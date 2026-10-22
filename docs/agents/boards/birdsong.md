# Birdsong

- **Birdsong is a Puzzles card (2026-10-22, unattended)**, the roadmap's
  second and the second Memory board. **Redesigned the same evening** at
  the user's word: a woodpecker knocks a rhythm on the old tree's trunk,
  one bar of four beats, and the player knocks it back on one drum; each
  round adds a knock. The songbird, its four drums and Whisper are history.
  Spec `docs/superpowers/specs/2026-10-22-birdsong-design.md` section 7;
  concept tab `docs/brainstorm/concepts.html#woodpecker`.
- Files: `puzzles/birdsong2d.gd` (the board, extends `core/puzzle_base.gd`),
  `puzzles/birdsong_state.gd` (bands, the day's knocks and their order,
  judging), `puzzles/birdsong_world.gd` (the garden; `trunk_edge`),
  `ui/faces/woodpecker.gd` (body and head meshes),
  `ui/hud/birdsong_tutorial_diagram.gd`, `ui/menu/cards/birdsong.gd`
  (extends Drumbeat's card for its go drum).
- **Judged between the player's taps** (`State.heard(t)`): the first knock
  anchors the bar, the rest are held to their places from it; `missed(t)`
  finds a place passed. The user picked this over judging on a running
  beat, so no per-phone timing (Drumbeat's tap-along) is needed. Keep it.
- **The board runs on its own clock** (`_t`, stood still while
  `clock_held`) and a queue of timed jobs (`_after`): the pecks, the beats,
  the turn. A knock is timed between two steps by `_now()` (the real time
  since the last step, at most 50 ms). A harness steps it by calling
  `_process(delta)` and knocks when `clock() >= knock_due(state.landed)`.
- **The board is its own tutorial**: `demo` set before it enters the tree
  makes it silent, deaf and laid in its own rect; the diagram knocks with
  `demo_knock()`. Lessons LISTEN, PLAY, SLIP, FEINT (Insane), HINT. The
  lanes size with the card's height so the short page still reads.
- Sounds: `tools/gen_sfx.py` set `birdsong`: `peck` (bank token, +1),
  `tick` (bank pebble, quiet), `feint` (bank lip); `drum.ogg` a copy of
  `assets/sfx/drumbeat/drum_0.ogg`; the rest Glimpse's takes. Unheard.
- Harness: `tests/_win.gd -- birdsong` (real touches on each knock's place,
  round two's last knock left out, one bulb);
  `tests/_shot_birdsong.gd -- <dir> d=<0..3> [tut|card]` shoots a peck
  mid-bar, two knocks landed, a slip, the win, a reopened day, a tutorial
  page or the card, with draw calls.
- Seen windowed at 810x1440, desktop GL and ANGLE: every band plays
  through, the win and its brain report, a solved day reopened, the first
  tutorial page, the card. 89-132 draw calls in play, up to ~167 with a
  tutorial page. `tests/_probe_insane_hints.gd -- id=birdsong`: 0 failures.
  Not seen: a phone, reduce motion, the sounds heard, pt/es read by a
  speaker.
