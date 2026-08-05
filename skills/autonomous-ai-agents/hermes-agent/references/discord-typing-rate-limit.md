# Discord Typing Indicator Rate-Limit Bug

**Hermes version:** v0.13.0 (2026.5.7)
**Date investigated:** 2026-05-09
**Status:** No config workaround. Upstream bug report needed.

## Symptoms

Continuous 429s on the Discord typing endpoint:
```
WARNING discord.http: We are being rate limited. POST https://discord.com/api/v10/channels/<id>/typing responded with 429. Retrying in 3.00 seconds.
```

Observed: 68 rate-limit hits in 1 hour across 2 channels, in bursts of 5-6 requests every 3 seconds.

**Secondary effect:** The 429 storm can be misinterpreted by Hermes as a provider rate-limit, triggering erroneous fallback to `fallback_model` or smart-routing to `cheap_model`. Users see sudden quality drops with no actual provider issue. Always check for typing 429s when investigating unexpected model switches on Discord.

## Architecture (Source Code Analysis)

### Base class typing loop (`gateway/platforms/base.py`)

- `_keep_typing()` runs continuously at 2-second intervals
- Each tick calls `self.send_typing(chat_id)` with a 1.5s timeout
- Started at line ~2794 via `asyncio.create_task(self._keep_typing(...))`
- Has a `_typing_paused` set to skip during approval waits
- No rate-limit awareness — swallows all exceptions as non-fatal debug logs

### Discord adapter typing loop (`gateway/platforms/discord.py`)

- Overrides `send_typing()` to start its OWN background `_typing_loop` (8-second cadence)
- Dedup guard: `if chat_id in self._typing_tasks: return` — only one loop per channel
- The loop directly calls `POST /channels/{channel_id}/typing` via discord.py HTTP
- On any exception (including rate-limit), the loop **returns** (dies), but the base class keeps calling `send_typing()` which restarts it

### The cascade mechanism

1. Base `_keep_typing` calls Discord's `send_typing()` every 2s
2. First call starts the 8-second Discord `_typing_loop`
3. Subsequent calls hit the dedup guard and return immediately (no extra HTTP)
4. But: discord.py's HTTP client has its own 429 retry logic (3s backoff)
5. When the Discord loop's HTTP POST gets 429'd, discord.py retries after 3s
6. Meanwhile the loop keeps ticking, and the base keeps calling send_typing()
7. The 3s retry backoff stacks with the 2s/8s loop cadence, creating burst patterns

### Why no config helps

- No `typing` section in `config.yaml` or `hermes_cli/config.py`
- No `--no-typing` flag or environment variable
- The typing behavior is hardcoded in the platform adapters

## Source file locations (NixOS install)

Files are in the Nix store at:
```
/nix/store/<hash>-hermes-agent-env/lib/python3.12/site-packages/
```

Key files:
- `gateway/platforms/base.py` — lines 2013-2090 (`_keep_typing`), lines 2780-2800 (task creation)
- `gateway/platforms/discord.py` — lines 558 (`_typing_tasks` dict), lines 2669-2710 (`send_typing` / `stop_typing`)

## Proposed upstream fix

1. Add a `typing` config section: `typing.enabled` (bool), `typing.interval` (float)
2. Honor 429 `Retry-After` headers — pause the typing loop for the requested duration
3. Consider whether base class `_keep_typing` should run at all for adapters that override `send_typing` with their own loops (currently both run simultaneously)
4. Exponential backoff on consecutive typing failures instead of fixed cadence

## Diagnosis commands

```bash
# Count rate-limit hits in the last hour
sudo journalctl -u hermes-agent --since "1 hour ago" --no-pager | grep -c "rate limited"

# Breakdown by channel
sudo journalctl -u hermes-agent --since "1 hour ago" --no-pager | grep "rate limited" | grep -oP 'channels/\K[0-9]+' | sort | uniq -c | sort -rn

# Timeline of hits
sudo journalctl -u hermes-agent --since "30 minutes ago" --no-pager | grep "rate limited" | awk '{print $1, $2, $3}' | uniq -c

# Check if still happening
sudo journalctl -u hermes-agent --since "2 minutes ago" --no-pager | grep -c "rate limited"
```
