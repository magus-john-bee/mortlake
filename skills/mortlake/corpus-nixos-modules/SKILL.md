---
name: corpus-nixos-modules
description: Corpus-specific module patterns — shared vs host-specific splits, hostname switching, NixOS list merging, conditional options, persistence migration plan, security-tiered modules, dead module cleanup, PR scope discipline, systemd PATH debugging, and agent skills architecture. Use this for HOW corpus organizes its NixOS config. For the underlying dendritic pattern (cross-referencing rules, boilerplate, file layout reference), use dendritic-pattern instead.
version: 1.0.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [nix, nixos, corpus, module-patterns, dendritic]
    related_skills: [import-tree-debugging, sops-nix-usage, restic-backblaze-b2, nixos-rebuild-dry-run, memory-landscape]
---

# Corpus NixOS Module Patterns

Corpus uses the **dendritic pattern**: every `.nix` file under `modules/` is a self-contained flake-parts module, auto-discovered by `import-tree`. No manual imports, no relative paths.

## Module Organization Principle

**One module per service. Switch on hostname for the small number of things that aren't shared.**

Shared infrastructure goes in `modules/features/<service>.nix`. Host-specific configuration (paths, services, options) lives in `modules/hosts/<host>/configuration.nix`.

### Shared Module with Hostname Switching

When a service needs different config per host (backup paths, credentials, etc.), use a `hostConfig` attrset keyed by hostname:

```nix
flake.nixosModules.restic = { config, ... }:
  let
    hostName = config.networking.hostName;
    hostConfig = {
      thoth = { repository = "..."; paths = [ ... ]; };
      mab   = { repository = "..."; paths = [ ... ]; };
    };
    cfg = hostConfig.${hostName};
  in { services.restic.backups.${cfg.name} = { ... }; };
```

This keeps one file per service while handling per-host differences declaratively.

### Host-Specific Additions via NixOS List Merging

NixOS automatically merges list-valued options across modules. Use this to add host-specific entries to shared declarations:

```nix
# In shared impermanence.nix:
environment.persistence."/persist".directories = [ "/var/log" "/var/lib/nixos" ];

# In mab/configuration.nix:
environment.persistence."/persist".directories = [ "/var/lib/acme" "/var/lib/nginx" ];

# Result: all five directories are persisted.
```

**Rule**: shared base dirs in the feature module, service-specific dirs in the host config. This keeps the shared module honest — only things every host needs.

### Conditional Features via mkOption + mkMerge

For features that only some hosts activate (e.g., BTRFS rollback), define an option and use `lib.mkIf`:

```nix
options.impermanence.rollbackLabel = lib.mkOption {
  type = lib.types.nullOr lib.types.str;
  default = null;
};

config = lib.mkMerge [
  { /* shared config */ }
  (lib.mkIf (cfg.rollbackLabel != null) {
    /* conditional config — only when option is set */
  })
];
```

Hosts opt in by setting the option in their `configuration.nix`. No boolean flags, no `lib.mkIf config.services.foo.enable` hacks.

## Flake-Parts Module Structure: perSystem vs nixosModules

Every `.nix` file under `modules/` is a flake-parts module, but **the sections you define determine what's available to import**:

- `flake.nixosModules.<name>` — creates a NixOS module importable via `self.nixosModules.<name>` in host configs
- `perSystem.packages.<name>` — creates a package (buildable via `nix build .#<name>`), but does NOT create a nixosModule

**A file that only defines `perSystem` packages cannot be imported as `self.nixosModules.X`.** If a host's `configuration.nix` lists `self.nixosModules.X` and the file only has `perSystem`, the build fails with `attribute 'X' missing`.

**Pattern — dual-export modules:** Some modules (like niri.nix) define both a `flake.nixosModules.niri` section (for NixOS-level config: services, packages, options) AND a `perSystem` section (for the wrapped package). Other modules (like noctalia.nix) are pure package wrappers with only `perSystem` — these don't need a nixosModule export because the package is pulled in transitively (e.g., niri's `spawn-at-startup` references `myNoctalia`).

**Before adding `self.nixosModules.X` to a host config, verify the module file actually exports `flake.nixosModules.X`.** If the file only defines `perSystem.packages.X`, the package is already available via nix build — it just doesn't need a nixosModule import.

## Cross-Cutting Config in the Dendritic Pattern

