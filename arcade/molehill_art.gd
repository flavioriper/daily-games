extends RefCounted

## Molehill's cast, drawn as builder shapes and shared by the game
## (arcade/molehill_screen.gd) and its card on the Arcade tab. Every sprite
## is built in pixels for a field unit of `u` pixels, standing on the hole's
## mouth at the origin (y 0), up being -y, so the screen raises and lowers a
## mole by the draw transform and never rebuilds one to move it. Meshes are
## cached per look and scale.
##
## The cast: a velvet mole with a pink nose and spade paws, a golden one, a
## mole wearing a terracotta flowerpot (cracked after the first whack), and
## the rabbit who is only visiting. Each has a dizzy look for after a whack.
## The mallet is a wooden garden mallet; a molehill is a mound of soil in
## two halves, the back (with the hole) and the front lip the mole rises
## behind.

const Pal = preload("res://core/palette.gd")
const Face = preload("res://ui/faces/face.gd")

enum Look { MOLE, MOLE_DIZZY, MOLE_TEASE, GOLD, GOLD_DIZZY, POT, POT_CRACKED, POT_DIZZY, BUNNY, BUNNY_DIZZY }

const INK := Color("3b3028")
const FUR := Color("6f5f66")
const FUR_DEEP := Color("57494f")
const BELLY := Color("a8949a")
const NOSE := Color("f29aa3")
const PAW := Color("f2bfb0")
const PAW_DEEP := Color("d99a8c")
const GOLD := Color("f2c14e")
const GOLD_DEEP := Color("d49a2c")
const GOLD_BELLY := Color("fbe3a0")
const POT := Color("d9774a")
const POT_DEEP := Color("b85c34")
const POT_RIM := Color("e8946a")
const SPROUT := Color("7fa84a")
const BUNNY := Color("f6efe4")
const BUNNY_DEEP := Color("e2d6c4")
const EAR_PINK := Color("f4b7c0")
const SOIL := Color("a87a52")
const SOIL_DEEP := Color("8a5f3d")
const SOIL_HI := Color("c49a6c")
const HOLE := Color("3e2a1f")
const HOLE_RIM := Color("5a3d2b")
const WOOD := Color("b98556")
const WOOD_DEEP := Color("946440")
const WOOD_BAND := Color("7a5236")
const HANDLE := Color("d8b07e")

## The mound, in units: its half-width and half-height, and the hole's.
const MOUND := Vector2(46.0, 19.0)
const HOLE_R := Vector2(29.0, 10.0)
## How far below the mouth a sunk mole stands, in units: it clears the clip.
const DEPTH := 76.0

static var _cache := {}

static func mesh(look: int, u: float) -> ArrayMesh:
	var key := "m%d/%.2f" % [look, u]
	if _cache.has(key):
		return _cache[key]
	if _cache.size() > 200:
		_cache.clear()
	var b := Face.Builder.new()
	match look:
		Look.MOLE:
			mole(b, u, FUR, FUR_DEEP, BELLY, "open")
		Look.MOLE_DIZZY:
			mole(b, u, FUR, FUR_DEEP, BELLY, "dizzy")
		Look.MOLE_TEASE:
			mole(b, u, FUR, FUR_DEEP, BELLY, "tease")
		Look.GOLD:
			mole(b, u, GOLD, GOLD_DEEP, GOLD_BELLY, "open")
			_shine(b, u)
		Look.GOLD_DIZZY:
			mole(b, u, GOLD, GOLD_DEEP, GOLD_BELLY, "dizzy")
		Look.POT:
			mole(b, u, FUR, FUR_DEEP, BELLY, "open")
			pot(b, u, false)
		Look.POT_CRACKED:
			mole(b, u, FUR, FUR_DEEP, BELLY, "worried")
			pot(b, u, true)
		Look.POT_DIZZY:
			mole(b, u, FUR, FUR_DEEP, BELLY, "dizzy")
		Look.BUNNY:
			bunny(b, u, false)
		Look.BUNNY_DIZZY:
			bunny(b, u, true)
	var m := b.mesh()
	_cache[key] = m
	return m

