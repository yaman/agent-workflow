#!/usr/bin/env bash
# verify.sh — prove the pack is project-agnostic and installs cleanly.
# Run from the repo root. Exits non-zero on any failure.
set -uo pipefail
cd "$(dirname "$0")/.."

fail=0
pass() { printf '  ok   %s\n' "$1"; }
bad()  { printf 'FAIL   %s\n' "$1"; fail=1; }

echo "== 1. no project-specific coupling in skills/ or agents/ =="
# Hard tokens that must NEVER appear anywhere.
HARD='nemesis|canavar|FORGE_|dev\.sh|opencode-go|/home/|revchief|riskchief|codechief|flowforge'
# 'forge' with a trailing non-letter, so 'forget'/'fire-and-forget' don't match.
SOFT='(^|[^a-z])forge([^a-z]|$)|iteration_map'
fail1=0
GREP='grep -rniI --exclude-dir=__pycache__ --exclude-dir=vendor --exclude=*.pyc'
if $GREP -E "$HARD" skills/ agents/ 2>/dev/null >/tmp/opencode/aw-coupling.txt; then
  bad "hard coupling tokens found:"; sed 's/^/       /' /tmp/opencode/aw-coupling.txt; fail1=1
fi
# The configuration docs legitimately name the default values, and skills/vendor/
# is third-party text (not ours to police); both are excluded from the soft scan.
if $GREP -E "$SOFT" skills/ agents/ 2>/dev/null \
   | grep -vE '/configuration.md:|default `iteration_map`|default `iteration`' >/tmp/opencode/aw-coupling2.txt; then
  bad "soft coupling tokens found:"; sed 's/^/       /' /tmp/opencode/aw-coupling2.txt; fail1=1
fi
[ "$fail1" = 0 ] && pass "no coupling tokens"

echo "== 2. every skill has valid frontmatter (name + description) =="
f2=0; n2=0
while IFS= read -r f; do
  n2=$((n2+1))
  first=$(head -1 "$f")
  [ "$first" = "---" ] || { bad "no opening frontmatter: $f"; f2=1; continue; }
  grep -qE '^name:\s*\S' "$f"        || { bad "no name: $f"; f2=1; }
  grep -qE '^description:\s*\S' "$f" || { bad "no description: $f"; f2=1; }
done < <(find skills -name SKILL.md | sort)
[ "$f2" = 0 ] && pass "$n2 skills have name + description"

echo "== 3. every agent has description frontmatter =="
f3=0
for f in agents/*.md; do
  grep -qE '^description:\s*\S' "$f" || { bad "agent missing description: $f"; f3=1; }
done
[ "$f3" = 0 ] && pass "$(ls agents/*.md | wc -l) agents have description"

echo "== 4. skills are self-contained (configuration.md present where referenced) =="
for d in skills/*/; do
  if grep -rq 'references/configuration.md' "$d" 2>/dev/null; then
    [ -f "$d/references/configuration.md" ] || bad "referenced but missing: $d"
  fi
done
pass "self-contained references"

echo "== 5. python script tests =="
if (cd skills/story-writing-council/scripts && python3 -m pytest -q >/tmp/opencode/aw-pytest.txt 2>&1); then
  pass "$(tail -1 /tmp/opencode/aw-pytest.txt)"
else
  bad "script tests failed"; tail -5 /tmp/opencode/aw-pytest.txt
fi

echo "== 6. installer dry-run, both hosts =="
if node install/install.mjs --host both >/tmp/opencode/aw-install.txt 2>&1; then
  pass "installer ran: $(grep -c '^  +' /tmp/opencode/aw-install.txt) files planned"
else
  bad "installer failed"; tail -5 /tmp/opencode/aw-install.txt
fi

echo "== 7. installer renders Claude agents (no opencode-only fields) =="
rendered=$(node install/install.mjs --host claude --print-agent architect 2>&1)
if printf '%s' "$rendered" | grep -qE '^maxTurns:' \
   && ! printf '%s' "$rendered" | grep -qE '^steps:' \
   && printf '%s' "$rendered" | grep -qE '^tools:'; then
  pass "claude renderer translates steps->maxTurns, permission->tools"
else
  bad "claude renderer"; printf '%s\n' "$rendered" | head -8 | sed 's/^/       /'
fi

echo "== 8. installer renders read-only vs full tool sets =="
ro=$(node install/install.mjs --host claude --print-agent qa 2>&1)
full=$(node install/install.mjs --host claude --print-agent developer 2>&1)
if printf '%s' "$ro" | grep -qE '^tools: Read, Grep, Glob' \
   && ! printf '%s' "$full" | grep -qE '^tools:'; then
  pass "read-only agents get a tools allowlist; implementers inherit all tools"
