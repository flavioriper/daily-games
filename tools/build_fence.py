#!/usr/bin/env python3
"""Garden Fence's fences (spec docs/superpowers/specs/2026-11-04-garden-fence-design.md).

    python3 -m venv /tmp/hv && /tmp/hv/bin/pip install wordfreq spylls
    /tmp/hv/bin/python tools/build_fence.py <dicts dir> <cache dir> [langs...]

<dicts dir> is Honeycomb's (tools/build_honeycomb.py): the LibreOffice
Hunspell dictionaries and the LDNOOBW lists as rude_<lang>.txt, used to prune
at build time only. What ships is wordfreq's (CC-BY-SA 4.0, attributed in each
bank's note). <cache dir> holds Biscuit Tin's pruned word list per language
(tools/build_biscuit.py, four to sixteen letters); the three-letter words are
looked up here and cached beside it (fence_lex3_<lang>.json).

A fence is a ring of posts round a garden bed, three a side, a letter on
each post. Twine is strung post to post to spell words: never two letters in
a row from one side, each word starting on the post the one before ended on,
three letters at least. Every post used is the solve; letters may be used
again.

A deal starts from a chain of common words (two, three on the pentagon)
that between them use exactly the fence's letters, each word's last letter
the next one's first. The letters are shared out three a side so no two
letters side by side in the chain stand on one side. The par is the fewest
words that use every post over the fair words, proved by search: a deal is
kept only when no shorter chain than its seed does it.

Writes, per language:
- content/fence_words[.lang].json: {"version", "note", "fair", "more",
  "shown"}, every word three letters or more with no letter twice in a row,
  by first letter, space-separated: `fair` commonest first (the par, the
  bulb and the fewest-to-go walk on them), `more` the rarer words a fence
  still takes, `shown` a word's accents where it has them. The game filters
  it by the day's posts (a list per fence was 4-5 MB a band).
- content/insane/fence_<band>[.lang].json (easy, medium, hard; Insane is the
  plain name), each {"version", "note", "boards": [{"posts", "sides",
  "gate", "par", "route", "words", "fair"}]}: `posts` the letters side by
  side (three a side, clockwise from the top), `sides` how many, `gate`
  Insane's post the last word must end on (-1 elsewhere), `par` the fewest
  words, `route` one fewest chain through common words (the day document's
  solution), `words` and `fair` how many words the fence takes, all told
  and common. The game reads them through InsaneBank.

FENCE_N (fences a bank, 365) and FENCE_BANDS (band numbers, comma-separated)
in the environment cut a trial build short.

Bands (sides, seed words, rule):
  easy    a triangle, nine posts, par 2
  medium  a square, twelve posts, par 2
  hard    a pentagon, fifteen posts, par 3
  insane  a square, twelve posts, par 2, Gate: one post must be the
          last letter of the last word
"""
import json, os, random, sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
from build_honeycomb import LANGS, ALPHA, ROMAN, fold, rude, stems  # noqa: E402
from build_padlock import EXTRA_RUDE, RUDE_STEMS, NAMES  # noqa: E402
from build_biscuit import lexicon, proper  # noqa: E402

PER_BANK = int(os.environ.get("FENCE_N", "365"))
FAIR_Z = 2.9
CREDIT_Z = 1.8
# A seed word's zipf floor, by band.
SEED_Z = [3.4, 3.3, 3.2, 3.3]
# band: (bank, sides, seed words, gate)
BANDS = [
    ("fence_easy", 3, 2, False),
    ("fence_medium", 4, 2, False),
    ("fence_hard", 5, 3, False),
    ("fence", 4, 2, True),
]
# The fewest fair words a fence must take (so a player has room to try).
FEWEST_FAIR = [40, 60, 70, 60]
# How often one word may be a seed in a bank.
SEED_CAP = 2
# Words a player may still string but the bulb never offers and no route
# takes: crude, not rude enough for the lists (Stepping Stones' list).
CRUDE = {
    "en": {"fart", "farts", "poop", "poops", "turd", "turds", "puke", "pukes", "vomit", "pimp", "pimps",
           "arse", "arses", "bums", "hoes", "booty", "thong", "drug", "drugs", "gays", "pees", "piss", "boozy",
           "pee", "poo", "bum", "gay", "sex", "hoe", "tit", "fag", "nob", "wee", "jap", "kkk", "pot", "pus"},
    "pt": {"xixi", "mijo", "mija", "mijar", "mijou", "caga", "cagar", "cagou", "peido", "peida", "bosta",
           "cocos", "drogas", "porre", "cu", "coc", "cag", "pum", "xot", "bum", "gay", "sexo", "pau",
           "cocô", "coco", "bunda", "rabo", "pinto"},
    "es": {"mear", "meado", "caga", "cagar", "cagan", "pito", "pitos", "paja", "pajas", "mamar", "pedos",
           "drogas", "pis", "pedo", "caca", "culo", "gay", "sexo", "teta", "nabo", "rabo"},
}


