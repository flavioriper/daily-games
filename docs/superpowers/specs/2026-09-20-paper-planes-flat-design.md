# Paper Planes, flat: the fifteenth screen

Status: designed 2026-09-20, alongside the concept page.
Concept page: `docs/brainstorm/concepts.html#planes` -- it plays the real
generator, not a fixture.
Reference: the user's screenshot of another app's board, **SETAS**, saved at
`docs/art/concept-planes-reference.png` and measured in section 2.
Sibling specs: the nine `2026-09-18-*-flat-design.md`,
`2026-09-19-queens-flat-design.md`, `2026-09-19-hidden-word-flat-design.md`,
`2026-09-20-word-trail-flat-design.md`, `...-mushroom-patch-flat-design.md`
and `...-sudoku-flat-design.md`.

A field of paper planes, each one a bent trail of cells with a folded dart at
its head. **Tap a plane and it launches**: it slides forward along its own
trail and out of the board, head first, the body following the head's track
the way a ribbon is pulled through a hole. It only goes if the **lane** --
every cell straight ahead of the dart, out to the edge -- is empty. Clear the
sky and the board is done.

**The name is not Setas, and the game is not an arrow.** *Setas* is simply
Portuguese for *arrows*, the reference app's own title for a game it did not
invent either; the genre ships in a dozen stores as some arrangement of the
words *arrow*, *tap* and *away*. This repo has renamed a game it did not
invent four times now -- Mastermind ships as **Code Break**, the New York
Times' word game as **Hidden Word**, LinkedIn's as **Word Trail**, and
Minesweeper's gentler cousin as **Mushroom Patch** -- and the move here is
the same one, with the re-theme that the family's paper world hands over for
free: an arrowhead folded once is a paper dart, and a dart that must have a
clear lane before it takes off *is* the rule, said in a picture.

## 1. What is built

| File | New? | Job |
|---|---|---|
| `puzzles/planes_state.gd` | new | The rules, scene-free: the grid, the planes, the lanes, generation, launch/undo/reset/hint, and the solver that proves a board. |
| `puzzles/planes2d.gd` | new | The flat board: the field of dots, the trails, the darts, the launch, the wake and the refusal. |
| `ui/registry.gd` | edit | The fifteenth grid entry, on page two. |
| `ui/menu/card_art.gd` | edit | The menu card's picture: one `_draw` branch, no character. |
| `tests/test_planes.gd` | new | The state class: generation, solvability over a sweep of seeds, the lane rule, launch, undo, reset, hint. |
| `tests/_shot_anim.gd` | edit | A `planes` case: a launch and its wake in the strip, then the idle window. |
| `docs/brainstorm/concepts.html` | edit | The playable tab (done first, 2026-09-20). |
| `docs/art/flat-motion.md` | edit | One line for the launch and the wake, in the family's table. |

Nothing else moves. **No new character is drawn** (section 9), **no new
colour is added to the palette** (section 8), and **`core/motion.gd` gains
nothing** (section 10).

## 2. What the reference is, and what was measured off it

The screenshot is one screen of another app's daily: a pink chrome bar
reading `SETAS`, a day line, a timer, an ad rail for a VIP tier, and between
them a dense board of bent black arrows on a lattice of faint grey dots.
Measured off the pixels rather than guessed:

| Measured | Value |
|---|---|
| Lattice pitch | 32 px on a 565 px-wide screenshot |
| Grid | **16 columns by 22 rows** (x 42..522, y 303..976) |
| Stroke | 5 px, about 0.16 of a cell, round joins |
| Arrows | about 45, lengths from 2 cells to a dozen |
| Empty cells | a faint grey dot each -- which is how the occupancy reads at a glance |

**Taken from it:** the lattice, the dot on every empty cell, the bent trails
with one head each, the density (roughly three cells in four covered), and
16 x 22 as the hard band. **Not taken:** the name (above), the plain
arrowhead (section 8), the pink chrome and the ad rail, and the lives -- the
genre's apps charge a heart for a blocked tap, and this game has had no lives
on any board since 2026-09-18.

