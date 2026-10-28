# Quilt

Moved verbatim from CLAUDE.md's "The flat screens" on 2026-09-29.

- **Quilt is the sixteenth board, and the first to put its pieces inside the
  board card** (2026-09-20, `puzzles/quilt2d.gd`, spec
  `2026-09-20-quilt-flat-design.md`, mock
  `docs/brainstorm/concepts.html#quilt`). A shaped backing of pale cloth and
  a rack of coloured patches under it; drag each patch on, wholly onto the
  backing and never over another, and the quilt is done when the last one
  goes on. The genre ships elsewhere as "Blocos" and as "Block Fit";
  **it is called Quilt and nothing else**, which is the fifth rename after
  Code Break, Hidden Word, Word Trail and Bridges. **Patches never turn** --
  one decision a drag, where, and not two.
  **Nothing wrong can be sitting on this quilt**: the patches' cells sum to
  the backing's and an illegal drop is never taken, so the last patch sewn
  on *is* the solve and there is no Check. That makes it Word Trail's shape
  -- no tray, no actions row, Reset up in the top bar, the tip card alone at
  140 -- reached by a third route, and it is why **the rack is not a tray**:
  a drag from a tray row to the board crosses a node boundary, and the whole
  gesture has to live in one coordinate space, so the card takes all 1340
  and holds both. **Its signature is the stitch**: a patch that lands sews a
  running stitch along every seam it now shares, dash by dash, in a wave out
  of the patch that landed. The seams are **derived and never stored** --
  each takes the *later* of its two patches' landings, because a seam
  belongs to a pair -- and the board's `_settle` is the plainest form of
  Queens' and Sudoku's: it diffs where every patch *is*, before against
  after, so a hint that displaces two patches and the undo that puts them
  back both animate correctly without either knowing which patches those
  were.
  **Three proposals died on the first rendered frame and one on a
  measurement**, all recorded in the spec's section 15 because the reasons
  travel: Queens' `REGION` pastels are a *ground* and two of the nine read
  as holes in the card, so `Pal.CLOTH` was added (a patch is the thing the
  player moves and has to be the strongest surface on the screen, not the
  palest); `SURFACE_HI` is four points of value off `PARCHMENT`, so the
  backing is Shikaku's `BED_GROUND`, the one palette entry already chosen to
  read as bare ground *on parchment*; a rack of equal bays measured **46.7 a
  cell on every band** because any single four-tall patch sizes them all, so
  it is two content-packed shelves with the tall patches grouped; and the
  empty bays are drawn, because without them the rack empties as the quilt
  fills and the last patch is dragged across four hundred pixels of nothing.
  **And a fifth, which is the one that travels: a patch cannot blush.** Every
  other board flashes a refused piece toward `Pal.BAD`; `Pal.CLOTH` runs
  right round the wheel, so at 0.30 the teal goes from 0.34 saturation to
  **0.07** (dead grey), the sage swings hue 91 to 49 (khaki) and the sky 212
  to 265 (mauve) -- only the four warm cloths blush at all, and a greyed
  patch reads as *disabled* rather than as refused. So the refusal is a rose
  **halo stroked round the silhouette** with the shiver, and the cloth is
  left alone: `docs/art/flat-motion.md`'s rule 9 read for a piece that is
  its own shape. **Any board whose pieces are coloured by index should
  expect this.** Two bugs on the drag were also found in review and are
  locked by `tests/test_quilt_board.gd`: an origin packed as
  `row * cols + column` wrapped a hold one cell off the left edge onto the
  far right (2,386 of those came back legal across 120 boards), and a second
  press stranded the held patch with no undo entry, because `take()` pushes
  no history and the matching `drop()` never ran.
  Measured with `tests/_shot_anim.gd -- quilt` at `--resolution 810x1440`:
  **58** bare, 58-59 played over six readings, **80 on the fullest board** and 58 under reduce
  motion, against the 855 budget, with Queens (71, 71) and Word Trail (65)
  reproducing their recorded counts as controls in the same session. Idle
  2.09-3.90 ms across every state, against a Queens control at 3.45/3.49 in
  that session and 3.83 in its own spec, so the milliseconds are comparable
  only within the session. ANGLE agrees on 80 and matches the board card to
  1/255; the reduce-motion pair 1.5 s apart is pixel-identical. Generation
  worst case **51.8 ms** against the 194 ms gate, and the one thing to know
  about it is that **uniqueness is not what the attempts are spent on** --
  only 2.5 to 4.7 percent of grown boards have a second tiling, because a
  region tiled by pieces that never rotate is almost always rigid; what
  costs attempts is grows that wedge (77 to 92 percent of them).

