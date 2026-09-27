extends RefCounted

## Molehill's cast, drawn as builder shapes and shared by the game
## (arcade/molehill_screen.gd) and its card on the Arcade tab. Every sprite
## is built in pixels for a field unit of `u` pixels, standing on the hole's
## mouth at the origin (y 0), up being -y, so the screen raises and lowers a
## mole by the draw transform and never rebuilds one to move it. Meshes are
## cached per look and scale.
##
## The cast: a velvet mole, a broad head on shoulders with a long pink
## snout, buck teeth and shovel hands clawed on the rim; a golden one in a
## tilted crown; a mole with a painted flowerpot pulled down to the brow
## (cracked after the first whack); and the rabbit who is only visiting,
## round-cheeked, one ear bent, a carrot in both paws. Each has a dizzy
## look for after a whack. Outlines are traced halves mirrored (`_sil`) and
## cel-shaded by an inset copy (`_inset`), never a single ellipse.
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
const CLAW := Color("f7eedd")
const CLAW_DEEP := Color("cdbb9f")
const TONGUE := Color("e9707e")
const TOOTH := Color("fffdf6")
const CROWN := Color("ffd65c")
const CROWN_DEEP := Color("c98f22")
const PAW := Color("f2bfb0")
const PAW_DEEP := Color("d99a8c")
const GOLD := Color("f2c14e")
const GOLD_DEEP := Color("d49a2c")
const GOLD_BELLY := Color("fbe3a0")
const POT := Color("d9774a")
const POT_DEEP := Color("b85c34")
const POT_RIM := Color("e8946a")
const POT_BAND := Color("f3e2c4")
const SPROUT := Color("7fa84a")
const GRASS := Color("6f9c46")
const GRASS_HI := Color("8dba58")
const CARROT := Color("f08a3c")
const CARROT_DEEP := Color("d0692a")
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

## `gaze` turns the eyes -1 (left), 0 or 1 (right); `blink` shuts them.
## Both are baked into the key, three gazes and two lids a look.
static func mesh(look: int, u: float, gaze := 0, blink := false) -> ArrayMesh:
	var key := "m%d/%.2f/%d%s" % [look, u, gaze, "b" if blink else ""]
	if _cache.has(key):
		return _cache[key]
	if _cache.size() > 200:
		_cache.clear()
	var b := Face.Builder.new()
	match look:
		Look.MOLE:
			mole(b, u, FUR, FUR_DEEP, BELLY, "blink" if blink else "open", gaze)
		Look.MOLE_DIZZY:
			mole(b, u, FUR, FUR_DEEP, BELLY, "dizzy")
		Look.MOLE_TEASE:
			mole(b, u, FUR, FUR_DEEP, BELLY, "tease")
		Look.GOLD:
			mole(b, u, GOLD, GOLD_DEEP, GOLD_BELLY, "blink" if blink else "open", gaze)
			_shine(b, u)
			_crown(b, u, false)
		Look.GOLD_DIZZY:
			mole(b, u, GOLD, GOLD_DEEP, GOLD_BELLY, "dizzy")
			_crown(b, u, true)
		Look.POT:
			mole(b, u, FUR, FUR_DEEP, BELLY, "blink" if blink else "stern", gaze)
			pot(b, u, false)
		Look.POT_CRACKED:
			mole(b, u, FUR, FUR_DEEP, BELLY, "worried")
			pot(b, u, true)
		Look.POT_DIZZY:
			mole(b, u, FUR, FUR_DEEP, BELLY, "dizzy")
		Look.BUNNY:
			bunny(b, u, false, gaze, blink)
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
	# the hole's back wall, lit a little where the sun gets in
	var wall := PackedVector2Array()
	for i in range(3, 16):
		var a := PI + PI * i / 18.0
		wall.append(at + Vector2(cos(a) * (HOLE_R.x - 2.5) * s, (sin(a) * (HOLE_R.y - 2.0) + 0.6) * s))
	b.stroke(wall, 1.6 * s, HOLE_RIM.lightened(0.12))
	# clods thrown up round the back of the rim
	for c in [Vector2(-31, -6), Vector2(-20, -12), Vector2(-4, -13.5), Vector2(13, -12.5), Vector2(27, -8), Vector2(36, -2)]:
		var r := 3.4 + fmod(absf(c.x) * 0.37, 1.6)
		b.ellipse(at + (c + Vector2(0.4, 0.8)) * s, r * s, r * 0.72 * s, SOIL_DEEP)
		b.ellipse(at + c * s, r * s, r * 0.7 * s, SOIL_HI if int(c.x) % 2 == 0 else SOIL)
	# grass growing up round the mound's back
	for side in [-1.0, 1.0]:
		tuft(b, at + Vector2(side * (MOUND.x - 2.0), 1.0) * s, s * 1.1, side)

## A tuft of three blades, leaning `lean` (-1 left, 1 right), its foot at
## `at`; blades in two greens.
static func tuft(b: Face.Builder, at: Vector2, s: float, lean: float) -> void:
	for k in 3:
		var dx := (k - 1) * 2.4
		var h := 9.0 + (4.0 if k == 1 else 0.0)
		var foot := at + Vector2(dx, 0) * s
		var tip := at + Vector2(dx + lean * (2.0 + k * 1.4), -h) * s
		var ctrl := at + Vector2(dx + lean * 0.4, -h * 0.6) * s
		b.stroke(Face.Builder.bezier2(foot, ctrl, tip, 6), (1.8 - k * 0.2) * s, GRASS if k != 1 else GRASS_HI)

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
	# crumbs on the lip's crest, and grass at its foot
	for p in [Vector2(-24, 7.5), Vector2(-11, 11.5), Vector2(9, 11.8), Vector2(22, 8.2)]:
		b.ellipse(at + (p + Vector2(0.3, 0.7)) * s, 2.8 * s, 1.9 * s, SOIL_DEEP)
		b.ellipse(at + p * s, 2.6 * s, 1.7 * s, SOIL_HI)
	tuft(b, at + Vector2(-38, 17) * s, s, -1.0)
	tuft(b, at + Vector2(31, 21) * s, s * 0.9, 1.0)
	tuft(b, at + Vector2(-4, 24.5) * s, s * 0.8, 0.4)

