extends "res://ui/menu/cards/card_face.gd"

## Cross Stitch's card: a corner of the sampler on warm paper. Eight
## letter patches in their wooden frame at the card's right, four little
## words crossing round a hole with a stitched flower in it, most of them
## stitched green, one on the right thread and one a stray; the go button
## is a round patch in the card's colour with a cream cross stitch on it,
## at the frame's foot on the left.
##
## Everything still is one mesh; the letters are draw_string calls over it.

const Art = preload("res://ui/faces/crossstitch_art.gd")
const CozyTheme = preload("res://ui/theme.gd")

## The row the card was drawn for (puzzle_card_2d.gd's CARD_H).
const H := 246.0
## A patch's side at H, the gap, the grid's middle from the card's right
## and foot.
const TILE := 46.0
const TILE_GAP := 6.0
const RIGHT := 112.0
const FOOT := 116.0
## SEW across the top, NET across the foot, SUN and WIT down the sides.
const LETTERS := "SEWU.INET"
const MARKS := [0, 0, 0, 1, -1, 2, 0, 0, 0]
const PAPER_TOP := Color("fdf5e3")
const PAPER_LOW := Color("f4e4c6")

var _letters: Array = []

func _k() -> float:
	return size.y / H

func _paint(b: Face.Builder) -> void:
	_letters = []
	var k := _k()
	var first := b.verts.size()
	b.polygon(ground(), Color.WHITE)
	shade(b, first, PAPER_TOP, PAPER_LOW, 0.0, size.y)
	var t := TILE * k
	var g := TILE_GAP * k
	var mid := Vector2(size.x - RIGHT * k, size.y - FOOT * k)
	var span := t * 3.0 + g * 2.0
	var linen := Rect2(mid - Vector2.ONE * (span * 0.5 + 10.0 * k), Vector2.ONE * (span + 20.0 * k))
	Art.frame(b, linen, 12.0 * k)
	Art.linen(b, linen, 7.0 * k)
	for i in 9:
		var at := mid + Vector2((i % 3 - 1) * (t + g), (i / 3 - 1) * (t + g))
		if MARKS[i] < 0:
			Art.flower(b, at, t * 0.7)
			continue
		Art.patch(b, at, t, MARKS[i])
		_letters.append([at, LETTERS[i], roundi(t * 0.62), Art.LETTER[MARKS[i]]])
	# the go button: a round patch in the card's colour, a cross stitch on it
	var r := 26.0 * k
	var go := linen.position + Vector2(-r * 2.1, linen.size.y - r * 0.9)
	if soon:
		b.disc(go, r, Art.FACE[2])
	else:
		b.disc(go + Vector2(0.0, r * 0.1), r, colour.darkened(0.25))
		b.disc(go, r, colour)
		var x := r * 0.38
		b.stroke(PackedVector2Array([go + Vector2(-x, -x), go + Vector2(x, x)]), r * 0.2, Pal.SURFACE)
		b.stroke(PackedVector2Array([go + Vector2(x, -x), go + Vector2(-x, x)]), r * 0.2, Pal.SURFACE)

func _draw() -> void:
	super()
	var font: Font = CozyTheme.display(800)
	for n: Array in _letters:
		var fs: int = n[2]
		var tw := font.get_string_size(n[1], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, (n[0] as Vector2) + Vector2(-tw * 0.5, font.get_ascent(fs) * 0.36), n[1],
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, n[3])

func _lay() -> void:
	var words := _words(String(entry.get("title", "")), 22.0, size.y * 0.5, 205.0, Pal.TEXT, Color("7a6650"))
	words.position.y = roundf(14.0 * _k())
