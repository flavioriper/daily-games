extends RefCounted

## Drumbeat's drawings, as builder shapes shared by the game
## (puzzles/drumbeat2d.gd) and its card on the first screen. Every piece is
## built about the origin in pixels and cached per look and size, so the
## screen moves, squashes and turns them by the draw transform and never
## rebuilds one to move it.
##
## The cast: the notes are berries with faces -- a red one struck on the
## drum's face (don) and a blue one struck on its rim (ka), a big one of each,
## the drumroll's golden bar and the balloon. The drum is a garden drum seen
## straight on: a cream skin with a painted leaf in a lacquered rim studded
## with brass. And Tam, the frog in a festival headband, who drums along
## beside the lane.

const Pal = preload("res://core/palette.gd")
const Face = preload("res://ui/faces/face.gd")

const INK := Color("3b3028")
const CREAM := Color("fff6e6")
const DON := Color("e8604c")
const DON_DEEP := Color("c24a3a")
const DON_HI := Color("f59a84")
const KA := Color("4fa3d6")
const KA_DEEP := Color("3a82b4")
const KA_HI := Color("8cc8ec")
const ROLL := Color("f2c14e")
const ROLL_DEEP := Color("d49a2c")
const ROLL_HI := Color("fbe3a0")
const BALLOON := Color("f08aa6")
const BALLOON_DEEP := Color("d0678a")
const CHEEK := Color("f7a8a0")
const LEAF := Color("7fa84a")
const LEAF_DEEP := Color("5f8a38")
const SKIN := Color("f7ecd6")
const SKIN_DEEP := Color("e6d4b2")
const SKIN_MARK := Color("e2cfa9")
const RIM := Color("b5523b")
const RIM_DEEP := Color("8c3b2a")
const RIM_HI := Color("d4775a")
const BRASS := Color("f2c14e")
const BRASS_DEEP := Color("c98f22")
const FROG := Color("8cc261")
const FROG_DEEP := Color("6ea24a")
const FROG_BELLY := Color("e9f2c8")
const BAND := Color("f4f0e6")
const BAND_SPOT := Color("e8604c")
const STICK := Color("e9c38f")
const STICK_DEEP := Color("c69a62")
const LANTERN := Color("f59a6a")
const LANTERN_GLOW := Color("ffd27a")

## Expressions: a note's (and Tam's) face.
enum Mood { HAPPY, JOY, WORRIED, SAD }

static var _cache := {}

static func _key(parts: Array) -> String:
	return "|".join(parts.map(func(p) -> String: return str(p)))

## A note of `type` (puzzles/drumbeat_state.gd's Type) at radius `r`: an ink rim, a
## cream ring and the berry inside with a shine and a face.
static func note(type: int, r: float, mood := Mood.HAPPY) -> ArrayMesh:
	var key := _key(["note", type, roundi(r), mood])
	if _cache.has(key):
		return _cache[key]
	var don := type == 0 or type == 2
	var body := DON if don else KA
	var deep := DON_DEEP if don else KA_DEEP
	var hi := DON_HI if don else KA_HI
	var b := Face.Builder.new()
	b.disc(Vector2(0, r * 0.1), r * 1.04, Color(INK, 0.18))
	b.disc(Vector2.ZERO, r, INK)
	b.disc(Vector2.ZERO, r * 0.9, CREAM)
	var inner := r * 0.72
	b.disc(Vector2.ZERO, inner, deep)
	b.disc(Vector2(-inner * 0.06, -inner * 0.08), inner * 0.9, body)
	b.ellipse(Vector2(-inner * 0.36, -inner * 0.44), inner * 0.26, inner * 0.14, Color(hi, 0.9))
	# the berry's seeds, faint, and a leaf on top for a ka
	if not don:
		b.ellipse(Vector2(inner * 0.1, -inner * 0.92), inner * 0.28, inner * 0.12, LEAF)
	_face(b, Vector2(0, inner * 0.12), inner * 0.9, mood)
	var m := b.mesh()
	_cache[key] = m
	return m

## A face of `s` (about a head's radius) centred on `c`: two bead eyes, a
## smile and the cheeks.
static func _face(b: Face.Builder, c: Vector2, s: float, mood: int) -> void:
	var ex := s * 0.34
	var ey := -s * 0.1
	for side in [-1.0, 1.0]:
		var e := c + Vector2(side * ex, ey)
		match mood:
			Mood.JOY:
				b.stroke(Face.Builder.arc_points(e + Vector2(0, s * 0.05), s * 0.12, PI * 1.1, PI * 1.9), s * 0.07, INK)
			Mood.SAD:
				b.stroke(PackedVector2Array([e + Vector2(-s * 0.1, -s * 0.02 * side), e + Vector2(s * 0.1, s * 0.02 * side)]), s * 0.06, INK)
			_:
				b.ellipse(e, s * 0.085, s * 0.11, INK)
				b.disc(e + Vector2(-s * 0.025, -s * 0.04), s * 0.03, Color(1, 1, 1, 0.9))
		b.ellipse(c + Vector2(side * s * 0.52, s * 0.14), s * 0.13, s * 0.08, Color(CHEEK, 0.75))
	match mood:
		Mood.WORRIED:
			b.stroke(Face.Builder.arc_points(c + Vector2(0, s * 0.36), s * 0.12, PI * 1.15, PI * 1.85), s * 0.06, INK)
		Mood.SAD:
			b.stroke(Face.Builder.arc_points(c + Vector2(0, s * 0.4), s * 0.14, PI * 1.15, PI * 1.85), s * 0.06, INK)
		Mood.JOY:
			var mouth := Face.Builder.arc_points(c + Vector2(0, s * 0.12), s * 0.2, PI * 0.1, PI * 0.9)
			b.polygon(mouth, INK)
			b.ellipse(c + Vector2(0, s * 0.26), s * 0.08, s * 0.04, Color("e9707e"))
		_:
			b.stroke(Face.Builder.arc_points(c + Vector2(0, s * 0.1), s * 0.16, PI * 0.2, PI * 0.8), s * 0.06, INK)

