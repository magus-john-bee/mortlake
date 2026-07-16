# Discord Voice Architecture (Hermes v0.13.0)

Source: `gateway/platforms/discord.py`, `gateway/run.py`

## Two Audio Delivery Paths

### Path 1: Speech Bubbles (Text Channel Attachments)
- `send_voice()` (line 1766) — sends audio as Discord file attachment with `flags: 8192` (native voice message)
- Falls back to plain `discord.File` if voice-message API fails
- Results in a "speech bubble" in the text channel — playable inline but NOT in the VC

### Path 2: Voice Channel Playback (Real-Time Audio)
- `play_tts()` (line 1748) — the entry point for VC audio
- Checks `_voice_text_channels` dict for guild_id → text_channel_id mapping
- If current chat_id matches AND `is_in_voice_channel(guild_id)`, calls `play_in_voice_channel()`
- Otherwise falls back to `send_voice()` (Path 1)
- `play_in_voice_channel()` (line 1914) — streams audio via `discord.FFmpegPCMAudio` through the connected `VoiceClient`
- Pauses `VoiceReceiver` during playback (echo prevention)

## Voice Channel Lifecycle

1. **Join**: `join_voice_channel()` (line 1857) — connects `discord.VoiceClient`, starts `VoiceReceiver`
2. **Play**: `play_in_voice_channel()` — FFmpeg → PCMVolumeTransformer → `vc.play()`
3. **Timeout**: `_voice_timeout_handler()` (line 1978) — auto-disconnects after inactivity
4. **Leave**: `leave_voice_channel()` — disconnects VC, cancels timeout, cleans up receivers

## Key Data Structures

```python
_voice_clients: Dict[int, VoiceClient]       # guild_id -> VoiceClient
_voice_text_channels: Dict[int, int]          # guild_id -> text_channel_id (set on /voice channel)
_voice_receivers: Dict[int, VoiceReceiver]    # guild_id -> VoiceReceiver
_voice_timeout_tasks: Dict[int, asyncio.Task] # guild_id -> timeout task
```

## Voice Mode State (`gateway_voice_mode.json`)

```json
{
  "discord:<chat_id>": "off" | "voice_only" | "all"
}
```

- `"off"` — no TTS
- `"voice_only"` — TTS only when user sends voice messages
- `"all"` — TTS for all replies (what `/voice tts` sets)

## `/voice` Command Handler (run.py ~8863)

| Subcommand | Mode Set | Effect |
|---|---|---|
| `/voice on` | `voice_only` | Reply with voice to voice messages |
| `/voice off` | `off` | Text only |
| `/voice tts` | `all` | Voice reply to ALL messages |
| `/voice channel` | (joins VC) | Bot joins user's VC |
| `/voice leave` | (leaves VC) | Bot disconnects |
| `/voice status` | (read-only) | Shows mode + VC info |

## Auto-TTS Routing (run.py)

When voice mode is `"all"` or `"voice_only"`, the gateway runner handles TTS automatically:

1. After agent generates a text response, `_should_send_voice_reply()` (~9132) decides whether to send TTS
2. If yes, `_send_voice_reply()` (~9186) generates audio via `text_to_speech_tool`
3. If the bot is in a VC for this guild, it calls `adapter.play_in_voice_channel()` — **real VC audio**
4. Otherwise falls back to `adapter.send_voice()` — **speech bubble**

### ⚠️ Dedup Pitfall: Agent `text_to_speech` disables auto-TTS

The runner checks if the agent already called `text_to_speech` in the current turn (line ~9165):

```python
has_agent_tts = any(
    msg.get("role") == "assistant"
    and any(
        tc.get("function", {}).get("name") == "text_to_speech"
        for tc in (msg.get("tool_calls") or [])
    )
    for msg in agent_messages
)
if has_agent_tts:
    return False  # SKIP auto-TTS
```

When the agent calls `text_to_speech`, the output goes through the normal `send_voice()` path (speech bubble). But the runner's auto-TTS — which would have routed through `play_in_voice_channel()` (VC audio) — is skipped.

**Result:** Agent-initiated `text_to_speech` = speech bubbles. Runner auto-TTS = VC audio. They are mutually exclusive.

**Correct behavior when voice mode is active:** Respond with plain text only. Let the runner's auto-TTS handle audio generation and VC routing.

## Troubleshooting

**"Speech bubbles instead of VC audio"**: Bot is not in the voice channel. User must run `/voice channel` first, then `/voice tts`.

**Voice mode keeps resetting**: Check `gateway_voice_mode.json` — it persists across restarts. If corrupt, delete it and re-run `/voice tts`.

**ElevenLabs 402 errors**: Free tier cannot use library voices. Either upgrade or switch `tts.provider` to `edge` (free).
