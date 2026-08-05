# Web Search Tools Comparison: Exa vs Codex Native

Condensed from research session 2026-05-19. For context when evaluating whether Exa is worth keeping alongside a model's built-in web search.

## Codex Native Web Search

Built on the OpenAI Responses API `web_search` tool. Used by Codex CLI and Codex IDE extension.

**Modes:**
- `cached` (default) — OpenAI-maintained index, pre-crawled results. Less prompt injection risk but potentially stale.
- `live` — fetches fresh pages. Default when using `--yolo`/full-access sandbox.
- `disabled` — off entirely.

**Config (config.toml):**
```toml
web_search = "cached"   # default
# web_search = "live"    # same as --search flag
# web_search = "disabled"
```

Recent addition (March 2026): full web search config with filters, location, etc. via `tools.web_search` section.

**Strengths:**
- Zero setup — built in, enabled by default
- Unified billing through OpenAI API
- Security-conscious defaults (cached mode avoids live content injection)
- Native transcript integration, no tool-call overhead

**Weaknesses:**
- No semantic/neural search — keyword-based
- No content extraction control (no highlights, no structured extraction)
- No category indexes (no dedicated research paper, company, people search)
- No deep search modes (no multi-step reasoning over results)
- Limited transparency into how/what it searched
- Cached mode staleness depends on OpenAI's crawl schedule
- Filter options are basic even after the March 2026 update

## Exa

Custom neural search engine built for AI consumption. Available as MCP tool in Hermes.

**Search modes (latency-quality tradeoff):**
| Mode | Speed | Use case |
|------|-------|----------|
| instant | ~250ms | Real-time (chat, voice) |
| fast | ~450ms | Speed with minimal quality loss |
| auto | ~1s | Default |
| deep-lite | 4s | Lightweight synthesized output |
| deep | 4-15s | Complex multi-step reasoning |
| deep-reasoning | 12-40s | Hard research tasks |

**Content extraction:**
- Highlights — 10x token-efficient relevant extracts
- Full text — complete page content
- Summaries — AI-generated per-result overviews
- Structured output — `output_schema` for JSON extraction
- Grounded answers — web-grounded text with citations

**Category indexes:**
- `company` (50M+), `people` (1B+), `research paper` (100M+), `news`, `personal site`, `financial report`, `github`, `pdf`

**Pricing:** $7/1k search, $12-15/1k deep modes, $1/1k pages for content extraction.

**Strengths:**
- Semantic search by meaning, not keyword — handles long natural-language queries
- Rich content extraction with token-efficient highlights
- Category-specific indexes for structured domains
- Configurable depth from sub-second to deep reasoning
- Proven quality — tops SimpleQA and MSMARCO benchmarks vs other search APIs
- Advanced filters: date, domain, text include/exclude, geo, subpage crawling

**Weaknesses:**
- Separate service with own API key, account, billing
- Added latency (deeper modes: 4-40s)
- Cost adds up at scale
- More parameter complexity
- External dependency in agent's critical path

## When to Use Which

- **Codex native:** Quick lookups, "what's the latest version of X", casual doc searches, any time the model already has native search enabled and precision doesn't matter much.
- **Exa:** Research-grade tasks, semantic/meaning-based queries, category-specific searches (papers, companies, people), when you need token-efficient content extraction, structured output from web data, or deep multi-step reasoning over search results.
- **Both together:** Use native for fast generic lookups, Exa for surgical research queries where quality matters more than speed.
