#!/usr/bin/env python3
"""Generate an Anki .apkg from a logbook page's '## Card Source' section.

Page format (see advanced-python-literacy.md / micrograd-backpropagation.md):
    ## Card Source
    ### deck: Subdeck Name
    > src: 00:00-08:08 (chapter reference)      <- optional, per-deck footer
    - Q. question text                          <- basic card
    \t- A. answer
    - C. text with {{c1::cloze}} deletions      <- cloze card
    \t- R. reveal/extra text
    \t- T. extra,tags                           <- optional, tab-child of a card

GUIDs are content-hashed from (subdeck :: question) so answer edits update in
place while question edits start fresh scheduling. Run with a python that has
genanki installed.

Usage: gen_srs_apkg.py PAGE.md OUTPUT.apkg [--deck "Top Deck Name"]
"""
import hashlib
import re
import sys

import genanki

BASIC_MODEL_ID = 1724916801  # do not change — stable model IDs keep imports clean
CLOZE_MODEL_ID = 1724916802

CSS = """
.card { font-family: -apple-system, 'Segoe UI', Roboto, sans-serif; font-size: 18px;
        text-align: left; color: #1a1a1a; background-color: #fdfdfd; padding: 16px; }
code { background: #f0f0f0; padding: 1px 4px; border-radius: 3px; font-size: 0.9em; }
hr { border: none; border-top: 1px solid #ddd; margin-top: 12px; }
.src { color: #888; font-size: 13px; margin-top: 10px; }
"""

BASIC_MODEL = genanki.Model(
    BASIC_MODEL_ID, "srs-basic",
    fields=[{"name": "Question"}, {"name": "Answer"}, {"name": "Src"}],
    templates=[{
        "name": "Card 1",
        "qfmt": "{{Question}}",
        "afmt": '{{FrontSide}}<hr id="answer">{{Answer}}<div class="src">{{Src}}</div>',
    }],
    css=CSS)

CLOZE_MODEL = genanki.Model(
    CLOZE_MODEL_ID, "srs-cloze",
    model_type=genanki.Model.CLOZE,
    fields=[{"name": "Text"}, {"name": "Extra"}, {"name": "Src"}],
    templates=[{
        "name": "Cloze",
        "qfmt": "{{cloze:Text}}",
        "afmt": '{{cloze:Text}}<hr id="answer">{{Extra}}<div class="src">{{Src}}</div>',
    }],
    css=CSS)


def parse(page_path, top_deck):
    """Yield (subdeck_full_name, kind, fields, tags) tuples from Card Source."""
    lines = open(page_path, encoding="utf-8").read().splitlines()
    in_source, subdeck, deck_src = False, None, ""
    card, kind = None, None
    cards = []

    def flush():
        nonlocal card, kind
        if card is not None:
            cards.append((subdeck, kind, card))
        card, kind = None, None

    for line in lines:
        if line.startswith("## Card Source"):
            in_source = True
            continue
        if not in_source:
            continue
        m = re.match(r"^### deck: (.+)$", line)
        if m:
            flush()
            subdeck = f"{top_deck}::{m.group(1).strip()}"
            deck_src = ""
            continue
        m = re.match(r"^> src: (.+)$", line)
        if m:
            deck_src = m.group(1).strip()
            continue
        m = re.match(r"^- ([QC])\. (.*)$", line)
        if m:
            flush()
            kind = m.group(1)
            card = {"q": m.group(2).strip(), "a": "", "tags": [], "src": deck_src}
            continue
        if card is not None:
            m = re.match(r"^\t- ([ART])\. (.*)$", line)
            if m:
                f, val = m.group(1), m.group(2).strip()
                if f == "T":
                    card["tags"] += [t.strip() for t in val.split(",") if t.strip()]
                elif f in ("A", "R"):
                    card["a"] = (card["a"] + "\n" + val).strip() if card["a"] else val
                continue
            if line.strip() == "":
                continue
            flush()
    flush()
    return cards


def main():
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    page_path, out_path = sys.argv[1], sys.argv[2]
    top_deck = "Anki Deck"
    if "--deck" in sys.argv:
        top_deck = sys.argv[sys.argv.index("--deck") + 1]
    else:  # fall back to the page's H1
        for line in open(page_path, encoding="utf-8"):
            if line.startswith("# "):
                top_deck = line[2:].strip()
                break

    cards = parse(page_path, top_deck)
    if not cards:
        sys.exit("no cards parsed — is the '## Card Source' section present?")

    decks = {}
    for subdeck, kind, c in cards:
        deck = decks.setdefault(
            subdeck,
            genanki.Deck(deck_id=int(hashlib.sha1(subdeck.encode()).hexdigest()[:8], 16),
                         name=subdeck))
        guid_key = f"{subdeck}::{c['q']}"
        tags = [top_deck.replace(" ", "_")] + c["tags"]
        if kind == "Q":
            note = genanki.Note(
                BASIC_MODEL, fields=[c["q"], c["a"], c["src"]],
                guid=genanki.guid_for(guid_key), tags=tags)
        else:
            note = genanki.Note(
                CLOZE_MODEL, fields=[c["q"], c["a"], c["src"]],
                guid=genanki.guid_for(guid_key), tags=tags)
        deck.add_note(note)

    genanki.Package(list(decks.values())).write_to_file(out_path)
    n_by_deck = {k: len(d.notes) for k, d in decks.items()}
    print(f"wrote {out_path}: {sum(n_by_deck.values())} cards in {len(decks)} subdecks")
    for k, n in n_by_deck.items():
        print(f"  {n:3d}  {k}")


if __name__ == "__main__":
    main()
