extends RefCounted

## Light Up (Akari). Place bulbs in the white cells. A bulb lights its whole
## row and column until a wall blocks it. No bulb may light another bulb.
## A numbered wall touches exactly that many bulbs orthogonally. Every white
## cell must end up lit.
##
## Cells: WALL is -2, white is -1, a numbered wall is 0..4, and a cat
## (Insane's Cat Naps) is CAT + n for n = 0..2: an open stone light crosses,
## that takes no lamp, needs no light, and wants exactly n lamps shining on
## it. Negative, so every `>= 0` test for a numbered block stays true.

const WALL := -2
const WHITE := -1
const CAT := -10
const CAT_TOP := CAT + 2

## A value light walks over: an open stone or a cat's.
static func passes(v: int) -> bool:
	return v == WHITE or (v >= CAT and v <= CAT_TOP)

static func is_cat(v: int) -> bool:
	return v >= CAT and v <= CAT_TOP

static func has_cats(grid: Array) -> bool:
	for row in grid:
		for v in row:
			if int(v) >= CAT and int(v) <= CAT_TOP:
				return true
	return false

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

## Distinct answers up to `limit`. A court with cats goes to the cat-aware
## solver (`solve_cats`), which may give up on its node budget and say -1;
## a court without them keeps the old search, which is what Easy to Hard
## generate with on the phone.
static func solve_count(grid: Array, w: int, h: int, limit: int) -> int:
	if has_cats(grid):
		return int(solve_cats(grid, w, h, limit).count)
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
			while p.x >= 0 and p.y >= 0 and p.x < w and p.y < h and (grid[p.y][p.x] == WHITE or grid[p.y][p.x] <= CAT_TOP):
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
			while p.x >= 0 and p.y >= 0 and p.x < w and p.y < h and (grid[p.y][p.x] == WHITE or grid[p.y][p.x] <= CAT_TOP):
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
			while p.x >= 0 and p.y >= 0 and p.x < w and p.y < h and (grid[p.y][p.x] == WHITE or grid[p.y][p.x] <= CAT_TOP):
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

# --- Cat Naps (Insane) ---

## How many lamps shine on `cell`: one down its row and one down its column
## at most, since no lamp may see another. What a cat's number counts.
static func seen_by(grid: Array, bulbs: Array, cell: Vector2i, w: int, h: int) -> int:
	var set: Dictionary = {}
	for b in bulbs:
		set[b] = true
	return _seen_in(grid, set, cell, w, h)

static func _seen_in(grid: Array, set: Dictionary, cell: Vector2i, w: int, h: int) -> int:
	var n := 0
	for d in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
		var p: Vector2i = cell + d
		while p.x >= 0 and p.y >= 0 and p.x < w and p.y < h and (grid[p.y][p.x] == WHITE or grid[p.y][p.x] <= CAT_TOP):
			if set.has(p):
				n += 1
			p += d
	return n

## Every cat has exactly as many lamps shining on her as her number, and no
## lamp stands on a cat.
static func cats_exact(grid: Array, bulbs: Array, w: int, h: int) -> bool:
	var set: Dictionary = {}
	for b in bulbs:
		set[b] = true
	for y in h:
		for x in w:
			var v: int = grid[y][x]
			if v >= CAT and v <= CAT_TOP:
				if set.has(Vector2i(x, y)):
					return false
				if _seen_in(grid, set, Vector2i(x, y), w, h) != v - CAT:
					return false
	return true

## The whole rule set with cats: numbers exact, no lamp sees another, every
## open stone but a cat's lit, every cat's count exact, lamps only on open
## stones.
static func is_valid(grid: Array, bulbs: Array, w: int, h: int) -> bool:
	for b in bulbs:
		if b.x < 0 or b.y < 0 or b.x >= w or b.y >= h or grid[b.y][b.x] != WHITE:
			return false
	if bulbs_see_each_other(grid, bulbs, w, h):
		return false
	if not _clues_exact(grid, bulbs, w, h):
		return false
	if not _all_lit(grid, bulbs, w, h):
		return false
	return cats_exact(grid, bulbs, w, h)

