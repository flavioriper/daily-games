# Shikaku, flat: the fourth screen on trial

Status: built, 2026-09-18. Concept page:
`docs/brainstorm/concepts.html#shikaku`. Sibling specs:
`2026-09-18-binairo-flat-design.md`, `2026-09-18-codebreak-flat-design.md`,
`2026-09-18-balance-flat-design.md`.

Shikaku is a field cut into rectangles: each holds exactly one number, and
that number is how many squares it covers. Drag corner to corner and the
rectangle you enclose becomes a plot.

**This is the board the camera costs most.** Shikaku is counting — you count
cells against a number, and you read whether two plots share one boundary. At
the island's seven-degree pitch the grid is a trapezoid: a cell at the back of
the field is a fraction of the height of one at the front, so counting a
three-by-three at the top is not the same act as counting one at the bottom.
Flat, every cell is the same square and counting is free. Of the screens
tried, this is the one where the flat view buys the most *puzzle* rather than
the most polish.

## 1. What was built

| File | New? | Job |
|---|---|---|
| `puzzles/shikaku_state.gd` | new | The rules, scene-free: clues, plots, the owner map, the seams, every move. |
| `puzzles/shikaku2d.gd` | new | The flat board: the field, its meshes, the input and the sprout's lines. |
| `ui/faces/marker_face.gd` | new | The signpost marker: a plaque on a stake with a number and a face. |
| `ui/faces/face.gd` | edit | Two expressions, `STRAIN` and `PUZZLED`. |
| `ui/flat/flat_host.gd` | edit | `"tray": "none"`, and the bottom slot summed from the rows it built. |
| `core/palette.gd` | edit | The field's earth, the fence and a wrong marker's edge. |
| `ui/registry.gd` | edit | `shikaku` goes flat; `shikaku_island` keeps the island board. |
| `tests/_win.gd` | edit | The existing solver drives both boards. |

The generator is untouched. `puzzles/shikaku_gen.gd` — the recursive
partition, the minimum area of three, the most-constrained-first search
proving the answer is the only one — is the island's, and both boards call it
with the same ladder, so a day hands out the same field to each.

## 2. The state is the one truth

`shikaku_state.gd` is `shikaku3d.gd`'s logic ported move for move and stripped
of its scene: `commit`, `take`, `undo`, `reset`, `apply_hint`, `wrong_clues`,
`is_solved`, `clue_ok`, `plot_blushes`, `clue_state`, and the seam maths
(`is_seam`, `fence_runs`, `fence_posts`) the fence is built from.

Two things are worth keeping honest about it:

- **`is_solved` is checked against the rules, not the stored answer.** Every
  plot holds exactly one number, its area matches, no two overlap and together
  they cover the field. A player who finds a different tiling than the
  generator's would win — the generator proves there is none, which is a
  different claim from the board refusing one.
- **A fence stands on a seam exactly when the two sides belong to different
  plots and at least one is claimed.** That is Shikaku's rule as a line: two
  neighbouring plots are divided by one fence and never two, and off the field
  counts as unclaimed, so a plot reaching the boundary is closed by the edge
  with nothing written for the case.

The island script still carries its own copy until the two screens are
judged. Whichever board survives, this is the one to keep.

## 3. How the field is drawn

Nothing is a node per cell. Three kinds of cached `ArrayMesh`, built through
`Face.Builder`:

- **The ground**, one mesh: the bare field and its faint grid. Rebuilt on
  layout only.
- **A bed**, one mesh each: tilled earth inset from its cells, a dashed furrow
  along each of its rows, a green inner line when a hint pinned it, and its
  crop once the field is planted. Built **about the plot's own centre**, so the
  pop on commit is a transform on the draw and never a rebuild. Cached by the
  plot itself (`x_y_w_h_locked_blush_planted`), so a commit builds the one bed
  it drew and re-uses every other.
- **The fence**, one mesh: every run as one line over its own shade, and a
  post only where runs meet, turn or cross. Rebuilt whenever the partition
  changes.

A hard board of sixty-three cells is therefore about sixteen draw commands,
not hundreds. `Face.Builder` is the right tool twice over: it is what the
characters are already drawn with, and it feathers every shape — MSAA is off
for the whole 2D canvas, so an unfeathered `draw_rect` would be the one hard
edge on the screen.

Two details that are consequences rather than decoration:

