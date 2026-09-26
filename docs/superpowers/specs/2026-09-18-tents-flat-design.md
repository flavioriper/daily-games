# Tents, flat: the sixth screen on trial

Status: built, 2026-09-18; polished onto the flat motion vocabulary,
2026-09-19 (section 10). Concept page:
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

## 10. Amendment: the polish of 2026-09-19

The user asked for Tents to be polished with proper animations on Binairo's
pattern, smoother and more elegant, and for the pattern to be kept so the
other boards take it. Built straight in Godot, as Code Break's, Balance's,
Untangle's and Shikaku's were, with this amendment and
`docs/art/flat-motion.md` as the record. The layout is kept; sections 2 to 6
stand. Section 7's motion is superseded by what follows.

**Two media on one board.** Tents is the first board with both: the trees,
the tents and the count chips are Face nodes, and the cairns, the shade under
the finger and a cell's blush are drawn. The nodes take the vocabulary
straight, each tree and tent standing in a slot the layout owns so the hop,
the nudge and the shiver never fight a relayout (a chip only ever scales and
needs none); the drawn things read the same recipes as curves
(`Motion.pop_in_scale`, `pop_out_scale`, `wide_pop_scale`, `flash_level`) off
one `_anim_until` clock that every recipe start extends. Every move -- a tap,
a sweep, an undo, a hint, a reset -- goes through one `_transition` that
diffs a snapshot of the marks against the state, so a tent going up or down
and a cairn arriving or leaving are the same code from every direction. The
doc gained rule 9 from it: a piece drawn in one skin, with nothing to flash
toward (a conifer, a pegged tent), blushes through its cell.

**What changed, moment by moment:**

| Moment | Now |
|---|---|
| Entrance | the meadow pops in wide (`wide_pop_scale`, `ENTER_WIDE_FROM` 0.86 over `ENTER_POP` 0.25) after `ENTER_DELAY`; each chip and each tree pops in with the squash (`pop_in`) along the diagonal at `ENTER_STAGGER` 0.03, `ENTER_FACE_LAG` after the meadow starts, a chip in step with the diagonal its line meets. The 26 px drop and the fade at 0.02 are gone |
| Press | a tree or a tent sinks to `PRESS_SCALE` 0.94 (`press`) and springs back; bare ground and a cairn take a shade that pops in wide under the finger (`wide_pop_scale` over `POP_IN`) and shrinks away when the finger leaves it. Nothing pressed before |
| Place | a tent pops in with the squash (`pop_in`, `POP_IN` 0.22) in place of its own six tenths; a puff in `TENT_CANVAS`; the trees and tents on its four sides lean away `NUDGE` 3 and back; the row's and the column's chips bump (`bump`, the Count moment) |
| Sweep | the shade follows the finger over the ground it can change, and on release the cairns arrive in a wave along the finger's path at `ENTER_STAGGER`, each cell's shade staying until its cairn lands (`pop_in_scale`, with the squash). No puffs: a row of them is a cloud. A rub-out runs the same wave with the pop out |
| Remove, undo | a tent shrinks to nothing with the quarter turn (`pop_out`, `POP_OUT` 0.12) and a cairn does the same, drawn from a leaving list after the state has forgotten it; what comes back pops in. Both used to vanish in one frame |
| Hint | a ring in `LEAF` through `Fx2D.ring`, the tent drops in from `DROP` 40 above with the fade (`drop_in`), one sparkle; a cairn under it pops out first |
| Wrong on Check | the tent wobbles (`wobble2d`) and its cell blushes toward `BAD_TILE` and settles (`flash_level`), drawn into the ground. The 0.6 s horizontal shake is gone |
| Refused | a tree or a pegged tent shivers (`shiver`, 0.04 of a cell) and its cell blushes; the sprout says why. The dip is gone |
| Reset | the cairns and tents pop out in a wave from the far corner at `RESET_STAGGER` 0.02 and the trees hop `RESET_HOP` in the same wave; the chips of the lines that emptied bump. Everything used to vanish at once |
| Solved | every tree and tent hops `SOLVE_HOP` -10 over `SOLVE_TIME` 0.4 along the diagonal from `SOLVE_DELAY` 0.25 at `SOLVE_STAGGER` 0.04, each going to JOY as the wave reaches it, a sparkle or a puff in turn at each tent; the cairns clearing away in a scatter (`CLEAR_*`) stay this board's own. `WIN_WAIT` 1.6, from 2.0 |

Faces are written only when their look changes, as the other four boards do
it.

**The dressing:**

- **Shadows on the ground.** The tree's and the tent's shadow leave their
  face meshes (`casts`, the marker's flag, now on `ConiferFace` and
  `TentFace`) for one board mesh of the family's soft discs
  (`Scenery.soft_disc`), read off each piece's own height so a shadow
  arrives with the pop and shrinks with the pop out, and anchored at the
  cell so a hopping piece leaves it where it stood. Peak 0.2 in `TEXT`, as
  Shikaku measured it. The tent's guy lines stay with the tent.
- **The meadow stands on the parchment** on the family's bottom edge of 6 in
  `LINE`, like every card on the flat screens.
- **No clouds or tufts.** The meadow is the ground seen from above and fills
  the card to a 34 px margin; a tuft in a cell would read as a piece.

**Measured** on this Mac at 1080 x 1920 through `tests/_shot_anim.gd`, whose
Tents run now sweeps the top row (`empty` skips it), two readings each:

