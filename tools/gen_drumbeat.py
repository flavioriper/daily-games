#!/usr/bin/env python3
"""Drumbeat's songs and charts: three original tunes arranged in the house's
own instruments and synthesised here note by note, with the drum chart of
each written against the same bar grid, so the notes and the music can never
drift apart.

    python3 tools/gen_drumbeat.py            # every song, and the drum
    python3 tools/gen_drumbeat.py parade     # only these
    python3 tools/gen_drumbeat.py drums      # only the drum (don.ogg, ka.ogg)

Writes assets/sfx/drumbeat/song_<id>.ogg (the music, a bar of wood-block
count-in first) and content/drumbeat.json (every song's charts, bar lines and
Go-Go sections, in seconds from the start of the file), which
puzzles/drumbeat2d.gd reads. Needs numpy and ffmpeg on the PATH.

A chart is written once, at Hard, one string of sixteenths a bar:
    d don (the face)   k ka (the rim)   D / K the big ones
    r drumroll  R big drumroll  b balloon, each held on by '=' to where it ends
    . nothing
Normal and Easy are thinned out of it by a minimum gap between notes (half a
beat and a beat), keeping a big note over a small one, so the three always
follow the same music.
"""
import json, pathlib, subprocess, sys, tempfile, wave
import numpy as np

ROOT = pathlib.Path(__file__).resolve().parent.parent
SR = 44100
OUT_DIR = ROOT / "assets/sfx/drumbeat"
CHART_OUT = ROOT / "content/drumbeat.json"
PEAK_DB = -5.0

MAJOR = [0, 2, 4, 5, 7, 9, 11]
MINOR = [0, 2, 3, 5, 7, 8, 10]

# --- the instruments (Marigold's, tools/gen_marigold_music.py, plus a flute,
# a koto pluck and a little percussion that keeps time under the player) ---


def hz(m):
    return 440.0 * 2.0 ** ((m - 69) / 12.0)


def env(n, attack, decay):
    t = np.arange(n) / SR
    a = np.minimum(1.0, t / attack) if attack > 0 else 1.0
    return a * np.exp(-t / decay)


def marimba(m, dur, vel=1.0):
    f = hz(m)
    n = int(SR * (dur + 1.0))
    t = np.arange(n) / SR
    y = (np.sin(2 * np.pi * f * t) * env(n, 0.003, 0.5 if f < 300 else 0.36)
         + 0.28 * np.sin(2 * np.pi * f * 3.93 * t) * env(n, 0.001, 0.06)
         + 0.06 * np.sin(2 * np.pi * f * 9.2 * t) * env(n, 0.001, 0.02))
    k = int(SR * 0.012)
    y[:k] += 0.15 * np.random.default_rng(int(m)).standard_normal(k) * np.linspace(1, 0, k)
    return vel * y


def glock(m, dur, vel=1.0):
    f = hz(m)
    n = int(SR * (dur + 1.6))
    t = np.arange(n) / SR
    y = (np.sin(2 * np.pi * f * t) * env(n, 0.001, 0.8)
         + 0.35 * np.sin(2 * np.pi * f * 2.76 * t) * env(n, 0.001, 0.22)
         + 0.12 * np.sin(2 * np.pi * f * 5.40 * t) * env(n, 0.001, 0.07))
    return vel * y


def kalimba(m, dur, vel=1.0):
    f = hz(m)
    n = int(SR * (dur + 0.7))
    t = np.arange(n) / SR
    y = (np.sin(2 * np.pi * f * t) * env(n, 0.002, 0.32)
         + 0.2 * np.sin(2 * np.pi * f * 5.95 * t) * env(n, 0.001, 0.03))
    return vel * y


def koto(m, dur, vel=1.0):
    # a plucked silk string: bright harmonics that die fast over a warm body
    f = hz(m)
    n = int(SR * (dur + 0.9))
    t = np.arange(n) / SR
    y = np.zeros(n)
    for h, a in [(1, 1.0), (2, 0.5), (3, 0.3), (4, 0.18), (5, 0.1)]:
        y += a * np.sin(2 * np.pi * f * h * t) * env(n, 0.0015, 0.5 / h ** 0.7)
    return vel * 0.6 * y


