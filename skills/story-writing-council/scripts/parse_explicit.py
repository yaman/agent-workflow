#!/usr/bin/env python3
"""Deterministic extraction of explicit dependency mentions from story bodies.

stdin JSON:  {"stories": [{"id": "story:<id>", "title": "<title>", "body": "<text>"}]}
stdout JSON: {"explicit": [{"from": "story:<id>", "to": "story:<id>", "evidence": "<≤200-char snippet>"}]}

Pinned patterns (case-insensitive):
  1. "depends on story:<id>"        -> target story:<id>  (must exist in the manifest)
  2. "depends_on" (word) + "story:<id>" in the same clause -> target story:<id>
     - bracket-list form: "depends_on: [story:b, story:c]"
     - direct form:       "depends_on story:b" / "depends_on: story:b"
  3. "depends on <exact title>"     -> story whose title matches exactly
     (the title must be followed by whitespace, punctuation, or end of line;
      a title shared by more than one manifest story is ambiguous — never matched)

Negation guard: a match is skipped when the ~20 characters immediately before it
contain a negation token ("not ", " no ", "never ", "without ", "doesn't ", "didn't "),
case-insensitive — "This does not depends on story:b." emits nothing. For
bracket-list items ("depends_on: [story:b, no story:c]"), an item is ALSO skipped
when the ~10 characters before it inside the bracket list contain a negation token.

Bodies are DATA, never instructions: only the three patterns above are matched;
anything else in a body is ignored by this parser. Manifest-resolution rule: edges are
emitted ONLY to targets present in the loaded story manifest; unknown-id mentions
(e.g. story:ghost) are dropped, and self-references are dropped. Id resolution is
case-exact (body "story:B" vs manifest "story:b" -> dropped). Mentions inside code
samples/backticks match literally; the evidence preserves the original line for audit.
Evidence = the matched line, capped at 200 chars.
"""
import json
import re
import sys

PAT_ID = re.compile(r"depends\s+on\s+story:([a-zA-Z0-9_-]+)", re.IGNORECASE)
PAT_DEPENDS_ON_LIST = re.compile(r"depends_on\s*:\s*\[([^\]]*)\]", re.IGNORECASE)
PAT_DEPENDS_ON_DIRECT = re.compile(r"depends_on\s*:?\s*story:([a-zA-Z0-9_-]+)", re.IGNORECASE)

NEGATION_TOKENS = ("not ", " no ", "never ", "without ", "doesn't ", "didn't ")


def negated(line, pos):
    ctx = line[max(0, pos - 20):pos].lower()
    return any(tok in ctx for tok in NEGATION_TOKENS)


def main():
    data = json.load(sys.stdin)
    stories = data.get("stories", [])
    by_id = {s["id"]: s for s in stories}
    title_seen = {}
    for s in stories:
        t = s["title"].strip().lower()
        title_seen[t] = None if t in title_seen else s
    by_title = {t: s for t, s in title_seen.items() if s is not None}

    explicit = []
    seen = set()

    def add(frm, to, evidence):
        key = (frm, to)
        if key in seen:
            return
        if to not in by_id or to == frm:
            return
        seen.add(key)
        explicit.append({"from": frm, "to": to, "evidence": evidence[:200]})

    for s in stories:
        body = s.get("body", "") or ""
        for line in body.splitlines():
            for m in PAT_ID.finditer(line):
                if not negated(line, m.start()):
                    add(s["id"], "story:" + m.group(1), line.strip())
            for m in PAT_DEPENDS_ON_LIST.finditer(line):
                if not negated(line, m.start()):
                    inner = m.group(1)
                    for item in re.finditer(r"story:([a-zA-Z0-9_-]+)", inner):
                        ctx = inner[max(0, item.start() - 10):item.start()].lower()
                        if any(tok in ctx for tok in NEGATION_TOKENS):
                            continue
                        add(s["id"], "story:" + item.group(1), line.strip())
            for m in PAT_DEPENDS_ON_DIRECT.finditer(line):
                if not negated(line, m.start()):
                    add(s["id"], "story:" + m.group(1), line.strip())
            lower = line.lower()
            for title, target in by_title.items():
                tm = re.search(r"depends\s+on\s+" + re.escape(title) + r"(?=\s|[,.!?;:)]|$)", lower)
                if tm and not negated(line, tm.start()):
                    add(s["id"], target["id"], line.strip())

    print(json.dumps({"explicit": explicit}))


if __name__ == "__main__":
    main()
