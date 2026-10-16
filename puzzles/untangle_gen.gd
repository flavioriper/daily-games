extends RefCounted

## Untangle. A plate of N peg holes (a ring, a hoop or a drilled board:
## untangle_plate.gd); R ropes, each ending in two pegs; N - 2R holes stand
## empty. A move lifts one peg out of its hole, carries it *over* everything
## and drops it in an empty hole, so its rope goes with it.
##
## The tangle is made of real crossings: where two ropes cross, one lies on
## top. Each pair of ropes keeps how many times it crosses (`n`) and, since a
## twisted pair's crossings alternate over and under along each rope, which
## rope is on top at each end of that run of crossings. A peg carried over the
## top past another rope does one of two things there, as a real cord would:
##
## * if its rope was the one on top at the crossing nearest this end, lifting
##   it takes that crossing out (the cord slides off: n - 1);
## * if its rope lay *under* there, the cord comes round over the top and the
##   two are wrapped once more (n + 1).
##
## A carry passes a rope when the carried rope's straight line, from its other
## peg, crosses that rope before the move and not after, or after and not
## before. On a ring or a hoop that is the peg's own way crossing the rope; on
## a board it is also the rope sweeping past one of the other rope's pegs.
## Either way a pair's count is odd exactly when the two ropes' straight
## lines cross, from the deal to the end.
##
## A rope that crosses nothing has come free: it leaves the plate with both
## its pegs (`retire`), its holes stand empty and nothing can be carried over
## it again. Its pegs read -1 in `at`. The board is undone when every rope has
## left, which is the same as no pair crossing at all.
##
## The rule lives on plain int arrays: `at[peg]` = hole (peg = 2 * rope + end)
## and `tw[pair]` = n * 2 + t, where for the pair (A, B), A < B, `t` is 1 when
## A is on top at the crossing nearest A's end 0. Which of B's ends is nearest
## that crossing is read off the holes when it matters (an even count): the
## way of joining the four pegs in two pairs that do not cross, the shorter
## one when both do not (`_first_with`).
##
## Solvable by construction: a move undone is the same kind of move made back
## (`apply` of the reverse restores `at` and `tw` exactly), so a board dealt by
## a walk away from a crossing-free layout has that walk backwards as a way
## home -- and still has with ropes leaving, since a pair's crossings depend on
## those two ropes' moves alone: the walk less the moves of ropes already gone
## undoes the rest (`_replay`). The way home is then *measured*: a beam search
## that plays the leaving in finds a short answer, and its length is the
## board's par.
##
## Spec: docs/superpowers/specs/2026-10-16-untangle-plates-design.md (the
## plates), docs/superpowers/specs/2026-09-29-untangle-knots-design.md (the
## knots).

const Plate = preload("res://puzzles/untangle_plate.gd")

## Per band, the plates a day may be dealt on, each with its ropes; then the
## walk's moves, the fewest crossings a deal may open with, the fewest moves
## its best answer may take (par), the most times a dealt pair may be wrapped,
## how many pairs may be wrapped at all (twice round or more: "knots") and the
## most crossings a deal may hold -- a plate has to stay readable -- how far
## a rope may reach beyond what its solved span needs (in hole spacings), the
## smallest reach as a share of the plate's widest span, and the thread a day
## is given beyond par (0: no thread).
const BANDS := [
	{"plates": [["ring:10", 4], ["square:12", 5], ["hex:12", 5], ["tri:12", 5]],
		"moves": 3, "cross": 2, "par": 3, "wrap": 1, "knots": 0, "most": 6, "extra": 9.0, "min_reach": 1.0, "slack": 0},
	{"plates": [["ring:13", 6], ["square:16", 7], ["tri:15", 7]],
		"moves": 5, "cross": 4, "par": 5, "wrap": 2, "knots": 1, "most": 10, "extra": 1.6, "min_reach": 0.6, "slack": 0},
	{"plates": [["honey:19", 8], ["grid:5x4", 9]],
		"moves": 6, "cross": 7, "par": 6, "wrap": 2, "knots": 2, "most": 13, "extra": 1.2, "min_reach": 0.5, "slack": 0},
	{"plates": [["grid:5x5", 11], ["honey:23", 10]],
		"moves": 10, "cross": 12, "par": 10, "wrap": 3, "knots": 4, "most": 22, "extra": 1.2, "min_reach": 0.45, "slack": 0},
]
## A dealt rope is wrapped round two others at most: more and it is a snarl
## nobody can read.
const WRAPS_PER_ROPE := 2
## A deal searches this many walks at most for their par, then keeps the
## best, and makes `WALKS` walks at most looking for ones worth the search (a
## walk is cheap, the search is not). Counts, not a clock: the same day has to
## deal the same board on a slow phone and a fast one.
const TRIES := 14
const WALKS := 70
## The beam search's width and how deep it goes.
const BEAM := 30
const BEAM_DEPTH := 20
## A hint's search is narrower: a first step, not a par.
const HINT_BEAM := 18
## The last walks of a deal take a board with a rope that starts free, or one
## whose walk backwards no longer plays forwards.
const SPARE_WALKS := 12

