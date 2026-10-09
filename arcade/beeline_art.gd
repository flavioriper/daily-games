extends RefCounted

## Beeline's garden, drawn as builder shapes and shared by the game
## (arcade/beeline_screen.gd), its tutorial pages and its card on the Arcade
## tab. Everything is built in pixels for a field unit of `u` pixels and
## cached per look and scale; the screen moves a thing by its draw transform
## and never rebuilds one to move it.
##
## The bee faces +x with her middle at the origin: a round butter body with
## two cocoa stripes, a sting, feelers, an eye and a blush. She is drawn
## bigger than the body the hedges are weighed against (Sim.R), so a near
## miss is a miss. Her wings are one mesh, rooted at the origin and reaching
## up, beaten by a squash of the transform.
##
## A hedge is one long clipped column with its trimmed end at the origin,
## reaching down (`hedge(u, false)`, the lower half of a gate) or up
## (`hedge(u, true)`, the upper half): the screen stands the end on the gap's
## edge and lets the field's clip take what runs off. The strips behind and
## under the flight -- clouds, far hills, the lawn -- are tiles as wide as
## their `*_TILE`, laid side by side and slid.

const Pal = preload("res://core/palette.gd")
const Face = preload("res://ui/faces/face.gd")
const Sim = preload("res://arcade/beeline_sim.gd")

enum Look { FLY, GLAD, DIZZY }

const INK := Color("4a3a2a")
const BODY := Color("f6c744")
const BODY_HI := Color("fbe08a")
const BODY_DEEP := Color("e0a92e")
const STRIPE := Color("5a4030")
const BLUSH := Color("f4a7a0")
const WING := Color("fdfbf4")
const WING_EDGE := Color("b9cfd6")
const HEDGE := Color("6fa055")
const HEDGE_HI := Color("8dbb66")
const HEDGE_DEEP := Color("4f7f42")
const HEDGE_INK := Color("3f6a38")
const BLOSSOMS := [Color("f4a7a0"), Color("fbe3a0"), Color("fff6ea"), Color("c7a6d8")]
const SKY_TOP := Color("bfe2ee")
const SKY_LOW := Color("fbf1d8")
const CLOUD := Color("fffdf6")
const HILL_FAR := Color("b9d8a6")
const HILL_NEAR := Color("a3cc8c")
const LAWN := Color("9ccb6f")
const LAWN_HI := Color("b4da84")
const LAWN_DEEP := Color("7fb257")
const SOIL := Color("c9a473")
const SOIL_DEEP := Color("b08a5c")
const DEW := Color("bfe6f2")
## The four ribbons, plainest first: clay, silver, gold and pearl.
const RIBBON := [Color("cf8a5b"), Color("b9c2cc"), Color("f2c14e"), Color("f3d9ee")]
const RIBBON_DEEP := [Color("a9683f"), Color("8f9aa6"), Color("c98f22"), Color("c9a3d6")]

## Half the bee's length, in units.
const BEE := 15.0
## Where her wings are rooted, from her middle, in units.
const WING_AT := Vector2(-2.0, -8.5)
## A hedge's column runs this far from its end, in units: past the sky's top
## or the ground from any gap.
const HEDGE_LEN := Sim.H + 30.0
## The strip of lawn under the sky, in units, and each tile's width.
const GROUND := 56.0
const GROUND_TILE := 240.0
const HILL_TILE := 420.0
const CLOUD_TILE := 520.0

static var _cache := {}

static func _made(key: String, build: Callable) -> ArrayMesh:
	if _cache.has(key):
		return _cache[key]
	if _cache.size() > 80:
		_cache.clear()
	var b := Face.Builder.new()
	build.call(b)
	var m := b.mesh()
	_cache[key] = m
	return m

static func bee(look: int, u: float) -> ArrayMesh:
	return _made("bee%d/%.2f" % [look, u], func(b: Face.Builder) -> void: _bee(b, look, BEE * u))

