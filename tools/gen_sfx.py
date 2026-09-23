#!/usr/bin/env python3
"""Generate a board's sound effects with ElevenLabs' sound-generation API.

    python3 tools/gen_sfx.py binairo            # every cue of the set
    python3 tools/gen_sfx.py binairo place hint # only these
    python3 tools/gen_sfx.py binairo place --new  # a fresh take, not the cached one

Each cue is one prompt below, rendered once (the raw take is cached in build/sfx_raw/, so re-running
only reprocesses it; --new asks ElevenLabs again), trimmed of leading and trailing
silence, levelled to a peak and written to assets/sfx/<board>/<cue>.ogg, which
is exactly where ui/fx2d.gd's cue() looks. The key is read from
$ELEVENLABS_API_KEY or ~/.config/elevenlabs/api_key and never stored here.
Needs ffmpeg on the PATH.
"""
import json, os, pathlib, re, subprocess, sys, urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent
API = "https://api.elevenlabs.io/v1/sound-generation?output_format=mp3_44100_128"

# The palette every cue shares, so the set reads as one instrument family.
STYLE = ("cozy casual mobile puzzle game UI sound, soft warm wooden and "
         "marimba tones, gentle, rounded, no harsh transients, clean, dry, "
         "no music bed, no voice")

