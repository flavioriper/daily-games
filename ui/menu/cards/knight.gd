extends "res://ui/menu/cards/card_face.gd"

## Knight's card: no board, only the squares of two hops, laid on an oat
## linen like stepping stones in the board's two checker tones. The cream
## knight stands low on the left; the L of its next hop runs two squares
## right and one up, the board's hoofprints stepping along it, and from where
## that lands a second L runs two right and one up again to the rose king,
## who sits at the far end under the seal's corner. So the seven squares
## make one crooked stair across the card, and both hops are true Ls on one
## grid. The go button is where the first hop lands: a square in the card's
## colour with a chevron, lifted. The name stands top left.
##
## Everything is one mesh: the pieces are ui/faces/chess_piece.gd's own
## builders, as the board draws them, and nothing lives on the card.

const Board = preload("res://puzzles/knight2d.gd")
const Piece = preload("res://ui/faces/chess_piece.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

## The row the card was drawn for (puzzle_card_2d.gd's CARD_H).
const H := 246.0
## A square at H, and the stair's room from the card's right side and foot.
const CELL := 52.0
const RIGHT := 18.0
const FOOT := 7.0
## The grid the stair is cut from, and its squares in the order they are
## hopped: the knight's, the two it passes, the landing, then the second L.
const COLS := 5
const ROWS := 3
const PATH: Array[Vector2i] = [Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2), Vector2i(2, 1), Vector2i(3, 1),
	Vector2i(4, 1), Vector2i(4, 0)]
const START := Vector2i(0, 2)
const GO := Vector2i(2, 1)
const KING := Vector2i(4, 0)
## A stone in cells: the gap round it, its corner, how deep its lip is, and
## its shadow.
const GAP := 0.035
const ROUND := 0.15
const LIP := 0.075
const SHADOW := 0.22
## The go square: its size in cells, how far it is lifted, and its shadow.
const GO_SIZE := 1.06
const GO_LIFT := 0.1
const GO_SHADOW := 0.24
## The hoofprints' ink, darker than the board's fading trail so they read
## at card size.
const PRINT_ALPHA := 0.5
## The words' margin and how far down they start.
const SIDE := 22.0
const WORDS := 215.0
const WORDS_TOP := 14.0

## The linen: oat over a deeper oat, and a pale pool behind the stair.
const LINEN_TOP := Color("f6efe1")
const LINEN_LOW := Color("ead9bf")
const POOL := Color("fbf6ea")
const BLURB := Color("7b6c56")

func _k() -> float:
	return size.y / H

func _cell() -> float:
	return CELL * _k()

## The grid's top left corner.
func _origin() -> Vector2:
	var s := _cell()
	var k := _k()
	return Vector2(size.x - RIGHT * k - COLS * s, size.y - FOOT * k - ROWS * s)

func _mid(cell: Vector2i) -> Vector2:
	return _origin() + (Vector2(cell) + Vector2.ONE * 0.5) * _cell()

## Both hops are Ls: two one way and one the other.
static func _is_hop(a: Vector2i, z: Vector2i) -> bool:
	var d := (z - a).abs()
	return (d.x == 2 and d.y == 1) or (d.x == 1 and d.y == 2)

func _paint(b: Face.Builder) -> void:
	var s := _cell()
	var first := b.verts.size()
	b.polygon(ground(), Color.WHITE)
	shade(b, first, LINEN_TOP, LINEN_LOW, 0.0, size.y)
	var o := _origin()
	Scenery.soft_disc(b, o + Vector2(COLS * 0.56, ROWS * 0.56) * s, s * 2.5, s * 1.5, Color(POOL, 0.5))
	# The stones' shadows under all of them, then the stones.
	for cell: Vector2i in PATH:
		if cell == GO and not soon:
			continue
		Scenery.soft_disc(b, _mid(cell) + Vector2(0.0, s * 0.42), s * 0.52, s * 0.17, Color(Pal.TEXT, SHADOW))
	for cell: Vector2i in PATH:
		if cell == GO and not soon:
			continue
		_stone(b, cell, s)
	if _is_hop(START, GO) and _is_hop(GO, KING):
		Board._hop_prints(b, _mid(START), _mid(GO), s, Color(Pal.KNIGHT_CREAM_LINE, PRINT_ALPHA))
	if not soon:
		_go(b, _mid(GO) - Vector2(0.0, s * GO_LIFT), s)
	Piece.king(b, _mid(KING), s)
	Piece.knight(b, _mid(START), s, Piece.CREAM, 1.0)

## One square of the board as a stone: its lip, its face, and the board's
## inner tile on a sage one or its speckle on a paper one. The knight stands
## on sage, so cream reads on it.
func _stone(b: Face.Builder, cell: Vector2i, s: float) -> void:
	var sage := (cell.x + cell.y) % 2 == 0
	var at := _origin() + (Vector2(cell) + Vector2.ONE * GAP) * s
	var side := s * (1.0 - 2.0 * GAP)
	var face: Color = Pal.CHESS_DARK if sage else Pal.CHESS_LIGHT
	var lip: Color = Pal.CHESS_DARK_EDGE if sage else Pal.CHESS_LIGHT.lerp(Pal.CHESS_FRAME, 0.34)
	b.polygon(Face.Builder.round_rect(at + Vector2(0.0, s * LIP), Vector2.ONE * side, s * ROUND), lip)
	b.polygon(Face.Builder.round_rect(at, Vector2.ONE * side, s * ROUND), face)
	if sage:
		b.polygon(Face.Builder.round_rect(at + Vector2.ONE * side * 0.13, Vector2.ONE * side * 0.74, s * 0.11),
			Pal.CHESS_DARK.lerp(Pal.CHESS_LIGHT, 0.2))
	else:
		var rng := RandomNumberGenerator.new()
		rng.seed = (cell.y * COLS + cell.x) * 31 + 5
		for i in 3:
			b.disc(at + Vector2(rng.randf_range(0.18, 0.82), rng.randf_range(0.18, 0.82)) * side, s * 0.016,
				Color(Pal.CHESS_DARK_EDGE, 0.5))

## The go square about `at`: a stone in the card's colour, lifted over its
## own shadow, with a chevron.
func _go(b: Face.Builder, at: Vector2, s: float) -> void:
	var side := s * GO_SIZE * (1.0 - 2.0 * GAP)
	var corner := at - Vector2.ONE * side * 0.5
	Scenery.soft_disc(b, at + Vector2(0.0, s * (0.46 + GO_LIFT)), s * 0.56, s * 0.19, Color(Pal.TEXT, GO_SHADOW))
	b.polygon(Face.Builder.round_rect(corner + Vector2(0.0, s * LIP * 1.3), Vector2.ONE * side, s * ROUND),
		colour.darkened(0.26))
	b.polygon(Face.Builder.round_rect(corner, Vector2.ONE * side, s * ROUND), colour)
	b.polygon(Face.Builder.round_rect(corner + Vector2.ONE * side * 0.1, Vector2(side * 0.8, side * 0.34), s * 0.1),
		Color(Pal.SURFACE, 0.16))
	var h := s * 0.17
	b.stroke(PackedVector2Array([at + Vector2(-h * 0.55, -h), at + Vector2(h * 0.55, 0.0), at + Vector2(-h * 0.55, h)]),
		s * 0.11, Pal.SURFACE)

func _lay() -> void:
	var words := _words(String(entry.get("title", "")), SIDE, size.y * 0.5, WORDS, Pal.TEXT, BLURB)
	words.position.y = roundf(WORDS_TOP * _k())