static func wings(u: float) -> ArrayMesh:
	return _made("wings/%.2f" % u, func(b: Face.Builder) -> void:
		var s := BEE * u
		for k in 2:
			var at := Vector2((0.26 - 0.5 * k) * s, -0.52 * s)
			var lean := 0.3 - 0.5 * k
			var edge := PackedVector2Array()
			var fill := PackedVector2Array()
			for p: Vector2 in Face.Builder.ring(Vector2.ZERO, 0.4 * s, 0.6 * s):
				edge.append(at + p.rotated(lean))
			for p: Vector2 in Face.Builder.ring(Vector2.ZERO, 0.33 * s, 0.53 * s):
				fill.append(at + p.rotated(lean))
			b.fan(edge, Color(WING_EDGE, 0.75))
			b.fan(fill, Color(WING, 0.9)))

static func _bee(b: Face.Builder, look: int, s: float) -> void:
	# the sting, behind her
	b.polygon(PackedVector2Array([Vector2(-0.92, -0.16) * s, Vector2(-1.34, 0.02) * s, Vector2(-0.92, 0.2) * s]), STRIPE)
	b.ellipse(Vector2.ZERO, 1.05 * s, 0.86 * s, INK)
	b.ellipse(Vector2.ZERO, 0.97 * s, 0.78 * s, BODY_DEEP)
	b.ellipse(Vector2(0.03, -0.05) * s, 0.92 * s, 0.7 * s, BODY)
	# two stripes, cut to her outline
	for x: float in [-0.42, 0.0]:
		var band := PackedVector2Array()
		for q in 13:
			var a := lerpf(-PI * 0.5, PI * 0.5, float(q) / 12.0)
			band.append(Vector2(x * s + cos(a) * 0.1 * s, sin(a) * 0.74 * s * sqrt(maxf(0.0, 1.0 - x * x))))
		b.stroke(band, 0.2 * s, STRIPE)
	b.ellipse(Vector2(-0.1, -0.5) * s, 0.42 * s, 0.13 * s, Color(BODY_HI, 0.9))
	# feelers, leaning ahead
	for k in 2:
		var root := Vector2(0.5 + 0.16 * k, -0.6) * s
		var tip := Vector2(0.78 + 0.22 * k, -1.12 + 0.06 * k) * s
		b.stroke(Face.Builder.bezier2(root, Vector2(root.x, tip.y), tip, 8), 0.07 * s, INK)
		b.disc(tip, 0.09 * s, INK)
	b.ellipse(Vector2(0.4, 0.24) * s, 0.16 * s, 0.1 * s, Color(BLUSH, 0.85))
	var eye := Vector2(0.6, -0.12) * s
	match look:
		Look.GLAD:
			b.stroke(Face.Builder.arc_points(eye + Vector2(0, 0.06 * s), 0.14 * s, PI * 1.1, PI * 1.9), 0.08 * s, INK)
			b.stroke(Face.Builder.arc_points(Vector2(0.72, 0.1) * s, 0.2 * s, PI * 0.15, PI * 0.8), 0.08 * s, INK)
		Look.DIZZY:
			for k in 2:
				var d := Vector2(0.11, 0.11 * (1 - 2 * k)) * s
				b.stroke(PackedVector2Array([eye - d, eye + d]), 0.08 * s, INK)
			b.disc(Vector2(0.74, 0.22) * s, 0.09 * s, INK)
		_:
			b.disc(eye, 0.13 * s, INK)
			b.disc(eye + Vector2(0.04, -0.05) * s, 0.045 * s, Color.WHITE)
			b.stroke(Face.Builder.arc_points(Vector2(0.7, 0.1) * s, 0.15 * s, PI * 0.15, PI * 0.75), 0.07 * s, INK)

