# Paper Planes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship **Paper Planes**, the fifteenth flat board: a field of bent paper-plane trails, each launched out of the board when the lane ahead of its dart is clear.

**Architecture:** A scene-free rules class (`puzzles/planes_state.gd`) holds the grid, the planes, generation and the greedy solver; a flat board (`puzzles/planes2d.gd`) draws it as a single `ArrayMesh` and animates the launch; the registry adds the fifteenth grid entry and the menu card gets one `_draw` branch. No new character, no new palette entry, nothing added to `core/motion.gd`.

**Tech Stack:** Godot 4.7, GDScript, gl_compatibility renderer. Tests are plain GDScript suites under `tests/`, run headless by `tests/run_tests.gd`.

**Spec:** `docs/superpowers/specs/2026-09-20-paper-planes-flat-design.md` — read it before Task 1 and keep it open; every number below comes from it.

## Global Constraints

- **The board is called Paper Planes.** Never *Setas*, never *Arrows*, never *Tap Away*, in code, in a comment, in a commit message or on screen. The reference app's name appears exactly once in the repo, in the spec's section 2, in order to forbid it. (Same rule as Code Break, Hidden Word and Word Trail.)
- **No lives, no mistakes, no Check.** A blocked tap is refused and costs nothing. Nothing may count refusals, and no analytics event may report one.
- **No new character.** Nothing is added to `ui/faces/`. The only face on the screen is the shared sprout on the tip card.
- **No new palette entry.** Every colour comes from `core/palette.gd` as it stands.
- **Nothing is added to `core/motion.gd`.** The board reads the family's recipes and carries only its own three constants (`LAUNCH_SPEED`, `WAKE_STEP`, `BLOCK_FLASH`).
- **No `instance uniform` anywhere**, ever (see CLAUDE.md: sixteen instances in the whole frame on a mobile driver).
- **A canvas command holds a mesh by RID, not by reference.** A board that rebuilds a cached `ArrayMesh` must keep the one its last `_draw` handed over in `_shown` until the next replaces it.
- **Design space is 1080 x 1920.** Run any render harness at `--resolution 810x1440`, and the flag is an *engine* flag: it goes **before** `--script`, never after.
- Suite must stay green: `godot --headless --path . --script tests/run_tests.gd` reports `0` failures.
- Commit after every task, in the repo's style: `feat(planes): ...`, `test(planes): ...`, `docs(planes): ...`.

---

## File Structure

| File | New? | Responsibility |
|---|---|---|
| `puzzles/planes_state.gd` | create | Grid, planes, occupancy, lanes, generation, launch/undo/reset, greedy solver. No nodes, no drawing. |
| `puzzles/planes2d.gd` | create | The flat board: layout, hit test, the field mesh, the launch/wake/refusal motion, the `PuzzleBase` contract. |
| `tests/test_planes.gd` | create | The state class over a sweep of seeds. |
| `tests/run_tests.gd` | modify | Register the suite. |
| `ui/registry.gd` | modify | The fifteenth grid entry. |
| `ui/menu/card_art.gd` | modify | `_draw_planes()` and its `match` arm. |
| `tests/_shot_anim.gd` | modify | A `planes` case: launch, wake, idle window. |
| `docs/art/flat-motion.md` | modify | One row for the launch and the wake. |
| `CLAUDE.md` | modify | The fifteenth board, in the places that count boards. |

---

### Task 1: The rules class — grid, planes, lanes

**Files:**
- Create: `puzzles/planes_state.gd`
- Create: `tests/test_planes.gd`
- Modify: `tests/run_tests.gd` (add `"planes": "res://tests/test_planes.gd"` after the `"sudoku"` line)

**Interfaces:**
- Consumes: nothing.
- Produces, and Tasks 2-4 rely on these exact names:
  - `const BANDS: Array` — three `{"cols": int, "rows": int, "min_len": int, "max_len": int, "weights": Array[int], "floor": float}` dictionaries.
  - `static func band(difficulty: int) -> Dictionary`
  - `var rows: int`, `var cols: int`
  - `var planes: Array[Dictionary]` — each `{"cells": Array[Vector2i] (tail..head), "dir": Vector2i, "gone": bool}`
  - `var order: Array[int]` — the generator's own solution order
  - `func build(rng: RandomNumberGenerator, difficulty: int) -> void`
  - `func lane(i: int) -> Array[Vector2i]`
  - `func blocker(i: int) -> int` — the index of the first plane in the lane, or `-1`
  - `func is_free(i: int) -> bool`
  - `func free_planes() -> Array[int]`
  - `func plane_at(cell: Vector2i) -> int` — `-1` when empty or gone
  - `func launch(i: int) -> bool`
  - `func undo() -> int` — the index put back, or `-1`
  - `func reset() -> void`
  - `func left() -> int`, `func solved() -> bool`
  - `func solve_order() -> Array[int]` — greedy; `[]` when stuck
  - `func hint_plane() -> int` — a free plane's index, `-1` when none

