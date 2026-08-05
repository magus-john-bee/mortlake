---
name: skill-crafting
description: >
  Design, build, test, and maintain reusable skills for Hermes Agent. Use when
  creating a new skill, revising an existing one, auditing your skill ecosystem,
  or establishing eval criteria for a skill under development.
version: 1.0.0
license: MIT
metadata:
  hermes:
    tags: [skill-authoring, skill-design, skill-testing, skill-maintenance]
    related_skills:
      - subagent-driven-development
      - writing-plans
      - systematic-debugging
      - requesting-code-review
---

# Skill Crafting

Design, build, test, and maintain reusable skills. This skill covers strategy,
structure, red-green eval loops, and lifecycle management — not the mechanics
of the `skill_manage` tool (which is the execution layer).

## When to Create a Skill

Create a skill when you have **procedural knowledge that should be reusable across sessions** and is not adequately captured by:
- A single memory note (ephemeral facts)
- An existing skill (check before creating)
- Inline instructions (one-off tasks)

| Case | Example | Right choice |
|------|---------|--------------|
| Team workflow conventions | PR author must not push to main | **Skill** — static, needs consistent enforcement |
| Multi-step process with branches | TDD cycle, debugging protocol | **Skill** — repeatable procedure |
| Quality criteria | "Distinctive, production-grade" | **Skill** — judgment criteria |
| API patterns | Specific SDK version, model IDs | **Skill** — domain knowledge |
| One-off investigation | A specific repo's structure | **Memory/hindsight** — not reusable |

Do NOT create a skill for:
- Trivial one-liner fixes
- Repo-specific facts with no transfer value
- Workflows already covered by existing skills

**Rule of thumb:** If you've given the same instruction to yourself 3+ times across sessions, it belongs in a skill.

---

## Strategy: The 12 Design Principles

Ground your skill in these evidence-based principles before writing a single line.

### 1. Optimize for activation accuracy

The `description` field is the routing signal — it determines whether the skill triggers at all.
A vague description means the skill silently fails to activate or over-triggers on every request.

- Write descriptions for **routing, not marketing**. State the job, likely trigger phrases, and nearby non-goals.
- Add explicit "Use this when" and "Do not use this when" when adjacent skills share semantic territory.
- Test activation against sibling skill descriptions to ensure the signal is unambiguous.

### 2. One skill, one workflow

Single-responsibility skills are easier to route, follow, and maintain.
Multi-mode skills with conditional branching create exactly the instruction composition
patterns that models handle worst.

- ComplexBench (NeurIPS 2024): nested compositions drop to **0.083 accuracy** vs **0.881** for flat.
- Split skills when they have materially different triggers, outputs, or decision rules.
- Accept structural duplication between similar skills until there are at least **three real consumers** of the shared structure.

### 3. Keep context lean

Context is a finite resource. Reasoning accuracy drops from **0.92 to 0.68** as input grows
from ~250 to ~3,000 tokens (ACL 2024 "Same Task, More Tokens"). Even a single distractor
degrades performance ("Context Rot", Chroma Research 2025).

- Target **150–300 lines** for most skills. 500 lines is the hard backstop.
- Every token that doesn't change behavior is actively harmful.
- Remove repeated rationale, decorative prose, and edge cases that don't change behavior.

### 4. Put critical instructions early

Universal primacy effect: later instructions have higher error rates.
All 20 models tested in IFScale show higher error rates for later instructions.

- Put **mission, defaults, required artifacts, hard constraints, and human checkpoint rules near the top**.
- Rules that block execution should not first appear in Phase 6.
- Put **guardrails and final-handoff instructions at the end** to benefit from recency.

### 5. Prefer explicit contracts over vague prose

Models follow verifiable constraints better than inferred implications.

- Name required artifacts, filenames, report headings, and stop conditions **explicitly**.
- "Always use `interactions.create()`" outperforms "The Interactions API is the recommended approach."
- Use `If X is missing, stop and report Y` over `Handle missing inputs appropriately`.

### 6. Use progressive disclosure

