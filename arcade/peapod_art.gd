extends RefCounted

## Peapod's drawings (spec
## docs/superpowers/specs/2026-10-04-arcade-peapod-design.md): the painted
## crates, one colour a weight of number, the gift crates and their tokens,
## the firecracker and the golden crate, the millipede's plates and head,
## and the pea cannon on its cart. Each is built once per look and scale,
## its origin at its centre (the cart's at its axle, the barrel's at its
## foot), and moved by the draw transform; shared with the Arcade tab's
## banner. A number is lettered over the mesh by the caller (`number()`).

const Pal = preload("res://core/palette.gd")
const Face = preload("res://ui/faces/face.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Sim = preload("res://arcade/peapod_sim.gd")

const INK := Color("3b3028")
const PAPER := Color("fffaf0")
const POD := Color("7fbf5a")
const POD_DEEP := Color("4f8a31")
const POD_HI := Color("b9e08a")
const PEA := Color("a6dc6a")
const PEA_DEEP := Color("5f9a3a")
const WOOD := Color("c89664")
const WOOD_DEEP := Color("9c6b45")
const WOOD_HI := Color("e0b98a")
const HUB := Color("ef9038")
const TYRE := Color("4a4038")
const GOLD := Color("f2c14e")
const GOLD_DEEP := Color("c98f22")
const CRACKER := Color("e2645c")
const HEAD := Color("6a4468")
const HEAD_DEEP := Color("4a2f4c")
const FEELER := Color("3f2a40")
## A crate's paint by the weight of its number: green for the lightest, up
## through teal, blue and violet to maroon and dusk.
const PAINT := [Color("8cc36b"), Color("5fc1ad"), Color("6fb0de"), Color("7d8fd9"), Color("9a7fd0"), Color("b06aa8"),
	Color("a8505e"), Color("5a4a5e")]
## A gift's tile, by Sim.Kind.
const GIFT := {Sim.Kind.PEA: Color("7fc8ee"), Sim.Kind.RATE: Color("f08fb0"), Sim.Kind.POWER: Color("f5a44a"),
	Sim.Kind.TWIN: Color("b6d957"), Sim.Kind.FAN: Color("a98be6"), Sim.Kind.PIERCE: Color("45c4b0"),
	Sim.Kind.BURST: Color("d665c8"), Sim.Kind.MAGNET: Color("5a8fe0"), Sim.Kind.FROST: Color("bfeaf7"),
	Sim.Kind.SHOVE: Color("5fbf8a"), Sim.Kind.ROT: Color("8a7358")}
const IRON := Color("8b94a3")
const ROT_INK := Color("4a2f4c")
const DART := Color("ffe66b")
const BERRY := Color("f0705a")

static var _cache := {}

static func _key(name: String, a: int, b: int, u: float) -> String:
	return "%s_%d_%d_%d" % [name, a, b, roundi(u * 100.0)]

static func _keep(key: String, m: ArrayMesh) -> ArrayMesh:
	if _cache.size() > 300:
		_cache.clear()
	_cache[key] = m
	return m

## The paint a number wears: a step up every time it trebles.
static func tier_of(hp: int) -> int:
	return clampi(int(log(maxf(1.0, hp)) / log(3.0)), 0, PAINT.size() - 1)

static func colour(kind: int, hp: int) -> Color:
	match kind:
		Sim.Kind.GOLD:
			return GOLD
		Sim.Kind.BOMB:
			return CRACKER
		Sim.Kind.HEAD:
			return HEAD
		Sim.Kind.IRON:
			return IRON
	if GIFT.has(kind):
		return GIFT[kind]
	return PAINT[tier_of(hp)]

## A number as a crate wears it: 9,999 at most, then thousands.
static func short(v: int) -> String:
	if v >= 1000000:
		return "%dM" % int(v / 1000000.0)
	if v >= 10000:
		return "%dk" % int(v / 1000.0)
	return str(v)

## A crate of `kind` in tier `tier`, a wall's cell big, centred.
static func crate(kind: int, tier: int, u: float) -> ArrayMesh:
	var key := _key("c", kind, tier, u)
	if _cache.has(key):
		return _cache[key]
	var b := Face.Builder.new()
	var w := (Sim.CELL_W - 3.0) * u
	var h := (Sim.CELL_H - 3.0) * u
	var at := Vector2(-w * 0.5, -h * 0.5)
	var r := 6.0 * u
	var lip := 4.5 * u
	var base := colour(kind, int(pow(3.0, tier)))
	var deep := base.darkened(0.3)
	# the side seen under the face, then the face, lit along its top
	b.fan(Face.Builder.round_rect(at, Vector2(w, h), r), deep)
	b.fan(Face.Builder.round_rect(at, Vector2(w, h - lip), r), base)
	b.fan(Face.Builder.round_rect(at + Vector2(3.0, 2.0) * u, Vector2(w - 6.0 * u, 3.0 * u), 1.5 * u), Color(1, 1, 1, 0.3))
	if kind == Sim.Kind.CRATE:
		# two plank seams, and a nail at each end of them
		for k in 2:
			var y := at.y + (h - lip) * (0.36 + 0.3 * k)
			b.stroke(PackedVector2Array([Vector2(at.x + 3.0 * u, y), Vector2(at.x + w - 3.0 * u, y)]), maxf(1.0, 0.7 * u), Color(deep, 0.3))
		for sx in [-1.0, 1.0]:
			b.disc(Vector2(sx * (w * 0.5 - 4.5 * u), at.y + (h - lip) * 0.5), 1.1 * u, Color(deep, 0.5))
	elif kind == Sim.Kind.IRON:
		# a strap down each side and a rivet in every corner
		for sx in [-1.0, 1.0]:
			b.fan(Face.Builder.round_rect(Vector2(sx * (w * 0.5 - 6.5 * u) - 2.5 * u, at.y + 1.0 * u), Vector2(5.0 * u, h - lip - 2.0 * u), 1.5 * u), Color(deep, 0.55))
			for sy in [0.0, 1.0]:
				b.disc(Vector2(sx * (w * 0.5 - 6.5 * u), at.y + 5.0 * u + sy * (h - lip - 10.0 * u)), 1.7 * u, base.lightened(0.45))
	else:
		# a paler panel the icon sits on, and a glint in the corner
		b.fan(Face.Builder.round_rect(at + Vector2(4.0, 5.5) * u, Vector2(w - 8.0 * u, h - lip - 9.0 * u), r * 0.6), base.lightened(0.22))
		_twinkle(b, at + Vector2(w - 7.0 * u, 7.0 * u), 3.4 * u, Color(1, 1, 1, 0.9))
		var c := Vector2(0, -lip * 0.5 + 0.5 * u)
		if kind == Sim.Kind.GOLD:
			for sx in [-1.0, 1.0]:
				_twinkle(b, c + Vector2(sx * w * 0.36, h * 0.12 * sx), 2.6 * u, Color(1, 1, 1, 0.8))
		else:
			icon(b, kind, c, (h - lip) * 0.7)
	return _keep(key, b.mesh())

## One of the millipede's plates, centred: an eight-sided shell over its
## darker rim, little legs out of both sides.
static func plate(kind: int, tier: int, u: float) -> ArrayMesh:
	var key := _key("p", kind, tier, u)
	if _cache.has(key):
		return _cache[key]
	var b := Face.Builder.new()
	var r := Sim.SEG_R * u
	var base := colour(kind, int(pow(3.0, tier)))
	var deep := base.darkened(0.3)
	for side in [-1.0, 1.0]:
		for k in [-1.0, 1.0]:
			var from := Vector2(k * r * 0.4, side * r * 0.7)
			b.stroke(PackedVector2Array([from, from + Vector2(k * r * 0.2, side * r * 0.5)]), maxf(1.5, 1.6 * u), FEELER)
	b.polygon(_octagon(Vector2(0, 1.8 * u), r), Color(0.2, 0.12, 0.05, 0.2))
	b.polygon(_octagon(Vector2(0, 1.0 * u), r), deep)
	b.polygon(_octagon(Vector2(0, -1.2 * u), r * 0.9), base)
	b.polygon(_octagon(Vector2(0, -1.2 * u), r * 0.72), base.lightened(0.14))
	b.stroke(Face.Builder.arc_points(Vector2(0, -1.2 * u), r * 0.74, -PI * 0.82, -PI * 0.55), maxf(1.0, 1.2 * u), Color(1, 1, 1, 0.45))
	if kind == Sim.Kind.IRON:
		for k in 4:
			b.disc(Vector2(0, -1.2 * u) + Vector2.from_angle(TAU * (k + 0.5) / 4.0) * r * 0.74, 1.5 * u, base.lightened(0.45))
	elif kind != Sim.Kind.CRATE and kind != Sim.Kind.GOLD:
		icon(b, kind, Vector2(0, -1.2 * u), r * 1.15)
	elif kind == Sim.Kind.GOLD:
		_twinkle(b, Vector2(r * 0.5, -r * 0.55), 2.6 * u, Color(1, 1, 1, 0.9))
	return _keep(key, b.mesh())

static func _octagon(c: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in 8:
		pts.append(c + Vector2.from_angle(TAU * (k + 0.5) / 8.0) * r * 1.06)
	return pts

## The millipede's head, facing +x, centred: the eyes are whites only (the
## screen lays the pupils, which watch the cart).
static func head(u: float, cross := false) -> ArrayMesh:
	var key := _key("h", int(cross), 0, u)
	if _cache.has(key):
		return _cache[key]
	var b := Face.Builder.new()
	var r := Sim.HEAD_R * u
	for side in [-1.0, 1.0]:
		var feeler := Face.Builder.bezier2(Vector2(r * 0.5, side * r * 0.5), Vector2(r * 1.3, side * r * 0.5), Vector2(r * 1.45, side * r * 1.05), 8)
		b.stroke(feeler, maxf(1.5, 1.5 * u), FEELER)
		b.disc(feeler[feeler.size() - 1], 2.2 * u, HUB)
		# the jaws
		b.polygon(PackedVector2Array([Vector2(r * 0.8, side * r * 0.42), Vector2(r * 1.28, side * r * 0.2), Vector2(r * 0.92, side * r * 0.08)]), FEELER)
	b.disc(Vector2(0, 1.8 * u), r, Color(0.2, 0.12, 0.05, 0.2))
	b.disc(Vector2(0, 1.0 * u), r, HEAD_DEEP)
	b.disc(Vector2(0, -1.0 * u), r * 0.94, HEAD)
	b.ellipse(Vector2(-r * 0.25, -r * 0.45), r * 0.5, r * 0.22, Color(1, 1, 1, 0.12))
	# stripes across the back of the head
	for k in 2:
		b.stroke(Face.Builder.arc_points(Vector2(r * 0.9, -1.0 * u), r * (1.45 + 0.3 * k), PI * 0.82, PI * 1.18), 2.2 * u, Color(HUB, 0.8))
	for side in [-1.0, 1.0]:
		var e := Vector2(r * 0.36, side * r * 0.4 - 1.0 * u)
		b.disc(e, r * 0.3, PAPER)
		if cross:
			# a brow drawn down over each eye
			b.stroke(PackedVector2Array([e + Vector2(-r * 0.32, side * r * 0.36), e + Vector2(r * 0.36, side * r * 0.1)]), 2.4 * u, FEELER)
	return _keep(key, b.mesh())

## A gift's picture, `s` tall about `c`, laid into a builder.
static func icon(b: Face.Builder, kind: int, c: Vector2, s: float) -> void:
	match kind:
		Sim.Kind.PEA:
			_plus(b, c + Vector2(-s * 0.36, 0), s * 0.2)
			pea(b, c + Vector2(s * 0.2, 0), s * 0.3)
		Sim.Kind.RATE:
			# two chevrons, up: the gun quickens
			for k in 2:
				var y := c.y + s * (0.2 - 0.34 * k)
				for pass_ in 2:
					var o := Vector2(0, s * 0.05) if pass_ == 0 else Vector2.ZERO
					b.stroke(PackedVector2Array([Vector2(c.x - s * 0.3, y + s * 0.14) + o, Vector2(c.x, y - s * 0.14) + o, Vector2(c.x + s * 0.3, y + s * 0.14) + o]),
						s * 0.15, Color(INK, 0.35) if pass_ == 0 else PAPER)
		Sim.Kind.POWER:
			# a heavy pea in a burst
			var pts := PackedVector2Array()
			for k in 16:
				pts.append(c + Vector2.from_angle(TAU * k / 16.0) * s * (0.5 if k % 2 == 0 else 0.34))
			b.polygon(pts, Color("fff1a8"))
			pea(b, c, s * 0.3)
		Sim.Kind.TWIN:
			_plus(b, c + Vector2(-s * 0.4, -s * 0.05), s * 0.18)
			var k := s / 60.0
			var at := c + Vector2(s * 0.16, s * 0.22)
			b.fan(Face.Builder.round_rect(at + Vector2(-9, -36) * k, Vector2(18, 28) * k, 7 * k), POD_DEEP)
			b.fan(Face.Builder.round_rect(at + Vector2(-17, -16) * k, Vector2(34, 14) * k, 4 * k), WOOD_DEEP)
			for sx in [-1.0, 1.0]:
				b.disc(at + Vector2(sx * 12, 0) * k, 8 * k, TYRE)
				b.disc(at + Vector2(sx * 12, 0) * k, 3.4 * k, HUB)
		Sim.Kind.FAN:
			# three peas flung apart from one mouth
			for k in [-1.0, 0.0, 1.0]:
				var d := Vector2.from_angle(-PI * 0.5 + k * 0.62)
				b.stroke(PackedVector2Array([c + Vector2(0, s * 0.36), c + Vector2(0, s * 0.36) + d * s * 0.42]), s * 0.07, Color(PAPER, 0.8))
				pea(b, c + Vector2(0, s * 0.36) + d * s * 0.58, s * 0.17)
		Sim.Kind.PIERCE:
			# a dart up through two slats
			for k in 2:
				b.fan(Face.Builder.round_rect(c + Vector2(-s * 0.4, -s * 0.2 + s * 0.3 * k), Vector2(s * 0.8, s * 0.11), s * 0.05), Color(INK, 0.4))
			b.stroke(PackedVector2Array([c + Vector2(0, s * 0.44), c + Vector2(0, -s * 0.2)]), s * 0.13, PAPER)
			b.polygon(PackedVector2Array([c + Vector2(-s * 0.24, -s * 0.16), c + Vector2(0, -s * 0.5), c + Vector2(s * 0.24, -s * 0.16)]), PAPER)
		Sim.Kind.BURST:
			# a berry going off: three peas out of it
			for k in 3:
				var d := Vector2.from_angle(-PI * 0.5 + TAU * k / 3.0)
				pea(b, c + d * s * 0.38, s * 0.13)
			b.disc(c, s * 0.24, PAPER)
			b.disc(c, s * 0.18, BERRY)
		Sim.Kind.MAGNET:
			# a horseshoe, mouth up, with pale tips
			var arc := Face.Builder.arc_points(c + Vector2(0, -s * 0.02), s * 0.27, 0.0, PI)
			b.stroke(arc, s * 0.2, Color("e8584f"))
			for sx in [-1.0, 1.0]:
				b.fan(Face.Builder.round_rect(c + Vector2(sx * s * 0.27 - s * 0.1, -s * 0.36), Vector2(s * 0.2, s * 0.36), s * 0.02), Color("e8584f"))
				b.fan(Face.Builder.round_rect(c + Vector2(sx * s * 0.27 - s * 0.1, -s * 0.44), Vector2(s * 0.2, s * 0.16), s * 0.02), PAPER)
		Sim.Kind.FROST:
			# a snowflake
			for k in 3:
				var d := Vector2.from_angle(PI * 0.5 + PI * k / 3.0)
				b.stroke(PackedVector2Array([c - d * s * 0.42, c + d * s * 0.42]), s * 0.1, Color("4f9fc8"))
				for end in [-1.0, 1.0]:
					b.disc(c + d * s * 0.42 * end, s * 0.07, Color("4f9fc8"))
			b.disc(c, s * 0.11, PAPER)
		Sim.Kind.SHOVE:
			# a fat arrow up off a bar
			b.fan(Face.Builder.round_rect(c + Vector2(-s * 0.36, s * 0.3), Vector2(s * 0.72, s * 0.13), s * 0.06), PAPER)
			b.fan(Face.Builder.round_rect(c + Vector2(-s * 0.1, -s * 0.1), Vector2(s * 0.2, s * 0.32), s * 0.03), PAPER)
			b.polygon(PackedVector2Array([c + Vector2(-s * 0.3, -s * 0.06), c + Vector2(0, -s * 0.46), c + Vector2(s * 0.3, -s * 0.06)]), PAPER)
		Sim.Kind.ROT:
			# a pea gone off, with a minus beside it
			b.fan(Face.Builder.round_rect(c + Vector2(-s * 0.5, -s * 0.07), Vector2(s * 0.3, s * 0.14), s * 0.05), PAPER)
			b.disc(c + Vector2(s * 0.16, s * 0.03), s * 0.3, ROT_INK)
			b.disc(c + Vector2(s * 0.16, 0), s * 0.27, Color("9aa04a"))
			for spot: Vector2 in [Vector2(0.06, -0.08), Vector2(0.26, 0.06), Vector2(0.12, 0.14)]:
				b.disc(c + spot * s, s * 0.06, ROT_INK)
			b.stroke(Face.Builder.bezier2(c + Vector2(s * 0.2, -s * 0.26), c + Vector2(s * 0.3, -s * 0.44), c + Vector2(s * 0.42, -s * 0.38), 5), s * 0.05, ROT_INK)
		Sim.Kind.BOMB:
			# a firecracker: a banded stick with a lit fuse
			var k := s / 60.0
			b.fan(Face.Builder.round_rect(c + Vector2(-9, -16) * k, Vector2(18, 40) * k, 5 * k), Color("b8403c"))
			b.fan(Face.Builder.round_rect(c + Vector2(-9, -6) * k, Vector2(18, 7) * k, 1 * k), GOLD)
			b.fan(Face.Builder.round_rect(c + Vector2(-9, 8) * k, Vector2(18, 7) * k, 1 * k), GOLD)
			b.stroke(Face.Builder.bezier2(c + Vector2(0, -16) * k, c + Vector2(4, -28) * k, c + Vector2(12, -26) * k, 6), 3 * k, Color("d9b27a"))
			_twinkle(b, c + Vector2(13, -27) * k, 9 * k, Color("ffd65c"))

static func _plus(b: Face.Builder, c: Vector2, r: float) -> void:
	var t := r * 0.36
	for pass_ in 2:
		var o := Vector2(0, r * 0.22) if pass_ == 0 else Vector2.ZERO
		var col := Color(INK, 0.35) if pass_ == 0 else PAPER
		b.fan(Face.Builder.round_rect(c + o + Vector2(-r, -t), Vector2(r * 2.0, t * 2.0), t * 0.6), col)
		b.fan(Face.Builder.round_rect(c + o + Vector2(-t, -r), Vector2(t * 2.0, r * 2.0), t * 0.6), col)

## A pea of radius `r` laid into a builder.
static func pea(b: Face.Builder, c: Vector2, r: float, a := 1.0) -> void:
	b.disc(c + Vector2(0, r * 0.12), r, Color(PEA_DEEP, a))
	b.disc(c, r * 0.9, Color(PEA, a))
	b.disc(c + Vector2(-r * 0.3, -r * 0.32), r * 0.3, Color(1, 1, 1, 0.6 * a))

static func _twinkle(b: Face.Builder, c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in 8:
		pts.append(c + Vector2.from_angle(-PI * 0.5 + TAU * k / 8.0) * (r if k % 2 == 0 else r * 0.32))
	b.polygon(pts, col)

## A falling gift: its picture on a bright disc with a pale ring.
static func token(kind: int, u: float) -> ArrayMesh:
	var key := _key("t", kind, 0, u)
	if _cache.has(key):
		return _cache[key]
	var b := Face.Builder.new()
	var r := 12.5 * u
	var base: Color = GIFT.get(kind, GOLD)
	b.disc(Vector2.ZERO, r * 1.35, Color(1, 1, 0.8, 0.22))
	b.disc(Vector2(0, 1.4 * u), r, base.darkened(0.3))
	b.disc(Vector2.ZERO, r, ROT_INK if kind == Sim.Kind.ROT else PAPER)
	b.disc(Vector2.ZERO, r * 0.86, base)
	b.stroke(Face.Builder.arc_points(Vector2.ZERO, r * 0.7, -PI * 0.85, -PI * 0.5), maxf(1.0, 1.2 * u), Color(1, 1, 1, 0.55))
	icon(b, kind, Vector2.ZERO, r * 1.25)
	return _keep(key, b.mesh())

## The cart, its axle's middle on the origin: a plank box between where the
## wheels go, with a cradle for the pod. `small` is the helper's, in pear.
static func cart(u: float, helper := false) -> ArrayMesh:
	var key := _key("k", int(helper), 0, u)
	if _cache.has(key):
		return _cache[key]
	var b := Face.Builder.new()
	var wood := WOOD if not helper else Color("d7b98a")
	b.ellipse(Vector2(0, 9.5 * u), 24.0 * u, 3.2 * u, Color(0.1, 0.2, 0.05, 0.22))
	b.fan(Face.Builder.round_rect(Vector2(-19, -9) * u, Vector2(38, 13) * u, 4 * u), wood.darkened(0.25))
	b.fan(Face.Builder.round_rect(Vector2(-19, -10) * u, Vector2(38, 11) * u, 4 * u), wood)
	b.fan(Face.Builder.round_rect(Vector2(-16, -9) * u, Vector2(32, 2.4) * u, 1.2 * u), Color(WOOD_HI, 0.8))
	for k in 3:
		b.stroke(PackedVector2Array([Vector2(-9.5 + 9.5 * k, -7) * u, Vector2(-9.5 + 9.5 * k, 0) * u]), maxf(1.0, 0.7 * u), Color(WOOD_DEEP, 0.4))
	# the cradle the pod's foot sits in
	b.fan(Face.Builder.round_rect(Vector2(-10, -15) * u, Vector2(20, 7) * u, 3 * u), WOOD_DEEP)
	return _keep(key, b.mesh())

## A wheel, centred: a dark tyre, six spokes and a pumpkin hub.
static func wheel(u: float) -> ArrayMesh:
	var key := _key("w", 0, 0, u)
	if _cache.has(key):
		return _cache[key]
	var b := Face.Builder.new()
	var r := 9.0 * u
	b.disc(Vector2.ZERO, r, TYRE)
	b.disc(Vector2.ZERO, r * 0.74, Color("f0e2c8"))
	for k in 6:
		var d := Vector2.from_angle(TAU * k / 6.0)
		b.stroke(PackedVector2Array([d * r * 0.2, d * r * 0.78]), maxf(1.2, 1.3 * u), TYRE)
	b.disc(Vector2.ZERO, r * 0.36, HUB)
	b.disc(Vector2(-r * 0.08, -r * 0.08), r * 0.16, Color("ffd9a8"))
	return _keep(key, b.mesh())

## The pea pod that is the barrel, its foot on the origin, mouth up: a fat
## green pod with a seam, a paler belly, a rolled lip and a tendril.
static func barrel(u: float, helper := false) -> ArrayMesh:
	var key := _key("b", int(helper), 0, u)
	if _cache.has(key):
		return _cache[key]
	var b := Face.Builder.new()
	var pod := POD if not helper else Pal.PEAR
	var deep := POD_DEEP if not helper else Color("8f9a3e")
	var tall := 30.0 * u
	var body := PackedVector2Array()
	var left := Face.Builder.bezier3(Vector2(-6, 0) * u, Vector2(-12, -8) * u, Vector2(-10, -22) * u, Vector2(-8, -30) * u, 10)
	var right := Face.Builder.bezier3(Vector2(8, -30) * u, Vector2(10, -22) * u, Vector2(12, -8) * u, Vector2(6, 0) * u, 10)
	body.append_array(left)
	body.append_array(right)
	b.polygon(body, deep)
	var inner := PackedVector2Array()
	for p in body:
		inner.append(Vector2(p.x * 0.82 - 0.8 * u, p.y * 0.97 - 0.4 * u))
	b.polygon(inner, pod)
	b.ellipse(Vector2(-4.0 * u, -tall * 0.5), 2.2 * u, tall * 0.3, Color(POD_HI, 0.7))
	b.stroke(PackedVector2Array([Vector2(3.5 * u, -3.0 * u), Vector2(4.5 * u, -tall * 0.55), Vector2(3.5 * u, -tall + 4.0 * u)]), maxf(1.0, 0.9 * u), Color(deep, 0.6))
	# the lip round the mouth, and the dark of the mouth in it
	b.ellipse(Vector2(0, -tall), 10.0 * u, 4.0 * u, deep)
	b.ellipse(Vector2(0, -tall - 0.6 * u), 9.0 * u, 3.2 * u, pod.lightened(0.2))
	b.ellipse(Vector2(0, -tall - 0.4 * u), 6.4 * u, 2.0 * u, Color("2f4a22"))
	# a tendril curling off the foot
	b.stroke(Face.Builder.bezier3(Vector2(8, -6) * u, Vector2(15, -8) * u, Vector2(16, -15) * u, Vector2(12, -14) * u, 10), maxf(1.0, 1.1 * u), deep)
	return _keep(key, b.mesh())

## A pea in flight by its look (Sim.Shot), centred, flying up: a pea, a
## dart that goes through, a berry that bursts. One mesh a look, drawn for
## every pea in the air by a MultiMesh.
static func shot(look: int, u: float) -> ArrayMesh:
	var key := _key("s", look, 0, u)
	if _cache.has(key):
		return _cache[key]
	var b := Face.Builder.new()
	var r := 3.3 * u
	match look:
		Sim.Shot.PIERCE:
			b.polygon(PackedVector2Array([Vector2(-r * 0.9, r * 1.2), Vector2(0, -r * 2.6), Vector2(r * 0.9, r * 1.2)]), DART.darkened(0.25))
			b.polygon(PackedVector2Array([Vector2(-r * 0.55, r * 0.9), Vector2(0, -r * 2.2), Vector2(r * 0.55, r * 0.9)]), DART)
			b.disc(Vector2(0, -r * 0.2), r * 0.3, Color(1, 1, 1, 0.8))
		Sim.Shot.BURST:
			var pts := PackedVector2Array()
			for k in 12:
				pts.append(Vector2.from_angle(TAU * k / 12.0) * r * (1.35 if k % 2 == 0 else 0.95))
			b.polygon(pts, BERRY.darkened(0.25))
			b.disc(Vector2.ZERO, r * 0.9, BERRY)
			b.disc(Vector2(-r * 0.3, -r * 0.32), r * 0.3, Color(1, 1, 1, 0.6))
		_:
			pea(b, Vector2.ZERO, r)
	return _keep(key, b.mesh())

## A four-pointed spark one unit long, white: scaled and tinted by its draw.
static func spark() -> ArrayMesh:
	if _cache.has("spark"):
		return _cache["spark"]
	var b := Face.Builder.new()
	for q in 4:
		var d := Vector2.from_angle(TAU * q / 4.0)
		b.fan(PackedVector2Array([d.orthogonal() * 0.12, d, -d.orthogonal() * 0.12]), Color.WHITE)
	return _keep("spark", b.mesh())

## The number on a crate or a plate, lettered in paper with an ink outline,
## centred on `c`; `s` is the height of what it sits on.
static func number(ci: CanvasItem, font: Font, c: Vector2, v: int, s: float, alpha := 1.0) -> void:
	var text := short(v)
	var fs := maxi(8, int(s * [0.6, 0.6, 0.58, 0.48, 0.4, 0.34][mini(text.length(), 5)]))
	var size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var at := c + Vector2(-size.x * 0.5, (font.get_ascent(fs) - font.get_descent(fs)) * 0.5)
	ci.draw_string_outline(font, at + Vector2(0, s * 0.03), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, maxi(3, int(s * 0.14)), Color(INK, 0.9 * alpha))
	ci.draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(PAPER, alpha))

static func font() -> Font:
	return CozyTheme.display(700)
