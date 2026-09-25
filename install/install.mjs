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
const valueOf = (f, d) => {
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

function listDirs(dir) {
  if (!fs.existsSync(dir)) return [];
  return fs
    .readdirSync(dir, { withFileTypes: true })
    .filter((d) => d.isDirectory())
    .map((d) => d.name)
    .sort();
}

function listFilesEnding(dir, ext) {
  if (!fs.existsSync(dir)) return [];
  return fs
    .readdirSync(dir, { withFileTypes: true })
    .filter((d) => d.isFile() && d.name.endsWith(ext))
    .map((d) => d.name)
    .sort();
}

// Collect every file under a skill dir, relative to the skill dir.
function skillFiles(skillDir) {
  const out = [];
  const walk = (abs, rel) => {
    for (const e of fs.readdirSync(abs, { withFileTypes: true })) {
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

  for (const { name, dir } of discoverSkills(skillsSrc)) {
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
        fs.mkdirSync(path.dirname(item.dst), { recursive: true });
        fs.writeFileSync(item.dst, content);
      }
    }
  }

  console.log(
    `\n${apply ? "Wrote" : "Would write"} ${wrote} file(s); ` +
      `${identical} unchanged; ${skipped} skipped (existing, differing).`
  );
  if (!apply) console.log("Dry-run only. Re-run with --apply to install.");
  if (skipped && !force)
    console.log("Note: skipped files already exist with different content. Nothing was overwritten.");
}

run();
