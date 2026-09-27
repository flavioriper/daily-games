extends RefCounted

## Hedgerow's cast and towers, drawn as builder shapes and shared by the
## game (arcade/hedgerow_screen.gd) and its card on the Arcade tab. Sizes
## are in sixteenths of a cell of `u` pixels. A pest is built at the origin
## facing up (-y) and turned to its heading by the draw transform, never
## rebuilt to move; two leg frames a pest. A tower is built at its cell's
## centre looking down on it: a stone slab, and on it a bramble, an acorn
## sling or a clay pot holding its element's orb, with a pip a level.
##
## The pests take their element's colour on the body, so a Rain wave is
## blue from across the lawn; the orbs take it too, which is how a player
## reads what beats what.

const Pal = preload("res://core/palette.gd")
const Face = preload("res://ui/faces/face.gd")
const Sim = preload("res://arcade/hedgerow_sim.gd")

const INK := Color("3b3028")
const WING := Color(0.95, 0.97, 1.0, 0.6)
const SLAB := Color("d9ccb4")
const SLAB_DEEP := Color("b3a386")
const POT := Color("d2825a")
const POT_DEEP := Color("a95f3d")
const BRAMBLE := Color("5f8f45")
const BRAMBLE_DEEP := Color("41693a")
const WOOD := Color("a67a4e")
const WOOD_DEEP := Color("7a5634")
const ACORN := Color("c99a63")
const ACORN_CAP := Color("7a5634")
const PIP := Color("f5c542")
const SHADOW := Color(0.18, 0.22, 0.12, 0.22)

## Each element's colour, and a deeper shade of it.
const EL_COL := {
	Sim.El.NONE: Color("c9b28f"), Sim.El.SUN: Color("f5b83d"), Sim.El.SHADE: Color("8a74c4"),
	Sim.El.RAIN: Color("4f9ad8"), Sim.El.EMBER: Color("e5673f"), Sim.El.LEAF: Color("6fae4a"),
	Sim.El.STONE: Color("a08c72"),
}

static var _cache := {}

static func col(el: int) -> Color:
	return EL_COL[el]

static func deep(el: int) -> Color:
	return (EL_COL[el] as Color).darkened(0.28)

## A pest's mesh, cached per kind, element, frame and scale.
static func creep(kind: int, el: int, frame: int, u: float) -> ArrayMesh:
	var key := "c%d/%d/%d/%.1f" % [kind, el, frame, u]
	if _cache.has(key):
		return _cache[key]
	if _cache.size() > 400:
		_cache.clear()
	var b := Face.Builder.new()
	var s := u / 16.0
	var body := col(el)
	match kind:
		Sim.Kind.APHID:
			aphid(b, s, frame, body)
		Sim.Kind.ANT:
			ant(b, s, frame, body)
		Sim.Kind.GNAT:
			gnat(b, s, frame, body)
		Sim.Kind.BEETLE:
			beetle(b, s, frame, body)
		Sim.Kind.SLUG:
			slug(b, s, frame, body)
		Sim.Kind.WASP:
			wasp(b, s, frame, body)
		Sim.Kind.BOSS:
			stag(b, s, frame, body)
	var m := b.mesh()
	_cache[key] = m
	return m

## A tower's mesh, cached per kind, level and scale, centred on its cell.
static func tower(key: String, level: int, u: float) -> ArrayMesh:
	var ck := "t%s/%d/%.1f" % [key, level, u]
	if _cache.has(ck):
		return _cache[ck]
	var b := Face.Builder.new()
	tower_into(b, key, level, u, Vector2.ZERO)
	var m := b.mesh()
	_cache[ck] = m
	return m

## An element's orb on its own (the pick card, the build chips).
static func orb_mesh(el: int, r: float) -> ArrayMesh:
	var ck := "o%d/%.1f" % [el, r]
	if _cache.has(ck):
		return _cache[ck]
	var b := Face.Builder.new()
	orb(b, Vector2.ZERO, r, [el])
	var m := b.mesh()
	_cache[ck] = m
	return m

# --- shared bits ---

static func _eyes(b: Face.Builder, at: Vector2, gap: float, r: float) -> void:
	for sd: float in [-1.0, 1.0]:
		var c := at + Vector2(sd * gap, 0)
		b.ellipse(c, r, r * 1.15, INK)
		b.disc(c + Vector2(-r * 0.3, -r * 0.4), r * 0.4, Color.WHITE)

