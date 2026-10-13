extends "res://ui/menu/cards/card_face.gd"

## Posy's card: one garden bed on a butter-yellow morning, and no grid. A
## single row of five of the game's own pieces lies along the lower right on
## a strip of its bed: a leaf, a mushroom, a drop, and two flowers. One more
## square of bed stands over the drop with the third flower in it, so the
## swap the game asks for is plain: the flower comes down, the drop goes up,
## and three flowers stand in a row. A two-way arc joins the two places. The
## row is checked in code: nothing lines up before the swap and three do
## after it.
##
## The go button is that third flower, in the card's colour, larger, lifted
## over its shadow, a chevron in its heart pointing down into its place.
##
## Everything is one mesh, the pieces arcade/posy_art.gd's own builders, and
## nothing lives on the card.

const Art = preload("res://arcade/posy_art.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

## The row the card was drawn for (puzzle_card_2d.gd's CARD_H), and the
## width its picture was laid for.
const H := 246.0
const W := 490.0
## A square of the bed at H, the step from one to the next, and the room
## from the card's right side and foot to the row.
const CELL := 50.0
const PITCH := 53.0
const RIGHT := 18.0
const FOOT := 16.0
## The bed's rim round its squares, and its corner.
const RIM := 7.0
const ROUND := 15.0
## A piece's size in its square.
const PIECE := 0.84
## The row, by the game's kinds (0 flower, 1 leaf, 2 drop, 3 mushroom), and
## the place whose piece trades with the one above it.
const ROW: Array[int] = [1, 3, 2, 0, 0]
const SWAP := 2
const ABOVE := 0
## How far the drop has started up, the go flower's size in squares, how far
## it is lifted, and its shadow.
const RISE := 5.0
const GO_SIZE := 1.3
const GO_LIFT := 9.0
const GO_SHADOW := 0.2
## The arc beside the two places: how far out it bows and how thick.
const ARC_OUT := 0.72
const ARC_W := 3.4
## The words' margin, their room and how far down they start.
const SIDE := 22.0
const WORDS := 215.0
const WORDS_TOP := 14.0

## The morning, a pale pool behind the bed, and the blurb's ink.
const SKY_TOP := Color("fdf8e0")
const SKY_LOW := Color("f9ecb8")
const POOL := Color("fffbea")
const BLURB := Color("7d6c44")

## The picture's scale: the card's height sets it, its width caps it.
func _k() -> float:
	return minf(size.y / H, size.x / W)

## The middle of the row's square `i`; -1 is the square over the swap.
func _mid(i: int) -> Vector2:
	var k := _k()
	var x := size.x - RIGHT * k - RIM * k - CELL * k * 0.5 - float(ROW.size() - 1 - maxi(i, 0)) * PITCH * k
	var y := size.y - FOOT * k - RIM * k - CELL * k * 0.5
	if i < 0:
		return Vector2(size.x - RIGHT * k - RIM * k - CELL * k * 0.5 - float(ROW.size() - 1 - SWAP) * PITCH * k, y - PITCH * k)
	return Vector2(x, y)

## Whether `row` holds three alike side by side.
static func _lines_up(row: Array[int]) -> bool:
	for i in row.size() - 2:
		if row[i] == row[i + 1] and row[i] == row[i + 2]:
			return true
	return false

## The swap is the game's: nothing lined up before it, three after.
static func _swap_lines_up() -> bool:
	var after: Array[int] = ROW.duplicate()
	after[SWAP] = ABOVE
	return not _lines_up(ROW) and _lines_up(after)

## One of the game's pieces, built about the origin and moved to `at`.
func _piece(b: Face.Builder, kind: int, at: Vector2, s: float) -> void:
	var first := b.verts.size()
	Art._build_tile(b, kind, s)
	for i in range(first, b.verts.size()):
		b.verts[i] += at

func _paint(b: Face.Builder) -> void:
	var k := _k()
	var s := CELL * k
	var first := b.verts.size()
	b.polygon(ground(), Color.WHITE)
	shade(b, first, SKY_TOP, SKY_LOW, 0.0, size.y)
	var left := _mid(0)
	var right := _mid(ROW.size() - 1)
	var up := _mid(-1)
	Scenery.soft_disc(b, (left + right) * 0.5 - Vector2(0.0, s * 0.75), (right.x - left.x) * 0.58, s * 1.15, Color(POOL, 0.6))
	# The bed: the row's strip and the one square over the swap, as one piece.
	var rim := Vector2.ONE * (s * 0.5 + RIM * k)
	Scenery.soft_disc(b, Vector2((left.x + right.x) * 0.5, left.y + rim.y), (right.x - left.x) * 0.56, 7.0 * k,
		Color(Pal.TEXT, 0.14))
	b.polygon(Face.Builder.round_rect(up - rim, rim * 2.0 + Vector2(0.0, PITCH * k), ROUND * k), Art.BOARD.darkened(0.08))
	b.polygon(Face.Builder.round_rect(left - rim + Vector2(0.0, 3.0 * k), Vector2(right.x - left.x, 0.0) + rim * 2.0, ROUND * k),
		Art.BOARD.darkened(0.16))
	b.polygon(Face.Builder.round_rect(left - rim, Vector2(right.x - left.x, 0.0) + rim * 2.0, ROUND * k), Art.BOARD)
	b.polygon(Face.Builder.round_rect(up - rim, rim * 2.0 + Vector2(0.0, PITCH * k * 0.6), ROUND * k), Art.BOARD)
	for i in range(-1, ROW.size()):
		var at := _mid(i)
		b.polygon(Face.Builder.round_rect(at - Vector2.ONE * s * 0.48, Vector2.ONE * s * 0.96, s * 0.18), Art.CELL)
	var ok := _swap_lines_up()
	for i in ROW.size():
		var at := _mid(i)
		if i == SWAP and ok and not soon:
			at.y -= RISE * k
		_piece(b, ROW[i], at, s * PIECE)
	if soon or not ok:
		_piece(b, ABOVE, up, s * PIECE)
		return
	_arc(b, up, _mid(SWAP), s, k)
	_go(b, up - Vector2(0.0, GO_LIFT * k), s * GO_SIZE * 0.5, k)

## The two-way arc right of the two places, an arrowhead at each end.
func _arc(b: Face.Builder, top: Vector2, low: Vector2, s: float, k: float) -> void:
	var ink := Color(Art.WOOD_DEEP, 0.8)
	var a := top + Vector2(s * ARC_OUT, s * 0.12)
	var z := low + Vector2(s * ARC_OUT, -s * 0.12)
	var bow := Vector2(s * 0.3, 0.0)
	var pts := Face.Builder.bezier3(a, a + bow, z + bow, z)
	b.stroke(pts, ARC_W * k, ink)
	var h := s * 0.13
	b.stroke(PackedVector2Array([a + Vector2(h * 1.3, -h * 0.2), a, a + Vector2(h * 0.5, h * 1.2)]), ARC_W * k, ink)
	b.stroke(PackedVector2Array([z + Vector2(h * 1.3, h * 0.2), z, z + Vector2(h * 0.5, -h * 1.2)]), ARC_W * k, ink)

## The go flower about `at`, radius `r`: the game's flower in the card's
## colour, lifted over its shadow, a chevron in its heart pointing down.
func _go(b: Face.Builder, at: Vector2, r: float, k: float) -> void:
	Scenery.soft_disc(b, at + Vector2(0.0, r * 0.9 + GO_LIFT * k), r * 0.8, r * 0.22, Color(Pal.TEXT, GO_SHADOW))
	var deep := colour.darkened(0.26)
	for i in 5:
		var d := Vector2.from_angle(TAU * i / 5.0 - PI * 0.5)
		b.disc(at + d * r * 0.44 + Vector2(r * 0.02, r * 0.07), r * 0.37, deep)
	for i in 5:
		var d := Vector2.from_angle(TAU * i / 5.0 - PI * 0.5)
		b.disc(at + d * r * 0.43, r * 0.33, colour)
		b.ellipse(at + d * r * 0.5 + Vector2(-r * 0.06, -r * 0.07), r * 0.12, r * 0.07, Color(Pal.SURFACE, 0.26))
	b.disc(at + Vector2(r * 0.02, r * 0.03), r * 0.36, deep)
	b.disc(at, r * 0.32, colour.darkened(0.12))
	var h := r * 0.15
	b.stroke(PackedVector2Array([at + Vector2(-h, -h * 0.5), at + Vector2(0.0, h * 0.6), at + Vector2(h, -h * 0.5)]),
		r * 0.11, Pal.SURFACE)

func _lay() -> void:
	var words := _words(String(entry.get("title", "")), SIDE, size.y * 0.5, WORDS, Pal.TEXT, BLURB)
	words.position.y = roundf(WORDS_TOP * size.y / H)
