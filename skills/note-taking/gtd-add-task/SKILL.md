---
name: gtd-add-task
description: Add a single task (next action) to taskdog — either a standalone task or a step belonging to an existing GTD project (tagged proj/<slug>, wired to the project's anchor). Use when the user gives one actionable item to capture ("add a task …", "new next action for X", "I need to …"). Not for planning whole projects (gtd-plan-project), changing existing tasks (gtd-edit-task), or someday/maybe items (those stay in the logbook).
category: note-taking
version: 1.0.0
license: MIT
metadata:
  hermes:
    tags: [gtd, taskdog, task-capture]
    related_skills: [gtd-taskdog, gtd-plan-project, gtd-edit-task]
---

# Add a taskdog task

One actionable item → one task. Two paths, decided first:

## Path decision

- **Project step** — the user names a project, or the task clearly extends a
  known project. Find the slug: from the user's words, or list anchors:
  `taskdog list -t project -f id,name,tags`. Unsure which project → show
  candidates and ask. No matching project and the item is really an outcome,
  not an action → suggest `gtd-plan-project` instead.
- **Standalone** — everything else. No project machinery.
- **User-blocker or agent task?** — if the item is a smallest-discrete-unit
  only the user can do and it blocks work, add `-t uriel-blocker`; a whole
  task Hermes can do end-to-end gets `-t uriel-can` (see gtd-taskdog
  "Agent-handoff tags"). Default: no handoff tag at all.
- **Someday/maybe?** Stays in the logbook (`gtd-someday-maybe.md`), never
  taskdog. If the user hedges ("maybe, eventually"), ask before filing.

## Path A — project step

```bash
# 1. Find the project's anchor (the task tagged `project`)
taskdog list -t proj/<slug> -f id,name,status,tags

# 2. Add the step — proj tag + context; estimate/deadline only if volunteered
taskdog add "<action>" -t proj/<slug> [-t <context>] [-e <hours>] [-D "YYYY-MM-DD HH:MM:SS"]

# 3. Wire it to the anchor so completing it counts toward the outcome
taskdog dep add <anchor_id> <new_step_id>

# 4. Verify
taskdog list -t proj/<slug> -f id,name,status,depends_on
```

Anchor unknown/not yet created → that's project planning, use
`gtd-plan-project`.

## Path B — standalone task

Apply what the user already said; don't interrogate:

```bash
taskdog add "<action>" [-t <context>] [-t area/<name>] [-p <priority>] \
  [-e <hours>] [-D "YYYY-MM-DD HH:MM:SS"]
```

- User gave just a thought, no metadata → **zero ceremony**: bare
  `taskdog add "<thought>"`. Clarification happens later, during processing.
- Someone else holds the ball → it's a waiting-for, not a task:
  `taskdog add "waiting: <what> — <who>" -t waiting` (edge the blocked
  action to it per `gtd-edit-task` if applicable).

## Conventions

- **Name starts with a physical verb** — "Draft…", "Call…", "Order…", not
  "Work on…" / "Handle…". Keep the user's wording otherwise.
- Contexts are bare tags (`errand`, `home`, `work`, `deep`, `phone`,
  `computer`), areas `area/<name>`, project tag `proj/<slug>`.
- Estimates are hours (float), deadlines `"YYYY-MM-DD HH:MM:SS"`. Only set
  when the user volunteers them.
- Don't chain steps to sibling steps — only the anchor edge.

## Verify + report

Re-list (or `taskdog show <id>`) and report the new task's **ID, name,
tags**, and — for project steps — the anchor edge. Never report success from
exit code alone.
