extends "res://ui/menu/cards/card_face.gd"

## Biscuit Tin's card: an open blue tin with a gold rim on a checked cloth,
## six broken pieces in it, two of them laid on a plate above spelling a
## word, one whole biscuit leaning on the tin; the go button is a round
## biscuit in the card's colour on the left.
##
## Everything still is one mesh; the letters are draw_string calls over it.

const Art = preload("res://ui/faces/biscuit_art.gd")
const CozyTheme = preload("res://ui/theme.gd")

## The row the card was drawn for (puzzle_card_2d.gd's CARD_H).
const H := 246.0
## The tin's middle from the card's right and foot, a piece's scale.
const RIGHT := 150.0
const FOOT := 70.0
const PIECE := 0.3
## The pieces in the tin, two rows of three, and on the plate.
const TIN := ["TEA", "CUP", "ER", "BIS", "IT", "SPO"]
const PLATE := ["CUP", "CAKE"]

var _letters: Array = []

func _k() -> float:
	return size.y / H

func _paint(b: Face.Builder) -> void:
	_letters = []
	var k := _k()
	var card := ground()
	b.polygon(card, Art.CLOTH)
	# the cloth's checks, cut to the card's rounded shape
	var band := 34.0 * k
	var x := 0.0
	while x < size.x:
		_check(b, card, PackedVector2Array([Vector2(x, 0), Vector2(x + band, 0), Vector2(x + band, size.y), Vector2(x, size.y)]))
		x += band * 2.0
	var y := 0.0
	while y < size.y:
		_check(b, card, PackedVector2Array([Vector2(0, y), Vector2(size.x, y), Vector2(size.x, y + band), Vector2(0, y + band)]))
		y += band * 2.0
	var mid := Vector2(size.x - RIGHT * k, size.y - FOOT * k)
	var cell := Vector2(Art.PIECE_W[3], Art.PIECE_H) * PIECE * k
	var inner := Rect2(mid - Vector2(cell.x * 1.6, cell.y * 1.1), Vector2(cell.x * 3.2, cell.y * 2.2))
	Art.tin(b, inner, 12.0 * k)
	for i in TIN.size():
		var at := inner.position + Vector2(cell.x * (0.55 + (i % 3) * 1.05), cell.y * (0.55 + (i / 3) * 1.1))
		var sz := Vector2(Art.PIECE_W[clampi(TIN[i].length(), 2, 4)], Art.PIECE_H) * PIECE * k
		var g := Face.Builder.new()
		Art.piece(g, sz, i + 3)
		b.append(g.mesh(), Transform2D(0.0, at))
		_letters.append([at, TIN[i], roundi(sz.y * 0.5), Art.INK])
	# the plate above, two pieces on it spelling a word, lit gold
	var plate := Rect2(mid.x - cell.x * 1.5, inner.position.y - 12.0 * k - cell.y * 1.3, cell.x * 3.0, cell.y * 1.15)
	Art.plate(b, plate)
	var px := plate.get_center().x - cell.x * 0.55
	for i in PLATE.size():
		var sz := Vector2(Art.PIECE_W[clampi(PLATE[i].length(), 2, 4)], Art.PIECE_H) * PIECE * 0.9 * k
		var at := Vector2(px + i * (cell.x * 1.08), plate.get_center().y - 2.0 * k)
		var g := Face.Builder.new()
		Art.piece(g, sz, i + 11, 1.0)
		b.append(g.mesh(), Transform2D(0.0, at))
		_letters.append([at, PLATE[i], roundi(sz.y * 0.5), Art.INK])
	# a whole biscuit leaning by the tin
	Art.whole(b, Vector2(inner.position.x - 26.0 * k, inner.end.y - 4.0 * k), 24.0 * k, 1)
	# the go button: a round biscuit in the card's colour
	var r := 24.0 * k
	var go := Vector2(inner.position.x - 92.0 * k, inner.end.y - r * 0.4)
	if soon:
		b.disc(go, r, Art.CASE_DEEP)
	else:
		b.disc(go + Vector2(0.0, r * 0.12), r, colour.darkened(0.25))
		b.disc(go, r, colour)
		for a in 6:
			var ang := TAU * a / 6.0
			b.disc(go + Vector2(cos(ang), sin(ang)) * r * 0.55, r * 0.09, colour.darkened(0.2))

func _check(b: Face.Builder, card: PackedVector2Array, rect: PackedVector2Array) -> void:
	for part in Geometry2D.intersect_polygons(rect, card):
		b.polygon(part, Color(Art.CLOTH_CHECK, 0.4))

func _draw() -> void:
	super()
	var font: Font = CozyTheme.display(800)
	for n: Array in _letters:
		var fs: int = n[2]
		var tw := font.get_string_size(n[1], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, (n[0] as Vector2) + Vector2(-tw * 0.5, font.get_ascent(fs) * 0.36), n[1],
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, n[3])

func _lay() -> void:
	var words := _words(String(entry.get("title", "")), 22.0, size.y * 0.5, 205.0, Pal.TEXT, Color("5a6f8a"))
	words.position.y = roundf(14.0 * _k())
