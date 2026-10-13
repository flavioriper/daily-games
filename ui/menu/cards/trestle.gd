extends "res://ui/menu/cards/card_face.gd"

## Trestle's card: the gorge from the side on a warm sandstone morning. Two
## cliff shoulders stand along the foot, the left one running in from the
## card's edge under the name, the right one against the card's side, pale
## water between them. The bridge crosses in the board's own members: four
## lengths of road from pin to pin, two posts, two struts to the middle and
## a slope up from each bank -- and no top chord, so the truss stands open
## between its two upper joints, both ringed. The cart waits at the lip of
## the left cliff with one rider (the board's own fruit, the one live
## child).
##
## The go button is the member the truss lacks: the top chord in the card's
## colour, thicker than its siblings, lifted off its place over a shadow at
## a slight angle, with a chevron. On a wider card the left cliff grows and
## the gap does not.
##
## Everything still is one mesh, the members, bolts, pins and cart
## ui/faces/trestle_parts.gd's own builders.

const Parts = preload("res://ui/faces/trestle_parts.gd")
const Fruit = preload("res://ui/faces/fruit.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

## The row the card was drawn for (puzzle_card_2d.gd's CARD_H).
const H := 246.0
## One step of the lattice at H, the gap in steps, the room right of the far
## pin in steps, and how far the deck stands over the card's foot at H.
const STEP := 48.0
const SPAN := 4
const RIGHT := 0.6
const DECK := 54.0
## The words end here: the near pin never stands left of it.
const WORDS_END := 250.0
## The water's depth at the foot, at H.
const WATER := 24.0
## The lattice points, in steps from the near pin, y up: the deck's joints
## and the two upper ones.
const TOP_A := Vector2i(1, 1)
const TOP_B := Vector2i(3, 1)
## The wooden members laid, each [from, to]. The top chord is the go piece.
const WOOD: Array = [
	[Vector2i(0, 0), Vector2i(1, 1)], [Vector2i(1, 1), Vector2i(1, 0)], [Vector2i(1, 1), Vector2i(2, 0)],
	[Vector2i(3, 1), Vector2i(2, 0)], [Vector2i(3, 1), Vector2i(3, 0)], [Vector2i(3, 1), Vector2i(4, 0)],
]
## The go member: how thick it is in steps, how far it is lifted, its lean
## in radians, and its shadow.
const GO_THICK := 0.36
const GO_LIFT := 0.42
const GO_LEAN := -0.09
const GO_SHADOW := 0.2
## The rider's seat in steps (the board's is 0.62) and which fruit it is.
const RIDER := 0.66
const FRUIT := 1
## How far back from the cliff's lip the cart stands, in steps.
const CART_BACK := 0.75
## The words' margin, their room and how far down they start.
const SIDE := 22.0
const WORDS := 215.0
const WORDS_TOP := 14.0

## The morning: sky over a deeper sand, a pale pool behind the bridge, the
## cliffs' face, cap and strata, the water and the blurb's ink.
const SKY_TOP := Color("fbf1e2")
const SKY_LOW := Color("f3e2c9")
const POOL := Color("fff9ee")
const CLIFF := Color("e6c9a2")
const CLIFF_LOW := Color("d9b68b")
const CAP := Color("f1dcb9")
const STRATA := Color("cfa97c")
const WATER_TOP := Color("cfe6ea")
const WATER_LOW := Color("b4d6df")
const BLURB := Color("7b6a54")

func _k() -> float:
	return size.y / H

## One lattice step: the card's height sets it, the words cap it.
func _u() -> float:
	return minf(STEP * _k(), (size.x - WORDS_END) / (float(SPAN) + RIGHT))

func _deck_y() -> float:
	return size.y - DECK * _k()

## The near pin, on the left cliff's lip.
func _near() -> Vector2:
	var u := _u()
	return Vector2(size.x - (float(SPAN) + RIGHT) * u, _deck_y())

func _pt(p: Vector2i) -> Vector2:
	return _near() + Vector2(p.x, -p.y) * _u()

## `shape` where it lies on the paper, in `colour`, shaded top to bottom.
func _on_paper(b: Face.Builder, shape: PackedVector2Array, top: Color, low: Color, y0: float, y1: float) -> void:
	for piece: PackedVector2Array in Geometry2D.intersect_polygons(shape, ground()):
		var first := b.verts.size()
		b.polygon(piece, Color.WHITE)
		shade(b, first, top, low, y0, y1)

func _paint(b: Face.Builder) -> void:
	var u := _u()
	var k := _k()
	var deck := _deck_y()
	var near := _near()
	var far := _pt(Vector2i(SPAN, 0))
	var first := b.verts.size()
	b.polygon(ground(), Color.WHITE)
	shade(b, first, SKY_TOP, SKY_LOW, 0.0, size.y)
	Scenery.soft_disc(b, (near + far) * 0.5 - Vector2(u * 0.3, u * 0.6), u * 2.6, u * 1.6, Color(POOL, 0.6))
	# The water between the cliffs, then the cliffs over its ends.
	var water_y := size.y - WATER * k
	_on_paper(b, PackedVector2Array([Vector2(near.x - u, water_y), Vector2(size.x, water_y), Vector2(size.x, size.y),
		Vector2(near.x - u, size.y)]), WATER_TOP, WATER_LOW, water_y, size.y)
	for i in 2:
		var x := lerpf(near.x, far.x, 0.3 + 0.4 * i)
		b.stroke(PackedVector2Array([Vector2(x - u * 0.22, water_y + (8.0 + 6.0 * i) * k),
			Vector2(x + u * 0.22, water_y + (8.0 + 6.0 * i) * k)]), 2.0 * k, Color(1, 1, 1, 0.6))
	_cliff(b, 0.0, near.x + u * 0.12, near.x - u * 0.2, deck)
	_cliff(b, far.x - u * 0.12, size.x, far.x + u * 0.2, deck)
	# The bridge: wood behind, the road over it, bolts and pins on top.
	for m: Array in WOOD:
		Parts.member(b, _pt(m[0]), _pt(m[1]), 1, u)
	for i in SPAN:
		Parts.member(b, _pt(Vector2i(i, 0)), _pt(Vector2i(i + 1, 0)), 0, u)
	for i in range(1, SPAN):
		Parts.joint(b, _pt(Vector2i(i, 0)), u)
	for top: Vector2i in [TOP_A, TOP_B]:
		b.disc(_pt(top), u * 0.2, Color(Pal.SUN, 0.42))
		Parts.joint(b, _pt(top), u)
	Parts.anchor(b, near, u)
	Parts.anchor(b, far, u)
	_cart(b, near + Vector2(-CART_BACK * u, 0.0), u)
	if not soon:
		_go(b, u)

## A cliff shoulder from `x0` to `x1` with its top at `top`; `foot_x` is
## where its face meets the water, so the lip overhangs a little.
func _cliff(b: Face.Builder, x0: float, x1: float, foot_x: float, top: float) -> void:
	var left := x0 <= 0.0
	var shape := PackedVector2Array([Vector2(x0, top), Vector2(x1, top), Vector2(foot_x if left else x1, size.y),
		Vector2(x0 if left else foot_x, size.y)])
	if not left:
		shape = PackedVector2Array([Vector2(x0, top), Vector2(x1, top), Vector2(x1, size.y), Vector2(foot_x, size.y)])
	_on_paper(b, shape, CLIFF, CLIFF_LOW, top, size.y)
	var k := _k()
	var cap := 5.0 * k
	_on_paper(b, PackedVector2Array([Vector2(x0, top), Vector2(x1, top), Vector2(x1, top + cap), Vector2(x0, top + cap)]),
		CAP, CAP, top, top + cap)
	# Two strata on the long shoulder, clear of the paper's corner.
	if not left:
		return
	var a := EDGE + RADIUS
	var z := x1 - 16.0 * k
	for i in 2:
		var y := top + (20.0 + 15.0 * i) * k
		var to := z - 12.0 * i * k
		var from := maxf(a, to - (64.0 - 18.0 * i) * k)
		if to - from > 8.0 * k:
			b.stroke(PackedVector2Array([Vector2(from, y), Vector2(to, y)]), 2.0 * k, Color(STRATA, 0.55))

## The cart on the road at `at`, as the board builds it: body, then wheels.
func _cart(b: Face.Builder, at: Vector2, u: float) -> void:
	Scenery.soft_disc(b, at + Vector2(0.0, u * 0.02), Parts.cart_width(u, 1) * 0.6, u * 0.07, Color(Pal.TEXT, 0.16))
	var first := b.verts.size()
	Parts.cart_body(b, u, 1)
	for i in range(first, b.verts.size()):
		b.verts[i] += at
	for w: Vector2 in Parts.wheel_at(u, 1):
		first = b.verts.size()
		Parts.wheel(b, u)
		for i in range(first, b.verts.size()):
			b.verts[i] += at + w

## The go member: the top chord in the card's colour, lifted and leaning.
func _go(b: Face.Builder, u: float) -> void:
	var a := _pt(TOP_A)
	var z := _pt(TOP_B)
	var mid := (a + z) * 0.5 - Vector2(0.0, GO_LIFT * u)
	var half := Vector2.from_angle(GO_LEAN) * (z - a).length() * 0.5
	var w := GO_THICK * u
	Scenery.soft_disc(b, (a + z) * 0.5 + Vector2(0.0, u * 0.06), half.length() * 0.95, u * 0.1, Color(Pal.TEXT, GO_SHADOW))
	var line := PackedVector2Array([mid - half, mid + half])
	var drop := Vector2(0.0, u * 0.07)
	b.stroke(PackedVector2Array([line[0] + drop, line[1] + drop]), w, colour.darkened(0.28))
	b.stroke(line, w, colour)
	var up := half.normalized().orthogonal()
	if up.y > 0.0:
		up = -up
	b.stroke(PackedVector2Array([line[0] + up * w * 0.24, line[1] + up * w * 0.24]), w * 0.2, Color(Pal.SURFACE, 0.22))
	for end: Vector2 in line:
		b.disc(end, w * 0.2, colour.darkened(0.34))
	var h := w * 0.3
	var n := half.normalized()
	b.stroke(PackedVector2Array([mid - n * h * 0.55 + up * h, mid + n * h * 0.55, mid - n * h * 0.55 - up * h]), w * 0.19,
		Pal.SURFACE)

func _lay() -> void:
	var words := _words(String(entry.get("title", "")), SIDE, size.y * 0.5, WORDS, Pal.TEXT, BLURB)
	words.position.y = roundf(WORDS_TOP * _k())
	var u := _u()
	var at := _near() + Vector2(-CART_BACK * u, 0.0) + Parts.seat(u, 1, 0)
	var seat := RIDER * u
	var rider: Control = Fruit.make(FRUIT, seat, at)
	rider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_keep(rider)
	rider.set_idle(true)
