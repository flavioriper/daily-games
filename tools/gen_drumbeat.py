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


# --- the player's four drums (2026-10-01): soft felt and hand strokes, warm,
# nothing that cracks. Each lane has its own, so the four read by ear too:
# low to high, left to right, like the lanes. ---


def lowpass(y, k):
    return np.convolve(y, np.ones(k) / k, mode="same")


def drum_big():
    # the big drum: a felt beater on a wide skin, a round low boom that
    # settles a little in pitch, a soft thump and no click
    n = int(SR * 0.6)
    t = np.arange(n) / SR
    f = 72 + 38 * np.exp(-t / 0.03)
    ph = 2 * np.pi * np.cumsum(f) / SR
    y = (np.sin(ph) * env(n, 0.002, 0.2)
         + 0.3 * np.sin(1.5 * ph) * env(n, 0.002, 0.07)
         + 0.12 * np.sin(2.2 * ph) * env(n, 0.002, 0.035))
    k = int(SR * 0.015)
    thump = lowpass(np.random.default_rng(31).standard_normal(k), 40)
    y[:k] += 1.6 * thump * np.linspace(1, 0, k)
    return np.tanh(1.3 * y)


def drum_hand():
    # the hand drum: a palm on a goatskin, a warm open tone that rings a
    # moment, the skin's slap underneath
    n = int(SR * 0.4)
    t = np.arange(n) / SR
    f = 190 + 60 * np.exp(-t / 0.012)
    ph = 2 * np.pi * np.cumsum(f) / SR
    y = (np.sin(ph) * env(n, 0.0015, 0.11)
         + 0.42 * np.sin(1.68 * ph) * env(n, 0.0015, 0.05)
         + 0.2 * np.sin(2.4 * ph) * env(n, 0.0015, 0.025))
    k = int(SR * 0.01)
    slap = lowpass(np.random.default_rng(32).standard_normal(k), 8)
    y[:k] += 1.0 * slap * np.linspace(1, 0, k)
    return np.tanh(1.2 * y)


def drum_frame():
    # the frame drum with little jingles: a soft thump of the fingers and a
    # short shimmer of brass discs, rolled off so it never hisses
    n = int(SR * 0.42)
    t = np.arange(n) / SR
    f = 150 + 40 * np.exp(-t / 0.01)
    ph = 2 * np.pi * np.cumsum(f) / SR
    body = np.sin(ph) * env(n, 0.002, 0.06)
    rng = np.random.default_rng(33)
    jingle = np.zeros(n)
    for j, (fr, at) in enumerate([(4200, 0.0), (5100, 0.006), (3700, 0.013), (4700, 0.021)]):
        i = int(at * SR)
        m = n - i
        tt = np.arange(m) / SR
        jingle[i:] += np.sin(2 * np.pi * fr * tt + rng.random() * 6) * np.exp(-tt / 0.07) * (0.5 + 0.5 * rng.random())
    jingle = lowpass(jingle, 3)
    return np.tanh(1.1 * (0.9 * body + 0.22 * jingle))


def drum_block():
    # the wooden tongue drum: a mallet on a hollow box, a round woody tock
    # with a little pitch, the friendliest of the four
    n = int(SR * 0.3)
    t = np.arange(n) / SR
    y = (np.sin(2 * np.pi * 620 * t) * env(n, 0.001, 0.06)
         + 0.45 * np.sin(2 * np.pi * 1550 * t) * env(n, 0.001, 0.02)
         + 0.25 * np.sin(2 * np.pi * 310 * t) * env(n, 0.001, 0.04))
    k = int(SR * 0.003)
    knock = lowpass(np.random.default_rng(34).standard_normal(k), 4)
    y[:k] += 0.5 * knock * np.linspace(1, 0, k)
    return np.tanh(1.2 * y)


DRUMS = [("drum_0", drum_big, -1.5), ("drum_1", drum_hand, -3.0), ("drum_2", drum_frame, -4.5), ("drum_3", drum_block, -4.5)]



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
#
# A day's song is short (the user's word, 2026-10-03: twenty to thirty seconds
# at most): a bar of pick-up, a verse, a Go-Go chorus and a last chord. Echo
# pairs its bars from the first of the verse (`echo_from`).

def S(chords, tunes, charts, gogo=False):
    assert len(chords) == len(tunes) == len(charts)
    for c in charts:
        assert len(c) == 16, f"chart bar is {len(c)} long: {c}"
    return {"bars": list(zip(chords, tunes, charts)), "gogo": gogo}


