#!/usr/bin/env python3
"""The game's soundtrack (2026-11-01). Twelve ElevenLabs Music v2.5 takes the
user chose by ear from the rounds on 2026-10-30 and 2026-11-01; the order here
is the order they play, and core/music.gd's TRACKS repeats it with the titles.

  tools/gen_music.py            treat the raw takes into assets/music/*.ogg
  tools/gen_music.py --new id   ask for a new take of one track, then treat it

Raw takes live in build/sfx_raw/music_try/raw (gitignored), named by the letter
each had on the listening page. Treatment is level and length only, because
these takes are already dark (rule 6 of the house sound): every track to the
same loudness, a short fade in, and a fade out the player's crossfade rides.
The prompts never name the reference game, the API refuses named works. Then
`godot --headless --path . --import`, or the game plays the old file.
"""
import json
import os
import pathlib
import re
import subprocess
import sys
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent
RAW = ROOT / "build/sfx_raw/music_try/raw"
OUT = ROOT / "assets/music"
API = "https://api.elevenlabs.io/v1/music?output_format=mp3_44100_128"
LUFS = -20.0
FADE_IN = 0.4
FADE_OUT = 3.0
QUALITY = "3"
TAIL = ' Instrumental only, no vocals, no vinyl crackle, no tape hiss, no noise layers. Real acoustic instruments, warm and close-miked, soft dynamics, low and mid register, no bright bells or glockenspiel in the lead. Gentle, unhurried background music for a cozy puzzle game: it stays in the background and never demands attention. Lofi-style warmth: the top end rolled off softly, rounded transients. Seamless, even energy from start to end, no big build-ups or drops.'

# id: (letter on the listening page, title, prompt)
TRACKS = {
    "garden_walk": ("E", "Garden Walk",
        'Gentle pastoral instrumental with a low, soft kalimba and a warm marimba sharing a simple melody, nylon-string guitar strumming lightly, a soft upright bass, no drums, a faint flute far away. Around 88 bpm, a sunny garden, a walk in the park, playful but calm.'),
    "sandal_hop": ("J", "Sandal Hop",
        'Upbeat, sunny instrumental with a ukulele strumming a skipping rhythm, a warm marimba playing a catchy, simple melody, soft hand claps and a brushed snare, upright bass, a wooden flute joining the tune. Around 112 bpm, a beach town in the morning, friendly and bouncy, cheerful, never loud.'),
    "fairway_morning": ("A", "Fairway Morning",
        'Breezy, sunny bossa nova with a nylon-string acoustic guitar playing soft chords and a light melody, upright bass, brushed drum kit with soft rim clicks, a warm Rhodes electric piano answering in the gaps. Around 96 bpm, relaxed and smiling, like a golf course on a sunny morning by the sea.'),
    "sunny_bench": ("N", "Sunny Bench",
        'Warm lofi instrumental with a felt upright piano playing a bouncy, hopeful melody over simple major chords, a soft kalimba sparkling low in the back, a muffled kick and brushed snare with a light shaker, a round double bass. Around 96 bpm, a walk through a sunny park, open sky, kind and lively.'),
    "palm_shade": ("L", "Palm Shade",
        'Warm island instrumental with a soft, muted steel pan playing a gentle, happy melody, a marimba answering, a ukulele strumming lightly, upright bass, soft bongos and shaker, a brushed snare. Around 108 bpm, a lagoon, palm shade, sunny and relaxed, played softly.'),
    "balcony_breeze": ("K", "Balcony Breeze",
        'Playful lofi instrumental with a nylon-string guitar picking a bright, bouncy melody, a warm marimba doubling it, a muffled soft kick and brushed snare giving it a lazy groove, a round upright bass, a little Rhodes in the gaps. Around 100 bpm, a sunny balcony, a breeze, happy and open.'),
    "island_breakfast": ("F", "Island Breakfast",
        'Light, cheerful island instrumental with a soft ukulele strumming, a warm marimba melody, upright bass, a brushed drum kit played very quietly with shaker, a muted nylon guitar. Around 100 bpm, sunny, friendly, a beach resort in the morning, never loud.'),
    "hillside_picnic": ("P", "Hillside Picnic",
        'Sunny folk-pop instrumental with a soft mandolin and a nylon-string guitar picking a bright, rolling pattern, a warm marimba carrying the melody, a brushed drum kit with shaker, upright bass, soft hand claps on the chorus. Around 108 bpm, a hillside picnic, fresh air, happy and warm.'),
    "rain_on_the_window": ("D", "Rain on the Window",
        'Lofi beat with a felt upright piano playing a simple, tender melody over soft jazzy chords, a muffled kick and brushed snare, a round double bass, a little warm nylon guitar in the back. Around 84 bpm, warm rain on a window, cozy and kind.'),
    "bobbing_boats": ("O", "Bobbing Boats",
        'Lively tropical instrumental led by a warm marimba playing a catchy, dancing melody, soft congas and bongos giving a gentle groove, a ukulele strumming, upright bass, a nylon guitar answering. Around 112 bpm, a sunny harbour, boats bobbing, cheerful, open and relaxed, never loud.'),
    "meadow_skip": ("I", "Meadow Skip",
        'Bright-hearted, open pastoral instrumental with a soft low kalimba and a warm marimba trading a bouncy melody, nylon-string guitar strumming along, a round upright bass, a brushed drum kit played lightly with shaker and soft rim clicks giving it a skip. Around 104 bpm, a sunny meadow, a picnic, cheerful and wide open.'),
    "village_square": ("M", "Village Square",
        'Cheerful folk instrumental in 4/4 with a soft accordion playing a warm, singable melody, a nylon-string guitar strumming, upright bass, a brushed drum kit with a light tambourine, a wooden flute answering. Around 110 bpm, a village square in the sun, good-natured and bright, played gently.'),
}


