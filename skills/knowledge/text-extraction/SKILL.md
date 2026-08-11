---
name: text-extraction
description: >
  Extract clean text from documents (PDF, EPUB, DOCX, HTML, RTF, Markdown, plain text)
  using pandoc as the primary engine, with pdftotext for prose PDFs and docling as an
  optional fallback for technical PDFs (tables, code blocks, formulas). Use when you need
  raw text from a document for analysis, search indexing, or feeding into another skill
  like book-to-skill.
version: 1.0.0
license: MIT
metadata:
  category: knowledge
---

# Text Extraction

Extract clean text + lightweight metadata from any document format using the best
available tool. Pandoc handles most formats; PDFs need special treatment.

## Tool Priority

| Format | Primary | Fallback | Notes |
|--------|---------|----------|-------|
| EPUB, DOCX, HTML, RTF, ODT | `pandoc` | — | Single binary, excellent markdown output |
| PDF (prose) | `pdftotext` (poppler) | `pdfminer.six` | Fast, clean text |
| PDF (technical) | `docling` | `pdftotext` | Preserves tables, code blocks, formulas (~1.5s/page) |
| PDF (scanned) | `ocrmypdf` → then extract | — | No text layer without OCR |
| TXT, MD, rst, AsciiDoc | passthrough | — | Already text |
| MOBI, AZW, AZW3 | `ebook-convert` (Calibre) | — | External binary, not pip |

## Usage

```bash
# Auto-detect format, choose best extractor
scripts/extract.sh <file-or-dir> [file2 ...]

# Force technical mode (use docling if available for PDFs)
scripts/extract.sh --technical <pdf>

# Force text mode (use pdftotext for PDFs)
scripts/extract.sh --text <pdf>

# Check which extractors are available
scripts/extract.sh --check
```

## Output

Creates a working directory (`/tmp/extract_work/` by default) containing:

- `full_text.txt` — all sources concatenated with `--- SOURCE: filename ---` separators
- `metadata.json` — per-source stats (format, extractor used, word count, est. tokens)

## How It Works

1. For each input file, detect format by extension
2. Route to the best available extractor for that format
3. Convert to plain text (pandoc targets `plain`) or lightweight markdown
4. Concatenate all sources with visual separators
5. Write metadata JSON with stats

## Scanned PDF Detection

The script checks the first few pages of each PDF for a text layer. If none is found,
it stops immediately with instructions to run OCR first:

```bash
ocrmypdf input.pdf output.pdf
```

## Dependencies

All available from nixpkgs:

- **pandoc** — primary extractor (EPUB, DOCX, HTML, RTF)
- **poppler_utils** — `pdftotext` for prose PDFs
- **docling** (optional) — Python package for technical PDFs with tables/code. Install
  via `pip install docling` or `uv pip install docling` in a project venv.

No Python is needed for the pandoc/pdftotext path. The script is pure bash.
