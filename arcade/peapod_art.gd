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
const Motes = preload("res://ui/motes.gd")
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
	Sim.Kind.ZAP: Color("5a8fe0"), Sim.Kind.FLAME: Color("ee7f5a"), Sim.Kind.NETTLE: Color("8a63b8"),
	Sim.Kind.HAIL: Color("dbe7f3"), Sim.Kind.GUST: Color("8fb7c9"), Sim.Kind.FROST: Color("a9dff2"),
	Sim.Kind.SHOVE: Color("5fbf8a")}
## A shop card's medallion, by Sim.Card: the heavier pea, the quicker gun,
## the crit and the energy.
const CARD := [Color("f5a44a"), Color("f08fb0"), Color("7fc8ee"), Color("45558f"), Color("a98be0")]
## A cart's own colour, by Sim.Cart: its tile where the carts are chosen and
## the medallion of the card only it sells.
const CART := [Color("8fc56f"), Color("b0794a"), Color("f09a3e"), Color("58a9d6"), Color("e9c85a"), Color("7fb565"), Color("dd6f55")]
## Energy: a mote of light, its pale heart and the deeper blue its glow
## thins out through, so it reads on a pale sky.
const ORB := Motes.ORB
const ORB_HI := Motes.ORB_HI
const ORB_DEEP := Motes.ORB_DEEP
## The pod as the barrel of an element, by Sim.Kind: its skin, its shade,
## its light and the dark of its mouth.
const POD_OF := {Sim.Kind.ZAP: [Color("f3df78"), Color("cfa93a"), Color("fff6c8"), Color("8a6a1c")],
	Sim.Kind.FLAME: [Color("f39176"), Color("cf5a44"), Color("ffd0bb"), Color("7c2e20")],
	Sim.Kind.NETTLE: [Color("b996e0"), Color("8a63b8"), Color("e6d6f7"), Color("4f3472")],
	Sim.Kind.HAIL: [Color("c9e6f6"), Color("8fbcd9"), Color("f4fbff"), Color("4f7896")],
	Sim.Kind.GUST: [Color("e4eeea"), Color("a9c4c0"), Color("ffffff"), Color("5f7f80")]}
const BOLT := Color("ffe37a")
const EMBER := Color("f28c4f")
## A pea of the flame, of the nettle, of the hail and of the gust.
const FIRE := Color("ef5b4a")
const STING := Color("a97bd8")
const ICE := Color("a8dcf5")
const WIND := Color("eef5f1")
## A shot's colour by its element (Sim.Kind).
const SHOT_OF := {Sim.Kind.ZAP: BOLT, Sim.Kind.FLAME: FIRE, Sim.Kind.NETTLE: STING, Sim.Kind.HAIL: ICE, Sim.Kind.GUST: WIND}
## The other carts' shots: a conker, a pumpkin, a drop of water and a seed.
const CONKER := Color("a8683c")
const PUMPKIN := Color("f09a3e")
const WATER := Color("6fb8ea")
const FLUFF := Color("fffdf6")
const IRON := Color("b7c0cc")
const MAPLE := Color("e2714f")
## The crates that look after others, by Sim.Kind: the PLUS's green, the
## TIMES's violet, the mender's rose and the lock's brass. Their signs and
## the badges on what they look after are these, never a shade of a paint.
const KEEP := {Sim.Kind.PLUS: Color("5fa85a"), Sim.Kind.TIMES: Color("8a63b8"), Sim.Kind.MEND: Color("e77f93"),
	Sim.Kind.WARD: Color("d9a441")}
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
	return Sim.tier_of(hp)

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
	if KEEP.has(kind):
		return KEEP[kind]
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
	if kind == Sim.Kind.WARD:
		# the lock wears the paint it keeps
		return PAINT[clampi(tier, 0, PAINT.size() - 1)]
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
		Sim.Kind.PLUS, Sim.Kind.TIMES:
			# its sign is lettered by the screen, inside this band
			b.stroke(Face.Builder.round_rect(at + Vector2(3.6, 3.6) * u, Vector2(w - 7.2 * u, h - lip - 7.2 * u), r * 0.66), maxf(1.6, 1.9 * u),
				KEEP[kind], true)
		Sim.Kind.MEND:
			_heart(b, c, (h - lip) * 0.36)
		Sim.Kind.WARD:
			_padlock(b, c + Vector2(0, 1.0 * u), (h - lip) * 0.38)
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
		Sim.Kind.PLUS, Sim.Kind.TIMES:
			b.stroke(Face.Builder.ring(c, r * 0.74, r * 0.74), maxf(1.6, 1.9 * u), KEEP[kind], true)
		Sim.Kind.MEND:
			_heart(b, c, r * 0.6)
		Sim.Kind.WARD:
			_padlock(b, c, r * 0.6)
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
		Sim.Kind.NETTLE:
			# a saw-edged leaf on its stalk, a sting at its tip
			var leaf := PackedVector2Array()
			for k in 9:
				var f := k / 8.0
				leaf.append(c + Vector2(-s * (0.3 if k % 2 == 1 else 0.2) * sin(f * PI), s * (0.4 - 0.84 * f)))
			for k in 9:
				var f := 1.0 - k / 8.0
				leaf.append(c + Vector2(s * (0.3 if k % 2 == 1 else 0.2) * sin(f * PI), s * (0.4 - 0.84 * f)))
			b.polygon(leaf, PAPER)
			b.stroke(PackedVector2Array([c + Vector2(0, s * 0.48), c + Vector2(0, -s * 0.3)]), s * 0.06, Color("8a63b8"))
		Sim.Kind.HAIL:
			# three hailstones coming down, a streak over each
			for st: Array in [[Vector2(-0.24, 0.16), 0.17], [Vector2(0.2, 0.26), 0.13], [Vector2(0.1, -0.2), 0.15]]:
				var at: Vector2 = c + st[0] * s
				var r: float = float(st[1]) * s
				b.stroke(PackedVector2Array([at + Vector2(r * 0.9, -r * 2.4), at + Vector2(r * 0.3, -r * 0.8)]), s * 0.05, Color("7fa8c9", 0.7))
				b.disc(at + Vector2(0, r * 0.14), r, Color("7fa8c9"))
				b.disc(at, r * 0.92, PAPER)
				b.disc(at + Vector2(-r * 0.3, -r * 0.3), r * 0.3, Color("cfe6f5"))
		Sim.Kind.GUST:
			# two curls of wind
			for k in 2:
				var y := c.y + s * (-0.14 + 0.3 * k)
				var w := s * (0.34 - 0.08 * k)
				var line := PackedVector2Array([Vector2(c.x - s * 0.42, y)])
				line.append_array(Face.Builder.arc_points(Vector2(c.x + w - s * 0.1, y - s * 0.13), s * 0.13, PI * 0.5, -PI * 0.9))
				b.stroke(line, s * 0.1, PAPER)
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
		Sim.Card.SHOTS:
			# three peas side by side, leaving together
			for k in [-1.0, 1.0, 0.0]:
				pea(b, c + Vector2(s * 0.3 * k, s * (0.1 if k != 0.0 else -0.08)), s * (0.17 if k != 0.0 else 0.2))
		Sim.Card.ENERGY:
			# motes of light, as a crate lets them go: one near, two further off
			for m: Array in [[Vector2(0.27, -0.27), 0.26], [Vector2(-0.3, 0.27), 0.2], [Vector2(-0.03, -0.02), 0.56]]:
				var at: Vector2 = c + m[0] * s
				glow(b, at, s * float(m[1]), Color(ORB, 1.0), 1.1)
				glow(b, at, s * float(m[1]) * 0.7, Color(ORB_HI, 1.0), 1.0)
				glow(b, at, s * float(m[1]) * 0.42, Color.WHITE, 0.7)