else
  bad "tool-set rendering"
fi

echo "== 9. rendered Claude descriptions are YAML-safe =="
# A description containing ': ' (or starting with a YAML indicator) must be
# quoted, or Claude Code's strict parser drops the whole frontmatter.
f9=0
for a in agents/*.md; do
  name=$(basename "$a" .md)
  line=$(node install/install.mjs --host claude --print-agent "$name" 2>/dev/null | grep -E '^description:' | head -1)
  val=${line#description: }
  case "$val" in
    \"*\") : ;;  # quoted -> fine
    *": "*) bad "unquoted description with colon in $name"; f9=1 ;;
  esac
done
[ "$f9" = 0 ] && pass "all descriptions are quoted or colon-free"

echo "== 10. conflict skills are NOT in the pack =="
# Superpowers' TDD/plans/SDD skills contradict this pack's ATDD model and must
# be excluded (documented in skills/vendor/VENDORED.md).
f10=0
for c in test-driven-development writing-plans executing-plans subagent-driven-development; do
  if find skills -type d -name "$c" | grep -q .; then bad "conflict skill present: $c"; f10=1; fi
done
[ "$f10" = 0 ] && pass "no conflicting upstream skills"

echo "== 11. vendored skills carry provenance =="
if [ -f skills/vendor/VENDORED.md ] \
   && grep -q 'obra/superpowers' skills/vendor/VENDORED.md \
   && grep -q 'MIT' skills/vendor/VENDORED.md; then
  pass "VENDORED.md records source, commit, license"
else
  bad "VENDORED.md missing provenance"
fi

echo "== 12. installer discovers vendored skills (flat) =="
if node install/install.mjs --host claude 2>/dev/null | grep -q 'skills/brainstorming/SKILL.md'; then
  pass "vendored brainstorming installs flat to skills/brainstorming"
else
  bad "installer does not flatten vendored skills"
fi

echo "== 13. bootstrap charter exists and self-gates =="
if [ -f bootstrap/CHARTER.md ] && grep -q 'does not apply' bootstrap/CHARTER.md; then
  pass "charter present with self-gate line"
else
  bad "charter missing or has no self-gate line"
fi

echo "== 14. session-start hook gates correctly =="
f14=0
if [ ! -x hooks/session-start.sh ]; then bad "hook not executable"; f14=1; fi
TMPD=$(mktemp -d)
mkdir -p "$TMPD/on" "$TMPD/off"
: > "$TMPD/on/workflow.config.toml"
closed=$(CLAUDE_PROJECT_DIR="$TMPD/off" bash hooks/session-start.sh)
[ -z "$closed" ] || { bad "hook emitted output with the gate closed"; f14=1; }
opened=$(CLAUDE_PROJECT_DIR="$TMPD/on" bash hooks/session-start.sh)
printf '%s' "$opened" | python3 -m json.tool >/dev/null 2>&1 \
  || { bad "hook output with the gate open is not valid JSON"; f14=1; }
[ -n "$opened" ] || { bad "hook emitted nothing with the gate open"; f14=1; }
rm -rf "$TMPD"
[ "$f14" = 0 ] && pass "gate closed: silent; gate open: valid JSON"

echo "== 15. bootstrap merge is idempotent (both hosts) =="
T15=$(mktemp -d)
node install/install.mjs --host claude --target "$T15/claude" --apply >/dev/null 2>&1
node install/install.mjs --host claude --target "$T15/claude" --apply >/dev/null 2>&1
n_claude=$(python3 -c "import json;print(len(json.load(open('$T15/claude/settings.json'))['hooks']['SessionStart']))" 2>/dev/null)
node install/install.mjs --host opencode --target "$T15/oc" --apply >/dev/null 2>&1
node install/install.mjs --host opencode --target "$T15/oc" --apply >/dev/null 2>&1
n_oc=$(python3 -c "import json;print(len(json.load(open('$T15/oc/opencode.json')).get('instructions',[])))" 2>/dev/null)
rm -rf "$T15"
if [ "$n_claude" = "1" ] && [ "$n_oc" = "1" ]; then
  pass "applying twice yields exactly one entry per host"
else
  bad "merge not idempotent (claude=$n_claude opencode=$n_oc)"
fi

echo
if [ "$fail" = 0 ]; then echo "ALL CHECKS PASSED"; else echo "CHECKS FAILED"; fi
exit "$fail"