def flute(m, dur, vel=1.0):
    # a bamboo flute: a soft sine with a breathy onset and a slow vibrato
    f = hz(m)
    n = int(SR * (dur + 0.12))
    t = np.arange(n) / SR
    vib = 1.0 + 0.006 * np.sin(2 * np.pi * 5.2 * t) * np.clip((t - 0.15) / 0.2, 0, 1)
    ph = 2 * np.pi * f * np.cumsum(vib) / SR
    body = np.sin(ph) + 0.18 * np.sin(2 * ph) + 0.05 * np.sin(3 * ph)
    shape = np.minimum(1.0, t / 0.04) * np.clip((dur + 0.12 - t) / 0.12, 0, 1)
    breath = np.random.default_rng(int(m) + 3).standard_normal(n)
    breath = np.convolve(breath, np.ones(6) / 6, mode="same") * np.exp(-t / 0.05) * 0.25
    return vel * (body * shape + breath)


def bass(m, dur, vel=1.0):
    f = hz(m)
    n = int(SR * (dur + 0.4))
    t = np.arange(n) / SR
    y = (np.sin(2 * np.pi * f * t) + 0.35 * np.sin(2 * np.pi * 2 * f * t)
         + 0.1 * np.sin(2 * np.pi * 3 * f * t)) * env(n, 0.004, 0.28)
    return vel * y


def kick(vel=1.0):
    # a soft felt kick: a sine dropping in pitch, no click
    n = int(SR * 0.35)
    t = np.arange(n) / SR
    f = 55 + 70 * np.exp(-t / 0.03)
    ph = 2 * np.pi * np.cumsum(f) / SR
    return vel * np.sin(ph) * env(n, 0.002, 0.12)


def shaker(vel=1.0, seed=0):
    n = int(SR * 0.09)
    rng = np.random.default_rng(seed)
    y = rng.standard_normal(n)
    y = y - np.convolve(y, np.ones(4) / 4, mode="same")  # the highs only
    return vel * y * env(n, 0.006, 0.025)


def clap(vel=1.0, seed=0):
    n = int(SR * 0.2)
    rng = np.random.default_rng(seed + 11)
    y = rng.standard_normal(n)
    y = np.convolve(y, np.ones(3) / 3, mode="same")
    t = np.arange(n) / SR
    e = np.exp(-t / 0.06) * (1 + 0.6 * (np.exp(-((t - 0.01) / 0.003) ** 2) + np.exp(-((t - 0.022) / 0.003) ** 2)))
    return vel * y * e


def wood(m, vel=1.0):
    # the count-in's wood block
    f = hz(m)
    n = int(SR * 0.12)
    t = np.arange(n) / SR
    return vel * (np.sin(2 * np.pi * f * t) + 0.4 * np.sin(2 * np.pi * f * 2.7 * t)) * env(n, 0.001, 0.025)


def don():
    # the player's drum, struck on the skin: a taiko's membrane dropping in
    # pitch as it settles, its second mode, and the stick's felt thump
    n = int(SR * 0.45)
    t = np.arange(n) / SR
    f = 88 + 70 * np.exp(-t / 0.022)
    ph = 2 * np.pi * np.cumsum(f) / SR
    y = (np.sin(ph) * env(n, 0.001, 0.16)
         + 0.35 * np.sin(1.59 * ph) * env(n, 0.001, 0.06)
         + 0.18 * np.sin(2.14 * ph) * env(n, 0.001, 0.03))
    k = int(SR * 0.012)
    thump = np.random.default_rng(21).standard_normal(k)
    thump = np.convolve(thump, np.ones(24) / 24, mode="same")
    y[:k] += 2.2 * thump * np.linspace(1, 0, k)
    return np.tanh(1.6 * y)


