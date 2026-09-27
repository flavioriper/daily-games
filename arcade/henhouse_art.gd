extends RefCounted

## Henhouse's cast and props, drawn as builder shapes and shared by the game
## (arcade/henhouse_screen.gd), its shop chips and its card on the Arcade
## tab. A bird is built in pixels for a field unit of `u` pixels, standing
## with its feet at the origin, facing right (the screen mirrors it with the
## draw transform to face left), so it moves by transform and is never
## rebuilt to move. Meshes are cached per look, plumage, frame and scale.
##
## The cast: hens in three plumages (cream, russet and speckled black), a
## round yellow chick (asleep, a squashed ball with shut eyes), the rooster
## with a great sickle tail, and the squirrel who works the pen. Eggs are
## drawn straight into a builder, in the state the belt has put them in:
## brown, washed, stamped, boxed, golden, or pale blue and speckled when a
## chick is inside.

const Pal = preload("res://core/palette.gd")
const Face = preload("res://ui/faces/face.gd")

enum Look { HEN, HEN_PECK, HEN_HAPPY, CHICK, CHICK_SLEEP, ROOSTER, SQUIRREL, SQUIRREL_CARRY }

const INK := Color("3b3028")
const PLUMES := [
	[Color("fbf5ea"), Color("e6d8c2"), Color("fffdf7")],
	[Color("d98c4a"), Color("b56a32"), Color("eaa865")],
	[Color("4d4852"), Color("36323b"), Color("6a6470")],
]
const COMB := Color("e2544c")
const COMB_DEEP := Color("bd3a35")
const BEAK := Color("f2a93b")
const BEAK_DEEP := Color("d98a22")
const LEG := Color("eea24a")
const BLUSH := Color("f4a7a0")
const CHICK := Color("ffd95e")
const CHICK_DEEP := Color("f0bb3a")
const CHICK_HI := Color("fff0a8")
const ROOSTER := Color("e9b776")
const ROOSTER_DEEP := Color("c98845")
const ROOSTER_NECK := Color("d9733a")
const TAIL := Color("2f5a5e")
const TAIL_HI := Color("4f8a7d")
const SQUIRREL := Color("c9773f")
const SQUIRREL_DEEP := Color("a45a2c")
const SQUIRREL_BELLY := Color("f2d2a6")
const EGG := Color("e8c49a")
const EGG_DEEP := Color("cfa47a")
const EGG_WASHED := Color("f7ead8")
const EGG_FERTILE := Color("cfe6de")
const EGG_FERTILE_DEEP := Color("a9cabd")
const EGG_GOLD := Color("f2c14e")
const EGG_GOLD_DEEP := Color("d49a2c")
const STAMP := Color("d9534c")
const CARTON := Color("d8b27e")
const CARTON_DEEP := Color("b98e58")
const WOOD := Color("b98556")
const WOOD_DEEP := Color("946440")
const WOOD_HI := Color("d4a574")
const METAL := Color("aab4bb")
const METAL_DEEP := Color("7f8a92")
const WATER := Color("7fc3e8")
const WATER_DEEP := Color("4f9fcb")
const GRAIN := Color("f0c35a")
const GRAIN_DEEP := Color("d19a36")
const SILO := Color("d9774a")
const SILO_DEEP := Color("b85c34")
const BELT := Color("4a4550")
const BELT_HI := Color("615b68")
const WASHER := Color("7fb6d9")
const WASHER_DEEP := Color("5a90b5")
const PRESS := Color("e2645c")
const PRESS_DEEP := Color("b84a44")
const BOX := Color("d8b27e")
const HEART := Color("ef6f7a")

static var _cache := {}

