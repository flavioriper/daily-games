#!/usr/bin/env python3
"""Stepping Stones' crossings (spec docs/superpowers/specs/2026-11-04-stepping-stones-design.md).

    python3 -m venv /tmp/hv && /tmp/hv/bin/pip install wordfreq spylls
    /tmp/hv/bin/python tools/build_stones.py <dicts dir> [cache dir] [langs...]

<dicts dir> is Honeycomb's (tools/build_honeycomb.py): the LibreOffice
Hunspell dictionaries and the LDNOOBW lists as rude_<lang>.txt, used to prune
at build time only. What ships is wordfreq's (CC-BY-SA 4.0, attributed in each
file's note). [cache dir] is Biscuit Tin's (tools/build_biscuit.py): its
pruned word list per language, four to sixteen letters, so the Hunspell pass
is shared.

A crossing is two common words of the band's length, one on each bank of a
brook; a stone is any word one letter from the one before. The fewest stones
between the banks are found by a search over the fair words (common enough to
ask for), never assumed, and a deal is kept only when at least two shortest
ways cross.

Writes, per language:
- content/stones_<n>[.lang].json, n 4 and 5: {"version", "note", "fair",
  "more", "shown"}: `fair` the words the bulb and the par walk on, commonest
  first; `more` the rarer words a player may still lay; `shown` a word's
  accents where it has them. The board judges a typed stone by these.
- content/insane/stones_<band>[.lang].json (easy, medium, hard; Insane is the
  plain name), each {"version", "note", "boards": [{"from", "to", "par",
  "given", "route", "ways"}]}: `par` the fewest stones (words between the
  banks), `given` Easy's middle stone (else ""), `route` one shortest way
  through the commonest words (the day document's solution), `ways` how many
  shortest ways there are (capped). The game reads them through InsaneBank.

Bands (word length, par stones, rule):
  easy    four letters, 3 stones, the middle one given
  medium  four letters, 4..5 stones
  hard    five letters, 4..5 stones
  insane  five letters, 4..6 stones, Slippery: a stone may also be the one
          before with two letters side by side swapped; the par counts
          swaps, and a shortest way takes one (or the plain way is longer)
"""
import json, random, sys
from collections import deque, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
from build_honeycomb import rude  # noqa: E402
from build_biscuit import lexicon, proper  # noqa: E402

PER_BANK = 365
FAIR_Z = 2.9
# a bank's word: common enough to stand on a bank
END_Z = 3.5
# band: (bank, length, par stones lo, hi, given, swaps)
BANDS = [
    ("stones_easy", 4, 3, 3, True, False),
    ("stones_medium", 4, 4, 5, False, False),
    ("stones_hard", 5, 4, 5, False, False),
    ("stones", 5, 4, 6, False, True),
]
# Words a player may still lay but the bulb never offers and no bank or par
# walks on: crude, not rude enough for the lists (a scan of the first build,
# 2026-11-04, found FARTS on an English route).
CRUDE = {
    "en": {"fart", "farts", "poop", "poops", "turd", "turds", "puke", "pukes", "vomit", "pimp", "pimps",
           "arse", "arses", "bums", "hoes", "booty", "thong", "drug", "drugs", "gays", "pees", "piss", "boozy"},
    "pt": {"xixi", "mijo", "mija", "mijar", "mijou", "caga", "cagar", "cagou", "peido", "peida", "bosta",
           "cocos", "drogas", "porre"},
    "es": {"mear", "meado", "caga", "cagar", "cagan", "pito", "pitos", "paja", "pajas", "mamar", "pedos",
           "drogas"},
}
# How often one word may stand on a bank in a bank of crossings.
END_CAP = 2
WAYS_CAP = 50


def graph(words, swaps):
    b = defaultdict(list)
    for w in words:
        for i in range(len(w)):
            b[w[:i] + "_" + w[i + 1:]].append(w)
    g = {w: set() for w in words}
    for ws in b.values():
        for a in ws:
            for c in ws:
                if a != c:
                    g[a].add(c)
    if swaps:
        have = set(words)
        for w in words:
            for i in range(len(w) - 1):
                s = w[:i] + w[i + 1] + w[i] + w[i + 2:]
                if s != w and s in have:
                    g[w].add(s)
                    g[s].add(w)
    return g


def bfs(g, s):
    d = {s: 0}
    q = deque([s])
    while q:
        x = q.popleft()
        for y in g[x]:
            if y not in d:
                d[y] = d[x] + 1
                q.append(y)
    return d


def ways(g, da, db, a, steps):
    """Shortest ways from a to b (`steps` edges): counted (capped), and one
    through the commonest words (rank: lower is commoner)."""
    count = defaultdict(int)
    count[a] = 1
    layer = [a]
    for k in range(1, steps + 1):
        nxt = set()
        for x in layer:
            for y in g[x]:
                if da.get(y) == k and db.get(y) == steps - k:
                    count[y] = min(WAYS_CAP, count[y] + count[x])
                    nxt.add(y)
        layer = list(nxt)
    return count


