extends "res://ui/menu/cards/card_face.gd"

## Honeycomb's card: a corner of the comb on warm paper. Seven wax cells at
## the card's right, the queen's in honey, the queen bee on it, letters on
## the cells; the go button is a round key in the card's colour, its tick
## cream, at the comb's foot on the left.
##
## Everything still is one mesh; the letters are draw_string calls over it.

const Art = preload("res://ui/faces/honeycomb_art.gd")
const CozyTheme = preload("res://ui/theme.gd")

## The row the card was drawn for (puzzle_card_2d.gd's CARD_H).
const H := 246.0
## A cell's radius at H, the comb's middle from the card's right and foot.
const CELL := 40.0
const RIGHT := 150.0
const FOOT := 112.0
const LETTERS := "ADEGNR"
const QUEEN := "L"
const PAPER_TOP := Color("fdf5e3")
const PAPER_LOW := Color("f6e5c4")

var _letters: Array = []

func _k() -> float:
	return size.y / H

func _paint(b: Face.Builder) -> void:
	_letters = []
	var k := _k()
	var first := b.verts.size()
	b.polygon(ground(), Color.WHITE)
	shade(b, first, PAPER_TOP, PAPER_LOW, 0.0, size.y)
	var r := CELL * k
	var mid := Vector2(size.x - RIGHT * k, size.y - FOOT * k)
	for i in 7:
		var at := mid + Art.cell_offset(i, r, 4.0 * k)
		Art.cell(b, at, r, i == 0)
		_letters.append([at, QUEEN if i == 0 else LETTERS[i - 1], roundi(r * 0.78)])
	Art.bee(b, mid + Vector2(r * 0.5, -r * 0.7), r * 0.62, 0.0)
	# the go key, in the card's colour
	var kr := 26.0 * k
	var go := mid + Vector2(-r * 3.2, r * 1.6)
	if soon:
		Art.key(b, go, kr, Art.Key.ENTER, false)
	else:
		b.disc(go + Vector2(0.0, kr * 0.1), kr, colour.darkened(0.25))
		b.disc(go, kr, colour)
		Art.mark(b, go, kr * 0.46, Art.Key.ENTER, Pal.SURFACE)

func _draw() -> void:
	super()
	var font: Font = CozyTheme.display(800)
	for n: Array in _letters:
		var fs: int = n[2]
		var tw := font.get_string_size(n[1], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, (n[0] as Vector2) + Vector2(-tw * 0.5, font.get_ascent(fs) * 0.36), n[1],
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Art.INK)

func _lay() -> void:
	var words := _words(String(entry.get("title", "")), 22.0, size.y * 0.5, 215.0, Pal.TEXT, Color("7a6650"))
	words.position.y = roundf(14.0 * _k())
