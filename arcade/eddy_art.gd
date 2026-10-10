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
## sailing boat and a beach ball -- each in three colours (`look`).
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
## on it, and the bank all round. `u` is pixels a pond unit.
static func pond(size: Vector2, u: float) -> ArrayMesh:
	var b := Face.Builder.new()
	var a := b.vertex(Vector2.ZERO, WATER_HI)
	var c := b.vertex(Vector2(size.x, 0), WATER)
	var d := b.vertex(size, WATER_LOW)
	var e := b.vertex(Vector2(0, size.y), WATER)
	b.tri(a, c, d)
	b.tri(a, d, e)
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	# the light on the water: long pale patches, and short bright ripples
	for i in 9:
		var p := Vector2(rng.randf_range(0.1, 0.9) * size.x, rng.randf_range(0.08, 0.92) * size.y)
		b.ellipse(p, rng.randf_range(26.0, 60.0) * u, rng.randf_range(7.0, 14.0) * u, Color(WATER_HI, 0.3))
	for i in 26:
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
