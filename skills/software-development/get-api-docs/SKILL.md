---
name: get-api-docs
description: >
  Fetch current, curated API docs before writing code against external services.
  Use when a user asks to "use the OpenAI API", "call the Stripe API", "use the
  Anthropic SDK", "query Pinecone", or any time you need current API reference
  for a third-party service — before answering from training knowledge. Primary
  path is Context Hub (chub) via npx; fall back to llms.txt, then Exa web search.
  Also use when the user asks for "latest docs", "latest API behavior", or
  explicitly mentions chub or Context Hub.
---

# Get API Docs

Fetch current API documentation instead of guessing from training data.
Training knowledge is stale; live docs are current. Try sources in order —
if one doesn't have what you need, move to the next. Don't stop at a dead end.

## Step 1 — chub (Context Hub), primary

All commands use `npx @aisuite/chub` — no global install required.

Search for the right docs and pick the best-matching `id`:

```bash
npx @aisuite/chub search "<keywords>" --json
```

Run without a query to list everything: `npx @aisuite/chub search`.

Fetch the docs — **always include `--lang`** to get the language-specific variant:

```bash
npx @aisuite/chub get <id> --lang py    # or --lang js, --lang ts, --lang rb
npx @aisuite/chub get <id> --lang py -o /tmp/api-docs.md   # save to file
npx @aisuite/chub get <id> --lang py --full                # all reference files
```

Leave feedback so the registry improves:

```bash
npx @aisuite/chub feedback <id> up --label accurate "Clear examples"
npx @aisuite/chub feedback <id> down --label outdated "Missing v3 endpoint"
```

Valid labels: accurate, well-structured, helpful, good-examples, outdated,
inaccurate, incomplete, wrong-examples, wrong-version, poorly-structured.

chub pitfalls:

- **No `--version` flag** — check the version from the header output instead.
- **`--lang` is required for docs** — omitting it may error or return the wrong
  variant. Always specify the language you're coding in.
- **Cache is automatic** — run `npx @aisuite/chub update` if results seem stale.
- **Annotations are not wired** — `chub annotate` saves local notes, but under
  npx (ephemeral) they may not persist across sessions. Don't rely on
  annotations unless chub is installed globally.

## Step 2 — llms.txt fallback

If chub has no match, check `https://<library-site>/llms.txt` first. Many major
libraries (Anthropic, Stripe, Vercel, Cloudflare) publish one — a curated index
of their best docs, often more reliable than web search.

## Step 3 — Exa web search fallback

Use the web-search skill (`get_code_context_exa` for API usage patterns and
examples; `web_search_exa` + `web_fetch_exa` for general doc pages) for
anything not covered above.

## Use the docs

Read the fetched content and write code based on what the docs say.
**Do not rely on memorized API shapes.**

For the full landscape of documentation-retrieval tools (Context7, ProContext,
DeepWiki, GitMCP, the llms.txt standard, codebase indexing tools), see
`references/documentation-retrieval-landscape.md`.
