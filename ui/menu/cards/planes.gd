extends "res://ui/menu/cards/card_face.gd"

## Paper Planes' card: a pale morning sky with no board on it at all. Three
## of the board's folded planes lie over the lower and right parts of the
## card, each on its own dotted lane that runs the paper edge to edge, so the
## lanes cross the whole card as a faint lattice. Only one of them may go, as
## the board rules it: the short plane heading down has the go plane's body
## across its lane, the bent one heading left has the short one across its
## own, and the big one along the foot has nothing ahead of it but sky. It is
## the go button: a plane in the card's colour, larger and lifted, the dots
## ahead of it lit and three chevrons leading off the right edge. The name
## stands top left and the top right corner is left to the seal.
##
## Everything is one mesh and nothing lives on it. The grooves and the two
## blocked darts are `ui/faces/paper_plane.gd`'s own; the go dart is the same
## fold redrawn here because the board's takes a colour by index only.

const PaperPlane = preload("res://ui/faces/paper_plane.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

## The row the card was drawn for (puzzle_card_2d.gd's CARD_H).
const H := 246.0
## A blocked plane's cell at H (its dart is 0.82 of it long), the go plane's,
## and the pitch of a lane's dots.
const CELL := 60.0
const GO_CELL := 80.0
const PITCH := 30.0
## How much the go dart is lifted.
const GO_LIFT := 0.35
## The planes, every point as [how far in from the card's right side, how far
## down] at H, head first. `turn` is the heading in quarter turns clockwise
## from east; `paper` the board's colour index.
const GO := {"pts": [Vector2(122.0, 196.0), Vector2(300.0, 196.0)], "turn": 0, "paper": 1}
const BLOCKED := [
	# Heading down onto the go plane's body.
	{"pts": [Vector2(190.0, 148.0), Vector2(190.0, 104.0)], "turn": 1, "paper": 2},
	# Heading left onto the short one's body, its tail turned up the side.
	{"pts": [Vector2(112.0, 128.0), Vector2(44.0, 128.0), Vector2(44.0, 90.0)], "turn": 2, "paper": 0},
]
## The words' margin and how far down they start.
const SIDE := 22.0
const WORDS_TOP := 14.0
## The room the words take from the card's top left corner, under WORDS_TOP.
const WORDS_CLEAR := Vector2(262.0, 132.0)
## How far a lane's dots keep from the paper's edge, and from the seal.
const DOT_EDGE := 9.0
## A lane's dot, a share of the cell, and its ink's alpha (the board's empty
## cells wore these until 2026-10-26).
const LANE_DOT := 0.05
const LANE_ALPHA := 0.45
const SEAL_CLEAR := SEAL_IN + SEAL_R + 10.0

const SKY_TOP := Color("cbe4f1")
const SKY_LOW := Color("fdf5e4")
const CLOUD := Color(1.0, 1.0, 1.0, 0.62)
## The clouds, as [x in the card's width, y at H, half width at H].
const CLOUDS := [[0.6, 44.0, 44.0], [0.13, 170.0, 34.0]]
const BLURB := Color("6d7480")

func _k() -> float:
	return size.y / H

## A point given from the card's right side at H, in this card's pixels.
func _pt(p: Vector2) -> Vector2:
	return Vector2(size.x - p.x * _k(), p.y * _k())

func _pts(plane: Dictionary) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: Vector2 in plane["pts"]:
		out.append(_pt(p))
	return out

static func _heading(plane: Dictionary) -> Vector2:
	return Vector2.from_angle(float(plane["turn"]) * PI * 0.5)

func _paint(b: Face.Builder) -> void:
	var k := _k()
	var paper := ground()
	var first := b.verts.size()
	b.polygon(paper, Color.WHITE)
	shade(b, first, SKY_TOP, SKY_LOW, 0.0, size.y)
	for cloud in CLOUDS:
		_cloud(b, Vector2(size.x * float(cloud[0]), float(cloud[1]) * k), float(cloud[2]) * k)
	# The lanes, edge to edge, under everything that lies on them.
	var planes: Array = BLOCKED.duplicate()
	if not soon:
		planes.append(GO)
	for plane: Dictionary in planes:
		_lane(b, paper, _pt(plane["pts"][0]), _heading(plane), Color(Pal.LINE, LANE_ALPHA),
			LANE_DOT * CELL * k * 1.3)
	# The bodies, then the darts over every body.
	var cell := CELL * k
	for plane: Dictionary in BLOCKED:
		PaperPlane.trail(b, _pts(plane), cell, int(plane["paper"]))
	if not soon:
		_go_lane(b)
		PaperPlane.trail(b, _pts(GO), GO_CELL * k, int(GO["paper"]))
	for plane: Dictionary in BLOCKED:
		PaperPlane.dart(b, _pt(plane["pts"][0]), float(plane["turn"]) * PI * 0.5, cell, int(plane["paper"]))
	if not soon:
		_go_dart(b, _pt(GO["pts"][0]), GO_CELL * k)

## Dots along the line through `at` in `dir`, both ways, as far as the paper
## runs, clear of the seal's corner.
func _lane(b: Face.Builder, paper: PackedVector2Array, at: Vector2, dir: Vector2, ink: Color, r: float) -> void:
	var step := PITCH * _k()
	var reach := int(ceil((size.x + size.y) / step))
	var inner := Rect2(Vector2.ONE * DOT_EDGE, size - Vector2.ONE * DOT_EDGE * 2.0)
	var seal := seal_centre()
	var clear := SEAL_CLEAR - SEAL_IN
	# No dot under the name or the blurb, which keep their size on any card.
	var words := Rect2(0.0, 0.0, WORDS_CLEAR.x, roundf(WORDS_TOP * _k()) + WORDS_CLEAR.y)
	for i in range(-reach, reach + 1):
		var p := at + dir * (step * (float(i) + 0.5))
		if not inner.has_point(p) or not Geometry2D.is_point_in_polygon(p, paper):
			continue
		if p.distance_to(seal) < clear or words.has_point(p):
			continue
		b.disc(p, r, ink)

## The way ahead of the go plane: its dots lit in the card's colour, and
## three chevrons leading off the right edge.
func _go_lane(b: Face.Builder) -> void:
	var k := _k()
	var head := _pt(GO["pts"][0])
	var from := head.x + GO_CELL * k * 0.62
	var room := size.x - DOT_EDGE - from
	var h := 7.0 * k
	for i in 3:
		var x := from + room * (0.2 + 0.3 * float(i))
		b.stroke(PackedVector2Array([Vector2(x - h * 0.6, head.y - h), Vector2(x + h * 0.6, head.y),
			Vector2(x - h * 0.6, head.y + h)]), 4.0 * k, Color(colour, 0.95 - 0.25 * float(i)))

## The board's dart at `head`, heading east, in the card's colour, lifted:
## paper_plane.gd's fold with the two papers given rather than indexed.
func _go_dart(b: Face.Builder, head: Vector2, cell: float) -> void:
	var s := cell * (1.0 + 0.16 * GO_LIFT)
	var tip := head + Vector2(PaperPlane.TIP, 0.0) * s
	var right := head + Vector2(-PaperPlane.BACK, PaperPlane.WING) * s
	var notch := head + Vector2(-PaperPlane.NOTCH, 0.0) * s
	var left := head + Vector2(-PaperPlane.BACK, -PaperPlane.WING) * s
	var fall := PaperPlane.SHADOW * cell * (1.0 + PaperPlane.SHADOW_FALL * GO_LIFT)
	Scenery.soft_disc(b, head + fall + Vector2(0.0, s * 0.06), s * 0.52, s * 0.2, Color(Pal.TEXT, 0.12))
	b.polygon(PackedVector2Array([tip + fall, right + fall, notch + fall, left + fall]),
		Color(Pal.TEXT, PaperPlane.SHADOW_ALPHA * 0.8))
	# The light stands up and to the left, so the upper wing is the lit one.
	b.polygon(PackedVector2Array([tip, notch, left]), colour.lerp(Pal.SURFACE, 0.3))
	b.polygon(PackedVector2Array([tip, right, notch]), colour.lerp(Pal.TEXT, 0.12))
	var keel := head + Vector2(-PaperPlane.NOTCH + 0.02, 0.0) * s
	b.polygon(PackedVector2Array([notch.lerp(tip, 0.28), keel + Vector2(0.0, 0.035) * s,
		keel + Vector2(0.0, -0.035) * s]), colour.lerp(Pal.TEXT, 0.3))
	b.stroke(PackedVector2Array([tip.lerp(notch, 0.08), tip.lerp(notch, 0.8)]), maxf(1.2, 0.028 * cell),
		Color(Pal.SURFACE, 0.8), false, false)

## A flat cloud about `at`, `w` to either side.
func _cloud(b: Face.Builder, at: Vector2, w: float) -> void:
	var h := w * 0.3
	b.polygon(Face.Builder.round_rect(at - Vector2(w, 0.0), Vector2(w * 2.0, h), h * 0.5), CLOUD)
	b.disc(at + Vector2(-w * 0.3, 0.0), h * 0.9, CLOUD)
	b.disc(at + Vector2(w * 0.25, -h * 0.1), h * 1.15, CLOUD)

func _lay() -> void:
	var room := size.x - SIDE - (SEAL_IN + SEAL_R + 10.0)
	var words := _words(String(entry.get("title", "")), SIDE, size.y * 0.5, room, Pal.TEXT, BLURB)
	words.position.y = roundf(WORDS_TOP * _k())
