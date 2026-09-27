extends RefCounted

## Super Slider's solver and its deal: a four-by-five tray, one big 2x2 block
## and a set of bars and squares, and the big block has to reach the gate in
## the middle of the bottom edge. Sliding blocks of this shape are the old
## 4x5 family (the Chinese Huarong Dao, the English Pennant, the French
## L'Âne rouge); the reference is a handheld that deals five hundred of them.
##
## **A position is one int.** Twenty cells of three bits, each saying what
## part of what shape sits there (`E` .. `B2` below), so two bars of the same
## shape are the same position whichever is which -- exactly how the player
## sees it -- and a Dictionary keyed on the int is the visited set.
##
## **A move is one block moved any distance, round corners too**, because
## that is what one drag does on the board. So the neighbours of a position
## are, for every block, every other place a flood through the empty cells
## can carry it, with every other block standing still. That is the
## traditional metric (the classic layout's 81 is counted in it).
##
## **The deal is mined, not grown on the phone**: tools/mine_slider.gd walks
## random layouts, takes each one's whole connected graph of positions,
## measures every position's distance to the gate and keeps positions at the
## bands' distances in content/slider.json. The phone only reads that file
## and, for a hint, runs `distances()` once on a worker thread.

const COLS := 4
const ROWS := 5
const N := COLS * ROWS

## A cell's code: empty, a square, a bar standing (top, bottom), a bar lying
## (left, right), the big block (its top-left, any other of its cells).
const E := 0
const SQ := 1
const V0 := 2
const V1 := 3
const H0 := 4
const H1 := 5
const B0 := 6
const B1 := 7

## A shape by its anchor code (its top-left cell's), and its size in cells.
const SIZE := {SQ: Vector2i(1, 1), V0: Vector2i(1, 2), H0: Vector2i(2, 1), B0: Vector2i(2, 2)}
const ANCHORS := [SQ, V0, H0, B0]
const DX := [1, -1, 0, 0]
const DY := [0, 0, 1, -1]

## Where the big block's top-left stands when it is out: the bottom two rows,
## the middle two columns.
const GOAL := 3 * COLS + 1

## The bands' distances to the gate, in moves: [least, most].
const BANDS := [Vector2i(8, 16), Vector2i(20, 34), Vector2i(38, 56), Vector2i(60, 200)]

const BANK := "res://content/slider.json"

## Each shape's contribution to a key at each anchor, or -1 where it does not
## fit the tray. Built once.
static var _contrib := {}

static func _table() -> Dictionary:
	if not _contrib.is_empty():
		return _contrib
	for a: int in ANCHORS:
		var sz: Vector2i = SIZE[a]
		var row := PackedInt64Array()
		row.resize(N)
		for i in N:
			var x := i % COLS
			var y := i / COLS
			if x + sz.x > COLS or y + sz.y > ROWS:
				row[i] = -1
				continue
			var k := 0
			for c in cells(a, i):
				k |= _part(a, c - i) << (3 * c)
			row[i] = k
		_contrib[a] = row
	return _contrib

## The code a shape with anchor code `a` writes `off` cells past its anchor.
static func _part(a: int, off: int) -> int:
	match a:
		SQ: return SQ
		V0: return V0 if off == 0 else V1
		H0: return H0 if off == 0 else H1
	return B0 if off == 0 else B1

## The cells a shape with anchor code `a` covers standing at `i`.
static func cells(a: int, i: int) -> PackedInt32Array:
	var sz: Vector2i = SIZE[a]
	var out := PackedInt32Array()
	for dy in sz.y:
		for dx in sz.x:
			out.append(i + dy * COLS + dx)
	return out

static func grid(key: int) -> PackedByteArray:
	var g := PackedByteArray()
	g.resize(N)
	for i in N:
		g[i] = (key >> (3 * i)) & 7
	return g

static func key_of(g: PackedByteArray) -> int:
	var k := 0
	for i in N:
		k |= int(g[i]) << (3 * i)
	return k

## Every block in a position: [[anchor code, anchor cell], ...] in cell order.
static func blocks(key: int) -> Array:
	var out: Array = []
	for i in N:
		var c := (key >> (3 * i)) & 7
		if c == SQ or c == V0 or c == H0 or c == B0:
			out.append([c, i])
	return out

