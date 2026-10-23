extends "res://ui/menu/cards/card_face.gd"

## Sudoku's card: every number once, every way you look, drawn as the three
## ways meeting. The bottom row of the grid runs along the card's foot, the
## seventh column climbs from it off the top of the card, and the region the
## two share stands whole in the corner between them, all of it the board's
## own tray: wood, grooves, paper panels, thin rules, the peers' sun wash.
## The row, the column and the region each hold eight digits and the one cell
## all three share is empty -- the go button, a tile in the card's colour
## lifted off its panel as the board lifts a selected cell. The digit it
## wants is the one none of the three has: a 7.
##
## The name stands on a sage cloth, top left, and the top right corner is
## left to the seal: the column passes it on the left and the region starts
## under it. Everything is one mesh; the digits are strings over it, givens
## in ink and written ones in leaf as on the board. Nothing lives here: the
## board seats no character.

const Board = preload("res://puzzles/sudoku2d.gd")
const Scenery = preload("res://ui/flat/scenery.gd")
const CozyTheme = preload("res://ui/theme.gd")

## The row the card was drawn for (puzzle_card_2d.gd's CARD_H).
const H := 246.0
## A cell at H; the grid's margin from the card's right side and foot; the
## words' margin, the room they are owed and the gap to the region.
const CELL := 46.0
const RIGHT := 20.0
const FOOT := 16.0
const SIDE := 22.0
const WORDS := 258.0
const WORDS_GAP := 12.0
## The grid is nine by nine; the cell the three share.
const N := 9
const GO := Vector2i(6, 8)
## The go tile, in cells: its side, its lift and its foot.
const GO_SIDE := 1.0
const GO_LIFT := 0.03
const GO_FOOT := 0.1

## The fragment, as [column, row, digit, written]: row 8 reads
## 2 9 5 | 8 1 3 | _ 4 6, column 6 reads 3 8 1 | 6 4 9 | 5 2 _ downward, and
## the region is 5 9 1 / 2 3 8 / _ 4 6. Each lacks only the 7.
const DIGITS := [
	[0, 8, 2, false], [1, 8, 9, false], [2, 8, 5, true], [3, 8, 8, false], [4, 8, 1, false],
	[5, 8, 3, true], [7, 8, 4, false], [8, 8, 6, true],
	[6, 0, 3, false], [6, 1, 8, false], [6, 2, 1, false], [6, 3, 6, true], [6, 4, 4, false],
	[6, 5, 9, false], [6, 6, 5, false], [6, 7, 2, true],
	[7, 6, 9, false], [8, 6, 1, true], [7, 7, 3, false], [8, 7, 8, false],
]
## The paper panels, as [column, row, wide, tall, shaded]: two of the row,
## the whole region, two of the column, chequered as the board's are.
const PANELS := [
	[0, 8, 3, 1, false], [3, 8, 3, 1, true], [6, 6, 3, 3, false],
	[6, 3, 1, 3, true], [6, 0, 1, 3, false],
]
## The wood under them: the row, the column, the region.
const WOOD := [[0, 8, 9, 1], [6, 0, 1, 9], [6, 6, 3, 3]]

const CLOTH_TOP := Color("eff2e6")
const CLOTH_LOW := Color("dde6d2")
const BLURB := Color("686c5a")

## The digits, as [baseline, text, px, ink], written over the mesh.
var _nums: Array = []

func _k() -> float:
	return size.y / H

## A cell: the card's scale, unless the region would crowd the words.
func _cell() -> float:
	var wide := (size.x - SIDE - WORDS - WORDS_GAP - RIGHT) / 3.0
	return minf(CELL * _k(), wide)

## The grid's top left corner: its last row on the card's foot, its last
## column by the card's right side, the rest running off the top and left.
func _origin() -> Vector2:
	var c := _cell()
	return Vector2(size.x - RIGHT - N * c, size.y - FOOT * _k() - N * c)

func _at(col: int, row: int) -> Vector2:
	return _origin() + Vector2(col, row) * _cell()

