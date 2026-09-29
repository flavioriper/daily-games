extends RefCounted

## Untangle, the wooden ring. A ring of N peg holes; R ropes, each ending in
## two pegs; N - 2R holes stand empty. A move lifts one peg out of its hole and
## drops it in an empty one, so its rope goes with it. Rope ends never leave
## the ring, so two ropes cross exactly when their four holes interleave
## around it, and the board is undone when no two do.
##
## Solvable by construction: a board is dealt by making random legal moves
## away from a crossing-free layout, so the same moves backwards are a way
## home. The way home is then *measured*, not assumed: a beam search from the
## dealt layout finds a short answer, and its length is the board's par. A
## deal is kept only when par is high enough for the band, and Hard and
## Insane hand out par plus a little thread, which is what makes running out
## fair -- the answer fits, and there is little to spare.
##
## Reach is this board's second rule. A rope is as long as its longest span
## needs (plus what the band allows), and a peg cannot be dropped in a hole
## farther from its rope's other end than that. Short ropes are what turn
## "move anything anywhere" into a puzzle of what to move first.
##
## Insane hands the board a kitten (see `_cat_deal`): after every third move
## she bats one named peg into the hole nearest to it, and the deal is built
## backwards so that the answer includes her swipes.
##
## Spec: docs/superpowers/specs/2026-09-29-untangle-ring-design.md.

## Per band: holes, ropes, the scramble's moves, the fewest crossings a deal
## may open with, the fewest moves its best answer may take (par), how far a
## rope may reach beyond what its solved span needs, the smallest reach as a
## share of half the ring, the thread a Hard or Insane board is given beyond
## par, and whether the kitten is loose. Insane has one empty hole, so every
## move (and every swipe) is forced into it.
const BANDS := [
	{"holes": 10, "ropes": 4, "moves": 4, "cross": 2, "par": 2, "extra": 9, "min_reach": 1.0, "slack": 0, "cat": false},
	{"holes": 13, "ropes": 6, "moves": 8, "cross": 5, "par": 4, "extra": 3, "min_reach": 0.6, "slack": 0, "cat": false},
	{"holes": 17, "ropes": 8, "moves": 13, "cross": 8, "par": 6, "extra": 2, "min_reach": 0.5, "slack": 3, "cat": false},
	{"holes": 19, "ropes": 9, "moves": 13, "cross": 8, "par": 6, "extra": 2, "min_reach": 0.5, "slack": 3, "cat": true},
]
## The kitten swipes after every this many of the player's moves.
const CAT_EVERY := 3
## A deal tries this many walks at most, then keeps the best. A count, not a
## clock: the same day has to deal the same board on a slow phone and a fast one.
const TRIES := 16
## The beam search's width and how deep it goes.
const BEAM := 36
const BEAM_DEPTH := 14

# --- the rule, on a plain array `at`: peg (2 * rope + end) -> hole ---

static func chord(n: int, a: int, b: int) -> int:
	var d := absi(a - b)
	return mini(d, n - d)

## True when the rope from `a` to `b` and the rope from `c` to `d` cross:
## exactly one of c, d lies strictly between a and b. Holes are distinct.
static func crosses(a: int, b: int, c: int, d: int) -> bool:
	var lo := mini(a, b)
	var hi := maxi(a, b)
	return (c > lo and c < hi) != (d > lo and d < hi)

