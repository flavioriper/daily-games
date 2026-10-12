extends RefCounted

## Griddle's drawings, each built once into a mesh and moved by a transform
## (spec docs/superpowers/specs/2026-10-12-arcade-griddle-design.md). The
## four grounds (fields, yard, counter, office) are one mesh each; a lot's
## crop, a toastie, a cheese, the stand's people and the things with a
## switch are small meshes of their own. Nothing here has a hard edge that
## is not a thing's own: shadows and patches are Furrow's soft blobs. The
## cows are Furrow's (arcade/furrow_animals.gd). No face is animated: the
## stand's people are scenery, a round head on a coat.

const Pal = preload("res://core/palette.gd")
const Face = preload("res://ui/faces/face.gd")
const Soft = preload("res://arcade/furrow_art.gd")

const INK := Color("4a3a2a")
const CREAM := Color("fffaf0")
const PAPER := Color("fcf7ef")
const GRASS := Color("a3cf78")
const GRASS_HI := Color("b9dc8c")
const GRASS_DEEP := Color("86b85f")
const SOIL := Color("a8754a")
const SOIL_HI := Color("c08e5e")
const SOIL_DEEP := Color("8a5c38")
const SOIL_DARK := Color("74492b")
const WOOD := Color("c79a66")
const WOOD_HI := Color("e0b988")
const WOOD_DEEP := Color("9c7248")
const STRAW := Color("ecd08a")
const STRAW_DEEP := Color("d3b064")
const WHEAT := Color("eec35a")
const WHEAT_DEEP := Color("cf9c34")
const CLOVER := Color("6fae4a")
const CLOVER_HI := Color("93c95f")
const CLOVER_BLOOM := Color("e58fb0")
const TEAL := Color("5fb3a8")
const TEAL_DEEP := Color("3f8f85")
const TEAL_HI := Color("8fd0c6")
const WALL := Color("f6ead2")
const WALL_SHADE := Color("e4d4b4")
const FLOOR := Color("e9d7b4")
const FLOOR_DEEP := Color("d6bf94")
const BARN := Color("c8553f")
const BARN_DEEP := Color("a23f30")
const ROOF := Color("8c5a44")
const BREAD := Color("e9b86a")
const BREAD_DEEP := Color("c48a3c")
const TOAST := Color("c98a3e")
const CHEESE := Color("f6cf4f")
const CHEESE_DEEP := Color("dba92c")
const COIN := Color("f2c14e")
const COIN_DEEP := Color("c98f22")
const IRON := Color("5c5f66")
const IRON_HI := Color("8b8f98")
const BLANKET := Color("7fa8d9")
const OK := Color("7fc06a")
const AMBER := Color("f0a93c")
const RED := Color("e0604c")
## The coats the town wears to the counter.
const COATS := [Color("e58f6a"), Color("7fa8d9"), Color("b78fd6"), Color("f0c05a"), Color("7fc0a0"), Color("e58fb0")]
const SKINS := [Color("f6d2b0"), Color("e0ad84"), Color("b9835c"), Color("8e5d3e")]
## A place's own colour, on its tray button and its page of the shop.
const PLACE_TINT := {"fields": Color("6fae4a"), "yard": Color("d98b4a"), "counter": Color("3f9f93"), "office": Color("8d7bc9")}

static var _cache := {}

static func _made(key: String, build: Callable) -> ArrayMesh:
	if _cache.has(key):
		return _cache[key]
	if _cache.size() > 260:
		_cache.clear()
	var b := Face.Builder.new()
	build.call(b)
	var m := b.mesh()
	_cache[key] = m
	return m

static func _rr(b: Face.Builder, at: Vector2, size: Vector2, r: float, col: Color) -> void:
	b.fan(Face.Builder.round_rect(at, size, r), col)

static func _shadow(b: Face.Builder, c: Vector2, rx: float, ry: float, a := 0.3) -> void:
	Soft.soft(b, c, rx, ry, Color(0.2, 0.16, 0.08, a))

# --- small things ---

## The stand's coin, `tall` pixels, its middle at the origin.
static func coin(tall: float) -> ArrayMesh:
	return _made("coin%.1f" % tall, func(b: Face.Builder) -> void: coin_into(b, Vector2.ZERO, tall))

static func coin_into(b: Face.Builder, c: Vector2, tall: float) -> void:
	var r := tall * 0.5
	b.disc(c + Vector2(0, r * 0.12), r, COIN_DEEP)
	b.disc(c, r * 0.94, COIN)
	b.disc(c, r * 0.62, Color("f8d776"))
	b.ellipse(c + Vector2(-r * 0.3, -r * 0.34), r * 0.2, r * 0.12, Color(CREAM, 0.8))

## A loaf, `s` wide, its middle at the origin.
static func loaf(s: float) -> ArrayMesh:
	return _made("loaf%.1f" % s, func(b: Face.Builder) -> void: loaf_into(b, Vector2.ZERO, s))

static func loaf_into(b: Face.Builder, c: Vector2, s: float) -> void:
	_rr(b, c + Vector2(-s * 0.5, -s * 0.24), Vector2(s, s * 0.56), s * 0.26, BREAD_DEEP)
	_rr(b, c + Vector2(-s * 0.46, -s * 0.3), Vector2(s * 0.92, s * 0.5), s * 0.24, BREAD)
	for x in [-0.2, 0.0, 0.2]:
		b.stroke(PackedVector2Array([c + Vector2(s * (x - 0.05), -s * 0.2), c + Vector2(s * (x + 0.05), -s * 0.02)]), s * 0.05, BREAD_DEEP)

