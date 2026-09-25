---
name: architecture-rules
description: Use when designing or implementing any Rust backend or Svelte/SvelteKit frontend component — starting a new project or feature, adding an endpoint, event kind, schema, store, crate, module, package, or component, choosing a backing store or database, defining API contracts or wire types, writing tests, a file nearing its size cap, or reviewing code in this stack. Also use when the user asks for architecture rules, coding standards, or best practices.
---

# Architecture Rules

The universal ruleset for every project in the stack: Rust backends, Svelte/SvelteKit frontends, and the seams between them. The rules are drawn from current (2025–2026) community best practice, with sources in `references/research-sources.md`.

## When this fires

At every design moment: the first line of a new project, a new feature, a new endpoint, a new event kind, a new schema, a new store, a new crate/module/package, a new component, a new wire contract, a new test, a file crossing its size cap, or a review of anything in this stack. If you are about to make one of the decisions below, read the corresponding section first.

---

## Part 1 — Universal rules

### 1. Contracts first, typed, designed up front

Every boundary in the system — events, API requests/responses, DB rows, wire types — is a **typed contract with named fields**. No untyped blobs (`serde_json::Value`, `any`, `unknown`, `Record<string, unknown>`) as contract payloads, in any language. The full vocabulary of a contract is designed **before the first write to it**, not accreted story-by-story. A new variant of an existing contract is a **design decision**, not an implementation task: it requires a note covering why the existing vocabulary can't express it and its compatibility semantics.

The compiler is the validator. String-keyed payload access (`payload.get("node")`) turns typos into runtime errors and makes every consumer a guessing game.

### 2. Store per access pattern, not one store for everything

Choose the store for the access pattern: **append-only log → log store or event store**, **graph → graph DB**, **projections/reads → whatever reads them best**. Never put every concern in one store because it's convenient, and never hand-roll what a purpose-built store gives for free — if you're writing a 500+ line adapter that re-implements arbitration, fencing, or compaction that a store already does, stop and change the store.

### 3. Small modules, justified seams

Start with the fewest modules that hold the system: **core (types + ports), engine (logic), entrypoints (CLI/API/UI)**. Every new crate, package, or module needs a **justification for the seam** — what crosses it, why it can't stay where it is. Never split by chronology ("this was extracted in phase 2") — split by what the thing is. No git-rev-pinned external repos for code you iterate on: a pinned rev is a release boundary, not a dev boundary. If two pieces evolve together, they live in one workspace.

### 4. One source of truth per type

Never hand-mirror a type across a boundary — canonical struct + hand-maintained protobuf mirrored by a golden test, JS types hand-copied from an OpenAPI spec, DTOs re-typed per service. **Generate the downstream types from the canonical source, or make them the same thing.** Two sources of truth held in sync by a test is a time bomb.

### 5. File size discipline

**No code file over ~1,500 lines; no Svelte component over ~400.** When a file crosses its cap, split by concern — each unit with one clear purpose, communicating through defined interfaces. A file that size is a liability for editing, reviewing, and diffing.

### 6. Comments explain why, in domain terms

Comments say what the invariant is, why the order matters, what failure mode the code guards against. Task/ticket references live in **commit messages**, not function headers — code written for the ticket system reads poorly to the next maintainer.

### 7. The design gate — implementation doesn't make architecture

Architecture accreted task-by-task is how you get shim modules and vocabularies committed before they were complete. **No implementation starts until the design doc pins the seams**: contracts, store topology, module boundaries, wire types. Implementers execute the pinned seams; they do not extend them. A story/task that touches a contract, store, or module boundary without a prior design note is rejected.

---

## Part 2 — Rust rules

### Contracts and types

