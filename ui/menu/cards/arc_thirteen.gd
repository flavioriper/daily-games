extends "res://ui/menu/cards/card_face.gd"

## Lucky Thirteen's card: a pale stream bed with the game's own paper discs
## lying loose on it, no tray. A chain runs through three touching sixes in
## the game's chain line -- paper slid under them, a stroke of their own
## paint over it -- and ends on the third, which is the one the three become
## a seven on: three or more of one number merge into the last, one higher.
## A 3, a 4 and a 9 lie about them, and a pale 13 sits apart under the
## seal's corner as the prize.
##
## The go button is the six the chain ends on: a disc in the card's colour,
## larger, lifted over its shadow, its number on it and a small chevron
## beside the number. The name stands top left.
##
## Everything still is one mesh: the discs are arcade/thirteen_art.gd's own
## piece (`_tile`: a face over its lip) in its own paints, since the game's
## baked skin is a texture a card's mesh cannot carry. The numerals are a
## draw_string each over the mesh, as the game letters them.

const Art = preload("res://arcade/thirteen_art.gd")
const Sim = preload("res://arcade/thirteen_sim.gd")
const Scenery = preload("res://ui/flat/scenery.gd")
const CozyTheme = preload("res://ui/theme.gd")

## The row the card was drawn for (puzzle_card_2d.gd's CARD_H).
const H := 246.0
## A disc across at H, and the discs lying about the chain, each [number,
## how far in from the card's right side, how far down] at H.
const DISC := 50.0
const LOOSE := [[3, 214.0, 198.0], [4, 134.0, 213.0], [9, 50.0, 184.0]]
## The chain's number and its discs in the order they are dragged, each
## [in from the right, down] at H; the last is the go button.
const CHAIN_V := 6
const CHAIN: Array[Vector2] = [Vector2(212.0, 140.0), Vector2(160.0, 166.0), Vector2(104.0, 134.0)]
## The prize: where it sits, how big, and how far it is washed into the bed.
const PRIZE := Vector2(47.0, 108.0)
const PRIZE_DISC := 42.0
const PRIZE_WASH := 0.42
## The chain line in discs: the paper under it and the paint over it (the
## banner's 0.46 and 0.3), and the paper ring round each disc on it.
const LINE_PAPER := 0.46
const LINE_PAINT := 0.3
const RING := 1.2
## The go disc: its size in discs, how far it is lifted, and its shadow.
const GO_SIZE := 1.28
const GO_LIFT := 5.0
const GO_SHADOW := 0.24
## A disc's shadow on the bed.
const SHADOW := 0.16
## The picture's reach from the right side at H: the scale is capped so it
## never starts under the words.
const REACH := 244.0
const WORDS_END := 240.0
## The words' margin, their room and how far down they start.
const SIDE := 22.0
const WORDS := 215.0
const WORDS_TOP := 14.0

## The stream bed, its ripples, the chain's paper and the blurb's ink.
const BED_TOP := Color("e8f5f3")
const BED_LOW := Color("d2eae6")
const RIPPLE := Color("f6fcfb")
const PAPER := Color("fffaf0")
const BLURB := Color("56736f")
## The ripples, each [x in the card's width, y at H, length at H].
const RIPPLES := [[0.12, 196.0, 74.0], [0.47, 222.0, 56.0], [0.5, 96.0, 44.0]]

## The numerals `_paint` wants lettered: [where, text, size, ink, drop].
var _nums: Array = []

func _k() -> float:
	return minf(size.y / H, maxf(size.x - WORDS_END, 1.0) / REACH)

## A place given as [in from the right, down] at H, on the card. The picture
## hangs from the foot, so a taller card keeps it low.
func _at(p: Vector2) -> Vector2:
	var k := _k()
	return Vector2(size.x - p.x * k, size.y - (H - p.y) * k)

## The game's rule, on the card's own discs: three or more of one number,
## each touching the one before (here, within a disc and a half).
func _chain_holds() -> bool:
	if CHAIN.size() < Sim.MIN_CHAIN:
		return false
	for i in range(1, CHAIN.size()):
		if CHAIN[i].distance_to(CHAIN[i - 1]) > DISC * 1.5:
			return false
	return true

