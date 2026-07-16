---
name: agentmemory-setup
description: How agentmemory is deployed in corpus — the iii-engine service, Hermes plugin, and Codex MCP integration. Covers npm package requirements, common failure modes (wrong package, missing tar, false OOM), and verification steps. Use this when debugging or modifying agentmemory.
category: corpus
version: 1.0.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [nixos, corpus, agentmemory, mcp, memory, iii-engine]
    related_skills: [corpus-nixos-modules, memory-landscape]
---

# Agentmemory Setup in Corpus

Agentmemory provides persistent cross-session memory for AI agents. It runs on thoth only (resource-constrained Hetzner VPS, 1.9G RAM). Other hosts do not import the agentmemory module.

## Architecture

Three layers, all talking to the same iii-engine service on localhost:3111:

1. **Systemd user service** (`modules/features/agentmemory.nix`) — runs `npx -y @agentmemory/agentmemory@latest` as a user service for john. Exposes REST (:3111), streams (:3112), viewer (:3113), iii-engine (:49134).
2. **Hermes plugin** (`modules/features/agentmemory-plugin/`) — vendored Python plugin that talks to the HTTP API at localhost:3111. Handles hooks: prefetch, sync_turn (auto-observe), on_pre_compress (context preservation), system_prompt_block (context injection). Registered via `memory.provider = "agentmemory"` in hermes.nix.
3. **MCP server** — `@agentmemory/mcp@latest` configured in both hermes.nix (mcpServers) and codex-free.nix. Connects to the running service on localhost:3111. Provides memory_recall, memory_save, memory_search tools.

The iii-engine binary lives at `~/.agentmemory/bin/iii` (persistent mount). It must be pre-installed or the npm package will try to download and extract it on every start.

## Key Environment Variables (service)

| Variable | Purpose |
|----------|---------|
| `OPENROUTER_API_KEY` | LLM consolidation/compression (passed via sops template) |
| `OPENROUTER_MODEL` | Which model for compression (set to deepseek flash for cost) |
| `CONSOLIDATION_ENABLED` | Enables background consolidation |
| `GRAPH_EXTRACTION_ENABLED` | Enables knowledge graph extraction |
| `AGENTMEMORY_AUTO_COMPRESS` | Per-observation LLM compression |
| `AGENTMEMORY_INJECT_CONTEXT` | Context injection into conversation |
| `NPM_CONFIG_CACHE` | Set to /tmp on tmpfs-root hosts |

## Critical: npm, NOT pip/uvx

Agentmemory is an **npm package** (`@agentmemory/agentmemory`), published by rohitg00. The PyPI package named `agentmemory` (by AutonomousResearchGroup) is completely unrelated and has no CLI entry point. Always use:

```
npx -y @agentmemory/agentmemory@latest    # service
npx -y @agentmemory/mcp@latest            # MCP server
```

Never `uvx --from agentmemory` — that pulls the wrong package.

## Critical: gnutar in PATH

The iii-engine installer needs `tar` to extract its binary. The systemd service PATH must include `pkgs.gnutar`. Without it, the installer fails silently with `tar: command not found` and the service crash-loops.

## Common Failure Modes

### Service crash-loops (8,000+ restarts)
**Cause:** Missing `gnutar` in PATH — the iii-engine auto-installer can't extract its binary.
**Fix:** Add `pkgs.gnutar` to the service `path` list. Pre-install the iii binary to `~/.agentmemory/bin/iii`.

### "MCP client failed to start" in Codex
**Cause:** The npx command can't find node, or the cache is on a full tmpfs root.
**Fix:** Ensure `pkgs.nodejs` is in PATH. Set `NPM_CONFIG_CACHE=/tmp/npm-cache` on tmpfs-root hosts.

### OOM kill (false diagnosis)
The service peaks at ~290MB. If you see OOM kills, check for accumulated zombie processes from prior crash loops, not the service itself. A clean restart after fixing the underlying issue resolves this.

### Memories not persisting across reboots
The `~/.agentmemory` directory must be on persistent storage. On thoth it's bind-mounted from `/persistent` via preservation. Check that `users.john.directories` includes `.agentmemory`.

## Verification Steps

1. Check service is running:
```bash
systemctl --user is-active agentmemory.service
```

2. Check REST API responds:
```bash
curl -s http://localhost:3111/agentmemory/context -X POST -H "Content-Type: application/json" -d '{"sessionId":"test","project":"/tmp"}'
```

3. Check consolidation is working:
```bash
journalctl --user -u agentmemory.service --since "5 min ago" | grep -E "Observation captured|Observation compressed|Memory saved"
```

4. Check iii-engine process is alive:
```bash
ps aux | grep "[i]ii --config"
```

5. Test MCP tools (from Hermes): use memory_save then memory_recall to verify round-trip.

## Module Structure

- `modules/features/agentmemory.nix` — service definition, nginx proxy, tmpfiles for plugin symlink
- `modules/features/agentmemory-plugin/` — vendored Hermes Python plugin (__init__.py, plugin.yaml, README.md)
- `modules/features/hermes.nix` — sets `memory.provider = "agentmemory"`, adds MCP server
- `modules/features/codex-free.nix` — adds agentmemory MCP server (thoth only)
- Imported only in `modules/hosts/thoth/configuration.nix`

## Port Map

| Port | Service |
|------|---------|
| 3111 | REST API (Hermes plugin connects here) |
| 3112 | WebSocket streams |
| 3113 | Web viewer (nginx-proxied at thoth-memory.otwell.dev) |
| 49134 | iii-engine internal |
