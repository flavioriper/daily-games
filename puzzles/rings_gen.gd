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
## **A ring is an int**: its colour, 0 to the band's colours less one. Insane
## dealt face-down rings from 2026-10-16 to 2026-10-26; the user had them
## taken out ("remove the hidden feature on insane and just make it with
## more colors, taller and harder"), so every ring lies face up again.
##
## **A deal is full pegs and empty ones** (2026-10-26, the made-fun pass):
## every colour's rings shuffled into pegs filled to the top, and two empty
## pegs beside them -- the sort games' own deal, where the empty pegs are
## the whole resource. Until then two pegs' worth of room was spread over
## every peg, which left a slot on top of nearly everything and runs dealt
## ready-made: a board with no pinch in it. No ring is dealt on one of its
## own colour (`_tangled`), so nothing starts as a run.
## Spec: docs/superpowers/specs/2026-09-20-rings-flat-design.md, section 3.
## Concept page: docs/brainstorm/concepts.html#rings.

## Rings a peg holds when it is full: four on Easy, the tutorial and the menu
## card, and taller towers up the bands since 2026-10-16 (the user: "add
## bigger towers, not just the same fixed amount of piles") -- each band's
## `cap`, passed to every rule below.
const CAP := 4

## Colours by band, each peg `cap` rings tall, and `spare` empty pegs.
## The 2026-10-26 pass made every band a full-peg deal with two empty pegs
## (the sort games' own climb runs from three colours on five pegs to six on
## eight) and Insane the biggest: ten colours on twelve pegs, seven high, in
## two rows of six.
const BANDS := [
	{"colours": 4, "cap": 4, "spare": 2},
	{"colours": 5, "cap": 5, "spare": 2},
	{"colours": 6, "cap": 6, "spare": 2},
	{"colours": 10, "cap": 7, "spare": 2},
]

## Deals tried before the day gives up and takes the last one anyway. Hard on
## seven pegs (2026-10-01) needs up to ~30 tries for a proved deal and 40 ran
## out about once in 440 seeds -- a dead board on a judged band, where every
## drop would cost a heart. A failed proof costs a few hundred nodes, so 400
## tries is cheap and the fallback is never reached in practice.
const ATTEMPTS := 400

## Nodes a single verdict may cost.
const NODE_BUDGET := 20000

## A ring's colour: what it is matched on (the ring itself since the
## face-down rings went).
static func top(c: int) -> int:
	return c

## The run on top of `peg`: the rings of the top ring's colour lying
## together, counted down from the top. 0 on an empty peg.
static func run(peg: Array) -> int:
	var n := 0
	var col := -1
	for k in range(peg.size() - 1, -1, -1):
		var c := int(peg[k])
		if col >= 0 and c != col:
			break
		col = c
		n += 1
	return n

## How many rings a move from `src` onto `dst` carries: the run, or as many
## of it as `dst` has room for. 0 when nothing may go (an empty source, no
## room, another colour on top).
static func take(src: Array, dst: Array, cap := CAP) -> int:
	var n := run(src)
	var room := cap - dst.size()
	if n == 0 or room <= 0:
		return 0
	if not dst.is_empty() and top(int(dst.back())) != top(int(src.back())):
		return 0
	return mini(n, room)

## Plays (i -> j) on `pegs`: moves `take` rings, keeping their order.
## Returns [rings moved, -1] ([0, -1] when nothing moved), which is what
## `unapply` needs.
static func apply(pegs: Array, i: int, j: int, cap := CAP) -> Array:
	var src: Array = pegs[i]
	var dst: Array = pegs[j]
	var k := take(src, dst, cap)
	if k == 0:
		return [0, -1]
	var start := src.size() - k
	for q in k:
		dst.append(src[start + q])
	src.resize(start)
	return [k, -1]

## Takes `apply` back exactly.
static func unapply(pegs: Array, i: int, j: int, done: Array) -> void:
	var k: int = done[0]
	if k == 0:
		return
	var src: Array = pegs[i]
	var dst: Array = pegs[j]
	var start := dst.size() - k
	for q in k:
		src.append(dst[start + q])
	dst.resize(start)

## Pegs a band stands: a full one a colour and its spare empty ones.
static func pegs_for(band: Dictionary) -> int:
	return int(band["colours"]) + int(band.get("spare", 2))

## The day's deal, proved solvable. `difficulty` is 0 to 3.
static func deal(rng: RandomNumberGenerator, difficulty: int) -> Array:
	var band: Dictionary = BANDS[clampi(difficulty, 0, BANDS.size() - 1)]
	var last: Array = []
	var cap: int = band.get("cap", CAP)
	for attempt in ATTEMPTS:
		var pegs := _deal_once(rng, int(band["colours"]), int(band.get("spare", 2)), cap)
		last = pegs
		if solved(pegs, cap):
			continue
		if not solve(pegs, NODE_BUDGET, cap).is_empty():
			return pegs
	return last

