extends RefCounted

## Bridges' generator: grow an answer, then prove the clues admit only that
## answer. There is no search for a puzzle -- the puzzle is whatever a legal
## network turns out to imply, because an islet's number *is* its degree in
## the grown network. So the clues are complete by construction and the only
## question left is whether a second network satisfies them.
## Spec: docs/superpowers/specs/2026-09-20-bridges-flat-design.md, section 4.
## Ported from the mock's generator, docs/brainstorm/concepts.html#bridges.

## The four bands (spec section 4). `span` is the furthest a run may reach,
## `loops` how many already-facing pairs the second pass tries to join, and
## `guess_free` whether propagation alone must finish the board. Insane's row
## is provisional, replaced by the bank in this board's own batch.
const BANDS := [
	{"n": 7, "islets": 11, "span": 5, "loops": 4, "guess_free": true},
	{"n": 9, "islets": 16, "span": 5, "loops": 6, "guess_free": false},
	{"n": 11, "islets": 24, "span": 5, "loops": 10, "guess_free": false},
	{"n": 11, "islets": 30, "span": 6, "loops": 12, "guess_free": false},
]
const MAX_DEGREE := 6
const MAX_PLANKS := 3
## The grow is cheap and the proof is not, so a board is regrown rather than
## repaired. The mock's worst case was 47 attempts on the hard band.
const ATTEMPTS := 200
## One grow wedges rather than fails: it can run out of legal candidates long
## before it has stood its islets. The guard is the mock's.
const GROW_GUARD := 4000
## Propagation settles in a handful of rounds; the cap only stops a pathology.
const PROP_ROUNDS := 200
const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
## A lane is walked in the positive directions only, so a facing pair is
## listed once whichever end it is read from.
const HALF_DIRS := [Vector2i(1, 0), Vector2i(0, 1)]

static func band(difficulty: int) -> Dictionary:
	return BANDS[clampi(difficulty, 0, BANDS.size() - 1)]

## The two cells sorted, so a pair keys the same whichever end asks.
static func lane_key(a: Vector2i, b: Vector2i) -> String:
	var p := a
	var q := b
	if q.y < p.y or (q.y == p.y and q.x < p.x):
		var swap := p
		p = q
		q = swap
	return "%d,%d|%d,%d" % [p.x, p.y, q.x, q.y]

## Every facing pair on the lattice: a lane ends at the first islet it meets,
## so a pair that faces another islet across a third never becomes a lane and
## a run can never pass over an islet. `cells` is the water strictly between.
static func lanes_for(n: int, islets: Array) -> Dictionary:
	var at := {}
	for cell in islets:
		at[cell] = true
	var out := {}
	for cell in islets:
		for dir in HALF_DIRS:
			var cells: Array[Vector2i] = []
			var p: Vector2i = cell + dir
			while p.x >= 0 and p.y >= 0 and p.x < n and p.y < n:
				if at.has(p):
					out[lane_key(cell, p)] = {"a": cell, "b": p, "cells": cells}
					break
				cells.append(p)
				p += dir
	return out

## lane key -> the lane keys whose water it shares. Two lanes on the same axis
## can never share a cell (each ends at the first islet), so the axes are
## compared as a guard rather than as a rule.
static func crossings(lanes: Dictionary) -> Dictionary:
	var by_cell := {}
	var out := {}
	for key in lanes:
		out[key] = []
		for cell in lanes[key].cells:
			by_cell.get_or_add(cell, []).append(key)
	for cell in by_cell:
		var list: Array = by_cell[cell]
		for i in list.size():
			for j in range(i + 1, list.size()):
				var ka: String = list[i]
				var kb: String = list[j]
				if _vertical(lanes[ka]) == _vertical(lanes[kb]):
					continue
				if not out[ka].has(kb):
					out[ka].append(kb)
				if not out[kb].has(ka):
					out[kb].append(ka)
	return out

static func _vertical(lane: Dictionary) -> bool:
	return int(lane.a.x) == int(lane.b.x)

# ---------------------------------------------------------------- the grow

