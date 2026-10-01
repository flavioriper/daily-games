extends RefCounted

## Caterpillar's generator: grow the answer, then prove it.
##
## The answer is a Hamiltonian path over the whole field -- the caterpillar's
## body when it is done -- and it is grown before anything else exists, so a
## solution is guaranteed before the first leaf is placed. It starts as a
## boustrophedon and is stirred with **backbite** moves: the head steps onto
## a neighbour already in the body, the body is cut there and the loose end
## becomes the head. Every backbite keeps a Hamiltonian path, and a few
## hundred of them are enough to lose the zigzag.
##
## Then leaves go on the path (1 on its first cell, the last number on its
## last cell, the rest spread along it) and hedges go on edges it never
## crosses, and a solver counts the walks that visit every cell with the
## leaves in order. While it finds a second walk, the first place the two
## disagree is pinned down, with a leaf or a hedge. Then leaves are taken
## away again, one at a time, toward the band's target, each only if the
## board stays unique.
##
## **Every proof is capped by a node count, never by a clock** (`NODE_CAP`).
## A capped proof counts as "not proved", so the leaf it was testing stays.
## That trades a slightly denser board for a bound on the worst seed, and
## unlike Sudoku's 300 ms budget it cannot differ between phones: a day is
## the same field on every device. Spec:
## docs/superpowers/specs/2026-09-25-caterpillar-flat-design.md, section 5.

## cols, rows, the leaf-count range and the hedge-count range. Insane's row is
## provisional, as every board's is (docs/superpowers/specs/
## 2026-09-23-insane-level-design.md).
const BANDS := [
	{"cols": 5, "rows": 5, "leaves": [6, 8], "hedges": [0, 0]},
	{"cols": 6, "rows": 6, "leaves": [7, 9], "hedges": [2, 4]},
	{"cols": 7, "rows": 7, "leaves": [8, 11], "hedges": [3, 6]},
	{"cols": 8, "rows": 8, "leaves": [9, 13], "hedges": [4, 8], "cap": 500},
]

const NODE_CAP := 1000   ## a band may lower it with its own "cap"
## Backbite moves per cell of field.
const STIR := 24

static func band(difficulty: int) -> Dictionary:
	return BANDS[clampi(difficulty, 0, BANDS.size() - 1)]

## {cols, rows, path: PackedInt32Array (the answer, cell = y * cols + x),
##  leaves: PackedInt32Array (the cell of leaf 1, leaf 2, ...),
##  hedges: PackedInt32Array (edge keys, see edge_key), unique: bool}
static func generate(rng: RandomNumberGenerator, difficulty: int) -> Dictionary:
	var b := band(difficulty)
	var w := int(b.cols)
	var h := int(b.rows)
	var n := w * h
	var p := _stir(rng, w, h)
	var on_path := {}
	for i in n - 1:
		on_path[edge_key(p[i], p[i + 1])] = true
	var target := rng.randi_range(int(b.leaves[0]), int(b.leaves[1]))
	var hedge_target := rng.randi_range(int(b.hedges[0]), int(b.hedges[1]))
	var hedge_max := int(b.hedges[1])
	var cap := int(b.get("cap", NODE_CAP))

	var idx := {0: true, n - 1: true}
	var k0 := maxi(2, target - 3)
	var gap := float(n - 1) / float(k0 - 1)
	for q in range(1, k0 - 1):
		var at := roundi(q * gap + (rng.randf() - 0.5) * gap * 0.6)
		idx[clampi(at, 1, n - 2)] = true

	var hedges := {}
	var tries := 0
	while hedges.size() < hedge_target and tries < 200:
		tries += 1
		var c := rng.randi_range(0, n - 1)
		var ns := _nbrs(w, h, c)
		var m: int = ns[rng.randi_range(0, ns.size() - 1)]
		if not on_path.has(edge_key(c, m)):
			hedges[edge_key(c, m)] = true

	var unique := false
	for g in n:
		var s := count(w, h, _leaves_of(p, idx), hedges.keys(), 2, cap)
		if s.count == 1 and not s.capped:
			unique = true
			break
		if s.capped or s.walks.size() < 2:
			# Not proved within the cap: split the longest run between leaves.
			var sorted := idx.keys()
			sorted.sort()
			var best_at := 0
			var best_gap := 0
			for q in sorted.size() - 1:
				if sorted[q + 1] - sorted[q] > best_gap:
					best_gap = sorted[q + 1] - sorted[q]
					best_at = sorted[q]
			idx[best_at + (best_gap >> 1)] = true
			continue
		var alt: PackedInt32Array = s.walks[0] if s.walks[0] != p else s.walks[1]
		var i := 0
		while alt[i] == p[i]:
			i += 1
		var e := edge_key(alt[i - 1], alt[i])
		if hedges.size() < hedge_max and not on_path.has(e) and rng.randf() < 0.5:
			hedges[e] = true
		else:
			var q := i
			while q < n - 1 and (idx.has(q) or alt[q] == p[q]):
				q += 1
			if q < n - 1:
				idx[q] = true
			elif not on_path.has(e):
				hedges[e] = true
			else:
				break

	if unique and idx.size() > target:
		var inner: Array = idx.keys().filter(func(v): return v != 0 and v != n - 1)
		for j in range(inner.size() - 1, 0, -1):
			var q := rng.randi_range(0, j)
			var t = inner[j]
			inner[j] = inner[q]
			inner[q] = t
		for v in inner:
			if idx.size() <= target:
				break
			idx.erase(v)
			if not proved(w, h, _leaves_of(p, idx), hedges.keys(), cap):
				idx[v] = true

	return {"cols": w, "rows": h, "path": p, "leaves": _leaves_of(p, idx),
		"hedges": PackedInt32Array(hedges.keys()), "unique": unique}

