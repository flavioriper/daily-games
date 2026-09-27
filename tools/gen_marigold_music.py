#!/usr/bin/env python3
"""Marigold's full-bloom music: Beethoven's Ode to Joy (public domain),
arranged in the house's own instruments and synthesised here, note by note.

    python3 tools/gen_marigold_music.py

Writes assets/sfx/marigold/music.ogg, which puzzles/marigold2d.gd plays once
when the last marigold blooms. Melody on marimba doubled by a glockenspiel an
octave up, kalimba chords on the off-beats, a plucked bass on the beats, a
soft timpani roll into the first bar and a held chord at the end, through a
small room. Needs numpy and ffmpeg on the PATH.
"""
import pathlib, subprocess, tempfile, wave
import numpy as np

ROOT = pathlib.Path(__file__).resolve().parent.parent
SR = 44100
BPM = 148.0
BEAT = 60.0 / BPM
PEAK_DB = -3.0

# The tune in D, MIDI pitches with lengths in beats.
A = [(66, 1), (66, 1), (67, 1), (69, 1), (69, 1), (67, 1), (66, 1), (64, 1),
     (62, 1), (62, 1), (64, 1), (66, 1)]
PHRASE_1 = A + [(66, 1.5), (64, 0.5), (64, 2)]
PHRASE_2 = A + [(64, 1.5), (62, 0.5), (62, 2)]
PHRASE_B = [(64, 1), (64, 1), (66, 1), (62, 1),
            (64, 1), (66, 0.5), (67, 0.5), (66, 1), (62, 1),
            (64, 1), (66, 0.5), (67, 0.5), (66, 1), (64, 1),
            (62, 1), (64, 1), (57, 2)]
TUNE = PHRASE_1 + PHRASE_2 + PHRASE_B + PHRASE_2

# One chord a half bar (two beats), as root and triad.
D, G, Aa, E, Bm = (50, [62, 66, 69]), (55, [62, 67, 71]), (45, [61, 64, 69]), (52, [64, 68, 71]), (47, [62, 66, 71])
CHORDS_1 = [D, D, D, Aa, D, Aa, Aa, Aa]
CHORDS_2 = [D, D, D, Aa, D, Aa, Aa, D]
CHORDS_B = [Aa, D, Aa, D, Aa, E, Aa, Aa]
CHORDS = CHORDS_1 + CHORDS_2 + CHORDS_B + CHORDS_2

INTRO = 2.0  # beats: the timpani roll and a glockenspiel run up into bar one
OUTRO = 6.0  # beats: the last chord ringing out


def hz(m):
    return 440.0 * 2.0 ** ((m - 69) / 12.0)


def env(n, attack, decay):
    t = np.arange(n) / SR
    a = np.minimum(1.0, t / attack) if attack > 0 else 1.0
    return a * np.exp(-t / decay)


def marimba(m, dur, vel=1.0):
    f = hz(m)
    n = int(SR * (dur + 1.2))
    t = np.arange(n) / SR
    # a marimba bar: the fundamental, its tuned fourth partial, a whisper of the tenth
    y = (np.sin(2 * np.pi * f * t) * env(n, 0.003, 0.55 if f < 300 else 0.4)
         + 0.28 * np.sin(2 * np.pi * f * 3.93 * t) * env(n, 0.001, 0.06)
         + 0.06 * np.sin(2 * np.pi * f * 9.2 * t) * env(n, 0.001, 0.02))
    # the mallet's soft knock
    k = int(SR * 0.012)
    y[:k] += 0.15 * np.random.default_rng(m).standard_normal(k) * np.linspace(1, 0, k)
    return vel * y


def glock(m, dur, vel=1.0):
    f = hz(m)
    n = int(SR * (dur + 2.0))
    t = np.arange(n) / SR
    y = (np.sin(2 * np.pi * f * t) * env(n, 0.001, 0.9)
         + 0.35 * np.sin(2 * np.pi * f * 2.76 * t) * env(n, 0.001, 0.25)
         + 0.12 * np.sin(2 * np.pi * f * 5.40 * t) * env(n, 0.001, 0.08))
    return vel * y


def kalimba(m, dur, vel=1.0):
    f = hz(m)
    n = int(SR * (dur + 0.8))
    t = np.arange(n) / SR
    y = (np.sin(2 * np.pi * f * t) * env(n, 0.002, 0.35)
         + 0.2 * np.sin(2 * np.pi * f * 5.95 * t) * env(n, 0.001, 0.03))
    return vel * y


def bass(m, dur, vel=1.0):
    f = hz(m)
    n = int(SR * (dur + 0.5))
    t = np.arange(n) / SR
    y = (np.sin(2 * np.pi * f * t) + 0.35 * np.sin(2 * np.pi * 2 * f * t)
         + 0.1 * np.sin(2 * np.pi * 3 * f * t)) * env(n, 0.004, 0.32)
    return vel * y


