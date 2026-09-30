#!/usr/bin/env python3
"""Generate a board's sound effects with ElevenLabs' sound-generation API.

    python3 tools/gen_sfx.py binairo            # every cue of the set
    python3 tools/gen_sfx.py binairo place hint # only these
    python3 tools/gen_sfx.py binairo place --new  # a fresh take, not the cached one

Each cue is one prompt below, rendered once (the raw take is cached in build/sfx_raw/, so re-running
only reprocesses it; --new asks ElevenLabs again), trimmed of leading and trailing
silence, levelled to a peak and written to assets/sfx/<board>/<cue>.ogg, which
is exactly where ui/fx2d.gd's cue() looks. The key is read from
$ELEVENLABS_API_KEY or ~/.config/elevenlabs/api_key and never stored here; when
it runs out of credits the request is retried once on
$ELEVENLABS_API_KEY_FALLBACK or ~/.config/elevenlabs/api_key_fallback.
Needs ffmpeg on the PATH.
"""
import json, os, pathlib, re, subprocess, sys, tempfile, urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent
API = "https://api.elevenlabs.io/v1/sound-generation?output_format=mp3_44100_128"

# The palette every cue shares, so the set reads as one instrument family.
STYLE = ("cozy casual mobile puzzle game UI sound, soft warm wooden and "
         "marimba tones, gentle, rounded, no harsh transients, clean, dry, "
         "no music bed, no voice")

# Real-object sounds (a table's balls, not a toy's) take this instead of STYLE:
# the house style's "marimba, no harsh transients" turned a ball's clack into
# a soft wooden boop.
FOLEY = "realistic foley recording, dry, no music, no voice"

# The Arcade tab's games: a soft retro arcade voice rather than the house
# marimba, because a shooter's zaps and pops want a synth -- but warm and
# rounded, so it still sits beside the rest of the game.
ARCADE = ("retro arcade video game sound effect, soft warm 8-bit chiptune "
          "synth, rounded, gentle, not harsh, clean, dry, no music bed, no voice")

# Molehill's whacks: a cartoon's bonks and squeaks, because a mallet on a
# mole wants a comic thump more than a synth -- its jingles stay ARCADE.
CARTOON = ("cute cartoon comedy sound effect, playful, rounded, soft, not harsh, "
           "clean, dry, no music bed, no voice")

# The menu's page turn (2026-09-28): a hushed real-world brush, because the
# house marimba turned a paper swish into a tonal whine the user heard as
# robotic, and plain foley still came back thin.
COZY = "cozy, warm, soft, intimate, close mic, quiet room, no music, no voice"