def half(section):
    """A section's second four bars: the phrase that closes it."""
    return tuple(part[4:] for part in section)


REST = "-:8"
EMPTY = "................"

PARADE = {
    "id": "parade", "title": "Garden Parade", "bpm": 112, "tonic": 65, "scale": MAJOR,
    "lead": "marimba", "stars": [1, 3, 5], "style": "parade",
}
PARADE["sections"] = [
    S(["C"], [REST], ["d.......d......."]),
    S(["F", "Bb", "Bb", "F"],
      ["1:2 3:2 5:2 5:2", "6:2 5:2 3:4", "4:2 4:2 6:2 4:2", "3:2 2:2 1:4"],
      ["d.kkd.k.d...d.k.", "d...k...D...k.k.", "d.d.k.kkd.d.k...", "k...k...D...k.k."]),
    S(["F", "C", "Bb", "F"],
      ["1':2 1':1 1':1 7:2 6:2", "5:2 1':2 2':4", "1':2 7:2 6:2 7:2", "1':6 -:2"],
      ["d...d.d.k...k...", "d...d...D...d.d.", "d.k.d.k.d.k.d.k.", "D.......R=====.."], gogo=True),
    S(["F"], ["1:8"], ["D..............."]),
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
    S(["A"], ["5:8"], ["d...d...d...D..."]),
    S(*half(_FA)),
    S(*half(_FC), gogo=True),
    S(["D"], ["1':8"], ["D..............."]),
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
        "d.ddd.ddd.k.k.k.", "D...d.k.D...k.k.", "d.k.d.k.d...D...", "D.......b=====.."])
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
    S(["E"], [REST], ["d...d...d.ddD..."]),
    S(*_GA),
    S(*half(_GC), gogo=True),
    S(["Am"], ["1':8"], ["D..............."]),
]

SONGS = [PARADE, FESTIVAL, GALLOP]

# Note types, as puzzles/drumbeat_state.gd reads them.
TAP, HOLD, ROLL, BALLOON = range(4)
# The drums standing at each level (the user's word, 2026-10-03: one, two,
# three and three), and the drums the tune is played on: with three the big
# drum keeps the kick and the bass to itself.
DRUM_COUNT = [1, 2, 3, 3]


def tune_lanes(nd):
    return [0] if nd == 1 else [0, 1] if nd == 2 else [1, 2]


# Hits a second a balloon asks for, by difficulty.
BALLOON_RATE = [4.0, 5.5, 7.5, 7.5]
# A melody note this many beats long or longer is held, by difficulty.
HOLD_BEATS = [2.0, 1.5, 1.5, 1.5]
# The least gap between any two notes, and between two on one drum, in beats.
# A note too close to the last on its drum steps to the next drum over
# (the two fingers trade), or is dropped when that one is busy too.
MIN_GAP = [1.0, 0.5, 0.25, 0.25]
SAME_GAP = [1.0, 0.5, 0.5, 0.5]
# Easy takes two beats between notes when a beat is quicker than this.
EASY_SECONDS = 0.5


def bar_start(song, i):
    beat = 60.0 / song["bpm"]
    return (1 + i) * 4 * beat  # bar 0 of the music follows one bar of count-in


# --- what the music plays, bar by bar ---
# The arrangement is written once as events, and both the music and the
# charts are made from those same events: a note on the chart is a note the
# player can hear, at the sample it sounds.