## The picture of the card only cart `cart` (Sim.Cart) sells, `s` tall
## about `c`: a conker hopping on, a blast's rings, a drop under pressure, a
## fan of seeds, a cart and the one behind it. The pea gun's is `card_icon`'s.
static func own_icon(b: Face.Builder, cart: int, c: Vector2, s: float) -> void:
	match cart:
		Sim.Cart.CONKER:
			b.stroke(Face.Builder.bezier2(c + Vector2(-s * 0.34, s * 0.2), c + Vector2(-s * 0.02, -s * 0.62), c + Vector2(s * 0.3, s * 0.08), 10), s * 0.07, Color(PAPER, 0.85))
			_conker(b, c + Vector2(-s * 0.34, s * 0.2), s * 0.15)
			_conker(b, c + Vector2(s * 0.3, s * 0.1), s * 0.2)
		Sim.Cart.PUMPKIN:
			for k in 2:
				b.stroke(Face.Builder.ring(c, s * (0.48 - 0.16 * k), s * (0.48 - 0.16 * k)), s * 0.06, Color(PAPER, 0.55 + 0.3 * k), true)
			_pumpkin(b, c, s * 0.2)
		Sim.Cart.HOSE:
			_drop(b, c + Vector2(0, s * 0.12), s * 0.24, WATER)
			for k in 2:
				var y := c.y - s * (0.2 + 0.2 * k)
				b.stroke(PackedVector2Array([Vector2(c.x - s * 0.2, y + s * 0.1), Vector2(c.x, y - s * 0.06), Vector2(c.x + s * 0.2, y + s * 0.1)]), s * 0.09, PAPER)
		Sim.Cart.DANDELION:
			for k in 5:
				var d := Vector2.from_angle(-PI * 0.5 + (k - 2) * 0.42)
				_seed(b, c + Vector2(0, s * 0.4) + d * s * 0.74, s * 0.13, d.angle() + PI * 0.5)
		Sim.Cart.MAPLE:
			# a seed, and the way it goes: up one side and down the other
			for side: float in [-1.0, 1.0]:
				var x := c.x + side * s * 0.34
				b.stroke(PackedVector2Array([Vector2(x, c.y + s * 0.34), Vector2(x, c.y - s * 0.34)]), s * 0.08, Color(PAPER, 0.85))
				var tip := Vector2(x, c.y - side * s * 0.4)
				b.polygon(PackedVector2Array([tip + Vector2(-s * 0.13, side * s * 0.14), tip, tip + Vector2(s * 0.13, side * s * 0.14)]), PAPER)
			_samara(b, c, s * 0.12, PAPER)
		Sim.Cart.TRAIN:
			for k in 2:
				var at := c + Vector2(s * (0.2 - 0.42 * k), s * (0.06 + 0.06 * k))
				var w := s * (0.4 - 0.1 * k)
				b.fan(Face.Builder.round_rect(at - Vector2(w * 0.5, w * 0.28), Vector2(w, w * 0.5), w * 0.14), PAPER if k == 0 else Color(PAPER, 0.7))
				for side: float in [-1.0, 1.0]:
					b.disc(at + Vector2(side * w * 0.3, w * 0.3), w * 0.17, INK)
		_:
			card_icon(b, Sim.Card.SHOTS, c, s)

## A shop card's medallion of radius `r`, ringed in paper. `cart` is whose
## shop it is: the cart's own card (Sim.Card.SHOTS) wears the cart's colour
## and picture.
static func card_medal(b: Face.Builder, card: int, c: Vector2, r: float, cart := 0) -> void:
	var own := card == Sim.Card.SHOTS and cart != Sim.Cart.PEA
	var base: Color = CART[cart] if own else CARD[card]
	b.disc(c + Vector2(0, r * 0.12), r, deepen(base))
	b.disc(c, r, PAPER)
	b.disc(c, r * 0.85, base)
	b.stroke(Face.Builder.arc_points(c, r * 0.68, -PI * 0.85, -PI * 0.5), maxf(1.0, r * 0.09), Color(1, 1, 1, 0.5))
	if own:
		own_icon(b, cart, c, r * 1.25)
	else:
		card_icon(b, card, c, r * 1.25)

## The same as a mesh, centred, 12.5 units across at `u`: on the gun's line
## along the grass, and bigger in the shop.
static func card_token(card: int, u: float, cart := 0) -> ArrayMesh:
	var key := _key("ct", card, cart, u)
	if _cache.has(key):
		return _cache[key]
	var b := Face.Builder.new()
	var r := 12.5 * u
	b.disc(Vector2(0, 2.4 * u), r, Color(0.3, 0.2, 0.08, 0.12))
	card_medal(b, card, Vector2.ZERO, r, cart)
	return _keep(key, b.mesh())

## A conker of radius `r`: a brown nut with its pale cap and a shine.
static func _conker(b: Face.Builder, c: Vector2, r: float, col := CONKER) -> void:
	b.disc(c + Vector2(0, r * 0.14), r, deepen(col))
	b.disc(c, r * 0.92, col)
	b.ellipse(c + Vector2(0, -r * 0.42), r * 0.56, r * 0.34, col.lerp(PAPER, 0.62))
	b.disc(c + Vector2(-r * 0.34, r * 0.1), r * 0.18, Color(1, 1, 1, 0.5))

## A pumpkin of radius `r`: three fat ribs and a stalk.
static func _pumpkin(b: Face.Builder, c: Vector2, r: float, col := PUMPKIN) -> void:
	b.fan(Face.Builder.round_rect(c + Vector2(-r * 0.12, -r * 1.2), Vector2(r * 0.24, r * 0.44), r * 0.08), POD_DEEP)
	b.ellipse(c + Vector2(0, r * 0.12), r * 1.12, r * 0.9, deepen(col))
	for k in [-1.0, 1.0]:
		b.ellipse(c + Vector2(k * r * 0.5, 0), r * 0.62, r * 0.84, col)
	b.ellipse(c, r * 0.5, r * 0.88, col.lightened(0.12))
	b.ellipse(c + Vector2(-r * 0.5, -r * 0.3), r * 0.14, r * 0.3, Color(1, 1, 1, 0.45))

