---
name: import-tree-debugging
description: Debugging techniques for flake-parts with import-tree — uncommitted files, missing packages, and eval-time vs parse-time errors.
version: 1.0.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [nix, flake-parts, import-tree, debugging]
---

# import-tree Debugging

`import-tree` (github:vic/import-tree) is used in corpus as the flake-parts module loader.
It scans `modules/` directories and auto-discovers `.nix` files as flake-parts modules.

## Critical Gotcha: Uncommitted Files Are Invisible

`import-tree` evaluates the **git tree** — untracked or unstaged files are NOT picked up
by `nix flake show`, `nix build`, or any flake evaluation. This includes new modules you
create but haven't yet committed.

**Symptoms:**
- `nix flake show` doesn't list your new module
- `nix build .#packages.<system>.<name>` errors with "does not provide attribute"
- `nix eval '.#packages.<system>' --json` doesn't include the new package
- But `nix-instantiate --parse` succeeds (it doesn't need git)

**Fix:** Always `git add` new module files before expecting them to appear in flake output. Staged-but-uncommitted changes require `nix flake show --allow-dirty` or `nix build --impure`. Committed files are visible to plain `nix flake show`.

## package vs nixosModules in the same file

Files can define both `perSystem.packages.<name>` (built via `nix build .#packages.<system>.<name>`)
and `flake.nixosModules.<name>` (imported into NixOS configs). Both reference the same flake
output tree but use different evaluation contexts.

For `nixosModules` to reference `perSystem.packages`:
```nix
flake.nixosModules.foo = { pkgs, ... }:
  let
    inherit (self.packages.${pkgs.stdenv.hostPlatform.system}) foo;
  in
  { environment.systemPackages = [ foo ]; };
```

Note: `self` must be in the destructuring of the module argument (`{ self, inputs, ... }`).

## Nix attribute naming restrictions

Dots (`.`) and double-dots (`..`, `...`) cannot be used as Nix attribute names. If you need
aliases like `..` or `...`, define them as literal zsh alias strings in `zshrc.content` rather
than trying to use a `zshAliases` attribute set.

## Checking what's actually in the flake

```bash
# List packages (fast)
nix eval '.#packages.x86_64-linux' --json | python3 -c "import sys,json; print(sorted(json.loads(sys.stdin.read()).keys()))"

# Full flake show (slower)
nix flake show --refresh

# Dry-run a specific package
nix build .#packages.x86_64-linux.<name> --dry-run
```

## wrapper-modules zsh API (BirdeeHub/nix-wrapper-modules)

The zsh wrapper from `wrapper-modules` uses:
- `zshrc.content` — string content appended to generated `.zshrc`
- `zshrc.path` — path to a file sourced before `.content`
- `zshAliases` — attribute set of alias-name -> command-string (null = ignore)
- `zdotdir` — directory containing `.zshenv`, `.zshrc`, `.zlogin`, `.zlogout`

For all aliases (including those with dots in names), prefer `zshrc.content` with literal
`alias` syntax. Keep `zshAliases` simple or avoid it.
