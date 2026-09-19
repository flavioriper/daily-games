# Queens, flat: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Put a tenth flat board, Queens, on the first screen: seat one queen per row, column and coloured region with no two touching, a seated queen crossing out every cell she sees in a wave.

**Architecture:** The pattern every flat board follows here: a scene-free state class over a seeded generator (`puzzles/queens_state.gd`, `puzzles/queens_gen.gd`), a `PuzzleBase` Control that draws it as two cached meshes with the crowns as nodes in slots (`puzzles/queens2d.gd`), one new face species (`ui/faces/crown_face.gd`), Nonogram's tile tray taught to take a chip set, a registry line, a card picture, and the two harness branches. Every motion goes through `core/motion.gd`'s recipes and curve readers; the board's one signature is the wave, three constants of its own.

**Tech Stack:** Godot 4.7, GDScript, gl_compatibility renderer. Tests through `tests/run_tests.gd` (headless) and the windowed harnesses `tests/_win.gd`, `tests/_shot_anim.gd`, `tests/_shot_menu.gd`.

**Spec:** `docs/superpowers/specs/2026-09-19-queens-flat-design.md`. Concept page: `docs/brainstorm/concepts.html#queens` (built beside this plan; where the mock and this plan disagree on a drawing number, the mock wins and the spec is amended in Task 8).

## Global Constraints

- Branch: `feat/queens-flat`, already checked out. Commit after every task; never push (the user calls the push).
- Godot is `godot` on PATH; the project root is `/Users/flavioriper/dev/daily`. Headless suite: `godot --headless --path . --script res://tests/run_tests.gd` (currently 2086 checks, 0 failures; every task must leave it at 0 failures).
- Windowed harnesses need a display and must never overlap: run one at a time, and take two readings when a number matters.
- Godot re-saves `project.godot` with a header comment after a windowed run: `git checkout project.godot` before committing if it shows as modified.
- Never write an `instance uniform` in a shader. Never bake a drawing to an image. Faces are code (`ui/faces/`), drawn as cached meshes.
- A canvas command holds a mesh by RID: keep the mesh the last `_draw` handed over referenced (`_shown`) until the next one replaces it.
- Only `world/main.gd` starts `Analytics` and `Backend`; harnesses and tests stay silent.
- Copy: the board is "Queens", the motto `Every queen has her seat`, the footer `Seat · Cross · Reign`, the card blurb `One queen per row,\ncolumn and colour.`. The chips read `Queen` and `Cross`.
- Numbers from the spec: `SIZES := [7, 8, 9]`, `HINTS := 3`, `WAVE_STEP` 0.045 s, `WAVE_FLASH` 0.35, `AUTO_ALPHA` 0.75, `PAD` 34, bottom slot 460, `WIN_WAIT` 1.6.
- Comment style: every file opens with a `##` doc explaining what it is and why, in prose, naming the spec section. Constants carry a `##` line when the number is a decision.

---

## File structure

| File | Task | Responsibility |
|---|---|---|
| `puzzles/queens_gen.gd` (new) | 1 | Queens first, regions grown from them, uniqueness proved. Pure functions, seeded only by the `rng` handed in. |
| `tests/test_queens.gd` (new), `tests/run_tests.gd` | 1, 2 | Generator and state checks. |
| `puzzles/queens_state.gd` (new) | 2 | The rules with no scene: regions, queens, the player's crosses, the derived crosses, every move, undo, hint, solved. |
| `core/palette.gd` | 3 | `REGION` (nine pastels) and `QUEEN_WASH`. |
| `ui/faces/crown_face.gd` (new) | 3 | The queen: a gold crown with a face, `pinned` for a hint's. |
| `ui/flat/tile_tray.gd`, `ui/flat/flat_host.gd` | 4 | The tray takes a chip set; `"tray": "crowns"`. |
| `puzzles/queens2d.gd` (new) | 5 | The board: court, meshes, crowns in slots, the wave, input, the sprout's lines, the win. |
| `ui/registry.gd`, `tests/_win.gd` | 5 | Queens in the grid, Snake Apple's `soon` card out; the solve branch. |
| `tests/_shot_anim.gd` | 6 | The tap branch; the strip and the measurements. |
| `ui/menu/card_art.gd` | 7 | The card's picture. |
| `CLAUDE.md`, `docs/art/flat-motion.md`, the spec | 8 | The record. |

---

### Task 1: The generator

**Files:**
- Create: `puzzles/queens_gen.gd`
- Create: `tests/test_queens.gd`
- Modify: `tests/run_tests.gd:15-34` (the `suites` dictionary)

**Interfaces:**
- Produces: `QueensGen.generate(rng: RandomNumberGenerator, n: int) -> Dictionary` with keys `region: Array` (`[r][c] -> int` region index 0..n-1), `solution: PackedInt32Array` (row -> column), `n: int`, `ok: bool`; `QueensGen.solve_count(region: Array, n: int, limit: int) -> int`; `QueensGen.legal(region: Array, n: int, cols: PackedInt32Array) -> bool`; `QueensGen.DIRS`.

- [ ] **Step 1: Write the failing test**

Create `tests/test_queens.gd`:

```gdscript
extends RefCounted

const Gen = preload("res://puzzles/queens_gen.gd")

static func run(t) -> void:
	_test_generator(t)

static func _test_generator(t) -> void:
	for n in [7, 8, 9]:
		for i in range(5):
			var rng := RandomNumberGenerator.new()
			rng.seed = 7000 + n * 100 + i
			var out: Dictionary = Gen.generate(rng, n)
			var tag := "%dx%d seed=%d" % [n, n, i]
			t.check(out.ok, "%s generated a puzzle" % tag)
			if not out.ok:
				continue
			t.eq(out.solution.size(), n, "%s has one queen per row" % tag)
			t.check(Gen.legal(out.region, n, out.solution), "%s answer is legal" % tag)
			t.eq(Gen.solve_count(out.region, n, 3), 1, "%s is uniquely solvable" % tag)
			# Every region holds exactly one of the answer's queens, and every
			# cell belongs to a region.
			var seen: Dictionary = {}
			for r in n:
				var g := int(out.region[r][int(out.solution[r])])
				t.check(not seen.has(g), "%s region %d holds one queen" % [tag, g])
				seen[g] = true
			var covered := true
			for r in n:
				for c in n:
					var g := int(out.region[r][c])
					if g < 0 or g >= n:
						covered = false
			t.check(covered, "%s every cell has a region" % tag)
			# Regions are connected: a flood from any cell of a region reaches
			# every cell of it.
			t.check(_connected(out.region, n), "%s every region is connected" % tag)
	# Two queens on neighbouring rows a column apart touch at a corner.
	var flat: Array = [[0, 0, 1], [0, 1, 1], [2, 2, 2]]
	t.check(not Gen.legal(flat, 3, PackedInt32Array([0, 1, 2])), "queens touching at a corner are illegal")
	t.check(not Gen.legal(flat, 3, PackedInt32Array([0, 2, 0])), "two queens in one column are illegal")
	# The same seed twice is the same board.
	var a := RandomNumberGenerator.new()
	a.seed = 4242
	var b := RandomNumberGenerator.new()
	b.seed = 4242
	t.check(Gen.generate(a, 7).region == Gen.generate(b, 7).region, "the same seed gives the same court")

static func _connected(region: Array, n: int) -> bool:
	for g in n:
		var cells: Array = []
		for r in n:
			for c in n:
				if int(region[r][c]) == g:
					cells.append(Vector2i(c, r))
		if cells.is_empty():
			return false
		var reached: Dictionary = {cells[0]: true}
		var stack: Array = [cells[0]]
		while not stack.is_empty():
			var p: Vector2i = stack.pop_back()
			for d in Gen.DIRS:
				var q: Vector2i = p + d
				if q.x < 0 or q.y < 0 or q.x >= n or q.y >= n:
					continue
				if int(region[q.y][q.x]) == g and not reached.has(q):
					reached[q] = true
					stack.append(q)
		if reached.size() != cells.size():
			return false
	return true
```

Register it in `tests/run_tests.gd`: after the line `"nonogram": "res://tests/test_nonogram.gd",` add

```gdscript
		"queens": "res://tests/test_queens.gd",
```

- [ ] **Step 2: Run the suite to verify it fails**

Run: `godot --headless --path . --script res://tests/run_tests.gd 2>&1 | tail -5`
Expected: `FAIL [queens] could not load suite` (the generator script does not exist), failure count 1.

- [ ] **Step 3: Write the generator**

Create `puzzles/queens_gen.gd`:

```gdscript
extends RefCounted

## Queens. Seat one queen in every row, every column and every coloured
## region, and never let two queens touch, not even at a corner -- the
## no-touch rule of the game most players know, chosen over chess diagonals
## because the regions carry the deductions.
##
## The board is generated in the easy direction and proved in the hard one:
## the queens are placed first (a permutation with the no-touch rule, found
## row by row with backtracking), one region is grown out of each queen by
## random orthogonal growth so every region is connected and holds exactly
## one queen of the answer, and then the answer is proved the only one with
## the same row-by-row search stopping at two. A board is kept only when it
## answers one. Regions grow at uneven speeds (a random weight each), which
## gives the small regions a unique answer needs and shapes worth reading.
##
## Seeded only by the `rng` handed in, so a day is the same court on every
## phone. Spec: docs/superpowers/specs/2026-09-19-queens-flat-design.md,
## section 4.

const DIRS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
## How many courts to try before giving the last one back unproved.
const ATTEMPTS := 200
## The slowest region grows at this fraction of the fastest.
const WEIGHT_MIN := 0.15

static func generate(rng: RandomNumberGenerator, n: int) -> Dictionary:
	var last: Dictionary = {}
	for _attempt in ATTEMPTS:
		var queens := _place_queens(rng, n)
		if queens.is_empty():
			continue
		var region := _grow_regions(rng, n, queens)
		last = {"region": region, "solution": queens, "n": n, "ok": false}
		if solve_count(region, n, 2) == 1:
			last.ok = true
			return last
	if last.is_empty():
		return {"region": [], "solution": PackedInt32Array(), "n": n, "ok": false}
	return last

## How many seatings `region` allows, up to `limit`.
static func solve_count(region: Array, n: int, limit: int) -> int:
	var cols := PackedInt32Array()
	cols.resize(n)
	return _count(region, n, 0, cols, {}, {}, limit)

## Whether `cols` (row -> column) is a full legal seating on `region`.
static func legal(region: Array, n: int, cols: PackedInt32Array) -> bool:
	if cols.size() != n:
		return false
	var used_col: Dictionary = {}
	var used_reg: Dictionary = {}
	for r in n:
		var c := int(cols[r])
		if c < 0 or c >= n or used_col.has(c):
			return false
		if r > 0 and absi(int(cols[r - 1]) - c) <= 1:
			return false
		var g := int(region[r][c])
		if used_reg.has(g):
			return false
		used_col[c] = true
		used_reg[g] = true
	return true

static func _count(region: Array, n: int, r: int, cols: PackedInt32Array,
		used_col: Dictionary, used_reg: Dictionary, limit: int) -> int:
	if r == n:
		return 1
	var found := 0
	for c in n:
		if used_col.has(c):
			continue
		# One queen per row means only the row above can touch this one.
		if r > 0 and absi(int(cols[r - 1]) - c) <= 1:
			continue
		var g := int(region[r][c])
		if used_reg.has(g):
			continue
		cols[r] = c
		used_col[c] = true
		used_reg[g] = true
		found += _count(region, n, r + 1, cols, used_col, used_reg, limit - found)
		used_col.erase(c)
		used_reg.erase(g)
		if found >= limit:
			return found
	return found

## A random legal permutation: row by row in a shuffled column order,
## backtracking when a column repeats or the queen touches the one above.
static func _place_queens(rng: RandomNumberGenerator, n: int) -> PackedInt32Array:
	var cols := PackedInt32Array()
	cols.resize(n)
	if _fill_row(rng, n, 0, cols, {}):
		return cols
	return PackedInt32Array()

static func _fill_row(rng: RandomNumberGenerator, n: int, r: int, cols: PackedInt32Array,
		used: Dictionary) -> bool:
	if r == n:
		return true
	var order: Array = range(n)
	_shuffle(order, rng)
	for c in order:
		if used.has(c):
			continue
		if r > 0 and absi(int(cols[r - 1]) - int(c)) <= 1:
			continue
		cols[r] = c
		used[c] = true
		if _fill_row(rng, n, r + 1, cols, used):
			return true
		used.erase(c)
	return false

## Region i starts on queen i's cell. Until every cell is claimed, a region is
## picked by weight and given a random free cell touching one of its own.
static func _grow_regions(rng: RandomNumberGenerator, n: int, queens: PackedInt32Array) -> Array:
	var region: Array = []
	for r in n:
		var row: Array = []
		row.resize(n)
		row.fill(-1)
		region.append(row)
	var owned: Array = []      # per region, the cells it holds that may still have a free neighbour
	var weight: Array = []
	for i in n:
		region[i][int(queens[i])] = i
		owned.append([Vector2i(int(queens[i]), i)])
		weight.append(rng.randf_range(WEIGHT_MIN, 1.0))
	var free := n * n - n
	while free > 0:
		var i := _pick(rng, owned, weight)
		var cells: Array = owned[i]
		var k := rng.randi_range(0, cells.size() - 1)
		var from: Vector2i = cells[k]
		var options: Array = []
		for d in DIRS:
			var p: Vector2i = from + d
			if p.x >= 0 and p.y >= 0 and p.x < n and p.y < n and int(region[p.y][p.x]) < 0:
				options.append(p)
		if options.is_empty():
			# This cell has nothing left to give; it will never regain a free
			# neighbour, so it leaves the region's frontier for good.
			cells.remove_at(k)
			continue
		var to: Vector2i = options[rng.randi_range(0, options.size() - 1)]
		region[to.y][to.x] = i
		cells.append(to)
		free -= 1
	return region

## A region with cells still on its frontier, chosen by weight.
static func _pick(rng: RandomNumberGenerator, owned: Array, weight: Array) -> int:
	var total := 0.0
	for i in owned.size():
		if not (owned[i] as Array).is_empty():
			total += float(weight[i])
	var roll := rng.randf() * total
	for i in owned.size():
		if (owned[i] as Array).is_empty():
			continue
		roll -= float(weight[i])
		if roll <= 0.0:
			return i
	for i in owned.size():
		if not (owned[i] as Array).is_empty():
			return i
	return 0

static func _shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
```

- [ ] **Step 4: Run the suite to verify it passes**

Run: `godot --headless --path . --script res://tests/run_tests.gd 2>&1 | tail -3`
Expected: the last line reports 0 failures and a count above 2086.

If any `generated a puzzle` check fails, the uniqueness rate is too low for 200 attempts at that size: raise `ATTEMPTS` to 400 first, and if it still fails lower `WEIGHT_MIN` to 0.08 (more uneven regions are more often unique). Record what you changed in the commit message.

- [ ] **Step 5: Time the generator**

Write `/tmp/_queens_time.gd` (throwaway, not committed):

```gdscript
extends SceneTree

const Gen = preload("res://puzzles/queens_gen.gd")

func _initialize() -> void:
	for n in [7, 8, 9]:
		var worst := 0
		var total := 0
		var fails := 0
		for i in 20:
			var rng := RandomNumberGenerator.new()
			rng.seed = 9000 + n * 100 + i
			var t0 := Time.get_ticks_usec()
			var out: Dictionary = Gen.generate(rng, n)
			var ms := int((Time.get_ticks_usec() - t0) / 1000)
			total += ms
			worst = maxi(worst, ms)
			if not out.ok:
				fails += 1
		print("n=%d mean=%d ms worst=%d ms fails=%d/20" % [n, total / 20, worst, fails])
	quit()
```