## A wheel of cheese with a wedge cut, `s` wide.
static func cheese(s: float) -> ArrayMesh:
	return _made("cheese%.1f" % s, func(b: Face.Builder) -> void: cheese_into(b, Vector2.ZERO, s))

static func cheese_into(b: Face.Builder, c: Vector2, s: float) -> void:
	var r := s * 0.5
	b.ellipse(c + Vector2(0, r * 0.24), r, r * 0.62, CHEESE_DEEP)
	b.ellipse(c, r, r * 0.62, CHEESE)
	b.polygon(PackedVector2Array([c, c + Vector2(r * 0.95, -r * 0.1), c + Vector2(r * 0.6, r * 0.48)]), CHEESE_DEEP)
	for p in [Vector2(-0.4, -0.1), Vector2(-0.1, 0.24), Vector2(0.2, -0.3)]:
		b.ellipse(c + p * r, r * 0.12, r * 0.08, CHEESE_DEEP)

## A sack of feed, `s` wide.
static func sack(s: float) -> ArrayMesh:
	return _made("sack%.1f" % s, func(b: Face.Builder) -> void:
		_rr(b, Vector2(-s * 0.4, -s * 0.4), Vector2(s * 0.8, s * 0.9), s * 0.26, Color("c9b086"))
		_rr(b, Vector2(-s * 0.34, -s * 0.36), Vector2(s * 0.68, s * 0.8), s * 0.22, Color("e3cfa6"))
		b.fan(Face.Builder.round_rect(Vector2(-s * 0.2, -s * 0.56), Vector2(s * 0.4, s * 0.22), s * 0.08), Color("c9b086"))
		_trefoil(b, Vector2(0, s * 0.06), s * 0.16, CLOVER))

static func _trefoil(b: Face.Builder, c: Vector2, r: float, col: Color) -> void:
	for i in 3:
		b.disc(c + Vector2.from_angle(-PI * 0.5 + TAU * i / 3.0) * r * 0.62, r * 0.62, col)

## A toastie, `s` wide: two slices and the cheese between. `done` 0 to 1
## browns it.
static func toastie(s: float, done := 1.0) -> ArrayMesh:
	var step := int(round(clampf(done, 0.0, 1.0) * 4.0))
	return _made("toastie%.1f/%d" % [s, step], func(b: Face.Builder) -> void: toastie_into(b, Vector2.ZERO, s, step / 4.0))

static func toastie_into(b: Face.Builder, c: Vector2, s: float, done := 1.0) -> void:
	var top := Color("f3deb0").lerp(TOAST, done)
	var edge := Color("d9bd86").lerp(Color("9c6426"), done)
	var w := s
	var h := s * 0.7
	_rr(b, c + Vector2(-w * 0.5, -h * 0.5 + s * 0.14), Vector2(w, h), s * 0.16, edge)
	_rr(b, c + Vector2(-w * 0.54, -h * 0.5 + s * 0.06), Vector2(w * 1.08, h * 0.9), s * 0.1, CHEESE)
	_rr(b, c + Vector2(-w * 0.5, -h * 0.5 - s * 0.04), Vector2(w, h), s * 0.16, edge)
	_rr(b, c + Vector2(-w * 0.44, -h * 0.5), Vector2(w * 0.88, h * 0.84), s * 0.13, top)
	if done > 0.4:
		for x in [-0.2, 0.0, 0.2]:
			b.stroke(PackedVector2Array([c + Vector2(s * (x - 0.08), -h * 0.3), c + Vector2(s * (x + 0.08), h * 0.16)]), s * 0.045, Color(edge, done))

## A bottle of tonic, `s` tall.
static func tonic(s: float) -> ArrayMesh:
	return _made("tonic%.1f" % s, func(b: Face.Builder) -> void:
		_rr(b, Vector2(-s * 0.26, -s * 0.2), Vector2(s * 0.52, s * 0.68), s * 0.14, Color("3f8f85"))
		_rr(b, Vector2(-s * 0.2, -s * 0.16), Vector2(s * 0.4, s * 0.6), s * 0.1, Color("7fd6c6"))
		_rr(b, Vector2(-s * 0.1, -s * 0.44), Vector2(s * 0.2, s * 0.28), s * 0.05, Color("3f8f85"))
		_rr(b, Vector2(-s * 0.14, -s * 0.52), Vector2(s * 0.28, s * 0.12), s * 0.04, WOOD_DEEP)
		b.disc(Vector2(0, s * 0.14), s * 0.1, CREAM))

## The kettle, `s` wide.
static func kettle(s: float) -> ArrayMesh:
	return _made("kettle%.1f" % s, func(b: Face.Builder) -> void:
		b.stroke(Face.Builder.arc_points(Vector2(0, -s * 0.2), s * 0.3, PI * 1.1, PI * 1.9), s * 0.07, IRON)
		b.polygon(PackedVector2Array([Vector2(s * 0.3, -s * 0.02), Vector2(s * 0.56, -s * 0.2), Vector2(s * 0.56, -s * 0.1), Vector2(s * 0.34, s * 0.12)]), TEAL_DEEP)
		b.ellipse(Vector2(0, s * 0.1), s * 0.4, s * 0.34, TEAL_DEEP)
		b.ellipse(Vector2(0, s * 0.06), s * 0.36, s * 0.3, TEAL)
		b.ellipse(Vector2(-s * 0.12, -s * 0.06), s * 0.1, s * 0.06, Color(CREAM, 0.6))
		b.disc(Vector2(0, -s * 0.26), s * 0.07, IRON))

