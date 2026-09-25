import json, subprocess, sys

def run(inp):
    p = subprocess.run([sys.executable, "graph.py"], input=json.dumps(inp), capture_output=True, text=True)
    assert p.returncode == 0, p.stderr
    return json.loads(p.stdout)

def test_two_cycle_break_inferred_first():
    out = run({"edges": [
        {"from": "story:a", "to": "story:b", "kind": "explicit"},
        {"from": "story:b", "to": "story:a", "kind": "inferred"},
    ], "estimates": {"story:a": 1, "story:b": 1}, "statuses": {"story:a": "todo", "story:b": "todo"}})
    assert out["broken"] == [{"from": "story:b", "to": "story:a", "kind": "inferred",
                              "reason": "inferred in cycle; explicit edges preserved"}], out
    assert len(out["edges"]) == 1 and out["edges"][0]["kind"] == "explicit"

def test_self_loop_broken():
    out = run({"edges": [{"from": "story:a", "to": "story:a", "kind": "inferred"}],
               "estimates": {}, "statuses": {}})
    assert out["broken"] == [{"from": "story:a", "to": "story:a", "kind": "inferred",
                              "reason": "tie on all criteria; lexicographic (to, from) fallback"}], out
    assert out["edges"] == [], out

def test_tie_break_lexicographic():
    out = run({"edges": [
        {"from": "story:a", "to": "story:b", "kind": "inferred"},
        {"from": "story:b", "to": "story:a", "kind": "inferred"},
    ], "estimates": {}, "statuses": {}})
    # Both edges tie on (kind, dependants); lexicographic min of (to, from):
    # ("story:a","story:b") < ("story:b","story:a") → edge b→a breaks.
    assert out["broken"] == [{"from": "story:b", "to": "story:a", "kind": "inferred",
                              "reason": "tie on all criteria; lexicographic (to, from) fallback"}], out

def test_two_disjoint_cycles_both_broken():
    out = run({"edges": [
        {"from": "story:a", "to": "story:b", "kind": "inferred"},
        {"from": "story:b", "to": "story:a", "kind": "inferred"},
        {"from": "story:c", "to": "story:d", "kind": "inferred"},
        {"from": "story:d", "to": "story:c", "kind": "inferred"},
    ], "estimates": {}, "statuses": {}})
    # One weakest edge per cycle; the other members stay as acyclic remnants.
    assert len(out["broken"]) == 2 and len(out["edges"]) == 2, out
    remnants = {(e["from"], e["to"]) for e in out["edges"]}
    assert ("story:a", "story:b") in remnants and ("story:c", "story:d") in remnants, out
    again = run({"edges": out["edges"], "estimates": {}, "statuses": {}})
    assert again["broken"] == [], again

def test_dependant_count_tier():
    out = run({"edges": [
        {"from": "story:a", "to": "story:b", "kind": "inferred"},
        {"from": "story:b", "to": "story:a", "kind": "inferred"},
        {"from": "story:c", "to": "story:a", "kind": "inferred"},
    ], "estimates": {}, "statuses": {}})
    # Cycle a→b→a; both edges inferred. target b has 1 dependant (a→b),
    # target a has 2 (b→a, c→a) → fewest dependants of target breaks a→b.
    assert out["broken"] == [{"from": "story:a", "to": "story:b", "kind": "inferred",
                              "reason": "fewest dependants of target"}], out
    remnants = {(e["from"], e["to"]) for e in out["edges"]}
    assert ("story:b", "story:a") in remnants and ("story:c", "story:a") in remnants, out

def test_topo_ties_by_estimate():
    out = run({"edges": [
        {"from": "story:z", "to": "story:a", "kind": "explicit"},
        {"from": "story:y", "to": "story:a", "kind": "explicit"},
    ], "estimates": {"story:y": 1, "story:z": 5, "story:a": 2}, "statuses": {}})
    assert out["topo"][0] == "story:y" and out["topo"][1] == "story:z" and out["topo"][2] == "story:a"

def test_blocked_todo_list():
    out = run({"edges": [{"from": "story:a", "to": "story:b", "kind": "explicit"}],
               "estimates": {}, "statuses": {"story:a": "todo", "story:b": "in-dev"}})
    assert out["blocked"] == [{"story": "story:a", "blocking": ["story:b"]}], out

def test_acyclic_input_noop():
    out = run({"edges": [{"from": "story:a", "to": "story:b", "kind": "inferred"}],
               "estimates": {}, "statuses": {}})
    assert out["broken"] == [] and len(out["edges"]) == 1

def test_duplicate_edges_dedupe_explicit_wins():
    out = run({"edges": [
        {"from": "story:a", "to": "story:b", "kind": "explicit"},
        {"from": "story:a", "to": "story:b", "kind": "inferred"},
        {"from": "story:b", "to": "story:c", "kind": "inferred"},
    ], "estimates": {}, "statuses": {}})
    assert out["broken"] == [], out
    pairs = {(e["from"], e["to"]): e["kind"] for e in out["edges"]}
    assert pairs == {("story:a", "story:b"): "explicit",
                     ("story:b", "story:c"): "inferred"}, out

def test_isolated_nodes_in_topo():
    out = run({"edges": [{"from": "story:a", "to": "story:b", "kind": "explicit"}],
               "nodes": ["story:a", "story:o"],
               "estimates": {}, "statuses": {}})
    assert out["topo"] == ["story:a", "story:b", "story:o"], out

if __name__ == "__main__":
    for name, fn in sorted(globals().items()):
        if name.startswith("test_") and callable(fn):
            fn()
            print(f"PASS {name}")
    print("all graph tests passed")
