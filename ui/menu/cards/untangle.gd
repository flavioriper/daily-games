extends "res://ui/menu/cards/card_face.gd"

## Untangle's card: the board's hoop on a piece of its linen. Three of the
## board's ropes run peg to peg across the ring -- two of them wound round
## each other in one of its knots, the third lying under the first -- and
## the knotted rope's near peg is up off its hole, in the hand: that peg is
## the go button, in the card's colour, with a chevron on its cap where the
## others carry their rope's inlay. The top right corner is bare linen, which
## is where the done seal is pinned; a sprig is stitched in the other corner
## and a hem runs along the bottom.
##
## The ropes are the board's own (untangle_rope.gd: a line worked out, a knot
## of one short twist, whole from peg to peg), laid once and drawn into the
## one mesh; nothing here lives but the words.

const Board = preload("res://puzzles/untangle2d.gd")
const Rope = preload("res://puzzles/untangle_rope.gd")
const Scenery = preload("res://ui/flat/scenery.gd")
const Rewards = preload("res://arcade/rewards.gd")

## The row the card was drawn for (puzzle_card_2d.gd's CARD_H); the hoop
## grows with a taller one.
const H := 246.0
## The hoop at H: its outer radius, how far its middle stands from the
## card's right edge and how far under the card's own middle.
const RO := 88.0
const RIGHT := 118.0
const DROP := 9.0
## A peg, in the wood's width. The board's is 0.44 on a ring of twenty holes
## and more; eight holes on a card want a peg that can be read.
const PEG_OF_BAND := 0.58
## The holes, and the angle the first of them stands at: the low right,
## under the go peg, which leaves none of them under the seal.
const HOLES := 8
const TURN := 0.70
## The ropes: [hole, hole, which of the board's ROPES]. The first is the one
## in the hand.
const ROPES := [[0, 4, 2], [2, 6, 4], [3, 5, 1]]
## The first two are wound round each other this many times.
const KNOT := 3
const KNOT_KEY := Vector2i(0, 1)
## The go peg's radius, and how far it is held off its hole.
const GO := 29.0
const GO_LIFT := Vector2(-2.0, -9.0)
## The words' margin, and the column they are never left with less than.
const TEXT_X := 24.0
const WORDS := 256.0

const LINEN_TOP := Color("f9f1df")
const LINEN_LOW := Color("eedfc2")
## The linen inside the hoop, pulled tight: a little paler.
const LINEN_TAUT := Color("fcf6e8")

func _k() -> float:
	return size.y / H

## The hoop's own scale: the card's, unless that would leave the words less
## than their column.
func _ks() -> float:
	return minf(_k(), (size.x - TEXT_X - WORDS) / (RIGHT + RO))

func _centre() -> Vector2:
	var ks := _ks()
	return Vector2(size.x - RIGHT * ks, size.y * 0.5 + DROP * ks)

## Where hole `h` is, on a ring of radius `rh` about `c`.
func _hole(c: Vector2, rh: float, h: int) -> Vector2:
	return c + Vector2.from_angle(TURN + TAU * h / HOLES) * rh

