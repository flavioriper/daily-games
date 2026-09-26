extends RefCounted

## Knight's pieces as builder shapes, shared by the board
## (puzzles/knight2d.gd) and its menu card (ui/menu/card_art.gd), so the two
## cannot drift apart: a carved knight for either side, and the rose king.
##
## Everything is in pixels, sized off `s`, the cell. A piece is drawn in a
## unit box PIECE cells wide, standing STAND cells above the square's centre
## so its ear can rise into the square behind. Ported from the concept
## page's mock (docs/brainstorm/concepts.html#knight).

const Pal = preload("res://core/palette.gd")
const Face = preload("res://ui/faces/face.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

const PIECE := 1.25
const STAND := 0.04
const CREAM := 0
const ROSE := 1

static var _outline := PackedVector2Array()

## The knight's head and neck in unit coordinates, looking left: one soft
## outline from the back of the plinth, up the mane, over the ear, down the
## nose to the muzzle, and back under the jaw.
static func _knight_outline() -> PackedVector2Array:
	if not _outline.is_empty():
		return _outline
	var pts := PackedVector2Array()
	var at := Vector2(0.2, 0.18)
	# each segment: [control or null for a straight line, end]
	var segs := [
		[Vector2(0.26, -0.04), Vector2(0.16, -0.2)],
		[Vector2(0.1, -0.32), Vector2(0.04, -0.36)],
		[null, Vector2(0.03, -0.44)],
		[null, Vector2(-0.05, -0.35)],
		[Vector2(-0.2, -0.3), Vector2(-0.29, -0.13)],
		[Vector2(-0.33, -0.03), Vector2(-0.25, 0.0)],
		[Vector2(-0.16, 0.01), Vector2(-0.1, -0.05)],
		[Vector2(-0.14, 0.08), Vector2(-0.2, 0.18)],
	]
	for seg: Array in segs:
		if seg[0] == null:
			pts.append(at)
		else:
			pts.append_array(Face.Builder.bezier2(at, seg[0], seg[1], 8))
		at = seg[1]
	pts.append(at)
	_outline = pts
	return pts

static func _mapped(pts: PackedVector2Array, map: Callable) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(pts.size())
	for i in pts.size():
		out[i] = map.call(pts[i])
	return out

## A carved knight on the square centred at `at`. `side` is CREAM or ROSE;
## `look` -1 looks left, 1 right; `lift` raises it in pixels (its shadow
## shrinks under it); `sq` squashes it (a landing, an entrance, a take);
## `joy` shuts its eye in a smile; `alpha` fades it (a taken one, the ghost
## under a catch).
static func knight(b: Face.Builder, at: Vector2, s: float, side: int, look: float, lift := 0.0,
		sq := Vector2.ONE, joy := false, alpha := 1.0) -> void:
	var col: Color = Pal.KNIGHT_CREAM if side == CREAM else Pal.KNIGHT_ROSE
	var deep: Color = Pal.KNIGHT_CREAM_DEEP if side == CREAM else Pal.KNIGHT_ROSE_DEEP
	var line: Color = Pal.KNIGHT_CREAM_LINE if side == CREAM else Pal.KNIGHT_ROSE_LINE
	var up := clampf(lift / s, 0.0, 1.0)
	Scenery.soft_disc(b, at + Vector2(0.0, s * 0.33), s * (0.3 - up * 0.08), s * 0.08,
		Color(Pal.TEXT, (0.2 - up * 0.12) * alpha))
	var u := s * PIECE
	var o := at + Vector2(0.0, -lift - s * STAND)
	var flip := -look
	var map := func(p: Vector2) -> Vector2: return o + Vector2(p.x * flip * sq.x, p.y * sq.y) * u
	var shape := func(pts: PackedVector2Array) -> PackedVector2Array:
		var m := _mapped(pts, map)
		if flip < 0.0:
			m.reverse()
		return m
	b.fan(shape.call(Face.Builder.round_rect(Vector2(-0.3, 0.2), Vector2(0.6, 0.14), 0.06)), Color(deep, alpha))
	b.fan(shape.call(Face.Builder.round_rect(Vector2(-0.3, 0.17), Vector2(0.6, 0.12), 0.06)), Color(col, alpha))
	var body: PackedVector2Array = shape.call(_knight_outline())
	b.polygon(body, Color(col, alpha))
	b.stroke(body, u * 0.028, Color(line, alpha), true)
	# the mane: three soft strokes down the back of the neck
	for i in 3:
		var yy := -0.28 + float(i) * 0.13
		var x0 := 0.1 + float(i) * 0.03
		var curve := Face.Builder.bezier2(Vector2(x0, yy), Vector2(0.19 + float(i) * 0.02, yy + 0.05),
			Vector2(0.15 + float(i) * 0.03, yy + 0.1), 6)
		curve.append(Vector2(0.15 + float(i) * 0.03, yy + 0.1))
		b.stroke(_mapped(curve, map), u * 0.05, Color(deep, 0.9 * alpha))
	# the face: an eye with a glint (a smile when joyful), a blush, a nostril
	if joy:
		b.stroke(_mapped(Face.Builder.arc_points(Vector2(-0.1, -0.19), 0.035, PI * 1.1, PI * 1.9), map),
			u * 0.022, Color(line, alpha))
	else:
		b.ellipse(map.call(Vector2(-0.1, -0.2)), u * 0.03 * sq.x, u * 0.036 * sq.y, Color(line, alpha))
		b.disc(map.call(Vector2(-0.11, -0.215)), u * 0.011, Color(1.0, 1.0, 1.0, 0.9 * alpha))
	b.ellipse(map.call(Vector2(-0.14, -0.1)), u * 0.045 * sq.x, u * 0.028 * sq.y, Color(Pal.CHEEK, 0.75 * alpha))
	b.disc(map.call(Vector2(-0.265, -0.06)), u * 0.012, Color(line, alpha))

## The rose king on the square centred at `at`: a rounded body under a gold
## three-point crown with a sleepy face. `tip` tips him over about his foot
## (the win, negative to the left); `scale` is his entrance; `fallen` crosses
## his eyes.
static func king(b: Face.Builder, at: Vector2, s: float, tip := 0.0, scale := 1.0, fallen := false) -> void:
	Scenery.soft_disc(b, at + Vector2(0.0, s * 0.33), s * 0.3, s * 0.08, Color(Pal.TEXT, 0.2))
	var u := s * PIECE * scale
	var foot := at + Vector2(0.0, s * 0.3)
	var lift := Vector2(0.0, -s * (0.3 + STAND))
	var map := func(p: Vector2) -> Vector2: return foot + (lift + p * u).rotated(tip)
	b.fan(_mapped(Face.Builder.round_rect(Vector2(-0.3, 0.2), Vector2(0.6, 0.14), 0.06), map), Pal.KNIGHT_ROSE_DEEP)
	b.fan(_mapped(Face.Builder.round_rect(Vector2(-0.3, 0.17), Vector2(0.6, 0.12), 0.06), map), Pal.KNIGHT_ROSE)
	var body := Face.Builder.bezier2(Vector2(-0.2, 0.18), Vector2(-0.27, -0.06), Vector2(-0.14, -0.16), 8)
	body.append(Vector2(-0.14, -0.16))
	body.append_array(Face.Builder.bezier2(Vector2(0.14, -0.16), Vector2(0.27, -0.06), Vector2(0.2, 0.18), 8))
	body.append(Vector2(0.2, 0.18))
	var bp := _mapped(body, map)
	b.fan(bp, Pal.KNIGHT_ROSE)
	b.stroke(bp, u * 0.028, Pal.KNIGHT_ROSE_LINE, true)
	b.fan(_mapped(Face.Builder.round_rect(Vector2(-0.18, -0.2), Vector2(0.36, 0.07), 0.03), map), Pal.KNIGHT_ROSE_DEEP)
	var crown := _mapped(PackedVector2Array([Vector2(-0.17, -0.2), Vector2(-0.19, -0.37), Vector2(-0.08, -0.28),
		Vector2(0.0, -0.42), Vector2(0.08, -0.28), Vector2(0.19, -0.37), Vector2(0.17, -0.2)]), map)
	b.polygon(crown, Pal.CROWN)
	b.stroke(crown, u * 0.022, Pal.CROWN_DEEP, true)
	b.disc(map.call(Vector2(0.0, -0.43)), u * 0.03, Pal.CROWN_DEEP)
	b.disc(map.call(Vector2(-0.19, -0.38)), u * 0.022, Pal.CROWN_DEEP)
	b.disc(map.call(Vector2(0.19, -0.38)), u * 0.022, Pal.CROWN_DEEP)
	var ey := -0.04
	for sx: float in [-1.0, 1.0]:
		var e := Vector2(sx * 0.075, ey)
		if fallen:
			b.stroke(_mapped(PackedVector2Array([e + Vector2(-0.025, -0.02), e + Vector2(0.025, 0.02)]), map), u * 0.02, Pal.KNIGHT_ROSE_LINE)
			b.stroke(_mapped(PackedVector2Array([e + Vector2(-0.025, 0.02), e + Vector2(0.025, -0.02)]), map), u * 0.02, Pal.KNIGHT_ROSE_LINE)
		else:
			b.ellipse(map.call(e), u * 0.022, u * 0.028, Pal.KNIGHT_ROSE_LINE)
		b.ellipse(map.call(Vector2(sx * 0.13, ey + 0.06)), u * 0.04, u * 0.025, Color(Pal.CHEEK, 0.8))
