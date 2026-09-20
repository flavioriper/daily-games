extends RefCounted

## Pinwheel's generator: grow an answer, pin it, prove it, scramble it.
##
## The board is a rectangle exactly tiled by polyominoes. Each piece is
## pinned through one of its own cells and can only rotate about that pin,
## which means **a piece has at most four placements in the whole frame** --
## it cannot translate at all. That is the opposite of Quilt, whose patches
## translate freely, and it is why the warning in `quilt_gen.gd`'s header
## ("a rotating patch would make almost every region tileable a dozen ways")
## does not apply here. Pinwheel is far more constrained than Quilt, and
## uniqueness comes almost free: the median board is proved on the first or
## second grow.
##
## Five stages, and each one can reject:
##   1. grow   -- partition the frame into polyominoes of the band's sizes
##   2. pin    -- choose each piece's pin to maximise its in-frame orientations
##   3. prove  -- exact cover, capped at two solutions; require exactly one
##   4. colour -- eight cloths, properly; a board needing a ninth is thrown away
##   5. scramble -- the tidiest opening that still needs the band's taps
##
## There is no wall-clock budget and no `graded: false`. The loop is bounded
## by ATTEMPTS and the honest flag is `unique: false`, which is Quilt's
## answer rather than Sudoku's; a board that fails the proof is still
## playable, because the scramble is by construction reachable from a real
## tiling.
##
## Seeded only by the `rng` handed in, so a day is the same frame on every
## phone. Spec: docs/superpowers/specs/2026-09-20-pinwheel-flat-design.md,
## section 5.

const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

## The three bands: the frame, the size multiset the grow partitions it into,
## the taps a scramble must be worth, and how deep a pile it may open with.
## Each multiset sums to exactly `cols * rows`, which is what makes "no cell
## bare" and "no cell stained" the same sentence (the spec's rule 7). Band 1
## is the 5x7 of eleven pieces counted off the reference screenshot, and it
## is the band the menu opens.
const BANDS := [
	{"cols": 5, "rows": 5, "sizes": [1, 2, 2, 3, 3, 3, 4, 4, 3], "min_turns": 8, "max_stack": 2},
	{"cols": 5, "rows": 7, "sizes": [1, 2, 2, 3, 3, 3, 4, 4, 4, 5, 4], "min_turns": 14, "max_stack": 3},
	{"cols": 6, "rows": 8, "sizes": [2, 2, 3, 3, 3, 4, 4, 4, 5, 5, 5, 4, 4], "min_turns": 20, "max_stack": 3},
]

const ATTEMPTS := 400     ## grows before the loop gives up
const SCRAMBLES := 220    ## openings tried per proved board, best kept
const CLOTHS := 8         ## Pal.CLOTH's size, mirrored here so the generator stays scene-free

static func band(difficulty: int) -> Dictionary:
	return BANDS[clampi(difficulty, 0, BANDS.size() - 1)]

# ------------------------------------------------------------- the generator

## Grow, pin, prove, colour, scramble; the first board that passes all five
## is the board. A proved board whose scramble was too tidy or too deep to
## satisfy the band is kept as a fallback with a plain scramble over it, so a
## seed that somehow exhausts ATTEMPTS still opens a real puzzle rather than
## nothing -- Quilt's order of preference, for Quilt's reason.
static func generate(rng: RandomNumberGenerator, difficulty: int) -> Dictionary:
	var d := clampi(difficulty, 0, BANDS.size() - 1)
	var b: Dictionary = BANDS[d]
	var cols := int(b.cols)
	var rows := int(b.rows)
	var fallback := {}
	for attempt in range(1, ATTEMPTS + 1):
		var pieces: Array = _grow(rng, b)
		if pieces.is_empty():
			continue
		var pins := PackedInt32Array()
		var shapes: Array = []
		for cells: Array in pieces:
			var pin: Vector2i = _pin(rng, cells, cols, rows)
			pins.append(pin.y * cols + pin.x)
			shapes.append(orientations(cells, pin, cols, rows))
		if count_tilings(shapes, cols, rows, 2) != 1:
			continue
		# Colour before scrambling: it is the cheaper of the two stages and the
		# likelier rejection. A board eight cloths cannot colour properly is
		# thrown away here exactly as a board that failed the proof is.
		var cloth: PackedInt32Array = _colour(shapes)
		if cloth.is_empty():
			continue
		var scramble: Dictionary = _scramble(rng, shapes, cols, rows, b)
		if scramble.is_empty():
			if fallback.is_empty():
				fallback = _board(cols, rows, pins, shapes, cloth,
					_plain_scramble(rng, shapes), attempt)
			continue
		return _board(cols, rows, pins, shapes, cloth, scramble, attempt)
	if not fallback.is_empty():
		return fallback
	# The total-failure dictionary: no frame, no pieces, nothing to look at and
	# nothing to play. It is the one path left that colours loosely instead of
	# rejecting, because rejecting here would hand back nothing at all -- and it
	# has no pieces to mis-colour.
	return {
		"cols": 0, "rows": 0, "pins": PackedInt32Array(), "shapes": [],
		"answer": PackedInt32Array(), "start": PackedInt32Array(),
		"cloth": _colour([], false), "unique": false,
		"attempts": ATTEMPTS, "turns": 0,
	}

