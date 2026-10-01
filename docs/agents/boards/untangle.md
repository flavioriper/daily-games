# Untangle

**Live carry and clean rope (2026-09-30)**, after the user: "the wire is not
reacting live with other, it create nots only after releasing, and the
notches are all pixeled".

- **The tangle reacts under the hand.** `_carry_tangle` runs every frame a
  peg is held: the straight carry from its hole to the hand passes over every
  rope whose peg-to-peg chord it crosses, and `Gen.apply_toward` applies the
  rule for just those ropes toward where that chord meets the ring (a
  fractional hole). Each pair's result depends only on the two ropes' pegs,
  which is why a fractional target is enough. Carried onto a hole, it is
  exactly `Gen.apply` (`tests/_probe_ut_live.gd`: 1488/1488 moves over four
  bands); `apply` is now `apply_toward` plus the `at` write. Put back
  (`_go_home`, `_drop_held`) shows `state.tw` again. The cinch / unwind
  cues play as the hand does it; `_landed` plays them only if the drop
  changed what was already shown (a hint, a tapped drop).
- **The shards were the ribbon flipping.** `Rope._ribbon` turned each
  point's normal to face away from the light, so wherever a rope turned
  across the light the strip folded over. The normal is now carried along
  the line and the lit side is blended per point (`_sample` mirrors the
  stops).
- **Folds.** `_folds` in the harness (`carry` mode) counts turns over 100
  degrees in the chain and the drawn line. They came from three places, now
  closed: a rope's braids overlapping along it (`_space_braids` pushes them
  apart along the rope and shortens them to fit, `BRAID_SHORTEST`); a
  twist laid on every drawn point near a braid, including the next braid's
  (a wiggle now carries `i0`/`i1`, the chain stretch held to it, and
  `_twist` works only there); and a braid placed at the point nearest all
  four pegs when a short rope could never reach it (`_braid` pulls it toward
  the rope that is too short, `BRAID_WAY_OF_LENGTH`, and caps its length at
  the gap between a rope's pegs). Wiggles without `i0` (none today) keep the
  old projection. The crossing search and the rewards read the spaced braids
  (`_laid`, `_braid_laid`).
- **Cost**: carrying on Insane, same harness back to back, 13.9 ms against
  12.1 before (both windows include the PNG saves): the braids now re-lay
  and wrapped ropes stay awake during the carry. Draw calls unchanged (156
  peak). Phone reading still owed.

**The knot rule (2026-09-29, evening)**: every pair of ropes keeps how many
times it crosses and which lies on top; a peg carried over the top lifts its
rope off where it lay on top and wraps it tighter where it lay under. Spec:
`docs/superpowers/specs/2026-09-29-untangle-knots-design.md` -- read it
first; the ring spec below it still holds for everything it does not change.

- **The rule** is `Gen.apply(at, tw, ropes, peg, hole)` on int arrays
  (`tw[pair] = n * 2 + t`). A move made back undoes it exactly -- the dealer,
  the kitten's backwards deal and undo all lean on that; keep it true
  (`tests/test_untangle.gd` walks it). `Gen.crosses` is now "a peg carried
  from a to b passes over the rope c-d" as well as the chord test.
- **Drawn tangle vs state.** `_tw_px` is the tangle as drawn: it takes the
  player's change when the peg lands (`res.tw_mid`) and the kitten's when she
  swats, so braids cinch on the landing. Anything that changes `state.tw`
  outside a move (undo, reset, answer, restore) calls `_set_shown`.
- **Braids** are laid out from peg positions only (`_braid`), bound into the
  chains by `_bind_all` only when a peg or a braid moved (`_bound_for`), and
  twisted on the drawn line (`Rope.wiggles`), not in the chain.
- **Over and under** come from `_find_crossings` (drawn lines) and
  `_build_patches`; the patch reach is per crossing (index 5 of a `_cross`
  entry).
- **Costs to watch**: crossing search, patches, and a rope mesh per moving
  rope. A new per-frame pass over every rope's drawn line shows up at once.

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

### Performance checkup and the tutorial (2026-10-01)

- **Measured first** (`tests/_probe_perf.gd untangle d=3`, ANGLE, 810x1440,
  second of two runs; the probe now carries pegs along the way home): Insane
  idled at **130 draw calls, ~10.8 ms**, and carrying a peg ran **~16.7 ms**,
  6.3 ms of it the board's `_rebuild` (crossing search 2.2, rope meshes 1.9,
  knots and targets 0.9, patches 0.5). Idle script cost was ~0.1 ms: idle
  was draw calls.
- **Pegs at rest are one mesh** (`_rest_mesh`, `_bake_rest`): every peg
  sitting still in its hole (no lift, flight, squash, shake or pop) has its
  shadow and cap baked together, made again only when the set of still pegs
  or a face changes (`_rest_for`); moving pegs still draw on their own over
  it. Eighteen pegs were 36 draw calls on Insane.
- **Rope meshes 2.7x cheaper** (`Rope._ribbon`, `_strands`): the vertices
  go into local arrays sized once and are appended whole, the triangle
  index runs are kept per (points, stops, base) (`_grid`, `_quads`).
  Output is byte-identical to the old writer.
- **Crossings kept per pair** (`_cross_kept`): a pair is searched again only
  when either rope's line changed (`Rope.ver`, bumped wherever the drawn line
  is invalidated), or its pegs, tangle or braid did. That only paid once
  `_bind_all` stopped clearing every rope's binds on every frame a peg moved:
  `Rope.set_binds()` takes a rope's binds, twists and route at once and
  leaves the rope (and its `ver`) alone when they come out the same.
- **After** (same probe): Insane idle **95 draws, ~8.4 ms**; carrying
  **~11.9 ms** (`_rebuild` ~3.7 ms); Hard idle 95 / ~7.8, play ~10.0; Easy
  idle 89 / ~6.7, play ~7.9. The rest of the 95 is the host (hiding the
  board leaves 75). Still open: the hint's beam search (`Gen.way_home`) is
  45-90 ms on this Mac on Insane and Hard, one hitch a hint press; and no
  phone reading.
- **Undo, Reset and Hint** were already on every band (Insane's hint is a
  video's), and the shared ? opens the tutorial.
- **The tutorial is three to five pages** (`tutorial_pages()`,
  `ui/hud/untangle_tutorial_diagram.gd`): an eight-hole ring drawn with the
  board's own wood, holes, capped pegs and `Rope` meshes (they swing, wrap
  and lie over and under as on the board; the braid is laid by a copy of
  `_braid`/`_bind_all` for one pair). Lift a peg over the rope it lies on
  top of and the crossing slides off (LIFT); the same carry with the rope
  underneath wraps it round once more, then Undo (WRAP); a short rope's
  reach -- glowing holes, a pull too far goes tight and back (REACH); then
  the hint where the band has one (HINT), the thread on Hard and Insane
  (THREAD), Insane's kitten (CAT). Reduce motion shows each lesson's end.
- **The kitten's tip was wrong**: `UT_TIP_CAT` said she bats the peg "into
  the hole you just left"; `Gen.cat_hole` puts it in the nearest empty hole
  its rope spans (clockwise first). The tip and the tutorial say so now.
