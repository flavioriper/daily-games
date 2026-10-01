#!/usr/bin/env python3
"""Merges the Sweethearts miner's parts into content/insane/marigold.json.

The KEEP gardens with the fewest openers (the hardest to start) are kept.
A bud's place is a float32 on the phone, so nine significant digits carry it
exactly and halve the file; the proof's angles are doubles and keep all of
theirs. tests/_probe_marigold.gd replays every entry from the file.

    python3 tools/merge_marigold_sweethearts.py part0.json part1.json ...
"""
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "content/insane/marigold.json"
KEEP = 160


def main() -> None:
    boards = []
    for path in sys.argv[1:]:
        for b in json.loads(pathlib.Path(path).read_text())["boards"]:
            boards.append({
                "pos": [float(f"{x:.9g}") for x in b["pos"]],
                "kind": b["kind"],
                "pair": b["pair"],
                "proof": b["proof"],
                "violet": b["violet"],
                "openers": b["openers"],
            })
    boards.sort(key=lambda b: b["openers"])
    boards = boards[:KEEP]
    doc = {"version": 1,
           "note": "Marigold Insane, Sweethearts: tools/mine_marigold_sweethearts.gd. Every pair blooms together "
                   "from the opening in `proof`'s six shots; `openers` counts the 65 fan angles whose first shot "
                   "blooms a pair.",
           "boards": boards}
    OUT.write_text(json.dumps(doc, separators=(",", ":")))
    print(f"{len(boards)} gardens -> {OUT.relative_to(ROOT)} ({OUT.stat().st_size // 1024} KB)")


if __name__ == "__main__":
    main()
