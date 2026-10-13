extends "res://ui/menu/cards/card_face.gd"

## Stackwood's card: the well from the side on a workshop cream. Four of its
## columns stand on a bench line along the foot against the card's right
## side, the game's own painted blocks stacked unevenly, and one block is
## falling in over the second column, whose top block carries the same
## number: a block that lands on its own number merges with it, so the next
## thing that happens is plain. The stacks shown hold only numbers the game
## makes (powers of two) and no two equal ones touch, so the well is at rest
## until the block lands.
##
## The go button is the falling block: in the card's colour, larger, lifted
## over a shadow, its number over a chevron pointing down, left of the
## seal's corner. The name stands top left.
##
## Everything still is one mesh, the blocks arcade/stackwood_art.gd's own;
## the numbers are draw_strings over it, as the game letters them.

const Art = preload("res://arcade/stackwood_art.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

## The row the card was drawn for (puzzle_card_2d.gd's CARD_H).
const H := 246.0
## A block at H, how far one sits above the next, and the stacks' room from
## the card's right side and foot.
const CELL := 46.0
const PITCH := 0.96
const RIGHT := 16.0
const FOOT := 13.0
## The words end here: the first column never stands left of it.
const WORDS_END := 250.0
## The columns left to right, each bottom up.
const STACKS := [[64, 8], [512], [128, 32, 4], [16, 2]]
## The column the go block falls into, and its number: the one on top there.
const GO_COL := 1
## The go block: its size in blocks, how far over the stack it hovers, and
## its shadow on the block below.
const GO_SIZE := 1.24
const GO_GAP := 0.5
const GO_SHADOW := 0.22
## The words' margin, their room and how far down they start.
const SIDE := 22.0
const WORDS := 215.0
const WORDS_TOP := 14.0

## The workshop: cream over a deeper cream, a pale pool behind the stacks,
## the bench line and the blurb's ink.
const CREAM_TOP := Color("fcf4e4")
const CREAM_LOW := Color("f3e2c6")
const POOL := Color("fffaf0")
const BENCH := Color("c9a57a")
const BLURB := Color("7b6a54")

## The picture's scale: the card's height sets it, its width caps it.
func _k() -> float:
	var wide := STACKS.size() * CELL + RIGHT
	return minf(size.y / H, (size.x - WORDS_END) / wide)

func _cell() -> float:
	return CELL * _k()

## The bench line's height on the card.
func _foot() -> float:
	return size.y - FOOT * _k()

## The middle of the block `row` up column `col`.
func _mid(col: int, row: int) -> Vector2:
	var s := _cell()
	var left := size.x - RIGHT * _k() - STACKS.size() * s
	return Vector2(left + (col + 0.5) * s, _foot() - s * 0.5 - row * s * PITCH)

func _go_value() -> int:
	var col: Array = STACKS[GO_COL]
	return int(col[col.size() - 1])

## The go block's middle: over its twin, clear of it.
func _go_mid() -> Vector2:
	var s := _cell()
	var top := _mid(GO_COL, (STACKS[GO_COL] as Array).size() - 1)
	return top - Vector2(0.0, s * (0.5 + GO_GAP + GO_SIZE * 0.5))

func _paint(b: Face.Builder) -> void:
	var k := _k()
	var s := _cell()
	var first := b.verts.size()
	b.polygon(ground(), Color.WHITE)
	shade(b, first, CREAM_TOP, CREAM_LOW, 0.0, size.y)
	var foot := _foot()
	var left := size.x - RIGHT * k - STACKS.size() * s
	Scenery.soft_disc(b, Vector2(left + STACKS.size() * s * 0.5, foot - s * 1.5), s * 2.6, s * 1.9, Color(POOL, 0.55))
	# The bench: one faint line along the foot.
	b.polygon(Face.Builder.round_rect(Vector2(18.0, foot), Vector2(size.x - 36.0, maxf(2.0, 3.0 * k)), 1.5 * k), Color(BENCH, 0.55))
	for c in STACKS.size():
		var col: Array = STACKS[c]
		for r in col.size():
			b.append(Art.block(int(col[r]), s), Transform2D(0.0, _mid(c, r)))
	var go := _go_mid()
	if soon:
		b.append(Art.block(_go_value(), s), Transform2D(0.0, go))
		return
	# The fall: three short strokes over the block, and its shadow below.
	var g := s * GO_SIZE
	for j in 3:
		var x := go.x + (j - 1) * g * 0.26
		var up := g * (0.72 if j == 1 else 0.64)
		b.stroke(PackedVector2Array([Vector2(x, go.y - up), Vector2(x, go.y - up - g * 0.26)]), maxf(2.0, s * 0.06),
			Color(BENCH, 0.5))
	var twin := _mid(GO_COL, (STACKS[GO_COL] as Array).size() - 1)
	Scenery.soft_disc(b, twin - Vector2(0.0, s * 0.5), s * 0.5, s * 0.13, Color(Pal.TEXT, GO_SHADOW))
	_go(b, go, g)

## The go block about `at`, `g` across: the game's block shape in the card's
## colour, with a chevron pointing down under where its number is written.
func _go(b: Face.Builder, at: Vector2, g: float) -> void:
	var half := g * 0.5
	var lip := g * 0.1
	var r := g * 0.16
	var corner := at - Vector2(half, half)
	b.polygon(Face.Builder.round_rect(corner + Vector2(0.0, lip), Vector2(g, g - lip), r), colour.darkened(0.28))
	var face := Vector2(g, g - lip)
	b.polygon(Face.Builder.round_rect(corner, face, r), colour)
	b.polygon(Face.Builder.round_rect(corner + Vector2.ONE * g * 0.09, Vector2(face.x - g * 0.18, face.y * 0.36), r * 0.7),
		Color(Pal.SURFACE, 0.16))
	var c := at + Vector2(0.0, g * 0.2)
	var h := g * 0.1
	b.stroke(PackedVector2Array([c + Vector2(-h, -h * 0.55), c + Vector2(0.0, h * 0.55), c + Vector2(h, -h * 0.55)]),
		g * 0.075, Pal.SURFACE)

func _draw() -> void:
	super._draw()
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var s := _cell()
	var font := Art.font()
	for c in STACKS.size():
		var col: Array = STACKS[c]
		for r in col.size():
			Art.number(self, font, _mid(c, r), int(col[r]), s)
	var go := _go_mid()
	if soon:
		Art.number(self, font, go, _go_value(), s)
		return
	# The go block's number, cream over a soft drop, above its chevron.
	var g := s * GO_SIZE
	var text := str(_go_value())
	var fs := int(g * 0.36)
	var wide := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var at := go + Vector2(-wide * 0.5, (font.get_ascent(fs) - font.get_descent(fs)) * 0.5 - g * 0.2)
	draw_string(font, at + Vector2(0.0, g * 0.025), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.15, 0.08, 0.05, 0.3))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Pal.SURFACE)

func _lay() -> void:
	var words := _words(String(entry.get("title", "")), SIDE, size.y * 0.5, WORDS, Pal.TEXT, BLURB)
	words.position.y = roundf(WORDS_TOP * size.y / H)
