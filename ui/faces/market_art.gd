extends RefCounted

## Market Sums' drawings: the wooden crate a number stands in, its paper
## label, the sun halo of a crate picked up, the round wooden sign tokens
## (+, take away, times, share) and the chalk order board hung from the
## awning. Builder shapes, not Controls: the board, the menu card and the
## tutorial draw the same pieces. The numerals are the caller's (a
## draw_string each, never baked); the signs' marks are shapes, so no font
## has to carry them.

const Pal = preload("res://core/palette.gd")
const Face = preload("res://ui/faces/face.gd")
const Scenery = preload("res://ui/flat/scenery.gd")
const Gen = preload("res://puzzles/market_gen.gd")

const CRATE := Color("d7aa74")
const CRATE_LIT := Color("e4bd8b")
const CRATE_DEEP := Color("a87a4c")
const CRATE_POST := Color("b98a58")
const CRATE_GAP := Color("8a6038")
const LABEL := Color("fbf3e2")
const LABEL_EDGE := Color("e3d2b4")
const FILLED := Color("dcefcf")
const FILLED_EDGE := Color("9cc47f")
const CHALK := Color("3f5048")
const CHALK_DEEP := Color("33423b")
const CHALK_INK := Color("f4f1e6")
const FRAME := Color("b8865a")
const FRAME_DEEP := Color("8f6440")
const TOKEN := Color("f4e4c8")
const TOKEN_DEEP := Color("cdb38c")
const STRING := Color("9a7b5a")

## A crate's parts as a share of its width: its height, corner, deep foot,
## the label's width, height and rise.
const H := 0.84
const CORNER := 0.1
const FOOT := 0.08
const LABEL_W := 0.72
const LABEL_H := 0.48
const LABEL_RISE := 0.02
## The picked crate's ring: its gap from the crate and its line.
const HALO_GAP := 0.05
const HALO_W := 0.03

## The pieces drawn many times over, about the origin, for a crate `w` wide:
## {crate, filled, halo, shade}. The halo is a ring round the crate, a
## soft glow outside a sun line, not a slab behind it.
static func units(w: float) -> Dictionary:
	var out := {}
	var b := Face.Builder.new()
	crate(b, Vector2.ZERO, w, false)
	out.crate = b.mesh()
	b = Face.Builder.new()
	crate(b, Vector2.ZERO, w, true)
	out.filled = b.mesh()
	b = Face.Builder.new()
	var gap := w * HALO_GAP
	var hs := Vector2(w, w * H) + Vector2.ONE * gap * 2.0
	var ring := Face.Builder.round_rect(-hs * 0.5, hs, w * CORNER + gap)
	b.stroke(ring, w * 0.07, Color(Pal.SUN, 0.22), true)
	b.stroke(ring, w * HALO_W, Pal.SUN, true)
	out.halo = b.mesh()
	b = Face.Builder.new()
	Scenery.soft_disc(b, Vector2(0.0, w * H * 0.5), w * 0.52, w * 0.1, Color(Pal.TEXT, 0.18))
	out.shade = b.mesh()
	return out

## A crate centred on `at`: a rounded wooden box on a darker foot, a lit
## rim along its top, two soft grooves for its slats and a faint post at
## each side, and the paper label over it; leaf paper once it holds the
## order. (The first crate, 2026-10-22, was dark gaps between three slats
## and two posts: busy, and the label small among it.)
static func crate(b, at: Vector2, w: float, filled: bool) -> void:
	var h := w * H
	var corner := at - Vector2(w, h) * 0.5
	var r := w * CORNER
	b.fan(Face.Builder.round_rect(corner, Vector2(w, h), r), CRATE_DEEP)
	b.fan(Face.Builder.round_rect(corner, Vector2(w, h - w * FOOT), r), CRATE)
	b.fan(Face.Builder.round_rect(corner + Vector2(w * 0.04, w * 0.03), Vector2(w * 0.92, w * 0.05), w * 0.025),
		Color(CRATE_LIT, 0.9))
	var body := h - w * FOOT
	for i in [1, 2]:
		var y: float = corner.y + body * i / 3.0
		b.stroke(PackedVector2Array([Vector2(corner.x + w * 0.05, y), Vector2(corner.x + w * 0.95, y)]),
			w * 0.018, Color(CRATE_GAP, 0.28), false, true)
	for side in [0.0, 1.0]:
		var x: float = corner.x + side * (w - w * 0.1)
		b.fan(Face.Builder.round_rect(Vector2(x, corner.y), Vector2(w * 0.1, body), r), Color(CRATE_POST, 0.55))
	var ls := Vector2(w * LABEL_W, w * LABEL_H)
	var lat := at - ls * 0.5 - Vector2(0.0, w * (LABEL_RISE + FOOT * 0.5))
	b.fan(Face.Builder.round_rect(lat + Vector2(0.0, w * 0.02), ls, w * 0.09),
		Color(FILLED_EDGE if filled else CRATE_GAP, 0.35))
	b.fan(Face.Builder.round_rect(lat, ls, w * 0.09), FILLED if filled else LABEL)

