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
