#!/usr/bin/env bash
# extract.sh — pandoc-first document text extraction
# Usage: extract.sh [--technical|--text] [--check] <file-or-dir> [file2 ...]
# Output: /tmp/extract_work/full_text.txt + metadata.json
set -euo pipefail

# SCRIPT_DIR available for future use; not currently needed
WORKDIR="${EXTRACT_WORKDIR:-/tmp/extract_work}"
MODE="auto"  # auto | technical | text

# ── Helpers ──────────────────────────────────────────────

die() { echo "ERROR: $*" >&2; exit 1; }

have() { command -v "$1" >/dev/null 2>&1; }

est_tokens() {
    # Rough estimate: ~0.75 tokens per word
    local words="$1"
    echo $(( words * 3 / 4 ))
}

# ── Check mode ───────────────────────────────────────────

check_deps() {
    echo "Extractor availability:"
    echo "  pandoc:     $(have pandoc && echo '✓' || echo '✗ (nixpkgs#pandoc)')"
    echo "  pdftotext:  $(have pdftotext && echo '✓' || echo '✗ (nixpkgs#poppler_utils)')"
    echo "  docling:    $(have docling && echo '✓' || echo '✗ (optional: pip install docling)')"
    echo "  ocrmypdf:   $(have ocrmypdf && echo '✓' || echo '✗ (optional: for scanned PDFs)')"
    echo "  ebook-convert: $(have ebook-convert && echo '✓' || echo '✗ (optional: Calibre)')"
    exit 0
}

# ── Format detection ─────────────────────────────────────

get_format() {
    local ext="${1##*.}"
    ext="${ext,,}"  # lowercase
    case "$ext" in
        pdf)         echo "pdf" ;;
        epub)        echo "epub" ;;
        docx)        echo "docx" ;;
        html|htm)    echo "html" ;;
        rtf)         echo "rtf" ;;
        odt)         echo "odt" ;;
        txt)         echo "txt" ;;
        md|markdown) echo "markdown" ;;
        rst)         echo "rst" ;;
        adoc|asciidoc) echo "asciidoc" ;;
        mobi|azw|azw3) echo "ebook" ;;
        *)           echo "unknown" ;;
    esac
}

# ── Extractors ───────────────────────────────────────────

extract_with_pandoc() {
    local input="$1" fmt="$2"
    # Pandoc handles most formats → plain text
    pandoc -f "$fmt" -t plain "$input" 2>/dev/null
}

extract_pdf() {
    local input="$1" fmt="pdf"
    local use_docling=false
    local use_pdftotext=false

    # Decide PDF extractor based on mode
    if [[ "$MODE" == "technical" ]] && have docling; then
        use_docling=true
    elif have pdftotext; then
        use_pdftotext=true
    elif have docling; then
        use_docling=true
    else
        die "No PDF extractor available. Install poppler_utils (pdftotext) or docling."
    fi

    # Check for text layer (scanned PDF detection)
    if have pdftotext; then
        local check
        check=$(pdftotext -f 1 -l 3 "$input" - 2>/dev/null | wc -c)
        if [[ "$check" -lt 50 ]]; then
            die "PDF appears to be scanned (no text layer in first 3 pages). Run OCR first:
  ocrmypdf '$input' output.pdf
Then extract from the OCR'd file."
        fi
    fi

    if $use_docling; then
        echo "[docling] extracting $input" >&2
        python3 -c "
from docling.document_converter import DocumentConverter
import sys
doc = DocumentConverter().convert(sys.argv[1])
print(doc.document.export_to_markdown())
" "$input"
    elif $use_pdftotext; then
        echo "[pdftotext] extracting $input" >&2
        pdftotext -layout "$input" -
    fi
}

extract_ebook_calibre() {
    local input="$1"
    have ebook-convert || die "MOBI/AZW requires Calibre's ebook-convert. Install Calibre."
    local tmp
    tmp=$(mktemp --suffix=.txt)
    ebook-convert "$input" "$tmp" >/dev/null 2>&1
    cat "$tmp"
    rm -f "$tmp"
}

extract_file() {
    local input="$1"
    local fmt
    fmt=$(get_format "$input")

    [[ -f "$input" ]] || die "File not found: $input"

    case "$fmt" in
        pdf)
            extract_pdf "$input"
            ;;
        epub)
            have pandoc || die "EPUB requires pandoc."
            extract_with_pandoc "$input" "epub"
            ;;
        docx)
            have pandoc || die "DOCX requires pandoc."
            extract_with_pandoc "$input" "docx"
            ;;
        html|htm)
            have pandoc || die "HTML requires pandoc."
            extract_with_pandoc "$input" "html"
            ;;
        rtf)
            have pandoc || die "RTF requires pandoc."
            extract_with_pandoc "$input" "rtf"
            ;;
        odt)
            have pandoc || die "ODT requires pandoc."
            extract_with_pandoc "$input" "odt"
            ;;
        txt|markdown|rst|asciidoc)
            # Already text — passthrough
            cat "$input"
            ;;
        ebook)
            extract_ebook_calibre "$input"
            ;;
        unknown)
            die "Unsupported format: $input (extension .${input##*.})"
            ;;
    esac
}