static func _legs(b: Face.Builder, s: float, frame: int, ys: Array, reach: float, colour: Color) -> void:
	var swing := 1.0 if frame == 0 else -1.0
	for i in ys.size():
		var y: float = ys[i]
		for sd: float in [-1.0, 1.0]:
			var kick := swing * sd * (1.0 if i % 2 == 0 else -1.0) * 1.2 * s
			var hip := Vector2(sd * reach * 0.45, y)
			var knee := Vector2(sd * reach, y - 0.6 * s + kick * 0.4)
			var foot := Vector2(sd * (reach + 1.2 * s), y + 1.4 * s + kick)
			b.stroke(PackedVector2Array([hip, knee, foot]), 0.7 * s, colour)

static func _feelers(b: Face.Builder, s: float, from_y: float, colour: Color, long := 1.0) -> void:
	for sd: float in [-1.0, 1.0]:
		var tip := Vector2(sd * 2.6 * s * long, from_y - 3.0 * s * long)
		var stem := Face.Builder.bezier2(Vector2(sd * 0.8 * s, from_y), Vector2(sd * 1.0 * s, from_y - 2.2 * s * long), tip, 8)
		b.stroke(stem, 0.5 * s, colour)
		b.disc(tip, 0.6 * s, colour)

static func _shine(b: Face.Builder, at: Vector2, rx: float, ry: float) -> void:
	b.ellipse(at, rx, ry, Color(1, 1, 1, 0.35))

# --- the pests ---

## An aphid: a plump soft pear of a bug.
static func aphid(b: Face.Builder, s: float, frame: int, body: Color) -> void:
	b.ellipse(Vector2(0, 1.5 * s), 4.8 * s, 3.0 * s, SHADOW)
	_legs(b, s, frame, [-1.0 * s, 1.0 * s, 3.0 * s], 4.2 * s, body.darkened(0.45))
	b.ellipse(Vector2(0, 1.2 * s), 4.4 * s, 5.2 * s, body.darkened(0.12))
	b.ellipse(Vector2(0, 0.8 * s), 3.9 * s, 4.6 * s, body)
	_shine(b, Vector2(-1.5 * s, -0.6 * s), 1.2 * s, 1.8 * s)
	b.ellipse(Vector2(0, -3.9 * s), 2.8 * s, 2.4 * s, body.lightened(0.15))
	_feelers(b, s, -5.6 * s, body.darkened(0.45))
	_eyes(b, Vector2(0, -3.9 * s), 1.1 * s, 0.6 * s)

## An ant: three beads, quick and thin.
static func ant(b: Face.Builder, s: float, frame: int, body: Color) -> void:
	b.ellipse(Vector2(0, 1.5 * s), 3.2 * s, 5.5 * s, SHADOW)
	_legs(b, s, frame, [-1.4 * s, 0.2 * s, 1.8 * s], 3.4 * s, body.darkened(0.5))
	b.ellipse(Vector2(0, 3.6 * s), 2.6 * s, 3.2 * s, body.darkened(0.1))
	b.ellipse(Vector2(0, 0.2 * s), 1.6 * s, 1.9 * s, body)
	b.ellipse(Vector2(0, -3.2 * s), 2.3 * s, 2.1 * s, body.lightened(0.1))
	_shine(b, Vector2(-0.8 * s, 2.6 * s), 0.8 * s, 1.2 * s)
	_feelers(b, s, -4.8 * s, body.darkened(0.5), 1.2)
	_eyes(b, Vector2(0, -3.3 * s), 0.9 * s, 0.5 * s)

## A gnat: small with buzzing wings.
static func gnat(b: Face.Builder, s: float, frame: int, body: Color) -> void:
	var spread := 0.7 if frame == 0 else 0.25
	b.ellipse(Vector2(0, 1.5 * s), 2.6 * s, 2.0 * s, SHADOW)
	for sd: float in [-1.0, 1.0]:
		var xf := Transform2D(sd * spread, Vector2(sd * 2.6 * s, -0.2 * s))
		b.fan(xf * Face.Builder.ring(Vector2.ZERO, 1.8 * s, 3.0 * s), WING)
	b.ellipse(Vector2(0, 0.8 * s), 2.4 * s, 2.9 * s, body)
	b.stroke(PackedVector2Array([Vector2(-2.1 * s, 1.4 * s), Vector2(2.1 * s, 1.4 * s)]), 0.7 * s, body.darkened(0.4))
	b.ellipse(Vector2(0, -2.2 * s), 1.9 * s, 1.7 * s, body.lightened(0.2))
	_eyes(b, Vector2(0, -2.2 * s), 0.75 * s, 0.45 * s)