def ka():
    # struck on the rim: the stick's crack and the hard wood ringing short
    n = int(SR * 0.2)
    t = np.arange(n) / SR
    y = (np.sin(2 * np.pi * 1180 * t) * env(n, 0.0005, 0.035)
         + 0.7 * np.sin(2 * np.pi * 2090 * t) * env(n, 0.0005, 0.022)
         + 0.4 * np.sin(2 * np.pi * 3350 * t) * env(n, 0.0005, 0.012))
    k = int(SR * 0.004)
    crack = np.random.default_rng(22).standard_normal(k)
    crack = crack - np.convolve(crack, np.ones(3) / 3, mode="same")
    y[:k] += 1.5 * crack * np.linspace(1, 0, k)
    return np.tanh(1.4 * y)


def normal(y, db=-1.0):
    return y / np.max(np.abs(y)) * 10 ** (db / 20)


def place(buf, y, at):
    i = int(round(at * SR))
    j = min(len(buf), i + len(y))
    if j > i >= 0:
        buf[i:j] += y[: j - i]


def room(x, mix=0.2):
    n = int(SR * 1.2)
    rng = np.random.default_rng(3)
    ir = rng.standard_normal(n) * np.exp(-np.arange(n) / (SR * 0.3))
    ir = np.convolve(ir, np.ones(12) / 12, mode="same")
    ir[0] = 0.0
    ir /= np.sqrt(np.sum(ir ** 2))
    size = 1 << int(np.ceil(np.log2(len(x) + n)))
    wet = np.fft.irfft(np.fft.rfft(x, size) * np.fft.rfft(ir, size), size)[: len(x)]
    return x + mix * wet


# --- notation ---

def pitch(tok, tonic, scale):
    """'5' is the fifth degree, "5'" an octave up, '5,' one down, '7#' raised."""
    octv = tok.count("'") - tok.count(",")
    sharp = tok.count("#")
    deg = int(tok.strip("',#"))
    octv += (deg - 1) // 7
    deg = (deg - 1) % 7
    return tonic + 12 * octv + scale[deg] + sharp


def melody(bar, tonic, scale):
    """'1:2 3:2 -:4' -> [(start in eighths, midi or None, length in eighths)]."""
    out, at = [], 0.0
    for tok in bar.split():
        p, d = tok.split(":")
        d = float(d)
        out.append((at, None if p == "-" else pitch(p, tonic, scale), d))
        at += d
    assert abs(at - 8.0) < 1e-6, f"bar sums to {at}: {bar}"
    return out


CHORD_ROOTS = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def chord(name):
    """'Am' / 'F' / 'Bb' / 'E' -> (root midi in octave 3, triad above middle C)."""
    root = CHORD_ROOTS[name[0]]
    rest = name[1:]
    if rest.startswith("b"):
        root -= 1
        rest = rest[1:]
    minor = rest.startswith("m")
    r = 48 + root
    third = 3 if minor else 4
    triad = [60 + root, 60 + root + third, 60 + root + 7]
    triad = [n - 12 if n > 72 else n for n in triad]
    return r, sorted(triad)


# --- the songs ---
# A section: its bars as (chord or [two chords], melody, chart). The chart is
# Hard's, sixteen characters a bar.

def S(chords, tunes, charts, gogo=False):
    assert len(chords) == len(tunes) == len(charts)
    for c in charts:
        assert len(c) == 16, f"chart bar is {len(c)} long: {c}"
    return {"bars": list(zip(chords, tunes, charts)), "gogo": gogo}


REST = "-:8"
EMPTY = "................"

