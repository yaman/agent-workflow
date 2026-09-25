---
name: story-atdd-workflow
description: "Use when starting work on any project that follows the story-driven workflow — writing project stories (\"write the stories\", \"turn this spec into stories\", \"story council review\"), setting architecture decisions (\"architecture decisions\", \"decide the stack\"), converting a spec into SurrealDB stories, picking up a story for execution (\"pick up story\", \"develop the story\", \"implement AC1\"), or any feature work that must be driven by per-AC acceptance tests in a SurrealDB iteration (per-project namespace, backlog + run databases). Replaces writing-plans/executing-plans: after brainstorming produces a spec, stories are written into SurrealDB and each AC is implemented as a vertical slice green one at a time. Also use when asked to set up or explain the workflow for a new project. Project-specific values (namespace, databases, deploy commands, traversal tools) are read from workflow.config.toml — see the skill's references/configuration.md; never hardcode them."
---

# Story-ATDD Workflow

Story-driven development backed by SurrealDB: specs become stories with fully
user-facing Gherkin ACs; each AC is implemented as ONE vertical slice, green at
a time, with the acceptance test written FIRST. There are no plan files. The
backlog + plan live in the map database (`${backlog.map_db}`), active execution
in the run database (`${backlog.run_db}`).

**Resolve configuration first.** All project-specific values below are
placeholders: namespace `${backlog.namespace}`, map db `${backlog.map_db}`, run
db `${backlog.run_db}`, deploy `${deploy.deploy_command}` / smoke
`${deploy.smoke_command}` over `${deploy.environments}`, traversal
`${traversal.primary}` + `${traversal.fallback}`, acceptance `${acceptance.e2e}`
+ `${acceptance.contract}`. Read them from `workflow.config.toml` (or the
machine default, or the documented defaults) per this skill's
`references/configuration.md`. Never hardcode them.

## When NOT to use

- Throwaway prototypes, one-off scripts, pure research — no stories.
- A backlog that uses the single-db, body-embedded AC format — that project
  uses `story-writing-council` instead; never apply the structured `acs` shape
  across both models. `workflow.config.toml` `backlog.mode` selects one
  (`two-db` = this skill, `single-db` = the council).

## The workflow

**Entry — once, before this workflow:** `brainstorming` → a **spec** (a design
doc on disk). This skill *consumes* that spec as its input; it does not produce
it. If work later raises a new design question, that goes back to `brainstorming`
as a **new** spec producing **new** stories — a forward edge with new input,
never a re-entry of the current story. (No plan files: the stories and their
ACs are the plan.)

```
story writing          → map db (${backlog.map_db}): epic + story (ACs are the contract)
architectural decisions → map db: decision (stack + per-layer architecture)
per story at pickup    → architect subagent (agent: `architect`) → tech_brief (per-AC sections) → with the story
per AC, strictly serial → ONE implementer subagent per AC cycle (agent: `developer`, or `rust-developer`/`svelte-developer`
                         for a language-specific slice): acceptance test (copies AC verbatim) RED →
                         vertical slice TDD top-down through clean architecture layers
                         (frontend presentation → application → domain → infrastructure →
                          backend delivery → application → domain → infrastructure) GREEN →
                         commit + merge to main → reports evidence back
                       → DEDICATED refactor subagent (a FRESH `developer` context; dedup/rename/extract, no behavior
                         change; FULL suite green; coverage ≥ baseline) → refactor commit or "no changes"
story green → full suite → statuses → done
```

## Step 1 — Story writing (from a spec)

The spec (from brainstorming, on disk) is decomposed into stories — each story
is one independently valuable vertical slice. For each story:

**Epic + story rows in the map db (`${backlog.map_db}`):**

- `epic { title, description }` — thematic grouping.
- `story { id: story:<slug>, title, epic, status: "todo", estimate, depends_on: [story:...], acs: [...] }`
- `phase { id: phase:<slug>, order, name, status, deliverable, spec_path, plan_path, spec_status, deferred, notes }` — **when a spec spans multiple delivery phases**, create a `phase` row per phase and set `story.phase = phase:<slug>`. This is how phases are tracked so they are never forgotten or confused. A story whose phase spec is not yet written is authored with `status: "planned"` (not `todo`) — `planned` stories are excluded from the pickup poll; flip them to `todo` when the phase's spec lands. `phase.deferred` lists the open design decisions that phase's spec must resolve. Phase dashboard:
  ```sql
  SELECT phase.order AS p, phase.name AS phase, count() AS stories, math::sum(estimate) AS acs
  FROM story WHERE epic = <epic> GROUP BY phase ORDER BY p;
  ```