## One half of a gate: `down` hangs from the sky's top, else it stands on
## the ground. The trimmed end is at the origin, across the middle.
static func hedge(u: float, down: bool) -> ArrayMesh:
	return _made("hedge%s/%.2f" % ["d" if down else "u", u], func(b: Face.Builder) -> void:
		var dir := -1.0 if down else 1.0
		var hw := Sim.GATE_W * 0.5 * u
		var far := HEDGE_LEN * u * dir
		var rng := RandomNumberGenerator.new()
		rng.seed = 7 if down else 11
		# the column: an inked edge, the leaf, a shaded side
		_box(b, -hw, 6.0 * u * dir, hw, far, HEDGE_INK)
		_box(b, -hw + 2.0 * u, 6.0 * u * dir, hw - 2.0 * u, far, HEDGE_DEEP)
		_box(b, -hw + 2.0 * u, 6.0 * u * dir, hw - 11.0 * u, far, HEDGE)
		_box(b, -hw + 5.0 * u, 6.0 * u * dir, -hw + 12.0 * u, far, Color(HEDGE_HI, 0.55))
		# clipped leaf: clumps down its length, lighter toward the light
		var n := int(HEDGE_LEN / 9.0)
		for i in n:
			var y := (18.0 + i * 9.0 + rng.randf_range(-2.0, 2.0)) * u * dir
			var x := rng.randf_range(-hw + 8.0 * u, hw - 8.0 * u)
			var lit := x < 0.0
			b.ellipse(Vector2(x, y), rng.randf_range(5.0, 8.0) * u, rng.randf_range(3.0, 4.5) * u,
				Color(HEDGE_HI if lit else HEDGE_INK, 0.5 if lit else 0.3))
		# blossom here and there
		for i in int(HEDGE_LEN / 46.0):
			var c := Vector2(rng.randf_range(-hw + 9.0 * u, hw - 9.0 * u), (30.0 + i * 46.0 + rng.randf_range(-10.0, 10.0)) * u * dir)
			var col: Color = BLOSSOMS[rng.randi() % BLOSSOMS.size()]
			for p in 5:
				b.disc(c + Vector2.from_angle(TAU * p / 5.0 + i) * 2.4 * u, 2.1 * u, col)
			b.disc(c, 1.5 * u, Color("f2c14e") if col != BLOSSOMS[1] else BLOSSOMS[0])
		# the trimmed end, a rounded cap a little wider than the column
		var cap := 20.0 * u
		var cw := hw + 3.0 * u
		var y0 := minf(0.0, cap * dir)
		b.polygon(Face.Builder.round_rect(Vector2(-cw, y0), Vector2(cw * 2.0, cap), 8.0 * u), HEDGE_INK)
		b.polygon(Face.Builder.round_rect(Vector2(-cw + 2.0 * u, y0 + 2.0 * u), Vector2(cw * 2.0 - 4.0 * u, cap - 4.0 * u), 6.5 * u), HEDGE_DEEP)
		b.polygon(Face.Builder.round_rect(Vector2(-cw + 2.0 * u, y0 + 2.0 * u), Vector2(cw * 2.0 - 12.0 * u, cap - 4.0 * u), 6.5 * u), HEDGE)
		b.ellipse(Vector2(-cw * 0.4, y0 + 6.5 * u), cw * 0.38, 2.6 * u, Color(HEDGE_HI, 0.8))
		for i in 4:
			var c := Vector2((-0.6 + 0.4 * i) * cw + rng.randf_range(-2.0, 2.0) * u, y0 + rng.randf_range(9.0, 14.0) * u)
			b.ellipse(c, 4.5 * u, 2.4 * u, Color(HEDGE_HI if i < 2 else HEDGE_INK, 0.35)))

static func _box(b: Face.Builder, x0: float, y0: float, x1: float, y1: float, col: Color) -> void:
	b.fan(PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)]), col)