Run: `godot --headless --path . --script /tmp/_queens_time.gd 2>&1 | grep 'n='`
Expected: three lines; the spec's target is a mean under 100 ms and no fails for n=9 on this Mac. Write the three lines down for Task 8's Measured section. If n=9 is over 100 ms mean, lower `ATTEMPTS`' cost rather than the count: add the cheapest pruning to `_count`, a check that the region of the cell being tried still has at least one cell in a later row or this one when it is not the last (skip it), and re-time. Report the numbers either way; do not spend more than one such pass.

- [ ] **Step 6: Commit**

```bash
git add puzzles/queens_gen.gd puzzles/queens_gen.gd.uid tests/test_queens.gd tests/run_tests.gd
git commit -m "feat(queens): the generator, queens first and regions grown, proved unique"
```

(Godot writes a `.uid` beside every new script on first load; commit it with the script. If it is not there yet, the headless run creates it.)

---

### Task 2: The state

**Files:**
- Create: `puzzles/queens_state.gd`
- Modify: `tests/test_queens.gd` (append the state checks)

**Interfaces:**
- Consumes: `QueensGen.generate`, `QueensGen.legal`, `QueensGen.DIRS`.
- Produces: `QueensState` with constants `BLANK 0, QUEEN 1, CROSS 2, AUTO 3, HINTS 3, SIZES [7, 8, 9], OK 0, SEEN 1, PINNED 2`; fields `n, region, solution, queens: Dictionary, crosses: Dictionary, locked: Dictionary, seen: Dictionary, history: Array`; readers `in_field(cell) -> bool`, `region_at(cell) -> int`, `mark_at(cell) -> int`, `is_seen(cell) -> bool`, `sees(q) -> Array`, `static distance(a, b) -> int`, `queens_left() -> int`, `recompute()`; moves `seat(cell) -> Dictionary {ok, why}`, `lift(cell) -> Dictionary {ok, why}`, `cross(cell) -> bool`, `uncross(cell) -> bool`, `sweep(cells: Array, on: bool) -> Array`, `undo() -> Array`, `hint() -> Dictionary {cell, lifted}`, `wrong_queens() -> Array`, `reset() -> Array`, `is_solved() -> bool`, `share_glyphs() -> String`.

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_queens.gd`: add the preload and call at the top,

```gdscript
const State = preload("res://puzzles/queens_state.gd")
```

change `run` to

```gdscript
static func run(t) -> void:
	_test_generator(t)
	_test_state(t)
```

and add at the end of the file:

```gdscript
## A 5x5 court by hand, whose answer is forced cell by cell: region 4 is the
## one cell (4,4), so its queen is given; row 3's region 3 then has only
## (2,3) clear of her; region 2 then only (0,2); region 0 only (1,0); and
## region 1 takes (3,1). Answer (row -> col): [1, 3, 0, 2, 4].
##   region:  0 0 0 1 1
##            0 0 1 1 1
##            2 2 1 1 1
##            2 2 3 3 3
##            2 2 3 3 4
static func _court() -> State:
	var s := State.new()
	s.n = 5
	s.region = [
		[0, 0, 0, 1, 1],
		[0, 0, 1, 1, 1],
		[2, 2, 1, 1, 1],
		[2, 2, 3, 3, 3],
		[2, 2, 3, 3, 4],
	]
	s.solution = PackedInt32Array([1, 3, 0, 2, 4])
	s.queens = {}
	s.crosses = {}
	s.locked = {}
	s.history = []
	s.recompute()
	return s

static func _test_state(t) -> void:
	var s := _court()
	t.check(Gen.legal(s.region, 5, s.solution), "the hand court's answer is legal")
	t.eq(Gen.solve_count(s.region, 5, 3), 1, "the hand court has one answer")
	t.eq(s.mark_at(Vector2i(0, 0)), State.BLANK, "a bare court is blank")

	# Seat a queen: her row, column, region and eight neighbours are seen.
	var q := Vector2i(2, 1)
	var res: Dictionary = s.seat(q)
	t.check(res.ok, "a queen seats on a bare cell")
	t.eq(s.mark_at(q), State.QUEEN, "the cell holds the queen")
	t.eq(s.mark_at(Vector2i(4, 1)), State.AUTO, "her row is crossed")
	t.eq(s.mark_at(Vector2i(2, 4)), State.AUTO, "her column is crossed")
	t.eq(s.mark_at(Vector2i(4, 0)), State.AUTO, "her region is crossed")
	t.eq(s.mark_at(Vector2i(1, 2)), State.AUTO, "her diagonal neighbour is crossed")
	t.eq(s.mark_at(Vector2i(0, 4)), State.BLANK, "a cell she cannot see stays blank")
	# Her row (4), her column (4), the rest of her region ((3,0), (4,0), (3,2),
	# (4,2)) and the two neighbours not already counted ((1,0), (1,2)).
	t.eq(s.sees(q).size(), 14, "she sees fourteen cells on this court")
	t.eq(State.distance(q, Vector2i(4, 4)), 3, "distance is the king's move")

	# A crown on a seen cell is refused; on a given queen, too.
	res = s.seat(Vector2i(4, 1))
	t.check(not res.ok and res.why == State.SEEN, "a seen cell refuses a queen")
	t.eq(s.history.size(), 1, "a refusal is not a move")

	# The player's cross, and a queen replacing it.
	t.check(s.cross(Vector2i(0, 4)), "a cross lays on a bare cell")
	t.eq(s.mark_at(Vector2i(0, 4)), State.CROSS, "the player's cross is her own")
	t.check(not s.cross(Vector2i(4, 1)), "a cross does not lay on a seen cell")
	t.check(not s.cross(q), "a cross does not lay on a queen")
	t.check(s.seat(Vector2i(0, 4)).ok, "a queen replaces the player's cross")
	t.eq(s.queens.size(), 2, "two queens seated")
	t.eq(s.queens_left(), 3, "three to go")

	# Undo takes the queen off and the cross comes back; undo again and the
	# cross goes too.
	t.eq(s.undo().size(), 1, "undo returns the one cell")
	t.eq(s.mark_at(Vector2i(0, 4)), State.CROSS, "undoing a seat restores the cross")
	s.undo()
	t.eq(s.mark_at(Vector2i(0, 4)), State.BLANK, "undoing a cross clears it")

	# Lift the queen: her crosses leave with her.
	res = s.lift(q)
	t.check(res.ok, "a queen lifts")
	t.eq(s.mark_at(Vector2i(4, 1)), State.BLANK, "her crosses leave with her")
	t.eq(s.seen.size(), 0, "nothing is seen on an empty court")
	s.undo()
	t.eq(s.mark_at(q), State.QUEEN, "undoing a lift seats her again")
	t.eq(s.mark_at(Vector2i(4, 1)), State.AUTO, "and her crosses return")

	# A sweep is one move however many cells it crossed, and skips seen cells.
	var path: Array = [Vector2i(0, 4), Vector2i(1, 4), Vector2i(2, 4), Vector2i(3, 4)]
	var changed: Array = s.sweep(path, true)
	t.eq(changed.size(), 3, "a sweep skips the cell the queen sees")
	t.eq(s.mark_at(Vector2i(1, 4)), State.CROSS, "a swept cell is crossed")
	s.undo()
	t.eq(s.mark_at(Vector2i(1, 4)), State.BLANK, "one undo takes the whole sweep back")
	s.sweep(path, true)
	changed = s.sweep([Vector2i(0, 4), Vector2i(1, 4)], false)
	t.eq(changed.size(), 2, "a rub-out takes the player's crosses")
	t.eq(s.mark_at(Vector2i(0, 4)), State.BLANK, "a rubbed-out cell is blank")

	# The hint seats the first missing answer queen, lifting a wrong queen in
	# its way, and pins it.
	var s2 := _court()
	s2.seat(Vector2i(2, 0))   # wrong: the answer's row 0 queen is at column 1
	var out: Dictionary = s2.hint()
	t.eq(out.cell, Vector2i(1, 0), "the hint seats row 0's answer")
	t.eq(out.lifted, [Vector2i(2, 0)], "the wrong queen beside it is lifted")
	t.eq(s2.mark_at(Vector2i(2, 0)), State.AUTO, "the lifted queen's cell is now seen")
	t.check(s2.locked.has(Vector2i(1, 0)), "the hint's queen is pinned")
	t.check(s2.history.is_empty(), "a hint clears the history")
	res = s2.lift(Vector2i(1, 0))
	t.check(not res.ok and res.why == State.PINNED, "a pinned queen refuses to lift")
	t.eq(s2.wrong_queens().size(), 0, "no wrong queens after the hint")

	# Reset keeps the given queen and clears the rest.
	s2.seat(Vector2i(3, 2))
	s2.cross(Vector2i(0, 4))
	var cleared: Array = s2.reset()
	t.eq(cleared.size(), 2, "reset clears the player's queen and cross")
	t.eq(s2.mark_at(Vector2i(1, 0)), State.QUEEN, "reset keeps the given queen")

	# Seat the answer: the fifth queen is the win.
	var s3 := _court()
	for r in 5:
		t.check(not s3.is_solved(), "not solved with %d queens" % r)
		t.check(s3.seat(Vector2i(int(s3.solution[r]), r)).ok, "answer queen %d seats" % r)
	t.check(s3.is_solved(), "the answer is solved")
	t.eq(s3.queens_left(), 0, "none to go")
	t.eq(s3.share_glyphs().split("\n").size(), 6, "five rows and a trailing newline")
	t.check(s3.share_glyphs().contains("👑"), "the share carries a crown")
```

- [ ] **Step 2: Run the suite to verify it fails**

Run: `godot --headless --path . --script res://tests/run_tests.gd 2>&1 | tail -5`
Expected: `FAIL [queens] could not load suite` (the state preload fails).

- [ ] **Step 3: Write the state**

Create `puzzles/queens_state.gd`:

```gdscript
extends RefCounted

## Queens' rules, with no scene under them: the court's regions, the queens,
## the crosses the player laid, the crosses the queens lay, and every move
## that can change them. The flat board (puzzles/queens2d.gd) draws this and
## nothing else.
##
## Two things decide the game's feel and are worth stating plainly. **A cell
## is crossed while any queen sees it**: `seen` counts, per cell, the queens
## whose row, column, region or eight neighbours it is in, rebuilt after
## every change and never stored, so lifting a queen takes her crosses with
## her and undo needs no bookkeeping for them. **And a crown on a seen cell is
## refused**: the cell is provably unavailable given the queens on the board,
## so the board says so rather than seating a queen that must be wrong. The
## consequence is that two queens can never conflict, and the n-th queen
## seated is the win.
##
## A gesture is a move: a sweep of crosses is one history entry and comes
## back on one undo. The win is checked against the rules (one per row,
## column and region, no two touching) and not against the stored answer;
## the generator proves the two agree.
## Spec: docs/superpowers/specs/2026-09-19-queens-flat-design.md, section 3.

const Gen = preload("res://puzzles/queens_gen.gd")

## What is on a cell. AUTO is a cross a queen laid: seen, and not the
## player's own.
const BLANK := 0
const QUEEN := 1
const CROSS := 2
const AUTO := 3
const HINTS := 3
## The ladder: easy, medium, hard. The menu opens medium.
const SIZES := [7, 8, 9]
## Why a seat or a lift was turned down.
const OK := 0
const SEEN := 1
const PINNED := 2
## The share's squares, one per region index; a crown marks a queen.
const SQUARES := ["🟫", "🟪", "🟦", "🟩", "🟧", "⬜", "🟨", "🟥", "⬛"]

var n: int = 7
var region: Array = []              # [r][c] -> region index
var solution := PackedInt32Array()  # row -> the answer's column
var queens: Dictionary = {}         # Vector2i -> true
var crosses: Dictionary = {}        # Vector2i -> true, the player's own
var locked: Dictionary = {}         # Vector2i -> true, a queen a hint seated
## Vector2i -> how many queens see it. Absent means none does. Derived.
var seen: Dictionary = {}
## One entry per gesture, newest last: [{"cell": Vector2i, "prev": int}].
var history: Array = []

func setup(rng: RandomNumberGenerator, difficulty: int) -> void:
	n = int(SIZES[clampi(difficulty, 0, SIZES.size() - 1)])
	var out: Dictionary = Gen.generate(rng, n)
	region = out.region
	solution = out.solution
	queens = {}
	crosses = {}
	locked = {}
	history = []
	recompute()

# --- reading the court ---

func in_field(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < n and cell.y < n

func region_at(cell: Vector2i) -> int:
	return int(region[cell.y][cell.x]) if in_field(cell) else -1

func mark_at(cell: Vector2i) -> int:
	if queens.has(cell):
		return QUEEN
	if crosses.has(cell):
		return CROSS
	if int(seen.get(cell, 0)) > 0:
		return AUTO
	return BLANK

func is_seen(cell: Vector2i) -> bool:
	return int(seen.get(cell, 0)) > 0

## Every cell a queen at `q` rules out: her row, her column, her region and
## her eight neighbours, without herself.
func sees(q: Vector2i) -> Array:
	var out: Array = []
	if not in_field(q):
		return out
	var g := region_at(q)
	for y in n:
		for x in n:
			var cell := Vector2i(x, y)
			if cell == q:
				continue
			if cell.y == q.y or cell.x == q.x or int(region[y][x]) == g \
					or (absi(cell.x - q.x) <= 1 and absi(cell.y - q.y) <= 1):
				out.append(cell)
	return out

## The king's move between two cells: the ring of the wave a cell is on.
static func distance(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))

func queens_left() -> int:
	return n - queens.size()

## Rebuilds `seen` from the queens on the court.
func recompute() -> void:
	seen = {}
	for q in queens:
		for cell in sees(q):
			seen[cell] = int(seen.get(cell, 0)) + 1

# --- moves ---

## Seats a queen on `cell`. Refused on a seen cell (SEEN); a queen already
## there is nothing to do (OK, not ok). The player's own cross there is
## replaced.
func seat(cell: Vector2i) -> Dictionary:
	if not in_field(cell) or queens.has(cell):
		return {"ok": false, "why": OK}
	if is_seen(cell):
		return {"ok": false, "why": SEEN}
	history.append([{"cell": cell, "prev": mark_at(cell)}])
	crosses.erase(cell)
	queens[cell] = true
	recompute()
	return {"ok": true, "why": OK}

## Takes a queen off `cell`. A hint's queen stays (PINNED).
func lift(cell: Vector2i) -> Dictionary:
	if not queens.has(cell):
		return {"ok": false, "why": OK}
	if locked.has(cell):
		return {"ok": false, "why": PINNED}
	history.append([{"cell": cell, "prev": QUEEN}])
	queens.erase(cell)
	recompute()
	return {"ok": true, "why": OK}

## Lays the player's cross on a bare cell. True when it did.
func cross(cell: Vector2i) -> bool:
	if not in_field(cell) or mark_at(cell) != BLANK:
		return false
	history.append([{"cell": cell, "prev": BLANK}])
	crosses[cell] = true
	return true

## Takes the player's own cross off. True when it did.
func uncross(cell: Vector2i) -> bool:
	if not crosses.has(cell):
		return false
	history.append([{"cell": cell, "prev": CROSS}])
	crosses.erase(cell)
	return true

## A sweep: lays the player's crosses on every bare cell of `cells` (`on`),
## or takes the player's crosses off every cell of `cells` that has one.
## One history entry for the lot, so one undo. Returns the cells that changed.
func sweep(cells: Array, on: bool) -> Array:
	var entry: Array = []
	var changed: Array = []
	for cell in cells:
		if on:
			if mark_at(cell) != BLANK:
				continue
			entry.append({"cell": cell, "prev": BLANK})
			crosses[cell] = true
		else:
			if not crosses.has(cell):
				continue
			entry.append({"cell": cell, "prev": CROSS})
			crosses.erase(cell)
		changed.append(cell)
	if not entry.is_empty():
		history.append(entry)
	return changed

## Takes back the last gesture. Returns the cells it touched.
func undo() -> Array:
	if history.is_empty():
		return []
	var entry: Array = history.pop_back()
	var touched: Array = []
	for e in entry:
		var cell: Vector2i = e.cell
		queens.erase(cell)
		crosses.erase(cell)
		match int(e.prev):
			QUEEN: queens[cell] = true
			CROSS: crosses[cell] = true
		touched.append(cell)
	recompute()
	return touched

## Seats the answer's queen in the first row that lacks her and pins her. A
## seated queen who sees that cell is wrong, and is lifted first. Clears the
## history: what came before no longer describes a board that can be gone
## back to. Returns {"cell": the seat, or (-1, -1) when every row has its
## queen, "lifted": the queens taken off}.
func hint() -> Dictionary:
	for r in n:
		var target := Vector2i(int(solution[r]), r)
		if queens.has(target):
			continue
		var lifted: Array = []
		for q in queens.keys():
			if sees(q).has(target):
				lifted.append(q)
		for q in lifted:
			queens.erase(q)
		crosses.erase(target)
		queens[target] = true
		locked[target] = true
		history = []
		recompute()
		return {"cell": target, "lifted": lifted}
	return {"cell": Vector2i(-1, -1), "lifted": []}

## Every seated queen the answer does not seat there. Check counts these.
func wrong_queens() -> Array:
	var out: Array = []
	for q in queens:
		if int(solution[q.y]) != q.x:
			out.append(q)
	return out

## Clears the player's queens and crosses; a hint's queens stay, and the
## history goes. Returns the cells cleared.
func reset() -> Array:
	var cleared: Array = []
	for q in queens.keys():
		if not locked.has(q):
			queens.erase(q)
			cleared.append(q)
	cleared.append_array(crosses.keys())
	crosses = {}
	history = []
	recompute()
	return cleared

## n queens seated and the rules hold. Checked against the rules, not the
## stored answer.
func is_solved() -> bool:
	if region.is_empty() or queens.size() != n:
		return false
	var cols := PackedInt32Array()
	cols.resize(n)
	cols.fill(-1)
	for q in queens:
		if int(cols[q.y]) >= 0:
			return false
		cols[q.y] = q.x
	return Gen.legal(region, n, cols)

## One row per line: a crown for a queen and a coloured square for every
## other cell, by region, so a shared court carries its regions.
func share_glyphs() -> String:
	var out := ""
	for y in n:
		for x in n:
			var cell := Vector2i(x, y)
			if queens.has(cell):
				out += "👑"
			else:
				out += str(SQUARES[int(region[y][x]) % SQUARES.size()])
		out += "\n"
	return out
```

