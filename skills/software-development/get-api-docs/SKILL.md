---
name: get-api-docs
description: >
  Fetch current, curated API docs via Context Hub (chub) before writing code against
  external services. Use when a user asks to "use the OpenAI API", "call the Stripe API",
  "use the Anthropic SDK", "query Pinecone", or any time you need current API reference
  for a third-party service. Prefer this over web search for API documentation — chub
  returns versioned, language-specific docs curated for coding agents. Also use when the
  user asks for "latest docs", "latest API behavior", or explicitly mentions chub or
  Context Hub.

---

# Get API Docs via chub (npx)

Fetch current API documentation with `npx @aisuite/chub` instead of guessing from
training data. This gives you the current, correct API shapes.

All commands use `npx @aisuite/chub` — no global install required.

## Step 1 — Search for the right docs

```bash
npx @aisuite/chub search "<keywords>" --json
```

Pick the best-matching `id` from the results (e.g. `openai/chat`, `anthropic/sdk`,
`stripe/api`). If nothing matches, try broader terms or run without a query to list
everything:

```bash
npx @aisuite/chub search
```

## Step 2 — Fetch the docs

```bash
npx @aisuite/chub get <id> --lang py    # or --lang js, --lang ts, --lang rb
```

**Always include `--lang`** to get the language-specific variant.

To save to a file instead of stdout:

```bash
npx @aisuite/chub get <id> --lang py -o /tmp/api-docs.md
```

To fetch all reference files (not just the entry point):

```bash
npx @aisuite/chub get <id> --lang py --full
```

## Step 3 — Use the docs

Read the fetched content and write code based on what the docs say.
**Do not rely on memorized API shapes** — use what chub returned.

## Step 4 — Leave feedback (optional)

If the doc was helpful or had gaps, rate it so the content improves for everyone:

```bash
npx @aisuite/chub feedback <id> up --label accurate "Clear examples"
npx @aisuite/chub feedback <id> down --label outdated "Missing v3 endpoint"
```

Valid labels: accurate, well-structured, helpful, good-examples, outdated, inaccurate,
incomplete, wrong-examples, wrong-version, poorly-structured.

## Pitfalls

- **No `--version` flag** — chub doesn't support it. Check the version from the
  header output of any command.
- **`--lang` is required for docs** — omitting it may return an error or the wrong
  variant. Always specify the language you're coding in.
- **Cache is automatic** — chub caches the registry locally. Run
  `npx @aisuite/chub update` if results seem stale.
- **Annotations are not wired** — the `chub annotate` command saves local notes, but
  in an npx (ephemeral) workflow these may not persist across sessions. Don't rely on
  annotations unless chub is installed globally.
