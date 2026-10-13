extends "res://ui/menu/cards/card_face.gd"

## Horse Pen's card: a little paddock standing free on a morning meadow. A
## pale sky falls to two soft rises of grass, and on the right, down by the
## foot, a patch of the board's field four cells by three: a stream along
## its bottom row (water is a wall, as on the board), hay bales over the two
## middle cells and one at their left, and the pony standing across those
## two cells in the wheat of its own reach, looking right at the one cell
## still open. The pen is checked in code: with that cell shut the reach is
## the two cells and touches no edge of the patch.
##
## The go button is the bale that shuts it: a bale in the card's colour,
## larger than its siblings and lifted over its shadow, with a chevron on
## its top. The other bales wear a paler straw so the card's mustard is the
## one saturated thing in the fence. The name stands top left over the sky.
##
## Everything is one mesh, the pony, bales, wheat and water
## ui/faces/horse_parts.gd's own builders; the board draws its pony on a
## layer of its own and has no Control for it, so it is baked here and
## nothing lives on the card. It writes no string.

const Parts = preload("res://ui/faces/horse_parts.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

## The row the card was drawn for (puzzle_card_2d.gd's CARD_H).
const H := 246.0
## A cell at H, and the patch's room from the card's right side and foot.
const CELL := 54.0
const RIGHT := 12.0
const FOOT := 9.0
## The words end here: the patch never starts left of it.
const WORDS_END := 254.0
## The patch, and what stands on it.
const COLS := 4
const ROWS := 3
const BALES: Array[Vector2i] = [Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1)]
const WATER: Array[Vector2i] = [Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2)]
const HORSE := Vector2i(1, 1)
const GO := Vector2i(3, 1)
## The pony: its size in cells, and where it stands from the middle of its
## cell, in cells (half a cell right, so it stands across the pen's two).
const PONY := 1.5
const PONY_AT := Vector2(0.5, -0.1)
## How far the plain bales' straw is washed toward cream.
const PALE := 0.42
## The go bale: its size in cells, how far it is lifted, and its shadow.
const GO_SIZE := 1.16
const GO_LIFT := 0.12
const GO_SHADOW := 0.24
## A cell's hint on the meadow: its inset and corner in cells, and its ink.
const HINT_INSET := 0.05
const HINT_ROUND := 0.2
const HINT_ALPHA := 0.5
## Where the meadow's two rises top out, as a part of the card's height.
const FAR_RISE := 0.37
const NEAR_RISE := 0.47
## The words' margin, their room and how far down they start.
const SIDE := 22.0
const WORDS := 215.0
const WORDS_TOP := 14.0

## The morning: the sky, the far rise, the meadow from its top to the foot,
## a cell's hint, the cream the plain bales are washed with, the blurb.
const SKY_TOP := Color("e3f1f8")
const SKY_LOW := Color("f1f7ec")
const FAR := Color("e6f3d9")
const MEADOW_TOP := Color("e1f1d0")
const MEADOW_LOW := Color("cfe6b6")
const HINT := Color("c6dfa6")
const CREAM := Color("f6ecd0")
const BLURB := Color("5d6f62")

func _k() -> float:
	return size.y / H

## One cell: the card's height sets it, the words cap it.
func _cell() -> float:
	return minf(CELL * _k(), (size.x - WORDS_END - RIGHT * _k()) / float(COLS))

## The patch's top left corner.
func _origin() -> Vector2:
	var s := _cell()
	var k := _k()
	return Vector2(size.x - RIGHT * k - COLS * s, size.y - FOOT * k - ROWS * s)

func _mid(cell: Vector2i) -> Vector2:
	return _origin() + (Vector2(cell) + Vector2.ONE * 0.5) * _cell()

## The cells the pony can walk to, up, down, left and right, with the go
## cell shut or open: never through a bale or water.
static func _reach(shut: bool) -> Array[Vector2i]:
	var out: Array[Vector2i] = [HORSE]
	var todo: Array[Vector2i] = [HORSE]
	while not todo.is_empty():
		var c: Vector2i = todo.pop_back()
		for d: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]:
			var n := c + d
			if n.x < 0 or n.y < 0 or n.x >= COLS or n.y >= ROWS:
				continue
			if n in out or n in BALES or n in WATER or (shut and n == GO):
				continue
			out.append(n)
			todo.append(n)
	return out

## A pen: no cell of the reach lies on the patch's edge.
static func _penned(reach: Array[Vector2i]) -> bool:
	for c: Vector2i in reach:
		if c.x == 0 or c.y == 0 or c.x == COLS - 1 or c.y == ROWS - 1:
			return false
	return true

## `shape` where it lies on the paper, shaded top to bottom.
func _on_paper(b: Face.Builder, shape: PackedVector2Array, top: Color, low: Color, y0: float, y1: float) -> void:
	for piece: PackedVector2Array in Geometry2D.intersect_polygons(shape, ground()):
		var first := b.verts.size()
		b.polygon(piece, Color.WHITE)
		shade(b, first, top, low, y0, y1)

