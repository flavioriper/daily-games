# Untangle

Rebuilt 2026-09-29 as a wooden ring of pegs with physical rope, thread on Hard
and Insane, and an Insane kitten. Spec:
`docs/superpowers/specs/2026-09-29-untangle-ring-design.md` (read it first; the
2026-09-18 lantern board's spec is history). Built unattended at the user's
word, on `feat/untangle-rope`, with no concept tab.

- **Files.** `puzzles/untangle_gen.gd` (rule on plain int arrays, the dealer,
  the beam search), `untangle_state.gd` (moves, thread, the kitten, undo,
  hint, reset), `untangle_rope.gd` (one Verlet rope and its mesh),
  `untangle2d.gd` (the board), `ui/faces/kitten_face.gd`,
  `tests/_shot_untangle.gd` (the harness: `-- d=0..3 rest|hold|taut|plan|wrong|answer|out|hint|undo|reset|perf [rm]`,
  frames go to its `SHOT_DIR`).
- **The rule** is `Gen.crosses(a, b, c, d)` on hole indices; peg = `2 * rope + end`,
  `at[peg]` = hole. Everything else (reach, thread, the kitten) is a legal-move
  filter or a schedule on top of it.
- **Par is measured, not proven.** The old plan (a vertex-cover lower bound
  from the scramble) was dropped: a scramble moves more ropes than R - 1, so the
  bound is never tight. `Gen.way_home` (beam, width 36, depth 14) gives par and
  the hint. A greedy "fewest crossings" bot needs par + 1..7 on Hard and up
  to par + 16 on Insane (`docs/superpowers/specs/2026-09-29-untangle-ring-design.md`,
  section 3); thread is par + 3 on both.
- **The kitten's determinism is the whole fairness argument.** Her schedule is
  `state.swipes` (move number -> peg) with `Gen.swipe_fallback` past the list;
  her target is `Gen.cat_hole` (nearest empty hole the rope can span, clockwise
  first); `moves_here` (moves since the last Reset) is what the schedule
  reads, not `spent`. `_cat_deal`, `way_home`, `_play`, `State.move` and
  `State.swipe_peg` must agree. `way_home` keys its `seen` set with
  `moves % 3` when she is loose, because the same layout plays out differently
  before and after a swipe.
- **Drawing.** Ring + embroidery: one static mesh. Each rope has its own mesh,
  rebuilt only when its pegs, lift, fade or glow changed or it is still awake
  (`_rope_sig`, `_calm`). Pegs are cached cap meshes (with and without the
  coloured inlay) drawn under a scale transform, with the family's
  `Scenery.shadow()` under each; faces, hats and the paw print are one small
  extras mesh. **The first version rebuilt every rope and peg per frame: 11-18
  ms carrying a peg; cached, 5.7-6.9 ms.** Keep any mesh handed to `draw_mesh`
  in `_shown` until the next `_draw`.
- **Peg positions are display truth.** `_peg_px` is where a peg is drawn
  (finger, flight or hole); the crossing marks are read off it
  (`_shown_crossings`), not off `state`, so a peg in the air has already left
  the marks behind. `state.at` changes at the drop, and the kitten's peg is
  drawn at its old hole until her swat (its flight `t0` is in the future).
- **`is_solved()` waits for the board to settle** (nothing held, no flight, the
  busy hold over) and is true once done; `_flow` calls `check_solved()` /
  `_run_out()` from `_process`. A harness that plays a move a frame calls
  `settle_now()` between them (`tests/_win.gd`).
- **Rope whip is a kick on the Verlet chain** (`Rope.kick`) plus a decaying
  slack; the rest length tracks the gap, so ropes are near-straight and never
  loop. Do not give the rope a fixed length shorter than its reach span or a
  held peg cannot reach a hole its own rule allows.
- **Insane hints are a video's** (`hints_left()` is `budget + extra - used`, the
  base is 0), because `hints_left() <= 0` is what makes the host offer the
  video; a board that returned 0 for "no hints of my own" would have the host
  offer a video that gives nothing (Balance's Insane still does).
- **Sound**: `tools/gen_sfx.py untangle`; `hover` deliberately has no file.
  Every other cue in the board has one. Awaiting the user's listen.
- **Measured (this Mac, 810x1440)**: 99 (Easy) to 124 (Insane) draw calls at
  rest, whole screen; idle 3.6-3.9 ms; carrying a peg 5.7-6.9 ms.
  Generation mean/worst: Easy 2/3 ms, Medium 9/14, Hard 57/250, Insane 71/155.
- **Open**: a lost day is not saved (reopening deals it fresh); no phone, ANGLE
  or listening pass yet.
