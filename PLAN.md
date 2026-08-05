# Mortlake

Personal monorepo for all code and configs. Named after John Dee's house at Mortlake — library, workshop, observatory.

> **Source repo:** Corpus (`~/src/corpus`) is the predecessor. Reference it for working patterns. Don't copy blindly — write clean new modules, grab from corpus only when the code helps. Keep the dendritic pattern (import-tree auto-discovery) and wrapper-modules for package wrapping.

## Quick Facts

- **Visibility:** Public (sops handles all real secrets)
- **Pattern:** Dendritic — every `.nix` under `modules/` auto-discovered by `import-tree`
- **Wrapped packages:** Use `wrapper-modules.lib.wrapPackage` for tools needing config injection (atuin, ghostty, niri, etc.)
- **Secrets:** sops-nix with age keys derived from SSH host keys via `ssh-to-age`
- **Build:** `nixos-rebuild switch --flake .#<host>`

## Hosts

| Host | Role | Status |
|------|------|--------|
| **Uriel** (was thoth) | Hetzner VPS — Hermes, Pi unconstrained, herdr, nginx, podman | Rename |
| **Jehoel** (replaces mab) | Server + desktop — Jellyfin, Transmission, Mealie, Syncthing, Sunshine, AMD GPU | New |
| **Raphael** (was puck) | Framework 12 laptop — daily driver, Niri desktop | Rename |
| **Raziel** | Android phone (GrapheneOS) — nix-on-droid | New |
| **Haniel** | Android phone (vanilla Android) — nix-on-droid | New |

## What Lives Here

- **`modules/`** — NixOS config (dendritic pattern). Feature modules + host configs.
- **`skills/`** — Agent skills for Hermes/Pi (~65 SKILL.md files)
- **`sites/`** — Personal static sites (`dev-resume/` — Hugo, johnotwell.com)
- **`android/`** — GrapheneOS + vanilla Android provisioning scripts, profiles, nix-on-droid configs

## What Stays Out

- **career-ops** — Public project (santifer/career-ops)
- **logbook** — Markdown knowledge base (`~/vault/logbook`)
- **Titania** — Future host, not yet started

---

# Implementation Plan

Work in steps. Phases are ordered by dependency — later phases import modules from earlier ones.

## Phase 1: Foundation ✅

- [x] `git init`
- [x] `flake.nix` — mkFlake + import-tree (same pattern as corpus). Includes `nix-on-droid` input.
- [x] `modules/parts.nix` — systems list (x86_64-linux, aarch64-linux, aarch64-darwin)
- [x] `.sops.yaml` — age key anchors (carried from corpus, will update as hosts are renamed)
- [x] `.gitignore` — Nix results, Hugo/node build artifacts, agent state dirs
- [x] Directory structure created
- [ ] `nix flake lock` — generate initial lock file

## Phase 2: Core modules

Write these first — everything else depends on them. Each `.nix` is a self-contained flake-parts module, auto-discovered by import-tree.

### System infrastructure