## Where a crate's numeral stands, from its centre, for a crate `w` wide.
static func label_centre(w: float) -> Vector2:
	return Vector2(0.0, -w * (LABEL_RISE + FOOT * 0.5))

## A crate's numeral size for `text`, a crate `w` wide.
static func numeral_size(text: String, w: float) -> int:
	return roundi(w * (0.36 if text.length() <= 2 else (0.3 if text.length() == 3 else 0.24)))

## A sign token of radius `r` about `at`, its mark drawn on it: wood, or
## the sun's when it is the sign picked.
static func token(b, at: Vector2, r: float, op: int, lit: bool) -> void:
	b.disc(at + Vector2(0.0, r * 0.1), r, Pal.SUN_DEEP if lit else TOKEN_DEEP)
	b.disc(at, r, Pal.SUN if lit else TOKEN)
	b.disc(at, r * 0.82, Color(Pal.SUN_RAY, 0.5) if lit else Color(Color.WHITE, 0.35))
	mark(b, at, r * 0.5, op, Pal.SURFACE if lit else Pal.TEXT)

## A sign's mark, `r` its half reach.
static func mark(b, at: Vector2, r: float, op: int, ink: Color) -> void:
	var t := r * 0.32
	match op:
		Gen.Op.ADD:
			b.fan(Face.Builder.round_rect(at - Vector2(r, t * 0.5), Vector2(r * 2.0, t), t * 0.5), ink)
			b.fan(Face.Builder.round_rect(at - Vector2(t * 0.5, r), Vector2(t, r * 2.0), t * 0.5), ink)
		Gen.Op.SUB:
			b.fan(Face.Builder.round_rect(at - Vector2(r, t * 0.5), Vector2(r * 2.0, t), t * 0.5), ink)
		Gen.Op.MUL:
			var k := r * 0.78
			b.stroke(PackedVector2Array([at + Vector2(-k, -k), at + Vector2(k, k)]), t, ink)
			b.stroke(PackedVector2Array([at + Vector2(k, -k), at + Vector2(-k, k)]), t, ink)
		_:
			b.fan(Face.Builder.round_rect(at - Vector2(r, t * 0.5), Vector2(r * 2.0, t), t * 0.5), ink)
			b.disc(at + Vector2(0.0, -r * 0.62), t * 0.62, ink)
			b.disc(at + Vector2(0.0, r * 0.62), t * 0.62, ink)

## The order board: a chalk slate `sz` in a wooden frame, hung by two
## strings from `hang` (the awning's foot) to its top corners.
static func board(b, centre: Vector2, sz: Vector2, hang: float, u: float) -> void:
	var corner := centre - sz * 0.5
	for side in [0.22, 0.78]:
		var x: float = corner.x + sz.x * side
		b.stroke(PackedVector2Array([Vector2(x, hang), Vector2(x, corner.y + 6.0 * u)]), 4.0 * u, STRING)
	b.fan(Face.Builder.round_rect(corner + Vector2(0.0, 6.0 * u), sz, 18.0 * u), FRAME_DEEP)
	b.fan(Face.Builder.round_rect(corner, sz, 18.0 * u), FRAME)
	var inset := 14.0 * u
	b.fan(Face.Builder.round_rect(corner + Vector2.ONE * inset, sz - Vector2.ONE * inset * 2.0, 10.0 * u), CHALK_DEEP)
	b.fan(Face.Builder.round_rect(corner + Vector2.ONE * inset + Vector2(0.0, 3.0 * u),
		sz - Vector2.ONE * inset * 2.0 - Vector2(0.0, 3.0 * u), 10.0 * u), CHALK)
	# a smudge of old chalk
	b.ellipse(corner + Vector2(sz.x * 0.78, sz.y * 0.7), sz.x * 0.1, sz.y * 0.08, Color(CHALK_INK, 0.06))
	for side in [0.22, 0.78]:
		b.disc(Vector2(corner.x + sz.x * side, corner.y + 6.0 * u), 6.0 * u, FRAME_DEEP)