def lexicon3(dicts, lang, cache):
    """Folded three-letter words: {folded: (zipf, written)}, rude words and
    names left out (Biscuit Tin's lexicon stops at four)."""
    p = Path(cache) / f"fence_lex3_{lang}.json"
    if p.exists():
        return {k: tuple(v) for k, v in json.loads(p.read_text()).items()}
    from spylls.hunspell import Dictionary
    import wordfreq
    hs = [Dictionary.from_files(str(Path(dicts) / d)) for d in LANGS[lang]]
    caps, low = stems(dicts, lang)
    bad = rude(dicts, lang)
    alpha = ALPHA[lang]
    words = {}
    for w in wordfreq.iter_wordlist(lang, "best"):
        z = wordfreq.zipf_frequency(w, lang)
        if z < CREDIT_Z:
            break
        if len(w) != 3 or not w.isalpha():
            continue
        f = fold(w, lang)
        if any(c not in alpha for c in f) or f in words:
            continue
        if f in bad or f in EXTRA_RUDE[lang] or f.startswith(RUDE_STEMS[lang]) or f in NAMES:
            continue
        if f in caps and f not in low:
            continue
        # three letters: only a word the dictionary has in lower case (no
        # abbreviations, no names), and never all one letter
        if f not in low or len(set(f)) == 1:
            continue
        if ROMAN.fullmatch(w) or not any(h.lookup(w) for h in hs):
            continue
        words[f] = (z, w)
    p.write_text(json.dumps(words, ensure_ascii=False))
    return words


def doubled(w):
    return any(w[i] == w[i + 1] for i in range(len(w) - 1))


def share(rng, letters, pairs, sides, tries=60):
    """`letters` shared out three a side so no pair in `pairs` stands on one
    side: [side of each letter] in `letters`' order, or None."""
    n = len(letters)
    idx = {c: i for i, c in enumerate(letters)}
    nb = [set() for _ in range(n)]
    for a, b in pairs:
        nb[idx[a]].add(idx[b])
        nb[idx[b]].add(idx[a])
    for _ in range(tries):
        order = sorted(range(n), key=lambda i: (-len(nb[i]), rng.random()))
        side = [-1] * n
        count = [0] * sides
        steps = [0]

        def go(k):
            if k == n:
                return True
            # a hard graph is given up on, not proved impossible
            steps[0] += 1
            if steps[0] > 4000:
                return False
            i = order[k]
            opts = list(range(sides))
            rng.shuffle(opts)
            for s in opts:
                if count[s] >= 3 or any(side[j] == s for j in nb[i]):
                    continue
                side[i] = s
                count[s] += 1
                if go(k + 1):
                    return True
                side[i] = -1
                count[s] -= 1
            return False

        if go(0):
            return side
    return None


def takes(w, side_of):
    """Whether the fence takes `w`: every letter a post, never two in a row
    from one side."""
    if len(w) < 3:
        return False
    prev = -1
    for c in w:
        s = side_of.get(c)
        if s is None or s == prev:
            return False
        prev = s
    return True


def mask_of(w, bit):
    m = 0
    for c in w:
        m |= bit[c]
    return m


