extends "res://core/puzzle_base.gd"

## Light Up. Tap a cell to cycle blank -> bulb -> mark -> blank.
## Light spreads live on every tap, which teaches the rule without reading it.

const Gen = preload("res://puzzles/lightup_gen.gd")
const Pal = preload("res://core/palette.gd")

const BLANK := 0
const BULB := 1
const MARK := 2

var w: int = 6
var h: int = 6
var _grid: Array = []
var _marks: Dictionary = {}
var _lit: Dictionary = {}
var _clash: Dictionary = {}
var _solution_bulbs: Array = []

var _cell: float = 0.0
var _origin: Vector2 = Vector2.ZERO

func puzzle_id() -> String: return "lightup"
func title() -> String: return "Light Up"

func rules() -> String:
	return "Light every white cell. A bulb lights its row and column until a wall. No bulb may light another. Numbers count touching bulbs."

func build(rng: RandomNumberGenerator, difficulty: int) -> void:
	var pct := 0.22
	match difficulty:
		0: w = 5; h = 5; pct = 0.24
		1: w = 6; h = 6; pct = 0.22
		_: w = 7; h = 7; pct = 0.20
	var out: Dictionary = Gen.generate(rng, w, h, pct)
	_grid = out.grid
	_solution_bulbs = out.bulbs
	_marks.clear()
	_recompute()
	if not resized.is_connected(queue_redraw):
		resized.connect(queue_redraw)
	queue_redraw()

func reset_board() -> void:
	_marks.clear()
	moves = 0
	_recompute()
	queue_redraw()

func is_solved() -> bool:
	if _grid.is_empty():
		return false
	var bulbs := _bulbs()
	if bulbs.is_empty():
		return false
	if Gen.bulbs_see_each_other(_grid, bulbs, w, h):
		return false
	if not Gen._clues_exact(_grid, bulbs, w, h):
		return false
	return Gen._all_lit(_grid, bulbs, w, h)

func share_glyphs() -> String:
	return "💡 %dx%d · %d moves" % [w, h, moves]

func _bulbs() -> Array:
	var out: Array = []
	for k in _marks:
		if _marks[k] == BULB:
			out.append(k)
	return out

func _recompute() -> void:
	if _grid.is_empty():
		return
	var bulbs := _bulbs()
	_lit = Gen.lit_cells(_grid, bulbs, w, h)
	_clash.clear()
	var set: Dictionary = {}
	for b in bulbs:
		set[b] = true
	for b in bulbs:
		for d in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
			var p: Vector2i = b + d
			while p.x >= 0 and p.y >= 0 and p.x < w and p.y < h and _grid[p.y][p.x] == Gen.WHITE:
				if set.has(p):
					_clash[b] = true
					_clash[p] = true
				p += d

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
	if _grid[c.y][c.x] != Gen.WHITE:
		return
	_marks[c] = (int(_marks.get(c, BLANK)) + 1) % 3
	_recompute()
	queue_redraw()
	note_move()

func _draw() -> void:
	if _grid.is_empty():
		return
	var font := ThemeDB.fallback_font
	_cell = minf(size.x / float(w), size.y / float(h))
	var board := Vector2(_cell * w, _cell * h)
	_origin = (size - board) * 0.5

	for y in h:
		for x in w:
			var c := Vector2i(x, y)
			var at := _origin + Vector2(x, y) * _cell
			var rect := Rect2(at + Vector2(1, 1), Vector2(_cell - 2, _cell - 2))
			var v: int = _grid[y][x]
			if v != Gen.WHITE:
				draw_rect(rect, Pal.LINE, true)
				if v >= 0:
					draw_string(font, at + Vector2(0, _cell * 0.7), str(v),
						HORIZONTAL_ALIGNMENT_CENTER, _cell, int(_cell * 0.5), Pal.TEXT)
				continue
			draw_rect(rect, Pal.SURFACE_HI if _lit.has(c) else Pal.SURFACE, true)
			var centre := at + Vector2(_cell, _cell) * 0.5
			match int(_marks.get(c, BLANK)):
				BULB:
					var col: Color = Pal.BAD if _clash.has(c) else Pal.ACCENT_2
					draw_circle(centre, _cell * 0.28, col)
					draw_arc(centre, _cell * 0.38, 0, TAU, 24, col, 3.0)
				MARK:
					draw_circle(centre, _cell * 0.08, Pal.TEXT_DIM)
