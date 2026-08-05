# GTD Weekly Review — Sub-Skill

Load this reference when preparing for or running a GTD Weekly Review. The weekly review is the "critical success factor" of GTD (David Allen's words) — the glue that keeps the entire system functional. This reference stays open during the review session.

---

## When to Use This

Load this skill when:
- Preparing for your weekly review (scheduling, environment setup)
- Running the weekly review itself (step-by-step guidance)
- Troubleshooting a review that's taking too long or feeling unproductive
- Helping the user move items between GTD surfaces during review

---

## The Weekly Review: 3 Phases, 11 Steps

David Allen defines the weekly review in three stages: **GET CLEAR** (empty your head), **GET CURRENT** (update your system), and **GET CREATIVE** (look forward with energy). The review should be done once every 7–10 days and should take 60–90 minutes once the habit is established.

---

### Phase 1: GET CLEAR

**Purpose:** Empty your head completely. Everything that's been rattling around your mind goes into the inbox.

**Step 1 — Collect Loose Papers and Materials**
Gather all accumulated inputs: receipts, business cards, notes, sticky pads, miscellaneous paper. Put them in your in-tray (physical or digital inbox).

**Step 2 — Get "IN" to Zero**
Process all items in your in-tray. For each item:
- Can it be done in under 2 minutes? → Do it now.
- Is it reference material? → File to [[Reference]].
- Does it require a project? → Create a project page, add next action to [[Next Actions]].
- Is it waiting on someone else? → Add to [[Waiting For]].
- Is it a someday/maybe? → Add to [[Someday/Maybe]].

**Step 3 — Empty Your Head**
Do a "mind sweep." Ask: What's on my plate? What's bothering me? What's unfinished? Capture everything into the inbox or directly onto the appropriate GTD surface. Don't organize yet — just get it out of your head.

---

### Phase 2: GET CURRENT

**Purpose:** Bring every surface in your system up to date.

**Step 4 — Review Action Lists (Next Actions)**
Go through [[Next Actions]].
- Mark completed actions `DONE`.
- For each remaining action: is it still the right next action? Update if not.
- Are there any actions no longer relevant? `CANCELED` them.
- Any action without a context tag? Add `#@context`.

**Step 5 — Review Previous Calendar Data**
Open your calendar for the past week. Look for:
- Any actions you said you'd do but didn't complete → add to [[Next Actions]] or today's journal.
- Any reference material worth saving → file to [[Reference]].
- Any completed projects → mark `status:: completed` on the project page.

**Step 6 — Review Upcoming Calendar**
Look at the next 1–2 weeks on your calendar. Ask for each event:
- Is there any prep work? → Create a next action.
- Does it trigger any new commitments? → Add to the appropriate surface.

**Step 7 — Review Waiting For**
Go through [[Waiting For]].
- Any items received? Mark the block `DONE` and follow up.
- Any items that are no longer relevant? `CANCELED`.
- Any items needing a follow-up nudge? Add a follow-up action to [[Next Actions]] (e.g., "Follow up with Jane on proposal").

**Step 8 — Review Project (and Larger Outcome) Lists**
Go through all `status:: active` projects. For each:
- Does it have at least one next action on [[Next Actions]]? If not, define one.
- Is the `Outcome Visions` still accurate? Update if the goal has shifted.
- Has the project stalled (no activity in 2+ weeks)? Move to the front of the Someday/Maybe list or activate it.
- Is the project actually done? Mark `status:: completed`.

**Step 9 — Browse through Project Plans and Support Material**
Open your project pages. Look at:
- `## Brainstorm` sections — any items that should become concrete actions?
- `## Organize` sections — any steps that are missing next actions?
- Any notes or context that needs updating?

---

### Phase 3: GET CREATIVE

**Purpose:** Pull items forward, let things go, look at the horizon.

**Step 10 — Review Someday/Maybe**
Go through [[Someday/Maybe]].
- Any item that now has energy or urgency? Promote it to a project:
  1. Create a project page using the `project-planning` template
  2. Add a `next-action::` on [[Next Actions]]
  3. Mark the Someday/Maybe item `CANCELED` (or leave it and add a link to the new project)
- Any item that no longer holds appeal? Delete it or leave it as-is.
- Any item that's been on the list for over a year with no movement? Question whether it belongs.

**Step 11 — Be Creative and Courageous**
This is the "blue sky" step. Ask:
- What's not in the system that should be?
- Any big picture goals or roles that feel neglected?
- Any new projects or ideas that want to be born?
- Capture them — put them in the inbox, turn them into projects.

---

## How to Run the Review in Logseq

### Create a Weekly Review Journal Entry

Open today's journal: `journals/YYYY_MM_DD.md`. Add the review checklist at the top.

```markdown
title:: Weekly Review — YYYY-MM-DD

## Weekly Review Checklist

### GET CLEAR
- [ ] 1. Collected all loose papers and materials
- [ ] 2. Inbox processed to zero
- [ ] 3. Mind sweep done — all open loops captured

### GET CURRENT
- [ ] 4. Next Actions reviewed — completed marked, stale actions updated
- [ ] 5. Previous calendar reviewed for missed actions
- [ ] 6. Upcoming calendar reviewed — prep actions added
- [ ] 7. Waiting For reviewed — follow-ups identified, received items marked
- [ ] 8. All active projects reviewed — each has a next action
- [ ] 9. Project plans browsed — brainstorm/organize sections updated

### GET CREATIVE
- [ ] 10. Someday/Maybe reviewed — items promoted or pruned
- [ ] 11. Blue sky thinking — new projects captured

---
Review completed: YYYY-MM-DD
Next review scheduled: [date + 7 days]
```

### Quick-Reference: Moving Items Between Surfaces

| From | To | How |
|------|----|-----|
| Inbox | Project | Create page with `template:: project-planning`, add next action to [[Next Actions]] |
| Inbox | Next Action | Add block to [[Next Actions]] with `#@context` |
| Inbox | Waiting For | Add block to [[Waiting For]] with who/what |
| Inbox | Someday/Maybe | Add block to [[Someday/Maybe]] with brief note on appeal |
| Inbox | Reference | Move content to [[Reference]] organized by topic |
| Someday/Maybe | Project | Create project page, mark S/M item `CANCELED`, link to new project |
| Project | Someday/Maybe | Change `status:: active` to `status:: someday` |
| Next Action | Waiting For | Move block to [[Waiting For]], add delegation info |
| Waiting For | Next Action | Follow-up completed → add next step to [[Next Actions]] |

---

## Troubleshooting

### "My review takes 4–6 hours"

Common causes:
- Doing tasks instead of reviewing — the review is NOT the time to execute actions. If something takes less than 2 minutes, do it and move on. But for anything longer, capture the action and stay in review mode.
- Carrying too much legacy backlog — process your inbox before starting the review (Step 2 should be done the day before if possible).
- Too many projects without next actions — the review will surface these. Add the next action and move on.

Tip: Get inbox to zero the day before you do the rest of the review. Splitting the load makes it manageable.

### "I forget to do the review"

- Schedule it. Pick a day and time that works for you — Friday morning is most common. Put it on your calendar like any other appointment.
- Leave a reminder block in your journal on the day before.
- Commit to at least 4 consecutive reviews before deciding it "doesn't work." It takes time to feel the benefit.

### "The review feels like a chore, not a reset"

Reframe it: the weekly review is not administrative overhead — it's the thing that gives you a "mind like water." When you emerge, you know exactly what matters and what to do next. That's worth 90 minutes.

### "I don't have 90 minutes"

Any review is better than none. If you're short on time, prioritize in this order:
1. Get inbox to zero (Step 2)
2. Review upcoming calendar (Step 6) — this shapes the week ahead
3. Review Next Actions (Step 4) — update what you can
4. Review Someday/Maybe (Step 10)

Even 20 minutes covering these will keep the system functional.

---

## Review Habits Checklist

Before you start the review, confirm:
- [ ] Calendar is clear for 60–90 minutes
- [ ] Inbox has been collected (Step 1 done)
- [ ] You're in "review mode" — not "do mode." You're allowed to capture actions, not execute them.
- [ ] You have access to all GTD surfaces: [[GTD Hub]], [[GTD Inbox]], [[Next Actions]], [[Waiting For]], [[Someday/Maybe]], [[Reference]]
