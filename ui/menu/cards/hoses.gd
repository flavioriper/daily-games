extends "res://ui/menu/cards/card_face.gd"

## Hosepipes' card: a corner of the garden on warm paper. A small raised bed
## of three by three squares stands on the card's right, two hoses through
## it, every square watered: a teal hose from its tap round the top to its
## open flower and a terracotta one along the foot. The go button is a tap
## handle in the card's colour at the bed's left.
##
## Everything is one mesh.

const Art = preload("res://ui/faces/hoses_art.gd")

## The row the card was drawn for (puzzle_card_2d.gd's CARD_H).
const H := 246.0
## A square at H, the bed's room from the card's right side and foot.
const CELL := 52.0
const RIGHT := 52.0
const FOOT := 36.0
## The two hoses on the bed, squares in reading order (3 by 3).
const HOSES := [[3, 0, 1, 2, 5, 4], [6, 7, 8]]
const PAPER_TOP := Color("fdf5e8")
const PAPER_LOW := Color("f4e2cc")
const BLURB := Color("7a6650")

func _k() -> float:
	return size.y / H

func _paint(b: Face.Builder) -> void:
	var k := _k()
	var first := b.verts.size()
	b.polygon(ground(), Color.WHITE)
	shade(b, first, PAPER_TOP, PAPER_LOW, 0.0, size.y)
	var cs := CELL * k
	var side := cs * 3.0
	var o := Vector2(size.x - RIGHT * k - side, size.y - FOOT * k - side)
	Art.frame(b, Rect2(o, Vector2(side, side)), cs * 0.26)
	for i in 9:
		Art.soil(b, _cell(o, cs, i), cs, true, i)
	for c in HOSES.size():
		var pts := []
		for v in HOSES[c]:
			pts.append(_cell(o, cs, int(v)))
		Art.hose(b, pts, cs, Art.colour(c))
	for c in HOSES.size():
		var h: Array = HOSES[c]
		Art.tap(b, _cell(o, cs, int(h[0])), cs, Art.colour(c), c)
		Art.flower(b, _cell(o, cs, int(h[h.size() - 1])), cs, Art.colour(c), 1.0, c)
	# the go button: a tap handle in the card's colour
	var go := Vector2(o.x - 70.0 * k, size.y - FOOT * k - 30.0 * k)
	var r := 26.0 * k
	if soon:
		Art.tap(b, go, r * 2.4, Art.colour(2))
	else:
		b.disc(go + Vector2(0.0, r * 0.1), r, colour.darkened(0.25))
		b.disc(go, r, colour)
		b.disc(go, r * 0.68, colour.darkened(0.15))
		for i in 4:
			var d := Vector2.RIGHT.rotated(i * PI * 0.5) * r * 0.62
			b.stroke(PackedVector2Array([go, go + d]), r * 0.2, Art.CREAM)
		b.disc(go, r * 0.22, Art.BRASS)

func _cell(o: Vector2, cs: float, i: int) -> Vector2:
	return o + Vector2((i % 3 + 0.5) * cs, (i / 3 + 0.5) * cs)

func _lay() -> void:
	var words := _words(String(entry.get("title", "")), 22.0, size.y * 0.5, 215.0, Pal.TEXT, BLURB)
	words.position.y = roundf(14.0 * _k())