## Exactly one walk, found inside the node cap. A capped search is never a
## proof, however many walks it had found when it stopped.
static func proved(w: int, h: int, leaves: PackedInt32Array, hedges: Array, cap := NODE_CAP) -> bool:
	var s := count(w, h, leaves, hedges, 2, cap)
	return s.count == 1 and not s.capped

## An edge between two orthogonal neighbours, order-free.
static func edge_key(a: int, b: int) -> int:
	return mini(a, b) * 4096 + maxi(a, b)

static func _nbrs(w: int, h: int, c: int) -> Array:
	var x := c % w
	var y := c / w
	var out := []
	if x > 0: out.append(c - 1)
	if x < w - 1: out.append(c + 1)
	if y > 0: out.append(c - w)
	if y < h - 1: out.append(c + w)
	return out

static func _leaves_of(p: PackedInt32Array, idx: Dictionary) -> PackedInt32Array:
	var s := idx.keys()
	s.sort()
	var out := PackedInt32Array()
	for i in s:
		out.append(p[i])
	return out

## A boustrophedon, stirred by backbites from either end.
static func _stir(rng: RandomNumberGenerator, w: int, h: int) -> PackedInt32Array:
	var n := w * h
	var p := PackedInt32Array()
	p.resize(n)
	for y in h:
		for x in w:
			p[y * w + x] = y * w + (w - 1 - x if y % 2 == 1 else x)
	var pos := PackedInt32Array()
	pos.resize(n)
	for i in n:
		pos[p[i]] = i
	for s in n * STIR:
		if rng.randi() & 1:
			# Bite from the head: head joins neighbour at j, reverse j+1..n-1.
			var ns := _nbrs(w, h, p[n - 1])
			var j := pos[ns[rng.randi_range(0, ns.size() - 1)]]
			if j == n - 2:
				continue
			var a := j + 1
			var z := n - 1
			while a < z:
				var t := p[a]
				p[a] = p[z]
				p[z] = t
				pos[p[a]] = a
				pos[p[z]] = z
				a += 1
				z -= 1
		else:
			var ns := _nbrs(w, h, p[0])
			var j := pos[ns[rng.randi_range(0, ns.size() - 1)]]
			if j == 1:
				continue
			var a := 0
			var z := j - 1
			while a < z:
				var t := p[a]
				p[a] = p[z]
				p[z] = t
				pos[p[a]] = a
				pos[p[z]] = z
				a += 1
				z -= 1
	return p

