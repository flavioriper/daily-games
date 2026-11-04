#!/usr/bin/env python3
"""Biscuit Tin's tins (spec docs/superpowers/specs/2026-11-04-biscuit-tin-design.md).

    python3 -m venv /tmp/hv && /tmp/hv/bin/pip install wordfreq spylls
    /tmp/hv/bin/python tools/build_biscuit.py <dicts dir> [cache dir] [langs...]

<dicts dir> is Honeycomb's (tools/build_honeycomb.py): the LibreOffice
Hunspell dictionaries and the LDNOOBW lists as rude_<lang>.txt, used to prune
at build time only. What ships is wordfreq's (CC-BY-SA 4.0, attributed in each
bank's note). [cache dir], when given, keeps each language's pruned word list
between runs (the Hunspell pass is the slow part).

A tin is a handful of long common words (the biscuits), each broken into
four pieces of two to four letters, the pieces mixed. Every ordered run of
one to four different pieces is looked up (`words`, the ones the tin
credits, four letters or more); a deal is kept only when the runs of four
pieces that spell a word are exactly its biscuits, no piece and no run is a
rude word, and every piece is different. Insane (Crumbs) mixes in the four
pieces of one more long word that the tin never credits whole.

Writes four banks per language, content/insane/biscuit_<band>[.lang].json
(easy, medium, hard; Insane is the plain name), each
{"version": 1, "note", "boards": [{"pieces", "biscuits", "words", "fair",
"line", "shown"}]}: `pieces` the pieces in the tin's order, `biscuits` each
biscuit as the indices of its four pieces in order, `words` every word the
tin credits as [folded, the most pieces it takes] sorted, `fair` the indices
of the words common enough to ask for, `line` the points three stars ask
for, `shown` a word's accents by its index where it has them. The game reads
them through InsaneBank.

Points a word: 1, 2, 4 or 8 by the pieces it takes. `line` is the biscuits'
points and a share of what the other fair words hold.
"""
import json, random, sys
from itertools import permutations
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
from build_honeycomb import LANGS, ALPHA, ROMAN, fold, rude, stems  # noqa: E402
from build_padlock import EXTRA_RUDE, RUDE_STEMS, NAMES  # noqa: E402

PER_BANK = 365
POINTS = [0, 1, 2, 4, 8]
FAIR_Z = 2.9
CREDIT_Z = 1.8
SHORTEST = 4
LONGEST = 16
# A biscuit word's zipf floor, by band.
SEED_Z = [3.2, 3.0, 3.0, 3.0]
# band: (bank, biscuits, word lengths, piece lengths, most two-letter pieces
# a biscuit, fewest two-letter pieces a biscuit, crumbs)
BANDS = [
    ("biscuit_easy", 3, (10, 13), (2, 4), 1, 0, False),
    ("biscuit_medium", 5, (9, 12), (2, 4), 2, 0, False),
    ("biscuit_hard", 5, (8, 10), (2, 3), 4, 2, False),
    ("biscuit", 5, (9, 12), (2, 4), 2, 0, True),
]
# The share of the other fair words' points three stars ask for, by band.
SHARE = [0.15, 0.15, 0.12, 0.12]
# How often one word may be a biscuit in a bank.
SEED_CAP = 2


def lexicon(dicts, lang, cache):
    """Folded words of four to sixteen letters: {folded: (zipf, written)},
    rude words and names left out."""
    if cache:
        p = Path(cache) / f"biscuit_lex_{lang}.json"
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
        if not SHORTEST <= len(w) <= LONGEST or not w.isalpha():
            continue
        f = fold(w, lang)
        if any(c not in alpha for c in f) or f in words:
            continue
        if f in bad or f in EXTRA_RUDE[lang] or any(b in f for b in bad if len(b) >= 4):
            continue
        if f.startswith(RUDE_STEMS[lang]) or f in NAMES:
            continue
        if f in caps and f not in low:
            continue
        if ROMAN.fullmatch(w) or not any(h.lookup(w) for h in hs):
            continue
        words[f] = (z, w)
    if cache:
        (Path(cache) / f"biscuit_lex_{lang}.json").write_text(json.dumps(words, ensure_ascii=False))
    return words


def cut(rng, word, plo, phi, most_two, least_two):
    """`word` broken into four pieces of plo..phi letters, or None."""
    n = len(word)
    ways = []
    for a in range(plo, phi + 1):
        for b in range(plo, phi + 1):
            for c in range(plo, phi + 1):
                d = n - a - b - c
                if plo <= d <= phi:
                    sizes = (a, b, c, d)
                    two = sizes.count(2)
                    if least_two <= two <= most_two:
                        ways.append(sizes)
    if not ways:
        return None
    a, b, c, d = rng.choice(ways)
    return [word[:a], word[a:a + b], word[a + b:a + b + c], word[a + b + c:]]


def prefixes(lex):
    """Every prefix of every word in `lex`, for the search to prune on."""
    out = set()
    for w in lex:
        for k in range(1, len(w)):
            out.add(w[:k])
    return out


