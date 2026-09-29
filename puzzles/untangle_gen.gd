extends RefCounted

## Untangle, the wooden ring. A ring of N peg holes; R ropes, each ending in
## two pegs; N - 2R holes stand empty. A move lifts one peg out of its hole,
## carries it *over* everything and drops it in an empty hole, so its rope
## goes with it.
##
## The tangle is made of real crossings: where two ropes cross, one lies on
## top. Each pair of ropes keeps how many times it crosses (`n`) and, since a
## twisted pair's crossings alternate over and under along each rope, which
## rope is on top at each end of that run of crossings. A peg carried over the
## top across another rope does one of two things there, as a real cord would:
##
## * if its rope was the one on top at the crossing nearest this end, lifting
##   it takes that crossing out (the cord slides off: n - 1);
## * if its rope lay *under* there, the cord comes round over the top and the
##   two are wrapped once more (n + 1).
##
## So lifting the cord on top untangles and pulling the one underneath knots
## it tighter. Two ropes with an even count are wrapped round each other
## without their pegs interleaving; an odd count always interleaves (the
## count's parity is the old rule, which it still obeys). The board is undone
## when no pair crosses at all.
##
## The rule lives on plain int arrays: `at[peg]` = hole (peg = 2 * rope + end)
## and `tw[pair]` = n * 2 + t, where for the pair (A, B), A < B, `t` is 1 when
## A is on top at the crossing nearest A's end 0. Which of B's ends is nearest
## that crossing is read off the ring when it matters (an even count: the only
## way the four pegs can be joined in two non-crossing pairs).
##
## Solvable by construction: a move undone is the same kind of move made back
## (`apply` of the reverse restores `at` and `tw` exactly), so a board dealt by
## a walk away from a crossing-free layout has that walk backwards as a way
## home. The way home is then *measured*: a beam search finds a short answer,
## and its length is the board's par.
##
## Spec: docs/superpowers/specs/2026-09-29-untangle-knots-design.md.

## Per band: holes, ropes, the walk's moves, the fewest crossings a deal may
## open with, the fewest moves its best answer may take (par), the most times
## a dealt pair may be wrapped, how many pairs may be wrapped at all (twice
## round or more: "knots") and the most crossings a deal may hold -- a ring
## has to stay readable -- how far a rope may reach beyond what its solved
## span needs, the smallest reach as a share of half the ring, the thread a
## Hard or Insane board is given beyond par, and whether the kitten is loose.
const BANDS := [
	{"holes": 10, "ropes": 4, "moves": 3, "cross": 2, "par": 3, "wrap": 1, "knots": 0, "most": 6, "extra": 9, "min_reach": 1.0, "slack": 0, "cat": false},
	{"holes": 13, "ropes": 6, "moves": 5, "cross": 4, "par": 5, "wrap": 2, "knots": 1, "most": 10, "extra": 3, "min_reach": 0.6, "slack": 0, "cat": false},
	{"holes": 17, "ropes": 8, "moves": 6, "cross": 7, "par": 6, "wrap": 2, "knots": 2, "most": 13, "extra": 2, "min_reach": 0.5, "slack": 4, "cat": false},
	{"holes": 19, "ropes": 9, "moves": 8, "cross": 8, "par": 8, "wrap": 3, "knots": 3, "most": 16, "extra": 2, "min_reach": 0.5, "slack": 3, "cat": true},
]
## A dealt rope is wrapped round two others at most: more and it is a snarl
## nobody can read.
const WRAPS_PER_ROPE := 2
## The kitten swipes after every this many of the player's moves.
const CAT_EVERY := 3
## A deal tries this many walks at most, then keeps the best. A count, not a
## clock: the same day has to deal the same board on a slow phone and a fast one.
const TRIES := 14
## The beam search's width and how deep it goes.
const BEAM := 30
const BEAM_DEPTH := 20
## A hint's search is narrower: a first step, not a par.
const HINT_BEAM := 18

# --- the rule ---

static func chord(n: int, a: int, b: int) -> int:
	var d := absi(a - b)
	return mini(d, n - d)

## True when the chord from `a` to `b` and the chord from `c` to `d` cross:
## exactly one of c, d lies strictly between a and b. Holes are distinct.
## Also: a peg carried from `a` to `b` passes over the rope from `c` to `d`.
static func crosses(a: int, b: int, c: int, d: int) -> bool:
	var lo := mini(a, b)
	var hi := maxi(a, b)
	return (c > lo and c < hi) != (d > lo and d < hi)

static func pair_count(ropes: int) -> int:
	return ropes * (ropes - 1) / 2