- **Furrows have flat ends.** A hard board carries about three hundred dashes;
  a round cap on each is two more discs of geometry per dash, which would cost
  more triangles than the beds themselves.
- **Dashes are measured along the path's own arc length**, not per vertex, so
  the pending rectangle's dashed edge rides round its corners. Its outline
  points are three pixels apart, and a dash per segment would be a solid line.

The pending rectangle's mesh is cached by the rectangle and the colour it
earned, because a drag moves the finger far more often than it moves the
rectangle.

## 4. The markers

Each clue is a wooden plaque on a stake carrying its number and a face
(`ui/faces/marker_face.gd`), and it wears exactly the state the board already
computes for it — four, no more:

| State | What the board knows | The marker |
|---|---|---|
| Idle | Its cell is in no plot yet. | Cream plaque, `HAPPY`. |
| Settled | `clue_ok`: one number in the plot, areas match. | Green plaque (`LEAF` over `LEAF_DEEP`), `JOY`. |
| Wrong size | One number in the plot, areas differ. | Rose plaque (`BAD` over `MARKER_DEEP`), `STRAIN`. |
| Lost | `plot_blushes`: the plot holds two numbers or none. | `PUZZLED` — **and the bed itself blushes**. |

The last row is the one to keep honest. A plot holding two numbers is not any
one marker's fault, which is why the island puts that state on the floor
rather than on a stone; the flat board does the same and only lets the markers
inside look confused about it. No face says anything the beds and the numbers
are not already saying.

**`Face.Expr` gained `STRAIN` and `PUZZLED`** for this, drawn from the mock's
own `faceParts`: strain is `WORRIED`'s slanted brows over a flat mouth, and
puzzled is one raised brow — the right one only, because two read as surprise
— over a small wavering frown. The change is additive; no existing character
moves.

**The state is carried by `expression` alone.** The four states and the four
faces map one to one, so the plaque's fill, its rim and the ink its numeral is
written in all follow from it, and the base's cache key (kind, layer, R,
expression, eye) stays sufficient. Every marker of a state on the board shares
one mesh. The numeral is the exception: it is drawn over the mesh with one
`draw_string`, because a digit in the key would multiply every state by nine
to save a single command per marker.

## 5. The screen

The family's shape for a board that submits — Code Break's rows exactly, minus
the tray, because there is nothing to pick up.

| Row | Height | What is in it |
|---|---|---|
| Top bar | 180 | Back, `SHIKAKU` with its leaf and `EVERY PLOT HAS ITS NUMBER`, then Undo, Hint with its count, Settings. |
| Day card | 120 | |
| Board card | 1264 | The field, on parchment. Square cells: 186 on easy, 150 on medium, 133 on hard. |
| Actions | 130 | **Reset and Check, and the row is back.** |
| Tip card | 140 | The sprout and one line. |

**The actions row is the answer to the question Balance and Untangle left
open.** `capabilities()` here is undo, hint *and* check, so this screen has
something to put in one. The row is not a mistake: it belongs to boards that
submit, and a board that is its own continuous check does not get one.

**`"tray": "none"` is new.** The host had always built a tray; Shikaku arms no
brush, seats nobody and steps no weight. The host now takes the row as
optional the way it already took the actions row, and measures the bottom slot
by summing the rows it actually built with a gap between each — never a
constant, since the four screens no longer agree on either row.

Ladder, unchanged from the island: 5×6 with a max area of 6, 6×8 and 7×9 with
9. The cell is `min((1000 - 68)/w, (board_h - 68)/h)`.

## 6. The rectangle under your finger

The island lifts the cells inside the drag and tints them, and leaves the
counting to you. Flat can afford more: the pending rectangle carries its area
in a disc at its centre, **green when it matches the single number inside it,
rose when it does not, and plain ink when it holds no number or two.**

The disc is drawn by an overlay above the markers while the tint goes under
them: a marker standing in the middle of the drag would hide the one number
the drag is for, and the markers have to stay readable through the wash.

This is the sharpest thing on the screen to argue about, because counting
cells is part of what Shikaku *is*. It removes the counting and leaves the
reasoning. The cheapest experiment if it proves too generous is to show the
count and never colour it.

## 7. Input and motion

- **Press** starts a drag on any cell not inside a pinned plot. A pinned plot
  refuses *before* the drag starts — its marker dips and the sprout says why
  — rather than letting a drag run and turning it down on release.
