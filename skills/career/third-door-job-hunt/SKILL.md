---
name: third-door-job-hunt
description: Use when planning or executing a job hunt via direct outreach (the "Third Door") — contacting hiring managers, peers, and founders directly while using portals only as low-effort parallel channels. Covers target selection, contact discovery, email strategy, follow-up cadence, and web-to-research/AI career pivots. Core rule: effort scales with visibility — never spend tailored work where only a filter reads it. Message-drafting mechanics defer to career-ops contacto mode.
tags: [career, job-hunt, outreach, third-door]
version: 1.0.0
license: MIT
metadata:
  hermes:
    tags: [career, job-hunt, outreach, third-door]
---

# The Third Door Job Hunt

Strategy layer for direct-outreach job hunting: targeting, sequencing, and
cadence. Message mechanics (drafting, personas, tone, multilingual variants)
live in career-ops — see "Bridging with career-ops" below.

**Canonical source:** this skill is the agent-executable form of the logbook
playbook `~/vault/logbook/pages/third-door-job-hunt.md`. That page stays the
human-readable original with full sourcing and template text. Do not fork
content between them — when the playbook changes, update this skill in the
same session.

## When to use / routing

- "Find me targets" / build a target list → this skill (§ Target Profile)
- "Draft an outreach email to X" → career-ops `contacto` (mechanics), with
  strategy from this skill (§ Email)
- "Evaluate this JD" → career-ops `evaluate`
- "Draft a cover letter" → career-ops `cover`
- Interview prep → career-ops interview modes (plan / practice / debrief)
- "What's my status / next follow-up?" → this skill (§ Follow-Up Cadence)
- Career-pivot framing (web → research) → this skill (§ Pivot Positioning)
- Resume/CV generation → career-ops resume modes
- Target-company tracking → logbook `[[companies-interested-in]]`

## The Three Doors

- **First Door** — the portal/ATS. Designed to filter out. 300+ applicants
  per popular posting within hours; ~75% of resumes killed by ATS parsing;
  portal → offer ≈ 0.1–2%.
- **Second Door** — connections/nepotism. Effective if you have it; not
  replicable, needs no playbook.
- **Third Door** — direct outreach to decision-makers. 15–25% response on
  well-targeted emails; sourced candidates 5x more likely to be hired;
  referred candidates ~30% conversion vs ~7% cold pool.

**Effort-per-visibility rule** (the actual principle — not door purity):
the First Door is fine as a *parallel* channel when it costs near-zero.
Fire the default resume into the portal in five minutes while the
tailored work goes to a person. The waste case isn't portals — it's
high-effort artifacts (tailored letters, work samples, long forms) spent
where only a filter sees them. Allocate effort by the chance a
decision-maker actually reads it: person reachable → full effort;
HR-gated only → minimum viable portal application, then go find the
person. Never let the portal application *be* the campaign.

## Target Profile (who to contact)

Priority order:

1. **Hiring manager** for the target team — best; owns the problem you'd solve.
2. **Future peer** on the team — champion + referral lane, lower pressure.
3. **Department head / VP / Director** — can create or refer roles pre-req.
4. **Technical founder / CTO** — startups; lead with a GitHub link or demo,
   never a resume.
5. **Internal recruiter** — lowest visibility per effort; use for
   low-effort parallel applications, never as the primary channel.

