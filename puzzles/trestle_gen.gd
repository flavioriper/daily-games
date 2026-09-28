extends RefCounted

## Trestle's level shapes and the designs the miner proves them with.
##
## A level is a gap `w` wide between two banks, the right one `dy` higher or
## lower, a set of anchors (the two road ends always, plus cliff pins, bank
## posts and a rock in the river on some), the materials on offer, the cart's
## mass and a budget. The phone never grows one: `tools/mine_trestle.gd`
## deals shapes, proves each with a design it finds by pruning a full truss,
## and writes the survivors to `content/trestle.json` with that design, which
## is also what a hint lays in.
## Spec: docs/superpowers/specs/2026-09-28-trestle-flat-design.md.

const Sim = preload("res://puzzles/trestle_sim.gd")

## The longest member: a knight's step (2, 1) fits, (2, 2) does not.
const MAX_LEN := 2.25
## The build zone's rows, below and above the road.
const LO := -4
const HI := 3

## Per band: gap widths, cart mass, budget over the proof's cost, materials.
const BANDS := [
	{"w": [4, 5], "cart": 1.2, "slack": 1.6, "mats": [Sim.ROAD, Sim.WOOD], "dy": [0]},
	{"w": [5, 6, 7], "cart": 1.6, "slack": 1.4, "mats": [Sim.ROAD, Sim.WOOD, Sim.ROPE], "dy": [0, 0, 1, -1]},
	{"w": [7, 8, 9], "cart": 2.0, "slack": 1.25, "mats": [Sim.ROAD, Sim.WOOD, Sim.ROPE], "dy": [0, 1, -1]},
	{"w": [8, 9, 10], "cart": 2.4, "slack": 1.12, "mats": [Sim.ROAD, Sim.WOOD, Sim.ROPE], "dy": [0, 1, -1, 2, -2]},
]

static func deck_y(w: int, dy: int, i: int) -> int:
	if dy == 0:
		return 0
	# one ramp step per unit of rise, centred in the span
	var steps := absi(dy)
	var first := (w - steps) / 2
	return signi(dy) * clampi(i - first + 1, 0, steps) if i > first - 1 else 0

## Is `p` a point a joint may stand on?
static func buildable(level: Dictionary, p: Vector2i) -> bool:
	for a in level.anchors:
		if p == Vector2i(int(a[0]), int(a[1])):
			return true
	var w := int(level.w)
	if p.x <= 0 or p.x >= w or p.y < LO or p.y > HI:
		return false
	var rock = level.get("rock")
	if rock != null and p.x == int(rock[0]) and p.y < int(rock[1]):
		return false
	return true

static func fits(a: Vector2i, b: Vector2i) -> bool:
	return a != b and Vector2(a).distance_to(Vector2(b)) <= MAX_LEN

## Road may climb no steeper than one in one.
static func road_ok(a: Vector2i, b: Vector2i) -> bool:
	return absi(b.y - a.y) <= absi(b.x - a.x)

static func plain_deck(level: Dictionary) -> Array:
	var w := int(level.w)
	var dy := int(level.get("dy", 0))
	var out: Array = []
	for i in w:
		out.append({"a": Vector2i(i, deck_y(w, dy, i)), "b": Vector2i(i + 1, deck_y(w, dy, i + 1)), "m": Sim.ROAD})
	return out

