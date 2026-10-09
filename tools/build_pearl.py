#!/usr/bin/env python3
"""Pearl Dive's bank: tools/pearl/level0..2.json -> content/pearl.json.

The three level files are the source (everyday, medium, hard; the contract of
a prompt is tools/pearl/CONTRACT.md), written by the day's own writer and
reviewer (`node lib/cli.js bank pearl ...` in server/functions) and mended by
hand. This checks every prompt against the contract and writes the one file
the game ships and the functions' build copies beside
server/functions/src/pearl.ts. Edit the level files, not the output.

    python3 tools/build_pearl.py
"""
import json
import pathlib
import sys
import unicodedata

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "tools" / "pearl"
OUT = ROOT / "content" / "pearl.json"
LANGS = ("en", "pt", "es")
PREFIX = "emh"
ASK_MAX, NAME_MAX, FORM_MIN, FORM_MAX, ANSWERS_MIN = 64, 26, 2, 22, 14
PEARL = 4
# A band takes its prompts from the head of a level's order and One Breath
# from its tail (puzzles/pearl_state.gd): a level shorter than this would
# ask one prompt twice in a day.
LEVEL_MIN = (8, 9, 9)

FOLD = {
    "á": "a", "à": "a", "â": "a", "ã": "a", "ä": "a", "å": "a",
    "é": "e", "è": "e", "ê": "e", "ë": "e",
    "í": "i", "ì": "i", "î": "i", "ï": "i",
    "ó": "o", "ò": "o", "ô": "o", "õ": "o", "ö": "o", "ø": "o",
    "ú": "u", "ù": "u", "û": "u", "ü": "u",
    "ç": "c", "ñ": "n", "ý": "y", "ß": "ss", "æ": "ae", "œ": "oe",
}


def norm(s: str) -> str:
    """As puzzles/pearl_state.gd folds a name: what the keyboard can type."""
    out = []
    for ch in unicodedata.normalize("NFC", s).lower():
        if "a" <= ch <= "z":
            out.append(ch)
        elif ch in FOLD:
            out.append(FOLD[ch])
    return "".join(out)


def problems(level: int, p: dict) -> list[str]:
    out = []
    pid = str(p.get("id", "?"))
    if not (len(pid) == 4 and pid[0] == PREFIX[level] and pid[1:].isdigit()):
        out.append("bad id")
    if p.get("level") != level:
        out.append(f"level is {p.get('level')!r}")
    for lang in LANGS:
        ask = (p.get(lang) or {}).get("ask") if isinstance(p.get(lang), dict) else None
        if not (isinstance(ask, str) and ask.strip()):
            out.append(f"{lang}: no ask")
        elif len(ask) > ASK_MAX:
            out.append(f"{lang}: ask over {ASK_MAX} ({len(ask)})")
    answers = p.get("answers")
    if not isinstance(answers, list):
        return out + ["no answers"]
    if len(answers) < ANSWERS_MIN:
        out.append(f"only {len(answers)} answers")
    rungs = [0] * (PEARL + 1)
    seen = {lang: {} for lang in LANGS}
    for at, a in enumerate(answers):
        t = a.get("t") if isinstance(a, dict) else None
        if not (isinstance(t, int) and 0 <= t <= PEARL):
            out.append(f"answer {at}: bad tier {t!r}")
            continue
        rungs[t] += 1
        for lang in LANGS:
            forms = a.get(lang)
            if not (isinstance(forms, list) and forms and all(isinstance(f, str) for f in forms)):
                out.append(f"answer {at}: no {lang} name")
                continue
            if len(forms[0]) > NAME_MAX:
                out.append(f"{lang}: name over {NAME_MAX}: {forms[0]!r}")
            for f in forms:
                n = norm(f)
                if any(ch.isdigit() for ch in f):
                    out.append(f"{lang}: a numeral in {f!r}")
                if unicodedata.normalize("NFC", f) != f:
                    out.append(f"{lang}: {f!r} is not composed (NFC)")
                if not FORM_MIN <= len(n) <= FORM_MAX:
                    out.append(f"{lang}: {f!r} folds to {len(n)} letters")
                if n in seen[lang]:
                    out.append(f"{lang}: {f!r} is also {seen[lang][n]!r}")
                seen[lang][n] = forms[0]
    if rungs[PEARL] != 1:
        out.append(f"{rungs[PEARL]} Pearls")
    for t in range(PEARL):
        if rungs[t] == 0:
            out.append(f"nothing on tier {t}")
    return out


def main() -> int:
    levels, bad, seen_ids, seen_asks = [], 0, set(), {}
    for level in range(3):
        items = json.loads((SRC / f"level{level}.json").read_text(encoding="utf-8"))
        for p in items:
            found = problems(level, p)
            pid = p.get("id")
            if pid in seen_ids:
                found.append("id used twice")
            seen_ids.add(pid)
            asked = norm(str((p.get("en") or {}).get("ask", "")))
            if asked in seen_asks:
                found.append(f"asked already as {seen_asks[asked]}")
            seen_asks[asked] = pid
            for f in found:
                print(f"level{level} {pid}: {f}")
            bad += len(found)
        if len(items) < LEVEL_MIN[level]:
            print(f"level{level}: only {len(items)} prompts")
            bad += 1
        levels.append(items)
    if bad:
        print(f"{bad} problems; nothing written")
        return 1
    OUT.write_text(json.dumps({"v": 1, "levels": levels}, ensure_ascii=False,
                              separators=(",", ":")) + "\n", encoding="utf-8")
    answers = sum(len(p["answers"]) for lv in levels for p in lv)
    print(f"{OUT.relative_to(ROOT)}: {' + '.join(str(len(lv)) for lv in levels)} prompts, "
          f"{answers} answers, {OUT.stat().st_size // 1024} KB")
    return 0


if __name__ == "__main__":
    sys.exit(main())
