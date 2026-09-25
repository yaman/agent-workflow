# agent-workflow

A project-agnostic, double-harness workflow pack: six skills and six subagents
that implement a story-driven, acceptance-test-driven development process on a
SurrealDB backlog. One canonical source tree installs into **opencode** and
**Claude Code**.

Nothing here is tied to a specific project. Every project-specific value
(namespace, databases, deploy commands, traversal tools, test harnesses) is
read from `workflow.config.toml` at runtime — see
[`references/configuration.md`](references/configuration.md).

## What's in the pack

### Skills

| Skill | Role |
|---|---|
| `story-atdd-workflow` | The core loop: spec → stories in SurrealDB → one AC at a time as a vertical slice, acceptance test first, layer-by-layer TDD, then a dedicated refactor pass and a deploy+smoke gate. The `two-db` backlog model. |
| `story-writing-council` | Six-persona council that reviews/authors backlog stories and remaps the whole `depends_on` graph with a deterministic, transactional write. The `single-db` backlog model. |
| `architecture-rules` | The coding standard for Rust backends and Svelte/SvelteKit frontends: layering, error handling, async, testing, clean code. |
| `wisdom-council` | N-expert parallel council for consequential design/architecture decisions — independent lenses, adjudicated divergences, MUST-FIX list. |
| `data-science-council` | Ten-persona council for statistical, causal, and learning claims or experiment configs. |
| `product-verification-council` | Ten-persona council that verifies a product/feature/release from independent lenses (architecture, QA, devops, UX, a11y, security, …). |

### Agents

`architect` (read-only designer), `developer` (ATDD implementer), `rust-developer`,
`svelte-developer`, `code-reviewer` (read-only quality gate), `qa` (read-only
rules-compliance gate).

## Install

The installer is non-destructive: it prints a plan by default and writes
nothing until you pass `--apply`. It never overwrites a file that already exists
unless you pass `--force`.

```bash
# Claude Code -> ~/.claude/{skills,agents}
node install/install.mjs --host claude            # dry-run
node install/install.mjs --host claude --apply

# opencode -> ~/.config/opencode/{skills,agents}
node install/install.mjs --host opencode --apply

# both at once
node install/install.mjs --host both --apply
```

Options: `--target DIR` (install elsewhere), `--model ID` (emit a model in
Claude agent frontmatter; default is to inherit the session model), `--force`,
`--help`.

The canonical agent frontmatter is opencode's (the primary host): `mode`,
`steps`, `permission`. The installer translates it for Claude Code (`steps` →
`maxTurns`, `permission` → a `tools` allowlist; read-only agents become
`Read, Grep, Glob, WebFetch, WebSearch, TodoWrite`). See
[`references/tool-mapping.md`](references/tool-mapping.md) for the full
translation, including tool-name mapping used in skill prose.

## Configure a project

Copy [`workflow.config.example.toml`](workflow.config.example.toml) to your
project root as `workflow.config.toml` (or to
`~/.config/agent-workflow/config.toml` for a machine default). With no config,
the skills run on the documented defaults: a single project, local-only, a
`two-db` SurrealDB backlog at `127.0.0.1:8000`.

Credentials are never stored in the config. They resolve at runtime from the
host's MCP server config, then `WORKFLOW_SURREAL_PASSWORD`, then a prompt to the
user.

## Scope

The pack is **generic**. It does not include third-party or machine-specific
skills (Orca, ponytail, gitnexus, OpenKnowledge, ui-ux-pro-max, …), and it does
not include the `search`/`deep-research` agents, which pin a provider-specific
model. Vendor those separately.

The council skills optionally record verdicts to SurrealDB. That path is used
only when the user asks, and its destination is resolved from
`[verdict_destinations]` or `[backlog]` in the config.

## License

MIT — see [LICENSE](LICENSE).
