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

# The Grove's pond-side clearing (2026-10-05): chopping goes on for as long
# as a finger is held, so what repeats is a dry click of wood and nothing
# rings; a tree down is a soft crack and a hush of leaves.
GROVE = ("close-mic foley recorded in a quiet woodland clearing, real small "
         "green wood, twigs, bark and leaves, natural and acoustic, soft and "
         "warm, rounded, never sharp, no synth, no electronic tones, no beeps, "
         "no music, no voice")

# Nightlight's star (2026-10-06): space tempts a synth pad and a laser, and
# gets neither. What is a thing -- a puff of gas, a rock falling in, a body
# coming apart -- is close-mic foley of breath, flour, sand and felt in a
# warm room; what is a moment is ARCADE's kalimba, music box and bells.
HEARTH = ("close-mic foley recorded in a quiet warm room at night, real soft "
          "things, a breath of air, flour, fine dry sand, felt, wool and small "
          "round pebbles, natural and acoustic, soft and warm, rounded, never "
          "sharp, no synth, no electronic tones, no beeps, no science fiction, "
          "no whoosh, no music, no voice")

# Nightlight's notes (2026-10-09). The set was heard and was "too harsh":
# ARCADE's music box and hand bells, asked for bright, with a shimmer and a
# sparkle on top, peaking at -4 to -8. Its notes are a kalimba and a tongue
# drum played low and muffled now, and no prompt under this asks for a
# bell, a sparkle or anything bright.
HEARTH_TUNE = ("a real kalimba and a wooden tongue drum played very softly "
               "with felt, close in a warm quiet room at night, low, mellow, "
               "muffled, round, hushed, no bells, no chimes, no sparkle, no "
               "synth, no beeps, no music bed, no voice")

# The notes of a set redone against the cozy rules (2026-10-09, Binairo
# first). HEARTH_TUNE's "low" and "very softly" came back as one pure tone
# at 250 to 330 Hz, peaking at -26 dB: under what a phone plays (-35 dB
# high-passed at 400 Hz) and levelled up out of the room's noise. The same
# kalimba and tongue drum, asked for in the middle of the instrument and
# played gently; the roll-off is what keeps it dark.
COZY_TUNE = ("a real kalimba and a wooden tongue drum played gently with "
             "felt, close in a warm quiet room, the middle notes of the "
             "instrument, mellow, muffled, round and warm, not deep, no "
             "bass, no bells, no chimes, no sparkle, nothing bright, no "
             "synth, no beeps, no music bed, no voice")

# Nightlight's clicks (2026-10-09, the second go the same morning). The
# three cues that never stop were HEARTH's flour and sand cut to 60 ms: a
# sliver of hiss from 80 Hz to 12 kHz, a tick of static however quiet. They
# are dull low taps on wood and wool now, with a body and no hiss, and are
# let ring out a little longer.
HEARTH_TAP = ("close-mic foley in a quiet warm room, one soft low muffled "
              "tap on wood, felt or wool, round, dull and dark, a small "
              "body and no hiss, no rustle, no crackle, no sand, no click, "
              "no synth, no beeps, no music, no voice")

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

# Horse Pen's meadow from above (2026-10-08): real straw bales on turf, a
# wooden gate and its latch, a small pony, with the garden family's kalimba,
# music box and hand bells for what the day says. A bale is dropped on every
# move, so place, lift and undo are dry straw and nothing with a note.
MEADOW = ("close-mic foley of a small sunny meadow paddock on a quiet morning, "
          "real dry straw bales, short grass, a wooden gate with a wooden "
          "latch, natural and acoustic, soft and warm, rounded, no synth, no "
          "electronic tones, no beeps, no music, no voice")
MEADOW_TUNE = ("real acoustic kalimba, wooden music box and small hand bells "
               "recorded close in a warm quiet room, natural, soft, rounded, "
               "gentle, cozy, no synth, no electronic tones, no beeps, no music "
               "bed, no voice")
# The pony itself: the families above all end "no voice", which would ask
# the animal to keep quiet.
# Lattice's garden table (2026-10-09): small wooden number tiles set into the
# sockets of a wooden lattice, with the garden family's kalimba, music box
# and hand bells for what the day says. A tile is picked up and two are
# swapped on every move, and most swaps send one home, so pick, drop, swap,
# miss, home and undo are dry wood and nothing with a note.
TILES = ("close-mic foley recorded at a small wooden garden table on a quiet "
         "morning, real small flat wooden game tiles and a wooden lattice "
         "frame with shallow wooden sockets, natural and acoustic, soft and "
         "warm, dry, rounded, no synth, no electronic tones, no beeps, no "
         "music, no voice")
TILES_TUNE = ("real acoustic kalimba, wooden music box and small hand bells "
              "recorded close in a warm quiet room, natural, soft, rounded, "
              "gentle, cozy, no synth, no electronic tones, no beeps, no music "
              "bed, no voice")

# How Big?'s carpenter's bench (2026-10-08): rulers, a clamp, paper and a
# tape measure for what is not a note, and the polished boards' kalimba,
# music box and hand bells for what is.
BENCH = ("close-mic foley recorded at a small wooden workbench in a quiet "
         "warm room, a real wooden folding ruler, a small wooden clamp, thick "
         "paper and a tape measure, natural and acoustic, soft, dry, rounded, "
         "no synth, no electronic tones, no beeps, no music, no voice")
BENCH_TUNE = ("real acoustic kalimba, wooden music box, wooden tongue drum "
              "and small hand bells recorded close in a warm quiet room, "
              "natural, soft, rounded, gentle, cozy, no synth, no electronic "
              "tones, no beeps, no music bed, no voice")

# Golden Acorn's quiz (2026-10-08): a card table in a quiet room. What is
# not a note is index cards, a wooden tile and a pencil on a wooden table.
QUIZ = ("close-mic foley recorded at a small wooden card table in a quiet "
        "warm room, real stiff paper index cards, small wooden tiles and a "
        "pencil, natural and acoustic, soft, dry, rounded, no synth, no "
        "electronic tones, no beeps, no music, no voice")
QUIZ_TUNE = ("real acoustic kalimba, wooden music box, wooden tongue drum "
             "and small hand bells recorded close in a warm quiet room, "
             "natural, soft, rounded, gentle, cozy, no synth, no electronic "
             "tones, no beeps, no music bed, no voice")

# Pearl Dive's water (2026-10-09): a small wooden jetty over calm water.
# What is not a note is water, a wet rope, a plank and a small brass bell
# knocked with a knuckle (a dull knock, never a ring).
JETTY = ("close-mic foley recorded on a small wooden jetty over calm clear "
         "water on a quiet warm day, real water drops and small bubbles, a "
         "wet rope and wooden planks, natural and acoustic, soft, dry, "
         "rounded, no synth, no electronic tones, no beeps, no music, no voice")
JETTY_TUNE = ("real acoustic kalimba, wooden music box, wooden tongue drum "
              "and small hand bells recorded close in a warm quiet room, "
              "natural, soft, rounded, gentle, cozy, no synth, no electronic "
              "tones, no beeps, no music bed, no voice")

# The user, 2026-10-09, of the menu's page turn and Dominoes' tile: "a harsh
# scratch sound extremely annoying. I want something really really soft ...
# soft, cozy, low tics, swipes should sound more like a light breeze blowing,
# or like those old mouse wheel spinning doing those low pitch clicks, or
# maybe leaves being blown". What those takes shared, measured: a burst of
# noise with most of its energy between 1 and 8 kHz (a centroid near 3 kHz),
# which is what anything slid, brushed or clacked comes back as. So a thing
# set down or picked up is HUSH -- one low soft tick, rolled off near 1.5 kHz
# -- and a swipe is BREEZE, a breath of air with no hiss. No prompt under
# either says slide, brush, scrape, sweep, rustle or clack. Two traps, both
# fallen into the same day: asked for "deep" and "low-pitched" the takes came
# back under 300 Hz, which a phone does not play, so each cue names
# `body:<Hz>`, a high-pass, and what is levelled is the part between it and
# `warm` (300 Hz to 1.6 kHz or so); and asked for "very soft, quiet" the API
# returns near silence (a peak of -44 dB), which levelling turns into room
# noise -- the prompt asks for a plain soft tick and the level makes it quiet.
HUSH = ("close-mic recording in a quiet warm room, a soft muffled hollow "
        "wooden tick, like one notch of an old mouse wheel turned slowly, "
        "round, dull, gentle and cozy, low but not bassy, no thump, no "
        "rumble, no scratch, no scrape, no hiss, no rustle, no ring, no "
        "tone, no music, no voice")
BREEZE = ("a light warm breeze outdoors on a calm day, soft low air moving "
          "gently, hushed, round and cozy, no whistle, no hiss, no crackle, "
          "no scratch, no music, no voice")

PONY = ("close-mic recording of a real small friendly pony in a quiet sunny "
        "meadow, natural, soft, warm, gentle, cute, dry, no synth, no music, "
        "no human voice")

# Untangle's kitten (2026-10-10): a real one, where CARTOON's purr was a
# rumble under what a phone plays.
KITTEN = ("close-mic recording of a real small kitten in a quiet warm room, "
          "natural, soft, warm, gentle, cute, dry, no synth, no music, no "
          "human voice")

