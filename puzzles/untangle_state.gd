extends RefCounted

## Untangle's rules, with no scene under them: which hole each rope end sits
## in, which ropes cross, every move that can change that, the thread a Hard
## or Insane day is allowed, and Insane's kitten. The board
## (puzzles/untangle2d.gd) draws this and nothing else.
##
## A peg is numbered 2 * rope + end. `at[peg]` is its hole and `occ[hole]` the
## peg in it (-1 when empty). The rule itself lives in untangle_gen.gd so the
## dealer and the player read one definition of a crossing.
## Spec: docs/superpowers/specs/2026-09-29-untangle-ring-design.md.

const Gen = preload("res://puzzles/untangle_gen.gd")

## Hints a day starts with, by band; a video's come on top (and cost thread).
const HINTS_BY_BAND := [3, 3, 1, 0]
## Thread a rewarded "one more spool" gives, by band.
const SPOOL_BY_BAND := [0, 0, 4, 3]

var band := 0
var holes := 10
var ropes := 4
var at := PackedInt32Array()
var occ := PackedInt32Array()
var start_at := PackedInt32Array()
## The layout the dealer's answer ends in, which is what "Show the answer"
## walks the pegs to.
var goal_at := PackedInt32Array()
## Per rope, the widest span (in holes) it can reach.
var reach := PackedInt32Array()
## The stack the ropes lie in, bottom to top: the rope moved last lies on top.
var order: Array = []
var start_order: Array = []
## The dealer's own answer, [peg, from, to] steps from the start.
var plan: Array = []
var par := 0
## Thread: 0 means no limit (Easy and Medium). A move, a hint and an undo each
## use a stitch; Reset gives nothing back.
var budget := 0
var spent := 0
var bought := false
## Insane's kitten: her schedule (move number -> the peg she bats after it)
## and how many moves this attempt has made, which is what the schedule reads.
var cat := false
var swipes: Dictionary = {}
var moves_here := 0
## One entry per move that can be taken back, newest last:
## {"peg", "from", "to", "order", "cat": {} or {"peg", "from", "to"}}.
var history: Array[Dictionary] = []

## Every crossing as a pair of ropes, and the ropes caught in one.
var pairs: Array[Vector2i] = []
var bad: Dictionary = {}

func setup(rng: RandomNumberGenerator, difficulty: int) -> void:
	band = clampi(difficulty, 0, Gen.BANDS.size() - 1)
	var out: Dictionary = Gen.generate(rng, band)
	holes = out.holes
	ropes = out.ropes
	start_at = out.start
	goal_at = out.goal
	reach = out.reach
	plan = out.plan
	par = out.par
	budget = out.budget
	cat = out.cat
	swipes = out.swipes
	start_order = out.order
	at = start_at.duplicate()
	order = start_order.duplicate()
	occ = Gen.occupancy(at, holes)
	spent = 0
	bought = false
	moves_here = 0
	history = []
	scan()

func scan() -> void:
	occ = Gen.occupancy(at, holes)
	pairs = Gen.crossing_pairs(at, ropes)
	bad = {}
	for p in pairs:
		bad[p.x] = true
		bad[p.y] = true

func crossings() -> int:
	return pairs.size()

func is_solved() -> bool:
	return pairs.is_empty()

func rope_of(peg: int) -> int:
	return peg >> 1

## The span, in holes, a rope of `peg` would have if that end sat in `hole`.
func span_if(peg: int, hole: int) -> int:
	return Gen.chord(holes, hole, at[peg ^ 1])

## 0 when `peg` may be dropped in `hole`; 1 when the hole is taken or is its
## own; 2 when the rope is too short to reach it.
func drop_check(peg: int, hole: int) -> int:
	if hole == at[peg] or occ[hole] >= 0:
		return 1
	if span_if(peg, hole) > reach[peg >> 1]:
		return 2
	return 0

## True when the board is not solved and no peg can go anywhere: every free
## hole is out of every rope's reach. Undo (Hard) and Reset are the ways out.
func stuck() -> bool:
	if is_solved():
		return false
	for p in at.size():
		if can_go(p):
			return false
	return true

## True when the peg has anywhere to go at all.
func can_go(peg: int) -> bool:
	for h in holes:
		if drop_check(peg, h) == 0:
			return true
	return false

# --- thread ---

func has_thread() -> bool:
	return budget > 0

func thread_left() -> int:
	return maxi(0, budget - spent) if budget > 0 else -1

func out_of_thread() -> bool:
	return budget > 0 and spent >= budget and not is_solved()

func buy_spool() -> void:
	budget += SPOOL_BY_BAND[band]
	bought = true

# --- the kitten ---

## The peg she bats after move number `j` of an attempt: the dealer's, or for
## a move past the answer a fixed stand-in so the schedule never runs out.
func swipe_peg(j: int) -> int:
	if swipes.has(j):
		return int(swipes[j])
	return Gen.swipe_fallback(j, at.size())