# cue: (prompt, seconds, peak level in dBFS -- quieter for the chatty ones)
SETS = {
    # The interface, not a board: every button's click (ui/ui_sound.gd).
    "ui": {
        "click":    ("a single tiny soft paper and wood click, pressing a small cozy button, very short and light", 0.5, -12),
    },
    "binairo": {
        "place":    ("a single soft wooden tile tap with a tiny bubbly pop, very short", 0.5, -6),
        "clear":    ("a very short soft downward whoosh-pop, a small token lifted off a wooden board", 0.5, -9),
        "brush":    ("a tiny soft paper click, selecting a pencil, very short and quiet", 0.5, -12),
        "undo":     ("a short soft reverse swish, like rewinding a tiny tape, playful", 0.6, -9),
        "hint":     ("a gentle magical sparkle chime, three soft glockenspiel notes rising", 1.0, -5),
        "check":    ("two soft low wooden marimba boops going down, a kind 'not quite' sound, not a buzzer", 0.7, -6),
        "check_ok": ("two soft bright marimba notes going up, a friendly 'all good' confirmation", 0.7, -5),
        "reset":    ("a quick ripple of many small soft wooden pops, tiles being swept off a board", 1.0, -8),
        "solved":   ("a warm short celebratory marimba and glockenspiel flourish, rising arpeggio ending on a bright sparkle, joyful and cozy", 2.0, -3),
        "line":     ("a short happy two-note soft kalimba pluck, a row completed", 0.6, -6),
        "blush_in": ("a tiny soft worried wobble, a muffled wooden 'bonk' with a slight pitch dip, gentle", 0.5, -10),
        "enter":    ("a soft airy cascade of tiny wooden pops rolling in, a board of tiles appearing", 1.0, -9),
    },
    # Code Break (puzzle_id "mastermind"): little round friends fly into
    # seats, a Check drops score pips into a pouch, lids lift on the answer.
    "mastermind": {
        "place":    ("a tiny soft bouncy boing and a wooden seat tap, a small round character hopping into a seat, very short", 0.5, -6),
        "clear":    ("a very short soft downward whoosh-pop, a small character hopping out of a wooden seat", 0.5, -9),
        "full":     ("a tiny soft muffled wooden double bump, a row already full, gentle, very short", 0.5, -11),
        "locked":   ("a tiny soft worried wobble, a muffled wooden 'bonk' with a slight pitch dip, gentle", 0.5, -10),
        "undo":     ("a short soft reverse swish, like rewinding a tiny tape, playful", 0.6, -9),
        "hint":     ("a gentle magical sparkle chime, three soft glockenspiel notes rising", 1.0, -5),
        "check":    ("two soft low wooden marimba boops going down, a kind 'not quite' sound, not a buzzer", 0.7, -6),
        "score":    ("a few small soft wooden beads dropping one after another into a cloth pouch, then a gentle marimba note", 1.0, -6),
        "reveal":   ("a soft wooden box lid lifting with a small curious kalimba shimmer, a secret being uncovered", 1.0, -6),
        "reset":    ("a quick ripple of many small soft wooden pops, pieces being swept off a board", 1.0, -8),
        "solved":   ("a warm short celebratory marimba and glockenspiel flourish, rising arpeggio ending on a bright sparkle, joyful and cozy", 2.0, -3),
        "enter":    ("a soft airy cascade of tiny wooden pops rolling in, a board of seats appearing", 1.0, -9),
    },
    # Balance: fruit weights on little hanging scales; a tap steps a weight
    # up or down, and a scale that comes level chimes.
    "balance": {
        "step":     ("a single tiny soft wooden click, a small weight nudged on a scale pan, very short", 0.5, -9),
        "level":    ("a soft bright two-note kalimba chime going up, a hanging scale settling perfectly level", 0.7, -6),
        "refused":  ("a tiny soft worried wobble, a muffled wooden 'bonk' with a slight pitch dip, gentle", 0.5, -10),
        "undo":     ("a short soft reverse swish, like rewinding a tiny tape, playful", 0.6, -9),
        "hint":     ("a gentle magical sparkle chime, three soft glockenspiel notes rising", 1.0, -5),
        "reset":    ("a soft wooden creak and gentle clatter, little scale pans swinging back to rest", 1.0, -8),
        "solved":   ("a warm short celebratory marimba and glockenspiel flourish, rising arpeggio ending on a bright sparkle, joyful and cozy", 2.0, -3),
        "enter":    ("a soft airy cascade of tiny wooden pops rolling in, little scales swinging into place", 1.0, -9),
    },
    # Untangle: paper lanterns joined by strings, dragged until no strings cross.
    "untangle": {
        "pick":     ("a tiny soft paper rustle, lifting a small paper lantern, very short and quiet", 0.5, -12),
        "drop":     ("a soft gentle paper lantern landing with a tiny wooden tap, very short", 0.5, -8),
        "undo":     ("a short soft reverse swish, like rewinding a tiny tape, playful", 0.6, -9),
        "hint":     ("a gentle magical sparkle chime, three soft glockenspiel notes rising", 1.0, -5),
        "reset":    ("a soft airy paper flutter, many small paper lanterns drifting back into place", 1.0, -8),
        "solved":   ("a warm short celebratory marimba and glockenspiel flourish, rising arpeggio ending on a bright sparkle, joyful and cozy", 2.0, -3),
        "enter":    ("a soft airy cascade of tiny paper and wooden pops, paper lanterns appearing one by one", 1.0, -9),
    },
    # Shikaku: garden beds drawn as rectangles in soil around number stakes.
    "shikaku": {
        "select":   ("a single tiny soft wooden marimba tick, one light mallet tap, very short and quiet", 0.5, -12),
        "plot":     ("a soft short garden trowel pat in loose soil with a tiny wooden tap, a garden bed marked out", 0.5, -6),
        "clear":    ("a very short soft downward whoosh with a light soil brush, a garden bed wiped away", 0.5, -9),
        "locked":   ("a tiny soft worried wobble, a muffled wooden 'bonk' with a slight pitch dip, gentle", 0.5, -10),
        "undo":     ("a short soft reverse swish, like rewinding a tiny tape, playful", 0.6, -9),
        "hint":     ("a gentle magical sparkle chime, three soft glockenspiel notes rising", 1.0, -5),
        "check":    ("two soft low wooden marimba boops going down, a kind 'not quite' sound, not a buzzer", 0.7, -6),
        "check_ok": ("two soft bright marimba notes going up, a friendly 'all good' confirmation", 0.7, -5),
        "reset":    ("a soft brushing sweep across loose soil with a few small wooden pops, a garden raked clean", 1.0, -8),
        "solved":   ("a warm short celebratory marimba and glockenspiel flourish, rising arpeggio ending on a bright sparkle, joyful and cozy", 2.0, -3),
        "enter":    ("a soft airy cascade of tiny wooden pops rolling in, little garden stakes appearing", 1.0, -9),
    },
    # Tents: pitch a tent beside each tree on a grassy campsite grid.
    "tents": {
        "place":    ("a tiny soft canvas flap and a light wooden peg tap, a little tent pitched, very short", 0.5, -6),
        "locked":   ("a tiny soft worried wobble, a muffled wooden 'bonk' with a slight pitch dip, gentle", 0.5, -10),
        "undo":     ("a short soft reverse swish, like rewinding a tiny tape, playful", 0.6, -9),
        "hint":     ("a gentle magical sparkle chime, three soft glockenspiel notes rising", 1.0, -5),
        "check":    ("two soft low wooden marimba boops going down, a kind 'not quite' sound, not a buzzer", 0.7, -6),
        "check_ok": ("two soft bright marimba notes going up, a friendly 'all good' confirmation", 0.7, -5),
        "reset":    ("a quick soft ripple of canvas flaps and small wooden pops, tents being packed away", 1.0, -8),
        "solved":   ("a warm short celebratory marimba and glockenspiel flourish, rising arpeggio ending on a bright sparkle, joyful and cozy", 2.0, -3),
        "enter":    ("a soft airy cascade of tiny wooden pops and a light leafy rustle, a campsite of trees appearing", 1.0, -9),
    },
    # Light Up: paper lamps set down in a stone courtyard light their rows.
    "lightup": {
        "place":    ("a tiny soft wooden tap with a warm gentle glow shimmer, a little paper lamp set down and lit, very short", 0.5, -6),
        "locked":   ("a tiny soft worried wobble, a muffled wooden 'bonk' with a slight pitch dip, gentle", 0.5, -10),
        "undo":     ("a short soft reverse swish, like rewinding a tiny tape, playful", 0.6, -9),
        "hint":     ("a gentle magical sparkle chime, three soft glockenspiel notes rising", 1.0, -5),
        "check":    ("two soft low wooden marimba boops going down, a kind 'not quite' sound, not a buzzer", 0.7, -6),
        "check_ok": ("two soft bright marimba notes going up, a friendly 'all good' confirmation", 0.7, -5),
        "reset":    ("a soft quick ripple of small wooden pops and a gentle airy puff, little lamps being blown out", 1.0, -8),
        "solved":   ("a warm short celebratory marimba and glockenspiel flourish, rising arpeggio ending on a bright sparkle, joyful and cozy", 2.0, -3),
        "enter":    ("a soft airy cascade of tiny wooden and stone pops rolling in, a courtyard of stones appearing", 1.0, -9),
    },
    # One Line: a snail walks every line between posts exactly once.
    "oneline": {
        "start":    ("a tiny soft bouncy boing and a wooden post tap, a small snail hopping onto a post, very short", 0.5, -6),
        "lay":      ("a short soft kalimba pluck with a light gliding slide, a line drawn from one post to the next", 0.5, -7),
        "locked":   ("a tiny soft worried wobble, a muffled wooden 'bonk' with a slight pitch dip, gentle", 0.5, -10),
        "undo":     ("a short soft reverse swish, like rewinding a tiny tape, playful", 0.6, -9),
        "hint":     ("a gentle magical sparkle chime, three soft glockenspiel notes rising", 1.0, -5),
        "check":    ("two soft low wooden marimba boops going down, a kind 'not quite' sound, not a buzzer", 0.7, -6),
        "check_ok": ("two soft bright marimba notes going up, a friendly 'all good' confirmation", 0.7, -5),
        "reset":    ("a soft quick backward swish with a few small wooden pops, a drawn trail wiped away", 1.0, -8),
        "solved":   ("a warm short celebratory marimba and glockenspiel flourish, rising arpeggio ending on a bright sparkle, joyful and cozy", 2.0, -3),
        "enter":    ("a soft airy cascade of tiny wooden pops rolling in, little wooden posts appearing", 1.0, -9),
    },
    # Nonogram: mosaic tiles laid on a floor by row and column clues.
    "nonogram": {
        "place":    ("a single soft ceramic mosaic tile tap on wood, a small tile laid down, very short", 0.5, -7),
        "locked":   ("a tiny soft worried wobble, a muffled wooden 'bonk' with a slight pitch dip, gentle", 0.5, -10),
        "undo":     ("a short soft reverse swish, like rewinding a tiny tape, playful", 0.6, -9),
        "hint":     ("a gentle magical sparkle chime, three soft glockenspiel notes rising", 1.0, -5),
        "check":    ("two soft low wooden marimba boops going down, a kind 'not quite' sound, not a buzzer", 0.7, -6),
        "check_ok": ("two soft bright marimba notes going up, a friendly 'all good' confirmation", 0.7, -5),
        "reset":    ("a quick ripple of many small soft ceramic and wooden clicks, mosaic tiles being swept off a floor", 1.0, -8),
        "solved":   ("a warm short celebratory marimba and glockenspiel flourish, rising arpeggio ending on a bright sparkle, joyful and cozy", 2.0, -3),
        "enter":    ("a soft airy cascade of tiny ceramic and wooden pops rolling in, a mosaic floor appearing", 1.0, -9),
    },
    # Queens: a little crowned bee seated on a garden court; crosses and
    # pebbles are the player's own marks.
    "queens": {
        "place":    ("a tiny soft wooden tap with a quick gentle buzzy wing flutter, a little bee settling on a flower, very short", 0.5, -6),
        "remove":   ("a very short soft downward whoosh with a tiny wing flutter, a little bee lifting off, gentle", 0.5, -9),
        "locked":   ("a tiny soft worried wobble, a muffled wooden 'bonk' with a slight pitch dip, gentle", 0.5, -10),
        "undo":     ("a short soft reverse swish, like rewinding a tiny tape, playful", 0.6, -9),
        "hint":     ("a gentle magical sparkle chime, three soft glockenspiel notes rising", 1.0, -5),
        "check":    ("two soft low wooden marimba boops going down, a kind 'not quite' sound, not a buzzer", 0.7, -6),
        "check_ok": ("two soft bright marimba notes going up, a friendly 'all good' confirmation", 0.7, -5),
        "reset":    ("a quick soft ripple of small wooden pops and a light wing flutter, a garden court swept clear", 1.0, -8),
        "solved":   ("a warm short celebratory marimba and glockenspiel flourish, rising arpeggio ending on a bright sparkle, joyful and cozy", 2.0, -3),
        "enter":    ("a soft airy cascade of tiny wooden pops and a light leafy rustle, a garden court appearing", 1.0, -9),
    },
    # Hidden Word (puzzle_id "hiddenword"): type a five-letter guess on a
    # keyboard, Enter turns the row over a tile at a time.
    "hiddenword": {
        "type":     ("a single tiny soft wooden letter tile click, typing on a cozy wooden keyboard, very short and quiet", 0.5, -12),
        "erase":    ("a tiny soft short downward wooden tick, a letter tile taken back, very short and quiet", 0.5, -13),
        "flip":     ("a single soft wooden tile flipping over with a light papery flick, very short", 0.5, -9),
        "refused":  ("a tiny soft worried wobble, a muffled wooden 'bonk' with a slight pitch dip, gentle", 0.5, -10),
        "hint":     ("a gentle magical sparkle chime, three soft glockenspiel notes rising", 1.0, -5),
        "reset":    ("a quick ripple of many small soft wooden pops, tiles being swept off a board", 1.0, -8),
        "solved":   ("a warm short celebratory marimba and glockenspiel flourish, rising arpeggio ending on a bright sparkle, joyful and cozy", 2.0, -3),
        "lost":     ("a gentle warm three-note soft marimba phrase gently descending and resolving, a kind 'maybe tomorrow', calm, not sad, not a buzzer", 1.5, -6),
        "enter":    ("a soft airy cascade of tiny wooden pops rolling in, a board of letter tiles appearing", 1.0, -9),
    },
    # Word Trail (puzzle_id "wordtrail"): drag a trail through letter tiles;
    # only a right word locks, and a ribbon of colour runs along it.
    "wordtrail": {
        "place":    ("a short bright rising kalimba run of four soft notes with a gentle ribbon swish, a hidden word found", 0.8, -6),
        "undo":     ("a short soft reverse swish, like rewinding a tiny tape, playful", 0.6, -9),
        "hint":     ("a gentle magical sparkle chime, three soft glockenspiel notes rising", 1.0, -5),
        "reset":    ("a quick ripple of many small soft wooden pops, letter tiles being swept clean", 1.0, -8),
        "solved":   ("a warm short celebratory marimba and glockenspiel flourish, rising arpeggio ending on a bright sparkle, joyful and cozy", 2.0, -3),
        "enter":    ("a soft airy cascade of tiny wooden pops rolling in, a field of letter tiles appearing", 1.0, -9),
    },
    # Mushroom Patch: plant a mushroom where one must be, lay a pebble where
    # none can be; nothing is ever revealed by a tap.
    "mushroom": {
        "place":    ("a tiny soft squishy pop with a light earthy wooden tap, a little mushroom popping up from moss, very short", 0.5, -6),
        "remove":   ("a very short soft downward whoosh-pop, a small thing lifted out of soft moss", 0.5, -9),
        "locked":   ("a tiny soft worried wobble, a muffled wooden 'bonk' with a slight pitch dip, gentle", 0.5, -10),
        "undo":     ("a short soft reverse swish, like rewinding a tiny tape, playful", 0.6, -9),
        "hint":     ("a gentle magical sparkle chime, three soft glockenspiel notes rising", 1.0, -5),
        "check":    ("two soft low wooden marimba boops going down, a kind 'not quite' sound, not a buzzer", 0.7, -6),
        "check_ok": ("two soft bright marimba notes going up, a friendly 'all good' confirmation", 0.7, -5),
        "reset":    ("a quick soft ripple of small squishy pops and a light leafy rustle, a forest patch cleared", 1.0, -8),
        "solved":   ("a warm short celebratory marimba and glockenspiel flourish, rising arpeggio ending on a bright sparkle, joyful and cozy", 2.0, -3),
        "enter":    ("a soft airy cascade of tiny wooden pops and a light leafy rustle, a mossy forest patch appearing", 1.0, -9),
    },
    # Sudoku: numerals in ink on a paper grid; a pencil mode for small notes,
    # and a row, column or region that fills lights up in a wave.
    "sudoku": {
        "place":    ("a single soft pencil tap on thick paper with a tiny wooden knock, writing a number, very short", 0.5, -7),
        "pencil":   ("a tiny light pencil scribble tick on paper, a small note jotted, very short and quiet", 0.5, -12),
        "line":     ("a short happy two-note soft kalimba pluck, a row completed", 0.6, -6),
        "locked":   ("a tiny soft worried wobble, a muffled wooden 'bonk' with a slight pitch dip, gentle", 0.5, -10),
        "undo":     ("a short soft reverse swish, like rewinding a tiny tape, playful", 0.6, -9),
        "hint":     ("a gentle magical sparkle chime, three soft glockenspiel notes rising", 1.0, -5),
        "check":    ("two soft low wooden marimba boops going down, a kind 'not quite' sound, not a buzzer", 0.7, -6),
        "check_ok": ("two soft bright marimba notes going up, a friendly 'all good' confirmation", 0.7, -5),
        "reset":    ("a soft quick eraser rub on paper with a few small wooden pops, a page wiped clean", 1.0, -8),
        "solved":   ("a warm short celebratory marimba and glockenspiel flourish, rising arpeggio ending on a bright sparkle, joyful and cozy", 2.0, -3),
        "enter":    ("a soft airy cascade of tiny paper and wooden pops rolling in, a grid of numbers appearing", 1.0, -9),
    },
    # Bridges: wooden plank bridges laid between islets on a calm sea.
    "bridges": {
        "place":    ("a single soft hollow wooden plank knock with a tiny water lap, a small plank laid across, very short", 0.5, -6),
        "remove":   ("a very short soft downward wooden slide with a tiny splash, planks lifted away", 0.5, -9),
        "met":      ("a short happy two-note soft kalimba pluck, a little island complete", 0.6, -7),
        "over":     ("a tiny soft worried wobble, a muffled hollow wooden 'bonk' with a slight pitch dip, gentle", 0.5, -10),
        "locked":   ("a tiny soft worried wobble, a muffled wooden 'bonk' with a slight pitch dip, gentle", 0.5, -10),
        "undo":     ("a short soft reverse swish, like rewinding a tiny tape, playful", 0.6, -9),
        "hint":     ("a gentle magical sparkle chime, three soft glockenspiel notes rising", 1.0, -5),
        "check":    ("two soft low wooden marimba boops going down, a kind 'not quite' sound, not a buzzer", 0.7, -6),
        "check_ok": ("two soft bright marimba notes going up, a friendly 'all good' confirmation", 0.7, -5),
        "reset":    ("a quick soft ripple of hollow wooden plank knocks and gentle water laps, bridges being taken up", 1.0, -8),
        "solved":   ("a warm short celebratory marimba and glockenspiel flourish, rising arpeggio ending on a bright sparkle, joyful and cozy", 2.0, -3),
        "enter":    ("a soft airy cascade of tiny wooden pops and a gentle water lap, little islands appearing on a calm sea", 1.0, -9),
    },
    # Quilt: cloth patches dragged off a rack onto a backing; a patch that
    # lands sews a running stitch along its seams.
    "quilt": {
        "lift":     ("a tiny soft fabric rustle, a small cloth patch picked up, very short and quiet", 0.5, -12),
        "place":    ("a soft muffled cloth pat followed by a few quick tiny soft needle-and-thread stitch ticks, a patch sewn on", 0.7, -6),
        "refused":  ("a tiny soft worried wobble, a muffled cloth 'bonk' with a slight pitch dip, gentle", 0.5, -10),
        "undo":     ("a short soft reverse swish, like rewinding a tiny tape, playful", 0.6, -9),
        "hint":     ("a gentle magical sparkle chime, three soft glockenspiel notes rising", 1.0, -5),
        "reset":    ("a soft quick ripple of fabric rustles and small muffled pats, cloth patches gathered back onto a rack", 1.0, -8),
        "solved":   ("a warm short celebratory marimba and glockenspiel flourish, rising arpeggio ending on a bright sparkle, joyful and cozy", 2.0, -3),
        "enter":    ("a soft airy cascade of tiny muffled cloth pats and wooden pops, quilt patches appearing on a rack", 1.0, -9),
    },
    # Paper Planes: tap a folded paper dart and it launches down its lane.
    "planes": {
        "place":    ("a light soft paper whoosh gliding away with a tiny papery flutter, a small folded paper plane launched, gentle", 0.8, -7),
        "refuse":   ("a tiny soft worried wobble, a muffled papery 'bonk' with a slight pitch dip, gentle", 0.5, -10),
        "undo":     ("a short soft reverse swish, like rewinding a tiny tape, playful", 0.6, -9),
        "hint":     ("a gentle magical sparkle chime, three soft glockenspiel notes rising", 1.0, -5),
        "reset":    ("a soft airy flurry of small paper rustles and folds, paper planes gliding back into place", 1.0, -8),
        "solved":   ("a warm short celebratory marimba and glockenspiel flourish, rising arpeggio ending on a bright sparkle, joyful and cozy", 2.0, -3),
        "enter":    ("a soft airy cascade of tiny paper folds and light wooden pops, paper planes appearing on a page", 1.0, -9),
    },
    # Pinwheel: tap a paper pinwheel and its cloth piece takes a quarter turn.
    "pinwheel": {
        "place":    ("a short soft airy paper pinwheel whirr with a tiny wooden click, a quarter turn, very short", 0.5, -11),
        "refused":  ("a tiny soft worried wobble, a muffled wooden 'bonk' with a slight pitch dip, gentle", 0.5, -10),
        "undo":     ("a short soft reverse swish, like rewinding a tiny tape, playful", 0.6, -9),
        "hint":     ("a gentle magical sparkle chime, three soft glockenspiel notes rising", 1.0, -5),
        "reset":    ("a soft quick ripple of airy paper whirrs and small wooden clicks, pinwheels spinning back", 1.0, -8),
        "solved":   ("a warm short celebratory marimba and glockenspiel flourish, rising arpeggio ending on a bright sparkle, joyful and cozy", 2.0, -3),
        "enter":    ("a soft airy cascade of tiny wooden pops and a light breezy flutter, little paper pinwheels appearing", 1.0, -9),
    },
}


