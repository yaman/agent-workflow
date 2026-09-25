# Wisdom Council — Dispatch & Synthesis Protocol

## Shared brief template (embed in EVERY council agent prompt)

```
You are <PERSONA>. You are on a design council for <ARTIFACT>. You are at the top of your field.
Do NOT modify files. Return a written proposal/review as your final message (structured markdown, max ~900 words).

## The problem / artifact
<PROBLEM: constraints, requirements, context — or the artifact path + what to read>
<MODE: blind-solve (problem only, NO current design) | critique (artifact + prior consensus, "stress-test, don't repeat it")>

## Prior council consensus (critique rounds only — stress-test, don't repeat)
<bulleted consensus points the other rounds converged on>

## Deliver (keep comparable with the other members)
A. <Verdict: ship as-is / conditional / not buildable — one of three, no hedging>
B. <Persona deep dive — their lens questions from the roster>
C. Where the consensus/design is wrong, over-engineered, or missing something (be specific, reference sections/tasks)
D. Top 5 failure modes + mitigations
E. What to cut for v1 / this round
F. One thing everyone else will get wrong
```

## Deliverable contracts — ONE per round, pick before dispatching

- **God-mode / critique rounds (default):** A–E contract from personas.md — verdict, top findings with exact references, **MUST-FIX list (numbered, each with the concrete change)**, nice-to-haves, one thing right. The MUST-FIX list is REQUIRED — synthesis step 4 consumes it.
- **Solve rounds:** the A–F contract above (verdict, deep dive, where-consensus-wrong, failure modes, cuts, one-thing-wrong).
- State in every brief which contract governs. Never mix the two within one round.

## Dispatch rules

1. **One shared problem block; one persona-specific lens block** appended per agent.
2. **All agents in ONE message** (parallel). Never dispatch serially — independence dies. Mechanics: N `task` calls in a single message. If the harness lacks a task tool, fall back to one subagent that runs the round itself (weaker — note it in the report).
3. **Blind rounds**: never include your current design in the problem block. The design is revealed only in critique rounds (where it is the artifact under attack).
4. **File-touching**: default "Do NOT modify files." Authoring rounds (e.g., plan-writer council): "write ONLY your section file at <exact path>; no other files" — one file per agent, then assemble.
5. **Authoring rounds**: lock canonical identifiers/contracts in every brief so parallel sections interlock; tell each agent what the OTHER sections own (no duplication); require Interfaces (Consumes/Produces) blocks.
6. **Round limits**: 4–6 agents for solve rounds, up to 9 for god-mode review. More than 9 → synthesis becomes noise.
7. **Contrarian is mandatory** in every extended-roster critique round. In solve rounds, add one if the problem invites over-optimism. User-pinned rosters override these rules.
8. **Empty/failed dispatch**: task returns empty → re-dispatch that brief once, then proceed with the remaining members and report the gap. Tool-level failure → retry once, then proceed + report. Never silently proceed with fewer members than briefed.

## Synthesis protocol (run it every time, in order)

1. **Verdict table** — one row per member: | lens | verdict | signature finding |.
2. **Consensus detection** — items found by 2+ independent members become "the inviolable core" (note: one member's unique finding can still be right; consensus is evidence, not truth).
3. **Adjudication table** — every divergence: | member | position | decision (adopt / override / defer) | why |. NO unadjudicated divergences.
4. **MUST-FIX consolidation** — dedupe into numbered fixes; each fix names the source member(s), the target artifact location, and the concrete change (inline edit, new task, or explicit deferral with rationale).
5. **Apply** — edit the artifact (or append an adjudication appendix, e.g., "Appendix C — Council Review Round N") and COMMIT — when write access exists. Read-only rounds: deliver fixes applied inline in the report with exact target locations, flagged "unapplied — awaiting write access". The council's output must change the thing, not just praise or bury it.
6. **Deferral list** — explicit v1/later items with one-line rationale; never silence.
7. **Report** — verdicts, cross-corroborated defects, what changed in the artifact, deferrals, next step.

## Adjudication rules

- Adopt a fix when 2+ independent members converge on it (cross-corroboration).
- Adopt a single-member fix when it is load-bearing (e.g., a seam with no owner, an untested claim the plan's own acceptance depends on).
- Override when the fix contradicts the user's explicit decisions or the spec's adopted defaults (state the override).
- Defer when the fix gates nothing until a later phase (e.g., learning-loop statistics while learning is locked) — but the deferral must be documented, never silent.
- When in doubt about a high-impact fix: apply it; the cost of a wrong must-fix is one commit, the cost of a missed one is a mid-build surprise.

## Failure patterns seen in practice (avoid)

- Agent returns empty → re-dispatch the brief immediately; never proceed with the gap.
- Agent writes the whole artifact in an authoring round → clamp with "write ONLY your section file."
- Section numbering/heading drift in assembled docs → normalize before assembly (e.g., `## Task` vs `### Task`).
- Assembly truncates headers (e.g., `head -12` cut Global Constraints) → rebuild assembly from source parts and verify byte counts before committing.
- Cross-section conflicts surface only at assembly → require Interfaces blocks up front + run a merge/conflict pass (canonical types, naming collisions) and record resolutions in the artifact header.
