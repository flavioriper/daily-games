extends "res://ui/menu/cards/card_face.gd"

## Caterpillar's card: the walk itself on a mint lawn, and no framed board.
## The caterpillar's one body comes in low on the left, runs the card's foot,
## climbs the right side and turns back left under the seal's corner, every
## bend a right angle between the centres of the board's squares, so what is
## shown is a legal walk. Only the squares it has crossed, and the few beside
## them, are laid. The square ahead of its head is the go button, in the
## card's colour with a chevron the way it crawls, and past it lies leaf 2,
## the next the board would let it eat. The name stands top left and the top
## right corner is left to the seal.
##
## Everything is one mesh: the squares, the body and head through
## `ui/faces/caterpillar.gd`'s own builders, the leaf and its badge redrawn
## from `caterpillar2d.gd`'s (instance methods there). The badge's numeral is
## one string over the mesh, as the board writes it. Nothing lives on it.

const Board = preload("res://puzzles/caterpillar2d.gd")
const Cat = preload("res://ui/faces/caterpillar.gd")
const Scenery = preload("res://ui/flat/scenery.gd")
const CozyTheme = preload("res://ui/theme.gd")

## The row the card was drawn for (puzzle_card_2d.gd's CARD_H).
const H := 246.0
## A square at H, and the lawn's margin from the card's right side and foot.
const CELL := 46.0
const RIGHT := 14.0
const FOOT := 12.0
## The walk's top row, counted up from the foot, the column (from the right)
## the head is on, and how many columns of that row are laid.
const TOP_ROW := 2
const HEAD_COL := 2
const TOP_COLS := 5
## The middle row's laid squares, from the right.
const MID_COLS := 3
## How near the left side the tail's tip may lie.
const TAIL_IN := 28.0
## The words' margin, the room they are owed and how far down they start.
const SIDE := 22.0
const WORDS := 215.0
const WORDS_GAP := 6.0
const WORDS_TOP := 14.0
## The go square, in squares, and how far it is lifted.
const GO_SIZE := 1.04
const GO_LIFT := 0.07

## The lawn: a light mint running a little deeper to the foot.
const LAWN_TOP := Color("eaf6e6")
const LAWN_LOW := Color("cfe9cd")
const BLURB := Color("5f7a5c")

## The numeral, [centre, text], written over the mesh.
var _nums: Array = []

func _k() -> float:
	return size.y / H

## The walk's own scale: the card's, unless the words want the room.
func _ks() -> float:
	var wide := (size.x - SIDE - WORDS - WORDS_GAP) / (RIGHT + float(TOP_COLS) * CELL)
	return minf(_k(), wide)

func _cell() -> float:
	return CELL * _ks()

## The centre of the square `col` in from the right and `row` up from the foot.
func _mid(col: int, row: int) -> Vector2:
	var c := _cell()
	return Vector2(size.x - RIGHT * _ks() - (float(col) + 0.5) * c, size.y - FOOT * _ks() - (float(row) + 0.5) * c)

## The furthest column of the foot row the tail's tip lies on.
func _tail_col() -> int:
	return maxi(HEAD_COL + 2, int(floor((size.x - RIGHT * _ks() - TAIL_IN) / _cell() - 0.5)))

## `pts` in `ink`, as much of it as lies on the paper.
func _on_paper(b: Face.Builder, paper: PackedVector2Array, pts: PackedVector2Array, ink: Color) -> void:
	for part in Geometry2D.intersect_polygons(paper, pts):
		b.polygon(part, ink)

func _paint(b: Face.Builder) -> void:
	var c := _cell()
	var paper := ground()
	var first := b.verts.size()
	b.polygon(paper, Color.WHITE)
	shade(b, first, LAWN_TOP, LAWN_LOW, 0.0, size.y)
	_nums.clear()
	# The squares the walk has crossed and the few beside it.
	var tail := _tail_col()
	for col in range(0, tail + 2):
		_tile(b, paper, col, 0, c)
	for col in MID_COLS:
		_tile(b, paper, col, 1, c)
	for col in TOP_COLS:
		_tile(b, paper, col, TOP_ROW, c)
	# Leaf 2 past the go square, as the board lays a leaf not yet eaten.
	var leaf_at := _mid(HEAD_COL + 2, TOP_ROW)
	_leaf(b, leaf_at, c)
	_badge(b, leaf_at, c)
	_nums.append([leaf_at, "2"])
	# The go button: the square ahead of the head.
	if not soon:
		_go(b, _mid(HEAD_COL + 1, TOP_ROW) - Vector2(0.0, c * GO_LIFT), c)
	# The walk, tail first: the foot row, up the right side, back to the left.
	var pts := PackedVector2Array()
	for col in range(tail, -1, -1):
		pts.append(_mid(col, 0))
	for row in range(1, TOP_ROW + 1):
		pts.append(_mid(0, row))
	for col in range(1, HEAD_COL + 1):
		pts.append(_mid(col, TOP_ROW))
	var scales: Array = []
	var breath := PackedFloat32Array()
	for i in pts.size():
		scales.append(Vector2.ONE)
		breath.append(1.0)
	Cat.body(b, pts, c, scales, breath)
	Cat.head(b, pts[pts.size() - 1], Vector2.LEFT, c, 1.0, Vector2.ONE, Face.Expr.HAPPY, 1.0)