## A beetle: a round shell split down the back, with spots.
static func beetle(b: Face.Builder, s: float, frame: int, body: Color) -> void:
	b.ellipse(Vector2(0, 1.6 * s), 5.4 * s, 4.0 * s, SHADOW)
	_legs(b, s, frame, [-1.0 * s, 1.2 * s, 3.2 * s], 4.6 * s, INK)
	b.ellipse(Vector2(0, 1.0 * s), 5.2 * s, 5.6 * s, body.darkened(0.35))
	for sd: float in [-1.0, 1.0]:
		var half := PackedVector2Array()
		for p in Face.Builder.arc_points(Vector2.ZERO, 4.9 * s, -PI * 0.5, PI * 0.5):
			half.append(Vector2(p.x * sd + sd * 0.2 * s, p.y * 1.08 + 1.0 * s))
		b.fan(half, body)
		b.disc(Vector2(sd * 2.4 * s, -0.4 * s), 0.9 * s, body.darkened(0.45))
		b.disc(Vector2(sd * 2.6 * s, 2.8 * s), 0.8 * s, body.darkened(0.45))
		_shine(b, Vector2(sd * 1.6 * s, -1.9 * s), 1.1 * s, 0.6 * s)
	b.ellipse(Vector2(0, -4.6 * s), 3.0 * s, 2.2 * s, INK.lerp(body, 0.25))
	_feelers(b, s, -6.2 * s, INK, 0.8)
	for sd: float in [-1.0, 1.0]:
		b.disc(Vector2(sd * 1.3 * s, -4.8 * s), 0.8 * s, Color.WHITE)
		b.disc(Vector2(sd * 1.3 * s, -4.6 * s), 0.42 * s, INK)

## A slug: a long soft body with eye stalks, and a glistening trail.
static func slug(b: Face.Builder, s: float, frame: int, body: Color) -> void:
	var squeeze := 1.0 if frame == 0 else 0.92
	b.ellipse(Vector2(0, 2.0 * s), 3.6 * s, 6.4 * s * squeeze, SHADOW)
	b.ellipse(Vector2(0, 5.0 * s), 2.2 * s, 3.4 * s, Color(1, 1, 1, 0.2))
	b.ellipse(Vector2(0, 1.2 * s), 3.2 * s, 6.2 * s * squeeze, body.darkened(0.1))
	b.ellipse(Vector2(0, 0.6 * s), 2.6 * s, 5.4 * s * squeeze, body)
	b.ellipse(Vector2(0, 0.0), 2.9 * s, 2.6 * s, body.lightened(0.12))
	_shine(b, Vector2(-1.0 * s, 1.8 * s), 0.8 * s, 2.2 * s)
	for sd: float in [-1.0, 1.0]:
		var tip := Vector2(sd * 1.9 * s, -6.8 * s * squeeze)
		b.stroke(PackedVector2Array([Vector2(sd * 0.9 * s, -3.8 * s), tip]), 0.7 * s, body.darkened(0.15))
		b.disc(tip, 0.9 * s, body.darkened(0.2))
		b.disc(tip + Vector2(0, -0.1 * s), 0.5 * s, INK)
	b.ellipse(Vector2(0, -2.8 * s), 1.1 * s, 0.5 * s, Color(Pal.CHEEK, 0.7))

