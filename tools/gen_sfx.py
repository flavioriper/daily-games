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
# Gumdrop's liquid (the user, 2026-10-11: "we need a more liquid sound for
# when adding liquid and mixing colors"): thick syrup in a wooden bowl,
# calm and close, which is the cozy rules' "calm water" and nothing that
# splashes, drips on a hard thing or fizzes.
SYRUP = ("close-mic foley recorded in a quiet warm kitchen, real thick warm "
         "syrup and honey poured slowly into a wooden bowl of calm water, "
         "soft, low, round and gentle, dry room, natural and acoustic, no "
         "splashing, no fizz, no metal, no glass, no synth, no electronic "
         "tones, no music, no voice")
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
        # The user, 2026-10-10: "too loud, too high pitch, annoying". It was the
        # paper-and-wood take of September at -12, 17% of it from 1 to 3 kHz:
        # a wheel's notch now (rule 5), 7 dB down. One number turns it up.
        # The user again that day, of the click and the page: "should be
        # lower as well", "way lower". The click is 6 dB down and the page 8
        # (-34 with BREEZE_TRIM): the measure calls both faint, as meant.
        # The user that evening, of the click at -25, on the phone: "too low,
        # can't hear anything even in the highest volume, fix it". "Should be
        # lower" was said of -19 on the Mac's speakers; the phone is the ear
        # that counts, so it is -18, inside rule 1's -13 to -19, the same low
        # take. It must not read `faint` in the measure (phone -24 or
        # better), and it does not go under -20 again.
        #
        # 2026-10-15: a pop, not a tick. From a page of seventeen pops (the
        # coin pages of that day, build/sfx_raw/coin_try/), the user of
        # this take: "way better than our current tick sound, let's use
        # it", and of a bubble-wrap pop, "insanely better than tick toc
        # sounds". So the wheel's notch (rule 5) is over: the button is a
        # smooth wooden token dropped on thick felt, a rounded pop, heard
        # as it came back (no roll-off, no body cut; 1,003 Hz, 45% from 1
        # to 3 kHz, 0.5% above). Same -18. The old take is
        # build/sfx_raw/ui/old/click_button.mp3.
        "click":    ("a smooth wooden token dropped onto thick felt, a single soft rounded pop, very short", 0.5, -18, FOLEY, "bank:token", "cut:0.12", "tight"),
        # The user, 2026-10-09, twice: the linen brush "too harsh", then the
        # card slid over felt that replaced it "a harsh scratch". A page turn
        # is a breath of breeze now (BREEZE), rolled off steeply above 1.1 kHz and
        # eased in over 60 ms: nothing in it is rubbed against anything.
        # The user, 2026-10-10: "the most annoying sound in the world, too
        # loud, too harsh". The same breath, 5 dB down, darker (900) and cut
        # at 0.35 s where half a second was heard.
        "page":     ("a soft gust of warm breeze through a few leaves, one gentle whoosh of air that rises and fades, short", 0.6, -28, BREEZE, "warm:900", "steep", "ease:0.08", "body:320", "cut:0.35"),
        # The opening (world/boot.gd, 2026-10-09): heard on every launch, so
        # it is the quietest tune there is, low and eased in.
        # The user, 2026-10-15: "a better initial animation, some pop sounds
        # with the grid being built one by one". The tiles are `tile` now,
        # one a tile as it lands, so the tune is only its two notes, played
        # as the sprout's leaves open; the take is one note (rule 8).
        "opening":  ("two slow soft notes rising on a kalimba and left to fade, a quiet good morning", 1.5, -13, COZY_TUNE, "warm:2400", "ease:0.012", "body:300", "notes:0.3:0,5"),
        # One tile of the opening's grid set down (ui/opening.gd's `landed`):
        # nine in a row, each a step higher (world/boot.gd).
        "tile":     ("one small hollow wooden tile set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -16, HUSH, "warm:1400", "cut:0.09", "body:320", "tight"),
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
        "place":    ('a smooth wooden token dropped onto thick felt, a single soft rounded pop, very short', 0.5, -13, FOLEY, "bank:token", "cut:0.16", "notes:0:-2", "tight"),
        "clear":    ('one single bubble of bubble wrap popped between two fingers, a soft small pop, close, very short', 0.5, -16, FOLEY, "bank:wrap", "cut:0.12", "tight"),
        # The lift's take over again: four prompts for a pencil's own tick came
        # back scratched (a fifth to a quarter of each above 3 kHz).
        "brush":    ("one small light wooden tile set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -17, HUSH, "warm:1500", "cut:0.1", "body:320", "notes:0:2"),
        "undo":     ('a single mouth pop made with the lips, soft and rounded, very short, close', 0.5, -15, FOLEY, "bank:lip", "cut:0.24", "tight"),
        "hint":     ("three slow soft notes rising on a kalimba, a gentle little idea, short", 1.0, -10, COZY_TUNE, "warm:2000", "steep", "ease:0.012", "body:300", "notes:0.15:3,7,10", "cut:0.8"),
        # check and blush_in re-prompted 2026-09-29 (insane polish): the low
        # marimba boops and the wooden "bonk" read as a scold, not a shrug.
        "check":    ("a gentle two-note melody on a soft kalimba: one note, then a second lower note, 'uh-oh' but kind, a cozy 'not quite yet', warm and round, never a buzzer", 1.0, -17, STYLE, "fall"),
        "check_ok": ("two soft bright marimba notes going up, a friendly 'all good' confirmation", 0.7, -10, STYLE, "body:300", "notes:0.13:2,6"),
        "reset":    ("a soft gust of warm breeze through a few leaves, one gentle whoosh of air that rises and fades, short", 0.8, -16, BREEZE, "warm:1100", "steep", "ease:0.06", "body:320"),
        "solved":   ("five slow soft notes rising on a kalimba over one gentle tongue drum note, a warm quiet little celebration that fades", 2.0, -8, COZY_TUNE, "warm:2600", "ease:0.012", "body:300", "notes:0.14:0,2,4,7,9", "cut:1.7"),
        "line":     ("two soft notes rising on a kalimba, short", 0.6, -12, COZY_TUNE, "warm:2600", "ease:0.01", "body:300", "notes:0.12:5,9"),
        "blush_in": ("a tiny soft felt mallet tap on a small wooden block with a gentle little pitch dip, a shy muffled 'oops', very short and quiet", 0.5, -14, STYLE, "body:300"),
        "enter":    ('a smooth wooden token dropped onto thick felt, a single soft rounded pop, very short', 0.5, -13, FOLEY, "bank:token", "cut:0.12", "notes:0:-2", "tight"),
        # Hearts, streaks and rewards (2026-09-29 insane polish, spec section 3).
        "heart_lost":    ("a soft felt-mallet marimba two-note fall, a small gentle 'oh', warm and muffled, never a buzzer", 0.6, -15),
        "out_of_hearts": ("three slow soft notes going down on a kalimba, like a sleepy yawn, calm and kind, maybe tomorrow", 1.5, -13, COZY_TUNE, "warm:2600", "ease:0.02", "body:300", "notes:0.3:9,5,2"),
        "heart_back":    ("a warm rising pair of soft kalimba plucks, a little heart coming back, gentle and happy", 0.6, -15),
        # Every scored tile from the second of a streak, on top of `place`: a
        # tick the board pitches, not a note (what repeats is a click).
        "combo":         ('one single bubble of bubble wrap popped between two fingers, a soft small pop, close, very short', 0.5, -15, FOLEY, "bank:wrap", "cut:0.14", "tight"),
        "confetti":      ("a small soft puff of warm air through a few leaves, light, rising and fading, short", 0.8, -17, BREEZE, "warm:1200", "steep", "ease:0.04", "body:320"),
        "line_silly":    ("three soft hollow wooden ticks one after another, speeding up, an old mouse wheel turned", 0.7, -15, HUSH, "warm:1500", "body:320"),
        "flawless":      ("two slow soft notes rising on a kalimba and left to fade, a gentle proud 'perfect'", 1.5, -9, COZY_TUNE, "warm:2600", "ease:0.012", "body:300", "notes:0.32:0,7"),
        "liar":          ("four soft tongue drum notes tiptoeing, sneaky and playful, the last one a little higher, light", 1.0, -11, COZY_TUNE, "warm:2600", "ease:0.01", "body:300", "notes:0.16:6,7,6,10"),
        "party":         ("a slow rising run of soft kalimba notes ending on two gentle tongue drum notes, a warm cozy little party, fading", 2.0, -8, COZY_TUNE, "warm:2600", "ease:0.012", "body:300", "notes:0.14:-7,-3,0,-3,0,5", "cut:1.9"),
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
        "pick":     ('a small pebble dropped into a calm pond, one soft plop, close, very short', 0.6, -15, FOLEY, "bank:pebble", "cut:0.1", "notes:0:3", "tight"),
        "drop":     ('a smooth wooden token dropped onto thick felt, a single soft rounded pop, very short', 0.5, -13, FOLEY, "bank:token", "cut:0.18", "notes:0:-1", "tight"),
        "put":      ('a smooth wooden token dropped onto thick felt, a single soft rounded pop, very short', 0.5, -13, FOLEY, "bank:token", "cut:0.09", "notes:0:3", "tight"),
        # "Not that far": two notes, the second lower.
        "refused":  ("one soft short note on a kalimba, muffled and kind", 0.6, -13, COZY_TUNE, "warm:2400", "ease:0.01", "body:300", "notes:0.12:6,3", "cut:0.5"),
        "taut":     ("one small wooden block set down gently on thick felt, a single soft dull tock, round and hollow, very short", 0.6, -14, HUSH, "warm:1300", "cut:0.12", "body:320", "tight"),
        # The knots: a wrap drawn tighter, a wrap spinning free, a rope left
        # with nothing crossing it.
        "cinch":    ("one soft pat on a small felt cushion over wood, a single dull hollow tock, round, very short", 0.5, -13, HUSH, "warm:1400", "cut:0.14", "body:320", "tight"),
        # unwind is the drop's take, three notches rising: a spool's own came
        # back twice with its tock 80 ms behind a first faint one.
        "unwind":   ('a single mouth pop made with the lips, soft and rounded, very short, close', 0.5, -13, FOLEY, "bank:lip", "cut:0.36", "notes:0.08:1,3,5", "tight"),
        "free":     ("a soft springy cotton rope boing with a tiny happy two-note kalimba lift, cute and cozy, very short", 0.6, -9, STYLE, "warm:6000"),
        "untie":    ("a tiny bright kalimba pluck going up with a soft rope loosening rustle, a knot coming undone, very short", 0.6, -10, STYLE, "warm:2400", "body:300"),
        "combo":    ('one single bubble of bubble wrap popped between two fingers, a soft small pop, close, very short', 0.5, -10, FOLEY, "bank:wrap", "cut:0.1", "notes:0:1", "tight"),
        "oops":     ("two soft wobbly descending marimba notes with a tiny cartoon slide, a gentle comic oops, not harsh", 0.7, -10),
        "undo":     ('a single mouth pop made with the lips, soft and rounded, very short, close', 0.5, -15, FOLEY, "bank:lip", "cut:0.28", "notes:0.11:1,-2", "tight"),
        "hint":     ("one soft note on a kalimba, a gentle little idea, short", 1.0, -10, COZY_TUNE, "warm:2000", "steep", "ease:0.012", "body:300", "notes:0.17:0,5,9", "cut:0.9"),
        "reset":    ("a soft gust of warm breeze through a few leaves, one gentle whoosh of air that rises and fades, short", 0.8, -16, BREEZE, "warm:1100", "steep", "ease:0.06", "body:320"),
        "solved":   ("one soft note on a kalimba over a gentle tongue drum, warm, left to fade", 2.0, -8, COZY_TUNE, "warm:2600", "ease:0.012", "body:300", "notes:0.14:0,4,7,9,12", "cut:1.7"),
        "enter":    ('a smooth wooden token dropped onto thick felt, a single soft rounded pop, very short', 0.5, -9, FOLEY, "bank:token", "cut:0.12", "notes:0:-1", "tight"),
        # Thread (Hard and Insane): a stitch is the lightest tick there is.
        "stitch":      ('one single bubble of bubble wrap popped between two fingers, a soft small pop, close, very short', 0.5, -13, FOLEY, "bank:wrap", "cut:0.08", "notes:0:6", "tight"),
        "thread_low":  ("a single soft low warm kalimba note, gentle, a quiet 'the thread is getting short', very short", 0.5, -12),
        "thread_out":  ("one slow soft note on a kalimba, sleepy, calm and kind, left to fade", 1.6, -13, COZY_TUNE, "warm:2600", "ease:0.02", "body:300", "notes:0.32:7,4,0"),
        "spool_back":  ("a warm rising pair of soft kalimba plucks with a tiny sparkle and a light wooden spool spinning, gentle and happy", 0.9, -10, STYLE, "warm:2400", "body:300"),
        "reveal":      ('a single mouth pop made with the lips, soft and rounded, very short, close', 0.5, -13, FOLEY, "bank:lip", "cut:0.34", "notes:0.13:1,4", "tight"),
        # The seal and the party.
        "stamp":    ('a smooth wooden token dropped onto thick felt, a single soft rounded pop, very short', 0.5, -9, FOLEY, "bank:token", "cut:0.12", "notes:0:-1", "tight"),
        "party":    ("one soft note on a kalimba over a gentle tongue drum, warm and cozy, left to fade", 2.0, -8, COZY_TUNE, "warm:2600", "ease:0.012", "body:300", "notes:0.14:0,4,7,4,7,12", "cut:1.9"),
        "confetti": ("a small soft puff of warm air through a few leaves, light, rising and fading, short", 0.8, -17, BREEZE, "warm:1200", "steep", "ease:0.04", "body:320"),
        # Insane's kitten (petted; her pounce went with her swipes,
        # 2026-10-16). The purr was 89% under 300 Hz, which a phone does
        # not play: it is a chirrup now, a real kitten's and no cartoon's.
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
        "select":   ('a small pebble dropped into a calm pond, one soft plop, close, very short', 0.6, -15, FOLEY, "bank:pebble", "cut:0.1", "notes:0:-1", "tight"),
        "plot":     ("a soft short garden trowel pat in loose soil with a tiny wooden tap, a garden bed marked out", 0.5, -13),
        "hint":     ("one soft note on a kalimba, a gentle little idea, short", 1.0, -10, COZY_TUNE, "warm:2000", "steep", "ease:0.012", "body:300", "notes:0.15:2,5,10", "cut:0.9"),
        "check_ok": ("two soft bright marimba notes going up, a friendly 'all good' confirmation", 0.7, -10, STYLE, "body:300", "warm:2600", "notes:0.13:2,6"),
        "reset":    ("a soft gust of warm breeze through a few leaves, one gentle whoosh of air that rises and fades, short", 0.8, -16, BREEZE, "warm:1100", "steep", "ease:0.06", "body:320"),
        "solved":   ("one soft note on a kalimba over a gentle tongue drum, warm, left to fade", 2.0, -8, COZY_TUNE, "warm:2600", "ease:0.012", "body:300", "notes:0.14:0,2,5,7,10", "cut:1.7"),
        # The stakes going in: select's take, five in a row. The cascade of
        # pops it was sat between 1 and 3 kHz whatever was rolled off.
        "enter":    ('a smooth wooden token dropped onto thick felt, a single soft rounded pop, very short', 0.5, -14, FOLEY, "bank:token", "cut:0.5", "notes:0.08:-3,-1,-3,0,2", "tight"),
        # A bed taken up: a lift is a lighter thing set down.
        "clear":    ('one single bubble of bubble wrap popped between two fingers, a soft small pop, close, very short', 0.5, -16, FOLEY, "bank:wrap", "cut:0.12", "notes:0:-1", "tight"),
        "locked":   ('one soft tongue click, a hollow rounded pop, close, very short', 0.5, -12, FOLEY, "bank:tongue", "cut:0.3", "notes:0:-1", "tight"),
        "undo":     ('a single mouth pop made with the lips, soft and rounded, very short, close', 0.5, -15, FOLEY, "bank:lip", "cut:0.28", "notes:0.11:-1,-4", "tight"),
        "check":    ("a gentle two-note melody on a soft kalimba: one note, then a second lower note, 'uh-oh' but kind, a cozy 'not quite yet', warm and round, never a buzzer", 1.0, -17, STYLE, "fall"),
        # The polish pass (2026-09-30, docs/superpowers/specs/2026-09-30-shikaku-polish-design.md).
        # sprout: a light tick after the bed's own. combo: layered over plot,
        # a tick the board pitches by the streak.
        "sprout":   ("one small wooden bead set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -16, HUSH, "warm:1600", "cut:0.09", "body:320", "tight", "notes:0:3"),
        "combo":    ('one single bubble of bubble wrap popped between two fingers, a soft small pop, close, very short', 0.5, -14, FOLEY, "bank:wrap", "cut:0.14", "notes:0:-1", "tight"),
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
        "enter":    ('a smooth wooden token dropped onto thick felt, a single soft rounded pop, very short', 0.5, -14, FOLEY, "bank:token", "cut:0.5", "notes:0.08:-2,0,1,-2,3", "tight"),
        "place":    ('a smooth wooden token dropped onto thick felt, a single soft rounded pop, very short', 0.5, -13, FOLEY, "bank:token", "cut:0.16", "notes:0:-2", "tight"),
        # A lamp put out: a lift is a lighter thing set down. The board also
        # plays it 5 dB down when a wrong lamp is taken away, so it is no
        # quieter than place.
        "strike":   ("one small light wooden block set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -13, HUSH, "warm:1500", "cut:0.12", "body:320", "tight"),
        "locked":   ('one soft tongue click, a hollow rounded pop, close, very short', 0.5, -12, FOLEY, "bank:tongue", "cut:0.3", "tight"),
        "undo":     ('a single mouth pop made with the lips, soft and rounded, very short, close', 0.5, -15, FOLEY, "bank:lip", "cut:0.28", "notes:0.11:0,-3", "tight"),
        "check":    ("a gentle two-note melody on a soft kalimba: one note, then a second lower note, 'uh-oh' but kind, a cozy 'not quite yet', warm and round, never a buzzer", 1.0, -17, STYLE, "fall"),
        # chip / clear tick per stone of a sweep, pitched up as it grows.
        "chip":     ('one single bubble of bubble wrap popped between two fingers, a soft small pop, close, very short', 0.5, -15, FOLEY, "bank:wrap", "cut:0.09", "tight"),
        "clear":    ('one single bubble of bubble wrap popped between two fingers, a soft small pop, close, very short', 0.5, -16, FOLEY, "bank:wrap", "cut:0.1", "notes:0:-3", "tight"),
        # combo: layered over place, a tick the board pitches by the streak.
        "combo":    ('one single bubble of bubble wrap popped between two fingers, a soft small pop, close, very short', 0.5, -14, FOLEY, "bank:wrap", "cut:0.14", "tight"),
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
        "place":    ('a smooth wooden token dropped onto thick felt, a single soft rounded pop, very short', 0.5, -14, FOLEY, "bank:token", "cut:0.16", "notes:0:-1", "tight"),
        # The user, 2026-10-10: a sound "when selecting tiles, not only on
        # place (like we do for trail word)". Each cell a stroke takes in:
        # place's take two steps up, the click under a finger that slides
        # (rule 9), so -21 and short.
        "select":   ('a small pebble dropped into a calm pond, one soft plop, close, very short', 0.6, -21, FOLEY, "bank:pebble", "cut:0.08", "notes:0:3", "tight"),
        "locked":   ('one soft tongue click, a hollow rounded pop, close, very short', 0.5, -12, FOLEY, "bank:tongue", "cut:0.3", "notes:0:1", "tight"),
        "undo":     ('a single mouth pop made with the lips, soft and rounded, very short, close', 0.5, -15, FOLEY, "bank:lip", "cut:0.28", "notes:0.11:1,-2", "tight"),
        "hint":     ("one soft note on a kalimba, a gentle little idea, short", 1.0, -10, COZY_TUNE, "warm:2000", "steep", "ease:0.012", "body:300", "notes:0.16:2,7,9", "cut:0.9"),
        "check":    ("a gentle two-note melody on a soft kalimba: one note, then a second lower note, 'uh-oh' but kind, a cozy 'not quite yet', warm and round, never a buzzer", 1.0, -17, STYLE, "fall"),
        "check_ok": ("two soft warm kalimba notes going up, a friendly cozy 'all good', gentle and round", 0.7, -10),
        "reset":    ("a soft gust of warm breeze through a few leaves, one gentle whoosh of air that rises and fades, short", 0.8, -16, BREEZE, "warm:1100", "steep", "ease:0.06", "body:320"),
        # The floor laid out: place's take, five in a row.
        "enter":    ('a smooth wooden token dropped onto thick felt, a single soft rounded pop, very short', 0.5, -14, FOLEY, "bank:token", "cut:0.5", "notes:0.08:-1,2,1,-1,4", "tight"),
        "solved":   ("one soft note on a kalimba over a gentle tongue drum, warm, left to fade", 2.0, -8, COZY_TUNE, "warm:2600", "ease:0.012", "body:300", "notes:0.14:4,6,8,11,13", "cut:1.7"),
        # The streak, the gags, the daisies and the pebbles a finished line
        # lays. combo: layered over place, a tick the board pitches by the
        # streak. mushroom: two tocks a third apart. bee: two quiet notes
        # going by. bloom: one. pebbles: a wheel's four notches.
        "combo":    ('one single bubble of bubble wrap popped between two fingers, a soft small pop, close, very short', 0.5, -14, FOLEY, "bank:wrap", "cut:0.14", "notes:0:1", "tight"),
        "confetti": ("a small soft puff of warm air through a few leaves, light, rising and fading, short", 0.8, -17, BREEZE, "warm:1200", "steep", "ease:0.04", "body:320"),
        "love":     ("a few tiny soft bubbly pops rising with a sweet little two-note kalimba 'aww', little hearts floating up, cute and warm", 0.8, -10, STYLE, "warm:2400", "body:300"),
        "mushroom": ("one soft pat on a small felt cushion over wood, a single dull hollow tock, round, very short", 0.5, -14, HUSH, "warm:1400", "cut:0.4", "body:320", "tight", "notes:0.13:0,4"),
        "bee":      ("one soft short note on a kalimba, muffled and kind", 0.6, -14, COZY_TUNE, "warm:2400", "ease:0.01", "body:300", "notes:0.12:7,5", "cut:0.55"),
        "bloom":    ("one soft short note on a kalimba, muffled and kind", 0.6, -15, COZY_TUNE, "warm:2400", "ease:0.01", "body:300", "notes:0:2", "cut:0.45"),
        "pebbles":  ('one single bubble of bubble wrap popped between two fingers, a soft small pop, close, very short', 0.5, -15, FOLEY, "bank:wrap", "cut:0.4", "notes:0.07:1,3,1,4", "tight"),
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
        "place":    ('a smooth wooden token dropped onto thick felt, a single soft rounded pop, very short', 0.5, -14, FOLEY, "bank:token", "cut:0.16", "notes:0:-3", "tight"),
        # A lift is a lighter thing set down.
        "remove":   ('a single mouth pop made with the lips, soft and rounded, very short, close', 0.5, -15, FOLEY, "bank:lip", "cut:0.12", "notes:0:-1", "tight"),
        "locked":   ('one soft tongue click, a hollow rounded pop, close, very short', 0.5, -12, FOLEY, "bank:tongue", "cut:0.3", "notes:0:5", "tight"),
        "undo":     ('a single mouth pop made with the lips, soft and rounded, very short, close', 0.5, -15, FOLEY, "bank:lip", "cut:0.28", "notes:0.11:-1,-4", "tight"),
        "hint":     ("one soft note on a kalimba, a gentle little idea, short", 1.0, -10, COZY_TUNE, "warm:2000", "steep", "ease:0.012", "body:300", "notes:0.16:4,7,9", "cut:0.9"),
        "check":    ("a gentle two-note melody on a soft kalimba: one note, then a second lower note, 'uh-oh' but kind, a cozy 'not quite yet', warm and round, never a buzzer", 1.0, -17, STYLE, "fall"),
        "check_ok": ("two soft warm kalimba notes going up, a friendly cozy 'all good', gentle and round", 0.7, -10),
        "reset":    ("a soft gust of warm breeze through a few leaves, one gentle whoosh of air that rises and fades, short", 0.8, -16, BREEZE, "warm:1100", "steep", "ease:0.06", "body:320"),
        # The court laid out: place's take, five in a row.
        "enter":    ('a smooth wooden token dropped onto thick felt, a single soft rounded pop, very short', 0.5, -14, FOLEY, "bank:token", "cut:0.5", "notes:0.08:-3,-1,0,-3,2", "tight"),
        "solved":   ("one soft note on a kalimba over a gentle tongue drum, warm, left to fade", 2.0, -8, COZY_TUNE, "warm:2600", "ease:0.012", "body:300", "notes:0.14:6,8,10,11,13", "cut:1.7"),
        # The streak, the gags, and the flowers a patch opens once it has
        # its queen. combo: layered over her seat, a tick the board pitches
        # by the streak. drone: a bee going by, two quiet notes up. twirl
        # and dance are the first set's takes, rolled off. bloom: one note.
        "combo":    ('one single bubble of bubble wrap popped between two fingers, a soft small pop, close, very short', 0.5, -14, FOLEY, "bank:wrap", "cut:0.14", "notes:0:-1", "tight"),
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
        "type":     ('one single bubble of bubble wrap popped between two fingers, a soft small pop, close, very short', 0.5, -15, FOLEY, "bank:wrap", "cut:0.1", "tight"),
        # A letter taken back: a lighter thing set down.
        "erase":    ('a single mouth pop made with the lips, soft and rounded, very short, close', 0.5, -16, FOLEY, "bank:lip", "cut:0.12", "tight"),
        "flip":     ('a smooth wooden token dropped onto thick felt, a single soft rounded pop, very short', 0.5, -14, FOLEY, "bank:token", "cut:0.14", "notes:0:-2", "tight"),
        "refused":  ('one soft tongue click, a hollow rounded pop, close, very short', 0.5, -12, FOLEY, "bank:tongue", "cut:0.3", "tight"),
        "hint":     ("one soft note on a kalimba, a gentle little idea, short", 1.0, -10, COZY_TUNE, "warm:2000", "steep", "ease:0.012", "body:300", "notes:0.16:2,5,9", "cut:0.9"),
        "reset":    ("a soft gust of warm breeze through a few leaves, one gentle whoosh of air that rises and fades, short", 0.8, -16, BREEZE, "warm:1100", "steep", "ease:0.06", "body:320"),
        "solved":   ("one soft note on a kalimba over a gentle tongue drum, warm, left to fade", 2.0, -8, COZY_TUNE, "warm:2600", "ease:0.012", "body:300", "notes:0.14:6,9,11,13,14", "cut:1.7"),
        "lost":     ('one soft tongue click, a hollow rounded pop, close, very short', 0.5, -9, FOLEY, "bank:tongue", "cut:0.3", "tight"),
        # The card laid out: type's take, five in a row.
        "enter":    ('a smooth wooden token dropped onto thick felt, a single soft rounded pop, very short', 0.5, -14, FOLEY, "bank:token", "cut:0.5", "notes:0.08:-2,1,-2,0,3", "tight"),
        # The streak, the row's reactions and the gags. combo: a tick a green
        # letter, pitched by the board. sprout: one quiet note.
        "combo":    ('one single bubble of bubble wrap popped between two fingers, a soft small pop, close, very short', 0.5, -14, FOLEY, "bank:wrap", "cut:0.08", "tight"),
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
        "post":     ('a smooth wooden token dropped onto thick felt, a single soft rounded pop, very short', 0.5, -14, FOLEY, "bank:token", "cut:0.14", "notes:0:-2", "tight"),
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
        "select":   ('a small pebble dropped into a calm pond, one soft plop, close, very short', 0.6, -15, FOLEY, "bank:pebble", "cut:0.1", "notes:0:1", "tight"),
        # A word found: four quick notes up.
        "place":    ("one soft short note on a kalimba, muffled and kind", 0.6, -10, COZY_TUNE, "warm:2400", "ease:0.01", "body:300", "notes:0.09:4,6,8,11", "cut:0.8"),
        # A word taken back: a lighter thing set down, twice and falling.
        "undo":     ('a single mouth pop made with the lips, soft and rounded, very short, close', 0.5, -15, FOLEY, "bank:lip", "cut:0.28", "notes:0.11:1,-2", "tight"),
        "hint":     ("one soft note on a kalimba, a gentle little idea, short", 1.0, -10, COZY_TUNE, "warm:2000", "steep", "ease:0.012", "body:300", "notes:0.16:3,7,10", "cut:0.9"),
        "reset":    ("a soft gust of warm breeze through a few leaves, one gentle whoosh of air that rises and fades, short", 0.8, -16, BREEZE, "warm:1100", "steep", "ease:0.06", "body:320"),
        "solved":   ("one soft note on a kalimba over a gentle tongue drum, warm, left to fade", 2.0, -8, COZY_TUNE, "warm:2600", "ease:0.012", "body:300", "notes:0.14:2,4,6,9,11", "cut:1.7"),
        # The field laid out: select's take, five in a row.
        "enter":    ('a smooth wooden token dropped onto thick felt, a single soft rounded pop, very short', 0.5, -14, FOLEY, "bank:token", "cut:0.5", "notes:0.08:-1,1,-1,2,4", "tight"),
        # Rewards: the streak, the word's reactions and its gags. combo: a
        # tick a word, pitched by the board. quick: a small puff of air.
        # flutter: the butterfly going, two quiet notes up.
        "combo":    ('one single bubble of bubble wrap popped between two fingers, a soft small pop, close, very short', 0.5, -14, FOLEY, "bank:wrap", "cut:0.055", "notes:0:1", "tight"),
        "streak":   ("a cheerful quick three-note rising kalimba and glockenspiel run, on a roll, bright and happy, short", 0.7, -9),
        "big":      ("a pleased little 'ooh' on soft kalimba, two notes up then a third higher with a small glockenspiel sparkle, a big word found, warm", 0.8, -9),
        "quick":    ("a tiny quick puff of warm air, one light short breath that rises and fades, very short", 0.5, -17, BREEZE, "warm:1000", "steep", "ease:0.03", "body:320"),
        "love":     ("a few tiny soft bubbly pops rising with a sweet little two-note kalimba 'aww', little hearts floating up, cute and warm", 0.8, -10),
        "conga":    ('one single bubble of bubble wrap popped between two fingers, a soft small pop, close, very short', 0.5, -10, FOLEY, "bank:wrap", "cut:0.1", "notes:0:6", "tight"),
        "flutter":  ("one soft short note on a kalimba, muffled and kind", 0.6, -14, COZY_TUNE, "warm:2400", "ease:0.01", "body:300", "notes:0.12:5,8", "cut:0.55"),
        "twirl":    ("a tiny playful spin, a soft airy whirl ending on a small bright kalimba 'ta-da' pluck, cute and silly, very short", 0.8, -10),
        # A wrong trail on Hard and Insane blows a dandelion seed away: a
        # breath of air, no shimmer. wish_low: two quiet notes down.
        "miss":     ('one soft tongue click, a hollow rounded pop, close, very short', 0.5, -13, FOLEY, "bank:tongue", "cut:0.3", "notes:0:7", "tight"),
        "wish":     ("a small soft puff of warm air through a few leaves, light, rising and fading, short", 0.8, -16, BREEZE, "warm:900", "steep", "ease:0.05", "body:320"),
        "wish_low": ("one soft short note on a kalimba, muffled and kind", 0.6, -14, COZY_TUNE, "warm:2400", "ease:0.01", "body:300", "notes:0.2:6,3", "cut:0.7"),
        "droop":    ("a soft slow descending felt-mallet marimba slide, sleepy and kind, little tiles sagging gently, warm and muffled, never a buzzer", 0.8, -13),
        "out_of_wishes": ("one slow soft note on a kalimba, sleepy, calm and kind, left to fade", 1.6, -13, COZY_TUNE, "warm:2600", "ease:0.02", "body:300", "notes:0.32:10,7,4"),
        "wish_back": ("a warm rising pair of soft kalimba plucks with a tiny airy puff, a new dandelion clock growing back, gentle and happy", 0.7, -12),
        "reveal":   ('a single mouth pop made with the lips, soft and rounded, very short, close', 0.5, -13, FOLEY, "bank:lip", "cut:0.25", "notes:0:1", "tight"),
        "lost":     ('one soft tongue click, a hollow rounded pop, close, very short', 0.5, -9, FOLEY, "bank:tongue", "cut:0.3", "notes:0:1", "tight"),
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
        "place":    ('a smooth wooden token dropped onto thick felt, a single soft rounded pop, very short', 0.5, -14, FOLEY, "bank:token", "cut:0.16", "notes:0:-3", "tight"),
        # A pencilled note: a lighter thing set down.
        "pencil":   ('one single bubble of bubble wrap popped between two fingers, a soft small pop, close, very short', 0.5, -17, FOLEY, "bank:wrap", "cut:0.1", "notes:0:-1", "tight"),
        # A cell picked, and let go by a second tap (the user, 2026-10-10:
        # "Sudoku should have a sound feedback (and haptic) when selecting a
        # empty space ... never a ghost click that do something silent"). The
        # thing a finger does most here, so the quietest tick of the set:
        # pencil's take (never `--new`), two steps up, which the board
        # plays a little lower when it lets go.
        "select":   ('a small pebble dropped into a calm pond, one soft plop, close, very short', 0.6, -18, FOLEY, "bank:pebble", "cut:0.08", "notes:0:1", "tight"),
        "line":     ('one single bubble of bubble wrap popped between two fingers, a soft small pop, close, very short', 0.5, -8, FOLEY, "bank:wrap", "cut:0.1", "notes:0:-1", "tight"),
        "locked":   ('one soft tongue click, a hollow rounded pop, close, very short', 0.5, -12, FOLEY, "bank:tongue", "cut:0.3", "notes:0:-1", "tight"),
        "undo":     ('a single mouth pop made with the lips, soft and rounded, very short, close', 0.5, -15, FOLEY, "bank:lip", "cut:0.28", "notes:0.11:-1,-4", "tight"),
        "hint":     ("one soft note on a kalimba, a gentle little idea, short", 1.0, -10, COZY_TUNE, "warm:2000", "steep", "ease:0.012", "body:300", "notes:0.16:4,8,11", "cut:0.9"),
        "check":    ("a gentle two-note melody on a soft kalimba: one note, then a second lower note, 'uh-oh' but kind, a cozy 'not quite yet', warm and round, never a buzzer", 1.0, -17, STYLE, "fall"),
        "check_ok": ("two soft warm kalimba notes going up, a friendly cozy 'all good', gentle and round", 0.7, -10, STYLE, "warm:2400", "body:300"),
        "reset":    ("a soft gust of warm breeze through a few leaves, one gentle whoosh of air that rises and fades, short", 0.8, -16, BREEZE, "warm:1100", "steep", "ease:0.06", "body:320"),
        # The tray laid out: place's take, five in a row.
        "enter":    ('a smooth wooden token dropped onto thick felt, a single soft rounded pop, very short', 0.5, -14, FOLEY, "bank:token", "cut:0.5", "notes:0.08:-3,-1,0,-3,2", "tight"),
        "solved":   ("one soft note on a kalimba over a gentle tongue drum, warm, left to fade", 2.0, -8, COZY_TUNE, "warm:2000", "ease:0.012", "body:300", "notes:0.14:3,5,7,10,12", "cut:1.7"),
        # A number is complete (all nine are placed): four quick notes, up,
        # back a step and up. A region's sticker opens on one quiet note.
        "all_home": ("one soft short note on a kalimba, muffled and kind", 0.6, -11, COZY_TUNE, "warm:2400", "ease:0.01", "body:300", "notes:0.1:4,9,7,12", "cut:0.85"),
        "bloom":    ("one soft short note on a kalimba, muffled and kind", 0.6, -15, COZY_TUNE, "warm:2400", "ease:0.01", "body:300", "notes:0:7", "cut:0.45"),
        # The streak and the gags. combo: a tick the board pitches by the
        # streak. boing: the number hopping, place's take three times, up
        # and back a step.
        "combo":    ('one single bubble of bubble wrap popped between two fingers, a soft small pop, close, very short', 0.5, -14, FOLEY, "bank:wrap", "cut:0.07", "notes:0:-1", "tight"),
        "confetti": ("a small soft puff of warm air through a few leaves, light, rising and fading, short", 0.8, -17, BREEZE, "warm:1200", "steep", "ease:0.04", "body:320"),
        "love":     ("a few tiny soft bubbly pops rising with a sweet little two-note kalimba 'aww', little hearts floating up, cute and warm", 0.8, -10),
        "twirl":    ("a tiny playful spin, a soft airy whirl ending on a small bright kalimba 'ta-da' pluck, cute and silly, very short", 0.8, -10),
        "boing":    ("one small wooden block set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -14, HUSH, "warm:1300", "cut:0.5", "body:320", "tight", "notes:0.15:0,4,2"),
        # Hearts, the wrong number tumbling off (three notches down, never a
        # slide), and the tray at dusk.
        "heart_lost":    ("a soft felt-mallet marimba two-note fall, a small gentle 'oh', warm and muffled, never a buzzer", 0.6, -15, STYLE, "warm:2400", "body:300"),
        "tumble":   ('one single bubble of bubble wrap popped between two fingers, a soft small pop, close, very short', 0.5, -15, FOLEY, "bank:wrap", "cut:0.5", "notes:0.14:-1,-3,-5", "tight"),
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
        "place":    ('a smooth wooden token dropped onto thick felt, a single soft rounded pop, very short', 0.5, -14, FOLEY, "bank:token", "cut:0.16", "notes:0:-2", "tight"),
        # A lift is a lighter thing set down.
        "remove":   ('a single mouth pop made with the lips, soft and rounded, very short, close', 0.5, -16, FOLEY, "bank:lip", "cut:0.12", "tight"),
        "met":      ("a short happy two-note soft kalimba pluck rising, a little island complete, warm and round", 0.6, -10, STYLE, "warm:2400", "body:300"),
        "over":     ('a smooth wooden token dropped onto thick felt, a single soft rounded pop, very short', 0.5, -13, FOLEY, "bank:token", "cut:0.12", "notes:0:-2", "tight"),
        "locked":   ('one soft tongue click, a hollow rounded pop, close, very short', 0.5, -12, FOLEY, "bank:tongue", "cut:0.3", "tight"),
        "undo":     ('a single mouth pop made with the lips, soft and rounded, very short, close', 0.5, -15, FOLEY, "bank:lip", "cut:0.28", "notes:0.11:0,-3", "tight"),
        "hint":     ("one soft note on a kalimba, a gentle little idea, short", 1.0, -10, COZY_TUNE, "warm:2000", "steep", "ease:0.012", "body:300", "notes:0.16:3,6,10", "cut:0.9"),
        "check":    ("a gentle two-note melody on a soft kalimba: one note, then a second lower note, 'uh-oh' but kind, a cozy 'not quite yet', warm and round, never a buzzer", 1.0, -17, STYLE, "fall"),
        "check_ok": ("two soft warm kalimba notes going up, a friendly cozy 'all good', gentle and round", 0.7, -10),
        "reset":    ("a soft gust of warm breeze through a few leaves, one gentle whoosh of air that rises and fades, short", 0.8, -16, BREEZE, "warm:1100", "steep", "ease:0.06", "body:320"),
        # The islets rising: place's take, five in a row.
        "enter":    ('a smooth wooden token dropped onto thick felt, a single soft rounded pop, very short', 0.5, -14, FOLEY, "bank:token", "cut:0.5", "notes:0.08:-2,1,-2,0,3", "tight"),
        "solved":   ("one soft note on a kalimba over a gentle tongue drum, warm, left to fade", 2.0, -8, COZY_TUNE, "warm:2000", "ease:0.012", "body:300", "notes:0.14:-1,1,4,6,8", "cut:1.7"),
        # The network: two groups joined, two quiet notes alike and a third
        # up, and the near-miss named.
        "join":     ("one soft short note on a kalimba, muffled and kind", 0.6, -12, COZY_TUNE, "warm:2400", "ease:0.01", "body:300", "notes:0.11:4,4,9", "cut:0.7"),
        "split":    ("a gentle curious three-note kalimba question, rising at the end, 'hmm, almost', warm and kind, never a buzzer", 0.9, -13),
        # The streak and the gags. combo: a tick the board pitches by the
        # streak. fish: a small puff of air where the splash was.
        "combo":    ('one single bubble of bubble wrap popped between two fingers, a soft small pop, close, very short', 0.5, -14, FOLEY, "bank:wrap", "cut:0.1", "tight"),
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
        "lift":     ('a single mouth pop made with the lips, soft and rounded, very short, close', 0.5, -16, FOLEY, "bank:lip", "cut:0.12", "notes:0:1", "tight"),
        "place":    ('a smooth wooden token dropped onto thick felt, a single soft rounded pop, very short', 0.5, -14, FOLEY, "bank:token", "cut:0.16", "notes:0:-1", "tight"),
        "refused":  ('one soft tongue click, a hollow rounded pop, close, very short', 0.5, -12, FOLEY, "bank:tongue", "cut:0.3", "notes:0:1", "tight"),
        "undo":     ('a single mouth pop made with the lips, soft and rounded, very short, close', 0.5, -15, FOLEY, "bank:lip", "cut:0.28", "notes:0.11:1,-2", "tight"),
        "hint":     ("one soft note on a kalimba, a gentle little idea, short", 1.0, -10, COZY_TUNE, "warm:2000", "steep", "ease:0.012", "body:300", "notes:0.16:4,7,11", "cut:0.9"),
        "reset":    ("a soft gust of warm breeze through a few leaves, one gentle whoosh of air that rises and fades, short", 0.8, -16, BREEZE, "warm:1100", "steep", "ease:0.06", "body:320"),
        # The patches laid out: place's take, five in a row.
        "enter":    ('a smooth wooden token dropped onto thick felt, a single soft rounded pop, very short', 0.5, -14, FOLEY, "bank:token", "cut:0.5", "notes:0.08:-1,2,-1,1,4", "tight"),
        "solved":   ("one soft note on a kalimba over a gentle tongue drum, warm, left to fade", 2.0, -8, COZY_TUNE, "warm:2000", "ease:0.012", "body:300", "notes:0.14:4,6,9,11,13", "cut:1.7"),
        # The rack patch tapped (two notches, side to side), and the dead end
        # named (Easy and Medium).
        "wiggle":   ('one single bubble of bubble wrap popped between two fingers, a soft small pop, close, very short', 0.5, -16, FOLEY, "bank:wrap", "cut:0.22", "notes:0.07:3,1", "tight"),
        "stuck":    ('one soft tongue click, a hollow rounded pop, close, very short', 0.5, -16, FOLEY, "bank:tongue", "cut:0.3", "notes:0:1", "tight"),
        # The streak and the gags. combo: a tick the board pitches by the
        # streak. button: a wooden bead pressed home. boing: place's take
        # three times, up and back.
        "combo":    ('one single bubble of bubble wrap popped between two fingers, a soft small pop, close, very short', 0.5, -14, FOLEY, "bank:wrap", "cut:0.1", "notes:0:1", "tight"),
        "confetti": ("a small soft puff of warm air through a few leaves, light, rising and fading, short", 0.8, -17, BREEZE, "warm:1200", "steep", "ease:0.04", "body:320"),
        "love":     ("one soft short note on a kalimba, muffled and kind", 0.6, -13, COZY_TUNE, "warm:2400", "ease:0.01", "body:300", "notes:0.1:5,5,8", "cut:0.6"),
        "button":   ('a smooth wooden token dropped onto thick felt, a single soft rounded pop, very short', 0.5, -15, FOLEY, "bank:token", "cut:0.14", "notes:0:-1", "tight"),
        "boing":    ("one small wooden spool set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1600", "cut:0.4", "body:320", "tight", "notes:0.1:0,3,0"),
        # A row or column of the quilt finished: four quick quiet notes up.
        "row":      ("one soft short note on a kalimba, muffled and kind", 0.6, -12, COZY_TUNE, "warm:2400", "ease:0.01", "body:300", "notes:0.07:3,5,7,10", "cut:0.7"),
        # Hearts, the wrong patch's thread let go (one light notch) and the
        # patch blown home (a small puff of air, never a flap), the chalk
        # mark (one quiet note), the quilt at dusk.
        "heart_lost":    ("a soft felt-mallet marimba two-note fall, a small gentle 'oh', warm and muffled, never a buzzer", 0.6, -15),
        "snip":     ('a single mouth pop made with the lips, soft and rounded, very short, close', 0.5, -15, FOLEY, "bank:lip", "cut:0.09", "notes:0:5", "tight"),
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
        # The frenzy (2026-11-01). `frenzy_beat` is a sixteen-pop riff of the
        # token, a seamless loop at 100 BPM that the board plays faster by
        # pitch_scale, so the rhythm is sample-tight on a phone at any frame
        # rate; bank takes only.
        "frenzy_beat": ('a smooth wooden token dropped onto thick felt, a single soft rounded pop, very short', 0.5, -9, FOLEY, "bank:token", "cut:2.4", "notes:0.15:-5,7,3,7,-5,7,5,7,-5,7,3,7,-3,10,7,10", "loop"),
        "frenzy_in":   ('one single bubble of bubble wrap popped between two fingers, a soft small pop, close, very short', 0.5, -10, FOLEY, "bank:wrap", "cut:0.32", "notes:0.07:0,4,7,12", "tight"),
        "frenzy_out":  ('a single mouth pop made with the lips, soft and rounded, very short, close', 0.5, -12, FOLEY, "bank:lip", "cut:0.4", "notes:0.11:3,0,-4", "tight"),
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
        "combo":    ('one single bubble of bubble wrap popped between two fingers, a soft small pop, close, very short', 0.5, -14, FOLEY, "bank:wrap", "cut:0.1", "notes:0:-1", "tight"),
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
        "place":    ('a smooth wooden token dropped onto thick felt, a single soft rounded pop, very short', 0.5, -14, FOLEY, "bank:token", "cut:0.16", "notes:0:-2", "tight"),
        "refused":  ("a tiny soft kalimba note with a gentle little wobble, a kind 'that one stays', muffled and warm, very short", 0.5, -12, LINEN),
        "undo":     ('a single mouth pop made with the lips, soft and rounded, very short, close', 0.5, -15, FOLEY, "bank:lip", "cut:0.28", "notes:0.11:0,-3", "tight"),
        "hint":     ("a gentle magical sparkle, three soft music box notes rising with a warm kalimba note underneath, cozy and kind", 1.0, -8, LINEN),
        "reset":    ("a soft gust of warm breeze through a few leaves, one gentle whoosh of air that rises and fades, short", 0.8, -16, BREEZE, "warm:1100", "steep", "ease:0.06", "body:320"),
        # The pinwheels pinned up: place's take, five in a row.
        "enter":    ('a smooth wooden token dropped onto thick felt, a single soft rounded pop, very short', 0.5, -14, FOLEY, "bank:token", "cut:0.5", "notes:0.08:-2,1,-2,0,3", "tight"),
        "solved":   ("one soft note on a kalimba over a gentle tongue drum, warm, left to fade", 2.0, -8, COZY_TUNE, "warm:2000", "ease:0.012", "body:300", "notes:0.14:6,8,11,13,15", "cut:1.7"),
        # The streak and the gags. combo: a tick the board pitches by the
        # streak. whirl: a pinwheel catching a gust. flutter: two quiet
        # notes up, the butterfly.
        "combo":    ('one single bubble of bubble wrap popped between two fingers, a soft small pop, close, very short', 0.5, -14, FOLEY, "bank:wrap", "cut:0.1", "tight"),
        "confetti": ("a small soft puff of warm air through a few leaves, light, rising and fading, short", 0.8, -17, BREEZE, "warm:1200", "steep", "ease:0.04", "body:320"),
        "whirl":    ("a soft gust of warm breeze through a few leaves, one gentle whoosh of air that rises, passes and fades", 1.0, -15, BREEZE, "warm:1100", "steep", "ease:0.08", "body:320"),
        "love":     ("one soft short note on a kalimba, muffled and kind", 0.6, -13, COZY_TUNE, "warm:2400", "ease:0.01", "body:300", "notes:0.1:5,5,8", "cut:0.6"),
        "flutter":  ("one soft short note on a kalimba, muffled and kind", 0.6, -15, COZY_TUNE, "warm:2400", "ease:0.01", "body:300", "notes:0.09:7,9", "cut:0.4"),
        # Snags and hearts (Hard and Insane). snag: the wrong turn caught, one
        # light notch. tack: its take, two quick notches, the piece stitched
        # down. tug: its take, lower, a ribbon gone taut (Insane).
        "snag":     ('one soft tongue click, a hollow rounded pop, close, very short', 0.5, -15, FOLEY, "bank:tongue", "cut:0.12", "tight"),
        "heart_lost":    ("a soft gentle kalimba two-note fall, a small sad 'oh', a delicate note dropping, warm and muffled, never a buzzer", 0.6, -15, LINEN),
        "tack":     ('a smooth wooden token dropped onto thick felt, a single soft rounded pop, very short', 0.5, -16, FOLEY, "bank:token", "cut:0.22", "notes:0.07:-2,0", "tight"),
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
    # segment; it eats the leaves in order. `step` still has no file; since
    # 2026-10-26 a square crawled is `crawl` and one backed off `back`. Re-prompted in the
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
        "place":    ('a smooth wooden token dropped onto thick felt, a single soft rounded pop, very short', 0.5, -14, FOLEY, "bank:token", "cut:0.16", "notes:0:-1", "tight"),
        "munch":    ("one small wooden peg set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1400", "cut:0.24", "body:320", "tight", "notes:0.08:0,2"),
        "refuse":   ("a tiny soft kalimba note with a gentle little wobble and a muffled leafy tap, a kind 'not that way', warm, very short", 0.5, -12, CLOVER),
        "undo":     ('a single mouth pop made with the lips, soft and rounded, very short, close', 0.5, -15, FOLEY, "bank:lip", "cut:0.28", "notes:0.11:1,-2", "tight"),
        "hint":     ("one soft note on a kalimba, a gentle little idea, short", 1.0, -10, COZY_TUNE, "warm:2000", "steep", "ease:0.012", "body:300", "notes:0.16:9,12,16", "cut:0.9"),
        "reset":    ("a soft gust of warm breeze through a few leaves, one gentle whoosh of air that rises and fades, short", 0.8, -16, BREEZE, "warm:1100", "steep", "ease:0.06", "body:320"),
        "solved":   ("one soft note on a kalimba over a gentle tongue drum, warm, left to fade", 2.0, -8, COZY_TUNE, "warm:2000", "ease:0.012", "body:300", "notes:0.14:4,6,9,11,13", "cut:1.7"),
        # The leaves laid out: place's take, five in a row.
        "enter":    ('a smooth wooden token dropped onto thick felt, a single soft rounded pop, very short', 0.5, -14, FOLEY, "bank:token", "cut:0.5", "notes:0.08:-1,2,-1,1,4", "tight"),
        # The streak and the gags. combo: a tick the board pitches by the
        # streak. burp: one quiet note. ladybug: three quiet notes, up and
        # back a step. hungry: two low notes alike, a kind 'not yet'.
        "combo":    ('one single bubble of bubble wrap popped between two fingers, a soft small pop, close, very short', 0.5, -14, FOLEY, "bank:wrap", "cut:0.055", "notes:0:1", "tight"),
        # The crawl (2026-10-26, the made-fun pass): every square the body
        # grows onto is one bubble of the wrap, two steps under combo's and
        # quieter, the board climbing it a semitone a square from the last
        # leaf, five at most. A square backed off is the lip, low.
        "crawl":    ('one single bubble of bubble wrap popped between two fingers, a soft small pop, close, very short', 0.5, -19, FOLEY, "bank:wrap", "cut:0.055", "notes:0:-1", "tight"),
        "back":     ('a single mouth pop made with the lips, soft and rounded, very short, close', 0.5, -19, FOLEY, "bank:lip", "cut:0.2", "notes:0:-3", "tight"),
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
        "lift":     ('a single mouth pop made with the lips, soft and rounded, very short, close', 0.5, -16, FOLEY, "bank:lip", "cut:0.12", "notes:0:-1", "tight"),
        "step":     ('one single bubble of bubble wrap popped between two fingers, a soft small pop, close, very short', 0.5, -19, FOLEY, "bank:wrap", "cut:0.06", "notes:0:-2", "tight"),
        "slide":    ("one small wooden peg set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -14, HUSH, "warm:1600", "cut:0.16", "body:320", "tight"),
        # Put back where it was lifted: slide's take, lower and quieter.
        "drop":     ('a smooth wooden token dropped onto thick felt, a single soft rounded pop, very short', 0.5, -17, FOLEY, "bank:token", "cut:0.14", "notes:0:-5", "tight"),
        "dew":      ("one soft short note on a kalimba, muffled and kind", 0.6, -13, COZY_TUNE, "warm:2400", "ease:0.01", "body:300", "notes:0:7", "cut:0.4"),
        "dry":      ("a soft gentle two-note kalimba falling, a kind 'not yet', warm and patient, short", 0.6, -12, GLASSHOUSE),
        "refuse":   ("a tiny soft kalimba note with a gentle little wobble and a muffled felt tap, a kind 'not that one', warm, very short", 0.5, -12, GLASSHOUSE),
        "undo":     ('a single mouth pop made with the lips, soft and rounded, very short, close', 0.5, -15, FOLEY, "bank:lip", "cut:0.28", "notes:0.11:-1,-4", "tight"),
        "hint":     ("one soft note on a kalimba, a gentle little idea, short", 1.0, -10, COZY_TUNE, "warm:2000", "steep", "ease:0.012", "body:300", "notes:0.16:-2,1,5", "cut:0.9"),
        "reset":    ("a soft gust of warm breeze through a few leaves, one gentle whoosh of air that rises and fades, short", 0.8, -16, BREEZE, "warm:1100", "steep", "ease:0.06", "body:320"),
        "solved":   ("one soft note on a kalimba over a gentle tongue drum, warm, left to fade", 2.0, -8, COZY_TUNE, "warm:2000", "ease:0.012", "body:300", "notes:0.14:4,6,9,11,13", "cut:1.7"),
        # The mirrors set on their pegs: slide's take, five in a row.
        "enter":    ('a smooth wooden token dropped onto thick felt, a single soft rounded pop, very short', 0.5, -14, FOLEY, "bank:token", "cut:0.5", "notes:0.08:-3,0,-3,-1,2", "tight"),
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
        "combo":    ('one single bubble of bubble wrap popped between two fingers, a soft small pop, close, very short', 0.5, -14, FOLEY, "bank:wrap", "cut:0.1", "notes:0:-1", "tight"),
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
        "flag":     ('a smooth wooden token dropped onto thick felt, a single soft rounded pop, very short', 0.5, -16, FOLEY, "bank:token", "cut:0.12", "notes:0:-3", "tight"),
        # The twig pulled out: flag's take, two steps down.
        "unflag":   ('a single mouth pop made with the lips, soft and rounded, very short, close', 0.5, -17, FOLEY, "bank:lip", "cut:0.12", "notes:0:-3", "tight"),
        # A hedgehog woken: the bell's take, two low notes alike, a small
        # "hmph" (heart_lost falls a quarter second behind it).
        "woke":     ("one soft short note on a kalimba, muffled and kind", 0.6, -12, COZY_TUNE, "warm:2200", "ease:0.01", "body:300", "notes:0.14:4,4", "cut:0.6"),
        # A number tapped to rake round it: rake's take, two notches.
        "chord":    ("one small wooden peg set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -14, HUSH, "warm:1600", "cut:0.24", "body:320", "tight", "notes:0.08:0,2"),
        "refuse":   ("a tiny soft kalimba note with a gentle little wobble and a muffled leaf rustle, a kind 'not that one', very short", 0.5, -14, HARVEST),
        "check":    ("a soft gentle two-note kalimba falling, a kind 'not yet', warm and patient", 0.6, -12, HARVEST),
        "check_ok": ("three soft warm kalimba notes rising, bright and happy, 'all good'", 0.7, -10, HARVEST),
        "undo":     ('a single mouth pop made with the lips, soft and rounded, very short, close', 0.5, -15, FOLEY, "bank:lip", "cut:0.28", "notes:0.11:-1,-4", "tight"),
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
        "combo":    ('one single bubble of bubble wrap popped between two fingers, a soft small pop, close, very short', 0.5, -14, FOLEY, "bank:wrap", "cut:0.1", "notes:0:-1", "tight"),
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
        "lift":     ('a single mouth pop made with the lips, soft and rounded, very short, close', 0.5, -16, FOLEY, "bank:lip", "cut:0.12", "tight"),
        "step":     ('one single bubble of bubble wrap popped between two fingers, a soft small pop, close, very short', 0.5, -19, FOLEY, "bank:wrap", "cut:0.06", "notes:0:-1", "tight"),
        "bump":     ("a solid hardwood toy block gently knocking against another wooden block, one soft dull hollow wooden knock, very short", 0.5, -13, WALNUT, "warm:7000", "cut:0.16", "tight"),
        "slide":    ("one small smooth wooden toy block set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -14, HUSH, "warm:1600", "cut:0.16", "body:320", "tight"),
        # Put back where it was lifted: slide's take, lower and quieter.
        "drop":     ('a smooth wooden token dropped onto thick felt, a single soft rounded pop, very short', 0.5, -17, FOLEY, "bank:token", "cut:0.14", "notes:0:-4", "tight"),
        "undo":     ('a single mouth pop made with the lips, soft and rounded, very short, close', 0.5, -15, FOLEY, "bank:lip", "cut:0.28", "notes:0.11:0,-3", "tight"),
        # A star of the count line lost (2026-10-26): Market Sums' slip, the
        # lip twice falling.
        "star":     ('a single mouth pop made with the lips, soft and rounded, very short, close', 0.5, -18, FOLEY, "bank:lip", "cut:0.2", "notes:0.09:-1,-5", "tight"),
        "slip":     ("a soft breath of warm breeze that eases, fades and stops, calm, short", 0.8, -17, BREEZE, "warm:900", "steep", "ease:0.05", "body:320"),
        "reset":    ("a soft gust of warm breeze through a few leaves, one gentle whoosh of air that rises and fades, short", 0.8, -16, BREEZE, "warm:1100", "steep", "ease:0.06", "body:320"),
        # The blocks set in the tray: slide's take, five in a row.
        "enter":    ('a smooth wooden token dropped onto thick felt, a single soft rounded pop, very short', 0.5, -14, FOLEY, "bank:token", "cut:0.5", "notes:0.08:-2,1,-2,0,3", "tight"),
        # The win. gate: the gate swinging open, a long breath. hop: the big
        # block out over the stepping stones, slide's take two steps up (the
        # board pitches each stone a little higher). latch: one move from
        # home, lift's take, three quick notches.
        "gate":     ("a long soft breath of warm breeze that eases, fades and stops, calm", 1.0, -16, BREEZE, "warm:900", "steep", "ease:0.1", "body:320"),
        "hop":      ('one single bubble of bubble wrap popped between two fingers, a soft small pop, close, very short', 0.5, -15, FOLEY, "bank:wrap", "cut:0.12", "notes:0:2", "tight"),
        "latch":    ('a smooth wooden token dropped onto thick felt, a single soft rounded pop, very short', 0.5, -15, FOLEY, "bank:token", "cut:0.3", "notes:0.07:-2,0,-2", "tight"),
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
        "combo":    ('one single bubble of bubble wrap popped between two fingers, a soft small pop, close, very short', 0.5, -14, FOLEY, "bank:wrap", "cut:0.1", "tight"),
        "confetti": ("a small soft puff of warm air through a few leaves, light, rising and fading, short", 0.8, -17, BREEZE, "warm:1200", "steep", "ease:0.04", "body:320"),
        "love":     ("one soft short note on a kalimba, muffled and kind", 0.6, -13, COZY_TUNE, "warm:2400", "ease:0.01", "body:300", "notes:0.1:2,2,5", "cut:0.6"),
        "flutter":  ("one soft short note on a kalimba, muffled and kind", 0.6, -15, COZY_TUNE, "warm:2400", "ease:0.01", "body:300", "notes:0.09:4,6", "cut:0.4"),
        "twirl":    ("one soft short note on a kalimba, muffled and kind", 0.6, -13, COZY_TUNE, "warm:2400", "ease:0.01", "body:300", "notes:0.09:0,3,7,3", "cut:0.8"),
        # The party.
        "stamp":    ("one soft note on a kalimba, proud and warm, left to fade", 1.5, -9, COZY_TUNE, "warm:2600", "ease:0.012", "body:300", "notes:0.26:8,4,11"),
        "party":    ("one soft note on a kalimba over a gentle tongue drum, warm and cozy, left to fade", 2.0, -8, COZY_TUNE, "warm:2600", "ease:0.012", "body:300", "notes:0.14:4,7,11,7,11,13", "cut:1.9"),
        "purr":     ("one short soft contented chirrup, a little rolling trill with the mouth closed, gentle and happy", 1.0, -12, KITTEN, "warm:2400", "ease:0.01", "body:300"),
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
        "place":    ('a smooth wooden token dropped onto thick felt, a single soft rounded pop, very short', 0.5, -16, FOLEY, "bank:token", "cut:0.09", "notes:0:-3", "tight"),
        "lift":     ('a single mouth pop made with the lips, soft and rounded, very short, close', 0.5, -17, FOLEY, "bank:lip", "cut:0.09", "notes:0:-1", "tight"),
        # A colour picked from the box: lift's take, two steps up.
        "pick":     ('a small pebble dropped into a calm pond, one soft plop, close, very short', 0.6, -15, FOLEY, "bank:pebble", "cut:0.1", "notes:0:1", "tight"),
        "peek":     ("a small soft puff of warm air through a few leaves, light, rising and fading, short", 0.8, -17, BREEZE, "warm:1200", "steep", "ease:0.04", "body:320"),
        # An empty compartment: lift's take, two low notches alike.
        "refuse":   ('one soft tongue click, a hollow rounded pop, close, very short', 0.5, -15, FOLEY, "bank:tongue", "cut:0.26", "notes:0.1:-4,-4", "tight"),
        "undo":     ('a single mouth pop made with the lips, soft and rounded, very short, close', 0.5, -15, FOLEY, "bank:lip", "cut:0.28", "notes:0.11:-1,-4", "tight"),
        "hint":     ("a gentle sparkle, three soft kalimba notes rising with a tiny hand bell on top, kind and helpful", 1.0, -9, BEADBOX_TUNE, "warm:2400", "body:300"),
        "check":    ("a soft two-note downward kalimba, gentle, kind, not yet", 0.6, -10, BEADBOX_TUNE, "warm:7000"),
        "check_ok": ("a soft bright three-note rising kalimba, all good", 0.7, -9, BEADBOX_TUNE, "warm:7000"),
        "reset":    ("a soft gust of warm breeze through a few leaves, one gentle whoosh of air that rises and fades, short", 0.8, -16, BREEZE, "warm:1100", "steep", "ease:0.06", "body:320"),
        # The beads set in the box: place's take, five in a row.
        "enter":    ('a smooth wooden token dropped onto thick felt, a single soft rounded pop, very short', 0.5, -14, FOLEY, "bank:token", "cut:0.5", "notes:0.08:-3,0,-3,-1,2", "tight"),
        # The iron over a full plate: a long breath. steam: a small puff.
        "iron":     ("a long soft breath of warm breeze that eases, fades and stops, calm", 1.0, -15, BREEZE, "warm:900", "steep", "ease:0.1", "body:320"),
        "steam":    ("a tiny quick puff of warm air, one light short breath that rises and fades, very short", 0.6, -17, BREEZE, "warm:900", "steep", "ease:0.04", "body:320"),
        "plate":    ("a small happy flourish, four soft kalimba notes rising with a tiny music box sparkle on top, a little square of bead art finished, proud and cute", 1.2, -8, BEADBOX_TUNE, "warm:7000"),
        # A plate ironed wrong, its beads hopping off: place's take, three
        # notches down.
        "astray":   ('one soft tongue click, a hollow rounded pop, close, very short', 0.5, -15, FOLEY, "bank:tongue", "cut:0.4", "notes:0.1:-1,-3,-5", "tight"),
        "heart_lost": ("a soft sad little two-note kalimba falling, gentle and kind, not scolding", 0.9, -12, BEADBOX_TUNE, "warm:7000"),
        "out_of_hearts": ("one slow soft note on a kalimba, sleepy, calm and kind, left to fade", 1.6, -13, COZY_TUNE, "warm:2600", "ease:0.02", "body:300", "notes:0.32:7,4,0"),
        "heart_back": ("a warm hopeful rising kalimba phrase with a small hand bell, a heart coming back, gentle and happy", 1.0, -10, BEADBOX_TUNE, "warm:7000"),
        # The streak: a tick the board pitches by the plates ironed right in
        # a row. steady: a tidy run of beads, the wheel spun, place's take
        # four quick notches.
        "combo":    ('one single bubble of bubble wrap popped between two fingers, a soft small pop, close, very short', 0.5, -14, FOLEY, "bank:wrap", "cut:0.1", "notes:0:-1", "tight"),
        "steady":   ('a smooth wooden token dropped onto thick felt, a single soft rounded pop, very short', 0.5, -16, FOLEY, "bank:token", "cut:0.3", "notes:0.055:-3,-2,-3,-1", "tight"),
        "confetti": ("a soft little paper confetti pop and flutter with a tiny music box twinkle, cute", 1.0, -10, BEADBOX_TUNE, "warm:7000"),
        # The butterfly: Hedgehogs' gust again, the quietest puff there is
        # (pitched up, a take that quiet came out of `notes` empty).
        "flutter":  ("a tiny quick puff of warm air, one light short breath that rises and fades, very short", 0.6, -19, BREEZE, "warm:1100", "steep", "ease:0.05", "body:320"),
        "stamp":    ("one soft note on a kalimba, proud and warm, left to fade", 1.5, -9, COZY_TUNE, "warm:2600", "ease:0.012", "body:300", "notes:0.26:5,1,8"),
        "solved":   ("a warm short celebratory flourish on a real kalimba and a music box, rising arpeggio ending on a soft hand bell shimmer, joyful and cozy", 2.0, -8, BEADBOX_TUNE, "warm:2600", "body:300"),
        "party":    ("a short cozy celebratory flourish on a real kalimba and a music box, rising and bright, with a few soft little party blower toots, warm and joyful", 2.0, -8, BEADBOX_TUNE, "warm:2600", "body:300"),
        "purr":     ("one short soft contented chirrup, a little rolling trill with the mouth closed, gentle and happy", 1.0, -12, KITTEN, "warm:2400", "ease:0.01", "body:300"),
    },
    # Glimpse (puzzle_id "glimpse"), 2026-10-22: Pixel Garden from memory,
    # so its board's sounds. Every row is Pixel Garden's, of the same takes
    # (copied into build/sfx_raw/glimpse/, never bought); the bank pops sit a
    # step over Pixel Garden's (rule 5). Hint, Check, hearts and the held
    # card are gone with the things that played them. New: `show` (the
    # picture held up: peek's puff a little higher), `hide` (put back under
    # its cover: the same puff lower) and `count` (the first show's last
    # three seconds, a bubble a second, which the board pitches up).
    # All of it unheard.
    "glimpse": {
        "show":     ("a small soft puff of warm air through a few leaves, light, rising and fading, short", 0.8, -16, BREEZE, "warm:1200", "steep", "ease:0.04", "body:320", "notes:0:2"),
        "hide":     ("a small soft puff of warm air through a few leaves, light, rising and fading, short", 0.8, -17, BREEZE, "warm:1100", "steep", "ease:0.04", "body:320", "notes:0:-3"),
        "count":    ('one single bubble of bubble wrap popped between two fingers, a soft small pop, close, very short', 0.5, -15, FOLEY, "bank:wrap", "cut:0.1", "notes:0:1", "tight"),
        "place":    ('a smooth wooden token dropped onto thick felt, a single soft rounded pop, very short', 0.5, -16, FOLEY, "bank:token", "cut:0.09", "notes:0:-2", "tight"),
        "lift":     ('a single mouth pop made with the lips, soft and rounded, very short, close', 0.5, -17, FOLEY, "bank:lip", "cut:0.09", "notes:0:0", "tight"),
        "pick":     ('a small pebble dropped into a calm pond, one soft plop, close, very short', 0.6, -15, FOLEY, "bank:pebble", "cut:0.1", "notes:0:2", "tight"),
        "refuse":   ('one soft tongue click, a hollow rounded pop, close, very short', 0.5, -15, FOLEY, "bank:tongue", "cut:0.26", "notes:0.1:-3,-3", "tight"),
        "undo":     ('a single mouth pop made with the lips, soft and rounded, very short, close', 0.5, -15, FOLEY, "bank:lip", "cut:0.28", "notes:0.11:0,-3", "tight"),
        "reset":    ("a soft gust of warm breeze through a few leaves, one gentle whoosh of air that rises and fades, short", 0.8, -16, BREEZE, "warm:1100", "steep", "ease:0.06", "body:320"),
        "enter":    ('a smooth wooden token dropped onto thick felt, a single soft rounded pop, very short', 0.5, -14, FOLEY, "bank:token", "cut:0.5", "notes:0.08:-2,1,-2,0,3", "tight"),
        "iron":     ("a long soft breath of warm breeze that eases, fades and stops, calm", 1.0, -15, BREEZE, "warm:900", "steep", "ease:0.1", "body:320"),
        "steam":    ("a tiny quick puff of warm air, one light short breath that rises and fades, very short", 0.6, -17, BREEZE, "warm:900", "steep", "ease:0.04", "body:320"),
        "plate":    ("a small happy flourish, four soft kalimba notes rising with a tiny music box sparkle on top, a little square of bead art finished, proud and cute", 1.2, -8, BEADBOX_TUNE, "warm:7000"),
        "astray":   ('one soft tongue click, a hollow rounded pop, close, very short', 0.5, -15, FOLEY, "bank:tongue", "cut:0.4", "notes:0.1:0,-2,-4", "tight"),
        "combo":    ('one single bubble of bubble wrap popped between two fingers, a soft small pop, close, very short', 0.5, -14, FOLEY, "bank:wrap", "cut:0.1", "notes:0:0", "tight"),
        "steady":   ('a smooth wooden token dropped onto thick felt, a single soft rounded pop, very short', 0.5, -16, FOLEY, "bank:token", "cut:0.3", "notes:0.055:-2,-1,-2,0", "tight"),
        "confetti": ("a soft little paper confetti pop and flutter with a tiny music box twinkle, cute", 1.0, -10, BEADBOX_TUNE, "warm:7000"),
        "flutter":  ("a tiny quick puff of warm air, one light short breath that rises and fades, very short", 0.6, -19, BREEZE, "warm:1100", "steep", "ease:0.05", "body:320"),
        "stamp":    ("one soft note on a kalimba, proud and warm, left to fade", 1.5, -9, COZY_TUNE, "warm:2600", "ease:0.012", "body:300", "notes:0.26:5,1,8"),
        "solved":   ("a warm short celebratory flourish on a real kalimba and a music box, rising arpeggio ending on a soft hand bell shimmer, joyful and cozy", 2.0, -8, BEADBOX_TUNE, "warm:2600", "body:300"),
        "party":    ("a short cozy celebratory flourish on a real kalimba and a music box, rising and bright, with a few soft little party blower toots, warm and joyful", 2.0, -8, BEADBOX_TUNE, "warm:2600", "body:300"),
        "purr":     ("one short soft contented chirrup, a little rolling trill with the mouth closed, gentle and happy", 1.0, -12, KITTEN, "warm:2400", "ease:0.01", "body:300"),
    },
    # Birdsong (puzzle_id "birdsong"), 2026-10-22: a bird sings a tune on
    # Drumbeat's drums and the player plays it back. Since the evening of
    # the same day a woodpecker knocks a rhythm on the old tree and the
    # player knocks it back on one drum: `drum` is a copy of
    # tools/gen_drumbeat.py's `drum_0` (the big drum, the felt skin at its
    # lowest), not here. The woodpecker's `peck` is the bank's wooden token
    # a step up (a thing struck on wood), the beat under its bar a quiet
    # `tick` of the pebble, Insane's `feint` (a peck drawn back) a soft lip.
    # The rest are takes already on disk, copied into
    # build/sfx_raw/birdsong/ from Glimpse's (itself Pixel Garden's), never
    # bought: `slip` is the tongue's refusal, `hush` the same tongue lower
    # and quieter (the drum knocked while the woodpecker knocks), `round`
    # the bead plate's flourish (a round knocked back), `hint` the held-up
    # picture's puff (the woodpecker knocks again). All of it unheard.
    "birdsong": {
        "slip":     ('one soft tongue click, a hollow rounded pop, close, very short', 0.5, -15, FOLEY, "bank:tongue", "cut:0.26", "notes:0.1:-3,-3", "tight"),
        "hush":     ('one soft tongue click, a hollow rounded pop, close, very short', 0.5, -21, FOLEY, "bank:tongue", "cut:0.1", "notes:0:-6", "tight"),
        "round":    ("a small happy flourish, four soft kalimba notes rising with a tiny music box sparkle on top, a little square of bead art finished, proud and cute", 1.2, -9, BEADBOX_TUNE, "warm:7000"),
        "peck":     ('a smooth wooden token dropped onto thick felt, a single soft rounded pop, very short', 0.5, -11, FOLEY, "bank:token", "cut:0.2", "notes:0:1", "tight"),
        # the player's knock on the stump (2026-10-29, the user: "players
        # really really hate the drums sounds, maybe we can change it to knock
        # sounds similar to what the bird does"): the peck's token, a little
        # deeper, so the two knocks are kin but told apart.
        "knock":    ('a smooth wooden token dropped onto thick felt, a single soft rounded pop, very short', 0.5, -10, FOLEY, "bank:token", "cut:0.2", "notes:0:-3", "tight"),
        "tick":     ('a small pebble dropped into a calm pond, one soft plop, close, very short', 0.5, -24, FOLEY, "bank:pebble", "cut:0.16", "tight"),
        "feint":    ('a single mouth pop made with the lips, soft and rounded, very short, close', 0.5, -22, FOLEY, "bank:lip", "cut:0.16", "notes:0:-2", "tight"),
        "hint":     ("a small soft puff of warm air through a few leaves, light, rising and fading, short", 0.8, -16, BREEZE, "warm:1200", "steep", "ease:0.04", "body:320", "notes:0:2"),
        "reset":    ("a soft gust of warm breeze through a few leaves, one gentle whoosh of air that rises and fades, short", 0.8, -16, BREEZE, "warm:1100", "steep", "ease:0.06", "body:320"),
        "enter":    ('a smooth wooden token dropped onto thick felt, a single soft rounded pop, very short', 0.5, -14, FOLEY, "bank:token", "cut:0.5", "notes:0.08:-2,1,-2,0,3", "tight"),
        "confetti": ("a soft little paper confetti pop and flutter with a tiny music box twinkle, cute", 1.0, -10, BEADBOX_TUNE, "warm:7000"),
        "solved":   ("a warm short celebratory flourish on a real kalimba and a music box, rising arpeggio ending on a soft hand bell shimmer, joyful and cozy", 2.0, -8, BEADBOX_TUNE, "warm:2600", "body:300"),
        "party":    ("a short cozy celebratory flourish on a real kalimba and a music box, rising and bright, with a few soft little party blower toots, warm and joyful", 2.0, -8, BEADBOX_TUNE, "warm:2600", "body:300"),
        "purr":     ("one short soft contented chirrup, a little rolling trill with the mouth closed, gentle and happy", 1.0, -12, KITTEN, "warm:2400", "ease:0.01", "body:300"),
    },
    # Teacups (puzzle_id "teacups"), 2026-10-22: cups lifted off friends on
    # a garden tea table. Every action is a pop from the bank, by its job:
    # `lift` the lip (a cup taken off; varied 0.96-1.04 at play), `down` the
    # token (a cup set back on its saucer, varied), `pair` three wraps rising
    # (a pair found), `miss` and `hush` the tongue (two different friends; a
    # tap that does nothing), `waltz` a run of wraps (Insane's two cups
    # trading places). The rest are takes already on disk, copied into
    # build/sfx_raw/teacups/ from Domino Patio's (themselves Birdsong's),
    # never bought. All of it unheard.
    "teacups": {
        "lift":     ('a single mouth pop made with the lips, soft and rounded, very short, close', 0.5, -15, FOLEY, "bank:lip", "cut:0.18", "notes:0:1", "tight"),
        "down":     ('a smooth wooden token dropped onto thick felt, a single soft rounded pop, very short', 0.5, -16, FOLEY, "bank:token", "cut:0.16", "notes:0:-2", "tight"),
        "pair":     ('one single bubble of bubble wrap popped between two fingers, a soft small pop, close, very short', 0.5, -14, FOLEY, "bank:wrap", "cut:0.1", "notes:0.07:0,4,7", "tight"),
        "miss":     ('one soft tongue click, a hollow rounded pop, close, very short', 0.5, -16, FOLEY, "bank:tongue", "cut:0.2", "notes:0.1:-3,-5", "tight"),
        "hush":     ('one soft tongue click, a hollow rounded pop, close, very short', 0.5, -21, FOLEY, "bank:tongue", "cut:0.1", "notes:0:-6", "tight"),
        "waltz":    ('one single bubble of bubble wrap popped between two fingers, a soft small pop, close, very short', 0.5, -17, FOLEY, "bank:wrap", "cut:0.1", "notes:0.09:0,2,4,2,0", "tight"),
        "hint":     ("a small soft puff of warm air through a few leaves, light, rising and fading, short", 0.8, -16, BREEZE, "warm:1200", "steep", "ease:0.04", "body:320", "notes:0:2"),
        "enter":    ('a smooth wooden token dropped onto thick felt, a single soft rounded pop, very short', 0.5, -14, FOLEY, "bank:token", "cut:0.5", "notes:0.06:-2,1,-2,0,3,1", "tight"),
        "confetti": ("a soft little paper confetti pop and flutter with a tiny music box twinkle, cute", 1.0, -10, BEADBOX_TUNE, "warm:7000"),
        "solved":   ("a warm short celebratory flourish on a real kalimba and a music box, rising arpeggio ending on a soft hand bell shimmer, joyful and cozy", 2.0, -8, BEADBOX_TUNE, "warm:2600", "body:300"),
        "party":    ("a short cozy celebratory flourish on a real kalimba and a music box, rising and bright, with a few soft little party blower toots, warm and joyful", 2.0, -8, BEADBOX_TUNE, "warm:2600", "body:300"),
    },
    # Market Sums (puzzle_id "market"), 2026-10-22: numbered crates on a
    # garden market stall, combined two at a time under a sign toward the
    # order. Every action is a pop from the bank, by its job: `pick` the
    # pebble (a crate picked; varied 0.96-1.04 at play), `drop` the lip (a
    # crate or a sign put down again), `sign` the token (a sign token
    # pressed, varied), `make` two wraps rising (one crate slid into
    # another), `refuse` the tongue (a take-away to nothing, a share with a
    # remainder, a crate past 9999), `undo` the lip falling, `reset` a run of
    # tokens falling (the crates dropped back on their shelves). The rest
    # are takes already on disk, copied into build/sfx_raw/market/ from
    # Teacups' (themselves Domino Patio's), never bought. All of it unheard.
    # 2026-10-26 made-fun pass: `slip` the lip twice falling (a step that
    # cost a star; the star falls off the count line). A step that brings
    # the stall nearer the order pitches `make` up at play, no new take.
    "market": {
        "slip":     ('a single mouth pop made with the lips, soft and rounded, very short, close', 0.5, -18, FOLEY, "bank:lip", "cut:0.2", "notes:0.09:-1,-5", "tight"),
        "pick":     ('one small smooth pebble dropped onto a wooden board, a single soft rounded click, very short', 0.5, -16, FOLEY, "bank:pebble", "cut:0.16", "notes:0:1", "tight"),
        "drop":     ('a single mouth pop made with the lips, soft and rounded, very short, close', 0.5, -20, FOLEY, "bank:lip", "cut:0.14", "notes:0:-3", "tight"),
        "sign":     ('a smooth wooden token dropped onto thick felt, a single soft rounded pop, very short', 0.5, -16, FOLEY, "bank:token", "cut:0.16", "notes:0:2", "tight"),
        "make":     ('one single bubble of bubble wrap popped between two fingers, a soft small pop, close, very short', 0.5, -14, FOLEY, "bank:wrap", "cut:0.1", "notes:0.07:0,5", "tight"),
        "refuse":   ('one soft tongue click, a hollow rounded pop, close, very short', 0.5, -16, FOLEY, "bank:tongue", "cut:0.2", "notes:0.1:-3,-5", "tight"),
        "undo":     ('a single mouth pop made with the lips, soft and rounded, very short, close', 0.5, -17, FOLEY, "bank:lip", "cut:0.18", "notes:0.08:2,-2", "tight"),
        "reset":    ('a smooth wooden token dropped onto thick felt, a single soft rounded pop, very short', 0.5, -16, FOLEY, "bank:token", "cut:0.4", "notes:0.05:0,-2,-4,-5,-7,-9", "tight"),
        "hint":     ("a small soft puff of warm air through a few leaves, light, rising and fading, short", 0.8, -16, BREEZE, "warm:1200", "steep", "ease:0.04", "body:320", "notes:0:2"),
        "enter":    ('a smooth wooden token dropped onto thick felt, a single soft rounded pop, very short', 0.5, -14, FOLEY, "bank:token", "cut:0.5", "notes:0.06:-2,1,-2,0,3,1", "tight"),
        "confetti": ("a soft little paper confetti pop and flutter with a tiny music box twinkle, cute", 1.0, -10, BEADBOX_TUNE, "warm:7000"),
        "solved":   ("a warm short celebratory flourish on a real kalimba and a music box, rising arpeggio ending on a soft hand bell shimmer, joyful and cozy", 2.0, -8, BEADBOX_TUNE, "warm:2600", "body:300"),
        "party":    ("a short cozy celebratory flourish on a real kalimba and a music box, rising and bright, with a few soft little party blower toots, warm and joyful", 2.0, -8, BEADBOX_TUNE, "warm:2600", "body:300"),
    },
    # Who Ate the Pie? (puzzle_id "pie"), 2026-10-22: bakers' name cards on
    # a bake-sale table, each marked "ate pie" or "didn't" once the clues
    # prove it. Every action is a pop from the bank, by its job: `pick` the
    # pebble (a card picked; varied 0.96-1.04 at play), `clear` the token (a
    # card turned to "didn't", varied), `caught` two wraps rising (a card
    # turned to "ate pie"), `refuse` the tongue (a mark nothing proves yet,
    # free), `slip` the tongue lower and twice (a mark the clues prove
    # wrong), `enter` a run of tokens (the cards laid down). The rest are
    # takes already on disk, copied into build/sfx_raw/pie/ from Market
    # Sums' (themselves Teacups'), never bought. All of it unheard.
    "pie": {
        "pick":     ('one small smooth pebble dropped onto a wooden board, a single soft rounded click, very short', 0.5, -16, FOLEY, "bank:pebble", "cut:0.16", "notes:0:1", "tight"),
        "clear":    ('a smooth wooden token dropped onto thick felt, a single soft rounded pop, very short', 0.5, -15, FOLEY, "bank:token", "cut:0.2", "notes:0.07:0,4", "tight"),
        "caught":   ('one single bubble of bubble wrap popped between two fingers, a soft small pop, close, very short', 0.5, -14, FOLEY, "bank:wrap", "cut:0.1", "notes:0.07:0,3,7", "tight"),
        "refuse":   ('one soft tongue click, a hollow rounded pop, close, very short', 0.5, -17, FOLEY, "bank:tongue", "cut:0.12", "notes:0:-2", "tight"),
        "slip":     ('one soft tongue click, a hollow rounded pop, close, very short', 0.5, -15, FOLEY, "bank:tongue", "cut:0.2", "notes:0.1:-3,-6", "tight"),
        "hint":     ("a small soft puff of warm air through a few leaves, light, rising and fading, short", 0.8, -16, BREEZE, "warm:1200", "steep", "ease:0.04", "body:320", "notes:0:2"),
        "enter":    ('a smooth wooden token dropped onto thick felt, a single soft rounded pop, very short', 0.5, -14, FOLEY, "bank:token", "cut:0.5", "notes:0.05:-2,1,-2,0,3,1,0", "tight"),
        "confetti": ("a soft little paper confetti pop and flutter with a tiny music box twinkle, cute", 1.0, -10, BEADBOX_TUNE, "warm:7000"),
        "solved":   ("a warm short celebratory flourish on a real kalimba and a music box, rising arpeggio ending on a soft hand bell shimmer, joyful and cozy", 2.0, -8, BEADBOX_TUNE, "warm:2600", "body:300"),
        "party":    ("a short cozy celebratory flourish on a real kalimba and a music box, rising and bright, with a few soft little party blower toots, warm and joyful", 2.0, -8, BEADBOX_TUNE, "warm:2600", "body:300"),
    },
    # Hosepipes (puzzle_id "hoses"), 2026-10-22: hoses dragged from garden
    # taps to their flowers across a raised bed. Every action is a pop from
    # the bank, by its job: `pick` the pebble (a hose taken in hand), `grow`
    # one wrap a square (the run of pops rides the drag; pitched up along the
    # hose at play), `back` the lip (a square taken off the hose), `cut` the
    # lip twice falling (another hose cut), `join` three wraps rising (a
    # flower reached), `refuse` the tongue (another hose's end, or a seed for
    # a hose with a flower), `hush` a quiet pebble (bare soil pressed: heard,
    # nothing happens), `dry` the tongue twice low (every flower joined, some
    # squares dry), `undo` the lip falling, `reset` a run of tokens falling,
    # `enter` a run of tokens (the ends laid on the bed). hint, solved,
    # confetti and party are takes already on disk, copied into
    # build/sfx_raw/hoses/ from Market Sums' (themselves Teacups'), never
    # bought. All of it unheard.
    "hoses": {
        "pick":     ('one small smooth pebble dropped onto a wooden board, a single soft rounded click, very short', 0.5, -16, FOLEY, "bank:pebble", "cut:0.16", "notes:0:1", "tight"),
        "grow":     ('one single bubble of bubble wrap popped between two fingers, a soft small pop, close, very short', 0.5, -18, FOLEY, "bank:wrap", "cut:0.09", "notes:0:0", "tight"),
        "back":     ('a single mouth pop made with the lips, soft and rounded, very short, close', 0.5, -19, FOLEY, "bank:lip", "cut:0.12", "notes:0:-2", "tight"),
        "cut":      ('a single mouth pop made with the lips, soft and rounded, very short, close', 0.5, -15, FOLEY, "bank:lip", "cut:0.2", "notes:0.07:0,-4", "tight"),
        "join":     ('one single bubble of bubble wrap popped between two fingers, a soft small pop, close, very short', 0.5, -14, FOLEY, "bank:wrap", "cut:0.1", "notes:0.07:0,4,7", "tight"),
        "refuse":   ('one soft tongue click, a hollow rounded pop, close, very short', 0.5, -16, FOLEY, "bank:tongue", "cut:0.14", "notes:0:-3", "tight"),
        "hush":     ('one small smooth pebble dropped onto a wooden board, a single soft rounded click, very short', 0.5, -24, FOLEY, "bank:pebble", "cut:0.12", "notes:0:-2", "tight"),
        "dry":      ('one soft tongue click, a hollow rounded pop, close, very short', 0.5, -15, FOLEY, "bank:tongue", "cut:0.2", "notes:0.1:-3,-6", "tight"),
        "undo":     ('a single mouth pop made with the lips, soft and rounded, very short, close', 0.5, -17, FOLEY, "bank:lip", "cut:0.18", "notes:0.08:2,-2", "tight"),
        "reset":    ('a smooth wooden token dropped onto thick felt, a single soft rounded pop, very short', 0.5, -16, FOLEY, "bank:token", "cut:0.4", "notes:0.05:0,-2,-4,-5,-7,-9", "tight"),
        "hint":     ("a small soft puff of warm air through a few leaves, light, rising and fading, short", 0.8, -16, BREEZE, "warm:1200", "steep", "ease:0.04", "body:320", "notes:0:2"),
        "enter":    ('a smooth wooden token dropped onto thick felt, a single soft rounded pop, very short', 0.5, -14, FOLEY, "bank:token", "cut:0.5", "notes:0.05:-2,1,-2,0,3,1,0,2", "tight"),
        "confetti": ("a soft little paper confetti pop and flutter with a tiny music box twinkle, cute", 1.0, -10, BEADBOX_TUNE, "warm:7000"),
        "solved":   ("a warm short celebratory flourish on a real kalimba and a music box, rising arpeggio ending on a soft hand bell shimmer, joyful and cozy", 2.0, -8, BEADBOX_TUNE, "warm:2600", "body:300"),
        "party":    ("a short cozy celebratory flourish on a real kalimba and a music box, rising and bright, with a few soft little party blower toots, warm and joyful", 2.0, -8, BEADBOX_TUNE, "warm:2600", "body:300"),
    },
    # Honeycomb (puzzle_id "honeycomb"), 2026-10-22: seven letters on a
    # comb of wax cells, words spelt by tapping them and sent into the honey
    # jar. Every action is a pop from the bank, by its job: `tap` the pebble
    # (a cell tapped; pitched up a step a letter at play, so a word rides up
    # as it is spelt), `delete` the lip (a letter taken back), `shuffle` a
    # run of tokens (the outer letters slid to new cells), `word` three
    # wraps rising (a word taken; pitched up with its length), `full` a run
    # of wraps climbing an octave (a full comb), `refuse` the tongue twice
    # falling (too short, no middle letter, no word), `found` one quiet
    # tongue (a word already in the jar: heard, nothing lost), `fly` a
    # flutter of small wraps (Insane: the queen flies), `reset` a run of
    # tokens falling, `enter` a run of tokens (the cells laid). hint,
    # solved, confetti and party are takes already on disk, copied into
    # build/sfx_raw/honeycomb/ from Hosepipes' (themselves Market Sums'),
    # never bought. All of it unheard.
    "honeycomb": {
        "tap":      ('one small smooth pebble dropped onto a wooden board, a single soft rounded click, very short', 0.5, -17, FOLEY, "bank:pebble", "cut:0.14", "notes:0:0", "tight"),
        "delete":   ('a single mouth pop made with the lips, soft and rounded, very short, close', 0.5, -18, FOLEY, "bank:lip", "cut:0.14", "notes:0:-2", "tight"),
        "shuffle":  ('a smooth wooden token dropped onto thick felt, a single soft rounded pop, very short', 0.5, -16, FOLEY, "bank:token", "cut:0.4", "notes:0.05:0,3,-1,2,-2,1", "tight"),
        "word":     ('one single bubble of bubble wrap popped between two fingers, a soft small pop, close, very short', 0.5, -14, FOLEY, "bank:wrap", "cut:0.1", "notes:0.07:0,4,7", "tight"),
        "full":     ('one single bubble of bubble wrap popped between two fingers, a soft small pop, close, very short', 0.5, -13, FOLEY, "bank:wrap", "cut:0.1", "notes:0.06:0,4,7,12,16,19", "tight"),
        "refuse":   ('one soft tongue click, a hollow rounded pop, close, very short', 0.5, -16, FOLEY, "bank:tongue", "cut:0.2", "notes:0.1:-3,-5", "tight"),
        "found":    ('one soft tongue click, a hollow rounded pop, close, very short', 0.5, -21, FOLEY, "bank:tongue", "cut:0.12", "notes:0:-1", "tight"),
        "fly":      ('one single bubble of bubble wrap popped between two fingers, a soft small pop, close, very short', 0.5, -20, FOLEY, "bank:wrap", "cut:0.08", "notes:0.035:7,9,7,9,12,9,12", "tight"),
        "reset":    ('a smooth wooden token dropped onto thick felt, a single soft rounded pop, very short', 0.5, -16, FOLEY, "bank:token", "cut:0.4", "notes:0.05:0,-2,-4,-5,-7,-9", "tight"),
        # 2026-10-28: a rank lit on the strip, four wraps climbing to the
        # fifth above (pitched up a rank at a time at play)
        "rank":     ('one single bubble of bubble wrap popped between two fingers, a soft small pop, close, very short', 0.5, -14, FOLEY, "bank:wrap", "cut:0.1", "notes:0.08:0,4,7,12", "tight"),
        "hint":     ("a small soft puff of warm air through a few leaves, light, rising and fading, short", 0.8, -16, BREEZE, "warm:1200", "steep", "ease:0.04", "body:320", "notes:0:2"),
        "enter":    ('a smooth wooden token dropped onto thick felt, a single soft rounded pop, very short', 0.5, -14, FOLEY, "bank:token", "cut:0.5", "notes:0.05:-2,1,-2,0,3,1,4", "tight"),
        "confetti": ("a soft little paper confetti pop and flutter with a tiny music box twinkle, cute", 1.0, -10, BEADBOX_TUNE, "warm:7000"),
        "solved":   ("a warm short celebratory flourish on a real kalimba and a music box, rising arpeggio ending on a soft hand bell shimmer, joyful and cozy", 2.0, -8, BEADBOX_TUNE, "warm:2600", "body:300"),
        "party":    ("a short cozy celebratory flourish on a real kalimba and a music box, rising and bright, with a few soft little party blower toots, warm and joyful", 2.0, -8, BEADBOX_TUNE, "warm:2600", "body:300"),
    },
    # Paper Box (puzzle_id "paperbox"), 2026-10-22: a paper net on a
    # cutting mat folded into the one box of three or four it makes. Every
    # action is a pop from the bank, by its job: `pick` the token (the right
    # box picked), `wrong` the tongue twice falling (a wrong box struck),
    # `fold` one wrap a hinge (the run of pops rides the fold; pitched up a
    # hinge at a time at play), `made` three wraps rising (the box shut and
    # turned to the corner picked), `shelf` the token (the box set on the
    # shelf; pitched up a box at a time), `hush` a quiet pebble (a tap that
    # does nothing), `enter` a run of tokens (the net laid on the mat and the
    # boxes set down). hint, solved, confetti and party are takes already on
    # disk, copied into build/sfx_raw/paperbox/ from Honeycomb's (themselves
    # Hosepipes'), never bought. All of it unheard.
    "paperbox": {
        "pick":     ('a smooth wooden token dropped onto thick felt, a single soft rounded pop, very short', 0.5, -15, FOLEY, "bank:token", "cut:0.18", "notes:0:2", "tight"),
        "wrong":    ('one soft tongue click, a hollow rounded pop, close, very short', 0.5, -16, FOLEY, "bank:tongue", "cut:0.2", "notes:0.1:-3,-6", "tight"),
        "fold":     ('one single bubble of bubble wrap popped between two fingers, a soft small pop, close, very short', 0.5, -17, FOLEY, "bank:wrap", "cut:0.09", "notes:0:0", "tight"),
        "made":     ('one single bubble of bubble wrap popped between two fingers, a soft small pop, close, very short', 0.5, -14, FOLEY, "bank:wrap", "cut:0.1", "notes:0.07:0,4,7", "tight"),
        "shelf":    ('a smooth wooden token dropped onto thick felt, a single soft rounded pop, very short', 0.5, -16, FOLEY, "bank:token", "cut:0.16", "notes:0:0", "tight"),
        "hush":     ('one small smooth pebble dropped onto a wooden board, a single soft rounded click, very short', 0.5, -24, FOLEY, "bank:pebble", "cut:0.12", "notes:0:-2", "tight"),
        "hint":     ("a small soft puff of warm air through a few leaves, light, rising and fading, short", 0.8, -16, BREEZE, "warm:1200", "steep", "ease:0.04", "body:320", "notes:0:2"),
        "enter":    ('a smooth wooden token dropped onto thick felt, a single soft rounded pop, very short', 0.5, -14, FOLEY, "bank:token", "cut:0.5", "notes:0.05:-2,1,-2,0,3", "tight"),
        "confetti": ("a soft little paper confetti pop and flutter with a tiny music box twinkle, cute", 1.0, -10, BEADBOX_TUNE, "warm:7000"),
        "solved":   ("a warm short celebratory flourish on a real kalimba and a music box, rising arpeggio ending on a soft hand bell shimmer, joyful and cozy", 2.0, -8, BEADBOX_TUNE, "warm:2600", "body:300"),
        "party":    ("a short cozy celebratory flourish on a real kalimba and a music box, rising and bright, with a few soft little party blower toots, warm and joyful", 2.0, -8, BEADBOX_TUNE, "warm:2600", "body:300"),
    },
    # Four Shelves (puzzle_id "shelves"), 2026-10-22: jam jars on a pantry
    # dresser, picked four at a time and shelved. Every action is a pop from
    # the bank, by its job: `pick` the pebble (a jar picked; pitched up a jar
    # at a time at play), `drop` the lip (a jar put back), `shuffle` a run of
    # tokens (the jars stood anew), `clear` the lip falling (every pick put
    # back), `shelf` three wraps rising (a shelf up; pitched up a shelf at a
    # time), `close` the tongue twice (three of the four go together),
    # `wrong` the tongue twice lower (not a shelf), `repeat` a quiet tongue
    # (four already tried, free), `hush` a quiet pebble, `out` the tongue
    # falling (the last heart), `reveal` one wrap (a shelf put up by Show the
    # shelves), `heart` two wraps rising (one more heart), `enter` a run of
    # tokens (the jars set down). hint, solved, confetti and party are takes
    # already on disk, copied into build/sfx_raw/shelves/ from Paper Box's,
    # never bought. All of it unheard.
    "shelves": {
        "pick":     ('one small smooth pebble dropped onto a wooden board, a single soft rounded click, very short', 0.5, -16, FOLEY, "bank:pebble", "cut:0.14", "notes:0:0", "tight"),
        "drop":     ('a single mouth pop made with the lips, soft and rounded, very short, close', 0.5, -19, FOLEY, "bank:lip", "cut:0.12", "notes:0:-2", "tight"),
        "shuffle":  ('a smooth wooden token dropped onto thick felt, a single soft rounded pop, very short', 0.5, -16, FOLEY, "bank:token", "cut:0.4", "notes:0.05:0,3,-1,2,-2,1", "tight"),
        "clear":    ('a single mouth pop made with the lips, soft and rounded, very short, close', 0.5, -18, FOLEY, "bank:lip", "cut:0.2", "notes:0.06:2,0,-2", "tight"),
        "shelf":    ('one single bubble of bubble wrap popped between two fingers, a soft small pop, close, very short', 0.5, -14, FOLEY, "bank:wrap", "cut:0.1", "notes:0.07:0,4,7", "tight"),
        "close":    ('one soft tongue click, a hollow rounded pop, close, very short', 0.5, -16, FOLEY, "bank:tongue", "cut:0.2", "notes:0.1:-1,-3", "tight"),
        "wrong":    ('one soft tongue click, a hollow rounded pop, close, very short', 0.5, -16, FOLEY, "bank:tongue", "cut:0.2", "notes:0.1:-3,-6", "tight"),
        "repeat":   ('one soft tongue click, a hollow rounded pop, close, very short', 0.5, -21, FOLEY, "bank:tongue", "cut:0.12", "notes:0:-2", "tight"),
        "hush":     ('one small smooth pebble dropped onto a wooden board, a single soft rounded click, very short', 0.5, -24, FOLEY, "bank:pebble", "cut:0.12", "notes:0:-2", "tight"),
        "out":      ('one soft tongue click, a hollow rounded pop, close, very short', 0.5, -15, FOLEY, "bank:tongue", "cut:0.3", "notes:0.12:-3,-6,-9", "tight"),
        "reveal":   ('one single bubble of bubble wrap popped between two fingers, a soft small pop, close, very short', 0.5, -17, FOLEY, "bank:wrap", "cut:0.1", "notes:0:0", "tight"),
        "heart":    ('one single bubble of bubble wrap popped between two fingers, a soft small pop, close, very short', 0.5, -15, FOLEY, "bank:wrap", "cut:0.1", "notes:0.07:0,7", "tight"),
        "hint":     ("a small soft puff of warm air through a few leaves, light, rising and fading, short", 0.8, -16, BREEZE, "warm:1200", "steep", "ease:0.04", "body:320", "notes:0:2"),
        "enter":    ('a smooth wooden token dropped onto thick felt, a single soft rounded pop, very short', 0.5, -14, FOLEY, "bank:token", "cut:0.5", "notes:0.05:-2,1,-2,0,3,1", "tight"),
        "confetti": ("a soft little paper confetti pop and flutter with a tiny music box twinkle, cute", 1.0, -10, BEADBOX_TUNE, "warm:7000"),
        "solved":   ("a warm short celebratory flourish on a real kalimba and a music box, rising arpeggio ending on a soft hand bell shimmer, joyful and cozy", 2.0, -8, BEADBOX_TUNE, "warm:2600", "body:300"),
        "party":    ("a short cozy celebratory flourish on a real kalimba and a music box, rising and bright, with a few soft little party blower toots, warm and joyful", 2.0, -8, BEADBOX_TUNE, "warm:2600", "body:300"),
    },
    # Five Clues (puzzle_id "clues"), 2026-10-22: clue cards turned on a
    # cork board and the idea typed on a slate. Every action is a pop from
    # the bank, by its job: `type` the pebble (a letter; varied at play),
    # `erase` the lip, `turn` the token (a card turned; pitched up a card at
    # a time), `right` three wraps rising (the idea named), `wrong` the
    # tongue twice falling, `lost` the tongue falling longer (the round
    # lost), `repeat` a quiet tongue (a line said before, free), `hush` a
    # quiet pebble, `next` a run of tokens (the next round's cards pinned),
    # `enter` the same. hint, solved, confetti and party are takes already
    # on disk, copied into build/sfx_raw/clues/ from Paper Box's, never
    # bought. All of it unheard.
    "clues": {
        "type":     ('one small smooth pebble dropped onto a wooden board, a single soft rounded click, very short', 0.5, -19, FOLEY, "bank:pebble", "cut:0.1", "notes:0:0", "tight"),
        "erase":    ('a single mouth pop made with the lips, soft and rounded, very short, close', 0.5, -20, FOLEY, "bank:lip", "cut:0.12", "notes:0:-2", "tight"),
        "turn":     ('a smooth wooden token dropped onto thick felt, a single soft rounded pop, very short', 0.5, -16, FOLEY, "bank:token", "cut:0.16", "notes:0:0", "tight"),
        "right":    ('one single bubble of bubble wrap popped between two fingers, a soft small pop, close, very short', 0.5, -14, FOLEY, "bank:wrap", "cut:0.1", "notes:0.07:0,4,7", "tight"),
        "wrong":    ('one soft tongue click, a hollow rounded pop, close, very short', 0.5, -16, FOLEY, "bank:tongue", "cut:0.2", "notes:0.1:-3,-6", "tight"),
        "lost":     ('one soft tongue click, a hollow rounded pop, close, very short', 0.5, -15, FOLEY, "bank:tongue", "cut:0.3", "notes:0.12:-3,-6,-9", "tight"),
        "repeat":   ('one soft tongue click, a hollow rounded pop, close, very short', 0.5, -21, FOLEY, "bank:tongue", "cut:0.12", "notes:0:-2", "tight"),
        "hush":     ('one small smooth pebble dropped onto a wooden board, a single soft rounded click, very short', 0.5, -24, FOLEY, "bank:pebble", "cut:0.12", "notes:0:-2", "tight"),
        "next":     ('a smooth wooden token dropped onto thick felt, a single soft rounded pop, very short', 0.5, -15, FOLEY, "bank:token", "cut:0.4", "notes:0.05:-2,1,-2,0,3", "tight"),
        "hint":     ("a small soft puff of warm air through a few leaves, light, rising and fading, short", 0.8, -16, BREEZE, "warm:1200", "steep", "ease:0.04", "body:320", "notes:0:2"),
        "enter":    ('a smooth wooden token dropped onto thick felt, a single soft rounded pop, very short', 0.5, -14, FOLEY, "bank:token", "cut:0.5", "notes:0.05:-2,1,-2,0,3", "tight"),
        "confetti": ("a soft little paper confetti pop and flutter with a tiny music box twinkle, cute", 1.0, -10, BEADBOX_TUNE, "warm:7000"),
        "solved":   ("a warm short celebratory flourish on a real kalimba and a music box, rising arpeggio ending on a soft hand bell shimmer, joyful and cozy", 2.0, -8, BEADBOX_TUNE, "warm:2600", "body:300"),
        "party":    ("a short cozy celebratory flourish on a real kalimba and a music box, rising and bright, with a few soft little party blower toots, warm and joyful", 2.0, -8, BEADBOX_TUNE, "warm:2600", "body:300"),
    },
    # Cross Stitch (puzzle_id "crossstitch"), 2026-11-04: a sampler of six
    # crossing words whose letters are swapped two at a time. Every action
    # is a pop from the bank, by its job: `pick` the pebble (a patch picked
    # up; varied at play), `drop` the lip (a patch put back), `swap` two
    # wraps a step apart (the run rides the two patches trading places),
    # `stitch` two wraps rising (a letter landed in its place; pitched up
    # with the letters stitched and the swaps made), `word` three wraps
    # rising to the octave (a word sewn round in gold), `refuse` the tongue
    # twice falling (a stitched patch pressed), `tight` a quiet tongue
    # falling (too few swaps left to finish), `fall` the lip falling (a star
    # lost), `out` the tongue falling (the last swap spent), `more` two wraps
    # rising (three more swaps), `reveal` a run of wraps (Show the sampler),
    # `enter` a run of tokens (the patches sewn on). hint, solved, confetti
    # and party are takes already on disk, copied into
    # build/sfx_raw/crossstitch/ from Honeycomb's, never bought. All of it
    # unheard.
    "crossstitch": {
        "pick":     ('one small smooth pebble dropped onto a wooden board, a single soft rounded click, very short', 0.5, -16, FOLEY, "bank:pebble", "cut:0.14", "notes:0:1", "tight"),
        "drop":     ('a single mouth pop made with the lips, soft and rounded, very short, close', 0.5, -19, FOLEY, "bank:lip", "cut:0.12", "notes:0:-1", "tight"),
        "swap":     ('one single bubble of bubble wrap popped between two fingers, a soft small pop, close, very short', 0.5, -16, FOLEY, "bank:wrap", "cut:0.09", "notes:0.11:0,2", "tight"),
        "stitch":   ('one single bubble of bubble wrap popped between two fingers, a soft small pop, close, very short', 0.5, -14, FOLEY, "bank:wrap", "cut:0.1", "notes:0.06:5,9", "tight"),
        "word":     ('one single bubble of bubble wrap popped between two fingers, a soft small pop, close, very short', 0.5, -13, FOLEY, "bank:wrap", "cut:0.1", "notes:0.07:0,4,7,12", "tight"),
        "refuse":   ('one soft tongue click, a hollow rounded pop, close, very short', 0.5, -16, FOLEY, "bank:tongue", "cut:0.2", "notes:0.1:-2,-4", "tight"),
        "tight":    ('one soft tongue click, a hollow rounded pop, close, very short', 0.5, -19, FOLEY, "bank:tongue", "cut:0.2", "notes:0.12:-1,-4", "tight"),
        "fall":     ('a single mouth pop made with the lips, soft and rounded, very short, close', 0.5, -18, FOLEY, "bank:lip", "cut:0.2", "notes:0.06:1,-1,-3", "tight"),
        "out":      ('one soft tongue click, a hollow rounded pop, close, very short', 0.5, -15, FOLEY, "bank:tongue", "cut:0.3", "notes:0.12:-2,-5,-8", "tight"),
        "more":     ('one single bubble of bubble wrap popped between two fingers, a soft small pop, close, very short', 0.5, -15, FOLEY, "bank:wrap", "cut:0.1", "notes:0.07:1,8", "tight"),
        "reveal":   ('one single bubble of bubble wrap popped between two fingers, a soft small pop, close, very short', 0.5, -17, FOLEY, "bank:wrap", "cut:0.08", "notes:0.04:0,2,4,5,7,9,11,12", "tight"),
        "hint":     ("a small soft puff of warm air through a few leaves, light, rising and fading, short", 0.8, -16, BREEZE, "warm:1200", "steep", "ease:0.04", "body:320", "notes:0:2"),
        "enter":    ('a smooth wooden token dropped onto thick felt, a single soft rounded pop, very short', 0.5, -14, FOLEY, "bank:token", "cut:0.5", "notes:0.05:-1,2,-1,1,4,2,5", "tight"),
        "confetti": ("a soft little paper confetti pop and flutter with a tiny music box twinkle, cute", 1.0, -10, BEADBOX_TUNE, "warm:7000"),
        "solved":   ("a warm short celebratory flourish on a real kalimba and a music box, rising arpeggio ending on a soft hand bell shimmer, joyful and cozy", 2.0, -8, BEADBOX_TUNE, "warm:2600", "body:300"),
        "party":    ("a short cozy celebratory flourish on a real kalimba and a music box, rising and bright, with a few soft little party blower toots, warm and joyful", 2.0, -8, BEADBOX_TUNE, "warm:2600", "body:300"),
    },
    # Padlock (puzzle_id "padlock"), 2026-11-04: a combination padlock whose
    # letter dials are turned until the window spells words. Every action is
    # a pop from the bank, by its job: `notch` the pebble, quiet and short
    # (one for every letter that crosses the window, dragged or springing:
    # the run rides the dial, pitched by dial and letter at play), `pick`
    # the pebble (a dial taken by the finger), `set` the token (a dial
    # settling on its letter), `word` three wraps rising (a word that lights
    # letters; pitched up with the letters it lights), `plain` one wrap and
    # a lower one (a word found that lights nothing new), `again` the lip
    # twice (a word already on a tag), `refuse` the tongue twice falling
    # (the rusty dial pushed up), `round` the token falling then a wrap (the
    # rusty dial coming round to its first letter), `fall` the lip falling
    # (a star lost), `open` tokens and wraps rising to the octave (the
    # shackle springing), `enter` a run of tokens (the dials dropping in).
    # hint, solved, confetti and party are takes already on disk, copied
    # into build/sfx_raw/padlock/ from Honeycomb's, never bought. All of it
    # unheard.
    "padlock": {
        "notch":    ('one small smooth pebble dropped onto a wooden board, a single soft rounded click, very short', 0.5, -22, FOLEY, "bank:pebble", "cut:0.07", "tight"),
        "pick":     ('one small smooth pebble dropped onto a wooden board, a single soft rounded click, very short', 0.5, -17, FOLEY, "bank:pebble", "cut:0.12", "notes:0:2", "tight"),
        "set":      ('a smooth wooden token dropped onto thick felt, a single soft rounded pop, very short', 0.5, -16, FOLEY, "bank:token", "cut:0.14", "tight"),
        "word":     ('one single bubble of bubble wrap popped between two fingers, a soft small pop, close, very short', 0.5, -13, FOLEY, "bank:wrap", "cut:0.1", "notes:0.07:0,4,7,12", "tight"),
        "plain":    ('one single bubble of bubble wrap popped between two fingers, a soft small pop, close, very short', 0.5, -17, FOLEY, "bank:wrap", "cut:0.1", "notes:0.09:0,-3", "tight"),
        "again":    ('a single mouth pop made with the lips, soft and rounded, very short, close', 0.5, -18, FOLEY, "bank:lip", "cut:0.12", "notes:0.09:0,0", "tight"),
        "refuse":   ('one soft tongue click, a hollow rounded pop, close, very short', 0.5, -16, FOLEY, "bank:tongue", "cut:0.2", "notes:0.1:-2,-4", "tight"),
        "round":    ('a smooth wooden token dropped onto thick felt, a single soft rounded pop, very short', 0.5, -15, FOLEY, "bank:token", "cut:0.3", "notes:0.06:5,2,-1,-4,7", "tight"),
        "fall":     ('a single mouth pop made with the lips, soft and rounded, very short, close', 0.5, -18, FOLEY, "bank:lip", "cut:0.2", "notes:0.06:1,-1,-3", "tight"),
        "open":     ('a smooth wooden token dropped onto thick felt, a single soft rounded pop, very short', 0.5, -12, FOLEY, "bank:token", "cut:0.5", "notes:0.06:0,4,7,12,16", "tight"),
        "hint":     ("a small soft puff of warm air through a few leaves, light, rising and fading, short", 0.8, -16, BREEZE, "warm:1200", "steep", "ease:0.04", "body:320", "notes:0:2"),
        "enter":    ('a smooth wooden token dropped onto thick felt, a single soft rounded pop, very short', 0.5, -14, FOLEY, "bank:token", "cut:0.5", "notes:0.06:-1,1,3,4,6,8", "tight"),
        "confetti": ("a soft little paper confetti pop and flutter with a tiny music box twinkle, cute", 1.0, -10, BEADBOX_TUNE, "warm:7000"),
        "solved":   ("a warm short celebratory flourish on a real kalimba and a music box, rising arpeggio ending on a soft hand bell shimmer, joyful and cozy", 2.0, -8, BEADBOX_TUNE, "warm:2600", "body:300"),
        "party":    ("a short cozy celebratory flourish on a real kalimba and a music box, rising and bright, with a few soft little party blower toots, warm and joyful", 2.0, -8, BEADBOX_TUNE, "warm:2600", "body:300"),
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
        "place":    ('a smooth wooden token dropped onto thick felt, a single soft rounded pop, very short', 0.5, -15, FOLEY, "bank:token", "cut:0.09", "notes:0:-2", "tight"),
        # Two wires touching: wake's take, two steps down.
        "join":     ('a smooth wooden token dropped onto thick felt, a single soft rounded pop, very short', 0.5, -17, FOLEY, "bank:token", "cut:0.09", "notes:0:-4", "tight"),
        # A lantern lit, seventeen in a ripple: the wheel spun, and the board
        # pitches it by the lantern's depth, not past five semitones.
        # Since 2026-10-26 (the made-fun pass) the house sound's wrap: a
        # lantern waking is a repeated thing, a run the board climbs a
        # semitone a pop by depth, five at most (WAKE_TOP).
        "wake":     ('one single bubble of bubble wrap popped between two fingers, a soft small pop, close, very short', 0.5, -16, FOLEY, "bank:wrap", "cut:0.1", "tight"),
        # Not there: the note, two quick ones a step down.
        "refuse":   ('a single soft tongue click, close, very short', 0.5, -16, FOLEY, "bank:tongue", "cut:0.12", "tight"),
        # The made-fun pass (2026-10-26). A stake set down: the token, two
        # steps up from place; a stake pulled: the lip; a wire ring closing:
        # the tongue, twice and falling, the one "not like that" it says.
        "stake":    ('a smooth wooden token dropped onto thick felt, a single soft rounded pop, very short', 0.5, -15, FOLEY, "bank:token", "cut:0.09", "notes:0:2", "tight"),
        "unstake":  ('a single mouth pop made with the lips, soft and rounded, very short, close', 0.5, -16, FOLEY, "bank:lip", "cut:0.1", "notes:0:0", "tight"),
        "ring":     ('a single soft tongue click, close, very short', 0.5, -15, FOLEY, "bank:tongue", "cut:0.25", "notes:0.1:0,-3", "tight"),
        # Taken back: place's take, twice and falling.
        "undo":     ('a single mouth pop made with the lips, soft and rounded, very short, close', 0.5, -15, FOLEY, "bank:lip", "cut:0.28", "notes:0.11:0,-3", "tight"),
        "hint":     ("one soft short note on a kalimba, muffled and kind", 0.6, -10, COZY_TUNE, "warm:2400", "ease:0.012", "body:300", "notes:0.16:4,7,11", "cut:1.0"),
        "reset":    ("a soft gust of warm breeze through a few leaves, one gentle whoosh of air that rises and fades, short", 0.8, -16, BREEZE, "warm:1100", "steep", "ease:0.06", "body:320"),
        # The garden set out: place's take, five in a row.
        "enter":    ('a smooth wooden token dropped onto thick felt, a single soft rounded pop, very short', 0.5, -14, FOLEY, "bank:token", "cut:0.5", "notes:0.08:-2,1,-2,0,3", "tight"),
        "solved":   ("one soft note on a kalimba over a gentle tongue drum, warm, left to fade", 2.0, -8, COZY_TUNE, "warm:2000", "ease:0.012", "body:300", "notes:0.14:4,6,9,11,13", "cut:1.7"),
        # The streak and the gags.
        "combo":    ('one single bubble of bubble wrap popped between two fingers, a soft small pop, close, very short', 0.5, -14, FOLEY, "bank:wrap", "cut:0.1", "tight"),
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
        "clip":     ('a single mouth pop made with the lips, soft and rounded, very short, close', 0.5, -15, FOLEY, "bank:lip", "cut:0.1", "notes:0:2", "tight"),
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
        "lift":     ('a single mouth pop made with the lips, soft and rounded, very short, close', 0.5, -16, FOLEY, "bank:lip", "cut:0.12", "notes:0:1", "tight"),
        "drop":     ('a smooth wooden token dropped onto thick felt, a single soft rounded pop, very short', 0.5, -13, FOLEY, "bank:token", "cut:0.16", "notes:0:-1", "tight"),
        # A peg filled with one colour: two notes a third apart, all but
        # together.
        "lock":     ("one soft short note on a kalimba, muffled and kind", 0.6, -10, COZY_TUNE, "warm:2400", "ease:0.012", "body:300", "notes:0.03:3,7", "cut:0.7"),
        # Not there: lift's take, two low notches alike.
        "refused":  ('one soft tongue click, a hollow rounded pop, close, very short', 0.5, -15, FOLEY, "bank:tongue", "cut:0.26", "notes:0.1:-2,-2", "tight"),
        # Taken back: lift's take, twice and falling.
        "undo":     ('a single mouth pop made with the lips, soft and rounded, very short, close', 0.5, -15, FOLEY, "bank:lip", "cut:0.28", "notes:0.11:1,-2", "tight"),
        "hint":     ("one soft short note on a kalimba, muffled and kind", 0.6, -10, COZY_TUNE, "warm:2400", "ease:0.012", "body:300", "notes:0.16:3,7,10", "cut:1.0"),
        # The rings back on their pegs: drop's take, five notches falling.
        "reset":    ("one small hollow wooden ring set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1400", "cut:0.5", "body:320", "tight", "notes:0.08:4,2,0,-1,-3"),
        # The pegs set out: drop's take, five in a row.
        "enter":    ('a smooth wooden token dropped onto thick felt, a single soft rounded pop, very short', 0.5, -14, FOLEY, "bank:token", "cut:0.5", "notes:0.08:-1,2,-1,1,4", "tight"),
        "solved":   ("one soft short note on a kalimba, muffled and kind", 0.6, -8, COZY_TUNE, "warm:2000", "ease:0.012", "body:300", "notes:0.14:2,5,7,9,11", "cut:1.7"),
        # The streak and the gags. combo: a tick the board pitches by the
        # streak, not past five semitones. twirl: the ring spun on its peg,
        # the wheel spun, four quick notches rising. love: two quiet notes
        # alike and a third up. buzz: the bee, the quietest puff there is.
        "combo":    ('one single bubble of bubble wrap popped between two fingers, a soft small pop, close, very short', 0.5, -14, FOLEY, "bank:wrap", "cut:0.1", "notes:0:1", "tight"),
        "confetti": ("a soft breath of warm breeze that eases, fades and stops, calm, short", 0.8, -17, BREEZE, "warm:900", "steep", "ease:0.05", "body:320"),
        "twirl":    ("one small light wooden bead set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1400", "cut:0.36", "body:320", "tight", "notes:0.07:0,2,3,5"),
        "love":     ("one soft short note on a kalimba, muffled and kind", 0.6, -13, COZY_TUNE, "warm:2400", "ease:0.01", "body:300", "notes:0.1:3,3,7", "cut:0.6"),
        "buzz":     ("a tiny quick puff of warm air, one light short breath that rises and fades, very short", 0.6, -19, BREEZE, "warm:1100", "steep", "ease:0.05", "body:320"),
        # Tumble (Insane): a two-tone ring turning over as it is lifted,
        # lift's take, one notch two steps down.
        "tumble":   ('one single bubble of bubble wrap popped between two fingers, a soft small pop, close, very short', 0.5, -17, FOLEY, "bank:wrap", "cut:0.12", "notes:0:-1", "tight"),
        # Hearts (Hard and Insane). The doomed ring wobbles on the stack as
        # the heart goes, so wobble is three notches, there and back, and the
        # heart one low quiet note: neither is a second fall. hop_back: the
        # ring home again, drop's take, two notches with the second three
        # steps up.
        "wobble":   ("one small hollow wooden ring set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1400", "cut:0.3", "body:320", "tight", "notes:0.07:0,2,0"),
        "heart_lost":    ("one soft short note on a kalimba, muffled and kind", 0.6, -15, COZY_TUNE, "warm:2000", "ease:0.012", "body:300", "notes:0:2", "cut:0.6"),
        "hop_back": ('one single bubble of bubble wrap popped between two fingers, a soft small pop, close, very short', 0.5, -15, FOLEY, "bank:wrap", "cut:0.26", "notes:0.1:1,4", "tight"),
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
        "wall":          ('one soft tongue click, a hollow rounded pop, close, very short', 0.5, -15, FOLEY, "bank:tongue", "cut:0.1", "notes:0:1", "tight"),
        "post":          ('one water drop falling into a cup of water, a single soft plop, close, very short', 0.5, -15, FOLEY, "bank:plop", "cut:0.1", "notes:0:4", "tight"),
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
        "enter":         ('one water drop falling into a cup of water, a single soft plop, close, very short', 0.5, -14, FOLEY, "bank:plop", "cut:0.5", "notes:0.08:1,4,1,3,6", "tight"),
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
        "enter":         ('a smooth wooden token dropped onto thick felt, a single soft rounded pop, very short', 0.5, -14, FOLEY, "bank:token", "cut:0.5", "notes:0.09:-8,-5,-8,-5", "tight"),
        "place":         ('a smooth wooden token dropped onto thick felt, a single soft rounded pop, very short', 0.5, -13, FOLEY, "bank:token", "cut:0.14", "notes:0:-5", "tight"),
        "lift":          ('a single mouth pop made with the lips, soft and rounded, very short, close', 0.5, -16, FOLEY, "bank:lip", "cut:0.12", "notes:0:2", "tight"),
        # Taken back: lift's take, twice and falling.
        "undo":          ('a single mouth pop made with the lips, soft and rounded, very short, close', 0.5, -15, FOLEY, "bank:lip", "cut:0.28", "notes:0.11:2,-1", "tight"),
        # Every bale gone: a breath, Hedgehogs' reset.
        "reset":         ("a soft breath of warm breeze that eases, fades and stops, calm, short", 0.8, -17, BREEZE, "warm:900", "steep", "ease:0.05", "body:320"),
        # Not there (water, a stone, a tunnel, a pinned bale, no bales left):
        # lift's take, two low notches alike.
        "locked":        ('one soft tongue click, a hollow rounded pop, close, very short', 0.5, -15, FOLEY, "bank:tongue", "cut:0.26", "notes:0.1:-1,-1", "tight"),
        # The pen shut, short of its target: it sounds on the frame `place`
        # does, so it is lift's take, two notches with the second four steps
        # up. The pen open again sounds with `lift`, so it is place's take,
        # one notch four steps under place's.
        "closed":        ('one soft tongue click, a hollow rounded pop, close, very short', 0.5, -14, FOLEY, "bank:tongue", "cut:0.24", "notes:0.09:1,5", "tight"),
        "open":          ('a single mouth pop made with the lips, soft and rounded, very short, close', 0.5, -15, FOLEY, "bank:lip", "cut:0.14", "notes:0:-7", "tight"),
        # The pen at its target: two notes a third apart all but together. At
        # the best there is: two alike and a third up. Either sounds over
        # `place`, a tock.
        "ready":         ("one soft short note on a kalimba, muffled and kind", 0.6, -10, COZY_TUNE, "warm:2400", "ease:0.012", "body:300", "notes:0.03:5,9", "cut:0.7"),
        "best":          ("one soft short note on a kalimba, muffled and kind", 0.6, -9, COZY_TUNE, "warm:2400", "ease:0.01", "body:300", "notes:0.1:7,7,11", "cut:0.8"),
        # Check on a pen that is open or too small: place's take, three slow
        # notches falling.
        "not_yet":       ('one soft tongue click, a hollow rounded pop, close, very short', 0.5, -14, FOLEY, "bank:tongue", "cut:0.5", "notes:0.14:-3,-5,-8", "tight"),
        "hint":          ("one soft short note on a kalimba, muffled and kind", 0.6, -10, COZY_TUNE, "warm:2400", "ease:0.012", "body:300", "notes:0.16:3,7,10", "cut:1.0"),
        # The pony patted: its own voice, a real one (PONY), the take of
        # 2026-10-08 with the top rolled off, 3 dB down.
        "neigh":         ("a small pony giving one short soft friendly nicker, a quiet breathy little whinny through the nose, cute and gentle, not loud, not dramatic, short", 0.9, -12, PONY, "warm:2400", "ease:0.01", "body:300"),
        # Made fun (2026-10-27). The pony peeking over the edge on its own:
        # neigh's take (its raw copied to peek.mp3, nothing bought), a step
        # up and quieter, since no finger asked for it.
        "peek":          ("a small pony giving one short soft friendly nicker, a quiet breathy little whinny through the nose, cute and gentle, not loud, not dramatic, short", 0.9, -16, PONY, "warm:2400", "ease:0.01", "body:300", "notes:0:2"),
        # Its hooves as it trots there and back: a run rides the walk, one
        # bubble a cell, quiet (the board varies it at play).
        "trot":          ('one single bubble of bubble wrap popped between two fingers, a soft small pop, close, very short', 0.5, -22, FOLEY, "bank:wrap", "cut:0.08", "notes:0:-4", "tight"),
        # A star won on the pill (two, or the pen grown back to it): the
        # bubble twice rising. One lost: the lip twice falling.
        "star_up":       ('one single bubble of bubble wrap popped between two fingers, a soft small pop, close, very short', 0.5, -15, FOLEY, "bank:wrap", "cut:0.2", "notes:0.08:-4,0", "tight"),
        "star_down":     ('a single mouth pop made with the lips, soft and rounded, very short, close', 0.5, -18, FOLEY, "bank:lip", "cut:0.2", "notes:0.09:-1,-5", "tight"),
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
        "drop":          ('a smooth wooden token dropped onto thick felt, a single soft rounded pop, very short', 0.5, -13, FOLEY, "bank:token", "cut:0.1", "notes:0:-4", "tight"),
        "pick":          ('a small pebble dropped into a calm pond, one soft plop, close, very short', 0.6, -16, FOLEY, "bank:pebble", "cut:0.1", "tight"),
        # Two tiles crossing in their arc: what travels is air, a small puff,
        # Hedgehogs' gust. `hint` sounds on the frame it does, and with motion
        # reduced so does whichever of home, home2 and miss the swap earns, so
        # it is neither a notch nor a note.
        "swap":          ("a tiny quick puff of warm air, one light short breath that rises and fades, very short", 0.6, -16, BREEZE, "warm:900", "steep", "ease:0.04", "body:320"),
        # The swap landed, 0.24 s on. One tile home: drop's take, one notch
        # three steps over drop's. Two at once: two notches, the second four
        # steps up. Neither: pick's take, one notch four steps down.
        "home":          ('a smooth wooden token dropped onto thick felt, a single soft rounded pop, very short', 0.5, -13, FOLEY, "bank:token", "cut:0.1", "notes:0:-1", "tight"),
        "home2":         ('a smooth wooden token dropped onto thick felt, a single soft rounded pop, very short', 0.5, -13, FOLEY, "bank:token", "cut:0.2", "notes:0.09:-5,-1", "tight"),
        "miss":          ('one soft tongue click, a hollow rounded pop, close, very short', 0.5, -16, FOLEY, "bank:tongue", "cut:0.12", "notes:0:-4", "tight"),
        # Taken back: pick's take, twice and falling. Not that one (a tile at
        # home, two of one number): two low notches alike.
        "undo":          ('a single mouth pop made with the lips, soft and rounded, very short, close', 0.5, -15, FOLEY, "bank:lip", "cut:0.26", "notes:0.11:0,-3", "tight"),
        "locked":        ('one soft tongue click, a hollow rounded pop, close, very short', 0.5, -15, FOLEY, "bank:tongue", "cut:0.24", "notes:0.1:-5,-5", "tight"),
        # The deal again: a breath, Hedgehogs' reset. The tiles popping onto the
        # lattice: pick's take, five in a row.
        "reset":         ("a soft breath of warm breeze that eases, fades and stops, calm, short", 0.8, -17, BREEZE, "warm:900", "steep", "ease:0.05", "body:320"),
        "enter":         ('a smooth wooden token dropped onto thick felt, a single soft rounded pop, very short', 0.5, -15, FOLEY, "bank:token", "cut:0.5", "notes:0.08:-6,-3,-6,-4,-1", "tight"),
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
    # Button Box (puzzles/buttons2d.gd, 2026-10-11): wooden buttons on linen
    # and a wooden tin. No new take: the three it is made of are Lattice's,
    # copied into build/sfx_raw/buttons/ -- `pick` (a light wooden button set
    # down on felt, which is this board's own piece by name), `drop` (the
    # hollow block, the tin's wood) and the one muffled kalimba note at 453
    # Hz -- with Hedgehogs' breath for the reset. What repeats has no note in
    # it: `lift` on every tap, then `sew` or `tin` once a button as a run
    # lands, a wheel spun, which the board climbs half a step a button and
    # five at the most. The notes are kept for the streak (`combo`, one note
    # the board pitches up to five steps), a long run sewn at once, a colour
    # whole, the bulb and the day's end; every note lands between 400 and
    # 700 Hz and no two cues share a contour.
    "buttons": {
        # A jewel landing, on a slot or in the case, is Yarn Hoop's point
        # with more room (the user, 2026-10-31: "a ploc sound instead of a
        # wood toc", then of the water take "terrible, I want a sound like
        # the one when you click on the yarn hoop points, a more open
        # sound"): the pebble, its tail left twice as long.
        "lift":          ('a single mouth pop made with the lips, soft and rounded, very short, close', 0.5, -16, FOLEY, "bank:lip", "cut:0.1", "notes:0:-1", "tight"),
        "sew":           ('a small pebble dropped into a calm pond, one soft plop, close, very short', 0.6, -16, FOLEY, "bank:pebble", "cut:0.16", "notes:0:-1", "tight"),
        "tin":           ('a small pebble dropped into a calm pond, one soft plop, close, very short', 0.6, -16, FOLEY, "bank:pebble", "cut:0.16", "notes:0:-5", "tight"),
        # The tin's new place: two tocks of its wood, the second four steps up.
        "open":          ('a single mouth pop made with the lips, soft and rounded, very short, close', 0.5, -13, FOLEY, "bank:lip", "cut:0.2", "notes:0.09:-2,2", "tight"),
        "undo":          ('a single mouth pop made with the lips, soft and rounded, very short, close', 0.5, -15, FOLEY, "bank:lip", "cut:0.26", "notes:0.11:1,-2", "tight"),
        "locked":        ('one soft tongue click, a hollow rounded pop, close, very short', 0.5, -15, FOLEY, "bank:tongue", "cut:0.24", "notes:0.1:-4,-4", "tight"),
        "enter":         ('a smooth wooden token dropped onto thick felt, a single soft rounded pop, very short', 0.5, -15, FOLEY, "bank:token", "cut:0.5", "notes:0.08:-5,-2,-5,-3,0", "tight"),
        "reset":         ("a soft breath of warm breeze that eases, fades and stops, calm, short", 0.8, -17, BREEZE, "warm:900", "steep", "ease:0.05", "body:320"),
        # The streak: one note, pitched by the board. A long run sewn at
        # once: two close together, a third apart. A colour whole: three up.
        "combo":         ("one soft short note on a kalimba, muffled and kind", 0.6, -13, COZY_TUNE, "warm:2400", "ease:0.012", "body:300", "notes:0:0", "cut:0.45"),
        "run":           ("one soft short note on a kalimba, muffled and kind", 0.6, -11, COZY_TUNE, "warm:2400", "ease:0.012", "body:300", "notes:0.06:0,3", "cut:0.6"),
        "whole":         ("one soft short note on a kalimba, muffled and kind", 0.6, -10, COZY_TUNE, "warm:2400", "ease:0.012", "body:300", "notes:0.11:0,4,7", "cut:0.9"),
        "hint":          ("one soft short note on a kalimba, muffled and kind", 0.6, -10, COZY_TUNE, "warm:2400", "ease:0.012", "body:300", "notes:0.16:2,2,5", "cut:1.0"),
        # The day's end, as Lattice times it: `party` starts 0.15 s into
        # `solved` and the seal lands on the party's fifth note.
        "solved":        ("one soft short note on a kalimba, muffled and kind", 0.6, -9, COZY_TUNE, "warm:2000", "ease:0.012", "body:300", "notes:0.07:-2,0,2", "cut:0.6"),
        "party":         ("one soft short note on a kalimba, muffled and kind", 0.6, -9, COZY_TUNE, "warm:2600", "ease:0.012", "body:300", "notes:0.14:3,5,7,4,5,7", "cut:1.4"),
        "stamp":         ("one soft short note on a kalimba, muffled and kind", 0.6, -9, COZY_TUNE, "warm:2600", "ease:0.012", "body:300", "notes:0.26:2,0,7"),
        "out_of_hearts": ("one soft short note on a kalimba, muffled and kind", 0.6, -13, COZY_TUNE, "warm:2600", "ease:0.02", "body:300", "notes:0.32:7,3,-2"),
        "heart_back":    ("one soft short note on a kalimba, muffled and kind", 0.6, -13, COZY_TUNE, "warm:2400", "ease:0.012", "body:300", "notes:0.14:0,5", "cut:0.7"),
    },
    # Yarn Hoop (puzzles/hoop2d.gd, 2026-10-14): pins, yarn and knitting
    # on linen. No new take: the three it is made of are Button Box's,
    # copied into build/sfx_raw/hoop/ -- the light wooden button set down on
    # felt (a pin taken up, a thread laid), the hollow block (a panel
    # filled) and the one muffled kalimba note -- with Hedgehogs' breath for
    # the reset. What repeats has no note in it: `stitch` once a thread,
    # climbed half a step a thread along a drag, and `fill` once a panel,
    # climbed a step a panel the drag closed, five at the most. The notes
    # are kept for a side that fills two panels at once (`double`), a drag
    # that closed three or more (`run`), a colour whole, the bulb and the
    # day's end; every note lands between 400 and 700 Hz.
    "hoop": {
        "pick":          ('a small pebble dropped into a calm pond, one soft plop, close, very short', 0.6, -18, FOLEY, "bank:pebble", "cut:0.08", "notes:0:-3", "tight"),
        "stitch":        ('one single bubble of bubble wrap popped between two fingers, a soft small pop, close, very short', 0.5, -16, FOLEY, "bank:wrap", "cut:0.09", "notes:0:-1", "tight"),
        "fill":          ('one single bubble of bubble wrap popped between two fingers, a soft small pop, close, very short', 0.5, -14, FOLEY, "bank:wrap", "cut:0.12", "notes:0:-2", "tight"),
        "locked":        ('one soft tongue click, a hollow rounded pop, close, very short', 0.5, -15, FOLEY, "bank:tongue", "cut:0.24", "notes:0.1:-5,-6", "tight"),
        "enter":         ('a smooth wooden token dropped onto thick felt, a single soft rounded pop, very short', 0.5, -15, FOLEY, "bank:token", "cut:0.5", "notes:0.08:-5,-3,-5,-1", "tight"),
        "reset":         ("a soft breath of warm breeze that eases, fades and stops, calm, short", 0.8, -17, BREEZE, "warm:900", "steep", "ease:0.05", "body:320"),
        # Two panels at once: two notes close together, a third apart. A
        # drag that closed three or more: two, a fourth apart. A colour
        # whole: three up.
        "double":        ("one soft short note on a kalimba, muffled and kind", 0.6, -12, COZY_TUNE, "warm:2400", "ease:0.012", "body:300", "notes:0.06:0,4", "cut:0.6"),
        "run":           ("one soft short note on a kalimba, muffled and kind", 0.6, -11, COZY_TUNE, "warm:2400", "ease:0.012", "body:300", "notes:0.07:2,7", "cut:0.6"),
        "whole":         ("one soft short note on a kalimba, muffled and kind", 0.6, -10, COZY_TUNE, "warm:2400", "ease:0.012", "body:300", "notes:0.11:0,3,7", "cut:0.9"),
        "hint":          ("one soft short note on a kalimba, muffled and kind", 0.6, -10, COZY_TUNE, "warm:2400", "ease:0.012", "body:300", "notes:0.16:2,5,5", "cut:1.0"),
        "solved":        ("one soft short note on a kalimba, muffled and kind", 0.6, -9, COZY_TUNE, "warm:2000", "ease:0.012", "body:300", "notes:0.07:-3,0,2", "cut:0.6"),
        "party":         ("one soft short note on a kalimba, muffled and kind", 0.6, -9, COZY_TUNE, "warm:2600", "ease:0.012", "body:300", "notes:0.14:2,5,7,2,5,9", "cut:1.4"),
        "stamp":         ("one soft short note on a kalimba, muffled and kind", 0.6, -9, COZY_TUNE, "warm:2600", "ease:0.012", "body:300", "notes:0.26:4,0,7"),
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
        "enter":         ('a smooth wooden token dropped onto thick felt, a single soft rounded pop, very short', 0.5, -14, FOLEY, "bank:token", "cut:0.5", "notes:0.08:-8,-5,-8,-6,-3", "tight"),
        # One notch of the wheel, a step under its take. The board plays it at
        # 1.08 to 0.92 by the answer's size and 0.94 to 1.06 at random, -4 dB,
        # and fx's CUE_GAP holds two 60 ms apart.
        "notch":         ('one single bubble of bubble wrap popped between two fingers, a soft small pop, close, very short', 0.5, -16, FOLEY, "bank:wrap", "cut:0.07", "notes:0:0", "tight"),
        "lock":          ('a smooth wooden token dropped onto thick felt, a single soft rounded pop, very short', 0.5, -13, FOLEY, "bank:token", "cut:0.14", "notes:0:-7", "tight"),
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
        "stamp":         ('a smooth wooden token dropped onto thick felt, a single soft rounded pop, very short', 0.5, -13, FOLEY, "bank:token", "cut:0.2", "notes:0.03:-10,-7", "tight"),
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
        "enter":         ('a smooth wooden token dropped onto thick felt, a single soft rounded pop, very short', 0.5, -14, FOLEY, "bank:token", "cut:0.5", "notes:0.08:-5,-8,-5,-7,-3", "tight"),
        "pick":          ('a small pebble dropped into a calm pond, one soft plop, close, very short', 0.6, -16, FOLEY, "bank:pebble", "cut:0.1", "notes:0:-1", "tight"),
        "lock":          ('a smooth wooden token dropped onto thick felt, a single soft rounded pop, very short', 0.5, -13, FOLEY, "bank:token", "cut:0.14", "notes:0:-5", "tight"),
        # The next question is a page turned: air, Hedgehogs' gust. It sounds on
        # the frame heart_back does when a heart is taken back, a puff under two
        # notes.
        "next":          ("a tiny quick puff of warm air, one light short breath that rises and fades, very short", 0.6, -16, BREEZE, "warm:900", "steep", "ease:0.04", "body:320"),
        # Lock with nothing picked, the bulb with nothing left to cut: pick's
        # take, two low notches alike.
        "refuse":        ('one soft tongue click, a hollow rounded pop, close, very short', 0.5, -15, FOLEY, "bank:tongue", "cut:0.26", "notes:0.1:-6,-6", "tight"),
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
        "stamp":         ('a smooth wooden token dropped onto thick felt, a single soft rounded pop, very short', 0.5, -13, FOLEY, "bank:token", "cut:0.2", "notes:0.03:-11,-8", "tight"),
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
        "enter":         ('one water drop falling into a cup of water, a single soft plop, close, very short', 0.5, -14, FOLEY, "bank:plop", "cut:0.5", "notes:0.08:-4,-1,-4,-2,1", "tight"),
        # The dive: what travels is air, Hedgehogs' whoosh.
        "dive":          ("a long soft gust of warm breeze through leaves, one gentle whoosh of air that rises slowly and fades", 1.0, -16, BREEZE, "warm:1100", "steep", "ease:0.1", "body:320"),
        # The clock's last five seconds, one a second: one notch of the wheel,
        # at -14 (a light tick, but the one that says the time is going: it
        # reads -18 on a phone, as the old one did). The board varies it by
        # 0.94 to 1.06, and the miss and the refusal with it.
        "tick":          ('one single bubble of bubble wrap popped between two fingers, a soft small pop, close, very short', 0.5, -14, FOLEY, "bank:wrap", "cut:0.07", "notes:0:2", "tight"),
        # The ladder counted down after an answer (2026-10-29): one bubble of
        # the wrap a rung, the board lifting each a step; the run of pops
        # rides the bell going down. A star won: a pebble, two up.
        "rung":          ('one single bubble of bubble wrap popped between two fingers, a soft small pop, close, very short', 0.5, -15, FOLEY, "bank:wrap", "cut:0.12", "tight"),
        "star":          ('a small pebble dropped into a calm pond, one soft plop, close, very short', 0.6, -14, FOLEY, "bank:pebble", "cut:0.16", "notes:0.07:0,4", "tight"),
        # Not on the list: twice and falling. It can sound on the frame `dry`
        # or `out_of_air` does (the miss's three seconds ran the clock out),
        # notches under a phrase. Enter on an empty line, and a bulb with
        # nothing left to tell: tick's take, two low notches alike.
        "miss":          ('one soft tongue click, a hollow rounded pop, close, very short', 0.5, -13, FOLEY, "bank:tongue", "cut:0.26", "notes:0.11:0,-3", "tight"),
        "refuse":        ('one soft tongue click, a hollow rounded pop, close, very short', 0.5, -15, FOLEY, "bank:tongue", "cut:0.24", "notes:0.1:-4,-4", "tight"),
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
        "stamp":         ('one water drop falling into a cup of water, a single soft plop, close, very short', 0.5, -13, FOLEY, "bank:plop", "cut:0.2", "notes:0.03:-7,-4", "tight"),
    },
    # the gifts, the shop and the gold pill (spec 2026-09-28-gold-gifts), keyed
    # by the sheets' own puzzle_id "wallet"
    "wallet": {
        # Redone 2026-10-10 against the cozy rules (docs/agents/sound.md), the
        # fiftieth set of the redo, with the Grove's below. None kept: all
        # four were flagged (buy and coin were coins by prompt and 98 and 99%
        # above 3 kHz, raw takes scratch; claim a shower of coins jingling at
        # -5; refused 75% under 300 Hz). Three new takes: `buy` (a hollow
        # wooden block set down on felt), `coin` (a lighter thing set down)
        # and one muffled kalimba note, `claim`'s (three takes: two came back
        # empty, at 273 and 296 Hz and -35 and -30 dB). refused is coin's
        # take. Every tick is `tight` and starts inside 20 ms. No coin rings
        # any more: these play over every board's own sounds, so they are
        # short and none is above -10.
        # A gift taken: three notes up, done in 0.47 s, ahead of the first
        # coin's landing 0.62 s after it (ui/menu/gold_pill.gd's FLIGHT). The
        # note came back at 330 Hz, so steps 5, 9 and 12 land at 440, 555
        # and 660 Hz.
        "claim":    ("one soft short note on a kalimba, muffled and kind", 0.6, -10, COZY_TUNE, "warm:2400", "ease:0.012", "body:300", "notes:0.12:5,9,12", "cut:0.6"),
        # A thing bought in the shop, and nothing else sounds with it: one
        # tock, six steps under its take (916 Hz raw) to stay the heavier.
        "buy":      ('one coin dropped into a small glass jar that holds a few coins, one short soft clink, close', 0.7, -13, FOLEY, "bank:jar", "cut:0.14", "notes:0:-7", "tight"),
        # Gold counted: one notch of the wheel for each coin that lands in
        # the pill, 50 ms apart, four to twelve of them, on the pill's own
        # player (four voices, not Fx2D's, so no CUE_GAP), a step of 0.03 up
        # each: the wheel spun. Two steps under its take so the twelfth, at
        # 1.33, still sits under 1 kHz.
        "coin":     ('one single bubble of bubble wrap popped between two fingers, a soft small pop, close, very short', 0.5, -16, FOLEY, "bank:wrap", "cut:0.08", "notes:0:-3", "tight"),
        # Not enough gold: coin's take, two low notches alike.
        "refused":  ('one soft tongue click, a hollow rounded pop, close, very short', 0.5, -15, FOLEY, "bank:tongue", "cut:0.26", "notes:0.1:-5,-5", "tight"),
    },
    # The Grove (valley/grove_screen.gd, 2026-10-05). `chop` plays on every
    # swing that hits for as long as a finger is held, twice a second at the
    # start and six times late on, and is the sound of the whole place: one
    # low wooden tock. A tree down and a tile bought happen now and then.
    "grove": {
        # Redone 2026-10-10 against the cozy rules (docs/agents/sound.md), the
        # fifty-first set of the redo, with the wallet's above. None kept:
        # build/sfx_raw/ held no take of the four, so nothing could be
        # rendered again. Three new takes: `chop` (a hollow wooden block set
        # down on felt), `fell` (a lighter button) and one muffled kalimba
        # note, `buy`'s. `no` is fell's take. Every tick is `tight`. Nothing
        # new is a hatchet, a sapling, a crack, a hush of leaves or a knock
        # (chop sat at 3.2 kHz and fell at 8 kHz, 85% above 3 kHz).
        # An axe in a tree, and through the screen's quiet voice a beaver's
        # tree down, a log landing on the jetty and a mote of light landing
        # on its plate (valley/grove_screen.gd: TICK_VARY, CLIMB_TOP): the
        # block, one tock from 0 ms, cut ahead of the next swing.
        "chop": ("one small hollow wooden block set down gently on thick felt, a single soft tock, round and hollow, very short", 0.5, -13, HUSH, "warm:1400", "cut:0.12", "body:320", "tight"),
        # A tree down, a crate opened, a raft landed. It sounds on the frame
        # the last chop does, so it is the button's take and not the
        # block's: three notches tumbling down. The take sat at 887 Hz, so
        # they are written one, four and seven steps under it.
        "fell": ("one small light wooden button set down gently on thick felt, a single soft light tock, round and hollow, very short", 0.5, -15, HUSH, "warm:1300", "cut:0.34", "body:320", "tight", "notes:0.09:-1,-4,-7"),
        # A tile or a node of the tree bought: two quiet notes up, no more.
        "buy":  ("one soft short note on a kalimba, muffled and kind", 0.6, -12, COZY_TUNE, "warm:2400", "ease:0.012", "body:300", "notes:0.13:5,9", "cut:0.6"),
        # What the energy does not reach: fell's take, two low notches alike
        # (chop's take holds a second knock 0.16 s behind its tock, past
        # chop's cut, and no row is written from it).
        "no":   ('one soft tongue click, a hollow rounded pop, close, very short', 0.5, -15, FOLEY, "bank:tongue", "cut:0.3", "notes:0.14:-8,-8", "tight"),
    },
}

# Picket Sums (puzzle_id "picket"), 2026-10-22: Sudoku's board with its grid
# fenced into garden plots (puzzles/picket2d.gd extends sudoku2d.gd), so it
# plays Sudoku's set, takes and all, copied into build/sfx_raw/picket/ and
# never bought. Its own cue is `plot`: a plot whose numbers add up to its
# tag, three wraps rising a step apart (a lighter cousin of Teacups' pair).
# All of it unheard.
SETS["picket"] = {
    **SETS["sudoku"],
    "plot":     ('one single bubble of bubble wrap popped between two fingers, a soft small pop, close, very short', 0.5, -13, FOLEY, "bank:wrap", "cut:0.1", "notes:0.06:2,5,9", "tight"),
}


# Every breath of air, 6 dB under the level its line names: the user,
# 2026-10-10, of the swipes in the boards and the loops under a puck or a
# ball, once they were already down: "slide sound ingame still too loud".
# One number for all of them (0 puts each back at its line's level).
BREEZE_TRIM = -6


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
    if cut and loop:
        # A loop written from one tick (Trestle's wheel): `cut` is its whole
        # length to the sample, padded with silence and never faded, so the
        # gap across the seam is the gap between any two of its ticks.
        soft += f",apad=whole_dur={cut},atrim=0:{cut}"
    elif cut:
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


# The user, 2026-10-10, of Firefly's and Posy's sounds once the redo had
# made every one a tick, a breath or a muffled note: "were better before,
# mix the current lofi sounds with it", and of Toy Boats, "I miss water
# sounds on attack miss". So a cue may name `"before:<warm>:<db>"`: the
# file it had before its set was redone, read out of git at the commit
# below, rolled off at `warm` and laid over the new one `db` from it. What
# the old one was is heard again and the new one is the low body under it.
BEFORE = {}


def before_take(board: str, cue: str, raw_dir: pathlib.Path) -> pathlib.Path:
    old = raw_dir / "before" / f"{cue}.ogg"
    if not old.exists():
        old.parent.mkdir(exist_ok=True)
        old.write_bytes(subprocess.run(
            ["git", "-C", str(ROOT), "show", f"{BEFORE[board]}:assets/sfx/{board}/{cue}.ogg"],
            capture_output=True, check=True).stdout)
    return old


def blend(out: pathlib.Path, old: pathlib.Path, peak: int, warm: int, gain: float, loop: bool, body: int = 300) -> None:
    # The old file goes through the same treatment as a take (trimmed,
    # rolled off, eased in, its rumble off), then the two are summed and
    # the sum is put back at the cue's level. A loop ends with the shorter.
    with tempfile.TemporaryDirectory() as tmp:
        soft = pathlib.Path(tmp) / "old.ogg"
        both = pathlib.Path(tmp) / "both.wav"
        to_ogg(old, soft, peak + gain, loop, warm, ease=0.006, body=body)
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(out), "-i", str(soft), "-filter_complex",
                        f"[0][1]amix=inputs=2:normalize=0:duration={'shortest' if loop else 'longest'}",
                        "-ac", "1", "-c:a", "pcm_f32le", str(both)], check=True)
        probe = subprocess.run(["ffmpeg", "-i", str(both), "-af",
                                "astats=measure_overall=Peak_level:measure_perchannel=none",
                                "-f", "null", "-"], capture_output=True, text=True).stderr
        top = float(re.search(r"Peak level dB: (-?[0-9.]+)", probe).group(1))
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(both), "-af", f"volume={peak - top:.2f}dB",
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
        if style is BREEZE:
            peak += BREEZE_TRIM
        loop = "loop" in rest[1:]
        warm = next((int(f[5:]) for f in rest[1:] if isinstance(f, str) and f.startswith("warm:")), 0)
        cut = next((float(f[4:]) for f in rest[1:] if isinstance(f, str) and f.startswith("cut:")), 0.0)
        ease = next((float(f[5:]) for f in rest[1:] if isinstance(f, str) and f.startswith("ease:")), 0.0)
        raw = raw_dir / f"{cue}.mp3"
        # `bank:<name>` (2026-10-15): the take is one of the kept pops in
        # tools/sfx_bank/ (the user's picks from the coin and pop pages of
        # that day; docs/agents/sound.md), copied into the board's raw dir
        # and never bought. A copy, not a reference: `tune` writes its
        # phrase beside the source, so every cue keeps its own. The prompt
        # in the row is the bank take's, for the record.
        bank = next((f[5:] for f in rest[1:] if isinstance(f, str) and f.startswith("bank:")), "")
        if bank and ("--new" in flags or not raw.exists()):
            raw.write_bytes((ROOT / "tools/sfx_bank" / f"{bank}.mp3").read_bytes())
        elif "--new" in flags or not raw.exists():
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
        before = next((f[7:] for f in rest[1:] if isinstance(f, str) and f.startswith("before:")), "")
        if before:
            # A third number is the old file's own `body`: 300 unless it was
            # a thump, which keeps what a phone does not play for the ears
            # that can hear it.
            old_warm, gain, *low = before.split(":")
            blend(out, before_take(board, cue, raw_dir), peak, int(old_warm), float(gain), loop, int(low[0]) if low else 300)
        print(f"{cue:9s} -> {out.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
