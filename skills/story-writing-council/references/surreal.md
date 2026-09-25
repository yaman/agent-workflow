# SurrealDB Access (backlog)

Endpoint: `${surreal.endpoint}` (default `http://127.0.0.1:8000`) · Namespace
`${backlog.namespace}` · Database `${backlog.db}` · Table `${backlog.table}`.
All values from `workflow.config.toml` (see this skill's
`references/configuration.md`).

## Credential resolution (never embed credentials in skill files)

1. If the host exposes a `surrealdb` MCP entry, read its `headers.Authorization`
   (`Basic <base64>` where the decoded value is `root:<password>`). The opencode
   path is `~/.config/opencode/opencode.json`; discover the host's MCP config
   rather than assuming that path.
2. Fallback: env var `WORKFLOW_SURREAL_PASSWORD` → username `root`.
3. If neither exists: STOP and ask the user for the SurrealDB root password —
   do not guess.

Set `CRED=$(...decoded root:password...)` and use
`curl -u "$CRED" -X POST --data "<sql>" $ENDPOINT/sql` for all
queries below.

## Queries

Poll for ready (unblocked, not done) stories:

```sql
SELECT id, title, status, estimate FROM ${backlog.table}
WHERE status = 'todo'
AND array::len(array::filter(depends_on, |$d| $d.status != 'done')) = 0
ORDER BY estimate ASC;
```

(`depends_on` is an `array<record link>` field, dereferenced as `depends_on.status`;
`->depends_on->story` only traverses RELATE edges and would return every todo story.)

List all stories:

```sql
SELECT title, id, status FROM ${backlog.table} ORDER BY title;
```

Insert a finished story (title, body with Epic + Decision details + ACs, estimate, depends_on edges):

```sql
CREATE ${backlog.table} SET
  title = "<title>",
  status = "todo",
  estimate = <int>,
  body = "<full story body with Epic line, Decision details, Gherkin ACs>",
  depends_on = [story:<dep-id-1>, story:<dep-id-2>];
```

Move a story to in-dev:

```sql
UPDATE story:<id> SET status = 'in-dev' WHERE id = story:<id>;
```

State machine: `todo` → `in-dev` → `in-review` → `done`.
`depends_on` edges: `in` = dependant, `out` = dependency.

## Mapping operations (whole-backlog remap)

Namespace/database come from `workflow.config.toml`. Tests set both to a
throwaway namespace AND set `${guard.test_mode_env}=1`; with the guard set, the
write helper MUST refuse to run against the real namespace/db (hard guard). All
requests carry the namespace/db explicitly:

```bash
NS=${backlog.namespace}
DB=${backlog.db}
BASE=${surreal.endpoint}
Q() { curl -s -u "$CRED" -X POST --data-binary "$1" -H "surreal-ns: $NS" -H "surreal-db: $DB" "$BASE/sql"; }
```

`CRED` is resolved per the credential rules above and MUST never be echoed,
logged, or printed (decode inline; `set +x` when debugging).

### Load (mapping step 1)

```sql
SELECT id, title, status, body, depends_on, estimate, updated_at FROM ${backlog.table} ORDER BY id;
```

### Snapshot (mapping step 7)

```sql
SELECT id, depends_on FROM ${backlog.table} ORDER BY id;
```

Persist the curl response to `<project>/.workflow/backups/depends_on-<ISO-ts>.json`;
assert the file is non-empty and its record count equals the Load count.
Rollback: for each snapshot row, `UPDATE story:<id> SET depends_on = <original value>;`
(re-run inside the same transaction form below).

### Write (mapping step 8) — transactional, id-validated

Id normalization (pinned — SurrealDB serializes hyphenated ids backticked, e.g.
``story:`test-sentinel` ``, and the fixtures use that form):

1. Strip surrounding backticks from every id read from a query response
   (``story:`test-sentinel` `` → `story:test-sentinel`).
2. Validate the stripped id against `^story:[a-zA-Z0-9_-]+$` before any
   interpolation — backticks must NOT pass validation.
3. When emitting the UPDATE, re-wrap any id containing `-` as ``story:`<id>` ``
   (hyphenated record ids need backticks in SurrealDB); plain ids stay unwrapped.

One request:

```sql
BEGIN TRANSACTION;
UPDATE story:<id1> SET depends_on = [story:<dep1a>, story:<dep1b>];
UPDATE story:<id2> SET depends_on = [];
COMMIT TRANSACTION;
```

The same strip-then-validate-then-rewrap normalization applies to every id in
`depends_on` list values. Build the statement list programmatically (python3)
and inspect the curl response array: every statement must return
`"status": "OK"` and affected rows ≥ 0 as expected; any ERR or a 0-row update
on a story that exists → `CANCEL TRANSACTION;` + restore from snapshot + report.

### Verify (mapping step 9)

```sql
SELECT id, depends_on, estimate FROM ${backlog.table} ORDER BY id;
```

Assert: no cycles (run `scripts/graph.py`), every edge target exists, written
id-set == loaded id-set, and the edge set equals the confirmed list. Persist
the mapping report (edge map, broken edges + reasons, topo order, snapshot
path, stale-story list = stories whose `updated_at` is newer than the last
`.workflow/mapping-reports/*` timestamp) to `<project>/.workflow/mapping-reports/<ts>.json`.

### Sentinel guard (tests)

Before any test write: `SELECT count() FROM story:test-sentinel;` — if the
sentinel story is absent, abort the test run (wrong database).