PARADE = {
    "id": "parade", "title": "Garden Parade", "bpm": 112, "tonic": 65, "scale": MAJOR,
    "lead": "marimba", "stars": [1, 3, 5], "style": "parade",
}
PARADE["sections"] = [
    S(["F", "C"], [REST, REST], [EMPTY, "d.......d......."]),
    S(["F", "Bb", "Bb", "F", "F", "C", "C", "F"],
      ["1:2 3:2 5:2 5:2", "6:2 5:2 3:4", "4:2 4:2 6:2 4:2", "3:2 2:2 1:4",
       "1:2 3:2 5:2 1':2", "7:2 6:2 5:4", "4:2 3:2 2:2 5,:2", "1:6 -:2"],
      ["d...d.k.d...d.k.", "d...k...D...k...", "d.d.k...d.d.k...", "k...k...D...kk..",
       "d...d.k.d...d.k.", "d.k.d.k.D.......", "d...k...d.d.k.k.", "D.......d.d.kkk."]),
    S(["F", "Bb", "Bb", "F", "F", "C", "C", "F"],
      ["1:2 3:2 5:2 5:2", "6:2 5:2 3:4", "4:2 4:2 6:2 4:2", "3:2 2:2 1:4",
       "1:2 3:2 5:2 1':2", "7:2 6:2 5:4", "4:2 3:2 2:2 5,:2", "1:6 -:2"],
      ["d.kkd.k.d...d.k.", "d...k...D...k.k.", "d.d.k.kkd.d.k...", "k...k...D...k.k.",
       "d.kkd.k.d...d.k.", "d.k.d.k.D...kk..", "d...k...d.d.k.kk", "D.......r=====.."]),
    S(["Dm", "Dm", "Bb", "C", "Dm", "Dm", "Bb", "C"],
      ["6:3 5:1 6:2 1':2", "6:4 5:4", "4:3 3:1 4:2 6:2", "5:8",
       "6:3 5:1 6:2 1':2", "2':4 1':4", "7:2 6:2 5:2 4:2", "5:6 -:2"],
      ["d.....k.d...D...", "d...k...d...k.k.", "d.....k.d...k...", "r===========....",
       "d.....k.d...D...", "D.......D.......", "k.k.k.k.d.d.d.d.", "b=========......"]),
    S(["F", "C", "Dm", "Bb", "F", "C", "Bb", "F"],
      ["1':2 1':1 1':1 7:2 6:2", "5:2 5:2 7:4", "6:2 6:1 6:1 5:2 4:2", "3:2 4:2 6:4",
       "1':2 1':1 1':1 7:2 6:2", "5:2 1':2 2':4", "1':2 7:2 6:2 7:2", "1':6 -:2"],
      ["d...d.d.k...k...", "d...d...K...k.k.", "d...d.d.k...k.kk", "d...k...D...k.k.",
       "d...d.d.k...k...", "d...d...D...d.d.", "d.k.d.k.d.k.d.k.", "D.......R=====.."], gogo=True),
    S(["F", "Bb", "Bb", "F", "F", "C", "C", "F"],
      ["1:2 3:2 5:2 5:2", "6:2 5:2 3:4", "4:2 4:2 6:2 4:2", "3:2 2:2 1:4",
       "1:2 3:2 5:2 1':2", "7:2 6:2 5:4", "4:2 3:2 2:2 5,:2", "1:6 -:2"],
      ["d.kkd.k.d...d.k.", "d...k...D...k.k.", "d.d.k.kkd.d.k...", "k...k...D...k.k.",
       "d.kkd.k.d...d.k.", "d.k.d.k.D...kk..", "d...k...d.d.k.kk", "D...........kkk."]),
    S(["F", "C", "Dm", "Bb", "F", "C", "Bb", "F"],
      ["1':2 1':1 1':1 7:2 6:2", "5:2 5:2 7:4", "6:2 6:1 6:1 5:2 4:2", "3:2 4:2 6:4",
       "1':2 1':1 1':1 7:2 6:2", "5:2 1':2 2':4", "1':2 7:2 6:2 7:2", "1':6 -:2"],
      ["d...d.d.k...k...", "d...d...K...k.k.", "d...d.d.k...k.kk", "d...k...D...k.k.",
       "d...d.d.k...k...", "d...d...D...d.d.", "d.k.d.k.d.k.d.k.", "D.......R=====.."], gogo=True),
    S(["F", "F"], ["1:8", REST], ["D...............", EMPTY]),
]