## A closed outline mirrored about x 0 from its right half: `segs` is a
## chain of cubic segments [p0, c0, c1, p1, c0, c1, p2, ...] in units,
## running from the foot on the right up to the crown on the centreline.
static func _sil(segs: Array, s: float) -> PackedVector2Array:
	var right := PackedVector2Array()
	var k := 0
	while k + 3 < segs.size():
		right.append_array(Face.Builder.bezier3(segs[k] * s, segs[k + 1] * s, segs[k + 2] * s, segs[k + 3] * s, 10))
		k += 3
	right.append(segs[segs.size() - 1] * s)
	var pts := right.duplicate()
	for i in range(right.size() - 2, -1, -1):
		if absf(right[i].x) > 0.01:
			pts.append(Vector2(-right[i].x, right[i].y))
	return pts

## `pts` scaled about `about` and shifted: the inset a cel shade leaves.
static func _inset(pts: PackedVector2Array, about: Vector2, k: float, shift: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(about + (p - about) * k + shift)
	return out

## A tapered, curling spike from `foot` (its base `w` wide) to `tip`, bowed
## by `bow` (a fraction of its length, + to its right): a claw or a tuft.
static func _spike(b: Face.Builder, foot: Vector2, tip: Vector2, w: float, bow: float, col: Color) -> void:
	var d := tip - foot
	var n := d.orthogonal().normalized()
	var mid := foot + d * 0.5 + n * d.length() * bow
	var pts := PackedVector2Array()
	pts.append_array(Face.Builder.bezier2(foot + n * w * 0.5, mid + n * w * 0.3, tip, 7))
	pts.append_array(Face.Builder.bezier2(tip, mid - n * w * 0.3, foot - n * w * 0.5, 7))
	pts.append(foot - n * w * 0.5)
	b.polygon(pts, col)

## The mole's outline: a broad shouldered body, a pinch at the neck and a
## wide head sloping to the crown, standing a little below the mouth.
const MOLE_SIL := [
	Vector2(22.0, 8.0), Vector2(23.0, -2.0), Vector2(25.0, -11.0), Vector2(22.5, -18.0),
	Vector2(21.4, -21.2), Vector2(19.2, -22.8), Vector2(19.2, -25.5),
	Vector2(19.2, -28.5), Vector2(21.6, -31.0), Vector2(21.0, -36.0),
	Vector2(20.2, -43.5), Vector2(16.5, -50.5), Vector2(10.5, -53.6),
	Vector2(6.5, -55.4), Vector2(3.0, -56.0), Vector2(0.0, -56.0),
]

## A mole standing in the hole: a velvet body shouldered under a broad head,
## a cel shade down its right, a cream bib, a long pink snout with a bulb of
## a nose, buck teeth, bead eyes in soft dark patches, and big shovel hands
## with five claws spread on the rim. `face` is "open", "blink", "dizzy"
## (spiral eyes, tongue), "tease" (a wink and a tongue), "worried" (a bead
## of sweat) or "stern" (lids down, the potted mole's).
static func mole(b: Face.Builder, u: float, fur: Color, deep: Color, belly: Color, face: String, gaze := 0) -> void:
	var s := u
	var sil := _sil(MOLE_SIL, s)
	b.polygon(sil, deep)
	var lit := _inset(sil, Vector2(0, -24.0 * s), 0.92, Vector2(-1.8, -0.9) * s)
	b.polygon(lit, fur)
	# a rim of light round the upper left, from the cheek to the crown
	var rim := PackedVector2Array()
	for p in lit:
		if p.x < -1.0 * s and p.y < -27.0 * s and p.y > -55.0 * s:
			rim.append(p * 0.965 + Vector2(0, -24.0 * s) * 0.035)
	if rim.size() > 2:
		b.stroke(rim, 1.3 * s, Color(fur.lightened(0.35), 0.55))
	# the bib, a cream shield from the neck to the rim
	b.polygon(_sil([Vector2(10.5, 8.0), Vector2(11.5, -2.0), Vector2(11.0, -12.0), Vector2(7.0, -18.0),
		Vector2(4.5, -21.5), Vector2(2.0, -21.8), Vector2(0.0, -20.5)], s), belly)
	# fur: the hole's shadow at the mouth, strokes of nap, flicks at the cheeks
	b.ellipse(Vector2(0, -1.0 * s), 21.0 * s, 6.0 * s, Color(0.12, 0.07, 0.04, 0.24))
	for p in [Vector2(-15, -14), Vector2(-17, -8), Vector2(15.5, -13), Vector2(-4, -12), Vector2(5, -8), Vector2(12, -45), Vector2(-9, -48)]:
		var c: Vector2 = p * s
		b.stroke(Face.Builder.bezier2(c + Vector2(-1.6, -1.2) * s, c + Vector2(0, 0.8) * s, c + Vector2(1.6, -1.2) * s, 6), 0.7 * s, Color(deep, 0.55))
	for side in [-1.0, 1.0]:
		for k in 3:
			var foot := Vector2(side * (19.0 - k * 0.4), -29.0 - k * 3.2) * s
			var tip := foot + Vector2(side * (4.2 - k * 0.8), 1.4 + k * 0.3) * s
			_spike(b, foot, tip, 2.6 * s, 0.1 * side, fur if side < 0 else deep)
		_spike(b, Vector2(side * 21.0, -16.5) * s, Vector2(side * 24.5, -14.0) * s, 2.4 * s, 0.1 * side, fur if side < 0 else deep)
	# the crown's tuft
	for k in 3:
		var foot := Vector2((k - 1) * 3.6, -54.0) * s
		var tip := Vector2((k - 1) * 6.0 + 1.0, -63.5 + absf(k - 1) * 3.0) * s
		_spike(b, foot, tip, (3.6 if k == 1 else 3.0) * s, 0.14 * (k - 1 if k != 1 else 0.6), deep)
		_spike(b, foot + Vector2(-0.3, 0.6) * s, tip + Vector2(-0.6, 1.4) * s, (2.2 if k == 1 else 1.8) * s, 0.14 * (k - 1 if k != 1 else 0.6), fur)
	# the shovel hands on the rim: a furred wrist, a broad pink palm and five
	# pale claws spread outward
	for side in [-1.0, 1.0]:
		var c := Vector2(side * 17.5, -4.5) * s
		b.ellipse(Vector2(side * 16.0, -10.0) * s, 6.8 * s, 6.0 * s, deep)
		b.ellipse(Vector2(side * 15.6, -10.6) * s, 6.0 * s, 5.2 * s, fur)
		var palm := Transform2D(side * 0.22, c)
		b.fan(palm * Face.Builder.ring(Vector2(0, 1.0 * s), 8.2 * s, 5.8 * s), PAW_DEEP)
		b.fan(palm * Face.Builder.ring(Vector2(0, 0), 7.6 * s, 5.2 * s), PAW)
		b.fan(palm * Face.Builder.ring(Vector2(side * -1.5 * s, -1.6 * s), 3.6 * s, 1.6 * s), Color(1, 1, 1, 0.3))
		for k in 5:
			var a: float = -1.15 + k * 0.4
			var dir := Vector2(cos(a) * side, sin(a))
			var foot := c + Vector2(dir.x * 6.4, dir.y * 4.4) * s
			var reach := (8.6 - absf(k - 2) * 1.1) * s
			var tip := foot + dir * reach + Vector2(0, 1.6) * s
			_spike(b, foot, tip + Vector2(0.3, 0.6) * s, 3.4 * s, -0.14 * side, CLAW_DEEP)
			_spike(b, foot, tip, 2.8 * s, -0.14 * side, CLAW)
			b.stroke(PackedVector2Array([foot.lerp(tip, 0.15), foot.lerp(tip, 0.6)]), 0.5 * s, Color(1, 1, 1, 0.6))
		for k in 2:
			var crease := c + Vector2(side * (1.0 + k * 2.6), -0.6) * s
			b.stroke(Face.Builder.bezier2(crease + Vector2(0, -2.0) * s, crease + Vector2(side * 0.8, 0), crease + Vector2(0, 2.0) * s, 6), 0.5 * s, PAW_DEEP)
	_mole_face(b, s, fur, deep, face, gaze)

## The mole's face: eye patches and eyes, brows, the snout and nose, the
## whisker pads and whiskers, the mouth and buck teeth, the blush.
static func _mole_face(b: Face.Builder, s: float, fur: Color, deep: Color, face: String, gaze: int) -> void:
	var eye_y := -38.5 * s
	var gap := 7.2 * s
	for side in [-1.0, 1.0]:
		b.ellipse(Vector2(side * gap, eye_y + 0.2 * s), 4.4 * s, 3.8 * s, Color(deep.darkened(0.2), 0.45))
		b.ellipse(Vector2(side * 12.8, -30.0) * s, 3.3 * s, 1.9 * s, Color(Pal.CHEEK, 0.7))
	match face:
		"dizzy":
			for side in [-1.0, 1.0]:
				var c := Vector2(side * gap, eye_y)
				var sp := PackedVector2Array()
				for k in 14:
					var a: float = k * 0.85 * side
					sp.append(c + Vector2.from_angle(a) * (0.4 + k * 0.22) * s)
				b.stroke(sp, 0.9 * s, INK)
		"tease":
			b.stroke(Face.Builder.bezier2(Vector2(-gap - 2.4 * s, eye_y + 0.4 * s), Vector2(-gap, eye_y - 2.2 * s), Vector2(-gap + 2.4 * s, eye_y + 0.4 * s), 8), 1.2 * s, INK)
			_bead(b, Vector2(gap, eye_y), s, 0)
			_brow(b, Vector2(gap, eye_y), s, 1.0, -0.5, deep)
		"blink":
			for side in [-1.0, 1.0]:
				var c := Vector2(side * gap, eye_y)
				b.stroke(Face.Builder.bezier2(c + Vector2(-2.3 * s, -0.3 * s), c + Vector2(0, 1.7 * s), c + Vector2(2.3 * s, -0.3 * s), 8), 1.1 * s, INK)
				_brow(b, c, s, side, 0.0, deep)
		"worried":
			for side in [-1.0, 1.0]:
				var c := Vector2(side * gap, eye_y)
				_bead(b, c, s, 0)
				_brow(b, c, s, side, 1.0, deep)
			var drop := Vector2(17.5, -41.0) * s
			b.fan(PackedVector2Array([drop + Vector2(0, -3.6) * s, drop + Vector2(1.7, 0.2) * s, drop + Vector2(0, 1.9) * s, drop + Vector2(-1.7, 0.2) * s]), Color("a9d6f0"))
			b.ellipse(drop + Vector2(0, 0.3) * s, 1.7 * s, 1.6 * s, Color("a9d6f0"))
			b.disc(drop + Vector2(-0.6, -0.2) * s, 0.5 * s, Color.WHITE)
		"stern":
			for side in [-1.0, 1.0]:
				var c := Vector2(side * gap + gaze * 1.2 * s, eye_y)
				_bead(b, c, s, 0)
				# a lid drawn down over the top of the eye, slanting inward
				var lid := PackedVector2Array([c + Vector2(-2.8, -3.2) * s, c + Vector2(2.8, -3.2) * s,
					c + Vector2(2.8, -1.2 - side * 0.8) * s, c + Vector2(-2.8, -1.2 + side * 0.8) * s])
				b.fan(lid, fur)
				b.stroke(PackedVector2Array([lid[3], lid[2]]), 0.9 * s, INK)
		_:
			for side in [-1.0, 1.0]:
				var c := Vector2(side * gap, eye_y)
				_bead(b, c, s, gaze)
				_brow(b, c, s, side, 0.25, deep)
	# the snout, long and tapering, pink toward the tip, with a crease or two
	var snout_col := fur.lerp(PAW, 0.45)
	b.fan(PackedVector2Array([Vector2(-2.6, -39.5) * s, Vector2(2.6, -39.5) * s, Vector2(4.6, -30.5) * s, Vector2(3.4, -27.0) * s,
		Vector2(-3.4, -27.0) * s, Vector2(-4.6, -30.5) * s]), snout_col)
	b.ellipse(Vector2(0, -39.4) * s, 2.6 * s, 1.4 * s, snout_col)
	b.fan(PackedVector2Array([Vector2(1.2, -39.0) * s, Vector2(2.6, -39.5) * s, Vector2(4.6, -30.5) * s, Vector2(3.4, -27.0) * s, Vector2(2.2, -28.0) * s]), Color(deep, 0.2))
	for k in 2:
		var y := (-34.8 + k * 2.6) * s
		b.stroke(Face.Builder.bezier2(Vector2(-2.4 * s - k * 0.4 * s, y), Vector2(0, y + 1.0 * s), Vector2(2.4 * s + k * 0.4 * s, y), 6), 0.55 * s, Color(deep, 0.6))
	# the whisker pads either side of the nose, dotted, and the whiskers
	for side in [-1.0, 1.0]:
		var pad := Vector2(side * 4.4, -24.4) * s
		b.ellipse(pad, 4.2 * s, 3.0 * s, fur.lightened(0.18))
		for k in 3:
			b.disc(pad + Vector2(side * (0.4 + k * 1.2), -0.6 + (k % 2) * 1.0) * s, 0.35 * s, Color(INK, 0.5))
		for k in 3:
			var from := pad + Vector2(side * 2.8, (k - 1) * 0.9) * s
			var to := Vector2(side * (18.5 - absf(k - 1) * 1.5), (-28.0 + k * 3.4)) * s
			b.stroke(Face.Builder.bezier2(from, from.lerp(to, 0.5) + Vector2(0, -1.2) * s, to, 6), 0.5 * s, Color(INK, 0.5))
	# the nose, a pink bulb with nostrils
	b.ellipse(Vector2(0, -26.6) * s, 5.8 * s, 4.1 * s, NOSE.darkened(0.14))
	b.ellipse(Vector2(-0.3, -27.1) * s, 5.4 * s, 3.7 * s, NOSE)
	b.ellipse(Vector2(-1.8, -28.4) * s, 1.8 * s, 1.0 * s, Color(1, 1, 1, 0.65))
	for side in [-1.0, 1.0]:
		b.ellipse(Vector2(side * 1.9, -25.8) * s, 0.9 * s, 0.65 * s, NOSE.darkened(0.45))
	# the mouth under the pads, and the buck teeth
	var my := -21.2 * s
	if face == "dizzy" or face == "tease":
		b.ellipse(Vector2(0, my + 0.6 * s), 3.2 * s, 2.4 * s, Color("5a2f33"))
		var tx := 1.6 if face == "tease" else 0.0
		b.fan(Face.Builder.round_rect(Vector2(tx - 2.3, -20.6) * s, Vector2(4.6, 6.2) * s, 2.3 * s), TONGUE)
		b.stroke(PackedVector2Array([Vector2(tx, -19.8) * s, Vector2(tx, -16.4) * s]), 0.5 * s, TONGUE.darkened(0.2))
	else:
		b.stroke(Face.Builder.bezier2(Vector2(-3.4 * s, my - 0.6 * s), Vector2(-1.7 * s, my + 1.2 * s), Vector2(0, my - 0.2 * s), 6), 0.75 * s, INK)
		b.stroke(Face.Builder.bezier2(Vector2(0, my - 0.2 * s), Vector2(1.7 * s, my + 1.2 * s), Vector2(3.4 * s, my - 0.6 * s), 6), 0.75 * s, INK)
	for k in 2:
		var x := (-1.95 + k * 2.05) * s
		b.fan(Face.Builder.round_rect(Vector2(x, my - 0.1 * s), Vector2(1.85, 2.7) * s, 0.5 * s), TOOTH)
	b.stroke(PackedVector2Array([Vector2(0, my + 0.1 * s), Vector2(0, my + 2.4 * s)]), 0.35 * s, Color(INK, 0.35))

## A bead of an eye with its catch-light, looking `gaze`.
static func _bead(b: Face.Builder, c: Vector2, s: float, gaze: int) -> void:
	var e := c + Vector2(gaze * 1.2 * s, 0)
	b.ellipse(e, 1.9 * s, 2.4 * s, INK)
	b.disc(e + Vector2(-0.6, -0.9) * s, 0.75 * s, Color.WHITE)
	b.disc(e + Vector2(0.7, 0.9) * s, 0.35 * s, Color(1, 1, 1, 0.6))

## A short brow over the eye at `c` on `side`: `lift` 1 raises its inner
## end (worried), -1 lowers it (up to something).
static func _brow(b: Face.Builder, c: Vector2, s: float, side: float, lift: float, deep: Color) -> void:
	var inner := c + Vector2(-side * 1.8, -4.8 - lift * 1.1) * s
	var outer := c + Vector2(side * 2.2, -5.0 + lift * 0.5) * s
	b.stroke(Face.Builder.bezier2(inner, (inner + outer) * 0.5 + Vector2(0, -0.9) * s, outer, 6), 0.9 * s, Color(deep.darkened(0.35), 0.8))

## A golden mole's glints: streaks of sheen down the fur and sparkles.
static func _shine(b: Face.Builder, u: float) -> void:
	var s := u
	b.stroke(Face.Builder.bezier2(Vector2(-15.5, -44.0) * s, Vector2(-18.0, -36.0) * s, Vector2(-16.0, -30.0) * s, 8), 1.6 * s, Color(1, 1, 1, 0.45))
	b.stroke(Face.Builder.bezier2(Vector2(-19.0, -17.0) * s, Vector2(-20.5, -11.0) * s, Vector2(-19.5, -6.0) * s, 8), 1.3 * s, Color(1, 1, 1, 0.35))
	for p in [Vector2(-23, -50), Vector2(22, -42), Vector2(-25, -24)]:
		var c: Vector2 = p * s
		var r := (4.4 if p.x == -23 else 3.0) * s
		b.fan(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.25, -r * 0.25), c + Vector2(r, 0), c + Vector2(r * 0.25, r * 0.25),
			c + Vector2(0, r), c + Vector2(-r * 0.25, r * 0.25), c + Vector2(-r, 0), c + Vector2(-r * 0.25, -r * 0.25)]), Color("fff6c9"))

