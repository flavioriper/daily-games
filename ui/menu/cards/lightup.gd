extends "res://ui/menu/cards/card_face.gd"

## Light Up's card: the court at dusk, and one lamp burning in it. A walk of
## flagstones runs along the foot of the card and turns up its right side;
## the lamp stands at the corner, and the stones it can see are warm -- up
## the side and out to the edge -- while the walk beyond the block beside it
## stays cold, because a block stops the light. The block reads 2 and has one
## lamp at its shoulder, so the stone on its other side is the go button: the
## place the second lamp goes.
##
## The stones, the block and the lamp are the board's own (puzzles/
## lightup2d.gd's _stone and _block_body, ui/faces/court_lantern.gd), and the
## light is what it is there: warm floor and a soft halo, never a ray.
##
## Everything still is one mesh; the lamp is the board's Control, its candle
## flickering as it does there, and the block's numeral is written over the
## mesh as the board writes it.

const Board = preload("res://puzzles/lightup2d.gd")
const CourtLantern = preload("res://ui/faces/court_lantern.gd")
const Scenery = preload("res://ui/flat/scenery.gd")
const CozyTheme = preload("res://ui/theme.gd")

## The row the card was drawn for (puzzle_card_2d.gd's CARD_H); the court
## grows with a taller one.
const H := 246.0
## A flagstone, the court's size in stones, and its margins from the card's
## right edge and its foot.
const CELL := 62.0
const COLS := 7
const ROWS := 3
const SIDE := 28.0
const FOOT := 24.0
const TEXT_X := 26.0

enum { COLD, WARM, BLOCK, LAMP, GO }
## The court, stone by stone: [column, row, what stands there].
const STONES := [
	[5, 0, WARM],
	[5, 1, WARM], [6, 1, COLD],
	[0, 2, COLD], [1, 2, COLD], [2, 2, COLD], [3, 2, GO], [4, 2, BLOCK], [5, 2, LAMP], [6, 2, WARM],
]
const LAMP_AT := Vector2i(5, 2)
const BLOCK_AT := Vector2i(4, 2)
## What the block asks for: the lamp beside it and the one the go stone wants.
const NUMBER := 2

const DUSK_TOP := Color("46384f")
const DUSK_LOW := Color("8d6252")
const INK := Color("fff3dc")
const INK_DIM := Color("e6d0bc")
## The motes in the lamp's light, in stones from the lamp: [x, y, radius, alpha].
const MOTES := [[-0.62, -1.10, 0.035, 0.55], [0.48, -1.62, 0.028, 0.45], [0.86, -0.52, 0.024, 0.5],
	[-0.34, -2.28, 0.022, 0.35], [-1.30, -0.72, 0.020, 0.3]]

## The court's own scale: the card's, unless that would run the walk off the
## card's left side.
func _k() -> float:
	return minf(size.y / H, (size.x - SIDE * 2.0) / (CELL * COLS))

func _cell() -> float:
	return CELL * _k()

func _origin() -> Vector2:
	var c := _cell()
	return Vector2(size.x - SIDE - c * COLS, size.y - FOOT - c * ROWS)

func _mid(cell: Vector2i) -> Vector2:
	return _origin() + (Vector2(cell) + Vector2(0.5, 0.5)) * _cell()

## A stone's outline at `cell`, `short` of a stone taken off its foot (the
## board's _tile).
func _tile(cell: Vector2i, short: float) -> PackedVector2Array:
	var c := _cell()
	var span := c * (1.0 - 2.0 * Board.GAP)
	return Face.Builder.round_rect(_mid(cell) - Vector2(span, span) * 0.5,
		Vector2(span, span - c * short), c * Board.STONE_RADIUS)

func _paint(b: Face.Builder) -> void:
	var c := _cell()
	var first := b.verts.size()
	b.polygon(ground(), Color.WHITE)
	shade(b, first, DUSK_TOP, DUSK_LOW, 0.0, size.y)
	# The lamp's light on the evening air, and the motes drifting in it.
	var lamp := _mid(LAMP_AT)
	Scenery.soft_disc(b, lamp + Vector2(0.0, -c), c * 1.75, c * 1.75, Color(Pal.SUN, 0.26))
	for m in MOTES:
		b.disc(lamp + Vector2(m[0], m[1]) * c, m[2] * c, Color(Pal.LANTERN_LIT, m[3]))
	# The walk: every stone its own tile, cold or carrying the lamp's warmth.
	for s in STONES:
		var cell := Vector2i(s[0], s[1])
		var what: int = s[2]
		if what == GO:
			if soon:
				_stone(b, cell, Pal.FLAGSTONE, Pal.FLAGSTONE_DEEP)
				continue
			_stone(b, cell, colour, colour.darkened(0.24))
			var mid := _mid(cell) - Vector2(0.0, c * Board.STONE_EDGE * 0.5)
			var k := c * 0.16
			b.stroke(PackedVector2Array([mid + Vector2(-k * 0.55, -k), mid + Vector2(k * 0.55, 0.0),
				mid + Vector2(-k * 0.55, k)]), c * 0.10, Pal.SURFACE)
		elif what == COLD or what == BLOCK:
			_stone(b, cell, Pal.FLAGSTONE, Pal.FLAGSTONE_DEEP)
		else:
			_stone(b, cell, Pal.LAMPLIT_FLOOR, Pal.LAMPLIT_DEEP)
	# What stands on the walk: the shadows first, then the block.
	Scenery.soft_disc(b, lamp + Board.LAMP_SHADOW_AT * c, Board.LAMP_SHADOW_RX * c, Board.LAMP_SHADOW_RY * c,
		Color(Pal.TEXT, Board.SHADOW_ALPHA))
	_block(b, _mid(BLOCK_AT), c * Board.BLOCK_SIZE)

