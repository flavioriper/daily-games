#!/usr/bin/env python3
"""Padlock's locks (spec docs/superpowers/specs/2026-11-04-padlock-design.md).

    python3 -m venv /tmp/hv && /tmp/hv/bin/pip install wordfreq spylls
    /tmp/hv/bin/python tools/build_padlock.py <dicts dir>

<dicts dir> is Honeycomb's (tools/build_honeycomb.py): the LibreOffice
Hunspell dictionaries and the LDNOOBW lists as rude_<lang>.txt, used to prune
at build time only. What ships is wordfreq's (CC-BY-SA 4.0, attributed in each
bank's note).

A lock is a row of letter dials, one per letter of the band's word length.
It is made by stacking a handful of common words (the seeds) letter by
letter: dial k holds the k-th letters of the seeds, each once. Every word the
dials can spell is then looked up (`words`, the ones the lock credits), and
the fewest of the fair ones (common enough to ask for) that light every
letter on every dial is solved exactly (`min`), never assumed.

Writes four banks per language, content/insane/padlock_<band>[.lang].json
(easy, medium, hard; Insane is the plain name), each
{"version": 1, "note", "boards": [{"dials", "start", "words", "fair", "min",
"shown"}]}: `dials` the letters of each dial top to bottom, `start` the
letter of each dial in the window as dealt (never a word), `words` every
word the dials spell that a player may dial (folded, sorted), `fair` the
indices into `words` of the ones the bulb and the stars count on, `shown` a
word's accents by its index where it has them. The game reads them through
InsaneBank.

Bands (word length, seeds, dial depths, the fewest words):
  easy    four letters, four seeds,   min 3..4
  medium  five letters, five seeds,   min 4..5
  hard    six letters, five seeds,    min 4..5, deeper dials
  insane  six letters, six seeds,     min 5..6 (Rusty Lock: one dial only
          turns down, and comes round past its last letter)

`min` is the par the stars read: the fewest fair words. A player who dials
a rarer word may beat it; the board solves the fewest still needed over
every credited word as it goes.
"""
import json, random, re, sys, unicodedata
from functools import lru_cache
from itertools import product
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
from build_honeycomb import LANGS, ALPHA, ROMAN, fold, rude, stems  # noqa: E402

PER_BANK = 365
# zipf floors: a seed, a fair word (the bulb and the fewest), a credited word
SEED_Z = [3.6, 3.4, 3.2, 3.2]
FAIR_Z = 2.9
CREDIT_Z = 1.8
# band: (bank, length, seeds, min range, most letters on a dial, credited words range)
BANDS = [
    ("padlock_easy", 4, 4, (3, 4), 4, (8, 40)),
    ("padlock_medium", 5, 5, (4, 5), 5, (8, 45)),
    ("padlock_hard", 6, 5, (4, 5), 5, (6, 40)),
    ("padlock", 6, 6, (5, 6), 6, (6, 45)),
]
# How often one word may be a seed in a bank.
SEED_CAP = 6
# Words the LDNOOBW lists miss that a lock should never spell back at a
# player (Honeycomb never met most of them: it has no S).
EXTRA_RUDE = {
    "en": {"piss", "pissed", "pisses", "meth", "crap", "crappy", "damn", "damned", "slut", "sluts",
           "porn", "porno", "nazi", "nazis", "bitch", "boobs", "boob", "tits", "dick", "dicks",
           "cock", "cocks", "homo", "homos", "fag", "fags", "twat", "wank", "anal", "anus",
           "rape", "raped", "rapes", "rapist", "sexy", "kike", "spic", "dyke", "slave", "slaves",
           "nigga", "hooker", "pussy", "horny", "booze", "drunk", "weed", "crack", "cocaine", "heroin"},
    "pt": {"porra", "merda", "bosta", "puta", "putas", "puto", "pinto", "pica", "piroca", "rola",
           "cu", "cuzao", "foder", "fode", "fodeu", "fodido", "transa", "transar", "tesao", "teta",
           "tetas", "peito", "peitos", "bunda", "bundas", "viado", "bicha", "corno", "chifre",
           "droga", "drogas", "cocaina", "crack", "maconha", "nazi", "nazista", "estupro", "sexo",
           "sexy", "safada", "safado", "vadia", "piranha", "xoxota", "buceta", "cacete", "caralho",
           "escrava", "escravo", "bebado", "bebada", "matar", "morte", "mata", "matou"},
    "es": {"puta", "putas", "puto", "putos", "joder", "jodido", "coño", "polla", "pollas", "verga",
           "culo", "culos", "teta", "tetas", "pene", "follar", "mierda", "cabron", "marica",
           "maricon", "zorra", "perra", "nazi", "nazis", "droga", "drogas", "cocaina", "crack",
           "sexo", "sexy", "violar", "esclava", "esclavo", "borracho", "matar", "muerte", "mato"},
}
# Stems a word may not start with (their every form is rude or cruel), and
# names and places the dictionaries let through in lower case.
RUDE_STEMS = {
    "en": ("piss", "fuck", "shit", "cunt", "slut", "whore", "retard"),
    "pt": ("fod", "porr", "put", "merd", "tarad", "anal", "cacet", "sacan", "chup", "brox"),
    "es": ("jod", "put", "foll", "cojon", "mierd", "porr", "chup", "mamad", "coñ", "cabron"),
}
NAMES = {"israel", "maria", "garcia", "bianca", "bianco", "fausto", "fausta", "julio", "loures",
         "triana", "pavia", "savoy", "marge", "lisa", "liam", "japon", "paris", "texas", "london",
         "jesus", "cristo", "satan", "allah", "hitler", "nazi", "india", "china", "peru", "cuba",
         "roma", "madrid", "lisboa", "brasil", "espana", "mexico", "chile", "italia", "europa",
         "farias", "mario", "carlos", "pedro", "paulo", "jorge", "lucas", "diego", "ana", "sara",
         "baloo", "elena", "marta", "laura", "pablo", "jose", "juan", "luis", "miguel", "ramon",
         "simon", "pilar", "rosa", "sofia", "lucia", "julia", "clara", "nadia", "ivan", "oscar"}