## A ribbon: a rosette with two tails, its middle at the origin, `r` across
## half of it in pixels. `tier` is 1 to 4.
static func ribbon(tier: int, r: float) -> ArrayMesh:
	return _made("ribbon%d/%.1f" % [tier, r], func(b: Face.Builder) -> void: ribbon_into(b, tier, Vector2.ZERO, r))

static func ribbon_into(b: Face.Builder, tier: int, c: Vector2, r: float) -> void:
	var col: Color = RIBBON[clampi(tier, 1, 4) - 1]
	var deep: Color = RIBBON_DEEP[clampi(tier, 1, 4) - 1]
	for k in 2:
		var sx := -1.0 + 2.0 * k
		b.polygon(PackedVector2Array([c + Vector2(sx * 0.1, 0.3) * r, c + Vector2(sx * 0.62, 0.5) * r, c + Vector2(sx * 0.8, 1.75) * r,
			c + Vector2(sx * 0.5, 1.5) * r, c + Vector2(sx * 0.22, 1.8) * r]), deep)
	for p in 10:
		b.disc(c + Vector2.from_angle(TAU * p / 10.0) * 0.72 * r, 0.3 * r, deep)
	b.disc(c, 0.78 * r, col)
	b.disc(c, 0.5 * r, Color("fffaf0"))
	b.disc(c, 0.36 * r, col)
	b.ellipse(c + Vector2(-0.14, -0.16) * r, 0.14 * r, 0.09 * r, Color(1, 1, 1, 0.6))

## The sky over a field of `size` pixels: pale blue falling to cream over
## the lawn, and a soft low sun.
static func sky(size: Vector2) -> ArrayMesh:
	var b := Face.Builder.new()
	var a := b.vertex(Vector2.ZERO, SKY_TOP)
	var c := b.vertex(Vector2(size.x, 0), SKY_TOP)
	var d := b.vertex(size, SKY_LOW)
	var e := b.vertex(Vector2(0, size.y), SKY_LOW)
	b.tri(a, c, d)
	b.tri(a, d, e)
	var sun := Vector2(size.x * 0.76, size.y * 0.2)
	for k in 4:
		b.disc(sun, size.x * (0.2 - 0.04 * k), Color(1.0, 0.97, 0.82, 0.14))
	return b.mesh()

## A tile of clouds, CLOUD_TILE wide, for a sky `tall` units high.
static func clouds(u: float) -> ArrayMesh:
	return _made("clouds/%.2f" % u, func(b: Face.Builder) -> void:
		for row: Array in [[70.0, 54.0, 1.0], [250.0, 120.0, 0.7], [410.0, 34.0, 0.8], [330.0, 210.0, 0.55]]:
			var c := Vector2(row[0], row[1]) * u
			var k: float = float(row[2]) * u
			for puff: Array in [[-26.0, 4.0, 15.0], [-8.0, -5.0, 20.0], [14.0, -1.0, 17.0], [30.0, 5.0, 12.0]]:
				b.ellipse(c + Vector2(puff[0], puff[1]) * k, float(puff[2]) * k * 1.25, float(puff[2]) * k, Color(CLOUD, 0.85))
			b.fan(Face.Builder.round_rect(c + Vector2(-42.0, 2.0) * k, Vector2(86.0, 16.0) * k, 8.0 * k), Color(CLOUD, 0.85)))

