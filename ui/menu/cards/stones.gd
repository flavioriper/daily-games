extends "res://ui/menu/cards/card_face.gd"

## Stepping Stones' card: a brook winding down the card's right side through
## pale meadow grass, three stepping stones across it reading CORD, WORD,
## WARD, each a letter from the last, the letters that already match the
## far bank's WARM on moss and each stone's changed letter in gold; the go
## button is a round stone in the card's colour on the grass to their left.
##
## Everything still is one mesh; the letters are draw_string calls over it.

const Art = preload("res://ui/faces/stones_art.gd")
const CozyTheme = preload("res://ui/theme.gd")

## The row the card was drawn for (puzzle_card_2d.gd's CARD_H).
const H := 246.0
## The brook's middle from the card's right, a letter cell at H.
const RIGHT := 150.0
const CELL := 27.0
const STONES := ["CORD", "WORD", "WARD"]
const FAR := "WARM"

var _letters: Array = []

func _k() -> float:
	return size.y / H

func _paint(b: Face.Builder) -> void:
	_letters = []
	var k := _k()
	var card := ground()
	var first := b.verts.size()
	b.polygon(card, Color.WHITE)
	shade(b, first, Art.GRASS, Art.GRASS_LOW, 0.0, size.y)
	# the brook: a band winding top to bottom, cut to the card's shape
	var mid := size.x - RIGHT * k
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for i in 9:
		var t := float(i) / 8.0
		var y := lerpf(-10.0, size.y + 10.0, t)
		var x := mid + sin(t * PI * 1.4 + 0.4) * 22.0 * k
		left.append(Vector2(x - 92.0 * k, y))
		right.append(Vector2(x + 92.0 * k, y))
	var band := PackedVector2Array(left)
	for i in range(right.size() - 1, -1, -1):
		band.append(right[i])
	for part in Geometry2D.intersect_polygons(band, card):
		var f := b.verts.size()
		b.polygon(part, Color.WHITE)
		for j in range(f, b.verts.size()):
			var dx := absf(b.verts[j].x - mid) / (92.0 * k)
			b.cols[j] = Art.WATER_DEEP.lerp(Art.WATER_EDGE, clampf(dx, 0.0, 1.0))
	# the current's streaks
	for i in 4:
		var y := size.y * (0.16 + i * 0.23)
		var x0 := mid - 60.0 * k + (i % 2) * 40.0 * k
		b.stroke(PackedVector2Array([Vector2(x0, y), Vector2(x0 + 22.0 * k, y - 3.0 * k), Vector2(x0 + 44.0 * k, y)]), 2.5 * k, Color(Art.WATER_HI, 0.7))
	# reeds on the grass by the water
	Art.reed(b, Vector2(mid - 104.0 * k, size.y - 30.0 * k), 64.0 * k, k)
	Art.reed(b, Vector2(mid - 92.0 * k, size.y - 22.0 * k), 48.0 * k, k)
	# the stones, zigzagging down
	var c := CELL * k
	var sz := Vector2(c * 5.0, c * 1.25)
	for i in STONES.size():
		var at := Vector2(mid + (14.0 if i % 2 == 0 else -14.0) * k, size.y * (0.24 + i * 0.27))
		Art.stone(b, at, sz, 17 + i * 31)
		var word: String = STONES[i]
		var prev: String = STONES[i - 1] if i > 0 else "COLD"
		for j in word.length():
			var p := at + Vector2((j - 1.5) * c, 0.0)
			var ink := Art.INK
			if word[j] == FAR[j]:
				Art.moss(b, p, c * 0.42)
				ink = Art.MOSS_INK
			if word[j] != prev[j]:
				ink = Art.CHANGED
			_letters.append([p, word[j], roundi(c * 0.66), ink])
	# the go button: a round stone in the card's colour
	var r := 24.0 * k
	var go := Vector2(mid - 150.0 * k, size.y - 60.0 * k)
	if soon:
		b.disc(go, r, Art.STONE_DEEP)
	else:
		b.ellipse(go + Vector2(0.0, r * 0.14), r * 1.08, r * 0.98, colour.darkened(0.25))
		b.ellipse(go, r * 1.08, r, colour)
		b.ellipse(go + Vector2(-r * 0.3, -r * 0.4), r * 0.4, r * 0.16, Color(1, 1, 1, 0.3))

func _draw() -> void:
	super()
	var font: Font = CozyTheme.display(800)
	for n: Array in _letters:
		var fs: int = n[2]
		var tw := font.get_string_size(n[1], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, (n[0] as Vector2) + Vector2(-tw * 0.5, font.get_ascent(fs) * 0.36), n[1],
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, n[3])

func _lay() -> void:
	var words := _words(String(entry.get("title", "")), 22.0, size.y * 0.5, 205.0, Pal.TEXT, Color("5f7a4a"))
	words.position.y = roundf(14.0 * _k())
