---
name: nix-flake-patch-dependency
description: Patch and experiment with Nix flake dependencies locally to isolate bugs
triggers:
  - nix flake override dependency
  - nix patch local package
  - nix overlay patch
  - nix debug dependency
---

# Nix Flake Dependency Patching Workflow

## Core Principle

In flakes, you **cannot patch files post-build**. Instead, you override the derivation at evaluation time using overlays or `overrideAttrs`. The goal is to reproduce a bug, isolate it, and verify the fix — without polluting upstream.

## Workflow Overview

```
1. Identify the failing package via nix log / error trace
2. Isolate: override it with local source or patches
3. Verify: build succeeds
4. Refine: iterate until bug is pinpointed
5. Clean up: upstream the fix or keep the override localized
```

## Technique 1: overrideAttrs (Leaf Package)

Use when you want to patch a single package's source or add build flags.

```nix
# In configuration.nix (NixOS module) — preferred for NixOS configs
{ pkgs, ... }: {
  nixpkgs.overlays = [
    (final: prev: {
      my-package = prev.my-package.overrideAttrs (oldAttrs: {
        # Option A: patch source
        patches = (oldAttrs.patches or []) ++ [
          ./my-local-fix.patch
        ];
        # Option B: substitute in-place
        postPatch = oldAttrs.postPatch or "" + ''
          sed -i "s|broken|fixed|g" src/main.c
        '';
        # Option C: override src entirely
        src = pkgs.fetchFromGitHub {
          owner = "myfork";
          repo = "my-package";
          rev = "my-fix-branch";
          hash = "sha256-...";
        };
      });
    })
  ];
}
```

## Technique 2: overrideAttrs with fetchpatch (Quick PR Patch)

When a PR fix exists but isn't in nixpkgs yet:

```nix
(final: prev: {
  my-package = prev.my-package.overrideAttrs (oldAttrs: {
    patches = (oldAttrs.patches or []) ++ [
      (prev.pkgs.fetchpatch {
        url = "https://github.com/owner/repo/pull/123.patch";
        sha256 = "sha256-...";
      })
    ];
  });
})
```

## Technique 3: Overlay for NixOS Flake Configs

For flake-based NixOS systems, the idiomatic place is `nixosModules` or inline in the host configuration:

```nix
# In your flake's modules/hermes.nix or similar
{ inputs, lib, config, pkgs, ... }: {
  nixpkgs.overlays = [
    (final: prev: {
      # Override a dependency of a package
      some-dep = prev.some-dep.overrideAttrs (old: {
        buildInputs = old.buildInputs ++ [ prev.libopus ];
      });
    })
  ];
}
```

## Technique 4: Local Path Input Override (CLI-only, No Rebuild)

For quick one-off testing without modifying any files:

```sh
# Override an input to a local checkout
nix build .#my-package --override-input nixpkgs /path/to/local/nixpkgs

# Or override a foreign flake input
nix build .#my-package --override-input some-flake /path/to/local/some-flake
```

## Technique 5: applyPatches (Whole-nixpkgs Patch)

For patches that affect many packages (rare):

```nix
# In flake.nix outputs
let
  nixpkgs-patched = import
    ((import inputs.nixpkgs { inherit system; }).applyPatches {
      name = "my-patchset";
      src = inputs.nixpkgs;
      patches = [ ./my-nixpkgs-patch.patch ];
    })
    { inherit system; };
in {
  # Use nixpkgs-patched here
}
```

**Warning**: This creates a second nixpkgs evaluation and breaks Hydra cache. Prefer overlays for NixOS configs.

## Debugging Commands

```sh
# Trace why a dependency is pulled in
nix why-depends .#packageName some-dependency

# View build log for a derivation
nix log /nix/store/...-some-package.drv

# Check what a package's src is
nix build .#packageName --print-build-log 2>&1 | head -50

# Dry-run eval (no build)
nix flake check --no-build

# Evaluate without building
nix eval .#packages.x86_64-linux.packageName.src.outPath
```

## Common Pitfalls

1. **`overrideDerivation` is deprecated** — use `overrideAttrs` instead
2. **Don't patch nixpkgs itself** — patch the package derivation via overlay
3. **Don't use `import nixpkgs {}` in critical paths** — creates multiple nixpkgs evaluations (IFD issues)
4. **For NixOS configs**: put overlays in `nixpkgs.overlays` in the module, not in `flake.nix` outputs
5. **Path dependencies need to be in git** — `nix build` reads from git index; commit before building

## Quick-Reference: Override vs overlayAttrs

| Situation | Approach |
|----------|----------|
| Change build flags / env vars | `overrideAttrs (old: { NIX_CFLAGS = ...; })` |
| Add a patch | `overrideAttrs (old: { patches = old.patches or [] ++ [ ./fix.patch ]; })` |
| Replace src with local checkout | `overrideAttrs (old: { src = /path/to/local/repo; })` |
| Override a function argument | `.override { arg = value; }` |
| Many packages need the same fix | Use an overlay |

## See Also

- [nix.dev: Overriding packages](https://nix.dev/guides/recipes/dependency-management)
- [ryantm nixpkgs: Overrides](https://ryantm.github.io/nixpkgs/using/overrides/)
- [juuso.dev: Patching nixpkgs in a flake](https://juuso.dev/blogPosts/patching-nixpkgs-flake/patching-nixpkgs-in-a-flake.html)
- [Discourse: Proper way of applying patch to system managed via flake](https://discourse.nixos.org/t/proper-way-of-applying-patch-to-system-managed-via-flake/21073)
