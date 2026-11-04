extends "res://ui/menu/cards/card_face.gd"

## Garden Fence's card: a little square garden bed on a mown lawn, a low
## rail round it with three posts a side, a letter on each cap; GARLIC tied
## in jute, every post it touched in bloom, and CHESTNUT half strung in
## green from its last post; the go button is a round post top in the
## card's colour on the lawn to the bed's left.
##
## Everything still is one mesh; the letters are draw_string calls over it.

const Art = preload("res://ui/faces/fence_art.gd")
const Board = preload("res://puzzles/fence2d.gd")
const CozyTheme = preload("res://ui/theme.gd")

## The row the card was drawn for (puzzle_card_2d.gd's CARD_H).
const H := 246.0
## The bed's middle from the card's right, its side, a post's radius at H.
const RIGHT := 150.0
const SIDE := 192.0
const POST_R := 15.5
## Three a side, clockwise from the top (tools/build_fence.py's order).
const POSTS := "hnraitglsceu"
const TIED := "garlic"
const STRUNG := "ches"

var _letters: Array = []

func _k() -> float:
	return size.y / H

func _paint(b: Face.Builder) -> void:
	_letters = []
	var k := _k()
	var card := ground()
	b.polygon(card, Art.LAWN)
	# mowing stripes, cut to the card's rounded shape
	var band := 30.0 * k
	var x := -band * 0.5
	while x < size.x:
		var stripe := PackedVector2Array([Vector2(x, 0), Vector2(x + band, 0), Vector2(x + band - 20.0 * k, size.y), Vector2(x - 20.0 * k, size.y)])
		for part in Geometry2D.intersect_polygons(stripe, card):
			b.polygon(part, Color(Art.LAWN_STRIPE, 0.6))
		x += band * 2.0
	var mid := Vector2(size.x - RIGHT * k, size.y * 0.54)
	var r := POST_R * k
	var box := Rect2(mid - Vector2.ONE * SIDE * k * 0.5, Vector2.ONE * SIDE * k)
	var f := Board.fit(4, box, r * 1.1)
	Art.bed(b, f.ring, k * 0.4)
	var spots: PackedVector2Array = f.posts
	var at := func(ch: String) -> Vector2: return spots[POSTS.find(ch)]
	var wd := r * 0.2
	for i in TIED.length() - 1:
		Art.twine(b, at.call(TIED[i]), at.call(TIED[i + 1]), wd, Art.TWINE, 2.0 * k)
	for i in STRUNG.length() - 1:
		Art.twine(b, at.call(STRUNG[i]), at.call(STRUNG[i + 1]), wd, Art.STRING, 2.0 * k)
	for i in POSTS.length():
		var p := spots[i]
		var used := TIED.contains(POSTS[i])
		var g := Face.Builder.new()
		Art.post(g, r, i, used)
		b.append(g.mesh(), Transform2D(0.0, p))
		var ink := Art.INK
		if STRUNG.contains(POSTS[i]):
			b.stroke(Face.Builder.ring(p, r * 0.86, r * 0.86), maxf(1.5, r * 0.12), Art.STRING, true)
		_letters.append([p, POSTS[i].to_upper(), roundi(r * 0.95), ink])
		if used:
			var out := (p - mid).normalized()
			Art.daisy(b, p + out * r * 0.8 + out.orthogonal() * r * 0.55, r * 0.42, 0.3)
	# the go button: a round post top in the card's colour
	var gr := 24.0 * k
	var go := Vector2(box.position.x - 70.0 * k, size.y - 60.0 * k)
	if soon:
		b.disc(go, gr, Art.POST_DEEP)
	else:
		b.disc(go + Vector2(0.0, gr * 0.14), gr, colour.darkened(0.25))
		b.disc(go, gr, colour)
		b.stroke(Face.Builder.ring(go, gr * 0.62, gr * 0.6), maxf(1.0, gr * 0.06), colour.darkened(0.15), true)
		b.disc(go + Vector2(-gr * 0.1, -gr * 0.05), gr * 0.12, colour.darkened(0.12))

func _draw() -> void:
	super()
	var font: Font = CozyTheme.display(800)
	for n: Array in _letters:
		var fs: int = n[2]
		var tw := font.get_string_size(n[1], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, (n[0] as Vector2) + Vector2(-tw * 0.5, font.get_ascent(fs) * 0.36), n[1],
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, n[3])

func _lay() -> void:
	var words := _words(String(entry.get("title", "")), 22.0, size.y * 0.5, 205.0, Pal.TEXT, Color("5f7a3a"))
	words.position.y = roundf(14.0 * _k())
