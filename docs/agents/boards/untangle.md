# Untangle

**Tight knots, and free ropes leave (2026-10-05)**, after the user: a
reference of taut ropes meeting in compact knots that "keep persistent no
matter how you change it", against a shot of ours torn into arrowheads and
scribbles; and "the rope retreat and disappear after knot is untangled".
Everything below this section about coils, braids, cores, winders, binds and
the Verlet chain is history: none of it is in the code any more.

- **The rope is a line worked out, not a chain stepped.** `Rope.lay(a, b,
  stops, wd)` builds it from its pegs and the knots it runs through: straight
  to each knot, through it, straight on. Nothing is ever "on its way", which
  is what used to be drawn torn. `Rope.step(dt)` only advances what is laid
  on top: a swing on the straight stretches (two damped springs, `kick`) and
  a 0.22 s glide from the old line when the *knots* change (`MORPH`; pegs and
  knots moving are followed at once).
- **A knot is one short twist** (`Rope.lay_knot`): both ropes swing across its
  axis, `KNOT_PITCH` 1.4 widths a crossing, `KNOT_SIDE` 0.52 either side, with
  a lead of 0.3 pitch at each end so a rope comes in already heading across
  (a hooked rope dips in and out in a V). Of the four ways it can lie (which
  of B's legs at which end, which side A comes in on) it takes the one its
  four legs turn least to leave by, sticky against the last frame. At most
  `KNOT_MOST` (6) crossings are drawn; deeper shows `×n` beside it.
- **Leaving a knot** is an arc of `FILLET` 0.8 widths tangent to the knot's
  heading and to the straight that follows (`_fillet`; two knots in a row
  settle their common tangent in three rounds). With no room it is tried at
  0.55 and 0.3 of that, and last of all one cubic curve from heading to
  heading. Never a corner: a corner is what draws as a spike.
- **The ribbon cannot fold.** `Rope._ribbon` stops the band's inner side at
  the point the line turns about wherever it turns tighter than the band is
  wide. This is the guard under everything else; keep it.
- **Where a knot lies** (`_lay_all`, board): `knot_centre` is the point with
  the shortest way to the pair's four pegs (the ropes' crossing; side by
  side, the diagonals' crossing; a peg in the hand just over the other rope,
  at that peg -- which is why a knot forms under the hand without a jump);
  then clear of its own pegs, pulled toward a rope too short to reach it
  (`KNOT_WAY`), apart from other knots (`KNOT_GAP`, more when they share a
  rope), and last of all inside the ring. The ring wins: a short rope is
  drawn a little long rather than a knot on the wood.
- **Crossings in a knot are read, not searched**: `Rope.marks[pair]` are the
  line indices where the weave crosses the axis, alternating from the
  tangle's top bit; a lone crossing still uses `Rope.hits`. The over-piece
  reaches only `PATCH_OVER` 0.16 past the rope under it: a longer piece shows
  its cut end where a third rope lies by.
- **The rule: a rope that crosses nothing leaves** (`Gen.retire`). Its pegs
  read -1 in `at`, its holes are free, nothing is carried over it again, and
  the day is won when the ring is empty. `State.move` returns `gone`, the
  kitten's entry carries her own `gone`, `undo` returns `back`, `reset` walks
  them home. A rope the walk left free at the deal is never dealt
  (`State.ropes_dealt()`), and the dealer passes such walks over while it
  has walks to spare.
- **Why the dealt answer still holds**: a pair's crossings depend on those
  two ropes' moves alone, so the walk backwards less the moves of ropes
  already gone clears the rest (`Gen._replay`). Not with the kitten -- a rope
  leaving changes which hole she bats a peg into -- so an Insane deal stands
  only on a replay that still wins. Her schedule's peg, when its rope has
  left, is the next peg round still there (`Gen.cat_peg`, one definition for
  the state, the search and the replay).
- **The dealer** makes up to `WALKS` 70 cheap walks and searches at most
  `TRIES` 14: a walk with a free rope, a failed replay or an answer already
  shorter than the band's par is passed over before the search, and the
  search only looks as deep as would beat the walk. `way_home` keeps a score
  per tangle and sorts ints. Measured (this Mac, 60 seeds a band, mean /
  worst): Easy 1.7 / 2.5 ms, Medium 11 / 24, Hard 31 / 52, **Insane 161 /
  611** (was 71 / 155: more free holes mean more moves a layout, and four
  walks in ten have a shorter answer and are searched for nothing). Par is
  the band's on every one of them, and no deal of 240 had a free rope.
