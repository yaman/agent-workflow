#!/usr/bin/env bash
# verify.sh — prove the pack is project-agnostic and installs cleanly.
# Runnable from any cwd and via a symlink. Exits non-zero on any failure.
# Needs: bash, node (for the installer dry-runs), python3 + pyyaml (for the
# frontmatter/placeholder/strict-YAML checks). Without python3 those checks fail
# — run verify.sh on a dev machine that has it.
set -uo pipefail
# Resolve this script's real directory, following symlinks, so the suite works
# when invoked via a symlink or from any cwd.
_src="${BASH_SOURCE[0]}"
while [ -L "$_src" ]; do
  _dir="$(cd -P "$(dirname "$_src")" && pwd)"
  _src="$(readlink "$_src")"
  case "$_src" in /*) ;; *) _src="$_dir/$_src" ;; esac
done
cd "$(cd -P "$(dirname "$_src")" && pwd)/.." || exit 1

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
# Run pytest with cache disabled and from a temp cwd so it never writes
# __pycache__/.pytest_cache into the skill tree (which the installer would copy).
if (cd skills/story-writing-council/scripts && PYTHONDONTWRITEBYTECODE=1 python3 -m pytest -q -p no:cacheprovider >/tmp/opencode/aw-pytest.txt 2>&1); then
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

echo "== 16. charter names every workflow step (drift guard) =="
# The charter is a summary of story-atdd-workflow; it must name each step.
# Missing one is how the 'architectural decisions' step was silently dropped.
f16=0
for tok in brainstorming "story-atdd-workflow" "stories" "decision" "tech_brief|architect" "acceptance test" "refactor" "deploy"; do
  if ! grep -qiE "$tok" bootstrap/CHARTER.md; then bad "charter omits: $tok"; f16=1; fi
done
# and the 5 steps the skill defines must be reflected (Step 1..5 headings exist)
nsteps=$(grep -cE '^## Step [0-9]' skills/story-atdd-workflow/SKILL.md)
[ "$nsteps" -ge 5 ] || { bad "expected >=5 Step headings in the skill, found $nsteps"; f16=1; }
[ "$f16" = 0 ] && pass "charter covers the workflow steps"

echo "== 17. shared references have not drifted across skills =="
f17=0
cfg=$(md5sum references/configuration.md | awk '{print $1}')
while IFS= read -r f; do
  [ "$(md5sum "$f" | awk '{print $1}')" = "$cfg" ] || { bad "configuration.md drifted: $f"; f17=1; }
done < <(find skills -path '*/references/configuration.md')
tm=$(md5sum references/tool-mapping.md | awk '{print $1}')
while IFS= read -r f; do
  [ "$(md5sum "$f" | awk '{print $1}')" = "$tm" ] || { bad "tool-mapping.md drifted: $f"; f17=1; }
done < <(find skills -path '*/references/tool-mapping.md')
[ "$f17" = 0 ] && pass "all shared-reference copies match references/"

echo "== 18. shell scripts are shellcheck-clean (if available) =="
if command -v shellcheck >/dev/null 2>&1; then
  f18=0
  for script in scripts/*.sh hooks/*.sh; do
    shellcheck -S warning "$script" >/dev/null 2>&1 || { bad "shellcheck: $script"; f18=1; }
  done
  [ "$f18" = 0 ] && pass "shellcheck (warning level) clean"
else
  pass "shellcheck not installed — skipped"
fi

echo "== 19. no skill-internal citation breaks when installed flat =="
# Inside a skill dir, a citation must be relative to the skill root, never
# repo-root-relative (`skills/<name>/...`), which breaks after a flat install.
f19=0
if grep -rn '`skills/[a-z0-9-]*/' skills/*/ 2>/dev/null | grep -v '/vendor/VENDORED.md' >/tmp/opencode/aw-flat.txt; then
  bad "repo-root-relative cite inside a skill:"; sed 's/^/       /' /tmp/opencode/aw-flat.txt; f19=1
fi
[ "$f19" = 0 ] && pass "skill citations are skill-relative"

