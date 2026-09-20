# Fairy Lights, flat: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship Netwalk as the fifteenth flat board -- a garden of fairy lights
where one tap turns a length of wire a quarter turn clockwise until every
paper lantern is lit.

**Architecture:** Three scene-free layers and one scene, the shape every flat
board here takes. `fairy_lights_gen.gd` grows the day's spanning tree, proves
it needs no guess, and scrambles it; `fairy_lights_state.gd` owns the moves
and the derived live set; `fairy_lights2d.gd` draws one `ArrayMesh` for the
wire and seats `lantern_face.gd` Controls in slots for the lights. The chrome
is the host's, unchanged, through one registry line.

**Tech Stack:** Godot 4.7, GDScript, gl_compatibility. No new palette colour,
no new face, nothing new in `core/motion.gd`.

**Spec:** `docs/superpowers/specs/2026-09-20-fairy-lights-flat-design.md`

**Mock, and the reference for every number:**
`docs/brainstorm/concepts.html#fairylights` -- it runs the real generator and
the real solver. Read the tab before starting a task; port from it rather than
re-deriving.

## Global Constraints

- **Worktree:** all work happens in
  `/Users/flavioriper/dev/daily/.claude/worktrees/fairy-lights` on branch
  `feat/fairy-lights`. Never touch `.claude/worktrees/bridges`,
  `.claude/worktrees/rings` or `.claude/worktrees/planes` -- other agents are
  live in them. Never `cd` out of this worktree.
- **Shared files also being edited on other branches:** `ui/registry.gd`,
  `ui/menu/card_art.gd`, `tests/run_tests.gd`, `tests/_win.gd`,
  `tests/_shot_anim.gd`, `docs/art/flat-motion.md`, `CLAUDE.md`. Make the
  smallest possible edit to each.
- **Ids and names:** registry id `fairylights`, title `Fairy Lights`, motto
  `WAKE EVERY LANTERN`. Files `puzzles/fairy_lights_gen.gd`,
  `puzzles/fairy_lights_state.gd`, `puzzles/fairy_lights2d.gd`,
  `tests/test_fairy_lights.gd`.
- **Never call the board anything but Fairy Lights** on screen or in code.
  Netwalk may be named in a design doc; it is not a product name here.
- **A render harness runs at `--resolution 810x1440`, never `1080x1920`**, and
  `--resolution` is an engine flag that must come **before** `--script`. After
  the `--` it is handed to the script instead and the run silently falls back
  to a 1237-wide canvas.
- **Never run two windowed render harnesses at once** -- GPU contention
  inflates the milliseconds. Take two sequential readings of anything timed,
  and quote both.
- **Never claim a measurement that was not taken.** Every figure in the spec's
  section 11 is filled from a run whose command is written down beside it.
- **The suite must stay green:** `godot --headless --path . --script
  tests/run_tests.gd` reports `0` failures before any commit that touches
  running code.
- **Cells abut.** There is no gap between cells on this board; the cell is
  `floor(944 / n)` with nothing subtracted.
- The ladder is easy 5x5, medium 6x6, hard 7x7.

---

## File structure

| File | Responsibility |
| --- | --- |
| `puzzles/fairy_lights_gen.gd` (create) | Masks and turning; randomised Prim tree; propagate-only solver; the scramble and its two conditions; the day's `build()`. Knows nothing about scenes. |
| `puzzles/fairy_lights_state.gd` (create) | The board's moves -- turn, undo, hint, reset -- and everything derived from them: matched edges, the live set with depths, solved. Knows nothing about scenes. |
| `puzzles/fairy_lights2d.gd` (create) | The `PuzzleBase` subclass: layout, the one `ArrayMesh`, the lantern slots, the gestures, the wash, the win. |
| `tests/test_fairy_lights.gd` (create) | The generator's promise and the state's moves. |
| `ui/registry.gd` (modify) | One entry after Sudoku. |
| `ui/menu/card_art.gd` (modify) | One `_build` branch, one `_draw` branch. |
| `tests/run_tests.gd` (modify) | One line registering the test file. |
| `tests/_win.gd` (modify) | A solver and a status line for this board. |
| `tests/_shot_anim.gd` (modify) | One tap script for the strip. |
| `docs/brainstorm/concepts.html` (modify, Task 1 only) | The deal's live cap, so the mock stays the reference. |
| `docs/art/flat-motion.md`, `CLAUDE.md`, the spec (modify, Task 7) | The record. |