## `poly` laid in `b`, as much of it as is on the paper.
func _put(b: Face.Builder, paper: PackedVector2Array, poly: PackedVector2Array, ink: Color) -> void:
	for part in Geometry2D.intersect_polygons(paper, poly):
		b.polygon(part, ink)

## Whether the middle of cell (`col`, `row`) stands on the paper with room
## for a digit.
func _whole(paper: PackedVector2Array, col: int, row: int) -> bool:
	var c := _cell()
	var mid := _at(col, row) + Vector2.ONE * c * 0.5
	for d: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		if not Geometry2D.is_point_in_polygon(mid + d * c * 0.36, paper):
			return false
	return true

func _paint(b: Face.Builder) -> void:
	var c := _cell()
	var k := c / Board.CELL
	var paper := ground()
	var first := b.verts.size()
	b.polygon(paper, Color.WHITE)
	shade(b, first, CLOTH_TOP, CLOTH_LOW, 0.0, size.y)
	_trays(b, paper, WOOD, k)
	# The panels, each over its lip, and the thin rules between their cells.
	for p in PANELS:
		_panel(b, paper, p[0], p[1], p[2], p[3], Pal.GRID_TINT if p[4] else Pal.SURFACE, k)
	# Every cell shown is a peer of the one that is open: the board's wash,
	# and the digit over it.
	_nums = []
	var font: Font = CozyTheme.display(600)
	var px := int(roundf(Board.DIGIT_SIZE * k))
	var rise := font.get_ascent(px) * 0.5
	var inset := Board.WASH_INSET * k
	for d in DIGITS:
		if not _whole(paper, d[0], d[1]):
			continue
		var at := _at(d[0], d[1])
		b.polygon(Face.Builder.round_rect(at + Vector2.ONE * inset, Vector2.ONE * (c - 2.0 * inset),
			Board.WASH_R * k), Color(Pal.SUN, Board.WASH_PEER))
		var text := str(d[2])
		var wide := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, px).x
		_nums.append([at + Vector2(c * 0.5 - wide * 0.5, c * 0.5 + rise), text, px,
			Pal.LEAF_DEEP if d[3] else Pal.TEXT])
	if not soon:
		_go(b, _at(GO.x, GO.y), c)

## The trays under `rects` ([column, row, wide, tall] in cells): their
## shadow on the cloth, lip, face and floor, as sudoku2d.gd's _tray lays
## them, each pass over all of them so two trays read as one.
func _trays(b: Face.Builder, paper: PackedVector2Array, rects: Array, k: float) -> void:
	var c := _cell()
	var f := Board.FRAME * k
	var r := (Board.CORNER + Board.FRAME * 0.5) * k
	var face: Color = Pal.GRID_RULE
	var floor_ink := face.darkened(Board.FLOOR_DARKEN)
	for pass_i in 4:
		for w in rects:
			var at := _at(w[0], w[1])
			var side := Vector2(w[2], w[3]) * c
			match pass_i:
				0:
					_put(b, paper, Face.Builder.round_rect(at - Vector2(f, f - 9.0 * k), side + Vector2.ONE * 2.0 * f, r),
						Color(Pal.TEXT, 0.08))
				1:
					_put(b, paper, Face.Builder.round_rect(at - Vector2(f, f - Board.TRAY_LIP * k),
						side + Vector2.ONE * 2.0 * f, r), Pal.WOOD_DEEP)
				2:
					_put(b, paper, Face.Builder.round_rect(at - Vector2.ONE * f, side + Vector2.ONE * 2.0 * f, r), face)
				3:
					_put(b, paper, Face.Builder.round_rect(at - Vector2.ONE * k, side + Vector2.ONE * 2.0 * k,
						Board.PANEL_R * k), floor_ink)

