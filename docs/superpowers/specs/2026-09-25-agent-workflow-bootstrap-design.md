# agent-workflow — session bootstrap design

2026-09-25

## Goal

Make the installed workflow **load itself at session start**, the way
superpowers does, so a colleague who installs this pack gets the workflow
without having to remember to invoke it. The injection must fire **only in
projects that opted in** — never in an unrelated repo.

## Context

Superpowers' enforcement is not in its skills. `hooks/session-start` reads
`using-superpowers/SKILL.md` and emits it as `hookSpecificOutput.additionalContext`
on every `SessionStart` event. Copying `skills/` does not reproduce that, because
nothing runs at session start when only files are copied. To match the behavior,
this pack must install a **session-start mechanism**, not more files.

The workflow is project-scoped: it needs `workflow.config.toml`, a SurrealDB
backlog, and a project that chose the model. Injecting "you MUST run the
story-ATDD workflow" into every session on the machine would be wrong — the
agent would try to write stories into a database that is not there. Over-
enforcement fails worse than under-enforcement here.

## The lifecycle this bootstrap points at

The charter's opening must state the sequence correctly (the lifecycle-block and
README wording fix landed just before this spec). Brainstorming is the **entry
point**, outside the workflow:

```
ONCE, before the workflow:  brainstorming → spec (design doc on disk)
THEN:                       story-atdd-workflow consumes the spec:
                              stories + ACs → map db
                              per story: architect → tech_brief
                                per AC, strictly serial (the only repeat):
                                  acceptance test RED → layer TDD GREEN → commit
                                  → dedicated refactor subagent
                                  → deploy + smoke every environment
                              story done → next story
```

Nothing loops back to brainstorming. A new design question later produces a
**new** spec and **new** stories — a forward edge, not a re-entry.

## Design

### 1. The charter — `bootstrap/CHARTER.md`

One canonical, harness-neutral markdown file (~2.7 KB). It is the entry
contract, not a copy of the skills:

- This project runs the story-driven ATDD workflow.
- Entry: `brainstorming` once → spec; then invoke `story-atdd-workflow`.
- Stories live in SurrealDB (process state); code/specs/tests live in git.
- One AC at a time; acceptance test RED first; per-layer RED evidence in the report.
- A dedicated refactor subagent after each green AC; coverage must not regress.
- Deploy + smoke **every** environment before an AC is done.
- Leave no dirty tree.
- **Self-gate line:** if `workflow.config.toml` is absent and `AGENT_WORKFLOW`
  is unset, this workflow does not apply — ignore this context.

It names the skills (via the harness's skill mechanism) rather than inlining
their bodies, so the charter stays small and does not go stale.

### 2. Claude Code — SessionStart hook

`hooks/session-start.sh`, executable. Behavior:

- Read `bootstrap/CHARTER.md`.
- Gate: emit output only when `$CLAUDE_PROJECT_DIR/workflow.config.toml` exists
  OR `$AGENT_WORKFLOW` is truthy. Otherwise `exit 0` with **no** output.
- When gating passes, print
  `{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"<charter>"}}`
  with the charter JSON-escaped (backslash, quote, newline, CR, tab).

The installer merges into `~/.claude/settings.json` (or `--target`'s
`settings.json`):

```json
{ "hooks": { "SessionStart": [ { "matcher": "startup|resume|clear|compact",
  "hooks": [ { "type": "command", "command": "<abs>/hooks/session-start.sh" } ] } ] } }
```

Merge rules: idempotent (an existing identical handler is not duplicated), a
timestamped backup before writing, never a blind overwrite.

### 3. opencode — `instructions` entry

The installer copies the charter to `~/.config/agent-workflow/CHARTER.md` and
adds that path to the `instructions` array in `opencode.json` (idempotent, with
a backup). opencode injects ambient instructions unconditionally; it has no
per-session gate at the config level. **Scoping therefore relies on the
charter's self-gate line and the model honoring it** — strictly weaker than the
Claude hook. This asymmetry is documented, not hidden.

### 4. Installer

- `--bootstrap` (default on) / `--no-bootstrap`.
- `--uninstall-bootstrap`: remove the hook entry and the `instructions` entry.
- Dry-run prints the exact JSON merges it would make.
- Nothing touches a live config without `--apply`.

### 5. Verify (`scripts/verify.sh`)

- The charter exists and contains the self-gate line.
- The hook is executable.
- The hook **gates**: run it with `CLAUDE_PROJECT_DIR` set to a dir WITH a
  `workflow.config.toml` → output contains `additionalContext`; with a dir
  WITHOUT one and no `AGENT_WORKFLOW` → empty output, exit 0.
- The settings merge is idempotent: applying it twice yields one handler.

### 6. Docs

- README "How the workflow loads" section: the two mechanisms, the gate, and
  the Claude/opencode asymmetry.
- `skills/vendor/VENDORED.md`: we now reproduce upstream's **mechanism**
  (session-start injection), not its text or its always-on scope.

## Non-goals

- No opencode plugin (`ctx.session.hook("context")`). It would gate properly on
  opencode, but adds a JS artifact and a host-version dependency. Deferred;
  the instructions entry ships first.
- No `.claude-plugin/` manifest. Plugin skill discovery for nested
  `skills/vendor/` is unverified; the installer route is proven.
- Not applying to the author's live config. Build and test in sandboxed dirs;
  wiring a real machine is the human's call.

## Testing

- `scripts/verify.sh` checks 13–17, 25 (charter present + self-gate, hook gated
  both ways, merge idempotency both hosts, charter names every step,
  `AGENT_WORKFLOW` truthiness); later robustness checks (20, 24) cover the
  opencode config-name symmetry and the JSONC decline path.
- Manual: run the hook with and without a config dir; diff the dry-run settings
  merge; confirm `opencode.json` gains exactly one `instructions` entry.
- **Unverifiable on this machine:** a live Claude `SessionStart` firing
  (headless Claude hangs under the local Bedrock config). The hook script is
  tested directly; the settings merge is verified by inspection. This limit is
  stated, not papered over.
