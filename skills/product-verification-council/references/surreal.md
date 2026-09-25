# SurrealDB write protocol (verdicts)

Rules inherited from `story-writing-council/references/surreal.md`: credential
resolution, no password in output/logs, refuse real writes in test mode, verify
after write.

## Credential resolution (never embed credentials)

Inherited verbatim from `story-writing-council/references/surreal.md`:

1. If the host exposes a `surrealdb` MCP entry, read its `headers.Authorization`
   (`Basic <base64>` where the decoded value is `root:<password>`). The opencode
   path is `~/.config/opencode/opencode.json`; discover the host's MCP config
   rather than assuming that path.
2. Fallback: env var `WORKFLOW_SURREAL_PASSWORD` → username `root`.
3. If neither exists: STOP and ask the user for the SurrealDB root password —
   never guess.

## When

ONLY when the user asks ("write it to the db", "record the verdict", "save it
to surrealdb"). Chat verdict first; the DB is the durable record.

## Destination

- Resolve the target namespace/database from `workflow.config.toml`
  (`backlog.namespace`, `backlog.db`) or, when the project keeps verdicts in
  their own store, the `verdict_destinations` map in that file. The full
  resolution order, key list and defaults are in `configuration.md`.
- Explicit user override wins. Ambiguous → ask one question. Never invent a
  destination.

Table: `verdict`.

Fields: { id, target_id, kind: "product" | "release" | "targeted", mode: "full" | "targeted", verdict, chair_line, consensus[], adjudications[], must_fix[], persona_count, ts, source_text (only if ≤ 8,000 chars, else omit and store a reference) }

Id convention: `verdict:<slug>-<YYYYMMDD>` (slug from target_id or the product title).

## Write

1. Present the verdict record to the user in chat (the synthesis already exists; show the record shape).
2. Write only after explicit confirmation.
3. Write the record.
4. Verify: SELECT the record by id; assert status == "recorded" and verdict field non-empty.

## Guards

- Refuse when `${guard.test_mode_env}=1` and the resolved db is a real target.
- Never update or delete an existing verdict without explicit user instruction.