## A bird or the squirrel: `plume` picks a hen's plumage, `frame` her step.
static func mesh(look: int, u: float, plume := 0, frame := 0) -> ArrayMesh:
	var key := "%d/%d/%d/%.2f" % [look, plume, frame, u]
	if _cache.has(key):
		return _cache[key]
	if _cache.size() > 300:
		_cache.clear()
	var b := Face.Builder.new()
	match look:
		Look.HEN, Look.HEN_PECK, Look.HEN_HAPPY:
			hen(b, u, plume, frame, look)
		Look.CHICK:
			chick(b, u, frame, false)
		Look.CHICK_SLEEP:
			chick(b, u, 0, true)
		Look.ROOSTER:
			rooster(b, u, frame)
		Look.SQUIRREL, Look.SQUIRREL_CARRY:
			squirrel(b, u, frame, look == Look.SQUIRREL_CARRY)
	var m := b.mesh()
	_cache[key] = m
	return m

static func _shadow(b: Face.Builder, s: float, rx: float) -> void:
	b.ellipse(Vector2(0, 0.6 * s), rx * s, rx * 0.32 * s, Color(0.2, 0.14, 0.06, 0.2))

## Two legs with three toes each, stepping apart on the odd frame.
static func _legs(b: Face.Builder, s: float, frame: int, spread: float, h: float, col: Color) -> void:
	var step := 1.6 if frame == 1 else 0.0
	for side in [-1.0, 1.0]:
		var x: float = side * spread + (step * side)
		var hip := Vector2(x * s, -h * s)
		var foot := Vector2((x + 0.6) * s, 0)
		b.stroke(PackedVector2Array([hip, foot]), 1.2 * s, col)
		for k in 3:
			b.stroke(PackedVector2Array([foot, foot + Vector2((k - 0.6) * 1.5 * s, 0.3 * s)]), 0.8 * s, col)

## A dot of an eye with a glint, or a shut arc.
static func _eye(b: Face.Builder, c: Vector2, s: float, open := true, r := 1.15) -> void:
	if open:
		b.disc(c, r * s, INK)
		b.disc(c + Vector2(0.35, -0.4) * s, r * 0.4 * s, Color("fffdf7"))
	else:
		b.stroke(Face.Builder.arc_points(c + Vector2(0, -0.4 * s), r * s, PI * 0.15, PI * 0.85), 0.7 * s, INK)

static func _heart(b: Face.Builder, c: Vector2, r: float, col: Color) -> void:
	b.disc(c + Vector2(-r * 0.5, 0), r * 0.58, col)
	b.disc(c + Vector2(r * 0.5, 0), r * 0.58, col)
	b.fan(PackedVector2Array([c + Vector2(-r * 1.05, r * 0.15), c + Vector2(r * 1.05, r * 0.15), c + Vector2(0, r * 1.25)]), col)

