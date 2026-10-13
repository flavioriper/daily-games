extends "res://ui/menu/cards/card_face.gd"

## Word Trail's card: a corner of the field, three tiles by three, on a warm
## peach morning, with one word being traced through it. The beam runs from
## the M along the top, down a tile, along and down again -- M, A, P, L, each
## tile lit toward the sun as the board lights the trail under a finger, the
## sun disc on the last of them -- and the tile the next step lands on, the E
## that finishes the word, is the go button: a piece in the card's colour
## with a chevron where its letter would be. The three tiles the trail leaves
## are another word of the field, quiet, and the ninth cell is a wall, the
## board's sunk bed with its leaf. The name stands on the left, three leaves
## lie at the card's foot, and the top right corner is left to the seal.
##
## The ground, the tiles, the bed, the beam and the go tile are one mesh, cut
## as the board cuts a piece (word_trail2d.gd's `_tile`: a lip, a lit rim, a
## crown) and laid by its own `_filleted` and `_cap`; the letters are draw
## commands over it, as they are there (Mosaic.letter). Nothing is alive.

const Board = preload("res://puzzles/word_trail2d.gd")
const Mosaic = preload("res://ui/faces/mosaic_tile.gd")
const Scenery = preload("res://ui/flat/scenery.gd")
const CozyTheme = preload("res://ui/theme.gd")

## The row the card was drawn for (puzzle_card_2d.gd's CARD_H); the field
## grows with a taller one.
const H := 246.0
## A tile at H, the gap between two, and the margins the field keeps from the
## card's sides and its foot.
const CELL := 52.0
const GAP := 4.0
const N := 3
const SIDE := 24.0
const RIGHT := 20.0
const FOOT := 14.0
## The room the words are owed beside the field, and the gap between them.
const WORDS := 258.0
const WORDS_GAP := 12.0
## A piece's bottom edge, in cells, and the least it may be: the board's
## TILE_EDGE is 7 on a cell of about 190, which is a hairline on one of 52.
const LIP := 0.07
const LIP_MIN := 3.0
## The word being traced, cell by cell, and the cell its last letter is on;
## the word the trail leaves, likewise; and the wall. Every step is to a
## side, never a diagonal, and the two words and the wall fill the field, as
## a board's do. Both words are in content/word_trail.json.
const WORD := "maple"
const TRAIL := [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1)]
const GO := Vector2i(2, 2)
const OTHER := "oak"
const OTHER_AT := [Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 2)]
const WALL := Vector2i(2, 0)
## The go tile, in cells, about the middle of the cell it stands on.
const GO_SIZE := 1.14
## How far a letter off the trail is let through.
const QUIET := 0.62

const SKY_TOP := Color("fdeee0")
const SKY_LOW := Color("f6d6c2")
const BLURB := Color("86685a")
## The leaves at the card's foot: [x, y up from the foot, length, angle,
## colour], at H.
const LEAVES := [
	[44.0, 30.0, 30.0, -0.5, Pal.LEAF],
	[84.0, 22.0, 24.0, 0.35, Pal.ACORN],
	[120.0, 34.0, 20.0, -0.9, Pal.SUN],
]
const LEAF_WASH := 0.4

func _k() -> float:
	return size.y / H

## The field's own scale: the card's, unless the words want the room.
func _ks() -> float:
	var wide := (size.x - SIDE - WORDS - WORDS_GAP - RIGHT) / (N * CELL + (N - 1) * GAP)
	return minf(_k(), wide)

func _cell() -> float:
	return CELL * _ks()

## The field's top left corner: it stands on the card's foot at its right.
func _origin() -> Vector2:
	var ks := _ks()
	var span := (N * CELL + (N - 1) * GAP) * ks
	return Vector2(size.x - RIGHT - span, size.y - FOOT * _k() - span)

func _corner(cell: Vector2i) -> Vector2:
	return _origin() + Vector2(cell) * ((CELL + GAP) * _ks())

func _lip() -> float:
	return maxf(LIP_MIN, _cell() * LIP)

## The middle of a piece's face, which is where its letter and the beam go.
func _centre(cell: Vector2i) -> Vector2:
	var s := _cell()
	return _corner(cell) + Vector2(s * 0.5, (s - _lip()) * 0.5)