# --- the rule ---

## True when the rope from hole a to hole b and the rope from c to d cross.
## Also: a peg carried from `a` to `b` passes over the rope from `c` to `d`.
static func crosses(pl: Plate, a: int, b: int, c: int, d: int) -> bool:
	return pl.crosses(a, b, c, d)

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

## True when, of the two ways to join pegs a0, a1 (one rope) to bf, bo (the
## other), {a0, bf} and {a1, bo} is the one whose joins do not cross; when
## neither crosses (the four not in a ring), the shorter.
static func _first_with(pl: Plate, a0: int, a1: int, bf: int, bo: int) -> bool:
	var c1 := pl.crosses(a0, bf, a1, bo)
	var c2 := pl.crosses(a0, bo, a1, bf)
	if c1 != c2:
		return not c1
	return pl.dist(a0, bf) + pl.dist(a1, bo) <= pl.dist(a0, bo) + pl.dist(a1, bf)

## The same with `bf` a point in the air (plate units).
static func _first_with_at(pl: Plate, a0: int, a1: int, bf: Vector2, bo: int) -> bool:
	var p0 := pl.pts[a0]
	var p1 := pl.pts[a1]
	var po := pl.pts[bo]
	var c1 := Plate.seg_cross(p0, bf, p1, po)
	var c2 := Plate.seg_cross(p0, po, p1, bf)
	if c1 != c2:
		return not c1
	return p0.distance_to(bf) + p1.distance_to(po) <= p0.distance_to(po) + p1.distance_to(bf)

## True when B's end `f` is the one nearest A's end 0 across an evenly wrapped
## pair.
static func _with_a0(pl: Plate, at: PackedInt32Array, a: int, b: int, f: int) -> bool:
	return _first_with(pl, at[2 * a], at[2 * a + 1], at[2 * b + f], at[2 * b + (1 - f)])

## Whether rope `x`'s end `e` lies on top at its nearest crossing with rope
## `y`: 1 over, 0 under, -1 when the pair does not cross.
static func top_at(pl: Plate, at: PackedInt32Array, tw: PackedInt32Array, ropes: int, x: int, e: int, y: int) -> int:
	var k := pair_index(x, y, ropes)
	var n := tw[k] >> 1
	if n == 0:
		return -1
	var t := tw[k] & 1
	if x < y:
		return t if (e == 0 or n % 2 == 1) else 1 - t
	if n % 2 == 1:
		return 1 - t
	return (1 - t) if _with_a0(pl, at, y, x, e) else t

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
static func apply(pl: Plate, at: PackedInt32Array, tw: PackedInt32Array, ropes: int, peg: int, hole: int) -> int:
	var delta := _carry(pl, at, tw, ropes, peg, hole, Vector2.ZERO)
	at[peg] = hole
	return delta

## The rule for a peg still in the air: carried from its hole over the top to
## `to` (plate units, the hand). `tw` changes in place, `at` does not. The
## board runs it every frame a peg is carried, so the ropes wrap and slide off
## under the hand, not at the drop; carried onto a hole it is `apply`.
static func apply_toward(pl: Plate, at: PackedInt32Array, tw: PackedInt32Array, ropes: int, peg: int, to: Vector2) -> int:
	return _carry(pl, at, tw, ropes, peg, -1, to)