FESTIVAL = {
    "id": "festival", "title": "Lantern Festival", "bpm": 132, "tonic": 62, "scale": MAJOR,
    "lead": "flute", "stars": [2, 4, 6], "style": "festival",
}
_FA = (["D", "Bm", "G", "A", "D", "Bm", "A", "D"],
       ["5:2 5:2 6:2 1':2", "6:2 5:2 3:4", "2:2 3:2 5:2 3:2", "2:2 1:2 2:4",
        "5:2 5:2 6:2 1':2", "2':2 1':2 6:4", "5:2 6:2 5:2 3:2", "1:6 -:2"],
       ["d.k.d.k.d.kkd.k.", "d...k...D...k...", "d.k.d.k.d.k.d.k.", "d...k...D...kkk.",
        "d.k.d.k.d.kkd.k.", "d...k...D...k...", "d.d.k.d.d.k.d.k.", "D.......r=====.."])
_FC = (["D", "A", "Bm", "G", "D", "A", ["G", "A"], "D"],
       ["1':2 1':2 2':2 1':2", "6:2 5:2 6:4", "1':2 6:2 5:2 3:2", "5:4 6:4",
        "1':2 1':2 2':2 3':2", "2':2 1':2 6:4", "5:2 6:2 1':2 2':2", "1':6 -:2"],
       ["d.ddk.d.d.ddk.d.", "d.k.d.k.D...k.k.", "d.ddk.d.d.ddk.d.", "D...k...D...kkkk",
        "d.ddk.d.d.ddk.d.", "d.k.d.k.D...k.k.", "d.k.d.k.d.kkd.kk", "D.......R======."])
FESTIVAL["sections"] = [
    S(["D", "Bm", "G", "A"],
      ["5:4 6:2 5:2", "3:8", "2:2 3:2 5:2 6:2", "5:8"],
      [EMPTY, EMPTY, "d.......d.......", "d...d...d...D..."]),
    S(*_FA),
    S(["Bm", "Bm", "G", "G", "Em", "Em", "A", "A"],
      ["6:3 6:1 5:2 6:2", "1':4 6:4", "5:3 5:1 3:2 5:2", "6:8",
       "3:2 5:2 6:2 5:2", "3:2 2:2 1:4", "2:2 3:2 5:2 6:2", "5:6 -:2"],
      ["d.....k.d...d.k.", "D.......d...k...", "d.....k.d...d.k.", "k.k.k.k.b======.",
       "d.k.d.k.d.k.d.kk", "d...k...D.......", "d.k.d.k.d.k.d.k.", "D...k...kkkkD..."]),
    S(*_FC, gogo=True),
    S(*_FA),
    S(*_FC, gogo=True),
    S(["D", "D"], ["1':8", REST], ["D...............", EMPTY]),
]

GALLOP = {
    "id": "gallop", "title": "Firefly Gallop", "bpm": 168, "tonic": 57, "scale": MINOR,
    "lead": "marimba", "stars": [3, 5, 7], "style": "gallop",
}
_GA = (["Am", "Am", "E", "E", "Am", "Am", "E", "Am"],
       ["5:1 5:.5 5:.5 5:1 5:.5 5:.5 5:1 1':1 2':1 3':1", "2':2 1':1 7#:1 5:4",
        "7#:1 7#:.5 7#:.5 7#:1 7#:.5 7#:.5 7#:1 2':1 3':1 4':1", "3':2 2':1 1':1 7#:4",
        "5:1 5:.5 5:.5 5:1 5:.5 5:.5 5:1 1':1 2':1 3':1", "2':2 1':1 3':1 5':4",
        "4':1 3':1 2':1 1':1 7#:2 2':2", "1':6 -:2"],
       ["d.ddd.ddd.k.k.k.", "D...k.k.d...k.k.", "k.kkk.kkd.d.d.d.", "D...d.d.k...k.k.",
        "d.ddd.ddd.k.k.k.", "D...d.k.D...k.k.", "d.k.d.k.d...D...", "D...........kkk."])
