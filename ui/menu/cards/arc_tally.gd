extends "res://ui/menu/cards/card_face.gd"

## Tally's card: a corner of the game's squared paper, ruled faintly over
## the whole face. Low on the right a dig stands on a printed 1 and a short
## walnut belt carries two cream tokens east into an adder facing up, whose
## answer rides one more square of belt north, a 2 on it.
##
## The go button is where that 2 is going: the counting box in the card's
## colour, lifted over its shadow, its cream panel showing the 2 it asks for
## and a chevron beside it. The name stands top left with the paper's line
## under it.
##
## Everything still is one mesh, the pieces arcade/tally_art.gd's own
## builders laid by a transform; the numerals are draw_strings over it, as
## the game letters its tokens.

const Art = preload("res://arcade/tally_art.gd")
const Sim = preload("res://arcade/tally_sim.gd")
const Scenery = preload("res://ui/flat/scenery.gd")
const CozyTheme = preload("res://ui/theme.gd")

## The row the card was drawn for (puzzle_card_2d.gd's CARD_H) and the width
## the picture's places are written at.
const H := 246.0
const W := 490.0
## The words end here: the picture's scale is capped so it never starts
## left of it.
const WORDS_END := 250.0
## A square of the paper at H.
const S := 44.0
## The pieces, as square middles at H: the dig, the belt's squares, the
## adder, the belt north of it and the go box.
const DIG := Vector2(292.0, 202.0)
const BELT := [Vector2(336.0, 202.0), Vector2(380.0, 202.0)]
const ADDER := Vector2(424.0, 202.0)
const UP := Vector2(424.0, 158.0)
const GO := Vector2(424.0, 104.0)
const GO_SIZE := Vector2(96.0, 54.0)
const GO_LIFT := 5.0
const GO_SHADOW := 0.24
## Where the two 1s ride along the belt (0 the west edge, 1 the east) and
## the 2 north of the adder.
const ONES := [0.25, 0.85]
const TWO := 0.45
## The words' margin, their room and how far down they start.
const SIDE := 22.0
const WORDS := 215.0
const WORDS_TOP := 14.0
const BLURB := Color("7d6a52")

func _k() -> float:
	return minf(size.y / H, (size.x - WORDS_END) / (W - WORDS_END))

## A place written at H on a W-wide card, on this card: the picture hangs
## from the right side and stands on the foot.
func _at(p: Vector2) -> Vector2:
	var k := _k()
	return Vector2(size.x - (W - p.x) * k, size.y - (H - p.y) * k)

## A piece built at Art.U to a square, laid on the square about `mid`.
func _xf(mid: Vector2, rot := 0.0) -> Transform2D:
	var s := S * _k() / Art.U
	return Transform2D(rot, Vector2(s, s), 0.0, _at(mid))

func _ones() -> Array:
	var out := []
	for u: float in ONES:
		out.append(Vector2(lerpf(BELT[0].x - S * 0.5, BELT[1].x + S * 0.5, u), DIG.y))
	return out

func _two() -> Vector2:
	return Vector2(UP.x, UP.y + S * 0.5 - S * TWO)

func _paint(b: Face.Builder) -> void:
	var k := _k()
	var first := b.verts.size()
	b.polygon(ground(), Color.WHITE)
	shade(b, first, Art.PAPER, Art.PAPER.darkened(0.04), 0.0, size.y)
	# The paper's rule, a square at a time from the picture's own grid, kept
	# off the rounded corners.
	var g := S * k
	var o := _at(Vector2(DIG.x - S * 0.5, DIG.y - S * 0.5))
	var x := fposmod(o.x, g)
	while x < size.x - RADIUS:
		if x > RADIUS:
			b.polygon(_bar(Vector2(x, EDGE + 2.0), Vector2(x, size.y - EDGE - 2.0), 1.5), Art.GRID)
		x += g
	var y := fposmod(o.y, g)
	while y < size.y - RADIUS:
		if y > RADIUS:
			b.polygon(_bar(Vector2(EDGE + 2.0, y), Vector2(size.x - EDGE - 2.0, y), 1.5), Art.GRID)
		y += g
	# A printed 2 waiting up the paper, in pencil.
	var ring_first := b.verts.size()
	Art.print_ring(b, Vector2.ZERO, true)
	_lay_from(b, ring_first, _xf(Vector2(336.0, 114.0)))
	# The belts: east from the dig to the adder, north out of it.
	var beds := b.verts.size()
	for m: Vector2 in BELT:
		Art.bed_into(b, Vector2.ZERO, 0, 0)
		_lay_from(b, beds, _xf(m))
		beds = b.verts.size()
	Art.bed_into(b, Vector2.ZERO, 3, 3)
	_lay_from(b, beds, _xf(UP))
	var chev := Art.chevron()
	for m: Vector2 in BELT:
		b.append(chev, _xf(m) * Transform2D(0.0, Vector2(-Art.U * 0.06, 0.0)))
	b.append(chev, _xf(UP + Vector2(0.0, S * 0.25)) * Transform2D(-PI * 0.5, Vector2.ZERO))
	# The pieces and the tokens riding.
	b.append(Art.dig(), _xf(DIG))
	b.append(Art.icon(Sim.ADD), _xf(ADDER))
	for p: Vector2 in _ones():
		b.append(Art.token(false), _xf(p))
	b.append(Art.token(true), _xf(_two()))
	if soon:
		# Not open yet: the box's plain panel, no lift.
		var c := _at(GO)
		var sz := GO_SIZE * k
		b.fan(Face.Builder.round_rect(c - sz * 0.5, sz, 14.0 * k), Art.PAINT[Sim.BOX])
		return
	_go(b, _at(GO) - Vector2(0.0, GO_LIFT * k), k)

