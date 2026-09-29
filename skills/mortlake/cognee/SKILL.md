---
name: cognee
description: Use when storing or recalling shared agent memory — cognee.otwell.dev (knowledge-graph memory; official Hermes plugin + pi extension as clients, curl for manual use).
tags: [cognee, memory, agents, mortlake]
---

# Cognee — shared agent memory

All agents (pi, prime-agent, hermes, on any host) share one memory: a
cognee server on uriel behind https://cognee.otwell.dev (nginx + ACME;
storage SQLite+LanceDB+Kuzu under /persistent/var/lib/cognee; server
module `modules/features/cognee.nix`).

## Clients

- **Hermes**: official memory-provider plugin (`cognee-integration-
  hermes-agent`), remote mode — COGNEE_BASE_URL + COGNEE_API_KEY.
- **pi / prime-agent**: community pi-cognee extension, MCP mode via the
  cognee-mcp proxy (API mode). See pi-integration docs.
- **Manual/cron**: plain curl (below). A bespoke `cognee` CLI was
  removed — upstream clients + curl cover everything.

## Manual use (curl, any host)

Auth: `X-Api-Key` from sops `cognee-api-key`
(/run/secrets/cognee-api-key). Endpoint: https://cognee.otwell.dev.

```
# remember (multipart; blocks until the graph is built — can take ~1min)
curl -X POST https://cognee.otwell.dev/api/v1/remember \
  -H "X-Api-Key: $(cat /run/secrets/cognee-api-key)" \
  -F 'raw_data=Mortlake discovers modules via import-tree.' \
  -F 'datasetName=agent_memory'

# recall (JSON; auto-routed answer)
curl -X POST https://cognee.otwell.dev/api/v1/recall \
  -H "X-Api-Key: $(cat /run/secrets/cognee-api-key)" \
  -H 'Content-Type: application/json' \
  -d '{"query":"How does mortlake discover modules?"}'

# health
curl https://cognee.otwell.dev/health
```

remember also accepts `run_in_background=true`, file uploads (`data0=@file`),
`labels`, `node_set`; recall accepts `datasets`, `only_context`,
`search_type`, `top_k`. See /openapi.json on the server.

## When to use

- **remember**: durable facts worth surfacing in future sessions on ANY
  host — architecture decisions, user preferences, project state, "we
  tried X and it failed because Y". Not a clipboard; the graph runs LLM
  extraction (GLM) on every ingest.
- **recall**: at session start on new problems, or when prior work
  clearly exists (mortlake patterns, past debugging, infrastructure
  decisions). Results carry provenance back to the source text.

Default dataset `agent_memory`; segment per project via `datasetName`.
Datasets are cheap; cross-dataset recall is the default.

## Server-side notes (ops)

- venv pinned `cognee[api]==1.6.1`, rebuilt by `cognee-venv.service` if
  its nix interpreter is GC'd; server is `cognee.service` (127.0.0.1:8010).
- Auth: single admin user (john@otwell.dev, password sops `cognee-admin-password`); one shared API key (sops `cognee-api-key`). Issue/rotate via POST /api/v1/auth/api-keys (login first — note the hyphen, not `apikeys`).
- Gotchas found live (each cost a deploy): (1) litellm needs a provider-qualified model: `LLM_MODEL=openai/glm-5.3`, bare `glm-5.3` fails routing; (2) with `LLM_API_KEY` set, embeddings default to OpenAI reusing that key → 401; pin BOTH `EMBEDDING_PROVIDER=fastembed` AND `EMBEDDING_MODEL=BAAI/bge-small-en-v1.5` (provider alone leaves the OpenAI default model); (3) pip wheels need `LD_LIBRARY_PATH` with stdenv.cc.cc.lib + zlib in the service env (nix-ld doesn't apply); (4) Kuzu/Ladybug writes to `~/.lbdb` — tmpfiles + ReadWritePaths or 226/NAMESPACE at startup; (5) sops template changes need `restartUnits` on the template or the running process keeps stale env.
- Backups: daily restic (uriel) includes /var/lib/cognee; the backup
  stops cognee.service for a consistent file-store snapshot and restarts
  it after.
- Entity extraction uses deepseek-v4.1-flash via OpenRouter (same slug
  as hermes fallback/vision); embeddings are local fastembed (CPU).
  MemoryMax 1200M on the 1.9GB box.
