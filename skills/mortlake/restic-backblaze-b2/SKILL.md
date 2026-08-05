---
name: restic-backblaze-b2
description: Restic backup to Backblaze B2 on NixOS — B2 native is broken, use S3 API instead
---

# Restic + Backblaze B2 on NixOS

## Context
The restic module in this corpus uses `services.restic.backups` with a systemd timer.
A wrapper script `restic-<backupName>` is created via `createWrapper = true`.

## Key Findings

### B2 Backend is Unmaintained
Restic's B2 native backend uses the `blazer` library which calls B2 API v1/v3.
Backblaze has deprecated those API versions. As of 2026, all B2 auth keys
(even account-level master keys) require API v4. Error seen:
```
b2_authorize_account: 400: This request is not currently supported on API version number 3
```

Restic's own docs say: **use the S3-compatible API instead**.

### Binary Name
The wrapper is created by `createWrapper = true` and produces `restic-<backupName>` (e.g. `restic-thoth`), NOT `restic`. The consolidated module also adds `pkgs.restic` to `environment.systemPackages` so the bare `restic` CLI is available for ad-hoc use.

### S3 Migration
Switch from `b2:` to `s3:` repository URL:

```nix
repository = "s3:s3.us-east-005.backblazeb2.com/thoth-restic";
```

Credentials map directly:
| B2 variable | S3 variable |
|-------------|-------------|
| B2_ACCOUNT_ID | AWS_ACCESS_KEY_ID |
| B2_ACCOUNT_KEY | AWS_SECRET_ACCESS_KEY |

Endpoint: use your B2 bucket's region-specific S3 endpoint (e.g. `s3.us-east-005.backblazeb2.com`).

### sops-nix Secrets Paths
sops-nix stores secrets under versioned directories like `/run/secrets.d/<N>/`,
NOT always under `/run/secrets/`. Always discover the actual path:
```bash
sudo find /run/secrets.d -name '*restic*' 2>/dev/null
```
Typical layout on this host:
- `/run/secrets.d/<N>/thoth-restic-password` — RESTIC_PASSWORD_FILE target
- `/run/secrets.d/<N>/rendered/thoth-restic-b2-env` — sourceable env file (exports AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY)

### Ad-Hoc Restic Commands (Manual / Shell Use)
The `restic-thoth` wrapper does NOT automatically source the systemd `EnvironmentFile`.
For any ad-hoc restic command (snapshots, restore, stats, init), you must explicitly
source credentials. Use this pattern:
```bash
sudo bash -c '
  source /run/secrets.d/<N>/rendered/thoth-restic-b2-env
  export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY
  export RESTIC_REPOSITORY="s3:s3.us-east-005.backblazeb2.com/thoth-restic"
  export RESTIC_PASSWORD_FILE="/run/secrets.d/<N>/thoth-restic-password"
  restic snapshots
'
```
Replace `<N>` with the actual version directory found via `find` above.
The bare `restic` binary (not the wrapper) works fine here — the env vars are what matter.

### Repository Initialization
The `initialize = true` option in `services.restic.backups.<name>` handles declarative
init — restic will initialize the repo on first backup run if it doesn't exist.
If imperative init is needed before the timer fires, use the ad-hoc pattern above
with `restic init` instead of `restic snapshots`.

### Testing S3 Connectivity
Note: `curl -u` does NOT work for S3 (requires AWS Signature V4). Instead, use
the ad-hoc restic pattern above to test connectivity — `restic stats` or
`restic snapshots` will fail fast with a clear auth/repo-existence error.

## File Structure (consolidated)
- `modules/features/restic.nix` — single module for all hosts, dispatches on `config.networking.hostName`
- `modules/features/secrets.yaml` — thoth SOPS-encrypted credentials (thoth-restic-password, thoth-restic-b2-env)
- `modules/features/supersecrets.yaml` — mab SOPS-encrypted credentials (mab-restic-password, mab-restic-b2-env)

### Per-Host Dispatch Pattern
The module uses an attrset keyed on hostname:
```nix
hostConfig = {
  thoth = { name = "thoth"; repository = "s3:..."; ... };
  mab   = { name = "mab";   repository = "s3:..."; ... };
};
cfg = hostConfig.${hostName};
```
Both hosts import `self.nixosModules.restic`. The old `mab-restic.nix` is deleted.

### Adding a New Host
1. Add a sops secret pair (`<host>-restic-password`, `<host>-restic-b2-env`) in the host's sops config
2. Add a B2 bucket
3. Add an entry to the `hostConfig` attrset in `restic.nix`

### Recovering a Missing/Deleted config File
If the `config` file at the root of the B2 bucket is deleted but keys/, data/, index/, and snapshots/ remain:

1. **Check B2 versions first** -- B2 keeps non-current versions by default:
   ```bash
   nix shell nixpkgs#awscli2 -c bash -c '
     source /run/secrets/rendered/<host>-restic-b2-env
     export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_DEFAULT_REGION=us-east-005
     aws s3api list-object-versions --bucket <bucket> --prefix config \
       --endpoint-url https://s3.us-east-005.backblazeb2.com
   '
   ```
2. **If no versions exist**, reconstruct using the Go tool at `/tmp/restic-recover/`:
   - Downloads the key file from B2
   - Decrypts it with the repo password (scrypt + AES-256-CTR + Poly1305-AES)
   - Generates a new irreducible polynomial (degree 52) using `github.com/restic/chunker`
   - Encrypts and uploads a fake config to B2
   - **Caveat**: The new chunker polynomial differs from original, breaking dedup for new backups. Restores work fine. Run `restic backup` once to re-chunk.

3. **SOPS secrets path**: On NixOS with sops-nix, secrets may be at `/run/secrets.d/<N>/` not `/run/secrets/`. Check both.

4. **Recovery script**: A ready-to-run Go program is at `scripts/recover-config.go`. Usage:
   ```bash
   # Download key file from B2 first
   nix shell nixpkgs#awscli2 -c bash -c '
     source /run/secrets/rendered/<host>-restic-b2-env
     export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_DEFAULT_REGION=<region>
     aws s3api get-object --bucket <bucket> --key "keys/<key-file-hash>" \
       --endpoint-url https://s3.<region>.backblazeb2.com /tmp/restic-key-file
   '
   # Run recovery (needs go + restic/chunker + golang.org/x/crypto)
   mkdir -p /tmp/restic-recover && cp scripts/recover-config.go /tmp/restic-recover/
   cd /tmp/restic-recover
   go mod init recover && go mod tidy
   go run recover-config.go /tmp/restic-key-file /path/to/password-file
   # Then upload the output to B2 as 'config'
   ```

**Pitfalls during config recovery:**
- Python `hashlib.scrypt` may hit OpenSSL memory limits with typical restic scrypt params (N=32768). Use Go or `openssl kdf` instead.
- The `chunker_polynomial` in config JSON must be a plain hex string (e.g. `"3da3358b4dc9"`), NOT `"0x3da3358b4dc9"`. Use `github.com/restic/chunker.RandomPolynomial()` to generate a valid irreducible polynomial.
- Restic's Poly1305-AES key layout is `R(16) || AES_K(nonce)(16)` — not the other way around. Use restic's own `golang.org/x/crypto/poly1305` via Go to avoid implementation mistakes.