_GB = (["F", "G", "C", "Am", "F", "G", "E", "E"],
       ["6:2 1':2 4':2 3':2", "2':2 7:2 5:4", "1':2 3':2 5':2 3':2", "1':4 5:4",
        "6:2 1':2 4':2 6':2", "5':2 4':2 2':4", "3':1 2':1 1':1 7#:1 1':1 2':1 3':2", "7#:8"],
       ["d...k...d.k.d.k.", "d...d...k.k.k.k.", "d...k...d.k.d.k.", "D.......k.k.kkk.",
        "d.k.d.k.d.k.d.k.", "d...d...D.......", "d.k.d.k.d.k.D...", "r=============.."])
_GC = (["Am", "F", "C", "G", "Am", "F", "E", "Am"],
       ["1':1 1':.5 1':.5 3':1 1':.5 1':.5 5':2 3':2", "4':1 4':.5 4':.5 6':1 4':.5 4':.5 1'':2 6':2",
        "5':1 5':.5 5':.5 3':1 5':.5 5':.5 1'':2 5':2", "7':2 5':2 2':4",
        "1':1 1':.5 1':.5 3':1 1':.5 1':.5 5':2 3':2", "4':1 4':.5 4':.5 6':1 4':.5 4':.5 1'':2 6':2",
        "7#':2 6':2 5':2 4':1 3':1", "1'':6 -:2"],
       ["d.ddk.kkd...D...", "d.ddk.kkd...D...", "k.kkd.ddk...D...", "d...k...D...kkkk",
        "d.ddk.kkd...D...", "d.ddk.kkd...D...", "D...k...d...k.k.", "D.......R=====.."])
GALLOP["sections"] = [
    S(["Am", "E"], [REST, REST], [EMPTY, "d...d...d.ddD..."]),
    S(*_GA),
    S(*_GA),
    S(*_GB),
    S(*_GC, gogo=True),
    S(["Am", "E", "Am", "E"], ["1':8", "7#:8", "1':8", "7#:8"],
      ["d.ddk.ddd.ddk.dd", "b=============..", "d.ddk.ddd.ddk.dd", "R=============.."]),
    S(*_GB),
    S(*_GC, gogo=True),
    S(["Am", "Am"], ["1':8", REST], ["D...............", EMPTY]),
]

SONGS = [PARADE, FESTIVAL, GALLOP]

# Note types, as puzzles/drumbeat_state.gd reads them.
DON, KA, BIG_DON, BIG_KA, ROLL, BIG_ROLL, BALLOON = range(7)
CHAR = {"d": DON, "k": KA, "D": BIG_DON, "K": BIG_KA, "r": ROLL, "R": BIG_ROLL, "b": BALLOON}
# Hits a second a balloon asks for, by difficulty.
BALLOON_RATE = [4.5, 6.5, 9.0]
# The least gap between two notes at Easy and Normal, in beats; Easy takes a
# second beat when one beat is quicker than EASY_SECONDS.
MIN_GAP = [1.0, 0.5, 0.0]
EASY_SECONDS = 0.5


def bar_start(song, i):
    beat = 60.0 / song["bpm"]
    return (1 + i) * 4 * beat  # bar 0 of the music follows one bar of count-in


def chart_hard(song):
    beat = 60.0 / song["bpm"]
    sixteenth = beat / 4.0
    notes = []
    bar = 0
    for sec in song["sections"]:
        for _, _, line in sec["bars"]:
            t0 = bar_start(song, bar)
            i = 0
            while i < 16:
                c = line[i]
                if c in "dkDK":
                    notes.append({"t": t0 + i * sixteenth, "type": CHAR[c]})
                elif c in "rRb":
                    j = i + 1
                    while j < 16 and line[j] == "=":
                        j += 1
                    notes.append({"t": t0 + i * sixteenth, "type": CHAR[c], "end": t0 + j * sixteenth})
                    i = j - 1
                elif c not in ".=":
                    raise ValueError(f"unknown chart character {c!r} in {line}")
                i += 1
            bar += 1
    return notes


