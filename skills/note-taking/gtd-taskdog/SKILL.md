---
name: gtd-taskdog
description: Practice David Allen's Getting Things Done (GTD) using taskdog (the central instance at https://taskdog.otwell.dev, server on uriel). Covers capture, clarification, organization into contexts/areas/projects, the anchor-complete project pattern, weekly review queries, and restore drills. Use when the user mentions taskdog, asks to add/organize/review tasks or projects, or wants GTD workflow operations against the central server.
category: note-taking
version: 1.0.0
license: MIT
metadata:
  hermes:
    tags: [gtd, taskdog, task-management, productivity]
    related_skills: [gtd-logseq]
---

# Getting Things Done (GTD) with Taskdog

Taskdog is THE system of record for actionable GTD state: next actions, projects (as anchors), waiting-fors tracked via dependencies, calendar-ish commitments via deadlines. Someday/Maybe lists stay in the Logseq logbook (gtd-someday-maybe page) — taskdog is for actual planning only. When capturing something that might be someday/maybe, ask the user (or default to inbox-style capture) rather than auto-filing into logbook.

## Topology & Access

- **Server**: uriel, systemd user service (john), `127.0.0.1:8000` behind nginx at **https://taskdog.otwell.dev** (ACME cert, API-key auth). All keys in sops (`taskdog-api-key-*` in secrets.yaml); server.toml rendered by sops template `taskdog-server-toml`.
- **Clients**: jehoel, raphael, uriel itself — cli.toml symlinked to sops template `taskdog-cli-toml` (base_url = https://taskdog.otwell.dev, hostname-switched key).
- **Hermes**: gets `TASKDOG_API_BASE_URL` + `TASKDOG_API_KEY` (key `hermes`) via hermes-env — env beats cli.toml, works regardless of HOME.
- **Data**: SQLite at `/home/john/.local/share/taskdog/tasks.db` on uriel (+ per-task markdown notes in `notes/`). Persisted via preservation; backed up by hourly WAL-safe snapshots (24h) + daily (14d) in `backups/`, restic→B2 once re-enabled.
- **Module**: `modules/features/taskdog.nix` (`services.taskdog.server.enable` / `client.enable`).
- **Local access from any host**: `taskdog list` etc. — cli.toml does the routing.

## Core Conventions

### Tags = Contexts + Areas

Two tag families, one namespace:

- **Contexts** — bare lowercase: `errand`, `home`, `work`, `deep`, `phone`, `computer`. The classic GTD contexts; assign at least one to every actionable task.
- **Areas** — prefixed: `area/health`, `area/devops`, `area/career`. Areas of focus for reviews and horizon 2+ views. Assign where relevant.
- **Role tags** — `project` (on anchors, see below), `waiting` (see Waiting-fors).
- **Handoff tags** — `uriel-blocker`, `uriel-can` (see Agent-handoff tags).

### Projects: the Anchor-Complete Pattern

Taskdog's flat dependency graph models projects as a milestone *sink*, not a parent container. Every project = one anchor task + free-floating steps:

```
anchor: "Project X shipped"   tags: [project, proj/x]  depends_on: [step1, step2, step3]
step1:  "Draft spec"          tags: [proj/x, deep]
step2:  "Buy parts"           tags: [proj/x, errand]
```

Rules:

1. **Anchor depends on steps, never the reverse.** The anchor becomes executable exactly when all steps complete — a natural "close out the project" trigger. Steps stay actionable from birth. Reversed edges deadlock by convention.
2. **Tags do the grouping, edges do only ordering.** There is no project view; `taskdog list --tag proj/x` IS the project view. Anchor's depends_on is a bonus index.
3. **Vertical planning lives in the anchor's notes.** Outcome, principles, brainstorm, natural planning model — per-task markdown. Steps = horizontal focus.
4. **Don't chain steps unless sequencing is real.** Executability requires every dep strictly COMPLETED (verified in task_query_service.py: a canceled or archived dep blocks forever). Cancel a step → manually `taskdog dep rm <anchor> <step>`. The weekly review must flag anchors whose deps contain non-completed, non-pending tasks (the cancel-orphan case).
5. **Creation flow**: steps first (`taskdog add "..." -t proj/x`), then anchor, then `taskdog dep add <anchor_id> <step_id>` for each step (first arg is the dependent).
6. **One anchor per project.** Multiple anchors on shared steps split the outcome; if a project needs phases, tag them `proj/x-phase1` etc. and give each phase its own anchor, chained anchor→prior-phase-anchor.

### Waiting-fors

Someone else holds the ball: create a task `waiting: <what> — <who>`, tag `waiting` + context/area as appropriate, and if it's blocking a next action, edge the next action to depend on it. Completion of the waiting-for unblocks automatically (strict-COMPLETED rule works for you here).

### Agent-handoff tags

Two role tags covering the Hermes↔john seam. **Default is unlabeled**: most tasks carry no handoff tag even when it's obvious who will do them — tag only when the tag is the information.

- **`uriel-blocker`** — the smallest discrete unit of work that *only john can do* and that blocks agent work (UI-only actions, credentials, decisions). Hermes files these the moment it hits a wall; one click = one task, never a bundle. If the blocked agent work is itself a task, edge it: `taskdog dep add <agent_task> <blocker>`. Completing the blocker unblocks automatically. Treat `taskdog list -t uriel-blocker --status pending` as john's queue — surface it when the user asks "what do you need from me".
- **`uriel-can`** — a whole task Hermes can execute end-to-end with zero input. Used to park delegable work (from john or from planning) in a pick-up queue; Hermes working idle can pull from `taskdog list -t uriel-can --status pending`.

Neither tag replaces contexts/areas — combine freely (`-t uriel-blocker -t computer`). A blocker resolved without an agent task depending on it still gets `done` normally.

### Calendar vs Tasks

Taskdog deadlines are soft scheduling metadata for the optimizer — not the GTD calendar. Time-specific commitments still go on a real calendar. Use taskdog deadlines for "must complete by" and let `taskdog optimize` spread work (US holidays respected via region=US).

### Capturing & Clarifying

Quick capture first, clarify during processing. `taskdog add "<thought>"` with zero ceremony — no tags, no priority. Then processing assigns context/area tags, priority, deadline, and either wires it into a project or leaves it standalone.

## Weekly Review Queries

Run these (or ask Hermes to run them) weekly:

```bash
# Open loops: pending tasks sorted by age
taskdog list --status pending --sort created_at
# Stuck anchors: project anchors whose deps contain non-completed tasks —
taskdog list -t project --status pending   # then per anchor:
taskdog show <id>                          # inspect depends_on statuses
# Waiting-fors (review age via created_at ordering)
taskdog list -t waiting --sort created_at
# John's blocker queue — things only the user can do, blocking agent work
taskdog list -t uriel-blocker --status pending --sort created_at
# Agent pick-up queue
taskdog list -t uriel-can --status pending
# Upcoming deadlines
taskdog list --sort deadline --status pending
```

## Restore Drill

`taskdog db backup` (server-side `VACUUM INTO` — WAL-safe, no stop needed) produces `.db` snapshots; hourly kept 24h + daily kept 14d live in `~/.local/share/taskdog/backups/` on uriel.

1. `taskdog db restore <snapshot.db>` — schedules restore-on-restart (no manual stop/copy dance).
2. Restart the server: `systemctl --user restart taskdog-server` (as john on uriel).
3. Verify: `taskdog list` from any host.

## Pitfalls

- **Canceled/archived deps block forever.** The one maintenance tax of the anchor pattern. Weekly review catches orphans; fix with `taskdog dep rm <anchor> <step>` (first arg = dependent).
- **No cascade.** Canceling a step doesn't touch the anchor or siblings — by design (dependencies define order, not ownership).
- **`dep add` argument order**: first arg = dependent, second = dependency. Reversed edges silently invert your project logic.
- **`db backup` from a remote host pulls the snapshot over the API** — run it ON uriel (or accept the transfer).
- **CLI flags verified against taskdog 0.26.0** (`-t/--tag`, `--sort created_at`, `dep add/rm`, `db backup/restore`). Re-verify `taskdog --help` after version bumps.
- **`~` resolves to /var/lib/hermes** for the Hermes service — use absolute `/home/john/...` paths when reading DB state directly.
- **DNS**: taskdog.otwell.dev needs its Porkbun A-record → 87.99.146.205. If NXDOMAIN, that's the cause; ACME will fail until it exists.

## Related

- gtd-logseq skill — someday/maybe lists and reference material stay in logbook.
- Mortlake module: `modules/features/taskdog.nix`; GTD conventions: this skill.
