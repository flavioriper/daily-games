extends "res://core/puzzle_base.gd"

## Shikaku. Drag corner to corner to draw a rectangle. Drawing over an existing
## rectangle replaces it, which is far more forgiving than refusing the drag.

const Gen = preload("res://puzzles/shikaku_gen.gd")
const Pal = preload("res://core/palette.gd")

var w: int = 6
var h: int = 6
var _clues: Array = []
var _solution: Array = []
var _rects: Array = []
var _drag_from: Vector2i = Vector2i(-1, -1)
var _drag_to: Vector2i = Vector2i(-1, -1)

var _cell: float = 0.0
var _origin: Vector2 = Vector2.ZERO

func puzzle_id() -> String: return "shikaku"
func title() -> String: return "Shikaku"

func rules() -> String:
	return "Split the grid into rectangles. Each one holds exactly one number, and that number is its area."

func build(rng: RandomNumberGenerator, difficulty: int) -> void:
	var max_area := 6
	match difficulty:
		0: w = 5; h = 5; max_area = 6
		1: w = 6; h = 8; max_area = 9
		_: w = 8; h = 10; max_area = 12
	var out: Dictionary = Gen.generate(rng, w, h, max_area, 3)
	_clues = out.clues
	_solution = out.rects
	_rects = []
	if not resized.is_connected(queue_redraw):
		resized.connect(queue_redraw)
	queue_redraw()

func reset_board() -> void:
	_rects = []
	moves = 0
	queue_redraw()

func is_solved() -> bool:
	# Checked against the rules, not against the stored answer.
	if _clues.is_empty():
		return false
	var covered: Dictionary = {}
	for r in _rects:
		var inside := 0
		for c in _clues:
			if r.has_point(c.pos):
				inside += 1
				if int(c.area) != r.size.x * r.size.y:
					return false
		if inside != 1:
			return false
		for x in range(r.position.x, r.position.x + r.size.x):
			for y in range(r.position.y, r.position.y + r.size.y):
				if covered.has(Vector2i(x, y)):
					return false
				covered[Vector2i(x, y)] = true
	return covered.size() == w * h

func share_glyphs() -> String:
	return "▦ %dx%d · %d moves" % [w, h, moves]

func _cell_at(pos: Vector2) -> Vector2i:
	var local := pos - _origin
	return Vector2i(int(floor(local.x / _cell)), int(floor(local.y / _cell)))

func _gui_input(event: InputEvent) -> void:
	if _cell <= 0.0 or is_done():
		return
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event is InputEventMouseButton and event.button_index != MOUSE_BUTTON_LEFT:
			return
		if event.pressed:
			var c := _cell_at(event.position)
			if c.x < 0 or c.y < 0 or c.x >= w or c.y >= h:
				return
			_drag_from = c
			_drag_to = c
		else:
			if _drag_from.x >= 0:
				_commit()
			_drag_from = Vector2i(-1, -1)
		queue_redraw()
	elif (event is InputEventScreenDrag or event is InputEventMouseMotion) and _drag_from.x >= 0:
		var c := _cell_at(event.position)
		_drag_to = Vector2i(clampi(c.x, 0, w - 1), clampi(c.y, 0, h - 1))
		queue_redraw()

func _pending() -> Rect2i:
	var x0: int = mini(_drag_from.x, _drag_to.x)
	var y0: int = mini(_drag_from.y, _drag_to.y)
	var x1: int = maxi(_drag_from.x, _drag_to.x)
	var y1: int = maxi(_drag_from.y, _drag_to.y)
	return Rect2i(x0, y0, x1 - x0 + 1, y1 - y0 + 1)

func _commit() -> void:
	var r := _pending()
	# A single tap on an existing rectangle clears it.
	if r.size == Vector2i(1, 1):
		for existing in _rects:
			if existing.has_point(r.position):
				_rects.erase(existing)
				queue_redraw()
				note_move()
				return
	var keep: Array = []
	for existing in _rects:
		if not existing.intersects(r):
			keep.append(existing)
	_rects = keep
	_rects.append(r)
	queue_redraw()
	note_move()

func _draw() -> void:
	if w == 0 or _clues.is_empty():
		return
	_cell = minf(size.x / float(w), size.y / float(h))
	var board := Vector2(_cell * w, _cell * h)
	_origin = (size - board) * 0.5

	for y in h:
		for x in w:
			draw_rect(Rect2(_origin + Vector2(x, y) * _cell + Vector2(1, 1),
				Vector2(_cell - 2, _cell - 2)), Pal.SURFACE, true)

	for i in _rects.size():
		var r: Rect2i = _rects[i]
		var col: Color = Pal.CAT[i % Pal.CAT.size()]
		col.a = 0.30
		draw_rect(_screen_rect(r), col, true)
		draw_rect(_screen_rect(r), Pal.CAT[i % Pal.CAT.size()], false, 4.0)

	if _drag_from.x >= 0:
		draw_rect(_screen_rect(_pending()), Pal.ACCENT, false, 6.0)

	var font := ThemeDB.fallback_font
	for c in _clues:
		var at: Vector2 = _origin + Vector2(c.pos.x, c.pos.y) * _cell
		draw_string(font, at + Vector2(0, _cell * 0.68), str(c.area),
			HORIZONTAL_ALIGNMENT_CENTER, _cell, int(_cell * 0.46), Pal.TEXT)

func _screen_rect(r: Rect2i) -> Rect2:
	return Rect2(_origin + Vector2(r.position.x, r.position.y) * _cell,
		Vector2(r.size.x, r.size.y) * _cell)
