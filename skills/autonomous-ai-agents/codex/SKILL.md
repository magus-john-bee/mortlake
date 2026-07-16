---
name: codex
description: "Delegate coding to OpenAI Codex CLI (features, PRs)."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [Coding-Agent, Codex, OpenAI, Code-Review, Refactoring]
    related_skills: [claude-code, hermes-agent]
---

# Codex CLI

Delegate coding tasks to [Codex](https://github.com/openai/codex) via the Hermes terminal. Codex is OpenAI's autonomous coding agent CLI.

## When to use

- Building features
- Refactoring
- PR reviews
- Batch issue fixing

Requires the codex CLI and a git repository.

## Prerequisites

- Codex installed (`npm install -g @openai/codex`, or via NixOS module)
- Auth configured: `OPENAI_API_KEY`, custom provider env key, or Codex OAuth
- **Must run inside a git repository** — Codex refuses to run outside one (override with `-c skip_git_repo_check=true`)
- Use `pty=true` in terminal calls — Codex is an interactive terminal app

For Hermes itself, `model.provider: openai-codex` uses Hermes-managed Codex
OAuth from `~/.hermes/auth.json` after `hermes auth add openai-codex`. For the
standalone Codex CLI, a valid CLI OAuth session may live under
`~/.codex/auth.json`; do not treat a missing `OPENAI_API_KEY` alone as proof
that Codex auth is missing.

### NixOS Deployment (thoth)

On NixOS, Codex is installed declaratively via the corpus NixOS config. Key details:

- **Config precedence:** `/etc/codex/config.toml` (set via `environment.etc`) overrides `$CODEX_HOME/config.toml`
- **API keys:** Stored in sops, rendered to `/run/secrets/rendered/codex-env`. The shell alias `codex` auto-sources this file before exec. When calling from Hermes (which doesn't use the alias), source it manually:
  ```
  export $(grep -v '^#' /run/secrets/rendered/codex-env | xargs) && codex exec "prompt"
  ```
- **Z.AI proxy:** On thoth, `glm-5.2` works through `codex-zai-proxy` (a FastAPI service on port 4891 that translates Responses API → Chat Completions for Z.AI's endpoint). The `zai-proxy` provider in config.toml points at `http://127.0.0.1:4891/v1`.
- **App-server:** `codex-app-server` systemd service listens on `ws://127.0.0.1:4500` for remote client access (puck/mab connect via SSH tunnel).
- **Skills symlink:** `~/.codex/skills` → `/var/lib/hermes/.hermes/skills` (shared with Hermes)
- **Providers available:** zai-proxy (default, glm-5.2), openrouter, groq. DeepSeek models route through OpenRouter (not direct — DeepSeek API lacks Responses API support). Switch with `-c` overrides (e.g. `-c 'model="deepseek/deepseek-v4-pro"' -c 'model_provider="openrouter"'`).

See `references/nixos-deployment.md` for the full module architecture.

## One-Shot Tasks

```
terminal(command="codex exec 'Add dark mode toggle to settings'", workdir="~/project", pty=true)
```

For scratch work (Codex needs a git repo):
```
terminal(command="cd $(mktemp -d) && git init && codex exec 'Build a snake game in Python'", pty=true)
```

## Background Mode (Long Tasks)

```
# Start in background with PTY
terminal(command="codex exec 'Refactor the auth module'", workdir="~/project", background=true, pty=true)
# Returns session_id

# Monitor progress
process(action="poll", session_id="<id>")
process(action="log", session_id="<id>")

# Send input if Codex asks a question
process(action="submit", session_id="<id>", data="yes")

# Kill if needed
process(action="kill", session_id="<id>")
```

## Key Flags (v0.135.0+)

| Flag | Effect |
|------|--------|
| `exec "prompt"` | One-shot non-interactive execution, exits when done |
| `-a never` / `--ask-for-approval never` | Never prompt for approval — run all commands automatically |
| `-s read-only` | Sandbox: only read filesystem |
| `-s workspace-write` | Sandbox: read + write inside project dir |
| `-s danger-full-access` | No sandbox restrictions |
| `--dangerously-bypass-approvals-and-sandbox` | Skip all approvals AND sandbox — equivalent to old `--yolo` |
| `-m <model>` | Override model for this run |
| `-p <profile>` | Layer a named config file (`$CODEX_HOME/<name>.config.toml`) on top of base config |
| `-c key=value` | Override a config.toml value (e.g. `-c skip_git_repo_check=true`) |
| `review` | Non-interactive code review subcommand |

**Note:** `--full-auto` and `--yolo` do not exist in v0.135.0+. The equivalent is the combination of approval policy + sandbox mode set in config.toml or via flags. If `approval_policy = "never"` and `sandbox_mode = "danger-full-access"` are already in config.toml, no extra flags are needed.

### Profile Pitfall: `-p` ≠ `[profiles.*]`

The `-p`/`--profile` flag does **NOT** use the `[profiles.<name>]` sections in config.toml. Those sections are for the interactive TUI profile picker only. The `-p` flag instead looks for a file at `$CODEX_HOME/<name>.config.toml` and layers it on top of the base config.

To override model and provider in `exec` mode, use `-c` overrides:
```bash
codex exec -c 'model="deepseek/deepseek-v4-pro"' -c 'model_provider="openrouter"' "prompt"
```
Both `model` and `model_provider` must be overridden together — changing only the model while leaving a different provider will send the wrong model name to the wrong API endpoint.

### wire_api = "chat" Removed

Codex 0.135+ **removed `wire_api = "chat"`** — only `wire_api = "responses"` is supported. Providers that only speak Chat Completions (DeepSeek direct, Z.AI direct) cannot be used without a translation proxy. Options:

1. **Use a proxy** (like `codex-zai-proxy` on thoth) that translates Responses API → Chat Completions
2. **Route through a Responses-capable provider** — e.g., use OpenRouter to access DeepSeek models (`deepseek/deepseek-v4-pro`) since OpenRouter speaks the Responses API natively
3. **Do NOT set `wire_api = "chat"`** — Codex will error with: `"wire_api = \"chat\" is no longer supported"`

## PR Reviews

Clone to a temp directory for safe review:

```
terminal(command="REVIEW=$(mktemp -d) && git clone https://github.com/user/repo.git $REVIEW && cd $REVIEW && gh pr checkout 42 && codex review --base origin/main", pty=true)
```

## Parallel Issue Fixing with Worktrees

```
# Create worktrees
terminal(command="git worktree add -b fix/issue-78 /tmp/issue-78 main", workdir="~/project")
terminal(command="git worktree add -b fix/issue-99 /tmp/issue-99 main", workdir="~/project")

# Launch Codex in each
terminal(command="codex exec 'Fix issue #78: <description>. Commit when done.'", workdir="/tmp/issue-78", background=true, pty=true)
terminal(command="codex exec 'Fix issue #99: <description>. Commit when done.'", workdir="/tmp/issue-99", background=true, pty=true)

# Monitor
process(action="list")

# After completion, push and create PRs
terminal(command="cd /tmp/issue-78 && git push -u origin fix/issue-78")
terminal(command="gh pr create --repo user/repo --head fix/issue-78 --title 'fix: ...' --body '...'")

# Cleanup
terminal(command="git worktree remove /tmp/issue-78", workdir="~/project")
```

## Batch PR Reviews

```
# Fetch all PR refs
terminal(command="git fetch origin '+refs/pull/*/head:refs/remotes/origin/pr/*'", workdir="~/project")

# Review multiple PRs in parallel
terminal(command="codex exec 'Review PR #86. git diff origin/main...origin/pr/86'", workdir="~/project", background=true, pty=true)
terminal(command="codex exec 'Review PR #87. git diff origin/main...origin/pr/87'", workdir="~/project", background=true, pty=true)

# Post results
terminal(command="gh pr comment 86 --body '<review>'", workdir="~/project")
```

## App-Server (Remote Access)

Codex can run as a persistent app-server that remote clients connect to:

```bash
codex app-server --listen ws://0.0.0.0:4500 --ws-auth capability-token --ws-token-file /path/to/token
```

Clients connect via `codex --remote ws://host:4500`. Supports websocket (`ws://`), secure websocket (`wss://`), unix socket (`unix://`), and stdio. The websocket transport is still marked experimental/unsupported in the README.

**Voice transcription does NOT traverse the app-server connection.** Voice mode captures local microphone audio via the TUI — it's a client-side-only feature. The JSON-RPC protocol has no audio streaming channel. See "Current Limitations" below.

## Current Limitations (as of June 2026)

### Voice Transcription — Removed

Voice transcription (hold-spacebar-to-talk, PR #3381) was **removed entirely** in March 2026 (PR #16114). The feature used OpenAI's Realtime API with `gpt-4o-mini-transcribe` for STT, hardcoded — no custom STT/TTS provider support was ever added. It was disabled on Linux from the start (ALSA build complexity with `cpal`), then ripped out as "partially-completed."

If voice input is needed, use external MCP tools like `speech-mcp-echo` (configurable STT: Groq Whisper, faster-whisper, Google Speech) that pipe text into Codex as an MCP server.

### No Custom STT/TTS Providers

The transcription pipeline was always hardcoded to OpenAI's Realtime API. The `[model_providers.*]` config section only applies to the conversation model, not the STT/TTS layer. Even before removal, there was no way to point transcription at a different provider.

### Remote Voice Not Supported

`codex --remote` (app-server websocket) is a JSON-RPC text channel. No audio is streamed between client and server. Voice input must happen on the machine physically connected to the microphone.

## Config Architecture

Codex reads config from multiple layers (highest precedence first):
1. `-c` CLI overrides (immediate, per-invocation)
2. `/etc/codex/config.toml` — system-level, set via NixOS `environment.etc`
3. `$CODEX_HOME/config.toml` — user-level (default `~/.codex/config.toml`)
4. `.codex/config.toml` — project-level (cannot override provider/auth keys)

The config supports:
- `model` / `model_provider` — default model and provider selection
- `[model_providers.<id>]` — custom provider definitions (base_url, env_key, wire_api, etc.)
- `[profiles.<name>]` — named config profiles for quick switching
- `[mcp_servers.<name>]` — MCP server definitions
- `[features]` — feature flags (e.g., `voice_transcription`, `realtime_conversation`, `memories`)
- `[projects."/path"]` — per-directory trust levels and settings
- `[shell_environment_policy]` — which env vars to pass to shell commands (`inherit = "core"` is minimal)

When wrapping Codex via NixOS (see corpus), the system config is deployed via `environment.etc."codex/config.toml"` — NOT baked into the wrapper binary. `$CODEX_HOME` remains writable for runtime data (auth.json, logs, sqlite). For server/client tier splits, each host gets its own config.toml and set of providers (see `codex-server.nix` vs `codex-client.nix` in corpus).

## Rules

1. **Always use `pty=true`** — Codex is an interactive terminal app and hangs without a PTY
2. **Git repo required** — Codex won't run outside a git directory. Use `mktemp -d && git init` for scratch, or `-c skip_git_repo_check=true`
3. **Use `exec` for one-shots** — `codex exec "prompt"` runs and exits cleanly
4. **Approval/sandbox in config.toml** — Set `approval_policy = "never"` and `sandbox_mode = "danger-full-access"` there rather than passing flags every time
5. **Background for long tasks** — use `background=true` and monitor with `process` tool
6. **Don't interfere** — monitor with `poll`/`log`, be patient with long-running tasks
7. **Parallel is fine** — run multiple Codex processes at once for batch work
8. **Source the env file** — On NixOS with sops, Hermes must source `/run/secrets/rendered/codex-env` before calling `codex` (the shell alias does this for interactive use, but Hermes's terminal doesn't use the alias)
