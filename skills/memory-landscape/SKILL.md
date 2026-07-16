---
name: memory-landscape
description: Three-layer memory system for AI agents — built-in key-value memory, AgentMemory MCP, and human-facing PKM. When to use each, how they interact, and decision heuristics. Agent-agnostic.
category: memory
---

# Memory Landscape

AI agents have access to multiple memory systems. Each serves a different purpose. Use the right one for the job.

## 1. Built-in Memory (key-value facts)

- **What:** Lightweight facts injected into every turn via system prompt.
- **Capacity:** Small (typically ~6,000 chars). Keep entries concise and declarative.
- **When to use:** User preferences, environment details, stable conventions, tool quirks, corrections.
- **Write style:** Declarative facts, not instructions. "User prefers concise responses" not "Always respond concisely".
- **Do NOT store:** Task progress, session outcomes, PR numbers, commit SHAs, temporary state.
- **Speed:** Fastest — already in context, no tool call needed to read.

## 2. AgentMemory MCP (semantic memory)

- **What:** Persistent semantic memory with auto-observation, LLM-backed consolidation, search, and audit trail.
- **Tools:** `memory_save`, `memory_recall`, `memory_search`, `memory_smart_search`, plus governance/audit tools.
- **Types:** pattern, preference, architecture, bug, workflow, fact.
- **When to use:** Cross-session recall of decisions, architectural insights, bug patterns, workflows.
- **Advantages:** Semantic search, automatic observation capture, graph extraction, consolidation pipeline.
- **For detailed usage:** Load the `agentmemory` skill.
- **Speed:** Requires explicit tool calls for recall, but auto-observes in the background.

## 3. Human-Facing PKM (Logseq, Obsidian, etc.)

- **What:** The user's personal knowledge management system — wikilinked notes, journals, shared knowledge.
- **Skill:** Load the relevant PKM skill (`logseq`, `obsidian`) for file operations.
- **When to use:** Collaborative knowledge, project notes, research, anything the user directly sees and edits.
- **Routing rule:** Non-repo, non-infrastructure personal requests likely belong here. If a request doesn't pertain to a specific code repo or system configuration, check the user's PKM pages first.
- **Speed:** Requires file reads, but is the only system the user directly interacts with.

## Decision Heuristics

| Situation | Use |
|-----------|-----|
| Quick fact I'll need next session | Built-in memory |
| User corrects me / states preference | Built-in memory |
| Architectural decision to recall semantically | AgentMemory |
| Bug pattern or workflow to search later | AgentMemory |
| Procedural approach I'll reuse | Skill (skill_manage) |
| Note the user should see in their PKM | Human-facing PKM |
| Project research, shared knowledge | Human-facing PKM |
| What happened in a past session | Session search (session_search) |

## Cross-System Patterns

- **Built-in memory** is always loaded — no recall step needed. Use it for the most critical, frequently-needed facts.
- **AgentMemory** requires explicit search/recall but offers semantic matching and auto-observation. Use it for richer, queryable knowledge.
- **PKM** requires file reads but is the only system the user interacts with directly. Use it for shared knowledge.
- **Session search** is a fourth recall channel — searches past conversation transcripts for what was said and decided.
- For critical facts, consider dual-storing: built-in memory (for speed) + AgentMemory (for semantic recall).
- For procedural workflows, save as a **skill** — skills encode reusable approaches with exact commands and pitfalls.

## Memory Lifecycle

```
Conversation turn
  ├─ Auto-observed by AgentMemory (background, no action needed)
  │   └─ Consolidation pipeline: compress → dedup → graph extract → decay
  ├─ Explicit memory_save (for emphasis or specific typing)
  └─ Built-in memory write (for critical always-in-context facts)
```

AgentMemory's consolidation pipeline runs periodically (if an LLM provider is configured):
1. **Compress** raw observations into structured memories (title, type, importance, narrative)
2. **Deduplicate** and merge similar observations
3. **Extract graph edges** (concept relationships) if enabled
4. **Decay** memories not reinforced over time (default: 30 days)

Without an LLM provider key, agentmemory runs in noop mode: BM25 keyword search works, but summarization/reflection/consolidation are disabled.

## Related Skills

- `agentmemory` — Detailed guide to using agentmemory MCP tools effectively
- Project-specific deployment skills (e.g., `corpus/agentmemory-setup`) — Installation and configuration