## The polish, board side (2026-09-30, spec `2026-09-30-quilt-polish-design.md` sections 1-3)

- **A press does not lift until the finger moves past `TAP_PX`** (14), and
  time alone never makes it a drag: a press let go without moving that far is
  a tap, however long it was held, which wiggles the patch where it lies and
  says `QL_TAP` (a sewn patch on Easy and Medium says `QL_TIP_OFF`; it was
  never taken, so its seams stay whole). `_hold_state()` answers CLEAR and
  `_in_hand()` -1 until then, so a tap never flashes a ghost.
- **Sticky snap lives in `_target()`**, not in `_held_origin()`:
  `tests/test_quilt_board.gd` holds `_held_origin()` to the raw rounded cell
  (the wrap regression), and the ghost and the release both read `_target()`.
  A ruled spot is still a geometric fit, so it comes back from `_target()`
  and the hold is `CROSSED`: the chalk X is drawn **on the held patch** in the
  hand's mesh, because the footprint under it is hidden by the patch itself
  (the first frame drew it on the footprint and it could not be seen).
- **The wrong patch is drawn in the hand's mesh** for its whole way home
  (`_peel_frame`, `_peel_stitch`), and its bay shows the chalk outline while
  it is out. The heart splits at `SNIP_AT`, not at the release.
- **The basket's weave is hundreds of strands**, and rebuilding it with the
  rack on every frame of a flight cost 36 ms a frame on this Mac; the mat is
  its own cached mesh now (`_mat_mesh`, one more draw call), mean back to
  4.4 ms. The first basket, rounded bricks in a tan wicker, read as a wall
  and swallowed the yellow cloths; it is pale straw with faint stakes and
  weavers, a woven band at the foot and a twisted rim.
- **Scrap Basket takes three shelves**: `_shelves()` tries two and three for
  nine patches or more and keeps the bigger cell -- 38.7 on two, **48.6** on
  three, against a field cell of 117.6. Easy 72.5 (field 150), Medium 62.5
  (147.9), Hard 62.5 (117.6, hearts' strip taken). Card 1000 x 1480.
- **The label** (`_tag_rect`) hangs off the right end of the backing's top
  row -- in the bounding box's empty corner or the side margin -- so it never
  covers a backing cell; mirrored left when the right has no room.
- `tests/_shot_quilt.gd` modes `rest tap stuck wrong out restore` (`rm` for
  reduce motion). Draw-call peaks at 810x1440: rest 95 (the ghost finger),
  tap 83, stuck 83, wrong 84 (Hard) / 80 (Insane), out 106 (with the card),
  restore 79-84, reduce motion 82-85; ANGLE 81 on Insane's wrong.

## The rewards (2026-09-30, spec sections 4 and 5)

- **The streak** counts good drops (Hard/Insane: a right patch; Easy/Medium:
  a drop that leaves the quilt finishable) in `_on_good_drop`, which skips
  the solving drop. `combo` from the second, pitched up `COMBO_STEPS`; the
  "x3" bubble over the patch's top from the third (drawn on the life layer,
  not a layer of its own); confetti at 4 and 7. `_break_streak` deflates it.
- **Gags** by `_gag_roll(p)`: the day's quilt hashes a start and each patch
  steps two along five rolls, so three gags share any five patches evenly.
  **A plain per-patch hash clumped**: one Scrap Basket drew seven buttons out
  of nine and the quilt read as a button quilt. Love hearts (life layer), a
  **button** (`_buttons`, drawn inside `_patch`, so it rides a held or
  flying patch and is baked into whichever mesh carries it; erased when the
  patch's flight home retires), a **boing** (squash about the patch's foot,
  hop `BOING_HOP`). Under reduce motion only the button, standing.
- **Row glints**: `_rows_done` checks every row and column the patch
  touches; a star and a soft white glow per cell, `ROW_STEP` a cell of
  distance out from the patch. The first glow was `SUN_RAY` and read as a
  grey disc on the blue and teal cloths.
