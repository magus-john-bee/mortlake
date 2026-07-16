---
name: agentmemory
description: How to effectively use agentmemory MCP tools — what to save, memory types, search strategies, observation flow, and consolidation. Agent-agnostic: works for Hermes, Codex, Claude Code, or any MCP client connected to an agentmemory server.
version: 1.0.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [memory, agentmemory, mcp, agent-tools]
    related_skills: [memory-landscape]
---

# Using Agentmemory

Agentmemory is a persistent memory layer for AI agents. It runs as a service (REST API + iii-engine) and exposes tools via MCP. This skill covers how to use those tools effectively — what to save, when, and how to recall it.

## Tool Surface

### Core tools (always available via MCP)

| Tool | Purpose | Key params |
|------|---------|------------|
| `memory_save` | Save an observation, insight, or pattern | `content`, `type` |
| `memory_recall` | Keyword search for past observations | `query`, `limit` |
| `memory_search` | Hybrid semantic + keyword search (smarter) | `query`, `limit` |
| `memory_smart_search` | Graph-augmented search with query expansion | `query`, `limit` |

### Extended tools (when connected to full server)

| Tool | Purpose |
|------|---------|
| `memory_sessions` | List/search past sessions |
| `memory_export` | Export memories to JSON |
| `memory_audit` | Access trail for a memory |
| `memory_governance_delete` | Delete a memory with reason (auditable) |

The full server exposes up to 51 tools. The 7 above cover 95% of use cases.

## Memory Types

Always pick the most specific type when saving. The type drives consolidation, graph extraction, and search relevance.

| Type | When to use | Example |
|------|-------------|---------|
| `pattern` | Recurring behavior or code pattern | "NixOS services need explicit PATH for binary discovery" |
| `preference` | User's stated preference or style | "User dislikes empty responses after tool execution" |
| `architecture` | System design decision | "tmpfs root means all state must be on persistent mounts" |
| `bug` | A bug and its root cause | "agentmemory crash-loop: missing gnutar, not OOM" |
| `workflow` | A procedure or process to follow | "Profile layering: config in profile file, trust in config.toml" |
| `fact` | General knowledge worth retaining | "DDR4 and DDR5 are physically incompatible" |

When in doubt, use `fact`. It's the safe default for anything that doesn't fit the others.

## What to Save

**Save durable knowledge** that will matter in future sessions:

- User corrections ("don't do X, do Y instead")
- Environment quirks (PATH issues, tmpfs gotchas, permission patterns)
- Architectural decisions and their rationale
- Bug root causes (especially non-obvious ones)
- Workflow discoveries ("this tool actually needs that flag")
- Stable user preferences and habits

**The acid test:** Will this be true and useful 7 days from now? If not, skip it.

## What NOT to Save

- Task progress ("finished step 3 of 5")
- Session outcomes ("PR merged successfully")
- Ephemeral state (current branch name, file counts, TODO status)
- Things easily rediscovered (file contents, command help output)
- Raw data dumps (logs, API responses)

These belong in session history (session_search) or nowhere at all. Saving them pollutes recall for real memories.

## Writing Good Memories

A good memory is a **self-contained declarative fact** that makes sense without surrounding context.

**Good:**
```
content: "On tmpfs-root NixOS hosts, npx caches to the root tmpfs which fills up. Set NPM_CONFIG_CACHE=/tmp/npm-cache to redirect to a larger mount."
type: "pattern"
```

**Bad:**
```
content: "Set NPM_CONFIG_CACHE to /tmp/npm-cache"
type: "fact"
```

The bad version omits the problem (tmpfs fills up), the trigger condition (tmpfs-root hosts), and the consequence (builds fail). Without those, it won't match when you search for "npm cache full disk".

**Structure:** Condition → Problem → Solution. Or: Context → Decision → Reason.

## Search Strategies

### `memory_recall` — keyword, fast
Use when you know specific terms. Exact-ish matching (BM25). Returns titles, types, narratives, importance scores.

