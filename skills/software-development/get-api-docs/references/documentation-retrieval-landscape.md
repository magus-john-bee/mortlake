# Documentation Retrieval Landscape for AI Agents

Research from June 2026. Covers tools and standards for getting current, accurate
documentation into AI agent context -- beyond what's in training data.

## Problem

LLMs generate code from stale training data. When asked about the latest API for
a fast-moving library (React 19, Next.js 15, Nix flake-parts), they hallucinate
deprecated or nonexistent APIs. Documentation retrieval tools solve this by
fetching current docs at inference time.

## Two Problem Domains

1. **Third-party library/framework docs** -- "I need the current API for X right now"
2. **Codebase understanding** -- "I need to navigate and understand this specific repo"

Tools generally specialize in one domain.

---

## Third-Party Library Docs (MCP Servers)

### Context7 (Upstash) -- 54K GitHub stars, market leader

- Two-tool MCP: `resolve-library-id` -> `query-docs`
- 9,000+ libraries indexed, version-specific
- MIT licensed, self-hostable via streamable-http
- Trigger: append "use context7" to any prompt
- Free tier: 1,000 req/month (was ~6K before Jan 2026 cut). Paid: $8-10/seat/mo
- Cloud endpoint: `https://mcp.context7.com/mcp` (API key in `CONTEXT7_API_KEY` header)
- **Weaknesses**: token-heavy responses, community-contributed docs not always verified,
  had ContextCrush context poisoning vulnerability (patched Feb 2026), cloud-only unless
  self-hosted
- Self-host: MIT repo at `github.com/upstash/context7`, run streamable-http server,
  point at your own library catalog
- April 2026 improvements: 65% token reduction, 38% latency reduction via server-side reranking

### ProContext -- open-source high-accuracy alternative

- MIT, self-hostable, designed for local deployment
- 2,000+ libraries, four MCP tools: resolve, search, read, outline
- Claims ~60% accuracy improvement over other open-source options, ~100% bounded by source docs
- Good fit for privacy-conscious / self-hosted setups
- stdio transport + local cache, Python 3.12+
- **Status: TODO -- planned for setup on thoth**

### DeepWiki (Cognition/Devin team) -- for understanding unfamiliar repos

