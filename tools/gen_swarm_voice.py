#!/usr/bin/env python3
"""The Swarm test's voice (ui/menu/swarm_tab.gd): every SWARM_L* line of
locale/ui.csv, in each language, spoken by ElevenLabs into
assets/voice/swarm/<KEY>_<lang>.mp3, and into content/swarm_voice.json when
each character starts (seconds), so the words appear as they are said
(content/* is in the export's include filter; a loose json elsewhere is not).

The key is $ELEVENLABS_API_KEY or ~/.config/elevenlabs/api_key (the fallback
key, as tools/gen_sfx.py, when that one is out of quota); never stored here.
A clip already on disk is kept unless --force.

    python3 tools/gen_swarm_voice.py [--force]
"""
import base64
import csv
import json
import os
import pathlib
import sys
import urllib.error
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "assets/voice/swarm"
# The Flavio demo's voice, exactly as Persona Studio speaks it
# (~/dev/hokipoki/persona-studio/state/personas/flavio.json): Boyd on
# eleven_v4_turbo, one delivery tag a line. Kinder than the demo (the user,
# 2026-11-04: "make the voice sound more kind"): stability 0.5 rather than
# its 0.35, and friendly/cheerful/gentle tags rather than warm/calm/laugh,
# which in Boyd's low rasp came out sultry.
VOICE = "gfRt6Z3Z8aTbpLfexQ7N"
MODEL = "eleven_v4_turbo"
STABILITY = 0.5
LANGS = ["en", "pt", "es"]
TAGS = {
    "SWARM_L1": "[cheerful]", "SWARM_L2": "[friendly]", "SWARM_L3": "[cheerful]",
    "SWARM_L4": "[friendly]", "SWARM_L5": "[friendly]", "SWARM_L6": "[cheerful]",
    "SWARM_L7": "[friendly]", "SWARM_L8": "[gentle]",
}


def keys() -> list[str]:
    out = []
    for env, name in (("ELEVENLABS_API_KEY", "api_key"), ("ELEVENLABS_API_KEY_FALLBACK", "api_key_fallback")):
        k = os.environ.get(env, "").strip()
        p = pathlib.Path.home() / ".config/elevenlabs" / name
        if not k and p.exists():
            k = p.read_text().strip()
        if k:
            out.append(k)
    if not out:
        sys.exit("no ElevenLabs key: set ELEVENLABS_API_KEY or write ~/.config/elevenlabs/api_key")
    return out


def speak(text: str, lang: str) -> dict:
    body = json.dumps({"text": text, "model_id": MODEL, "voice_settings": {"stability": STABILITY}}).encode()
    last = None
    for k in keys():
        req = urllib.request.Request(
            f"https://api.elevenlabs.io/v1/text-to-speech/{VOICE}/with-timestamps?output_format=mp3_44100_128",
            data=body, headers={"xi-api-key": k, "Content-Type": "application/json"})
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                return json.load(r)
        except urllib.error.HTTPError as e:
            last = f"{e.code} {e.read().decode(errors='replace')[:300]}"
    sys.exit(f"ElevenLabs refused {text!r}: {last}")


def main() -> None:
    force = "--force" in sys.argv
    OUT.mkdir(parents=True, exist_ok=True)
    with open(ROOT / "locale/ui.csv", newline="") as f:
        rows = [r for r in csv.DictReader(f) if r["keys"].startswith("SWARM_L")]
    timing_path = ROOT / "content/swarm_voice.json"
    timings = json.loads(timing_path.read_text()) if timing_path.exists() else {}
    for row in rows:
        for lang in LANGS:
            text = row[lang].replace("\\n", " ")
            mp3 = OUT / f"{row['keys']}_{lang}.mp3"
            if mp3.exists() and mp3.stem in timings and not force:
                continue
            tag = TAGS.get(row["keys"], "")
            j = speak(f"{tag} {text}" if tag else text, lang)
            mp3.write_bytes(base64.b64decode(j["audio_base64"]))
            al = j.get("alignment") or {}
            # The tag is not shown, so its characters leave the timings; when the
            # shown words cannot be found the game spreads them over the clip.
            said = "".join(al.get("characters", []))
            at = said.find(text)
            starts = al.get("character_start_times_seconds", [])[at:at + len(text)] if at >= 0 else []
            timings[mp3.stem] = {"text": text, "starts": [round(x, 3) for x in starts]}
            timing_path.write_text(json.dumps(timings, ensure_ascii=False, indent=0))
            print("spoke", mp3.name, len(al.get("characters", [])), "chars")


if __name__ == "__main__":
    main()
