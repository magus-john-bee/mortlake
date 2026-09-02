---
name: gtd-edit-task
description: Edit, update, or manipulate existing taskdog tasks — rename, retag, reprioritize, reschedule, edit notes, wire or unwind dependencies, change status (start/pause/done/cancel/reopen), or delete. Use when the user names a task and wants it changed ("rename X", "bump the priority on X", "X is done", "add a dep from X to Y", "what's blocking X?"). Not for planning whole projects (gtd-plan-project) or creating standalone new tasks that aren't project steps.
category: note-taking
version: 1.0.0
license: MIT
metadata:
  hermes:
    tags: [gtd, taskdog, task-editing]
    related_skills: [gtd-taskdog, gtd-plan-project]
---

# Edit a taskdog task

The edit surface at a glance — pick by what changes:

| Change | Command |
|---|---|
| Name, priority, estimate, deadlines, planned times | `taskdog update <id> --name/--priority/--estimated-duration/--deadline/--planned-start/--planned-end` |
| Status | `start` / `pause` / `done` / `cancel` / `reopen` |
| Tags | `taskdog tag set <id> <tags…>` (**replaces the whole list**) |
| Notes | `taskdog note <id> -c "…"`, `-a` to append, `-f <file>` |
| Dependencies | `taskdog dep add/rm <dependent> <dependency>` |
| Show with notes | `taskdog show <id> --raw` |
| Find task by name/tag | `taskdog list [-t <tag>] [-f id,name,…]` |
| Delete | `taskdog rm <id>` (archive) / `--hard` (permanent) |

`update` and `tag set` are the only commands that change existing properties
in place. Status commands are dedicated. Never edit the SQLite DB directly.

## Resolution — name → ID

The user says names; taskdog IDs are numbers. Resolve before editing:

1. `taskdog list -f id,name,status,tags,depends_on` (or filtered by tag when
   the user gave a project).
2. Exact name match → proceed. If not unique, add tags/context from the
   conversation to disambiguate.
3. **Still ambiguous → show the candidates and ask.** Never edit blind.

Contexts are bare tags (`errand`, `home`, `work`, `deep`, `phone`,
`computer`), areas `area/<name>`, role tags `project` / `waiting`, project
tags `proj/<slug>`.

## Edit recipes

**Rename / reprioritize / reschedule**
```bash
taskdog update 12 --name "Call the roofer" --priority 7
taskdog update 12 --deadline "2026-09-04 17:00:00" --estimated-duration 0.5
```

**Retag (replaces all tags — read current first)**
```bash
taskdog tag list 12          # or: taskdog show 12 --raw
taskdog tag set 12 proj/roof errand
```

**Status**
```bash
taskdog start 12 && taskdog done 12      # done refuses on PENDING
taskdog pause 12                         # → PENDING, resets time tracking
taskdog cancel 12; taskdog reopen 12     # cancel also via
                                         # taskdog update 12 --status CANCELED
```

**Notes**
```bash
taskdog note 12 -c "# Context …"          # replace
taskdog note 12 -a -c "Follow-up: …"      # append
```

**Dependencies (dependent first!)**
```bash
taskdog dep add 30 12   # task 30 now waits on task 12
taskdog dep rm 30 12
```

**Waiting-fors**
```bash
taskdog add "waiting: roof quote — roofing co" -t waiting
taskdog dep add 12 <new_waiting_id>     # the next action now waits on it
```

**Delete**
```bash
taskdog rm 12          # archive (default, recoverable via restore)
taskdog rm --hard 12   # permanent — confirm with user first
```

**What's blocking this task?**
```bash
taskdog show <id> --raw
# then for each ID in Depends On:
taskdog show <dep_id> --raw | head -20
```

## After every edit

Re-show the task and report the changed fields to the user — never report
success from the exit code alone.