## Every crossing as a pair of rope indices, low first.
static func crossing_pairs(at: PackedInt32Array, ropes: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for r in ropes:
		for s in range(r + 1, ropes):
			if crosses(at[2 * r], at[2 * r + 1], at[2 * s], at[2 * s + 1]):
				out.append(Vector2i(r, s))
	return out

static func crossing_count(at: PackedInt32Array, ropes: int) -> int:
	var total := 0
	for r in ropes:
		for s in range(r + 1, ropes):
			if crosses(at[2 * r], at[2 * r + 1], at[2 * s], at[2 * s + 1]):
				total += 1
	return total

static func is_solved(at: PackedInt32Array, ropes: int) -> bool:
	for r in ropes:
		for s in range(r + 1, ropes):
			if crosses(at[2 * r], at[2 * r + 1], at[2 * s], at[2 * s + 1]):
				return false
	return true

## Each rope's crossings as a bit mask of the ropes it crosses.
static func _adjacency(at: PackedInt32Array, ropes: int) -> PackedInt32Array:
	var adj := PackedInt32Array()
	adj.resize(ropes)
	for r in ropes:
		for s in range(r + 1, ropes):
			if crosses(at[2 * r], at[2 * r + 1], at[2 * s], at[2 * s + 1]):
				adj[r] |= 1 << s
				adj[s] |= 1 << r
	return adj

static func _popcount(m: int) -> int:
	var n := 0
	while m != 0:
		m &= m - 1
		n += 1
	return n

static func _cover(adj: PackedInt32Array, alive: int, ropes: int) -> int:
	for r in ropes:
		var near: int = adj[r] & alive
		if alive & (1 << r) and near != 0:
			var without := alive & ~(1 << r)
			var take_r := 1 + _cover(adj, without, ropes)
			var take_near := _popcount(near) + _cover(adj, without & ~near, ropes)
			return mini(take_r, take_near)
	return 0

## The fewest ropes that touch every crossing. Each move relocates one rope,
## so no answer is shorter than this.
static func min_cover(at: PackedInt32Array, ropes: int) -> int:
	return _cover(_adjacency(at, ropes), (1 << ropes) - 1, ropes)

static func occupancy(at: PackedInt32Array, holes: int) -> PackedInt32Array:
	var occ := PackedInt32Array()
	occ.resize(holes)
	occ.fill(-1)
	for p in at.size():
		occ[at[p]] = p
	return occ

## Whether peg `p` may be dropped in `hole`: the hole is free and the rope it
## is on can span it.
static func fits(at: PackedInt32Array, holes: int, reach: PackedInt32Array, p: int, hole: int, occ: PackedInt32Array) -> bool:
	return hole != at[p] and occ[hole] < 0 and chord(holes, hole, at[p ^ 1]) <= reach[p >> 1]

## Every legal move from `at` as [peg, hole].
static func legal_moves(at: PackedInt32Array, holes: int, reach: PackedInt32Array) -> Array:
	var occ := occupancy(at, holes)
	var out: Array = []
	for p in at.size():
		for h in holes:
			if occ[h] < 0 and h != at[p] and chord(holes, h, at[p ^ 1]) <= reach[p >> 1]:
				out.append([p, h])
	return out

## The hole the kitten puts peg `p` in: the empty hole nearest to it round the
## ring (clockwise first) that its rope can span; -1 when there is none and
## she naps.
static func cat_hole(at: PackedInt32Array, holes: int, reach: PackedInt32Array, p: int) -> int:
	var occ := occupancy(at, holes)
	var here := at[p]
	for d in range(1, holes / 2 + 1):
		var cw := (here + d) % holes
		if fits(at, holes, reach, p, cw, occ):
			return cw
		var ccw := (here - d + holes) % holes
		if fits(at, holes, reach, p, ccw, occ):
			return ccw
	return -1

# --- a short way home ---

## The peg the kitten bats after move number `j` when the deal did not name
## one: a fixed stand-in, so her schedule never runs out.
static func swipe_fallback(j: int, pegs: int) -> int:
	return (j * 5 + 3) % pegs

## A beam search from `at` to any crossing-free layout: each depth keeps the
## `width` layouts with the fewest crossings, fewest ropes to move first. Not
## the shortest answer for certain, but always a real one. Returns the moves
## [[peg, from, to], ...] ([] when already solved), or null when none was
## found within `depth` moves. With the kitten loose (`every` > 0) she swipes
## after every `every`th move counted from `moves0`, as `swipes` says, and the
## search plays her in.
static func way_home(at: PackedInt32Array, holes: int, ropes: int, reach: PackedInt32Array,
		depth := BEAM_DEPTH, width := BEAM, rng: RandomNumberGenerator = null,
		swipes := {}, every := 0, moves0 := 0) -> Variant:
	if is_solved(at, ropes):
		return []
	var seen := {_key(at, every, moves0): true}
	# Each entry: [score, state, path].
	var beam: Array = [[0, at, []]]
	for d in depth:
		var next: Array = []
		var j := moves0 + d + 1
		for entry in beam:
			var here: PackedInt32Array = entry[1]
			for m in legal_moves(here, holes, reach):
				var nxt := here.duplicate()
				nxt[m[0]] = m[1]
				var path: Array = (entry[2] as Array).duplicate()
				path.append([m[0], here[m[0]], m[1]])
				if is_solved(nxt, ropes):
					return path
				if every > 0 and j % every == 0:
					var p: int = swipes.get(j, swipe_fallback(j, nxt.size()))
					var to := cat_hole(nxt, holes, reach, p)
					if to >= 0:
						nxt[p] = to
						if is_solved(nxt, ropes):
							return path
				var key := _key(nxt, every, j)
				if seen.has(key):
					continue
				seen[key] = true
				var jitter := rng.randi_range(0, 9) if rng != null else 0
				next.append([min_cover(nxt, ropes) * 1000 + crossing_count(nxt, ropes) * 20 + jitter, nxt, path])
		if next.is_empty():
			return null
		next.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
		beam = next.slice(0, width)
	return null

## A layout as a dictionary key; with the kitten loose it carries where the
## count stands in her cycle, since the same layout plays out differently
## before a swipe and after one.
static func _key(at: PackedInt32Array, every: int, j: int) -> PackedByteArray:
	var k := at.to_byte_array()
	if every > 0:
		k.append(j % every)
	return k

# --- the deal ---

## A non-crossing pairing of `pts` (holes in ring order): the first is tied to
## a random odd-numbered one, and each side is paired on its own. Ropes are
## nudged toward long spans, which is what tangles.
static func _pair_up(rng: RandomNumberGenerator, pts: Array) -> Array:
	if pts.is_empty():
		return []
	var options: Array = []
	for j in range(1, pts.size(), 2):
		options.append(j)
	var total := 0
	for j in options:
		total += j
	var pick: int = int(options.back())
	var roll := rng.randi_range(1, total)
	for j in options:
		roll -= j
		if roll <= 0:
			pick = j
			break
	var out: Array = [[pts[0], pts[pick]]]
	out.append_array(_pair_up(rng, pts.slice(1, pick)))
	out.append_array(_pair_up(rng, pts.slice(pick + 1)))
	return out

## A crossing-free layout: which holes stand empty, and who ties to whom.
## Returns {"at": ..., "reach": ...}.
static func _goal(rng: RandomNumberGenerator, cfg: Dictionary) -> Dictionary:
	var holes: int = cfg.holes
	var ropes: int = cfg.ropes
	var order: Array = range(holes)
	for i in range(order.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = order[i]; order[i] = order[j]; order[j] = tmp
	var empty_count: int = holes - 2 * ropes
	var taken: Array = order.slice(empty_count)
	taken.sort()
	var pairs := _pair_up(rng, taken)
	var slots: Array = range(ropes)
	for i in range(slots.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = slots[i]; slots[i] = slots[j]; slots[j] = tmp
	var at := PackedInt32Array()
	at.resize(2 * ropes)
	var reach := PackedInt32Array()
	reach.resize(ropes)
	var half := holes / 2
	var floor_reach := int(ceil(float(half) * float(cfg.min_reach)))
	for k in pairs.size():
		var r: int = slots[k]
		var a: int = pairs[k][0]
		var b: int = pairs[k][1]
		if rng.randi() % 2 == 0:
			var t := a; a = b; b = t
		at[2 * r] = a
		at[2 * r + 1] = b
		var span := chord(holes, a, b)
		reach[r] = mini(half, maxi(floor_reach, span + rng.randi_range(0, int(cfg.extra))))
	return {"at": at, "reach": reach}

## The next step away from the solved layout: a legal move of a rope not yet
## moved (any rope when all have been), scored by how much it deepens the
## tangle -- the smallest set of ropes that must move first, then the
## crossings -- and the best of them taken. [] when nothing is legal.
static func _pick_away(rng: RandomNumberGenerator, at: PackedInt32Array, holes: int, ropes: int,
		reach: PackedInt32Array, moved: Dictionary, last_rope: int) -> Array:
	var options := legal_moves(at, holes, reach)
	for i in range(options.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = options[i]; options[i] = options[j]; options[j] = tmp
	var base_cover := min_cover(at, ropes)
	var base_cross := crossing_count(at, ropes)
	var best: Array = []
	var best_score := -1000
	for m in options:
		var rope: int = m[0] >> 1
		if rope == last_rope:
			continue
		var nxt := at.duplicate()
		nxt[m[0]] = m[1]
		var score := (min_cover(nxt, ropes) - base_cover) * 100 + (crossing_count(nxt, ropes) - base_cross) * 10
		if moved.has(rope):
			score -= 60
		if score > best_score:
			best_score = score
			best = m
	return best

## The layout dealt: legal moves out of the solved layout, each one chosen to
## deepen the tangle. Returns {"start"} or {} when the walk is a dud.
static func _scramble(rng: RandomNumberGenerator, goal: Dictionary, cfg: Dictionary) -> Dictionary:
	var at: PackedInt32Array = goal.at.duplicate()
	var moved := {}
	var last_rope := -1
	for step in int(cfg.moves):
		var chosen := _pick_away(rng, at, cfg.holes, cfg.ropes, goal.reach, moved, last_rope)
		if chosen.is_empty():
			return {}
		at[chosen[0]] = chosen[1]
		last_rope = chosen[0] >> 1
		moved[last_rope] = true
	return {"start": at}

## Insane's deal, built backwards so the kitten's swipes are part of the
## answer: from the solved layout, undo the player's last move, then (when a
## swipe follows the move before it) undo her swipe, and so on to the start.
## Returns {"start", "plan", "swipes"} or {} when a step has no way back.
## Plan entries are [peg, from, to].
static func _cat_deal(rng: RandomNumberGenerator, goal: Dictionary, cfg: Dictionary) -> Dictionary:
	var holes: int = cfg.holes
	var ropes: int = cfg.ropes
	var reach: PackedInt32Array = goal.reach
	var at: PackedInt32Array = goal.at.duplicate()
	var total: int = cfg.moves
	var plan: Array = []
	var swipes := {}   # move number j -> the peg she bats after it
	var moved := {}
	var last_rope := -1
	for j in range(total, 0, -1):
		var chosen := _pick_away(rng, at, holes, ropes, reach, moved, last_rope)
		if chosen.is_empty():
			return {}
		plan.push_front([chosen[0], chosen[1], at[chosen[0]]])
		at[chosen[0]] = chosen[1]
		last_rope = chosen[0] >> 1
		moved[last_rope] = true
		# Undo her swipe after move j - 1, if there is one.
		var done := j - 1
		if done >= CAT_EVERY and done % CAT_EVERY == 0:
			var swiped := false
			var pegs: Array = range(at.size())
			for i in range(pegs.size() - 1, 0, -1):
				var k := rng.randi_range(0, i)
				var tmp = pegs[i]; pegs[i] = pegs[k]; pegs[k] = tmp
			for p in pegs:
				# She left `p` on an empty hole `a`, and it now sits on `h`:
				# put it back on `a` and check she would do it again.
				var occ := occupancy(at, holes)
				var h := at[p]
				for a in holes:
					if occ[a] >= 0 or chord(holes, a, at[p ^ 1]) > reach[p >> 1]:
						continue
					var back := at.duplicate()
					back[p] = a
					if cat_hole(back, holes, reach, p) == h:
						at = back
						swipes[done] = p
						swiped = true
						break
				if swiped:
					break
			if not swiped:
				return {}
	return {"start": at, "plan": plan, "swipes": swipes}

## `plan` played forward from `start`, her swipes included, to the layout it ends in.
static func _play(start: PackedInt32Array, plan: Array, cfg: Dictionary, reach: PackedInt32Array, swipes: Dictionary) -> PackedInt32Array:
	var at := start.duplicate()
	for j in plan.size():
		at[plan[j][0]] = plan[j][2]
		if is_solved(at, cfg.ropes):
			break
		if cfg.cat and (j + 1) % CAT_EVERY == 0:
			var p: int = swipes.get(j + 1, swipe_fallback(j + 1, at.size()))
			var to := cat_hole(at, cfg.holes, reach, p)
			if to >= 0:
				at[p] = to
				if is_solved(at, cfg.ropes):
					break
	return at

## Plays the answer forward with the kitten, from the start, and says whether
## it ends solved after exactly the planned number of moves, and not before.
static func _replays(start: PackedInt32Array, reach: PackedInt32Array, cfg: Dictionary, deal: Dictionary) -> bool:
	var holes: int = cfg.holes
	var ropes: int = cfg.ropes
	var at := start.duplicate()
	var plan: Array = deal.plan
	var swipes: Dictionary = deal.swipes
	for j in plan.size():
		var m: Array = plan[j]
		var occ := occupancy(at, holes)
		if not fits(at, holes, reach, m[0], m[2], occ):
			return false
		at[m[0]] = m[2]
		if is_solved(at, ropes):
			return j == plan.size() - 1
		var done := j + 1
		if swipes.has(done):
			var to := cat_hole(at, holes, reach, swipes[done])
			if to < 0:
				return false
			at[swipes[done]] = to
	return is_solved(at, ropes)

## One full board for `band`: {"holes", "ropes", "start", "goal", "reach",
## "plan", "par", "budget", "cat", "swipes", "order"}. `plan` is an answer,
## as [peg, from, to] moves.
static func generate(rng: RandomNumberGenerator, band: int) -> Dictionary:
	var cfg: Dictionary = BANDS[clampi(band, 0, BANDS.size() - 1)]
	var ropes: int = cfg.ropes
	var best: Dictionary = {}
	var best_par := -1
	for attempt in TRIES:
		var goal := _goal(rng, cfg)
		var deal: Dictionary = _cat_deal(rng, goal, cfg) if cfg.cat else _scramble(rng, goal, cfg)
		if deal.is_empty():
			continue
		var start: PackedInt32Array = deal.start
		if crossing_count(start, ropes) < int(cfg.cross):
			continue
		var plan: Array
		var swipes: Dictionary = deal.get("swipes", {})
		if cfg.cat:
			if not _replays(start, goal.reach, cfg, deal):
				continue
			plan = deal.plan
			# The deal's own answer is only one way; the search, with her
			# swipes played in, usually finds one less than half as long, and
			# that is what par and the thread are measured against.
			var found = way_home(start, cfg.holes, ropes, goal.reach, BEAM_DEPTH, BEAM, rng, swipes, CAT_EVERY, 0)
			if found != null and found.size() < plan.size():
				plan = found
		else:
			var found = way_home(start, cfg.holes, ropes, goal.reach, BEAM_DEPTH, BEAM, rng)
			if found == null:
				continue
			plan = found
		var par := plan.size()
		if par > best_par:
			best_par = par
			var end := _play(start, plan, cfg, goal.reach, swipes)
			best = {"holes": cfg.holes, "ropes": ropes, "start": start, "goal": end,
				"reach": goal.reach, "plan": plan, "par": par,
				"budget": (par + int(cfg.slack)) if int(cfg.slack) > 0 else 0,
				"cat": cfg.cat, "swipes": swipes}
		if par >= int(cfg.par):
			break
	if best.is_empty():
		# Every walk was a dud: fall back to the easiest honest board, one
		# rope moved. Never an unsolvable one.
		var goal := _goal(rng, BANDS[0])
		var start: PackedInt32Array = goal.at.duplicate()
		var occ := occupancy(start, 10)
		for p in start.size():
			for h in 10:
				if occ[h] < 0 and fits(start, 10, goal.reach, p, h, occ):
					start[p] = h
					break
			if not is_solved(start, 4):
				break
		var plan = way_home(start, 10, 4, goal.reach)
		best = {"holes": 10, "ropes": 4, "start": start, "goal": goal.at, "reach": goal.reach,
			"plan": plan if plan != null else [], "par": 1, "budget": 0, "cat": false, "swipes": {}}
	# The stack the ropes lie in, bottom to top.
	var order: Array = range(best.ropes)
	for i in range(order.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = order[i]; order[i] = order[j]; order[j] = tmp
	best["order"] = order
	return best