static func _board(cols: int, rows: int, pins: PackedInt32Array, shapes: Array,
		cloth: PackedInt32Array, scramble: Dictionary, attempt: int) -> Dictionary:
	var answer := PackedInt32Array()
	answer.resize(shapes.size())
	# `answer` is all zeros because the grow *is* the answer and `orientations`
	# keeps the grown one first. It is handed over anyway so nothing downstream
	# has to know that, and so a generator that one day grows the scramble
	# instead does not break a single consumer.
	return {
		"cols": cols,
		"rows": rows,
		"pins": pins,
		"shapes": shapes,
		"answer": answer,
		"start": scramble.start,
		"cloth": cloth,
		"unique": true,
		"attempts": attempt,
		"turns": int(scramble.turns),
	}

# ------------------------------------------------------------------ the grow

## Partition the frame into polyominoes of the band's sizes. Each piece seeds
## at a free cell with the **fewest free orthogonal neighbours** -- the
## tightest corner left on the board -- and then accretes at random from its
## own frontier.
##
## Seeding into the tightest corner is load-bearing and not a flourish: a
## piece seeded in open ground leaves the awkward cells for last, the last
## piece wedges into two disconnected holes, and the grow is thrown away.
## `quilt_gen.gd` reaches for the same instinct from the same evidence.
## Returns `[]` when a piece runs out of frontier or a cell is left over.
static func _grow(rng: RandomNumberGenerator, b: Dictionary) -> Array:
	var cols := int(b.cols)
	var rows := int(b.rows)
	var order: Array = (b.sizes as Array).duplicate()
	_shuffle(rng, order)
	var grid: Array = []
	grid.resize(cols * rows)
	grid.fill(-1)
	var pieces: Array = []
	for idx in order.size():
		var free: Array = []
		for i in grid.size():
			if int(grid[i]) < 0:
				free.append(i)
		if free.is_empty():
			return []
		var least := 5
		var seeds: Array = []
		for i: int in free:
			var deg := _free_degree(grid, cols, rows, i)
			if deg < least:
				least = deg
				seeds = [i]
			elif deg == least:
				seeds.append(i)
		var seed_cell: int = seeds[rng.randi_range(0, seeds.size() - 1)]
		var cells: Array = [seed_cell]
		grid[seed_cell] = idx
		while cells.size() < int(order[idx]):
			var front: Array = []
			for i: int in cells:
				for n: int in _free_neighbours(grid, cols, rows, i):
					front.append(n)
			if front.is_empty():
				return []
			var grown: int = front[rng.randi_range(0, front.size() - 1)]
			grid[grown] = idx
			cells.append(grown)
		cells.sort()
		pieces.append(cells)
	for i in grid.size():
		if int(grid[i]) < 0:
			return []
	var out: Array = []
	for cells: Array in pieces:
		var v: Array = []
		for i: int in cells:
			v.append(Vector2i(i % cols, i / cols))
		out.append(v)
	return out

static func _free_degree(grid: Array, cols: int, rows: int, i: int) -> int:
	return _free_neighbours(grid, cols, rows, i).size()

static func _free_neighbours(grid: Array, cols: int, rows: int, i: int) -> Array:
	var c := Vector2i(i % cols, i / cols)
	var out: Array = []
	for d: Vector2i in DIRS:
		var n := c + d
		if n.x < 0 or n.x >= cols or n.y < 0 or n.y >= rows:
			continue
		var j := n.y * cols + n.x
		if int(grid[j]) < 0:
			out.append(j)
	return out

