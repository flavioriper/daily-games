# Pipes, rebuilt as an island of blocks

*Design, 2026-09-15. Grown out of the concept page
(`docs/brainstorm/concepts.html`, the Pipes tab, concept of the same day) with
every open decision closed in the way that page recommended. The reference
picture is `docs/art/concept-pipes-iso.png`.*

Pipes today is a flat five-by-seven field of pads: every cell already holds a
piece and the whole puzzle is turning each one until nothing leaks. It works,
and it is the one board in the game with no decision in it -- there is exactly
one right angle per cell and the player finds it by exhaustion.

This replaces it. The board becomes a floating voxel island seen from the
corner. Water starts in a tank on a high block and has to reach a pool at the
drain. The player *builds* the pipeline out of a tray of pieces, over ledges
and down cliff faces. Water runs level and downhill on its own; every climb
needs a pump. Tall ground hides part of the route from any one side, so
turning the island is part of the puzzle.

The puzzle id stays `pipes`, so progress and analytics carry on, and the old
board's water, leak jets and flood wave carry over with it -- they were the
good part.

## 0. What is replaced, and what is kept

| | |
|---|---|
| **Gone** | `puzzles/pipes3d.gd` (the pad board), `puzzles/pipes_gen.gd` (the spanning-tree scrambler), the `pipe_cross` piece from the tray, the Check button on this board |
| **Kept as is** | the five pipe models and the `valve`, `pipe_pad`, the `pipe_flow` shader and `Toon.pipe_flow()`, `Fx`'s jets, puffs and sparkles, the HUD, the toon and outline shaders |
| **New code** | `puzzles/pipes_iso_gen.gd`, `puzzles/pipes_iso.gd`, `ui/hud/piece_tray.gd`, four piece icons in `ui/icons.gd`, orthographic fit and a tweened turn in `world/camera_rig.gd`, a ghost variant of the toon shader for peek |
| **New models** | `block`, `pump`, `source_tank`, `drain_pool` |

`pipe_cross` keeps its model, its slot and its contract row: with one source
and no loops a cross never appears in a solution, so it is not in the tray, and
it comes back for nothing the day loops or two sources do.

## 1. The grid

Columns are indexed `(x, z)`, `x` across and `z` toward the player, the same
way every other board indexes `(col, row)`. Each column has a **height** in
`1 .. levels`: blocks fill the levels `0 .. height - 1`, and the air cell
resting on the column's crown is at level `height`.

A **cell** is a `Vector3i(x, y, z)`. It is *air* when `y >= height[x][z]`, and
its world position is `BoardMath.cell_center(z, x, cols, rows, y)` -- one
world unit per level, because a block is a unit cube.

A piece's **hub** -- the point its arms radiate from, and the only point that
has to line up for two pieces to meet -- sits `Placeholders.TUBE_Y` (0.175)
above the cell's own floor. That is exactly where the hub of a pipe piece
resting on a 0.175-high floor sits today, and it means two cells one level
apart have hubs exactly one unit apart, which is what a vertical run needs: an
arm is `ARM_LEN` (0.498) long, so two facing arms meet with 0.004 between
them. **A piece is therefore mounted on a pivot at the hub**, with the model
hung at `-TUBE_Y` under it, and the pivot carries the orientation. Nothing
else in the board needs to know how a pipe is modelled.

## 2. Mouths, kinds and orientation

Six directions, as bits, with the same names the board and the generator use:

| bit | 1 `N` | 2 `E` | 4 `S` | 8 `W` | 16 `U` | 32 `D` |
|---|---|---|---|---|---|---|
| world | -Z | +X | +Z | -X | +Y | -Y |

The five kinds the tray can hold, with the mouth set each model carries as
modelled (`REFERENCE`, which must keep agreeing with `core/placeholders.gd`
and `art/pipes.blend`):

| kind | slot | modelled mouths | distinct orientations |
|---|---|---|---|
| `straight` | `pipe_straight` | `N \| S` | 3 (along X, along Z, vertical) |
| `elbow` | `pipe_elbow` | `N \| E` | 12 |
| `tee` | `pipe_tee` | `N \| E \| S` | 12 |
| `pump` | `pump` | `U \| D` | 1 |
| `source` / `drain` | `source_tank` / `drain_pool` | `N` | 4 (the generator fixes it) |

