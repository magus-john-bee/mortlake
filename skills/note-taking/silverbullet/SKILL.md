---
name: silverbullet
description: Use when reading/writing the SilverBullet space at sb.otwell.dev — HTTP API via bearer token, or direct file edits on uriel.
version: 1.0.0
author: Hermes Agent
license: MIT
tags: [silverbullet, pkm, notes, api, mortlake]
metadata:
  hermes:
    tags: [silverbullet, pkm, notes, api, mortlake]
---

# SilverBullet space (sb.otwell.dev)

## When to Use
- Reading, writing, or reorganizing pages in the SB space from ANY host (HTTP API)
- Direct text edits on uriel (the primary host — first-class, see below)
- Seeding/migrating content from the logbook vault
- SB configuration questions (SB_* env vars, CONFIG page, plugs)

## Topology
- Server: `silverbullet.service` on uriel, bound to 127.0.0.1:3000, behind
  nginx + ACME at `https://sb.otwell.dev` (module: `modules/features/silverbullet.nix`).
- Space: `/home/john/vault/sb` on uriel — plain markdown inside the vault bind
  mount (tmpfs-persisted, restic-backed). Also a standalone git repo
  (`.silverbullet.db*`, `_plug/`, `.chrome-data/` gitignored); mirror push to
  the magus GitHub account is MANUAL, fallback-only.
- Auth: browser login = `SB_USER` (john). Agents = `SB_AUTH_TOKEN` bearer.
- John edits space files directly on uriel (no browser mediation needed) —
  treat direct edits as normal, not a workaround.

## Agent access from any host (HTTP API)

Token extraction — works on any mortlake host (secrets.yaml is encrypted for
uriel, jehoel, and raphael host keys). SOPS_AGE_KEY_CMD is a sessionVariable
on mortlake hosts; in agent contexts export it explicitly:

```bash
TOKEN=$(cd ~/src/mortlake && \
  SOPS_AGE_KEY_CMD="sudo ssh-to-age -private-key -i /etc/ssh/ssh_host_ed25519_key" \
  sops -d --extract '["silverbullet-auth-token"]' modules/features/secrets.yaml)
```

(The repo checkout path may differ per host; adjust. On non-mortlake hosts
there is no sops access — run via a mortlake host instead.)

Health check first (no auth required): `curl -s https://sb.otwell.dev/.ping`
— if this answers taskdog JSON instead, uriel hasn't been rebuilt with the
silverbullet module yet.

### Endpoints (auth-excluded: `/.ping`, `/.client/*`, `/.auth`, `/service_worker.js`)

| Call | Purpose |
|---|---|
| `GET /.fs/<path>` | read a file's raw content (e.g. `/.fs/index.md`). Response headers: `X-Last-Modified` (ms epoch), `X-Permission` (rw/ro), `X-Content-Length` |
| `PUT /.fs/<path>` | write body to a file (creates/overwrites; markdown or binary) |
| `DELETE /.fs/<path>` | delete a file |
| `GET /.fs/` | full file listing, JSON array (name, created, lastModified, contentType, contentLength, perm). Library/Std/* entries are SB's built-in virtual pages — not on disk |
| `GET /.config` | client config JSON (readOnly, indexPage, …) |

```bash
# read
curl -s -H "Authorization: Bearer $TOKEN" https://sb.otwell.dev/.fs/index.md
# write (creates parents as needed)
curl -s -X PUT -H "Authorization: Bearer $TOKEN" --data-binary @page.md \
  https://sb.otwell.dev/.fs/pages/meeting-notes.md
# delete
curl -s -X DELETE -H "Authorization: Bearer $TOKEN" https://sb.otwell.dev/.fs/pages/old.md
# list everything
curl -s -H "Authorization: Bearer $TOKEN" https://sb.otwell.dev/.fs/
```

Do NOT send the `X-Sync-Mode: true` header — that marks requests as coming
from the official client and changes redirect behavior.

## Direct editing on uriel

- Edit files under `/home/john/vault/sb` with anything (vim, scripts, hermes
  file tools). SB indexes external changes; browser clients pick them up on
  their next sync cycle (reload if a page looks stale).
- Never touch `.silverbullet.db*` (index db), `_plug/` (plug cache),
  `.chrome-data/`.
- Git commits in the space are cheap and encouraged; pushing the mirror is a
  manual fallback action, restic is the primary backup.

## Layout conventions
- `index.md` = index page; `CONFIG.md` = runtime config (space-lua blocks,
  e.g. `config.set("sync.documents", true)`); `Library/` = templates/library
  (keep it committed).
- URL paths == space paths: page `pages/foo` is the file `pages/foo.md`.

## Pitfalls
| Problem | Cause / fix |
|---|---|
| 401 on API calls | token not rendered yet (service predates `silverbullet-auth-token` in sops — rebuild uriel) or wrong extraction path |
| Taskdog JSON at sb.otwell.dev | uriel running pre-silverbullet generation; nginx default vhost answered. Rebuild from mortlake main |
| Lost update | SB is last-write-wins per file. For critical pages: GET (note `X-Last-Modified`), edit, PUT — no merge exists |
| `GET /.fs/x` 404 but page exists in UI | path needs the real extension (`/.fs/index.md` not `/.fs/index`) |
| Token on a non-mortlake host | sops file isn't decryptable there — delegate to a mortlake host |