## The hurry bell: a wooden clapper board, `s` wide (no bell rings here).
static func bell(s: float) -> ArrayMesh:
	return _made("bell%.1f" % s, func(b: Face.Builder) -> void:
		_rr(b, Vector2(-s * 0.4, -s * 0.34), Vector2(s * 0.8, s * 0.6), s * 0.12, WOOD_DEEP)
		_rr(b, Vector2(-s * 0.34, -s * 0.3), Vector2(s * 0.68, s * 0.48), s * 0.1, WOOD_HI)
		b.stroke(PackedVector2Array([Vector2(-s * 0.2, s * 0.3), Vector2(s * 0.14, -s * 0.06)]), s * 0.08, WOOD_DEEP)
		b.disc(Vector2(s * 0.16, -s * 0.08), s * 0.13, IRON))

## A bucket of scraps, `s` wide.
static func bucket(s: float) -> ArrayMesh:
	return _made("bucket%.1f" % s, func(b: Face.Builder) -> void:
		b.stroke(Face.Builder.arc_points(Vector2(0, -s * 0.14), s * 0.32, PI, TAU), s * 0.05, IRON)
		b.polygon(PackedVector2Array([Vector2(-s * 0.38, -s * 0.16), Vector2(s * 0.38, -s * 0.16), Vector2(s * 0.28, s * 0.4), Vector2(-s * 0.28, s * 0.4)]), IRON)
		b.polygon(PackedVector2Array([Vector2(-s * 0.32, -s * 0.12), Vector2(s * 0.06, -s * 0.12), Vector2(s * 0.02, s * 0.34), Vector2(-s * 0.24, s * 0.34)]), IRON_HI)
		b.ellipse(Vector2(0, -s * 0.16), s * 0.38, s * 0.1, Color("8a6a44"))
		b.disc(Vector2(-s * 0.1, -s * 0.2), s * 0.08, Color("d98b4a"))
		b.disc(Vector2(s * 0.12, -s * 0.18), s * 0.07, CLOVER))

## A signboard `w` wide with its foot at the origin; the price is lettered
## on it by the place.
static func signboard(w: float) -> ArrayMesh:
	return _made("sign%.0f" % w, func(b: Face.Builder) -> void:
		var h := w * 0.46
		_rr(b, Vector2(-w * 0.05, -h * 0.4), Vector2(w * 0.1, h * 0.5), w * 0.03, WOOD_DEEP)
		_rr(b, Vector2(-w * 0.5, -h * 1.3 + 5.0), Vector2(w, h), h * 0.24, Color(SOIL_DARK, 0.35))
		_rr(b, Vector2(-w * 0.5, -h * 1.3), Vector2(w, h), h * 0.24, WOOD_DEEP)
		_rr(b, Vector2(-w * 0.5 + 4.0, -h * 1.3 + 4.0), Vector2(w - 8.0, h - 10.0), h * 0.2, CREAM))

## A round button `r` in radius with a rim: a switch, the kettle's plate.
static func plate(r: float, col: Color) -> ArrayMesh:
	return _made("plate%.1f/%s" % [r, col.to_html()], func(b: Face.Builder) -> void:
		b.disc(Vector2(0, r * 0.1), r, Color(INK, 0.2))
		b.disc(Vector2.ZERO, r, CREAM)
		b.disc(Vector2.ZERO, r * 0.86, col))

# --- people ---

## One of the town, `s` tall, feet at the origin: coat `coat`, skin `skin`,
## a sour mouth when `cross`.
static func folk(s: float, coat: int, skin: int, cross := false) -> ArrayMesh:
	return _made("folk%.1f/%d/%d/%s" % [s, coat, skin, cross], func(b: Face.Builder) -> void:
		_person(b, s, COATS[coat % COATS.size()], SKINS[skin % SKINS.size()], cross, Color.TRANSPARENT))

## One of the crew, `s` tall: a cream apron and a teal cap; asleep on their
## feet when `worn`.
static func crew(s: float, skin: int, worn := false) -> ArrayMesh:
	return _made("crew%.1f/%d/%s" % [s, skin, worn], func(b: Face.Builder) -> void:
		_person(b, s, TEAL, SKINS[skin % SKINS.size()], worn, CREAM))