## A hen side on, facing right, about 24 units tall: a plump body with a
## raised tail, a folded wing, a head with a three-lobed comb, a wattle and
## a beak. Pecking lowers the head to the ground; happy closes her eyes in a
## smile with a blush.
static func hen(b: Face.Builder, u: float, plume: int, frame: int, look: int) -> void:
	var s := u
	var p: Array = PLUMES[plume % PLUMES.size()]
	var col: Color = p[0]
	var deep: Color = p[1]
	var hi: Color = p[2]
	_shadow(b, s, 11.0)
	_legs(b, s, frame, 2.4, 5.0, LEG)
	# the tail, three rounded feathers up behind
	for k in 3:
		var a := -2.2 + k * 0.28
		var c := Vector2(-9.5, -13.0) + Vector2.from_angle(a) * 3.5
		b.ellipse(c * s, 3.4 * s, 5.2 * s, deep if k != 1 else col)
	# the body: a deep underside, the lit body, a rim of light on the back
	b.ellipse(Vector2(0.5, -9.5) * s, 11.5 * s, 8.6 * s, deep)
	b.ellipse(Vector2(-0.2, -10.4) * s, 10.6 * s, 7.8 * s, col)
	b.ellipse(Vector2(-2.5, -14.2) * s, 6.5 * s, 2.6 * s, hi)
	if plume == 2:
		for q in [Vector2(-5, -8), Vector2(-1, -6), Vector2(3, -9), Vector2(-7, -12), Vector2(1, -12.5), Vector2(5, -6.5)]:
			b.disc(q * s, 0.8 * s, Color(1, 1, 1, 0.55))
	# the folded wing, with its feather tips
	var wing := PackedVector2Array()
	for i in 13:
		var a := PI * 0.95 + PI * 1.1 * i / 12.0
		wing.append(Vector2(-1.5 + cos(a) * 6.8, -10.2 + sin(a) * 4.4) * s)
	b.polygon(wing, deep)
	for k in 3:
		b.ellipse(Vector2(-5.2 + k * 2.2, -7.2 + k * 0.2) * s, 1.3 * s, 1.9 * s, deep.darkened(0.08))
	b.stroke(Face.Builder.arc_points(Vector2(-1.5, -10.6) * s, 5.6 * s, PI * 1.1, PI * 1.75), 0.9 * s, hi)
	# the head and neck, lowered to the ground when pecking
	var head := Vector2(7.0, -19.0) if look != Look.HEN_PECK else Vector2(11.5, -8.5)
	var neck := PackedVector2Array([Vector2(3.0, -13.0) * s, head * s + Vector2(-3.8, 2.5) * s, head * s + Vector2(2.0, 3.0) * s, Vector2(8.0, -10.0) * s])
	b.fan(neck, col)
	b.disc(head * s, 5.4 * s, col)
	b.disc((head + Vector2(-1.4, -1.6)) * s, 2.6 * s, hi)
	# the comb, three lobes, and the wattle
	for k in 3:
		var c := head + Vector2(-2.2 + k * 2.1, -5.2 + absf(k - 1) * 0.9)
		b.disc(c * s, (1.9 - absf(k - 1) * 0.25) * s, COMB_DEEP)
		b.disc((c + Vector2(-0.2, -0.3)) * s, (1.6 - absf(k - 1) * 0.25) * s, COMB)
	b.ellipse((head + Vector2(3.6, 3.8)) * s, 1.3 * s, 2.0 * s, COMB)
	# the beak
	var bk := head + Vector2(4.6, -0.6)
	b.fan(PackedVector2Array([(bk + Vector2(0, -1.5)) * s, (bk + Vector2(3.6, 0.2)) * s, (bk + Vector2(0, 1.4)) * s]), BEAK)
	b.stroke(PackedVector2Array([(bk + Vector2(0.2, 0.1)) * s, (bk + Vector2(3.0, 0.2)) * s]), 0.4 * s, BEAK_DEEP)
	# the eye and a blush
	_eye(b, (head + Vector2(1.8, -0.8)) * s, s, look != Look.HEN_HAPPY)
	b.ellipse((head + Vector2(1.2, 2.2)) * s, 1.6 * s, 1.0 * s, Color(BLUSH, 0.75 if look == Look.HEN_HAPPY else 0.4))

