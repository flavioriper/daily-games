extends RefCounted

## Lattice's deals. The phone reads them out of content/lattice.json, a pool
## a band mined by tools/build_lattice.py, where every deal is proved to have
## one answer and its fewest swaps (`par`) is known. `generate` is the
## fallback for a build without the file: the same shape of deal, its par
## taken as dealt and its answer not proved the only one.

## Side, knots kept, and how a deal is scrambled: pairs of tiles that traded
## cells and rings of three. A clean solve is a swap a pair and two a ring.
const BANDS := [
	{"n": 5, "knots": 4, "pairs": 4, "threes": 2},
	{"n": 7, "knots": 9, "pairs": 8, "threes": 2},
	{"n": 7, "knots": 9, "pairs": 11, "threes": 2},
	{"n": 7, "knots": 6, "pairs": 11, "threes": 2},
]
const STEP := {"L": Vector2i(-1, 0), "U": Vector2i(0, -1), "R": Vector2i(1, 0), "D": Vector2i(0, 1)}

## The lattice's cells in reading order, as (column, row): every cell of an
## `n` by `n` square but the ones on an odd row and an odd column.
static func cells_of(n: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for r in n:
		for c in n:
			if r % 2 == 0 or c % 2 == 0:
				out.append(Vector2i(c, r))
	return out

## The holes in reading order, as (column, row).
static func holes_of(n: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for r in range(1, n, 2):
		for c in range(1, n, 2):
			out.append(Vector2i(c, r))
	return out

## A line of the bank, "<answer>|<opening>|<knots>|<par>", as a deal:
## {n, sol, cur, knots: [{hole, dirs}], par}. {} when it does not read.
static func unpack(line: String) -> Dictionary:
	var parts := line.split("|")
	if parts.size() != 4 or parts[0].length() != parts[1].length():
		return {}
	var count := parts[0].length()
	var n := 5 if count == 21 else 7
	if cells_of(n).size() != count:
		return {}
	var sol := PackedByteArray()
	var cur := PackedByteArray()
	for i in count:
		sol.append(parts[0].unicode_at(i) - 48)
		cur.append(parts[1].unicode_at(i) - 48)
	var knots: Array = []
	for k: String in parts[2].split(",", false):
		var hole := k.to_int()
		knots.append({"hole": hole, "dirs": k.substr(str(hole).length())})
	return {"n": n, "sol": sol, "cur": cur, "knots": knots, "par": int(parts[3])}

## A deal laid on the spot.
static func generate(rng: RandomNumberGenerator, band: int) -> Dictionary:
	var spec: Dictionary = BANDS[clampi(band, 0, BANDS.size() - 1)]
	var n: int = spec.n
	var cells := cells_of(n)
	var index := {}
	for i in cells.size():
		index[cells[i]] = i
	while true:
		var sol := _answer(rng, n, cells, index)
		if sol.is_empty():
			continue
		var cur := _scramble(rng, sol, spec)
		if cur.is_empty():
			continue
		var holes := holes_of(n)
		var order: Array = range(holes.size())
		_shuffle(rng, order)
		order = order.slice(0, int(spec.knots))
		order.sort()
		var knots: Array = []
		for h: int in order:
			# Two of the four ways: a corner or straight across.
			var ways: Array = ["L", "U", "R", "D"]
			ways.remove_at(rng.randi_range(0, 3))
			ways.remove_at(rng.randi_range(0, 2))
			knots.append({"hole": h, "dirs": "".join(ways)})
		return {"n": n, "sol": sol, "cur": cur, "knots": knots,
			"par": int(spec.pairs) + 2 * int(spec.threes)}
	return {}

## The crossings first, each new to its row and its column, then every
## line's own cells from what the line still lacks.
static func _answer(rng: RandomNumberGenerator, n: int, cells: Array[Vector2i], index: Dictionary) -> PackedByteArray:
	var sol := PackedByteArray()
	sol.resize(cells.size())
	for r in range(0, n, 2):
		for c in range(0, n, 2):
			var free: Array = []
			for d in range(1, n + 1):
				var ok := true
				for k in range(0, n, 2):
					if (k < c and sol[index[Vector2i(k, r)]] == d) or (k < r and sol[index[Vector2i(c, k)]] == d):
						ok = false
				if ok:
					free.append(d)
			if free.is_empty():
				return PackedByteArray()
			sol[index[Vector2i(c, r)]] = free[rng.randi_range(0, free.size() - 1)]
	for across in [true, false]:
		for a in range(0, n, 2):
			var rest: Array = range(1, n + 1)
			var open: Array = []
			for b in n:
				var i: int = index[Vector2i(b, a) if across else Vector2i(a, b)]
				if b % 2 == 0:
					rest.erase(int(sol[i]))
				else:
					open.append(i)
			_shuffle(rng, rest)
			for k in open.size():
				sol[open[k]] = rest[k]
	return sol

static func _scramble(rng: RandomNumberGenerator, sol: PackedByteArray, spec: Dictionary) -> PackedByteArray:
	var order: Array = range(sol.size())
	_shuffle(rng, order)
	var cur := sol.duplicate()
	var at := 0
	for group in [[3, int(spec.threes)], [2, int(spec.pairs)]]:
		for _k in int(group[1]):
			var size: int = group[0]
			for i in size:
				var here: int = order[at + i]
				cur[here] = sol[order[at + (i + 1) % size]]
				if cur[here] == sol[here]:
					return PackedByteArray()
			at += size
	return cur

static func _shuffle(rng: RandomNumberGenerator, list: Array) -> void:
	for i in range(list.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = list[i]
		list[i] = list[j]
		list[j] = t
