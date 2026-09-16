extends "res://ui/hud/panel.gd"

## One puzzle on the menu: its carved wood sign, and nothing else. The sign is
## the modelled board (ui/hud/sign_view.gd) with the puzzle's title and motto
## extruded on it, so the card needs no label of its own. The whole board is
## the button and squashes on press. Emits open; the menu decides what that
## means.

signal open

const SignView = preload("res://ui/hud/sign_view.gd")

const SQUASH := 0.06
const SQUASH_TIME := 0.18
const PRESS_TINT := Color(0.93, 0.91, 0.88)

var entry: Dictionary
var _sign: Control
var _tap: Button
var _press_tw: Tween

func _init(the_entry: Dictionary) -> void:
	entry = the_entry
	enter_from = Vector2(0, 60)

func _make_inner() -> Container:
	var box := MarginContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return box

func _build() -> void:
	_inner.resized.connect(func() -> void: _inner.pivot_offset = _inner.size * 0.5)
	resized.connect(_fit_sign)
	_sign = SignView.new()
	_sign.set_words(String(entry.get("title", "")), String(entry.get("motto", "")))
	_inner.add_child(_sign)
	_fit_sign()
	# The tap surface lies over the sign, drawn by nothing: the board itself
	# answers the press.
	_tap = Button.new()
	_tap.flat = true
	_tap.focus_mode = Control.FOCUS_NONE
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		_tap.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_tap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tap.button_down.connect(_press)
	_tap.button_up.connect(_release)
	_tap.pressed.connect(func() -> void: open.emit())
	add_child(_tap)

## The card stands as tall as the board's own proportions ask for the width the
## list gave it. The minimum has to be computed rather than left to the
## viewport: a SubViewportContainer reports no height of its own, and the
## menu's VBox asks for the minimum before anything has a width.
func _fit_sign() -> void:
	if _sign == null:
		return
	var want := roundf(size.x / SignView.ASPECT)
	if want > 0.0 and absf(_sign.custom_minimum_size.y - want) > 0.5:
		_sign.custom_minimum_size.y = want

func _press() -> void:
	Motion.stop(_press_tw)
	_inner.scale = Vector2.ONE
	_inner.self_modulate = PRESS_TINT
	_press_tw = Motion.squash(_inner, SQUASH, SQUASH_TIME)

func _release() -> void:
	_inner.self_modulate = Color.WHITE