- [ ] **Step 1: Write the failing test**

Create `tests/test_planes.gd`:

```gdscript
extends RefCounted

## Paper Planes' rules (puzzles/planes_state.gd): the lane, the launch, and
## the generator's one promise -- a board carved backwards out of an empty
## sky can always be cleared.

const State = preload("res://puzzles/planes_state.gd")

static func run(t) -> void:
	_test_lane(t)
	_test_launch(t)

static func _empty(rows: int, cols: int) -> State:
	var st := State.new()
	st.rows = rows
	st.cols = cols
	st.planes = []
	st.order = []
	st.clear_occupancy()
	return st

## A plane laid by hand: cells tail..head, direction taken from the last step.
static func _add(st: State, cells: Array) -> int:
	var typed: Array[Vector2i] = []
	for c in cells:
		typed.append(c)
	return st.add_plane(typed)

## The lane is every cell beyond the head, out to the edge -- and a plane is
## free exactly when nothing stands in it.
static func _test_lane(t) -> void:
	var st := _empty(5, 5)
	# A plane along row 2, heading right, head at (2, 2).
	var a := _add(st, [Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2)])
	t.eq(st.planes[a]["dir"], Vector2i(1, 0), "the dart heads the way the last step went")
	t.eq(st.lane(a).size(), 2, "two cells between the head and the right edge")
	t.check(st.is_free(a), "an empty lane is a free plane")
	t.eq(st.blocker(a), -1, "nothing blocks it")
	# A second plane standing in that lane.
	var b := _add(st, [Vector2i(4, 0), Vector2i(4, 1), Vector2i(4, 2)])
	t.check(not st.is_free(a), "a plane in the lane blocks the launch")
	t.eq(st.blocker(a), b, "and it is named as the blocker")
	t.check(st.is_free(b), "the blocker itself heads down a clear lane")

## A launch empties the plane's cells and can never block anything; an undo
## puts it back exactly as it was.
static func _test_launch(t) -> void:
	var st := _empty(5, 5)
	var a := _add(st, [Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2)])
	var b := _add(st, [Vector2i(4, 0), Vector2i(4, 1), Vector2i(4, 2)])
	t.check(not st.launch(a), "a blocked plane refuses to launch")
	t.eq(st.left(), 2, "and nothing left the board")
	t.check(st.launch(b), "the free one goes")
	t.eq(st.plane_at(Vector2i(4, 1)), -1, "its cells are empty behind it")
	t.check(st.is_free(a), "which frees the one it was blocking")
	t.check(st.launch(a), "and that one goes too")
	t.check(st.solved(), "an empty sky is a solved board")
	t.eq(st.undo(), a, "undo puts the last one back")
	t.check(not st.solved(), "so the board is not solved any more")
	t.eq(st.plane_at(Vector2i(1, 2)), a, "and it is back on its own cells")
```

- [ ] **Step 2: Run it and watch it fail**

