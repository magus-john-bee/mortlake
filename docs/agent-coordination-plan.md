# Agent Coordination Plan

Multi-agent task coordination for mortlake using jj workspaces, OpenSpec, and
plaintext — no external task manager.

## Design principles

1. **No external task manager.** Evaluated lodestar, claimd, beans, hence — all
   overbuilt for <12 agents. The commit graph + a markdown file is sufficient.
2. **The commit graph IS the task DAG.** jj parent chains encode dependencies;
   auto-rebase propagates upstream changes to dependent branches for free.
3. **OpenSpec carries the spec content.** Each task maps to an OpenSpec change
   in `openspec/changes/<change-name>/`. No duplication of spec material in the
   coordination file.
4. **Agents communicate via plaintext.** A single `COORDINATION.md` at repo root
   tracks claims, status, and handoff notes. For a dozen agents this is trivially
   readable and writable by any LLM agent — no CLI to learn, no `--json` parsing.
5. **herdr owns process lifecycle.** Stale-agent detection is a herdr hook, not
   a lease daemon.

## Three layers

| Layer | Tool | Responsibility |
|-------|------|----------------|
| Structural | jj | Workspaces (agent isolation), bookmark chains (dependency edges), auto-rebase (propagation) |
| Spec | OpenSpec | Change proposals, delta specs, acceptance criteria, archive on completion |
| Coordination | `COORDINATION.md` | Claim state, agent roster, task status, handoff notes |

## jj workspace model

```
~/src/mortlake/                    ← integration workspace (trunk)
│  Only this workspace runs `nixos-rebuild switch`.
│  Merges land here. Dependent bookmarks auto-rebase.
│
├── COORDINATION.md                ← coordination state (committed)
├── .claims/                       ← atomic lock dirs (gitignored)
│
~/src/mortlake-pi-1/               ← workspace: pi-1
~/src/mortlake-pi-3/               ← workspace: pi-3
~/src/mortlake-codex-1/            ← workspace: codex-1
```

Each workspace shares one jj object store. `jj log --graph` from any workspace
shows the full commit DAG across all agents.

### Bookmark conventions

```
task/<change-name>     ← one bookmark per task, matches OpenSpec change name
```

- **Linear dependency** (B depends on A): B's commit is a child of A's in the
  graph. When A merges to trunk, jj auto-rebases B on top.
- **Diamond dependency** (C depends on A and B): C's parent is a merge commit
  of A and B. jj handles multi-parent commits natively.
- **Independent tasks**: separate bookmarks off trunk, no parent relationship.
  Run in parallel, merge independently.

### What "done" means

A task is done when its bookmark merges to trunk (main bookmark). jj auto-rebases
all children. The agent then updates COORDINATION.md to reflect completion. Any
downstream task that was `blocked` becomes `ready` — either an agent polls
COORDINATION.md and notices, or a handoff note signals it.

## COORDINATION.md schema

```markdown
# Agent Coordination

## Active Agents
| Agent | Workspace | Host | PID | Last Seen |
|-------|-----------|------|-----|-----------|
| pi-1 | mortlake-pi-1 | uriel | 12345 | 2026-08-09T10:30Z |
| pi-3 | mortlake-pi-3 | uriel | 12346 | 2026-08-09T10:31Z |

## Tasks

### fix-auth
- bookmark: task/fix-auth
- status: in_progress
- claimed_by: pi-3
- started: 2026-08-09T10:00Z
- depends_on: refactor-session (done)
- spec: openspec/changes/fix-auth/
- notes: OAuth flow implemented, needs tests

### write-tests
- bookmark: task/write-tests
- status: blocked
- depends_on: fix-auth (in_progress), setup-ci (ready)
- spec: openspec/changes/write-tests/

### setup-ci
- bookmark: task/setup-ci
- status: ready
- notes: no blockers

## Handoff Log

[2026-08-09T10:15Z pi-3] fix-auth: found the bug — session middleware wasn't
  propagating the OAuth scope. Fix in commit abc123. Tests can proceed once
  this merges.

[2026-08-09T10:30Z pi-1] setup-ci: CI is green. write-tests unblocked once
  fix-auth lands.
```

### Task status values

| Status | Meaning |
|--------|---------|
| `ready` | All deps done. Any free agent can claim. |
| `in_progress` | Claimed by an agent with a live workspace. |
| `blocked` | Waiting on one or more dependencies to complete. |
| `done` | Merged to trunk. Dependents auto-unblocked. |
| `needs_review` | Work complete, awaiting human or agent review before merge. |
| `blocked_on_human` | Agent hit a decision point requiring user input. |

The `blocked_on_human` state is how agents surface questions to you — scan
COORDINATION.md for this status to see who's waiting.

## Claim protocol

Atomic claims via `mkdir` (POSIX-guaranteed atomic — succeeds or EEXIST):

```bash
# 1. Find a ready task in COORDINATION.md
# 2. Attempt claim
mkdir ~/src/mortlake/.claims/<task-id>   # atomic: succeeds or fails with EEXIST

# 3. If mkdir succeeded → you own the claim
#    Edit COORDINATION.md: status → in_progress, claimed_by → <agent-name>
#    Commit the change

# 4. If mkdir failed (EEXIST) → another agent got there first
#    Go back to step 1, pick a different task
```

### Release on completion

```bash
# 1. Merge task bookmark to trunk
jj bookmark set main -r <merge-commit>
# 2. Update COORDINATION.md: status → done
# 3. Commit
# 4. Release the lock
rmdir ~/src/mortlake/.claims/<task-id>
```

