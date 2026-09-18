# Tents, flat: the sixth screen on trial

Status: built, 2026-09-18. Concept page:
`docs/brainstorm/concepts.html#tents`. Sibling specs:
`2026-09-18-binairo-flat-design.md`, `...-codebreak-`, `...-balance-`,
`...-shikaku-` and `...-untangle-flat-design.md`.

Tents & Trees: one tent pitched orthogonally beside every tree, no two tents
touching even corner to corner, and the numbers beside each line counting the
tents in it.

## 1. What flat buys here, honestly

**Less than it bought Shikaku, and this page should say so.** A meadow with
conifers on it is already this puzzle's natural home, and the island's version
is one of the prettiest of the twelve. Nobody should read this series as six
straight wins. What flat does buy is two things:

- **The counts.** Twenty-six numbers on a hard board, consulted constantly, and
  on a board pitched at seven degrees the far band is the smallest and most
  foreshortened thing on the screen — precisely the information you look at
  most, rendered worst. Flat, a count is the same size wherever it sits, and it
  changes colour legibly: green the moment its line holds exactly its number,
  rose the moment it holds too many.
- **The sweep.** Ruling ground out is most of the work in Tents — a hard board
  is 64 squares and 9 tents, so 55 of them are cairns — and a drag that lays a
  whole row of them is a gesture a grid square-on to the eye invites and a
  tilted one does not. That is the one place this screen is not just the island
  redrawn.

## 2. What was built

| File | New? | Job |
|---|---|---|
| `puzzles/tents_state.gd` | new | The rules, scene-free: trees, counts, what is on each square, and every gesture that changes it. |
| `puzzles/tents2d.gd` | new | The flat board: the meadow, the cairns, the characters, the gesture and the sprout's lines. |
| `ui/faces/tent_face.gd` | new | A canvas tent, carrying the two rules it can break on its own. |
| `ui/faces/conifer_face.gd` | new | A tree. It blinks, it sways, and it does nothing else. |
| `ui/faces/count_chip.gd` | new | One line's number, in the three states a line can be in. |
| `ui/flat/flat_host.gd` | edit | `card_centred()`: where a capped card's leftover goes. |
| `core/palette.gd` | edit | The flat meadow, the canvas, the pebbles. |
| `ui/registry.gd` | edit | `tents` goes flat; `tents_island` keeps the island board. |
| `tests/_win.gd` | edit | One driver solves both boards. |

The generator is untouched. `puzzles/tents_gen.gd` — the paired placement, the
uniqueness search, and `is_valid_solution` — is the island's, and both boards
run the same ladder (6×6 and 5 tents, 7×7 and 7, 8×8 and 9), so a day pitches
the same meadow on each.

## 3. The state is the one truth, with one deliberate difference

`tents_state.gd` is `tents3d.gd`'s logic ported, except that **a gesture is a
move, not a tap**. The flat board sweeps a whole row of cairns in one drag, so
the history records a *list* of squares rather than a single one, and a swept
row comes back on one undo rather than sixteen. The island only ever had single
taps to record, so this is the one place the flat board's history genuinely
differs from it — and it is a consequence of the gesture rather than a
decoration. Measured: a sweep across an eight-wide row is `moves=1`,
`history=1`, and one undo clears all six squares it changed.

## 4. The gesture

- **Tap puts a tent up or takes whatever is there away.** The island cycles
  blank → tent → cairn → blank, which costs two taps for every one of the 55
  cairns a hard board wants.
- **Drag sweeps.** The direction is read off the square the drag started on:
  begin on a cairn and the sweep rubs out, begin anywhere else and it lays.
  Verified both ways.
- **A sweep never disturbs a tent or a tree.** Losing a tent to a stray finger
  would be the worst bug on this board; verified by sweeping the length of a
  row a tent stands in and finding it still standing.
- **A fast finger leaves no holes.** The board fills in every square between
  the last one painted and the one the drag event carries. The mock paints only
  what it is handed, which is fine at a browser's event rate and would not be
  on a phone.

## 5. What the board says, and what it will not

A tent carries the two rules it can be seen breaking on its own: its fabric
goes rose when it touches another tent, diagonals included, or when it stands
beside no tree at all. A count chip goes green or rose for its line. That is
everything — **the board never draws which tree a tent belongs to.**

That restraint is the whole difficulty of Tents. The win test in `tents_gen.gd`
is not "every tree has a tent next to it"; it is a *perfect matching* between
trees and adjacent tents, precisely because greedy pairing is not enough. A
board can have a tent beside every tree and still be wrong, because two trees
are quarrelling over the same one. Drawing the ropes would hand that over. The
conifer therefore blinks and sways and reacts to nothing.