## The rule, toward hole `hole`, or toward the point `tp` when `hole` < 0.
static func _carry(pl: Plate, at: PackedInt32Array, tw: PackedInt32Array, ropes: int, peg: int, hole: int, tp: Vector2) -> int:
	var x := peg >> 1
	var e := peg & 1
	var from := at[peg]
	var other := at[peg ^ 1]
	var po := pl.pts[other]
	var delta := 0
	for y in ropes:
		if y == x or at[2 * y] < 0:
			continue
		var y0 := at[2 * y]
		var y1 := at[2 * y + 1]
		var was := pl.crosses(other, from, y0, y1)
		var now := pl.crosses(other, hole, y0, y1) if hole >= 0 else Plate.seg_cross(po, tp, pl.pts[y0], pl.pts[y1])
		if was == now:
			continue
		var k := pair_index(x, y, ropes)
		var n := tw[k] >> 1
		var cur := top_at(pl, at, tw, ropes, x, e, y)
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
					# _with_a0 with the mover's end where it is going.
					var with0 := _first_with(pl, y0, y1, hole, other) if hole >= 0 else _first_with_at(pl, y0, y1, tp, other)
					t2 = (1 - req) if with0 else req
		tw[k] = n2 * 2 + t2
		delta += 1 if push else -1
	return delta

## The tangle of a layout nobody has wrapped: each crossing pair crosses
## once, the rope listed later on top.
static func plain_tangle(pl: Plate, at: PackedInt32Array, ropes: int) -> PackedInt32Array:
	var tw := empty_tangle(ropes)
	for r in ropes:
		for s in range(r + 1, ropes):
			if pl.crosses(at[2 * r], at[2 * r + 1], at[2 * s], at[2 * s + 1]):
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

## True when rope `r` has left the plate.
static func gone(at: PackedInt32Array, r: int) -> bool:
	return at[2 * r] < 0

## Every rope still on the plate that crosses nothing leaves it: its pegs go
## to -1 in `at`. Returns the ropes that left, lowest first.
static func retire(at: PackedInt32Array, tw: PackedInt32Array, ropes: int) -> Array:
	var busy := 0
	var k := 0
	for r in ropes:
		for s in range(r + 1, ropes):
			if tw[k] != 0:
				busy |= (1 << r) | (1 << s)
			k += 1
	var out: Array = []
	for r in ropes:
		if at[2 * r] >= 0 and (busy >> r) & 1 == 0:
			at[2 * r] = -1
			at[2 * r + 1] = -1
			out.append(r)
	return out

## How many ropes are still on the plate.
static func ropes_left(at: PackedInt32Array) -> int:
	var n := 0
	for r in at.size() / 2:
		if at[2 * r] >= 0:
			n += 1
	return n

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
		if at[p] >= 0:
			occ[at[p]] = p
	return occ

## Whether peg `p` may be dropped in `hole`: the hole is free and the rope it
## is on reaches that far.
static func fits(pl: Plate, at: PackedInt32Array, reach: PackedFloat32Array, p: int, hole: int, occ: PackedInt32Array) -> bool:
	return at[p] >= 0 and hole != at[p] and occ[hole] < 0 and pl.dist(hole, at[p ^ 1]) <= reach[p >> 1]

## Every legal move from `at` as [peg, hole].
static func legal_moves(pl: Plate, at: PackedInt32Array, reach: PackedFloat32Array) -> Array:
	var occ := occupancy(at, pl.n)
	var free := PackedInt32Array()
	for h in pl.n:
		if occ[h] < 0:
			free.append(h)
	var out: Array = []
	for p in at.size():
		if at[p] < 0:
			continue
		var far := at[p ^ 1]
		var most := reach[p >> 1]
		for h in free:
			if pl.dist(h, far) <= most:
				out.append([p, h])
	return out

# --- a short way home ---

## How far a layout looks from home, for the search: every crossing, the
## ropes that must move, and the deepest wrap (each a floor on the moves left).
static func score(tw: PackedInt32Array, ropes: int) -> int:
	return min_cover(tw, ropes) * 300 + deepest(tw) * 300 + crossing_count(tw) * 40