---

### Task 1: The generator, its solver, and the promise

**Files:**
- Create: `puzzles/fairy_lights_gen.gd`
- Create (throwaway): `tests/_probe_fairy_gen.gd`
- Modify: `docs/brainstorm/concepts.html` (the deal's live cap only)

**Interfaces:**
- Consumes: nothing.
- Produces, all `static`:
  - `N := 1`, `E := 2`, `S := 4`, `W := 8` (side bits, clockwise from north)
  - `cw(m: int) -> int`, `ccw(m: int) -> int`
  - `rotations(m: int) -> Array` -- the distinct rotations of a mask
  - `solvable(n: int, sol: PackedInt32Array) -> bool` -- the propagate-only solver
  - `build(rng: RandomNumberGenerator, difficulty: int) -> Dictionary`, keys
    `n: int`, `post: int`, `sol: PackedInt32Array`, `deal: PackedInt32Array`,
    `attempts: int`, `proved: bool`
  - `SIZES := [5, 6, 7]`, `BUDGET := 400`

- [ ] **Step 1: Read the mock's generator**

Open `docs/brainstorm/concepts.html#fairylights` and read the IIFE at the end
of the page's one big `<script>`. Its tree growth, its solver and its
acceptance test are the algorithm; port them, do not re-invent them. Read
section 4 of the spec beside it.

- [ ] **Step 2: Write the failing test**

Create `tests/test_fairy_lights.gd` with the generator's half only (the
state's half arrives in Task 2). Follow the shape of `tests/test_sudoku.gd`
for how a test file declares itself to the runner.

```gdscript
# 1. Turning four times is the identity, and cw/ccw are inverses.
# 2. Every band builds: n is 5/6/7, sol.size() == n*n, post is in range.
# 3. The solution is a tree: exactly n*n-1 edges, every cell reachable
#    from post, and no cell has a stub pointing off the grid.
# 4. Every board over 40 seeds a band comes back proved == true, and
#    solvable() agrees when handed the solution back.
# 5. The deal is a rotation of the solution, cell for cell: for every i,
#    deal[i] is in rotations(sol[i]).
# 6. The deal is not the solution: at least 60% of turnable pieces differ.
# 7. The deal leaves at most 25% of cells live.
# 8. The same seed twice is the same garden, and two seeds differ.
```

- [ ] **Step 3: Run it and watch it fail**

Run: `godot --headless --path . --script tests/run_tests.gd`
Expected: the file does not load / `fairy_lights_gen.gd` not found.

Register it first in `tests/run_tests.gd`, one line beside `"sudoku"`:
`"fairylights": "res://tests/test_fairy_lights.gd",`

- [ ] **Step 4: Write the generator**

Port from the mock. The load-bearing parts, each of which the spec argues:

- **The tree is randomised Prim**, not DFS. DFS is almost always guess-free
  first try but grows corridors -- 13.6-17.1% of cells as lanterns, a snake
  of wire. Prim branches and costs a re-roll about a quarter of the time.
- **The solver never branches.** Each cell starts with `rotations()` of its
  own shape. Strike out any candidate with a stub pointing off-grid. Whenever
  every remaining candidate of a cell agrees about a side, that edge is
  proven, and the neighbour's candidates are filtered to match. Iterate to a
  fixpoint. Every cell down to one candidate means guess-free.
- **The acceptance test is three conditions on the tree**, before any
  scramble: `solvable()`, at least 22% of cells degree-1, and the post with at
  least two arms.
- **`BUDGET` is 400 attempts** and past it the last tree grown is shipped with
  `proved: false`. It has never been reached; it exists so a pathological seed
  cannot hang `build()`.
- **The scramble has two conditions**, each re-rolled: at least 60% of
  turnable pieces out of place, and **no more than 25% of cells live at the
  deal** (spec 4.5 -- this one is new and is not in the mock yet; Step 7 adds
  it there). Cap the re-scramble loop at 200 tries and take the best seen
  rather than looping forever.
- Everything comes off the `rng` handed in and nothing else, so a day is the
  same garden on every phone.

Write it over `PackedInt32Array`, with the file header comment in this repo's
voice: what the file owns, why Prim rather than DFS, and the spec section.

- [ ] **Step 5: Run the tests**

Run: `godot --headless --path . --script tests/run_tests.gd`
Expected: the new assertions pass, total failures `0`.

- [ ] **Step 6: Measure it in GDScript and record the reading**

Write `tests/_probe_fairy_gen.gd` as a throwaway `SceneTree` script (run its
assertions from `_process`, not `_initialize` -- `_ready` is deferred
headless). Over **200 seeds a band** report: mean and worst attempts, mean and
worst wall-clock milliseconds for the whole `build()`, and the fraction
`proved`. Run it twice and quote both.

Run: `godot --headless --path . --script tests/_probe_fairy_gen.gd`

This replaces the spec's estimate in section 4.3, which was scaled off
JavaScript and is explicitly labelled as not a reading. If the worst case is
past ~50 ms, say so loudly in your report -- it changes nothing about the
design but it belongs in the record.

- [ ] **Step 7: Teach the mock the live cap**

In `docs/brainstorm/concepts.html`, add the same 25%-live condition to the
mock's scramble, and add one sentence to the tab's section 4 saying the deal
is capped so the garden opens dark. The page is the reference; it must not
drift from the board.

Re-shoot the tab to confirm it still plays. Headless Chrome at 2x, crop with
PIL from this worktree; delete any stale `--user-data-dir` profile before each
shot or Chrome hangs, and note that exit code 124 does not mean there is no
image -- Chrome sometimes writes the PNG and then hangs on exit.

- [ ] **Step 8: Commit**

```bash
git add puzzles/fairy_lights_gen.gd tests/test_fairy_lights.gd tests/run_tests.gd tests/_probe_fairy_gen.gd docs/brainstorm/concepts.html
git commit -m "feat(fairy-lights): the day's garden, proved to need no guess"
```

---

### Task 2: The state

**Files:**
- Create: `puzzles/fairy_lights_state.gd`
- Modify: `tests/test_fairy_lights.gd`

**Interfaces:**
- Consumes: all of Task 1's statics.
- Produces (an instance, `extends RefCounted`):
  - `var n: int`, `var post: int`
  - `var grid: PackedInt32Array` -- what is on the board now
  - `var deal: PackedInt32Array`, `var sol: PackedInt32Array`
  - `var pinned: PackedByteArray` -- 1 where a hint settled a cell
  - `var turns: int`, `var hints: int`
  - `const OK := 0`, `const CROSS := 1`, `const PINNED := 2`
  - `func start(rng: RandomNumberGenerator, difficulty: int) -> void`
  - `func turn(i: int) -> int` -- one of the three codes
  - `func undo() -> int` -- the cell turned back, or -1
  - `func hint() -> int` -- the cell settled, or -1
  - `func reset_board() -> void`
  - `func depths() -> PackedInt32Array` -- BFS depth from `post`, -1 for dead
  - `func matched(i: int, side: int) -> bool` -- that stub meets a stub
  - `func loose(i: int) -> int` -- mask of this cell's unmatched stubs
  - `func is_solved() -> bool`
  - `func lanterns() -> PackedInt32Array` -- the degree-1 cells, reading order

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_fairy_lights.gd`:

```gdscript
# 9.  A fresh state is not solved, and grid == deal.
# 10. turn() on an ordinary cell returns OK, advances turns by one, and
#     leaves grid[i] == cw(previous).
# 11. Four turns of one cell come back to where they started.
# 12. turn() on a cross returns CROSS, does not change grid, and does not
#     count a turn.
# 13. Setting grid to sol makes is_solved() true; turning any one
#     non-cross cell off it makes it false again.
# 14. depths(): post is 0, a cell joined to the post is 1, and a cell whose
#     stub faces a closed neighbour is -1.
# 15. matched() is symmetric: matched(i, side) == matched(j, opposite)
#     for every neighbouring pair, and false at the grid's edge.
# 16. undo() turns the last cell back and returns it; on an empty log it
#     returns -1 and changes nothing.
# 17. hint() settles the first unsolved cell in reading order to sol,
#     pins it, counts a hint, and empties the undo log.
# 18. turn() on a pinned cell returns PINNED and changes nothing.
# 19. reset_board() puts every unpinned cell back to deal and leaves a
#     pinned cell where the hint put it.
# 20. Solving a whole board by turning each cell to sol reaches
#     is_solved() with no cell left loose().
```

- [ ] **Step 2: Run them and watch them fail**

Run: `godot --headless --path . --script tests/run_tests.gd`
Expected: failures naming `fairy_lights_state.gd`.

- [ ] **Step 3: Write the state**

Three things carry the design and must not be compromised:

- **Live is derived, every time, and never stored.** `depths()` is a BFS from
  `post` over edges where both sides carry a stub. No cache that a move has to
  remember to invalidate; Queens' rule, and it is what makes undo free.
- **Solved is the rule, not the answer.** `is_solved()` checks that every
  stub meets a stub and every cell has a depth -- it never compares `grid`
  with `sol`. A test that passes because the two arrays are equal is testing
  the wrong thing.
- **A hint is a given.** `hint()` empties the undo log (Shikaku's rule) and
  what it settled survives `reset_board()`.

- [ ] **Step 4: Run the tests**

Run: `godot --headless --path . --script tests/run_tests.gd`
Expected: `0` failures.

- [ ] **Step 5: Commit**

```bash
git add puzzles/fairy_lights_state.gd tests/test_fairy_lights.gd
git commit -m "feat(fairy-lights): the rules, scene-free"
```

---

### Task 3: The board on the grid, and the win harness

**Files:**
- Create: `puzzles/fairy_lights2d.gd`
- Modify: `ui/registry.gd`, `tests/_win.gd`

**Interfaces:**
- Consumes: the state's whole surface.
- Produces: a `PuzzleBase` subclass answering `puzzle_id()` `"fairylights"`,
  `title()`, `rules()`, `capabilities()` `["undo", "hint"]`, `card_height()`,
  `card_centred()` `true`, `flat_win()`, `tip_line()`, plus `hint()`,
  `undo()`, `reset_board()`, `is_solved()`. It holds its state in a member
  **named `state`**, because `tests/_win.gd` reaches for `_puzzle.state` the
  way it does on every other board.
- `flat_win()` returns **five lit paper lanterns**. `ui/flat/well_done.gd`
  lays a cast of faces and draws no cord, so the cord the mock draws between
  them is not shipped and nobody edits `well_done.gd` for it.
- **Analytics need no code.** `ui/puzzle_host.gd` already sends
  `puzzle_start`, `puzzle_complete`, `puzzle_abandon`, `hint_used`,
  `undo_used`, `board_reset` and `rules_opened` for any board; there is no
  `check_used` here because there is no Check. Do not add an `Analytics` call
  to this board.

- [ ] **Step 1: The registry entry**

In `ui/registry.gd`, after Sudoku's entry (the last of `PUZZLES`):

```gdscript
	{
		"id": "fairylights",
		"kind": "puzzle",
		"title": "Fairy Lights",
		"blurb": "Turn the wire until every lantern is lit.",
		"short": "Turn the wire,\nlight the garden.",
		"motto": "Wake every lantern",
		"footer": "Turn · Join · Light",
		# It picks nothing up and there is no Check: a board is unfinished
		# or it is done. So Reset rides up into the top bar and the bottom
		# slot is the tip card alone.
		"script": "res://puzzles/fairy_lights2d.gd",
		"shell": "flat",
		"tray": "none",
		"actions": false,
		"difficulties": [0, 1, 2],
	},
```

This is the fifteenth entry, so it lands on page two with Mushroom Patch and
Sudoku. Nothing about the pager changes.

- [ ] **Step 2: Build the board, laid out from the spec's section 2**

Port the mock's geometry number for number. `INSET` 28, cell `floor(944 / n)`,
**no gap**, the 6-wide `GRID_RULE` fence drawn *round* the grid, the ground in
`SURFACE` half-way to `PARCHMENT` with rules in `LINE` at 34%.

How it is drawn (spec section 6): the ground, the fence, the halos, the wire
and the loose ends go into **one `ArrayMesh`**; the lanterns and the post are
`ui/faces/lantern_face.gd` Controls **in slots the board owns**, Untangle's
arrangement. Draw order matters -- halos under every live run first, then the
wire over them.

**Keep the mesh the last `_draw` handed over** in a `_shown` member. A canvas
command holds a mesh by RID, and a board that rebuilds its cached `ArrayMesh`
and drops the old one leaves the renderer drawing a freed RID -- "Parameter
mesh is null" and an empty card -- on any frame rendered without its queued
redraw flushed, which is exactly what a harness's `force_draw()` does.

Colours come from the spec's section 5 table and **no new palette constant is
added**.

This task is the still board: the pieces are where the state says, the live
set is warm, loose ends stop short with a rounded end. Motion is Task 4.

- [ ] **Step 3: Wire the gestures**

A tap turns the cell under the finger clockwise. A cross returns `CROSS` and
the sprout says so through the tip line. A pinned cell returns `PINNED`. There
is no drag, no long press and no second direction.

- [ ] **Step 4: Teach the win harness this board**

In `tests/_win.gd` add a `_solve_fairylights()` beside `_solve_sudoku()` that
turns every cell to its proven orientation through the ordinary `turn()` --
never by writing `grid` directly, because the harness's job is to prove the
real move path reaches the win -- and a status line beside the others:

```gdscript
		"fairylights": return "%dx%d garden, %d lanterns, %d turns, board fit=%s, hud=%s" % [
			_puzzle.state.n, _puzzle.state.n, _puzzle.state.lanterns().size(),
			_puzzle.state.turns, _fit_ok, _hud_ok]
```

- [ ] **Step 5: Run the win harness, windowed**

Run: `godot --path . --resolution 810x1440 --script tests/_win.gd`
Expected: every band solves, board fit and hud ok. **It must be run windowed:
headless it silently reports 0/0.**

- [ ] **Step 6: Run the suite**

Run: `godot --headless --path . --script tests/run_tests.gd`
Expected: `0` failures.

- [ ] **Step 7: Commit**

```bash
git add puzzles/fairy_lights2d.gd ui/registry.gd tests/_win.gd
git commit -m "feat(fairy-lights): the garden on the grid, and the win it reaches"
```

---

### Task 4: Motion -- the spin and the wash

**Files:**
- Modify: `puzzles/fairy_lights2d.gd`

**Interfaces:**
- Consumes: Task 3's board. Produces: two constants, `TURN_TIME := 0.26` and
  `WAVE_STEP := 0.05`, and nothing new in `core/motion.gd`.

- [ ] **Step 1: Read the vocabulary first**

Read `docs/art/flat-motion.md` and `core/motion.gd`. Every recipe this board
needs already has a curve reader -- `back_out`, `wide_pop_scale`,
`pop_in_scale`, `bump_scale`, `shiver_offset`, `flash_level`. **A number that
has to differ goes through a recipe's parameter, never a copied constant.**

- [ ] **Step 2: Build the moments from the spec's section 7 table**

The load-bearing ones:

- **The turn:** `back_out` over `TURN_TIME`, with the arms pulled in about 11%
  at the middle of the spin so a piece does not reach into its neighbours on
  the way round. **A lantern's body counter-rotates** so the paper stays
  level; a hanging thing does not cartwheel.
- **The wash is the signature.** It is Queens' `_settle` with the tree's own
  depth in place of a queen's sight: diff a snapshot of what was live against
  what is live now, and hand each changed cell its moment -- `depth *
  WAVE_STEP` after the spin for a cell just reached, and **the same wave
  reversed, far end first**, for a cell just cut off, which reads as the light
  being pulled back rather than switched off. Derived off the diff, never
  stored.
- **A lantern wakes** with `bump_scale` as the wash arrives, and its face
  appears with it -- an unlit lantern is `plain`.
- **Reduce motion** kills all of it: no spin, no wash, no bump, no halo pulse,
  no rings, no sparkles, and the win follows the last turn.

- [ ] **Step 3: Prove reduce motion is still**

Shoot two frames 1.5 s apart with `Motion.reduce` set **right before the board
opens**, and compare them. Expected: pixel-identical.

- [ ] **Step 4: Rebuild only while something is moving, and ask about every wave**

If the board rebuilds its mesh only while animating, `_animating()` must
account for **every** wave -- the entrance, the spin, the wash and the win. A
board that asks only about its entrance freezes the tail of a long wash
part-way, which shows on a rendered frame and in no test.

- [ ] **Step 5: Run the suite and the win harness again**

Run: `godot --headless --path . --script tests/run_tests.gd`, then
`godot --path . --resolution 810x1440 --script tests/_win.gd`
Expected: `0` failures; every band still solves.

- [ ] **Step 6: Commit**

```bash
git add puzzles/fairy_lights2d.gd
git commit -m "feat(fairy-lights): the spin, and the light running out along the wire"
```

---

### Task 5: The animation strip, and the numbers

**Files:**
- Modify: `tests/_shot_anim.gd`
- Modify: `docs/superpowers/specs/2026-09-20-fairy-lights-flat-design.md` (section 11 only)

- [ ] **Step 1: Add the tap script**

Beside `_tap_sudoku()`, add `_tap_fairylights()`: one real touch on a cell the
solution turns, chosen so the wash actually runs -- a cell adjacent to the
live set. Go through the board's ordinary input path, not the state directly.

**A probe has to let a frame pass between the poke and the shot.**
`queue_redraw` is flushed on the next idle frame, so a probe that pokes the
board and calls `force_draw()` in the same frame photographs the state before
the poke.

- [ ] **Step 2: Shoot the strip and count, twice**

Run: `godot --path . --resolution 810x1440 --script tests/_shot_anim.gd -- fairylights`

Record draw calls **bare** and **with a wash in flight**, against the 855
budget. Read each twice. Never run this while another windowed harness is up.

- [ ] **Step 3: Run a control board in the same hour**

Run the same harness for `wordtrail` (recorded at 65/62/65 with one word
locked, 60/61 bare) and quote what it comes back as. **A single reading off
this harness is worth nothing** -- Hidden Word's fourteen runs spread 3.06 to
7.30 ms on an unchanged build. Quote every reading, including the flattering
one.

- [ ] **Step 4: Check the phone's driver**

Run: `godot --path . --resolution 810x1440 --rendering-driver opengl3_angle --script tests/_shot_anim.gd -- fairylights`

Expected: the same draw calls, and the settled frame matching the default
driver to a couple of levels on edge antialiasing alone. A difference larger
than that means something has reintroduced an `instance uniform`, whose real
cap is **sixteen instances in the frame** and which a desktop driver hides.

- [ ] **Step 5: Fill the spec's section 11**

Write every reading in, with the command beside it and the control's figures
next to this board's. Replace the JavaScript-scaled generator estimate in
section 4.3 with Task 1's real GDScript reading, and say the old one was an
estimate.

- [ ] **Step 6: Commit**

```bash
git add tests/_shot_anim.gd docs/superpowers/specs/2026-09-20-fairy-lights-flat-design.md
git commit -m "docs(fairy-lights): the fifteenth board measured, with a control beside it"
```

---

### Task 6: The menu card's picture

**Files:**
- Modify: `ui/menu/card_art.gd`

- [ ] **Step 1: Draw the card**

One `_build` branch and one `_draw` branch: **a lantern post with a short run
of lit wire and two paper lanterns on it**, seated in the 320 by 118 picture
box and scaled to the card. All reuse -- `lantern_face.gd` for the lanterns,
the board's own wire colours for the run.

**It is never an image and never a `SubViewport`.** Read the `"mushroom"`
branch beside it, including its comment about seating a face by its own foot
rather than by arithmetic on the box.

- [ ] **Step 2: Shoot page two and count**

Run: `godot --path . --resolution 810x1440 --script tests/_shot_menu.gd -- page2`

Page two read **119** with two cards, one invisible filler and the pager; with
three cards the filler count changes. Record what it comes back as. A short
last row needs invisible `SIZE_EXPAND_FILL` filler `Control`s padded out to
the column count, or a lone card comes out 334 wide instead of 320 -- check
the card measures 320.

- [ ] **Step 3: Look at the frame**

Crop the shot with PIL and look at it. The post must not be buried and the
lanterns must sit on the run rather than float over it.

- [ ] **Step 4: Commit**

```bash
git add ui/menu/card_art.gd
git commit -m "feat(fairy-lights): the card's own post and two lanterns"
```

---

### Task 7: The record

**Files:**
- Modify: `CLAUDE.md`, `docs/art/flat-motion.md`
- Modify: `docs/superpowers/specs/2026-09-20-fairy-lights-flat-design.md`
  (amendments section)

- [ ] **Step 1: `docs/art/flat-motion.md`**

Add this board's row to the table: the wash along the tree's depth, and the
counter-rotating lantern -- the rule that a hanging thing keeps its paper
level through a spin is the reusable part.

- [ ] **Step 2: `CLAUDE.md`**

Update, minimally and precisely:
- "The flat screens": **fifteen** boards, Fairy Lights named with its spec and
  its mock anchor, and its own bullet -- the first board whose cells abut, and
  why; the wash as its signature; the guess-free promise and what the
  generator actually costs in GDScript.
- "The first screen": fifteen cards, page two now holds three.
- The bottom-slot list gains a fifteenth number (140).
- The count of boards that drop Check goes to three, and the count carrying
  five buttons in the top bar goes to four.

Do not restate anything already true; correct the counts that moved.

- [ ] **Step 3: Add the build's amendments to the spec**

Everything the build learned that contradicts or extends the design as
written, in its own section at the end, the way every other spec here carries
one.

- [ ] **Step 4: Commit**

```bash
git add CLAUDE.md docs/art/flat-motion.md docs/superpowers/specs/2026-09-20-fairy-lights-flat-design.md
git commit -m "docs(fairy-lights): the fifteenth board on the record"
```

---

## Done when

- The suite reports `0` failures and `tests/_win.gd` solves every band
  windowed.
- Draw calls are recorded bare and mid-wash, on both drivers, with a control
  board's figures beside them, and are inside the 855 budget.
- The generator's GDScript cost is a reading, not an estimate.
- The mock and the board agree; neither has drifted.
- `CLAUDE.md`, `docs/art/flat-motion.md` and the spec's sections 11 and the
  amendments are true.
- main has been merged into this branch and reconciled by hand -- the other
  board branches touch the same six shared files.