## The mound's back half, with the hole, centred on the hole's mouth.
static func mound_back(b: Face.Builder, at: Vector2, u: float) -> void:
	var s := u
	b.ellipse(at + Vector2(0, 8.0 * s), (MOUND.x + 4.0) * s, (MOUND.y + 3.0) * s, Color(0.25, 0.18, 0.1, 0.18))
	b.ellipse(at + Vector2(0, 4.0 * s), MOUND.x * s, MOUND.y * s, SOIL)
	b.ellipse(at + Vector2(-6.0 * s, -4.0 * s), MOUND.x * 0.7 * s, MOUND.y * 0.55 * s, SOIL_HI)
	b.ellipse(at + Vector2(0, -0.6 * s), (HOLE_R.x + 3.0) * s, (HOLE_R.y + 2.2) * s, HOLE_RIM)
	b.ellipse(at, HOLE_R.x * s, HOLE_R.y * s, HOLE)
	b.ellipse(at + Vector2(0, -2.5 * s), HOLE_R.x * 0.8 * s, HOLE_R.y * 0.45 * s, HOLE.darkened(0.25))

## The mound's front lip: the soil in front of the hole, which a mole rises
## from behind. Pebbles and a crumb or two on it.
static func mound_front(b: Face.Builder, at: Vector2, u: float) -> void:
	var s := u
	var pts := PackedVector2Array()
	var n := 18
	for i in n + 1:
		var a := PI * i / n
		pts.append(at + Vector2(cos(a) * MOUND.x * s, 4.0 * s + sin(a) * MOUND.y * s))
	for i in range(n, -1, -1):
		var a := PI * i / n
		pts.append(at + Vector2(cos(a) * HOLE_R.x * s, sin(a) * HOLE_R.y * s))
	b.polygon(pts, SOIL)
	# the lit crest of the lip, and its shaded foot
	var crest := PackedVector2Array()
	for i in range(3, n - 2):
		var a := PI * i / n
		crest.append(at + Vector2(cos(a) * (HOLE_R.x + 2.0) * s, (sin(a) * (HOLE_R.y + 2.5) + 0.5) * s))
	b.stroke(crest, 2.4 * s, SOIL_HI)
	var foot := PackedVector2Array()
	for i in range(2, n - 1):
		var a := PI * i / n
		foot.append(at + Vector2(cos(a) * (MOUND.x - 3.0) * s, (4.0 + sin(a) * (MOUND.y - 3.0)) * s))
	b.stroke(foot, 2.6 * s, SOIL_DEEP)
	for p in [Vector2(-22, 13), Vector2(17, 16), Vector2(30, 9), Vector2(-8, 19)]:
		b.ellipse(at + p * s, 3.2 * s, 2.2 * s, Pal.CAIRN_STONE)
		b.ellipse(at + (p + Vector2(-0.8, -0.8)) * s, 1.4 * s, 0.8 * s, Color(1, 1, 1, 0.4))
	for p in [Vector2(-32, 6), Vector2(4, 22), Vector2(24, 20)]:
		b.disc(at + p * s, 1.8 * s, SOIL_DEEP)

