#!/usr/bin/env python3
"""Measure a board's sounds against the cozy rules (docs/agents/sound.md).

    tools/measure_sfx.py <puzzle_id> [cue ...] [--raw]

A line a cue: its length, its peak, the centroid of its spectrum, how its
energy is shared between four bands, how far down everything above 3 kHz is,
and its peak high-passed at 400 Hz (a stand-in for a phone's speaker). The
last column says which rule it breaks, if any:

    high    less than 30 dB down above 3 kHz, or a centroid above 1 kHz
    rumble  more of it under 300 Hz than between 300 Hz and 1 kHz
    faint   under -24 dB on a phone
    empty   a raw take with next to nothing in it
    scratch a raw take with a quarter of it above 3 kHz (ask again with --new)

--raw reads the takes in build/sfx_raw/ in place of the finished files.
"""
import pathlib
import subprocess
import sys

import numpy as np

ROOT = pathlib.Path(__file__).resolve().parent.parent
RATE = 44100


def decode(path: pathlib.Path) -> np.ndarray:
    raw = subprocess.run(["ffmpeg", "-loglevel", "error", "-i", str(path), "-ac", "1",
                          "-ar", str(RATE), "-f", "f32le", "-"], capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.float32).astype(np.float64)


def db(x: float) -> float:
    return 20 * np.log10(max(x, 1e-9))


def measure(path: pathlib.Path) -> tuple[str, list[str]]:
    x = decode(path)
    if x.size == 0:
        return "no samples", ["empty"]
    spec = np.fft.rfft(x)
    freq = np.fft.rfftfreq(x.size, 1 / RATE)
    power = np.abs(spec) ** 2
    total = power.sum() or 1e-18
    share = [power[(freq >= lo) & (freq < hi)].sum() / total
             for lo, hi in ((0, 300), (300, 1000), (1000, 3000), (3000, RATE))]
    centroid = (freq * power).sum() / total
    top_down = -10 * np.log10(max(share[3], 1e-9))
    phone = np.fft.irfft(np.where(freq >= 400, spec, 0), x.size)
    peak, phone_peak = db(np.abs(x).max()), db(np.abs(phone).max())
    # How long anything is heard: the span above -40 dB of the peak.
    loud = np.nonzero(np.abs(x) > np.abs(x).max() * 0.01)[0]
    heard = (loud[-1] - loud[0]) / RATE if loud.size else 0.0
    flags = []
    if top_down < 30 or centroid > 1000:
        flags.append("high")
    if share[0] > share[1] and share[0] > 0.25:
        flags.append("rumble")
    if phone_peak < -24:
        flags.append("faint")
    if peak < -30 or heard < 0.02:
        flags.append("empty")
    line = (f"{x.size / RATE:5.2f}s heard {heard:4.2f}  peak {peak:6.1f}  centroid {centroid:5.0f} Hz  "
            f"<300 {share[0] * 100:3.0f}%  300-1k {share[1] * 100:3.0f}%  1-3k {share[2] * 100:3.0f}%  "
            f">3k {share[3] * 100:4.1f}% ({top_down:4.1f} dB down)  phone {phone_peak:6.1f}")
    return line, flags


def main() -> None:
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if not args:
        sys.exit(__doc__)
    raw = "--raw" in sys.argv
    folder = ROOT / ("build/sfx_raw" if raw else "assets/sfx") / args[0]
    files = sorted(folder.glob("*.mp3" if raw else "*.ogg"))
    if args[1:]:
        files = [f for f in files if f.stem in args[1:]]
    bad = 0
    for f in files:
        line, flags = measure(f)
        if raw:
            # A raw take is judged for what no filter mends: nothing in it,
            # or a scratch (the fifth number in the line is the share above
            # 3 kHz).
            flags = [k for k in flags if k == "empty"]
            if float(line.split(">3k")[1].split("%")[0]) > 25:
                flags.append("scratch")
        bad += bool(flags)
        print(f"{f.stem:14s} {line}  {' '.join(flags)}")
    print(f"{len(files)} files, {bad} flagged")


if __name__ == "__main__":
    main()