## A little crown worn tilted on the golden mole's crown; knocked, it slips
## over one ear.
static func _crown(b: Face.Builder, u: float, knocked: bool) -> void:
	var s := u
	var xf := Transform2D(0.75, Vector2(13.0, -51.0) * s) if knocked else Transform2D(0.22, Vector2(4.5, -56.0) * s)
	var band := PackedVector2Array([Vector2(-8.5, 0), Vector2(8.5, 0), Vector2(9.2, -4.0), Vector2(-9.2, -4.0)])
	var peaks := PackedVector2Array([Vector2(-9.2, -3.5), Vector2(9.2, -3.5), Vector2(10.4, -11.5), Vector2(5.0, -6.5), Vector2(0, -13.0),
		Vector2(-5.0, -6.5), Vector2(-10.4, -11.5)])
	var shift := func(pts: PackedVector2Array, d: Vector2) -> PackedVector2Array:
		var out := PackedVector2Array()
		for p in pts:
			out.append(xf * ((p + d) * s))
		return out
	b.polygon(shift.call(peaks, Vector2(0.6, 0.8)), CROWN_DEEP)
	b.polygon(shift.call(peaks, Vector2.ZERO), CROWN)
	b.fan(shift.call(band, Vector2(0.4, 0.6)), CROWN_DEEP)
	b.fan(shift.call(band, Vector2.ZERO), CROWN.lightened(0.15))
	for p in [Vector2(-10.4, -11.5), Vector2(0, -13.0), Vector2(10.4, -11.5)]:
		b.disc(xf * (p * s), 1.3 * s, CROWN.lightened(0.35))
	for k in 3:
		var at: Vector2 = xf * (Vector2((k - 1) * 5.2, -2.0) * s)
		b.disc(at, 1.35 * s, [Color("e0657a"), Color("6fb6e0"), Color("e0657a")][k])
		b.disc(at + Vector2(-0.4, -0.4) * s, 0.45 * s, Color(1, 1, 1, 0.7))
	b.stroke(PackedVector2Array([xf * (Vector2(-7.0, -5.5) * s), xf * (Vector2(-5.0, -9.0) * s)]), 0.8 * s, Color(1, 1, 1, 0.5))

