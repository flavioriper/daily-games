extends RefCounted

## Brittle's drawings: a square of nut brittle in six flavours and three
## states of cracked, the wedge, the popping candy, the things that lie in the
## tin, a sugar ball and the scoop. Each is built once, at CELL pixels to the
## cell, and set down by transform; nothing here is built twice.

const Face = preload("res://ui/faces/face.gd")
const Sim = preload("res://arcade/brittle_sim.gd")
const CozyTheme = preload("res://ui/theme.gd")

## A cell in the meshes' own pixels.
const CELL := 100.0
const BALL := 24.0
const INK := Color("2b1a16")
const CREAM := Color("fff6e4")
## The tin's floor and its rim.
const COCOA := Color("3a2823")
const RIM := Color("a9825a")
const RIM_DARK := Color("6e5138")
const RIM_LIT := Color("d8b488")
const DANGER := Color("ef6a55")
const SUGAR := Color("fff3d6")
## Softest number first: mint, lemon, apricot, raspberry, plum, blueberry.
const FLAVOUR := [Color("4fb79c"), Color("e3b73f"), Color("ee9440"), Color("dd5868"), Color("a45aa8"), Color("5a64c4")]
const PLUM := Color("e0548f")
const LACE := Color("3fbcd0")
const FIZZ := Color("f7d354")

static var _meshes := {}

static func font() -> Font:
	return CozyTheme.display(700)

## How hard a square is against the step it stands at: a flavour.
static func band(value: int, step_n: int) -> int:
	var t := float(value) / float(maxi(step_n, 1) * 2)
	return clampi(int(t * FLAVOUR.size()), 0, FLAVOUR.size() - 1)

## How broken: 0 whole, 1 cracked, 2 about to go.
static func crack(left: int, whole: int) -> int:
	var t := float(left) / float(maxi(whole, 1))
	return 0 if t > 0.66 else (1 if t > 0.33 else 2)

static func _cached(key: String, make: Callable) -> ArrayMesh:
	if not _meshes.has(key):
		var b := Face.Builder.new()
		make.call(b)
		_meshes[key] = b.mesh()
	return _meshes[key]

## A cell's piece, centred on the origin.
static func piece(what: int, flavour: int, cracked: int, turn: int) -> ArrayMesh:
	var key := "p%d_%d_%d_%d" % [what, flavour, cracked, turn]
	return _cached(key, func(b: Face.Builder) -> void: _piece(b, what, flavour, cracked, turn))

static func _piece(b: Face.Builder, what: int, flavour: int, cracked: int, turn: int) -> void:
	var col: Color = FLAVOUR[flavour]
	var h := Sim.HALF * CELL
	if what == Sim.Kind.SQUARE or what == Sim.Kind.POP:
		_slab(b, Face.Builder.round_rect(Vector2(-h, -h), Vector2(h, h) * 2.0, 15.0), col, h)
		_nuts(b, turn, col, what == Sim.Kind.POP)
		_cracks(b, cracked, turn)
		return
	var t: Array = Sim.triangle(what, Vector2.ZERO)
	var pts := PackedVector2Array()
	for p: Vector2 in t:
		pts.append(p * CELL)
	var mid := (pts[0] + pts[1] + pts[2]) / 3.0
	for k in 3:
		pts[k] = mid + (pts[k] - mid) * 0.97
	_slab(b, pts, col, h)
	# the nuts stand toward the right angle, where the number does not
	var nut := pts[0].lerp(mid, 0.5)
	b.ellipse(nut, 11.0, 7.0, col.lightened(0.42))
	b.ellipse(nut + (pts[1] - pts[0]).normalized() * 22.0, 7.0, 5.0, col.lightened(0.3))

## The thick edge, the face and the light across the top.
static func _slab(b: Face.Builder, pts: PackedVector2Array, col: Color, h: float) -> void:
	var low := PackedVector2Array()
	for p in pts:
		low.append(p + Vector2(0.0, 5.0))
	b.polygon(low, col.darkened(0.42))
	b.polygon(pts, col)
	var lit := PackedVector2Array()
	var mid := Vector2.ZERO
	for p in pts:
		mid += p / float(pts.size())
	for p in pts:
		lit.append(p + (mid - p).normalized() * 7.0 + Vector2(0.0, -2.0))
	b.stroke(lit, 3.0, Color(col.lightened(0.5), 0.55), true)
	b.polygon(_shrunk(pts, mid, 0.56), col.lerp(INK, 0.16))