## The slot of the pair (r, s) in `tw`, either order.
static func pair_index(r: int, s: int, ropes: int) -> int:
	var a := mini(r, s)
	var b := maxi(r, s)
	return a * ropes - a * (a + 1) / 2 + (b - a - 1)

## The pair a slot stands for, low rope first.
static func pair_of(k: int, ropes: int) -> Vector2i:
	var a := 0
	while k >= ropes - 1 - a:
		k -= ropes - 1 - a
		a += 1
	return Vector2i(a, a + 1 + k)

static func empty_tangle(ropes: int) -> PackedInt32Array:
	var tw := PackedInt32Array()
	tw.resize(pair_count(ropes))
	tw.fill(0)
	return tw

## How many times a pair crosses.
static func count(tw: PackedInt32Array, k: int) -> int:
	return tw[k] >> 1

## True when B's end `f` is the one nearest A's end 0 across an evenly wrapped
## pair: {a0, bf} and {a1, the other} are the two non-crossing pairs.
static func _with_a0(at: PackedInt32Array, a: int, b: int, f: int) -> bool:
	return not crosses(at[2 * a], at[2 * b + f], at[2 * a + 1], at[2 * b + (1 - f)])

## Whether rope `x`'s end `e` lies on top at its nearest crossing with rope
## `y`: 1 over, 0 under, -1 when the pair does not cross.
static func top_at(at: PackedInt32Array, tw: PackedInt32Array, ropes: int, x: int, e: int, y: int) -> int:
	var k := pair_index(x, y, ropes)
	var n := tw[k] >> 1
	if n == 0:
		return -1
	var t := tw[k] & 1
	if x < y:
		return t if (e == 0 or n % 2 == 1) else 1 - t
	if n % 2 == 1:
		return 1 - t
	return (1 - t) if _with_a0(at, y, x, e) else t

## Along rope A (the lower index) from its end 0, the pair's crossings as A
## over (1) or under (0): they alternate.
static func run_of(tw: PackedInt32Array, k: int) -> PackedInt32Array:
	var n := tw[k] >> 1
	var t := tw[k] & 1
	var out := PackedInt32Array()
	for i in n:
		out.append(t if i % 2 == 0 else 1 - t)
	return out

## Peg `peg` carried over the top from its hole to `hole`: `at` and `tw`
## change in place. Returns the change in crossings (negative: some undone).
## The hole must be free; reach is the caller's.
static func apply(at: PackedInt32Array, tw: PackedInt32Array, ropes: int, peg: int, hole: int) -> int:
	var x := peg >> 1
	var e := peg & 1
	var from := at[peg]
	var before := at.duplicate()
	at[peg] = hole
	var delta := 0
	for y in ropes:
		if y == x or not crosses(from, hole, at[2 * y], at[2 * y + 1]):
			continue
		var k := pair_index(x, y, ropes)
		var n := tw[k] >> 1
		var cur := top_at(before, tw, ropes, x, e, y)
		var push := n == 0 or cur == 0
		var n2 := n + 1 if push else n - 1
		# The mover's own side of the crossing nearest its end, afterwards: on
		# top of a new one, or under the next one in (they alternate).
		var req := 1 if push else 0
		var t2 := 0
		if n2 > 0:
			if x < y:
				if n2 % 2 == 1:
					t2 = req
				else:
					t2 = req if e == 0 else 1 - req
			else:
				if n2 % 2 == 1:
					t2 = 1 - req
				else:
					t2 = (1 - req) if _with_a0(at, y, x, e) else req
		tw[k] = n2 * 2 + t2
		delta += 1 if push else -1
	return delta

## The tangle of a layout nobody has wrapped: each interleaving pair crosses
## once, the rope listed later on top.
static func plain_tangle(at: PackedInt32Array, ropes: int) -> PackedInt32Array:
	var tw := empty_tangle(ropes)
	for r in ropes:
		for s in range(r + 1, ropes):
			if crosses(at[2 * r], at[2 * r + 1], at[2 * s], at[2 * s + 1]):
				tw[pair_index(r, s, ropes)] = 2
	return tw

static func crossing_count(tw: PackedInt32Array) -> int:
	var total := 0
	for v in tw:
		total += v >> 1
	return total

## The most times any one pair is wrapped: no answer is shorter, since a move
## changes a pair's count by one at most.
static func deepest(tw: PackedInt32Array) -> int:
	var most := 0
	for v in tw:
		most = maxi(most, v >> 1)
	return most