static func _person(b: Face.Builder, s: float, coat: Color, skin: Color, cross: bool, apron: Color) -> void:
	_shadow(b, Vector2(0, 0), s * 0.34, s * 0.09)
	var body := Face.Builder.round_rect(Vector2(-s * 0.26, -s * 0.62), Vector2(s * 0.52, s * 0.62), s * 0.24)
	b.fan(body, coat.darkened(0.14))
	_rr(b, Vector2(-s * 0.22, -s * 0.62), Vector2(s * 0.44, s * 0.56), s * 0.2, coat)
	if apron.a > 0.0:
		_rr(b, Vector2(-s * 0.15, -s * 0.5), Vector2(s * 0.3, s * 0.44), s * 0.08, apron)
	var head := Vector2(0, -s * 0.78)
	b.disc(head, s * 0.2, skin)
	if apron.a > 0.0:
		b.fan(Face.Builder.arc_points(head + Vector2(0, -s * 0.04), s * 0.21, PI, TAU), TEAL_DEEP)
		_rr(b, head + Vector2(-s * 0.02, -s * 0.12), Vector2(s * 0.3, s * 0.07), s * 0.03, TEAL_DEEP)
	else:
		b.fan(Face.Builder.arc_points(head + Vector2(0, -s * 0.02), s * 0.21, PI * 1.05, PI * 1.95), coat.darkened(0.4))
	var ink := Color(INK, 0.9)
	if cross:
		b.stroke(PackedVector2Array([head + Vector2(-s * 0.11, -s * 0.01), head + Vector2(-s * 0.05, s * 0.01)]), s * 0.03, ink)
		b.stroke(PackedVector2Array([head + Vector2(s * 0.11, -s * 0.01), head + Vector2(s * 0.05, s * 0.01)]), s * 0.03, ink)
		b.stroke(Face.Builder.arc_points(head + Vector2(0, s * 0.13), s * 0.06, PI * 1.15, PI * 1.85), s * 0.025, ink, false)
	else:
		b.disc(head + Vector2(-s * 0.08, 0), s * 0.026, ink)
		b.disc(head + Vector2(s * 0.08, 0), s * 0.026, ink)
		b.stroke(Face.Builder.arc_points(head + Vector2(0, s * 0.04), s * 0.07, PI * 0.2, PI * 0.8), s * 0.025, ink, false)
	b.disc(head + Vector2(-s * 0.13, s * 0.05), s * 0.035, Color("f4a7a0", 0.6))
	b.disc(head + Vector2(s * 0.13, s * 0.05), s * 0.035, Color("f4a7a0", 0.6))

# --- the fields ---

## A lot's earth, `size` pixels, its middle at the origin. `kind` 0 turned
## earth, 1 resting (grown over), 2 not yet bought (meadow, a faint edge).
static func lot(size: Vector2, kind: int) -> ArrayMesh:
	return _made("lot%.0f/%.0f/%d" % [size.x, size.y, kind], func(b: Face.Builder) -> void:
		var r := minf(size.x, size.y) * 0.16
		var at := -size * 0.5
		if kind == 2:
			_rr(b, at, size, r, Color(GRASS_DEEP, 0.35))
			_rr(b, at + Vector2(5, 5), size - Vector2(10, 10), r * 0.8, Color(GRASS_HI, 0.5))
			return
		_rr(b, at + Vector2(0, 8.0), size, r, Color(SOIL_DARK, 0.5))
		_rr(b, at, size, r, SOIL_DEEP)
		_rr(b, at + Vector2(6, 5), size - Vector2(12, 14), r * 0.84, SOIL)
		Soft.soft(b, Vector2(-size.x * 0.16, -size.y * 0.2), size.x * 0.4, size.y * 0.3, Color(SOIL_HI, 0.5))
		for i in 3:
			var y := at.y + size.y * (0.28 + 0.22 * i)
			b.stroke(PackedVector2Array([Vector2(at.x + size.x * 0.12, y), Vector2(at.x + size.x * 0.88, y)]), size.y * 0.05, Color(SOIL_DEEP, 0.8))
		if kind == 1:
			for k in 9:
				var p := Vector2(at.x + size.x * (0.2 + 0.3 * (k % 3)) + (k * 7 % 11) - 5.0, at.y + size.y * (0.3 + 0.24 * (k / 3)))
				for d in [-0.5, 0.0, 0.5]:
					b.stroke(PackedVector2Array([p, p + Vector2(d * 14.0, -14.0 * (1.0 - absf(d) * 0.4))]), 3.5, GRASS_DEEP if k % 2 == 0 else GRASS_HI))

## A lot's crop at `stage` (0 sprouts, 1 half, 2 tall, 3 ripe), for a lot
## `size` pixels: nine plants in three rows, the middle of the lot at the
## origin.
static func crop(kind: int, stage: int, size: Vector2) -> ArrayMesh:
	return _made("crop%d/%d/%.0f/%.0f" % [kind, stage, size.x, size.y], func(b: Face.Builder) -> void:
		var s := minf(size.x / 3.6, size.y / 3.2)
		for row in 3:
			for col in 3:
				var foot := Vector2(size.x * (-0.3 + 0.3 * col), size.y * (-0.16 + 0.26 * row))
				if kind == 0:
					_wheat(b, foot, s, stage)
				else:
					_clover(b, foot, s, stage))

static func _wheat(b: Face.Builder, foot: Vector2, s: float, stage: int) -> void:
	var tall: float = s * float([0.24, 0.5, 0.78, 0.86][stage])
	var col: Color = [CLOVER_HI, CLOVER_HI, Color("c9cf6a"), WHEAT][stage]
	for d in [-0.22, 0.0, 0.22]:
		var top := foot + Vector2(d * s * 0.9, -tall * (1.0 - absf(d) * 0.5))
		b.stroke(PackedVector2Array([foot + Vector2(d * s * 0.3, 0), top]), maxf(2.5, s * 0.07), col.darkened(0.12))
		if stage >= 2:
			b.ellipse(top + Vector2(0, -s * 0.08), s * 0.09, s * 0.17, WHEAT if stage == 3 else Color("d8d478"))
			if stage == 3:
				b.ellipse(top + Vector2(-s * 0.03, -s * 0.12), s * 0.03, s * 0.07, Color(CREAM, 0.7))