## The full candidate: the deck, a Pratt truss `down` rows under it and one
## `up` rows over it (0 for none), and a link from every anchor to each
## candidate joint in reach. `diag` 0 lays every diagonal both ways, 1 only
## those falling toward the middle, 2 only those rising toward it: a full
## cross-braced truss is too heavy to hold itself up past seven or so. The
## miner prunes it.
static func full(level: Dictionary, down: int, up: int, diag := 0, wood := Sim.WOOD) -> Array:
	var w := int(level.w)
	var dy := int(level.get("dy", 0))
	var out := plain_deck(level)
	var seen := {}
	for d in out:
		seen[_k(d.a, d.b)] = true
	var joints := {}
	for i in w + 1:
		joints[Vector2i(i, deck_y(w, dy, i))] = true
	for off in [-down, up]:
		if off == 0:
			continue
		for i in range(0, w + 1):
			var y := deck_y(w, dy, i)
			var p := Vector2i(i, y + off)
			var q := Vector2i(i + 1, deck_y(w, dy, i + 1) + off)
			if i > 0 and buildable(level, p):
				joints[p] = true
				_add(level, out, seen, Vector2i(i, y), p, wood)
			if i + 1 <= w and buildable(level, p) and buildable(level, q) and i > 0 and i + 1 < w:
				_add(level, out, seen, p, q, wood)
			# diagonals
			# the diagonal from the road down (or up) to the next column, and
			# the one from this column's chord back to the next road joint
			var left := 2 * i + 1 < w
			var first := diag == 0 or (diag == 1) == left
			var second := diag == 0 or (diag == 1) != left
			var d0 := Vector2i(i, y)
			var d1 := Vector2i(i + 1, deck_y(w, dy, i + 1) + off)
			if first and buildable(level, d1) and d1.x < w:
				_add(level, out, seen, d0, d1, wood)
			var e0 := Vector2i(i, y + off)
			var e1 := Vector2i(i + 1, deck_y(w, dy, i + 1))
			if second and i > 0 and buildable(level, e0):
				_add(level, out, seen, e0, e1, wood)
	for a in level.anchors:
		var ap := Vector2i(int(a[0]), int(a[1]))
		for p in joints.keys():
			if p != ap and fits(ap, p):
				_add(level, out, seen, ap, p, wood)
	return out

static func _add(level: Dictionary, out: Array, seen: Dictionary, a: Vector2i, b: Vector2i, m: int) -> void:
	if not fits(a, b) or not buildable(level, a) or not buildable(level, b):
		return
	var k := _k(a, b)
	if seen.has(k):
		return
	seen[k] = true
	out.append({"a": a, "b": b, "m": m})

static func _k(a: Vector2i, b: Vector2i) -> Vector4i:
	if a.x < b.x or (a.x == b.x and a.y < b.y):
		return Vector4i(a.x, a.y, b.x, b.y)
	return Vector4i(b.x, b.y, a.x, a.y)

## True when `design` gets the cart over `level`, with every member's stress
## at most `margin` of its limit.
static func proves(level: Dictionary, design: Array, margin := 1.0) -> bool:
	var sim := Sim.new()
	sim.setup(level, design)
	if not sim.run():
		return false
	return sim.worst() <= margin

const BANK := "res://content/trestle.json"
static var _bank: Array = []

## The first mined Easy level, for a bank that is missing or short a band:
## the board always opens.
const FALLBACK := {"anchors": [[0, 0], [4, 0], [0, -2], [4, -1]], "band": 0, "budget": 3900, "cart": 1.2,
	"dy": 0, "mats": [0, 1], "proof_cost": 2390, "w": 4,
	"proof": [
		[0, 0, 1, 0, 0], [1, 0, 2, 0, 0], [2, 0, 3, 0, 0], [3, 0, 4, 0, 0], [0, 0, 1, 1, 1], [1, 0, 1, 1, 1],
		[1, 1, 2, 1, 1], [1, 0, 2, 1, 1], [2, 0, 2, 1, 1], [2, 1, 3, 1, 1], [2, 1, 3, 0, 1], [3, 0, 3, 1, 1],
		[3, 1, 4, 0, 1]]}

static func bank() -> Array:
	if _bank.is_empty() and FileAccess.file_exists(BANK):
		var doc = JSON.parse_string(FileAccess.get_file_as_string(BANK))
		if doc is Dictionary and doc.get("bands") is Array:
			_bank = doc.bands
	return _bank

## The day's level for band `difficulty`.
static func deal(rng: RandomNumberGenerator, difficulty: int) -> Dictionary:
	var bands := bank()
	var band := clampi(difficulty, 0, BANDS.size() - 1)
	if band < bands.size() and bands[band] is Array and not (bands[band] as Array).is_empty():
		var pool: Array = bands[band]
		return (pool[rng.randi_range(0, pool.size() - 1)] as Dictionary).duplicate(true)
	return FALLBACK.duplicate(true)
