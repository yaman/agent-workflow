---
name: data-science-council
description: Use when the user asks for a data science council review — "run the DS council", "data science council", "review this claim", "is this statistically sound", "review this experiment config", "would this survive due diligence", "catch the statistics problems" — on any document (memo, ADR, pitch, proposal) or experiment config with a statistical, causal, or learning claim. Summons a 10-persona parallel council (power & sample-size, causal inference, learning-loop, experiment design, multiple-comparisons, data & labeling, strategy/econometrics, benchmarks fact-checker, overclaim skeptic, data engineer) that reviews documents and experiment configs, adjudicates divergences, returns a verdict with severity-tagged MUST-FIX findings, and can write the verdict to SurrealDB (verdict table, status recorded) on request.
---

# Data Science Council

## Overview

Ten expert personas review a document or experiment config in parallel, then the chair synthesizes with every divergence adjudicated. Independence comes from parallel dispatch (no shared context); comparability comes from one shared problem block and one deliverable contract per persona. The council catches what an external data-science assessment catches: underpowered designs, correlation sold as causation, self-confirming learning loops, experiments that aren't experiments, uncorrected multiple comparisons, dirty labels, non-estimable strategy claims, unverifiable numbers, vendor-marketing overclaims, and designs whose data feed does not exist.

## When to Use

- User pastes a document/claim → **document mode**: verdict + MUST-FIX list.
- User pastes an experiment config (assignment_model_v1 shape) → **config mode**: design-checklist review.
- User asks for a statistical/causal sanity check on anything (memo, ADR, pitch, story, proposal).

**When NOT to use:** pure code review, non-statistical design reviews, one-off factual lookups, anything without a statistical/causal/learning claim.

## Mode detect

- Text with a claim → document mode (default: full roster).
- Config-shaped object (assignment model / washout / metrics / guardrails / min samples / decision rule) → config mode (default: lite roster).
- Genuinely ambiguous → one clarifying question, then proceed.

## Rosters

- **Full (10):** Power & Sample-Size Auditor, Causal Inference Critic, Learning-Loop Critic, Experiment Design Reviewer, Multiple-Comparisons Auditor, Data & Labeling Critic, Strategy & Econometrics Reviewer, Benchmarks Fact-Checker (web), Overclaim & Evidence Skeptic (web), Data Engineer / Feed-Reality Critic.
- **Lite (7):** Power & Sample-Size Auditor, Causal Inference Critic, Learning-Loop Critic, Experiment Design Reviewer, Multiple-Comparisons Auditor, Overclaim & Evidence Skeptic (web), Data Engineer / Feed-Reality Critic.
- Consensus threshold: ≥ half + 1 of dispatched personas (≥6/10 full, ≥4/7 lite).

## Problem block (shared, given to every persona verbatim)

1. The document or config, verbatim.
2. The mode checklist — read `references/checklists.md`, include the relevant checklist verbatim.
3. The anchor table — read `references/benchmarks.md` and include it verbatim (personas must argue from verified numbers).
4. The deliverable contract, verbatim (from `references/personas.md` header): verdict sentence; findings with severity (BLOCKER/MUST-FIX/WARNING/INFO) and evidence class (sourced/computed/first-principles); one thing the document gets right.
5. Mode instruction: "Review only — do not modify files. Return findings only."

## Dispatch protocol

1. Load `references/personas.md`; select the roster by mode.
2. Dispatch ALL personas in a single message via the `task` tool (`general` subagent type), each with: the shared problem block + their persona block + the mode instruction.
3. Empty persona result → re-dispatch that one brief. Task-tool failure → retry once, then proceed with the remaining personas and report the gap.
4. No task tool in this harness: decline the run and say why, OR proceed sequentially with the independence caveat explicitly recorded in the verdict (parallel dispatch is the independence mechanism — a sequential run's verdict must carry the caveat, never silently).

## Synthesis (chair, mandatory structure)

- **Verdict table:** persona × verdict.
- **Consensus list:** verdict-direction agreement with per-point supporter counts — the listed "N/M" is the number of personas sharing the verdict direction; each listed point carries its own supporter count (a 9/10 verdict never implies 9 personas held each point).
- **Adjudicated divergences:** every disagreement with adopt / override / defer + why. An unadjudicated divergence is a failure.
- **Merged MUST-FIX list:** deduplicated, ordered by severity; BLOCKERs separated from WARNINGs.
- **Chair's one-liner:** "would this survive a competent data-science reviewer?"
- **Final verdict:** `sound` / `sound-with-gaps` / `unsound` / `inconclusive` (inconclusive is first-class — a verdict on immature evidence is an error).

## SurrealDB step (ONLY when the user asks)

1. Read `references/surreal.md`; resolve credentials per its rules.
2. Present the record shape, write as `recorded`, verify by re-reading the record, report the id.
3. Never claim success without the verification read.

## Verification corpus (acceptance runs)

The skill is not done until a set of known cases passes. Use cases from the
project's own history (a memo with a flawed learning-loop claim, a known-sound
design, a naive experiment config, a well-formed config) and assert the council
surfaces the expected findings. A generic baseline:

1. A learning-loop memo → must independently surface: prediction-vs-prescription conflation; infeasibility at small sample sizes; the self-confirming feedback loop; strategy non-identifiability; multiple-comparisons exposure. Missing any = failure.
2. A known-sound design doc → must return sound / sound-with-gaps (confirm, not re-litigate).
3. A naive experiment config (small N, 50/50 split, short horizon, single metric, no washout, no correction) → must flag: underpowered, no pre-registration, undefined family, contamination, labeling assumptions.
4. A well-formed config (crossover + washout + pre-registered + corrected + propensity-logged) → must pass with gaps only.
5. An immature-evidence claim → must return `inconclusive`, not a confident verdict.

## Red flags — STOP and fix

- Any persona returned the whole synthesis instead of their own findings.
- Synthesis table missing adjudication for any divergence.
- Verdict emitted without the chair's one-liner.
- `inconclusive` avoided when evidence is immature.
- MUST-FIX list unordered, or BLOCKERs mixed with WARNINGs.
- Consensus claimed with fewer than half + 1 of dispatched personas.
- Empty persona results silently ignored.
- SurrealDB write without user confirmation of destination.
- Verdict written with status `decided`.
- Config reviewed without the Data Engineer persona.
- Root password printed to output/logs.
