#!/usr/bin/env python3
"""Honeycomb's word lists and hives (spec docs/superpowers/specs/2026-10-22-honeycomb-design.md).

    python3 -m venv /tmp/hv && /tmp/hv/bin/pip install wordfreq spylls
    /tmp/hv/bin/python tools/build_honeycomb.py <dicts dir>

<dicts dir> holds the LibreOffice Hunspell dictionaries (en_US, en_GB,
pt_BR, es_ES .dic/.aff from github.com/LibreOffice/dictionaries) and the
LDNOOBW lists as rude_<lang>.txt. They prune at build time only: nothing of
theirs is shipped. What ships is wordfreq's (CC-BY-SA 4.0, attributed in each
file's note).

Writes content/honeycomb.json (en), honeycomb.pt.json, honeycomb.es.json:
every word a player may make (four letters or more, no S, seven letters at
most, folded the way Hidden Word folds), with its letter mask and the band
from which it is one of the day's words (its tier: 0 common .. 2 rarer, 3 a
word the hive takes and scores but never counts or hints). And four banks
per language, content/insane/honeycomb_<band>[.lang].json: hives (seven
letters, the queen's letter, Insane's flight order) sorted into bands by how
many of the day's words they hold.
"""
import json, random, re, sys, unicodedata
from pathlib import Path

import wordfreq
from spylls.hunspell import Dictionary

ROOT = Path(__file__).resolve().parent.parent
LANGS = {"en": ["en_US", "en_GB"], "pt": ["pt_BR"], "es": ["es_ES"]}
ALPHA = {"en": "abcdefghijklmnopqrstuvwxyz", "pt": "abcdefghijklmnopqrstuvwxyz", "es": "abcdefghijklmnopqrstuvwxyzñ"}
BARE = str.maketrans("áàâãäéèêëíìîïóòôõöúùûüç", "aaaaaeeeeiiiiooooouuuuc")
# zipf floors: tier 0 from Easy, 1 from Medium, 2 from Hard; 3 accepted only
TIERS = [3.3, 2.9, 2.5, 1.5]
BANDS = ["easy", "medium", "hard", ""]
# Roman numerals are in the dictionaries (viii, xiii) and are not words
ROMAN = re.compile(r"m{0,4}(cm|cd|d?c{0,3})(xc|xl|l?x{0,3})(ix|iv|v?i{0,3})")
# per band: the tier its words come from, how many words a hive holds
WINDOW = {0: (0, 16, 34), 1: (1, 26, 48), 2: (2, 34, 58), 3: (2, 30, 52)}
# Insane: every letter in the queen's cell must hold this many words
INSANE_EACH = 9
PER_BAND = 366

def fold(w, lang):
    w = w.lower()
    if lang == "es":
        return "".join(c if c == "ñ" else c.translate(BARE) for c in w)
    return w.translate(BARE)

def rude(dicts, lang):
    out = set()
    p = Path(dicts) / f"rude_{lang}.txt"
    for line in p.read_text().splitlines():
        line = line.strip().lower()
        if line and " " not in line:
            out.add(fold(line, lang))
    return out

def stems(dicts, lang):
    """The dictionaries' own stems: (capitalised, lower-case), folded."""
    caps, low = set(), set()
    for d in LANGS[lang]:
        for line in open(Path(dicts) / f"{d}.dic", encoding="utf-8", errors="ignore"):
            s = line.split("/")[0].strip().split("-")[0]
            if not s.isalpha():
                continue
            if s[0].isupper() and not s.isupper():
                caps.add(fold(s, lang))
            elif s.islower():
                low.add(fold(s, lang))
    return caps, low

