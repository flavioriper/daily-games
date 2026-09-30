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

## The field per band: easy, medium, hard, insane. Insane is Wish Tags on
## 8x8, dealt from the bank (`from_bank`); its row here is the size of the
## live fallback `build()` grows when the bank is empty or broken.
const SIZES := [5, 6, 7, 8]
## Wish Tags' field.
const TAGS_N := 8
## The fewest tags a Wish Tags garden keeps. Stripped all the way down, the
## no-loop and no-island rules carry most gardens on a single tag (median 1
## over the first bank), which leaves the tags invisible as a mechanic; the
## strip stops at this floor instead.
const TAGS_MIN := 4
## Trees `generate_tags` grows before it gives up and hands back `ok: false`.
## Mined off the phone, so this only bounds a bad seed.
const TAGS_BUDGET := 200
## Per side bit d: the set of the sixteen piece masks that have that side
## open, as a sixteen-bit set (bit m set when mask m opens side d). The tag
## solver's candidates are sets of piece masks in this same shape, so "every
## candidate agrees side d is open" is one AND.
const OPEN := [0xAAAA, 0xCCCC, 0xF0F0, 0xFF00]
const ALL16 := 0xFFFF
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
	var band: int = clampi(difficulty, 0, SIZES.size() - 1)
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

# ------------------------------------------------------------- Wish Tags
#
# Insane. Some lanterns wear a paper tag with a number on it: how many
# lengths of wire lie between that lantern and the post. The garden is 8x8
# and one the propagate-only solver above cannot finish -- without the tags
# it needs a guess or has more than one answer -- so the tags are the only
# way in. Mined off the phone (tools/insane/fairylights_ladder.gd) and dealt
# from content/insane/fairylights.json; `build()` at band 3 is the live
# fallback, a propagate-proved 8x8 with every lantern tagged (`all_tags`).
# Spec: docs/superpowers/specs/2026-09-30-fairylights-polish-design.md,
# section 2.

## How far every cell sits from the post along the tree's own wire: a
## breadth-first walk over sides open from both ends. -1 where the walk never
## arrives. Reads whatever masks it is handed -- the answer here, and the
## state's `depths()` is the same walk over the board as it stands.
static func tree_depths(n: int, post: int, masks: PackedInt32Array) -> PackedInt32Array:
	var cells := n * n
	var out := PackedInt32Array()
	out.resize(cells)
	out.fill(-1)
	if cells == 0 or post < 0 or post >= cells or masks.size() != cells:
		return out
	out[post] = 0
	var queue := PackedInt32Array([post])
	var head := 0
	while head < queue.size():
		var i: int = queue[head]
		head += 1
		var r: int = i / n
		var c: int = i % n
		for d in range(4):
			if masks[i] & (1 << d) == 0:
				continue
			var a: int = r + DR[d]
			var b: int = c + DC[d]
			if a < 0 or b < 0 or a >= n or b >= n:
				continue
			var j: int = a * n + b
			if out[j] != -1 or masks[j] & (1 << ((d + 2) % 4)) == 0:
				continue
			out[j] = out[i] + 1
			queue.append(j)
	return out

## Whether `masks` is a spanning tree over every cell, rooted at the post:
## no stub points off the grid or at a closed side, there are exactly
## cells - 1 edges, and the walk from the post reaches every cell -- which,
## with that edge count, also rules out a loop.
static func is_spanning_tree(n: int, post: int, masks: PackedInt32Array) -> bool:
	var cells := n * n
	if n < 2 or masks.size() != cells or post < 0 or post >= cells:
		return false
	var stubs := 0
	for i in cells:
		var m: int = masks[i]
		if m < 0 or m > 15:
			return false
		for d in range(4):
			if m & (1 << d) == 0:
				continue
			stubs += 1
			var a: int = i / n + DR[d]
			var b: int = i % n + DC[d]
			if a < 0 or b < 0 or a >= n or b >= n:
				return false
			if masks[a * n + b] & (1 << ((d + 2) % 4)) == 0:
				return false
	if stubs != 2 * (cells - 1):
		return false
	for v in tree_depths(n, post, masks):
		if v < 0:
			return false
	return true