def fewest(words, bit, full, gate_letter, most):
    """The fewest words (at most `most`, three at most) chaining to use
    every post (ending on `gate_letter` when given), or 0 when more are
    needed. Words are read as (mask, first, last): many share one."""
    ends = defaultdict(set)    # first letter -> {(mask, last)}
    every = set()
    for w in words:
        m = mask_of(w, bit)
        ends[w[0]].add((m, w[-1]))
        every.add((m, w[-1]))

    def ok(last):
        return gate_letter is None or last == gate_letter

    for m, last in every:
        if m == full and ok(last):
            return 1
    if most < 2:
        return 0
    # two words: one ending on L, one starting on L, between them every
    # post. Only the largest letter sets matter (a word whose posts are a
    # part of another's never closes a chain the other does not), and the
    # two must hold n posts between them.
    n = bin(full).count("1")
    ending = defaultdict(set)
    for m, last in every:
        ending[last].add(m)
    for letter, group in ends.items():
        tails = _largest(m for m, last in group if ok(last))
        if not tails:
            continue
        heads = _largest(ending.get(letter, ()))
        by_count = defaultdict(list)
        for mv in tails:
            by_count[bin(mv).count("1")].append(mv)
        for m in heads:
            need = full & ~m
            for c in range(n - bin(m).count("1"), n + 1):
                for mv in by_count.get(c, ()):
                    if mv & need == need:
                        return 2
    if most < 3:
        return 0
    closing = defaultdict(list)
    for first, group in ends.items():
        closing[first] = [m for m, last in group if ok(last)]
    seen = set()
    for m, last in every:
        for mv, lv in ends[last]:
            mm = m | mv
            if mm == m or (mm, lv) in seen:
                continue
            seen.add((mm, lv))
            need = full & ~mm
            for mx in closing[lv]:
                if mx & need == need:
                    return 3
    return 0


def _largest(masks):
    """The masks no other mask holds all of."""
    out = []
    for m in sorted(set(masks), key=lambda m: -bin(m).count("1")):
        if not any(m & k == m for k in out):
            out.append(m)
    return out