## A drop of water `r` wide, its point down behind it (it flies up).
static func _drop(b: Face.Builder, c: Vector2, r: float, col: Color) -> void:
	for pass_ in 2:
		var k := 1.0 if pass_ == 0 else 0.84
		var pts := PackedVector2Array([c + Vector2(0, r * 1.9 * k)])
		pts.append_array(Face.Builder.arc_points(c, r * k, PI * 0.82, PI * 2.18))
		b.polygon(pts, deepen(col) if pass_ == 0 else col)
	b.disc(c + Vector2(-r * 0.3, -r * 0.24), r * 0.28, Color(1, 1, 1, 0.7))

## A dandelion seed `r` big, turned `turn`: the seed, and its tuft of down
## trailing behind.
## A maple's winged seed about `c`: two nuts back to back and a papery wing
## out from each, veined; the screen whirls it.
static func _samara(b: Face.Builder, c: Vector2, r: float, col := MAPLE) -> void:
	for side: float in [-1.0, 1.0]:
		var wing := PackedVector2Array()
		for p: Vector2 in [Vector2(0.2, -0.5), Vector2(1.5, -1.0), Vector2(2.7, -0.5), Vector2(2.9, 0.3), Vector2(1.6, 0.62), Vector2(0.2, 0.5)]:
			wing.append(c + Vector2(p.x * side, p.y * side) * r)
		b.polygon(wing, deepen(col))
		var inner := PackedVector2Array()
		for p: Vector2 in [Vector2(0.3, -0.34), Vector2(1.5, -0.78), Vector2(2.5, -0.38), Vector2(2.66, 0.2), Vector2(1.5, 0.42), Vector2(0.3, 0.34)]:
			inner.append(c + Vector2(p.x * side, p.y * side) * r)
		b.polygon(inner, col.lerp(PAPER, 0.35))
		b.stroke(PackedVector2Array([c + Vector2(0.4 * side, 0.3 * side) * r, c + Vector2(2.4 * side, 0.1 * side) * r]), maxf(1.0, r * 0.14), Color(deepen(col), 0.8))
	b.disc(c + Vector2(0, r * 0.1), r * 0.66, deepen(col))
	b.disc(c, r * 0.58, col)
	b.disc(c + Vector2(-r * 0.2, -r * 0.2), r * 0.18, Color(1, 1, 1, 0.6))

static func _seed(b: Face.Builder, c: Vector2, r: float, turn := 0.0, col := FLUFF) -> void:
	var back := Vector2(0, 1).rotated(turn)
	for k in [-1.0, 0.0, 1.0]:
		var d := back.rotated(k * 0.5)
		b.stroke(PackedVector2Array([c + back * r * 0.4, c + back * r * 0.4 + d * r * 1.7]), maxf(1.0, r * 0.22), Color(col, 0.9))
		b.disc(c + back * r * 0.4 + d * r * 1.7, r * 0.32, col)
	b.disc(c + Vector2(0, r * 0.1), r * 0.62, Color("8a6a45"))
	b.disc(c, r * 0.52, Color("c9a172") if col == FLUFF else col)

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

## The mote of energy and the soft light it is made of are ui/motes.gd's,
## since 2026-10-06: the Grove's energy is the same mote.
const ORB_R := Motes.ORB_R
static func glow(b: Face.Builder, c: Vector2, r: float, col: Color, fall := 2.0) -> void:
	Motes.glow(b, c, r, col, fall)

static func orb() -> ArrayMesh:
	return Motes.orb()

static func orb_light() -> ArrayMesh:
	return Motes.orb_light()

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

## A gift on the rack, centred, RACK_R across at `u`: its medallion alone,
## for the seat it sits on is the screen's.
const BUTTON_R := 10.4
static func button(kind: int, u: float) -> ArrayMesh:
	var key := _key("bt", kind, 0, u)
	if _cache.has(key):
		return _cache[key]
	var b := Face.Builder.new()
	medal(b, kind, Vector2.ZERO, BUTTON_R * u)
	return _keep(key, b.mesh())

## The paper pip a rack button's count is lettered on, centred.
const PIP_R := 6.2
static func pip(u: float) -> ArrayMesh:
	var key := _key("pip", 0, 0, u)
	if _cache.has(key):
		return _cache[key]
	var b := Face.Builder.new()
	var r := PIP_R * u
	b.disc(Vector2(0, 0.9 * u), r, Color(0.3, 0.2, 0.08, 0.22))
	b.disc(Vector2.ZERO, r, CREAM_DEEP)
	b.disc(Vector2.ZERO, r - 0.9 * u, PAPER)
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
## pale pod with a seam, a lit belly, a rolled lip and a tendril. With an
## element running (`el`: Sim.Kind.ZAP or FLAME) it is the element's colour,
## as its peas are.
static func barrel(u: float, helper := false, el := 0, cart := 0) -> ArrayMesh:
	if cart != Sim.Cart.PEA and cart != Sim.Cart.TRAIN:
		return _gun(u, el, cart)
	var key := _key("b", int(helper), el, u)
	if _cache.has(key):
		return _cache[key]
	var b := Face.Builder.new()
	var pod := POD if not helper else Color("d3da8a")
	var deep := POD_DEEP if not helper else Color("aab45c")
	var hi := POD_HI
	var mouth := POD_MOUTH
	if POD_OF.has(el):
		pod = POD_OF[el][0]
		deep = POD_OF[el][1]
		hi = POD_OF[el][2]
		mouth = POD_OF[el][3]
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
	b.ellipse(Vector2(-4.0 * u, -tall * 0.5), 2.0 * u, tall * 0.3, Color(hi, 0.8))
	b.stroke(PackedVector2Array([Vector2(3.5 * u, -3.0 * u), Vector2(4.5 * u, -tall * 0.55), Vector2(3.5 * u, -tall + 4.0 * u)]), maxf(1.0, 0.9 * u), Color(deep, 0.6))
	# the lip round the mouth, and the dark of the mouth in it
	b.ellipse(Vector2(0, -tall + 0.6 * u), 10.0 * u, 4.2 * u, deep)
	b.ellipse(Vector2(0, -tall - 0.6 * u), 9.4 * u, 3.4 * u, pod.lightened(0.25))
	b.ellipse(Vector2(0, -tall - 0.4 * u), 6.4 * u, 2.0 * u, mouth)
	# a tendril curling off the foot
	b.stroke(Face.Builder.bezier3(Vector2(8, -6) * u, Vector2(15, -8) * u, Vector2(16, -15) * u, Vector2(12, -14) * u, 10), maxf(1.0, 1.1 * u), deep)
	return _keep(key, b.mesh())

