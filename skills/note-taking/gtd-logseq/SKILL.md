---
name: gtd-logseq
description: Practice David Allen's Getting Things Done (GTD) using the Logseq knowledge graph at ~/vault/logbook. Provides templates, workflows, conventions, and guidance for building a complete GTD trusted system in Logseq.
category: note-taking
---

# Getting Things Done (GTD) with Logseq

GTD is a personal productivity system built on five stages: **Capture**, **Process**, **Organize**, **Review**, and **Execute**. This skill turns your Logseq graph into a GTD trusted system — a single place for all your commitments, projects, and next actions.

**Graph location:** `~/vault/logbook` (Logseq — "logbook")

---

## When to Load This Skill

Load this skill when:
- You want to set up GTD in your Logseq graph for the first time
- You want to do an initial brain dump / inbox processing session
- You want to run your weekly review
- You're unclear about which GTD surface an item belongs on
- You want guidance on creating a new project, adding a next action, or organizing an item
- You want to review your current GTD system status

---

## GTD Surfaces

Your GTD system lives as individual pages in the graph. Start at the hub:

- **[[GTD Hub]]** (`pages/gtd.md`) — entry point, links to all surfaces
- **[[GTD Inbox]]** (`pages/gtd-inbox.md`) — capture everything here first
- **[[Next Actions]]** (`pages/gtd-next-actions.md`) — every active next action
- **[[Waiting For]]** (`pages/gtd-waiting-for.md`) — delegated or pending items
- **[[Someday/Maybe]]** (`pages/gtd-someday-maybe.md`) — not now, but interesting
- **[[Reference]]** (`pages/gtd-reference.md`) — non-actionable information
- **[[GTD Contexts]]** (`pages/gtd-contexts.md`) — context tag reference

---

## Key Conventions

### Task Markers
GTD states map to Logseq's native task markers:
- `TODO` — next action (active)
- `LATER` — someday/maybe item
- `DONE` — completed
- `CANCELED` — trashed or deferred
- `WAITING` — simulated with `LATER` + `#@waiting` tag

### Context Tags
Contexts filter what you can do in a given setting. Use `#@context` notation:
`#@calls` `#@home` `#@work` `#@errands` `#@computer` `#@office` `#@reads` `#@reviews`

Contexts are user-extensible. If you create an action with a new `#@context` tag, I'll ask if you'd like to add it as a formal context.

### Areas of Focus
GTD's higher horizons (20k–50k ft). Each area is a Logseq page linking to related projects. Convention:

```
tags:: #area-of-focus

<one-line description>

## Active Projects
- [[project-page]]

## Someday/Maybe
```

When creating a project, always ask which area it belongs to and link it from the area page. Common areas: environment, health, finances, relationships, career, learning.

### Projects
Every project uses the **`project-planning` template** — see `templates/project-planning.md` for the full layout. If the graph has no template page yet, seed it from that file into the graph first.

Projects have three statuses: `status:: active`, `status:: someday`, `status:: completed`. Always set `area:: [[area-name]]` on the project page.

### 2-Minute Rule
If an inbox item can be done in under 2 minutes, do it now — don't put it in the system.

---

## How to Work with This Skill

This skill uses an **OpenSpec-style interaction model**: I produce a full plan or capture, you review it as a readable file, then we reconcile. We don't do it item-by-item through conversation.

Typical workflow:
1. You tell me what you want to work on (brain dump, inbox processing, weekly review, etc.)
2. I produce a plan or capture file for you to read
3. You annotate, adjust, or approve
4. We apply changes together

---

## Sub-Skills and References

### Weekly Review
The weekly review is the "critical success factor" of GTD. It lives as a dedicated sub-skill:

```
skill_view("gtd-logseq", file_path="references/gtd-weekly-review.md")
```

Load this when you're ready to run your weekly review. It includes the 3-phase, 11-step structure, a Logseq journal checklist template, a moving-items-between-surfaces table, and troubleshooting.

### Initial Brain Dump
When setting up GTD for the first time, use the brain dump guide:

```
skill_view("gtd-logseq", file_path="references/gtd-brain-dump.md")
```

It walks you through capturing everything in your head in one session, then processing it.

---

## Non-GTD Pages in the Graph

The graph can hold pages that aren't GTD surfaces — research link collections, reading lists, topic reference pages. These use normal Logseq page conventions (headings, lists, links) without GTD templates or status markers. Example: `ai-research.md` — saved papers and links organized by date.

## Existing Projects

Discover these dynamically — search the graph for `template:: project-planning` pages. Do not hardcode a list here; it goes stale immediately.

## Young Graph Note

If the graph doesn't have the full GTD surface set yet (no GTD Hub, no Next Actions page), projects and areas can be created standalone. They get wired into the full system later when surfaces are set up. Don't block project creation on missing infrastructure.

---

## Workflows

### Capture → Inbox → Process
1. Open [[GTD Inbox]]
2. Append any new thought, task, or idea as a bullet with a timestamp
3. When you're ready to process, I can generate a **processing plan** — a file listing every inbox item with a suggested surface and action for each. You review and adjust, then we apply.

### Create a New Project
1. Create a page using `template:: project-planning`
2. Fill in Principles/Purpose, Values, Outcome Visions, Brainstorm, Organize
3. Add at least one concrete action in the Actions section
4. Link that action to [[Next Actions]] via `[[Next Actions#block-id]]`
5. I can generate a project creation brief if you want help thinking it through

### Run a Weekly Review
1. Load `references/gtd-weekly-review.md`
2. Open today's journal entry
3. Copy the checklist from the review reference into your journal
4. Work through GET CLEAR → GET CURRENT → GET CREATIVE
5. I can pre-populate a review status file so you can see all your surfaces at once before diving in

---

## Files Created by This Skill

| File | Purpose |
|------|---------|
| `pages/gtd.md` | GTD hub — central navigation |
| `pages/gtd-inbox.md` | Inbox — capture entry point |
| `pages/gtd-next-actions.md` | Next Actions list |
| `pages/gtd-waiting-for.md` | Waiting For list |
| `pages/gtd-someday-maybe.md` | Someday/Maybe list |
| `pages/gtd-reference.md` | Reference material |
| `pages/gtd-contexts.md` | Context taxonomy |
| `journals/gtd-weekly-review-template.md` | Weekly review journal template |
| `references/gtd-brain-dump.md` | Initial brain dump guide |
| `references/gtd-weekly-review.md` | Weekly review sub-skill |
| `references/gtd-projects.md` | Project lifecycle guide |
| `templates/project-planning.md` | Logseq project-planning template — seed into graph as `pages/project-planning.md` if missing |
| `templates/area-of-focus.md` | Logseq area-of-focus page template |