## A wasp: striped, winged, flying high (its shadow falls well below it).
static func wasp(b: Face.Builder, s: float, frame: int, body: Color) -> void:
	b.ellipse(Vector2(1.5 * s, 7.0 * s), 3.4 * s, 2.4 * s, Color(SHADOW, 0.14))
	var spread := 0.55 if frame == 0 else 0.15
	for sd: float in [-1.0, 1.0]:
		var xf := Transform2D(sd * spread, Vector2(sd * 3.4 * s, -0.8 * s))
		b.fan(xf * Face.Builder.ring(Vector2.ZERO, 2.2 * s, 4.4 * s), WING)
		b.stroke(xf * Face.Builder.ring(Vector2.ZERO, 2.2 * s, 4.4 * s), 0.3 * s, Color(1, 1, 1, 0.6), true)
	b.ellipse(Vector2(0, 2.6 * s), 2.6 * s, 3.8 * s, body)
	for k in 3:
		var y := (1.2 + k * 1.4) * s
		b.stroke(PackedVector2Array([Vector2(-2.3 * s, y), Vector2(2.3 * s, y)]), 0.8 * s, INK)
	b.stroke(PackedVector2Array([Vector2(0, 6.2 * s), Vector2(0, 7.6 * s)]), 0.6 * s, INK)
	b.ellipse(Vector2(0, -1.4 * s), 1.8 * s, 1.6 * s, body.darkened(0.25))
	b.ellipse(Vector2(0, -3.8 * s), 2.2 * s, 1.9 * s, body.lightened(0.15))
	_feelers(b, s, -5.4 * s, INK, 0.8)
	_eyes(b, Vector2(0, -3.8 * s), 0.9 * s, 0.55 * s)

## The boss: a great stag beetle with antlers.
static func stag(b: Face.Builder, s: float, frame: int, body: Color) -> void:
	var k := 1.35
	b.ellipse(Vector2(0, 2.0 * s * k), 5.6 * s * k, 4.4 * s * k, SHADOW)
	_legs(b, s * k, frame, [-1.0 * s * k, 1.4 * s * k, 3.6 * s * k], 4.8 * s * k, INK)
	b.ellipse(Vector2(0, 1.4 * s * k), 5.2 * s * k, 5.8 * s * k, body.darkened(0.4))
	b.ellipse(Vector2(0, 1.2 * s * k), 4.8 * s * k, 5.4 * s * k, body)
	b.stroke(PackedVector2Array([Vector2(0, -3.6 * s * k), Vector2(0, 6.4 * s * k)]), 0.4 * s * k, body.darkened(0.4))
	_shine(b, Vector2(-2.0 * s * k, -0.4 * s * k), 1.2 * s * k, 2.4 * s * k)
	_shine(b, Vector2(2.0 * s * k, -0.4 * s * k), 0.8 * s * k, 1.6 * s * k)
	b.ellipse(Vector2(0, -4.8 * s * k), 3.6 * s * k, 2.4 * s * k, INK.lerp(body, 0.3))
	for sd: float in [-1.0, 1.0]:
		var jaw := Face.Builder.bezier2(Vector2(sd * 1.8 * s * k, -6.2 * s * k), Vector2(sd * 4.4 * s * k, -9.0 * s * k), Vector2(sd * 1.0 * s * k, -11.0 * s * k), 10)
		b.stroke(jaw, 1.0 * s * k, INK.lerp(body, 0.35))
		b.stroke(PackedVector2Array([jaw[5], jaw[5] + Vector2(-sd * 1.2 * s * k, -0.2 * s * k)]), 0.6 * s * k, INK.lerp(body, 0.35))
	for sd: float in [-1.0, 1.0]:
		b.disc(Vector2(sd * 1.5 * s * k, -5.0 * s * k), 0.8 * s * k, Color.WHITE)
		b.disc(Vector2(sd * 1.5 * s * k, -4.8 * s * k), 0.45 * s * k, INK)
	# a crown of gold dots, so a boss reads as one at a glance
	for i in 3:
		b.disc(Vector2((i - 1) * 1.4 * s * k, -7.0 * s * k), 0.55 * s * k, PIP)

# --- the towers ---

