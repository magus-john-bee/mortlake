---
name: logseq
description: Read, search, and create notes in the Logseq knowledge base at ~/vault/logbook. Logseq is a privacy-first, open-source PKM that stores notes as plain Markdown/Org-mode files in a local graph. Supports wikilinks, block references, journals, and task management.
category: note-taking
---

# Logseq Knowledge Base

**Location:** Set via `LOGSEQ_PATH` environment variable.

If unset, defaults to `~/vault/logbook`.

**Primary graph:** The user's main Logseq graph is `~/vault/logbook` ("logbook"). All Logseq workflows should assume this graph unless otherwise specified. Set `LOGSEQ_PATH=/home/john/vault/logbook` in the hermes-env sops secret.

Note: Paths may contain spaces — always quote them.

---

## Research Paper Workflow

When the user shares an arXiv URL and says to add it to logbook:

1. **Fetch metadata** using the arXiv API (see `arxiv` skill).
2. **Update `pages/ai-research.md`** -- append to the latest dated section (or create `## Saved M/D/YYYY`). Format: `- [[ARXIV_ID] Title](https://arxiv.org/abs/ARXIV_ID)`
3. **Download the PDF** to `assets/research-papers/ARXIV_ID.pdf` via `curl -L -o assets/research-papers/ARXIV_ID.pdf https://arxiv.org/pdf/ARXIV_ID`
4. **PR + merge** since logbook has branch protection. Branch name: `add-ARXIV_ID`.

The `ai-research.md` page organizes links by date with `---` separators and `## Saved M/D/YYYY` headers. New entries go at the bottom of the latest section or in a new section for today's date.

---

## Routing Heuristic

Logseq (logbook) is the user's personal knowledge management system. When the user asks you to file, track, or store something that doesn't belong to a specific git repo or machine config, **check logbook/pages/ first**.

| Request type | Where it goes |
|---|---|
| Machine configs, NixOS modules, infra | `~/src/corpus/` (git repo) |
| Skills | `/var/lib/hermes/.hermes/skills/` |
| Personal lists, company tracking, research notes, GTD items | `~/vault/logbook/pages/` (Logseq) |
| GTD "someday/maybe" items | `~/vault/logbook/pages/gtd-someday-maybe.md` |

When in doubt, search logbook/pages/ for existing pages that match the topic before creating new ones.

**Page discovery pitfall:** When a user says "add to logbook" or "add this to logbook" with a link/note, they almost always have a specific existing page in mind. Search broadly — try multiple patterns covering the topic (e.g. for an AI paper, search `ai-research`, `machine-learning`, `papers`, `reading-list`). Do NOT assume the page doesn't exist after one narrow search. If you can't find it, ask the user rather than creating a new page.

---

## Key Concepts

| Concept | Description |
|---------|-------------|
| **Pages** | Markdown/Org-mode files in `pages/` directory |
| **Journals** | Daily notes in `journals/YYYY_MM_DD.md` |
| **Wikilinks** | `[[Page Name]]` links to other pages |
| **Block references** | `((block-id))` references to specific blocks |
| **Properties** | Page-level metadata at top: `key:: value` |
| **Linked/Unlinked refs** | Backlink references shown on each page |

---

## Read a note (page)

```bash
LOGSEQ="${LOGSEQ_PATH:-$HOME/vault/logbook}"
cat "$LOGSEQ/pages/Note Name.md"
```

## Read a journal entry

```bash
LOGSEQ="${LOGSEQ_PATH:-$HOME/vault/logbook}"
# Today's journal
cat "$LOGSEQ/journals/$(date +%Y_%m_%d).md"
# Specific date
cat "$LOGSEQ/journals/2026_04_16.md"
```

## List pages

```bash
LOGSEQ="${LOGSEQ_PATH:-$HOME/vault/logbook}"

# All pages
find "$LOGSEQ/pages" -name "*.md" -type f

# In a specific folder
ls "$LOGSEQ/pages/Subfolder/"
```

## List journals

```bash
LOGSEQ="${LOGSEQ_PATH:-$HOME/vault/logbook}"
ls -1 "$LOGSEQ/journals/"
```

## Search

```bash
LOGSEQ="${LOGSEQ_PATH:-$HOME/vault/logbook}"

# By filename
find "$LOGSEQ/pages" -name "*.md" -iname "*keyword*"

# By content (pages only)
grep -rli "keyword" "$LOGSEQ/pages" --include="*.md"

# By content (journals only)
grep -rli "keyword" "$LOGSEQ/journals" --include="*.md"

# By content (entire graph)
grep -rli "keyword" "$LOGSEQ" --include="*.md"
```

## Create a page

```bash
LOGSEQ="${LOGSEQ_PATH:-$HOME/vault/logbook}"
cat > "$LOGSEQ/pages/New Page.md" << 'ENDPAGE'
title:: New Page

# New Page

Content here.

[[Related Page]]  <!-- wikilink -->

-
ENDPAGE
```

## Create a journal entry

```bash
LOGSEQ="${LOGSEQ_PATH:-$HOME/vault/logbook}"
DATE=$(date +%Y_%m_%d)
cat > "$LOGSEQ/journals/$DATE.md" << 'ENDJOURNAL'
title:: Journal

# Journal

-
ENDJOURNAL
```

## Append to a page

```bash
LOGSEQ="${LOGSEQ_PATH:-$HOME/vault/logbook}"
echo -e "\nNew content here." >> "$LOGSEQ/pages/Existing Page.md"
```

## Properties (YAML-alternative frontmatter)

Logseq uses `key:: value` syntax at the top of pages (no `---` delimiters):

```markdown
title:: My Page
alias:: Alias Name
tags:: tag1, tag2
created:: 2026-04-16

# My Page

Content...
```

## Task Management

Logseq has built-in task markers:

```markdown
- TODO This is a task to do
- LATER This will be done later
- NOW This is in progress
- DONE This is complete
- CANCELED This was canceled
```

## Wikilinks

Link to other pages with `[[Page Name]]`. The link target is resolved to `pages/Page Name.md`.

```markdown
See [[Related Page]] for details.
```

## Block References

Reference a specific block by its ID (auto-generated UUID in parentheses at the end of a line):

```markdown
<!-- On source page -->
This is a block with an ID. #+BEGIN_ID
abc123 #+END_ID

<!-- Referencing it from elsewhere -->
((abc123))
```

## Linked and Unlinked References

Logseq automatically tracks all pages that link to or mention a given page. These appear in the **References** section of each page. When creating or editing notes, be aware that:
- `[[Page Name]]` creates a **linked reference**
- Writing `Page Name` (without brackets) in a block creates an **unlinked reference**

---

## Comparison: Logseq vs Obsidian

| Feature | Logseq | Obsidian |
|---------|--------|----------|
| Vault location | `~/vault/logbook` (LOGSEQ_PATH) | `~/Documents/Obsidian Vault/` |
| Wikilinks | `[[Page]]` | `[[Page]]` |
| Daily notes | Journals (`journals/`) | Daily notes plugin |
| Block refs | `((id))` | `^block-id` |
| Properties | `key:: value` inline | YAML frontmatter `---` |
| Task markers | TODO/LATER/NOW/DONE/CANCELED | Checklist plugin |
| Org-mode | Native support | Plugin only |

The core file operations (read, write, search, list) work identically — only the paths and some feature names differ.