The skill body (SKILL.md) should be a **control plane**, not an encyclopedia.
Move depth into `scripts/`, `references/`, and `examples/` directories.

- The model should be able to start executing from SKILL.md alone.
- Load additional context only when a specific phase requires it.
- Keep delegation shallow — a top-level skill should usually call leaf skills, not build a three-layer wrapper stack.

### 7. Use scripts only when deterministic execution beats prose

- Use scripts for **parsing, validation, formatting, scaffolding** — mechanical tasks easier to run than describe.
- Do NOT hide core judgment or routing logic inside scripts.
- If a script is required, specify **exactly when to run it, what inputs it needs, and what outputs count as success**.
- Never require interactive input from a script in an autonomous skill workflow.

### 8. Design human checkpoints narrowly

"Ask when uncertain" is too broad and adds constraint load on every action.

- **Name the exact ambiguity trigger** that requires human input: "ask before creating a missing memory file," not "ask when uncertain."
- Keep the normal path autonomous.
- Limit the number of distinct checkpoint conditions — each competes with workflow instructions for attention.

### 9. Make the workflow measurable from day one

Without measurable criteria, you can't iterate and you can't detect regressions.

- Give every skill a **checkable definition of done**.
- Separate **outcome goals** (did it work?), **process goals** (did it follow the workflow?), and **style goals** (does it match conventions?).
- Make artifact paths and output formats explicit so evaluation harnesses can inspect them.
- Design at least one **positive-trigger** and one **negative-trigger** prompt for activation evaluation.

### 10. Treat skills as privileged instructions

Skills influence planning, tool usage, and command execution. A skill that claims certain
permissions or behaviors will be followed as written — the model does not independently
verify whether the claims are legitimate.

- Never assume network access, elevated permissions, or non-standard tools without stating so.
- Require explicit approval for sensitive or high-impact actions.
- Review skills with the **same rigor as code reviews**.

### 11. Manage context budget across the skill lifecycle

Skills load into a context window that already contains system prompts, conversation history,
tool results, and potentially other skills. The effective budget for any single skill is
a fraction of the total.

- Design skills to be **context-efficient**: produce explicit artifacts (files) rather than relying on the model remembering long intermediate outputs.
- When a skill delegates to sub-agents, expect summaries (**1,000–2,000 tokens**) rather than full transcripts.
- Be aware that a 300-line skill loaded after 180K tokens of prior conversation is competing for the model's remaining attention.

### 12. Design for error recovery and convergence

Agent workflows fail. Skills should be designed so failures are recoverable, progress is visible,
and the workflow converges toward completion rather than looping indefinitely.

- Define **convergence criteria** for iterative workflows. State what "done" looks like and what triggers re-iteration vs. escalation.
- Require **observable outputs at each phase transition**.
- Set explicit **loop limits or escalation triggers** to prevent infinite loops.

---

## Recommended Skill Structure

This section order is designed for reliable agent execution, informed by primacy and recency effects:

| Section | Purpose | Position rationale |
|---------|---------|-------------------|
| Frontmatter | Routing metadata (name, description, category) | Loaded before body; determines activation and grouping |
| Opening contract | One-sentence statement of what the skill does | Immediate orientation |
| Defaults / inputs | No-input behavior and accepted inputs | Prevents silent guessing |
| Required artifacts | Named file paths and report outputs | Makes workflow inspectable |
| Multi-agent pattern | Recommended reviewer/worker roles | Encourages shallow, explicit delegation |
| Global constraints | Hard rules that always apply | Benefit from primacy effect |
| Human checkpoints | Exact ask-user triggers | Keeps escalation explicit and rare |
| Workflow phases | Ordered execution steps | Main operational body |
| Guardrails | Common failure modes and negative constraints | Benefits from recency effect |
| Final handoff | What to report back | Keeps closeout deterministic |

**Ordering rules:**
- Put routing, defaults, artifacts, and hard constraints **before** the phased workflow.
- Put explanations and examples after the contract, or move them out of SKILL.md entirely.
- Put guardrails and final-handoff instructions **last**.
- Do NOT place new critical rules in the middle of the workflow phases ("lost in the middle" effect).

