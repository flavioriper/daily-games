# Paper Box

- **Paper Box is a Puzzles card (2026-10-22, unattended)**, the roadmap's
  twelfth, a mental-rotation board under Space. A paper net on a cutting
  mat and three or four boxes under it; pick the box it folds into, five
  rounds a day. Spec `docs/superpowers/specs/2026-10-22-paperbox-design.md`.
  The id is `paperbox` and the locale prefix `PB_`.
- Files: `puzzles/paperbox2d.gd` (the board, extends `core/puzzle_base.gd`),
  `puzzles/paperbox_state.gd` (bands, the deal, the wrong boxes, picks, the
  bulb's strike), `puzzles/paperbox_fold.gd` (the eleven nets, the fold's
  frames, the 24 turns, pictures, the iso projection),
  `puzzles/paperbox_world.gd`, `ui/faces/paperbox_art.gd` (papers, the
  sheet renderer, the box, stamps, hatch, shelf spot),
  `ui/hud/paperbox_tutorial_diagram.gd`, `ui/menu/cards/paperbox.gd`.
- **One fold model serves the rules and the animation.** `Fold.frames(net,
  root, angles)` places every square at its hinge angle (0 flat, PI/2
  shut); the rules read the shut frames' normals and stamp ways, the board
  draws the same frames at the angles of the moment. Change the fold and
  both move together.
- **A wrong box is proven against every turn of the box** (`Fold.pictures`,
  24 keys) and starts from its own random turn, never from the right
  picture (the right box would otherwise be the one the others agree with).
  `tests/_probe_paperbox.gd` re-proves 365 days a band and measures that
  tell.
- **The board runs on its own clock** (`_t`, stood still while
  `clock_held`) and a queue of timed jobs (`_after`), as Teacups' does. A
  harness steps it by calling `_process(delta)`, and must shoot a frame
  after stepping (a shot in the same frame shows the last draw).
- **Meshes**: the shelf and the net at rest are cached by key; the boxes,
  their shadows, the hatch and the ring are cached by key and size and let
  go at the end of a `_draw` that no longer used them (never in
  `_relayout`, which ran between a draw and its render and freed meshes
  still on the canvas: "Parameter mesh is null"). The fold is one mesh a
  frame, kept as a member until the next.
- **The board is its own tutorial**: `demo` makes it silent, deaf and laid
  in its own rect; the diagram taps boxes with `demo_tap`. Lessons FOLD,
  OPPOSITE (an Easy deal), CORNER (a Hard deal), STAMPS (Insane only, an
  Insane deal), HINT; each picks the wrong box of its lesson's kind, then
  the right one, and rests once that box is on the shelf.
- **Draw calls**: 77-92 in play (77-90 on Hard under ANGLE), 107-146 on the
  win with the report, 95-102 a tutorial page, 6 on the card.
- Harness: `tests/_win.gd -- paperbox` (real touches: a wrong box, a tap on
  it again, a tap on the mat's foot that picks nothing, the bulb's real button, then each round's right box with the
  fold stepped through); `tests/_shot_paperbox.gd -- <dir> d=<0..3>
  [tut=<page>|card]` shoots rest, wrong, hinted, each beat of the fold, the
  next round, the win and the reopened day.
