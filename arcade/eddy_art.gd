extends RefCounted

## Eddy's pond, drawn as builder shapes and shared by the game
## (arcade/eddy_screen.gd), its tutorial pages and its card on the Arcade
## tab. Everything is built in pixels and cached per look and size; the
## screen moves, turns and shrinks a thing by its draw transform and never
## rebuilds one to do it.
##
## The pond is seen from straight above: still water with the light lying
## on it, a grassy bank all round with stones, reeds and lily pads in the
## corners. What floats is drawn with its middle at the origin: three
## leaves, three petals, an acorn, and the toys -- a rubber duck, a little
## sailing boat and a beach ball -- each in three colours (`look`). Above
## the toys are what a garden leaves by a pond, to be grown into over many
## runs: a tin bucket, a watering can and a lilo, then a raft of logs and a
## rowing boat.
##
## The whirlpool is two meshes a core across (`funnel` and `streaks`, both
## built for a core of one `r` and scaled by the transform as it grows):
## the mouth going down dark in rings with foam round its lip, and the long
## curved streaks of the water turning round it. The screen turns the mouth
## fast and the streaks slowly, as the water does.

const Pal = preload("res://core/palette.gd")
const Face = preload("res://ui/faces/face.gd")
const Sim = preload("res://arcade/eddy_sim.gd")

const INK := Color("3d4a52")
const WATER := Color("86c9d4")
const WATER_HI := Color("a9dde2")
const WATER_LOW := Color("6fb6c8")
const WATER_DEEP := Color("4c93ad")
const WATER_DARK := Color("346f8c")
const WATER_PIT := Color("234f6a")
const FOAM := Color("f6fbf8")
const BANK := Color("9ccb6f")
const BANK_HI := Color("b4da84")
const BANK_DEEP := Color("7fb257")
const STONE := Color("c9c2b4")
const STONE_DEEP := Color("a59d8e")
const PAD := Color("6fae5a")
const PAD_HI := Color("8cc46f")
const PAD_DEEP := Color("558f4a")
const REED := Color("5f8f4a")
const REED_HEAD := Color("8a6a45")
const LEAVES := [Color("7fb257"), Color("e39a4a"), Color("e8c75a")]
const LEAVES_DEEP := [Color("5f9244"), Color("c0772f"), Color("c9a437")]
const PETALS := [Color("f4a7b4"), Color("fff6ea"), Color("c7a6d8")]
const PETALS_DEEP := [Color("d97f92"), Color("e3d6c2"), Color("a384b8")]
const NUT := Color("c98f55")
const NUT_HI := Color("e0ac72")
const NUT_CAP := Color("8a6a45")
const DUCK := Color("f6c744")
const DUCK_HI := Color("fbe08a")
const DUCK_DEEP := Color("e0a92e")
const BEAK := Color("ee8a3c")
const HULLS := [Color("d9634f"), Color("4f8fc4"), Color("5aa56a")]
const HULLS_DEEP := [Color("b34a3a"), Color("3a70a0"), Color("438552")]
const DECK := Color("f0d9a8")
const SAIL := Color("fffaf0")
const BALLS := [Color("e8604f"), Color("4f9fd0"), Color("f2b63c")]
const TIN := Color("b9c4c9")
const TIN_HI := Color("dde5e7")
const TIN_DEEP := Color("8a979e")
const CANS := [Color("5aa56a"), Color("d9634f"), Color("4f8fc4")]
const CANS_DEEP := [Color("438552"), Color("b34a3a"), Color("3a70a0")]
const LILOS := [Color("f4a7b4"), Color("8fd0c4"), Color("f2c66a")]
const LILOS_DEEP := [Color("d97f92"), Color("64ab9e"), Color("d3a245")]
const LOG := Color("b98958")
const LOG_HI := Color("d3a673")
const LOG_DEEP := Color("8a6a45")
const ROPE := Color("efe2c4")
const PLANK := Color("e6c998")
const SPIN := Color("5fb3cf")
const SPIN_LOW := Color("e39a4a")
const BAR_BACK := Color("fffaf0")

## How much bigger than its weighed radius a thing is drawn.
const DRAWN := 1.18
## The bank's width round the pond, in pond units.
const RIM := 7.0

static var _cache := {}

static func _made(key: String, build: Callable) -> ArrayMesh:
	if _cache.has(key):
		return _cache[key]
	if _cache.size() > 120:
		_cache.clear()
	var b := Face.Builder.new()
	build.call(b)
	var m := b.mesh()
	_cache[key] = m
	return m