---

## Assessment: The 6-Dimension Rubric

Score each skill run across these dimensions (0–3 each; max 18):

| Dimension | What it measures | How to score |
|-----------|-----------------|--------------|
| **Task completion** | Did the skill produce a usable result? | Binary: output works or it doesn't |
| **Activation accuracy** | Did the skill trigger when it should / not trigger when it shouldn't? | Check positive and negative trigger tests |
| **Process compliance** | Did it follow the workflow steps in order? | Trace the execution path |
| **Style conformance** | Does output match your conventions and the skill's directives? | Regex checks or LLM-as-judge |
| **Efficiency** | Token count, command thrashing, unnecessary retries | Measure resources used |
| **Error recovery** | Did failures lead to convergence or infinite loops? | Check loop limits and escalation triggers |

Score distribution guidance:
- **15–18**: Excellent — ship it
- **10–14**: Good — fix the gaps before shipping
- **5–9**: Needs significant work — review design principles
- **0–4**: Rewrite from scratch

---

## Red-Green Testing with Subagents

Apply the two-stage review pattern from `subagent-driven-development` to skill authoring:

### Stage 1: Red — Write the failing eval

Before writing the skill body, write the eval prompts and checks. This forces you to
define "success" before you define the procedure.

```
1. Create a prompt set (10–20 prompts)
   - Each prompt declares its own success criteria
   - Include negative trigger tests (skill should NOT activate)
   - Include edge cases drawn from real usage

2. For each test case, define expected_checks
   - Deterministic: regex, file existence, API name
   - Qualitative: requires LLM-as-judge

3. Run the agent with the skill loaded, capture output
```

### Stage 2: Green — Write the skill to pass

Now write the skill body, using eval failures as the iteration signal.

```
For each failing test:
  - Identify which design principle was violated
  - Fix the description (usually the highest-leverage change)
  - Or fix the body (add missing directive, remove noise)
  - Re-run eval
  - Repeat until green
```

### The Eval Harness

```python
# Pseudocode — implement in execute_code or terminal scripts

CHECK_REGISTRY = {
    "correct_sdk":       lambda code: bool(re.search(r"from google import genai", code)),
    "current_model":     lambda code: not any(m in code for m in DEPRECATED_MODELS),
    "interactions_api":  lambda code: "interactions.create" in code,
    "no_old_sdk":        lambda code: "generateContent" not in code,
}

def run_eval(test_case):
    output = run_agent_cli(test_case["prompt"])
    code = extract_code_blocks(output.response_text)
    results = {}
    for check_id in test_case["expected_checks"]:
        results[check_id] = CHECK_REGISTRY[check_id](code)
    return results
```

### When to use LLM-as-judge vs. deterministic checks

| Use deterministic checks | Use LLM-as-judge |
|------------------------|-------------------|
| SDK versions, API names | Code structure quality |
| File paths, command flags | Naming conventions |
| Deprecated model detection | Design pattern adherence |
| Output format compliance | "Distinctive, production-grade" judgments |

LLM-as-judge is slow and expensive. Use it selectively. Most skill criteria are checkable with regex.

---

## The Iteration Loop

```
┌─────────────────────────────────────────────────────┐
│  1. Define success criteria (before writing)         │
│     → Write the eval prompts and checks first       │
└─────────────────┬───────────────────────────────────┘
                  ▼
┌─────────────────────────────────────────────────────┐
│  2. Write initial skill body                         │
│     → Follow the 12 design principles               │
└─────────────────┬───────────────────────────────────┘
                  ▼
┌─────────────────────────────────────────────────────┐
│  3. Run eval suite → get red results                 │
│     → Multiple trials (3–5x per prompt)               │
│     → Report distribution, not single binary         │
└─────────────────┬───────────────────────────────────┘
                  ▼
┌─────────────────────────────────────────────────────┐
│  4. Fix the skill (highest-leverage first)           │
│     → Rewrite description usually wins               │
│     → Then tighten body directives                  │
└─────────────────┬───────────────────────────────────┘
                  ▼
┌─────────────────────────────────────────────────────┐
│  5. Re-run eval → green                              │
│     → When eval hits ~100%, graduate to regression   │
└─────────────────────────────────────────────────────┘
```