- [ ] **Step 4: Run the suite to verify it passes**

Run: `godot --headless --path . --script res://tests/run_tests.gd 2>&1 | tail -3`
Expected: 0 failures. The expected counts were derived by hand from the diagram in the test's comment; if one fails, the rule is wrong, not the number.

- [ ] **Step 5: Commit**

```bash
git add puzzles/queens_state.gd puzzles/queens_state.gd.uid tests/test_queens.gd
git commit -m "feat(queens): the state, derived crosses and the refusal, every move under test"
```

---

### Task 3: The palette block and the crown

**Files:**
- Modify: `core/palette.gd` (insert a block before the line beginning `# Horse Pen (the design agreed`)
- Create: `ui/faces/crown_face.gd`
- Modify: `tests/test_queens.gd` (two palette checks)

**Interfaces:**
- Produces: `Pal.REGION` (an Array of nine Colors, taken by region index), `Pal.QUEEN_WASH: Color`; `CrownFace extends Face` with `var pinned: bool`, `const SEAT := 2.0` (the rect a crown of radius R needs is `SEAT * R` square), `_kind()` `"crown0"`/`"crown1"`, one layer `"body"` carrying the face.

- [ ] **Step 1: Write the failing palette checks**

In `tests/test_queens.gd`, add to `run`:

```gdscript
static func run(t) -> void:
	_test_generator(t)
	_test_state(t)
	_test_palette(t)
```

and append:

```gdscript
static func _test_palette(t) -> void:
	var Pal = load("res://core/palette.gd")
	t.eq(Pal.REGION.size(), 9, "nine region pastels, one per region of the hard board")
	for i in Pal.REGION.size():
		for j in range(i + 1, Pal.REGION.size()):
			t.check(Pal.REGION[i] != Pal.REGION[j], "REGION %d and %d differ" % [i, j])
		# A pastel, not a saturated chip: light enough to carry ink and a
		# grey pebble on it.
		t.check(Pal.REGION[i].get_luminance() > 0.55, "REGION %d is light enough for a piece on it" % i)
```

- [ ] **Step 2: Run the suite to verify it fails**

Run: `godot --headless --path . --script res://tests/run_tests.gd 2>&1 | grep -c 'FAIL \[queens\]'`
Expected: at least 1 (`REGION` does not exist; the suite reports the queens checks as failures, or aborts the queens suite with a script error, either way a non-zero failure count).

- [ ] **Step 3: Add the palette block**

Open `docs/brainstorm/concepts.html`, find the Queens tab's IIFE (search for `getElementById('qn')`) and read its `REGION` (or equivalently named) array of nine hex strings. Use those values below in place of the defaults, in the same order, so the game and the mock are the same drawing. If the tab is not there yet, keep the defaults.

Insert into `core/palette.gd` before the line beginning `# Horse Pen (the design agreed`:

```gdscript
# Queens (docs/superpowers/specs/2026-09-19-queens-flat-design.md, section
# 5): a court cut into as many coloured regions as it has rows, under an ink
# frame and ink seams, on the parchment card. Nine pastels taken by region
# index and spread round the wheel so no two neighbours share a family: the
# seam does the separating and the colour is the region's name. The ten
# *_TILE chip tints above are too pale to hold nine regions apart on
# parchment, which is why these are their own block. The mock's own values
# (docs/art/concept-queens.png, docs/brainstorm/concepts.html#queens).
const REGION := [
	Color("d9cbb0"),   # tan
	Color("c9b7ea"),   # lavender
	Color("b9d4f6"),   # sky
	Color("c5e8b5"),   # mint
	Color("f8d3a0"),   # apricot
	Color("e2e3e6"),   # silver
	Color("eef0a3"),   # lemon
	Color("f7a385"),   # coral
	Color("f6c0d4"),   # rose
]
## The gold the wave leaves on a cell for a moment as a queen's reach arrives:
## the crown's own colour, laid over the region at WAVE_FLASH.
const QUEEN_WASH := SUN
```

- [ ] **Step 4: Run the suite to verify it passes**

Run: `godot --headless --path . --script res://tests/run_tests.gd 2>&1 | tail -3`
Expected: 0 failures.

- [ ] **Step 5: Write the crown**

Create `ui/faces/crown_face.gd`:

```gdscript
extends "res://ui/faces/face.gd"

## The queen: a gold crown with a face on its band, the flat Queens' whole
## cast and the tenth screen's one new species. The bar for adding one is
## the snail's (ui/faces/snail_face.gd): nothing in the cast does what this
## needs. Nothing in it is a queen, and the crown is the one thing the board
## seats, so it earns the exception.
##
## Three points over a band, the middle one taller, a deeper edge along the
## band's foot and a highlight on its shoulder; a small deep gem on each
## outer point, and on the middle point a leaf-green gem when `pinned` -- a
## queen a hint seated, the given look every board wears in green. HAPPY at
## rest, JOY on the win, STRAIN for a beat when the finger is refused on her.
## One layer, one cached mesh per state, shared by every crown on the board.
## No shadow layer: the board draws the soft disc under her on its own
## ground, so a hopping crown leaves it behind (ui/faces/court_lantern.gd's
## `casts` false, always).
##
## Every measure is in R, and the drawing is 1.8 R across and runs from the
## middle tip at -1.06 R to the band's foot at 0.78 R, so a rect `px` square
## holds it with R = px / 2 (SEAT). Ported number for number from the canvas
## mock (docs/brainstorm/concepts.html#queens, `crown`); where this file and
## the mock disagree, the mock is right and this is amended.
## Spec: docs/superpowers/specs/2026-09-19-queens-flat-design.md, section 5.

## The rect a crown of radius R needs, in R.
const SEAT := 2.0
const BAND_TOP := -0.1
const BAND_BOTTOM := 0.78
const BAND_HALF := 0.9
const BAND_RADIUS := 0.16
## The deeper edge along the band's foot.
const EDGE := 0.12
## The three points: the outer tips and the taller middle one.
const TIP_X := 0.66
const TIP_Y := -0.98
const MID_Y := -1.06
const TIP_R := 0.15
## Where the points meet between the tips, in R.
const NOTCH := Vector2(0.33, -0.3)
const GEM_R := 0.11
const HI_AT := Vector2(-0.72, 0.0)
const HI_SIZE := Vector2(0.3, 0.1)
const HI_RADIUS := 0.05
const HI_ALPHA := 0.28
## The face sits on the band, a little below its middle, at this R.
const FACE_R := 0.6
const FACE_AT := Vector2(0.0, 0.3)

## A queen a hint seated, who can never be lifted again.
var pinned: bool = false:
	set(v):
		pinned = v
		queue_redraw()

func _kind() -> String:
	return "crown%d" % int(pinned)

func _radius_for(px: float) -> float:
	return px / SEAT

func _layers() -> Array:
	return [["body", true]]

func _build_layer(name: String, R: float, eye: float, b: Builder) -> void:
	if name != "body":
		return
	var body: Color = Pal.SUN
	var deep: Color = Pal.SUN_DEEP
	# The points, one concave outline from shoulder to shoulder, with a disc
	# on each tip so the points are rounded rather than sharp.
	var points := PackedVector2Array([
		Vector2(-BAND_HALF, BAND_TOP + 0.2) * R,
		Vector2(-TIP_X, TIP_Y) * R,
		Vector2(-NOTCH.x, NOTCH.y) * R,
		Vector2(0.0, MID_Y) * R,
		Vector2(NOTCH.x, NOTCH.y) * R,
		Vector2(TIP_X, TIP_Y) * R,
		Vector2(BAND_HALF, BAND_TOP + 0.2) * R,
	])
	b.polygon(points, body)
	for tip in [Vector2(-TIP_X, TIP_Y), Vector2(0.0, MID_Y), Vector2(TIP_X, TIP_Y)]:
		b.disc(tip * R, TIP_R * R, body)
	# The band: its deeper foot first, the body over it short of the edge.
	var band_at := Vector2(-BAND_HALF, BAND_TOP) * R
	var band := Vector2(2.0 * BAND_HALF, BAND_BOTTOM - BAND_TOP) * R
	b.fan(Builder.round_rect(band_at, band, BAND_RADIUS * R), deep)
	b.fan(Builder.round_rect(band_at, band - Vector2(0.0, EDGE * R), BAND_RADIUS * R), body)
	b.fan(Builder.round_rect(HI_AT * R, HI_SIZE * R, HI_RADIUS * R), Color(1.0, 1.0, 1.0, HI_ALPHA))
	# The gems: deep on the outer points, and the given's leaf on the middle.
	b.disc(Vector2(-TIP_X, TIP_Y) * R, GEM_R * 0.55 * R, Color(deep, 0.8))
	b.disc(Vector2(TIP_X, TIP_Y) * R, GEM_R * 0.55 * R, Color(deep, 0.8))
	if pinned:
		b.disc(Vector2(0.0, MID_Y) * R, GEM_R * R, Pal.LEAF_DEEP)
		b.disc(Vector2(0.0, MID_Y - 0.02) * R, GEM_R * 0.72 * R, Pal.LEAF)
	_face_parts(b, FACE_R * R, FACE_AT * R, Pal.TEXT, eye)
```

Then open the concept tab's `crown` drawing function in `docs/brainstorm/concepts.html` (search `function crown` inside the `qn` IIFE) and compare each number above with the mock's; change this file to the mock's values where they differ, keeping the constants' names.

- [ ] **Step 6: Look at it**

Write `/tmp/_crown_shot.gd` (throwaway, not committed):

```gdscript
extends SceneTree

const CrownFace = preload("res://ui/faces/crown_face.gd")
const Face = preload("res://ui/faces/face.gd")
const Pal = preload("res://core/palette.gd")

var _frames := 0

func _initialize() -> void:
	var bg := ColorRect.new()
	bg.color = Pal.PARCHMENT
	bg.size = Vector2(1000, 300)
	root.add_child(bg)
	var exprs := [Face.Expr.HAPPY, Face.Expr.JOY, Face.Expr.STRAIN, Face.Expr.HAPPY]
	for i in 4:
		var crown := CrownFace.new()
		crown.expression = exprs[i]
		crown.pinned = i == 3
		crown.size = Vector2(220, 220)
		crown.position = Vector2(40 + i * 240, 40)
		root.add_child(crown)

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 4:
		root.get_viewport().get_texture().get_image().save_png("/tmp/crown.png")
		return true
	return false
```

Run: `godot --path . --resolution 1000x300 --script /tmp/_crown_shot.gd` (windowed; needs the display). Then look at `/tmp/crown.png` with the Read tool. Expected: four gold crowns on parchment, three rounded points with the middle taller, a face on the band with cheeks, the second grinning with shut arched eyes, the third with slanted brows and a flat mouth, the fourth with a green gem on its middle point. No stray triangles (a self-intersecting outline would show as a missing wedge: if so, the `points` list is out of order). Compare against `docs/art/concept-queens.png`'s queen and the concept tab's crown; adjust constants until it reads as the same crown. Then `git checkout project.godot` if Godot re-saved it.

- [ ] **Step 7: Run the suite once more and commit**

Run: `godot --headless --path . --script res://tests/run_tests.gd 2>&1 | tail -3`
Expected: 0 failures.

```bash
git add core/palette.gd ui/faces/crown_face.gd ui/faces/crown_face.gd.uid tests/test_queens.gd
git commit -m "feat(queens): nine region pastels and the crown, the tenth screen's one new species"
```

---

### Task 4: The tray takes a chip set

**Files:**
- Modify: `ui/flat/tile_tray.gd` (whole file; the diff is the set)
- Modify: `ui/flat/flat_host.gd:162-185` (the `match` on `tray`)

**Interfaces:**
- Consumes: `QueensState.QUEEN`, `QueensState.CROSS`, `CrownFace`.
- Produces: `TileTray.new(chip_set := TileTray.MOSAIC)`; `TileTray.MOSAIC` and `TileTray.CROWNS` (Dictionaries with `values: Array[int]`, `labels`, `names`, `glyphs: Array[String]` in `"tile" | "pebble" | "crown"`); registry `"tray": "crowns"`. The board must own `var brush: int` and `func set_brush(v: int)`, as Nonogram's does.

- [ ] **Step 1: Write the failing probe**

Write `/tmp/_tray_probe.gd` (throwaway, not committed):

```gdscript
extends SceneTree

const TileTray = preload("res://ui/flat/tile_tray.gd")

var _frames := 0
var _a
var _b

func _initialize() -> void:
	_a = TileTray.new()
	root.add_child(_a)
	_b = TileTray.new(TileTray.CROWNS)
	root.add_child(_b)

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 3:
		return false
	var ok := _a.chips.size() == 2 and _b.chips.size() == 2
	ok = ok and _a.chips[0].get_node("Label").text == "Tile"
	ok = ok and _b.chips[0].get_node("Label").text == "Queen"
	ok = ok and _b.chips[1].get_node("Label").text == "Cross"
	ok = ok and _b.chips[0].has_node("Glyph")
	print("tray probe ok=%s" % ok)
	return true
```

