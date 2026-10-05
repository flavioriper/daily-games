#!/usr/bin/env python3
"""Marigold's full-bloom music: Beethoven's Ode to Joy (public domain), played
on a real kalimba, a music box and a bass kalimba.

    python3 tools/gen_sfx.py marigold note_kalimba note_box note_low   # once
    python3 tools/gen_marigold_music.py

Writes assets/sfx/marigold/music.ogg, which puzzles/marigold2d.gd plays once
when the last marigold blooms. The tune has to be exact, so it is sequenced
here rather than prompted -- but nothing is synthesised (2026-10-05; until
then every note was a sum of sines): each instrument is one recorded note
from ElevenLabs (assets/sfx/marigold/note_*.ogg, the same POND_TUNE family as
the board's cues), its pitch measured and the note played at each pitch of
the score by resampling, the way a sampler does. Melody on the kalimba
doubled by the music box above, kalimba chords on the off-beats, the bass
kalimba on the beats, a music box run up into the first bar and a held chord
at the end, through a small room. Needs numpy and ffmpeg on the PATH.
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

INTRO = 2.0  # beats: a low note and a music box run up into bar one
OUTRO = 6.0  # beats: the last chord ringing out


def hz(m):
    return 440.0 * 2.0 ** ((m - 69) / 12.0)


def midi(f):
    return 69.0 + 12.0 * np.log2(f / 440.0)


def load(name):
    """One recorded note as mono float samples, cut to a single note if the
    take came back with two, and the pitch it sounds at."""
    path = ROOT / f"assets/sfx/marigold/{name}.ogg"
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", str(path), "-f", "f32le",
                          "-ac", "1", "-ar", str(SR), "-"], capture_output=True, check=True).stdout
    y = np.frombuffer(raw, dtype=np.float32).astype(np.float64)
    y /= np.max(np.abs(y))
    # from the pluck itself: the silence left before it would be stretched
    # with the note, and a low part would come in late
    y = y[max(0, int(np.argmax(np.abs(y) > 0.05)) - int(SR * 0.002)):]
    # a second onset: the level climbing 9 dB back out of its own decay
    hop = int(SR * 0.005)
    level = np.array([np.sqrt(np.mean(y[i:i + hop] ** 2)) for i in range(0, len(y) - hop, hop)])
    db = 20 * np.log10(level + 1e-9)
    onsets = [k for k in range(24, len(db)) if db[k] > -30 and db[k] - np.min(db[k - 8:k]) > 9]
    if onsets:
        cut = onsets[0] * hop - int(SR * 0.01)
        y = y[:cut].copy()
        fade = int(SR * 0.03)
        y[-fade:] *= np.linspace(1, 0, fade)
    # the pitch: the lowest strong peak of the ring, past the pluck's knock
    seg = y[int(SR * 0.03):int(SR * 0.45)]
    size = 1 << 18
    mag = np.abs(np.fft.rfft(seg * np.hanning(len(seg)), size))
    freq = np.fft.rfftfreq(size, 1 / SR)
    band = (freq > 60) & (freq < 3000)
    floor = 0.35 * np.max(mag[band])
    peaks = [i for i in np.nonzero(band)[0][1:-1] if mag[i] >= floor and mag[i] > mag[i - 1] and mag[i] >= mag[i + 1]]
    i = peaks[0]
    a, b, c = mag[i - 1], mag[i], mag[i + 1]
    f0 = (i + 0.5 * (a - c) / (a - 2 * b + c)) * SR / size
    return {"name": name, "y": y, "f0": f0, "cut": bool(onsets)}


def play(inst, m, dur, vel=1.0, ring=0.6):
    """The instrument's one note resampled to MIDI pitch `m`, held `dur`
    seconds and let ring `ring` more before it is faded."""
    ratio = hz(m) / inst["f0"]
    src = inst["y"]
    n = min(int(len(src) / ratio), int(SR * (dur + ring)))
    y = np.interp(np.arange(n) * ratio, np.arange(len(src)), src)
    fade = min(n, int(SR * 0.12))
    y[-fade:] *= np.linspace(1, 0, fade)
    return vel * y


def near(inst, m, lo, hi):
    """`m` moved by octaves to sit as close to the instrument's own note as
    [lo, hi] allows, so a note is bent as little as it can be."""
    own = midi(inst["f0"])
    best = min((m + 12 * k for k in range(-4, 5) if lo <= m + 12 * k <= hi), key=lambda x: abs(x - own))
    return best


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
    kal, box, low = load("note_kalimba"), load("note_box"), load("note_low")
    for i in (kal, box, low):
        print(f"{i['name']:13s} sounds at {i['f0']:7.1f} Hz (MIDI {midi(i['f0']):5.2f}), {len(i['y']) / SR:.2f} s"
              + (", cut to its first note" if i["cut"] else ""))
    # Each part in the octave its instrument was recorded nearest to: the
    # tune's middle is F#4 (66), the bass under it, the music box over it.
    up = near(kal, 66, 60, 84) - 66
    over = near(box, 66 + up + 12, 66 + up + 12, 96) - 66
    under = near(low, 50, 36, 66 + up - 12) - 50
    print(f"melody {up:+d}, music box {over:+d}, bass {under:+d} semitones from the score")

    total = sum(d for _, d in TUNE)
    length = (INTRO + total + OUTRO) * BEAT + 2.0
    L = np.zeros(int(SR * length))
    rng = np.random.default_rng(5)

    # the intro: a low A, and a music box run up into the downbeat
    place(L, play(low, 45 + under, INTRO * BEAT, 0.5), 0.0)
    run = [62, 64, 66, 67, 69, 71, 73, 74]
    for k, m in enumerate(run):
        place(L, play(box, m + over, 0.2, 0.25 + 0.03 * k), (INTRO - 1.0) * BEAT + k * BEAT / len(run))

    start = INTRO * BEAT
    at = start
    for k, (m, d) in enumerate(TUNE):
        vel = (1.0 if (at - start) / BEAT % 4 == 0 else 0.85) * rng.uniform(0.94, 1.0)
        hand = rng.uniform(0.0, 0.006)  # a finger is never on the grid
        place(L, play(kal, m + up, d * BEAT, 0.6 * vel), at + hand)
        place(L, play(box, m + over, d * BEAT, 0.2 * vel), at + hand + 0.004)
        at += d * BEAT

    for k, (root, triad) in enumerate(CHORDS):
        t0 = start + k * 2 * BEAT
        place(L, play(low, root + under, BEAT, 0.5 if k % 8 else 0.62, ring=0.3), t0)
        place(L, play(low, root + under, BEAT, 0.35, ring=0.3), t0 + BEAT)
        for off in (0.5, 1.5):
            for j, m in enumerate(triad):
                place(L, play(kal, m + up, 0.4 * BEAT, 0.11, ring=0.25), t0 + off * BEAT + 0.008 * j)

    # the end: the tonic, rung out on everything, with a last music box sparkle
    end = start + total * BEAT
    place(L, play(low, 38 + 12 + under, 3 * BEAT, 0.6, ring=2.0), end)
    for j, m in enumerate([62, 66, 69, 74]):
        place(L, play(kal, m + up, 3 * BEAT, 0.3, ring=2.0), end + 0.02 * j)
    for k, m in enumerate([74, 78, 81, 86]):
        place(L, play(box, m + over - 12, BEAT, 0.16, ring=2.0), end + 0.25 * BEAT + k * 0.07)

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