## A thing afloat, `u` pixels a pond unit.
static func thing(kind: int, look: int, u: float) -> ArrayMesh:
	return _made("thing%d/%d/%.2f" % [kind, look, u], func(b: Face.Builder) -> void:
		var s := float(Sim.KINDS[kind].r) * DRAWN * u
		# the water darker round it, and a thread of light where it sits
		b.disc(Vector2.ZERO, s * 1.3, Color(WATER_DEEP, 0.2))
		b.stroke(Face.Builder.ring(Vector2.ZERO, s * 1.18, s * 1.18), maxf(1.0, s * 0.05), Color(FOAM, 0.22), true)
		thing_into(b, kind, look, s))

## The same into a builder, `s` pixels its half-length, its middle at the
## origin.
static func thing_into(b: Face.Builder, kind: int, look: int, s: float, at := Vector2.ZERO, turn := 0.0) -> void:
	var into := b
	if at != Vector2.ZERO or turn != 0.0:
		into = Face.Builder.new()
	match kind:
		Sim.Kind.LEAF: _leaf(into, look % 3, s)
		Sim.Kind.PETAL: _petal(into, look % 3, s)
		Sim.Kind.ACORN: _acorn(into, s)
		Sim.Kind.DUCK: _duck(into, s)
		Sim.Kind.BOAT: _boat(into, look % 3, s)
		Sim.Kind.BALL: _ball(into, look % 3, s)
		Sim.Kind.BUCKET: _bucket(into, s)
		Sim.Kind.CAN: _can(into, look % 3, s)
		Sim.Kind.LILO: _lilo(into, look % 3, s)
		Sim.Kind.RAFT: _raft(into, s)
		Sim.Kind.ROWBOAT: _rowboat(into, look % 3, s)
	if into != b:
		b.append(into.mesh(), Transform2D(turn, at))

