# Tool mapping — one workflow, any harness

The skills are canonical and harness-neutral. Their prose names a *role*
("dispatch subagents", "make a todo list", "run a shell command", "load a
skill"), not a host-specific tool name. Translate when running in a harness
whose tool names differ. The canonical role is on the left.

| Role in the skills | opencode | Claude Code | Notes |
|---|---|---|---|
| Dispatch a subagent | `task` with `agent`/`subagent_type` | `Agent` | Give `description` + `prompt`; pass a session id to continue one. |
| Track a todo list | (v2 has none; keep a scratch checklist) | `TodoWrite` | If no todo tool exists, track the plan as a scratch list — never a plan file (stories are the plan). |
| Run a shell command | `shell`(v2) / `bash`(v1) | `Bash` | |
| Read a file | `read` | `Read` | |
| Create / overwrite a file | `write` | `Write` | |
| Targeted edit | `edit` | `Edit` | |
| Search file contents | `grep` | `Grep` | Prefer the graph tool when configured. |
| Find files by pattern | `glob` | `Glob` | |
| Fetch a URL | `webfetch` | `WebFetch` | |
| Search the web | `websearch` | `WebSearch` | |
| Load a skill | `skill` | `Skill` | |

## Subagent names

The workflow refers to subagent *roles*: **architect**, **developer**,
**rust-developer**, **svelte-developer**, **code-reviewer**, **qa**, and the
generic dispatcher for the councils. A harness exposes them by whatever name its
agent registry uses:

- opencode: the agent files in `~/.config/opencode/agents/<name>.md` register
  under their `name`/filename. The generic subagent is **`General`**.
- Claude Code: the same files installed to `~/.claude/agents/<name>.md`
  register under their frontmatter `name`. The generic subagent is
  **`general-purpose`**.

So a skill that says "dispatch via the subagent tool with the `general` type"
means `General` on opencode and `general-purpose` on Claude Code — pick the
generic agent your harness provides.

The installer in this package renders the agent files for either host (see
`install/install.mjs` and the agent frontmatter translation below).

## Frontmatter translation (agents)

The canonical agent body is identical across hosts; only the frontmatter
differs. The installer renders:

| opencode field | Claude Code field |
|---|---|
| `description` | `description` |
| `mode: subagent` / `mode: all` | (Claude subagents are always available; drop or keep as `mode`) |
| `steps: N` | `maxTurns: N` |
| `permission: { bash: allow, edit: allow, ... }` | `tools:` allowlist / `disallowedTools:` denylist |
| (none) | `model:` — omit to inherit the session model |

Read-only agents (`architect`, `code-reviewer`, `qa`) become a `tools:`
allowlist of `Read, Grep, Glob, WebFetch, WebSearch, TodoWrite`. Implementing
agents become the full tool set. No provider-specific `model` is emitted by
default — pass `--model` at install time if a host needs one.

## Skills frontmatter

Both hosts implement the Agent Skills standard: `name` + `description` in
`SKILL.md`. A skill directory copied into either host's skills location loads
unchanged. opencode additionally reads `~/.claude/skills/` and
`~/.agents/skills/`; Claude Code reads `~/.claude/skills/` (and project
`.claude/skills/`). One copy per host is enough — do not install duplicate
copies into directories both hosts scan, or one host warns about duplicate
skill names.
