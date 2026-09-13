extends "res://core/puzzle_base.gd"

## Untangle. Drag the dots until no lines cross.
## The grabbed node keeps its offset from the fingertip so your thumb does not
## sit on top of the crossing you are trying to fix.

const Gen = preload("res://puzzles/untangle_gen.gd")
const Pal = preload("res://core/palette.gd")

var nodes: int = 9
var _edges: Array = []
var _pos: PackedVector2Array = PackedVector2Array()
var _start: PackedVector2Array = PackedVector2Array()
var _planar: PackedVector2Array = PackedVector2Array()
var _held: int = -1
var _grab_offset: Vector2 = Vector2.ZERO
var _crossings: int = 0

var _rect: Rect2 = Rect2()

func puzzle_id() -> String: return "untangle"
func title() -> String: return "Untangle"

func rules() -> String:
	return "Drag the dots until no two lines cross."

func build(rng: RandomNumberGenerator, difficulty: int) -> void:
	match difficulty:
		0: nodes = 7
		1: nodes = 10
		_: nodes = 14
	var out: Dictionary = Gen.generate(rng, nodes)
	_edges = out.edges
	_start = out.start
	_planar = out.planar
	_pos = out.start.duplicate()
	_crossings = Gen.crossings(_edges, _pos)
	if not resized.is_connected(queue_redraw):
		resized.connect(queue_redraw)
	queue_redraw()

func reset_board() -> void:
	_pos = _start.duplicate()
	_crossings = Gen.crossings(_edges, _pos)
	moves = 0
	queue_redraw()

func is_solved() -> bool:
	return Gen.is_untangled(_edges, _pos)

func share_glyphs() -> String:
	return "🕸 %d nodes · %d moves" % [nodes, moves]

func _to_screen(p: Vector2) -> Vector2:
	return _rect.position + p * _rect.size

func _to_norm(p: Vector2) -> Vector2:
	return (p - _rect.position) / _rect.size

func _gui_input(event: InputEvent) -> void:
	if _rect.size.x <= 0.0 or is_done():
		return
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		var pressed: bool = event.pressed
		var at: Vector2 = event.position
		if event is InputEventMouseButton and event.button_index != MOUSE_BUTTON_LEFT:
			return
		if pressed:
			_held = _nearest(at)
			if _held >= 0:
				_grab_offset = _to_screen(_pos[_held]) - at
		else:
			if _held >= 0:
				note_move()
			_held = -1
		queue_redraw()
	elif (event is InputEventScreenDrag or event is InputEventMouseMotion) and _held >= 0:
		var target := _to_norm(event.position + _grab_offset)
		_pos[_held] = Vector2(clampf(target.x, 0.03, 0.97), clampf(target.y, 0.03, 0.97))
		_crossings = Gen.crossings(_edges, _pos)
		queue_redraw()

func _nearest(at: Vector2) -> int:
	var best := -1
	var best_d := 90.0  # generous thumb-sized grab radius
	for i in _pos.size():
		var d := _to_screen(_pos[i]).distance_to(at)
		if d < best_d:
			best_d = d
			best = i
	return best

func _draw() -> void:
	var pad := 40.0
	var side := minf(size.x, size.y) - pad * 2.0
	_rect = Rect2((size - Vector2(side, side)) * 0.5, Vector2(side, side))

	for e in _edges:
		var a := _to_screen(_pos[e.x])
		var b := _to_screen(_pos[e.y])
		draw_line(a, b, Pal.LINE, 5.0)

	for i in _pos.size():
		var p := _to_screen(_pos[i])
		var r := 30.0 if i == _held else 24.0
		var col: Color = Pal.ACCENT_2 if i == _held else Pal.ACCENT
		draw_circle(p, r, col)

	var msg := ""
	if _crossings > 0:
		msg = "%d crossing%s" % [_crossings, "" if _crossings == 1 else "s"]
	elif Gen.min_separation(_pos) < Gen.MIN_SEP:
		msg = "dots are too close together"
	else:
		msg = "no crossings"
	draw_string(ThemeDB.fallback_font, Vector2(0, size.y - 12), msg,
		HORIZONTAL_ALIGNMENT_CENTER, size.x, 36,
		Pal.GOOD if is_solved() else Pal.TEXT_DIM)
