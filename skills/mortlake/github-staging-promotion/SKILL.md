---
name: github-staging-promotion
description: Mortlake's two-repo GitHub topology — private staging (uriel-mortlake/mortlake, agent free rein) promotes via promote/<slug> PRs to canonical (magus-john-bee/mortlake, protected main). Covers which account/credential to use for each operation on jehoel, the GH_TOKEN trick for staging PRs, and the private/main overlay. Use when pushing, opening PRs, or promoting anything in the mortlake repo, or when gh fails to resolve the mortlake repo.
---

# GitHub Staging + Promotion (mortlake)

Two repos, two identities, one pipeline. Sources of truth: `README.md`
(Development workflow section) and `modules/features/gh.nix`.

## Topology

| | Staging | Canonical |
|---|---|---|
| Repo | `uriel-mortlake/mortlake` (private) | `magus-john-bee/mortlake` (public) |
| Remote name | `origin` | `public` |
| URL hint | `https://uriel-mortlake@github.com/...` | `https://magus-john-bee@github.com/...` |
| main | **agent free rein** — direct push OK | **protected** — PR + 1 approval |
| Role | all work lands here | publication of record |

Other hosts (raphael, phones) use a read-only `jbotwell` identity —
never push from them.

Two checkouts, two roles:

- **jehoel** `/home/john/src/mortlake` — work checkout (HTTPS + PAT
  routing). Branches, PRs, evals happen here.
- **uriel** `/home/john/src/mortlake` — promotion checkout. Both remotes
  use the SSH alias `github-uriel` (→ Hermes's deploy key
  `/var/lib/hermes/.ssh/id_ed25519_gh_uriel`). The adjacent
  `/home/john/src/mortlake-private` is a git worktree of `private/main`.
  No cron/timer — promotion runs on demand (you, or Hermes when asked).

## Credential plumbing (jehoel only)

- `/etc/gh/hosts.yml` (sops-rendered from `supersecrets.yaml`) holds BOTH
  PATs; **active account is `magus-john-bee`** (the human at the terminal).
- Git push/pull works for both repos regardless of active account:
  remote URLs embed the username, and `gh-cred-router` (git credential
  helper, defined in `gh.nix`) resolves non-active usernames via
  `gh auth token --user <name>`.
- **`gh` CLI commands are the trap**: the active account cannot even
  *resolve* the private staging repo (GraphQL: "Could not resolve to a
  Repository"). Never `gh auth switch` — route per-command instead:

```bash
# PRs / API calls against STAGING (origin):
GH_TOKEN=$(gh auth token --user uriel-mortlake) \
  gh pr create -R uriel-mortlake/mortlake --base main --head <branch> ...

# PRs / API calls against CANONICAL (public) — plain gh, active account:
gh pr create -R magus-john-bee/mortlake ...
```

## Promotion pipeline

Runs from **uriel's checkout** (SSH remotes, Hermes's key):

```bash
# on uriel, /home/john/src/mortlake
git push origin main                              # staging (free rein)
git push public main:refs/heads/promote/<slug>    # promotion branch
# → open PR promote/<slug> → main on magus-john-bee/mortlake (plain gh,
#   from jehoel — canonical is visible to the active account)
# → human reviews (1 approval required), merge
```

After merge, canonical main flows back into staging main via regular
merge commits ("Merge pull request #N from magus-john-bee/promote/...").
A promote branch is a snapshot of staging main at push time — its PR diff
against canonical main is cumulative, so promote promptly after landing.

## Gotchas

1. **jehoel's clone has no `public` remote** — the NixOS activation
   script (`ghRemoteHints` in `gh.nix`) only fixes URLs of remotes that
   already exist, and promotion is done from uriel anyway. If you must
   promote from jehoel:
   `git remote add public https://magus-john-bee@github.com/magus-john-bee/mortlake.git`
2. **`private/main` overlay** — staging-only branch holding private
   planning files, checked out as the worktree
   `/home/john/src/mortlake-private` on uriel. A pre-push hook enforces
   its content never reaches the public repo. Never merge `private/main`
   into work destined for promotion.
3. **Don't confuse the repos** — `gh repo list` under the active account
   shows a `magus-john-bee/mortlake` with different branch names
   (`promote/*`); that's canonical, not a fork. Staging is invisible to it.
4. **Squash/rebase at promotion is normal** — promote branch SHAs may not
   match staging SHAs (promotion rewrites or snapshots). Verify by title
   and content, not hash, when tracing a change.
