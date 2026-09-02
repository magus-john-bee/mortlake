# Card Quality Checklist

Full 15-item checklist for deep review of card quality. Use when auditing existing
cards or doing a quality pass on a batch. The quick 3-item gate in SKILL.md is
sufficient for normal card creation.

## Atomicity
- [ ] Does this card test exactly one fact?
- [ ] If the answer has multiple parts, should they be separate cards?
- [ ] Would failing one part while knowing others give ambiguous feedback?

## Contextual Self-Sufficiency
- [ ] Could this card be answered without seeing surrounding cards?
- [ ] Are ambiguous terms explicitly scoped? (e.g., "In Python...")
- [ ] Would my future self understand the question without re-reading the source?

## Interference Prevention
- [ ] Are there similar concepts that could be confused with this?
- [ ] If yes, have I created a comparison card?
- [ ] Is the cue specific enough to map one-to-one with the target memory?

## Retrieval Quality
- [ ] Does this card require generative retrieval, not just recognition?
- [ ] Am I testing understanding, not just keyword matching?
- [ ] Have I varied phrasing across related cards to avoid surface-feature learning?

## Connection Quality
- [ ] Does this card connect to at least 2-3 other cards?
- [ ] Is this part of a dense interconnected web, not an isolated node?
- [ ] Have I used `[[page links]]` or `((block-id))` references to make connections explicit?