Avoid: generic `careers@` inboxes; FAANG recruiters for technical roles (they
can't override process — go to the HM); anyone whose listing explicitly says
"no direct contact."

## Finding the right person

1. LinkedIn: company page → People → department filter. Target "Head of /
   Director / VP / Team Lead / Staff Engineer" for the function. Large
   companies: one level below VP (they're the ones struggling to hire).
   Startups: founder/CTO.
2. Prefer people **in role < 2 years** — still proving themselves, less
   entrenched with internal recruiting, more likely to source outside the
   portal.
3. Posting breadcrumbs: JD mentions a team name → search team + company on
   LinkedIn; the team lead usually surfaces.
4. Company About/Team pages — best for companies < 500 employees.
5. Google operators: `site:linkedin.com/in "company" "hiring manager"`,
   `"name" "company" email`.
6. Conference talks / papers / engineering blogs — for research roles the
   presenter or author is often the team lead, and gives a real hook for the
   email's first line.

## Finding their email

Managers live in email, not LinkedIn DMs. Get the address.

- Finder tools (free tiers 25–50 lookups/mo each): Hunter.io, Apollo.io,
  RocketReach, Kaspr.
- Pattern-guess: `firstname@`, `firstname.lastname@`, `firstinitiallastname@`,
  `firstname@company.com` — validate against one known public employee address.
- Verify before sending (NeverBounce / ZeroBounce) — bounces damage sender
  reputation and spam-folder future mail.
- Fallback: LinkedIn DM (connection request with a 1-line note, then email a
  day later). Email strongly preferred.

## Email strategy

Hard rules:

- **50–150 words**, under 125 performs best. If it needs scrolling, cut.
- **No resume attachment on exploratory first emails** — offer to send it.
  Exception: referencing a specific posted role → attaching is fine and
  reduces friction.
- **One clear ask**: a 15-minute call, a quick question, or permission to
  send the resume. Never three options.
- **Ask for a conversation, not a job.** "Can we chat for 15 minutes?" not
  "Are you hiring?"
- **Personalize the first two lines.** If it could go to 50 companies
  unchanged, it's too generic.
- **Don't sound AI-formal.** "Reaching out to express my keen interest" is a
  red flag. Use AI to brainstorm; final draft in your own voice.
- **Send from your own authenticated Gmail.** Plain text, SPF/DKIM aligned.
  No third-party relays.

Four-part structure:

1. **Hook** (1 sentence) — reference something real: launch, paper, blog
   post, product detail, team expansion. Prove you looked.
2. **Relevance** (1–2 sentences) — who you are + one specific quantified
   result. One number beats a list of titles.
3. **Why this company** (1 sentence) — a detail that proves it's not a blast.
4. **Next step** (1 sentence) — the single clear ask.

Subject lines: under 7 words, specific, not clever (HMs search their inbox
by role name later). Working formulas:

- `[Role] application, [Name]` — boring on purpose, easy to find again
- `Quick question about the [role] at [Company]` — questions get opened
- `[Specific result], interested in [team]`
- `[Mutual connection] suggested I reach out` — highest-converting, only if true
- `Loved the [specific thing], applying for [role]`

Avoid: "Opportunity," "Following up," "Resume attached," "Hello," ALL CAPS,
anything over 8 words.

### Template selection (full text in the logbook playbook)

- **A — Exploratory** (no posted role, research-adjacent target): their
  work → your pivot credential → 15-minute ask.
- **B — Posted role**: unusual fit → one quantified result → call ask;
  resume attached; mention you also applied through the portal.
- **C — Future-peer value-first** (highest-skill play): offer a useful
  artifact (risk list, benchmark, pattern writeup) with no ask. Often
  triggers "we're actually looking for your background" + referral lane.
- **D — Founder cold DM** (LinkedIn/X): 2 sentences, lead with the demo
  link, not the resume.

## Follow-up cadence

Most replies come after the follow-up, not the first email. 48% of people
never send one — the follow-up alone beats half the field.

- Touch 1: day 0 — intro + value proposition
- Touch 2: day 5–7 — gentle reminder + ONE new piece of value/context
  (announcement, new angle, resource). Not "bumping this up."
- Touch 3 (optional): day 14–20 — different angle; read the room
- Stop after 2 unanswered. Three+ tips from persistence into intrusion.
  Re-engage in 60–90 days only if circumstances change.

Timing data: waiting 3 days boosts reply ~31%; waiting > 5 days drops them
~24%. 5–7 business days is the window.

## If redirected to HR / the portal

Still a win. Apply through the portal referencing the conversation
("[HM name] suggested I apply") — flags the application for special
attention; you're a vouched-for applicant, not a cold one. Then reply to the
HM confirming you applied.

## Informational interviews (the stealth Third Door)

Lowest-friction entry: asking for 20 minutes of perspective, not a job.

- Ask: 50–125 words, specific reason you picked them, defined 20 minutes,
  and the magic sentence — "I'm not asking you for a job, I just want your
  perspective."
- Run it: speak less than a third of the time; open questions about their
  experience (stories and opinions, not googleable facts); never ask "are
  you hiring"; near the end ask "is there anyone else you'd recommend I
  talk to?" — turns one chat into a chain of warm intros.
- Follow up within 24 hours referencing something specific they said; stay
  visible only with useful things.

## Pivot positioning (web → research / AI-adjacent)

Research orgs have mountains of unkempt research code; strong SWE + mediocre
ML is a viable and needed profile. Emphasize:

- **AI orchestration experience** — agent pipelines, tool-use workflows,
  RAG systems, evaluation harnesses. The strongest pivot credential; lead
  with it.
- **Generalist systems thinking** — across-stack range, fast domain
  learning, integration with existing infrastructure.
- **Shipping under constraints** — the prototype-to-reliable translation
  research code needs.
- **Comfort with ambiguity** — side projects, OSS contributions,
  self-directed learning as evidence.

Reframe: "web developer" → "software engineer building [orchestration
layers / data pipelines / distributed systems]". Never criticize past
employers; forward-looking only ("work where the engineering bar and the
problem space are both more ambitious").

### Target role categories

- **Research Software Engineer (RSE)** — universities, national labs,
  research institutes. Bridge between scientists and production code.
  Lower competition than pure ML roles.
- **AI/ML Infrastructure Engineer** — national labs (ORNL, LBL/NERSC,
  Frederick), big tech, AI-first startups. HPC/GPU environments,
  orchestration (Ray, Airflow, Dagster), serving (vLLM, LiteLLM).
- **AI Research Software Engineer** — applied research divisions (Arc
  Institute, Allen Institute, Broad Institute, Thomson Reuters Labs).
  Methods + the software that deploys them.
- **Applied Scientist / Research Engineer** — industry labs. End-to-end:
  literature → hypothesis → experiment → production. Open to strong SWEs.
- **MLOps / LLMOps Engineer** — CI/CD for models, eval harnesses, RAG
  pipelines, agent orchestration. Direct experience match.
- **AI Orchestration Engineer** (emerging) — startups, AI-first companies.
  Agent workflows, tool-use patterns, multi-model routing. Exact match.

Where to look beyond boards: national labs' own career sites
(jobs.ornl.gov, jobs.lbl.gov), university research-computing centers
(every R1 has one), research institutes, YC/stealth startups (cold-DM
founders — they hire 2–4 weeks before the portal post exists), industry
applied-research divisions.

Concrete signals to surface: agent/orchestration frameworks built or
contributed to; RAG + vector DB experience (Chroma, Qdrant, Milvus); model
serving (vLLM, Ollama, LiteLLM); eval harnesses; distributed compute (Ray,
Kubeflow, Airflow); Linux/containers/IaC; OSS contributions to research
tools; papers read/implemented/written about.

## The math: expectations & cadence

- Target list of 30–50 companies, not 5. Track: company, contact, email,
  role, personalization notes, status, follow-up dates.
- 5–10 personalized emails/day. Quality beats quantity, but volume
  generates responses.
- Benchmark response rates: well-personalized to the right target 15–25%;
  strong social proof up to 25–50%; generic 5–25%; portal (comparison)
  2–5%.
- Most positive responses land on the 2nd or 3rd touch.
- Expect ghosting even with good emails and right targets. A few months of
  consistent effort → a connection at a target company.

## The meta-principle

Asking a stranger for a job puts a burden on them; busy people decline
burdens. Knocking on the Third Door asking for a handout keeps it locked —
offer a tool. The Third Door converts agency into access: more research,
more energy, more rejection than the portal, but a game of agency rather
than chance.

## Bridging with career-ops

career-ops (`~/src/career-ops`, `.agents/skills/career-ops/`) is the
message-mechanics layer: ~50 mode files covering contacto (outreach drafting
with recruiter-vs-HM persona split), JD evaluation rubrics, cover letters,
interview plan/practice/debrief, and resume generation.

Division of labor:

- **This skill** — strategy: who to contact, when, how often, how to
  position the pivot, what to track.
- **career-ops contacto** — mechanics: drafting the actual email, persona
  and tone rules, language variants (en/de/es/zh), length discipline.
- **career-ops evaluate / cover / interview / resume modes** — the
  non-outreach workflows.

Workflow when drafting outreach: (1) this skill picks the target type and
template letter (A/B/C/D); (2) `contacto` drafts in the right persona and
language; (3) this skill's hard-rules checklist is the final gate before
sending (word count, one ask, no attachment unless posted-role, subject
formula).

The portal-facing career-ops modes (scan, tracker, apply, batch) are First
Door machinery — deliberately unused under Third Door strategy except when
an HM redirects to the portal (§ If redirected).

## Maintenance notes

- Upstream career-ops moves fast (local clone diverges; upstream added
  heavy zh/ localization and expanded interview modes as of 2026-08-18).
  Before relying on a mode name, check `ls ~/src/career-ops/modes/`.
- The logbook playbook is canonical for template text and sourcing; this
  skill intentionally does not duplicate the four full templates.
