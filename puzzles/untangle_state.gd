extends RefCounted

## Untangle's rules, with no scene under them: which hole each rope end sits
## in, how every pair of ropes crosses (how often, and which lies on top),
## every move that can change that, the thread a Hard
## or Insane day is allowed, and Insane's kitten. The board
## (puzzles/untangle2d.gd) draws this and nothing else.
##
## A peg is numbered 2 * rope + end. `at[peg]` is its hole and `occ[hole]` the
## peg in it (-1 when empty). A rope that crosses nothing leaves the ring with
## its pegs (`at` reads -1 for both) and its holes stand empty; the day is won
## when the last has left. The rule itself lives in untangle_gen.gd so the
## dealer and the player read one definition of a crossing.
## Spec: docs/superpowers/specs/2026-09-29-untangle-knots-design.md.

const Gen = preload("res://puzzles/untangle_gen.gd")

## Hints a day starts with, by band; a video's come on top (and cost thread).
const HINTS_BY_BAND := [3, 3, 1, 0]
## Thread a rewarded "one more spool" gives, by band.
const SPOOL_BY_BAND := [0, 0, 0, 3]

var band := 0
var holes := 10
var ropes := 4
var at := PackedInt32Array()
var occ := PackedInt32Array()
var start_at := PackedInt32Array()
## Per pair of ropes, how they cross (Gen: n * 2 + who is on top).
var tw := PackedInt32Array()
var start_tw := PackedInt32Array()
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
## {"peg", "from", "to", "order", "at", "tw" (both from before it),
## "cat": {} or {"peg", "from", "to"}}.
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
	start_tw = out.tw
	reach = out.reach
	plan = out.plan
	par = out.par
	budget = out.budget
	cat = out.cat
	swipes = out.swipes
	start_order = out.order
	at = start_at.duplicate()
	tw = start_tw.duplicate()
	order = start_order.duplicate()
	occ = Gen.occupancy(at, holes)
	spent = 0
	bought = false
	moves_here = 0
	history = []
	scan()

func scan() -> void:
	occ = Gen.occupancy(at, holes)
	pairs = Gen.crossing_pairs(tw, ropes)
	bad = {}
	for p in pairs:
		bad[p.x] = true
		bad[p.y] = true

## Every crossing, a wrapped pair counting each time round.
func crossings() -> int:
	return Gen.crossing_count(tw)

## How many times ropes `r` and `s` cross.
func count(r: int, s: int) -> int:
	return Gen.count(tw, Gen.pair_index(r, s, ropes))

## 1 when rope `r`'s end `e` is on top at its nearest crossing with `s`, 0
## under, -1 when they do not cross.
func top_at(r: int, e: int, s: int) -> int:
	return Gen.top_at(at, tw, ropes, r, e, s)

## What dropping `peg` in `hole` would do to the crossings: the change, and how
## many of the pairs it passes over it would wrap tighter. [delta, wraps].
func preview(peg: int, hole: int) -> Array:
	var a := at.duplicate()
	var t := tw.duplicate()
	var before := t.duplicate()
	var delta := Gen.apply(a, t, ropes, peg, hole)
	var wraps := 0
	for k in t.size():
		if (t[k] >> 1) > (before[k] >> 1) and (before[k] >> 1) > 0:
			wraps += 1
	return [delta, wraps]

func is_solved() -> bool:
	return pairs.is_empty()

## True when rope `r` has come free and left the ring.
func is_gone(r: int) -> bool:
	return at[2 * r] < 0

## How many ropes the day was dealt (a rope the dealer left free is not).
func ropes_dealt() -> int:
	return Gen.ropes_left(start_at)

func rope_of(peg: int) -> int:
	return peg >> 1

## The span, in holes, a rope of `peg` would have if that end sat in `hole`.
func span_if(peg: int, hole: int) -> int:
	return Gen.chord(holes, hole, at[peg ^ 1])

## 0 when `peg` may be dropped in `hole`; 1 when the hole is taken or is its
## own; 2 when the rope is too short to reach it.
func drop_check(peg: int, hole: int) -> int:
	if at[peg] < 0 or hole == at[peg] or occ[hole] >= 0:
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
	if at[peg] < 0:
		return false
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
## kitten is not loose. The peg is the one her schedule names, or when its rope
## has left the ring the next peg round that is still there.
func cat_next() -> Dictionary:
	if not cat:
		return {}
	var due := (moves_here / Gen.CAT_EVERY + 1) * Gen.CAT_EVERY
	var peg := Gen.cat_peg(at, swipe_peg(due))
	if peg < 0:
		return {}
	return {"peg": peg, "in": due - moves_here}

## Where she would put her peg if the player's move `peg` -> `hole` were made
## now and she pounced straight after, [] when that is not her move to make
## or she would nap.
func foresee(peg: int, hole: int) -> Array:
	var nxt := cat_next()
	if nxt.is_empty() or int(nxt["in"]) != 1 or drop_check(peg, hole) != 0:
		return []
	var moved := at.duplicate()
	var moved_tw := tw.duplicate()
	Gen.apply(moved, moved_tw, ropes, peg, hole)
	if Gen.is_solved(moved_tw):
		return []
	Gen.retire(moved, moved_tw, ropes)
	var hers := Gen.cat_peg(moved, swipe_peg(moves_here + 1))
	var target := Gen.cat_hole(moved, holes, reach, hers)
	if target < 0:
		return []
	return [hers, moved[hers], target]

# --- moves ---