**The single highest-leverage action:** rewriting the description. philschmid reported
that description changes alone fixed 5 of 7 failures in a real skill.

---

## Negative Trigger Tests

A skill with too-broad description will trigger on every request. Test that it **does not activate** for:

- Unrelated task domains
- Tasks already handled by sibling skills
- Edge cases outside the skill's scope

Example:
```json
{
  "id": "negative_csv",
  "prompt": "Write a Python script that reads a CSV and plots a bar chart.",
  "should_trigger": false,
  "expected_checks": []
}
```

If the skill triggers on this, the description is too broad.

---

## Skill Retirement

Run the eval suite **without** the skill loaded. If tests still pass, the model has
absorbed the skill's value — retire the skill. This prevents your ecosystem from
accumulating stale skills that no longer add value.

---

## Lifecycle Management

| Measure | Method |
|---------|--------|
| Specify owner | List responsibility owner in `owner` field |
| Last review date | Regularly update `last_reviewed` |
| Review cycle | Quarterly review recommended |
| Operational alignment | Verify consistency with actual workflows |

Skills should follow a continuous improvement cycle: **Create → Use → Eval → Revise → Retire**.

---

## Deleting Installed Skills

Skills installed via `hermes skills install` (Nix store copies) have read-only
permissions (`dr-xr-x-r-x`). Direct `rm -rf` will fail with permission denied.

```
# Fix: chmod before rm
chmod -R u+w /path/to/skill-dir
rm -rf /path/to/skill-dir

# Bulk cleanup (e.g. all .bak dirs)
find /var/lib/hermes/.hermes/skills -name '*.bak' -type d -exec chmod -R u+w {} +
find /var/lib/hermes/.hermes/skills -name '*.bak' -type d -exec rm -rf {} +
```

Spot these by the `Jan 1 1970` timestamp and `dr-xr-x` permissions in `ls -la`.

---

## Anti-Patterns

| Anti-pattern | Why it fails | Better pattern |
|-------------|--------------|----------------|
| Vague description like "Helps with PDFs" | Weak routing signal | Describe job + trigger conditions + non-goals |
| Multi-mode skill with major branches | Increases instruction count and interference | Split into separate skills |
| Critical rule buried late in the file | Later instructions are easier to drop | Move invariants near the top |
| **Assuming a skill exists because it is referenced** | Job specs, hub cache, and manifests can reference skills that were never installed; this leads to silent failures or phantom diffs | Always verify on disk (`skills_list`, `find`, `skill_view`) before depending on a skill's presence |
| Laundry list of edge cases in SKILL.md | Bloats context and dilutes core instructions | Keep only canonical cases; move rest to references/ |
| Interactive script | Hangs or fails in autonomous runs | Make scripts fully flag-driven with --help |
| Core behavior hidden in companion files | Breaks on clients that only load SKILL.md | Keep main workflow understandable from SKILL.md alone |
| Shared base-skill wrapper hierarchy | Creates fragile abstractions and drift | Accept structural duplication until reuse is clearly real |
| Untestable definition of done | Hard to evaluate or regress | Add explicit artifacts, commands, or rubric outputs |
| Blanket permission expansion | Conflicts with least-privilege policy | Ask for approval at named high-impact steps |
| Accumulating intermediate results in context | Depletes attention budget for later instructions | Write intermediates to files; reference by path |
| Generic "ask when uncertain" checkpoint | Model interprets on every action | Name exact trigger conditions |

---

## Authoring Checklist

Before considering a skill done, verify:

- [ ] The description clearly says what the skill does and when it should trigger
- [ ] The skill has one primary job and one primary output contract
- [ ] The top of the file contains defaults, artifact rules, and hard stop conditions
- [ ] Every required file or report path is explicit
- [ ] Human checkpoints are concrete and sparse
- [ ] The workflow has measurable success criteria
- [ ] Any required script is non-interactive and documented with inputs/outputs
- [ ] The skill still makes sense if a client only loads SKILL.md
- [ ] The body is as short as possible without making behavior ambiguous
- [ ] At least one positive-trigger and one negative-trigger prompt exist for evaluation
- [ ] Guardrails and negative constraints appear at the end, not buried in the middle
- [ ] The skill's context footprint is proportional to its complexity
- [ ] You've run the eval suite and achieved green (or documented acceptable gaps)

---

## Key Research Thresholds

| Metric | Value | Source |
|--------|-------|--------|
| Reasoning accuracy drop onset | ~500 tokens of input growth | "Same Task, More Tokens", ACL 2024 |
| Aggregate accuracy decline (250→3K tokens) | 0.92 → 0.68 (24pp) | "Same Task, More Tokens" |
| Best frontier model accuracy at 500 instructions | 68.9% | IFScale 2025 |
| Primacy effect peak density | 150–200 instructions | IFScale 2025 |
| Flat AND constraint composition (GPT-4) | 0.881 | ComplexBench, NeurIPS 2024 |
| Nested multi-layer composition (GPT-4) | 0.083–0.694 | ComplexBench |
| Catalog token cost per skill | ~50–100 tokens | Agent Skills spec |
| Full skill instruction budget | <5,000 tokens | Agent Skills spec |
| Recommended skill body length | 150–300 lines | Agent Layer synthesis |
| Hard backstop | 500 lines | Agent Skills spec |

---

## Two-Tier Skill Directory Architecture

On NixOS hosts managed by corpus, skills live in two locations with different write semantics:

| Location | Write access | Discovery | What lives there |
|----------|-------------|-----------|-----------------|
| `/var/lib/hermes/.hermes/skills/` | Hermes agent (auto-creates, hub installs) | Hermes: primary skills dir. Codex: via `~/.codex/skills` symlink | Hub/bundled/community skills + agent-created skills |
| `/home/john/src/corpus/agent-skills/` | User-directed only (commits to corpus) | Hermes: via `external_dirs` in config. Codex: via `.agents/skills` symlink at repo root | Custom skills versioned with infrastructure config |

**Hermes config** (in `modules/features/hermes.nix`):
```nix
skills = {
  config.wiki.path = "/home/john/vault/book-of-thoth";
  external_dirs = [ "/home/john/src/corpus/agent-skills" ];
};
```

**Codex discovery** (in `modules/features/codex-server.nix`):
- `~/.codex/skills` symlinks to `/var/lib/hermes/.hermes/skills` (hermes-managed skills)
- `/home/john/src/corpus/.agents/skills` symlinks to `/home/john/src/corpus/agent-skills` (corpus skills, REPO scope)
- The `.agents/` dir is gitignored — it's a runtime symlink created by tmpfiles.d, not tracked in git

**Key behaviors:**
- `external_dirs` are read-only for Hermes — agent-created skills always land in the primary skills home
- Local (primary dir) skills take precedence on name collision with `external_dirs`
- Non-existent `external_dirs` paths are silently skipped
- Codex REPO scope scans `.agents/skills` from CWD up to repo root, so corpus skills are found when working inside any subdirectory of corpus

**When deciding where to put a skill:**
- Hub-installed, community, or agent-auto-created → primary dir (`/var/lib/hermes/.hermes/skills/`)
- User-written, versioned with infra config, shared across agents → corpus (`agent-skills/`)
- Skills that are the same for both Hermes and Codex and represent tool configuration → corpus

---

## In-Repo Skill Authoring (hermes-agent-skill-authoring)

There are two places a SKILL.md can live:

1. **User-local:** `~/.hermes/skills/<category>/<name>/SKILL.md` — personal, not shared. Created via `skill_manage(action='create')`.
2. **In-repo:** `<repo>/skills/<category>/<name>/SKILL.md` — committed, shipped with the package. Use `write_file` + `git add`. `skill_manage(action='create')` does NOT target this tree.