- **Drag** clamps to the field rather than dropping off it: a drag that
  wanders off holds its far corner on the edge cell.
- **Release** commits. A 1×1 on an existing plot clears it; anything else
  replaces every plot it overlaps. The new bed pops in from nine tenths and
  its fences appear; earth puffs at its four corners.
- **Check** shakes every number the board does not yet satisfy and the sprout
  counts them. Nothing is solved for you.
- **Hint** draws the first solution plot the board does not have, pins it,
  pops its number and sparkles over it. It clears the history, because a hint
  may displace a pinned plot's neighbours and what came before no longer
  describes a board that can be gone back to.
- **Solved**: seedlings come up bed by bed from the top-left, a tenth of a
  second apart and staggered again inside each bed. During the wave each
  seedling is its own cached mesh at one of eight growth steps; once the field
  is up the crop is folded into the bed meshes and the per-seedling draws stop.

Every motion goes through `core/motion.gd`, so reduce-motion stills the
decoration and keeps the change of state. The drawn animations read
`Motion.reduce` directly and land at their end value.

## 8. The tip card and the win

`tip_line()` is the board's own: the three teaching lines cycle while the
field is bare, then the count of bare squares, the blushing beds before
either, and Check's tally after a press. The board pushes a new line by
emitting `focus_changed`, which is what the host refreshes on — nothing else
on this screen has a focus.

`flat_win()` returns an **empty cast** with "The whole field is planted."
`well_done.set_cast([], ...)` already draws that as leaves, three stars and
the words with no sun and moon, which is the mock's win exactly. The board is
the answer, so it does not leave: the chrome fades, the card slides down and
shrinks, and the planted field comes with it.

`win_delay()` is 2.1 s, the length of the planting wave on a hard board.

## 9. Two defects worth keeping written down

Both were found by rendering the screen rather than by the suite, which
passed throughout.

- **A mesh handed to `draw_mesh` must stay referenced until the frame is
  rendered.** The pending rectangle's area disc was built into a local, which
  is freed the moment `_draw` returns; the renderer was then given a dead RID,
  so the disc silently did not draw and every redraw logged `Parameter "mesh"
  is null`. `ui/faces/face.gd` already says this in its header -- it keeps its
  meshes in a static cache for exactly this reason -- and the overlay now
  keeps its own.
- **A layout that runs before the board has a size cannot be the thing an
  entrance measures from.** `build()` calls `_layout()` while the host has not
  sized the board yet, so it returns early and the markers are still at y 0;
  `_enter()` captured that as the resting height and tweened `position:y` back
  to it, overwriting the correct positions the later resize had written. Every
  marker stacked in the top row. Each marker now stands in its own slot
  (`ui/flat/tip_card.gd` does the same for the sprout): the layout moves the
  slot, the motion moves the face, and the two can never fight.

## 10. Calls this screen is still for

- **Does the area disc give away too much?** Section 6.
- **Is 133 enough on hard?** Seven by nine is the biggest grid of the twelve
  boards, and a drag has to start on a corner cell. 133 design pixels is about
  47 CSS pixels on a phone, against the 44 you would want under a thumb, so it
  is comfortable — but the count and the reach are separate questions.
- **Fourteen markers with faces.** Easy carries about 7 plots, medium 11, hard
  14. Fourteen small faces may be a crowd where five fruit or seven lanterns
  were a cast.
- **Whether the bed should blush at all**, now that the marker can look
  puzzled. Two signals for one state may be one too many, though it is the
  island's own choice and the honest one. Kept for now; cheap to drop.
- **Whether tap-to-clear is discoverable** without the tip card saying so. It
  is the one gesture on the board that is not a drag, which is why it is the
  second of the three teaching lines.

## 11. Amendment: the polish of 2026-09-19

The user asked for Shikaku to be polished with proper animations on Binairo's
pattern, smoother and more elegant, and for the pattern to be kept so the
other boards take it. Built straight in Godot, as Code Break's, Balance's and
Untangle's were, with this amendment and `docs/art/flat-motion.md` as the
record. The layout is kept; sections 3 to 6 stand. Section 7's motion and its
"pops in from nine tenths" are superseded by what follows.

