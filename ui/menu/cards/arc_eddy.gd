extends "res://ui/menu/cards/card_face.gd"

## Eddy's card: the pond from above, and the pond is the paper. A light
## blue-green water lies over the whole card with a few ripples on it and one
## lily pad cut by the foot. On the right, low of centre, the whirlpool
## turns in the game's own drawing (arcade/eddy_art.gd's streaks and funnel)
## on a deeper pool of water, and three of the game's small things ride its
## one spiral in, the smallest nearest the eye: a petal, an acorn, a leaf.
## A duckling sits apart to the left, swimming off: at this level the mouth
## does not take her, and `_takes` asks the game's own rule (eddy_sim.gd's
## `grip_of`) rather than trusting the picture. Everything afloat is drawn
## to the scale the core is.
##
## The go button is the whirlpool's eye, the thing the player steers: a disc
## in the card's colour over the pit, lifted, with a chevron. Before the
## card opens the eye is the game's plain dark pit.
##
## Everything is one mesh. Nothing lives on the card and it writes no string.

const Art = preload("res://arcade/eddy_art.gd")
const Sim = preload("res://arcade/eddy_sim.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

## The row the card was drawn for (puzzle_card_2d.gd's CARD_H).
const H := 246.0
## The words end here, and the picture reaches this far in from the card's
## right side at H: the width caps the scale by the two.
const WORDS_END := 237.0
const REACH := 250.0
## The whirlpool: its level, its core in pixels at H, and where its middle
## stands as [in from the right, down].
const LEVEL := 2
const CORE := 26.0
const POOL_AT := Vector2(150.0, 138.0)
## The deeper water under it, in cores across and down.
const POOL := Vector2(3.7, 3.0)
## What rides the spiral, each [kind, look, how far out in cores, the angle
## it stands at], the smallest nearest the eye.
const RIDERS := [
	[Sim.Kind.PETAL, 0, 1.62, 0.55],
	[Sim.Kind.ACORN, 0, 2.3, 2.45],
	[Sim.Kind.LEAF, 1, 3.0, 4.35],
]
## The one too big for the mouth: where she sits as [in from the right,
## down] at H, and the way she swims.
const BIG := Sim.Kind.DUCK
const BIG_AT := Vector2(252.0, 198.0)
const BIG_TURN := 2.95
## The go eye in cores, how far it is lifted at H, and its shadow.
const EYE := 0.86
const EYE_LIFT := 3.0
const EYE_SHADOW := 0.26
## The lily pad: its middle from the card's left and how far under the foot
## it lies, its radius, and the way its notch points.
const PAD_AT := Vector2(74.0, 6.0)
const PAD_R := 38.0
const PAD_TURN := -0.9
## Ripples, each [x, y, radius] at H; a negative x is counted in from the
## right.
const RIPPLES := [[150.0, 196.0, 15.0], [-36.0, 226.0, 12.0], [-232.0, 92.0, 11.0]]
## The words' margin, their room and how far down they start.
const SIDE := 22.0
const WORDS := 215.0
const WORDS_TOP := 14.0

## The pond, lightened from the game's so the words read on it, and the
## blurb's ink.
const POND_TOP := Color("dff1ee")
const POND_LOW := Color("bfe1e0")
const BLURB := Color("4d6e72")

func _kh() -> float:
	return size.y / H

## The picture's scale: the card's height sets it, its width caps it.
func _k() -> float:
	return minf(_kh(), (size.x - WORDS_END) / REACH)

## The whirlpool's middle.
func _eye() -> Vector2:
	return Vector2(size.x - POOL_AT.x * _k(), POOL_AT.y * _kh())

## Pixels a pond unit: the core drawn is the core the level has.
func _unit() -> float:
	return CORE * _k() / Sim.core_of(LEVEL)

## Whether the mouth at this card's level takes `kind`, by the game's rule.
static func _takes(kind: int) -> bool:
	return Sim.grip_of(kind, LEVEL) >= 1.0

## `shape` where it lies on the paper, in `colour`.
func _on_paper(b: Face.Builder, shape: PackedVector2Array, colour: Color) -> void:
	for piece: PackedVector2Array in Geometry2D.intersect_polygons(shape, ground()):
		b.polygon(piece, colour)

func _paint(b: Face.Builder) -> void:
	var k := _k()
	var kh := _kh()
	var r := CORE * k
	var u := _unit()
	var first := b.verts.size()
	b.polygon(ground(), Color.WHITE)
	shade(b, first, POND_TOP, POND_LOW, 0.0, size.y)
	for row: Array in RIPPLES:
		var x := float(row[0]) * k if float(row[0]) >= 0.0 else size.x + float(row[0]) * k
		_ripple(b, Vector2(x, float(row[1]) * kh), float(row[2]) * k)
	_pad(b, Vector2(PAD_AT.x * kh, size.y + PAD_AT.y * kh), PAD_R * kh)
	# The deeper water the whirlpool turns in, its streaks, then its mouth.
	var eye := _eye()
	Scenery.soft_disc(b, eye, POOL.x * r, POOL.y * r, Color(Art.WATER, 0.62))
	Scenery.soft_disc(b, eye, POOL.x * r * 0.6, POOL.y * r * 0.6, Color(Art.WATER_LOW, 0.4))
	b.append(Art.streaks(r), Transform2D(0.0, eye))
	var mouth := Face.Builder.new()
	Art.funnel_into(mouth, r)
	b.append(mouth.mesh(), Transform2D(0.0, eye))
	# What it is taking, each lying along the water's turn.
	for row: Array in RIDERS:
		var kind := int(row[0])
		if not _takes(kind):
			continue
		var at := eye + Vector2.from_angle(float(row[3])) * float(row[2]) * r
		_afloat(b, kind, int(row[1]), at, float(row[3]) - PI * 0.5 - 0.35, u)
	# And what it cannot yet: she sits apart.
	if not _takes(BIG):
		_afloat(b, BIG, 0, Vector2(size.x - BIG_AT.x * k, BIG_AT.y * kh), BIG_TURN, u)
	if not soon:
		_go(b, eye, r, kh)

## One of the game's things afloat at `at`: the water darker round it and a
## thread of light where it sits, as the game lays them, then the thing.
func _afloat(b: Face.Builder, kind: int, look: int, at: Vector2, turn: float, u: float) -> void:
	var s := float(Sim.KINDS[kind].r) * Art.DRAWN * u
	b.disc(at, s * 1.15, Color(Art.WATER_DEEP, 0.2))
	b.stroke(Face.Builder.ring(at, s * 1.08, s * 1.08), maxf(1.0, s * 0.05), Color(Art.FOAM, 0.4), true)
	Art.thing_into(b, kind, look, s, at, turn)

## The go eye about `at`: a disc in the card's colour over the pit, lifted
## over its own shadow, with a chevron.
func _go(b: Face.Builder, at: Vector2, r: float, kh: float) -> void:
	var rr := EYE * r
	var up := at - Vector2(0.0, EYE_LIFT * kh)
	Scenery.soft_disc(b, at + Vector2(0.0, rr * 0.34), rr * 1.12, rr * 0.9, Color(Art.WATER_PIT, EYE_SHADOW))
	b.disc(up + Vector2(0.0, rr * 0.16), rr, colour.darkened(0.26))
	b.disc(up, rr, colour)
	b.ellipse(up - Vector2(0.0, rr * 0.42), rr * 0.62, rr * 0.3, Color(Pal.SURFACE, 0.16))
	var h := rr * 0.38
	b.stroke(PackedVector2Array([up + Vector2(-h * 0.55, -h), up + Vector2(h * 0.55, 0.0), up + Vector2(-h * 0.55, h)]),
		rr * 0.24, Pal.SURFACE)

## A ripple about `at`: two shallow arcs of foam, one inside the other.
func _ripple(b: Face.Builder, at: Vector2, r: float) -> void:
	b.stroke(Face.Builder.arc_points(at, r, PI * 1.15, PI * 1.85), maxf(1.5, r * 0.13), Color(Art.FOAM, 0.7))
	b.stroke(Face.Builder.arc_points(at + Vector2(0.0, r * 0.1), r * 0.55, PI * 1.2, PI * 1.8), maxf(1.2, r * 0.11),
		Color(Art.FOAM, 0.5))

## The lily pad about `at`, the game's own pad with its notch, as much of it
## as lies on the paper.
func _pad(b: Face.Builder, at: Vector2, r: float) -> void:
	_on_paper(b, _wedge(at + Vector2(0.0, 0.14 * r), r * 1.04, 0.25), Color(Art.WATER_DEEP, 0.4))
	_on_paper(b, _wedge(at, r, 0.25), Art.PAD_DEEP)
	_on_paper(b, _wedge(at, r * 0.86, 0.3), Art.PAD)
	var sheen := Face.Builder.ring(at + Vector2.from_angle(PAD_TURN + PI) * r * 0.3 - Vector2(0.0, 0.34 * r), r * 0.36, r * 0.16)
	_on_paper(b, sheen, Color(Art.PAD_HI, 0.8))

## A disc about `at` with a notch `gap` radians either side of PAD_TURN.
func _wedge(at: Vector2, r: float, gap: float) -> PackedVector2Array:
	var pts := PackedVector2Array([at])
	pts.append_array(Face.Builder.arc_points(at, r, PAD_TURN + gap, PAD_TURN + TAU - gap))
	return pts

func _lay() -> void:
	var words := _words(String(entry.get("title", "")), SIDE, size.y * 0.5, WORDS, Pal.TEXT, BLURB)
	words.position.y = roundf(WORDS_TOP * _kh())