## A drumroll's bar from x 0 to `length` at radius `r`: a golden capsule
## with an ink rim and a cream ring, its head a note-sized cap.
static func roll(length: float, r: float) -> ArrayMesh:
	var key := _key(["roll", roundi(length), roundi(r)])
	if _cache.has(key):
		return _cache[key]
	var b := Face.Builder.new()
	var L := maxf(0.0, length)
	b.polygon(Face.Builder.round_rect(Vector2(-r, -r * 0.94), Vector2(L + r * 2.0, r * 2.08), r), Color(INK, 0.18))
	b.polygon(Face.Builder.round_rect(Vector2(-r, -r), Vector2(L + r * 2.0, r * 2.0), r), INK)
	b.polygon(Face.Builder.round_rect(Vector2(-r * 0.9, -r * 0.9), Vector2(L + r * 1.8, r * 1.8), r * 0.9), CREAM)
	b.polygon(Face.Builder.round_rect(Vector2(-r * 0.72, -r * 0.72), Vector2(L + r * 1.44, r * 1.44), r * 0.72), ROLL_DEEP)
	b.polygon(Face.Builder.round_rect(Vector2(-r * 0.72, -r * 0.8), Vector2(L + r * 1.44, r * 1.36), r * 0.68), ROLL)
	b.polygon(Face.Builder.round_rect(Vector2(-r * 0.4, -r * 0.6), Vector2(L + r * 0.6, r * 0.22), r * 0.11), Color(ROLL_HI, 0.9))
	_face(b, Vector2(0, r * 0.1), r * 0.65, Mood.JOY)
	var m := b.mesh()
	_cache[key] = m
	return m

## The balloon at radius `r`, `fill` 0..1 of the way to popping (it swells
## and reddens), with its knot and string hanging down.
static func balloon(r: float, fill: float) -> ArrayMesh:
	var step := int(clampf(fill, 0.0, 1.0) * 8.0)
	var key := _key(["balloon", roundi(r), step])
	if _cache.has(key):
		return _cache[key]
	var k := step / 8.0
	var rr := r * (0.95 + 0.4 * k)
	var col := BALLOON.lerp(DON, k * 0.5)
	var b := Face.Builder.new()
	var string := PackedVector2Array()
	for i in 9:
		var t := i / 8.0
		string.append(Vector2(sin(t * 5.0) * r * 0.12, rr * 1.05 + t * r * 1.1))
	b.stroke(string, maxf(1.5, r * 0.05), Color(INK, 0.6))
	b.polygon(PackedVector2Array([Vector2(-r * 0.14, rr * 1.12), Vector2(r * 0.14, rr * 1.12), Vector2(0, rr * 0.92)]), col.darkened(0.2))
	b.ellipse(Vector2.ZERO, rr * 1.02, rr * 1.12, INK)
	b.ellipse(Vector2.ZERO, rr * 0.94, rr * 1.04, col)
	b.ellipse(Vector2(rr * 0.12, rr * 0.16), rr * 0.8, rr * 0.86, col.darkened(0.08))
	b.ellipse(Vector2(-rr * 0.08, -rr * 0.06), rr * 0.8, rr * 0.86, col)
	b.ellipse(Vector2(-rr * 0.4, -rr * 0.5), rr * 0.2, rr * 0.3, Color(1, 1, 1, 0.55))
	_face(b, Vector2(0, rr * 0.1), rr * 0.8, Mood.WORRIED if k > 0.6 else Mood.HAPPY)
	var m := b.mesh()
	_cache[key] = m
	return m

