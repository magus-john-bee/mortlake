# GTD Projects

**How projects work in your GTD system.**

---

## What Is a Project in GTD?

A project is any outcome that requires more than one physical action step. "Finish resume" is a project. "Send email to Jane" is a next action.

**The test:** If you can do it in one physical step, it's an action — not a project. If it has multiple steps over time, it's a project.

---

## Project Template

Every project uses the **`project-planning` template**. The template lives in the skill at `templates/project-planning.md` — if the graph doesn't have a `pages/project-planning.md` yet, seed it from there. Then reference it on each project page:

```
template:: project-planning
```

This gives you the GTD informal planning workflow:

```
- Principles / Purpose   — Why does this matter?
- Values                 — What's important about it?
- Outcome Visions        — What does success look like?
- Brainstorm             — What could get in the way? What's involved?
- Organize               — Structure the work into steps
- Actions                — Concrete next physical steps
```

---

## Project Status

Projects have three possible statuses:

| Status | Meaning |
|--------|---------|
| `status:: active` | You're actively working toward this outcome |
| `status:: someday` | Moved to the someday/maybe track — not actively pursued |
| `status:: completed` | The outcome has been achieved |

---

## Creating a New Project

1. Create a new Logseq page
2. Add `template:: project-planning` at the top
3. Set `status:: active` and `area:: [[area-name]]` (always link to an area of focus)
4. Fill in the sections — particularly `Outcome Visions` and `Actions`
5. Add at least one next action to [[Next Actions]]
6. Link from the project's `Actions` section to `[[Next Actions#block-id]]`
7. Add the project link under Active Projects on its area page

---

## Linking Next Actions to Projects

Every next action on [[Next Actions]] should show its origin project:

```
- TODO Call Jane about the proposal #@calls [[my-project]]
```

On the project page, the `Actions` section links back:

```
## Actions
- [ ] Call Jane about the proposal ((block-id))
```

---

## Weekly Review and Projects

During weekly review (Steps 8 and 9):

1. For each `status:: active` project:
   - Does it have a next action on [[Next Actions]]?
   - Is the `Outcome Visions` still accurate?
   - Is the project still active — or should it move to someday/maybe?

2. Browse project pages:
   - Brainstorm sections: any items that should become actions?
   - Organize sections: any steps missing next actions?

3. Move stalled projects to someday/maybe (change `status::`) or delete them.

---

## Adopting Existing Pages as Projects

Your graph has pages that are already project-shaped. To adopt one:
1. Open the page
2. Confirm it has `Outcome Visions` and `Actions` sections
3. Add `status:: active` if not already present
4. Link its first action to [[Next Actions]]

Discover project candidates dynamically — search the graph for pages with `Outcome Visions` and `Actions` sections.
