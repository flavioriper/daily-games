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
