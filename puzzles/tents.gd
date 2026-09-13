extends "res://core/puzzle_base.gd"

## Tents & Trees. Tap a cell to cycle blank -> tent -> grass -> blank.
## Grass is the "definitely not here" mark, which is how the puzzle is
## actually solved.

const Gen = preload("res://puzzles/tents_gen.gd")
const Pal = preload("res://core/palette.gd")
const Shapes = preload("res://core/shapes.gd")

const BLANK := 0
const TENT := 1
const GRASS := 2

var w: int = 7
var h: int = 7
var _trees: Dictionary = {}
var _row_counts: Array = []
var _col_counts: Array = []
var _marks: Dictionary = {}
var _solution_tents: Array = []

var _cell: float = 0.0
var _origin: Vector2 = Vector2.ZERO

func puzzle_id() -> String: return "tents"
func title() -> String: return "Tents"

func rules() -> String:
	return "Pitch one tent orthogonally beside each tree. Tents never touch, not even diagonally. Numbers count the tents in each line."

func build(rng: RandomNumberGenerator, difficulty: int) -> void:
	var pairs := 7
	match difficulty:
		0: w = 6; h = 6; pairs = 5
		1: w = 7; h = 7; pairs = 7
		_: w = 8; h = 8; pairs = 9
	var out: Dictionary = Gen.generate(rng, w, h, pairs)
	_trees.clear()
	for t in out.trees:
		_trees[t] = true
	_solution_tents = out.tents
	_row_counts = out.row_counts
	_col_counts = out.col_counts
	_marks.clear()
	if not resized.is_connected(queue_redraw):
		resized.connect(queue_redraw)
	queue_redraw()

func reset_board() -> void:
	_marks.clear()
	moves = 0
	queue_redraw()

func is_solved() -> bool:
	if _trees.is_empty():
		return false
	var tents: Array = []
	for k in _marks:
		if _marks[k] == TENT:
			tents.append(k)
	return Gen.is_valid_solution(tents, _trees.keys(), _row_counts, _col_counts, w, h)

func share_glyphs() -> String:
	var out := ""
	for y in h:
		for x in w:
			var c := Vector2i(x, y)
			if _trees.has(c):
				out += "🌲"
			elif _marks.get(c, BLANK) == TENT:
				out += "⛺"
			else:
				out += "🟩"
		out += "\n"
	return out

func _gui_input(event: InputEvent) -> void:
	var pos := Vector2.INF
	if event is InputEventScreenTouch and event.pressed:
		pos = event.position
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pos = event.position
	if pos == Vector2.INF or _cell <= 0.0 or is_done():
		return
	var local := pos - _origin
	var c := Vector2i(int(local.x / _cell), int(local.y / _cell))
	if c.x < 0 or c.y < 0 or c.x >= w or c.y >= h or _trees.has(c):
		return
	_marks[c] = (int(_marks.get(c, BLANK)) + 1) % 3
	queue_redraw()
	note_move()

func _draw() -> void:
	if w == 0 or _row_counts.is_empty():
		return
	var font := ThemeDB.fallback_font
	# Leave a gutter for the counts along the top and left.
	var gutter := 54.0
	_cell = minf((size.x - gutter) / float(w), (size.y - gutter) / float(h))
	var board := Vector2(_cell * w, _cell * h)
	_origin = Vector2(gutter + (size.x - gutter - board.x) * 0.5,
		gutter + (size.y - gutter - board.y) * 0.5)

	for x in w:
		draw_string(font, _origin + Vector2(x * _cell, -14), str(_col_counts[x]),
			HORIZONTAL_ALIGNMENT_CENTER, _cell, 34, Pal.TEXT_DIM)
	for y in h:
		draw_string(font, _origin + Vector2(-gutter, y * _cell + _cell * 0.66), str(_row_counts[y]),
			HORIZONTAL_ALIGNMENT_CENTER, gutter - 10, 34, Pal.TEXT_DIM)

	for y in h:
		for x in w:
			var c := Vector2i(x, y)
			var at := _origin + Vector2(x, y) * _cell
			draw_rect(Rect2(at + Vector2(1, 1), Vector2(_cell - 2, _cell - 2)), Pal.SURFACE, true)
			var centre := at + Vector2(_cell, _cell) * 0.5
			if _trees.has(c):
				Shapes.draw_shape(self, Shapes.Kind.TRIANGLE, centre, _cell * 0.3, Pal.GOOD)
			else:
				match int(_marks.get(c, BLANK)):
					TENT:
						Shapes.draw_shape(self, Shapes.Kind.DIAMOND, centre, _cell * 0.3, Pal.ACCENT_2)
					GRASS:
						draw_line(centre - Vector2(_cell, _cell) * 0.12,
							centre + Vector2(_cell, _cell) * 0.12, Pal.LINE, 4.0)
						draw_line(centre + Vector2(-_cell, _cell) * 0.12,
							centre + Vector2(_cell, -_cell) * 0.12, Pal.LINE, 4.0)