## One flagstone: its deep edge, its face and the light along its crest.
func _stone(b: Face.Builder, cell: Vector2i, face: Color, deep: Color) -> void:
	var c := _cell()
	b.polygon(_tile(cell, 0.0), deep)
	b.polygon(_tile(cell, Board.STONE_EDGE), face)
	var wide := c * (1.0 - 2.0 * Board.GAP - 2.0 * Board.STONE_RADIUS)
	var at := _mid(cell)
	b.polygon(Face.Builder.round_rect(Vector2(at.x - wide * 0.5, at.y - c * (0.5 - Board.GAP) + c * 0.04),
		Vector2(wide, c * 0.06), c * 0.03), Color(1.0, 1.0, 1.0, Board.CREST_ALPHA))

## The block, `s` across about `at`: the board's cut stone with the plaque its
## number is carved in, and the lamp's light along the side that faces it.
func _block(b: Face.Builder, at: Vector2, s: float) -> void:
	var face: Color = Pal.BLOCK_STONE
	var deep := face.darkened(0.3)
	Scenery.soft_disc(b, at + Board.BLOCK_SHADOW_AT * s, Board.BLOCK_SHADOW_RX * s, Board.BLOCK_SHADOW_RY * s,
		Color(Pal.TEXT, Board.BLOCK_SHADOW_ALPHA))
	b.polygon(Face.Builder.round_rect(at - Vector2.ONE * 0.46 * s, Vector2.ONE * 0.92 * s, 0.15 * s), deep)
	b.polygon(Face.Builder.round_rect(at - Vector2.ONE * 0.46 * s, Vector2(0.92, 0.8) * s, 0.15 * s), face)
	b.polygon(Face.Builder.round_rect(at + Vector2(0.22, -0.46) * s, Vector2(0.24, 0.8) * s, 0.15 * s),
		Color(0.0, 0.0, 0.0, 0.1))
	b.stroke(PackedVector2Array([at + Vector2(-0.3, -0.4) * s, at + Vector2(0.28, -0.4) * s]), 0.045 * s,
		Color(1.0, 1.0, 1.0, 0.16))
	b.stroke(PackedVector2Array([at + Vector2(-0.4, -0.3) * s, at + Vector2(-0.4, 0.2) * s]), 0.04 * s,
		Color(1.0, 1.0, 1.0, 0.09))
	b.polygon(Face.Builder.round_rect(at + Vector2(-0.25, -0.31) * s, Vector2(0.5, 0.5) * s, 0.14 * s),
		Color(deep, 0.55))
	b.stroke(PackedVector2Array([at + Vector2(-0.14, 0.2) * s, at + Vector2(0.14, 0.2) * s]), 0.035 * s,
		Color(1.0, 1.0, 1.0, 0.12))
	# The lit stone beside it, on its side (the board's _block_rims).
	b.stroke(PackedVector2Array([at + Vector2(0.44, -0.36) * s, at + Vector2(0.44, 0.24) * s]),
		Board.RIM_WIDTH * s, Color(Pal.SUN_RAY, Board.RIM_ALPHA))

func _draw() -> void:
	super()
	if size.x <= 0.0 or size.y <= 0.0:
		return
	# The block's numeral, as the board writes it over its own mesh.
	var s := _cell() * Board.BLOCK_SIZE
	var font: Font = CozyTheme.display(700)
	var px := int(roundf(Board.NUM_SIZE * s * 1.15))
	var text := str(NUMBER)
	var wide := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, px).x
	draw_string(font, _mid(BLOCK_AT) + Vector2(-wide * 0.5, font.get_ascent(px) * 0.5 - 0.08 * s), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, px, Pal.BLOCK_NUM)

func _lay() -> void:
	var c := _cell()
	var lamp := CourtLantern.new()
	# Its shadow is on the stone, in the mesh.
	lamp.casts = false
	lamp.lit = 1.0
	lamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var px := c * Board.LAMP_SIZE
	lamp.size = Vector2(px, px)
	lamp.pivot_offset = lamp.size * 0.5
	lamp.position = _mid(LAMP_AT) - lamp.size * 0.5 - Vector2(0.0, c * 0.04)
	_keep(lamp)
	lamp.set_idle(true)
	# The words stand in the dusk over the cold end of the walk, clear of the
	# stones that turn up the side.
	var o := _origin()
	var room := o.x + c * LAMP_AT.x - TEXT_X - 10.0
	_words(String(entry.get("title", "")), TEXT_X, (o.y + c * 2.0) * 0.5 + 2.0, room, INK, INK_DIM)