## 3. The rules, and the one fact that shapes the whole screen

- The board is a grid of cells. A **plane** is a self-avoiding path of 2 or
  more cells, tail to head. Its **direction** is the step from the cell
  before the head to the head. No two planes share a cell.
- A plane's **lane** is every cell strictly beyond its head, in its
  direction, out to the edge of the board.
- **A tap launches the plane if its lane is empty.** It slides along its own
  body and then straight out; its cells go empty.
- **If any cell of the lane is occupied, the tap is refused** -- and that is
  all that happens. No life, no counter, no mark on the board (section 10
  says what it looks like).
- The board is won when the last plane has gone.

Everything else on this screen follows from one fact:

> **A launch can never block another plane.** Launching only empties cells,
> and a lane is blocked only by occupied ones. So if a board can be cleared
> at all, it can still be cleared after *any* legal tap: take the old order
> and strike the plane just launched out of it -- every remaining plane's
> lane is a subset of the cells it faced before, so each is still clear when
> its turn comes.

Three consequences, and they are the reason this board's chrome is the
shortest in the game:

1. **There is no wrong move**, so there is **no Check**. Nothing incorrect
   can ever be sitting on the board, exactly as on Word Trail.
2. **The player cannot dead-end the board.** A board generated solvable stays
   solvable to the last tap, whatever order is chosen.
3. **The solver is greedy and complete.** Repeatedly launch any plane whose
   lane is clear; if the board empties, it was solvable, and no search or
   backtracking is ever needed. This is what `tests/test_planes.gd` proves a
   generated board with, and what `hint()` picks from.

Undo and Reset are therefore pure convenience rather than repair, and they
are kept for the same reason every board has them.

## 4. The state is the one truth

`puzzles/planes_state.gd` is scene-free and holds the whole game, the way
`word_trail_state.gd` and `sudoku_gen.gd` do for theirs. The board script
draws it and nothing else.

```
rows, cols: int
planes: Array[Dictionary]     # {"cells": Array[Vector2i] tail..head, "dir": Vector2i, "gone": bool}
occupant: Dictionary          # Vector2i -> plane index, for the planes still here
order: Array[int]             # the generator's own solution order, for the hint
history: Array[int]           # launched, in order, for undo
```

The API is small: `generate(rng, difficulty)`, `lane(i)` (the cells ahead),
`blocker(i)` (the first occupied cell in the lane, or `null`), `free(i)`,
`free_planes()`, `launch(i)`, `undo()`, `reset()`, `solved()`, and
`solve_order()` -- the greedy solver, returning the order it found or an
empty array if the board is stuck, which is what the test sweep calls.

`occupant` is maintained rather than recomputed: a launch clears the plane's
own cells, an undo writes them back. `lane`, `blocker` and `free` read it, so
nothing about blocking is ever stored -- the crosses on Queens' board are
derived the same way, and for the same reason: an undo that puts a plane back
must not have to remember what it used to block.

## 5. Generation: carve the board backwards out of an empty sky

The generator never solves anything. It builds the board in **reverse play
order**, so a solution exists before the first pixel is drawn.

Repeatedly, until the coverage target is met or a run of `TRIES` placements
has failed in a row:

1. Pick a random empty cell as the **head** and a random direction whose lane
   is **entirely empty**. (If no direction works, pick another cell.)
2. Grow the **tail** backwards from the head as a random self-avoiding walk
   through empty cells, to a length drawn from the band's weights. The walk
   may never enter the lane, so **a plane can never block itself** and the
   rule in section 3 needs no special case for the plane being tapped.
3. Place it. The first step back from the head is forced to be the opposite
   of the chosen direction, which is what fixes the dart's heading.

Planes placed **later** are launched **earlier**: when plane *i* was placed,
the board held exactly the planes placed before it, and its lane was checked
clear of those. Launch them in reverse placement order and each one meets
precisely the board it was validated against. The generator's `order` is that
reversal, kept only for the hint.