# ── Main ─────────────────────────────────────────────────

main() {
    local files=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --technical) MODE="technical"; shift ;;
            --text)      MODE="text";      shift ;;
            --check)     check_deps        ;;
            -h|--help)
                echo "Usage: extract.sh [--technical|--text] [--check] <file-or-dir> [file2 ...]"
                echo "       --technical  Use docling for PDFs (tables, code blocks)"
                echo "       --text       Use pdftotext for PDFs (fast, prose)"
                echo "       --check      Show extractor availability"
                exit 0
                ;;
            *)
                # Expand directories
                if [[ -d "$1" ]]; then
                    while IFS= read -r -d '' f; do
                        files+=("$f")
                    done < <(find "$1" -maxdepth 3 -type f \
                        \( -name '*.pdf' -o -name '*.epub' -o -name '*.docx' \
                        -o -name '*.html' -o -name '*.htm' -o -name '*.rtf' \
                        -o -name '*.odt' -o -name '*.txt' -o -name '*.md' \
                        -o -name '*.markdown' -o -name '*.rst' -o -name '*.adoc' \
                        -o -name '*.mobi' -o -name '*.azw' -o -name '*.azw3' \) \
                        -print0 2>/dev/null)
                else
                    files+=("$1")
                fi
                shift
                ;;
        esac
    done

    [[ ${#files[@]} -eq 0 ]] && die "No input files. Usage: extract.sh <file-or-dir> [file2 ...]"

    # Check minimum deps
    have pandoc || die "pandoc is required. Install via nixpkgs#pandoc."

    # Prepare workdir
    rm -rf "$WORKDIR"
    mkdir -p "$WORKDIR"

    local sources_json="[]"
    local total_words=0

    echo "Extracting ${#files[@]} source(s)..." >&2

    local full_text="$WORKDIR/full_text.txt"
    : > "$full_text"  # truncate

    for file in "${files[@]}"; do
        if [[ ! -f "$file" ]]; then
            echo "WARN: skipping $file (not found)" >&2
            continue
        fi

        local fmt
        fmt=$(get_format "$file")
        local extractor=""

        echo "--- SOURCE: $(basename "$file") ---" >> "$full_text"
        echo "" >> "$full_text"

        case "$fmt" in
            txt|markdown|rst|asciidoc)
                extractor="passthrough"
                ;;
            pdf)
                if [[ "$MODE" == "technical" ]] && have docling; then
                    extractor="docling"
                elif have pdftotext; then
                    extractor="pdftotext"
                elif have docling; then
                    extractor="docling"
                else
                    echo "WARN: skipping $file (no PDF extractor)" >&2
                    continue
                fi
                ;;
            epub|docx|html|rtf|odt)
                extractor="pandoc"
                ;;
            ebook)
                extractor="ebook-convert"
                ;;
        esac

        local tmp_out
        tmp_out=$(mktemp)
        if extract_file "$file" > "$tmp_out" 2>/dev/null; then
            cat "$tmp_out" >> "$full_text"
            echo "" >> "$full_text"

            local words
            words=$(wc -w < "$tmp_out" | tr -d ' ')
            total_words=$((total_words + words))
            local tokens
            tokens=$(est_tokens "$words")

            sources_json=$(python3 -c "
import json
s = json.loads('''$sources_json''')
s.append({
    'file': '$(basename "$file")',
    'path': '$file',
    'format': '$fmt',
    'extractor': '$extractor',
    'words': $words,
    'estimated_tokens': $tokens
})
print(json.dumps(s))
" 2>/dev/null || echo "$sources_json")
        else
            echo "WARN: extraction failed for $file" >&2
        fi
        rm -f "$tmp_out"
    done

    local total_tokens
    total_tokens=$(est_tokens "$total_words")

    # Write metadata
    python3 -c "
import json, os
meta = {
    'total_sources': ${#files[@]},
    'total_words': $total_words,
    'estimated_tokens': $total_tokens,
    'sources': json.loads('''$sources_json''')
}
with open(os.path.join('$WORKDIR', 'metadata.json'), 'w') as f:
    json.dump(meta, f, indent=2)
" 2>/dev/null || {
        # Fallback if python3 is somehow missing
        echo "{\"total_sources\": ${#files[@]}, \"total_words\": $total_words}" > "$WORKDIR/metadata.json"
    }

    echo "" >&2
    echo "Done. Output:" >&2
    echo "  $WORKDIR/full_text.txt   ($(wc -w < "$full_text" | tr -d ' ') words)" >&2
    echo "  $WORKDIR/metadata.json" >&2
}

main "$@"
