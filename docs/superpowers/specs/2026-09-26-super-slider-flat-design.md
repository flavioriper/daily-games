# Super Slider, flat: the twenty-fifth board

A walnut tray of painted wooden blocks on a lawn. **Slide the blocks round
the tray until the big red one walks out of the gate** in the middle of the
bottom edge. Drag a block and it follows the finger through the empty cells,
round corners too, never over another and never lifted.

The reference is the handheld the user brought on 2026-09-26 (a photo of the
box and the console): a 4x5 tray, one red 2x2 block, blue 1x2 bars standing
or lying, yellow 1x1 squares, and a green sensor zone at the bottom centre.
It is the old 4x5 sliding-block family (Huarong Dao, Pennant, L'Âne rouge),
and the handheld deals five hundred layouts of it. The user named the card
**Super Slider**; the handheld itself sells as *Super Slide*, one letter
away, so the name is the user's call to keep or change (one string in
`ui/registry.gd` and `title()`).

Built in one sitting while the user was away, from the photo and the
published rules, without a concept tab in `docs/brainstorm/concepts.html`
first -- the one step of the usual order skipped, recorded here so it is not
read as an oversight.

---

## 1. What is built

| File | What it is |
| --- | --- |
| `puzzles/slider_gen.gd` | The solver: a position as one int, moves, the whole-graph distances, the bank's deal. Scene-free. |
| `puzzles/slider_state.gd` | The rules: blocks, steps, undo, reset, hint off a worker thread's distances, solved. Scene-free. |
| `puzzles/slider2d.gd` | The board: two meshes, the drag, the settle, the count line, the gate. |
| `ui/faces/slider_block.gd` | The drawing -- tray, gate, mat, doors, blocks -- shared by the board and its menu card. |
| `tools/mine_slider.gd`, `tools/merge_slider.py` | The bank's miner and its merge. |
| `content/slider.json` | The bank: trays by band, each with its shortest way out. |
| `core/palette.gd` | The tray's colours (`SLIDE_*`). |
| `ui/registry.gd`, `locale/boards.csv`, `ui/menu/vistas.gd`, `ui/menu/card_art.gd` | The card: entry, strings (en/pt-BR/es), banner vista, picture. |
| `tools/gen_sfx.py`, `assets/sfx/slider/` | Eleven cues, one take each. |
| `tests/_win.gd`, `tests/_shot_anim.gd`, `tests/_probe_slider.gd` | The harness hooks and the solver probe. |

## 2. The rules

- **The tray** is 4 wide and 5 tall. The gate is the bottom edge's middle two
  columns; the day is done when the big block's four cells are the bottom
  two rows of those columns.
- **The one move** is dragging a block: it slides a cell at a time through
  empty cells and may turn corners in the same drag. **One drag is one
  move** however far it goes, which is the family's traditional metric (the
  classic layout's 81 is counted in it).
- Nothing wrong can sit in the tray, so there is **no Check**, no tray row and
  no actions row: Undo, Reset and Hint ride in the top bar
  (`"tray": "none"`, `"actions": false`) -- Pinwheel's shape.
- **A hint plays the next move of a shortest way out** from wherever the
  player is, sliding its block along its path; it counts no move. Three a day.
- The line over the tray counts moves against the day's shortest; the win
  line says both.

## 3. The solver

A position is one int: twenty cells of three bits, each naming what part of
what shape sits there (`E`, `SQ`, `V0`/`V1`, `H0`/`H1`, `B0`/`B1`). Two bars
of a shape are therefore the same position whichever is which, as the player
sees it, and the int is the visited set's key. A block's contribution to the
key at each anchor is tabled once, so a neighbour is `key - here + there`.

`distances(start)` walks the start's whole graph breadth-first (moves
reverse, so the graph is every position the day can reach), then runs a
second breadth-first pass from every goal position over the stored edges, so
**every position's distance to the gate is known at once**. A hint is a
lookup: any move to a position one nearer. Checked against the literature on
the classic layout: **25,955 positions, 81 moves** -- both exactly the
published figures. The walk's neighbours come from `_next_keys`, which keeps
occupancy as a 20-bit mask and floods each block through one reused queue, so
a position allocates nothing: that took the classic graph from 966 ms to
**315 ms on this Mac**, and the largest graph the bank ships (105,064
positions) to **1.2 s**. A phone is plausibly two to three times slower; it
is unmeasured.

The phone runs it once a day on a `WorkerThreadPool` task started as the tray
opens, into a box the task keeps its own reference to; the board waits for it
(`finish()`) as it leaves. A hint pressed before it is done waits for it.

## 4. The deal

Mined on the Mac, never grown on the phone. `tools/mine_slider.gd` fills
random trays (the big block anywhere off the gate, then bars and squares in
reading order, exactly two cells empty), skips graphs over 120,000 positions
(a hint runs over the whole graph on the phone), and keeps positions whose
distance falls in a band -- two a band a graph, and for Insane up to four
within six moves of the graph's farthest. Positions are written canonical
(the lesser of a tray and its mirror); the phone deals a mirror half the days.
`tools/merge_slider.py` dedups across bands and thins each to a fixed shuffle.

| Band | Shortest way out | Trays |
| --- | --- | --- |
| Easy | 8-16 | 300 |
| Medium | 20-34 | 300 |
| Hard | 38-56 | 280 |
| Insane | 60-138 | 189 |

