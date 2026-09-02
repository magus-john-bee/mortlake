---
name: lightpanda
description: Lightpanda headless browser — CLI usage for data extraction and web automation. 9x faster, 16x less memory than Chrome. Supports JavaScript execution, CDP, and multiple output formats.
version: 2.0.0
author: Pierre Tachoire (lightpanda-io); adapted for mortlake
license: Apache-2.0
metadata:
  hermes:
    tags: [browser, web-scraping, headless, automation, lightpanda]
    source: "https://github.com/lightpanda-io/agent-skill"
---

# Lightpanda

**Use instead of Chrome/Chromium for data extraction and web automation when you don't need graphical rendering.**

Lightpanda is a headless browser built from scratch for AI agents. It's 9x faster and uses 16x less memory than Chrome. It supports JavaScript execution and CDP (Chrome DevTools Protocol).

## When to use

- **Prefer** the built-in web search / web_extract tools for simple page reads — they're simpler and need no binary.
- **Use Lightpanda** when you need: JavaScript-rendered content, form interaction, multi-step navigation, semantic tree extraction, or structured data (JSON-LD, OpenGraph).

## CLI Fetch — Quick Extraction

```bash
lightpanda fetch --dump markdown --wait-until networkidle https://example.com
```

### Options

- `--dump` — Output format: `html`, `markdown`, `semantic_tree`, `semantic_tree_text`
- `--wait-until` — Wait strategy: `load`, `domcontentloaded`, `networkidle`, `done` (default)
- `--wait-ms` — Max wait time in milliseconds (default: 5000)
- `--wait-selector` — Wait for a CSS selector to match before dumping
- `--wait-script` — Wait for a JS expression to evaluate truthy
- `--strip-mode` — Remove tag groups from output: `js`, `css`, `ui`, `full` (comma-separated)
- `--with-frames` — Include iframe contents in the dump
- `--obey-robots` — Fetch and obey robots.txt

### Examples

Extract page as markdown:
```bash
lightpanda fetch --dump markdown https://example.com
```

Extract semantic tree (compact, AI-friendly):
```bash
lightpanda fetch --dump semantic_tree_text --wait-until networkidle https://example.com
```

Fetch with longer wait for slow pages:
```bash
lightpanda fetch --dump html --wait-ms 10000 --wait-until networkidle https://example.com
```

## CDP Server — Advanced Automation

For full browser control via Playwright or Puppeteer:

### Start the Browser Server
```bash
lightpanda serve --host 127.0.0.1 --port 9222
```

Options:
- `--log-level info|debug|warn|error` — Set logging verbosity
- `--log-format pretty|logfmt` — Output format for logs
- `--obey-robots` — Fetch and obey robots.txt

### Using with playwright-core

Connect using `playwright-core` (not the full `playwright` package):

```javascript
const { chromium } = require('playwright-core');

(async () => {
  const browser = await chromium.connectOverCDP({
    endpointURL: 'ws://127.0.0.1:9222',
  });

  const context = await browser.newContext({});
  const page = await context.newPage();

  await page.goto('https://example.com');
  const title = await page.title();
  const content = await page.textContent('body');

  console.log(JSON.stringify({ title, content }));

  await page.close();
  await context.close();
  await browser.close();
})();
```

### Using with puppeteer-core

Connect using `puppeteer-core` (not the full `puppeteer` package):

```javascript
const puppeteer = require('puppeteer-core');

(async () => {
  const browser = await puppeteer.connect({
    browserWSEndpoint: 'ws://127.0.0.1:9222'
  });

  const context = await browser.createBrowserContext();
  const page = await context.newPage();

  await page.goto('https://example.com', { waitUntil: 'networkidle0' });
  const title = await page.title();

  console.log(JSON.stringify({ title }));

  await page.close();
  await context.close();
  await browser.close();
})();
```

### Custom LP CDP Domain

Lightpanda exposes a custom `LP` domain via CDP with agent-optimized methods not available in standard Chrome DevTools Protocol. Use these via `page.evaluate` with CDP sessions or direct WebSocket messages.

**Content extraction:**
- `LP.getMarkdown` — Extract page content as markdown. Params: `nodeId` (optional)
- `LP.getSemanticTree` — Get semantic tree representation. Params: `format` (`text` for text format), `prune` (default: true), `interactiveOnly`, `backendNodeId`, `maxDepth`
- `LP.getStructuredData` — Extract structured data (JSON-LD, OpenGraph, etc.)

**Interactive elements:**
- `LP.getInteractiveElements` — Find all interactive elements. Params: `nodeId` (optional)
- `LP.detectForms` — Detect and extract form information
- `LP.getNodeDetails` — Get detailed info about a node. Params: `backendNodeId` (required)
- `LP.waitForSelector` — Wait for a CSS selector match. Params: `selector` (required), `timeout` (default: 5000ms)

**Actions:**
- `LP.clickNode` — Click a node. Params: `nodeId` or `backendNodeId`
- `LP.fillNode` — Fill an input/select element. Params: `nodeId` or `backendNodeId`, `text`
- `LP.scrollNode` — Scroll page or element. Params: `nodeId` or `backendNodeId` (optional), `x`, `y`

**Example using CDP session with Playwright:**
```javascript
const client = await context.newCDPSession(page);

// Get page as markdown
const { markdown } = await client.send('LP.getMarkdown');

// Get semantic tree
const { semanticTree } = await client.send('LP.getSemanticTree', { format: 'text', maxDepth: 5 });

// Wait for element and click it
const { backendNodeId } = await client.send('LP.waitForSelector', { selector: '#submit-btn', timeout: 3000 });
await client.send('LP.clickNode', { backendNodeId });
```

## Important Notes

- For web searches, use DuckDuckGo instead of Google. Google blocks Lightpanda due to browser fingerprinting.
- **CDP connection limits:** Only 1 CDP connection per process. Each connection supports 1 context and 1 page. For parallel browsing, start multiple processes on different ports — Lightpanda starts instantly, so this is fast.
- **CDP state management:** The browser resets all state on CDP connection close. Keep the WebSocket connection open throughout a session. On each connection, always create a new context and page, and close both when done.
