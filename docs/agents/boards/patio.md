# Domino Patio

- **Domino Patio is a Puzzles card (2026-10-22, unattended)**, the roadmap's
  third: lay the house's dominoes on a patio of flower beds so every bed
  keeps the rule on its tag. Logic (numbers live inside Logic). Spec
  `docs/superpowers/specs/2026-10-22-domino-patio-design.md`. The genre's
  own name, and the same word for a tile's dots, are never used: they are
  spots.
- Files: `puzzles/patio2d.gd` (the board, extends `core/puzzle_base.gd`),
  `puzzles/patio_state.gd` (placements, beds, Undo, the bulb's move),
  `puzzles/patio_gen.gd` (the day, the counting solver),
  `puzzles/patio_world.gd`, `ui/hud/patio_tutorial_diagram.gd`,
  `ui/menu/cards/patio.gd`. The tile is `ui/faces/domino_tile.gd`, lifted
  out of `versus/dominoes_board.gd` (which now calls it) so both boards and
  both cards share one drawing.
- **A tile is drawn where the rules put it**: `_process` compares each
  tile's `[at, dir]` with the place it was gliding to (`_key`) and starts a
  glide from where it was shown last frame (`_last_pos`) when it changed.
  So a drop, Undo, the bulb and the bin need no animation code of their
  own. A turn is `Motion.turn_angle` on the new mesh.
- Input: a press on a tile (patio by square, rack by bay), a move past
  `TAP_PX` lifts it (`_press.moved`), the release lays it at `_drop_at`
  (nearest fitting pair within `REACH`), refuses it over the patio, or
  sends it to its bay. A release without a move is `_tap`, a quarter turn.
- **A turn on the rack is no move**: it pushes no history, and `undo()`
  keeps the way a tile still on the rack was turned.
- The answer is the bulb's only (`hint_move`): solved is the beds' rules
  (`State.solved`). `right(t)` treats a tile turned end for end inside one
  bed as right.
- **The board is its own tutorial**: `demo` set before it enters the tree
  makes it silent and deaf; the diagram lays tiles with `demo_lay(t)` and
  turns with `demo_turn(t)`. Lessons LAY, TURN, BEDS, BOUNDS (Medium on),
  SPARE (Insane), HINT.
- Sounds: `tools/gen_sfx.py` set `patio`, bank pops plus Birdsong's takes
  copied into `build/sfx_raw/patio/`. Unheard.
- Harness: `tests/_win.gd -- patio` (real touches: turn taps on the rack,
  drags onto the patio, one tile dragged off and laid again, one bulb);
  `tests/_shot_patio.gd -- <dir> d=<0..3> [tut|card]` shoots rest, held,
  half, refuse, broken, the win, the reopened day and the card, with draw
  calls. `tests/_probe_patio_gen.gd -- n=<seeds>` times the generator.
- Seen windowed on ANGLE at 810x1440: Medium and Insane at rest, a tile
  held, half laid with ticks, a refusal, a broken bed, the win and its brain
  report, a solved day reopened, the first tutorial page (Insane), the card,
  and a level change from Medium to Hard (`tests/_probe_level_slide.gd --
  patio to=2`: the world still, the board slid, one board left).
  Draw calls: Medium 114 rest, 132 at most in play, 200 on the win; Insane
  159 rest, 188 in play, 269 on the win. `tests/_probe_insane_hints.gd --
  id=patio seeds=4`: 0 failures, every day carried by the bulb. Not seen: a
  phone, reduce motion, Easy and Hard on screen, pt/es read by a speaker,
  the sounds heard.
- Open, the user's to call: everything in the spec's section 7, in
  particular the worst generation time (~260 ms on this Mac on Hard and
  Insane, over Quilt's 194 ms gate) and Insane's many lone-square beds.
