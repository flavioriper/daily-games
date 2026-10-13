extends "res://ui/menu/cards/card_face.gd"

## Balance's card: the seesaw in its meadow, a weight short. A pumpkin has
## the plank's low end down on its bale, the brass level over the hub has its
## bubble run to the high side, and over the far cup of that side hangs the
## one weight that would bring the beam level: the go button, a fruit in the
## card's colour with a chevron for a face. The name stands in the sky to the
## left of it all.
##
## The plank, its cups and pips, the level, the hub with its stone keel, the
## trestle and the bales are the board's (puzzles/balance2d.gd's _build_plank,
## _build_keel, _build_still and _build_bale, in its colours); the pumpkin is
## one of the five (ui/faces/fruit.gd) and the only thing here that lives.

const Fruit = preload("res://ui/faces/fruit.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

## The row the card was drawn for (puzzle_card_2d.gd's CARD_H); the meadow
## grows with a taller one.
const H := 246.0
## The picture's margin from the card's right edge and the words' from its left.
const SIDE := 24.0
const TEXT_X := 24.0
## How much grass there is under the sky.
const LAWN_H := 32.0
## The seesaw, at H: a cup's pitch, the plank's half length and half
## thickness, the hub's height over the grass and how far the beam leans
## (left end down). The board's own shares: a plank 0.55 of a cup past its
## last cup and 0.3 thick, a fruit 0.41 of its seat.
const CUP := 36.0
const HALF := 104.0
const TOP := 5.5
const HUB_H := 58.0
const TILT := -0.13
## The share of the card's width the plank may take before it stops growing
## with the card's height, so the words keep their column.
const PLANK_SHARE := 0.45
## The trestle's legs, the keel's rod and its stone.
const LEG_SPLAY := 40.0
const LEG_W := 8.0
const KEEL_L := 30.0
const STONE_R := 11.0
## The level: how far over the plank it rides, its glass, its ticks a side
## and where the bubble has run to, in ticks.
const VIAL_UP := 30.0
const VIAL := Vector2(64.0, 11.0)
const VIAL_TICKS := 5
const BUBBLE := 3.4
## The pumpkin's seat and cup, and the go weight's radius, cup and hover.
const SEAT := 54.0
const HEAVY := 2
const HEAVY_CUP := -2
const GO_R := 26.0
const GO_CUP := 2
const GO_HOVER := 5.0
## A bale: its width, and how far in from the plank's end it stands.
const BALE_W := 38.0
const BALE_IN := 14.0

func _k() -> float:
	return size.y / H

## The seesaw's own scale: the card's, unless that would run the plank into
## the words' column.
func _ks() -> float:
	return minf(_k(), size.x * PLANK_SHARE / (HALF * 2.0))

func _ground() -> float:
	return size.y - LAWN_H * _k()

func _pivot() -> Vector2:
	var s := _ks()
	return Vector2(size.x - SIDE - HALF * s, _ground() - HUB_H * s)

## The plank's frame: x along it, y down, the hub at the origin.
func _plank_xf() -> Transform2D:
	return Transform2D(TILT, _pivot())

## The middle of the go weight, hanging over its cup.
func _go_at() -> Vector2:
	var s := _ks()
	return _plank_xf() * Vector2(GO_CUP * CUP * s, -(TOP + GO_R + GO_HOVER) * s)

func _paint(b: Face.Builder) -> void:
	var k := _k()
	var s := _ks()
	var paper := ground()
	var ground_y := _ground()
	var pivot := _pivot()
	# The sky, two far hills on it and a cloud.
	var first := b.verts.size()
	b.polygon(paper, Color.WHITE)
	shade(b, first, Pal.SKY_TOP, Pal.SKY_HORIZON.lerp(Pal.SUN_TILE, 0.45), 0.0, ground_y)
	for hill: Array in [[0.16, 0.46, 46.0, 0.45], [0.80, 0.42, 34.0, 0.3]]:
		var far := Face.Builder.ring(Vector2(size.x * hill[0], ground_y + 8.0 * k), size.x * hill[1], hill[2] * k)
		for part in Geometry2D.intersect_polygons(paper, far):
			b.polygon(part, Pal.LAWN.lerp(Pal.SKY_HORIZON, hill[3]))
	Scenery.cloud(b, Vector2(pivot.x - HALF * s * 0.62, 34.0 * k), 13.0 * k, Color(Pal.PAPER, 0.9))
	# The meadow, its edge, tufts and a few flowers.
	for part in Geometry2D.intersect_polygons(paper, _band(ground_y, size.y + 8.0)):
		first = b.verts.size()
		b.polygon(part, Color.WHITE)
		shade(b, first, Pal.LAWN, Pal.LAWN_DEEP, ground_y, size.y)
	b.polygon(Face.Builder.round_rect(Vector2(EDGE, ground_y - 2.0), Vector2(size.x - EDGE * 2.0, 5.0), 2.5),
		Pal.LAWN_DEEP.lerp(Pal.LAWN, 0.4))
	for x: float in [0.09, 0.33, 0.52, 0.95]:
		Scenery.tuft(b, Vector2(size.x * x, ground_y + 5.0 * k), 11.0 * k)
	for fl: Array in [[0.06, 0.55, Pal.FLOWER], [0.20, 0.42, Pal.PAPER], [0.40, 0.62, Pal.SUN], [0.47, 0.36, Pal.FLOWER]]:
		_flower(b, Vector2(size.x * fl[0], ground_y + LAWN_H * k * fl[1]), 4.2 * k, fl[2])
	# The shadows on the grass, then the bales: the low end lies on its own.
	Scenery.soft_disc(b, Vector2(pivot.x, ground_y + 4.0 * s), HALF * s * 0.95, 7.0 * s, Color(Pal.TEXT, 0.12))
	var rest := (HALF - BALE_IN) * s
	var bale_top := pivot.y + rest * sin(-TILT) + TOP * s * cos(TILT) + 1.0
	for side: float in [-1.0, 1.0]:
		_bale(b, Vector2(pivot.x + side * rest * cos(TILT), ground_y + 4.0 * s), ground_y + 4.0 * s - bale_top, s)
	# The trestle: two splayed legs and a cross bar, feet in the grass.
	for side: float in [-1.0, 1.0]:
		var foot := Vector2(pivot.x + side * LEG_SPLAY * s, ground_y + 3.0 * s)
		b.stroke(PackedVector2Array([pivot, foot]), LEG_W * s, Pal.SCALE_DEEP)
		b.stroke(PackedVector2Array([pivot.lerp(foot, 0.15), foot]), LEG_W * s * 0.35, Pal.SCALE_WOOD.lerp(Pal.SCALE_DEEP, 0.3))
	var bar_y := lerpf(pivot.y, ground_y, 0.62)
	b.stroke(PackedVector2Array([Vector2(pivot.x - LEG_SPLAY * s * 0.62, bar_y), Vector2(pivot.x + LEG_SPLAY * s * 0.62, bar_y)]),
		LEG_W * s * 0.7, Pal.SCALE_DEEP)
	# The keel and the plank, in the plank's frame and leaning with it.
	var beam := Face.Builder.new()
	_keel(beam, s)
	_plank(beam, s)
	b.append(beam.mesh(), _plank_xf())
	if not soon:
		_go(b, _go_at(), GO_R * s)

## A band of the card from `y0` to `y1`, wider than the paper it is cut by.
func _band(y0: float, y1: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(-8.0, y0), Vector2(size.x + 8.0, y0),
		Vector2(size.x + 8.0, y1), Vector2(-8.0, y1)])