## A beam search from (`at`, `tw`) to an empty plate, ropes leaving as they
## come free: each depth keeps the `width` layouts that look nearest home. Not
## the shortest answer for certain, but always a real one. Returns the moves
## [[peg, from, to], ...] ([] when already solved), or null when none was
## found within `depth` moves.
static func way_home(pl: Plate, at: PackedInt32Array, tw: PackedInt32Array, ropes: int, reach: PackedFloat32Array,
		depth := BEAM_DEPTH, width := BEAM, rng: RandomNumberGenerator = null) -> Variant:
	if is_solved(tw):
		return []
	# A layout's score depends on its tangle alone, and most moves leave the
	# tangle as it was: kept per tangle for the length of the search.
	var scores := {}
	var seen := {_key(at, tw): true}
	# Each entry: [at, tw, the entry it came from (or null), the move made].
	var beam: Array = [[at, tw, null, []]]
	for d in depth:
		var next: Array = []
		# Each new layout's score and its place in `next`, as one int, so the
		# sort is the engine's own.
		var ranked := PackedInt64Array()
		var last := d == depth - 1
		for entry in beam:
			var here: PackedInt32Array = entry[0]
			var here_tw: PackedInt32Array = entry[1]
			for m in legal_moves(pl, here, reach):
				var nxt := here.duplicate()
				var nxt_tw := here_tw.duplicate()
				apply(pl, nxt, nxt_tw, ropes, m[0], m[1])
				var step: Array = [m[0], here[m[0]], m[1]]
				# Only a move that changed the tangle can have set a rope free.
				if nxt_tw != here_tw:
					if is_solved(nxt_tw):
						return _path(entry, step)
					retire(nxt, nxt_tw, ropes)
				# The deepest layer is only asked whether it wins.
				if last:
					continue
				var key := _key(nxt, nxt_tw)
				if seen.has(key):
					continue
				seen[key] = true
				var jitter := rng.randi_range(0, 9) if rng != null else 0
				var sc = scores.get(nxt_tw)
				if sc == null:
					sc = score(nxt_tw, ropes)
					scores[nxt_tw] = sc
				ranked.append((int(sc) + jitter) * 65536 + next.size())
				next.append([nxt, nxt_tw, entry, step])
		if next.is_empty():
			return null
		ranked.sort()
		beam = []
		for i in mini(width, ranked.size()):
			beam.append(next[ranked[i] & 65535])
	return null

## The moves that led to `entry`, oldest first, and `step` after them.
static func _path(entry: Array, step: Array) -> Array:
	var out: Array = [step]
	var e = entry
	while e != null and not (e[3] as Array).is_empty():
		out.push_front(e[3])
		e = e[2]
	return out

static func _key(at: PackedInt32Array, tw: PackedInt32Array) -> PackedByteArray:
	var k := at.to_byte_array()
	k.append_array(tw.to_byte_array())
	return k

# --- the deal ---

## A non-crossing pairing of `pts` (holes in order round a ring or hoop): the
## first is tied to a random odd-numbered one, and each side is paired on its
## own. Ropes are nudged toward long spans, which is what tangles.
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