def bar_events(song, i, bars, gogo_bar):
    beat = 60.0 / song["bpm"]
    eighth = beat / 2.0
    ch, tune, _ = bars[i]
    t0 = bar_start(song, i)
    go = gogo_bar[i]
    halves = ch if isinstance(ch, list) else [ch, ch]
    last = i == len(bars) - 1
    tonic, scale, style = song["tonic"], song["scale"], song["style"]
    out = []

    def ev(at, inst, m=None, dur=0.0, vel=1.0, part="back", seed=0):
        out.append({"t": at, "s": round((at - t0) / (beat / 4.0), 4), "inst": inst, "m": m,
                    "dur": dur, "vel": vel, "part": part, "seed": seed})

    for at, m, d in melody(tune, tonic, scale):
        if m is None:
            continue
        accent = 1.0 if at % 2 == 0 else 0.85
        ev(t0 + at * eighth, "lead", m, d * eighth, accent, "lead")
    if last:
        root, triad = chord(halves[0])
        ev(t0, "bass", root - 12, 3 * beat, 0.6)
        for m in triad:
            ev(t0, "marimba", m, 3 * beat, 0.22)
        return out
    for h, name in enumerate(halves):
        root, triad = chord(name)
        th = t0 + h * 2 * beat
        if style == "parade":
            ev(th, "bass", root - 12, beat, 0.5)
            ev(th + beat, "bass", root - 5, beat, 0.35)
            for off in (0.5, 1.5):
                for m in triad:
                    ev(th + off * beat, "kalimba", m, 0.4 * beat, 0.11)
        elif style == "festival":
            for q in range(2):
                ev(th + q * beat, "bass", root - 12, beat * 0.9, 0.48 if q == 0 else 0.36)
            for k, m in enumerate(triad + [triad[0] + 12]):
                ev(th + k * eighth, "koto", m, 0.5 * beat, 0.16)
        else:
            for q in range(2):
                b0 = th + q * beat
                ev(b0, "bass", root - 12, eighth, 0.5)
                ev(b0 + eighth, "bass", root - 12, eighth / 2, 0.34)
                ev(b0 + eighth * 1.5, "bass", root, eighth / 2, 0.34)
                for m in triad:
                    ev(b0 + eighth, "kalimba", m + 12, 0.2 * beat, 0.07)
    for q in range(4):
        tq = t0 + q * beat
        if q in (0, 2) or (go and style != "parade"):
            ev(tq, "kick", None, 0.0, 0.55 if q == 0 else 0.42)
        ev(tq + eighth, "shaker", None, 0.0, 0.05 if go else 0.035, seed=i * 8 + q)
        if go:
            ev(tq, "shaker", None, 0.0, 0.03, seed=i * 8 + q + 400)
            if q in (1, 3):
                ev(tq, "clap", None, 0.0, 0.14, seed=i * 4 + q)
    if go and (i == 0 or not gogo_bar[i - 1]):
        steps = [0, 4, 7, 12, 16, 19] if scale is MAJOR else [0, 3, 7, 12, 15, 19]
        for k, m in enumerate(steps):
            ev(t0 - beat + k * beat / 6, "sparkle", tonic + 24 + m, 0.3, 0.1 + 0.015 * k)
    return out


def all_bars(song):
    bars = [b for s in song["sections"] for b in s["bars"]]
    gogo_bar = [s["gogo"] for s in song["sections"] for _ in s["bars"]]
    section = [k for k, s in enumerate(song["sections"]) for _ in s["bars"]]
    return bars, gogo_bar, section


def render(song):
    """The backing and the lead, as two stems the same length: the lead (the
    tune) dips when the player lets a note pass, so it is its own file."""
    beat = 60.0 / song["bpm"]
    bars, gogo_bar, _ = all_bars(song)
    length = (1 + len(bars)) * 4 * beat + 2.5
    back = np.zeros(int(SR * length))
    lead = np.zeros(int(SR * length))
    for k in range(4):
        place(back, wood(84 if k == 0 else 79, 0.5), k * beat)
    for i in range(len(bars)):
        for e in bar_events(song, i, bars, gogo_bar[:]):
            m, d, v, at = e["m"], e["dur"], e["vel"], e["t"]
            inst = e["inst"]
            if inst == "lead":
                if song["lead"] == "flute":
                    place(lead, flute(m + 12, d * 0.95, 0.32 * v), at)
                    if gogo_bar[i]:
                        place(lead, glock(m + 12, d, 0.1 * v), at)
                else:
                    place(lead, marimba(m, d, 0.5 * v), at)
                    place(lead, glock(m + 12, d, (0.2 if gogo_bar[i] else 0.13) * v), at)
            elif inst == "bass":
                place(back, bass(m, d, v), at)
            elif inst == "marimba":
                place(back, marimba(m, d, v), at)
            elif inst == "kalimba":
                place(back, kalimba(m, d, v), at)
            elif inst == "koto":
                place(back, koto(m, d, v), at)
            elif inst == "kick":
                place(back, kick(v), at)
            elif inst == "shaker":
                place(back, shaker(v, seed=e["seed"]), at)
            elif inst == "clap":
                place(back, clap(v, seed=e["seed"]), at)
            elif inst == "sparkle":
                place(back, glock(m, d, v), at)
    back, lead = room(back), room(lead)
    tail = int(SR * 1.5)
    fade = np.linspace(1, 0, tail)
    back[-tail:] *= fade
    lead[-tail:] *= fade
    k = 10 ** (PEAK_DB / 20) / np.max(np.abs(back + lead))
    return back * k, lead * k


