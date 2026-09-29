# Agent Architecture

Confirmed architecture for coding agents, memory, and skills across all hosts.

## Roles

| Agent | Host(s) | Role |
|-------|---------|------|
| **Pi** (pi.dev) | Uriel (primary), Jehoel, Raphael | Primary coding agent. User interacts with Pi directly. herdr multiplexes parallel Pi sessions. |
| **Hermes** | Uriel only | Discord-connected assistant (same as this one). MCP-enabled. |
| **Codex** | Uriel | Secondary, heavy coding only. Skeleton deployment. |

## Memory — Cognee (uriel, cognee.otwell.dev)

All agents (Hermes + pi + prime-agent on all machines) talk to a shared Cognee server.

- **Server:** uriel, `modules/features/cognee.nix` — uv venv (`cognee[api]==1.6.1`), systemd `cognee.service` behind nginx + ACME at `https://cognee.otwell.dev`
- **Storage:** upstream file-based defaults (SQLite relational + LanceDB vector + Kuzu graph) under `/persistent/var/lib/cognee` — no Postgres (upstream flipped defaults to file-based; July Postgres plan superseded)
- **LLM:** GLM 5.3 via Z.AI (entity extraction during cognify); **Embeddings:** fastembed default, local ONNX CPU
- **Auth:** single admin user; shared API key in sops (`cognee-api-key`) → `/run/secrets/cognee-api-key` on every host; `X-Api-Key` header
- **MCP proxy:** `cognee-mcp.service` on uriel (podman, digest-pinned `cognee/cognee-mcp`, API mode → 8010, binds 127.0.0.1:8012) behind nginx `https://cognee.otwell.dev/mcp` — token-gated (`cognee-mcp-token` in sops; `?token=` or `Authorization: Bearer`)
- **Clients:** Hermes (uriel) = official memory-provider plugin, remote mode, active provider `cognee`; pi/prime-agent (all hosts) = `@kerryhatcher/pi-cognee` extension, MCP mode; anything else = curl (`X-Api-Key`)
- **Backup:** daily restic on uriel includes `/var/lib/cognee`, with cognee.service stopped around the snapshot for consistent file stores

## Intelligence Stack (Pi — CLI-first, no MCP)

| Tool | Function | How Pi calls it |
|------|----------|-----------------|
| Cognee | Memory + knowledge graph synthesis | HTTP to Cognee API |
| neuledge/context | Library/framework docs | CLI `context` command |
| codebase-memory-mcp | Codebase graph (symbols, calls, dependencies) | CLI or MCP server (Pi uses CLI) |
| GitMCP | Fallback docs for GitHub repos | CLI |

## Hermes MCP Servers (Uriel only)

Hermes keeps MCP servers that Pi can't use:
- codebase-memory
- context (neuledge)
- exa (web search)
- nixos
- gitmcp

## Skills — Two Parallel Systems

### Canonical shared skills (`~/src/mortlake/skills/`)
- 69 SKILL.md files currently
- **Source of truth for all code agents** — both Pi and Hermes read from here
- Version-controlled in mortlake repo
- Covers: NixOS patterns, debugging, research, SRS, note-taking, autonomous agents, etc.
- Both Pi and Hermes configured to load skills from this directory

### Hermes self-managed skills (`~/.hermes/skills/`)
- Hermes' native skill system — editable by Hermes at runtime (I can create/patch/delete these)
- Runs **in parallel** to the canonical skills
- For Hermes-specific operational skills that don't apply to Pi (Hermes tool workflows, platform-specific behaviors)
- Not shared with Pi

### Pi skills/extensions
- All Pi settings, skills, and extensions live in `~/src/mortlake/`
- Pi skills directory: `.pi/skills/` (project-local, read from mortlake)
- Pi prompts: `.pi/prompts/` (slash commands)
- Pi extensions: installed via `pi install`, configured in mortlake-managed config

## Pi Config in Mortlake

Pi needs a NixOS module (`modules/features/pi-agent.nix` or similar) that:
- Installs Pi CLI (pi.dev npm package or equivalent)
- Points Pi's config/skills/extensions at mortlake paths
- Sets Cognee endpoint environment variable
- Configures herdr integration (lifecycle hooks)
- Persists Pi state directories (sessions, caches)
- Shares the `mortlake/skills/` directory with Hermes

## What Needs Updating in PLAN.md

1. **`gbrain.nix` → `cognee.nix`** — gbrain module was dropped (superseded by cognee; never imported by any host). The [cognee setup plan](./cognee-setup-plan.md) is the reference doc.
2. **Add `pi-agent.nix` module** — Not currently in PLAN.md. Needs to be in Phase 3 or 4 (package/tooling tier).
3. **Cognee scope** — The cognee setup doc says "memory for Pi". Update to "shared memory for all agents (Hermes + Pi on all hosts)".
4. **Skills config** — Ensure Hermes module's `skills.config.external_dirs` includes `~/src/mortlake/skills/`. Pi module points at the same directory.
5. **Hermes Cognee client** — Add Cognee HTTP calls to Hermes config (tool or curl-based, not MCP).
