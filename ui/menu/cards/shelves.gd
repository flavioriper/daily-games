extends "res://ui/menu/cards/card_face.gd"

## Four Shelves' card: a corner of the sage dresser on cream paper, two rows
## of jam jars on its planks, the top row already a shelf up in sun with its
## jars gone, and the go button a jar whose lid wears the card's colour.
##
## Everything is one mesh. Nothing lives on the card.

const Art = preload("res://ui/faces/shelves_art.gd")
const World = preload("res://puzzles/shelves_world.gd")

## The row the card was drawn for (puzzle_card_2d.gd's CARD_H).
const H := 246.0
const JAR := Vector2(52.0, 62.0)
const RIGHT := 50.0
const PAPER_TOP := Color("fdf6ea")
const PAPER_LOW := Color("f3e6d2")

func _k() -> float:
	return size.y / H

func _paint(b: Face.Builder) -> void:
	var k := _k()
	var first := b.verts.size()
	b.polygon(ground(), Color.WHITE)
	shade(b, first, PAPER_TOP, PAPER_LOW, 0.0, size.y)
	var jar := JAR * k
	var x1 := size.x - RIGHT * k
	var x0 := x1 - jar.x * 4.2
	var panel := Rect2(x0 - 14.0 * k, 26.0 * k, x1 - x0 + 28.0 * k, size.y - 52.0 * k)
	b.fan(Face.Builder.round_rect(panel.position - Vector2(10.0 * k, 0.0), panel.size + Vector2(20.0 * k, 0.0), 12.0 * k), World.FRAME)
	b.fan(Face.Builder.round_rect(panel.position + Vector2(0.0, 6.0 * k), panel.size - Vector2(0.0, 12.0 * k), 8.0 * k), World.PANEL)
	# the top row: a shelf up in sun
	var row0 := panel.position.y + 18.0 * k + jar.y * 0.5
	Art.shelf(b, Vector2(panel.get_center().x, row0), Vector2(x1 - x0, jar.y * 0.8), 0)
	# the second row: four jars on their plank, the last the go button
	var row1 := row0 + jar.y * 1.25
	Art.plank(b, Vector2(panel.get_center().x, row1 + jar.y * 0.5), x1 - x0 + 10.0 * k, 9.0 * k)
	for i in 4:
		var at := Vector2(x0 + jar.x * (0.6 + i * 1.0), row1)
		var jb := Face.Builder.new()
		Art.jar(jb, Vector2.ZERO, jar * 0.92)
		var m := jb.mesh()
		if i == 3 and not soon:
			_tint_lid(jb)
			m = jb.mesh()
		b.append(m, Transform2D(0.0, at))

## The go jar's lid in the card's colour.
func _tint_lid(jb: Face.Builder) -> void:
	for i in jb.cols.size():
		var c: Color = jb.cols[i]
		if _same(c, Art.LID):
			jb.cols[i] = Color(colour.r, colour.g, colour.b, c.a)
		elif _same(c, Art.LID_DEEP):
			var d := colour.darkened(0.25)
			jb.cols[i] = Color(d.r, d.g, d.b, c.a)

static func _same(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) < 0.01

func _lay() -> void:
	var words := _words(String(entry.get("title", "")), 22.0, size.y * 0.5, 215.0)
	words.position.y = roundf(14.0 * _k())
