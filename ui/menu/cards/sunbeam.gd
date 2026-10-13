extends "res://ui/menu/cards/card_face.gd"

## Sunbeam's card: the beam is the picture. A dawn of its own, lilac over
## apricot, and no floor or frame: the morning sun sits in the board's window
## low on the left, and its light runs the card's foot, takes a first dewdrop,
## climbs a step at two brass mirrors, takes a second, and runs on into a
## potted fern -- because the mirror that would send it up to the bud is one
## peg down its rail. That mirror is the go button: mounted in the card's
## colour, lifted, with a chevron up the rail to the peg the light crosses.
## The way from that peg to the bud is drawn faint, as light not yet there,
## and the bud is fed but shut.
##
## Everything is laid on one grid of cells counted from the card's bottom
## right corner, each piece on a rail of two pegs, as the board has them, and
## the beam is traced by the board's own rule of a mirror (a quarter turn off
## the glass). Every part is `ui/faces/sunbeam_parts.gd`'s own; only the go
## mirror's mount is redrawn, to take the card's colour. One mesh, nothing
## alive, no strings.

const Parts = preload("res://ui/faces/sunbeam_parts.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

## The row the card was drawn for (puzzle_card_2d.gd's CARD_H).
const H := 246.0
## A cell at H, and where the grid's bottom right cell stands in from the
## card's right side and foot.
const CELL := 46.0
const RIGHT := 36.0
const FOOT := 44.0
## The words' margin and how far down they start.
const SIDE := 22.0
const WORDS_TOP := 14.0
## Where the window stands in from the left side, at H.
const WINDOW_IN := 46.0

## The cells, as (columns in from the right, rows up from the foot).
const DROP_A := Vector2i(4, 0)
const TURN_A := Vector2i(3, 0)
const TURN_B := Vector2i(3, 1)
const DROP_B := Vector2i(2, 1)
const HOME := Vector2i(1, 1)
const BUD := Vector2i(1, 2)
const POT := Vector2i(0, 1)
## Each mirror's rail, as its two pegs; the go mirror waits on GO_FROM.
const RAIL_A := [Vector2i(3, 0), Vector2i(2, 0)]
const RAIL_B := [Vector2i(3, 1), Vector2i(3, 2)]
const GO_FROM := Vector2i(1, 0)
## How much stouter the go mirror is, and how far it is lifted (the board's
## own `lift`, 0 to 1).
const GO_SCALE := 1.22
const GO_LIFT := 0.8
## The beam's width before the first drop, after it and after the second, as
## the board fattens it with every drop passed, and the faint way to the bud.
const WIDTHS := [0.62, 0.8, 1.0]
const GHOST := 0.3
## How fed the bud is, short of the bloom.
const BUD_GROW := 0.5

const DAWN_TOP := Color("ebe2f5")
const DAWN_LOW := Color("fbe2cc")
const HAZE := Color("fff3de")
const BLURB := Color("7a6a78")
## The motes in the light, as [how far along the lit way 0 to 1, off the
## beam in cells, radius in cells].
const MOTES := [[0.12, -0.3, 0.035], [0.3, 0.26, 0.028], [0.52, -0.24, 0.04], [0.7, 0.3, 0.028], [0.88, -0.28, 0.034]]

func _k() -> float:
	return size.y / H

func _cell() -> float:
	return CELL * _k()

func _at(cell: Vector2i) -> Vector2:
	var k := _k()
	return Vector2(size.x - (RIGHT + float(cell.x) * CELL) * k, size.y - (FOOT + float(cell.y) * CELL) * k)

func _window() -> Vector2:
	return Vector2(WINDOW_IN * _k(), _at(DROP_A).y)

func _paint(b: Face.Builder) -> void:
	var c := _cell()
	var k := _k()
	var paper := ground()
	var first := b.verts.size()
	b.polygon(paper, Color.WHITE)
	shade(b, first, DAWN_TOP, DAWN_LOW, 0.0, size.y)
	# A warm haze low on the right, where the light is headed.
	Scenery.soft_disc(b, _at(Vector2i(2, 1)), c * 2.5, c * 1.7, Color(HAZE, 0.5))
	# The rails, under everything that rides them.
	_rail(b, RAIL_A, c)
	_rail(b, RAIL_B, c)
	_rail(b, [GO_FROM, HOME], c)
	# The window and its sun.
	var win := _window()
	Parts.window(b, win, c)
	Parts.sun(b, win, c)
	# The light: along the foot, up the step, and on into the fern.
	var a := _at(DROP_A)
	var ta := _at(TURN_A)
	var tb := _at(TURN_B)
	var d := _at(DROP_B)
	var home := _at(HOME)
	var stop := _at(POT) - Vector2(c * 0.24, 0.0)
	if not soon:
		Parts.beam(b, PackedVector2Array([home, _at(BUD) + Vector2(0.0, c * 0.2)]), c, GHOST, WIDTHS[2])
	Parts.beam(b, PackedVector2Array([win + Vector2(c * 0.3, 0.0), a]), c, 1.0, WIDTHS[0])
	Parts.beam(b, PackedVector2Array([a, ta, tb, d]), c, 1.0, WIDTHS[1])
	Parts.beam(b, PackedVector2Array([d, stop]), c, 1.0, WIDTHS[2])
	var lit := PackedVector2Array([win, a, ta, tb, d, stop])
	for m in MOTES:
		var at := _along(lit, float(m[0]))
		b.disc(at[0] + at[1].orthogonal() * c * float(m[1]), c * float(m[2]), Color(Pal.BEAM_CORE, 0.8))
	# What the light meets.
	Parts.drop(b, a, c, true)
	Parts.drop(b, d, c, true)
	Parts.pot(b, _at(POT), c)
	Parts.bud(b, _at(BUD), c, 0.0, false, 0.0, 0.0, BUD_GROW)
	Parts.mirror(b, ta, c, true)
	Parts.mirror(b, tb, c, true)
	Parts.star(b, ta, c * 0.2, Color(Pal.BEAM_CORE, 0.9))
	Parts.star(b, tb, c * 0.2, Color(Pal.BEAM_CORE, 0.9))
	if soon:
		Parts.mirror(b, _at(GO_FROM), c, true)
		return
	# The peg the go mirror is wanted on, ringed in the light's colour.
	b.stroke(Face.Builder.ring(home, c * 0.2, c * 0.2), maxf(2.0, c * 0.05), Color(Pal.BEAM_CORE, 0.95), true)
	_go(b, _at(GO_FROM), home, c, k)

## A rail between two cells, a peg at each.
func _rail(b: Face.Builder, cells: Array, c: float) -> void:
	var a := _at(cells[0])
	var z := _at(cells[1])
	var out := (z - a).normalized() * c * 0.3
	Parts.rail(b, a - out, z + out, c, PackedVector2Array([a, z]))

## The point `t` of the way along `pts`, and the heading there.
static func _along(pts: PackedVector2Array, t: float) -> Array:
	var total := 0.0
	for i in pts.size() - 1:
		total += pts[i].distance_to(pts[i + 1])
	var left := total * t
	for i in pts.size() - 1:
		var ln := pts[i].distance_to(pts[i + 1])
		if left <= ln or i == pts.size() - 2:
			var dir := (pts[i + 1] - pts[i]).normalized()
			return [pts[i] + dir * minf(left, ln), dir]
		left -= ln
	return [pts[0], Vector2.RIGHT]

## The go mirror at `at`, wanted at `home`: the board's mirror, lifted, with
## its mount in the card's colour, and a chevron up the rail between them.
func _go(b: Face.Builder, at: Vector2, home: Vector2, c: float, k: float) -> void:
	Parts.mirror(b, at, c, true, GO_LIFT, false, GO_SCALE)
	# The mount again over the brass, in the card's colour; then the glass.
	var r := c * 0.33 * GO_SCALE * (1.0 + GO_LIFT * 0.06)
	var mid := at + Vector2(0.0, -GO_LIFT * 6.0)
	b.disc(mid + Vector2(0.0, 4.0), r, colour.darkened(0.3))
	b.disc(mid, r, colour)
	var arc := Face.Builder.arc_points(mid, r, PI * 1.1, PI * 1.5)
	arc.append(mid)
	b.fan(arc, Color(Pal.SURFACE, 0.3))
	b.disc(mid, r * 0.73, colour.lerp(Pal.SURFACE, 0.45))
	var xf := Transform2D(-PI * 0.25, mid)
	var ln := c * 0.4 * GO_SCALE
	var th := c * 0.075 * GO_SCALE
	b.fan(xf * Face.Builder.round_rect(Vector2(-ln, -th + 3.0), Vector2(ln * 2.0, th * 2.0), th * 0.8), Pal.MIRROR_EDGE)
	b.fan(xf * Face.Builder.round_rect(Vector2(-ln, -th), Vector2(ln * 2.0, th * 2.0), th * 0.8), Pal.MIRROR_GLASS)
	b.fan(xf * Face.Builder.round_rect(Vector2(-ln * 0.75, -th * 0.6), Vector2(ln * 0.85, th * 0.4), th * 0.2),
		Color(1.0, 1.0, 1.0, 0.95))
	b.disc(xf * Vector2(-ln, 0.0), c * 0.05 * GO_SCALE, colour.darkened(0.3))
	b.disc(xf * Vector2(ln, 0.0), c * 0.05 * GO_SCALE, colour.darkened(0.3))
	# The chevron, on the rail between the mirror and its peg.
	var dir := (home - at).normalized()
	var tip := at.lerp(home, 0.6)
	var h := c * 0.13
	var side := dir.orthogonal() * h
	var pts := PackedVector2Array([tip - dir * h + side, tip, tip - dir * h - side])
	b.stroke(pts, c * 0.15 + 2.0 * k, colour.darkened(0.3))
	b.stroke(pts, c * 0.09, Pal.SURFACE)

func _lay() -> void:
	var room := size.x - SIDE - (SEAL_IN + SEAL_R + 10.0)
	var words := _words(String(entry.get("title", "")), SIDE, size.y * 0.5, room, Pal.TEXT, BLURB)
	words.position.y = roundf(WORDS_TOP * _k())