func _paint(b: Face.Builder) -> void:
	var k := _k()
	var s := _cell()
	var first := b.verts.size()
	b.polygon(ground(), Color.WHITE)
	shade(b, first, SKY_TOP, SKY_LOW, 0.0, size.y)
	# The leaves, washed toward the ground they lie on, each with its rib.
	for leaf in LEAVES:
		var at := Vector2(leaf[0] * k, size.y - leaf[1] * k)
		var tint: Color = (leaf[4] as Color).lerp(SKY_LOW, LEAF_WASH)
		var xf := Transform2D(leaf[3], at)
		b.polygon(xf * Board._leaf_points(leaf[2] * k), tint)
		b.stroke(PackedVector2Array([xf * Vector2(leaf[2] * k * 0.12, 0.0), xf * Vector2(leaf[2] * k * 0.86, 0.0)]),
			maxf(1.5, leaf[2] * k * 0.06), tint.darkened(0.16))
	# The field's shadow on the ground, one soft piece under every tile.
	var round := s * Board.RADIUS
	for y in N:
		for x in N:
			var cell := Vector2i(x, y)
			if cell == WALL or (cell == GO and not soon):
				continue
			b.polygon(Face.Builder.round_rect(_corner(cell) + Vector2(0.0, s * 0.09), Vector2(s, s), round),
				Color(Pal.TEXT, 0.08))
	# The wall: a bed sunk into the ground, its leaf pressed into the floor.
	var bed := _corner(WALL)
	b.polygon(Face.Builder.round_rect(bed, Vector2(s, s), round), Board.BED_SHADE)
	b.polygon(Face.Builder.round_rect(bed + Vector2(0.0, s * Board.BED_LIP), Vector2(s, s * (1.0 - Board.BED_LIP)),
		round), Board.BED)
	b.polygon(Transform2D(Board.WALL_LEAF_ANGLE, bed + Board.WALL_LEAF_AT * s) * Board._leaf_points(Board.WALL_LEAF * s),
		Color(Pal.TEXT, Board.WALL_LEAF_INK))
	# The tiles: paper pieces, the ones on the trail lit toward the sun.
	var cells: Array = TRAIL + OTHER_AT
	if soon:
		cells.append(GO)
	for cell: Vector2i in cells:
		var tone: float = Board._tone(cell)
		var face: Color = Board._toned(Pal.SURFACE.lerp(Pal.SURFACE_HI, Board.PAPER_CROWN), tone)
		var rim: Color = Pal.SURFACE
		var lip: Color = Pal.SURFACE_HI.lerp(Pal.LINE, Board.PAPER_LIP)
		if TRAIL.has(cell):
			face = face.lerp(Pal.SUN_RAY, Board.TRAIL_LIT)
			rim = rim.lerp(Pal.SUN_RAY, Board.TRAIL_LIT * 0.5)
			lip = lip.lerp(Pal.SUN, Board.TRAIL_LIT)
		_piece(b, _corner(cell), s, face, lip, rim)
	# The beam under the finger, and its head on the tile the finger is on.
	var pts := PackedVector2Array()
	for cell: Vector2i in TRAIL:
		pts.append(_centre(cell))
	var w := s * Board.BEAM_W
	var beam := Color(Pal.SUN_RAY, Board.BEAM_ALPHA)
	var line: PackedVector2Array = Board._filleted(pts, w * 0.5)
	b.stroke(line, w, beam, false, false)
	Board._cap(b, line[0], line[0] - line[1], w * 0.5, beam)
	Board._cap(b, line[-1], line[-1] - line[-2], w * 0.5, beam)
	var head := pts[-1]
	Scenery.soft_disc(b, head, s * Board.HALO_R, s * Board.HALO_R, Color(Pal.SUN_RAY, Board.HALO_A))
	b.disc(head, s * Board.HEAD_R, Color(Pal.SUN, Board.BEAM_ALPHA))
	# The go button: the tile the next step lands on.
	if not soon:
		_go(b, _corner(GO) + Vector2.ONE * (s * 0.5), s * GO_SIZE)

## One piece at `at`, `s` wide, as the board's tile shape is cut: the bottom
## edge in `deep`, the face in `rim`, and the crown in `fill` a bevel down
## and in from it.
func _piece(b: Face.Builder, at: Vector2, s: float, fill: Color, deep: Color, rim: Color) -> void:
	var r := s * Board.RADIUS
	var edge := maxf(LIP_MIN, s * LIP)
	var bev := s * Board.BEVEL
	b.polygon(Face.Builder.round_rect(at, Vector2(s, s), r), deep)
	b.polygon(Face.Builder.round_rect(at, Vector2(s, s - edge), r), rim)
	b.polygon(Face.Builder.round_rect(at + Vector2(bev * 0.7, bev), Vector2(s - bev * 1.4, s - edge - bev),
		maxf(r - bev * 0.5, 0.0)), fill)

## The go tile about `mid`: a piece in the card's colour over its own soft
## shadow, a chevron where its letter would be.
func _go(b: Face.Builder, mid: Vector2, s: float) -> void:
	var at := mid - Vector2.ONE * (s * 0.5)
	Scenery.soft_disc(b, mid + Vector2(0.0, s * 0.4), s * 0.56, s * 0.18, Color(Pal.TEXT, 0.2))
	_piece(b, at, s, colour, colour.darkened(0.26), colour.lerp(Pal.SURFACE, Board.RIM_LIGHT))
	var c := mid + Vector2(s * 0.02, -maxf(LIP_MIN, s * LIP) * 0.5)
	var h := s * 0.17
	b.stroke(PackedVector2Array([c + Vector2(-h * 0.55, -h), c + Vector2(h * 0.55, 0.0),
		c + Vector2(-h * 0.55, h)]), s * 0.1, Pal.SURFACE)

func _draw() -> void:
	super()
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var font: Font = CozyTheme.display(700)
	# Mosaic.letter sizes a glyph at its own LETTER_SIZE of the box it is
	# handed; the board's letter is LETTER of the cell.
	var box := _cell() * Board.LETTER / Mosaic.LETTER_SIZE
	for i in TRAIL.size():
		Mosaic.letter(self, _centre(TRAIL[i]), box, WORD[i], Vector2.ONE, Pal.TEXT, font)
	for i in OTHER_AT.size():
		Mosaic.letter(self, _centre(OTHER_AT[i]), box, OTHER[i], Vector2.ONE, Pal.TEXT, font, QUIET)
	if soon:
		Mosaic.letter(self, _centre(GO), box, WORD[TRAIL.size()], Vector2.ONE, Pal.TEXT, font, QUIET)

func _lay() -> void:
	# The words stand on the left, a little over the middle so the leaves
	# keep the foot.
	var room := _origin().x - SIDE - WORDS_GAP
	_words(String(entry.get("title", "")), SIDE, size.y * 0.5 - 14.0 * _k(), room, Pal.TEXT, BLURB)