## The drum seen straight on, centred on the origin: the lacquered rim to
## `rim_r` studded with brass tacks, and the skin to `face_r` with a
## painted leaf. Cached per size.
static func drum(face_r: float, rim_r: float) -> ArrayMesh:
	var key := _key(["drum", roundi(face_r), roundi(rim_r)])
	if _cache.has(key):
		return _cache[key]
	var b := Face.Builder.new()
	b.ellipse(Vector2(0, rim_r * 0.12), rim_r * 1.04, rim_r * 1.0, Color(INK, 0.16))
	b.disc(Vector2.ZERO, rim_r, RIM_DEEP)
	b.disc(Vector2(0, -rim_r * 0.03), rim_r * 0.97, RIM)
	b.stroke(Face.Builder.arc_points(Vector2.ZERO, rim_r * 0.9, PI * 1.12, PI * 1.62), rim_r * 0.05, Color(RIM_HI, 0.8))
	# the tacks, round the rim
	var tr := (rim_r + face_r) * 0.5
	var tacks := 24
	for i in tacks:
		var p := Vector2.from_angle(TAU * i / tacks) * tr
		b.disc(p + Vector2(0, rim_r * 0.008), rim_r * 0.026, BRASS_DEEP)
		b.disc(p, rim_r * 0.022, BRASS)
		b.disc(p + Vector2(-rim_r * 0.007, -rim_r * 0.007), rim_r * 0.008, Color(1, 1, 0.9, 0.9))
	b.disc(Vector2.ZERO, face_r * 1.02, Color(INK, 0.35))
	b.disc(Vector2.ZERO, face_r, SKIN_DEEP)
	b.disc(Vector2(-face_r * 0.04, -face_r * 0.05), face_r * 0.94, SKIN)
	b.ellipse(Vector2(-face_r * 0.34, -face_r * 0.42), face_r * 0.3, face_r * 0.14, Color(1, 1, 1, 0.35))
	# the painted leaf in the middle of the skin: where a don is struck
	var leaf := PackedVector2Array()
	var n := 24
	for i in n + 1:
		var t := float(i) / n
		leaf.append(Vector2(lerpf(-1.0, 1.0, t), -sin(t * PI) * 0.42) * face_r * 0.34)
	for i in range(n - 1, 0, -1):
		var t := float(i) / n
		leaf.append(Vector2(lerpf(-1.0, 1.0, t), sin(t * PI) * 0.42) * face_r * 0.34)
	var rot := Transform2D(-0.6, Vector2.ZERO)
	for i in leaf.size():
		leaf[i] = rot * leaf[i]
	b.polygon(leaf, Color(SKIN_MARK, 0.9))
	b.stroke(PackedVector2Array([rot * Vector2(-face_r * 0.36, 0), rot * Vector2(face_r * 0.3, 0)]), face_r * 0.02, Color(SKIN_DEEP, 0.9))
	b.stroke(Face.Builder.arc_points(Vector2.ZERO, face_r * 0.8, 0.0, TAU), face_r * 0.012, Color(SKIN_MARK, 0.7), true)
	var m := b.mesh()
	_cache[key] = m
	return m

## Tam the frog at scale `s` (his head's radius), standing with his feet on
## the origin: a round body, a head with bulb eyes, a headband with a knot.
## His arms are separate (`frog_arm`) so the screen can swing them.
static func frog(s: float, mood := Mood.HAPPY, blink := false) -> ArrayMesh:
	var key := _key(["frog", roundi(s * 4.0), mood, blink])
	if _cache.has(key):
		return _cache[key]
	var b := Face.Builder.new()
	# feet and body
	b.ellipse(Vector2(0, -s * 0.05), s * 1.1, s * 0.22, Color(INK, 0.14))
	for side in [-1.0, 1.0]:
		b.ellipse(Vector2(side * s * 0.52, -s * 0.12), s * 0.36, s * 0.16, FROG_DEEP)
	b.ellipse(Vector2(0, -s * 0.72), s * 0.82, s * 0.7, FROG_DEEP)
	b.ellipse(Vector2(0, -s * 0.76), s * 0.76, s * 0.64, FROG)
	b.ellipse(Vector2(0, -s * 0.62), s * 0.48, s * 0.44, FROG_BELLY)
	# a festival coat's collar, a little sash
	b.stroke(PackedVector2Array([Vector2(-s * 0.5, -s * 1.12), Vector2(0, -s * 0.72), Vector2(s * 0.5, -s * 1.12)]), s * 0.12, BAND_SPOT)
	# the head
	var h := Vector2(0, -s * 1.62)
	b.ellipse(h + Vector2(0, s * 0.04), s * 1.02, s * 0.78, FROG_DEEP)
	b.ellipse(h, s * 0.98, s * 0.74, FROG)
	for side in [-1.0, 1.0]:
		var bulb := h + Vector2(side * s * 0.5, -s * 0.58)
		b.disc(bulb, s * 0.34, FROG_DEEP)
		b.disc(bulb + Vector2(0, -s * 0.02), s * 0.31, FROG)
		b.disc(bulb + Vector2(0, -s * 0.02), s * 0.22, Color.WHITE)
		if blink or mood == Mood.JOY:
			b.stroke(Face.Builder.arc_points(bulb + Vector2(0, s * 0.02), s * 0.12, PI * 1.1, PI * 1.9), s * 0.06, INK)
		elif mood == Mood.SAD:
			b.stroke(PackedVector2Array([bulb + Vector2(-s * 0.12, -s * 0.03 * side), bulb + Vector2(s * 0.12, s * 0.03 * side)]), s * 0.06, INK)
		else:
			b.ellipse(bulb + Vector2(side * s * 0.03, s * 0.01), s * 0.1, s * 0.13, INK)
			b.disc(bulb + Vector2(side * s * 0.03 - s * 0.03, -s * 0.04), s * 0.035, Color(1, 1, 1, 0.9))
	# the headband across the brow, knotted at one side with two tails
	b.stroke(PackedVector2Array([h + Vector2(-s * 0.95, -s * 0.2), h + Vector2(0, -s * 0.34), h + Vector2(s * 0.95, -s * 0.2)]), s * 0.2, BAND)
	b.disc(h + Vector2(0, -s * 0.33), s * 0.1, BAND_SPOT)
	var knot := h + Vector2(s * 0.92, -s * 0.2)
	b.polygon(PackedVector2Array([knot, knot + Vector2(s * 0.42, -s * 0.2), knot + Vector2(s * 0.36, s * 0.02)]), BAND)
	b.polygon(PackedVector2Array([knot, knot + Vector2(s * 0.38, s * 0.26), knot + Vector2(s * 0.2, s * 0.32)]), BAND)
	b.disc(knot, s * 0.1, BAND_SPOT)
	# cheeks and mouth
	for side in [-1.0, 1.0]:
		b.ellipse(h + Vector2(side * s * 0.62, s * 0.2), s * 0.16, s * 0.09, Color(CHEEK, 0.8))
	match mood:
		Mood.JOY:
			var mouth := Face.Builder.arc_points(h + Vector2(0, s * 0.06), s * 0.4, PI * 0.12, PI * 0.88)
			b.polygon(mouth, INK)
			b.ellipse(h + Vector2(0, s * 0.34), s * 0.16, s * 0.07, Color("e9707e"))
		Mood.SAD, Mood.WORRIED:
			b.stroke(Face.Builder.arc_points(h + Vector2(0, s * 0.46), s * 0.26, PI * 1.2, PI * 1.8), s * 0.07, INK)
		_:
			b.stroke(Face.Builder.arc_points(h + Vector2(0, -s * 0.02), s * 0.42, PI * 0.18, PI * 0.82), s * 0.07, INK)
	var m := b.mesh()
	_cache[key] = m
	return m

