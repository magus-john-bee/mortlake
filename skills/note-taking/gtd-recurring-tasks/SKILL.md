---
name: gtd-recurring-tasks
description: Wire recurring commitments (trash day, filter changes, restore drills, review digests) as Hermes cron jobs that auto-create their taskdog task instances — script-only for fixed cadences, agent-driven when judgment is needed. Use when the user wants recurring/routine tasks to appear in taskdog automatically, or asks for a cron job that creates tasks. Not for one-off tasks (gtd-add-task) or projects (gtd-plan-project).
category: note-taking
version: 1.0.0
license: MIT
metadata:
  hermes:
    tags: [gtd, taskdog, cron, recurring, automation]
    related_skills: [gtd-taskdog, gtd-add-task, gtd-edit-task]
---

# Recurring taskdog tasks via Hermes cron

taskdog has no native recurrence. This skill materializes a recurring
commitment as fresh task instances on schedule, dedup-guarded so missed
ticks and re-runs never double-create.

Cron jobs are Hermes-side (the gateway host — taskdog env lives there);
pi/prime-agent read the tasks but don't run the jobs. That's fine: taskdog
is the central store.

## Gather before creating (the only checkpoint)

Confirm these four with the user before writing anything:

1. **Task name + context tag** — physical-verb name, bare context tag
   (`home`, `errand`, …). Follows gtd-add-task conventions.
2. **Schedule** — cron expr or shorthand (`0 8 * * 1`, `every 2h`).
   Host timezone applies (uriel: America/New_York).
3. **Day-of vs ahead-of-time** — created the morning it's due, or a week
   ahead for visibility? Same script, different schedule. Default: day-of.
4. **Announce vs silent** — one-line ping to the chat when a task is
   created, or fully silent? Default: announce-on-create-only.

## Pattern A — script-only (default; fixed cadences, zero tokens)

Write the script to `~/.hermes/scripts/recurring-<slug>.sh`:

```bash
#!/usr/bin/env bash
# <task name> — recurring taskdog instance (gtd-recurring-tasks)
# Cron runs scripts with a MINIMAL PATH (no /run/current-system/sw/bin) —
# restore it first or taskdog = "command not found" (exit 127, seen live).
export PATH=/run/current-system/sw/bin:/usr/bin:/bin:$PATH
set -euo pipefail
NAME="<task name>"
FRAGMENT="<distinctive name substring>"
# Default taskdog list hides completed/canceled — a hit here means a
# pending instance already exists; stay silent (empty output = no ping).
if taskdog list --status pending -f name | grep -qF "$FRAGMENT"; then
  exit 0
fi
taskdog add "$NAME" -t <context> >/dev/null
echo "Created task: $NAME"
```

Then create the job (cronjob tool):

```
action=create
name=recurring-<slug>
schedule=<cron expr>
no_agent=true            # script IS the job; no LLM, no tokens
script=recurring-<slug>.sh   # relative to ~/.hermes/scripts/
deliver=origin           # default; created-task line pings the home chat
```

Semantics that matter: non-empty stdout is delivered verbatim; **empty
stdout is silent**; non-zero exit alerts. The guard prints nothing when
the task exists — that's the quiet path, by design.

## Pattern B — agent-driven (judgment needed)

For digests and review-type recurrences (e.g. weekly GTD review): the job
runs an agent against `gtd-taskdog` review queries.

- `prompt` must be **self-contained** — cron runs in a fresh session with
  zero chat context. Spell out: run the review queries (stuck anchors,
  waiting-for age, upcoming deadlines), deliver a compact digest.
- `skills=["gtd-taskdog"]`, `enabled_toolsets=["terminal"]` to keep the
  job lean.
- `continuity=true` for anything that dedups against its own last output.
- Never agent-driven what a 6-line script can do.

## Dedup semantics (why the guard is correct)

`taskdog list` default view excludes completed/canceled/archived — so
"pending instance exists" is exactly "not yet done". Completing the task
makes the next tick create a fresh instance: that IS the recurrence. The
guard also absorbs overlapping ticks and Hermes restarts.

## Pitfalls

- **Minimal PATH in the cron runner** — scripts execute WITHOUT
  `/run/current-system/sw/bin` on PATH; every NixOS system binary (taskdog,
  curl, …) is "command not found" (exit 127). The template's `export PATH=`
  line is load-bearing; never omit it. Verify with
  `env -i /bin/bash <script>` (not from a login shell, which masks it).

- **Never extract an ID by list position** (`head -1` of the pending list
  is *some* task, not *the* task). Resolve by name fragment → matching row
  → that row's ID. In scripts, prefer `taskdog update/note/done` with an
  ID captured at creation time (`taskdog add` prints it), or grep the
  id+name table for the fragment and read the ID off **that row**.
- **Table wrapping breaks exact-match grep** — long names wrap across
  lines in `taskdog list` output. Match a distinctive *fragment*
  (grep -qF), never the full name with -x.
- **Don't verify by firing the job** — a test run creates a real task,
  possibly before the user wanted it. Verify instead: run the guard line
  alone in terminal (expect clean exit), and confirm the job in
  `cronjob action=list`.
- **Changing cadence** = update the job (list → update by job_id), don't
  create a near-duplicate.
- **Removal**: `cronjob action=list` → `remove` by job_id, then delete
  the script file. Leftover scripts are harmless but rot.

## After creating

Report to the user: job name, schedule (in their tz), the exact task line
it creates, announce/silent behavior, and how to kill it later. Offer
nothing else — recurrence is now the job's business, not theirs.