## The cat-aware count: {"count": answers up to `limit`, or -1 when `budget`
## nodes ran out, "nodes": nodes spent}. `relax` reads the cats with their
## numbers ignored -- a cat's stone still takes no lamp and needs no light --
## which is what a Cat Naps board must stay ambiguous under.
static func solve_cats(grid: Array, w: int, h: int, limit: int, relax := false,
		budget := 400000) -> Dictionary:
	var s := CatSolver.new()
	var n := s.build(grid, w, h, relax)
	if n < 0:
		return {"count": 0, "nodes": 0}
	s.budget = budget
	var found := s.search(0, limit)
	return {"count": -1 if s.over else found, "nodes": s.nodes}

## The solver over indices: candidates are the open stones (never a cat's),
## each carrying the candidates in its sight, the numbered blocks beside it
## and the cats that see it. Lamp first, the stones by a number or a cat
## first, then those fewest stones can see.
class CatSolver extends RefCounted:
	var n := 0
	var sight: Array = []          # id -> PackedInt32Array, other candidates in line
	var blocks_of: Array = []      # id -> PackedInt32Array of block ids
	var blk_need := PackedInt32Array()
	var blk_nb: Array = []         # block id -> PackedInt32Array of candidates
	var cats_of: Array = []        # id -> PackedInt32Array of cat ids
	var cat_need := PackedInt32Array()
	var cat_row: Array = []        # cat id -> PackedInt32Array
	var cat_col: Array = []
	var order := PackedInt32Array()
	var st := PackedInt32Array()   # -1 undecided, 0 dark, 1 lamp
	var relax := false
	var nodes := 0
	var budget := 0
	var over := false

	## -1 when the court cannot be solved at all (a need nothing can meet).
	func build(grid: Array, w: int, h: int, relax_cats: bool) -> int:
		relax = relax_cats
		var id := PackedInt32Array()
		id.resize(w * h)
		id.fill(-1)
		var cells: Array = []
		for y in h:
			for x in w:
				if grid[y][x] == -1:
					id[y * w + x] = cells.size()
					cells.append(Vector2i(x, y))
		n = cells.size()
		var dirs := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
		# The candidates along one open line through `c`, in direction d and back.
		var line := func(c: Vector2i, axis: Array) -> PackedInt32Array:
			var out := PackedInt32Array()
			for d in axis:
				var p: Vector2i = c + d
				while p.x >= 0 and p.y >= 0 and p.x < w and p.y < h and (grid[p.y][p.x] == -1 or grid[p.y][p.x] <= -8):  # WHITE or a cat
					if id[p.y * w + p.x] >= 0:
						out.append(id[p.y * w + p.x])
					p += d
			return out
		var horiz := [Vector2i(-1, 0), Vector2i(1, 0)]
		var vert := [Vector2i(0, -1), Vector2i(0, 1)]
		for k in n:
			var sg: PackedInt32Array = line.call(cells[k], horiz)
			sg.append_array(line.call(cells[k], vert))
			sight.append(sg)
			blocks_of.append(PackedInt32Array())
			cats_of.append(PackedInt32Array())
		for y in h:
			for x in w:
				var v: int = grid[y][x]
				var c := Vector2i(x, y)
				if v >= 0:
					var nb := PackedInt32Array()
					for d in dirs:
						var p: Vector2i = c + d
						if p.x >= 0 and p.y >= 0 and p.x < w and p.y < h and id[p.y * w + p.x] >= 0:
							nb.append(id[p.y * w + p.x])
					if nb.size() < v:
						return -1
					var b := blk_nb.size()
					blk_nb.append(nb)
					blk_need.append(v)
					for k in nb:
						blocks_of[k].append(b)
				elif v >= -10 and v <= -8 and not relax:
					var row: PackedInt32Array = line.call(c, horiz)
					var col: PackedInt32Array = line.call(c, vert)
					var need := v + 10
					if int(not row.is_empty()) + int(not col.is_empty()) < need:
						return -1
					var ci := cat_row.size()
					cat_row.append(row)
					cat_col.append(col)
					cat_need.append(need)
					for k in row:
						cats_of[k].append(ci)
					for k in col:
						cats_of[k].append(ci)
		var key := PackedInt32Array()
		key.resize(n)
		for k in n:
			key[k] = sight[k].size() - 100 * blocks_of[k].size() - 50 * cats_of[k].size()
		var ids: Array = range(n)
		ids.sort_custom(func(a, b): return key[a] < key[b] or (key[a] == key[b] and a < b))
		order = PackedInt32Array(ids)
		st.resize(n)
		st.fill(-1)
		return n

	func search(idx: int, limit: int) -> int:
		nodes += 1
		if budget > 0 and nodes > budget:
			over = true
			return 0
		if idx == n:
			return 1
		var k: int = order[idx]
		var found := 0
		for v in [1, 0]:
			st[k] = v
			if _ok(k, v):
				found += search(idx + 1, limit - found)
			st[k] = -1
			if over or found >= limit:
				return found
		return found

	func _ok(k: int, v: int) -> bool:
		if v == 1:
			for j in sight[k]:
				if st[j] == 1:
					return false
		for b in blocks_of[k]:
			var have := 0
			var maybe := 0
			for j in blk_nb[b]:
				var s: int = st[j]
				if s == 1:
					have += 1
				elif s < 0:
					maybe += 1
			var need: int = blk_need[b]
			if have > need or have + maybe < need:
				return false
		for c in cats_of[k]:
			var have := 0
			var can := 0
			for seg in [cat_row[c], cat_col[c]]:
				var lamp := false
				var open := false
				for j in seg:
					var s: int = st[j]
					if s == 1:
						lamp = true
					elif s < 0:
						open = true
				if lamp:
					have += 1
					can += 1
				elif open:
					can += 1
			var need: int = cat_need[c]
			if have > need or can < need:
				return false
		if v == 0:
			if not _lightable(k):
				return false
			for j in sight[k]:
				if st[j] == 0 and not _lightable(j):
					return false
		return true

	func _lightable(k: int) -> bool:
		if st[k] != 0:
			return true
		for j in sight[k]:
			if st[j] != 0:
				return true
		return false

