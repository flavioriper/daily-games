extends "res://ui/menu/cards/card_face.gd"

## Code Break's card: the board's own box. The dark shelf across the top
## holds THE CODE under its wooden lids, as the board's first row does, with
## one seat already open and a friend looking out of it, and a pouch with a
## score in it at the row's end; the parchment under the shelf's lip carries
## the name, and the go button is one more lid, in the card's colour, with a
## chevron carved where the others have a question mark.
##
## The lids are the board's own planks (codebreak2d.gd's Lid), the friend is
## one of the seven (ui/faces/friends.gd) and the pips are the pouch's: a
## count, laid loose, never a map.

const Board = preload("res://puzzles/codebreak2d.gd")
const Friends = preload("res://ui/faces/friends.gd")
const CozyTheme = preload("res://ui/theme.gd")

## The row the card was drawn for (puzzle_card_2d.gd's CARD_H); the shelf
## grows with a taller one.
const H := 246.0
## The shelf: where it ends, the seats on it, their gap, and the margin.
const SHELF := 104.0
const SEAT := 68.0
const GAP := 10.0
const SEAT_Y := 19.0
const SIDE := 24.0
## A lid's corner and edge, in seats, as the board's are (0.22, and 7 on 150).
const LID_ROUND := 0.22
const LID_EDGE := 0.055
## The four seats: -1 a lid, else the friend looking out.
const SEATS := [-1, 4, -1, -1]
## The pouch at the row's end and what it holds: friends in the right seat,
## right friends in the wrong one.
const POUCH := Vector2(66.0, 46.0)
const EXACT := 1
const COLOURS := 2
## The go lid.
const GO := 76.0

const SHELF_TOP := Color("5f3f28")
const SHELF_LOW := Color("7a5334")
const PAPER_TOP := Color("f8f0dc")
const PAPER_LOW := Color("eedfc0")

func _k() -> float:
	return size.y / H

## The row's own scale: the shelf's, unless that would run the pouch into
## the corner the seal is pinned in.
func _ks() -> float:
	var row := SEATS.size() * (SEAT + GAP) + 4.0 + POUCH.x
	return minf(_k(), (size.x - SIDE * 2.0 - SEAL_R * 2.0 + 8.0) / row)

## The top left corner of seat `i`, the row standing in the shelf's middle.
func _seat(i: int) -> Vector2:
	var ks := _ks()
	return Vector2(SIDE + i * (SEAT + GAP) * ks, SEAT_Y * _k() + SEAT * (_k() - ks) * 0.5)

func _go_at() -> Vector2:
	var low := SHELF * _k()
	return Vector2(size.x - SIDE - GO, low + (size.y - low - GO) * 0.5 - 2.0)

