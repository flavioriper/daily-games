extends "res://ui/menu/cards/card_face.gd"

## Nightlight's card: one body in space. A deep plum night over the whole
## paper with a dusting of far stars, thinner behind the words, and the star
## itself low on the right: the sky's own star standing still (its limb, its
## colour and the pale heart of dabs run together, as arcade/nightlight_art.gd
## lays it), a soft light round it with no shape, the gas winding in round it
## as the game's ring does, and two small worlds lit from it on one faint
## orbit. No ranks, no ground: Firefly is the tab's other night.
##
## The go button is the star: it is what the player presses and feeds, so it
## wears the card's colour and the chevron. Not open yet, it is the sky's
## plain star, small. The name stands top left in cream; the line under it is
## the star as it is kept, set from outside.
##
## Everything is one mesh and nothing lives on the card.

const NightArt = preload("res://arcade/nightlight_art.gd")
const NightSim = preload("res://arcade/nightlight_sim.gd")
const Motes = preload("res://ui/motes.gd")

## The row the card was drawn for (puzzle_card_2d.gd's CARD_H).
const H := 246.0
## The star's middle, in from the card's right side and up from its foot, its
## radius open and not yet open, and how far its light reaches.
const STAR_IN := Vector2(122.0, 104.0)
const STAR_R := 42.0
const STAR_PLAIN := 24.0
const LIGHT := 92.0
## The gas: how many puffs, the ring's radius where it starts and ends, the
## puff's size at each end.
const PUFFS := 20
const GAS_FROM := 82.0
const GAS_TO := 58.0
const PUFF_FROM := 10.0
const PUFF_TO := 6.0
## The orbit: its half axes, its tilt, and the worlds on it as [angle,
## radius, kind].
const ORBIT := Vector2(96.0, 30.0)
const TILT := -0.2
const WORLDS := [[2.75, 8.0, NightSim.Kind.GIANT], [0.5, 5.0, NightSim.Kind.ROCK]]
## The far stars: how many are tried, and the room kept thin round the words.
const FAR := 54
const WORDS_ROOM := Vector2(250.0, 176.0)
## The picture's reach left of the card's right side, and where the words end:
## the width caps the scale so the one never runs under the other.
const REACH := 222.0
const WORDS_END := 244.0
## The words' margin, their room and how far down they start.
const SIDE := 22.0
const WORDS := 215.0
const WORDS_TOP := 14.0

## The night, a paler pool behind the star, the far stars and the inks.
const NIGHT_TOP := Color("2a2440")
const NIGHT_LOW := Color("3b3158")
const POOL := Color("5a4a80")
const FAR_STAR := Color("fff0d8")
const INK := Color("fff3dc")
const INK_DIM := Color("d8cbe6")

func _h() -> float:
	return size.y / H

## The picture's scale: the card's height sets it, its width caps it.
func _k() -> float:
	return minf(size.y / H, maxf(size.x - WORDS_END, 1.0) / REACH)

func _star() -> Vector2:
	return size - STAR_IN * _k()

func _paint(b: Face.Builder) -> void:
	var k := _k()
	var paper := ground()
	var first := b.verts.size()
	b.polygon(paper, Color.WHITE)
	shade(b, first, NIGHT_TOP, NIGHT_LOW, 0.0, size.y)
	var star := _star()
	_far(b, paper, star, k)
	Motes.glow(b, star, LIGHT * k, Color(POOL, 0.55), 1.4)
	# The orbit's far half, then the gas and the star, then its near half, so
	# the worlds pass behind and before.
	_orbit(b, star, k, true)
	for i in PUFFS:
		var t := float(i) / (PUFFS - 1)
		var at := star + Vector2.from_angle(-0.5 + i * 0.31) * lerpf(GAS_FROM, GAS_TO, t) * k
		NightArt.lay_puff(b, at, lerpf(PUFF_FROM, PUFF_TO, t) * k, Color(NightArt.GAS.lerp(NightArt.WARM, t), 0.7))
	if soon:
		_body(b, star, STAR_PLAIN * k, NightArt.star_col(5800.0))
	else:
		_body(b, star, STAR_R * k, colour)
		var h := STAR_R * k * 0.34
		b.stroke(PackedVector2Array([star + Vector2(-h * 0.5, -h), star + Vector2(h * 0.6, 0.0), star + Vector2(-h * 0.5, h)]),
			STAR_R * k * 0.2, Pal.SURFACE)
	_orbit(b, star, k, false)

## The star `r` in radius: a light with no edge, the deeper limb, its own
## colour and the pale heart of dabs run together.
func _body(b: Face.Builder, at: Vector2, r: float, col: Color) -> void:
	Motes.glow(b, at, minf(r * 2.1, LIGHT * _k()), Color(col.lerp(NightArt.WARM, 0.4), 0.5), 2.0)
	b.disc(at, r, Color(col.r * 0.9, col.g * 0.72, col.b * 0.6))
	b.disc(at + Vector2(-0.02, -0.03) * r, r * 0.88, col)
	var pale := col.lerp(NightArt.HEART, 0.55)
	for dab: Array in [[Vector2(-0.46, -0.4), 0.26], [Vector2(-0.2, -0.56), 0.2], [Vector2(-0.58, -0.12), 0.16]]:
		b.disc(at + (dab[0] as Vector2) * r, float(dab[1]) * r, Color(pale, 0.85))

## A place on the orbit at `angle`.
func _on_orbit(star: Vector2, k: float, angle: float) -> Vector2:
	return star + (Vector2(cos(angle) * ORBIT.x, sin(angle) * ORBIT.y) * k).rotated(TILT)

## Half the orbit, faint, and the worlds that stand on it: the far half is
## the upper one.
func _orbit(b: Face.Builder, star: Vector2, k: float, far: bool) -> void:
	var line := PackedVector2Array()
	for i in 25:
		line.append(_on_orbit(star, k, (PI if far else 0.0) + PI * i / 24.0))
	b.stroke(line, 1.6 * k, Color(FAR_STAR, 0.16 if far else 0.26), false, false)
	for w: Array in WORLDS:
		var a := fposmod(float(w[0]), TAU)
		if (a > PI) != far:
			continue
		var at := _on_orbit(star, k, a)
		NightArt.lit(b, at, float(w[1]) * k, NightArt.PAINT[w[2]], star - at)

## The far stars: flat dots, kept on the paper, thin behind the words and
## none in the seal's corner or over the star's own light.
func _far(b: Face.Builder, paper: PackedVector2Array, star: Vector2, k: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 6113
	var seal := seal_centre()
	var words := WORDS_ROOM * Vector2(1.0, _h())
	for i in FAR:
		var at := Vector2(rng.randf_range(12.0, size.x - 12.0), rng.randf_range(12.0, size.y - 12.0))
		var r := rng.randf_range(0.9, 2.0) * _h()
		var keep := rng.randf()
		if at.x < words.x and at.y < words.y and keep > 0.22:
			continue
		if at.distance_to(seal) < SEAL_R + 12.0 or at.distance_to(star) < LIGHT * k * 0.9:
			continue
		if not Geometry2D.is_point_in_polygon(at, paper):
			continue
		b.disc(at, r, Color(FAR_STAR, rng.randf_range(0.3, 0.7)))

func _lay() -> void:
	var words := _words(String(entry.get("title", "")), SIDE, size.y * 0.5, WORDS, INK, INK_DIM)
	words.position.y = roundf(WORDS_TOP * _h())
