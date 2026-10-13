extends "res://ui/menu/cards/card_face.gd"

## Lattice's card: the lattice in its own open shape on a pale slate paper.
## Four rows of a five-by-five stand against the card's right side and foot
## (the top row is left off: its corner is the seal's): three wooden slats
## up and two across, a tile at every crossing and between, and the gaps
## between them left as gaps. Every tile is home and leaf green but two, a 4
## over a 3 in the fourth column, each sitting in the other's cell with the
## board's sun rim round it: the two whole rows each hold one number twice
## and lack another, and changing those two places finishes both, which
## `_swap_finishes` checks. Three gaps carry the board's knots, their sums
## counted from the answer and leaf where every tile they point at is home.
##
## The go button is the swap: a round token in the card's colour in the gap
## between the two tiles, lifted over its shadow, an arrow up and an arrow
## down on it. It is not a tile, because the card's colour is sage and a
## sage tile would read as one at home.
##
## Everything still is one mesh in ui/faces/lattice_art.gd's own builders;
## the numerals are a draw_string each over it, as the board writes them.
## Nothing lives on the card.

const Board = preload("res://puzzles/lattice2d.gd")
const Art = preload("res://ui/faces/lattice_art.gd")
const Scenery = preload("res://ui/flat/scenery.gd")
const CozyTheme = preload("res://ui/theme.gd")

## The row the card was drawn for (puzzle_card_2d.gd's CARD_H).
const H := 246.0
## A cell at H, and the lattice's room from the card's right side and foot.
const CELL := 42.0
const RIGHT := 12.0
const FOOT := 9.0
## The words end here: the lattice never starts left of it.
const WORDS_END := 274.0
## The piece shown: five columns, four rows, a gap where both are odd
## counting the row left off. `ANSWER` is what goes where, 0 a gap.
const COLS := 5
const ROWS := 4
const ANSWER := [
	[2, 0, 1, 0, 3],
	[1, 4, 5, 3, 2],
	[4, 0, 2, 0, 4],
	[5, 2, 3, 4, 1],
]
## The two tiles in each other's cells, and the gap between them.
const SWAP_A := Vector2i(3, 1)
const SWAP_B := Vector2i(3, 3)
const GO := Vector2i(3, 2)
## The knots: the gap each sits in and the ways it points.
const KNOTS := [[Vector2i(1, 0), "LR"], [Vector2i(3, 0), "LD"], [Vector2i(1, 2), "UR"]]
## The token in cells: its radius, how far it is lifted, its shadow.
const GO_R := 0.52
const GO_LIFT := 0.08
const GO_SHADOW := 0.26
## The words' margin, their room and how far down they start.
const SIDE := 22.0
const WORDS := 215.0
const WORDS_TOP := 14.0

## The slate: paper over a deeper paper, a pale pool behind the lattice, and
## the blurb's ink.
const SLATE_TOP := Color("eef2f9")
const SLATE_LOW := Color("dde5f1")
const POOL := Color("f8fafd")
const BLURB := Color("65708a")

## The numerals `_paint` laid: [baseline start, text, px, ink].
var _nums: Array = []

func _k() -> float:
	return size.y / H

## A cell: the card's height sets it, the words cap it.
func _cell() -> float:
	var k := _k()
	return minf(CELL * k, (size.x - RIGHT * k - WORDS_END) / float(COLS))

func _origin() -> Vector2:
	var c := _cell()
	var k := _k()
	return Vector2(size.x - RIGHT * k - COLS * c, size.y - FOOT * k - ROWS * c)

func _mid(cell: Vector2i) -> Vector2:
	return _origin() + (Vector2(cell) + Vector2.ONE * 0.5) * _cell()

## What a cell shows: the answer, with the two swapped tiles traded.
static func _shown(cell: Vector2i) -> int:
	if cell == SWAP_A:
		return ANSWER[SWAP_B.y][SWAP_B.x]
	if cell == SWAP_B:
		return ANSWER[SWAP_A.y][SWAP_A.x]
	return ANSWER[cell.y][cell.x]

static func _home(cell: Vector2i) -> bool:
	return cell != SWAP_A and cell != SWAP_B

## True when every whole row of the answer holds 1 to COLS once and the two
## rows of the swap do not as shown: the one trade finishes both.
static func _swap_finishes() -> bool:
	for y in ROWS:
		if ANSWER[y].has(0):
			continue
		var want: Array = ANSWER[y].duplicate()
		want.sort()
		if want != [1, 2, 3, 4, 5]:
			return false
	for cell: Vector2i in [SWAP_A, SWAP_B]:
		var row: Array = []
		for x in COLS:
			row.append(_shown(Vector2i(x, cell.y)))
		row.sort()
		if row == [1, 2, 3, 4, 5]:
			return false
	return ANSWER[SWAP_A.y][SWAP_A.x] != ANSWER[SWAP_B.y][SWAP_B.x]