**Every story body carries:**

1. **Epic line** — the epic this serves.
2. **Outline** — user-story form: `As a user, I want <action>, so that <benefit>.`
3. **≤3 Gherkin ACs** — THE CONTRACT. No separate "decision details" section; the ACs are the decisions.

**AC rules (the essentials — see `references/story-rules.md` for the full text):**

- **Fully user-facing.** Given = user state / config as the user sets it; When = the user's single action; Then = user-observable outcome with exact strings the user SEES and exact values. Technical pinning (file names, RPCs, signatures) NEVER lives in an AC — it goes in the tech_brief.
- **Exactly one scenario per AC** — Given/When/Then each on its own line; no And-chaining, no run-together keywords.
- **Independently implementable vertical slices.** AC(n) must be makeable green alone without AC(n-1)'s code. If it can't, the story was split wrong — re-split before execution.
- **Estimate = the AC count.** Size = how many ATDD cycles it carries.
- **Max 3 ACs.** More, or an AC spanning more than one ATDD session → split (`sXa`/`sXb`).
- **One functionality per AC.** Every AC exercises exactly ONE functionality. An invalid-form AC arranges the invalid state in the Given (e.g. via the authoring/API surface) and asserts the rejection in the When/Then — the rejection itself is the user-observable behaviour.

Write stories into SurrealDB with the `acs` field as structured data:

```
CREATE story:<slug> SET
  title = "...",
  epic = epic:<epic-slug>,
  status = "todo",
  estimate = <AC count>,
  depends_on = [story:<dep-1>, ...],
  acs = [
    { key: "ac1", title: "scenario: <what the user achieves>",
      gherkin: { given: "...", when: "...", then: "..." } },
    ...
  ];
```

- **Ready-for-pickup poll:** `SELECT id, title, estimate FROM story WHERE status = 'todo' AND array::len(array::filter(depends_on, |$d| $d.status != 'done')) = 0 ORDER BY estimate ASC` — the only place an implementer may pick from. (`depends_on` is an `array<record link>` field, so it is dereferenced as `depends_on.status`; `->depends_on->story` only works for RELATE edges and would silently return every story.)
- Write stories in `depends_on` topological order; verify acyclicity before finishing.
- Review with the council: the story-writing-council personas (or a slimmed review gate — 2-3 lenses suffice for spec-derived stories) review the ACs' zero-assumptions, user-facing wording, and vertical-slice independence BEFORE they are executed. Adjudicate every divergence; an unadjudicated review is a failure.
- SurrealDB record-id note: build record ids with the raw-identifier form `story:⟨{slug}⟩` — a raw `story:{slug}` with a hyphenated slug mints at a truncated record id. Hyphenated ids must be backticked in queries.

## Step 2 — Architectural decisions

Before the first story is picked up (per project; amended only via explicit review):

- `decision` rows in the map db (`${backlog.map_db}`):
  - `kind = "stack"`: languages, frameworks, databases, exact versions.
  - `kind = "architecture"`: the code architecture per layer — clean / hexagonal / MVP / MVC / MVVM — and WHERE each applies (e.g. "backend: hexagonal; frontend: feature-first MVVM").
- **Default (when the project has no contrary decision): clean architecture in BOTH.** Backend: delivery → application → domain → infrastructure. Frontend: presentation → application → domain → infrastructure. Dependency rule: dependencies point inward; infrastructure implements ports declared by the inner layers. Layer map + test seams: `references/clean-architecture-layers.md`.
- Decisions are stable within an iteration. Amending is a reviewable act, never silent drift.

## Step 3 — Architect subagent per story (tech_brief)

At story pickup, BEFORE any implementation:

- Dispatch the `architect` subagent (isolated context: the story + its ACs + the project's `decision` rows). It never implements (its permissions are read-only).
- **Codebase traversal is graph-first, symbols fallback — never raw grep.** When `${traversal.primary}` is `gitnexus`, the architect uses the gitnexus MCP tools (`query`, `context`, `impact`, `trace`, `cypher`) — read `gitnexus://repo/{name}/context` first for the overview + staleness check, and re-analyze if the index is stale. When the graph does not resolve a symbol-level question (exact definition, references, diagnostics), and `${traversal.fallback}` is `serena`, use the serena MCP by project name: `activate_project <name>` first, then `find_symbol`/`find_referencing_symbols`/`get_symbols_overview`. Raw grep is only for confirming exact strings/line numbers after a graph/symbol tool has located the symbols. If `${traversal.primary}` is `none`, fall back to glob/grep and say so in the report — never pretend a graph was consulted. The repos to index are the project's own repos under `${project.name}`.
- Deliverable: **tech_brief** — one document, a section per AC, pinning:
  - files to create/modify (exact paths), grouped per clean architecture layer (frontend presentation/application/domain/infrastructure; backend delivery/application/domain/infrastructure),
  - function/method signatures and the ports/interfaces each layer exposes,
  - the test seam per layer (how the layer under test is driven, with its inner unit test),
  - the acceptance test's location/harness (`${acceptance.e2e}`),
  - the contract at the frontend→backend seam (`${acceptance.contract}`): the consumer test's location, the contract's expected request/response shape (path, method, body, status, response fields), and the provider test's location.
- Store the brief WITH the story: `UPDATE story:<slug> SET tech_brief = <brief>;` in the map db (`${backlog.map_db}`). It is the evidence — "why was it built this way" is answered by the approved brief.
- One architect per story (a 3-AC story sharing one slice needs no three briefings); the brief is per-AC sections.

## Step 4 — Per-AC vertical execution (STRICTLY SERIAL, one subagent per AC cycle)

Mark the story in the run db (`${backlog.run_db}`) first: `CREATE story_run SET story_id = "story:<slug>", status = "in-dev", current_ac = "ac1", started_at = <now>;`

Then, ONE AC AT A TIME — never parallel ACs, never "write all acceptance tests first":

**Each AC cycle (architect brief section + TDD) runs in a FRESH subagent.** The main session never implements — it coordinates: dispatch, verify the subagent's report, record status, dispatch the next AC. This preserves the main session's context and gives each subagent a clean, complete brief.

1. **Dispatch the AC(n) implementer subagent** (agent: `developer`, or `rust-developer`/`svelte-developer` for a language-specific slice) with a self-contained brief: the story id, the AC(n) scenario VERBATIM from `acs[n].gherkin`, the tech_brief's AC(n) section (files, signatures, seams, acceptance-test location), the project's `decision` rows, and the commit/merge instruction. **The subagent must traverse the codebase graph-first** (`${traversal.primary}`: `query`/`context`/`impact`/`trace` — read `gitnexus://repo/{name}/context` first; when the graph does not resolve a symbol-level question and `${traversal.fallback}` is available, fall back to the serena MCP by name — `activate_project <name>` then `find_symbol`/`find_referencing_symbols`; raw grep only to confirm exact strings/line numbers after a graph/symbol tool locates the symbols; if the primary is `none`, use glob/grep and say so). The subagent must:
   - write the acceptance test FIRST — the scenario copied VERBATIM from the story's `acs[n].gherkin`. Run it: RED for the right reason. This is the "A" of ATDD.
   - implement the full vertical slice for AC(n) — **layer-by-layer TDD, top-down**: for EACH clean architecture layer in order (frontend presentation → frontend application → frontend domain → frontend infrastructure (API client) → backend delivery (route/controller) → backend application (use case) → backend domain → backend infrastructure (repository/db config)), write that layer's unit test FIRST, run it RED, then implement the layer's logic, run it GREEN — before moving to the next layer. The acceptance test is the outer red loop; each layer's unit test is the inner red loop. If a layer has nothing to add for the current AC, skip it — write exactly enough code to turn the red AC green.
   - **frontend → backend handoff is consumer-driven (`${acceptance.contract}`), not a mock-based client unit test.** The frontend infrastructure layer writes a **consumer test** (RED → implement the API client → GREEN → publish the contract). The backend delivery layer then runs the **provider test against that consumer contract** (RED → implement the route/controller → GREEN) BEFORE its own unit tests — the contract is the seam between the two sides. No `client.test.ts` with a mock transport; the consumer contract replaces it.
   - write exactly enough code to turn the red AC green, nothing more (no building ahead of the next AC).
   - commit and merge to main (worktree → merge back to main; direct branch → commit on main).
   - **deploy + smoke test every environment** — run the project's `${deploy.deploy_command}` (per environment) and `${deploy.smoke_command}`, both defined in `workflow.config.toml` or the project's own AGENTS.md; `${deploy.base_urls}` gives each environment's base URL. A project with `environments = []` has no deploy step — skip this. Deploy is the coordinator's job — do NOT run it inside the AC subagent.
   - report back: the evidence (file:line of the acceptance test), the commit hash, and the merge confirmation. **The report MUST carry, per layer, the exact RED command and its failing output, then the GREEN command and its passing output.** A report without the red evidence is rejected and the AC redone — "I ran it and it passed" is not evidence of TDD; "I ran it and it FAILED for this reason, then it passed" is. **Do NOT run the refactor checkpoint — that belongs to the dedicated refactor subagent (step 2).**
2. **Dispatch the DEDICATED refactor subagent** (a fresh `developer` context — NEVER the implementer whose code it cleans) on the just-green diff: read the diff, remove duplication, improve names, extract helpers, delete dead code — **no behavior change**. Then re-run the FULL suite (must stay green) and measure coverage in every changed repo with that repo's CI ignore-regex. **Coverage must never regress**: it must stay ≥ the recorded baseline (a project-level ratchet, e.g. a `mem:workflow/coverage-ratchet` note — the CI gate is the floor; the ratchet is stricter). A drop fails the checkpoint even when it stays above the CI gate. It commits its work as its own `refactor(<svc>): <ac-slug>` commit (merged to main) OR reports "no changes warranted" with evidence (the diff it reviewed + suite/coverage output). **No AC is recorded green, deployed, or advanced until this subagent has reported.**
3. **Verify the reports** — the implementer's (acceptance test exists, is green, committed on main) AND the refactor subagent's (suite green, coverage ≥ baseline, commit present or a justified no-op). Do not trust reports blindly; spot-check the diffs and the test runs.
4. **Deploy + smoke test in EVERY environment the project defines** (`${deploy.environments}`) — the coordinator deploys (never the AC subagent). Deploying to a subset is not a deploy: **an AC is done if and only if it is deployed to all environments AND its user-observable behaviour is smoke-tested through the full stack in each.** The exact commands and environment list come from `workflow.config.toml` (`${deploy.deploy_command}`, `${deploy.smoke_command}`, `${deploy.base_urls}`) or the project's own AGENTS.md, which overrides. A green pipeline is not a deploy — the artifact may not be live yet. Run the project's smoke seam in each env (liveness route + the AC's acceptance seam). Deploy is the coordinator's job — do NOT run it inside the AC subagent.

   **The real path must be exercised — a double-only path does not count.** When a project runs a deterministic test mode (replay, mock, cassette, dry-run) alongside a real one, a path that exists only in the deterministic arm — or that drops facts the real arm produces — passes the test mode and fails against the real dependency. The live/real arm is the product; the deterministic arm is the harness around it. A feature is done only when exercised against the **live** dependency in at least one environment (or a scripted live-equivalent where the real dependency cannot be made deterministic), and its behaviour must not depend on which mode is running. When an AC's acceptance test is inherently replay-shaped (it asserts a recorded trace), pair it with a **live smoke** proving the same observable on the live path; a replay-only AC is not accepted.

5. **Record it immediately** in the run db (`${backlog.run_db}`):
   `UPDATE story_run SET acs = <... with acs[n].status = "green", evidence = "<file:line>">, current_ac = "ac2";`
6. Next AC. Repeat with fresh implementer + refactor subagents.

**No shortcuts:** if the subagent did not watch the acceptance test fail for the right reason, it does not know it tests the right thing. If implementation was written before the failing acceptance test, it must be deleted and redone from the test. The same holds at every layer: a layer's unit test must be written and seen RED before that layer's logic is implemented — no layer is implemented without its own failing test first.

**The authority split (pinned).** One authority per kind of state, never mirrored: the process state (backlog, stories, phases, decisions, tech briefs, run/AC evidence) lives in SurrealDB — `${backlog.namespace}` (`${backlog.map_db}` + `${backlog.run_db}`); the code, specs, plans, and acceptance tests live in git. Never copy one into the other; when they disagree, each is authoritative for its own kind. The database must answer "what is running, where, with what evidence" without reading the code; the repo must build and pass without reading the database.

## Step 5 — Finish

Last AC green → `story_run.status = "in-review"`, `story.status = "in-review"` in the map → run the full test suite → finishing-a-development-branch (worktree detect, base-branch confirm, merge/PR/keep options). Update both dbs' statuses with evidence + timestamps.

**Definition of done (pinned): an AC is done if and only if it is deployed to ALL environments AND smoke tested there.** A green pipeline is not a deploy; a dev-only check is not all environments. Do not record an AC green, mark a story done, or advance the phase pointer on a subset.

## Commit discipline

- **Every successful AC = one commit, merged to main immediately** — before the next AC starts. The per-AC commit is the checkpoint; main is always green. If the dedicated refactor subagent changes code, its `refactor(<svc>): <ac-slug>` commit is a paired part of the SAME AC (allowed and expected); the rule forbids batching *ACs*, not the refactor commit.
- **Leave no dirty tree.** The tree must be clean at report time: `git status --porcelain` empty, untracked files included. A repo whose working tree is dirty at report time is NOT complete — the dirty state is uncommitted work that must be committed or explicitly deferred by the human. This is not limited to AC work: any change intended to persist (docs, config, a fix) is committed as its own commit the moment it is proven working, and a repo must build from a clean checkout (no committed code may reference an untracked file).
- Worktree flow: implement in the worktree → commit → merge back to main → continue in the worktree (rebase onto main if needed).
- Direct-branch flow: commit on main directly (only when the user has consented to working on main).
- Never batch multiple ACs into one commit; never leave an AC's commit unmerged while starting the next AC.

## Discipline — the failure modes this workflow exists to prevent

- Writing acceptance tests LAST, after implementation (a plan that writes all the e2e specs as its final tasks is the exact anti-pattern).
- Ephemeral plan files carrying both requirements and technical detail (violates "stories live in SurrealDB, never in ephemeral plan files").
- Implementing all ACs' unit layers, then "wiring up" the acceptance tests at the end — the acceptance test per AC is the outer red loop; it gates the slice.
- Implementing a layer without its own failing unit test — each layer is TDD'd in place (unit test RED → logic → GREEN) before the next layer starts; the acceptance test alone does not excuse skipping a layer's inner red loop.
- Mock-based client unit tests instead of a consumer contract — the frontend→backend handoff is consumer-driven: the consumer test records the contract, the provider test verifies it. A `client.test.ts` against a mock transport is the anti-pattern.
- Parallel ACs or parallel implementers on one story — ACs are serial BY DESIGN (evidence trail, per-AC checkpoints).
- Leaving an AC's commit unmerged while starting the next AC — every AC lands on main before the next begins; main is always green.
- The main session implementing ACs itself — each AC cycle runs in a fresh subagent; the main session coordinates (dispatch → verify → record → dispatch next).
- Accepting a report without per-layer RED evidence — "it passed" is not TDD; the report must show the exact failing command and output before the fix, per layer.
- Letting coverage regress at the refactor checkpoint — the refactor re-runs the FULL suite AND measures coverage per changed repo against the project's recorded ratchet; a drop fails the checkpoint even if it stays above the CI gate.
- A dirty working tree at report time — the tree must be clean (`git status --porcelain` empty, untracked included); uncommitted work is uncommitted work.
- Skipping the dedicated refactor subagent, or letting the implementer refactor its own AC — the refactor checkpoint runs in a SEPARATE fresh subagent after the AC is green. Code that only its author has ever cleaned is not clean; the AC is not recorded green/deployed/advanced until the refactor subagent reports.
- Raw-grep codebase traversal instead of the configured graph/symbol tools — the graph (`query`/`context`/`impact`/`trace`) locates symbols and their callers first, the symbol server resolves definitions/references; grep only confirms exact strings/line numbers. Grep-first traversal is how subagents lose the thread and loop.
- Building bottom-up (db config → backend → UI) — the slice is built top-down in the direction the acceptance test drives, through the clean architecture layers; persistence is the LAST layer, not the first.
- Technical pinning inside ACs (file names, function signatures in Given/Then) — that is the tech_brief's job, and it is decided by the architect at pickup, not fixed at authoring time.
- Building ahead of the red test — write exactly enough code to turn the current red AC green, nothing more. If AC(n+1)'s test later goes green without ever being red, you built ahead; the next AC must start red.

## References

- `references/story-rules.md` — full story standards (AC format, INVEST, splitting, estimates).
- `references/surreal-schema.md` — the two-db schema, table shapes, record-link rules, status hygiene.
- `references/clean-architecture-layers.md` — the default clean architecture layer map for frontend + backend, dependency rule, per-layer test seams, and the top-down vertical slice build order.