### Release on abandonment

```bash
# Agent gives up or hits a blocker
# 1. Update COORDINATION.md: status → blocked or ready, clear claimed_by
# 2. Append handoff note explaining why
# 3. rmdir ~/src/mortlake/.claims/<task-id>
```

## Stale-agent cleanup (herdr hook)

herdr tracks agent process lifecycles. A post-exit hook (or periodic cron) does:

1. Read COORDINATION.md, find all `in_progress` tasks with `claimed_by` entries.
2. Cross-reference against live agent processes (herdr session list).
3. For any dead agent with an active claim:
   - `rmdir ~/src/mortlake/.claims/<task-id>`
   - Update COORDINATION.md: status → `ready`, clear `claimed_by`
   - Append handoff note: `[<timestamp> system] <agent> process died, task released`

This replaces TTL-based lease expiry. Simpler, no timer daemon, no heartbeats.

## Agent workflow (the loop each Pi agent runs)

```
1. Read COORDINATION.md
2. Find a task where status=ready AND all depends_on are done
   - If none found → wait or signal "no work available" to herdr
3. Claim the task (mkdir .claims/<id>, edit COORDINATION.md, commit)
4. Ensure workspace exists:
   jj workspace add --name <agent-name> ../mortlake-<agent-name>
5. Set bookmark on current commit:
   jj bookmark set task/<change-name>
6. Read the spec: openspec/changes/<change-name>/
7. Implement the change (normal Pi workflow)
8. Commit work to the task bookmark
9. When done:
   - Merge to trunk
   - Update COORDINATION.md: status → done
   - Release lock (rmdir .claims/<id>)
   - Append handoff note for downstream agents
10. If blocked:
    - Update COORDINATION.md: status → blocked_on_human (or blocked)
    - Append handoff note explaining the blocker
    - Release lock
    - Go back to step 1
```

## OpenSpec integration

Each task corresponds to an OpenSpec change:

```
openspec/changes/
├── fix-auth/
│   ├── proposal.md          ← what + why
│   ├── tasks.md             ← implementation checklist
│   └── design.md            ← (optional) technical design
├── write-tests/
│   └── proposal.md
└── setup-ci/
    └── proposal.md
```

- `/opsx:propose fix-auth` creates the change spec
- The Pi agent reads the spec to know what to build
- `/opsx:apply` applies the change to the working tree
- `/opsx:archive fix-auth` archives the change after merge to trunk

The OpenSpec change name = the jj bookmark name = the COORDINATION.md task ID.
One name, three contexts — no mapping table needed.

## Visibility / monitoring

For the "at a glance: who's working, who's stopped, who needs input" view:

```bash
# Commit DAG (structural view)
jj log --graph -T 'bookmark ++ "\n" ++ description.first_line()'

# Coordination state (semantic view)
cat COORDINATION.md

# Quick status (scriptable)
grep 'status:' COORDINATION.md | sort | uniq -c
#   2 status: done
#   1 status: in_progress
#   1 status: ready
#   1 status: blocked_on_human

# Who needs your attention
grep -A3 'blocked_on_human' COORDINATION.md
```

A thin dashboard script could format COORDINATION.md into a colored table —
but for a dozen agents, `cat` is fine.

## .gitignore additions

```
.claims/
```

The `.claims/` directory is filesystem-level locking state, not version
control content. It's per-machine and ephemeral.

## What this design explicitly does NOT have

- **No TTL leases or heartbeat timers.** Stale cleanup is herdr's job.
- **No database.** COORDINATION.md is the single source of truth.
- **No inter-agent messaging protocol.** The handoff log is a markdown section.
- **No MCP server.** Agents just read/write files.
- **No claim retry/backoff.** mkdir fails instantly, agent picks the next task.
- **No priority queue.** Agents pick whichever ready task looks most relevant.
  Priority can be added as a field in COORDINATION.md if needed.

If any of these become necessary at scale, the plaintext schema is trivially
portable — wrap it in a tool later, nothing lost.

## Phased rollout

### Phase 1: Conventions and docs
- [ ] Finalize COORDINATION.md schema (this document)
- [ ] Add `.claims/` to .gitignore
- [ ] Write a Pi skill (`agent-coordination`) that teaches the claim loop
- [ ] Document jj workspace + bookmark conventions in AGENTS.md

### Phase 2: Helper scripts
- [ ] `scripts/task-claim.sh <task-id> <agent-name>` — mkdir + edit + commit
- [ ] `scripts/task-release.sh <task-id>` — rmdir + edit + commit
- [ ] `scripts/task-cleanup.sh` — scan for dead agents, release stale claims
- [ ] `scripts/task-status.sh` — pretty-print COORDINATION.md summary

### Phase 3: herdr integration
- [ ] herdr post-exit hook → calls `task-cleanup.sh`
- [ ] herdr pre-start hook → agent reads COORDINATION.md before first action
- [ ] Verify auto-rebase behavior when merging task bookmarks to trunk

### Phase 4: OpenSpec wiring
- [ ] Confirm OpenSpec change names align with bookmark names
- [ ] Test full cycle: `/opsx:propose` → claim → implement → merge → `/opsx:archive`
- [ ] Document the workflow in a mortlake skill

### Phase 5: Operational validation
- [ ] Run 2-3 Pi agents in parallel on independent tasks
- [ ] Test a dependency chain (A → B → C) — verify auto-rebase
- [ ] Test stale-agent cleanup (kill an agent, verify claim is released)
- [ ] Test diamond dependency (C depends on A + B)
