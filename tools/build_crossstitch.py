#!/usr/bin/env python3
"""Cross Stitch's samplers (spec docs/superpowers/specs/2026-11-04-cross-stitch-design.md).

    python3 tools/build_crossstitch.py

No downloads: every word comes from Hidden Word's answers
(content/hidden_word[.lang].json), folded the way the keyboard folds them
(accents off, but ñ kept in Spanish), so a sampler only ever holds words a
player of that language knows.

A sampler is a 5 by 5 linen with four holes: three words across (rows 0, 2,
4) and three down (columns 0, 2, 4), agreeing on the nine crossings, six
different words. Its 21 letters are then shuffled, and the fewest swaps
that put them back (`min`) is computed, never assumed: equal letters can
make a shuffle shorter than the swaps that made it, so the builder solves
the swap count exactly (misplaced letters less the most cycles their
letter graph splits into) and keeps only shuffles whose fewest is the
band's.

Writes four banks per language, content/insane/crossstitch_<band>[.lang].json
(easy, medium, hard; Insane is the plain name), each
{"version": 1, "note", "boards": [{"words", "shown", "start", "min"}]}:
`words` the six folded words (across 0/2/4, then down 0/2/4), `shown` the
same six as written, with accents, and `start` the 25 cells as dealt
(row by row, "." the holes). The game reads them through InsaneBank.

Bands:
  easy    common words (Hidden Word's easy and medium); one across and
          one down word dealt whole (stitched), MIN 6 swaps
  medium  common words, MIN 8
  hard    every answer, MIN 10
  insane  every answer, MIN 10 (the board hides the amber thread)
"""
import json, random, sys, unicodedata
from collections import defaultdict
from functools import lru_cache
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LANGS = {"en": "", "pt": ".pt", "es": ".es"}
PER_BANK = 365
# band: (bank file, which answers (index into Hidden Word's bands; None = all), fewest swaps, words given)
BANDS = [
    ("crossstitch_easy", 1, 6, True),
    ("crossstitch_medium", 1, 8, False),
    ("crossstitch_hard", None, 10, False),
    ("crossstitch", None, 10, False),
]
# How often one word may stand in a bank's samplers.
WORD_CAP = 14


def fold(word: str, lang: str) -> str:
    out = ""
    for ch in word.lower():
        if lang == "es" and ch == "ñ":
            out += ch
            continue
        out += "".join(c for c in unicodedata.normalize("NFD", ch) if unicodedata.category(c) != "Mn")
    return out


def cells_of(slot: int) -> list:
    """The five cells of word `slot`: 0..2 across rows 0/2/4, 3..5 down columns 0/2/4."""
    if slot < 3:
        r = slot * 2
        return [r * 5 + c for c in range(5)]
    c = (slot - 3) * 2
    return [r * 5 + c for r in range(5)]


HOLES = {6, 8, 16, 18}
LETTERS = [i for i in range(25) if i not in HOLES]


def solution_grid(words: list) -> list:
    g = ["."] * 25
    for s, w in enumerate(words):
        for k, i in enumerate(cells_of(s)):
            assert g[i] in (".", w[k]), (words, s)
            g[i] = w[k]
    return g


def fewest_swaps(start: list, goal: list) -> int:
    """The fewest swaps of two cells that turn `start` into `goal`: the
    misplaced cells less the most cycles their letter graph splits into."""
    edges = defaultdict(int)
    m = 0
    for i in LETTERS:
        if start[i] != goal[i]:
            edges[(start[i], goal[i])] += 1
            m += 1
    if m == 0:
        return 0
    keys = sorted(edges)
    return m - _most_cycles(tuple(edges[k] for k in keys), tuple(keys))


@lru_cache(maxsize=None)
def _most_cycles(counts: tuple, keys: tuple) -> int:
    # every edge left lies on some cycle (the graph is balanced); take the
    # first edge left and try every simple cycle through it
    first = next((i for i, n in enumerate(counts) if n > 0), -1)
    if first < 0:
        return 0
    a, b = keys[first]
    out_of = defaultdict(list)
    for i, (x, y) in enumerate(keys):
        if counts[i] > 0:
            out_of[x].append(i)
    best = 0
    seen = set()

    def walk(at, used, path):
        nonlocal best
        if at == a:
            c = list(counts)
            for e in path:
                c[e] -= 1
            best = max(best, 1 + _most_cycles(tuple(c), keys))
            return
        for e in out_of[at]:
            nxt = keys[e][1]
            if nxt in used and nxt != a:
                continue
            if counts[e] - path.count(e) <= 0:
                continue
            walk(nxt, used | {nxt}, path + [e])

    walk(b, {a, b}, [first])
    return best