## A terracotta flowerpot worn upside down, pulled down to the brow, a band
## painted round it and a sprout still growing out of its drainage hole;
## cracked, it has a chip out of the rim and two cracks.
static func pot(b: Face.Builder, u: float, cracked: bool) -> void:
	var s := u
	var rim_y := -47.0 * s
	var top_y := -72.0 * s
	var at_y := func(y: float) -> float: return lerpf(19.5, 13.0, (y - rim_y) / (top_y - rim_y)) * s
	b.ellipse(Vector2(0, rim_y + 3.0 * s), 20.0 * s, 3.2 * s, Color(0.1, 0.05, 0.02, 0.25))
	var body := PackedVector2Array([Vector2(-19.5 * s, rim_y), Vector2(19.5 * s, rim_y), Vector2(13.0 * s, top_y), Vector2(-13.0 * s, top_y)])
	b.fan(body, POT)
	b.fan(PackedVector2Array([Vector2(5.0 * s, rim_y), Vector2(19.5 * s, rim_y), Vector2(13.0 * s, top_y), Vector2(7.5 * s, top_y)]), POT_DEEP)
	# the painted band: a cream stripe with dots of glaze
	var y0 := -58.5 * s
	var y1 := -54.0 * s
	b.fan(PackedVector2Array([Vector2(-at_y.call(y1), y1), Vector2(at_y.call(y1), y1), Vector2(at_y.call(y0), y0), Vector2(-at_y.call(y0), y0)]), POT_BAND)
	b.fan(PackedVector2Array([Vector2(5.8 * s, y1), Vector2(at_y.call(y1), y1), Vector2(at_y.call(y0), y0), Vector2(7.0 * s, y0)]), POT_BAND.darkened(0.12))
	for k in 5:
		var x := (-11.0 + k * 5.5) * s
		b.disc(Vector2(x, (y0 + y1) * 0.5), 1.1 * s, POT_DEEP if k < 3 else POT_DEEP.darkened(0.15))
	for k in 6:
		var x := (-13.0 + k * 5.2) * s
		b.fan(PackedVector2Array([Vector2(x - 1.4 * s, y0), Vector2(x + 1.4 * s, y0), Vector2(x, y0 - 2.2 * s)]), POT_BAND)
	# the rim, lit along its lip
	b.fan(Face.Builder.round_rect(Vector2(-22.5 * s, rim_y - 3.0 * s), Vector2(45.0 * s, 8.5 * s), 3.0 * s), POT_RIM)
	b.fan(PackedVector2Array([Vector2(8.0 * s, rim_y - 3.0 * s), Vector2(22.0 * s, rim_y - 3.0 * s), Vector2(22.0 * s, rim_y + 5.5 * s), Vector2(8.0 * s, rim_y + 5.5 * s)]), POT_DEEP.lerp(POT_RIM, 0.4))
	b.stroke(PackedVector2Array([Vector2(-20.0 * s, rim_y - 1.6 * s), Vector2(6.0 * s, rim_y - 1.6 * s)]), 1.1 * s, Color(1, 1, 1, 0.3))
	b.ellipse(Vector2(-8.0 * s, -64.5 * s), 1.8 * s, 3.8 * s, Color(1, 1, 1, 0.2))
	# the sprout through the hole in its bottom
	var stem := Face.Builder.bezier2(Vector2(0, top_y), Vector2(1.5 * s, top_y - 5.0 * s), Vector2(0, top_y - 9.0 * s), 8)
	b.stroke(stem, 1.4 * s, SPROUT)
	for side in [-1.0, 1.0]:
		var leaf := Transform2D(side * 0.6, Vector2(side * 3.4 * s, top_y - 8.5 * s))
		b.fan(leaf * Face.Builder.ring(Vector2.ZERO, 3.8 * s, 1.9 * s), SPROUT.lightened(0.1 if side < 0 else 0.0))
		b.stroke(PackedVector2Array([leaf * Vector2(-2.6 * s, 0), leaf * Vector2(2.6 * s, 0)]), 0.4 * s, SPROUT.darkened(0.2))
	if cracked:
		b.fan(PackedVector2Array([Vector2(-15.0 * s, rim_y + 5.6 * s), Vector2(-6.0 * s, rim_y + 5.6 * s), Vector2(-10.0 * s, rim_y + 0.5 * s)]), FUR_DEEP)
		b.stroke(PackedVector2Array([Vector2(-10.0 * s, rim_y + 3.0 * s), Vector2(-7.0 * s, rim_y - 6.0 * s), Vector2(-9.0 * s, rim_y - 12.0 * s), Vector2(-4.0 * s, top_y + 2.0 * s)]), 1.0 * s, INK)
		b.stroke(PackedVector2Array([Vector2(12.0 * s, rim_y - 2.0 * s), Vector2(8.0 * s, rim_y - 9.0 * s), Vector2(10.0 * s, rim_y - 15.0 * s)]), 0.9 * s, INK)

