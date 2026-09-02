# Impermanence Operational Reference

## How It Works

`environment.persistence."/persist".directories` creates **bind mounts** at boot. The real data lives at `/persist/var/lib/hermes`, and `/var/lib/hermes` becomes a transparent mount point over it. Processes see the same path, same contents, same permissions.

This is NOT a file-level whitelist — it's "this entire directory tree, forever."

## Migration Order

When enabling impermanence on a host that already has data:

1. Copy existing data to `/persist` paths BEFORE rebuilding
2. Then rebuild — the bind mount will shadow the old location

```bash
mkdir -p /persist/var/lib/hermes
cp -a /var/lib/hermes/. /persist/var/lib/hermes/
```

If you rebuild before migrating, the bind mount overlays an empty `/persist` dir over the existing data — the old data is still on disk but inaccessible through the mount point.

## Rollback Conditionalization Pattern

Use `lib.mkOption` + `lib.mkMerge` + `lib.mkIf` to make initrd rollback opt-in:

```nix
options.impermanence.rollbackLabel = lib.mkOption {
  type = lib.types.nullOr lib.types.str;
  default = null;  # no rollback unless explicitly set
};

config = lib.mkMerge [
  { /* shared persistence declarations */ }
  (lib.mkIf (cfg.rollbackLabel != null) {
    boot.initrd.systemd.services.btrfs-rollback = { ... };
  })
];
```

Hosts with ephemeral root (mab) set `impermanence.rollbackLabel = "mab-root"`.
Hosts without rollback (thoth) just get the persistence bind mounts.

## Commented Config for Future Activation

When a host will eventually use impermanence but isn't ready yet, keep the host-specific directory entries commented in the host's `configuration.nix`:

```nix
# environment.persistence."/persist".directories = [
#   "/var/lib/hermes"
#   "/var/lib/hindsight"
# ];
```

These lines can't be live without importing the impermanence module (the option won't exist). Uncomment + add the import in the same commit when ready.

## Host Layout (Current — Being Replaced)

All hosts are migrating from `impermanence` to `preservation` with tmpfs root. Once complete, this module and its rollback service will be deleted.

| Host | Rollback | Persistence | Imported |
|------|----------|-------------|----------|
| mab  | yes (`mab-root`) | base + acme + nginx | yes |
| thoth| yes (`thoth-root`) | base + hermes + codex + containers + acme + nginx | yes |

Post-migration: `impermanence.nix` deleted, `impermanence` flake input removed, rollback service gone, tmpfs `/` on all hosts.

## Shared Base Directories

These are in `impermanence.nix` and apply to all hosts that import it:
- `/var/log`
- `/var/lib/nixos`
- `/home/john/vault`, `/home/john/src`
- SSH host keys, machine-id
