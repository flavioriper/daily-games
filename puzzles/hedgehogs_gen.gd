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
## in cells. Insane adds the sleepwalkers below.
##
## Made fun (2026-10-28, tests/_probe_hh_fun.gd): a deal must also hand the
## player a way in and a warm-up. The opening's first reading decides at
## least FIRST_READ piles on every band (one in three Hard openings decided
## one or none), and `late` is the most of the bare piles a reader of one
## number at a time may be left facing when the first pair of numbers is
## needed: on Hard and Insane that wall came at the opening itself on one
## night in four, and before half way on most.
const Planes = preload("res://puzzles/planes_state.gd")

const BANDS := [
	{"cols": 8, "rows": 10, "k": 12, "subsets": false, "need_sub": 0, "open": Vector2i(12, 40), "late": 1.0},
	{"cols": 9, "rows": 11, "k": 17, "subsets": false, "need_sub": 0, "open": Vector2i(12, 36), "late": 1.0},
	{"cols": 10, "rows": 11, "k": 21, "subsets": true, "need_sub": 1, "open": Vector2i(8, 30), "late": 0.5},
	{"cols": 10, "rows": 11, "k": 24, "subsets": true, "need_sub": 2, "open": Vector2i(6, 28), "late": 0.8},
]
const FIRST_READ := 2

## Sleepwalkers (Insane): every WALK_EVERY rakes the bell rings and one
## sleeping hedgehog, not under a flag, steps to a covered pile next to it --
## only a step after which logic still plays the lawn out from what the
## player can see. WALK_TRIES steps are tried, in the day's own order.
const WALK_EVERY := 3
const WALK_TRIES := 30
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
## hedgehogs yet. `void` (1 = not lawn, the day's shape cut round it; empty
## for the whole rectangle) is kept out of every neighbour list, has none of
## its own, is never covered, raked, counted or a hedgehog's.
static func blank(cols: int, rows: int, k: int, void_in := PackedByteArray()) -> Dictionary:
	var n := cols * rows
	var voids := PackedByteArray()
	voids.resize(n)
	if void_in.size() == n:
		voids = void_in.duplicate()
	var nb: Array = []
	for c in n:
		var out := PackedInt32Array()
		if voids[c] == 0:
			for r in neighbours(cols, rows, c):
				if voids[r] == 0:
					out.append(r)
		nb.append(out)
	var hog := PackedByteArray()
	hog.resize(n)
	var num := PackedInt32Array()
	num.resize(n)
	return {"cols": cols, "rows": rows, "n": n, "k": k, "nb": nb, "hog": hog, "num": num,
		"void": voids, "start": 0, "graded": true, "attempts": 0, "opened": 0, "proof": {}}

## Whether `c` is outside the day's shape (never on a rectangle).
static func is_void(g: Dictionary, c: int) -> bool:
	var v: PackedByteArray = g.get("void", PackedByteArray())
	return c < v.size() and v[c] == 1

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
	var voids: PackedByteArray = g.get("void", PackedByteArray())
	for c in int(g.n):
		if known[c] == 1:
			left -= 1
		elif open[c] == 0 and (voids.is_empty() or voids[c] == 0):
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
	var open := PackedByteArray()
	open.resize(g.n)
	flood(g, open, g.start)
	var known := PackedByteArray()
	known.resize(g.n)
	return prove_from(g, subsets, open, known)

## `prove` from a position part played: `open` (raked) and `known` (hedgehogs
## the player can see are there: woken, pinned), both copied, never written.
## Sleepwalkers asks it of every step a hedgehog might take, so a walk never
## leaves the player a guess.
static func prove_from(g: Dictionary, subsets: bool, open_in: PackedByteArray, known_in: PackedByteArray) -> Dictionary:
	var n: int = g.n
	var open := open_in.duplicate()
	var known := known_in.duplicate()
	var hog: PackedByteArray = g.hog
	var safe_left := 0
	for c in n:
		if hog[c] == 0 and open[c] == 0 and not is_void(g, c):
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