## A meadow flower of five petals.
func _flower(b: Face.Builder, at: Vector2, r: float, petal: Color) -> void:
	for i in 5:
		b.disc(at + Vector2.from_angle(i * TAU / 5.0 - PI * 0.5) * r * 0.75, r * 0.55, petal)
	b.disc(at, r * 0.42, Pal.SUN_DEEP)

## A straw bale `h` tall standing on `foot`, with its two straps.
func _bale(b: Face.Builder, foot: Vector2, h: float, s: float) -> void:
	var w := BALE_W * s
	var at := foot + Vector2(-w * 0.5, -h)
	Scenery.soft_disc(b, foot, w * 0.7, 5.0 * s, Color(Pal.TEXT, 0.14))
	b.polygon(Face.Builder.round_rect(at, Vector2(w, h), 5.0 * s), Pal.STRAW)
	b.polygon(Face.Builder.round_rect(at, Vector2(w, h * 0.3), 4.5 * s), Pal.STRAW.lerp(Pal.PAPER, 0.35))
	for i in 2:
		var x := -w * 0.22 + i * w * 0.44
		b.polygon(Face.Builder.round_rect(at + Vector2(w * 0.5 + x - 1.5 * s, 0.0), Vector2(3.0 * s, h), 1.5 * s), Pal.STRAP)

