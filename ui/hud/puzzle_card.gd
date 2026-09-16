extends "res://ui/hud/panel.gd"

## One puzzle on the menu: its carved wood sign, and nothing else. The sign
## carries the title and the motto as modelled lettering, so the card needs no
## label of its own; the whole board is the button and squashes on press.
## Emits open; the menu decides what that means.
##
## The signs are rendered from art/sign.blend by tools/build_signs.py, one per
## entry in ui/registry.gd, into assets/signs/<id>.png. They are all cut to the
## same frame, so every card in the column comes out the same shape.

signal open

const DIR := "res://assets/signs/"
## The frame tools/build_signs.py renders: the plank plus the leaf sprigs that
## reach past it. The card is as tall as its width divided by this, so a sign
## is never squeezed. It cannot be left to TextureRect's own
## EXPAND_FIT_WIDTH_PROPORTIONAL: that reports no minimum height until it has
## been given a width, and the menu's VBox asks for the minimum first, so
## every card came out zero-high.
const ASPECT := 1024.0 / 372.0
const SQUASH := 0.06
const SQUASH_TIME := 0.18
const PRESS_TINT := Color(0.93, 0.91, 0.88)

var entry: Dictionary
var _sign: TextureRect
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
	var tex: Texture2D = load(DIR + String(entry.get("id", "")) + ".png") as Texture2D
	if tex != null:
		_sign = TextureRect.new()
		_sign.texture = tex
		_sign.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_sign.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_sign.stretch_mode = TextureRect.STRETCH_SCALE
		_inner.add_child(_sign)
		_fit_sign()
	else:
		# A stripped project with no signs rendered still gets a usable menu,
		# the way CozyTheme falls back to the engine font.
		var label := Label.new()
		label.theme_type_variation = "CardTitle"
		label.text = String(entry.get("title", ""))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.custom_minimum_size.y = 148.0
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_inner.add_child(label)
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

## Keeps the sign at the rendered frame's aspect as the list's width changes.
func _fit_sign() -> void:
	if _sign == null:
		return
	var want := roundf(size.x / ASPECT)
	if want > 0.0 and absf(_sign.custom_minimum_size.y - want) > 0.5:
		_sign.custom_minimum_size.y = want

func _press() -> void:
	Motion.stop(_press_tw)
	_inner.scale = Vector2.ONE
	_inner.self_modulate = PRESS_TINT
	_press_tw = Motion.squash(_inner, SQUASH, SQUASH_TIME)

func _release() -> void:
	_inner.self_modulate = Color.WHITE
