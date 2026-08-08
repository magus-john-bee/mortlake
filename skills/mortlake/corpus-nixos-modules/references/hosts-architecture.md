# Host Architecture Reference

Three NixOS hosts managed from the corpus flake at `~/src/corpus`.

## Hosts

| Host | Role | Hardware | Boot | Disk |
|------|------|----------|------|------|
| **puck** | Laptop (Framework 12, 13th gen Intel) | NVMe | systemd-boot | LUKS → btrfs |
| **mab** | Home server (Intel, NVMe) | NVMe | systemd-boot | Plain btrfs (no LUKS planned) |
| **thoth** | VPS / agent host (QEMU guest) | VirtIO (`/dev/sda`) | GRUB (efiInstallAsRemovable) | Plain btrfs (no LUKS — cloud VM) |

## Current Persistence State

### Puck (reference implementation)
- **Framework**: `preservation` (nix-community/preservation)
- **Root**: tmpfs `/` (ephemeral, no btrfs rollback needed)
- **Mount**: `/persistent`
- **Disko**: LUKS encryption, btrfs subvols `persistent` and `nix`, 4G swap partition, ESP + bios-boot
- **sops**: `sops.nix` (age key at `/persistent/etc/ssh/...`)
- **User dirs**: declared in `preservation.users.john.directories` (`.ssh`, `src`, `vault`)
- **System dirs**: declared in `preservation.preserveAt."/persistent".directories` (`/tmp`, `/var/lib/nixos`, `/etc/ssh`, NetworkManager, bluetooth)
- **Files**: `/etc/machine-id`

### Mab
- **Framework**: `impermanence` (nix-community/impermanence) with btrfs rollback on boot
- **Root**: btrfs `/root` subvol (snapshotted + rolled back each boot via `impermanence.rollbackLabel`)
- **Mount**: `/persist`
- **Disko**: Plain btrfs, subvols `root`, `nix`, `persist`, `log` (no encryption, no swap)
- **sops**: `sopsLegacy.nix` (age key at `/persist/etc/ssh/...`)
- **Services with custom data dirs**: jellyfin (`/persist/jellyfin/*`), transmission (`/persist/transmission`), mealie (`/persist/mealie`), syncthing (`/persist/syncthing`)
- **Host-specific persisted dirs**: `/var/lib/acme`, `/var/lib/nginx`
- **Migration note**: Expand restic to B2 first, re-disko with nixos-anywhere, restore. 8G swap partition to be added.

### Thoth
- **Framework**: `impermanence` with btrfs rollback
- **Root**: btrfs `/root` subvol
- **Mount**: `/persist`
- **Disko**: Plain btrfs, subvols `root`, `nix`, `persist`, `log`, 2G swap (no encryption — cloud VM, LUKS is theater)
- **sops**: `sopsLegacy.nix`
- **Host-specific persisted dirs**: `/var/lib/hermes`, `/var/lib/containers`, `/var/lib/acme`, `/var/lib/nginx`, `/home/john/.codex`
- **Migration note**: Disposable host. Re-image with nixos-anywhere, restic restore. Add `.codex` to restic after codex/impermanence PR merges.

## Planned Migration

Goal: bring mab and thoth to parity with puck's architecture.

### Decisions (Finalized June 2026)

1. **No LUKS on servers.** Thoth is a cloud VM — hypervisor can read RAM, encryption is theater. Mab is physically accessible but LUKS unlock hassle isn't worth it for media server workloads. LUKS stays on puck only.
2. **tmpfs root** on all machines. No btrfs `/root` subvol, no initrd rollback service.
3. **Switch from `impermanence` to `preservation`** on mab and thoth
4. **Move mount point from `/persist` to `/persistent`**
5. **Services use default directories** (e.g., `/var/lib/jellyfin` instead of `/persist/jellyfin/data`) — listed in preservation's `directories` instead
6. **Consolidate sops modules** — single `sops.nix` pointing to `/persistent/etc/ssh/...`, delete `sopsLegacy.nix`
7. **8G swap on mab** (currently none)
8. **Common preservation module** — shared `preservation.nix` feature module for base dirs, machine-specific additions in each host's `configuration.nix`
9. **Update restic paths** to match new layout

### Migration Strategy