def build(dicts, lang, cache):
    bad = rude(dicts, lang)
    lex = proper(lexicon(dicts, lang, cache), lang, bad)
    lex.update(lexicon3(dicts, lang, cache))
    lex = {w: v for w, v in lex.items() if not doubled(w)}
    crude = CRUDE[lang]
    suffix = "" if lang == "en" else "." + lang
    fair_g, more_g = defaultdict(list), defaultdict(list)
    for w in sorted(lex, key=lambda w: (-lex[w][0], w)):
        (fair_g if lex[w][0] >= FAIR_Z and w not in crude else more_g)[w[0]].append(w)
    shown = {w: lex[w][1].lower() for w in lex if lex[w][1].lower() != w}
    doc = {"version": 1,
           "note": ("Garden Fence's words, built by tools/build_fence.py from wordfreq's words (Robyn "
                    "Speer, CC-BY-SA 4.0, https://github.com/rspeer/wordfreq), pruned at build time by "
                    "the LibreOffice Hunspell dictionaries and the LDNOOBW list; three letters or more, "
                    "never one letter twice in a row. By first letter, space-separated: `fair` "
                    "commonest first (the bulb and the par walk on them), `more` rarer words the fence "
                    "still takes, `shown` accents."),
           "fair": {k: " ".join(v) for k, v in sorted(fair_g.items())},
           "more": {k: " ".join(sorted(v)) for k, v in sorted(more_g.items())},
           "shown": shown}
    (ROOT / f"content/fence_words{suffix}.json").write_text(json.dumps(doc, ensure_ascii=False, separators=(",", ":")))
    print(f"{lang} words: fair {sum(map(len, fair_g.values()))} more {sum(map(len, more_g.values()))}", flush=True)
    # each word's letters as a set over the alphabet, so a fence's words are
    # found by a mask test before the side rule is read
    abc = {c: 1 << i for i, c in enumerate(ALPHA[lang])}
    lex_words = sorted(lex)
    lex_sets = [sum(abc[c] for c in set(w)) for w in lex_words]
    only = os.environ.get("FENCE_BANDS")
    for band, (bank, sides, seeds, gate) in enumerate(BANDS):
        if only and str(band) not in only.split(","):
            continue
        rng = random.Random(f"fence|{lang}|{bank}")
        n = sides * 3
        seedz = SEED_Z[band]
        pool = sorted(w for w in lex if lex[w][0] >= seedz and w not in crude and len(w) >= 4)
        by_first = defaultdict(list)
        for w in pool:
            by_first[w[0]].append(w)
        used = defaultdict(int)
        boards = []
        seen = set()
        tries = 0
        while len(boards) < PER_BANK and tries < 400000:
            tries += 1
            chain = [rng.choice(pool)]
            letters = set(chain[0])
            dead = False
            for k in range(1, seeds):
                last = k == seeds - 1
                nxt = [v for v in by_first[chain[-1][-1]] if v not in chain]
                if last:
                    nxt = [v for v in nxt if len(letters | set(v)) == n]
                else:
                    # the middle word leaves room for one more
                    nxt = [v for v in nxt if n - 7 <= len(letters | set(v)) <= n - 3]
                if not nxt:
                    dead = True
                    break
                v = rng.choice(nxt)
                chain.append(v)
                letters |= set(v)
            if dead or len(letters) != n or any(used[w] >= SEED_CAP for w in chain):
                continue
            pairs = set()
            for w in chain:
                for i in range(len(w) - 1):
                    pairs.add((w[i], w[i + 1]))
            order = sorted(letters)
            side = share(rng, order, pairs, sides)
            if side is None:
                continue
            side_of = {c: side[i] for i, c in enumerate(order)}
            # the posts side by side, each side's three in a shuffled order
            posts = []
            for s in range(sides):
                mine = [c for c in order if side_of[c] == s]
                rng.shuffle(mine)
                posts.extend(mine)
            key = "".join(sorted(posts))
            if key in seen:
                continue
            have = sum(abc[c] for c in posts)
            words = [w for w, ws in zip(lex_words, lex_sets) if ws & ~have == 0 and takes(w, side_of)]
            fair = [w for w in words if lex[w][0] >= FAIR_Z and w not in crude]
            if len(fair) < FEWEST_FAIR[band]:
                continue
            bit = {c: 1 << i for i, c in enumerate(posts)}
            full = (1 << n) - 1
            g = chain[-1][-1] if gate else None
            # no shorter chain over every word the fence takes
            if fewest(words, bit, full, g, seeds - 1):
                continue
            seen.add(key)
            for w in chain:
                used[w] += 1
            if len(boards) % 50 == 49:
                print(f"  {lang} {bank}: {len(boards) + 1} in {tries} tries", flush=True)
            boards.append({"posts": "".join(posts), "sides": sides,
                           "gate": posts.index(g) if gate else -1, "par": seeds,
                           "route": chain, "words": len(words), "fair": len(fair)})
        doc = {"version": 1,
               "note": ("Garden Fence's fences, built by tools/build_fence.py from wordfreq's words "
                        "(Robyn Speer, CC-BY-SA 4.0, https://github.com/rspeer/wordfreq), pruned at "
                        "build time by the LibreOffice Hunspell dictionaries and the LDNOOBW list. "
                        "`posts` three a side clockwise from the top, `par` the fewest words that use "
                        "every post, `route` one such chain, `words` and `fair` how many words the "
                        "fence takes (content/fence_words.json), `gate` Insane's last post."),
               "boards": boards}
        out = ROOT / f"content/insane/{bank}{suffix}.json"
        out.write_text(json.dumps(doc, ensure_ascii=False, separators=(",", ":")))
        nw = [b["words"] for b in boards]
        nf = [b["fair"] for b in boards]
        print(f"{lang} {bank}: {len(boards)} in {tries} tries; words avg {sum(nw) / max(1, len(nw)):.0f} "
              f"(min {min(nw, default=0)}), fair avg {sum(nf) / max(1, len(nf)):.0f}; "
              f"{out.stat().st_size // 1024} KB", flush=True)


if __name__ == "__main__":
    dicts = sys.argv[1]
    cache = sys.argv[2]
    for lang in (sys.argv[3:] or ["en", "pt", "es"]):
        build(dicts, lang, cache)
