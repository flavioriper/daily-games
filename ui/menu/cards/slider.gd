extends "res://ui/menu/cards/card_face.gd"

## Super Slider's card: the paper is the tray's own floor, seen close at the
## gate. The board's four columns stand against the card's right side and its
## bottom wall runs the card's foot in walnut, cut away under the two middle
## columns where the plank doors hang ajar. The big red block is one step
## from home, over the lit mat, and one square stands under it; the cell to
## that square's right is empty, so one slide clears the run. That square is
## the go button: a block in the card's colour, lifted, its chevron pointing
## the way it slides. A blue bar and a yellow square stand by. The name is
## top left, on bare floor.
##
## The cells are the board's own (slider_gen.gd's 4 by 5, the gate under
## columns 1 and 2), the top row and a half lost off the card's top, and
## every block is ui/faces/slider_block.gd's, as the board draws them.
## Everything is one mesh; nothing lives on the card.

const Gen = preload("res://puzzles/slider_gen.gd")
const Block = preload("res://ui/faces/slider_block.gd")

## The row the card was drawn for (puzzle_card_2d.gd's CARD_H).
const H := 246.0
## A cell at H, the columns' room from the card's right side, and the floor's
## from its foot (the wall stands in that).
const CELL := 58.0
const RIGHT := 10.0
const FOOT := 27.0
## Where the words end: the columns never start left of it, so a tall narrow
## card gets smaller cells rather than a block under its blurb.
const WORDS_END := 232.0
## The wall's left end from the card's side.
const WALL_LEFT := 14.0
## How far the doors stand open, and how lit the mat is.
const DOORS := 0.6
const GLOW := 0.7
## The blocks, in the board's cells: the big one a step above the goal, the
## square in its way, and the two standing by.
const BIG := Vector2i(1, 2)
const GO := Vector2i(2, 4)
const GO_TO := Vector2i(3, 4)
const BAR := Vector2i(0, 3)
const SQUARE := Vector2i(3, 3)
## The first row whose grooves are drawn: those above lie under the words
## and the seal.
const GROOVE_ROW := 2
## The words' margin and how far down they start.
const SIDE := 22.0
const WORDS := 215.0
const WORDS_TOP := 14.0

## The floor: birch over a warmer birch.
const FLOOR_TOP := Color("f8f0de")
const FLOOR_LOW := Color("eddfc2")
const BLURB := Color("7d6d55")

func _k() -> float:
	return size.y / H

func _cell() -> float:
	return minf(CELL * _k(), (size.x - RIGHT - WORDS_END) / float(Gen.COLS))

## The board's top left corner: its columns against the right, its last row
## on the wall.
func _origin() -> Vector2:
	var s := _cell()
	return Vector2(size.x - RIGHT - Gen.COLS * s, size.y - FOOT * _k() - Gen.ROWS * s)

func _at(cell: Vector2i) -> Vector2:
	return _origin() + Vector2(cell) * _cell()

## The position shown is a real one: no two blocks share a cell, the go
## square's slide lands in an empty cell, and with it gone the big block's
## step into the goal is clear.
static func _legal() -> bool:
	var taken := {}
	for item: Array in [[BIG, Vector2i(2, 2)], [GO, Vector2i.ONE], [BAR, Vector2i(1, 2)], [SQUARE, Vector2i.ONE]]:
		var at: Vector2i = item[0]
		var sz: Vector2i = item[1]
		for dy in sz.y:
			for dx in sz.x:
				var c := at + Vector2i(dx, dy)
				if taken.has(c) or c.x < 0 or c.y < 0 or c.x >= Gen.COLS or c.y >= Gen.ROWS:
					return false
				taken[c] = true
	if taken.has(GO_TO) or (GO_TO - GO).abs() != Vector2i(1, 0):
		return false
	taken.erase(GO)
	var goal := Vector2i(Gen.GOAL % Gen.COLS, Gen.GOAL / Gen.COLS)
	if BIG + Vector2i(0, 1) != goal:
		return false
	for dx in 2:
		if taken.has(BIG + Vector2i(dx, 2)):
			return false
	return true

func _paint(b: Face.Builder) -> void:
	var s := _cell()
	var o := _origin()
	var first := b.verts.size()
	b.polygon(ground(), Color.WHITE)
	shade(b, first, FLOOR_TOP, FLOOR_LOW, 0.0, size.y)
	var floor_y := o.y + Gen.ROWS * s
	# The pressed grid, from the row the big block stands in down.
	var top := o.y + GROOVE_ROW * s + s * 0.12
	for x in range(1, Gen.COLS):
		b.stroke(PackedVector2Array([Vector2(o.x + x * s, top), Vector2(o.x + x * s, floor_y - s * 0.12)]), s * 0.014,
			Pal.SLIDE_GROOVE)
	for y in range(GROOVE_ROW + 1, Gen.ROWS):
		b.stroke(PackedVector2Array([o + Vector2(s * 0.12, y * s), o + Vector2(Gen.COLS * s - s * 0.12, y * s)]), s * 0.014,
			Pal.SLIDE_GROOVE)
	Block.hollow(b, _at(GO_TO), s)
	Block.mat(b, o, s, GLOW)
	_wall(b, o, s)
	Block.doors(b, o, s, DOORS)
	Block.block(b, _at(BAR), Vector2i(1, 2), s, Gen.V0)
	Block.block(b, _at(SQUARE), Vector2i.ONE, s, Gen.SQ)
	Block.block(b, _at(BIG), Vector2i(2, 2), s, Gen.B0, 0.0, Face.Expr.HAPPY, Vector2(0.0, 0.03))
	if soon or not _legal():
		Block.block(b, _at(GO), Vector2i.ONE, s, Gen.SQ)
	else:
		_go(b, _at(GO), s)

