extends "res://ui/menu/cards/card_face.gd"

## Market Sums' card: a corner of the stall on warm paper. A shelf along the
## card's foot on the right holds three crates, 5, 8 and the 40 their
## product makes, its label leaf for an order filled; the chalk order board
## hangs over them reading 40. The go button is a sign token in the card's
## colour, its times mark cream, at the shelf's front.
##
## Everything still is one mesh; the numbers are draw_string calls over it.

const Art = preload("res://ui/faces/market_art.gd")
const Gen = preload("res://puzzles/market_gen.gd")
const CozyTheme = preload("res://ui/theme.gd")

## The row the card was drawn for (puzzle_card_2d.gd's CARD_H).
const H := 246.0
## A crate's width at H, the crates' room from the card's right side and
## foot, and the column the words keep.
const CRATE := 74.0
const RIGHT := 64.0
const FOOT := 40.0
## The crates: [in from the right, number, filled].
const CRATES := [[180.0, 5, false], [95.0, 8, false], [10.0, 40, true]]
const ORDER := 40
const PAPER_TOP := Color("fdf5e8")
const PAPER_LOW := Color("f4e2cc")
const BLURB := Color("7a6650")

var _numbers: Array = []

func _k() -> float:
	return size.y / H

func _paint(b: Face.Builder) -> void:
	_numbers = []
	var k := _k()
	var first := b.verts.size()
	b.polygon(ground(), Color.WHITE)
	shade(b, first, PAPER_TOP, PAPER_LOW, 0.0, size.y)
	var cw := CRATE * k
	var shelf_y := size.y - FOOT * k
	var x0 := size.x - (RIGHT + 260.0) * k
	# the shelf
	b.fan(Face.Builder.round_rect(Vector2(x0, shelf_y), Vector2(size.x - x0 - 14.0 * k, 12.0 * k), 4.0 * k), Art.CRATE_DEEP)
	b.fan(Face.Builder.round_rect(Vector2(x0, shelf_y), Vector2(size.x - x0 - 14.0 * k, 8.0 * k), 4.0 * k), Art.CRATE)
	for spec: Array in CRATES:
		var at := Vector2(size.x - (RIGHT + float(spec[0])) * k - cw * 0.5, shelf_y - cw * Art.H * 0.5)
		Art.crate(b, at, cw, bool(spec[2]))
		_numbers.append([at + Art.label_centre(cw), str(spec[1]), roundi(cw * 0.3), Pal.TEXT])
	# the order board over them
	var bs := Vector2(150.0, 78.0) * k
	var bc := Vector2(size.x - (RIGHT + 95.0) * k - cw * 0.5, shelf_y - cw * Art.H - 70.0 * k)
	Art.board(b, bc, bs, bc.y - bs.y * 0.5 - 22.0 * k, k * 0.45)
	_numbers.append([bc + Vector2(0.0, 2.0 * k), str(ORDER), roundi(40.0 * k), Art.CHALK_INK])
	# the go token, in the card's colour
	var tr_ := 26.0 * k
	var go := Vector2(size.x - (RIGHT + 262.0) * k, shelf_y - tr_ - 4.0 * k)
	if soon:
		Art.token(b, go, tr_, Gen.Op.MUL, false)
	else:
		b.disc(go + Vector2(0.0, tr_ * 0.1), tr_, colour.darkened(0.25))
		b.disc(go, tr_, colour)
		Art.mark(b, go, tr_ * 0.5, Gen.Op.MUL, Art.LABEL)

func _draw() -> void:
	super()
	var font: Font = CozyTheme.display(800)
	for n: Array in _numbers:
		var fs: int = n[2]
		var tw := font.get_string_size(n[1], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, (n[0] as Vector2) + Vector2(-tw * 0.5, font.get_ascent(fs) * 0.36), n[1],
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, n[3])

func _lay() -> void:
	var words := _words(String(entry.get("title", "")), 22.0, size.y * 0.5, 215.0, Pal.TEXT, BLURB)
	words.position.y = roundf(14.0 * _k())