func _paint(b: Face.Builder) -> void:
	var k := _k()
	var s := DISC * k
	_nums = []
	var first := b.verts.size()
	b.polygon(ground(), Color.WHITE)
	shade(b, first, BED_TOP, BED_LOW, 0.0, size.y)
	for r: Array in RIPPLES:
		var at := Vector2(size.x * float(r[0]), size.y - (H - float(r[1])) * k)
		var long := float(r[2]) * k
		b.stroke(PackedVector2Array([at, at + Vector2(long, 0.0)]), 3.0 * k, Color(RIPPLE, 0.8))
		b.stroke(PackedVector2Array([at + Vector2(long * 0.3, 9.0 * k), at + Vector2(long * 0.85, 9.0 * k)]), 2.4 * k,
			Color(RIPPLE, 0.6))
	# The prize, washed into the bed.
	var prize := _at(PRIZE)
	var ps := PRIZE_DISC * k
	var lip := ps * 0.5 * Art.LIP
	var mid := BED_TOP.lerp(BED_LOW, 0.4)
	b.disc(prize + Vector2(0.0, lip * 0.5), (ps - lip) * 0.5, Art.line_colour(Sim.GOAL).lerp(mid, PRIZE_WASH))
	b.disc(prize - Vector2(0.0, lip * 0.5), (ps - lip) * 0.5, Art.paint(Sim.GOAL).lerp(mid, PRIZE_WASH))
	_number(prize, Sim.GOAL, ps, Color(Art.number_colour(Sim.GOAL), 0.7))
	# The discs' shadows under all of them.
	for d: Array in LOOSE:
		_shadow(b, _at(Vector2(d[1], d[2])), s)
	var chain := PackedVector2Array()
	for p: Vector2 in CHAIN:
		chain.append(_at(p))
	var ok := _chain_holds() and not soon
	var go := chain[chain.size() - 1]
	for i in chain.size():
		if not (ok and i == chain.size() - 1):
			_shadow(b, chain[i], s)
	# The chain: paper slid under its discs, their paint along it.
	if ok:
		for p in chain:
			b.polygon(Art.tile_outline(p, s * RING), PAPER)
		b.stroke(chain, s * LINE_PAPER, PAPER)
		b.stroke(chain, s * LINE_PAINT, Art.paint(CHAIN_V))
	for d: Array in LOOSE:
		var at := _at(Vector2(d[1], d[2]))
		Art._tile(b, at, s * 0.97, int(d[0]))
		_number(at, int(d[0]), s, Art.number_colour(int(d[0])))
	for i in chain.size():
		if ok and i == chain.size() - 1:
			continue
		Art._tile(b, chain[i], s * 0.97, CHAIN_V)
		_number(chain[i], CHAIN_V, s, Art.number_colour(CHAIN_V))
	if ok:
		_go(b, go - Vector2(0.0, GO_LIFT * k), s * GO_SIZE, k)

func _shadow(b: Face.Builder, at: Vector2, s: float) -> void:
	Scenery.soft_disc(b, at + Vector2(0.0, s * 0.44), s * 0.5, s * 0.16, Color(Pal.TEXT, SHADOW))

## The go disc about `at`, `s` across: the game's piece in the card's
## colour, its number left of the middle and a chevron right of it.
func _go(b: Face.Builder, at: Vector2, s: float, k: float) -> void:
	Scenery.soft_disc(b, at + Vector2(0.0, s * 0.46 + GO_LIFT * k), s * 0.54, s * 0.18, Color(Pal.TEXT, GO_SHADOW))
	var lip := s * 0.5 * Art.LIP * 1.3
	var r := (s - lip) * 0.5
	b.disc(at + Vector2(0.0, lip * 0.5), r, colour.darkened(0.26))
	var face := at - Vector2(0.0, lip * 0.5)
	b.disc(face, r, colour)
	b.disc(face - Vector2(0.0, r * 0.3), r * 0.62, Color(Pal.SURFACE, 0.1))
	_number(face - Vector2(s * 0.15, 0.0), CHAIN_V, s * 0.92, Pal.SURFACE)
	var c := face + Vector2(s * 0.2, 0.0)
	var h := s * 0.13
	b.stroke(PackedVector2Array([c + Vector2(-h * 0.55, -h), c + Vector2(h * 0.55, 0.0), c + Vector2(-h * 0.55, h)]),
		s * 0.085, Pal.SURFACE)

## Number `v` centred on a disc `s` across at `c`, as the game letters it.
func _number(c: Vector2, v: int, s: float, ink: Color) -> void:
	var font: Font = Art.font()
	var text := str(v)
	var px := int(s * (0.46 if text.length() == 1 else 0.4))
	var wide := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var at := c + Vector2(-wide * 0.5 - s * 0.012, (font.get_ascent(px) - font.get_descent(px)) * 0.5 - s * 0.05)
	_nums.append([at, text, px, ink, s * 0.025])

func _draw() -> void:
	super()
	var font: Font = Art.font()
	for n: Array in _nums:
		var ink: Color = n[3]
		draw_string(font, n[0] + Vector2(0.0, n[4]), n[1], HORIZONTAL_ALIGNMENT_LEFT, -1, n[2], Color(0.2, 0.12, 0.05, 0.25 * ink.a))
		draw_string(font, n[0], n[1], HORIZONTAL_ALIGNMENT_LEFT, -1, n[2], ink)

func _lay() -> void:
	var words := _words(String(entry.get("title", "")), SIDE, size.y * 0.5, WORDS, Pal.TEXT, BLURB)
	words.position.y = roundf(WORDS_TOP * _k())
