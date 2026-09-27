#!/usr/bin/env python3
"""Merge tools/mine_slider.gd's outputs into content/slider.json.

    python3 tools/merge_slider.py /tmp/slider_mine/*.json

A position is kept in one band only (the first that has it), each band is
thinned to at most CAP entries by a fixed shuffle, and the file is written in
a stable order so a re-merge of the same candidates changes nothing.
"""
import json, pathlib, random, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
CAP = [300, 300, 300, 400]

def main() -> None:
    bands = [{} for _ in range(4)]
    for path in sys.argv[1:]:
        doc = json.loads(pathlib.Path(path).read_text())
        for b, entries in enumerate(doc["bands"]):
            for e in entries:
                bands[b][e["b"]] = e
    seen = set()
    out = []
    rng = random.Random(20260926)
    for b in range(4):
        keep = [e for k, e in sorted(bands[b].items()) if k not in seen]
        rng.shuffle(keep)
        keep = sorted(keep[:CAP[b]], key=lambda e: (e["p"], e["b"]))
        seen.update(e["b"] for e in keep)
        out.append([{"b": e["b"], "p": e["p"]} for e in keep])
        pars = [e["p"] for e in keep]
        sizes = [e["n"] for e in keep]
        print(f"band {b}: {len(keep)} trays, shortest {min(pars)}-{max(pars)}, graphs up to {max(sizes)} positions")
    doc = {
        "version": 1,
        "note": "Super Slider's trays, mined by tools/mine_slider.gd and merged by tools/merge_slider.py. "
                "b: twenty cell codes in reading order (puzzles/slider_gen.gd); p: the shortest way out, in moves.",
        "bands": out,
    }
    (ROOT / "content/slider.json").write_text(json.dumps(doc, separators=(",", ":")) + "\n")

if __name__ == "__main__":
    main()
