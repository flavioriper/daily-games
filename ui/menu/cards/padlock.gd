extends "res://ui/menu/cards/card_face.gd"

## Padlock's card: a brass combination padlock on a pale shed door. Four
## letter dials in its face, the window across them reading LOCK, three of
## its letters lit gold, the steel shackle over it; the go button is a round
## brass key bow in the card's colour at the lock's foot on the left.
##
## Everything still is one mesh; the letters are draw_string calls over it.

const Art = preload("res://ui/faces/padlock_art.gd")
const CozyTheme = preload("res://ui/theme.gd")

## The row the card was drawn for (puzzle_card_2d.gd's CARD_H).
const H := 246.0
## A dial's width and cell at H, the lock's middle from the card's right
## and foot.
const DIAL := 34.0
const CELL := 28.0
const RIGHT := 128.0
const FOOT := 96.0
## Each dial's letters top to bottom; the middle row is the window.
const DIALS := ["SLR", "IOA", "NCM", "TKE"]

var _letters: Array = []

func _k() -> float:
	return size.y / H

func _paint(b: Face.Builder) -> void:
	_letters = []
	var k := _k()
	var first := b.verts.size()
	b.polygon(ground(), Color.WHITE)
	shade(b, first, Art.DOOR, Art.DOOR_LOW, 0.0, size.y)
	for x in range(0, int(size.x), int(64.0 * k)):
		b.polygon(PackedVector2Array([Vector2(x, 0), Vector2(x + 3.0 * k, 0), Vector2(x + 3.0 * k, size.y), Vector2(x, size.y)]), Color(Art.DOOR_GAP, 0.6))
	var d := DIAL * k
	var c := CELL * k
	var mid := Vector2(size.x - RIGHT * k, size.y - FOOT * k)
	var body := Rect2(mid - Vector2(d * 2.0 + 12.0 * k, c * 1.5 + 10.0 * k), Vector2(d * 4.0 + 24.0 * k, c * 3.0 + 20.0 * k))
	Art.shackle(b, mid.x, body.position.y, body.size.x * 0.62, 70.0 * k, 11.0 * k, 0.0)
	Art.body(b, body)
	for i in 4:
		var x := mid.x + (i - 1.5) * d
		Art.slot(b, Rect2(x - d * 0.44, mid.y - c * 1.5, d * 0.88, c * 3.0))
		for j in 3:
			var at := Vector2(x, mid.y + (j - 1) * c)
			var lit := j == 1 and i != 2
			Art.cell(b, at, Vector2(d * 0.76, c * 0.88), lit)
			_letters.append([at, DIALS[i][j], roundi(c * 0.6), Art.GOLD_INK if lit else Color(Art.INK, 1.0 if j == 1 else 0.6)])
	Art.window(b, Rect2(mid.x - d * 2.0, mid.y - c * 0.56, d * 4.0, c * 1.12))
	# the go button: a key's round bow in the card's colour
	var r := 24.0 * k
	var go := Vector2(body.position.x - r * 1.9, body.end.y - r * 0.6)
	if soon:
		b.disc(go, r, Art.IVORY_LOW)
	else:
		b.disc(go + Vector2(0.0, r * 0.1), r, colour.darkened(0.25))
		b.disc(go, r, colour)
		b.disc(go, r * 0.38, Art.DOOR)
		b.stroke(PackedVector2Array([go + Vector2(r * 0.9, 0.0), go + Vector2(r * 1.7, 0.0)]), r * 0.24, colour.darkened(0.25))

func _draw() -> void:
	super()
	var font: Font = CozyTheme.display(800)
	for n: Array in _letters:
		var fs: int = n[2]
		var tw := font.get_string_size(n[1], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, (n[0] as Vector2) + Vector2(-tw * 0.5, font.get_ascent(fs) * 0.36), n[1],
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, n[3])

func _lay() -> void:
	var words := _words(String(entry.get("title", "")), 22.0, size.y * 0.5, 205.0, Pal.TEXT, Color("6a7a5a"))
	words.position.y = roundf(14.0 * _k())
