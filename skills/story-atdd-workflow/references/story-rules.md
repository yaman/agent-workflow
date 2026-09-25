# Story Rules — full text

The essential rules live in SKILL.md; this file carries the complete standards and the reasoning. Generalized from established story-writing standards, extended for the per-AC vertical ATDD workflow.

## Structure (every story)

1. **Epic line** — the epic this story serves (`epic:<slug>`).
2. **Outline** — user-story form: `As a user, I want <action>, so that <benefit>.`
3. **≤3 Gherkin ACs** — the contract. There is NO separate "Decision details" section; the ACs ARE the decisions.
4. **Estimate** — the AC count.
5. **`depends_on`** — explicit edges to prerequisite stories.

## AC format (exact)

Structured, one object per AC:

```
{ key: "ac1",
  title: "scenario: <what the user achieves>",
  gherkin: {
    given: "<precondition, user-observable state>",
    when:  "<the user's single action>",
    then:  "<the user-observable outcome, exact strings/values>"
  } }
```

Example:

```
{ key: "ac1",
  title: "scenario: user sees the exact duplicate error",
  gherkin: {
    given: "an entry with name \"atdd\" already exists",
    when:  "the user saves a second entry named \"atdd\"",
    then:  "the form shows \"registry entry already exists: atdd\" and no new row appears"
  } }
```

## AC rules

- **Fully user-facing.** Given = user state / config as the user sets it. When = the user's single action. Then = the user-observable outcome: exact strings the user SEES, exact displayed values, thresholds as the user configures them. Zero assumptions in user terms.
- **Exactly one scenario per AC.** Given/When/Then each on its own line; no And-chaining; no run-together keywords; no second scenario folded in.
- **Independently implementable vertical slices.** AC(n) must be makeable green alone, without AC(n-1)'s code. If it can't, the story was split wrong — re-split (or re-order the ACs) BEFORE execution. This is what makes the serial per-AC loop possible.
- **Technical pinning NEVER lives in an AC.** File names, function signatures, RPCs, internal field names, error strings only the backend emits — all of it goes in the architect's tech_brief (per-AC sections, written at pickup). If an AC needs a technical detail to be decidable, the spec/architect decides it — the AC stays user-facing.
- **Estimate = the AC count.** A story's size is how many ATDD cycles it carries. Scheduling = sum of AC counts over `depends_on` topological order.
- **Max 3 ACs per story.** More, or any AC spanning more than one ATDD session → split (`sXa`/`sXb`), split recorded in the story title.
- **INVEST:** Independent (explicit `depends_on` edges), Negotiable (outcomes, not implementation), Valuable, Estimable (AC count), Small (single ATDD session per AC), Testable (each AC names its acceptance test's harness in the tech_brief).

## Story lifecycle

`todo → in-dev → in-review → done` (map db). Parallel track in the iteration db: `story_run` carries per-AC granular state (`pending/red/green` + evidence).

## Splitting triggers

- >3 ACs.
- Multi-repo work.
- Mixed concerns (e.g. test infra + feature in one story).
- Any AC too large for one ATDD session.
- AC(n) not implementable without AC(n-1) — either re-order the ACs (if the user-observable order allows) or split.
