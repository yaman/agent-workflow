# Vendored skills

`skills/vendor/superpowers/` contains skills copied from
[obra/superpowers](https://github.com/obra/superpowers), MIT-licensed, and
patched only where their cross-references pointed at skills this pack does not
ship. They are **not** written by this project — see attribution below.

The workflow is complete with them: a colleague installs this repo and gets
both the story-driven ATDD loop (`skills/`) and the lifecycle skills the loop
calls into (`skills/vendor/superpowers/`).

## What is vendored, and why

| Skill | Why it is here |
|---|---|
| `brainstorming` | `story-atdd-workflow` Step 1 starts from a spec; brainstorming is how the spec is produced. Patched: its terminal step now hands off to `story-atdd-workflow` instead of `writing-plans`. |
| `finishing-a-development-branch` | Named in `story-atdd-workflow` Step 5. |
| `systematic-debugging` | Debugging discipline for bugs encountered mid-AC. Patched: its failing-test step points at our red-first gate, not the removed `test-driven-development`. |
| `verification-before-completion` | Evidence-before-claims; pairs with the per-layer RED-evidence rule. |
| `requesting-code-review` | Review request discipline. |
| `receiving-code-review` | How to evaluate review feedback without performative agreement. |
| `using-git-worktrees` | Isolation for AC work in a worktree flow. |

## What is deliberately NOT vendored

Superpowers ships 15 skills. Four are **excluded because they contradict this
pack's model** — installing them alongside the workflow would put two competing
processes in the same session:

| Excluded | Conflict |
|---|---|
| `test-driven-development` | This pack replaces TDD with ATDD (`story-atdd-workflow`). |
| `writing-plans` | `story-atdd-workflow` replaces it — stories are the plan, no plan files. |
| `executing-plans` | Same; `story-atdd-workflow` is the execution model. |
| `subagent-driven-development` | `story-atdd-workflow` owns subagent orchestration; SDD is a competing model. |

Four more are irrelevant to this workflow and excluded for size:
`using-superpowers`, `diagnosing-superpowers`, `writing-skills`,
`dispatching-parallel-agents`.

`scripts/verify.sh` asserts the four conflict skills never appear in the pack.

## What vendoring does NOT reproduce

Superpowers is more than a skills directory. Its behavior is enforced by a
**SessionStart hook** (`hooks/session-start`) that injects "you MUST use the
skill" into every session, and an `using-superpowers` bootstrap skill. Copying
the skills does not copy that machinery, and this pack intentionally does not
recreate it — the workflow here is invoked through `story-atdd-workflow` and the
pack's agents, not through a mandatory-skill gate.

If a colleague wants the full upstream enforcement, they can additionally
install superpowers itself (`npx skills add obra/superpowers`, or as an opencode
plugin) — but note the four excluded skills above would then be present, and
should be removed or ignored.

## Provenance

- Source: `https://github.com/obra/superpowers`
- Version: `6.4.1`
- Commit: `5bf4e78011075bcfc0dc295f0724994cd123ee71` (2026-09-18)
- License: MIT — Copyright (c) 2025 Jesse Vincent
- Local modifications: cross-reference patches only (documented per row above);
  no behavioral edits.

To refresh: re-copy the seven `SKILL.md` trees from a newer superpowers tag and
re-apply the two patches (brainstorming's handoff, systematic-debugging's
failing-test reference).