Run: `godot --headless --path . --script tests/run_tests.gd 2>&1 | tail -5`
Expected: the run reports failures for the `planes` suite (the script does not exist yet, so the runner's `can_instantiate()` guard counts one failure). Add the suite line to `tests/run_tests.gd` first if the suite does not appear at all.

- [ ] **Step 3: Write `puzzles/planes_state.gd` — everything but generation**

The file starts with a doc comment in the repo's voice naming the spec (`docs/superpowers/specs/2026-09-20-paper-planes-flat-design.md`, sections 3 and 4) and the one fact the whole screen rests on: **a launch only ever empties cells, so it can never block another plane**.

```gdscript
extends RefCounted

const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var rows := 0
var cols := 0
var planes: Array[Dictionary] = []
var order: Array[int] = []
var _occupant: Dictionary = {}   # Vector2i -> plane index, planes still on the board
var _history: Array[int] = []

func clear_occupancy() -> void:
	_occupant = {}
	_history = []

## Lays one plane on the board. `cells` runs tail to head; the direction is
## the step into the head, so a plane's heading is a property of its shape
## and never a second field to keep in step.
func add_plane(cells: Array[Vector2i]) -> int:
	var head: Vector2i = cells[cells.size() - 1]
	var dir: Vector2i = head - cells[cells.size() - 2]
	var idx := planes.size()
	planes.append({"cells": cells, "dir": dir, "gone": false})
	for c in cells:
		_occupant[c] = idx
	return idx

func in_board(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < cols and c.y < rows

func plane_at(cell: Vector2i) -> int:
	return int(_occupant.get(cell, -1))

## Every cell beyond the head, in the dart's direction, out to the edge.
func lane(i: int) -> Array[Vector2i]:
	var p: Dictionary = planes[i]
	var cells: Array[Vector2i] = p["cells"]
	var dir: Vector2i = p["dir"]
	var out: Array[Vector2i] = []
	var at: Vector2i = cells[cells.size() - 1] + dir
	while in_board(at):
		out.append(at)
		at += dir
	return out

## The first plane standing in the lane, or -1.
func blocker(i: int) -> int:
	for c in lane(i):
		var who := plane_at(c)
		if who != -1:
			return who
	return -1

func is_free(i: int) -> bool:
	return not planes[i]["gone"] and blocker(i) == -1

func free_planes() -> Array[int]:
	var out: Array[int] = []
	for i in planes.size():
		if is_free(i):
			out.append(i)
	return out

func launch(i: int) -> bool:
	if planes[i]["gone"] or not is_free(i):
		return false
	planes[i]["gone"] = true
	for c in planes[i]["cells"]:
		_occupant.erase(c)
	_history.append(i)
	return true

func undo() -> int:
	if _history.is_empty():
		return -1
	var i: int = _history.pop_back()
	planes[i]["gone"] = false
	for c in planes[i]["cells"]:
		_occupant[c] = i
	return i

func reset() -> void:
	for i in planes.size():
		if planes[i]["gone"]:
			planes[i]["gone"] = false
			for c in planes[i]["cells"]:
				_occupant[c] = i
	_history = []

func left() -> int:
	var n := 0
	for p in planes:
		if not p["gone"]:
			n += 1
	return n

func solved() -> bool:
	return left() == 0

## Greedy, and complete: launching a plane only empties cells, so a board
## that could be cleared before a tap can still be cleared after it. No
## search, no backtracking. Returns [] when the board is stuck.
func solve_order() -> Array[int]:
	var gone := {}
	var out: Array[int] = []
	var total := left()
	while out.size() < total:
		var moved := false
		for i in planes.size():
			if planes[i]["gone"] or gone.has(i):
				continue
			var clear := true
			for c in lane(i):
				var who := plane_at(c)
				if who != -1 and not gone.has(who):
					clear = false
					break
			if clear:
				gone[i] = true
				out.append(i)
				moved = true
		if not moved:
			return []
	return out

## The hint's pick: the first plane of the generator's own order that is
## still here and free, else any free one.
func hint_plane() -> int:
	for i in order:
		if not planes[i]["gone"] and is_free(i):
			return i
	var free := free_planes()
	return -1 if free.is_empty() else free[0]
```

Note `solve_order()` must not mutate the board: it reads `plane_at` and skips planes already in its own `gone` set, exactly as written.

- [ ] **Step 4: Run the tests**

Run: `godot --headless --path . --script tests/run_tests.gd 2>&1 | tail -5`
Expected: `0` failures, and the total rises by the new suite's assertions.

- [ ] **Step 5: Commit**

```bash
git add puzzles/planes_state.gd tests/test_planes.gd tests/run_tests.gd
git commit -m "feat(planes): the rules -- lanes, launch, undo and the greedy solver"
```

---

### Task 2: Generation, backwards out of an empty sky

**Files:**
- Modify: `puzzles/planes_state.gd` (add `BANDS`, `band()`, `build()` and the private placement helpers)
- Modify: `tests/test_planes.gd` (add `_test_generator` and `_test_repeatable` to `run`)

**Interfaces:**
- Consumes: everything Task 1 produced.
- Produces: `build(rng, difficulty)` fills `rows`, `cols`, `planes` and `order`; `State.band(difficulty)` is the band table other files read for the grid size.

The algorithm is in the spec's section 5 and is already validated in Python at `tools/_planes_probe.py` — **read that file**; port it, do not reinvent it.

- [ ] **Step 1: Write the failing test**

Add to `tests/test_planes.gd`, and add both to `run()`:

```gdscript
static func _built(seed_value: int, difficulty: int) -> State:
	var st := State.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	st.build(rng, difficulty)
	return st

## The generator's promises, over enough seeds that a rare layout cannot
## hide: the band's grid, well-formed planes, no overlap, no plane blocking
## itself, and -- the one that matters -- every board clears.
static func _test_generator(t) -> void:
	for difficulty in 3:
		var b: Dictionary = State.band(difficulty)
		for s in range(1, 41):
			var st := _built(s, difficulty)
			t.eq(st.cols, int(b["cols"]), "band %d seed %d: columns" % [difficulty, s])
			t.eq(st.rows, int(b["rows"]), "band %d seed %d: rows" % [difficulty, s])
			t.check(st.planes.size() >= 8, "band %d seed %d: a board worth playing" % [difficulty, s])
			var seen := {}
			for i in st.planes.size():
				var cells: Array = st.planes[i]["cells"]
				t.check(cells.size() >= int(b["min_len"]) and cells.size() <= int(b["max_len"]),
					"band %d seed %d: plane %d is within the band's lengths" % [difficulty, s, i])
				for j in cells.size():
					var c: Vector2i = cells[j]
					t.check(st.in_board(c), "band %d seed %d: plane %d stays on the board" % [difficulty, s, i])
					t.check(not seen.has(c), "band %d seed %d: no two planes share a cell" % [difficulty, s, i])
					seen[c] = true
					if j > 0:
						var step: Vector2i = c - cells[j - 1]
						t.eq(absi(step.x) + absi(step.y), 1,
							"band %d seed %d: plane %d walks one cell at a time" % [difficulty, s, i])
				# A plane may never stand in its own lane: the launch rule
				# would then have to special-case the plane being tapped.
				var body := {}
				for c in cells:
					body[c] = true
				for c in st.lane(i):
					t.check(not body.has(c), "band %d seed %d: plane %d never blocks itself" % [difficulty, s, i])
			t.eq(st.solve_order().size(), st.planes.size(),
				"band %d seed %d: the whole board clears" % [difficulty, s])
			t.eq(st.order.size(), st.planes.size(),
				"band %d seed %d: the generator's own order is complete" % [difficulty, s])

## The same seed is the same board, which is what a daily puzzle means.
static func _test_repeatable(t) -> void:
	for difficulty in 3:
		var a := _built(77, difficulty)
		var b := _built(77, difficulty)
		t.eq(a.planes.size(), b.planes.size(), "band %d: same seed, same plane count" % difficulty)
		for i in a.planes.size():
			t.eq(a.planes[i]["cells"], b.planes[i]["cells"], "band %d: plane %d is the same" % [difficulty, i])
```

- [ ] **Step 2: Run it and watch it fail**

Run: `godot --headless --path . --script tests/run_tests.gd 2>&1 | tail -5`
Expected: failures in the `planes` suite — `build` does nothing yet, so the band and plane-count assertions fail.

- [ ] **Step 3: Implement generation**

Add to `puzzles/planes_state.gd`:

```gdscript
## The bands (spec section 6). Hard is the reference's own 16 x 22. The
## weights pick a plane's length: the middle lengths are the common ones,
## because a board of two-cell darts reads as confetti and a board of
## ten-cell ones cannot be packed.
const BANDS: Array[Dictionary] = [
	{"cols": 10, "rows": 14, "min_len": 2, "max_len": 8, "weights": [2, 3, 4, 5, 5, 4, 3], "floor": 0.72},
	{"cols": 13, "rows": 18, "min_len": 2, "max_len": 9, "weights": [2, 3, 4, 5, 5, 5, 4, 3], "floor": 0.72},
	{"cols": 16, "rows": 22, "min_len": 2, "max_len": 10, "weights": [2, 3, 4, 5, 5, 5, 4, 3, 2], "floor": 0.72},
]
## How many boards to make before keeping the fullest, and how many failed
## placements in a row end a board.
const CANDIDATES := 6
const TRIES := 400

static func band(difficulty: int) -> Dictionary:
	return BANDS[clampi(difficulty, 0, BANDS.size() - 1)]
```

`build()` makes up to `CANDIDATES` boards with `_carve()`, keeps the first whose coverage reaches the band's `floor` (else the fullest), then sets `order` to the reverse of the placement order and asserts `solve_order()` is complete.

`_carve(rng, b)` is the Python probe, cell for cell:

- loop while coverage is under 0.95 and consecutive failures are under `TRIES`;
- pick a random cell; if occupied, count a failure and go on;
- shuffle `DIRS`; for each, walk the lane out to the edge, abandoning the direction the moment an occupied cell appears; keep the lane's cells in a `Dictionary` for lookup;
- the first step back from the head is `head - dir`: it must be on the board, empty and not in the lane, or the direction is abandoned;
- draw a target length with `_pick_length(rng, b)` (weighted by `b["weights"]`, index `len - min_len`), then extend the tail by choosing uniformly among the neighbours of the tail end that are on the board, unoccupied, not already in this plane, and not in the lane; stop when there is no candidate;
- if the body reached `min_len`, reverse it to tail..head, `add_plane()` it, reset the failure count; otherwise count a failure.

Reuse `add_plane()` so the direction is derived in one place only. `build()` must reset `rows`, `cols`, `planes`, `order` and `clear_occupancy()` at the top so a rebuild on the same object is clean.

- [ ] **Step 4: Run the tests**

Run: `godot --headless --path . --script tests/run_tests.gd 2>&1 | tail -5`
Expected: `0` failures.

- [ ] **Step 5: Measure it, and record what you measured**

Write a throwaway probe (`tools/_planes_time.gd`, a `SceneTree` script; remember that in a headless `SceneTree` script `_ready` is deferred — run assertions from `_process` or `_initialize`) that builds 40 boards a band and prints, per band: plane count range and mean, coverage range and mean, and milliseconds a board. Run it:

`godot --headless --path . --script tools/_planes_time.gd`

Paste the numbers into the spec's section 6 table as a second row labelled **GDScript on this Mac**, beside the Python probe's. Do not delete the Python row; if the two disagree by more than a little, say so in the spec rather than quietly replacing it. Delete the probe afterwards (it is throwaway) and say in the commit message what it measured.

- [ ] **Step 6: Commit**

```bash
git add puzzles/planes_state.gd tests/test_planes.gd docs/superpowers/specs/2026-09-20-paper-planes-flat-design.md
git commit -m "feat(planes): carve a board backwards out of an empty sky"
```

---

### Task 3: The board — layout, drawing, and a tap that launches

**Files:**
- Create: `puzzles/planes2d.gd`
- Modify: `ui/registry.gd` (the fifteenth entry)

**Interfaces:**
- Consumes: `puzzles/planes_state.gd`'s whole API, and `PuzzleBase`'s contract in `core/puzzle_base.gd`.
- Produces: a `PuzzleBase` subclass the flat host can spawn; `Registry.PUZZLES` gains `{"id": "planes", ...}`.

**Read first:** `puzzles/word_trail2d.gd` (the closest shape — no tray, no actions row, a single-mesh field, `_shown` kept by RID) and `puzzles/queens2d.gd`'s `_settle` (the wave this board's wake copies). Follow their structure, their comment density and their constant-naming.