## A mole standing in the hole: a velvet pear with a lighter belly, spade
## paws on the rim, a pink nose and whiskers. `face` is "open", "dizzy"
## (spiral eyes, tongue), "tease" (a wink and a tongue) or "worried".
static func mole(b: Face.Builder, u: float, fur: Color, deep: Color, belly: Color, face: String) -> void:
	var s := u
	b.ellipse(Vector2(0, -22.0 * s), 21.0 * s, 32.0 * s, deep)
	b.ellipse(Vector2(-1.0 * s, -23.5 * s), 19.5 * s, 30.5 * s, fur)
	b.ellipse(Vector2(0, -12.0 * s), 12.5 * s, 17.0 * s, belly)
	# the sheen along the crown
	b.ellipse(Vector2(-7.0 * s, -44.0 * s), 6.0 * s, 3.2 * s, Color(1, 1, 1, 0.16))
	# spade paws on the rim, pads and claws
	for side in [-1.0, 1.0]:
		var c := Vector2(side * 15.0 * s, -5.0 * s)
		b.ellipse(c + Vector2(0, 1.2 * s), 9.5 * s, 6.0 * s, PAW_DEEP)
		b.ellipse(c, 9.0 * s, 5.4 * s, PAW)
		for k in 3:
			var cx := c + Vector2((k - 1) * 3.6 * s, -3.8 * s)
			b.ellipse(cx, 1.3 * s, 2.0 * s, Color("fff4ea"))
	var eye_y := -36.0 * s
	var gap := 7.5 * s
	match face:
		"dizzy":
			for side in [-1.0, 1.0]:
				var c := Vector2(side * gap, eye_y)
				var sp := PackedVector2Array()
				for k in 14:
					var a: float = k * 0.85 * side
					sp.append(c + Vector2.from_angle(a) * (0.4 + k * 0.23) * s)
				b.stroke(sp, 0.9 * s, INK)
		"tease":
			b.stroke(Face.Builder.bezier2(Vector2(-gap - 2.4 * s, eye_y), Vector2(-gap, eye_y - 2.4 * s), Vector2(-gap + 2.4 * s, eye_y), 8), 1.2 * s, INK)
			b.ellipse(Vector2(gap, eye_y), 2.0 * s, 2.6 * s, INK)
			b.disc(Vector2(gap - 0.7 * s, eye_y - 0.9 * s), 0.8 * s, Color.WHITE)
		"worried":
			for side in [-1.0, 1.0]:
				var c := Vector2(side * gap, eye_y)
				b.ellipse(c, 2.0 * s, 2.6 * s, INK)
				b.disc(c + Vector2(-0.7 * s, -0.9 * s), 0.8 * s, Color.WHITE)
				b.stroke(PackedVector2Array([c + Vector2(-side * 3.0 * s, -4.4 * s), c + Vector2(side * 1.8 * s, -5.6 * s)]), 0.9 * s, INK)
		_:
			for side in [-1.0, 1.0]:
				var c := Vector2(side * gap, eye_y)
				b.ellipse(c, 2.0 * s, 2.6 * s, INK)
				b.disc(c + Vector2(-0.7 * s, -0.9 * s), 0.8 * s, Color.WHITE)
	for side in [-1.0, 1.0]:
		b.ellipse(Vector2(side * 11.5 * s, -28.5 * s), 3.2 * s, 1.9 * s, Color(Pal.CHEEK, 0.75))
	# whiskers, then the snout and its big pink nose
	for side in [-1.0, 1.0]:
		for k in 3:
			var from := Vector2(side * 5.0 * s, -29.0 * s)
			var to := Vector2(side * 17.0 * s, (-33.0 + k * 3.5) * s)
			b.stroke(PackedVector2Array([from, to]), 0.55 * s, Color(INK, 0.55))
	b.ellipse(Vector2(0, -28.0 * s), 6.2 * s, 4.6 * s, fur.lightened(0.12))
	b.ellipse(Vector2(0, -30.5 * s), 4.4 * s, 3.3 * s, NOSE)
	b.ellipse(Vector2(-1.3 * s, -31.6 * s), 1.4 * s, 0.8 * s, Color(1, 1, 1, 0.6))
	if face == "dizzy" or face == "tease":
		b.ellipse(Vector2(1.2 * s, -21.5 * s), 2.4 * s, 3.2 * s, Color("e9707e"))
		b.stroke(PackedVector2Array([Vector2(-3.2 * s, -24.0 * s), Vector2(3.2 * s, -24.0 * s)]), 0.8 * s, INK)
	else:
		b.stroke(Face.Builder.bezier2(Vector2(-2.6 * s, -24.2 * s), Vector2(0, -22.4 * s), Vector2(2.6 * s, -24.2 * s), 8), 0.8 * s, INK)

## A golden mole's sparkle, beside its crown.
static func _shine(b: Face.Builder, u: float) -> void:
	var s := u
	for p in [Vector2(-19, -48), Vector2(18, -40)]:
		var c: Vector2 = p * s
		var r := 4.2 * s if p.x < 0 else 3.0 * s
		b.fan(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.25, -r * 0.25), c + Vector2(r, 0), c + Vector2(r * 0.25, r * 0.25),
			c + Vector2(0, r), c + Vector2(-r * 0.25, r * 0.25), c + Vector2(-r, 0), c + Vector2(-r * 0.25, -r * 0.25)]), Color("fff6c9"))

