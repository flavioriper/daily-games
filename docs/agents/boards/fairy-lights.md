# Fairy Lights

- **What it is** (2026-09-20, `puzzles/fairy_lights2d.gd`, rules in
  `puzzles/fairy_lights_state.gd`, deals in `puzzles/fairy_lights_gen.gd`,
  spec `docs/superpowers/specs/2026-09-20-fairy-lights-flat-design.md`, mock
  `docs/brainstorm/concepts.html#fairylights`). A garden of paving stones, a
  lantern post in the middle and a length of wire on every stone; a tap turns
  a piece a quarter turn clockwise, and that is the only gesture. Wire joined
  back to the post runs gold. Done when every stub meets a stub and every
  lantern is lit. The flat spec names the genre it follows once, to forbid
  it; nothing else does. **Live is derived, never stored** (`state.depths()`
  every call), and the board keeps only *moments* (`_live_at`, `_out_at`,
  `_wake_at`, `_dark_at`), so undo needs no book.
- **The polish** (2026-09-30, `feat/fairylights-polish`, spec
  `docs/superpowers/specs/2026-09-30-fairylights-polish-design.md`): Hard and
  Insane judge one mistake, **a turn of a piece that is already right** (a
  fuse: sparks, a brown-out, a heart, and a brass clip that holds the piece
  for good); Insane is **Wish Tags**, an 8x8 garden the ordinary rules cannot
  finish, whose lanterns wear their distance along the wire from the post,
  banked in `content/insane/fairylights.json` (150 gardens, 4 tags each,
  mined through `tools/insane/fairylights_ladder.gd`); the streak, join
  sparks, moth / hum / love gags, the party (dance, fireflies, the nap cat,
  gold tags, the seal); re-prompted cozy sounds (unheard).

## Numbers

| band | garden | cell | hints | hearts |
|---|---|---|---|---|
| Easy | 5x5 | 188 | 3 | - |
| Medium | 6x6 | 157 | 3 | - |
| Hard | 7x7 | 134 | 1 | 3 |
| Insane | 8x8 Wish Tags | 118 | 0 | 2 |

