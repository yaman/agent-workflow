# agent-workflow — design

2026-09-25

## Goal

Package the machine's custom agent workflow (six skills + six subagents) as a
project-agnostic, double-harness (opencode + Claude Code) repository a colleague
can install, **without changing the running skills on this machine**.

## Constraints

- No project-specific values (namespace, databases, deploy commands, traversal
  tool names, harness names) baked into skill text.
- Works in Claude Code as well as opencode.
- The live install (`~/.agents/skills`, `~/.config/opencode/agents`) is not touched.

## Decisions

1. **Runtime config over install-time rendering.** Skills read
   `workflow.config.toml` (project → machine → defaults) rather than being
   rendered with project values per install. One copy stays generic and works
   across projects; rendering would re-bake coupling.
2. **Canonical source is harness-neutral.** Skill bodies name *roles* (dispatch
   a subagent, run a shell command), and `references/tool-mapping.md` gives the
   per-host translation. Agent frontmatter is stored in opencode's shape and
   translated for Claude Code at install time (`steps` → `maxTurns`, `permission`
   → `tools`).
3. **Two backlog models, selected by config.** `story-atdd-workflow` is the
   `two-db` model (structured `acs`, phases, tech_brief); `story-writing-council`
   is the `single-db` body-embedded model. `backlog.mode` selects one; neither
   is applied to the other's backlog.
4. **Credentials stay out of the config.** Resolution order is documented
   (host MCP config → `WORKFLOW_SURREAL_PASSWORD` → ask). The tool-specific
   `SURREAL_ROOT_PASSWORD`/`FORGE_*` variables are gone; the guard is
   `WORKFLOW_TEST_MODE`.
5. **Scope is the workflow, not the toolbox.** Third-party skills (Orca,
   ponytail, gitnexus, OpenKnowledge, ui-ux-pro-max) and provider-pinned agents
   (`search`, `deep-research`) are excluded — they are not this workflow and
   would bloat the repo.
6. **Non-destructive installer.** Dry-run by default; skip-and-report existing
   differing files unless `--force`.

## Parameterization map

Every placeholder is defined in `references/configuration.md` (copied into each
skill's `references/` so skills are self-contained). Summary:

- `project.name`
- `backlog.mode`, `backlog.namespace`, `backlog.map_db`, `backlog.run_db`,
  `backlog.db`, `backlog.table`
- `surreal.endpoint`
- `guard.test_mode_env`
- `deploy.environments`, `deploy.deploy_command`, `deploy.smoke_command`,
  `deploy.base_urls`
- `traversal.primary`, `traversal.fallback`
- `acceptance.e2e`, `acceptance.contract`
- `[verdict_destinations]` (optional, for the council verdict writes)

## Out of scope

- Installing into the live host (left to the human; the installer can be run
  with `--apply` when desired).
- Preserving the live machine's exact skill text: the packaged copies are the
  parameterized versions, intentionally divergent.
