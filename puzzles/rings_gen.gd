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
##
## **A move carries the run** (2026-10-16, the user's reference): the rings of
## one colour lying together on top of a peg go as one, as many of them as the
## peg they go to has room for; the rest stay where they were. So a move is
## still (from, to) -- how many rings it carries is the position's to say
## (`take`), and `apply` plays it.
##
## **A ring is an int**: its colour in the low three bits (0-7), and on
## Insane `HIDDEN` over it while it lies face down. Insane deals every ring
## under a peg's top face down; a ring turns face up for good the moment it is
## a peg's top, and a run stops at a face-down ring (the player cannot know
## it is the same colour, so the solver does not move it either). Every rule
## reads a ring through `top()`, so a face-down ring still counts toward its
## colour's lock.
## Spec: docs/superpowers/specs/2026-09-20-rings-flat-design.md, section 3.
## Concept page: docs/brainstorm/concepts.html#rings.

## Rings a peg holds when it is full. Four at every band; the colour count is
## what moves.
const CAP := 4

## Colours by band, and always two pegs' worth of slack -- eight free slots,
## spread over the deal rather than left as two empty pegs. Six over eight is
## the reference's own three a peg; the other two bands leave a peg or two one
## short, which is the arithmetic and not a choice.
## Hard is six colours on **seven** pegs since the 2026-10-01 polish.
## Insane (2026-10-16) is bigger and blind: eight colours on ten pegs, two
## rows of five, every ring under a top dealt face down (`hidden`).
const BANDS := [
	{"colours": 4, "pegs": 6},
	{"colours": 5, "pegs": 7},
	{"colours": 6, "pegs": 7},
	{"colours": 8, "pegs": 10, "hidden": true},
]

## A face-down ring: its colour with this bit over it.
const HIDDEN := 8

## Deals tried before the day gives up and takes the last one anyway. Hard on
## seven pegs (2026-10-01) needs up to ~30 tries for a proved deal and 40 ran
## out about once in 440 seeds -- a dead board on a judged band, where every
## drop would cost a heart. A failed proof costs a few hundred nodes, so 400
## tries is cheap and the fallback is never reached in practice.
const ATTEMPTS := 400

## Nodes a single verdict may cost.
const NODE_BUDGET := 20000

## A ring's colour as it lies, face up or down: what it is matched on.
static func top(c: int) -> int:
	return c & 7

## Whether a ring lies face down.
static func hidden(c: int) -> bool:
	return c & HIDDEN != 0

## The run on top of `peg`: the face-up rings of the top ring's colour lying
## together, counted down from the top. 0 on an empty peg.
static func run(peg: Array) -> int:
	var n := 0
	var col := -1
	for k in range(peg.size() - 1, -1, -1):
		var c := int(peg[k])
		if hidden(c) or (col >= 0 and top(c) != col):
			break
		col = top(c)
		n += 1
	return n

## How many rings a move from `src` onto `dst` carries: the run, or as many
## of it as `dst` has room for. 0 when nothing may go (an empty source, no
## room, another colour on top).
static func take(src: Array, dst: Array) -> int:
	var n := run(src)
	var room := CAP - dst.size()
	if n == 0 or room <= 0:
		return 0
	if not dst.is_empty() and top(int(dst.back())) != top(int(src.back())):
		return 0
	return mini(n, room)

## Plays (i -> j) on `pegs`: moves `take` rings, keeping their order, and
## turns the source's new top face up. Returns [rings moved, the code the
## source's new top had before it turned] ([0, -1] when nothing moved), which
## is what `unapply` needs.
static func apply(pegs: Array, i: int, j: int) -> Array:
	var src: Array = pegs[i]
	var dst: Array = pegs[j]
	var k := take(src, dst)
	if k == 0:
		return [0, -1]
	var start := src.size() - k
	for q in k:
		dst.append(src[start + q])
	src.resize(start)
	var was := -1
	if not src.is_empty():
		was = int(src.back())
		src[src.size() - 1] = top(was)
	return [k, was]