## A whole Insane board: walls, one or two napping cats whose lines no lamp
## may stand in, a lamp set lighting every other stone, then three to five
## more cats on unlit-by-rule stones with the count the lamps give them (at
## least one greedy two). Every wall numbered, proved unique, then every
## number that can go taken off, and kept only if with the cats' numbers
## ignored the court has more than one answer. {} on a miss.
static func generate_cats(rng: RandomNumberGenerator, w: int, h: int, wall_pct := 0.18,
		cats_min := 4, cats_max := 6, budget := 200000) -> Dictionary:
	for _attempt in 60:
		var grid := _random_walls(rng, w, h, wall_pct)
		var whites: Array = []
		for y in h:
			for x in w:
				if grid[y][x] == WHITE:
					whites.append(Vector2i(x, y))
		if whites.size() < w * h / 2:
			continue
		_shuffle(whites, rng)
		# The napping cats and the lines they keep dark.
		var naps := rng.randi_range(1, 2)
		var banned: Dictionary = {}
		var nap_cells: Array = []
		for c in whites:
			if nap_cells.size() == naps:
				break
			if banned.has(c):
				continue
			nap_cells.append(c)
			grid[c.y][c.x] = CAT
			banned[c] = true
			for d in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
				var p: Vector2i = c + d
				while p.x >= 0 and p.y >= 0 and p.x < w and p.y < h and grid[p.y][p.x] != WALL and grid[p.y][p.x] < 0:
					banned[p] = true
					p += d
		# A maximal lamp set off the banned lines.
		var bulbs: Array = []
		var set: Dictionary = {}
		var lit: Dictionary = {}
		for c in whites:
			if banned.has(c) or lit.has(c) or grid[c.y][c.x] != WHITE:
				continue
			bulbs.append(c)
			set[c] = true
			lit[c] = true
			for d in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
				var p: Vector2i = c + d
				while p.x >= 0 and p.y >= 0 and p.x < w and p.y < h and (grid[p.y][p.x] == WHITE or grid[p.y][p.x] <= CAT_TOP):
					lit[p] = true
					p += d
		if bulbs.is_empty() or not _all_lit(grid, bulbs, w, h):
			continue
		if bulbs_see_each_other(grid, bulbs, w, h):
			continue
		# The other cats sit where the lamps already shine, with that count.
		var greedy: Array = []
		var basking: Array = []
		for c in whites:
			if grid[c.y][c.x] != WHITE or set.has(c):
				continue
			var n := _seen_in(grid, set, c, w, h)
			if n == 2:
				greedy.append(c)
			elif n == 1:
				basking.append(c)
		if greedy.is_empty():
			continue
		var more := rng.randi_range(cats_min, cats_max) - naps
		var picks: Array = [greedy[0]]
		var pool: Array = greedy.slice(1) + basking
		_shuffle(pool, rng)
		for c in pool:
			if picks.size() >= more:
				break
			picks.append(c)
		if picks.size() < cats_min - naps:
			continue
		for c in picks:
			grid[c.y][c.x] = CAT + _seen_in(grid, set, c, w, h)
		if not is_valid(grid, bulbs, w, h):
			continue
		# Number every wall, then strip what can go.
		var clued := _copy(grid)
		var spots: Array = []
		for y in h:
			for x in w:
				if grid[y][x] == WALL:
					clued[y][x] = _adjacent_bulbs(Vector2i(x, y), bulbs, w, h)
					spots.append(Vector2i(x, y))
		if int(solve_cats(clued, w, h, 2, false, budget).count) != 1:
			continue
		_shuffle(spots, rng)
		for s in spots:
			var kept: int = clued[s.y][s.x]
			clued[s.y][s.x] = WALL
			if int(solve_cats(clued, w, h, 2, false, budget).count) != 1:
				clued[s.y][s.x] = kept
		if int(solve_cats(clued, w, h, 2, true, budget).count) < 2:
			continue
		return {"grid": clued, "bulbs": bulbs, "w": w, "h": h, "ok": true}
	return {}

