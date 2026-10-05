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

# The Arcade tab's jingles and chimes. Until 2026-10-05 this was a soft
# 8-bit chiptune synth ("a shooter's zaps and pops want a synth"); the user
# asked for cozy and never synth, so every one of them is a real kalimba,
# music box, tongue drum or hand bell now, the family the polished boards
# share, and no prompt under it says retro, blip, zap or synth.
ARCADE = ("real acoustic kalimba, wooden music box, wooden tongue drum and "
          "small hand bells recorded close in a warm quiet room, natural, "
          "soft, rounded, gentle, cozy, no synth, no electronic tones, no "
          "beeps, no music bed, no voice")

# Firefly's night garden (2026-10-05): what is not a note in a shooter --
# the shot, a pop, a dive, the silk beam -- is close-mic foley of glass,
# paper and air, in place of the chiptune's pews and tractor beam.
NIGHT = ("close-mic foley recorded in a quiet garden on a warm summer night, "
         "real small glass jars and glass bells, paper, silk and soft leaves, "
         "natural and acoustic, soft and warm, rounded, no synth, no "
         "electronic tones, no beeps, no music, no voice")

# Molehill's whacks: a cartoon's bonks and squeaks, because a mallet on a
# mole wants a comic thump more than a synth -- its jingles stay ARCADE.
CARTOON = ("cute cartoon comedy sound effect, playful, rounded, soft, not harsh, "
           "clean, dry, no music bed, no voice")

# The menu's page turn (2026-09-28): a hushed real-world brush, because the
# house marimba turned a paper swish into a tonal whine the user heard as
# robotic, and plain foley still came back thin.
COZY = "cozy, warm, soft, intimate, close mic, quiet room, no music, no voice"

# Peapod's vegetable patch and Lucky Thirteen's riverbed (2026-10-05): the
# user "really really hates" both games' sounds, "it's annoying". What they
# had was CARTOON bonks, boings and a slide whistle under a gun that never
# stops, so everything that is a thing is close-mic foley, low and muffled,
# and what is a note is ARCADE's kalimba and music box.
PEAPATCH = ("close-mic foley of a small vegetable patch on a quiet sunny "
            "afternoon, real dried peas, small soft pine crates, straw, "
            "canvas and felt, natural and acoustic, soft and warm, rounded, "
            "never sharp, no synth, no electronic tones, no beeps, no music, "
            "no voice")
RIVERBED = ("close-mic foley of smooth round river pebbles on damp sand and "
            "in a shallow wooden tray, recorded in a quiet room, natural and "
            "acoustic, low, soft and warm, muffled, rounded, never sharp, no "
            "synth, no electronic tones, no beeps, no music, no voice")

# Fairy Lights' garden at dusk (2026-09-30): glass chimes, a music box and
# kalimba in place of the house marimba, which turns a lantern into a woodblock.
DUSK = ("cozy casual mobile puzzle game sound, soft warm glass chimes, music "
        "box and kalimba tones, gentle, rounded, no harsh transients, clean, "
        "dry, no music bed, no voice")

# Paper Planes' sky (2026-09-30): soft paper, felt, kalimba and a music box,
# with gentle breaths of air, in place of the house marimba.
BREEZE = ("cozy casual mobile puzzle game sound, soft paper, felt, warm kalimba "
          "and music box tones, gentle breaths of air, rounded, no harsh "
          "transients, clean, dry, no music bed, no voice")

# Pinwheel's sewing basket on a breezy porch (2026-10-01): soft paper
# whirrs, linen and felt, kalimba and a music box, in place of the house
# marimba.
LINEN = ("cozy casual mobile puzzle game sound, soft paper pinwheel whirrs, "
         "linen and felt, warm kalimba and music box tones, gentle breeze, "
         "rounded, no harsh transients, clean, dry, no music bed, no voice")

# Rings' sunny terrace (2026-10-01): soft hollow wooden rings on felt-capped
# dowels, warm kalimba and a music box, a hush of leaves, in place of the
# house marimba (whose undo was a tape rewind).
TERRACE = ("cozy casual mobile puzzle game sound, soft hollow wooden rings "
           "on smooth wooden dowels, felt, warm kalimba and music box tones, "
           "a sunny garden terrace, rounded, no harsh transients, clean, dry, "
           "no music bed, no voice")

# Caterpillar's sunny clover garden (2026-10-01): soft felt and leaf rustles,
# tiny wooden ticks, kalimba and a music box, in place of the house marimba
# (whose undo was a tape rewind and whose refuse was a wooden bonk).
CLOVER = ("cozy casual mobile puzzle game sound in a sunny clover garden, "
          "soft felt and leaf rustles, tiny wooden ticks, warm kalimba and "
          "music box tones, hushed, rounded, never harsh, no buzzers, no synth "
          "beeps, clean, dry, no music bed, no voice")

# Sunbeam's sunlit greenhouse (2026-10-01): soft glass and music box chimes,
# felt-soft brass ticks on wood, kalimba and airy shimmers, in place of the
# house marimba (whose undo was a tape rewind and whose refuse a wooden bonk).
GLASSHOUSE = ("cozy casual mobile puzzle game sound in a warm sunlit greenhouse, "
              "soft glass and music box chimes, felt-soft little brass ticks on "
              "wood, warm kalimba, gentle airy shimmer, hushed, rounded, never "
              "harsh, no buzzers, no synth beeps, clean, dry, no music bed, no voice")

# Knight's garden table in the sun (2026-10-01): felt-bottomed wooden toy
# pieces on paper, kalimba and a music box, leaves and a breeze, in place of
# the house marimba (whose undo was a tape rewind and refuse a wooden bonk).
PADDOCK = ("cozy casual mobile puzzle game sound on a sunny garden table, "
           "soft felt-bottomed wooden toy pieces on paper, warm kalimba and "
           "music box tones, a hush of leaves, hushed, rounded, never harsh, "
           "no buzzers, no synth beeps, clean, dry, no music bed, no voice")

# Hedgehogs' autumn lawn at dusk (2026-10-01): dry leaves, a soft bamboo
# rake, felt and wooden toy taps, kalimba, a music box and a little moon bell,
# in place of the house marimba (whose undo was a tape rewind and refuse a
# wooden bonk).
HARVEST = ("cozy casual mobile puzzle game sound on an autumn lawn at dusk, "
           "soft dry leaves, felt-soft little wooden taps, warm kalimba and "
           "music box tones, hushed, rounded, never harsh, no buzzers, no synth "
           "beeps, clean, dry, no music bed, no voice")

# Super Slider's walnut tray (2026-10-01): players heard the first set as
# synthetic, so a block's sounds are close-mic foley of real hardwood on felt
# and the rewards a real kalimba and music box, recorded, never synth.
WALNUT = ("close-mic foley of real smooth painted hardwood toy blocks on a "
          "felt-lined walnut tray, recorded in a quiet cozy room, natural and "
          "acoustic, soft and warm, rounded, no synth, no electronic tones, no "
          "beeps, no music, no voice")
WALNUT_TUNE = ("real acoustic kalimba and wooden music box recorded close in a "
               "warm quiet room, natural, soft, rounded, gentle, no synth, no "
               "electronic tones, no beeps, no music bed, no voice")

# Marigold's dusk pond (2026-10-01 polish): the first set was the house
# marimba and glockenspiel, thin next to the boards re-recorded the same
# day, so a seed's world is close-mic foley of a real garden (seeds, clay,
# water, leaves) and every note a real kalimba, music box or hand bell,
# recorded, never synth, rolled off above 7 kHz where it hisses.
POND = ("close-mic foley recorded in a quiet garden by a pond at dusk, real "
        "seeds, clay pots, soft leaves and water, natural and acoustic, soft "
        "and warm, rounded, no synth, no electronic tones, no beeps, no music, "
        "no voice")
POND_TUNE = ("real acoustic kalimba, wooden music box and small hand bells "
             "recorded close in a warm quiet room, natural, soft, rounded, "
             "gentle, cozy, no synth, no electronic tones, no beeps, no music "
             "bed, no voice")

# Pixel Garden's bead box (2026-10-01 polish): the first set was the house
# glockenspiel, marimba and a tape-rewind undo, thin beside the boards re-
# recorded the same day, so a bead's world is close-mic foley of the real
# kit -- small plastic fuse beads, a clear plastic compartment box, steel
# tweezers, a pegboard, a warm iron on paper -- and every note a real
# kalimba, music box or hand bell, recorded, never synth, rolled off above
# 7 kHz where it hisses.
BEADBOX = ("close-mic foley of a real craft table on a quiet afternoon, small "
           "plastic fuse beads, a clear plastic compartment box, steel tweezers, "
           "a plastic pegboard and a warm iron on baking paper, natural and "
           "acoustic, soft and warm, rounded, no synth, no electronic tones, no "
           "beeps, no music, no voice")
BEADBOX_TUNE = ("real acoustic kalimba, wooden music box and small hand bells "
                "recorded close in a warm quiet room, natural, soft, rounded, "
                "gentle, cozy, no synth, no electronic tones, no beeps, no music "
                "bed, no voice")

# Drumbeat's band (2026-10-01 polish): the first set was retro arcade synth
# and cartoon, loud beside the boards re-recorded the same day, so its world
# is close-mic foley of a garden festival at dusk -- hand drums struck
# softly, paper lanterns, small party balloons, confetti -- and every note a
# real kalimba, music box, wooden tongue drum or hand bell, never synth.
FESTIVAL = ("close-mic foley of a small cozy garden festival at dusk, real soft "
            "hand drums, wooden beads, paper lanterns and party balloons, "
            "natural and acoustic, soft and warm, rounded, no synth, no "
            "electronic tones, no beeps, no music, no voice")
FESTIVAL_TUNE = ("real acoustic kalimba, wooden music box, wooden tongue drum and "
                 "small hand bells recorded close in a warm quiet room, natural, "
                 "soft, rounded, gentle, cozy, no synth, no electronic tones, no "
                 "beeps, no music bed, no voice")

# Trestle's riverside workshop (2026-10-01 polish): the first set mixed the
# house marimba, cartoon whistles and a synth-ish tape rewind, loud beside
# the boards re-recorded the same day, so a bridge's world is close-mic
# foley of a wooden toy workshop by a stream -- small pine planks, hemp rope,
# brass bolts, a wooden toy cart, real china teacups, a gentle brook -- and
# every note a real kalimba, music box or hand bell, never synth.
WORKSHOP = ("close-mic foley of a small cozy wooden toy workshop beside a gentle "
            "stream, real small pine planks, hemp rope, brass bolts, a wooden "
            "toy cart and china teacups, natural and acoustic, soft and warm, "
            "rounded, no synth, no electronic tones, no beeps, no music, no voice")
WORKSHOP_TUNE = ("real acoustic kalimba, wooden music box and small hand bells "
                 "recorded close in a warm quiet room, natural, soft, rounded, "
                 "gentle, cozy, no synth, no electronic tones, no beeps, no music "
                 "bed, no voice")

# Mini Golf's course on a garden lawn (2026-10-05): a real ball, a putter, a
# wooden kerb and a plastic cup, with the garden family's kalimba, music box
# and hand bells for what the card says.
LINKS = ("close-mic foley of a small garden mini golf course on a quiet sunny "
         "lawn, a real golf ball, a putter, wooden kerbs, felt, sand and a "
         "plastic cup, natural and acoustic, soft and warm, rounded, no synth, "
         "no electronic tones, no beeps, no music, no voice")
LINKS_TUNE = ("real acoustic kalimba, wooden music box and small hand bells "
              "recorded close in a warm quiet room, natural, soft, rounded, "
              "gentle, cozy, no synth, no electronic tones, no beeps, no music "
              "bed, no voice")