## Lays what `b` took since `first` under `xf`.
func _lay_from(b: Face.Builder, first: int, xf: Transform2D) -> void:
	for i in range(first, b.verts.size()):
		b.verts[i] = xf * b.verts[i]

static func _bar(a: Vector2, c: Vector2, w: float) -> PackedVector2Array:
	var n := (c - a).normalized().orthogonal() * w * 0.5
	return PackedVector2Array([a + n, c + n, c - n, a - n])

## The go box about `at`: the card's colour, lifted over its own shadow,
## a cream panel on its left for the number and a chevron on its right.
func _go(b: Face.Builder, at: Vector2, k: float) -> void:
	var sz := GO_SIZE * k
	var corner := at - sz * 0.5
	Scenery.soft_disc(b, at + Vector2(0.0, sz.y * 0.5 + (GO_LIFT + 4.0) * k), sz.x * 0.54, 8.0 * k, Color(Art.INK, GO_SHADOW))
	b.fan(Face.Builder.round_rect(corner + Vector2(0.0, 5.0 * k), sz, 15.0 * k), colour.darkened(0.26))
	b.fan(Face.Builder.round_rect(corner, sz, 15.0 * k), colour)
	b.fan(Face.Builder.round_rect(corner + Vector2(5.0, 5.0) * k, Vector2(sz.x - 10.0 * k, sz.y * 0.36), 10.0 * k), Color(Pal.SURFACE, 0.16))
	b.fan(Face.Builder.round_rect(corner + Vector2(8.0, 8.0) * k, Vector2(sz.y - 16.0 * k, sz.y - 16.0 * k), 9.0 * k), Art.TOKEN)
	var c := at + Vector2(sz.x * 0.27, 0.0)
	var h := 9.0 * k
	b.stroke(PackedVector2Array([c + Vector2(-h * 0.55, -h), c + Vector2(h * 0.55, 0.0), c + Vector2(-h * 0.55, h)]),
		6.0 * k, Pal.SURFACE)

func _draw() -> void:
	super._draw()
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var k := _k()
	var font := CozyTheme.display(700)
	_numeral(font, "1", _at(DIG), int(S * 0.36 * k), Art.INK)
	_numeral(font, "2", _at(Vector2(336.0, 114.0)), int(S * 0.4 * k), Art.PENCIL.darkened(0.15))
	for p: Vector2 in _ones():
		_numeral(font, "1", _at(p), int(S * 0.34 * k), Art.INK)
	_numeral(font, "2", _at(_two()), int(S * 0.34 * k), Art.INK)
	if not soon:
		var sz := GO_SIZE * k
		var panel := _at(GO) - Vector2(0.0, GO_LIFT * k) - sz * 0.5 + Vector2(8.0, 8.0) * k + Vector2.ONE * (sz.y - 16.0 * k) * 0.5
		_numeral(font, "2", panel, int(sz.y * 0.5), Art.INK)

func _numeral(font: Font, text: String, mid: Vector2, fs: int, col: Color) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, Vector2(mid.x - w * 0.5, mid.y + fs * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)

func _lay() -> void:
	var words := _words(String(entry.get("title", "")), SIDE, size.y * 0.5, WORDS, Pal.TEXT, BLURB)
	words.position.y = roundf(WORDS_TOP * _k())