static func _clover(b: Face.Builder, foot: Vector2, s: float, stage: int) -> void:
	var r: float = s * float([0.12, 0.2, 0.28, 0.3][stage])
	_shadow(b, foot, r * 1.5, r * 0.5, 0.2)
	for i in 3:
		b.disc(foot + Vector2(0, -r * 0.8) + Vector2.from_angle(-PI * 0.5 + TAU * i / 3.0) * r * 0.7, r * 0.7, CLOVER if i != 0 else CLOVER_HI)
	if stage == 3:
		b.disc(foot + Vector2(0, -r * 1.7), r * 0.5, CLOVER_BLOOM)
		b.disc(foot + Vector2(-r * 0.12, -r * 1.82), r * 0.2, Color(CREAM, 0.8))

## The cart, `s` wide, its wheels' foot at the origin.
static func cart(s: float) -> ArrayMesh:
	return _made("cart%.1f" % s, func(b: Face.Builder) -> void:
		_shadow(b, Vector2(0, 0), s * 0.6, s * 0.12)
		_rr(b, Vector2(-s * 0.5, -s * 0.5), Vector2(s, s * 0.34), s * 0.06, WOOD_DEEP)
		_rr(b, Vector2(-s * 0.46, -s * 0.48), Vector2(s * 0.92, s * 0.24), s * 0.05, WOOD_HI)
		b.ellipse(Vector2(0, -s * 0.52), s * 0.36, s * 0.14, STRAW)
		b.stroke(PackedVector2Array([Vector2(s * 0.5, -s * 0.34), Vector2(s * 0.8, -s * 0.5)]), s * 0.05, WOOD_DEEP)
		for x in [-0.28, 0.28]:
			b.disc(Vector2(s * x, -s * 0.12), s * 0.15, INK)
			b.disc(Vector2(s * x, -s * 0.12), s * 0.09, WOOD_HI))

## The meadow under the lots, `size` pixels from the origin: grass shaded
## top to bottom, soft patches, daisies, and the barn `barn_h` tall with
## its roof's top at `y0`.
static func fields_ground(size: Vector2, y0: float, barn_h: float) -> ArrayMesh:
	return _made("fground%.0f/%.0f/%.0f" % [size.x, size.y, y0], func(b: Face.Builder) -> void:
		Soft.quad(b, [Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)], [GRASS_HI, GRASS, GRASS_DEEP, GRASS_DEEP])
		for k in 26:
			var p := Vector2(fmod(k * 397.0, size.x), fmod(k * 613.0 + 80.0, size.y))
			Soft.soft(b, p, 90.0 + (k % 5) * 30.0, 50.0 + (k % 3) * 20.0, Color(GRASS_HI if k % 2 == 0 else GRASS_DEEP, 0.32))
		Soft.soft(b, Vector2(size.x * 0.2, size.y * 0.2), size.x * 0.5, size.y * 0.3, Color(1.0, 0.98, 0.8, 0.16))
		for k in 14:
			var p := Vector2(fmod(k * 271.0 + 40.0, size.x), y0 + barn_h + 30.0 + fmod(k * 487.0, size.y - y0 - barn_h - 60.0))
			for i in 5:
				b.disc(p + Vector2.from_angle(TAU * i / 5.0) * 5.0, 4.0, CREAM)
			b.disc(p, 3.5, COIN)
		# the barn across the top
		var foot := y0 + barn_h
		_shadow(b, Vector2(size.x * 0.5, foot), size.x * 0.3, 24.0, 0.25)
		_rr(b, Vector2(size.x * 0.28, y0 + barn_h * 0.36), Vector2(size.x * 0.44, barn_h * 0.64), 14.0, BARN_DEEP)
		_rr(b, Vector2(size.x * 0.28 + 6.0, y0 + barn_h * 0.36), Vector2(size.x * 0.44 - 12.0, barn_h * 0.58), 12.0, BARN)
		b.polygon(PackedVector2Array([Vector2(size.x * 0.24, y0 + barn_h * 0.42), Vector2(size.x * 0.5, y0 + barn_h * 0.02), Vector2(size.x * 0.76, y0 + barn_h * 0.42)]), ROOF)
		b.polygon(PackedVector2Array([Vector2(size.x * 0.29, y0 + barn_h * 0.42), Vector2(size.x * 0.5, y0 + barn_h * 0.1), Vector2(size.x * 0.71, y0 + barn_h * 0.42)]), ROOF.lightened(0.1))
		_rr(b, Vector2(size.x * 0.43, y0 + barn_h * 0.52), Vector2(size.x * 0.14, barn_h * 0.48), 10.0, Color("6a3a2c"))
		b.stroke(PackedVector2Array([Vector2(size.x * 0.43, y0 + barn_h * 0.52), Vector2(size.x * 0.57, foot)]), 5.0, WALL)
		b.stroke(PackedVector2Array([Vector2(size.x * 0.57, y0 + barn_h * 0.52), Vector2(size.x * 0.43, foot)]), 5.0, WALL))

# --- the yard ---

