---
name: every-session
description: >
  Session initialization — run this skill first, every session. Restores cross-session continuity,
  manages memory and wiki orientation, checks for in-flight work, and routes to the right skill
  before any task work begins. Do NOT load this skill mid-session as a task handler — it manages
  the session itself, not any specific task domain.
version: 1.0.0
license: MIT
metadata:
  hermes:
    tags: [session, initialization, memory, continuity, meta]
    related_skills:
      - skill-crafting
      - working-with-code
      - logseq
---

# Every Session

This skill runs at the start of every session. It restores continuity with prior work,
orients to persistent context (memory, hindsight, llm-wiki), checks for in-flight work,
and routes to the right skill before any task work begins.

**What this skill does:**
- Recalls relevant past sessions before starting new work
- Orients to the llm-wiki if the session involves wiki work
- Checks for in-flight work (PRs, TODOs, openspec stubs, cron results)
- Routes to the correct domain skill
- Manages its own closing — retains discoveries, updates wiki, confirms pending work

**What this skill does NOT do:**
- Handle any specific task domain (coding, research, writing — those load their own skills)
- Run mid-session as a task handler
- Produce artifacts beyond session state

## Directory Layout

All machines have three user directories under **the human user's home** (`/home/john/`):

- **`/home/john/src/`** — repos containing code we actively work on and use. Includes `corpus` (machine and software configs — when asked to modify a config or nix file without a specified path, assume `/home/john/src/corpus`)
- **`/home/john/vault/`** — repos containing material meant to be read (mostly markdown). Includes:
  - `book-of-thoth` — the agent's llm-wiki, for agent reference and knowledge persistence
  - `logbook` — the user's primary Logseq graph for personal reference and knowledge persistence. **All Logseq workflows assume this graph unless otherwise specified.**
These directories are created by the `dev-dirs` NixOS module (tmpfiles rules). On preservation hosts they're persisted through the preservation module.

> ⚠️ **`~` pitfall:** The Hermes agent runs as a systemd service under its own user (`/var/lib/hermes/`). The `~` shell variable and tilde expansion resolve to `/var/lib/hermes/`, **not** `/home/john/`. When the user says `~/src/corpus`, they mean `/home/john/src/corpus`. Always use the absolute path.

---

## When to Load

**Load this skill:**
- At the start of **every** session, before any task work
- When the user says "remember", "we did this before", "as I mentioned", or similar continuity cues
- When you notice a task is clearly a continuation of something from a past session

**Do NOT load this skill:**
- As a task handler mid-session (it manages the session, not tasks)
- When the user's request is already scoped and the session is already in progress (re-load is unnecessary overhead)

Check what's relevant from previous sessions before starting new work.

```
Use session_search(query="<current task or project>") to find related past sessions.
Use hindsight_recall(query="<current context>") to pull persistent facts.
```

### Step 2: Memory Review + llm-wiki Orientation

Check for any new memories or updates since the last session.

```
Use hindsight_recall on any active projects or ongoing work visible in the session context.
```

Look for:
- Active PRs or branches that need attention
- Open decisions or open questions from prior sessions
- User preferences discovered in prior sessions that aren't yet in memory

If the session will involve wiki work (queries, ingestion, updates), orient first:

```
Read WIKI/SCHEMA.md        # Understand conventions and tag taxonomy
Read WIKI/index.md         # See what pages already exist
Read WIKI/log.md offset=N  # Scan recent entries to see what's been done
```

This prevents duplicating work, contradicting schema conventions, or missing cross-links.
This is required before any llm-wiki operation — see the llm-wiki skill's "Orient yourself" step.

### Step 3: Active Context Check

Before starting new work, verify there is no in-flight work that takes priority.

**Check for:**
- Pending review requests (PRs waiting on you)
- Open decisions the user was waiting on
- Cron jobs that may have triggered and delivered results
- TODOs.md — check for unresolved items relevant to this session
- openspec/changes/ — check for active stub changes or pending work

### Step 4: Skill Routing Check

Determine whether this session's task is covered by an existing skill.

```
If the task matches an existing skill → load it before proceeding
If no skill matches → proceed with general workflow
If unsure → ask the user
```