def thin(song, notes, level):
    beats = MIN_GAP[level]
    if level == 0 and 60.0 / song["bpm"] < EASY_SECONDS:
        beats = 2.0
    gap = beats * 60.0 / song["bpm"] - 1e-6
    out = []
    for n in notes:
        big = n["type"] in (BIG_DON, BIG_KA)
        if out and n["type"] < ROLL and out[-1]["type"] < ROLL and n["t"] - out[-1]["t"] < gap:
            # a big note wins the slot from a small one before it
            if big and out[-1]["type"] in (DON, KA):
                out[-1] = dict(n)
            continue
        if out and out[-1]["type"] >= ROLL and n["t"] < out[-1]["end"] + gap * 0.5:
            continue
        m = dict(n)
        if m["type"] == BALLOON:
            m["count"] = max(3, int(round((m["end"] - m["t"]) * BALLOON_RATE[level])))
        out.append(m)
    return out


def pack(notes):
    rows = []
    for n in notes:
        row = [round(n["t"], 4), n["type"]]
        if "end" in n:
            row.append(round(n["end"], 4))
        if "count" in n:
            row.append(n["count"])
        rows.append(row)
    return rows


# --- the arrangement ---

def render(song):
    bpm = song["bpm"]
    beat = 60.0 / bpm
    eighth = beat / 2.0
    bars = [b for s in song["sections"] for b in s["bars"]]
    gogo_bar = [s["gogo"] for s in song["sections"] for _ in s["bars"]]
    length = (1 + len(bars)) * 4 * beat + 2.5
    L = np.zeros(int(SR * length))
    tonic, scale, style = song["tonic"], song["scale"], song["style"]

    # the count-in: four wood blocks, the first one higher
    for k in range(4):
        place(L, wood(84 if k == 0 else 79, 0.5), k * beat)

    for i, (ch, tune, _) in enumerate(bars):
        t0 = bar_start(song, i)
        go = gogo_bar[i]
        halves = ch if isinstance(ch, list) else [ch, ch]
        last = i == len(bars) - 1
        # the tune
        for at, m, d in melody(tune, tonic, scale):
            if m is None:
                continue
            when = t0 + at * eighth
            dur = d * eighth
            accent = 1.0 if at % 2 == 0 else 0.85
            if song["lead"] == "flute":
                place(L, flute(m + 12, dur * 0.95, 0.32 * accent), when)
                if go:
                    place(L, glock(m + 12, dur, 0.1 * accent), when)
            else:
                place(L, marimba(m, dur, 0.5 * accent), when)
                place(L, glock(m + 12, dur, (0.2 if go else 0.13) * accent), when)
        if last:
            root, triad = chord(halves[0])
            place(L, bass(root - 12, 3 * beat, 0.6), t0)
            for m in triad:
                place(L, marimba(m, 3 * beat, 0.22), t0)
            continue
        # the harmony and the bass, by style
        for h, name in enumerate(halves):
            root, triad = chord(name)
            th = t0 + h * 2 * beat
            if style == "parade":
                # oom-pah: the root on the beat, the chord on the off-beat
                place(L, bass(root - 12, beat, 0.5), th)
                place(L, bass(root - 5, beat, 0.35), th + beat)
                for off in (0.5, 1.5):
                    for m in triad:
                        place(L, kalimba(m, 0.4 * beat, 0.11), th + off * beat)
            elif style == "festival":
                # a root pulse and a koto rolling up the chord
                for q in range(2):
                    place(L, bass(root - 12, beat * 0.9, 0.48 if q == 0 else 0.36), th + q * beat)
                arp = triad + [triad[0] + 12]
                for k, m in enumerate(arp):
                    place(L, koto(m, 0.5 * beat, 0.16), th + k * eighth)
            else:
                # the gallop: the root as long-short-short, chords stabbed on the 8ths
                for q in range(2):
                    b0 = th + q * beat
                    place(L, bass(root - 12, eighth, 0.5), b0)
                    place(L, bass(root - 12, eighth / 2, 0.34), b0 + eighth)
                    place(L, bass(root, eighth / 2, 0.34), b0 + eighth * 1.5)
                    for m in triad:
                        place(L, kalimba(m + 12, 0.2 * beat, 0.07), b0 + eighth)
        # the time-keeping: a soft kick, a shaker, claps in Go-Go
        for q in range(4):
            tq = t0 + q * beat
            if q in (0, 2) or (go and style != "parade"):
                place(L, kick(0.55 if q == 0 else 0.42), tq)
            place(L, shaker(0.05 if go else 0.035, seed=i * 8 + q), tq + eighth)
            if go:
                place(L, shaker(0.03, seed=i * 8 + q + 400), tq)
                if q in (1, 3):
                    place(L, clap(0.14, seed=i * 4 + q), tq)
        # a glockenspiel sparkle into each Go-Go section
        if go and (i == 0 or not gogo_bar[i - 1]):
            for k, m in enumerate([0, 4, 7, 12, 16, 19]):
                place(L, glock(tonic + 24 + m if scale is MAJOR else tonic + 24 + [0, 3, 7, 12, 15, 19][k], 0.3, 0.1 + 0.015 * k), t0 - beat + k * beat / 6)

    y = room(L)
    tail = int(SR * 1.5)
    y[-tail:] *= np.linspace(1, 0, tail)
    y *= 10 ** (PEAK_DB / 20) / np.max(np.abs(y))
    return y