Run: `godot --headless --path . --script /tmp/_tray_probe.gd 2>&1 | tail -3`
Expected: a script error (`TileTray.new` takes no argument; `CROWNS` is not a member).

- [ ] **Step 2: Teach the tray the set**

In `ui/flat/tile_tray.gd`:

Replace the header doc's last paragraph (`## The tray only asks; the puzzle owns the brush ...` through the `## Spec:` line) with:

```gdscript
## The tray only asks; the puzzle owns the brush (`brush`) and refresh()
## reads it back, so a board that drops the brush on a solve is shown here
## too. `symbol_tray.gd`'s sibling.
##
## Two boards wear it. It is built with a **chip set** -- what each chip
## paints, the word it carries, its node name and which glyph it draws --
## and there are two: MOSAIC, Nonogram's tile and cross, the default; and
## CROWNS, Queens' crown and cross, which the registry asks for with
## `"tray": "crowns"`. One tray, two sets, no copy.
## Spec: docs/superpowers/specs/2026-09-18-nonogram-flat-design.md, section 6;
## docs/superpowers/specs/2026-09-19-queens-flat-design.md, section 6.
```

Replace

```gdscript
## What the player chose: State.FILL or State.MARK.
signal pick(v: int)

const State = preload("res://puzzles/nonogram_state.gd")
```

with

```gdscript
## What the player chose: one of the set's values.
signal pick(v: int)

const NonogramState = preload("res://puzzles/nonogram_state.gd")
const QueensState = preload("res://puzzles/queens_state.gd")
const CrownFace = preload("res://ui/faces/crown_face.gd")
```

Replace

```gdscript
## Chip index -> brush value, and the word each carries.
const VALUES := [State.FILL, State.MARK]
const LABELS := ["Tile", "Cross"]

var chips: Array[Button] = []
var _armed := -1
var _lifts: Array = [null, null]

func _init() -> void:
	enter_from = Vector2(0, 100)
```

with

```gdscript
## The two sets. `glyphs` names what the chip's picture is: a laid tile, a
## pebble on its socket, or a crown (a CrownFace seated on the chip).
const MOSAIC := {
	"values": [NonogramState.FILL, NonogramState.MARK],
	"labels": ["Tile", "Cross"],
	"names": ["TileChip", "CrossChip"],
	"glyphs": ["tile", "pebble"],
}
const CROWNS := {
	"values": [QueensState.QUEEN, QueensState.CROSS],
	"labels": ["Queen", "Cross"],
	"names": ["QueenChip", "CrossChip"],
	"glyphs": ["crown", "pebble"],
}

var chips: Array[Button] = []
var _set: Dictionary = MOSAIC
var _armed := -1
var _lifts: Array = [null, null]

func _init(chip_set: Dictionary = MOSAIC) -> void:
	_set = chip_set
	enter_from = Vector2(0, 100)
```

In `_build`, replace `for i in VALUES.size():` with `for i in (_set.values as Array).size():`, replace `chip.name = ["TileChip", "CrossChip"][i]` with `chip.name = str(_set.names[i])`, replace `label.text = LABELS[i]` with `label.text = str(_set.labels[i])`, and replace the glyph block

```gdscript
		var glyph := Control.new()
		glyph.name = "Glyph"
		glyph.size = Vector2.ONE * GLYPH
		glyph.position = Vector2(GLYPH_X, GLYPH_Y) - glyph.size * 0.5
		glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glyph.draw.connect(_draw_glyph.bind(glyph, i))
		chip.add_child(glyph)
```

with

```gdscript
		var glyph: Control
		if str(_set.glyphs[i]) == "crown":
			# A crown is a face of its own and draws itself.
			glyph = CrownFace.new()
		else:
			glyph = Control.new()
			glyph.draw.connect(_draw_glyph.bind(glyph, i))
		glyph.name = "Glyph"
		glyph.size = Vector2.ONE * GLYPH
		glyph.position = Vector2(GLYPH_X, GLYPH_Y) - glyph.size * 0.5
		glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(glyph)
```

Replace `_draw_glyph`'s body condition `if VALUES[i] == State.FILL:` with `if str(_set.glyphs[i]) == "tile":` (the `else` branch stays the pebble on its socket).

In `_on_pressed`, replace `pick.emit(VALUES[i])` with `pick.emit(int(_set.values[i]))`.

In `refresh`, replace `var armed := VALUES.find(brush)` with `var armed := (_set.values as Array).find(brush)`.

In `ui/flat/flat_host.gd`, inside the `match str(_entry.get("tray", "symbols")):`, after the `"tiles":` branch add:

```gdscript
		"crowns":
			# Queens' pair: the same tray as Nonogram's, with the crown set.
			tray = TileTray.new(TileTray.CROWNS)
			tray.pick.connect(_on_brush)
			rows.append(TileTray.HEIGHT)
```

- [ ] **Step 3: Run the probe and the suite**

Run: `godot --headless --path . --script /tmp/_tray_probe.gd 2>&1 | tail -3`
Expected: `tray probe ok=true`.

Run: `godot --headless --path . --script res://tests/run_tests.gd 2>&1 | tail -3`
Expected: 0 failures.

- [ ] **Step 4: Commit**

```bash
git add ui/flat/tile_tray.gd ui/flat/flat_host.gd
git commit -m "feat(flat): the tile tray takes a chip set, and crowns is the second"
```

---

### Task 5: The board, on the grid and under the win harness

**Files:**
- Create: `puzzles/queens2d.gd`
- Modify: `ui/registry.gd` (the `PUZZLES` list and its header comment)
- Modify: `tests/_win.gd` (the describe `match` near line 80, the `_solve` `match` at line 93, and a new `_solve_queens`)

