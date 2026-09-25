# Configuration — resolving project-specific values

The workflow skills are **project-agnostic**. They never hardcode a namespace,
a database, a repo name, a deploy command, or a traversal tool. Before a skill
is used, its placeholders are resolved from `workflow.config.toml`.

## Resolution order

Read the first of these that exists, then stop:

1. `./workflow.config.toml` — the project's own config (authoritative in that repo).
2. `~/.config/agent-workflow/config.toml` — your machine default.
3. **No file** → use the defaults below. Every skill still works unconfigured;
   the defaults are a single-project, local-only setup.

State the resolved values once in your report so the human can correct them.

**Activation vs. values.** The session-start bootstrap (the workflow charter
injected at session start) fires only when the **project-root** config exists or
`AGENT_WORKFLOW` is set — a machine default supplies *values* but does not by
itself activate the injected charter. The skills themselves resolve the full
order above regardless.

## Keys and their defaults

| Placeholder | Default | Meaning |
|---|---|---|
| `${project.name}` | `my-project` | human label, prose only |
| `${backlog.mode}` | `two-db` | `two-db` (story-atdd-workflow) or `single-db` (story-writing-council) |
| `${backlog.namespace}` | `my-project` | SurrealDB `ns=` for this project |
| `${backlog.map_db}` | `iteration_map` | two-db: backlog + plan db |
| `${backlog.run_db}` | `iteration` | two-db: active-execution db |
| `${backlog.db}` | `my-project` | single-db: the one database |
| `${backlog.table}` | `story` | single-db: the backlog table |
| `${surreal.endpoint}` | `http://127.0.0.1:8000` | SurrealDB HTTP endpoint |
| `${guard.test_mode_env}` | `WORKFLOW_TEST_MODE` | write guard env var |
| `${deploy.environments}` | `["dev"]` | envs an AC must reach |
| `${deploy.deploy_command}` | `""` | template; `${env}`, `${base_url}` |
| `${deploy.smoke_command}` | `""` | template; `${env}`, `${base_url}` |
| `${deploy.base_urls}` | `{ dev = "http://127.0.0.1:8080" }` | per-env base URL |
| `${traversal.primary}` | `gitnexus` | or `none` |
| `${traversal.fallback}` | `serena` | or `none` |
| `${acceptance.e2e}` | `playwright` | acceptance harness name |
| `${acceptance.contract}` | `pact` | contract harness name |

## Credentials (never in the config file)

SurrealDB credentials are resolved at runtime, never stored:

1. **MCP server config.** If the host exposes a `surrealdb` MCP entry, read its
   `headers.Authorization` (`Basic <base64>` → `root:<password>`). The opencode
   path is `~/.config/opencode/opencode.json`; other hosts may differ — discover
   the host's MCP config rather than assuming a path.
2. **Environment.** `WORKFLOW_SURREAL_PASSWORD` (username `root`).
3. **Ask the user.** Never guess, never embed.

`CRED` must never be echoed, logged, or written to a file. Decode inline,
`set +x` when debugging.

## The write guard

When `$env:${guard.test_mode_env}` is truthy, write helpers MUST refuse to
write to the project's real namespace/db. Tests point the same env at a
throwaway namespace and assert the guard fires. This replaces any
tool-specific guard variable.

## Verdict destinations (councils)

The council skills (`data-science-council`, `product-verification-council`)
record a verdict to SurrealDB only when the user asks. Their destination is
resolved in this order:

1. an explicit user instruction;
2. a `[verdict_destinations]` entry keyed by topic (`{namespace, db, table}`);
3. the `[backlog]` namespace/db with table `verdict`.

If it is ambiguous, ask one question — never invent a destination. The key is
optional; the example config carries it commented out. Fields written:
`{ id, target_id, kind, mode, verdict, chair_line, consensus[], adjudications[],
must_fix[], persona_count, ts, source_text }`.

## Deploy and smoke

A project with no deploy step sets `environments = []`. Otherwise the
coordinator runs `${deploy.deploy_command}` per environment, then
`${deploy.smoke_command}` against that environment's `${deploy.base_urls}`
entry, and records the result. A project may instead define these commands in
its own `AGENTS.md`, which overrides this file.