## A terracotta flowerpot worn upside down, a sprout still growing out of
## its drainage hole; cracked, it has a chip out of the rim and two cracks.
static func pot(b: Face.Builder, u: float, cracked: bool) -> void:
	var s := u
	var rim_y := -43.0 * s
	var top_y := -66.0 * s
	var body := PackedVector2Array([Vector2(-19.0 * s, rim_y), Vector2(19.0 * s, rim_y), Vector2(13.0 * s, top_y), Vector2(-13.0 * s, top_y)])
	b.fan(body, POT)
	b.fan(PackedVector2Array([Vector2(4.0 * s, rim_y), Vector2(19.0 * s, rim_y), Vector2(13.0 * s, top_y), Vector2(7.0 * s, top_y)]), POT_DEEP)
	b.fan(Face.Builder.round_rect(Vector2(-22.0 * s, rim_y - 3.0 * s), Vector2(44.0 * s, 8.0 * s), 3.0 * s), POT_RIM)
	b.fan(PackedVector2Array([Vector2(8.0 * s, rim_y - 3.0 * s), Vector2(22.0 * s, rim_y - 3.0 * s), Vector2(22.0 * s, rim_y + 5.0 * s), Vector2(8.0 * s, rim_y + 5.0 * s)]), POT_DEEP.lerp(POT_RIM, 0.4))
	b.ellipse(Vector2(-7.0 * s, -55.0 * s), 2.2 * s, 7.0 * s, Color(1, 1, 1, 0.18))
	# the sprout through the hole in its bottom
	var stem := Face.Builder.bezier2(Vector2(0, top_y), Vector2(1.5 * s, top_y - 5.0 * s), Vector2(0, top_y - 9.0 * s), 8)
	b.stroke(stem, 1.4 * s, SPROUT)
	for side in [-1.0, 1.0]:
		var leaf := Transform2D(side * 0.6, Vector2(side * 3.4 * s, top_y - 8.5 * s))
		b.fan(leaf * Face.Builder.ring(Vector2.ZERO, 3.6 * s, 1.8 * s), SPROUT.lightened(0.1 if side < 0 else 0.0))
	if cracked:
		b.fan(PackedVector2Array([Vector2(-15.0 * s, rim_y - 3.2 * s), Vector2(-6.0 * s, rim_y - 3.2 * s), Vector2(-10.0 * s, rim_y + 4.0 * s)]), FUR)
		b.stroke(PackedVector2Array([Vector2(-10.0 * s, rim_y + 3.0 * s), Vector2(-7.0 * s, rim_y - 6.0 * s), Vector2(-9.0 * s, rim_y - 12.0 * s), Vector2(-4.0 * s, top_y + 2.0 * s)]), 1.0 * s, INK)
		b.stroke(PackedVector2Array([Vector2(12.0 * s, rim_y - 2.0 * s), Vector2(8.0 * s, rim_y - 9.0 * s), Vector2(10.0 * s, rim_y - 15.0 * s)]), 0.9 * s, INK)