**Thoth (disposable):** Re-image with `nixos-anywhere`, `restic restore`. Add `.codex` to restic paths after codex/impermanence PR merges.

**Mab (data migration via B2):** Expand restic to cover all service data first. Let backup soak to B2 (~2 weeks of short-term storage cost). Re-disko with `nixos-anywhere`, then `restic restore`. Trim restic paths afterward (exclude transmission downloads, large media).

### Implementation Order

1. Expand mab restic paths + verify backup completes
2. Create shared `preservation.nix` feature module
3. Update disko configs (tmpfs root, `/persistent` + `/nix` subvols only, no `/root` or `/log` subvols)
4. Remove service data dir overrides (jellyfin, transmission, mealie, syncthing)
5. Add service default dirs to each host's preservation config
6. Consolidate sops.nix, delete sopsLegacy.nix
7. Delete `impermanence.nix` module, remove `impermanence` flake input
8. Re-disko thoth → restore
9. Re-disko mab → restore

### Service Default Data Directories

| Service | Default dir(s) | Notes |
|---------|----------------|-------|
| Jellyfin | `/var/lib/jellyfin` (data), `/etc/jellyfin` (config) | NixOS module has `dataDir` and `configDir` options |
| Transmission | `/var/lib/transmission` | NixOS module has `home` option; downloads go under `~/Downloads` |
| Mealie | `/var/lib/mealie` | Via `DATA_DIR` setting |
| Syncthing | `/var/lib/syncthing` | NixOS module has `dataDir` and `configDir` options |
| Nginx | `/var/lib/nginx` | State dir |
| ACME | `/var/lib/acme` | Cert storage |
| Hermes | `/var/lib/hermes` | Agent home |
| Codex | `/home/john/.codex` | CLI state |
| Podman | `/var/lib/containers` | Container storage |

### Restic Backup Paths (mab)

**Migration-time (expanded, temporary):** Back up EVERYTHING under `/persist/...` to B2 — jellyfin media, transmission downloads, syncthing sync data, mealie, acme, nginx, ssh, home dirs. Short-term B2 cost acceptable for ~2 weeks. Restore after re-disko, then trim.

**Steady-state (post-migration):** Back up from `/persistent/...` paths. Config/state only:
- Mealie data (`/persistent/var/lib/mealie`)
- Transmission config (`/persistent/var/lib/transmission` — **exclude `Downloads/`**)
- Jellyfin config (`/persistent/var/lib/jellyfin` — **exclude media library**)
- Syncthing config (`/persistent/var/lib/syncthing` — **exclude sync data**)
- ACME certs (`/persistent/var/lib/acme`)
- Nginx state (`/persistent/var/lib/nginx`)
- Home subdirs (`.ssh`, `src`, `vault` — defined subdirs, NOT entire home)

**Explicitly excluded from steady-state restic:** jellyfin media files, transmission downloaded torrents, syncthing synced data. These are replaceable or too large for routine offsite backup.

## Key Files

```
modules/hosts/<host>/
├── default.nix           # nixosSystem instantiation
├── configuration.nix     # imports, host-specific config
├── disko.nix             # partition layout
├── hardware.nix          # boot, kernel modules, firmware
└── preservation.nix      # only puck has this currently; will become shared module

modules/features/
├── john.nix              # Shared user module — all hosts (shell, sudo, groups, linger)
├── network.nix           # SSH authorized keys — all hosts
├── safe-atuin.nix        # Isolated atuin for thoth (no sync, no secrets)
├── impermanence.nix      # TO BE DELETED — replaced by preservation module
├── preservation.nix      # TO BE CREATED — shared base, replaces impermanence.nix
├── restic.nix            # hostname-switched backup config
├── sops.nix              # all hosts post-migration (references /persistent)
├── sops-legacy.nix       # TO BE DELETED — merged into sops.nix
├── jellyfin.nix          # currently overrides dataDir → will use NixOS defaults
├── transmission.nix      # currently overrides home → will use NixOS defaults
├── mealie.nix            # currently overrides DATA_DIR → will use NixOS defaults
├── syncthing-lead.nix    # currently overrides dirs → will use NixOS defaults
└── nginx.nix             # contains security.acme global config

TODO.md                   # consolidated plan file (TODO.md + TODOS.md merged June 2026)
```