static func tower_into(b: Face.Builder, key: String, level: int, u: float, at: Vector2) -> void:
	var s := u / 16.0
	# the slab
	var half := 7.0 * s
	b.fan(Face.Builder.round_rect(at + Vector2(-half + 0.8 * s, -half + 1.6 * s), Vector2(half * 2, half * 2), 3.0 * s), SHADOW)
	b.fan(Face.Builder.round_rect(at + Vector2(-half, -half), Vector2(half * 2, half * 2), 3.0 * s), SLAB_DEEP)
	b.fan(Face.Builder.round_rect(at + Vector2(-half, -half), Vector2(half * 2, half * 2 - 1.2 * s), 3.0 * s), SLAB)
	var els: Array = Sim.TOWERS[key].els
	match key:
		"thorn":
			_bramble(b, s, at, level)
		"acorn":
			_sling(b, s, at, level)
		_:
			var dual := els.size() == 2
			var r := (4.2 if dual else 3.6) * s + level * 0.35 * s
			# the pot
			b.disc(at + Vector2(0, 0.8 * s), r + 1.8 * s, POT_DEEP)
			b.disc(at + Vector2(0, 0.4 * s), r + 1.4 * s, POT)
			b.disc(at + Vector2(0, 0.4 * s), r + 0.6 * s, POT_DEEP.darkened(0.2))
			if dual:
				# a dual's leaves: two sprigs under the orb
				for sd: float in [-1.0, 1.0]:
					var lf := Face.Builder.ring(Vector2.ZERO, 1.2 * s, 2.6 * s)
					b.fan(Transform2D(sd * 0.9, at + Vector2(sd * (r + 0.6 * s), -r * 0.6)) * lf, BRAMBLE)
			orb(b, at + Vector2(0, -0.4 * s), r, els)
	# a pip a level along the slab's foot
	var n := level + 1
	for i in n:
		var x := (i - (n - 1) * 0.5) * 2.2 * s
		b.disc(at + Vector2(x, half - 1.4 * s), 0.85 * s, WOOD_DEEP)
		b.disc(at + Vector2(x, half - 1.5 * s), 0.6 * s, PIP)

## A bramble clump bristling with thorns.
static func _bramble(b: Face.Builder, s: float, at: Vector2, level: int) -> void:
	var r := (4.0 + level * 0.6) * s
	for i in 7:
		var a := TAU * i / 7.0
		b.disc(at + Vector2.from_angle(a) * r * 0.55 + Vector2(0, -0.6 * s), r * 0.55, BRAMBLE_DEEP)
	for i in 7:
		var a := TAU * i / 7.0 + 0.3
		var p := at + Vector2.from_angle(a) * r * 0.95 + Vector2(0, -0.6 * s)
		var q := at + Vector2.from_angle(a) * (r * 1.3) + Vector2(0, -0.6 * s)
		b.stroke(PackedVector2Array([p, q]), 0.6 * s, Color("e9dcc0"))
	b.disc(at + Vector2(0, -0.8 * s), r * 0.7, BRAMBLE)
	b.disc(at + Vector2(-r * 0.25, -r * 0.35), r * 0.25, BRAMBLE.lightened(0.2))
	if level >= 1:
		for i in level * 2:
			var a := TAU * i / (level * 2.0) + 0.8
			b.disc(at + Vector2.from_angle(a) * r * 0.45 + Vector2(0, -0.6 * s), 0.9 * s, Pal.BERRY)

## A little wooden sling with an acorn in its cup.
static func _sling(b: Face.Builder, s: float, at: Vector2, level: int) -> void:
	var w := (4.6 + level * 0.5) * s
	b.fan(Face.Builder.round_rect(at + Vector2(-w, -1.0 * s), Vector2(w * 2, 4.0 * s), 1.2 * s), WOOD_DEEP)
	b.fan(Face.Builder.round_rect(at + Vector2(-w, -1.4 * s), Vector2(w * 2, 3.6 * s), 1.2 * s), WOOD)
	b.stroke(PackedVector2Array([at + Vector2(0, 1.0 * s), at + Vector2(0, -4.8 * s)]), 1.2 * s, WOOD_DEEP)
	b.disc(at + Vector2(0, -5.0 * s), 2.2 * s, WOOD_DEEP)
	b.ellipse(at + Vector2(0, -4.6 * s), 1.6 * s, 1.9 * s, ACORN)
	b.ellipse(at + Vector2(0, -5.8 * s), 1.8 * s, 1.0 * s, ACORN_CAP)
	for i in level:
		b.ellipse(at + Vector2((i * 2 - 1) * 2.8 * s, 0.4 * s), 1.1 * s, 1.3 * s, ACORN)
		b.ellipse(at + Vector2((i * 2 - 1) * 2.8 * s, -0.4 * s), 1.2 * s, 0.7 * s, ACORN_CAP)

