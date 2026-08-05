---
name: sops-nix
description: General sops-nix API reference — flake input, .sops.yaml key selection, creating/editing secrets, templates with placeholder interpolation, per-secret options, and gotchas. Use this when you need to understand HOW sops-nix works (syntax, options, age key management). For corpus-specific workflow (which secrets file, current secrets list, CLI editing commands), use sops-nix-usage instead.
---

# sops-nix

Encrypts secrets at rest in the repo, decrypts at activation time to `/run/secrets/`.

## Setup

### Flake input

```nix
inputs.sops-nix = {
  url = "github:Mic92/sops-nix";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

### NixOS module

```nix
{ inputs, ... }: {
  flake.nixosModules.sops = { ... }: {
    imports = [ inputs.sops-nix.nixosModules.sops ];
    sops = {
      defaultSopsFile = ./secrets.yaml;
      defaultSopsFormat = "yaml";
      age.keyFile = "/home/john/.age/private.txt";
    };
  };
}
```

Add `self.nixosModules.sops` to host configuration imports.

## .sops.yaml (repo root)

Controls which keys can decrypt. **Not a Nix file** — sops reads it directly:

```yaml
keys:
  - &thoth age19ujs8j7sj8tsmep6ugtha0suuwk9tshef3a54l39ly6r6tqtwq0qd269ea
  - &admin age1xxxxx...

creation_rules:
  - key_groups:
      - age:
          - *thoth
          - *admin
```

Supports `path_regex` for per-file rules.

## Getting Age Public Keys

```bash
# From personal SSH ed25519 key:
nix-shell -p ssh-to-age --run "ssh-to-age < ~/.ssh/id_ed25519.pub"

# From remote host SSH host key:
nix-shell -p ssh-to-age --run "ssh-keyscan <host> | ssh-to-age"
```

## Creating & Editing Secrets

```bash
nix-shell -p sops --run "sops modules/features/secrets.yaml"
```

Opens `$EDITOR`. Write YAML:

```yaml
hermes-env: |
  EXA_API_KEY=sk-abc123...
  GLM_API_KEY=sk-def456...
```

On save, sops encrypts all values. Safe to `git commit`.

**Important:** For `systemd EnvironmentFile` use, secret values must be `KEY=VALUE` format (not YAML `KEY: VALUE`).

## Re-encrypting After Key Changes

```bash
sops updatekeys modules/features/secrets.yaml
```

## Using Secrets in NixOS Config

Secrets are **files, not strings**. Use `config.sops.secrets.<name>.path`:

```nix
{ config, ... }: {
  sops.secrets.my_password = { owner = "john"; };
  users.users.john.hashedPasswordFile = config.sops.secrets.my_password.path;
}
```

### Per-secret options

| Option | Description |
|--------|-------------|
| `owner` | File ownership (e.g., `"john"`) |
| `group` | Group ownership |
| `mode` | File permissions (e.g., `"0400"`) |
| `sopsFile` | Override source file |
| `format` | Override format (`yaml`, `json`, `binary`, `dotenv`, `ini`) |
| `key` | Key to extract from sops file |
| `path` | Override destination path |
| `restartUnits` | systemd units to restart when secret changes |
| `reloadUnits` | systemd units to reload (SIGHUP) when secret changes |
| `neededForUsers` | Decrypt before user creation (for passwords) |

## Templates — Interpolate Secrets into Config

```nix
{ config, ... }: {
  sops.secrets.db_password = {};

  sops.templates."app-config.toml".content = ''
    database_url = "postgres://app:${config.sops.placeholder.db_password}@localhost/app"
  '';
}
```

`config.sops.placeholder.<name>` are hashed markers replaced with decrypted values during activation. Templates land at `/run/secrets/rendered/<name>`.

## Gotchas

1. **Secrets only exist after activation** — never use at Nix evaluation time
2. **`neededForUsers = true`** decrypts to `/run/secrets-for-users/` before user creation
3. **`restartUnits`** — add this so services pick up changed secrets on rebuild
4. **`age.keyFile` must NOT be in the Nix store** — sops-nix rejects Nix store paths
5. **Impermanence** — put `sops.age.keyFile` on a persisted path, or ensure `/etc/ssh` has `neededForBoot = true`
6. **Age over GPG** — simpler, no daemon, works with SSH ed25519 keys

## References

- sops-nix: https://github.com/Mic92/sops-nix