- **Every JSON/API/DB boundary is a typed serde struct.** `serde_json::Value` is for opaque passthrough only, never a contract. Use `#[serde(rename_all = "camelCase")]` at the container level, `skip_serializing_if = "Option::is_none"` instead of emitting null, `default` for forward-compatible config, internally tagged enums (`tag = "type"`) for JSON polymorphism.
- **No runtime-only JSON shapes — anywhere, not just at boundaries (pinned 2026-09-11).** A structured shape that exists only as `serde_json::Value`/`json!` has no compile-time contract: a renamed key, a dropped field, or a wrong variant is a runtime bug — and in a content-addressed canonical form it is a *silent hash change*. Model every structured shape as a named `#[derive(Serialize, Deserialize)]` struct/enum — canonical forms, journal/event payloads, cassettes, internal RPC bodies, config — and let `serde_json` be only the transport that serializes the typed value. `json!` is permitted only for genuinely opaque, schema-less passthrough (never for a shape the domain knows). Canonicalization is the serialization of typed canonical structs (`CanonicalDoc` and friends); a hand-built `json!` tree is exactly the violation this rule names. Corollary: a `*_json` helper that returns `serde_json::Value` is a smell — it should return a typed value or serialize a typed struct.
- **`deny_unknown_fields` on strict inputs** (config files, internal RPC) to catch typos — but never combine it with `flatten` (documented footgun; pick one per struct).
- **Newtypes for IDs and validated values.** `struct UserId(u64)` distinguishes IDs at compile time for free with `#[repr(transparent)]`; `#[serde(transparent)]` keeps the wire format identical. Encapsulate validation in the constructor — an `Email` value is valid by construction.
- **Tagged enums over string constants.** Discriminants and serialized names are permanent once something is written to disk or the wire. Design the variant list before first release; append-only after — never renumber, never reuse a freed value.
- **Zero-copy types (`&'de str`, `Cow<'de, str>`) only as short-lived parse views near the transport**; convert to owned types at task/queue/storage boundaries. Don't adopt lifetimes across the domain without profiling.

### Errors

- **Libraries expose `thiserror` enums; applications collect with `anyhow`.** The boundary decides: library modules return concrete `#[derive(Error)]` enums callers can match on; the binary gathers them with `anyhow::Error` + `.context()`. `anyhow` is fine inside a library's internals and tests — the rule is about the exposed boundary.
- **`.context()`/`.with_context()` at every trust boundary** (network/file/parse) — every `?` gets a breadcrumb. Use the closure form when the message costs a `format!`.
- **Mark public error enums `#[non_exhaustive]`** so adding variants stays semver-safe; keep variants as fine as what callers actually branch on. `#[from]` on wrapped errors enables `?`.
- **Panic for bugs, `Result` for runtime conditions.** Litmus test: "could a correct program, given valid inputs, still hit this?" Yes → `Result`; only wrong code → `panic!`/`expect("reason")`. Never `unwrap` user input, network calls, or file I/O. Panic is fine at startup, in tests, and for provable invariants.
- **Never leak infrastructure error details to API clients.** Map to a generic error at the layer boundary; log the full chain server-side (`{:#}` prints the "Caused by:" chain), return sanitized messages.
- **`miette` (or `color-eyre`) for user-facing CLI diagnostics** — source snippets, labels, help text. The `fancy` feature lives only in the top-level binary, never in libraries.

### Async (tokio)

- **Never block the executor.** Blocking syscalls/locks in async tasks starve other tasks — use `spawn_blocking` for sync I/O and CPU-heavy work.
- **Structured concurrency: prefer composing futures over spawning tasks.** A dropped future is cancelled safely; a spawned task with a dropped handle is fire-and-forget. If you must spawn, use `JoinSet` (completion-order results, batch abort, cancel-safe in `select!`) or `TaskTracker` for graceful shutdown.
- **Timeouts everywhere an await crosses a trust boundary**: `tokio::time::timeout` per external call, plus overall request budgets.
- **Graceful shutdown = detect (`ctrl_c` + SIGTERM) → notify (`CancellationToken`) → wait (`TaskTracker::close().wait()`).** Explicit async shutdown methods, never `drop`.
- **`tracing` + `tracing-subscriber` with `EnvFilter`**, spans carry request context across awaits; `tokio-console` for task visualization. Keep telemetry out of hot loops.
- **`async fn` in traits**: beware the unsolved send-bound problem — you can't bound the returned future's `Send` without `trait-variant` or RTN syntax. The T-types team itself warns against `async fn` in public API traits.

### Structure and tooling

