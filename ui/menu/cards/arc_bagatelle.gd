extends "res://ui/menu/cards/card_face.gd"

## Bagatelle's card: the game's plum velvet over the whole face, a few rows
## of brass pins on the right, two marbles falling through them (a clay and
## a glass, one wearing a gold pin's ring) and three wooden cups along the
## foot. The go button is the middle cup's sun-coloured twin, lifted, with a
## chevron. The name stands top left in cream.
##
## Everything still is one mesh, laid from arcade/bagatelle_art.gd's own
## builders by a transform.

const Art = preload("res://arcade/bagatelle_art.gd")
const Sim = preload("res://arcade/bagatelle_sim.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

## The row the card was drawn for and the width the places are written at.
const H := 246.0
const W := 490.0
const WORDS_END := 250.0
## Field units to card pixels at H.
const FIELD_K := 0.2
## The pins, marbles and cups in card pixels at H, from the card's corner.
const PINS_AT := Vector2(268.0, 34.0)
const ROWS := 5
const ACROSS := 6
const PIN_DX := 34.0
const PIN_DY := 28.0
const MARBLES := [[Vector2(320.0, 62.0), 0, false], [Vector2(421.0, 118.0), 1, true]]
const CUPS_Y := 184.0
const GO := Vector2(372.0, 208.0)
const GO_SIZE := Vector2(72.0, 46.0)
const SIDE := 22.0
const WORDS := 215.0
const WORDS_TOP := 14.0
const BLURB := Color("d9c8e6")

func _k() -> float:
	return minf(size.y / H, (size.x - WORDS_END) / (W - WORDS_END))

func _at(p: Vector2) -> Vector2:
	var k := _k()
	return Vector2(size.x - (W - p.x) * k, size.y - (H - p.y) * k)

func _paint(b: Face.Builder) -> void:
	var k := _k()
	var first := b.verts.size()
	b.polygon(ground(), Color.WHITE)
	shade(b, first, Art.VELVET_TOP, Art.VELVET_LOW, 0.0, size.y)
	var pin := Art.pin()
	for r in ROWS:
		var n := ACROSS if r % 2 == 0 else ACROSS - 1
		for i in n:
			var p := PINS_AT + Vector2(i * PIN_DX + (0.0 if r % 2 == 0 else PIN_DX * 0.5), r * PIN_DY)
			b.append(pin, Transform2D(0.0, Vector2.ONE * k * 0.9, 0.0, _at(p)))
	# a gold pin among them
	b.append(Art.bonus_pin("plus"), Transform2D(0.0, Vector2.ONE * k * 0.8, 0.0, _at(PINS_AT + Vector2(3.5 * PIN_DX, 3.0 * PIN_DY))))
	for m: Array in MARBLES:
		var at := _at(m[0])
		b.append(Art.marble(int(m[1])), Transform2D(0.0, Vector2.ONE * k * 1.1, 0.0, at))
		if bool(m[2]):
			b.append(Art.boost_ring("plus"), Transform2D(0.0, Vector2.ONE * k * 1.1, 0.0, at))
	# the cups, the middle one the go button
	for x: float in [GO.x - 76.0, GO.x + 76.0]:
		b.append(Art.cup(1), Transform2D(0.0, Vector2(0.44, 0.4) * k, 0.0, _at(Vector2(x, CUPS_Y))))
	if soon:
		b.append(Art.cup(3), Transform2D(0.0, Vector2(0.44, 0.4) * k, 0.0, _at(Vector2(GO.x, CUPS_Y))))
		return
	_go(b, _at(GO) - Vector2(0.0, 5.0 * k), k)

func _go(b: Face.Builder, at: Vector2, k: float) -> void:
	var sz := GO_SIZE * k
	var corner := at - sz * 0.5
	Scenery.soft_disc(b, at + Vector2(0.0, sz.y * 0.5 + 8.0 * k), sz.x * 0.54, 8.0 * k, Color(0, 0, 0, 0.3))
	b.fan(Face.Builder.round_rect(corner + Vector2(0.0, 5.0 * k), sz, 15.0 * k), colour.darkened(0.26))
	b.fan(Face.Builder.round_rect(corner, sz, 15.0 * k), colour)
	b.fan(Face.Builder.round_rect(corner + Vector2(5.0, 5.0) * k, Vector2(sz.x - 10.0 * k, sz.y * 0.36), 10.0 * k), Color(Pal.SURFACE, 0.16))
	var h := 9.0 * k
	b.stroke(PackedVector2Array([at + Vector2(-h * 0.55, -h), at + Vector2(h * 0.55, 0.0), at + Vector2(-h * 0.55, h)]), 6.0 * k, Pal.SURFACE)

func _lay() -> void:
	var words := _words(String(entry.get("title", "")), SIDE, size.y * 0.5, WORDS, Art.CREAM, BLURB)
	words.position.y = roundf(WORDS_TOP * _k())
