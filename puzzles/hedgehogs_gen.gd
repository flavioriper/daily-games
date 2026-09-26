extends RefCounted

## Hedgehogs' day, scene-free: the lawn, the flood and the logic that proves
## it.
##
## A cols x rows lawn under leaf piles, k hedgehogs asleep under some of
## them. The day opens with one bare patch already raked: the opening cell
## and its eight neighbours are kept clear of hedgehogs, so the opening is a
## nought and floods. A deal is kept only if a solver that never guesses,
## starting from that opening, rakes every bare cell -- singles (a number's
## covered neighbours are all bare, or all hedgehogs), subsets (one number's
## covered set inside another's) where the level allows them, and the global
## count. Hard must need a subset at least once and Insane twice; Easy and
## Medium never may. A board logic plays out from the opening has one answer
## consistent with what it shows, so no separate uniqueness test is asked.
##
## Cells are ints, y * cols + x. Ported line for line from the concept
## page's mock (docs/brainstorm/concepts.html#hedgehogs: hedgehogBoard,
## hFlood, hDeduce, hProve).
## Spec: docs/superpowers/specs/2026-09-26-hedgehogs-flat-design.md, section 5.

## Per level: the lawn, the hedgehogs, whether the proof may subtract
## subsets and how many rounds must need one, and the opening flood's range
## in cells. Insane's row is provisional (CLAUDE.md, "Insane is a fourth
## level").
const BANDS := [
	{"cols": 8, "rows": 10, "k": 12, "subsets": false, "need_sub": 0, "open": Vector2i(12, 40)},
	{"cols": 9, "rows": 11, "k": 17, "subsets": false, "need_sub": 0, "open": Vector2i(12, 36)},
	{"cols": 10, "rows": 11, "k": 21, "subsets": true, "need_sub": 1, "open": Vector2i(8, 30)},
	{"cols": 10, "rows": 11, "k": 24, "subsets": true, "need_sub": 2, "open": Vector2i(6, 28)},
]
## Deals tried before the first proved one is handed back ungraded.
const ATTEMPTS := 400

static func band(d: int) -> Dictionary:
	return BANDS[clampi(d, 0, BANDS.size() - 1)]