## A court as a bank entry, and back: one string a row, "." an open stone,
## "#" a bare wall, "0".."4" a numbered one, "a".."c" a cat wanting 0..2;
## the answer's lamps as [x, y] pairs (JSON numbers arrive as floats).
const _BANK_CATS := "abc"

static func to_bank(out: Dictionary) -> Dictionary:
	var rows: Array = []
	for y in int(out.h):
		var line := ""
		for x in int(out.w):
			var v: int = out.grid[y][x]
			if v == WHITE:
				line += "."
			elif v == WALL:
				line += "#"
			elif v >= 0:
				line += str(v)
			else:
				line += _BANK_CATS[v - CAT]
		rows.append(line)
	var lamps: Array = []
	for b in out.bulbs:
		lamps.append([b.x, b.y])
	return {"w": out.w, "h": out.h, "rows": rows, "lamps": lamps}

static func from_bank(b: Dictionary) -> Dictionary:
	if not (b.get("rows") is Array and b.get("lamps") is Array):
		return {}
	var w := int(b.get("w", 0))
	var h := int(b.get("h", 0))
	var rows: Array = b.rows
	if w <= 0 or h <= 0 or rows.size() != h:
		return {}
	var grid: Array = []
	for y in h:
		var line := String(rows[y])
		if line.length() != w:
			return {}
		var row: Array = []
		for x in w:
			var ch := line[x]
			if ch == ".":
				row.append(WHITE)
			elif ch == "#":
				row.append(WALL)
			elif ch >= "0" and ch <= "4":
				row.append(int(ch))
			elif _BANK_CATS.contains(ch):
				row.append(CAT + _BANK_CATS.find(ch))
			else:
				return {}
		grid.append(row)
	var bulbs: Array = []
	for c in b.lamps:
		bulbs.append(Vector2i(int(c[0]), int(c[1])))
	return {"grid": grid, "bulbs": bulbs, "w": w, "h": h, "ok": true}