# ------------------------------------------------------------------ the proof
#
# Up to 64 cells, so a set of cells is one int and bit c is cell c. The four
# `open_*` masks say which cells have an open edge on that side (inside the
# field and not hedged); shifting a set by 1 or `w` moves it one cell, and the
# right shifts are masked because GDScript's are arithmetic.

## The masks every search and judge reads: which cells have an open edge on
## each side, the leaves by cell, the last leaf's bit and, on Peckish, the
## middle leaves' bits (`food`) and the tummy (`hunger`).
static func context(w: int, h: int, leaves: PackedInt32Array, hedges: Array, hunger := 0) -> Dictionary:
	var n := w * h
	var ctx := {"w": w, "n": n, "hunger": hunger}
	var hs := {}
	for e in hedges:
		hs[e] = true
	var r := 0
	var l := 0
	var d := 0
	var u := 0
	for c in n:
		var x := c % w
		var y := c / w
		if x < w - 1 and not hs.has(edge_key(c, c + 1)): r |= 1 << c
		if x > 0 and not hs.has(edge_key(c, c - 1)): l |= 1 << c
		if y < h - 1 and not hs.has(edge_key(c, c + w)): d |= 1 << c
		if y > 0 and not hs.has(edge_key(c, c - w)): u |= 1 << c
	ctx.r = r
	ctx.l = l
	ctx.d = d
	ctx.u = u
	ctx.m1 = 0x7FFFFFFFFFFFFFFF
	ctx.mw = 0x7FFFFFFFFFFFFFFF >> (w - 1)
	var clue := PackedInt32Array()
	clue.resize(n)
	for k in leaves.size():
		clue[leaves[k]] = k + 1
	ctx.clue = clue
	ctx.last = leaves.size()
	ctx.end_bit = 1 << leaves[leaves.size() - 1]
	var food := 0
	for k in range(1, leaves.size() - 1):
		food |= 1 << leaves[k]
	ctx.food = food
	return ctx

## Counts walks from leaf 1 over every cell, leaves in order, ending on the
## last leaf, up to `limit`. {count, walks (the first `limit` found), capped}.
static func count(w: int, h: int, leaves: PackedInt32Array, hedges: Array, limit: int, cap: int,
		hunger := 0) -> Dictionary:
	var n := w * h
	var ctx := context(w, h, leaves, hedges, hunger)
	ctx.limit = limit
	ctx.cap = cap
	ctx.nodes = 0
	ctx.walks = []
	var full := -1 if n == 64 else (1 << n) - 1
	var path := PackedInt32Array([leaves[0]])
	_walk(ctx, leaves[0], 2, full & ~(1 << leaves[0]), path, hunger)
	return {"count": ctx.walks.size(), "walks": ctx.walks, "capped": ctx.nodes > cap}

static func _walk(ctx: Dictionary, head: int, next: int, free: int, path: PackedInt32Array, tummy := 0) -> void:
	ctx.nodes += 1
	if ctx.nodes > ctx.cap:
		return
	if free == 0:
		if (1 << head) == ctx.end_bit:
			ctx.walks.append(path.duplicate())
		return
	var w: int = ctx.w
	var hb := 1 << head
	var step := [
		[ctx.r, 1], [ctx.l, -1], [ctx.d, w], [ctx.u, -w]]
	for s in step:
		if not (int(s[0]) & hb):
			continue
		var m: int = head + int(s[1])
		var mb := 1 << m
		if not (free & mb):
			continue
		var k: int = ctx.clue[m]
		var t2 := 0
		var hunger: int = ctx.hunger
		if hunger > 0:
			# Peckish: any leaf in any order, but a bare square only on a
			# tummy that still has room.
			if k == 0:
				if tummy <= 0:
					continue
				t2 = tummy - 1
			else:
				t2 = hunger
		elif k != 0 and k != next:
			continue
		if mb == ctx.end_bit and free != mb:
			continue
		var f2 := free & ~mb
		if f2 != 0 and not _viable(ctx, m, f2):
			continue
		if hunger > 0 and f2 != 0 and not _fed(ctx, m, f2, t2):
			continue
		path.append(m)
		_walk(ctx, m, next + 1 if k != 0 else next, f2, path, t2)
		path.resize(path.size() - 1)
		if ctx.walks.size() >= ctx.limit or ctx.nodes > ctx.cap:
			return

