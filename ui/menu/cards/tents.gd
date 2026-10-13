extends "res://ui/menu/cards/card_face.gd"

## Tents' card: one row of the meadow, laid along the foot of the card in a
## misty wood. The row's count stands at its left end as it does on the
## board, a two, and the row holds two trees: the first has its tent pitched
## beside it, lamp lit, and the second is still waiting for the one in the
## square next to it -- which is the go button, a tent in the card's colour
## with a chevron where the doorway is. A square of bare grass lies between
## the two tents, because tents never touch. The name stands in the mist
## over the row, and the top right corner is left to the seal.
##
## The ground, the row, the chip and the pitched tent are one mesh (the chip
## and the tent baked from the board's own faces); the two trees are the
## board's Controls, swaying as they do there.

const Board = preload("res://puzzles/tents2d.gd")
const TentFace = preload("res://ui/faces/tent_face.gd")
const ConiferFace = preload("res://ui/faces/conifer_face.gd")
const CountChip = preload("res://ui/faces/count_chip.gd")
const Scenery = preload("res://ui/flat/scenery.gd")
const CozyTheme = preload("res://ui/theme.gd")

## The row the card was drawn for (puzzle_card_2d.gd's CARD_H); the meadow
## grows with a taller one.
const H := 246.0
## A square at H, the chip's own place in squares, the row's margin from the
## card's sides and its lift off the card's foot.
const CELL := 74.0
const CHIP_PLACE := 0.74
const CHIP_SIZE := 0.96
const SIDE := 24.0
const FOOT := 13.0
## The meadow's corner and bottom edge, in squares (the board's TURF_RADIUS
## and TURF_EDGE on a square of about 110).
const TURF_ROUND := 0.16
const TURF_LIP := 0.07
## The row, square by square.
enum { GRASS, TREE, TENT, GO }
const ROW := [TREE, TENT, GRASS, GO, TREE]
## The go tent, in squares: bigger than a pitched one, standing on the same
## ground.
const GO_SIZE := 1.1

const MIST_TOP := Color("e9f3ec")
const MIST_LOW := Color("d3e8d6")
## The wood behind the row: the floor and the far trees, and the trees as
## [x in card widths, height, half width], at H, from the floor's line.
const WOOD := Color("bcdcc4")
const WOOD_FAR := Color("c9e3cf")
const PINES := [[0.05, 30.0, 13.0], [0.13, 20.0, 10.0], [0.24, 26.0, 12.0], [0.37, 18.0, 9.0],
	[0.47, 28.0, 13.0], [0.58, 20.0, 10.0], [0.68, 32.0, 14.0], [0.79, 22.0, 10.0],
	[0.88, 30.0, 13.0], [0.96, 20.0, 10.0]]

## The chip's numeral, as CountChip.numeral() gives it, written over the mesh.
var _num: Array = []

func _k() -> float:
	return size.y / H

## The row's own scale: the card's, unless the row would not fit its width.
func _ks() -> float:
	return minf(_k(), (size.x - SIDE * 2.0) / ((CHIP_PLACE + ROW.size()) * CELL))

func _cell() -> float:
	return CELL * _ks()

## The meadow's top left corner: the row stands on the card's foot, the
## chip's place to its left.
func _origin() -> Vector2:
	var c := _cell()
	return Vector2(SIDE + CHIP_PLACE * c, size.y - FOOT * _k() - c * (1.0 + TURF_LIP))

## The middle of square `i`.
func _mid(i: int) -> Vector2:
	var c := _cell()
	return _origin() + Vector2((i + 0.5) * c, c * 0.5)