## A paper panel `wide` by `tall` cells from (`col`, `row`), over its lip,
## with the thin rules between its cells.
func _panel(b: Face.Builder, paper: PackedVector2Array, col: int, row: int, wide: int, tall: int, ink: Color,
		k: float, thin_a := Board.THIN_ALPHA) -> void:
	var c := _cell()
	var g := Board.GUTTER * k * 0.5
	var pr := Board.PANEL_R * k
	var thin := Color(Pal.LINE, thin_a)
	var thin_w := maxf(Board.THIN_W * k, 1.0)
	var at := _at(col, row)
	var side := Vector2(wide, tall) * c
	var inner := side - Vector2.ONE * 2.0 * g
	_put(b, paper, Face.Builder.round_rect(at + Vector2(g, g + Board.PANEL_LIP * k), inner, pr),
		ink.lerp(Pal.GRID_RULE, 0.45))
	_put(b, paper, Face.Builder.round_rect(at + Vector2.ONE * g, inner, pr), ink)
	for i in range(1, wide):
		var x := at.x + i * c
		_rule(b, Vector2(x, at.y + g + pr * 0.5), Vector2(x, at.y + side.y - g - pr * 0.5), thin_w, thin)
	for i in range(1, tall):
		var y := at.y + i * c
		_rule(b, Vector2(at.x + g + pr * 0.5, y), Vector2(at.x + side.x - g - pr * 0.5, y), thin_w, thin)

## A thin rule from `a` to `z`, kept on the card.
func _rule(b: Face.Builder, a: Vector2, z: Vector2, w: float, ink: Color) -> void:
	var lo := Vector2.ONE * (EDGE + 1.0)
	var hi := size - lo
	if a.x < lo.x or a.x > hi.x or z.y < lo.y or a.y > hi.y or z.x < lo.x:
		return
	a = a.clamp(lo, hi)
	z = z.clamp(lo, hi)
	if a.distance_to(z) < 2.0:
		return
	b.stroke(PackedVector2Array([a, z]), w, ink, false, false)

## The go button: the cell the row, the column and the region share, a tile
## in the card's colour lifted off its panel over a soft shadow, a chevron
## where its digit will be.
func _go(b: Face.Builder, at: Vector2, c: float) -> void:
	var side := c * GO_SIDE
	var foot := c * GO_FOOT
	var round := c * 0.2
	var mid := at + Vector2.ONE * c * 0.5
	Scenery.soft_disc(b, mid + Vector2(0.0, c * 0.36), side * 0.56, c * 0.22, Color(Pal.TEXT, Board.SEL_SHADOW_A))
	var tile := mid - Vector2(side, side) * 0.5 - Vector2(0.0, c * GO_LIFT)
	b.polygon(Face.Builder.round_rect(tile, Vector2(side, side), round), colour.darkened(0.24))
	b.polygon(Face.Builder.round_rect(tile, Vector2(side, side - foot), round), colour)
	b.stroke(PackedVector2Array([tile + Vector2(round, c * 0.07), tile + Vector2(side - round, c * 0.07)]),
		c * 0.05, Color(1.0, 1.0, 1.0, 0.28), false, true)
	var top := tile + Vector2(side, side - foot) * 0.5
	var h := c * 0.2
	b.stroke(PackedVector2Array([top + Vector2(-h * 0.55, -h), top + Vector2(h * 0.55, 0.0),
		top + Vector2(-h * 0.55, h)]), c * 0.12, Pal.SURFACE)

func _draw() -> void:
	super()
	var font: Font = CozyTheme.display(600)
	for n in _nums:
		draw_string(font, n[0], n[1], HORIZONTAL_ALIGNMENT_LEFT, -1.0, n[2], n[3])

func _lay() -> void:
	# The words stand on the cloth over the row, left of the region.
	var c := _cell()
	var room := _at(GO.x, GO.y).x - Board.FRAME * c / Board.CELL - SIDE - WORDS_GAP
	var row_top := _at(0, N - 1).y - Board.FRAME * c / Board.CELL
	_words(String(entry.get("title", "")), SIDE, row_top * 0.5 + 2.0, room, Pal.TEXT, BLURB)
