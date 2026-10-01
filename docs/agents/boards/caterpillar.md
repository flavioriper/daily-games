# Caterpillar

Moved verbatim from CLAUDE.md's "The flat screens" on 2026-09-29.

- **Caterpillar is the twenty-first card** (2026-09-25,
  `puzzles/caterpillar2d.gd`, spec `2026-09-25-caterpillar-flat-design.md`,
  mock `docs/brainstorm/concepts.html#caterpillar`). Drag one walk from leaf
  1 through every square, eating the numbered leaves in order, never across a
  fence; the walk is drawn as the caterpillar (`ui/faces/caterpillar.gd`) and
  the solve turns it into a butterfly. LinkedIn ships the genre under its own
  name; **it is called Caterpillar and nothing else**. Two things travel:
  **a proof capped by a node count is never a proof** -- the first generator
  read a capped search that had found one walk as unique and 14 of 60 hard
  and insane boards had two (`tests/_probe_cat_gen.gd` re-proves uncapped) --
  and **a board whose idle breath rebuilds its whole mesh pays for it every
  frame**: 12.2 ms idle until only the head's small mesh breathed (3.3 ms,
  Pinwheel 2.44 as the control). 58 draw calls on Hard, ANGLE included.
  **Polished on 2026-09-26** (the spec's amendment): a lawn and a
  wooden-framed bed of grass tiles, real leaves under the body with a bite a
  chew, legs that step in a wave while it is dragged, three smooth chews on a
  leaf scrap and a gulp down the body, a head that runs back over a cut rather
  than jumping, and a butterfly that loops away. 58 half-walked, 57 under
  reduce motion, ANGLE agreeing.
  **The tip card is gone from every board** since `1a04e0a` (2026-09-21): the
  bottom-slot figures and tip-card rules elsewhere in this file predate that.
  **Polished again on 2026-10-01** (`2026-10-01-caterpillar-polish-design.md`):
  players said the line lagged, more the longer it grew, and it did -- every
  frame of a drag rebuilt every leaf, fence and segment (7.7 ms at one
  segment, 28.9 at sixty-two on this Mac, `tests/_probe_cat_perf.gd`), a flick
  dropped the squares between two touch events, and the head jumped back to
  restart its slide. Now: **the settled tail is baked and appended to, the
  last sixteen segments are copied from baked triangle lists through a
  transform (`Soup`, `_part`), leaves and fences are cached by their look**
  (2.3 ms at sixty-two, flat), the drag is walked a fifth of a square at a
  time, and the head trails by a melting lag along the walked squares. Two
  things travel: **a board whose cost grows with what the player has drawn
  must keep the settled part baked**, and **a corner the finger cut is an
  ambiguous gesture and never costs a heart**. Hard (3 hearts, 1 hint) prices
  a step that strands a square; Insane is **Peckish** (unnumbered middle
  leaves, a tummy of five bare squares, 2 hearts, no hints, no Undo, any step
  off the one walk priced; 200 gardens mined by
  `tools/insane/caterpillar_ladder.gd`). Streak, row sparkles, burp bubble,
  love hearts, ladybug, the party's flutter, the nap cat and the seal; the
  CLOVER sound set (unheard). Peak 113 draw calls (ANGLE, the party).
  Harness: `tests/_shot_caterpillar.gd`.
