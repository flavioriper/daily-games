extends "res://ui/menu/cards/card_face.gd"

## Brittle's card: a corner of the tin on the right of a warm cocoa card, three
## squares of brittle in it as the game draws them, one nearly broken, and the
## stream of sugar balls rising to it off the scoop. The go button is the
## scoop's lead ball, grown and carrying a chevron. The name stands top left
## with the best under it. Everything is one mesh, built in the game's own
## drawings and laid by scale, and nothing lives on the card.

const Art = preload("res://arcade/brittle_art.gd")
const Sim = preload("res://arcade/brittle_sim.gd")

const H := 246.0
const W := 490.0
const SIDE := 22.0
const WORDS := 215.0
const WORDS_TOP := 14.0
const GROUND_TOP := Color("4a342c")
const GROUND_LOW := Color("33231e")
## The pieces, by [x, y] in from the card's right and down from its top,
## flavour and cracks.
const PIECES := [[60.0, 52.0, 3, 0], [128.0, 52.0, 1, 1], [60.0, 120.0, 4, 2]]
const PIECE := 0.64
## The stream: from the scoop up to the square it is cracking.
const STREAM := [[150.0, 214.0], [139.0, 190.0], [128.0, 166.0], [117.0, 142.0], [106.0, 118.0]]
const GO_AT := Vector2(150.0, 214.0)
const GO_R := 21.0

func _k() -> float:
	return minf(size.y / H, size.x / W)

func _at(v: Vector2, k: float) -> Vector2:
	return Vector2(size.x - v.x * k, v.y * k)

func _paint(b: Face.Builder) -> void:
	var k := _k()
	var first := b.verts.size()
	b.polygon(ground(), Color.WHITE)
	shade(b, first, GROUND_TOP, GROUND_LOW, 0.0, size.y)
	for p: Array in PIECES:
		var s := PIECE * k
		b.append(Art.piece(Sim.Kind.SQUARE, int(p[2]), int(p[3]), 1), Transform2D(0.0, Vector2(s, s), 0.0, _at(Vector2(p[0], p[1]), k)))
	var ball := Sim.R * 100.0 * PIECE * k / Art.BALL
	for p: Array in STREAM.slice(1):
		b.append(Art.ball(), Transform2D(0.0, Vector2(ball, ball), 0.0, _at(Vector2(p[0], p[1]), k)))
	var go := _at(GO_AT, k)
	var r := GO_R * k
	var rs := r / Art.BALL
	b.append(Art.scoop(), Transform2D(0.0, Vector2(k * 0.8, k * 0.45), 0.0, go + Vector2(0.0, r * 0.8)))
	if soon:
		return
	b.append(Art.ball(), Transform2D(0.0, Vector2(rs, rs), 0.0, go))
	var c := r * 0.42
	b.stroke(PackedVector2Array([go + Vector2(-c * 0.5, -c), go + Vector2(c * 0.6, 0.0), go + Vector2(-c * 0.5, c)]), r * 0.2, Art.RIM_DARK)

func _lay() -> void:
	var words := _words(String(entry.get("title", "")), SIDE, size.y * 0.5, WORDS, Art.CREAM, Art.CREAM.darkened(0.12))
	words.position.y = roundf(WORDS_TOP * _k() if size.y / H <= size.x / W else WORDS_TOP * size.y / H)
