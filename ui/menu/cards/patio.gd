extends "res://ui/menu/cards/card_face.gd"

## Domino Patio's card: a patio on the terrace's warm paper, four squares
## across and three down against the card's right side and foot, its top
## right square left off (the corner is the seal's, and a patio is never a
## plain box). Five beds in the board's own colours with their tags: a 7 the
## laid 4 and 3 keep, an all-the-same the laid double five has begun, an
## over-8 the laid 6 and 4 keep, an under-3 still open, and a bare bed with
## no rule. The go button is the next tile, the 0 and 1, held up over the
## bare bed in the card's colour, its two halves' spots in cream.
##
## Everything still is one mesh; the tags' numbers are a draw_string each
## over it, as the board writes them. Nothing lives on the card.

const Tile = preload("res://ui/faces/domino_tile.gd")
const Scenery = preload("res://ui/flat/scenery.gd")
const CozyTheme = preload("res://ui/theme.gd")

## The row the card was drawn for (puzzle_card_2d.gd's CARD_H).
const H := 246.0
## A square at H, and the patio's room from the card's right side and foot.
const CELL := 62.0
const RIGHT := 16.0
const FOOT := 14.0
const WORDS_END := 270.0
const COLS := 4
const ROWS := 3
## Each square's bed (-1 off the patio), and each bed's colour
## (Pal.REGION's index, -1 bare stone), rule ("" none) and tag square.
const BED := [[0, 0, 1, -1], [2, 1, 1, 3], [2, 4, 4, 3]]
const BEDS := [[2, "7", Vector2i(0, 0)], [3, "=", Vector2i(2, 0)], [4, "<3", Vector2i(0, 1)],
	[7, ">8", Vector2i(3, 1)], [-1, "", Vector2i(1, 2)]]
## The tiles laid: [first square, the way the second lies, the numbers].
const LAID := [[Vector2i(0, 0), Vector2i(1, 0), Vector2i(4, 3)], [Vector2i(2, 0), Vector2i(0, 1), Vector2i(5, 5)],
	[Vector2i(3, 1), Vector2i(0, 1), Vector2i(6, 4)]]
## The go tile's numbers, and the spots' cream on the card's colour.
const GO := Vector2i(0, 1)
const GO_SPOT := Color("fffaf0")

const PAPER_TOP := Color("fbf3e3")
const PAPER_LOW := Color("f0e2c6")
const GROUT := Color("c9b48f")
const STONE := Color("efe4cf")
const BLURB := Color("7a6650")

var _nums: Array = []

func _k() -> float:
	return size.y / H

func _cell() -> float:
	var k := _k()
	return minf(CELL * k, (size.x - RIGHT * k - WORDS_END) / float(COLS))

func _origin() -> Vector2:
	var c := _cell()
	var k := _k()
	return Vector2(size.x - RIGHT * k - COLS * c, size.y - FOOT * k - ROWS * c)