- Turns any public GitHub repo into queryable wiki with architecture diagrams
- Three MCP tools: `read_wiki_structure`, `read_wiki_contents`, `ask_question`
- Free, no auth for public repos
- **Fully Cognition-dependent**: hosted only at `mcp.deepwiki.com/mcp`. No self-hosting
  option. A community scraping wrapper was shut down ("DeepWiki has cut off the
  possibility to scrape it"). You're at Cognition's mercy for uptime and future pricing.
- 50,000+ repos indexed at launch
- Best for codebase orientation, not API reference snippets
- Complements Context7/ProContext rather than replacing it

### GitMCP -- zero-setup fallback

- Replace `github.com` with `gitmcp.io` in any URL, instant docs
- Free, no auth, any public repo
- Best when Context7/ProContext haven't indexed the library you need

### Ref Tools -- best token efficiency

- 5K token cap per page, session-aware (no repeat results)
- Closed-source paid API ($9-19/mo after 200 free credits)
- Best for long agent runs with context window pressure

### Docfork -- stack-scoped search

- Reads your package.json, limits search to declared dependencies
- Prevents wrong-library matches (a real Context7 problem)
- Hybrid semantic + BM25 search via RRF

### Practical pairings (community consensus)

- **Context7 + GitMCP** -- broad library coverage + any-repo fallback
- **Context7 + DeepWiki** -- API snippets + repo understanding
- **Context7 + Ref Tools** -- broad coverage + token-efficient for large APIs

---

## llms.txt -- The Emerging Standard

Proposed by Jeremy Howard (AnswerDotAI) in 2024. Websites publish `/llms.txt` -- a
curated markdown index of their best documentation pages. Think `sitemap.xml` but
for agents, not crawlers.

### Format

```markdown
# Project Name

> One-paragraph factual summary of the project.

## Section Name

- [Page Title](https://absolute.url): One-sentence description
- [Another Page](https://absolute.url): One-sentence description

## Optional

- [Less Critical Page](https://absolute.url): Can skip for shorter context
```

### Key conventions

- Absolute URLs only (agents fetch in isolation)
- H1 = site name, H2s = categories, bullet links = doc pages
- `llms-full.txt` optional companion: same index + full page content inlined
- Keep to 10-30 links in root file; use llms-full.txt for comprehensive coverage

### Adoption

Anthropic, Stripe, Vercel, Cloudflare, Cursor, Windsurf, and many others ship one.
Major doc platforms (Mintlify, VitePress, Docusaurus) have plugins to auto-generate.

### Agent usage

When researching a library, check `https://that-library.com/llms.txt` as a first
step. It provides a curated map of the best docs -- often better than crawling the
full site.

**Status: TODO -- planned as a shared skill/instruction for both Hermes and Codex
to check llms.txt first when looking up docs.**

---

## Codebase Understanding (for your own repos)

These index local code for agent navigation without reading every file.

### colbymchenry/CodeGraph -- recommended (38,641 stars)

The clear winner in this category. Mature, well-maintained, honest benchmarks.

- **TypeScript**, self-contained binary (bundles its own Node 22+ runtime)
- **MIT licensed**, 100% local SQLite + FTS5, no API keys, no external services
- **8 MCP tools** with `codegraph_explore` as the primary -- one-call answers for
  "how does X work", tracing flows, surveying areas
- **20+ languages** via tree-sitter, framework-aware routes for 14 web frameworks
- **React Native / Expo / iOS cross-language bridging** (Swift<->ObjC<->JS)
- **Auto-sync** via native file watcher (FSEvents/inotify) with staleness banners
- **Explicit Hermes Agent support** in the installer
- **Benchmarks**: 7 real codebases (VS Code, Django, Tokio, OkHttp, etc.), 4 runs each,
  median reported: 16% cheaper, 47% fewer tokens, 58% fewer tool calls
- **Known limitation**: FTS5 keyword search only, no semantic/vector search.
  If you don't know the symbol name, you may need Exa/web search as fallback.
- **Known limitation**: module-qualified symbol lookup (e.g. `module::symbol`) not
  supported for Rust and similar languages (issue #173). Bare-name lookup silently
  picks a random collision when ambiguous.
- **Zero config**: auto-detects languages, skips node_modules/dist/etc, respects .gitignore
- Install: `curl -fsSL https://raw.githubusercontent.com/colbymchenry/codegraph/main/install.sh | sh`
  then `codegraph install` to wire into agents, `codegraph init -i` per project
- **Status: TODO -- planned for setup on thoth**

### Lore -- deepest code intelligence

- SCIP-first + LSP enrichment = actual resolved type information, not just structural
- If you need "what's the return type of this generic function", Lore knows from the
  language server. CodeGraph knows the function exists but not types.
- 14+ MCP tools, local-first, optional vector embeddings
- Benchmarks: +10pp correctness, 84% fewer tokens, 62% faster vs grep baseline
- More setup complexity (requires SCIP indexers + optional LSP)

### suatkocar/CodeGraph (Rust) -- NOT recommended

- 1 star, 1 contributor, last commit March 2026
- Claims 44 tools, 32 languages, security scanning (OWASP/CWE/taint analysis),
  data flow analysis, git analytics, PageRank -- massively overscoped for a solo
  project in its first month
- Self-reported quality metrics show search relevance at F1 0.37 (terrible)
- Benchmarked on an 11-file TypeScript project only
- The core indexing may work, but peripheral tools (security, data flow, complexity)
  are almost certainly thin wrappers, not real static analysis
- Compare: colbymchenry/CodeGraph has 38K stars, transparent benchmarks, honest
  issue handling, and deliberately chose 8 focused tools over 44 aspirational ones

### Other codebase tools (for reference)

- **Mnemo**: Full memory + knowledge graph + code graph in one (58 tools). More like
  "AgentMemory + code indexing combined."
- **SymDex**: Repo-local symbolic indexing, context packs, multi-repo registry
- **Probe (ZeroEntropy)**: Strongest retrieval quality (cross-encoder reranking), needs API key
- **CodeRAG**: Full-featured RAG with web viewer, backlog integration

### Key differentiators at a glance

| | colbymchenry/CodeGraph | Lore | Mnemo | suatkocar (Rust) |
|---|---|---|---|---|
| Search | FTS5 keyword | BM25 + semantic + fused | BM25 + vector + graph | BM25 + vector + RRF |
| Semantic | No | Yes (optional) | Yes (ONNX) | Yes (Jina ONNX) |
| Languages | 20+ | 23 (SCIP+LSP) | 14 | 32 (claimed) |
| Type info | No | Yes (LSP) | No | No |
| Maturity | 38K stars, 15 releases | ~2K stars | ~1K stars | 1 star, likely overreaching |

---

## Current Setup Assessment

What we have on this system:
- **Exa MCP**: `web_search_exa`, `web_fetch_exa`, `get_code_context_exa` -- solid
  general-purpose doc retrieval
- **Skills system**: domain-specific knowledge (dendritic-pattern, nix-wrapper-modules, etc.)
- **Web search**: general fallback
- **chub CLI**: API doc fetching via community registry

The gap: **no automatic, proactive doc lookup**. Agent searches when it thinks to,
but nothing forces it to pull fresh docs before writing code against an API.

### Planned additions (from June 2026 research session)

1. **colbymchenry/CodeGraph MCP** -- codebase intelligence, 100% local, Hermes support
2. **ProContext MCP** -- self-hosted library doc lookup, MIT, local-first
3. **Nix/NixOS MCP** -- NixOS module options, nixpkgs API, flake-parts/disko/sops-nix docs
4. **llms.txt awareness** -- shared skill for Hermes + Codex to check /llms.txt first
5. **Keep Exa + chub as fallback** -- for anything not covered by the above
