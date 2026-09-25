# This project runs the agent-workflow workflow

You are in a project that uses the **story-driven, acceptance-test-driven
(ATDD) workflow**. Follow it unless the user says otherwise.

## The sequence

```
ONCE, before the workflow:  brainstorming -> spec (a design doc on disk)
THEN: story-atdd-workflow consumes the spec:
        stories + ACs into SurrealDB (the plan)
        project decisions (stack + per-layer architecture) pinned in the map db
        per story: architect subagent -> tech_brief
          per AC, strictly serial (the inner repeat):
            acceptance test RED -> layer-by-layer TDD GREEN -> commit
            -> dedicated refactor subagent (no behavior change)
            -> deploy + smoke every environment
        story done -> next story (the outer repeat)
```

Brainstorming is the entry point, *outside* the loop. Nothing loops back to it.
A later design question makes a **new** spec and **new** stories, not a re-entry.

## Non-negotiables

- **Spec first.** No story before a spec: `brainstorming`, then `story-atdd-workflow`.
- **Stories are the plan.** No plan files. Stories and ACs live in SurrealDB
  (process state); code, specs and tests live in git. One authority per kind of state.
- **≤3 user-facing Gherkin ACs per story, one functionality each.** Given/When/Then
  each on its own line; no technical pinning in an AC.
- **Decisions before the first story.** Stack and per-layer architecture are pinned
  in the map db before any story is picked up, and amended only via explicit review.
- **One AC at a time.** Never parallel ACs; never write all acceptance tests first.
- **RED first, with evidence.** The acceptance test fails for the right reason
  before any implementation; each architecture layer's unit test is written and
  seen RED before that layer's code. The report carries the exact failing command
  and output per layer — "it passed" is not evidence.
- **Refactor is a separate subagent**, dispatched after the AC is green, in a fresh
  context (never the implementer), with no behavior change; coverage must not regress.
- **Deploy + smoke every environment** before an AC is done. A green pipeline is
  not a deploy.
- **Leave no dirty tree.** `git status --porcelain` empty, untracked included.

## Configuration

Project-specific values — namespace, databases, deploy commands, traversal
tools, test harnesses — come from `workflow.config.toml` (the project root, or
your machine default at `~/.config/agent-workflow/config.toml`). Read it; never
hardcode them.

## Self-gate

If `workflow.config.toml` is absent from the project root and `AGENT_WORKFLOW`
is not set, this workflow does not apply to this project — ignore this context.
