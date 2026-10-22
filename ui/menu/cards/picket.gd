extends "res://ui/menu/cards/sudoku.gd"

## Picket Sums' card: Sudoku's card (ui/menu/cards/sudoku.gd) -- the row
## along the foot, the column climbing off the top, the region in the corner
## between them and the go tile where all three meet -- fenced into plots as
## the board fences its grid, each with its wooden tag. The go tile's plot
## reads 9 and holds a 2, so the number it wants is still the 7.

const Picket = preload("res://puzzles/picket2d.gd")

## The tags are drawn half as big again as the board's: at a card's cell
## the board's own would not read.
const TAG_GROW := 1.5

## The plots over the fragment, as lists of [column, row]; the first is
## where the tag hangs. Their tags are the digits' sums, the go tile's 7
## among them.
const PLOTS := [
	[[0, 8], [1, 8]], [[2, 8], [3, 8]], [[4, 8], [5, 8]], [[7, 8], [8, 8]],
	[[6, 7], [6, 8]],
	[[6, 0], [6, 1]], [[6, 2], [6, 3]], [[6, 4], [6, 5]],
	[[6, 6], [7, 6], [8, 6]], [[7, 7], [8, 7]],
]
const GO_DIGIT := 7

func _digit_at(col: int, row: int) -> int:
	if Vector2i(col, row) == GO:
		return GO_DIGIT
	for d in DIGITS:
		if d[0] == col and d[1] == row:
			return d[2]
	return 0

func _plot_of(col: int, row: int) -> int:
	for p in PLOTS.size():
		for cell in PLOTS[p]:
			if cell[0] == col and cell[1] == row:
				return p
	return -1

func _paint(b: Face.Builder) -> void:
	_tags = []
	super(b)
	var c := _cell()
	var k := c / Board.CELL
	var paper := ground()
	var ins := Picket.FENCE_INSET * k
	var w := maxf(Picket.FENCE_W * k, 2.0)
	for p in PLOTS.size():
		for cell in PLOTS[p]:
			var col: int = cell[0]
			var row: int = cell[1]
			if Vector2i(col, row) == GO or not _whole(paper, col, row):
				continue
			var o := _at(col, row)
			var same := func(dc: int, dr: int) -> bool: return _plot_of(col + dc, row + dr) == p
			if not same.call(0, -1):
				_fence(b, o + Vector2(ins if not same.call(-1, 0) else 0.0, ins),
					o + Vector2(c - ins if not same.call(1, 0) else c, ins), w, k)
			if not same.call(0, 1):
				_fence(b, o + Vector2(ins if not same.call(-1, 0) else 0.0, c - ins),
					o + Vector2(c - ins if not same.call(1, 0) else c, c - ins), w, k)
			if not same.call(-1, 0):
				_fence(b, o + Vector2(ins, ins if not same.call(0, -1) else 0.0),
					o + Vector2(ins, c - ins if not same.call(0, 1) else c), w, k)
			if not same.call(1, 0):
				_fence(b, o + Vector2(c - ins, ins if not same.call(0, -1) else 0.0),
					o + Vector2(c - ins, c - ins if not same.call(0, 1) else c), w, k)
	# The tags, over the fences' corners, their numbers with the digits.
	var font: Font = CozyTheme.body(800)
	var px := maxi(11, int(roundf(Picket.TAG_SIZE * k * TAG_GROW)))
	k *= TAG_GROW
	for p in PLOTS.size():
		var first: Array = PLOTS[p][0]
		if not _whole(paper, first[0], first[1]):
			continue
		var sum := 0
		for cell in PLOTS[p]:
			sum += _digit_at(cell[0], cell[1])
		var text := str(sum)
		var wide := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, px).x
		var at := _at(first[0], first[1]) + Picket.TAG_AT * k
		var sz := Vector2(wide + 2.0 * Picket.TAG_PAD.x * k, font.get_height(px) * 0.82 + 2.0 * Picket.TAG_PAD.y * k)
		var e := Picket.TAG_EDGE * k
		b.polygon(Face.Builder.round_rect(at, sz, Picket.TAG_R * k), Pal.WOOD_DEEP)
		b.polygon(Face.Builder.round_rect(at + Vector2.ONE * e, sz - Vector2.ONE * 2.0 * e,
			maxf(Picket.TAG_R * k - e, 1.0)), Picket.TAG_FACE)
		_tags.append([Vector2(at.x + sz.x * 0.5 - wide * 0.5, at.y + sz.y * 0.5 + font.get_ascent(px) * 0.5
			- font.get_descent(px) * 0.15), text, px])

var _tags: Array = []

func _fence(b: Face.Builder, a: Vector2, z: Vector2, w: float, k: float) -> void:
	var length := a.distance_to(z)
	if length <= 0.5:
		return
	b.stroke(PackedVector2Array([a, z]), maxf(Picket.RAIL_W * k, 1.0), Color(Picket.FENCE, Picket.RAIL_A), false, false)
	var dir := (z - a) / length
	var dash := Picket.PICKET * k
	var step := dash + Picket.PICKET_GAP * k
	var count := maxi(1, int(floor((length + Picket.PICKET_GAP * k) / step)))
	var lead := (length - (count * step - Picket.PICKET_GAP * k)) * 0.5
	for n in count:
		var s := lead + n * step
		b.stroke(PackedVector2Array([a + dir * s, a + dir * minf(s + dash, length)]), w, Picket.FENCE, false, true)

func _draw() -> void:
	super()
	var font: Font = CozyTheme.body(800)
	for t in _tags:
		draw_string(font, t[0], t[1], HORIZONTAL_ALIGNMENT_LEFT, -1.0, t[2], Pal.TEXT)