| | Draw calls | Idle |
|---|---|---|
| Medium board at rest, bare, before | 103 | 3.24, 3.30 ms |
| Medium board at rest, bare, now | 97 | 3.38, 3.40 ms |
| Now, with a swept row of five cairns | 97 | 3.59, 3.61 ms |

The six calls saved are the trees' shadow layers, now one ground mesh.

Suite 2086/0. `tests/_win.gd` windowed 9/9, Tents solved through the real
hint button, Check and taps. A throwaway probe shot the entrance, a placed
tent, a refused tree, a sweep and its cairns, a wrong tent under Check, an
undo, a hint, a removal, a reset, a held press and the solve wave through to
the win screen, each with and without reduce-motion (under which the meadow,
the chips and the trees are up at once, nothing blushes, shivers or rings, a
tent or a cairn is there or gone in one frame and the win screen follows the
last tap). The probe also caught its own trap: `Motion.reduce` has to be set
right before the board opens, because `world/main.gd`'s deferred `_ready`
reloads settings over anything set earlier.

Open, still, from section 9: the hard cell, the crowd of eighteen faces, the
tree that reacts to nothing, the automatic cairns and the centred card.
Nothing here answers them; it only makes the flat board move with the same
hand as the other five.

## 11. Amendment: the second polish, 2026-09-25

The user asked for the design and the animation to be polished. Built
directly, like the second passes of Code Break, Balance, Untangle and Shikaku
the same evening, and this amendment is the record. The rules, the layout,
the chips and section 10's table are unchanged except where named.

**The meadow is dressed, but never inside a square.** Section 10's reason
for no tufts still holds -- a tuft in a cell would read as a piece -- so a
tuft (`Scenery.tuft`, made public for this) stands on some of the grid's
inner crossings (`TUFT_SHARE`) and a small five-petal flower on a few more
(`FLOWER_SHARE`). A crossing belongs to no square, so nothing a player puts
down ever stands on one. A light runs along the turf's top edge
(`RIM_LIGHT`). All of it is in the cached meadow mesh.

**The tree and the tent are shaded.** Each of the conifer's tiers has a lit
left half and a shaded right half, with its hem bowed up between the tips so
they droop (`HEM_BOW`, `TIER_SHADE`), and its trunk has a dark side. The tent
has poles crossed over its ridge, a seam down the lit slope with light along
its outer edge, its door flap rolled back to show the lining, and a wooden
peg at the foot of each guy line. On JOY its doorway is lamp-lit (`SUN`
toward the canvas, with a paler core), and JOY only ever comes with the win.
The menu card and the how-to-play diagram draw these same faces and pick up
the change. Nothing else draws them, so it is not opt-in the way Untangle's
pleats were.

**A cairn has three tiers and no two are alike.** Each stone is lit along
its crest (`CREST`). A square leans its cairn by up to `CAIRN_TILT`, sizes it
within `CAIRN_JITTER` and slides the cap by up to `CAIRN_SHIFT`, all off two
fixed hashes of the square, so a swept row no longer reads as one stamp laid
seven times.

**A tent is pitched, not popped.** It stands on a pivot at the foot of its
fabric (`FOOT`), so it comes up out of the ground: flat and wide
(`PITCH_FROM`), stretched past its height (`PITCH_STRETCH`), and home on the
back ease over `PITCH_TIME`. Struck, whether by a tap, an undo or Reset, it
folds back down into the ground over `STRIKE_TIME` instead of shrinking with
the quarter turn. With the new pivot, the press, Check's wobble and the solve
hop all rock it on its foot. A hint's tent still drops in from above.

**A cairn is stacked a stone at a time.** First the two at its foot with the
shadow, then the middle one, then the cap, `STACK_STEP` apart. Each drops on
from `STACK_DROP` of the cairn's height, reading `Motion.drop_in_lift` and
`pop_in_scale` over `STACK_TIME`; the cap's glint grows with the cap. Taken
away, the cap goes first (`UNSTACK_STEP`), each tier rising `UNSTACK_LIFT` as
it shrinks.

**The win is a camp.** The cairns no longer fade. They sink into the turf in
the same scatter as before (`CLEAR_*`). As each one is half down, a tuft grows
on `WIN_TUFT_SHARE` of the squares nothing stands on (those tufts are inside
squares, but nothing more can be put down by then). As the solve wave reaches
each tent, its doorway lights and throws a warm pool on the grass in front
(`GLOW_*`). `restore_completed_board()` opens onto the same picture, because
the tufts are chosen by square and not by whether a cairn was there.

Under reduce motion none of it moves. A tent is up or gone, a cairn stands
whole or is gone, and the win's camp is there at once.

**Measured** on this Mac at `--resolution 810x1440` with
`tests/_shot_anim.gd -- tents`, before and after on the same day's board.
Draw calls are unchanged: **94** swept and bare, and 94 under reduce motion.
The harness's 2.2 s idle window catches the stacking's tail and reads 2.57
and 2.62 ms against 2.42 and 2.41 before. With the window moved to 3.2-5.2 s,
a settled board reads **2.25 and 2.24 ms against 2.28 and 2.31 before**. The
reduce-motion pair 1.5 s apart is pixel-identical. Under reduce motion, ANGLE
agrees on 94 with a max channel delta of 1/255 (compared under reduce motion
because the trees' sway has a random phase each run). Suite 122583/0;
`tests/_win.gd` windowed 21/21. The menu reads 260 calls both before and
after. A throwaway probe pitched the answer's tents, a wrong one, a sweep,
Check, two undos, a full sweep, the solve and `restore_completed_board()`, and
shot each of them.
