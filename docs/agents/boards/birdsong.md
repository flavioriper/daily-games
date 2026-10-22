# Birdsong

- **Birdsong is a Puzzles card (2026-10-22, unattended)**, the roadmap's
  second and the second Memory board. A bird on a branch sings a tune on
  Drumbeat's drums; play it back; one note longer each round. Spec
  `docs/superpowers/specs/2026-10-22-birdsong-design.md`.
- Files: `puzzles/birdsong2d.gd` (the board, extends `core/puzzle_base.gd`,
  not Drumbeat: nothing of Drumbeat's clock or chart is used),
  `puzzles/birdsong_state.gd` (bands, tune, rounds, slips),
  `puzzles/birdsong_world.gd`, `ui/faces/songbird.gd` (the bird and the
  quaver), `ui/hud/birdsong_tutorial_diagram.gd`, `ui/menu/cards/birdsong.gd`
  (extends Drumbeat's card for its drums and go drum).
- **The board runs on its own clock** (`_t`, stood still while
  `clock_held`) and a queue of timed jobs (`_after`): the song, the turn,
  the round's flourish. A harness steps it by calling `_process(delta)`.
- **The board is its own tutorial**: `demo` set before it enters the tree
  makes it silent, deaf and laid in its own rect; the diagram plays it with
  `demo_strike(d)`. Lessons LISTEN, PLAY, SLIP, WHISPER (Insane), HINT.
- Taps aim at the nearest drum across anywhere under the row (`drum_at`).
- Sounds: `tools/gen_sfx.py` set `birdsong`, Glimpse's takes copied into
  `build/sfx_raw/birdsong/`; `note_k`/`drum_k` are copies of
  `assets/sfx/drumbeat/drum_k.ogg`. Unheard.
- Harness: `tests/_win.gd -- birdsong` (real touches, one slip, one bulb);
  `tests/_shot_birdsong.gd -- <dir> d=<0..3> [tut|card]` shoots the song,
  a berry played back, a slip, the win, a tutorial page or the card, with
  draw calls.
- Seen windowed on ANGLE at 810x1440: Medium and Hard play, the win and its
  brain report, the first tutorial page, the card. 105-115 draw calls in
  play, ~156 on the win, ~189 with a tutorial page over it. Not seen: a
  phone, reduce motion, pt/es read by a speaker, the sounds heard.
