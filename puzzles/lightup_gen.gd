extends RefCounted

## Light Up (Akari). Place bulbs in the white cells. A bulb lights its whole
## row and column until a wall blocks it. No bulb may light another bulb.
## A numbered wall touches exactly that many bulbs orthogonally. Every white
## cell must end up lit.
##
## Cells: WALL is -2, white is -1, a numbered wall is 0..4.

const WALL := -2
const WHITE := -1

static func generate(rng: RandomNumberGenerator, w: int, h: int, wall_pct: float) -> Dictionary:
	for _attempt in 120:
		var grid := _random_walls(rng, w, h, wall_pct)
		var bulbs := _place_bulbs(rng, grid, w, h)
		if bulbs.is_empty():
			continue
		if not _all_lit(grid, bulbs, w, h):
			continue

		# Number every wall, then strip numbers while the answer stays unique.
		var clued := _copy(grid)
		for y in h:
			for x in w:
				if grid[y][x] == WALL:
					clued[y][x] = _adjacent_bulbs(Vector2i(x, y), bulbs, w, h)
		if solve_count(clued, w, h, 2) != 1:
			continue

		var spots: Array = []
		for y in h:
			for x in w:
				if clued[y][x] >= 0:
					spots.append(Vector2i(x, y))
		_shuffle(spots, rng)
		for s in spots:
			var kept: int = clued[s.y][s.x]
			clued[s.y][s.x] = WALL
			if solve_count(clued, w, h, 2) != 1:
				clued[s.y][s.x] = kept
		return {"grid": clued, "bulbs": bulbs, "w": w, "h": h, "ok": true}
	return {"grid": [], "bulbs": [], "w": w, "h": h, "ok": false}

static func solve_count(grid: Array, w: int, h: int, limit: int) -> int:
	var whites: Array = []
	for y in h:
		for x in w:
			if grid[y][x] == WHITE:
				whites.append(Vector2i(x, y))
	# Stones beside a number first, then the ones fewest stones can see:
	# both fail soonest, and the order cannot change the count.
	var key: Dictionary = {}
	for c in whites:
		var sight := 0
		for d in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
			var p: Vector2i = c + d
			if p.x >= 0 and p.y >= 0 and p.x < w and p.y < h and grid[p.y][p.x] >= 0:
				sight -= 100
			while p.x >= 0 and p.y >= 0 and p.x < w and p.y < h and grid[p.y][p.x] == WHITE:
				sight += 1
				p += d
		key[c] = sight
	whites.sort_custom(func(a, b): return key[a] < key[b] or (key[a] == key[b] and (a.y < b.y or (a.y == b.y and a.x < b.x))))
	var state: Dictionary = {}
	return _search(grid, whites, 0, state, w, h, limit)

static func _search(grid: Array, whites: Array, idx: int, state: Dictionary,
		w: int, h: int, limit: int) -> int:
	if idx == whites.size():
		var bulbs: Array = []
		for k in state:
			if state[k]:
				bulbs.append(k)
		if not _clues_exact(grid, bulbs, w, h):
			return 0
		return 1 if _all_lit(grid, bulbs, w, h) else 0

	var cell: Vector2i = whites[idx]
	var found := 0
	for put in [true, false]:
		state[cell] = put
		if _consistent(grid, state, cell, put, w, h):
			found += _search(grid, whites, idx + 1, state, w, h, limit - found)
		state.erase(cell)
		if found >= limit:
			return found
	return found

## Cheap incremental pruning: no two bulbs may see each other, and no wall
## clue may be exceeded or become unreachable.
static func _consistent(grid: Array, state: Dictionary, cell: Vector2i, put: bool,
		w: int, h: int) -> bool:
	if put:
		for d in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
			var p: Vector2i = cell + d
			while p.x >= 0 and p.y >= 0 and p.x < w and p.y < h and grid[p.y][p.x] == WHITE:
				if state.get(p, false):
					return false  # two bulbs in line of sight
				p += d
	for d in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
		var wall: Vector2i = cell + d
		if wall.x < 0 or wall.y < 0 or wall.x >= w or wall.y >= h:
			continue
		var need: int = grid[wall.y][wall.x]
		if need < 0:
			continue
		var have := 0
		var maybe := 0
		for e in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
			var n: Vector2i = wall + e
			if n.x < 0 or n.y < 0 or n.x >= w or n.y >= h or grid[n.y][n.x] != WHITE:
				continue
			if state.has(n):
				if state[n]:
					have += 1
			else:
				maybe += 1
		if have > need or have + maybe < need:
			return false
	# Leaving a stone dark can strand it, or a stone that sees it, with
	# nothing left that could light it; only those can die here.
	if not put:
		if not _lightable(grid, state, cell, w, h):
			return false
		for d in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
			var p: Vector2i = cell + d
			while p.x >= 0 and p.y >= 0 and p.x < w and p.y < h and grid[p.y][p.x] == WHITE:
				if not _lightable(grid, state, p, w, h):
					return false
				p += d
	return true

