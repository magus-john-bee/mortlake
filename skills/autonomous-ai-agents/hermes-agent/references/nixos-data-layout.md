# NixOS Data Layout (Thoth)

When Hermes is managed via NixOS (HERMES_MANAGED=true), data lives under `/var/lib/hermes/.hermes/` instead of the default `~/.hermes/`.

## Directory Map

```
/var/lib/hermes/.hermes/
├── config.yaml              # Managed config (but on NixOS, edits happen in corpus modules/features/hermes.nix)
├── .env                     # Secrets (sops-decrypted)
├── .managed                 # Marker file (empty) — signals NixOS management
├── auth.json                # OAuth tokens, credential pools
├── state.db                 # SQLite: kanban, processes, gateway state (~80MB, WAL mode)
├── .hermes_history          # Command history
├── SOUL.md                  # Personality document
├── memories/
│   ├── MEMORY.md            # Agent's personal notes (injected as MEMORY block)
│   ├── MEMORY.md.lock       # Write lock
│   ├── USER.md              # User profile (injected as USER PROFILE block)
│   └── USER.md.lock
├── sessions/                # JSONL transcripts, one per session (~292 files)
│   └── YYYYMMDD_HHMMSS_<id>.jsonl
├── hindsight/
│   └── config.json          # Symlink → /nix/store/...-hindsight-config.json (immutable)
├── skills/                  # Installed + external skills
│   └── .hub/taps.json       # Tap registry
├── cache/
│   ├── documents/
│   ├── audio/
│   └── images/
├── logs/                    # Gateway and error logs
├── gateway/                 # Gateway runtime state
├── cron/                    # Scheduled jobs
├── sandboxes/               # Code execution sandboxes
├── images/                  # Downloaded images
├── pastes/                  # Paste storage
├── platforms/               # Platform-specific state
└── plugins/                 # Plugin data
```

## Hindsight (Long-term Memory)

Runs as a **Podman container** (`ghcr.io/vectorize-io/hindsight:latest-slim`).

- **Container data**: `/var/lib/hindsight/` (host) → `/home/hindsight/.pg0` (container)
- Inside: **PostgreSQL 18.1** with vector embeddings, entity graph, and index
- **API**: `http://127.0.0.1:8888` (health: `/health`)
- **Port 9999**: additional service
- **Config**: `/var/lib/hermes/.hermes/hindsight/config.json` → Nix store symlink
- **Definition**: `modules/features/hindsight.nix` in corpus

Key config values (from config.json):
```json
{
  "mode": "local_external",
  "api_url": "http://127.0.0.1:8888",
  "bank_id": "hermes",
  "recall_budget": "mid",
  "memory_mode": "hybrid",
  "auto_retain": true,
  "auto_recall": true,
  "retain_async": true
}
```

Hindsight container environment:
- LLM provider: Groq, model `openai/gpt-oss-20b`
- Embeddings: OpenAI-compatible via DeepInfra, model `BAAI/bge-large-en-v1.5`
- Reranker: `rrf` (reciprocal rank fusion)
- API key via sops secret `hindsight-env`

## Quick Checks

```bash
# Hindsight health
curl -s http://127.0.0.1:8888/health

# Hindsight container status
podman ps --filter name=hindsight

# Hermes state DB size
du -h /var/lib/hermes/.hermes/state.db

# Session count
ls /var/lib/hermes/.hermes/sessions/ | wc -l

# Memory files
wc -c /var/lib/hermes/.hermes/memories/MEMORY.md
wc -c /var/lib/hermes/.hermes/memories/USER.md

# Podman process tree for hindsight
ps aux | grep hindsight | grep -v grep
```