## A chick, a yellow ball about 12 units tall; asleep it squats with shut
## eyes and its beak tucked.
static func chick(b: Face.Builder, u: float, frame: int, asleep: bool) -> void:
	var s := u
	_shadow(b, s, 6.0)
	var lift := 0.0 if asleep else 3.0
	if not asleep:
		_legs(b, s, frame, 1.5, 3.2, LEG)
	var c := Vector2(0, -5.5 - lift + (1.2 if asleep else 0.0))
	var r := Vector2(6.4, 5.8 if not asleep else 4.8)
	b.ellipse(c * s + Vector2(0.4, 0.6) * s, r.x * s, r.y * s, CHICK_DEEP)
	b.ellipse(c * s, r.x * 0.95 * s, r.y * 0.95 * s, CHICK)
	b.ellipse((c + Vector2(-1.8, -2.2)) * s, 2.8 * s, 1.8 * s, CHICK_HI)
	# a tuft on top
	for k in 3:
		b.stroke(Face.Builder.bezier2((c + Vector2(0.5, -r.y + 0.6)) * s, (c + Vector2(0.2 + (k - 1) * 1.2, -r.y - 1.2)) * s,
			(c + Vector2(-0.6 + (k - 1) * 1.8, -r.y - 2.0)) * s, 5), 0.8 * s, CHICK_DEEP)
	# a stub of a wing
	b.ellipse((c + Vector2(-1.8, 1.0)) * s, 2.6 * s, 1.8 * s, CHICK_DEEP)
	var bk := c + Vector2(r.x - 0.6, 0.2 if not asleep else 1.2)
	b.fan(PackedVector2Array([(bk + Vector2(0, -1.1)) * s, (bk + Vector2(2.4, 0)) * s, (bk + Vector2(0, 1.0)) * s]), BEAK)
	_eye(b, (c + Vector2(2.8, -1.2)) * s, s, not asleep, 0.95)
	b.ellipse((c + Vector2(2.0, 1.2)) * s, 1.2 * s, 0.7 * s, Color(BLUSH, 0.6))

## The rooster: taller than a hen, a russet neck, a great green sickle tail
## and a big comb.
static func rooster(b: Face.Builder, u: float, frame: int) -> void:
	var s := u
	_shadow(b, s, 12.0)
	_legs(b, s, frame, 2.8, 7.0, LEG)
	# the sickle tail, long curved feathers up behind
	for k in 4:
		var tip := Vector2(-18.0 + k * 1.5, -30.0 + k * 4.5)
		var pts := Face.Builder.bezier2(Vector2(-7, -14) * s, Vector2(-17.0 + k, -24.0 + k * 3.0) * s, tip * s, 8)
		b.stroke(pts, (3.2 - k * 0.3) * s, TAIL if k % 2 == 0 else TAIL_HI)
	b.ellipse(Vector2(0.5, -12.0) * s, 12.0 * s, 9.0 * s, ROOSTER_DEEP)
	b.ellipse(Vector2(-0.3, -12.8) * s, 11.0 * s, 8.2 * s, ROOSTER)
	var wing := PackedVector2Array()
	for i in 13:
		var a := PI * 0.95 + PI * 1.1 * i / 12.0
		wing.append(Vector2(-1.5 + cos(a) * 7.0, -12.6 + sin(a) * 4.6) * s)
	b.polygon(wing, TAIL)
	b.stroke(Face.Builder.arc_points(Vector2(-1.5, -13.0) * s, 5.8 * s, PI * 1.1, PI * 1.75), 0.9 * s, TAIL_HI)
	var head := Vector2(8.0, -24.0)
	b.fan(PackedVector2Array([Vector2(3.0, -15.0) * s, (head + Vector2(-4.2, 2.0)) * s, (head + Vector2(2.4, 3.4)) * s, Vector2(9.0, -12.0) * s]), ROOSTER_NECK)
	b.disc(head * s, 5.8 * s, ROOSTER_NECK)
	for k in 5:
		var c := head + Vector2(-4.0 + k * 2.0, -5.8 - sin(k / 4.0 * PI) * 1.4)
		b.disc(c * s, 1.9 * s, COMB_DEEP)
		b.disc((c + Vector2(-0.2, -0.3)) * s, 1.6 * s, COMB)
	b.ellipse((head + Vector2(3.4, 4.6)) * s, 1.6 * s, 2.6 * s, COMB)
	var bk := head + Vector2(5.0, -0.6)
	b.fan(PackedVector2Array([(bk + Vector2(0, -1.6)) * s, (bk + Vector2(4.0, 0.3)) * s, (bk + Vector2(0, 1.5)) * s]), BEAK)
	_eye(b, (head + Vector2(2.0, -1.0)) * s, s)
	b.stroke(PackedVector2Array([(head + Vector2(0.6, -2.6)) * s, (head + Vector2(3.4, -2.2)) * s]), 0.7 * s, INK)