**Two media, one hand.** The markers are nodes and take the vocabulary
straight. The field, the beds and the rectangle under the finger are drawn
into meshes, so they cannot be handed a tween; they read the same recipes as
curves instead. That needed the recipes written down as curves once, in
`core/motion.gd`: `back_out` (the overshoot every board had its own copy of),
`pop_in_scale`, `wide_pop_scale`, `pop_out_scale`, `drop_in_lift`,
`appear_level`, `bump_scale` and `flash_level`, each handed the seconds since
its moment began and landing on its final state under reduce-motion exactly as
the tween would. Three constants that were sitting as near-copies came in with
them: `ENTER_DELAY` (Balance 0.15, Untangle 0.18, Shikaku 0.2 -- now one 0.18),
`RESET_HOP` (Binairo's -4) and `BUMP` / `BUMP_TIME` (bump's own defaults, so a
drawn bump reads them). The doc's rule 8 names the readers; the four boards
still to port will use them.

**What changed, moment by moment:**

| Moment | Now |
|---|---|
| Entrance | the field pops in wide (`wide_pop_scale`, `ENTER_WIDE_FROM` 0.86 over `ENTER_POP` 0.25) after `ENTER_DELAY`; each marker pops in with the squash (`pop_in`) along the diagonal at `ENTER_STAGGER` 0.03, `ENTER_FACE_LAG` after the field starts. The 30 px slide-and-fade at 0.02 is gone |
| Drag | the wash pops in wide and the count disc pops in from nothing (`pop_in_scale`) as the finger lands; the disc bumps (`bump_scale`) whenever the area is recounted -- the table's Count moment |
| Place | the bed pops in wide over `POP_IN` 0.22 with the drop's fade, in place of its own 0.9 over 0.3 and 0.2; the marker inside hops `HOP` -6; the markers in the cells bordering the bed lean away `NUDGE` 3 and back; the earth at the four corners stays as this board's placement puff, in `BED_FURROW` |
| Remove, displaced, undo | a leaving bed shrinks to nothing over `POP_OUT` 0.12 (`pop_out_scale`, no turn on a wide thing, for the reason rule 7 gives), drawn from its own mesh after the state has forgotten it; a returning bed pops in; every marker freed or covered hops. Beds used to vanish in one frame |
| Hint | a ring in `LEAF` at the bed's centre through `Fx2D.ring`, the bed drops in from `DROP` 40 above (`drop_in_lift`), one sparkle, the marker takes the family's bump. The 0.18 bump over 0.4 and the six sparkles on a pool of three are gone |
| Wrong on Check | the marker wobbles (`wobble2d`) and its bed, if it has one, blushes toward its own rose and settles: the bed's blushing variant drawn over it at `flash_level`, so it lightens the way a blush does rather than darkening the way a modulate would |
| Refused | the marker shivers (`shiver`, 0.04 of its seat) and the pinned bed blushes; the sprout says why. The 0.36-seat dip is gone |
| Reset | the beds pop out in a wave from the far corner at `RESET_STAGGER` 0.02, the fence standing until the last has gone; the markers hop `RESET_HOP` in the same wave |
| Solved | the crop stays the signature, paced from `SOLVE_DELAY` 0.25 through `Motion.stagger` at the board's `PLANT_STEP` 0.1 (a bed is a row) with a `PLANT_WAVE` cap of 1.2; each marker hops `SOLVE_HOP` -10 over `SOLVE_TIME` 0.4 as its bed is planted, with a sparkle and a puff in turn. `WIN_WAIT` 2.2 |

Faces are written only when their look changes, as Balance's and Untangle's
are; the old refresh rewrote fourteen every move.

**The dressing:**