**A coverage retry, not a coverage guarantee.** As the sky fills, free cells
gather into pockets with no clear lane to an edge, and placements start
failing; the honest ceiling is around nine cells in ten and the honest floor
is nearer six. The generator makes up to `CANDIDATES` boards and keeps the
first at or above the band's coverage floor, else the fullest one it made. It
is cheap enough to do that: measured with `tools/_planes_probe.py`, the
algorithm in Python takes **0.8 ms (easy), 1.3 ms (medium) and 1.9 ms (hard)**
a board on this Mac, twenty seeds a band -- two orders off Sudoku's budget
problem, so there is no fallback path here and nothing to grade against a
clock. The shipped GDScript, measured the same way with a throwaway
`SceneTree` probe over forty seeds a band once `build()` existed (Task 2),
came in at **1.3 ms (easy), 2.2 ms (medium) and 7.0 ms (hard)** -- still two
orders off the budget, but the hard band is proportionally the outlier: easy
and medium ran 1.6x the Python figure, hard ran roughly 3.7x, which is worth
naming rather than smoothing over even though it changes nothing about the
lack of a fallback path.

Every generated board is then run through the greedy solver before it is
handed over. It has never failed -- it cannot, by construction -- and the
check stays because the cost is a microsecond and the claim is worth
enforcing.

## 6. The bands

| Band | Grid | Plane length | Source | Planes | Coverage | ms/board |
|---|---|---|---|---|---|---|
| Easy | 10 x 14 | 2-8 | Python probe (20 seeds) | 21-33 (mean 25) | 0.74-0.89 | 0.8 |
| Easy | 10 x 14 | 2-8 | GDScript on this Mac (40 seeds) | 21-31 (mean 25.4) | 0.72-0.91 (mean 0.80) | 1.3 |
| Medium | 13 x 18 | 2-9 | Python probe (20 seeds) | 27-45 (mean 37) | 0.65-0.81 | 1.3 |
| Medium | 13 x 18 | 2-9 | GDScript on this Mac (40 seeds) | 30-45 (mean 37.7) | 0.73-0.87 (mean 0.78) | 2.2 |
| Hard | 16 x 22 | 2-10 | Python probe (20 seeds) | 42-59 (mean 51) | 0.63-0.82 | 1.9 |
| Hard | 16 x 22 | 2-10 | GDScript on this Mac (40 seeds) | 45-62 (mean 51.6) | 0.70-0.83 (mean 0.75) | 7.0 |

The GDScript row is `build()` itself (Task 2), read from a throwaway
`tools/_planes_time.gd` `SceneTree` probe, two runs each within 0.1-0.2 ms of
the figures above; it is not kept in the tree. Plane counts and coverage land
close to the Python probe's on every band -- the port carries the same
behaviour -- but the timings diverge on the hard band specifically (see
section 5): easy and medium run about 1.6x Python's ms, hard runs about
3.7x, likely GDScript's per-call overhead compounding over the longer
self-avoiding walks a 16 x 22 board needs. Both are still far under any
budget, so nothing here changes the "no fallback path" conclusion above.

Difficulty here is **how long the scan is, not how hard the logic is** --
there is no logic, in the Binairo sense, only looking. A bigger board holds
more planes and more of them are free at once (the probe's mean was 6.9, 9.7
and 11.6 planes tappable at a time), so what the hard band costs is minutes
and attention rather than deduction. That is the genre, and it is worth
saying out loud rather than dressing a scanning game as a deduction one.

The hard band is the reference's own 16 x 22.

## 7. The screen, measured (1080 x 1920 design space)

| Row | Height | What is in it |
|---|---|---|
| Top bar | 180 | Back, `PAPER PLANES` in ink with the leaf, `A CLEAR LANE AND AWAY` under it, then Undo, Reset, Hint with its count, Settings. **Five buttons**, because there is no actions row for Reset to stand in. |
| gap | 20 | |
| Day card | 120 | The family's. |
| gap | 20 | |
| Board card | **1340** | 1000 wide, parchment, 28 inset, so the field box is **944 x 1284**. |
| gap | 20 | |
| Tip card | 140 | The sprout, the line for what just happened, and the only door to the rules sheet. |