## The other carts' guns, each its foot on the origin and its mouth 30 units
## up like the pod's, so what a gift dresses the pod in sits on any of them.
## The conker's is a green husk split open on a nut; the pumpkin's a fat
## pumpkin, its top cut off; the hose's a brass-nosed spout; the dandelion's
## a stalk and a clock of down. With an element running the lip (the clock)
## is the element's colour.
static func _gun(u: float, el: int, cart: int) -> ArrayMesh:
	var key := _key("g%d" % cart, 0, el, u)
	if _cache.has(key):
		return _cache[key]
	var b := Face.Builder.new()
	var tall := 30.0 * u
	var mouth := Vector2(0, -tall)
	var trim: Color = POD_OF[el][0] if POD_OF.has(el) else Color(0, 0, 0, 0)
	match cart:
		Sim.Cart.CONKER:
			var husk := Color("9cc86a")
			var body := PackedVector2Array()
			body.append_array(Face.Builder.bezier3(Vector2(-6, 0) * u, Vector2(-16, -8) * u, Vector2(-15, -24) * u, Vector2(-9, -30) * u, 10))
			body.append_array(Face.Builder.bezier3(Vector2(9, -30) * u, Vector2(15, -24) * u, Vector2(16, -8) * u, Vector2(6, 0) * u, 10))
			b.polygon(body, deepen(husk))
			var inner := PackedVector2Array()
			for p in body:
				inner.append(Vector2(p.x * 0.86 - 0.8 * u, p.y * 0.97 - 0.4 * u))
			b.polygon(inner, husk)
			# its prickles
			for at: Vector2 in [Vector2(-13.5, -10), Vector2(-14, -20), Vector2(13.5, -10), Vector2(14, -20), Vector2(-9, -3), Vector2(9, -3)]:
				var out := Vector2(signf(at.x), -0.3).normalized()
				b.polygon(PackedVector2Array([(at + out.orthogonal() * 1.6) * u, (at + out * 4.2) * u, (at - out.orthogonal() * 1.6) * u]), deepen(husk))
			b.ellipse(Vector2(-5.0 * u, -tall * 0.5), 2.2 * u, tall * 0.26, Color(1, 1, 1, 0.3))
			b.ellipse(mouth + Vector2(0, 0.8 * u), 10.6 * u, 4.4 * u, deepen(husk))
			b.ellipse(mouth - Vector2(0, 0.4 * u), 10.0 * u, 3.6 * u, trim if trim.a > 0.0 else husk.lightened(0.3))
			b.ellipse(mouth, 7.0 * u, 2.3 * u, Color("5a3a22"))
		Sim.Cart.PUMPKIN:
			var col := PUMPKIN
			b.ellipse(Vector2(0, -13.0 * u), 17.5 * u, 14.6 * u, deepen(col))
			for k in [-1.0, 1.0]:
				b.ellipse(Vector2(k * 8.4 * u, -14.0 * u), 8.8 * u, 13.4 * u, col)
			b.ellipse(Vector2(0, -14.0 * u), 7.4 * u, 14.2 * u, col.lightened(0.12))
			b.ellipse(Vector2(-9.5 * u, -18.0 * u), 2.0 * u, 5.0 * u, Color(1, 1, 1, 0.4))
			b.ellipse(mouth + Vector2(0, 2.4 * u), 11.4 * u, 4.6 * u, deepen(col))
			b.ellipse(mouth + Vector2(0, 1.4 * u), 10.6 * u, 3.8 * u, trim if trim.a > 0.0 else col.lightened(0.3))
			b.ellipse(mouth + Vector2(0, 1.6 * u), 7.6 * u, 2.4 * u, Color("7a3d12"))
			b.stroke(Face.Builder.bezier3(Vector2(13, -22) * u, Vector2(20, -26) * u, Vector2(21, -33) * u, Vector2(17, -31) * u, 10), maxf(1.0, 1.2 * u), POD_DEEP)
		Sim.Cart.HOSE:
			var can := Color("7cc3c9")
			b.fan(Face.Builder.round_rect(Vector2(-9, -14) * u, Vector2(18, 14) * u, 4 * u), deepen(can))
			b.fan(Face.Builder.round_rect(Vector2(-9, -14) * u, Vector2(18, 11.6) * u, 4 * u), can)
			b.polygon(PackedVector2Array([Vector2(-4.6, -12) * u, Vector2(-3.4, -27) * u, Vector2(3.4, -27) * u, Vector2(4.6, -12) * u]), deepen(can))
			b.polygon(PackedVector2Array([Vector2(-4.6, -12) * u, Vector2(-3.4, -27) * u, Vector2(1.6, -27) * u, Vector2(2.4, -12) * u]), can)
			b.ellipse(Vector2(-5.4 * u, -8.0 * u), 1.3 * u, 3.6 * u, Color(1, 1, 1, 0.45))
			# the brass rose it sprays from
			b.polygon(PackedVector2Array([Vector2(-4.4, -26) * u, Vector2(-8.6, -30.4) * u, Vector2(8.6, -30.4) * u, Vector2(4.4, -26) * u]), GOLD_DEEP)
			b.ellipse(mouth + Vector2(0, 0.2 * u), 8.8 * u, 2.6 * u, GOLD_DEEP)
			b.ellipse(mouth - Vector2(0, 0.6 * u), 8.4 * u, 2.2 * u, trim if trim.a > 0.0 else DART)
			for k in 3:
				b.disc(mouth + Vector2((k - 1) * 4.0 * u, -0.6 * u), 0.9 * u, GOLD_INK)
			b.stroke(Face.Builder.bezier3(Vector2(9, -4) * u, Vector2(17, -5) * u, Vector2(17, -15) * u, Vector2(9, -13) * u, 10), maxf(1.2, 1.9 * u), deepen(can))
		Sim.Cart.MAPLE:
			# a sawn stump, its rings up, a red leaf on its side and a shoot
			var bark := Color("b98a5e")
			b.fan(Face.Builder.round_rect(Vector2(-10.5, -28) * u, Vector2(21, 29) * u, 4 * u), deepen(bark))
			b.fan(Face.Builder.round_rect(Vector2(-10.5, -28) * u, Vector2(17.5, 27.4) * u, 4 * u), bark)
			for k in 3:
				b.stroke(PackedVector2Array([Vector2(-6.0 + 5.0 * k, -22) * u, Vector2(-6.6 + 5.0 * k, -6) * u]), maxf(1.0, 0.8 * u), Color(deepen(bark), 0.55))
			b.ellipse(Vector2(-12.0, -1.0) * u, 4.4 * u, 2.4 * u, deepen(bark))
			b.ellipse(Vector2(11.6, -0.6) * u, 3.8 * u, 2.2 * u, deepen(bark))
			var leaf := PackedVector2Array()
			for k in 10:
				leaf.append(Vector2(13.0, -13.0) * u + Vector2.from_angle(TAU * k / 10.0 - 0.3) * (6.4 if k % 2 == 0 else 3.0) * u)
			b.polygon(leaf, deepen(MAPLE))
			var leaf_in := PackedVector2Array()
			for k in 10:
				leaf_in.append(Vector2(13.0, -13.4) * u + Vector2.from_angle(TAU * k / 10.0 - 0.3) * (5.2 if k % 2 == 0 else 2.4) * u)
			b.polygon(leaf_in, MAPLE)
			b.ellipse(mouth + Vector2(0, 0.8 * u), 11.0 * u, 4.2 * u, deepen(bark))
			b.ellipse(mouth - Vector2(0, 0.4 * u), 10.4 * u, 3.5 * u, trim if trim.a > 0.0 else Color("f1dfbd"))
			b.stroke(Face.Builder.ring(mouth - Vector2(0, 0.4 * u), 6.2 * u, 2.0 * u), maxf(1.0, 0.8 * u), Color(deepen(bark), 0.7), true)
			b.ellipse(mouth - Vector2(0, 0.4 * u), 2.2 * u, 0.8 * u, Color(deepen(bark), 0.8))
		_:
			# the dandelion: a stalk, two leaves, and its clock of down
			b.stroke(PackedVector2Array([Vector2(0, 0), Vector2(0.8 * u, -11.0 * u), Vector2(0, -21.0 * u)]), maxf(1.6, 2.4 * u), POD_DEEP)
			for k in [-1.0, 1.0]:
				var leaf := PackedVector2Array()
				for i in 9:
					var f := i / 8.0
					leaf.append(Vector2(k * (2.0 + 12.0 * f), -2.0 - 6.0 * f - (2.4 if i % 2 == 1 else 0.0) * sin(f * PI)) * u)
				for i in 9:
					var f := 1.0 - i / 8.0
					leaf.append(Vector2(k * (2.0 + 12.0 * f), -1.0 - 3.4 * f) * u)
				b.polygon(leaf, POD)
			var heart := Vector2(0, -23.0 * u)
			var down: Color = trim if trim.a > 0.0 else FLUFF
			b.disc(heart + Vector2(0, 0.8 * u), 10.4 * u, Color(deepen(CREAM_DEEP), 0.5))
			b.disc(heart, 10.0 * u, Color(down, 0.5))
			for k in 14:
				var d := Vector2.from_angle(TAU * k / 14.0 + 0.2)
				b.stroke(PackedVector2Array([heart + d * 2.4 * u, heart + d * 8.4 * u]), maxf(1.0, 0.7 * u), Color(down.darkened(0.12), 0.9))
				b.disc(heart + d * 8.8 * u, 1.9 * u, down)
			for k in 7:
				b.disc(heart + Vector2.from_angle(TAU * k / 7.0 + 0.5) * 4.8 * u, 1.6 * u, down)
			b.disc(heart, 2.8 * u, Color("c9a172"))
	return _keep(key, b.mesh())

