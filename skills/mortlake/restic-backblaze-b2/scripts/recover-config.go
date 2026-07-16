// Recover a missing restic repository config file.
//
// When the config file is deleted but keys/, data/, index/, and snapshots/
// remain, this program decrypts the key file, extracts the master key,
// generates a new irreducible chunker polynomial, and writes an encrypted
// config file that restic can read.
//
// Usage:
//   1. Download the key file from the repo (e.g. via aws s3api)
//   2. Run: go run recover-config.go <key-file> <password-file>
//   3. Upload the output to the repo as "config"
//
// Requires: github.com/restic/chunker, golang.org/x/crypto/{poly1305,scrypt}
//
// NOTE: The new chunker polynomial differs from the original. This means:
//   - All existing data can be RESTORED
//   - Deduplication for NEW backups will be less efficient (first backup re-chunks)
//   - For restore-only purposes, this is perfectly fine

package main

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"encoding/json"
	"fmt"
	"os"

	"github.com/restic/chunker"
	"golang.org/x/crypto/poly1305"
	"golang.org/x/crypto/scrypt"
)

type MACKey struct {
	K []byte `json:"k"`
	R []byte `json:"r"`
}

type MasterKey struct {
	Encrypt []byte `json:"encrypt"`
	MAC     MACKey `json:"mac"`
}

type KeyFile struct {
	N    int    `json:"N"`
	R    int    `json:"r"`
	P    int    `json:"p"`
	Salt []byte `json:"salt"`
	Data []byte `json:"data"`
}

// poly1305PrepareKey builds the Poly1305 key per restic's convention:
// key = R(16 bytes) || AES_K(nonce)(16 bytes)
func poly1305PrepareKey(nonce []byte, k, r []byte) [32]byte {
	var key [32]byte
	block, _ := aes.NewCipher(k)
	block.Encrypt(key[16:], nonce)
	copy(key[:16], r)
	return key
}

func poly1305Compute(msg []byte, nonce []byte, k, r []byte) []byte {
	polyKey := poly1305PrepareKey(nonce, k, r)
	var out [16]byte
	poly1305.Sum(&out, msg, &polyKey)
	return out[:]
}

// seal encrypts and authenticates plaintext using restic's AEAD format:
// output = nonce(16) + ciphertext + MAC(16)
func seal(encKey, macK, macR, plaintext []byte) []byte {
	nonce := make([]byte, 16)
	rand.Read(nonce)
	block, _ := aes.NewCipher(encKey)
	ct := make([]byte, len(plaintext))
	stream := cipher.NewCTR(block, nonce)
	stream.XORKeyStream(ct, plaintext)
	mac := poly1305Compute(ct, nonce, macK, macR)
	result := make([]byte, 0, 16+len(ct)+16)
	result = append(result, nonce...)
	result = append(result, ct...)
	result = append(result, mac...)
	return result
}

func main() {
	if len(os.Args) < 3 {
		fmt.Fprintf(os.Stderr, "Usage: %s <key-file> <password-file> [output-file]\n", os.Args[0])
		fmt.Fprintf(os.Stderr, "\nDecrypts a restic key file and creates a fake config file.\n")
		fmt.Fprintf(os.Stderr, "The key file can be downloaded from the repo's keys/ directory.\n")
		os.Exit(1)
	}

	keyFilePath := os.Args[1]
	passwordPath := os.Args[2]
	outputPath := "/tmp/restic-config-recovered"
	if len(os.Args) >= 4 {
		outputPath = os.Args[3]
	}

	// Read password
	password, err := os.ReadFile(passwordPath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: read password: %v\n", err)
		os.Exit(1)
	}
	pass := string(password)
	if len(pass) > 0 && pass[len(pass)-1] == '\n' {
		pass = pass[:len(pass)-1]
	}

	// Read key file
	keyData, err := os.ReadFile(keyFilePath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: read key file: %v\n", err)
		os.Exit(1)
	}

	var kf KeyFile
	if err := json.Unmarshal(keyData, &kf); err != nil {
		fmt.Fprintf(os.Stderr, "Error: parse key file: %v\n", err)
		os.Exit(1)
	}

	fmt.Printf("Key file: N=%d r=%d p=%d salt=%d-bytes data=%d-bytes\n",
		kf.N, kf.R, kf.P, len(kf.Salt), len(kf.Data))

	// Derive user key from password via scrypt
	derived, err := scrypt.Key([]byte(pass), kf.Salt, kf.N, kf.R, kf.P, 64)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: scrypt: %v\n", err)
		os.Exit(1)
	}
	encKey := derived[0:32]
	macK := derived[32:48]
	macR := derived[48:64]

	// Parse encrypted data: nonce(16) + ciphertext + MAC(16)
	nonce := kf.Data[:16]
	macTag := kf.Data[len(kf.Data)-16:]
	ciphertext := kf.Data[16 : len(kf.Data)-16]

	// Verify MAC (over ciphertext only, per restic source)
	computedMAC := poly1305Compute(ciphertext, nonce, macK, macR)
	if string(computedMAC) != string(macTag) {
		fmt.Fprintf(os.Stderr, "Error: MAC verification failed (wrong password?)\n")
		os.Exit(1)
	}
	fmt.Println("MAC verification: OK")

	// Decrypt master key via AES-256-CTR
	block, _ := aes.NewCipher(encKey)
	plaintext := make([]byte, len(ciphertext))
	stream := cipher.NewCTR(block, nonce)
	stream.XORKeyStream(plaintext, ciphertext)

	var master MasterKey
	if err := json.Unmarshal(plaintext, &master); err != nil {
		fmt.Fprintf(os.Stderr, "Error: parse master key: %v\n", err)
		os.Exit(1)
	}
	fmt.Println("Master key decrypted: OK")

	// Generate a valid irreducible polynomial using restic's chunker library
	pol, err := chunker.RandomPolynomial()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: generate polynomial: %v\n", err)
		os.Exit(1)
	}

	// Generate random repo ID
	b := make([]byte, 16)
	rand.Read(b)
	newID := fmt.Sprintf("%x-%x-%x-%x-%x", b[0:4], b[4:6], b[6:8], b[8:10], b[10:])

	// Create config JSON (polynomial as plain hex, NO "0x" prefix)
	config := map[string]interface{}{
		"version":            2,
		"id":                 newID,
		"chunker_polynomial": fmt.Sprintf("%x", uint64(pol)),
	}
	configJSON, _ := json.Marshal(config)
	fmt.Printf("Config: %s\n", string(configJSON))

	// Encrypt config with master key
	encrypted := seal(master.Encrypt, master.MAC.K, master.MAC.R, configJSON)

	if err := os.WriteFile(outputPath, encrypted, 0644); err != nil {
		fmt.Fprintf(os.Stderr, "Error: write output: %v\n", err)
		os.Exit(1)
	}

	fmt.Printf("\nSUCCESS: %d bytes written to %s\n", len(encrypted), outputPath)
	fmt.Println("Upload this file to the repo root as 'config' (e.g. via aws s3api put-object)")
}