Peak draw calls at 810x1440 (the spec's section 6 has every mode): rest
102-125, fuse 124 (Hard), out with the card 139, tags 144, solve 139 (Easy) /
173 (Insane, and on ANGLE), restore 152 -- far under 855. Suite 123054/0;
`tests/_win.gd -- fairylights` winnable 1/1 (6x6, 33 turns).

## Harness

    godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_fairylights.gd -- d=2 fuse

Modes `rest press fuse out tags howto restore right solve`, `d=0..3`, `rm`
for reduce motion, `out=<dir>` for the frames (default `/tmp`). Windowed and
one at a time.

## Review findings, fixed (2026-09-30)

- **One finger turns a piece**: the press keeps its touch index
  (`_press_finger`, -1 for the mouse) and another finger's press, slide and
  release are ignored. The turn fires only when the finger lifts from the
  piece it went down on while still held -- before, a slide from one piece to
  the next turned the second, a second finger turned a second piece, and a
  cancelled touch or a release with no press (one pressed during a fuse)
  still turned whatever was under it, which on Hard and Insane can be a fuse.
- **A wake chime still to come dies with its lantern**: `_settle` drops
  queued `_wake_cues` for any cell the move left dark, and `_run_out` drops
  them all. An undo or Reset inside the wash had still rung the lantern awake
  and played its moth, hum or love over it going dark.
- **`can_reset()`** greys Reset during a fuse, out of hearts and once done
  (the host logged a `board_reset` that did nothing).
- Checked and left: the board stops rebuilding after the party and after a
  restore (the mesh is the same object 1.5 s apart, `_animating()` false,
  the life layer quiet); under reduce motion lantern transforms are identical
  1.5 s apart; Try again clears clips, gives every heart back and keeps a
  hint's pin; the winning turn's join spark lands 0.2 s after the tap, before
  the chase, so it is not over the party.

## The checkup (2026-10-02)

- **The wire is shapes now.** `_build` reads every cell's curves once
  (frame, pull, lift, level, chase, press, bead pop) and gives each a look
  (`_look`): the stubs, which of them meet (`_matched_of`), lit, no middle
  bead, a clip on, a tag's reading and gold -- or -1 while anything on the
  cell is not at its resting value. Cells with a look are put pass by pass
  (`P_WASH` .. `P_TAG`, the live passes' own order) from shapes made once
  (`_shape`, id `pass << 16 | look`) into the rest mesh (`_build_rest`),
  handed back while the plan of looks and pins is unchanged; the rest are
  drawn live into the mesh `_build` returns, drawn over it. A live cell's
  glow and wash land over its still neighbours while it moves (Quilt's
  trade). `_arms`, `_glow`, `_beads`, `_arm_end_m` take a piece's masks, not
  its cell, so a shape can be drawn about the origin.
- **Built in a reference layout's space** (Bridges'): `_in_ref` swaps
  `_grid`/`_cell` for the largest layout of this deal while the still, rest
  and live meshes are built, and `_draw` puts them under `_relay()`. The win
  card's smaller relayout rebuilds nothing; a new deal (`_dealt`) takes a new
  reference. Fixed-pixel lips scale with it there.
- **The lanterns are painted** by the `Lanterns` child (`_draw_lanterns`):
  each LanternFace is `painted` (its node draws nothing) and its
  `layers_now()` go into one RunMesh under the slot's and its own transform,
  origin rounded to a whole pixel (the renderer does that to a node; without
  it every lantern sat half a pixel off). A lantern whose `modulate` is not
  white (the press shade) or that is hidden is drawn by its node. The paint
  is redrawn from `_dress`, `_refresh` and `_sway_all` (while any lantern is
  lit), which covers the sway, the blinks and the entrance.
- **The tutorial** (`ui/hud/fairylights_tutorial_diagram.gd`) plays a
  quietened board (`Garden`: no sounds, tips, gags, streak, party or card;
  a fuse never runs the hearts out) on a hand-dealt 4x4 garden laid by
  `lay()` through the board's own `_dealt()`. Pages: TURN, DONE, HEARTS
  (Hard/Insane), TAGS (Insane), UNDO, HINT (bands with hints). The garden
  takes the page's whole width, `_inset()` the frame alone and the hearts
  beside it (`_heart_row()` 0, `_hearts_at()`).
- Probe: `tests/_probe_perf.gd -- fairylights d=<0..3> [fill]` taps every
  piece round to its answer; `x=fl_count` times a rest-mesh build, a handed-
  back build, the still mesh and the lantern paint; `x=fl_lanterns` hides
  every lantern.
- **Insane counts moves (2026-10-04,** `docs/agents/flat-screens.md`,
  "Insane counts moves"**).** `State.HEARTS` is `[0, 0, 0, 0]`, so `judged`
  is false on every band: a turn of a piece that is already right is a turn
  like any other (no RIGHT, no fuse, no clip, no heart -- the fuse was the
  answer with a price on it). The fuse, the clips and the hearts' drawing
  are left in place, dormant. Wish Tags hands out
  `State.moves_budget()` = `shortest_solve()` + max(3, a quarter of it,
  rounded up), where the shortest solve is the sum over pieces of the
  quarter turns clockwise from the deal to the answer -- a true optimum (one
  answer, a turn moves one piece one way). Over the bank's 150 gardens that
  is 70-111 turns (median 87), budgets 88-139. Every turn costs one
  (`_spend(1, ...)` after `note_move()`); a cross or a pinned piece refused
  costs nothing. Out of moves is `out_of_hearts` and the old dark ending;
  the card is opened with `MOVES_BONUS` (5). Reset and Try again hand the
  budget back. No Undo and no hint on Insane (`capabilities()` is empty,
  `can_undo()` false), the tutorial drops its UNDO page there and ends on
  `MovesDiagram.page`; the completion record keeps `moves_left`. Kept: the
  gold wire, the loose round tips and the tags' tick or rose number, all read
  off the wire as it stands and never off `sol`. `max_moves` is read in
  `build()`, not `_dealt()`, so the tutorial's hand-dealt gardens count
  nothing. Surprising: a clockwise-only turn makes one overshoot cost four
  moves (the wrong one and three to come round), so the slack of ~22 is five
  slips, not twenty-two. Not updated: `FL_LVL_3` still says "two hearts",
  and `tests/_shot_fairylights.gd`'s `fuse` and `out` modes have no fuse to
  shoot.
