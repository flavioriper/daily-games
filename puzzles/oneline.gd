extends "res://core/puzzle_base.gd"

## One-line drawing. Start on a marked node, then drag along the edges.
## Every edge exactly once, without lifting your finger.

const Gen = preload("res://puzzles/oneline_gen.gd")
const Pal = preload("res://core/palette.gd")

var _edges: Array = []
var _nodes: Array = []
var _pos: Dictionary = {}
var _starts: Array = []
var _done_edges: Dictionary = {}
var _current: int = -1
var _rect: Rect2 = Rect2()

func puzzle_id() -> String: return "oneline"
func title() -> String: return "One Line"

func rules() -> String:
	return "Start on a highlighted dot and drag along every line exactly once, without lifting your finger."

func build(rng: RandomNumberGenerator, difficulty: int) -> void:
	var dims := [[3, 3, 0.55], [4, 3, 0.5], [4, 4, 0.45]]
	var d: Array = dims[clampi(difficulty, 0, 2)]
	var out: Dictionary = Gen.generate(rng, d[0], d[1], d[2])
	_edges = out.edges
	_nodes = out.nodes
	_pos = out.pos
	_starts = out.starts
	_done_edges.clear()
	_current = -1
	if not resized.is_connected(queue_redraw):
		resized.connect(queue_redraw)
	queue_redraw()

func reset_board() -> void:
	_done_edges.clear()
	_current = -1
	moves = 0
	queue_redraw()

func is_solved() -> bool:
	return not _edges.is_empty() and _done_edges.size() == _edges.size()

func share_glyphs() -> String:
	return "✏️ %d lines in one stroke" % _edges.size()

func _screen(n: int) -> Vector2:
	return _rect.position + (_pos[n] as Vector2) * _rect.size

func _gui_input(event: InputEvent) -> void:
	if _rect.size.x <= 0.0 or is_done():
		return
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event is InputEventMouseButton and event.button_index != MOUSE_BUTTON_LEFT:
			return
		if event.pressed:
			var n := _nearest(event.position)
			if n < 0:
				return
			if _current == -1:
				# Must begin at an odd vertex when the figure has any.
				if _starts.is_empty() or _starts.has(n):
					_current = n
					queue_redraw()
			else:
				_try_step(n)
	elif (event is InputEventScreenDrag or event is InputEventMouseMotion) and _current >= 0:
		var n := _nearest(event.position)
		if n >= 0:
			_try_step(n)

func _try_step(n: int) -> void:
	if n == _current:
		return
	var e := Vector2i(mini(_current, n), maxi(_current, n))
	if not _edges.has(e) or _done_edges.has(e):
		return
	_done_edges[e] = true
	_current = n
	queue_redraw()
	note_move()

func _nearest(at: Vector2) -> int:
	var best := -1
	var best_d := 80.0
	for n in _nodes:
		var d := _screen(n).distance_to(at)
		if d < best_d:
			best_d = d
			best = n
	return best

func _draw() -> void:
	if _nodes.is_empty():
		return
	var pad := 40.0
	var side := minf(size.x, size.y) - pad * 2.0
	_rect = Rect2((size - Vector2(side, side)) * 0.5, Vector2(side, side))

	for e in _edges:
		var col: Color = Pal.ACCENT if _done_edges.has(e) else Pal.LINE
		draw_line(_screen(e.x), _screen(e.y), col, 9.0 if _done_edges.has(e) else 5.0)

	for n in _nodes:
		var p := _screen(n)
		var r := 20.0
		var col: Color = Pal.TEXT_DIM
		if n == _current:
			col = Pal.ACCENT_2
			r = 28.0
		elif _current == -1 and (_starts.is_empty() or _starts.has(n)):
			col = Pal.GOOD
			r = 24.0
		draw_circle(p, r, col)

	var left: int = _edges.size() - _done_edges.size()
	draw_string(ThemeDB.fallback_font, Vector2(0, size.y - 12),
		"%d line%s left" % [left, "" if left == 1 else "s"],
		HORIZONTAL_ALIGNMENT_CENTER, size.x, 36,
		Pal.GOOD if left == 0 else Pal.TEXT_DIM)
