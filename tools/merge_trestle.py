#!/usr/bin/env python3
"""Gathers tools/mine_trestle.gd's lines into content/trestle.json.

    for b in 0 1 2 3; do godot --headless --script res://tools/mine_trestle.gd -- $b 20 \\
        > build/trestle/band$b.jsonl 2> build/trestle/band$b.log & done; wait
    python3 tools/merge_trestle.py

A level dealt twice (same gap, same pins, same rock) is kept once.
"""
import json, pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
bands = []
for b in range(4):
    seen, pool = set(), []
    src = ROOT / f"build/trestle/band{b}.jsonl"
    for line in src.read_text().splitlines() if src.exists() else []:
        line = line.strip()
        if not line.startswith("{"):
            continue
        lv = json.loads(line)
        key = (lv["w"], lv["dy"], tuple(sorted(tuple(a) for a in lv["anchors"])), tuple(lv.get("rock") or ()))
        if key in seen:
            continue
        seen.add(key)
        pool.append(lv)
    bands.append(pool)
    print(f"band {b}: {len(pool)} levels")
(ROOT / "content/trestle.json").write_text(json.dumps({"bands": bands}, separators=(",", ":")) + "\n")