# cue: (prompt, seconds, peak level in dBFS -- quieter for the chatty ones
#       [, style in place of STYLE [, "loop": a seamless loop, no trim or fade
#                                     | "fall": the take, then itself 3 semitones lower
#                                     | "warm:<Hz>": rolled off above <Hz> and eased in
#                                       over 4 ms, for a take that came back scratchy]])
SETS = {
    # The interface, not a board: every button's click (ui/ui_sound.gd).
    "ui": {
        "click":    ("a single tiny soft paper and wood click, pressing a small cozy button, very short and light", 0.5, -12),
        "page":     ("A soft hand brushing sideways across a linen tablecloth, one gentle muffled fabric swipe, warm and hushed", 0.5, -14, COZY),
    },
    "binairo": {
        "place":    ("a single soft wooden tile tap with a tiny bubbly pop, very short", 0.5, -6),
        "clear":    ("a very short soft downward whoosh-pop, a small token lifted off a wooden board", 0.5, -9),
        "brush":    ("a tiny soft paper click, selecting a pencil, very short and quiet", 0.5, -12),
        "undo":     ("a short soft reverse swish, like rewinding a tiny tape, playful", 0.6, -9),
        "hint":     ("a gentle magical sparkle chime, three soft glockenspiel notes rising", 1.0, -5),
        # check and blush_in re-prompted 2026-09-29 (insane polish): the low
        # marimba boops and the wooden "bonk" read as a scold, not a shrug.
        "check":    ("a gentle two-note melody on a soft kalimba: one note, then a second lower note, 'uh-oh' but kind, a cozy 'not quite yet', warm and round, never a buzzer", 1.0, -17, STYLE, "fall"),
        "check_ok": ("two soft bright marimba notes going up, a friendly 'all good' confirmation", 0.7, -5),
        "reset":    ("a quick ripple of many small soft wooden pops, tiles being swept off a board", 1.0, -8),
        "solved":   ("a warm short celebratory marimba and glockenspiel flourish, rising arpeggio ending on a bright sparkle, joyful and cozy", 2.0, -3),
        "line":     ("a short happy two-note soft kalimba pluck, a row completed", 0.6, -6),
        "blush_in": ("a tiny soft felt mallet tap on a small wooden block with a gentle little pitch dip, a shy muffled 'oops', very short and quiet", 0.5, -10),
        "enter":    ("a soft airy cascade of tiny wooden pops rolling in, a board of tiles appearing", 1.0, -9),
        # Hearts, streaks and rewards (2026-09-29 insane polish, spec section 3).
        "heart_lost":    ("a soft felt-mallet marimba two-note fall, a small gentle 'oh', warm and muffled, never a buzzer", 0.6, -15),
        "out_of_hearts": ("a sleepy three-note music box lullaby slowly descending, like a soft yawn, calm and kind, maybe tomorrow", 1.5, -14),
        "heart_back":    ("a warm rising pair of soft kalimba plucks, a little heart coming back, gentle and happy", 0.6, -15),
        "combo":         ("a single short bright soft kalimba pluck, one clean note, very short", 0.5, -8),
        "confetti":      ("a soft flutter of tiny paper confetti pieces falling with a tiny sparkling glockenspiel twinkle, light and airy", 1.0, -9),
        "line_silly":    ("a playful soft wooden boing, a springy muffled wood bounce with a tiny giggling kalimba trill on top, cute and short", 0.7, -7),
        "flawless":      ("a very quiet soft paper stamp tap followed by a loud clear warm glockenspiel chime, two bright rising notes ringing out and fading slowly, a gentle proud 'perfect'", 1.5, -5),
        "liar":          ("a sneaky tiptoeing soft pizzicato plucked string phrase, caught red-handed, cheeky and playful, light", 1.0, -7),
        "party":         ("a cozy celebratory kalimba and glockenspiel flourish rising, with a very soft muffled party blower toot at the end, joyful and warm", 2.0, -4),
    },
    # Code Break (puzzle_id "mastermind"): little round friends fly into
    # seats, a Check drops score pips into a pouch, lids lift on the answer.
    "mastermind": {
        "place":    ("a tiny soft bouncy boing and a wooden seat tap, a small round character hopping into a seat, very short", 0.5, -6),
        "clear":    ("a very short soft downward whoosh-pop, a small character hopping out of a wooden seat", 0.5, -9),
        # full, locked and check re-prompted 2026-09-29 (Code Break polish):
        # the wooden bumps and boops read as a scold, as Binairo's did.
        "full":     ("a tiny soft felt pat, a gentle muffled 'hmm, all full', a small cushion being patted twice, warm and quiet, very short", 0.5, -13),
        "locked":   ("a tiny soft kalimba note with a gentle little wobble, a kind 'this one stays', muffled and warm, very short", 0.5, -12),
        "undo":     ("a short soft reverse swish, like rewinding a tiny tape, playful", 0.6, -9),
        "hint":     ("a gentle magical sparkle chime, three soft glockenspiel notes rising", 1.0, -5),
        "check":    ("a gentle two-note melody on a soft kalimba: one note, then a second lower note, 'uh-oh' but kind, a cozy 'not quite yet', warm and round, never a buzzer", 1.0, -17, STYLE, "fall"),
        "score":    ("a soft cloth pouch settling on a wooden table, a tiny muffled flop, cozy and quiet", 0.6, -10),
        "reveal":   ("a soft wooden box lid lifting with a small curious kalimba shimmer, a secret being uncovered", 1.0, -6),
        "reset":    ("a quick ripple of many small soft wooden pops, pieces being swept off a board", 1.0, -8),
        "solved":   ("a warm short celebratory marimba and glockenspiel flourish, rising arpeggio ending on a bright sparkle, joyful and cozy", 2.0, -3),
        "enter":    ("a soft airy cascade of tiny wooden pops rolling in, a board of seats appearing", 1.0, -9),
        # The polish pass (2026-09-29, docs/superpowers/specs/2026-09-29-codebreak-polish-design.md).
        # note: layered under place and pitched up the pentatonic by seat, so
        # a filling row plays a little tune. pip: one per score pip, pitched
        # up a step each as it lands.
        "note":        ("a single short bright soft kalimba pluck, one clean note, very short", 0.5, -8),
        "pip":         ("a single small glass bead dropping into a soft cloth pouch, a tiny muted clink, very short", 0.5, -9),
        "warmer":      ("a warm rising three-note soft kalimba phrase, a happy little 'getting warmer', gentle", 0.8, -8),
        "so_close":    ("an excited rising soft marimba and glockenspiel run with a tiny sparkle at the top, 'so close!', joyful and warm", 1.0, -6),
        "all_here":    ("a playful bouncy soft wooden xylophone conga shuffle, small round characters dancing in a line, cute and cozy", 1.2, -7),
        "cool":        ("a laid-back soft kalimba slide down and back up, a cool little 'nice', with a tiny soft wooden click like sunglasses going on, relaxed and cute", 0.9, -8),
        "shuffle":     ("two small wooden cups sliding and hopping over each other on a table, soft wooden shuffle and two gentle taps landing, playful, a magician's cup game", 0.9, -7),
        "peek":        ("a tiny soft wooden lid lifting a crack and settling back with a very quiet tock, curious and cute", 0.6, -15),
        "stamp":       ("a very quiet soft paper stamp tap followed by a loud clear warm glockenspiel chime, two bright rising notes ringing out and fading slowly, proud", 1.5, -5),
        "party":       ("a cozy celebratory kalimba and glockenspiel flourish rising, with a very soft muffled party blower toot at the end, joyful and warm", 2.0, -4),
        "confetti":    ("a soft flutter of tiny paper confetti pieces falling with a tiny sparkling glockenspiel twinkle, light and airy", 1.0, -9),
        "out_of_rows": ("a sleepy three-note music box lullaby slowly descending, like a soft yawn, calm and kind, maybe tomorrow", 1.5, -14),
        "row_back":    ("a warm rising pair of soft kalimba plucks, a little extra chance, gentle and happy", 0.6, -12),
    },
    # Balance: a seesaw of fruit with secret weights (the scales it began as
    # are gone); a fruit settling in a cup, a beam that comes level chimes.
    "balance": {
        # step and refused re-prompted 2026-09-29 (sunset pass): the wooden
        # click and "bonk" read as a scold, as Binairo's and Code Break's did.
        "step":     ("a tiny soft felt thump, a small round fruit settling into a little wooden cup, cozy and quiet, very short", 0.5, -11),
        "level":    ("a soft bright two-note kalimba chime going up, a hanging scale settling perfectly level", 0.7, -6),
        "refused":  ("a tiny soft felt pat with a gentle little kalimba wobble, a kind 'this one stays put', muffled and warm, very short", 0.5, -12),
        "undo":     ("a short soft reverse swish, like rewinding a tiny tape, playful", 0.6, -9),
        "hint":     ("a gentle magical sparkle chime, three soft glockenspiel notes rising", 1.0, -5),
        "reset":    ("a quick soft run of little fruit hopping back into a wicker basket, gentle bumps and a light rustle", 1.0, -8),
        "solved":   ("a warm short celebratory marimba and glockenspiel flourish, rising arpeggio ending on a bright sparkle, joyful and cozy", 2.0, -3),
        "enter":    ("a wooden seesaw creaking once as it tips, then a small fruit landing on a plank with a soft thump", 1.0, -9),
        # The seesaw (2026-09-27): a fruit picked up, a fruit landing on the
        # plank (pitched by its weight in the board), the plank's end
        # bumping down on a hay bale, and the tock of the beam coming to rest.
        "lift":     ("a tiny soft pluck, a small round fruit lifted out of a wicker basket, very short", 0.5, -12, FOLEY),
        "land":     ("a small round apple dropped onto a wooden plank, one soft hollow wooden thump, close mic, very short", 0.5, -6, FOLEY),
        "thud":     ("the end of a wooden seesaw plank bumping down onto a soft hay bale, a cushioned muffled thump with a gentle straw rustle, cozy", 0.6, -8, FOLEY),
        "tock":     ("a single soft muted wooden tock, a gentle settle, very short", 0.5, -12),
        # The sunset pass (2026-09-29, docs/superpowers/specs/2026-09-29-balance-sunset-design.md):
        # Insane's springy bales, the sun going down on Hard and Insane, and
        # the silly rewards.
        "boing":     ("a playful soft springy cartoon boing, a hay bale bouncing like a spring, with a tiny rising slide whistle, cute and cozy, not harsh", 0.9, -6, CARTOON),
        "sunset":    ("a sleepy three-note music box lullaby slowly descending, like a soft yawn at dusk, calm and kind, maybe tomorrow", 1.6, -12),
        "hour_back": ("a warm rising pair of soft kalimba plucks with a tiny glockenspiel sparkle, the sun peeking back up, gentle and happy", 0.8, -10),
        "sun_low":   ("a single soft low warm kalimba note, gentle, a quiet 'the day is getting late', very short", 0.5, -14),
        "toss":      ("a light airy whoosh ending in a bright soft kalimba ting, a nice throw landing, playful", 0.7, -9),
        "giggle":    ("a tiny cute high giggling trill on a soft glockenspiel and kalimba, the sun giggling when tickled, playful, very short", 0.7, -10),
        "reveal":    ("a soft wooden box lid lifting with a small curious kalimba shimmer, a secret being uncovered", 1.0, -6),
        "stamp":     ("a very quiet soft paper stamp tap followed by a loud clear warm glockenspiel chime, two bright rising notes ringing out and fading slowly, proud", 1.5, -5),
        "party":     ("a cozy celebratory kalimba and glockenspiel flourish rising, with a very soft muffled party blower toot at the end, joyful and warm", 2.0, -4),
        "confetti":  ("a soft flutter of tiny paper confetti pieces falling with a tiny sparkling glockenspiel twinkle, light and airy", 1.0, -9),
    },
    # Untangle: pegs in a wooden ring, a thick cotton rope from each to its twin,
    # lifted into empty holes until no ropes cross. Re-prompted 2026-09-29
    # (the ring rebuild): real wood and rope in FOLEY, the kalimba for the
    # rewards; on Hard and Insane a needle and thread, and Insane's kitten.
    # The knots pass (same day): measured, not heard -- enter came back 94%
    # hiss above 6 kHz and pick, put, taut, stitch and reset 30-60%, against
    # a family (Balance, the rewards) mostly under 5%; those are warmed, enter
    # is re-prompted, and the braids get cinch, unwind and free.
    "untangle": {
        "pick":     ("a small smooth wooden peg pulled out of a snug wooden hole, one soft hollow pop with a light cotton rope rustle, cozy, close mic, very short", 0.5, -10, FOLEY, "warm:4200"),
        "drop":     ("a small wooden peg pressed into a wooden hole, one soft round hollow thock, cozy, close mic, very short", 0.5, -6, FOLEY),
        "put":      ("a tiny soft wooden peg tap, very quiet, very short", 0.5, -14, FOLEY, "warm:3800"),
        "refused":  ("a soft muffled rubbery rope stretch ending in a tiny kind wobbly kalimba note, a gentle 'not that far', warm, very short", 0.6, -10),
        "taut":     ("a thick cotton rope pulled tight, a soft creak and a low gentle twang, close mic, cozy", 0.7, -9, FOLEY, "warm:3500"),
        # The knots: a wrap drawn tighter, a wrap spinning free, a rope left
        # with nothing crossing it.
        "cinch":    ("a thick soft cotton rope drawn snug around another rope, one short muffled woolly squeeze and creak, cozy, close mic", 0.5, -10, FOLEY, "warm:3500"),
        "unwind":   ("a soft cotton rope unwinding and spinning loose with a gentle whirr, ending in one bright happy kalimba pluck, cozy", 0.8, -8, STYLE, "warm:6000"),
        "free":     ("a soft springy cotton rope boing with a tiny happy two-note kalimba lift, cute and cozy, very short", 0.6, -9, STYLE, "warm:6000"),
        "untie":    ("a tiny bright kalimba pluck going up with a soft rope loosening rustle, a knot coming undone, very short", 0.6, -8),
        "combo":    ("two or three soft rising kalimba and glockenspiel notes, a cheerful cozy little fanfare", 0.9, -7),
        "oops":     ("two soft wobbly descending marimba notes with a tiny cartoon slide, a gentle comic oops, not harsh", 0.7, -10),
        "undo":     ("a short soft reverse swish, like rewinding a tiny tape, playful", 0.6, -9),
        "hint":     ("a gentle magical sparkle chime, three soft glockenspiel notes rising", 1.0, -5),
        "reset":    ("many small wooden pegs and soft ropes sliding back into place, gentle clicks and a cloth rustle, close mic", 1.0, -9, FOLEY, "warm:4200"),
        "solved":   ("a warm short celebratory marimba and glockenspiel flourish, rising arpeggio ending on a bright sparkle, joyful and cozy", 2.0, -3),
        "enter":    ("four or five soft low wooden marimba ticks one after another, like small round pegs settling into a wooden ring, warm and gentle, no hiss", 1.0, -9, STYLE, "warm:5000"),
        # Thread (Hard and Insane).
        "stitch":      ("a tiny needle pulling thread through cloth, one very short soft zip, quiet, close mic", 0.5, -15, FOLEY, "warm:4000"),
        "thread_low":  ("a single soft low warm kalimba note, gentle, a quiet 'the thread is getting short', very short", 0.5, -12),
        "thread_out":  ("a sleepy three-note music box lullaby slowly descending with a soft yawn, calm and kind, maybe tomorrow", 1.6, -12),
        "spool_back":  ("a warm rising pair of soft kalimba plucks with a tiny sparkle and a light wooden spool spinning, gentle and happy", 0.9, -9),
        "reveal":      ("a soft curious kalimba shimmer with ropes sliding gently into place, a secret being revealed", 1.0, -6),
        # The seal and the party.
        "stamp":    ("a very quiet soft paper stamp tap followed by a loud clear warm glockenspiel chime, two bright rising notes ringing out and fading slowly, proud", 1.5, -5),
        "party":    ("a cozy celebratory kalimba and glockenspiel flourish rising, with a very soft muffled party blower toot at the end, joyful and warm", 2.0, -4),
        "confetti": ("a soft flutter of tiny paper confetti pieces falling with a tiny sparkling glockenspiel twinkle, light and airy", 1.0, -9, STYLE, "warm:7000"),
        # Insane's kitten.
        "pounce":   ("a tiny playful kitten mrrp and a soft paw swat, cute and cozy, very short", 0.8, -8, CARTOON),
        "purr":     ("a soft contented kitten purr with one tiny happy mew, cute and cozy, gentle", 1.2, -9, CARTOON),
    },
    # Shikaku: garden beds drawn as rectangles in soil around number stakes.
    "shikaku": {
        "select":   ("a single tiny soft wooden marimba tick, one light mallet tap, very short and quiet", 0.5, -12),
        "plot":     ("a soft short garden trowel pat in loose soil with a tiny wooden tap, a garden bed marked out", 0.5, -6),
        "hint":     ("a gentle magical sparkle chime, three soft glockenspiel notes rising", 1.0, -5),
        "check_ok": ("two soft bright marimba notes going up, a friendly 'all good' confirmation", 0.7, -5),
        "reset":    ("a soft brushing sweep across loose soil with a few small wooden pops, a garden raked clean", 1.0, -8),
        "solved":   ("a warm short celebratory marimba and glockenspiel flourish, rising arpeggio ending on a bright sparkle, joyful and cozy", 2.0, -3),
        "enter":    ("a soft airy cascade of tiny wooden pops rolling in, little garden stakes appearing", 1.0, -9),
        # clear, locked, undo and check re-prompted 2026-09-30 (Shikaku
        # polish): the bonk, the tape rewind and the wooden boops read as a
        # scold or a toy, as Binairo's and Code Break's did.
        "clear":    ("a soft hushed brush of a gloved hand over loose garden soil, one gentle muffled sweep, warm and quiet, very short", 0.5, -12, COZY),
        "locked":   ("a tiny soft kalimba note with a gentle little wobble, a kind 'this one stays', muffled and warm, very short", 0.5, -12),
        "undo":     ("a tiny soft felt pat and a small wooden kalimba note sliding gently down, a kind 'take that back', warm and quiet, very short", 0.5, -11),
        "check":    ("a gentle two-note melody on a soft kalimba: one note, then a second lower note, 'uh-oh' but kind, a cozy 'not quite yet', warm and round, never a buzzer", 1.0, -17, STYLE, "fall"),
        # The polish pass (2026-09-30, docs/superpowers/specs/2026-09-30-shikaku-polish-design.md).
        # combo: layered over plot and pitched up the pentatonic by the streak.
        "sprout":   ("a tiny soft green leaf unfurling with a small sweet bubbly pop, a seedling popping out of soft soil, cute and quiet, very short", 0.5, -12),
        "combo":    ("a single short bright soft kalimba pluck, one clean note, very short", 0.5, -8),
        "confetti": ("a soft flutter of tiny paper confetti pieces falling with a tiny sparkling glockenspiel twinkle, light and airy", 1.0, -9),
        "worm":     ("a tiny cute soft squeaky 'bloop' of a little worm popping out of soft soil, then a small playful wooden kalimba trill, silly and sweet", 0.9, -9),
        "cool":     ("a laid-back soft kalimba slide down and back up, a cool little 'nice', with a tiny soft wooden click like sunglasses going on, relaxed and cute", 0.9, -8),
        "twirl":    ("a quick soft playful wooden whirl, a small sign spinning round once with a light airy swish and a tiny happy glockenspiel ding at the end, cute", 0.7, -9),
        "heart_lost":    ("a soft felt-mallet marimba two-note fall, a small gentle 'oh', warm and muffled, like a flower drooping, never a buzzer", 0.6, -15),
        "out_of_hearts": ("a sleepy three-note music box lullaby slowly descending, like a soft yawn, calm and kind, maybe tomorrow", 1.5, -14),
        "heart_back":    ("a warm rising pair of soft kalimba plucks, a little heart coming back, gentle and happy", 0.6, -15),
        "stamp":    ("a very quiet soft paper stamp tap followed by a loud clear warm glockenspiel chime, two bright rising notes ringing out and fading slowly, proud", 1.5, -5),
        "party":    ("a cozy celebratory kalimba and glockenspiel flourish rising, with a very soft muffled party blower toot at the end, joyful and warm", 2.0, -4),
    },
    # Tents: pitch a tent beside each tree on a grassy campsite grid.
    "tents": {
        "hint":     ("a gentle magical sparkle chime, three soft glockenspiel notes rising", 1.0, -5),
        "check_ok": ("two soft bright marimba notes going up, a friendly 'all good' confirmation", 0.7, -5),
        "reset":    ("a quick soft ripple of canvas flaps and small wooden pops, tents being packed away", 1.0, -8),
        "solved":   ("a warm short celebratory marimba and glockenspiel flourish, rising arpeggio ending on a bright sparkle, joyful and cozy", 2.0, -3),
        "enter":    ("a soft airy cascade of tiny wooden pops and a light leafy rustle, a campsite of trees appearing", 1.0, -9),
        # The polish pass (2026-09-30, docs/superpowers/specs/2026-09-30-tents-polish-design.md):
        # place, locked, undo and check re-prompted toward felt and kalimba,
        # as Shikaku's were the same morning -- the bonk, the tape rewind and
        # the wooden boops read as a scold or a toy.
        "place":    ("a soft cozy canvas tent fabric whump with a tiny warm wooden peg tap, a little tent popping up, gentle and round, very short", 0.5, -7, COZY),
        "strike":   ("a soft hushed canvas fabric fold and flop, a small tent gently folded down, warm and muffled, very short", 0.5, -11, COZY),
        "locked":   ("a tiny soft kalimba note with a gentle little wobble, a kind 'this one stays', muffled and warm, very short", 0.5, -12),
        "undo":     ("a tiny soft felt pat and a small wooden kalimba note sliding gently down, a kind 'take that back', warm and quiet, very short", 0.5, -11),
        "check":    ("a gentle two-note melody on a soft kalimba: one note, then a second lower note, 'uh-oh' but kind, a cozy 'not quite yet', warm and round, never a buzzer", 1.0, -17, STYLE, "fall"),
        # cairn / clear tick per square of a sweep, pitched up as it grows.
        "cairn":    ("a single tiny soft click of two small smooth pebbles set on grass, very short and quiet", 0.5, -13, COZY),
        "clear":    ("a tiny soft brush of a hand over grass, one hushed light sweep, very short and quiet", 0.5, -14, COZY),
        # combo: layered over place and pitched up the pentatonic by the streak.
        "combo":    ("a single short bright soft kalimba pluck, one clean note, very short", 0.5, -8),
        "confetti": ("a soft flutter of tiny paper confetti pieces falling with a tiny sparkling glockenspiel twinkle, light and airy", 1.0, -9),
        "peek":     ("a tiny cute soft zipper unzip then a small happy 'hoo!' like a cheerful little kalimba trill, a camper peeking out of a tent to wave, silly and sweet, no voice", 0.9, -9),
        "cool":     ("a laid-back soft kalimba slide down and back up, a cool little 'nice', with a tiny soft wooden click like sunglasses going on, relaxed and cute", 0.9, -8),
        "bunny":    ("three tiny soft bouncy boings on grass getting quieter, a small bunny hopping past, cute and light", 0.9, -10),
        "oak":      ("a warm soft rustle of big oak leaves with two small glockenspiel notes rising, a happy old tree, gentle", 0.8, -9),
        "heart_lost":    ("a soft felt-mallet marimba two-note fall, a small gentle 'oh', warm and muffled, like a tent sagging, never a buzzer", 0.6, -15),
        "out_of_hearts": ("a sleepy three-note music box lullaby slowly descending, like a soft yawn by a campfire, calm and kind, maybe tomorrow", 1.5, -14),
        "heart_back":    ("a warm rising pair of soft kalimba plucks, a little heart coming back, gentle and happy", 0.6, -15),
        "stamp":    ("a very quiet soft paper stamp tap followed by a loud clear warm glockenspiel chime, two bright rising notes ringing out and fading slowly, proud", 1.5, -5),
        "party":    ("a cozy celebratory kalimba and glockenspiel flourish rising, with a very soft muffled party blower toot and a flutter of little flags at the end, joyful and warm", 2.0, -4),
    },
    # Light Up: paper lamps set down in a stone courtyard light their rows.
    "lightup": {
        "hint":     ("a gentle magical sparkle chime, three soft glockenspiel notes rising", 1.0, -5),
        "check_ok": ("two soft bright marimba notes going up, a friendly 'all good' confirmation", 0.7, -5),
        "reset":    ("a soft quick ripple of small wooden pops and a gentle airy puff, little lamps being blown out", 1.0, -8),
        "solved":   ("a warm short celebratory marimba and glockenspiel flourish, rising arpeggio ending on a bright sparkle, joyful and cozy", 2.0, -3),
        "enter":    ("a soft airy cascade of tiny wooden and stone pops rolling in, a courtyard of stones appearing", 1.0, -9),
        # The polish pass (2026-09-30, docs/superpowers/specs/2026-09-30-lightup-polish-design.md):
        # place, locked, undo and check re-prompted toward paper, felt and
        # kalimba, as Shikaku's and Tents' were the same day -- the bonk, the
        # tape rewind and the wooden boops read as a scold or a toy.
        "place":    ("a soft paper lantern gently set down on smooth stone with a tiny papery rustle and a warm little glow swelling, gentle and round, very short", 0.5, -7, COZY),
        "strike":   ("a lamp softly blown out, a tiny gentle breath and a small paper lantern settling, warm and hushed, very short", 0.5, -11, COZY),
        "locked":   ("a tiny soft kalimba note with a gentle little wobble, a kind 'this one stays', muffled and warm, very short", 0.5, -12),
        "undo":     ("a tiny soft felt pat and a small wooden kalimba note sliding gently down, a kind 'take that back', warm and quiet, very short", 0.5, -11),
        "check":    ("a gentle two-note melody on a soft kalimba: one note, then a second lower note, 'uh-oh' but kind, a cozy 'not quite yet', warm and round, never a buzzer", 1.0, -17, STYLE, "fall"),
        # chip / clear tick per stone of a sweep, pitched up as it grows.
        "chip":     ("a single tiny soft click of a small slate chip set down on a stone floor, very short and quiet", 0.5, -13, COZY),
        "clear":    ("a tiny soft brush of a hand over a smooth stone floor, one hushed light sweep, very short and quiet", 0.5, -14, COZY),
        # combo: layered over place and pitched up the pentatonic by the streak.
        "combo":    ("a single short bright soft kalimba pluck, one clean note, very short", 0.5, -8),
        "confetti": ("a soft flutter of tiny paper confetti pieces falling with a tiny sparkling glockenspiel twinkle, light and airy", 1.0, -9),
        "cool":     ("a laid-back soft kalimba slide down and back up, a cool little 'nice', with a tiny soft wooden click like sunglasses going on, relaxed and cute", 0.9, -8),
        "puff":     ("a little paper lantern puffing out a small soft smoke ring shaped like a heart, a gentle round 'poof' with a tiny sweet kalimba twinkle, silly and cute", 0.8, -9),
        "snail":    ("a tiny snail carrying a little lantern slides past, a soft slidey squeak and a tiny tinkling bell, cute and gentle", 1.0, -10),
        "moth":     ("a soft papery flutter of a small moth's wings arriving at a lantern, with a tiny glockenspiel twinkle, light and delicate", 0.8, -11, COZY),
        "purr":     ("a content little cat purring briefly on a soft cushion, cozy, soft and warm, short", 1.0, -10, COZY),
        "wake":     ("a small cat woken by a light, one short cross little mew, cute and grumpy, not a hiss, short", 0.6, -10, COZY),
        "heart_lost":    ("a soft felt-mallet marimba two-note fall, a small gentle 'oh', warm and muffled, like a lantern dimming, never a buzzer", 0.6, -15),
        "out_of_hearts": ("a sleepy three-note music box lullaby slowly descending, like a soft yawn by lantern light, calm and kind, maybe tomorrow", 1.5, -14),
        "heart_back":    ("a warm rising pair of soft kalimba plucks, a little heart coming back, gentle and happy", 0.6, -15),
        "stamp":    ("a very quiet soft paper stamp tap followed by a loud clear warm glockenspiel chime, two bright rising notes ringing out and fading slowly, proud", 1.5, -5),
        "party":    ("a cozy celebratory kalimba and glockenspiel flourish rising, with a very soft muffled party blower toot and a flutter of little paper lanterns at the end, joyful and warm", 2.0, -4),
        "lanterns": ("sky lanterns rising into the night, an airy warm whoosh drifting upward with a soft glockenspiel shimmer, gentle and magical", 2.0, -7),
    },
    # One Line: a snail walks every line between posts exactly once.
    "oneline": {
        "hint":     ("a gentle magical sparkle chime, three soft glockenspiel notes rising", 1.0, -5),
        "check_ok": ("two soft bright marimba notes going up, a friendly 'all good' confirmation", 0.7, -5),
        "solved":   ("a warm short celebratory marimba and glockenspiel flourish, rising arpeggio ending on a bright sparkle, joyful and cozy", 2.0, -3),
        "enter":    ("a soft airy cascade of tiny wooden pops rolling in, little wooden posts appearing", 1.0, -9),
        # The polish pass (2026-09-30, docs/superpowers/specs/2026-09-30-oneline-polish-design.md):
        # start, lay, locked, undo, check and reset re-prompted toward felt,
        # wood and kalimba, as Shikaku's, Tents' and Light Up's were the same
        # day -- the boing, the bonk, the tape rewind and the wooden boops
        # read as a toy or a scold. lay plays on every step, pitched up a
        # little with the streak, so it is the quietest and roundest.
        "start":    ("a tiny soft snail settling onto a small wooden post, a gentle felt pat and a tiny warm kalimba note, very short and cozy", 0.5, -9, COZY),
        "lay":      ("a single small wooden plank set down softly on a mossy path, a gentle hollow wooden tock with a tiny warm kalimba pluck, very short", 0.5, -9, COZY),
        "locked":   ("a tiny soft kalimba note with a gentle little wobble, a kind 'this one stays', muffled and warm, very short", 0.5, -12),
        "undo":     ("a tiny soft felt pat and a small wooden kalimba note sliding gently down, a kind 'take that back', warm and quiet, very short", 0.5, -11),
        "check":    ("a gentle two-note melody on a soft kalimba: one note, then a second lower note, 'uh-oh' but kind, a cozy 'not quite yet', warm and round, never a buzzer", 1.0, -17, STYLE, "fall"),
        "reset":    ("a soft quick ripple of small wooden planks being lifted and stacked gently, hollow soft wooden taps and a hushed brush, cozy", 1.0, -10, COZY),
        # Sunny Spells: a sunny line refused, and a dewy one after the sun.
        "sun":      ("a tiny warm 'phew, too hot' shimmer, a soft rising heat haze sound with one small muted kalimba note, gentle and cute, very short", 0.6, -12),
        "dew":      ("two tiny soft water droplets falling into a leaf with a gentle bright plink, refreshing and cozy, very short", 0.5, -11, COZY),
        "bloom":    ("a tiny soft flower opening, a delicate papery unfurl with a gentle single glockenspiel twinkle, very short and sweet", 0.6, -13),
        # The streak, the gags and the ladybugs.
        "combo":    ("a single short bright soft kalimba pluck, one clean note, very short", 0.5, -8),
        "confetti": ("a soft flutter of tiny paper confetti pieces falling with a tiny sparkling glockenspiel twinkle, light and airy", 1.0, -9),
        "cool":     ("a laid-back soft kalimba slide down and back up, a cool little 'nice', with a tiny soft wooden click like sunglasses going on, relaxed and cute", 0.9, -8),
        "love":     ("a few tiny soft bubbly pops rising with a sweet little two-note kalimba 'aww', little hearts floating up, cute and warm", 0.8, -10),
        "mushroom": ("a tiny cute mushroom popping out of soft moss, a soft squishy 'bloop' with a little happy rising boing, gentle and silly", 0.7, -10),
        "ladybug":  ("a tiny ladybug buzzing in and landing softly, a short delicate wing flutter with a tiny happy glockenspiel ting, cute and light", 0.8, -11, COZY),
        # Hearts, the wrong step's plank coming back up, and the party.
        "heart_lost":    ("a soft felt-mallet marimba two-note fall, a small gentle 'oh', warm and muffled, like a plank sagging, never a buzzer", 0.6, -15),
        "slip":     ("a small wooden plank lifting back up with a soft hollow creak and a gentle slide, warm and quiet, not scary, short", 0.6, -12, COZY),
        "out_of_hearts": ("a sleepy three-note music box lullaby slowly descending, like a soft yawn at dusk by a pond, calm and kind, maybe tomorrow", 1.5, -14),
        "heart_back":    ("a warm rising pair of soft kalimba plucks, a little heart coming back, gentle and happy", 0.6, -15),
        "stamp":    ("a very quiet soft paper stamp tap followed by a loud clear warm glockenspiel chime, two bright rising notes ringing out and fading slowly, proud", 1.5, -5),
        "party":    ("a cozy celebratory kalimba and glockenspiel flourish rising, with a very soft muffled party blower toot and a flutter of little flags at the end, joyful and warm", 2.0, -4),
        "petals":   ("a gentle breeze carrying many soft flower petals, an airy warm whoosh with a light sprinkle of tiny glockenspiel twinkles, dreamy and cozy", 2.0, -8),
    },
    # Nonogram: mosaic tiles laid on a floor by row and column clues. Re-
    # prompted toward felt, wood and kalimba on 2026-09-30, as One Line's,
    # Light Up's, Tents' and Shikaku's were: the tape rewind, the bonk and the
    # marimba boops read as a toy or a scold. place plays on every stroke, so
    # it is the quietest and roundest.
    "nonogram": {
        "place":    ("a single small glazed ceramic tile set down softly into a wooden tray, a gentle muted clack with a tiny warm kalimba pluck, very short", 0.5, -9, COZY),
        "locked":   ("a tiny soft kalimba note with a gentle little wobble, a kind 'this one stays', muffled and warm, very short", 0.5, -12),
        "undo":     ("a tiny soft felt pat and a small wooden kalimba note sliding gently down, a kind 'take that back', warm and quiet, very short", 0.5, -11),
        "hint":     ("a gentle magical sparkle, three soft glockenspiel notes rising with a warm felt kalimba underneath, cozy and kind", 1.0, -8),
        "check":    ("a gentle two-note melody on a soft kalimba: one note, then a second lower note, 'uh-oh' but kind, a cozy 'not quite yet', warm and round, never a buzzer", 1.0, -17, STYLE, "fall"),
        "check_ok": ("two soft warm kalimba notes going up, a friendly cozy 'all good', gentle and round", 0.7, -10),
        "reset":    ("a soft quick ripple of small ceramic tiles being lifted and stacked gently into a wooden box, hushed and cozy", 1.0, -10, COZY),
        "enter":    ("a soft airy cascade of tiny ceramic and wooden taps settling gently, a little mosaic floor laid out, cozy and hushed", 1.0, -11, COZY),
        "solved":   ("a warm short celebratory kalimba and glockenspiel flourish, rising arpeggio ending on a soft bright sparkle, joyful and cozy", 2.0, -4),
        # The streak, the gags, the daisies and the pebbles a finished line lays.
        "combo":    ("a single short bright soft kalimba pluck, one clean note, very short", 0.5, -8),
        "confetti": ("a soft flutter of tiny paper confetti pieces falling with a tiny sparkling glockenspiel twinkle, light and airy", 1.0, -9),
        "love":     ("a few tiny soft bubbly pops rising with a sweet little two-note kalimba 'aww', little hearts floating up, cute and warm", 0.8, -10),
        "mushroom": ("a tiny cute mushroom popping out of soft moss, a soft squishy 'bloop' with a little happy rising boing, gentle and silly", 0.7, -10),
        "bee":      ("a tiny cute bumblebee zooming past from left to right, a soft fuzzy buzz rising and falling with a tiny happy glockenspiel ting, gentle and funny", 1.2, -12, COZY),
        "bloom":    ("a tiny soft flower opening, a delicate papery unfurl with a gentle single glockenspiel twinkle, very short and sweet", 0.6, -14),
        "pebbles":  ("a quick soft ripple of tiny smooth pebbles set down one after another on wood, gentle little taps, cozy and satisfying", 0.8, -13, COZY),
        # Hearts, the wrong tile turned out, and the party.
        "heart_lost":    ("a soft felt-mallet marimba two-note fall, a small gentle 'oh', warm and muffled, never a buzzer", 0.6, -15),
        "slip":     ("a small ceramic tile lifted out of its socket with a soft hollow wooden pop, and a tiny pebble set down in its place, warm and quiet", 0.6, -12, COZY),
        "out_of_hearts": ("a sleepy three-note music box lullaby slowly descending, like a soft yawn at dusk, calm and kind, maybe tomorrow", 1.5, -14),
        "heart_back":    ("a warm rising pair of soft kalimba plucks, a little heart coming back, gentle and happy", 0.6, -15),
        "stamp":    ("a very quiet soft paper stamp tap followed by a loud clear warm glockenspiel chime, two bright rising notes ringing out and fading slowly, proud", 1.5, -5),
        "frame":    ("a small wooden picture frame set gently on a wall, a soft hollow wooden knock and a tiny warm chime, cozy and proud", 0.8, -10, COZY),
        "party":    ("a cozy celebratory kalimba and glockenspiel flourish rising, with a very soft muffled party blower toot and a flutter of little flags at the end, joyful and warm", 2.0, -4),
        "petals":   ("a gentle breeze carrying many soft flower petals, an airy warm whoosh with a light sprinkle of tiny glockenspiel twinkles, dreamy and cozy", 2.0, -8),
        "leaves":   ("a soft autumn breeze and a gentle shower of dry leaves drifting down and rustling, warm and cozy, with one tiny low kalimba note", 2.0, -9, COZY),
    },
    # Queens: a little crowned bee seated on a garden court; crosses are the
    # player's own marks and the ones the queens lay. Re-prompted toward felt,
    # wood, kalimba and soft wings on 2026-09-30, as Nonogram's were: the tape
    # rewind and the marimba "bonk" read as a toy or a scold. place plays on
    # every cross of a sweep, so it is the quietest and roundest.
    "queens": {
        "place":    ("a tiny soft felt tap on a wooden board with a very quick gentle wing flutter, a little bee settling on a flower, very short and hushed", 0.5, -9, COZY),
        "remove":   ("a very short soft felt brush and a tiny airy wing lift, a little bee rising off a flower, gentle and quiet", 0.5, -11, COZY),
        "locked":   ("a tiny soft kalimba note with a gentle little wobble, a kind 'not there', muffled and warm, very short", 0.5, -12),
        "undo":     ("a tiny soft felt pat and a small wooden kalimba note sliding gently down, a kind 'take that back', warm and quiet, very short", 0.5, -11),
        "hint":     ("a gentle magical sparkle, three soft glockenspiel notes rising with a warm felt kalimba underneath and a tiny wing flutter, cozy and kind", 1.0, -8),
        "check":    ("a gentle two-note melody on a soft kalimba: one note, then a second lower note, 'uh-oh' but kind, a cozy 'not quite yet', warm and round, never a buzzer", 1.0, -17, STYLE, "fall"),
        "check_ok": ("two soft warm kalimba notes going up, a friendly cozy 'all good', gentle and round", 0.7, -10),
        "reset":    ("a soft quick ripple of tiny felt pats and a light flutter of little wings, a garden court swept gently clear, hushed and cozy", 1.0, -10, COZY),
        "enter":    ("a soft airy cascade of tiny wooden taps and a light leafy rustle, a little garden court laid out, cozy and hushed", 1.0, -11, COZY),
        "solved":   ("a warm short celebratory kalimba and glockenspiel flourish, rising arpeggio ending on a soft bright sparkle, joyful and cozy", 2.0, -4),
        # The streak, the gags, and the flowers a patch opens once it has its queen.
        "combo":    ("a single short bright soft kalimba pluck, one clean note, very short", 0.5, -8),
        "confetti": ("a soft flutter of tiny paper confetti pieces falling with a tiny sparkling glockenspiel twinkle, light and airy", 1.0, -9),
        "love":     ("a few tiny soft bubbly pops rising with a sweet little two-note kalimba 'aww', little hearts floating up, cute and warm", 0.8, -10),
        "drone":    ("a tiny cute bumblebee buzzing in a quick little loop around a flower, a soft fuzzy buzz rising and falling, with a tiny happy glockenspiel ting at the end, gentle and funny", 1.2, -12, COZY),
        "twirl":    ("a tiny playful spin, a soft airy whirl with a light wing flutter ending on a small bright kalimba 'ta-da' pluck, cute and silly, very short", 0.8, -10),
        "bloom":    ("a tiny soft flower opening, a delicate papery unfurl with a gentle single glockenspiel twinkle, very short and sweet", 0.6, -14),
        # Hearts, the wrong queen flying off, and the party.
        "heart_lost":    ("a soft felt-mallet marimba two-note fall, a small gentle 'oh', warm and muffled, never a buzzer", 0.6, -15),
        "buzz_off": ("a little bee buzzing away sheepishly, a soft fuzzy buzz fading off into the distance with a tiny descending kalimba note, gentle and a bit funny", 0.8, -12, COZY),
        "out_of_hearts": ("a sleepy three-note music box lullaby slowly descending, like a soft yawn at dusk, calm and kind, maybe tomorrow", 1.5, -14),
        "heart_back":    ("a warm rising pair of soft kalimba plucks, a little heart coming back, gentle and happy", 0.6, -15),
        "stamp":    ("a very quiet soft paper stamp tap followed by a loud clear warm glockenspiel chime, two bright rising notes ringing out and fading slowly, proud", 1.5, -5),
        "party":    ("a cozy celebratory kalimba and glockenspiel flourish rising, with a very soft muffled party blower toot and a flutter of little wings at the end, joyful and warm", 2.0, -4),
        "dance":    ("a short cheerful little kalimba and soft hand-drum shuffle, four playful bouncy notes, a tiny happy dance, cozy and cute", 1.2, -9),
        # Insane: Morning Mist. The mist rolls in on the entrance and lifts at the party.
        "mist":     ("a soft cool morning breeze, a hushed airy whoosh drifting slowly with a faint distant wind chime, calm and cozy", 1.5, -13, COZY),
        "mist_lift": ("a soft warm breeze lifting away with a gentle rising shimmer of glockenspiel notes, sunlight breaking through, dreamy and cozy", 1.8, -9),
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
        "select":   ("a single tiny soft kalimba tick, one light plucked tine, very short and quiet, no reverb tail", 0.5, -12),
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
    # Caterpillar: drag from leaf 1 and every square grows the caterpillar a
    # segment; it eats the leaves in order. `step` fires on every square, so
    # it gets no file (docs/art/sound-direction.md).
    "caterpillar": {
        "place":    ("a tiny soft leafy rustle with a small wooden tick, a little caterpillar waking up, very short", 0.5, -11),
        "munch":    ("a tiny soft crisp leaf nibble, two quick gentle crunches with a small rising marimba blip, cute, very short", 0.5, -8),
        "refuse":   ("a tiny soft worried wobble, a muffled wooden 'bonk' with a slight pitch dip, gentle", 0.5, -10),
        "undo":     ("a short soft reverse swish, like rewinding a tiny tape, playful", 0.6, -9),
        "hint":     ("a gentle magical sparkle chime, three soft glockenspiel notes rising", 1.0, -5),
        "reset":    ("a soft quick descending ripple of leafy rustles, a caterpillar curling back up small", 1.0, -8),
        "solved":   ("a warm short celebratory marimba and glockenspiel flourish rising into a light airy flutter of butterfly wings, joyful and cozy", 2.0, -3),
        "enter":    ("a soft airy cascade of tiny wooden pops and a light leafy rustle, a little garden of leaves appearing", 1.0, -9),
    },
    # Sunbeam: drag a brass mirror or a copper cup along its wooden rail and
    # the light follows; wet every dewdrop, then the bud blooms. `step` fires
    # on every peg a drag crosses, so it gets no file
    # (docs/art/sound-direction.md).
    "sunbeam": {
        "lift":     ("a tiny soft brass click, a small mirror lifted off a wooden peg, very short", 0.5, -12),
        "step":     ("a single tiny soft wooden rail tick, a small brass piece passing a peg as it slides, very short and quiet", 0.5, -15),
        "slide":    ("a short soft wooden slide ending in a gentle brass tick, a mirror settling onto a peg, cozy", 0.5, -10),
        "drop":     ("a tiny soft brass tick on wood, very short and quiet", 0.5, -14),
        "dew":      ("a single tiny bright glass droplet chime, a dewdrop catching sunlight, soft glockenspiel, very short", 0.6, -9),
        "dry":      ("a soft gentle two-note downward marimba, not yet, warm and patient", 0.6, -10),
        "refuse":   ("a tiny soft muffled wooden 'bonk' with a slight pitch dip, gentle", 0.5, -10),
        "undo":     ("a short soft reverse swish, like rewinding a tiny tape, playful", 0.6, -9),
        "hint":     ("a gentle magical sparkle chime, three soft glockenspiel notes rising", 1.0, -5),
        "reset":    ("a soft quick descending ripple of wooden ticks, pieces sliding back along rails", 1.0, -8),
        "solved":   ("a warm celebratory glockenspiel and marimba flourish rising into a soft airy shimmer, a flower opening in morning sunlight, joyful and cozy", 2.0, -3),
        "enter":    ("a soft airy cascade of tiny brass clicks and a light warm shimmer, a greenhouse waking in the morning sun", 1.0, -9),
    },
    # Knight: a cream knight hops in Ls to take the rose king; rose knights
    # answer every hop. A catch slides the board back one move.
    "knight": {
        "hop":      ("a single soft wooden chess piece tap on a paper board, light and cozy, very short", 0.5, -10),
        "answer":   ("a lower softer felt-bottomed wooden chess piece tap, very short", 0.5, -12),
        "take":     ("a bright small wooden knock, one chess piece taking another, cozy, very short", 0.5, -9),
        "caught":   ("a soft gentle two-note downward marimba, not yet, warm and patient", 0.6, -10),
        "slide":    ("a short soft paper slide, pieces sliding back on a board", 0.5, -11),
        "refuse":   ("a tiny soft muffled wooden 'bonk' with a slight pitch dip, gentle", 0.5, -10),
        "undo":     ("a short soft reverse swish, like rewinding a tiny tape, playful", 0.6, -9),
        "hint":     ("a gentle magical sparkle chime, three soft glockenspiel notes rising", 1.0, -5),
        "reset":    ("a soft quick descending ripple of wooden ticks, chess pieces set back in place", 1.0, -8),
        "solved":   ("a warm celebratory marimba run rising, ending in a small wooden piece toppling over with a soft clack, joyful and cozy", 2.0, -3),
        "enter":    ("a soft airy cascade of tiny wooden taps, chess pieces being set on a paper board", 1.0, -9),
    },
    # Snooker (Versus, versus/snooker_screen.gd): real table sounds first --
    # resin balls and a leather tip -- kept soft, then the game's own marimba
    # for the verdicts. `clack` plays for every contact, pitched by speed.
    "snooker": {
        "strike":   ("a single leather cue tip striking a snooker cue ball, a crisp short tock, close mic, very short", 0.5, -8, FOLEY),
        "clack":    ("a single sharp clack of one resin snooker ball hitting another on a table, crisp click, close mic, very short, no echo", 0.5, -6, FOLEY),
        "cushion":  ("a single dull thump of a snooker ball bouncing off the rubber cushion of a snooker table rail, close mic, very short", 0.5, -8, FOLEY),
        "pot":      ("a snooker ball dropping into a leather pocket with a soft hollow thunk and a short roll, cozy", 0.8, -8, FOLEY),
        "roll":     ("continuous steady low rumble of snooker balls rolling across a felt cloth table, smooth, constant, no hits, no clicks", 3.0, -10, FOLEY, "loop"),
        "foul":     ("a soft gentle two-note downward kalimba, not yet, never a buzzer", 0.6, -9),
        "hint":     ("a gentle magical sparkle chime, three soft glockenspiel notes rising", 1.0, -5),
        "win":      ("a warm celebratory marimba run rising with a soft clack of snooker balls, joyful and cozy", 2.0, -3),
        "lose":     ("a soft warm three-note descending marimba, gentle and kind, good game", 1.4, -6),
    },
    # Chess (Versus, versus/chess_screen.gd): wooden pieces on a wooden board
    # as foley, the verdicts in the house marimba. `hop` is the knight's leap.
    "chess": {
        "lift":     ("a single small wooden chess piece lifted off a wooden board, a tiny soft felt scrape, close mic, very short", 0.5, -14, FOLEY),
        "place":    ("a single wooden chess piece set down on a wooden chessboard, a soft warm felt-bottomed knock, close mic, very short", 0.5, -7, FOLEY),
        "slide":    ("a wooden chess piece sliding briefly across a wooden board on felt, a short soft swish, close mic", 0.5, -14, FOLEY),
        "capture":  ("a wooden chess piece knocking another wooden chess piece over, a crisp wooden clack then a small tumble and roll, close mic, short", 0.8, -6, FOLEY),
        "castle":   ("two wooden chess pieces set down on a wooden board one right after the other, two soft knocks, close mic, short", 0.6, -7, FOLEY),
        "hop":      ("a short playful soft airy whoosh with a tiny springy boing, a little wooden horse leaping", 0.5, -12),
        "check":    ("two soft bright glockenspiel notes, a gentle alert, a king in danger, not alarming", 0.8, -7),
        "promote":  ("a gentle magical rising sparkle shimmer with a soft marimba swell, a small piece transforming", 1.2, -6),
        "refused":  ("a tiny soft worried wobble, a muffled wooden 'bonk' with a slight pitch dip, gentle", 0.5, -10),
        "hint":     ("a gentle magical sparkle chime, three soft glockenspiel notes rising", 1.0, -5),
        "enter":    ("a quick soft cascade of wooden chess pieces being set out on a wooden board one after another", 1.2, -9, FOLEY),
        "win":      ("a warm celebratory marimba and glockenspiel flourish, rising arpeggio ending on a bright sparkle, joyful and cozy", 2.0, -3),
        "lose":     ("a soft warm three-note descending marimba, gentle and kind, good game", 1.4, -6),
        "draw":     ("two soft even marimba notes, calm and balanced, a friendly handshake", 1.0, -6),
    },
    # Checkers (Versus, versus/checkers_screen.gd): round wooden draughts on
    # a wooden board as foley, the verdicts in the house marimba. `hop` is a
    # jump's take-off (pitched up a step a jump down a chain), `capture` the
    # piece squashed and tossed, `flip` a losing piece turning face down.
    "checkers": {
        "lift":     ("a single flat round wooden draughts piece lifted off a wooden board, a tiny soft scrape, close mic, very short", 0.5, -14, FOLEY),
        "place":    ("a single flat round wooden draughts piece set down on a wooden board, a soft warm wooden click, close mic, very short", 0.5, -7, FOLEY),
        "slide":    ("a flat round wooden draughts piece sliding briefly across a wooden board, a short soft swish, close mic", 0.5, -14, FOLEY),
        "hop":      ("a short playful soft airy whoosh with a tiny springy boing, a little wooden disc leaping", 0.5, -12),
        "capture":  ("one flat wooden draughts piece landing hard on another, a crisp wooden clack then a small coin-like spin and wobble settling, close mic, short", 0.8, -6, FOLEY),
        "crown":    ("a gentle magical rising sparkle shimmer with a small bright glockenspiel ding, a crown landing on a piece", 1.2, -6),
        "flip":     ("a single flat wooden draughts piece flipped over onto a wooden board, a soft quick tick-tock clack, close mic, very short", 0.5, -10, FOLEY),
        "refused":  ("a tiny soft worried wobble, a muffled wooden 'bonk' with a slight pitch dip, gentle", 0.5, -10),
        "hint":     ("a gentle magical sparkle chime, three soft glockenspiel notes rising", 1.0, -5),
        "enter":    ("a quick soft cascade of flat wooden draughts pieces dealt out on a wooden board one after another, little coin-like wobbles", 1.4, -9, FOLEY),
        "win":      ("a warm celebratory marimba and glockenspiel flourish, rising arpeggio ending on a bright sparkle, joyful and cozy", 2.0, -3),
        "lose":     ("a soft warm three-note descending marimba, gentle and kind, good game", 1.4, -6),
        "draw":     ("two soft even marimba notes, calm and balanced, a friendly handshake", 1.0, -6),
    },
    # Hedgehogs: rake autumn leaf piles off a lawn; hedgehogs sleep under
    # some. A wrong rake wakes one, grumpy -- a snuffle, never a buzzer.
    "hedgehogs": {
        "rake":     ("a short soft sweep of a rake through dry autumn leaves, cozy, very short", 0.5, -10),
        "gust":     ("a soft airy flurry of dry leaves blown off a lawn by a light breeze, cozy", 0.8, -9),
        "flag":     ("a small wooden twig pushed softly into a pile of dry leaves, very short", 0.5, -10),
        "unflag":   ("a small twig pulled out of dry leaves with a tiny rustle, very short", 0.5, -11),
        "woke":     ("a tiny grumpy hedgehog snuffle and huff, then a soft gentle two-note downward marimba, cute, never harsh", 0.9, -9),
        "chord":    ("two quick soft rake sweeps through dry leaves, very short", 0.5, -10),
        "refuse":   ("a tiny soft muffled wooden 'bonk' with a slight pitch dip, gentle", 0.5, -10),
        "check":    ("a soft two-note downward kalimba, gentle, not yet", 0.6, -9),
        "check_ok": ("a soft bright three-note rising kalimba, all good", 0.7, -8),
        "undo":     ("a short soft reverse swish, like rewinding a tiny tape, playful", 0.6, -9),
        "hint":     ("a gentle magical sparkle chime, three soft glockenspiel notes rising", 1.0, -5),
        "reset":    ("a soft rustle of leaves settling back onto a lawn, gentle", 1.0, -8),
        "solved":   ("a warm celebratory marimba run rising with a soft leaf flurry and tiny happy squeaks, joyful and cozy", 2.0, -3),
        "enter":    ("a soft airy rustle of autumn leaves settling onto grass", 1.0, -9),
    },
    # Super Slider: painted wooden blocks slid round a walnut tray until the
    # big one walks out of a little garden gate.
    "slider": {
        "lift":     ("a tiny soft wooden block lifted a hair off a wooden tray, a light dry tick, very short", 0.5, -13),
        "step":     ("a very short soft wooden block sliding one notch across a wooden tray, a tiny dry scrape", 0.5, -16),
        "bump":     ("a small soft muffled wooden knock, one wooden block nudging against another, gentle, very short", 0.5, -12),
        "slide":    ("a soft wooden block sliding to a stop on a smooth wooden tray and settling with a gentle tap, short", 0.5, -10),
        "drop":     ("a tiny soft wooden tap, a block set back down where it was, very short", 0.5, -14),
        "undo":     ("a short soft reverse swish, like rewinding a tiny tape, playful", 0.6, -9),
        "hint":     ("a gentle magical sparkle chime, three soft glockenspiel notes rising", 1.0, -5),
        "reset":    ("a quick soft ripple of wooden blocks sliding back into place on a tray", 1.0, -8),
        "gate":     ("a small wooden garden gate creaking open softly with a bright little kalimba note", 0.8, -8),
        "solved":   ("a warm short celebratory marimba and glockenspiel flourish, rising arpeggio ending on a bright sparkle, joyful and cozy", 2.0, -3),
        "enter":    ("a soft airy cascade of small wooden blocks being set down in a wooden tray", 1.0, -9),
    },
    # Marigold: the family's sun shoots a seed down through a pond garden of
    # flower buds; every bud it touches blooms with the next note of a rising
    # scale, the blooms are picked, and the last marigold is a full bloom.
    "marigold": {
        "shoot":    ("a soft round airy 'thoop', a small seed puffed out of a leaf tube, light and cute, very short", 0.5, -8),
        "hit":      ("a single clear soft glockenspiel note, one bell tone, bright and short with a quick natural decay, no other notes", 0.5, -8),
        "wall":     ("a tiny soft wooden tock, a small bead bouncing off a wooden post, very short", 0.5, -16),
        "clover":   ("a quick bright magical double chime with a soft shimmer, something splitting in two happily", 0.7, -8),
        "violet":   ("a sweet bright three-note rising kalimba sparkle, a special bonus found", 0.8, -6),
        "pop":      ("a single tiny soft petal pop, a small flower plucked, light and airy, very short", 0.5, -12),
        "pot":      ("a small bead dropping into a clay flowerpot with a hollow terracotta clunk and a happy little kalimba note going up", 0.8, -6),
        "free":     ("a cheerful short marimba jingle of three rising notes, a reward earned", 1.0, -6),
        "drain":    ("a very soft low airy swoosh fading down, a small bead falling away out of sight, gentle", 0.6, -14),
        "fever":    ("a swelling magical harp glissando rising up into a bright shimmering chime, a sudden wonderful moment, joyful", 1.8, -4),
        "roll":     ("a steady soft rolling tremolo on a low wooden marimba and a felt-mallet tom, a suspenseful drumroll, even and constant, no accents, no ending", 3.0, -8, STYLE, "loop"),
        "close":    ("a soft playful disappointed 'awww', two marimba notes sliding down with a little wooden wobble, a near miss, gentle and funny, never sad", 0.9, -8),
        "fever_pot":("a bright triumphant bell and marimba hit with a sparkling shimmer, a big prize won, joyful", 1.2, -4),
        "out":      ("a gentle soft two-note downward kalimba, a kind 'try again', never sad or harsh", 0.8, -9),
        "hint":     ("a gentle magical sparkle chime, three soft glockenspiel notes rising", 1.0, -5),
        "reset":    ("a soft airy cascade of tiny wooden pops and a light leafy rustle, a little garden growing back", 1.0, -8),
        "solved":   ("a joyful celebratory marimba and glockenspiel fanfare, a bright rising melody that lands on a big warm chord with sparkles, triumphant and cozy", 2.8, -3),
        "enter":    ("a soft airy cascade of tiny wooden pops and a light leafy rustle, a little evening garden appearing", 1.0, -9),
    },
    # Pixel Garden: copy a little picture onto a pegboard in beads; the
    # finished picture is ironed. `place` fires on every bead a stroke seats
    # (pitched a hair apart), so it is tiny and quiet.
    "pixelgarden": {
        "place":    ("a single tiny soft click, a small plastic bead dropped onto a peg of a pegboard, light and cute, very short", 0.5, -13),
        "lift":     ("a tiny soft plucking tick, a small bead pulled off a peg, very short and light", 0.5, -15),
        "pick":     ("a tiny soft rattle of a few small beads in a little wooden dish, very short", 0.5, -12),
        "peek":     ("a very short soft paper whoosh, a small card lifted up to look at", 0.5, -14),
        "refuse":   ("a tiny soft worried wobble, a muffled wooden 'bonk' with a slight pitch dip, gentle", 0.5, -10),
        "undo":     ("a short soft reverse swish, like rewinding a tiny tape, playful", 0.6, -9),
        "hint":     ("a gentle magical sparkle chime, three soft glockenspiel notes rising", 1.0, -5),
        "check":    ("a soft two-note downward kalimba, gentle, not yet", 0.6, -9),
        "check_ok": ("a soft bright three-note rising kalimba, all good", 0.7, -8),
        "reset":    ("a soft quick cascade of many small beads pouring back into a wooden dish", 1.0, -8),
        "iron":     ("a soft warm gentle steam puff and a slow shimmering glockenspiel glissando, a warm iron gliding over a finished bead picture, cozy", 1.6, -7),
        "solved":   ("a warm short celebratory marimba and glockenspiel flourish, rising arpeggio ending on a bright sparkle, joyful and cozy", 2.0, -3),
        "enter":    ("a soft airy handful of small beads poured gently into a wooden dish", 1.0, -10),
    },
    # Fairy Lights (puzzle_id "fairylights"): tap a piece of garden wire to
    # turn it; wire joined back to the post runs gold and wakes its lanterns.
    "fairylights": {
        "place":    ("a single soft wooden click with a tiny light wire tick, a small piece of garden wire turned a quarter, very short", 0.5, -8),
        "wake":     ("a single tiny warm glass twinkle, a little paper lantern softly lighting up, very short and delicate", 0.5, -12),
        "refuse":   ("a tiny soft worried wobble, a muffled wooden 'bonk' with a slight pitch dip, gentle", 0.5, -10),
        "undo":     ("a short soft reverse swish, like rewinding a tiny tape, playful", 0.6, -9),
        "hint":     ("a gentle magical sparkle chime, three soft glockenspiel notes rising", 1.0, -5),
        "reset":    ("a soft quick descending ripple of tiny glass twinkles fading out, garden lanterns dimming one after another", 1.0, -8),
        "solved":   ("a warm short celebratory marimba and glockenspiel flourish, rising arpeggio ending on a bright sparkle, joyful and cozy", 2.0, -3),
        "enter":    ("a soft airy cascade of tiny wooden pops and a light leafy rustle, a little evening garden appearing", 1.0, -9),
    },
    # Firefly (Arcade, arcade/firefly_screen.gd): a formation shooter in a
    # night garden. `shoot` fires several times a second, so it is short
    # and quiet; `beam` is the moth's silk beam, looped while it is open.
    "firefly": {
        "shoot":    ("a tiny soft bright 'pew', a small glowing spark shot upward, very short and light", 0.5, -14, ARCADE),
        "pop":      ("a small soft bubbly pop with a tiny sparkle, a little bug zapped, very short", 0.5, -9, ARCADE),
        "pop_moth": ("a bigger round pop with a bright sparkling chime burst, a big moth defeated, short and satisfying", 0.7, -6, ARCADE),
        "hurt":     ("a short hollow metallic 'donk', an armoured bug hit but not beaten yet, very short", 0.5, -9, ARCADE),
        "dive":     ("a descending soft whistling swoop, a bug diving down to attack, quick", 0.8, -13, ARCADE),
        "beam_open":("a rising shimmering sweep opening up, a tractor beam of light switching on, sci-fi but gentle", 0.8, -8, ARCADE),
        "beam":     ("a steady soft wavering shimmering hum, a tractor beam of light, continuous, even, no ending", 3.0, -12, ARCADE, "loop"),
        "captured": ("a sad wobbling descending warble, a little ship caught and pulled up into a beam", 1.2, -7, ARCADE),
        "carried":  ("a short low minor two-note chime, a ship lost", 0.8, -9, ARCADE),
        "rescue":   ("a bright happy rising arpeggio with sparkles, a friend set free", 1.0, -5, ARCADE),
        "docked":   ("a cheerful double chime click, two ships joining together, power up", 0.7, -5, ARCADE),
        "rogue":    ("an ominous short low synth warble, something turning against you", 0.8, -9, ARCADE),
        "ship_pop": ("a soft crunchy explosion burst fading into falling sparkles, the player's ship destroyed, not too loud", 1.2, -5, ARCADE),
        "start":    ("a short cheerful retro arcade game start jingle, a bouncy rising melody, about three seconds", 3.0, -4, ARCADE),
        "stage":    ("a short bright three-note fanfare, a new stage beginning", 1.2, -6, ARCADE),
        "clear":    ("a quick happy rising chime run, a wave cleared", 1.0, -6, ARCADE),
        "flyby":    ("a playful bouncy retro jingle, a bonus round starting", 1.8, -5, ARCADE),
        "result":   ("a short friendly score tally jingle, counting points up", 1.2, -6, ARCADE),
        "perfect":  ("a triumphant sparkling retro fanfare, a perfect bonus round, joyful", 2.2, -4, ARCADE),
        "extra":    ("a bright retro one-up jingle, an extra life earned, rising notes", 1.0, -5, ARCADE),
        "game_over":("a gentle slow descending retro melody, game over, soft and kind not sad", 2.2, -5, ARCADE),
        "new_best": ("a joyful celebratory retro fanfare with sparkles, a new high score", 2.4, -4, ARCADE),
    },
    # Molehill (Arcade, arcade/molehill_screen.gd): whack-a-mole on a lawn.
    # The whacks are cartoon bonks; pop_up and escape fire constantly, so
    # they sit low.
    "molehill": {
        "pop_up":      ("a tiny soft 'plop' of a small animal popping up out of a hole in the soil, very short", 0.5, -16, CARTOON),
        "whack":       ("a soft rubbery cartoon 'bonk' of a wooden mallet on a little head, with a tiny squeak, very short", 0.5, -6, CARTOON),
        "whack_gold":  ("a cartoon mallet 'bonk' followed by a bright jingle of coins and a sparkle, a golden prize, short", 0.8, -5, CARTOON),
        "clang":       ("a hollow clay flowerpot knocked by a wooden mallet, a round 'clonk' that rings a little, short", 0.5, -7, CARTOON),
        "crack":       ("a clay flowerpot cracking apart with a soft crunch and a cartoon 'bonk', short", 0.6, -6, CARTOON),
        "bunny":       ("a startled little cartoon rabbit squeak and a soft 'boing', oops, not hurt, short", 0.6, -6, CARTOON),
        "miss":        ("a soft dull thud of a wooden mallet on grass and soil, a miss, very short", 0.5, -10, CARTOON),
        "escape":      ("a tiny cheeky cartoon raspberry giggle of a little mole ducking back down a hole, very short", 0.5, -14, CARTOON),
        "combo":       ("a bright rising three-note chime with a sparkle, a combo multiplier going up, short", 0.7, -6, ARCADE),
        "streak_lost": ("a short soft descending two-note blip, a streak broken, gentle", 0.5, -10, ARCADE),
        "go":          ("a short bright cheerful 'go' horn blip of two rising notes, a round starts", 0.6, -5, ARCADE),
        "tick":        ("a single soft wooden clock tick with a tiny bell, a countdown second, very short", 0.5, -9, ARCADE),
        "frenzy":      ("an excited quick rising retro arpeggio with a drum roll, the last ten seconds, double points", 1.2, -5, ARCADE),
        "time_up":     ("a cheerful alarm clock 'brring' bell, very short, time is up", 0.8, -6, CARTOON),
        "start":       ("a short cheerful retro arcade game start jingle, a bouncy garden tune, about two seconds", 2.2, -4, ARCADE),
        "game_over":   ("a gentle slow descending retro melody, game over, soft and kind not sad", 2.2, -5, ARCADE),
        "new_best":    ("a joyful celebratory retro fanfare with sparkles, a new high score", 2.4, -4, ARCADE),
    },
    # Stackwood (Arcade, arcade/stackwood_screen.gd): numbered wooden toy
    # blocks that fall and merge. The blocks are CARTOON wood; the jingles
    # ARCADE. move and land fire on every block, so they sit low; merge is
    # pitched up the chain by the screen.
    "stackwood": {
        "move":      ("a tiny soft wooden tick, a toy block nudged one step sideways, very short", 0.5, -18, CARTOON),
        "drop":      ("a quick soft airy whoosh of a small wooden block dropping, very short", 0.5, -14, CARTOON),
        "land":      ("a soft hollow wooden toy block landing on a stack of blocks, a warm 'tock', very short", 0.5, -9, CARTOON),
        "merge":     ("two wooden toy blocks clicking together into one with a bright soft chime, satisfying, very short", 0.5, -6, CARTOON),
        "chain":     ("a quick bright rising three-note chime with a sparkle, a chain combo, short", 0.7, -6, ARCADE),
        "big":       ("a bright happy sparkling two-note chime, a new biggest block made, short", 0.8, -5, ARCADE),
        "milestone": ("a joyful triumphant retro fanfare with sparkles, the 2048 block reached, about two seconds", 2.2, -4, ARCADE),
        "wild":      ("a shimmering magical rainbow sparkle swirl, soft and bright, short", 0.8, -7, ARCADE),
        "buy":       ("a cheerful two-note purchase chime with a tiny coin, a power-up bought, short", 0.6, -7, ARCADE),
        "fuse":      ("a short soft cartoon fuse hiss and crackle, a little bomb lit, short", 0.7, -10, CARTOON),
        "bomb":      ("a soft round cartoon 'boom' with wooden blocks scattering, playful, not harsh, short", 0.9, -5, CARTOON),
        "zap":       ("a soft bright electric zap crackle, a playful lightning bolt, short", 0.7, -7, ARCADE),
        "refused":   ("a soft low short 'bonk' blip, not enough acorns, gentle, not harsh", 0.5, -10, ARCADE),
        "warn":      ("a soft worried two-note warning blip, a stack near the top, gentle not alarming", 0.6, -9, ARCADE),
        "retired":   ("a soft pop and a small descending sparkle, the smallest blocks retired, short", 0.6, -8, ARCADE),
        "topple":    ("a tall stack of wooden toy blocks toppling and tumbling down, a cascade of hollow wooden clatters, about a second and a half", 1.5, -5, CARTOON),
        "go":        ("a short bright cheerful 'go' blip of two rising notes, a game starts", 0.6, -5, ARCADE),
        "start":     ("a short cheerful retro arcade game start jingle, a bouncy toy-box tune, about two seconds", 2.2, -4, ARCADE),
        "game_over": ("a gentle slow descending retro melody, game over, soft and kind not sad", 2.2, -5, ARCADE),
        "new_best":  ("a joyful celebratory retro fanfare with sparkles, a new high score", 2.4, -4, ARCADE),
    },
    # Lucky Thirteen (Arcade, arcade/thirteen_screen.gd): numbered river
    # pebbles merged by drawing chains. The pebbles are CARTOON stone; the
    # jingles ARCADE. select fires on every pebble a chain takes and is
    # pitched up the chain by the screen, so it sits low; merge is pitched
    # up the numbers.
    "thirteen": {
        "select":     ("a single tiny soft click of a smooth river pebble tapped, bright and clean, very short", 0.5, -14, CARTOON),
        "unselect":   ("a tiny soft low tick, a small pebble set back down, very short", 0.5, -18, CARTOON),
        "short":      ("a soft low short 'bonk' blip, not enough pebbles, gentle, not harsh", 0.5, -10, ARCADE),
        "merge":      ("a few smooth pebbles clicking together into one with a bright soft chime, satisfying, very short", 0.6, -6, CARTOON),
        "land":       ("a tiny soft stone 'tock' of a pebble settling onto sand, very short", 0.5, -16, CARTOON),
        "new_number": ("a bright happy sparkling two-note chime, a new biggest number made, short", 0.8, -5, ARCADE),
        "goal":       ("a joyful triumphant retro fanfare with sparkles and a lucky chime, the number thirteen reached, about two seconds", 2.4, -4, ARCADE),
        "stuck":      ("a soft worried descending two-note blip, no moves left, gentle not alarming", 0.7, -8, ARCADE),
        "arm":        ("a soft quick click and a tiny rising blip, a tool picked up, short", 0.5, -10, ARCADE),
        "undo":       ("a short soft reverse swish, like rewinding a tiny tape, playful", 0.6, -8, ARCADE),
        "swap":       ("two small smooth pebbles swishing past each other and trading places, a quick airy double whoosh, short", 0.6, -8, CARTOON),
        "pluck":      ("a soft cartoon 'pop' of a small pebble plucked out of sand, short", 0.5, -7, CARTOON),
        "shuffle":    ("a handful of smooth pebbles rattled and shaken in a wooden tray, a quick rolling clatter, about a second", 1.0, -7, CARTOON),
        "lift":       ("a soft rising magical bloop with a sparkle, a pebble raised up one, short", 0.6, -7, ARCADE),
        "refused":    ("a soft low short 'bonk' blip, not allowed, gentle, not harsh", 0.5, -10, ARCADE),
        "tumble":     ("a trayful of smooth pebbles tipped out and tumbling, a cascade of soft stone clatters, about a second and a half", 1.5, -6, CARTOON),
        "start":      ("a short cheerful retro arcade game start jingle, a bouncy lucky little tune, about two seconds", 2.2, -4, ARCADE),
        "game_over":  ("a gentle slow descending retro melody, game over, soft and kind not sad", 2.2, -5, ARCADE),
        "new_best":   ("a joyful celebratory retro fanfare with sparkles, a new high score", 2.4, -4, ARCADE),
    },
    # Posy (Arcade, arcade/posy_screen.gd): a swap-three garden of flowers,
    # leaves, drops, mushrooms, berries and acorns. The garden's touches are
    # CARTOON; the specials' shimmer and the jingles ARCADE. match fires on
    # every cascade step and is pitched up the cascade by the screen, so it
    # sits low; collect fires on every tile landing on a goal, lower still.
    "posy": {
        "select":       ("a single tiny soft click, a small garden tile picked up, bright and clean, very short", 0.5, -14, CARTOON),
        "swap":         ("a quick soft airy double swish, two small tiles trading places, playful, short", 0.5, -10, CARTOON),
        "bad_swap":     ("a soft springy boing back, two tiles bumping and sliding back to where they were, gentle, short", 0.6, -10, CARTOON),
        "match":        ("a soft bubbly pop of three little flowers plucked at once, satisfying, very short", 0.5, -6, CARTOON),
        "land":         ("a tiny soft patter of small tiles settling into place, very short and quiet", 0.5, -18, CARTOON),
        "collect":      ("a tiny soft bright tick, a petal landing in a basket, very short", 0.5, -18, ARCADE),
        "made_breeze":  ("a soft rising whoosh with a bright shimmer, a magical breeze being made, short", 0.6, -8, ARCADE),
        "made_bomb":    ("a soft rising sparkle and a small warm hum, a seed bomb being made, short", 0.7, -8, ARCADE),
        "made_rainbow": ("a bright magical rising arpeggio shimmer, a rainbow flower appearing, about a second", 1.0, -6, ARCADE),
        "breeze":       ("a quick gust of wind sweeping across a garden, a clean whoosh with leaves rustling, short", 0.7, -6, CARTOON),
        "bomb":         ("a soft cartoon poof blast, a burst of seeds and petals, round and gentle not harsh, short", 0.7, -5, CARTOON),
        "rainbow":      ("a sparkling magical sweep, a shower of chimes flying out in every direction, about a second", 1.1, -5, ARCADE),
        "goal":         ("a bright happy two-note chime, a goal completed, short", 0.7, -6, ARCADE),
        "cheer":        ("a short joyful bright sparkle flourish, a big cascade, happy", 0.8, -7, ARCADE),
        "day_done":     ("a joyful short garden fanfare with sparkles, a day's goals completed, about two seconds", 2.0, -4, ARCADE),
        "deal":         ("a soft airy cascade of many small tiles tumbling into a wooden tray, about a second", 1.0, -9, CARTOON),
        "shuffle":      ("a handful of small wooden tiles shaken and rattled in a tray, a quick rolling clatter, about a second", 1.0, -8, CARTOON),
        "convert":      ("a soft magical twinkle, a tile turning special, short", 0.6, -9, ARCADE),
        "gift":         ("a cheerful little present chime with a sparkle, a tool earned, short", 0.8, -7, ARCADE),
        "trowel":       ("a small garden trowel digging into soft soil, a quick scoop and a soft pop, short", 0.6, -7, CARTOON),
        "arm":          ("a soft quick click and a tiny rising blip, a tool picked up, short", 0.5, -10, ARCADE),
        "refused":      ("a soft low short 'bonk' blip, not allowed, gentle, not harsh", 0.5, -10, ARCADE),
        "out_of_moves": ("a soft slow descending wobble, out of moves, gentle and kind, not sad", 1.0, -7, CARTOON),
        "start":        ("a short cheerful retro arcade game start jingle, a bouncy flowery little tune, about two seconds", 2.2, -4, ARCADE),
        "game_over":    ("a gentle slow descending retro melody, game over, soft and kind not sad", 2.2, -5, ARCADE),
        "new_best":     ("a joyful celebratory retro fanfare with sparkles, a new high score", 2.4, -4, ARCADE),
        # the genre pass (2026-09-28): the bee, the bed's ground, the offer
        "made_bee":     ("a soft cheerful buzzy little trill, a tiny bee appearing, playful, short", 0.6, -8, CARTOON),
        "bee":          ("a quick soft cartoon bee buzz zipping away, playful, short", 0.6, -8, CARTOON),
        "bee_hit":      ("a tiny soft cartoon 'bop' as a bee lands on a flower, very short", 0.5, -10, CARTOON),
        "weed":         ("a small tuft of grass pulled out of soft soil, a quick rip and a soft pop, short", 0.5, -9, CARTOON),
        "stone":        ("a small soft cartoon knock on a garden stone, a light crack, short", 0.5, -9, CARTOON),
        "stone_break":  ("a soft cartoon garden stone crumbling apart into pebbles, round not harsh, short", 0.7, -7, CARTOON),
        "moss":         ("a soft squishy creeping sound, moss spreading over a tile, gentle and slightly sneaky, short", 0.6, -10, CARTOON),
        "moss_clear":   ("a soft fluffy poof, a clump of moss plucked away, short", 0.5, -9, CARTOON),
        "offer":        ("a gentle hopeful two-note question chime, so close, not sad", 0.8, -7, ARCADE),
        "more_moves":   ("a bright cheerful rising sparkle, extra moves granted, short", 0.8, -6, ARCADE),
    },
    # Rings: lift the top ring off a wooden peg and drop it on an empty peg
    # or on its own colour; four of a colour fill a peg and lock it.
    "rings": {
        "lift":     ("a tiny soft hollow wooden ring sliding up off a smooth peg, a light airy lift, very short", 0.5, -12),
        "drop":     ("a single soft hollow wooden ring settling down onto a stack of rings on a peg, a gentle clack, very short", 0.5, -8),
        "lock":     ("a short happy two-note soft kalimba pluck with a tiny sparkle, a peg filled with one colour", 0.7, -6),
        "refused":  ("a tiny soft worried wobble, a muffled wooden 'bonk' with a slight pitch dip, gentle", 0.5, -10),
        "undo":     ("a short soft reverse swish, like rewinding a tiny tape, playful", 0.6, -9),
        "hint":     ("a gentle magical sparkle chime, three soft glockenspiel notes rising", 1.0, -5),
        "reset":    ("a quick soft ripple of hollow wooden rings clacking down onto pegs, a set being put back", 1.0, -8),
        "solved":   ("a warm short celebratory marimba and glockenspiel flourish, rising arpeggio ending on a bright sparkle, joyful and cozy", 2.0, -3),
        "enter":    ("a soft airy cascade of tiny hollow wooden clacks rolling in, stacks of rings on pegs appearing", 1.0, -9),
    },
    # Drumbeat (puzzles/drumbeat2d.gd): the drum-festival rhythm game. don
    # and ka, the player's own drum, are synthesised by tools/gen_drumbeat.py
    # with the songs, not generated here: the takes were late, too quiet
    # under the music and did not sound like a drum.
    "drumbeat": {
        "balloon":      ("a tiny soft rubbery squeak of a balloon being squeezed, very short", 0.5, -12, CARTOON),
        "pop":          ("a balloon popping with a cheerful bang and a tiny confetti sparkle, short", 0.7, -4, CARTOON),
        "balloon_gone": ("a small balloon slowly deflating and flying off with a comic squeaky whistle, short", 0.9, -9, CARTOON),
        "gogo":         ("a festive rising whoosh with a bright shimmer and a small gong, the party begins, short", 1.4, -5, ARCADE),
        "soul":         ("a bright short rising chime with a sparkle, a meter filling past its line", 0.8, -7, ARCADE),
        "combo":        ("a short bright festival bell flourish, three quick rising notes", 0.7, -8, ARCADE),
        "break":        ("a short soft comic descending wobble, a drumstick fumbled, gentle", 0.5, -12, CARTOON),
        "select":       ("a single tiny soft wooden click, choosing a song, very short", 0.5, -12),
        "start":        ("a short festival drum roll on a taiko building into one big hit, get ready", 1.6, -5, FOLEY),
        "clear":        ("a festive celebratory jingle on marimba and small bells, a song cleared, joyful, about two seconds", 2.4, -4, ARCADE),
        "full_combo":   ("a triumphant festive fanfare on bells and marimba ending on a big drum hit and sparkles, a perfect performance", 2.8, -3, ARCADE),
        "fail":         ("a gentle short descending marimba phrase, a kind try again, soft and warm not sad", 2.0, -6, ARCADE),
        "new_best":     ("a joyful celebratory retro fanfare with sparkles, a new high score", 2.4, -4, ARCADE),
        "tick":         ("a single soft wooden clock tick with a tiny bell, very short", 0.5, -9, ARCADE),
    },
    # Trestle (puzzles/trestle2d.gd): a bridge built of road planks, wooden
    # beams and rope over a river, then a little cart sent across. The
    # building is the house marimba; the test is foley and cartoon, because
    # a beam snapping wants to sound like wood.
    "trestle": {
        "enter":      ("a soft airy cascade of small wooden knocks and a river's gentle burble, a building site by a stream appearing", 1.0, -9),
        "select":     ("a single tiny soft wooden click, choosing a tool, very short", 0.5, -12),
        "place_road": ("a wooden plank laid down on a frame with one solid soft knock and a tiny nail tap, very short", 0.5, -7, FOLEY),
        "place_wood": ("a light wooden beam set into place with a soft hollow knock and a small bolt click, very short", 0.5, -8, FOLEY),
        "place_rope": ("a rope pulled taut with a soft creak and a quick knot tug, very short", 0.5, -9, FOLEY),
        "remove":     ("a wooden beam lifted off a frame with a soft clatter, very short", 0.5, -9, FOLEY),
        "refused":    ("a tiny soft worried wobble, a muffled wooden 'bonk' with a slight pitch dip, gentle", 0.5, -10),
        "undo":       ("a short soft reverse swish, like rewinding a tiny tape, playful", 0.6, -9),
        "hint":       ("a gentle magical sparkle chime, three soft glockenspiel notes rising", 1.0, -5),
        "reset":      ("a quick soft clatter of small wooden beams being gathered up and stacked", 1.0, -8, FOLEY),
        "go":         ("a cheerful little toy train whistle toot and a small cart starting to roll, short", 1.2, -6, CARTOON),
        "roll":       ("continuous steady soft rumble of small wooden cart wheels rolling over wooden planks, even, no bumps, no clicks", 3.0, -12, FOLEY, "loop"),
        "creak":      ("a single long low creak of a wooden beam straining under weight, close mic", 0.8, -8, FOLEY),
        "snap":       ("a wooden beam snapping in two with a sharp crack and a splintering crunch, close mic, short", 0.7, -4, FOLEY),
        "snap_rope":  ("a taut rope snapping with a quick twang and a whip crack, short", 0.6, -5, FOLEY),
        "whoa":       ("a short comic cartoon falling slide whistle going down, gentle", 0.8, -8, CARTOON),
        "bump":       ("a small wooden cart landing with a soft thump and a wheel rattle, short", 0.5, -8, FOLEY),
        "splash":     ("a small wooden cart falling into a river with a big cartoon splash and bubbles, short", 1.0, -5, CARTOON),
        "fail":       ("a gentle short descending marimba phrase, a kind try again, soft and warm not sad", 1.4, -7),
        "cross":      ("a small cart reaching the other side, two cheerful toy horn honks, short", 0.8, -6, CARTOON),
        "solved":     ("a warm short celebratory marimba and glockenspiel flourish, rising arpeggio ending on a bright sparkle, joyful and cozy", 2.0, -3),
    },
    # the gifts, the shop and the gold pill (spec 2026-09-28-gold-gifts), keyed
    # by the sheets' own puzzle_id "wallet"
    "wallet": {
        "claim":    ("a small gift box opening with a soft paper rustle then a bright shower of little gold coins jingling, cheerful, short", 1.2, -5),
        "buy":      ("a few small gold coins dropped onto a wooden counter with a soft happy chime, short", 0.7, -7),
        "coin":     ("a single tiny soft gold coin clink, very short", 0.5, -14),
        "refused":  ("a soft low wooden double knock, a gentle not yet, very short", 0.5, -10),
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


def fallback_key() -> str:
    """A second key for when the first runs out of credits:
    $ELEVENLABS_API_KEY_FALLBACK or ~/.config/elevenlabs/api_key_fallback."""
    k = os.environ.get("ELEVENLABS_API_KEY_FALLBACK", "").strip()
    if not k:
        p = pathlib.Path.home() / ".config/elevenlabs/api_key_fallback"
        if p.exists():
            k = p.read_text().strip()
    return k


def generate(api_key: str, prompt: str, seconds: float, style: str = STYLE, loop: bool = False) -> bytes:
    body = {
        "text": f"{prompt}. {style}",
        "duration_seconds": seconds,
        "prompt_influence": 0.6,
    }
    if loop:
        body["loop"] = True
        body["model_id"] = "eleven_text_to_sound_v2"
    body = json.dumps(body).encode()
    req = urllib.request.Request(API, data=body, method="POST", headers={
        "xi-api-key": api_key, "Content-Type": "application/json", "Accept": "audio/mpeg"})
    try:
        with urllib.request.urlopen(req, timeout=120) as r:
            return r.read()
    except urllib.error.HTTPError as e:
        detail = e.read().decode(errors='replace')[:400]
        # Out of credits on this key: go again on the fallback key, once.
        spare = fallback_key()
        if "quota_exceeded" in detail and spare and spare != api_key:
            print("  quota exceeded, retrying on the fallback key")
            return generate(spare, prompt, seconds, style, loop)
        sys.exit(f"ElevenLabs answered {e.code}: {detail}")


def to_ogg(mp3: pathlib.Path, out: pathlib.Path, peak: int, loop: bool = False, warm: int = 0) -> None:
    # Trim silence at both ends (reverse trick for the tail) with a low
    # threshold and a little padding, so a soft ripple is not eaten; then
    # scale to a peak level (loudnorm misbehaves on sub-second clips) and
    # fade the last 30 ms so nothing clicks off.
    #
    # Each stage is its own file, because inside one filter chain ffmpeg
    # decides for itself where the stereo-to-mono fold happens, and the
    # level came out anything from 3 dB hot to 5 dB short depending on it.
    # The trim runs on the stereo take (in mono it cut audible ring-outs),
    # the fold is written as 32-bit float (it can pass full scale), and the
    # peak is read off that mono file with astats -- volumedetect measures
    # in 16-bit and reads anything over full scale as exactly 0 dB.
    # A loop keeps every sample: a trim or a fade would put a gap in its seam.
    trim = "anull" if loop else "silenceremove=start_periods=1:start_threshold=-60dB:start_silence=0.01"
    # Warm (2026-09-29, Untangle): a take whose hiss or scratch sits above the
    # cozy family is rolled off -- two gentle low-pass poles and a high shelf
    # -- and eased in so its first transient is a touch rather than a click.
    soft = f",lowpass=f={warm}:p=2,highshelf=f={warm // 2}:g=-4,afade=t=in:d=0.004" if warm else ""
    with tempfile.TemporaryDirectory() as tmp:
        mono = pathlib.Path(tmp) / "mono.wav"
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(mp3),
                        "-af", f"{trim},areverse,{trim},areverse{soft}",
                        "-ac", "1", "-c:a", "pcm_f32le", str(mono)], check=True)
        probe = subprocess.run(["ffmpeg", "-i", str(mono), "-af",
                                "astats=measure_overall=Peak_level:measure_perchannel=none",
                                "-f", "null", "-"], capture_output=True, text=True).stderr
        top = float(re.search(r"Peak level dB: (-?[0-9.]+)", probe).group(1))
        dur = float(subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration",
                                    "-of", "csv=p=0", str(mono)], capture_output=True, text=True).stdout)
        chain = f"volume={peak - top:.2f}dB" if loop else \
            f"volume={peak - top:.2f}dB,afade=t=out:st={max(dur - 0.03, 0):.3f}:d=0.03"
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(mono), "-af", chain,
                        "-ar", "44100", "-c:a", "libvorbis", "-q:a", "5", str(out)], check=True)