## The squirrel who works the pen, side on and facing right, with a bushy
## tail curling up behind; carrying, it holds its arms up to the eggs on its
## back.
static func squirrel(b: Face.Builder, u: float, frame: int, carry: bool) -> void:
	var s := u
	_shadow(b, s, 8.0)
	# the tail, a fat S up behind
	var tail := Face.Builder.bezier3(Vector2(-5, -4) * s, Vector2(-15, -4) * s, Vector2(-14, -20) * s, Vector2(-6, -19) * s, 14)
	b.stroke(tail, 8.5 * s, SQUIRREL_DEEP)
	b.stroke(tail, 6.5 * s, SQUIRREL)
	b.stroke(Face.Builder.bezier3(Vector2(-7, -6) * s, Vector2(-13, -7) * s, Vector2(-12.5, -17) * s, Vector2(-7, -17.5) * s, 12), 1.6 * s, Color(1, 0.9, 0.75, 0.5))
	# hind legs
	var hop := -1.0 if frame == 1 else 0.0
	b.ellipse(Vector2(-2.5, -2.4 + hop) * s, 3.4 * s, 2.4 * s, SQUIRREL_DEEP)
	b.ellipse(Vector2(1.5, -0.8) * s, 2.0 * s, 1.0 * s, SQUIRREL_DEEP)
	# the body and belly
	b.ellipse(Vector2(0.5, -7.0 + hop) * s, 5.2 * s, 6.2 * s, SQUIRREL)
	b.ellipse(Vector2(2.4, -6.2 + hop) * s, 2.8 * s, 4.2 * s, SQUIRREL_BELLY)
	# the head, an ear, the eye and nose
	var head := Vector2(3.8, -14.0 + hop)
	b.disc(head * s, 4.2 * s, SQUIRREL)
	b.fan(PackedVector2Array([(head + Vector2(-2.6, -2.0)) * s, (head + Vector2(-1.2, -6.8)) * s, (head + Vector2(0.4, -2.6)) * s]), SQUIRREL_DEEP)
	b.ellipse((head + Vector2(2.6, 1.0)) * s, 2.4 * s, 1.9 * s, SQUIRREL_BELLY)
	b.disc((head + Vector2(4.6, 0.4)) * s, 0.8 * s, INK)
	_eye(b, (head + Vector2(1.4, -0.9)) * s, s, true, 1.0)
	# arms: up to the load, or at the chest
	if carry:
		b.stroke(PackedVector2Array([Vector2(1.5, -9.0 + hop) * s, Vector2(-0.5, -13.5 + hop) * s]), 1.3 * s, SQUIRREL_DEEP)
	else:
		b.stroke(PackedVector2Array([Vector2(2.5, -8.0 + hop) * s, Vector2(5.0, -7.0 + hop) * s]), 1.3 * s, SQUIRREL_DEEP)

