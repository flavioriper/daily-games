#!/usr/bin/env python3
"""Gathers tools/mine_horse.gd's lines into content/horse.json.

    mkdir -p build/horse
    for b in 0 1 2 3; do for k in 1 2; do
        godot --headless --script res://tools/mine_horse.gd -- $b 80 $((b * 100 + k)) \\
            > build/horse/band$b.$k.jsonl 2> build/horse/band$b.$k.log & done; done; wait
    python3 tools/merge_horse.py

A meadow laid twice (the same water, boulders and horse) is kept once.
"""
import json, pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
bands = []
for b in range(4):
    seen, pool = set(), []
    for src in sorted((ROOT / "build/horse").glob(f"band{b}*.jsonl")):
        for line in src.read_text().splitlines():
            line = line.strip()
            if not line.startswith("{"):
                continue
            m = json.loads(line)
            key = (tuple(m["water"]), tuple(m["stones"]), m["horse"])
            if key in seen:
                continue
            seen.add(key)
            for k, v in list(m.items()):
                if isinstance(v, float):
                    m[k] = int(v)
                elif isinstance(v, list):
                    m[k] = [[int(x) for x in e] if isinstance(e, list) else int(e) for e in v]
            for k in ("apples", "gold", "bees", "tunnels"):
                if not m[k]:
                    del m[k]
            pool.append(m)
    bands.append(pool)
    best = sorted(m["best"] for m in pool)
    if best:
        print(f"band {b}: {len(pool)} meadows, best {best[0]}..{best[-1]}, median {best[len(best) // 2]}")
(ROOT / "content/horse.json").write_text(json.dumps({"bands": bands}, separators=(",", ":")) + "\n")
