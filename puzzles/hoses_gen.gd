extends RefCounted

## Hosepipes' garden beds (spec docs/superpowers/specs/2026-10-22-hoses-design.md):
## the day's deal and the solver that proves it has one answer.
##
## A bed is n by n squares. Each colour has two ends on it, a tap and a
## flower; on Insane (Seedlings) some flowers are bare seeds, which any
## hose may water. The answer joins every pair with a hose of its colour,
## hoses never share a square, and every square is watered.
##
## The deal: every square starts as a hose of one, and hoses whose ends are
## side by side are joined, never so a hose runs alongside itself, until
## the band's count is left, each at least MIN_LEN long; their ends are the
## taps and the flowers. A cut is kept only
## when `count` proves the ends allow no other answer. The proof is never
## capped by a node count (Caterpillar's lesson: a capped search read as
## unique is no proof); it is kept fast by pruning instead.

## The bands: squares a side, how many hoses (lo..hi), seeds (Insane).
const BANDS := [
	{"n": 5, "lo": 4, "hi": 5, "seeds": 0},
	{"n": 6, "lo": 5, "hi": 6, "seeds": 0},
	{"n": 7, "lo": 6, "hi": 7, "seeds": 0},
	{"n": 8, "lo": 7, "hi": 8, "seeds": 3},
]
## The shortest hose dealt, in squares counting both ends.
const MIN_LEN := 3
## No more colours than the categorical ramp has (core/palette.gd CAT).
const MAX_HOSES := 8

## A cell no hose owns yet, and a seed no hose has reached.
const EMPTY := -1
const SEED := -2

# --- the deal ---

## The day for `band`: {n, ends: [[tap, flower], ...] (flower -1 for a
## seed hose's), seeds: [cells], paths: [[cells tap..flower], ...]}.
static func deal(rng: RandomNumberGenerator, band: int, tries := 400) -> Dictionary:
	var b: Dictionary = BANDS[clampi(band, 0, 3)]
	var n := int(b.n)
	var seeds := int(b.seeds)
	for attempt in tries:
		var k := rng.randi_range(int(b.lo), int(b.hi))
		var paths := _grow(rng, n, k)
		if paths.is_empty():
			continue
		var day := _day_of(rng, n, paths, 0)
		if count(day, 2) != 1:
			continue
		if seeds == 0:
			day["attempts"] = attempt + 1
			return day
		# a seed only loosens the bed, so only a bed with one answer is tried
		# with seeds, a few different hoses seeded before it is let go
		for again in 8:
			var seeded := _day_of(rng, n, day.paths, seeds)
			if (seeded.seeds as Array).size() == seeds and count(seeded, 2) == 1:
				seeded["attempts"] = attempt + 1
				return seeded
	return {}

## A banked day (content/insane/hoses.json, hoses_hard.json) back as `deal`
## hands one over, or {} when it does not hold together. The phone checks
## what is cheap -- the hoses water every square once, step by step, from
## their ends -- and trusts the miner's proof that there is one answer.
static func from_bank(board: Dictionary) -> Dictionary:
	var n := int(board.get("n", 0))
	var ends: Array = board.get("ends", [])
	var seeds: Array = board.get("seeds", [])
	var paths: Array = board.get("paths", [])
	if n < 4 or n > 9 or ends.is_empty() or ends.size() != paths.size() or ends.size() > MAX_HOSES:
		return {}
	var seen := {}
	var out_paths := []
	var out_ends := []
	var seed_left := {}
	for sc in seeds:
		seed_left[int(sc)] = true
	for c in paths.size():
		var p: Array = paths[c]
		var e: Array = ends[c]
		if p.size() < 2 or e.size() != 2:
			return {}
		var q := []
		for i in p.size():
			var v := int(p[i])
			if v < 0 or v >= n * n or seen.has(v):
				return {}
			if i > 0 and not v in _nbs(int(q[i - 1]), n):
				return {}
			seen[v] = true
			q.append(v)
		if int(e[0]) != int(q[0]):
			return {}
		if int(e[1]) >= 0:
			if int(e[1]) != int(q[q.size() - 1]):
				return {}
		elif not seed_left.erase(int(q[q.size() - 1])):
			return {}
		out_paths.append(q)
		out_ends.append([int(e[0]), int(e[1])])
	if seen.size() != n * n or not seed_left.is_empty():
		return {}
	var out_seeds := []
	for sc in seeds:
		out_seeds.append(int(sc))
	return {"n": n, "ends": out_ends, "seeds": out_seeds, "paths": out_paths}