## One of Tam's arms with its drumstick, hanging from the shoulder at the
## origin and pointing down (+y); the screen turns it.
static func frog_arm(s: float) -> ArrayMesh:
	var key := _key(["arm", roundi(s * 4.0)])
	if _cache.has(key):
		return _cache[key]
	var b := Face.Builder.new()
	b.stroke(PackedVector2Array([Vector2.ZERO, Vector2(0, s * 0.55)]), s * 0.24, FROG_DEEP)
	b.stroke(PackedVector2Array([Vector2.ZERO, Vector2(0, s * 0.52)]), s * 0.18, FROG)
	# the stick, held in the hand, out past it
	b.stroke(PackedVector2Array([Vector2(0, s * 0.45), Vector2(0, s * 1.35)]), s * 0.13, STICK_DEEP)
	b.stroke(PackedVector2Array([Vector2(0, s * 0.45), Vector2(0, s * 1.33)]), s * 0.09, STICK)
	b.disc(Vector2(0, s * 1.36), s * 0.1, STICK)
	b.disc(Vector2(0, s * 0.6), s * 0.16, FROG)
	var m := b.mesh()
	_cache[key] = m
	return m

## A paper lantern of radius `r` hanging from its cord at the origin, lit
## `glow` 0..1.
static func lantern(r: float, col: Color, glow: float) -> ArrayMesh:
	var g := int(clampf(glow, 0.0, 1.0) * 4.0)
	var key := _key(["lantern", roundi(r), col.to_html(false), g])
	if _cache.has(key):
		return _cache[key]
	var gl := g / 4.0
	var b := Face.Builder.new()
	var c := Vector2(0, r * 1.25)
	if gl > 0.0:
		b.disc(c, r * (1.7 + 0.4 * gl), Color(LANTERN_GLOW, 0.18 * gl))
	b.stroke(PackedVector2Array([Vector2.ZERO, c + Vector2(0, -r)]), maxf(1.2, r * 0.06), Color(INK, 0.6))
	b.polygon(Face.Builder.round_rect(c + Vector2(-r * 0.45, -r * 1.12), Vector2(r * 0.9, r * 0.2), r * 0.05), INK.lightened(0.15))
	b.polygon(Face.Builder.round_rect(c + Vector2(-r * 0.45, r * 0.92), Vector2(r * 0.9, r * 0.2), r * 0.05), INK.lightened(0.15))
	var body := col.lerp(LANTERN_GLOW, 0.35 * gl)
	b.ellipse(c, r * 0.95, r * 1.0, body.darkened(0.12))
	b.ellipse(c + Vector2(-r * 0.05, -r * 0.03), r * 0.88, r * 0.94, body)
	for k in [-0.5, 0.0, 0.5]:
		b.stroke(Face.Builder.arc_points(c + Vector2(0, -r * 0.94 * k), r * 0.9, PI * 0.08, PI * 0.92).slice(0, 1) + PackedVector2Array([c + Vector2(-r * 0.9 * sqrt(1.0 - k * k), -r * 0.94 * k), c + Vector2(r * 0.9 * sqrt(1.0 - k * k), -r * 0.94 * k)]), maxf(1.0, r * 0.04), Color(body.darkened(0.25), 0.6))
	b.ellipse(c + Vector2(-r * 0.32, -r * 0.34), r * 0.2, r * 0.3, Color(1, 1, 0.92, 0.35 + 0.3 * gl))
	var m := b.mesh()
	_cache[key] = m
	return m

