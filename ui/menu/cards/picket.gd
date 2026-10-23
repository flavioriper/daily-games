extends "res://ui/menu/cards/sudoku.gd"

## Picket Sums' card: one region of the board, whole and big enough to read,
## standing in Sudoku's tray (ui/menu/cards/sudoku.gd lays the tray and the
## panel) and fenced into four plots as the board fences its grid, with the
## board's own fence and tag pills (puzzles/picket2d.gd's fence_cell and
## tag_pill). Every cell but one is filled; the go tile sits in the plot
## tagged 16 that already holds a 9, so the number it wants is the 7 -- the
## one the region is missing too.
##
## The first card (2026-10-22) was a nine-by-nine fragment like Sudoku's,
## its tags over the digits in cells too small for both; the user: "hard to
## read right now due to numbers and letters". Here a tag sits in its
## corner and the digit in the middle, with room between them.

const Picket = preload("res://puzzles/picket2d.gd")

## A cell at H, and the region's margin from the card's right side.
const P_CELL := 64.0
const P_RIGHT := 30.0
## The region, as rows of digits; the plots as lists of [column, row], the
## first where the tag hangs; the go tile and the cells written in leaf.
const P_GRID := [[5, 3, 8], [4, 9, 1], [2, 7, 6]]
const P_PLOTS := [
	[[0, 0], [1, 0]],
	[[2, 0], [2, 1], [2, 2]],
	[[0, 1], [0, 2]],
	[[1, 1], [1, 2]],
]
const P_GO := Vector2i(1, 2)
const P_WRITTEN := [Vector2i(1, 0), Vector2i(2, 1)]
## The tags a little bigger than the board's, the digits a little smaller,
## so both read at a card's cell and never meet.
const P_TAG_GROW := 1.15
const P_DIGIT := 0.86

var _tags: Array = []

func _cell() -> float:
	var wide := (size.x - SIDE - WORDS - WORDS_GAP - P_RIGHT * _k()) / 3.0
	return minf(P_CELL * _k(), wide)

func _origin() -> Vector2:
	var c := _cell()
	return Vector2(size.x - P_RIGHT * _k() - 3.0 * c, (size.y - 3.0 * c) * 0.5)

func _plot_of(col: int, row: int) -> int:
	for p in P_PLOTS.size():
		for cell in P_PLOTS[p]:
			if cell[0] == col and cell[1] == row:
				return p
	return -1

func _paint(b: Face.Builder) -> void:
	var c := _cell()
	var k := c / Board.CELL
	var paper := ground()
	var first := b.verts.size()
	b.polygon(paper, Color.WHITE)
	shade(b, first, CLOTH_TOP, CLOTH_LOW, 0.0, size.y)
	_trays(b, paper, [[0, 0, 3, 3]], k)
	_panel(b, paper, 0, 0, 3, 3, Pal.SURFACE, k, Picket.THIN_FAINT)
	for row in 3:
		for col in 3:
			var p := _plot_of(col, row)
			Picket.fence_cell(b, _at(col, row), c, Picket.FENCE_INSET * k,
				func(dr: int, dc: int) -> bool: return _plot_of(col + dc, row + dr) == p,
				maxf(Picket.FENCE_W * k * 1.5, 1.5), Picket.FENCE.darkened(0.12))
	# The digits, and the tags' pills over the fences' corners.
	_nums = []
	var font: Font = CozyTheme.display(600)
	var px := int(roundf(Board.DIGIT_SIZE * k * P_DIGIT))
	var rise := font.get_ascent(px) * 0.5
	for row in 3:
		for col in 3:
			if Vector2i(col, row) == P_GO:
				continue
			var text := str(P_GRID[row][col])
			var wide := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, px).x
			_nums.append([_at(col, row) + Vector2(c * 0.5 - wide * 0.5 + c * 0.04, c * 0.56 + rise), text, px,
				Pal.LEAF_DEEP if Vector2i(col, row) in P_WRITTEN else Pal.TEXT])
	_tags = []
	var tk := k * P_TAG_GROW
	var tfont: Font = CozyTheme.body(Picket.TAG_WEIGHT)
	var tpx := maxi(13, int(roundf(Picket.TAG_SIZE * tk)))
	for plot in P_PLOTS:
		var sum := 0
		for cell in plot:
			sum += int(P_GRID[cell[1]][cell[0]])
		var text := str(sum)
		var wide := tfont.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, tpx).x
		var box: Rect2 = Picket.tag_rect(_at(plot[0][0], plot[0][1]) + Picket.TAG_AT * tk, wide, tfont, tpx, tk)
		Picket.tag_pill(b, box, tk, Picket.TAG_FACE, true)
		_tags.append([Picket.tag_base(box, wide, tfont, tpx), text, tpx])
	if not soon:
		_go(b, _at(P_GO.x, P_GO.y), c)

func _draw() -> void:
	super()
	var font: Font = CozyTheme.body(Picket.TAG_WEIGHT)
	for t in _tags:
		draw_string(font, t[0], t[1], HORIZONTAL_ALIGNMENT_LEFT, -1.0, t[2], Picket.TAG_INK)

func _lay() -> void:
	# The words stand on the cloth, left of the tray, at the card's middle.
	var c := _cell()
	var room := _at(0, 0).x - Board.FRAME * c / Board.CELL - SIDE - WORDS_GAP
	_words(String(entry.get("title", "")), SIDE, size.y * 0.5, room, Pal.TEXT, BLURB)
