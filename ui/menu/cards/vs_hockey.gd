extends "res://ui/menu/cards/card_face.gd"

## Air Hockey's card: the table's ice is the paper. The centre line and the
## right half of the centre circle cross the card large and faint, and the
## goal mouth is cut into the right edge under the seal's corner, the only
## place the table's wooden rail shows. The puck is on its way to that goal
## with three fading discs behind it, and the rival's sun mallet stands low
## by the goal, a little out of the way.
##
## The go button is our mallet: the table's mallet in the card's colour,
## larger, lifted over its shadow, a chevron on its knob along the shot. The
## name stands top left over the ice.
##
## Everything is one mesh, in versus/hockey_table.gd's own colours and
## shapes. Nothing lives on the card and it writes no string.

const Table = preload("res://versus/hockey_table.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

## The row the card was drawn for (puzzle_card_2d.gd's CARD_H) and the
## width its picture was laid for.
const H := 246.0
const W := 490.0
## Where things stand, as [in from the card's right side, up from its foot],
## at H: the goal's middle, our mallet, the puck, the rival's mallet.
const GOAL := Vector2(0.0, 88.0)
const OURS := Vector2(203.0, 130.0)
const PUCK := Vector2(110.0, 107.0)
const RIVAL := Vector2(64.0, 40.0)
## The goal: half its mouth, how long the rail runs either side of it, the
## rail's width and how deep the slot is, at H.
const MOUTH := 37.0
const STUB := 20.0
const RAIL := 13.0
const SLOT := 9.0
## The centre line, in from the right, and the circle's radius, at H.
const CENTRE := 236.0
const CIRCLE := 64.0
const MARK_W := 3.0
const MARK_ALPHA := 0.26
## The radii at H: the go mallet, the plain one a card not open yet wears,
## the rival's, the puck.
const GO_R := 34.0
const PLAIN_R := 24.0
const RIVAL_R := 23.0
const PUCK_R := 18.0
## How far the go mallet is lifted, and its shadow.
const GO_LIFT := 4.0
const GO_SHADOW := 0.24
## The trail: how many discs, and how far back along the shot the last is,
## as a share of the way from the puck to our mallet.
const TRAIL := 3
const TRAIL_BACK := 0.62
## The words' margin, their room and how far down they start.
const SIDE := 22.0
const WORDS := 215.0
const WORDS_TOP := 14.0

## The ice, lit over a deeper blue, and the blurb's ink.
const ICE_TOP := Color("f2f8fc")
const ICE_LOW := Color("dfeef7")
const POOL := Color("ffffff")
const BLURB := Color("62758a")

## The picture's scale: the card's height sets it, its width caps it.
func _k() -> float:
	return minf(size.y / H, size.x / W)

## A place given as [in from the right, up from the foot] at H, on the card.
func _at(p: Vector2) -> Vector2:
	var k := _k()
	return Vector2(size.x - p.x * k, size.y - p.y * k)

func _paint(b: Face.Builder) -> void:
	var k := _k()
	var first := b.verts.size()
	b.polygon(ground(), Color.WHITE)
	shade(b, first, ICE_TOP, ICE_LOW, 0.0, size.y)
	var puck := _at(PUCK)
	Scenery.soft_disc(b, puck + Vector2(-20.0, 0.0) * k, 120.0 * k, 70.0 * k, Color(POOL, 0.55))
	_marks(b, k)
	_goal(b, k)
	var ours := _at(OURS)
	var goal := _at(GOAL) + Vector2(-EDGE - SLOT * k * 0.5, 0.0)
	# The trail, fading back toward the mallet that struck it.
	for i in range(TRAIL, 0, -1):
		var t := TRAIL_BACK * float(i) / float(TRAIL)
		b.disc(puck.lerp(ours, t), PUCK_R * k * (1.0 - 0.16 * i), Color(Table.PUCK, 0.2 - 0.05 * i))
	_mallet(b, _at(RIVAL), RIVAL_R * k, Table.SIDE[0][0], Table.SIDE[0][1], Table.SIDE[0][2], true)
	_puck(b, puck, PUCK_R * k)
	if soon:
		_mallet(b, ours, PLAIN_R * k, Table.SIDE[1][0], Table.SIDE[1][1], Table.SIDE[1][2], false)
		return
	_go(b, ours, GO_R * k, (goal - ours).normalized(), k)

## The table's ink, large and faint: the centre line from edge to edge and
## the half of the centre circle on the goal's side.
func _marks(b: Face.Builder, k: float) -> void:
	var ink := Color(Table.INK, MARK_ALPHA)
	var x := size.x - CENTRE * k
	var mid := Vector2(x, _at(GOAL).y)
	var w := MARK_W * k
	b.stroke(PackedVector2Array([Vector2(x, EDGE + 3.0), Vector2(x, size.y - EDGE - 3.0)]), w, ink, false, false)
	b.stroke(Face.Builder.arc_points(mid, CIRCLE * k, -PI * 0.5, PI * 0.5), w, ink, false, false)
	b.disc(mid, 5.0 * k, ink)

## The goal in the right edge: the slot, and a length of rail either side.
func _goal(b: Face.Builder, k: float) -> void:
	var mid := _at(GOAL)
	var right := size.x - EDGE
	var rail := RAIL * k
	var mouth := MOUTH * k
	# a warm wash on the ice before the mouth, as the table's lamp gives
	Scenery.soft_disc(b, Vector2(right - 47.0 * k, mid.y), 44.0 * k, mouth * 1.1, Color(Table.LAMP, 0.5))
	b.polygon(PackedVector2Array([Vector2(right - SLOT * k, mid.y - mouth), Vector2(right, mid.y - mouth),
		Vector2(right, mid.y + mouth), Vector2(right - SLOT * k, mid.y + mouth)]), Table.SLOT)
	for way: float in [-1.0, 1.0]:
		var near := mid.y + way * mouth
		var far := near + way * STUB * k
		var top := minf(near, far)
		var at := Vector2(right - rail, top)
		var sz := Vector2(rail, absf(far - near))
		b.polygon(Face.Builder.round_rect(at, sz, rail * 0.3), Table.WOOD_DEEP)
		b.polygon(Face.Builder.round_rect(at + Vector2(0.0, 0.0), sz - Vector2(rail * 0.22, 0.0), rail * 0.3), Table.WOOD)
		b.polygon(Face.Builder.round_rect(at + Vector2(rail * 0.16, sz.y * 0.14), Vector2(rail * 0.22, sz.y * 0.72), rail * 0.1),
			Color(Table.WOOD_LIT, 0.9))
		# the cream lip at the mouth's corner
		b.disc(Vector2(right - rail * 0.5, near), rail * 0.34, Table.LIP)

## The puck, as the table draws it: flat, with one lit arc.
func _puck(b: Face.Builder, at: Vector2, r: float) -> void:
	Scenery.soft_disc(b, at + Vector2(r * 0.14, r * 0.3), r * 1.08, r * 0.9, Table.SHADOW)
	b.disc(at, r, Table.PUCK_DEEP)
	b.disc(at + Table.LIGHT * r * 0.07, r * 0.9, Table.PUCK)
	b.stroke(Face.Builder.arc_points(at + Table.LIGHT * r * 0.07, r * 0.66, PI * 0.95, PI * 1.55), maxf(1.6, r * 0.1),
		Color(Table.PUCK_LIT, 0.95), false, true)

## A mallet of the table's: the skirt, its lit arc, the well and the knob.
## `sun` studs its skirt the way the first seat's is.
func _mallet(b: Face.Builder, at: Vector2, r: float, body: Color, lit: Color, deep: Color, sun: bool) -> void:
	var light: Vector2 = Table.LIGHT
	Scenery.soft_disc(b, at + Vector2(r * 0.12, r * 0.3), r * 1.08, r * 0.92, Table.SHADOW)
	b.disc(at, r, deep)
	b.disc(at + light * r * 0.06, r * 0.93, body)
	b.stroke(Face.Builder.arc_points(at + light * r * 0.06, r * 0.8, PI * 0.95, PI * 1.55), maxf(2.0, r * 0.07),
		Color(lit, 0.9), false, true)
	if sun:
		for i in 12:
			var ray := Vector2.from_angle(TAU * (i + 0.5) / 12.0)
			b.disc(at + light * r * 0.06 + ray * r * 0.765, r * (0.058 if i % 2 == 0 else 0.04), Color(Table.HALO, 0.8))
	b.disc(at - light * r * 0.05, r * 0.6, deep)
	b.disc(at + light * r * 0.03, r * 0.55, body.darkened(0.06))
	b.disc(at - light * r * 0.14, r * 0.4, Color(deep, 0.8))
	b.disc(at + light * r * 0.1, r * 0.36, deep)
	b.disc(at + light * r * 0.16, r * 0.33, lit)

## The go mallet about `at`: the table's mallet in the card's colour, lifted
## over its shadow, a chevron on its knob pointing along `way`.
func _go(b: Face.Builder, at: Vector2, r: float, way: Vector2, k: float) -> void:
	var light: Vector2 = Table.LIGHT
	var deep := colour.darkened(0.3)
	var lit := colour.lightened(0.3)
	var c := at - Vector2(0.0, GO_LIFT * k)
	Scenery.soft_disc(b, at + Vector2(r * 0.14, r * 0.36), r * 1.12, r * 0.96, Color(Pal.TEXT, GO_SHADOW))
	b.disc(c + Vector2(0.0, r * 0.1), r, deep)
	b.disc(c, r * 0.97, colour)
	b.stroke(Face.Builder.arc_points(c, r * 0.82, PI * 0.95, PI * 1.55), maxf(2.0, r * 0.07), Color(lit, 0.9), false, true)
	b.disc(c - light * r * 0.05, r * 0.62, deep)
	b.disc(c + light * r * 0.03, r * 0.57, colour.darkened(0.08))
	var knob := c + light * r * 0.1
	b.disc(knob - light * r * 0.2, r * 0.46, Color(deep, 0.8))
	b.disc(knob, r * 0.44, colour.lightened(0.12))
	var h := r * 0.2
	var side := way.orthogonal()
	b.stroke(PackedVector2Array([knob - way * h * 0.55 - side * h, knob + way * h * 0.55, knob - way * h * 0.55 + side * h]),
		r * 0.13, Pal.SURFACE)

func _lay() -> void:
	var words := _words(String(entry.get("title", "")), SIDE, size.y * 0.5, WORDS, Pal.TEXT, BLURB)
	words.position.y = roundf(WORDS_TOP * size.y / H)
