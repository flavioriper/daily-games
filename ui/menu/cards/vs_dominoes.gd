extends "res://ui/menu/cards/card_face.gd"

## Dominoes' card: a pale blush table cloth with one stitched hem, and a
## short line of the house set laid as the game lays it. A double three
## stands crosswise at the right, a three-six runs left from it, and a
## six-two turns the corner and climbs, every joint matching; on a wider
## card a five-three leads the line in from the right. The line's open end
## is the two, ringed softly.
##
## The go button is the tile that answers it: a two-four in the card's
## colour with cream pips, larger, lifted over its shadow and leaning, its
## two over the open end and a chevron at its middle pointing down at the
## joint. The name stands top left.
##
## Everything is one mesh; the tiles are versus/dominoes_board.gd's own
## ivory, brass and pips, redrawn here under a transform (the board builds
## each as a mesh of its own). Nothing lives on the card.

const Board = preload("res://versus/dominoes_board.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

## The row the card was drawn for (puzzle_card_2d.gd's CARD_H).
const H := 246.0
## A tile's short side at H (the board's is 100), so a tile is 84 by 42.
const UNIT := 42.0
## The line's middle above the card's foot, and the room right of it, at H.
const LINE := 56.0
const RIGHT := 24.0
## A card this wide or wider leads the line in with one more tile.
const LEAD_FROM := 580.0
## The words end here: the picture's scale never brings it left of it.
const WORDS_END := 250.0
## How wide the picture is at H, from its left edge to the card's right.
const REACH := 214.0
## The go tile: its size beside its siblings, where its middle stands from
## the open end's (in tile units), its lean in radians, and its shadow.
const GO_SIZE := 1.16
const GO_AT := Vector2(0.55, -1.42)
const GO_LEAN := 0.14
const GO_SHADOW := 0.24
## The words' margin, their room and how far down they start.
const SIDE := 22.0
const WORDS := 215.0
const WORDS_TOP := 14.0

## The cloth, its hem and the blurb's ink.
const CLOTH_TOP := Color("fcefee")
const CLOTH_LOW := Color("f5dcdc")
const HEM := Color("e3b9bb")
const POOL := Color("fff8f6")
const BLURB := Color("86636a")

func _k() -> float:
	return minf(size.y / H, (size.x - WORDS_END) / REACH)

func _paint(b: Face.Builder) -> void:
	var k := _k()
	var u := UNIT * k
	var first := b.verts.size()
	b.polygon(ground(), Color.WHITE)
	shade(b, first, CLOTH_TOP, CLOTH_LOW, 0.0, size.y)
	_hem(b, k)
	# The line, from the right: each tile [middle, upright, first, second].
	var y := size.y - LINE * k
	var x := size.x - RIGHT * k
	var lead := size.x >= LEAD_FROM
	Scenery.soft_disc(b, Vector2(x - u * 3.0, y - u * 0.6), u * 2.6, u * 1.7, Color(POOL, 0.55))
	if lead:
		_tile(b, Transform2D(0.0, Vector2(x - u, y)), u, 3, 5, false)
		x -= u * 2.0
	_tile(b, Transform2D(PI * 0.5, Vector2(x - u * 0.5, y)), u, 3, 3, false)
	x -= u
	_tile(b, Transform2D(0.0, Vector2(x - u, y)), u, 6, 3, false)
	x -= u * 2.0
	# The corner: the six below, against the line; the two above, open.
	var turn := Vector2(x - u * 0.5, y - u * 0.5)
	_tile(b, Transform2D(PI * 0.5, turn), u, 2, 6, false)
	var open := turn - Vector2(0.0, u * 0.5)
	if soon:
		return
	Scenery.soft_disc(b, open, u * 0.78, u * 0.78, Color(Pal.SUN, 0.5))
	b.stroke(Face.Builder.round_rect(open - Vector2.ONE * u * 0.56, Vector2.ONE * u * 1.12, u * 0.2), u * 0.07,
		Color(Pal.SUN, 0.95), true)
	var s := u * GO_SIZE
	var at := open + GO_AT * u
	Scenery.soft_disc(b, at + Vector2(0.0, s * 0.62), s * 1.05, s * 0.3, Color(Pal.TEXT, GO_SHADOW))
	var xf := Transform2D(GO_LEAN, at)
	_tile(b, xf, s, 2, 4, true)
	# The chevron where the pin would be, pointing down at the joint.
	var h := s * 0.2
	b.stroke(xf * PackedVector2Array([Vector2(-h, -h * 0.55), Vector2(0.0, h * 0.55), Vector2(h, -h * 0.55)]),
		s * 0.13, Pal.SURFACE)

## One line of running stitch along the cloth's foot, short of the picture.
func _hem(b: Face.Builder, k: float) -> void:
	var y := size.y - 14.0 * k
	var x := SIDE + 4.0
	var until := size.x - (REACH + 30.0) * k
	while x + 14.0 * k < until:
		b.stroke(PackedVector2Array([Vector2(x, y), Vector2(x + 14.0 * k, y)]), 2.6 * k, Color(HEM, 0.8))
		x += 24.0 * k

## One tile under `xf`, lying along its x: `u` is its short side, `a` the
## number of its first half and `z` of its second. The board's ivory, its
## brass rim on a double, its pin and its pips; `go` paints it in the card's
## colour with cream pips and leaves the pin to the chevron.
func _tile(b: Face.Builder, xf: Transform2D, u: float, a: int, z: int, go: bool) -> void:
	var s := u / Board.H
	var body := Vector2(2.0 * u, u) - Vector2(8.0, 8.0) * s
	var shape := xf * Face.Builder.round_rect(-body * 0.5, body, 16.0 * s)
	if not go:
		b.fan(_moved(shape, Vector2(1.0, 9.0) * s), Color(0.1, 0.06, 0.02, 0.22))
	b.fan(_moved(shape, Vector2(0.0, 5.0) * s), colour.darkened(0.28) if go else Board.IVORY_EDGE)
	b.fan(shape, colour if go else Board.IVORY)
	var rim: Color = Color(colour.lightened(0.35), 0.9) if go else (Color(Board.BRASS, 0.95) if a == z else Color(Board.IVORY_LIT, 0.9))
	b.stroke(xf * Face.Builder.round_rect(-body * 0.5 + Vector2(5.0, 5.0) * s, body - Vector2(10.0, 10.0) * s, 12.0 * s),
		3.0 * s, rim, true)
	if not go:
		b.stroke(xf * PackedVector2Array([Vector2(0.0, -30.0) * s, Vector2(0.0, 30.0) * s]), 4.0 * s, Color(Board.INK, 0.75))
		b.disc(xf * Vector2.ZERO + Vector2(0.0, 1.0) * s, 8.0 * s, Board.BRASS.darkened(0.25))
		b.disc(xf * Vector2.ZERO, 7.0 * s, Board.BRASS)
	_pips(b, xf, Vector2(-u * 0.5, 0.0), a, s, go)
	_pips(b, xf, Vector2(u * 0.5, 0.0), z, s, go)

## A half's pips about `c` in the tile's own space: the die's patterns as
## the board lays them, the six in two lines along the tile.
func _pips(b: Face.Builder, xf: Transform2D, c: Vector2, n: int, s: float, go: bool) -> void:
	var g := 25.0 * s
	var spots: Array[Vector2] = []
	if n % 2 == 1:
		spots.append(Vector2.ZERO)
	if n >= 2:
		spots.append(Vector2(-g, -g))
		spots.append(Vector2(g, g))
	if n >= 4:
		spots.append(Vector2(g, -g))
		spots.append(Vector2(-g, g))
	if n == 6:
		spots.append(Vector2(-g, 0.0))
		spots.append(Vector2(g, 0.0))
	for p: Vector2 in spots:
		var at := xf * (c + Vector2(p.y, -p.x))
		if go:
			b.disc(at + Vector2(0.0, 1.5) * s, 10.0 * s, colour.darkened(0.25))
			b.disc(at, 9.5 * s, Pal.SURFACE)
		else:
			b.disc(at + Vector2(0.0, 1.5) * s, 10.0 * s, Color(1, 1, 1, 0.6))
			b.disc(at, 9.5 * s, Board.PIPS[n])
			b.disc(at + Vector2(-3.0, -3.0) * s, 2.6 * s, Color(1, 1, 1, 0.32))

static func _moved(pts: PackedVector2Array, by: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(p + by)
	return out

func _lay() -> void:
	var words := _words(String(entry.get("title", "")), SIDE, size.y * 0.5, WORDS, Pal.TEXT, BLURB)
	words.position.y = roundf(WORDS_TOP * size.y / H)
