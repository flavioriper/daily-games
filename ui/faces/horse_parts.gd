extends RefCounted

## Horse Pen's drawings: builder shapes, not Controls -- the board bakes its
## field into a few meshes, and the menu card and the tutorial draw the same
## pieces (ui/faces/patch_cloth.gd's reason). Everything is drawn about a
## cell's centre `at` in a cell of `s` pixels.
##
## The horse is the one creature on the board, a chestnut pony seen from the
## side with a flaxen mane and tail (core/palette.gd says why chestnut). Its
## looks are the family's (ui/faces/face.gd's Expr); its head turns about the
## neck (`nod`), so a shake of the head is the head alone.

const Pal = preload("res://core/palette.gd")
const Face = preload("res://ui/faces/face.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

const HIDE_DEEP := Color("6f3d20")
const HIDE_LIGHT := Color("a8683c")
const MUZZLE := Color("e9cfae")
const HOOF := Color("4a3424")
const STRAW_DEEP := Color("c99a3c")
const STRAW_LIGHT := Color("f4d27e")
const BOULDER_LIGHT := Color("b7bfc6")
const BOULDER_DEEP := Color("7d8890")
const WATER := Color("8fcdea")
const WATER_DEEP := Color("6fb4d8")
const WATER_HI := Color("c9eaf8")
const GOLD := Color("f6c53c")
const GOLD_DEEP := Color("d99a1c")
const GOLD_HI := Color("fff0b0")
const HIVE := Color("e6b450")
const HIVE_DEEP := Color("b98228")
const BEE_BODY := Color("f4cf4a")
const BEE_WING := Color(1.0, 1.0, 1.0, 0.75)
const TUNNEL_EARTH := Color("8a6a4a")
const TUNNEL_DARK := Color("3d2c20")

static func _hash(a: int, b: int) -> float:
	var hh := (a * 374761393 + b * 668265263) ^ (a * b * 1274126177)
	hh = (hh ^ (hh >> 13)) * 1274126177
	return float((hh ^ (hh >> 16)) & 0x7fffffff) / float(0x7fffffff)

static func _turned(pts: PackedVector2Array, pivot: Vector2, angle: float) -> PackedVector2Array:
	if angle == 0.0:
		return pts
	var xf := Transform2D(angle, pivot) * Transform2D(0.0, -pivot)
	return xf * pts

## The horse standing on `at`, facing right (`flip` turns it). `expr` is a
## Face.Expr, `eye` how open the eye is (a blink), `nod` the head's turn in
## radians about the neck, `kick` 0 to 1 the hind legs thrown back, `tail`
## the tail's swish in radians.
static func horse(b: Face.Builder, at: Vector2, s: float, expr := 0, eye := 1.0,
		nod := 0.0, kick := 0.0, tail := 0.0, flip := false) -> void:
	var sx := -1.0 if flip else 1.0
	var P := func(x: float, y: float) -> Vector2: return at + Vector2(x * sx, y) * s
	var neck: Vector2 = P.call(0.13, -0.06)
	var turn := nod * sx
	# The tail, behind everything: a flaxen plume from the rump.
	var root: Vector2 = P.call(-0.3, -0.02)
	var plume := Face.Builder.bezier3(root, P.call(-0.46, -0.02), P.call(-0.5, 0.2), P.call(-0.4, 0.3), 10)
	plume.append_array(Face.Builder.bezier3(P.call(-0.4, 0.3), P.call(-0.36, 0.18), P.call(-0.33, 0.1), P.call(-0.27, 0.06), 10))
	b.polygon(_turned(plume if not flip else _reversed(plume), root, tail * sx), Pal.MANE)
	# The far legs, darker; then the body; then the near legs.
	var back := kick * 0.5
	_leg(b, P.call(-0.2, 0.12), P.call(-0.24 - back * 0.3, 0.38 - back * 0.1), s, HIDE_DEEP)
	_leg(b, P.call(0.1, 0.12), P.call(0.08, 0.38), s, HIDE_DEEP)
	b.ellipse(P.call(-0.06, 0.04), 0.27 * s, 0.185 * s, Pal.HIDE)
	b.ellipse(P.call(-0.1, -0.03), 0.17 * s, 0.07 * s, HIDE_LIGHT)
	_leg(b, P.call(-0.13, 0.14), P.call(-0.15 - back * 0.4, 0.4 - back * 0.14), s, Pal.HIDE)
	_leg(b, P.call(0.16, 0.14), P.call(0.17, 0.4), s, Pal.HIDE)
	# The neck and the head turn together about the neck's foot.
	var neck_pts := PackedVector2Array([P.call(0.03, -0.08), P.call(0.16, -0.36), P.call(0.3, -0.3), P.call(0.22, 0.06)])
	b.polygon(_turned(neck_pts if not flip else _reversed(neck_pts), neck, turn), Pal.HIDE)
	var mane := Face.Builder.bezier3(P.call(0.2, -0.44), P.call(0.06, -0.42), P.call(-0.02, -0.2), P.call(0.02, -0.04), 10)
	mane.append_array(Face.Builder.bezier3(P.call(0.02, -0.04), P.call(0.08, -0.14), P.call(0.12, -0.28), P.call(0.24, -0.36), 10))
	b.polygon(_turned(mane if not flip else _reversed(mane), neck, turn), Pal.MANE)
	var head: Vector2 = P.call(0.26, -0.3)
	var ear := PackedVector2Array([P.call(0.17, -0.4), P.call(0.2, -0.56), P.call(0.27, -0.42)])
	b.polygon(_turned(ear if not flip else _reversed(ear), neck, turn), HIDE_DEEP)
	b.fan(_turned(_tilted(head, 0.17 * s, 0.13 * s, 0.35 * sx), neck, turn), Pal.HIDE)
	b.fan(_turned(_tilted(P.call(0.37, -0.22), 0.1 * s, 0.085 * s, 0.35 * sx), neck, turn), MUZZLE)
	var nostril := _turned(PackedVector2Array([P.call(0.42, -0.21)]), neck, turn)[0]
	b.disc(nostril, 0.014 * s, HOOF)
	var lock := Face.Builder.bezier2(P.call(0.18, -0.44), P.call(0.3, -0.5), P.call(0.33, -0.36), 8)
	lock.append_array(Face.Builder.bezier2(P.call(0.33, -0.36), P.call(0.27, -0.42), P.call(0.18, -0.44), 8))
	b.polygon(_turned(lock if not flip else _reversed(lock), neck, turn), Pal.MANE)
	# The eye: the family's looks, on a face seen from the side.
	var eye_at := _turned(PackedVector2Array([P.call(0.27, -0.31)]), neck, turn)[0]
	var r := 0.034 * s
	match expr:
		Face.Expr.JOY:
			b.stroke(_turned_arc(eye_at, r * 1.15, PI * 1.15, PI * 1.85), r * 0.7, Pal.HORSE_EYE)
		Face.Expr.SLEEPY:
			b.stroke(_turned_arc(eye_at, r * 1.15, PI * 0.15, PI * 0.85), r * 0.7, Pal.HORSE_EYE)
		_:
			var open := maxf(0.12, eye)
			b.ellipse(eye_at, r, r * open, Pal.HORSE_EYE)
			if open > 0.6:
				b.disc(eye_at + Vector2(-0.3, -0.35) * r, r * 0.34, Color.WHITE)
			if expr == Face.Expr.WORRIED or expr == Face.Expr.STRAIN or expr == Face.Expr.PUZZLED:
				var brow_a := eye_at + Vector2(-1.6 * sx, -1.5) * r
				var brow_b := eye_at + Vector2(1.2 * sx, -2.3) * r
				b.stroke(PackedVector2Array([brow_a, brow_b]), r * 0.55, HIDE_DEEP)
	b.disc(eye_at + Vector2(0.06 * sx, 0.075) * s, 0.03 * s, Color(Pal.FLOWER, 0.55))

static func _reversed(pts: PackedVector2Array) -> PackedVector2Array:
	var out := pts.duplicate()
	out.reverse()
	return out

static func _tilted(centre: Vector2, rx: float, ry: float, angle: float) -> PackedVector2Array:
	return Transform2D(angle, centre) * Face.Builder.ring(Vector2.ZERO, rx, ry)

static func _turned_arc(centre: Vector2, r: float, from: float, to: float) -> PackedVector2Array:
	return Face.Builder.arc_points(centre, r, from, to)

static func _leg(b: Face.Builder, hip: Vector2, foot: Vector2, s: float, colour: Color) -> void:
	b.stroke(PackedVector2Array([hip, foot]), 0.085 * s, colour)
	b.stroke(PackedVector2Array([foot.lerp(hip, 0.12), foot]), 0.09 * s, HOOF)

## The soft shadow a thing of `wide` cells casts on the ground under `at`.
static func shade(b: Face.Builder, at: Vector2, s: float, wide := 0.34, alpha := 0.2) -> void:
	Scenery.soft_disc(b, at + Vector2(0.0, 0.36 * s), wide * s, 0.1 * s, Color(Pal.TEXT, alpha))

## A hay bale: a top, a front and two straps, so a row of them is a wall and
## not a dotted line. `old` is a bale a hint dropped, in older straw.
static func bale(b: Face.Builder, at: Vector2, s: float, old := false) -> void:
	var top := Pal.STRAW_LOCK if old else Pal.STRAW
	var front := Pal.STRAW_LOCK.darkened(0.14) if old else STRAW_DEEP
	var half := 0.37 * s
	var body := Vector2(2.0 * half, 2.0 * half)
	b.fan(Face.Builder.round_rect(at - Vector2(half, half * 0.82), body * Vector2(1.0, 0.96), 0.09 * s), front)
	b.fan(Face.Builder.round_rect(at - Vector2(half, half), body * Vector2(1.0, 0.7), 0.09 * s), top)
	# Straw: a few pale strokes along the top.
	for k in 3:
		var y := at.y - half + (0.2 + 0.2 * k) * s * 0.74
		var x0 := at.x - half * (0.62 - 0.2 * (k % 2))
		b.stroke(PackedVector2Array([Vector2(x0, y), Vector2(x0 + half * 0.5, y)]), 0.02 * s,
			Color(STRAW_LIGHT if not old else Pal.STRAW, 0.9))
	for sx in [-0.42, 0.42]:
		var x: float = at.x + sx * half
		b.stroke(PackedVector2Array([Vector2(x, at.y - half + 0.03 * s), Vector2(x, at.y + half * 0.9)]),
			0.045 * s, Pal.STRAP, false, false)

## A boulder: fixed stone, rounder and cooler than anything the player lays,
## leaned and sized by its cell so no two lie alike, with moss on its crown.
static func boulder(b: Face.Builder, at: Vector2, s: float, cell := 0) -> void:
	var grow := 0.92 + 0.14 * _hash(cell, 3)
	var pts := PackedVector2Array()
	for k in 14:
		var a := TAU * k / 14.0
		var rr := (0.36 + 0.05 * _hash(cell * 17 + k, 5)) * grow
		pts.append(at + Vector2(cos(a) * rr * 1.05, sin(a) * rr * 0.8 + 0.06) * s)
	b.polygon(pts, BOULDER_DEEP)
	var crown := PackedVector2Array()
	for k in 14:
		var a := TAU * k / 14.0
		var rr := (0.3 + 0.04 * _hash(cell * 17 + k, 5)) * grow
		crown.append(at + Vector2(cos(a) * rr * 1.02 - 0.02, sin(a) * rr * 0.68 - 0.04) * s)
	b.polygon(crown, Pal.BOULDER)
	b.ellipse(at + Vector2(-0.1, -0.14) * s, 0.13 * s * grow, 0.06 * s, BOULDER_LIGHT)
	b.ellipse(at + Vector2(0.1, -0.2) * s * grow, 0.1 * s, 0.045 * s, Pal.MOSS)

## An apple: three more points in the pen.
static func apple(b: Face.Builder, at: Vector2, s: float, golden := false) -> void:
	var skin := GOLD if golden else Pal.FRUIT
	var deep := GOLD_DEEP if golden else Pal.BERRY_DEEP
	var r := (0.24 if golden else 0.2) * s
	b.ellipse(at + Vector2(0.0, 0.07 * s), r * 1.02, r * 0.95, deep)
	b.ellipse(at + Vector2(-0.01 * s, 0.04 * s), r * 0.96, r * 0.9, skin)
	b.ellipse(at + Vector2(-0.35, -0.2) * r + Vector2(0.0, 0.04 * s), r * 0.3, r * 0.2,
		Color(GOLD_HI if golden else Color.WHITE, 0.6))
	b.stroke(PackedVector2Array([at + Vector2(0.0, -0.8) * r + Vector2(0.0, 0.05 * s),
		at + Vector2(0.12, -1.25) * r]), 0.035 * s, Pal.STEM)
	b.ellipse(at + Vector2(0.42, -1.12) * r, r * 0.34, r * 0.16, Pal.APPLE_LEAF)
	if golden:
		for k in 4:
			var a := TAU * k / 4.0 + 0.5
			var p := at + Vector2(cos(a), sin(a) * 0.9) * r * 1.45 + Vector2(0.0, 0.04 * s)
			b.fan(PackedVector2Array([p + Vector2(0.0, -0.05 * s), p + Vector2(0.018 * s, 0.0),
				p + Vector2(0.0, 0.05 * s), p + Vector2(-0.018 * s, 0.0)]), GOLD_HI)

## A beehive on the grass: five fewer points in the pen. The bees round it
## are the board's (`bee`), since they fly.
static func hive(b: Face.Builder, at: Vector2, s: float) -> void:
	for k in 4:
		var y := 0.2 - 0.13 * k
		var rx := 0.27 - 0.045 * k - (0.03 if k == 0 else 0.0)
		b.ellipse(at + Vector2(0.0, y) * s, rx * s, 0.085 * s, HIVE_DEEP if k % 2 == 0 else HIVE)
	b.ellipse(at + Vector2(0.0, -0.27) * s, 0.09 * s, 0.06 * s, HIVE)
	b.ellipse(at + Vector2(0.0, 0.14) * s, 0.06 * s, 0.07 * s, TUNNEL_DARK)

## One bee about `at`, `r` its body's half length, wings at `beat` (0 to 1).
static func bee(b: Face.Builder, at: Vector2, r: float, beat := 1.0) -> void:
	b.ellipse(at + Vector2(-0.2, -0.9) * r, r * 0.6, r * (0.35 + 0.35 * beat), BEE_WING)
	b.ellipse(at + Vector2(0.4, -0.9) * r, r * 0.55, r * (0.3 + 0.35 * beat), BEE_WING)
	b.ellipse(at, r, r * 0.72, BEE_BODY)
	b.stroke(PackedVector2Array([at + Vector2(-0.15, -0.6) * r, at + Vector2(-0.15, 0.6) * r]), r * 0.3, Pal.HORSE_EYE, false, false)
	b.stroke(PackedVector2Array([at + Vector2(0.4, -0.5) * r, at + Vector2(0.4, 0.5) * r]), r * 0.26, Pal.HORSE_EYE, false, false)

## A tunnel's mouth: an earth mound with a dark arch and a ribbon of `tint`,
## the same on both mouths of a pair.
static func tunnel(b: Face.Builder, at: Vector2, s: float, tint: Color) -> void:
	var mound := Face.Builder.arc_points(at + Vector2(0.0, 0.3 * s), 0.4 * s, PI, TAU)
	b.polygon(mound, TUNNEL_EARTH)
	b.ellipse(at + Vector2(0.0, 0.3 * s), 0.4 * s, 0.07 * s, TUNNEL_EARTH)
	var arch := Face.Builder.arc_points(at + Vector2(0.0, 0.3 * s), 0.25 * s, PI, TAU)
	b.polygon(arch, TUNNEL_DARK)
	b.ellipse(at + Vector2(0.0, 0.3 * s), 0.25 * s, 0.045 * s, TUNNEL_DARK)
	b.stroke(Face.Builder.arc_points(at + Vector2(0.0, 0.3 * s), 0.325 * s, PI * 1.08, PI * 1.92), 0.055 * s, tint)
	b.ellipse(at + Vector2(-0.2, -0.04) * s, 0.09 * s, 0.035 * s, Pal.MOSS)

## The wheat on a cell the horse can reach: a pale wash and three stalks.
## Built once about the origin for a cell of `s`; the board moves and grows it.
static func wheat(b: Face.Builder, s: float, inset: float, radius: float) -> void:
	var span := s - 2.0 * inset
	b.fan(Face.Builder.round_rect(-Vector2.ONE * span * 0.5, Vector2.ONE * span, radius), Pal.TURF_REACH)
	for k in 3:
		var x := (-0.28 + 0.28 * k) * s
		var foot := Vector2(x, (0.36 - 0.05 * (k % 2)) * s)
		var tip := foot + Vector2(0.03 * (k - 1), -0.2) * s
		b.stroke(PackedVector2Array([foot, tip]), 0.022 * s, Pal.WHEAT)
		b.fan(_tilted(tip, 0.03 * s, 0.065 * s, 0.15 * (k - 1)), Pal.WHEAT)

## A bloom on a penned cell at the win: five petals round a pale eye.
static func bloom(b: Face.Builder, at: Vector2, r: float, colour: Color) -> void:
	for k in 5:
		var a := TAU * k / 5.0 - PI * 0.5
		b.disc(at + Vector2(cos(a), sin(a)) * r, r * 0.75, colour)
	b.disc(at, r * 0.6, Pal.FLOWER_EYE)

## The water of the field `w` by `h` (`is_water` a byte a cell) with its
## top-left at `o`: a channel sunk in the turf, the far bank's cut earth along
## every top edge and the water lying a little below it. A rounded square a
## cell and a plain bar across every join, so only a stream's own corners are
## round and two streams that meet read as one.
static func water(b: Face.Builder, is_water: Callable, w: int, h: int, o: Vector2, s: float) -> void:
	var inset := 0.05 * s
	var round := 0.2 * s
	var bank := 0.1 * s
	for layer in 3:
		var colour: Color = [Pal.CUT_EARTH, WATER_DEEP, WATER][layer]
		var top: float = [0.0, bank, bank + 0.05 * s][layer]
		for i in w * h:
			if not is_water.call(i):
				continue
			var x := i % w
			var y := i / w
			var up: bool = y > 0 and is_water.call(i - w)
			var at := o + Vector2(x, y) * s + Vector2(inset, inset + (0.0 if up else top))
			var size := Vector2(s - 2.0 * inset, s - 2.0 * inset - (0.0 if up else top))
			b.fan(Face.Builder.round_rect(at, size, round), colour)
			if x < w - 1 and is_water.call(i + 1):
				var up2: bool = y > 0 and is_water.call(i + 1 - w)
				var t := maxf(0.0 if up else top, 0.0 if up2 else top)
				b.fan(PackedVector2Array([o + Vector2(x + 0.5, y) * s + Vector2(0.0, inset + t),
					o + Vector2(x + 1.5, y) * s + Vector2(0.0, inset + t),
					o + Vector2(x + 1.5, y + 1) * s - Vector2(0.0, inset),
					o + Vector2(x + 0.5, y + 1) * s - Vector2(0.0, inset)]), colour)
			if y < h - 1 and is_water.call(i + w):
				b.fan(PackedVector2Array([o + Vector2(x, y + 0.5) * s + Vector2(inset, 0.0),
					o + Vector2(x + 1, y + 0.5) * s - Vector2(inset, 0.0),
					o + Vector2(x + 1, y + 1.5) * s - Vector2(inset, 0.0),
					o + Vector2(x, y + 1.5) * s + Vector2(inset, 0.0)]), colour)
	# A glint or two a cell, by the cell's own lot.
	for i in w * h:
		if not is_water.call(i):
			continue
		var c := o + Vector2(i % w + 0.5, i / w + 0.5) * s
		var lot := _hash(i, 11)
		var p := c + Vector2(lot - 0.5, _hash(i, 13) * 0.3 + 0.05) * s * 0.5
		b.stroke(PackedVector2Array([p, p + Vector2(0.16 * s, 0.0)]), 0.03 * s, WATER_HI)
		if lot > 0.5:
			b.stroke(PackedVector2Array([p + Vector2(-0.12, 0.14) * s, p + Vector2(-0.02, 0.14) * s]), 0.025 * s, WATER_HI)

## An ear of wheat for the score's pill: a stalk and its grains.
static func wheat_ear(b: Face.Builder, at: Vector2, s: float, colour: Color) -> void:
	b.stroke(PackedVector2Array([at + Vector2(-0.08, 0.36) * s, at + Vector2(0.02, -0.1) * s]), 0.06 * s, colour)
	for k in 3:
		var p := at + Vector2(0.0, 0.08 - 0.15 * k) * s
		b.fan(_tilted(p + Vector2(-0.1, 0.0) * s, 0.06 * s, 0.11 * s, -0.5), colour)
		b.fan(_tilted(p + Vector2(0.12, -0.02) * s, 0.06 * s, 0.11 * s, 0.5), colour)
	b.fan(_tilted(at + Vector2(0.03, -0.36) * s, 0.06 * s, 0.11 * s, 0.05), colour)