**Interfaces:**
- Consumes: `QueensState` (Task 2), `CrownFace` (Task 3), `Pal.REGION`, `Pal.QUEEN_WASH` (Task 3), the tray's `"crowns"` set (Task 4), `Motion`'s recipes and readers, `Fx2D`, `Mosaic.pebble`, `Scenery.soft_disc`.
- Produces: a `PuzzleBase` with `puzzle_id() "queens"`, `var state`, `var brush: int`, `var n: int` (read-only, the court's size), `cell_to_local(r, c) -> Vector2`, `card_height`, `card_centred`, `set_brush(v)`, `tip_line()`, `flat_win()`, `win_delay()`, `capabilities() ["undo", "hint", "check"]`. The harnesses read `_puzzle.n`, `_puzzle.state.solution`, `_puzzle.state.queens`.

- [ ] **Step 1: Register the board and write the failing harness branch**

In `ui/registry.gd`, replace the header comment's second paragraph

```gdscript
## `PUZZLES` is the grid: twelve cards, three across and four down, in the
## order they are drawn. Nine of them open a flat board; the last three name
## a board that has never been drawn flat and say `soon` instead of opening
## (ui/menu.gd draws them dimmed with no go button).
```

with

```gdscript
## `PUZZLES` is the grid: twelve cards, three across and four down, in the
## order they are drawn. Ten of them open a flat board; the last two name a
## board that has never been drawn flat and say `soon` instead of opening
## (ui/menu.gd draws them dimmed with no go button). Snake Apple's `soon`
## card left the grid on 2026-09-19 to make room for Queens: it is the one
## being redesigned outright, and its island board stays under More.
```

After the `nonogram` entry's closing `},` and before the comment `# --- the last row:`, insert:

```gdscript
	{
		"id": "queens",
		"kind": "puzzle",
		"title": "Queens",
		"blurb": "Seat one queen in every row, column and colour.",
		"short": "One queen per row,\ncolumn and colour.",
		"motto": "Every queen has her seat",
		"footer": "Seat · Cross · Reign",
		# Two chips, a crown and a cross, so it asks for the tile tray with
		# the crown set.
		"script": "res://puzzles/queens2d.gd",
		"shell": "flat",
		"tray": "crowns",
		"difficulties": [0, 1, 2],
	},
```

Replace the comment

```gdscript
	# --- the last row: named, drawn, and not yet playable here. Each has a
	# board on the stage behind More (`legacy` names it), and each comes back
	# to this row the day it is drawn flat.
```

with

```gdscript
	# --- the end of the last row: named, drawn, and not yet playable here.
	# Each has a board on the stage behind More (`legacy` names it), and each
	# comes back to this row the day it is drawn flat.
```

and delete the `snake` entry from `PUZZLES` (the dictionary with `"id": "snake"` and `"soon": true`; the `snake_island` entry in `LEGACY` stays, with its `seed_as`).

In `tests/_win.gd`: in the describe `match` (the one with the line `"nonogram", "nonogram_island": return "%dx%d picture, ...`), add

```gdscript
		"queens": return "%dx%d court, %d queens, board fit=%s, hud=%s" % [_puzzle.n, _puzzle.n, _puzzle.state.queens.size(), _fit_ok, _hud_ok]
```

In `_solve`, after the `"nonogram", "nonogram_island": _solve_nonogram()` line add

```gdscript
		"queens": _solve_queens()
```

and after `_solve_nonogram` add:

```gdscript
## Queens: one hint (seats and pins a queen), one check, then the answer's
## seat in every row the hint did not fill, tapped with the crown chip the
## tray arms by default.
func _solve_queens() -> void:
	var n: int = _puzzle.n
	# Board fit check: every cell centre must land inside the slot.
	var slot := Rect2(Vector2.ZERO, _puzzle.size)
	_fit_ok = true
	for r in n:
		for c in n:
			if not slot.has_point(_puzzle.cell_to_local(r, c)):
				_fit_ok = false
	_press(_host.top_bar.hint_button)
	_press(_host.action_bar.check_button)
	_hud_ok = _puzzle.hints_used == 1 and _puzzle.checks == 1
	for r in n:
		if _puzzle.is_done():
			return
		var cell := Vector2i(int(_puzzle.state.solution[r]), r)
		if _puzzle.state.queens.has(cell):
			continue
		_tap_local(_puzzle.cell_to_local(r, cell.x))
```

Run: `godot --headless --path . --script res://tests/run_tests.gd 2>&1 | tail -3`
Expected: 0 failures (the registry is data; nothing loads the script yet).

Run: `godot --path . --resolution 540x960 --script res://tests/_win.gd 2>&1 | tail -12`
Expected: the walk reaches `queens` and fails to open it (no script at `res://puzzles/queens2d.gd`), so fewer than 10 boards report solved.

- [ ] **Step 2: Write the board**

Create `puzzles/queens2d.gd`:

```gdscript
extends "res://core/puzzle_base.gd"

## Queens as a flat board: a court cut into as many coloured regions as it
## has rows, under an ink frame and ink seams, on the host's parchment card.
## Seat one queen in every row, every column and every colour, and never let
## two queens touch, not even at a corner. The rules live in
## puzzles/queens_state.gd, which this only draws.
##
## This is the first board that answers a move for you. A seated queen
## crosses out every cell she can see, in a wave that runs out from her ring
## by ring (WAVE_STEP): as it reaches a cell the cell flashes gold and its
## pebble pops in behind the flash. Lift her and the wave runs backward, the
## far cells first, so her reach draws back into where she stood. The crosses
## a queen lays are derived by the state and never stored, so undo and
## removal need no bookkeeping for them; a crown on a crossed cell is
## refused, so two queens can never conflict and the n-th queen is the win.
##
## How it is drawn. Only the crowns are nodes (ui/faces/crown_face.gd), each
## in a slot of its own so the layout and the motion never fight (rule 2 of
## docs/art/flat-motion.md). Everything else is two meshes rebuilt only while
## something moves: the floor (the frame, the region-tinted cells, the grid,
## the seams and the dot on every free cell), built about the court's centre
## so the entrance pop is a transform; and the ground (the wave's washes, the
## blushes, the crowns' shadows and every pebble) over it. Every drawn moment
## reads the flat boards' vocabulary as curves off core/motion.gd (rule 8);
## nothing here needed a new reader. Every move -- a tap, a sweep, an undo, a
## hint, a reset -- goes through one _settle that diffs a snapshot of the
## court against the state and hands each changed cell its moment, with one
## Callable saying when: a queen's wave, a sweep's path, Reset's far corner.
## Spec: docs/superpowers/specs/2026-09-19-queens-flat-design.md.
## Concept page: docs/brainstorm/concepts.html#queens.

const State = preload("res://puzzles/queens_state.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Face = preload("res://ui/faces/face.gd")
const CrownFace = preload("res://ui/faces/crown_face.gd")
const Mosaic = preload("res://ui/faces/mosaic_tile.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

# --- the court ---
## The card's inset round the court.
const PAD := 34.0
## The ink frame round the court and the seams between regions, in pixels;
## the faint grid between cells of one region and the dot on a free cell, in
## cells. The mock's own.
const FRAME := 6.0
const FRAME_RADIUS := 16.0
const SEAM := 5.0
const GRID := 2.0
const GRID_ALPHA := 0.28
const DOT_R := 0.055
const DOT_ALPHA := 0.32
## How far a pressed cell goes toward the ink at the bottom of its press. The
## cells are flush, so a press here shades rather than shrinks (a shrunk cell
## would show the frame's ink round it); the piece on the cell sinks.
const SINK_SHADE := 0.18
## The pieces in cells, each a fraction of a cell, and the crown's soft
## shadow on the ground.
const CROWN_SIZE := 0.8
const CROWN_SHADOW_AT := Vector2(0.0, 0.36)
const CROWN_SHADOW_RX := 0.3
const CROWN_SHADOW_RY := 0.08
const SHADOW_ALPHA := 0.22
const BLUSH_ALPHA := 0.9
## The seat's and the hint's ring, in cells.
const RING_R := 0.6
## How far a refused pebble shivers, in cells.
const SHIVER := 0.03

# --- this board's own motion: the wave ---
## One ring of the wave per WAVE_STEP: a cell a queen sees arrives its
## king-move distance in rings after her, and leaves in the reverse order.
const WAVE_STEP := 0.045
## The gold wash's peak alpha as the wave reaches a cell.
const WAVE_FLASH := 0.35
## A cross a queen laid, against the player's own at one.
const AUTO_ALPHA := 0.75
## How long a refused given queen strains before her face settles.
const STRAIN_TIME := 0.6
## The pebbles clear away in a scatter on the win, as Nonogram's do.
const CLEAR_DELAY := 0.2
const CLEAR_SPREAD := 0.3
const CLEAR_TIME := 0.5
const CLEAR_SHRINK := 0.4
const WIN_WAIT := 1.6

const HINTS := State.HINTS
const TIP_CYCLE := 10.0
const TIPS := [
	"One queen in every row, every column and every colour.",
	"A queen crosses out every seat she can see.",
	"Two queens never touch, not even at a corner.",
]

var state = State.new()
## Which chip the tray has armed: State.QUEEN or State.CROSS. The tray only
## asks; this owns it, and tile_tray.gd reads it back.
var brush: int = State.QUEEN

## The court's size, the name the win harness reads.
var n: int:
	get: return state.n

var fx: Node2D
var _cell := 0.0
var _grid := Vector2.ZERO
var _crowns: Dictionary = {}   # Vector2i -> CrownFace, kept once made
var _slots: Dictionary = {}    # crown -> its slot
var _pos_tw: Dictionary = {}   # crown -> the hop, the shiver, the drop
var _look_tw: Dictionary = {}  # crown -> the pop, the press, the wobble
var _gen := 0

## Every drawn moment, each the second it begins, read off Motion's curve
## readers in _build_floor and _build_ground.
var _cross_in: Dictionary = {}  # cell -> at: its pebble pops in then
var _cross_out: Array = []      # [{"cell", "at", "alpha"}]: pebbles shrinking out
var _wash: Dictionary = {}      # cell -> at: the wave reaches it then
var _blush: Dictionary = {}     # cell -> at: Check pointed at it, or a refusal
var _shiver: Dictionary = {}    # cell -> at: a refused pebble
var _sunk: Dictionary = {}      # cell -> {"down", "up"}: the finger has it
var _floor: ArrayMesh
var _ground: ArrayMesh
var _ground_dirty := true
## The meshes the last _draw handed the canvas item. A canvas command holds a
## mesh by RID and not by reference; dropping the only reference to a mesh
## still on the item's command list leaves the renderer drawing a freed RID.
var _shown: Array = []

# --- the gesture ---
var _press_cell := Vector2i(-1, -1)
var _pressed: Control       # the crown under the finger, if one
var _dragged := false
var _lay := true            # a sweep lays crosses, or rubs the player's out
var _swept: Dictionary = {}
var _pending: Array = []
var _last_paint := Vector2i(-1, -1)

var _opened := -1.0e9
var _solved_at := -1.0
var _anim_until := 0.0
var _tip_text := ""
var _tip_mood := Face.Expr.HAPPY
var _tip_idx := 0
var _tip_timer: Timer

func puzzle_id() -> String: return "queens"
func title() -> String: return "Queens"

func rules() -> String:
	return "Seat one queen in every row, every column and every colour. No two queens may touch, not even at a corner. A queen crosses out every seat she can see."

func capabilities() -> Array[String]:
	return ["undo", "hint", "check"]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = false
	fx = Fx2D.new()
	fx.name = "Fx"
	fx.z_index = 2
	add_child(fx)
	_tip_timer = Timer.new()
	_tip_timer.wait_time = TIP_CYCLE
	_tip_timer.timeout.connect(_cycle_tip)
	add_child(_tip_timer)
	resized.connect(_layout)
	solved.connect(_on_solved)

func build(rng: RandomNumberGenerator, difficulty: int) -> void:
	_stop_all()
	state.setup(rng, difficulty)
	brush = State.QUEEN
	_cross_in = {}
	_cross_out = []
	_wash = {}
	_blush = {}
	_shiver = {}
	_sunk = {}
	_clear_gesture()
	_solved_at = -1.0
	_build_pieces()
	_layout()
	_tip_idx = 0
	_say(TIPS[0], Face.Expr.HAPPY)
	_tip_timer.start()
	_enter()

# --- the cast ---

## Only the crowns are nodes. The court and the pebbles are drawn.
func _build_pieces() -> void:
	for crown in _slots:
		_slots[crown].queue_free()
	_slots = {}
	_crowns = {}

## Puts `crown` in a slot of her own under the board. The slot takes the
## layout; the crown inside it takes the motion.
func _stand(crown: Control, node_name: String) -> void:
	var slot := Control.new()
	slot.name = node_name
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(slot)
	crown.name = "crown"
	crown.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(crown)
	_slots[crown] = slot

## The crown on `cell`, made the first time a queen is seated there and kept
## afterwards: a cell tapped twice would otherwise build and free a node with
## a mesh cache behind it on every tap.
func _crown_node(cell: Vector2i) -> CrownFace:
	if _crowns.has(cell):
		return _crowns[cell]
	var crown := CrownFace.new()
	crown.visible = false
	crown.scale = Vector2.ZERO
	_stand(crown, "crown_%d_%d" % [cell.x, cell.y])
	crown.set_idle(true)
	_crowns[cell] = crown
	if _cell > 0.0:
		_seat(crown, cell_to_local(cell.y, cell.x), _cell * CROWN_SIZE)
	return crown

## Every crown takes the look her state asks for; a crown is written only
## when her look changes, since a written face redraws.
func _refresh_faces() -> void:
	for cell in _crowns:
		var crown: CrownFace = _crowns[cell]
		if state.mark_at(cell) != State.QUEEN:
			continue
		var pinned: bool = state.locked.has(cell)
		if crown.pinned != pinned:
			crown.pinned = pinned
		# The win writes JOY on each crown as the wave reaches her, and a
		# refusal's strain settles on its own clock.
		if _solved_at >= 0.0 or crown.expression == Face.Expr.STRAIN:
			continue
		_set_expr(crown, Face.Expr.HAPPY)

func _set_expr(face: Face, expr: int) -> void:
	if face.expression != expr:
		face.expression = expr

# --- layout ---

## The court is the largest grid the card holds, and the card is cut to the
## court and centred in the slot (card_height, card_centred): the grid is
## square while its space is tall, so the cell is capped by the width at
## every step and there is slack however the card is cut.
func _layout() -> void:
	if state.region.is_empty():
		return
	_cell = _cell_for(size.y)
	if _cell <= 0.0:
		return
	var court := Vector2.ONE * (_cell * state.n)
	var tall := minf(size.y, court.y + 2.0 * PAD)
	_grid = Vector2(size.x * 0.5 - court.x * 0.5, (size.y - tall) * 0.5 + (tall - court.y) * 0.5)
	for cell in _crowns:
		_seat(_crowns[cell], cell_to_local(cell.y, cell.x), _cell * CROWN_SIZE)
	_refresh_faces()
	_redraw()

## Seats `crown` `px` square about `centre`: her slot takes the place, and her
## own place inside it is left to the motion.
func _seat(crown: Control, centre: Vector2, px: float) -> void:
	var seat := Vector2.ONE * px
	var slot: Control = _slots[crown]
	slot.size = seat
	slot.position = centre - seat * 0.5
	crown.size = seat
	crown.pivot_offset = seat * 0.5

## The cell a slot of `available` height holds, capped by the width.
func _cell_for(available: float) -> float:
	if state.region.is_empty():
		return 0.0
	return minf((size.x - 2.0 * PAD) / state.n, (available - 2.0 * PAD) / state.n)

func card_height(available: float) -> float:
	var cell := _cell_for(available)
	if cell <= 0.0:
		return available
	return minf(available, cell * state.n + 2.0 * PAD)

func card_centred() -> bool:
	return true

## Control-local point over the centre of cell (r, c). The win harness taps
## these.
func cell_to_local(r: int, c: int) -> Vector2:
	return _grid + Vector2(c + 0.5, r + 0.5) * _cell

func _cell_at(local: Vector2) -> Vector2i:
	if _cell <= 0.0:
		return Vector2i(-1, -1)
	var p := (local - _grid) / _cell
	var cell := Vector2i(int(floor(p.x)), int(floor(p.y)))
	return cell if state.in_field(cell) else Vector2i(-1, -1)

## The court's centre in board pixels: what the floor pops about.
func _court_centre() -> Vector2:
	return _grid + Vector2.ONE * (_cell * state.n * 0.5)

# --- the frame ---

func _process(delta: float) -> void:
	super(delta)
	if _now() < _anim_until:
		queue_redraw()

## Keeps the court redrawing for `seconds` more: something on it is moving.
func _busy_for(seconds: float) -> void:
	_anim_until = maxf(_anim_until, _now() + seconds)

## Something on the court changed: rebuild it on the next draw.
func _redraw() -> void:
	_ground_dirty = true
	queue_redraw()

# --- the drawing ---

## The court pops in wide about its centre once the chrome has slid in
## (rule 7), as one draw transform over the floor mesh; the ground is drawn
## over it as it is.
func _draw() -> void:
	if _cell <= 0.0 or state.region.is_empty():
		return
	var now := _now()
	var busy := false
	var shown: Array = []
	if _ground_dirty or now < _anim_until:
		_floor = _build_floor(now)
		var out := _build_ground(now)
		_ground = out.mesh
		busy = out.busy
		_ground_dirty = false
	var since := now - _opened - Motion.ENTER_DELAY
	if since < Motion.ENTER_POP:
		busy = true
	var seen := Motion.appear_level(since)
	if seen > 0.0 and _floor != null:
		var grown := Motion.wide_pop_scale(since)
		draw_mesh(_floor, null, Transform2D(0.0, Vector2(grown, grown), 0.0, _court_centre()),
			Color(1.0, 1.0, 1.0, seen))
		shown.append(_floor)
	if _ground != null:
		draw_mesh(_ground, null)
		shown.append(_ground)
	_shown = shown
	if busy:
		_anim_until = maxf(_anim_until, now + 0.1)

## The court, built about its centre: the ink frame (a filled round rect the
## cells lie flush on, so its rounded corners are ink and not parchment), a
## cell per region colour shaded toward the ink while the finger holds it,
## the faint grid over them, the seams where two regions meet, and the dot
## on every cell nothing stands on.
func _build_floor(now: float) -> ArrayMesh:
	var b := Face.Builder.new()
	var field := Vector2.ONE * (_cell * state.n)
	var origin := -field * 0.5
	b.fan(Face.Builder.round_rect(origin - Vector2.ONE * FRAME,
		field + Vector2.ONE * (2.0 * FRAME), FRAME_RADIUS), Pal.TEXT)
	var gone: Array = []
	for y in state.n:
		for x in state.n:
			var cell := Vector2i(x, y)
			var col: Color = Pal.REGION[state.region_at(cell) % Pal.REGION.size()]
			if _sunk.has(cell):
				var pr: Dictionary = _sunk[cell]
				var released := -1.0 if now < float(pr.up) else now - float(pr.up)
				if released >= Motion.RELEASE_TIME:
					gone.append(cell)
				else:
					var grown := Motion.press_scale(now - float(pr.down), released)
					var depth := clampf((1.0 - grown) / (1.0 - Motion.PRESS_SCALE), 0.0, 1.0)
					col = col.lerp(Pal.TEXT, SINK_SHADE * depth)
			b.fan(_square(origin + Vector2(x, y) * _cell, _cell), col)
	for cell in gone:
		_sunk.erase(cell)
	# The grid: every line across the whole court, faint and flat-ended.
	var grid_ink := Color(Pal.TEXT, GRID_ALPHA)
	for i in range(1, state.n):
		b.stroke(PackedVector2Array([origin + Vector2(i * _cell, 0.0),
			origin + Vector2(i * _cell, field.y)]), GRID, grid_ink, false, false)
		b.stroke(PackedVector2Array([origin + Vector2(0.0, i * _cell),
			origin + Vector2(field.x, i * _cell)]), GRID, grid_ink, false, false)
	# The seams: the edge between two cells of different regions, in ink,
	# round-capped so they meet cleanly at corners.
	for y in state.n:
		for x in state.n:
			var cell := Vector2i(x, y)
			var g := state.region_at(cell)
			var at := origin + Vector2(x, y) * _cell
			if x + 1 < state.n and state.region_at(cell + Vector2i.RIGHT) != g:
				b.stroke(PackedVector2Array([at + Vector2(_cell, 0.0), at + Vector2.ONE * _cell]),
					SEAM, Pal.TEXT)
			if y + 1 < state.n and state.region_at(cell + Vector2i.DOWN) != g:
				b.stroke(PackedVector2Array([at + Vector2(0.0, _cell), at + Vector2.ONE * _cell]),
					SEAM, Pal.TEXT)
	# The dot on a cell nothing stands on: blank, or crossed but with its
	# pebble still on its way in the wave.
	for y in state.n:
		for x in state.n:
			var cell := Vector2i(x, y)
			var mark := state.mark_at(cell)
			var bare := mark == State.BLANK
			if _crossed(mark) and _cross_in.has(cell) and float(_cross_in[cell]) > now:
				bare = true
			if bare:
				b.disc(origin + (Vector2(cell) + Vector2.ONE * 0.5) * _cell, DOT_R * _cell,
					Color(Pal.TEXT, DOT_ALPHA))
	return b.mesh()

## A cell's square from its top-left corner.
static func _square(at: Vector2, s: float) -> PackedVector2Array:
	return PackedVector2Array([at, at + Vector2(s, 0.0), at + Vector2.ONE * s, at + Vector2(0.0, s)])

## Everything standing on the court, in one mesh: the wave's gold washes, the
## blushes, the crowns' shadows, the pebbles on their way out and the pebbles
## that are here.
func _build_ground(now: float) -> Dictionary:
	var b := Face.Builder.new()
	var busy := not _sunk.is_empty()
	# The wave: as it reaches a cell the cell flashes toward gold and back,
	# read off flash_level; a cell it has not reached yet keeps us drawing.
	var gone: Array = []
	for cell in _wash:
		var e: float = now - float(_wash[cell])
		if e < 0.0:
			busy = true
			continue
		if e >= Motion.FLASH_IN + Motion.FLASH_OUT:
			gone.append(cell)
			continue
		busy = true
		_cell_wash(b, cell, Color(Pal.QUEEN_WASH, WAVE_FLASH * Motion.flash_level(e)))
	for cell in gone:
		_wash.erase(cell)
	# The blush: toward the family's rose and back.
	gone = []
	for cell in _blush:
		var e: float = now - float(_blush[cell])
		if e >= Motion.FLASH_IN + Motion.FLASH_OUT:
			gone.append(cell)
			continue
		busy = true
		_cell_wash(b, cell, Color(Pal.BAD_TILE, BLUSH_ALPHA * Motion.flash_level(e)))
	for cell in gone:
		_blush.erase(cell)
	# The crowns' shadows, anchored at the cell and read off each crown's own
	# scale and alpha, so one arrives with the pop and stays put when she hops.
	for cell in _crowns:
		var crown: CrownFace = _crowns[cell]
		if crown.visible:
			_crown_shadow(b, crown, cell)
	# Pebbles on their way out, drawn from the shape the state has forgotten.
	var still: Array = []
	for out in _cross_out:
		var e: float = now - float(out.at)
		var shrunk := Motion.pop_out_scale(e)
		if shrunk <= 0.0:
			continue
		still.append(out)
		busy = true
		var turn := PI * 0.5 * clampf(e / Motion.POP_OUT, 0.0, 1.0)
		Mosaic.pebble(b, cell_to_local(out.cell.y, out.cell.x), _cell, Vector2.ONE * shrunk,
			float(out.alpha), turn)
	_cross_out = still
	# The pebbles that are here: waiting for the wave, popping in with the
	# squash, standing, shivering when refused, or clearing away on the win.
	gone = []
	for y in state.n:
		for x in state.n:
			var cell := Vector2i(x, y)
			var mark := state.mark_at(cell)
			if not _crossed(mark):
				continue
			var grow := Vector2.ONE
			if _cross_in.has(cell):
				var e: float = now - float(_cross_in[cell])
				if e < 0.0:
					busy = true
					continue
				grow = Motion.pop_in_scale(e)
				if e < Motion.POP_IN:
					busy = true
				else:
					gone.append(cell)
			grow *= _sink(cell, now)
			var alpha := AUTO_ALPHA if mark == State.AUTO else 1.0
			if _solved_at >= 0.0:
				var cleared := _dec((now - _solved_at - CLEAR_DELAY - _hash(cell) * CLEAR_SPREAD) / CLEAR_TIME)
				if cleared >= 1.0:
					continue
				busy = true
				alpha *= 1.0 - cleared
				grow *= 1.0 - cleared * CLEAR_SHRINK
			if grow.x <= 0.0 or grow.y <= 0.0:
				continue
			var at := cell_to_local(cell.y, cell.x)
			var shook: float = now - float(_shiver.get(cell, -100.0))
			if shook < Motion.SHIVER_TIME:
				busy = true
				at.x += Motion.shiver_offset(shook, _cell * SHIVER)
			Mosaic.pebble(b, at, _cell, grow, alpha)
	for cell in gone:
		_cross_in.erase(cell)
	if b.verts.is_empty():
		return {"mesh": null, "busy": busy}
	return {"mesh": b.mesh(), "busy": busy}

## A wash over the whole of `cell`.
func _cell_wash(b, cell: Vector2i, colour: Color) -> void:
	b.fan(_square(_grid + Vector2(cell) * _cell, _cell), colour)

## The family's soft disc under `crown` on `cell`, scaled by how much of her
## is there and faded with her while she drops in.
func _crown_shadow(b, crown: Control, cell: Vector2i) -> void:
	var seen := clampf(crown.scale.y, 0.0, 1.0) * clampf(crown.modulate.a, 0.0, 1.0)
	if seen <= 0.0:
		return
	Scenery.soft_disc(b, cell_to_local(cell.y, cell.x) + CROWN_SHADOW_AT * _cell,
		CROWN_SHADOW_RX * _cell * seen, CROWN_SHADOW_RY * _cell * seen,
		Color(Pal.TEXT, SHADOW_ALPHA * seen))

## press_scale for the cell under the finger, one when it is not.
func _sink(cell: Vector2i, now: float) -> float:
	if not _sunk.has(cell):
		return 1.0
	var pr: Dictionary = _sunk[cell]
	var released := -1.0 if now < float(pr.up) else now - float(pr.up)
	return Motion.press_scale(now - float(pr.down), released)

static func _crossed(mark: int) -> bool:
	return mark == State.CROSS or mark == State.AUTO

# --- the moments ---

## The chrome is the host's; here the court pops in wide after the family's
## delay. Nothing stands on it yet.
func _enter() -> void:
	_opened = _now()
	_busy_for(Motion.ENTER_DELAY + Motion.ENTER_POP)
	fx.cue("enter")

## The cell under the finger sinks (the Press moment) and stays down until the
## piece it is waiting for lands or the finger lets it go.
func _sink_cell(cell: Vector2i) -> void:
	if _sunk.has(cell) and is_inf(float(_sunk[cell].up)):
		return
	_sunk[cell] = {"down": _now(), "up": INF}
	_busy_for(Motion.PRESS_TIME)

## Lets go of every cell the gesture still holds down: each springs back when
## the piece it is under arrives, or now.
func _end_sinks(now: float, arrivals: Dictionary = {}) -> void:
	var last := now
	for cell in _sunk:
		var pr: Dictionary = _sunk[cell]
		if is_inf(float(pr.up)):
			pr.up = float(arrivals.get(cell, now))
			last = maxf(last, float(pr.up))
	_anim_until = maxf(_anim_until, last + Motion.RELEASE_TIME)

## Every cell of the court as the state marks it now: what _settle diffs
## against after a move.
func _snapshot() -> Dictionary:
	var out: Dictionary = {}
	for y in state.n:
		for x in state.n:
			var cell := Vector2i(x, y)
			out[cell] = state.mark_at(cell)
	return out

## Every cell whose mark differs between `before` (a _snapshot) and the state
## now takes its moment -- a crown pops in (or drops in, from a hint) or
## shrinks out, a pebble pops in or shrinks out -- `delay_of.call(cell,
## leaving)` seconds after `t`; and every cell in `wash` flashes gold as the
## wave reaches it. A cross changing hands between the player and a queen is
## not a change. Returns the second each changed cell's piece arrives, for
## the sinks to wait on.
func _settle(before: Dictionary, t: float, delay_of: Callable, drop := false, wash: Array = []) -> Dictionary:
	var arrivals: Dictionary = {}
	if not Motion.reduce:
		for cell in wash:
			var at: float = t + float(delay_of.call(cell, false))
			_wash[cell] = at
			_busy_for(at - t + Motion.FLASH_IN + Motion.FLASH_OUT)
	for cell in before:
		var prev := int(before[cell])
		var mark := state.mark_at(cell)
		if prev == mark or (_crossed(prev) and _crossed(mark)):
			continue
		var going: float = t + float(delay_of.call(cell, true))
		var coming: float = t + float(delay_of.call(cell, false))
		if prev == State.QUEEN:
			_crown_down(cell, going - t)
		elif _crossed(prev):
			_cross_leaves(cell, going, prev)
		if mark == State.QUEEN:
			_crown_up(cell, coming - t, drop)
			arrivals[cell] = coming
		elif _crossed(mark):
			_cross_arrives(cell, coming)
			arrivals[cell] = coming
	_refresh_faces()
	return arrivals

## The wave out of a queen at `q`: a cell she sees arrives its king-move
## distance in rings after her, and leaves in the reverse order, the far
## cells first, so her reach draws back into where she stood. Nothing waits
## under reduce-motion.
func _wave_from(q: Vector2i) -> Callable:
	var far := maxi(maxi(q.x, state.n - 1 - q.x), maxi(q.y, state.n - 1 - q.y))
	return func(cell: Vector2i, leaving: bool) -> float:
		if Motion.reduce:
			return 0.0
		var d := State.distance(q, cell)
		return float((far - d) if leaving else d) * WAVE_STEP

## A sweep's wave: along the finger's path at the family's stagger.
func _along(path: Array) -> Callable:
	return func(cell: Vector2i, _leaving: bool) -> float:
		if Motion.reduce:
			return 0.0
		return Motion.stagger(maxi(path.find(cell), 0), Motion.ENTER_STAGGER)

## Reset's wave from the far corner.
func _from_far_corner() -> Callable:
	return func(cell: Vector2i, _leaving: bool) -> float:
		if Motion.reduce:
			return 0.0
		return Motion.stagger(2 * state.n - 2 - cell.x - cell.y, Motion.RESET_STAGGER)

func _at_once() -> Callable:
	return func(_cell_: Vector2i, _leaving: bool) -> float:
		return 0.0

## A queen is seated on `cell`: her crown pops in with the squash after
## `delay`, or drops in from above when a hint seated her.
func _crown_up(cell: Vector2i, delay: float, drop: bool) -> void:
	var crown := _crown_node(cell)
	crown.visible = true
	Motion.stop(_look_tw.get(crown))
	Motion.stop(_pos_tw.get(crown))
	crown.rotation = 0.0
	crown.position = Vector2.ZERO
	crown.modulate.a = 1.0
	_set_expr(crown, Face.Expr.HAPPY)
	if drop:
		crown.scale = Vector2.ONE
		_pos_tw[crown] = Motion.drop_in(crown, Motion.DROP, Motion.DROP_TIME, delay)
		_busy_for(delay + Motion.DROP_TIME)
	else:
		_look_tw[crown] = Motion.pop_in(crown, Motion.POP_IN, delay)
		_busy_for(delay + Motion.POP_IN)

## A queen is lifted off `cell`: her crown shrinks to nothing with the quarter
## turn after `delay` and is hidden once gone, unless something seated her
## again.
func _crown_down(cell: Vector2i, delay: float) -> void:
	var crown: CrownFace = _crowns.get(cell)
	if crown == null:
		return
	Motion.stop(_look_tw.get(crown))
	var tw := Motion.pop_out(crown, Motion.POP_OUT, delay)
	if tw == null:
		crown.visible = false
		return
	_look_tw[crown] = tw
	_busy_for(delay + Motion.POP_OUT)
	tw.chain().tween_callback(func() -> void:
		if state.mark_at(cell) != State.QUEEN:
			crown.visible = false
			crown.rotation = 0.0)

func _cross_arrives(cell: Vector2i, at: float) -> void:
	_cross_in[cell] = at
	_busy_for(at - _now() + Motion.POP_IN)

## A pebble leaves `cell` at `at`, at the ink it had. Under reduce-motion it
## is simply gone, as pop_out would have it.
func _cross_leaves(cell: Vector2i, at: float, prev: int) -> void:
	_cross_in.erase(cell)
	_shiver.erase(cell)
	if Motion.reduce:
		return
	_cross_out.append({"cell": cell, "at": at, "alpha": AUTO_ALPHA if prev == State.AUTO else 1.0})
	_busy_for(at - _now() + Motion.POP_OUT)

## A cell blushes toward the family's rose and settles: Check pointing at its
## queen, or a press refused on it.
func _blush_cell(cell: Vector2i) -> void:
	if Motion.reduce:
		return
	_blush[cell] = _now()
	_busy_for(Motion.FLASH_IN + Motion.FLASH_OUT)

## `crown` hops `height` over `time` after `delay`; she rests at her slot's
## origin, so the base is always zero.
func _hop(crown: Control, height: float, time: float, delay := 0.0) -> void:
	Motion.stop(_pos_tw.get(crown))
	crown.position = Vector2.ZERO
	_pos_tw[crown] = Motion.hop(crown, height, time, delay, 0.0)
	_busy_for(delay + time)

## Check pointing at a crown: she wobbles where she stands.
func _wobble(crown: Control) -> void:
	Motion.stop(_look_tw.get(crown))
	crown.rotation = 0.0
	crown.scale = Vector2.ONE
	_look_tw[crown] = Motion.wobble2d(crown)
	_busy_for(Motion.WOBBLE_TIME)

## A crown refused on `cell`, which a queen already sees: the pebble there
## shivers and the cell blushes, and the sprout says why.
func _refuse_seen(cell: Vector2i) -> void:
	_say("A queen already sees that seat.", Face.Expr.WORRIED)
	fx.cue("locked")
	if Motion.reduce:
		return
	_shiver[cell] = _now()
	_blush_cell(cell)
	_busy_for(Motion.SHIVER_TIME)

## A lift refused on a given queen: she shivers and strains for a beat while
## her cell blushes, and the sprout says why.
func _refuse_pinned(cell: Vector2i) -> void:
	_say("That queen was given. She stays.", Face.Expr.WORRIED)
	fx.cue("locked")
	_blush_cell(cell)
	var crown: CrownFace = _crowns.get(cell)
	if crown == null or Motion.reduce:
		return
	_set_expr(crown, Face.Expr.STRAIN)
	_after(STRAIN_TIME, func() -> void:
		if crown.expression == Face.Expr.STRAIN and _solved_at < 0.0:
			crown.expression = Face.Expr.HAPPY)
	Motion.stop(_pos_tw.get(crown))
	crown.position = Vector2.ZERO
	_pos_tw[crown] = Motion.shiver(crown, _cell * SHIVER)
	_busy_for(Motion.SHIVER_TIME)

# --- input ---

## Touch and drag only, as every flat board takes them. With the crown chip a
## tap seats or lifts a queen on the cell it was pressed on; with the cross
## chip a tap lays or takes the player's cross, and a drag sweeps.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_press(_cell_at(event.position))
		else:
			_release(_cell_at(event.position))
	elif event is InputEventScreenDrag and _press_cell.x >= 0:
		_drag(event.position)

func _press(cell: Vector2i) -> void:
	_release_press()
	_end_sinks(_now())
	_clear_gesture()
	if is_done() or cell.x < 0:
		return
	_press_cell = cell
	var mark := state.mark_at(cell)
	# A crown under the finger sinks whichever chip is armed: every tappable
	# piece takes the press, including one that will do nothing on release.
	if mark == State.QUEEN and _crowns.has(cell):
		_pressed = _crowns[cell]
		Motion.stop(_look_tw.get(_pressed))
		_look_tw[_pressed] = Motion.press(_pressed, true)
	if brush == State.QUEEN:
		_sink_cell(cell)
	else:
		# The stroke's job is read off the cell it began on: a stroke that
		# begins on the player's own cross rubs out, any other lays.
		_lay = mark != State.CROSS
		_paint(cell)
	_redraw()

## The crown under the finger springs back.
func _release_press() -> void:
	if _pressed == null:
		return
	if is_instance_valid(_pressed):
		Motion.stop(_look_tw.get(_pressed))
		_look_tw[_pressed] = Motion.press(_pressed, false)
		_busy_for(Motion.RELEASE_TIME)
	_pressed = null

## With the cross chip, every cell between the last one painted and this one
## is swept, so a fast finger leaves no holes. No line lock: a Queens sweep
## is a region's odd corners as often as a row. The crown chip does not
## sweep.
func _drag(at: Vector2) -> void:
	if brush != State.CROSS:
		return
	var cell := _cell_at(at)
	if cell.x < 0 or cell == _last_paint:
		return
	_dragged = true
	if _last_paint.x >= 0:
		var steps := maxi(absi(cell.x - _last_paint.x), absi(cell.y - _last_paint.y))
		for i in range(1, steps):
			_paint(Vector2i(roundi(lerpf(_last_paint.x, cell.x, float(i) / steps)),
				roundi(lerpf(_last_paint.y, cell.y, float(i) / steps))))
	_paint(cell)
	_redraw()

## A stroke paints a cell once, sinks every cell it can change, and passes
## over queens and the cells a queen sees.
func _paint(cell: Vector2i) -> void:
	if not state.in_field(cell):
		return
	_last_paint = cell
	if _swept.has(cell):
		return
	_swept[cell] = true
	var mark := state.mark_at(cell)
	if _lay:
		if mark != State.BLANK:
			return
	elif mark != State.CROSS:
		return
	_sink_cell(cell)
	_pending.append(cell)

func _release(at_cell: Vector2i) -> void:
	var cell := _press_cell
	var was_drag := _dragged
	var lay := _lay
	var pending := _pending
	var now := _now()
	_release_press()
	_clear_gesture()
	if cell.x < 0 or is_done():
		_end_sinks(now)
		_redraw()
		return
	if brush == State.QUEEN:
		_end_sinks(now)
		# A press with the crown chip is a tap only if it is let go on the
		# cell it landed on; a finger that wandered off has changed its mind.
		if at_cell == cell:
			_tap_crown(cell, now)
		_redraw()
		return
	if not pending.is_empty():
		var before := _snapshot()
		var changed: Array = state.sweep(pending, lay)
		var arrivals := _settle(before, now, _along(pending) if was_drag else _at_once())
		_end_sinks(now, arrivals)
		if not changed.is_empty():
			# One stroke is one move, however many cells it crossed. A sweep
			# lays its pebbles in a wave along the finger's path and puffs
			# none; a single tap puffs.
			if not was_drag and lay:
				fx.puff(cell_to_local(cell.y, cell.x), Pal.SOCKET_PEBBLE)
			fx.cue("place")
			_speak()
			_redraw()
			note_move()
			return
	_end_sinks(now)
	_redraw()

## The crown chip on `cell`: a queen there is lifted (or refuses, if given),
## a bare cell or the player's cross seats one, a seen cell refuses.
func _tap_crown(cell: Vector2i, now: float) -> void:
	var before := _snapshot()
	if state.queens.has(cell):
		var lifted: Dictionary = state.lift(cell)
		if not lifted.ok:
			if int(lifted.why) == State.PINNED:
				_refuse_pinned(cell)
			return
		_settle(before, now, _wave_from(cell))
		fx.cue("remove")
		_speak()
		note_move()
		return
	var seated: Dictionary = state.seat(cell)
	if not seated.ok:
		if int(seated.why) == State.SEEN:
			_refuse_seen(cell)
		return
	_settle(before, now, _wave_from(cell), false, state.sees(cell))
	var at := cell_to_local(cell.y, cell.x)
	fx.ring(at, _cell * RING_R, Pal.SUN)
	fx.puff(at, Pal.SUN)
	fx.cue("place")
	_speak()
	note_move()

func _clear_gesture() -> void:
	_press_cell = Vector2i(-1, -1)
	_dragged = false
	_lay = true
	_swept = {}
	_pending = []
	_last_paint = Vector2i(-1, -1)

## The tray armed a chip.
func set_brush(v: int) -> void:
	brush = v

# --- the sprout's line ---

## What the tip card says: the rules while the court is bare, then how many
## queens are seated and how many are to go.
func _speak() -> void:
	if is_done():
		return
	if state.queens.is_empty() and state.crosses.is_empty():
		_say(TIPS[_tip_idx], Face.Expr.HAPPY)
		return
	var seated := state.queens.size()
	var left := state.queens_left()
	if seated == 0:
		_say("%d queens to seat." % left, Face.Expr.HAPPY)
		return
	_say("%d %s seated, %d to go." % [seated, "queen" if seated == 1 else "queens", left],
		Face.Expr.HAPPY)

func _say(text: String, mood: int) -> void:
	_tip_text = text
	_tip_mood = mood
	# The tip card only re-reads a board when the host refreshes it, and the
	# host refreshes on this signal.
	focus_changed.emit()

func _cycle_tip() -> void:
	if is_done() or _tip_mood != Face.Expr.HAPPY or not state.queens.is_empty() \
			or not state.crosses.is_empty():
		return
	_tip_idx = (_tip_idx + 1) % TIPS.size()
	_say(TIPS[_tip_idx], Face.Expr.HAPPY)

func tip_line() -> Dictionary:
	return {"text": _tip_text, "mood": _tip_mood}

# --- the HUD's actions ---

func can_undo() -> bool:
	return not is_done() and not state.history.is_empty()

## Takes back the last gesture: a queen's seat or lift runs her wave the other
## way, a sweep comes back along its path. Counts no move.
func undo() -> bool:
	if is_done() or state.history.is_empty():
		return false
	var now := _now()
	_release_press()
	_clear_gesture()
	_end_sinks(now)
	var before := _snapshot()
	var cells: Array = state.undo()
	var origin := Vector2i(-1, -1)
	for cell in cells:
		if int(before[cell]) == State.QUEEN or state.mark_at(cell) == State.QUEEN:
			origin = cell
	if origin.x >= 0:
		var wash: Array = state.sees(origin) if state.queens.has(origin) else []
		_settle(before, now, _wave_from(origin), false, wash)
	else:
		_settle(before, now, _along(cells))
	_speak()
	fx.cue("undo")
	_redraw()
	moved.emit()
	return true

func hints_left() -> int:
	return HINTS - hints_used

## Seats the answer's queen in the first row that lacks her and pins her: a
## wrong queen in her way pops out first, a ring pulses out of the cell, the
## crown drops in from above, sparkles rise, and her wave runs. Counts no
## move but can finish the puzzle.
func hint() -> bool:
	if is_done() or hints_left() <= 0:
		return false
	var now := _now()
	_release_press()
	_clear_gesture()
	_end_sinks(now)
	var before := _snapshot()
	var out: Dictionary = state.hint()
	var target: Vector2i = out.cell
	if target.x < 0:
		return false
	hints_used += 1
	# The wrong queens go first and at once; the snapshot forgets them so the
	# wave lays their cells' pebbles like any other.
	for q in out.lifted:
		_crown_down(q, 0.0)
		before[q] = State.BLANK
	_settle(before, now, _wave_from(target), true, state.sees(target))
	var at := cell_to_local(target.y, target.x)
	fx.ring(at, _cell * RING_R, Pal.LEAF)
	fx.sparkle(at, Pal.LEAF)
	fx.cue("hint")
	_say("This queen was given, and she stays." if (out.lifted as Array).is_empty()
		else "That queen was in the wrong seat. This one was given, and she stays.",
		Face.Expr.HAPPY)
	_redraw()
	moved.emit()
	check_solved()
	return true

## Every queen the answer does not seat there wobbles and her cell blushes,
## and the sprout says how many. Crosses are left alone: a cross is a note,
## not a claim.
func check() -> int:
	if is_done():
		return 0
	checks += 1
	var wrong: Array = state.wrong_queens()
	for cell in wrong:
		if _crowns.has(cell):
			_wobble(_crowns[cell])
		_blush_cell(cell)
	_say("%d %s in the wrong seat." % [wrong.size(), "queen is" if wrong.size() == 1 else "queens are"]
		if not wrong.is_empty() else "Every queen you have seated is right.",
		Face.Expr.WORRIED if not wrong.is_empty() else Face.Expr.JOY)
	fx.cue("check" if not wrong.is_empty() else "check_ok")
	_redraw()
	return wrong.size()

## Every queen and cross the player laid goes, in a wave from the far corner;
## a given queen hops and keeps her crosses. Hints spent are not refunded.
func reset_board() -> void:
	var now := _now()
	_release_press()
	_clear_gesture()
	_end_sinks(now)
	var before := _snapshot()
	state.reset()
	var wave := _from_far_corner()
	_settle(before, now, wave)
	if not Motion.reduce:
		for cell in state.queens:
			if _crowns.has(cell):
				_hop(_crowns[cell], Motion.RESET_HOP, Motion.HOP_TIME, float(wave.call(cell, false)))
	_blush = {}
	_shiver = {}
	moves = 0
	_running = true
	_say("The court is cleared. A given queen keeps her seat.", Face.Expr.HAPPY)
	fx.cue("reset")
	_redraw()

func is_solved() -> bool:
	return state.is_solved()

func share_glyphs() -> String:
	return state.share_glyphs()

# --- the win ---

## One crown in JOY, and the words. The board stays on the card as it slides
## down, every queen on her colour and the crosses gone.
func flat_win() -> Dictionary:
	return {"faces": [CrownFace.new()], "subtitle": "Every queen has her seat."}

func win_delay() -> float:
	return Motion.REDUCED_TIME if Motion.reduce else WIN_WAIT

## The crowns hop in the family's wave along the diagonal with JOY and a
## spark each, and the pebbles clear away in a scatter, leaving the queens on
## their colours.
func _on_solved() -> void:
	var now := _now()
	_release_press()
	_clear_gesture()
	_end_sinks(now)
	_tip_timer.stop()
	_solved_at = now
	_blush = {}
	_shiver = {}
	var k := 0
	for cell in state.queens:
		var crown := _crown_node(cell)
		var delay := _solve_delay(cell)
		_hop(crown, Motion.SOLVE_HOP, Motion.SOLVE_TIME, delay)
		_grin(crown, delay)
		_after(delay, _spark_at.bind(k, cell_to_local(cell.y, cell.x)))
		k += 1
	_say("Every queen has her seat.", Face.Expr.JOY)
	fx.cue("solved")
	_busy_for(maxf(_solve_delay(Vector2i(state.n, state.n)) + Motion.SOLVE_TIME,
		CLEAR_DELAY + CLEAR_SPREAD + CLEAR_TIME))
	_redraw()

func _solve_delay(cell: Vector2i) -> float:
	if Motion.reduce:
		return 0.0
	return Motion.SOLVE_DELAY + Motion.stagger(cell.x + cell.y, Motion.SOLVE_STAGGER)

## `crown` goes to JOY as the wave reaches her; at once under reduce-motion.
func _grin(crown: Face, delay: float) -> void:
	if delay <= 0.0:
		crown.expression = Face.Expr.JOY
	else:
		_after(delay, func() -> void: crown.expression = Face.Expr.JOY)

## A spark as crown `k` hops, the two pools used in turn so a run of nine a
## few hundredths apart does not recycle one pool fast enough to cut each
## burst in half.
func _spark_at(k: int, at: Vector2) -> void:
	if k % 2 == 0:
		fx.sparkle(at, Pal.SUN)
	else:
		fx.puff(at, Pal.SUN, 4)

# --- odds and ends ---

## Kills every tween the previous board still tracks and retires its pending
## callbacks, so a rebuild never inherits a hop aimed at a crown that is gone.
func _stop_all() -> void:
	_gen += 1
	_pressed = null
	for tw in _pos_tw.values():
		Motion.stop(tw)
	for tw in _look_tw.values():
		Motion.stop(tw)
	_pos_tw = {}
	_look_tw = {}

## Runs `what` after `delay`, unless the board has been rebuilt meanwhile.
func _after(delay: float, what: Callable) -> void:
	var gen := _gen
	get_tree().create_timer(maxf(delay, 0.0)).timeout.connect(func() -> void:
		if gen == _gen and is_inside_tree():
			what.call())

## Seconds since the scene started, the clock every animation here reads.
func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

func _dec(u: float) -> float:
	return 1.0 if Motion.reduce else clampf(u, 0.0, 1.0)

## A fixed pseudo-random number per cell, so the pebbles clear away in a
## scatter rather than a wave.
static func _hash(cell: Vector2i) -> float:
	return float(posmod(hash(cell), 1000)) / 1000.0
```

- [ ] **Step 3: Run the suite and the win harness**

Run: `godot --headless --path . --script res://tests/run_tests.gd 2>&1 | tail -3`
Expected: 0 failures. (The suite does not load the board, but a parse error in `queens_state.gd` or the tray would show here.)

Run: `godot --path . --resolution 540x960 --script res://tests/_win.gd 2>&1 | grep -v '^$' | tail -14`
Expected: a `queens` line reading `8x8 court, 8 queens, board fit=true, hud=true` and a total of `10/10` (nine before). If the board fails to load, run `godot --headless --path . --check-only --script res://puzzles/queens2d.gd 2>&1 | head` for the parse error. If `hud=false`, the hint or the check button did not reach the board: check `capabilities()` and that `_host.top_bar.hint_button` is enabled (`hints_left() > 0`).

- [ ] **Step 4: Shoot every board once**

Run: `godot --path . --resolution 540x960 --script res://tests/_shot.gd 2>&1 | grep saved | tail -3`
Then look at `/tmp/shot_queens.png` with the Read tool. Expected: the flat chrome with `QUEENS` in the top bar, the day card, the court on parchment with eight regions in pastels under ink seams and a dot in every cell, the Queen and Cross chips with the Queen chip lifted and bordered, Reset and Check, and the sprout's first line. Also look at `/tmp/shot_nonogram.png` to confirm the tray still reads Tile and Cross.

- [ ] **Step 5: Commit**

```bash
git checkout project.godot 2>/dev/null
git add puzzles/queens2d.gd puzzles/queens2d.gd.uid ui/registry.gd tests/_win.gd
git commit -m "feat(queens): the flat board, the tenth card, and the win harness solving it"
```

---

### Task 6: The animation strip, the contact sheet and the numbers

**Files:**
- Modify: `tests/_shot_anim.gd` (the header doc, the dispatch at the `elif _entry.id == "nonogram"` line, and one new function)
- Modify: `puzzles/queens2d.gd` only where a frame shows something wrong

**Interfaces:**
- Consumes: `_puzzle.n`, `_puzzle.state.solution`, `_puzzle.cell_to_local`, `_host.top_bar.hint_button`, `_host.action_bar.check_button`, `_host.action_bar.reset_button`, `_host.tray.chips`.

- [ ] **Step 1: Add the strip's branch**

In `tests/_shot_anim.gd`, in the header doc after the sentence ending `and the idle window has a row of tiles in it.` add:

```gdscript
## Queens has the answer's first queen seated, so the strip shows the crown
## pop and the wave of crosses running out of her, and the idle window has a
## queen and her crosses in it.
```

In `_process`, after

```gdscript
		elif _entry.id == "nonogram" and not _empty:
			_begin_nonogram_sweep()
```

add

```gdscript
		elif _entry.id == "queens" and not _empty:
			_tap_queens()
```

After `_begin_nonogram_sweep` add:

```gdscript
## Queens: one real touch on the answer's first queen, with the crown chip the
## tray arms by default.
func _tap_queens() -> void:
	var c: int = int(_puzzle.state.solution[0])
	_tap_global(_puzzle.get_global_transform_with_canvas() * _puzzle.cell_to_local(0, c))
```

- [ ] **Step 2: Shoot the strip, twice**

Run: `godot --path . --resolution 1080x1920 --script res://tests/_shot_anim.gd -- queens 2>&1 | grep -E 'saved|idle'`
Expected: six `saved /tmp/anim_queens_N.png` lines and one `idle frames=... mean_ms=... max_draw_calls=...` line. Run it a second time and keep both idle lines. Then run `... -- queens empty` twice for the bare board.

Look at each frame with the Read tool:
- `_0` (0.35 s): the court mid-pop, slightly small and fading in, the chrome sliding.
- `_1` (0.9 s): the court at rest, a dot in every cell, the Queen chip lifted and bordered.
- `_2` (1.65 s): the crown popping in on row 0 (squashed), a gold ring starting, the nearest cells washing gold with their pebbles just appearing.
- `_3` (1.8 s): the wave four or five rings out: gold washes fading behind it, pebbles landed near the queen, dots still ahead of it.
- `_4` (2.8 s): landed: the crown at rest with her shadow, a pebble at 0.75 alpha on every cell she sees, dots elsewhere, the sprout saying `1 queen seated, 7 to go.`
- `_5` (3.8 s): the same, still.

What to fix if it is not so: pebbles appearing all at once means `_cross_in` is not being honoured for `e < 0` in `_build_ground`; no gold means `_wash` is empty (check `_settle`'s `wash` argument) or `QUEEN_WASH` over a pastel is too faint (raise `WAVE_FLASH` to 0.45, note it for the spec); a crown without a shadow means `_crown_shadow` is not reached (`crown.visible`); a dot under a landed pebble means the floor's `bare` test is wrong.

Write down: peak draw calls and mean idle ms, bare and with the seated queen, two readings each, against the 855 budget and the family's 63 to 97 calls.

- [ ] **Step 3: The contact sheet**

Write `/tmp/_queens_probe.gd` (throwaway, not committed):

```gdscript
extends SceneTree

## Throwaway: a contact sheet of the flat Queens' moments. Saves
## /tmp/queens_<name>.png. Pass `-- rm` to run it under reduce-motion.

const Motion = preload("res://core/motion.gd")
const DRAG_TIME := 0.35

var _menu: Node
var _host: Node
var _puzzle: Node
var _t := -0.2
var _opened := false
var _steps: Array = []
var _shots: Array = []
var _finish := INF
var _drag_from := Vector2.ZERO
var _drag_by := Vector2.ZERO
var _drag_until := INF
var _drag_done := true

func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	Motion.reduce = OS.get_cmdline_user_args().has("rm")
	var main: Node = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	_menu = main.get_node("UI/Menu")

func _process(delta: float) -> bool:
	_t += delta
	if not _opened:
		if _t < 0.0:
			return false
		_opened = true
		_t = 0.0
		var entry: Dictionary = load("res://ui/registry.gd").find("queens")
		_menu._open(entry)
		_host = _menu.get_child(_menu.get_child_count() - 1)
		_puzzle = _host._puzzle
		_plan()
		return false
	for s in _steps:
		if not s[2] and _t >= s[0]:
			s[2] = true
			s[1].call()
	if not _drag_done:
		_drag_step()
	for s in _shots:
		if not s[2] and _t >= s[0]:
			s[2] = true
			var path := "/tmp/queens_%s%s.png" % [s[1], "_rm" if Motion.reduce else ""]
			root.get_texture().get_image().save_png(path)
			print("saved %s at t=%.2f" % [path, _t])
	return _t >= _finish

func _step(at: float, what: Callable) -> void:
	_steps.append([at, what, false])

func _shot(at: float, name: String) -> void:
	_shots.append([at, name, false])

func _plan() -> void:
	var n: int = _puzzle.n
	var sol: PackedInt32Array = _puzzle.state.solution
	_step(1.6, func() -> void: _tap_cell(0, int(sol[0])))
	_shot(1.7, "seat_pop")
	_shot(1.85, "wave_mid")
	_shot(2.3, "wave_landed")
	# A wrong queen: the first bare cell of row 2 that is not the answer's.
	_step(2.6, func() -> void:
		for c in n:
			if _puzzle.state.mark_at(Vector2i(c, 2)) == 0 and c != int(sol[2]):
				_tap_cell(2, c)
				return)
	_shot(2.75, "wrong_seated")
	_step(3.2, func() -> void: _press(_host.top_bar.hint_button))
	_shot(3.3, "hint_drop")
	_shot(3.55, "hint_wave")
	_step(4.0, func() -> void: _press(_host.action_bar.check_button))
	_shot(4.15, "check")
	# The crown chip on a seen cell: refused.
	_step(4.6, func() -> void:
		for cell in _puzzle.state.seen:
			_tap_cell(cell.y, cell.x)
			return)
	_shot(4.7, "refused")
	_step(5.2, func() -> void: _press(_host.tray.chips[1]))
	_step(5.4, func() -> void: _drag_row(n - 1))
	_shot(5.6, "sweep_down")
	_shot(5.95, "sweep_landed")
	_step(6.4, func() -> void: _press(_host.tray.chips[0]))
	_step(6.6, func() -> void: _press(_host.action_bar.reset_button))
	_shot(6.7, "reset_wave")
	_shot(7.0, "reset_done")
	var t := 7.4
	for r in n:
		var row := r
		_step(t, func() -> void:
			if not _puzzle.state.queens.has(Vector2i(int(sol[row]), row)):
				_tap_cell(row, int(sol[row])))
		t += 0.35
	_shot(t + 0.3, "solve_wave")
	_shot(t + 0.9, "solve_clear")
	_shot(t + 2.4, "win")
	_finish = t + 2.6

func _tap_cell(r: int, c: int) -> void:
	_tap_global(_puzzle.get_global_transform_with_canvas() * _puzzle.cell_to_local(r, c))

func _press(btn: Button) -> void:
	_tap_global(btn.get_global_transform_with_canvas() * (btn.size * 0.5))

func _tap_global(at: Vector2) -> void:
	for pressed in [true, false]:
		var ev := InputEventScreenTouch.new()
		ev.index = 0
		ev.pressed = pressed
		ev.position = at
		root.push_input(ev, true)

## A drag along row `r` from its first cell to its last, one event a frame.
func _drag_row(r: int) -> void:
	var xf: Transform2D = _puzzle.get_global_transform_with_canvas()
	_drag_from = xf * _puzzle.cell_to_local(r, 0)
	_drag_by = xf * _puzzle.cell_to_local(r, _puzzle.n - 1) - _drag_from
	var down := InputEventScreenTouch.new()
	down.index = 0
	down.pressed = true
	down.position = _drag_from
	root.push_input(down, true)
	_drag_until = _t + DRAG_TIME
	_drag_done = false

func _drag_step() -> void:
	var u := clampf(1.0 - (_drag_until - _t) / DRAG_TIME, 0.0, 1.0)
	var at := _drag_from + _drag_by * (1.0 - pow(1.0 - u, 2.0))
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = at
	root.push_input(drag, true)
	if u >= 1.0:
		var up := InputEventScreenTouch.new()
		up.index = 0
		up.pressed = false
		up.position = at
		root.push_input(up, true)
		_drag_done = true
```

Run: `godot --path . --resolution 1080x1920 --script /tmp/_queens_probe.gd 2>&1 | grep -E 'saved|ERROR|error'`
Expected: sixteen `saved` lines and no errors. Look at every frame with the Read tool and judge each against the spec's section 9:

| Frame | Expected |
|---|---|
| `seat_pop` | the crown mid-squash on her cell, a gold ring, the first pebbles appearing beside her |
| `wave_mid` | washes fading behind the wave front, pebbles landed near, dots ahead |
| `wave_landed` | every cell she sees crossed at 0.75, the rest dotted, the sprout counting |
| `wrong_seated` | a second crown on row 2, her own crosses arriving |
| `hint_drop` | the given crown above her cell on the way down (or landed if the frame is late), a leaf ring; if the wrong queen saw her cell she is mid-pop-out |
| `hint_wave` | the given crown landed with a green gem, her crosses arriving |
| `check` | any remaining wrong crown tilted mid-wobble over a rose-washed cell; if none is wrong, the sprout saying every seated queen is right |
| `refused` | a pebble shifted sideways over a rose-washed cell, the sprout saying a queen already sees that seat |
| `sweep_down` | the cells under the drag shaded, the Cross chip lifted |
| `sweep_landed` | the swept bare cells of the last row crossed at full ink, the queens' crosses left as they were |
| `reset_wave` | pebbles and the player's crowns shrinking in a wave from the bottom right, the given crown hopping |
| `reset_done` | only the given crown and her crosses remain |
| `solve_wave` | crowns hopping along the diagonal with JOY, sparkles |
| `solve_clear` | pebbles fading in a scatter, queens on their colours |
| `win` | the win screen: one crown, `Every queen has her seat.`, the board shrunk below |

Then run `... /tmp/_queens_probe.gd -- rm` and look at `wave_landed_rm`, `hint_wave_rm`, `reset_done_rm`, `win_rm`: under reduce-motion a queen and every cross she brings are there in one frame, nothing washes gold or rose, and the win follows the last tap. Fix the board where a frame disagrees, re-run the frame, and record any constant you changed for the spec's amendment.

- [ ] **Step 4: Run the suite and commit**

Run: `godot --headless --path . --script res://tests/run_tests.gd 2>&1 | tail -3`
Expected: 0 failures.

```bash
git checkout project.godot 2>/dev/null
git add tests/_shot_anim.gd puzzles/queens2d.gd
git commit -m "feat(queens): the strip's branch, and what the contact sheet corrected"
```

(If nothing in the board changed, commit only the harness.)

---

### Task 7: The card

**Files:**
- Modify: `ui/menu/card_art.gd` (the preloads, `_build`, `_draw`, one new drawing, and the header comment)

**Interfaces:**
- Consumes: `CrownFace`, `Pal.REGION`, `Pal.TEXT`.

- [ ] **Step 1: Draw the card**

In `ui/menu/card_art.gd`, in the header comment replace `Nine of the twelve` with `Ten of the twelve`, add `Queens' crown` to the list after `One Line's snail`, and replace `only the three \`soon\` cards are drawn here outright` with `only the two \`soon\` cards are drawn here outright`.

After `const SnailFace = preload("res://ui/faces/snail_face.gd")` add:

```gdscript
const CrownFace = preload("res://ui/faces/crown_face.gd")
```

In `_build`, before the `_:` branch add:

```gdscript
		"queens":
			# The crown on a patch of the court _draw lays under her.
			_seat(CrownFace.new(), 64.0, 0.0, 2.0)
```

In `_draw`, after `"nonogram": _draw_mosaic()` add:

```gdscript
		"queens": _draw_regions()
```

After `_draw_mosaic` add:

```gdscript
## Queens: six cells of the court in two regions with the seam between them,
## under the crown, and the soft disc she stands on.
func _draw_regions() -> void:
	var cell := 44.0
	var x0 := -cell * 1.5
	var y0 := -cell
	var plan := [[1, 1, 2], [1, 2, 2]]
	for r in 2:
		for k in 3:
			_round(x0 + k * cell, y0 + r * cell, cell, cell, 0.0, Pal.REGION[plan[r][k]])
	_line([Vector2(x0 + 2.0 * cell, y0), Vector2(x0 + 2.0 * cell, y0 + cell),
		Vector2(x0 + cell, y0 + cell), Vector2(x0 + cell, y0 + 2.0 * cell)], 4.0, Pal.TEXT)
	draw_rect(Rect2(at(x0, y0), Vector2(3.0 * cell, 2.0 * cell) * _u), Pal.TEXT, false, 4.0 * _u)
	_disc(0.0, 26.0, 20.0, Color(Pal.TEXT, 0.14))
```

- [ ] **Step 2: Shoot the menu, twice**

Run: `godot --path . --resolution 540x960 --script res://tests/_shot_menu.gd 2>&1 | grep -E 'idle|saved'`
Run it a second time. Expected: two `idle frames=... mean_ms=... max_draw_calls=...` lines; the baseline is 291 draw calls (CLAUDE.md). Look at `/tmp/shot_menu_1.png`: the tenth card, first in the last row, reads `Queens` over `One queen per row, / column and colour.` with a gold crown on a patch of two pastels, at full ink with a go button; Pipes and Horse Pen dimmed beside it; no Snake Apple. Write down the draw calls.

- [ ] **Step 3: Run the suite and commit**

Run: `godot --headless --path . --script res://tests/run_tests.gd 2>&1 | tail -3`
Expected: 0 failures.

```bash
git checkout project.godot 2>/dev/null
git add ui/menu/card_art.gd
git commit -m "feat(menu): the Queens card, a crown on two colours"
```

---

### Task 8: The record

**Files:**
- Modify: `CLAUDE.md` (five passages), `docs/art/flat-motion.md` (the Boards on it table), `docs/superpowers/specs/2026-09-19-queens-flat-design.md` (section 11 and a section 13), `tests/_shot.gd:22` (a comment)

**Interfaces:** none; this task writes what Tasks 1 to 7 measured. Have their numbers to hand: the generator's three timing lines (Task 1), the strip's draw calls and idle ms bare and seated, two readings each (Task 6), the menu's draw calls (Task 7), the suite's count and the win harness's `10/10`.

- [ ] **Step 1: CLAUDE.md**

In the bullet beginning `- **A card's picture is the board's own cast**`, replace `Nine of the twelve` with `Ten of the twelve`.

Replace the bullet beginning `- **Twelve cards, and three of them do not open.** Pipes, Horse Pen and` so that it reads:

```markdown
- **Twelve cards, and two of them do not open.** Pipes and Horse Pen have
  no flat board: they keep their picture and name at 55% ink, wear a pale
  `SOON` pill and emit `blocked`, and the menu answers with a line saying
  their island version is under More. They stand together at the end of the
  last row on purpose -- dimmed cards scattered through a grid read as a
  bug. Snake Apple's `soon` card left the grid on 2026-09-19 to make room
  for Queens, the tenth live card: it is the one being redesigned outright,
  and its island board stays under More with `seed_as` still `snake`. The
  pill hangs off the card, **not** off `_inner`: that is a PanelContainer
  and a second child there is stretched over everything.
```

In the bullet beginning `- **The registry is two lists.**`, replace `(nine flat plus the three \`soon\`)` with `(ten flat plus the two \`soon\`)`.

Replace the paragraph beginning `Nine cards open a flat 2D board under flat chrome:` so that it reads:

```markdown
Ten cards open a flat 2D board under flat chrome: **Binairo**
(`puzzles/binairo2d.gd`), **Code Break** (`puzzles/codebreak2d.gd`),
**Balance** (`puzzles/balance2d.gd`), **Shikaku**
(`puzzles/shikaku2d.gd`), **Untangle** (`puzzles/untangle2d.gd`), **Tents**
(`puzzles/tents2d.gd`), **Light Up** (`puzzles/lightup2d.gd`), **One Line**
(`puzzles/oneline2d.gd`), **Nonogram** (`puzzles/nonogram2d.gd`) and, since
2026-09-19, **Queens** (`puzzles/queens2d.gd`).
```

In the `Specs:` sentence that follows, after `...-nonogram-flat-design.md` siblings` add `, and `docs/superpowers/specs/2026-09-19-queens-flat-design.md``; in the `mocks:` list after `#nonogram` add ` and `#queens``.

In the bullet beginning `- **The registry picks the shell**`, replace `the nine screens want 460, 460, 390, 290, 140, 290, 290, 290 and 460` with `the ten screens want 460, 460, 390, 290, 140, 290, 290, 290, 460 and 460`, and after `"tiles"` in the tray list add `, "crowns"`.

After the bullet that ends `so a drawn tile can squash, wobble, turn out and flash.` (the long "Every flat board moves with one hand" bullet), add a new bullet:

```markdown
- **Queens is the precedent for a board that answers a move** (2026-09-19,
  `puzzles/queens2d.gd`, spec `2026-09-19-queens-flat-design.md`). A seated
  queen crosses out every cell she sees; those crosses are **derived** by the
  state (`seen`, a count per cell rebuilt after every change) and never
  stored, so lifting her takes them with her and undo keeps no book for
  them. A crown on a seen cell is **refused**, so two queens can never
  conflict and the n-th queen is the win. The wave is its signature: every
  move goes through one `_settle` that diffs a snapshot of the court against
  the state and hands each changed cell its moment, with a Callable saying
  when -- a queen's king-move distance times `WAVE_STEP` (reversed for a
  lift, far cells first), a sweep's path, Reset's far corner -- and the
  cells the queen sees flash gold (`QUEEN_WASH` at `WAVE_FLASH`) as it
  reaches them. The crown (`ui/faces/crown_face.gd`) is the cast's one new
  species since the snail. The tile tray takes a **chip set** now
  (`TileTray.MOSAIC`, `TileTray.CROWNS`; `"tray": "crowns"`), so Nonogram's
  tray and Queens' are one class.
```

- [ ] **Step 2: flat-motion.md**

In `docs/art/flat-motion.md`, in the `## Boards on it` table, after the Nonogram row add (fill the numbers from Task 6):

```markdown
| Queens | on it (2026-09-19), built on the vocabulary from the first line rather than ported: the court pops in wide about its centre; a cell shades under the finger and the piece on it sinks; a seated crown pops in with the squash under a gold ring and puff and her crosses arrive in a wave by king-move distance at `WAVE_STEP` 0.045, each cell flashing `QUEEN_WASH` as the wave reaches it, read off `flash_level` and `pop_in_scale`; a lifted crown shrinks with the quarter turn and her crosses leave far first; a sweep sinks its cells and lays pebbles along the path at `ENTER_STAGGER`; a hint's crown drops in under a leaf ring with a sparkle, a wrong queen in her way popping out first; Check wobbles a wrong crown and blushes her cell; a refused seat shivers the pebble and blushes the cell, a refused given queen shivers and strains; Reset shrinks everything the player laid in a wave from the far corner while given queens hop; the solve wave hops the crowns to JOY along the diagonal and the pebbles clear in a scatter. Crowns in slots over two drawn meshes on one clock (rule 8). Measured: N draw calls bare and N with a seated queen's crosses, N.NN and N.NN ms idle bare at 1080 x 1920 on this Mac, N.NN and N.NN with a queen seated |
```

- [ ] **Step 3: The spec**

In `docs/superpowers/specs/2026-09-19-queens-flat-design.md`, replace section 11's paragraph with a table of what was measured:

```markdown
## 11. Measured

On this Mac, 2026-09-19.

| | Value |
|---|---|
| Generator, 20 seeds each: 7x7 / 8x8 / 9x9 mean and worst | from Task 1's three lines |
| Medium board at rest, bare: draw calls, idle ms (two readings) | from Task 6 |
| Medium board with the first queen seated: draw calls, idle ms (two readings) | from Task 6 |
| The first screen with the Queens card: draw calls, against 291 | from Task 7 |
| Suite | N checks, 0 failures |
| `tests/_win.gd` windowed | 10/10, Queens solved through the real hint button, Check and taps |

The 855 draw-call budget is the binding one; the idle number is a report.
```

and append a section:

```markdown
## 13. Amendments from the build, 2026-09-19

- **A press with the crown chip is a tap only if it is let go on the cell it
  landed on.** Section 6 said a drag with the crown chip is a tap where it
  ends; a finger that wanders off a cell on a phone has more often changed
  its mind than aimed, so the board takes the press cell or nothing.
- **No clouds or tufts under the card.** Section 8 promised the family's
  scenery; the court fills the card, as Nonogram's floor does, and there is
  nowhere for a cloud to be.
- **A crown under the finger sinks whichever chip is armed**, including the
  cross chip, which does nothing to her on release: every tappable piece
  takes the press.
- Any constant the contact sheet changed (Task 6), with the value before and
  after, one line each. If none changed, say so.
```

Also in `tests/_shot.gd`, change the comment `# The three \`soon\` cards name a board that has no flat version, so they` to `# The two \`soon\` cards name a board that has no flat version, so they`.

- [ ] **Step 4: Commit**

```bash
git add CLAUDE.md docs/art/flat-motion.md docs/superpowers/specs/2026-09-19-queens-flat-design.md tests/_shot.gd
git commit -m "docs(queens): the tenth flat board on the record, measured"
```

---

## Done when

- The suite reports 0 failures and the win harness 10/10.
- `/tmp/anim_queens_*.png` and the contact sheet show every moment of the spec's section 9, with and without reduce-motion.
- The first screen shows Queens as the tenth card and Pipes and Horse Pen dimmed after it, within the draw-call budget.
- CLAUDE.md, flat-motion.md and the spec carry the numbers.
- Everything is committed on `feat/queens-flat`; nothing is pushed.