## The yard, `size` pixels from the origin: the barn's wall and roof at the
## top to `wall_h`, straw underfoot.
static func yard_ground(size: Vector2, wall_h: float) -> ArrayMesh:
	return _made("yground%.0f/%.0f" % [size.x, size.y], func(b: Face.Builder) -> void:
		Soft.quad(b, [Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)], [STRAW, STRAW, STRAW_DEEP, STRAW_DEEP])
		for k in 60:
			var p := Vector2(fmod(k * 397.0, size.x), wall_h + fmod(k * 613.0, size.y - wall_h))
			var d := Vector2.from_angle(k * 1.7) * 26.0
			b.stroke(PackedVector2Array([p, p + d]), 3.0, Color(Color("f6e2a6") if k % 2 == 0 else Color("c8a558"), 0.7))
		Soft.soft(b, Vector2(size.x * 0.3, wall_h + size.y * 0.2), size.x * 0.5, size.y * 0.3, Color(1.0, 0.98, 0.8, 0.2))
		# the wall: red boards, a beam, a window of light
		Soft.quad(b, [Vector2.ZERO, Vector2(size.x, 0), Vector2(size.x, wall_h), Vector2(0, wall_h)], [BARN_DEEP, BARN_DEEP, BARN, BARN])
		var n := int(size.x / 70.0)
		for k in n + 1:
			b.stroke(PackedVector2Array([Vector2(size.x * k / n, 0), Vector2(size.x * k / n, wall_h)]), 3.0, Color(BARN_DEEP, 0.7))
		_rr(b, Vector2(0, wall_h - 16.0), Vector2(size.x, 22.0), 6.0, WOOD_DEEP)
		_rr(b, Vector2(0, wall_h - 16.0), Vector2(size.x, 12.0), 6.0, WOOD)
		_shadow(b, Vector2(size.x * 0.5, wall_h + 14.0), size.x * 0.6, 24.0, 0.22))

## A stall's straw bed and rails, `size` pixels, its middle at the origin.
## `kept` false is the aisle a cow too many stands in: no bed, no rails.
static func stall(size: Vector2, kept: bool) -> ArrayMesh:
	return _made("stall%.0f/%.0f/%s" % [size.x, size.y, kept], func(b: Face.Builder) -> void:
		var at := -size * 0.5
		if not kept:
			Soft.soft(b, Vector2(0, size.y * 0.2), size.x * 0.44, size.y * 0.24, Color(STRAW_DEEP, 0.5))
			return
		_rr(b, at + Vector2(8, size.y * 0.34), Vector2(size.x - 16.0, size.y * 0.6), 26.0, Color("d9b866"))
		_rr(b, at + Vector2(14, size.y * 0.36), Vector2(size.x - 28.0, size.y * 0.5), 22.0, Color("f3dc98"))
		for x in [at.x + 6.0, at.x + size.x - 6.0]:
			_rr(b, Vector2(x - 6.0, at.y + size.y * 0.1), Vector2(12.0, size.y * 0.82), 5.0, WOOD_DEEP)
		_rr(b, Vector2(at.x + 6.0, at.y + size.y * 0.16), Vector2(size.x - 12.0, 10.0), 5.0, WOOD)
		_rr(b, Vector2(at.x + 6.0, at.y + size.y * 0.3), Vector2(size.x - 12.0, 10.0), 5.0, WOOD))

## The trough, `w` wide, its middle at the origin; the feed in it is drawn
## by the place.
static func trough(w: float) -> ArrayMesh:
	return _made("trough%.0f" % w, func(b: Face.Builder) -> void:
		var h := w * 0.26
		_shadow(b, Vector2(0, h * 0.6), w * 0.56, h * 0.34)
		_rr(b, Vector2(-w * 0.5, -h * 0.5), Vector2(w, h), h * 0.3, WOOD_DEEP)
		_rr(b, Vector2(-w * 0.5 + 8.0, -h * 0.5 + 6.0), Vector2(w - 16.0, h - 20.0), h * 0.2, Color("6a4a30")))

## A cow's blanket, laid over her back: `s` is her size.
static func blanket(s: float) -> ArrayMesh:
	return _made("blanket%.1f" % s, func(b: Face.Builder) -> void:
		_rr(b, Vector2(-s * 0.34, -s * 0.62), Vector2(s * 0.56, s * 0.34), s * 0.12, BLANKET.darkened(0.14))
		_rr(b, Vector2(-s * 0.32, -s * 0.62), Vector2(s * 0.52, s * 0.28), s * 0.1, BLANKET)
		for x in [-0.2, -0.06, 0.08]:
			b.stroke(PackedVector2Array([Vector2(s * x, -s * 0.6), Vector2(s * x, -s * 0.36)]), s * 0.03, Color(CREAM, 0.7)))

# --- the counter ---