The three characters are all `Face` subclasses, so each is one cached mesh a
layer, and each carries its state on `expression` — the fabric's colour, the
chip's fill and the face all follow from it together, which keeps the base's
cache key (kind, layer, R, expression, eye) sufficient. The chip's numeral is
drawn over its mesh with one `draw_string`, as Shikaku's marker does it, and
the tent's hint peg is folded into `_kind()` because it is drawn into the same
mesh as the fabric.

## 6. The screen

Top bar (Back, `TENTS` with the leaf, `A CAMP FOR EVERY TREE`, then Undo, Hint
and Settings), day card, the board card, the actions row with Reset and Check,
the tip card. `capabilities()` is undo, hint and check, as Shikaku's is, so the
actions row is back.

**The counts live on a band outside the grid**, columns above and rows to the
left, 0.72 of a cell wide. On the island that band is a real extra row and
column of bare platform, because a stone has to stand on something; here
nothing stands on it, so it costs less than a cell.

**The card is cut to the meadow and centred in its slot**, which breaks the
family's habit of pinning the board under the day card. This is the one board
of the six whose grid is square while its space is tall: the cell is capped by
the *width* every time, so there is slack however the card is cut, and air
above and below reads as centring where all of it below reads as a board that
fell over. The host learned one optional method for it — `card_centred()`,
beside the `card_height()` Balance already used — and Balance's behaviour is
unchanged.

## 7. Motion

| Moment | What happens |
|---|---|
| Entrance | The counts fade along their bands, then the conifers drop onto the meadow on a diagonal. |
| Pitching | A tent pops in from six tenths; a cairn's pebbles arrive with the same overshoot. Squares under a running sweep carry a faint shade while the gesture runs. |
| Breaking a rule | The fabric turns rose the instant it happens and the sprout names which of the two rules it is. Nothing waits for Check. |
| A tree, or a pegged tent | Refuses the tap with a dip and a line from the sprout. |
| Check | Every tent the answer does not put there shakes; the sprout counts them. |
| Solved | The tents hop in reading order a tenth of a second apart, faces going to a grin as each lands, and **the cairns clear away** — a hard board finishes with 55 of its 64 squares under pebbles, and without this the last picture is the working-out rather than the camp. |

A tree's sway is `rock` through `_layer_angle`, the leaf's own idiom: a
transform on its own draw, so a swaying meadow never rebuilds a mesh and never
asks the board for a frame. Measured: the board goes quiet the moment its
entrance ends.

## 8. Measured

On this Mac, through `world/main.tscn`:

| | Draw calls |
|---|---|
| Medium board at rest (7×7, 7 trees) | 103 |
| Hard board at rest (8×8, 9 trees) | 111 |
| A swept row and a pitched tent | 106 |
| The win's hop and clear-away | 117 |

Against the 855 budget, with the stage hidden under the flat host's opaque
page. The meadow and its grid are one cached mesh; every cairn and the sweep's
shade are a second, rebuilt only when something moves; the characters are one
or two commands each.

Suite 2086/0. Win harness 19/19, both Tents boards included — the flat board
answers the island's own names (`w`, `h`, `_solution_tents`, `cell_to_local`),
so one driver solves both.

## 9. Calls this screen is still for

- **The cell is the tightest of the six.** At a phone's 1080 width a hard board
  lands at about 107 design pixels, which is 38 CSS pixels under a thumb
  against the 44 you would want; Shikaku's were 133. Options, in order of how
  much they cost: shrink the count band, drop hard from 8×8 to 7×8, or accept
  that the sweep means most interactions are drags and drags are forgiving.
- **Is a tent with a face one face too many?** Hard carries 9 tents and 9
  conifers, all with eyes. It may be a cast or it may be a crowd, and the trees
  are the ones that could lose theirs.
- **A tree that reacts to nothing** is deliberate (section 5), but a character
  that never answers can read as broken rather than as discreet.
- **Whether the sweep should lay cairns around a placed tent automatically**,
  the way experienced players do it by hand. A real convenience, and also the
  board doing a deduction for you.
- **Whether tap-to-clear a cairn is right**, or whether a cairn should have to
  be swept away so that a tap always means "tent".
- **The centred card breaks the family's rule** (section 6). If it reads as
  loose rather than as composed, the alternative is a full-height parchment
  with the meadow floating in it, which is what the first draft did and which
  read as an empty mat.