## A tile of far hills, HILL_TILE wide, their feet at y 0 and their tops up.
static func hills(u: float) -> ArrayMesh:
	return _made("hills/%.2f" % u, func(b: Face.Builder) -> void:
		var w := HILL_TILE * u
		# two rows of rounded hills; each row ends where it began, so tiles meet
		for row: Array in [[HILL_FAR, 62.0, 3.0, 0.0], [HILL_NEAR, 38.0, 5.0, 1.3]]:
			var pts := PackedVector2Array([Vector2(0, 0)])
			var steps := 48
			for i in steps + 1:
				var k := float(i) / steps
				var tall: float = float(row[1]) * (0.62 + 0.38 * sin(k * TAU * float(row[2]) + float(row[3])) * sin(k * TAU + float(row[3])))
				pts.append(Vector2(k * w, -tall * u))
			pts.append(Vector2(w, 0))
			b.polygon(pts, row[0])
		# a few round trees along the nearer row
		for i in 5:
			var c := Vector2((30.0 + i * 84.0) * u, -(30.0 + 9.0 * sin(i * 2.1)) * u)
			b.fan(Face.Builder.round_rect(c + Vector2(-1.5, 0.0) * u, Vector2(3.0, 14.0) * u, u), Color("8a6a4a", 0.7))
			b.disc(c, 10.0 * u, Color("86b873"))
			b.disc(c + Vector2(-3.0, -3.0) * u, 5.0 * u, Color("9cc986", 0.8)))

## A tile of the lawn under the flight, GROUND_TILE wide and GROUND tall, its
## top edge (the ground the sim ends a run on) at y 0.
static func ground(u: float) -> ArrayMesh:
	return _made("ground/%.2f" % u, func(b: Face.Builder) -> void:
		var w := GROUND_TILE * u
		var tall := GROUND * u
		_box(b, 0.0, 0.0, w, tall, SOIL)
		_box(b, 0.0, 22.0 * u, w, tall, SOIL_DEEP)
		_box(b, 0.0, 0.0, w, 16.0 * u, LAWN_DEEP)
		_box(b, 0.0, 0.0, w, 12.0 * u, LAWN)
		_box(b, 0.0, 0.0, w, 4.0 * u, LAWN_HI)
		# the turf's scalloped foot, and mown stripes leaning the way she flies
		var n := 20
		for i in n:
			b.disc(Vector2((i + 0.5) * w / n, 15.0 * u), 4.6 * u, LAWN_DEEP)
		for i in 10:
			var x := i * w / 10.0
			b.fan(PackedVector2Array([Vector2(x + 4.0 * u, 0), Vector2(x + 14.0 * u, 0), Vector2(x + 8.0 * u, 12.0 * u), Vector2(x - 2.0 * u, 12.0 * u)]), Color(LAWN_HI, 0.45))
		var rng := RandomNumberGenerator.new()
		rng.seed = 5
		# pebbles in the soil, daisies on the turf: all clear of the tile's ends
		for i in 9:
			var c := Vector2(rng.randf_range(10.0, GROUND_TILE - 10.0), rng.randf_range(27.0, GROUND - 6.0)) * u
			b.ellipse(c, rng.randf_range(2.5, 5.0) * u, rng.randf_range(1.5, 2.6) * u, Color(SOIL, 0.75))
		for i in 6:
			var c := Vector2(20.0 + i * 38.0 + rng.randf_range(-8.0, 8.0), rng.randf_range(4.0, 9.0)) * u
			var col: Color = BLOSSOMS[i % BLOSSOMS.size()]
			for p in 5:
				b.disc(c + Vector2.from_angle(TAU * p / 5.0) * 2.0 * u, 1.7 * u, col)
			b.disc(c, 1.2 * u, Color("f2c14e") if col != BLOSSOMS[1] else BLOSSOMS[0]))

## A dewdrop round the bee: a clear bubble with a glint. `r` in pixels.
static func dew_into(b: Face.Builder, c: Vector2, r: float, a := 1.0) -> void:
	b.disc(c, r, Color(DEW, 0.28 * a))
	b.stroke(Face.Builder.ring(c, r, r), maxf(1.5, r * 0.09), Color(1, 1, 1, 0.75 * a), true)
	b.stroke(Face.Builder.arc_points(c, r * 0.72, PI * 1.1, PI * 1.45), maxf(1.5, r * 0.1), Color(1, 1, 1, 0.8 * a))
	b.disc(c + Vector2(0.38, 0.42) * r, r * 0.07, Color(1, 1, 1, 0.6 * a))
