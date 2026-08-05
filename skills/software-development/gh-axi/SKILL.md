---
name: gh-axi
description: >
  Token-efficient GitHub CLI wrapper for agents. Use alongside raw `gh` for GitHub
  operations where compact, structured output matters more than human-readable formatting.
  gh-axi wraps `gh` with agent-friendly output (TOON format), contextual next-step
  suggestions, and concise responses. Prefer gh-axi for listing, viewing, and searching
  issues/PRs/runs in agent workflows. Fall back to raw `gh` for complex or obscure
  operations not covered by gh-axi's command surface.

---

# gh-axi — GitHub CLI for Agents

Agent-oriented wrapper around `gh`. Same commands, but output is token-efficient
with built-in next-step hints. Runs via npx — no install needed.

## When to use gh-axi vs raw gh

**Use gh-axi** for: listing/viewing issues, PRs, runs; searching; dashboards;
any read-heavy GitHub query where you want compact output.

**Use raw `gh`** for: anything gh-axi doesn't cover; complex jq filters;
API calls with custom endpoints; detailed human-readable output.

## Usage

All commands go through `npx gh-axi`:

```bash
npx gh-axi                              # dashboard — repo state at a glance
npx gh-axi issue list --state open       # open issues
npx gh-axi pr view 42                    # view PR #42
npx gh-axi run list --status failure     # failed workflow runs
npx gh-axi search issues "bug" -R owner/repo
```

## Commands

### Issues

```bash
npx gh-axi issue list --state open --label bug --limit 10
npx gh-axi issue view 42 --comments
npx gh-axi issue create --title "Fix login" --body "Steps..."
npx gh-axi issue edit 42 --add-label "priority"
npx gh-axi issue close 42 --reason completed
npx gh-axi issue comment 42 --body "Fixed in #43"
npx gh-axi issue transfer 42 -R source/repo --to-repo dest/repo
npx gh-axi issue subissue add 16 20 101
```

### Pull Requests

```bash
npx gh-axi pr list --state open --author myself
npx gh-axi pr view 42 --comments --reviews
npx gh-axi pr view 42 --full            # untruncated body
npx gh-axi pr create --title "feat: ..." --body "..." --draft
npx gh-axi pr merge 42 --squash --delete-branch
npx gh-axi pr review 42 --approve --body "LGTM"
npx gh-axi pr checks 42                 # CI status
npx gh-axi pr diff 42                   # token-efficient diff
npx gh-axi pr diff 42 --full            # untruncated diff
npx gh-axi pr checkout 42
npx gh-axi pr update-branch 42
```

### Workflow Runs

```bash
npx gh-axi run list --workflow ci.yml --status failure
npx gh-axi run view 123456
npx gh-axi run view 123456 --log-failed  # logs for failed jobs only
npx gh-axi run view 123456 --job <job-id> --log
npx gh-axi run rerun 123456
npx gh-axi run rerun 123456 --failed    # rerun only failed jobs
npx gh-axi run cancel 123456
npx gh-axi run download 123456 --name artifacts --dir ./out
```

### Search

```bash
npx gh-axi search issues "login bug" --repo owner/repo --state open
npx gh-axi search prs "feat" --author alice --sort updated
npx gh-axi search repos "cli tool" --language Go --stars ">50"
npx gh-axi search commits "fix" --repo owner/repo
npx gh-axi search code "TODO" --repo owner/repo
```

### Repos

```bash
npx gh-axi repo view                     # current repo
npx gh-axi repo create my-project --private
npx gh-axi repo fork owner/repo --clone
npx gh-axi repo list --visibility public --language TypeScript
```

### Other

```bash
npx gh-axi workflow list                 # list workflows
npx gh-axi release list                  # list releases
npx gh-axi label list                    # list labels
npx gh-axi api /repos/owner/repo/stats   # raw API access
```

## Global flags

- `-R owner/name` or `--repo owner/name` — target a specific repo
- `--help` — help for any command
- `-v` / `-V` / `--version` — show version

## Pitfalls

- **Requires `gh` authenticated** — gh-axi wraps `gh`, so `gh auth login` must
  have been run. If gh-axi fails with auth errors, fix `gh` first.
- **No `--json` flag** — output is always TOON format (plain text, structured).
  If you need machine-parseable JSON, use raw `gh --json` instead.
- **Diff truncation** — `pr diff` truncates by default. Use `--full` for the
  complete diff.
- **SessionStart hooks** — gh-axi can install hooks for Claude Code / Codex.
  Ignore this — Hermes doesn't use them.
- **Not a full replacement** — gh-axi covers common operations well but doesn't
  expose every `gh` subcommand or flag. Fall back to `gh` for anything not
  listed in `npx gh-axi <command> --help`.