func _paint(b: Face.Builder) -> void:
	var c := _cell()
	var k := _k()
	var paper := ground()
	var at := _origin()
	var first := b.verts.size()
	b.polygon(paper, Color.WHITE)
	shade(b, first, MIST_TOP, MIST_LOW, 0.0, size.y)
	# The wood: far trees over a floor that runs under the row to the foot.
	var line := at.y + c * 0.16
	for pine in PINES:
		var x: float = size.x * pine[0]
		var tall: float = pine[1] * k
		var wide: float = pine[2] * k
		b.polygon(PackedVector2Array([Vector2(x, line - tall), Vector2(x + wide, line + 1.0),
			Vector2(x - wide, line + 1.0)]), WOOD_FAR)
	for part in Geometry2D.intersect_polygons(paper, PackedVector2Array([Vector2(-8.0, line),
			Vector2(size.x + 8.0, line), Vector2(size.x + 8.0, size.y + 8.0), Vector2(-8.0, size.y + 8.0)])):
		first = b.verts.size()
		b.polygon(part, Color.WHITE)
		shade(b, first, WOOD_FAR, WOOD, line, size.y)
	# The meadow: its shadow, its bottom edge, the grass and the grid.
	var field := Vector2(ROW.size() * c, c)
	var round := c * TURF_ROUND
	b.polygon(Face.Builder.round_rect(at + Vector2(0.0, c * 0.12), field + Vector2(0.0, c * TURF_LIP), round),
		Color(Pal.LEAF_DEEP, 0.16))
	b.polygon(Face.Builder.round_rect(at, field + Vector2(0.0, c * TURF_LIP), round), Pal.LINE)
	b.polygon(Face.Builder.round_rect(at, field, round), Pal.MEADOW)
	for i in range(1, ROW.size()):
		b.stroke(PackedVector2Array([at + Vector2(i * c, 0.0), at + Vector2(i * c, c)]), Board.GRID_WIDTH * _ks(),
			Color(Pal.MEADOW_LINE, Board.GRID_ALPHA), false, false)
	# What lies on the ground: tufts and a flower on the bare square, the
	# shadows of whatever stands (the board's TREE_SHADOW_*, TENT_SHADOW_*)
	# and the warm pool under a lit tent (GLOW_*).
	for i in ROW.size():
		var mid := _mid(i)
		match ROW[i]:
			GRASS:
				Scenery.tuft(b, mid + Vector2(-0.22, 0.30) * c, Board.TUFT_H * c)
				Scenery.tuft(b, mid + Vector2(0.20, -0.06) * c, Board.TUFT_H * c * 0.8)
				_flower(b, mid + Vector2(0.24, 0.30) * c, Board.FLOWER_R * c * 1.3, Pal.FLOWER)
				_flower(b, mid + Vector2(-0.16, -0.24) * c, Board.FLOWER_R * c * 1.1, Pal.SURFACE)
			TREE:
				var seat := c * Board.TREE_SIZE
				Scenery.soft_disc(b, mid + Board.TREE_SHADOW_AT * seat, Board.TREE_SHADOW_RX * seat,
					Board.TREE_SHADOW_RY * seat, Color(Pal.TEXT, Board.SHADOW_ALPHA))
			TENT:
				var seat := c * Board.TENT_SIZE
				Scenery.soft_disc(b, mid + Board.TENT_SHADOW_AT * seat, Board.TENT_SHADOW_RX * seat,
					Board.TENT_SHADOW_RY * seat, Color(Pal.TEXT, Board.SHADOW_ALPHA))
				Scenery.soft_disc(b, mid + Board.GLOW_AT * seat, Board.GLOW_RX * seat, Board.GLOW_RY * seat,
					Color(Pal.SUN, Board.GLOW_ALPHA))
			GO:
				if not soon:
					var seat := c * GO_SIZE
					Scenery.soft_disc(b, _go_mid(i) + Board.TENT_SHADOW_AT * seat, Board.TENT_SHADOW_RX * seat,
						Board.TENT_SHADOW_RY * seat, Color(Pal.TEXT, Board.SHADOW_ALPHA))
	# The pitched tent, lamp lit, as the board bakes a right one.
	for i in ROW.size():
		if ROW[i] != TENT:
			continue
		var seat := c * Board.TENT_SIZE
		var tent := TentFace.new()
		tent.casts = false
		tent.expression = Face.Expr.JOY
		tent.size = Vector2(seat, seat)
		tent.bake_into(b, Transform2D(0.0, _mid(i) - tent.size * 0.5), Color.WHITE, true)
		tent.free()
	# The go tent.
	if not soon:
		for i in ROW.size():
			if ROW[i] == GO:
				_go_tent(b, _go_mid(i), c * GO_SIZE)
	# The row's count, standing at its left end.
	var px := c * CHIP_SIZE
	var chip := CountChip.new()
	chip.number = ROW.count(TENT) + ROW.count(GO)
	chip.size = Vector2(px, px)
	var xf := Transform2D(0.0, Vector2(SIDE + (CHIP_PLACE * c - px) * 0.5 - c * 0.04, at.y + (c - px) * 0.5))
	chip.bake_into(b, xf, Color.WHITE, true)
	_num = chip.numeral()
	if not _num.is_empty():
		_num[0] = xf * _num[0]
	chip.free()