## What the pod wears while the Dart runs, the middle of its mouth on the
## origin: a brass nozzle that narrows the mouth to a point.
static func nozzle(u: float) -> ArrayMesh:
	var key := _key("nz", 0, 0, u)
	if _cache.has(key):
		return _cache[key]
	var b := Face.Builder.new()
	b.polygon(PackedVector2Array([Vector2(-7.4, -0.6) * u, Vector2(-3.6, -7.6) * u, Vector2(3.6, -7.6) * u, Vector2(7.4, -0.6) * u]), GOLD_DEEP)
	b.polygon(PackedVector2Array([Vector2(-6.2, -1.0) * u, Vector2(-2.8, -6.8) * u, Vector2(2.8, -6.8) * u, Vector2(6.2, -1.0) * u]), DART)
	b.fan(Face.Builder.round_rect(Vector2(-9.8, -1.6) * u, Vector2(19.6, 4.6) * u, 2.2 * u), GOLD_DEEP)
	b.fan(Face.Builder.round_rect(Vector2(-9.8, -2.2) * u, Vector2(19.6, 3.6) * u, 1.8 * u), DART)
	b.stroke(PackedVector2Array([Vector2(-3.2, -2.8) * u, Vector2(-2.0, -5.6) * u]), maxf(1.0, 1.1 * u), Color(1, 1, 1, 0.7))
	b.ellipse(Vector2(0, -7.5 * u), 3.2 * u, 1.1 * u, GOLD_INK)
	return _keep(key, b.mesh())

## What the cart wears while the Berry runs, the cradle's middle on the
## origin: a bunch of berries either side of the pod's foot, on two leaves.
static func berries(u: float) -> ArrayMesh:
	var key := _key("br", 0, 0, u)
	if _cache.has(key):
		return _cache[key]
	var b := Face.Builder.new()
	for side in [-1.0, 1.0]:
		b.ellipse(Vector2(side * 15.5, -2.0) * u, 5.0 * u, 2.4 * u, POD_DEEP)
		for at: Vector2 in [Vector2(12.0, 1.4), Vector2(16.6, -0.6), Vector2(13.6, -3.4)]:
			var c := Vector2(side * at.x, at.y) * u
			b.disc(c + Vector2(0, 0.5 * u), 3.3 * u, deepen(BERRY))
			b.disc(c, 3.0 * u, BERRY)
			b.disc(c + Vector2(-0.9, -1.0) * u, 0.9 * u, Color(1, 1, 1, 0.7))
	return _keep(key, b.mesh())

## Lightning playing round the pod's mouth while the bolt runs, the mouth's
## middle on the origin: one of `CRACKLES` looks, a new one every blink.
const CRACKLES := 4
static func crackle(look: int, u: float) -> ArrayMesh:
	var key := _key("ck", look, 0, u)
	if _cache.has(key):
		return _cache[key]
	var b := Face.Builder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 40 + look
	for arc in 3:
		var a := rng.randf_range(-PI, 0.0)
		var from := Vector2.from_angle(a) * rng.randf_range(7.0, 10.0) * u
		var to := Vector2.from_angle(a + rng.randf_range(0.7, 1.5) * (1.0 if rng.randf() < 0.5 else -1.0)) * rng.randf_range(11.0, 17.0) * u
		var side := (to - from).orthogonal().normalized()
		var line := PackedVector2Array([from])
		for j in [1, 2, 3]:
			line.append(from.lerp(to, j / 4.0) + side * rng.randf_range(-3.2, 3.2) * u)
		line.append(to)
		b.stroke(line, 2.6 * u, Color(BOLT, 0.75))
		b.stroke(line, 1.0 * u, Color.WHITE)
	return _keep(key, b.mesh())

