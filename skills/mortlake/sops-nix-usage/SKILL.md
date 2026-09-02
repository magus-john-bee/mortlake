---
name: sops-nix-usage
description: Corpus-specific sops-nix workflow — which secrets file to edit, current secrets list, sops CLI commands for adding/updating values, rebuild-to-propagate workflow, and caveats (no --update-key flag, exec-env for verification). Use this when you need to ADD or MODIFY a secret in corpus. For general sops-nix API (module options, templates, age key setup), use sops-nix instead.
category: devops
---

# sops-nix Workflow

Secrets are encrypted in `secrets.yaml` files and decrypted at build time via sops-nix. Secrets are then available to services via `config.sops.secrets."<name>".path`.

## Current System

- **Repo:** `/home/john/src/corpus`
- **Main secrets file:** `modules/features/secrets.yaml`
- **Encrypted for:** `thoth` and `titania` age keys (see `.sops.yaml`)
- **CLI:** `sops` (installed at `/run/current-system/sw/bin/sops`)
- **SOPS_AGENT:** thoth's age key at `/run/secrets/sops/agent`

## Adding/Updating a Secret

### Step 1: Edit the encrypted file

You CANNOT use `sops set --update-key` — that flag doesn't exist. Instead:

**Option A: Use `sops set` with JSON path (for new keys only)**
```bash
cd /home/john/src/corpus
sops set modules/features/secrets.yaml hermes-env 'value here'
```
This works for NEW keys. For existing keys, decrypt, edit manually, then re-encrypt.

**Option B: Decrypt, edit, re-encrypt**
```bash
cd /home/john/src/corpus

# Decrypt to see current content
sops -d modules/features/secrets.yaml

# Edit the decrypted file, then re-encrypt
# (sops auto-detects and re-encrypts on save if within a creation_rule path)
```

**Option C: Use sops exec-env to verify (read-only)**
```bash
sops exec-env modules/features/secrets.yaml -- 'echo "KEY=$KEY"'
```

### Step 2: Rebuild NixOS to propagate

After updating `secrets.yaml`, rebuild to regenerate the decrypted secret files:
```bash
nixos-rebuild switch --flake .#thoth
```

The hermes-agent service reads `hermes-env` via `environmentFiles` in `hermes.nix`:
```nix
environmentFiles = [ config.sops.secrets."hermes-env".path ];
```

## Current Secrets in secrets.yaml

- `hermes-env` — contains `MESSAGING_CWD`, `LOGSEQ_PATH`, `OPENROUTER_API_KEY`, `HF_TOKEN`, `MINIMAX_API_KEY`
- `groq-api-key`
- `thoth-restic-password`
- `thoth-restic-b2-env`
- `hindsight-env`
- `gh-hosts`
- `gh-config`

## Gotchas

1. **No `--update-key` flag** — doesn't exist, ignore any docs suggesting it
2. **`sops set` with JSON path** — works for adding new keys, not reliable for modifying multi-line values
3. **Rebuild required** — changes to `secrets.yaml` don't propagate until `nixos-rebuild switch`
4. **Age keys** — secrets are encrypted for specific recipients defined in `.sops.yaml`
5. **`sops exec-env`** — lets you verify decrypted values without writing files

## Related Skills

- `sops-nix` — dendritic pattern skill for SOPS in corpus NixOS config