## Every lantern tagged with its depth: the live fallback's tags, and where
## the miner starts before it strips.
static func all_tags(n: int, post: int, sol: PackedInt32Array) -> Dictionary:
	var dep := tree_depths(n, post, sol)
	var out := {}
	for i in n * n:
		if degree(sol[i]) == 1:
			out[i] = dep[i]
	return out

## The tag solver: the propagate-only rule above, plus three rules a player
## uses, plus -- only when those stall -- one supposition at a time.
##
## Candidates are sets of piece masks, one sixteen-bit set a cell (bit m for
## mask m; see OPEN). The rules, run to a fixpoint:
## - **propagate**: a side every candidate agrees on is proven, and the
##   neighbour is filtered to match (exactly `solvable()`).
## - **no loop**: two proven-open edges may not close a ring, and an
##   undecided edge between two cells already joined by proven-open wire is
##   closed.
## - **no island**: a group of cells joined by proven-open wire that is not
##   the whole garden must reach out; with no undecided edge leading out it
##   is a contradiction, with exactly one that edge is open.
## - **tags are distances**: a tagged lantern whose proven run holds the post
##   must sit at exactly its tag along it; otherwise the run has to leave by
##   an undecided edge, from a cell `k` steps along to a neighbour `g`, with
##   k + 1 + manhattan(g, post) <= tag and the same parity. None such is a
##   contradiction; exactly one is open.
##
## When the fixpoint stalls short of one candidate a cell, **suppositions**:
## for each cell still holding more than one, try each candidate alone,
## propagate, and strike it on a contradiction. Loop while a pass strikes
## anything. It never guesses: a candidate only goes when assuming it breaks
## a rule, so a finish is a proof the answer is unique.
##
## {"ok": finished at exactly `sol`, "rung": suppositions that struck a
## candidate, "work": candidates tried, and on a stall "left": the cells
## still holding more than one candidate}. `suppose` false stops at the
## fixpoint (rung and work 0).
static func solve_tags(n: int, post: int, sol: PackedInt32Array, tags: Dictionary,
		suppose := true) -> Dictionary:
	var cells := n * n
	var fail := {"ok": false, "rung": 0, "work": 0}
	if n < 2 or sol.size() != cells or post < 0 or post >= cells:
		return fail
	var nb := PackedInt32Array()
	nb.resize(cells * 4)
	var md := PackedInt32Array()
	md.resize(cells)
	var cand := PackedInt32Array()
	cand.resize(cells)
	var pr: int = post / n
	var pc: int = post % n
	for i in cells:
		var r: int = i / n
		var c: int = i % n
		md[i] = absi(r - pr) + absi(c - pc)
		var set := 0
		for m in rotations(sol[i]):
			set |= 1 << int(m)
		for d in range(4):
			var a: int = r + DR[d]
			var b: int = c + DC[d]
			if a < 0 or b < 0 or a >= n or b >= n:
				nb[i * 4 + d] = -1
				set &= ~int(OPEN[d])
			else:
				nb[i * 4 + d] = a * n + b
		if set == 0:
			return fail
		cand[i] = set
	var keys: Array = tags.keys()
	keys.sort()
	var tl := PackedInt32Array()
	var tv := PackedInt32Array()
	for k in keys:
		tl.append(int(k))
		tv.append(int(tags[k]))
	if not _tag_propagate(cells, nb, md, post, tl, tv, cand):
		return fail
	var rung := 0
	var work := 0
	while suppose and not _all_single(cand):
		var struck := false
		for i in cells:
			var rest: int = cand[i]
			if rest & (rest - 1) == 0:
				continue
			while rest != 0:
				var low: int = rest & -rest
				rest &= ~low
				var now: int = cand[i]
				if now & low == 0:
					continue
				if now & (now - 1) == 0:
					break
				work += 1
				var trial := cand.duplicate()
				trial[i] = low
				if _tag_propagate(cells, nb, md, post, tl, tv, trial):
					continue
				cand[i] = now & ~low
				rung += 1
				struck = true
				if not _tag_propagate(cells, nb, md, post, tl, tv, cand):
					return {"ok": false, "rung": rung, "work": work}
		if not struck:
			break
	if not _all_single(cand):
		var left := 0
		for c in cand:
			if c & (c - 1) != 0:
				left += 1
		return {"ok": false, "rung": rung, "work": work, "left": left}
	for i in cells:
		if cand[i] != 1 << sol[i]:
			# Every rule is meant to be sound, so the answer can never be
			# struck; landing anywhere else is a solver bug, not a board.
			push_error("Fairy Lights: the tag solver finished off the answer")
			return {"ok": false, "rung": rung, "work": work}
	return {"ok": true, "rung": rung, "work": work}