- **The party** (`_party`, `_party_lead()` after the solve): the dance
  (`_dance_colours` hands two beat halves out greedily so neighbours are
  half a beat apart), confetti twice, quilt wisdom by the quilt's hash, the
  seal on the rack's lower right (Flawless; on Insane "Insane" over Flawless
  or Scraps). **The nap cat** is Light Up's `ui/faces/nap_cat.gd` with its
  tag showing "z": a node (`_cat`, z 3) placed each frame by `_place_cat`,
  popping up at the rack's right end, three hops onto the 2x2 of backing
  nearest the quilt's middle that has **no button under her** (the first
  frame hid one behind her ears), a settle squash, then SLEEPY and `purr`.
  **Scrap Basket's bunting**: twine across the top of the card at `BUNT_Y`
  2, the scraps flying out of the basket in x order and pegged at
  0.17 / 0.33 / 0.81 so none hangs over the hearts' pill, swinging down to
  rest over `BUNT_SWING`; their bays show the chalk shape. `win_delay()` is
  `WIN_WAIT + PARTY_AT + PARTY_EXTRA` (3.9 s) and the win card shows the
  cat, the seal and the bunting in its thumbnail.
- **Restore** puts the cat there asleep (quietly), the seal when the record
  is flawless or Insane, the bunting still; no dance, no confetti.
- `share_glyphs()` puts the seal on its own line under the square grid
  (the grid ends in a newline): `🏅 Flawless` or `🧺 Scraps[ · Flawless]`.
- `tests/_shot_quilt.gd` adds `right` (all but the last answer patch: the
  streak, the gags, the glints) and `solve`. Peaks: right 90 Easy / 93 Hard,
  solve 93 Easy / 91 Insane (92 on ANGLE), restore 88-90, reduce motion
  86-88, out 105. No idle life was added beyond the curled cat's "z".


## Review findings, fixed (2026-09-30)

