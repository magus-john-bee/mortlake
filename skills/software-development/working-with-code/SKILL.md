---
name: working-with-code
description: General programming workflow for nontrivial code and plaintext projects. Load this when doing any nontrivial work on a codebase or plaintext project (docs, static sites, .md-oriented tools).
version: 1.0.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [programming, workflow, code, plaintext, best-practices]
    related_skills: [systematic-debugging, test-driven-development, writing-plans, subagent-driven-development, github-pr-workflow]
---

# Working With Code

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. Then check them against external sources.
- If multiple interpretations exist, present them — don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask. If you can "ask" somewhere on the web or your tools, do so. If it's a question only the user can answer, do not be afraid to ask.

### Pitfall: Negative claims from narrow searches

Before asserting "X is not configured", "there's no module for Y", or "nothing references Z", search broadly with multiple query variations. A single narrow search returning zero results does not mean the thing doesn't exist — it may mean your pattern didn't match the file content, the config lives in an unexpectedly-named module, or the search tool handled the regex differently than expected.

**Correct approach:**
1. First search: narrow/precise pattern.
2. If zero results, broaden: drop qualifiers, use shorter terms, search for the general concept.
3. If still nothing, `grep -r` as a fallback — different regex engines match differently.
4. Only then make the negative claim, and state what you searched for so the user can verify.

Example: searching `security\.acme|acme\.acceptTerms` returned nothing, but a broader `grep -r "acme"` immediately found the config in `nginx.nix` — because ACME config rides along with the nginx module, not in a dedicated ACME file.

### Pitfall: "Change X to Y" — rename or new?

When the user says "change X to Y" or "call it Y", the instruction is ambiguous between renaming an existing thing and creating a new separate thing named Y. **Clarify before acting** — especially when the scope seems to cross module boundaries or the user mentions multiple files.

Wrong interpretation: rename the existing file/module/package from X to Y and update all consumers.
Right interpretation (sometimes): create a brand-new Y alongside the existing X, and only change the consumer(s) the user specified.

If the user names multiple files ("I want X to stay the same, and a new Y for host Z"), that's a clear signal for separate. But if they say "change the nix file to Y", ask: "Rename the existing file, or create a new one alongside it?" — the answer has radically different implementation paths.

### Pitfall: Verify tool output before declaring environmental failures

