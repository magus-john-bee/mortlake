---
name: web-search
description: All web search and web fetch operations use Exa MCP directly. No other search path is used.
category: research
---

# Web Search Skill

All web searches MUST go through the exa MCP tools directly. Do not use any other web search mechanism.

## Tools

Use these three exa MCP tools for all web search operations:

### 1. `mcp_exa_web_search_exa` — Standard Search
For general web searches. Returns title, URL, published date, author, and code highlights.

```json
{
  "query": "semantically rich description of the ideal page",
  "numResults": 10
}
```

### 2. `mcp_exa_web_search_advanced_exa` — Advanced Search
For targeted searches with filters (date ranges, domain restrictions, content requirements, exclusion).

Key parameters:
- `query` — search query
- `numResults` — number of results (1-100)
- `category` — filter: company, research paper, news, pdf, github, personal site, people
- `includeText` — ONE phrase (max 5 words) that must appear in results
- `excludeText` — phrases to exclude (use array, one phrase each)
- `startPublishedDate` / `endPublishedDate` — ISO 8601 date range
- `includeDomains` / `excludeDomains` — domain filters
- `enableHighlights: true` — extract relevant snippets
- `highlightsQuery` — focus highlights on specific sub-topic

**Gotcha:** `includeText` only accepts a single phrase up to 5 words. `["syntax", "example"]` (two phrases) will be rejected — use `["list comprehension syntax"]` instead.

### 3. `mcp_exa_web_fetch_exa` — Content Fetching
For extracting full content from known URLs.

```json
{
  "urls": ["https://example.com"],
  "maxCharacters": 3000
}
```

## Related Skills

### Search & Research
- **llm-wiki** — Persistent knowledge base lookups and wiki-style research
- **arxiv** — Academic paper discovery and retrieval
- **blogwatcher** — Monitoring RSS/Atom feeds and blogs

### MCP Tools
- **mcporter** — CLI for listing, configuring, authenticating, and calling MCP servers
- **native-mcp** — Built-in MCP client for connecting to external MCP servers

## Specialized Search Strategies

For specialized search tasks, use these sub-skills from `references/`:

- **code-search** — When searching for code examples, API syntax, SDK docs, config patterns, or debugging help. Uses `get_code_context_exa`.
- **company-research** — When researching companies, competitors, market landscape, or building company lists. Uses `web_search_advanced_exa` with `category: "company"`.
- **lead-generation** — When building prospect lists with ICP scoring and enrichment. Uses `deep_search_exa` with subagent batching. See: `references/lead-generation.md`
- **people-search** — When finding LinkedIn profiles, experts, team members, or professional backgrounds. Uses `web_search_advanced_exa` with `category: "people"`.
- **financial-report-search** — When searching for SEC filings (10-K, 10-Q), quarterly earnings, annual reports, or investor presentations. Uses `web_search_advanced_exa` with `category: "financial report"`.
- **research-paper-search** — When searching for academic papers, arXiv preprints, or scientific research with full filter support. Uses `web_search_advanced_exa` with `category: "research paper"`.
- **personal-site-search** — When searching for personal blogs, portfolio sites, or independent analysis from practitioners. Uses `web_search_advanced_exa` with `category: "personal site"`.

### web-search-tools-comparison
When comparing Exa against alternatives (e.g., Codex native web search, Google SERP), see `references/web-search-tools-comparison.md` for a condensed comparison of capabilities, tradeoffs, and when to use which.

## MCP Configuration

The exa MCP server is configured in `config.yaml` under the `mcp` section. It provides three tools:
- `exa_web_search_exa`
- `exa_web_search_advanced_exa`
- `exa_web_fetch_exa`

These are automatically available when the MCP server is connected.
