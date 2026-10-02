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

## The board checkup (2026-10-02)

- **Made in a reference layout's space.** The bed (`_build_bed`), the leaf,
  fence and badge looks, the body and the head are built while `_in_ref`
  makes `_cell()`/`_origin()` answer the reference layout, and drawn under
  `_relay()`; only the lawn (`_build_lawn`, the whole card) is made again
  when the card changes size. The win card's relayout made all of it again:
  70-97 ms. While the relay is the identity the lawn and the bed are drawn as
  one mesh (`_join`), a draw call fewer. A new garden (`build`, the
  tutorial's `lay`) clears `_ref_cell` so every look is made again.
- **Looks, not rebuilds.** Leaves, fences, badges and every segment part are
  `RunMesh` shapes keyed by look (`_look`, `_cache`, `_look_makers`); the
  resting leaves, fences and given washes go into `_rm`'s runs (one per
  piece, laid by `_lay_rooms`), the badges into `_rm_over`'s, each a rest
  mesh handed back while its signature stands, and whatever moves into
  `_rm_live`; the stretch near the head goes into `_rm_lo`/`_rm_hi` runs per
  segment slot from the seam (`BODY_SLOTS`). The head is `_head_look`: a
  mesh per turn (72), eyes (eighths), sway (fiftieths of a radian) and scrap
  (eighths), under `_top_xf`. The tail is still baked by `Cat.body` every
  eight squares (~2.5 ms then).
- **Small caches.** The hearts-and-tummy pill by what it shows
  (`_hearts_cache`), the party's flutter in sixteen wing beats
  (`_flutter_look`, made at its drawn size: a Builder's feather is absolute
  pixels), and the streak's digits drawn out of sight on the first frame
  (`_warm_combo`).
- **Tutorial**: `tutorial_pages()` and `ui/hud/caterpillar_tutorial_diagram.gd`
  (a `Garden` subclass with no sounds, tips, gags, party or card; `_inset()`
  keeps just the frame's width of lawn on the short page).

## One smooth body (2026-10-02)

- **The beads are gone.** The body was a round segment on every square over a
  thin tube, mitred at every turn; the user found it "too square ... like an
  old browser canvas game". It is now one tube (`Cat.body`, `_spine`,
  `_ribbon`): each segment owns the stretch from the middle of the step
  before it to the middle of the step after, a quadratic through its square's
  centre, so a turn is a round bend; its width eases between neighbours down
  to a pointed tail (`TAIL`, `TIP`). Over a base shaded away from the light: the
  lit body, a lit band leaning toward the top left (`LIGHT`), a crease bowed
  toward the tail between segments, two spots and a short shine per segment
  (`crease`, `decal`). Legs, spots and shadow sit on `Cat.seat` (inside a
  bend, not on the corner). A cut segment pops out as a short piece of tube.
- **Two stretches built apart must meet on one edge**: the tail and the live
  stretch end flat in the middle of a step, and the strip's normals come from
  the curve's own slope, not from neighbouring samples. One-sided normals
  left a light hairline across the body at every bake seam.
- **Cost**: the tube near the head is built whole every frame (it is one
  shape); its creases, spots and shines are RunMesh looks (`_rm_hi`, a look
  per 72nd of a turn for the marks, which lean to the light). Probe
  (`tests/_probe_cat_perf.gd`, Insane): 0.7-1.4 ms before, 0.85-1.7 ms after
  (built with the builder they were 2.3-2.8). Draw calls unchanged (108 peak
  on the Insane solve, ANGLE).