## The rabbit, who only came to look: cream fur, tall ears with pink
## insides, round eyes and a twitchy nose. Dizzy, her ears flop.
static func bunny(b: Face.Builder, u: float, dizzy: bool) -> void:
	var s := u
	for side in [-1.0, 1.0]:
		var tilt: float = side * (1.25 if dizzy else 0.16)
		var base := Vector2(side * 8.0 * s, -46.0 * s)
		var xf := Transform2D(tilt, base)
		b.fan(xf * Face.Builder.ring(Vector2(0, -16.0 * s), 6.2 * s, 16.5 * s), BUNNY_DEEP)
		b.fan(xf * Face.Builder.ring(Vector2(0, -16.5 * s), 5.6 * s, 16.0 * s), BUNNY)
		b.fan(xf * Face.Builder.ring(Vector2(0, -15.0 * s), 2.9 * s, 11.5 * s), EAR_PINK)
	b.ellipse(Vector2(0, -22.0 * s), 20.0 * s, 30.0 * s, BUNNY_DEEP)
	b.ellipse(Vector2(-1.0 * s, -23.0 * s), 19.0 * s, 29.0 * s, BUNNY)
	b.ellipse(Vector2(0, -12.0 * s), 11.0 * s, 15.0 * s, Color("fffaf2"))
	for side in [-1.0, 1.0]:
		var c := Vector2(side * 13.0 * s, -5.0 * s)
		b.ellipse(c, 7.5 * s, 5.0 * s, BUNNY_DEEP)
		b.ellipse(c + Vector2(0, -0.6 * s), 7.0 * s, 4.4 * s, Color("fffaf2"))
	var eye_y := -35.0 * s
	for side in [-1.0, 1.0]:
		var c := Vector2(side * 7.5 * s, eye_y)
		if dizzy:
			b.stroke(PackedVector2Array([c + Vector2(-2.2, -2.2) * s, c + Vector2(2.2, 2.2) * s]), 1.0 * s, INK)
			b.stroke(PackedVector2Array([c + Vector2(-2.2, 2.2) * s, c + Vector2(2.2, -2.2) * s]), 1.0 * s, INK)
		else:
			b.ellipse(c, 2.6 * s, 3.2 * s, INK)
			b.disc(c + Vector2(-0.9 * s, -1.1 * s), 1.0 * s, Color.WHITE)
		b.ellipse(Vector2(side * 12.0 * s, -27.5 * s), 3.2 * s, 1.9 * s, Color(Pal.CHEEK, 0.8))
	b.fan(PackedVector2Array([Vector2(-2.4 * s, -30.0 * s), Vector2(2.4 * s, -30.0 * s), Vector2(0, -27.4 * s)]), EAR_PINK.darkened(0.08))
	b.stroke(Face.Builder.bezier2(Vector2(0, -27.4 * s), Vector2(-1.2 * s, -25.0 * s), Vector2(-3.0 * s, -25.6 * s), 6), 0.7 * s, INK)
	b.stroke(Face.Builder.bezier2(Vector2(0, -27.4 * s), Vector2(1.2 * s, -25.0 * s), Vector2(3.0 * s, -25.6 * s), 6), 0.7 * s, INK)
	for side in [-1.0, 1.0]:
		for k in 2:
			b.stroke(PackedVector2Array([Vector2(side * 4.0 * s, -28.0 * s), Vector2(side * 15.0 * s, (-30.5 + k * 3.0) * s)]), 0.5 * s, Color(INK, 0.4))

## The mallet, its hand at the origin and its head up the handle at
## (0, -HEAD_AT): a turned handle and a barrel head with two iron bands.
const HEAD_AT := 50.0

static func mallet(u: float) -> ArrayMesh:
	var key := "mallet/%.2f" % u
	if _cache.has(key):
		return _cache[key]
	var b := Face.Builder.new()
	var s := u
	b.stroke(PackedVector2Array([Vector2(0, 0), Vector2(0, -HEAD_AT * s)]), 5.2 * s, WOOD_DEEP)
	b.stroke(PackedVector2Array([Vector2(-0.6 * s, -2.0 * s), Vector2(-0.6 * s, -(HEAD_AT - 4.0) * s)]), 3.4 * s, HANDLE)
	b.disc(Vector2.ZERO, 3.6 * s, WOOD_DEEP)
	var head := Vector2(0, -HEAD_AT * s)
	b.fan(Face.Builder.round_rect(head - Vector2(21.0, 12.0) * s, Vector2(42.0, 24.0) * s, 6.0 * s), WOOD_DEEP)
	b.fan(Face.Builder.round_rect(head - Vector2(20.0, 11.0) * s, Vector2(40.0, 20.0) * s, 5.5 * s), WOOD)
	b.fan(Face.Builder.round_rect(head - Vector2(18.0, 9.0) * s, Vector2(36.0, 5.0) * s, 2.5 * s), Color(1, 1, 1, 0.2))
	for side in [-1.0, 1.0]:
		b.fan(Face.Builder.round_rect(head + Vector2(side * 13.0 - 2.5, -12.0) * s, Vector2(5.0, 24.0) * s, 1.5 * s), WOOD_BAND)
	for side in [-1.0, 1.0]:
		b.ellipse(head + Vector2(side * 20.5 * s, 0), 2.2 * s, 10.5 * s, WOOD.lightened(0.12))
	var m := b.mesh()
	_cache[key] = m
	return m