def calib_track():
    """The tap-along that tunes a phone's timing: a soft wood block every
    CALIB_GAP seconds, the first of each four a little higher."""
    n = int(SR * (CALIB_AT + CALIB_GAP * CALIB_CLICKS + 1.0))
    y = np.zeros(n)
    clicks = []
    for k in range(CALIB_CLICKS):
        at = CALIB_AT + k * CALIB_GAP
        place(y, wood(84 if k % 4 == 0 else 79, 0.7), at)
        clicks.append(round(at, 4))
    return normal(room(y, 0.1), -3.0), clicks


CALIB_AT = 1.0
CALIB_GAP = 0.6
CALIB_CLICKS = 12


# --- the charts ---

def sixteenths(beats):
    return beats * 4.0


def spans(song):
    """The drumrolls and balloons the hand-written chart lines hold:
    [(t, end, kind)] -- the only thing still read from them."""
    beat = 60.0 / song["bpm"]
    sixteenth = beat / 4.0
    bars, _, _ = all_bars(song)
    out = []
    for b, (_, _, line) in enumerate(bars):
        t0 = bar_start(song, b)
        i = 0
        while i < 16:
            c = line[i]
            if c in "rRb":
                j = i + 1
                while j < 16 and line[j] == "=":
                    j += 1
                out.append((t0 + i * sixteenth, t0 + j * sixteenth, c))
                i = j
                continue
            i += 1
    return out