When a tool returns an unexpected or ambiguous result (e.g. `git push` says "Everything up-to-date", a command returns empty output, or a file isn't found), **check the actual state before fabricating an explanation**. Run `git status`, `hostname`, `ls`, or other verification commands. Past sessions incorrectly hallucinated container isolation, missing SSH keys, and permission errors when the real issue was simply uncommitted changes or a wrong directory. Report what's actually happening, not what you assume is happening.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it — don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

---

## Branching and PR Workflow

**NEVER push directly to main. All code changes go through PR.**

Rule: Every meaningful change → worktree branch → PR opened → reviewed by user → merged to main

### Pitfall: Stash conflict contaminating commits

When you `git stash` before pulling, then `git stash pop` causes a conflict, resolving the conflict auto-stages the file. If you commit without verifying the staging area, unrelated stash artifacts end up in the commit.

After stash pop + conflict resolution, always verify what's staged:
```bash
git diff --cached --stat
```

If unrelated files got staged, unstage before committing:
```bash
git reset HEAD <unrelated-file>
git checkout -- <unrelated-file>
```

If already committed with extra files, soft-reset and re-stage:
```bash
git reset HEAD~1
git add <only-intended-files>
git commit -m "..."
```
If a stash was dropped (e.g. `git checkout --theirs` + `git stash drop`) and you need to recover the lost local change, find it in unreachable objects:

```bash
git fsck --no-reflogs --unreachable 2>/dev/null | grep commit
# For each dangling commit, check if it touched your file:
git show <sha> -- path/to/file
```

### Pitfall: write_file resolves against repo root, not worktree

When working in a git worktree (`.worktrees/<name>/`), the `write_file` tool may resolve relative paths against the main repo root, not the worktree directory. Always use **absolute paths** that include the `.worktrees/<name>/` prefix:

```
# WRONG — may write to main repo
write_file(path="modules/features/foo.nix", ...)

# RIGHT — explicit worktree path
write_file(path="/home/john/project/.worktrees/my-task/modules/features/foo.nix", ...)
```

After writing, verify the file landed in the worktree: `ls .worktrees/<name>/path/to/file`.

### Pitfall: treefmt 2.x uses --fail-on-change, not --check
### Pitfall: treefmt 2.x uses --fail-on-change, not --check

treefmt 2.x removed `--check`. The CI-compatible flag is `--fail-on-change`:
```bash
nix fmt -- --fail-on-change    # treefmt 2.x ✓
nix fmt -- --check             # treefmt 2.x ✗ (unknown flag error)
```

### Pitfall: nix build for NixOS configurations needs full attribute path

`nix build .#nixosConfigurations.<host>` fails with "'type' is not a string but a set". You need the full attribute path to the build toplevel:
```bash
# WRONG — fails with attribute type error
nix build .#nixosConfigurations.thoth

# RIGHT
nix build .#nixosConfigurations.thoth.config.system.build.toplevel
```

- Create the PR as soon as the branch has a meaningful commit
- User reviews and merges; I don't merge my own PRs
- If it's not ready for review yet, still open a draft PR so progress is visible
- "Code changes" means anything that produces a diff: new files, edits, deletions

## Worktree Workflow

For all non-trivial tasks, use a dedicated worktree:

### Creating a Worktree

```bash
# Ensure worktrees directory exists
mkdir -p .worktrees

# Create named worktree with feature branch
git worktree add .worktrees/<task-name> -b worktree/<task-name>
```

### Working in a Worktree

- **Small, meaningful pieces** — if it can't be broken down further, that's a good sign
- **Verify before moving on** — unit tests + actually run what you wrote
- **PR when done** — all worktree work results in a pull request

### Completing a Worktree

1. Write the code and tests
2. Verify: tests pass, code runs
3. Push branch
4. Open PR
5. Return to main: `git checkout main`

---

## Skill Routing

Use specialized skills for their domains:

| Situation | Skill |
|-----------|-------|
| Bug / test failure / unexpected behavior | `systematic-debugging` |
| Writing new feature or fix | `test-driven-development` |
| Planning multi-step implementation | `writing-plans` |
| Delegating to subagents | `subagent-driven-development` |
| PR lifecycle, reviews, issues | `github-pr-workflow` |
| Complex codebase unfamiliar to you | `codebase-inspection` |

---

## Delegation to External Coding Agents

**For involved code edits, delegate to Codex CLI rather than editing directly.**

Think of the relationship as: **Hermes = supervisor, Codex = hotshot dev.**

Hermes handles the planning, coordination, and oversight. Codex handles the deep implementation work — multi-file refactors, complex feature additions, bug fixes across layers, and exploratory coding.

### When to Delegate

| Task Type | Who Does It |
|-----------|-------------|
| Simple 1-3 line fix in a known file | Hermes directly |
| Configuration tweak, doc update, typo | Hermes directly |
| Multi-file refactor, new feature, complex bug | **Codex** |
| Anything requiring iterative trial-and-error | **Codex** |

### How to Delegate

1. **Plan the work** — Hermes defines the goal, success criteria, and constraints
2. **Run Codex** — Use `codex exec "prompt"` or interactive mode via pty
3. **Review the output** — Hermes inspects the diff, runs tests, verifies against criteria
4. **Iterate if needed** — Send follow-up prompts or open a PR for user review

**Key principle:** Hermes stays in control of decisions and quality gates. Codex does the heavy lifting. Neither replaces the other — they complement.
**Key principle:** Hermes stays in control of decisions and quality gates. ForgeCode does the heavy lifting. Neither replaces the other — they complement.

---

**These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.

---