- **One finger holds the patch** (Hedgehogs' rule): `_drag.finger` is the
  touch index (-1 mouse); another finger's press, drag and release are
  ignored. Before, a second finger's release judged the first finger's patch
  and cost a heart on Hard/Insane. A cancelled touch goes through
  `_cancel_drag()` -- the patch back where it was taken from, unjudged, no
  history -- and Undo, Hint and Reset call it first, so none strands a
  patch that `take()` had lifted.
- **Tap vs drag is distance only** (see above). The old pair (lift at 0.12 s,
  tap judged at 0.3 s) let the outline promise a spot the release would not
  use, and a still hold nudged a sewn patch a row up. `take()` now waits for
  the drag (`_begin_lift`).
- **SNAG off the left/top edge**: `_hold_state()` counts cells over the quilt
  from the unclamped `_held_cells()`, not from `_held_origin()` (-1 whenever
  the patch's (0, 0) is off the edge), so an L hanging off the left with
  cells over the quilt halos and is refused instead of taken off quietly
  (114 such holds probed across the four bands, all SNAG).
- **Scrap Basket colours**: `State.cloth_of` (spec section 3); every
  `Cloth.*` call on the board and the share's squares go through it. Probed
  on all 150 banked boards: no touching quilt pair, no look-alike pair, no
  scrap with a cloth of its own, no cloth past two. Bands of eight patches
  or fewer keep `cloth_of[p] == p`.
- **`from_bank`** type-checks every value before `int()`/`String()` and
  refuses a scrap with a quilt patch's shape; malformed entries return {}
  without a script error.
- **Undo and reset** clear `_rows`, `_love`, `_boing` (`_clear_gags`), and
  undo bumps `_gen` so a gag's or the streak's pending sound does not play
  (only boards that cannot undo have `_after`s that must still run).
- **The ghost finger is one mesh** (it was ~7 draw calls and a fresh
  `Cloth.loops()` a frame) off the cached `_loops[p]`, and the life layer
  stops redrawing while its alpha is 0; the streak's bubble is built once a
  count and moved by its transform. Peaks at 810x1440: rest (Easy) **84**,
  was 95; solve (Insane) 92.


## The checkup (2026-10-02, `docs/agents/checkup.md` row 16)

- **The lag was the drag.** `_gui_input` calls `_refresh()` on every motion
  and `_animating()` is true while `_drag` is live, so the quilt (4.4-6 ms)
  and the rack (2.6-3 ms) were rebuilt every frame a finger was down: a full
  Scrap Basket with a patch held was 11.7 ms a frame.
- **Three kinds of patch** (`_build_quilt`, `_build_rack`): at rest -- a
  look (`_look`, ids `LOOK_*`) put where it lies into `_still_quilt` /
  `_still_rack`, rebuilt only when the plan (`_still_*_plan`: look, x, y)
  changes; moving as a whole -- the look under `_look_xf` (the squash and
  turn about the patch's middle that `Cloth.place` does); changing -- drawn
  by the old `_patch` path. `_sewn_look_id` says which: -1 while its stitch
  runs, it blushes, its button pops on, it has a shadow, a fade or a cell
  between the rack's and the quilt's. A seam is still only when both its
  patches are (`"other"` on each seam now) and it is fully sewn.
- **The ghost has its own mesh** (`_under`), drawn under the still patches as
  it always was under every patch: one more draw call while a drag is live.
- **Looks are per layout**: `_forget_looks()` on `_layout()` and on a new
  board (`_shape_cache()`), so the win card's relayout redraws them once.
- **The tutorial** (`ui/hud/quilt_tutorial_diagram.gd`, `Patchwork`): a
  4x3 quilt, A A B B / A C C B / D D C B, plus a three-tall scrap on Insane,
  dealt by `lay()`; the page's card puts the quilt left and the rack right
  (`_field_box`/`_rack_box` overridden), the label in the quilt's share.
  The finger lets go HOLD_LIFT cells under the spot, as the board holds a
  patch above the thumb.
- **`-INF` sentinel**: not needed here -- the restore leaves `_solved_at` at
  -1 and its stamps (`t - 10`, `t - 100`) are only ever subtracted.

## Insane counts moves (2026-10-04, `docs/agents/flat-screens.md`)

- **Scrap Basket hands out moves, not hearts.** `State.HEARTS` is all zero,
  so `judged()` is false on every band and WRONG, RULED and STAYS, the chalk
  and the peel lie dormant. Insane now takes any patch that fits, a scrap
  included, and lets it be dragged off again, as Medium does. The budget is
  `quilt_patches + 3` (`State.moves_budget`; 12 on every banked board: nine
  and three): a patch sewn on, taken off or slid to another spot is one
  (`move_cost`), one put back where it was lifted from is free. No Undo, no
  Hint; Reset and Try again hand the budget back. What went with the
  judging, on Insane only (`max_moves > 0`): **the dead end** (`QL_STUCK`
  and its pulse were the board saying a patch is wrong), **the streak**
  (nobody knows a drop was good; the gags and the row glints stay), and
  **the ghost finger** (it dragged a patch to its answer place; it had never
  shown on Insane, which was judged, and would have begun to). Surprising:
  a sewn patch let go over the quilt where it will not fit used to fly home
  to the rack; on Insane it goes back down where it was sewn, since a
  refused drop must cost nothing and a patch in the rack would be a move.
  And nine patches can now sit on the quilt with a gap showing, so
  `_left_line` says `QL_WIN` only when the quilt is solved. The pill is in
  the hearts' strip; `completion_record` keeps `moves`. `QL_LVL_2` still
  reads "three hearts" (Hard's, stale since ce192ab).

### The sewing table is the whole screen (2026-10-13)

The redesign (`docs/agents/flat-screens.md`, "Every board gets a world of
its own"), built unattended. `puzzles/quilt_world.gd` is a pale birch table seen
from above with faint seams and grain, the window's panes of light behind
the wordmark, three spools and a thimble in the gap of the tools row, and
along the foot a tape measure, loose buttons, the card's needle with its
thread run to a spool, and a pincushion; five dust motes breathe. The
rack's felt mat is on the host's margin; the quilt's height binds, so it
stands centred about 106 inside each side at 1080.

- Registry: `bleed`, `level_card`; no tray, no actions row, as before.
- `opengl3_angle`, 810x1440: 81 draw calls at rest; `tests/_win.gd --
  quilt` passes with real drags.
- Decided for the user, unconfirmed: birch, not the card's heather linen
  (two boards already have cloth); the rack 3% shorter; the empty mat
  travelling with the quilt on the win. Owed: a phone, the level slide.

### Bricks, not cloth (2026-10-17)

The user: "redesign quilt to have a design closer to a brick ... builder
pieces". A look change only: rules, motion, timings, looks, sounds, the
id, the title and every `QL_*` line are as they were.

- **`ui/faces/brick_piece.gd`** replaces `patch_cloth.gd` on the board, its
  world, its card and (by inheritance) its tutorial, and answers every name
  they called on the cloth; Pinwheel keeps the cloth. It is standalone,
  not a subclass: GDScript refuses a child redeclaring a parent's const,
  and the geometry (`loops`, `laid`, `round_loop`, the dash walker) is
  handed straight through to the cloth file.
- A brick: corner 0.07 (was 0.17), side `EDGE` 0.13 (was 0.075), a bevel of
  light along its upper edges, and a **stud on every cell** drawn in the
  print's slot (`print_cloth`). Eight toy colours (`BRICK`), by the same
  `cloth_of` index; `Pal.CLOTH` is untouched.
- **The thread became plastic**: a seam between two bricks is a solid dark
  groove (`STITCH_ON` 1000, `STITCH_OFF` ~0), the quilting stitch a pale
  bevel line run round once as the brick presses home (`QUILT_ON` 1000),
  and `needle()` draws nothing. **Hems are not drawn** (`_seams` skips an
  edge off the backing): on a brick the dark line sat on the cell boundary,
  half off the rounded corner, and read detached.
- The backing is a **plate** (`Brick.plate`): pale grey, a low stud a cell;
  rules, puffs and ties are gone. The rack's felt mat is a pale-blue
  **sorting tray** (`_tray`), Scrap Basket's wicker a sand **tub** with
  ribs and a lip. The button gag is a clear round tile tinted by its brick.
- The world (`quilt_world.gd`) keeps the birch and the window's light;
  three small bricks sit in the tools row's gap and seven loose bricks lie
  along the foot (`TOOLS`, `LOOSE`). The card's linen is a plate, the
  patches bricks, the needle a loose brick; studs stop short of the words.
- `opengl3_angle`, 810x1440, `_shot_quilt.gd`: rest 82/82 (81/81 before, same
  session), right 91, Insane solve 109 (was 92). `_win.gd -- quilt` passes;
  suite 248522/0.
- Decided for the user, unconfirmed: the name stays Quilt and the words
  still say patch, sew and blanket; the prints are gone, so two alike
  shapes now differ by colour alone (a colour-blind player loses the
  print's help); grey plate rather than green; hems dropped. Left as cloth
  and never reached for Quilt: `ui/hud/how_to_play_diagram.gd`'s quilt
  lesson (the board has `tutorial_pages()`) and `card_art.gd`'s
  `_draw_quilt` (the entry has a `"card"`). The sounds stand: `place` is
  already the bank's token. Owed: a phone, the tutorial page looked at
  (`quilt_tutorial_diagram.gd` parses).

## Made fun (2026-10-28)

The user: "make quilt experience way better to play, and game itself way
funnier to play, right now nobody likes it", autonomous, push when done.

- **Measured first** (`tests/_probe_ql_fun.gd`, headless, 60 days a band).
  The quilt was not too easy: a patch had 8.8 / 11.2 / 17.5 / 21.1 legal
  spots on the bare quilt (Easy to Insane) and none had only one. What was
  wrong is that it could not be *read*. Reading means what a careful player
  does: rule out a spot that leaves a pocket smaller than every patch left,
  then sew a patch with one spot left, or the one patch that can cover some
  bare square. That finished only 17, 18 and 4 of 60 Easy, Medium and Hard
  quilts, and **30, 22 and 39 of 60 had no first move at all**: the first
  patch on was a guess, and so was most of the rest. A player who drops
  anything anywhere it fits is stuck on 59-60 of 60.
- **Readable deals** (`Gen.readable`, `READ_SHARE` [1, 1, 0.1]): Easy and
  Medium are dealt only if the reading finishes them (60/60 now), and Hard
  only if it gives a first move (60/60 now; read to the end 9-16/60, so
  Hard keeps its middle). Node windows and uniqueness are tested as before;
  the loop runs `ATTEMPTS * READ_ATTEMPTS` and falls back to the first
  board that passed the rest. Deal on this Mac, 60 days: Easy 6.7 ms (worst
  21), Medium 11.8 (46), Hard 32 (121), against the 194 gate. Reading half
  of Hard cost 78 / 360 and was dropped. Insane's bank is untouched (not
  re-mined; 15/60 of its boards open with a forced move).
- **The gap under the hand** (`_gap_cells`, `State.gaps`, `Gen.pocket_cells`):
  on Easy, Medium and Hard, a held patch that fits washes rose (dashed rim)
  the bare squares its drop would shut in a pocket too small for any patch
  still waiting. Only pockets beside the patch are walked, each until it
  reaches the smallest size, cached by (patch, spot, history length). The
  drop is still taken; the old dead-end line and pulse follow it. Not on
  Insane (its scraps make "too small for what is left" untrue, and it says
  nothing it does not have to).
- **The bulb teaches the reading** (`State._read_next`): a hint sews the
  next forced move on the quilt with only its right patches counted, when
  that move is an answer place; otherwise the old pick (fewest spots).
- **Two tips** in the cycle (`TIPS`, not Insane's): `QL_TIP_CORNER` (start
  in a corner or a nook, a square only one patch can cover) and
  `QL_TIP_GAP` (the rose gap), en/pt/es.
- `tests/_shot_quilt.gd gap`: Medium peak 82 draw calls. Suite 303252/0.
- Decided for the user, unconfirmed: Hard asks only for a first move; the
  gap wash on Hard as well; the drop into a gap is not refused; the bank
  left alone. Not on a phone; no new sound (the wash is silent, as a ghost
  is).