## The crowd's kinds and their fur: a bunny, a mouse, a bear cub, a chick and
## a hedgehog.
const CRITTERS := [Color("f3e6d8"), Color("b9aeb8"), Color("c8906a"), Color("f7d56a"), Color("a67c5b")]
const CRITTER_BELLY := [Color("fff8ee"), Color("e6dde4"), Color("ecc9a4"), Color("fff0b8"), Color("ecd7b8")]

## One of the festival crowd, `kind` 0..4 at scale `s` (its head's radius),
## standing with the foot of its body on the origin: a bust with a face, and
## with `arms_up` both paws in the air, each holding a glow stick of `stick`
## (transparent for bare paws).
static func critter(kind: int, s: float, mood := Mood.HAPPY, arms_up := false, stick := Color(0, 0, 0, 0)) -> ArrayMesh:
	var key := _key(["critter", kind, roundi(s * 4.0), mood, arms_up, stick.to_html()])
	if _cache.has(key):
		return _cache[key]
	kind = clampi(kind, 0, CRITTERS.size() - 1)
	var fur: Color = CRITTERS[kind]
	var deep := fur.darkened(0.18)
	var belly: Color = CRITTER_BELLY[kind]
	var b := Face.Builder.new()
	# the arms go behind the body when raised
	if arms_up:
		for side in [-1.0, 1.0]:
			var sh := Vector2(side * s * 0.62, -s * 0.62)
			var paw := Vector2(side * s * 1.12, -s * 1.72)
			if stick.a > 0.0:
				var tip := paw + Vector2(side * s * 0.18, -s * 0.78)
				b.disc(tip, s * 0.42, Color(stick, 0.22))
				b.stroke(PackedVector2Array([paw, tip]), s * 0.2, stick.lightened(0.35))
				b.stroke(PackedVector2Array([paw, tip]), s * 0.09, Color(1, 1, 1, 0.8))
			b.stroke(PackedVector2Array([sh, paw]), s * 0.3, deep)
			b.disc(paw, s * 0.2, fur)
	# the body, a bust cut flat at the foot
	var body := PackedVector2Array()
	for i in 17:
		var a := PI + PI * i / 16.0
		body.append(Vector2(cos(a) * s * 0.92, sin(a) * s * 0.95))
	b.polygon(body, deep)
	var inner := PackedVector2Array()
	for i in 17:
		var a := PI + PI * i / 16.0
		inner.append(Vector2(cos(a) * s * 0.84, sin(a) * s * 0.88 - s * 0.02))
	b.polygon(inner, fur)
	b.ellipse(Vector2(0, -s * 0.28), s * 0.44, s * 0.3, belly)
	var h := Vector2(0, -s * 1.34)
	# ears and crests behind the head
	match kind:
		0:
			for side in [-1.0, 1.0]:
				var e := h + Vector2(side * s * 0.42, -s * 1.02)
				b.ellipse(e, s * 0.24, s * 0.62, deep)
				b.ellipse(e + Vector2(0, s * 0.06), s * 0.11, s * 0.44, Color("f4b8b8"))
		1:
			for side in [-1.0, 1.0]:
				var e := h + Vector2(side * s * 0.72, -s * 0.62)
				b.disc(e, s * 0.44, deep)
				b.disc(e, s * 0.3, Color("f4b8c4"))
		2:
			for side in [-1.0, 1.0]:
				var e := h + Vector2(side * s * 0.7, -s * 0.66)
				b.disc(e, s * 0.3, deep)
				b.disc(e, s * 0.17, belly)
		3:
			for k in 3:
				var a := -PI * 0.5 + (k - 1) * 0.45
				b.stroke(PackedVector2Array([h + Vector2(0, -s * 0.8), h + Vector2.from_angle(a) * s * 1.35]), s * 0.14, deep)
		4:
			for k in 11:
				var a := PI + PI * k / 10.0
				var root := h + Vector2.from_angle(a) * s * 0.86
				var d := Vector2.from_angle(a)
				b.polygon(PackedVector2Array([root - d.orthogonal() * s * 0.2, root + d * s * 0.46, root + d.orthogonal() * s * 0.2]), Color("6e4f3a"))
	b.disc(h + Vector2(0, s * 0.05), s * 1.0, deep)
	b.disc(h, s * 0.95, fur)
	if kind == 4:
		b.ellipse(h + Vector2(0, s * 0.18), s * 0.72, s * 0.62, belly)
	b.ellipse(h + Vector2(-s * 0.36, -s * 0.46), s * 0.22, s * 0.12, Color(1, 1, 1, 0.35))
	_face(b, h + Vector2(0, s * 0.12), s * 0.82, mood)
	if kind == 3:
		b.polygon(PackedVector2Array([h + Vector2(-s * 0.14, s * 0.2), h + Vector2(s * 0.14, s * 0.2), h + Vector2(0, s * 0.38)]), Color("f08a3a"))
	elif kind in [0, 1, 2]:
		b.ellipse(h + Vector2(0, s * 0.12), s * 0.1, s * 0.07, INK if kind != 0 else Color("e9707e"))
	var m := b.mesh()
	_cache[key] = m
	return m

