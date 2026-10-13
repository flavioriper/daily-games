extends "res://ui/menu/cards/card_face.gd"

## Rings' card: three of the board's pegs on a wooden base against a blush
## plaster wall. The base comes in along the card's foot from the right edge
## and ends rounded a little past the middle. The left peg, under the words,
## is the low one: two rings of one colour, the rest of that colour on pegs
## past the card's edge. The middle peg holds three rings in the card's
## colour and wants one more -- the go button, which is that ring in the
## hand, larger, lifted clear of the post over its own soft shadow, a
## chevron where the others wear their emblem. The right peg is home: four
## rings of a third colour under the board's daisy cap, which stops short
## of the seal's corner. A ring drops onto its own
## colour on a peg with room (rings_state.gd's can_drop), so the picture is
## a position the board could stand in and the go ring's drop a legal move.
##
## Each peg is told by its colour and its emblem, never by a shade; the full
## one is told by its cap. Everything is one mesh and nothing lives on it.

const Board = preload("res://puzzles/rings2d.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

## The row the card was drawn for (puzzle_card_2d.gd's CARD_H).
const H := 246.0
## A ring's width at H, the pegs' pitch, and how far in from the card's
## right side the last peg stands.
const RING := 64.0
const PITCH := 76.0
const LAST_IN := 56.0
## How far up from the card's foot the rings' ground line is.
const GROUND_UP := 38.0
## The base: how far past the first peg's ring it runs, its top face behind
## and in front of the ground line, its front board, and its corner.
const BASE_PAST := 24.0
const BASE_BACK := 15.0
const BASE_LIP := 7.0
const BASE_FRONT := 17.0
const BASE_ROUND := 11.0
## The go ring: how much larger than its siblings, and how far over the
## post top its foot hovers, in its own widths.
const GO_SIZE := 1.25
const GO_HOVER := 0.12
## The words' margin and how far down they start; the first peg's post
## never comes nearer the card's left side than POST_MIN, which is where
## the longest blurb line ends.
const SIDE := 22.0
const WORDS_TOP := 14.0
const POST_MIN := 276.0

## The pegs left to right as [ring colour index in Board.RING_COLOURS, how
## many it holds]. The middle one's colour is the card's own.
const HOME := 5
const MINE := 4
const OTHER := 1
const PEGS := [[OTHER, 2], [MINE, 3], [HOME, 4]]

## The wall, top to foot, the light on it behind the pegs, and the blurb.
const WALL_TOP := Color("fbeeec")
const WALL_LOW := Color("f2d5d6")
const LIGHT := Color("fff8f3")
const BLURB := Color("86686a")

func _k() -> float:
	return size.y / H

## The picture's own scale: the card's, unless the words want the room.
func _ks() -> float:
	var span := LAST_IN + float(PEGS.size() - 1) * PITCH
	return minf(_k(), (size.x - POST_MIN) / span)

func _ground_y() -> float:
	return size.y - GROUND_UP * _ks()

func _peg_x(i: int) -> float:
	return size.x - (LAST_IN + float(PEGS.size() - 1 - i) * PITCH) * _ks()

func _ink(index: int) -> Color:
	return colour if index == MINE else Board.RING_COLOURS[index]

## `pts` in `col`, as much of it as lies on the paper.
func _on_paper(b: Face.Builder, paper: PackedVector2Array, pts: PackedVector2Array, col: Color) -> void:
	for part in Geometry2D.intersect_polygons(paper, pts):
		b.polygon(part, col)

func _paint(b: Face.Builder) -> void:
	var s := _ks()
	var w := RING * s
	var g := _ground_y()
	var paper := ground()
	var first := b.verts.size()
	b.polygon(paper, Color.WHITE)
	shade(b, first, WALL_TOP, WALL_LOW, 0.0, size.y)
	# The light on the plaster behind the pegs.
	var mid_x := _peg_x(1)
	_on_paper(b, paper, Face.Builder.ring(Vector2(mid_x, g - 70.0 * s), 150.0 * s, 96.0 * s), Color(LIGHT, 0.34))
	_on_paper(b, paper, Face.Builder.ring(Vector2(mid_x, g - 70.0 * s), 104.0 * s, 68.0 * s), Color(LIGHT, 0.34))
	_base(b, paper, _peg_x(0) - w * 0.5 - BASE_PAST * s, g, s)
	for i in PEGS.size():
		var peg: Array = PEGS[i]
		_peg(b, _peg_x(i), g, w, int(peg[0]), int(peg[1]))
	if not soon:
		_go(b, mid_x, g, w)

## The base from `x` off the card's right side: its shadow on the wall's
## foot, the front board, the lit top the pegs stand in.
func _base(b: Face.Builder, paper: PackedVector2Array, x: float, g: float, s: float) -> void:
	var y0 := g - BASE_BACK * s
	var y1 := g + BASE_LIP * s
	var y2 := y1 + BASE_FRONT * s
	var wide := size.x - x + 40.0 * s
	var r := BASE_ROUND * s
	var front: Color = Pal.PLAQUE.lerp(Pal.WOOD, 0.3)
	var top: Color = Pal.WOOD.lerp(Pal.SCALE_WOOD, 0.4)
	_on_paper(b, paper, Face.Builder.round_rect(Vector2(x + 6.0 * s, y2 - 10.0 * s), Vector2(wide, 17.0 * s), 9.0 * s),
		Color(Pal.TEXT, 0.09))
	_on_paper(b, paper, Face.Builder.round_rect(Vector2(x, y0), Vector2(wide, y2 - y0), r),
		Pal.PLAQUE_DEEP.lerp(front, 0.45))
	_on_paper(b, paper, Face.Builder.round_rect(Vector2(x, y0), Vector2(wide, y2 - y0 - 3.0 * s), r), front)
	_on_paper(b, paper, Face.Builder.round_rect(Vector2(x, y0), Vector2(wide, y1 - y0 + r * 0.5), r), top)
	# The lit back edge, and one line of grain.
	var end := size.x - EDGE - 2.0
	b.stroke(PackedVector2Array([Vector2(x + r, y0 + 2.5 * s), Vector2(end, y0 + 2.5 * s)]), 2.2 * s,
		Color(top.lerp(Color.WHITE, 0.4), 0.8))
	b.stroke(PackedVector2Array([Vector2(x + r * 1.6, y1 + r * 0.5 + BASE_FRONT * s * 0.4),
		Vector2(x + r * 1.6 + 46.0 * s, y1 + r * 0.5 + BASE_FRONT * s * 0.4)]), 1.3 * s, Color(Pal.PLAQUE_DEEP, 0.28))

## One peg as Board._append_peg stands it -- the stack's shadow, the rings
## bottom-up, the dowel into the top one, the daisy on a full peg -- with
## the card's colour standing in for the board's on MINE.
func _peg(b: Face.Builder, cx: float, g: float, w: float, index: int, count: int) -> void:
	var none := Callable()
	var foot := g - Board.SEAT * w
	b.fan(Face.Builder.ring(Vector2(cx + 0.07 * w, foot + Board.FACE * w * 0.75), 0.55 * w, Board.FACE * w * 0.85),
		Color(Pal.TEXT, 0.16))
	var into := foot
	for k in count:
		into = Board._ring_yt(g, w, k)
		Board._append_donut(b, cx, into, w, _ink(index), index, 1.0, none)
	var top_y := Board._post_top(g, w)
	Board._append_post(b, cx, top_y, into, w, 1.0, none)
	if count >= Board.Gen.CAP:
		Board._append_daisy(b, Vector2(cx, top_y + Board.POST * w * 0.2), Board.CAP_R * w, none)

## The go ring over the middle peg: its shadow on the ring it will land on,
## then the board's ring in the card's colour, a chevron for its emblem.
func _go(b: Face.Builder, cx: float, g: float, w: float) -> void:
	var none := Callable()
	var top_ring := Board._ring_yt(g, w, int(PEGS[1][1]) - 1)
	Scenery.soft_disc(b, Vector2(cx + 0.03 * w, top_ring + Board.FACE * w * 0.1), w * 0.5, Board.FACE * w * 1.05,
		Color(Pal.TEXT, 0.2))
	var gw := w * GO_SIZE
	var yt := Board._post_top(g, w) - (Board.SIDE + Board.FACE + GO_HOVER) * gw
	Board._donut_body(b, cx, yt, gw, colour, 1.0, none)
	Board._donut_face(b, cx, yt, gw, colour, 1.0, none)
	var at := Vector2(cx + gw * 0.01, yt + Board.FACE * gw + Board.SIDE * gw * 0.47)
	var h := gw * 0.085
	b.stroke(PackedVector2Array([at + Vector2(-h * 0.55, -h), at + Vector2(h * 0.55, 0.0), at + Vector2(-h * 0.55, h)]),
		gw * 0.058, Pal.SURFACE)

func _lay() -> void:
	var room := size.x - SIDE - (SEAL_IN + SEAL_R + 10.0)
	var words := _words(String(entry.get("title", "")), SIDE, size.y * 0.5, room, Pal.TEXT, BLURB)
	words.position.y = roundf(WORDS_TOP * _k())
