extends "res://ui/menu/cards/card_face.gd"

## Toy Boats' card: a pale tub of bath water seen from above, a few ripples
## lying across it, and a loose patch of the pond's own water low on the
## right, four squares by three, with the board's lines on it. One wooden
## boat of three squares lies along its middle row, half found: the board's
## pegs stand in two of its holes, two ripples mark where a pebble found only
## water, and the square that would finish it is ringed.
##
## The go button is the throw at that square: the board's peg in the card's
## colour, large, lifted over its shadow above the ringed square, a chevron
## pointing down into it. The name stands top left.
##
## Everything is one mesh, the hull versus/boats_board.gd's own outline and
## the marks drawn as the pond draws them. Nothing lives on the card and it
## writes no string.

const Board = preload("res://versus/boats_board.gd")
const Rules = preload("res://versus/boats_rules.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

## The row the card was drawn for (puzzle_card_2d.gd's CARD_H).
const H := 246.0
## A square at H, the patch in squares, and its room from the card's right
## side and foot.
const CELL := 44.0
const COLS := 4
const ROWS := 3
const RIGHT := 18.0
const FOOT := 16.0
## The words end here: the patch never starts left of it.
const WORDS_END := 250.0
## The patch's corner and how far its frame of deeper water stands out, in
## squares.
const ROUND := 0.3
const RIM := 0.09
## The boat: which of the fleet it is (three squares), the square of its
## stern and the squares already pegged.
const BOAT := 2
const STERN := Vector2i(1, 1)
const HIT: Array[Vector2i] = [Vector2i(1, 1), Vector2i(2, 1)]
const AIM := Vector2i(3, 1)
const MISSES: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 2)]
## The go peg: its radius in squares, how far over the square it hangs, and
## its shadow.
const GO_R := 0.5
const GO_UP := 0.98
const GO_SHADOW := 0.26
## The ripples on the tub, as [x in the card's width, y at H, length at H].
const RIPPLES := [[0.46, 196.0, 34.0], [0.3, 222.0, 26.0], [0.52, 84.0, 30.0], [0.1, 204.0, 22.0]]
## The words' margin, their room and how far down they start.
const SIDE := 22.0
const WORDS := 215.0
const WORDS_TOP := 14.0

## The tub: its water top to foot, the ripples' ink, the patch's water (the
## pond's, lightened so the paper stays the pale one) and the blurb's ink.
const TUB_TOP := Color("e3f3fa")
const TUB_LOW := Color("c9e6f3")
const RIPPLE := Color("9fcbe4")
const POND := Color("6fb3dc")
const POND_LOW := Color("5aa3d1")
const POND_RIM := Color("8ec6e6")
const BLURB := Color("4f6b7c")

func _kh() -> float:
	return size.y / H

## One square: the card's height sets it, the words cap it.
func _cell() -> float:
	var k := _kh()
	return minf(CELL * k, (size.x - RIGHT * k - WORDS_END) / float(COLS))

## The patch's top left corner.
func _origin() -> Vector2:
	var s := _cell()
	var k := _kh()
	return Vector2(size.x - RIGHT * k - COLS * s, size.y - FOOT * k - ROWS * s)

func _mid(cell: Vector2i) -> Vector2:
	return _origin() + (Vector2(cell) + Vector2.ONE * 0.5) * _cell()

func _paint(b: Face.Builder) -> void:
	var k := _kh()
	var s := _cell()
	var u := s / Board.U
	var first := b.verts.size()
	b.polygon(ground(), Color.WHITE)
	shade(b, first, TUB_TOP, TUB_LOW, 0.0, size.y)
	for r: Array in RIPPLES:
		_ripple(b, Vector2(size.x * float(r[0]), float(r[1]) * k), float(r[2]) * k, k)
	# The patch of pond: a paler rim, the water, the light on it, its lines.
	var o := _origin()
	var all := Vector2(COLS, ROWS) * s
	Scenery.soft_disc(b, o + all * 0.5 + Vector2(0.0, s * 0.08), all.x * 0.5 + 10.0 * k, all.y * 0.5 + 8.0 * k, Color(Board.WATER_DEEP, 0.2))
	b.polygon(Face.Builder.round_rect(o - Vector2.ONE * s * RIM, all + Vector2.ONE * s * RIM * 2.0, s * (ROUND + RIM)), POND_RIM)
	first = b.verts.size()
	b.polygon(Face.Builder.round_rect(o, all, s * ROUND), Color.WHITE)
	shade(b, first, POND, POND_LOW, o.y, o.y + all.y)
	Scenery.soft_disc(b, o + Vector2(all.x * 0.3, all.y * 0.3), all.x * 0.28, all.y * 0.26, Color(1, 1, 1, 0.12))
	for i in range(1, COLS):
		b.stroke(PackedVector2Array([o + Vector2(i * s, s * 0.12), o + Vector2(i * s, all.y - s * 0.12)]), s * 0.022, Board.WATER_LINE)
	for i in range(1, ROWS):
		b.stroke(PackedVector2Array([o + Vector2(s * 0.12, i * s), o + Vector2(all.x - s * 0.12, i * s)]), s * 0.022, Board.WATER_LINE)
	# Where a pebble found only water: the pond's ring and dot.
	for cell: Vector2i in MISSES:
		var m := _mid(cell)
		b.stroke(Face.Builder.ring(m, s * 0.2, s * 0.2), s * 0.045, Color(1, 1, 1, 0.8), true)
		b.disc(m, s * 0.06, Color(1, 1, 1, 0.8))
	_boat(b, _mid(STERN), u)
	for cell: Vector2i in HIT:
		var m := _mid(cell)
		b.disc(m + Vector2(0.03, 0.06) * s, s * 0.2, Color(0.25, 0.1, 0.05, 0.3))
		b.disc(m, s * 0.2, Board.PEG)
		b.disc(m + Vector2(-0.05, -0.06) * s, s * 0.1, Board.PEG_LIT)
	if soon:
		return
	# The square that finishes it, ringed as the board rings a hint.
	var aim := _mid(AIM)
	b.stroke(Face.Builder.ring(aim, s * 0.34, s * 0.34), s * 0.07, Board.HINT, true)
	_go(b, aim - Vector2(0.0, s * GO_UP), aim, s)