# cue: (prompt, seconds, peak level in dBFS -- quieter for the chatty ones
#       [, style in place of STYLE [, "loop": a seamless loop, no trim or fade
#                                     | "fall": the take, then itself 3 semitones lower
#                                     | "warm:<Hz>": rolled off above <Hz> and eased in
#                                       over 4 ms, for a take that came back scratchy
#                                     | "cut:<s>": only the take's first <s> seconds, for a
#                                       tick the API keeps doubling (Marigold's wall, pop)
#                                     | "tight": the lead-in trimmed at -36 dB, not -60, for
#                                       a tap that must land on its frame (Peapod's hit came
#                                       back 60 ms behind a breath of room noise)]])
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
        "undo":     ("a tiny soft felt brush and one small kalimba note gliding gently down, a kind 'take that back', warm and quiet, very short", 0.6, -9),
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
        "undo":     ("a tiny soft felt brush and one small kalimba note gliding gently down, a kind 'take that back', warm and quiet, very short", 0.6, -9),
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
        "undo":     ("a tiny soft felt brush and one small kalimba note gliding gently down, a kind 'take that back', warm and quiet, very short", 0.6, -9),
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
        "undo":     ("a tiny soft felt brush and one small kalimba note gliding gently down, a kind 'take that back', warm and quiet, very short", 0.6, -9),
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
    # paper keyboard, Enter turns the row over a tile at a time, on a
    # parchment card in a little meadow. Insane is Snail Mail: a little snail
    # carries each row's colours and delivers them one row late (the row
    # turns over as sealed kraft-paper envelopes first). Re-prompted toward
    # felt, paper, kalimba and glockenspiel on 2026-09-30, as Queens' were:
    # the wooden "bonk" read as a scold. type fires on every key, so it is the
    # quietest, roundest and shortest; flip plays five times a row, 4% higher
    # per tile, so it is very short and soft.
    "hiddenword": {
        "type":     ("a single tiny soft felt tap on a paper key, one muffled round little tick, typing on a cozy paper keyboard, extremely short and hushed", 0.5, -14, COZY),
        "erase":    ("a tiny soft paper brush and a small felt pat, a letter gently taken back, very short and quiet", 0.5, -14, COZY),
        "flip":     ("a single very short soft papery card flick, a small parchment tile turning over, light and hushed", 0.5, -12, COZY),
        "refused":  ("a tiny soft kalimba note with a gentle little wobble, a kind 'not quite a word', muffled and warm, very short, never a buzzer", 0.5, -12),
        "hint":     ("a gentle magical sparkle, three soft glockenspiel notes rising with a warm felt kalimba underneath and a light paper rustle, cozy and kind", 1.0, -8),
        "reset":    ("a soft quick ripple of tiny felt pats and a light flutter of paper cards, a parchment card swept gently clear, hushed and cozy", 1.0, -10, COZY),
        "solved":   ("a warm short celebratory kalimba and glockenspiel flourish, rising arpeggio ending on a soft bright sparkle, joyful and cozy", 2.0, -4),
        "lost":     ("a gentle warm three-note soft felt kalimba phrase slowly descending and resolving softly, a kind 'maybe tomorrow', calm, not sad, never a buzzer", 1.5, -9),
        "enter":    ("a soft airy cascade of tiny paper cards settling and a light leafy rustle, a little parchment card of letters laid out in a meadow, cozy and hushed", 1.0, -11, COZY),
        # The streak, the row's reactions and the gags.
        "combo":    ("a single short bright soft kalimba pluck, one clean note, very short", 0.5, -8),
        "warmer":   ("a cheerful little two-note rising kalimba 'ooh!', soft and warm, getting warmer, short", 0.6, -10),
        "so_close": ("a slightly excited three-note rising melody on soft kalimba and glockenspiel, a happy 'so close!', warm and bright, short", 0.8, -8),
        "all_here": ("a playful little soft hand-drum and kalimba conga shuffle, bouncy and cute, every friend has arrived, cozy", 1.2, -9),
        "cool":     ("a laid-back cool little slide, a soft whistle-like kalimba glide gently down then back up, relaxed and pleased, cozy", 0.8, -10),
        "love":     ("a few tiny soft bubbly pops rising with a sweet little two-note kalimba 'aww', little hearts floating up, cute and warm", 0.8, -10),
        "twirl":    ("a tiny playful spin, a soft airy whirl ending on a small bright kalimba 'ta-da' pluck, cute and silly, very short", 0.8, -10),
        "sprout":   ("a tiny leaf popping out of the soil, a soft papery unfurl with a gentle single glockenspiel twinkle, very short and sweet", 0.6, -12),
        "confetti": ("a soft flutter of tiny paper confetti pieces falling with a tiny sparkling glockenspiel twinkle, light and airy", 1.0, -9),
        "party":    ("a cozy celebratory kalimba and glockenspiel flourish rising, with a very soft muffled party blower toot and a flutter of little paper flags at the end, joyful and warm", 2.0, -4),
        "dance":    ("a short cheerful little kalimba and soft hand-drum shuffle, four playful bouncy notes, a tiny happy dance, cozy and cute", 1.2, -9),
        "stamp":    ("a very quiet soft paper stamp tap followed by a loud clear warm glockenspiel chime, two bright rising notes ringing out and fading slowly, proud", 1.5, -5),
        "ready":    ("a tiny soft two-note kalimba blip going up, a little 'ready', very short and quiet", 0.5, -13),
        # Out of rows: the tiles sag, a lullaby, and a row given back.
        "droop":    ("a soft slow descending felt-mallet marimba slide, sleepy and kind, little tiles sagging gently, warm and muffled, never a buzzer", 0.8, -13),
        "out_of_rows": ("a sleepy three-note music box lullaby slowly descending, like a soft yawn at dusk, calm and kind, maybe tomorrow", 1.5, -14),
        "row_back": ("a warm rising pair of soft kalimba plucks, one more row, gentle and happy", 0.6, -12),
        # Insane: Snail Mail.
        "post":     ("a soft papery envelope folding shut and a tiny felt tap, a little letter sealed, very short and quiet", 0.5, -13, COZY),
        "snail":    ("a tiny cute snail sliding slowly, a soft gentle squishy slide with a light paper rustle, ending on a small happy kalimba ting, a little letter delivered, cute and cozy", 1.2, -11, COZY),
        "snail_hurry": ("a tiny cute snail scurrying quickly, a soft quick squishy patter ending in a bright little glockenspiel ding, good news travels fast, cute and funny", 0.8, -10, COZY),
    },
    # Word Trail (puzzle_id "wordtrail"): drag a trail through letter tiles;
    # only a right word locks, and a ribbon of colour runs along it.
    # Re-prompted toward felt, paper and kalimba on 2026-09-30 (polish pass,
    # docs/superpowers/specs/2026-09-30-word-trail-polish-design.md): the
    # wooden pops read as clatter beside Hidden Word's new set. select fires
    # on every tile a finger takes, 5% higher each, so it is the quietest and
    # shortest. Hard and Insane spend a dandelion's seeds on wrong trails
    # (wish, droop, out_of_wishes, wish_back); Insane is Night Walk, the
    # field in the dark but for a little lantern (lantern, dawn).
    "wordtrail": {
        "select":   ("a single tiny soft felt-tipped kalimba tick, one light muffled plucked tine, extremely short and hushed, no reverb tail", 0.5, -15),
        "place":    ("a short bright rising soft kalimba run of four notes with a gentle silky ribbon swish, a hidden word found, warm and cozy", 0.8, -7),
        "undo":     ("a soft short paper slide backwards with a tiny felt pat, a ribbon gently rolled back up, hushed and cozy", 0.6, -12, COZY),
        "hint":     ("a gentle magical sparkle, three soft glockenspiel notes rising with a warm felt kalimba underneath and a light paper rustle, cozy and kind", 1.0, -8),
        "reset":    ("a soft quick ripple of tiny felt pats and a light flutter of paper, colourful ribbons swept gently off a parchment card, hushed and cozy", 1.0, -10, COZY),
        "solved":   ("a warm short celebratory kalimba and glockenspiel flourish, rising arpeggio ending on a soft bright sparkle, joyful and cozy", 2.0, -4),
        "enter":    ("a soft airy cascade of tiny paper cards settling and a light leafy rustle, a little field of letter tiles laid out in a meadow, cozy and hushed", 1.0, -11, COZY),
        # Rewards: the streak, the word's reactions and its gags.
        "combo":    ("a single short bright soft kalimba pluck, one clean note, very short", 0.5, -9),
        "streak":   ("a cheerful quick three-note rising kalimba and glockenspiel run, on a roll, bright and happy, short", 0.7, -9),
        "big":      ("a pleased little 'ooh' on soft kalimba, two notes up then a third higher with a small glockenspiel sparkle, a big word found, warm", 0.8, -9),
        "quick":    ("a tiny fast whoosh of air ending on one bright soft kalimba ping, quick as a wink, cute and short", 0.5, -11),
        "love":     ("a few tiny soft bubbly pops rising with a sweet little two-note kalimba 'aww', little hearts floating up, cute and warm", 0.8, -10),
        "conga":    ("a playful little soft hand-drum and kalimba conga shuffle, bouncy and cute, letters dancing in a line, cozy", 1.2, -10),
        "flutter":  ("a tiny butterfly fluttering away, soft quick papery wing flaps with a light rising glockenspiel twinkle, delicate and sweet", 0.8, -12, COZY),
        "twirl":    ("a tiny playful spin, a soft airy whirl ending on a small bright kalimba 'ta-da' pluck, cute and silly, very short", 0.8, -10),
        # A wrong trail on Hard and Insane blows a dandelion seed away.
        "miss":     ("a tiny soft kalimba note with a gentle little downward wobble, a kind 'not that one', muffled and warm, very short, never a buzzer", 0.5, -13),
        "wish":     ("a soft little breath of air blowing a dandelion seed away, a gentle airy puff with a faint high glockenspiel shimmer drifting off, delicate and cozy", 0.8, -13, COZY),
        "wish_low": ("two soft low kalimba notes, a gentle careful 'hmm', only a few wishes left, warm and kind, not worried", 0.6, -13),
        "droop":    ("a soft slow descending felt-mallet marimba slide, sleepy and kind, little tiles sagging gently, warm and muffled, never a buzzer", 0.8, -13),
        "out_of_wishes": ("a sleepy three-note music box lullaby slowly descending, like a soft yawn at dusk, calm and kind, maybe tomorrow", 1.5, -14),
        "wish_back": ("a warm rising pair of soft kalimba plucks with a tiny airy puff, a new dandelion clock growing back, gentle and happy", 0.7, -12),
        "reveal":   ("a single soft low felt kalimba note with a light paper ribbon unrolling, a word shown gently, calm, not sad", 0.6, -13),
        "lost":     ("a gentle warm three-note soft felt kalimba phrase slowly descending and resolving softly, a kind 'maybe tomorrow', calm, not sad, never a buzzer", 1.5, -9),
        # The party.
        "bloom":    ("a soft little flourish of flowers popping open, several tiny papery pops rising in pitch with a light glockenspiel twinkle, a meadow blooming, sweet", 1.0, -10),
        "party":    ("a cozy celebratory kalimba and glockenspiel flourish rising, with a very soft muffled party blower toot and a flutter of little paper flags at the end, joyful and warm", 2.0, -4),
        "dance":    ("a short cheerful little kalimba and soft hand-drum shuffle, four playful bouncy notes, a tiny happy dance, cozy and cute", 1.2, -9),
        "confetti": ("a soft flutter of tiny paper confetti pieces falling with a tiny sparkling glockenspiel twinkle, light and airy", 1.0, -9),
        "stamp":    ("a very quiet soft paper stamp tap followed by a loud clear warm glockenspiel chime, two bright rising notes ringing out and fading slowly, proud", 1.5, -5),
        # Insane: Night Walk.
        "lantern":  ("a tiny soft warm glow switching on, a gentle hushed airy 'fwoom' of a little paper lantern being lit with one faint glockenspiel note, very short and quiet", 0.5, -16, COZY),
        "dawn":     ("a slow soft sunrise swell, warm gentle glockenspiel and kalimba notes rising and brightening with a faint morning birdsong chirp, peaceful and cozy", 2.0, -8),
    },
    # Mushroom Patch: plant a mushroom where one must be, lay a pebble where
    # none can be; nothing is ever revealed by a tap. Re-prompted toward
    # felt, moss, paper and kalimba on 2026-09-30 (the polish), as Queens'
    # and Word Trail's were: the tape-rewind undo and the wooden "bonk" read
    # as a toy or a scold. Hard and Insane judge a mushroom as she lands: a
    # wrong one costs a heart and wilts back into the soil. Insane is Fairy
    # Rings: some numbers count the ring two steps out.
    "mushroom": {
        "place":    ("a tiny soft squishy pop out of thick moss with a light felt tap, a little mushroom popping up, cute and hushed, very short", 0.5, -9, COZY),
        "pebble":   ("a single tiny smooth pebble set down gently on soft moss, one muffled round little stone tap, very short and quiet", 0.5, -12, COZY),
        "remove":   ("a very short soft felt brush and a tiny airy lift, a little mushroom pulled gently out of moss, quiet", 0.5, -12, COZY),
        "locked":   ("a tiny soft kalimba note with a gentle little wobble, a kind 'not there', muffled and warm, very short", 0.5, -12),
        "undo":     ("a tiny soft felt pat and a small wooden kalimba note sliding gently down, a kind 'take that back', warm and quiet, very short", 0.5, -11),
        "hint":     ("a gentle magical sparkle, three soft glockenspiel notes rising with a warm felt kalimba underneath and a tiny leafy rustle, cozy and kind", 1.0, -8),
        "check":    ("a gentle two-note melody on a soft kalimba: one note, then a second lower note, 'uh-oh' but kind, a cozy 'not quite yet', warm and round, never a buzzer", 1.0, -17, STYLE, "fall"),
        "check_ok": ("two soft warm kalimba notes going up, a friendly cozy 'all good', gentle and round", 0.7, -10),
        "reset":    ("a soft quick ripple of tiny felt pats and a light leafy rustle, a mossy forest patch swept gently clear, hushed and cozy", 1.0, -10, COZY),
        "enter":    ("a soft airy cascade of tiny moss pops and a light leafy rustle, a little forest patch laid out, cozy and hushed", 1.0, -11, COZY),
        "solved":   ("a warm short celebratory kalimba and glockenspiel flourish, rising arpeggio ending on a soft bright sparkle, joyful and cozy", 2.0, -4),
        # Pressing a number lights the cells it counts.
        "reach":    ("a very soft short airy shimmer, one faint glockenspiel note with a hushed breath, a little glow switching on, extremely quiet and short", 0.5, -18, COZY),
        # The streak, the gags, and the flower a finished number opens.
        "combo":    ("a single short bright soft kalimba pluck, one clean note, very short", 0.5, -8),
        "confetti": ("a soft flutter of tiny paper confetti pieces falling with a tiny sparkling glockenspiel twinkle, light and airy", 1.0, -9),
        "love":     ("a few tiny soft bubbly pops rising with a sweet little two-note kalimba 'aww', little hearts floating up, cute and warm", 0.8, -10),
        "twirl":    ("a tiny playful spin, a soft airy whirl ending on a small bright kalimba 'ta-da' pluck, cute and silly, very short", 0.8, -10),
        "sneeze":   ("a tiny cute squeaky cartoon sneeze 'achoo' from a very small creature followed by a soft sparkly puff of dust, silly and adorable, very short", 0.8, -12, CARTOON),
        "bloom":    ("a tiny soft flower opening, a delicate papery unfurl with a gentle single glockenspiel twinkle, very short and sweet", 0.6, -14),
        # Hearts, the wrong mushroom wilting, and the patch at dusk.
        "heart_lost":    ("a soft felt-mallet marimba two-note fall, a small gentle 'oh', warm and muffled, never a buzzer", 0.6, -15),
        "wilt":     ("a little mushroom wilting and sinking sheepishly back into soft moss, a slow soft descending slide whistle, very gentle and a bit funny, muffled", 0.8, -13, CARTOON),
        "out_of_hearts": ("a sleepy three-note music box lullaby slowly descending, like a soft yawn at dusk, calm and kind, maybe tomorrow", 1.5, -14),
        "heart_back":    ("a warm rising pair of soft kalimba plucks, a little heart coming back, gentle and happy", 0.6, -15),
        # The party.
        "stamp":    ("a very quiet soft paper stamp tap followed by a loud clear warm glockenspiel chime, two bright rising notes ringing out and fading slowly, proud", 1.5, -5),
        "party":    ("a cozy celebratory kalimba and glockenspiel flourish rising, with a very soft muffled party blower toot and a flutter of little leaves at the end, joyful and warm", 2.0, -4),
        "dance":    ("a short cheerful little kalimba and soft hand-drum shuffle, four playful bouncy notes, a tiny happy dance, cozy and cute", 1.2, -9),
        "meadow":   ("a soft little flourish of flowers popping open, several tiny papery pops rising in pitch with a light glockenspiel twinkle, a meadow blooming, sweet", 1.0, -10),
        # Insane: Fairy Rings. The rings grow in after the patch, and glow at the party.
        "rings":    ("a soft magical twinkle circling around, tiny glockenspiel and celesta notes in a little ring with a faint airy shimmer, fairy dust in a mossy forest, dreamy and hushed", 1.5, -13, COZY),
        "rings_glow": ("a warm dreamy swell of soft celesta and glockenspiel notes rising and glowing, fairy rings lighting up in a forest at dusk, magical and cozy", 1.8, -9),
    },
    # Sudoku: numerals in ink on paper panels laid in a wooden tray; a row,
    # column or region that fills lights up in a wave. Re-prompted toward
    # felt, paper, soft pencil and kalimba on 2026-09-30 (the polish), as
    # Mushroom Patch's and Queens' were: the tape-rewind undo and the wooden
    # "bonk" read as a toy or a scold. Hard and Insane judge a number as it
    # lands: a wrong one costs a heart and tumbles off the paper. Insane is
    # Hilltops: little hills that count the lower cells beside them.
    "sudoku": {
        "place":    ("a single soft graphite pencil tap on thick warm paper with a tiny muffled felt knock, writing a number, cozy and hushed, very short", 0.5, -9, COZY),
        "pencil":   ("a tiny light pencil scribble tick on paper, a small note jotted, very short and quiet", 0.5, -13, COZY),
        "line":     ("a short happy two-note soft kalimba pluck rising, a row completed, warm and round", 0.6, -8),
        "locked":   ("a tiny soft kalimba note with a gentle little wobble, a kind 'not there', muffled and warm, very short", 0.5, -12),
        "undo":     ("a tiny soft paper rustle and a small wooden kalimba note sliding gently down, a kind 'take that back', warm and quiet, very short", 0.5, -11),
        "hint":     ("a gentle magical sparkle, three soft glockenspiel notes rising with a warm felt kalimba underneath and a tiny paper rustle, cozy and kind", 1.0, -8),
        "check":    ("a gentle two-note melody on a soft kalimba: one note, then a second lower note, 'uh-oh' but kind, a cozy 'not quite yet', warm and round, never a buzzer", 1.0, -17, STYLE, "fall"),
        "check_ok": ("two soft warm kalimba notes going up, a friendly cozy 'all good', gentle and round", 0.7, -10),
        "reset":    ("a soft quick eraser rub on thick paper with a light rustle of pages, a page wiped gently clean, hushed and cozy", 1.0, -11, COZY),
        "enter":    ("a soft airy cascade of tiny paper taps and a light page rustle, a sheet of numbers laid out on a wooden tray, cozy and hushed", 1.0, -11, COZY),
        "solved":   ("a warm short celebratory kalimba and glockenspiel flourish, rising arpeggio ending on a soft bright sparkle, joyful and cozy", 2.0, -4),
        # A number is complete (all nine are placed), a region gets its sticker.
        "all_home": ("a sweet little rising run of four soft music box notes ending in a tiny sparkle, everyone is home, warm and happy", 1.0, -10),
        "bloom":    ("a tiny soft flower opening, a delicate papery unfurl with a gentle single glockenspiel twinkle, very short and sweet", 0.6, -14),
        # The streak and the gags.
        "combo":    ("a single short bright soft kalimba pluck, one clean note, very short", 0.5, -8),
        "confetti": ("a soft flutter of tiny paper confetti pieces falling with a tiny sparkling glockenspiel twinkle, light and airy", 1.0, -9),
        "love":     ("a few tiny soft bubbly pops rising with a sweet little two-note kalimba 'aww', little hearts floating up, cute and warm", 0.8, -10),
        "twirl":    ("a tiny playful spin, a soft airy whirl ending on a small bright kalimba 'ta-da' pluck, cute and silly, very short", 0.8, -10),
        "boing":    ("three tiny soft rubbery cartoon boings bouncing, a little number hopping happily on paper, cute and silly, gentle", 0.8, -13, CARTOON),
        # Hearts, the wrong number tumbling off, and the tray at dusk.
        "heart_lost":    ("a soft felt-mallet marimba two-note fall, a small gentle 'oh', warm and muffled, never a buzzer", 0.6, -15),
        "tumble":   ("a little paper number tumbling off a page and fluttering away, a soft papery flip and a gentle descending slide whistle, a bit funny, muffled", 0.8, -13, CARTOON),
        "ruled":    ("a very soft short felt tap with a tiny low kalimba note, a gentle 'we already know that one', quiet and kind", 0.5, -14),
        "out_of_hearts": ("a sleepy three-note music box lullaby slowly descending, like a soft yawn at dusk, calm and kind, maybe tomorrow", 1.5, -14),
        "heart_back":    ("a warm rising pair of soft kalimba plucks, a little heart coming back, gentle and happy", 0.6, -15),
        # The party.
        "stamp":    ("a very quiet soft paper stamp tap followed by a loud clear warm glockenspiel chime, two bright rising notes ringing out and fading slowly, proud", 1.5, -5),
        "party":    ("a cozy celebratory kalimba and glockenspiel flourish rising, with a very soft muffled party blower toot and a flutter of paper at the end, joyful and warm", 2.0, -4),
        "dance":    ("a short cheerful little kalimba and soft hand-drum shuffle, four playful bouncy notes, a tiny happy dance, cozy and cute", 1.2, -9),
        # Insane: Hilltops. The hills rise in after the grid, and glow at the party.
        "hills":    ("a soft rolling rise of tiny muffled felt thumps and a gentle breeze through grass, little green hills rising, with one faint warm glockenspiel note, cozy and hushed", 1.5, -13, COZY),
        "hills_glow": ("a warm dreamy swell of soft celesta and glockenspiel notes rising and glowing, little hills lit gold by a sunset, magical and cozy", 1.8, -9),
    },
    # Bridges: wooden plank bridges laid between islets on a calm sea. The
    # first set was re-prompted 2026-09-30 (the polish) toward soft wood,
    # felt, gentle water and kalimba: the hollow "bonk" and the tape-rewind
    # undo read as a toy or a scold, as they did on Sudoku and Mushroom Patch.
    "bridges": {
        "place":    ("a single soft muffled wooden plank laid down on a little dock with a tiny gentle water lap underneath, warm and hushed, very short", 0.5, -9, COZY),
        "remove":   ("a soft short wooden plank lifted off a little dock with a tiny drip of water, gentle and quiet, very short", 0.5, -12, COZY),
        "met":      ("a short happy two-note soft kalimba pluck rising, a little island complete, warm and round", 0.6, -8),
        "over":     ("a tiny soft kalimba note with a gentle little wobble, a kind 'too many', muffled and warm, very short", 0.5, -13),
        "locked":   ("a tiny soft kalimba note with a gentle little wobble, a kind 'not there', muffled and warm, very short", 0.5, -12),
        "undo":     ("a tiny soft wooden creak and a small kalimba note sliding gently down, a kind 'take that back', warm and quiet, very short", 0.5, -11),
        "hint":     ("a gentle magical sparkle, three soft glockenspiel notes rising with a warm felt kalimba underneath and a tiny water shimmer, cozy and kind", 1.0, -8),
        "check":    ("a gentle two-note melody on a soft kalimba: one note, then a second lower note, 'uh-oh' but kind, a cozy 'not quite yet', warm and round, never a buzzer", 1.0, -17, STYLE, "fall"),
        "check_ok": ("two soft warm kalimba notes going up, a friendly cozy 'all good', gentle and round", 0.7, -10),
        "reset":    ("a soft quick ripple of little wooden planks being gathered up with gentle water laps, hushed and cozy", 1.0, -11, COZY),
        "enter":    ("a soft airy cascade of tiny muffled wooden pops and a gentle calm water lap, little islands rising out of a quiet pond, cozy and hushed", 1.0, -11, COZY),
        "solved":   ("a warm short celebratory kalimba and glockenspiel flourish, rising arpeggio ending on a soft bright sparkle, joyful and cozy", 2.0, -4),
        # The network: two groups joined, and the near-miss named.
        "join":     ("a sweet little rising pair of soft music box notes with a tiny sparkle, two friends holding hands, warm and happy", 0.8, -11),
        "split":    ("a gentle curious three-note kalimba question, rising at the end, 'hmm, almost', warm and kind, never a buzzer", 0.9, -13),
        # The streak and the gags.
        "combo":    ("a single short bright soft kalimba pluck, one clean note, very short", 0.5, -8),
        "confetti": ("a soft flutter of tiny paper confetti pieces falling with a tiny sparkling glockenspiel twinkle, light and airy", 1.0, -9),
        "love":     ("a few tiny soft bubbly pops rising with a sweet little two-note kalimba 'aww', little hearts floating up, cute and warm", 0.8, -10),
        "twirl":    ("a tiny playful spin, a soft airy whirl ending on a small bright kalimba 'ta-da' pluck, cute and silly, very short", 0.8, -10),
        "fish":     ("a tiny cute fish leaping out of a calm pond with a small soft splash and landing back with a gentle bloop, playful and silly", 0.9, -12, CARTOON),
        # Hearts, the wrong plank sinking, the buoy, and the pond at dusk.
        "heart_lost":    ("a soft felt-mallet marimba two-note fall, a small gentle 'oh', warm and muffled, never a buzzer", 0.6, -15),
        "sink":     ("a small wooden plank cracking softly in two and sinking into a calm pond with a gentle bloop and a few tiny bubbles, a bit funny, muffled", 0.9, -13, CARTOON),
        "ruled":    ("a small buoy bobbing up in calm water with a tiny soft bell ding, gentle and quiet, a kind reminder", 0.6, -15),
        "out_of_hearts": ("a sleepy three-note music box lullaby slowly descending, like a soft yawn at dusk over a still pond, calm and kind, maybe tomorrow", 1.5, -14),
        "heart_back":    ("a warm rising pair of soft kalimba plucks, a little heart coming back, gentle and happy", 0.6, -15),
        # The party.
        "stamp":    ("a very quiet soft paper stamp tap followed by a loud clear warm glockenspiel chime, two bright rising notes ringing out and fading slowly, proud", 1.5, -5),
        "party":    ("a cozy celebratory kalimba and glockenspiel flourish rising, with a very soft muffled party blower toot and a flutter of paper at the end, joyful and warm", 2.0, -4),
        "dance":    ("a short cheerful little kalimba and soft hand-drum shuffle, four playful bouncy notes, a tiny happy dance, cozy and cute", 1.2, -9),
        "boat":     ("a tiny paper boat drifting across a calm pond, gentle water lapping and a soft little toy boat horn toot, cute and cozy", 2.0, -11, CARTOON),
        # Insane: Lantern Night. The lanterns light after the islets rise, and flare at the party.
        "lanterns": ("a soft warm hush of little paper lanterns glowing on one by one at night by a calm pond, gentle crickets far away and one faint warm celesta note, cozy and magical", 1.5, -13, COZY),
        "lanterns_glow": ("a warm dreamy swell of soft celesta and glockenspiel notes rising and glowing, paper lanterns lit bright over night water, magical and cozy", 1.8, -9),
    },
    # Quilt: cloth patches dragged off a rack onto a backing; a patch that
    # lands sews a running stitch along its seams. The first set was
    # re-prompted 2026-09-30 (the polish) toward felt, cotton, a wooden spool,
    # soft pins and kalimba: the tape-rewind undo and the cloth "bonk" read as
    # a toy or a scold, as they did on Bridges and Sudoku. Hard and Insane
    # judge a patch as it lands: a wrong one's thread snaps and it flutters
    # home. Insane is Scrap Basket: three scraps that don't belong.
    "quilt": {
        "lift":     ("a tiny soft cotton fabric rustle, a small felt patch picked up off a felt mat, hushed, very short and quiet", 0.5, -13, COZY),
        "place":    ("a soft muffled felt patch patted down onto a cotton quilt, followed by a few quick tiny soft needle-and-thread stitch pulls, a patch sewn on, cozy and hushed", 0.7, -9, COZY),
        "refused":  ("a tiny soft kalimba note with a gentle little wobble, a kind 'not there', muffled and warm, very short", 0.5, -12),
        "undo":     ("a tiny soft cotton rustle and a small kalimba note sliding gently down, a kind 'take that back', warm and quiet, very short", 0.5, -11),
        "hint":     ("a gentle magical sparkle, three soft glockenspiel notes rising with a warm felt kalimba underneath and a tiny soft fabric rustle, cozy and kind", 1.0, -8),
        "reset":    ("a soft quick ripple of cotton patches being gathered back onto a felt mat, gentle fabric rustles and a little wooden spool rolling, hushed and cozy", 1.0, -11, COZY),
        "enter":    ("a soft airy cascade of tiny muffled felt pats and a small wooden spool tap, cloth patches laid out on a felt mat, cozy and hushed", 1.0, -11, COZY),
        "solved":   ("a warm short celebratory kalimba and glockenspiel flourish, rising arpeggio ending on a soft bright sparkle, joyful and cozy", 2.0, -4),
        # The rack patch tapped, and the dead end named (Easy and Medium).
        "wiggle":   ("a tiny playful soft cloth wiggle, a quick little felt shuffle side to side with a soft muffled wooden spool tap, cute, very short", 0.5, -13, COZY),
        "stuck":    ("a gentle two-note melody on a soft kalimba: one note, then a second lower note, 'hmm, that gap won't fill', kind and curious, warm and round, never a buzzer", 1.0, -16, STYLE, "fall"),
        # The streak and the gags.
        "combo":    ("a single short bright soft kalimba pluck, one clean note, very short", 0.5, -8),
        "confetti": ("a soft flutter of tiny paper confetti pieces falling with a tiny sparkling glockenspiel twinkle, light and airy", 1.0, -9),
        "love":     ("a few tiny soft bubbly pops rising with a sweet little two-note kalimba 'aww', little hearts floating up, cute and warm", 0.8, -10),
        "button":   ("a little button sewn onto cloth, a quick soft thread pull and a tiny cute round wooden pop, cheerful, very short", 0.6, -11, CARTOON),
        "boing":    ("a tiny soft rubbery cartoon boing, a little cloth patch squashing and hopping happily on a quilt, cute and silly, gentle", 0.7, -13, CARTOON),
        # A row or column of the quilt finished.
        "row":      ("a quick soft sparkle running along in a line, a light rising glissando of tiny glockenspiel twinkles over a soft felt kalimba note, warm and happy", 0.9, -11),
        # Hearts, the wrong patch snipped off and fluttering home, the quilt at dusk.
        "heart_lost":    ("a soft felt-mallet marimba two-note fall, a small gentle 'oh', warm and muffled, never a buzzer", 0.6, -15),
        "snip":     ("a single soft gentle scissors snip through cotton thread, a thread snapping, quiet and close, very short", 0.5, -13, COZY),
        "flutter":  ("a small cloth patch peeling up and fluttering through the air, soft quick cotton fabric flaps, landing with a gentle muffled pat, a bit funny", 0.8, -13, COZY),
        "ruled":    ("a very soft short chalk mark on fabric, a quiet little tailor's chalk scratch with a tiny low kalimba note, a gentle 'we already know that one', kind", 0.5, -14),
        "out_of_hearts": ("a sleepy three-note music box lullaby slowly descending, like a soft yawn by a warm fire, the quilters nodding off, calm and kind, maybe tomorrow", 1.5, -14),
        "heart_back":    ("a warm rising pair of soft kalimba plucks, a little heart coming back, gentle and happy", 0.6, -15),
        # The party.
        "stamp":    ("a very quiet soft paper stamp tap followed by a loud clear warm glockenspiel chime, two bright rising notes ringing out and fading slowly, proud", 1.5, -5),
        "party":    ("a cozy celebratory kalimba and glockenspiel flourish rising, with a very soft muffled party blower toot and a flutter of paper at the end, joyful and warm", 2.0, -4),
        "dance":    ("a short cheerful little kalimba and soft hand-drum shuffle, four playful bouncy notes, a tiny happy dance, cozy and cute", 1.2, -9),
        "purr":     ("a sleepy little cat curling up on a soft quilt and purring briefly, cozy, soft and warm, short", 1.0, -10, COZY),
        # Insane: Scrap Basket. The three scraps strung up as bunting at the solve.
        "bunting":  ("little cloth flags strung up on a line and fluttering in a gentle breeze, soft fabric flaps with a cheerful rising three-note kalimba, happy and cozy", 1.3, -11, COZY),
    },
    # Paper Planes: tap a folded paper dart and it launches down its lane.
    # Re-prompted 2026-09-30 (the polish) toward soft paper, felt, kalimba, a
    # music box and gentle breaths of air (BREEZE in place of the house
    # marimba): the tape-rewind undo and the papery "bonk" read as a toy or a
    # scold. `place` is the launch. Hard and Insane crash a plane on a wrong
    # launch; Insane is Windy Day, and `drift` rides every launch there, so it
    # is short and very quiet.
    "planes": {
        "place":    ("a light soft breath of air and a gentle papery swish gliding away, a small folded paper plane launched from a hand, hushed, short", 0.7, -10, BREEZE),
        "refuse":   ("a tiny soft kalimba note with a gentle little wobble, a kind 'not that one', muffled and warm, very short", 0.5, -12, BREEZE),
        "undo":     ("a tiny soft paper rustle and a small kalimba note sliding gently down, a kind 'take that back', warm and quiet, very short", 0.5, -11, BREEZE),
        "hint":     ("a gentle magical sparkle, three soft music box notes rising with a warm kalimba note underneath, cozy and kind", 1.0, -8, BREEZE),
        "reset":    ("a soft airy flurry of small paper rustles and gentle breaths of air, paper planes gliding back to the hand, hushed and cozy", 1.0, -11, BREEZE),
        "enter":    ("a soft airy cascade of tiny paper folds and a light warm breeze, a sheet of paper planes appearing in a sunny sky, hushed", 1.0, -11, BREEZE),
        "solved":   ("a warm short celebratory music box and kalimba flourish, rising arpeggio ending on a soft bright shimmer and a gentle breath of air, the whole sky cleared, joyful and cozy", 2.0, -4, BREEZE),
        # The streak and the gags.
        "combo":    ("a single short soft bright kalimba and music box pluck, one clean note, very short", 0.5, -8, BREEZE),
        "confetti": ("a soft flutter of tiny paper confetti pieces falling with a tiny sparkling music box twinkle, light and airy", 1.0, -9, BREEZE),
        "loop":     ("a paper plane doing a loop-the-loop, a soft airy swoosh rising and curling round with a playful three-note kalimba run, light and cute", 1.0, -11, BREEZE),
        "tweet":    ("a single tiny soft little songbird chirp, two sweet high notes, close and gentle, very short", 0.5, -14, COZY),
        "whoosh":   ("a quick soft airy whoosh of a paper plane passing close by, gentle and warm, short", 0.6, -12, BREEZE),
        "love":     ("a tiny soft sweet bubbly pop with a little two-note music box 'aww', cute and warm, short", 0.7, -10, BREEZE),
        # Crashes and hearts (Hard and Insane).
        "crash":    ("a small paper dart bumping its folded nose into a soft cushion and crumpling a little, a muffled papery pat followed by a soft crinkle of paper, gentle and cute, never an impact", 0.8, -13, COZY),
        "flutter":  ("a folded paper plane fluttering gently down, soft papery wobbles and a quiet little rustle settling, hushed", 0.9, -14, COZY),
        "heart_lost":    ("a soft gentle kalimba two-note fall, a small sad 'oh', a delicate note dropping, warm and muffled, never a buzzer", 0.6, -15, BREEZE),
        "out_of_hearts": ("a sleepy music box winding slowly down, a few soft notes descending and slowing, paper planes resting for the day, calm and kind, maybe tomorrow", 1.6, -14, BREEZE),
        "heart_back":    ("a warm rising pair of soft kalimba plucks, a little heart coming back, gentle and happy", 0.6, -15, BREEZE),
        # Windy Day (Insane).
        "gust":     ("a warm soft whoosh of breeze rising and passing, a gentle gust of wind on a sunny day, rounded and cozy", 1.0, -12, BREEZE),
        "drift":    ("a very quiet tiny airy swish, a faint breath of wind nudging a paper plane aside, barely there, very short", 0.5, -18, BREEZE),
        "stuck":    ("a soft sigh of wind that fades and stops, a breeze settling down to calm, gentle, short", 0.8, -14, BREEZE),
        # The party.
        "stamp":    ("a soft paper stamp thump followed by a clear warm music box chime sparkle, two bright rising notes ringing out and fading slowly, proud", 1.5, -5, BREEZE),
        "party":    ("a short joyful flourish on a music box and kalimba, rising and bright with a flutter of paper at the end, warm and cozy", 2.0, -4, BREEZE),
        "flock":    ("many little paper planes whooshing softly past together, airy swishes overlapping, with a bright rising kalimba flourish, joyful and gentle", 1.6, -9, BREEZE),
        "purr":     ("a sleepy little cat curled up in a warm sunny window purring briefly, soft contented purr, cozy and warm, short", 1.0, -10, COZY),
        "clouds":   ("soft fluffy clouds drifting apart, an airy gentle shimmer of breeze with a warm slow music box note, dreamy and calm", 1.5, -12, BREEZE),
    },
    # Pinwheel: tap a paper pinwheel and its cloth piece takes a quarter turn.
    # Re-prompted in the polish (2026-10-01) toward a sewing basket on a
    # breezy porch (LINEN in place of the house marimba): soft paper whirrs,
    # linen, felt, a wooden spool, kalimba and a music box. No tape-rewind
    # undo, no wooden bonk.
    "pinwheel": {
        "place":    ("a soft airy paper pinwheel whirr turning a quarter round, with a tiny felt-soft wooden click as it settles, hushed, very short", 0.5, -11, LINEN),
        "refused":  ("a tiny soft kalimba note with a gentle little wobble, a kind 'that one stays', muffled and warm, very short", 0.5, -12, LINEN),
        "undo":     ("a tiny soft linen rustle and a small kalimba note sliding gently down, a kind 'take that back', warm and quiet, very short", 0.5, -11, LINEN),
        "hint":     ("a gentle magical sparkle, three soft music box notes rising with a warm kalimba note underneath, cozy and kind", 1.0, -8, LINEN),
        "reset":    ("a soft airy ripple of little paper pinwheels whirring back one after another with tiny felt clicks, hushed and cozy", 1.0, -11, LINEN),
        "enter":    ("a soft airy cascade of tiny paper flutters and felt pops, a quilt of little pinwheels appearing on a breezy porch, hushed", 1.0, -11, LINEN),
        "solved":   ("a warm short celebratory music box and kalimba flourish, rising arpeggio ending in a soft bright shimmer and a happy breeze through paper pinwheels, joyful and cozy", 2.0, -4, LINEN),
        # The polish's new cues.
        "combo":    ("a single short soft bright kalimba and music box pluck, one clean note, very short", 0.5, -8, LINEN),
        "confetti": ("a soft flutter of tiny paper confetti pieces falling with a tiny sparkling music box twinkle, light and airy", 1.0, -9, LINEN),
        "whirl":    ("a little paper pinwheel catching a happy gust and whirring round and round fast, a soft rising airy whirr with a playful two-note kalimba whistle, cute", 1.0, -11, LINEN),
        "love":     ("a tiny soft sweet bubbly pop with a little two-note music box 'aww', cute and warm, short", 0.7, -10, LINEN),
        "flutter":  ("a tiny butterfly fluttering past, soft quick papery wing flutters with a delicate rising music box twinkle, light and cute, short", 0.9, -12, LINEN),
        "snag":     ("a soft fabric snag, a gentle thread catching with a tiny tug and a muffled felt thump, a small 'oops', warm, never harsh, short", 0.5, -12, LINEN),
        "heart_lost":    ("a soft gentle kalimba two-note fall, a small sad 'oh', a delicate note dropping, warm and muffled, never a buzzer", 0.6, -15, LINEN),
        "tack":     ("a tiny soft needle and thread stitch, two quick gentle pulls of thread through linen and a small bright music box ding, neat and kind", 0.6, -12, LINEN),
        "out_of_hearts": ("a sleepy music box winding slowly down, a few soft notes descending and slowing, paper pinwheels going still at dusk, calm and kind, maybe tomorrow", 1.6, -14, LINEN),
        "heart_back":    ("a warm rising pair of soft kalimba plucks, a little heart coming back, gentle and happy", 0.6, -15, LINEN),
        "tug":      ("a soft satin ribbon pulled taut with a gentle little stretch and release, a quiet springy twang on a felt-muted kalimba, short", 0.5, -14, LINEN),
        "stamp":    ("a soft paper stamp thump followed by a clear warm music box chime sparkle, two bright rising notes ringing out and fading slowly, proud", 1.5, -5, LINEN),
        "party":    ("a short joyful flourish on a music box and kalimba, rising and bright with a flutter of paper at the end, warm and cozy", 2.0, -4, LINEN),
        "kite":     ("a paper kite with a ribbon tail swooping up on a warm breeze, a soft rising airy whoosh and a gentle fluttering of paper and ribbon, joyful", 1.4, -10, LINEN),
        "purr":     ("a sleepy little cat curled up in a warm sunny window purring briefly, soft contented purr, cozy and warm, short", 1.0, -10, COZY),
        "ribbons":  ("satin ribbons slipping loose and fluttering up into a breeze, soft silky swishes with a slow dreamy music box note, calm and happy", 1.5, -12, LINEN),
    },
    # Caterpillar: drag from leaf 1 and every square grows the caterpillar a
    # segment; it eats the leaves in order. `step` fires on every square, so
    # it gets no file (docs/art/sound-direction.md). Re-prompted in the
    # polish (2026-10-01) toward a sunny clover garden (CLOVER in place of
    # the house marimba): no tape-rewind undo, no wooden bonk.
    "caterpillar": {
        "place":    ("a tiny soft clover leaf rustle with a small felt-soft wooden tick, a little caterpillar waking up and stretching, hushed, very short", 0.5, -11, CLOVER),
        "munch":    ("a tiny cute caterpillar nibbling a soft leaf, two quick gentle crunch-crunch nibbles with a small warm rising kalimba plink, soft and adorable, very short", 0.5, -9, CLOVER),
        "refuse":   ("a tiny soft kalimba note with a gentle little wobble and a muffled leafy tap, a kind 'not that way', warm, very short", 0.5, -12, CLOVER),
        "undo":     ("a tiny soft leaf rustle and a small kalimba note sliding gently down, a kind 'take that back', warm and quiet, very short", 0.5, -11, CLOVER),
        "hint":     ("a gentle magical sparkle, three soft music box notes rising with a warm kalimba note underneath, cozy and kind", 1.0, -8, CLOVER),
        "reset":    ("a soft quick descending ripple of leafy rustles and tiny felt ticks, a little caterpillar curling back up small, hushed and cozy", 1.0, -11, CLOVER),
        "solved":   ("a warm short celebratory music box and kalimba flourish, rising arpeggio ending in a soft bright shimmer and a light airy flutter of butterfly wings over clover, joyful and cozy", 2.0, -4, CLOVER),
        "enter":    ("a soft airy cascade of tiny felt pops and a light rustle of clover leaves, a little garden of leaves appearing, hushed", 1.0, -11, CLOVER),
        # The polish's new cues.
        "combo":    ("a single short soft bright kalimba and music box pluck, one clean note, very short", 0.5, -8, CLOVER),
        "confetti": ("a soft flutter of tiny paper confetti pieces falling with a tiny sparkling music box twinkle, light and airy", 1.0, -9, CLOVER),
        "burp":     ("a tiny cute caterpillar hiccup-burp that blows a little soap bubble, a soft bubbly 'blip' and a tiny bubble pop, adorable, not gross, very short", 0.6, -12, CLOVER),
        "love":     ("a tiny soft sweet bubbly pop with a little two-note music box 'aww', cute and warm, short", 0.7, -10, CLOVER),
        "ladybug":  ("a tiny ladybug buzzing softly in and landing on a leaf with a soft little tick, cute, gentle, never annoying, short", 0.9, -14, CLOVER),
        "hungry":   ("a tiny soft tummy rumble, a cute little 'grumble' of a hungry caterpillar, muffled and gentle, a kind 'not yet', short", 0.6, -12, CLOVER),
        "strand":   ("a soft worried 'uh-oh', two kalimba notes with a gentle wobble bending down, warm and muffled, never a buzzer, short", 0.6, -12, CLOVER),
        "heart_lost":    ("a soft gentle kalimba two-note fall, a small sad 'oh', a delicate note dropping, warm and muffled, never a buzzer", 0.6, -15, CLOVER),
        "slip":     ("a little caterpillar scooting back one square, a soft quick leafy slide with a felt-soft tick, gentle, very short", 0.5, -12, CLOVER),
        "out_of_hearts": ("a sleepy music box winding slowly down, a few soft notes descending and slowing, a clover garden at dusk going quiet, calm and kind, maybe tomorrow", 1.6, -14, CLOVER),
        "heart_back":    ("a warm rising pair of soft kalimba plucks, a little heart coming back, gentle and happy", 0.6, -15, CLOVER),
        "stamp":    ("a soft rubber seal stamp thump on paper followed by a small warm music box sparkle, two bright rising notes ringing out, proud", 1.5, -5, CLOVER),
        "party":    ("a short cozy celebratory flourish on kalimba and music box, rising and bright, with a few soft little party blower toots, warm and joyful", 2.0, -4, CLOVER),
        "purr":     ("a sleepy little cat curled up in a warm sunny window purring briefly, soft contented purr, cozy and warm, short", 1.0, -10, COZY),
        "flutter":  ("several tiny butterflies taking off together, soft quick papery wing flutters with a delicate rising music box twinkle, light and cute", 1.2, -12, CLOVER),
        "row":      ("a quick soft rising sparkle run across a row of little tiles, a tiny music box glissando, light and bright, short", 0.7, -11, CLOVER),
        "fill":     ("a tummy filling back up after a leaf, a soft happy 'mmm' with a warm rising kalimba plink, content and cute, short", 0.6, -11, CLOVER),
    },
    # Sunbeam: drag a brass mirror or a copper cup along its wooden rail and
    # the light follows; wet every dewdrop, then the bud blooms. `step` fires
    # on every peg a drag crosses, so it gets no file
    # (docs/art/sound-direction.md).
    "sunbeam": {
        # Re-prompted in the polish (2026-10-01) toward the greenhouse.
        "lift":     ("a tiny felt-soft brass click, a little mirror lifted off a wooden peg with a breath of air, hushed, very short", 0.5, -13, GLASSHOUSE),
        "step":     ("a single tiny soft wooden rail tick, a small brass piece passing a peg as it slides, very short and quiet", 0.5, -15),
        "slide":    ("a short soft wooden glide ending in a gentle felt-soft brass tick, a mirror settling onto its peg, cozy and hushed", 0.5, -11, GLASSHOUSE),
        "drop":     ("a tiny felt-soft brass tick on wood, very short and quiet", 0.5, -15, GLASSHOUSE),
        "dew":      ("a single tiny bright glass droplet chime, a dewdrop catching warm sunlight, soft music box, very short", 0.6, -10, GLASSHOUSE),
        "dry":      ("a soft gentle two-note kalimba falling, a kind 'not yet', warm and patient, short", 0.6, -12, GLASSHOUSE),
        "refuse":   ("a tiny soft kalimba note with a gentle little wobble and a muffled felt tap, a kind 'not that one', warm, very short", 0.5, -12, GLASSHOUSE),
        "undo":     ("a soft little glass shimmer sliding gently down with a felt-soft wooden tick, a kind 'take that back', warm and quiet, very short", 0.5, -11, GLASSHOUSE),
        "hint":     ("a gentle magical sparkle, three soft music box notes rising with a warm glass chime underneath, cozy and kind", 1.0, -8, GLASSHOUSE),
        "reset":    ("a soft quick descending ripple of tiny felt-soft wooden ticks, little mirrors sliding home along their rails, hushed and cozy", 1.0, -11, GLASSHOUSE),
        "solved":   ("a warm short celebratory music box and glass chime flourish rising into a soft airy shimmer, a flower opening in morning sunlight, joyful and cozy", 2.0, -4, GLASSHOUSE),
        "enter":    ("a soft airy cascade of tiny glass chimes and felt-soft brass clicks, a greenhouse waking in the morning sun, hushed", 1.0, -11, GLASSHOUSE),
        # The polish's new cues.
        "stir":     ("a tiny sleepy snail murmuring in its sleep, a soft muffled 'mmh' with a little wobbly kalimba note, cute, very short", 0.5, -15, GLASSHOUSE),
        "shy":      ("a tiny shy nervous glass twinkle trembling, a dewdrop blushing, a soft quivering music box note, cute, very short", 0.5, -15, GLASSHOUSE),
        "wake":     ("a little snail startled awake, a cute soft surprised 'oh!' squeak made of two quick rising kalimba notes, gentle, never a buzzer, short", 0.6, -12, GLASSHOUSE),
        "sizzle":   ("a tiny dewdrop drying in the sun, a very soft little steam 'pfff' with a delicate glass note fading, gentle, short", 0.7, -13, GLASSHOUSE),
        "heart_lost":    ("a soft gentle kalimba two-note fall, a small sad 'oh', a delicate note dropping, warm and muffled, never a buzzer", 0.6, -15, GLASSHOUSE),
        "slip":     ("a little brass mirror sliding back along its wooden rail, a soft quick glide with a felt-soft tick, gentle, very short", 0.5, -12, GLASSHOUSE),
        "out_of_hearts": ("a sleepy music box winding slowly down, a few soft notes descending and slowing, a greenhouse at dusk going quiet, calm and kind, maybe tomorrow", 1.6, -14, GLASSHOUSE),
        "heart_back":    ("a warm rising pair of soft kalimba plucks, a little heart coming back, gentle and happy", 0.6, -15, GLASSHOUSE),
        "combo":    ("a single short soft bright glass and music box pluck, one clean note, very short", 0.5, -8, GLASSHOUSE),
        "confetti": ("a soft flutter of tiny paper confetti pieces falling with a tiny sparkling music box twinkle, light and airy", 1.0, -9, GLASSHOUSE),
        "rainbow":  ("a soft shimmering rising glissando of tiny glass chimes, a little rainbow appearing in a sunbeam, magical and warm, short", 1.0, -10, GLASSHOUSE),
        "love":     ("a tiny soft sweet bubbly pop with a little two-note music box 'aww', cute and warm, short", 0.7, -10, GLASSHOUSE),
        "flutter":  ("tiny butterflies fluttering by, soft quick papery wing flutters with a delicate rising music box twinkle, light and cute", 1.0, -12, GLASSHOUSE),
        "chorus":   ("many tiny glass dewdrops chiming together all at once in warm sunlight, a soft bright shimmering chord on music box and glass, magical, short", 1.2, -7, GLASSHOUSE),
        "stamp":    ("a soft rubber seal stamp thump on paper followed by a small warm music box sparkle, two bright rising notes ringing out, proud", 1.5, -5, GLASSHOUSE),
        "party":    ("a short cozy celebratory flourish on music box and glass chimes, rising and bright, with a few soft little party blower toots, warm and joyful", 2.0, -4, GLASSHOUSE),
        "purr":     ("a sleepy little cat curled up in a warm sunny window purring briefly, soft contented purr, cozy and warm, short", 1.0, -10, COZY),
    },
    # Knight: a cream knight hops in Ls to take the rose king; rose knights
    # answer every hop. A catch slides the board back one move. Re-prompted
    # 2026-10-01 (polish) in PADDOCK -- the old set's undo was a tape rewind
    # and its refuse a wooden bonk -- and the hearts, Brambles and party cues
    # added.
    "knight": {
        "hop":      ("a single soft felt-bottomed wooden chess knight landing on a paper board, a light cozy tap with a tiny springy lift, very short", 0.5, -11, PADDOCK),
        "answer":   ("a lower softer felt-bottomed wooden piece tap on paper, hushed, very short", 0.5, -14, PADDOCK),
        "take":     ("a bright small cartoon wooden 'bonk' of one toy chess piece knocking another over, a tiny tumble and a twinkle, cute, short", 0.6, -10, PADDOCK),
        "caught":   ("a soft gentle two-note kalimba falling, a kind 'oops, caught', warm and patient, never a buzzer, short", 0.6, -12, PADDOCK),
        "slide":    ("a short soft glide of felt-bottomed wooden pieces sliding back on paper, hushed and cozy", 0.5, -13, PADDOCK),
        "refuse":   ("a tiny soft kalimba note with a gentle little wobble and a muffled felt tap, a kind 'not that one', very short", 0.5, -13, PADDOCK),
        "undo":     ("a soft little music box note sliding gently down with a felt-soft wooden tick, a kind 'take that back', quiet, very short", 0.5, -12, PADDOCK),
        "hint":     ("a gentle magical sparkle, three soft music box notes rising with a warm kalimba underneath, cozy and kind", 1.0, -8, PADDOCK),
        "reset":    ("a soft quick descending ripple of tiny felt-soft wooden ticks, toy chess pieces hopping home, hushed and cozy", 1.0, -11, PADDOCK),
        "solved":   ("a warm celebratory kalimba and music box run rising, ending in a little wooden toy king toppling with a soft clack and a happy pony nicker, joyful and cozy", 2.0, -4, PADDOCK),
        "enter":    ("a soft airy cascade of tiny felt-bottomed wooden pieces being set on a paper board, gentle", 1.0, -11, PADDOCK),
        "flip":     ("a playful soft airy whoosh spinning once round with a tiny springy boing and a giggly kalimba trill, a little toy pony doing a somersault, cute, short", 0.7, -10, PADDOCK),
        "bramble":  ("a tiny soft leafy rustle and a little green sprouting pop, a small bramble springing up from the ground, cute and quiet, very short", 0.5, -15, PADDOCK),
        "nap":      ("a tiny sleepy yawn made of two soft descending music box notes and a gentle little snore puff, a toy knight dozing off, cute and quiet", 1.0, -12, PADDOCK),
        "stuck":    ("a soft gentle three-note kalimba falling, a kind 'no way through from here', warm and calm, never a buzzer", 0.9, -13, PADDOCK),
        "boxed":    ("a soft worried little kalimba wobble with a leafy thorny rustle closing in, gentle, 'oh no, boxed in', never harsh, short", 0.8, -12, PADDOCK),
        "wither":   ("a soft gentle downward leafy rustle fading away, little brambles shrinking back into the ground, with a faint warm music box note, hushed", 0.9, -14, PADDOCK),
        "heart_lost":    ("a soft gentle kalimba two-note fall, a small sad 'oh', a delicate note dropping, warm and muffled, never a buzzer", 0.6, -15, PADDOCK),
        "out_of_hearts": ("a sleepy music box winding slowly down, a few soft notes descending and slowing, a garden table at dusk going quiet, calm and kind, maybe tomorrow", 1.6, -14, PADDOCK),
        "heart_back":    ("a warm rising pair of soft kalimba plucks, a little heart coming back, gentle and happy", 0.6, -15, PADDOCK),
        "combo":    ("a single short soft bright kalimba pluck, one clean warm note, very short", 0.5, -8, PADDOCK),
        "confetti": ("a soft flutter of tiny paper confetti pieces falling with a tiny sparkling music box twinkle, light and airy", 1.0, -9, PADDOCK),
        "love":     ("a tiny soft sweet bubbly pop with a little two-note music box 'aww', cute and warm, short", 0.7, -10, PADDOCK),
        "flutter":  ("a tiny butterfly fluttering by, soft quick papery wing flutters with a delicate rising music box twinkle, light and cute", 1.0, -12, PADDOCK),
        "crown":    ("a small golden toy crown landing with a soft bright 'ting' and a warm sparkling music box shimmer, proud and cute, short", 1.0, -8, PADDOCK),
        "stamp":    ("a soft rubber seal stamp thump on paper followed by a small warm music box sparkle, two bright rising notes ringing out, proud", 1.5, -5, PADDOCK),
        "party":    ("a short cozy celebratory flourish on kalimba and music box, rising and bright, with a few soft little party blower toots and a happy pony nicker, warm and joyful", 2.0, -4, PADDOCK),
        "purr":     ("a sleepy little cat curled up on a warm sunny garden table purring briefly, soft contented purr, cozy and warm, short", 1.0, -10, COZY),
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
        # 2026-10-01 (polish) in HARVEST -- the old set's undo was a tape
        # rewind and its refuse a wooden bonk; Sleepwalkers, hearts and the
        # rewards are new.
        "rake":     ("a short soft sweep of a little bamboo rake through a small pile of dry autumn leaves, cozy and crisp, very short", 0.5, -11, HARVEST),
        "gust":     ("a soft airy flurry of dry autumn leaves lifting off a lawn in a light warm breeze, with a faint rising kalimba shimmer", 0.9, -10, HARVEST),
        "flag":     ("a small wooden twig pushed softly into a pile of dry leaves with a tiny muffled felt tap, very short", 0.5, -11, HARVEST),
        "unflag":   ("a small twig pulled gently out of dry leaves with a tiny rustle, very short", 0.5, -13, HARVEST),
        "woke":     ("a tiny grumpy hedgehog snuffle and a little sleepy huff, then one soft low kalimba note, cute and kind, never harsh", 0.9, -10, HARVEST),
        "chord":    ("two quick soft little rake sweeps through dry leaves, light and tidy, very short", 0.5, -11, HARVEST),
        "refuse":   ("a tiny soft kalimba note with a gentle little wobble and a muffled leaf rustle, a kind 'not that one', very short", 0.5, -14, HARVEST),
        "check":    ("a soft gentle two-note kalimba falling, a kind 'not yet', warm and patient", 0.6, -12, HARVEST),
        "check_ok": ("three soft warm kalimba notes rising, bright and happy, 'all good'", 0.7, -10, HARVEST),
        "undo":     ("a soft little music box note sliding gently down with a felt-soft leaf rustle, a kind 'take that back', quiet, very short", 0.5, -13, HARVEST),
        "hint":     ("a gentle magical sparkle, three soft music box notes rising with a warm kalimba underneath, cozy and kind", 1.0, -9, HARVEST),
        "reset":    ("a soft rustle of autumn leaves drifting back down onto a lawn, with a calm low music box note, gentle", 1.0, -11, HARVEST),
        "solved":   ("a warm celebratory kalimba and music box run rising, with a soft swirl of leaves and tiny happy hedgehog squeaks, joyful and cozy", 2.0, -5, HARVEST),
        "enter":    ("a soft airy rustle of autumn leaves settling onto grass, with one warm low kalimba note", 1.0, -12, HARVEST),
        "bell":     ("a single small soft silver moon bell chime, round and dreamy, ringing out gently at night, music box tone, cozy and quiet", 1.0, -11, HARVEST),
        "snuffle":  ("a tiny sleeping hedgehog shuffling under dry leaves, a soft little sleepy snuffle and two tiny pitter-patter footsteps in the leaves, cute, quiet", 0.8, -12, HARVEST),
        "heart_lost":    ("a soft gentle kalimba two-note fall, a small sad 'oh', a delicate note dropping, warm and muffled, never a buzzer", 0.6, -15, HARVEST),
        "out_of_hearts": ("a sleepy music box winding slowly down, a few soft notes descending and slowing, an autumn lawn at dusk going quiet, calm and kind, maybe tomorrow", 1.6, -14, HARVEST),
        "heart_back":    ("a warm rising pair of soft kalimba plucks, a little heart coming back, gentle and happy", 0.6, -15, HARVEST),
        "combo":    ("a single short soft bright kalimba pluck, one clean warm note, very short", 0.5, -9, HARVEST),
        "confetti": ("a soft flutter of tiny paper confetti and a few dry leaves falling, with a tiny sparkling music box twinkle, light and airy", 1.0, -10, HARVEST),
        "love":     ("a tiny soft sweet bubbly pop with a little two-note music box 'aww', cute and warm, short", 0.7, -11, HARVEST),
        "flutter":  ("a tiny butterfly fluttering up out of a pile of leaves, soft quick papery wing flutters with a delicate rising music box twinkle, light and cute", 1.0, -13, HARVEST),
        "acorn":    ("a little acorn popping out of dry leaves and bouncing twice on soft grass, tiny hollow wooden boinks, playful and cute, short", 0.8, -11, HARVEST),
        "whoosh":   ("a soft happy whoosh of a big pile of dry leaves blown away all at once, airy and bright with a small rising kalimba sparkle", 0.9, -11, HARVEST),
        "stamp":    ("a soft rubber seal stamp thump on paper followed by a small warm music box sparkle, two bright rising notes ringing out, proud", 1.5, -6, HARVEST),
        "party":    ("a short cozy celebratory flourish on kalimba and music box, rising and bright, with a few soft little party blower toots and tiny happy hedgehog squeaks, warm and joyful", 2.0, -5, HARVEST),
        "purr":     ("a small cat purring softly and contentedly while curling up to sleep", 1.5, -14, COZY),
    },
    # Super Slider: painted wooden blocks slid round a walnut tray until the
    # big one walks out of a little garden gate. 2026-10-01 (polish): players
    # called the first set synthetic, so every cue a block makes is now
    # close-mic foley of real hardwood on felt (WALNUT, rolled off above 7 kHz),
    # and only the rewards are music, a real kalimba and music box
    # (WALNUT_TUNE). The old undo was a tape rewind.
    "slider": {
        "lift":     ("a small smooth hardwood toy block picked up off a felt-lined wooden tray, one soft dry wooden tick, very short", 0.5, -15, WALNUT, "warm:7000"),
        "step":     ("one quiet short scrape of a smooth hardwood block sliding a finger's width across soft felt, very short", 0.5, -19, WALNUT, "warm:7000"),
        "bump":     ("a solid hardwood toy block gently knocking against another wooden block, one soft dull hollow wooden knock, very short", 0.5, -13, WALNUT, "warm:7000"),
        "slide":    ("a smooth hardwood block sliding across a felt-lined tray and settling into place with one soft solid wooden clack, short", 0.6, -11, WALNUT, "warm:7000"),
        "drop":     ("a hardwood toy block set gently back down on felt, a soft muted wooden tap, very short", 0.5, -16, WALNUT, "warm:7000"),
        "undo":     ("a hardwood block pushed back across felt with a soft hush and a gentle wooden tap, quiet, short", 0.6, -14, WALNUT, "warm:7000"),
        "slip":     ("a smooth wooden block sliding back across felt with a soft hush, ending in a gentle wooden tap, short", 0.7, -14, WALNUT, "warm:7000"),
        "reset":    ("a handful of smooth hardwood toy blocks sliding back across a felt-lined tray, a soft ripple of gentle wooden clacks, short", 1.0, -12, WALNUT, "warm:7000"),
        "enter":    ("small hardwood toy blocks set down one by one into a felt-lined wooden tray, a soft quick patter of gentle wooden taps", 1.0, -13, WALNUT, "warm:7000"),
        "gate":     ("a tiny wooden garden gate swinging open on a soft creaky hinge with a little brass latch click", 0.8, -10, WALNUT, "warm:7000"),
        "hop":      ("a small hardwood toy block hopping onto a flat garden stepping stone, one soft hollow tock, very short", 0.5, -15, WALNUT, "warm:7000"),
        "latch":    ("a small brass garden-gate latch rattling softly three times, a happy little jiggle, short", 0.7, -13, WALNUT, "warm:7000"),
        "hint":     ("three soft rising notes plucked on a real kalimba with a delicate music box sparkle, gentle and magical", 1.0, -10, WALNUT_TUNE),
        "solved":   ("a warm happy rising run plucked on a real kalimba with a music box, ending on a bright gentle chord, cozy and joyful", 2.0, -6, WALNUT_TUNE),
        "fret":     ("a single soft low kalimba note gently bending down, a tiny worried 'hmm', quiet and kind, very short", 0.5, -19, WALNUT_TUNE),
        "huff":     ("a tiny stubborn 'hmph' made of two quick soft low kalimba plucks and a muffled wooden knock, cute, very short", 0.5, -15, WALNUT_TUNE),
        "heart_lost":    ("a soft gentle kalimba two-note fall, a small sad 'oh', a delicate note dropping, warm and muffled, never a buzzer", 0.6, -15, WALNUT_TUNE),
        "out_of_hearts": ("a real wind-up music box winding slowly down, a few soft notes descending and slowing, a garden at dusk going quiet, calm and kind", 1.6, -14, WALNUT_TUNE),
        "heart_back":    ("a warm rising pair of soft kalimba plucks, a little heart coming back, gentle and happy", 0.6, -15, WALNUT_TUNE),
        "combo":    ("a single short soft bright pluck on a real kalimba, one clean warm note, very short", 0.5, -9, WALNUT_TUNE),
        "confetti": ("a soft flutter of tiny paper confetti falling with a tiny music box twinkle, light and airy", 1.0, -10, WALNUT_TUNE),
        "love":     ("a tiny soft sweet two-note music box 'aww' with a little bubbly pop, cute and warm, short", 0.7, -11, WALNUT_TUNE),
        "flutter":  ("a tiny butterfly fluttering by, soft quick papery wing flutters with a delicate rising music box twinkle, light and cute", 1.0, -13, WALNUT_TUNE),
        "twirl":    ("a playful soft airy whoosh spinning once around with a giggly kalimba trill, a little wooden toy doing a happy twirl, cute, short", 0.7, -11, WALNUT_TUNE),
        "stamp":    ("a soft rubber seal stamp thump on paper followed by a small warm music box sparkle, two bright rising notes ringing out, proud", 1.5, -6, WALNUT_TUNE),
        "party":    ("a short cozy celebratory flourish on a real kalimba and a music box, rising and bright, with a few soft little party blower toots, warm and joyful", 2.0, -5, WALNUT_TUNE),
        "purr":     ("a small cat purring softly and contentedly while curling up to sleep", 1.5, -14, COZY),
    },
    # Marigold: the family's sun shoots a seed down through a pond garden of
    # flower buds; every bud it touches blooms with the next note of a rising
    # scale, the blooms are picked, and the last marigold is a full bloom.
    "marigold": {
        # 2026-10-01 (polish): every cue taken again in POND / POND_TUNE, and
        # the hearts, Sweethearts and the silly rewards added. `hit` is pitched
        # up a scale, so it has to be one clean note.
        "shoot":    ("a small seed puffed softly out of a curled green leaf tube, one round airy 'pff' with a tiny leafy flick, very short", 0.5, -10, POND, "warm:7000"),
        "hit":      ("one single soft note plucked on a real kalimba, clean and round with a quick natural ring, only one note, nothing else", 0.5, -9, POND_TUNE, "warm:7000"),
        "wall":     ("a tiny dry seed tapping a smooth wooden garden post, one soft woody tick, very short", 0.5, -17, POND, "warm:7000", "cut:0.1"),
        "clover":   ("two quick soft music box notes ringing together with a tiny leafy rustle, something splitting in two happily", 0.7, -10, POND_TUNE, "warm:7000"),
        "violet":   ("three sweet rising notes on a real music box with a soft hand bell shimmer, a special find, delicate", 0.8, -8, POND_TUNE, "warm:7000"),
        "pop":      ("one tiny soft pluck of a flower petal off its stem, a light papery 'pip', very short and quiet", 0.5, -14, POND, "warm:7000", "cut:0.06"),
        "pot":      ("a small seed dropping into a terracotta flowerpot full of soft soil, a hollow warm clay 'tunk', then one happy rising kalimba note", 0.8, -8, POND_TUNE, "warm:7000"),
        "free":     ("three cheerful rising notes plucked on a real kalimba with a little music box sparkle on top, a reward earned", 1.0, -8, POND_TUNE, "warm:7000"),
        "drain":    ("a small seed dropping softly into a still pond, one gentle little 'plip' and a tiny ripple, quiet", 0.6, -15, POND, "warm:7000"),
        "fever":    ("a swelling run of soft hand bells and a real kalimba rising up into a bright warm shimmering music box chord, a wonderful moment, joyful", 1.8, -5, POND_TUNE, "warm:7000"),
        "roll":     ("a steady soft rolling tremolo of fingers drumming on a wooden box and a felt-mallet frame drum, a suspenseful drumroll, even and constant, no accents, no ending", 3.0, -9, POND, "loop"),
        "close":    ("a soft playful disappointed 'awww' of two kalimba notes bending down with a little wooden wobble, a near miss, funny and kind, never sad", 0.9, -10, POND_TUNE, "warm:7000"),
        "fever_pot":("a bright happy cascade of hand bells and music box notes landing on a warm chord, a big prize won, joyful", 1.2, -5, POND_TUNE, "warm:7000"),
        "out":      ("a gentle soft two-note kalimba falling, a kind 'try again', warm and patient, never sad or harsh", 0.8, -11, POND_TUNE, "warm:7000"),
        "hint":     ("three soft rising music box notes with a delicate hand bell sparkle, gentle and magical", 1.0, -9, POND_TUNE, "warm:7000"),
        "reset":    ("a soft rustle of leaves and little stems springing back up in a garden bed, with one calm low kalimba note, a garden growing back", 1.0, -11, POND, "warm:7000"),
        "solved":   ("a warm joyful rising run on a real kalimba, music box and soft hand bells, landing on a bright gentle chord, cozy and triumphant", 2.6, -5, POND_TUNE, "warm:7000"),
        "enter":    ("a soft airy rustle of leaves and petals settling in an evening garden by a pond, with one warm low kalimba note", 1.0, -12, POND, "warm:7000"),
        "heart_lost":    ("a soft gentle kalimba two-note fall, a small sad 'oh', a delicate note dropping, warm and muffled, never a buzzer", 0.6, -14, POND_TUNE, "warm:7000"),
        "out_of_hearts": ("a real wind-up music box winding slowly down, a few soft notes descending and slowing, a pond garden at dusk going quiet, calm and kind", 1.6, -13, POND_TUNE, "warm:7000"),
        "heart_back":    ("a warm rising pair of soft kalimba plucks, a little heart coming back, gentle and happy", 0.6, -13, POND_TUNE, "warm:7000"),
        "pair":     ("a sweet little two-note music box 'aww' rising, two notes ringing together in harmony, two sweethearts meeting, tender and warm", 0.8, -9, POND_TUNE, "warm:7000"),
        "apart":    ("a soft sad little slide down on a kalimba with a tiny wooden wobble, a flower closing up, gentle and a bit funny, never harsh", 0.8, -12, POND_TUNE, "warm:7000"),
        "combo":    ("a single short soft bright pluck on a real kalimba, one clean warm note, very short", 0.5, -10, POND_TUNE, "warm:7000"),
        "confetti": ("a soft flutter of tiny paper confetti and petals falling, with a tiny music box twinkle, light and airy", 1.0, -11, POND_TUNE, "warm:7000"),
        "ribbit":   ("one small cute frog croak by a pond at night, a short soft round 'ribbit', friendly and funny", 0.6, -10, POND, "warm:7000"),
        "splash":   ("a small frog landing back on a lily pad, a soft wet little 'plap' and a tiny ripple of water, quiet", 0.5, -14, POND, "warm:7000"),
        "quack":    ("a mother duck quacking softly twice and three tiny ducklings peeping as they paddle across a calm pond, cute and gentle", 1.4, -11, POND, "warm:7000"),
        "shades":   ("a playful cool little slide up on a kalimba ending in a tiny bright music box 'ting', something putting on sunglasses, funny and cute, short", 0.7, -9, POND_TUNE, "warm:7000"),
        "stamp":    ("a soft rubber seal stamp thump on paper followed by a small warm music box sparkle, two bright rising notes ringing out, proud", 1.5, -6, POND_TUNE, "warm:7000"),
        "party":    ("a short cozy celebratory flourish on a real kalimba and a music box, rising and bright, with a few soft little party blower toots, warm and joyful", 2.0, -5, POND_TUNE, "warm:7000"),
        "purr":     ("a small cat purring softly and contentedly while curling up to sleep", 1.5, -14, COZY),
        # 2026-10-05: the three instruments of the full bloom's tune, one note
        # each. tools/gen_marigold_music.py plays them at pitch into music.ogg
        # (the tune has to be exact, so it is sequenced, never prompted); the
        # board itself never cues them.
        "note_kalimba": ("one single clear note plucked once on a real kalimba and left to ring out, only one note, nothing else", 1.5, -6, POND_TUNE, "warm:7000"),
        "note_box":     ("one single bright delicate note plucked once on the comb of a real wooden music box and left to ring out, only one note, nothing else", 1.5, -6, POND_TUNE, "warm:7000"),
        "note_low":     ("one single low warm round note plucked once on a real bass kalimba and left to ring out, deep and soft, only one note, nothing else", 1.5, -6, POND_TUNE, "warm:7000"),
    },
    # Pixel Garden: copy a little picture onto a pegboard in beads; a full
    # plate is ironed. Re-recorded 2026-10-01 (the polish) as BEADBOX: real
    # beads, box, tweezers and iron, every note a kalimba or music box. `place`
    # fires on every bead a stroke seats (pitched a hair apart), so it is tiny
    # and quiet and cut to its first click.
    "pixelgarden": {
        "place":    ("a single tiny soft click, one small plastic fuse bead set down onto a peg of a plastic pegboard with tweezers, light, very short", 0.5, -14, BEADBOX, "warm:7000", "cut:0.25"),
        "lift":     ("a tiny soft plucking tick, steel tweezers lifting one small plastic bead off a peg, very short and light", 0.5, -16, BEADBOX, "warm:7000", "cut:0.25"),
        "pick":     ("steel tweezers dipping into a compartment of small plastic beads, a tiny soft rattle, very short", 0.5, -13, BEADBOX, "warm:7000"),
        "peek":     ("a very short soft paper whoosh, a small paper pattern card lifted up to look at", 0.5, -15, BEADBOX, "warm:7000"),
        "refuse":   ("tweezers tapping the empty plastic bottom of a compartment twice, a soft hollow little tick tick, gentle", 0.5, -12, BEADBOX, "warm:7000"),
        "undo":     ("a tiny soft plucking tick and one small plastic bead dropped back into a box of beads, very short", 0.5, -12, BEADBOX, "warm:7000"),
        "hint":     ("a gentle sparkle, three soft kalimba notes rising with a tiny hand bell on top, kind and helpful", 1.0, -8, BEADBOX_TUNE, "warm:7000"),
        "check":    ("a soft two-note downward kalimba, gentle, kind, not yet", 0.6, -10, BEADBOX_TUNE, "warm:7000"),
        "check_ok": ("a soft bright three-note rising kalimba, all good", 0.7, -9, BEADBOX_TUNE, "warm:7000"),
        "reset":    ("a soft quick cascade of many small plastic beads pouring back into a clear plastic box", 1.0, -9, BEADBOX, "warm:7000"),
        "enter":    ("a soft handful of small plastic beads poured gently into a clear plastic compartment box", 1.0, -11, BEADBOX, "warm:7000"),
        "iron":     ("a warm household iron set down gently on baking paper with a soft gentle steam puff and a slow glide, cozy, quiet", 1.6, -9, BEADBOX, "warm:7000"),
        "steam":    ("one small soft puff of steam from a warm iron, a gentle short hiss, quiet and cozy", 0.7, -14, BEADBOX, "warm:7000"),
        "plate":    ("a small happy flourish, four soft kalimba notes rising with a tiny music box sparkle on top, a little square of bead art finished, proud and cute", 1.2, -7, BEADBOX_TUNE, "warm:7000"),
        "astray":   ("a few small plastic beads hopping off a pegboard and pattering back into a plastic box, soft and light, playful", 0.9, -11, BEADBOX, "warm:7000"),
        "heart_lost": ("a soft sad little two-note kalimba falling, gentle and kind, not scolding", 0.9, -9, BEADBOX_TUNE, "warm:7000"),
        "out_of_hearts": ("a slow gentle descending music box lullaby phrase, sleepy and soft, three notes winding down", 1.8, -9, BEADBOX_TUNE, "warm:7000"),
        "heart_back": ("a warm hopeful rising kalimba phrase with a small hand bell, a heart coming back", 1.0, -8, BEADBOX_TUNE, "warm:7000"),
        "combo":    ("a single bright soft kalimba note, warm and round, short", 0.5, -10, BEADBOX_TUNE, "warm:7000"),
        "steady":   ("a quick soft run of small plastic beads clicking onto pegs one after another, a tidy little patter, very light", 0.8, -13, BEADBOX, "warm:7000"),
        "confetti": ("a soft little paper confetti pop and flutter with a tiny music box twinkle, cute", 1.0, -10, BEADBOX_TUNE, "warm:7000"),
        "flutter":  ("a butterfly's soft wings fluttering past, a tiny delicate papery flutter, very quiet", 0.8, -16, BEADBOX, "warm:7000"),
        "stamp":    ("a soft rubber seal stamp thump on paper followed by a small warm music box sparkle, two bright rising notes ringing out, proud", 1.5, -7, BEADBOX_TUNE, "warm:7000"),
        "solved":   ("a warm short celebratory flourish on a real kalimba and a music box, rising arpeggio ending on a soft hand bell shimmer, joyful and cozy", 2.0, -5, BEADBOX_TUNE, "warm:7000"),
        "party":    ("a short cozy celebratory flourish on a real kalimba and a music box, rising and bright, with a few soft little party blower toots, warm and joyful", 2.0, -6, BEADBOX_TUNE, "warm:7000"),
        "purr":     ("a small cat purring softly and contentedly while curling up to sleep", 1.5, -14, COZY),
    },
    # Fairy Lights (puzzle_id "fairylights"): tap a piece of garden wire to
    # turn it; wire joined back to the post runs gold and wakes its lanterns.
    # Re-prompted 2026-09-30 (the polish) toward glass chimes, soft felt taps,
    # a music box and kalimba (DUSK in place of the house marimba): the
    # tape-rewind undo and the wooden "bonk" read as a toy or a scold, as they
    # did on Bridges, Sudoku and Quilt. Hard and Insane blow a fuse on a wrong
    # join; Insane is Wish Tags.
    "fairylights": {
        "place":    ("a single soft muffled felt tap with a tiny delicate glass tick, a small piece of garden wire turned a quarter, hushed, very short", 0.5, -11, DUSK),
        "join":     ("a tiny soft warm click and a faint little sparkle, two thin wires touching, very short and very quiet", 0.5, -15, DUSK),
        "wake":     ("a single tiny warm glass chime twinkle, a little paper lantern softly lighting up, very short and delicate", 0.5, -13, DUSK),
        "refuse":   ("a tiny soft kalimba note with a gentle little wobble, a kind 'not there', muffled and warm, very short", 0.5, -12, DUSK),
        "undo":     ("a tiny soft felt tap and a small kalimba note sliding gently down, a kind 'take that back', warm and quiet, very short", 0.5, -11, DUSK),
        "hint":     ("a gentle magical sparkle, three soft glass chime notes rising with a warm kalimba note underneath, cozy and kind", 1.0, -8, DUSK),
        "reset":    ("a soft quick descending ripple of tiny glass chimes fading out, garden lanterns dimming one after another, hushed and cozy", 1.0, -11, DUSK),
        "enter":    ("a soft airy cascade of tiny glass chime twinkles and a light leafy rustle, a little evening garden appearing at dusk, hushed", 1.0, -11, DUSK),
        "solved":   ("a warm short celebratory music box and glass chime flourish, rising arpeggio ending on a soft bright shimmer, a whole garden of lanterns lit, joyful and cozy", 2.0, -4, DUSK),
        # The streak and the gags.
        "combo":    ("a single short soft bright kalimba and glass chime pluck, one clean note, very short", 0.5, -8, DUSK),
        "confetti": ("a soft flutter of tiny paper confetti pieces falling with a tiny sparkling glass twinkle, light and airy", 1.0, -9, DUSK),
        "moth":     ("a small soft moth fluttering its papery wings close by, gentle quick delicate flaps, hushed", 0.8, -14, COZY),
        "hum":      ("a little lantern humming a tiny tune, three soft music box notes, sweet and sleepy, quiet", 0.9, -12, DUSK),
        "love":     ("a tiny soft sweet bubbly pop with a little two-note glass chime 'aww', cute and warm, short", 0.7, -10, DUSK),
        # Hearts and the fuse (Hard and Insane).
        "heart_lost":    ("a soft gentle glass chime two-note fall, a small sad 'oh', a delicate tink dropping, warm and muffled, never a buzzer", 0.6, -15, DUSK),
        "fuse":     ("a tiny soft warm electric fizz and a small muffled pop, a little bulb flickering off and on, cozy and gentle, not scary, short", 0.6, -14, COZY),
        "clip":     ("a small brass clip snapping onto a thin wire, a single soft little metallic click, close and quiet, very short", 0.5, -13, COZY),
        "out_of_hearts": ("a sleepy music box winding slowly down, a few soft notes descending and slowing, garden lights dimming for the night, calm and kind, maybe tomorrow", 1.6, -14, DUSK),
        "heart_back":    ("a warm rising pair of soft glass chime notes, a little heart coming back, gentle and happy", 0.6, -15, DUSK),
        # The party.
        "stamp":    ("a soft paper stamp thump followed by a clear warm glass chime sparkle, two bright rising notes ringing out and fading slowly, proud", 1.5, -5, DUSK),
        "party":    ("a short joyful garden party flourish on a music box and glockenspiel, rising and bright with a flutter of paper at the end, warm and cozy", 2.0, -4, DUSK),
        "dance":    ("a short cheerful bouncy kalimba tune, four playful light hopping notes, a tiny happy dance, cozy and cute", 1.2, -9, DUSK),
        "fireflies":("an airy rising shimmer of many tiny soft twinkles, fireflies drifting up into a dusk sky, magical and gentle", 1.5, -11, DUSK),
        "purr":     ("a sleepy little cat curled up in a warm garden purring briefly, soft contented purr, cozy and warm, short", 1.0, -10, COZY),
        # Insane: Wish Tags.
        "tags":     ("little paper wish tags fluttering on a string in a soft breeze with a warm golden glass chime shimmer, cozy and magical", 1.3, -11, DUSK),
    },
    # Firefly (Arcade, arcade/firefly_screen.gd): a formation shooter in a
    # night garden. `shoot` fires several times a second, so it is short
    # and quiet; `beam` is the moth's silk beam, looped while it is open.
    # Re-recorded 2026-10-05 off the chiptune: NIGHT foley for the shot, the
    # pop, the dive and the beam, ARCADE's kalimba and music box for the rest.
    "firefly": {
        "shoot":    ("one tiny soft dry click of a fingertip flicking a small seed off a leaf, very short and quiet", 0.5, -14, NIGHT, "warm:6000", "cut:0.08"),
        "pop":      ("one single small soft round pop of a cork pulled from a tiny bottle, dry, no ringing, very short", 0.5, -9, NIGHT, "warm:6000", "cut:0.15"),
        "pop_moth": ("a bigger round soft pop followed by a bright sprinkle of small hand bells and music box notes, a big moth sent off, short and satisfying", 0.7, -6, ARCADE),
        "hurt":     ("one short low hollow note on a wooden tongue drum, damped at once, an armoured ladybird hit but not beaten yet, very short", 0.5, -9, ARCADE),
        "dive":     ("a quick soft breathy swoop of a paper fan swept down through the air, falling, a bug diving, quick", 0.8, -13, NIGHT),
        "beam_open":("a soft rising run on a real music box with a shimmer of tiny hand bells opening up, a ribbon of silk light unrolling, gentle", 0.8, -8, ARCADE),
        "beam":     ("a steady soft shimmering tremolo of tiny hand bells over a gently singing glass rim, a ribbon of silk light, continuous, even, no accents, no ending", 3.0, -12, NIGHT, "loop"),
        "captured": ("a sad little wobbling slide down on a real kalimba, a few notes bending lower, a little friend caught and carried up, gentle", 1.2, -7, ARCADE),
        "carried":  ("a short low minor two-note fall on a real kalimba, a friend lost, soft", 0.8, -9, ARCADE),
        "rescue":   ("a bright happy rising run on a real kalimba with a music box sparkle on top, a friend set free", 1.0, -5, ARCADE),
        "docked":   ("a cheerful quick pair of music box notes with a soft wooden click, two friends joining up, stronger together", 0.7, -5, ARCADE),
        "rogue":    ("a short low uneasy two-note wobble on a wooden tongue drum, something turning against you, soft, not scary", 0.8, -9, ARCADE),
        "ship_pop": ("a soft round paper-bag 'poof' fading into a falling sprinkle of tiny hand bells, a little firefly's light going out, not too loud", 1.2, -5, ARCADE),
        "start":    ("a short cheerful opening tune on a real kalimba and music box, a bouncy rising melody with a hand bell on top, a game beginning, about three seconds", 3.0, -4, ARCADE),
        "stage":    ("a short bright three-note fanfare on a real music box and hand bells, a new stage beginning", 1.2, -6, ARCADE),
        "clear":    ("a quick happy rising run on a real kalimba ending on a hand bell, a wave cleared", 1.0, -6, ARCADE),
        "flyby":    ("a playful bouncy little tune on a real kalimba and a wooden tongue drum, a bonus round starting", 1.8, -5, ARCADE),
        "result":   ("a short friendly run of music box notes counting up one by one, a score being tallied", 1.2, -6, ARCADE),
        "perfect":  ("a triumphant sparkling fanfare on a real kalimba, music box and hand bells, a perfect bonus round, joyful", 2.2, -4, ARCADE),
        "extra":    ("three bright rising notes on a real music box with a hand bell sparkle, an extra life earned", 1.0, -5, ARCADE),
        "game_over":("a gentle slow descending melody on a real kalimba, a few soft notes stepping down, the game is over, kind and calm, never sad", 2.2, -5, ARCADE),
        "new_best": ("a joyful celebratory fanfare on a real kalimba, music box and soft hand bells, landing on a bright warm chord, a new high score", 2.4, -4, ARCADE),
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
        "combo":       ("a bright rising three-note run on a real kalimba with a hand bell sparkle, a combo multiplier going up, short", 0.7, -6, ARCADE),
        "streak_lost": ("a short soft two-note fall on a real kalimba, a streak broken, gentle", 0.5, -10, ARCADE),
        "go":          ("two short bright rising notes on a real music box with a little hand bell on top, a round starts, cheerful", 0.6, -5, ARCADE),
        "tick":        ("a single soft wooden clock tick with a tiny bell, a countdown second, very short", 0.5, -9, ARCADE),
        "frenzy":      ("an excited quick rising run on a real kalimba over a soft roll of fingers drumming on a wooden box, the last ten seconds, double points", 1.2, -5, ARCADE),
        "time_up":     ("a cheerful alarm clock 'brring' bell, very short, time is up", 0.8, -6, CARTOON),
        "start":       ("a short cheerful opening tune on a real kalimba and music box, a bouncy garden melody, a game beginning, about two seconds", 2.2, -4, ARCADE),
        "game_over":   ("a gentle slow descending melody on a real kalimba, a few soft notes stepping down, the game is over, kind and calm, never sad", 2.2, -5, ARCADE),
        "new_best":    ("a joyful celebratory fanfare on a real kalimba, music box and soft hand bells, landing on a bright warm chord, a new high score", 2.4, -4, ARCADE),
    },
    # Stackwood (Arcade, arcade/stackwood_screen.gd): numbered wooden toy
    # blocks that fall and merge. The blocks are CARTOON wood; the jingles
    # ARCADE (a kalimba and music box since 2026-10-05). move and land fire
    # on every block, so they sit low; merge is pitched up the chain by the
    # screen.
    "stackwood": {
        "move":      ("a tiny soft wooden tick, a toy block nudged one step sideways, very short", 0.5, -18, CARTOON),
        "drop":      ("a quick soft airy whoosh of a small wooden block dropping, very short", 0.5, -14, CARTOON),
        "land":      ("a soft hollow wooden toy block landing on a stack of blocks, a warm 'tock', very short", 0.5, -9, CARTOON),
        "merge":     ("two wooden toy blocks clicking together into one with a bright soft chime, satisfying, very short", 0.5, -6, CARTOON),
        "chain":     ("a quick bright rising three-note run on a real kalimba with a hand bell sparkle, a chain combo, short", 0.7, -6, ARCADE),
        "big":       ("two bright happy notes on a real music box with a hand bell sparkle, a new biggest block made, short", 0.8, -5, ARCADE),
        "milestone": ("a joyful triumphant fanfare on a real kalimba, music box and hand bells, a great block reached at last, about two seconds", 2.2, -4, ARCADE),
        "wild":      ("a soft swirling run of tiny hand bells and music box notes, a rainbow shimmer, magical, soft and bright, short", 0.8, -7, ARCADE),
        "buy":       ("a cheerful two-note music box chime with a tiny coin clink, a power-up bought, short", 0.6, -7, ARCADE),
        "fuse":      ("a short soft cartoon fuse hiss and crackle, a little bomb lit, short", 0.7, -10, CARTOON),
        "bomb":      ("a soft round cartoon 'boom' with wooden blocks scattering, playful, not harsh, short", 0.9, -5, CARTOON),
        "zap":       ("a quick soft crackle of a dry twig snapping with a bright sprinkle of tiny hand bells, a playful little lightning bolt, short", 0.7, -7, ARCADE),
        "refused":   ("one soft low damped note on a wooden tongue drum, a kind 'not yet', not enough acorns, gentle, very short", 0.5, -10, ARCADE),
        "warn":      ("two soft worried notes on a real kalimba, the second a little lower, a stack near the top, gentle, not alarming", 0.6, -9, ARCADE),
        "retired":   ("a soft pop and a small falling sprinkle of music box notes, the smallest blocks put away, short", 0.6, -8, ARCADE),
        "topple":    ("a tall stack of wooden toy blocks toppling and tumbling down, a cascade of hollow wooden clatters, about a second and a half", 1.5, -5, CARTOON),
        "go":        ("two short bright rising notes on a real music box with a little hand bell on top, a game starts, cheerful", 0.6, -5, ARCADE),
        "start":     ("a short cheerful opening tune on a real kalimba and music box, a bouncy toy-box melody, a game beginning, about two seconds", 2.2, -4, ARCADE),
        "game_over": ("a gentle slow descending melody on a real kalimba, a few soft notes stepping down, the game is over, kind and calm, never sad", 2.2, -5, ARCADE),
        "new_best":  ("a joyful celebratory fanfare on a real kalimba, music box and soft hand bells, landing on a bright warm chord, a new high score", 2.4, -4, ARCADE),
    },
    # Lucky Thirteen (Arcade, arcade/thirteen_screen.gd): numbered river
    # pebbles merged by drawing chains. Re-recorded 2026-10-05 as RIVERBED
    # foley (the user hated the set). select fires on every pebble a chain
    # takes and is pitched up the chain by the screen, a little. **It is a
    # click, and the first take of all**: for an hour it was a kalimba note
    # up the pentatonic, and the user: "it's important to avoid bell or
    # ring sounds for something that repeat a lot, so use something more
    # like a click, previous selection sound were in the right direction".
    # merge is every move's, so it is a clack with no note either.
    "thirteen": {
        "select":     ("a single tiny soft click of a smooth river pebble tapped, bright and clean, very short", 0.5, -14, CARTOON),
        "unselect":   ("a tiny soft low 'tok' of one smooth pebble set back down on damp sand, muffled, very short", 0.5, -18, RIVERBED, "warm:5000"),
        "short":      ("one soft low damped note on a wooden tongue drum, a kind 'not yet', not enough pebbles, gentle, very short", 0.5, -10, ARCADE),
        "merge":      ("three smooth river pebbles clicking softly together one after another, a little satisfying clack, dry, no ringing, very short", 0.6, -6, RIVERBED, "warm:6000"),
        "land":       ("a tiny soft low 'tup' of one smooth pebble settling onto damp sand, muffled, very short", 0.5, -16, RIVERBED, "warm:5000"),
        "new_number": ("two bright happy notes on a real music box with a hand bell sparkle, a new biggest number made, short", 0.8, -5, ARCADE),
        "goal":       ("a joyful triumphant fanfare on a real kalimba, music box and hand bells with one lucky bell ringing on top, the number thirteen reached, about two seconds", 2.4, -4, ARCADE),
        "stuck":      ("two soft worried notes falling on a real kalimba, no moves left, gentle, not alarming", 0.7, -8, ARCADE),
        "arm":        ("a soft quick wooden click and one tiny rising kalimba note, a tool picked up, short", 0.5, -10, ARCADE),
        "undo":       ("a short soft brush of a hand over sand with one small kalimba note gliding gently down, a kind 'take that back', short", 0.6, -8, ARCADE),
        "swap":       ("two smooth river pebbles sliding past each other over damp sand, a soft double hush, short", 0.6, -8, RIVERBED, "warm:6000"),
        "pluck":      ("one smooth pebble lifted out of damp sand with a soft low 'thup', short", 0.5, -7, RIVERBED, "warm:6000"),
        "shuffle":    ("a handful of smooth river pebbles rolled gently round a shallow wooden tray, a soft low rolling clatter, about a second", 1.0, -7, RIVERBED, "warm:6000"),
        "lift":       ("a soft rising pair of kalimba notes with a hand bell sparkle, a pebble raised up one, short", 0.6, -7, ARCADE),
        "refused":    ("one soft low damped note on a wooden tongue drum, a kind 'not yet', not allowed, gentle, very short", 0.5, -10, ARCADE),
        "tumble":     ("a trayful of smooth river pebbles tipped slowly out onto sand, a soft low cascade of stone clicks, about a second and a half", 1.5, -6, RIVERBED, "warm:6000"),
        "start":      ("a short cheerful opening tune on a real kalimba and music box, a bouncy lucky little melody, a game beginning, about two seconds", 2.2, -4, ARCADE),
        "game_over":  ("a gentle slow descending melody on a real kalimba, a few soft notes stepping down, the game is over, kind and calm, never sad", 2.2, -5, ARCADE),
        "new_best":   ("a joyful celebratory fanfare on a real kalimba, music box and soft hand bells, landing on a bright warm chord, a new high score", 2.4, -4, ARCADE),
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
        "collect":      ("one single tiny soft dry wooden tick, very short and quiet", 0.5, -18, COZY, "warm:6000", "cut:0.06"),
        "made_breeze":  ("a soft rising breath of air through leaves with a shimmer of tiny hand bells, a magical breeze being made, short", 0.6, -8, ARCADE),
        "made_bomb":    ("a soft rising sprinkle of music box notes over one warm low kalimba note, a seed pod swelling up, short", 0.7, -8, ARCADE),
        "made_rainbow": ("a bright rising run on a real music box and kalimba with shimmering hand bells, a rainbow flower appearing, about a second", 1.0, -6, ARCADE),
        "breeze":       ("a quick gust of wind sweeping across a garden, a clean whoosh with leaves rustling, short", 0.7, -6, CARTOON),
        "bomb":         ("a soft cartoon poof blast, a burst of seeds and petals, round and gentle not harsh, short", 0.7, -5, CARTOON),
        "rainbow":      ("a sweeping shower of hand bells and music box notes scattering in every direction, sparkling and magical, about a second", 1.1, -5, ARCADE),
        "goal":         ("two bright happy notes on a real music box, a goal completed, short", 0.7, -6, ARCADE),
        "cheer":        ("a short joyful flourish on a real kalimba with a hand bell sparkle, a big cascade, happy", 0.8, -7, ARCADE),
        "day_done":     ("a joyful short garden fanfare on a real kalimba, music box and hand bells, a day's goals completed, about two seconds", 2.0, -4, ARCADE),
        "deal":         ("a soft airy cascade of many small tiles tumbling into a wooden tray, about a second", 1.0, -9, CARTOON),
        "shuffle":      ("a handful of small wooden tiles shaken and rattled in a tray, a quick rolling clatter, about a second", 1.0, -8, CARTOON),
        "convert":      ("a soft twinkle of two tiny music box notes, a tile turning special, short", 0.6, -9, ARCADE),
        "gift":         ("a cheerful little rising music box phrase with a hand bell sparkle, a present, a tool earned, short", 0.8, -7, ARCADE),
        "trowel":       ("a small garden trowel digging into soft soil, a quick scoop and a soft pop, short", 0.6, -7, CARTOON),
        "arm":          ("a soft quick wooden click and one tiny rising kalimba note, a tool picked up, short", 0.5, -10, ARCADE),
        "refused":      ("one soft low damped note on a wooden tongue drum, a kind 'not yet', not allowed, gentle, very short", 0.5, -10, ARCADE),
        "out_of_moves": ("a soft slow descending wobble, out of moves, gentle and kind, not sad", 1.0, -7, CARTOON),
        "start":        ("a short cheerful opening tune on a real kalimba and music box, a bouncy flowery little melody, a game beginning, about two seconds", 2.2, -4, ARCADE),
        "game_over":    ("a gentle slow descending melody on a real kalimba, a few soft notes stepping down, the game is over, kind and calm, never sad", 2.2, -5, ARCADE),
        "new_best":     ("a joyful celebratory fanfare on a real kalimba, music box and soft hand bells, landing on a bright warm chord, a new high score", 2.4, -4, ARCADE),
        # the genre pass (2026-09-28): the bee, the bed's ground, the offer
        "made_bee":     ("a soft cheerful buzzy little trill, a tiny bee appearing, playful, short", 0.6, -8, CARTOON),
        "bee":          ("a quick soft cartoon bee buzz zipping away, playful, short", 0.6, -8, CARTOON),
        "bee_hit":      ("a tiny soft cartoon 'bop' as a bee lands on a flower, very short", 0.5, -10, CARTOON),
        "weed":         ("a small tuft of grass pulled out of soft soil, a quick rip and a soft pop, short", 0.5, -9, CARTOON),
        "stone":        ("a small soft cartoon knock on a garden stone, a light crack, short", 0.5, -9, CARTOON),
        "stone_break":  ("a soft cartoon garden stone crumbling apart into pebbles, round not harsh, short", 0.7, -7, CARTOON),
        "moss":         ("a soft squishy creeping sound, moss spreading over a tile, gentle and slightly sneaky, short", 0.6, -10, CARTOON),
        "moss_clear":   ("a soft fluffy poof, a clump of moss plucked away, short", 0.5, -9, CARTOON),
        "offer":        ("a gentle hopeful two-note question on a real kalimba, the second note rising, so close, not sad", 0.8, -7, ARCADE),
        "more_moves":   ("a bright cheerful rising sprinkle of music box notes and a hand bell, extra moves granted, short", 0.8, -6, ARCADE),
    },
    # Peapod (Arcade, arcade/peapod_screen.gd): a pea cannon against numbered
    # crates. The gun never stops, so a shot is the faintest click and a pea
    # landing a soft woody one, thinned by the screen, both played through
    # an Fx2D that knocks for nothing; pop is pitched up a streak, a little.
    # Levels by the user's ear (2026-10-05): "the block break is too loud,
    # and the block shoot hit is too low" at pop -8 and hit -18, so pop -14
    # (the golden one -9) and hit -10 (iron's clank -11). The hit since then
    # is a wooden tock with more body in it, 3 dB louder at the same peak,
    # so it sits at -13 to be as loud as the tap the user said yes to.
    # Re-recorded 2026-10-05 as PEAPATCH foley (the user hated the set).
    "peapod": {
        # 2026-10-05: the gun fires five to ten times a second for the whole
        # run. Its first sound was an airy half-second 'pft'; taking it away
        # altogether was wrong too -- the user: "we need a really subtle
        # click sound for every shoot". So a click, cut to its first 50 ms
        # and the quietest file in the game.
        "shot":      ("one tiny soft dry click of a small wooden toy pea shooter's catch, very short and quiet", 0.5, -24, PEAPATCH, "warm:6000", "cut:0.05"),
        "hit":       ("one single soft dry 'tock' on a small hollow wooden block tapped with a felt mallet, warm and round, damped at once, no ring, very short", 0.5, -13, PEAPATCH, "warm:6000", "cut:0.12", "tight"),
        "pop":       ("a small soft pine crate coming apart with one round low cork 'pop' and a light tumble of thin slats, gentle, very short", 0.5, -14, PEAPATCH, "warm:6000"),
        "pop_gold":  ("a small pine crate coming apart with a soft pop and a warm little spill of coins onto a wooden table, a golden prize, short", 0.8, -9, PEAPATCH, "warm:7000"),
        "gift":      ("one soft bright rising kalimba pluck with a tiny hand bell, a present popping out of a box, very short", 0.5, -8, ARCADE),
        "catch":     ("two bright happy rising notes on a real music box, a gift caught, short", 0.6, -6, ARCADE),
        "twin":      ("a cheerful bouncy three-note phrase on a real kalimba, a little helper joining in, short", 0.8, -5, ARCADE),
        "twin_off":  ("a short soft two-note fall on a real kalimba with a little puff of air, a helper leaving, gentle", 0.5, -10, ARCADE),
        "lost":      ("a tiny soft 'plip' of something small dropping into long grass, a gift missed, very short", 0.5, -12, PEAPATCH, "warm:6000"),
        "boom":      ("a soft round muffled 'whump' of a paper party popper going off under a blanket, with a few small pine crates tumbling over, playful, low, short", 0.9, -5, PEAPATCH, "warm:6000"),
        "knock":     ("a soft hollow knock of knuckles on a small empty pine crate, woody and gentle, very short", 0.5, -9, PEAPATCH, "warm:6000"),
        "head":      ("a big soft round pop of a paper bag followed by a bright sprinkle of small hand bells and music box notes, a big bug sent off, satisfying, short", 0.9, -5, ARCADE),
        "wave":      ("a short bright two-note fanfare on a real music box and a hand bell, a new wave beginning", 0.7, -7, ARCADE),
        "milli":     ("a short playful low marching riff of four quick notes on a wooden tongue drum, a big bug arriving on many little feet, not scary", 1.0, -7, ARCADE),
        "clear":     ("a quick happy rising run on a real kalimba ending on a hand bell, a wave cleared", 1.0, -6, ARCADE),
        "word":      ("a bright rising three-note run on a real kalimba with a hand bell sparkle, a combo streak, short", 0.7, -6, ARCADE),
        "warn":      ("two soft worried notes on a real kalimba, the second a little lower, something getting too close, gentle, not alarming", 0.6, -8, ARCADE),
        "over":      ("a soft thud and a light clatter of small wooden crates settling, then two clear gentle kalimba notes stepping down, kind and calm, never sad", 0.9, -6, ARCADE),
        "go":        ("two short bright rising notes on a real music box with a little hand bell on top, a round starts, cheerful", 0.6, -5, ARCADE),
        "start":     ("a short cheerful opening tune on a real kalimba and music box, a bouncy garden melody, a game beginning, about two seconds", 2.2, -4, ARCADE),
        "game_over": ("a gentle slow descending melody on a real kalimba, a few soft notes stepping down, the game is over, kind and calm, never sad", 2.2, -5, ARCADE),
        "new_best":  ("a joyful celebratory fanfare on a real kalimba, music box and soft hand bells, landing on a bright warm chord, a new high score", 2.4, -4, ARCADE),
        # the second pass (2026-10-04): an iron crate, a pod, the frost, the shove (the rotten
        # gift and its sound went on 2026-10-05)
        "clank":     ("a tiny soft dull 'tink' of one dried pea on a small tin watering can, damped at once, not ringing, very short", 0.5, -11, PEAPATCH, "warm:6000"),
        "pod":       ("three bright rising notes on a real kalimba with a soft wooden click, a new pod loaded, lively, short", 0.7, -6, ARCADE),
        "frost":     ("a soft falling shimmer of tiny glass bells and music box notes slowing down, a gentle frost settling over everything, short", 0.9, -7, ARCADE),
        "shove":     ("a big soft whoosh of a canvas sheet flapped once and a padded woody thump, everything pushed back, short", 0.8, -6, PEAPATCH, "warm:6000"),
    },
    # Rings: lift the top ring off a wooden peg and drop it on an empty peg
    # or on its own colour; four of a colour fill a peg and lock it.
    "rings": {
        "lift":     ("a tiny soft hollow wooden ring sliding up off a smooth felt-lined dowel, a light airy lift with a faint kalimba breath, very short", 0.5, -12, TERRACE),
        "drop":     ("a single soft hollow wooden ring settling down onto a felt-cushioned stack of rings, a gentle muted wooden clack, very short", 0.5, -9, TERRACE),
        "lock":     ("a short happy two-note soft kalimba pluck with a tiny music box sparkle and a little daisy pop, a peg filled with one colour", 0.7, -7, TERRACE),
        "refused":  ("a tiny soft kalimba note with a gentle little wobble and a muffled felt tap, a kind 'not there', very short", 0.5, -12, TERRACE),
        "undo":     ("a tiny soft wooden ring sliding back with a small kalimba note gliding gently down, a kind 'take that back', warm and quiet, very short", 0.5, -11, TERRACE),
        "hint":     ("a gentle magical sparkle, three soft music box notes rising with a warm kalimba note underneath, cozy and kind", 1.0, -8, TERRACE),
        "reset":    ("a soft ripple of hollow wooden rings settling one after another onto felt, hushed and cozy", 1.0, -11, TERRACE),
        "enter":    ("a soft airy cascade of tiny felt-muted wooden clacks and leaves rustling, stacks of rings appearing on a sunny terrace, hushed", 1.0, -11, TERRACE),
        "solved":   ("a warm short celebratory music box and kalimba flourish, rising arpeggio ending in a soft bright shimmer and a happy rustle of leaves, joyful and cozy", 2.0, -4, TERRACE),
        # The polish (docs/superpowers/specs/2026-10-01-rings-polish-design.md).
        "combo":    ("a single short soft bright kalimba and music box pluck, one clean note, very short", 0.5, -8, TERRACE),
        "confetti": ("a soft flutter of tiny paper confetti pieces falling with a tiny sparkling music box twinkle, light and airy", 1.0, -9, TERRACE),
        "twirl":    ("a little wooden ring spinning happily on a smooth peg, a soft rising whirr with a playful two-note kalimba whistle and a tiny hop, cute", 0.9, -11, TERRACE),
        "love":     ("a tiny soft sweet bubbly pop with a little two-note music box 'aww', cute and warm, short", 0.7, -10, TERRACE),
        "buzz":     ("a tiny fuzzy bumblebee buzzing a happy loop around and drifting away, soft and cute, a little music box twinkle, never annoying", 1.2, -15, TERRACE),
        "tumble":   ("a soft wooden ring flipping over in the air, a quick airy whoosh and a playful little kalimba flip, two notes up then down, cute, very short", 0.5, -12, TERRACE),
        "wobble":   ("a wooden ring wobbling uncertainly on top of a stack, a soft rattling clatter slowing down with a small worried kalimba note bending down, gentle, short", 0.7, -12, TERRACE),
        "heart_lost":    ("a soft gentle kalimba two-note fall, a small sad 'oh', a delicate note dropping, warm and muffled, never a buzzer", 0.6, -15, TERRACE),
        "hop_back": ("a soft wooden ring hopping back home, a light airy boing and a felt-soft clack, kind, short", 0.5, -12, TERRACE),
        "out_of_hearts": ("a sleepy music box winding slowly down, a few soft notes descending and slowing, a garden terrace at dusk going quiet, calm and kind, maybe tomorrow", 1.6, -14, TERRACE),
        "heart_back":    ("a warm rising pair of soft kalimba plucks, a little heart coming back, gentle and happy", 0.6, -15, TERRACE),
        "stamp":    ("a soft paper stamp thump followed by a clear warm music box chime sparkle, two bright rising notes ringing out and fading slowly, proud", 1.5, -5, TERRACE),
        "party":    ("a short joyful flourish on a music box and kalimba, rising and bright with a flutter of paper at the end, warm and cozy", 2.0, -4, TERRACE),
        "hoop":     ("a wooden hoop rolling across stone flags, a soft rumbling roll with a wobbly spin settling down flat, a playful kalimba glissando, cute", 1.6, -11, TERRACE),
        "purr":     ("a small cat purring contentedly, soft and close, a cozy rumble, very gentle", 1.4, -16, COZY),
    },
    # Drumbeat (puzzles/drumbeat2d.gd): a band of four drums at a garden
    # festival at dusk. The drums themselves (drum_0..3) are synthesised by
    # tools/gen_drumbeat.py with the songs, not generated here: they play on
    # every stroke over the music and must start on their first sample.
    # 2026-10-01 (the polish): every cue taken again as FESTIVAL /
    # FESTIVAL_TUNE -- real hand percussion, paper lanterns, kalimba, music
    # box and hand bells -- and the hearts, Echo and the silly rewards added.
    "drumbeat": {
        "enter":        ("a soft evening garden festival settling in, distant paper lanterns rustling in a breeze, one warm low kalimba note and a tiny wind chime", 1.0, -12, FESTIVAL, "warm:7000"),
        "select":       ("a single tiny soft wooden click of a small wooden bead, very short", 0.5, -13, FESTIVAL, "warm:7000", "cut:0.1"),
        "reset":        ("a soft rustle of paper lanterns and one calm low kalimba note, a garden stage getting ready again", 0.9, -12, FESTIVAL_TUNE, "warm:7000"),
        "gogo":         ("a joyful swell of small hand bells and a soft shaker rising into one warm gentle frame drum hit and a kalimba sparkle, the festival begins, cozy", 1.4, -6, FESTIVAL_TUNE, "warm:7000"),
        "soul":         ("three bright rising music box notes with a small hand bell shimmer, a meter filling past its line, delicate", 0.8, -9, FESTIVAL_TUNE, "warm:7000"),
        "combo":        ("a single short bright pluck on a real kalimba with a tiny bell, one clean warm note, very short", 0.5, -10, FESTIVAL_TUNE, "warm:7000"),
        "break":        ("a soft comic little wooden wobble, a drumstick fumbled onto a soft mat, gentle and funny, never harsh", 0.5, -13, FESTIVAL, "warm:7000"),
        "balloon":      ("a tiny soft rubbery squeak of a small party balloon being squeezed, very short", 0.5, -13, FESTIVAL, "warm:7000", "cut:0.25"),
        "pop":          ("a small party balloon popping with a soft round pop and a flutter of paper confetti and a tiny bell, cheerful", 0.8, -6, FESTIVAL, "warm:7000"),
        "balloon_gone": ("a small balloon slowly deflating and flying off with a soft comic squeaky whistle, short and funny", 0.9, -11, FESTIVAL, "warm:7000"),
        "clear":        ("a warm joyful rising run on a real kalimba, music box and soft hand bells over a gentle hand drum, landing on a bright chord, cozy and triumphant", 2.4, -5, FESTIVAL_TUNE, "warm:7000"),
        "full_combo":   ("a happy festive flourish of hand bells, music box and kalimba with a soft frame drum roll ending on one warm big drum hit and a sparkle, a perfect performance, cozy", 2.8, -4, FESTIVAL_TUNE, "warm:7000"),
        "fail":         ("a gentle short descending kalimba phrase, a kind try again, soft and warm, never sad", 1.6, -9, FESTIVAL_TUNE, "warm:7000"),
        "heart_lost":   ("a soft gentle kalimba two-note fall, a small sad 'oh', warm and muffled, never a buzzer", 0.6, -12, FESTIVAL_TUNE, "warm:7000"),
        "out_of_hearts":("a real wind-up music box winding slowly down, a few soft notes descending and slowing, a garden festival at night going quiet, calm and kind", 1.8, -12, FESTIVAL_TUNE, "warm:7000"),
        "heart_back":   ("a warm rising pair of soft kalimba plucks and a tiny hand bell, a little heart coming back, gentle and happy", 0.7, -11, FESTIVAL_TUNE, "warm:7000"),
        "echo":         ("a friendly little call of three quick soft wooden tongue drum notes rising, then a tiny bell, your turn, playful and cozy", 0.8, -8, FESTIVAL_TUNE, "warm:7000"),
        "echo_perfect": ("a sweet shimmering answer of soft hand bells and a music box, two bright notes ringing together, a call answered perfectly, magical and warm", 1.0, -8, FESTIVAL_TUNE, "warm:7000"),
        "golden":       ("a shower of small soft coins and a bright warm music box glissando with a hand bell, a golden treasure found, joyful and cozy", 1.2, -7, FESTIVAL_TUNE, "warm:7000"),
        "conga":        ("a playful little soft hand drum and shaker conga shuffle with a kalimba hop, bouncy and cute, critters dancing in a line, cozy", 1.6, -9, FESTIVAL_TUNE, "warm:7000"),
        "shades":       ("a playful cool little slide up on a kalimba ending in a tiny bright music box 'ting', a frog putting on sunglasses, funny and cute, short", 0.7, -9, FESTIVAL_TUNE, "warm:7000"),
        "hold_done":    ("one soft round chime of a small hand bell, warm and clear, very short", 0.6, -12, FESTIVAL_TUNE, "warm:7000"),
        "tune_done":    ("two soft warm wooden tongue drum notes and a tiny bell, everything in tune, gentle and satisfied", 0.8, -10, FESTIVAL_TUNE, "warm:7000"),
        "stamp":        ("a soft rubber seal stamp thump on paper followed by a small warm music box sparkle, two bright rising notes ringing out, proud", 1.5, -6, FESTIVAL_TUNE, "warm:7000"),
        "party":        ("a short cozy celebratory flourish on a real kalimba and a music box with soft party blower toots and a gentle hand drum, rising and bright, warm and joyful", 2.0, -6, FESTIVAL_TUNE, "warm:7000"),
        "purr":         ("a small cat purring softly and contentedly while curling up to sleep", 1.5, -14, COZY),
    },
    # Trestle (puzzles/trestle2d.gd): a bridge built of road planks, wooden
    # beams and rope over a river, then a little cart of fruit (on Insane
    # with cups of tea) sent across; the bridge troll keeps score. All of it
    # WORKSHOP foley and WORKSHOP_TUNE notes since the 2026-10-01 polish.
    "trestle": {
        "enter":         ("a gentle brook babbling softly and a few small wooden planks set down one after another on a workbench, a calm riverside workshop opening", 1.2, -10, WORKSHOP, "warm:7000"),
        "select":        ("a single tiny soft click of a small wooden peg, very short", 0.5, -13, WORKSHOP, "cut:0.25"),
        "place_road":    ("one small pine plank laid flat onto a wooden frame, a single soft solid knock, very short", 0.5, -8, WORKSHOP, "cut:0.3"),
        "place_wood":    ("one light wooden dowel set into a frame with a soft hollow knock and a tiny brass bolt click, very short", 0.5, -9, WORKSHOP, "cut:0.3"),
        "place_rope":    ("a short piece of hemp rope pulled taut with a soft creak and a little knot tug, very short", 0.5, -10, WORKSHOP),
        "remove":        ("a small wooden stick lifted off a frame and set aside with a soft wooden clack, very short", 0.5, -10, WORKSHOP, "cut:0.3"),
        "refused":       ("two soft low knocks on a hollow wooden box, a gentle not quite, very short", 0.5, -11, WORKSHOP),
        "undo":          ("a small wooden piece slid back across a wooden table with a soft brush, very short", 0.5, -11, WORKSHOP),
        "hint":          ("three soft rising notes on a real music box with a tiny hand bell shimmer, gentle and kind", 1.0, -8, WORKSHOP_TUNE, "warm:7000"),
        "reset":         ("a handful of small wooden sticks gathered up and stacked softly into a wooden box", 1.0, -9, WORKSHOP),
        "go":            ("a small wooden toy cart starting to roll on wooden boards with a soft rattle, and one cheerful little brass bicycle bell ring", 1.0, -8, WORKSHOP),
        "roll":          ("continuous steady soft rumble of small wooden toy cart wheels rolling over wooden planks, even, no bumps, no clicks", 3.0, -13, WORKSHOP, "loop"),
        "creak":         ("a single soft low creak of a small wooden beam taking weight, close mic", 0.7, -10, WORKSHOP),
        "snap":          ("a small dry wooden stick snapping in two with a soft crack and a light splinter, close mic, short", 0.6, -6, WORKSHOP, "cut:0.45"),
        "snap_rope":     ("a thin taut hemp string snapping with a soft twang, short", 0.5, -7, WORKSHOP, "cut:0.4"),
        "whoa":          ("three soft descending notes on a real kalimba, a little oh no, playful and gentle", 0.8, -10, WORKSHOP_TUNE, "warm:7000"),
        "bump":          ("a small wooden toy cart landing on wooden boards with a soft thump and a little wheel rattle, short", 0.5, -9, WORKSHOP, "cut:0.4"),
        "splash":        ("a small wooden toy dropped into a calm stream with a round soft splash and a few bubbles, short", 1.0, -7, WORKSHOP),
        "fail":          ("a gentle short descending phrase on a real kalimba, four soft notes, a kind try again, warm not sad", 1.3, -9, WORKSHOP_TUNE, "warm:7000"),
        "cross":         ("a small wooden toy cart rolling off wooden boards onto soft grass and two cheerful little brass bicycle bell rings", 0.9, -8, WORKSHOP),
        "solved":        ("a warm short celebratory flourish on a real kalimba and a music box, a rising arpeggio ending on a bright hand bell, joyful and cozy", 2.0, -5, WORKSHOP_TUNE, "warm:7000"),
        "settle":        ("a small wooden frame easing back into place with one soft gentle creak and a tiny settle, short", 0.6, -12, WORKSHOP),
        "honk":          ("one squeeze of a small rubber bulb toy horn, a soft round honk, cute and funny, short", 0.5, -10, WORKSHOP, "cut:0.4"),
        "clink":         ("two china teacups clinked together gently, a soft bright ceramic clink, cheers, short", 0.5, -10, WORKSHOP, "cut:0.4"),
        "slosh":         ("tea sloshing up the side of a full china teacup, a small liquid swirl, close mic, short", 0.6, -11, WORKSHOP),
        "spill":         ("a splash of tea spilling over the rim of china teacups onto a wooden tray with a little ceramic rattle, short", 0.8, -8, WORKSHOP),
        "heart_lost":    ("two soft descending notes on a real kalimba, a small sigh, gentle, short", 0.7, -10, WORKSHOP_TUNE, "warm:7000"),
        "out_of_hearts": ("a slow sleepy descending lullaby phrase on a real music box winding down, soft and peaceful", 1.8, -9, WORKSHOP_TUNE, "warm:7000"),
        "heart_back":    ("three soft rising notes on a real kalimba and a little hand bell, hopeful and warm", 1.0, -8, WORKSHOP_TUNE, "warm:7000"),
        "scorecard":     ("a small wooden paddle sign flipped up with a soft wooden clack and a tiny bright music box ting, proud and funny, short", 0.8, -9, WORKSHOP_TUNE, "warm:7000"),
        "stamp":         ("a soft rubber seal stamp thump on paper followed by a small warm music box sparkle, two bright rising notes ringing out, proud", 1.5, -7, WORKSHOP_TUNE, "warm:7000"),
        "quack":         ("a mother duck giving two soft friendly quacks and tiny ducklings peeping, by a calm stream, gentle", 1.2, -12, WORKSHOP),
        "purr":          ("a small cat purring softly and contentedly while curling up to sleep", 1.5, -14, COZY),
    },
    # Mini Golf (puzzles/minigolf2d.gd): a ball putted round a felt green
    # inside a wooden kerb, into a cup with a flag in it; the card's words
    # (hole in one, birdie, par, bogey) each have their own short phrase.
    "minigolf": {
        "enter":         ("a few garden birds chirping softly and one golf ball set down on felt with a small soft tap, a calm sunny lawn", 1.3, -11, LINKS, "warm:7000"),
        "putt":          ("a putter striking a golf ball once, a single soft rounded tock, very short", 0.5, -7, LINKS, "cut:0.3"),
        "wall":          ("a golf ball knocking once against a wooden board, a single soft hollow wooden knock, very short", 0.5, -9, LINKS, "cut:0.25"),
        "post":          ("a golf ball bouncing off a rubber bumper with one soft springy boing, playful, very short", 0.5, -8, LINKS, "cut:0.35"),
        "sand":          ("a golf ball rolling into fine dry sand and stopping, a short soft hiss of sand", 0.6, -11, LINKS),
        "splash":        ("a golf ball dropping into a small garden pond with one round soft plop and a few bubbles, short", 0.9, -7, LINKS),
        "lip":           ("a golf ball rattling round the rim of a plastic cup and rolling away, a short hollow rattle", 0.6, -9, LINKS, "cut:0.45"),
        "sink":          ("a golf ball dropping into a plastic mini golf cup with a hollow rattle at the bottom, satisfying, short", 0.7, -6, LINKS),
        "ace":           ("a bright joyful rising flourish on a real music box and hand bells, five quick notes ending on a high ringing bell, a little triumph", 1.6, -5, LINKS_TUNE, "warm:7000"),
        "birdie":        ("three quick bright rising notes on a real kalimba with a tiny hand bell on the last, happy, short", 0.9, -7, LINKS_TUNE, "warm:7000"),
        "par":           ("two soft warm rising notes on a real kalimba, content, short", 0.7, -9, LINKS_TUNE, "warm:7000"),
        "bogey":         ("two soft notes on a real kalimba, the second a little lower, a gentle never mind, short", 0.7, -10, LINKS_TUNE, "warm:7000"),
        "next":          ("a small cloth flag fluttering once in a light breeze, one soft airy whoosh, short", 0.7, -12, LINKS),
        "gate":          ("a small wooden garden gate swinging on its hinge with a soft creak and a little latch click, short", 0.7, -10, LINKS),
        "hint":          ("three soft rising notes on a real music box with a tiny hand bell shimmer, gentle and kind", 1.0, -8, LINKS_TUNE, "warm:7000"),
        "reset":         ("a paper scorecard flipped over and a small pencil tapped on it twice, soft, short", 0.8, -10, LINKS),
        "out_of_hearts": ("a slow sleepy descending lullaby phrase on a real music box winding down, soft and peaceful", 1.8, -9, LINKS_TUNE, "warm:7000"),
        "heart_back":    ("three soft rising notes on a real kalimba and a little hand bell, hopeful and warm", 1.0, -8, LINKS_TUNE, "warm:7000"),
        "solved":        ("a warm short celebratory flourish on a real kalimba and a music box, a rising arpeggio ending on a bright hand bell, joyful and cozy", 2.0, -5, LINKS_TUNE, "warm:7000"),
        "party":         ("a cozy celebratory kalimba and hand bell flourish rising, with a very soft muffled party blower toot at the end, joyful and warm", 2.0, -5, LINKS_TUNE, "warm:7000"),
        "stamp":         ("a soft rubber seal stamp thump on paper followed by a small warm music box sparkle, two bright rising notes ringing out, proud", 1.5, -7, LINKS_TUNE, "warm:7000"),
        "purr":          ("a small cat purring softly and contentedly while curling up to sleep", 1.5, -14, COZY),
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


def to_ogg(mp3: pathlib.Path, out: pathlib.Path, peak: int, loop: bool = False, warm: int = 0, cut: float = 0.0, tight: bool = False) -> None:
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
    head = "silenceremove=start_periods=1:start_threshold=-36dB:start_silence=0.004" if tight and not loop else trim
    # Warm (2026-09-29, Untangle): a take whose hiss or scratch sits above the
    # cozy family is rolled off -- two gentle low-pass poles and a high shelf
    # -- and eased in so its first transient is a touch rather than a click.
    soft = f",lowpass=f={warm}:p=2,highshelf=f={warm // 2}:g=-4,afade=t=in:d=0.004" if warm else ""
    if cut:
        soft += f",atrim=0:{cut},afade=t=out:st={cut * 0.6:.3f}:d={cut * 0.4:.3f}"
    with tempfile.TemporaryDirectory() as tmp:
        mono = pathlib.Path(tmp) / "mono.wav"
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(mp3),
                        "-af", f"{head},areverse,{trim},areverse{soft}",
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
        cut = next((float(f[4:]) for f in rest[1:] if isinstance(f, str) and f.startswith("cut:")), 0.0)
        raw = raw_dir / f"{cue}.mp3"
        if "--new" in flags or not raw.exists():
            raw.write_bytes(generate(key(), prompt, seconds, style, loop))
        out = out_dir / f"{cue}.ogg"
        if "fall" in rest[1:]:
            raw = fall(raw)
        to_ogg(raw, out, peak, loop, warm, cut, "tight" in rest[1:])
        print(f"{cue:9s} -> {out.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
