# Cognee + Postgres Setup Plan

Local knowledge-graph memory for Pi. Single Postgres instance backs all three
Cognee stores (relational, vector, graph). No external vector DB, no Neo4j.

## Architecture

```
Postgres (NixOS system service)
├── Relational: documents, chunks, metadata
├── pgvector: embeddings (semantic search)
└── Graph: graph_node / graph_edge tables
      │
      ▲
      │
Cognee API server (systemd user service, :8000)
├── LLM: GLM via Z.AI (entity extraction during cognify)
├── Embeddings: fastembed / bge-small-en-v1.5 (local ONNX, CPU, ~30MB)
└── Storage: /persistent/home/john/.cognee/{system,data}
      │
      ▲
      │ HTTP (localhost)
      │
Pi (curl → localhost:8000)
```

## Files to create/modify

### 1. `modules/features/postgresql.nix` (new)

First Postgres in mortlake. PG17 + pgvector extension plugin.

- `services.postgresql.enable = true`, `package = pkgs.postgresql_17`
- `listen_addresses = "127.0.0.1"` (localhost only)
- `ensureDatabases = [ "cognee_db" ]`
- `ensureUsers`: `cognee` (owns cognee_db), `john` (superuser for admin)
- `extraPlugins = [ pkgs.postgresql_17.pkgs.pgvector ]`
- **Manual step after first rebuild**: `psql -U cognee -d cognee_db -c "CREATE EXTENSION IF NOT EXISTS vector;"` — Cognee doesn't create it for you.

### 2. `modules/features/cognee.nix` (new)

systemd user service following the established agent-service pattern.

**Secrets (sops):**
- Add `cognee-db-password` to `modules/features/secrets.yaml`
- `sops.templates."cognee-env"` with:
  - `DB_PROVIDER=postgres`, `DB_HOST=127.0.0.1`, `DB_PORT=5432`, `DB_NAME=cognee_db`, `DB_USERNAME=cognee`, `DB_PASSWORD=${placeholder}`
  - `VECTOR_DB_PROVIDER=pgvector`
  - `GRAPH_DATABASE_PROVIDER=postgres`
  - `LLM_PROVIDER=openai`, `LLM_API_KEY=<glm-api-key>`, `LLM_ENDPOINT=https://api.z.ai/api/coding/paas/v4`, `LLM_MODEL=glm-5.2`
  - `EMBEDDING_PROVIDER=fastembed`, `EMBEDDING_MODEL=BAAI/bge-small-en-v1.5`
  - `SYSTEM_ROOT_DIRECTORY=/persistent/home/john/.cognee/system`
  - `DATA_ROOT_DIRECTORY=/persistent/home/john/.cognee/data`

**Venv strategy** — use `uv run` at service startup (avoids fragile nix build with deep Python dep tree):
- ExecStart: `uv run --with "cognee[postgres-binary,fastembed]" python -m cognee.api`
- `path = [ pkgs.uv pkgs.curl pkgs.bash ]`
- First start is slow (uv resolves + downloads deps); subsequent starts use cache.
- UV cache: persist `~/.cache/uv` via preservation module if not already.
- Requires `python313` available in the environment (it's in pkgs).

**Alternative** (if uv-run startup proves too slow): build venv at activation:
```nix
system.activationScripts.cognee-venv = ''
  if [ ! -d /persistent/home/john/.cognee/venv ]; then
    ${pkgs.uv}/bin/uv venv /persistent/home/john/.cognee/venv
    /persistent/home/john/.cognee/venv/bin/pip install "cognee[postgres-binary,fastembed]"
  fi
'';
# ExecStart points at /persistent/home/john/.cognee/venv/bin/python -m cognee.api
```

**Service config:**
- `after = [ "postgresql.service" "network.target" ]`
- `wantedBy = [ "default.target" ]`
- `Restart = "on-failure"`, `RestartSec = "5"`

### 3. `modules/features/secrets.yaml` (modify)

Add:
```yaml
cognee-db-password: <generate strong password>
```
Re-encrypt: `sops modules/features/secrets.yaml`

Add to `sops.nix` secrets block:
```nix
"cognee-db-password" = john;
```

### 4. Host config (e.g. `hosts/uriel.nix`)

Add both modules to imports:
```nix
inputs.mortlake.nixosModules.postgresql
inputs.mortlake.nixosModules.cognee
```

### 5. Pi integration

Pi calls Cognee REST API via curl. Add wrapper script to `~/.local/bin/`:

```bash
#!/usr/bin/env bash
# cognee-remember: ingest text into Cognee
# Usage: echo "some fact" | cognee-remember
curl -s -X POST http://localhost:8000/v1/cognify \
  -H "Content-Type: application/json" \
  -d "{\"data\": \"$(cat -)\"}"
```

```bash
#!/usr/bin/env bash
# cognee-recall: query Cognee memory
# Usage: cognee-recall "how does mortlake discover modules?"
curl -s "http://localhost:8000/v1/search" \
  -H "Content-Type: application/json" \
  -d "{\"query\": \"$1\"}" \
  | jq -r '.[]?.text'
```

Hook into Pi via shell aliases or Pi's TOML hooks config.

### 6. Preservation

Add to whichever host's preservation config:
```nix
preservation.preserveAt."/persistent".users.john.directories = [
  ".cognee"
];
```

## Verification checklist

```bash
# 1. Postgres up + extension installed
systemctl status postgresql
psql -U cognee -d cognee_db -c "SELECT extname FROM pg_extension;"
# If vector missing:
psql -U cognee -d cognee_db -c "CREATE EXTENSION IF NOT EXISTS vector;"

# 2. Cognee API responding
curl http://localhost:8000/health

# 3. Run migrations (first time against fresh Postgres)
uv run --with "cognee[postgres-binary,fastembed]" python -c \
  "import asyncio, cognee; asyncio.run(cognee.run_startup_migrations())"

# 4. Smoke test — remember + recall
uv run --with "cognee[postgres-binary,fastembed]" python -c "
import asyncio, cognee

async def main():
    await cognee.remember('Mortlake uses flake-parts with import-tree for module discovery.')
    results = await cognee.recall(query_text='How does mortlake discover modules?')
    for r in results:
        print(r.text)

asyncio.run(main())
"

# 5. Pi can reach it
cognee-recall "How does mortlake discover modules?"
```

## Decision rationale

| Decision | Why |
|----------|-----|
| Postgres for all 3 stores | Cognee's recommended backend; one process/backup; matches user's Postgres+AGE preference over Neo4j |
| Postgres graph tables (no Cypher) | Acceptable — Cognee's query patterns don't need raw Cypher; Postgres is the explicitly recommended backend |
| fastembed (bge-small-en) | Local ONNX, CPU-only, ~30MB model, zero API cost for embeddings |
| GLM via Z.AI for LLM | Already have key; OpenAI-compatible endpoint; Cognee uses LiteLLM internally |
| `uv run` at startup | Avoids fragile nix build with cognee's deep dep tree; matches two-layer Nix+uv philosophy from ml template |
| systemd user service | Same pattern as previous agent services; runs as john |

## Open questions

- **Venv strategy**: `uv run` (simpler, slower startup) vs activation-script venv (faster startup, one-time build). Decide after testing first boot.
- **LLM cost during cognify**: Entity extraction calls GLM on every `remember()`. For high-volume ingestion, consider batching or a cheaper model (deepseek-v4-flash via OpenRouter).
- **Backup**: Postgres `pg_dump` covers relational + pgvector + graph tables. No separate backup needed if everything's in one DB.
