---
name: creating-srs-cards
description: >
  Create spaced repetition flashcards from resources (documentation, books, notes,
  papers) for export to Anki via logseq-anki-sync. Applies the EAT 2.0 framework
  (Encoded, Atomic, Timeless), deep Ankification for complex topics, and research-backed
  card design principles. Outputs Logseq-formatted blocks ready for sync.
  Use when the user asks to create flashcards, Anki cards, SRS cards, or wants to
  memorize/ankify content from notes, papers, or documentation.
metadata:
  hermes:
    related_skills: [logseq, pandoc]
---

# Creating SRS Flashcards

Creates spaced repetition flashcards using logseq-anki-sync syntax, grounded in
cognitive science (see `references/cognitive-science-foundation.md` for full theory).

## Invocation Workflow

When asked to create flashcards from source material:

1. **Identify input**: accept raw text, file path, URL, or Logseq page reference
2. **Extract learnable facts**: scan for definitions, relationships, procedures,
   claims, and conceptual distinctions
3. **Apply card-type decision tree** (Rule 4) to each fact
4. **Write Logseq-formatted blocks** following syntax rules below
5. **Quick quality gate** each card: atomic? self-sufficient? no interference?
6. **Group by topic** with appropriate tags and deck assignments

If the input is a paper or book, apply the reading workflow (shallow or deep)
before card creation. For PDFs/epubs, convert to markdown first (see `pandoc` skill).

Minimum 5 cards per topic, or skip entirely (orphan clusters are worse than zero cards).

## The 5 Golden Rules

### Rule 1: Atomicity (1NF)

Each card tests exactly ONE discrete fact.

**Test**: If the answer contains "and", "or", or a list of 3+ items, it likely violates atomicity. Lists of 2-3 related items may use Q&A or `#incremental`; lists of 4+ should be split into separate cards.

**Exception** — when "and" unifies a single concept:
```markdown
Why do both Python decorators and context managers use wrapper patterns? #card
	- Tests understanding of a shared design principle, not two separate facts
```

**Decision heuristic**: Does the "and" connect two independent facts, or frame a comparison/relationship that is itself the learning objective?

### Rule 2: Contextual Self-Sufficiency (2NF)

The question contains all necessary context to be answered in isolation.
- Explicit domain when terms are ambiguous: "In Python...", "In Cell Biology..."
- No pronouns that require external context

**Pronoun nuances**:
- Bad (ambiguous): "What does it return?", "Why did this happen?"
- Fine (pronoun IS the subject): "What does `this` refer to in a JavaScript arrow function?"

### Rule 3: Interference Inhibition

For similar concepts, generate Comparison Cards.

**Trigger**: Source text discusses concepts that could be confused.

**Format**: "Distinguish between X and Y regarding Z."

```markdown
Distinguish between Mitosis and Meiosis regarding daughter cell genetics. #card
	- Mitosis = Genetically Identical (Diploid)
	- Meiosis = Genetically Unique (Haploid)
```

### Rule 4: Cloze vs Q&A Selection

| Card Type | Use When | Example |
|-----------|----------|---------|
| **Cloze** | Atomic facts, syntax, exact wording | `print('Hello') is valid syntax in {{Python 3}}` |
| **Q&A** | Reasoning, "why"/"how" questions | "Why does Python 3 require parentheses for print?" |
| **Comparison** | Confusable concepts | "Distinguish between TCP and UDP regarding reliability" |
| **Swift Arrow** | Structured multi-attribute lookups (e.g., disease → symptoms/pathogen/treatment) where each attribute is independently testable | `Tuberculosis \n\t- Description :-> ...` |

**Cloze risk**: Shallow pattern matching — memorizing sentence shape instead of the fact.

**Mitigation**: Create separate cards for each retrieval direction of an important fact. Each card below tests a *different* fact (entity, output, mechanism) — they are not interchangeable "variations" of one card:

```markdown
{{c1::Mitochondria}} produce ATP.
```
```markdown
Mitochondria produce {{c1::ATP}}.
```
```markdown
Mitochondria produce ATP via {{c1::cellular respiration}}.
```

Each is its own Logseq block. Together they ensure you can retrieve the fact from any direction, preventing shallow pattern matching on sentence shape.