static func contrib(a: int, i: int) -> int:
	return _table()[a][i]

static func is_goal(key: int) -> bool:
	return ((key >> (3 * GOAL)) & 7) == B0

## The anchors a shape `a` standing at `from` can reach through the empty
## cells of `g` (which must not hold the shape itself), `from` included.
static func reach(g: PackedByteArray, a: int, from: int) -> PackedInt32Array:
	var sz: Vector2i = SIZE[a]
	var seen := {from: true}
	var out := PackedInt32Array([from])
	var i := 0
	while i < out.size():
		var at: int = out[i]
		i += 1
		var x := at % COLS
		var y := at / COLS
		for d in 4:
			var nx: int = x + DX[d]
			var ny: int = y + DY[d]
			if nx < 0 or ny < 0 or nx + sz.x > COLS or ny + sz.y > ROWS:
				continue
			var to := ny * COLS + nx
			if seen.has(to):
				continue
			var free := true
			for dy in sz.y:
				for dx in sz.x:
					if g[to + dy * COLS + dx] != E:
						free = false
			if free:
				seen[to] = true
				out.append(to)
	return out

## Every position one move from `key`: [[next key, anchor code, from, to], ...].
static func moves(key: int) -> Array:
	var g := grid(key)
	var out: Array = []
	for b: Array in blocks(key):
		var a: int = b[0]
		var from: int = b[1]
		var own: int = contrib(a, from)
		var cs := cells(a, from)
		for c in cs:
			g[c] = E
		var base := key - own
		for to in reach(g, a, from):
			if to != from:
				out.append([base + contrib(a, to), a, from, to])
		for c in cs:
			g[c] = (own >> (3 * c)) & 7
	return out

## The whole graph a position belongs to and every position's distance to
## the gate: {"keys": PackedInt64Array, "index": {key: i}, "dist":
## PackedInt32Array (-1 where the gate cannot be reached)}. Moves reverse, so
## the graph is the same from any of its positions; one run serves every
## hint of a day. With a `cap`, a graph larger than that gives up and
## answers {} (the miner skips it: a phone's hint would wait too long on it);
## a `stop` box whose "stop" is set gives up too (a board closed mid-run).
static func distances(start: int, cap := 0, stop := {}) -> Dictionary:
	var keys := PackedInt64Array([start])
	var index := {start: 0}
	var adj_at := PackedInt32Array()
	var adj := PackedInt32Array()
	var goals := PackedInt32Array()
	var nbr := PackedInt64Array()
	var queue := PackedInt32Array()
	queue.resize(N)
	_fast_tables()
	var i := 0
	while i < keys.size():
		if cap > 0 and keys.size() > cap:
			return {}
		if i & 1023 == 0 and stop.get("stop", false):
			return {}
		var k: int = keys[i]
		adj_at.append(adj.size())
		if is_goal(k):
			goals.append(i)
		nbr.clear()
		_next_keys(k, nbr, queue)
		for nk in nbr:
			var j: int = index.get(nk, -1)
			if j < 0:
				j = keys.size()
				index[nk] = j
				keys.append(nk)
			adj.append(j)
		i += 1
	adj_at.append(adj.size())
	var dist := PackedInt32Array()
	dist.resize(keys.size())
	dist.fill(-1)
	var q := PackedInt32Array()
	for gi in goals:
		dist[gi] = 0
		q.append(gi)
	var h := 0
	while h < q.size():
		var u: int = q[h]
		h += 1
		for e in range(adj_at[u], adj_at[u + 1]):
			var v: int = adj[e]
			if dist[v] < 0:
				dist[v] = dist[u] + 1
				q.append(v)
	return {"keys": keys, "index": index, "dist": dist}

## `moves` without the bookkeeping, for the breadth-first run: only the keys,
## into `out`, with occupancy as a 20-bit mask and each block's flood through
## `queue` (N long, reused), so a position allocates nothing.
static var _mask: Array = []
static var _adj: Array = []
static var _con: Array = []

