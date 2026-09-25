#!/usr/bin/env python3
"""Deterministic dependency-graph operations for story-writing-council mapping mode.

stdin JSON:  {"edges": [{"from": "story:<id>", "to": "story:<id>", "kind": "explicit"|"inferred"}],
              "estimates": {"story:<id>": int}, "statuses": {"story:<id>": str},
              "nodes": ["story:<id>", ...]}
stdout JSON: {"broken": [{"from","to","kind","reason"}], "edges": [final acyclic list],
              "topo": ["story:<id>", ...], "blocked": [{"story", "blocking": [...]}]}

`nodes` (optional) lists every loaded story id; ids not reachable from any edge
are appended to `topo` after all edge-participating ids, ordered by (estimate, id).

Duplicate (from,to) edges are deduped before cycle handling: one edge per pair, and
when duplicates differ in kind the explicit one wins (inferred dupes are dropped).

Tie-break for weakest edge in a cycle (pinned): explicit > inferred (break inferred
first), then fewest dependants of the target, then lexicographic (to, from).
No model calls in this file — it must stay pure.
"""
import json
import sys
from collections import defaultdict

KIND_RANK = {"explicit": 0, "inferred": 1}


def topo_sort(edges, estimates, nodes=None):
    adj = defaultdict(list)
    indeg = defaultdict(int)
    ids = set()
    for e in edges:
        adj[e["from"]].append(e["to"])
        indeg[e["to"]] += 1
        ids.update((e["from"], e["to"]))
    ready = sorted(
        (i for i in ids if indeg[i] == 0),
        key=lambda i: (estimates.get(i, 0), i),
    )
    order = []
    while ready:
        u = ready.pop(0)
        order.append(u)
        for v in adj[u]:
            indeg[v] -= 1
            if indeg[v] == 0:
                ready.append(v)
                ready.sort(key=lambda i: (estimates.get(i, 0), i))
    if nodes:
        reachable = set()
        for e in edges:
            reachable.add(e["from"])
            reachable.add(e["to"])
        order.extend(sorted(
            (n for n in nodes if n not in reachable),
            key=lambda i: (estimates.get(i, 0), i),
        ))
    return order


def find_cycle(edges):
    adj = defaultdict(list)
    for e in edges:
        adj[e["from"]].append(e)
    state = {}
    parent_edge = {}

    def dfs(u, edge_into):
        state[u] = 1
        parent_edge[u] = edge_into
        for e in adj[u]:
            v = e["to"]
            if state.get(v, 0) == 1:
                path = []
                cur = u
                while cur != v:
                    path.append(parent_edge[cur])
                    cur = parent_edge[cur]["from"]
                path.append(e)
                path.reverse()
                return path
            if state.get(v, 0) == 0:
                found = dfs(v, e)
                if found:
                    return found
        state[u] = 2
        return None

    for u in list(adj):
        if state.get(u, 0) == 0:
            found = dfs(u, None)
            if found:
                return found
    return None


def weakest_edge(cycle_edges, all_edges):
    dependants = defaultdict(int)
    for e in all_edges:
        dependants[e["to"]] += 1
    ordered: list[dict] = sorted(
        cycle_edges,
        key=lambda e: (
            -KIND_RANK[e["kind"]],
            dependants[e["to"]],
            e["to"],
            e["from"],
        ),
    )
    weakest = ordered[0]
    if len(ordered) == 1:
        return weakest, "tie on all criteria; lexicographic (to, from) fallback"
    runner_up = ordered[1]
    if weakest["kind"] != runner_up["kind"]:
        reason = "inferred in cycle; explicit edges preserved"
    elif dependants[weakest["to"]] != dependants[runner_up["to"]]:
        reason = "fewest dependants of target"
    else:
        reason = "tie on all criteria; lexicographic (to, from) fallback"
    return weakest, reason


def blocked_stories(edges, statuses):
    dep_edges = defaultdict(list)
    for e in edges:
        if statuses.get(e["to"], "done") != "done":
            dep_edges[e["from"]].append(e["to"])
    return [
        {"story": s, "blocking": sorted(deps)}
        for s, deps in sorted(dep_edges.items())
        if statuses.get(s, "todo") == "todo"
    ]


def main():
    data = json.load(sys.stdin)
    edges = list(data.get("edges", []))
    estimates = data.get("estimates", {})
    statuses = data.get("statuses", {})
    nodes = data.get("nodes", [])
    broken = []

    dedup = {}
    key_order = []
    for e in edges:
        key = (e["from"], e["to"])
        if key not in dedup:
            dedup[key] = e
            key_order.append(key)
        elif e["kind"] == "explicit" and dedup[key]["kind"] != "explicit":
            dedup[key] = e
    edges = [dedup[k] for k in key_order]

    while True:
        cycle = find_cycle(edges)
        if cycle is None:
            break
        target, reason = weakest_edge(cycle, edges)
        broken.append({"from": target["from"], "to": target["to"],
                       "kind": target["kind"], "reason": reason})
        edges = [e for e in edges if not (e["from"] == target["from"] and e["to"] == target["to"])]

    order = topo_sort(edges, estimates, nodes)
    print(json.dumps({
        "broken": broken,
        "edges": edges,
        "topo": order,
        "blocked": blocked_stories(edges, statuses),
    }))


if __name__ == "__main__":
    main()