## Place one islet, then repeatedly pick a standing islet, a direction, a
## distance and a run of one to three planks. Returns {} when the walk wedged
## before the band's islets stood. Runs are kept as index pairs, because
## centring moves every islet and a lane key would go stale.
static func _grow(rng: RandomNumberGenerator, b: Dictionary) -> Dictionary:
	var n: int = b.n
	var target: int = b.islets
	var span: int = b.span
	var islets: Array[Vector2i] = []
	var deg: Array[int] = []
	var runs: Array[Dictionary] = []
	var at := {}
	var cover := {}
	var first := Vector2i(rng.randi_range(1, n - 2), rng.randi_range(1, n - 2))
	at[first] = 0
	islets.append(first)
	deg.append(0)
	var guard := 0
	while islets.size() < target and guard < GROW_GUARD:
		guard += 1
		var i := rng.randi_range(0, islets.size() - 1)
		var src: Vector2i = islets[i]
		var dir: Vector2i = DIRS[rng.randi_range(0, DIRS.size() - 1)]
		# Never one: two islets never stand shoulder to shoulder.
		var d := rng.randi_range(2, span)
		var tgt: Vector2i = src + dir * d
		if tgt.x < 0 or tgt.y < 0 or tgt.x >= n or tgt.y >= n:
			continue
		if at.has(tgt) or cover.has(tgt):
			continue
		var touching := false
		for nd in DIRS:
			if at.has(tgt + nd):
				touching = true
				break
		if touching:
			continue
		var cells: Array[Vector2i] = []
		var ok := true
		for s in range(1, d):
			var c: Vector2i = src + dir * s
			if at.has(c) or cover.has(c):
				ok = false
				break
			cells.append(c)
		if not ok:
			continue
		var v := rng.randi_range(1, MAX_PLANKS)
		# No islet ever asks for more than six.
		if deg[i] + v > MAX_DEGREE:
			continue
		var j := islets.size()
		at[tgt] = j
		islets.append(tgt)
		deg.append(0)
		for c in cells:
			cover[c] = true
		runs.append({"a": i, "b": j, "v": v})
		deg[i] += v
		deg[j] += v
	if islets.size() < target:
		return {}
	return {"islets": islets, "deg": deg, "runs": runs, "at": at, "cover": cover}

## The grow lays exactly one run per new islet, so on its own it can only ever
## build a tree -- and on a tree the connectivity rule never bites and no lane
## is ever a decoy. So join a few pairs that already face each other, if
## nothing is in the way and both degrees allow it. Bounded by the degree cap
## rather than by the number asked for: past a point, asking for more loops
## changes nothing.
static func _close_loops(rng: RandomNumberGenerator, g: Dictionary, b: Dictionary) -> void:
	var n: int = b.n
	var islets: Array = g.islets
	var deg: Array = g.deg
	var runs: Array = g.runs
	var at: Dictionary = g.at
	var cover: Dictionary = g.cover
	var held := {}
	for r in runs:
		held["%d|%d" % [mini(int(r.a), int(r.b)), maxi(int(r.a), int(r.b))]] = true
	var pool: Array[Dictionary] = []
	for i in islets.size():
		for dir in HALF_DIRS:
			var cells: Array[Vector2i] = []
			var p: Vector2i = islets[i] + dir
			while p.x >= 0 and p.y >= 0 and p.x < n and p.y < n:
				if at.has(p):
					var j: int = int(at[p])
					if not held.has("%d|%d" % [mini(i, j), maxi(i, j)]):
						pool.append({"a": i, "b": j, "cells": cells})
					break
				cells.append(p)
				p += dir
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap: Dictionary = pool[i]
		pool[i] = pool[j]
		pool[j] = swap
	var want: int = b.loops
	for f in pool:
		if want <= 0:
			break
		var blocked := false
		for c in f.cells:
			if cover.has(c):
				blocked = true
				break
		if blocked:
			continue
		var v := rng.randi_range(1, MAX_PLANKS)
		if deg[f.a] + v > MAX_DEGREE or deg[f.b] + v > MAX_DEGREE:
			continue
		for c in f.cells:
			cover[c] = true
		runs.append({"a": f.a, "b": f.b, "v": v})
		deg[f.a] += v
		deg[f.b] += v
		want -= 1