The dendritic pattern groups config by service, but some NixOS settings are cross-cutting — they apply to multiple services but aren't a "service" themselves. In corpus, these get folded into the most relevant shared module rather than getting their own file:

- `security.acme` → lives in `nginx.nix` (ACME is used exclusively by nginx vhosts)
- `users.users` → lives in `users.nix`
- `nix.settings` → lives in `nix-qol.nix`

**Implication for searching:** When looking for "where is X configured?", don't assume it has its own module. Search broadly across `modules/features/` — the config may be inside a module named after the primary consumer, not the config itself.

## Multi-Tier Module Splits

When a feature module needs different configurations on different hosts (beyond simple hostname-switched values), split it into role-based modules sharing a common base:

**Pattern:** `codex-server.nix` (full config, app-server, MCP integrations, no guardrails) vs `codex-client.nix` (lighter config, more conservative approval policy, no server, no MCP). Hosts import the tier that matches their role.

**Implementation considerations:**
- Each tier needs its own `config.toml` — the `perSystem` wrapper currently bakes in a single config file. Either create two wrapped packages (`codex-server`, `codex-client`) or make the config path a module option.
- `sops.templates` for API keys can be shared — both tiers need the same keys, just different quantities.
- A shared `codex-common.nix` for the package wrapper and sops env template avoids duplication.
- Server tier: systemd service, firewall port, persistence, MCP servers, skill symlinks. Client tier: just the CLI binary and config.

**Applicable when:** a service has a clear "host vs consumer" split, one host serves (websocket, HTTP, etc.) and others connect to it.

## Grab-Bag Module Remediation

A module that bundles unrelated concerns (packages, SSH, firewall, GC, nix settings) violates the one-module-per-service principle. When refactoring:

1. **Identify the seams** — list each concern and check for existing dedicated modules (e.g., `nix-qol.nix` may already cover `nix.settings`).
2. **Check for duplication** — grab-bag modules often duplicate settings also declared in host configs (e.g., `common.nix` has `services.openssh.enable` and so does `mab/configuration.nix`).
3. **Split into focused modules** — `ssh.nix`, `nix-gc.nix`, `firewall.nix`, fold packages into existing `dev-packages.nix` / `config-packages.nix`.
4. **Preserve the import name** — either make `common.nix` a meta-import of the new modules (hosts keep `self.nixosModules.common`) or update all host configs to import the individual modules.
5. **Check commented-out imports** — hosts that commented out `common` (e.g., puck) may want specific subsets after the split.

## Key Conventions

- **Persist mount point**: All hosts use `/persistent`. (Legacy `/persist` is being retired.)
- **Persistence framework**: All hosts use `preservation` (nix-community/preservation) with tmpfs root. Legacy `impermanence` + btrfs rollback is being removed.
- `environment.persistence."...".directories` entries are bind-mounted as entire directory trees — anything created inside them at runtime is safe, not just what existed at declaration time.
- Feature modules define shared base + conditional logic. Host configs add host-specific entries and set options.
- When a host isn't ready to use a module yet (e.g., thoth and impermanence), keep the host-specific entries commented in the host config rather than importing the module prematurely.
- **Service data dirs**: Services MUST use their default NixOS directories (e.g., `/var/lib/jellyfin`), with those directories listed in the host's preservation config. Do NOT override `dataDir`/`home`/`DATA_DIR` to point under `/persistent` — that pattern is retired.
- **LUKS**: Only puck (laptop) gets LUKS. Cloud VMs (thoth) don't benefit — the hypervisor can read RAM. Physical servers (mab) don't need it unless threat model justifies the unlock hassle.
- **Re-imaging**: Use `nixos-anywhere` for both cloud (thoth, Hetzner) and physical (mab) hosts. For thoth, target the Hetzner rescue IP. For mab, expand restic to B2 first, re-disko, then restore.

## Systemd Service Runtime Dependencies

**Problem:** NixOS systemd services (both system and user) run with a minimal PATH — only coreutils, findutils, grep, sed, systemd. Any program the service shells out to must be explicitly added.

**Solution:** Use the `path` key in the service definition:
```nix
systemd.user.services.myservice = {
  path = [ pkgs.curl pkgs.jq config.inputs.somePkg ];
  # ...
};
```

This prepends the packages' `bin/` directories to the service's PATH. Do NOT rely on `environment.systemPackages` — that only affects login shells, not systemd service environments.

