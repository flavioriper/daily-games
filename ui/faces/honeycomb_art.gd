extends RefCounted

## Honeycomb's drawings: the wax cells of the comb (flat on top, a deep
## rim under a lighter face), the queen's cell in honey, the queen bee who
## sits on it, the three round wooden keys under the comb (take a letter
## back, shuffle, send the word) and the honey jar's strip that fills toward
## the day's line. Builder shapes, not Controls: the board, the menu card and
## the tutorial draw the same pieces. Letters are the caller's (a draw_string
## each, never baked).

const Pal = preload("res://core/palette.gd")
const Face = preload("res://ui/faces/face.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

const WAX := Color("f6e2a8")
const WAX_LIT := Color("fbeec6")
const WAX_DEEP := Color("dcb768")
const HONEY := Color("f2b33d")
const HONEY_LIT := Color("f8cb64")
const HONEY_DEEP := Color("c98a1c")
const INK := Color("4a3420")
const BEE := Color("f7c234")
const BEE_BAND := Color("4a3420")
const WING := Color("f4fbff")
const KEY := Color("f4e4c8")
const KEY_DEEP := Color("cdb38c")
const JAR := Color("fbf3e2")
const JAR_EDGE := Color("e3d2b4")

## Keys under the comb.
enum Key { DELETE, SHUFFLE, ENTER }

## A cell's rim as a share of its radius, how far its face is lifted.
const RIM := 0.1
const LIFT := 0.07

## A flat-topped hexagon about `at`, `r` to its corners.
static func hex_points(at: Vector2, r: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in 6:
		var a := PI / 3.0 * i
		out.append(at + Vector2(cos(a), sin(a)) * r)
	return out

## Where the cell `i` sits about the comb's middle, for cells `r` to their
## corners with `gap` between them: 0 the middle, 1..6 round it from the top
## clockwise.
static func cell_offset(i: int, r: float, gap: float) -> Vector2:
	if i == 0:
		return Vector2.ZERO
	var d := (r * sqrt(3.0) + gap)
	var a := -PI * 0.5 + PI / 3.0 * (i - 1)
	return Vector2(cos(a), sin(a)) * d

## A wax cell: the deep rim a little low, the face, a lit lip at the top.
static func cell(b, at: Vector2, r: float, queen: bool) -> void:
	var face := HONEY if queen else WAX
	var deep := HONEY_DEEP if queen else WAX_DEEP
	var lit := HONEY_LIT if queen else WAX_LIT
	b.fan(hex_points(at + Vector2(0.0, r * LIFT), r), deep)
	b.fan(hex_points(at, r * (1.0 - RIM * 0.4)), face)
	b.fan(hex_points(at + Vector2(0.0, -r * 0.05), r * 0.72), Color(lit, 0.55))
	b.fan(hex_points(at + Vector2(0.0, r * 0.04), r * 0.66), face)

## The pieces drawn many times over, about the origin, for cells `r` to
## their corners: {cell, queen, press (a sun ring for a cell pressed),
## shade}.
static func units(r: float) -> Dictionary:
	var out := {}
	var b := Face.Builder.new()
	cell(b, Vector2.ZERO, r, false)
	out.cell = b.mesh()
	b = Face.Builder.new()
	cell(b, Vector2.ZERO, r, true)
	out.queen = b.mesh()
	b = Face.Builder.new()
	b.fan(hex_points(Vector2.ZERO, r * 1.1), Color(Pal.SUN_RAY, 0.55))
	out.press = b.mesh()
	b = Face.Builder.new()
	Scenery.soft_disc(b, Vector2(0.0, r * 0.95), r * 0.9, r * 0.16, Color(Pal.TEXT, 0.16))
	out.shade = b.mesh()
	return out

## The queen bee, `s` her body's length, facing right, about `at`; `flap`
## 0..1 the wings' beat.
static func bee(b, at: Vector2, s: float, flap := 0.0) -> void:
	var wing := 0.75 + 0.25 * cos(flap * TAU)
	Scenery.soft_disc(b, at + Vector2(0.0, s * 0.42), s * 0.42, s * 0.08, Color(Pal.TEXT, 0.18))
	b.ellipse(at + Vector2(-s * 0.08, -s * 0.34 * wing), s * 0.2, s * 0.3 * wing, Color(WING, 0.85))
	b.ellipse(at + Vector2(s * 0.12, -s * 0.3 * wing), s * 0.16, s * 0.26 * wing, Color(WING, 0.75))
	b.ellipse(at, s * 0.5, s * 0.34, BEE_BAND)
	b.ellipse(at, s * 0.46, s * 0.3, BEE)
	for x in [-0.14, 0.08]:
		b.fan(Face.Builder.round_rect(at + Vector2(s * (x - 0.05), -s * 0.3), Vector2(s * 0.1, s * 0.6), s * 0.04), BEE_BAND)
	b.disc(at + Vector2(s * 0.42, -s * 0.04), s * 0.2, BEE_BAND)
	b.disc(at + Vector2(s * 0.48, -s * 0.09), s * 0.045, WING)
	# a little crown: three points of honey
	var c := at + Vector2(s * 0.4, -s * 0.24)
	b.fan(PackedVector2Array([c + Vector2(-s * 0.13, 0.0), c + Vector2(-s * 0.12, -s * 0.13), c + Vector2(-s * 0.05, -s * 0.05),
		c + Vector2(0.0, -s * 0.16), c + Vector2(s * 0.05, -s * 0.05), c + Vector2(s * 0.12, -s * 0.13), c + Vector2(s * 0.13, 0.0)]), HONEY)
	b.stroke(PackedVector2Array([at + Vector2(-s * 0.5, 0.0), at + Vector2(-s * 0.62, s * 0.04)]), s * 0.06, BEE_BAND)

## A round wooden key of radius `r` about `at`, its mark on it; the sun's
## while it is pressed.
static func key(b, at: Vector2, r: float, kind: int, lit: bool) -> void:
	b.disc(at + Vector2(0.0, r * 0.1), r, Pal.SUN_DEEP if lit else KEY_DEEP)
	b.disc(at, r, Pal.SUN if lit else KEY)
	b.disc(at, r * 0.82, Color(Pal.SUN_RAY, 0.5) if lit else Color(Color.WHITE, 0.35))
	mark(b, at, r * 0.46, kind, Pal.SURFACE if lit else INK)

## A key's mark, `r` its half reach.
static func mark(b, at: Vector2, r: float, kind: int, ink: Color) -> void:
	var t := r * 0.26
	match kind:
		Key.DELETE:
			# a tag pointing left, an x on it
			var pts := PackedVector2Array([at + Vector2(-r, 0.0), at + Vector2(-r * 0.45, -r * 0.62), at + Vector2(r, -r * 0.62),
				at + Vector2(r, r * 0.62), at + Vector2(-r * 0.45, r * 0.62), at + Vector2(-r, 0.0)])
			b.stroke(pts, t * 0.8, ink, false)
			var x := at + Vector2(r * 0.25, 0.0)
			var k := r * 0.3
			b.stroke(PackedVector2Array([x + Vector2(-k, -k), x + Vector2(k, k)]), t * 0.8, ink)
			b.stroke(PackedVector2Array([x + Vector2(k, -k), x + Vector2(-k, k)]), t * 0.8, ink)
		Key.SHUFFLE:
			# two arcs chasing each other round, an arrowhead on each
			for half in 2:
				var a0 := PI * half + 0.35
				var pts := Face.Builder.arc_points(at, r * 0.8, a0, a0 + PI - 0.7)
				b.stroke(pts, t * 0.8, ink, false)
				var tip: Vector2 = pts[pts.size() - 1]
				var along := (tip - pts[pts.size() - 2]).normalized()
				var side := along.orthogonal()
				b.fan(PackedVector2Array([tip + along * r * 0.3, tip + side * r * 0.26, tip - side * r * 0.26]), ink)
		_:
			# a tick
			b.stroke(PackedVector2Array([at + Vector2(-r * 0.75, 0.0), at + Vector2(-r * 0.2, r * 0.55), at + Vector2(r * 0.8, -r * 0.6)]),
				t, ink, false)

## The honey strip: a jar's paper band `sz` about `at`, filled from the left
## by `share` (0..1) of honey, with comb cells pressed into it.
static func strip(b, at: Vector2, sz: Vector2, share: float) -> void:
	var corner := at - sz * 0.5
	var rr := sz.y * 0.5
	b.fan(Face.Builder.round_rect(corner + Vector2(0.0, sz.y * 0.12), sz, rr), JAR_EDGE)
	b.fan(Face.Builder.round_rect(corner, sz, rr), JAR)
	var inset := sz.y * 0.16
	var inner := sz - Vector2.ONE * inset * 2.0
	b.fan(Face.Builder.round_rect(corner + Vector2.ONE * inset, inner, inner.y * 0.5), Color(WAX_DEEP, 0.35))
	var fill := clampf(share, 0.0, 1.0) * inner.x
	if fill > 1.0:
		var fw := maxf(fill, inner.y)
		b.fan(Face.Builder.round_rect(corner + Vector2.ONE * inset, Vector2(fw, inner.y), inner.y * 0.5), HONEY)
		b.fan(Face.Builder.round_rect(corner + Vector2.ONE * inset + Vector2(inner.y * 0.3, inner.y * 0.14),
			Vector2(maxf(fw - inner.y * 0.6, 0.0), inner.y * 0.22), inner.y * 0.11), Color(HONEY_LIT, 0.9))