Margins 40 top and bottom. `cell = floor(min(944 / cols, 1284 / rows))`, and
the grid is centred in the field box:

| Band | cell | grid |
|---|---|---|
| Easy | 91 | 910 x 1274 |
| Medium | 71 | 923 x 1278 |
| Hard | 58 | 928 x 1276 |

Every band is bound by **height**, narrowly -- a tall grid in a tall slot --
so `card_height(available)` hands back everything it is given and there is no
slack worth centring; `card_centred()` stays false, as Word Trail's does, and
the few leftover pixels are absorbed by centring the grid inside the box.

**58 is the smallest cell in the game**, under Sudoku's 100 and Queens' 103,
and it is bearable for a reason none of those could use: **you do not tap a
cell here, you tap a plane**, and the smallest plane covers two cells and
carries a dart drawn across most of one. The hit test is by cell and the
answer is the plane occupying it, so the target is the whole body.

## 8. Colour, and how it is drawn

No new palette entry. The board is ink on parchment, which is what the
reference is and what this family's boards have never quite been:

| Piece | Colour | Size |
|---|---|---|
| Empty cell | `LINE` at 0.45 | a dot, radius 0.05 cell |
| Trail | `TEXT` | stroke 0.17 cell, round caps and joins |
| Dart | `TEXT` | 0.42 cell forward of the head's centre, wings 0.26 back and 0.30 aside, tail notch 0.12 back |
| Crease | `PAPER` | a fold slit near the tip, 0.06 cell wide, running `[0.22, -0.05]` of a cell along the spine rather than down the whole of it |
| Lane, pressed and clear | `SUN` at 0.35 | a band 0.34 cell wide |
| Lane, refused | `BAD_TILE` at the flash's own level | the same band, first lane cell to blocker |
| Hint glow | `SUN_RAY` at 0.32 | a wash **0.86 cell wide** under the hinted plane's whole body |
| Hint ring | the family's (`ui/fx2d.gd`) | |

**The dart is the one thing the reference's picture loses.** A solid
arrowhead is a triangle; a dart is the same triangle with a notch cut out of
its tail and a crease down its spine, which is two more polygons and reads as
folded paper at 58 px. That is the whole re-theme: the board is the
reference's board, drawn in this game's material.

