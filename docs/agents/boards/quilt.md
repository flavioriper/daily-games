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

- **A press does not lift until the finger moves** (or `GROW_WAIT`, 0.12 s):
  a press let go within `TAP_PX` 14 and `TAP_TIME` 0.3 s is a tap, which
  wiggles the patch where it lies and says `QL_TAP` (a sewn patch on Easy and
  Medium goes straight back with its seams whole and says `QL_TIP_OFF`).
  `_hold_state()` answers CLEAR until then, so a tap never flashes a ghost.
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

