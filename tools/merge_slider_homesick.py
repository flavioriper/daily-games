#!/usr/bin/env python3
"""Merge tools/mine_slider_homesick.gd's outputs into content/insane/slider.json.

    python3 tools/merge_slider_homesick.py /tmp/slider_home/*.json

Dedups by tray, keeps at most PER_GRAPH trays from any one graph (a graph is
told by its size and doom share, which the miner writes) so a day's Homesick
does not keep dealing the same family, thins to CAP by a fixed shuffle and
writes in a stable order, so a re-merge of the same candidates changes
nothing.
"""
import json, pathlib, random, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
CAP = 200
PER_GRAPH = 24


def main() -> None:
    trays = {}
    for path in sys.argv[1:]:
        for e in json.loads(pathlib.Path(path).read_text())["boards"]:
            trays[e["b"]] = e
    rng = random.Random(20261001)
    graphs = {}
    for b, e in sorted(trays.items()):
        graphs.setdefault((e["n"], e["doom"]), []).append(e)
    keep = []
    for g in sorted(graphs):
        pool = graphs[g]
        rng.shuffle(pool)
        # the deepest of each family first
        pool.sort(key=lambda e: -e["p"])
        keep += pool[:PER_GRAPH]
    rng.shuffle(keep)
    keep = sorted(keep[:CAP], key=lambda e: (e["p"], e["b"]))
    pars = [e["p"] for e in keep]
    print(f"{len(trays)} candidates from {len(graphs)} graphs; kept {len(keep)}, "
          f"shortest {min(pars)}-{max(pars)}, graphs up to {max(e['n'] for e in keep)} positions")
    doc = {
        "version": 1,
        "note": "Super Slider's Insane trays, Homesick (the big block never steps back up), mined by "
                "tools/mine_slider_homesick.gd and merged by tools/merge_slider_homesick.py. "
                "b: twenty cell codes in reading order (puzzles/slider_gen.gd); p: the shortest way home, "
                "in moves, with the big block never stepping up; n: positions the tray can reach; "
                "doom: the share of the big block's moves in its graph that strand it.",
        "boards": [{"b": e["b"], "p": e["p"], "n": e["n"], "doom": e["doom"]} for e in keep],
    }
    (ROOT / "content/insane/slider.json").write_text(json.dumps(doc, separators=(",", ":")) + "\n")


if __name__ == "__main__":
    main()