**Common missing binaries:**
- `curl` — if the service makes HTTP calls or downloads anything
- `bash` / `sh` — if the service runs shell commands via `execSync("sh", ...)`
- `which` — if the service uses `which` to discover other binaries (Node.js apps commonly do this via `execFileSync("which", [name])`)
- `jq` — if the service parses JSON via CLI
- Any interpreter the service's code shells out to

**Debugging pattern:** When a service says "X not found" but X IS in the unit's PATH, the program may be using a discovery mechanism that itself isn't available:
1. Check the unit file: `cat /etc/systemd/user/<service>.service | grep PATH`
2. Check the logs: `journalctl --user -u <service> -n 30`
3. **Find the actual check in the source before adding more packages.** This avoids iterative trial-and-error rebuilds. Run: `grep -r "not found" /nix/store/.../package-name.../lib/`
4. Node.js: look for `execFileSync("which", ...)`, `which()`, `execSync("sh ...")`
5. Python: `shutil.which()` is pure-Python (no external dep), but `subprocess.run(["which", ...])` is not

**Pitfall — iterative PATH additions:** When a service can't find a binary, the temptation is to add packages to `path` one at a time and rebuild. Each rebuild cycle costs 2-3 minutes. Instead, grep the Nix store source for the error message to find the discovery mechanism, then add ALL needed packages in one shot. One session wasted 3 PRs/rebuilds adding iii+curl, then bash, then which — when reading the source first would have revealed all four were needed immediately.

See `references/systemd-service-path.md` for a worked example.

## Impermanence vs Restic: Keep Separate

These overlap but serve different lifetimes:
- **Impermanence**: "does this survive the next boot?" — bind mounts from `/persist`
- **Restic**: "can I recover this if the disk dies?" — offsite backup to B2

The Venn diagram isn't a circle. Some dirs are persisted but not backed up (large mab media), some are backed up but not persisted (`/home/john` on thoth where root isn't ephemeral). Keep two separate lists — explicit and easy to audit. When adding a directory, add it to both if needed.

## Pitfall — ACME / Let's Encrypt Silent Failure

Setting `enableACME = true` on an nginx virtualHost is necessary but **not sufficient**. Without the global `security.acme` block, NixOS silently skips cert provisioning — nginx serves whatever cert it finds (often a stale self-signed/minica cert), and there is no build-time or runtime error.

**In corpus**, the global `security.acme` block lives in `modules/features/nginx.nix` (not a dedicated ACME module — it rides along with the nginx feature module since ACME is tightly coupled to nginx). Before declaring ACME is "not configured", search broadly: `grep -r "acme\|security\.acme\|acceptTerms" --include="*.nix"` across the whole repo. A narrow `search_files` pattern can return false negatives.

**Required global config** (in `modules/features/nginx.nix`):

```nix
security.acme = {
  acceptTerms = true;
  defaults.email = "johnbee@otwell.dev";
};
```

**Checklist when adding HTTPS to a service:**
1. `enableACME = true` + `forceSSL = true` on the vhost ✓
2. `security.acme.acceptTerms = true` + `defaults.email` globally (in `nginx.nix`) ✓
3. Port 80 open in the firewall (HTTP-01 challenge) ✓
4. DNS for the domain points to this host's public IP ✓
5. `/var/lib/acme` persisted in the host's impermanence config ✓

**Debugging:** If nginx serves a self-signed or minica cert despite `enableACME = true` and `security.acme` being present:
- `systemctl status acme-<domain>.service` — check if the ACME timer/unit ran and succeeded
- `ls /var/lib/acme/<domain>/` — check if a real Let's Encrypt cert was ever issued
- `nginx -T | grep certificate` — see which cert file nginx is actually loading (may be pointing at a stale minica cert)
- Check if a leftover minica/self-signed cert in `/var/lib/acme/<domain>/` or `/etc/ssl/` is being loaded instead of the ACME-provisioned one
- Verify DNS: `dig <domain>` must resolve to the host's public IP at the time of cert issuance

## Persistence Migration (Planned — Decisions Finalized)

Mab and thoth will migrate from `impermanence` + `/persist` + btrfs-rollback to `preservation` + `/persistent` + tmpfs root, matching puck's architecture. Services will use default directories (e.g., `/var/lib/jellyfin`) listed in preservation instead of custom `/persist/<service>` overrides.

### Finalized Decisions

