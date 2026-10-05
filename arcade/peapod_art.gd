extends RefCounted

## Peapod's drawings (spec
## docs/superpowers/specs/2026-10-04-arcade-peapod-design.md, section 7): the
## soft look Lucky Thirteen and Posy wear. A crate is a rounded pastel tile
## with a thin lip, one paint a weight of number, its number in ink; a gift
## crate is a cream parcel showing the token it holds; the millipede is a row
## of round paper discs behind a plum head; the cart is pale wood under a
## pea-pod barrel. Each is built once per look and scale, its origin at its
## centre (the cart's at its axle, the barrel's and a flower's at the foot),
## and moved by the draw transform; shared with the Arcade tab's banner and
## the tutorial's pages. A number is lettered over the mesh by the caller
## (`number()`), because a glyph is not a mesh.

const Pal = preload("res://core/palette.gd")
const Face = preload("res://ui/faces/face.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Sim = preload("res://arcade/peapod_sim.gd")

const INK := Color("3b3028")
const PAPER := Color("fffaf0")
const CREAM := Color("fbf3e2")
const CREAM_DEEP := Color("e3cfa6")
const POD := Color("a9d68a")
const POD_DEEP := Color("7fb565")
const POD_HI := Color("d3ecb8")
const POD_MOUTH := Color("5f8a48")
const PEA := Color("b5e08a")
const PEA_DEEP := Color("7fb565")
const WOOD := Color("e3c79f")
const WOOD_DEEP := Color("c9a172")
const WOOD_HI := Color("f3e2c4")
const HUB := Color("f2a48d")
const TYRE := Color("b08a62")
const GOLD := Color("f6cb5e")
const GOLD_DEEP := Color("d9a441")
const GOLD_INK := Color("7a4a10")
const CRACKER := Color("ee8d7e")
const HEAD := Color("b89ac9")
const HEAD_DEEP := Color("8f71a3")
## The millipede's legs and feelers, and the pupils the screen lays.
const FEELER := Color("5e4a6b")
## A crate's paint by the weight of its number, every one pulled toward
## paper (Lucky Thirteen's pastels): green for the lightest, up through
## teal, sky, periwinkle and mauve to rose, clay and dusk.
const PAINT := [Color("b9d996"), Color("93d4c3"), Color("9fcbe8"), Color("b5b3e4"), Color("dbaed6"), Color("f3a9af"),
	Color("d98d6a"), Color("7c7386")]
## A gift's medallion, by Sim.Kind.
const GIFT := {Sim.Kind.FAN: Color("a98be6"), Sim.Kind.PIERCE: Color("45c4b0"), Sim.Kind.BURST: Color("d665c8"),
	Sim.Kind.ZAP: Color("5a8fe0"), Sim.Kind.FLAME: Color("ee7f5a"), Sim.Kind.FROST: Color("a9dff2"),
	Sim.Kind.SHOVE: Color("5fbf8a")}
## A shop card's medallion, by Sim.Card: the heavier pea, the quicker gun,
## the crit and the energy.
const CARD := [Color("f5a44a"), Color("f08fb0"), Color("7fc8ee"), Color("45558f")]
## An energy orb: its glow and body, and its bright heart.
const ORB := Color("3fc8ff")
const ORB_HI := Color("e6fbff")
const ORB_DEEP := Color("1f8fd0")
const BOLT := Color("ffe37a")
const EMBER := Color("f28c4f")
const IRON := Color("b7c0cc")
const DART := Color("ffe08a")
const BERRY := Color("f2907c")
## The flowers a cleared wave leaves on the grass: petals and eye.
const BLOOM := [[Color("f3a9af"), Color("f6cb5e")], [Color("fffaf0"), Color("f6cb5e")], [Color("b5b3e4"), Color("fbf3e2")],
	[Color("f6cb5e"), Color("d98d6a")], [Color("9fcbe8"), Color("fffaf0")]]
## How round a crate's corners are and how thick its lip, in field units.
const ROUND := 9.0
const LIP := 3.6

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

## What a crate or a plate is known by: its paint, or its gift's.
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

## A piece's lip: its own paint deepened (Lucky Thirteen's `line_colour`).
static func deepen(c: Color) -> Color:
	return c.lerp(Color(c.r * c.r * 0.86, c.g * c.g * 0.80, c.b * c.b * 0.90), 0.6)

## The face a crate or a plate of `kind` shows: a gift's is cream paper, its
## colour on the medallion.
static func _face_colour(kind: int, tier: int) -> Color:
	if kind == Sim.Kind.CRATE:
		return PAINT[clampi(tier, 0, PAINT.size() - 1)]
	if kind == Sim.Kind.GOLD:
		return GOLD
	if kind == Sim.Kind.IRON:
		return IRON
	if kind == Sim.Kind.HEAD:
		return HEAD
	return CREAM

static func _lip_colour(kind: int, tier: int) -> Color:
	if kind == Sim.Kind.GOLD:
		return GOLD_DEEP
	var face := _face_colour(kind, tier)
	return CREAM_DEEP if face == CREAM else deepen(face)

## Paper on a dusky tile; on the rest ink, warmed with the tile's own lip.
static func number_colour(kind: int, hp: int) -> Color:
	if kind == Sim.Kind.GOLD:
		return GOLD_INK
	var face := _face_colour(kind, tier_of(hp))
	return PAPER if face.get_luminance() < 0.56 else INK.lerp(deepen(face), 0.3)

## A number as a crate wears it: 9,999 at most, then thousands.
static func short(v: int) -> String:
	if v >= 1000000:
		return "%dM" % int(v / 1000000.0)
	if v >= 10000:
		return "%dk" % int(v / 1000.0)
	return str(v)

## A crate of `kind` in tier `tier`, a wall's cell big, centred: the lip, the
## face, and by its kind a pale ring and glints (golden), rivets (iron), the
## firecracker or the medallion of the gift inside.
static func crate(kind: int, tier: int, u: float) -> ArrayMesh:
	var key := _key("c", kind, tier, u)
	if _cache.has(key):
		return _cache[key]
	var b := Face.Builder.new()
	var w := (Sim.CELL_W - 3.0) * u
	var h := (Sim.CELL_H - 3.0) * u
	var at := Vector2(-w * 0.5, -h * 0.5)
	var r := ROUND * u
	var lip := LIP * u
	var base := _face_colour(kind, tier)
	b.fan(Face.Builder.round_rect(at + Vector2(0, 2.2 * u), Vector2(w, h), r), Color(0.3, 0.2, 0.08, 0.1))
	b.fan(Face.Builder.round_rect(at, Vector2(w, h), r), _lip_colour(kind, tier))
	b.fan(Face.Builder.round_rect(at, Vector2(w, h - lip), r), base)
	var c := Vector2(0, -lip * 0.5)
	match kind:
		Sim.Kind.CRATE:
			pass
		Sim.Kind.GOLD:
			b.stroke(Face.Builder.round_rect(at + Vector2(4.0, 4.0) * u, Vector2(w - 8.0 * u, h - lip - 8.0 * u), r * 0.62), maxf(1.2, 1.1 * u),
				Color(GOLD.lerp(PAPER, 0.6), 0.9), true)
			for sx in [-1.0, 1.0]:
				_twinkle(b, c + Vector2(sx * w * 0.36, -sx * h * 0.16), 2.8 * u, Color(1, 1, 1, 0.9))
		Sim.Kind.IRON:
			for sx in [-1.0, 1.0]:
				for sy in [-1.0, 1.0]:
					var p := c + Vector2(sx * (w * 0.5 - 6.5 * u), sy * ((h - lip) * 0.5 - 6.0 * u))
					b.disc(p + Vector2(0, 0.6 * u), 1.9 * u, deepen(IRON))
					b.disc(p, 1.7 * u, IRON.lightened(0.5))
		Sim.Kind.BOMB:
			icon(b, kind, c + Vector2(0, 2.0 * u), (h - lip) * 0.7)
		_:
			medal(b, kind, c, (h - lip) * 0.4, false)
	return _keep(key, b.mesh())

## One of the millipede's plates, centred: a round paper disc with its lip,
## little legs out of both sides.
static func plate(kind: int, tier: int, u: float) -> ArrayMesh:
	var key := _key("p", kind, tier, u)
	if _cache.has(key):
		return _cache[key]
	var b := Face.Builder.new()
	var r := Sim.SEG_R * u
	var lip := r * 0.18
	var base := _face_colour(kind, tier)
	for side in [-1.0, 1.0]:
		for k in [-1.0, 1.0]:
			var from := Vector2(k * r * 0.4, side * r * 0.72)
			b.stroke(PackedVector2Array([from, from + Vector2(k * r * 0.16, side * r * 0.46)]), maxf(1.5, 1.8 * u), Color(FEELER, 0.7))
	b.disc(Vector2(0, 2.2 * u), r, Color(0.3, 0.2, 0.08, 0.1))
	b.disc(Vector2(0, lip * 0.5), r - lip * 0.5, _lip_colour(kind, tier))
	var c := Vector2(0, -lip * 0.5)
	b.disc(c, r - lip * 0.5, base)
	match kind:
		Sim.Kind.CRATE:
			pass
		Sim.Kind.GOLD:
			b.stroke(Face.Builder.ring(c, r * 0.7, r * 0.7), maxf(1.2, 1.1 * u), Color(GOLD.lerp(PAPER, 0.6), 0.9), true)
			_twinkle(b, c + Vector2(r * 0.56, -r * 0.5), 2.8 * u, Color(1, 1, 1, 0.9))
		Sim.Kind.IRON:
			for k in 4:
				var p := c + Vector2.from_angle(TAU * (k + 0.5) / 4.0) * r * 0.7
				b.disc(p + Vector2(0, 0.6 * u), 1.7 * u, deepen(IRON))
				b.disc(p, 1.5 * u, IRON.lightened(0.5))
		Sim.Kind.BOMB:
			icon(b, kind, c + Vector2(0, 2.0 * u), r * 1.15)
		_:
			medal(b, kind, c, r * 0.6, false)
	return _keep(key, b.mesh())

## The millipede's head, facing +x, centred, seen from above like its
## plates: a plum disc with two striped bands, feelers and blushing cheeks.
## The eyes are whites only (the screen lays the pupils, which watch the
## cart); `cross` draws a brow down over each.
static func head(u: float, cross := false) -> ArrayMesh:
	var key := _key("h", int(cross), 0, u)
	if _cache.has(key):
		return _cache[key]
	var b := Face.Builder.new()
	var r := Sim.HEAD_R * u
	for side in [-1.0, 1.0]:
		var feeler := Face.Builder.bezier2(Vector2(r * 0.5, side * r * 0.5), Vector2(r * 1.3, side * r * 0.5), Vector2(r * 1.45, side * r * 1.05), 8)
		b.stroke(feeler, maxf(1.5, 1.6 * u), Color(FEELER, 0.8))
		b.disc(feeler[feeler.size() - 1], 2.6 * u, HUB)
	b.disc(Vector2(0, 2.4 * u), r, Color(0.3, 0.2, 0.08, 0.1))
	b.disc(Vector2(0, 1.2 * u), r, HEAD_DEEP)
	b.disc(Vector2(0, -1.0 * u), r * 0.94, HEAD)
	# two pale bands across the back of the head
	for k in 2:
		b.stroke(Face.Builder.arc_points(Vector2(r * 0.9, -1.0 * u), r * (1.45 + 0.3 * k), PI * 0.84, PI * 1.16), 2.2 * u, Color(PAPER, 0.5))
	for side in [-1.0, 1.0]:
		var e := Vector2(r * 0.36, side * r * 0.4 - 1.0 * u)
		b.ellipse(e + Vector2(r * 0.34, side * r * 0.3), r * 0.16, r * 0.12, Color(HUB, 0.55))
		b.disc(e, r * 0.3, PAPER)
		if cross:
			b.stroke(PackedVector2Array([e + Vector2(-r * 0.32, side * r * 0.36), e + Vector2(r * 0.36, side * r * 0.1)]), 2.4 * u, FEELER)
	return _keep(key, b.mesh())

## A gift's picture, `s` tall about `c`, laid into a builder.
static func icon(b: Face.Builder, kind: int, c: Vector2, s: float) -> void:
	match kind:
		Sim.Kind.FAN:
			# three peas flung apart from one mouth
			for k in [-1.0, 0.0, 1.0]:
				var d := Vector2.from_angle(-PI * 0.5 + k * 0.62)
				b.stroke(PackedVector2Array([c + Vector2(0, s * 0.36), c + Vector2(0, s * 0.36) + d * s * 0.42]), s * 0.07, Color(PAPER, 0.8))
				pea(b, c + Vector2(0, s * 0.36) + d * s * 0.58, s * 0.17)
		Sim.Kind.PIERCE:
			# a dart up through two slats
			for k in 2:
				b.fan(Face.Builder.round_rect(c + Vector2(-s * 0.4, -s * 0.2 + s * 0.3 * k), Vector2(s * 0.8, s * 0.11), s * 0.05), Color(INK, 0.3))
			b.stroke(PackedVector2Array([c + Vector2(0, s * 0.44), c + Vector2(0, -s * 0.2)]), s * 0.13, PAPER)
			b.polygon(PackedVector2Array([c + Vector2(-s * 0.24, -s * 0.16), c + Vector2(0, -s * 0.5), c + Vector2(s * 0.24, -s * 0.16)]), PAPER)
		Sim.Kind.BURST:
			# a berry going off: three peas out of it
			for k in 3:
				var d := Vector2.from_angle(-PI * 0.5 + TAU * k / 3.0)
				pea(b, c + d * s * 0.38, s * 0.13)
			b.disc(c, s * 0.24, PAPER)
			b.disc(c, s * 0.18, BERRY)
		Sim.Kind.ZAP:
			_bolt(b, c + Vector2(0, s * 0.04), s * 0.5, Color(INK, 0.25))
			_bolt(b, c, s * 0.5, BOLT)
		Sim.Kind.FLAME:
			_flame(b, c + Vector2(0, s * 0.42), s * 0.86, PAPER, BOLT)
		Sim.Kind.FROST:
			# a snowflake
			for k in 3:
				var d := Vector2.from_angle(PI * 0.5 + PI * k / 3.0)
				b.stroke(PackedVector2Array([c - d * s * 0.42, c + d * s * 0.42]), s * 0.1, PAPER)
				for end in [-1.0, 1.0]:
					b.disc(c + d * s * 0.42 * end, s * 0.07, PAPER)
			b.disc(c, s * 0.11, Color("4f9fc8"))
		Sim.Kind.SHOVE:
			# a fat arrow up off a bar
			b.fan(Face.Builder.round_rect(c + Vector2(-s * 0.36, s * 0.3), Vector2(s * 0.72, s * 0.13), s * 0.06), PAPER)
			b.fan(Face.Builder.round_rect(c + Vector2(-s * 0.1, -s * 0.1), Vector2(s * 0.2, s * 0.32), s * 0.03), PAPER)
			b.polygon(PackedVector2Array([c + Vector2(-s * 0.3, -s * 0.06), c + Vector2(0, -s * 0.46), c + Vector2(s * 0.3, -s * 0.06)]), PAPER)
		Sim.Kind.BOMB:
			# a firecracker: a banded stick with a lit fuse
			var k := s / 60.0
			b.fan(Face.Builder.round_rect(c + Vector2(-9, -15) * k, Vector2(18, 40) * k, 6 * k), deepen(CRACKER))
			b.fan(Face.Builder.round_rect(c + Vector2(-9, -16) * k, Vector2(18, 38) * k, 6 * k), CRACKER)
			b.fan(Face.Builder.round_rect(c + Vector2(-9, -7) * k, Vector2(18, 6) * k, 1 * k), GOLD)
			b.fan(Face.Builder.round_rect(c + Vector2(-9, 7) * k, Vector2(18, 6) * k, 1 * k), GOLD)
			b.stroke(Face.Builder.bezier2(c + Vector2(0, -16) * k, c + Vector2(4, -28) * k, c + Vector2(12, -26) * k, 6), 3 * k, WOOD_DEEP)
			_twinkle(b, c + Vector2(13, -27) * k, 9 * k, Color("f6b866"))

## A jagged bolt `r` tall either way of `c`.
static func _bolt(b: Face.Builder, c: Vector2, r: float, col: Color) -> void:
	b.polygon(PackedVector2Array([c + Vector2(r * 0.2, -r), c + Vector2(-r * 0.5, r * 0.12), c + Vector2(-r * 0.04, r * 0.12),
		c + Vector2(-r * 0.24, r), c + Vector2(r * 0.52, -r * 0.2), c + Vector2(r * 0.06, -r * 0.2)]), col)

## A flame `tall` high, its foot on `foot`: a teardrop leaning a little, a
## paler one inside it.
static func _flame(b: Face.Builder, foot: Vector2, tall: float, col: Color, core: Color) -> void:
	for pass_ in 2:
		var k := 1.0 if pass_ == 0 else 0.55
		var w := tall * 0.36 * k
		var h := tall * k
		var at := foot + Vector2(0, -tall * 0.04 * pass_)
		var pts := PackedVector2Array()
		pts.append_array(Face.Builder.bezier3(at + Vector2(0, -h), at + Vector2(w * 0.3, -h * 0.6), at + Vector2(w * 1.3, -h * 0.4), at + Vector2(w * 0.7, -h * 0.06), 8))
		pts.append_array(Face.Builder.bezier3(at + Vector2(w * 0.7, -h * 0.06), at + Vector2(w * 0.2, h * 0.08), at + Vector2(-w * 0.9, h * 0.06), at + Vector2(-w * 0.9, -h * 0.26), 8))
		pts.append_array(Face.Builder.bezier3(at + Vector2(-w * 0.9, -h * 0.26), at + Vector2(-w * 0.9, -h * 0.6), at + Vector2(-w * 0.3, -h * 0.66), at + Vector2(0, -h), 8))
		b.polygon(pts, col if pass_ == 0 else core)

## A shop card's picture (Sim.Card), `s` tall about `c`.
static func card_icon(b: Face.Builder, card: int, c: Vector2, s: float) -> void:
	match card:
		Sim.Card.DAMAGE:
			# a heavy pea in a burst
			var pts := PackedVector2Array()
			for k in 16:
				pts.append(c + Vector2.from_angle(TAU * k / 16.0) * s * (0.5 if k % 2 == 0 else 0.34))
			b.polygon(pts, Color("fff1a8"))
			pea(b, c, s * 0.3)
		Sim.Card.SPEED:
			# two chevrons, up: the gun quickens
			for k in 2:
				var y := c.y + s * (0.2 - 0.34 * k)
				for pass_ in 2:
					var o := Vector2(0, s * 0.05) if pass_ == 0 else Vector2.ZERO
					b.stroke(PackedVector2Array([Vector2(c.x - s * 0.3, y + s * 0.14) + o, Vector2(c.x, y - s * 0.14) + o, Vector2(c.x + s * 0.3, y + s * 0.14) + o]),
						s * 0.15, Color(INK, 0.25) if pass_ == 0 else PAPER)
		Sim.Card.CRIT:
			# a bull's eye with a glint on it
			b.disc(c + Vector2(0, s * 0.04), s * 0.44, Color(INK, 0.2))
			b.disc(c, s * 0.44, PAPER)
			b.disc(c, s * 0.3, Color("f08a80"))
			b.disc(c, s * 0.15, PAPER)
			_twinkle(b, c + Vector2(s * 0.3, -s * 0.3), s * 0.24, Color("fff1a8"))
		Sim.Card.ENERGY:
			# an energy orb, as a crate drops them, and a glint off it
			b.disc(c, s * 0.46, Color(ORB, 0.3))
			b.disc(c, s * 0.34, ORB_DEEP)
			b.disc(c, s * 0.29, ORB)
			b.disc(c, s * 0.18, ORB_HI)
			b.disc(c + Vector2(-s * 0.1, -s * 0.12), s * 0.08, Color(1, 1, 1, 0.9))
			_twinkle(b, c + Vector2(s * 0.32, -s * 0.32), s * 0.2, Color(1, 1, 1, 0.9))

## A shop card's medallion of radius `r`, ringed in paper.
static func card_medal(b: Face.Builder, card: int, c: Vector2, r: float) -> void:
	var base: Color = CARD[card]
	b.disc(c + Vector2(0, r * 0.12), r, deepen(base))
	b.disc(c, r, PAPER)
	b.disc(c, r * 0.85, base)
	b.stroke(Face.Builder.arc_points(c, r * 0.68, -PI * 0.85, -PI * 0.5), maxf(1.0, r * 0.09), Color(1, 1, 1, 0.5))
	card_icon(b, card, c, r * 1.25)

## The same as a mesh, centred, 12.5 units across at `u`: on the gun's line
## along the grass, and bigger in the shop.
static func card_token(card: int, u: float) -> ArrayMesh:
	var key := _key("ct", card, 0, u)
	if _cache.has(key):
		return _cache[key]
	var b := Face.Builder.new()
	var r := 12.5 * u
	b.disc(Vector2(0, 2.4 * u), r, Color(0.3, 0.2, 0.08, 0.12))
	card_medal(b, card, Vector2.ZERO, r)
	return _keep(key, b.mesh())

## The flame on a crate or a plate alight, its foot on the origin: swayed by
## its draw.
static func fire(u: float) -> ArrayMesh:
	var key := _key("fi", 0, 0, u)
	if _cache.has(key):
		return _cache[key]
	var b := Face.Builder.new()
	_flame(b, Vector2(0, 1.0 * u), 17.0 * u, Color(INK, 0.16), Color(INK, 0.0))
	_flame(b, Vector2.ZERO, 16.0 * u, EMBER, BOLT)
	return _keep(key, b.mesh())

## An energy orb, centred, its glow ORB_R in radius (built that big so its
## discs are round, and scaled down by its draw): a wide soft glow, the orb
## and its bright heart, with a comet's tail back along -x (its draw turns
## it the way it flies and stretches it by how fast).
const ORB_R := 64.0
static func orb() -> ArrayMesh:
	if _cache.has("orb"):
		return _cache["orb"]
	var b := Face.Builder.new()
	var r := ORB_R
	var i0 := b.vertex(Vector2(0, -0.36 * r), Color(ORB, 0.55))
	var i1 := b.vertex(Vector2(0, 0.36 * r), Color(ORB, 0.55))
	var i2 := b.vertex(Vector2(-1.6 * r, 0), Color(ORB, 0.0))
	b.tri(i0, i1, i2)
	b.disc(Vector2.ZERO, r, Color(ORB, 0.14))
	b.disc(Vector2.ZERO, 0.72 * r, Color(ORB, 0.26))
	b.disc(Vector2.ZERO, 0.5 * r, ORB_DEEP)
	b.disc(Vector2.ZERO, 0.43 * r, ORB)
	b.disc(Vector2(-0.07, -0.08) * r, 0.2 * r, ORB_HI)
	b.disc(Vector2(-0.14, -0.16) * r, 0.09 * r, Color.WHITE)
	return _keep("orb", b.mesh())

## A spent pea, centred, with no wake: what tumbles off a crate it landed on.
static func crumb(u: float) -> ArrayMesh:
	var key := _key("cb", 0, 0, u)
	if _cache.has(key):
		return _cache[key]
	var b := Face.Builder.new()
	pea(b, Vector2.ZERO, 2.6 * u)
	return _keep(key, b.mesh())

## A pea of radius `r` laid into a builder.
static func pea(b: Face.Builder, c: Vector2, r: float, a := 1.0) -> void:
	b.disc(c + Vector2(0, r * 0.14), r, Color(PEA_DEEP, a))
	b.disc(c, r * 0.9, Color(PEA, a))
	b.disc(c + Vector2(-r * 0.3, -r * 0.32), r * 0.3, Color(1, 1, 1, 0.65 * a))

static func _twinkle(b: Face.Builder, c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in 8:
		pts.append(c + Vector2.from_angle(-PI * 0.5 + TAU * k / 8.0) * (r if k % 2 == 0 else r * 0.32))
	b.polygon(pts, col)

## A gift's medallion of radius `r` laid into a builder: its colour on a
## disc with a lip, its picture on that; `rim` rings it in paper, for one
## out of its parcel.
static func medal(b: Face.Builder, kind: int, c: Vector2, r: float, rim := true) -> void:
	var base: Color = GIFT.get(kind, GOLD)
	b.disc(c + Vector2(0, r * 0.12), r, deepen(base))
	if rim:
		b.disc(c, r, PAPER)
		b.disc(c, r * 0.85, base)
	else:
		b.disc(c - Vector2(0, r * 0.06), r * 0.95, base)
	b.stroke(Face.Builder.arc_points(c, r * 0.68, -PI * 0.85, -PI * 0.5), maxf(1.0, r * 0.09), Color(1, 1, 1, 0.5))
	icon(b, kind, c, r * 1.25)

## A gift out of its parcel: its medallion ringed in paper, on a pale glow.
static func token(kind: int, u: float) -> ArrayMesh:
	var key := _key("t", kind, 0, u)
	if _cache.has(key):
		return _cache[key]
	var b := Face.Builder.new()
	var r := 12.5 * u
	b.disc(Vector2.ZERO, r * 1.32, Color(PAPER, 0.5))
	b.disc(Vector2(0, 2.4 * u), r, Color(0.3, 0.2, 0.08, 0.12))
	medal(b, kind, Vector2.ZERO, r)
	return _keep(key, b.mesh())

## The cart, its axle's middle on the origin: a pale plank box between where
## the wheels go, with a cradle for the pod. `helper` is the helper's, paler.
static func cart(u: float, helper := false) -> ArrayMesh:
	var key := _key("k", int(helper), 0, u)
	if _cache.has(key):
		return _cache[key]
	var b := Face.Builder.new()
	var wood := WOOD if not helper else Color("efdcb8")
	var deep := WOOD_DEEP if not helper else Color("d2b98c")
	b.ellipse(Vector2(0, 9.5 * u), 24.0 * u, 3.0 * u, Color(0.2, 0.3, 0.1, 0.14))
	b.fan(Face.Builder.round_rect(Vector2(-19, -10) * u, Vector2(38, 14) * u, 5 * u), deep)
	b.fan(Face.Builder.round_rect(Vector2(-19, -10) * u, Vector2(38, 10.8) * u, 5 * u), wood)
	b.fan(Face.Builder.round_rect(Vector2(-15, -8.4) * u, Vector2(30, 2.0) * u, 1.0 * u), Color(WOOD_HI, 0.7))
	for k in 2:
		b.stroke(PackedVector2Array([Vector2(-6.0 + 12.0 * k, -5.5) * u, Vector2(-6.0 + 12.0 * k, -1.0) * u]), maxf(1.0, 0.8 * u), Color(deep, 0.5))
	# the cradle the pod's foot sits in
	b.fan(Face.Builder.round_rect(Vector2(-10, -15) * u, Vector2(20, 7) * u, 3 * u), deep)
	return _keep(key, b.mesh())

## A wheel, centred: a soft tyre, a cream face, six spokes and a coral hub.
static func wheel(u: float) -> ArrayMesh:
	var key := _key("w", 0, 0, u)
	if _cache.has(key):
		return _cache[key]
	var b := Face.Builder.new()
	var r := 9.0 * u
	b.disc(Vector2.ZERO, r, TYRE)
	b.disc(Vector2.ZERO, r * 0.76, CREAM)
	for k in 6:
		var d := Vector2.from_angle(TAU * k / 6.0)
		b.stroke(PackedVector2Array([d * r * 0.2, d * r * 0.7]), maxf(1.2, 1.3 * u), Color(WOOD_DEEP, 0.8))
	b.disc(Vector2(0, r * 0.04), r * 0.36, deepen(HUB))
	b.disc(Vector2.ZERO, r * 0.33, HUB)
	b.disc(Vector2(-r * 0.09, -r * 0.09), r * 0.12, Color(1, 1, 1, 0.6))
	return _keep(key, b.mesh())

## The pea pod that is the barrel, its foot on the origin, mouth up: a fat
## pale pod with a seam, a lit belly, a rolled lip and a tendril.
static func barrel(u: float, helper := false) -> ArrayMesh:
	var key := _key("b", int(helper), 0, u)
	if _cache.has(key):
		return _cache[key]
	var b := Face.Builder.new()
	var pod := POD if not helper else Color("d3da8a")
	var deep := POD_DEEP if not helper else Color("aab45c")
	var tall := 30.0 * u
	var body := PackedVector2Array()
	var left := Face.Builder.bezier3(Vector2(-6, 0) * u, Vector2(-12, -8) * u, Vector2(-10, -22) * u, Vector2(-8, -30) * u, 10)
	var right := Face.Builder.bezier3(Vector2(8, -30) * u, Vector2(10, -22) * u, Vector2(12, -8) * u, Vector2(6, 0) * u, 10)
	body.append_array(left)
	body.append_array(right)
	b.polygon(body, deep)
	var inner := PackedVector2Array()
	for p in body:
		inner.append(Vector2(p.x * 0.84 - 0.8 * u, p.y * 0.97 - 0.4 * u))
	b.polygon(inner, pod)
	b.ellipse(Vector2(-4.0 * u, -tall * 0.5), 2.0 * u, tall * 0.3, Color(POD_HI, 0.8))
	b.stroke(PackedVector2Array([Vector2(3.5 * u, -3.0 * u), Vector2(4.5 * u, -tall * 0.55), Vector2(3.5 * u, -tall + 4.0 * u)]), maxf(1.0, 0.9 * u), Color(deep, 0.6))
	# the lip round the mouth, and the dark of the mouth in it
	b.ellipse(Vector2(0, -tall + 0.6 * u), 10.0 * u, 4.2 * u, deep)
	b.ellipse(Vector2(0, -tall - 0.6 * u), 9.4 * u, 3.4 * u, pod.lightened(0.25))
	b.ellipse(Vector2(0, -tall - 0.4 * u), 6.4 * u, 2.0 * u, POD_MOUTH)
	# a tendril curling off the foot
	b.stroke(Face.Builder.bezier3(Vector2(8, -6) * u, Vector2(15, -8) * u, Vector2(16, -15) * u, Vector2(12, -14) * u, 10), maxf(1.0, 1.1 * u), deep)
	return _keep(key, b.mesh())

## A pea in flight by its look (Sim.Shot), centred, flying up, a pale wake
## fading behind it: a pea, a dart that goes through, a berry that bursts, a
## bolt that jumps on and an ember that sets alight.
## One mesh a look, drawn for every pea in the air by a MultiMesh.
static func shot(look: int, u: float) -> ArrayMesh:
	var key := _key("s", look, 0, u)
	if _cache.has(key):
		return _cache[key]
	var b := Face.Builder.new()
	var r := 3.3 * u
	var wake: Color = ([PEA, DART, BERRY, BOLT, EMBER][clampi(look, 0, 4)] as Color).lerp(PAPER, 0.5)
	var i0 := b.vertex(Vector2(-r * 0.7, 0), Color(wake, 0.5))
	var i1 := b.vertex(Vector2(r * 0.7, 0), Color(wake, 0.5))
	var i2 := b.vertex(Vector2(0, r * 6.5), Color(wake, 0.0))
	b.tri(i0, i1, i2)
	match look:
		Sim.Shot.PIERCE:
			b.polygon(PackedVector2Array([Vector2(-r * 0.9, r * 1.2), Vector2(0, -r * 2.6), Vector2(r * 0.9, r * 1.2)]), deepen(DART))
			b.polygon(PackedVector2Array([Vector2(-r * 0.55, r * 0.9), Vector2(0, -r * 2.2), Vector2(r * 0.55, r * 0.9)]), DART)
			b.disc(Vector2(0, -r * 0.2), r * 0.3, Color(1, 1, 1, 0.8))
		Sim.Shot.BURST:
			var pts := PackedVector2Array()
			for k in 12:
				pts.append(Vector2.from_angle(TAU * k / 12.0) * r * (1.35 if k % 2 == 0 else 0.95))
			b.polygon(pts, deepen(BERRY))
			b.disc(Vector2.ZERO, r * 0.9, BERRY)
			b.disc(Vector2(-r * 0.3, -r * 0.32), r * 0.3, Color(1, 1, 1, 0.6))
		Sim.Shot.ZAP:
			_bolt(b, Vector2.ZERO, r * 2.1, deepen(BOLT))
			_bolt(b, Vector2(0, -r * 0.2), r * 1.7, BOLT)
		Sim.Shot.FLAME:
			_flame(b, Vector2(0, r * 1.5), r * 3.6, EMBER, BOLT)
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

## A crate's shape (`round` false) or a plate's, in white: tinted by its
## draw for the blink a pea leaves and for the last of a crate gone.
static func blank(round: bool, u: float) -> ArrayMesh:
	var key := _key("f", int(round), 0, u)
	if _cache.has(key):
		return _cache[key]
	var b := Face.Builder.new()
	if round:
		b.disc(Vector2.ZERO, Sim.SEG_R * u, Color.WHITE)
	else:
		var w := (Sim.CELL_W - 3.0) * u
		var h := (Sim.CELL_H - 3.0) * u
		b.fan(Face.Builder.round_rect(Vector2(-w * 0.5, -h * 0.5), Vector2(w, h), ROUND * u), Color.WHITE)
	return _keep(key, b.mesh())

## A flower a cleared wave leaves on the grass, its foot on the origin: a
## stem with a leaf, five petals round an eye. `look` picks BLOOM's colours.
static func flower(look: int, u: float) -> ArrayMesh:
	var key := _key("fl", look, 0, u)
	if _cache.has(key):
		return _cache[key]
	var b := Face.Builder.new()
	var cols: Array = BLOOM[look % BLOOM.size()]
	var top := Vector2(0, -16.0 * u)
	b.stroke(Face.Builder.bezier2(Vector2.ZERO, Vector2(2.4 * u, -7.0 * u), top, 8), maxf(1.4, 1.5 * u), POD_DEEP)
	var leaf := PackedVector2Array()
	for i in 10:
		var a := TAU * i / 10.0
		leaf.append(Vector2(3.6 * u, -5.4 * u) + Vector2(cos(a) * 3.6 * u, sin(a) * 1.7 * u).rotated(-0.5))
	b.fan(leaf, POD)
	for k in 5:
		var d := Vector2.from_angle(-PI * 0.5 + TAU * k / 5.0)
		b.disc(top + d * 3.5 * u + Vector2(0, 0.6 * u), 3.1 * u, deepen(cols[0]))
		b.disc(top + d * 3.5 * u, 3.0 * u, cols[0])
	b.disc(top, 2.5 * u, cols[1])
	return _keep(key, b.mesh())

## A little gold crown, its base's middle on the origin: what the pod wears
## once the best is passed.
static func crown(u: float) -> ArrayMesh:
	var key := _key("cr", 0, 0, u)
	if _cache.has(key):
		return _cache[key]
	var b := Face.Builder.new()
	var w := 7.0 * u
	var pts := PackedVector2Array([Vector2(-w, 0), Vector2(-w * 1.1, -7.0 * u), Vector2(-w * 0.5, -3.6 * u), Vector2(0, -8.6 * u),
		Vector2(w * 0.5, -3.6 * u), Vector2(w * 1.1, -7.0 * u), Vector2(w, 0)])
	var drop := PackedVector2Array()
	for p in pts:
		drop.append(p + Vector2(0, 1.0 * u))
	b.polygon(drop, GOLD_DEEP)
	b.polygon(pts, GOLD)
	b.fan(Face.Builder.round_rect(Vector2(-w, -2.2 * u), Vector2(w * 2.0, 2.2 * u), 0.8 * u), GOLD.lerp(PAPER, 0.45))
	for p: Vector2 in [Vector2(-w * 1.1, -7.0 * u), Vector2(0, -8.6 * u), Vector2(w * 1.1, -7.0 * u)]:
		b.disc(p, 1.3 * u, HUB if p.x == 0.0 else PAPER)
	return _keep(key, b.mesh())

## A cloud `w` wide, centred, in paper white: tinted and moved by its draw.
static func cloud(w: float) -> ArrayMesh:
	var key := _key("cl", 0, 0, w)
	if _cache.has(key):
		return _cache[key]
	var b := Face.Builder.new()
	for k in 3:
		b.ellipse(Vector2((k - 1) * w * 0.3, (k % 2) * w * 0.05), w * 0.26, w * 0.13, Color.WHITE)
	b.ellipse(Vector2(-w * 0.04, -w * 0.09), w * 0.22, w * 0.14, Color.WHITE)
	return _keep(key, b.mesh())

## The number on a crate or a plate of `kind`, lettered in ink (paper on a
## dusky one) with no line round it, centred on `c`; `s` is the height of
## what it sits on.
static func number(ci: CanvasItem, font: Font, c: Vector2, v: int, s: float, alpha := 1.0, kind := Sim.Kind.CRATE) -> void:
	var text := short(v)
	var fs := maxi(8, int(s * [0.62, 0.62, 0.58, 0.48, 0.4, 0.34][mini(text.length(), 5)]))
	var size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var at := c + Vector2(-size.x * 0.5, (font.get_ascent(fs) - font.get_descent(fs)) * 0.5)
	ci.draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(number_colour(kind, v), alpha))

static func font() -> Font:
	return CozyTheme.display(700)
