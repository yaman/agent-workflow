#!/usr/bin/env bash
# agent-workflow SessionStart hook (Claude Code).
#
# Emits bootstrap/CHARTER.md as SessionStart additionalContext, but ONLY for a
# project that opted in: a workflow.config.toml in the project dir, or
# AGENT_WORKFLOW set. Otherwise it is silent (exit 0, no output).
#
# Claude Code is the only host that consumes this. opencode has no per-session
# gate at the config level, so it uses a config `instructions` entry (injected
# unconditionally, scoped only by the charter's self-gate line).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
# The charter lives at bootstrap/CHARTER.md in the repo and may sit beside the
# hook once installed; accept either.
if [ -f "${PLUGIN_ROOT}/CHARTER.md" ]; then
  charter_path="${PLUGIN_ROOT}/CHARTER.md"
elif [ -f "${PLUGIN_ROOT}/bootstrap/CHARTER.md" ]; then
  charter_path="${PLUGIN_ROOT}/bootstrap/CHARTER.md"
else
  exit 0
fi

project_dir="${CLAUDE_PROJECT_DIR:-$(pwd)}"

# Gate: the project must have opted in. AGENT_WORKFLOW counts as "on" only for a
# truthy value; 0/false/no/off (any case) are treated as unset so that
# AGENT_WORKFLOW=0 disables rather than enables.
agent_workflow_on=0
case "${AGENT_WORKFLOW:-}" in
  ""|0|false|FALSE|False|no|NO|No|off|OFF|Off) agent_workflow_on=0 ;;
  *) agent_workflow_on=1 ;;
esac

if [ ! -f "${project_dir}/workflow.config.toml" ] && [ "$agent_workflow_on" = "0" ]; then
  exit 0
fi

[ -f "$charter_path" ] || exit 0

charter="$(cat "$charter_path")"

# Escape for JSON embedding (single-pass bash substitution).
escape_for_json() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\t'/\\t}"
  printf '%s' "$s"
}

escaped="$(escape_for_json "$charter")"

printf '{\n  "hookSpecificOutput": {\n    "hookEventName": "SessionStart",\n    "additionalContext": "%s"\n  }\n}\n' "$escaped"
exit 0