## A shot in flight by its shape (Sim.Shot) and its element (`el`: 0, or
## Sim.Kind.ZAP to GUST), centred, flying up, a pale wake fading behind it:
## a pea, a dart that goes through, a berry that bursts, a conker, a pumpkin,
## a drop of water or a dandelion's seed, in its own colour or, of an
## element, in the element's (lightning's yellow, the flame's red, the
## nettle's violet, the hail's ice, the gust's white). The shape never
## changes for the element.
## One mesh a look, drawn for every shot in the air by a MultiMesh.
static func shot(look: int, u: float, el := 0) -> ArrayMesh:
	var key := _key("s", look, el, u)
	if _cache.has(key):
		return _cache[key]
	var b := Face.Builder.new()
	var r := 3.3 * u
	var col: Color = [PEA, DART, BERRY, CONKER, PUMPKIN, WATER, FLUFF, MAPLE][clampi(look, 0, 7)]
	if SHOT_OF.has(el):
		col = SHOT_OF[el]
	var wake := col.lerp(PAPER, 0.5)
	if look != Sim.Shot.SEED and look != Sim.Shot.DROP and look != Sim.Shot.MAPLE:
		var i0 := b.vertex(Vector2(-r * 0.7, 0), Color(wake, 0.5))
		var i1 := b.vertex(Vector2(r * 0.7, 0), Color(wake, 0.5))
		var i2 := b.vertex(Vector2(0, r * 6.5), Color(wake, 0.0))
		b.tri(i0, i1, i2)
	match look:
		Sim.Shot.PIERCE:
			b.polygon(PackedVector2Array([Vector2(-r * 0.9, r * 1.2), Vector2(0, -r * 2.6), Vector2(r * 0.9, r * 1.2)]), deepen(col))
			b.polygon(PackedVector2Array([Vector2(-r * 0.55, r * 0.9), Vector2(0, -r * 2.2), Vector2(r * 0.55, r * 0.9)]), col)
			b.disc(Vector2(0, -r * 0.2), r * 0.3, Color(1, 1, 1, 0.8))
		Sim.Shot.BURST:
			var pts := PackedVector2Array()
			for k in 12:
				pts.append(Vector2.from_angle(TAU * k / 12.0) * r * (1.35 if k % 2 == 0 else 0.95))
			b.polygon(pts, deepen(col))
			b.disc(Vector2.ZERO, r * 0.9, col)
			b.disc(Vector2(-r * 0.3, -r * 0.32), r * 0.3, Color(1, 1, 1, 0.6))
		Sim.Shot.CONKER:
			_conker(b, Vector2.ZERO, r * 1.05, col)
		Sim.Shot.PUMPKIN:
			_pumpkin(b, Vector2.ZERO, r, col)
		Sim.Shot.DROP:
			_drop(b, Vector2.ZERO, r * 0.95, col)
		Sim.Shot.SEED:
			_seed(b, Vector2.ZERO, r * 0.9, 0.0, col)
		Sim.Shot.MAPLE:
			_samara(b, Vector2.ZERO, r * 1.1, col)
		_:
			if el == 0:
				pea(b, Vector2.ZERO, r)
			else:
				b.disc(Vector2(0, r * 0.14), r, deepen(col))
				b.disc(Vector2.ZERO, r * 0.9, col)
				b.disc(Vector2(-r * 0.3, -r * 0.32), r * 0.3, Color(1, 1, 1, 0.65))
	return _keep(key, b.mesh())

## A heart `r` tall either way of `c`, the mender's, with a paper cross on it.
static func _heart(b: Face.Builder, c: Vector2, r: float) -> void:
	for pass_ in 2:
		var k := r if pass_ == 0 else r * 0.84
		var col: Color = deepen(KEEP[Sim.Kind.MEND]) if pass_ == 0 else KEEP[Sim.Kind.MEND]
		var o := c + Vector2(0, r * 0.1 if pass_ == 0 else 0.0)
		b.disc(o + Vector2(-k * 0.46, -k * 0.3), k * 0.52, col)
		b.disc(o + Vector2(k * 0.46, -k * 0.3), k * 0.52, col)
		b.polygon(PackedVector2Array([o + Vector2(-k * 0.94, -k * 0.1), o + Vector2(k * 0.94, -k * 0.1), o + Vector2(0, k * 0.96)]), col)
	b.fan(Face.Builder.round_rect(c + Vector2(-r * 0.34, -r * 0.24), Vector2(r * 0.68, r * 0.2), r * 0.08), PAPER)
	b.fan(Face.Builder.round_rect(c + Vector2(-r * 0.1, -r * 0.48), Vector2(r * 0.2, r * 0.68), r * 0.08), PAPER)

## A padlock `r` tall either way of `c`: a brass body with a keyhole, its
## shackle over it.
static func _padlock(b: Face.Builder, c: Vector2, r: float) -> void:
	var brass: Color = KEEP[Sim.Kind.WARD]
	var loop := Face.Builder.arc_points(c + Vector2(0, -r * 0.2), r * 0.42, PI, TAU)
	loop.insert(0, c + Vector2(-r * 0.42, r * 0.1))
	loop.append(c + Vector2(r * 0.42, r * 0.1))
	b.stroke(loop, r * 0.3, INK, false, false)
	b.stroke(loop, r * 0.16, PAPER, false, false)
	b.fan(Face.Builder.round_rect(c + Vector2(-r * 0.72, -r * 0.08), Vector2(r * 1.44, r * 1.08), r * 0.2), INK)
	b.fan(Face.Builder.round_rect(c + Vector2(-r * 0.62, 0.0), Vector2(r * 1.24, r * 0.9), r * 0.14), brass)
	b.fan(Face.Builder.round_rect(c + Vector2(-r * 0.62, 0.0), Vector2(r * 1.24, r * 0.3), r * 0.14), brass.lightened(0.35))
	b.disc(c + Vector2(0, r * 0.4), r * 0.15, INK)
	b.fan(Face.Builder.round_rect(c + Vector2(-r * 0.06, r * 0.4), Vector2(r * 0.12, r * 0.3), r * 0.04), INK)

## The badge at the corner of a thing a PLUS or a TIMES looks after,
## centred: a disc of that crate's colour with its sign in paper.
static func badge(kind: int, u: float) -> ArrayMesh:
	var key := _key("bdg", kind, 0, u)
	if _cache.has(key):
		return _cache[key]
	var b := Face.Builder.new()
	var r := 5.6 * u
	var col: Color = KEEP[kind]
	b.disc(Vector2.ZERO, r + 1.2 * u, PAPER)
	b.disc(Vector2(0, 0.5 * u), r, deepen(col))
	b.disc(Vector2.ZERO, r * 0.94, col)
	var turn := 0.0 if kind == Sim.Kind.PLUS else PI * 0.25
	for k in 2:
		var d := Vector2.from_angle(turn + PI * 0.5 * k) * r * 0.56
		b.stroke(PackedVector2Array([-d, d]), maxf(1.4, 1.7 * u), PAPER)
	return _keep(key, b.mesh())

## What a thing the lock keeps wears, centred: a paper band round it with
## an ink line in it, and a small padlock on its top edge. `round` is a
## millipede's plate. A ring, never a shade of the thing's paint.
static func kept(round: bool, u: float) -> ArrayMesh:
	var key := _key("kpt", int(round), 0, u)
	if _cache.has(key):
		return _cache[key]
	var b := Face.Builder.new()
	var top := Vector2.ZERO
	var line: PackedVector2Array
	if round:
		var r := Sim.SEG_R * u
		line = Face.Builder.ring(Vector2(0, -r * 0.09), r * 0.86, r * 0.86)
		top = Vector2(0, -r * 0.95)
	else:
		var w := (Sim.CELL_W - 3.0) * u
		var h := (Sim.CELL_H - 3.0) * u - LIP * u
		line = Face.Builder.round_rect(Vector2(-w * 0.5, -(h + LIP * u) * 0.5) + Vector2(2.2, 2.2) * u, Vector2(w - 4.4 * u, h - 4.4 * u), ROUND * u * 0.8)
		top = Vector2(w * 0.5 - 9.0 * u, -(h + LIP * u) * 0.5 + 2.0 * u)
	b.stroke(line, 3.4 * u, Color(PAPER, 0.95), true)
	b.stroke(line, maxf(1.0, 0.9 * u), Color(INK, 0.75), true)
	b.disc(top + Vector2(0, 1.0 * u), 6.6 * u, PAPER)
	_padlock(b, top, 5.2 * u)
	return _keep(key, b.mesh())