static func _fast_tables() -> void:
	if not _mask.is_empty():
		return
	var mask: Array = []
	var con: Array = []
	for code in 8:
		var m := PackedInt64Array()
		var k := PackedInt64Array()
		m.resize(N)
		k.resize(N)
		if SIZE.has(code):
			for i in N:
				var ck: int = contrib(code, i)
				if ck < 0:
					continue
				k[i] = ck
				for c in cells(code, i):
					m[i] |= 1 << c
		mask.append(m)
		con.append(k)
	var adj: Array = []
	for i in N:
		var a := PackedInt32Array()
		var x := i % COLS
		var y := i / COLS
		if x + 1 < COLS: a.append(i + 1)
		if x > 0: a.append(i - 1)
		if y + 1 < ROWS: a.append(i + COLS)
		if y > 0: a.append(i - COLS)
		adj.append(a)
	_con = con
	_adj = adj
	_mask = mask

static func _next_keys(key: int, out: PackedInt64Array, queue: PackedInt32Array) -> void:
	var occ := 0
	for i in N:
		if (key >> (3 * i)) & 7 != E:
			occ |= 1 << i
	for i in N:
		var code := (key >> (3 * i)) & 7
		if code != SQ and code != V0 and code != H0 and code != B0:
			continue
		var masks: PackedInt64Array = _mask[code]
		var con: PackedInt64Array = _con[code]
		var rest := occ & ~masks[i]
		var base := key - con[i]
		var seen := 1 << i
		queue[0] = i
		var head := 0
		var tail := 1
		while head < tail:
			var at: int = queue[head]
			head += 1
			for to in _adj[at]:
				if seen & (1 << to):
					continue
				var m: int = masks[to]
				if m == 0 or m & rest:
					continue
				seen |= 1 << to
				queue[tail] = to
				tail += 1
				out.append(base + con[to])

## The position mirrored left to right: the same puzzle, so the miner keeps
## only one of the two.
static func mirror(key: int) -> int:
	var g := grid(key)
	var m := PackedByteArray()
	m.resize(N)
	for b: Array in blocks(key):
		var a: int = b[0]
		var i: int = b[1]
		var sz: Vector2i = SIZE[a]
		var x := COLS - (i % COLS) - sz.x
		var to := (i / COLS) * COLS + x
		for c in cells(a, to):
			m[c] = _part(a, c - to)
	return key_of(m)

## A position as the bank writes it: twenty digits, cell codes in reading
## order.
static func encode(key: int) -> String:
	var s := ""
	for i in N:
		s += str((key >> (3 * i)) & 7)
	return s

static func decode(s: String) -> int:
	var k := 0
	for i in mini(N, s.length()):
		k |= int(s.unicode_at(i) - 48) << (3 * i)
	return k

# --- the deal ---

static var _bank: Array = []

static func bank() -> Array:
	if _bank.is_empty() and FileAccess.file_exists(BANK):
		var doc = JSON.parse_string(FileAccess.get_file_as_string(BANK))
		if doc is Dictionary and doc.get("bands") is Array:
			_bank = doc.bands
	return _bank

## The day's tray: {"start": key, "par": moves, "band": difficulty}. From the
## bank when it has the band; otherwise the classic layout, which every band
## can fall back on rather than fail to open.
static func deal(rng: RandomNumberGenerator, difficulty: int) -> Dictionary:
	var bands := bank()
	var band := clampi(difficulty, 0, BANDS.size() - 1)
	if band < bands.size() and bands[band] is Array and not (bands[band] as Array).is_empty():
		var pool: Array = bands[band]
		var e: Dictionary = pool[rng.randi_range(0, pool.size() - 1)]
		var k := decode(String(e.b))
		# Half the days the tray is dealt mirrored; the par is the same.
		if rng.randf() < 0.5:
			k = mirror(k)
		return {"start": k, "par": int(e.p), "band": band}
	return {"start": decode(CLASSIC), "par": CLASSIC_PAR, "band": band}

## The oldest layout of all: the big block top middle, four bars standing,
## one lying across the middle, four squares and two empty cells.
const CLASSIC := "26723773245231131001"
const CLASSIC_PAR := 81