## Every free cell still reachable from the head, and no free cell a dead end
## unless it is the last leaf.
static func _viable(ctx: Dictionary, head: int, free: int) -> bool:
	var w: int = ctx.w
	var r: int = ctx.r
	var l: int = ctx.l
	var d: int = ctx.d
	var u: int = ctx.u
	var m1: int = ctx.m1
	var mw: int = ctx.mw
	var reach := 1 << head
	while true:
		var grown := reach | (free & (((reach & r) << 1) | (((reach & l) >> 1) & m1) \
			| ((reach & d) << w) | (((reach & u) >> w) & mw)))
		if grown == reach:
			break
		reach = grown
	if (reach & free) != free:
		return false
	var g := free | (1 << head)
	var a := r & (((g >> 1) & m1))
	var b := l & (g << 1)
	var c := d & (((g >> w) & mw))
	var e := u & (g << w)
	var any := a | b | c | e
	var two := (a & b) | (a & c) | (a & e) | (b & c) | (b & e) | (c & e)
	var one := free & any & ~two
	if free & ~any:
		return false
	return (one & ~int(ctx.end_bit)) == 0

## Peckish: whether a leaf is still within the tummy's reach of the head --
## `tummy` bare squares and then a leaf, through free squares only -- or,
## once only the last leaf is left, whether the bare squares left fit in it.
static func _fed(ctx: Dictionary, head: int, free: int, tummy: int) -> bool:
	var food: int = free & int(ctx.food)
	if food == 0:
		return popcount(free) - 1 <= tummy
	var w: int = ctx.w
	var r: int = ctx.r
	var l: int = ctx.l
	var d: int = ctx.d
	var u: int = ctx.u
	var m1: int = ctx.m1
	var mw: int = ctx.mw
	var bare: int = free & ~int(ctx.food) & ~int(ctx.end_bit)
	var reach := 1 << head
	for i in tummy + 1:
		var near := ((reach & r) << 1) | (((reach & l) >> 1) & m1) \
			| ((reach & d) << w) | (((reach & u) >> w) & mw)
		if near & food:
			return true
		var grown := reach | (near & bare)
		if grown == reach:
			return false
		reach = grown
	return false

## How many bits are set.
static func popcount(x: int) -> int:
	var c := 0
	while x != 0:
		x &= x - 1
		c += 1
	return c

# --------------------------------------------------------------- Peckish
#
# Insane's garden: the leaves carry no numbers (only the first and the last
# are marked) and the caterpillar's tummy holds HUNGER bare squares between
# bites. The answer is grown as every band's is, leaves are laid along it at
# most HUNGER bare squares apart, and the proof counts walks under those
# rules; while it finds a second, the first place the two part is fenced (or,
# where the answer itself runs, given a leaf).