## The stand, `size` pixels from the origin: the back wall with its shelf
## to `back`, the awning's teal and cream stripes over it, the pass at
## `pass_y`, the counter's front at `front`, and the square before it.
static func counter_ground(size: Vector2, back: float, pass_y: float, front: float) -> ArrayMesh:
	return _made("cground%.0f/%.0f" % [size.x, size.y], func(b: Face.Builder) -> void:
		# the square
		Soft.quad(b, [Vector2(0, front), Vector2(size.x, front), size, Vector2(0, size.y)], [FLOOR, FLOOR, FLOOR_DEEP, FLOOR_DEEP])
		var rows := int((size.y - front) / 90.0) + 1
		for r in rows:
			var y := front + 90.0 * r
			b.stroke(PackedVector2Array([Vector2(0, y), Vector2(size.x, y)]), 3.0, Color(FLOOR_DEEP, 0.6))
			for c in 8:
				var x := size.x * (c + (0.5 if r % 2 == 0 else 0.0)) / 7.0
				b.stroke(PackedVector2Array([Vector2(x, y), Vector2(x, y + 90.0)]), 3.0, Color(FLOOR_DEEP, 0.5))
		Soft.soft(b, Vector2(size.x * 0.5, front + (size.y - front) * 0.4), size.x * 0.6, (size.y - front) * 0.5, Color(1.0, 0.98, 0.85, 0.22))
		# inside the stand
		Soft.quad(b, [Vector2.ZERO, Vector2(size.x, 0), Vector2(size.x, front), Vector2(0, front)], [WALL_SHADE, WALL_SHADE, WALL, WALL])
		_rr(b, Vector2(20, back - 20.0), Vector2(size.x - 40.0, 34.0), 10.0, IRON)
		_rr(b, Vector2(20, back - 20.0), Vector2(size.x - 40.0, 18.0), 10.0, IRON_HI)
		# the pass: a wooden shelf
		_rr(b, Vector2(40, pass_y - 14.0), Vector2(size.x - 80.0, 44.0), 12.0, WOOD_DEEP)
		_rr(b, Vector2(40, pass_y - 14.0), Vector2(size.x - 80.0, 30.0), 12.0, WOOD_HI)
		# the counter's front
		_shadow(b, Vector2(size.x * 0.5, front + 10.0), size.x * 0.6, 30.0, 0.26)
		_rr(b, Vector2(0, front - 96.0), Vector2(size.x, 96.0), 14.0, TEAL_DEEP)
		_rr(b, Vector2(0, front - 96.0), Vector2(size.x, 34.0), 14.0, WOOD_HI)
		_rr(b, Vector2(0, front - 70.0), Vector2(size.x, 12.0), 4.0, WOOD_DEEP)
		for k in int(size.x / 110.0) + 1:
			_rr(b, Vector2(20.0 + 110.0 * k, front - 48.0), Vector2(70.0, 34.0), 10.0, TEAL)
		# the awning
		var n := int(size.x / 96.0) + 1
		var w := size.x / n
		for k in n:
			var col := TEAL if k % 2 == 0 else CREAM
			_rr(b, Vector2(w * k, -30.0), Vector2(w + 1.0, 104.0), 0.0, col)
			b.fan(Face.Builder.arc_points(Vector2(w * (k + 0.5), 74.0), w * 0.5, 0.0, PI), col)
		Soft.quad(b, [Vector2(0, 74.0), Vector2(size.x, 74.0), Vector2(size.x, 150.0), Vector2(0, 150.0)], [Color(INK, 0.16), Color(INK, 0.16), Color(INK, 0.0), Color(INK, 0.0)]))

## A grill's plate, `w` wide, its middle at the origin. `lit` false is a
## place a grill could stand.
static func grill(w: float, lit: bool) -> ArrayMesh:
	return _made("grill%.0f/%s" % [w, lit], func(b: Face.Builder) -> void:
		var h := w * 0.62
		if not lit:
			_rr(b, Vector2(-w * 0.5, -h * 0.5), Vector2(w, h), 16.0, Color(INK, 0.08))
			return
		_rr(b, Vector2(-w * 0.5, -h * 0.5 + 8.0), Vector2(w, h), 16.0, Color(INK, 0.3))
		_rr(b, Vector2(-w * 0.5, -h * 0.5), Vector2(w, h), 16.0, Color("3c3f46"))
		_rr(b, Vector2(-w * 0.44, -h * 0.4), Vector2(w * 0.88, h * 0.76), 12.0, IRON)
		for k in 5:
			var x := -w * 0.36 + w * 0.18 * k
			b.stroke(PackedVector2Array([Vector2(x, -h * 0.32), Vector2(x, h * 0.28)]), 4.0, Color("3c3f46")))

## A till, `w` wide, its foot at the origin.
static func till(w: float, lit: bool) -> ArrayMesh:
	return _made("till%.0f/%s" % [w, lit], func(b: Face.Builder) -> void:
		if not lit:
			_rr(b, Vector2(-w * 0.5, -w * 0.5), Vector2(w, w * 0.5), 12.0, Color(INK, 0.08))
			return
		_rr(b, Vector2(-w * 0.5, -w * 0.36), Vector2(w, w * 0.36), 10.0, WOOD_DEEP)
		_rr(b, Vector2(-w * 0.44, -w * 0.72), Vector2(w * 0.88, w * 0.44), 10.0, Color("b7694a"))
		_rr(b, Vector2(-w * 0.36, -w * 0.66), Vector2(w * 0.72, w * 0.2), 6.0, CREAM)
		for k in 3:
			b.disc(Vector2(-w * 0.22 + w * 0.22 * k, -w * 0.36), w * 0.06, CREAM)
		_rr(b, Vector2(-w * 0.4, -w * 0.2), Vector2(w * 0.8, w * 0.1), 5.0, Color("7a5234")))

# --- the office ---