- **On screen** (`_send_off`, `_update_leaving`): the rope's pegs grin and it
  shines (`LEAVE_WAIT` 0.24 s), one peg is reeled across to the other
  (`LEAVE_REEL` 0.3 s, the rope shortening between them, the `free` cue), and
  both pop away with a ring, a sparkle and a tick (`LEAVE_POP` 0.16 s). The
  peg just dropped is the one that stays put. The board holds input until the
  last has gone. `_away[r]` is the rope off the ring *as drawn*; `_peg_home`
  of a peg with no hole is where it is drawn.
- **The win is an empty ring**: no pegs are left to grin or wear hats (that
  code is gone), so it is the stickers, the confetti and the seal; a restored
  day is the empty ring under its seal; Show the answer sends every rope off.
  The tutorial's LIFT and HINT pages end with the ropes leaving
  (`HTP_UT_GONE_CAP`), and THREAD's and CAT's moves now cross nothing so no
  rope leaves in the middle of what they show.
- **Measured** (ANGLE, 810x1440, Insane, second of two): idle 95 draws,
  ~9.2 ms; carrying ~10.4 ms, 108 draws at the peak (was 95 / ~8.4 and
  ~11.9). `hint_step` is still 50-90 ms a press.
- **Harness**: `tests/_shot_untangle.gd` has a `back` mode (the answer but
  for its last move, then Undo and Reset: the ropes that left come back) and
  now sets the board's `mouse_filter` to ignore -- the real pointer hovering
  over the always-on-top window was carrying the held peg off mid-run.
  `day=N` opens a finished day and always has; it shows nothing of a deal.
- **Not done**: no phone; nothing heard (the `free` cue is the old one,
  played at the reel); a rope hooked on three others in a small space still
  curls between its knots (clean, but busy); two ropes that do not cross but
  are pulled over each other by their knots are drawn in stack order, which
  looks like a crossing that is not one.

**Coils, not twists (2026-10-03)**, after the user: "untangle cords knots are
extremely weird still" (a rope with both pegs on one side made a hairpin loop
through the twist; squeezed twists read as curls; nothing showed which rope
lay on top).

- **A braid is a coil.** The rope whose pegs are further apart is the *core*
  and runs straight through; the other, the *winder*, swings a full rope
  width across it and back (`BRAID_SIDE` 1.0, `BRAID_PITCH` 2.1). `lay_braid`
  and `core_is_a` are static on the board and the tutorial diagram calls
  them, so the two cannot drift again. The core is sticky (`BRAID_CORE_KEEP`)
  so a carry does not flip a coil. Side by side, the two still meet where the
  diagonals of the four pegs cross, and the reach rule still pulls a braid
  toward a rope too short to get there: then the core bends too.
- **Phase.** The swing runs from `BRAID_LEAD` before the first crossing to
  the same after the last (`p0`/`p1` in the braid and the wiggle), so the
  winder comes in already heading across and no crossing sits at an end.
  `braid_point` takes the rope's travel (`dir`, `u`), not the axis's: the
  winder enters on the side it arrives from (`item[2]` goes -1 when it comes
  from another braid on the far side) and goes through whichever way is
  shorter.
- **Never squeezed into a scribble.** A core without room shows fewer turns
  (two at a time, `BRAID_PITCH_MIN`), and `_draw_turns` writes the real count
  beside the coil (`br.of` against `br.n`). Only two short ropes hooked
  together are squeezed further (the coil must end between the core's pegs).
- **Spacing** (`_space_braids`): each coil slides along its core to the free
  stretch nearest where it would lie -- free of the core's other coils, of
  the winder's other coils lying by, and of third ropes crossing the core.
  A rope's braids are visited in the order that makes its way shortest
  (`_shortest_round`), not the order along its own line.
- **Over and under**: `Rope.shade` lays a soft dark either side of the rope
  on top at every crossing, in the patch mesh (no draw call); it thins where
  crossings crowd and past 24 of them. A patch piece reaches only as far as
  the rope under it is wide (`_across`).
- **Cost**: `Rope.hits` now tests the boxes of the drawn pieces (`_box`,
  built with the line) instead of chain boxes grown by a margin, and only a
  rope that really leaves its line (`_bent`) is searched wide. Carry on
  Insane, same harness back to back: 11.2 ms against 12.2 before; draw calls
  unchanged (95 at rest, 103 carrying). Phone reading still owed.
- **Left as it is**: `carry` still reports one drawn turn over 100 degrees on
  Hard and Insane when a peg is carried over five ropes at once (a slack rope
  hooked on three ropes across the ring turns sharply between them); the
  tutorial's braid pages were not looked at after the change (the `howto`
  mode shoots page one only).

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