Insane saturated first: the deepest positions cluster in a few large graphs,
so later graphs mostly repeated trays already kept. The mine was about forty
minutes of seven processes on this Mac.

With no bank on disk every band deals the classic layout (81), so the board
always opens.

## 5. The drawing

Two meshes: **still** (the lawn with faint mown stripes and tufts, the path of
stepping stones out of the gate, the tray) rebuilt on a relayout only, and
**live** (the mat's glow, the blocks, the gate's doors) rebuilt only while
something moves -- an idle tray rebuilds nothing. The blocks keep the
handheld's carvings in the house's soft cel: the big block has a face and a
double chevron pointing at the gate, a bar a carved slot, a square a carved
cross and boss. The card clips (`clip_contents`), because the big block walks
out past the frame on the win.

## 6. The motion

The held block lifts (a longer shadow and a small rise), follows the finger a
cell at a time -- the longer way first, round a corner when that way is shut
-- and leans up to half a cell toward an open way and `RUBBER` 0.07 toward a
shut one, knocking once (`bump`). Let go, it settles onto its cell on
`back_out` over `SNAP_TIME` 0.16 and dips (`LAND` 0.08 over `LAND_TIME`
0.22) with a puff. A hint's or an undo's block slides its path at
`SLIDE_SPEED` 7 cells a second; a reset sends every block straight home on
`RESET_STAGGER`. The entrance pops the blocks in on the house stagger.

The win: the big block lands, the mat lights (`GLOW_TIME` 0.3, a GOOD ring),
the doors fold back (`DOOR_TIME` 0.35, the `gate` cue and a puff), and the big
block, face to JOY, walks `EXIT` 1.8 cells out of the gate over `EXIT_TIME`
0.85 while the others hop in a wave from the gate; the win screen waits
`WIN_HOLD` 0.9 past that.

## 7. Figures

Measured with `tests/_shot_anim.gd -- slider` at `--resolution 810x1440`,
2026-09-26: **67** draw calls bare and with a block dragged and landed, 67
held mid-drag (`hold`), up to 89 across the win (the ring, puffs and
sparkles), and **68 on ANGLE** (`--rendering-driver opengl3_angle`). The
idle read 3.95-4.45 ms in sessions shared with the miners, so the
milliseconds are not quotable; an idle tray rebuilds no mesh. The menu's
last page, which holds this card alone at 1080x1920, reads 108.
`tests/_win.gd -- slider` (the harness now takes board ids after `--`)
solves Medium by one HUD hint and real drags, fit and HUD both true.
`tests/_probe_slider.gd` deals three days a band, checks every par against
the solver, plays each out by hints with an undo and a reset on the way:
`bad=0`. The suite: 122,591 passed, 0 failed.

Owed: a listen to the eleven sounds (one take each), the hint's wait on a
real phone for a 100k-position Insane graph, and the user's call on the
name.

## 8. Polish (amendment, 2026-09-26)

Asked for as "polish and improve design and animation", built directly.

**The drawing.** The lawn gets a bush tucked into each corner, clover,
tufts and daisies off the tray and the path, and stepping stones with a lit
top and a tuft beside them, running to the card's hem. The walnut frame
carries wavy grain down all four sides and two knots, and a brass peg at
each corner joint; the floor has a faint speckle, and every empty cell is a
shallow hollow (in the live mesh, since the holes move). The gate's doors
are planks with a hinge strap and a brass latch knob, and they ride up as
they fold back. Each block carries a faint grain along its long way; a lifted
block casts a second, spreading shadow and takes a sheen. The lit mat
breathes a halo past its edge (`SLIDE_MAT_HI`). New palette entries:
`SLIDE_STONE_HI`, `SLIDE_MAT_HI`, `SLIDE_BRASS(_HI)`, `SLIDE_CLOVER`,
`SLIDE_BUSH(_HI/_DEEP)`.

**The motion.** The held block's drawn anchor chases the finger's at
`FOLLOW` 28 a second, so a step between cells glides instead of snapping,
and its speed leans it along its travel (`LEAN_PER` 0.012 a cell a second,
at most `LEAN_MAX` 0.07: the leading edge runs ahead, the sides draw in). A
step kicks a wisp of dust off the trailing edge. A knock into a wall or a
block shivers the block (`KNOCK` 0.035 of a cell over `KNOCK_TIME` 0.24),
and the block in its way flinches (`FLINCH` 0.03). The big block watches the
held block, its face moving up to `GAZE` 0.07 of a cell, looks worried when
it is itself knocked, looks down at the gate once solved, and blinks every
2.8-5.5 s (the live mesh rebuilds only for the blink). The blocks drop in
`ENTER_DROP` 0.35 of a cell as they pop in. A hint leaves a dotted trail in
`SUN` down its path, drawn a beat ahead of the block and faded over
`TRAIL_FADE` 0.6. On the win the big block walks out in `EXIT_STEPS` 3 hops,
each landing with a squash and a puff on the stones, and a sparkle rises
over each other block as its hop comes round.

**Figures** (`tests/_shot_anim.gd -- slider` at 810x1440): 68 draw calls
played (67 before), 67 held (`hold`), up to 72 across the win, 67 on ANGLE;
idle 3.73 ms against 3.95 before, in the same session. Under `rm` two frames
1.5 s apart are pixel-identical. `tests/_win.gd -- slider` passes; the suite
122,591/0.
