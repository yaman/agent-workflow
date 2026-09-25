# SurrealDB Schema — map db + run db

Every project has its own namespace: `ns=<namespace>` (from `workflow.config.toml` `${backlog.namespace}`). Two databases by default: the map (backlog + plan) and the run (active execution). No separate backlog db — the iteration map IS the backlog. A project may instead use the single-db model (`backlog.mode = "single-db"`, the `story-writing-council` shape); this file describes the default two-db model.

## db = map (`${backlog.map_db}`, default `iteration_map`) — the whole project's backlog + plan

Write-once within an iteration; stable. Record links are legal here (same db).

### `epic`

| Field | Type | Notes |
|---|---|---|
| `id` | record | `epic:<slug>` |
| `title` | string | e.g. "B1 — Runtime failure Detector" |
| `description` | string | |

### `story`

| Field | Type | Notes |
|---|---|---|
| `id` | record | `story:<slug>` — build with raw-identifier form `story:⟨{slug}⟩`; hyphenated slugs get backticks in queries (``story:`s6-7a` ``) |
| `title` | string | user-story form |
| `epic` | record link | `epic:<slug>` |
| `status` | string | `todo / in-dev / in-review / done`; **`planned`** = authored but gated behind a not-yet-written phase spec (never pickable — the poll selects `todo` only); `superseded` = replaced by a split |
| `estimate` | int | AC count |
| `phase` | record link | `phase:<slug>` — the delivery phase this story belongs to (optional; set when a spec is split into phases) |
| `depends_on` | array<record link> | `[story:<dep-1>, ...]`; in = dependant, out = dependency |
| `acs` | array<object> | `[{ key, title, gherkin: { given, when, then } }]` — structured, NOT body text |
| `tech_brief` | object/string | written by the architect agent at pickup; per-AC sections |

### `phase`

First-class delivery phases, so multi-phase specs don't get forgotten or confused. Stories reference `phase:<slug>`; a phase gates its stories by keeping their status `planned` until the phase's spec is written (then flip to `todo`).

| Field | Type | Notes |
|---|---|---|
| `id` | record | `phase:<slug>` (e.g. `phase:p1`) |
| `order` | int | delivery order (1, 2, 3, …) |
| `name` | string | human label |
| `status` | string | `planned / active / done` |
| `deliverable` | string | one-line outcome of the phase |
| `spec_path` | string/null | the phase's spec doc on disk (null until written) |
| `plan_path` | string/null | the phase's plan doc on disk (null until written) |
| `spec_status` | string | `not-started / pending / written` |
| `deferred` | array<string> | design decisions the phase's spec must resolve (the open items it inherits) |
| `notes` | string | free text |

**Phase dashboard:**

```sql
SELECT phase.order AS p, phase.name AS phase, count() AS stories, math::sum(estimate) AS acs
FROM story WHERE epic = <epic> GROUP BY phase ORDER BY p;
```

### `decision`

| Field | Type | Notes |
|---|---|---|
| `id` | record | `decision:<slug>` |
| `title` | string | |
| `kind` | string | `stack` (languages/frameworks/dbs/versions) or `architecture` (per-layer code architecture) |
| `content` | string | the decision, verbatim |
| `reviewed_at` | datetime | amendment gate |

## db = run (`${backlog.run_db}`, default `iteration`) — active execution

Mutable; the single source of truth for "what is happening right now".

### `iteration`

The iteration's plan header (successor of the writing-plans header block).

| Field | Type | Notes |
|---|---|---|
| `id` | record | `iteration:<slug>` |
| `name` | string | |
| `goal` | string | one sentence |
| `architecture` | string | 2-3 sentences |
| `tech_stack` | string | |
| `constraints` | array<string> | |
| `status` | string | `planned / active / done` |

### `story_run`

Per-story execution state. References the map's story by STRING key — SurrealDB record links do not cross databases, so `story_id` is `"story:<slug>"`, never a link.

| Field | Type | Notes |
|---|---|---|
| `id` | record | `story_run:<slug>` |
| `story_id` | string | `"story:<slug>"` — join key into the map db's `story` |
| `status` | string | `todo / in-dev / in-review / done` |
| `current_ac` | string | `"ac1"` .. `"acN"` |
| `started_at` | datetime | |
| `finished_at` | datetime | |
| `acs` | array<object> | `[{ key, status: pending/red/green, evidence }]` — evidence = `<file:line>` |

## Status hygiene

- Every AC transition (`pending → red → green`) and every story status change is written to the run db IMMEDIATELY, with evidence and timestamps. Never batch status updates at the end of a session.
- The iteration db must answer "what is running, where, with what evidence" without touching the map.
- Map statuses flip when the run starts (`in-dev`), enters review (`in-review`), and completes (`done`).

## Ready-for-pickup poll (map db)

```sql
SELECT id, title, estimate FROM story
WHERE status = 'todo'
AND array::len(array::filter(depends_on, |$d| $d.status != 'done')) = 0
ORDER BY estimate ASC;
```

The only place an implementer may pick from. `story_run` is created in the run db at pickup.

**Why not `->depends_on->story`:** `depends_on` is an `array<record link>` field, not a RELATE edge, so it is dereferenced as `depends_on.status`. The graph-traversal form `->depends_on->story` returns an empty set for every story, which makes the poll return *every* todo story — a silent correctness bug (it unblocks blocked work).

## Record-id note (SurrealDB gotcha)

Build record ids with the raw-identifier form `story:⟨{id}⟩` (e.g. `story:⟨atdd-core⟩`). A raw `story:{id}` with a hyphenated id mints at a truncated record id (SurrealDB parses dashes as subtraction) and silently collides with other hyphenated ids of the same prefix. When emitting ids in queries, re-wrap any id containing `-` as ``story:`<id>` ``.

## Credentials

Resolved at runtime, never embedded. See this skill's `references/configuration.md` for the resolution order (host MCP config → `WORKFLOW_SURREAL_PASSWORD` → ask the user). Never embed or echo credentials.