## The rabbit's head: fluffy cheeks wider than the crown, a round chin.
const BUNNY_HEAD := [
	Vector2(0.0, -22.5), Vector2(7.0, -22.5), Vector2(14.0, -24.0), Vector2(18.0, -28.5),
	Vector2(21.5, -32.0), Vector2(20.5, -38.0), Vector2(17.0, -44.0),
	Vector2(14.0, -49.0), Vector2(7.5, -52.0), Vector2(0.0, -52.0),
]
## Her body under it, a soft pear down into the hole.
const BUNNY_BODY := [
	Vector2(18.0, 8.0), Vector2(19.0, -2.0), Vector2(18.5, -12.0), Vector2(14.5, -20.0),
	Vector2(11.0, -26.0), Vector2(5.0, -28.0), Vector2(0.0, -28.0),
]

## The rabbit, who only came to look: a round-cheeked head on a soft body,
## a tuft on her brow, one tall ear and one bent at the tip, big glossy
## eyes, a pink button of a nose over two puffs, a fluffy bib, and the
## carrot she brought held in both paws. Dizzy, her ears flop, the carrot
## is gone and her paws fall to the rim.
static func bunny(b: Face.Builder, u: float, dizzy: bool, gaze := 0, blink := false) -> void:
	var s := u
	var white := Color("fffaf2")
	# the ears behind the head
	for side in [-1.0, 1.0]:
		var base := Vector2(side * 8.0, -47.0) * s
		if dizzy:
			var xf := Transform2D(side * 1.25, base)
			b.fan(xf * Face.Builder.ring(Vector2(0, -16.0 * s), 6.2 * s, 16.5 * s), BUNNY_DEEP)
			b.fan(xf * Face.Builder.ring(Vector2(0, -16.5 * s), 5.6 * s, 16.0 * s), BUNNY)
			b.fan(xf * Face.Builder.ring(Vector2(0, -15.0 * s), 2.9 * s, 11.5 * s), EAR_PINK)
		elif side < 0:
			var xf := Transform2D(-0.14, base)
			b.fan(xf * Face.Builder.ring(Vector2(0, -17.5 * s), 6.4 * s, 18.0 * s), BUNNY_DEEP)
			b.fan(xf * Face.Builder.ring(Vector2(-0.5 * s, -18.0 * s), 5.7 * s, 17.4 * s), BUNNY)
			b.fan(xf * Face.Builder.ring(Vector2(0.2 * s, -16.5 * s), 3.0 * s, 12.5 * s), EAR_PINK)
			b.stroke(PackedVector2Array([xf * Vector2(0.2 * s, -8.0 * s), xf * Vector2(0.2 * s, -24.0 * s)]), 0.6 * s, EAR_PINK.darkened(0.12))
		else:
			# the right ear stands to its knee and flops over there
			var xf := Transform2D(0.18, base)
			var knee := Vector2(0, -22.0 * s)
			var tip := xf * Transform2D(1.9, knee)
			b.fan(xf * Face.Builder.ring(Vector2(0, -11.5 * s), 6.4 * s, 12.5 * s), BUNNY_DEEP)
			b.fan(xf * Face.Builder.ring(Vector2(-0.5 * s, -12.0 * s), 5.7 * s, 12.0 * s), BUNNY)
			b.fan(xf * Face.Builder.ring(Vector2(0.2 * s, -11.0 * s), 3.0 * s, 8.5 * s), EAR_PINK)
			b.fan(tip * Face.Builder.ring(Vector2(0, -7.5 * s), 6.0 * s, 9.5 * s), BUNNY_DEEP)
			b.fan(tip * Face.Builder.ring(Vector2(0.3 * s, -7.5 * s), 5.4 * s, 9.0 * s), BUNNY)
			b.ellipse(xf * knee, 5.6 * s, 3.2 * s, BUNNY)
	# the body, shaded down its right
	var body := _sil(BUNNY_BODY, s)
	b.polygon(body, BUNNY_DEEP)
	b.polygon(_inset(body, Vector2(0, -10.0 * s), 0.93, Vector2(-1.6, -0.6) * s), BUNNY)
	b.ellipse(Vector2(0, -1.0 * s), 19.0 * s, 5.5 * s, Color(0.12, 0.07, 0.04, 0.18))
	# the fluffy bib, scalloped at the neck
	for k in 3:
		b.ellipse(Vector2((k - 1) * 5.0, -21.0 + absf(k - 1) * 1.6) * s, 5.0 * s, 4.2 * s, white)
	b.ellipse(Vector2(0, -12.0 * s), 11.0 * s, 10.0 * s, white)
	# the head, cheeks tufted, shaded down its right
	var head := _sil(BUNNY_HEAD, s)
	b.polygon(head, BUNNY_DEEP)
	var lit := _inset(head, Vector2(0, -37.0 * s), 0.94, Vector2(-1.4, -0.7) * s)
	b.polygon(lit, BUNNY)
	for side in [-1.0, 1.0]:
		for k in 3:
			var foot := Vector2(side * (19.5 - k * 0.6), -31.5 + k * 2.8) * s
			_spike(b, foot, foot + Vector2(side * (4.0 - k * 0.8), 2.0) * s, 3.0 * s, 0.12 * side, BUNNY if side < 0 else BUNNY_DEEP)
	# the tuft on her brow
	for k in 3:
		var foot := Vector2((k - 1) * 3.0, -50.5) * s
		_spike(b, foot, foot + Vector2((k - 1) * 2.6 + 1.2, -6.0 + absf(k - 1) * 1.6) * s, 3.0 * s, -0.2 if k != 0 else 0.2, BUNNY)
	# eyes, big and glossy, with a lash at the outer corner
	var eye_y := -38.0 * s
	for side in [-1.0, 1.0]:
		var c := Vector2(side * 8.2 * s, eye_y)
		if dizzy:
			b.stroke(PackedVector2Array([c + Vector2(-2.3, -2.3) * s, c + Vector2(2.3, 2.3) * s]), 1.1 * s, INK)
			b.stroke(PackedVector2Array([c + Vector2(-2.3, 2.3) * s, c + Vector2(2.3, -2.3) * s]), 1.1 * s, INK)
		elif blink:
			b.stroke(Face.Builder.bezier2(c + Vector2(-3.0 * s, -0.4 * s), c + Vector2(0, 2.2 * s), c + Vector2(3.0 * s, -0.4 * s), 8), 1.1 * s, INK)
			b.stroke(PackedVector2Array([c + Vector2(side * 2.8, -0.2) * s, c + Vector2(side * 4.2, -1.4) * s]), 0.8 * s, INK)
		else:
			var e := c + Vector2(gaze * 1.3 * s, 0)
			b.ellipse(e, 3.0 * s, 3.7 * s, INK)
			b.ellipse(e + Vector2(0, 1.6) * s, 2.2 * s, 1.5 * s, Color("5b4a6a"))
			b.disc(e + Vector2(-1.0 * s, -1.3 * s), 1.2 * s, Color.WHITE)
			b.disc(e + Vector2(1.0 * s, 1.2 * s), 0.55 * s, Color(1, 1, 1, 0.75))
			b.stroke(PackedVector2Array([c + Vector2(side * 2.6, -2.2) * s, c + Vector2(side * 4.3, -3.6) * s]), 0.8 * s, INK)
		b.ellipse(Vector2(side * 13.5 * s, -30.5 * s), 3.6 * s, 2.1 * s, Color(Pal.CHEEK, 0.8))
	# the muzzle: two puffs, a button nose, a Y of a mouth and her teeth
	for side in [-1.0, 1.0]:
		b.ellipse(Vector2(side * 3.3, -28.0) * s, 3.9 * s, 3.1 * s, white)
		for k in 2:
			b.disc(Vector2(side * (2.6 + k * 1.4), -28.4 + k * 0.9) * s, 0.3 * s, Color(INK, 0.4))
	b.fan(PackedVector2Array([Vector2(-2.4 * s, -32.0 * s), Vector2(2.4 * s, -32.0 * s), Vector2(0, -29.4 * s)]), EAR_PINK.darkened(0.1))
	b.ellipse(Vector2(0, -31.6 * s), 2.4 * s, 1.1 * s, EAR_PINK.darkened(0.1))
	b.disc(Vector2(-0.8, -31.8) * s, 0.5 * s, Color(1, 1, 1, 0.7))
	b.stroke(PackedVector2Array([Vector2(0, -29.4 * s), Vector2(0, -27.4 * s)]), 0.6 * s, INK)
	if dizzy:
		b.ellipse(Vector2(0, -24.8) * s, 2.2 * s, 1.6 * s, Color("5a2f33"))
	else:
		b.fan(Face.Builder.round_rect(Vector2(-1.9, -25.6) * s, Vector2(3.8, 2.6) * s, 0.6 * s), TOOTH)
		b.stroke(PackedVector2Array([Vector2(0, -25.5) * s, Vector2(0, -23.1) * s]), 0.35 * s, Color(INK, 0.35))
	for side in [-1.0, 1.0]:
		for k in 3:
			var from := Vector2(side * 6.0, -28.5 + k * 0.8) * s
			var to := Vector2(side * (19.0 - absf(k - 1) * 1.5), -32.0 + k * 3.2) * s
			b.stroke(Face.Builder.bezier2(from, from.lerp(to, 0.5) + Vector2(0, -1.0) * s, to, 6), 0.5 * s, Color(INK, 0.4))
	if dizzy:
		for side in [-1.0, 1.0]:
			var c := Vector2(side * 14.0, -5.0) * s
			b.ellipse(c + Vector2(0, 0.8) * s, 7.8 * s, 5.2 * s, BUNNY_DEEP)
			b.ellipse(c, 7.2 * s, 4.6 * s, white)
			for k in 2:
				b.stroke(PackedVector2Array([c + Vector2((k - 0.5) * 3.2, -1.2) * s, c + Vector2((k - 0.5) * 3.2, 1.6) * s]), 0.5 * s, BUNNY_DEEP)
		return
	# the carrot she brought, held across her chest in both paws: she is
	# only visiting
	var tip := Vector2(-4.5, 2.0) * s
	var top := Vector2(8.0, -18.5) * s
	var along := (top - tip).normalized()
	var n := along.orthogonal()
	b.polygon(PackedVector2Array([tip, top + n * 5.0 * s, top + along * 1.4 * s, top - n * 5.0 * s]), CARROT)
	b.fan(PackedVector2Array([tip, top - n * 5.0 * s, top - n * 1.4 * s]), CARROT_DEEP)
	b.stroke(PackedVector2Array([tip.lerp(top, 0.2) + n * 1.2 * s, tip.lerp(top, 0.85) + n * 2.8 * s]), 0.9 * s, Color(1, 1, 1, 0.35))
	for k in 4:
		var at := tip.lerp(top, 0.22 + k * 0.19)
		b.stroke(PackedVector2Array([at - n * (0.8 + k * 0.8) * s, at + n * (0.3 + k * 0.5) * s]), 0.6 * s, CARROT_DEEP)
	for k in 3:
		var leaf := Transform2D(-0.8 + k * 0.6 + along.angle() + PI * 0.5, top + along * 1.0 * s)
		b.fan(leaf * Face.Builder.ring(Vector2(0, -5.2 * s), 1.8 * s, 5.6 * s), SPROUT if k != 1 else SPROUT.lightened(0.12))
	# her paws, one either side of it
	var grip := tip.lerp(top, 0.42)
	for side in [-1.0, 1.0]:
		var c: Vector2 = grip + n * side * 4.6 * s + along * side * -1.0 * s
		b.ellipse(c + Vector2(0.4, 0.7) * s, 3.4 * s, 2.9 * s, BUNNY_DEEP)
		b.ellipse(c, 3.1 * s, 2.6 * s, white)
		for k in 2:
			var t := c + Vector2((k - 0.5) * 1.8, 0.6) * s
			b.stroke(PackedVector2Array([t, t + Vector2(0, 1.3) * s]), 0.4 * s, BUNNY_DEEP)