See the Skill Routing Table at the end of this skill.

---

## Cross-Session Continuity Patterns

### When the user references something from a past session

```
session_search(query="<keywords from user's reference>")
```

Do NOT ask the user to repeat themselves if you can find it in session history.
If the search is ambiguous, show the user what you found and confirm before proceeding.

### When you encounter something you don't recognize

Before assuming it's new:
```
hindsight_recall(query="<unknown term, tool, project>")
session_search(query="<unknown term>")
```

Tools, projects, and conventions the user mentioned before are already in memory.
Don't make the user re-explain.

### When a task is a continuation

If a prior session left something unfinished:
1. memory: see if you have any memory of this or similar work
2. session_search: find the last session that worked on it
3. hindsight: recall any persistent facts about it

Then state what you found and confirm the continuation before proceeding.

### When you discover something worth remembering

During the session, if you learn:
- A user preference or habit
- A project-specific convention
- A tool quirk or workaround
- A decision with rationale

Useful factoids belong in memory and hindsight. Useful facts (preferences, conventions, tool quirks) → memory or hindsight_retain immediately.
Episodic / compound knowledge → llm-wiki (entities, concepts, research).
session_search is passive — it searches past transcripts automatically; you don't write to it.

```
hindsight_retain(content="<what to remember>", context="<why it matters>")
memory(action='add', target='memory', content="<fact>")
```

Don't wait until end of session — persist immediately when you learn it.

---

## Skill Routing Table

Use this table to route to the right skill for the task at hand.

| Task | Skill to Load |
|------|--------------|
| Codebase or plaintext project work | `working-with-code` |
| Planning or spec-driven work | `working-with-openspec` |
| GitHub PR workflow | `github-pr-workflow` |
| Creating or editing Logseq notes | `logseq` |
| Building or querying the llm-wiki knowledge base | `llm-wiki` |
| ML training, fine-tuning, evaluation | (see mlops/* skills) |
| Web search or research | `web-search` |
| Skill creation or revision | `skill-crafting` |
| NixOS / system config | (see devops/* skills) |
| Email management | `himalaya` |
| Deep research or literature review | `feynman-deep-research` / `feynman-literature-review` |
| Bug investigation | `systematic-debugging` |
| Writing a plan | `writing-plans` / `plan` |

If no skill matches and the task is nontrivial → load `working-with-code` as default.

---

## Anti-Patterns

| Anti-pattern | What to do instead |
|---|---|
| Starting task work without checking continuity | Run cross-session recall first |
| Asking user to repeat something in memory | Look it up with session_search first |
| Forgetting a stated preference | Retain to hindsight immediately — don't wait for session close |
| Working in a vacuum when a relevant skill exists | Check the routing table before starting |
| Speculating about a skill's existence, location, or content from memory | Use `skill_view` or `skills_list` to check — don't guess or spelunk with `find` |
| Assuming you're in a restricted container or can't reach host filesystem | Hermes runs as a systemd service **on the host** — check with `hostname` or `ls /home/john/src/` before assuming restrictions. Don't invent workarounds (saving to memory "to do later from thoth") when you can act directly. |
| Using `~` to refer to the user's home directory | `~` resolves to `/var/lib/hermes/` (the Hermes service user), not `/home/john/`. Always use `/home/john/...` explicitly. When the user says `~/src/corpus`, they mean `/home/john/src/corpus`. |
| wiki work without orienting to SCHEMA/index/log | Orient first — required before any llm-wiki operation |

---

## Session Closing

Before the session ends (or when the user says goodnight), use your judgment:

- **Retain what matters** — persist user preferences, decisions, and anything that would waste future sessions if lost
- **Update relevant pages** — if you learned something that belongs in the llm-wiki or Logseq, file it before you forget
- **Confirm pending work** — tell the user what was accomplished and what still needs attention

Don't spend time on session closing rituals if nothing significant happened. A two-minute session gets a two-minute close.

---

## Relationship to SOUL.md

SOUL.md is the "way to be" — values, principles, and character. This skill is the "how to operate" — procedures, continuity, and session hygiene. SOUL.md tells you *what to care about*. This skill tells you *what to do first*.

Load this skill because SOUL.md directs you to. The two are complementary.