## A rise of grass across the card whose top swells to `crest` (a part of
## the card's width) at `top`.
func _rise(b: Face.Builder, top: float, crest: float, swell: float, colour: Color, low: Color) -> void:
	var shape := PackedVector2Array()
	for i in 25:
		var t := i / 24.0
		shape.append(Vector2(t * size.x, top + swell * (1.0 - cos((t - crest) * PI * 1.3)) * 0.5))
	shape.append(Vector2(size.x, size.y))
	shape.append(Vector2(0.0, size.y))
	_on_paper(b, shape, colour, low, top, size.y)

func _paint(b: Face.Builder) -> void:
	var s := _cell()
	var k := _k()
	var o := _origin()
	var first := b.verts.size()
	b.polygon(ground(), Color.WHITE)
	shade(b, first, SKY_TOP, SKY_LOW, 0.0, size.y * NEAR_RISE)
	_rise(b, size.y * FAR_RISE, 0.72, 14.0 * k, FAR, MEADOW_TOP)
	_rise(b, size.y * NEAR_RISE, 0.3, 12.0 * k, MEADOW_TOP, MEADOW_LOW)
	# The patch: a hint a cell, the wheat of the pony's reach, the stream.
	var inset := s * HINT_INSET
	for y in ROWS:
		for x in COLS:
			b.fan(Face.Builder.round_rect(o + Vector2(x, y) * s + Vector2.ONE * inset, Vector2.ONE * (s - 2.0 * inset),
				s * HINT_ROUND), Color(HINT, HINT_ALPHA))
	var reach := _reach(true)
	if _penned(reach):
		for cell: Vector2i in reach:
			first = b.verts.size()
			Parts.wheat(b, s, inset, s * HINT_ROUND)
			var at := _mid(cell)
			for i in range(first, b.verts.size()):
				b.verts[i] += at
	Parts.water(b, func(i: int) -> bool: return Vector2i(i % COLS, i / COLS) in WATER, COLS, ROWS, o, s)
	# The open cell, lit: where the last bale goes.
	Scenery.soft_disc(b, _mid(GO), s * 0.5, s * 0.46, Color(Pal.SUN, 0.34))
	# The far bales, the pony before them, then the near one.
	for cell: Vector2i in BALES:
		if cell.y < HORSE.y:
			_bale(b, _mid(cell), s)
	var pony := _mid(HORSE) + PONY_AT * s
	Parts.shade(b, pony, s * PONY, 0.36, 0.22)
	Parts.horse(b, pony, s * PONY, Face.Expr.HAPPY)
	for cell: Vector2i in BALES:
		if cell.y >= HORSE.y:
			_bale(b, _mid(cell), s)
	if not soon:
		_go(b, _mid(GO) - Vector2(0.0, s * GO_LIFT), s)

## One of the board's bales on `at`, its straw washed toward cream; the
## straps keep their ink.
func _bale(b: Face.Builder, at: Vector2, s: float) -> void:
	Parts.shade(b, at, s, 0.4, 0.16)
	var first := b.verts.size()
	Parts.bale(b, at, s)
	for i in range(first, b.verts.size()):
		var c := b.cols[i]
		if c.is_equal_approx(Pal.STRAP):
			continue
		var pale := c.lerp(CREAM, PALE)
		b.cols[i] = Color(pale.r, pale.g, pale.b, c.a)

## The go bale about `at`: the board's bale in the card's colour, larger,
## over its own shadow, with a chevron on its top.
func _go(b: Face.Builder, at: Vector2, s: float) -> void:
	var g := s * GO_SIZE
	var half := 0.37 * g
	var body := Vector2(2.0 * half, 2.0 * half)
	Scenery.soft_disc(b, at + Vector2(0.0, half * 0.96 + s * GO_LIFT), half * 1.1, s * 0.14, Color(Pal.TEXT, GO_SHADOW))
	b.fan(Face.Builder.round_rect(at - Vector2(half, half * 0.82), body * Vector2(1.0, 0.96), 0.09 * g),
		colour.darkened(0.26))
	b.fan(Face.Builder.round_rect(at - Vector2(half, half), body * Vector2(1.0, 0.7), 0.09 * g), colour)
	b.fan(Face.Builder.round_rect(at - Vector2(half * 0.84, half * 0.88), Vector2(half * 1.68, half * 0.36), 0.06 * g),
		Color(Pal.SURFACE, 0.2))
	for sx in [-0.72, 0.72]:
		var x: float = at.x + sx * half
		b.stroke(PackedVector2Array([Vector2(x, at.y - half + 0.03 * g), Vector2(x, at.y + half * 0.9)]),
			0.045 * g, colour.darkened(0.48), false, false)
	var mid := at - Vector2(0.0, half * 0.3)
	var h := g * 0.15
	b.stroke(PackedVector2Array([mid + Vector2(-h * 0.55, -h), mid + Vector2(h * 0.55, 0.0), mid + Vector2(-h * 0.55, h)]),
		g * 0.1, Pal.SURFACE)

func _lay() -> void:
	var words := _words(String(entry.get("title", "")), SIDE, size.y * 0.5, WORDS, Pal.TEXT, BLURB)
	words.position.y = roundf(WORDS_TOP * _k())