## The walk starts on one cell and wanders, so a grown network can sit in a
## corner with two rows of open sea under it. Slide the whole thing so its
## bounding box is centred: nothing moves relative to anything else, so every
## lane, every crossing and the answer itself are untouched. A network that
## covers five rows of seven is a smaller board drawn on a bigger one, and
## centring only moves the empty water, so it is refused unless the box comes
## within one row *and* one column of the lattice edge.
static func _centre_and_reach(islets: Array, n: int) -> bool:
	if islets.is_empty():
		return false
	var lo := Vector2i(n, n)
	var hi := Vector2i(-1, -1)
	for q in islets:
		lo.x = mini(lo.x, q.x)
		lo.y = mini(lo.y, q.y)
		hi.x = maxi(hi.x, q.x)
		hi.y = maxi(hi.y, q.y)
	var sx := floori(float(n - 1 - (hi.x + lo.x)) / 2.0)
	var sy := floori(float(n - 1 - (hi.y + lo.y)) / 2.0)
	if sx != 0 or sy != 0:
		for i in islets.size():
			islets[i] = islets[i] + Vector2i(sx, sy)
	return hi.x - lo.x >= n - 2 and hi.y - lo.y >= n - 2

# ------------------------------------------------------------- the generator

## Grow, close some loops, centre and reach, derive the clues, prove them.
## A board that degrades is better than a board that fails to open, so the
## last attempt hands back the best board seen rather than nothing, in this
## order of preference: a board whose clues are proved unique *and* meet the
## band's guess-free demand, then any unique board, then the last one grown.
##
## **Every board carries `unique`, and it is the proof's own verdict.** The
## last-resort board is one the proof rejected for a second answer, so it
## comes back `unique = false` and the state can say so rather than assume.
## Measured on this Mac over 600 boards, 200 seeds a band: **0 came back
## non-unique**, and the worst board spent 38 of the 200 attempts (the means
## are 3.3, 3.8 and 6.3 on the three bands). Carrying the hard band's
## per-attempt failure rate out to 200 in a row lands somewhere around 1e-15,
## so the last resort is robustness and not a live path -- but the flag has to
## be honest whether or not the path is ever walked.
static func generate(rng: RandomNumberGenerator, difficulty: int) -> Dictionary:
	var b := band(difficulty)
	var last := {}
	var unique := {}
	for attempt in range(1, ATTEMPTS + 1):
		var g := _grow(rng, b)
		if g.is_empty():
			continue
		_close_loops(rng, g, b)
		if not _centre_and_reach(g.islets, b.n):
			continue
		var islets: Array = g.islets
		var lanes := lanes_for(b.n, islets)
		var answer := {}
		var ok := true
		for r in g.runs:
			var key := lane_key(islets[int(r.a)], islets[int(r.b)])
			if not lanes.has(key):
				ok = false
				break
			answer[key] = int(r.v)
		if not ok:
			continue
		var need := {}
		for i in islets.size():
			if int(g.deg[i]) < 1:
				ok = false
				break
			need[islets[i]] = int(g.deg[i])
		if not ok:
			continue
		var proof := count_solutions(b.n, islets, need, lanes, 2)
		var board := {
			"n": b.n,
			"islets": islets,
			"need": need,
			"answer": answer,
			"attempts": attempt,
			"guess_free": bool(proof.guess_free),
			"unique": int(proof.count) == 1,
		}
		last = board
		if not board.unique:
			continue
		if unique.is_empty():
			unique = board
		if b.guess_free and not board.guess_free:
			continue
		return board
	return unique if not unique.is_empty() else last

# ----------------------------------------------------------------- the proof

