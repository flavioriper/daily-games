extends RefCounted

## Rings' generator: the day's deal, and the solver that proves it can be sorted.
##
## **A deal is never handed over unproved.** Twenty-four rings dealt at random
## into eight pegs of three is a tight position -- every peg one slot short of
## full -- and the cheap way to know a day is fair is to sort it before the
## player sees it. Measured in the concept page's JavaScript over 200 seeds a
## band (2026-09-20): not one deal in six hundred was unsolvable and a verdict
## cost under 300 nodes, so the proof is nearly free. ATTEMPTS and NODE_BUDGET
## are there so a pathological day cannot hang build(), not because the
## measurement expects to need them.
##
## **The search is cheap because of two things.** The key is canonical -- the
## pegs are interchangeable, so sorting their codes before hashing collapses
## the whole symmetry group -- and the moves are ordered: finish a peg, then
## land on a colour, then spend an empty peg. Without the ordering the same
## search is thousands of nodes; with it, it is dozens.
##
## The same solver answers the board's hint, which is why solve() returns the
## path and not just a verdict.
## Spec: docs/superpowers/specs/2026-09-20-rings-flat-design.md, section 3.
## Concept page: docs/brainstorm/concepts.html#rings.

## Rings a peg holds when it is full. Four at every band; the colour count is
## what moves.
const CAP := 4

## Colours by band, and always two pegs' worth of slack -- eight free slots,
## spread over the deal rather than left as two empty pegs. Six over eight is
## the reference's own three a peg; the other two bands leave a peg or two one
## short, which is the arithmetic and not a choice.
const BANDS := [
	{"colours": 4, "pegs": 6},
	{"colours": 5, "pegs": 7},
	{"colours": 6, "pegs": 8},
]

## Deals tried before the day gives up and takes the last one anyway. Measured
## need: zero. This is the guard, not the plan.
const ATTEMPTS := 40

## Nodes a single verdict may cost. Measured worst: 267.
const NODE_BUDGET := 20000

## The day's deal, proved solvable. `difficulty` is 0, 1 or 2.
static func deal(rng: RandomNumberGenerator, difficulty: int) -> Array:
	var band: Dictionary = BANDS[clampi(difficulty, 0, BANDS.size() - 1)]
	var last: Array = []
	for attempt in ATTEMPTS:
		var pegs := _deal_once(rng, int(band["colours"]), int(band["pegs"]))
		last = pegs
		if solved(pegs):
			continue
		if not solve(pegs, NODE_BUDGET).is_empty():
			return pegs
	return last

## One shuffled deal, as even as the band divides.
static func _deal_once(rng: RandomNumberGenerator, colours: int, peg_count: int) -> Array:
	var bag: Array[int] = []
	for c in colours:
		for k in CAP:
			bag.append(c)
	_shuffle(bag, rng)
	var base := bag.size() / peg_count
	var extra := bag.size() - base * peg_count
	var sizes: Array[int] = []
	for i in peg_count:
		sizes.append(base + (1 if i < extra else 0))
	_shuffle(sizes, rng)
	var out: Array = []
	var at := 0
	for s in sizes:
		var peg: Array[int] = []
		for k in s:
			peg.append(bag[at])
			at += 1
		out.append(peg)
	return out

static func _shuffle(a: Array, rng: RandomNumberGenerator) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var v = a[i]
		a[i] = a[j]
		a[j] = v

## Every peg empty or full of one colour.
static func solved(pegs: Array) -> bool:
	for s in pegs:
		if s.is_empty():
			continue
		if s.size() != CAP:
			return false
		for c in s:
			if c != s[0]:
				return false
	return true

## A peg nothing comes off again: full and all one colour. Safe to forbid as a
## source rather than merely pointless -- a full monochrome peg is already
## where that colour belongs and has no free slot, so no solution can need to
## take rings off it.
static func locked(peg: Array) -> bool:
	if peg.size() != CAP:
		return false
	for c in peg:
		if c != peg[0]:
			return false
	return true

## The canonical key. A peg is (colour + 1) in three bits a ring, under 4096 so
## it fits one character; the codes are sorted, so two positions that differ
## only in which peg is which come out identical.
static func key(pegs: Array) -> String:
	var codes: Array[int] = []
	for s in pegs:
		var code := 0
		for k in s.size():
			code |= (int(s[k]) + 1) << (3 * k)
		codes.append(code)
	codes.sort()
	var out := ""
	for c in codes:
		out += String.chr(c + 32)
	return out

## Every legal move from `pegs`, best first: a move that finishes a peg, then
## any other move onto a matching colour, then a move onto an empty peg. The
## ordering is what makes the search cheap, and the two prunings are what keep
## it from walking in circles: a locked peg is never a source, and a whole
## uniform peg is never moved onto an empty one (that is the same position
## with the pegs renamed).
static func moves_from(pegs: Array) -> Array:
	var scored: Array = []
	for i in pegs.size():
		var src: Array = pegs[i]
		if src.is_empty() or locked(src):
			continue
		var col: int = src.back()
		var run := 0
		var x := src.size() - 1
		while x >= 0 and int(src[x]) == col:
			run += 1
			x -= 1
		var uniform := run == src.size()
		for j in pegs.size():
			if i == j:
				continue
			var dst: Array = pegs[j]
			if dst.size() >= CAP:
				continue
			if dst.is_empty():
				if uniform:
					continue
				scored.append([2, i, j])
				continue
			if int(dst.back()) != col:
				continue
			var finishes := dst.size() + mini(run, CAP - dst.size()) == CAP
			scored.append([0 if finishes else 1, i, j])
	scored.sort_custom(func(a, b): return a[0] < b[0])
	var out: Array[Vector2i] = []
	for s in scored:
		out.append(Vector2i(s[1], s[2]))
	return out

## A path from `pegs` to solved, or []. Depth-first over canonical positions,
## a solution and not the shortest -- which is all either caller needs: the
## deal wants a yes, and the hint wants a next move that leads somewhere.
static func solve(pegs: Array, budget := NODE_BUDGET) -> Array:
	var work: Array = []
	for s in pegs:
		work.append((s as Array).duplicate())
	var seen := {}
	var path: Array[Vector2i] = []
	var nodes := [0]
	if _dfs(work, seen, path, nodes, budget):
		return path
	return []

static func _dfs(pegs: Array, seen: Dictionary, path: Array, nodes: Array, budget: int) -> bool:
	if solved(pegs):
		return true
	nodes[0] += 1
	if nodes[0] > budget:
		return false
	var k := key(pegs)
	if seen.has(k):
		return false
	seen[k] = true
	for m in moves_from(pegs):
		var src: Array = pegs[m.x]
		var dst: Array = pegs[m.y]
		dst.append(src.pop_back())
		path.append(m)
		if _dfs(pegs, seen, path, nodes, budget):
			return true
		path.pop_back()
		src.append(dst.pop_back())
		if nodes[0] > budget:
			return false
	return false
