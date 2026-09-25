---
name: wisdom-council
description: Use when the user asks to summon a council of expert agents, a wisdom council, god-mode review, or multi-perspective critique of a design, spec, plan, or architecture. Also use when a consequential decision would benefit from independent expert perspectives before proceeding — including "spin up N agents to solve/check this", "did we miss anything?", or design-council review requests. Do NOT use for factual lookups, simple questions, or when the user just wants one answer.
---

# Wisdom Council

## Overview

Summon N expert agents in parallel, each solving/reviewing the same problem from a distinct school of thought, then synthesize: compare, find consensus, adjudicate disagreements, and deliver a verdict with must-fixes. The council's power comes from **independence** (parallel, no shared context) and **structured comparison** (same question set, comparable outputs). Never let one agent produce the whole result — that is exactly what the council exists to prevent.

## When to Use

- User says: "wisdom council", "god mode", "summon experts", "spin up N agents", "gather perspective", "review this with a council", "check if we missed anything" (design/plan/spec context).
- A design or plan is about to be committed and would benefit from adversarial, independent review.
- Multiple schools of thought genuinely apply (correctness, ops, security, UX, economics, statistics, …).

**When NOT to use:** one-off factual questions, quick implementation decisions, anything with a single clearly-correct answer.

## Council Roster (pick lenses, don't use all)

The full persona library is in `references/personas.md`. **The default council is the God-Mode 9** — architect, product owner, QA, UX, devops, secops, cost, data-science, performance — each with a fixed lens (technical feasibility / customer value / testability / experience / operations / security / economics / statistics / performance) and a fixed deliverable contract (verdict, findings with references, MUST-FIX list, nice-to-haves, one thing right).

Selection rules:

- **Plan/design review (default):** the god-mode 9 — or the relevant subset (e.g., a kernel-only review: architect, QA, secops, cost, performance).
- **Blind solve round** (user wants independent solutions): 4–6 personas from the extended solution roster. Give them the PROBLEM ONLY — never your current design (anchoring destroys independence).
- **Critique round** (review an artifact): extended-roster personas + the contrarian post-mortem every time. Give them the artifact + prior consensus to stress-test ("don't repeat it").
- **Always add at least one lens the user didn't name** — they're asking for a council because their own perspective is narrow.
- Balance: 1 contrarian per 3–4 domain experts; never more than ~9 parallel agents in one round (attention-limited synthesis).

## Dispatch Protocol (abridged — full template in `references/protocol.md`)

1. One shared problem block: system context, constraints, the deliverable contract (A–F questions: verdict, specialty deep dive, consensus stress-test, failure modes, cuts, one thing everyone gets wrong).
2. Persona-specific lens block appended to each brief (from `references/personas.md`).
3. Dispatch ALL agents in a single message (parallel).
4. Synthesize: verdict table → consensus list → adjudicated divergences → MUST-FIX list → what was applied/committed → deferrals.

## Non-Negotiables

- Every brief: "Do NOT modify files" unless the round is an authoring round (then: one section per agent, exact file path, no other files).
- Every brief returns a structured verdict with named failure modes — no open-ended essays.
- Synthesis MUST adjudicate every divergence with a decision (adopt/override/defer + why). An unadjudicated council report is a failure.
- Apply accepted must-fixes to the artifact and commit — **when write access exists**. If the round is read-only (user constraint or no git repo), deliver the fixes applied inline in the report (exact edit + target location per fix) and flag "unapplied — awaiting write access". Never silently skip application.
- If an agent returns empty: re-dispatch that brief, don't silently proceed. If the dispatch tool itself fails, retry once; if it fails again, proceed with the remaining members and report the gap.
- **User-pinned rosters take precedence** over selection rules (e.g., "exactly these 3 personas"). The "add a lens they didn't name" rule applies when the user names none or a partial set; the contrarian-mandatory rule applies to extended-roster critiques, not to user-pinned god-mode sets.

## Red Flags — STOP and Fix

- Any agent wrote the whole artifact instead of their section/perspective
- Reviewers were given your design when you wanted independent solutions (anchored)
- The synthesis table has no adjudication column
- "Resolve at merge" notes left without an owning task
- Empty agent results silently ignored

## Prior Council Artifacts (reference corpus)

- The project's own canonical council examples — point at a spec and a plan in the project that show the round structure or the god-mode deliverable contract (verdict table, adjudicated MUST-FIX list). Substitute the project's real paths; the council works without a recorded example.
