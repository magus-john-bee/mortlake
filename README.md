# mortlake

Personal monorepo for all code and configs. Named after John Dee's house at Mortlake — library, workshop, observatory.

NixOS configuration using the **Dendritic Pattern** — every `.nix` file under `modules/` is a self-contained flake-parts module, auto-discovered by `import-tree`.

## Hosts

| Host | Role | Hardware |
|------|------|----------|
| **Uriel** | Hetzner VPS — Hermes, Pi, nginx, podman | Cloud VPS |
| **Jehoel** | Server + desktop — Jellyfin, Transmission, Mealie, Sunshine, AMD GPU | Intel NUC + OCuLink eGPU |
| **Raphael** | Framework 12 laptop — daily driver | Framework 12 |
| **Raziel** | Android phone (GrapheneOS) — nix-on-droid | Pixel |
| **Haniel** | Android phone (vanilla Android) — nix-on-droid | Pixel |

## Build & Deploy

```bash
nixos-rebuild switch --flake .#uriel     # Build and switch (NixOS hosts)
nix build .#nixosConfigurations.uriel    # Build without switching
nix-on-droid switch --flake .#raziel     # Apply phone config
```

## Repository Structure

```
├── flake.nix                     # mkFlake + import-tree ./modules
├── modules/
│   ├── parts.nix                 # flake-parts systems list
│   ├── features/                 # Feature modules (auto-discovered)
│   └── hosts/                    # Host configurations
├── skills/                       # Agent skills for Hermes/Pi (~68 SKILL.md files)
├── sites/                        # Personal static sites
│   └── dev-resume/               # Hugo resume site (johnotwell.com)
├── android/                      # GrapheneOS + vanilla Android provisioning
└── justfile                      # lint, eval, schema validation, skill syncing
```

## Secrets (sops-nix)

All machines use SSH-derived age keys for sops. sops-nix derives the age key from the SSH host key (`/persistent/etc/ssh/ssh_host_ed25519_key`) at activation time.

### Adding a new machine

1. Get the age public key: `ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub`
2. Add to `.sops.yaml` under `keys:` with a descriptive anchor
3. Add to the relevant `key_groups` in `creation_rules`
4. Re-encrypt: `sops updatekeys modules/features/secrets.yaml`

## Build & Test

```bash
just eval uriel          # Evaluate a host config without building
just dry uriel           # Dry-build (eval + derivations, no switch)
just lint                # nix fmt + statix + deadnix + schema validation
just lint-fix            # Auto-fix linting issues
```

## Clean install with nixos-anywhere

```bash
nix run nixpkgs#nixos-anywhere -- --flake .#<host> --target-host john@<ip> --phases kexec,disko,install,reboot
```

## Restic Backups

Each host has a restic backup job configured in `restic.nix`. Service modules contribute their own backup paths via the `mortlake.restic` option:

```nix
mortlake.restic = {
  paths = [ "/var/lib/my-service" ];
  exclude = [ "/var/lib/my-service/cache" ];
};
```

## Design Principles

**Single-user by design.** These machines have one human user (john). Unless there is a compelling reason otherwise, all services run as `john:users` and all data directories are owned by `john:users`.

## What This Repo Does Not Contain

- **Knowledge base** — Markdown notes live in `~/vault/logbook` (separate repo)
- **Public projects** — career-ops and other release-intended projects stay separate
