extends RefCounted

## Fairy Lights' garden: the day's spanning tree, the propagate-only solver
## that proves the tree needs no guess, and the scramble that deals it dark.
## No state and no scene -- every entry point is static, and everything comes
## off the `rng` handed in and nothing else, so a day is the same garden on
## every phone.
##
## A piece is four bits, one a side: N=1, E=2, S=4, W=8, clockwise from
## north. A quarter turn clockwise is one bit rotate, which is the whole of
## the move, and a piece's shape is nothing but its degree in the tree -- 1 a
## lantern on a stub, 2 a straight or an elbow, 3 a tee, 4 a cross.
##
## **The tree is randomised Prim, not a depth-first walk**, and that choice is
## the whole cost of this file. A DFS tree is almost always guess-free first
## try, because it grows long corridors and a corridor is straights and a
## straight has only two rotations to begin with -- but it leaves only
## 13.6-17.1% of the field as lanterns, a snake of wire with a dozen lights
## on it, which is not a garden of fairy lights. Prim branches, which is
## where the lanterns, the tees and the crosses come from (35.2-37.9% of
## cells), and it costs a re-roll about a quarter of the time. Paying the
## re-rolls is the call; the numbers are in the spec's section 4.2.
##
## **The promise belongs to the tree and not to the scramble.** A scramble
## hides the answer; it cannot make the board harder to deduce. So the
## acceptance test runs on the bare tree, before anything is turned, and a
## tree that fails is thrown away whole.
## Spec: docs/superpowers/specs/2026-09-20-fairy-lights-flat-design.md,
## section 4.

## The four sides, clockwise from north.
const N := 1
const E := 2
const S := 4
const W := 8
## Row and column steps per side bit, indexed by the bit's position.
const DR := [-1, 0, 1, 0]
const DC := [0, 1, 0, -1]

## The field per band: easy, medium, hard.
const SIZES := [5, 6, 7]
## Trees grown before the promise is given up on. Never approached in the
## 6,000 boards the spec measured (worst 8, at 7x7); it exists only so a
## pathological seed cannot hang the board opening, the way Sudoku's time
## budget does. Past it the last tree grown is shipped with `proved: false`,
## and on such a board "every cell is live" is doing real work in the solved
## rule rather than merely restating "every stub meets a stub".
const BUDGET := 400
## How much of the field a garden wants as lanterns. Below this a Prim tree
## reads as wire rather than as lights.
const LANTERN_SHARE := 0.22
## Deals tried before the best one seen is shipped. Both conditions below
## are cheap to satisfy, so this is a ceiling and not a plan.
const SCRAMBLE_TRIES := 200
## How many of the turnable pieces have to be out of place. A deal that came
## out mostly right is thrown away rather than shipped.
const WRONG_SHARE := 0.6
## How much of the garden may already be live when it opens. New in the
## spec's section 4.5 and added to the mock in the same commit: the opening
## frame is the one that has to say *this is a dark garden and the post is
## where the power is*, and without a ceiling one 6x6 seed opened with a
## third of the field already gold.
const LIVE_SHARE := 0.25

## A clockwise quarter turn.
static func cw(m: int) -> int:
	return ((m << 1) | (m >> 3)) & 15

## A counter-clockwise quarter turn. Nothing on the board taps this way --
## it is the undo of a tap, and the solver's own arithmetic.
static func ccw(m: int) -> int:
	return ((m >> 1) | (m << 3)) & 15

## The distinct rotations of a mask, and therefore the candidates a cell
## starts the solve with: a stub four, an elbow four, a tee four, a straight
## **two**, a cross **one**.
static func rotations(m: int) -> Array:
	var out: Array = []
	var x := m
	for i in range(4):
		if not out.has(x):
			out.append(x)
		x = cw(x)
	return out

static func degree(m: int) -> int:
	return (m & 1) + ((m >> 1) & 1) + ((m >> 2) & 1) + ((m >> 3) & 1)