- **Shadows on the ground.** The stake's shadow comes out of the marker's mesh
  (`MarkerFace.casts`, the lantern's flag) and into one mesh of the family's
  soft discs (`Scenery.soft_disc`) built by the board, read off each marker's
  own height while the entrance runs and cached after, so it arrives with the
  pop and a hopping marker leaves it where it stood. Its peak is 0.2 in
  `TEXT`, above the doc's band, because a disc that fades to its rim reads at
  about half its centre and 0.14 left the foot floating. One draw call.
- **The field stands on the parchment** on the family's bottom edge of 6 in
  `LINE`, like every card on the flat screens.
- **No clouds or tufts.** The field is the ground seen from above and fills
  the card to a 34 px margin; a tuft in a cell would read as a piece.

**Measured** on this Mac at 1080 x 1920 through `tests/_shot_anim.gd`, whose
Shikaku run now draws the first solution plot corner to corner over 0.35 s
(`empty` skips it):

| | Draw calls | Idle |
|---|---|---|
| Medium board at rest, no bed, before | 94 | 4.00 ms |
| Medium board at rest, no bed, now | 95 | 3.34 ms |
| Now, with one bed and its fence | 101 | 3.37 ms |

The one call added is the shadow mesh; the time saved is the faces no longer
redrawn on every move.

Suite 2086/0. `tests/_win.gd` windowed 9/9, Shikaku solved through the real
hint button, Check and drags. A throwaway probe shot the entrance, a hint, a
refused drag, a wrong bed, Check, a clear, an undo, a reset and the planting
wave through to the win screen, each with and without reduce-motion (under
which the field and its markers are up at once, nothing blushes, shivers or
rings, a bed is there or gone in one frame and the crop is up the moment the
board is solved).

Open, still, from section 10: the area disc's generosity, the hard cell, the
crowd of fourteen faces and whether the bed should blush at all. Nothing here
answers them; it only makes the flat board move with the same hand as the
other four.

## 12. Amendment: the second polish, 2026-09-25

The user asked for the design and the animation to be polished. Built
directly, as Code Break's, Balance's and Untangle's second passes were the
same evening; this amendment is the record. The rules, the layout, the
markers and section 11's motion table are unchanged except where named.

**A bed is raised and tilled by the cell.** It stands on a lip of its own
darker soil (`BED_LIP`, the family's soft foot), and the dashed grain is gone
for two mounds of earth along every row (`RIDGES`), each a round-ended hump
a shade lighter than the soil over the shadow it throws and under a thin lit
crest. The mounds break at every column seam, which is the point of them: a
bed used to cover the grid lines, so its rows could be counted by the grain
and its columns could not. Now both can. A blushing bed's lip and grooves
take the blush with its soil.

**The fence has a post at every cell.** A small post at every lattice point
a run passes (`MID_POST_SHARE`), and the capped one of before where runs
meet, turn or cross, so a side can be counted post to post as well. A lying
rail is lit along its top; an upright one takes no light.

**The fence goes up post by post.** It is kept per unit seam now (`_edges`)
and diffed against the partition on every move (`_fence_sync`): a new
stretch grows out of its end nearer where the move began -- the cell the
finger went down on, a hint's bed after it has dropped, an undo's returning
bed -- `FENCE_STEP` a cell further round (capped at `FENCE_WAVE`), over
`RAIL_TIME`, its near post popping as it sets off and its far one as the
rail arrives. A stretch taken away shrinks to its middle over `POP_OUT` on
the same wave, so Reset's fence now comes down with the beds from the far
corner instead of standing until the last one has gone. The mesh is rebuilt
only while a stretch moves and cached after.

**A new bed is raked in.** Under its wide pop the mounds are drawn in row
after row, each left to right, over `TILL_TIME` in `TILL_STEPS` cached
frames.

**The drag.** The rectangle glides after the finger (`PEND_EASE`, an
exponential ease) instead of jumping a cell at a time, and the count's disc
rides it; its dashes crawl round it at `ANTS` cells a second, cut to a whole
number of periods so no stub sits where the path begins. When the rectangle
comes to fit the one sign inside it -- green -- that sign bobs, once, with
the family's bump.

Under reduce motion none of it moves: the fence stands or goes at once, a
bed arrives raked, the rectangle is where the finger is and its dashes stand
still.

**Measured** on this Mac at `--resolution 810x1440` with
`tests/_shot_anim.gd -- shikaku`, before and after on the same day's board:
draw calls unchanged (**100** with the harness's bed, **95/94** bare); a
settled board 2.46 and 2.48 ms against 2.39 and 2.42 before (idle window
moved to 3.2-5.2 s, because the harness's 2.2 s window catches the fence
still going up and reads 2.9). Reduce-motion pair 1.5 s apart
pixel-identical; ANGLE agrees on 100 with a max channel delta of 2/255, in
the wordmark's sun-dot. Suite 122583/0; `tests/_win.gd` windowed 21/21. A
throwaway probe ran two hints, a reset and a full solve through the
planting wave to the win screen with no error.