- [ ] **Step 1: The registry entry**

Append to `Registry.PUZZLES`, after Sudoku, with a comment saying why it takes no tray and no actions row:

```gdscript
	{
		"id": "planes",
		"kind": "puzzle",
		"title": "Paper Planes",
		"blurb": "Tap a plane whose lane to the edge is clear, and off it goes.",
		"short": "Send every plane\noff a clear lane.",
		"motto": "A clear lane and away",
		"footer": "Scan · Clear · Launch",
		# It picks nothing up, and there is no Check: a launch only ever
		# empties cells, so nothing wrong can be sitting on the board and the
		# player cannot dead-end it. Reset rides up into the top bar and the
		# bottom slot is the tip card alone, which is Word Trail's shape.
		"script": "res://puzzles/planes2d.gd",
		"shell": "flat",
		"tray": "none",
		"actions": false,
		"difficulties": [0, 1, 2],
	},
```

Also update the file's header comment: it says "fourteen cards over two pages" in several places — make it fifteen, and say that the fifteenth is the second card added without displacing anything and that `PER_PAGE` is still twelve, so page two now holds three.

- [ ] **Step 2: The board's skeleton and layout**

Create `puzzles/planes2d.gd` extending `res://core/puzzle_base.gd`, with a doc comment naming the spec and sections 7-10. Implement, in this order:

