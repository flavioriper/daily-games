extends "res://core/puzzle_base.gd"

## Mastermind. Tap a slot to cycle its token, then Check.
## Every token is a colour AND a shape, so nothing depends on hue alone.

const Gen = preload("res://puzzles/mastermind_gen.gd")
const Pal = preload("res://core/palette.gd")
const Shapes = preload("res://core/shapes.gd")

var length: int = 4
var palette: int = 6
var max_guesses: int = 10

var _code: Array = []
var _guesses: Array = []
var _marks: Array = []
var _current: Array = []
var _revealed: bool = false

var _row_h: float = 0.0
var _check: Button

func puzzle_id() -> String: return "mastermind"
func title() -> String: return "Code Break"

func rules() -> String:
	return "Crack the hidden row. After each check: filled = right token in the right place, hollow = right token, wrong place."

func build(rng: RandomNumberGenerator, difficulty: int) -> void:
	var repeats := true
	match difficulty:
		0: length = 4; palette = 6; max_guesses = 10; repeats = false
		1: length = 4; palette = 6; max_guesses = 8;  repeats = true
		_: length = 5; palette = 7; max_guesses = 9;  repeats = true

	_code = Gen.make_code(rng, length, palette, repeats)
	_guesses = []
	_marks = []
	_revealed = false
	_current = []
	for i in length:
		_current.append(0)

	if _check == null:
		_check = Button.new()
		_check.text = "Check"
		_check.add_theme_font_size_override("font_size", 40)
		_check.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		_check.offset_top = -120
		_check.offset_bottom = 0
		_check.pressed.connect(_submit)
		add_child(_check)
	if not resized.is_connected(queue_redraw):
		resized.connect(queue_redraw)
	queue_redraw()

func reset_board() -> void:
	_guesses = []
	_marks = []
	_revealed = false
	for i in length:
		_current[i] = 0
	moves = 0
	queue_redraw()

func is_solved() -> bool:
	return _marks.size() > 0 and int(_marks[-1].exact) == length

func share_glyphs() -> String:
	# Structurally identical to Wordle's share grid, with zero language content.
	var out := ""
	for m in _marks:
		out += "🟩".repeat(int(m.exact)) + "🟨".repeat(int(m.colour))
		out += "⬛".repeat(length - int(m.exact) - int(m.colour)) + "\n"
	return out

func _submit() -> void:
	if is_done() or _revealed:
		return
	_marks.append(Gen.score(_current, _code))
	_guesses.append(_current.duplicate())
	if _guesses.size() >= max_guesses and int(_marks[-1].exact) != length:
		_revealed = true
	queue_redraw()
	note_move()

func _gui_input(event: InputEvent) -> void:
	var pos := Vector2.INF
	if event is InputEventScreenTouch and event.pressed:
		pos = event.position
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pos = event.position
	if pos == Vector2.INF or _row_h <= 0.0 or is_done() or _revealed:
		return
	var row := int(pos.y / _row_h)
	if row != _guesses.size():
		return
	var slot_w := (size.x * 0.72) / float(length)
	var slot := int(pos.x / slot_w)
	if slot < 0 or slot >= length:
		return
	_current[slot] = (int(_current[slot]) + 1) % palette
	queue_redraw()

func _draw() -> void:
	var usable := size.y - 140.0
	_row_h = usable / float(max_guesses + 1)
	var slot_w := (size.x * 0.72) / float(length)
	var r := minf(slot_w, _row_h) * 0.34

	for row in max_guesses:
		var y := row * _row_h + _row_h * 0.5
		var pegs: Array = []
		var active := false
		if row < _guesses.size():
			pegs = _guesses[row]
		elif row == _guesses.size() and not _revealed and not is_done():
			pegs = _current
			active = true

		if active:
			draw_rect(Rect2(0, row * _row_h + 4, size.x, _row_h - 8), Pal.SURFACE, true)
		if pegs.is_empty():
			for s in length:
				draw_arc(Vector2(slot_w * (s + 0.5), y), r * 0.5, 0, TAU, 20, Pal.LINE, 2.0)
			continue

		for s in pegs.size():
			var centre := Vector2(slot_w * (s + 0.5), y)
			Shapes.draw_shape(self, int(pegs[s]) % Shapes.Kind.size(), centre, r, Pal.CAT[int(pegs[s]) % Pal.CAT.size()])

		if row < _marks.size():
			_draw_marks(_marks[row], Vector2(size.x * 0.76, y), r * 0.42)

	# Reveal the answer once the guesses run out.
	if _revealed:
		var y2 := max_guesses * _row_h + _row_h * 0.5
		draw_string(ThemeDB.fallback_font, Vector2(0, y2 - r * 2), "Out of guesses:",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Pal.BAD)
		for s in _code.size():
			Shapes.draw_shape(self, int(_code[s]) % Shapes.Kind.size(),
				Vector2(slot_w * (s + 0.5), y2 + r), r, Pal.CAT[int(_code[s]) % Pal.CAT.size()])

func _draw_marks(m: Dictionary, at: Vector2, r: float) -> void:
	var i := 0
	var per_row := 3
	for k in int(m.exact):
		var p := at + Vector2((i % per_row) * r * 3.0, (i / per_row) * r * 3.0)
		draw_circle(p, r, Pal.TEXT)
		i += 1
	for k in int(m.colour):
		var p := at + Vector2((i % per_row) * r * 3.0, (i / per_row) * r * 3.0)
		draw_arc(p, r, 0, TAU, 18, Pal.TEXT_DIM, 2.5)
		i += 1
