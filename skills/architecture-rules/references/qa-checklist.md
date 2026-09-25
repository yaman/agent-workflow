# QA checklist

The concrete checklist the `qa` agent works from. Every item maps to a rule
in the skill body. Check each item that applies to the scope; mark PASS /
VIOLATION / UNVERIFIED with evidence (file:line).

## Universal rules (Part 1)

- [ ] **Contracts typed:** every boundary (events, API req/res, DB rows, wire types) is a typed contract with named fields. No `serde_json::Value`, `any`, `unknown`, `Record<string, unknown>` as contract payloads.
- [ ] **Vocabulary designed up front:** no evidence of contract variants accreted task-by-task (e.g. an enum that grew 10+ variants with per-variant story comments).
- [ ] **Store per access pattern:** no single store holding log + graph + projections; no 500+ line adapter re-implementing arbitration/fencing/compaction a store already does.
- [ ] **Module seams justified:** no shim modules (module that only re-exports), no crate/package split by chronology, no git-rev-pinned deps for code under active iteration.
- [ ] **One source of truth per type:** no hand-mirrored types (canonical struct + hand-maintained proto/TS mirror held in sync by a test).
- [ ] **File size:** no code file over ~1,500 lines; no Svelte component over ~400.
- [ ] **Why-comments:** comments explain why in domain terms; no ticket/story references in function headers.
- [ ] **Design gate:** no contract/store/module-boundary change without a prior design note.

## Rust rules (Part 2) — for .rs files

- [ ] **Typed serde structs** at every JSON/API/DB boundary; `serde_json::Value` only for opaque passthrough.
- [ ] **`deny_unknown_fields`** on strict inputs; never combined with `flatten`.
- [ ] **Newtypes** for IDs and validated values.
- [ ] **Tagged enums** over string constants; discriminants never renumbered/reused.
- [ ] **Errors:** `thiserror` enums in libraries, `anyhow` + `.context()` at boundaries in binaries; `#[non_exhaustive]` on public error enums; no `unwrap` outside tests and main.
- [ ] **No leaked infra errors to API clients** — generic error at layer boundary, full chain logged server-side.
- [ ] **Async:** no blocking calls in async paths (no `std::thread::sleep`, no blocking locks); `JoinSet`/`TaskTracker` over fire-and-forget spawns; timeouts on awaits crossing trust boundaries; graceful shutdown via CancellationToken + TaskTracker.
- [ ] **Ports/adapters:** domain depends on traits, not adapters; clock injected.
- [ ] **Edition 2024** idioms (no `once_cell`, no `|| async {}` where `async || {}` fits).
- [ ] **Workspace:** versions in `[workspace.dependencies]`, shared `[workspace.lints]`, no crate under ~500 lines with one dependent.

## Svelte rules (Part 3) — for .svelte / frontend .ts files

- [ ] **Runes:** `$state` only for reactive state; `$derived` for computed; `$effect` only for browser-only side effects, never updating state inside an effect, never wrapped in `if (browser)`.
- [ ] **No `$effect` for derived state** — the #1 Svelte 5 anti-pattern.
- [ ] **Data through `load` functions** — no `fetch` in components when a load exists.
- [ ] **Load functions pure** — no side effects, no writing to stores/global state; no per-user data in module-level `$state`.
- [ ] **Forms:** form actions + `use:enhance`; server-side validation; `fail()` for validation errors; `redirect(303)` after success.
- [ ] **State:** runes over stores for new shared state; typed `createContext` over prop drilling; state as local as possible.
- [ ] **Components:** under ~400 lines; callback props over `createEventDispatcher`; `$bindable` only for form-control-like components; snippets over slots; keyed `{#each}`.
- [ ] **TypeScript strict:** props typed (interface for `$props()`), stores typed, `load` returns typed, `./$types` used.
- [ ] **a11y:** no `a11y_*` warnings silenced; real buttons, labels, focus management.

## TDD rules (Part 4) — for any change

- [ ] **Failing test first:** test written before implementation, red for the right reason (behavior missing, not a typo).
- [ ] **No test+code same pass** — no tautological tests mirroring the implementation.
- [ ] **Test files untouched during implementation** — no deleted assertions, no `.skip`, no weakened expectations, no implementation special-cased to the test.
- [ ] **Tests test behavior, not implementation** — query by role/label/text, not internal state.
- [ ] **AAA structure; one behavior per test; names read like bug reports.**
- [ ] **No pasted computed values** in assertions.
- [ ] **Test strategy:** mocks only at boundaries; real dependencies (testcontainers) for DB/queue/HTTP; property tests for round-trips/invariants; coverage not chased to 100%.

## Clean code rules (Part 5) — for any code

- [ ] **Full-word names** — no abbreviations or single letters; domain vocabulary.
- [ ] **One level of abstraction per function** — splitting reduced global complexity, not just line count.
- [ ] **No entanglement** — no conjoined methods; no tiny functions from aggressive extraction.
- [ ] **No shallow interfaces** — no methods whose implementation is as complex as the abstraction they hide.
- [ ] **Guard clauses / early returns** — happy path last at one indentation level; no 12-guard functions (extract a validator).
- [ ] **No state smuggling** — no class/instance state used to pass parameters.
- [ ] **Complexity:** cyclomatic ≤ ~10 (hard 15); cognitive ≤ ~10.
- [ ] **Comments:** why, non-obvious, interfaces — never "what" restatements; updated in the same commit.
- [ ] **Duplication:** no wrong abstractions (extract → parameter → conditional → unreadable); duplication tolerated when local and obvious.
- [ ] **No dead code / commented-out code.**
- [ ] **No agent failure modes:** no silent overengineering (200 lines where 50 suffice), no unsolicited cosmetic changes to adjacent code, no hidden assumptions, no pruned why-comments.

## Rationalization table check

Flag any code that embodies one of these:

| The code thinks… | Reality |
| --- | --- |
| "The discriminator is already written to disk; I'll just append one more variant." | Growing a vocabulary committed before it was complete. |
| "This index/uniqueness constraint makes the race impossible." | Hand-rolled arbitration = wrong store. |
| "I'll extract this module now; it can be its own package later." | Every extraction changes the seams. |
| "This is just one more event kind / store / crate / endpoint / field." | Contract, topology, or boundary decision. Design note first. |
| "I'll write the test and the code together — faster." | Tautological tests, no red phase. |
| "This test is flaky, I'll just skip it for now." | A skipped test is a deleted test. |
| "These 3,000 lines are fine, it's all related." | Unreviewable, undiffable, uneditable. Split by concern. |