**The crease's 0.09 was designed and its 0.06 was seen** (amended 2026-09-20,
Task 3). The wider number came off this page; the narrower one came off a
screenshot at the hard band's 58 px cell, where a `PAPER` slit 0.09 of a cell
across hollows the dart out and the head stops reading as the solid ink the
reference's arrowhead is. The canvas mock at
`docs/brainstorm/concepts.html#planes` had already settled on 0.06 over the
short `[0.22, -0.05]` run, and `puzzles/planes2d.gd` ships the mock's numbers.
**The lane band is 0.34, and the disagreement it was recorded as having with
the mock never existed** (amended 2026-09-20, Task 4, by the same method: two
screenshots at the hard band's 58 px cell rather than an argument). The mock
draws *every* wash at one width -- its `WASH_W` is 0.34, for the press
preview, the refusal and the hint's glow alike -- so the "0.86 wash there"
recorded above was a misreading of the mock and not a second opinion about
the band. Drawn both ways, 0.34 is also the better picture, for a reason
worth keeping: **a third of a cell is a line and reads as the way out** --
the route the plane would take, drawn in the same language as the trails,
with the dots on either side of it still showing -- while 0.86 floods the
cells kerb to kerb, swallows those dots, crowds the trails in the rows above
and below, and reads as *this region is wrong*, which is a sentence this
board never says: nothing is wrong, the lane is merely occupied.

**The hint's glow is the one wash that is deliberately not 0.34.** It is
0.86, because it is doing the other job: the lane band names a *path* and
has to read as a line, and the glow names a *piece* and has to read as a
light standing under the body it sits beneath. At 0.34 under a 0.17 trail
the glow is a gold rim barely a stroke wider than the ink -- the trail looks
outlined rather than lit, and under the dart it all but disappears. Both were
shot at 58 px before this was written.

The field is **one `ArrayMesh`**, rebuilt only when something changes, the
way Word Trail's field is: the dots, the trails, the darts, the lane band and
the hint glow all go into it, because none of them has a face on it and a
Control per plane would be fifty nodes. The mesh the last `_draw` handed over
is kept in `_shown` until the next one replaces it -- a canvas command holds
a mesh by RID and not by reference, and a harness that calls
`RenderingServer.force_draw()` will otherwise photograph a freed one.

## 9. The cast: nothing

Paper Planes is the **fifth board to add nothing to `ui/faces/`** and the
**second to seat no character at all**, after Sudoku. Its pieces are folded
paper, drawn straight into the field mesh; the one face on the screen is the
shared sprout on the tip card. Nonogram decided this, Hidden Word and Word
Trail confirmed it, Sudoku made it a pattern: a board whose pieces are marks
rather than creatures does not get a mascot bolted onto it.

## 10. Motion

Everything comes from `core/motion.gd` and `docs/art/flat-motion.md`. This
board adds **three constants of its own** and nothing to the shared
vocabulary:

| This board's own | Value | Why it cannot be shared |
|---|---|---|
| `LAUNCH_SPEED` | 22 cells a second, minimum 0.22 s | Nothing else in the game moves a piece along its own body. |
| `WAKE_STEP` | 0.04 s per king-move step | Queens' `WAVE_STEP` is 0.05 and tuned to a queen's sight; this wave runs out of a departing plane. |
| `BLOCK_FLASH` | 0.35 s | The refusal's band. |

- **The launch is the signature.** The plane runs along a *track*: its own
  body polyline, extended past the head down the lane and one body-length
  beyond the edge. With `s` the cells travelled, the body drawn is the slice
  of the track between `s` and `s + len - 1`, so the tail follows the head
  through every bend it made. It eases in -- `Motion`'s own curve, read as a
  reader the way Shikaku and Light Up read theirs -- so the plane accelerates
  away, and a puff of sparkles (`ui/fx2d.gd`) marks where it crossed the
  edge.
- **The wake answers the move.** After a launch, the set of free planes is
  diffed against a snapshot taken before it, and every **newly freed** plane
  beats its wings once (`Motion.bump_scale` on the dart, 0.24 s), staggered
  by `WAKE_STEP` times its king-move distance from the departing plane's
  head. This is Queens' `_settle` exactly -- derived from the state, never
  stored, so an undo leaves nothing behind to clean up -- and it is what
  makes the board feel as though it noticed.
- **A refusal is a picture of the rule, not a scolding.** The lane flashes in
  `BAD_TILE` from the dart up to the blocking cell, the **blocking** plane
  shivers (`Motion.shiver_offset`), and the tapped plane nudges forward and
  back (`Motion.nudge_offset`). No toast: unlike Hidden Word's refusals, this
  one is frequent by design and already fully explained by the flash. The tip
  card takes the line.
- **Undo** runs the last launch backwards along the same track; **Reset**
  flies them all back, staggered from the far corner, which is the family's
  reset wave.
- **The solve** is the family's wave over the empty dots, then the win
  screen.
- **Reduce motion** stills all of it: a launch becomes an instant removal,
  the wake and the flash do not run, and two frames 1.5 s apart must come out
  pixel-identical.

**What the three constants turned out not to have to cover** (amended
2026-09-20, Task 4, as built). Four numbers the table above reads as this
board's are the vocabulary's, and none of them became a fourth constant:

- **The 0.22 s floor under a short launch is `Motion.POP_IN`**, not a
  coincidence written down twice. A launch is never quicker than the pop a
  piece arrives with, which is the honest reason for a floor at all.
- **The ease is the family's own curve read backwards.**
  `Motion.pop_out_scale` is a quarter-cosine falling from one to nothing, so
  one minus it rises from nothing and accelerates away -- which is a launch.
  Its inverse is arithmetic, and two things need it: the puff, which has to
  know the frame the head crosses the edge, and every cell's dot, which has
  to know the frame the tail passed over it.
- **A cell takes its dot back over `Motion.appear_level`**, read against the
  second the tail crosses that cell rather than over a distance in cells, so
  the dot's return costs nothing either.
- **The refusal's shiver and nudge are the vocabulary's own pixels**
  (`SHIVER_PX` 2, `NUDGE` 3), not the mock's cell fractions (0.05 and 0.22 of
  a cell). The family measures both in the 1080-wide design space rather than
  per cell, and taking the mock's would have meant two more constants for a
  detail the band already carries. The mock's are the more visible lurch at
  58 px and that is the trade made; it is named here rather than hidden, and
  it is a one-line change through `nudge_offset`'s own `px` parameter if the
  refusal ever reads as too quiet on a phone.