## Takes `apply` back exactly, face-down ring and all.
static func unapply(pegs: Array, i: int, j: int, done: Array) -> void:
	var k: int = done[0]
	if k == 0:
		return
	var src: Array = pegs[i]
	var dst: Array = pegs[j]
	if int(done[1]) >= 0:
		src[src.size() - 1] = int(done[1])
	var start := dst.size() - k
	for q in k:
		src.append(dst[start + q])
	dst.resize(start)

## The day's deal, proved solvable. `difficulty` is 0 to 3. Insane's rings
## under each top are dealt face down, and proved under that rule.
static func deal(rng: RandomNumberGenerator, difficulty: int) -> Array:
	var band: Dictionary = BANDS[clampi(difficulty, 0, BANDS.size() - 1)]
	var last: Array = []
	for attempt in ATTEMPTS:
		var pegs := _deal_once(rng, int(band["colours"]), int(band["pegs"]))
		if band.get("hidden", false):
			for peg: Array in pegs:
				for k in peg.size() - 1:
					peg[k] = int(peg[k]) | HIDDEN
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
		if not locked(s):
			return false
	return true

## A peg nothing comes off again: full and all one colour. Safe to forbid as a
## source rather than merely pointless -- a full monochrome peg is already
## where that colour belongs and has no free slot, so no solution can need to
## take rings off it.
static func locked(peg: Array) -> bool:
	if peg.size() != CAP:
		return false
	var c0 := top(int(peg[0]))
	for c in peg:
		if top(int(c)) != c0:
			return false
	return true

## The canonical key. A peg is (ring + 1) in six bits a ring (a face-down
## ring's code runs to 15); the codes are sorted, so two positions that
## differ only in which peg is which come out identical.
static func key(pegs: Array) -> String:
	var codes: Array[int] = []
	for s in pegs:
		var code := 0
		for k in s.size():
			code |= (int(s[k]) + 1) << (6 * k)
		codes.append(code)
	codes.sort()
	var out := ""
	for c in codes:
		out += str(c) + ","
	return out

## Every legal move from `pegs`, best first: a move that finishes a peg, then
## any other move onto a matching colour, then a move onto an empty peg. The
## ordering is what makes the search cheap. The prunings are only sound ones:
## a locked peg is never a source (the game's own rule), a peg that is one
## run and nothing else never moves onto an empty peg (the same position with
## the pegs renamed), and of several empty pegs only the first is tried
## (the same again).
static func moves_from(pegs: Array) -> Array:
	var scored: Array = []
	var empty := -1
	for j in pegs.size():
		if (pegs[j] as Array).is_empty():
			empty = j
			break
	for i in pegs.size():
		var src: Array = pegs[i]
		if src.is_empty() or locked(src):
			continue
		var n := run(src)
		var col := top(int(src.back()))
		for j in pegs.size():
			if i == j:
				continue
			var dst: Array = pegs[j]
			if dst.is_empty():
				if j != empty or n == src.size():
					continue
				scored.append([2, i, j])
				continue
			var k := take(src, dst)
			if k == 0:
				continue
			var finishes := dst.size() + k == CAP
			if finishes:
				for c in dst:
					if top(int(c)) != col:
						finishes = false
						break
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
	return _search(pegs, budget)["path"]

## 1 when `pegs` can still be sorted, 0 when the search proved it cannot (a
## doomed position: every line from it walked), -1 when it ran out of nodes
## first -- which the board treats as alive, so a heart is only ever taken
## for a proof.
static func verdict(pegs: Array, budget := NODE_BUDGET) -> int:
	var out := _search(pegs, budget)
	if not (out["path"] as Array).is_empty() or solved(pegs):
		return 1
	return 0 if int(out["nodes"]) <= budget else -1

static func _search(pegs: Array, budget: int) -> Dictionary:
	var work: Array = []
	for s in pegs:
		work.append((s as Array).duplicate())
	var seen := {}
	var path: Array[Vector2i] = []
	var nodes := [0]
	if _dfs(work, seen, path, nodes, budget):
		return {"path": path, "nodes": nodes[0]}
	return {"path": [] as Array[Vector2i], "nodes": nodes[0]}

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
		var done := apply(pegs, m.x, m.y)
		path.append(m)
		if _dfs(pegs, seen, path, nodes, budget):
			return true
		path.pop_back()
		unapply(pegs, m.x, m.y, done)
		if nodes[0] > budget:
			return false
	return false