## The office, `size` pixels from the origin: papered wall to `floor_y`, a
## skirting, boards underfoot.
static func office_ground(size: Vector2, floor_y: float) -> ArrayMesh:
	return _made("oground%.0f/%.0f" % [size.x, size.y], func(b: Face.Builder) -> void:
		Soft.quad(b, [Vector2.ZERO, Vector2(size.x, 0), Vector2(size.x, floor_y), Vector2(0, floor_y)], [Color("efe3cf"), Color("efe3cf"), Color("f7efdf"), Color("f7efdf")])
		var n := int(size.x / 120.0) + 1
		for k in n:
			for r in int(floor_y / 120.0) + 1:
				var p := Vector2(60.0 + 120.0 * k + (60.0 if r % 2 == 1 else 0.0), 60.0 + 120.0 * r)
				if p.y < floor_y - 20.0:
					_trefoil(b, p, 12.0, Color(TEAL_HI, 0.3))
		Soft.soft(b, Vector2(size.x * 0.3, floor_y * 0.3), size.x * 0.5, floor_y * 0.4, Color(1.0, 0.98, 0.85, 0.25))
		Soft.quad(b, [Vector2(0, floor_y), Vector2(size.x, floor_y), size, Vector2(0, size.y)], [WOOD, WOOD, WOOD_DEEP, WOOD_DEEP])
		for k in int((size.y - floor_y) / 46.0) + 1:
			b.stroke(PackedVector2Array([Vector2(0, floor_y + 46.0 * k), Vector2(size.x, floor_y + 46.0 * k)]), 3.0, Color(WOOD_DEEP, 0.6))
		_rr(b, Vector2(0, floor_y - 18.0), Vector2(size.x, 26.0), 6.0, WOOD_DEEP)
		_rr(b, Vector2(0, floor_y - 18.0), Vector2(size.x, 14.0), 6.0, WOOD_HI))

## A sheet of paper pinned to the wall, `size` pixels, its top left at the
## origin.
static func sheet(size: Vector2) -> ArrayMesh:
	return _made("sheet%.0f/%.0f" % [size.x, size.y], func(b: Face.Builder) -> void:
		_rr(b, Vector2(0, 8.0), size, 30.0, Color(INK, 0.16))
		_rr(b, Vector2.ZERO, size, 30.0, PAPER))

## A jar, `s` wide and 1.3 times as tall, its middle at the origin; what is
## in it is drawn by the place.
static func jar(s: float) -> ArrayMesh:
	return _made("jar%.1f" % s, func(b: Face.Builder) -> void:
		var h := s * 1.3
		_shadow(b, Vector2(0, h * 0.5), s * 0.56, s * 0.14)
		_rr(b, Vector2(-s * 0.5, -h * 0.5), Vector2(s, h), s * 0.24, Color("cfe3e0"))
		_rr(b, Vector2(-s * 0.44, -h * 0.5 + s * 0.06), Vector2(s * 0.88, h - s * 0.12), s * 0.2, Color("eef7f5")))

## The jar's glass over what is in it: a shine, the rim and the lid.
static func jar_glass(s: float) -> ArrayMesh:
	return _made("jarglass%.1f" % s, func(b: Face.Builder) -> void:
		var h := s * 1.3
		_rr(b, Vector2(-s * 0.36, -h * 0.4), Vector2(s * 0.1, h * 0.6), s * 0.05, Color(1, 1, 1, 0.5))
		_rr(b, Vector2(-s * 0.44, -h * 0.5 - s * 0.14), Vector2(s * 0.88, s * 0.2), s * 0.07, WOOD_DEEP)
		_rr(b, Vector2(-s * 0.4, -h * 0.5 - s * 0.14), Vector2(s * 0.8, s * 0.12), s * 0.06, WOOD_HI))

## The signboard's notch `k` of four, `s` wide: a board with that many
## flags on it (0: bare).
static func notch(s: float, k: int, on: bool) -> ArrayMesh:
	return _made("notch%.1f/%d/%s" % [s, k, on], func(b: Face.Builder) -> void:
		_rr(b, Vector2(-s * 0.5, -s * 0.4 + 6.0), Vector2(s, s * 0.8), s * 0.16, Color(INK, 0.18))
		_rr(b, Vector2(-s * 0.5, -s * 0.4), Vector2(s, s * 0.8), s * 0.16, TEAL_DEEP if on else WOOD_DEEP)
		_rr(b, Vector2(-s * 0.44, -s * 0.36), Vector2(s * 0.88, s * 0.66), s * 0.13, TEAL if on else CREAM)
		var ink := CREAM if on else WOOD_DEEP
		toastie_into(b, Vector2(0, s * 0.02), s * (0.26 + 0.07 * k), 1.0)
		for i in k:
			var a := -PI * 0.5 + (i - (k - 1) * 0.5) * 0.7
			var from := Vector2.from_angle(a) * s * 0.26 + Vector2(0, s * 0.02)
			b.stroke(PackedVector2Array([from, from + Vector2.from_angle(a) * s * 0.1]), s * 0.04, ink))

## A place's picture for its button on the tray, `s` wide, its middle at
## the origin: wheat, a cheese, a toastie, a ledger.
static func place_icon(p: String, s: float) -> ArrayMesh:
	return _made("place%s/%.1f" % [p, s], func(b: Face.Builder) -> void: _place_icon(b, p, s))

static func _place_icon(b: Face.Builder, p: String, s: float) -> void:
	if p == "fields":
		_wheat(b, Vector2(0, s * 0.42), s * 0.95, 3)
	elif p == "yard":
		cheese_into(b, Vector2(0, -s * 0.04), s * 0.86)
	elif p == "counter":
		toastie_into(b, Vector2.ZERO, s * 0.8, 1.0)
	else:
		_rr(b, Vector2(-s * 0.32, -s * 0.4), Vector2(s * 0.64, s * 0.8), s * 0.1, CREAM)
		for k in 3:
			b.stroke(PackedVector2Array([Vector2(-s * 0.18, -s * 0.2 + s * 0.2 * k), Vector2(s * 0.18, -s * 0.2 + s * 0.2 * k)]), s * 0.06, Color(INK, 0.5))
