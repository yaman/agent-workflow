#!/usr/bin/env node
// install.mjs — install the agent-workflow skills + agents into a host.
//
// One canonical source tree, rendered for the host's on-disk contract:
//   opencode      skills/ + agents/ (verbatim; the canonical frontmatter is
//                 opencode's own, since it is the primary host)
//   claude        skills/ + agents/ with the agent frontmatter translated
//                 (steps->maxTurns, permission->tools, mode dropped)
//
// Non-destructive by default: prints a plan and writes nothing. Pass --apply to
// write. Existing files are never overwritten without --force; they are
// reported and skipped. The repo itself is never modified.

import fs from "node:fs";
import path from "node:path";
import os from "node:os";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const pkgRoot = path.resolve(here, "..");

const argv = process.argv.slice(2);
const has = (f) => argv.includes(f);
// Accept both `--flag value` and `--flag=value`. Falls back to `d` when absent.
const valueOf = (f, d) => {
  const eq = argv.find((a) => a.startsWith(`${f}=`));
  if (eq !== undefined) return eq.slice(f.length + 1);
  const i = argv.indexOf(f);
  return i !== -1 && argv[i + 1] && !argv[i + 1].startsWith("--") ? argv[i + 1] : d;
};

if (has("--help") || has("-h")) {
  console.log(`agent-workflow installer

Usage:
  node install/install.mjs --host <claude|opencode|both> [options]

Options:
  --host <c>      Target host (required): claude | opencode | both
  --target <dir>  Base directory to install into.
                  claude   default: ~/.claude
                  opencode default: ~/.config/opencode
                  (skills -> <target>/skills, agents -> <target>/agents)
  --model <m>     Model id to emit in Claude agent frontmatter (default: none,
                  so each subagent inherits the session model).
  --apply         Actually write. Without it, prints the plan only (dry-run).
  --force         Overwrite existing files (default: skip + report).
  --bootstrap     Register the workflow charter at session start (default: on).
                  claude:   merges a SessionStart hook into settings.json
                  opencode: adds the charter to the config instructions list
  --no-bootstrap  Skip the session-start registration.
  --uninstall-bootstrap  Remove a previously registered bootstrap.
  --print-agent N Print the agent N rendered for the host, then exit (debug).
  --help          This text.
`);
  process.exit(0);
}

// Debug seam: render a single agent for a host without touching disk.
// Handled inside run() (below) because it needs the render helpers defined.

const host = valueOf("--host", null);
if (!host || !["claude", "opencode", "both"].includes(host)) {
  console.error("error: --host must be claude | opencode | both (see --help)");
  process.exit(2);
}
const apply = has("--apply");
const force = has("--force");
const model = valueOf("--model", null);
const bootstrap = !has("--no-bootstrap");
const uninstallBootstrap = has("--uninstall-bootstrap");

// `--host both` writes opencode-shaped and claude-shaped agents to different
// paths; a single --target would make them collide. Require per-host defaults.
if (host === "both" && valueOf("--target", null)) {
  console.error(
    "error: --host both cannot be combined with --target (each host needs its own\n" +
      "       agents/ directory). Run the installer once per host instead."
  );
  process.exit(2);
}

// ---------------------------------------------------------------- frontmatter

// Minimal frontmatter split: returns { fm: string, body: string }. Only handles
// the flat `key: value` / nested-indented shape this package uses.
function splitFrontmatter(text) {
  const m = text.match(/^---\r?\n([\s\S]*?)\r?\n---\r?\n?([\s\S]*)$/);
  if (!m) return { fm: "", body: text };
  return { fm: m[1], body: m[2] };
}