### When to author in-repo

- User asks to add a skill "in this branch / repo / commit"
- You're committing a reusable workflow that should ship with hermes-agent
- You're editing an existing skill under the repo's `skills/` tree

### Required frontmatter

Source of truth: `tools/skill_manager_tool.py::_validate_frontmatter`. Hard requirements:

- Starts with `---` as the first bytes (no leading blank line).
- Closes with `\n---\n` before the body.
- Parses as a YAML mapping.
- `name` field present.
- `description` field present, ≤ **1024 chars** (`MAX_DESCRIPTION_LENGTH`).
- Non-empty body after the closing `---`.

### Peer-matched frontmatter shape

```yaml
---
name: my-skill-name               # lowercase, hyphens, ≤64 chars
description: Use when <trigger>. <one-line behavior>.
version: 1.0.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [short, descriptive, tags]
    related_skills: [other-skill, another-skill]
---
```

### Size limits

- Description: ≤ 1024 chars (enforced).
- Full SKILL.md: ≤ 100,000 chars (~36k tokens).
- Peer skills sit at **8-14k chars**. Aim for that range. Past 20k, split into `references/*.md`.

### Directory placement

```
skills/<category>/<skill-name>/SKILL.md
```

Categories in repo: `autonomous-ai-agents`, `creative`, `data-science`, `devops`, `dogfood`, `email`, `gaming`, `github`, `leisure`, `mcp`, `media`, `mlops/*`, `note-taking`, `productivity`, `red-teaming`, `research`, `smart-home`, `social-media`, `software-development`. Pick the closest existing category. Don't invent new top-level categories casually.

### In-repo workflow

1. Survey peers in the target category (`ls skills/<category>/`). Read 2-3 peer SKILL.md files to match tone and structure.
2. Check validator constraints in `tools/skill_manager_tool.py` if unsure.
3. Draft with `write_file` to `skills/<category>/<name>/SKILL.md`.
4. Validate locally (run the YAML/frontmatter checks).
5. Git add + commit on the active branch.
6. Note: the current session's skill loader is cached — `skill_view` / `skills_list` won't see the new skill until a new session.

### Editing existing in-repo skills

- **Small fix:** `skill_manage(action='patch')` works on in-repo skills.
- **Major rewrite:** `write_file` the whole SKILL.md.
- **Supporting files:** `write_file` to `references/`, `templates/`, `scripts/`, or `assets/`.
- **Always commit** — in-repo skills are source, not runtime state.

### In-repo pitfalls

1. **`skill_manage(action='create')` writes to `~/.hermes/skills/`**, not the repo. Use `write_file` for in-repo.
2. **Leading whitespace before `---`** fails validation.
3. **Description too generic.** Use "Use when ..." pattern.
4. **Current session can't see new skills** — the loader is cached at session start.
5. **`related_skills` referencing user-local skills** works for you but breaks for other clones.

---

## Integration with Other Skills

| Skill | How it fits in |
|-------|----------------|
| `subagent-driven-development` | Use its two-stage review (spec compliance → quality) as the eval reviewer pattern for skill red-green loops |
| `writing-plans` | Use to create the implementation plan for complex skills before writing the SKILL.md |
| `systematic-debugging` | Apply when a skill fails an eval — investigate root cause before fixing |
| `requesting-code-review` | Apply the same review dimensions to skill SKILL.md as you would to code |

---

## Quick Reference: Skill vs. Other Knowledge Capture

```
Skill ────────── Procedural, reusable, triggers on conditions
Memory ───────── Ephemeral facts, preferences, session notes
Hindsight ────── Structured long-term facts, extracted from sessions
Wiki/Notes ───── Growing knowledge, compounding understanding
Inline ───────── One-off instructions, not reusable
```

If it's a **procedure** the agent should follow autonomously → skill.
If it's a **fact** the agent should remember → memory/hindsight.
If it's **knowledge that compounds over time** → wiki/notes.