## The propagate-only solver, and the whole of the promise.
##
## Each cell starts with the distinct rotations of its own shape. An edge to
## off-grid is closed, so any candidate pointing into the wall is struck out.
## Whenever every remaining candidate of a cell agrees about a side, that
## side is proven open or closed and the neighbour's candidates are filtered
## to match. Iterate to a fixpoint. Every cell down to one candidate means no
## guess is ever needed -- and the one candidate is the answer, because the
## answer was in the set to begin with and filtering only ever removes what
## cannot be.
##
## **It never branches**, and it is deliberately weaker than a good player:
## it does not reason "that would make a loop" or "that would strand a
## corner", which a human does constantly. Weaker is the point. A board this
## solver can finish is a board nobody has to guess on, with room to spare.
static func solvable(n: int, sol: PackedInt32Array) -> bool:
	var cells := n * n
	var cand: Array = []
	cand.resize(cells)
	for i in range(cells):
		cand[i] = rotations(sol[i])
	var changed := true
	# The fixpoint is reached in a handful of sweeps; this only bounds a bug.
	var guard := 0
	while changed and guard < BUDGET:
		guard += 1
		changed = false
		for i in range(cells):
			var r: int = i / n
			var c: int = i % n
			for d in range(4):
				var a: int = r + DR[d]
				var b: int = c + DC[d]
				var ci: Array = cand[i]
				if a < 0 or b < 0 or a >= n or b >= n:
					var keep: Array = []
					for m in ci:
						if m & (1 << d) == 0:
							keep.append(m)
					if keep.size() != ci.size():
						cand[i] = keep
						changed = true
					if keep.is_empty():
						return false
					continue
				var j: int = a * n + b
				var od: int = (d + 2) % 4
				var all_open := true
				var none_open := true
				for m in ci:
					if m & (1 << d) != 0:
						none_open = false
					else:
						all_open = false
				if not (all_open or none_open):
					continue
				var cj: Array = cand[j]
				var keep_j: Array = []
				for m in cj:
					var open_back: bool = m & (1 << od) != 0
					if open_back == all_open:
						keep_j.append(m)
				if keep_j.size() != cj.size():
					cand[j] = keep_j
					changed = true
				if keep_j.is_empty():
					return false
	for x in cand:
		if x.size() != 1:
			return false
	return true

## The day's garden. `difficulty` is 0, 1 or 2; everything random comes off
## `rng`. Hands back the grid size, the post's cell, the tree the solver
## proved, the dealt board, how many trees were grown and whether the promise
## was actually kept.
static func build(rng: RandomNumberGenerator, difficulty: int) -> Dictionary:
	var band: int = clampi(difficulty, 0, 2)
	var n: int = SIZES[band]
	var cells := n * n
	# The middle cell. An even side has four of them; the seed picks one.
	var lo: int = (n - 1) / 2
	var hi: int = int(ceil((n - 1) / 2.0))
	var post: int = rng.randi_range(lo, hi) * n + rng.randi_range(lo, hi)
	var sol := PackedInt32Array()
	var attempts := 0
	var proved := false
	while attempts < BUDGET:
		attempts += 1
		sol = _tree(rng, n, post)
		if _accept(n, post, sol):
			proved = true
			break
	# The budget ran out: play the last tree grown rather than block the
	# board opening.
	return {
		"n": n,
		"post": post,
		"sol": sol,
		"deal": _scramble(rng, n, post, sol),
		"attempts": attempts,
		"proved": proved,
	}

## A spanning tree over every cell, rooted at the post, by randomised Prim:
## hold every edge out of the reached set and take one at random. The
## frontier is a flat array of `cell * 4 + side` and an exhausted entry is
## swapped in from the end rather than spliced out -- the pick is uniform
## over the set either way, and the set is what matters.
static func _tree(rng: RandomNumberGenerator, n: int, post: int) -> PackedInt32Array:
	var cells := n * n
	var mask := PackedInt32Array()
	mask.resize(cells)
	mask.fill(0)
	var seen := PackedByteArray()
	seen.resize(cells)
	seen.fill(0)
	var front := PackedInt32Array()
	seen[post] = 1
	_push(front, n, post, seen)
	while front.size() > 0:
		var k := rng.randi_range(0, front.size() - 1)
		var e: int = front[k]
		front[k] = front[front.size() - 1]
		front.resize(front.size() - 1)
		var i: int = e >> 2
		var d: int = e & 3
		var j: int = (i / n + DR[d]) * n + (i % n + DC[d])
		if seen[j] == 1:
			continue
		mask[i] |= 1 << d
		mask[j] |= 1 << ((d + 2) % 4)
		seen[j] = 1
		_push(front, n, j, seen)
	return mask

