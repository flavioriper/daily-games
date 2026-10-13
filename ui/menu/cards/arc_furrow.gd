extends "res://ui/menu/cards/card_face.gd"

## Furrow's card: an early morning over a soil-cream field, one soft far
## hill, and three of the game's own beds side by side along the lower
## right, as its banner and its seed cards lay them: one bare, one with a
## sprout, one with its crop ripe. A hen stands at the row's near end. The go button is the next thing done to the bare bed: a
## seed packet in the card's colour, lifted over it, its chevron pointing
## down into the soil. The name stands top left, with the field's line (its
## seeds and plots, set from outside) under it.
##
## Everything is one mesh: the beds, plants, packet and hen are
## arcade/furrow_art.gd's and arcade/furrow_animals.gd's own builders, and
## nothing lives on the card.

const Art = preload("res://arcade/furrow_art.gd")
const Animals = preload("res://arcade/furrow_animals.gd")

## The row the card was drawn for (puzzle_card_2d.gd's CARD_H).
const H := 246.0
## The words end here and the picture needs this much to their right: the
## card's width caps the scale so the beds never start under them.
const WORDS_END := 240.0
const REACH := 250.0
## The beds at H: how far apart, their size, how far in from the right the
## last one's middle is and how far over the foot they lie.
const PITCH := 82.0
const BED := Vector2(74.0, 30.0)
const RIGHT := 34.0
const FOOT := 36.0
## Half a bed, as the plants are sized, and what grows in each bed from the
## bare one rightward: [crop, stage].
const PLANT := 37.0
const BEDS := [[4, 0], [0, 1], [3, 3]]
## The hen: how tall, and how far left of the bare bed's middle she stands.
const HEN := 46.0
const HEN_OUT := 62.0
## The go packet: its side, how far over its bed it hangs, and its shadow.
const GO := 52.0
const GO_UP := 72.0
const GO_SHADOW := 0.24
## The packet when the card is not open yet.
const PLAIN := 38.0
## The far hill's crest and foot at H.
const HILL_TOP := 128.0
const HILL_FOOT := 176.0
## The words' margin, their room and how far down they start.
const SIDE := 22.0
const WORDS := 215.0
const WORDS_TOP := 14.0

## The morning: sky over soil-cream, the far hill and the blurb's ink.
const SKY := Color("eef5ee")
const FIELD := Color("f6e8cf")
const HILL := Color("dfeccf")
const BLURB := Color("6f6a4c")

func _k() -> float:
	return minf(size.y / H, maxf(size.x - WORDS_END, 1.0) / REACH)

## Bed `i`'s middle, the bare one first.
func _bed(i: int) -> Vector2:
	var k := _k()
	return Vector2(size.x - (RIGHT + float(BEDS.size() - 1 - i) * PITCH) * k, size.y - FOOT * k)

func _paint(b: Face.Builder) -> void:
	var k := _k()
	var first := b.verts.size()
	b.polygon(ground(), Color.WHITE)
	shade(b, first, SKY, FIELD, 0.0, size.y)
	_hill(b)
	# A pale wash of turned earth under the row.
	var mid := (_bed(0) + _bed(BEDS.size() - 1)) * 0.5
	Art.soft(b, mid + Vector2(0.0, 6.0 * k), PITCH * 1.55 * k, 26.0 * k, Color(Art.EARTH, 0.5))
	for i in BEDS.size():
		b.append(Art.bed(BED * k), Transform2D(0.0, _bed(i)))
	for i in BEDS.size():
		var row: Array = BEDS[i]
		if i == 0:
			# The bare bed: turned soil and nothing in it yet.
			continue
		b.append(Art.plant(row[0], row[1], PLANT * k), Transform2D(0.0, _bed(i)))
	Animals.hen_into(b, _bed(0) + Vector2(-HEN_OUT * k, 10.0 * k), HEN * k)
	var over := _bed(0) - Vector2(0.0, GO_UP * k)
	if soon:
		b.append(Art.packet(BEDS[0][0], PLAIN * k), Transform2D(0.0, _bed(0) - Vector2(0.0, 52.0 * k)))
		return
	_go(b, over, k)

## One soft far hill, sunk under the words and highest behind the beds.
func _hill(b: Face.Builder) -> void:
	var k := size.y / H
	var pts := PackedVector2Array()
	var steps := 28
	for i in steps + 1:
		var t := float(i) / steps
		var x := lerpf(EDGE, size.x - EDGE, t)
		var y := lerpf(HILL_FOOT, HILL_TOP, pow(sin(t * PI * 0.62), 2.0)) * k
		pts.append(Vector2(x, y))
	var first := b.verts.size()
	var low := HILL_FOOT * k + 14.0 * k
	pts.append(Vector2(size.x - EDGE, low))
	pts.append(Vector2(EDGE, low))
	b.polygon(pts, Color.WHITE)
	# Clear at its foot, so it melts into the field.
	for i in range(first, b.verts.size()):
		var a := clampf(inverse_lerp(low, HILL_TOP * k, b.verts[i].y), 0.0, 1.0)
		b.cols[i] = Color(HILL, a * 0.9)

## The go packet about `at`: the game's seed packet in the card's colour,
## lifted over its shadow on the bed, a chevron pointing down into the soil.
func _go(b: Face.Builder, at: Vector2, k: float) -> void:
	var s := GO * k
	var corner := at - Vector2.ONE * s * 0.5
	Art.soft(b, _bed(0) + Vector2(0.0, -2.0 * k), s * 0.5, s * 0.16, Color(Pal.TEXT, GO_SHADOW))
	b.polygon(Face.Builder.round_rect(corner + Vector2(0.0, s * 0.1), Vector2.ONE * s, s * 0.2), colour.darkened(0.28))
	b.polygon(Face.Builder.round_rect(corner, Vector2.ONE * s, s * 0.2), colour)
	b.polygon(Face.Builder.round_rect(corner + Vector2.ONE * s * 0.1, Vector2(s * 0.8, s * 0.3), s * 0.12),
		Color(Pal.SURFACE, 0.18))
	# The packet's torn top: a paler band, as the game's packet has its panel.
	b.polygon(Face.Builder.round_rect(corner + Vector2(s * 0.12, s * 0.08), Vector2(s * 0.76, s * 0.1), s * 0.05),
		Color(Pal.SURFACE, 0.35))
	var h := s * 0.17
	var c := at + Vector2(0.0, s * 0.08)
	b.stroke(PackedVector2Array([c + Vector2(-h, -h * 0.55), c + Vector2(0.0, h * 0.55), c + Vector2(h, -h * 0.55)]),
		s * 0.11, Pal.SURFACE)

func _lay() -> void:
	var words := _words(String(entry.get("title", "")), SIDE, size.y * 0.5, WORDS, Pal.TEXT, BLURB)
	words.position.y = roundf(WORDS_TOP * size.y / H)
