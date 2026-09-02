# Cognitive Science Foundation for SRS Card Design

The full theoretical underpinnings behind the card design rules in SKILL.md.

## Why Surface Rules Fail

Old heuristic rules (`len(back) < 30`, "never use 'and'", "must end with '?'") fail because they pattern-match instead of reasoning about quality. The shift: from pattern matching to semantic engineering.

## The Principles That Matter

### Testing Effect (Bjork)

Effortful retrieval strengthens memory traces. Conditions that feel "easy" during study produce poor retention. Reject cards that rely on recognition; require *generative* retrieval.

### Minimum Information Principle (Wozniak)

Complex cards cause ambiguous feedback (recalling 6/7 items — did you "know" it?), interference (forgetting one part fails the whole card), and algorithm degradation (SRS assumes binary memory traces).

### Interference Theory

Old memories block new ones (proactive interference); new memories degrade old ones (retroactive interference). Every card needs a unique "semantic fingerprint" — a cue that maps one-to-one with the target memory.

### Context-Dependent Memory

Cards that depend on surrounding cards become "context-bound" and can't be retrieved in real-world situations. Cards must be contextually self-sufficient.

### Elaborative Encoding

The richer the associations to a concept, the better we remember it. The act of *constructing* a card is itself elaborative encoding.

### Dual-Coding Theory (Paivio)

Verbal and non-verbal information are stored separately. Pictures and words together are recalled substantially better than words alone.

## EAT 2.0 Detailed Framework

### Encoded (Elaborative Encoding)

Context deepens understanding via schema connections, not just reminders. A card's context should:
- Link to related concepts the learner already knows
- Explain *why* the information matters
- Provide the "hook" that makes the fact retrievable

Poor context: copy-pasting the source paragraph without synthesis.

### Atomic (Database Normalization Analogy)

**1NF (One Fact Per Card):** Split lists into separate cards.

**2NF (Contextual Self-Sufficiency):** The answer must depend *fully* on the question, with all necessary context present. Without "In Cell Biology", "nucleus" is ambiguous (atoms, cells, brain).

**3NF (No Shortcut Hints):** Remove "hints" that allow deducing the answer without actual retrieval.

Example of 3NF violation: "Large organ in abdomen that filters blood *and* produces bile" lets the learner bypass "filters blood" via "produces bile" alone — shallow pattern matching.

### Timeless (Interference Management)

When concepts could be confused (Mitosis/Meiosis, TCP/UDP, list/tuple), create comparison cards that encode the *difference* as a primary feature, creating a "boundary" that prevents interference.

## Syntopic Reading for Entire Fields

1. Start with 1 truly important paper → thorough read
2. Thorough reads of the 5-10 best papers, interspersed with shallow reads of tens more
3. Shallow reads identify which papers are important and absorb the "breadth" praxis
4. Outcome: identify open problems, "pregnant" observations, field-wide blind spots

## Creative Project Frame

Anki works far better in service of a creative project (writing, building software, research). Emotional investment makes better questions and deeper internalization. Speculative stockpiling ("I should learn about X") generates cold, lifeless cards.

## The Advanced Features Rabbit Hole

95% of Anki's value comes from basic Q&A and cloze. Chasing plugins/automation leads to quitting.

## Syntax Red Flags

- More than 3 `{{c` in one block → split into multiple cards
- Cloze syntax inside ` ``` ` code block → convert to Q&A
- `{{c1::...}}` AND `:->` on same line → pick one
- `#card` on a line with cloze syntax → remove `#card` (clozes auto-generate)
- List of 5+ items clozed together → use `#incremental` or split
