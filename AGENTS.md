You are an AI agent helping john with development, infrastructure, and creative tasks on the mortlake monorepo.

---

## Project Overview

NixOS configuration using the **Dendritic Pattern** — every `.nix` file under `modules/` is a self-contained flake-parts module, auto-discovered by `import-tree`. No manual imports, no relative paths. Files cross-reference by name through `self`.

Built on: **flake-parts**, **import-tree**, **nix-wrapper-modules**, **disko**, **sops-nix**, **preservation**.

**Domain skills:** `dendritic-pattern`, `nix-wrapper-modules`, `sops-nix` — load these when editing Nix files.

## Repository Structure

```
.
├── flake.nix                  # mkFlake + import-tree ./modules
├── .sops.yaml                 # sops key selection rules
├── modules/
│   ├── parts.nix              # flake-parts config (systems list)
│   ├── hosts/                 # Host configurations
│   │   ├── uriel/             # Hetzner VPS (Hermes, Pi, podman)
│   │   ├── jehoel/            # Server + desktop (replaces mab)
│   │   ├── raphael/           # Framework 12 laptop
│   │   ├── raziel/            # Android phone (nix-on-droid)
│   │   └── haniel/            # Android phone (nix-on-droid)
│   └── features/              # Reusable feature modules
├── skills/                    # Agent skills (Hermes + Pi)
├── sites/                     # Personal static sites
│   └── dev-resume/            # Hugo resume (johnotwell.com)
├── android/                   # Android provisioning scripts + profiles
├── AGENTS.md
└── justfile
```

## Host Directory Layout

Every NixOS host follows the same structure:

```
modules/hosts/<name>/
├── default.nix          # flake-parts: creates flake.nixosConfigurations.<name>
├── configuration.nix    # NixOS module: imports features
├── hardware.nix         # NixOS module: hardware-specific config
└── disko.nix            # NixOS module: disk partitioning
```

nix-on-droid hosts use `flake.nixOnDroidConfigurations` instead of `nixosConfigurations`, and `environment.packages` instead of `environment.systemPackages`.

**Why `default.nix` and `configuration.nix` are separate:** They operate at different module system levels. `default.nix` defines `flake.nixosConfigurations` (a flake-parts output) and customizes `pkgs` creation (`allowUnfree`, `permittedInsecurePackages`). This must happen at the flake level because `nixosSystem { pkgs = ... }` needs pkgs at evaluation time. `configuration.nix` defines `flake.nixosModules` — the actual NixOS config (imports, services, networking).

## Build & Test

```bash
nixos-rebuild switch --flake .#uriel     # Build and switch
nix build .#nixosConfigurations.uriel    # Build without switching
just eval uriel                          # Evaluate without building
just dry uriel                           # Dry-build
just lint                                # nix fmt + statix + deadnix + schema
```

## Design Principles

**Single-user by design.** These machines have one human user (john). Unless there is a compelling, specific reason otherwise, all services must run as `john:users` and all data directories must be owned by `john:users`.

**Wrapped packages.** Tools needing config injection (atuin, helix, ghostty, niri, zellij, zsh, noctalia) are wrapped via `wrapper-modules.lib.wrapPackage`. This creates `perSystem` packages with `constructFiles` that inject config at the nix store level. Both `nix run .#<tool>` and the system-wide install use the same wrapped config.

**Co-located configs.** Each wrapped module reads its config from a co-located file via `builtins.readFile ./path/to/config`. These files must travel with their parent `.nix` module — miss one and the build fails.

## Secrets (sops-nix)

All machines use SSH-derived age keys for sops. The age key is derived from the SSH host key at `/persistent/etc/ssh/ssh_host_ed25519_key`.

Secrets live in `modules/features/secrets.yaml` and `modules/features/supersecrets.yaml` — sops-encrypted, safe to commit.

### Adding a new machine

1. Get the age public key from its SSH host key: `ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub`
2. Add to `.sops.yaml` under `keys:` with a descriptive anchor (e.g., `&newhost`)
3. Add to the relevant `key_groups` in `creation_rules`
4. Re-encrypt: `sops updatekeys modules/features/secrets.yaml`

## Important Gotchas

1. **Always `inherit pkgs;`** in wrapper-modules `.wrap` calls — missing this breaks builds
2. **Don't nest flake-parts modules** — each file must be a flat module; flake-parts can't merge nested definitions
3. **`self` vs `self'`** — `self` is flake-level, `self'` is per-system; `self'` is NOT available in `flake.nixosModules`, use `self.packages.${pkgs.system}.<name>` instead
4. **`allowUnfree` in `default.nix` only** — must be set at pkgs creation time, not inside NixOS modules (assertion failure)
5. **`git add` new files before build** — flakes only see git-tracked files
6. **User-level preservation for john's dirs** — when adding a directory under `/home/john/` to preservation, use `users.john.directories` (not the system-level `directories` list)
7. **`nix-ld` is critical** — MCP servers and pre-built binaries need `programs.nix-ld` (in `nix-qol.nix`). They reference `LD_LIBRARY_PATH = "/run/current-system/sw/share/nix-ld/lib"`.
8. **Co-located config files** — wrapped modules use `builtins.readFile ./config.toml`. These files must exist alongside the `.nix` module.

## Restic Backups

All backup paths and excludes are listed per-host in the `hostConfig` attrset in `restic.nix`. When adding a new service, add its data directory to the relevant host's `paths`/`exclude` lists there.

## Landing the Plane (Session Completion)

**When ending a work session**, complete ALL steps:

1. **Run quality gates** - `just lint`
2. **Update PLAN.md** - check off completed items
3. **PUSH TO REMOTE**:
   ```bash
   git pull --rebase
   git push
   git status  # MUST show "up to date with origin"
   ```
4. **Verify** - All changes committed AND pushed
