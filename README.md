# agent-workflow

A workflow pack for AI coding agents: **six skills and six subagents** that run
a story-driven, acceptance-test-driven development process on a SurrealDB
backlog. One canonical source tree installs into **opencode** and **Claude Code**.

It exists to make an agent hold a strict workflow when the work gets
complicated — write the failing acceptance test first, build one acceptance
criterion at a time through the layers, refactor in a separate pass, and only
call it done once it is deployed and smoke-tested.

Nothing here is tied to a specific project. Every project-specific value
(namespace, databases, deploy commands, traversal tools, test harnesses) is read
from `workflow.config.toml` at runtime — see
[`references/configuration.md`](references/configuration.md).

## Prerequisites

| Need | For |
|---|---|
| **opencode** or **Claude Code** | running the skills and agents |
| **Node.js ≥ 18** | `install/install.mjs` (the installer) |
| **Node.js ≥ 22.20** | the `npx skills` CLI, if you use that route instead |
| **SurrealDB** at `127.0.0.1:8000` (or your own endpoint) | the backlog + run state |
| **git** | cloning the repo |

You only need SurrealDB for the two story-backlog skills
(`story-atdd-workflow`, `story-writing-council`). `architecture-rules` and the
three councils work without it.

## Quickstart

```bash
git clone git@github.com:yaman/agent-workflow.git
cd agent-workflow

# 1. Review what will be installed (writes nothing):
node install/install.mjs --host claude

# 2. Install. Use --host opencode for opencode, or run both.
node install/install.mjs --host claude --apply
node install/install.mjs --host opencode --apply
```

Then point a project at it:

```bash
# from your project root:
cp /path/to/agent-workflow/workflow.config.example.toml workflow.config.toml
# edit: set [backlog].namespace, [deploy].environments, etc.
```

**Success looks like:** the skill is visible to your agent — run `/skills` in
Claude Code, or ask the agent to use `story-atdd-workflow`. Then say
*"turn this spec into stories"* or *"pick up story:<slug>"*.

## The workflow at a glance

`story-atdd-workflow` is the core loop. It takes a spec (from brainstorming)
and drives it to done, dispatching subagents per step:

```
spec (on disk)
  │
  ├─ stories + ACs ───────────→ SurrealDB map db
  │
  └─ per story:
       architect subagent  → tech_brief (files, seams, test locations)
         └─ per AC, one at a time, strictly serial:
              developer subagent   → acceptance test RED
                                   → layer-by-layer TDD GREEN
                                   → commit
              refactor subagent    → dedup/rename, full suite green
              coordinator          → deploy + smoke every environment
       → story done
```

Surrounding skills: **wisdom-council** for a consequential design decision,
**data-science-council** / **product-verification-council** to review a claim or
a release, and **architecture-rules** as the coding standard the implementer
agents follow.

## Pick your backlog model

The two backlog skills are alternatives — a project uses **one**, selected by
`backlog.mode`. Never apply one model's shape to the other's backlog.

| `backlog.mode` | Skill | Shape | Pick when |
|---|---|---|---|
| `two-db` (default) | `story-atdd-workflow` | structured `acs`, `phase`, `decision`, `tech_brief` across a backlog db and a run db | **new projects** — this is the recommended model |
| `single-db` | `story-writing-council` | one flat `story` table whose `body` carries the Epic line, Decision details, and Gherkin ACs | an **existing** backlog already in that shape |

## What's in the pack

### Skills

| Skill | Role |
|---|---|
| `story-atdd-workflow` | The core loop (above). The `two-db` backlog model. |
| `story-writing-council` | Six-persona council that reviews/authors backlog stories and remaps the whole `depends_on` graph with a deterministic, transactional write. The `single-db` model. |
| `architecture-rules` | The coding standard for Rust backends and Svelte/SvelteKit frontends: layering, error handling, async, testing, clean code. |
| `wisdom-council` | N-expert parallel council for consequential design/architecture decisions — independent lenses, adjudicated divergences, MUST-FIX list. |
| `data-science-council` | Ten-persona council for statistical, causal, and learning claims or experiment configs. |
| `product-verification-council` | Ten-persona council that verifies a product/feature/release from independent lenses (architecture, QA, devops, UX, a11y, security, …). |

### Agents

`architect` (read-only designer), `developer` (ATDD implementer),
`rust-developer`, `svelte-developer`, `code-reviewer` (read-only quality gate),
`qa` (read-only rules gate).

## Install (reference)

The installer is **non-destructive**: it prints a plan by default and writes
nothing until `--apply`. An existing file is never overwritten without `--force`.

| Flag | Effect |
|---|---|
| `--host <claude\|opencode\|both>` | required; which host's layout to render |
| `--target DIR` | install somewhere other than the host default (`~/.claude`, `~/.config/opencode`) |
| `--model ID` | emit a model in Claude agent frontmatter (default: inherit the session model) |
| `--apply` | actually write (without it: dry-run) |
| `--force` | overwrite existing files (default: skip and report) |

`--host both` cannot be combined with `--target` (each host needs its own
`agents/` directory); run the installer once per host instead.

The canonical agent frontmatter is opencode's (`mode`, `steps`, `permission`).
The installer translates it for Claude Code (`steps` → `maxTurns`, `permission`
→ a `tools` allowlist). See
[`references/tool-mapping.md`](references/tool-mapping.md) for the full
translation, including the tool-name mapping used in skill prose.

### Via the `skills` CLI (skills only)

```bash
npx skills add yaman/agent-workflow --list        # show the 6 skills
npx skills add yaman/agent-workflow --all -g      # install all, globally
npx skills add yaman/agent-workflow -g -s story-atdd-workflow
```

Tested with `skills@1.7.0` (needs Node ≥ 22.20). It installs to every detected
agent's skill directory — `~/.claude/skills/`, `~/.agents/skills/`, … —
symlinked by default (`--copy` to copy). **It installs skills only, not
subagents.** For the agents — or both together — use `install/install.mjs`.

## Configure a project

Resolution order, first match wins:

1. `./workflow.config.toml` — the project's own config
2. `~/.config/agent-workflow/config.toml` — your machine default
3. no file → the documented defaults (single project, local-only, `two-db`)

Start from [`workflow.config.example.toml`](workflow.config.example.toml) — it
documents every key. Credentials are never stored in the config; they resolve at
runtime from the host's MCP server config, then `WORKFLOW_SURREAL_PASSWORD`, then
a prompt to you.

## Verify and uninstall

```bash
bash scripts/verify.sh     # coupling, frontmatter, self-containment,
                           # script tests, and an installer dry-run
```

Uninstall by deleting the installed files (the installer never touches anything
outside its target):

```bash
rm -rf ~/.claude/skills/{story-atdd-workflow,story-writing-council,architecture-rules,wisdom-council,data-science-council,product-verification-council}
rm -f  ~/.claude/agents/{architect,developer,rust-developer,svelte-developer,code-reviewer,qa}.md
# opencode: the same paths under ~/.config/opencode/
# npx skills: npx skills remove
```

## Scope

The pack is **generic**. It does not include third-party or machine-specific
skills (Orca, ponytail, gitnexus, OpenKnowledge, ui-ux-pro-max, …), and it does
not include the `search`/`deep-research` agents, which pin a provider-specific
model. Vendor those separately.

The council skills optionally record verdicts to SurrealDB, only when you ask;
the destination resolves from `[verdict_destinations]` or `[backlog]` in the
config.

## License

MIT — see [LICENSE](LICENSE).