def key() -> str:
    k = os.environ.get("ELEVENLABS_API_KEY", "").strip()
    if not k:
        p = pathlib.Path.home() / ".config/elevenlabs/api_key"
        if p.exists():
            k = p.read_text().strip()
    if not k:
        sys.exit("no ElevenLabs key: set ELEVENLABS_API_KEY or write ~/.config/elevenlabs/api_key")
    return k


def generate(api_key: str, prompt: str, seconds: float) -> bytes:
    body = json.dumps({
        "text": f"{prompt}. {STYLE}",
        "duration_seconds": seconds,
        "prompt_influence": 0.6,
    }).encode()
    req = urllib.request.Request(API, data=body, method="POST", headers={
        "xi-api-key": api_key, "Content-Type": "application/json", "Accept": "audio/mpeg"})
    try:
        with urllib.request.urlopen(req, timeout=120) as r:
            return r.read()
    except urllib.error.HTTPError as e:
        sys.exit(f"ElevenLabs answered {e.code}: {e.read().decode(errors='replace')[:400]}")


def to_ogg(mp3: pathlib.Path, out: pathlib.Path, peak: int) -> None:
    # Trim silence at both ends (reverse trick for the tail) with a low
    # threshold and a little padding, so a soft ripple is not eaten; then
    # scale to a peak level (loudnorm misbehaves on sub-second clips) and
    # fade the last 30 ms so nothing clicks off.
    trim = "silenceremove=start_periods=1:start_threshold=-60dB:start_silence=0.01"
    # Fold to mono first, so the peak is measured on what is written: a take
    # whose channels differ loses several dB in the fold, and levelling the
    # stereo peak left those files well under their target.
    pre = f"aformat=channel_layouts=mono,{trim},areverse,{trim},areverse"
    probe = subprocess.run(["ffmpeg", "-i", str(mp3), "-af", f"{pre},volumedetect", "-f", "null", "-"],
                           capture_output=True, text=True).stderr
    top = float(re.search(r"max_volume: (-?[0-9.]+) dB", probe).group(1))
    h, m, sec = re.findall(r"time=(\d+):(\d+):([0-9.]+)", probe)[-1]
    dur = int(h) * 3600 + int(m) * 60 + float(sec)
    chain = f"{pre},volume={peak - top:.2f}dB,afade=t=out:st={max(dur - 0.03, 0):.3f}:d=0.03"
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(mp3), "-af", chain,
                    "-ac", "1", "-ar", "44100", "-c:a", "libvorbis", "-q:a", "5", str(out)], check=True)


def main() -> None:
    if len(sys.argv) < 2 or sys.argv[1] not in SETS:
        sys.exit(f"usage: gen_sfx.py <{'|'.join(SETS)}> [cue ...]")
    board = sys.argv[1]
    flags = [a for a in sys.argv[2:] if a.startswith("--")]
    cues = [a for a in sys.argv[2:] if not a.startswith("--")] or list(SETS[board])
    out_dir = ROOT / "assets/sfx" / board
    out_dir.mkdir(parents=True, exist_ok=True)
    raw_dir = ROOT / "build/sfx_raw" / board
    raw_dir.mkdir(parents=True, exist_ok=True)
    for cue in cues:
        prompt, seconds, peak = SETS[board][cue]
        raw = raw_dir / f"{cue}.mp3"
        if "--new" in flags or not raw.exists():
            raw.write_bytes(generate(key(), prompt, seconds))
        out = out_dir / f"{cue}.ogg"
        to_ogg(raw, out, peak)
        print(f"{cue:9s} -> {out.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
