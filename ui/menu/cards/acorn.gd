extends "res://ui/menu/cards/card_face.gd"

## Golden Acorn's card: the prize and the four plates, on a golden autumn
## parchment. The board's four answer plates stand stacked against the
## card's right side, lettered A to D on their discs as the board letters
## them, each with two blank lines where an answer would be written -- the
## question is new every day, so the card writes none. Left of the stack the
## golden acorn stands in a soft glow with three motes: on this board it is
## a prize and a mark, not a character (ui/faces/acorn_art.gd), so it is
## baked and nothing lives on the card. Two fallen leaves lie in the bottom
## left corner.
##
## The go button is the answer picked: plate C in the card's colour, wider
## and taller than its siblings, lifted over a shadow, with a chevron at its
## far end. The name stands top left.
##
## Everything still is one mesh; the four letters are `draw_string`s over
## it, as the board writes them.

const Art = preload("res://ui/faces/acorn_art.gd")
const LeafPile = preload("res://ui/faces/leaf_pile.gd")
const Scenery = preload("res://ui/flat/scenery.gd")
const CozyTheme = preload("res://ui/theme.gd")

## The row the card was drawn for (puzzle_card_2d.gd's CARD_H).
const H := 246.0
## A plate at H, the gap between two, and the stack's room from the card's
## right side and foot.
const PLATE := Vector2(158.0, 33.0)
const GAP := 7.0
const RIGHT := 16.0
const FOOT := 13.0
## A plate's corner, its lip, its rim and its letter's disc as a share of
## its height (the board's LETTER_R), and how far in the disc starts.
const ROUND := 13.0
const LIP := 4.0
const RIM := 2.0
const LETTER_R := 0.3
const LETTER_IN := 11.0
const LETTER_FONT := 0.5
const LETTERS := ["A", "B", "C", "D"]
## The blank lines on a plate: [share of the room, how far down in plates].
const LINES := [[0.78, -0.14], [0.5, 0.16]]
const LINE_W := 4.0
## The go plate: which one, how much larger, how far it is lifted and slid
## out of the stack, and its shadow.
const GO := 2
const GO_SIZE := 1.12
const GO_LIFT := 3.0
const GO_OUT := 7.0
const GO_SHADOW := 0.22
## The acorn: its radius at H, how far left of the stack its middle stands,
## how far over the foot its tip is, and its glow.
const NUT := 37.0
const NUT_GAP := 48.0
const NUT_FOOT := 20.0
const GLOW := Vector2(74.0, 50.0)
const MOTES := [[Vector2(-44.0, -30.0), 3.2], [Vector2(40.0, -42.0), 2.4], [Vector2(-34.0, 22.0), 2.2]]
## The fallen leaves, as [x and y from the bottom left corner at H, length,
## angle, kind, colour].
const LITTER := [
	[Vector2(48.0, 34.0), 42.0, -0.45, LeafPile.Kind.OAK, Color("e2a650")],
	[Vector2(98.0, 20.0), 28.0, 0.5, LeafPile.Kind.MAPLE, Color("dd8a55")],
]
## The words' margin, their room and how far down they start.
const SIDE := 22.0
const WORDS := 215.0
const WORDS_TOP := 14.0

## The parchment, the glow's gold, and the blurb's ink.
const PAPER_TOP := Color("fdf5dc")
const PAPER_LOW := Color("f8e6b4")
const GLOW_INK := Color("fff8dc")
const BLURB := Color("7d6a45")

func _k() -> float:
	return size.y / H

## Plate `i`'s box, top to bottom.
func _plate(i: int) -> Rect2:
	var k := _k()
	var sz := PLATE * k
	var top := size.y - FOOT * k - 4.0 * sz.y - 3.0 * GAP * k
	return Rect2(size.x - RIGHT * k - sz.x, top + float(i) * (sz.y + GAP * k), sz.x, sz.y)

## The go plate's box: larger about its right end, slid left and lifted.
func _go_box() -> Rect2:
	var k := _k()
	var box := _plate(GO)
	var sz := box.size * GO_SIZE
	return Rect2(box.end.x - sz.x - GO_OUT * k, box.get_center().y - sz.y * 0.5 - GO_LIFT * k, sz.x, sz.y)

func _is_go(i: int) -> bool:
	return i == GO and not soon

func _box(i: int) -> Rect2:
	return _go_box() if _is_go(i) else _plate(i)

## Where plate `i`'s letter disc has its middle, and its radius.
func _disc(i: int) -> Array:
	var box := _box(i)
	var r := box.size.y * LETTER_R
	var into := LETTER_IN * _k() * (GO_SIZE if _is_go(i) else 1.0)
	return [Vector2(box.position.x + into + r, box.get_center().y), r]

func _nut() -> Vector2:
	var k := _k()
	return Vector2(_plate(0).position.x - NUT_GAP * k, size.y - (NUT_FOOT + NUT * 1.06) * k)

