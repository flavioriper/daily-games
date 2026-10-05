#!/usr/bin/env python3
"""Gathers tools/mine_minigolf.gd's lines into content/minigolf.json.

    mkdir -p build/minigolf
    for b in 0 1 2 3; do for k in 1 2 3; do
        godot --headless --script res://tools/mine_minigolf.gd -- $b 40 $((b * 100 + k)) \\
            > build/minigolf/band$b.$k.jsonl 2> build/minigolf/band$b.$k.log & done; done; wait
    python3 tools/merge_minigolf.py

A hole grown twice (the same squares and cut corners) is kept once. The
proof's numbers are written as mined: a putt is chaotic past a bank or two,
and a rounded angle is another putt.
"""
import json, pathlib, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
prefix = sys.argv[1] if len(sys.argv) > 1 else "band"
bands = []
for b in range(4):
    seen, pool = set(), []
    for src in sorted((ROOT / "build/minigolf").glob(f"{prefix}{b}*.jsonl")):
        for line in src.read_text().splitlines():
            line = line.strip()
            if not line.startswith("{"):
                continue
            hole = json.loads(line)
            key = (tuple(sorted(hole["cells"])), tuple(sorted(hole.get("cuts", []))))
            if key in seen:
                continue
            seen.add(key)
            hole["cells"] = [int(c) for c in hole["cells"]]
            hole["cuts"] = [int(c) for c in hole.get("cuts", [])]
            hole["par"] = int(hole["par"])
            hole.pop("band", None)
            pool.append(hole)
    bands.append(pool)
    pars = {}
    for hole in pool:
        pars[hole["par"]] = pars.get(hole["par"], 0) + 1
    print(f"band {b}: {len(pool)} holes, pars {dict(sorted(pars.items()))}")
(ROOT / "content/minigolf.json").write_text(json.dumps({"bands": bands}, separators=(",", ":")) + "\n")