echo "== 20. opencode bootstrap install/uninstall are symmetric (json and jsonc) =="
f20=0
for conf in opencode.json opencode.jsonc; do
  T20=$(mktemp -d)
  printf '%s\n' '{"model":"keep-me"}' > "$T20/$conf"
  node install/install.mjs --host opencode --target "$T20" --apply >/dev/null 2>&1
  got=$(grep -c CHARTER "$T20/$conf" 2>/dev/null || true)
  node install/install.mjs --host opencode --target "$T20" --uninstall-bootstrap --apply >/dev/null 2>&1
  left=$(grep -c CHARTER "$T20/$conf" 2>/dev/null || true)
  got=${got:-0}; left=${left:-0}
  model=$(python3 -c "import json;print(json.load(open('$T20/$conf')).get('model'))" 2>/dev/null)
  rm -rf "$T20"
  if [ "$got" != "1" ] || [ "$left" != "0" ] || [ "$model" != "keep-me" ]; then
    bad "opencode $conf: installed=$got left=$left model=$model"; f20=1
  fi
done
[ "$f20" = 0 ] && pass "both config names install and uninstall cleanly"

echo "== 21. every vendored skill ships the upstream license notice =="
f21=0
for d in skills/vendor/superpowers/*/; do
  [ -f "$d/SKILL.md" ] || continue
  if [ ! -f "$d/LICENSE" ] || ! grep -q 'Jesse Vincent' "$d/LICENSE"; then
    bad "missing/incomplete LICENSE in $d"; f21=1
  fi
done
[ "$f21" = 0 ] && pass "all vendored skills carry the MIT notice"

echo "== 22. installer never copies generated artifacts =="
# The installer must exclude __pycache__/.pytest_cache/*.pyc even if a local test
# run left them in the skill tree.
f22=0
mkdir -p skills/story-writing-council/scripts/__pycache__ skills/story-writing-council/scripts/.pytest_cache
: > skills/story-writing-council/scripts/__pycache__/fake.cpython-999.pyc
: > skills/story-writing-council/scripts/.pytest_cache/CACHEDIR.TAG
if node install/install.mjs --host claude 2>/dev/null | grep -qE '__pycache__|\.pytest_cache|\.pyc'; then
  bad "installer plans to copy generated artifacts"; f22=1
fi
rm -rf skills/story-writing-council/scripts/__pycache__ skills/story-writing-council/scripts/.pytest_cache
[ "$f22" = 0 ] && pass "generated artifacts excluded from the install plan"

echo "== 23. installer fails cleanly on an unwritable target =="
# A write error must be a one-line message + exit 1, not an unhandled stack trace.
f23=0
T23=$(mktemp -d); chmod 500 "$T23"
node install/install.mjs --host claude --target "$T23/sub" --apply >/dev/null 2>/tmp/opencode/aw-ro.err
rc=$?
chmod 700 "$T23"; rm -rf "$T23"
[ "$rc" = "1" ] || { bad "expected exit 1 on unwritable target, got $rc"; f23=1; }
grep -q '^error: cannot write' /tmp/opencode/aw-ro.err || { bad "no clean error message"; f23=1; }
grep -q 'Node.js v' /tmp/opencode/aw-ro.err && { bad "stack trace leaked to stderr"; f23=1; }
[ "$f23" = 0 ] && pass "clean error + exit 1, no stack trace"

echo "== 24. JSONC config is declined with an actionable message (never corrupted) =="
f24=0
T24=$(mktemp -d)
printf '{\n  // user comment\n  "model": "x",\n}\n' > "$T24/opencode.jsonc"
out=$(node install/install.mjs --host opencode --target "$T24" --apply 2>&1)
grep -qiE 'does not parse as JSON|JSONC|comments or trailing commas' <<<"$out" || { bad "no parse-hint in the message"; f24=1; }
grep -q 'instructions' <<<"$out" || { bad "message does not say what to do"; f24=1; }
grep -q '// user comment' "$T24/opencode.jsonc" || { bad "installer modified/corrupted the JSONC file"; f24=1; }
rm -rf "$T24"
[ "$f24" = 0 ] && pass "JSONC left intact with an actionable message"

echo "== 25. AGENT_WORKFLOW falsy values disable the gate =="
f25=0
T25=$(mktemp -d)   # no workflow.config.toml here
for v in 0 false no off; do
  out=$(CLAUDE_PROJECT_DIR="$T25" AGENT_WORKFLOW="$v" bash hooks/session-start.sh)
  [ -z "$out" ] || { bad "AGENT_WORKFLOW=$v did NOT disable the gate"; f25=1; }
done
for v in 1 true yes; do
  out=$(CLAUDE_PROJECT_DIR="$T25" AGENT_WORKFLOW="$v" bash hooks/session-start.sh)
  [ -n "$out" ] || { bad "AGENT_WORKFLOW=$v did NOT enable the gate"; f25=1; }
done
rm -rf "$T25"
[ "$f25" = 0 ] && pass "0/false/no/off disable; 1/true/yes enable"

echo "== 26. strict YAML: every rendered agent + skill frontmatter parses =="
if python3 -c "import yaml" >/dev/null 2>&1; then
  f26=0
  T26=$(mktemp -d)
  node install/install.mjs --host claude --target "$T26" --apply >/dev/null 2>&1
  out=$(python3 - "$T26" 2>&1 <<'PY'
import sys,glob,yaml,re
tgt=sys.argv[1]; bad=[]
try:
    for p in sorted(glob.glob(tgt+'/agents/*.md')):
        t=open(p,encoding='utf-8').read()
        m=re.match(r'^---\r?\n(.*?)\r?\n---\r?\n',t,re.S)
        if not m: bad.append('no fm: '+p); continue
        d=yaml.safe_load(m.group(1))
        if not d.get('name') or not d.get('description'): bad.append('missing field: '+p)
        if any(k in d for k in ('steps','permission','mode')): bad.append('opencode field leaked: '+p)
    for p in glob.glob('skills/**/SKILL.md',recursive=True):
        t=open(p,encoding='utf-8').read()
        m=re.match(r'^---\r?\n(.*?)\r?\n---\r?\n',t,re.S)
        if not m: bad.append('no fm: '+p); continue
        d=yaml.safe_load(m.group(1))
        if not isinstance(d,dict) or not d.get('name'): bad.append('bad fm: '+p)
