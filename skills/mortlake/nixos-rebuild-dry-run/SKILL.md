---
name: nixos-rebuild-dry-run
description: Verify NixOS configuration builds without applying — dry-run workflow, command gotchas, and sudo requirements for config validation.
version: 1.1.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [nixos, nix, dry-run, build-verification]
    related_skills: [sops-nix-usage, restic-backblaze-b2, nix-build-derv-path-workaround]
---

# NixOS Rebuild Dry-Run

Use this when the user wants to verify a NixOS or Nix flake configuration builds without switching to it.

**The Command**

```bash
sudo nixos-rebuild dry-build --flake .#<hostname>
```

Example for thoth:
```bash
sudo nixos-rebuild dry-build --flake .#thoth
```

> **Note:** On some NixOS versions, `nixos-rebuild switch --dry-run` fails with "unrecognized arguments: --dry-run". Use `dry-build` as the action instead.

## Common Gotchas

1. **`nix build .#nixosConfigurations.<host>` does NOT work** — it fails with "type is not a string but a set". The correct `nix build` invocation is:
   ```bash
   nix build .#nixosConfigurations.<host>.config.system.build.toplevel
   ```
   This builds the full system derivation. It validates more than `nix flake check` but less than `nixos-rebuild dry-build` (which evaluates all modules in the NixOS eval context).

2. **`nix flake check` validates flake structure only** — it passes even if the actual NixOS config has module-level errors. It checks packages, devShells, and module imports, but NOT the full system evaluation.

3. **Always use `sudo`** — nixos-rebuild requires root. Without sudo access (e.g., agent running as non-root user without NOPASSWD), this command will fail.

4. **The `--dry-run` flag is not available on all NixOS versions** — some versions only support `dry-build`. If `--dry-run` fails with "unrecognized arguments", try `dry-build` instead.

## Inspecting Generated Units Before Deploy

After `nix build` succeeds, you can inspect the generated systemd units, config files, etc. from the nix store **without switching**:

```bash
nix build .#nixosConfigurations.<host>.config.system.build.toplevel --no-link --print-out-paths | \
  xargs -I{} cat {}/etc/systemd/user/<service>.service
```

This is useful for verifying PATH contents, EnvironmentFile paths, ExecStart commands, etc. before committing to a rebuild. Avoids multiple rebuild cycles when debugging service configuration.

## Cross-Host Builds

**Don't build other hosts' configs locally unless the user explicitly asks.** Building `.#puck` from thoth pulls in hundreds of packages, builds large GUI/desktop dependencies, and can take 10+ minutes. The correct workflow for fixing another host's config is:

1. Fix the issue in the Nix files
2. Run `nix flake check` or `nix eval` to catch obvious errors (fast, no downloads)
3. Push the fix (PR if branch-protected)
4. Let the target machine pull and rebuild itself

The user will tell you if they want a full local build of a different host. If the build fails with a clear eval error (missing attribute, type mismatch), that's caught at evaluation time — no full build needed to confirm the fix.

## Workflow

```
1. sudo nixos-rebuild dry-build --flake .#<hostname>   (or nix build ... toplevel)
2. If errors → fix them
3. (Optional) Inspect generated units/configs from nix store
4. Repeat until dry-build passes
5. User runs: sudo nixos-rebuild switch --flake .#<hostname>  (to actually apply)
```

## Exit Codes

- `0` — Dry-build passed, configuration is valid
- `non-zero` — Errors in configuration (module imports, types, assertions, etc.)