## An element's orb: its colour with a glyph on it; a dual's is split down
## the middle, one colour a side, with both glyphs.
static func orb(b: Face.Builder, at: Vector2, r: float, els: Array) -> void:
	for k in 3:
		b.disc(at, r * (1.5 - k * 0.15), Color(col(els[0]), 0.08))
	if els.size() == 1:
		var e: int = els[0]
		b.disc(at, r, deep(e))
		b.disc(at + Vector2(0, -r * 0.06), r * 0.92, col(e))
		glyph(b, e, at, r * 0.55, Color(1, 1, 1, 0.92))
	else:
		b.disc(at, r, deep(els[0]).lerp(deep(els[1]), 0.5))
		for i in 2:
			var e: int = els[i]
			var sd := -1.0 if i == 0 else 1.0
			var half := PackedVector2Array([at])
			for p in Face.Builder.arc_points(at, r * 0.92, PI * 0.5 + (0.0 if i == 0 else PI), PI * 1.5 + (0.0 if i == 0 else PI)):
				half.append(p)
			b.polygon(half, col(e))
			glyph(b, e, at + Vector2(sd * r * 0.46, 0), r * 0.34, Color(1, 1, 1, 0.92))
	b.ellipse(at + Vector2(-r * 0.35, -r * 0.45), r * 0.28, r * 0.16, Color(1, 1, 1, 0.45))

## An element's sign, `r` across its half-width.
static func glyph(b: Face.Builder, el: int, at: Vector2, r: float, ink: Color) -> void:
	match el:
		Sim.El.SUN:
			b.disc(at, r * 0.45, ink)
			for i in 8:
				var a := TAU * i / 8.0
				b.stroke(PackedVector2Array([at + Vector2.from_angle(a) * r * 0.65, at + Vector2.from_angle(a) * r]), r * 0.16, ink)
		Sim.El.SHADE:
			var moon := PackedVector2Array()
			for p in Face.Builder.arc_points(at, r * 0.85, PI * 0.35, PI * 1.65):
				moon.append(p)
			for p in Face.Builder.arc_points(at + Vector2(r * 0.35, 0), r * 0.62, PI * 1.45, PI * 0.55):
				moon.append(p)
			b.polygon(moon, ink)
		Sim.El.RAIN:
			var drop := PackedVector2Array([at + Vector2(0, -r)])
			for p in Face.Builder.arc_points(at + Vector2(0, r * 0.3), r * 0.6, -PI * 0.1, PI * 1.1):
				drop.append(p)
			b.polygon(drop, ink)
		Sim.El.EMBER:
			# a flame with a second tongue licking up its left side
			var f := PackedVector2Array()
			f.append_array(Face.Builder.bezier2(at + Vector2(r * 0.1, -r), at + Vector2(r * 0.8, -r * 0.2), at + Vector2(r * 0.5, r * 0.55), 8))
			f.append_array(Face.Builder.bezier2(at + Vector2(r * 0.5, r * 0.55), at + Vector2(0, r * 1.05), at + Vector2(-r * 0.5, r * 0.55), 8))
			f.append_array(Face.Builder.bezier2(at + Vector2(-r * 0.5, r * 0.55), at + Vector2(-r * 0.75, r * 0.05), at + Vector2(-r * 0.45, -r * 0.45), 6))
			f.append_array(Face.Builder.bezier2(at + Vector2(-r * 0.45, -r * 0.45), at + Vector2(-r * 0.2, -r * 0.05), at + Vector2(-r * 0.05, -r * 0.25), 5))
			f.append_array(Face.Builder.bezier2(at + Vector2(-r * 0.05, -r * 0.25), at + Vector2(0, -r * 0.6), at + Vector2(r * 0.1, -r), 6))
			b.polygon(f, ink)
		Sim.El.LEAF:
			var xf := Transform2D(-0.7, at)
			var leaf := PackedVector2Array()
			leaf.append_array(Face.Builder.bezier2(Vector2(0, -r), Vector2(r * 0.8, 0), Vector2(0, r), 8))
			leaf.append_array(Face.Builder.bezier2(Vector2(0, r), Vector2(-r * 0.8, 0), Vector2(0, -r), 8))
			b.polygon(xf * leaf, ink)
		Sim.El.STONE:
			var hexa := PackedVector2Array()
			for i in 6:
				hexa.append(at + Vector2.from_angle(TAU * i / 6.0 + PI / 6.0) * r * 0.85)
			b.fan(hexa, ink)
		_:
			b.disc(at, r * 0.5, ink)