## One square of the lawn, as the board lays it (lip, face, a glint), kept on
## the paper.
func _tile(b: Face.Builder, paper: PackedVector2Array, col: int, row: int, c: float) -> void:
	var gap := Board.TILE_GAP * c / CELL * 0.5
	var side := c - gap * 2.0
	var at := _mid(col, row) - Vector2.ONE * (side * 0.5)
	var tone := Pal.MEADOW.lerp(Pal.SURFACE, 0.34 if (col + row) % 2 == 0 else 0.18)
	var radius := c * Board.TILE_R
	_on_paper(b, paper, Face.Builder.round_rect(at + Vector2(0.0, c * 0.05), Vector2.ONE * side, radius),
		Pal.MEADOW_LINE.lerp(Pal.LEAF, 0.18))
	_on_paper(b, paper, Face.Builder.round_rect(at, Vector2.ONE * side, radius), tone)
	_on_paper(b, paper, Face.Builder.round_rect(at + Vector2(side * 0.1, side * 0.06),
		Vector2(side * 0.5, side * 0.05), side * 0.025), Color(Pal.SURFACE, 0.35))

## A whole leaf about `mid`: Board._leaf_shape's, with no bite out of it.
func _leaf(b: Face.Builder, mid: Vector2, s: float) -> void:
	var xf := Transform2D(Board.LEAF_ANGLE, mid + Vector2(s * 0.03, s * 0.02))
	var ln := s * Board.LEAF_LEN
	var wd := s * Board.LEAF_WIDE
	var root := Vector2(-ln * 0.5, 0.0)
	var tip := Vector2(ln * 0.5, 0.0)
	var pts := Face.Builder.bezier3(root, Vector2(-ln * 0.2, -wd * 0.75), Vector2(ln * 0.3, -wd * 0.55), tip, 12)
	pts.append_array(Face.Builder.bezier3(tip, Vector2(ln * 0.3, wd * 0.55), Vector2(-ln * 0.2, wd * 0.75), root, 12))
	var under := PackedVector2Array()
	for p in pts:
		under.append(p + Vector2(0.0, s * 0.03).rotated(-Board.LEAF_ANGLE))
	b.polygon(xf * under, Pal.LEAF_DEEP)
	b.polygon(xf * pts, Pal.LEAF_LIGHT)
	b.stroke(xf * PackedVector2Array([root + Vector2(ln * 0.02, 0.0), tip - Vector2(ln * 0.08, 0.0)]), s * 0.022, Pal.LEAF)
	for q in 3:
		var x := -ln * 0.28 + ln * 0.22 * float(q)
		for side: float in [-1.0, 1.0]:
			b.stroke(xf * PackedVector2Array([Vector2(x, 0.0), Vector2(x + ln * 0.12, side * wd * 0.26)]),
				s * 0.014, Color(Pal.LEAF, 0.8))
	b.stroke(xf * PackedVector2Array([root, root - Vector2(ln * 0.1, -wd * 0.05)]), s * 0.028, Pal.LEAF_DEEP)

## The leaf's number badge about `mid`, as Board._badge_shape rounds one.
func _badge(b: Face.Builder, mid: Vector2, s: float) -> void:
	var r := s * Board.BADGE_R
	Scenery.soft_disc(b, mid + Vector2(0.0, s * 0.04), r * 1.3, r * 1.15, Color(Pal.TEXT, 0.18))
	b.disc(mid, r, Pal.TEXT)
	b.fan(Face.Builder.ring(mid + Vector2(-0.3, -0.42) * r, r * 0.34, r * 0.16), Color(1.0, 1.0, 1.0, 0.12))

## The go square about `at`: a square in the card's colour over its own
## shadow, with a chevron the way the head is crawling.
func _go(b: Face.Builder, at: Vector2, c: float) -> void:
	var s := c * GO_SIZE
	var corner := at - Vector2.ONE * (s * 0.5)
	var radius := s * 0.2
	Scenery.soft_disc(b, at + Vector2(0.0, s * 0.42), s * 0.52, s * 0.2, Color(Pal.TEXT, 0.2))
	b.polygon(Face.Builder.round_rect(corner + Vector2(0.0, s * 0.1), Vector2.ONE * s, radius), colour.darkened(0.26))
	b.polygon(Face.Builder.round_rect(corner, Vector2.ONE * s, radius), colour)
	b.polygon(Face.Builder.round_rect(corner + Vector2(s * 0.12, s * 0.07), Vector2(s * 0.5, s * 0.06), s * 0.03),
		Color(Pal.SURFACE, 0.3))
	var mid := at + Vector2(s * 0.02, 0.0)
	var h := s * 0.17
	b.stroke(PackedVector2Array([mid + Vector2(h * 0.55, -h), mid + Vector2(-h * 0.55, 0.0),
		mid + Vector2(h * 0.55, h)]), s * 0.11, Pal.SURFACE)

func _draw() -> void:
	super()
	var font: Font = CozyTheme.display(700)
	var px := int(roundf(_cell() * Board.BADGE_R * Board.NUMBER))
	if px <= 0:
		return
	var rise := font.get_height(px) * 0.5 - font.get_descent(px)
	for n in _nums:
		var wide := font.get_string_size(n[1], HORIZONTAL_ALIGNMENT_LEFT, -1.0, px).x
		draw_string(font, n[0] + Vector2(-wide * 0.5, rise), n[1], HORIZONTAL_ALIGNMENT_LEFT, -1.0, px, Pal.SURFACE)

func _lay() -> void:
	var words := _words(String(entry.get("title", "")), SIDE, size.y * 0.5, WORDS, Pal.TEXT, BLURB)
	words.position.y = roundf(WORDS_TOP * _k())