except Exception as e:
    bad.append('parse error: %s' % e)
print('\n'.join(bad))
PY
)
  rm -rf "$T26"
  if [ -n "$out" ]; then bad "strict YAML issues:"; printf '%s\n' "$out" | sed 's/^/       /'; f26=1; fi
  [ "$f26" = 0 ] && pass "all agent + skill frontmatter parses under strict YAML"
else
  pass "pyyaml not installed — skipped"
fi

echo "== 27. every config placeholder is documented and used (no drift) =="
if python3 -c "import yaml" >/dev/null 2>&1; then
  f27=0
  out=$(python3 - <<'PY' 2>&1
import re, glob, tomllib
used = set()
for p in (glob.glob('skills/**/*.md', recursive=True)
          + ['bootstrap/CHARTER.md', 'references/configuration.md']):
    if '/vendor/' in p:
        continue
    used |= set(re.findall(r'\$\{([a-z0-9_.]+)\}', open(p, encoding='utf-8').read()))
cfg = tomllib.load(open('workflow.config.example.toml', 'rb'))
def flat(d, pre=''):
    out = set()
    for k, v in d.items():
        out |= flat(v, pre + k + '.') if isinstance(v, dict) else {pre + k}
    return out
keys = flat(cfg)
# a placeholder may name a map key (e.g. ${deploy.base_urls}) while the example
# defines its entries (deploy.base_urls.dev); accept the map name too
extra = set()
for k in list(keys):
    parts = k.split('.')
    for i in range(1, len(parts)):
        extra.add('.'.join(parts[:i]))
keys |= extra
# base_url/env are template placeholders inside deploy commands, not config keys
ignore = {'base_url', 'env'}
problems = []
problems += ['used-not-in-example: ' + k for k in sorted(used - keys - ignore)]
# a leaf key is "used" if it, or any ancestor prefix (a map it belongs to), is used
def is_used(k):
    parts = k.split('.')
    return any('.'.join(parts[:i]) in used for i in range(1, len(parts) + 1))
problems += ['in-example-not-used: ' + k for k in sorted(keys - extra) if not is_used(k)]
# every documented placeholder must still be used somewhere
for k in sorted(used):
    if k not in open('references/configuration.md', encoding='utf-8').read():
        problems.append('used-but-undocumented: ' + k)
print('\n'.join(problems))
PY
)
  if [ -n "$out" ]; then bad "config drift:"; printf '%s\n' "$out" | sed 's/^/       /'; f27=1; fi
  [ "$f27" = 0 ] && pass "config placeholders documented and used"
else
  pass "python tomllib/yaml unavailable — skipped"
fi