def lexicon(dicts, lang):
    """Folded words of four to six letters: {folded: (zipf, written)}, rude
    words and names left out."""
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
        if not 4 <= len(w) <= 6 or not w.isalpha():
            continue
        f = fold(w, lang)
        if any(c not in alpha for c in f) or f in words:
            continue
        if not any(h.lookup(w) for h in hs) or ROMAN.fullmatch(w):
            continue
        if f in bad or f in EXTRA_RUDE[lang] or any(b in f for b in bad if len(b) >= 4):
            continue
        if f.startswith(RUDE_STEMS[lang]) or f in NAMES:
            continue
        if f in caps and f not in low:
            continue
        words[f] = (z, w)
    return words


def fewest(lit_all: int, masks: list) -> int:
    """The fewest masks whose union is `lit_all`: branch on the lowest bit
    no mask chosen covers yet."""
    best = [99]

    @lru_cache(maxsize=None)
    def go(left: int) -> int:
        if left == 0:
            return 0
        bit = left & -left
        out = 99
        for m in masks:
            if m & bit:
                out = min(out, 1 + go(left & ~m))
        return out
    return go(lit_all)


def make_lock(rng, seeds, lex, length):
    dials = []
    for k in range(length):
        col = []
        for w in seeds:
            if w[k] not in col:
                col.append(w[k])
        rng.shuffle(col)
        dials.append(col)
    found = []
    for combo in product(*dials):
        w = "".join(combo)
        if w in lex:
            found.append(w)
    found.sort()
    # letter bits: dial k letter j -> bit offset
    off = [0]
    for d in dials:
        off.append(off[-1] + len(d))
    def mask(w):
        return sum(1 << (off[k] + dials[k].index(c)) for k, c in enumerate(w))
    fair = [i for i, w in enumerate(found) if lex[w][0] >= FAIR_Z]
    full = (1 << off[-1]) - 1
    n = fewest(full, tuple(sorted({mask(found[i]) for i in fair}, reverse=True)))
    return dials, found, fair, n


def build(dicts, lang):
    lex = lexicon(dicts, lang)
    suffix = "" if lang == "en" else "." + lang
    for band, (bank, length, nseeds, (lo, hi), deep, (wlo, whi)) in enumerate(BANDS):
        rng = random.Random(f"padlock|{lang}|{bank}")
        pool = sorted(w for w, (z, _) in lex.items() if len(w) == length and z >= SEED_Z[band])
        same = sorted(w for w in lex if len(w) == length)
        sub = {w: lex[w] for w in same}
        used = {}
        boards = []
        tries = 0
        while len(boards) < PER_BANK and tries < 400000:
            tries += 1
            free = [w for w in pool if used.get(w, 0) < SEED_CAP]
            seeds = rng.sample(free, nseeds)
            # dials of two letters or more, none past the band's depth
            depths = [len({w[k] for w in seeds}) for k in range(length)]
            if min(depths) < 2 or max(depths) > deep:
                continue
            dials, found, fair, n = make_lock(rng, seeds, sub, length)
            if not lo <= n <= hi or not wlo <= len(found) <= whi:
                continue
            # a start whose window is not a word
            for _ in range(50):
                start = [rng.randrange(len(d)) for d in dials]
                if "".join(d[s] for d, s in zip(dials, start)) not in sub:
                    break
            else:
                continue
            for w in seeds:
                used[w] = used.get(w, 0) + 1
            shown = {str(i): lex[w][1].lower() for i, w in enumerate(found) if lex[w][1].lower() != w}
            boards.append({"dials": ["".join(d) for d in dials], "start": start,
                           "words": found, "fair": fair, "min": n, "shown": shown})
        doc = {"version": 1,
               "note": ("Padlock's locks, built by tools/build_padlock.py from wordfreq's words "
                        "(Robyn Speer, CC-BY-SA 4.0, https://github.com/rspeer/wordfreq), pruned "
                        "at build time by the LibreOffice Hunspell dictionaries and the LDNOOBW "
                        "list. `dials` top to bottom, `start` the window as dealt, `words` every "
                        "word the dials spell, `fair` those the bulb and the fewest count on, "
                        "`min` the fewest fair words that light every letter, `shown` accents."),
               "boards": boards}
        (ROOT / f"content/insane/{bank}{suffix}.json").write_text(json.dumps(doc, ensure_ascii=False, separators=(",", ":")))
        mins = [b["min"] for b in boards]
        print(f"{lang} {bank}: {len(boards)} locks in {tries} tries; pool {len(pool)}; "
              f"min {min(mins) if mins else '-'}..{max(mins) if mins else '-'}; "
              f"words avg {sum(len(b['words']) for b in boards) / max(1, len(boards)):.1f}; "
              f"letters avg {sum(sum(len(d) for d in b['dials']) for b in boards) / max(1, len(boards)):.1f}")


if __name__ == "__main__":
    dicts = sys.argv[1]
    for lang in (sys.argv[2:] or ["en", "pt", "es"]):
        build(dicts, lang)