## Range propagation over every lane, then a counted search. `cap` stops the
## search early: the callers only ever need to know "one, or more than one".
## Returns {"count": int, "guess_free": bool} -- guess_free is true when
## propagation alone pinned every lane, so no branch was ever taken.
##
## `n` is the lattice size and **nothing here reads it**: the lanes and the
## crossings were both derived from it before this is called, so the search
## never needs the grid again. It stays in the signature because it is the
## documented interface -- `generate()`, the suite and the mock's counter all
## pass the board's own `n` -- and dropping it would be a rename of the one
## entry point outside this file.
static func count_solutions(n: int, islets: Array, need: Dictionary,
		lanes: Dictionary, cap: int) -> Dictionary:
	var ed := _compile(n, islets, need, lanes)
	var count: int = ed.lanes
	var lo := PackedByteArray()
	var hi := PackedByteArray()
	lo.resize(count)
	hi.resize(count)
	var nd: PackedInt32Array = ed.need
	for e in count:
		lo[e] = 0
		hi[e] = mini(MAX_PLANKS, mini(nd[ed.ea[e]], nd[ed.eb[e]]))
	var state := {"count": 0, "branched": false}
	_search(ed, lo, hi, cap, state)
	return {"count": int(state.count), "guess_free": not bool(state.branched)}

## The lanes and the islets as flat arrays: the search copies its ranges on
## every branch, so it reads indices rather than dictionary keys. `_n` is
## carried from `count_solutions`' interface and deliberately unread -- see
## there.
static func _compile(_n: int, islets: Array, need: Dictionary, lanes: Dictionary) -> Dictionary:
	var cross := crossings(lanes)
	var idx := {}
	for i in islets.size():
		idx[islets[i]] = i
	var keys: Array = lanes.keys()
	var eid := {}
	for e in keys.size():
		eid[keys[e]] = e
	var ea := PackedInt32Array()
	var eb := PackedInt32Array()
	var nd := PackedInt32Array()
	ea.resize(keys.size())
	eb.resize(keys.size())
	nd.resize(islets.size())
	for i in islets.size():
		nd[i] = int(need[islets[i]])
	# Plain Arrays while they are being filled: a packed array is a value type,
	# so appending through a subscript would append to a copy.
	var raw_inc: Array = []
	for i in islets.size():
		raw_inc.append([])
	var xs: Array[PackedInt32Array] = []
	for e in keys.size():
		var lane: Dictionary = lanes[keys[e]]
		ea[e] = int(idx[lane.a])
		eb[e] = int(idx[lane.b])
		raw_inc[ea[e]].append(e)
		raw_inc[eb[e]].append(e)
		var row := PackedInt32Array()
		for other in cross[keys[e]]:
			row.append(int(eid[other]))
		xs.append(row)
	var inc: Array[PackedInt32Array] = []
	for row2 in raw_inc:
		inc.append(PackedInt32Array(row2))
	return {
		"lanes": keys.size(), "islets": islets.size(), "keys": keys,
		"ea": ea, "eb": eb, "need": nd, "inc": inc, "cross": xs,
	}