# cue: (prompt, seconds, peak level in dBFS -- quieter for the chatty ones
#       [, style in place of STYLE [, "loop": a seamless loop, no trim or fade
#                                     | "fall": the take, then itself 3 semitones lower
#                                     | "warm:<Hz>": rolled off above <Hz> and eased in
#                                       over 4 ms, for a take that came back scratchy
#                                     | "cut:<s>": only the take's first <s> seconds, for a
#                                       tick the API keeps doubling (Marigold's wall, pop)
#                                     | "body:<Hz>": rolled off below <Hz>, so a low soft
#                                       take is levelled by what a phone plays, not by
#                                       its rumble
#                                     | "steep": `warm`'s roll-off four poles steeper, for
#                                       air and leaves, which are hiss all the way up
#                                     | "tight": the lead-in trimmed at -36 dB, not -60, for
#                                       a tap that must land on its frame (Peapod's hit came
#                                       back 60 ms behind a breath of room noise)
#                                     | "notes:<gap>:<semitones>,...": a phrase built from
#                                       the take, which is one note however it is asked:
#                                       the note played once a step, that many semitones
#                                       up or down, <gap> seconds apart (COZY_TUNE)]])
SETS = {
    # The interface, not a board: every button's click (ui/ui_sound.gd).
    "ui": {
        "click":    ("a single tiny soft paper and wood click, pressing a small cozy button, very short and light", 0.5, -12),
        # The user, 2026-10-09, twice: the linen brush "too harsh", then the
        # card slid over felt that replaced it "a harsh scratch". A page turn
        # is a breath of breeze now (BREEZE), rolled off steeply above 1.1 kHz and
        # eased in over 60 ms: nothing in it is rubbed against anything.
        "page":     ("a soft gust of warm breeze through a few leaves, one gentle whoosh of air that rises and fades, short", 0.6, -16, BREEZE, "warm:1100", "steep", "ease:0.06", "body:320"),
        # The opening (world/boot.gd, 2026-10-09): heard on every launch, so
        # it is the quietest tune there is, low and eased in.
        "opening":  ("a few small wooden tiles set down gently one after another on a wooden table, then two slow soft rising notes on a low kalimba, a quiet good morning, short", 1.7, -13, HEARTH_TUNE, "warm:5000", "ease:0.02"),
    },
    "binairo": {
        # Redone 2026-10-09 against the cozy rules (docs/agents/sound.md): what
        # is a thing is a HUSH tick, what travels is BREEZE, what is a moment
        # is COZY_TUNE's muffled kalimba, its phrases written with `notes`
        # from the one note a take holds. Six takes of the first set already
        # measured low and were kept: blush_in, check, heart_back, heart_lost
        # as they were (blush_in 4 dB down), enter levelled down and rolled
        # off, check_ok levelled down and given the second note its prompt
        # always asked for.
        "place":    ("one small wooden tile set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -13, HUSH, "warm:1600", "cut:0.16", "body:320"),
        "clear":    ("one small light wooden tile set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -16, HUSH, "warm:1500", "cut:0.12", "body:320"),
        # The lift's take over again: four prompts for a pencil's own tick came
        # back scratched (a fifth to a quarter of each above 3 kHz).
        "brush":    ("one small light wooden tile set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -17, HUSH, "warm:1500", "cut:0.1", "body:320", "notes:0:2"),
        "undo":     ("two soft dull hollow wooden tocks close together, the second a little lower, very short", 0.5, -15, HUSH, "warm:1400", "cut:0.24", "body:320", "tight"),
        "hint":     ("three slow soft notes rising on a kalimba, a gentle little idea, short", 1.0, -10, COZY_TUNE, "warm:2000", "steep", "ease:0.012", "body:300", "notes:0.15:3,7,10", "cut:0.8"),
        # check and blush_in re-prompted 2026-09-29 (insane polish): the low
        # marimba boops and the wooden "bonk" read as a scold, not a shrug.
        "check":    ("a gentle two-note melody on a soft kalimba: one note, then a second lower note, 'uh-oh' but kind, a cozy 'not quite yet', warm and round, never a buzzer", 1.0, -17, STYLE, "fall"),
        "check_ok": ("two soft bright marimba notes going up, a friendly 'all good' confirmation", 0.7, -10, STYLE, "body:300", "notes:0.13:2,6"),
        "reset":    ("a soft gust of warm breeze through a few leaves, one gentle whoosh of air that rises and fades, short", 0.8, -16, BREEZE, "warm:1100", "steep", "ease:0.06", "body:320"),
        "solved":   ("five slow soft notes rising on a kalimba over one gentle tongue drum note, a warm quiet little celebration that fades", 2.0, -8, COZY_TUNE, "warm:2600", "ease:0.012", "body:300", "notes:0.14:0,2,4,7,9", "cut:1.7"),
        "line":     ("two soft notes rising on a kalimba, short", 0.6, -12, COZY_TUNE, "warm:2600", "ease:0.01", "body:300", "notes:0.12:5,9"),
        "blush_in": ("a tiny soft felt mallet tap on a small wooden block with a gentle little pitch dip, a shy muffled 'oops', very short and quiet", 0.5, -14, STYLE, "body:300"),
        "enter":    ("a soft airy cascade of tiny wooden pops rolling in, a board of tiles appearing", 1.0, -13, STYLE, "body:300", "warm:2400"),
        # Hearts, streaks and rewards (2026-09-29 insane polish, spec section 3).
        "heart_lost":    ("a soft felt-mallet marimba two-note fall, a small gentle 'oh', warm and muffled, never a buzzer", 0.6, -15),
        "out_of_hearts": ("three slow soft notes going down on a kalimba, like a sleepy yawn, calm and kind, maybe tomorrow", 1.5, -13, COZY_TUNE, "warm:2600", "ease:0.02", "body:300", "notes:0.3:9,5,2"),
        "heart_back":    ("a warm rising pair of soft kalimba plucks, a little heart coming back, gentle and happy", 0.6, -15),
        # Every scored tile from the second of a streak, on top of `place`: a
        # tick the board pitches, not a note (what repeats is a click).
        "combo":         ("a single soft hollow wooden tock, a small woodblock tapped with felt, round, very short", 0.5, -15, HUSH, "warm:1600", "cut:0.14", "body:320"),
        "confetti":      ("a small soft puff of warm air through a few leaves, light, rising and fading, short", 0.8, -17, BREEZE, "warm:1200", "steep", "ease:0.04", "body:320"),
        "line_silly":    ("three soft hollow wooden ticks one after another, speeding up, an old mouse wheel turned", 0.7, -15, HUSH, "warm:1500", "body:320"),
        "flawless":      ("two slow soft notes rising on a kalimba and left to fade, a gentle proud 'perfect'", 1.5, -9, COZY_TUNE, "warm:2600", "ease:0.012", "body:300", "notes:0.32:0,7"),
        "liar":          ("four soft tongue drum notes tiptoeing, sneaky and playful, the last one a little higher, light", 1.0, -11, COZY_TUNE, "warm:2600", "ease:0.01", "body:300", "notes:0.16:6,7,6,10"),
        "party":         ("a slow rising run of soft kalimba notes ending on two gentle tongue drum notes, a warm cozy little party, fading", 2.0, -8, COZY_TUNE, "warm:2600", "ease:0.012", "body:300", "notes:0.14:-7,-3,0,-3,0,5", "cut:1.9"),
    },
    # Code Break (puzzle_id "mastermind"): little round friends fly into
    # seats, a Check drops score pips into a pouch, lids lift on the answer.
    "mastermind": {
        # Redone 2026-10-10 against the cozy rules (docs/agents/sound.md), the
        # second set of the redo: what is a thing is a HUSH tick, what travels
        # is BREEZE, what is a moment is COZY_TUNE's muffled kalimba, its
        # phrase written with `notes` from the one note a take holds. Five
        # takes of the first set already measured low and were kept as they
        # were (check, cool, locked, row_back) or levelled down (warmer), and
        # enter is levelled down and rolled off as Binairo's was.
        # Every tick is `tight`: a take's tock sits up to 0.18 s into its room
        # noise, which a `cut` then ends before the sound (the first full, undo
        # and score were one late tock or none).
        "place":    ("one small round wooden piece set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -13, HUSH, "warm:1600", "cut:0.16", "body:320", "tight"),
        "clear":    ("one small light wooden piece set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -16, HUSH, "warm:1500", "cut:0.12", "body:320", "tight"),
        # A full row's "hmm": the same pat twice, the second a step lower.
        "full":     ("one soft pat on a small felt cushion over wood, a single dull hollow tock, round, very short", 0.5, -15, HUSH, "warm:1400", "cut:0.26", "body:320", "notes:0.1:0,-2", "tight"),
        "locked":   ("a tiny soft kalimba note with a gentle little wobble, a kind 'this one stays', muffled and warm, very short", 0.5, -12),
        "undo":     ("one small wooden piece set down gently on thick felt, a single soft dull tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1400", "cut:0.28", "body:320", "notes:0.11:0,-3", "tight"),
        "hint":     ("one soft note on a kalimba, a gentle little idea, short", 1.0, -10, COZY_TUNE, "warm:2000", "steep", "ease:0.012", "body:300", "notes:0.2:4,9,9", "cut:0.9"),
        "check":    ("a gentle two-note melody on a soft kalimba: one note, then a second lower note, 'uh-oh' but kind, a cozy 'not quite yet', warm and round, never a buzzer", 1.0, -17, STYLE, "fall"),
        # A row that scored nothing: one dull tock, lower than a pip.
        "score":    ("one small wooden block set down gently on thick felt, a single soft dull tock, round and hollow, very short", 0.6, -15, HUSH, "warm:1300", "cut:0.2", "body:320", "tight"),
        # The lids lift on the answer: a tock and the same a little higher.
        "reveal":   ("a small wooden box lid set down gently on thick felt, a single soft tock, round and hollow, very short", 0.6, -13, HUSH, "warm:1600", "cut:0.34", "body:320", "notes:0.13:0,3", "tight"),
        "reset":    ("a soft gust of warm breeze through a few leaves, one gentle whoosh of air that rises and fades, short", 0.8, -16, BREEZE, "warm:1100", "steep", "ease:0.06", "body:320"),
        "solved":   ("one soft note on a kalimba over a gentle tongue drum, warm, left to fade", 2.0, -8, COZY_TUNE, "warm:2600", "ease:0.012", "body:300", "notes:0.14:4,6,8,11,13", "cut:1.7"),
        "enter":    ("a soft airy cascade of tiny wooden pops rolling in, a board of seats appearing", 1.0, -13, STYLE, "body:300", "warm:2400"),
        # note: layered under place and pitched a semitone a seat, so a
        # filling row climbs a little. pip: one per score pip, a semitone up
        # each as it lands. Both are ticks the board pitches, not notes (what
        # repeats is a click), and neither climbs past five semitones.
        "note":        ("one small round wooden piece set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1600", "cut:0.14", "body:320", "tight"),
        "pip":         ("one small wooden bead set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -16, HUSH, "warm:1600", "cut:0.09", "body:320", "tight"),
        "warmer":      ("a warm rising three-note soft kalimba phrase, a happy little 'getting warmer', gentle", 0.8, -10, STYLE, "body:300"),
        "so_close":    ("one soft note on a kalimba, warm and happy, short", 1.0, -9, COZY_TUNE, "warm:2600", "ease:0.01", "body:300", "notes:0.11:2,6,4,9"),
        "all_here":    ("one soft note on a wooden tongue drum, round and playful, short", 1.2, -10, COZY_TUNE, "warm:2400", "ease:0.01", "body:300", "notes:0.13:5,5,10,5,10", "cut:1.1"),
        "cool":        ("a laid-back soft kalimba slide down and back up, a cool little 'nice', with a tiny soft wooden click like sunglasses going on, relaxed and cute", 0.9, -8),
        # The cup game: three tocks, the middle one a step up. Nothing slid.
        "shuffle":     ("one small wooden cup set down gently on thick felt, a single soft hollow tock, round, very short", 0.6, -14, HUSH, "warm:1500", "cut:0.42", "body:320", "notes:0.12:0,2,0", "tight"),
        "peek":        ("one small light wooden lid set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.6, -17, HUSH, "warm:1500", "cut:0.12", "body:320", "tight"),
        "stamp":       ("one soft note on a kalimba, proud and warm, left to fade", 1.5, -9, COZY_TUNE, "warm:2600", "ease:0.012", "body:300", "notes:0.26:4,0,7"),
        "party":       ("one soft note on a kalimba over a gentle tongue drum, warm and cozy, left to fade", 2.0, -8, COZY_TUNE, "warm:2600", "ease:0.012", "body:300", "notes:0.14:4,8,11,8,11,13", "cut:1.9"),
        "confetti":    ("a small soft puff of warm air through a few leaves, light, rising and fading, short", 0.8, -17, BREEZE, "warm:1200", "steep", "ease:0.04", "body:320"),
        "out_of_rows": ("one slow soft note on a kalimba, sleepy, calm and kind, left to fade", 1.5, -13, COZY_TUNE, "warm:2600", "ease:0.02", "body:300", "notes:0.32:11,8,4"),
        "row_back":    ("a warm rising pair of soft kalimba plucks, a little extra chance, gentle and happy", 0.6, -12),
    },
    # Balance: a seesaw of fruit with secret weights (the scales it began as
    # are gone); a fruit settling in a cup, a beam that comes level chimes.
    "balance": {
        # Redone 2026-10-10 against the cozy rules (docs/agents/sound.md), the
        # third set of the redo: what is a thing is a HUSH tick, what travels
        # is BREEZE, what is a moment is COZY_TUNE's muffled kalimba, its
        # phrase written with `notes` from the one note a take holds. Four
        # takes of the first set already measured low and were kept: refused,
        # hour_back and sun_low as they were, level levelled down;
        # enter is levelled down and rolled off. Every tick is `tight` (Code
        # Break's lesson: a tock sits behind its room noise and a `cut` ends
        # before it).
        "step":     ("one small round wooden ball set down gently in a little wooden cup lined with felt, a single soft tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1500", "cut:0.14", "body:320", "tight"),
        "level":    ("a soft bright two-note kalimba chime going up, a hanging scale settling perfectly level", 0.7, -9, STYLE, "body:300"),
        "refused":  ("a tiny soft felt pat with a gentle little kalimba wobble, a kind 'this one stays put', muffled and warm, very short", 0.5, -12),
        "undo":     ("one small wooden ball set down gently on thick felt, a single soft dull tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1400", "cut:0.28", "body:320", "tight", "notes:0.11:0,-3"),
        "hint":     ("one soft note on a kalimba, a gentle little idea, short", 1.0, -10, COZY_TUNE, "warm:2000", "steep", "ease:0.012", "body:300", "notes:0.16:4,11,8", "cut:0.9"),
        "reset":    ("a soft gust of warm breeze through a few leaves, one gentle whoosh of air that rises and fades, short", 0.8, -16, BREEZE, "warm:1100", "steep", "ease:0.06", "body:320"),
        "solved":   ("one soft note on a kalimba over a gentle tongue drum, warm, left to fade", 2.0, -8, COZY_TUNE, "warm:2600", "ease:0.012", "body:300", "notes:0.14:4,6,8,11,13", "cut:1.7"),
        "enter":    ("a wooden seesaw creaking once as it tips, then a small fruit landing on a plank with a soft thump", 1.0, -13, FOLEY, "body:300", "warm:2000"),
        # The seesaw: a fruit picked up (a lift is a lighter thing set down),
        # a fruit landing on the plank (pitched by its weight in the board),
        # the plank's end coming down on a hay bale, and the tock of the beam
        # coming to rest.
        "lift":     ("one small light wooden ball set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -17, HUSH, "warm:1500", "cut:0.1", "body:320", "tight"),
        "land":     ("one small round wooden ball set down gently on a wooden plank covered in felt, a single soft tock, round and hollow, very short", 0.5, -13, HUSH, "warm:1600", "cut:0.18", "body:320", "tight"),
        "thud":     ("the end of a wooden plank set down gently on a thick wool cushion, a single soft dull tock, round and hollow, very short", 0.6, -14, HUSH, "warm:1200", "cut:0.24", "body:320", "tight"),
        "tock":     ("one small wooden block set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -16, HUSH, "warm:1600", "cut:0.12", "body:320", "tight"),
        # Insane's springy bales: two tocks, the second a third up. No
        # cartoon spring and no whistle.
        "boing":     ("one small wooden block set down gently on a thick wool cushion, a single soft hollow tock, round, very short", 0.6, -13, HUSH, "warm:1500", "cut:0.3", "body:320", "tight", "notes:0.1:0,4"),
        "sunset":    ("one slow soft note on a kalimba, sleepy, calm and kind, left to fade", 1.6, -13, COZY_TUNE, "warm:2600", "ease:0.02", "body:300", "notes:0.32:9,6,2"),
        "hour_back": ("a warm rising pair of soft kalimba plucks with a tiny glockenspiel sparkle, the sun peeking back up, gentle and happy", 0.8, -10),
        "sun_low":   ("a single soft low warm kalimba note, gentle, a quiet 'the day is getting late', very short", 0.5, -14),
        # A good throw, pitched up a little by the run: one note, no whoosh.
        "toss":      ("one soft short note on a kalimba, warm and happy", 0.7, -12, COZY_TUNE, "warm:2400", "ease:0.008", "body:300", "notes:0:5", "cut:0.5"),
        # The sun tickled: a wheel's four notches, up and down. It can be
        # tapped over and over, so it is ticks and no trill.
        "giggle":    ("one small light wooden bead set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.6, -16, HUSH, "warm:1600", "cut:0.34", "body:320", "tight", "notes:0.07:0,3,1,4"),
        "reveal":    ("a small wooden box lid set down gently on thick felt, a single soft tock, round and hollow, very short", 0.6, -13, HUSH, "warm:1600", "cut:0.34", "body:320", "tight", "notes:0.13:0,3"),
        "stamp":     ("one soft note on a kalimba, proud and warm, left to fade", 1.5, -9, COZY_TUNE, "warm:2600", "ease:0.012", "body:300", "notes:0.26:8,4,11"),
        "party":     ("one soft note on a kalimba over a gentle tongue drum, warm and cozy, left to fade", 2.0, -8, COZY_TUNE, "warm:2600", "ease:0.012", "body:300", "notes:0.14:-1,3,6,3,6,8", "cut:1.9"),
        "confetti":  ("a small soft puff of warm air through a few leaves, light, rising and fading, short", 0.8, -17, BREEZE, "warm:1200", "steep", "ease:0.04", "body:320"),
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
        # Redone 2026-10-10 against the cozy rules (docs/agents/sound.md), the
        # fourth set of the redo: what is a thing is a HUSH tick, what travels
        # is BREEZE, what is a moment is COZY_TUNE's muffled kalimba, its
        # phrase written with `notes` from the one note a take holds. Takes of
        # the first set that already measured low are kept: free, oops,
        # thread_low, enter and pounce as they were, combo and stamp levelled
        # down, untie and spool_back rolled off. Nothing here is rope any
        # more: a creak, a rustle and a zip all came back as scratch, so a
        # rope pulled tight is a dull tock and a wrap spinning free a wheel's
        # three notches. Every tick is `tight`.
        # The drop's take two steps up: two prompts for a lighter peg came back
        # scratched (three quarters and more of each above 3 kHz).
        "pick":     ("one small round wooden peg set down gently in a wooden hole lined with felt, a single soft tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1500", "cut:0.1", "body:320", "tight", "notes:0:2"),
        "drop":     ("one small round wooden peg set down gently in a wooden hole lined with felt, a single soft tock, round and hollow, very short", 0.5, -13, HUSH, "warm:1600", "cut:0.18", "body:320", "tight"),
        "put":      ("one small wooden bead set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -13, HUSH, "warm:1600", "cut:0.09", "body:320", "tight", "notes:0:4"),
        # "Not that far": two notes, the second lower.
        "refused":  ("one soft short note on a kalimba, muffled and kind", 0.6, -13, COZY_TUNE, "warm:2400", "ease:0.01", "body:300", "notes:0.12:6,3", "cut:0.5"),
        "taut":     ("one small wooden block set down gently on thick felt, a single soft dull tock, round and hollow, very short", 0.6, -14, HUSH, "warm:1300", "cut:0.12", "body:320", "tight"),
        # The knots: a wrap drawn tighter, a wrap spinning free, a rope left
        # with nothing crossing it.
        "cinch":    ("one soft pat on a small felt cushion over wood, a single dull hollow tock, round, very short", 0.5, -13, HUSH, "warm:1400", "cut:0.14", "body:320", "tight"),
        # unwind is the drop's take, three notches rising: a spool's own came
        # back twice with its tock 80 ms behind a first faint one.
        "unwind":   ("one small round wooden peg set down gently in a wooden hole lined with felt, a single soft tock, round and hollow, very short", 0.5, -13, HUSH, "warm:1600", "cut:0.36", "body:320", "tight", "notes:0.08:0,2,4"),
        "free":     ("a soft springy cotton rope boing with a tiny happy two-note kalimba lift, cute and cozy, very short", 0.6, -9, STYLE, "warm:6000"),
        "untie":    ("a tiny bright kalimba pluck going up with a soft rope loosening rustle, a knot coming undone, very short", 0.6, -10, STYLE, "warm:2400", "body:300"),
        "combo":    ("two or three soft rising kalimba and glockenspiel notes, a cheerful cozy little fanfare", 0.9, -10),
        "oops":     ("two soft wobbly descending marimba notes with a tiny cartoon slide, a gentle comic oops, not harsh", 0.7, -10),
        "undo":     ("one small wooden peg set down gently on thick felt, a single soft dull tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1400", "cut:0.28", "body:320", "tight", "notes:0.11:0,-3"),
        "hint":     ("one soft note on a kalimba, a gentle little idea, short", 1.0, -10, COZY_TUNE, "warm:2000", "steep", "ease:0.012", "body:300", "notes:0.17:0,5,9", "cut:0.9"),
        "reset":    ("a soft gust of warm breeze through a few leaves, one gentle whoosh of air that rises and fades, short", 0.8, -16, BREEZE, "warm:1100", "steep", "ease:0.06", "body:320"),
        "solved":   ("one soft note on a kalimba over a gentle tongue drum, warm, left to fade", 2.0, -8, COZY_TUNE, "warm:2600", "ease:0.012", "body:300", "notes:0.14:0,4,7,9,12", "cut:1.7"),
        "enter":    ("four or five soft low wooden marimba ticks one after another, like small round pegs settling into a wooden ring, warm and gentle, no hiss", 1.0, -9, STYLE, "warm:5000"),
        # Thread (Hard and Insane): a stitch is the lightest tick there is.
        "stitch":      ("one small wooden bead set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -13, HUSH, "warm:1600", "cut:0.08", "body:320", "tight", "notes:0:5"),
        "thread_low":  ("a single soft low warm kalimba note, gentle, a quiet 'the thread is getting short', very short", 0.5, -12),
        "thread_out":  ("one slow soft note on a kalimba, sleepy, calm and kind, left to fade", 1.6, -13, COZY_TUNE, "warm:2600", "ease:0.02", "body:300", "notes:0.32:7,4,0"),
        "spool_back":  ("a warm rising pair of soft kalimba plucks with a tiny sparkle and a light wooden spool spinning, gentle and happy", 0.9, -10, STYLE, "warm:2400", "body:300"),
        "reveal":      ("a small wooden box lid set down gently on thick felt, a single soft tock, round and hollow, very short", 0.6, -13, HUSH, "warm:1600", "cut:0.34", "body:320", "tight", "notes:0.13:0,3"),
        # The seal and the party.
        "stamp":    ("a very quiet soft paper stamp tap followed by a loud clear warm glockenspiel chime, two bright rising notes ringing out and fading slowly, proud", 1.5, -9),
        "party":    ("one soft note on a kalimba over a gentle tongue drum, warm and cozy, left to fade", 2.0, -8, COZY_TUNE, "warm:2600", "ease:0.012", "body:300", "notes:0.14:0,4,7,4,7,12", "cut:1.9"),
        "confetti": ("a small soft puff of warm air through a few leaves, light, rising and fading, short", 0.8, -17, BREEZE, "warm:1200", "steep", "ease:0.04", "body:320"),
        # Insane's kitten. The purr was 89% under 300 Hz, which a phone does
        # not play: it is a chirrup now, a real kitten's and no cartoon's.
        "pounce":   ("a tiny playful kitten mrrp and a soft paw swat, cute and cozy, very short", 0.8, -8, CARTOON),
        "purr":     ("one short soft contented chirrup, a little rolling trill with the mouth closed, gentle and happy", 1.0, -12, KITTEN, "warm:2400", "ease:0.01", "body:300"),
    },
    # Shikaku: garden beds drawn as rectangles in soil around number stakes.
    "shikaku": {
        # Redone 2026-10-10 against the cozy rules (docs/agents/sound.md), the
        # fifth set of the redo, as Untangle's above. Kept from the first set:
        # locked, worm, cool, heart_back and out_of_hearts as they were, plot
        # levelled down, heart_lost with its rumble taken off, check_ok as
        # Binairo's is; check is Code Break's take of the same prompt (this
        # board's own came back under 300 Hz). select and combo are ticks the board
        # pitches, and neither climbs past five semitones. Every tick is
        # `tight`.
        "select":   ("one small light wooden stake set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1600", "cut:0.1", "body:320", "tight"),
        "plot":     ("a soft short garden trowel pat in loose soil with a tiny wooden tap, a garden bed marked out", 0.5, -13),
        "hint":     ("one soft note on a kalimba, a gentle little idea, short", 1.0, -10, COZY_TUNE, "warm:2000", "steep", "ease:0.012", "body:300", "notes:0.15:2,5,10", "cut:0.9"),
        "check_ok": ("two soft bright marimba notes going up, a friendly 'all good' confirmation", 0.7, -10, STYLE, "body:300", "warm:2600", "notes:0.13:2,6"),
        "reset":    ("a soft gust of warm breeze through a few leaves, one gentle whoosh of air that rises and fades, short", 0.8, -16, BREEZE, "warm:1100", "steep", "ease:0.06", "body:320"),
        "solved":   ("one soft note on a kalimba over a gentle tongue drum, warm, left to fade", 2.0, -8, COZY_TUNE, "warm:2600", "ease:0.012", "body:300", "notes:0.14:0,2,5,7,10", "cut:1.7"),
        # The stakes going in: select's take, five in a row. The cascade of
        # pops it was sat between 1 and 3 kHz whatever was rolled off.
        "enter":    ("one small light wooden stake set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -14, HUSH, "warm:1600", "cut:0.5", "body:320", "tight", "notes:0.08:0,2,0,3,5"),
        # A bed taken up: a lift is a lighter thing set down.
        "clear":    ("one small light wooden block set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -16, HUSH, "warm:1500", "cut:0.12", "body:320", "tight"),
        "locked":   ("a tiny soft kalimba note with a gentle little wobble, a kind 'this one stays', muffled and warm, very short", 0.5, -12),
        "undo":     ("one small wooden block set down gently on thick felt, a single soft dull tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1400", "cut:0.28", "body:320", "tight", "notes:0.11:0,-3"),
        "check":    ("a gentle two-note melody on a soft kalimba: one note, then a second lower note, 'uh-oh' but kind, a cozy 'not quite yet', warm and round, never a buzzer", 1.0, -17, STYLE, "fall"),
        # The polish pass (2026-09-30, docs/superpowers/specs/2026-09-30-shikaku-polish-design.md).
        # sprout: a light tick after the bed's own. combo: layered over plot,
        # a tick the board pitches by the streak.
        "sprout":   ("one small wooden bead set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -16, HUSH, "warm:1600", "cut:0.09", "body:320", "tight", "notes:0:3"),
        "combo":    ("one small wooden block set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -14, HUSH, "warm:1600", "cut:0.14", "body:320", "tight"),
        "confetti": ("a small soft puff of warm air through a few leaves, light, rising and fading, short", 0.8, -17, BREEZE, "warm:1200", "steep", "ease:0.04", "body:320"),
        "worm":     ("a tiny cute soft squeaky 'bloop' of a little worm popping out of soft soil, then a small playful wooden kalimba trill, silly and sweet", 0.9, -9),
        "cool":     ("a laid-back soft kalimba slide down and back up, a cool little 'nice', with a tiny soft wooden click like sunglasses going on, relaxed and cute", 0.9, -8),
        # The sign spun round once: a wheel's four notches, up and back, on
        # sprout's take (its own began 150 ms late).
        "twirl":    ("one small wooden bead set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.6, -15, HUSH, "warm:1600", "cut:0.34", "body:320", "tight", "notes:0.07:0,2,4,2"),
        "heart_lost":    ("a soft felt-mallet marimba two-note fall, a small gentle 'oh', warm and muffled, never a buzzer", 0.6, -15, STYLE, "body:300"),
        "out_of_hearts": ("a sleepy three-note music box lullaby slowly descending, like a soft yawn, calm and kind, maybe tomorrow", 1.5, -14),
        "heart_back":    ("a warm rising pair of soft kalimba plucks, a little heart coming back, gentle and happy", 0.6, -15),
        "stamp":    ("one soft note on a kalimba, proud and warm, left to fade", 1.5, -9, COZY_TUNE, "warm:2600", "ease:0.012", "body:300", "notes:0.26:5,0,9"),
        "party":    ("one soft note on a kalimba over a gentle tongue drum, warm and cozy, left to fade", 2.0, -8, COZY_TUNE, "warm:2600", "ease:0.012", "body:300", "notes:0.14:-2,2,5,2,5,10", "cut:1.9"),
    },
    # Tents: pitch a tent beside each tree on a grassy campsite grid.
    "tents": {
        # Redone 2026-10-10 against the cozy rules (docs/agents/sound.md), the
        # sixth set of the redo, as Shikaku's above. Kept from the first set:
        # locked and cool as they were, check_ok levelled down, heart_lost
        # with its rumble taken off, heart_back rolled off; check is Code
        # Break's take of the same prompt (this board's own came back under
        # 300 Hz). Nothing here is canvas any more: a whump was a thump at
        # 18 Hz, a fold, a zip and a rustle are the scratch. cairn, clear and
        # combo are ticks the board pitches, none past five semitones. Every
        # tick is `tight`.
        "hint":     ("one soft note on a kalimba, a gentle little idea, short", 1.0, -10, COZY_TUNE, "warm:2000", "steep", "ease:0.012", "body:300", "notes:0.16:0,4,7", "cut:0.9"),
        "check_ok": ("two soft bright marimba notes going up, a friendly 'all good' confirmation", 0.7, -10, STYLE, "body:300", "warm:2600"),
        "reset":    ("a soft gust of warm breeze through a few leaves, one gentle whoosh of air that rises and fades, short", 0.8, -16, BREEZE, "warm:1100", "steep", "ease:0.06", "body:320"),
        "solved":   ("one soft note on a kalimba over a gentle tongue drum, warm, left to fade", 2.0, -8, COZY_TUNE, "warm:2600", "ease:0.012", "body:300", "notes:0.14:0,2,4,7,9", "cut:1.7"),
        # The trees standing up: place's take, five in a row. The cascade of
        # pops and leaves it was had four fifths of itself above 3 kHz.
        "enter":    ("one small wooden tent peg set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -14, HUSH, "warm:1600", "cut:0.5", "body:320", "tight", "notes:0.08:0,3,0,2,5"),
        "place":    ("one small wooden tent peg set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -13, HUSH, "warm:1600", "cut:0.16", "body:320", "tight"),
        # A tent folded down: a lift is a lighter thing set down.
        "strike":   ("one small light wooden block set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1500", "cut:0.12", "body:320", "tight"),
        "locked":   ("a tiny soft kalimba note with a gentle little wobble, a kind 'this one stays', muffled and warm, very short", 0.5, -12),
# undo is strike's take, twice and falling: its own held two tocks
        # 80 ms apart, four once the phrase was written.
        "undo":     ("one small light wooden block set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1400", "cut:0.28", "body:320", "tight", "notes:0.11:0,-3"),
        "check":    ("a gentle two-note melody on a soft kalimba: one note, then a second lower note, 'uh-oh' but kind, a cozy 'not quite yet', warm and round, never a buzzer", 1.0, -17, STYLE, "fall"),
        # cairn / clear tick per square of a sweep, pitched up as it grows.
        "cairn":    ("one small wooden bead set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1600", "cut:0.09", "body:320", "tight"),
# clear is cairn's take three steps down: a cork came back scratched or
        # under 300 Hz three times in three.
        "clear":    ("one small wooden bead set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -16, HUSH, "warm:1500", "cut:0.1", "body:320", "tight", "notes:0:-3"),
        # combo: layered over place, a tick the board pitches by the streak.
        "combo":    ("one small wooden block set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -14, HUSH, "warm:1600", "cut:0.14", "body:320", "tight"),
        "confetti": ("a small soft puff of warm air through a few leaves, light, rising and fading, short", 0.8, -17, BREEZE, "warm:1200", "steep", "ease:0.04", "body:320"),
        # The gags. peek: a camper's wave, up and back. bunny: three hops,
        # ticks on a cushion. oak: the tree's own leaves in a breath of air.
        "peek":     ("one soft short note on a kalimba, muffled and kind", 0.6, -12, COZY_TUNE, "warm:2400", "ease:0.01", "body:300", "notes:0.1:4,7,4", "cut:0.6"),
        "cool":     ("a laid-back soft kalimba slide down and back up, a cool little 'nice', with a tiny soft wooden click like sunglasses going on, relaxed and cute", 0.9, -8),
        "bunny":    ("one soft pat on a small felt cushion over wood, a single dull hollow tock, round, very short", 0.5, -14, HUSH, "warm:1400", "cut:0.5", "body:320", "tight", "notes:0.15:0,4,2"),
        "oak":      ("a soft warm breeze through the leaves of one big old tree, a gentle slow breath of air that rises and fades, short", 0.9, -16, BREEZE, "warm:1100", "steep", "ease:0.08", "body:320"),
        "heart_lost":    ("a soft felt-mallet marimba two-note fall, a small gentle 'oh', warm and muffled, like a tent sagging, never a buzzer", 0.6, -15, STYLE, "body:300", "notes:0:4"),
        "out_of_hearts": ("one slow soft note on a kalimba, sleepy, calm and kind, left to fade", 1.6, -13, COZY_TUNE, "warm:2600", "ease:0.02", "body:300", "notes:0.32:7,4,0"),
        "heart_back":    ("a warm rising pair of soft kalimba plucks, a little heart coming back, gentle and happy", 0.6, -15, STYLE, "warm:2400", "body:300"),
        "stamp":    ("one soft note on a kalimba, proud and warm, left to fade", 1.5, -9, COZY_TUNE, "warm:2600", "ease:0.012", "body:300", "notes:0.26:5,0,9"),
        "party":    ("one soft note on a kalimba over a gentle tongue drum, warm and cozy, left to fade", 2.0, -8, COZY_TUNE, "warm:2600", "ease:0.012", "body:300", "notes:0.14:0,4,7,4,7,12", "cut:1.9"),
    },
    # Light Up: paper lamps set down in a stone courtyard light their rows.
    "lightup": {
        # Redone 2026-10-10 against the cozy rules (docs/agents/sound.md), the
        # seventh set of the redo, as Tents' above. Kept from the first set:
        # check, locked, heart_lost and heart_back as they were, check_ok
        # levelled down, cool rolled off. Nothing here is paper or stone any
        # more: a lantern's rustle, a slate chip and a hand over the floor
        # all sat above 3 kHz. chip, clear and combo are ticks the board
        # pitches, none past five semitones. Every tick is `tight`.
        "hint":     ("one soft note on a kalimba, a gentle little idea, short", 1.0, -10, COZY_TUNE, "warm:2000", "steep", "ease:0.012", "body:300", "notes:0.18:0,3,7", "cut:0.9"),
        "check_ok": ("two soft bright marimba notes going up, a friendly 'all good' confirmation", 0.7, -10, STYLE, "body:300", "warm:2600"),
        "reset":    ("a soft gust of warm breeze through a few leaves, one gentle whoosh of air that rises and fades, short", 0.8, -16, BREEZE, "warm:1100", "steep", "ease:0.06", "body:320"),
        "solved":   ("one soft note on a kalimba over a gentle tongue drum, warm, left to fade", 2.0, -8, COZY_TUNE, "warm:2600", "ease:0.012", "body:300", "notes:0.14:0,3,5,7,10", "cut:1.7"),
        # The stones rolling in: place's take, five in a row.
        "enter":    ("one small wooden lantern base set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -14, HUSH, "warm:1600", "cut:0.5", "body:320", "tight", "notes:0.08:0,2,3,0,5"),
        "place":    ("one small wooden lantern base set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -13, HUSH, "warm:1600", "cut:0.16", "body:320", "tight"),
        # A lamp put out: a lift is a lighter thing set down. The board also
        # plays it 5 dB down when a wrong lamp is taken away, so it is no
        # quieter than place.
        "strike":   ("one small light wooden block set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -13, HUSH, "warm:1500", "cut:0.12", "body:320", "tight"),
        "locked":   ("a tiny soft kalimba note with a gentle little wobble, a kind 'this one stays', muffled and warm, very short", 0.5, -12),
        "undo":     ("one small light wooden block set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1400", "cut:0.28", "body:320", "tight", "notes:0.11:0,-3"),
        "check":    ("a gentle two-note melody on a soft kalimba: one note, then a second lower note, 'uh-oh' but kind, a cozy 'not quite yet', warm and round, never a buzzer", 1.0, -17, STYLE, "fall"),
        # chip / clear tick per stone of a sweep, pitched up as it grows.
        "chip":     ("one small wooden bead set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1600", "cut:0.09", "body:320", "tight"),
        "clear":    ("one small wooden bead set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -16, HUSH, "warm:1500", "cut:0.1", "body:320", "tight", "notes:0:-3"),
        # combo: layered over place, a tick the board pitches by the streak.
        "combo":    ("one small wooden block set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -14, HUSH, "warm:1600", "cut:0.14", "body:320", "tight"),
        "confetti": ("a small soft puff of warm air through a few leaves, light, rising and fading, short", 0.8, -17, BREEZE, "warm:1200", "steep", "ease:0.04", "body:320"),
        "cool":     ("a laid-back soft kalimba slide down and back up, a cool little 'nice', with a tiny soft wooden click like sunglasses going on, relaxed and cute", 0.9, -8, STYLE, "warm:2400", "body:300"),
        # The gags. puff: the lantern's smoke ring, a puff of air. snail:
        # three slow notches of a wheel. moth: two quiet notes arriving.
        "puff":     ("one small soft round puff of warm air, a gentle breath that rises and fades, very short", 0.6, -16, BREEZE, "warm:1200", "steep", "ease:0.03", "body:320"),
        "snail":    ("one soft pat on a small felt cushion over wood, a single dull hollow tock, round, very short", 0.5, -15, HUSH, "warm:1400", "cut:0.7", "body:320", "tight", "notes:0.22:0,2,0"),
        "moth":     ("one soft short note on a kalimba, muffled and kind", 0.6, -14, COZY_TUNE, "warm:2400", "ease:0.01", "body:300", "notes:0.09:5,7", "cut:0.5"),
        # The cat. Untangle's purr was 89% under 300 Hz, which a phone does
        # not play: a chirrup here too, and a real cat's short mew.
        "purr":     ("one short soft contented chirrup, a little rolling trill with the mouth closed, gentle and happy", 1.0, -12, KITTEN, "warm:2400", "ease:0.01", "body:300"),
        "wake":     ("one short soft low grumbly mew with the mouth nearly closed, sleepy and a little cross, gentle", 0.7, -12, KITTEN, "warm:2400", "ease:0.01", "body:300"),
        "heart_lost":    ("a soft felt-mallet marimba two-note fall, a small gentle 'oh', warm and muffled, like a lantern dimming, never a buzzer", 0.6, -15),
        "out_of_hearts": ("one slow soft note on a kalimba, sleepy, calm and kind, left to fade", 1.6, -13, COZY_TUNE, "warm:2600", "ease:0.02", "body:300", "notes:0.32:7,3,0"),
        "heart_back":    ("a warm rising pair of soft kalimba plucks, a little heart coming back, gentle and happy", 0.6, -15),
        "stamp":    ("one soft note on a kalimba, proud and warm, left to fade", 1.5, -9, COZY_TUNE, "warm:2600", "ease:0.012", "body:300", "notes:0.26:3,0,7"),
        "party":    ("one soft note on a kalimba over a gentle tongue drum, warm and cozy, left to fade", 2.0, -8, COZY_TUNE, "warm:2600", "ease:0.012", "body:300", "notes:0.14:0,3,7,3,7,12", "cut:1.9"),
        # The sky lanterns going up: a long slow breath of air, no shimmer.
        "lanterns": ("a long soft gust of warm breeze through a few leaves, one slow gentle whoosh of air that rises and fades", 2.0, -15, BREEZE, "warm:1100", "steep", "ease:0.15", "body:320"),
    },
    # One Line: a snail walks every line between posts exactly once.
    "oneline": {
        # Redone 2026-10-10 against the cozy rules (docs/agents/sound.md), the
        # eighth set of the redo, as Light Up's above. Kept from the first
        # set: locked, love and heart_back as they were, check_ok levelled
        # down, cool rolled off, heart_lost four steps up with its rumble
        # off; check is Code Break's take of the same prompt (this board's
        # own sat under 300 Hz). Nothing here is a plank that creaks, a drop
        # that plinks or a wing that flutters any more: all three sat above
        # 3 kHz. lay and combo are ticks the board pitches, neither past five
        # semitones. Every tick is `tight`. Three takes are borrowed, their
        # own having failed twice: start is mushroom's (the same pat), sun
        # Light Up's puff and confetti Binairo's, each of the same prompt.
        # The phrases' steps are set by each take's own note, so that every
        # note lands between 400 and 700 Hz.
        "hint":     ("one soft note on a kalimba, a gentle little idea, short", 1.0, -10, COZY_TUNE, "warm:2000", "steep", "ease:0.012", "body:300", "notes:0.17:-2,0,5", "cut:0.9"),
        "check_ok": ("two soft bright marimba notes going up, a friendly 'all good' confirmation", 0.7, -10, STYLE, "body:300", "warm:2600"),
        "solved":   ("one soft note on a kalimba over a gentle tongue drum, warm, left to fade", 2.0, -8, COZY_TUNE, "warm:2600", "ease:0.012", "body:300", "notes:0.14:4,6,9,11,13", "cut:1.7"),
        # The posts standing up: lay's take, five in a row.
        "enter":    ("one small wooden plank set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -14, HUSH, "warm:1600", "cut:0.5", "body:320", "tight", "notes:0.08:0,2,0,3,5"),
        # The snail settling on its first post.
        "start":    ("one soft pat on a small felt cushion over wood, a single dull hollow tock, round, very short", 0.5, -13, HUSH, "warm:1400", "cut:0.18", "body:320", "tight"),
        # lay plays on every step, pitched up a little with the streak
        # (1.32 at most, under five semitones).
        "lay":      ("one small wooden plank set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -14, HUSH, "warm:1600", "cut:0.16", "body:320", "tight"),
        "locked":   ("a tiny soft kalimba note with a gentle little wobble, a kind 'this one stays', muffled and warm, very short", 0.5, -12),
        # undo is slip's take, twice and falling (slip's own first take was
        # two tocks 50 ms apart; the fourth was one).
        "undo":     ("one small light wooden block set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1400", "cut:0.28", "body:320", "tight", "notes:0.11:0,-3"),
        "check":    ("a gentle two-note melody on a soft kalimba: one note, then a second lower note, 'uh-oh' but kind, a cozy 'not quite yet', warm and round, never a buzzer", 1.0, -17, STYLE, "fall"),
        "reset":    ("a soft gust of warm breeze through a few leaves, one gentle whoosh of air that rises and fades, short", 0.8, -16, BREEZE, "warm:1100", "steep", "ease:0.06", "body:320"),
        # Sunny Spells: a sunny line refused is a puff of warm air, and a
        # dewy one after the sun two quiet notes; a flower opening is one.
        "sun":      ("one small soft round puff of warm air, a gentle breath that rises and fades, very short", 0.6, -16, BREEZE, "warm:1200", "steep", "ease:0.03", "body:320"),
        "dew":      ("one soft short note on a kalimba, muffled and kind", 0.6, -14, COZY_TUNE, "warm:2400", "ease:0.01", "body:300", "notes:0.09:5,7", "cut:0.5"),
        "bloom":    ("one soft short note on a kalimba, muffled and kind", 0.6, -15, COZY_TUNE, "warm:2400", "ease:0.01", "body:300", "notes:0:9", "cut:0.45"),
        # The streak, the gags and the ladybugs. combo: layered over lay, a
        # tick the board pitches by the streak. mushroom: two tocks a third
        # apart. ladybug: three quiet notes, up and back.
        "combo":    ("one small wooden block set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -14, HUSH, "warm:1600", "cut:0.14", "body:320", "tight"),
        "confetti": ("a small soft puff of warm air through a few leaves, light, rising and fading, short", 0.8, -17, BREEZE, "warm:1200", "steep", "ease:0.04", "body:320"),
        "cool":     ("a laid-back soft kalimba slide down and back up, a cool little 'nice', with a tiny soft wooden click like sunglasses going on, relaxed and cute", 0.9, -8, STYLE, "warm:2400", "body:300"),
        "love":     ("a few tiny soft bubbly pops rising with a sweet little two-note kalimba 'aww', little hearts floating up, cute and warm", 0.8, -10),
        "mushroom": ("one soft pat on a small felt cushion over wood, a single dull hollow tock, round, very short", 0.5, -14, HUSH, "warm:1400", "cut:0.4", "body:320", "tight", "notes:0.13:0,4"),
        "ladybug":  ("one soft short note on a kalimba, muffled and kind", 0.6, -13, COZY_TUNE, "warm:2400", "ease:0.01", "body:300", "notes:0.1:4,7,4", "cut:0.6"),
        # Hearts, the wrong step's plank coming back up, and the party. A
        # lift is a lighter thing set down.
        "heart_lost":    ("a soft felt-mallet marimba two-note fall, a small gentle 'oh', warm and muffled, like a plank sagging, never a buzzer", 0.6, -15, STYLE, "body:300", "notes:0:4"),
        "slip":     ("one small light wooden block set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -14, HUSH, "warm:1500", "cut:0.12", "body:320", "tight"),
        "out_of_hearts": ("one slow soft note on a kalimba, sleepy, calm and kind, left to fade", 1.6, -13, COZY_TUNE, "warm:2600", "ease:0.02", "body:300", "notes:0.32:11,6,4"),
        "heart_back":    ("a warm rising pair of soft kalimba plucks, a little heart coming back, gentle and happy", 0.6, -15),
        "stamp":    ("one soft note on a kalimba, proud and warm, left to fade", 1.5, -9, COZY_TUNE, "warm:2600", "ease:0.012", "body:300", "notes:0.26:4,2,9"),
        "party":    ("one soft note on a kalimba over a gentle tongue drum, warm and cozy, left to fade", 2.0, -8, COZY_TUNE, "warm:2600", "ease:0.012", "body:300", "notes:0.14:-1,1,6,1,6,8", "cut:1.9"),
        # The petals on the wind: a long slow breath of air, no twinkle.
        "petals":   ("a long soft gust of warm breeze through a few leaves, one slow gentle whoosh of air that rises and fades", 2.0, -15, BREEZE, "warm:1100", "steep", "ease:0.15", "body:320"),
    },
    # Nonogram: mosaic tiles laid on a floor by row and column clues.
    "nonogram": {
        # Redone 2026-10-10 against the cozy rules (docs/agents/sound.md), the
        # ninth set of the redo, as One Line's above. Kept from the first
        # set: locked, check, check_ok, heart_lost, heart_back, slip and frame
        # as they were, love rolled off. Nothing here is ceramic any more: a
        # glazed tile's clack and a ripple of them sat between 1 and 3 kHz,
        # and place and undo had come out 20 and 90 ms long. combo is a tick
        # the board pitches, not past five semitones. Every tick is `tight`.
        # place plays on every stroke, so it is the plainest. Two takes are
        # borrowed, their own having failed twice: mushroom is One Line's and
        # confetti Binairo's, each of the same prompt. place, combo and undo
        # were taken again until each was one tock (the first of each held a
        # second 60 ms behind). The phrases' steps are set by each take's own
        # note, so that every note lands between 400 and 700 Hz. slip's
        # prompt still says ceramic: it is the kept take's, which measures low.
        "place":    ("one small wooden tile set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -14, HUSH, "warm:1600", "cut:0.16", "body:320", "tight"),
        "locked":   ("a tiny soft kalimba note with a gentle little wobble, a kind 'this one stays', muffled and warm, very short", 0.5, -12),
        "undo":     ("one small light wooden block set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1400", "cut:0.28", "body:320", "tight", "notes:0.11:0,-3"),
        "hint":     ("one soft note on a kalimba, a gentle little idea, short", 1.0, -10, COZY_TUNE, "warm:2000", "steep", "ease:0.012", "body:300", "notes:0.16:2,7,9", "cut:0.9"),
        "check":    ("a gentle two-note melody on a soft kalimba: one note, then a second lower note, 'uh-oh' but kind, a cozy 'not quite yet', warm and round, never a buzzer", 1.0, -17, STYLE, "fall"),
        "check_ok": ("two soft warm kalimba notes going up, a friendly cozy 'all good', gentle and round", 0.7, -10),
        "reset":    ("a soft gust of warm breeze through a few leaves, one gentle whoosh of air that rises and fades, short", 0.8, -16, BREEZE, "warm:1100", "steep", "ease:0.06", "body:320"),
        # The floor laid out: place's take, five in a row.
        "enter":    ("one small wooden tile set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -14, HUSH, "warm:1600", "cut:0.5", "body:320", "tight", "notes:0.08:0,3,2,0,5"),
        "solved":   ("one soft note on a kalimba over a gentle tongue drum, warm, left to fade", 2.0, -8, COZY_TUNE, "warm:2600", "ease:0.012", "body:300", "notes:0.14:4,6,8,11,13", "cut:1.7"),
        # The streak, the gags, the daisies and the pebbles a finished line
        # lays. combo: layered over place, a tick the board pitches by the
        # streak. mushroom: two tocks a third apart. bee: two quiet notes
        # going by. bloom: one. pebbles: a wheel's four notches.
        "combo":    ("one small wooden block set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -14, HUSH, "warm:1600", "cut:0.14", "body:320", "tight"),
        "confetti": ("a small soft puff of warm air through a few leaves, light, rising and fading, short", 0.8, -17, BREEZE, "warm:1200", "steep", "ease:0.04", "body:320"),
        "love":     ("a few tiny soft bubbly pops rising with a sweet little two-note kalimba 'aww', little hearts floating up, cute and warm", 0.8, -10, STYLE, "warm:2400", "body:300"),
        "mushroom": ("one soft pat on a small felt cushion over wood, a single dull hollow tock, round, very short", 0.5, -14, HUSH, "warm:1400", "cut:0.4", "body:320", "tight", "notes:0.13:0,4"),
        "bee":      ("one soft short note on a kalimba, muffled and kind", 0.6, -14, COZY_TUNE, "warm:2400", "ease:0.01", "body:300", "notes:0.12:7,5", "cut:0.55"),
        "bloom":    ("one soft short note on a kalimba, muffled and kind", 0.6, -15, COZY_TUNE, "warm:2400", "ease:0.01", "body:300", "notes:0:2", "cut:0.45"),
        "pebbles":  ("one small wooden bead set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1600", "cut:0.4", "body:320", "tight", "notes:0.07:0,2,0,3"),
        # Hearts, the wrong tile turned out, and the party.
        "heart_lost":    ("a soft felt-mallet marimba two-note fall, a small gentle 'oh', warm and muffled, never a buzzer", 0.6, -15),
        "slip":     ("a small ceramic tile lifted out of its socket with a soft hollow wooden pop, and a tiny pebble set down in its place, warm and quiet", 0.6, -12, COZY),
        "out_of_hearts": ("one slow soft note on a kalimba, sleepy, calm and kind, left to fade", 1.6, -13, COZY_TUNE, "warm:2600", "ease:0.02", "body:300", "notes:0.32:11,9,4"),
        "heart_back":    ("a warm rising pair of soft kalimba plucks, a little heart coming back, gentle and happy", 0.6, -15),
        "stamp":    ("one soft note on a kalimba, proud and warm, left to fade", 1.5, -9, COZY_TUNE, "warm:2600", "ease:0.012", "body:300", "notes:0.26:9,4,11"),
        "frame":    ("a small wooden picture frame set gently on a wall, a soft hollow wooden knock and a tiny warm chime, cozy and proud", 0.8, -10, COZY),
        "party":    ("one soft note on a kalimba over a gentle tongue drum, warm and cozy, left to fade", 2.0, -8, COZY_TUNE, "warm:2600", "ease:0.012", "body:300", "notes:0.14:4,9,11,9,11,13", "cut:1.9"),
        # The petals and the leaves on the wind: a long slow breath of air
        # each, no twinkle, the leaves the lower of the two.
        "petals":   ("a long soft gust of warm breeze through a few leaves, one slow gentle whoosh of air that rises and fades", 2.0, -15, BREEZE, "warm:1100", "steep", "ease:0.15", "body:320"),
        "leaves":   ("a soft warm breeze through the leaves of one big old tree, a gentle slow breath of air that rises and fades", 2.0, -16, BREEZE, "warm:1000", "steep", "ease:0.12", "body:320"),
    },
    # Queens: a little crowned bee seated on a garden court; crosses are the
    # player's own marks and the ones the queens lay.
    "queens": {
        # Redone 2026-10-10 against the cozy rules (docs/agents/sound.md), the
        # tenth set of the redo, as Nonogram's above. Nothing here is a wing
        # or a buzz any more: a flutter, a fuzzy buzz and a papery unfurl all
        # sat above 3 kHz, so the bee is heard as two quiet notes going by
        # (drone) or going off (buzz_off). place plays on every cross of a
        # sweep, pitched up a little a cross (1.24 at most, under five
        # semitones), so it is the plainest; combo is a tick the board
        # pitches, not past five semitones. Every tick is `tight`. Three
        # takes are borrowed, each of the same prompt: check is Code Break's
        # and heart_lost Nonogram's (this board's own sat under 300 Hz),
        # confetti Binairo's (its own came back scratched four times in
        # four); enter is place's. The phrases' steps are set by each take's
        # own note, so that every note lands between 400 and 700 Hz.
        "place":    ("one small wooden tile set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -14, HUSH, "warm:1600", "cut:0.16", "body:320", "tight"),
        # A lift is a lighter thing set down.
        "remove":   ("one small light wooden block set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1500", "cut:0.12", "body:320", "tight"),
        "locked":   ("a tiny soft kalimba note with a gentle little wobble, a kind 'not there', muffled and warm, very short", 0.5, -12, STYLE, "body:300", "warm:2600", "notes:0:6"),
        "undo":     ("one small light wooden block set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1400", "cut:0.28", "body:320", "tight", "notes:0.11:0,-3"),
        "hint":     ("one soft note on a kalimba, a gentle little idea, short", 1.0, -10, COZY_TUNE, "warm:2000", "steep", "ease:0.012", "body:300", "notes:0.16:4,7,9", "cut:0.9"),
        "check":    ("a gentle two-note melody on a soft kalimba: one note, then a second lower note, 'uh-oh' but kind, a cozy 'not quite yet', warm and round, never a buzzer", 1.0, -17, STYLE, "fall"),
        "check_ok": ("two soft warm kalimba notes going up, a friendly cozy 'all good', gentle and round", 0.7, -10),
        "reset":    ("a soft gust of warm breeze through a few leaves, one gentle whoosh of air that rises and fades, short", 0.8, -16, BREEZE, "warm:1100", "steep", "ease:0.06", "body:320"),
        # The court laid out: place's take, five in a row.
        "enter":    ("one small wooden tile set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -14, HUSH, "warm:1600", "cut:0.5", "body:320", "tight", "notes:0.08:0,2,3,0,5"),
        "solved":   ("one soft note on a kalimba over a gentle tongue drum, warm, left to fade", 2.0, -8, COZY_TUNE, "warm:2600", "ease:0.012", "body:300", "notes:0.14:6,8,10,11,13", "cut:1.7"),
        # The streak, the gags, and the flowers a patch opens once it has
        # its queen. combo: layered over her seat, a tick the board pitches
        # by the streak. drone: a bee going by, two quiet notes up. twirl
        # and dance are the first set's takes, rolled off. bloom: one note.
        "combo":    ("one small wooden block set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -14, HUSH, "warm:1600", "cut:0.14", "body:320", "tight"),
        "confetti": ("a small soft puff of warm air through a few leaves, light, rising and fading, short", 0.8, -17, BREEZE, "warm:1200", "steep", "ease:0.04", "body:320"),
        "love":     ("a few tiny soft bubbly pops rising with a sweet little two-note kalimba 'aww', little hearts floating up, cute and warm", 0.8, -10),
        "drone":    ("one soft short note on a kalimba, muffled and kind", 0.6, -14, COZY_TUNE, "warm:2400", "ease:0.01", "body:300", "notes:0.12:6,8", "cut:0.55"),
        "twirl":    ("a tiny playful spin, a soft airy whirl with a light wing flutter ending on a small bright kalimba 'ta-da' pluck, cute and silly, very short", 0.8, -11, STYLE, "warm:2400", "body:300"),
        "bloom":    ("one soft short note on a kalimba, muffled and kind", 0.6, -15, COZY_TUNE, "warm:2400", "ease:0.01", "body:300", "notes:0:7", "cut:0.45"),
        # Hearts, the wrong queen flying off (two quiet notes down), and the
        # party.
        "heart_lost":    ("a soft felt-mallet marimba two-note fall, a small gentle 'oh', warm and muffled, never a buzzer", 0.6, -15),
        "buzz_off": ("one soft short note on a kalimba, muffled and kind", 0.6, -14, COZY_TUNE, "warm:2400", "ease:0.01", "body:300", "notes:0.14:9,5", "cut:0.6"),
        "out_of_hearts": ("one slow soft note on a kalimba, sleepy, calm and kind, left to fade", 1.6, -13, COZY_TUNE, "warm:2600", "ease:0.02", "body:300", "notes:0.32:9,5,2"),
        "heart_back":    ("a warm rising pair of soft kalimba plucks, a little heart coming back, gentle and happy", 0.6, -15, STYLE, "warm:2400", "body:300"),
        "stamp":    ("one soft note on a kalimba, proud and warm, left to fade", 1.5, -9, COZY_TUNE, "warm:2600", "ease:0.012", "body:300", "notes:0.26:7,4,11"),
        "party":    ("one soft note on a kalimba over a gentle tongue drum, warm and cozy, left to fade", 2.0, -8, COZY_TUNE, "warm:2600", "ease:0.012", "body:300", "notes:0.14:0,3,5,3,5,7", "cut:1.9"),
        "dance":    ("a short cheerful little kalimba and soft hand-drum shuffle, four playful bouncy notes, a tiny happy dance, cozy and cute", 1.2, -10, STYLE, "warm:2400", "body:300"),
        # Insane: Morning Mist. The mist rolls in on the entrance and lifts
        # at the party: a long slow breath of air each, no chime and no
        # shimmer, the mist the lower of the two.
        "mist":     ("a soft cool morning breeze over a quiet garden, a slow gentle breath of air that rises and fades", 1.5, -16, BREEZE, "warm:1000", "steep", "ease:0.15", "body:320"),
        "mist_lift": ("a long soft gust of warm breeze through a few leaves, one slow gentle whoosh of air that rises and fades", 1.8, -15, BREEZE, "warm:1200", "steep", "ease:0.12", "body:320"),
    },
    # Hidden Word (puzzle_id "hiddenword"): type a five-letter guess on a
    # paper keyboard, Enter turns the row over a tile at a time, on a
    # parchment card in a little meadow. Insane is Snail Mail: a little snail
    # carries each row's colours and delivers them one row late (the row
    # turns over as sealed kraft-paper envelopes first).
    "hiddenword": {
        # Redone 2026-10-10 against the cozy rules (docs/agents/sound.md), the
        # eleventh set of the redo, as Queens' above. Kept from the first
        # set, as they were: refused, lost, warmer, so_close, cool, love,
        # twirl, dance, ready, droop and row_back; all_here with its rumble
        # off. Nothing here is paper any more: a key, a card's flick, an
        # envelope's fold and a brush all sat above 3 kHz. type fires on
        # every key, so it is the plainest and the shortest; flip plays five
        # times a row, 4% higher a tile; combo is a tick the board pitches a
        # semitone a green letter, four at most. Every tick is `tight`.
        # Borrowed takes: confetti is Binairo's, of the same prompt; enter,
        # snail and snail_hurry are type's and post is flip's. The phrases'
        # steps are set by each take's own note, so that every note lands
        # between 400 and 700 Hz.
        "type":     ("one small wooden tile set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1600", "cut:0.1", "body:320", "tight"),
        # A letter taken back: a lighter thing set down.
        "erase":    ("one small light wooden block set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -16, HUSH, "warm:1500", "cut:0.12", "body:320", "tight"),
        "flip":     ("one small wooden block set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -14, HUSH, "warm:1600", "cut:0.14", "body:320", "tight"),
        "refused":  ("a tiny soft kalimba note with a gentle little wobble, a kind 'not quite a word', muffled and warm, very short, never a buzzer", 0.5, -12),
        "hint":     ("one soft note on a kalimba, a gentle little idea, short", 1.0, -10, COZY_TUNE, "warm:2000", "steep", "ease:0.012", "body:300", "notes:0.16:2,5,9", "cut:0.9"),
        "reset":    ("a soft gust of warm breeze through a few leaves, one gentle whoosh of air that rises and fades, short", 0.8, -16, BREEZE, "warm:1100", "steep", "ease:0.06", "body:320"),
        "solved":   ("one soft note on a kalimba over a gentle tongue drum, warm, left to fade", 2.0, -8, COZY_TUNE, "warm:2600", "ease:0.012", "body:300", "notes:0.14:6,9,11,13,14", "cut:1.7"),
        "lost":     ("a gentle warm three-note soft felt kalimba phrase slowly descending and resolving softly, a kind 'maybe tomorrow', calm, not sad, never a buzzer", 1.5, -9),
        # The card laid out: type's take, five in a row.
        "enter":    ("one small wooden tile set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -14, HUSH, "warm:1600", "cut:0.5", "body:320", "tight", "notes:0.08:0,3,0,2,5"),
        # The streak, the row's reactions and the gags. combo: a tick a green
        # letter, pitched by the board. sprout: one quiet note.
        "combo":    ("one small wooden block set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -14, HUSH, "warm:1600", "cut:0.08", "body:320", "tight"),
        "warmer":   ("a cheerful little two-note rising kalimba 'ooh!', soft and warm, getting warmer, short", 0.6, -10),
        "so_close": ("a slightly excited three-note rising melody on soft kalimba and glockenspiel, a happy 'so close!', warm and bright, short", 0.8, -8),
        "all_here": ("a playful little soft hand-drum and kalimba conga shuffle, bouncy and cute, every friend has arrived, cozy", 1.2, -10, STYLE, "body:300", "warm:2600"),
        "cool":     ("a laid-back cool little slide, a soft whistle-like kalimba glide gently down then back up, relaxed and pleased, cozy", 0.8, -10),
        "love":     ("a few tiny soft bubbly pops rising with a sweet little two-note kalimba 'aww', little hearts floating up, cute and warm", 0.8, -10),
        "twirl":    ("a tiny playful spin, a soft airy whirl ending on a small bright kalimba 'ta-da' pluck, cute and silly, very short", 0.8, -10),
        "sprout":   ("one soft short note on a kalimba, muffled and kind", 0.6, -15, COZY_TUNE, "warm:2400", "ease:0.01", "body:300", "notes:0:5", "cut:0.45"),
        "confetti": ("a small soft puff of warm air through a few leaves, light, rising and fading, short", 0.8, -17, BREEZE, "warm:1200", "steep", "ease:0.04", "body:320"),
        "party":    ("one soft note on a kalimba over a gentle tongue drum, warm and cozy, left to fade", 2.0, -8, COZY_TUNE, "warm:2600", "ease:0.012", "body:300", "notes:0.14:4,7,9,7,9,12", "cut:1.9"),
        "dance":    ("a short cheerful little kalimba and soft hand-drum shuffle, four playful bouncy notes, a tiny happy dance, cozy and cute", 1.2, -9),
        "stamp":    ("one soft note on a kalimba, proud and warm, left to fade", 1.5, -9, COZY_TUNE, "warm:2600", "ease:0.012", "body:300", "notes:0.26:4,2,9"),
        "ready":    ("a tiny soft two-note kalimba blip going up, a little 'ready', very short and quiet", 0.5, -13),
        # Out of rows: the tiles sag, three slow notes down, and a row given
        # back.
        "droop":    ("a soft slow descending felt-mallet marimba slide, sleepy and kind, little tiles sagging gently, warm and muffled, never a buzzer", 0.8, -13),
        "out_of_rows": ("one slow soft note on a kalimba, sleepy, calm and kind, left to fade", 1.6, -13, COZY_TUNE, "warm:2600", "ease:0.02", "body:300", "notes:0.32:9,5,2"),
        "row_back": ("a warm rising pair of soft kalimba plucks, one more row, gentle and happy", 0.6, -12),
        # Insane: Snail Mail. post: a row sealed, flip's take a little
        # darker (a pat on felt came back as a knock 0.2 s ahead of its
        # tock, and the cut kept the knock). The
        # snail is never a slide (a slide is the scratch): three slow
        # notches when it brings a sealed row's colours, four quick ones
        # climbing when it hurries, both type's take.
        "post":     ("one small wooden block set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -14, HUSH, "warm:1400", "cut:0.14", "body:320", "tight"),
        "snail":    ("one small wooden tile set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1400", "cut:0.7", "body:320", "tight", "notes:0.22:0,2,0"),
        "snail_hurry": ("one small wooden tile set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1400", "cut:0.45", "body:320", "tight", "notes:0.08:0,2,3,5"),
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
        # Redone 2026-10-10 against the cozy rules (docs/agents/sound.md), the
        # twelfth set of the redo, as Hidden Word's above. Kept from the
        # first set, as they were: big, streak, love, twirl, droop, wish_back,
        # lost and dawn; conga and miss with their rumble off, dance and
        # reveal rolled off. Nothing here is paper, a ribbon or a
        # glockenspiel any more. select fires on every tile a finger takes,
        # pitched up a little a tile (1.33 at most, five semitones), so it is
        # the plainest and the shortest; combo is a tick the board pitches a
        # semitone a word, five at most, and cut at 0.055 s (two takes each
        # held a second tock 60 ms behind). Every tick is `tight`. Borrowed
        # takes: confetti is Binairo's, of the same prompt; enter is
        # select's. The phrases' steps are set by each take's own note, so
        # that every note lands between 400 and 700 Hz.
        "select":   ("one small wooden tile set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1600", "cut:0.1", "body:320", "tight"),
        # A word found: four quick notes up.
        "place":    ("one soft short note on a kalimba, muffled and kind", 0.6, -10, COZY_TUNE, "warm:2400", "ease:0.01", "body:300", "notes:0.09:4,6,8,11", "cut:0.8"),
        # A word taken back: a lighter thing set down, twice and falling.
        "undo":     ("one small light wooden block set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1400", "cut:0.28", "body:320", "tight", "notes:0.11:0,-3"),
        "hint":     ("one soft note on a kalimba, a gentle little idea, short", 1.0, -10, COZY_TUNE, "warm:2000", "steep", "ease:0.012", "body:300", "notes:0.16:3,7,10", "cut:0.9"),
        "reset":    ("a soft gust of warm breeze through a few leaves, one gentle whoosh of air that rises and fades, short", 0.8, -16, BREEZE, "warm:1100", "steep", "ease:0.06", "body:320"),
        "solved":   ("one soft note on a kalimba over a gentle tongue drum, warm, left to fade", 2.0, -8, COZY_TUNE, "warm:2600", "ease:0.012", "body:300", "notes:0.14:2,4,6,9,11", "cut:1.7"),
        # The field laid out: select's take, five in a row.
        "enter":    ("one small wooden tile set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -14, HUSH, "warm:1600", "cut:0.5", "body:320", "tight", "notes:0.08:0,2,0,3,5"),
        # Rewards: the streak, the word's reactions and its gags. combo: a
        # tick a word, pitched by the board. quick: a small puff of air.
        # flutter: the butterfly going, two quiet notes up.
        "combo":    ("one small wooden block set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -14, HUSH, "warm:1600", "cut:0.055", "body:320", "tight"),
        "streak":   ("a cheerful quick three-note rising kalimba and glockenspiel run, on a roll, bright and happy, short", 0.7, -9),
        "big":      ("a pleased little 'ooh' on soft kalimba, two notes up then a third higher with a small glockenspiel sparkle, a big word found, warm", 0.8, -9),
        "quick":    ("a tiny quick puff of warm air, one light short breath that rises and fades, very short", 0.5, -17, BREEZE, "warm:1000", "steep", "ease:0.03", "body:320"),
        "love":     ("a few tiny soft bubbly pops rising with a sweet little two-note kalimba 'aww', little hearts floating up, cute and warm", 0.8, -10),
        "conga":    ("a playful little soft hand-drum and kalimba conga shuffle, bouncy and cute, letters dancing in a line, cozy", 1.2, -10, STYLE, "body:300", "warm:2600", "notes:0:5"),
        "flutter":  ("one soft short note on a kalimba, muffled and kind", 0.6, -14, COZY_TUNE, "warm:2400", "ease:0.01", "body:300", "notes:0.12:5,8", "cut:0.55"),
        "twirl":    ("a tiny playful spin, a soft airy whirl ending on a small bright kalimba 'ta-da' pluck, cute and silly, very short", 0.8, -10),
        # A wrong trail on Hard and Insane blows a dandelion seed away: a
        # breath of air, no shimmer. wish_low: two quiet notes down.
        "miss":     ("a tiny soft kalimba note with a gentle little downward wobble, a kind 'not that one', muffled and warm, very short, never a buzzer", 0.5, -13, STYLE, "body:300", "warm:2600", "notes:0:6"),
        "wish":     ("a small soft puff of warm air through a few leaves, light, rising and fading, short", 0.8, -16, BREEZE, "warm:900", "steep", "ease:0.05", "body:320"),
        "wish_low": ("one soft short note on a kalimba, muffled and kind", 0.6, -14, COZY_TUNE, "warm:2400", "ease:0.01", "body:300", "notes:0.2:6,3", "cut:0.7"),
        "droop":    ("a soft slow descending felt-mallet marimba slide, sleepy and kind, little tiles sagging gently, warm and muffled, never a buzzer", 0.8, -13),
        "out_of_wishes": ("one slow soft note on a kalimba, sleepy, calm and kind, left to fade", 1.6, -13, COZY_TUNE, "warm:2600", "ease:0.02", "body:300", "notes:0.32:10,7,4"),
        "wish_back": ("a warm rising pair of soft kalimba plucks with a tiny airy puff, a new dandelion clock growing back, gentle and happy", 0.7, -12),
        "reveal":   ("a single soft low felt kalimba note with a light paper ribbon unrolling, a word shown gently, calm, not sad", 0.6, -13, STYLE, "warm:2000", "body:300"),
        "lost":     ("a gentle warm three-note soft felt kalimba phrase slowly descending and resolving softly, a kind 'maybe tomorrow', calm, not sad, never a buzzer", 1.5, -9),
        # The party. bloom: the meadow opening, four quiet notes.
        "bloom":    ("one soft short note on a kalimba, muffled and kind", 0.6, -12, COZY_TUNE, "warm:2400", "ease:0.01", "body:300", "notes:0.13:4,8,6,11", "cut:0.9"),
        "party":    ("one soft note on a kalimba over a gentle tongue drum, warm and cozy, left to fade", 2.0, -8, COZY_TUNE, "warm:2600", "ease:0.012", "body:300", "notes:0.14:0,3,5,3,5,8", "cut:1.9"),
        "dance":    ("a short cheerful little kalimba and soft hand-drum shuffle, four playful bouncy notes, a tiny happy dance, cozy and cute", 1.2, -9, STYLE, "warm:2400", "body:300"),
        "confetti": ("a small soft puff of warm air through a few leaves, light, rising and fading, short", 0.8, -17, BREEZE, "warm:1200", "steep", "ease:0.04", "body:320"),
        "stamp":    ("one soft note on a kalimba, proud and warm, left to fade", 1.5, -9, COZY_TUNE, "warm:2600", "ease:0.012", "body:300", "notes:0.26:4,0,7"),
        # Insane: Night Walk. The lantern lit is one quiet note.
        "lantern":  ("one soft short note on a kalimba, muffled and kind", 0.6, -16, COZY_TUNE, "warm:2400", "ease:0.01", "body:300", "notes:0:6", "cut:0.45"),
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
        # Redone 2026-10-10 against the cozy rules (docs/agents/sound.md), the
        # thirteenth set of the redo, as Word Trail's above. Kept from the
        # first set, as they were: locked, check, check_ok, love, dance,
        # heart_lost and heart_back; twirl rolled off. Nothing here is moss,
        # a glockenspiel, a celesta or a slide whistle any more. place and
        # pebble are the two things a finger does all day, so they are the
        # plainest; combo is a tick the board pitches, not past five
        # semitones, cut at 0.07 s ahead of its take's second tock. Every
        # tick is `tight`. Borrowed takes: confetti is
        # Binairo's, of the same prompt; enter is place's, undo and wilt
        # remove's. The phrases' steps are set by each take's own note, so
        # that every note lands between 400 and 700 Hz.
        "place":    ("one small wooden tile set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -14, HUSH, "warm:1600", "cut:0.16", "body:320", "tight"),
        "pebble":   ("one small round wooden bead set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1500", "cut:0.09", "body:320", "tight"),
        # A lift is a lighter thing set down.
        "remove":   ("one small light wooden block set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -16, HUSH, "warm:1400", "cut:0.12", "body:320", "tight"),
        "locked":   ("a tiny soft kalimba note with a gentle little wobble, a kind 'not there', muffled and warm, very short", 0.5, -12),
        "undo":     ("one small light wooden block set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1400", "cut:0.28", "body:320", "tight", "notes:0.11:0,-3"),
        "hint":     ("one soft note on a kalimba, a gentle little idea, short", 1.0, -10, COZY_TUNE, "warm:2000", "steep", "ease:0.012", "body:300", "notes:0.16:3,7,10", "cut:0.9"),
        "check":    ("a gentle two-note melody on a soft kalimba: one note, then a second lower note, 'uh-oh' but kind, a cozy 'not quite yet', warm and round, never a buzzer", 1.0, -17, STYLE, "fall"),
        "check_ok": ("two soft warm kalimba notes going up, a friendly cozy 'all good', gentle and round", 0.7, -10),
        "reset":    ("a soft gust of warm breeze through a few leaves, one gentle whoosh of air that rises and fades, short", 0.8, -16, BREEZE, "warm:1100", "steep", "ease:0.06", "body:320"),
        # The patch laid out: place's take, five in a row.
        "enter":    ("one small wooden tile set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -14, HUSH, "warm:1600", "cut:0.5", "body:320", "tight", "notes:0.08:0,3,2,0,5"),
        "solved":   ("one soft note on a kalimba over a gentle tongue drum, warm, left to fade", 2.0, -8, COZY_TUNE, "warm:2000", "ease:0.012", "body:300", "notes:0.14:1,3,5,8,10", "cut:1.7"),
        # Pressing a number lights the cells it counts: the quietest tick
        # there is.
        "reach":    ("one small wooden block set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -18, HUSH, "warm:1300", "cut:0.08", "body:320", "tight"),
        # The streak, the gags, and the flower a finished number opens.
        # combo: a tick the board pitches by the streak. sneeze: a small
        # puff of air. bloom: one note.
        "combo":    ("one small wooden block set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -14, HUSH, "warm:1600", "cut:0.07", "body:320", "tight"),
        "confetti": ("a small soft puff of warm air through a few leaves, light, rising and fading, short", 0.8, -17, BREEZE, "warm:1200", "steep", "ease:0.04", "body:320"),
        "love":     ("a few tiny soft bubbly pops rising with a sweet little two-note kalimba 'aww', little hearts floating up, cute and warm", 0.8, -10),
        "twirl":    ("a tiny playful spin, a soft airy whirl ending on a small bright kalimba 'ta-da' pluck, cute and silly, very short", 0.8, -10, STYLE, "warm:2400", "body:300"),
        "sneeze":   ("a tiny quick puff of warm air, one light short breath that rises and fades, very short", 0.5, -16, BREEZE, "warm:750", "steep", "ease:0.02", "body:320"),
        "bloom":    ("one soft short note on a kalimba, muffled and kind", 0.6, -15, COZY_TUNE, "warm:2400", "ease:0.01", "body:300", "notes:0:7", "cut:0.45"),
        # Hearts, the wrong mushroom sinking back (three notches down, never
        # a slide), and the patch at dusk.
        "heart_lost":    ("a soft felt-mallet marimba two-note fall, a small gentle 'oh', warm and muffled, never a buzzer", 0.6, -15),
        "wilt":     ("one small light wooden block set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1300", "cut:0.5", "body:320", "tight", "notes:0.14:0,-2,-4"),
        "out_of_hearts": ("one slow soft note on a kalimba, sleepy, calm and kind, left to fade", 1.6, -13, COZY_TUNE, "warm:2600", "ease:0.02", "body:300", "notes:0.32:10,7,4"),
        "heart_back":    ("a warm rising pair of soft kalimba plucks, a little heart coming back, gentle and happy", 0.6, -15),
        # The party. meadow: the flowers opening, four quiet notes.
        "stamp":    ("one soft note on a kalimba, proud and warm, left to fade", 1.5, -9, COZY_TUNE, "warm:2600", "ease:0.012", "body:300", "notes:0.26:7,4,11"),
        "party":    ("one soft note on a kalimba over a gentle tongue drum, warm and cozy, left to fade", 2.0, -8, COZY_TUNE, "warm:2600", "ease:0.012", "body:300", "notes:0.14:4,7,9,7,9,12", "cut:1.9"),
        "dance":    ("a short cheerful little kalimba and soft hand-drum shuffle, four playful bouncy notes, a tiny happy dance, cozy and cute", 1.2, -9),
        "meadow":   ("one soft short note on a kalimba, muffled and kind", 0.6, -12, COZY_TUNE, "warm:2400", "ease:0.01", "body:300", "notes:0.13:4,8,6,11", "cut:0.9"),
        # Insane: Fairy Rings. The rings grow in after the patch, a long slow
        # breath of air, and glow at the party, three slow notes that rise and settle.
        "rings":    ("a long soft gust of warm breeze through a few leaves, one slow gentle whoosh of air that rises and fades", 1.6, -16, BREEZE, "warm:1100", "steep", "ease:0.12", "body:320"),
        "rings_glow": ("one slow soft note on a kalimba, calm and kind, left to fade", 1.6, -11, COZY_TUNE, "warm:2600", "ease:0.02", "body:300", "notes:0.35:4,11,8"),
    },
    # Sudoku: numerals in ink on paper panels laid in a wooden tray; a row,
    # column or region that fills lights up in a wave. Re-prompted toward
    # felt, paper, soft pencil and kalimba on 2026-09-30 (the polish), as
    # Mushroom Patch's and Queens' were: the tape-rewind undo and the wooden
    # "bonk" read as a toy or a scold. Hard and Insane judge a number as it
    # lands: a wrong one costs a heart and tumbles off the paper. Insane is
    # Hilltops: little hills that count the lower cells beside them.
    "sudoku": {
        # Redone 2026-10-10 against the cozy rules (docs/agents/sound.md), the
        # fourteenth set of the redo, as Mushroom Patch's above. Kept from
        # the first set, as they were: line, locked, love, twirl, dance and
        # heart_back; check_ok and heart_lost rolled off, ruled six steps up
        # with its rumble off. Nothing here is a pencil, paper, an eraser, a
        # glockenspiel, a music box, a celesta or a slide whistle any more.
        # place and pencil are the two things a finger does all day, so they
        # are the plainest; combo is a tick the board pitches, not past five
        # semitones. Every tick is `tight`. Borrowed takes: check is Code
        # Break's and confetti Binairo's, of the same prompts; enter is
        # place's and so is boing (combo's take holds a second tock 0.12 s
        # behind, so combo is cut at 0.07 s), undo and tumble pencil's. The
        # phrases' steps are set by each take's own note, so that every note
        # lands between 400 and 700 Hz.
        "place":    ("one small wooden tile set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -14, HUSH, "warm:1600", "cut:0.16", "body:320", "tight"),
        # A pencilled note: a lighter thing set down.
        "pencil":   ("one small light wooden block set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -17, HUSH, "warm:1200", "cut:0.1", "body:320", "tight"),
        "line":     ("a short happy two-note soft kalimba pluck rising, a row completed, warm and round", 0.6, -8),
        "locked":   ("a tiny soft kalimba note with a gentle little wobble, a kind 'not there', muffled and warm, very short", 0.5, -12),
        "undo":     ("one small light wooden block set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1200", "cut:0.28", "body:320", "tight", "notes:0.11:0,-3"),
        "hint":     ("one soft note on a kalimba, a gentle little idea, short", 1.0, -10, COZY_TUNE, "warm:2000", "steep", "ease:0.012", "body:300", "notes:0.16:4,8,11", "cut:0.9"),
        "check":    ("a gentle two-note melody on a soft kalimba: one note, then a second lower note, 'uh-oh' but kind, a cozy 'not quite yet', warm and round, never a buzzer", 1.0, -17, STYLE, "fall"),
        "check_ok": ("two soft warm kalimba notes going up, a friendly cozy 'all good', gentle and round", 0.7, -10, STYLE, "warm:2400", "body:300"),
        "reset":    ("a soft gust of warm breeze through a few leaves, one gentle whoosh of air that rises and fades, short", 0.8, -16, BREEZE, "warm:1100", "steep", "ease:0.06", "body:320"),
        # The tray laid out: place's take, five in a row.
        "enter":    ("one small wooden tile set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -14, HUSH, "warm:1600", "cut:0.5", "body:320", "tight", "notes:0.08:0,2,3,0,5"),
        "solved":   ("one soft note on a kalimba over a gentle tongue drum, warm, left to fade", 2.0, -8, COZY_TUNE, "warm:2000", "ease:0.012", "body:300", "notes:0.14:3,5,7,10,12", "cut:1.7"),
        # A number is complete (all nine are placed): four quick notes, up,
        # back a step and up. A region's sticker opens on one quiet note.
        "all_home": ("one soft short note on a kalimba, muffled and kind", 0.6, -11, COZY_TUNE, "warm:2400", "ease:0.01", "body:300", "notes:0.1:4,9,7,12", "cut:0.85"),
        "bloom":    ("one soft short note on a kalimba, muffled and kind", 0.6, -15, COZY_TUNE, "warm:2400", "ease:0.01", "body:300", "notes:0:7", "cut:0.45"),
        # The streak and the gags. combo: a tick the board pitches by the
        # streak. boing: the number hopping, place's take three times, up
        # and back a step.
        "combo":    ("one small wooden block set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -14, HUSH, "warm:1300", "cut:0.07", "body:320", "tight"),
        "confetti": ("a small soft puff of warm air through a few leaves, light, rising and fading, short", 0.8, -17, BREEZE, "warm:1200", "steep", "ease:0.04", "body:320"),
        "love":     ("a few tiny soft bubbly pops rising with a sweet little two-note kalimba 'aww', little hearts floating up, cute and warm", 0.8, -10),
        "twirl":    ("a tiny playful spin, a soft airy whirl ending on a small bright kalimba 'ta-da' pluck, cute and silly, very short", 0.8, -10),
        "boing":    ("one small wooden block set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -14, HUSH, "warm:1300", "cut:0.5", "body:320", "tight", "notes:0.15:0,4,2"),
        # Hearts, the wrong number tumbling off (three notches down, never a
        # slide), and the tray at dusk.
        "heart_lost":    ("a soft felt-mallet marimba two-note fall, a small gentle 'oh', warm and muffled, never a buzzer", 0.6, -15, STYLE, "warm:2400", "body:300"),
        "tumble":   ("one small light wooden block set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1200", "cut:0.5", "body:320", "tight", "notes:0.14:0,-2,-4"),
        "ruled":    ("a very soft short felt tap with a tiny low kalimba note, a gentle 'we already know that one', quiet and kind", 0.5, -14, STYLE, "body:300", "warm:2600", "notes:0:6"),
        "out_of_hearts": ("one slow soft note on a kalimba, sleepy, calm and kind, left to fade", 1.6, -13, COZY_TUNE, "warm:2600", "ease:0.02", "body:300", "notes:0.32:6,3,0"),
        "heart_back":    ("a warm rising pair of soft kalimba plucks, a little heart coming back, gentle and happy", 0.6, -15),
        # The party.
        "stamp":    ("one soft note on a kalimba, proud and warm, left to fade", 1.5, -9, COZY_TUNE, "warm:2600", "ease:0.012", "body:300", "notes:0.26:7,4,11"),
        "party":    ("one soft note on a kalimba over a gentle tongue drum, warm and cozy, left to fade", 2.0, -8, COZY_TUNE, "warm:2600", "ease:0.012", "body:300", "notes:0.14:4,7,9,7,9,12", "cut:1.9"),
        "dance":    ("a short cheerful little kalimba and soft hand-drum shuffle, four playful bouncy notes, a tiny happy dance, cozy and cute", 1.2, -9),
        # Insane: Hilltops. The hills rise in after the grid, a long slow
        # breath of air, and glow at the party, three slow notes that rise
        # and settle.
        "hills":    ("a long soft gust of warm breeze through a few leaves, one slow gentle whoosh of air that rises and fades", 1.6, -16, BREEZE, "warm:1100", "steep", "ease:0.12", "body:320"),
        "hills_glow": ("one slow soft note on a kalimba, calm and kind, left to fade", 1.6, -11, COZY_TUNE, "warm:2600", "ease:0.02", "body:300", "notes:0.35:2,9,6"),
    },
    # Bridges: wooden plank bridges laid between islets on a calm sea. The
    # first set was re-prompted 2026-09-30 (the polish) toward soft wood,
    # felt, gentle water and kalimba: the hollow "bonk" and the tape-rewind
    # undo read as a toy or a scold, as they did on Sudoku and Mushroom Patch.
    "bridges": {
        # Redone 2026-10-10 against the cozy rules (docs/agents/sound.md), the
        # fifteenth set of the redo, as Sudoku's above. Kept from the first
        # set, as they were: over, locked, check_ok, split, love, dance,
        # heart_back and the boat; met, twirl and heart_lost rolled off.
        # Nothing here is a plank's creak, a drip, a splash, a bell, a
        # glockenspiel, a music box or a celesta any more. place and remove
        # are the two things a finger does all day, so they are the plainest;
        # combo is a tick the board pitches, not past five semitones. Every
        # tick is `tight`. Borrowed takes: check is Code Break's and confetti
        # Binairo's, of the same prompts; enter is place's, undo and sink
        # remove's, ruled join's. The phrases' steps are set by each take's
        # own note, so that every note lands between 400 and 700 Hz.
        "place":    ("one small wooden block set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -14, HUSH, "warm:1600", "cut:0.16", "body:320", "tight"),
        # A lift is a lighter thing set down.
        "remove":   ("one small light wooden block set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -16, HUSH, "warm:1400", "cut:0.12", "body:320", "tight"),
        "met":      ("a short happy two-note soft kalimba pluck rising, a little island complete, warm and round", 0.6, -10, STYLE, "warm:2400", "body:300"),
        "over":     ("a tiny soft kalimba note with a gentle little wobble, a kind 'too many', muffled and warm, very short", 0.5, -13),
        "locked":   ("a tiny soft kalimba note with a gentle little wobble, a kind 'not there', muffled and warm, very short", 0.5, -12),
        "undo":     ("one small light wooden block set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1200", "cut:0.28", "body:320", "tight", "notes:0.11:0,-3"),
        "hint":     ("one soft note on a kalimba, a gentle little idea, short", 1.0, -10, COZY_TUNE, "warm:2000", "steep", "ease:0.012", "body:300", "notes:0.16:3,6,10", "cut:0.9"),
        "check":    ("a gentle two-note melody on a soft kalimba: one note, then a second lower note, 'uh-oh' but kind, a cozy 'not quite yet', warm and round, never a buzzer", 1.0, -17, STYLE, "fall"),
        "check_ok": ("two soft warm kalimba notes going up, a friendly cozy 'all good', gentle and round", 0.7, -10),
        "reset":    ("a soft gust of warm breeze through a few leaves, one gentle whoosh of air that rises and fades, short", 0.8, -16, BREEZE, "warm:1100", "steep", "ease:0.06", "body:320"),
        # The islets rising: place's take, five in a row.
        "enter":    ("one small wooden block set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -14, HUSH, "warm:1600", "cut:0.5", "body:320", "tight", "notes:0.08:0,3,0,2,5"),
        "solved":   ("one soft note on a kalimba over a gentle tongue drum, warm, left to fade", 2.0, -8, COZY_TUNE, "warm:2000", "ease:0.012", "body:300", "notes:0.14:-1,1,4,6,8", "cut:1.7"),
        # The network: two groups joined, two quiet notes alike and a third
        # up, and the near-miss named.
        "join":     ("one soft short note on a kalimba, muffled and kind", 0.6, -12, COZY_TUNE, "warm:2400", "ease:0.01", "body:300", "notes:0.11:4,4,9", "cut:0.7"),
        "split":    ("a gentle curious three-note kalimba question, rising at the end, 'hmm, almost', warm and kind, never a buzzer", 0.9, -13),
        # The streak and the gags. combo: a tick the board pitches by the
        # streak. fish: a small puff of air where the splash was.
        "combo":    ("one small wooden block set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -14, HUSH, "warm:1600", "cut:0.1", "body:320", "tight"),
        "confetti": ("a small soft puff of warm air through a few leaves, light, rising and fading, short", 0.8, -17, BREEZE, "warm:1200", "steep", "ease:0.04", "body:320"),
        "love":     ("a few tiny soft bubbly pops rising with a sweet little two-note kalimba 'aww', little hearts floating up, cute and warm", 0.8, -10),
        "twirl":    ("a tiny playful spin, a soft airy whirl ending on a small bright kalimba 'ta-da' pluck, cute and silly, very short", 0.8, -10, STYLE, "warm:2400", "body:300"),
        "fish":     ("a tiny quick puff of warm air, one light short breath that rises and fades, very short", 0.5, -16, BREEZE, "warm:750", "steep", "ease:0.03", "body:320"),
        # Hearts, the wrong plank sinking (three notches down, never a
        # slide), the buoy (one quiet note, no bell), and the pond at dusk.
        "heart_lost":    ("a soft felt-mallet marimba two-note fall, a small gentle 'oh', warm and muffled, never a buzzer", 0.6, -15, STYLE, "warm:2400", "body:300"),
        "sink":     ("one small light wooden block set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1200", "cut:0.5", "body:320", "tight", "notes:0.14:0,-2,-4"),
        "ruled":    ("one soft short note on a kalimba, muffled and kind", 0.6, -14, COZY_TUNE, "warm:2400", "ease:0.01", "body:300", "notes:0:7", "cut:0.45"),
        "out_of_hearts": ("one slow soft note on a kalimba, sleepy, calm and kind, left to fade", 1.6, -13, COZY_TUNE, "warm:2600", "ease:0.02", "body:300", "notes:0.32:9,5,2"),
        "heart_back":    ("a warm rising pair of soft kalimba plucks, a little heart coming back, gentle and happy", 0.6, -15),
        # The party.
        "stamp":    ("one soft note on a kalimba, proud and warm, left to fade", 1.5, -9, COZY_TUNE, "warm:2600", "ease:0.012", "body:300", "notes:0.26:1,-3,4"),
        "party":    ("one soft note on a kalimba over a gentle tongue drum, warm and cozy, left to fade", 2.0, -8, COZY_TUNE, "warm:2600", "ease:0.012", "body:300", "notes:0.14:4,8,11,8,11,13", "cut:1.9"),
        "dance":    ("a short cheerful little kalimba and soft hand-drum shuffle, four playful bouncy notes, a tiny happy dance, cozy and cute", 1.2, -9),
        "boat":     ("a tiny paper boat drifting across a calm pond, gentle water lapping and a soft little toy boat horn toot, cute and cozy", 2.0, -11, CARTOON),
        # Insane: Lantern Night. The lanterns light after the islets rise, a
        # long slow breath of air, and flare at the party, three slow notes
        # that rise and settle.
        "lanterns": ("a long soft gust of warm breeze through a few leaves, one slow gentle whoosh of air that rises and fades", 1.6, -16, BREEZE, "warm:1100", "steep", "ease:0.12", "body:320"),
        "lanterns_glow": ("one slow soft note on a kalimba, calm and kind, left to fade", 1.6, -11, COZY_TUNE, "warm:2600", "ease:0.02", "body:300", "notes:0.35:4,13,9"),
    },
    # Quilt: cloth patches dragged off a rack onto a backing; a patch that
    # lands sews a running stitch along its seams. The first set was
    # re-prompted 2026-09-30 (the polish) toward felt, cotton, a wooden spool,
    # soft pins and kalimba: the tape-rewind undo and the cloth "bonk" read as
    # a toy or a scold, as they did on Bridges and Sudoku. Hard and Insane
    # judge a patch as it lands: a wrong one's thread snaps and it flutters
    # home. Insane is Scrap Basket: three scraps that don't belong.
    "quilt": {
        # Redone 2026-10-10 against the cozy rules (docs/agents/sound.md), the
        # sixteenth set of the redo. Kept from the first set, as they were:
        # refused, stuck, heart_lost and dance; heart_back and the bunting
        # rolled off (the bunting keeps its first prompt, cloth flags and
        # all, and passes the measure). Nothing new is cloth, thread, a
        # needle, scissors, chalk, a glockenspiel or a music box (a rustle
        # and a flap are scratch, a snip is steel). lift and place are the two things a
        # finger does all day, so they are the plainest; combo is a tick the
        # board pitches, not past five semitones. Every tick is `tight`.
        # Borrowed takes: confetti is Binairo's and the cat Untangle's
        # kitten, of the same prompts; enter and boing are place's, undo,
        # wiggle and snip lift's, ruled and love row's (the hearts' bubbly
        # pops sat at 1 kHz however they were rolled off: two quiet notes
        # alike and a third up now). The phrases' steps are set by each
        # take's own note, so that every note lands between 400 and 700 Hz.
        # A lift is a lighter thing set down.
        "lift":     ("one small light wooden button set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -16, HUSH, "warm:1400", "cut:0.12", "body:320", "tight"),
        "place":    ("one small wooden spool set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -14, HUSH, "warm:1600", "cut:0.16", "body:320", "tight"),
        "refused":  ("a tiny soft kalimba note with a gentle little wobble, a kind 'not there', muffled and warm, very short", 0.5, -12),
        "undo":     ("one small light wooden button set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1200", "cut:0.28", "body:320", "tight", "notes:0.11:0,-3"),
        "hint":     ("one soft note on a kalimba, a gentle little idea, short", 1.0, -10, COZY_TUNE, "warm:2000", "steep", "ease:0.012", "body:300", "notes:0.16:4,7,11", "cut:0.9"),
        "reset":    ("a soft gust of warm breeze through a few leaves, one gentle whoosh of air that rises and fades, short", 0.8, -16, BREEZE, "warm:1100", "steep", "ease:0.06", "body:320"),
        # The patches laid out: place's take, five in a row.
        "enter":    ("one small wooden spool set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -14, HUSH, "warm:1600", "cut:0.5", "body:320", "tight", "notes:0.08:0,3,0,2,5"),
        "solved":   ("one soft note on a kalimba over a gentle tongue drum, warm, left to fade", 2.0, -8, COZY_TUNE, "warm:2000", "ease:0.012", "body:300", "notes:0.14:4,6,9,11,13", "cut:1.7"),
        # The rack patch tapped (two notches, side to side), and the dead end
        # named (Easy and Medium).
        "wiggle":   ("one small light wooden button set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -16, HUSH, "warm:1400", "cut:0.22", "body:320", "tight", "notes:0.07:2,0"),
        "stuck":    ("a gentle two-note melody on a soft kalimba: one note, then a second lower note, 'hmm, that gap won't fill', kind and curious, warm and round, never a buzzer", 1.0, -16, STYLE, "fall"),
        # The streak and the gags. combo: a tick the board pitches by the
        # streak. button: a wooden bead pressed home. boing: place's take
        # three times, up and back.
        "combo":    ("one small wooden block set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -14, HUSH, "warm:1600", "cut:0.1", "body:320", "tight"),
        "confetti": ("a small soft puff of warm air through a few leaves, light, rising and fading, short", 0.8, -17, BREEZE, "warm:1200", "steep", "ease:0.04", "body:320"),
        "love":     ("one soft short note on a kalimba, muffled and kind", 0.6, -13, COZY_TUNE, "warm:2400", "ease:0.01", "body:300", "notes:0.1:5,5,8", "cut:0.6"),
        "button":   ("one small round wooden bead set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1500", "cut:0.14", "body:320", "tight"),
        "boing":    ("one small wooden spool set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1600", "cut:0.4", "body:320", "tight", "notes:0.1:0,3,0"),
        # A row or column of the quilt finished: four quick quiet notes up.
        "row":      ("one soft short note on a kalimba, muffled and kind", 0.6, -12, COZY_TUNE, "warm:2400", "ease:0.01", "body:300", "notes:0.07:3,5,7,10", "cut:0.7"),
        # Hearts, the wrong patch's thread let go (one light notch) and the
        # patch blown home (a small puff of air, never a flap), the chalk
        # mark (one quiet note), the quilt at dusk.
        "heart_lost":    ("a soft felt-mallet marimba two-note fall, a small gentle 'oh', warm and muffled, never a buzzer", 0.6, -15),
        "snip":     ("one small light wooden button set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1500", "cut:0.09", "body:320", "tight", "notes:0:4"),
        "flutter":  ("a tiny quick puff of warm air, one light short breath that rises and fades, very short", 0.5, -16, BREEZE, "warm:750", "steep", "ease:0.03", "body:320"),
        "ruled":    ("one soft short note on a kalimba, muffled and kind", 0.6, -14, COZY_TUNE, "warm:2400", "ease:0.01", "body:300", "notes:0:7", "cut:0.45"),
        "out_of_hearts": ("one slow soft note on a kalimba, sleepy, calm and kind, left to fade", 1.6, -13, COZY_TUNE, "warm:2600", "ease:0.02", "body:300", "notes:0.32:10,6,3"),
        "heart_back":    ("a warm rising pair of soft kalimba plucks, a little heart coming back, gentle and happy", 0.6, -15, STYLE, "warm:2400", "body:300"),
        # The party.
        "stamp":    ("one soft note on a kalimba, proud and warm, left to fade", 1.5, -9, COZY_TUNE, "warm:2600", "ease:0.012", "body:300", "notes:0.26:7,4,10"),
        "party":    ("one soft note on a kalimba over a gentle tongue drum, warm and cozy, left to fade", 2.0, -8, COZY_TUNE, "warm:2600", "ease:0.012", "body:300", "notes:0.14:-1,3,6,3,6,8", "cut:1.9"),
        "dance":    ("a short cheerful little kalimba and soft hand-drum shuffle, four playful bouncy notes, a tiny happy dance, cozy and cute", 1.2, -9),
        "purr":     ("one short soft contented chirrup, a little rolling trill with the mouth closed, gentle and happy", 1.0, -12, KITTEN, "warm:2400", "ease:0.01", "body:300"),
        # Insane: Scrap Basket. The three scraps strung up as bunting at the solve.
        "bunting":  ("little cloth flags strung up on a line and fluttering in a gentle breeze, soft fabric flaps with a cheerful rising three-note kalimba, happy and cozy", 1.3, -11, COZY, "warm:2400", "body:300"),
    },
    # Paper Planes: tap a folded paper dart and it launches down its lane.
    # Re-prompted 2026-09-30 (the polish) toward soft paper, felt, kalimba, a
    # music box and gentle breaths of air (BREEZE in place of the house
    # marimba): the tape-rewind undo and the papery "bonk" read as a toy or a
    # scold. `place` is the launch. Hard and Insane crash a plane on a wrong
    # launch; Insane is Windy Day, and `drift` rides every launch there, so it
    # is short and very quiet.
    "planes": {
        # Redone 2026-10-10 against the cozy rules (docs/agents/sound.md), the
        # seventeenth set of the redo, with Quilt's above. Kept from the
        # first set, as they were: refuse, undo, hint, heart_lost, heart_back
        # and the clouds; the flock rolled off (undo, hint and the clouds
        # keep their first prompts, a paper rustle and a music box in them,
        # and pass the measure). Nothing new is paper, a music box or a bird
        # (a rustle, a fold and a crinkle are scratch, a chirp sat whole
        # above 3 kHz). A launch travels, so
        # `place` is a small puff of air, the first one a phone plays: the
        # old one was a breath at 19 Hz. combo is a tick the board pitches,
        # not past five semitones. Every tick is `tight`. Borrowed takes:
        # confetti is Binairo's and the cat Untangle's kitten, of the same
        # prompts; whoosh is place's, flutter crash's, tweet and love loop's.
        # The phrases' steps are set by each take's own note, so that every
        # note lands between 400 and 700 Hz.
        "place":    ("a tiny quick puff of warm air, one light short breath that rises and fades, very short", 0.5, -15, BREEZE, "warm:900", "steep", "ease:0.015", "body:320", "cut:0.3"),
        "refuse":   ("a tiny soft kalimba note with a gentle little wobble, a kind 'not that one', muffled and warm, very short", 0.5, -12, BREEZE),
        "undo":     ("a tiny soft paper rustle and a small kalimba note sliding gently down, a kind 'take that back', warm and quiet, very short", 0.5, -11, BREEZE),
        "hint":     ("a gentle magical sparkle, three soft music box notes rising with a warm kalimba note underneath, cozy and kind", 1.0, -8, BREEZE),
        "reset":    ("a soft gust of warm breeze through a few leaves, one gentle whoosh of air that rises and fades, short", 0.8, -16, BREEZE, "warm:1100", "steep", "ease:0.06", "body:320"),
        # The planes appearing in the sky: a long slow breath.
        "enter":    ("a long soft gust of warm breeze through a few leaves, one slow gentle whoosh of air that rises and fades", 1.2, -16, BREEZE, "warm:1100", "steep", "ease:0.12", "body:320"),
        "solved":   ("one soft note on a kalimba over a gentle tongue drum, warm, left to fade", 2.0, -8, COZY_TUNE, "warm:2000", "ease:0.012", "body:300", "notes:0.14:2,4,7,9,11", "cut:1.7"),
        # The streak and the gags. combo: a tick the board pitches by the
        # streak. loop: four quiet notes up and over. tweet: two quiet
        # notes, the bird. whoosh: place's puff, lower and slower in.
        "combo":    ("one small wooden block set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -14, HUSH, "warm:1600", "cut:0.1", "body:320", "tight"),
        "confetti": ("a small soft puff of warm air through a few leaves, light, rising and fading, short", 0.8, -17, BREEZE, "warm:1200", "steep", "ease:0.04", "body:320"),
        "loop":     ("one soft short note on a kalimba, muffled and kind", 0.6, -12, COZY_TUNE, "warm:2400", "ease:0.01", "body:300", "notes:0.12:4,9,7,4", "cut:0.8"),
        "tweet":    ("one soft short note on a kalimba, muffled and kind", 0.6, -15, COZY_TUNE, "warm:2400", "ease:0.01", "body:300", "notes:0.09:9,11", "cut:0.4"),
        "whoosh":   ("a tiny quick puff of warm air, one light short breath that rises and fades, very short", 0.5, -15, BREEZE, "warm:750", "steep", "ease:0.05", "body:320"),
        "love":     ("one soft short note on a kalimba, muffled and kind", 0.6, -13, COZY_TUNE, "warm:2400", "ease:0.01", "body:300", "notes:0.1:5,5,8", "cut:0.6"),
        # Crashes and hearts (Hard and Insane). crash: a soft nose on a
        # cushion, one tock. flutter: its take, three notches down, never a
        # flap.
        "crash":    ("one small wooden peg set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -14, HUSH, "warm:1400", "cut:0.16", "body:320", "tight"),
        "flutter":  ("one small wooden peg set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -16, HUSH, "warm:1200", "cut:0.5", "body:320", "tight", "notes:0.14:0,-2,-4"),
        "heart_lost":    ("a soft gentle kalimba two-note fall, a small sad 'oh', a delicate note dropping, warm and muffled, never a buzzer", 0.6, -15, BREEZE),
        "out_of_hearts": ("one slow soft note on a kalimba, sleepy, calm and kind, left to fade", 1.6, -13, COZY_TUNE, "warm:2600", "ease:0.02", "body:300", "notes:0.32:10,7,4"),
        "heart_back":    ("a warm rising pair of soft kalimba plucks, a little heart coming back, gentle and happy", 0.6, -15, BREEZE),
        # Windy Day (Insane). drift rides every launch, so it is the
        # quietest; stuck is the breeze settling.
        "gust":     ("a soft gust of warm breeze through a few leaves, one gentle whoosh of air that rises, passes and fades", 1.0, -15, BREEZE, "warm:1100", "steep", "ease:0.08", "body:320"),
        "drift":    ("a tiny breath of warm air, one light short puff that fades", 0.5, -19, BREEZE, "warm:800", "steep", "ease:0.04", "body:320", "cut:0.3"),
        "stuck":    ("a soft breath of warm breeze that eases, fades and stops, calm, short", 0.8, -17, BREEZE, "warm:900", "steep", "ease:0.05", "body:320"),
        # The party.
        "stamp":    ("one soft note on a kalimba, proud and warm, left to fade", 1.5, -9, COZY_TUNE, "warm:2600", "ease:0.012", "body:300", "notes:0.26:9,5,12"),
        "party":    ("one soft note on a kalimba over a gentle tongue drum, warm and cozy, left to fade", 2.0, -8, COZY_TUNE, "warm:2600", "ease:0.012", "body:300", "notes:0.14:4,8,11,8,11,13", "cut:1.9"),
        "flock":    ("many little paper planes whooshing softly past together, airy swishes overlapping, with a bright rising kalimba flourish, joyful and gentle", 1.6, -9, BREEZE, "warm:2000", "body:300"),
        "purr":     ("one short soft contented chirrup, a little rolling trill with the mouth closed, gentle and happy", 1.0, -12, KITTEN, "warm:2400", "ease:0.01", "body:300"),
        "clouds":   ("soft fluffy clouds drifting apart, an airy gentle shimmer of breeze with a warm slow music box note, dreamy and calm", 1.5, -12, BREEZE),
    },
    # Pinwheel: tap a paper pinwheel and its cloth piece takes a quarter turn.
    # Re-prompted in the polish (2026-10-01) toward a sewing basket on a
    # breezy porch (LINEN in place of the house marimba): soft paper whirrs,
    # linen, felt, a wooden spool, kalimba and a music box. No tape-rewind
    # undo, no wooden bonk.
    "pinwheel": {
        # Redone 2026-10-10 against the cozy rules (docs/agents/sound.md), the
        # eighteenth set of the redo. Kept from the polish's set, as they
        # were: refused, hint, heart_lost and heart_back (hint keeps its
        # first prompt, a music box in it, and passes the measure). Nothing
        # new is paper, linen, thread, a needle, a ribbon, a music box or a
        # whistle (a whirr, a rustle and a flutter are scratch, a needle is
        # steel, a twang rings). A quarter turn is the thing a finger does
        # all day, so `place` is the plainest: one notch of a wheel. combo
        # is a tick the board pitches, not past five semitones. Every tick
        # is `tight`. Borrowed takes: confetti is Binairo's and the cat
        # Untangle's kitten, of the same prompts; enter is place's, undo,
        # tack and tug snag's, love flutter's. The phrases' steps are set by
        # each take's own note, so that every note lands between 400 and
        # 700 Hz. What travels on air is air: the whirl, the kite and the
        # ribbons are a breath of breeze each.
        "place":    ("one small wooden bobbin set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -14, HUSH, "warm:1600", "cut:0.16", "body:320", "tight"),
        "refused":  ("a tiny soft kalimba note with a gentle little wobble, a kind 'that one stays', muffled and warm, very short", 0.5, -12, LINEN),
        "undo":     ("one small light wooden button set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1200", "cut:0.28", "body:320", "tight", "notes:0.11:0,-3"),
        "hint":     ("a gentle magical sparkle, three soft music box notes rising with a warm kalimba note underneath, cozy and kind", 1.0, -8, LINEN),
        "reset":    ("a soft gust of warm breeze through a few leaves, one gentle whoosh of air that rises and fades, short", 0.8, -16, BREEZE, "warm:1100", "steep", "ease:0.06", "body:320"),
        # The pinwheels pinned up: place's take, five in a row.
        "enter":    ("one small wooden bobbin set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -14, HUSH, "warm:1600", "cut:0.5", "body:320", "tight", "notes:0.08:0,3,0,2,5"),
        "solved":   ("one soft note on a kalimba over a gentle tongue drum, warm, left to fade", 2.0, -8, COZY_TUNE, "warm:2000", "ease:0.012", "body:300", "notes:0.14:6,8,11,13,15", "cut:1.7"),
        # The streak and the gags. combo: a tick the board pitches by the
        # streak. whirl: a pinwheel catching a gust. flutter: two quiet
        # notes up, the butterfly.
        "combo":    ("one small wooden block set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -14, HUSH, "warm:1600", "cut:0.1", "body:320", "tight"),
        "confetti": ("a small soft puff of warm air through a few leaves, light, rising and fading, short", 0.8, -17, BREEZE, "warm:1200", "steep", "ease:0.04", "body:320"),
        "whirl":    ("a soft gust of warm breeze through a few leaves, one gentle whoosh of air that rises, passes and fades", 1.0, -15, BREEZE, "warm:1100", "steep", "ease:0.08", "body:320"),
        "love":     ("one soft short note on a kalimba, muffled and kind", 0.6, -13, COZY_TUNE, "warm:2400", "ease:0.01", "body:300", "notes:0.1:5,5,8", "cut:0.6"),
        "flutter":  ("one soft short note on a kalimba, muffled and kind", 0.6, -15, COZY_TUNE, "warm:2400", "ease:0.01", "body:300", "notes:0.09:7,9", "cut:0.4"),
        # Snags and hearts (Hard and Insane). snag: the wrong turn caught, one
        # light notch. tack: its take, two quick notches, the piece stitched
        # down. tug: its take, lower, a ribbon gone taut (Insane).
        "snag":     ("one small light wooden button set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1400", "cut:0.12", "body:320", "tight"),
        "heart_lost":    ("a soft gentle kalimba two-note fall, a small sad 'oh', a delicate note dropping, warm and muffled, never a buzzer", 0.6, -15, LINEN),
        "tack":     ("one small light wooden button set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -16, HUSH, "warm:1400", "cut:0.22", "body:320", "tight", "notes:0.07:0,2"),
        "out_of_hearts": ("one slow soft note on a kalimba, sleepy, calm and kind, left to fade", 1.6, -13, COZY_TUNE, "warm:2600", "ease:0.02", "body:300", "notes:0.32:4,1,-3"),
        "heart_back":    ("a warm rising pair of soft kalimba plucks, a little heart coming back, gentle and happy", 0.6, -15, LINEN),
        "tug":      ("one small light wooden button set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1300", "cut:0.12", "body:320", "tight", "notes:0:-2"),
        # The party. kite: a long breath that rises. ribbons (Insane): the
        # breeze easing as they slip loose.
        "stamp":    ("one soft note on a kalimba, proud and warm, left to fade", 1.5, -9, COZY_TUNE, "warm:2600", "ease:0.012", "body:300", "notes:0.26:9,5,12"),
        "party":    ("one soft note on a kalimba over a gentle tongue drum, warm and cozy, left to fade", 2.0, -8, COZY_TUNE, "warm:2600", "ease:0.012", "body:300", "notes:0.14:-1,3,6,3,6,8", "cut:1.9"),
        "kite":     ("a long soft gust of warm breeze through a few leaves, one slow gentle whoosh of air that rises and fades", 1.2, -15, BREEZE, "warm:1100", "steep", "ease:0.12", "body:320"),
        "purr":     ("one short soft contented chirrup, a little rolling trill with the mouth closed, gentle and happy", 1.0, -12, KITTEN, "warm:2400", "ease:0.01", "body:300"),
        "ribbons":  ("a soft breath of warm breeze that eases, fades and stops, calm, short", 0.8, -17, BREEZE, "warm:900", "steep", "ease:0.05", "body:320"),
    },
    # Caterpillar: drag from leaf 1 and every square grows the caterpillar a
    # segment; it eats the leaves in order. `step` fires on every square, so
    # it gets no file (docs/art/sound-direction.md). Re-prompted in the
    # polish (2026-10-01) toward a sunny clover garden (CLOVER in place of
    # the house marimba): no tape-rewind undo, no wooden bonk.
    "caterpillar": {
        # Redone 2026-10-10 against the cozy rules (docs/agents/sound.md), the
        # nineteenth set of the redo, with Pinwheel's above. Kept from the
        # polish's set, as they were: refuse, strand, heart_lost and
        # heart_back. Nothing new is a leaf, a crunch, a bubble, a buzz, a
        # wing, a music box or a party blower (a rustle and a crunch are
        # scratch, the ladybug's buzz sat whole above 3 kHz). munch fires on
        # every leaf eaten, so it is two low notches, a nibble; combo is a
        # tick the board pitches, not past five semitones. Every tick is
        # `tight`. Borrowed takes: confetti is Binairo's and the cat
        # Untangle's kitten, of the same prompts, and reset Pinwheel's (four
        # takes here each came back a scratch); enter is place's, slip
        # undo's, love and burp row's, fill and hungry the ladybug's. combo
        # is cut at 0.055 s, ahead of its take's second tock at 60 ms. The
        # phrases' steps are set by each take's own note, so that every note
        # lands between 400 and 700 Hz, and no two phrases share a contour.
        # A lift is a lighter thing set down.
        "place":    ("one small wooden bead set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -14, HUSH, "warm:1600", "cut:0.16", "body:320", "tight"),
        "munch":    ("one small wooden peg set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1400", "cut:0.24", "body:320", "tight", "notes:0.08:0,2"),
        "refuse":   ("a tiny soft kalimba note with a gentle little wobble and a muffled leafy tap, a kind 'not that way', warm, very short", 0.5, -12, CLOVER),
        "undo":     ("one small light wooden button set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1200", "cut:0.28", "body:320", "tight", "notes:0.11:0,-3"),
        "hint":     ("one soft note on a kalimba, a gentle little idea, short", 1.0, -10, COZY_TUNE, "warm:2000", "steep", "ease:0.012", "body:300", "notes:0.16:9,12,16", "cut:0.9"),
        "reset":    ("a soft gust of warm breeze through a few leaves, one gentle whoosh of air that rises and fades, short", 0.8, -16, BREEZE, "warm:1100", "steep", "ease:0.06", "body:320"),
        "solved":   ("one soft note on a kalimba over a gentle tongue drum, warm, left to fade", 2.0, -8, COZY_TUNE, "warm:2000", "ease:0.012", "body:300", "notes:0.14:4,6,9,11,13", "cut:1.7"),
        # The leaves laid out: place's take, five in a row.
        "enter":    ("one small wooden bead set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -14, HUSH, "warm:1600", "cut:0.5", "body:320", "tight", "notes:0.08:0,3,0,2,5"),
        # The streak and the gags. combo: a tick the board pitches by the
        # streak. burp: one quiet note. ladybug: three quiet notes, up and
        # back a step. hungry: two low notes alike, a kind 'not yet'.
        "combo":    ("one small wooden block set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -14, HUSH, "warm:1600", "cut:0.055", "body:320", "tight"),
        "confetti": ("a small soft puff of warm air through a few leaves, light, rising and fading, short", 0.8, -17, BREEZE, "warm:1200", "steep", "ease:0.04", "body:320"),
        "burp":     ("one soft short note on a kalimba, muffled and kind", 0.6, -14, COZY_TUNE, "warm:2400", "ease:0.01", "body:300", "notes:0:5", "cut:0.45"),
        "love":     ("one soft short note on a kalimba, muffled and kind", 0.6, -13, COZY_TUNE, "warm:2400", "ease:0.01", "body:300", "notes:0.1:5,5,8", "cut:0.6"),
        "ladybug":  ("one soft short note on a kalimba, round and kind", 0.6, -15, COZY_TUNE, "warm:2400", "ease:0.01", "body:300", "notes:0.1:4,9,7", "cut:0.6"),
        "hungry":   ("one soft short note on a kalimba, round and kind", 0.6, -14, COZY_TUNE, "warm:2200", "ease:0.01", "body:300", "notes:0.16:4,4", "cut:0.6"),
        "strand":   ("a soft worried 'uh-oh', two kalimba notes with a gentle wobble bending down, warm and muffled, never a buzzer, short", 0.6, -12, CLOVER),
        "heart_lost":    ("a soft gentle kalimba two-note fall, a small sad 'oh', a delicate note dropping, warm and muffled, never a buzzer", 0.6, -15, CLOVER),
        # The caterpillar scooting back a square: undo's take, one notch down.
        "slip":     ("one small light wooden button set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -16, HUSH, "warm:1300", "cut:0.12", "body:320", "tight", "notes:0:-2"),
        "out_of_hearts": ("one slow soft note on a kalimba, sleepy, calm and kind, left to fade", 1.6, -13, COZY_TUNE, "warm:2600", "ease:0.02", "body:300", "notes:0.32:10,7,4"),
        "heart_back":    ("a warm rising pair of soft kalimba plucks, a little heart coming back, gentle and happy", 0.6, -15, CLOVER),
        # The party. flutter: the butterflies taking off, a small puff of air.
        "stamp":    ("one soft note on a kalimba, proud and warm, left to fade", 1.5, -9, COZY_TUNE, "warm:2600", "ease:0.012", "body:300", "notes:0.26:9,5,12"),
        "party":    ("one soft note on a kalimba over a gentle tongue drum, warm and cozy, left to fade", 2.0, -8, COZY_TUNE, "warm:2600", "ease:0.012", "body:300", "notes:0.14:-1,3,6,3,6,8", "cut:1.9"),
        "purr":     ("one short soft contented chirrup, a little rolling trill with the mouth closed, gentle and happy", 1.0, -12, KITTEN, "warm:2400", "ease:0.01", "body:300"),
        "flutter":  ("a tiny quick puff of warm air, one light short breath that rises and fades, very short", 0.6, -16, BREEZE, "warm:900", "steep", "ease:0.04", "body:320"),
        # A row of the garden eaten clean: four quick quiet notes up. fill
        # (Insane, Peckish): the tummy topped up, two quiet notes up.
        "row":      ("one soft short note on a kalimba, muffled and kind", 0.6, -12, COZY_TUNE, "warm:2400", "ease:0.01", "body:300", "notes:0.07:3,5,7,10", "cut:0.7"),
        "fill":     ("one soft short note on a kalimba, round and kind", 0.6, -14, COZY_TUNE, "warm:2400", "ease:0.01", "body:300", "notes:0.1:5,9", "cut:0.45"),
    },
    # Sunbeam: drag a brass mirror or a copper cup along its wooden rail and
    # the light follows; wet every dewdrop, then the bud blooms. `step` fires
    # on every peg a drag crosses: the quietest notch there is, a wheel turned
    # under the finger (Fx2D's CUE_GAP keeps it from machine-gunning).
    "sunbeam": {
        # Redone 2026-10-10 against the cozy rules (docs/agents/sound.md), the
        # twentieth set of the redo. Kept from the polish's set, as they were:
        # dry, refuse, shy, wake, heart_lost and heart_back. Nothing new is
        # brass, glass, a chime, a music box, steam or a wing (brass and
        # glass ring, a glide and a flutter are scratch). A piece let go on
        # its peg is the thing a finger does all day, so `slide` is the
        # plainest: one tock, and no longer a glide. combo is a tick the
        # board pitches, not past five semitones, and the dew one quiet note
        # the board pitches by the drops lit, not past five either. Every
        # tick is `tight`. Borrowed takes: confetti is Binairo's and the cat
        # Untangle's kitten, of the same prompts; step, undo and stir are
        # lift's, drop and enter slide's, rainbow, love, flutter and chorus
        # the dew's. The phrases' steps are set by each take's own note, so
        # that every note lands between 400 and 700 Hz, and no two phrases
        # share a contour. A lift is a lighter thing set down.
        "lift":     ("one small light wooden button set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -16, HUSH, "warm:1400", "cut:0.12", "body:320", "tight"),
        "step":     ("one small light wooden button set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -19, HUSH, "warm:1300", "cut:0.06", "body:320", "tight", "notes:0:-1"),
        "slide":    ("one small wooden peg set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -14, HUSH, "warm:1600", "cut:0.16", "body:320", "tight"),
        # Put back where it was lifted: slide's take, lower and quieter.
        "drop":     ("one small wooden peg set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -17, HUSH, "warm:1400", "cut:0.14", "body:320", "tight", "notes:0:-2"),
        "dew":      ("one soft short note on a kalimba, muffled and kind", 0.6, -13, COZY_TUNE, "warm:2400", "ease:0.01", "body:300", "notes:0:7", "cut:0.4"),
        "dry":      ("a soft gentle two-note kalimba falling, a kind 'not yet', warm and patient, short", 0.6, -12, GLASSHOUSE),
        "refuse":   ("a tiny soft kalimba note with a gentle little wobble and a muffled felt tap, a kind 'not that one', warm, very short", 0.5, -12, GLASSHOUSE),
        "undo":     ("one small light wooden button set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1200", "cut:0.28", "body:320", "tight", "notes:0.11:0,-3"),
        "hint":     ("one soft note on a kalimba, a gentle little idea, short", 1.0, -10, COZY_TUNE, "warm:2000", "steep", "ease:0.012", "body:300", "notes:0.16:-2,1,5", "cut:0.9"),
        "reset":    ("a soft gust of warm breeze through a few leaves, one gentle whoosh of air that rises and fades, short", 0.8, -16, BREEZE, "warm:1100", "steep", "ease:0.06", "body:320"),
        "solved":   ("one soft note on a kalimba over a gentle tongue drum, warm, left to fade", 2.0, -8, COZY_TUNE, "warm:2000", "ease:0.012", "body:300", "notes:0.14:4,6,9,11,13", "cut:1.7"),
        # The mirrors set on their pegs: slide's take, five in a row.
        "enter":    ("one small wooden peg set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -14, HUSH, "warm:1600", "cut:0.5", "body:320", "tight", "notes:0.08:0,3,0,2,5"),
        # The polish's cues. stir: a snail under the light, one low light
        # notch (it fires mid-drag). sizzle: a drop dried, a small puff of
        # air. slip: the piece gone home along its rail, a short breath.
        "stir":     ("one small light wooden button set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -17, HUSH, "warm:1200", "cut:0.12", "body:320", "tight", "notes:0:-3"),
        "shy":      ("a tiny shy nervous glass twinkle trembling, a dewdrop blushing, a soft quivering music box note, cute, very short", 0.5, -15, GLASSHOUSE),
        "wake":     ("a little snail startled awake, a cute soft surprised 'oh!' squeak made of two quick rising kalimba notes, gentle, never a buzzer, short", 0.6, -12, GLASSHOUSE),
        "sizzle":   ("a tiny quick puff of warm air, one light short breath that rises and fades, very short", 0.6, -16, BREEZE, "warm:900", "steep", "ease:0.04", "body:320"),
        "heart_lost":    ("a soft gentle kalimba two-note fall, a small sad 'oh', a delicate note dropping, warm and muffled, never a buzzer", 0.6, -15, GLASSHOUSE),
        "slip":     ("a soft breath of warm breeze that eases, fades and stops, calm, short", 0.8, -17, BREEZE, "warm:900", "steep", "ease:0.05", "body:320"),
        "out_of_hearts": ("one slow soft note on a kalimba, sleepy, calm and kind, left to fade", 1.6, -13, COZY_TUNE, "warm:2600", "ease:0.02", "body:300", "notes:0.32:14,11,9"),
        "heart_back":    ("a warm rising pair of soft kalimba plucks, a little heart coming back, gentle and happy", 0.6, -15, GLASSHOUSE),
        # The streak and the gags. combo: a tick the board pitches by the
        # streak. rainbow: four quick quiet notes, up and over. flutter: two
        # quiet notes up, the butterfly. chorus: every drop at once, three
        # notes all but together.
        "combo":    ("one small wooden block set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -14, HUSH, "warm:1600", "cut:0.1", "body:320", "tight"),
        "confetti": ("a small soft puff of warm air through a few leaves, light, rising and fading, short", 0.8, -17, BREEZE, "warm:1200", "steep", "ease:0.04", "body:320"),
        "rainbow":  ("one soft short note on a kalimba, muffled and kind", 0.6, -13, COZY_TUNE, "warm:2400", "ease:0.01", "body:300", "notes:0.09:6,9,13,9", "cut:0.8"),
        "love":     ("one soft short note on a kalimba, muffled and kind", 0.6, -13, COZY_TUNE, "warm:2400", "ease:0.01", "body:300", "notes:0.1:7,7,10", "cut:0.6"),
        "flutter":  ("one soft short note on a kalimba, muffled and kind", 0.6, -15, COZY_TUNE, "warm:2400", "ease:0.01", "body:300", "notes:0.09:9,11", "cut:0.4"),
        "chorus":   ("one soft short note on a kalimba, muffled and kind", 0.6, -11, COZY_TUNE, "warm:2400", "ease:0.01", "body:300", "notes:0.04:6,10,13", "cut:0.9"),
        # The party.
        "stamp":    ("one soft note on a kalimba, proud and warm, left to fade", 1.5, -9, COZY_TUNE, "warm:2600", "ease:0.012", "body:300", "notes:0.26:3,-1,6"),
        "party":    ("one soft note on a kalimba over a gentle tongue drum, warm and cozy, left to fade", 2.0, -8, COZY_TUNE, "warm:2600", "ease:0.012", "body:300", "notes:0.14:4,8,11,8,11,13", "cut:1.9"),
        "purr":     ("one short soft contented chirrup, a little rolling trill with the mouth closed, gentle and happy", 1.0, -12, KITTEN, "warm:2400", "ease:0.01", "body:300"),
    },
    # Knight: a cream knight hops in Ls to take the rose king; rose knights
    # answer every hop. A catch slides the board back one move.
    "knight": {
        # Redone 2026-10-10 against the cozy rules (docs/agents/sound.md), the
        # twenty-first set of the redo, with Sunbeam's above. Kept from the
        # polish's set, as they were: caught, refuse, hint, stuck, boxed,
        # heart_lost and heart_back. Nothing new is paper, a bonk, a boing, a
        # leaf, a snore, a music box, a party blower or a pony (a rustle is
        # scratch, the bonk sat at 2.7 kHz). A hop is the thing a finger does
        # all day, so `hop` is the plainest: one tock. combo is a tick the
        # board pitches, not past five semitones. Every tick is `tight`.
        # Borrowed takes: confetti is Binairo's and the cat Untangle's
        # kitten, of the same prompts; take and enter are hop's, undo and
        # the bramble answer's, love, flutter and the crown the nap's. The
        # phrases' steps are set by each take's own note, so that every note
        # lands between 400 and 700 Hz, and no two phrases share a contour.
        # What travels is air: the slide back, the somersault and the
        # brambles withering are a breath of breeze each.
        "hop":      ("one small wooden pawn set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -14, HUSH, "warm:1600", "cut:0.16", "body:320", "tight"),
        "answer":   ("one small light wooden button set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -16, HUSH, "warm:1300", "cut:0.12", "body:320", "tight", "notes:0:-2"),
        # A rose knight taken: hop's take, two notches, the second up.
        "take":     ("one small wooden pawn set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -13, HUSH, "warm:1600", "cut:0.24", "body:320", "tight", "notes:0.08:0,3"),
        "caught":   ("a soft gentle two-note kalimba falling, a kind 'oops, caught', warm and patient, never a buzzer, short", 0.6, -12, PADDOCK),
        "slide":    ("a soft breath of warm breeze that eases, fades and stops, calm, short", 0.8, -17, BREEZE, "warm:900", "steep", "ease:0.05", "body:320"),
        "refuse":   ("a tiny soft kalimba note with a gentle little wobble and a muffled felt tap, a kind 'not that one', very short", 0.5, -13, PADDOCK),
        "undo":     ("one small light wooden button set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1200", "cut:0.28", "body:320", "tight", "notes:0.11:0,-3"),
        "hint":     ("a gentle magical sparkle, three soft music box notes rising with a warm kalimba underneath, cozy and kind", 1.0, -8, PADDOCK),
        "reset":    ("a soft gust of warm breeze through a few leaves, one gentle whoosh of air that rises and fades, short", 0.8, -16, BREEZE, "warm:1100", "steep", "ease:0.06", "body:320"),
        "solved":   ("one soft note on a kalimba over a gentle tongue drum, warm, left to fade", 2.0, -8, COZY_TUNE, "warm:2000", "ease:0.012", "body:300", "notes:0.14:4,7,9,11,13", "cut:1.7"),
        # The pieces set on the board: hop's take, five in a row.
        "enter":    ("one small wooden pawn set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -14, HUSH, "warm:1600", "cut:0.5", "body:320", "tight", "notes:0.08:0,3,0,2,5"),
        # The somersault: a small puff of air.
        "flip":     ("a tiny quick puff of warm air, one light short breath that rises and fades, very short", 0.6, -16, BREEZE, "warm:900", "steep", "ease:0.04", "body:320"),
        # Brambles (Insane). bramble: one sprung up, a light notch. nap: a
        # knight fenced in dozing off, two quiet notes down. wither: a long
        # breath easing.
        "bramble":  ("one small light wooden button set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -17, HUSH, "warm:1400", "cut:0.12", "body:320", "tight", "notes:0:2"),
        "nap":      ("one soft short note on a kalimba, muffled and kind", 0.6, -14, COZY_TUNE, "warm:2200", "ease:0.01", "body:300", "notes:0.2:8,5", "cut:0.7"),
        "stuck":    ("a soft gentle three-note kalimba falling, a kind 'no way through from here', warm and calm, never a buzzer", 0.9, -13, PADDOCK),
        "boxed":    ("a soft worried little kalimba wobble with a leafy thorny rustle closing in, gentle, 'oh no, boxed in', never harsh, short", 0.8, -12, PADDOCK),
        "wither":   ("a long soft breath of warm breeze that eases, fades and stops, calm", 1.0, -17, BREEZE, "warm:900", "steep", "ease:0.1", "body:320"),
        "heart_lost":    ("a soft gentle kalimba two-note fall, a small sad 'oh', a delicate note dropping, warm and muffled, never a buzzer", 0.6, -15, PADDOCK),
        "out_of_hearts": ("one slow soft note on a kalimba, sleepy, calm and kind, left to fade", 1.6, -13, COZY_TUNE, "warm:2600", "ease:0.02", "body:300", "notes:0.32:11,8,4"),
        "heart_back":    ("a warm rising pair of soft kalimba plucks, a little heart coming back, gentle and happy", 0.6, -15, PADDOCK),
        # The streak and the gags. combo: a tick the board pitches by the
        # streak. flutter: two quiet notes up, the butterfly. crown: two
        # slow notes, the second a fifth up.
        "combo":    ("one small wooden block set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -14, HUSH, "warm:1600", "cut:0.1", "body:320", "tight"),
        "confetti": ("a small soft puff of warm air through a few leaves, light, rising and fading, short", 0.8, -17, BREEZE, "warm:1200", "steep", "ease:0.04", "body:320"),
        "love":     ("one soft short note on a kalimba, muffled and kind", 0.6, -13, COZY_TUNE, "warm:2400", "ease:0.01", "body:300", "notes:0.1:5,5,8", "cut:0.6"),
        "flutter":  ("one soft short note on a kalimba, muffled and kind", 0.6, -15, COZY_TUNE, "warm:2400", "ease:0.01", "body:300", "notes:0.09:7,9", "cut:0.4"),
        "crown":    ("one soft short note on a kalimba, muffled and kind", 0.6, -11, COZY_TUNE, "warm:2400", "ease:0.01", "body:300", "notes:0.22:3,10", "cut:0.9"),
        # The party.
        "stamp":    ("one soft note on a kalimba, proud and warm, left to fade", 1.5, -9, COZY_TUNE, "warm:2600", "ease:0.012", "body:300", "notes:0.26:8,4,11"),
        "party":    ("one soft note on a kalimba over a gentle tongue drum, warm and cozy, left to fade", 2.0, -8, COZY_TUNE, "warm:2600", "steep", "ease:0.012", "body:300", "notes:0.14:8,12,15,12,15,17", "cut:1.9"),
        "purr":     ("one short soft contented chirrup, a little rolling trill with the mouth closed, gentle and happy", 1.0, -12, KITTEN, "warm:2400", "ease:0.01", "body:300"),
    },
    # Snooker (Versus, versus/snooker_screen.gd). Redone 2026-10-10 against
    # the cozy rules (docs/agents/sound.md), the twenty-second set of the
    # redo, with air hockey's below. Kept from the first set: foul as it was
    # and lose, 4 dB down. Nothing new is resin, leather, rubber, a marimba
    # or a glockenspiel: the table's own sounds were a click at 2.5 kHz and
    # two thumps under 300 Hz. `clack` plays for every contact and `cushion`
    # for every rail, pitched by speed (not past five semitones) and levelled
    # by `_hit_db`, so they are the plainest: one tock each, `tight`.
    # Borrowed takes: cushion and pot are clack's. `roll` is a loop whose
    # level follows the balls: what travels is air, a steady breath (a
    # loop's take is also read in 0.3 s steps: one that swells or dips
    # pulses every three seconds, and the measure does not see it).
    "snooker": {
        "strike":   ("one small wooden peg set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -13, HUSH, "warm:1600", "cut:0.14", "body:320", "tight"),
        "clack":    ("one small wooden ball set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -13, HUSH, "warm:1500", "cut:0.1", "body:320", "tight"),
        # A rail: clack's take, three steps down and duller.
        "cushion":  ("one small wooden ball set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -14, HUSH, "warm:1200", "cut:0.14", "body:320", "tight", "notes:0:-3"),
        # A ball down: clack's take, two notches, the second four steps up.
        "pot":      ("one small wooden ball set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -13, HUSH, "warm:1500", "cut:0.26", "body:320", "tight", "notes:0.1:0,4"),
        "roll":     ("a continuous steady soft warm breath of air moving, smooth, constant and even, no gusts", 3.0, -15, BREEZE, "loop", "warm:1000", "steep", "body:320"),
        "foul":     ("a soft gentle two-note downward kalimba, not yet, never a buzzer", 0.6, -9),
        "hint":     ("one soft note on a kalimba, gentle and kind, left to fade", 1.0, -10, COZY_TUNE, "warm:2400", "ease:0.012", "body:300", "notes:0.16:-3,0,4", "cut:1.0"),
        "win":      ("one soft note on a kalimba over a gentle tongue drum, warm, left to fade", 2.0, -8, COZY_TUNE, "warm:2000", "steep", "ease:0.012", "body:300", "notes:0.14:8,10,12,15,17", "cut:1.7"),
        "lose":     ("a soft warm three-note descending marimba, gentle and kind, good game", 1.4, -10),
    },
    # Air hockey (Versus, versus/hockey_screen.gd). Redone 2026-10-10 against
    # the cozy rules, the twenty-third set of the redo. Kept from the first
    # set: lose, 4 dB down. Nothing new is plastic, a clunk, a music box or
    # a hand bell. A mallet on the puck and the puck on a rail fire many
    # times a second, so each is one low tock that never rings (`strike`,
    # `wall` and `post` are pitched, not past five semitones, and levelled by
    # how hard the contact was), `tight`. Borrowed takes: serve is strike's,
    # post wall's, conceded goal's, glide Snooker's roll. `glide` is the puck on its cushion of
    # air, a loop whose level follows the puck's speed: a steady breath, no
    # hiss. With two players on one phone every goal plays `goal` and the
    # end plays `win`.
    "hockey": {
        "strike":   ("one small round wooden block set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -13, HUSH, "warm:1600", "cut:0.1", "body:320", "tight"),
        "wall":     ("one small light wooden button set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -14, HUSH, "warm:1400", "cut:0.1", "body:320", "tight"),
        # A goal's corner: wall's take, three steps down.
        "post":     ("one small light wooden button set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -13, HUSH, "warm:1200", "cut:0.16", "body:320", "tight", "notes:0:-3"),
        "glide":    ("a continuous steady soft warm breath of air moving, smooth, constant and even, no gusts", 3.0, -14, BREEZE, "loop", "warm:900", "steep", "body:320"),
        # The puck set down: strike's take, two steps down.
        "serve":    ("one small round wooden block set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1300", "cut:0.1", "body:320", "tight", "notes:0:-2"),
        "goal":     ("one soft short note on a kalimba, muffled and kind", 0.6, -9, COZY_TUNE, "warm:2400", "ease:0.01", "body:300", "notes:0.12:3,8", "cut:0.7"),
        "conceded": ("one soft short note on a kalimba, muffled and kind", 0.6, -12, COZY_TUNE, "warm:2400", "ease:0.01", "body:300", "notes:0.18:7,3", "cut:0.7"),
        "win":      ("one soft note on a kalimba over a gentle tongue drum, warm and cozy, left to fade", 2.0, -8, COZY_TUNE, "warm:2400", "steep", "ease:0.012", "body:300", "notes:0.14:8,12,15,12,15,17", "cut:1.9"),
        "lose":     ("a soft warm three-note descending kalimba, gentle and kind, good game", 1.4, -10, ARCADE),
    },
    # Chess (Versus, versus/chess_screen.gd). Redone 2026-10-10 against the
    # cozy rules (docs/agents/sound.md), the twenty-fourth set of the redo,
    # with checkers' below. Kept from the first set: lose, 4 dB down. Nothing
    # new is a scrape, a swish, a clack, a tumble, a boing, a bonk, a marimba
    # or a glockenspiel. A piece chosen and a piece set down are what a hand
    # does all game, so `lift` and `place` are the plainest: one tock each,
    # the lift a lighter thing (a lift asked for as a lift comes back a
    # thump or a hiss), `tight`. Borrowed takes: capture, castle and enter
    # are place's, refused lift's, promote and draw check's. What travels is
    # air: a rook, bishop or queen setting off and a move taken back are a
    # breath of breeze, the knight's leap a small puff. The phrases' steps
    # are set by each take's own note, so that every note lands between 400
    # and 700 Hz, and no two phrases share a contour.
    "chess": {
        "lift":     ("one small light wooden button set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -16, HUSH, "warm:1300", "cut:0.12", "body:320", "tight"),
        "place":    ("one small wooden pawn set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -13, HUSH, "warm:1600", "cut:0.14", "body:320", "tight"),
        "slide":    ("a soft breath of warm breeze that eases, fades and stops, calm, short", 0.8, -17, BREEZE, "warm:900", "steep", "ease:0.05", "body:320"),
        # A piece taken: place's take, two notches, the second four steps up.
        "capture":  ("one small wooden pawn set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -12, HUSH, "warm:1600", "cut:0.24", "body:320", "tight", "notes:0.08:0,4"),
        # King and rook: place's take, two notches alike.
        "castle":   ("one small wooden pawn set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -13, HUSH, "warm:1600", "cut:0.3", "body:320", "tight", "notes:0.13:0,0"),
        # The knight's leap: a small puff of air.
        "hop":      ("a tiny quick puff of warm air, one light short breath that rises and fades, very short", 0.6, -16, BREEZE, "warm:900", "steep", "ease:0.04", "body:320"),
        "check":    ("one soft short note on a kalimba, muffled and kind", 0.6, -10, COZY_TUNE, "warm:2400", "ease:0.01", "body:300", "notes:0.16:5,7", "cut:0.7"),
        "promote":  ("one soft short note on a kalimba, muffled and kind", 0.6, -9, COZY_TUNE, "warm:2400", "ease:0.01", "body:300", "notes:0.11:4,7,11,7", "cut:0.9"),
        # Not that square: lift's take, twice and falling.
        "refused":  ("one small light wooden button set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1200", "cut:0.28", "body:320", "tight", "notes:0.11:0,-3"),
        "hint":     ("one soft note on a kalimba, gentle and kind, left to fade", 1.0, -10, COZY_TUNE, "warm:2400", "ease:0.012", "body:300", "notes:0.16:0,2,5", "cut:1.0"),
        # The pieces set out: place's take, five in a row.
        "enter":    ("one small wooden pawn set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -14, HUSH, "warm:1600", "cut:0.5", "body:320", "tight", "notes:0.08:0,3,0,2,5"),
        "win":      ("one soft note on a kalimba over a gentle tongue drum, warm, left to fade", 2.0, -8, COZY_TUNE, "warm:2000", "steep", "ease:0.012", "body:300", "notes:0.14:4,5,7,9,12", "cut:1.7"),
        "lose":     ("a soft warm three-note descending marimba, gentle and kind, good game", 1.4, -10),
        "draw":     ("one soft short note on a kalimba, muffled and kind", 0.6, -10, COZY_TUNE, "warm:2400", "ease:0.01", "body:300", "notes:0.24:5,5", "cut:0.8"),
    },
    # Checkers (Versus, versus/checkers_screen.gd). Redone 2026-10-10 against
    # the cozy rules, the twenty-fifth set of the redo. Kept from the first
    # set: lose and draw, 4 dB down. Nothing new is a scrape, a swish, a
    # clack, a coin's spin, a boing, a bonk or a glockenspiel.
    # `lift` and `place` are one tock each, the lift a lighter thing,
    # `tight`; the board pitches them down a chain of jumps, not past five
    # semitones. Borrowed takes: capture and enter are place's, flip and
    # refused lift's, slide and hop chess's, of the same prompts. `slide` (a king setting off, a move taken back) is a
    # breath of breeze, `hop` (a jump's take-off) a small puff, `flip` (a
    # losing piece turning face down, a dozen in a row) one light notch.
    "checkers": {
        "lift":     ("one small light flat wooden disc set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -16, HUSH, "warm:1300", "cut:0.12", "body:320", "tight"),
        "place":    ("one small flat round wooden disc set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -13, HUSH, "warm:1600", "cut:0.16", "body:320", "tight"),
        "slide":    ("a soft breath of warm breeze that eases, fades and stops, calm, short", 0.8, -17, BREEZE, "warm:900", "steep", "ease:0.05", "body:320"),
        "hop":      ("a tiny quick puff of warm air, one light short breath that rises and fades, very short", 0.6, -16, BREEZE, "warm:900", "steep", "ease:0.04", "body:320"),
        # A piece jumped: place's take, two notches, the second three steps down.
        "capture":  ("one small flat round wooden disc set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -12, HUSH, "warm:1600", "cut:0.24", "body:320", "tight", "notes:0.08:0,-3"),
        "crown":    ("one soft short note on a kalimba, muffled and kind", 0.6, -9, COZY_TUNE, "warm:2400", "ease:0.01", "body:300", "notes:0.11:6,9,13,9", "cut:0.9"),
        # A losing piece turned face down: lift's take, two steps down.
        "flip":     ("one small light flat wooden disc set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1200", "cut:0.12", "body:320", "tight", "notes:0:-2"),
        # Not that square: lift's take, twice and falling.
        "refused":  ("one small light flat wooden disc set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1200", "cut:0.28", "body:320", "tight", "notes:0.11:0,-3"),
        "hint":     ("one soft note on a kalimba, gentle and kind, left to fade", 1.0, -10, COZY_TUNE, "warm:2400", "ease:0.012", "body:300", "notes:0.16:4,7,9", "cut:1.0"),
        # The pieces dealt out: place's take, five in a row.
        "enter":    ("one small flat round wooden disc set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -14, HUSH, "warm:1600", "cut:0.5", "body:320", "tight", "notes:0.08:0,2,0,3,5"),
        "win":      ("one soft note on a kalimba over a gentle tongue drum, warm and cozy, left to fade", 2.0, -8, COZY_TUNE, "warm:2400", "steep", "ease:0.012", "body:300", "notes:0.14:4,7,9,7,9,12", "cut:1.9"),
        "lose":     ("a soft warm three-note descending marimba, gentle and kind, good game", 1.4, -10),
        "draw":     ("two soft even marimba notes, calm and balanced, a friendly handshake", 1.0, -10),
    },
    # Hedgehogs: rake autumn leaf piles off a lawn; hedgehogs sleep under
    # some. A wrong rake wakes one, grumpy -- two low notes, never a buzzer.
    "hedgehogs": {
        # Redone 2026-10-10 against the cozy rules (docs/agents/sound.md), the
        # twenty-sixth set of the redo, with Super Slider's below. Kept from
        # the polish's set, as they were: refuse, check, check_ok, hint,
        # enter, love, heart_lost and heart_back. Nothing new is a rake, a
        # leaf, a twig, a snuffle, a bell, a music box, a boink or a party
        # blower (a sweep and a rustle are scratch, a silver bell rings). A
        # rake is the thing a finger does all day, so `rake` is the plainest:
        # one tock. combo is a tick the board pitches, not past five
        # semitones. Every tick is `tight`. Borrowed takes: confetti is
        # Binairo's and the cat Untangle's kitten, of the same prompts; chord
        # is rake's, unflag, undo, snuffle and the acorn flag's, woke and
        # flutter the bell's. The phrases' steps are set by each take's own
        # note, so that every note lands between 400 and 700 Hz, and no two
        # phrases share a contour. What travels is air: a wide rake is a gust
        # and a lawn's worth a longer one.
        "rake":     ("one small wooden peg set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -14, HUSH, "warm:1600", "cut:0.16", "body:320", "tight"),
        "gust":     ("a tiny quick puff of warm air, one light short breath that rises and fades, very short", 0.6, -16, BREEZE, "warm:900", "steep", "ease:0.04", "body:320"),
        "flag":     ("one small light wooden button set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -16, HUSH, "warm:1400", "cut:0.12", "body:320", "tight"),
        # The twig pulled out: flag's take, two steps down.
        "unflag":   ("one small light wooden button set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -17, HUSH, "warm:1200", "cut:0.12", "body:320", "tight", "notes:0:-2"),
        # A hedgehog woken: the bell's take, two low notes alike, a small
        # "hmph" (heart_lost falls a quarter second behind it).
        "woke":     ("one soft short note on a kalimba, muffled and kind", 0.6, -12, COZY_TUNE, "warm:2200", "ease:0.01", "body:300", "notes:0.14:4,4", "cut:0.6"),
        # A number tapped to rake round it: rake's take, two notches.
        "chord":    ("one small wooden peg set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -14, HUSH, "warm:1600", "cut:0.24", "body:320", "tight", "notes:0.08:0,2"),
        "refuse":   ("a tiny soft kalimba note with a gentle little wobble and a muffled leaf rustle, a kind 'not that one', very short", 0.5, -14, HARVEST),
        "check":    ("a soft gentle two-note kalimba falling, a kind 'not yet', warm and patient", 0.6, -12, HARVEST),
        "check_ok": ("three soft warm kalimba notes rising, bright and happy, 'all good'", 0.7, -10, HARVEST),
        "undo":     ("one small light wooden button set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1200", "cut:0.28", "body:320", "tight", "notes:0.11:0,-3"),
        "hint":     ("a gentle magical sparkle, three soft music box notes rising with a warm kalimba underneath, cozy and kind", 1.0, -9, HARVEST),
        "reset":    ("a soft breath of warm breeze that eases, fades and stops, calm, short", 0.8, -17, BREEZE, "warm:900", "steep", "ease:0.05", "body:320"),
        "solved":   ("one soft note on a kalimba over a gentle tongue drum, warm, left to fade", 2.0, -8, COZY_TUNE, "warm:2000", "ease:0.012", "body:300", "notes:0.14:4,6,9,11,13", "cut:1.7"),
        "enter":    ("a soft airy rustle of autumn leaves settling onto grass, with one warm low kalimba note", 1.0, -12, HARVEST),
        # Sleepwalkers (Insane). bell: the night's walk, one quiet note (it
        # was a silver bell). snuffle: the walker's steps, flag's take, three
        # slow notches.
        "bell":     ("one soft short note on a kalimba, muffled and kind", 0.6, -14, COZY_TUNE, "warm:2200", "ease:0.012", "body:300", "notes:0:7", "cut:0.6"),
        "snuffle":  ("one small light wooden button set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -17, HUSH, "warm:1200", "cut:0.4", "body:320", "tight", "notes:0.12:-2,0,-2"),
        "heart_lost":    ("a soft gentle kalimba two-note fall, a small sad 'oh', a delicate note dropping, warm and muffled, never a buzzer", 0.6, -15, HARVEST),
        "out_of_hearts": ("one slow soft note on a kalimba, sleepy, calm and kind, left to fade", 1.6, -13, COZY_TUNE, "warm:2600", "ease:0.02", "body:300", "notes:0.32:12,9,5"),
        "heart_back":    ("a warm rising pair of soft kalimba plucks, a little heart coming back, gentle and happy", 0.6, -15, HARVEST),
        # The streak and the gags. combo: a tick the board pitches by the
        # streak. flutter: two quiet notes up, the butterfly. acorn: flag's
        # take, a hop and two bounces. whoosh: a lawn's worth of leaves gone
        # at once, a longer breath than the gust.
        "combo":    ("one small wooden peg set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -14, HUSH, "warm:1600", "cut:0.1", "body:320", "tight"),
        "confetti": ("a small soft puff of warm air through a few leaves, light, rising and fading, short", 0.8, -17, BREEZE, "warm:1200", "steep", "ease:0.04", "body:320"),
        "love":     ("a tiny soft sweet bubbly pop with a little two-note music box 'aww', cute and warm, short", 0.7, -11, HARVEST),
        "flutter":  ("one soft short note on a kalimba, muffled and kind", 0.6, -15, COZY_TUNE, "warm:2400", "ease:0.01", "body:300", "notes:0.09:7,9", "cut:0.4"),
        "acorn":    ("one small light wooden button set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1400", "cut:0.42", "body:320", "tight", "notes:0.13:4,0,-1"),
        "whoosh":   ("a long soft gust of warm breeze through leaves, one gentle whoosh of air that rises slowly and fades", 1.0, -15, BREEZE, "warm:1100", "steep", "ease:0.1", "body:320"),
        # The party.
        "stamp":    ("one soft note on a kalimba, proud and warm, left to fade", 1.5, -9, COZY_TUNE, "warm:2600", "ease:0.012", "body:300", "notes:0.26:9,6,13"),
        "party":    ("one soft note on a kalimba over a gentle tongue drum, warm and cozy, left to fade", 2.0, -8, COZY_TUNE, "warm:2600", "ease:0.012", "body:300", "notes:0.14:4,8,11,8,11,13", "cut:1.9"),
        "purr":     ("one short soft contented chirrup, a little rolling trill with the mouth closed, gentle and happy", 1.0, -12, KITTEN, "warm:2400", "ease:0.01", "body:300"),
    },
    # Super Slider: painted wooden blocks slid round a walnut tray until the
    # big one walks out of a little garden gate.
    "slider": {
        # Redone 2026-10-10 against the cozy rules (docs/agents/sound.md), the
        # twenty-seventh set of the redo. Kept from the polish's set: hint,
        # huff and heart_lost as they were, heart_back rolled off, and bump
        # with its lead-in trimmed (its knock sat 0.13 s into the file).
        # Nothing new is a scrape, a hush over felt, a clack, a hinge, brass,
        # a music box or a party blower (a block slid came back between 1
        # and 3 kHz, fourteen cues of it). A block let go is the thing a finger does all day, so `slide`
        # is the plainest: one tock, and `step`, a cell under the finger, the
        # quietest there is. combo is a tick the board pitches, not past five
        # semitones. Every tick is `tight`. Borrowed takes: confetti is
        # Binairo's and the cat Untangle's kitten, of the same prompts; step,
        # undo and the latch are lift's, drop, enter and hop slide's, fret,
        # flutter and twirl love's. The phrases' steps are set by each take's
        # own note, so that every note lands between 400 and 700 Hz, and no
        # two phrases share a contour. What travels is air: a block sent home,
        # the tray dealt again and the gate swinging open are a breath of
        # breeze each. A lift is a lighter thing set down.
        "lift":     ("one small light wooden button set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -16, HUSH, "warm:1400", "cut:0.12", "body:320", "tight"),
        "step":     ("one small light wooden button set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -19, HUSH, "warm:1300", "cut:0.06", "body:320", "tight", "notes:0:-1"),
        "bump":     ("a solid hardwood toy block gently knocking against another wooden block, one soft dull hollow wooden knock, very short", 0.5, -13, WALNUT, "warm:7000", "cut:0.16", "tight"),
        "slide":    ("one small smooth wooden toy block set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -14, HUSH, "warm:1600", "cut:0.16", "body:320", "tight"),
        # Put back where it was lifted: slide's take, lower and quieter.
        "drop":     ("one small smooth wooden toy block set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -17, HUSH, "warm:1400", "cut:0.14", "body:320", "tight", "notes:0:-2"),
        "undo":     ("one small light wooden button set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1200", "cut:0.28", "body:320", "tight", "notes:0.11:0,-3"),
        "slip":     ("a soft breath of warm breeze that eases, fades and stops, calm, short", 0.8, -17, BREEZE, "warm:900", "steep", "ease:0.05", "body:320"),
        "reset":    ("a soft gust of warm breeze through a few leaves, one gentle whoosh of air that rises and fades, short", 0.8, -16, BREEZE, "warm:1100", "steep", "ease:0.06", "body:320"),
        # The blocks set in the tray: slide's take, five in a row.
        "enter":    ("one small smooth wooden toy block set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -14, HUSH, "warm:1600", "cut:0.5", "body:320", "tight", "notes:0.08:0,3,0,2,5"),
        # The win. gate: the gate swinging open, a long breath. hop: the big
        # block out over the stepping stones, slide's take two steps up (the
        # board pitches each stone a little higher). latch: one move from
        # home, lift's take, three quick notches.
        "gate":     ("a long soft breath of warm breeze that eases, fades and stops, calm", 1.0, -16, BREEZE, "warm:900", "steep", "ease:0.1", "body:320"),
        "hop":      ("one small smooth wooden toy block set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1600", "cut:0.12", "body:320", "tight", "notes:0:2"),
        "latch":    ("one small light wooden button set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1400", "cut:0.3", "body:320", "tight", "notes:0.07:0,2,0"),
        "hint":     ("three soft rising notes plucked on a real kalimba with a delicate music box sparkle, gentle and magical", 1.0, -10, WALNUT_TUNE),
        "solved":   ("one soft note on a kalimba over a gentle tongue drum, warm, left to fade", 2.0, -8, COZY_TUNE, "warm:2000", "ease:0.012", "body:300", "notes:0.14:4,7,9,11,13", "cut:1.7"),
        "fret":     ("one soft short note on a kalimba, muffled and kind", 0.6, -17, COZY_TUNE, "warm:2200", "ease:0.012", "body:300", "notes:0:-1", "cut:0.4"),
        "huff":     ("a tiny stubborn 'hmph' made of two quick soft low kalimba plucks and a muffled wooden knock, cute, very short", 0.5, -15, WALNUT_TUNE),
        "heart_lost":    ("a soft gentle kalimba two-note fall, a small sad 'oh', a delicate note dropping, warm and muffled, never a buzzer", 0.6, -15, WALNUT_TUNE),
        "out_of_hearts": ("one slow soft note on a kalimba, sleepy, calm and kind, left to fade", 1.6, -13, COZY_TUNE, "warm:2600", "ease:0.02", "body:300", "notes:0.32:10,7,5"),
        "heart_back":    ("a warm rising pair of soft kalimba plucks, a little heart coming back, gentle and happy", 0.6, -15, WALNUT_TUNE, "warm:2200", "body:300"),
        # The streak and the gags. combo: a tick the board pitches by the
        # streak. love: two quiet notes alike and a third up. flutter: two
        # quiet notes up, the butterfly. twirl: four quick ones, up and over.
        # fret (a drag that leads away from home): one low quiet note.
        "combo":    ("one small wooden peg set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -14, HUSH, "warm:1600", "cut:0.1", "body:320", "tight"),
        "confetti": ("a small soft puff of warm air through a few leaves, light, rising and fading, short", 0.8, -17, BREEZE, "warm:1200", "steep", "ease:0.04", "body:320"),
        "love":     ("one soft short note on a kalimba, muffled and kind", 0.6, -13, COZY_TUNE, "warm:2400", "ease:0.01", "body:300", "notes:0.1:2,2,5", "cut:0.6"),
        "flutter":  ("one soft short note on a kalimba, muffled and kind", 0.6, -15, COZY_TUNE, "warm:2400", "ease:0.01", "body:300", "notes:0.09:4,6", "cut:0.4"),
        "twirl":    ("one soft short note on a kalimba, muffled and kind", 0.6, -13, COZY_TUNE, "warm:2400", "ease:0.01", "body:300", "notes:0.09:0,3,7,3", "cut:0.8"),
        # The party.
        "stamp":    ("one soft note on a kalimba, proud and warm, left to fade", 1.5, -9, COZY_TUNE, "warm:2600", "ease:0.012", "body:300", "notes:0.26:8,4,11"),
        "party":    ("one soft note on a kalimba over a gentle tongue drum, warm and cozy, left to fade", 2.0, -8, COZY_TUNE, "warm:2600", "ease:0.012", "body:300", "notes:0.14:4,7,11,7,11,13", "cut:1.9"),
        "purr":     ("one short soft contented chirrup, a little rolling trill with the mouth closed, gentle and happy", 1.0, -12, KITTEN, "warm:2400", "ease:0.01", "body:300"),
    },
    # Marigold: the family's sun shoots a seed down through a pond garden of
    # flower buds; every bud it touches blooms with the next note of a rising
    # scale, the blooms are picked, and the last marigold is a full bloom.
    "marigold": {
        # Redone 2026-10-10 against the cozy rules (docs/agents/sound.md), the
        # twenty-eighth set of the redo, with Pixel Garden's below. Kept from
        # the polish's set: close, apart and shades as they were, heart_back
        # three steps up (its plucks sat at 361 Hz, -25 dB on a phone). Nothing new is a seed, clay,
        # water, a leaf, a frog, a duck, a drum, a music box, a hand bell or
        # a party blower (the shot, the plip and the garden growing back sat
        # near half above 3 kHz, the drumroll 98% under 300 Hz). `hit` is the
        # board's own sound, one muffled note a bloom, and the board pitches
        # it up a scale that stops at five semitones (it was a major scale up
        # nineteen), so its take is one clean note at 400 Hz or over. Every
        # tick is `tight`. Borrowed takes, of the same prompts: shoot is
        # Hedgehogs' gust, reset Super Slider's, the roll Snooker's, combo
        # Super Slider's, confetti Binairo's and the cat Untangle's kitten;
        # here pop, drain, splash and the frog are wall's or pop's, and
        # clover, violet, pot, free, hint, pair, out, heart_lost and the
        # ducks hit's. The phrases' steps are set by each take's own note,
        # so that every note lands between 400 and 700 Hz, and no two
        # phrases share a contour. What travels is air: the seed leaving the
        # sun is a small puff, the garden growing back a breath, and the
        # drumroll under a seed falling to its pot a loop of steady air.
        "shoot":    ("a tiny quick puff of warm air, one light short breath that rises and fades, very short", 0.6, -15, BREEZE, "warm:900", "steep", "ease:0.03", "body:320"),
        "hit":      ("one soft short note on a kalimba, muffled and kind", 0.6, -12, COZY_TUNE, "warm:2200", "ease:0.008", "body:300", "cut:0.5"),
        "wall":     ("one small wooden bead set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -17, HUSH, "warm:1500", "cut:0.1", "body:320", "tight"),
        # A lucky clover splitting the seed in two: two quick notes alike.
        "clover":   ("one soft short note on a kalimba, muffled and kind", 0.6, -12, COZY_TUNE, "warm:2400", "ease:0.01", "body:300", "notes:0.07:5,5", "cut:0.5"),
        # The violet, a special find: four quick notes, up and over.
        "violet":   ("one soft short note on a kalimba, muffled and kind", 0.6, -11, COZY_TUNE, "warm:2400", "ease:0.01", "body:300", "notes:0.09:0,4,7,4", "cut:0.8"),
        # A bloom picked: a lighter tick the board pitches up the scale.
        "pop":      ("one small light wooden button set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -16, HUSH, "warm:1400", "cut:0.07", "body:320", "tight"),
        # The seed in the pot: one note, a fifth over a bloom's.
        "pot":      ("one soft short note on a kalimba, muffled and kind", 0.6, -10, COZY_TUNE, "warm:2400", "ease:0.01", "body:300", "notes:0:7", "cut:0.6"),
        # A seed earned (the board pitches it by the shot's word): two notes
        # alike and a third up.
        "free":     ("one soft short note on a kalimba, muffled and kind", 0.6, -10, COZY_TUNE, "warm:2400", "ease:0.01", "body:300", "notes:0.1:0,0,3", "cut:0.7"),
        # The seed in the pond: pop's take, three steps down.
        "drain":    ("one small light wooden button set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -16, HUSH, "warm:1200", "cut:0.07", "body:320", "tight", "notes:0:-3"),
        "fever":    ("one soft note on a kalimba over a gentle tongue drum, warm and bright-hearted, left to fade", 2.0, -8, COZY_TUNE, "warm:2600", "ease:0.012", "body:300", "notes:0.1:2,4,6,7,9,11", "cut:1.6"),
        "roll":     ("a continuous steady soft warm breath of air moving, smooth, constant and even, no gusts", 3.0, -15, BREEZE, "loop", "warm:900", "steep", "body:320"),
        "close":    ("a soft playful disappointed 'awww' of two kalimba notes bending down with a little wooden wobble, a near miss, funny and kind, never sad", 0.9, -10, POND_TUNE, "warm:7000"),
        # The last seed in the pot: fever's take, down, and up past where it began.
        "fever_pot":("one soft note on a kalimba over a gentle tongue drum, warm and bright-hearted, left to fade", 2.0, -8, COZY_TUNE, "warm:2600", "ease:0.012", "body:300", "notes:0.11:9,6,2,6,11", "cut:1.5"),
        "out":      ("one soft short note on a kalimba, muffled and kind", 0.6, -12, COZY_TUNE, "warm:2200", "ease:0.012", "body:300", "notes:0.2:5,0", "cut:0.8"),
        "hint":     ("one soft short note on a kalimba, muffled and kind", 0.6, -10, COZY_TUNE, "warm:2400", "ease:0.012", "body:300", "notes:0.16:0,4,8", "cut:0.9"),
        "reset":    ("a soft gust of warm breeze through a few leaves, one gentle whoosh of air that rises and fades, short", 0.8, -16, BREEZE, "warm:1100", "steep", "ease:0.06", "body:320"),
        "solved":   ("one soft note on a kalimba over a gentle tongue drum, warm, left to fade", 2.0, -8, COZY_TUNE, "warm:2000", "ease:0.012", "body:300", "notes:0.14:4,7,9,11,13", "cut:1.7"),
        # The garden set out: wall's take, five in a row.
        "enter":    ("one small wooden bead set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -14, HUSH, "warm:1600", "cut:0.5", "body:320", "tight", "notes:0.08:0,3,0,2,5"),
        # A heart lost: one low quiet note.
        "heart_lost":    ("one soft short note on a kalimba, muffled and kind", 0.6, -14, COZY_TUNE, "warm:2200", "ease:0.012", "body:300", "notes:0:-1", "cut:0.45"),
        "out_of_hearts": ("one slow soft note on a kalimba, sleepy, calm and kind, left to fade", 1.6, -13, COZY_TUNE, "warm:2600", "ease:0.02", "body:300", "notes:0.32:11,8,4"),
        "heart_back":    ("a warm rising pair of soft kalimba plucks, a little heart coming back, gentle and happy", 0.6, -13, POND_TUNE, "warm:2200", "body:300", "notes:0:3"),
        # Sweethearts (Insane). pair: two notes a third apart, all but
        # together (the board pitches it by the pairs of the shot). apart: a
        # flower closing up, kept.
        "pair":     ("one soft short note on a kalimba, muffled and kind", 0.6, -12, COZY_TUNE, "warm:2400", "ease:0.01", "body:300", "notes:0.03:0,3", "cut:0.6"),
        "apart":    ("a soft sad little slide down on a kalimba with a tiny wooden wobble, a flower closing up, gentle and a bit funny, never harsh", 0.8, -12, POND_TUNE, "warm:7000"),
        # The streak and the gags. combo: a tick the board pitches by the
        # streak. ribbit: the frog, wall's take, two low notches. splash: the
        # frog back on its pad, pop's take, one notch two steps down. quack:
        # the ducks crossing, two low notes and three small ones above them.
        "combo":    ("one small wooden peg set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -14, HUSH, "warm:1600", "cut:0.1", "body:320", "tight"),
        "confetti": ("a small soft puff of warm air through a few leaves, light, rising and fading, short", 0.8, -17, BREEZE, "warm:1200", "steep", "ease:0.04", "body:320"),
        "ribbit":   ("one small wooden bead set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -14, HUSH, "warm:1300", "cut:0.26", "body:320", "tight", "notes:0.09:-2,-2"),
        "splash":   ("one small light wooden button set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -16, HUSH, "warm:1200", "cut:0.07", "body:320", "tight", "notes:0:-2"),
        "quack":    ("one soft short note on a kalimba, muffled and kind", 0.6, -13, COZY_TUNE, "warm:2400", "ease:0.01", "body:300", "notes:0.13:0,0,7,7,7", "cut:1.0"),
        "shades":   ("a playful cool little slide up on a kalimba ending in a tiny bright music box 'ting', something putting on sunglasses, funny and cute, short", 0.7, -9, POND_TUNE, "warm:7000"),
        # The party.
        "stamp":    ("one soft note on a kalimba, proud and warm, left to fade", 1.5, -9, COZY_TUNE, "warm:2600", "ease:0.012", "body:300", "notes:0.26:8,4,11"),
        "party":    ("one soft note on a kalimba over a gentle tongue drum, warm and cozy, left to fade", 2.0, -8, COZY_TUNE, "warm:2600", "ease:0.012", "body:300", "notes:0.14:0,3,7,3,7,8", "cut:1.9"),
        "purr":     ("one short soft contented chirrup, a little rolling trill with the mouth closed, gentle and happy", 1.0, -12, KITTEN, "warm:2400", "ease:0.01", "body:300"),
        # 2026-10-05: the three instruments of the full bloom's tune, one note
        # each. tools/gen_marigold_music.py plays them at pitch into music.ogg
        # (the tune has to be exact, so it is sequenced, never prompted); the
        # board itself never cues them.
        "note_kalimba": ("one single clear note plucked once on a real kalimba and left to ring out, only one note, nothing else", 1.5, -6, POND_TUNE, "warm:7000"),
        "note_box":     ("one single bright delicate note plucked once on the comb of a real wooden music box and left to ring out, only one note, nothing else", 1.5, -6, POND_TUNE, "warm:7000"),
        "note_low":     ("one single low warm round note plucked once on a real bass kalimba and left to ring out, deep and soft, only one note, nothing else", 1.5, -6, POND_TUNE, "warm:7000"),
    },
    # Pixel Garden: copy a little picture onto a pegboard in beads; a full
    # plate is ironed. `place` fires on every bead a stroke seats (pitched a
    # hair apart), so it is the plainest and one of the quietest.
    "pixelgarden": {
        # Redone 2026-10-10 against the cozy rules (docs/agents/sound.md), the
        # twenty-ninth set of the redo, with Marigold's above. Kept from the
        # polish's set: check, check_ok, plate, heart_back and confetti as
        # they were, hint, solved and party rolled off (the last two at -8,
        # they were -5 and -6), heart_lost 3 dB down. Nothing new is plastic,
        # steel tweezers, a box of beads, paper, an iron, steam, a wing, a
        # music box or a rubber stamp (ten cues sat 86 to 98% above 3 kHz,
        # the bead on every peg among them). A bead is a small wooden one
        # set down on felt now. combo is a tick the board pitches, not past
        # five semitones. Every tick is `tight`. Borrowed takes, of the same
        # prompts: reset is Super Slider's and the iron its gate, steam and
        # the butterfly Hedgehogs' gust, peek and confetti's like Binairo's
        # puff, combo Super Slider's, the cat Untangle's kitten; here enter,
        # astray and steady are place's, and pick, refuse and undo lift's.
        # The phrases' steps are set by each take's own note, so that every
        # note lands between 400 and 700 Hz. What travels is air: the
        # pattern card lifted, the beads poured back, the iron and its steam
        # are a breath or a puff each. A lift is a lighter thing set down.
        "place":    ("one small wooden bead set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -16, HUSH, "warm:1500", "cut:0.09", "body:320", "tight"),
        "lift":     ("one small light wooden button set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -17, HUSH, "warm:1300", "cut:0.09", "body:320", "tight"),
        # A colour picked from the box: lift's take, two steps up.
        "pick":     ("one small light wooden button set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1400", "cut:0.1", "body:320", "tight", "notes:0:2"),
        "peek":     ("a small soft puff of warm air through a few leaves, light, rising and fading, short", 0.8, -17, BREEZE, "warm:1200", "steep", "ease:0.04", "body:320"),
        # An empty compartment: lift's take, two low notches alike.
        "refuse":   ("one small light wooden button set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1200", "cut:0.26", "body:320", "tight", "notes:0.1:-3,-3"),
        "undo":     ("one small light wooden button set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1200", "cut:0.28", "body:320", "tight", "notes:0.11:0,-3"),
        "hint":     ("a gentle sparkle, three soft kalimba notes rising with a tiny hand bell on top, kind and helpful", 1.0, -9, BEADBOX_TUNE, "warm:2400", "body:300"),
        "check":    ("a soft two-note downward kalimba, gentle, kind, not yet", 0.6, -10, BEADBOX_TUNE, "warm:7000"),
        "check_ok": ("a soft bright three-note rising kalimba, all good", 0.7, -9, BEADBOX_TUNE, "warm:7000"),
        "reset":    ("a soft gust of warm breeze through a few leaves, one gentle whoosh of air that rises and fades, short", 0.8, -16, BREEZE, "warm:1100", "steep", "ease:0.06", "body:320"),
        # The beads set in the box: place's take, five in a row.
        "enter":    ("one small wooden bead set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -14, HUSH, "warm:1600", "cut:0.5", "body:320", "tight", "notes:0.08:0,3,0,2,5"),
        # The iron over a full plate: a long breath. steam: a small puff.
        "iron":     ("a long soft breath of warm breeze that eases, fades and stops, calm", 1.0, -15, BREEZE, "warm:900", "steep", "ease:0.1", "body:320"),
        "steam":    ("a tiny quick puff of warm air, one light short breath that rises and fades, very short", 0.6, -17, BREEZE, "warm:900", "steep", "ease:0.04", "body:320"),
        "plate":    ("a small happy flourish, four soft kalimba notes rising with a tiny music box sparkle on top, a little square of bead art finished, proud and cute", 1.2, -8, BEADBOX_TUNE, "warm:7000"),
        # A plate ironed wrong, its beads hopping off: place's take, three
        # notches down.
        "astray":   ("one small wooden bead set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1400", "cut:0.4", "body:320", "tight", "notes:0.1:0,-2,-4"),
        "heart_lost": ("a soft sad little two-note kalimba falling, gentle and kind, not scolding", 0.9, -12, BEADBOX_TUNE, "warm:7000"),
        "out_of_hearts": ("one slow soft note on a kalimba, sleepy, calm and kind, left to fade", 1.6, -13, COZY_TUNE, "warm:2600", "ease:0.02", "body:300", "notes:0.32:7,4,0"),
        "heart_back": ("a warm hopeful rising kalimba phrase with a small hand bell, a heart coming back, gentle and happy", 1.0, -10, BEADBOX_TUNE, "warm:7000"),
        # The streak: a tick the board pitches by the plates ironed right in
        # a row. steady: a tidy run of beads, the wheel spun, place's take
        # four quick notches.
        "combo":    ("one small wooden peg set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -14, HUSH, "warm:1600", "cut:0.1", "body:320", "tight"),
        "steady":   ("one small wooden bead set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -16, HUSH, "warm:1500", "cut:0.3", "body:320", "tight", "notes:0.055:0,1,0,2"),
        "confetti": ("a soft little paper confetti pop and flutter with a tiny music box twinkle, cute", 1.0, -10, BEADBOX_TUNE, "warm:7000"),
        # The butterfly: Hedgehogs' gust again, the quietest puff there is
        # (pitched up, a take that quiet came out of `notes` empty).
        "flutter":  ("a tiny quick puff of warm air, one light short breath that rises and fades, very short", 0.6, -19, BREEZE, "warm:1100", "steep", "ease:0.05", "body:320"),
        "stamp":    ("one soft note on a kalimba, proud and warm, left to fade", 1.5, -9, COZY_TUNE, "warm:2600", "ease:0.012", "body:300", "notes:0.26:5,1,8"),
        "solved":   ("a warm short celebratory flourish on a real kalimba and a music box, rising arpeggio ending on a soft hand bell shimmer, joyful and cozy", 2.0, -8, BEADBOX_TUNE, "warm:2600", "body:300"),
        "party":    ("a short cozy celebratory flourish on a real kalimba and a music box, rising and bright, with a few soft little party blower toots, warm and joyful", 2.0, -8, BEADBOX_TUNE, "warm:2600", "body:300"),
        "purr":     ("one short soft contented chirrup, a little rolling trill with the mouth closed, gentle and happy", 1.0, -12, KITTEN, "warm:2400", "ease:0.01", "body:300"),
    },
    # Fairy Lights (puzzle_id "fairylights"): tap a piece of garden wire to
    # turn it; wire joined back to the post runs gold and wakes its lanterns.
    # Hard and Insane blow a fuse on a wrong join; Insane is Wish Tags.
    # Redone 2026-10-10 against the cozy rules (docs/agents/sound.md), the
    # thirtieth set of the redo, with Firefly's below. Nothing is kept: the
    # three that passed (hint, refuse, undo) had lost their raw takes, so
    # they are written from this set's own. Nothing new is glass, a chime, a
    # music box, a glockenspiel, brass, a fizz, paper or a wing (DUSK; ten
    # cues sat 68 to 99% above 3 kHz, the wire's turn among them, and solved
    # and party peaked at -4). Three takes of ticks and notes: `place` (a
    # wooden toggle on felt), `wake` (a lighter bead) and `hum` (one muffled
    # note, at 332 Hz, so its phrases are 4 to 11 steps up); here enter,
    # fuse, clip and undo are place's, join wake's, and hint, refuse, love,
    # heart_lost, heart_back and dance hum's. solved, out_of_hearts, stamp
    # and party are a take each (330, 331, 330 and 446 Hz). Borrowed, of the
    # same prompts: combo and reset Super Slider's and the tags its gate,
    # the moth Hedgehogs' gust and the fireflies its whoosh, confetti
    # Binairo's, the cat Untangle's kitten. Every tick is `tight`. A lantern
    # waking is a tick the board pitches by its depth, combo one it pitches
    # by the streak, neither past five semitones.
    "fairylights": {
        "place":    ("one small wooden toggle set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1500", "cut:0.09", "body:320", "tight"),
        # Two wires touching: wake's take, two steps down.
        "join":     ("one small light wooden bead set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -17, HUSH, "warm:1300", "cut:0.09", "body:320", "tight", "notes:0:-2"),
        # A lantern lit, seventeen in a ripple: the wheel spun, and the board
        # pitches it by the lantern's depth, not past five semitones.
        "wake":     ("one small light wooden bead set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -16, HUSH, "warm:1500", "cut:0.09", "body:320", "tight"),
        # Not there: the note, two quick ones a step down.
        "refuse":   ("one soft short note on a kalimba, muffled and kind", 0.6, -14, COZY_TUNE, "warm:2200", "ease:0.012", "body:300", "notes:0.1:6,4", "cut:0.5"),
        # Taken back: place's take, twice and falling.
        "undo":     ("one small wooden toggle set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1200", "cut:0.28", "body:320", "tight", "notes:0.11:0,-3"),
        "hint":     ("one soft short note on a kalimba, muffled and kind", 0.6, -10, COZY_TUNE, "warm:2400", "ease:0.012", "body:300", "notes:0.16:4,7,11", "cut:1.0"),
        "reset":    ("a soft gust of warm breeze through a few leaves, one gentle whoosh of air that rises and fades, short", 0.8, -16, BREEZE, "warm:1100", "steep", "ease:0.06", "body:320"),
        # The garden set out: place's take, five in a row.
        "enter":    ("one small wooden toggle set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -14, HUSH, "warm:1600", "cut:0.5", "body:320", "tight", "notes:0.08:0,3,0,2,5"),
        "solved":   ("one soft note on a kalimba over a gentle tongue drum, warm, left to fade", 2.0, -8, COZY_TUNE, "warm:2000", "ease:0.012", "body:300", "notes:0.14:4,6,9,11,13", "cut:1.7"),
        # The streak and the gags.
        "combo":    ("one small wooden peg set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -14, HUSH, "warm:1600", "cut:0.1", "body:320", "tight"),
        "confetti": ("a small soft puff of warm air through a few leaves, light, rising and fading, short", 0.8, -17, BREEZE, "warm:1200", "steep", "ease:0.04", "body:320"),
        # The moth: Hedgehogs' gust, the quietest puff there is.
        "moth":     ("a tiny quick puff of warm air, one light short breath that rises and fades, very short", 0.6, -19, BREEZE, "warm:1100", "steep", "ease:0.05", "body:320"),
        "hum":      ("one soft short note on a kalimba, muffled and kind", 0.6, -14, COZY_TUNE, "warm:2400", "ease:0.012", "body:300", "notes:0.2:4,8,6", "cut:0.9"),
        "love":     ("one soft short note on a kalimba, muffled and kind", 0.6, -13, COZY_TUNE, "warm:2400", "ease:0.01", "body:300", "notes:0.1:4,4,7", "cut:0.6"),
        # Hearts and the fuse (Hard and Insane). The fuse sounds with
        # heart_lost, so it is two low notches alike and the heart one low
        # quiet note: neither is a second fall.
        "heart_lost":    ("one soft short note on a kalimba, muffled and kind", 0.6, -15, COZY_TUNE, "warm:2000", "ease:0.012", "body:300", "notes:0:4", "cut:0.6"),
        "fuse":     ("one small wooden toggle set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1200", "cut:0.26", "body:320", "tight", "notes:0.1:-3,-3"),
        # The clip on a judged wire: place's take, one notch two steps up.
        "clip":     ("one small wooden toggle set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1400", "cut:0.1", "body:320", "tight", "notes:0:2"),
        "out_of_hearts": ("one slow soft note on a kalimba, sleepy, calm and kind, left to fade", 1.6, -13, COZY_TUNE, "warm:2600", "ease:0.02", "body:300", "notes:0.32:11,8,4"),
        "heart_back":    ("one soft short note on a kalimba, muffled and kind", 0.6, -13, COZY_TUNE, "warm:2400", "ease:0.012", "body:300", "notes:0.14:4,9", "cut:0.7"),
        # The party.
        "stamp":    ("one soft note on a kalimba, proud and warm, left to fade", 1.5, -9, COZY_TUNE, "warm:2600", "ease:0.012", "body:300", "notes:0.26:9,5,12"),
        "party":    ("one soft note on a kalimba over a gentle tongue drum, warm and cozy, left to fade", 2.0, -8, COZY_TUNE, "warm:2600", "ease:0.012", "body:300", "notes:0.14:0,3,5,3,5,8", "cut:1.9"),
        "dance":    ("one soft short note on a kalimba, muffled and kind", 0.6, -11, COZY_TUNE, "warm:2400", "ease:0.01", "body:300", "notes:0.12:4,9,4,11", "cut:0.9"),
        # Fireflies drifting up: Hedgehogs' whoosh, a long breath that rises.
        "fireflies":("a long soft gust of warm breeze through leaves, one gentle whoosh of air that rises slowly and fades", 1.0, -15, BREEZE, "warm:1100", "steep", "ease:0.1", "body:320"),
        "purr":     ("one short soft contented chirrup, a little rolling trill with the mouth closed, gentle and happy", 1.0, -12, KITTEN, "warm:2400", "ease:0.01", "body:300"),
        # Insane: Wish Tags. The tags on their string in a breeze: Super
        # Slider's gate, a long breath.
        "tags":     ("a long soft breath of warm breeze that eases, fades and stops, calm", 1.0, -16, BREEZE, "warm:900", "steep", "ease:0.1", "body:320"),
    },
    # Firefly (Arcade, arcade/firefly_screen.gd): a formation shooter in a
    # night garden. `shoot` fires several times a second, so it is short
    # and quiet; `beam` is the moth's silk beam, looped while it is open.
    # Redone 2026-10-10 against the cozy rules (docs/agents/sound.md), the
    # thirty-first set of the redo, with Fairy Lights' above. Fifteen kept
    # on their takes of 2026-10-05, none above -8 now (they were -4 to -7):
    # hurt and carried as they were, captured, rescue, docked, stage, clear,
    # flyby, result, extra and game_over turned down, beam_open, start,
    # perfect and new_best rolled off as well; they keep ARCADE's prompts, a
    # music box and hand bells in them, and pass the measure. Three new
    # takes: `shoot` (a light wooden button on felt, where it was a click
    # 94% above 3 kHz), `pop` (a cork on felt, where it was 81% under 300
    # Hz) and `pop_moth` (one muffled note, at 334 Hz, so the phrases are 4
    # to 11 steps up); rogue and ship_pop are pop_moth's. Borrowed, of the
    # same prompts: the dive is Hedgehogs' gust and the beam Snooker's
    # steady air. Nothing new is a seed, a cork's pop, a paper fan, a paper
    # bag, a glass rim or a hand bell. The screen pitches shoot, pop and
    # docked, none past five semitones.
    "firefly": {
        "shoot":    ("one small light wooden button set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1400", "cut:0.06", "body:320", "tight"),
        "pop":      ("one small cork set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -13, HUSH, "warm:1500", "cut:0.1", "body:320", "tight"),
        # A big moth sent off: two muffled notes, a fourth up.
        "pop_moth": ("one soft short note on a kalimba, muffled and kind", 0.6, -9, COZY_TUNE, "warm:2400", "ease:0.01", "body:300", "notes:0.09:4,9", "cut:0.6"),
        "hurt":     ("one short low hollow note on a wooden tongue drum, damped at once, an armoured ladybird hit but not beaten yet, very short", 0.5, -9, ARCADE),
        # A bug diving: Hedgehogs' gust.
        "dive":     ("a tiny quick puff of warm air, one light short breath that rises and fades, very short", 0.6, -16, BREEZE, "warm:900", "steep", "ease:0.04", "body:320"),
        "beam_open":("a soft rising run on a real music box with a shimmer of tiny hand bells opening up, a ribbon of silk light unrolling, gentle", 0.8, -8, ARCADE, "warm:2600", "body:300"),
        # The silk beam, looped while it is open: Snooker's steady air.
        "beam":     ("a continuous steady soft warm breath of air moving, smooth, constant and even, no gusts", 3.0, -15, BREEZE, "loop", "warm:1000", "steep", "body:320"),
        "captured": ("a sad little wobbling slide down on a real kalimba, a few notes bending lower, a little friend caught and carried up, gentle", 1.2, -8, ARCADE),
        "carried":  ("a short low minor two-note fall on a real kalimba, a friend lost, soft", 0.8, -9, ARCADE),
        "rescue":   ("a bright happy rising run on a real kalimba with a music box sparkle on top, a friend set free", 1.0, -8, ARCADE),
        "docked":   ("a cheerful quick pair of music box notes with a soft wooden click, two friends joining up, stronger together", 0.7, -8, ARCADE),
        # A friend turned: the note, a low wobble (down a step and back).
        "rogue":    ("one soft short note on a kalimba, muffled and kind", 0.6, -10, COZY_TUNE, "warm:2000", "ease:0.012", "body:300", "notes:0.13:5,4,5", "cut:0.7"),
        # The firefly's light going out: three quick notes down.
        "ship_pop": ("one soft short note on a kalimba, muffled and kind", 0.6, -8, COZY_TUNE, "warm:2400", "ease:0.012", "body:300", "notes:0.12:11,7,4", "cut:0.9"),
        "start":    ("a short cheerful opening tune on a real kalimba and music box, a bouncy rising melody with a hand bell on top, a game beginning, about three seconds", 3.0, -8, ARCADE, "warm:1800", "body:300"),
        "stage":    ("a short bright three-note fanfare on a real music box and hand bells, a new stage beginning", 1.2, -8, ARCADE),
        "clear":    ("a quick happy rising run on a real kalimba ending on a hand bell, a wave cleared", 1.0, -8, ARCADE),
        "flyby":    ("a playful bouncy little tune on a real kalimba and a wooden tongue drum, a bonus round starting", 1.8, -8, ARCADE),
        "result":   ("a short friendly run of music box notes counting up one by one, a score being tallied", 1.2, -8, ARCADE),
        "perfect":  ("a triumphant sparkling fanfare on a real kalimba, music box and hand bells, a perfect bonus round, joyful", 2.2, -8, ARCADE, "warm:2600", "body:300"),
        "extra":    ("three bright rising notes on a real music box with a hand bell sparkle, an extra life earned", 1.0, -8, ARCADE),
        "game_over":("a gentle slow descending melody on a real kalimba, a few soft notes stepping down, the game is over, kind and calm, never sad", 2.2, -8, ARCADE),
        "new_best": ("a joyful celebratory fanfare on a real kalimba, music box and soft hand bells, landing on a bright warm chord, a new high score", 2.4, -8, ARCADE, "warm:2600", "body:300"),
    },
    # Molehill (Arcade, arcade/molehill_screen.gd): moles bopped on a lawn.
    # Redone against the cozy rules on 2026-10-10 (docs/agents/sound.md has
    # the row). The mallet is a tick and so is everything it lands on;
    # pop_up and escape fire constantly, so they sit lowest.
    "molehill": {
        "pop_up":      ("a tiny soft 'plop' of a small animal popping up out of a hole in the soil, very short", 0.5, -16, CARTOON, "warm:1400", "body:320"),
        "whack":       ("one small wooden mallet set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -13, HUSH, "warm:1500", "cut:0.1", "body:320", "tight"),
        # The golden mole: the note, two quick ones a fourth apart.
        "whack_gold":  ("one soft short note on a kalimba, muffled and kind", 0.6, -9, COZY_TUNE, "warm:2400", "ease:0.01", "body:300", "notes:0.09:4,9", "cut:0.6"),
        # A pot knocked is whack's take three steps down, a pot broken two
        # notches falling.
        "clang":       ("one small wooden mallet set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -13, HUSH, "warm:1500", "cut:0.12", "body:320", "tight", "notes:0:-3"),
        "crack":       ("one small wooden mallet set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -13, HUSH, "warm:1500", "cut:0.22", "body:320", "tight", "notes:0.09:0,-4"),
        # The bunny bopped by mistake: a low wobble, a step down and back.
        "bunny":       ("one soft short note on a kalimba, muffled and kind", 0.6, -10, COZY_TUNE, "warm:2000", "ease:0.012", "body:300", "notes:0.13:5,4,5", "cut:0.7"),
        # The mallet on the grass: Firefly's shot, a lighter thing.
        "miss":        ("one small light wooden button set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -16, HUSH, "warm:1400", "cut:0.06", "body:320", "tight"),
        # A mole gone back down: Hedgehogs' gust.
        "escape":      ("a tiny quick puff of warm air, one light short breath that rises and fades, very short", 0.6, -19, BREEZE, "warm:900", "steep", "ease:0.04", "body:320"),
        # The multiplier going up: Super Slider's tick, a semitone a step.
        "combo":       ("one small wooden block set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -14, HUSH, "warm:1600", "cut:0.14", "body:320", "tight"),
        "streak_lost": ("one soft short note on a kalimba, muffled and kind", 0.6, -11, COZY_TUNE, "warm:2200", "ease:0.012", "body:300", "notes:0.16:7,4", "cut:0.7"),
        "go":          ("one soft short note on a kalimba, muffled and kind", 0.6, -9, COZY_TUNE, "warm:2400", "ease:0.01", "body:300", "notes:0.12:4,4,8", "cut:0.8"),
        "tick":        ("a single soft wooden clock tick with a tiny bell, a countdown second, very short", 0.5, -9, ARCADE),
        "frenzy":      ("an excited quick rising run on a real kalimba over a soft roll of fingers drumming on a wooden box, the last ten seconds, double points", 1.2, -8, ARCADE),
        # The bell is gone: four notes hopping, a third apart.
        "time_up":     ("one soft short note on a kalimba, muffled and kind", 0.6, -9, COZY_TUNE, "warm:2400", "ease:0.01", "body:300", "notes:0.11:11,8,11,8", "cut:0.9"),
        "start":       ("a short cheerful opening tune on a real kalimba and music box, a bouncy garden melody, a game beginning, about two seconds", 2.2, -8, ARCADE, "warm:1800", "body:300"),
        "game_over":   ("a gentle slow descending melody on a real kalimba, a few soft notes stepping down, the game is over, kind and calm, never sad", 2.2, -8, ARCADE),
        "new_best":    ("a joyful celebratory fanfare on a real kalimba, music box and soft hand bells, landing on a bright warm chord, a new high score", 2.4, -8, ARCADE),
    },
    # Stackwood (Arcade, arcade/stackwood_screen.gd): numbered wooden toy
    # blocks that fall and merge. Redone against the cozy rules on
    # 2026-10-10 (docs/agents/sound.md has the row). move and land fire on
    # every block, so they sit low; merge is land's take, pitched up the
    # chain by the screen, five semitones at most.
    "stackwood": {
        "move":      ("one small light wooden toy block set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -18, HUSH, "warm:1400", "cut:0.07", "body:320", "tight"),
        # A block let go: Hedgehogs' gust.
        "drop":      ("a tiny quick puff of warm air, one light short breath that rises and fades, very short", 0.6, -17, BREEZE, "warm:900", "steep", "ease:0.04", "body:320"),
        "land":      ("one hollow wooden toy block set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -13, HUSH, "warm:1500", "cut:0.12", "body:320", "tight"),
        "merge":     ("one hollow wooden toy block set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -13, HUSH, "warm:1500", "cut:0.12", "body:320", "tight", "notes:0:2"),
        # The chain's count: Super Slider's tick, a semitone a step.
        "chain":     ("one small wooden block set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -14, HUSH, "warm:1600", "cut:0.14", "body:320", "tight"),
        # A new biggest block: the note, two a fourth apart.
        "big":       ("one soft short note on a kalimba, muffled and kind", 0.6, -9, COZY_TUNE, "warm:2400", "ease:0.01", "body:300", "notes:0.12:4,9", "cut:0.7"),
        "milestone": ("a joyful triumphant fanfare on a real kalimba, music box and hand bells, a great block reached at last, about two seconds", 2.2, -8, ARCADE, "warm:2600", "body:300"),
        "wild":      ("a soft swirling run of tiny hand bells and music box notes, a rainbow shimmer, magical, soft and bright, short", 0.8, -8, ARCADE, "warm:2600", "body:300"),
        "buy":       ("a cheerful two-note music box chime with a tiny coin clink, a power-up bought, short", 0.6, -8, ARCADE),
        # The fuse lit is move's take, four quick notches (the wheel spun);
        # the bolt three quick ones down; not enough acorns two low alike.
        "fuse":      ("one small light wooden toy block set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -16, HUSH, "warm:1400", "cut:0.26", "body:320", "tight", "notes:0.055:0,1,2,3"),
        # The bomb and the stack coming down are land's take: a short tumble
        # of five notches and a long one of eleven, falling.
        "bomb":      ("one hollow wooden toy block set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -13, HUSH, "warm:1500", "cut:0.36", "body:320", "tight", "notes:0.05:0,-3,-1,-5,-2"),
        "zap":       ("one small light wooden toy block set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1400", "cut:0.17", "body:320", "tight", "notes:0.045:5,2,0"),
        "refused":   ("one small light wooden toy block set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1400", "cut:0.2", "body:320", "tight", "notes:0.1:-3,-3"),
        # A stack near the top: two slow notes, the second lower.
        "warn":      ("one soft short note on a kalimba, muffled and kind", 0.6, -10, COZY_TUNE, "warm:2200", "ease:0.012", "body:300", "notes:0.2:7,4", "cut:0.8"),
        "retired":   ("a soft pop and a small falling sprinkle of music box notes, the smallest blocks put away, short", 0.6, -8, ARCADE),
        "topple":    ("one hollow wooden toy block set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -12, HUSH, "warm:1500", "cut:1.1", "body:320", "tight", "notes:0.085:0,-1,2,-2,-1,-4,-3,-5,-4,-7,-7"),
        "go":        ("two short bright rising notes on a real music box with a little hand bell on top, a game starts, cheerful", 0.6, -8, ARCADE),
        "start":     ("a short cheerful opening tune on a real kalimba and music box, a bouncy toy-box melody, a game beginning, about two seconds", 2.2, -8, ARCADE, "warm:1800", "body:300"),
        "game_over": ("a gentle slow descending melody on a real kalimba, a few soft notes stepping down, the game is over, kind and calm, never sad", 2.2, -8, ARCADE),
        "new_best":  ("a joyful celebratory fanfare on a real kalimba, music box and soft hand bells, landing on a bright warm chord, a new high score", 2.4, -8, ARCADE, "warm:2600", "body:300"),
    },
    # Lucky Thirteen (Arcade, arcade/thirteen_screen.gd): numbered river
    # pebbles merged by drawing chains. Redone against the cozy rules on
    # 2026-10-10 (docs/agents/sound.md has the row). select fires on every
    # pebble a chain takes and is pitched up the chain by the screen, a
    # semitone a pebble and five at most. **It is a click and stays one**:
    # for an hour on 2026-10-05 it was a kalimba note up the pentatonic, and
    # the user: "it's important to avoid bell or ring sounds for something
    # that repeat a lot, so use something more like a click, previous
    # selection sound were in the right direction". merge is every move's,
    # so it is a tock with no note either. Nothing is a stone: a pebble on
    # sand came back as a click at 2.5 kHz and three clacking at 4.5.
    "thirteen": {
        "select":     ("one small smooth wooden bead set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1400", "cut:0.07", "body:320", "tight"),
        # A pebble given back: select's take, two steps down.
        "unselect":   ("one small smooth wooden bead set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -18, HUSH, "warm:1200", "cut:0.07", "body:320", "tight", "notes:0:-2"),
        "short":      ("one soft low damped note on a wooden tongue drum, a kind 'not yet', not enough pebbles, gentle, very short", 0.5, -10, ARCADE),
        "merge":      ("one smooth round wooden pebble set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -13, HUSH, "warm:1500", "cut:0.12", "body:320", "tight"),
        # A pebble settling: merge's take, two steps down and quieter.
        "land":       ("one smooth round wooden pebble set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -16, HUSH, "warm:1300", "cut:0.1", "body:320", "tight", "notes:0:-2"),
        "new_number": ("two bright happy notes on a real music box with a hand bell sparkle, a new biggest number made, short", 0.8, -8, ARCADE, "warm:2600", "body:300"),
        "goal":       ("a joyful triumphant fanfare on a real kalimba, music box and hand bells with one lucky bell ringing on top, the number thirteen reached, about two seconds", 2.4, -8, ARCADE, "warm:2600", "body:300"),
        # No moves left: two slow notes, the second a third lower.
        "stuck":      ("one soft short note on a kalimba, muffled and kind", 0.6, -10, COZY_TUNE, "warm:2200", "ease:0.012", "body:300", "notes:0.2:7,4", "cut:0.8"),
        # The tools are select's take: one notch two steps up for a tool
        # picked up, twice and falling for a move taken back, two a third
        # apart for two pebbles trading places, two low ones alike for no.
        "arm":        ("one small smooth wooden bead set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1400", "cut:0.07", "body:320", "tight", "notes:0:2"),
        "undo":       ("one small smooth wooden bead set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1400", "cut:0.2", "body:320", "tight", "notes:0.09:0,-3"),
        "swap":       ("one small smooth wooden bead set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1400", "cut:0.18", "body:320", "tight", "notes:0.08:-1,2"),
        # A pebble taken off the board: merge's take, three steps up.
        "pluck":      ("one smooth round wooden pebble set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -14, HUSH, "warm:1500", "cut:0.12", "body:320", "tight", "notes:0:3"),
        # The board stirred and the board tipped out are merge's take: the
        # wheel spun, nine notches wandering and eleven falling.
        "shuffle":    ("one smooth round wooden pebble set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -14, HUSH, "warm:1500", "cut:0.75", "body:320", "tight", "notes:0.075:0,2,-1,3,0,-2,1,-1,2"),
        "lift":       ("a soft rising pair of kalimba notes with a hand bell sparkle, a pebble raised up one, short", 0.6, -8, ARCADE),
        "refused":    ("one small smooth wooden bead set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1400", "cut:0.2", "body:320", "tight", "notes:0.1:-3,-3"),
        "tumble":     ("one smooth round wooden pebble set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -12, HUSH, "warm:1500", "cut:1.1", "body:320", "tight", "notes:0.085:0,-1,2,-2,-1,-4,-3,-5,-4,-7,-7"),
        "start":      ("a short cheerful opening tune on a real kalimba and music box, a bouncy lucky little melody, a game beginning, about two seconds", 2.2, -8, ARCADE, "warm:1800", "body:300"),
        # The game's end: stuck's note, four slow ones stepping down.
        "game_over":  ("one soft short note on a kalimba, muffled and kind", 0.6, -9, COZY_TUNE, "warm:2200", "ease:0.012", "body:300", "notes:0.3:11,9,7,4", "cut:1.6"),
        "new_best":   ("a joyful celebratory fanfare on a real kalimba, music box and soft hand bells, landing on a bright warm chord, a new high score", 2.4, -8, ARCADE, "warm:2600", "body:300"),
    },
    # Posy (Arcade, arcade/posy_screen.gd): a swap-three garden of flowers,
    # leaves, drops, mushrooms, berries and acorns. Redone against the cozy
    # rules on 2026-10-10 (docs/agents/sound.md has the row). match fires on
    # every cascade step and is pitched up the cascade by the screen, a
    # semitone a step and five at most, so it is a tock; collect fires on
    # every tile landing on a goal, the faintest tick. What travels is air.
    "posy": {
        "select":       ("one small thin wooden tile set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1400", "cut:0.07", "body:320", "tight"),
        # Two tiles trading places: Paper Planes' puff.
        "swap":         ("a tiny quick puff of warm air, one light short breath that rises and fades, very short", 0.5, -16, BREEZE, "warm:750", "steep", "ease:0.05", "body:320"),
        # A swap that makes nothing: select's take, there and a step back.
        "bad_swap":     ("one small thin wooden tile set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1400", "cut:0.2", "body:320", "tight", "notes:0.09:0,-2"),
        "match":        ("one small round wooden button set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -13, HUSH, "warm:1500", "cut:0.12", "body:320", "tight"),
        # Tiles settling: select's take, two steps down and quiet.
        "land":         ("one small thin wooden tile set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -18, HUSH, "warm:1200", "cut:0.06", "body:320", "tight", "notes:0:-2"),
        # A tile reaching its goal: Firefly's shot, a lighter thing.
        "collect":      ("one small light wooden button set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -18, HUSH, "warm:1400", "cut:0.06", "body:320", "tight"),
        # A breeze made is Hedgehogs' breath (its reset; Binairo's gust,
        # tried first, is 78% above 3 kHz raw and passes only filtered) and
        # a breeze let go its long one.
        "made_breeze":  ("a soft breath of warm breeze that eases, fades and stops, calm, short", 0.8, -17, BREEZE, "warm:900", "steep", "ease:0.05", "body:320"),
        # A seed pod made: the note, two quick ones a fourth apart.
        "made_bomb":    ("one soft short note on a kalimba, muffled and kind", 0.6, -9, COZY_TUNE, "warm:2400", "ease:0.01", "body:300", "notes:0.09:4,9", "cut:0.6"),
        "made_rainbow": ("a bright rising run on a real music box and kalimba with shimmering hand bells, a rainbow flower appearing, about a second", 1.0, -8, ARCADE),
        "breeze":       ("a long soft gust of warm breeze through leaves, one gentle whoosh of air that rises slowly and fades", 1.0, -15, BREEZE, "warm:1100", "steep", "ease:0.1", "body:320"),
        # The seed pod going off is match's take, a tumble of five notches.
        "bomb":         ("one small round wooden button set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -13, HUSH, "warm:1500", "cut:0.36", "body:320", "tight", "notes:0.05:0,-3,-1,-5,-2"),
        "rainbow":      ("a sweeping shower of hand bells and music box notes scattering in every direction, sparkling and magical, about a second", 1.1, -8, ARCADE),
        "goal":         ("two bright happy notes on a real music box, a goal completed, short", 0.7, -8, ARCADE),
        "cheer":        ("a short joyful flourish on a real kalimba with a hand bell sparkle, a big cascade, happy", 0.8, -8, ARCADE),
        "day_done":     ("a joyful short garden fanfare on a real kalimba, music box and hand bells, a day's goals completed, about two seconds", 2.0, -8, ARCADE),
        # The bed dealt and the bed stirred: the wheel spun, nine notches
        # of match's take falling into place and eight of select's wandering.
        "deal":         ("one small round wooden button set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -14, HUSH, "warm:1500", "cut:0.8", "body:320", "tight", "notes:0.08:3,1,2,0,1,-2,-1,-3,-4"),
        "shuffle":      ("one small thin wooden tile set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1400", "cut:0.6", "body:320", "tight", "notes:0.065:0,3,-1,2,-2,1,3,0"),
        "convert":      ("a soft twinkle of two tiny music box notes, a tile turning special, short", 0.6, -9, ARCADE, "warm:2400", "body:300"),
        "gift":         ("a cheerful little rising music box phrase with a hand bell sparkle, a present, a tool earned, short", 0.8, -8, ARCADE, "warm:2600", "body:300"),
        # The trowel: two notches of match's take, falling.
        "trowel":       ("one small round wooden button set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -13, HUSH, "warm:1500", "cut:0.22", "body:320", "tight", "notes:0.09:0,-4"),
        "arm":          ("one small thin wooden tile set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1400", "cut:0.07", "body:320", "tight", "notes:0:2"),
        "refused":      ("one small round wooden button set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1400", "cut:0.2", "body:320", "tight", "notes:0.1:-3,-3"),
        "out_of_moves": ("a soft slow descending wobble, out of moves, gentle and kind, not sad", 1.0, -8, CARTOON),
        "start":        ("a short cheerful opening tune on a real kalimba and music box, a bouncy flowery little melody, a game beginning, about two seconds", 2.2, -8, ARCADE),
        "game_over":    ("a gentle slow descending melody on a real kalimba, a few soft notes stepping down, the game is over, kind and calm, never sad", 2.2, -8, ARCADE),
        "new_best":     ("a joyful celebratory fanfare on a real kalimba, music box and soft hand bells, landing on a bright warm chord, a new high score", 2.4, -8, ARCADE, "warm:2600", "body:300"),
        # The bee made is the note, four quick ones a step apart (a little
        # trill); the bee leaving Hedgehogs' gust, its landing match's take
        # three steps up.
        "made_bee":     ("one soft short note on a kalimba, muffled and kind", 0.6, -10, COZY_TUNE, "warm:2200", "ease:0.01", "body:300", "notes:0.07:7,9,7,9", "cut:0.6"),
        "bee":          ("a tiny quick puff of warm air, one light short breath that rises and fades, very short", 0.6, -19, BREEZE, "warm:900", "steep", "ease:0.04", "body:320"),
        "bee_hit":      ("one small round wooden button set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1500", "cut:0.1", "body:320", "tight", "notes:0:3"),
        # The bed's ground. A weed pulled is two quick notches of select's
        # take, rising; a stone knocked one of match's three steps down and
        # a stone broken three falling; moss creeping three slow low ones of
        # select's and moss plucked one of match's two steps up.
        "weed":         ("one small thin wooden tile set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1400", "cut:0.15", "body:320", "tight", "notes:0.06:0,2"),
        "stone":        ("one small round wooden button set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -13, HUSH, "warm:1500", "cut:0.12", "body:320", "tight", "notes:0:-3"),
        "stone_break":  ("one small round wooden button set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -13, HUSH, "warm:1500", "cut:0.3", "body:320", "tight", "notes:0.07:-2,-5,-7"),
        "moss":         ("one small thin wooden tile set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -17, HUSH, "warm:1200", "cut:0.34", "body:320", "tight", "notes:0.11:-4,-4,-2"),
        "moss_clear":   ("one small round wooden button set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -14, HUSH, "warm:1500", "cut:0.12", "body:320", "tight", "notes:0:2"),
        # So close: the note, a question, the second a step higher.
        "offer":        ("one soft short note on a kalimba, muffled and kind", 0.6, -10, COZY_TUNE, "warm:2200", "ease:0.012", "body:300", "notes:0.22:5,7", "cut:0.8"),
        "more_moves":   ("a bright cheerful rising sprinkle of music box notes and a hand bell, extra moves granted, short", 0.8, -8, ARCADE),
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
    # Redone against the cozy rules on 2026-10-10 (docs/agents/sound.md has
    # the row). hit is not touched: its file is the take in hit.mp3, the
    # tock with more body, and it is never rendered again by name without
    # a look at the raw (hit_liked_0859.mp3, the tap first said yes to,
    # sits at 1.3 kHz). The levels above stand: pop -14, the golden one -9,
    # the iron -11, hit -13. One new take, `knock` (a small hollow wooden
    # box set down on felt, one tock from 0 ms, its file at 611 Hz): pop, boom,
    # milli and lost are knock's, and clank is hit's own take three steps
    # down, so iron is the same wood, lower. The note is Lucky Thirteen's
    # (332 Hz, so the phrases are 4 to 11 steps up): pop_gold, head, wave
    # and over. Borrowed, of the same prompts: shot is Firefly's, twin_off
    # Hedgehogs' gust and shove its breath. Twelve more kept on their takes
    # of 2026-10-04 and 05, none above -8 now. Nothing new is a pea shooter's
    # catch, a cork's pop, slats, coins, a tin can, a party popper, a paper
    # bag, canvas or a hand bell. The screen pitches shot, hit, clank, pop,
    # knock, catch and word, none past five semitones.
    "peapod": {
        # 2026-10-05: the gun fires five to ten times a second for the whole
        # run. Its first sound was an airy half-second 'pft'; taking it away
        # altogether was wrong too -- the user: "we need a really subtle
        # click sound for every shoot". So a tick, Firefly's shot cut at
        # 0.06 s, and the quietest file of the set: -23 is as low as the
        # measure lets it go (it was -24, a click at 3.3 kHz that read
        # `faint`; the screen takes 4 dB more off).
        "shot":     ("one small light wooden button set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -23, HUSH, "warm:1400", "cut:0.06", "body:320", "tight"),
        "hit":       ("one single soft dry 'tock' on a small hollow wooden block tapped with a felt mallet, warm and round, damped at once, no ring, very short", 0.5, -13, PEAPATCH, "warm:6000", "cut:0.12", "tight"),
        # A crate coming apart: knock's take, a tumble of three notches.
        "pop":       ("one small hollow wooden box set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -14, HUSH, "warm:1500", "cut:0.2", "body:320", "tight", "notes:0.045:0,-2,-5"),
        # The golden crate: the note, two a fourth apart all but together
        # (catch and go are two rising, one after the other).
        "pop_gold":  ("one soft short note on a kalimba, muffled and kind", 0.6, -9, COZY_TUNE, "warm:2400", "ease:0.01", "body:300", "notes:0.03:4,9", "cut:0.6"),
        "gift":      ("one soft bright rising kalimba pluck with a tiny hand bell, a present popping out of a box, very short", 0.5, -8, ARCADE),
        "catch":     ("two bright happy rising notes on a real music box, a gift caught, short", 0.6, -8, ARCADE, "warm:2600", "body:300"),
        "twin":      ("a cheerful bouncy three-note phrase on a real kalimba, a little helper joining in, short", 0.8, -8, ARCADE),
        # A pod's gift run out: Hedgehogs' gust.
        "twin_off":  ("a tiny quick puff of warm air, one light short breath that rises and fades, very short", 0.6, -17, BREEZE, "warm:900", "steep", "ease:0.04", "body:320"),
        # A gift missed (no caller on the screen): knock's take, one notch
        # two steps down.
        "lost":      ("one small hollow wooden box set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -16, HUSH, "warm:1300", "cut:0.1", "body:320", "tight", "notes:0:-2"),
        # The cracker going off: knock's take, a tumble of five notches.
        "boom":      ("one small hollow wooden box set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -12, HUSH, "warm:1500", "cut:0.36", "body:320", "tight", "notes:0.05:-1,2,-3,0,-4"),
        "knock":     ("one small hollow wooden box set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -13, HUSH, "warm:1500", "cut:0.12", "body:320", "tight"),
        # The big bug sent off: the note, four up and over.
        "head":      ("one soft short note on a kalimba, muffled and kind", 0.6, -8, COZY_TUNE, "warm:2400", "ease:0.01", "body:300", "notes:0.1:4,7,11,9", "cut:1.0"),
        # A new wave: the note, two alike and a third up.
        "wave":      ("one soft short note on a kalimba, muffled and kind", 0.6, -9, COZY_TUNE, "warm:2400", "ease:0.01", "body:300", "notes:0.12:4,4,8", "cut:0.8"),
        # The big bug arriving on its many feet: knock's take, four notches
        # marching.
        "milli":     ("one small hollow wooden box set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -13, HUSH, "warm:1500", "cut:0.5", "body:320", "tight", "notes:0.11:0,-2,0,-2"),
        "clear":     ("a quick happy rising run on a real kalimba ending on a hand bell, a wave cleared", 1.0, -8, ARCADE, "warm:2000", "body:300"),
        "word":      ("a bright rising three-note run on a real kalimba with a hand bell sparkle, a combo streak, short", 0.7, -8, ARCADE),
        "warn":      ("two soft worried notes on a real kalimba, the second a little lower, something getting too close, gentle, not alarming", 0.6, -8, ARCADE),
        # The wall at the line: the note, three slow ones down.
        "over":      ("one soft short note on a kalimba, muffled and kind", 0.6, -9, COZY_TUNE, "warm:2200", "ease:0.012", "body:300", "notes:0.26:11,7,4", "cut:1.3"),
        "go":        ("two short bright rising notes on a real music box with a little hand bell on top, a round starts, cheerful", 0.6, -8, ARCADE),
        "start":     ("a short cheerful opening tune on a real kalimba and music box, a bouncy garden melody, a game beginning, about two seconds", 2.2, -8, ARCADE, "warm:1800", "body:300"),
        "game_over": ("a gentle slow descending melody on a real kalimba, a few soft notes stepping down, the game is over, kind and calm, never sad", 2.2, -8, ARCADE),
        "new_best":  ("a joyful celebratory fanfare on a real kalimba, music box and soft hand bells, landing on a bright warm chord, a new high score", 2.4, -8, ARCADE, "warm:2600", "body:300"),
        # A pea on iron or on a locked crate: hit's take, three steps down.
        "clank":     ("one single soft dry 'tock' on a small hollow wooden block tapped with a felt mallet, warm and round, damped at once, no ring, very short", 0.5, -11, PEAPATCH, "warm:6000", "cut:0.12", "tight", "notes:0:-3"),
        "pod":       ("three bright rising notes on a real kalimba with a soft wooden click, a new pod loaded, lively, short", 0.7, -8, ARCADE),
        "frost":     ("a soft falling shimmer of tiny glass bells and music box notes slowing down, a gentle frost settling over everything, short", 0.9, -8, ARCADE),
        # Everything pushed back: Hedgehogs' breath (its reset).
        "shove":     ("a soft breath of warm breeze that eases, fades and stops, calm, short", 0.8, -16, BREEZE, "warm:900", "steep", "ease:0.05", "body:320"),
    },
    # Rings: lift the top ring off a wooden peg and drop it on an empty peg
    # or on its own colour; four of a colour fill a peg and lock it.
    "rings": {
        # Redone 2026-10-10 against the cozy rules (docs/agents/sound.md), the
        # thirty-seventh set of the redo, with Peapod's above. None kept: the
        # set was TERRACE's (a music box and bells by prompt), fifteen of its
        # twenty-four files failed the measure and the raw takes of fifteen
        # were gone, so every cue is written again and the set renders whole
        # from what is in build/sfx_raw/. Three new takes: `drop` (a hollow
        # wooden ring set down on felt, the thing a finger does all day, so
        # the plainest: one tock), `lift` (a lighter thing set down) and one
        # muffled kalimba note, `hint`'s. Every tick is `tight`. undo,
        # refused, tumble and twirl are lift's take, hop_back, wobble, reset,
        # enter and the hoop drop's, and lock, solved, love, heart_lost,
        # heart_back, out_of_hearts, stamp and party the note's. Borrowed, of
        # the same prompts: combo is Super Slider's tick, the bee Hedgehogs'
        # gust, confetti Hedgehogs' breath (its reset; Binairo's confetti is
        # 79% above 3 kHz raw and passes only filtered) and the cat Untangle's
        # kitten. Nothing new is a ring slid up a dowel, a clack, a rattle, a
        # whirr, a boing, a buzz, a paper stamp, a music box or a hoop on
        # stone. The note came back at 373 Hz, so the phrases' steps are 2 to
        # 11 up and every note lands between 400 and 700 Hz; no two cues
        # share a contour. lift's tock starts at 20 ms, the others at 0.
        "lift":     ("one small light wooden bead set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -16, HUSH, "warm:1400", "cut:0.12", "body:320", "tight"),
        "drop":     ("one small hollow wooden ring set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -13, HUSH, "warm:1600", "cut:0.16", "body:320", "tight"),
        # A peg filled with one colour: two notes a third apart, all but
        # together.
        "lock":     ("one soft short note on a kalimba, muffled and kind", 0.6, -10, COZY_TUNE, "warm:2400", "ease:0.012", "body:300", "notes:0.03:3,7", "cut:0.7"),
        # Not there: lift's take, two low notches alike.
        "refused":  ("one small light wooden bead set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1200", "cut:0.26", "body:320", "tight", "notes:0.1:-3,-3"),
        # Taken back: lift's take, twice and falling.
        "undo":     ("one small light wooden bead set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1200", "cut:0.28", "body:320", "tight", "notes:0.11:0,-3"),
        "hint":     ("one soft short note on a kalimba, muffled and kind", 0.6, -10, COZY_TUNE, "warm:2400", "ease:0.012", "body:300", "notes:0.16:3,7,10", "cut:1.0"),
        # The rings back on their pegs: drop's take, five notches falling.
        "reset":    ("one small hollow wooden ring set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1400", "cut:0.5", "body:320", "tight", "notes:0.08:4,2,0,-1,-3"),
        # The pegs set out: drop's take, five in a row.
        "enter":    ("one small hollow wooden ring set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -14, HUSH, "warm:1600", "cut:0.5", "body:320", "tight", "notes:0.08:0,3,0,2,5"),
        "solved":   ("one soft short note on a kalimba, muffled and kind", 0.6, -8, COZY_TUNE, "warm:2000", "ease:0.012", "body:300", "notes:0.14:2,5,7,9,11", "cut:1.7"),
        # The streak and the gags. combo: a tick the board pitches by the
        # streak, not past five semitones. twirl: the ring spun on its peg,
        # the wheel spun, four quick notches rising. love: two quiet notes
        # alike and a third up. buzz: the bee, the quietest puff there is.
        "combo":    ("one small wooden peg set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -14, HUSH, "warm:1600", "cut:0.1", "body:320", "tight"),
        "confetti": ("a soft breath of warm breeze that eases, fades and stops, calm, short", 0.8, -17, BREEZE, "warm:900", "steep", "ease:0.05", "body:320"),
        "twirl":    ("one small light wooden bead set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1400", "cut:0.36", "body:320", "tight", "notes:0.07:0,2,3,5"),
        "love":     ("one soft short note on a kalimba, muffled and kind", 0.6, -13, COZY_TUNE, "warm:2400", "ease:0.01", "body:300", "notes:0.1:3,3,7", "cut:0.6"),
        "buzz":     ("a tiny quick puff of warm air, one light short breath that rises and fades, very short", 0.6, -19, BREEZE, "warm:1100", "steep", "ease:0.05", "body:320"),
        # Tumble (Insane): a two-tone ring turning over as it is lifted,
        # lift's take, one notch two steps down.
        "tumble":   ("one small light wooden bead set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -17, HUSH, "warm:1200", "cut:0.12", "body:320", "tight", "notes:0:-2"),
        # Hearts (Hard and Insane). The doomed ring wobbles on the stack as
        # the heart goes, so wobble is three notches, there and back, and the
        # heart one low quiet note: neither is a second fall. hop_back: the
        # ring home again, drop's take, two notches with the second three
        # steps up.
        "wobble":   ("one small hollow wooden ring set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1400", "cut:0.3", "body:320", "tight", "notes:0.07:0,2,0"),
        "heart_lost":    ("one soft short note on a kalimba, muffled and kind", 0.6, -15, COZY_TUNE, "warm:2000", "ease:0.012", "body:300", "notes:0:2", "cut:0.6"),
        "hop_back": ("one small hollow wooden ring set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1500", "cut:0.26", "body:320", "tight", "notes:0.1:0,3"),
        "out_of_hearts": ("one soft short note on a kalimba, muffled and kind", 0.6, -13, COZY_TUNE, "warm:2600", "ease:0.02", "body:300", "notes:0.32:10,7,3"),
        "heart_back":    ("one soft short note on a kalimba, muffled and kind", 0.6, -13, COZY_TUNE, "warm:2400", "ease:0.012", "body:300", "notes:0.14:3,8", "cut:0.7"),
        # The party.
        "stamp":    ("one soft short note on a kalimba, muffled and kind", 0.6, -9, COZY_TUNE, "warm:2600", "ease:0.012", "body:300", "notes:0.26:7,3,10"),
        "party":    ("one soft short note on a kalimba, muffled and kind", 0.6, -8, COZY_TUNE, "warm:2600", "ease:0.012", "body:300", "notes:0.14:2,5,9,5,9,11", "cut:1.9"),
        # The runaway hoop: drop's take, six slow notches, turning over and
        # settling down flat. Asked for twice as a hollow wooden wheel
        # turning, it came back 95% and 83% under 300 Hz: a slide that does
        # not pass is a row of ticks.
        "hoop":     ("one small hollow wooden ring set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -16, HUSH, "warm:1400", "cut:1.05", "body:320", "tight", "notes:0.17:2,0,2,0,-2,-3"),
        "purr":     ("one short soft contented chirrup, a little rolling trill with the mouth closed, gentle and happy", 1.0, -12, KITTEN, "warm:2400", "ease:0.01", "body:300"),
    },
    # Drumbeat (puzzles/drumbeat2d.gd): a band of drums at a garden festival
    # at dusk. The drums themselves (drum_0..3), the songs and their tunes
    # (song_*, lead_*) and the tap-along (calib) are synthesised by
    # tools/gen_drumbeat.py, not generated here: the drums play on every
    # stroke over the music and must start on their first sample.
    "drumbeat": {
        # Redone 2026-10-10 against the cozy rules (docs/agents/sound.md), the
        # thirty-eighth set of the redo, with Trestle's below. One kept,
        # `fail`, as it was: a kalimba phrase by its prompt, its raw the take
        # its file is made of. Seven more passed (clear, combo, echo_perfect,
        # full_combo, hold_done, shades, soul), but each names a hand bell or
        # a music box in its own prompt and clear and full_combo peaked at -5
        # and -4, so they are written again with the eighteen that failed.
        # Three new takes: `select` (a light wooden bead set down on felt),
        # `balloon` (a hollow wooden block, the thing a finger does over and
        # over, so the plainest: one tock) and one muffled kalimba note,
        # `clear`'s. Every tick is `tight`: what sounds on a stroke while the
        # song runs (balloon, pop, hold_done, combo, golden) starts on its
        # first samples. break is select's take, pop, hold_done, enter and
        # conga balloon's, and gogo, soul, echo, echo_perfect, golden, shades,
        # tune_done, full_combo, heart_lost, heart_back, out_of_hearts, stamp
        # and party the note's. Borrowed, of the same prompts: combo is Super
        # Slider's tick, reset Hedgehogs' breath (its reset), the balloon
        # flying off its whoosh and the cat Untangle's kitten. Nothing new is
        # a hand bell, a music box, a shaker, a lantern's rustle, a balloon's
        # squeak or whistle, coins, a rubber stamp or a party blower, and
        # nothing is above -8, under drums that peak at -1 to -5. The note
        # came back at 446 Hz, so the phrases' steps are 0 to 8 up and every
        # note lands between 400 and 710 Hz; no two cues share a contour.
        # balloon's take is one clean tock but sits at 778 Hz, so the balloon
        # and the cues made of it are written one to three steps down: the
        # board pitches the balloon up five semitones and it stays under
        # 900 Hz. Every tick starts at 0 ms.
        "select":       ("one small light wooden bead set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -16, HUSH, "warm:1400", "cut:0.1", "body:320", "tight"),
        # The band setting up: balloon's take, five in a row.
        "enter":        ("one small hollow wooden block set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -14, HUSH, "warm:1600", "cut:0.5", "body:320", "tight", "notes:0.08:-3,0,-3,-1,2"),
        "reset":        ("a soft breath of warm breeze that eases, fades and stops, calm, short", 0.8, -17, BREEZE, "warm:900", "steep", "ease:0.05", "body:320"),
        # In the song. gogo: four quick notes hopping up. soul (the gauge
        # past its line): three up. combo: a tick the board pitches by the
        # streak called, 3.7 semitones at most. break (a streak of ten or
        # more dropped): select's take, twice and falling. hold_done (a
        # ribbon held to its end): balloon's take, one notch two steps over it.
        "gogo":         ("one soft short note on a kalimba, muffled and kind", 0.6, -9, COZY_TUNE, "warm:2400", "ease:0.01", "body:300", "notes:0.1:0,4,2,7", "cut:0.9"),
        "soul":         ("one soft short note on a kalimba, muffled and kind", 0.6, -11, COZY_TUNE, "warm:2400", "ease:0.01", "body:300", "notes:0.11:3,5,8", "cut:0.8"),
        "combo":        ("one small wooden peg set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -14, HUSH, "warm:1600", "cut:0.1", "body:320", "tight"),
        "break":        ("one small light wooden bead set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1200", "cut:0.28", "body:320", "tight", "notes:0.11:0,-3"),
        "hold_done":    ("one small hollow wooden block set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -13, HUSH, "warm:1600", "cut:0.12", "body:320", "tight", "notes:0:-1"),
        # The balloon: a tock a stroke, which the board pitches by the
        # strokes so far, not past five semitones (CLIMB_TOP). pop: balloon's
        # take, two notches with the second four steps up. balloon_gone (not popped in
        # time): a long breath, the air going out of it.
        "balloon":      ("one small hollow wooden block set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -14, HUSH, "warm:1400", "cut:0.12", "body:320", "tight", "notes:0:-3"),
        "pop":          ("one small hollow wooden block set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -13, HUSH, "warm:1600", "cut:0.2", "body:320", "tight", "notes:0.06:-3,1"),
        "balloon_gone": ("a long soft gust of warm breeze through leaves, one gentle whoosh of air that rises slowly and fades", 1.0, -16, BREEZE, "warm:1100", "steep", "ease:0.1", "body:320"),
        # The song's end. clear: five up. full_combo: six, two climbs of
        # three, the second from a step higher. fail is the polish's take.
        "clear":        ("one soft short note on a kalimba, muffled and kind", 0.6, -9, COZY_TUNE, "warm:2000", "ease:0.012", "body:300", "notes:0.14:0,2,4,5,7", "cut:1.7"),
        "full_combo":   ("one soft short note on a kalimba, muffled and kind", 0.6, -9, COZY_TUNE, "warm:2200", "ease:0.012", "body:300", "notes:0.13:0,2,4,2,4,7", "cut:1.9"),
        "fail":         ("a gentle short descending kalimba phrase, a kind try again, soft and warm, never sad", 1.6, -9, FESTIVAL_TUNE, "warm:7000"),
        # Hearts (Hard and Insane).
        "heart_lost":   ("one soft short note on a kalimba, muffled and kind", 0.6, -14, COZY_TUNE, "warm:2000", "ease:0.012", "body:300", "notes:0:0", "cut:0.6"),
        "out_of_hearts":("one soft short note on a kalimba, muffled and kind", 0.6, -13, COZY_TUNE, "warm:2600", "ease:0.02", "body:300", "notes:0.32:7,4,0"),
        "heart_back":   ("one soft short note on a kalimba, muffled and kind", 0.6, -13, COZY_TUNE, "warm:2400", "ease:0.012", "body:300", "notes:0.14:2,7", "cut:0.7"),
        # Echo (Insane). echo: Tam's call, a question, the second note a step
        # higher. echo_perfect: the answer, two notes a third apart all but
        # together.
        "echo":         ("one soft short note on a kalimba, muffled and kind", 0.6, -10, COZY_TUNE, "warm:2400", "ease:0.01", "body:300", "notes:0.16:3,5", "cut:0.6"),
        "echo_perfect": ("one soft short note on a kalimba, muffled and kind", 0.6, -10, COZY_TUNE, "warm:2400", "ease:0.012", "body:300", "notes:0.03:1,5", "cut:0.7"),
        # The silly rewards. golden (the golden berry): a trill of four
        # quick notes a step apart. conga: balloon's take, four notches, three
        # alike and the last up. shades (the frog's sunglasses): three notes,
        # up and half back.
        "golden":       ("one soft short note on a kalimba, muffled and kind", 0.6, -10, COZY_TUNE, "warm:2400", "ease:0.01", "body:300", "notes:0.07:2,4,5,7", "cut:0.7"),
        "conga":        ("one small hollow wooden block set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -13, HUSH, "warm:1500", "cut:0.5", "body:320", "tight", "notes:0.12:-3,-3,-3,1"),
        "shades":       ("one soft short note on a kalimba, muffled and kind", 0.6, -11, COZY_TUNE, "warm:2400", "ease:0.01", "body:300", "notes:0.12:0,7,4", "cut:0.7"),
        # The tap-along done: two quiet notes alike and a third up.
        "tune_done":    ("one soft short note on a kalimba, muffled and kind", 0.6, -11, COZY_TUNE, "warm:2400", "ease:0.01", "body:300", "notes:0.12:0,0,4", "cut:0.7"),
        # The party.
        "stamp":        ("one soft short note on a kalimba, muffled and kind", 0.6, -9, COZY_TUNE, "warm:2600", "ease:0.012", "body:300", "notes:0.26:4,0,7"),
        "party":        ("one soft short note on a kalimba, muffled and kind", 0.6, -9, COZY_TUNE, "warm:2600", "ease:0.012", "body:300", "notes:0.14:0,3,7,3,7,8", "cut:1.9"),
        "purr":         ("one short soft contented chirrup, a little rolling trill with the mouth closed, gentle and happy", 1.0, -12, KITTEN, "warm:2400", "ease:0.01", "body:300"),
    },
    # Trestle (puzzles/trestle2d.gd): a bridge built of road planks, wooden
    # beams and rope over a river, then a little cart of fruit (on Insane
    # with cups of tea) sent across; the bridge troll keeps score.
    "trestle": {
        # Redone 2026-10-10 against the cozy rules (docs/agents/sound.md), the
        # thirty-ninth set of the redo, with Drumbeat's above. None kept:
        # seven passed, but the set was WORKSHOP_TUNE's (a music box and hand
        # bells by style; hint, solved, scorecard and heart_back by prompt
        # too, solved at -5), and the three that were plain kalimba falls
        # (fail, whoa, heart_lost) sound with notes written here, so they are
        # written from the same note and the set is in one tuning. Three new
        # takes: `place_wood` (a hollow wooden block set down on felt, the
        # thing a finger does all day, so the plainest: one tock), `select`
        # (a lighter thing set down) and one muffled kalimba note, `hint`'s.
        # Every tick is `tight`. place_road, reset, enter, snap, bump, cross
        # and scorecard are wood's take, place_rope, remove, refused, undo,
        # creak, snap_rope, clink, slosh and the ducks select's, and go,
        # honk, whoa, fail, solved, heart_lost, out_of_hearts, heart_back and
        # stamp the note's. Borrowed, of the same prompts: the cart's roll is
        # Snooker's loop of steady air, settle Hedgehogs' breath (its reset),
        # splash its gust, spill its whoosh and the cat Untangle's kitten.
        # Nothing new is pine, hemp, brass, a bicycle bell, a creak, a crack,
        # a twang, a rubber horn, china, tea, a splash, a duck, a music box
        # or a hand bell. Wood's take sits at 696 Hz, so place_wood is two
        # steps under it and nothing of it goes past three up; the note came
        # back at 353 Hz, so the phrases' steps are 3 to 12 up and every note
        # lands between 400 and 700 Hz; no two cues share a contour. Every
        # tock starts at 0 ms.
        "place_wood":    ("one small hollow wooden block set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -13, HUSH, "warm:1600", "cut:0.14", "body:320", "tight", "notes:0:-2"),
        # The road is the heavier plank: wood's take, three steps under it.
        "place_road":    ("one small hollow wooden block set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -13, HUSH, "warm:1400", "cut:0.16", "body:320", "tight", "notes:0:-5"),
        # Rope is the lighter thing: select's take, three steps up.
        "place_rope":    ("one small light wooden button set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1400", "cut:0.12", "body:320", "tight", "notes:0:3"),
        "select":        ("one small light wooden button set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -16, HUSH, "warm:1200", "cut:0.12", "body:320", "tight"),
        # A piece taken off: select's take, one notch two steps down.
        "remove":        ("one small light wooden button set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -16, HUSH, "warm:1200", "cut:0.12", "body:320", "tight", "notes:0:-2"),
        # Not there: two low notches alike. Taken back, and Stop: twice and
        # falling.
        "refused":       ("one small light wooden button set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1200", "cut:0.26", "body:320", "tight", "notes:0.1:-3,-3"),
        "undo":          ("one small light wooden button set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1200", "cut:0.28", "body:320", "tight", "notes:0.11:0,-3"),
        "hint":          ("one soft short note on a kalimba, muffled and kind", 0.6, -10, COZY_TUNE, "warm:2400", "ease:0.012", "body:300", "notes:0.16:3,7,10", "cut:1.0"),
        # Back to building: wood's take, five notches falling. The planks set
        # out: five in a row.
        "reset":         ("one small hollow wooden block set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1400", "cut:0.5", "body:320", "tight", "notes:0.08:3,1,-1,-2,-4"),
        "enter":         ("one small hollow wooden block set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -14, HUSH, "warm:1600", "cut:0.5", "body:320", "tight", "notes:0.08:-2,1,-2,0,3"),
        # Go: two notes alike and a third up. The cart is a loop of steady air
        # the board fades in and out and pitches by its load (0.85 to 1.1):
        # Snooker's roll, of the same prompt. honk: the horn at mid-span, two
        # quick notes alike.
        "go":            ("one soft short note on a kalimba, muffled and kind", 0.6, -10, COZY_TUNE, "warm:2400", "ease:0.01", "body:300", "notes:0.1:5,5,9", "cut:0.7"),
        "roll":          ("a continuous steady soft warm breath of air moving, smooth, constant and even, no gusts", 3.0, -15, BREEZE, "loop", "warm:1000", "steep", "body:320"),
        "honk":          ("one soft short note on a kalimba, muffled and kind", 0.6, -12, COZY_TUNE, "warm:2400", "ease:0.01", "body:300", "notes:0.13:8,8", "cut:0.5"),
        # A beam near its limit: select's take, three slow low notches. A beam
        # gone: wood's take, three notches, down and half back. A rope gone:
        # select's, two quick ones with the second five steps up.
        "creak":         ("one small light wooden button set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -14, HUSH, "warm:1200", "cut:0.4", "body:320", "tight", "notes:0.12:-3,-1,-3"),
        "snap":          ("one small hollow wooden block set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -12, HUSH, "warm:1500", "cut:0.3", "body:320", "tight", "notes:0.06:2,-4,-1"),
        "snap_rope":     ("one small light wooden button set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -14, HUSH, "warm:1400", "cut:0.2", "body:320", "tight", "notes:0.05:-1,4"),
        # The cart off the deck: a wobble, a step down and back. Landing on a
        # lower deck: wood's take, two notches all but together. Into the
        # river, and a piece taken down into it: a puff of air, Hedgehogs' gust.
        # fail: four notes that fall and come half back. cross: the wheels off
        # the deck onto the bank, wood's take twice with the second three steps
        # up; it sounds on the frame `solved` does, so it is not a phrase.
        "whoa":          ("one soft short note on a kalimba, muffled and kind", 0.6, -12, COZY_TUNE, "warm:2400", "ease:0.01", "body:300", "notes:0.09:7,5,7", "cut:0.5"),
        "bump":          ("one small hollow wooden block set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -13, HUSH, "warm:1400", "cut:0.2", "body:320", "tight", "notes:0.03:-6,-2"),
        "splash":        ("a tiny quick puff of warm air, one light short breath that rises and fades, very short", 0.6, -16, BREEZE, "warm:900", "steep", "ease:0.04", "body:320"),
        "fail":          ("one soft short note on a kalimba, muffled and kind", 0.6, -11, COZY_TUNE, "warm:2400", "ease:0.015", "body:300", "notes:0.2:10,7,3,5"),
        "cross":         ("one small hollow wooden block set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -14, HUSH, "warm:1600", "cut:0.26", "body:320", "tight", "notes:0.1:-2,1"),
        "solved":        ("one soft short note on a kalimba, muffled and kind", 0.6, -8, COZY_TUNE, "warm:2000", "ease:0.012", "body:300", "notes:0.14:3,5,7,10,12", "cut:1.7"),
        # The bridge easing back after a test: a breath, Hedgehogs' reset.
        "settle":        ("a soft breath of warm breeze that eases, fades and stops, calm, short", 0.8, -18, BREEZE, "warm:900", "steep", "ease:0.05", "body:320"),
        # Tea Party (Insane). clink: two cups of wood, select's take twice all
        # but together. slosh: the tea near the rim, three quick notches there
        # and back, the quietest thing here. spill: a longer breath, Hedgehogs'
        # whoosh.
        "clink":         ("one small light wooden button set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1400", "cut:0.16", "body:320", "tight", "notes:0.04:2,5"),
        "slosh":         ("one small light wooden button set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -16, HUSH, "warm:1200", "cut:0.24", "body:320", "tight", "notes:0.06:0,2,0"),
        "spill":         ("a long soft gust of warm breeze through leaves, one gentle whoosh of air that rises slowly and fades", 1.0, -16, BREEZE, "warm:1100", "steep", "ease:0.1", "body:320"),
        # Hearts (Hard and Insane). heart_lost sounds on the frame `fail` does,
        # so it is one low quiet note, a fifth under fail's first, and not a
        # second fall.
        "heart_lost":    ("one soft short note on a kalimba, muffled and kind", 0.6, -15, COZY_TUNE, "warm:2000", "ease:0.012", "body:300", "notes:0:3", "cut:0.6"),
        "out_of_hearts": ("one soft short note on a kalimba, muffled and kind", 0.6, -13, COZY_TUNE, "warm:2600", "ease:0.02", "body:300", "notes:0.32:12,8,3"),
        "heart_back":    ("one soft short note on a kalimba, muffled and kind", 0.6, -13, COZY_TUNE, "warm:2400", "ease:0.012", "body:300", "notes:0.14:5,10", "cut:0.7"),
        # The troll's card: wood's take, one notch three steps up. The seal:
        # three notes that dip and rise. The ducks: select's take, two low
        # notches and three above them. The cat: Untangle's kitten.
        "scorecard":     ("one small hollow wooden block set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -14, HUSH, "warm:1600", "cut:0.12", "body:320", "tight", "notes:0:3"),
        "stamp":         ("one soft short note on a kalimba, muffled and kind", 0.6, -9, COZY_TUNE, "warm:2600", "ease:0.012", "body:300", "notes:0.26:8,3,10"),
        "quack":         ("one small light wooden button set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -17, HUSH, "warm:1400", "cut:0.56", "body:320", "tight", "notes:0.11:-2,-2,3,3,3"),
        "purr":          ("one short soft contented chirrup, a little rolling trill with the mouth closed, gentle and happy", 1.0, -12, KITTEN, "warm:2400", "ease:0.01", "body:300"),
    },
    # Mini Golf (puzzles/minigolf2d.gd): a ball putted round a felt green
    # inside a wooden kerb, into a cup with a flag in it; the card's words
    # (hole in one, birdie, par, bogey) each have their own short phrase.
    "minigolf": {
        # Redone 2026-10-10 against the cozy rules (docs/agents/sound.md), the
        # fortieth set of the redo, with Horse Pen's below. None kept: eight
        # passed, but the set was LINKS_TUNE's (a music box and hand bells by
        # style, and by prompt in birdie, hint, heart_back and solved; solved
        # peaked at -5), enter was garden birds and splash a plop in a pond,
        # and the takes of birdie, par, bogey and heart_back sit at -21 to
        # -30 dB, so every cue is written again and the set is in one tuning.
        # Three new takes: `putt` (a hollow wooden block set down on felt,
        # the stroke under the finger, so the plainest: one tock), `wall` (a
        # lighter thing set down, the knock on every kerb) and one muffled
        # kalimba note, `hint`'s. Every tick is `tight`. sink and gate are
        # putt's take, post, lip, reset and enter wall's, and ace, birdie,
        # par, bogey, solved, out_of_hearts, heart_back, stamp and party the
        # note's. Borrowed, of the same prompts: sand is Hedgehogs' breath
        # (its reset), splash its gust, the next hole its whoosh and the cat
        # Untangle's kitten. Nothing new is a club's click, a clack off a
        # board, a rubber boing, a rattle in a plastic cup, sand hissing, a
        # plop, a flag, a hinge, a pencil, birds, a music box, a hand bell
        # or a party blower. putt's take holds a second knock 0.19 s behind
        # its tock, so it is cut at 0.14 and only the two cues that end
        # before that knock are written from it (sink's first notch is four
        # steps down, which puts it at 0.24, where the cut ends); the rows
        # are wall's take, which is one tock and nothing else. The note came
        # back at 376 Hz, so the phrases' steps are 2 to 11 up and every note
        # lands between 400 and 700 Hz; no two cues share a contour. wall's
        # tock starts at 20 ms, the others at 0.
        "putt":          ("one small hollow wooden block set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -13, HUSH, "warm:1600", "cut:0.14", "body:320", "tight"),
        # The kerb, pitched and levelled by how hard the ball met it. A post
        # is the same take one notch three steps up (the board adds a step a
        # post).
        "wall":          ("one small light wooden button set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1400", "cut:0.1", "body:320", "tight"),
        "post":          ("one small light wooden button set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1400", "cut:0.1", "body:320", "tight", "notes:0:3"),
        # Into the sand: a breath that eases and stops, Hedgehogs' reset.
        # Into the pond: a puff of air, its gust.
        "sand":          ("a soft breath of warm breeze that eases, fades and stops, calm, short", 0.8, -17, BREEZE, "warm:900", "steep", "ease:0.05", "body:320"),
        "splash":        ("a tiny quick puff of warm air, one light short breath that rises and fades, very short", 0.6, -16, BREEZE, "warm:900", "steep", "ease:0.04", "body:320"),
        # Round the rim and out: wall's take, three quick notches there and
        # back. In the cup: putt's take, two notches with the second four
        # steps up; the card's word follows 0.32 s behind, so it is not a
        # phrase.
        "lip":           ("one small light wooden button set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1400", "cut:0.24", "body:320", "tight", "notes:0.06:0,2,0"),
        "sink":          ("one small hollow wooden block set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -13, HUSH, "warm:1500", "cut:0.24", "body:320", "tight", "notes:0.1:-4,0"),
        # The card's words: the better the hole, the longer and the higher
        # the rise. A hole in one is two climbs of three, a birdie three up,
        # par two notes a third apart all but together, a bogey two with the
        # second two steps down.
        "ace":           ("one soft short note on a kalimba, muffled and kind", 0.6, -8, COZY_TUNE, "warm:2000", "ease:0.012", "body:300", "notes:0.1:2,5,9,4,7,11", "cut:1.3"),
        "birdie":        ("one soft short note on a kalimba, muffled and kind", 0.6, -10, COZY_TUNE, "warm:2400", "ease:0.012", "body:300", "notes:0.12:4,7,9", "cut:0.8"),
        "par":           ("one soft short note on a kalimba, muffled and kind", 0.6, -11, COZY_TUNE, "warm:2400", "ease:0.012", "body:300", "notes:0.03:4,7", "cut:0.6"),
        "bogey":         ("one soft short note on a kalimba, muffled and kind", 0.6, -12, COZY_TUNE, "warm:2400", "ease:0.012", "body:300", "notes:0.16:6,4", "cut:0.7"),
        # The next hole sliding in: a longer breath, Hedgehogs' whoosh. The
        # gates swapping: putt's take, two low notches all but together.
        "next":          ("a long soft gust of warm breeze through leaves, one gentle whoosh of air that rises slowly and fades", 1.0, -16, BREEZE, "warm:1100", "steep", "ease:0.1", "body:320"),
        "gate":          ("one small hollow wooden block set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -14, HUSH, "warm:1400", "cut:0.2", "body:320", "tight", "notes:0.03:-5,-2"),
        # The bulb: two notes alike and a third up.
        "hint":          ("one soft short note on a kalimba, muffled and kind", 0.6, -10, COZY_TUNE, "warm:2400", "ease:0.012", "body:300", "notes:0.16:3,3,7", "cut:1.0"),
        # The card blank again: wall's take, five notches falling. The course
        # set out: five in a row.
        "reset":         ("one small light wooden button set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1400", "cut:0.5", "body:320", "tight", "notes:0.08:5,3,1,0,-2"),
        "enter":         ("one small light wooden button set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -14, HUSH, "warm:1400", "cut:0.5", "body:320", "tight", "notes:0.08:0,3,0,2,5"),
        # The strokes run out (Insane), and the three handed back.
        "out_of_hearts": ("one soft short note on a kalimba, muffled and kind", 0.6, -13, COZY_TUNE, "warm:2600", "ease:0.02", "body:300", "notes:0.32:10,7,3"),
        "heart_back":    ("one soft short note on a kalimba, muffled and kind", 0.6, -13, COZY_TUNE, "warm:2400", "ease:0.012", "body:300", "notes:0.14:3,8", "cut:0.7"),
        # The round done: five up. The party: six up and over, the seal three
        # that dip and rise, the cat Untangle's kitten.
        "solved":        ("one soft short note on a kalimba, muffled and kind", 0.6, -8, COZY_TUNE, "warm:2000", "ease:0.012", "body:300", "notes:0.14:2,4,7,9,11", "cut:1.7"),
        "party":         ("one soft short note on a kalimba, muffled and kind", 0.6, -9, COZY_TUNE, "warm:2600", "ease:0.012", "body:300", "notes:0.14:2,5,9,5,9,11", "cut:1.9"),
        "stamp":         ("one soft short note on a kalimba, muffled and kind", 0.6, -9, COZY_TUNE, "warm:2600", "ease:0.012", "body:300", "notes:0.26:7,3,10"),
        "purr":          ("one short soft contented chirrup, a little rolling trill with the mouth closed, gentle and happy", 1.0, -12, KITTEN, "warm:2400", "ease:0.01", "body:300"),
    },
    # Horse Pen (puzzles/horse2d.gd): hay bales dropped on a meadow to pen a
    # pony in. `place` fires on every move and `lift` and `undo` nearly as
    # often; the notes are kept for the pen closing on its target and the
    # day's end, and the pony has its own voice.
    "horse": {
        # Redone 2026-10-10 against the cozy rules (docs/agents/sound.md), the
        # forty-first set of the redo, with Mini Golf's above. One kept: the
        # pony's `neigh`, its own take and prompt, rolled off and turned down
        # as Untangle's kitten was (an animal's voice is a character and does
        # not become notches). Six more passed (best, heart_back, hint,
        # locked, ready, solved), but the set was MEADOW_TUNE's (a wooden
        # music box and hand bells by style; best, hint, solved and
        # heart_back by prompt too, solved and best at -5 and -6) and locked
        # a knuckle on a fence post, so all are written from this set's
        # takes and it is in one tuning. Three new takes: `place` (a hollow
        # wooden block set down on felt, the thing a finger does all day, so
        # the plainest: one tock), `lift` (a lighter thing set down) and one
        # muffled kalimba note, `hint`'s. Every tick is `tight`. open,
        # not_yet and enter are place's take, undo, locked and closed lift's,
        # and ready, best, solved, party, stamp, out_of_hearts and heart_back
        # the note's. Borrowed, of the same prompt: reset is Hedgehogs'
        # breath (its reset). Nothing new is straw, grass, a hoof, a broom, a
        # fence post, a gate's latch, a music box, a hand bell, a rubber
        # stamp or a party blower. Place's take sits at 771 Hz cut at 320,
        # so `place` is two steps under it; lift's at 481 Hz so cut, so `lift` is
        # three steps over it and nothing of it goes under its take; the
        # note came back at 342 Hz, so the phrases' steps are 3 to 12 up and
        # every note lands between 400 and 700 Hz; no two cues share a
        # contour. Every tock starts at 0 ms.
        "enter":         ("one small hollow wooden block set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -14, HUSH, "warm:1600", "cut:0.5", "body:320", "tight", "notes:0.09:-5,-2,-5,-2"),
        "place":         ("one small hollow wooden block set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -13, HUSH, "warm:1600", "cut:0.14", "body:320", "tight", "notes:0:-2"),
        "lift":          ("one small light wooden button set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -16, HUSH, "warm:1400", "cut:0.12", "body:320", "tight", "notes:0:3"),
        # Taken back: lift's take, twice and falling.
        "undo":          ("one small light wooden button set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1400", "cut:0.28", "body:320", "tight", "notes:0.11:3,0"),
        # Every bale gone: a breath, Hedgehogs' reset.
        "reset":         ("a soft breath of warm breeze that eases, fades and stops, calm, short", 0.8, -17, BREEZE, "warm:900", "steep", "ease:0.05", "body:320"),
        # Not there (water, a stone, a tunnel, a pinned bale, no bales left):
        # lift's take, two low notches alike.
        "locked":        ("one small light wooden button set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1200", "cut:0.26", "body:320", "tight", "notes:0.1:0,0"),
        # The pen shut, short of its target: it sounds on the frame `place`
        # does, so it is lift's take, two notches with the second four steps
        # up. The pen open again sounds with `lift`, so it is place's take,
        # one notch four steps under place's.
        "closed":        ("one small light wooden button set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -14, HUSH, "warm:1400", "cut:0.24", "body:320", "tight", "notes:0.09:2,6"),
        "open":          ("one small hollow wooden block set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1400", "cut:0.14", "body:320", "tight", "notes:0:-6"),
        # The pen at its target: two notes a third apart all but together. At
        # the best there is: two alike and a third up. Either sounds over
        # `place`, a tock.
        "ready":         ("one soft short note on a kalimba, muffled and kind", 0.6, -10, COZY_TUNE, "warm:2400", "ease:0.012", "body:300", "notes:0.03:5,9", "cut:0.7"),
        "best":          ("one soft short note on a kalimba, muffled and kind", 0.6, -9, COZY_TUNE, "warm:2400", "ease:0.01", "body:300", "notes:0.1:7,7,11", "cut:0.8"),
        # Check on a pen that is open or too small: place's take, three slow
        # notches falling.
        "not_yet":       ("one small hollow wooden block set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -14, HUSH, "warm:1400", "cut:0.5", "body:320", "tight", "notes:0.14:-2,-4,-7"),
        "hint":          ("one soft short note on a kalimba, muffled and kind", 0.6, -10, COZY_TUNE, "warm:2400", "ease:0.012", "body:300", "notes:0.16:3,7,10", "cut:1.0"),
        # The pony patted: its own voice, a real one (PONY), the take of
        # 2026-10-08 with the top rolled off, 3 dB down.
        "neigh":         ("a small pony giving one short soft friendly nicker, a quiet breathy little whinny through the nose, cute and gentle, not loud, not dramatic, short", 0.9, -12, PONY, "warm:2400", "ease:0.01", "body:300"),
        # The day's end. `party` starts 0.4 s into `solved`, so solved is four
        # quick notes up and the party the long one, six up and over; the seal
        # 0.8 s after that, three notes that dip and rise.
        "solved":        ("one soft short note on a kalimba, muffled and kind", 0.6, -9, COZY_TUNE, "warm:2000", "ease:0.012", "body:300", "notes:0.1:5,7,9,12", "cut:0.9"),
        "party":         ("one soft short note on a kalimba, muffled and kind", 0.6, -9, COZY_TUNE, "warm:2600", "ease:0.012", "body:300", "notes:0.14:3,7,10,7,10,12", "cut:1.9"),
        "stamp":         ("one soft short note on a kalimba, muffled and kind", 0.6, -9, COZY_TUNE, "warm:2600", "ease:0.012", "body:300", "notes:0.26:8,3,10"),
        # Out of moves (Insane): three slow notes down. Five more: two a
        # fourth apart.
        "out_of_hearts": ("one soft short note on a kalimba, muffled and kind", 0.6, -13, COZY_TUNE, "warm:2600", "ease:0.02", "body:300", "notes:0.32:12,8,3"),
        "heart_back":    ("one soft short note on a kalimba, muffled and kind", 0.6, -13, COZY_TUNE, "warm:2400", "ease:0.012", "body:300", "notes:0.14:5,10", "cut:0.7"),
    },
    # Lattice (puzzles/lattice2d.gd): wooden number tiles swapped about a
    # lattice. `pick`, `swap` and one of `home`, `home2` or `miss` fire on
    # every move, so those five have no note in them (a tile home is a snug
    # seat, not a chime); the notes are kept for a whole line, the bulb and
    # the day's end.
    "lattice": {
        # Redone 2026-10-10 against the cozy rules (docs/agents/sound.md), the
        # forty-second set of the redo, with How Big?'s below. None kept: six
        # passed (heart_back, hint, home, home2, line, swap), but the notes were
        # TILES_TUNE's (a wooden music box and small hand bells by style, and
        # by prompt in line, hint and heart_back; line peaked at -7), home2's
        # take sat at -29 dB, and home and swap were a firm click at -8 and two
        # taps at -10, over the level of a tick, so every cue is written again
        # and the set is in one tuning. Three new takes: `drop` (a hollow
        # wooden block set down on felt, the tile under the finger, so the
        # plainest: one tock), `pick` (a lighter thing set down) and one muffled
        # kalimba note, `hint`'s. Every tick is `tight`. home and home2 are
        # drop's take, miss, undo, locked and enter pick's, and line, solved,
        # party, stamp, out_of_hearts and heart_back the note's. Borrowed, of
        # the same prompts: swap is Hedgehogs' gust and reset its breath (its
        # reset). Nothing new is a tile slid, swept, shuffled or clattered, a
        # click in a socket, a knuckle, a music box, a hand bell, a rubber stamp
        # or a party blower. Drop's take sits at 773 Hz cut at 320, so `drop` is
        # two steps under it and nothing of it goes past one up; pick's at 731;
        # the note came back at 453 Hz, so the phrases' steps are 2 down to 7 up
        # and every note lands between 400 and 700 Hz; no two cues share a
        # contour. Every tock starts at 0 ms.
        "drop":          ("one small hollow wooden block set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -13, HUSH, "warm:1600", "cut:0.1", "body:320", "tight", "notes:0:-2"),
        "pick":          ("one small light wooden button set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -16, HUSH, "warm:1400", "cut:0.1", "body:320", "tight"),
        # Two tiles crossing in their arc: what travels is air, a small puff,
        # Hedgehogs' gust. `hint` sounds on the frame it does, and with motion
        # reduced so does whichever of home, home2 and miss the swap earns, so
        # it is neither a notch nor a note.
        "swap":          ("a tiny quick puff of warm air, one light short breath that rises and fades, very short", 0.6, -16, BREEZE, "warm:900", "steep", "ease:0.04", "body:320"),
        # The swap landed, 0.24 s on. One tile home: drop's take, one notch
        # three steps over drop's. Two at once: two notches, the second four
        # steps up. Neither: pick's take, one notch four steps down.
        "home":          ("one small hollow wooden block set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -13, HUSH, "warm:1600", "cut:0.1", "body:320", "tight", "notes:0:1"),
        "home2":         ("one small hollow wooden block set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -13, HUSH, "warm:1600", "cut:0.2", "body:320", "tight", "notes:0.09:-3,1"),
        "miss":          ("one small light wooden button set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -16, HUSH, "warm:1200", "cut:0.12", "body:320", "tight", "notes:0:-4"),
        # Taken back: pick's take, twice and falling. Not that one (a tile at
        # home, two of one number): two low notches alike.
        "undo":          ("one small light wooden button set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1400", "cut:0.26", "body:320", "tight", "notes:0.11:0,-3"),
        "locked":        ("one small light wooden button set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1200", "cut:0.24", "body:320", "tight", "notes:0.1:-5,-5"),
        # The deal again: a breath, Hedgehogs' reset. The tiles popping onto the
        # lattice: pick's take, five in a row.
        "reset":         ("a soft breath of warm breeze that eases, fades and stops, calm, short", 0.8, -17, BREEZE, "warm:900", "steep", "ease:0.05", "body:320"),
        "enter":         ("one small light wooden button set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1400", "cut:0.5", "body:320", "tight", "notes:0.08:-4,-1,-4,-2,1"),
        # A whole line: it sounds on the frame home or home2 does, a tock under
        # it, so it is the one small note of the board, two a third apart all
        # but together. The bulb: two alike and a third up, over the puff.
        "line":          ("one soft short note on a kalimba, muffled and kind", 0.6, -11, COZY_TUNE, "warm:2400", "ease:0.012", "body:300", "notes:0.03:0,4", "cut:0.6"),
        "hint":          ("one soft short note on a kalimba, muffled and kind", 0.6, -10, COZY_TUNE, "warm:2400", "ease:0.012", "body:300", "notes:0.16:2,2,5", "cut:1.0"),
        # The day's end. `party` starts 0.15 s into `solved`, so solved is three
        # quick low notes a step apart, over by then, and the party takes the
        # rise from a step above its last: two climbs of three, the second from
        # a step up. The seal comes 0.55 s into that, on the party's fifth
        # note, so its first is a third under that one and not the same note
        # twice: three that dip and rise.
        "solved":        ("one soft short note on a kalimba, muffled and kind", 0.6, -9, COZY_TUNE, "warm:2000", "ease:0.012", "body:300", "notes:0.07:-2,0,2", "cut:0.6"),
        "party":         ("one soft short note on a kalimba, muffled and kind", 0.6, -9, COZY_TUNE, "warm:2600", "ease:0.012", "body:300", "notes:0.14:3,5,7,4,5,7", "cut:1.4"),
        "stamp":         ("one soft short note on a kalimba, muffled and kind", 0.6, -9, COZY_TUNE, "warm:2600", "ease:0.012", "body:300", "notes:0.26:2,0,7"),
        # Out of swaps (Insane): three slow notes down. Five more: two a fourth
        # apart.
        "out_of_hearts": ("one soft short note on a kalimba, muffled and kind", 0.6, -13, COZY_TUNE, "warm:2600", "ease:0.02", "body:300", "notes:0.32:7,3,-2"),
        "heart_back":    ("one soft short note on a kalimba, muffled and kind", 0.6, -13, COZY_TUNE, "warm:2400", "ease:0.012", "body:300", "notes:0.14:0,5", "cut:0.7"),
    },
    # How Big? (puzzles/how_big2d.gd, 2026-10-08): a carpenter's bench. The
    # one cue that repeats is `notch`, a click every time the answer grows or
    # shrinks by a twelfth while the finger pulls it: the wheel of an old
    # mouse spun under the finger, cut short, the quietest thing here, and
    # the board pitches it down a little as the thing gets bigger. A lock is
    # a tock; a reveal by its grade and the day's end happen now and then and
    # are notes.
    "how_big": {
        # Redone 2026-10-10 against the cozy rules (docs/agents/sound.md), the
        # forty-third set of the redo, with Lattice's above. None kept: five
        # passed (close, heart_back, hint, out_of_hearts, solved), but the set
        # was BENCH_TUNE's (a wooden music box and hand bells by style, and by
        # prompt in hint, heart_back, out_of_hearts and solved; solved peaked
        # at -5), and close's take sat at -30 dB, so every cue is written again
        # and the set is in one tuning. Three new takes: `lock` (a hollow
        # wooden block set down on felt, the tock under the finger), `notch` (a
        # lighter thing set down, the wheel's click) and one muffled kalimba
        # note, `hint`'s. Every tick is `tight`. enter, heart_lost and stamp
        # are lock's take, reset notch's, and spot, close, fair, off,
        # heart_back, out_of_hearts, solved and party the note's. Borrowed, of
        # the same prompt: the next round is Hedgehogs' gust. Nothing new is a
        # folding ruler, a clamp, a sheet of paper, a steel tape, a tongue
        # drum, a music box, a hand bell, a rubber stamp or a party blower.
        # Lock's take sits at 833 Hz cut at 320, over the lighter one's 706, so
        # `lock` is six steps under it and nothing of it is played at its own
        # pitch; the note came back at 504 Hz, so the phrases' steps are 4 down
        # to 5 up and every note lands between 400 and 673 Hz; no two cues
        # share a contour. Both takes are one tock and nothing else, and every
        # tock starts at 0 ms.
        # The bench set out: lock's take, five notches in a row.
        "enter":         ("one small hollow wooden block set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -14, HUSH, "warm:1600", "cut:0.5", "body:320", "tight", "notes:0.08:-7,-4,-7,-5,-2"),
        # One notch of the wheel, a step under its take. The board plays it at
        # 1.08 to 0.92 by the answer's size and 0.94 to 1.06 at random, -4 dB,
        # and fx's CUE_GAP holds two 60 ms apart.
        "notch":         ("one small light wooden button set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -16, HUSH, "warm:1400", "cut:0.07", "body:320", "tight", "notes:0:-1"),
        "lock":          ("one small hollow wooden block set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -13, HUSH, "warm:1600", "cut:0.14", "body:320", "tight", "notes:0:-6"),
        # The pair walking off and the next coming on: a puff of air,
        # Hedgehogs' gust.
        "next":          ("a tiny quick puff of warm air, one light short breath that rises and fades, very short", 0.6, -16, BREEZE, "warm:900", "steep", "ease:0.04", "body:320"),
        # The answer back where the round began, and the Ladder from its first
        # rung: notch's take, five notches falling, the wheel spun back.
        "reset":         ("one small light wooden button set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1400", "cut:0.5", "body:320", "tight", "notes:0.08:2,0,-2,-3,-5"),
        # The reveal by its grade: the better the guess, the longer and the
        # higher the rise. Spot on is two climbs of three, close three up, fair
        # two notes a third apart all but together, well off two with the
        # second two steps down.
        "spot":          ("one soft short note on a kalimba, muffled and kind", 0.6, -8, COZY_TUNE, "warm:2000", "ease:0.012", "body:300", "notes:0.1:-4,-1,3,-2,1,5", "cut:1.3"),
        "close":         ("one soft short note on a kalimba, muffled and kind", 0.6, -10, COZY_TUNE, "warm:2400", "ease:0.012", "body:300", "notes:0.12:-2,1,3", "cut:0.8"),
        "fair":          ("one soft short note on a kalimba, muffled and kind", 0.6, -11, COZY_TUNE, "warm:2400", "ease:0.012", "body:300", "notes:0.03:-1,2", "cut:0.6"),
        "off":           ("one soft short note on a kalimba, muffled and kind", 0.6, -12, COZY_TUNE, "warm:2400", "ease:0.012", "body:300", "notes:0.16:0,-2", "cut:0.7"),
        # The bulb: two notes alike and a third up.
        "hint":          ("one soft short note on a kalimba, muffled and kind", 0.6, -10, COZY_TUNE, "warm:2400", "ease:0.012", "body:300", "notes:0.16:-2,-2,2", "cut:1.0"),
        # Hearts (the Ladder). heart_lost sounds 75 ms ahead of `off` (the card
        # at 0.45 s, the grade at 0.525), so it is no note: lock's take, two low
        # notches alike, nine steps under the take. Out of them: three slow
        # notes down. One back: two a fourth apart.
        "heart_lost":    ("one small hollow wooden block set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1400", "cut:0.26", "body:320", "tight", "notes:0.1:-9,-9"),
        "heart_back":    ("one soft short note on a kalimba, muffled and kind", 0.6, -13, COZY_TUNE, "warm:2400", "ease:0.012", "body:300", "notes:0.14:-3,2", "cut:0.7"),
        "out_of_hearts": ("one soft short note on a kalimba, muffled and kind", 0.6, -13, COZY_TUNE, "warm:2600", "ease:0.02", "body:300", "notes:0.32:3,0,-4"),
        # The day's end. `party` and `stamp` both start 0.25 s into `solved`
        # (SOLVE_DELAY), so solved is four quick notes up, the party the long
        # one, six up and over, and the seal is no phrase: lock's take, two low
        # notches all but together, a thing pressed down.
        "solved":        ("one soft short note on a kalimba, muffled and kind", 0.6, -9, COZY_TUNE, "warm:2000", "ease:0.012", "body:300", "notes:0.1:-2,0,2,5", "cut:0.9"),
        "party":         ("one soft short note on a kalimba, muffled and kind", 0.6, -9, COZY_TUNE, "warm:2600", "ease:0.012", "body:300", "notes:0.14:-4,0,3,0,3,5", "cut:1.9"),
        "stamp":         ("one small hollow wooden block set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -13, HUSH, "warm:1400", "cut:0.2", "body:320", "tight", "notes:0.03:-9,-6"),
    },
    # Golden Acorn (puzzles/acorn2d.gd, 2026-10-08): a quiz at a card table.
    # `pick` is the one that repeats (every tap on an answer, and a player
    # in doubt taps several): a light wooden button set down on felt, cut
    # short, no note; `lock` is the tock under the finger, a hollow block.
    # The answer, the bulb and the day's end happen now and then and are a
    # few muffled notes. No drum roll and no buzzer: the held breath after a
    # lock is silence, and a wrong answer steps down two notes of a kalimba.
    "acorn": {
        # Redone 2026-10-10 against the cozy rules (docs/agents/sound.md), the
        # forty-fourth set of the redo, with Pearl Dive's below. None kept: seven
        # passed (heart_back, heart_lost, hint, out_of_hearts, party, right,
        # solved), but all seven were QUIZ_TUNE's (a wooden music box and small
        # hand bells by style, and a hand bell, a music box or a party blower by
        # prompt in right, hint, heart_back, out_of_hearts, solved and party;
        # right peaked at -6, solved and party at -5) and heart_lost a tongue
        # drum whose raw sat at -27 dB, so every cue is written again and the
        # set is in one tuning. Three new takes: `lock` (a hollow wooden block
        # set down on felt, the tock under the finger), `pick` (a lighter thing
        # set down) and one muffled kalimba note, `hint`'s. Every tick is
        # `tight`. enter and refuse are pick's take, heart_lost and stamp
        # lock's, and right, wrong, heart_back, out_of_hearts, solved and party
        # the note's. Borrowed, of the same prompt: next is Hedgehogs' gust.
        # Nothing new is an index card, a pencil, a knuckle, a tongue drum, a
        # music box, a hand bell, a rubber stamp or a party blower. Lock's take
        # sits at 695 Hz cut at 320, so `lock` is two steps under it; pick's at
        # 762 so cut, the lighter and the higher of the two, and nothing of it
        # is played over its own pitch; the note came back at 386 Hz, so the
        # phrases' steps are 1 to 10 up and every note lands between 400 and 700
        # Hz; no two cues share a contour. Every tock starts at 0 ms.
        # The cards laid out: pick's take, five notches in a row.
        "enter":         ("one small light wooden button set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -14, HUSH, "warm:1400", "cut:0.5", "body:320", "tight", "notes:0.08:-2,-5,-2,-4,0"),
        "pick":          ("one small light wooden button set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -16, HUSH, "warm:1400", "cut:0.1", "body:320", "tight"),
        "lock":          ("one small hollow wooden block set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -13, HUSH, "warm:1600", "cut:0.14", "body:320", "tight", "notes:0:-2"),
        # The next question is a page turned: air, Hedgehogs' gust. It sounds on
        # the frame heart_back does when a heart is taken back, a puff under two
        # notes.
        "next":          ("a tiny quick puff of warm air, one light short breath that rises and fades, very short", 0.6, -16, BREEZE, "warm:900", "steep", "ease:0.04", "body:320"),
        # Lock with nothing picked, the bulb with nothing left to cut: pick's
        # take, two low notches alike.
        "refuse":        ("one small light wooden button set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1200", "cut:0.26", "body:320", "tight", "notes:0.1:-5,-5"),
        # The verdict, 0.6 s after the lock (HOLD) and a dozen times a day, so
        # short: right is three quick notes up, wrong two with the second two
        # steps down.
        "right":         ("one soft short note on a kalimba, muffled and kind", 0.6, -10, COZY_TUNE, "warm:2400", "ease:0.012", "body:300", "notes:0.09:2,5,9", "cut:0.7"),
        "wrong":         ("one soft short note on a kalimba, muffled and kind", 0.6, -12, COZY_TUNE, "warm:2400", "ease:0.012", "body:300", "notes:0.16:5,3", "cut:0.7"),
        # The bulb: two notes alike and a third up.
        "hint":          ("one soft short note on a kalimba, muffled and kind", 0.6, -10, COZY_TUNE, "warm:2400", "ease:0.012", "body:300", "notes:0.16:3,3,7", "cut:1.0"),
        # Hearts (the Climb). heart_lost sounds 0.35 s behind `wrong` (WHY_AT),
        # inside its second note, so it is no note: lock's take, two low notches
        # with the second two steps down. Out of them: three slow notes down.
        # One back: two a fourth apart.
        "heart_lost":    ("one small hollow wooden block set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1400", "cut:0.26", "body:320", "tight", "notes:0.1:-5,-7"),
        "heart_back":    ("one soft short note on a kalimba, muffled and kind", 0.6, -13, COZY_TUNE, "warm:2400", "ease:0.012", "body:300", "notes:0.14:4,9", "cut:0.7"),
        "out_of_hearts": ("one soft short note on a kalimba, muffled and kind", 0.6, -13, COZY_TUNE, "warm:2600", "ease:0.02", "body:300", "notes:0.32:10,7,3"),
        # The day's end. `party` and `stamp` both start 0.25 s into `solved`
        # (SOLVE_DELAY), so solved is four quick notes struck inside 0.24 s, two
        # leaps of a fourth with the second from a step up, the party the long
        # one, six up and over, and the seal is no phrase: lock's take, two low
        # notches all but together, a thing pressed down.
        "solved":        ("one soft short note on a kalimba, muffled and kind", 0.6, -9, COZY_TUNE, "warm:2000", "ease:0.012", "body:300", "notes:0.08:1,6,3,8", "cut:0.9"),
        "party":         ("one soft short note on a kalimba, muffled and kind", 0.6, -9, COZY_TUNE, "warm:2600", "ease:0.012", "body:300", "notes:0.14:1,5,8,5,8,10", "cut:1.9"),
        "stamp":         ("one small hollow wooden block set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -13, HUSH, "warm:1400", "cut:0.2", "body:320", "tight", "notes:0.03:-8,-5"),
    },
    # Pearl Dive (puzzles/pearl2d.gd, 2026-10-09): a dive off a wooden jetty.
    # `tick` is the one that repeats (the clock's last five seconds, every
    # prompt that runs that low): one notch of a wheel, cut short, no note. A
    # miss can come several times a prompt, so it is two notches and no note
    # either. An answer is felt by its depth: the rarer it is, the longer and
    # the higher its notes rise. No buzzer and no alarm: the clock running
    # out is a small fall of two notes, and out of air three slow ones down.
    # What travels is air, and nothing is water.
    "pearl": {
        # Redone 2026-10-10 against the cozy rules (docs/agents/sound.md), the
        # forty-fifth set of the redo, with Golden Acorn's above. None kept:
        # six passed (air_back, deep, dry, out_of_air, party, solved), but the
        # notes were JETTY_TUNE's (a wooden music box and small hand bells by
        # style, and by prompt in out_of_air, solved and party; solved and
        # party peaked at -5), deep had a water drop in it, air_back was
        # bubbles, and the takes of deep, dry and party sat at -24 to -33 dB,
        # so every cue is written again and the set is in one tuning. Three
        # new takes: `miss` (a hollow wooden block set down on felt), `tick`
        # (a lighter thing set down, the clock's notch) and one muffled
        # kalimba note, `hint`'s. Every tick is `tight`. enter and stamp are
        # miss's take, refuse tick's, and hit, deep, pearl, dry, out_of_air,
        # solved and party the note's. Borrowed, of the same prompts: the
        # dive is Hedgehogs' whoosh, the next prompt its gust and the air
        # given back its breath (its reset). Nothing new is a wave, a rope's
        # creak, a pebble's plop, a drop, a bubble, a clock, a knuckle on a
        # plank, a music box, a hand bell, a rubber stamp or a party blower.
        # Miss's take sits at 692 Hz cut at 320 and tick's at 566, so `tick`
        # is two steps over its take (its weight out from under 300 Hz) and
        # `refuse` four under; the note came back at 331 Hz, so the phrases'
        # steps are 4 to 13 up and every note lands between 417 and 701 Hz;
        # no two cues share a contour. Both takes are one tock and nothing
        # else, and every tock starts at 0 ms.
        # The card standing ready: miss's take, five notches in a row.
        "enter":         ("one small hollow wooden block set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -14, HUSH, "warm:1600", "cut:0.5", "body:320", "tight", "notes:0.08:-4,-1,-4,-2,1"),
        # The dive: what travels is air, Hedgehogs' whoosh.
        "dive":          ("a long soft gust of warm breeze through leaves, one gentle whoosh of air that rises slowly and fades", 1.0, -16, BREEZE, "warm:1100", "steep", "ease:0.1", "body:320"),
        # The clock's last five seconds, one a second: one notch of the wheel,
        # at -14 (a light tick, but the one that says the time is going: it
        # reads -18 on a phone, as the old one did). The board varies it by
        # 0.94 to 1.06, and the miss and the refusal with it.
        "tick":          ("one small light wooden button set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -14, HUSH, "warm:1400", "cut:0.07", "body:320", "tight", "notes:0:2"),
        # Not on the list: twice and falling. It can sound on the frame `dry`
        # or `out_of_air` does (the miss's three seconds ran the clock out),
        # notches under a phrase. Enter on an empty line, and a bulb with
        # nothing left to tell: tick's take, two low notches alike.
        "miss":          ("one small hollow wooden block set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -13, HUSH, "warm:1600", "cut:0.26", "body:320", "tight", "notes:0.11:0,-3"),
        "refuse":        ("one small light wooden button set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1200", "cut:0.24", "body:320", "tight", "notes:0.1:-4,-4"),
        # An answer by its depth: the rarer the find, the longer and the
        # higher the rise. A common one is two notes a third apart all but
        # together, a rare one three up, the Pearl two climbs of three; a
        # prompt left dry two with the second two steps down.
        "hit":           ("one soft short note on a kalimba, muffled and kind", 0.6, -12, COZY_TUNE, "warm:2400", "ease:0.012", "body:300", "notes:0.03:4,8", "cut:0.6"),
        "deep":          ("one soft short note on a kalimba, muffled and kind", 0.6, -10, COZY_TUNE, "warm:2400", "ease:0.012", "body:300", "notes:0.12:6,9,11", "cut:0.8"),
        "pearl":         ("one soft short note on a kalimba, muffled and kind", 0.6, -9, COZY_TUNE, "warm:2000", "ease:0.012", "body:300", "notes:0.1:4,8,11,6,9,13", "cut:1.3"),
        "dry":           ("one soft short note on a kalimba, muffled and kind", 0.6, -12, COZY_TUNE, "warm:2400", "ease:0.012", "body:300", "notes:0.16:8,6", "cut:0.7"),
        # The next prompt: a puff of air, Hedgehogs' gust.
        "next":          ("a tiny quick puff of warm air, one light short breath that rises and fades, very short", 0.6, -16, BREEZE, "warm:900", "steep", "ease:0.04", "body:320"),
        # The bulb: two notes alike and a third up.
        "hint":          ("one soft short note on a kalimba, muffled and kind", 0.6, -10, COZY_TUNE, "warm:2400", "ease:0.012", "body:300", "notes:0.16:5,5,9", "cut:1.0"),
        # One Breath (Insane). Air given back sounds 0.25 s into the answer's
        # own notes, so it is no phrase: a breath, Hedgehogs' reset. Out of
        # air: three slow notes down.
        "air_back":      ("a soft breath of warm breeze that eases, fades and stops, calm, short", 0.8, -17, BREEZE, "warm:900", "steep", "ease:0.05", "body:320"),
        "out_of_air":    ("one soft short note on a kalimba, muffled and kind", 0.6, -13, COZY_TUNE, "warm:2600", "ease:0.02", "body:300", "notes:0.32:11,8,4"),
        # The day's end. `party` and `stamp` both start 0.25 s into `solved`
        # (SOLVE_DELAY), so solved is four quick notes up, the last struck at
        # 0.21 s, the party the long one, six up and over, and the seal is no
        # phrase: miss's take, two low notches all but together, a thing
        # pressed down.
        "solved":        ("one soft short note on a kalimba, muffled and kind", 0.6, -9, COZY_TUNE, "warm:2000", "ease:0.012", "body:300", "notes:0.07:4,6,8,11", "cut:0.7"),
        "party":         ("one soft short note on a kalimba, muffled and kind", 0.6, -9, COZY_TUNE, "warm:2600", "ease:0.012", "body:300", "notes:0.14:4,8,11,8,11,13", "cut:1.9"),
        "stamp":         ("one small hollow wooden block set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -13, HUSH, "warm:1400", "cut:0.2", "body:320", "tight", "notes:0.03:-7,-4"),
    },
    # Toy Boats (Versus, versus/boats_screen.gd). Redone 2026-10-10 against
    # the cozy rules (docs/agents/sound.md), the forty-sixth set of the redo,
    # with Penny Drop's below. None kept. Nothing new is water, a plop, a
    # drip, a swish, a glug, a bubble, a latch, a creak or a pebble: a boat
    # set down is a wooden block on felt. Three takes: `place` (the block),
    # `lift` (a lighter button) and `hint`'s one muffled note. A game is a
    # hundred throws, so what a throw makes is a notch or air with no note:
    # the pebble on its way is air (Hedgehogs' gust, and its breath for the
    # other player's), yours answered a low notch (`miss`) or two rising
    # (`hit`), theirs a dull tock (`splash`, wide of your boats) or two
    # falling (`knock`). `tick` is the finger crossing a square of the slate
    # and a boat carried a square, the quietest thing in the set and still
    # played by a phone. The notes are kept for what happens five times a
    # game or once: `sunk` rises, `glug` (a boat of yours gone) is a small
    # fall, `hint`, `win`, `lose`. `ready` and `fold` sound on one frame
    # against the computer, so the first is two notches pressed down and the
    # second air (Hedgehogs' whoosh): the box swung over.
    "boats": {
        # The five boats set out: place's take, five in a row.
        "enter":    ("one small hollow wooden block set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -14, HUSH, "warm:1600", "cut:0.5", "body:320", "tight", "notes:0.08:-4,-2,0,-2,1"),
        "lift":     ("one small light wooden button set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -16, HUSH, "warm:1300", "cut:0.12", "body:320", "tight"),
        # A boat set down: the block, four steps under its take to be the
        # heavier of the two (the take sat at 820 Hz, the button at 670).
        "place":    ("one small hollow wooden block set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -13, HUSH, "warm:1600", "cut:0.14", "body:320", "tight", "notes:0:-4"),
        # A quarter turn: lift's take, two notches close, the second three steps up.
        "turn":     ("one small light wooden button set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1300", "cut:0.2", "body:320", "tight", "notes:0.07:0,3"),
        # A square crossed: lift's take, one notch of the wheel two steps up.
        "tick":     ("one small light wooden button set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -17, HUSH, "warm:1300", "cut:0.07", "body:320", "tight", "notes:0:2"),
        # No room, or a square already tried: lift's take, twice and falling.
        "refused":  ("one small light wooden button set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1200", "cut:0.28", "body:320", "tight", "notes:0.11:0,-3"),
        # The lid pressed shut: place's take, two low notches all but together.
        "ready":    ("one small hollow wooden block set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -13, HUSH, "warm:1400", "cut:0.2", "body:320", "tight", "notes:0.03:-7,-4"),
        # The box swung over: a whoosh of air, Hedgehogs'.
        "fold":     ("a long soft gust of warm breeze through leaves, one gentle whoosh of air that rises slowly and fades", 1.0, -16, BREEZE, "warm:1100", "steep", "ease:0.1", "body:320"),
        # A pebble on its way: yours a puff of air, Hedgehogs' gust; the
        # other player's, coming down, its breath (its reset).
        "throw":    ("a tiny quick puff of warm air, one light short breath that rises and fades, very short", 0.6, -16, BREEZE, "warm:900", "steep", "ease:0.04", "body:320"),
        "lob":      ("a soft breath of warm breeze that eases, fades and stops, calm, short", 0.8, -17, BREEZE, "warm:900", "steep", "ease:0.05", "body:320"),
        # Yours, wide: lift's take, one low notch.
        "miss":     ("one small light wooden button set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1200", "cut:0.14", "body:320", "tight", "notes:0:-4"),
        # Theirs, wide of your boats: place's, three steps under it and duller.
        "splash":   ("one small hollow wooden block set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -14, HUSH, "warm:1200", "cut:0.14", "body:320", "tight", "notes:0:-7"),
        # Yours on a boat: place's take, two notches, the second four steps up.
        "hit":      ("one small hollow wooden block set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -12, HUSH, "warm:1600", "cut:0.24", "body:320", "tight", "notes:0.08:-4,0"),
        # Theirs on a boat of yours: place's take, two notches, the second three steps down.
        "knock":    ("one small hollow wooden block set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -13, HUSH, "warm:1400", "cut:0.26", "body:320", "tight", "notes:0.1:-2,-5"),
        # A boat of theirs gone: three quick notes up.
        "sunk":     ("one soft short note on a kalimba, muffled and kind", 0.6, -10, COZY_TUNE, "warm:2400", "ease:0.012", "body:300", "notes:0.1:5,9,12", "cut:0.7"),
        # A boat of yours gone: two notes, the second two steps down.
        "glug":     ("one soft short note on a kalimba, muffled and kind", 0.6, -12, COZY_TUNE, "warm:2400", "ease:0.012", "body:300", "notes:0.16:8,6", "cut:0.7"),
        # The bulb: two notes alike and a third up.
        "hint":     ("one soft short note on a kalimba, muffled and kind", 0.6, -10, COZY_TUNE, "warm:2400", "ease:0.012", "body:300", "notes:0.16:5,5,9", "cut:1.0"),
        # Six up and over.
        "win":      ("one soft short note on a kalimba, muffled and kind", 0.6, -9, COZY_TUNE, "warm:2600", "ease:0.012", "body:300", "notes:0.14:4,8,11,8,11,13", "cut:1.9"),
        # Three slow ones down, small and kind.
        "lose":     ("one soft short note on a kalimba, muffled and kind", 0.6, -13, COZY_TUNE, "warm:2600", "ease:0.02", "body:300", "notes:0.32:11,8,4"),
    },
    # Penny Drop (Versus, versus/penny_screen.gd): a painted wooden rack and
    # two rolls of pennies. A game is up to forty-two drops, so everything a
    # drop makes is dry and short with no note, and the notes are kept for
    # what happens once a game.
    "penny": {
        # Redone 2026-10-10 against the cozy rules (docs/agents/sound.md), the
        # forty-seventh set of the redo, with Toy Boats' above. None kept:
        # all ten were flagged. The six of HEARTH's foley were coins on wood
        # (a slide of metal, a clack, a scrape, a handful tumbling), 52 to
        # 95% above 3 kHz from takes that were all scratch, and `tick` a
        # thump at 113 Hz a phone does not play; the four of HEARTH_TUNE's
        # kalimba sat at 223 to 330 Hz, -28 to -46 dB on a phone. Three new
        # takes: `land` (a hollow wooden block set down on felt, the knock
        # under every move, so the plainest: one tock), `lift` (a lighter
        # thing set down) and one muffled kalimba note, `hint`'s. Every tick
        # is `tight`. tick, refused and spill are lift's take, win, lose and
        # draw the note's, and `drop` is Hedgehogs' gust, of the same
        # prompt. A coin never rings, so nothing new is a coin, a slot, a
        # clack, a scrape or a tumble of metal: a penny is a wooden thing on
        # felt.
        # The penny let go: a puff of air, cut short because the knock comes
        # 0.23 s behind it on a full column (0.52 s on an empty one).
        "drop":     ("a tiny quick puff of warm air, one light short breath that rises and fades, very short", 0.6, -18, BREEZE, "warm:900", "steep", "ease:0.04", "body:320", "cut:0.22"),
        # Its knock on what is below: the board plays it 1.08 to 0.92, lower
        # and up to 5.5 dB louder the further it fell.
        "land":     ("one small hollow wooden block set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -13, HUSH, "warm:1600", "cut:0.14", "body:320", "tight"),
        # A penny taken back out of the top of its column.
        "lift":     ("one small light wooden button set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -16, HUSH, "warm:1300", "cut:0.12", "body:320", "tight"),
        # The finger crossing to another slot: lift's take, one notch of the
        # wheel two steps up, the quietest thing in the set.
        "tick":     ("one small light wooden button set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -17, HUSH, "warm:1400", "cut:0.07", "body:320", "tight", "notes:0:2"),
        # A full column: lift's take, two low notches alike.
        "refused":  ("one small light wooden button set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1200", "cut:0.26", "body:320", "tight", "notes:0.1:-3,-3"),
        # The rack emptied before a new game: lift's take, seven notches
        # tumbling down, the bottom row first.
        "spill":    ("one small light wooden button set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -16, HUSH, "warm:1300", "cut:0.62", "body:320", "tight", "notes:0.07:4,2,3,0,1,-2,-4"),
        "hint":     ("one soft short note on a kalimba, muffled and kind", 0.6, -11, COZY_TUNE, "warm:2400", "ease:0.012", "body:300", "notes:0.14:5,9", "cut:0.6"),
        "win":      ("one soft short note on a kalimba, muffled and kind", 0.6, -9, COZY_TUNE, "warm:2000", "ease:0.012", "body:300", "notes:0.14:4,7,9,11,12", "cut:1.5"),
        "lose":     ("one soft short note on a kalimba, muffled and kind", 0.6, -11, COZY_TUNE, "warm:2400", "ease:0.015", "body:300", "notes:0.26:9,7,4", "cut:1.1"),
        "draw":     ("one soft short note on a kalimba, muffled and kind", 0.6, -10, COZY_TUNE, "warm:2400", "ease:0.01", "body:300", "notes:0.24:7,7", "cut:0.8"),
    },
    # Dominoes (Versus, versus/dominoes_screen.gd): thick wooden tiles on a
    # felt mat. A hand is twenty-odd tiles laid and a game four hands or so,
    # so everything a tile does is dry, low and short with no note, and the
    # notes are kept for a hand's end, the bulb and the game's end.
    "dominoes": {
        # Redone 2026-10-10 against the cozy rules (docs/agents/sound.md), the
        # forty-eighth set of the redo, with Reversi's below. None kept: nine
        # of eleven were flagged, and the two that passed (`place`, `lift`)
        # are written again so the set is in one tuning (lift's take was a
        # thump at 178 Hz). The five of HEARTH_TUNE's kalimba sat at 194 to
        # 330 Hz and read -44 to -47 on a phone (`win` -21, 98% under 300
        # Hz), so a hand's end and the game's were all but silent there;
        # `refused` was 42 Hz from an empty take, `draw` 85% under 300 Hz,
        # `knock` a thump, `shuffle` a scratch take filtered. Three new takes:
        # `place` (a hollow wooden block set down on felt, the tock under
        # every move, so the plainest: one tock), `lift` (a lighter thing set
        # down) and one muffled kalimba note, `hint`'s. Every tick is
        # `tight`. knock is place's take, draw, refused and shuffle lift's,
        # out, lost_hand, win and lose the note's. Nothing new is a knuckle,
        # a table, a tile slid, a clack or a stir of tiles: a tile is a
        # wooden thing on felt.
        "place":     ("one small hollow wooden block set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -13, HUSH, "warm:1600", "cut:0.14", "body:320", "tight", "notes:0:-4"),
        # A tile picked to choose its end.
        "lift":      ("one small light wooden button set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -16, HUSH, "warm:1300", "cut:0.12", "body:320", "tight"),
        # One taken from the boneyard, by either hand: lift's take, one notch
        # of the wheel two steps up, the quietest thing in the set.
        "draw":      ("one small light wooden button set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -17, HUSH, "warm:1400", "cut:0.09", "body:320", "tight", "notes:0:2"),
        # A tile that fits neither end, or the boneyard tapped with a tile
        # that fits: lift's take, twice and falling.
        "refused":   ("one small light wooden button set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1200", "cut:0.28", "body:320", "tight", "notes:0.11:0,-3"),
        # A pass, "I cannot go", and a hand tied: place's take, two low
        # notches alike.
        "knock":     ("one small hollow wooden block set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -13, HUSH, "warm:1400", "cut:0.3", "body:320", "tight", "notes:0.13:-7,-7"),
        # The tiles stirred before a deal, once a hand: lift's take, the
        # wheel spun, nine notches wandering over the deal's first second.
        "shuffle":   ("one small light wooden button set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -17, HUSH, "warm:1300", "cut:0.95", "body:320", "tight", "notes:0.1:0,3,-2,2,-1,4,1,-3,0"),
        # Your hand emptied, or a blocked hand yours: three quick notes up.
        "out":       ("one soft short note on a kalimba, muffled and kind", 0.6, -10, COZY_TUNE, "warm:2400", "ease:0.012", "body:300", "notes:0.1:4,8,11", "cut:0.7"),
        # The hand theirs: two notes, the second two steps down.
        "lost_hand": ("one soft short note on a kalimba, muffled and kind", 0.6, -12, COZY_TUNE, "warm:2400", "ease:0.012", "body:300", "notes:0.16:7,5", "cut:0.7"),
        # The bulb: two notes alike and a third up.
        "hint":      ("one soft short note on a kalimba, muffled and kind", 0.6, -10, COZY_TUNE, "warm:2400", "ease:0.012", "body:300", "notes:0.16:4,4,8", "cut:1.0"),
        # First to fifty: six up and over.
        "win":       ("one soft short note on a kalimba, muffled and kind", 0.6, -9, COZY_TUNE, "warm:2600", "ease:0.012", "body:300", "notes:0.14:3,7,10,7,10,11", "cut:1.9"),
        # Three slow ones down, small and kind.
        "lose":      ("one soft short note on a kalimba, muffled and kind", 0.6, -13, COZY_TUNE, "warm:2600", "ease:0.02", "body:300", "notes:0.32:10,7,3"),
    },
    # Reversi (Versus, versus/reversi_screen.gd): thick two-faced wooden discs
    # on a painted wooden board. A game is sixty discs set down and a few
    # hundred turned over, so everything a disc does is dry, low and short
    # with no note, and the notes are kept for the bulb and the end.
    "reversi": {
        # Redone 2026-10-10 against the cozy rules (docs/agents/sound.md), the
        # forty-ninth set of the redo, with Dominoes' above. None kept.
        # Three new takes: `place` (a hollow wooden block set down on felt,
        # the tock under every move), `lift` (a lighter button) and one
        # muffled kalimba note, `hint`'s. Every tick is `tight`. flip and
        # refused are lift's take, pass place's, win, lose and draw the
        # note's, and `sweep` is Hedgehogs' breath, of the same prompt.
        # Nothing new is a knuckle on a frame, a disc tapped flat, a thud or
        # a tongue drum (flip and place passed and are not kept: place's raw
        # was 67% under 300 Hz, and the set is in one tuning). The old
        # sweep, five ticks asked for in one take, came back 90% above 3 kHz.
        # A disc set on its square: the block, three steps under its take to
        # be the heavier of the two (the take sat at 684 Hz, as the button).
        "place":   ("one small hollow wooden block set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -13, HUSH, "warm:1600", "cut:0.14", "body:320", "tight", "notes:0:-3"),
        # A move taken back: the lighter thing set down.
        "lift":    ("one small light wooden button set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -16, HUSH, "warm:1300", "cut:0.12", "body:320", "tight"),
        # One ring of discs turned over, up to seven a move 85 ms apart:
        # lift's take, one notch of the wheel two steps up, from 0 ms. The
        # board plays it half a step higher a ring and 3 dB down on the
        # first (versus/reversi_board.gd, FLIP_PITCH).
        "flip":    ("one small light wooden button set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -16, HUSH, "warm:1400", "cut:0.07", "body:320", "tight", "notes:0:2"),
        # A square that turns nothing: lift's take, twice and falling.
        "refused": ("one small light wooden button set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1200", "cut:0.28", "body:320", "tight", "notes:0.11:0,-3"),
        # No square to play, the turn handed back: place's take, two low
        # notches alike.
        "pass":    ("one small hollow wooden block set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -13, HUSH, "warm:1400", "cut:0.3", "body:320", "tight", "notes:0.14:-5,-5"),
        # The board cleared for a new game, the discs going off corner to
        # corner in 0.3 s: a breath of air, Hedgehogs' (its reset).
        "sweep":   ("a soft breath of warm breeze that eases, fades and stops, calm, short", 0.8, -17, BREEZE, "warm:900", "steep", "ease:0.05", "body:320"),
        # The note came back at 340 Hz and -28 dB: steps 4 to 12 land every
        # note at 428 to 680 Hz. The bulb: two notes up; a win five up, a
        # loss three slow ones down, a draw two alike.
        "hint":    ("one soft short note on a kalimba, muffled and kind", 0.6, -11, COZY_TUNE, "warm:2400", "ease:0.012", "body:300", "notes:0.14:5,9", "cut:0.6"),
        "win":     ("one soft short note on a kalimba, muffled and kind", 0.6, -9, COZY_TUNE, "warm:2400", "ease:0.012", "body:300", "notes:0.14:4,7,9,11,12", "cut:1.5"),
        "lose":    ("one soft short note on a kalimba, muffled and kind", 0.6, -11, COZY_TUNE, "warm:2400", "ease:0.015", "body:300", "notes:0.26:9,7,4", "cut:1.1"),
        "draw":    ("one soft short note on a kalimba, muffled and kind", 0.6, -10, COZY_TUNE, "warm:2400", "ease:0.01", "body:300", "notes:0.24:7,7", "cut:0.8"),
    },
    # the gifts, the shop and the gold pill (spec 2026-09-28-gold-gifts), keyed
    # by the sheets' own puzzle_id "wallet"
    "wallet": {
        "claim":    ("a small gift box opening with a soft paper rustle then a bright shower of little gold coins jingling, cheerful, short", 1.2, -5),
        "buy":      ("a few small gold coins dropped onto a wooden counter with a soft happy chime, short", 0.7, -7),
        "coin":     ("a single tiny soft gold coin clink, very short", 0.5, -14),
        "refused":  ("a soft low wooden double knock, a gentle not yet, very short", 0.5, -10),
    },
    # The Grove (valley/grove_screen.gd, 2026-10-05). `chop` plays on every
    # swing that hits for as long as a finger is held, twice a second at the
    # start and six times late on: a click, cut short and the quietest file
    # of the set. A tree down and a tile bought happen now and then.
    "grove": {
        "chop": ("one small dry knock of a little hatchet biting into a thin green sapling, a short soft wooden tick, very short and quiet", 0.5, -18, GROVE, "warm:6000", "cut:0.09"),
        "fell": ("a thin young tree coming down: one soft green-wood crack and a short hush of leaves settling on grass, gentle, short", 0.7, -11, GROVE),
        "buy":  ("two soft rising notes on a real kalimba, warm and woody, something made a little better, short", 0.6, -9, ARCADE),
        "no":   ("a soft low wooden double knock, a gentle not yet, very short", 0.5, -12, GROVE),
    },
    # Nightlight (arcade/nightlight_screen.gd, 2026-10-06; made quieter and
    # darker on 2026-10-09, when the user had heard it: "too harsh, I want
    # something way more cozier, subtle"). Three cues go on for as long as
    # the game does and are clicks, cut short, the quietest of the set:
    # `pour` (the press that braked something, five a second at most),
    # `light` (a mote of light landing on its plate, a short run up) and
    # `eat` (a solid falling into the star). Everything else happens now and
    # then and may be a note: a body torn, a stage of the chain lighting
    # (five a life at most), the star going dim and waking, the two powers
    # offered, one taken, a tile bought or refused, and the two ends with
    # the small star that comes after. Every cue is rolled off (`warm`) and
    # eased in (`ease`), and no note peaks above -11 but the supernova,
    # whose thump is followed by low notes because a whump alone is not
    # there on a phone's speaker. A prompt and its style together are 450
    # characters at most.
    "nightlight": {
        "pour":   ("one soft low muffled pat of a fingertip on a thick wool blanket over a wooden table, a dull round 'pup', very short and quiet", 0.5, -24, HEARTH_TAP, "warm:2400", "cut:0.11", "tight", "ease:0.01"),
        "light":  ("one very soft low tap of a felt mallet on a small hollow wooden box, a round dull 'tok', very short and quiet", 0.5, -22, HEARTH_TAP, "warm:2800", "cut:0.13", "tight", "ease:0.008"),
        "eat":    ("one soft low round 'plop' of a small pebble dropped into a felt-lined wooden bowl, dull and muffled, short", 0.5, -18, HEARTH_TAP, "warm:2800", "cut:0.22", "tight", "ease:0.01"),
        "tear":   ("three soft low muffled taps of small wooden beads falling one after another on a wool blanket, dull and round, gentle, short", 0.6, -18, HEARTH_TAP, "warm:1800", "ease:0.015"),
        "ignite": ("one low warm round note on the tongue drum, then one soft kalimba note blooming under it, something glowing deep inside, slow, about one second", 1.3, -11, HEARTH_TUNE, "warm:5000", "ease:0.015"),
        "dim":    ("two slow soft low notes stepping down on the tongue drum, a lamp turned low, gentle and kind, never sad", 1.0, -14, HEARTH_TUNE, "warm:5000", "ease:0.015"),
        "wake":   ("two soft low rising notes on the kalimba, a small lamp coming back on, warm, short", 0.7, -13, HEARTH_TUNE, "warm:5000", "ease:0.015"),
        "pick":   ("three slow soft rising notes on the kalimba, a quiet choice being offered, short", 0.9, -13, HEARTH_TUNE, "warm:5000", "ease:0.015"),
        "perk":   ("one warm low kalimba pluck with one soft tongue drum note under it, a small gift taken, short", 0.7, -12, HEARTH_TUNE, "warm:5000", "ease:0.015"),
        "buy":    ("two soft low rising notes on the kalimba, warm and woody, something made a little better, short", 0.6, -13, HEARTH_TUNE, "warm:5000", "ease:0.015"),
        # the first take's knock, kept: one asked for on felt came back with nothing above 400 Hz
        "no":     ("a soft low wooden double knock, a gentle not yet, very short", 0.5, -16, ARCADE, "warm:4500", "ease:0.012"),
        "nova":   ("a soft breath drawn in, one big round soft low 'whoomp' of a heavy wool blanket shaken out, then a few slow soft low kalimba and tongue drum notes falling far apart for three seconds, fading away", 5.0, -8, HEARTH_TUNE, "warm:5500", "ease:0.03"),
        "fade":   ("one long slow soft exhale of air through wool, with four slow gentle low kalimba notes stepping down far apart over it, something letting go, calm and kind, never sad", 5.0, -12, HEARTH_TUNE, "warm:5000", "ease:0.04"),
        "born":   ("three slow soft rising notes on the kalimba ending on one warm tongue drum note, a new little light beginning, hopeful, short", 1.4, -12, HEARTH_TUNE, "warm:5000", "ease:0.015"),
    },
    # Beeline (arcade/beeline_screen.gd, 2026-10-09): a bee flown through the
    # gaps in a garden's hedges. Two cues never stop and are dull low taps,
    # the quietest of the set: `flap` (every beat of the wings, two or three
    # a second) and `pass` (a gap behind her, one every second and a
    # quarter). The rest happens now and then: a hedge met, the grass, a
    # dewdrop bursting, a ribbon (four a run at most) and the run's two
    # ends. Nightlight's lesson is kept: low, dark, quiet, eased in, no
    # bell and nothing bright. The same day the user heard the rewards and
    # nothing else: `flap`, `pass` and `land` were HEARTH_TAP's felt at -25,
    # -21 and -16 under a 2400-3200 Hz roll-off, which left nothing above
    # 400 Hz for a phone's speaker (-40 dB and under). They are dry taps on
    # thin wood now, still with no note, at -15, -13 and -12 and rolled off
    # near 5 kHz.
    "beeline": {
        "flap":      ("one small soft dry tap of a fingertip on a thin smooth wooden box, a light round woody 'tup' with a clear body, gentle, very short", 0.5, -15, FOLEY, "warm:4800", "cut:0.1", "tight", "ease:0.006"),
        "pass":      ("one soft dry tap of a small wooden mallet on a small hollow wooden block, a round woody 'tok' with a clear body, gentle, very short", 0.5, -13, FOLEY, "warm:5000", "cut:0.14", "tight", "ease:0.006"),
        "bump":      ("a small soft thing bumping into a leafy garden hedge, one dull soft thud and a short hush of leaves, gentle, not harsh, short", 0.7, -14, GROVE, "warm:4500", "ease:0.012"),
        "land":      ("a small soft thing dropping onto thick grass, one soft plop with a short dry rustle of grass blades, gentle, very short", 0.5, -12, GROVE, "warm:5000", "cut:0.3", "ease:0.01"),
        "dew":       ("one soft round low water drop 'bloop' falling into a small wooden bowl of water, gentle and dull, short", 0.6, -15, JETTY, "warm:4500", "ease:0.012"),
        "ribbon":    ("two soft low rising notes on the kalimba, warm and woody, a small prize won, short", 0.7, -12, HEARTH_TUNE, "warm:5000", "ease:0.015"),
        "start":     ("three slow soft rising notes on the kalimba, a quiet morning in a garden beginning, short", 1.0, -13, HEARTH_TUNE, "warm:5000", "ease:0.015"),
        "game_over": ("three soft slow descending notes on a low kalimba, gentle and kind, never sad, good try", 1.5, -12, HEARTH_TUNE, "warm:5500", "ease:0.02"),
        "new_best":  ("a warm short rising phrase on a low kalimba and a wooden tongue drum, five soft notes ending on a round held note, glad and cozy", 2.0, -10, HEARTH_TUNE, "warm:6000", "ease:0.02"),
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


def to_ogg(mp3: pathlib.Path, out: pathlib.Path, peak: int, loop: bool = False, warm: int = 0, cut: float = 0.0, tight: bool = False, ease: float = 0.0, body: int = 0, steep: bool = False) -> None:
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
    # Ease (2026-10-09, Nightlight): 4 ms is still a tick on a take that
    # starts at full level; a cue that should arrive rather than land names
    # a longer one.
    soft = f",lowpass=f={warm}:p=2,highshelf=f={warm // 2}:g=-4,afade=t=in:d={ease or 0.004}" if warm else \
        f",afade=t=in:d={ease}" if ease else ""
    if loop and warm:
        # A loop is rolled off and not eased: a fade would dip at its seam.
        soft = f",lowpass=f={warm}:p=2,highshelf=f={warm // 2}:g=-4"
    if steep and warm:
        soft = f",lowpass=f={warm}:p=2,lowpass=f={warm}:p=2" + soft
    if body:
        soft = f",highpass=f={body}:p=2,highpass=f={body}:p=2" + soft
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


def tune(mp3: pathlib.Path, gap: float, steps: list[float]) -> pathlib.Path:
    # A phrase from one recorded note (2026-10-09, Binairo). Asked for
    # "five notes rising" the API returns a single kalimba hit ringing out,
    # every time, and as often as not at 250 to 350 Hz, under what a phone
    # plays. So the take is the note, and the phrase is written here: the
    # same take once a step, moved by that many semitones, `gap` apart.
    # The take's lead-in is trimmed first (2026-10-10, Balance): moved with
    # the pitch, 0.37 s of room noise before a tock put its second, three
    # semitones up, 0.07 s after the first where 0.13 was written.
    out = mp3.with_name(mp3.stem + "_tune.wav")
    head = "silenceremove=start_periods=1:start_threshold=-36dB:start_silence=0.004"
    marks = "".join(f"[n{i}]" for i in range(len(steps)))
    voices = ";".join(
        f"[v{i}]asetrate={44100 * 2 ** (st / 12):.1f},aresample=44100,adelay={int(i * gap * 1000)}:all=1[n{i}]"
        for i, st in enumerate(steps))
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(mp3), "-filter_complex",
                    f"[0]aresample=44100,{head},asplit={len(steps)}" + "".join(f"[v{i}]" for i in range(len(steps))) + ";"
                    + voices + f";{marks}amix=inputs={len(steps)}:normalize=0:duration=longest",
                    str(out)], check=True)
    return out


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
        ease = next((float(f[5:]) for f in rest[1:] if isinstance(f, str) and f.startswith("ease:")), 0.0)
        raw = raw_dir / f"{cue}.mp3"
        if "--new" in flags or not raw.exists():
            raw.write_bytes(generate(key(), prompt, seconds, style, loop))
        out = out_dir / f"{cue}.ogg"
        notes = next((f[6:] for f in rest[1:] if isinstance(f, str) and f.startswith("notes:")), "")
        if notes:
            gap, steps = notes.split(":")
            raw = tune(raw, float(gap), [float(v) for v in steps.split(",")])
        if "fall" in rest[1:]:
            raw = fall(raw)
        body = next((int(f[5:]) for f in rest[1:] if isinstance(f, str) and f.startswith("body:")), 0)
        to_ogg(raw, out, peak, loop, warm, cut, "tight" in rest[1:], ease, body, "steep" in rest[1:])
        print(f"{cue:9s} -> {out.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
