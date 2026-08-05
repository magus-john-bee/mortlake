# Codex NixOS Deployment Architecture (corpus)

## Module Layout

Modules in `modules/features/`:

| Module | Purpose | Used On |
|--------|---------|---------|
| `codex-server.nix` | Full Codex install with app-server, sops env, MCP servers | thoth |
| `codex-client.nix` | Lightweight client that connects to thoth via SSH tunnel | puck, mab |
| `codex-zai-proxy.nix` | FastAPI proxy translating Responses API → Chat Completions for Z.AI | thoth (also puck, mab for standalone glm-5.2) |
| `codex-shared/config.toml` | Shared base config (providers, profiles, defaults) | all hosts |

The shared config was extracted to avoid duplicating provider/profile definitions between server and client. Host-specific overrides (sandbox mode, MCP servers) live in the user-level config layer (`~/.codex/config.toml` on thoth) which merges on top of the system layer.

## codex-server.nix

- Deploys `/etc/codex/config.toml` pointing at the shared config
- Creates shell alias `codex` that sources sops env file before exec:
  ```
  set -a; source ${envFile} 2>/dev/null; set +a; command codex
  ```
- **sops template `codex-env`**: renders API keys to `/run/secrets/rendered/codex-env`
  - `GLM_API_KEY=unused-proxy-handles-auth` (the proxy handles actual Z.AI auth)
  - `OPENROUTER_API_KEY`, `GROQ_API_KEY` from sops
- **systemd service `codex-app-server`**: runs `codex app-server --listen ws://127.0.0.1:4500` as user `john`
  - MCP servers: ouroboros (spawned as child processes)
  - `ProtectSystem = "strict"` with explicit `ReadWritePaths`
- **tmpfiles rules**: `/var/lib/codex`, `~/.codex`, and symlink `~/.codex/skills` → Hermes skills

## codex-client.nix

- Deploys client-specific config (default model: deepseek-v4-pro via openrouter, no Z.AI proxy)
- No app-server, no MCP servers
- Shell alias `thodex`:
  ```
  ssh -f -NL 4500:localhost:4500 thoth
  codex --remote ws://localhost:4500
  ```
  Opens SSH tunnel to thoth's app-server, then connects as a remote client.

## codex-zai-proxy.nix

- Runs `erubescent/codex-zai-proxy` as a systemd service
- Python FastAPI + uvicorn on `127.0.0.1:4891`
- Translates Codex's Responses API calls into Z.AI Chat Completions format
- Health check: `GET http://127.0.0.1:4891/health` → `{"status":"ok","upstream":"..."}`
- sops template `codex-zai-proxy-env` with `ZAI_API_KEY` (the real Z.AI key — the proxy handles auth, Codex itself gets a dummy key)

## Provider Routing

| Provider | Models | Backend | Notes |
|----------|--------|---------|-------|
| `zai-proxy` | `glm-5.2` (default) | Z.AI via localhost:4891 | Proxy translates Responses → Chat Completions |
| `openrouter` | `deepseek/deepseek-v4-pro`, `deepseek/deepseek-v4-flash`, `moonshotai/kimi-k2.7-code` | OpenRouter | Native Responses API support, no proxy needed |
| `groq` | `openai/gpt-oss-20b` | Groq | Native Responses API support |

**DeepSeek models route through OpenRouter** (e.g. `deepseek/deepseek-v4-pro`) because DeepSeek's direct API only speaks Chat Completions and Codex 0.135+ dropped `wire_api = "chat"`. Do NOT create a direct `deepseek` provider — it will 404 on `/responses`.

## Model Override in exec Mode

The `-p`/`--profile` flag looks for `$CODEX_HOME/<name>.config.toml` files, NOT the `[profiles.*]` sections in config.toml (those are TUI-only). To use a different model/provider in exec mode, use `-c` overrides:

```bash
# Switch to DeepSeek V4 Pro via OpenRouter
codex exec -c 'model="deepseek/deepseek-v4-pro"' -c 'model_provider="openrouter"' "prompt"

# Switch to Groq fast model
codex exec -c 'model="openai/gpt-oss-20b"' -c 'model_provider="groq"' "prompt"
```

Both `model` AND `model_provider` must be overridden together.

## Hermes Invoking Codex

Hermes doesn't use john's shell alias, so API keys aren't in the environment. Must source them explicitly:

```bash
export $(grep -v '^#' /run/secrets/rendered/codex-env | xargs) && codex exec "prompt"
```

Run from a git repo with `pty=true`. For non-repo directories, add `-c skip_git_repo_check=true`.

## Known Issues

- `codex exec` reads stdin and prints "Reading additional input from stdin..." — harmless but noisy.
- The proxy forwards whatever model name it receives to Z.AI. If you use `-m deepseek-v4-pro` without also changing `model_provider` away from `zai-proxy`, the proxy sends `deepseek-v4-pro` to Z.AI which rejects it as "Unknown Model". Always change both model AND provider together.
- `.opencode/skills/linting/SKILL.md` in corpus triggers a non-fatal error on every Codex run: "missing YAML frontmatter delimited by ---". Harmless but noisy in logs.
