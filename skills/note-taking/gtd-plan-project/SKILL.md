---
name: gtd-plan-project
description: Plan a GTD project in taskdog via David Allen's informal (natural) planning model — purpose & principles, outcome visioning, brainstorming, organizing, identifying next actions — then scaffold it as an anchor-complete project (anchor task + steps + vertical-planning notes). Use when the user wants to plan, scope, or think through a project and land it in taskdog. Not for single next actions, quick capture, or someday/maybe items.
category: note-taking
version: 1.0.0
license: MIT
metadata:
  hermes:
    tags: [gtd, taskdog, project-planning, natural-planning]
    related_skills: [gtd-taskdog, gtd-edit-task, gtd-logseq]
---

# GTD Informal Project Planning → taskdog

Run David Allen's **natural planning model** conversationally with the user,
then write the result to taskdog as an anchor-complete project. The thinking is
the user's — your job is the questions, the structure, and the scaffolding.

Works from any host with the taskdog client (`TASKDOG_API_*` env or
`cli.toml` routes to https://taskdog.otwell.dev).

**Topic source:** text after the slash command, the user's message, or asked
interactively if none given.

## Hard rules (read first)

- **Someday/Maybe stays in the logbook**, never taskdog. If planning reveals
  the user isn't actually committed, stop and say so — don't scaffold.
- **Anchor depends on steps, never the reverse.** One anchor per project.
  Phases → `proj/<slug>-phase1`, `proj/<slug>-phase2`, each with its own
  anchor.
- **Don't chain steps to each other** unless sequencing is real. Unsequenced
  steps are actionable from birth.
- **Confirm the full scaffold before writing anything.** This is the only
  checkpoint.
- Tags: project tag `proj/<kebab-slug>` (short), contexts bare (`errand`,
  `home`, `work`, `deep`, `phone`, `computer`), areas `area/<name>`. Anchor
  also gets the `project` role tag.
- Estimates are hours (float), deadlines are `"YYYY-MM-DD HH:MM:SS"`. Only set
  when the user volunteers them.

## Phase flow

One phase at a time, **max 2–3 short questions per phase**. If the user's
opening message already answers a phase, summarize what you heard and move on —
never re-ask. If the user says "skip" or "just scaffold", jump to Scaffold with
what you have. Only Next Actions is mandatory.

### 1. Purpose & Principles
- "Why do this at all? What changes if you do / don't?"
- "What ground rules govern it — budget, standards, constraints?"
- Capture 1–3 bullets. Purpose = why; principles = how it must behave.

### 2. Outcome Visioning
- "It's done and it's a wild success — what do you see?"
- Capture the picture of done in concrete, sensory terms. This becomes the
  anchor name's test: "<Outcome> shipped".

### 3. Brainstorming
- Open generation, no judgment, get quantity: "What's on your mind about
  this? What could be part of it?"
- You may seed ideas from the purpose/outcome, clearly as suggestions — the
  user's list leads. Capture everything, including half-baked ones (they may
  become notes, not steps).

### 4. Organizing
- Cluster the brainstorm into components; sequence only where order is real.
- Spot gaps: "What's missing? What has to be true first?"
- Distinguish **steps** (doable work) from **notes-only** material (context,
  ideas, reference — stays in notes).

### 5. Identifying Next Actions
- Every open component gets at least one **physical, visible next action**,
  starting with a concrete verb ("Draft…", "Call…", "Order…" — not "Work
  on…", "Handle…").
- If someone else holds the ball for a component: waiting-for, not a next
  action (see Scaffold).

## Scaffold (after user approves)

```bash
# 0. Check for slug collision — if non-empty, extend that project instead
taskdog list -t proj/<slug>

# 1. Steps first (one add per step)
taskdog add "<next action>" -t proj/<slug> [-t <context>] [-e <hours>] [-D "YYYY-MM-DD HH:MM:SS"]

# 2. Anchor — the outcome, completable exactly when all steps complete
taskdog add "<Outcome> shipped" -t project -t proj/<slug>

# 3. Edges — dependent FIRST (anchor depends on each step)
taskdog dep add <anchor_id> <step_id>

# 3b. Real step→step sequencing found during Organizing (e.g. "listing
#     waits on triage AND wipes") — wire it NOW, not after the fact:
#     dependent first, one edge per real prerequisite
taskdog dep add <later_step_id> <earlier_step_id>

# 4. Waiting-fors (if any): "waiting: <what> — <who>" tagged waiting,
#    and edge the blocked action to depend on it
taskdog add "waiting: <what> — <who>" -t waiting -t proj/<slug>
taskdog dep add <blocked_action_id> <waiting_for_id>

# 5. Vertical planning → anchor notes (template below)
taskdog note <anchor_id> -c "<markdown>"

# 6. Verify
taskdog list -t proj/<slug> -f id,name,status,depends_on,tags
taskdog show <anchor_id> --raw
```

### Anchor notes template

```markdown
# <Project>

## Purpose & Principles
- …

## Outcome Vision
- …

## Brainstorm
- …

## Organized Plan
<components / sequence, prose or list>

## Next Actions
- [ ] <action> (#<step_id>)
```

## Verify before reporting done

- Every step PENDING, correctly tagged, no accidental step→step edges —
  but every **real** prerequisite edge from Organizing IS present (gated
  steps are correctly unready).
- Anchor `depends_on` lists every step (and only steps).
- Notes saved (check `taskdog show <anchor_id> --raw` output).
- Report the anchor ID + step IDs in a compact list.

## Failure modes

- **`done` refused on PENDING steps** — lifecycle is `start` → `done`. Don't
  try to pre-complete steps during scaffold.
- **Existing project with same slug** — either pick a new slug or extend: add
  steps, then `taskdog dep add <existing_anchor> <new_step>`.
- **A step balloons into its own outcome** — split it out as a sub-project
  with its own slug + anchor; note the linkage in both anchors' notes.