def timpani(m, dur, vel=1.0, roll=0.0):
    f = hz(m)
    n = int(SR * (dur + 1.5))
    t = np.arange(n) / SR
    body = np.sin(2 * np.pi * f * t) + 0.5 * np.sin(2 * np.pi * f * 1.5 * t) + 0.25 * np.sin(2 * np.pi * f * 1.99 * t)
    if roll > 0:
        # a soft felt roll swelling for `roll` seconds, then the stroke
        rng = np.random.default_rng(7)
        shiver = 0.75 + 0.25 * np.abs(np.sin(2 * np.pi * 14.0 * t))
        grow = np.clip(t / roll, 0, 1) ** 1.6
        y = body * shiver * grow * (t < roll) * 0.8
        y += 0.06 * rng.standard_normal(n) * grow * (t < roll)
        k = t >= roll
        y[k] += body[k] * np.exp(-(t[k] - roll) / 0.7)
        return vel * y
    return vel * body * env(n, 0.005, 0.7)


def place(buf, y, at):
    i = int(at * SR)
    j = min(len(buf), i + len(y))
    if j > i:
        buf[i:j] += y[: j - i]


def room(x):
    # a small warm room: an exponentially decaying noise tail, low-passed
    n = int(SR * 1.4)
    rng = np.random.default_rng(3)
    ir = rng.standard_normal(n) * np.exp(-np.arange(n) / (SR * 0.35))
    ir = np.convolve(ir, np.ones(12) / 12, mode="same")
    ir[0] = 0.0
    ir /= np.sqrt(np.sum(ir ** 2))
    size = 1 << int(np.ceil(np.log2(len(x) + n)))
    wet = np.fft.irfft(np.fft.rfft(x, size) * np.fft.rfft(ir, size), size)[: len(x)]
    return x + 0.22 * wet


def render():
    total = sum(d for _, d in TUNE)
    length = (INTRO + total + OUTRO) * BEAT + 2.0
    L = np.zeros(int(SR * length))

    # the intro: a timpani roll on A up into the downbeat, a glockenspiel run
    place(L, timpani(45, 0.5, 0.55, roll=INTRO * BEAT), 0.0)
    run = [62, 64, 66, 67, 69, 71, 73, 74]
    for k, m in enumerate(run):
        place(L, glock(m + 12, 0.2, 0.25 + 0.03 * k), (INTRO - 1.0) * BEAT + k * BEAT / len(run))

    start = INTRO * BEAT
    at = start
    for k, (m, d) in enumerate(TUNE):
        vel = 1.0 if (at - start) / BEAT % 4 == 0 else 0.85
        place(L, marimba(m, d * BEAT, 0.55 * vel), at)
        place(L, glock(m + 12, d * BEAT, 0.16 * vel), at)
        at += d * BEAT

    for k, (root, triad) in enumerate(CHORDS):
        t0 = start + k * 2 * BEAT
        place(L, bass(root - 12 if root > 50 else root, BEAT, 0.5), t0)
        place(L, bass(root - 12 if root > 50 else root, BEAT, 0.35), t0 + BEAT)
        for off in (0.5, 1.5):
            for m in triad:
                place(L, kalimba(m, 0.4 * BEAT, 0.12), t0 + off * BEAT)
        if k % 8 == 0:
            place(L, timpani(root - 12 if root > 50 else root, BEAT, 0.3), t0)

    # the end: the tonic, rung out on everything, with a last glockenspiel sparkle
    end = start + total * BEAT
    place(L, timpani(38, 2 * BEAT, 0.55), end)
    place(L, bass(38, 3 * BEAT, 0.6), end)
    for m in [62, 66, 69, 74]:
        place(L, marimba(m, 3 * BEAT, 0.3), end)
        place(L, kalimba(m + 12, 2 * BEAT, 0.12), end + 0.03)
    for k, m in enumerate([74, 78, 81, 86]):
        place(L, glock(m, BEAT, 0.14), end + 0.25 * BEAT + k * 0.07)

    y = room(L)
    # fade the ring-out to silence
    tail = int(SR * 1.5)
    y[-tail:] *= np.linspace(1, 0, tail)
    y *= 10 ** (PEAK_DB / 20) / np.max(np.abs(y))
    return y


def main():
    y = render()
    out = ROOT / "assets/sfx/marigold/music.ogg"
    with tempfile.TemporaryDirectory() as tmp:
        wav = pathlib.Path(tmp) / "music.wav"
        with wave.open(str(wav), "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes((y * 32767).astype(np.int16).tobytes())
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(wav),
                        "-c:a", "libvorbis", "-q:a", "5", str(out)], check=True)
    print(f"music -> {out.relative_to(ROOT)} ({len(y) / SR:.1f} s)")


if __name__ == "__main__":
    main()