def credit(pieces, lex, pre):
    """Every word an ordered run of one to four different pieces spells:
    {folded: most pieces}, and the runs of four that spell one. A run is
    grown only while it is the start of some word."""
    out = {}
    fours = []

    def grow(run, s):
        if len(s) >= 1 and s in lex:
            out[s] = max(out.get(s, 0), len(run))
            if len(run) == 4:
                fours.append((s, tuple(run)))
        if len(run) == 4 or (run and s not in pre):
            return
        for i, p in enumerate(pieces):
            if i not in run:
                run.append(i)
                grow(run, s + p)
                run.pop()

    grow([], "")
    return out, fours


def build(dicts, lang, cache):
    lex = lexicon(dicts, lang, cache)
    bad = rude(dicts, lang) | EXTRA_RUDE[lang]
    suffix = "" if lang == "en" else "." + lang
    for band, (bank, nb, (wlo, whi), (plo, phi), most_two, least_two, crumbs) in enumerate(BANDS):
        rng = random.Random(f"biscuit|{lang}|{bank}")
        pre = prefixes(lex)
        pool = sorted(w for w, (z, _) in lex.items() if wlo <= len(w) <= whi and z >= SEED_Z[band]
                      and cut(random.Random(0), w, plo, phi, most_two, least_two) is not None)
        used = {}
        boards = []
        tries = 0
        why = {}
        while len(boards) < PER_BANK and tries < 200000:
            tries += 1
            free = [w for w in pool if used.get(w, 0) < SEED_CAP]
            if len(free) < nb + 1:
                why["pool"] = why.get("pool", 0) + 1
                break
            seeds = rng.sample(free, nb + (1 if crumbs else 0))
            # no biscuit inside another, no two sharing a stem of five
            if any(a != b and (a in b or a[:5] == b[:5]) for a in seeds for b in seeds):
                why["alike"] = why.get("alike", 0) + 1
                continue
            # cut again, a few times, while two pieces come out the same
            for _ in range(12):
                cuts = [cut(rng, w, plo, phi, most_two, least_two) for w in seeds]
                flat = [p for c in cuts for p in c]
                if len(set(flat)) == len(flat):
                    break
            if len(set(flat)) != len(flat):
                why["same piece"] = why.get("same piece", 0) + 1
                continue
            if any(p in bad for p in flat):
                why["rude piece"] = why.get("rude piece", 0) + 1
                continue
            order = list(range(len(flat)))
            rng.shuffle(order)
            pieces = [flat[i] for i in order]
            where = {i: order.index(i) for i in range(len(flat))}
            found, fours = credit(pieces, lex, pre)
            if crumbs:
                found.pop(seeds[-1], None)
                fours = [f for f in fours if f[0] != seeds[-1]]
            fwords = {w for w, _ in fours}
            if fwords != set(seeds[:nb]) or len(fours) != nb:
                why["other four"] = why.get("other four", 0) + 1
                continue
            # a run of pieces must never spell a rude word, credited or not
            runs = {"".join(pieces[i] for i in run) for k in (2, 3)
                    for run in permutations(range(len(pieces)), k)}
            if runs & bad:
                why["rude run"] = why.get("rude run", 0) + 1
                continue
            words = sorted(found)
            fair = [i for i, w in enumerate(words) if lex[w][0] >= FAIR_Z or w in seeds[:nb]]
            extra = sum(POINTS[found[words[i]]] for i in fair if words[i] not in seeds[:nb])
            line = min(POINTS[4] * nb + round(SHARE[band] * extra), POINTS[4] * nb * 3 // 2)
            biscuits = [[where[b * 4 + j] for j in range(4)] for b in range(nb)]
            for w in seeds:
                used[w] = used.get(w, 0) + 1
            shown = {str(i): lex[w][1].lower() for i, w in enumerate(words) if lex[w][1].lower() != w}
            boards.append({"pieces": pieces, "biscuits": biscuits,
                           "words": [[w, found[w]] for w in words], "fair": fair,
                           "line": line, "shown": shown})
        doc = {"version": 1,
               "note": ("Biscuit Tin's tins, built by tools/build_biscuit.py from wordfreq's words "
                        "(Robyn Speer, CC-BY-SA 4.0, https://github.com/rspeer/wordfreq), pruned "
                        "at build time by the LibreOffice Hunspell dictionaries and the LDNOOBW "
                        "list. `pieces` in the tin's order, `biscuits` the four pieces of each "
                        "whole biscuit in order, `words` every word the tin credits with the "
                        "most pieces it takes, `fair` those the line counts on, `line` the "
                        "points three stars ask for, `shown` accents."),
               "boards": boards}
        (ROOT / f"content/insane/{bank}{suffix}.json").write_text(json.dumps(doc, ensure_ascii=False, separators=(",", ":")))
        lines = [b["line"] for b in boards]
        print(f"{lang} {bank}: {len(boards)} tins in {tries} tries; pool {len(pool)}; "
              f"line {min(lines) if lines else '-'}..{max(lines) if lines else '-'}; "
              f"words avg {sum(len(b['words']) for b in boards) / max(1, len(boards)):.1f}; "
              f"rejects {why}", flush=True)


if __name__ == "__main__":
    dicts = sys.argv[1]
    cache = sys.argv[2] if len(sys.argv) > 2 else ""
    for lang in (sys.argv[3:] or ["en", "pt", "es"]):
        build(dicts, lang, cache)