## The day as a bank keeps it.
static func to_bank(day: Dictionary) -> Dictionary:
	if day.is_empty():
		return {}
	return {"n": day.n, "ends": day.ends, "seeds": day.seeds, "paths": day.paths}

## The ends of `paths`, each reversed or not at random, seeds chosen.
static func _day_of(rng: RandomNumberGenerator, n: int, paths: Array, seeds: int) -> Dictionary:
	var ends := []
	var out := []
	for p: Array in paths:
		var q := p.duplicate()
		if rng.randf() < 0.5:
			q.reverse()
		out.append(q)
	# the seed hoses: any of four squares or more, so a seed is never a
	# step from its tap
	var order := []
	for c in out.size():
		if (out[c] as Array).size() >= 4:
			order.append(c)
	for i in range(order.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = order[i]
		order[i] = order[j]
		order[j] = t
	var seeded := {}
	for i in mini(seeds, order.size()):
		seeded[order[i]] = true
	var seed_cells := []
	for c in out.size():
		var q: Array = out[c]
		if seeded.has(c):
			ends.append([int(q[0]), -1])
			seed_cells.append(int(q[q.size() - 1]))
		else:
			ends.append([int(q[0]), int(q[q.size() - 1])])
	return {"n": n, "ends": ends, "seeds": seed_cells, "paths": out}

## The bed split into `k` hoses, none running alongside itself: every
## square starts as a hose of one, and two hoses whose ends are side by side
## are joined, the shortest first, until `k` are left. [] when it stalls or
## leaves a hose under MIN_LEN.
static func _grow(rng: RandomNumberGenerator, n: int, k: int) -> Array:
	var N := n * n
	var paths := {}
	var of := PackedInt32Array()
	of.resize(N)
	for i in N:
		paths[i] = [i]
		of[i] = i
	var left := N
	while left > k:
		# the shortest hoses' ends look for a neighbour's end first
		var shortest := N
		for id in paths:
			shortest = mini(shortest, (paths[id] as Array).size())
		var tries := []
		var spare := []
		for id in paths:
			var p: Array = paths[id]
			var ends := [p[0]] if p.size() == 1 else [p[0], p[p.size() - 1]]
			for e in ends:
				for v in _nbs(int(e), n):
					var q: Array = paths[of[v]]
					if of[v] == id or (int(q[0]) != v and int(q[q.size() - 1]) != v):
						continue
					if p.size() == shortest or q.size() == shortest:
						tries.append([id, int(e), of[v], v])
					else:
						spare.append([id, int(e), of[v], v])
		var joined := false
		var pools := [tries, spare]
		if rng.randf() < 0.15:
			pools = [spare, tries]
		for pool: Array in pools:
			if joined:
				break
			while not pool.is_empty():
				var at := rng.randi_range(0, pool.size() - 1)
				var m: Array = pool[at]
				pool.remove_at(at)
				var a: Array = (paths[m[0]] as Array).duplicate()
				var b: Array = (paths[m[2]] as Array).duplicate()
				if int(a[a.size() - 1]) != int(m[1]):
					a.reverse()
				if int(b[0]) != int(m[3]):
					b.reverse()
				var j: Array = a + b
				if _touches([j], n):
					continue
				paths.erase(m[2])
				paths[m[0]] = j
				for c in b:
					of[int(c)] = int(m[0])
				left -= 1
				joined = true
				break
		if not joined:
			return []
	var out := []
	for id in paths:
		var p: Array = paths[id]
		if p.size() < MIN_LEN:
			return []
		out.append(p)
	return out

## Whether a hose runs alongside itself: two of its squares side by side
## that are not one step apart along it. Such a hose can nearly always cut
## the corner, and a bed with one almost never has one answer.
static func _touches(paths: Array, n: int) -> bool:
	for p: Array in paths:
		var at := {}
		for i in p.size():
			at[int(p[i])] = i
		for i in p.size():
			for v in _nbs(int(p[i]), n):
				if at.has(v) and absi(int(at[v]) - i) > 1:
					return true
	return false

static func _nbs(i: int, n: int) -> Array:
	var x := i % n
	var y := i / n
	var out := []
	if x > 0: out.append(i - 1)
	if x < n - 1: out.append(i + 1)
	if y > 0: out.append(i - n)
	if y < n - 1: out.append(i + n)
	return out

# --- the solver ---

## How many answers the day's ends allow, stopping at `most`. Every hose
## grows from its tap; a seed hose may end on any seed no hose has reached.
static func count(day: Dictionary, most := 2) -> int:
	var s := Solver.new(day)
	s.most = most
	s.run()
	return s.found

## How hard the solver worked to prove the day: the nodes it searched.
static func effort(day: Dictionary) -> int:
	var s := Solver.new(day)
	s.most = 2
	s.run()
	return s.nodes if s.found == 1 else -1

## One answer for the day's ends, as paths tap..flower ([] if none). Seed
## hoses end on the seed they reach.
static func solve(day: Dictionary) -> Array:
	var s := Solver.new(day)
	s.most = 1
	s.keep = true
	s.run()
	return s.answer

class Solver:
	var n := 0
	var N := 0
	var nbs: Array = []          # cell -> PackedInt32Array of neighbours
	var owner := PackedInt32Array()
	var head := PackedInt32Array()
	var goal := PackedInt32Array()  # -1 for a seed hose
	var done := PackedByteArray()
	var trail: Array = []        # per hose, the cells from the tap (when keep)
	var hoses := 0
	var open := 0
	var empties := 0
	var free_seeds := 0
	var most := 2
	var found := 0
	var nodes := 0
	var keep := false
	var answer: Array = []
	var _region := PackedInt32Array()
	var _stack := PackedInt32Array()

	func _init(day: Dictionary) -> void:
		n = int(day.n)
		N = n * n
		for i in N:
			var x := i % n
			var y := i / n
			var a := PackedInt32Array()
			if x > 0: a.append(i - 1)
			if x < n - 1: a.append(i + 1)
			if y > 0: a.append(i - n)
			if y < n - 1: a.append(i + n)
			nbs.append(a)
		owner.resize(N)
		owner.fill(EMPTY)
		_region.resize(N)
		_stack.resize(N)
		var ends: Array = day.ends
		hoses = ends.size()
		head.resize(hoses)
		goal.resize(hoses)
		done.resize(hoses)
		for c in hoses:
			var e: Array = ends[c]
			head[c] = int(e[0])
			goal[c] = int(e[1])
			owner[int(e[0])] = c
			if int(e[1]) >= 0:
				owner[int(e[1])] = c
			trail.append([int(e[0])])
		for sc in day.get("seeds", []):
			owner[int(sc)] = SEED
			free_seeds += 1
		open = hoses
		for i in N:
			if owner[i] == EMPTY:
				empties += 1

	func run() -> void:
		if _ok():
			_search()

	## The moves hose `c` has from its head: [cell, finishes].
	func _moves(c: int) -> Array:
		var out := []
		var h := head[c]
		for v in nbs[h]:
			var o := owner[v]
			if o == EMPTY:
				out.append(v)
			elif v == goal[c] and goal[c] >= 0:
				out.append(v)
			elif o == SEED and goal[c] < 0:
				out.append(v)
		return out

	func _search() -> void:
		nodes += 1
		if open == 0:
			if empties == 0 and free_seeds == 0:
				found += 1
				if keep and answer.is_empty():
					for t: Array in trail:
						answer.append(t.duplicate())
			return
		# the open hose with the fewest moves grows first
		var best := -1
		var best_moves := []
		for c in hoses:
			if done[c]:
				continue
			var m := _moves(c)
			if m.is_empty():
				return
			if best < 0 or m.size() < best_moves.size():
				best = c
				best_moves = m
				if m.size() == 1:
					break
		var c := best
		var h := head[c]
		for v: int in best_moves:
			var o := owner[v]
			var finishing := (v == goal[c]) or o == SEED
			if o == SEED:
				owner[v] = c
				free_seeds -= 1
			elif o == EMPTY:
				owner[v] = c
				empties -= 1
			head[c] = v
			if keep:
				(trail[c] as Array).append(v)
			if finishing:
				done[c] = 1
				open -= 1
			if _ok():
				_search()
			if finishing:
				done[c] = 0
				open += 1
			if keep:
				(trail[c] as Array).pop_back()
			head[c] = h
			if o == SEED:
				owner[v] = SEED
				free_seeds += 1
			elif o == EMPTY:
				owner[v] = EMPTY
				empties += 1
			if found >= most:
				return

	## Whether the bed as it stands can still be finished, by what is cheap
	## to see: every empty square two ways in, every open hose a way on and
	## a way to its flower through empty ground, every patch of empty ground
	## some open hose able to water it.
	func _ok() -> bool:
		# an empty square needs two of: empty squares, open heads, open flowers, free seeds
		for i in N:
			if owner[i] != EMPTY:
				continue
			var ways := 0
			for v in nbs[i]:
				var o := owner[v]
				if o == EMPTY or o == SEED:
					ways += 1
				elif o >= 0 and not done[o] and (v == head[o] or v == goal[o]):
					ways += 1
			if ways < 2:
				return false
		# patches of empty ground
		_region.fill(-1)
		var regions := 0
		for i in N:
			if owner[i] != EMPTY or _region[i] >= 0:
				continue
			var top := 0
			_stack[top] = i
			top += 1
			_region[i] = regions
			while top > 0:
				top -= 1
				var u := _stack[top]
				for v in nbs[u]:
					if owner[v] == EMPTY and _region[v] < 0:
						_region[v] = regions
						_stack[top] = v
						top += 1
			regions += 1
		var served := PackedByteArray()
		served.resize(regions)
		var seed_reg_hi := {}
		if free_seeds > 0:
			for i in N:
				if owner[i] != SEED:
					continue
				var touched := false
				for v in nbs[i]:
					if owner[v] == EMPTY:
						seed_reg_hi[_region[v]] = true
						touched = true
					elif owner[v] >= 0 and not done[owner[v]] and goal[owner[v]] < 0 and v == head[owner[v]]:
						touched = true
				if not touched:
					return false
		for c in hoses:
			if done[c]:
				continue
			var h := head[c]
			var hr := {}
			var next_to := false
			for v in nbs[h]:
				var o := owner[v]
				if o == EMPTY:
					hr[_region[v]] = true
				elif goal[c] >= 0 and v == goal[c]:
					next_to = true
				elif goal[c] < 0 and o == SEED:
					next_to = true
			if goal[c] >= 0:
				var g := goal[c]
				var any := next_to
				for v in nbs[g]:
					if owner[v] == EMPTY and hr.has(_region[v]):
						served[_region[v]] = 1
						any = true
				if not any:
					return false
			else:
				var any := next_to
				for r in hr:
					if seed_reg_hi.has(r):
						served[r] = 1
						any = true
				if not any:
					return false
		for r in regions:
			if not served[r]:
				return false
		return true