func _paint(b: Face.Builder) -> void:
	var k := _k()
	var paper := ground()
	var low := SHELF * k
	var first := b.verts.size()
	b.polygon(paper, Color.WHITE)
	shade(b, first, PAPER_TOP, PAPER_LOW, low, size.y)
	# The shelf, its grain, and the lip the parchment hangs under.
	for part in Geometry2D.intersect_polygons(paper, _band(-8.0, low)):
		first = b.verts.size()
		b.polygon(part, Color.WHITE)
		shade(b, first, SHELF_TOP, SHELF_LOW, 0.0, low)
	for run: Array in [[0.10, 0.02, 0.46, 0.4], [0.13, 0.58, 0.97, 2.0], [0.50, 0.70, 0.99, 1.1],
			[0.86, 0.03, 0.40, 2.6], [0.90, 0.52, 0.90, 0.2]]:
		var pts := PackedVector2Array()
		for i in 13:
			var x := lerpf(run[1], run[2], i / 12.0)
			pts.append(Vector2(x * size.x, (run[0] + 0.022 * sin(x * 11.0 + run[3])) * low))
		b.stroke(pts, 2.0 * k, Color(Pal.WOOD, 0.13))
	for part in Geometry2D.intersect_polygons(paper, _band(low - 7.0 * k, low)):
		b.polygon(part, Pal.WOOD)
	for part in Geometry2D.intersect_polygons(paper, _band(low - 7.0 * k, low - 4.5 * k)):
		b.polygon(part, Color(Pal.WOOD.lightened(0.35), 0.75))
	first = b.verts.size()
	b.polygon(PackedVector2Array([Vector2(EDGE, low), Vector2(size.x - EDGE, low),
		Vector2(size.x - EDGE, low + 12.0 * k), Vector2(EDGE, low + 12.0 * k)]), Color.WHITE)
	shade(b, first, Color(Pal.PLAQUE_DEEP, 0.22), Color(Pal.PLAQUE_DEEP, 0.0), low, low + 12.0 * k)
	# The seats.
	var ks := _ks()
	var px := SEAT * ks
	for i in SEATS.size():
		var at := _seat(i)
		var who: int = SEATS[i]
		if who < 0:
			_lid(b, at, px, Pal.WOOD, Pal.WOOD_DEEP)
			b.append(Board.Lid._plank(px), Transform2D(0.0, at))
		else:
			# An open seat is its friend's own chip, as a filled seat is on
			# the board (SEAT_TINT, SEAT_RIM).
			var socket := Face.Builder.round_rect(at, Vector2(px, px), px * LID_ROUND)
			b.polygon(socket, Friends.tile(who).lerp(Friends.colour(who), 0.14))
			b.stroke(Face.Builder.round_rect(at + Vector2(2.0, 2.0), Vector2(px - 4.0, px - 4.0), px * LID_ROUND - 2.0),
				3.0 * ks, Color(Friends.colour(who), 0.55), true)
	# The pouch, and the score piled in it.
	var pouch := POUCH * ks
	var p_at := _seat(SEATS.size()) + Vector2(4.0 * ks, (px - pouch.y) * 0.5)
	b.polygon(Face.Builder.round_rect(p_at + Vector2(0.0, 3.0 * ks), pouch, pouch.y * 0.5), Color(0.14, 0.08, 0.04, 0.30))
	b.polygon(Face.Builder.round_rect(p_at, pouch, pouch.y * 0.5), Pal.PARCHMENT.lerp(Pal.SURFACE, 0.5))
	var r := 8.2 * ks
	var spots := [Vector2(-0.19, -0.19), Vector2(0.17, -0.22), Vector2(-0.01, 0.20)]
	for i in spots.size():
		var c: Vector2 = p_at + pouch * 0.5 + Vector2(spots[i].x * pouch.x, spots[i].y * pouch.y)
		if i < EXACT:
			b.disc(c, r, Color(Pal.TEXT, 0.88))
		else:
			b.disc(c, r, Pal.SURFACE)
			b.stroke(Face.Builder.arc_points(c, r - 1.4 * ks, 0.0, TAU), 2.2 * ks, Color(Pal.TEXT_DIM, 0.9), true)
	# The go lid.
	if not soon:
		var g := _go_at()
		_lid(b, g, GO, colour, colour.darkened(0.22))
		b.polygon(Face.Builder.round_rect(g + Vector2(GO * 0.26, GO * 0.07), Vector2(GO * 0.48, GO * 0.045), GO * 0.0225),
			Color(1.0, 1.0, 1.0, 0.28))
		for c: Vector2 in [Vector2(0.17, 0.2), Vector2(0.83, 0.2)]:
			b.disc(g + c * GO, GO * 0.036, Color(colour.darkened(0.35), 0.7))
		var mid := g + Vector2(GO, GO) * 0.5 + Vector2(GO * 0.02, GO * 0.03)
		var c2 := GO * 0.15
		b.stroke(PackedVector2Array([mid + Vector2(-c2 * 0.55, -c2), mid + Vector2(c2 * 0.55, 0.0),
			mid + Vector2(-c2 * 0.55, c2)]), GO * 0.10, Pal.SURFACE)

## A band of the card from `y0` to `y1`, wider than the paper it is cut by.
func _band(y0: float, y1: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(-8.0, y0), Vector2(size.x + 8.0, y0),
		Vector2(size.x + 8.0, y1), Vector2(-8.0, y1)])

## A lid `px` square at `at`: its shadow, its edge and its face.
func _lid(b: Face.Builder, at: Vector2, px: float, fill: Color, deep: Color) -> void:
	var edge := px * LID_EDGE
	b.polygon(Face.Builder.round_rect(at + Vector2(0.0, px * 0.06), Vector2(px, px), px * LID_ROUND), Color(0.14, 0.08, 0.04, 0.30))
	b.polygon(Face.Builder.round_rect(at, Vector2(px, px), px * LID_ROUND), deep)
	b.polygon(Face.Builder.round_rect(at + Vector2(edge, edge), Vector2(px - edge * 2.0, px - edge * 2.4),
		px * LID_ROUND - edge), fill)

func _lay() -> void:
	var k := _k()
	var px := SEAT * _ks()
	for i in SEATS.size():
		var at := _seat(i)
		var who: int = SEATS[i]
		if who >= 0:
			var face: Control = Friends.make(who, px * 0.86, at + Vector2(px, px) * 0.5)
			_keep(face)
			face.set_idle(true)
			continue
		# The lid's mark, as the board carves it.
		var mark := Label.new()
		mark.text = "?"
		mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		mark.add_theme_font_override("font", CozyTheme.display(700))
		mark.add_theme_font_size_override("font_size", int(px * 0.44))
		mark.add_theme_color_override("font_color", Color(Pal.WOOD_DEEP, 0.85))
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_keep(mark)
		mark.position = at
		mark.size = Vector2(px, px)
	var low := SHELF * k
	_words(String(entry.get("title", "")), SIDE, low + (size.y - low) * 0.5 + 1.0, _go_at().x - SIDE - 8.0)