## The up to eight cells round `c`, in row order.
static func neighbours(cols: int, rows: int, c: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	var x := c % cols
	var y := c / cols
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var nx := x + dx
			var ny := y + dy
			if nx >= 0 and ny >= 0 and nx < cols and ny < rows:
				out.append(ny * cols + nx)
	return out

## An empty lawn's dictionary: its size, a neighbour table built once, no
## hedgehogs yet.
static func blank(cols: int, rows: int, k: int) -> Dictionary:
	var n := cols * rows
	var nb: Array = []
	for c in n:
		nb.append(neighbours(cols, rows, c))
	var hog := PackedByteArray()
	hog.resize(n)
	var num := PackedInt32Array()
	num.resize(n)
	return {"cols": cols, "rows": rows, "n": n, "k": k, "nb": nb, "hog": hog, "num": num,
		"start": 0, "graded": true, "attempts": 0, "opened": 0, "proof": {}}

## Counts every bare cell's hedgehog neighbours; a hedgehog's own is -1.
static func count(g: Dictionary) -> void:
	var hog: PackedByteArray = g.hog
	var num: PackedInt32Array = g.num
	for c in int(g.n):
		if hog[c] == 1:
			num[c] = -1
			continue
		var s := 0
		for r: int in g.nb[c]:
			s += hog[r]
		num[c] = s

## Rakes `c` on `open` (1 = raked): a nought floods through its neighbours
## that are neither raked nor hedgehogs, and on through every nought it
## reaches. Returns Vector2i(cell, ring) in breadth-first order, `ring`
## being the distance from `c` -- the gust's timing. A hedgehog or a raked
## cell returns nothing.
static func flood(g: Dictionary, open: PackedByteArray, c: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var hog: PackedByteArray = g.hog
	var num: PackedInt32Array = g.num
	if open[c] == 1 or hog[c] == 1:
		return out
	open[c] = 1
	var q: Array[Vector2i] = [Vector2i(c, 0)]
	var head := 0
	while head < q.size():
		var p: Vector2i = q[head]
		head += 1
		out.append(p)
		if num[p.x] != 0:
			continue
		for r: int in g.nb[p.x]:
			if open[r] == 0 and hog[r] == 0:
				open[r] = 1
				q.append(Vector2i(r, p.y + 1))
	return out

## One round of logic from what is known: `open` (raked cells, whose numbers
## are read) and `known` (1 = a hedgehog known to be there: woken, pinned or
## proved). Returns {"rule": "single"|"subset"|"count", "safe", "hogs"} for
## the first rule family that decides anything, both sorted ascending, or {}
## when none does. **The player's flags are never read**: a flag may be
## wrong.
static func deduce(g: Dictionary, open: PackedByteArray, known: PackedByteArray, subsets: bool) -> Dictionary:
	var num: PackedInt32Array = g.num
	var cons: Array = []  # [PackedInt32Array unknowns, need]
	for c in int(g.n):
		if open[c] == 0:
			continue
		var u := PackedInt32Array()
		var need: int = num[c]
		for r: int in g.nb[c]:
			if known[r] == 1:
				need -= 1
			elif open[r] == 0:
				u.append(r)
		if not u.is_empty():
			cons.append([u, need])
	var safe := {}
	var hogs := {}
	for k: Array in cons:
		var u: PackedInt32Array = k[0]
		if int(k[1]) == 0:
			for r in u:
				safe[r] = true
		elif int(k[1]) == u.size():
			for r in u:
				hogs[r] = true
	if not safe.is_empty() or not hogs.is_empty():
		return _found("single", safe, hogs)
	if subsets:
		for a: Array in cons:
			var au: PackedInt32Array = a[0]
			for b: Array in cons:
				var bu: PackedInt32Array = b[0]
				if a == b or au.size() >= bu.size():
					continue
				var inside := true
				for r in au:
					if not bu.has(r):
						inside = false
						break
				if not inside:
					continue
				var diff := PackedInt32Array()
				for r in bu:
					if not au.has(r):
						diff.append(r)
				var dn: int = int(b[1]) - int(a[1])
				if dn == 0:
					for r in diff:
						safe[r] = true
				elif dn == diff.size():
					for r in diff:
						hogs[r] = true
		if not safe.is_empty() or not hogs.is_empty():
			return _found("subset", safe, hogs)
	var left: int = g.k
	var unk := {}
	for c in int(g.n):
		if known[c] == 1:
			left -= 1
		elif open[c] == 0:
			unk[c] = true
	if not unk.is_empty() and left == 0:
		return _found("count", unk, {})
	if not unk.is_empty() and left == unk.size():
		return _found("count", {}, unk)
	return {}

static func _found(rule: String, safe: Dictionary, hogs: Dictionary) -> Dictionary:
	var s := PackedInt32Array(safe.keys())
	s.sort()
	var h := PackedInt32Array(hogs.keys())
	h.sort()
	return {"rule": rule, "safe": s, "hogs": h}

## Plays the whole lawn out by logic from the opening. {"ok", "rounds",
## "sub" (rounds that needed a subset), "cnt" (rounds that needed the count)}.
static func prove(g: Dictionary, subsets: bool) -> Dictionary:
	var n: int = g.n
	var open := PackedByteArray()
	open.resize(n)
	var known := PackedByteArray()
	known.resize(n)
	flood(g, open, g.start)
	var hog: PackedByteArray = g.hog
	var safe_left := 0
	for c in n:
		if hog[c] == 0 and open[c] == 0:
			safe_left += 1
	var rounds := 0
	var sub := 0
	var cnt := 0
	while safe_left > 0:
		var d := deduce(g, open, known, subsets)
		if d.is_empty():
			return {"ok": false, "rounds": rounds, "sub": sub, "cnt": cnt}
		rounds += 1
		if d.rule == "subset":
			sub += 1
		elif d.rule == "count":
			cnt += 1
		for r: int in d.hogs:
			known[r] = 1
		for r: int in d.safe:
			if open[r] == 0:
				safe_left -= flood(g, open, r).size()
	return {"ok": true, "rounds": rounds, "sub": sub, "cnt": cnt}

## The day's lawn for level `d`, seeded only by `rng`. The opening is dealt
## away from the edge with its 3x3 kept clear; the hedgehogs are the first k
## of the rest, shuffled. Kept only if the opening flood is in the level's
## range and `prove` plays the lawn out; a proof short of the level's subset
## quota is kept aside as the fallback, handed back ungraded after ATTEMPTS.
static func generate(rng: RandomNumberGenerator, d: int) -> Dictionary:
	var bd := band(d)
	var cols: int = bd.cols
	var rows: int = bd.rows
	var fallback := {}
	for attempt in range(1, ATTEMPTS + 1):
		var g := blank(cols, rows, bd.k)
		var sx := rng.randi_range(1, cols - 2)
		var sy := rng.randi_range(1, rows - 2)
		g.start = sy * cols + sx
		var free: Array[int] = []
		for c in int(g.n):
			if absi(c % cols - sx) > 1 or absi(c / cols - sy) > 1:
				free.append(c)
		for i in range(free.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var t := free[i]
			free[i] = free[j]
			free[j] = t
		var hog: PackedByteArray = g.hog
		for i in int(bd.k):
			hog[free[i]] = 1
		count(g)
		var probe := PackedByteArray()
		probe.resize(g.n)
		var opened := flood(g, probe, g.start).size()
		var span: Vector2i = bd.open
		if opened < span.x or opened > span.y:
			continue
		var p := prove(g, bd.subsets)
		if not p.ok:
			continue
		g.attempts = attempt
		g.opened = opened
		g.proof = p
		if int(p.sub) < int(bd.need_sub):
			if fallback.is_empty():
				fallback = g
			continue
		g.graded = true
		return g
	if not fallback.is_empty():
		fallback.graded = false
		fallback.attempts = ATTEMPTS
	return fallback