## Narrow every lane's lo..hi until nothing changes. False on a contradiction.
## Four rules, and they are the whole of the solver's reasoning.
static func _propagate(ed: Dictionary, lo: PackedByteArray, hi: PackedByteArray) -> bool:
	var lanes: int = ed.lanes
	var count: int = ed.islets
	var nd: PackedInt32Array = ed.need
	var inc: Array = ed.inc
	var xs: Array = ed.cross
	var ea: PackedInt32Array = ed.ea
	var eb: PackedInt32Array = ed.eb
	for _round in PROP_ROUNDS:
		var changed := false
		# 1. An islet narrows every lane it touches against its own number and
		#    what its other lanes can still take.
		for i in count:
			var li: PackedInt32Array = inc[i]
			var sum_lo := 0
			var sum_hi := 0
			for e in li:
				sum_lo += lo[e]
				sum_hi += hi[e]
			if sum_lo > nd[i] or sum_hi < nd[i]:
				return false
			for e in li:
				var want_lo: int = nd[i] - (sum_hi - hi[e])
				var want_hi: int = nd[i] - (sum_lo - lo[e])
				# The ranges live in a byte array, so a bound that has run
				# past 0..3 is a contradiction and never a wrapped value.
				if want_lo > MAX_PLANKS or want_hi < 0:
					return false
				if want_lo > lo[e]:
					sum_lo += want_lo - lo[e]
					lo[e] = want_lo
					changed = true
				if want_hi < hi[e]:
					sum_hi -= hi[e] - want_hi
					hi[e] = want_hi
					changed = true
				if lo[e] > hi[e]:
					return false
		# 2. A lane that is certainly there closes every lane crossing it.
		for e in lanes:
			if lo[e] < 1:
				continue
			for f in xs[e]:
				if lo[f] >= 1:
					return false
				if hi[f] != 0:
					hi[f] = 0
					changed = true
		# 3. Flood the islets over the lanes that are certainly there; those
		#    groups are what the connectivity rule reasons about.
		var comp := PackedInt32Array()
		comp.resize(count)
		comp.fill(-1)
		var groups := 0
		for i in count:
			if comp[i] >= 0:
				continue
			comp[i] = groups
			var stack: Array[int] = [i]
			while not stack.is_empty():
				var u: int = stack.pop_back()
				for e in inc[u]:
					if lo[e] < 1:
						continue
					var v: int = eb[e] if ea[e] == u else ea[e]
					if comp[v] < 0:
						comp[v] = groups
						stack.append(v)
			groups += 1
		# 4. The group rule, and it is the one that makes connectivity part of
		#    the deduction rather than a filter at the end. A group that can no
		#    longer reach out of itself can never join the rest, so it is a
		#    contradiction; a group with exactly one way out must take it.
		if groups > 1:
			var outs: Array = []
			for k in groups:
				outs.append([])
			for e in lanes:
				if hi[e] < 1:
					continue
				var ca: int = comp[ea[e]]
				var cb: int = comp[eb[e]]
				if ca == cb:
					continue
				outs[ca].append(e)
				outs[cb].append(e)
			for k in groups:
				var row: Array = outs[k]
				if row.is_empty():
					return false
				if row.size() == 1:
					var e: int = row[0]
					if lo[e] < 1:
						lo[e] = 1
						changed = true
						if lo[e] > hi[e]:
							return false
		if not changed:
			return true
	return true

## Propagate, then branch on the lane with the fewest values left. Every lane
## settled means one candidate answer, which is checked whole.
static func _search(ed: Dictionary, lo: PackedByteArray, hi: PackedByteArray,
		cap: int, state: Dictionary) -> void:
	if int(state.count) >= cap:
		return
	if not _propagate(ed, lo, hi):
		return
	var pick := -1
	var span := MAX_PLANKS + 1
	for e in int(ed.lanes):
		if hi[e] > lo[e] and hi[e] - lo[e] < span:
			span = hi[e] - lo[e]
			pick = e
	if pick < 0:
		if _legal(ed, lo):
			state.count = int(state.count) + 1
		return
	state.branched = true
	for v in range(lo[pick], hi[pick] + 1):
		var l2 := lo.duplicate()
		var h2 := hi.duplicate()
		l2[pick] = v
		h2[pick] = v
		_search(ed, l2, h2, cap, state)
		if int(state.count) >= cap:
			return

## Every number met, no two runs crossing, and one single network.
static func _legal(ed: Dictionary, val: PackedByteArray) -> bool:
	var lanes: int = ed.lanes
	var count: int = ed.islets
	var nd: PackedInt32Array = ed.need
	var ea: PackedInt32Array = ed.ea
	var eb: PackedInt32Array = ed.eb
	var inc: Array = ed.inc
	var xs: Array = ed.cross
	var deg := PackedInt32Array()
	deg.resize(count)
	for e in lanes:
		if val[e] < 1:
			continue
		deg[ea[e]] += val[e]
		deg[eb[e]] += val[e]
	for i in count:
		if deg[i] != nd[i]:
			return false
	for e in lanes:
		if val[e] < 1:
			continue
		for f in xs[e]:
			if val[f] >= 1:
				return false
	if count <= 1:
		return true
	var seen := PackedByteArray()
	seen.resize(count)
	seen[0] = 1
	var reached := 1
	var stack: Array[int] = [0]
	while not stack.is_empty():
		var u: int = stack.pop_back()
		for e in inc[u]:
			if val[e] < 1:
				continue
			var v: int = eb[e] if ea[e] == u else ea[e]
			if seen[v] == 0:
				seen[v] = 1
				reached += 1
				stack.append(v)
	return reached == count