**A plane turns around in the air; it never snaps home first** (amended
2026-09-20, Task 4, fix round 1). Undo and Reset put a plane back in the
state the instant its flight home *begins* -- the board has to be correct
before the picture is -- so its cells are tappable again while it is still
out over the edge, and there is deliberately no busy gate to stop that. Both
directions therefore start a new flight at the phase whose eased position is
where the plane actually is, rather than at the end of the track: without it,
a re-tap during a flight home snaps the plane back to its resting cells
before launching it, and an Undo during a flight out throws it off the board
before bringing it in. Both were reproduced on rendered frames before the fix
and after. One consequence is worth stating rather than discovering: **a
plane already in the air does not wait its turn in Reset's wave** -- the
stagger delay is dropped for it, because holding a moving piece still is the
same teleport one beat later.

The wake's own stagger goes through `Motion.stagger(k, WAKE_STEP)`, so it
takes the family's 0.6 cap: on a 16 by 22 field a king-move distance can
reach 21, and 21 x 0.04 is 0.84 s of wings still beating after the plane has
gone. The cap is rule 4 and this board does not raise it.

## 11. The hint

Three, as everywhere. A hint rings one **free** plane and beats its wings; it
never launches it. The pick is the first free plane in the generator's own
`order` when that plane is still on the board, else any free one -- so a hint
nudges the player along the intended thread when there is one and is still
correct when the player has wandered off it. `hints_left()` and `hint()` are
the base class's.

## 12. The menu card

The fifteenth entry in `Registry.PUZZLES`, which puts it on **page two**
beside Mushroom Patch and Sudoku -- the third card there, and the first one
to land on that page without a word being changed anywhere else: the pager
arrived on 2026-09-20 for the thirteenth card and `PER_PAGE` is twelve, so
the fifteenth costs the first screen nothing at all. The short last row still
needs its invisible filler `Control`s, which `ui/menu.gd` already pads out.

The picture is **pure `_draw`**, like Nonogram's and Sudoku's: three bent ink
trails with darts at their heads, across the 320 by 118 box, with the faint
dots of the field behind them. No branch of `_build`, no character, no
furniture.

Registry line:

```
"id": "planes", "title": "Paper Planes",
"blurb": "Tap a plane whose lane to the edge is clear, and off it goes.",
"short": "Send every plane\noff a clear lane.",
"motto": "A clear lane and away", "footer": "Scan · Clear · Launch",
"script": "res://puzzles/planes2d.gd", "shell": "flat",
"tray": "none", "actions": false, "difficulties": [0, 1, 2],
```

`PAPER PLANES` is a long title and `flat_top_bar.gd` letters it smaller by
itself; nothing here sets a font size. The bar's block is the five-button
370, as Word Trail's is.

## 13. What the board says

`rules()`: the three sentences of section 3 -- what a lane is, what a tap
does, and that a blocked tap costs nothing. The rules sheet is reached from
the tip card, which this board keeps.

