extends "res://core/puzzle_base.gd"

## Pipe rotation. Tap a piece to turn it. Pieces already fed from the source
## light up, which is the feedback that makes this mechanic feel good.

const Gen = preload("res://puzzles/pipes_gen.gd")
const Pal = preload("res://core/palette.gd")

var w: int = 5
var h: int = 7
var _mask: Array = []
var _rot: Array = []
var _live: Dictionary = {}
var _cell: float = 0.0
var _origin: Vector2 = Vector2.ZERO

func puzzle_id() -> String: return "pipes"
func title() -> String: return "Pipes"

func rules() -> String:
	return "Tap a piece to turn it. Connect every pipe with no loose ends."

func build(rng: RandomNumberGenerator, difficulty: int) -> void:
	match difficulty:
		0: w = 4; h = 5
		1: w = 5; h = 7
		_: w = 6; h = 9
	var out: Dictionary = Gen.generate(rng, w, h)
	_mask = out.mask
	_rot = out.rot
	_recompute_live()
	if not resized.is_connected(queue_redraw):
		resized.connect(queue_redraw)
	queue_redraw()

func reset_board() -> void:
	moves = 0
	_recompute_live()
	queue_redraw()

func is_solved() -> bool:
	return Gen.is_solved(_mask, _rot, w, h)

func share_glyphs() -> String:
	return "🔧 %dx%d · %d turns" % [w, h, moves]

func _gui_input(event: InputEvent) -> void:
	var pos := Vector2.INF
	if event is InputEventScreenTouch and event.pressed:
		pos = event.position
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pos = event.position
	if pos == Vector2.INF or _cell <= 0.0 or is_done():
		return
	var local := pos - _origin
	var x := int(local.x / _cell)
	var y := int(local.y / _cell)
	if x < 0 or y < 0 or x >= w or y >= h:
		return
	_rot[y][x] = (int(_rot[y][x]) + 1) % 4
	_recompute_live()
	queue_redraw()
	note_move()

func _recompute_live() -> void:
	# Flood fill from the top-left cell through matching openings.
	_live.clear()
	var stack: Array = [Vector2i(0, 0)]
	_live[Vector2i(0, 0)] = true
	while not stack.is_empty():
		var cur: Vector2i = stack.pop_back()
		var m: int = Gen.rotate_mask(_mask[cur.y][cur.x], _rot[cur.y][cur.x])
		for bit in [Gen.UP, Gen.RIGHT, Gen.DOWN, Gen.LEFT]:
			if m & bit == 0:
				continue
			var n: Vector2i = cur + Gen.DELTA[bit]
			if n.x < 0 or n.y < 0 or n.x >= w or n.y >= h or _live.has(n):
				continue
			var nm: int = Gen.rotate_mask(_mask[n.y][n.x], _rot[n.y][n.x])
			if nm & Gen.OPPOSITE[bit] != 0:
				_live[n] = true
				stack.append(n)

func _draw() -> void:
	if w == 0:
		return
	_cell = minf(size.x / float(w), size.y / float(h))
	var board := Vector2(_cell * w, _cell * h)
	_origin = (size - board) * 0.5

	var thick := _cell * 0.16
	for y in h:
		for x in w:
			var at := _origin + Vector2(x, y) * _cell
			var centre := at + Vector2(_cell, _cell) * 0.5
			var lit: bool = _live.has(Vector2i(x, y))
			draw_rect(Rect2(at + Vector2(2, 2), Vector2(_cell - 4, _cell - 4)), Pal.SURFACE, true)

			var m: int = Gen.rotate_mask(_mask[y][x], _rot[y][x])
			var col: Color = Pal.ACCENT if lit else Pal.LINE
			for bit in [Gen.UP, Gen.RIGHT, Gen.DOWN, Gen.LEFT]:
				if m & bit == 0:
					continue
				var d: Vector2i = Gen.DELTA[bit]
				draw_line(centre, centre + Vector2(d.x, d.y) * (_cell * 0.5), col, thick)
			# An end piece gets a cap so it reads differently from a corner.
			var count := 0
			for bit in [Gen.UP, Gen.RIGHT, Gen.DOWN, Gen.LEFT]:
				if m & bit != 0:
					count += 1
			if count == 1:
				draw_circle(centre, thick * 1.15, col)
			else:
				draw_circle(centre, thick * 0.62, col)
			if x == 0 and y == 0:
				draw_arc(centre, _cell * 0.36, 0, TAU, 28, Pal.ACCENT_2, 4.0)