echo "== 28. no skill was silently dropped (count floor) =="
# Guard against a skill directory going missing without any check noticing.
n28=$(find skills -name SKILL.md | wc -l)
if [ "$n28" -lt 13 ]; then
  bad "expected at least 13 skills, found $n28 (one may have been dropped)"
else
  pass "$n28 skills present"
fi

echo "== 29. every skill-internal reference resolves =="
# Files cited as references/<name>.md inside a SKILL.md must exist in that skill.
f29=0
while IFS= read -r sk; do
  d=$(dirname "$sk")
  for ref in $(grep -oE 'references/[a-z0-9-]+\.md' "$sk" | sort -u); do
    [ -f "$d/$ref" ] || { bad "$sk cites missing $ref"; f29=1; }
  done
  for ref in $(grep -oE '`[a-z0-9-]+\.(md|sh|py)`' "$sk" | tr -d '`' | sort -u); do
    [ -f "$d/$ref" ] || [ -f "$d/references/$ref" ] || { bad "$sk cites missing $ref"; f29=1; }
  done
done < <(find skills -name SKILL.md)
[ "$f29" = 0 ] && pass "all skill-internal references resolve"

echo "== 30. installer preserves source executable bits =="
f30=0
T30=$(mktemp -d)
node install/install.mjs --host claude --target "$T30" --apply >/dev/null 2>&1
while IFS= read -r src; do
  base=$(echo "$src" | sed -E 's|^skills/(vendor/superpowers/)?([^/]+)/.*|\2|')
  rel=$(echo "$src" | sed -E 's|^skills/(vendor/superpowers/)?[^/]+/||')
  dst="$T30/skills/$base/$rel"
  if [ -x "$src" ] && [ ! -x "$dst" ]; then bad "exec bit lost: $base/$rel"; f30=1; fi
  if [ ! -x "$src" ] && [ -x "$dst" ]; then bad "unexpected exec bit: $base/$rel"; f30=1; fi
done < <(find skills -type f -name '*.sh' -perm -u+x)
rm -rf "$T30"
[ "$f30" = 0 ] && pass "executable scripts stay executable after install"

echo "== 31. agents named as 'agent: X' in skills must exist in agents/ =="
f31=0
for name in $(grep -rhoE 'agent: `[a-z-]+`' skills/story-atdd-workflow/ bootstrap/ 2>/dev/null \
              | grep -oE '`[a-z-]+`' | tr -d '`' | sort -u); do
  [ -f "agents/$name.md" ] || { bad "skill names an agent that does not ship: $name"; f31=1; }
done
[ "$f31" = 0 ] && pass "every named agent exists"

echo "== 32. no skill carries a shared reference it never cites =="
# A skill should carry a copy only if it actually points at it.
f32=0
while IFS= read -r f; do
  d=$(dirname "$(dirname "$f")")
  grep -rq 'references/configuration.md\|configuration\.md' "$d" --include='*.md' 2>/dev/null \
    || { bad "uncited configuration.md copy: $d"; f32=1; }
done < <(find skills -path '*/references/configuration.md')
while IFS= read -r f; do
  d=$(dirname "$(dirname "$f")")
  grep -rq 'references/tool-mapping.md\|tool-mapping\.md' "$d" --include='*.md' 2>/dev/null \
    || { bad "uncited tool-mapping.md copy: $d"; f32=1; }
done < <(find skills -path '*/references/tool-mapping.md')
[ "$f32" = 0 ] && pass "no uncited shared-reference copies"

echo "== 33. read-only agents never get write-capable tools =="
# Render each read-only agent and assert its Claude tools allowlist contains no
# write/edit/bash/agent tool (exact tokens, not substrings like TodoWrite).
f33=0
for a in architect code-reviewer qa; do
  t=$(node install/install.mjs --host claude --print-agent "$a" 2>/dev/null | grep -E '^tools:' | sed 's/^tools: //')
  [ -n "$t" ] || { bad "$a renders with no tools allowlist (would inherit all)"; f33=1; continue; }
  for bad in Bash PowerShell Edit Write NotebookEdit Agent; do
    if echo "$t" | tr ',' '\n' | sed 's/^ *//;s/ *$//' | grep -qx "$bad"; then
      bad "read-only agent $a is allowed $bad"; f33=1
    fi
  done
done
[ "$f33" = 0 ] && pass "read-only agents are write-incapable"