func _draw() -> void:
	super()
	if not _num.is_empty():
		draw_string(CozyTheme.display(700), _num[0], _num[1], HORIZONTAL_ALIGNMENT_LEFT, -1.0, _num[2], _num[3])

## Where the go tent's own middle goes, so that it stands on the ground the
## pitched one does.
func _go_mid(i: int) -> Vector2:
	var c := _cell()
	return _mid(i) + Vector2(0.0, 0.4 * c * (Board.TENT_SIZE - GO_SIZE))

## A tent of `R` at `at`, cut as TentFace cuts one (its lines, pegs, poles,
## two slopes, seam and lit edge), in the card's colour, with a chevron where
## the doorway would be.
func _go_tent(b: Face.Builder, at: Vector2, R: float) -> void:
	var deep := colour.darkened(0.24)
	for side: float in [-1.0, 1.0]:
		b.stroke(PackedVector2Array([at + Vector2(side * 0.44, 0.4) * R, at + Vector2(side * 0.16, -0.3) * R]),
			0.035 * R, Color(Pal.TENT_DARK, 0.55))
		b.polygon(Face.Builder.round_rect(at + Vector2(side * 0.44 - 0.025, 0.35) * R, Vector2(0.05, 0.09) * R, 0.02 * R),
			Pal.BARK)
		b.stroke(PackedVector2Array([at + Vector2(-side * 0.025, -0.41) * R, at + Vector2(side * 0.05, -0.52) * R]),
			TentFace.POLE_WIDTH * R, Pal.BARK)
	b.polygon(PackedVector2Array([at + Vector2(0.0, -0.46) * R, at + Vector2(0.42, 0.4) * R,
		at + Vector2(-0.42, 0.4) * R]), deep)
	b.polygon(PackedVector2Array([at + Vector2(0.0, -0.46) * R, at + Vector2(0.2, 0.4) * R,
		at + Vector2(-0.42, 0.4) * R]), colour)
	b.stroke(PackedVector2Array([at + Vector2(-0.02, -0.42) * R, at + Vector2(-0.39, 0.38) * R]),
		TentFace.SEAM_WIDTH * R, Color(1.0, 1.0, 1.0, TentFace.EDGE_LIGHT), false, false)
	var mid := at + Vector2(-0.05, 0.13) * R
	var h := R * 0.13
	b.stroke(PackedVector2Array([mid + Vector2(-h * 0.55, -h), mid + Vector2(h * 0.55, 0.0),
		mid + Vector2(-h * 0.55, h)]), R * 0.085, Pal.SURFACE)

## A meadow flower of `r`: five petals round a sun-yellow middle.
func _flower(b: Face.Builder, at: Vector2, r: float, petal: Color) -> void:
	for i in 5:
		b.disc(at + Vector2.from_angle(-PI * 0.5 + i * TAU / 5.0) * r, r * 0.72, petal)
	b.disc(at, r * 0.6, Pal.SUN)

func _lay() -> void:
	var c := _cell()
	var seat := c * Board.TREE_SIZE
	for i in ROW.size():
		if ROW[i] != TREE:
			continue
		var tree := ConiferFace.new()
		# The shadow is the card's, on the ground.
		tree.casts = false
		tree.size = Vector2(seat, seat)
		tree.position = _mid(i) - tree.size * 0.5
		_keep(tree)
		tree.set_idle(true)
	# The words stand in the mist over the row, clear of the seal's corner.
	var room := size.x - SIDE - (SEAL_IN + SEAL_R + 10.0)
	_words(String(entry.get("title", "")), SIDE, _origin().y * 0.5 + 2.0, room)