def build(dicts, lang, stats):
    hs = [Dictionary.from_files(str(Path(dicts) / d)) for d in LANGS[lang]]
    caps, low = stems(dicts, lang)
    bad = rude(dicts, lang)
    alpha = ALPHA[lang]
    words = {}  # folded -> [zipf, written]
    for w in wordfreq.iter_wordlist(lang, "best"):
        z = wordfreq.zipf_frequency(w, lang)
        if z < TIERS[-1]:
            break
        if len(w) < 4 or not w.isalpha():
            continue
        f = fold(w, lang)
        if any(c not in alpha for c in f) or "s" in f or len(set(f)) > 7:
            continue
        if not any(h.lookup(w) for h in hs) or ROMAN.fullmatch(w):
            continue
        if f in words:
            continue
        words[f] = [z, w]
    out_words = sorted(words)
    tiers = []
    for f in out_words:
        z = words[f][0]
        t = next(i for i, floor in enumerate(TIERS) if z >= floor)
        # a rude word is taken when typed, but never one of the day's words
        if f in bad or any(b in f for b in bad if len(b) >= 4):
            t = 3
        tiers.append(t)
    # shy: a day's word that is also a name or a place in the dictionary
    # (Amanda, Argentina): counted when found, never shown by the bulb, never
    # the hive's full-comb word
    shy = [i for i, f in enumerate(out_words) if tiers[i] < 3 and f in caps and f not in low]
    masks = [sum(1 << alpha.index(c) for c in set(f)) for f in out_words]
    written = {str(i): words[f][1] for i, f in enumerate(out_words) if words[f][1] != f}
    doc = {
        "version": 1,
        "note": ("Honeycomb's words, from wordfreq (Robyn Speer, CC-BY-SA 4.0, "
                 "https://github.com/rspeer/wordfreq), pruned at build time by the "
                 "LibreOffice Hunspell dictionaries (nothing of theirs is shipped) and "
                 "the LDNOOBW list. Built by tools/build_honeycomb.py: folded words of "
                 "four letters or more with no S and at most seven letters, each with its "
                 "letter mask over `alphabet` and its tier (0 common .. 2 rarer: the band "
                 "from which it is one of the day's words; 3 taken and scored, never "
                 "counted or hinted). `written` keeps a word's accents by its index; "
                 "`shy` are the indices of day's words the dictionaries also have as a "
                 "name or a place: counted, never hinted."),
        "alphabet": alpha,
        "words": out_words,
        "masks": masks,
        "tiers": "".join(str(t) for t in tiers),
        "written": written,
        "shy": shy,
    }
    suffix = "" if lang == "en" else "." + lang
    (ROOT / f"content/honeycomb{suffix}.json").write_text(json.dumps(doc, ensure_ascii=False, separators=(",", ":")))
    print(lang, len(out_words), "words; tiers", [tiers.count(i) for i in range(4)])
    hives(lang, out_words, masks, tiers, alpha, suffix, set(shy))

def hives(lang, out_words, masks, tiers, alpha, suffix, shy):
    rng = random.Random("honeycomb|" + lang)
    full = {}  # mask of a seven-letter word -> the words that fill it
    for i, (f, m, t) in enumerate(zip(out_words, masks, tiers)):
        if bin(m).count("1") == 7 and t < 3 and i not in shy:
            full.setdefault(m, []).append((t, f))
    keys = sorted(full)
    rng.shuffle(keys)
    # a comb's letters serve one band each queen: a set two bands share has a
    # different queen in each
    queens = {}
    for band in [3, 2, 0, 1]:
        tier, lo, hi = WINDOW[band]
        boards = []
        counts = []
        seen = set()
        for hm in keys:
            if hm in seen or min(t for t, _ in full[hm]) > tier:
                continue
            inside = [(m, t) for m, t in zip(masks, tiers) if t <= tier and m & ~hm == 0]
            letters = [c for i, c in enumerate(alpha) if hm >> i & 1]
            per = {c: sum(1 for m, _ in inside if m >> alpha.index(c) & 1) for c in letters}
            if band == 3:
                if min(per.values()) < INSANE_EACH:
                    continue
                ok = [c for c in letters if lo <= per[c] <= hi]
            else:
                ok = [c for c in letters if lo <= per[c] <= hi]
            ok = [c for c in ok if c not in queens.get(hm, set())]
            if not ok:
                continue
            queen = rng.choice(ok)
            entry = {"letters": "".join(letters), "queen": queen}
            if band == 3:
                rest = [c for c in letters if c != queen]
                rng.shuffle(rest)
                entry["flight"] = "".join(rest)
            boards.append(entry)
            counts.append(per[queen])
            seen.add(hm)
            queens.setdefault(hm, set()).add(queen)
            if len(boards) >= PER_BAND:
                break
        name = BANDS[band]
        doc = {"version": 1, "note": f"Honeycomb's {name or 'insane'} hives, built by tools/build_honeycomb.py: seven letters and the queen's (whose letter every word holds), each holding {lo}-{hi} of the day's words of tier {tier} or below" + ("; `flight` is the order the queen flies in (Wandering Queen)" if band == 3 else "") + ".", "boards": boards}
        fn = f"honeycomb_{name}" if name else "honeycomb"
        (ROOT / f"content/insane/{fn}{suffix}.json").write_text(json.dumps(doc, ensure_ascii=False, indent=1))
        counts.sort()
        print(" ", lang, name or "insane", len(boards), "hives; words", counts[:1], counts[len(counts) // 2:len(counts) // 2 + 1], counts[-1:])

if __name__ == "__main__":
    dicts = sys.argv[1]
    for lang in LANGS:
        build(dicts, lang, False)