## Drops `peg` in `hole` (which must pass drop_check): its rope goes on top,
## the thread is used, and if this move is the one before a swipe -- and did
## not solve the board -- the kitten pounces. Returns {"peg", "from", "to",
## "cleared" (crossings this move undid, negative when it made some: the
## player's move alone, before any swipe), "left" (crossings after the move,
## before any swipe), "gone" (ropes it left crossing nothing, which leave the
## ring), "unwound" (pairs that were wrapped, two or more times round, and
## now cross no more than once), "wrapped" (pairs it wrapped tighter), "cat"
## ({} or {"peg", "from", "to", "gone": the ropes her swipe set free}),
## "tw_mid" (the tangle after the player's move, before any swipe)};
## {} when the drop is not allowed.
func move(peg: int, hole: int) -> Dictionary:
	if drop_check(peg, hole) != 0:
		return {}
	var before := crossings()
	var entry := {"peg": peg, "from": at[peg], "to": hole, "order": order.duplicate(),
		"at": at.duplicate(), "tw": tw.duplicate(), "cat": {}}
	var was_tw := tw.duplicate()
	Gen.apply(at, tw, ropes, peg, hole)
	var gone: Array = Gen.retire(at, tw, ropes)
	_raise(peg >> 1)
	moves_here += 1
	spent += 1
	scan()
	var after_move := crossings()
	var unwound := 0
	var wrapped := 0
	for k in tw.size():
		var was := was_tw[k] >> 1
		var now := tw[k] >> 1
		if was >= 2 and now <= 1:
			unwound += 1
		if now > was and was > 0:
			wrapped += 1
	var mid := tw.duplicate()
	if cat and not is_solved() and moves_here % Gen.CAT_EVERY == 0:
		var p := Gen.cat_peg(at, swipe_peg(moves_here))
		var to := Gen.cat_hole(at, holes, reach, p)
		if to >= 0:
			entry["cat"] = {"peg": p, "from": at[p], "to": to}
			Gen.apply(at, tw, ropes, p, to)
			entry.cat["gone"] = Gen.retire(at, tw, ropes)
			_raise(p >> 1)
			scan()
	history.append(entry)
	return {"peg": peg, "from": entry.from, "to": hole, "cleared": before - after_move, "left": after_move,
		"gone": gone, "unwound": unwound, "wrapped": wrapped, "cat": entry.cat, "tw_mid": mid}

func _raise(rope: int) -> void:
	order.erase(rope)
	order.append(rope)

func can_undo() -> bool:
	return not history.is_empty() and not cat and not out_of_thread()

## Takes the last move back (a stitch, like any move) and says which peg went
## where and which ropes came back to the ring with it ("back"); {} when
## there is nothing to undo.
func undo() -> Dictionary:
	if history.is_empty():
		return {}
	var last: Dictionary = history.pop_back()
	var back: Array = []
	for r in ropes:
		if at[2 * r] < 0 and int(last.at[2 * r]) >= 0:
			back.append(r)
	at = (last.at as PackedInt32Array).duplicate()
	tw = (last.tw as PackedInt32Array).duplicate()
	order = last.order
	moves_here = maxi(0, moves_here - 1)
	spent += 1
	scan()
	return {"peg": int(last.peg), "from": int(last.to), "to": int(last.from), "back": back}

## The next step of a short way home from where the pegs are now, as
## [peg, from, to]; [] when there is none to give. The search plays the
## kitten's swipes in, so her schedule is part of the hint. Without her, a
## move taken back is a move made back, so when the search finds nothing the
## last move undone is always a step toward the start, and the dealer's
## answer from there.
func hint_step() -> Array:
	var way = null
	if cat:
		var depth := mini(Gen.BEAM_DEPTH, maxi(thread_left() + 2, 6))
		way = Gen.way_home(at, tw, holes, ropes, reach, depth, Gen.HINT_BEAM, null, swipes, Gen.CAT_EVERY, moves_here)
	else:
		if at == start_at and tw == start_tw and not plan.is_empty():
			return plan[0]
		way = Gen.way_home(at, tw, holes, ropes, reach, Gen.BEAM_DEPTH, Gen.HINT_BEAM)
		if way == null and not history.is_empty():
			var last: Dictionary = history.back()
			var back_peg := int(last.peg)
			if at[back_peg] == int(last.to) and drop_check(back_peg, int(last.from)) == 0:
				return [back_peg, int(last.to), int(last.from)]
	if way == null or way.is_empty():
		# No way home in reach of the search: the move that looks nearest
		# home, even one that crosses more first (undoing a wrap often
		# does), so a hint is always a move while any move exists.
		var best: Array = []
		var lowest := 1 << 30
		for m in Gen.legal_moves(at, holes, reach):
			var a := at.duplicate()
			var t := tw.duplicate()
			Gen.apply(a, t, ropes, m[0], m[1])
			var sc := Gen.score(t, ropes)
			if sc < lowest:
				lowest = sc
				best = [m[0], at[m[0]], m[1]]
		return best
	return way[0]

## Back to the tangle the player was given. The thread stays spent (the
## board reads what came back), the kitten's schedule starts over. Returns the
## pegs that have somewhere to walk to, in order (a peg whose rope had left
## among them: it comes back).
func reset() -> Array[int]:
	var walking: Array[int] = []
	for p in at.size():
		if at[p] != start_at[p]:
			walking.append(p)
	at = start_at.duplicate()
	tw = start_tw.duplicate()
	order = start_order.duplicate()
	moves_here = 0
	history = []
	scan()
	return walking

## Every rope still on the ring comes free and leaves it; says which did.
func show_answer() -> Array[int]:
	var leaving: Array[int] = []
	for r in ropes:
		if at[2 * r] >= 0:
			leaving.append(r)
	at.fill(-1)
	tw = Gen.empty_tangle(ropes)
	history = []
	scan()
	return leaving

func share_glyphs() -> String:
	return tr("UT_SHARE") % [holes, ropes_dealt()]