## The wooden boat, its stern's square at `at`, lying along the row: the
## board's hull outline, deck, line of paint, grain and a hole a square.
func _boat(b: Face.Builder, at: Vector2, u: float) -> void:
	var n: int = Rules.FLEET[BOAT]
	var lift := Board.U * 0.06
	var shadow := PackedVector2Array()
	for p in Board.hull_points(BOAT):
		shadow.append(at + (p + Vector2(lift * 0.5, lift)) * u)
	b.polygon(shadow, Board.SHADE)
	b.polygon(_laid(Board.hull_points(BOAT), at, u), Board.HULL_RIM)
	b.polygon(_laid(Board.hull_points(BOAT, -0.055 * Board.U), at + Vector2(-0.01, -0.02) * Board.U * u, u), Board.HULL)
	b.stroke(_laid(Board.hull_points(BOAT, -0.13 * Board.U), at, u), 0.05 * Board.U * u, Board.PAINT[BOAT], true)
	b.stroke(PackedVector2Array([at + Vector2(-0.2, -0.07) * Board.U * u, at + Vector2((n - 1) + 0.05, -0.07) * Board.U * u]),
		0.018 * Board.U * u, Color(Board.HULL_RIM, 0.3))
	b.stroke(PackedVector2Array([at + Vector2(-0.12, 0.08) * Board.U * u, at + Vector2((n - 1) - 0.1, 0.08) * Board.U * u]),
		0.018 * Board.U * u, Color(Board.HULL_RIM, 0.3))
	for i in n:
		var hole := at + Vector2(i, 0.0) * Board.U * u
		b.disc(hole, 0.085 * Board.U * u, Board.HOLE)
		b.disc(hole + Vector2(0.012, 0.02) * Board.U * u, 0.06 * Board.U * u, Color(0.2, 0.12, 0.06, 0.5))

static func _laid(points: PackedVector2Array, at: Vector2, u: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		out.append(at + p * u)
	return out

## The go peg about `at`, over the square at `home`: its shadow on the
## water, its side, its top in the card's colour, a pale patch of light and
## a chevron pointing down.
func _go(b: Face.Builder, at: Vector2, home: Vector2, s: float) -> void:
	var r := s * GO_R
	Scenery.soft_disc(b, home + Vector2(0.0, s * 0.04), r * 0.86, r * 0.5, Color(0.05, 0.15, 0.25, GO_SHADOW))
	b.disc(at + Vector2(0.0, r * 0.14), r, colour.darkened(0.28))
	b.disc(at, r, colour)
	Scenery.soft_disc(b, at + Vector2(-0.26, -0.3) * r, r * 0.42, r * 0.3, Color(Pal.SURFACE, 0.22))
	var h := r * 0.36
	b.stroke(PackedVector2Array([at + Vector2(-h, -h * 0.5), at + Vector2(0.0, h * 0.55), at + Vector2(h, -h * 0.5)]),
		r * 0.22, Pal.SURFACE)

## A ripple on the tub: a slow wave of line, `length` long from `at`.
func _ripple(b: Face.Builder, at: Vector2, length: float, k: float) -> void:
	var pts := PackedVector2Array()
	for i in 9:
		pts.append(at + Vector2(length * i / 8.0, sin(i * 0.9) * 2.2 * k))
	b.stroke(pts, 2.4 * k, Color(RIPPLE, 0.55))

func _lay() -> void:
	var words := _words(String(entry.get("title", "")), SIDE, size.y * 0.5, WORDS, Pal.TEXT, BLURB)
	words.position.y = roundf(WORDS_TOP * _kh())