# --- the four drums (2026-10-01): a band of drums in a row, each with its own
# colour, voice and face; the notes coming down to each are berries of its
# colour. Left to right, low to high: the big drum, the hand drum, the
# jingle drum and the tongue drum. ---

## Each drum's berry: body, deep, highlight.
const LANE_BODY := [Color("e8604c"), Color("f2a33a"), Color("7fbf5a"), Color("4fa3d6")]
const LANE_DEEP := [Color("c24a3a"), Color("d07f22"), Color("5f9c3e"), Color("3a82b4")]
const LANE_HI := [Color("f59a84"), Color("fbd08a"), Color("b7e07a"), Color("8cc8ec")]
const GOLDEN := Color("f2c14e")
const ECHO := Color("b9a8f0")

## A berry for drum `lane` at radius `r`: an ink rim, a cream ring and the
## berry inside with a shine, a leaf and a face. `ghost` draws it as Echo's
## memory -- a lilac outline with no fill, for a hidden note struck.
static func berry(lane: int, r: float, mood := Mood.HAPPY) -> ArrayMesh:
	var key := _key(["berry", lane, roundi(r), mood])
	if _cache.has(key):
		return _cache[key]
	lane = clampi(lane, 0, 3)
	var body: Color = LANE_BODY[lane]
	var deep: Color = LANE_DEEP[lane]
	var hi: Color = LANE_HI[lane]
	var b := Face.Builder.new()
	b.disc(Vector2(0, r * 0.12), r * 1.04, Color(INK, 0.18))
	b.disc(Vector2.ZERO, r, INK)
	b.disc(Vector2.ZERO, r * 0.9, CREAM)
	var inner := r * 0.72
	b.disc(Vector2.ZERO, inner, deep)
	b.disc(Vector2(-inner * 0.06, -inner * 0.08), inner * 0.9, body)
	b.ellipse(Vector2(-inner * 0.36, -inner * 0.44), inner * 0.26, inner * 0.14, Color(hi, 0.9))
	# each drum's berry its own leaf: one, two, a sprig, none (a plum)
	match lane:
		0:
			b.ellipse(Vector2(inner * 0.1, -inner * 0.92), inner * 0.28, inner * 0.12, LEAF)
		1:
			for s in [-1.0, 1.0]:
				b.ellipse(Vector2(s * inner * 0.2, -inner * 0.9), inner * 0.22, inner * 0.1, LEAF)
		2:
			b.stroke(PackedVector2Array([Vector2(0, -inner * 0.8), Vector2(inner * 0.1, -inner * 1.12)]), inner * 0.08, LEAF_DEEP)
			b.disc(Vector2(inner * 0.18, -inner * 1.1), inner * 0.12, LEAF)
	_face(b, Vector2(0, inner * 0.12), inner * 0.9, mood)
	var m := b.mesh()
	_cache[key] = m
	return m

## The golden berry: one in a song, worth a shower of coins.
static func golden_berry(r: float, mood := Mood.JOY) -> ArrayMesh:
	var key := _key(["golden", roundi(r), mood])
	if _cache.has(key):
		return _cache[key]
	var b := Face.Builder.new()
	for i in 8:
		var a := TAU * i / 8.0
		b.polygon(PackedVector2Array([Vector2.from_angle(a - 0.12) * r * 0.9, Vector2.from_angle(a) * r * 1.38, Vector2.from_angle(a + 0.12) * r * 0.9]), Color(GOLDEN, 0.7))
	b.disc(Vector2.ZERO, r, INK)
	b.disc(Vector2.ZERO, r * 0.9, Color("fff1c8"))
	b.disc(Vector2.ZERO, r * 0.72, ROLL_DEEP)
	b.disc(Vector2(-r * 0.04, -r * 0.06), r * 0.65, GOLDEN)
	b.ellipse(Vector2(-r * 0.26, -r * 0.32), r * 0.2, r * 0.1, Color(1, 1, 0.9, 0.95))
	_face(b, Vector2(0, r * 0.1), r * 0.64, mood)
	var m := b.mesh()
	_cache[key] = m
	return m

## Echo's hidden note, shown for a moment once struck: a lilac ring.
static func ghost(r: float) -> ArrayMesh:
	var key := _key(["ghost", roundi(r)])
	if _cache.has(key):
		return _cache[key]
	var b := Face.Builder.new()
	b.stroke(Face.Builder.arc_points(Vector2.ZERO, r * 0.9, 0.0, TAU), r * 0.18, Color(ECHO, 0.9), true)
	b.stroke(Face.Builder.arc_points(Vector2.ZERO, r * 0.62, 0.0, TAU), r * 0.08, Color(Color.WHITE, 0.6), true)
	var m := b.mesh()
	_cache[key] = m
	return m