def key() -> str:
    k = os.environ.get("ELEVENLABS_API_KEY", "").strip()
    if not k:
        p = pathlib.Path.home() / ".config/elevenlabs/api_key"
        k = p.read_text().strip() if p.exists() else ""
    if not k:
        sys.exit("no ElevenLabs key")
    return k


def compose(track: str) -> None:
    letter, _title, prompt = TRACKS[track]
    body = json.dumps({"prompt": prompt + TAIL, "model_id": "music_v2_5",
        "music_length_ms": 60000, "force_instrumental": True}).encode()
    req = urllib.request.Request(API, data=body, method="POST", headers={
        "xi-api-key": key(), "Content-Type": "application/json", "Accept": "audio/mpeg"})
    RAW.mkdir(parents=True, exist_ok=True)
    with urllib.request.urlopen(req, timeout=600) as r:
        (RAW / f"{letter}.mp3").write_bytes(r.read())


def loudness(path: pathlib.Path) -> float:
    err = subprocess.run(["ffmpeg", "-nostats", "-i", str(path), "-af", "ebur128=framelog=quiet",
        "-f", "null", "-"], capture_output=True, text=True).stderr
    return float(re.findall(r"I:\s+(-?[\d.]+) LUFS", err)[-1])


def duration(path: pathlib.Path) -> float:
    return float(subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration",
        "-of", "csv=p=0", str(path)], capture_output=True, text=True).stdout)


def treat(track: str) -> None:
    letter = TRACKS[track][0]
    src = RAW / f"{letter}.mp3"
    gain = LUFS - loudness(src)
    length = duration(src)
    OUT.mkdir(parents=True, exist_ok=True)
    out = OUT / f"{track}.ogg"
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(src), "-af",
        f"volume={gain:.2f}dB,afade=t=in:d={FADE_IN},afade=t=out:st={length - FADE_OUT:.3f}:d={FADE_OUT}",
        "-c:a", "libvorbis", "-q:a", QUALITY, str(out)], check=True)
    print(f"{track}: {gain:+.1f} dB, {out.stat().st_size // 1024} KB, {loudness(out):.1f} LUFS")


def main() -> None:
    if len(sys.argv) == 3 and sys.argv[1] == "--new":
        compose(sys.argv[2])
        treat(sys.argv[2])
        return
    for track in TRACKS:
        treat(track)


if __name__ == "__main__":
    main()
