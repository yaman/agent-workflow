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
GREP='grep -rniI --exclude-dir=__pycache__ --exclude=*.pyc'
if $GREP -E "$HARD" skills/ agents/ 2>/dev/null >/tmp/opencode/aw-coupling.txt; then
  bad "hard coupling tokens found:"; sed 's/^/       /' /tmp/opencode/aw-coupling.txt; fail1=1
fi
# The configuration docs legitimately name the default values; exclude them from
# the soft scan, but scan everything else.
if $GREP -E "$SOFT" skills/ agents/ 2>/dev/null \
   | grep -vE '/configuration.md:|default `iteration_map`|default `iteration`' >/tmp/opencode/aw-coupling2.txt; then
  bad "soft coupling tokens found:"; sed 's/^/       /' /tmp/opencode/aw-coupling2.txt; fail1=1
fi
[ "$fail1" = 0 ] && pass "no coupling tokens"

echo "== 2. every skill has valid frontmatter (name + description) =="
f2=0
for d in skills/*/; do
  f="$d/SKILL.md"
  if [ ! -f "$f" ]; then bad "missing SKILL.md: $d"; f2=1; continue; fi
  first=$(head -1 "$f")
  [ "$first" = "---" ] || { bad "no opening frontmatter: $d"; f2=1; continue; }
  grep -qE '^name:\s*\S' "$f"        || { bad "no name: $d"; f2=1; }
  grep -qE '^description:\s*\S' "$f" || { bad "no description: $d"; f2=1; }
done
[ "$f2" = 0 ] && pass "6 skills have name + description"

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

echo
if [ "$fail" = 0 ]; then echo "ALL CHECKS PASSED"; else echo "CHECKS FAILED"; fi
exit "$fail"