func _paint(b: Face.Builder) -> void:
	var k := _k()
	var first := b.verts.size()
	b.polygon(ground(), Color.WHITE)
	shade(b, first, PAPER_TOP, PAPER_LOW, 0.0, size.y)
	for l: Array in LITTER:
		var at: Vector2 = l[0]
		LeafPile.leaf(b, Vector2(at.x * k, size.y - at.y * k), float(l[1]) * k, float(l[2]), l[4], int(l[3]))
	# The prize in its glow.
	var nut := _nut()
	Scenery.soft_disc(b, nut + Vector2(0.0, -4.0) * k, GLOW.x * k, GLOW.y * k, Color(GLOW_INK, 0.85))
	b.ellipse(nut + Vector2(0.0, NUT * 1.08 * k), NUT * 0.7 * k, NUT * 0.13 * k, Color(Pal.TEXT, 0.12))
	Art.acorn(b, nut, NUT * k, true)
	for m: Array in MOTES:
		b.disc(nut + (m[0] as Vector2) * k, float(m[1]) * k, Color(Pal.SUN, 0.5))
	# The plain plates, then the go plate over them.
	for i in 4:
		if not _is_go(i):
			_plain(b, i, k)
	if not soon:
		_go(b, k)

## A plate as the board draws one at rest: lip, rim, face, the letter's
## disc and two blank lines.
func _plain(b: Face.Builder, i: int, k: float) -> void:
	var box := _plate(i)
	var round := ROUND * k
	b.fan(Face.Builder.round_rect(box.position + Vector2(0.0, LIP * k), box.size, round), Color(Pal.LINE, 0.8))
	b.fan(Face.Builder.round_rect(box.position, box.size, round), Pal.LINE)
	b.fan(Face.Builder.round_rect(box.position + Vector2.ONE * RIM * k, box.size - Vector2.ONE * RIM * k * 2.0,
		round - RIM * k), Pal.SURFACE)
	var d := _disc(i)
	b.disc(d[0], d[1], Pal.ACORN_TILE)
	_lines(b, box, d, k, Color(Pal.LINE, 0.5), 1.0)

## The blank lines right of a plate's disc, `room` of the way to its end.
func _lines(b: Face.Builder, box: Rect2, d: Array, k: float, ink: Color, room: float) -> void:
	var from: float = (d[0] as Vector2).x + float(d[1]) + 10.0 * k
	var wide := (box.end.x - 14.0 * k - from) * room
	for l: Array in LINES:
		var y := box.get_center().y + float(l[1]) * box.size.y
		b.stroke(PackedVector2Array([Vector2(from, y), Vector2(from + wide * float(l[0]), y)]), LINE_W * k, ink)

## The go plate: the answer picked, in the card's colour, lifted over its
## own shadow, a chevron at its far end.
func _go(b: Face.Builder, k: float) -> void:
	var box := _go_box()
	var round := ROUND * k * GO_SIZE
	Scenery.soft_disc(b, Vector2(box.get_center().x, box.end.y + (LIP + GO_LIFT) * k), box.size.x * 0.5,
		box.size.y * 0.3, Color(Pal.TEXT, GO_SHADOW))
	b.fan(Face.Builder.round_rect(box.position + Vector2(0.0, LIP * 1.3 * k), box.size, round), colour.darkened(0.26))
	b.fan(Face.Builder.round_rect(box.position, box.size, round), colour)
	b.fan(Face.Builder.round_rect(box.position + Vector2(box.size.y * 0.16, box.size.y * 0.1),
		Vector2(box.size.x - box.size.y * 0.32, box.size.y * 0.32), box.size.y * 0.16), Color(Pal.SURFACE, 0.16))
	var d := _disc(GO)
	b.disc(d[0], d[1], colour.darkened(0.26))
	_lines(b, box, d, k, Color(Pal.SURFACE, 0.45), 0.72)
	var h := box.size.y * 0.2
	var at := Vector2(box.end.x - box.size.y * 0.55, box.get_center().y)
	b.stroke(PackedVector2Array([at + Vector2(-h * 0.55, -h), at + Vector2(h * 0.55, 0.0), at + Vector2(-h * 0.55, h)]),
		box.size.y * 0.13, Pal.SURFACE)

func _draw() -> void:
	super()
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var font: Font = CozyTheme.display(700)
	for i in 4:
		var d := _disc(i)
		var px := int(roundf(_box(i).size.y * LETTER_FONT))
		if px <= 0:
			continue
		var at: Vector2 = d[0]
		var wide := font.get_string_size(LETTERS[i], HORIZONTAL_ALIGNMENT_LEFT, -1.0, px).x
		var rise := (font.get_ascent(px) - font.get_descent(px)) * 0.5
		draw_string(font, at + Vector2(-wide * 0.5, rise), LETTERS[i], HORIZONTAL_ALIGNMENT_LEFT, -1.0, px,
			Pal.SURFACE if _is_go(i) else Pal.TEXT)

func _lay() -> void:
	var words := _words(String(entry.get("title", "")), SIDE, size.y * 0.5, WORDS, Pal.TEXT, BLURB)
	words.position.y = roundf(WORDS_TOP * _k())