- **Edition 2024** (Rust 1.85+, Feb 2025). `impl Trait` now captures all in-scope lifetimes (old `Captures`/outlives tricks just work); `Future`/`IntoFuture` are in the prelude; use `async || {}` closures instead of `|| async {}`; drop `once_cell` for `LazyLock`. `cargo fix --edition` handles the migration, but review its inserted `use<..>` bounds.
- **One workspace, flat `crates/` directory, all versions in `[workspace.dependencies]`**, shared `[workspace.lints]`, one `Cargo.lock`. Split by function, not by layer. A crate under ~500 lines with one dependent shouldn't be a crate.
- **`[workspace.lints]` centralizes policy; CI gates `clippy --all-targets --all-features -D warnings`.** Enable `pedantic`/`nursery` at warn, cherry-pick denials (`unwrap_used`, `dbg_macro`, `todo`), explicitly allow noisy ones (`module_name_repetitions`, `too_many_lines`). Prefer `CARGO_BUILD_WARNINGS=deny` (Cargo 1.97+, no cache invalidation) over `RUSTFLAGS=-Dwarnings`. Avoid `#![deny(warnings)]` in source — new lints break old builds.
- **CI jobs: separate lint / test / coverage / security.** `rust-toolchain.toml` pinned, `--locked` everywhere, `cargo-llvm-cov` (source-based; preferred over tarpaulin), `cargo-deny` for advisories/licenses, `cargo-semver-checks` on library releases, `cargo test --doc` as its own step (nextest doesn't run doctests).
- **Feature flags: name by capability not implementation** (`postgres-support`, not `with-sqlx`); additive only; `dep:` syntax for optional deps; test combos with `cargo hack --each-feature`. Mutually exclusive features for runtime behavior is a config problem, not a feature problem.
- **Declare `rust-version` (MSRV)**; commit `Cargo.lock` for binaries.
- **Performance: profile first, then optimize only measured hot paths** (`perf`/flamegraph/criterion, `black_box`). Allocation discipline over micro-tuning: `with_capacity`, iterator `collect()` over manual push loops, `Box<[T]>`/`Arc<[T]>` for immutable owned sequences. Release profile: `opt-level=3`, thin LTO; `panic="abort"` only for services that never `catch_unwind`. Trust the compiler — newtypes and iterators are free.

### Ports/adapters

- **Ports = traits, adapters = impls; the domain depends on traits only, arrows point inward; one composition root.** Use `Arc<dyn Trait>` in application services for swappability and compile time; keep generics for hot internal paths. "Generics optimize behavior, `dyn Trait` optimizes change."
- **The clock is injected** — determinism and testability follow.
- **Design traits object-safe from the start** if they may become trait objects (no generic methods, no `Self` in non-receiver position); use `where Self: Sized` to exclude specific methods.

---

## Part 3 — Svelte rules

### Runes — reactivity

- **Svelte 5 runes everywhere.** `$state` for state that actually drives reactivity (template, `$derived`, `$effect`) — everything else is a plain `let`. Over-declaring state is the Svelte 5 equivalent of React's `useState`-everything habit.
- **`$derived` for anything computable from state; `$effect` is an escape hatch.** Effects "should mostly be avoided," and you never update state inside an effect. `$effect` is for browser-only side effects (analytics, DOM interop, subscriptions, persistence) with a cleanup return — it never runs on the server, so never wrap it in `if (browser)`.
- **Prefer event handlers over `$effect` for reacting to user interaction** — "don't react to state changes, react to events." Logic goes in `onclick`/callback props, not in effects watching state.
- **Treat props as if they will change** — derive from props with `$derived`, never compute once at init (it silently goes stale).
- **`$state.raw` for large, effectively-immutable data** (API responses, config blobs) reassigned wholesale — deep proxies have overhead. Default to `$state` otherwise; don't reach for raw "for performance" without profiling.
- **Know where the proxy stops:** destructuring a `$state` object captures a frozen value; `$state(new Foo())` does NOT make class instances reactive — use `$state` fields on the class.
- **Use `$inspect.trace` to debug reactivity** — first line of an `$effect`/`$derived.by` shows which dependency triggered an update.

### SvelteKit — data, forms, SSR

- **Data flows through `load` functions — no `fetch` in components when a load exists.** Server `load` (`+page.server.ts`) for secrets, DB access, cookies; universal `load` (`+page.js`) for public API fetches and non-serializable data. Use the load-provided `fetch` (inherits cookies, inlines responses into SSR HTML).
- **Keep `load` functions pure — no side effects, no writing to stores/global state** (the #1 SSR data-leak vector). Per-request data flows: `load` return → `setContext`/`getContext` (or `event.locals` in hooks). Never store per-user data in module-level `$state` — it's shared across all users on the server.
- **Avoid `await parent()` waterfalls** — call independent fetches before awaiting parent data. Stream slow, non-essential data by returning promises from server loads (with a noop `.catch()` on non-SvelteKit promises).
- **Forms: form actions + `use:enhance`** — works without JS; `fail()` for validation errors (preserve submitted values); `throw redirect(303)` after success (PRG); `throw error()` for unexpected errors. Validate on the server always.
- **URL-addressable state (filters, sort, pagination) lives in search params**, not component state — it survives reloads and feeds SSR.

### State management

- **Runes replace most stores.** Shared reactive logic lives in `.svelte.ts` modules; the canonical app-wide client-state pattern is a class with `$state` fields exported as a `const` instance. Stores remain valid for RxJS interop, third-party contracts, and legacy code.
- **Context over prop drilling and over module state.** Use a typed `createContext` wrapper rather than raw `setContext`/`getContext`; context scopes state to a component tree and is SSR-safe.
- **Keep state as local as possible** — promote to module-level class store only when several components genuinely share it; scope through context the moment SSR enters the picture.

### Components

- **Components are small and single-purpose** — split at ~400 lines. One component = one job; no logic in markup (compute in the script block, reference variables).
- **Callback props replace `createEventDispatcher`** (deprecated): `onclick?: (data) => void`. Type `$props()` with an interface (it's `any` by default).
- **`$bindable` sparingly** — only for form-control-like components where the child genuinely co-owns the value; overuse "can make your data flow unpredictable." Prefer callback props when the parent should decide how to handle a change.
- **Snippets replace slots** — `{#snippet}` + `{@render}`, typed as `Snippet`/`Snippet<[arg: T]>` props.
- **Keyed `{#each}` blocks** (never index as key) for surgical DOM updates; style children via CSS custom properties (`--color`), not `:global` hacks.

### TypeScript

- **TypeScript strict everywhere.** Every prop typed, every store typed, every `load` return typed.
- **Use generated `./$types` everywhere** — `PageServerLoad`, `Actions`, and `PageProps`/`LayoutProps` give end-to-end type safety from `load` return to `data`/`form` props with zero hand-written types.
- **Shared types come from the canonical source (rule 4)** — a generated `types.ts` from the backend contract, not hand-copied DTOs.

### Quality gates

- **Treat every `a11y_*` compiler warning as a bug to fix, not noise to silence** — Svelte is the only mainstream framework with compile-time a11y checks. `svelte-ignore` only for documented false positives; run `svelte-check --fail-on-warnings` in CI; add `@axe-core/playwright` for runtime checks.
- **Performance is mostly free** — fine-grained signals mean only dependent DOM nodes update; `$derived` is lazily evaluated. No manual memoization needed; the main costs to manage are deep proxies and unnecessary effects.
- **Colocate route-specific code in the route tree; only shared utilities go in `$lib`** ("put as much logic as close to the page as possible"). Use `$lib/server` for server-only code (enforced boundary).

---

## Part 4 — TDD rules

### The discipline

- **Test-first is a design discipline, not a coverage tactic.** The failing test forces interface decisions before implementation; the test suite is a side effect, design is the point.
- **One test at a time; cycles in minutes.** A single red→green→refactor cycle should take minutes, not hours — >15–20 min means the increment is too large, split it. Watch it fail for the right reason (behavior missing, not a typo): a test that passes on first run is testing nothing.
- **Green = minimal code; refactor is non-optional.** Hardcode if necessary; don't solve future tests (triangulation — don't generalize from one example). The refactor step is where TDD's design benefit actually happens; skipping it is the #1 pitfall.
- **Never paste computed values into assertions** — copying actual output into expected values defeats the double-checking that creates TDD's validation value. Two hats: "make it run, then make it right" — never mix refactoring into red→green.
- **Test behavior, not implementation.** "The more your tests resemble the way your software is used, the more confidence they can give you." Query by role/label/text, not class names or internal state. A unit needing 5 mocks signals 5 responsibilities.
- **AAA (Arrange-Act-Assert); one behavior per test; a failing test name should read like a bug report.** Names state behavior, context, outcome (`givenX_whenY_thenZ`). Tests are first-class code — same naming, refactoring, and cleanup standards; delete or rewrite tests that consistently fail for unclear reasons rather than skipping them.

### Strategy

- **The pyramid ratio is a starting point, not a law:** ~70% unit / 20% integration / 10% E2E by count. More important: audit where your last 20 production bugs escaped, then thicken that layer. For frontend, the **Testing Trophy** applies — "write tests. Not too many. Mostly integration." (static analysis base, thin unit layer, largest integration layer, thin E2E cap).
- **Mock at boundaries only; prefer real dependencies.** "Only mock types you own" — the port at the process boundary (HTTP, DB, filesystem, queue). Classicist (Detroit) by default: test behavior with real collaborators; mock only unmanaged process boundaries.
- **Every test creates its own fixture from scratch** — same result regardless of order. Use factory functions/builders, not shared mutable fixtures.
- **Test composition over duplication:** 4 computation variants + 5 reporting variants + 1 wiring test = 10 tests instead of 20. Redundant tests (whose pass/fail creates no new information) can be deleted.
- **Property-based tests complement (never replace) example tests.** Good properties: round-trips, invariants, oracles, idempotence. proptest (Rust) over quickcheck for constrained strategies and shrinking; **commit `.proptest-regressions`** — each found counterexample becomes a permanent regression test.
- **Coverage measures execution, not assertion quality.** Don't chase 100% — target the honest signal (mutation testing) on critical modules; coverage targets incentivize testing implementation details.

### Language specifics

- **Rust:** three-tier pyramid — unit (`#[cfg(test)] mod` in source), integration (`tests/`, public API only), doctests. **The lib/bin split is the single most important testability decision** (thin `main.rs`, all logic in `lib.rs`). `cargo nextest` over `cargo test` (per-test isolation, timeouts, no hanging CI) — but nextest doesn't run doctests, add `cargo test --doc`. **Real dependencies via testcontainers** for DB/queue/HTTP; mock only true boundaries (wiremock for external HTTP); transaction-rollback per test or unique-schema-per-test for DB isolation. **`insta` snapshots for structured text output** (error messages, API bodies) with redactions for timestamps/ids; `CI=true` so snapshots are never silently written.
- **Svelte:** extract logic into `.svelte.ts` modules and unit-test it directly (the docs explicitly prefer this over component tests — test files also need `.svelte` in the name for runes to compile). Component tests via `@testing-library/svelte` (jsdom) or `vitest-browser-svelte` (real browser); wrap `$effect`-using code in `$effect.root()` + `flushSync()`. Test `load` functions and form actions as plain functions. Playwright for critical-user-journey e2e only, suite < 30 min, run on PRs.

### AI-agent discipline (the load-bearing part for agent-written code)

- **The failing test is a contract the agent cannot fake** — an executable spec the agent checks itself, on every iteration. Test-first flips the economics: agents write boilerplate tests in seconds; what they lack is discipline, so the discipline is enforced structurally, not by asking.
- **Write the failing test FIRST, before any implementation code, copying the requirement verbatim.** Then implement the minimum to make it green. Never write test and code in the same pass — that produces tautological tests (~35% of agent-written tests mirror the implementation).
- **One test at a time with agents.** Batching tests lets the agent write implementation that "passes" the batch without being driven by it.
- **Test files are frozen/off-limits during implementation** — an agent that can edit tests can delete them. Review diffs for deleted assertions, `.skip`, or weakened expectations. The agent must not change a failing test to make it pass; it changes the code.
- **Guard against reward hacking** — the documented #1 AI failure mode is deleting failing tests rather than fixing code. Watch for: tests removed, assertions loosened, tests skipped, implementation special-cased to the test.
- **Spec-first → test-first → agent-implement:** write the spec, generate failing tests from the spec (preferably with a different model than the implementer, to avoid correlated failures), agent implements the minimum to pass, human reviews. Spec gaps become visible when tests can't be written from the spec.

---

## Part 5 — Clean code rules

### The stance

The 2024–25 Clean Code controversy (Ousterhout vs Martin, Muratori vs Martin) settled a synthesis: clean code is about **reducing the total information a reader must hold** — via names, one level of abstraction, explicit contracts, and incremental tidying — not obeying a rulebook. Hard line-count rules as a *primary* metric are rejected; "fits in one screen / fits in one agent tool call" are real constraints.

### Naming

- **Full words, never abbreviations or letters.** Controlled experiments: full-word identifiers produce ~19% faster defect detection than abbreviations or single letters; descriptive compound names speed up semantic-defect finding ~14%. Names are the agent's navigation API — distinctive, greppable names make `rg "funcName"` hit the target in one call.
- **Use a shared, domain-specific vocabulary** (ubiquitous language) — the one naming practice everyone endorses: names let a reader who knows the domain navigate without decoding.
- **Name parameters better than locals** — parameter names matter more for comprehension, and bad names actively hurt (code with bad names is comprehended no better than code with single letters).
- **Extract intermediate values into named variables — but only with meaningful names.** Meaningless intermediates hurt comprehension; meaningful ones help in exactly the hard cases.

### Structure

- **"One thing" means one level of abstraction, not one operation** — a function is composed of calls at a single level of abstraction. Splitting purely to shorten functions increases global complexity; splitting should reduce global complexity or code size, preferably both.
- **Beware entanglement (conjoined methods)** — if understanding A requires reading B and vice versa, they're entangled; tiny functions created by aggressive extraction are the leading cause. The fix is often to *combine* them.
- **Beware shallow interfaces** — a method whose implementation is as long/complex as the abstraction it hides is shallow: a few lines saved on the caller at the cost of a jump.
- **Guard clauses and early returns; happy path last, at one indentation level** — settled practice. Guards cut cognitive complexity dramatically. Caveat: 12 guards at the top means the function does too much — extract a validator.
- **Don't use class/instance state to smuggle parameters** — prefer parameters + return values; prefer pure functions.
- **Complexity:** cyclomatic ~10 as a testing metric (hard 15); cognitive complexity ~10 as a readability metric. Spend refactoring budget on **complexity × churn**, not complexity alone — "complexity doesn't cause bugs; *changing* complexity causes bugs."

### Comments and duplication

- **Comments are for why, non-obvious information, and interfaces — never "what" restatements.** The comment-smells taxonomy found misleading comments the most harmful smell and obvious comments the most common. Comment value ranges −30% to +34% by snippet — comments are valuable for structure, context, and complex code.
- **Interface comments are a contract, not decoration** — an interface comment defines which parts of the implementation are expected to stay the same; code alone cannot express this. Public API doc comments (rustdoc/jsdoc) fall here.
- **Comments are code: update them in the same commit.** Outdated comments are worse than none. Prefer fewer, longer block comments over scattered inline noise.
- **Duplication is cheaper than the wrong abstraction** (Sandi Metz): extract → parameter → conditional → unreadable is the canonical failure mode. Abstract when you're confident the abstraction is right; tolerate duplication when it's local and obvious. Rule of three is a heuristic, not a law.

### Process

- **Tidy incrementally, in small reversible steps — "tidy first"** — and land each tidy immediately: if it's hard, don't do it; two reds is a revert. Structure changes are reversible; behavior changes aren't.
- **Dead code and "never" paths get deleted, not commented.** Commented-out code and dead branches are the top source of confusion — and for agent-written code this doubles: agents imitate what they find (~8x more duplicated blocks than human code), so bad patterns in the repo compound into the next generation.
- **Reviews enforce shape, not taste:** entanglement, hidden side effects, wrong abstractions, complexity, contract clarity — not line counts or rule compliance.

### Agent-specific

- **Small files (<~300 lines) fit in one tool call** — a unit of meaning that fits in a single Read avoids pagination and fragmented mental models. This converts "file size" from opinion into token economics.
- **Don't strip agent-authored why-comments in review** — they encode decisions the next agent will need. Greppable names + why-comments + locality are the structural properties of an agent-maintainable codebase.
- **Mechanically enforce invariants** — custom linters, dependency-direction checks, structural tests with remediation instructions embedded in lint messages. Documentation alone doesn't constrain agents.
- **AGENTS.md as a ~100-line table of contents, not an encyclopedia** — pointers to docs/design docs/specs; a monolithic rules file crowds out task context and rots.
- **Guard against agent failure modes:** silent overengineering (200 lines where 50 suffice), unsolicited cosmetic changes to adjacent code, hidden assumptions, pruning why-comments on refactor.

---

## Rationalization table

The rationalizations to watch for — and the reality:

| The code thinks… | Reality |
| --- | --- |
| "The discriminator is already written to disk; I'll just append one more variant." | You're growing a vocabulary committed before it was complete. Design contracts up front, don't grow them under compatibility constraints. |
| "This index/uniqueness constraint makes the race impossible." | Hand-rolled arbitration in the app layer is the symptom of the wrong store, not a feature. |
| "I'll extract this module now; it can be its own package later." | Every extraction changes the seams. Start with the fewest modules and justify every seam. |
| "This is just one more event kind / store / crate / endpoint / field." | Each one is a contract, topology, or boundary decision. Design note first. |
| "I'll write the test and the code together — faster." | Tautological tests that mirror the implementation, and no red phase. Failing test first, then the minimum to green. |
| "This test is flaky, I'll just skip it for now." | A skipped test is a deleted test. Fix it, or delete it and write the behavior test properly. |
| "These 3,000 lines are fine, it's all related." | A file that size cannot be reviewed, diffed, or edited reliably. Split by concern. |

---

## Applying

- **New project:** apply all rules up front. The first design doc pins every seam.
- **Existing codebase:** apply the rules to whatever you touch. Don't refactor the whole repo in one pass — but never extend a pattern this skill forbids. Every new contract, store, module, or test follows the rules even if old ones don't.