## The rod under the hub and the stone lashed to it, which is what swings a
## free beam back to a reading.
func _keel(b: Face.Builder, s: float) -> void:
	var end := Vector2(0.0, KEEL_L * s)
	var r := STONE_R * s
	b.stroke(PackedVector2Array([Vector2.ZERO, end]), 3.4 * s, Pal.SCALE_DARK)
	b.ellipse(end + Vector2(0.0, r * 0.1), r * 1.12, r, Pal.BOULDER)
	b.ellipse(end + Vector2(-r * 0.2, -r * 0.2), r * 0.7, r * 0.55, Pal.BOULDER.lerp(Pal.PAPER, 0.25))
	b.ellipse(end + Vector2(-r * 0.35, -r * 0.42), r * 0.28, r * 0.16, Color(Pal.PAPER, 0.5))
	b.polygon(Face.Builder.round_rect(end + Vector2(-r * 0.5, -r * 0.95), Vector2(r, r * 0.3), r * 0.12), Pal.ROPE_HEMP)

## The plank: the board, its lower edge in shade, a lip and the distance pips
## at every cup, the level's bracket, glass and bubble, and the hub.
func _plank(b: Face.Builder, s: float) -> void:
	var half := HALF * s
	var top := TOP * s
	b.polygon(Face.Builder.round_rect(Vector2(-half, -top), Vector2(half * 2.0, top * 2.0), top * 0.7), Pal.SCALE_WOOD)
	b.polygon(Face.Builder.round_rect(Vector2(-half, top * 0.25), Vector2(half * 2.0, top * 0.75), top * 0.5), Pal.SCALE_DEEP)
	b.stroke(PackedVector2Array([Vector2(-half * 0.92, -top * 0.3), Vector2(-half * 0.35, -top * 0.42)]), 1.6 * s, Color(Pal.SCALE_DARK, 0.25))
	b.stroke(PackedVector2Array([Vector2(half * 0.2, -top * 0.25), Vector2(half * 0.85, -top * 0.38)]), 1.6 * s, Color(Pal.SCALE_DARK, 0.25))
	var lip := Vector2(CUP * 0.74, 4.4) * s
	var pip := 1.7 * s
	for x: int in [-2, -1, 1, 2]:
		var cx := x * CUP * s
		if x == GO_CUP and not soon:
			# The cup the weight hangs over, lit as the board lights an aim.
			Scenery.soft_disc(b, Vector2(cx, -top - 2.0 * s), GO_R * s * 1.15, 7.0 * s, Color(Pal.SUN, 0.5))
		b.polygon(Face.Builder.round_rect(Vector2(cx - lip.x * 0.5, -top - lip.y * 0.5), lip, lip.y * 0.5),
			Pal.SCALE_WOOD.lerp(Pal.SCALE_DEEP, 0.45))
		b.polygon(Face.Builder.round_rect(Vector2(cx - lip.x * 0.42, -top - lip.y * 0.5), Vector2(lip.x * 0.84, lip.y * 0.36), lip.y * 0.18),
			Pal.SCALE_WOOD.lerp(Pal.PAPER, 0.2))
		for i in absi(x):
			b.disc(Vector2(cx + (i - (absi(x) - 1) * 0.5) * pip * 2.8, top * 0.55), pip, Pal.SCALE_DARK)
	# The level.
	var vy := -(top + VIAL_UP * s)
	var v := VIAL * s
	b.polygon(Face.Builder.round_rect(Vector2(-2.2 * s, vy), Vector2(4.4 * s, -vy - top * 0.5), 1.5 * s), Pal.SCALE_DEEP)
	b.polygon(Face.Builder.round_rect(Vector2(-v.x * 0.5 - 4.0 * s, vy - v.y * 0.5 - 4.0 * s), v + Vector2(8.0, 8.0) * s, v.y * 0.5 + 4.0 * s), Pal.BRASS_DEEP)
	b.polygon(Face.Builder.round_rect(Vector2(-v.x * 0.5 - 2.0 * s, vy - v.y * 0.5 - 2.0 * s), v + Vector2(4.0, 4.0) * s, v.y * 0.5 + 2.0 * s), Pal.BRASS)
	b.polygon(Face.Builder.round_rect(Vector2(-v.x * 0.5, vy - v.y * 0.5), v, v.y * 0.5), Pal.DEW.lerp(Pal.LEAF_LIGHT, 0.35))
	var tick := (v.x * 0.5 - v.y * 0.5) / (VIAL_TICKS + 0.6)
	for i in range(-VIAL_TICKS, VIAL_TICKS + 1, 5):
		var tall := 0.62 if i == 0 else 0.42
		b.polygon(Face.Builder.round_rect(Vector2(i * tick - 0.8 * s, vy + v.y * 0.5 - v.y * tall), Vector2(1.6 * s, v.y * tall), 0.8 * s),
			Color(Pal.TEXT, 0.6 if i == 0 else 0.35))
	var bubble := Vector2(BUBBLE * tick, vy)
	b.ellipse(bubble, v.y * 0.62, v.y * 0.34, Color(Pal.PAPER, 0.92))
	b.ellipse(bubble + Vector2(-v.y * 0.18, -v.y * 0.1), v.y * 0.22, v.y * 0.1, Color(1.0, 1.0, 1.0, 0.95))
	# The hub.
	b.disc(Vector2.ZERO, 6.0 * s, Pal.SCALE_DARK)
	b.disc(Vector2.ZERO, 3.0 * s, Pal.BRASS)
	b.disc(Vector2(-0.8, -1.0) * s, 1.1 * s, Pal.BRASS_HI)