## What she will do next: {"peg", "in"} (moves until she pounces), {} when the
## kitten is not loose.
func cat_next() -> Dictionary:
	if not cat:
		return {}
	var due := (moves_here / Gen.CAT_EVERY + 1) * Gen.CAT_EVERY
	return {"peg": swipe_peg(due), "in": due - moves_here}

## Where she would put her peg if the player's move `peg` -> `hole` were made
## now and she pounced straight after, [] when that is not her move to make
## or she would nap.
func foresee(peg: int, hole: int) -> Array:
	var nxt := cat_next()
	if nxt.is_empty() or int(nxt["in"]) != 1 or drop_check(peg, hole) != 0:
		return []
	var moved := at.duplicate()
	moved[peg] = hole
	if Gen.is_solved(moved, ropes):
		return []
	var target := Gen.cat_hole(moved, holes, reach, int(nxt.peg))
	if target < 0:
		return []
	return [int(nxt.peg), moved[int(nxt.peg)], target]

# --- moves ---

## Drops `peg` in `hole` (which must pass drop_check): its rope goes on top,
## the thread is used, and if this move is the one before a swipe -- and did
## not solve the board -- the kitten pounces. Returns {"peg", "from", "to",
## "cleared" (crossings this move undid, negative when it made some: the
## player's move alone, before any swipe), "left" (crossings after the move,
## before any swipe), "cat"}; {} when the drop is not allowed.
func move(peg: int, hole: int) -> Dictionary:
	if drop_check(peg, hole) != 0:
		return {}
	var before := crossings()
	var entry := {"peg": peg, "from": at[peg], "to": hole, "order": order.duplicate(), "cat": {}}
	at[peg] = hole
	_raise(peg >> 1)
	moves_here += 1
	spent += 1
	scan()
	var after_move := crossings()
	if cat and not is_solved() and moves_here % Gen.CAT_EVERY == 0:
		var p := swipe_peg(moves_here)
		var to := Gen.cat_hole(at, holes, reach, p)
		if to >= 0:
			entry["cat"] = {"peg": p, "from": at[p], "to": to}
			at[p] = to
			scan()
	history.append(entry)
	return {"peg": peg, "from": entry.from, "to": hole, "cleared": before - after_move, "left": after_move, "cat": entry.cat}

func _raise(rope: int) -> void:
	order.erase(rope)
	order.append(rope)

func can_undo() -> bool:
	return not history.is_empty() and not cat and not out_of_thread()

## Takes the last move back (a stitch, like any move) and says which peg went
## where; {} when there is nothing to undo.
func undo() -> Dictionary:
	if history.is_empty():
		return {}
	var last: Dictionary = history.pop_back()
	if not last.cat.is_empty():
		at[int(last.cat.peg)] = int(last.cat.from)
	at[int(last.peg)] = int(last.from)
	order = last.order
	moves_here = maxi(0, moves_here - 1)
	spent += 1
	scan()
	return {"peg": int(last.peg), "from": int(last.to), "to": int(last.from)}

## The next step of a short way home from where the pegs are now, as
## [peg, from, to]; [] when there is none to give. The search plays the
## kitten's swipes in, so her schedule is part of the hint.
func hint_step() -> Array:
	var way = null
	if cat:
		var depth := mini(Gen.BEAM_DEPTH, maxi(thread_left() + 2, 4))
		way = Gen.way_home(at, holes, ropes, reach, depth, Gen.HINT_BEAM, null, swipes, Gen.CAT_EVERY, moves_here)
	else:
		way = Gen.way_home(at, holes, ropes, reach, Gen.BEAM_DEPTH, Gen.HINT_BEAM)
	if way == null or way.is_empty():
		# No way home in reach of the search: the move that leaves fewest
		# crossings, so a hint is still something.
		var best: Array = []
		var fewest := crossings()
		for m in Gen.legal_moves(at, holes, reach):
			var t := at.duplicate()
			t[m[0]] = m[1]
			var c := Gen.crossing_count(t, ropes)
			if c < fewest:
				fewest = c
				best = [m[0], at[m[0]], m[1]]
		return best
	return way[0]

## Back to the tangle the player was given. The thread stays spent (the
## board reads what came back), the kitten's schedule starts over. Returns the
## pegs that have somewhere to walk to, in order.
func reset() -> Array[int]:
	var walking: Array[int] = []
	for p in at.size():
		if at[p] != start_at[p]:
			walking.append(p)
	at = start_at.duplicate()
	order = start_order.duplicate()
	moves_here = 0
	history = []
	scan()
	return walking

## Lays the dealer's untangled layout down, and says which pegs walked.
func show_answer() -> Array[int]:
	var walking: Array[int] = []
	for p in at.size():
		if at[p] != goal_at[p]:
			walking.append(p)
	at = goal_at.duplicate()
	history = []
	scan()
	return walking

func share_glyphs() -> String:
	return tr("UT_SHARE") % [holes, ropes]
