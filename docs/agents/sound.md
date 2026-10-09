<!-- Moved verbatim from CLAUDE.md on 2026-09-29. -->

## Sound

Full rules: `docs/art/sound-direction.md`. Sounds are generated with
ElevenLabs by `tools/gen_sfx.py <puzzle_id>` into
`assets/sfx/<puzzle_id>/<cue>.ogg`, and `Fx2D.cue()` plays whichever cue has
a file -- a missing file is silence, on purpose. Soft wood, marimba, kalimba,
glockenspiel and paper; never a buzzer; up means good, down means not yet;
cues that fire on every touch (Binairo's `focus`, `blush_out`) get no file.
One take per cue; the user listens and names the ones to redo. The set is
keyed by `puzzle_id()`, not the card's name (Code Break's is `mastermind`).
Every flat board has a set, Fairy Lights included (2026-09-23). Every button clicks through `ui/ui_sound.gd`, wired by
`CozyTheme.dress()`, and keeps quiet when a board cue answered the same frame.

**Never synth (user, 2026-10-05: "we need cozy sounds, to avoid synth").**
Every file is an ElevenLabs take of real acoustic things -- kalimba, music
box, hand bells, tongue drum, close-mic foley. No prompt says retro, blip,
zap, 8-bit, synth or tape rewind, and no tool sums sines into a sound. A
tune that has to be exact is sequenced from recorded single notes
(`tools/gen_marigold_music.py`). **The one exception left is Drumbeat**: its
three songs, their lead tracks, the four drums and the calibration clicks
are still synthesised by `tools/gen_drumbeat.py` (the user: "skip drumbeat
for now"). The pass itself: `docs/art/sound-direction.md`, its last section.

**Nightlight has a set since 2026-10-06** (`HEARTH` foley and `ARCADE`
notes, fourteen cues; `docs/agents/arcade.md`). A space game gets no pad
and no laser. **Heard on 2026-10-09 and "too harsh"**: its notes are
`HEARTH_TUNE` now (kalimba and tongue drum, low and muffled, no bells, no
"bright", no "sparkle"), every cue has `warm` and the new `ease:<seconds>`
fade-in, and no note peaks above -11 (`nova` -8). When a set is asked to be
cozier, that is the order: what the game adds at play, then level and
roll-off, then the prompt's words. **A harness is heard on this Mac**: run one that plays a
game with sounds under `--audio-driver Dummy`.

**What repeats a lot is a click (user, 2026-10-05).** "It's important to
avoid bell or ring sounds for something that repeat a lot, so use something
more like a click." A chain's pebbles, a gun's shots, tiles landing: short,
dry, no note. Notes are for what happens now and then. A constant action
still gets its sound -- "a really subtle click", not silence.

**Horse Pen has a set since 2026-10-08** (`SETS["horse"]`, `MEADOW` foley,
`MEADOW_TUNE` notes and `PONY` for the `neigh`, eighteen cues): one take a
cue, unheard by the user. A bale dropped, lifted or undone is dry straw
with no note. Details: `docs/art/sound-direction.md`, its last section.

**How Big? has a set since 2026-10-08** (`SETS["how_big"]`, `BENCH` foley of
a carpenter's bench and `BENCH_TUNE` notes, sixteen cues): one take a cue,
unheard by the user. `notch` is the one that repeats (a click every 8% the
answer grows or shrinks): a ruler's joint, cut to 0.07 s at -19, and the
board pitches it down as the thing gets bigger. Details:
`docs/art/sound-direction.md`, its last section.

**Golden Acorn has a set since 2026-10-08** (`SETS["acorn"]`, `QUIZ` foley of
a card table -- index cards, a wooden tile, a pencil -- and `QUIZ_TUNE`
notes, fourteen cues): one take a cue, unheard by the user. `pick` is the
one that repeats (every tap on an answer): a wooden tile set down, cut to
0.1 s at -15, no note. The held breath after a lock is silence, not a drum
roll. Details: `docs/art/sound-direction.md`, its last section.

**Pearl Dive has a set since 2026-10-09** (`SETS["pearl"]`, `JETTY` foley of
a wooden jetty over calm water -- drops, bubbles, a wet rope, a plank -- and
`JETTY_TUNE` notes, sixteen cues): one take a cue, unheard by the user.
`tick` is the one that repeats (the clock's last five seconds): a wooden
clock's tick, cut to 0.07 s at -16, no note. `miss` can come several times
a prompt and is two dull knocks on a plank, no note either. The keyboard's
keys click through `ui/ui_sound.gd` as Hidden Word's do; the board adds no
cue a letter. Details: `docs/art/sound-direction.md`, its last section.

**Lattice has a set since 2026-10-09** (`SETS["lattice"]`, `TILES` foley of
wooden game tiles and a wooden lattice on a garden table and `TILES_TUNE`
notes, seventeen cues): one take a cue (`home` two), unheard by the user.
`pick`, `swap` and one of `miss` or `home` sound on every move, so with
`drop` and `undo` they are dry wood cut to 0.1-0.28 s with no note; the
notes are `home2` (two tiles home at once), `line`, `hint` and the day's
end. Details: `docs/art/sound-direction.md`, its last section.
