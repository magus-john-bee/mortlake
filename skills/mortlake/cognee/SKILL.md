---
name: cognee
description: Use when storing or recalling shared agent memory — the `cognee` CLI talks to cognee.otwell.dev (knowledge-graph memory for pi, prime-agent, and hermes).
tags: [cognee, memory, agents, mortlake]
---

# Cognee — shared agent memory

All agents (pi, prime-agent, hermes, on any host) share one memory: a
cognee server on uriel behind https://cognee.otwell.dev (nginx + ACME;
storage SQLite+LanceDB+Kuzu under /persistent/var/lib/cognee; server
module `modules/features/cognee.nix`).

## CLI (any host)

Auth is automatic: `$COGNEE_API_KEY` or `/run/secrets/cognee-api-key`
(sops). `$COGNEE_URL` defaults to https://cognee.otwell.dev.

```
cognee remember "Mortlake discovers modules via import-tree."   # blocks until graph built
cognee remember --bg "long text"                                 # background; poll status
cognee remember --file doc.md --dataset docs                     # file upload
cognee recall "How does mortlake discover modules?"              # auto-routed answer
cognee recall --context "graph extracts about X"                 # raw retrieval, no LLM answer
cognee recall --datasets agent_memory,docs "..."                 # scope datasets
cognee status                                                     # health + datasets
```

## When to use

- **remember**: durable facts worth surfacing in future sessions on ANY
  host — architecture decisions, user preferences, project state, "we
  tried X and it failed because Y". Not a clipboard; the graph runs LLM
  extraction (GLM) on every ingest.
- **recall**: at session start on new problems, or when prior work
  clearly exists (mortlake patterns, past debugging, infrastructure
  decisions). Results carry provenance back to the source text.

Default dataset `agent_memory`; use `--dataset` to segment (e.g. one per
project). Datasets are cheap; cross-dataset recall is the default.

## Server-side notes (ops)

- venv pinned `cognee[api]==1.6.1`, rebuilt by `cognee-venv.service` if
  its nix interpreter is GC'd; server is `cognee.service` (127.0.0.1:8010).
- Auth: single admin user; one shared API key (sops `cognee-api-key`).
  Issue/rotate via /api/v1/auth/apikeys (login first).
- Backups: daily restic (uriel) includes /var/lib/cognee; the backup
  stops cognee.service for a consistent file-store snapshot and restarts
  it after.
- Entity extraction uses GLM via Z.AI (`glm-5.3`); embeddings are local
  fastembed (CPU). MemoryMax 1200M on the 1.9GB box.
