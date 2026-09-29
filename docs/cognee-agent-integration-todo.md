# Cognee Agent Integration — DONE (09-29)

Status: COMPLETE on staging main (f21abff). Server live since 4a11fa8;
agents wired 09-29: hermes plugin (remote mode), cognee-mcp proxy,
pi-cognee extension. Everything below was verified LIVE on uriel before
the nix was written. Remaining for the operator: deploy (jehoel
remote-build), then run the test matrix in §4.

## 0. Context (what exists)

- Server: `modules/features/cognee.nix` — cognee.service 127.0.0.1:8010
  behind nginx+ACME at https://cognee.otwell.dev. X-Api-Key auth; key in
  sops `cognee-api-key` → /run/secrets/cognee-api-key on every host.
  $COGNEE_URL set by pi.nix on all hosts.
- Admin user: john@otwell.dev / sops `cognee-admin-password` (login
  POST /api/v1/auth/login, form-encoded, mints JWT; API keys via
  POST /api/v1/auth/api-keys — hyphen!).
- Upstream docs (read these first):
  - Hermes plugin: https://docs.cognee.ai/integrations/hermes-agent-integration
  - Pi extension: https://docs.cognee.ai/integrations/pi-integration
  - MCP server: https://docs.cognee.ai/cognee-mcp/mcp-overview

## 1. Hermes (easiest — no new services)

Official plugin `cognee-integration-hermes-agent` in REMOTE mode (thin
HTTP client — exactly our shape):

- Install WITHOUT pip-into-nix: vendored-copy path from the docs —
  `cognee-hermes-install` copies to $HERMES_HOME/plugins/cognee. For
  nix: fetch the plugin dir (pypi wheel or cognee-integrations repo,
  integrations/hermes-agent) into the repo or fetchTarball, place via
  hermes.nix into /var/lib/hermes/.hermes/plugins/cognee (Hermes home on
  uriel; check hermes.nix for homeDir). Plugin pins cognee==1.6.0 vs our
  1.6.1 server — wire contract, expected fine, verify.
- Config (env or cognee.json): COGNEE_BASE_URL=https://cognee.otwell.dev,
  COGNEE_API_KEY from sops, COGNEE_PLUGIN_DATASET=agent_memory (share
  the one brain), COGNEE_IMPROVE_ON_END=true.
- Then: `hermes memory setup` → pick cognee. Hermes runs as a systemd
  service on uriel (hermes.nix) — restart it, then test in a live
  session: "remember that X", new session, "what is X".
- NOTE for whoever runs setup: the plugin's update check phones PyPI;
  harmless. The hermes-agent skill (references/) has plugin mechanics.

## 2. cognee-mcp proxy on uriel (prereq for pi)

pi-cognee extension speaks MCP; cognee's MCP server in API mode is the
translator. Docs: cognee-mcp README "API Mode".

- New systemd service in cognee.nix (or cognee-mcp.nix): image
  `cognee/cognee-mcp:main` via podman (NOT a venv — 2GB dep tree, API
  mode never runs it; container is the sane packaging here; podman
  module already exists but is NOT imported on uriel — add import), OR
  uv venv pinned cognee-mcp if container fights tmpfs/preservation.
  Run: `--api-url http://127.0.0.1:8010 --api-token <cognee-api-key>`,
  HTTP transport, bind 127.0.0.1:8011.
- nginx: location /mcp on cognee.otwell.dev → 8011. MUST pass Host
  header through (MCP validates Host/Origin vs DNS-rebinding; 421/403
  otherwise) and needs its own auth (the api-token authenticates cognee
  but the /mcp endpoint itself must not be open — consider a second
  bearer token or IP allowlist + the token).
- Verify: MCP handshake via curl (initialize) before touching pi.

## 3. pi + prime-agent (all hosts)

Community ext `npm:@kerryhatcher/pi-cognee`, MCP mode:

- pi.nix: pre-seed extension + config. Extensions install to
  ~/.pi/agent/npm/ — pi.nix comment says "npm at runtime"; likely an
  activation script or `pi install npm:@kerryhatcher/pi-cognee` once
  per host (find the declarative path; maybe persist .pi/agent/npm via
  preservation — .pi already preserved).
- Config per host: mode=mcp, mcpUrl=https://cognee.otwell.dev/mcp.
  Config lives in the extension's store (~/.pi/agent/...; check
  /cognee-config write path — maybe settings.json merge-update like
  pi-model-defaults activation script in pi.nix).
- prime-agent: pi-based, same .pi tree + its own .prime. VERIFY it picks
  up the extension (may need same seeding under ~/.prime if it doesn't
  share). Unverified — do this live, not by assumption.

## 4. Wrap-up

- DONE 09-29: skills/mortlake/cognee/SKILL.md client section updated
  from live integrations; docs/agent-architecture.md clients line now
  names plugin + extension + proxy (CLI line removed).
- PR: promote branch `promote/cognee-agent-integration` — carved as ONE
  concern (all 9 staging commits are this feature) off public/main,
  squashed to a single commit. NOT a staging snapshot (host configs
  shared across concerns bit us twice; here the only host-config deltas
  ARE this concern's imports).
- Test matrix (post-deploy, live):
  1. hermes: `hermes memory status` shows cognee; session "remember
     that X" → new session "what is X".
  2. pi recall in a repo dir (jehoel): "check your cognee memory".
  3. cross-host: jehoel pi recalls a uriel-written memory.
  4. dataset=agent_memory shared across hermes; pi writes to
     pi_cognee_memory (proxy agent-scoping — expected, recall is
     cross-dataset).
  5. /mcp without token → 401; with ?token= → initialize OK.
  6. prime-agent: `pi list` inside prime shows the extension; if not,
     `pi install npm:@kerryhatcher/pi-cognee` inside prime once.

## Gotchas already paid for (don't relearn)

All in skills/mortlake/cognee/SKILL.md §ops: litellm provider-qualified
model, EMBEDDING_* must both be pinned, LD_LIBRARY_PATH in service env,
~/.lbdb tmpfiles, sops template restartUnits. Plus: deploy-rs flake
check is the real eval gate (--no-build alone passed a broken tree
once); jehoel checkout must be git fetch+reset --hard origin/main
before EVERY deploy (piped pull masked failures twice).