**Decision Tree**:
```
Is the learning objective a specific fact, syntax, or exact wording?
├─ Yes → Use Cloze (watch for pattern-matching risk)
└─ No  → Is it a "why" or "how" question requiring reasoning?
         ├─ Yes → Use Q&A
         └─ No  → Is it a comparison between similar concepts?
                  ├─ Yes → Use Comparison Card
                  └─ No  → Is it a structured multi-attribute lookup (entity → N attributes)?
                           ├─ Yes → Use Swift Arrow (`:->`)
                           └─ No  → Default to Q&A
```

**Syntax red flags** — catch these while writing:
- More than 3 `{{c` cloze deletions in one block → split into multiple cards
- Cloze syntax inside fenced code blocks → braces conflict; use Q&A
- `{{c1::...}}` AND `:->` on same line → pick one format
- `#card` tag on a line with cloze syntax → remove `#card` (clozes auto-generate)
- List of 5+ items clozed together → use `#incremental` or split

### Rule 5: Hierarchical Tagging

Tags are cognitive scaffolding, not just organization.

**Structure**:
- **Hierarchy** (the "where"): `Domain::Subdomain::Topic`
- **Facet** (the "what"): `Fact`, `Concept`, `Procedure`, `Principle`, `Visual`

```markdown
tags:: medicine::cardiology::pharmacology, type::procedure
```

| Facet | Definition | Retrieval Mode |
|-------|------------|----------------|
| `Fact` | Discrete data (dates, constants, names) | Rote recall |
| `Concept` | Abstract definitions, theories | Semantic reconstruction |
| `Procedure` | Algorithms, "how-to" steps | Procedural memory |
| `Principle` | Heuristics, laws, mental models | Application logic |
| `Visual` | Diagrams, anatomy | Visuospatial processing |

---

## EAT 2.0 Quick Reference

### Encoded → Elaborative Encoding

Context should link to related concepts, explain *why it matters*, and provide the "hook":

```markdown
Why does Python 3 require parentheses for print()? #card
	- print() is a function in Python 3, not a statement
	- Python 2's "print x" was a special language statement
	- This matters because it makes print composable — you can
	  pass it to map(), use it in comprehensions, and extend with
	  keyword arguments, unlike Python 2's statement form
```

### Atomic → Database Normalization

- **1NF**: One fact per card. Split lists into separate cards.
- **2NF**: Answer depends fully on the question — all context present.
- **3NF**: No shortcut hints that allow deducing without retrieval.

### Timeless → Interference Management

When concepts could be confused, create comparison cards that encode the *difference* as a primary feature.

---

## Deep Ankification (Complex Topics)

For theorems, algorithms, proofs, and complex systems. Based on Nielsen's deep Ankification process.

### Phase I: Understanding

1. **Grazing** — pick out single elements, convert to cards. Multiple passes.
2. **Restate ideas in multiple ways** — geometric, verbal, visual.
3. **Explore minor variations** — what happens at boundaries? If assumptions change?
4. **Aspirational distillation cards** — boundary conditions to aim for.
5. **Build a hierarchy**: atomic facts → integrative cards → high-level conceptual cards.

```markdown
In one sentence, what is the core reason quicksort averages O(n log n)? #card
	- Each partition divides elements ~in half, creating a balanced
	  recursion tree of depth log n with n work per level
```

### Phase II: Pushing Boundaries

Change assumptions and ask how the result breaks or generalizes:

```markdown
Why does the proof that quicksort is O(n log n) average fail in the worst case? #card
	- A sorted input causes each partition to produce a 0/n-1 split,
	  creating a degenerate tree of depth n → O(n²)
```

Edge cases, weakened conditions, generalizations — open-ended. The further you go and the more connections you make to other results, the better.

### Key Principles

- **Phases are interleaved in practice** — pushing boundaries (Phase II) often reveals gaps in understanding that send you back to Phase I. The phases describe complementary modes of engagement, not a strict sequence.
- Think of proofs/algorithms as **networks of simple observations**, not linear lists
- **Multiple explanations** give improved understanding and intuition
- Atomic doesn't mean simple — "What is the amortized cost of HashMap.put()?" assumes sophisticated background but is a single, clearly scoped question
- **The 200 words problem**: struggling with complex issues often means missing basic terminology — Nielsen describes this as lacking the ~200 domain vocabulary words needed to make technical reading tractable. Card the foundational terms first, then return to the complex material.