def lane_bands(song, lanes):
    """Each section's tune split into bands of pitch, low to high, one for
    each of the drums in `lanes`."""
    bars, gogo_bar, section = all_bars(song)
    pitches = {}
    for i in range(len(bars)):
        for e in bar_events(song, i, bars, gogo_bar):
            if e["inst"] == "lead":
                pitches.setdefault(section[i], []).append(e["m"])
    bands = {}
    k = len(lanes)
    for s, ps in pitches.items():
        u = sorted(set(ps))
        # the sorted distinct pitches in runs as even as can be
        bands[s] = {m: lanes[min(k - 1, idx * k // len(u))] for idx, m in enumerate(u)}
    return bands


def chart(song, level):
    """One level's chart, for the drums that level has: the tune's notes on
    its drums by pitch, the kick on drum 0, rolls and balloons where the
    hand-written lines put them, and on Hard the backing's own strokes in the
    tune's rests. Every note is an onset in the music."""
    beat = 60.0 / song["bpm"]
    bars, gogo_bar, section = all_bars(song)
    nd = DRUM_COUNT[level]
    tl = tune_lanes(nd)
    bands = lane_bands(song, tl)
    lv = min(level, 2)
    grid = [4.0, 2.0, 1.0][lv]  # sixteenths: Easy on the beat, Medium the eighths
    long_spans = spans(song)
    gap = MIN_GAP[lv] * beat
    same = SAME_GAP[lv] * beat
    if lv == 0 and beat < EASY_SECONDS:
        gap = same = 2.0 * beat

    def in_span(t):
        for a, z, _ in long_spans:
            if a - beat * 0.25 - 1e-6 <= t <= z + beat * 0.5:
                return True
        return False

    cands = []  # (t, lane, type, end, priority)
    for i in range(len(bars)):
        evs = bar_events(song, i, bars, gogo_bar)
        lead = sorted([e for e in evs if e["inst"] == "lead"], key=lambda e: e["t"])
        first_of_section = i == 0 or section[i] != section[i - 1]
        for e in lead:
            if abs(e["s"] / grid - round(e["s"] / grid)) > 1e-3:
                continue
            lane = bands[section[i]].get(e["m"], tl[-1])
            if e["dur"] >= HOLD_BEATS[lv] * beat - 1e-6:
                cands.append((e["t"], lane, HOLD, e["t"] + e["dur"] - beat * 0.5, 3))
            else:
                cands.append((e["t"], lane, TAP, 0.0, 3))
        lead_at = {round(e["s"], 3) for e in lead}
        for e in evs:
            if e["inst"] != "kick":
                continue
            if abs(e["s"] / grid - round(e["s"] / grid)) > 1e-3:
                continue
            with_tune = round(e["s"], 3) in lead_at
            if lv == 0:
                # Easy: the kick on the bar's first beat, when the tune is quiet there
                if e["s"] == 0 and not with_tune:
                    cands.append((e["t"], 0, TAP, 0.0, 2))
            elif lv == 1:
                # Medium: the kick where the tune rests; with it only into a section
                if not with_tune or (e["s"] == 0 and first_of_section):
                    cands.append((e["t"], 0, TAP, 0.0, 2))
            else:
                cands.append((e["t"], 0, TAP, 0.0, 2))
        if lv >= 1:
            # the backing's strokes fill the tune's rests: Medium the bass on
            # drum 0; Hard the chord stabs and the koto too, on drums 2 and 3
            # by turns
            busy = []
            for e in lead:
                busy.append((e["t"] - 1e-6, e["t"] + max(e["dur"], beat * 0.5)))
            # one stroke an instant, on the eighths, never over the kick
            kicks = {round(e["s"], 3) for e in evs if e["inst"] == "kick"}
            seen = set()
            k = 0
            for e in sorted(evs, key=lambda e: e["t"]):
                if e["inst"] not in (("bass", "kalimba", "koto") if lv == 2 else ("bass",)):
                    continue
                at = round(e["s"], 3)
                if at in seen or at in kicks or abs(at / 2.0 - round(at / 2.0)) > 1e-3:
                    continue
                if any(a <= e["t"] < z for a, z in busy):
                    continue
                seen.add(at)
                lane = 0 if e["inst"] == "bass" else tl[k % len(tl)]
                if e["inst"] != "bass":
                    k += 1
                cands.append((e["t"], lane, TAP, 0.0, 1))
    # one candidate per instant and drum, the higher priority first
    cands.sort(key=lambda c: (round(c[0], 4), -c[4], c[1]))
    notes = []
    last_on = [-10.0] * nd
    last_any = -10.0
    last_t = -10.0
    for t, lane, typ, end, pri in cands:
        if in_span(t):
            continue
        chord_ok = abs(t - last_t) < 1e-4
        if chord_ok:
            # a second drum at the same instant: Hard any time, Medium into a
            # section, Easy never
            if lv == 0 or (lv == 1 and pri != 2):
                continue
            if any(abs(n["t"] - t) < 1e-4 and n["lane"] == lane for n in notes):
                continue
            if sum(1 for n in notes if abs(n["t"] - t) < 1e-4) >= 2:
                continue
        elif t - last_any < gap - 1e-6:
            continue
        # a drum still held, or struck too lately, passes the note to a neighbour
        def free(l):
            if t - last_on[l] < same - 1e-6:
                return False
            for n in notes:
                if n["lane"] == l and n["type"] == HOLD and n["t"] < t <= n["end"] + beat * 0.25:
                    return False
            return not any(abs(n["t"] - t) < 1e-4 and n["lane"] == l for n in notes)
        if not free(lane):
            alt = [l for l in (lane - 1, lane + 1) if 0 <= l < nd and (l != 0 or nd < 3)]
            alt = [l for l in alt if free(l)]
            if not alt:
                continue
            lane = alt[0]
        # nothing struck while a hold is held on another drum, below Hard
        if lv < 2 and any(n["type"] == HOLD and n["t"] < t < n["end"] for n in notes):
            continue
        n = {"t": t, "lane": lane, "type": typ}
        if typ == HOLD:
            n["end"] = end
        notes.append(n)
        last_on[lane] = t
        last_any = t
        last_t = t
    for a, z, kind in long_spans:
        if kind == "b":
            notes.append({"t": a, "lane": min(1, nd - 1), "type": BALLOON, "end": z,
                          "count": max(3, int(round((z - a) * BALLOON_RATE[level])))})
        else:
            notes.append({"t": a, "lane": 0 if kind == "R" else nd - 1, "type": ROLL, "end": z})
    notes.sort(key=lambda n: (n["t"], n["lane"]))
    return notes


def echo(song, hard):
    """Insane is Echo: the bars go in pairs, and the second of each pair
    plays the first again -- with its notes hidden. Read it, play it, then
    play it back from memory: the screen lets the tune step aside under a
    hidden bar, so the player hears the backing and their own drums. A long
    note running out of its bar is cut at the bar line; a pair whose second
    bar holds a drumroll or a balloon is played as Hard plays it."""
    beat = 60.0 / song["bpm"]
    bars, _, _ = all_bars(song)
    bar_len = 4 * beat
    out, spans_ = [], []
    first = song.get("echo_from", 1)
    pairs = range(first, len(bars) - 1, 2)
    # the pick-up before the first pair and whatever follows the last are
    # played as Hard plays them
    lo = bar_start(song, first)
    hi = bar_start(song, pairs[-1] + 2) if len(pairs) else lo
    out.extend(dict(n) for n in hard if n["t"] < lo - 1e-6 or n["t"] >= hi - 1e-6)
    for k in pairs:
        a = bar_start(song, k)
        b = a + bar_len
        call = [dict(n) for n in hard if a - 1e-6 <= n["t"] < b - 1e-6]
        second = [dict(n) for n in hard if b - 1e-6 <= n["t"] < b + bar_len - 1e-6]
        if not call or any(n["type"] in (ROLL, BALLOON) for n in second):
            # a drumroll or a balloon in the second bar: the pair is played
            # as Hard plays it, so Insane keeps its long notes
            out.extend(call)
            out.extend(second)
            continue
        for n in call:
            if "end" in n:
                n["end"] = min(n["end"], b - beat * 0.25)
                if n["end"] <= n["t"] + beat * 0.25:
                    n.pop("end")
                    n.pop("count", None)
                    n["type"] = TAP
            out.append(n)
            e = dict(n)
            e["t"] = n["t"] + bar_len
            if "end" in e:
                e["end"] = n["end"] + bar_len
            e["hidden"] = 1
            out.append(e)
        spans_.append([round(b, 4), round(b + bar_len, 4)])
    out.sort(key=lambda n: (n["t"], n["lane"]))
    return out, spans_


def pack(notes):
    """[t, lane, type, end, count, hidden] a note."""
    return [[round(n["t"], 4), n["lane"], n["type"], round(n.get("end", 0.0), 4), n.get("count", 0), n.get("hidden", 0)]
            for n in notes]


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
    charts = [chart(song, lv) for lv in range(3)]
    insane, echoes = echo(song, chart(song, 3))
    charts.append(insane)
    return {
        "id": song["id"], "title": song["title"], "bpm": song["bpm"],
        "file": f"res://assets/sfx/drumbeat/song_{song['id']}.ogg",
        "lead": f"res://assets/sfx/drumbeat/lead_{song['id']}.ogg",
        "length": round((1 + nbars) * 4 * beat + 1.0, 3),
        "beat": round(beat, 6), "bars": bars, "gogo": gogo, "echo": echoes,
        "stars": song["stars"], "charts": [pack(c) for c in charts],
    }


def write_wav_ogg(y, out):
    write_ogg(y, out)


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


def main():
    want = sys.argv[1:] or [s["id"] for s in SONGS] + ["drums", "calib"]
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    if "drums" in want:
        # the player's own drums, synthesised rather than generated: they play
        # on every stroke over the song, so each starts on its first sample
        for name, fn, db in DRUMS:
            out = OUT_DIR / f"{name}.ogg"
            write_ogg(normal(fn(), db), out)
            print(f"drum -> {out.relative_to(ROOT)}")
    clicks = calib_track()[1]
    if "calib" in want:
        y, _ = calib_track()
        write_ogg(y, OUT_DIR / "calib.ogg")
        print("calib -> assets/sfx/drumbeat/calib.ogg")
    entries = [entry(s) for s in SONGS]
    CHART_OUT.write_text(json.dumps({"songs": entries, "calib": {
        "file": "res://assets/sfx/drumbeat/calib.ogg", "clicks": clicks}}, separators=(",", ":")) + "\n")
    for e in entries:
        counts = [len(c) for c in e["charts"]]
        print(f"{e['id']}: {e['length']:.1f} s, notes easy/medium/hard/insane {counts}")
    print(f"charts -> {CHART_OUT.relative_to(ROOT)}")
    for s in SONGS:
        if s["id"] in want:
            back, lead = render(s)
            write_ogg(back, OUT_DIR / f"song_{s['id']}.ogg")
            write_ogg(lead, OUT_DIR / f"lead_{s['id']}.ogg")
            print(f"music -> song_{s['id']}.ogg + lead_{s['id']}.ogg")


if __name__ == "__main__":
    main()
