---
name: local-market-scan
description: "Use for local buying recon around Spartanburg & Greenville."
version: 1.0.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [marketplace, facebook, local, buying, recon, spartanburg, greenville]
---

# Local Market Scan — FB Marketplace recon without the feed

## Purpose

John buys locally through Facebook Marketplace (CL isn't liquid enough in this
area), but wants to touch Facebook as little as possible — it's addictive trash
and every minute on it is a cost. The agent does ALL the digging; John's only
Facebook interaction is opening the one listing link and messaging the seller.

**Standing shape: search + fetch via Exa's index, never a live logged-out
scrape.** Direct fetches of facebook.com login-redirect (verified 2026-09-18);
the winning move is that Exa's crawl cache holds FULL item-page content —
price, description, location, listing age, photo URL (verified:
`/marketplace/item/<id>/` pages return complete listing details through
`web_fetch_exa`).

## Method

### 1. Search — Exa advanced, domain-pinned

```
mcp__exa__web_search_advanced_exa:
  query: "Facebook Marketplace listing <item keywords> for sale Spartanburg Greenville South Carolina"
  includeDomains: ["facebook.com"]
  numResults: 10
  enableHighlights: true
  highlightsQuery: "price listing"
```

Query tips:
- Keep the query a natural description ("Facebook Marketplace listing for a
  used table saw for sale") — neural search, not keyword-only.
- Add city names for geo recall; Spartanburg + Greenville covers the metro.
- `/marketplace/item/` URLs in results = real listings; permalink/group/page
  URLs = adjacent surfaces (see 3).

### 2. Fetch — full details from cache

```
mcp__exa__web_fetch_exa:
  urls: ["https://www.facebook.com/marketplace/item/<id>/"]
```

Returns full cached listing: price, seller description (verbatim, emojis and
all), structured details (mileage/condition fields), location, "Listed N ago",
photo URL. The photo URL is a signed CDN link — fetch works while the
signature lives (days); don't archive them as permanent.

### 3. Fold in adjacent surfaces (they index BETTER than Marketplace)

Public page/group posts are fully indexable and often fresher for local:

- **Pawn shops** (E-Z Money Spartanburg, Palmetto Pawn Greer, etc.) — tools,
  electronics, serial-numbered goods; post inventory publicly
- **Estate-sale posts** in local groups ("Yeah THAT Greenville!") — tools &
  garage items by the garage-full; cash/Venmo, dated windows
- **Trading-post / consignment pages** (Carolina Trading Post) — furniture,
  vintage; often show Sold status
- **Liquidators** (SCD Sales, Johnston SC) — open-box/returned electronics at
  steep cuts

Search without the domain pin to sweep these (same query minus
`includeDomains`), or target a known page via
`includeDomains: ["facebook.com/<page>"]`.

### 4. Complementary sources (non-Facebook)

- **Craigslist** (greenville.craigslist.org) — fully fetchable, no login;
  sparser but zero-noise. Search + fetch work directly.
- **eBay** — for shipped comps / price ceilings when evaluating a local ask;
  sold listings (via web search) for true market price.
- OfferUp/app-only sources are NOT reachable — don't burn calls trying.

## Limits (state these when reporting)

- **Recency bias**: index coverage skews to whatever the crawler saw recently;
  old results are common. Good for "what's out there", weak for time-sensitive
  deals. Say the index date when it matters.
- No Marketplace-side sorting/filtering (price, distance) — the query is the
  only lever.
- Listings sell and vanish — a cached page may describe a sold item; the
  link's live state is ground truth only in John's logged-in view.
- Fresh fetches of facebook.com hit login walls / temp blocks — do NOT retry
  live fetches; cache-first always.

## Output shape

Report as a list, one entry per find:

```
<item> — $<price> — <location> — listed <age> — <source: Marketplace | pawn | estate | CL | liquidator>
  link: <url>
  note: <condition/details from cached description, one line>
```

Deliver links, not screenshots. John opens one link, messages the seller —
that's the entire Facebook interaction budget.

## Watcher variant

For ongoing hunts (e.g., RAM during a shortage, a specific tool at a price
ceiling), this becomes a cron watcher: daily Exa search with the query pinned,
dedup against previously surfaced listing IDs (watchers skill watermark
pattern), digest to Discord on new hits only. Set up only on explicit request.