### Answer Length

Answers should be 1-3 lines — concise enough for binary self-rating ("did I know this?"),
complete enough to not require re-reading the source. If you need a paragraph, the card
is probably testing too much: split it.

### Leeches and Review

A "leech" is a card the learner keeps failing. Leeches indicate **card design problems,
not memory problems**. When a card has been failed repeatedly:

1. **Rewrite** the card — split it, rephrase the question, or add context
2. **Check for interference** — is a similar card causing confusion?
3. **Mnemonic reinforcement** — encode with a vivid personal association,
   visual image, or memory palace hook. Wozniak's Rules 10-12 emphasize
   personalization and imagery as powerful encoding tools.
4. **Consider suspension** — if the fact isn't worth the rewrite effort, suspend it

Do NOT just re-review a leech unchanged. The SRS algorithm assumes the card is
well-formed; a badly designed card degrades scheduling for everything.

---

## Reading Workflows

### The 10-Minute Rule

If memorizing a fact seems worth ~10 minutes of future time, card it. If something seems striking, card it regardless.

### Minimum 5 Questions Per Resource

Fewer than 5 creates an orphan cluster with no context. If you can't find 5 good questions, add zero.

### Deep Reading (Papers)

1. **Passes 1-6**: Rapid scanning. Identify key technique names, basic facts from abstract, intro, conclusion, figures, captions. For papers < 10 pages or when the learner already has domain familiarity, 1-2 passes suffice. The 5-6 pass approach is for dense, unfamiliar material — Nielsen describes this as an emergent behavior he noticed in himself, not a mandatory protocol.
2. **Thorough read**: After sufficient passes, background context makes deep reading tractable.
3. **Second thorough pass**: More falls into place. Questions approach research directions.

### Shallow Reading (10-60 min)

- Extract 5-20 questions on core claims and ideas
- **Ankify figures**: "Visualize the graph of X" — knowing the broad shape is valuable
- Practice deliberate switching — completionism is a failure mode

### Ankify Claims, Not Facts

Attribute claims to sources:
```markdown
What does Jones 2011 claim is the average age at which physics Nobelists
made their prizewinning discovery, over 1980-2011? #card
	- 48
```

---

## logseq-anki-sync Card Syntax

### Cloze Deletion Format

```markdown
The {{c1::derivative}} of sin(x) is {{c2::cos(x)}}.
```

- `{{c1::text}}` through `{{c9::text}}`
- Same number = same card; different numbers = separate cards
- Max 3 cloze deletions per card — split if more needed

**Code/math clozes** (braces conflict) — use Q&A instead.

### Multiline Q&A Format

```markdown
What are the three types of SQL commands? #card
	- Data Definition Language (DDL)
	- Data Manipulation Language (DML)
	- Data Control Language (DCL)
```

**Direction tags**: `#forward`, `#reversed`, `#bidirectional`