## A hold note's tail for drum `lane`, `length` long running up from the
## origin (to -y) and `w` wide: a soft ribbon of the drum's colour with an
## ink edge and beads along it. `lit` draws it glowing, held.
static func tail(lane: int, length: float, w: float, lit: bool) -> ArrayMesh:
	var key := _key(["tail", lane, roundi(length / 4.0), roundi(w), lit])
	if _cache.has(key):
		return _cache[key]
	lane = clampi(lane, 0, 3)
	var L := maxf(0.0, length)
	var b := Face.Builder.new()
	var body: Color = LANE_BODY[lane]
	if lit:
		b.polygon(Face.Builder.round_rect(Vector2(-w * 0.9, -L - w * 0.4), Vector2(w * 1.8, L + w * 0.4), w * 0.9), Color(body.lightened(0.5), 0.35))
	b.polygon(Face.Builder.round_rect(Vector2(-w * 0.5, -L - w * 0.5), Vector2(w, L + w * 0.5), w * 0.5), INK)
	b.polygon(Face.Builder.round_rect(Vector2(-w * 0.36, -L - w * 0.36), Vector2(w * 0.72, L + w * 0.36), w * 0.36), body.lightened(0.25 if lit else 0.0))
	b.stroke(PackedVector2Array([Vector2(-w * 0.12, -w * 0.2), Vector2(-w * 0.12, -L)]), w * 0.1, Color(1, 1, 1, 0.45 if lit else 0.25))
	var step := w * 1.3
	var y := -step
	while y > -L:
		b.disc(Vector2(w * 0.08, y), w * 0.1, Color(CREAM, 0.7))
		y -= step
	var m := b.mesh()
	_cache[key] = m
	return m

## One of the four drums at scale `r` (half its width), standing with its
## foot on the origin, seen from a little above: the skin's oval on top --
## where it is struck -- and the body under it with a face.
##   0 the big drum: a wide lacquered barrel with brass tacks
##   1 the hand drum: a goblet of warm wood laced with rope
##   2 the jingle drum: a shallow green frame with brass jingles
##   3 the tongue drum: a blue box of wood with its tongues cut on top
static func band_drum(kind: int, r: float, mood := Mood.HAPPY) -> ArrayMesh:
	var key := _key(["band", kind, roundi(r), mood])
	if _cache.has(key):
		return _cache[key]
	var b := Face.Builder.new()
	var top := skin_y(kind, r)
	b.ellipse(Vector2(0, -r * 0.04), r * 1.0, r * 0.16, Color(INK, 0.18))
	match kind:
		0:
			var body := Color("b5523b")
			var deep := Color("8c3b2a")
			b.polygon(_barrel(r * 0.98, r * 0.86, top, -r * 0.06), deep)
			b.polygon(_barrel(r * 0.9, r * 0.8, top, -r * 0.1), body)
			b.stroke(PackedVector2Array([Vector2(-r * 0.6, top + r * 0.2), Vector2(-r * 0.7, -r * 0.3)]), r * 0.07, Color(RIM_HI, 0.7))
			for k in 7:
				var x := lerpf(-r * 0.78, r * 0.78, k / 6.0)
				var y := top + r * 0.12 + absf(x) * 0.05
				b.disc(Vector2(x, y), r * 0.045, BRASS_DEEP)
				b.disc(Vector2(x, y - r * 0.01), r * 0.035, BRASS)
			_skin(b, top, r * 0.9, r * 0.26, Color("8c3b2a"))
			_face(b, Vector2(0, top + r * 0.62), r * 0.5, mood)
		1:
			var wood := Color("d9894a")
			var deep := Color("b36a32")
			var cup := PackedVector2Array()
			var steps := 18
			for i in steps + 1:
				var t := float(i) / steps
				var y := lerpf(top, -r * 0.08, t)
				var w := r * (0.72 - 0.42 * sin(clampf(t * 1.25, 0.0, 1.0) * PI * 0.5) + 0.2 * smoothstep(0.75, 1.0, t))
				cup.append(Vector2(-w, y))
			for i in range(steps, -1, -1):
				var t := float(i) / steps
				var y := lerpf(top, -r * 0.08, t)
				var w := r * (0.72 - 0.42 * sin(clampf(t * 1.25, 0.0, 1.0) * PI * 0.5) + 0.2 * smoothstep(0.75, 1.0, t))
				cup.append(Vector2(w, y))
			var outer := PackedVector2Array()
			for p in cup:
				outer.append(p * Vector2(1.08, 1.0) + Vector2(0, r * 0.02))
			b.polygon(outer, deep)
			b.polygon(cup, wood)
			# the rope lacing, a zigzag round the cup
			var zig := PackedVector2Array()
			for k in 9:
				var x := lerpf(-r * 0.62, r * 0.62, k / 8.0)
				zig.append(Vector2(x, top + r * (0.12 if k % 2 == 0 else 0.42)))
			b.stroke(zig, r * 0.05, Color(CREAM, 0.9))
			_skin(b, top, r * 0.76, r * 0.22, deep)
			_face(b, Vector2(0, top + r * 0.62), r * 0.42, mood)
		2:
			var frame := Color("6fae4e")
			var deep := Color("4f8a36")
			b.polygon(Face.Builder.round_rect(Vector2(-r * 0.96, top), Vector2(r * 1.92, -top - r * 0.06), r * 0.3), deep)
			b.polygon(Face.Builder.round_rect(Vector2(-r * 0.9, top), Vector2(r * 1.8, -top - r * 0.14), r * 0.26), frame)
			# the jingles, pairs of brass discs in slots round the frame
			for k in 4:
				var x := lerpf(-r * 0.6, r * 0.6, k / 3.0)
				var y := top + (-top) * 0.55
				b.polygon(Face.Builder.round_rect(Vector2(x - r * 0.13, y - r * 0.08), Vector2(r * 0.26, r * 0.16), r * 0.06), Color(INK, 0.45))
				b.ellipse(Vector2(x, y), r * 0.1, r * 0.05, BRASS)
				b.ellipse(Vector2(x - r * 0.02, y - r * 0.015), r * 0.05, r * 0.02, Color(1, 1, 0.9, 0.9))
			_skin(b, top, r * 0.92, r * 0.27, deep)
			_face(b, Vector2(0, top + r * 0.02), r * 0.4, mood)
		_:
			var box := Color("4f93c4")
			var deep := Color("356f9c")
			b.polygon(Face.Builder.round_rect(Vector2(-r * 0.92, top - r * 0.1), Vector2(r * 1.84, -top + r * 0.04), r * 0.14), deep)
			b.polygon(Face.Builder.round_rect(Vector2(-r * 0.86, top - r * 0.06), Vector2(r * 1.72, -top - r * 0.06), r * 0.12), box)
			# the lid seen from above, its tongues cut in
			var lid := Face.Builder.round_rect(Vector2(-r * 0.92, top - r * 0.34), Vector2(r * 1.84, r * 0.4), r * 0.14)
			b.polygon(lid, Color("8cc4e8"))
			for k in 3:
				var x := lerpf(-r * 0.5, r * 0.5, k / 2.0)
				b.stroke(PackedVector2Array([Vector2(x - r * 0.18, top - r * 0.2), Vector2(x + r * 0.18, top - r * 0.2), Vector2(x + r * 0.18, top - r * 0.06)]), r * 0.04, Color(deep, 0.8))
			b.disc(Vector2(0, top - r * 0.14), r * 0.07, Color(INK, 0.5))
			_face(b, Vector2(0, top + r * 0.42), r * 0.44, mood)
	var m := b.mesh()
	_cache[key] = m
	return m