static func _shrunk(pts: PackedVector2Array, mid: Vector2, k: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(mid + (p - mid) * k)
	return out

## Almonds round the edge, leaving the number its middle; popping candy wears
## sparks instead.
static func _nuts(b: Face.Builder, turn: int, col: Color, popping: bool) -> void:
	var spots := [Vector2(-31, -33), Vector2(32, -29), Vector2(-35, 30), Vector2(31, 34), Vector2(3, -36)]
	for k in spots.size():
		var at: Vector2 = spots[(k + turn) % spots.size()]
		if popping:
			var s := PackedVector2Array()
			for n in 8:
				s.append(at + Vector2.from_angle(TAU * n / 8.0) * (10.0 if n % 2 == 0 else 4.0))
			b.polygon(s, FIZZ)
		else:
			b.ellipse(at, 8.0 - (k % 2) * 2.0, 5.0, col.lightened(0.42))

## The cracks: marks, never a shade of the piece.
static func _cracks(b: Face.Builder, cracked: int, turn: int) -> void:
	if cracked == 0:
		return
	var a := -1.0 if turn % 2 == 0 else 1.0
	b.stroke(PackedVector2Array([Vector2(-44.0 * a, -18), Vector2(-27.0 * a, -8), Vector2(-33.0 * a, 8), Vector2(-20.0 * a, 15)]), 3.5, Color(INK, 0.7))
	if cracked == 2:
		b.stroke(PackedVector2Array([Vector2(44.0 * a, 20), Vector2(26.0 * a, 26), Vector2(30.0 * a, 43)]), 3.5, Color(INK, 0.7))
		b.stroke(PackedVector2Array([Vector2(10.0 * a, -45), Vector2(16.0 * a, -29), Vector2(30.0 * a, -24)]), 3.5, Color(INK, 0.7))

## What lies in the tin and is not struck but passed through.
static func item(what: int) -> ArrayMesh:
	return _cached("i%d" % what, func(b: Face.Builder) -> void: _item(b, what))

static func _item(b: Face.Builder, what: int) -> void:
	match what:
		Sim.Kind.PLUS:
			b.stroke(Face.Builder.ring(Vector2.ZERO, 36.0, 36.0), 5.0, Color(PLUM.lightened(0.3), 0.75), true)
			b.disc(Vector2(0, 2), 25.0, PLUM.darkened(0.3))
			b.disc(Vector2.ZERO, 25.0, PLUM)
			b.polygon(Face.Builder.round_rect(Vector2(-14, -4), Vector2(28, 8), 3.0), CREAM)
			b.polygon(Face.Builder.round_rect(Vector2(-4, -14), Vector2(8, 28), 3.0), CREAM)
		Sim.Kind.ROW, Sim.Kind.COL:
			var along := Vector2.RIGHT if what == Sim.Kind.ROW else Vector2.DOWN
			var across := along.orthogonal()
			b.stroke(Face.Builder.ring(Vector2.ZERO, 36.0, 36.0), 5.0, Color(LACE.lightened(0.3), 0.75), true)
			b.disc(Vector2.ZERO, 27.0, LACE.darkened(0.45))
			for s in [-1.0, 1.0]:
				var tip: Vector2 = along * 24.0 * s
				var back: Vector2 = along * 8.0 * s
				b.polygon(PackedVector2Array([tip, back + across * 12.0, back - across * 12.0]), CREAM)
			b.stroke(PackedVector2Array([along * -10.0, along * 10.0]), 7.0, CREAM)
		Sim.Kind.FIZZ:
			b.stroke(Face.Builder.ring(Vector2.ZERO, 36.0, 36.0), 5.0, Color(FIZZ, 0.65), true)
			var s := PackedVector2Array()
			for n in 16:
				s.append(Vector2.from_angle(TAU * n / 16.0) * (27.0 if n % 2 == 0 else 13.0))
			b.polygon(s, FIZZ)
			b.disc(Vector2.ZERO, 7.0, CREAM)

## A sugar ball, BALL pixels in radius: the transform sizes it. The edge's
## feather is in pixels, so a ball built at radius 1 comes out a blur.
static func ball() -> ArrayMesh:
	return _cached("ball", func(b: Face.Builder) -> void:
		b.disc(Vector2(0.0, BALL * 0.14), BALL, Color("b98f61"))
		b.disc(Vector2.ZERO, BALL, SUGAR)
		b.disc(Vector2(-0.3, -0.34) * BALL, BALL * 0.34, Color.WHITE))

## The scoop the stream leaves from, its lip on the origin.
static func scoop() -> ArrayMesh:
	return _cached("scoop", func(b: Face.Builder) -> void:
		var bowl := Face.Builder.arc_points(Vector2.ZERO, 34.0, 0.0, PI)
		b.polygon(bowl, RIM_DARK)
		var inner := Face.Builder.arc_points(Vector2(0.0, -2.0), 28.0, 0.0, PI)
		b.polygon(inner, RIM)
		b.stroke(PackedVector2Array([Vector2(-37, 0), Vector2(37, 0)]), 7.0, RIM_LIT))

## The tin: the rim, the cocoa floor with the cut lines of the slab on it,
## the line of the last row and the lane over the floor.
static func tin(b: Face.Builder, o: Vector2, cell: float) -> void:
	var inner := Vector2(Sim.W, Sim.FLOOR) * cell
	var rim := 16.0
	b.polygon(Face.Builder.round_rect(o - Vector2(rim, rim) + Vector2(0, 8), inner + Vector2(rim, rim) * 2.0, 34.0), Color(INK, 0.45))
	b.polygon(Face.Builder.round_rect(o - Vector2(rim, rim), inner + Vector2(rim, rim) * 2.0, 34.0), RIM_DARK)
	b.polygon(Face.Builder.round_rect(o - Vector2(rim, rim) * 0.72, inner + Vector2(rim, rim) * 1.44, 28.0), RIM)
	b.polygon(Face.Builder.round_rect(o - Vector2(rim, rim) * 0.3, inner + Vector2(rim, rim) * 0.6, 22.0), RIM_DARK)
	b.polygon(Face.Builder.round_rect(o, inner, 18.0), COCOA)
	for c in range(1, Sim.COLS):
		var x := o.x + c * cell
		b.stroke(PackedVector2Array([Vector2(x, o.y + 8.0), Vector2(x, o.y + Sim.ROWS * cell)]), 2.0, Color(CREAM, 0.05), false, false)
	for r in range(1, Sim.ROWS):
		var y := o.y + r * cell
		b.stroke(PackedVector2Array([Vector2(o.x + 8.0, y), Vector2(o.x + inner.x - 8.0, y)]), 2.0, Color(CREAM, 0.05), false, false)
	var y := o.y + Sim.ROWS * cell
	var x := o.x + 10.0
	while x < o.x + inner.x - 16.0:
		b.stroke(PackedVector2Array([Vector2(x, y), Vector2(x + 14.0, y)]), 3.0, Color(DANGER, 0.45), false, false)
		x += 26.0
