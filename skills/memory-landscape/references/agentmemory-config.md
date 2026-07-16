# AgentMemory Configuration Reference

Source: agentmemory npm package (`@agentmemory/agentmemory`). Homepage: https://github.com/rohitg00/agentmemory

## Installation

Agentmemory is an **npm package**, not a Python package. Always invoke via:
```
npx -y @agentmemory/agentmemory@latest    # server (REST + iii-engine)
npx -y @agentmemory/mcp@latest            # MCP server
```

Do NOT use `uvx --from agentmemory` or `pip install agentmemory` — the PyPI package of that name is unrelated (different author, no CLI entry point).

The iii-engine binary downloads to `~/.agentmemory/bin/iii` on first run. The installer needs `tar` (gnutar) in PATH.

## LLM Provider (pick one)

Detection order: OPENAI_API_KEY -> MINIMAX_API_KEY -> ANTHROPIC_API_KEY -> GEMINI_API_KEY -> OPENROUTER_API_KEY -> noop.

| Provider | Env var | Model env var | Notes |
|----------|---------|---------------|-------|
| OpenAI | `OPENAI_API_KEY` | `OPENAI_BASE_URL` | Also used for embeddings |
| Anthropic | `ANTHROPIC_API_KEY` | `ANTHROPIC_MODEL`, `ANTHROPIC_BASE_URL` | Per-token billing |
| Gemini | `GEMINI_API_KEY` or `GOOGLE_API_KEY` | `GEMINI_MODEL` | Also enables embeddings |
| OpenRouter | `OPENROUTER_API_KEY` | `OPENROUTER_MODEL` | Any model, supports fallbacks |
| MiniMax | `MINIMAX_API_KEY` | `MINIMAX_MODEL` | Anthropic-compatible |

No-op (default): no LLM key = synthetic BM25 compression only, no summarization/consolidation.

## Key Behavior Flags

| Flag | Default | Purpose |
|------|---------|---------|
| `CONSOLIDATION_ENABLED` | false | Consolidation pipeline (raw -> semantic -> procedural) |
| `GRAPH_EXTRACTION_ENABLED` | false | Extract concept-graph edges on remember |
| `AGENTMEMORY_AUTO_COMPRESS` | false | LLM compress every observation batch (costly) |
| `AGENTMEMORY_REFLECT` | false | Periodic auto-synthesize lessons |
| `CONSOLIDATION_DECAY_DAYS` | 30 | Days before non-reinforced memories decay |
| `MAX_TOKENS` | 4096 | Cap LLM completion tokens for compression/summarize |
| `AGENTMEMORY_LLM_TIMEOUT_MS` | 60000 | Outbound LLM/embedding timeout |

## Search Tuning

| Flag | Default | Purpose |
|------|---------|---------|
| `BM25_WEIGHT` | 0.4 | Hybrid search BM25 weight |
| `VECTOR_WEIGHT` | 0.6 | Hybrid search vector weight |
| `AGENTMEMORY_GRAPH_WEIGHT` | 0.2 | Graph traversal bonus on smart-search |
| `MAX_OBS_PER_SESSION` | 500 | Per-session observation cap |
| `SUMMARIZE_CHUNK_SIZE` | 400 | Obs per chunk for large-session summarize |
| `SUMMARIZE_CHUNK_CONCURRENCY` | 6 | Parallel chunk LLM calls |

## Embedding Provider

Auto-detected from LLM keys. Override with `EMBEDDING_PROVIDER` (local, openai, voyage, cohere, gemini, openrouter).

Without an embedding key, runs in BM25-only mode (keyword matching, no semantic similarity).

## Diagnostics

| Command | Purpose |
|---------|---------|
| `agentmemory doctor --dry-run` | Show issues + planned fixes without executing |
| `agentmemory doctor --all` | Apply all fixes non-interactively |
| `agentmemory status` | Quick health: running/stopped, memory count, flags |

Doctor checks: server reachability, .env file, LLM provider key, viewer port, iii binary location.

## REST Worker vs MCP Standalone

AgentMemory has two operational modes:

1. **REST worker** (full): Requires iii-engine running. Powers consolidation sweeps, summarization, reflection, the viewer, and streams. Started by `npx @agentmemory/agentmemory` (default command).
2. **MCP standalone** (reduced): The MCP shim works without iii-engine. Exposes 7 basic tools (save, recall, search, sessions, export, audit, governance). No consolidation, no summarization.

**Key diagnostic signal:** If MCP tools respond but `agentmemory status` shows "not running", the REST worker is dead and LLM-backed features are disabled.

## Ports

- REST API: 3111 (`III_REST_PORT`)
- Streams: 3112 (`III_STREAMS_PORT`)
- Viewer: 3113 (auto-started, read-only)
- iii-engine: 49134 (auto-derived from REST port)

## MCP Shim vs Full Server

The `@agentmemory/mcp` package is a thin shim. It exposes the full tool surface only when it can reach a running agentmemory server via `AGENTMEMORY_URL` (default: http://localhost:3111). Without a server, falls back to 7-tool local set.