## One shuffled deal: every colour's rings into full pegs, no ring on one of
## its own colour, and `spare` empty pegs after them.
static func _deal_once(rng: RandomNumberGenerator, colours: int, spare: int, cap := CAP) -> Array:
	var bag: Array[int] = []
	for c in colours:
		for k in cap:
			bag.append(c)
	_shuffle(bag, rng)
	_untangle(bag, cap, rng)
	var out: Array = []
	for i in colours:
		var peg: Array[int] = []
		for k in cap:
			peg.append(bag[i * cap + k])
		out.append(peg)
	for i in spare:
		out.append([] as Array[int])
	return out

## Whether ring `at` of the bag, cut into pegs of `cap`, lies on a ring of
## its own colour or carries one.
static func _tangled(bag: Array, at: int, cap: int) -> bool:
	var k := at % cap
	if k > 0 and bag[at - 1] == bag[at]:
		return true
	return k < cap - 1 and at + 1 < bag.size() and bag[at + 1] == bag[at]

## Swaps rings until none lies on its own colour: a ring that does trades
## places with one picked at random where neither would. Bounded; a bag it
## cannot clear (never seen with three colours or more) is left as it is.
static func _untangle(bag: Array, cap: int, rng: RandomNumberGenerator) -> void:
	for pass_n in 200:
		var clean := true
		for at in bag.size():
			if not _tangled(bag, at, cap):
				continue
			clean = false
			for tries in 40:
				var other := rng.randi_range(0, bag.size() - 1)
				if bag[other] == bag[at]:
					continue
				var v = bag[at]
				bag[at] = bag[other]
				bag[other] = v
				if _tangled(bag, at, cap) or _tangled(bag, other, cap):
					bag[other] = bag[at]
					bag[at] = v
					continue
				break
		if clean:
			return

static func _shuffle(a: Array, rng: RandomNumberGenerator) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var v = a[i]
		a[i] = a[j]
		a[j] = v

## Every peg empty or full of one colour.
static func solved(pegs: Array, cap := CAP) -> bool:
	for s in pegs:
		if s.is_empty():
			continue
		if not locked(s, cap):
			return false
	return true

## A peg nothing comes off again: full and all one colour. Safe to forbid as a
## source rather than merely pointless -- a full monochrome peg is already
## where that colour belongs and has no free slot, so no solution can need to
## take rings off it.
static func locked(peg: Array, cap := CAP) -> bool:
	if peg.size() != cap:
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
static func moves_from(pegs: Array, cap := CAP) -> Array:
	var scored: Array = []
	var empty := -1
	for j in pegs.size():
		if (pegs[j] as Array).is_empty():
			empty = j
			break
	for i in pegs.size():
		var src: Array = pegs[i]
		if src.is_empty() or locked(src, cap):
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
			var k := take(src, dst, cap)
			if k == 0:
				continue
			var finishes := dst.size() + k == cap
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
static func solve(pegs: Array, budget := NODE_BUDGET, cap := CAP) -> Array:
	return _search(pegs, budget, cap)["path"]

## 1 when `pegs` can still be sorted, 0 when the search proved it cannot (a
## doomed position: every line from it walked), -1 when it ran out of nodes
## first.
static func verdict(pegs: Array, budget := NODE_BUDGET, cap := CAP) -> int:
	var out := _search(pegs, budget, cap)
	if not (out["path"] as Array).is_empty() or solved(pegs, cap):
		return 1
	return 0 if int(out["nodes"]) <= budget else -1

static func _search(pegs: Array, budget: int, cap := CAP) -> Dictionary:
	var work: Array = []
	for s in pegs:
		work.append((s as Array).duplicate())
	var seen := {}
	var path: Array[Vector2i] = []
	var nodes := [0]
	if _dfs(work, seen, path, nodes, budget, cap):
		return {"path": path, "nodes": nodes[0]}
	return {"path": [] as Array[Vector2i], "nodes": nodes[0]}

static func _dfs(pegs: Array, seen: Dictionary, path: Array, nodes: Array, budget: int, cap: int) -> bool:
	if solved(pegs, cap):
		return true
	nodes[0] += 1
	if nodes[0] > budget:
		return false
	var k := key(pegs)
	if seen.has(k):
		return false
	seen[k] = true
	for m in moves_from(pegs, cap):
		var done := apply(pegs, m.x, m.y, cap)
		path.append(m)
		if _dfs(pegs, seen, path, nodes, budget, cap):
			return true
		path.pop_back()
		unapply(pegs, m.x, m.y, done)
		if nodes[0] > budget:
			return false
	return false