func _paint(b: Face.Builder) -> void:
	var c := _cell()
	var o := _origin()
	var first := b.verts.size()
	b.polygon(ground(), Color.WHITE)
	shade(b, first, SLATE_TOP, SLATE_LOW, 0.0, size.y)
	Scenery.soft_disc(b, o + Vector2(COLS * 0.5, ROWS * 0.5) * c, c * 2.6, c * 1.9, Color(POOL, 0.6))
	# The slats: the three columns under the two rows, then a socket a tile.
	for x in COLS:
		if ANSWER[0][x] != 0:
			Art.slat(b, o + Vector2(x * c, 0.0), Vector2(c, ROWS * c), c)
	for y in ROWS:
		if not ANSWER[y].has(0):
			Art.slat(b, o + Vector2(0.0, y * c), Vector2(COLS * c, c), c)
	for y in ROWS:
		for x in COLS:
			if ANSWER[y][x] != 0:
				Art.socket(b, _mid(Vector2i(x, y)), c)
	# The knots, leaf where all they point at is home.
	_nums = []
	var font: Font = CozyTheme.display(700)
	var knot_px := int(c * Board.KNOT_DIGIT)
	var knot_rise := (font.get_ascent(knot_px) - font.get_descent(knot_px)) * 0.5
	for knot: Array in KNOTS:
		var at: Vector2i = knot[0]
		var sum := 0
		var done := true
		for d in String(knot[1]):
			var to := at + Vector2i(Art.WAY[d])
			sum += int(ANSWER[to.y][to.x])
			done = done and _home(to)
		Art.knot(b, _mid(at), c, knot[1], done)
		_ink(font, str(sum), _mid(at) + Vector2(0.0, knot_rise), knot_px, Pal.PAPER)
	# The tiles, the two that trade places on the board's sun rim.
	var ok := _swap_finishes()
	var px := int(c * Board.DIGIT)
	var rise := (font.get_ascent(px) - font.get_descent(px)) * 0.5 - c * Art.FACE_RISE
	for y in ROWS:
		for x in COLS:
			var cell := Vector2i(x, y)
			if ANSWER[y][x] == 0:
				continue
			var home := _home(cell) or not ok
			var at := _mid(cell)
			if not home and not soon:
				var s := c * (Art.TILE + 0.1)
				b.fan(Face.Builder.round_rect(at - Vector2.ONE * s * 0.5, Vector2.ONE * s,
					c * (Art.TILE_RADIUS + 0.04)), Pal.SUN)
			Art.tile(b, at, c, home)
			_ink(font, str(_shown(cell) if ok else int(ANSWER[y][x])), at + Vector2(0.0, rise), px,
				Pal.SURFACE if home else Pal.TEXT)
	if not soon and ok:
		_go(b, _mid(GO) - Vector2(0.0, c * GO_LIFT), c)

## One numeral centred on `at`'s x, its baseline at `at`'s y.
func _ink(font: Font, text: String, at: Vector2, px: int, ink: Color) -> void:
	var wide := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, px).x
	_nums.append([at - Vector2(wide * 0.5, 0.0), text, px, ink])

## The go token about `at`: a disc in the card's colour over its shadow and
## its own deep edge, an arrow up and an arrow down for the trade.
func _go(b: Face.Builder, at: Vector2, c: float) -> void:
	var r := c * GO_R
	Scenery.soft_disc(b, at + Vector2(0.0, r * 0.9 + c * GO_LIFT), r * 1.05, r * 0.36, Color(Pal.TEXT, GO_SHADOW))
	b.disc(at + Vector2(0.0, c * 0.07), r, colour.darkened(0.26))
	b.disc(at, r, colour)
	b.disc(at - Vector2(0.0, r * 0.3), r * 0.62, Color(Pal.SURFACE, 0.1))
	var w := c * 0.09
	var reach := r * 0.52
	var head := r * 0.3
	for side: float in [-1.0, 1.0]:
		var x := at.x + side * r * 0.3
		# The left arrow points up, the right one down.
		var tip := Vector2(x, at.y + side * reach)
		var tail := Vector2(x, at.y - side * reach)
		b.stroke(PackedVector2Array([tail, tip]), w, Pal.SURFACE)
		b.stroke(PackedVector2Array([tip + Vector2(-head, -side * head), tip, tip + Vector2(head, -side * head)]),
			w, Pal.SURFACE)

func _draw() -> void:
	super()
	var font: Font = CozyTheme.display(700)
	for n: Array in _nums:
		draw_string(font, n[0], n[1], HORIZONTAL_ALIGNMENT_LEFT, -1.0, n[2], n[3])

func _lay() -> void:
	var words := _words(String(entry.get("title", "")), SIDE, size.y * 0.5, WORDS, Pal.TEXT, BLURB)
	words.position.y = roundf(WORDS_TOP * _k())