## {cols, rows, path, leaves (first, the unnumbered ones, last), hedges,
##  unique, hunger}
static func generate_peckish(rng: RandomNumberGenerator, w: int, h: int, hunger: int,
		hedge_max: int, cap: int) -> Dictionary:
	var n := w * h
	var p := _stir(rng, w, h)
	var on_path := {}
	for i in n - 1:
		on_path[edge_key(p[i], p[i + 1])] = true
	# Leaves as far apart as the tummy allows, now and then one sooner.
	var idx := {0: true, n - 1: true}
	var at := 0
	while at + hunger + 1 < n - 1:
		at += hunger + 1 - (1 if rng.randf() < 0.25 else 0)
		idx[at] = true
	var hedges := {}
	var unique := false
	for g in n * 2:
		var s := count(w, h, _peck_leaves(p, idx), hedges.keys(), 2, cap, hunger)
		if s.count == 1 and not s.capped:
			unique = true
			break
		if s.capped or s.walks.size() < 2:
			if hedges.size() >= hedge_max:
				break
			# Out of nodes: a fence on a random edge the answer never crosses.
			for tries in 40:
				var c := rng.randi_range(0, n - 1)
				var ns := _nbrs(w, h, c)
				var e := edge_key(c, ns[rng.randi_range(0, ns.size() - 1)])
				if not on_path.has(e) and not hedges.has(e):
					hedges[e] = true
					break
			continue
		var alt: PackedInt32Array = s.walks[0] if s.walks[0] != p else s.walks[1]
		var i := 0
		while alt[i] == p[i]:
			i += 1
		var e := edge_key(alt[i - 1], alt[i])
		if not on_path.has(e) and hedges.size() < hedge_max:
			hedges[e] = true
		else:
			# The stray walk ran along the answer's own edge: a leaf where
			# the two first disagree pins it instead.
			var q := i
			while q < n - 1 and idx.has(q):
				q += 1
			if q >= n - 1:
				break
			idx[q] = true
	return {"cols": w, "rows": h, "path": p, "leaves": _peck_leaves(p, idx),
		"hedges": PackedInt32Array(hedges.keys()), "unique": unique, "hunger": hunger}

## The leaves in path order: the first, the middle ones, the last.
static func _peck_leaves(p: PackedInt32Array, idx: Dictionary) -> PackedInt32Array:
	return _leaves_of(p, idx)

## Insane's knobs: an 8x8 garden, a tummy of five bare squares, up to
## sixteen fences, and the proof's node cap. Mined offline
## (tools/insane/caterpillar_ladder.gd) into content/insane/caterpillar.json,
## because one board costs ~400 ms here.
const PECK_SIDE := 8
const PECK_HUNGER := 5
const PECK_FENCES := 16
const PECK_CAP := 4000

## One bank row, plain ints only.
static func to_bank(g: Dictionary) -> Dictionary:
	return {"cols": g.cols, "rows": g.rows, "hunger": g.hunger, "path": Array(g.path),
		"leaves": Array(g.leaves), "hedges": Array(g.hedges)}

static func from_bank(row: Dictionary) -> Dictionary:
	if row.is_empty() or not row.has("path"):
		return {}
	var path := PackedInt32Array()
	for v in row.path:
		path.append(int(v))
	var leaves := PackedInt32Array()
	for v in row.leaves:
		leaves.append(int(v))
	var hedges := PackedInt32Array()
	for v in row.hedges:
		hedges.append(int(v))
	return {"cols": int(row.cols), "rows": int(row.rows), "hunger": int(row.hunger), "path": path,
		"leaves": leaves, "hedges": hedges, "unique": true}

## How many steps a player could take along the answer that the board would
## not refuse and that no walk finishes from: on a proved board, every legal
## step off the answer. The bank's rung.
static func traps(g: Dictionary) -> int:
	var w: int = g.cols
	var h: int = g.rows
	var p: PackedInt32Array = g.path
	var hunger: int = g.get("hunger", 0)
	var ctx := context(w, h, g.leaves, Array(g.hedges), hunger)
	var on := {}
	var tummy := hunger
	var out := 0
	on[p[0]] = true
	for i in p.size() - 1:
		var head := p[i]
		var hb := 1 << head
		for s in [[ctx.r, 1], [ctx.l, -1], [ctx.d, w], [ctx.u, -w]]:
			if not (int(s[0]) & hb):
				continue
			var m: int = head + int(s[1])
			if on.has(m) or m == p[i + 1]:
				continue
			var k: int = ctx.clue[m]
			if (1 << m) == int(ctx.end_bit) and on.size() + 1 < p.size():
				continue
			if hunger > 0:
				if k == 0 and tummy <= 0:
					continue
			elif k != 0 and k != _eaten_on(ctx, on) + 1:
				continue
			out += 1
		var nxt := p[i + 1]
		on[nxt] = true
		tummy = hunger if ctx.clue[nxt] != 0 else tummy - 1
	return out

static func _eaten_on(ctx: Dictionary, on: Dictionary) -> int:
	var k := 0
	for c in on:
		if ctx.clue[c] != 0:
			k += 1
	return k