## The nettle's mark on a thing stung, centred: a small violet leaf, its
## saw edge in ink. Never a tint of the thing: a crate's paint is its number.
static func sting(u: float) -> ArrayMesh:
	var key := _key("stg", 0, 0, u)
	if _cache.has(key):
		return _cache[key]
	var b := Face.Builder.new()
	for pass_ in 2:
		var k := 1.0 if pass_ == 0 else 0.74
		var leaf := PackedVector2Array()
		for i in 9:
			var f := i / 8.0
			leaf.append(Vector2(-(3.4 if i % 2 == 1 else 2.2) * sin(f * PI) * k, 5.4 * k - 11.0 * f * k) * u)
		for i in 9:
			var f := 1.0 - i / 8.0
			leaf.append(Vector2((3.4 if i % 2 == 1 else 2.2) * sin(f * PI) * k, 5.4 * k - 11.0 * f * k) * u)
		b.polygon(leaf, Color("4f3472") if pass_ == 0 else STING)
	b.stroke(PackedVector2Array([Vector2(0, 4.6 * u), Vector2(0, -3.4 * u)]), maxf(1.0, 0.7 * u), Color(PAPER, 0.7))
	return _keep(key, b.mesh())

## The hail's mark on a thing left brittle, centred: a six-armed crystal of
## ice with an ink edge.
static func rime(u: float) -> ArrayMesh:
	var key := _key("rim", 0, 0, u)
	if _cache.has(key):
		return _cache[key]
	var b := Face.Builder.new()
	for pass_ in 2:
		var wide := (2.6 if pass_ == 0 else 1.3) * u
		var col := Color("4f7896") if pass_ == 0 else Color("f4fbff")
		for k in 3:
			var d := Vector2.from_angle(PI * 0.5 + PI * k / 3.0)
			b.stroke(PackedVector2Array([-d * 5.4 * u, d * 5.4 * u]), wide, col)
			for end in [-1.0, 1.0]:
				for side in [-1.0, 1.0]:
					b.stroke(PackedVector2Array([d * 3.2 * u * end, d * 3.2 * u * end + d.rotated(side * 0.9) * 2.0 * u * end]), wide * 0.8, col)
	b.disc(Vector2.ZERO, 1.4 * u, ICE)
	return _keep(key, b.mesh())

## A puff of wind where a gust's shot lands, centred, in white: two curls,
## swelled and thinned by their draw.
static func puff(u: float) -> ArrayMesh:
	var key := _key("puf", 0, 0, u)
	if _cache.has(key):
		return _cache[key]
	var b := Face.Builder.new()
	for k in 2:
		var y := (-3.0 + 6.0 * k) * u
		var w := (9.0 - 2.4 * k) * u
		var line := PackedVector2Array([Vector2(-10.0 * u, y)])
		line.append_array(Face.Builder.arc_points(Vector2(w - 3.0 * u, y - 3.0 * u), 3.0 * u, PI * 0.5, -PI * 0.9))
		b.stroke(line, 2.0 * u, Color.WHITE)
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

## How worn a crate or a plate with `hp` left of `most` is, 0 (whole) to
## WORN (about to break): the cracks it shows.
const WORN := 3
static func worn(hp: int, most: int) -> int:
	if hp >= most or most <= 1:
		return 0
	var left := float(hp) / most
	return 3 if left <= 0.25 else (2 if left <= 0.5 else (1 if left <= 0.8 else 0))

## Whether `p` (field units, a piece's own middle the origin) is on the face
## of a crate (its round corners kept) or, `round`, of a plate.
static func _on_face(p: Vector2, round: bool) -> bool:
	if round:
		return p.distance_to(Vector2(0, -Sim.SEG_R * 0.09)) < Sim.SEG_R * 0.9
	var half := Vector2((Sim.CELL_W - 3.0) * 0.5 - 0.6, (Sim.CELL_H - 3.0 - LIP) * 0.5 - 0.5)
	var q := (p - Vector2(0, -LIP * 0.5)).abs() - half + Vector2(ROUND, ROUND)
	return Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - ROUND < 0.0

## `pts` as far as `part` of its length.
static func _cut(pts: PackedVector2Array, part: float) -> PackedVector2Array:
	if part >= 1.0 or pts.size() < 2:
		return pts
	var whole := 0.0
	for i in pts.size() - 1:
		whole += pts[i].distance_to(pts[i + 1])
	var left := whole * part
	var out := PackedVector2Array([pts[0]])
	for i in pts.size() - 1:
		var seg := pts[i].distance_to(pts[i + 1])
		if seg >= left:
			out.append(pts[i].lerp(pts[i + 1], left / maxf(seg, 0.001)))
			break
		out.append(pts[i + 1])
		left -= seg
	return out