`tip_line()` says what just happened, in the family's voice: the opening line
names the rule, a refusal says the lane is blocked and by which way, a launch
after a long pause says nothing at all. It never counts planes: **the board
is its own scoreboard**, and an empty sky is the only score anyone needs --
Word Trail's rule, and Mushroom Patch's.

`flat_win()`: **no cast and a subtitle**, `{"faces": [], "subtitle": "Every
plane found its lane."}`. The host's `faces` are Controls from `ui/faces/`,
and this board has none by section 9's rule, so the win screen keeps the
family's sun and moon -- which is what Nonogram, Word Trail and Sudoku all
do for the same reason. A dart drawn on the win screen would mean a new
Control for one screen's sake, and that is exactly the bargain section 9
declines.

## 14. Analytics

Nothing new. `puzzle_start`, `puzzle_complete` with `solved: true`,
`hint_used`, `undo_used` and `board_reset` all come from the host. There is
no `check_used` on this board because there is no Check. A refused tap sends
nothing: it is not a mistake, and an event that counts it would invite
somebody to treat it as one.

## 15. Calls this screen is for

The budget is 855. The field is one mesh, the chrome is the family's, and
there is no character on the screen, so the expectation was that this would
be the **cheapest board in the game** -- under Word Trail's 60-65.

**Measured (Task 5, 2026-09-20), and the expectation holds.**
`tests/_shot_anim.gd -- planes` at `--resolution 810x1440`: the harness taps
a free plane picked for the shortest flight **among those whose launch also
wakes another** (`_tap_planes`/`_wakes` in the harness, played and undone on
the state before the real tap, never on the board), so one tap shows both
signature moves rather than an isolated dart. Three separate runs (a fourth
was needed for the phone-driver check below) read **55, 55 and 55** draw
calls, with idle means of **2.13, 2.07 and 1.98 ms**. Word Trail, run as the
control in the same session immediately after the first two, read **65**
draw calls and a **2.30 ms** idle mean -- both a little over the 60-65
draw calls and 2.37-2.51 ms its own spec recorded, which is the run-to-run
spread this Mac always shows on this harness and exactly why a single
reading is worth nothing (Hidden Word's spec, section 9). Paper Planes reads
under Word Trail by a wide margin in both sessions, so the comparison holds
even though neither board's absolute number repeats to the millisecond:
**Paper Planes is the cheapest board in the game**, exactly as predicted,
both against Word Trail and against the 855 budget.

On the phone's driver (`--rendering-driver opengl3_angle`): the same **55**
draw calls, and the settled frame (the sixth shot, t=3.8 s) matches the
default driver's to a **max channel delta of 1** across 91,782 of the
frame's 1,166,400 pixels -- edge antialiasing dither between the two
backends, the same class of difference Sudoku's and Word Trail's own phone
checks recorded, and not the much larger, scattered errors a garbage
`instance uniform` would leave.

The first screen (`tests/_shot_menu.gd`): page one still reads **335** draw
calls, the same figure Task 3 recorded with the fifteenth card's picture
stubbed empty, because the card stands on page two and costs page one
nothing (section 12). Page two, with all three of its cards now drawing a
real picture, reads **175** against Task 3's **127** -- checked by
temporarily stubbing this board's own `_draw` arm back to a no-op and
re-measuring, which read exactly 127 again, so the **+48** is Paper Planes'
own picture (the dot lattice, three trails and three darts) and nothing
else moved.

## 16. Open questions

1. **Is 58 px too dense to read on the phone?** The reference does the same
   thing at 32 px on a smaller screen, so the answer is probably no, but the
   hard band is the one to look at on the device before it is called done.
2. **Does the wake earn its cost?** It is the one piece of motion that is not
   load-bearing. If it reads as noise on a 50-plane board, it is the first
   thing to cut, and cutting it costs one function.
3. **Should a blocked tap say more than the flash?** The tip card takes the
   line today. If playtesting shows people tapping the same blocked plane
   repeatedly, the second refusal of the same plane could ring the blocker
   instead -- but that is a change to make with a reason, not in advance.