## Whether the opening (`open`, raked) hands a way in -- its first reading
## decides FIRST_READ piles or more -- and a reader of one number at a time
## gets at least as far as `late` allows before a pair is needed.
static func _warm(g: Dictionary, open_in: PackedByteArray, late: float) -> bool:
	var open := open_in.duplicate()
	var known := PackedByteArray()
	known.resize(g.n)
	var first := deduce(g, open, known, false)
	if first.is_empty() or first.rule == "count" or first.safe.size() + first.hogs.size() < FIRST_READ:
		return false
	if late >= 1.0:
		return true
	var bare := 0
	for c in int(g.n):
		if g.hog[c] == 0 and open[c] == 0 and not is_void(g, c):
			bare += 1
	var d := first
	while not d.is_empty() and d.rule == "single":
		for r: int in d.hogs:
			known[r] = 1
		for r: int in d.safe:
			if open[r] == 0:
				flood(g, open, r)
		d = deduce(g, open, known, false)
	var left := 0
	for c in int(g.n):
		if g.hog[c] == 0 and open[c] == 0 and not is_void(g, c):
			left += 1
	return float(left) <= late * float(bare)

## The day's lawn for level `d`, seeded only by `rng`. The opening is dealt
## away from the edge with its 3x3 kept clear; the hedgehogs are the first k
## of the rest, shuffled. Kept only if the opening flood is in the level's
## range and `prove` plays the lawn out; a proof short of the level's subset
## quota is kept aside as the fallback, handed back ungraded after ATTEMPTS.
##
## `shape` (shape_fit's, the day's thing) lays the lawn in its cut instead:
## its box, its void, its hedgehogs and opening range scaled to its cells,
## and the opening only where its whole 3x3 is lawn. A shape that never
## deals a proved lawn returns {}, and the board deals the rectangle.
static func generate(rng: RandomNumberGenerator, d: int, shape: Dictionary = {}) -> Dictionary:
	var bd := band(d)
	var cols: int = bd.cols
	var rows: int = bd.rows
	var k: int = bd.k
	var span: Vector2i = bd.open
	var voids := PackedByteArray()
	var starts: Array[int] = []
	if not shape.is_empty():
		cols = int(shape.cols)
		rows = int(shape.rows)
		k = int(shape.k)
		span = shape.open
		voids = shape.void
		starts.assign(shape.starts)
	var fallback := {}
	for attempt in range(1, ATTEMPTS + 1):
		var g := blank(cols, rows, k, voids)
		var sx := 0
		var sy := 0
		if starts.is_empty():
			sx = rng.randi_range(1, cols - 2)
			sy = rng.randi_range(1, rows - 2)
		else:
			var s0: int = starts[rng.randi_range(0, starts.size() - 1)]
			sx = s0 % cols
			sy = s0 / cols
		g.start = sy * cols + sx
		var free: Array[int] = []
		for c in int(g.n):
			if (absi(c % cols - sx) > 1 or absi(c / cols - sy) > 1) and g.void[c] == 0:
				free.append(c)
		for i in range(free.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var t := free[i]
			free[i] = free[j]
			free[j] = t
		var hog: PackedByteArray = g.hog
		for i in k:
			hog[free[i]] = 1
		count(g)
		var probe := PackedByteArray()
		probe.resize(g.n)
		var opened := flood(g, probe, g.start).size()
		if opened < span.x or opened > span.y:
			continue
		var p := prove(g, bd.subsets)
		if not p.ok:
			continue
		g.attempts = attempt
		g.opened = opened
		g.proof = p
		if int(p.sub) < int(bd.need_sub) or not _warm(g, probe, float(bd.late)):
			if fallback.is_empty():
				fallback = g
			continue
		g.graded = true
		return g
	if not shape.is_empty():
		# A themed lawn is dealt graded or not at all: the rectangle is the
		# fallback, never a shape that skipped the band's own promise.
		return {}
	if not fallback.is_empty():
		fallback.graded = false
		fallback.attempts = ATTEMPTS
	return fallback

# --- the day's shape (daily theme, wave 2, 2026-11-06) ---

## The night's picture sides each band tries, in order: each is a different
## thing of the theme, so the bands mostly lay different lawns.
const THEMED_SIZES := [[10, 12, 24, 32], [12, 24, 32, 10], [24, 32, 12, 10], [32, 24, 12, 10]]
## A cut is kept when its lawn is at least SHAPE_MIN of the band's own
## rectangle (a smaller lawn is a shorter day) and at most SHAPE_MAX of its
## box (or it is a rectangle with a corner off). Boxes grow up to SHAPE_GROW
## a side past the band's: taller boxes shrink every pile on a phone.
const SHAPE_MIN := 0.7
const SHAPE_MAX := 0.9
const SHAPE_GROW := 1

## `pic_rows` (a night picture's rows) cut for band `d`: {cols, rows, void,
## beads (cell -> bead name), cells, k, open, starts}, or {} when no box
## takes it. The cut is smoothed (a one-cell spur trimmed, a one-cell nook
## filled) and kept as its largest piece; hedgehogs and the opening's range
## keep the band's density.
static func shape_fit(pic_rows: Array, d: int) -> Dictionary:
	var bd := band(d)
	var n0 := int(bd.cols) * int(bd.rows)
	for grow in SHAPE_GROW + 1:
		var box := Vector2i(int(bd.cols) + grow, int(bd.rows) + grow)
		var cut := Planes.cut_shape(pic_rows, box, false)
		if cut.is_empty():
			continue
		var off := Vector2i((box.x - int(cut.cols)) / 2, (box.y - int(cut.rows)) / 2)
		var on := {}
		for c: Vector2i in cut.cells:
			on[c + off] = cut.cells[c]
		on = _smooth(on, box)
		# Laid in the smoothed cut's own extent: no row or column of grass
		# a phone pays height for.
		var lo := Vector2i(1 << 20, 1 << 20)
		var hi := Vector2i(-1, -1)
		for c: Vector2i in on:
			lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
			hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
		if hi.x < 0:
			continue
		box = hi - lo + Vector2i.ONE
		var moved := {}
		for c: Vector2i in on:
			moved[c - lo] = on[c]
		on = moved
		var count := on.size()
		if float(count) < SHAPE_MIN * float(n0) or float(count) > SHAPE_MAX * float(box.x * box.y):
			continue
		var voids := PackedByteArray()
		voids.resize(box.x * box.y)
		voids.fill(1)
		for c: Vector2i in on:
			voids[c.y * box.x + c.x] = 0
		var starts: Array[int] = []
		for y in range(1, box.y - 1):
			for x in range(1, box.x - 1):
				var whole := true
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						if voids[(y + dy) * box.x + x + dx] == 1:
							whole = false
				if whole:
					starts.append(y * box.x + x)
		if starts.size() < 4:
			continue
		var share := float(count) / float(n0)
		var span: Vector2i = bd.open
		return {"cols": box.x, "rows": box.y, "void": voids, "beads": on, "cells": count,
			"k": int(round(float(bd.k) * share)),
			"open": Vector2i(int(round(span.x * share)), int(round(span.y * share))),
			"starts": starts}
	return {}

## A cut without its one-cell spurs and nooks, as its largest piece.
static func _smooth(on: Dictionary, box: Vector2i) -> Dictionary:
	var dirs := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
	for pass_i in 3:
		var changed := false
		for y in box.y:
			for x in box.x:
				var c := Vector2i(x, y)
				var sides := 0
				var bead := ""
				for dv: Vector2i in dirs:
					if on.has(c + dv):
						sides += 1
						bead = String(on[c + dv])
				if on.has(c) and sides <= 1:
					on.erase(c)
					changed = true
				elif not on.has(c) and sides >= 3:
					on[c] = bead
					changed = true
		if not changed:
			break
	var best := {}
	var seen := {}
	for c: Vector2i in on:
		if seen.has(c):
			continue
		var piece := {c: on[c]}
		seen[c] = true
		var stack: Array = [c]
		while not stack.is_empty():
			var p: Vector2i = stack.pop_back()
			for dv: Vector2i in dirs:
				var q: Vector2i = p + dv
				if on.has(q) and not seen.has(q):
					seen[q] = true
					piece[q] = on[q]
					stack.append(q)
		if piece.size() > best.size():
			best = piece
	return best