Orientation is **a rotation, not a quarter turn**: the board holds the 24
axis-aligned rotations with determinant +1 as `Basis` values, and a piece's
orientation is whichever of them maps its kind's modelled mouth set onto the
mouth set the cell wants. `rotate_mask(mask, basis)` maps each bit's direction
vector through the basis and reads the bit back, so one function covers every
kind and every axis. The distinct orientations of a kind are the distinct
images of its reference set under those 24 rotations, generated rather than
tabulated -- a tabulated list of twelve elbow orientations is a list nobody
can check.

## 3. Rules

1. **Place, don't turn.** The board starts with the terrain, the source and
   the drains. The player places pieces from a tray; each kind has a count.
2. **Water cannot climb.** From the source it runs through every connected
   mouth along the level and down any drop. It goes up a vertical run only
   when that run contains a pump.
3. **A vertical run** is a maximal stack of pieces joined by up/down mouths.
   If any piece in it is a pump, water climbs the whole run. Two separate
   climbs need two pumps.
4. **Standing.** A piece must rest on the ground -- the cell directly below it
   is a block -- *unless* it has an up or a down mouth, in which case it may
   hang in a vertical run. Bridges through the sky are impossible; drops and
   climbs are not.
5. **A leak** is a fed mouth that faces nothing, faces the ground, or faces a
   piece with no mouth on that side. It pours. Leaks are a clue, not a
   failure: the board shows at most four at once, the ones nearest the source
   first.
6. **Solved** when water reaches every drain and no fed mouth leaks. Pieces
   left in the tray are fine; dry, disconnected pieces are fine too -- they
   just do not count.
7. **The source's height is not a limit** beyond rule 2: water that has
   dropped into a valley cannot come back up without a pump, even to a level
   below the source.

Rule 5 is taken literally, including upward mouths: a fed mouth pointing at
open sky pours like any other. It is one rule instead of two, it is visible,
and the only state it forbids is an untidy one.

## 4. The water

Flow is a breadth-first search from the source over placed pieces. Two pieces
connect when each has a mouth facing the other. A step along the level or
downward is free; a step upward is taken only when the vertical run that step
belongs to holds a pump. Every fed piece keeps its search depth, so the
wetting wave races outward from the source instead of arriving everywhere at
once -- the same `_flood` shape the pad board used, with the same
`FLOW_STEP` / `FLOW_CAP` staggering measured from the shallowest newly-wet
depth.

Per fed piece the board drives the three surfaces the pad board drove: `Steel`
tinted from `STEEL` to `PIPE_WET`, `Collar` from `STEEL_HI` to `PIPE_WET_HI`,
and the instance's own `pipe_flow` material's `wet` uniform from 0 to 1, all
on one eight-step tween so the toon cache stays bounded.

A drain fills when the water arrives: its basin turns from dark to
`WATER`, ripples, and the win chord plays when the last one fills.

## 5. Interaction

**Placing.**

1. Tap a piece in the tray to select it. The selection survives a placement,
   so straights chain.
2. **Tap an open mouth** -- on the source, or on any placed piece -- to place
   the selected piece in the cell that mouth faces, already turned to connect.
   This is the main gesture and the only way to reach a cell that hangs: to
   build a drop, tap the down mouth of the elbow over the edge, then the down
   mouth of the piece that appears, and so on.
3. **Tap a block top** to place the selected piece on that floor cell,
   unconnected, in the kind's first flat orientation. For starting a stretch
   early, or laying pieces near a drain and working back.
4. **Tap a placed piece** to cycle its remaining valid orientations. A piece a
   hint placed does not turn.
5. **Long-press a placed piece** (0.45 s) to send it back to the tray. Its
   downstream pieces stay where they are and go dry.