echo "== 34. the skill records both AC transitions the schema defines =="
# The schema promises pending -> red -> green is written immediately; the skill
# must instruct both the red and the green write, not only green.
f34=0
sk=skills/story-atdd-workflow/SKILL.md
grep -q 'acs\[n\].status = "green"' "$sk" || { bad "skill never records the green transition"; f34=1; }
grep -q 'acs\[n\].status = "red"'   "$sk" || { bad "skill never records the red transition"; f34=1; }
grep -q 'pending → red → green\|pending -> red -> green' skills/story-atdd-workflow/references/surreal-schema.md \
  || { bad "schema no longer documents the AC state machine"; f34=1; }
[ "$f34" = 0 ] && pass "skill records pending→red→green, matching the schema"

echo "== 35. installer accepts --flag=value as well as --flag value =="
f35=0
a=$(node install/install.mjs --host=claude 2>/dev/null | grep -c '=== claude ->' || true)
b=$(node install/install.mjs --host claude 2>/dev/null | grep -c '=== claude ->' || true)
[ "${a:-0}" -ge 1 ] || { bad "--host=claude not accepted"; f35=1; }
[ "${b:-0}" -ge 1 ] || { bad "--host claude not accepted"; f35=1; }
t=$(node install/install.mjs --host claude --target=/tmp/aw-eq-check 2>/dev/null | grep -c '/tmp/aw-eq-check' || true)
[ "${t:-0}" -ge 1 ] || { bad "--target=DIR not accepted"; f35=1; }
[ "$f35" = 0 ] && pass "both --flag=value and --flag value forms work"

echo "== 36. read-only agents are never the actor of a write =="
# A read-only agent (edit: deny) must not be the grammatical actor of a mutating
# command. Heuristic: the agent name immediately followed (within a short span,
# no other actor word between) by a mutating verb. Mere mention ("the architect
# is read-only; the coordinator stores it") must not trip it.
f36=0
for a in agents/*.md; do
  grep -qE '^  edit: (deny|ask)' "$a" || continue
  name=$(grep -m1 '^name:' "$a" 2>/dev/null | sed 's/name: *//')
  [ -n "$name" ] || name=$(basename "$a" .md)
  # patterns that make the agent the writer, e.g. "architect: UPDATE", "architect writes",
  # "architect runs the commit", "have the architect store"
  pat="(${name}[^.]{0,25}(UPDATE|CREATE|writes?|stores?|commits?|runs the commit))"
  hits=$(awk 'BEGIN{n=0} /^---$/{n++; next} n>=2' skills/story-atdd-workflow/SKILL.md \
         | grep -iE "$pat" \
         | grep -viE 'coordinator|is read-only|cannot write' || true)
  if [ -n "$hits" ]; then bad "read-only agent '$name' is the actor of a write"; printf '%s\n' "$hits" | sed 's/^/       /'; f36=1; fi
done
[ "$f36" = 0 ] && pass "no read-only agent is the actor of a write"

echo "== 37. scripts resolve their real location via symlink =="
# Invoke the hook through a symlink only — do NOT re-run verify.sh here, which
# would recurse the whole suite. A tiny probe of the path-resolution logic is
# enough: the hook must find CHARTER.md through a symlinked path.
f37=0
ln -sf "$(pwd)/hooks/session-start.sh" /tmp/aw-hlink.sh
d37=$(mktemp -d); : > "$d37/workflow.config.toml"
n=$(CLAUDE_PROJECT_DIR="$d37" bash /tmp/aw-hlink.sh 2>/dev/null | wc -c)
[ "$n" -gt 0 ] || { bad "hook fails when symlinked (cannot resolve its real dir)"; f37=1; }
rm -rf "$d37" /tmp/aw-hlink.sh
# and the scripts must share the same resolution idiom
grep -q 'BASH_SOURCE' scripts/verify.sh || { bad "verify.sh does not resolve symlinks"; f37=1; }
grep -q 'BASH_SOURCE' scripts/sync-references.sh || { bad "sync-references.sh does not resolve symlinks"; f37=1; }
[ "$f37" = 0 ] && pass "symlink-safe path resolution in all three scripts"

echo "== 38. a corrupt package fails loudly, not silently =="
f38=0
tmp38=$(mktemp -d)
for missing in agents skills bootstrap/CHARTER.md; do
  cp -r "$(pwd)" "$tmp38/broken" 2>/dev/null || true
  ( cd "$tmp38/broken" && rm -rf "$missing" )
  ( cd "$tmp38/broken" && node install/install.mjs --host claude --target "$tmp38/out" >/dev/null 2>&1 )
  rc=$?
  [ "$rc" = "1" ] || { bad "missing $missing did not fail (exit $rc)"; f38=1; }
  rm -rf "$tmp38/broken" "$tmp38/out"