func _paint(b: Face.Builder) -> void:
	var ks := _ks()
	var c := _centre()
	var ro := RO * ks
	var ri := ro * Board.RING_IN
	var rh := (ro + ri) * 0.5
	var peg := (ro - ri) * PEG_OF_BAND
	var wd := peg * Board.ROPE_OF_PEG
	# The linen.
	var first := b.verts.size()
	b.polygon(ground(), Color.WHITE)
	shade(b, first, LINEN_TOP, LINEN_LOW, 0.0, size.y)
	_sprig(b, Vector2(42.0, 38.0) * _k(), 11.0 * _k(), 0.9, 1.0)
	# The hem: a running stitch along the bottom, between the corners.
	var hem_y := size.y - 13.0
	var x := RADIUS
	while x + 12.0 <= size.x - RADIUS:
		b.stroke(PackedVector2Array([Vector2(x, hem_y), Vector2(x + 12.0, hem_y)]), 3.0, Color(Board.CLOTH_GOLD, 0.5))
		x += 21.0
	# The hoop: its shadow on the cloth in two soft passes, the linen it
	# holds, the wood, its two edges, the light on its upper left, the grain.
	var soft := ro - ri
	b.stroke(Face.Builder.arc_points(c + Vector2(0.012, 0.03) * ro, rh, 0.0, TAU), soft + 14.0 * ks, Color(Pal.TEXT, 0.05), true)
	b.stroke(Face.Builder.arc_points(c + Vector2(0.01, 0.022) * ro, rh, 0.0, TAU), soft + 7.0 * ks, Color(Pal.TEXT, 0.09), true)
	b.disc(c, rh, LINEN_TAUT)
	b.stroke(Face.Builder.arc_points(c, rh, 0.0, TAU), soft, Board.WOOD, true)
	b.stroke(Face.Builder.arc_points(c, ro - 1.5 * ks, 0.0, TAU), 3.0 * ks, Board.WOOD_EDGE, true)
	b.stroke(Face.Builder.arc_points(c, ri + 1.5 * ks, 0.0, TAU), 3.0 * ks, Board.WOOD_EDGE, true)
	b.stroke(Face.Builder.arc_points(c, ro - 5.5 * ks, PI * 1.02, PI * 1.62), 2.6 * ks, Color(Board.WOOD_HI, 0.85), false, true)
	var grain := RandomNumberGenerator.new()
	grain.seed = 4471
	for i in 10:
		var rr := grain.randf_range(ri + 5.0 * ks, ro - 5.0 * ks)
		var a0 := grain.randf_range(0.0, TAU)
		b.stroke(Face.Builder.arc_points(c, rr, a0, a0 + grain.randf_range(0.25, 0.9)), 1.4 * ks,
			Color(Board.WOOD_GRAIN, grain.randf_range(0.12, 0.26)), false, true)
	var hole_r := peg * Board.HOLE_OF_PEG
	for h in HOLES:
		var at := _hole(c, rh, h)
		b.disc(at, hole_r * 1.14, Color(Board.HOLE_RIM, 0.7))
		b.disc(at, hole_r, Board.HOLE)
		b.disc(at + Vector2(0.0, hole_r * 0.16), hole_r * 0.82, Board.HOLE_DEEP)
	# Where each peg is: in its hole, but for the one in the hand.
	var held := not soon
	var pos := PackedVector2Array()
	for r: Array in ROPES:
		pos.append(_hole(c, rh, r[0]))
		pos.append(_hole(c, rh, r[1]))
	var home := pos[0]
	if held:
		pos[0] = home + GO_LIFT * ks
	# The ropes, each laid whole from peg to peg, the first two through
	# their knot.
	var ropes: Array = []
	for r in ROPES.size():
		var rope := Rope.new()
		rope.setup(pos[2 * r], pos[2 * r + 1], pos[2 * r].distance_to(pos[2 * r + 1]) * 1.3, wd)
		ropes.append(rope)
	var kn := Rope.lay_knot(KNOT_KEY, Board.knot_centre(pos[0], pos[1], pos[2], pos[3]), KNOT, wd,
		pos[0], pos[1], pos[2], pos[3])
	for r in 2:
		(ropes[r] as Rope).lay(pos[2 * r], pos[2 * r + 1], [[kn, r]], wd)
		(ropes[r] as Rope).rest()
	for r: int in [2, 1, 0]:
		var col: Array = Board.ROPES[ROPES[r][2]]
		(ropes[r] as Rope).draw(b, wd, col[0], col[1], col[2])
	# The knot's middle crossing is the second rope's: a piece of it laid
	# back over the first, as the board lays one (PATCH_HALF).
	var over: Rope = ropes[1]
	var ia: PackedInt32Array = (ropes[0] as Rope).marks.get(KNOT_KEY, PackedInt32Array())
	var ib: PackedInt32Array = over.marks.get(KNOT_KEY, PackedInt32Array())
	if ia.size() == ib.size():
		over.polyline()
		var col: Array = Board.ROPES[ROPES[1][2]]
		var half := wd * Board.PATCH_HALF
		for i in range(1, ib.size(), 2):
			var s: float = over.cum()[ib[i if int(kn.dir_b) > 0 else ib.size() - 1 - i]]
			over.draw(b, wd, col[0], col[1], col[2], 0.0, 1.0, Color(0, 0, 0, 0), 0.0, 0.0, 0.0, s - half, s + half, 0.85)
	# The pegs, and the one in the hand over them all.
	for p in pos.size():
		if p == 0 and held:
			continue
		_peg(b, pos[p], peg, Board.ROPES[ROPES[p >> 1][2]])
	if held:
		_go(b, home, pos[0], GO * ks)