- `puzzle_id()` → `"planes"`, `title()` → `"Paper Planes"`, `rules()` → the three sentences of the spec's section 3 (what a lane is, what a tap does, that a blocked tap costs nothing).
- `capabilities()` → `["undo", "hint"]` (typed `Array[String]`).
- `card_height(available)` → `available`; `card_centred()` → `false`.
- `build(rng, difficulty)` → makes the `State`, calls `build`, then `_layout()`.
- Layout: `_cell` is `floor(min((size.x - 2 * INSET) / cols, (size.y - 2 * INSET) / rows))` and `_origin` centres `cols * _cell` by `rows * _cell` in the card. Recompute on `resized`.
- Constants, from the spec's sections 7 and 8, each on its own line with the spec's own words as the comment: `INSET := 28.0`, `DOT := 0.05`, `DOT_ALPHA := 0.45`, `TRAIL := 0.17`, `DART_TIP := 0.42`, `DART_BACK := 0.26`, `DART_WING := 0.30`, `DART_NOTCH := 0.12`, `CREASE := 0.09`, `LANE_W := 0.34`, `LANE_ALPHA := 0.35`.

- [ ] **Step 3: Draw the field as one mesh**

`_draw()` builds a single `ArrayMesh` and issues one `draw_mesh`. Order matters and is: the dots on empty cells, then each plane's trail, then each plane's dart, then the lane band (pressed or refused) over them, then the hint glow. Keep the mesh in `var _shown: ArrayMesh` until the next `_draw` replaces it — **a canvas command holds a mesh by RID and not by reference**, and `tests/_shot_anim.gd` calls `RenderingServer.force_draw()`.

