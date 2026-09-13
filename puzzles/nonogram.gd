extends "res://core/puzzle_base.gd"

## Nonogram. Tap a cell to cycle blank -> filled -> marked -> blank.
## The finished grid is the share image, which is this puzzle's real advantage.

const Gen = preload("res://puzzles/nonogram_gen.gd")
const Pal = preload("res://core/palette.gd")

const BLANK := 0
const FILL := 1
const MARK := 2

var w: int = 5
var h: int = 5
var _bitmap: Array = []
var _rows: Array = []
var _cols: Array = []
var _marks: Dictionary = {}

var _cell: float = 0.0
var _origin: Vector2 = Vector2.ZERO
var _gutter: float = 0.0

func puzzle_id() -> String: return "nonogram"
func title() -> String: return "Nonogram"

func rules() -> String:
	return "The numbers give the lengths of the filled runs in each line, in order, with a gap between runs."

func build(rng: RandomNumberGenerator, difficulty: int) -> void:
	match difficulty:
		0: w = 5; h = 5
		1: w = 8; h = 8
		_: w = 10; h = 10
	var out: Dictionary = Gen.generate(rng, w, h)
	_bitmap = out.bitmap
	_rows = out.rows
	_cols = out.cols
	_marks.clear()
	if not resized.is_connected(queue_redraw):
		resized.connect(queue_redraw)
	queue_redraw()

func reset_board() -> void:
	_marks.clear()
	moves = 0
	queue_redraw()

func is_solved() -> bool:
	if _bitmap.is_empty():
		return false
	for y in h:
		for x in w:
			var filled: bool = int(_marks.get(Vector2i(x, y), BLANK)) == FILL
			if filled != (int(_bitmap[y][x]) == 1):
				return false
	return true

func share_glyphs() -> String:
	var out := ""
	for y in h:
		for x in w:
			out += "⬛" if int(_bitmap[y][x]) == 1 else "⬜"
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
	if c.x < 0 or c.y < 0 or c.x >= w or c.y >= h:
		return
	_marks[c] = (int(_marks.get(c, BLANK)) + 1) % 3
	queue_redraw()
	note_move()

func _draw() -> void:
	if _bitmap.is_empty():
		return
	var font := ThemeDB.fallback_font
	_gutter = minf(size.x * 0.26, 190.0)
	_cell = minf((size.x - _gutter) / float(w), (size.y - _gutter) / float(h))
	var board := Vector2(_cell * w, _cell * h)
	_origin = Vector2(_gutter + (size.x - _gutter - board.x) * 0.5,
		_gutter + (size.y - _gutter - board.y) * 0.5)

	var fs := int(clampf(_cell * 0.34, 18.0, 30.0))
	for x in w:
		var txt := ""
		for v in _cols[x]:
			txt += "%d\n" % v
		draw_multiline_string(font, _origin + Vector2(x * _cell, -_gutter + 24.0), txt,
			HORIZONTAL_ALIGNMENT_CENTER, _cell, fs, -1, Pal.TEXT_DIM)
	for y in h:
		var parts: Array = []
		for v in _rows[y]:
			parts.append(str(v))
		draw_string(font, _origin + Vector2(-_gutter, y * _cell + _cell * 0.68),
			" ".join(PackedStringArray(parts)),
			HORIZONTAL_ALIGNMENT_RIGHT, _gutter - 12.0, fs, Pal.TEXT_DIM)

	for y in h:
		for x in w:
			var c := Vector2i(x, y)
			var at := _origin + Vector2(x, y) * _cell
			var state: int = int(_marks.get(c, BLANK))
			var col: Color = Pal.SURFACE
			if state == FILL:
				col = Pal.ACCENT
			draw_rect(Rect2(at + Vector2(1, 1), Vector2(_cell - 2, _cell - 2)), col, true)
			if state == MARK:
				var centre := at + Vector2(_cell, _cell) * 0.5
				var d := _cell * 0.16
				draw_line(centre - Vector2(d, d), centre + Vector2(d, d), Pal.TEXT_DIM, 3.0)
				draw_line(centre + Vector2(-d, d), centre + Vector2(d, -d), Pal.TEXT_DIM, 3.0)
