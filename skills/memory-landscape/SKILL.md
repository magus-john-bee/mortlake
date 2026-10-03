---
name: memory-landscape
description: Three-layer memory system for AI agents — built-in key-value memory, shared semantic memory (planned successor path icm+qmd), and human-facing PKM. When to use each, how they interact, and decision heuristics. Agent-agnostic.
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

## 2. Shared Semantic Memory (planned)

- **History:** cognee layer removed 2026-10-02, unused; successor path icm+qmd.
- **What it will cover:** Cross-session recall of decisions, architectural insights, bug patterns, workflows.
- **Status:** No shared-memory backend is deployed today. Until icm+qmd land, use session search for past-session recall and the PKM for durable shared knowledge.

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
| Architectural decision to recall semantically | Session search today; icm+qmd once landed |
| Bug pattern or workflow to search later | Session search today; icm+qmd once landed |
| Procedural approach I'll reuse | Skill (skill_manage) |
| Note the user should see in their PKM | Human-facing PKM |
| Project research, shared knowledge | Human-facing PKM |
| What happened in a past session | Session search (session_search) |

## Cross-System Patterns

- **Built-in memory** is always loaded — no recall step needed. Use it for the most critical, frequently-needed facts.
- **Shared semantic memory** has no live backend yet (see layer 2). Until icm+qmd land, session search and the PKM cover recall.
- **PKM** requires file reads but is the only system the user interacts with directly. Use it for shared knowledge.
- **Session search** is a fourth recall channel — searches past conversation transcripts for what was said and decided.
- For critical facts, consider dual-storing: built-in memory (for speed) + the PKM (for durable, user-visible notes).
- For procedural workflows, save as a **skill** — skills encode reusable approaches with exact commands and pitfalls.