## The go weight: a round fruit in the card's colour under a bark stalk with
## one leaf, a chevron where the five have a face.
func _go(b: Face.Builder, at: Vector2, r: float) -> void:
	var stalk := at + Vector2(r * 0.04, -r * 0.86)
	b.stroke(Face.Builder.bezier2(stalk, stalk + Vector2(r * 0.02, -r * 0.26), stalk + Vector2(r * 0.2, -r * 0.4), 6), r * 0.13, Pal.BARK)
	b.ellipse(stalk + Vector2(r * 0.42, -r * 0.2), r * 0.26, r * 0.13, Pal.LEAF_DEEP)
	b.disc(at + Vector2(0.0, r * 0.1), r, colour.darkened(0.22))
	b.disc(at, r, colour)
	b.ellipse(at + Vector2(-r * 0.36, -r * 0.5), r * 0.3, r * 0.15, Color(1.0, 1.0, 1.0, 0.3))
	var mid := at + Vector2(r * 0.05, r * 0.04)
	var c := r * 0.36
	b.stroke(PackedVector2Array([mid + Vector2(-c * 0.55, -c), mid + Vector2(c * 0.55, 0.0),
		mid + Vector2(-c * 0.55, c)]), r * 0.24, Pal.SURFACE)

func _lay() -> void:
	var s := _ks()
	# The pumpkin, seated in its cup and leaning with the plank.
	var seat := SEAT * s
	var face: Control = Fruit.make(HEAVY, seat, _plank_xf() * Vector2(HEAVY_CUP * CUP * s, -TOP * s - seat * 0.41))
	face.shadowless = true
	face.rotation = TILT
	_keep(face)
	face.set_idle(true)
	var room := _pivot().x - HALF * s - TEXT_X - 6.0
	_words(String(entry.get("title", "")), TEXT_X, _ground() * 0.5 + 2.0, room)