## An egg at `c` (its middle), `r` its half-height in pixels, in the state
## the belt has put it in. A boxed egg is a little carton with the egg's
## crown showing.
static func egg(b: Face.Builder, c: Vector2, r: float, gold := false, fertile := false, washed := false,
		stamped := false, boxed := false, alpha := 1.0) -> void:
	if boxed:
		var w := r * 1.9
		b.ellipse(c + Vector2(0, r * 0.95), w * 0.62, r * 0.26, Color(0.2, 0.14, 0.06, 0.2 * alpha))
		var body := Face.Builder.round_rect(c + Vector2(-w * 0.5, -r * 0.2), Vector2(w, r * 1.1), r * 0.18)
		b.fan(Face.Builder.round_rect(c + Vector2(-w * 0.5, -r * 0.1), Vector2(w, r * 1.1), r * 0.18), Color(CARTON_DEEP, alpha))
		b.fan(body, Color(CARTON, alpha))
		b.ellipse(c + Vector2(0, -r * 0.25), r * 0.62, r * 0.55, Color((EGG_GOLD if gold else EGG_WASHED), alpha))
		b.stroke(PackedVector2Array([c + Vector2(-w * 0.5, -r * 0.2), c + Vector2(w * 0.5, -r * 0.2)]), r * 0.16, Color(CARTON_DEEP, alpha))
		b.disc(c + Vector2(0, r * 0.42), r * 0.2, Color(STAMP if stamped else CARTON_DEEP, alpha))
		return
	var col := EGG
	var deep := EGG_DEEP
	if gold:
		col = EGG_GOLD
		deep = EGG_GOLD_DEEP
	elif fertile:
		col = EGG_FERTILE
		deep = EGG_FERTILE_DEEP
	elif washed:
		col = EGG_WASHED
		deep = EGG.lightened(0.1)
	b.ellipse(c + Vector2(0, r * 0.95), r * 0.8, r * 0.25, Color(0.2, 0.14, 0.06, 0.2 * alpha))
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		# narrower at the top: an egg, not an ellipse
		var rx := r * 0.78 * (1.0 - 0.14 * (1.0 - sin(a)) * 0.5)
		pts.append(c + Vector2(cos(a) * rx, sin(a) * r))
	b.fan(pts, Color(deep, alpha))
	var inner := PackedVector2Array()
	for p in pts:
		inner.append(c + (p - c) * 0.88 + Vector2(-r * 0.06, -r * 0.08))
	b.fan(inner, Color(col, alpha))
	b.ellipse(c + Vector2(-r * 0.28, -r * 0.4), r * 0.18, r * 0.3, Color(1, 1, 1, (0.75 if gold or washed else 0.45) * alpha))
	if fertile:
		for q in [Vector2(0.25, 0.1), Vector2(-0.2, 0.35), Vector2(0.1, -0.35), Vector2(0.35, 0.5)]:
			b.disc(c + q * r, r * 0.08, Color(deep.darkened(0.2), alpha))
	if stamped:
		b.stroke(Face.Builder.arc_points(c + Vector2(r * 0.12, r * 0.2), r * 0.32, 0.0, TAU), r * 0.1, Color(STAMP, 0.85 * alpha))

static var _icons := {}