```
memory_recall(query="systemd PATH missing binary", limit=10)
```

### `memory_search` — hybrid semantic + keyword
Use when your query is conceptual rather than keyword-specific. Combines vector similarity with BM25. Returns scored results.

```
memory_search(query="service can't find command even though it's installed", limit=5)
```

### `memory_smart_search` — graph-augmented, deepest
Use when you need the most thorough results. Adds graph traversal (related concepts) and query expansion (synonyms, related terms). Slowest but most complete.

```
memory_smart_search(query="why does agentmemory keep crashing")
```

**Rule of thumb:** Start with `memory_recall`. If nothing useful comes back, escalate to `memory_search`, then `memory_smart_search`.

## Observation Flow

When connected to a running server, agentmemory **automatically observes** conversation turns. You don't need to manually save everything — the background pipeline captures:

- User messages and tool calls
- Tool outputs and results
- Session context (project, cwd, timestamps)

The consolidation pipeline then:
1. **Compresses** raw observations via LLM into structured memories (title, type, importance, narrative)
2. **Deduplicates** and merges similar observations
3. **Extracts graph edges** (concept relationships) if enabled
4. **Decays** memories not reinforced over time (default: 30 days)

This means: **explicit `memory_save` is for emphasis, not for capture.** The system already sees the conversation. Use `memory_save` when:
- You want to ensure something survives with a specific type
- You want higher importance than auto-compression would assign
- You want to capture a synthesized insight, not a raw observation

## Importance Scoring

When auto-compressing, the LLM assigns an importance score (1-10). This affects:
- Search ranking (higher = more relevant)
- Decay resistance (important memories decay slower)
- Context injection (higher importance = more likely included in prompt context)

You can influence this by saving explicitly — manual saves typically get importance 7.

## Cross-Agent Sharing

Multiple agents connecting to the same agentmemory server **share the same memory store**. This means:

- A bug found by Codex is recallable by Hermes
- Architectural decisions saved by one agent inform all others
- Use `AGENT_ID` env var to scope memories to a specific agent if isolation is needed
- Use `AGENTMEMORY_AGENT_SCOPE=isolated` to filter recall to only your agent's memories

Without `AGENT_ID`, all memories are shared and unscoped.

## Consolidation and Cost

The consolidation pipeline uses LLM calls. Key cost drivers:

- `AGENTMEMORY_AUTO_COMPRESS=true` — compresses every observation batch (high cost, rich results)
- `AGENTMEMORY_AUTO_COMPRESS=false` — synthetic BM25 compression only (free, less rich)
- `CONSOLIDATION_ENABLED=true` — hourly sweep that consolidates into semantic memories

**Recommendation:** Use a cheap model for consolidation (e.g., `deepseek/deepseek-v4-flash`). Premium models (claude-sonnet, gpt-4o) can cost $5+/day under active use vs $0.46/day for deepseek.

## Troubleshooting

### Tools respond but recall returns nothing
Check if the server is actually running. MCP standalone mode (no iii-engine) can save/recall from a local JSON file, but won't have the full search/graph features. Verify:
```
curl http://localhost:3111/agentmemory/context -X POST -H "Content-Type: application/json" -d '{"sessionId":"test","project":"/tmp"}'
```

### Memories not surviving reboots
The `~/.agentmemory` directory must be on persistent storage. On tmpfs-root systems, this requires explicit mount/preservation configuration.

### Consolidation not running
Requires an LLM provider key. Without one, agentmemory runs in noop mode — BM25 search works but no summarization, reflection, or graph extraction. Check server logs for "noop provider" messages.

### Embedding search returns poor results
Without an embedding API key, agentmemory falls back to BM25-only mode (keyword matching, no semantic similarity). This means conceptual queries won't match well. Set an embedding provider key (OpenAI, Gemini, Voyage, Cohere, or OpenRouter).
