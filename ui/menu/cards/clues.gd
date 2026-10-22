extends "res://ui/menu/cards/card_face.gd"

## Five Clues' card: a corner of the cork board on cream paper, five clue
## cards pinned down it, the first two turned up with a line of pencil on
## each, the rest kraft backs; the go button is the last card's pin in the
## card's colour.
##
## Everything is one mesh. Nothing lives on the card.

const Art = preload("res://ui/faces/clues_art.gd")
const World = preload("res://puzzles/clues_world.gd")

const H := 246.0
const CARD := Vector2(150.0, 30.0)
const RIGHT := 60.0
const PAPER_TOP := Color("fdf6ea")
const PAPER_LOW := Color("f3e6d2")

func _k() -> float:
	return size.y / H

func _paint(b: Face.Builder) -> void:
	var k := _k()
	var first := b.verts.size()
	b.polygon(ground(), Color.WHITE)
	shade(b, first, PAPER_TOP, PAPER_LOW, 0.0, size.y)
	var sz := CARD * k
	var cx := size.x - RIGHT * k - sz.x * 0.5 - 20.0 * k
	var cork := Rect2(cx - sz.x * 0.5 - 20.0 * k, 22.0 * k, sz.x + 40.0 * k, size.y - 44.0 * k)
	b.fan(Face.Builder.round_rect(cork.position - Vector2(8.0, 8.0) * k, cork.size + Vector2(16.0, 16.0) * k, 10.0 * k), World.FRAME)
	b.fan(Face.Builder.round_rect(cork.position, cork.size, 5.0 * k), World.CORK)
	var gap := (cork.size.y - 16.0 * k - sz.y * 5.0) / 4.0
	for i in 5:
		var at := Vector2(cx, cork.position.y + 8.0 * k + sz.y * 0.5 + i * (sz.y + gap))
		if i < 2:
			Art.card(b, at, sz)
			var pts := PackedVector2Array()
			for j in 7:
				var t := float(j) / 6.0
				pts.append(at + Vector2(lerpf(-sz.x * 0.3, sz.x * 0.3, t), sz.y * 0.1 + sin(t * 9.0 + i) * sz.y * 0.1))
			b.stroke(pts, 2.2 * k, Color(Art.INK, 0.6))
		else:
			Art.back(b, at, sz)
	if not soon:
		var pin := Vector2(cx, cork.position.y + 8.0 * k + sz.y * 4.5 + 4.0 * gap - sz.y * 0.42)
		b.disc(pin + Vector2(0.0, 2.0 * k), sz.y * 0.2, colour.darkened(0.3))
		b.disc(pin, sz.y * 0.2, colour)

func _lay() -> void:
	var words := _words(String(entry.get("title", "")), 22.0, size.y * 0.5, 215.0)
	words.position.y = roundf(14.0 * _k())
