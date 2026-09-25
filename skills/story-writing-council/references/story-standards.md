# Story Writing Standards

Source: established story-writing standards for agent execution. Stories for
agent execution live in SurrealDB (`ns=${backlog.namespace}`, `db=${backlog.db}`,
table `${backlog.table}` — from `workflow.config.toml`), never in ephemeral
plan files.

## Rules

- **Max 3 acceptance criteria (ACs) per story.** If a story needs more than 3
  ACs, or any AC is huge, split the story (e.g. `S3a`/`S3b`) and record the
  split in the story body.
- **ACs MUST be written as proper Gherkin** — each AC is a scenario block
  with the `Given` / `When` / `Then` keywords each on their own line. Inline
  prose with run-together keywords is not acceptable.
- **Exactly one scenario per AC.** No `And`-chaining multiple scenarios; no
  multiple Given/When/Then per AC.
- **Zero assumptions:** AC bodies must name exact field names, version pins,
  env var names, thresholds, and error strings — nothing left for the
  developer to invent.
- **INVEST:** Independent (via explicit `depends_on` edges), Negotiable
  (outcomes not implementation), Valuable, Estimable, Small (single ATDD
  session), Testable.
- **Mandatory breakdown triggers:** >3 ACs, multi-repo work, mixed concerns
  (e.g. test infra + feature), or any AC too large for one ATDD session.

## User-perspective rule (the A of ATDD)

- **The acceptance test is written from the USER's perspective** — what the
  user clicks, types, sees, and experiences (browser test, Playwright is the
  "A"). Not a unit test of a backend artifact.
- **No backend-only stories.** Backend changes are enforced from the user
  perspective: every story must be a user-visible feature; backend work
  (services, relays, adapters, engine seams) is folded in as implementation
  detail of a user-facing story. A story that names a backend artifact as
  its outcome is a symptom of a missing user story — re-derive the user
  benefit first.
- **Evolutionary architecture:** build small enough and valuable enough
  for the user with each story. An **epic** is the full benefit package
  delivered to the user; every story in the epic builds up to that benefit
  package step by step, iteratively. If a story idea contains multiple
  user-visible benefits, it is an epic — break it down into stories, each
  delivering one increment of the benefit package, each a single ATDD
  session.
- **One story = one user journey increment.** The user journey statement
  must be a single action — no "and", no semicolons, no lists. "I see my
  sessions and open one" is two stories. "I see commands and file changes"
  is two stories. If the journey needs "and", split the story.
- **Breakdown test:** if a story's ACs would need more than 3 user-visible
  behaviors, or the story spans multiple user journeys, split it. Each story
  = one user journey increment, one ATDD session, ≤3 ACs.

## Gherkin AC format (exact)

Each AC is a block:

```
AC1: <short scenario title>

- Given <precondition, fully pinned: exact inputs/config>
- When <single action>
- Then <single observable outcome, exact expected values>
```

Example:

```
AC1: pure defaults on empty load

- Given no config file and no env vars
- When load(None) is called
- Then the returned Config has bind_addr "127.0.0.1:8777", org_id "default", project_id "default", log_level "info"
```

## Story body preamble

Every story body starts with:

1. An **"Epic:"** line (epic scope).
2. An **"Outline:"** block in user-story form: `As a user, I want to <action>, so that <benefit>.`
3. A **"Decision details (zero assumptions)"** section pinning the technical decisions before the ACs.

## AC heading format

Each AC heading is `AC1: scenario: <what the user achieves>` followed by the
Gherkin block (see "Gherkin AC format (exact)" above). Example:

```
AC1: scenario: user achieves locked identifiers verbatim

- Given ...
- When ...
- Then ...
```