static func _push(front: PackedInt32Array, n: int, i: int, seen: PackedByteArray) -> void:
	var r: int = i / n
	var c: int = i % n
	for d in range(4):
		var a: int = r + DR[d]
		var b: int = c + DC[d]
		if a < 0 or b < 0 or a >= n or b >= n:
			continue
		if seen[a * n + b] == 0:
			front.append(i * 4 + d)

## Two rules on the look, and then the promise. A field with too few lanterns
## is a snake of wire, and a post with one arm reads as broken rather than as
## the one place the power comes from.
static func _accept(n: int, post: int, mask: PackedInt32Array) -> bool:
	var lanterns := 0
	for m in mask:
		if degree(m) == 1:
			lanterns += 1
	if lanterns < int(ceil(n * n * LANTERN_SHARE)):
		return false
	if degree(mask[post]) < 2:
		return false
	return solvable(n, mask)

## The deal. A cross is already every way round, so it is left where it
## stands; everything else takes a random rotation. Two conditions, each
## re-rolled rather than shipped: enough of the turnable pieces out of place
## that the board is not most of the way solved at the deal, and little
## enough of it live that the garden opens dark. Neither is hard to meet, so
## the loop is capped and the least-bad deal seen is taken rather than
## spinning; shipping *something* beats blocking the board.
static func _scramble(rng: RandomNumberGenerator, n: int, post: int, sol: PackedInt32Array) -> PackedInt32Array:
	var cells := n * n
	var turnable := 0
	var rots: Array = []
	rots.resize(cells)
	for i in range(cells):
		var rs: Array = rotations(sol[i])
		rots[i] = rs
		if rs.size() > 1:
			turnable += 1
	var want_wrong: int = int(ceil(turnable * WRONG_SHARE))
	var live_cap: int = int(cells * LIVE_SHARE)
	var best := PackedInt32Array()
	var best_miss := -1
	for _try in range(SCRAMBLE_TRIES):
		var deal := PackedInt32Array()
		deal.resize(cells)
		var wrong := 0
		for i in range(cells):
			var rs: Array = rots[i]
			deal[i] = sol[i] if rs.size() == 1 else rs[rng.randi_range(0, rs.size() - 1)]
			if deal[i] != sol[i]:
				wrong += 1
		var lit := _live(n, post, deal)
		var miss: int = maxi(0, want_wrong - wrong) + maxi(0, lit - live_cap)
		if miss == 0:
			return deal
		if best_miss < 0 or miss < best_miss:
			best_miss = miss
			best = deal
	return best

## How many cells a breadth-first walk from the post reaches over sides that
## are open from both ends. The board derives live the same way after every
## turn and stores nothing; here it is only ever asked about a fresh deal.
static func _live(n: int, post: int, cur: PackedInt32Array) -> int:
	var cells := n * n
	var seen := PackedByteArray()
	seen.resize(cells)
	seen.fill(0)
	var queue := PackedInt32Array([post])
	seen[post] = 1
	var head := 0
	var lit := 1
	while head < queue.size():
		var i: int = queue[head]
		head += 1
		var r: int = i / n
		var c: int = i % n
		for d in range(4):
			if cur[i] & (1 << d) == 0:
				continue
			var a: int = r + DR[d]
			var b: int = c + DC[d]
			if a < 0 or b < 0 or a >= n or b >= n:
				continue
			var j: int = a * n + b
			if seen[j] == 1:
				continue
			if cur[j] & (1 << ((d + 2) % 4)) == 0:
				continue
			seen[j] = 1
			lit += 1
			queue.append(j)
	return lit
