#!/usr/bin/env python3
"""Hidden Word's Insane bank: the words Snail Mail makes hardest.

Not a GDScript ladder like the others in this folder (README.md): a word
board has no generator to mine, only a list to grade, and grading 968 words
against 968 words is a job for a few minutes of Python, not a phone.

Snail Mail (spec 2026-09-30-hidden-word-polish-design.md, section 2): a
row's colours arrive one row late, so every guess is made without the row
just before it. The grader plays every answer with a solver that knows the
**answer list** -- far more than a player knows -- picks two fixed openers
(the best-spread word, then the best one sharing no letter with it), and
from then on guesses the candidate that splits the words still possible
from the rows delivered so far the most. A word it needs five or more rows
for (or misses in six) goes in the bank; the rung is those rows, 7 a miss.

Run from the repo root:  python3 tools/insane/hiddenword_ladder.py [en pt es]
Writes content/insane/hiddenword.json, .pt.json and .es.json.
"""

import json
import math
import pathlib
import sys
import unicodedata
from collections import Counter

ROOT = pathlib.Path(__file__).resolve().parents[2]
ROWS = 6
LAG = 1
KEEP = 5
POOL = 80


def fold(word: str, lang: str) -> str:
    """Locale.fold(): the word as the keyboard types it (CORAÇÃO is CORACAO)."""
    keep = "abcdefghijklmnopqrstuvwxyz" + ("ñ" if lang == "es" else "")
    out = ""
    for ch in word.lower():
        out += ch if ch in keep else unicodedata.normalize("NFD", ch)[0]
    return out


def mark(guess: str, word: str) -> tuple:
    """hidden_word_state.gd's two-pass rule: greens first, then ambers off a tally."""
    out = [2] * 5
    tally = Counter()
    for i in range(5):
        if guess[i] == word[i]:
            out[i] = 0
        else:
            tally[word[i]] += 1
    for i in range(5):
        if out[i] == 0:
            continue
        if tally[guess[i]] > 0:
            out[i] = 1
            tally[guess[i]] -= 1
    return tuple(out)


def spread(guess: str, words: list) -> float:
    n = len(words)
    counts = Counter(mark(guess, w) for w in words)
    return -sum(v / n * math.log(v / n) for v in counts.values())


def grade_all(words: list) -> dict:
    first = max(words[:400], key=lambda g: spread(g, words))
    apart = [w for w in words if not set(w) & set(first)] or words
    second = max(apart, key=lambda g: spread(g, words))

    def play(answer: str) -> int:
        seen = []
        guesses = []
        for t in range(ROWS):
            delivered = seen[:max(0, len(guesses) - LAG)]
            cands = [w for w in words if w not in guesses
                     and all(mark(g, w) == m for g, m in delivered)]
            if t == 0:
                g = first
            elif t == 1:
                g = second if second in cands else cands[0]
            elif len(cands) <= 2:
                g = cands[0]
            else:
                g = max(cands[:POOL], key=lambda x: spread(x, cands))
            guesses.append(g)
            seen.append((g, mark(g, answer)))
            if g == answer:
                return t + 1
        return ROWS + 1

    return {w: play(w) for w in words}


def main() -> None:
    langs = sys.argv[1:] or ["en", "pt", "es"]
    for lang in langs:
        src = ROOT / ("content/hidden_word.json" if lang == "en" else f"content/hidden_word.{lang}.json")
        written = json.loads(src.read_text())["answers"]
        folded = [fold(w, lang) for w in written]
        grades = grade_all(folded)
        boards = []
        for w, f in zip(written, folded):
            rung = grades[f]
            if rung >= KEEP:
                boards.append({"answer": w, "grade": {"rung": rung, "work": rung, "unique": True}})
        out = ROOT / ("content/insane/hiddenword.json" if lang == "en" else f"content/insane/hiddenword.{lang}.json")
        doc = {
            "version": 1,
            "note": "Hidden Word's Snail Mail bank: answers an answer-list-aware solver needs "
                    "%d+ rows for when each row's colours arrive a row late "
                    "(tools/insane/hiddenword_ladder.py). rung = rows, %d = not in six." % (KEEP, ROWS + 1),
            "boards": boards,
        }
        out.write_text(json.dumps(doc, ensure_ascii=False, indent="\t") + "\n")
        counts = Counter(grades.values())
        print(f"{lang}: {len(boards)} of {len(written)} kept -> {out.relative_to(ROOT)}  {sorted(counts.items())}")


if __name__ == "__main__":
    main()