def write_ogg(y, out):
    with tempfile.TemporaryDirectory() as tmp:
        wav = pathlib.Path(tmp) / "song.wav"
        with wave.open(str(wav), "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes((np.clip(y, -1, 1) * 32767).astype(np.int16).tobytes())
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(wav),
                        "-c:a", "libvorbis", "-q:a", "4", str(out)], check=True)


def entry(song):
    beat = 60.0 / song["bpm"]
    nbars = sum(len(s["bars"]) for s in song["sections"])
    bars, gogo, b = [], [], 0
    for s in song["sections"]:
        start = bar_start(song, b)
        for _ in s["bars"]:
            bars.append(round(bar_start(song, b), 4))
            b += 1
        if s["gogo"]:
            gogo.append([round(start, 4), round(bar_start(song, b), 4)])
    hard = chart_hard(song)
    charts = [pack(thin(song, hard, lv)) for lv in range(3)]
    return {
        "id": song["id"], "title": song["title"], "bpm": song["bpm"],
        "file": f"res://assets/sfx/drumbeat/song_{song['id']}.ogg",
        "length": round((1 + nbars) * 4 * beat + 1.0, 3),
        "beat": round(beat, 6), "bars": bars, "gogo": gogo,
        "stars": song["stars"], "charts": charts,
    }


def main():
    want = sys.argv[1:] or [s["id"] for s in SONGS] + ["drums"]
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    if "drums" in want:
        # the player's own drum, synthesised rather than generated: it plays
        # on every stroke over the song, so it must start on its first
        # sample and be as loud as the music
        for name, y in (("don", normal(don(), -1.0)), ("ka", normal(ka(), -4.5))):
            out = OUT_DIR / f"{name}.ogg"
            write_ogg(y, out)
            print(f"drum -> {out.relative_to(ROOT)}")
    entries = [entry(s) for s in SONGS]
    CHART_OUT.write_text(json.dumps({"songs": entries}, separators=(",", ":")) + "\n")
    for e in entries:
        counts = [sum(1 for n in c if n[1] < ROLL) for c in e["charts"]]
        print(f"{e['id']}: {e['length']:.1f} s, notes easy/normal/hard {counts}")
    print(f"charts -> {CHART_OUT.relative_to(ROOT)}")
    for s in SONGS:
        if s["id"] in want:
            out = OUT_DIR / f"song_{s['id']}.ogg"
            write_ogg(render(s), out)
            print(f"music -> {out.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