- **No LUKS on servers.** Thoth is a Hetzner cloud VM — the hypervisor can read RAM, so disk encryption is theater. Mab is physically accessible but user decided the unlock hassle isn't worth it for media server workloads.
- **tmpfs root on all machines.** No btrfs `/root` subvol, no initrd rollback service. The `impermanence.nix` module and `impermanence` flake input will be deleted.
- **Common preservation module.** Shared `preservation.nix` feature module for base dirs (machine-id, SSH keys, `/var/log`, `/var/lib/nixos`, user dirs). Machine-specific additions in each host's `configuration.nix`.
- **Consolidate `sops.nix` / `sopsLegacy.nix`.** Single `sops.nix` pointing to `/persistent/etc/ssh/...`, delete `sopsLegacy.nix`.
- **8G swap on mab** (currently none). Thoth keeps existing 2G swap.
- **Services use default dirs.** Remove all custom `dataDir`/`home`/`DATA_DIR` overrides from service modules (jellyfin, transmission, mealie, syncthing). Add the default paths to each host's preservation config.
- **nixos-anywhere for re-imaging.** Both thoth and mab will be re-diskoed.

### Migration Strategy

**Thoth (disposable):** Everything important is in restic. Re-image with `nixos-anywhere`, `restic restore` data. Run a final restic backup immediately before re-diskoing. Add `.codex` to restic paths (after the codex/impermanence PR merges).

**Mab (data migration via B2):** Expand mab's restic config to cover all service data (jellyfin, transmission config, syncthing, acme, nginx, etc.). Let a full backup soak to B2 (short-term storage cost acceptable for ~2 weeks). Re-disko with `nixos-anywhere`, then `restic restore`. After migration, trim restic paths back to what's needed long-term (exclude transmission downloads, large media files).

**Implementation order:**
1. Expand mab restic paths + verify backup completes
2. Create shared `preservation.nix` feature module
3. Update disko configs for mab and thoth (tmpfs root, `/persistent` + `/nix` subvols, no `/root` or `/log` subvols)
4. Remove service data dir overrides (jellyfin, transmission, mealie, syncthing)
5. Add service default dirs to each host's preservation config
6. Consolidate sops.nix, delete sopsLegacy.nix
7. Delete `impermanence.nix` module, remove `impermanence` flake input
8. Re-disko thoth → restore
9. Re-disko mab → restore

**During migration**: some modules may still reference `/persist`, some reference `/persistent`. Check the host's actual config before assuming which is in use.

## Security-Tiered Module Splits (separate files)

When a service needs different security postures on different hosts (e.g., synced shell history on personal machines vs isolated history on a shared/AI host), create **separate module files** rather than cramming both tiers into one file. Each file is a self-contained flake-parts module with its own `perSystem` packages and `flake.nixosModules`.