## A peg as the board draws one at rest: its soft shadow, the cap, and the
## inlay in its rope's colour.
func _peg(b: Face.Builder, at: Vector2, r: float, col: Array) -> void:
	Scenery.soft_disc(b, at + Vector2(0.1, 0.26) * r, r * 1.02, r * 0.66, Color(Pal.TEXT, 0.24))
	b.ellipse(at + Vector2(0.0, r * 0.1), r, r, Board.CAP_DEEP)
	b.ellipse(at, r * 0.97, r * 0.97, Board.CAP_SIDE)
	b.ellipse(at + Vector2(0.0, -r * 0.06), r * 0.8, r * 0.78, Board.CAP)
	b.ellipse(at + Vector2(-0.27, -0.32) * r, r * 0.27, r * 0.19, Color(Board.CAP_HI, 0.85))
	b.disc(at + Vector2(0.0, -r * 0.06), r * 0.4, col[1])
	b.disc(at + Vector2(0.0, -r * 0.08), r * 0.32, col[0])
	b.disc(at + Vector2(-0.1, -0.16) * r, r * 0.1, Color(col[2], 0.9))

## The go peg: a cap in the card's colour held at `at`, off its hole at
## `home`, where its shadow has parted from it; a chevron for its inlay.
func _go(b: Face.Builder, home: Vector2, at: Vector2, r: float) -> void:
	Scenery.soft_disc(b, home + Vector2(0.14, 0.36) * r, r * 1.3, r * 0.92, Color(Pal.TEXT, 0.20))
	b.ellipse(at + Vector2(0.0, r * 0.1), r, r, colour.darkened(0.40))
	b.ellipse(at, r * 0.97, r * 0.97, colour.darkened(0.22))
	b.ellipse(at + Vector2(0.0, -r * 0.06), r * 0.8, r * 0.78, colour)
	b.ellipse(at + Vector2(-0.27, -0.34) * r, r * 0.25, r * 0.16, Color(1.0, 1.0, 1.0, 0.32))
	var mid := at + Vector2(r * 0.03, -r * 0.05)
	var q := r * 0.27
	b.stroke(PackedVector2Array([mid + Vector2(-q * 0.55, -q), mid + Vector2(q * 0.55, 0.0),
		mid + Vector2(-q * 0.55, q)]), r * 0.17, Pal.SURFACE)

## A flower with two leaves and a pair of berries, as the board stitches
## them in its cloth's corners (untangle2d.gd's _sprig).
func _sprig(b: Face.Builder, at: Vector2, r: float, tilt: float, side: float) -> void:
	for i in 2:
		var a := tilt + side * (0.55 + 0.9 * i)
		Rewards.petal(b, at + Vector2.from_angle(a) * r * 1.35, r * 0.78, r * 0.3, a, Board.CLOTH_LEAF)
		b.stroke(PackedVector2Array([at + Vector2.from_angle(a) * r * 0.7, at + Vector2.from_angle(a) * r * 1.9]),
			1.6, Board.CLOTH_LEAF_DEEP, false, false)
	for i in 6:
		var a := TAU * i / 6.0 + tilt
		Rewards.petal(b, at + Vector2.from_angle(a) * r * 0.5, r * 0.5, r * 0.28, a, Board.CLOTH_PETAL_DEEP)
	for i in 6:
		var a := TAU * i / 6.0 + tilt
		Rewards.petal(b, at + Vector2.from_angle(a) * r * 0.48 + Vector2(-0.6, -1.0), r * 0.46, r * 0.24, a, Color.WHITE)
	b.disc(at, r * 0.28, Board.CLOTH_GOLD)
	for i in 2:
		b.disc(at + Vector2(side * (r * 1.7 + i * r * 0.5), -r * 0.8 - i * r * 0.2), r * 0.2, Board.CLOTH_BERRY)

func _lay() -> void:
	var ks := _ks()
	var room := _centre().x - RO * ks - TEXT_X - 6.0
	_words(String(entry.get("title", "")), TEXT_X, size.y * 0.5 + 6.0, room)
