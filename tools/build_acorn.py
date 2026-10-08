#!/usr/bin/env python3
"""Golden Acorn's bank: tools/acorn/tier0..3.json -> content/acorn.json.

The four tier files are the source (easy, medium, hard, expert; the contract
of a question is tools/acorn/CONTRACT.md). This checks every question against
the contract and writes the one file the game ships and the functions' build
copies beside server/functions/src/acorn.ts. Edit the tier files, not the
output.

    python3 tools/build_acorn.py
"""
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "tools" / "acorn"
OUT = ROOT / "content" / "acorn.json"
LANGS = ("en", "pt", "es")
CATS = {"nature", "science", "geography", "history", "arts", "food", "sports",
        "words", "everyday"}
PREFIX = "emhx"
Q_MAX, ANSWER_MAX, WHY_MAX = 110, 26, 110
# The Climb takes its last questions from a tier's tail and a band its first
# from the head (puzzles/acorn_state.gd): a tier shorter than this would ask
# one question twice in a day.
TIER_MIN = 10


def problems(tier: int, q: dict) -> list[str]:
    out = []
    qid = str(q.get("id", "?"))
    if not (len(qid) == 4 and qid[0] == PREFIX[tier] and qid[1:].isdigit()):
        out.append("bad id")
    if q.get("cat") not in CATS:
        out.append(f"bad cat {q.get('cat')!r}")
    for lang in LANGS:
        w = q.get(lang)
        if not isinstance(w, dict):
            out.append(f"{lang}: missing")
            continue
        wrong = w.get("wrong")
        if not (isinstance(wrong, list) and len(wrong) == 3):
            out.append(f"{lang}: wrong is not three")
            continue
        answers = [w.get("right"), *wrong]
        if not all(isinstance(a, str) and a.strip() for a in answers):
            out.append(f"{lang}: an empty answer")
            continue
        if len({a.strip().lower() for a in answers}) != 4:
            out.append(f"{lang}: two answers alike")
        for a in answers:
            if len(a) > ANSWER_MAX:
                out.append(f"{lang}: answer over {ANSWER_MAX}: {a!r}")
        for key, most in (("q", Q_MAX), ("why", WHY_MAX)):
            text = w.get(key)
            if not (isinstance(text, str) and text.strip()):
                out.append(f"{lang}: no {key}")
            elif len(text) > most:
                out.append(f"{lang}: {key} over {most} ({len(text)})")
    return out


def main() -> int:
    tiers, bad, seen_ids, seen_q = [], 0, set(), {}
    for tier in range(4):
        items = json.loads((SRC / f"tier{tier}.json").read_text(encoding="utf-8"))
        for q in items:
            found = problems(tier, q)
            qid = q.get("id")
            if qid in seen_ids:
                found.append("id used twice")
            seen_ids.add(qid)
            asked = str(q.get("en", {}).get("q", "")).strip().lower()
            if asked in seen_q:
                found.append(f"asked already as {seen_q[asked]}")
            seen_q[asked] = qid
            for f in found:
                print(f"tier{tier} {qid}: {f}")
            bad += len(found)
        if len(items) < TIER_MIN:
            print(f"tier{tier}: only {len(items)} questions")
            bad += 1
        tiers.append(items)
    if bad:
        print(f"{bad} problems; nothing written")
        return 1
    OUT.write_text(json.dumps({"v": 1, "tiers": tiers}, ensure_ascii=False,
                              separators=(",", ":")) + "\n", encoding="utf-8")
    print(f"{OUT.relative_to(ROOT)}: {' + '.join(str(len(t)) for t in tiers)} questions")
    return 0


if __name__ == "__main__":
    sys.exit(main())
