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
