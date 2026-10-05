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

**What repeats a lot is a click (user, 2026-10-05).** "It's important to
avoid bell or ring sounds for something that repeat a lot, so use something
more like a click." A chain's pebbles, a gun's shots, tiles landing: short,
dry, no note. Notes are for what happens now and then. A constant action
still gets its sound -- "a really subtle click", not silence.