## A non-crossing pairing of holes anywhere on a board: tied at random, then
## any two ties that cross swapped for the two that do not (which is always
## shorter in all, so it ends).
static func _pair_loose(rng: RandomNumberGenerator, pl: Plate, pts: Array) -> Array:
	var order := pts.duplicate()
	for i in range(order.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = order[i]; order[i] = order[j]; order[j] = tmp
	var out: Array = []
	for i in range(0, order.size(), 2):
		out.append([order[i], order[i + 1]])
	var changed := true
	while changed:
		changed = false
		for i in out.size():
			for j in range(i + 1, out.size()):
				var a: int = out[i][0]
				var b: int = out[i][1]
				var c: int = out[j][0]
				var d: int = out[j][1]
				if not pl.crosses(a, b, c, d):
					continue
				if not pl.crosses(a, c, b, d):
					out[i] = [a, c]
					out[j] = [b, d]
				else:
					out[i] = [a, d]
					out[j] = [b, c]
				changed = true
	return out

## A crossing-free layout: which holes stand empty, and who ties to whom.
## Returns {"at": ..., "reach": ...}.
static func _goal(rng: RandomNumberGenerator, pl: Plate, cfg: Dictionary, ropes: int) -> Dictionary:
	var holes: int = pl.n
	var order: Array = range(holes)
	for i in range(order.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = order[i]; order[i] = order[j]; order[j] = tmp
	var empty_count: int = holes - 2 * ropes
	var taken: Array = order.slice(empty_count)
	taken.sort()
	var pairs := _pair_up(rng, taken) if pl.convex else _pair_loose(rng, pl, taken)
	var slots: Array = range(ropes)
	for i in range(slots.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = slots[i]; slots[i] = slots[j]; slots[j] = tmp
	var at := PackedInt32Array()
	at.resize(2 * ropes)
	var reach := PackedFloat32Array()
	reach.resize(ropes)
	var floor_reach := pl.maxd * float(cfg.min_reach)
	for k in pairs.size():
		var r: int = slots[k]
		var a: int = pairs[k][0]
		var b: int = pairs[k][1]
		if rng.randi() % 2 == 0:
			var t := a; a = b; b = t
		at[2 * r] = a
		at[2 * r + 1] = b
		var span := pl.dist(a, b)
		var far := span + rng.randf_range(0.0, float(cfg.extra)) * pl.spacing
		# A hair over, so a hole just at the reach is in it on every phone.
		reach[r] = minf(pl.maxd, maxf(floor_reach, far)) + 1e-4
	return {"at": at, "reach": reach}

## The next step away from home: a legal move of a rope other than the last
## one moved, that wraps no pair deeper than the band allows, scored by how
## much it deepens the tangle (the ropes that must move first, the wraps, then
## the crossings), ropes not yet moved preferred; the best is taken. [] when
## nothing is legal.
static func _pick_away(rng: RandomNumberGenerator, pl: Plate, at: PackedInt32Array, tw: PackedInt32Array, cfg: Dictionary,
		ropes: int, reach: PackedFloat32Array, moved: Dictionary, last_rope: int) -> Array:
	var options := legal_moves(pl, at, reach)
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
		apply(pl, nxt, nxt_tw, ropes, m[0], m[1])
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
static func _scramble(rng: RandomNumberGenerator, pl: Plate, goal: Dictionary, cfg: Dictionary, ropes: int) -> Dictionary:
	var at: PackedInt32Array = goal.at.duplicate()
	var tw := empty_tangle(ropes)
	var moved := {}
	var last_rope := -1
	var plan: Array = []
	for step in int(cfg.moves):
		var chosen := _pick_away(rng, pl, at, tw, cfg, ropes, goal.reach, moved, last_rope)
		if chosen.is_empty():
			return {}
		plan.push_front([chosen[0], chosen[1], at[chosen[0]]])
		apply(pl, at, tw, ropes, chosen[0], chosen[1])
		last_rope = chosen[0] >> 1
		moved[last_rope] = true
	return {"start": at, "tw": tw, "plan": plan}

## `plan` played forward from the start with ropes leaving as they come free:
## the moves really made ([peg, from, to], a move of a rope already gone is
## skipped) when that empties the plate, null when it does not or a move does
## not fit.
static func _replay(pl: Plate, start: PackedInt32Array, start_tw: PackedInt32Array, plan: Array, ropes: int,
		reach: PackedFloat32Array) -> Variant:
	var at := start.duplicate()
	var tw := start_tw.duplicate()
	var out: Array = []
	if is_solved(tw):
		return out
	for m in plan:
		var p: int = m[0]
		if at[p] < 0:
			continue
		if not fits(pl, at, reach, p, m[2], occupancy(at, pl.n)):
			return null
		out.append([p, at[p], m[2]])
		apply(pl, at, tw, ropes, p, m[2])
		if is_solved(tw):
			return out
		retire(at, tw, ropes)
	return null

## The board dealt when every walk of a band was a dud: an Easy ring walk that
## is really tangled and, failing even that, two ropes that cross once.
static func _fallback(rng: RandomNumberGenerator) -> Dictionary:
	var easy: Dictionary = BANDS[0]
	var pl: Plate = Plate.of("ring:10")
	var ropes := 4
	for attempt in 200:
		var goal := _goal(rng, pl, easy, ropes)
		var deal := _scramble(rng, pl, goal, easy, ropes)
		if deal.is_empty() or crossing_count(deal.tw) < 1:
			continue
		var start: PackedInt32Array = deal.start
		retire(start, deal.tw, ropes)
		var plan = way_home(pl, start, deal.tw, ropes, goal.reach)
		if plan == null:
			continue
		return {"plate": pl.id, "holes": pl.n, "ropes": ropes, "start": start, "tw": deal.tw,
			"reach": goal.reach, "plan": plan, "par": plan.size(), "budget": 0}
	var at := PackedInt32Array([0, 2, 1, 3])
	return {"plate": pl.id, "holes": 10, "ropes": 2, "start": at, "tw": plain_tangle(pl, at, 2),
		"reach": PackedFloat32Array([2.0, 2.0]), "plan": [[2, 1, 4]], "par": 1, "budget": 0}

## The plate a band deals on today: one of its list, by the day's draw.
static func pick_plate(rng: RandomNumberGenerator, band: int) -> Array:
	var cfg: Dictionary = BANDS[clampi(band, 0, BANDS.size() - 1)]
	var list: Array = cfg.plates
	return list[rng.randi_range(0, list.size() - 1)]

## One full board for `band`: {"plate", "holes", "ropes", "start", "tw",
## "reach", "plan", "par", "budget", "order"}. `plan` is an answer, as
## [peg, from, to] moves. A rope the walk left crossing nothing is not dealt
## at all (its pegs are -1 in `start`); a deal with one is passed over while
## there are walks to spare, so most days every rope is in the tangle.
## `plate_id` (with its `ropes`) deals on that plate instead of the day's.
static func generate(rng: RandomNumberGenerator, band: int, plate_id := "", plate_ropes := 0) -> Dictionary:
	var cfg: Dictionary = BANDS[clampi(band, 0, BANDS.size() - 1)]
	var choice: Array = pick_plate(rng, band)
	if plate_id != "":
		choice = [plate_id, plate_ropes]
	var pl: Plate = Plate.of(choice[0])
	var ropes: int = choice[1]
	var best: Dictionary = {}
	var best_par := -1
	var searched := 0
	for walk in WALKS:
		var goal := _goal(rng, pl, cfg, ropes)
		var deal := _scramble(rng, pl, goal, cfg, ropes)
		if deal.is_empty():
			continue
		var start: PackedInt32Array = deal.start
		var start_tw: PackedInt32Array = deal.tw
		if crossing_count(start_tw) < int(cfg.cross):
			continue
		var spare := walk >= WALKS - SPARE_WALKS
		var idle := retire(start, start_tw, ropes).size()
		if idle > 0 and not spare:
			continue
		# The walk backwards is one answer (less the moves of ropes that have
		# left by then); a deal whose walk is already shorter than the band's
		# par is passed over while there are walks to spare.
		var plan = _replay(pl, start, start_tw, deal.plan, ropes, goal.reach)
		if not spare and (plan == null or plan.size() < int(cfg.par)):
			continue
		# The search may find a shorter answer, and that is what par and the
		# thread are measured against: it looks only as deep as would beat
		# the walk.
		var depth: int = BEAM_DEPTH if plan == null else plan.size() - 1
		if depth > 0:
			var found = way_home(pl, start, start_tw, ropes, goal.reach, depth, BEAM, rng)
			if found != null:
				plan = found
		searched += 1
		if plan == null:
			continue
		var par: int = plan.size()
		var better := par > best_par
		if not best.is_empty() and idle != int(best.idle):
			better = idle < int(best.idle)
		if better:
			best_par = par
			best = {"plate": pl.id, "holes": pl.n, "ropes": ropes, "start": start, "tw": start_tw,
				"reach": goal.reach, "plan": plan, "par": par,
				"budget": (par + int(cfg.slack)) if int(cfg.slack) > 0 else 0, "idle": idle}
		if (par >= int(cfg.par) and idle == 0) or searched >= TRIES:
			break
	if best.is_empty():
		best = _fallback(rng)
	best.erase("idle")
	# The stack the ropes lie in, bottom to top, where no crossing says
	# otherwise.
	var order: Array = range(best.ropes)
	for i in range(order.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = order[i]; order[i] = order[j]; order[j] = tmp
	best["order"] = order
	return best
