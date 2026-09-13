extends "res://core/puzzle_base.gd"

## Balance scales. Read the scales, then dial in each shape's weight.
## One shape's weight is given -- without it the scales only ever pin down
## ratios, never actual values.

const Gen = preload("res://puzzles/balance_gen.gd")
const Pal = preload("res://core/palette.gd")
const Shapes = preload("res://core/shapes.gd")

var shapes: int = 3
var _secret: Array = []
var _scales: Array = []
var _anchor: Dictionary = {}
var _guess: Array = []

var _answer_y: float = 0.0
var _answer_w: float = 0.0

func puzzle_id() -> String: return "balance"
func title() -> String: return "Balance"

func rules() -> String:
	return "Every scale balances. One weight is given. Tap a shape below to set what it weighs."

func build(rng: RandomNumberGenerator, difficulty: int) -> void:
	shapes = clampi(2 + difficulty, 2, 4)
	var out: Dictionary = Gen.generate(rng, shapes)
	_secret = out.secret
	_scales = out.scales
	_anchor = out.anchor
	_guess = []
	for i in shapes:
		_guess.append(int(_anchor.value) if i == int(_anchor.shape) else 1)
	if not resized.is_connected(queue_redraw):
		resized.connect(queue_redraw)
	queue_redraw()

func reset_board() -> void:
	for i in shapes:
		_guess[i] = int(_anchor.value) if i == int(_anchor.shape) else 1
	moves = 0
	queue_redraw()

func is_solved() -> bool:
	return _guess == _secret

func share_glyphs() -> String:
	return "⚖️ %d shapes · %d scales" % [shapes, _scales.size()]

func _gui_input(event: InputEvent) -> void:
	var pos := Vector2.INF
	if event is InputEventScreenTouch and event.pressed:
		pos = event.position
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pos = event.position
	if pos == Vector2.INF or _answer_w <= 0.0 or is_done():
		return
	if pos.y < _answer_y:
		return
	var idx := int(pos.x / _answer_w)
	if idx < 0 or idx >= shapes or idx == int(_anchor.shape):
		return
	_guess[idx] = (int(_guess[idx]) % Gen.MAX_W) + 1
	queue_redraw()
	note_move()

func _draw() -> void:
	var font := ThemeDB.fallback_font
	var answer_h := 220.0
	_answer_y = size.y - answer_h
	_answer_w = size.x / float(shapes)

	# --- scales ---
	var n := maxi(_scales.size(), 1)
	var band := _answer_y / float(n)
	var r := minf(band * 0.24, 46.0)
	for i in _scales.size():
		var sc: Dictionary = _scales[i]
		var cy := band * i + band * 0.5
		draw_line(Vector2(size.x * 0.12, cy), Vector2(size.x * 0.88, cy), Pal.LINE, 4.0)
		draw_colored_polygon(PackedVector2Array([
			Vector2(size.x * 0.5, cy), Vector2(size.x * 0.5 - 22, cy + 40),
			Vector2(size.x * 0.5 + 22, cy + 40)]), Pal.LINE)
		_draw_pan(sc.left, size.x * 0.28, cy - r * 1.5, r)
		_draw_pan(sc.right, size.x * 0.72, cy - r * 1.5, r)

	# --- answer row ---
	draw_line(Vector2(0, _answer_y), Vector2(size.x, _answer_y), Pal.LINE, 2.0)
	for i in shapes:
		var cx := _answer_w * (i + 0.5)
		var locked := i == int(_anchor.shape)
		if locked:
			draw_rect(Rect2(_answer_w * i + 6, _answer_y + 6, _answer_w - 12, answer_h - 12),
				Pal.SURFACE_HI, true)
		Shapes.draw_shape(self, i, Vector2(cx, _answer_y + 74), 42.0, Pal.CAT[i])
		var txt := str(_guess[i])
		draw_string(font, Vector2(cx - 30, _answer_y + 186), txt,
			HORIZONTAL_ALIGNMENT_CENTER, 60, 58, Pal.TEXT_DIM if locked else Pal.TEXT)

func _draw_pan(side: Array, cx: float, cy: float, r: float) -> void:
	var total := side.size()
	var step := r * 2.3
	var start := cx - (total - 1) * step * 0.5
	for i in total:
		var idx := int(side[i])
		Shapes.draw_shape(self, idx, Vector2(start + i * step, cy), r, Pal.CAT[idx])