## The mallet, its hand at the origin and its head up the handle at
## (0, -HEAD_AT): a turned handle and a barrel head with two iron bands.
const HEAD_AT := 50.0

static func mallet(u: float) -> ArrayMesh:
	var key := "mallet/%.2f" % u
	if _cache.has(key):
		return _cache[key]
	var b := Face.Builder.new()
	var s := u
	b.stroke(PackedVector2Array([Vector2(0, 0), Vector2(0, -HEAD_AT * s)]), 5.6 * s, WOOD_DEEP)
	b.stroke(PackedVector2Array([Vector2(-0.7 * s, -2.0 * s), Vector2(-0.7 * s, -(HEAD_AT - 4.0) * s)]), 3.6 * s, HANDLE)
	# a leather grip bound round the foot of the handle
	b.fan(Face.Builder.round_rect(Vector2(-3.6, -15.0) * s, Vector2(7.2, 14.0) * s, 2.4 * s), Color("9a4f3a"))
	for k in 4:
		var y := (-13.0 + k * 3.4) * s
		b.stroke(PackedVector2Array([Vector2(-3.4 * s, y + 1.2 * s), Vector2(3.4 * s, y - 0.6 * s)]), 0.9 * s, Color("7a3a2a"))
	b.disc(Vector2.ZERO, 4.0 * s, WOOD_DEEP)
	var head := Vector2(0, -HEAD_AT * s)
	b.fan(Face.Builder.round_rect(head - Vector2(24.0, 14.0) * s, Vector2(48.0, 28.0) * s, 7.0 * s), WOOD_DEEP)
	b.fan(Face.Builder.round_rect(head - Vector2(23.0, 13.0) * s, Vector2(46.0, 24.0) * s, 6.5 * s), WOOD)
	# grain along the barrel
	for k in 3:
		var y := (-6.0 + k * 5.5) * s
		b.stroke(Face.Builder.bezier2(head + Vector2(-17.0 * s, y), head + Vector2(-4.0 * s, y - 2.0 * s), head + Vector2(10.0 * s, y + 0.6 * s), 8), 0.8 * s, Color(WOOD_DEEP, 0.55))
	b.fan(Face.Builder.round_rect(head - Vector2(21.0, 11.0) * s, Vector2(42.0, 5.5) * s, 2.7 * s), Color(1, 1, 1, 0.22))
	for side in [-1.0, 1.0]:
		b.fan(Face.Builder.round_rect(head + Vector2(side * 15.0 - 2.8, -14.0) * s, Vector2(5.6, 28.0) * s, 1.6 * s), WOOD_BAND)
		b.fan(Face.Builder.round_rect(head + Vector2(side * 15.0 - 2.0, -12.5) * s, Vector2(1.6, 25.0) * s, 0.8 * s), Color(1, 1, 1, 0.16))
	for side in [-1.0, 1.0]:
		b.ellipse(head + Vector2(side * 23.5 * s, 0), 2.6 * s, 12.5 * s, WOOD.lightened(0.12))
	var m := b.mesh()
	_cache[key] = m
	return m