## A line through `pts` (pixels) that thins from `w0` wide to `w1` at its
## tip, soft-edged, laid into a builder: one run of triangles, so nothing
## laps and beads where it bends.
static func _ribbon(b: Face.Builder, pts: PackedVector2Array, w0: float, w1: float, col: Color) -> void:
	var n := pts.size()
	if n < 2:
		return
	var clear := Color(col, 0.0)
	var base := b.verts.size()
	for i in n:
		var t := (pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var nrm := Vector2(-t.y, t.x)
		var half := lerpf(w0, w1, float(i) / (n - 1)) * 0.5
		b.vertex(pts[i] - nrm * (half + 0.7), clear)
		b.vertex(pts[i] - nrm * half, col)
		b.vertex(pts[i] + nrm * half, col)
		b.vertex(pts[i] + nrm * (half + 0.7), clear)
	for i in n - 1:
		var p := base + i * 4
		var q := p + 4
		for k in 3:
			b.tri(p + k, q + k, q + k + 1)
			b.tri(p + k, q + k + 1, p + k + 1)

## A crack through `pts` (field units) into a builder at `u`: a pale edge
## under a dark hairline, so it is a split in the thing and not a line drawn
## on it, and reads on any paint (the dark on a pale one, the pale on a dark
## one). `wide` at its start, a hair at its tip.
static func _crack_line(b: Face.Builder, pts: PackedVector2Array, u: float, wide: float) -> void:
	var at := PackedVector2Array()
	var lit := PackedVector2Array()
	for p in pts:
		at.append(p * u)
		lit.append(p * u + Vector2(0.45, 0.6) * u)
	_ribbon(b, lit, wide * u, 0.3 * u, Color(1, 1, 1, 0.34))
	_ribbon(b, at, wide * u, 0.22 * u, Color(INK, 0.66))

## The break in a crate's face (or, `round`, a plate's), centred like it:
## where it was struck, a little pit, and hairline cracks running out from
## it to the edges, straight for a way and then kinked, each its own
## length. `stage` (1..WORN) is how far it has gone: two short cracks; then
## four, longer, one forking, and a shard between two of them sunk a shade;
## then every one out to the edge, forked, joined across into shards (some
## sunk, some lifted to the light), with a bite out of the edge where a
## crack ends on it. A later stage only adds to an earlier one, so a
## crate's cracks grow and never jump. `look` is one of CRACK_LOOKS breaks,
## none like another: where it was struck, how many cracks, which way and
## how far each goes are all thrown for it.
const CRACK_LOOKS := 6
static func cracks(round: bool, look: int, stage: int, u: float) -> ArrayMesh:
	var key := _key("cr%d" % int(round), look, stage, u)
	if _cache.has(key):
		return _cache[key]
	var b := Face.Builder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7919 * (look + 1) + (31 if round else 0)
	stage = clampi(stage, 1, WORN)
	var mid := Vector2(0, -Sim.SEG_R * 0.09) if round else Vector2(0, -LIP * 0.5)
	var span := Vector2(Sim.SEG_R, Sim.SEG_R) * 0.5 if round else Vector2(Sim.CELL_W * 0.36, Sim.CELL_H * 0.27)
	# where it was struck: off the middle, clear of most of its number
	var hit := mid + Vector2(rng.randf_range(0.45, 1.0) * (1.0 if rng.randf() < 0.5 else -1.0), rng.randf_range(-1.0, 1.0)) * span
	var stride := 0.6 if round else 1.0
	var n := 5 + rng.randi() % 3
	var turn := rng.randf() * TAU
	var lines: Array = []
	var reached: Array = []
	for k in n:
		var out := turn + TAU * k / n + rng.randf_range(-0.4, 0.4)
		var way := Vector2.from_angle(out)
		var pts := PackedVector2Array([hit])
		var at_edge := false
		for i in 12:
			# straight for a way, and now and then a sharp kink
			var bend := rng.randf_range(-0.22, 0.22)
			if rng.randf() < 0.35:
				bend = rng.randf_range(0.55, 1.0) * (1.0 if rng.randf() < 0.5 else -1.0)
			way = (way.rotated(bend) * 0.74 + Vector2.from_angle(out) * 0.26).normalized()
			var from := pts[pts.size() - 1]
			var to := from + way * rng.randf_range(3.5, 9.0) * stride
			if not _on_face(to, round):
				# as far as the edge, and no further
				var lo := 0.0
				var hi := 1.0
				for step in 7:
					var m := (lo + hi) * 0.5
					if _on_face(from.lerp(to, m), round):
						lo = m
					else:
						hi = m
				pts.append(from.lerp(to, lo))
				at_edge = true
				break
			pts.append(to)
		lines.append(pts)
		reached.append(at_edge)
	# the order they open in, and how far each has got at the first stages
	var order: Array = range(n)
	for i in range(n - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var held: int = order[i]
		order[i] = order[j]
		order[j] = held
	var open: int = [2, 4, n][stage - 1]
	var wide: float = [0.95, 1.1, 1.25][stage - 1]
	var shown: Array = []
	shown.resize(n)
	for q in n:
		var k: int = order[q]
		var grown := rng.randf_range(0.35, 0.55)
		var part := 0.0
		if q < open:
			part = 1.0 if stage == WORN else (grown if stage == 1 or q >= 2 else minf(1.0, grown + 0.45))
		shown[k] = _cut(lines[k], part) if part > 0.0 else PackedVector2Array()
	# a shard between two cracks side by side, sunk a shade or lifted to the light
	var tints := [Color(INK, 0.1), Color(1, 1, 1, 0.16), Color(INK, 0.07)]
	var shards := 0
	for k in n:
		var here: PackedVector2Array = shown[k]
		var next: PackedVector2Array = shown[(k + 1) % n]
		var want := rng.randf() < 0.55
		if not want or here.size() < 2 or next.size() < 2 or shards >= [0, 1, 3][stage - 1]:
			continue
		var edge := PackedVector2Array()
		for p in here:
			edge.append(p * u)
		for i in range(next.size() - 1, 0, -1):
			edge.append(next[i] * u)
		if Geometry2D.triangulate_polygon(edge).is_empty():
			continue
		b.polygon(edge, tints[shards % tints.size()])
		shards += 1
	for q in mini(open, n):
		var k: int = order[q]
		var pts: PackedVector2Array = shown[k]
		var fork_at := rng.randi_range(1, 3)
		var fork_turn := rng.randf_range(0.6, 1.1) * (1.0 if rng.randf() < 0.5 else -1.0)
		var fork_long := rng.randf_range(4.0, 8.0) * stride
		var kink := rng.randf_range(-0.7, 0.7)
		_crack_line(b, pts, u, wide)
		# a fork off it, once it has grown past where the fork leaves
		if stage >= 2 and (stage == WORN or q == 0) and fork_at < pts.size() - 1:
			var from := pts[fork_at]
			var way := (pts[fork_at] - pts[fork_at - 1]).normalized().rotated(fork_turn)
			var bend := from + way * fork_long * 0.6
			var tip := bend + way.rotated(kink) * fork_long * 0.4
			if _on_face(bend, round) and _on_face(tip, round):
				_crack_line(b, PackedVector2Array([from, bend, tip]), u, wide * 0.6)
	if stage == WORN:
		# joined across, from one crack to the next round
		for k in n:
			var a: PackedVector2Array = lines[k]
			var c: PackedVector2Array = lines[(k + 1) % n]
			var keep := rng.randf() < 0.5
			# near where it was struck, as a struck thing rings: never a long
			# line from one far end to another
			var ia := rng.randi_range(1, clampi(a.size() - 1, 1, 2))
			var ic := rng.randi_range(1, clampi(c.size() - 1, 1, 2))
			if not keep or a[ia].distance_to(c[ic]) > 15.0 * stride:
				continue
			_crack_line(b, PackedVector2Array([a[ia], c[ic]]), u, 0.6)
		# a bite out of the edge where a crack ends on it
		var bites := 0
		for k in n:
			if not reached[k] or bites >= 2:
				continue
			var pts: PackedVector2Array = lines[k]
			var end := pts[pts.size() - 1]
			var back := (pts[pts.size() - 2] - end).normalized()
			var side := back.orthogonal()
			var wide_b := rng.randf_range(1.6, 2.6) * stride
			var deep := rng.randf_range(1.6, 2.6) * stride
			b.polygon(PackedVector2Array([(end + side * wide_b) * u, (end + back * deep + side * 0.3) * u, (end - side * wide_b * 0.8) * u]), Color(INK, 0.45))
			bites += 1
	# the pit where it was struck, ragged and bigger each time
	var pit := PackedVector2Array()
	var r: float = [0.7, 1.0, 1.4][stage - 1] * (0.8 if round else 1.0)
	for k in 6:
		pit.append((hit + Vector2.from_angle(TAU * k / 6.0 + rng.randf_range(-0.3, 0.3)) * r * rng.randf_range(0.6, 1.25)) * u)
	b.polygon(pit, Color(INK, 0.6))
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