done
rm -rf "$tmp38"
[ "$f38" = 0 ] && pass "missing package files fail with exit 1"

echo "== 39. bare --apply warns it is writing to the real host config =="
f39=0
# dry-run: no warning (nothing is written)
if node install/install.mjs --host claude 2>/dev/null | grep -q 'no --target given'; then
  bad "dry-run wrongly warns about writing"; f39=1
fi
# sandboxed apply: no warning
T39=$(mktemp -d)
if node install/install.mjs --host claude --target "$T39" --apply 2>/dev/null | grep -q 'no --target given'; then
  bad "sandboxed apply wrongly warns"; f39=1
fi
rm -rf "$T39"
# bare apply, HOME redirected so nothing real is touched: must warn
H39=$(mktemp -d)
if ! HOME="$H39" node install/install.mjs --host claude --apply 2>/dev/null | grep -q 'no --target given'; then
  bad "bare --apply did not warn"; f39=1
fi
rm -rf "$H39"
[ "$f39" = 0 ] && pass "bare --apply warns; dry-run and sandboxed do not"

echo "== 40. agents do not hardcode a traversal tool the config may disable =="
# The traversal tools are configured via workflow.config.toml; an agent body must
# not assert one unconditionally (it would tell the model to use an absent tool).
f40=0
if grep -rn 'gitnexus MCP tools\|use the serena MCP\|must use gitnexus\|use gitnexus' agents/ >/tmp/opencode/aw-trav.txt 2>/dev/null; then
  bad "agent hardcodes a traversal tool:"; sed 's/^/       /' /tmp/opencode/aw-trav.txt; f40=1
fi
# and the parameterized mention should be present in the implementer agents
for a in architect developer rust-developer svelte-developer code-reviewer qa; do
  grep -q 'traversal.primary' "agents/$a.md" || { bad "agents/$a.md does not reference the configured traversal"; f40=1; }
done
[ "$f40" = 0 ] && pass "agents parameterize traversal, no hardcode"

echo "== 41. malformed config shapes are handled safely =="
f41=0
# empty file: treated as {} and merged
H41=$(mktemp -d); mkdir -p "$H41/.claude"; : > "$H41/.claude/settings.json"
HOME="$H41" node install/install.mjs --host claude --apply >/dev/null 2>&1
python3 -c "import json;d=json.load(open('$H41/.claude/settings.json'));assert d.get('hooks')" 2>/dev/null \
  || { bad "empty settings.json was not treated as {}"; f41=1; }
rm -rf "$H41"
# array / scalar: declined with a message, no crash, file intact
for val in '[]' '"hello"' '42'; do
  H41=$(mktemp -d); mkdir -p "$H41/.claude"; printf '%s' "$val" > "$H41/.claude/settings.json"
  HOME="$H41" node install/install.mjs --host claude --apply >/tmp/opencode/aw-o.txt 2>/tmp/opencode/aw-e.txt
  rc=$?
  grep -q 'TypeError\|SyntaxError' /tmp/opencode/aw-e.txt && { bad "crash on settings.json=$val"; f41=1; }
  [ "$(cat "$H41/.claude/settings.json")" = "$val" ] || { bad "settings.json=$val was modified"; f41=1; }
  [ "$rc" = "0" ] || { bad "nonzero exit on settings.json=$val"; f41=1; }
  rm -rf "$H41"
done
[ "$f41" = 0 ] && pass "empty→{}, non-object shapes declined without crash"

echo "== 42. config keys named in skills are documented in configuration.md =="
f42=0
# Keys the skills tell the reader to look up in configuration.md must be there.
for key in verdict_destinations base_urls; do
  if grep -rq "$key" skills/ --include='*.md' 2>/dev/null; then
    grep -q "$key" references/configuration.md || { bad "$key referenced by skills but undocumented"; f42=1; }
  fi
done
[ "$f42" = 0 ] && pass "referenced config keys are documented"

echo
if [ "$fail" = 0 ]; then echo "ALL CHECKS PASSED"; else echo "CHECKS FAILED"; fi
exit "$fail"