def samplers(rng, pool, idx, first, uses):
    """Every first word in a shuffled order, each giving the first sampler
    (in a shuffled order of its down words) whose words are not used up:
    a sweep reaches every corner of the list, where a random draw keeps
    finding the same few vowel-rich words."""
    order = list(pool)
    rng.shuffle(order)
    for a0 in order:
        if uses[a0] >= WORD_CAP:
            continue
        d0s, d2s, d4s = first.get(a0[0], []), first.get(a0[2], []), first.get(a0[4], [])
        if not (d0s and d2s and d4s):
            continue
        d0s, d2s, d4s = rng.sample(d0s, len(d0s)), rng.sample(d2s, len(d2s)), rng.sample(d4s, len(d4s))
        found = None
        for d0 in d0s:
            if found or uses[d0] >= WORD_CAP:
                continue
            for d2 in d2s:
                if found or uses[d2] >= WORD_CAP:
                    continue
                for d4 in d4s:
                    if uses[d4] >= WORD_CAP:
                        continue
                    a2s = [w for w in idx.get((d0[2], d2[2], d4[2]), []) if uses[w] < WORD_CAP]
                    a4s = [w for w in idx.get((d0[4], d2[4], d4[4]), []) if uses[w] < WORD_CAP]
                    if not a2s or not a4s:
                        continue
                    a2, a4 = rng.choice(a2s), rng.choice(a4s)
                    words = [a0, a2, a4, d0, d2, d4]
                    if len(set(words)) == 6:
                        found = words
                        break
        if found:
            yield found


def shuffle(rng, goal, fewest, given):
    """A shuffle of the sampler's letters whose fewest swaps is `fewest`,
    the cells of the given words left where they are."""
    fixed = set()
    for s in given:
        fixed |= set(cells_of(s))
    free = [i for i in LETTERS if i not in fixed]
    for _ in range(20000):
        # how many letters move and in how many rings: a ring of n letters
        # takes n - 1 swaps, so moved - rings = fewest
        rings = rng.randint(2, max(2, min(fewest, len(free) - fewest)))
        moved = fewest + rings
        if moved > len(free):
            continue
        cells = rng.sample(free, moved)
        # cut the moved cells into `rings` rings of two or more
        cuts = sorted(rng.sample(range(1, moved), rings - 1)) if rings > 1 else []
        sizes = [b - a for a, b in zip([0] + cuts, cuts + [moved])]
        if min(sizes) < 2:
            continue
        start = list(goal)
        at = 0
        for n in sizes:
            ring = cells[at:at + n]
            for k in range(n):
                start[ring[(k + 1) % n]] = goal[ring[k]]
            at += n
        # a moved letter that lands on its own letter would sit stitched
        if any(start[i] == goal[i] for i in cells):
            continue
        if fewest_swaps(start, goal) != fewest:
            continue
        return start
    return None


def build(lang: str) -> None:
    src = json.loads((ROOT / f"content/hidden_word{LANGS[lang]}.json").read_text())
    answers = src["answers"]
    bands = src["bands"]
    for name, cut, fewest, given in BANDS:
        rng = random.Random(f"crossstitch|{lang}|{name}")
        chosen = answers[: bands[cut]] if cut is not None else answers
        shown = {}
        for w in chosen:
            f = fold(w, lang)
            if len(f) == 5 and f.isalpha():
                shown.setdefault(f, w.lower())
        pool = sorted(shown)
        idx = defaultdict(list)
        first = defaultdict(list)
        for w in pool:
            idx[(w[0], w[2], w[4])].append(w)
            first[w[0]].append(w)
        uses = defaultdict(int)
        boards = []
        seen = set()
        for sweep in range(12):
            for words in samplers(rng, pool, idx, first, uses):
                if len(boards) >= PER_BANK:
                    break
                key = tuple(sorted(words))
                if key in seen or any(uses[w] >= WORD_CAP for w in words):
                    continue
                goal = solution_grid(words)
                giv = [rng.randrange(3), 3 + rng.randrange(3)] if given else []
                start = shuffle(rng, goal, fewest, giv)
                if start is None:
                    continue
                seen.add(key)
                for w in words:
                    uses[w] += 1
                boards.append({
                    "words": words,
                    "shown": [shown[w] for w in words],
                    "start": "".join(start),
                    "min": fewest,
                })
            if len(boards) >= PER_BANK:
                break
        rng.shuffle(boards)
        if len(boards) < PER_BANK:
            print(f"{lang} {name}: only {len(boards)}", file=sys.stderr)
        note = ("Cross Stitch's samplers for one band, built by tools/build_crossstitch.py "
                "from Hidden Word's answers (themselves drawn from wordfreq, Robyn Speer et al., "
                "CC-BY-SA 4.0). `words`: three across (rows 0/2/4) then three down (columns 0/2/4), "
                "folded; `shown`: the same as written; `start`: the 25 cells as dealt, row by row, "
                "'.' a hole; `min`: the fewest swaps that stitch it, solved exactly.")
        out = ROOT / f"content/insane/{name}{LANGS[lang]}.json"
        out.write_text(json.dumps({"version": 1, "note": note, "boards": boards}, ensure_ascii=False, indent=0) + "\n")
        print(f"{lang} {name}: {len(boards)} samplers, {len(pool)} words -> {out.relative_to(ROOT)}")


if __name__ == "__main__":
    for lang in (sys.argv[1:] or list(LANGS)):
        build(lang)
