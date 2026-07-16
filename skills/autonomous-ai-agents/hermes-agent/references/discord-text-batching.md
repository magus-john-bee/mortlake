# Discord Duplicate Messages — Investigation Reference

## Symptom

User sees two separate bot messages in a Discord DM where only one was expected (e.g. "Hey! 👋 What's up?" AND "Hey! What can I help you with?").

## Initial Theory (DISPROVEN)

~~The Discord adapter's text batching mechanism buffers outbound text and flushes stale content when a new inbound message arrives, causing duplicate messages.~~

**This is wrong.** The text batching mechanism (`_enqueue_text_event` / `_flush_text_batch` in `discord.py` lines 4428-4514) handles **INBOUND** user messages — it merges split Discord messages (2000-char chunks that arrive within milliseconds). The `Flushing text batch` log lines are the inbound dispatcher, NOT outbound duplication. The flushed char count is the user's message length being dispatched (e.g. "Hello" = 5 chars).

## What the Logs Actually Show

On 2026-05-16, the user reported seeing two responses ("Hey! 👋 What's up?" and "Hey! What can I help you with?"). Full gateway log analysis:

```
03:21:25  /reset invoked → generation invalidated
03:21:26  Sending response (115 chars) — reset confirmation
03:21:33  Flushing text batch (5 chars) — "Hello" dispatched (normal inbound)
03:21:33  Inbound: "Hello"
03:21:43  Response ready: 17 chars, 1 API call
03:21:43  Sending response (17 chars) — "Hey! 👋 What's up?"
```

**Only ONE `Sending response` for the turn.** The message "Hey! What can I help you with?" does not appear anywhere in `gateway.log`, `agent.log`, or the session transcript (`sessions/<id>.jsonl`). The stream consumer was not active (short response, no tool calls). The `already_sent` suppression path was never triggered because it was a clean single-call turn.

The user also reported duplicates earlier (03:17:32: "What the hell is happening? Why are there two of you?"), confirming this is a recurring issue — not a one-off.

## Actual Cause (UNKNOWN — not in gateway)

After tracing through `run.py` (lines 7540-7880), `stream_consumer.py` (lines 360-534, 1055-1270), `base.py` (lines 2892-3130), and `discord.py` (send at ~1430, edit_message, on_message at 715):

- Only one gateway process running
- Only one `adapter.send()` call per response
- No `already_sent` / `final_response_sent` interaction (streaming not active)
- No second "response ready" event
- `on_message` properly ignores own messages (`message.author == self._client.user`)
- Bot message filtering is set to `"none"` (default) — other bots are ignored

**Possible external causes:**
1. Another bot or Discord integration responding to the same messages
2. Discord client cache/rendering issue showing stale messages
3. Discord auto-response configured in the Developer Portal

**Diagnostic question for the user:** Does the second message have a different timestamp, avatar, or bot username? This confirms whether it's from a different source entirely.

## Debugging Technique

When investigating Discord message delivery issues:

### 1. Use `gateway.log`, not journalctl
Gateway writes structured logs to `~/.hermes/logs/gateway.log`. journalctl only captures WARNING+ from stdout (nearly empty for normal operation). The NixOS systemd unit is `hermes-agent.service`.

```bash
# All delivery events for a chat:
grep "CHAT_ID" ~/.hermes/logs/gateway.log | grep -E "Sending response|response ready|Flushing text batch"

# Check for double-sends:
grep "Sending response" ~/.hermes/logs/gateway.log | tail -20
```

### 2. Cross-reference with `agent.log`
`~/.hermes/logs/agent.log` shows session lifecycle, API calls, model info, and stream consumer activity. Use it to confirm what the agent actually returned:

```bash
grep "response_len=\|Turn ended" ~/.hermes/logs/agent.log | tail -10
```

### 3. Check session transcripts
The JSONL transcript in `~/.hermes/sessions/` shows exact role/content for every message. If a message isn't in the transcript, the agent never produced it:

```bash
cat ~/.hermes/sessions/<session_id>.jsonl | python3 -c "
import sys, json
for line in sys.stdin:
    msg = json.loads(line)
    if msg.get('role') in ('user', 'assistant'):
        print(f\"{msg['role']}: {msg['content'][:80]}\")
"
```

### 4. Verify single gateway instance
```bash
ps aux | grep "hermes gateway" | grep -v grep
# Should show exactly ONE process
```

## Key Source Code Locations

| What | File | Lines |
|------|------|-------|
| Inbound text batching | `gateway/platforms/discord.py` | 4428-4514 |
| Outbound send | `gateway/platforms/discord.py` | ~1430 (send method) |
| Stream consumer loop | `gateway/stream_consumer.py` | 360-534 |
| Stream consumer send/edit | `gateway/stream_consumer.py` | 1055-1270 |
| Response delivery gate | `gateway/run.py` | 7540-7880 |
| `already_sent` suppression | `gateway/run.py` | 7840-7877, 15990-16017 |
| Session transcript write | `gateway/run.py` | ~7698-7750 |
| Discord on_message | `gateway/platforms/discord.py` | 715-800 |

## False Leads to Avoid

- **"Flushing text batch" is NOT outbound duplication.** It's the inbound message dispatcher.
- **The 5-char flush is "Hello" being dispatched**, not a stale fragment leaking.
- **`response_previewed` / `already_sent` paths** only activate when streaming is active and the stream consumer sent text. For short responses with no tool calls, these are irrelevant.