**Picking.** A tap casts a ray and tests it against two things: the small
sphere at every open mouth (radius 0.16) and the crown of every column
(a unit square at the column's own height). The nearest hit wins, mouths
breaking a tie, because a mouth sphere hovering over its own block's crown
must be reachable. Plane picking cannot be used at all here: cells sit at many
heights, so there is no one plane to intersect.

**Looking.**

* **Turn** -- the cube button, or a horizontal swipe on empty ground: one
  quarter turn, 0.35 s, eased. Four stops.
* **Peek** -- the eye button, held: the ground fades to 35% so the pipes
  behind it show. Pieces stay solid and tappable. Released, it fades back.
* **Undo** reverses a place, a turn and a removal. **Hint** (3) places the
  next piece of the generator's route, from the source outward, locked and
  tinted as a given. **Reset** returns every piece to the tray and turns the
  view back to the first stop.
* **No Check button.** The water is the check.

**Analytics.** The existing board events carry on. Two new ones, so we learn
whether the third dimension is a puzzle or a nuisance: `view_turn` (per turn,
carrying the stop it landed on) and `peek_used` (per press).

## 6. The camera

* **Orthographic**, for this board only; every other board keeps the
  perspective rig untouched. Parallel edges are what make blocks read as a
  diorama.
* **Pitch 35 degrees, yaw 45 + k * 90.** Four stops.
* **One size for all four stops.** The fit takes the largest vertical extent
  the board's box projects to over the four yaws and uses it at every stop, so
  the island does not breathe in and out as it turns. The fit is analytic, not
  a binary search: an orthographic projection is linear, so the size falls out
  of the box's extent in camera space and the board slot's pixel size in one
  step, and one centring pass puts the box's centre on the slot's centre.
* **The board box** is `cols x (levels + 2) x rows`, taken from the terrain
  rather than from the pieces, so the framing does not jump when a piece is
  placed high.
* `board_projection()` and `board_yaw()` join `board_pitch()` on
  `PuzzleBase3D`; `Stage.fit_camera` passes them through. A board that does
  not override them gets exactly what it gets today.

## 7. The terrain

* **Blocks are unit cubes**, two layers: `Block_Earth` and `Block_Grass` (the
  crown). A column's crown is grass, or the pale stone of a pad where a piece
  stands, or the given colour where a hint placed that piece.
* **Merged, not instanced.** A six-by-six board five levels tall is up to 180
  cubes and twice that in draw calls. The board merges every block's earth
  layer into one mesh and every crown into one of three (grass, stone, given),
  so the whole island is four meshes and an outline shell each. Merging
  happens on build and again when a crown changes colour, which is rare (a
  placement or a hint, not a frame).
* **Peek** swaps the merged ground's materials for the ghost variant while the
  button is held and puts them back on release. Nothing else changes.
* The stage's sea and sky stay where they are: an island of blocks floating
  over water is the picture.

## 8. The generator

`pipes_iso_gen.gd`, headless and pure, in the order the concept page settled.

1. **Route first.** Pick a source column and a drain column far apart. Walk a
   self-avoiding route in three dimensions from one to the other:
   * a **horizontal** step moves to a neighbouring column and fixes that
     column's crown at the current level;
   * a **drop** of `k` steps into a neighbouring column: the cell above that
     column at the current level hangs with a down mouth, `k - 1` vertical
     straights hang under it, and the cell on the column's crown takes an
     elbow with an up mouth;
   * a **climb** of `k` steps is the same upside down, and exactly one of its
     vertical straights becomes the **pump**.
   The difficulty says how many climbs and how long the route may be.
2. **Kinds from the route.** An interior route cell's mouths are the reverse
   of the step that arrived and the step that leaves: two opposite mouths make
   a straight, two adjacent an elbow. The first cell is the source fixture and
   the last is a drain.
3. **A second drain** (hard only) grows a branch off a random interior route
   cell, which becomes a tee. The branch walks level and downhill only -- no
   pump -- so it needs no second climb to be solvable.
4. **Terrain from the route.** Every column the route touches takes the lowest
   route cell over it as its height, which is the same rule for a horizontal
   cell (its own floor) and for the foot of a drop or a climb. Every other
   column gets a random height, smoothed toward its neighbours. Then a few
   extra ledges are raised at random, never into a route cell, so the ground
   is interesting where the route is not.
5. **Occlusion check.** From the first camera stop, at least the difficulty's
   number of route cells must be hidden behind taller ground. Hiddenness is
   measured by marching from the cell toward the camera and asking whether the
   ray passes under a column's crown -- exact enough for a heightfield, and it
   runs headless. Otherwise the terrain is re-rolled.
6. **Tray.** The route's pieces counted per kind, plus the difficulty's
   spares drawn from the kinds already there. Spares are decoys: they make
   "use everything in the tray" useless as a strategy.
7. **Verify.** Run the board's own flow over the route: every drain fed, no
   leaks, every piece standing legally, every climb pumped. Regenerate on
   failure, and give up after a bounded number of attempts with `ok = false`,
   the way `horse_gen` does.

| | Easy | Medium | Hard |
|---|---|---|---|
| Columns | 4 x 4 | 5 x 5 | 6 x 6 |
| Height levels | 3 | 4 | 5 |
| Drains | 1 | 1 | 2 |
| Climbs (pumps) | 0 or 1 | 1 | 1 or 2 |
| Route pieces | 5 to 8 | 8 to 12 | 12 to 18 |
| Spare pieces | 0 | 1 | 2 |
| Hidden route cells | 0 | 1 | 2 |

## 9. Models

Four new slots, modelled in `art/pipes.blend` beside the five pipe shapes and
run through the contract check.

| slot | footprint | height | layers |
|---|---|---|---|
| `block` | exactly 1.0 x 1.0 | 1.0 | `Block_Earth` (`Earth`), `Block_Grass` (`Grass`, the crown the board tints) |
| `pump` | 1.0 x 1.0 | 0.38 | `Pump_Shell` (`Steel`), `Pump_Collar` (`Collar`), `Pump_Water` (`Flow_flat`), `Pump_Housing` (`Brass`), `Pump_Ring` (`Lit`) |
| `source_tank` | 1.0 x 1.0 | 0.6 | `Tank_Body` (`Stone`), `Tank_Orb` (`Glass`), plus the three pipe layers on its one arm |
| `drain_pool` | 1.0 x 1.0 | 0.3 | `Pool_Rim` (`Stone`), `Pool_Water` (`Water_flat`, dark until fed), plus the three pipe layers on its one arm |

The pump carries the pipe piece's own three layers so the flood wets it like
any other piece, and adds a brass housing and a collar the board lights when
the run is climbing. The source and the drain each carry one arm's worth of
pipe so the mouth the player taps looks like a mouth.

`block` is exact, not budgeted: the board tiles it edge to edge in three
dimensions, and a block 0.98 across would leave a seam of sky in every wall.

## 10. Build order

Three sub-projects, in this order, each landing on `feat/pipes-iso`:

1. **Rules and generator.** The grid, the mouth and orientation maths, the
   standing rule, flow with pumps, the route/terrain/tray generator and the
   verifier. Headless; drives everything else. The board runs on placeholders
   before any of the art exists.
2. **The island and the interaction.** Orthographic fit and turn on the rig,
   the merged ground, ray picking, tap-a-mouth placement, orientation cycling,
   long-press removal, the piece tray, peek, undo, hint, reset.
3. **Art and motion.** The four models through the contract; the water and the
   leak jets carried over; the entrance (the island rises, blocks pop in by
   height, the tank lights, the tray slides in) and the win (the drains
   ripple, the pumps whir, the camera turns once slowly).

**Scenery is deferred**, as on every other board: no trees, lanterns, fences,
waterfalls or bird in the first cut. The island's silhouette and the water
below are the scene.

## 11. Verification

* The suite stays green, `tests/test_pipes.gd` rewritten around the new
  generator's invariants (the old file tested a scrambler that no longer
  exists).
* `tests/_win.gd`'s `_solve_pipes` replays the generator's route through the
  same tap-a-mouth path a player uses, so the harness proves the gesture, not
  just the rules.
* `tests/_shot.gd` windowed for the look, `tests/_shot_anim.gd -- pipes` for
  the entrance, the idle frame time and the draw calls. The ceiling is the
  855 draw calls Code Break's screen set.