def fall(mp3: pathlib.Path) -> pathlib.Path:
    # A two-note "not yet" built from one note: the API gave Binairo's check a
    # single kalimba hit three takes running (2026-09-29), however the prompt
    # asked for two. The first note is cut at 0.22 s, the same take a minor
    # third lower comes in at 0.2 s.
    out = mp3.with_name(mp3.stem + "_fall.wav")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(mp3), "-filter_complex",
                    "[0]asplit[a][b];"
                    "[a]atrim=0:0.22,afade=t=out:st=0.17:d=0.05[n1];"
                    "[b]asetrate=44100*0.8409,aresample=44100,adelay=200|200[n2];"
                    "[n1][n2]amix=inputs=2:normalize=0:duration=longest",
                    str(out)], check=True)
    return out


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
        prompt, seconds, peak, *rest = SETS[board][cue]
        style = rest[0] if rest else STYLE
        loop = "loop" in rest[1:]
        warm = next((int(f[5:]) for f in rest[1:] if isinstance(f, str) and f.startswith("warm:")), 0)
        raw = raw_dir / f"{cue}.mp3"
        if "--new" in flags or not raw.exists():
            raw.write_bytes(generate(key(), prompt, seconds, style, loop))
        out = out_dir / f"{cue}.ogg"
        if "fall" in rest[1:]:
            raw = fall(raw)
        to_ogg(raw, out, peak, loop, warm)
        print(f"{cue:9s} -> {out.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