- [ ] **`preservation-common.nix`** — import preservation module, tmpfs-root dirs (`/tmp`, `/var/lib/nixos`, `/var/log`), machine-id, user dirs (`.ssh`, `.cache`, `.npm`). Reference: `corpus/modules/features/preservation-common.nix`
- [ ] **`network.nix`** — firewall, openssh with persistent host keys (`/persistent/etc/ssh/...`), sshd boot-race fix (tmpfiles ordering + preStart guard). Drop hardcoded thoth IP — use a host-level ssh config block or sops. Move authorized_keys out of this module (they're user keys, not network config) — keep in `john.nix` or a separate file. Reference: `corpus/modules/features/network.nix`
- [ ] **`sops.nix`** — import sops-nix, `age.sshKeyPaths = [ "/persistent/etc/ssh/ssh_host_ed25519_key" ]`, declare all secrets with `owner = "john"`. **Drop `sops-legacy.nix` entirely.** Reference: `corpus/modules/features/sops.nix`
- [ ] **`john.nix`** — user definition, `mutableUsers=false`, sudo NOPASSWD, ssh key generation activation script. **Depends on:** `zsh.nix` must exist first (sets `shell = "${self.packages...zsh}/bin/zsh"`). Reference: `corpus/modules/features/john.nix`
- [ ] **`clock.nix`** — timezone `America/New_York`. Trivial.

### Packages & tooling

- [ ] **`packages.nix`** — merge common/config/dev-packages into one module. Core (curl, wget, vim, ghostty.terminfo), Nix tooling (age, sops, direnv, nh, check-jsonschema, ssh-to-age, nickel), Dev (bat, bun, fd, fzf, git, jujutsu, just, nodejs, pandoc, python313, uv, tre-command).
- [ ] **`nix-qol.nix`** — nix gc, auto-optimise, flake registry. **Must keep:** `programs.nix-ld` (critical — MCP servers and Pi tools use `LD_LIBRARY_PATH = "/run/current-system/sw/share/nix-ld/lib"`) and `services.envfs.enable` (provides `/usr/bin/env`). Keep `cache.otwell.dev` substituter if nix-serve is deployed (it is — Phase 6). Reference: `corpus/modules/features/nix-qol.nix`
- [ ] **`dev-dirs.nix`** — tmpfiles rules for `~/src`, `~/vault`, `~/vault/logbook`, `~/vault/book-of-thoth`, `~/reference-repos`. Preservation + restic paths. Note: `book-of-thoth` path is referenced by hermes.nix (`skills.config.wiki.path`) — keep consistent. Sets `mortlake.restic.paths`. Reference: `corpus/modules/features/dev-dirs.nix`
- [ ] **`git.nix`** — git config with direnv. Reference: corpus.
- [ ] **`gh.nix`** — wrapped gh with sops auth (`gh-oauth-token` template → `/etc/gh/hosts.yml`). Reference: corpus (good pattern).

### Shell & editor (wrapped packages — bring co-located configs!)

- [ ] **`zsh.nix`** — wrapped zsh. **Co-located files:** `zshrc.zsh` (uses `@intelli_shell@` substitution). **Must update:** `NH_FLAKE` path from `$HOME/projects/corpus` → `$HOME/src/mortlake`. **Must update:** `SOPS_AGE_KEY_FILE` if set (corpus sets it to `/var/lib/sops-nix/key.txt` — likely vestigial, the `age.sshKeyPaths` approach in sops.nix is the correct one). **Depends on:** `intellishell.nix`. Reference: `corpus/modules/features/zsh.nix`
- [ ] **`intellishell.nix`** — deploys `/etc/intellishell/config.toml`, persists `~/.local/share/intelli-shell`. Referenced by `zshrc.zsh`. Reference: `corpus/modules/features/intellishell.nix`
- [ ] **`helix.nix`** — wrapped helix. **Co-located files:** `helix/config.toml`, `helix/languages.toml`, `helix/schemas/config.schema.json`, `helix/schemas/languages.schema.json`. Reference: corpus.
- [ ] **`zellij.nix`** — wrapped zellij. **Co-located files:** `zellij/config.kdl`, `zellij/layouts/default.kdl`, `zellij/layouts/dev.kdl`. Reference: corpus.
- [ ] **`atuin.nix`** — merged atuin + safe-atuin into one module with sync option. Sync version needs sops secrets (`atuin-username`, `atuin-password`, `atuin-key` from `supersecrets.yaml`) and `systemd.services.atuin-login` oneshot. No duplication. Reference: both `corpus/modules/features/atuin.nix` and `safe-atuin.nix`.

### Build tooling

- [ ] **`treefmt.nix`** — import treefmt-nix flakeModule, nixfmt + statix + deadnix. Reference: corpus.
- [ ] **`devshell.nix`** — git-hooks-nix flakeModule. Reference: corpus.
- [ ] **`restic.nix`** — per-host backup to B2. **Rename option:** `corpus.restic` → `mortlake.restic`. **Must also update:** all modules that set `mortlake.restic.paths`/`.exclude`: `dev-dirs.nix`, `jellyfin.nix`, `transmission.nix`, `mealie.nix`, `syncthing-lead.nix`. **Must rename secret keys:** `thoth-restic-password` → `uriel-restic-password`, `mab-restic-*` → `jehoel-restic-*`, `puck-restic-*` → `raphael-restic-*` in `supersecrets.yaml`. hostConfig entries for uriel, jehoel, raphael. Reference: `corpus/modules/features/restic.nix`

## Phase 3: AI tooling modules

Write these before host configs that import them.

- [ ] **`herdr.nix`** — install on all NixOS hosts. Persist `~/.config/herdr`, `~/.local/share/herdr`. Per-user integration install happens after first boot (`herdr integration install pi`, `herdr integration install hermes`). Check nixpkgs availability — may need flake input or manual install.
- [ ] **`pi.nix`** — Pi agent. Persist `~/.pi`. Needs API keys via sops template (`pi-env`: GLM_API_KEY, OPENROUTER_API_KEY, EXA_API_KEY). Check whether `pi` is in nixpkgs or needs installer script. Include `codebase-memory-mcp` in systemPackages here (moved from codex-safe so it's available regardless of Codex). **Skills/extensions:** all Pi settings, skills, and extensions live in `~/src/mortlake/` — `.pi/skills/` and `.pi/prompts/` are project-local in the repo. **Shared skills:** Pi and Hermes both read from `~/src/mortlake/skills/` as canonical source. **Cognee endpoint:** set `COGNEE_API_URL` environment variable pointing at the Cognee service (host-configurable).
- [ ] **`cognee.nix`** — shared memory layer for ALL agents (Hermes + Pi on all hosts). Postgres 17 + pgvector backend. Cognee API on `:8000` (systemd user service). fastembed local embeddings, GLM via Z.AI for entity extraction. See [agent architecture](./docs/agent-architecture.md) and [cognee setup plan](./docs/cognee-setup-plan.md). **Host:** configurable via module option (Uriel or Jehoel). Endpoint passed to all agent configs via sops template.
- [ ] **`openshell.nix`** — sandboxed Pi runtime for raphael/jehoel. Needs podman or docker. Check nixpkgs availability.
- [ ] **`hermes.nix`** — Hermes on uriel only. **Co-located file:** `hermes_soul.md`. **Trimmed MCP servers:** ouroboros, codebase-memory, context (neuledge), exa, nixos, gitmcp. **Remove:** mempalace, codegraph, procontext, agentmemory. **Must keep (non-MCP settings):** model config (provider/model/context_length=1048576), fallback_model, STT/TTS config, smart_model_routing, session_reset (discord idle 180min), provider_routing, compression, memory settings (char limits), skills config (`external_dirs = ["/etc/codex/skills", "~/src/mortlake/skills"]`, `wiki.path = "/home/john/vault/book-of-thoth"`), `extraDependencyGroups = ["exa", "messaging", "tts-premium", "voice"]`, systemd service env (`LD_LIBRARY_PATH` with libopus + stdenv.cc.cc.lib, `CODEX_HOME=/etc/codex`), path entries (binutils, codex, nodejs). **Cognee:** add HTTP client for shared memory (curl-based, not MCP). Reference: `corpus/modules/features/hermes.nix`
- [ ] **Drop:** `codex-free.nix`, `codex-zai-proxy.nix`, `codex-safe.nix`, `codex-shared/` (Codex dropped — Pi is primary coding agent), `opencode.nix` (superseded by Pi), `opencode/` directory.

**Why Codex is dropped:** Pi is the primary coding agent with native Z.AI support built in — the `zai` provider already uses `baseUrl: https://api.z.ai/api/coding/paas/v4` with correct compat flags (`thinkingFormat: "zai"`, `supportsDeveloperRole: false`). Just `/login zai` and `/model glm-5.2` in Pi. No proxy, no translation layer, no separate Codex skeleton needed.

**Z.AI policy awareness (Issue #4187):** Z.AI's coding plan is "strictly limited to officially supported tools." Pi is not on the supported list (Hermes/OpenClaw IS, best-effort tier). Wire traffic from Pi looks like stock OpenAI SDK, which Z.AI may flag. Most users report no issues, but be aware throttling/ban risk exists after 3 violations. Alternative: use general API endpoint (`/api/paas/v4`) via `czottmann/pi-zai-api` extension if on pay-as-you-go.
- [ ] **`ouroboros.nix`** — config deployment only (invoked via `uvx`). **Co-located:** `ouroboros/config.yaml`. Reference: corpus.

## Phase 4: Desktop modules

- [ ] **`niri.nix`** — wrapped niri (~270 lines of keybinds). Reference: corpus (good as-is).
- [ ] **`greetd.nix`** — niri-session auto-login + tuigreet fallback. Reference: corpus.
- [ ] **`ghostty.nix`** — wrapped ghostty. **Co-located file:** `ghostty/config.ghostty`. Reference: corpus.
- [ ] **`noctalia.nix`** — wrapped noctalia launcher. **Co-located files:** `noctalia.json` (709 lines), `schemas/noctalia.schema.json`. Reference: corpus.
- [ ] **`browser.nix`** — nyxt + ungoogled-chromium + **persistence** (was missing in corpus). Persist `.config/chromium`, `.config/nyxt`, `.local/share/nyxt`, `.cache/nyxt`. `programs.chromium.extensions` for KeePassXC-Browser (`oboonakemofpalcgghocfoadofidjkkk`) + uBlock Origin (`cjpalhdlnbpafiamejdnhcphjbkeiagm`). Disable Chromium password manager (`PasswordManagerEnabled = false`). Register KeePassXC native messaging host for Chromium.
- [ ] **`nyxt-config.lisp`** — declarative Nyxt config with built-in KeePassXC password interface (`password-keepassxc.lisp`). TODO: expand with keybindings, search engines, commands.
- [ ] **`gui-packages.nix`** — anki, keepassxc (not proton-pass), librewolf, logseq, meld, okular, vlc. No zed-editor. No zed/garnix cache config. Note: may need `permittedInsecurePackages = [ "electron-39.8.10" ]` for logseq/anki.
- [ ] **`sound.nix`** — pipewire, rtkit. Reference: corpus.
- [ ] **`nerd-fonts.nix`** — fonts. Reference: corpus.
- [ ] **`sunshine.nix`** — game streaming server (jehoel only). Vulkan/VAAPI packages, firewall ports (47984-48010), persist `~/.config/sunshine`.
- [ ] **`the-aether.nix`** — NetworkManager WiFi profile with sops secret. Needed on raphael (laptop). **Co-located:** references `supersecrets.yaml` for `the-aether-pw`. Reference: corpus.
- [ ] **AMD GPU config** — in jehoel `hardware.nix`. `amdgpu` kernel module, `hardware.graphics.enable`, RADV. Set `opencl = false` for 5700 XT (RDNA1). Flip to `true` when 7900 XTX goes in.
- [ ] **`herald.nix`** — TUI email client ([herald-mail.app](https://herald-mail.app)). **Not in nixpkgs, no upstream flake — requires a local `buildGoModule` derivation.** Chosen over himalaya because Herald handles Proton Bridge's non-standard TLS cert (CA-as-end-entity) without issue, while himalaya's rustls stack hard-rejects it (unreleased fix as of mid-2026). Build requires Go 1.25+ and CGO (SQLite). Config at `~/.herald/conf.yaml` (IMAP/SMTP creds → sops, `chmod 600`). Persist `~/.herald/` (SQLite cache + config). Optional: Ollama integration for semantic search/classification. MCP server via `herald mcp`. First-run wizard handles Gmail OAuth or IMAP presets (Proton Bridge, Fastmail, iCloud, Outlook). Target: raphael (daily driver), optionally jehoel.

## Phase 5: Service modules (jehoel server role)

- [ ] **`nginx.nix`** — nginx with recommended settings, ACME email. Reference: corpus.
- [ ] **`jellyfin.nix`** — service + firewall port for LAN (8096). Sets `mortlake.restic.paths`. No nginx vhost by default. Reference: corpus but strip nginx.
- [ ] **`jellyfin-public.nix`** — opt-in nginx reverse proxy + TLS. Not imported by default.
- [ ] **`transmission.nix`** — service + done script. **Tracker pattern from sops** (`torrent-tracker-pattern` template). Rename script `copy-torrent-to-syncthing`. Sets `mortlake.restic.paths`. Reference: corpus but sanitize tracker.
- [ ] **`mealie.nix`** — recipe manager. Sets `mortlake.restic.paths`. Reference: corpus.
- [ ] **`syncthing-lead.nix`** — lead node (jehoel). **Device IDs from sops** (not hardcoded). **Rename:** puck→raphael, pixel→raziel/haniel, mab→jehoel device labels. **GUI password hash** → move to sops. Sets `mortlake.restic.paths`. Reference: corpus.
- [ ] **`syncthing-follow.nix`** — follower node (raphael). Reference: corpus.
- [ ] **`dd-client.nix`** — Porkbun DDNS. Clean domains list: `cache`, `mealie`, `jehoel`, `syncthing` only. Drop dead: airsonic, calibre, ha, jellyfin. Rename mab→jehoel. Reference: corpus but trim.
- [ ] **`nix-serve.nix`** — binary cache behind nginx. **Co-located:** `nix-serve-key.yaml` (sops). Reference: corpus.
- [ ] **`podman.nix`** — OCI runtime (uriel). Reference: corpus.
- [ ] **Post-build hook** — `nix.settings.post-build-hook` to push to nix-serve cache via SSH. Needed on jehoel (cache host) and raphael (client). Pattern: `nix copy --to ssh://john@jehoel $OUT_PATHS || true`. Reference: mab/puck configs in corpus.

## Phase 6: Host configurations

Host configs import modules from Phases 2–5. Don't start until the needed modules exist.

### Uriel (rename from thoth)

- [ ] Copy `corpus/modules/hosts/thoth/` as starting point, rename module names (`thothHardware`→`urielHardware`, etc.)
- [ ] **Resource limits:** `max-jobs = 1; cores = 1; max-substitution-jobs = 3` (Hetzner VPS constraints)
- [ ] Imports: hermes, podman, nginx, restic, pi (unconstrained), herdr, cognee
- [ ] Update `.sops.yaml`: rename `&thoth` → `&uriel` (same age key — SSH host key doesn't change on rename)
- [ ] `sops updatekeys modules/features/secrets.yaml` + `supersecrets.yaml`

### Raphael (rename from puck)

- [ ] Copy `corpus/modules/hosts/puck/` as starting point, rename module names
- [ ] Imports: niri, greetd, ghostty, browser, sound, nerd-fonts, noctalia, the-aether, herdr, pi (OpenShell-sandboxed?)
- [ ] **May need:** `permittedInsecurePackages` for electron apps
- [ ] Update `.sops.yaml`: rename `&puck` → `&raphael`
- [ ] `sops updatekeys` on secret files

### Jehoel (new — replaces mab)

- [ ] Write fresh — 4 files (default.nix, configuration.nix, hardware.nix, disko.nix)
- [ ] Server role: jellyfin (LAN-only), transmission, mealie, syncthing-lead, nginx, nix-serve, dd-client, restic
- [ ] Desktop role: niri, greetd, ghostty, browser, sound, nerd-fonts, noctalia
- [ ] New: sunshine, AMD GPU config (amdgpu, Vulkan/RADV, `opencl = false`)
- [ ] Post-build hook for nix-serve cache
- [ ] **Secrets chicken-and-egg:** Jehoel is a new machine — no age key until first boot. Migration order: provision machine → obtain SSH host key → `ssh-to-age` → add `&jehoel` to `.sops.yaml` → add to creation_rules → `sops updatekeys` → rebuild with secrets.

### Raziel & Haniel (Android — nix-on-droid)

- [ ] **Note on output type:** nix-on-droid uses `flake.nixOnDroidConfigurations.<name>`, not `nixosConfigurations`. The module structure is different: uses `environment.packages` (not `environment.systemPackages`), has its own `pkgs` parameter (`import inputs.nixpkgs { system = "aarch64-linux"; }`), and modules use the nix-on-droid module system (not NixOS modules). import-tree will discover the `.nix` files — the module just needs to set `flake.nixOnDroidConfigurations.<name>` instead of `flake.nixosConfigurations.<name>`.
- [ ] `android/profiles/raziel.yaml` — GrapheneOS profile (de-Googled, F-Droid primary, Aurora for Play-only)
- [ ] `android/profiles/haniel.yaml` — Vanilla Android profile (Play Services present)
- [ ] `modules/hosts/raziel/default.nix` + `configuration.nix` — nixOnDroidConfiguration
- [ ] `modules/hosts/haniel/default.nix` + `configuration.nix` — nixOnDroidConfiguration
- [ ] Shared nix-on-droid common module (factor out shared package list)

### Decommission old hosts

- [ ] Don't copy `modules/hosts/mab/` — comment out `&mab` in `.sops.yaml`
- [ ] Don't copy `modules/hosts/thoth/` after uriel is verified
- [ ] Don't copy `modules/hosts/puck/` after raphael is verified

## Phase 7: Security & public audit

Before flipping repo to public:

- [ ] Verify all secrets in `secrets.yaml` / `supersecrets.yaml` are sops-encrypted (ciphertext only)
- [ ] Verify `.sops.yaml` has only age *public* keys
- [ ] Move tracker pattern to sops (transmission done script)
- [ ] Move Syncthing device IDs to sops
- [ ] Move Syncthing GUI password hash to sops
- [ ] Consider moving password hashes to sops (`hashedPasswordFile`) — optional, they're salted
- [ ] Grep sweep: no `$6$`, `$2y$`, `password =`, `apiKey`, unencrypted IPs in `.nix` files
- [ ] Audit `secrets.yaml` for stale entries: remove `codex-ws-token` (if it still exists), `forge-openrouter-api-key`, `forge-services-api-key` if unused
- [ ] Investigate `&caliban` age key — what is it? Remove if unused, or document.
- [ ] Make repo public: `gh repo edit jbotwell/mortlake --visibility public`

## Phase 8: Sites, skills & Android scripts

- [ ] **Absorb dev-resume** — rsync `~/src/dev-resume/` into `sites/dev-resume/`. Drop unused theme submodules (keep gruvbox). Add Hugo/node build artifacts to `.gitignore` (already in `.gitignore`).
- [ ] **Copy skills** — rsync `corpus/agent-skills/` into `skills/`. Rename `skills/corpus/` → `skills/mortlake/`. Update internal references in skill files that mention corpus paths (`corpus-nixos-modules`, `corpus-ssh-key-management`, etc.).
- [ ] **Copy Android scripts** — rsync `corpus/android/` scripts and `lib/`. Update `android/nix-on-droid/README.md` references from corpus→mortlake. Create raziel/haniel profiles from `pixel-9.yaml` template.
- [ ] **justfile** — already written. Verify `sync-ouroboros-skills` and `sync-feynman-skills` targets use `skills/` path.
- [ ] **Deprecate corpus + dev-resume** — add deprecation notice to both repos, optionally archive on GitHub.

## Phase 9: Documentation

- [ ] **`README.md`** — what mortlake is, build/deploy commands, host layout, secrets, restic, nix-on-droid
- [ ] **`AGENTS.md`** — practical agent guide: dendritic pattern, gotchas, design principles, landing-the-plane workflow. Update from corpus AGENTS.md — change all corpus references, update `NH_FLAKE` path, update skill paths.

---

## Key dependency graph (write in this order)

```
Phase 2 (core) ──────┬──→ Phase 3 (AI tooling) ──┐
                      │                           │
                      ├──→ Phase 4 (desktop) ─────┤
                      │                           ├──→ Phase 6 (hosts)
                      ├──→ Phase 5 (services) ────┘
                      │
                      └──→ Phase 7 (audit) ──→ make public
                      
Phase 8 (sites/skills) — independent, can run anytime after Phase 1
Phase 9 (docs) — after everything else
```

**Within Phase 2, write in this order:**
1. `zsh.nix` + `intellishell.nix` (shell — others depend on zsh wrapper)
2. `preservation-common.nix`, `sops.nix`, `network.nix` (infra)
3. `john.nix` (depends on zsh)
4. `packages.nix`, `nix-qol.nix`, `git.nix`, `gh.nix` (tooling)
5. `helix.nix`, `zellij.nix`, `ghostty.nix` (editors — bring co-located configs)
6. `atuin.nix` (merged)
7. `restic.nix` (last — others set `mortlake.restic.*`)
8. `dev-dirs.nix`, `treefmt.nix`, `devshell.nix`

---

## Follow-up TODOs

### Learning

- [ ] **Pi** — learn the full feature set: hooks system, TypeScript extensions, `~/.pi/agent/models.json` custom providers, `/login` and `/model` workflows, session management, how it differs from Hermes
- [ ] **Herdr** — learn workspace/tab/pane management, agent state model (idle/working/blocked), session restore, `herdr agent start/stop`, integration install mechanics, per-pane output watching
- [ ] **Zellij** — flesh out config beyond defaults: custom layouts (dev.kdl, default.kdl), floating panes, tab naming, plugin config, keybinding tweaks, integration with herdr panes
- [ ] **Cognee** — learn the API: cognify pipeline, add_data, search, graph queries. How to structure data for best retrieval. How Hermes and Pi make REST calls. See [setup plan](./docs/cognee-setup-plan.md).
- [ ] **OpenShell** — policy YAML format, sandbox lifecycle, how to configure Pi-in-sandbox for raphael/jehoel, network proxy rules

### Config improvements

- [ ] **Wrapped intellishell** — the current `intellishell.nix` deploys a raw `/etc/intellishell/config.toml` and installs the package directly. Wrap it with `wrapper-modules.lib.wrapPackage` like atuin/helix/ghostty so the config is injected via constructFiles and `nix run .#intelli-shell` works standalone.
- [ ] **Exa API raw-access skill** — curl/TS patterns for `/find`, `/contents`, `/answer`, `/get` with filter options (`category`, `text`, `includeDomains`, `excludeDomains`, `startPublishedDate`, `numResults`, `subpages`, `subpageTarget`)

### Skills

- [ ] **Intellishell usage skill** — document the CLI workflow: `intelli-shell add`, `intelli-shell search`, `intelli-shell exec`, inline mode, gist sync, TUI keyboard enhancements. Show how it integrates with zsh (the `@intelli_shell@` init in zshrc). Cover common patterns (tagging commands, searching by tag, fuzzy search modes).

### Deferred

- [ ] **Distributed builds** — Create `remote-builder-client.nix` module so uriel and raphael delegate builds to jehoel via `nix.buildMachines`. Requires SSH key trust between machines. Titania migration plan (corpus `.hermes/plans/2026-07-06_135930-titania-migration.md`) has full task breakdown — adapt host names (titania→jehoel, thoth→uriel, puck→raphael).
- [ ] Declarative Nyxt config expansion (keybindings, search engines, commands, theme)
- [ ] Flatpak/appimage/printing modules — decide whether to include for jehoel/raphael
