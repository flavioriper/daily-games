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

## Counts walks from leaf 1 over every cell, leaves in order, ending on the
## last leaf, up to `limit`. {count, walks (the first `limit` found), capped}.
static func count(w: int, h: int, leaves: PackedInt32Array, hedges: Array, limit: int, cap: int) -> Dictionary:
	var n := w * h
	var ctx := {"w": w, "n": n, "limit": limit, "cap": cap, "nodes": 0, "walks": []}
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
	var full := -1 if n == 64 else (1 << n) - 1
	var path := PackedInt32Array([leaves[0]])
	_walk(ctx, leaves[0], 2, full & ~(1 << leaves[0]), path)
	return {"count": ctx.walks.size(), "walks": ctx.walks, "capped": ctx.nodes > cap}

static func _walk(ctx: Dictionary, head: int, next: int, free: int, path: PackedInt32Array) -> void:
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
		if k != 0 and k != next:
			continue
		if mb == ctx.end_bit and free != mb:
			continue
		var f2 := free & ~mb
		if f2 != 0 and not _viable(ctx, m, f2):
			continue
		path.append(m)
		_walk(ctx, m, next + 1 if k != 0 else next, f2, path)
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