**Pattern — atuin vs safe-atuin:**
- `atuin.nix` — full atuin with sync enabled, sops secrets, systemd login service. Imported by mab and puck. Contains `packages.atuin` (wrapped, sync on) and `nixosModules.atuin`.
- `safe-atuin.nix` — separate file, same UX (nord theme, fuzzy search, vim keymap) but `auto_sync = false`, no sops secrets, no login service. Imported only by thoth (AI host where the agent shouldn't have access to synced shell history). Contains `packages.safe-atuin` (wrapped, sync off) and `nixosModules.safe-atuin`.

**Why separate files, not one file with two exports:**
- The user explicitly keeps atuin.nix stable for personal machines. The "safe" variant is a distinct security boundary, not a config toggle.
- Different secret requirements (sops vs none) mean different dependency graphs.
- Clearer audit surface: `safe-atuin.nix` has zero secret references.

**Key points:**
- Both use `wrapPackage` for the wrapped variant — full theme, keymaps, etc. Not a raw TOML file.
- A top-level `let ... in { self, inputs, ... }:` is fine — `import-tree` handles it.
- New files must be `git add`-ed before `nix flake show` discovers them.

## Shared User Module Pattern

All hosts share `john.nix` for user config. It provides: wrapped zsh shell, passwordless sudo, linger, trusted-users, default hashed password, networkmanager+wheel groups.

**Host-specific overrides** use `lib.mkForce` in the host's `configuration.nix`:
```nix
# thoth has a separate password
users.users.john.hashedPassword = lib.mkForce "$6$ws2Z1s...";
```

**SSH authorized keys** live in `network.nix` (not per-host user modules). All hosts import `network.nix` and get the same keys (john@nixos, john@puck). Do NOT duplicate keys in per-host user files.

**Pattern:**
- `john.nix` — shared user definition (shell, sudo, groups, linger, default password)
- `network.nix` — SSH authorized keys for all hosts
- Host `configuration.nix` — `lib.mkForce` overrides for anything host-specific

**When consolidating per-host user modules into `john.nix`:**
1. Verify the host imports `network.nix` (for SSH keys)
2. Check for host-specific `hashedPassword` — move to host config with `lib.mkForce`
3. Check for inline `security.sudo.extraRules` in host config — remove (john.nix handles it)
4. Check for shell overrides — remove (john.nix sets wrapped zsh)
5. Delete the old per-host user module
6. Update host imports: `self.nixosModules.thoth-users` → `self.nixosModules.john`
7. Build all three hosts to verify

## Dead Module Cleanup

Before deleting a feature module, verify it has zero consumers:

```bash
# Check if the module is imported anywhere
grep -rn 'nixosModules.<module-name>' modules/hosts/
```

If the grep returns nothing, the module is dead code. Common cases:
- Modules replaced by a consolidated version (e.g., `puck-users.nix` replaced by `john.nix`)
- Modules whose host migrated to a different module (e.g., `thoth-users.nix` → `john.nix`)
- Packages no longer referenced by any NixOS module (e.g., `packages.atuin-no-sync` after thoth moved to `safe-atuin`)

When removing dead packages from `perSystem`, also remove any helper `let` bindings that only the dead package used (e.g., a shared `tomlFmt` helper that only `atuin-no-sync` needed).

## Scope Discipline for PRs

Each logical change gets its own branch and PR. Do NOT push unrelated changes to an existing feature branch — even if the branch is a "plan" branch with other work queued.

**Workflow:**
1. Start from `main` for each new PR
2. If working on an existing branch and the change is unrelated, create a new branch from `main` and cherry-pick
3. If you accidentally pushed to the wrong branch, revert the commit on that branch and open a proper PR
4. Confirm with the user which branch/PR a change belongs to before pushing

**Anti-pattern:** Pushing a cleanup commit to a planning branch (e.g., `plan/persistence-unification`) because it happens to be checked out. This creates messy revert commits and confuses the PR history.

## Shared Agent Skills Directory

The top-level `agent-skills/` directory holds custom skills that are part of tool configuration and shared across agents (Hermes + Codex). These are versioned with corpus because they represent infrastructure configuration, not agent runtime state.

**Configuration:**
- **Hermes** reads them via `skills.external_dirs` in `hermes.nix` (read-only)
- **Codex** reads them via `environment.etc` at `/etc/codex/skills` → `agent-skills/` (ADMIN scope)
- Skills in `agent-skills/` are committed to corpus and deployed via `nixos-rebuild`
- New skills here require `git add` before they're visible to agents

**Agent-created skills** (auto-generated at runtime) still land in `/var/lib/hermes/.hermes/skills/`. Corpus skills are user-directed only — you decide what goes there.

See `skill-crafting` for the full two-tier architecture documentation.

## Detailed References

- `references/hosts-architecture.md` — three-host inventory, current vs planned persistence state, service default directories, disko layouts, key file map
- `references/impermanence.md` — operational details: bind mount mechanics, migration order, rollback patterns
- `references/systemd-service-path.md` — worked example: debugging "binary not found" in systemd services when PATH looks correct

## File Layout

```
.
├── agent-skills/        # Custom skills shared across agents (Hermes + Codex)
│   └── .gitkeep
├── modules/
│   ├── features/           # Shared service modules (one per service)
│   ├── john.nix        # Shared user module (shell, sudo, groups) — all hosts
│   ├── network.nix     # SSH authorized keys — all hosts
│   ├── atuin.nix       # Full atuin: sync + sops login (mab, puck)
│   ├── safe-atuin.nix  # Isolated atuin: no sync, no secrets (thoth only)
│   ├── restic.nix      # Hostname-switched
│   ├── hermes.nix
│   └── ...
└── hosts/
    ├── thoth/
    │   ├── configuration.nix  # Host-specific: hashedPassword override, nix limits
    │   ├── disko.nix
    │   └── hardware.nix
    ├── mab/
    │   └── configuration.nix  # Host-specific: persistence dirs, extra packages
    └── puck/
        └── configuration.nix # Host-specific: networkmanager, niri, greetd
```