def is_swap(x, y):
    d = [i for i in range(len(x)) if x[i] != y[i]]
    return len(d) == 2 and d[1] == d[0] + 1 and x[d[0]] == y[d[1]] and x[d[1]] == y[d[0]]


def swap_on_way(g, da, db, steps):
    """Whether some shortest way takes a swap."""
    for x, k in da.items():
        if k >= steps or db.get(x, 99) != steps - k:
            continue
        for y in g[x]:
            if da.get(y) == k + 1 and db.get(y) == steps - k - 1 and is_swap(x, y):
                return True
    return False


def build(dicts, lang, cache):
    lex = proper(lexicon(dicts, lang, cache), lang, rude(dicts, lang))
    suffix = "" if lang == "en" else "." + lang
    for n in (4, 5):
        words = sorted((w for w in lex if len(w) == n), key=lambda w: (-lex[w][0], w))
        fair = [w for w in words if lex[w][0] >= FAIR_Z and w not in CRUDE[lang]]
        more = sorted(w for w in words if lex[w][0] < FAIR_Z or w in CRUDE[lang])
        shown = {w: lex[w][1].lower() for w in words if lex[w][1].lower() != w}
        doc = {"version": 1,
               "note": ("Stepping Stones' words, built by tools/build_stones.py from wordfreq's words "
                        "(Robyn Speer, CC-BY-SA 4.0, https://github.com/rspeer/wordfreq), pruned at "
                        "build time by the LibreOffice Hunspell dictionaries and the LDNOOBW list. "
                        "`fair` commonest first (the bulb and the par walk on them), `more` rarer "
                        "words a stone may still be, `shown` accents."),
               "fair": fair, "more": more, "shown": shown}
        (ROOT / f"content/stones_{n}{suffix}.json").write_text(json.dumps(doc, ensure_ascii=False, separators=(",", ":")))
        print(f"{lang} {n}: fair {len(fair)} more {len(more)}")
    for band, (bank, n, lo, hi, given, swaps) in enumerate(BANDS):
        rng = random.Random(f"stones|{lang}|{bank}")
        fair = [w for w in lex if len(w) == n and lex[w][0] >= FAIR_Z and w not in CRUDE[lang]]
        rank = {w: i for i, w in enumerate(sorted(fair, key=lambda w: (-lex[w][0], w)))}
        g = graph(fair, swaps)
        plain = graph(fair, False) if swaps else g
        ends = sorted(w for w in fair if lex[w][0] >= END_Z)
        used = defaultdict(int)
        boards = []
        tries = 0
        while len(boards) < PER_BANK and tries < 200000:
            tries += 1
            a = rng.choice(ends)
            if used[a] >= END_CAP:
                continue
            da = bfs(g, a)
            far = [w for w in ends if lo + 1 <= da.get(w, 99) <= hi + 1 and used[w] < END_CAP]
            if not far:
                continue
            b = rng.choice(far)
            steps = da[b]
            # every letter changes on the way (Easy: each step a letter right)
            if sum(x != y for x, y in zip(a, b)) < (n if band < 2 else n - 1):
                continue
            db = bfs(g, b)
            if swaps and bfs(plain, a).get(b, 99) <= steps and not swap_on_way(g, da, db, steps):
                continue
            count = ways(g, da, db, a, steps)
            if count[b] < 2:
                continue
            # one shortest way through the commonest words: walk back from b
            route = [b]
            while route[-1] != a:
                x = route[-1]
                back = [y for y in g[x] if da.get(y) == da[x] - 1 and db.get(y) == db[x] + 1 and count[y] > 0]
                route.append(min(back, key=lambda y: rank[y]))
            route.reverse()
            mid = ""
            if given:
                mid = route[len(route) // 2]
            if any(lex[w][0] < FAIR_Z for w in route):
                continue
            used[a] += 1
            used[b] += 1
            boards.append({"from": a, "to": b, "par": steps - 1, "given": mid,
                           "route": route[1:-1], "ways": count[b]})
        doc = {"version": 1,
               "note": ("Stepping Stones' crossings, built by tools/build_stones.py from wordfreq's "
                        "words (Robyn Speer, CC-BY-SA 4.0, https://github.com/rspeer/wordfreq). "
                        "`par` the fewest stones between `from` and `to` over the fair words, `given` "
                        "Easy's middle stone, `route` one shortest way, `ways` how many (capped)."),
               "boards": boards}
        (ROOT / f"content/insane/{bank}{suffix}.json").write_text(json.dumps(doc, ensure_ascii=False, separators=(",", ":")))
        pars = defaultdict(int)
        for x in boards:
            pars[x["par"]] += 1
        print(f"{lang} {bank}: {len(boards)} in {tries} tries; ends {len(ends)}; par {dict(pars)}; "
              f"ways avg {sum(x['ways'] for x in boards) / max(1, len(boards)):.1f}")


if __name__ == "__main__":
    dicts = sys.argv[1]
    cache = sys.argv[2] if len(sys.argv) > 2 else None
    for lang in (sys.argv[3:] or ["en", "pt", "es"]):
        build(dicts, lang, cache)