static func _shuffle(rng: RandomNumberGenerator, a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap = a[i]
		a[i] = a[j]
		a[j] = swap

# ------------------------------------------------------------- the geometry

## `cells` turned `quarters` quarter turns **clockwise** about `pin`.
## Clockwise on a y-down screen sends the offset (+1, 0) to (0, +1), so the
## step is `d = Vector2i(-d.y, d.x)`. Get that backwards and every board in
## the game is mirrored, which no test downstream of here would notice.
static func rotate(cells: Array, pin: Vector2i, quarters: int) -> Array:
	var k := posmod(quarters, 4)
	var out: Array = []
	for c: Vector2i in cells:
		var d := c - pin
		for _i in k:
			d = Vector2i(-d.y, d.x)
		out.append(pin + d)
	return out

## The piece's distinct in-frame orientations, **in quarters order, index 0
## the cells as given**. A rotation with a cell outside the frame is dropped
## and one that repeats an earlier cell set is dropped, so a 1x1 comes back
## with one and a plus about its own centre with one.
##
## The order is the mechanic: a tap advances the index by one modulo the
## count (the spec's rule 4), so these have to stay in clockwise order and
## the solving orientation has to stay first.
static func orientations(cells: Array, pin: Vector2i, cols: int, rows: int) -> Array:
	var out: Array = []
	var seen := {}
	for k in 4:
		var turned: Array = rotate(cells, pin, k)
		var ids: Array = []
		var inside := true
		for c: Vector2i in turned:
			if c.x < 0 or c.x >= cols or c.y < 0 or c.y >= rows:
				inside = false
				break
			ids.append(c.y * cols + c.x)
		if not inside:
			continue
		ids.sort()
		var key := str(ids)
		if seen.has(key):
			continue
		seen[key] = true
		out.append(turned)
	return out

## The pin that leaves the piece the most orientations, chosen at random
## among the cells that tie. Maximising is what keeps a piece movable: a pin
## chosen carelessly leaves a one-orientation piece and a dead tap.
static func _pin(rng: RandomNumberGenerator, cells: Array, cols: int, rows: int) -> Vector2i:
	var most := -1
	var best: Array = []
	for pin: Vector2i in cells:
		var n: int = orientations(cells, pin, cols, rows).size()
		if n > most:
			most = n
			best = [pin]
		elif n == most:
			best.append(pin)
	return best[rng.randi_range(0, best.size() - 1)]

# ----------------------------------------------------------------- the proof

## Exact cover: every piece takes exactly one of its orientations and every
## cell is covered once. Branches on the **first uncovered cell in scan
## order** -- something has to cover it, so only the orientations that reach
## it are worth trying -- and stops at `cap`.
##
## This is the whole uniqueness proof, and it is cheap here because a pinned
## piece cannot translate: it has at most four placements in the entire
## frame, where a Quilt patch has one per position it fits.
static func count_tilings(shapes: Array, cols: int, rows: int, cap: int) -> int:
	var total := cols * rows
	var ids: Array = []
	var by_cell: Array = []
	by_cell.resize(total)
	for i in total:
		by_cell[i] = []
	for p in shapes.size():
		var ors: Array = []
		for o in (shapes[p] as Array).size():
			var cs: Array = []
			for c: Vector2i in ((shapes[p] as Array)[o] as Array):
				cs.append(c.y * cols + c.x)
			ors.append(cs)
			for cell: int in cs:
				(by_cell[cell] as Array).append(Vector2i(p, o))
		ids.append(ors)
	var cover: Array = []
	cover.resize(total)
	cover.fill(0)
	var used: Array = []
	used.resize(shapes.size())
	used.fill(false)
	return _count(ids, by_cell, cover, used, 0, total, cap)

static func _count(ids: Array, by_cell: Array, cover: Array, used: Array,
		filled: int, total: int, cap: int) -> int:
	if filled == total:
		return 1
	var at := 0
	while int(cover[at]) != 0:
		at += 1
	var found := 0
	for pair: Vector2i in (by_cell[at] as Array):
		if bool(used[pair.x]):
			continue
		var cs: Array = (ids[pair.x] as Array)[pair.y]
		var clear := true
		for cell: int in cs:
			if int(cover[cell]) != 0:
				clear = false
				break
		if not clear:
			continue
		for cell: int in cs:
			cover[cell] = 1
		used[pair.x] = true
		found += _count(ids, by_cell, cover, used, filled + cs.size(), total, cap - found)
		used[pair.x] = false
		for cell: int in cs:
			cover[cell] = 0
		if found >= cap:
			return found
	return found

# -------------------------------------------------------------- the scramble

## The opening. Every piece with somewhere to go is turned off its answer, so
## the board never opens solved, and the tap count is the sum over pieces of
## how many quarters each has to travel to come home.
##
## A pile four deep reads as chaos rather than as a puzzle, so this tries
## many openings and keeps the **tidiest** one that is still worth the band's
## taps: fewest stained cells first, then the shallowest stack. Returns `{}`
## when none of the tries cleared `min_turns` under `max_stack`.
static func _scramble(rng: RandomNumberGenerator, shapes: Array, cols: int, rows: int,
		b: Dictionary) -> Dictionary:
	var best := {}
	for _try in SCRAMBLES:
		var start := PackedInt32Array()
		var turns := 0
		for p in shapes.size():
			var m: int = (shapes[p] as Array).size()
			if m < 2:
				start.append(0)
				continue
			var si := rng.randi_range(1, m - 1)
			start.append(si)
			turns += (m - si) % m
		if turns < int(b.min_turns):
			continue
		var cover: Array = []
		cover.resize(cols * rows)
		cover.fill(0)
		for p in shapes.size():
			for c: Vector2i in ((shapes[p] as Array)[start[p]] as Array):
				cover[c.y * cols + c.x] += 1
		var deepest := 0
		var stained := 0
		for n: int in cover:
			deepest = maxi(deepest, n)
			if n > 1:
				stained += 1
		if deepest > int(b.max_stack):
			continue
		var score := stained * 10 + deepest
		if best.is_empty() or score < int(best.score):
			best = {"start": start, "turns": turns, "score": score}
		if score <= shapes.size():
			break
	return best

## The fallback opening, used only on a board whose tidy scramble never
## cleared the band: every movable piece somewhere other than home, and no
## opinion about how it looks.
static func _plain_scramble(rng: RandomNumberGenerator, shapes: Array) -> Dictionary:
	var start := PackedInt32Array()
	var turns := 0
	for p in shapes.size():
		var m: int = (shapes[p] as Array).size()
		if m < 2:
			start.append(0)
			continue
		var si := rng.randi_range(1, m - 1)
		start.append(si)
		turns += (m - si) % m
	return {"start": start, "turns": turns, "score": 0}

# ------------------------------------------------------------- the colouring

## Give every piece a `Pal.CLOTH` index that keeps it off the pieces it could
## be confused with -- two pieces in one colour read as a single shape, which
## is exactly the information the player is reading the frame for.
##
## The edge is the honest reading of "these two can ever meet": the union of
## A's orientations' cells, **dilated by one orthogonal step**, meeting the
## union of B's. That is symmetric, it covers overlapping as well as touching,
## and it holds in every state the board can be in rather than in one of them.
##
## **Eight cloths cannot always colour that graph, and a board they cannot is
## thrown away.** There is no `p % CLOTHS` fallback on this path: greedy runs
## in descending degree and the moment it would want a ninth cloth this hands
## back an empty array, `generate()` grows another board, and the loop carries
## on exactly as it does for a failed proof. Generation is a few milliseconds
## here, so rejection is the cheap way to keep a promise: over 300 seeds a
## band it throws away **2, 6 and 31** proved boards, which costs 3, 17 and
## 132 extra grows -- a rejected board costs a whole fresh grow-and-prove
## cycle, and band 2 already spends 3.75 grows on an average board.
##
## `strict` is false on one caller only: the total-failure dictionary, which
## has no pieces to colour and nothing playable to spoil.
##
## **A narrower rule shipped here first and was measured against the answer.**
## It forbade a shared cloth only on pieces that could overlap or that touched
## *in the solved frame*, it kept that promise perfectly, and it left a
## same-cloth pair orthogonally touching **in the opening state** on 149, 219
## and 241 boards of 300. The lesson is worth more than the rule: a legibility
## rule measured against the solved frame is measured against the state the
## player spends the least time looking at. The spec's section 5 has the full
## history.
static func _colour(shapes: Array, strict := true) -> PackedInt32Array:
	var n := shapes.size()
	var spread: Array = []
	var reach: Array = []
	for p in n:
		var every := {}
		var near := {}
		for orient: Array in (shapes[p] as Array):
			for c: Vector2i in orient:
				every[c] = true
				near[c] = true
				for d: Vector2i in DIRS:
					near[c + d] = true
		spread.append(every)
		reach.append(near)
	var meets: Array = []
	for p in n:
		meets.append([])
	for a in n:
		for b in range(a + 1, n):
			var met := false
			for c in (spread[b] as Dictionary):
				if (reach[a] as Dictionary).has(c):
					met = true
					break
			if met:
				(meets[a] as Array).append(b)
				(meets[b] as Array).append(a)
	var order: Array = []
	for p in n:
		order.append(p)
	order.sort_custom(func(x, y): return (meets[x] as Array).size() > (meets[y] as Array).size())
	var cloth := PackedInt32Array()
	cloth.resize(n)
	cloth.fill(-1)
	for p: int in order:
		var taken := {}
		for q: int in (meets[p] as Array):
			if cloth[q] >= 0:
				taken[cloth[q]] = true
		var pick := -1
		for i in CLOTHS:
			if not taken.has(i):
				pick = i
				break
		if pick < 0:
			if strict:
				return PackedInt32Array()
			pick = p % CLOTHS
		cloth[p] = pick
	return cloth