**When to create reverse cards**: Create reverse (answer→question) cards for
definitional and mapping knowledge where the relationship works both directions
(e.g., "term ↔ definition", "symbol ↔ meaning"). Skip reverse cards for causal,
sequential, or procedural knowledge where the reverse direction is unnatural
(e.g., don't reverse "Why does X happen? → Because Y" into "What happens because of Y?").

**Incremental cards** (one child per card):
```markdown
SQL command types: #card #incremental
	- DDL - schema operations
	- DML - data operations
	- DCL - permission operations
```

### Swift Arrow Format

```markdown
Tuberculosis
	- Description :-> Potentially serious infectious disease affecting lungs
	- Symptoms :-> chest pain, chronic cough, fatigue, fever
	- Pathogen :-> Mycobacterium tuberculosis
```

### Deck, Tags, and Extra Field

```markdown
What is async/await in JavaScript? #card
deck:: JavaScript/Async
tags:: promises, es2017, type::concept
	- Syntactic sugar over Promises
	- Makes async code look synchronous
extra::
	- Introduced in ES2017
	- await can only be used inside async functions
```

### Inter-Card Linking

Connections between cards are part of Wozniak's knowledge network principle. Use Logseq syntax:

- `[[Page Name]]` — links to a concept page (e.g., `[[async/await]]`, `[[event loop]]`)
- `((block-id))` — references a specific Logseq block (copy block ref via right-click)

```markdown
How does async/await relate to the event loop? #card
tags:: [[event loop]], [[promises]]
	- async functions yield control back to the event loop at each await
	- The event loop resumes the function when the awaited Promise settles
```

Linking satisfies the Connection Quality checklist item: "Does this card connect to at least 2-3 other cards?"

---

## Anti-Patterns

### Card-Level

- **Orphan questions**: Never enter just one question about a topic. Minimum **2-3 cards** for a small cluster, **5+** for a source that merits deeper engagement. Forcing filler cards to hit an arbitrary threshold is itself an anti-pattern — if you can only find 2 good cards, create 2, not 5 mediocre ones.
- **Yes/no pattern**: "Is computing the partition function intractable?" → "For which graphical models is it tractable?"
- **Surface-feature learning**: Same question structure across many cards. Vary forms.
- **Lists > 2-3 items clozed together**: Split or use `#incremental`.
- **Cloze inside code blocks**: Braces conflict; use Q&A.
- **Shortcut hints**: "Large organ that filters blood *and* produces bile" → split.
- **Ambiguous terms without domain**: "What is the nucleus?" → "In Cell Biology..."

### Workflow-Level

- **Speculative stockpiling**: Learning APIs without a project = orphan cards.
- **Fewer than 5 questions from a paper**: Isolated orphan cluster. 5 is the floor
  for topics worth ankifying at all — if you can't find 5 good questions, the source
  doesn't contain enough learnable substance for you; skip it entirely.
- **Ankifying misleading claims as facts**: Always attribute to source.
- **Completionism**: Spending too long on unimportant papers. Practice deliberate switching.
- **Unmindful Ankification of everything**: Especially with books. Slows progress enormously.

### When NOT to Create Cards

Some things are better learned through practice, exploration, or lookup:

- **Frequently changing information** — API parameters, CLI flags, library versions
  (card the concept, not the parameter list)
- **Things you learn through doing** — debugging workflows, editor shortcuts, git rebase
- **Instantly googleable facts** — standard library function signatures, common port numbers
- **Procedural muscle memory** — typing, IDE navigation, keyboard shortcuts

---

## Card Quality Self-Check

Quick gate for every card (3 questions):
1. **Atomic?** — One fact, no ambiguous feedback if partially recalled
2. **Self-sufficient?** — Answerable without seeing surrounding cards
3. **No interference?** — Cue maps one-to-one with the target memory

For deeper review, load `references/quality-checklist.md` for the full 15-item checklist
covering retrieval quality, connection quality, and anti-pattern detection.

---

## Processing Long Documents

For PDFs, epubs, and other binary formats, convert to markdown first (e.g., via `pandoc` — see the `pandoc` skill). Process one section at a time to avoid overwhelming context. Ensure cards from different sections link together (avoid orphan clusters per section).

### Image-Based Cards

When the source contains diagrams, figures, or visual layouts, create cards that test
visual recall: "Sketch the architecture of X", "What does the loss curve of Y look like?",
"Label the parts of Z". These leverage Dual-Coding Theory — visual and verbal memories
reinforce each other. Even knowing the broad shape of a graph or diagram is valuable.

---

## References

- See `references/cognitive-science-foundation.md` for the full cognitive science underpinnings
- See `references/quality-checklist.md` for the full 15-item card quality checklist
- Nielsen, M. — *Augmenting Long-term Memory* (2018)
- Nielsen, M. — *Using SRS to See Through a Piece of Mathematics* (2019)
- Matuschak, A. & Nielsen, M. — *How Can We Develop Transformative Tools for Thought?* (2019)
- Wozniak, P. — *Twenty Rules of Formulating Knowledge*
- Bjork, R.A. — Desirable Difficulties in Learning
- Paivio, A. — Dual-Coding Theory (1971)
