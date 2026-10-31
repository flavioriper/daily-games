extends RefCounted

## Toy Boats' tricks and streak, the computer's games only. The rules
## (versus/boats_rules.gd) and the wire are one pebble a turn, and online stays
## that: a trick queue on a match is a rules deploy (docs/agents/versus.md).
## So this is a layer over the rules: a trick is several ordinary pebbles.
##
## Three boats each carry one trick, once a game, and take it down with them:
## the Barge's **Scatter** (five pebbles in a plus), the Ferry's **Spyglass**
## (how many boat squares lie in a 3 x 3, a free look that costs no throw) and
## the Tugboat's **Skipper** (a pebble skipping up a column, four squares at
## most, stopping on the first hit). The computer throws the first and the
## third; a count on a slate is nothing its levels can read.

const Rules = preload("res://versus/boats_rules.gd")
const AI = preload("res://versus/boats_ai.gd")

const SCATTER := 1
const GLASS := 2
const SKIP := 4
const ALL := SCATTER | GLASS | SKIP
const KINDS := [SCATTER, GLASS, SKIP]
## Who carries which: an index into Rules.FLEET.
const CARRIER := {SCATTER: 0, GLASS: 1, SKIP: 2}
const SKIPS := 4
## From this many pebbles thrown the computer starts on its tricks, one time
## in this many tries by level, when it has nothing to follow up.
const BOT_FROM := 6
const BOT_ODDS := [0.25, 0.4, 0.6]

## What is left of `stock` (a mask) once the boats gone have taken theirs.
static func left(stock: int, sunk: Array) -> int:
	var out := stock
	for kind: int in KINDS:
		if sunk[CARRIER[kind]]:
			out &= ~kind
	return out

## The squares `kind` covers from `c`, in the order they land, tried or not.
static func cover(kind: int, c: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	var at := Rules.xy(c)
	var near: Array[Vector2i] = []
	match kind:
		SCATTER:
			near = [Vector2i.ZERO, Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
		GLASS:
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					near.append(Vector2i(dx, dy))
		SKIP:
			for k in SKIPS:
				near.append(Vector2i(0, -k))
		_:
			near = [Vector2i.ZERO]
	for d in near:
		var q := at + d
		if q.x >= 0 and q.y >= 0 and q.x < Rules.N and q.y < Rules.N:
			out.append(Rules.cell(q.x, q.y))
	return out

## The squares of `cover` a pebble can still land on.
static func fresh(kind: int, c: int, marks: PackedByteArray) -> PackedInt32Array:
	var out := PackedInt32Array()
	for q in cover(kind, c):
		if marks[q] == Rules.UNKNOWN:
			out.append(q)
	return out

## How many boat squares a pond whose boats are known holds under `cells`.
static func count(pond: RefCounted, cells: PackedInt32Array) -> int:
	var n := 0
	for q in cells:
		if pond.boat_at(q) >= 0:
			n += 1
	return n

## The pebbles a throw at `c` becomes against a pond whose boats are known,
## each fired there and written on `chart`: [{c, r, boat, b}], in landing
## order. A plain throw is one, a Skipper ends on its first hit.
static func volley(kind: int, c: int, pond: RefCounted, chart: RefCounted) -> Array:
	var out := []
	for q in fresh(kind, c, chart.marks):
		var a: Dictionary = pond.fire(q)
		var b: Vector3i = pond.boats[a.boat] if int(a.r) == Rules.SUNK else Rules.HIDDEN
		chart.note(q, a.r, a.boat, b)
		out.append({"c": q, "r": a.r, "boat": a.boat, "b": b})
		if kind == SKIP and int(a.r) != Rules.MISS:
			break
	return out

## The computer's trick for this turn, {kind, c}, or empty for a plain throw:
## never with a hit to finish, and at the square the board's own counting
## likes best for that shape.
static func plan(chart: RefCounted, level: int, stock: int, rng: RandomNumberGenerator) -> Dictionary:
	if chart.shots < BOT_FROM or not chart.open_hits().is_empty():
		return {}
	if rng.randf() >= float(BOT_ODDS[clampi(level, 0, 2)]):
		return {}
	var kinds: Array[int] = []
	for kind: int in [SCATTER, SKIP]:
		if stock & kind != 0:
			kinds.append(kind)
	if kinds.is_empty():
		return {}
	var kind: int = kinds[rng.randi() % kinds.size()]
	var score: PackedFloat32Array = AI.density(chart)
	var best := -1
	var top := -1.0
	for c in Rules.CELLS:
		if chart.marks[c] != Rules.UNKNOWN:
			continue
		var s := 0.0
		for q in fresh(kind, c, chart.marks):
			s += score[q]
		s *= 1.0 + rng.randf() * (0.08 if level >= 2 else 0.6)
		if s > top:
			top = s
			best = c
	return {} if best < 0 else {"kind": kind, "c": best}
