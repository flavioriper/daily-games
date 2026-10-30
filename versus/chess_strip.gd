extends Control

## The score sheet: the game's moves in one line under the board, the one on
## show in a pill, each of the player's coloured by its verdict once it has
## one. Drag it sideways; tap a move to see the board as it stood. Drawn as
## one control, a string a move in view, so a long game costs no more than a
## short one.

signal picked(ply: int)

const Pal = preload("res://core/palette.gd")
const Grade = preload("res://versus/chess_grade.gd")
const Board = preload("res://versus/chess_board.gd")

const FONT_SIZE := 32
const GAP := 18.0
const PAD := 12.0
const DRAG := 12.0

var moves: Array = []
## Ply -> grade, for the moves that have one.
var grades := {}
## The move on show, the last one when -1.
var current := -1

var _x: Array = []
var _w: Array = []
var _scroll := 0.0
var _press := Vector2.ZERO
var _pressing := false
var _moved := false
var _font: Font

func _ready() -> void:
	_font = get_theme_font("font", "SheetBody")
	custom_minimum_size.y = 64.0
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_follow)

func set_moves(the_moves: Array) -> void:
	moves = the_moves
	_measure()
	_follow()

func set_current(ply: int) -> void:
	current = ply
	_follow()

func set_grade(ply: int, grade: int) -> void:
	grades[ply] = grade
	queue_redraw()

func clear() -> void:
	moves = []
	grades = {}
	current = -1
	_measure()
	_scroll = 0.0
	queue_redraw()

func _token(ply: int) -> String:
	@warning_ignore("integer_division")
	return ("%d. " % (ply / 2 + 1) if ply % 2 == 0 else "") + String(moves[ply])

func _measure() -> void:
	_x = []
	_w = []
	var at := PAD
	for ply in moves.size():
		var w := _font.get_string_size(_token(ply), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
		_x.append(at)
		_w.append(w)
		at += w + GAP + (GAP * 0.5 if ply % 2 == 1 else 0.0)

func _length() -> float:
	return 0.0 if _x.is_empty() else float(_x.back()) + float(_w.back()) + PAD

## Keeps the move on show in view.
func _follow() -> void:
	var ply: int = moves.size() - 1 if current < 0 else current
	if ply >= 0 and ply < _x.size():
		var left: float = _x[ply] - PAD
		var right: float = _x[ply] + _w[ply] + PAD
		if right - _scroll > size.x:
			_scroll = right - size.x
		elif left < _scroll:
			_scroll = left
	_scroll = clampf(_scroll, 0.0, maxf(_length() - size.x, 0.0))
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	var at := Vector2.ZERO
	var pressed := false
	var released := false
	if event is InputEventScreenTouch and event.index == 0:
		at = event.position
		pressed = event.pressed
		released = not event.pressed
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		at = event.position
		pressed = event.pressed
		released = not event.pressed
	elif event is InputEventScreenDrag and event.index == 0:
		at = event.position
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		at = event.position
	else:
		return
	accept_event()
	if pressed:
		_press = at
		_pressing = true
		_moved = false
	elif released:
		if _pressing and not _moved:
			_tap(at.x)
		_pressing = false
	elif _pressing:
		if absf(at.x - _press.x) > DRAG:
			_moved = true
		if _moved:
			_scroll = clampf(_scroll + _press.x - at.x, 0.0, maxf(_length() - size.x, 0.0))
			_press = at
			queue_redraw()

func _tap(x: float) -> void:
	for ply in moves.size():
		var left: float = _x[ply] - _scroll
		if x >= left - GAP * 0.5 and x <= left + _w[ply] + GAP * 0.5:
			picked.emit(ply)
			return

func _draw() -> void:
	var on: int = moves.size() - 1 if current < 0 else current
	var base := (size.y + FONT_SIZE * 0.72) * 0.5
	for ply in moves.size():
		var x: float = _x[ply] - _scroll
		if x + _w[ply] < 0.0:
			continue
		if x > size.x:
			break
		if ply == on:
			var pill := StyleBoxFlat.new()
			pill.bg_color = Color(Pal.PAPER, 0.92)
			pill.set_corner_radius_all(14)
			draw_style_box(pill, Rect2(x - 8.0, 6.0, _w[ply] + 16.0, size.y - 12.0))
		var ink := Pal.TEXT if ply == on else Color(Pal.PAPER, 0.92)
		var g: int = grades.get(ply, -1)
		if g >= Grade.INACCURACY or g == Grade.BRILLIANT or g == Grade.GREAT:
			ink = Board.BADGE[g].darkened(0.15) if ply == on else Board.BADGE[g].lightened(0.25)
		draw_string(_font, Vector2(x, base), _token(ply), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, ink)