## Where a drum's skin (its striking face) sits above its foot.
static func skin_y(kind: int, r: float) -> float:
	return [-r * 1.0, -r * 1.15, -r * 0.62, -r * 0.62][clampi(kind, 0, 3)]

static func _barrel(w_mid: float, w_end: float, top: float, foot: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n := 14
	for i in n + 1:
		var t := float(i) / n
		pts.append(Vector2(-lerpf(w_end, w_mid, sin(t * PI)), lerpf(top, foot, t)))
	for i in range(n, -1, -1):
		var t := float(i) / n
		pts.append(Vector2(lerpf(w_end, w_mid, sin(t * PI)), lerpf(top, foot, t)))
	return pts

static func _skin(b: Face.Builder, y: float, rx: float, ry: float, rim: Color) -> void:
	b.ellipse(Vector2(0, y), rx * 1.06, ry * 1.18, rim)
	b.ellipse(Vector2(0, y), rx, ry, SKIN_DEEP)
	b.ellipse(Vector2(-rx * 0.04, y - ry * 0.06), rx * 0.94, ry * 0.88, SKIN)
	b.ellipse(Vector2(-rx * 0.4, y - ry * 0.3), rx * 0.24, ry * 0.2, Color(1, 1, 1, 0.4))

## Tam's sunglasses, for a run hot enough: two dark lenses and a bridge,
## centred on the origin at scale `s` (Tam's).
static func shades(s: float) -> ArrayMesh:
	var key := _key(["shades", roundi(s * 4.0)])
	if _cache.has(key):
		return _cache[key]
	var b := Face.Builder.new()
	for side in [-1.0, 1.0]:
		var c := Vector2(side * s * 0.5, 0)
		b.polygon(Face.Builder.round_rect(c - Vector2(s * 0.34, s * 0.22), Vector2(s * 0.68, s * 0.42), s * 0.16), INK)
		b.polygon(Face.Builder.round_rect(c - Vector2(s * 0.28, s * 0.17), Vector2(s * 0.56, s * 0.32), s * 0.12), Color("2c3e5a"))
		b.stroke(PackedVector2Array([c + Vector2(-s * 0.18, -s * 0.08), c + Vector2(-s * 0.04, -s * 0.14)]), s * 0.05, Color(1, 1, 1, 0.6))
	b.stroke(PackedVector2Array([Vector2(-s * 0.16, -s * 0.06), Vector2(s * 0.16, -s * 0.06)]), s * 0.07, INK)
	var m := b.mesh()
	_cache[key] = m
	return m