func _paint(b: Face.Builder) -> void:
	var c := _cell()
	var o := _origin()
	var k := _k()
	var first := b.verts.size()
	b.polygon(ground(), Color.WHITE)
	shade(b, first, PAPER_TOP, PAPER_LOW, 0.0, size.y)
	Scenery.soft_disc(b, o + Vector2(COLS * 0.5, ROWS + 0.1) * c, c * 2.6, c * 0.5, Color(Pal.TEXT, 0.14))
	for y in ROWS:
		for x in COLS:
			if BED[y][x] < 0:
				continue
			var at := o + Vector2(x, y) * c
			b.fan(Face.Builder.round_rect(at - Vector2.ONE * c * 0.06, Vector2.ONE * c * 1.12, c * 0.16), GROUT)
	for y in ROWS:
		for x in COLS:
			if BED[y][x] < 0:
				continue
			var at := o + Vector2(x, y) * c
			var k2 := int(BEDS[BED[y][x]][0])
			var col: Color = Pal.REGION[k2] if k2 >= 0 else STONE
			b.fan(Face.Builder.round_rect(at + Vector2.ONE * c * 0.05, Vector2.ONE * c * 0.9, c * 0.12), col)
	var s := c / Tile.H
	for lay: Array in LAID:
		var a: Vector2i = lay[0]
		var d: Vector2i = lay[1]
		var v: Vector2i = lay[2]
		var mid := o + (Vector2(a) + Vector2(0.5, 0.5) + Vector2(d) * 0.5) * c
		var t := Face.Builder.new()
		Tile.face(t, v.x, v.y, d.y != 0, v.x == v.y)
		b.append(t.mesh(), Transform2D(0.0, Vector2.ONE * s, 0.0, mid))
	if not soon:
		_go(b, o + Vector2(2.0, 2.32) * c, c)
	# the tags, over everything
	_nums = []
	var font: Font = CozyTheme.display(700)
	var px := int(c * 0.34)
	var rise := (font.get_ascent(px) - font.get_descent(px)) * 0.5
	for bed: Array in BEDS:
		if String(bed[1]) == "":
			continue
		var at := o + Vector2(bed[2] as Vector2i) * c + Vector2.ONE * c * 0.2
		var r := c * 0.19
		var wide := font.get_string_size(String(bed[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		var half := Vector2(maxf(r, wide * 0.5 + r * 0.45), r)
		var deep: Color = (Pal.REGION[int(bed[0])] as Color).darkened(0.38)
		b.fan(Face.Builder.round_rect(at - half + Vector2(0, 2.0 * k), half * 2.0, half.y), Color(deep, 0.6))
		b.fan(Face.Builder.round_rect(at - half, half * 2.0, half.y), Pal.SURFACE)
		b.stroke(Face.Builder.round_rect(at - half, half * 2.0, half.y), 1.8 * k, deep, true)
		if String(bed[1]) == "=":
			b.stroke(PackedVector2Array([at + Vector2(-r * 0.6, -r * 0.2), at + Vector2(r * 0.6, -r * 0.2)]), r * 0.18, Pal.TEXT)
			b.stroke(PackedVector2Array([at + Vector2(-r * 0.6, r * 0.2), at + Vector2(r * 0.6, r * 0.2)]), r * 0.18, Pal.TEXT)
		else:
			_nums.append([at + Vector2(-wide * 0.5, rise), String(bed[1]), px, Pal.TEXT])

## The go button: the next tile, held up over the open bed in the card's
## colour, over its own shadow.
func _go(b: Face.Builder, at: Vector2, c: float) -> void:
	var half := Vector2(c, c * 0.5)
	Scenery.soft_disc(b, at + Vector2(0.0, half.y + c * 0.3), c * 0.9, c * 0.16, Color(Pal.TEXT, 0.22))
	b.fan(Face.Builder.round_rect(at - half + Vector2(0, c * 0.08), half * 2.0, c * 0.16), colour.darkened(0.26))
	b.fan(Face.Builder.round_rect(at - half, half * 2.0, c * 0.16), colour)
	b.stroke(PackedVector2Array([at + Vector2(0.0, -c * 0.3), at + Vector2(0.0, c * 0.3)]), c * 0.04, Color(GO_SPOT, 0.7))
	var k := c / Tile.H
	for half_at: Array in [[Vector2(-c * 0.5, 0), GO.x], [Vector2(c * 0.5, 0), GO.y]]:
		_spots(b, at + (half_at[0] as Vector2), int(half_at[1]), k)

## A half's spots in cream: the house tile's pattern, one colour.
func _spots(b: Face.Builder, c: Vector2, n: int, k: float) -> void:
	var g := 25.0 * k
	var at: Array = []
	if n % 2 == 1:
		at.append(Vector2.ZERO)
	if n >= 2:
		at.append(Vector2(-g, -g))
		at.append(Vector2(g, g))
	if n >= 4:
		at.append(Vector2(g, -g))
		at.append(Vector2(-g, g))
	if n == 6:
		at.append(Vector2(-g, 0.0))
		at.append(Vector2(g, 0.0))
	for p: Vector2 in at:
		b.disc(c + p, 9.5 * k, GO_SPOT)

func _draw() -> void:
	super()
	var font: Font = CozyTheme.display(700)
	for n: Array in _nums:
		draw_string(font, n[0], n[1], HORIZONTAL_ALIGNMENT_LEFT, -1.0, n[2], n[3])

func _lay() -> void:
	var words := _words(String(entry.get("title", "")), 22.0, size.y * 0.5, 215.0, Pal.TEXT, BLURB)
	words.position.y = roundf(14.0 * _k())
