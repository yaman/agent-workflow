---
name: product-verification-council
description: Use when the user asks to verify a product, run a product council, "verify this product", "is this product ready to ship", "review this product", "product verification", "council review" — on a product, feature, demo, spec, or release candidate. Summons a 10-persona parallel council (architect, developer, devops, SRE/performance, QA, devsecops, UX, accessibility, product owner, skeptic) that reviews the product from independent lenses, adjudicates divergences, returns a verdict with severity-tagged MUST-FIX findings, and can write the verdict to SurrealDB (verdict table, status recorded) on request.
---

# Product Verification Council

## Overview

Ten expert personas review a product in parallel, then the chair synthesizes with every divergence adjudicated. Independence comes from parallel dispatch (no shared context); comparability comes from one shared problem block and one deliverable contract per persona. The council catches what a single reviewer misses: architecture debt, capacity cliffs, security holes, test blind spots, UX failures, accessibility gaps, and claims that don't survive contact with the demo.

## When to Use

- User pastes a product/spec/demo/claim → **product mode**: verdict + MUST-FIX list.
- User asks for a pre-release verification → **release mode**: full roster, release bar.
- User asks for a targeted review (e.g. "just the security") → **targeted mode**: subset roster.

**When NOT to use:** pure code review, one-off factual lookups, anything without a product/design/claim to verify.

## Mode detect

- Product/spec/demo/claim text → product mode (default: full roster).
- Release candidate → release mode (default: full roster, release bar).
- Targeted lens request → targeted mode (subset roster, named lenses only).
- Genuinely ambiguous → one clarifying question, then proceed.

## Rosters

- **Full (10):** Architect, Developer, DevOps, SRE/Performance, QA, DevSecOps, UX, Accessibility, Product Owner, Skeptic.
- **Targeted (N):** the named lenses only.
- **Conditional seats** (added when the product warrants, see `references/personas.md`): Data/Analytics (any telemetry, metrics, dashboards, or ML/statistical claims), Compliance/Privacy (any user data, GDPR/CCPA exposure, licensing questions).
- Consensus threshold: ≥ half + 1 of dispatched personas (≥6/10 full).

## Problem block (shared, given to every persona verbatim)

1. The product/spec/demo/claim, verbatim.
2. The mode checklist — read `references/checklists.md`, include the relevant checklist verbatim.
3. The deliverable contract, verbatim (from `references/personas.md` header): verdict sentence; findings with severity (BLOCKER/MUST-FIX/WARNING/INFO) and evidence class (sourced/computed/first-principles); one thing the product gets right.
4. Mode instruction: "Review only — do not modify files. Return findings only."

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
- **Chair's one-liner:** "would this product survive a competent reviewer?"
- **Final verdict:** `ship` / `ship-with-conditions` / `do-not-ship` / `inconclusive` (inconclusive is first-class — a verdict on immature evidence is an error).

## Veto power

Only 4 seats can block a release: **Architect, SRE/Performance, DevSecOps, Product Owner**. Developer, QA, UX, Accessibility, Skeptic findings escalate to BLOCKER only when confirmed by a veto seat. Rationale: these are the seats where a miss is expensive and hard to reverse (architecture debt, capacity, security, product-market fit).

## SurrealDB step (ONLY when the user asks)

1. Read `references/surreal.md`; resolve credentials per its rules.
2. Present the record shape, write as `recorded`, verify by re-reading the record, report the id.
3. Never claim success without the verification read.

## Verification corpus (acceptance runs)

The skill is not done until these pass. Run them before declaring the skill complete:

1. A naive product (no auth, no tests, no load testing, no a11y, no privacy policy) → must independently surface: missing auth, no test strategy, no capacity plan, no accessibility, no privacy/compliance exposure. Missing any of the five = failure.
2. A well-formed product (auth, tests, load-tested, a11y-tested, privacy policy) → must pass with gaps only.
3. A product with a false claim ("handles 10k concurrent users" with no load test) → must flag the claim as unverified, not just as a gap.
4. A targeted security review → must return only security findings, no UX noise.

## Red flags — STOP and fix

- Any persona returned the whole synthesis instead of their own findings.
- Any persona's verdict label contradicts their own findings (e.g. ship-with-conditions with BLOCKERs) — flag and adjudicate, don't silently adopt.
- Synthesis table missing adjudication for any divergence.
- Verdict emitted without the chair's one-liner.
- `inconclusive` avoided when evidence is immature.
- MUST-FIX list unordered, or BLOCKERs mixed with WARNINGs.
- Consensus claimed with fewer than half + 1 of dispatched personas.
- Empty persona results silently ignored.
- SurrealDB write without user confirmation of destination.
- Verdict written with status `decided`.
- Conditional seats skipped when the product warrants them (telemetry present, user data present).
- Root password printed to output/logs.

## References

- `references/personas.md` — the persona lenses and their deliverable contract.
- `references/checklists.md` — the review checklist.
- `references/configuration.md` — how project values (namespace, database) resolve.
- `references/surreal.md` — the opt-in verdict write protocol.
- `references/tool-mapping.md` — subagent dispatch / tool names per harness.