static func _blade(s: float, wide: float, tip := 1.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n := 14
	for i in n + 1:
		var k := float(i) / n
		pts.append(Vector2(lerpf(-s, s * tip, k), -sin(k * PI) * wide * (0.75 + 0.25 * k)))
	for i in n + 1:
		var k := 1.0 - float(i) / n
		pts.append(Vector2(lerpf(-s, s * tip, k), sin(k * PI) * wide * (0.75 + 0.25 * k)))
	return pts

static func _leaf(b: Face.Builder, look: int, s: float) -> void:
	var col: Color = LEAVES[look]
	var deep: Color = LEAVES_DEEP[look]
	b.polygon(_blade(s * 1.08, s * 0.62), deep)
	b.polygon(_blade(s * 0.96, s * 0.5), col)
	b.stroke(PackedVector2Array([Vector2(-s * 1.25, 0), Vector2(s * 0.8, 0)]), maxf(1.5, s * 0.1), deep)
	for k in 3:
		var x := (-0.4 + 0.4 * k) * s
		for side: float in [-1.0, 1.0]:
			b.stroke(PackedVector2Array([Vector2(x, 0), Vector2(x + 0.26 * s, side * 0.3 * s)]), maxf(1.0, s * 0.06), Color(deep, 0.8))
	b.ellipse(Vector2(-0.1, -0.22) * s, 0.42 * s, 0.1 * s, Color(1, 1, 1, 0.22))

static func _petal(b: Face.Builder, look: int, s: float) -> void:
	var col: Color = PETALS[look]
	var deep: Color = PETALS_DEEP[look]
	b.ellipse(Vector2(0.1 * s, 0), 0.98 * s, 0.74 * s, deep)
	b.polygon(PackedVector2Array([Vector2(-1.15, 0) * s, Vector2(-0.3, -0.62) * s, Vector2(-0.3, 0.62) * s]), deep)
	b.ellipse(Vector2(0.12 * s, 0), 0.84 * s, 0.6 * s, col)
	b.polygon(PackedVector2Array([Vector2(-0.98, 0) * s, Vector2(-0.3, -0.48) * s, Vector2(-0.3, 0.48) * s]), col)
	b.ellipse(Vector2(0.3, -0.16) * s, 0.36 * s, 0.14 * s, Color(1, 1, 1, 0.4))
	b.stroke(PackedVector2Array([Vector2(-0.8, 0) * s, Vector2(0.2, 0) * s]), maxf(1.0, s * 0.07), Color(deep, 0.7))

static func _acorn(b: Face.Builder, s: float) -> void:
	b.ellipse(Vector2(0.12 * s, 0), 0.98 * s, 0.8 * s, NUT_CAP.darkened(0.15))
	b.ellipse(Vector2(0.16 * s, 0), 0.86 * s, 0.68 * s, NUT)
	b.ellipse(Vector2(0.3, -0.2) * s, 0.34 * s, 0.14 * s, Color(NUT_HI, 0.9))
	b.polygon(PackedVector2Array([Vector2(0.9, -0.12) * s, Vector2(1.18, 0) * s, Vector2(0.9, 0.12) * s]), NUT)
	# the cup, and its stalk
	var cup := PackedVector2Array()
	for p: Vector2 in Face.Builder.arc_points(Vector2(-0.2 * s, 0), 0.8 * s, PI * 0.5, PI * 1.5):
		cup.append(p)
	b.polygon(cup, NUT_CAP)
	b.stroke(PackedVector2Array([Vector2(-0.98, 0) * s, Vector2(-1.25, -0.08) * s]), maxf(1.5, s * 0.14), NUT_CAP.darkened(0.15))
	for k in 3:
		b.disc(Vector2(-0.52 - 0.14 * (k % 2), -0.34 + 0.34 * k) * s, 0.09 * s, Color(NUT_HI, 0.55))

## The rubber duck from above, her beak toward +x.
static func _duck(b: Face.Builder, s: float) -> void:
	# her tail, her body, her wings folded, her head
	b.polygon(PackedVector2Array([Vector2(-0.62, -0.3) * s, Vector2(-1.2, 0) * s, Vector2(-0.62, 0.3) * s]), DUCK_DEEP)
	b.ellipse(Vector2(-0.12 * s, 0), 0.92 * s, 0.76 * s, DUCK_DEEP)
	b.ellipse(Vector2(-0.1 * s, -0.03 * s), 0.82 * s, 0.66 * s, DUCK)
	for side: float in [-1.0, 1.0]:
		b.ellipse(Vector2(-0.2, side * 0.36) * s, 0.46 * s, 0.2 * s, Color(DUCK_DEEP, 0.8))
	b.ellipse(Vector2(-0.3, -0.24) * s, 0.3 * s, 0.12 * s, Color(DUCK_HI, 0.9))
	b.polygon(PackedVector2Array([Vector2(0.86, -0.2) * s, Vector2(1.3, -0.1) * s, Vector2(1.3, 0.1) * s, Vector2(0.86, 0.2) * s]), BEAK)
	b.disc(Vector2(0.52 * s, 0), 0.5 * s, DUCK_DEEP)
	b.disc(Vector2(0.53 * s, -0.02 * s), 0.43 * s, DUCK)
	b.ellipse(Vector2(0.44, -0.18) * s, 0.2 * s, 0.09 * s, Color(DUCK_HI, 0.9))
	for side: float in [-1.0, 1.0]:
		b.disc(Vector2(0.7, side * 0.24) * s, 0.085 * s, INK)
		b.disc(Vector2(0.72, side * 0.24 - 0.02) * s, 0.03 * s, Color.WHITE)

## The little sailing boat from above, her bow toward +x.
static func _boat(b: Face.Builder, look: int, s: float) -> void:
	var col: Color = HULLS[look]
	var deep: Color = HULLS_DEEP[look]
	b.polygon(_blade(s * 1.02, s * 0.56, 1.1), deep)
	b.polygon(_blade(s * 0.92, s * 0.46, 1.08), col)
	b.polygon(_blade(s * 0.66, s * 0.28, 1.0), DECK)
	b.stroke(PackedVector2Array([Vector2(-0.5, 0) * s, Vector2(0.5, 0) * s]), maxf(1.0, s * 0.04), Color(deep, 0.5))
	# her sail leaning over the side, and the mast's top
	b.polygon(PackedVector2Array([Vector2(0.34, 0.02) * s, Vector2(-0.46, 0.62) * s, Vector2(-0.5, 0.02) * s]), Color(INK, 0.16))
	b.polygon(PackedVector2Array([Vector2(0.4, -0.04) * s, Vector2(-0.4, -0.7) * s, Vector2(-0.5, -0.04) * s]), SAIL)
	b.stroke(PackedVector2Array([Vector2(0.4, -0.04) * s, Vector2(-0.4, -0.7) * s, Vector2(-0.5, -0.04) * s]), maxf(1.0, s * 0.05), Color(deep, 0.7), true)
	b.disc(Vector2(-0.06, -0.04) * s, 0.09 * s, Color("8a6a45"))

static func _ball(b: Face.Builder, look: int, s: float) -> void:
	var col: Color = BALLS[look]
	b.disc(Vector2.ZERO, s, col.darkened(0.25))
	b.disc(Vector2.ZERO, 0.92 * s, FOAM)
	for k in 3:
		var a0 := TAU * k / 3.0 + 0.3
		var wedge := PackedVector2Array([Vector2.ZERO])
		for p: Vector2 in Face.Builder.arc_points(Vector2.ZERO, 0.92 * s, a0, a0 + TAU / 6.0):
			wedge.append(p)
		b.polygon(wedge, col)
	b.disc(Vector2.ZERO, 0.2 * s, BALLS[(look + 2) % 3])
	b.ellipse(Vector2(-0.3, -0.36) * s, 0.3 * s, 0.16 * s, Color(1, 1, 1, 0.45))

## The tin bucket from above: its rim, the dark inside it with a little
## water standing there, and its handle lying over.
static func _bucket(b: Face.Builder, s: float) -> void:
	b.disc(Vector2.ZERO, s, TIN_DEEP)
	b.disc(Vector2.ZERO, 0.93 * s, TIN)
	b.stroke(Face.Builder.arc_points(Vector2.ZERO, 0.86 * s, PI * 1.05, PI * 1.75), maxf(2.0, s * 0.07), TIN_HI)
	b.disc(Vector2(0, 0.03 * s), 0.74 * s, TIN_DEEP.darkened(0.25))
	b.disc(Vector2(0.04, 0.1) * s, 0.6 * s, WATER_DARK)
	b.ellipse(Vector2(-0.12, -0.02) * s, 0.3 * s, 0.1 * s, Color(WATER_HI, 0.5))
	# the handle, from ear to ear, fallen to one side
	for side: float in [-1.0, 1.0]:
		b.disc(Vector2(0, side * 0.88) * s, 0.1 * s, INK)
	b.stroke(Face.Builder.bezier2(Vector2(0, -0.88) * s, Vector2(0.62, 0) * s, Vector2(0, 0.88) * s, 14), maxf(2.0, s * 0.08), INK)
	b.stroke(Face.Builder.bezier2(Vector2(0.24, -0.3) * s, Vector2(0.37, 0) * s, Vector2(0.24, 0.3) * s, 6), maxf(3.0, s * 0.15), LOG)

## The watering can from above, its spout toward +x: the round body open at
## the top, the spout with its rose, the handle behind.
static func _can(b: Face.Builder, look: int, s: float) -> void:
	var col: Color = CANS[look]
	var deep: Color = CANS_DEEP[look]
	# the handle behind, a loop
	b.stroke(Face.Builder.arc_points(Vector2(-0.56, 0) * s, 0.34 * s, PI * 0.5, PI * 1.5), maxf(3.0, s * 0.13), deep)
	# the spout and its rose
	b.polygon(PackedVector2Array([Vector2(0.2, -0.16) * s, Vector2(0.92, -0.07) * s, Vector2(0.92, 0.07) * s, Vector2(0.2, 0.16) * s]), deep)
	b.polygon(PackedVector2Array([Vector2(0.24, -0.1) * s, Vector2(0.9, -0.04) * s, Vector2(0.9, 0.04) * s, Vector2(0.24, 0.1) * s]), col)
	b.ellipse(Vector2(0.98, 0) * s, 0.1 * s, 0.2 * s, deep)
	b.ellipse(Vector2(1.0, 0) * s, 0.06 * s, 0.15 * s, TIN_HI)
	b.disc(Vector2(-0.14, 0) * s, 0.6 * s, deep)
	b.disc(Vector2(-0.14, 0) * s, 0.54 * s, col)
	b.disc(Vector2(-0.14, 0.02) * s, 0.4 * s, deep.darkened(0.25))
	b.disc(Vector2(-0.11, 0.06) * s, 0.31 * s, WATER_DARK)
	b.stroke(Face.Builder.arc_points(Vector2(-0.14, 0) * s, 0.47 * s, PI * 1.05, PI * 1.7), maxf(1.5, s * 0.05), Color(1, 1, 1, 0.4))
	# the bar over the top
	b.stroke(PackedVector2Array([Vector2(-0.52, 0) * s, Vector2(0.22, 0) * s]), maxf(2.5, s * 0.1), deep)

## The lilo from above: a long air bed in ribs, its pillow toward +x.
static func _lilo(b: Face.Builder, look: int, s: float) -> void:
	var col: Color = LILOS[look]
	var deep: Color = LILOS_DEEP[look]
	var half := Vector2(1.0, 0.52) * s
	b.fan(Face.Builder.round_rect(-half, half * 2.0, 0.2 * s), deep)
	b.fan(Face.Builder.round_rect(-half + Vector2(0.05, 0.05) * s, half * 2.0 - Vector2(0.1, 0.1) * s, 0.16 * s), col)
	# five ribs along it, light on each
	for k in 5:
		var y := (-0.4 + 0.2 * k) * s
		if k > 0:
			b.stroke(PackedVector2Array([Vector2(-0.9 * s, y - 0.1 * s), Vector2(0.52 * s, y - 0.1 * s)]), maxf(1.5, s * 0.03), Color(deep, 0.8))
		b.stroke(PackedVector2Array([Vector2(-0.84 * s, y - 0.03 * s), Vector2(0.44 * s, y - 0.03 * s)]), maxf(1.5, s * 0.035), Color(1, 1, 1, 0.3))
	# the pillow, across
	b.fan(Face.Builder.round_rect(Vector2(0.56, -0.46) * s, Vector2(0.38, 0.92) * s, 0.14 * s), deep)
	b.fan(Face.Builder.round_rect(Vector2(0.6, -0.42) * s, Vector2(0.3, 0.84) * s, 0.12 * s), FOAM)
	b.ellipse(Vector2(0.72, -0.2) * s, 0.07 * s, 0.14 * s, Color(col, 0.6))

## The raft from above: five logs side by side, lashed twice across.
static func _raft(b: Face.Builder, s: float) -> void:
	for k in 5:
		var y := (-0.56 + 0.28 * k) * s
		var long := (0.98 if k % 2 == 0 else 0.88) * s
		var back := (-0.94 if k % 2 == 1 else -0.86) * s
		b.fan(Face.Builder.round_rect(Vector2(back, y - 0.15 * s), Vector2(long - back, 0.3 * s), 0.13 * s), LOG_DEEP)
		b.fan(Face.Builder.round_rect(Vector2(back + 0.03 * s, y - 0.12 * s), Vector2(long - back - 0.06 * s, 0.22 * s), 0.1 * s), LOG)
		b.stroke(PackedVector2Array([Vector2(back + 0.14 * s, y - 0.05 * s), Vector2(long - 0.2 * s, y - 0.05 * s)]), maxf(1.5, s * 0.03), Color(LOG_HI, 0.9))
		# the cut end, its rings
		b.ellipse(Vector2(long - 0.05 * s, y), 0.05 * s, 0.11 * s, LOG_HI)
		b.ellipse(Vector2(long - 0.05 * s, y), 0.025 * s, 0.055 * s, LOG_DEEP)
	for x: float in [-0.5, 0.46]:
		b.stroke(PackedVector2Array([Vector2(x, -0.72) * s, Vector2(x, 0.72) * s]), maxf(3.0, s * 0.075), ROPE.darkened(0.2))
		b.stroke(PackedVector2Array([Vector2(x - 0.015, -0.72) * s, Vector2(x - 0.015, 0.72) * s]), maxf(1.5, s * 0.04), ROPE)

## The rowing boat from above, her bow toward +x: the hull, the boards of
## her floor, two thwarts and the oars shipped across her.
static func _rowboat(b: Face.Builder, look: int, s: float) -> void:
	var col: Color = HULLS[look]
	var deep: Color = HULLS_DEEP[look]
	# the oars lie under the gunwale's line, their blades out over the water
	for side: float in [-1.0, 1.0]:
		var from := Vector2(0.12, side * 0.1) * s
		var to := Vector2(-0.5, side * 0.9) * s
		b.stroke(PackedVector2Array([from, to]), maxf(2.0, s * 0.045), LOG_DEEP)
		b.ellipse(to + (to - from).normalized() * 0.1 * s, 0.07 * s, 0.16 * s, LOG)
	b.polygon(_blade(s * 1.0, s * 0.52, 1.08), deep)
	b.polygon(_blade(s * 0.93, s * 0.45, 1.06), col)
	b.polygon(_blade(s * 0.82, s * 0.36, 1.0), PLANK.darkened(0.12))
	b.polygon(_blade(s * 0.78, s * 0.32, 0.98), PLANK)
	for k in 3:
		var y := (-0.14 + 0.14 * k) * s
		b.stroke(PackedVector2Array([Vector2(-0.6 * s, y), Vector2(0.6 * s, y)]), maxf(1.0, s * 0.02), Color(LOG_DEEP, 0.45))
	# her thwarts and the board at her stern
	for x: float in [-0.3, 0.28]:
		b.fan(Face.Builder.round_rect(Vector2(x - 0.08, -0.36) * s, Vector2(0.16, 0.72) * s, 0.03 * s), LOG_DEEP)
		b.fan(Face.Builder.round_rect(Vector2(x - 0.07, -0.36) * s, Vector2(0.12, 0.72) * s, 0.03 * s), LOG_HI)
	b.fan(Face.Builder.round_rect(Vector2(-0.84, -0.2) * s, Vector2(0.12, 0.4) * s, 0.03 * s), deep)
	b.stroke(PackedVector2Array([Vector2(-0.5, -0.3) * s, Vector2(0.4, -0.34) * s]), maxf(1.5, s * 0.03), Color(1, 1, 1, 0.3))
	for side: float in [-1.0, 1.0]:
		b.disc(Vector2(0.0, side * 0.42) * s, 0.045 * s, INK)

## The whirlpool's mouth for a core of `r` pixels: the water going down
## darker ring by ring, three curls of foam turning in it, foam round its
## lip.
static func funnel(r: float) -> ArrayMesh:
	return _made("funnel/%.1f" % r, func(b: Face.Builder) -> void: funnel_into(b, r))

static func funnel_into(b: Face.Builder, r: float) -> void:
	b.disc(Vector2.ZERO, 1.5 * r, Color(WATER_LOW, 0.45))
	b.disc(Vector2.ZERO, 1.22 * r, Color(WATER_DEEP, 0.55))
	b.disc(Vector2.ZERO, r, WATER_DEEP)
	b.disc(Vector2.ZERO, 0.72 * r, WATER_DARK)
	b.disc(Vector2.ZERO, 0.4 * r, WATER_PIT)
	b.disc(Vector2.ZERO, 0.16 * r, WATER_PIT.darkened(0.3))
	for k in 3:
		var a0 := TAU * k / 3.0
		b.stroke(_curl(0.3 * r, 0.95 * r, a0, 2.6), maxf(1.5, r * 0.07), Color(FOAM, 0.55))
		b.stroke(_curl(0.98 * r, 1.16 * r, a0 + 1.0, 1.3), maxf(1.5, r * 0.09), Color(FOAM, 0.75))

## The water turning round the mouth, for a core of `r` pixels: long streaks
## curling in from three cores out, fainter the further.
static func streaks(r: float) -> ArrayMesh:
	return _made("streaks/%.1f" % r, func(b: Face.Builder) -> void:
		for k in 5:
			var a0 := TAU * k / 5.0
			b.stroke(_curl(1.5 * r, 2.2 * r, a0, 1.5), maxf(1.5, r * 0.08), Color(FOAM, 0.34))
			b.stroke(_curl(2.3 * r, 3.0 * r, a0 + 2.0, 1.0), maxf(1.5, r * 0.07), Color(FOAM, 0.2))
			b.stroke(_curl(3.1 * r, 3.7 * r, a0 + 0.9, 0.7), maxf(1.0, r * 0.06), Color(FOAM, 0.1)))

## A curl from `r0` at angle `a0` out to `r1`, `sweep` radians round, the
## way the water turns.
static func _curl(r0: float, r1: float, a0: float, sweep: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n := 16
	for i in n + 1:
		var k := float(i) / n
		pts.append(Vector2.from_angle(a0 - sweep * k) * lerpf(r0, r1, k))
	return pts

## The pond under everything, `size` pixels: the water with the light lying
## on it, and the bank all round. `u` is pixels a pond unit, and `turf` how
## many units of grass are drawn beyond the bank, tufted and flowered.
static func pond(size: Vector2, u: float, turf := 0.0) -> ArrayMesh:
	var b := Face.Builder.new()
	var rng := RandomNumberGenerator.new()
	if turf > 0.0:
		rng.seed = 7
		var out := Vector2(turf, turf) * u
		var all := size + out * 2.0
		b.fan(PackedVector2Array([-out, Vector2(size.x + out.x, -out.y), size + out, Vector2(-out.x, size.y + out.y)]), BANK)
		for i in int((all.x * all.y - size.x * size.y) / (u * u) / 2200.0):
			var p := Vector2(rng.randf(), rng.randf()) * all - out
			if Rect2(Vector2.ZERO, size).has_point(p):
				continue
			var roll := rng.randf()
			if roll < 0.12:
				b.disc(p, 2.4 * u, PETALS[rng.randi() % 3])
				b.disc(p, 1.0 * u, Color("f2c14e"))
			else:
				b.ellipse(p, rng.randf_range(7.0, 16.0) * u, rng.randf_range(4.0, 8.0) * u, Color(BANK_HI if roll < 0.6 else BANK_DEEP, 0.5))
	var a := b.vertex(Vector2.ZERO, WATER_HI)
	var c := b.vertex(Vector2(size.x, 0), WATER)
	var d := b.vertex(size, WATER_LOW)
	var e := b.vertex(Vector2(0, size.y), WATER)
	b.tri(a, c, d)
	b.tri(a, d, e)
	rng.seed = 12
	# the light on the water: long pale patches, and short bright ripples, as
	# many again for every 300 by 360 of a bigger pond
	var more := maxf(1.0, size.x * size.y / (u * u) / 108000.0)
	for i in int(9 * more):
		var p := Vector2(rng.randf_range(0.1, 0.9) * size.x, rng.randf_range(0.08, 0.92) * size.y)
		b.ellipse(p, rng.randf_range(26.0, 60.0) * u, rng.randf_range(7.0, 14.0) * u, Color(WATER_HI, 0.3))
	for i in int(26 * more):
		var p := Vector2(rng.randf_range(0.06, 0.94) * size.x, rng.randf_range(0.05, 0.95) * size.y)
		var w := rng.randf_range(5.0, 11.0) * u
		b.stroke(Face.Builder.bezier2(p - Vector2(w, 0), p - Vector2(0, 1.6 * u), p + Vector2(w, 0), 8), maxf(1.5, 0.8 * u), Color(FOAM, 0.26))
	# the bank: a darker lip of water under the grass, then the turf scalloped
	var rim := RIM * u
	for side in 4:
		var along := size.x if side < 2 else size.y
		var n := int(along / (9.0 * u)) + 1
		for i in n + 1:
			var k := float(i) / n * along
			var p := Vector2(k, 0.0) if side == 0 else (Vector2(k, size.y) if side == 1 else (Vector2(0.0, k) if side == 2 else Vector2(size.x, k)))
			b.disc(p, rim * (1.25 + 0.2 * sin(i * 1.7 + side)), Color(WATER_DEEP, 0.4))
	for side in 4:
		var along := size.x if side < 2 else size.y
		var n := int(along / (8.0 * u)) + 1
		for i in n + 1:
			var k := float(i) / n * along
			var p := Vector2(k, 0.0) if side == 0 else (Vector2(k, size.y) if side == 1 else (Vector2(0.0, k) if side == 2 else Vector2(size.x, k)))
			var rr := rim * (0.95 + 0.22 * sin(i * 2.3 + side * 1.1))
			b.disc(p, rr, BANK_DEEP)
			b.disc(p, rr * 0.78, BANK if i % 3 != 0 else BANK_HI)
	# the corners: lily pads, stones and reeds, each clear of the open water
	var corners := [Vector2(0, 0), Vector2(size.x, 0), size, Vector2(0, size.y)]
	for q in 4:
		var c0: Vector2 = corners[q]
		var inward := Vector2(1.0 if c0.x == 0.0 else -1.0, 1.0 if c0.y == 0.0 else -1.0)
		b.disc(c0, rim * 2.6, BANK_DEEP)
		b.disc(c0, rim * 2.2, BANK)
		for i in 3:
			var p := c0 + inward * Vector2(rng.randf_range(1.2, 3.4), rng.randf_range(1.2, 3.4)) * rim * (0.6 + 0.3 * i)
			if q % 2 == 0:
				_lily(b, p, rng.randf_range(4.2, 6.4) * u, rng.randf() * TAU, i == 1)
			else:
				var rr := rng.randf_range(2.6, 4.4) * u
				b.ellipse(p + Vector2(0, 0.25 * rr), rr * 1.15, rr * 0.9, Color(WATER_DEEP, 0.5))
				b.ellipse(p, rr * 1.1, rr * 0.85, STONE_DEEP)
				b.ellipse(p - Vector2(0.12, 0.16) * rr, rr * 0.86, rr * 0.62, STONE)
		if q % 2 == 1:
			for i in 4:
				var root := c0 + inward * Vector2(0.6 + 0.7 * i, 2.3 - 0.4 * i) * rim
				var tip := root + Vector2(inward.x * 0.6, -3.2 - 0.5 * (i % 2)) * rim
				b.stroke(PackedVector2Array([root, tip]), maxf(2.0, 0.9 * u), REED)
				b.ellipse(tip, 0.9 * u, 2.6 * u, REED_HEAD)
	return b.mesh()

static func _lily(b: Face.Builder, at: Vector2, r: float, turn: float, bloom: bool) -> void:
	var pad := PackedVector2Array([at])
	for p: Vector2 in Face.Builder.arc_points(at, r, turn + 0.25, turn + TAU - 0.25):
		pad.append(p)
	var shade := PackedVector2Array([at + Vector2(0, 0.14 * r)])
	for p: Vector2 in Face.Builder.arc_points(at + Vector2(0, 0.14 * r), r * 1.04, turn + 0.25, turn + TAU - 0.25):
		shade.append(p)
	b.polygon(shade, Color(WATER_DEEP, 0.5))
	b.polygon(pad, PAD_DEEP)
	var top := PackedVector2Array([at])
	for p: Vector2 in Face.Builder.arc_points(at, r * 0.86, turn + 0.3, turn + TAU - 0.3):
		top.append(p)
	b.polygon(top, PAD)
	b.ellipse(at + Vector2.from_angle(turn + PI) * r * 0.3 - Vector2(0, 0.1 * r), r * 0.36, r * 0.18, Color(PAD_HI, 0.8))
	if bloom:
		for p in 6:
			b.ellipse(at + Vector2.from_angle(TAU * p / 6.0) * 0.3 * r, 0.26 * r, 0.26 * r, PETALS[0] if p % 2 == 0 else PETALS[1])
		b.disc(at, 0.16 * r, Color("f2c14e"))

## A drop of the pond's water, `tall` pixels, its middle at the origin: what
## a run banks and the shop is paid in.
static func drop(tall: float) -> ArrayMesh:
	return _made("drop/%.1f" % tall, func(b: Face.Builder) -> void:
		var r := tall * 0.34
		var c := Vector2(0, tall * 0.5 - r)
		for pass_k in 2:
			var grow := 1.0 if pass_k == 0 else 0.8
			var col := WATER_DARK if pass_k == 0 else SPIN
			var pts := PackedVector2Array([c + Vector2(0, -tall + r) * (1.0 if pass_k == 0 else 0.86)])
			for p: Vector2 in Face.Builder.arc_points(c, r * grow, -PI * 0.22, PI * 1.22):
				pts.append(p)
			b.polygon(pts, col)
		b.ellipse(c + Vector2(-0.32, 0.1) * r, 0.16 * r, 0.3 * r, Color(1, 1, 1, 0.55)))

## The pad the thumb steers by, `r` pixels across half of it: a round of
## pale wood with a rim and four small marks, its middle at the origin.
static func pad_base(r: float) -> ArrayMesh:
	return _made("pad/%.1f" % r, func(b: Face.Builder) -> void:
		b.disc(Vector2(0, 0.07 * r), r, Color(0.2, 0.1, 0.05, 0.2))
		b.disc(Vector2.ZERO, r, Color("9c6b45"))
		b.disc(Vector2.ZERO, 0.93 * r, Color("e9d6b4"))
		b.disc(Vector2.ZERO, 0.8 * r, Color("f4e7cc"))
		for k in 4:
			var dir := Vector2.from_angle(TAU * k / 4.0)
			var side := dir.orthogonal()
			b.polygon(PackedVector2Array([dir * 0.72 * r, dir * 0.56 * r + side * 0.1 * r, dir * 0.56 * r - side * 0.1 * r]), Color("c9a473")))

## The pad's knob: a button of the pond's water with a curl on it.
static func pad_knob(r: float) -> ArrayMesh:
	return _made("knob/%.1f" % r, func(b: Face.Builder) -> void:
		b.disc(Vector2(0, 0.14 * r), r, Color(0.2, 0.1, 0.05, 0.25))
		b.disc(Vector2.ZERO, r, WATER_DARK)
		b.disc(Vector2(0, -0.05 * r), 0.9 * r, WATER_DEEP)
		b.disc(Vector2(0, -0.08 * r), 0.74 * r, WATER_LOW)
		for k in 3:
			b.stroke(_curl(0.14 * r, 0.56 * r, TAU * k / 3.0, 2.2) , maxf(2.0, r * 0.09), Color(FOAM, 0.8))
		b.ellipse(Vector2(-0.3, -0.5) * r, 0.3 * r, 0.12 * r, Color(1, 1, 1, 0.35)))