function fmGet(fm, key) {
  const re = new RegExp(`^${key}\\s*:\\s*(.+)$`, "m");
  const m = fm.match(re);
  return m ? m[1].trim().replace(/^["']|["']$/g, "") : null;
}

// ---------------------------------------------------- opencode -> claude agent

const READ_ONLY_AGENTS = new Set(["architect", "code-reviewer", "qa"]);
const READ_ONLY_TOOLS = "Read, Grep, Glob, WebFetch, WebSearch, TodoWrite";

function renderClaudeAgent(name, text) {
  const { fm, body } = splitFrontmatter(text);
  const description = fmGet(fm, "description") || `${name} subagent`;
  const steps = fmGet(fm, "steps");
  // Quote the description as a JSON string: YAML accepts that form, and it is
  // required whenever the value contains `: ` or other YAML-significant chars.
  // Claude Code's frontmatter parser is strict (unlike opencode's), so an
  // unquoted description with a colon fails to parse and silently drops all
  // metadata.
  const lines = [
    `name: ${name}`,
    `description: ${JSON.stringify(description)}`,
  ];
  if (READ_ONLY_AGENTS.has(name)) lines.push(`tools: ${READ_ONLY_TOOLS}`);
  if (steps) lines.push(`maxTurns: ${steps}`);
  if (model) lines.push(`model: ${JSON.stringify(model)}`);
  return `---\n${lines.join("\n")}\n---\n${body.startsWith("\n") ? body : "\n" + body}`;
}

// ------------------------------------------------------------------- planning

function resolveTarget(h) {
  const explicit = valueOf("--target", null);
  if (explicit) return path.resolve(explicit);
  return h === "claude"
    ? path.join(os.homedir(), ".claude")
    : path.join(os.homedir(), ".config", "opencode");
}

function listFilesEnding(dir, ext) {
  if (!fs.existsSync(dir)) return [];
  return fs
    .readdirSync(dir, { withFileTypes: true })
    .filter((d) => d.isFile() && d.name.endsWith(ext))
    .map((d) => d.name)
    .sort();
}

// Generated/tooling artifacts that must never be installed as skill content.
const IGNORED_DIRS = new Set(["__pycache__", ".pytest_cache", "node_modules", ".git"]);
const IGNORED_FILES = /\.(pyc|pyo)$/;

// Collect every file under a skill dir, relative to the skill dir, skipping
// generated artifacts (pytest/py caches) that a local test run may leave behind.
function skillFiles(skillDir) {
  const out = [];
  const walk = (abs, rel) => {
    for (const e of fs.readdirSync(abs, { withFileTypes: true })) {
      if (e.isDirectory() && IGNORED_DIRS.has(e.name)) continue;
      if (e.isFile() && IGNORED_FILES.test(e.name)) continue;
      const a = path.join(abs, e.name);
      const r = rel ? path.join(rel, e.name) : e.name;
      if (e.isDirectory()) walk(a, r);
      else if (e.isFile()) out.push(r);
    }
  };
  walk(skillDir, "");
  return out.sort();
}

// Discover every skill directory under skills/ (including skills/vendor/<pack>/<skill>/)
// by finding directories that directly contain a SKILL.md. Returns
// { name, dir } where name is the skill's own directory name (vending must
// install flat — hosts scan immediate subdirectories of their skills dir).
function discoverSkills(skillsSrc, maxDepth = 4) {
  const found = [];
  const walk = (abs, depth) => {
    if (depth > maxDepth) return;
    let entries;
    try {
      entries = fs.readdirSync(abs, { withFileTypes: true });
    } catch {
      return;
    }
    const hasSkillMd = entries.some((e) => e.isFile() && e.name === "SKILL.md");
    if (hasSkillMd) {
      // A directory containing SKILL.md is one skill; its children are its files.
      found.push({ name: path.basename(abs), dir: abs });
      return;
    }
    for (const e of entries) {
      if (e.isDirectory()) walk(path.join(abs, e.name), depth + 1);
    }
  };
  walk(skillsSrc, 0);
  return found.sort((a, b) => a.name.localeCompare(b.name));
}

function planFor(h) {
  const target = resolveTarget(h);
  const skillsSrc = path.join(pkgRoot, "skills");
  const agentsSrc = path.join(pkgRoot, "agents");
  const plan = [];

  // Package integrity: the installer must not silently install a partial pack
  // (e.g. a corrupt checkout with no skills/ or agents/).
  const skillsFound = discoverSkills(skillsSrc);
  if (skillsFound.length === 0) {
    console.error(`error: no skills found under ${skillsSrc} — is this a complete checkout?`);
    process.exit(1);
  }
  if (!fs.existsSync(agentsSrc) || listFilesEnding(agentsSrc, ".md").length === 0) {
    console.error(`error: no agent files found under ${agentsSrc} — is this a complete checkout?`);
    process.exit(1);
  }

  for (const { name, dir } of skillsFound) {
    for (const rel of skillFiles(dir)) {
      plan.push({
        kind: "skill",
        src: path.join(dir, rel),
        dst: path.join(target, "skills", name, rel),
      });
    }
  }
  for (const f of listFilesEnding(agentsSrc, ".md")) {
    const name = f.replace(/\.md$/, "");
    plan.push({
      kind: "agent",
      name,
      host: h,
      src: path.join(agentsSrc, f),
      dst: path.join(target, "agents", f),
    });
  }
  return { target, plan };
}

// --------------------------------------------------------------------- execute

// ------------------------------------------------------------ session bootstrap

// Merge a JSON object into a settings file idempotently. Returns a report
// describing what changed, without writing unless `write` is true.
// Read a settings file as a JSON object. Returns:
//   {} for a missing file or an empty/whitespace-only file,
//   the parsed object when the file holds a JSON object,
//   { error: "unparseable" } when the JSON does not parse (e.g. JSONC comments),
//   { error: "not-object" } when it parses but is an array/scalar/null.
function readJsonFile(p) {
  if (!fs.existsSync(p)) return {};
  const raw = fs.readFileSync(p, "utf8");
  if (raw.trim() === "") return {};
  let parsed;
  try {
    parsed = JSON.parse(raw);
  } catch {
    return { error: "unparseable" };
  }
  if (parsed === null || typeof parsed !== "object" || Array.isArray(parsed)) {
    return { error: "not-object" };
  }
  return parsed;
}

// A settings object is usable when it is a plain object (not an error marker).
const isSettings = (s) => s !== null && typeof s === "object" && !s.error;

// A precise, actionable reason for a settings file that could not be used.
function jsonReason(settingsPath, settings) {
  const base = path.basename(settingsPath);
  const fix =
    `register the charter manually (a SessionStart hook in settings.json, or ` +
    `the charter path in the opencode instructions array), or set AGENT_WORKFLOW=1`;
  if (settings && settings.error === "unparseable") {
    return `${base} does not parse as JSON (comments or trailing commas?) and cannot be edited safely — ${fix}`;
  }
  return `${base} does not contain a JSON object (found an array or scalar) — ${fix}`;
}

function backupFile(p) {
  if (!fs.existsSync(p)) return null;
  const stamp = new Date().toISOString().replace(/[:.]/g, "-");
  const bak = `${p}.aw-bak-${stamp}`;
  fs.copyFileSync(p, bak);
  return bak;
}

// claude: ensure settings.json has exactly one SessionStart handler for our hook.
function planClaudeBootstrap(target, hookScript) {
  const settingsPath = path.join(target, "settings.json");
  const settings = readJsonFile(settingsPath);
  if (!isSettings(settings)) {
    return { path: settingsPath, ok: false, reason: jsonReason(settingsPath, settings) };
  }
  const hooks = (settings.hooks ||= {});
  const groups = (hooks.SessionStart ||= []);
  const already = groups.some((g) =>
    (g.hooks || []).some((hh) => hh.command === hookScript)
  );
  if (already) {
    return { path: settingsPath, ok: true, changed: false, settings };
  }
  groups.push({
    matcher: "startup|resume|clear|compact",
    hooks: [{ type: "command", command: hookScript }],
  });
  return { path: settingsPath, ok: true, changed: true, settings };
}

function unplanClaudeBootstrap(target, hookScript) {
  const settingsPath = path.join(target, "settings.json");
  const settings = readJsonFile(settingsPath);
  if (!isSettings(settings) || !settings.hooks || !settings.hooks.SessionStart) {
    return { path: settingsPath, ok: true, changed: false, settings: settings || {} };
  }
  const before = settings.hooks.SessionStart.length;
  settings.hooks.SessionStart = settings.hooks.SessionStart
    .map((g) => ({ ...g, hooks: (g.hooks || []).filter((hh) => hh.command !== hookScript) }))
    .filter((g) => (g.hooks || []).length > 0);
  const changed = settings.hooks.SessionStart.length !== before;
  if (settings.hooks.SessionStart.length === 0) delete settings.hooks.SessionStart;
  if (settings.hooks && Object.keys(settings.hooks).length === 0) delete settings.hooks;
  return { path: settingsPath, ok: true, changed, settings };
}

// opencode: ensure the charter path is in the config `instructions` array.
// Resolve the same way plan and unplan do, so the two stay symmetric: prefer an
// existing opencode.jsonc, else opencode.json, else default to opencode.json.
function resolveOpencodeConfig(target) {
  const candidates = ["opencode.json", "opencode.jsonc"].map((f) => path.join(target, f));
  return candidates.find((p) => fs.existsSync(p)) || candidates[0];
}

function planOpencodeBootstrap(target, charterPath) {
  const settingsPath = resolveOpencodeConfig(target);
  const settings = readJsonFile(settingsPath);
  if (!isSettings(settings)) {
    return { path: settingsPath, ok: false, reason: jsonReason(settingsPath, settings) };
  }
  const list = Array.isArray(settings.instructions) ? settings.instructions : [];
  if (list.includes(charterPath)) {
    return { path: settingsPath, ok: true, changed: false, settings };
  }
  settings.instructions = [...list, charterPath];
  return { path: settingsPath, ok: true, changed: true, settings };
}

function unplanOpencodeBootstrap(target, charterPath) {
  const settingsPath = resolveOpencodeConfig(target);
  const settings = readJsonFile(settingsPath);
  if (!isSettings(settings) || !Array.isArray(settings.instructions)) {
    return { path: settingsPath, ok: true, changed: false, settings: settings || {} };
  }
  const before = settings.instructions.length;
  settings.instructions = settings.instructions.filter((p) => p !== charterPath);
  if (settings.instructions.length === 0) delete settings.instructions;
  return { path: settingsPath, ok: true, changed: settings.instructions?.length !== before, settings };
}

// Write a file, or fail with a clean message instead of an exception trace.
// `mode` optionally sets the permission bits (e.g. 0o755 for scripts).
function writeOrFail(dst, content, mode) {
  try {
    fs.mkdirSync(path.dirname(dst), { recursive: true });
    fs.writeFileSync(dst, content);
    if (mode !== undefined) fs.chmodSync(dst, mode);
    return true;
  } catch (e) {
    console.error(`\nerror: cannot write ${dst}\n       ${e.code || ""} ${e.message}`.trimEnd());
    console.error(
      `\nA partial install may exist. Re-run once the cause is fixed;` +
        ` existing files are skipped unless --force.`
    );
    process.exit(1);
  }
}

// Source permission bits, so executable scripts stay executable after install.
function sourceMode(src) {
  try {
    return fs.statSync(src).mode & 0o777;
  } catch {
    return undefined;
  }
}

function runBootstrap(hosts) {
  // The hook script and charter are installed under the target:
  //   <target>/hooks/session-start.sh, <target>/CHARTER.md
  for (const h of hosts) {
    const target = resolveTarget(h);
    const hookScript = path.join(target, "hooks", "session-start.sh");
    const charterPath = path.join(target, "CHARTER.md");

    if (uninstallBootstrap) {
      const r = h === "claude"
        ? unplanClaudeBootstrap(target, hookScript)
        : unplanOpencodeBootstrap(target, charterPath);
      console.log(`\n=== bootstrap uninstall: ${h} -> ${r.path} ===`);
      if (!r.ok) { console.log(`  ! ${r.reason} — left untouched`); continue; }
      if (!r.changed) { console.log("  = no bootstrap entry present"); continue; }
      console.log("  - remove bootstrap entry");
      if (apply) { backupFile(r.path); writeOrFail(r.path, JSON.stringify(r.settings, null, 2) + "\n"); }
      continue;
    }

    if (!bootstrap) continue;

    // Files the bootstrap needs (placed by the normal file plan only for
    // claude's hook; ensure both exist regardless of file-plan skipping).
    const needs = h === "claude"
      ? [[path.join(pkgRoot, "hooks", "session-start.sh"), hookScript], [path.join(pkgRoot, "bootstrap", "CHARTER.md"), charterPath]]
      : [[path.join(pkgRoot, "bootstrap", "CHARTER.md"), charterPath]];

    console.log(`\n=== bootstrap: ${h} ===`);
    for (const [src, dst] of needs) {
      if (!fs.existsSync(src)) {
        console.error(`error: missing package file ${src} — is this a complete checkout?`);
        process.exit(1);
      }
      if (fs.existsSync(dst) && !force) { console.log(`  = ${path.relative(target, dst)} (present)`); continue; }
      console.log(`  + ${path.relative(target, dst)}`);
      if (apply) {
        writeOrFail(dst, fs.readFileSync(src));
        try { if (dst.endsWith(".sh")) fs.chmodSync(dst, 0o755); } catch { /* best effort */ }
      }
    }

    const r = h === "claude"
      ? planClaudeBootstrap(target, hookScript)
      : planOpencodeBootstrap(target, charterPath);
    if (!r.ok) { console.log(`  ! ${r.reason} — left untouched`); continue; }
    console.log(`  ${r.changed ? "+ merge" : "="} SessionStart/instructions in ${path.relative(target, r.path)}`);
    if (r.changed && apply) {
      backupFile(r.path);
      writeOrFail(r.path, JSON.stringify(r.settings, null, 2) + "\n");
    }
  }
}

function run() {
  // Debug seam: render one agent for a host, no disk writes.
  if (has("--print-agent")) {
    const name = valueOf("--print-agent", null);
    const asHost = valueOf("--host", "claude") === "opencode" ? "opencode" : "claude";
    if (!name) {
      console.error("error: --print-agent needs an agent name");
      process.exit(2);
    }
    const src = path.join(pkgRoot, "agents", `${name}.md`);
    if (!fs.existsSync(src)) {
      console.error(`error: no such agent: ${name}`);
      process.exit(2);
    }
    const text = fs.readFileSync(src, "utf8");
    process.stdout.write(asHost === "opencode" ? text : renderClaudeAgent(name, text));
    process.exit(0);
  }

  const hosts = host === "both" ? ["claude", "opencode"] : [host];
  let wrote = 0;
  let skipped = 0;
  let identical = 0;

  // A bare `--apply` (no --target) writes into the host's real config directory.
  // Say so loudly, once, before touching anything.
  if (apply && !valueOf("--target", null)) {
    console.log(
      "\nNOTE: no --target given; applying to your real host config directory.\n" +
        "      Pass --target DIR to install into a sandbox instead."
    );
  }

  for (const h of hosts) {
    const { target, plan } = planFor(h);
    console.log(`\n=== ${h} -> ${target} (${apply ? "APPLY" : "dry-run"}) ===`);
    for (const item of plan) {
      const label = path.relative(target, item.dst);
      const content =
        item.kind === "agent" && h === "claude"
          ? renderClaudeAgent(item.name, fs.readFileSync(item.src, "utf8"))
          : fs.readFileSync(item.src); // Buffer for verbatim copies

      const exists = fs.existsSync(item.dst);
      if (exists && !force) {
        const same =
          typeof content === "string"
            ? fs.readFileSync(item.dst, "utf8") === content
            : Buffer.compare(fs.readFileSync(item.dst), content) === 0;
        if (same) {
          console.log(`  = ${label} (unchanged)`);
          identical++;
        } else {
          console.log(`  ! ${label} (exists, different — skipped; use --force to overwrite)`);
          skipped++;
        }
        continue;
      }
      console.log(`  + ${label}`);
      wrote++;
      if (apply) {
        // Preserve source exec bits for scripts; rendered agents are plain files.
        const mode = item.kind === "skill" ? sourceMode(item.src) : undefined;
        writeOrFail(item.dst, content, mode);
      }
    }
  }

  console.log(
    `\n${apply ? "Wrote" : "Would write"} ${wrote} file(s); ` +
      `${identical} unchanged; ${skipped} skipped (existing, differing).`
  );

  runBootstrap(hosts);

  if (!apply) console.log("Dry-run only. Re-run with --apply to install.");
  if (skipped && !force)
    console.log("Note: skipped files already exist with different content. Nothing was overwritten.");
}

run();