static func _all_single(cand: PackedInt32Array) -> bool:
	for c in cand:
		if c & (c - 1) != 0:
			return false
	return true

## The fixpoint of every rule. False on a contradiction.
static func _tag_propagate(cells: int, nb: PackedInt32Array, md: PackedInt32Array, post: int,
		tl: PackedInt32Array, tv: PackedInt32Array, cand: PackedInt32Array) -> bool:
	while true:
		if not _local(cells, nb, cand):
			return false
		var g := _global(cells, nb, md, post, tl, tv, cand)
		if g < 0:
			return false
		if g == 0:
			return true
	return true

## The propagate-only rule over a work stack: a cell whose candidates changed
## goes back on it, and its neighbours are filtered off it.
static func _local(cells: int, nb: PackedInt32Array, cand: PackedInt32Array) -> bool:
	var stack := PackedInt32Array()
	stack.resize(cells)
	var inq := PackedByteArray()
	inq.resize(cells)
	inq.fill(1)
	for i in cells:
		stack[i] = i
	var top := cells
	while top > 0:
		top -= 1
		var i: int = stack[top]
		inq[i] = 0
		var c: int = cand[i]
		for d in range(4):
			var j: int = nb[i * 4 + d]
			if j < 0:
				continue
			var o: int = OPEN[d]
			var cj: int = cand[j]
			var nj: int
			if c & ~o == 0:
				nj = cj & int(OPEN[(d + 2) & 3])
			elif c & o == 0:
				nj = cj & ~int(OPEN[(d + 2) & 3])
			else:
				continue
			if nj == cj:
				continue
			if nj == 0:
				return false
			cand[j] = nj
			if inq[j] == 0:
				inq[j] = 1
				if top < stack.size():
					stack[top] = j
				else:
					stack.append(j)
				top += 1
	return true

static func _find(parent: PackedInt32Array, x: int) -> int:
	var r := x
	while parent[r] != r:
		r = parent[r]
	while parent[x] != r:
		var nx: int = parent[x]
		parent[x] = r
		x = nx
	return r

## Opens edge `e` (cell * 4 + side) from both ends.
static func _force_open(nb: PackedInt32Array, cand: PackedInt32Array, e: int) -> void:
	var i: int = e >> 2
	var d: int = e & 3
	cand[i] &= int(OPEN[d])
	cand[nb[e]] &= int(OPEN[(d + 2) & 3])

