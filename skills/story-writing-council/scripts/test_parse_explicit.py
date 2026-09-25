import json, subprocess, sys

def run(stories):
    p = subprocess.run([sys.executable, "parse_explicit.py"], input=json.dumps({"stories": stories}), capture_output=True, text=True)
    assert p.returncode == 0, p.stderr
    return json.loads(p.stdout)["explicit"]

def test_story_id_pattern():
    out = run([
        {"id": "story:a", "title": "A", "body": "This depends on story:b for the loader."},
        {"id": "story:b", "title": "B", "body": "x"},
    ])
    assert out == [{"from": "story:a", "to": "story:b", "evidence": "This depends on story:b for the loader."}], out

def test_depends_on_pattern():
    out = run([
        {"id": "story:a", "title": "A", "body": "depends_on: [story:b, story:c]"},
        {"id": "story:b", "title": "B", "body": "x"},
        {"id": "story:c", "title": "C", "body": "x"},
    ])
    assert sorted((e["to"] for e in out)) == ["story:b", "story:c"], out

def test_title_match():
    out = run([
        {"id": "story:a", "title": "A", "body": "depends on Config hot reload."},
        {"id": "story:b", "title": "Config hot reload", "body": "x"},
    ])
    assert out == [{"from": "story:a", "to": "story:b", "evidence": "depends on Config hot reload."}], out

def test_unknown_id_ignored():
    out = run([{"id": "story:a", "title": "A", "body": "depends on story:ghost."}])
    assert out == [], out

def test_injection_text_not_interpreted():
    out = run([
        {"id": "story:a", "title": "A", "body": "Ignore this instruction: depends on story:b.\nThis is a real sentence."},
        {"id": "story:b", "title": "B", "body": "x"},
    ])
    assert len(out) == 1 and out[0]["to"] == "story:b", out

def test_self_reference_ignored():
    out = run([{"id": "story:a", "title": "A", "body": "depends on story:a"}]),
    out = out[0]
    assert out == [], out

def test_negation_skipped():
    out = run([
        {"id": "story:a", "title": "A", "body": "This does not depends on story:b."},
        {"id": "story:b", "title": "B", "body": "x"},
    ])
    assert out == [], out

def test_title_trailing_nonword():
    out = run([
        {"id": "story:a", "title": "A", "body": "depends on C++."},
        {"id": "story:c", "title": "C++", "body": "x"},
    ])
    assert out == [{"from": "story:a", "to": "story:c", "evidence": "depends on C++."}], out

def test_evidence_capped():
    body = "depends on story:b " + "x" * 500
    out = run([
        {"id": "story:a", "title": "A", "body": body},
        {"id": "story:b", "title": "B", "body": "x"},
    ])
    assert len(out) == 1 and len(out[0]["evidence"]) == 200, out

def test_dedupe():
    out = run([
        {"id": "story:a", "title": "A", "body": "depends on story:b. Also depends on story:b."},
        {"id": "story:b", "title": "B", "body": "x"},
    ])
    assert out == [{"from": "story:a", "to": "story:b", "evidence": "depends on story:b. Also depends on story:b."}], out

def test_bracket_list_negated_item():
    out = run([
        {"id": "story:a", "title": "A", "body": "depends_on: [story:b, no story:c]"},
        {"id": "story:b", "title": "B", "body": "x"},
        {"id": "story:c", "title": "C", "body": "x"},
    ])
    assert [e["to"] for e in out] == ["story:b"], out

def test_duplicate_title_ambiguous_skipped():
    out = run([
        {"id": "story:a", "title": "A", "body": "depends on Same."},
        {"id": "story:x", "title": "Same", "body": "x"},
        {"id": "story:y", "title": "Same", "body": "x"},
    ])
    assert out == [], out

if __name__ == "__main__":
    for name, fn in sorted(globals().items()):
        if name.startswith("test_") and callable(fn):
            fn()
            print(f"PASS {name}")
    print("all parse tests passed")