Build the trail as a stroked polyline: for each segment, a quad of width `TRAIL * _cell` between the two cell centres, plus a round join at each interior cell centre and a round cap at the tail. The dart is the four-point polygon of the spec's section 8 (tip, wing, notch, wing) with a `CREASE`-wide quad in `Pal.PAPER` down its spine, both rotated by the plane's direction.

Rebuild the mesh only when something changed (a dirty flag set by a launch, an undo, a reset, a press, a relayout, or a live animation), never every frame.

- [ ] **Step 4: The tap**

`_gui_input` on a press: convert the position to a cell, ask `plane_at`, and

- if the cell is empty, do nothing;
- if the plane is free, start its launch (Task 4 animates it; for this task, launch it immediately and `note_move()`);
- if it is blocked, start the refusal (Task 4; for this task, just do nothing).

`is_solved()` → `_state.solved()`. `reset_board()` → `_state.reset()` and redraw. `can_undo()`/`undo()` → the state's. `hints_left()`/`hint()` → three hints, the ring on `hint_plane()`, `hints_used += 1`, `check_solved()`.

- [ ] **Step 5: See it**

Import and open the board in the real app:

```bash
godot --headless --path . --import
godot --path . --resolution 810x1440 --script tests/_shot.gd -- planes
```

(Check `tests/_shot.gd`'s own usage line first; if it does not take a puzzle id, use `tests/_shot_anim.gd -- planes` once Task 5 has added the case, or open the game and tap through to the card.) Crop the PNG with PIL and **look at it**: the field should read like `docs/art/concept-planes-reference.png` — dense bent trails, clear darts, faint dots in the gaps.

- [ ] **Step 6: Commit**

```bash
git add puzzles/planes2d.gd ui/registry.gd
git commit -m "feat(planes): the flat board -- the field, the darts and the tap"
```

---

### Task 4: The launch, the wake and the refusal

**Files:**
- Modify: `puzzles/planes2d.gd`
- Modify: `docs/art/flat-motion.md`

**Interfaces:**
- Consumes: Task 3's board and mesh builder.
- Produces: nothing other files call.

Everything here is the family's vocabulary from `core/motion.gd` read as curve readers (`Motion.back_out`, `Motion.bump_scale`, `Motion.shiver_offset`, `Motion.nudge_offset`, `Motion.flash_level`), plus **three constants of this board's own and no more**: `LAUNCH_SPEED := 22.0`, `WAKE_STEP := 0.04`, `BLOCK_FLASH := 0.35`. Read `docs/art/flat-motion.md` first; if a number you want exists there, use the recipe rather than a new constant.

- [ ] **Step 1: The launch**

The plane runs along a **track**: its own body polyline (tail to head), extended past the head down the lane and one body-length beyond the edge. With `s` the cells travelled since the tap, the body drawn is the slice of the track from `s` to `s + len - 1`, sampled along the polyline, so the tail follows the head through every bend. Duration is `max(0.22, track_length / LAUNCH_SPEED)`, eased so it accelerates away. When it finishes, the plane is gone from the state and the mesh is rebuilt without it, and a puff of sparkles (`ui/fx2d.gd`) marks where it crossed the edge.

Launch the state *immediately* on the tap (so the freed planes are correct while the animation runs) and draw the departing plane from the animation rather than from the state.

- [ ] **Step 2: The wake**

Before the tap, snapshot `free_planes()` as a `Dictionary`; after it, diff. Every newly freed plane beats its wings once — `Motion.bump_scale` on the dart only, 0.24 s — starting at `WAKE_STEP` times the king-move distance between its head and the departing plane's head. This is `queens2d.gd`'s `_settle`; read it and follow it, including that the set is **derived and never stored**, so an undo leaves nothing to clean up.

- [ ] **Step 3: The refusal**

A blocked tap: the lane from the dart up to (and including) the blocking cell flashes `Pal.BAD_TILE` for `BLOCK_FLASH`, the **blocking** plane shivers (`Motion.shiver_offset`), and the tapped plane nudges forward and back (`Motion.nudge_offset`). No toast, no counter, no analytics event. `tip_line()` takes the line.

- [ ] **Step 4: Undo, reset and reduce motion**

Undo runs the last launch backwards along the same track. Reset flies every plane back, staggered from the far corner by the family's reset wave. Under `Motion.reduce`, a launch is an instant removal, the wake and the flash do not run, and nothing idles: two frames 1.5 s apart must be **pixel-identical**.

Make sure the board only rebuilds the mesh while something is actually moving, and that `_animating()` asks about **every** wave, not just the first — `oneline2d.gd` shipped a bug where the lines' wave outlasted the posts' entrance and froze half-drawn (CLAUDE.md records it).

- [ ] **Step 5: Check it by eye and by pixel**

- `godot --path . --resolution 810x1440 --script tests/_shot_anim.gd -- planes` (after Task 5) for the strip; look at every frame.
- Reduce motion: take two frames 1.5 s apart and compare them byte for byte with PIL; they must be identical.

- [ ] **Step 6: Add the row to the family's table**

`docs/art/flat-motion.md`: one row for **the launch** (a piece that travels along its own body, which nothing else in the game does) and one for **the wake** (Queens' `_settle` with a departure in place of a queen's sight), each naming this board's constants and saying that nothing was added to `core/motion.gd`.

- [ ] **Step 7: Commit**

```bash
git add puzzles/planes2d.gd docs/art/flat-motion.md
git commit -m "feat(planes): the launch, the wake and the refusal"
```

---

### Task 5: The menu card and the animation harness

**Files:**
- Modify: `ui/menu/card_art.gd`
- Modify: `tests/_shot_anim.gd`

**Interfaces:**
- Consumes: nothing from the board — the card draws its own picture.
- Produces: a `planes` arm in `card_art.gd`'s `_draw` match, and a `planes` case in the harness.

- [ ] **Step 1: The card's picture**

`ui/menu/card_art.gd` gets `_draw_planes()` and a `"planes": _draw_planes()` arm in the `_draw` match. **No `_build` branch and no character** — like Nonogram's and Sudoku's. Three bent ink trails with darts at their heads across the 320 by 118 box, with the field's faint dots behind them. Use the box's own units (`at(x, y)`), not pixels.

- [ ] **Step 2: Look at the first screen**

`godot --path . --resolution 810x1440 --script tests/_shot_menu.gd -- page2`
Crop and look: the card must sit third on page two, beside Mushroom Patch and Sudoku, and read as this board at card size. Record the page-two draw-call count the harness prints.

- [ ] **Step 3: The animation case**

`tests/_shot_anim.gd` gets a `planes` case: open the board, tap a plane that is free, and take the strip across the launch, the wake and two seconds of idle. Follow the file's existing per-board cases and extend its header comment the way Word Trail's and Sudoku's entries did. Remember the frame-lag rule: **poke the board on one frame, `force_draw()` on the next** — a probe that pokes and shoots in the same frame photographs the state before the poke.

- [ ] **Step 4: Measure, twice, with a control**

Run, sequentially and never overlapping (GPU contention inflates the numbers):

```bash
godot --path . --resolution 810x1440 --script tests/_shot_anim.gd -- planes
godot --path . --resolution 810x1440 --script tests/_shot_anim.gd -- planes
godot --path . --resolution 810x1440 --script tests/_shot_anim.gd -- wordtrail
```

Record **every** reading, including the flattering one, and quote the control beside them: a single reading off this harness is worth nothing. Then run the phone's driver once and diff the settled frame against the default driver's to prove nothing reintroduced an `instance uniform`:

```bash
godot --path . --rendering-driver opengl3_angle --resolution 810x1440 --script tests/_shot_anim.gd -- planes
```

Write the numbers into the spec's section 15, replacing the expectation with the measurement.

- [ ] **Step 5: Commit**

```bash
git add ui/menu/card_art.gd tests/_shot_anim.gd docs/superpowers/specs/2026-09-20-paper-planes-flat-design.md
git commit -m "feat(planes): the menu card and the animation harness case"
```

---

### Task 6: What the board says, and the win

**Files:**
- Modify: `puzzles/planes2d.gd`

**Interfaces:**
- Consumes: the flat host's optional contract in `core/puzzle_base.gd` and `ui/flat/flat_host.gd`.
- Produces: nothing other files call.

- [ ] **Step 1: `tip_line()`**

Read what `word_trail2d.gd` and `mushroom2d.gd` return and match the shape exactly. The opening line names the rule; a refusal says the lane is blocked; a launch says nothing after the first few. **It never counts planes** — the board is its own scoreboard.

- [ ] **Step 2: `flat_win()`**

```gdscript
func flat_win() -> Dictionary:
	return {"faces": [], "subtitle": "Every plane found its lane."}
```

`faces` are Controls from `ui/faces/` and this board has none, so the win screen keeps the family's sun and moon — exactly what `nonogram2d.gd`, `word_trail2d.gd` and `sudoku2d.gd` do. Add `win_delay()` in the same shape those three use (`Motion.REDUCED_TIME if Motion.reduce else WIN_WAIT`), long enough for the last launch and the solve wave to finish first.

- [ ] **Step 3: Win it**

`godot --path . --script tests/_win.gd` — **windowed, not headless**: that harness silently reports 0/0 without a display. Every board must still win 10/10 (or whatever the file's own count is); a new board joins the sweep if the file enumerates the registry.

- [ ] **Step 4: Commit**

```bash
git add puzzles/planes2d.gd
git commit -m "feat(planes): the tip lines and the win screen"
```

---

### Task 7: The record

**Files:**
- Modify: `CLAUDE.md`
- Modify: `docs/superpowers/specs/2026-09-20-paper-planes-flat-design.md` (an amendments section)

- [ ] **Step 1: `CLAUDE.md`**

Every place that counts boards has to move from fourteen to fifteen, and each claim has to stay true:

- "The first screen": fourteen cards becomes fifteen; page two holds three; say that the fifteenth cost the first screen nothing because `PER_PAGE` is twelve, and give the re-measured page-one and page-two draw calls if they moved.
- "The flat screens": add Paper Planes to the list with its spec and its `#planes` mock; add a bullet for it in the boards' own section, in the voice of the others — what it is, what its signature is (the launch and the wake), that it adds no character and no palette entry, that it is the second board to seat no character, and the measured draw calls and idle with their control.
- The bottom-slot list ("the fourteen screens want 458, 460, ...") gains a fifteenth number: **140**, the tip card alone, which ties Word Trail's for the shortest in the game.
- The "five buttons" sentence: four boards now carry five (Balance, Untangle, Word Trail, Paper Planes).
- The registry section: fifteen flat boards.

- [ ] **Step 2: The spec's amendments**

A final section recording what the build changed from the design and why — every sibling spec has one, and a claim that was overturned is more useful than one that was never tested.

- [ ] **Step 3: Full suite, and the sweep**

```bash
godot --headless --path . --script tests/run_tests.gd 2>&1 | tail -3
```
Expected: `0` failures.

- [ ] **Step 4: Commit**

```bash
git add CLAUDE.md docs/superpowers/specs/2026-09-20-paper-planes-flat-design.md
git commit -m "docs(planes): the fifteenth board in the record"
```