## The loop, island and tag rules, read once off the proven-open wire. -1 a
## contradiction, 1 something was proven (run the propagate rule again), 0
## nothing new. Called only at the propagate rule's fixpoint, where both
## ends of an edge agree on it, so each edge is read from its west or north
## cell alone.
static func _global(cells: int, nb: PackedInt32Array, md: PackedInt32Array, post: int,
		tl: PackedInt32Array, tv: PackedInt32Array, cand: PackedInt32Array) -> int:
	var parent := PackedInt32Array()
	parent.resize(cells)
	for i in cells:
		parent[i] = i
	for i in cells:
		var c: int = cand[i]
		for d in [1, 2]:
			var j: int = nb[i * 4 + d]
			if j < 0:
				continue
			if c & ~int(OPEN[d]) == 0:
				var a := _find(parent, i)
				var b := _find(parent, j)
				if a == b:
					return -1
				parent[a] = b
	# No loop: an undecided edge inside one run is closed.
	var changed := false
	var exits := PackedInt32Array()
	exits.resize(cells)
	exits.fill(0)
	var exit_edge := PackedInt32Array()
	exit_edge.resize(cells)
	var size := PackedInt32Array()
	size.resize(cells)
	size.fill(0)
	for i in cells:
		size[_find(parent, i)] += 1
	for i in cells:
		var c: int = cand[i]
		for d in [1, 2]:
			var j: int = nb[i * 4 + d]
			if j < 0:
				continue
			var o: int = OPEN[d]
			if c & o == 0 or c & ~o == 0:
				continue
			var a := _find(parent, i)
			var b := _find(parent, j)
			if a == b:
				c &= ~o
				cand[i] = c
				cand[j] &= ~int(OPEN[(d + 2) & 3])
				changed = true
				continue
			exits[a] += 1
			exit_edge[a] = i * 4 + d
			exits[b] += 1
			exit_edge[b] = j * 4 + ((d + 2) & 3)
	if changed:
		return 1
	# No island: a run that is not the whole garden has to reach out.
	for r in cells:
		if parent[r] != r or size[r] == cells:
			continue
		if exits[r] == 0:
			return -1
		if exits[r] == 1:
			_force_open(nb, cand, exit_edge[r])
			changed = true
	if changed:
		return 1
	# Tags are distances.
	var dist := PackedInt32Array()
	dist.resize(cells)
	dist.fill(-1)
	var queue := PackedInt32Array()
	for k in tl.size():
		var lantern: int = tl[k]
		var tag: int = tv[k]
		queue.resize(0)
		queue.append(lantern)
		dist[lantern] = 0
		var head := 0
		var at_post := -1
		var valid := 0
		var last := -1
		while head < queue.size():
			var i: int = queue[head]
			head += 1
			var here: int = dist[i]
			if i == post:
				at_post = here
			var c: int = cand[i]
			for d in range(4):
				var j: int = nb[i * 4 + d]
				if j < 0:
					continue
				var o: int = OPEN[d]
				if c & ~o == 0:
					if dist[j] < 0:
						dist[j] = here + 1
						queue.append(j)
				elif c & o != 0:
					var need: int = here + 1 + md[j]
					if need <= tag and (tag - need) & 1 == 0:
						valid += 1
						last = i * 4 + d
		for q in queue:
			dist[q] = -1
		if at_post >= 0:
			if at_post != tag:
				return -1
			continue
		if valid == 0:
			return -1
		if valid == 1:
			_force_open(nb, cand, last)
			changed = true
	return 1 if changed else 0

## One Wish Tags garden, grown on the Mac by the miner: an 8x8 Prim tree
## neither the propagate-only solver nor the tag solver with no tags can
## finish, every lantern tagged, the tag solver
## made to finish it, then tags stripped one at a time in a seeded order,
## each removal kept only while the tag solver still finishes, stopping at
## TAGS_MIN (a garden with fewer lanterns keeps them all). Scrambled as
## every band is. {"n", "post", "sol", "deal", "tags" (cell -> depth),
## "rung", "work", "attempts", "ok"}; `ok` false when TAGS_BUDGET trees all
## failed (the last one grown rides along untagged, never to be banked).
static func generate_tags(rng: RandomNumberGenerator) -> Dictionary:
	var n := TAGS_N
	var lo: int = (n - 1) / 2
	var hi: int = int(ceil((n - 1) / 2.0))
	var post: int = rng.randi_range(lo, hi) * n + rng.randi_range(lo, hi)
	var attempts := 0
	var sol := PackedInt32Array()
	while attempts < TAGS_BUDGET:
		attempts += 1
		sol = _tree(rng, n, post)
		var lanterns := 0
		for m in sol:
			if degree(m) == 1:
				lanterns += 1
		if lanterns < int(ceil(n * n * LANTERN_SHARE)) or degree(sol[post]) < 2:
			continue
		# The ordinary rules must not be enough: that is Hard's garden. Nor
		# may the player's own rules with no tag at all -- no loop, no
		# island, suppositions -- or the tags are decoration. Only about one
		# Prim tree in sixteen at 8x8 has more than one answer those rules
		# cannot tell apart, which is the garden the tags are for.
		if solvable(n, sol) or bool(solve_tags(n, post, sol, {}).ok):
			continue
		var tags := all_tags(n, post, sol)
		if not bool(solve_tags(n, post, sol, tags).ok):
			continue
		var order: Array = tags.keys()
		order.sort()
		for k in range(order.size() - 1, 0, -1):
			var s := rng.randi_range(0, k)
			var t = order[k]
			order[k] = order[s]
			order[s] = t
		for cell in order:
			if tags.size() <= TAGS_MIN:
				break
			var depth: int = tags[cell]
			tags.erase(cell)
			if not bool(solve_tags(n, post, sol, tags).ok):
				tags[cell] = depth
		var proof := solve_tags(n, post, sol, tags)
		return {"n": n, "post": post, "sol": sol, "deal": _scramble(rng, n, post, sol),
			"tags": tags, "rung": int(proof.rung), "work": int(proof.work),
			"attempts": attempts, "ok": true}
	return {"n": n, "post": post, "sol": sol, "deal": _scramble(rng, n, post, sol),
		"tags": {}, "rung": 0, "work": 0, "attempts": attempts, "ok": false}