## Whether a lamp stands on or in sight of `c`, or a stone there is undecided.
static func _lightable(grid: Array, state: Dictionary, c: Vector2i, w: int, h: int) -> bool:
	if state.get(c, true):
		return true
	for d in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
		var p: Vector2i = c + d
		while p.x >= 0 and p.y >= 0 and p.x < w and p.y < h and grid[p.y][p.x] == WHITE:
			if state.get(p, true):
				return true
			p += d
	return false

static func _clues_exact(grid: Array, bulbs: Array, w: int, h: int) -> bool:
	for y in h:
		for x in w:
			if grid[y][x] >= 0:
				if _adjacent_bulbs(Vector2i(x, y), bulbs, w, h) != grid[y][x]:
					return false
	return true

static func _all_lit(grid: Array, bulbs: Array, w: int, h: int) -> bool:
	var lit: Dictionary = {}
	for b in bulbs:
		lit[b] = true
		for d in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
			var p: Vector2i = b + d
			while p.x >= 0 and p.y >= 0 and p.x < w and p.y < h and grid[p.y][p.x] == WHITE:
				lit[p] = true
				p += d
	for y in h:
		for x in w:
			if grid[y][x] == WHITE and not lit.has(Vector2i(x, y)):
				return false
	return true

static func lit_cells(grid: Array, bulbs: Array, w: int, h: int) -> Dictionary:
	var lit: Dictionary = {}
	for b in bulbs:
		lit[b] = true
		for d in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
			var p: Vector2i = b + d
			while p.x >= 0 and p.y >= 0 and p.x < w and p.y < h and grid[p.y][p.x] == WHITE:
				lit[p] = true
				p += d
	return lit

static func bulbs_see_each_other(grid: Array, bulbs: Array, w: int, h: int) -> bool:
	var set: Dictionary = {}
	for b in bulbs:
		set[b] = true
	for b in bulbs:
		for d in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
			var p: Vector2i = b + d
			while p.x >= 0 and p.y >= 0 and p.x < w and p.y < h and grid[p.y][p.x] == WHITE:
				if set.has(p):
					return true
				p += d
	return false

static func _adjacent_bulbs(wall: Vector2i, bulbs: Array, w: int, h: int) -> int:
	var n := 0
	for b in bulbs:
		if absi(b.x - wall.x) + absi(b.y - wall.y) == 1:
			n += 1
	return n

static func _random_walls(rng: RandomNumberGenerator, w: int, h: int, pct: float) -> Array:
	var grid: Array = []
	for y in h:
		var row: Array = []
		for x in w:
			row.append(WALL if rng.randf() < pct else WHITE)
		grid.append(row)
	return grid

static func _place_bulbs(rng: RandomNumberGenerator, grid: Array, w: int, h: int) -> Array:
	var cells: Array = []
	for y in h:
		for x in w:
			if grid[y][x] == WHITE:
				cells.append(Vector2i(x, y))
	if cells.is_empty():
		return []
	_shuffle(cells, rng)
	var bulbs: Array = []
	for c in cells:
		if bulbs_see_each_other(grid, bulbs + [c], w, h):
			continue
		var lit := lit_cells(grid, bulbs, w, h)
		if lit.has(c):
			continue  # already lit, a bulb here would be redundant
		bulbs.append(c)
	return bulbs

static func _copy(grid: Array) -> Array:
	var out: Array = []
	for row in grid:
		out.append((row as Array).duplicate())
	return out

static func _shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp = arr[i]; arr[i] = arr[j]; arr[j] = tmp