## The tray's bottom wall along the card's foot, as slider_block.gd's tray
## draws its frame: walnut over its shaded lip, a lit band, and the gate cut
## away under the goal's two columns between two turned posts.
func _wall(b: Face.Builder, o: Vector2, s: float) -> void:
	var f := Block.FRAME * s
	var y := o.y + Gen.ROWS * s
	var x0 := WALL_LEFT
	var x1 := o.x + Gen.COLS * s
	var w := x1 - x0
	b.fan(Face.Builder.round_rect(Vector2(x0, y - s * 0.03), Vector2(w, s * 0.05), s * 0.02), Color(Pal.SLIDE_FRAME_DEEP, 0.2))
	b.fan(Face.Builder.round_rect(Vector2(x0, y + s * 0.04), Vector2(w, f), f * 0.5), Pal.SLIDE_FRAME_DEEP)
	b.fan(Face.Builder.round_rect(Vector2(x0, y), Vector2(w, f), f * 0.5), Pal.SLIDE_FRAME)
	b.fan(Face.Builder.round_rect(Vector2(x0 + f, y + f * 0.2), Vector2(w - f * 2.0, f * 0.2), f * 0.1), Pal.SLIDE_FRAME_HI)
	var gx := o.x + s * float(Gen.GOAL % Gen.COLS)
	b.fan(PackedVector2Array([Vector2(gx, y - s * 0.02), Vector2(gx + s * 2.0, y - s * 0.02),
		Vector2(gx + s * 2.0, y + f + s * 0.04), Vector2(gx, y + f + s * 0.04)]), Pal.SLIDE_MAT.lerp(Pal.SLIDE_MAT_HI, GLOW))
	for side: float in [0.0, 2.0]:
		var post := Vector2(gx + s * side, y + f * 0.5)
		b.disc(post + Vector2(0.0, s * 0.03), f * 0.62, Pal.SLIDE_FRAME_DEEP)
		b.disc(post, f * 0.62, Pal.SLIDE_FRAME_HI)
		b.disc(post, f * 0.34, Pal.SLIDE_FRAME)
	for x: float in [x0 + f * 0.6, x1 - f * 0.6]:
		var peg := Vector2(x, y + f * 0.5)
		b.disc(peg, f * 0.22, Pal.SLIDE_BRASS)
		b.disc(peg + Vector2(-f * 0.06, -f * 0.07), f * 0.08, Pal.SLIDE_BRASS_HI)

## The go square, its cell's box at `at`: a block of the board's make in the
## card's colour, lifted over the board's own lifted shadow, a chevron
## pointing at the empty cell it slides into.
func _go(b: Face.Builder, at: Vector2, s: float) -> void:
	Block.shadow(b, at, Vector2i.ONE, s, 1.0)
	var up := at - Vector2(0.0, s * 0.1)
	var p := up + Vector2.ONE * Block.GAP * s
	var sz := Vector2.ONE * s * (1.0 - 2.0 * Block.GAP)
	var rad := Block.RADIUS * s
	var top := sz - Vector2(0.0, Block.LIP * s)
	b.fan(Face.Builder.round_rect(p, sz, rad), colour.darkened(0.28))
	b.fan(Face.Builder.round_rect(p, top, rad), colour)
	b.fan(Face.Builder.round_rect(p + Vector2(rad * 0.7, s * 0.045), Vector2(top.x - rad * 1.4, s * 0.05), s * 0.025),
		Color(colour.lightened(0.4), 0.9))
	b.fan(Face.Builder.round_rect(p + Vector2(rad * 0.5, s * 0.03), Vector2(top.x - rad, top.y * 0.3), rad * 0.8),
		Color(Pal.SURFACE, 0.14))
	var c := p + top * 0.5
	var h := s * 0.19
	var dir := Vector2(GO_TO - GO)
	var side := Vector2(-dir.y, dir.x)
	b.stroke(PackedVector2Array([c - dir * h * 0.55 - side * h, c + dir * h * 0.55, c - dir * h * 0.55 + side * h]),
		s * 0.11, Pal.SURFACE)

func _lay() -> void:
	var words := _words(String(entry.get("title", "")), SIDE, size.y * 0.5, WORDS, Pal.TEXT, BLURB)
	words.position.y = roundf(WORDS_TOP * _k())
