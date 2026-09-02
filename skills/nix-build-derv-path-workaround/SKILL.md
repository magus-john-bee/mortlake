---
name: nix-build-derv-path-workaround
description: Work around misleading nix build error where evaluation succeeds but reporting fails with "type is not a string but a set"
version: 1.0.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [nix, nixos, build-error, workaround]
    related_skills: [nixos-rebuild-dry-run, corpus-nixos-modules]
---

# Nix Build DRV Path Workaround

## Problem
`nix build .#nixosConfigurations.<name>` fails with:
```
error: 'nixosConfigurations.<name>.type' is not a string but a set
```

But evaluation actually succeeds. The error is a nix reporting bug where the build appears to fail but the derivation was created correctly.

## Solution

### Option A: Build the toplevel directly (simplest)

```bash
nix build .#nixosConfigurations.<name>.config.system.build.toplevel
```

This bypasses the reporting bug by requesting the actual derivation attribute instead of the top-level option set.

### Option B: Get the .drv path and build it

```bash
# Step 1: Get the .drv path (this succeeds)
nix eval --raw '.#nixosConfigurations.<name>.config.system.build.toplevel.drvPath'

# Step 2: Build from the .drv directly
nix build /nix/store/<hash>-nixos-system-<name>-<version>.drv
```

## When to Use
- When `nix build .#nixosConfigurations.<host>` fails with the "type" error but you're confident the config is correct
- When `nix build .#nixosConfigurations.<host> --show-trace` still shows only the cryptic error
- When `nix build .#nixosConfigurations.<host> --dry-run` also fails

## Note
This appears to be a bug in certain nix versions where evaluation succeeds but output handling fails to coerce the option-type set to a string for reporting. Option A is preferred — it's one command instead of two.

## Overlap
The `nixos-rebuild-dry-run` skill documents this same pattern in its gotchas section.