## A Wish Tags garden in the bank's plain-JSON shape: the masks as arrays and
## the tags as [cell, depth] pairs in cell order. {} for a failed grow.
static func to_bank(board: Dictionary) -> Dictionary:
	if board.is_empty() or not bool(board.get("ok", false)):
		return {}
	var keys: Array = board.tags.keys()
	keys.sort()
	var pairs: Array = []
	for k in keys:
		pairs.append([int(k), int(board.tags[k])])
	return {"n": int(board.n), "post": int(board.post), "sol": Array(board.sol),
		"deal": Array(board.deal), "tags": pairs}

## A banked garden back in `build()`'s shape plus its tags, **checked the way
## the phone can afford**: `sol` is a spanning tree over n*n rooted at the
## post, every tag sits on a lantern and equals its depth in `sol`, and every
## dealt piece is a rotation of its own answer. That the tags pin the answer
## down is the miner's proof and is trusted. {} when any of it fails (a value
## of the wrong type included), and the board grows a live one instead.
static func from_bank(entry: Dictionary) -> Dictionary:
	if entry.is_empty() or not _is_num(entry.get("n")) or not _is_num(entry.get("post")) \
			or not (entry.get("sol") is Array) or not (entry.get("deal") is Array) \
			or not (entry.get("tags") is Array):
		return {}
	var n := int(entry.n)
	var post := int(entry.post)
	if n < 2 or n > 12:
		return {}
	var cells := n * n
	var sol := _masks(entry.sol, cells)
	var deal := _masks(entry.deal, cells)
	if sol.is_empty() or deal.is_empty() or not is_spanning_tree(n, post, sol):
		return {}
	for i in cells:
		if not rotations(sol[i]).has(deal[i]):
			return {}
	var dep := tree_depths(n, post, sol)
	var tags := {}
	for pair in entry.tags:
		if not (pair is Array) or pair.size() != 2 or not _is_num(pair[0]) or not _is_num(pair[1]):
			return {}
		var cell := int(pair[0])
		if cell < 0 or cell >= cells or tags.has(cell) or degree(sol[cell]) != 1 \
				or int(pair[1]) != dep[cell]:
			return {}
		tags[cell] = dep[cell]
	if tags.is_empty():
		return {}
	return {"n": n, "post": post, "sol": sol, "deal": deal, "tags": tags,
		"attempts": 0, "proved": true}

## A bank array of `cells` piece masks, or empty when any value is not one.
static func _masks(values: Array, cells: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	if values.size() != cells:
		return out
	for v in values:
		if not _is_num(v) or float(v) != floorf(float(v)) or int(v) < 0 or int(v) > 15:
			return PackedInt32Array()
		out.append(int(v))
	return out

## Whether a bank value is a number (JSON reads every number as a float).
static func _is_num(v: Variant) -> bool:
	return v is int or v is float
