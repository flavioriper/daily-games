extends "res://ui/menu/cards/card_face.gd"

## Pearl Dive's card: the sea in section, kept light. A strip of morning sky
## holds the name, the waterline runs under it, and the water deepens from a
## pale aqua to a soft blue-teal over a sandy bed along the foot. On the
## right a rope drops from a float on the waterline, past two of the board's
## own pips where earlier answers left the bell, to the bell itself; the
## pearl waits in its open shell on the bed below and to the right, further
## down than the bell has been. A few bubbles rise beside the rope. No word
## is written: the answers change every day.
##
## The go button is the bell: the board's diving bell redrawn in the card's
## colour, larger, lifted over a shadow, a chevron pointing down where its
## window was. Before the card opens it is the board's plain brass bell.
##
## Everything is one mesh, the shell, pips and bubbles ui/faces/pearl_art.gd's
## own builders. Nothing lives on the card.

const Art = preload("res://ui/faces/pearl_art.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

## The row the card was drawn for (puzzle_card_2d.gd's CARD_H).
const H := 246.0
## The picture's room from the card's right side at H, and where the words
## end: the scale is capped so the bell never stands under them.
const REACH := 176.0
const WORDS_END := 250.0
## The waterline and the bed's top, at H.
const SURFACE_Y := 86.0
const BED := 20.0
## The rope: how far in from the right it hangs, at H.
const ROPE_IN := 158.0
const ROPE_W := 2.6
const FLOAT_R := 8.0
## The bell: how far down its middle hangs, the go bell's radius, the plain
## one's, how far the go bell is lifted and its shadow.
const BELL_Y := 166.0
const GO_R := 36.0
const PLAIN_R := 24.0
const GO_LIFT := 4.0
const GO_SHADOW := 0.2
## The pips an answer left on the rope: [how far down at H, tier].
const PIPS := [[98.0, 0], [110.0, 2]]
const PIP_R := 6.0
const PIP_OUT := 13.0
## The shell: the pearl's radius, how far in from the right it lies and how
## far its foot sinks into the sand.
const PEARL_R := 25.0
const SHELL_IN := 66.0
const SHELL_SINK := 5.0
## The bubbles, as [in from the right, down, radius] at H.
const BUBBLES := [[112.0, 116.0, 5.0], [100.0, 98.0, 3.5], [181.0, 138.0, 4.0], [189.0, 114.0, 2.8]]
## The words' margin, their room and how far down they start.
const SIDE := 22.0
const WORDS := 215.0
const WORDS_TOP := 14.0

## The morning: the sky, the water from the surface to the foot, the line
## between them, the sand and the blurb's ink.
const SKY_TOP := Color("f3f8f6")
const SKY_LOW := Color("e6f4f1")
const SEA_TOP := Color("d6eff2")
const SEA_LOW := Color("9fd0dc")
const SHINE := Color("f7fdfd")
const SAND := Color("f1e3c0")
const SAND_LOW := Color("e3cf9f")
const ROPE := Color("8b7a5e")
const BLURB := Color("4b6a76")

func _kh() -> float:
	return size.y / H

## The picture's scale: the card's height sets it, its width caps it.
func _k() -> float:
	return minf(_kh(), (size.x - WORDS_END) / REACH)

func _surface() -> float:
	return SURFACE_Y * _kh()

## `shape` where it lies on the paper, shaded top to bottom.
func _on_paper(b: Face.Builder, shape: PackedVector2Array, top: Color, low: Color, y0: float, y1: float) -> void:
	for piece: PackedVector2Array in Geometry2D.intersect_polygons(shape, ground()):
		var first := b.verts.size()
		b.polygon(piece, Color.WHITE)
		shade(b, first, top, low, y0, y1)

func _paint(b: Face.Builder) -> void:
	var k := _k()
	var surf := _surface()
	var first := b.verts.size()
	b.polygon(ground(), Color.WHITE)
	shade(b, first, SKY_TOP, SKY_LOW, 0.0, surf)
	# The water, its line, and the bed with one slow dune.
	_on_paper(b, PackedVector2Array([Vector2(0.0, surf), Vector2(size.x, surf), Vector2(size.x, size.y),
		Vector2(0.0, size.y)]), SEA_TOP, SEA_LOW, surf, size.y)
	b.stroke(PackedVector2Array([Vector2(EDGE + 2.0, surf), Vector2(size.x - EDGE - 2.0, surf)]), 2.4 * _kh(),
		Color(SHINE, 0.9))
	var bed_y := size.y - BED * _kh()
	var bed := PackedVector2Array()
	var steps := 24
	for i in steps + 1:
		var t := float(i) / float(steps)
		bed.append(Vector2(t * size.x, bed_y + sin(t * TAU * 1.4 + 0.6) * 3.5 * _kh()))
	bed.append(Vector2(size.x, size.y))
	bed.append(Vector2(0.0, size.y))
	_on_paper(b, bed, SAND, SAND_LOW, bed_y - 4.0, size.y)
	# The shell on the bed, the rope from its float, the pips, the bubbles.
	var rope_x := size.x - ROPE_IN * k
	var shell_at := Vector2(size.x - SHELL_IN * k, bed_y + SHELL_SINK * k - PEARL_R * k * 2.2)
	Scenery.soft_disc(b, shell_at + Vector2(0.0, PEARL_R * k * 2.1), PEARL_R * k * 2.0, PEARL_R * k * 0.4,
		Color(Pal.TEXT, 0.12))
	Art.shell(b, shell_at, PEARL_R * k)
	var bell_at := Vector2(rope_x, surf + (BELL_Y - SURFACE_Y) * k)
	var r := (PLAIN_R if soon else GO_R) * k
	b.stroke(PackedVector2Array([Vector2(rope_x, surf), bell_at - Vector2(0.0, r * 1.1)]), ROPE_W * k, ROPE)
	b.disc(Vector2(rope_x, surf), FLOAT_R * k, Pal.SURFACE)
	b.polygon(Face.Builder.arc_points(Vector2(rope_x, surf), FLOAT_R * k, PI, TAU), Art.TIER[4])
	for p: Array in PIPS:
		Art.pip(b, Vector2(rope_x + PIP_OUT * k, surf + (float(p[0]) - SURFACE_Y) * k), PIP_R * k, int(p[1]))
	for bub: Array in BUBBLES:
		Art.bubble(b, Vector2(size.x - float(bub[0]) * k, surf + (float(bub[1]) - SURFACE_Y) * k), float(bub[2]) * k)
	if soon:
		Art.bell(b, bell_at, r)
	else:
		_go(b, bell_at, r, k)

## The go bell about `at`: the board's bell in the card's colour, lifted over
## its shadow, a chevron pointing down in place of the window.
func _go(b: Face.Builder, at: Vector2, r: float, k: float) -> void:
	Scenery.soft_disc(b, at + Vector2(0.0, r * 1.02 + GO_LIFT * k), r * 0.95, r * 0.26, Color(Pal.TEXT, GO_SHADOW))
	var c := at - Vector2(0.0, GO_LIFT * k)
	var deep := colour.darkened(0.26)
	b.stroke(Face.Builder.arc_points(c + Vector2(0.0, -1.0) * r, 0.2 * r, 0.0, TAU), 0.1 * r, deep, true)
	var dome := PackedVector2Array([c + Vector2(-0.82, 0.62) * r])
	dome.append_array(Face.Builder.bezier3(c + Vector2(-0.82, 0.62) * r, c + Vector2(-0.86, -0.5) * r,
		c + Vector2(-0.5, -0.9) * r, c + Vector2(0.0, -0.9) * r))
	dome.append_array(Face.Builder.bezier3(c + Vector2(0.0, -0.9) * r, c + Vector2(0.5, -0.9) * r,
		c + Vector2(0.86, -0.5) * r, c + Vector2(0.82, 0.62) * r))
	b.polygon(dome, colour)
	b.stroke(Face.Builder.arc_points(c + Vector2(0.0, -0.06) * r, 0.62 * r, PI * 1.12, PI * 1.5), 0.1 * r,
		Color(Pal.SURFACE, 0.3))
	b.fan(Face.Builder.round_rect(c + Vector2(-0.96, 0.52) * r, Vector2(1.92, 0.34) * r, 0.14 * r), deep)
	var h := r * 0.24
	var m := c + Vector2(0.0, -0.1) * r
	b.stroke(PackedVector2Array([m + Vector2(-h, -h * 0.55), m + Vector2(0.0, h * 0.55), m + Vector2(h, -h * 0.55)]),
		r * 0.15, Pal.SURFACE)

func _lay() -> void:
	var words := _words(String(entry.get("title", "")), SIDE, size.y * 0.5, WORDS, Pal.TEXT, BLURB)
	words.position.y = roundf(WORDS_TOP * _kh())