## A shop chip's picture, fitted in a box `size` pixels tall and centred
## on the origin.
static func icon(item: String, size: float) -> ArrayMesh:
	var key := "%s/%.1f" % [item, size]
	if _icons.has(key):
		return _icons[key]
	var b := Face.Builder.new()
	var s := size / 30.0
	match item:
		"hen":
			_put(b, Look.HEN, s, Vector2(0, 12) * s, 1)
			b.disc(Vector2(10, -9) * s, 4.2 * s, Pal.SUN)
			b.stroke(PackedVector2Array([Vector2(8, -9) * s, Vector2(12, -9) * s]), 1.2 * s, Color("fffaf0"))
			b.stroke(PackedVector2Array([Vector2(10, -11) * s, Vector2(10, -7) * s]), 1.2 * s, Color("fffaf0"))
		"rooster":
			_put(b, Look.ROOSTER, s * 0.85, Vector2(1, 13) * s, 0)
		"radio":
			b.fan(Face.Builder.round_rect(Vector2(-12, -7) * s, Vector2(24, 17) * s, 3.0 * s), Color("c45b4a"))
			b.fan(Face.Builder.round_rect(Vector2(-10, -5) * s, Vector2(12, 13) * s, 2.0 * s), Color("f3e2c4"))
			for k in 4:
				b.stroke(PackedVector2Array([Vector2(-9, -3 + k * 3) * s, Vector2(1, -3 + k * 3) * s]), 0.8 * s, Color("c9b38e"))
			b.disc(Vector2(7, -1) * s, 2.6 * s, Color("3b3028"))
			b.disc(Vector2(7, 5) * s, 1.8 * s, Color("3b3028"))
			b.stroke(PackedVector2Array([Vector2(-6, -7) * s, Vector2(4, -14) * s]), 1.0 * s, METAL_DEEP)
			b.disc(Vector2(12, -12) * s, 1.8 * s, INK)
			b.stroke(PackedVector2Array([Vector2(13.6, -12) * s, Vector2(13.6, -18) * s, Vector2(16, -17) * s]), 0.9 * s, INK)
		"feed":
			var sack := PackedVector2Array([Vector2(-9, -8) * s, Vector2(9, -8) * s, Vector2(11, 12) * s, Vector2(-11, 12) * s])
			b.fan(sack, Color("e3cfa4"))
			b.fan(PackedVector2Array([Vector2(-9, -8) * s, Vector2(9, -8) * s, Vector2(7, -12) * s, Vector2(-7, -12) * s]), Color("cdb584"))
			for k in 7:
				b.ellipse(Vector2(-6 + k * 2, -12.5 - (k % 2)) * s, 1.4 * s, 1.0 * s, GRAIN)
			b.disc(Vector2(0, 3) * s, 5.0 * s, Pal.SUN)
			b.fan(PackedVector2Array([Vector2(-2, 1) * s, Vector2(2, 1) * s, Vector2(0, 6) * s]), Color("fffaf0"))
		"auto_feed", "auto_water":
			var col := GRAIN if item == "auto_feed" else WATER
			var deep := GRAIN_DEEP if item == "auto_feed" else WATER_DEEP
			b.fan(PackedVector2Array([Vector2(-8, -13) * s, Vector2(8, -13) * s, Vector2(4, 0) * s, Vector2(-4, 0) * s]), METAL)
			b.fan(PackedVector2Array([Vector2(-6, -11) * s, Vector2(6, -11) * s, Vector2(3, -2) * s, Vector2(-3, -2) * s]), col)
			b.fan(Face.Builder.round_rect(Vector2(-13, 4) * s, Vector2(26, 8) * s, 3 * s), WOOD)
			b.fan(Face.Builder.round_rect(Vector2(-11, 5) * s, Vector2(22, 4) * s, 2 * s), deep)
			b.stroke(PackedVector2Array([Vector2(0, 0) * s, Vector2(0, 5) * s]), 2.0 * s, col)
			# a gear for "by itself"
			for k in 8:
				var a := TAU * k / 8.0
				b.disc(Vector2(10, -10) * s + Vector2.from_angle(a) * 4.2 * s, 1.4 * s, METAL_DEEP)
			b.disc(Vector2(10, -10) * s, 3.8 * s, METAL_DEEP)
			b.disc(Vector2(10, -10) * s, 1.5 * s, Color("fcf7ef"))
		"belt":
			b.fan(Face.Builder.round_rect(Vector2(-14, -3) * s, Vector2(28, 8) * s, 4 * s), BELT)
			for k in 5:
				b.disc(Vector2(-10 + k * 5, 1) * s, 1.8 * s, METAL)
			b.stroke(PackedVector2Array([Vector2(-10, 6) * s, Vector2(-11, 13) * s]), 2 * s, WOOD_DEEP)
			b.stroke(PackedVector2Array([Vector2(10, 6) * s, Vector2(11, 13) * s]), 2 * s, WOOD_DEEP)
			egg(b, Vector2(-5, -8) * s, 5.0 * s)
			egg(b, Vector2(6, -8) * s, 5.0 * s)
			b.stroke(PackedVector2Array([Vector2(-2, -16) * s, Vector2(6, -16) * s]), 1.2 * s, INK)
			b.fan(PackedVector2Array([Vector2(6, -18.5) * s, Vector2(10, -16) * s, Vector2(6, -13.5) * s]), INK)
		"basket":
			for k in 3:
				egg(b, Vector2(-6 + k * 6, -5 - (k % 2) * 2) * s, 4.6 * s)
			var body := PackedVector2Array()
			for i in 13:
				var a := PI * i / 12.0
				body.append(Vector2(cos(a) * 12, -2 + sin(a) * 11) * s)
			b.polygon(body, WOOD)
			for k in 3:
				b.stroke(PackedVector2Array([Vector2(-11 + k, 1 + k * 3) * s, Vector2(11 - k, 1 + k * 3) * s]), 0.9 * s, WOOD_DEEP)
			b.stroke(Face.Builder.arc_points(Vector2(0, -2) * s, 12 * s, PI, TAU), 1.6 * s, WOOD_DEEP)
		"squirrel":
			_put(b, Look.SQUIRREL, s * 1.1, Vector2(2, 12) * s, 0)
		"washer":
			b.fan(Face.Builder.round_rect(Vector2(-12, -14) * s, Vector2(24, 14) * s, 3 * s), WASHER)
			b.fan(Face.Builder.round_rect(Vector2(-12, -14) * s, Vector2(24, 4) * s, 2 * s), WASHER_DEEP)
			for k in 5:
				b.stroke(PackedVector2Array([Vector2(-8 + k * 4, 1) * s, Vector2(-9 + k * 4, 6) * s]), 1.0 * s, WATER)
			egg(b, Vector2(0, 8) * s, 5.0 * s, false, false, true)
			for q in [Vector2(-8, 4), Vector2(9, 7), Vector2(6, 1)]:
				b.disc(q * s, 1.4 * s, Color(WATER, 0.8))
		"stamp":
			b.fan(Face.Builder.round_rect(Vector2(-4, -15) * s, Vector2(8, 10) * s, 2 * s), PRESS)
			b.fan(Face.Builder.round_rect(Vector2(-8, -6) * s, Vector2(16, 5) * s, 2 * s), PRESS_DEEP)
			egg(b, Vector2(0, 7) * s, 6.0 * s, false, false, true, true)
		"packer":
			egg(b, Vector2(0, 2) * s, 9.0 * s, false, false, true, true, true)
			b.stroke(PackedVector2Array([Vector2(-12, -9) * s, Vector2(-6, -13) * s]), 1.4 * s, CARTON_DEEP)
			b.stroke(PackedVector2Array([Vector2(12, -9) * s, Vector2(6, -13) * s]), 1.4 * s, CARTON_DEEP)
		"retire":
			# a deck chair under a sun hat of a sun
			b.disc(Vector2(8, -10) * s, 5.0 * s, Pal.SUN)
			b.stroke(PackedVector2Array([Vector2(-10, 12) * s, Vector2(2, -6) * s]), 1.8 * s, WOOD_DEEP)
			b.stroke(PackedVector2Array([Vector2(-2, -6) * s, Vector2(10, 12) * s]), 1.8 * s, WOOD_DEEP)
			b.fan(PackedVector2Array([Vector2(-6, -8) * s, Vector2(4, -8) * s, Vector2(8, 4) * s, Vector2(-4, 4) * s]), Color("e2645c"))
			b.fan(PackedVector2Array([Vector2(-3, -8) * s, Vector2(0, -8) * s, Vector2(4, 4) * s, Vector2(1, 4) * s]), Color("fffaf0"))
	var m := b.mesh()
	_icons[key] = m
	return m

## Bakes a cast member into a builder by copying its cached mesh's arrays,
## so an icon is one mesh.
static func _put(b: Face.Builder, look: int, u: float, at: Vector2, plume: int) -> void:
	var m := mesh(look, u, plume, 0)
	var arr := m.surface_get_arrays(0)
	var vs: PackedVector2Array = arr[Mesh.ARRAY_VERTEX]
	var cs: PackedColorArray = arr[Mesh.ARRAY_COLOR]
	var ix: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var base := b.verts.size()
	for i in vs.size():
		b.vertex(vs[i] + at, cs[i])
	for i in ix:
		b.idx.append(base + i)