## The most other ropes any one rope is wrapped round (twice or more).
static func most_wraps(tw: PackedInt32Array, ropes: int) -> int:
	var per := PackedInt32Array()
	per.resize(ropes)
	var k := 0
	var most := 0
	for r in ropes:
		for s in range(r + 1, ropes):
			if (tw[k] >> 1) >= 2:
				per[r] += 1
				per[s] += 1
				most = maxi(most, maxi(per[r], per[s]))
			k += 1
	return most

## How many pairs are wrapped round each other (cross twice or more).
static func knots(tw: PackedInt32Array) -> int:
	var total := 0
	for v in tw:
		if (v >> 1) >= 2:
			total += 1
	return total

static func is_solved(tw: PackedInt32Array) -> bool:
	for v in tw:
		if v != 0:
			return false
	return true

## Every pair that crosses, as rope indices low first.
static func crossing_pairs(tw: PackedInt32Array, ropes: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for k in tw.size():
		if tw[k] != 0:
			out.append(pair_of(k, ropes))
	return out

## Each rope's crossings as a bit mask of the ropes it crosses.
static func _adjacency(tw: PackedInt32Array, ropes: int) -> PackedInt32Array:
	var adj := PackedInt32Array()
	adj.resize(ropes)
	var k := 0
	for r in ropes:
		for s in range(r + 1, ropes):
			if tw[k] != 0:
				adj[r] |= 1 << s
				adj[s] |= 1 << r
			k += 1
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

## The fewest ropes that touch every crossing.
static func min_cover(tw: PackedInt32Array, ropes: int) -> int:
	return _cover(_adjacency(tw, ropes), (1 << ropes) - 1, ropes)

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

## How far a layout looks from home, for the search: every crossing, the
## ropes that must move, and the deepest wrap (each a floor on the moves left).
static func score(tw: PackedInt32Array, ropes: int) -> int:
	return min_cover(tw, ropes) * 300 + deepest(tw) * 300 + crossing_count(tw) * 40

## A beam search from (`at`, `tw`) to any crossing-free layout: each depth
## keeps the `width` layouts that look nearest home. Not the shortest answer
## for certain, but always a real one. Returns the moves [[peg, from, to], ...]
## ([] when already solved), or null when none was found within `depth` moves.
## With the kitten loose (`every` > 0) she swipes after every `every`th move
## counted from `moves0`, as `swipes` says, and the search plays her in.
static func way_home(at: PackedInt32Array, tw: PackedInt32Array, holes: int, ropes: int, reach: PackedInt32Array,
		depth := BEAM_DEPTH, width := BEAM, rng: RandomNumberGenerator = null,
		swipes := {}, every := 0, moves0 := 0) -> Variant:
	if is_solved(tw):
		return []
	var seen := {_key(at, tw, every, moves0): true}
	# Each entry: [score, at, tw, path].
	var beam: Array = [[0, at, tw, []]]
	for d in depth:
		var next: Array = []
		var j := moves0 + d + 1
		for entry in beam:
			var here: PackedInt32Array = entry[1]
			var here_tw: PackedInt32Array = entry[2]
			for m in legal_moves(here, holes, reach):
				var nxt := here.duplicate()
				var nxt_tw := here_tw.duplicate()
				apply(nxt, nxt_tw, ropes, m[0], m[1])
				var path: Array = (entry[3] as Array).duplicate()
				path.append([m[0], here[m[0]], m[1]])
				if is_solved(nxt_tw):
					return path
				if every > 0 and j % every == 0:
					var p: int = swipes.get(j, swipe_fallback(j, nxt.size()))
					var to := cat_hole(nxt, holes, reach, p)
					if to >= 0:
						apply(nxt, nxt_tw, ropes, p, to)
						if is_solved(nxt_tw):
							return path
				var key := _key(nxt, nxt_tw, every, j)
				if seen.has(key):
					continue
				seen[key] = true
				var jitter := rng.randi_range(0, 9) if rng != null else 0
				next.append([score(nxt_tw, ropes) + jitter, nxt, nxt_tw, path])
		if next.is_empty():
			return null
		next.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
		beam = next.slice(0, width)
	return null

## A layout as a dictionary key; with the kitten loose it carries where the
## count stands in her cycle, since the same layout plays out differently
## before a swipe and after one.
static func _key(at: PackedInt32Array, tw: PackedInt32Array, every: int, j: int) -> PackedByteArray:
	var k := at.to_byte_array()
	k.append_array(tw.to_byte_array())
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

## The next step away from home: a legal move of a rope other than the last
## one moved, that wraps no pair deeper than the band allows, scored by how
## much it deepens the tangle (the ropes that must move first, the wraps, then
## the crossings), ropes not yet moved preferred; the best is taken. [] when
## nothing is legal.
static func _pick_away(rng: RandomNumberGenerator, at: PackedInt32Array, tw: PackedInt32Array, cfg: Dictionary,
		reach: PackedInt32Array, moved: Dictionary, last_rope: int) -> Array:
	var ropes: int = cfg.ropes
	var options := legal_moves(at, cfg.holes, reach)
	for i in range(options.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = options[i]; options[i] = options[j]; options[j] = tmp
	var base := score(tw, ropes)
	var best: Array = []
	var best_score := -100000
	for m in options:
		var rope: int = m[0] >> 1
		if rope == last_rope:
			continue
		var nxt := at.duplicate()
		var nxt_tw := tw.duplicate()
		apply(nxt, nxt_tw, ropes, m[0], m[1])
		if deepest(nxt_tw) > int(cfg.wrap) or knots(nxt_tw) > int(cfg.knots) or crossing_count(nxt_tw) > int(cfg.most) \
				or most_wraps(nxt_tw, ropes) > WRAPS_PER_ROPE:
			continue
		var s := score(nxt_tw, ropes) - base + rng.randi_range(0, 60)
		if moved.has(rope):
			s -= 150
		if s > best_score:
			best_score = s
			best = m
	return best

## The layout dealt: legal moves out of the solved layout, each one chosen to
## deepen the tangle. Returns {"start", "tw", "plan"} (the walk backwards,
## [peg, from, to] steps) or {} when the walk is a dud.
static func _scramble(rng: RandomNumberGenerator, goal: Dictionary, cfg: Dictionary) -> Dictionary:
	var at: PackedInt32Array = goal.at.duplicate()
	var tw := empty_tangle(cfg.ropes)
	var moved := {}
	var last_rope := -1
	var plan: Array = []
	for step in int(cfg.moves):
		var chosen := _pick_away(rng, at, tw, cfg, goal.reach, moved, last_rope)
		if chosen.is_empty():
			return {}
		plan.push_front([chosen[0], chosen[1], at[chosen[0]]])
		apply(at, tw, cfg.ropes, chosen[0], chosen[1])
		last_rope = chosen[0] >> 1
		moved[last_rope] = true
	return {"start": at, "tw": tw, "plan": plan}

## Insane's deal, built backwards so the kitten's swipes are part of the
## answer: from the solved layout, undo the player's last move, then (when a
## swipe follows the move before it) undo her swipe, and so on to the start.
## A move undone is a move made back, so each step backwards is `apply`.
## Returns {"start", "tw", "plan", "swipes"} or {} when a step has no way back.
## Plan entries are [peg, from, to].
static func _cat_deal(rng: RandomNumberGenerator, goal: Dictionary, cfg: Dictionary) -> Dictionary:
	var holes: int = cfg.holes
	var ropes: int = cfg.ropes
	var reach: PackedInt32Array = goal.reach
	var at: PackedInt32Array = goal.at.duplicate()
	var tw := empty_tangle(ropes)
	var total: int = cfg.moves
	var plan: Array = []
	var swipes := {}   # move number j -> the peg she bats after it
	var moved := {}
	var last_rope := -1
	for j in range(total, 0, -1):
		var chosen := _pick_away(rng, at, tw, cfg, reach, moved, last_rope)
		if chosen.is_empty():
			return {}
		plan.push_front([chosen[0], chosen[1], at[chosen[0]]])
		apply(at, tw, ropes, chosen[0], chosen[1])
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
					if cat_hole(back, holes, reach, p) != h:
						continue
					var back_tw := tw.duplicate()
					var check := at.duplicate()
					apply(check, back_tw, ropes, p, a)
					if deepest(back_tw) > int(cfg.wrap) + 1 or knots(back_tw) > int(cfg.knots) + 1 or crossing_count(back_tw) > int(cfg.most) + 2 \
							or most_wraps(back_tw, ropes) > WRAPS_PER_ROPE:
						continue
					at = check
					tw = back_tw
					swipes[done] = p
					swiped = true
					break
				if swiped:
					break
			if not swiped:
				return {}
	return {"start": at, "tw": tw, "plan": plan, "swipes": swipes}

## `plan` played forward from the start, her swipes included, to the layout
## it ends in: [at, tw].
static func play(start: PackedInt32Array, start_tw: PackedInt32Array, plan: Array, cfg: Dictionary,
		reach: PackedInt32Array, swipes: Dictionary) -> Array:
	var at := start.duplicate()
	var tw := start_tw.duplicate()
	for j in plan.size():
		apply(at, tw, cfg.ropes, plan[j][0], plan[j][2])
		if is_solved(tw):
			break
		if cfg.cat and (j + 1) % CAT_EVERY == 0:
			var p: int = swipes.get(j + 1, swipe_fallback(j + 1, at.size()))
			var to := cat_hole(at, cfg.holes, reach, p)
			if to >= 0:
				apply(at, tw, cfg.ropes, p, to)
				if is_solved(tw):
					break
	return [at, tw]

## Plays the answer forward with the kitten, from the start, and says whether
## it ends solved after exactly the planned number of moves, and not before.
static func _replays(start: PackedInt32Array, start_tw: PackedInt32Array, reach: PackedInt32Array, cfg: Dictionary, deal: Dictionary) -> bool:
	var holes: int = cfg.holes
	var ropes: int = cfg.ropes
	var at := start.duplicate()
	var tw := start_tw.duplicate()
	var plan: Array = deal.plan
	var swipes: Dictionary = deal.swipes
	for j in plan.size():
		var m: Array = plan[j]
		if not fits(at, holes, reach, m[0], m[2], occupancy(at, holes)):
			return false
		apply(at, tw, ropes, m[0], m[2])
		if is_solved(tw):
			return j == plan.size() - 1
		var done := j + 1
		if swipes.has(done):
			var to := cat_hole(at, holes, reach, swipes[done])
			if to < 0:
				return false
			apply(at, tw, ropes, swipes[done], to)
	return is_solved(tw)

## The board dealt when every walk of a band was a dud: a band-0 walk that is
## really tangled and, failing even that, two ropes that cross once.
static func _fallback(rng: RandomNumberGenerator) -> Dictionary:
	var easy: Dictionary = BANDS[0]
	for attempt in 200:
		var goal := _goal(rng, easy)
		var deal := _scramble(rng, goal, easy)
		if deal.is_empty() or crossing_count(deal.tw) < 1:
			continue
		var plan = way_home(deal.start, deal.tw, easy.holes, easy.ropes, goal.reach)
		if plan == null:
			continue
		var end := play(deal.start, deal.tw, plan, easy, goal.reach, {})
		return {"holes": easy.holes, "ropes": easy.ropes, "start": deal.start, "tw": deal.tw, "goal": end[0],
			"reach": goal.reach, "plan": plan, "par": plan.size(), "budget": 0, "cat": false, "swipes": {}}
	var at := PackedInt32Array([0, 2, 1, 3])
	return {"holes": 10, "ropes": 2, "start": at, "tw": plain_tangle(at, 2), "goal": PackedInt32Array([0, 2, 4, 3]),
		"reach": PackedInt32Array([5, 5]), "plan": [[2, 1, 4]], "par": 1, "budget": 0, "cat": false, "swipes": {}}

## One full board for `band`: {"holes", "ropes", "start", "tw", "goal",
## "reach", "plan", "par", "budget", "cat", "swipes", "order"}. `plan` is an
## answer, as [peg, from, to] moves.
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
		var start_tw: PackedInt32Array = deal.tw
		if crossing_count(start_tw) < int(cfg.cross):
			continue
		var plan: Array
		var swipes: Dictionary = deal.get("swipes", {})
		if cfg.cat:
			if not _replays(start, start_tw, goal.reach, cfg, deal):
				continue
			plan = deal.plan
			# The deal's own answer is only one way; the search, with her
			# swipes played in, may find a shorter one, and that is what par
			# and the thread are measured against.
			var found = way_home(start, start_tw, cfg.holes, ropes, goal.reach, BEAM_DEPTH, BEAM, rng, swipes, CAT_EVERY, 0)
			if found != null and found.size() < plan.size():
				plan = found
		else:
			plan = deal.plan
			var found = way_home(start, start_tw, cfg.holes, ropes, goal.reach, BEAM_DEPTH, BEAM, rng)
			if found != null and found.size() < plan.size():
				plan = found
		var par := plan.size()
		if par > best_par:
			best_par = par
			var end := play(start, start_tw, plan, cfg, goal.reach, swipes)
			best = {"holes": cfg.holes, "ropes": ropes, "start": start, "tw": start_tw, "goal": end[0],
				"reach": goal.reach, "plan": plan, "par": par,
				"budget": (par + int(cfg.slack)) if int(cfg.slack) > 0 else 0,
				"cat": cfg.cat, "swipes": swipes}
		if par >= int(cfg.par):
			break
	if best.is_empty():
		best = _fallback(rng)
	# The stack the ropes lie in, bottom to top, where no crossing says
	# otherwise.
	var order: Array = range(best.ropes)
	for i in range(order.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = order[i]; order[i] = order[j]; order[j] = tmp
	best["order"] = order
	return best
