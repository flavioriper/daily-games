extends "res://ui/hud/panel.gd"

## One puzzle on the menu: a paper card with a diorama of the puzzle's own
## pieces (ui/hud/card_scene.gd), its name, a one-line blurb and a round
## go button in the puzzle's colour. The whole card is the button and
## squashes on press. Emits open; the menu decides what that means.

signal open

const CardScene = preload("res://legacy/ui/hud/card_scene.gd")
const IconButton = preload("res://ui/hud/icon_button.gd")

const SCENE_H := 144.0
const GO := 68.0
const SQUASH := 0.06
const SQUASH_TIME := 0.18
const PRESS_TINT := Color(0.93, 0.91, 0.88)

var entry: Dictionary
var colour: Color
var scene: Control
var _tap: Button
var _press_tw: Tween

func _init(the_entry: Dictionary, the_colour: Color) -> void:
	entry = the_entry
	colour = the_colour
	enter_from = Vector2(0, 60)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _make_inner() -> Container:
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", CozyTheme.paper_card())
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return box

func _build() -> void:
	_inner.resized.connect(func() -> void: _inner.pivot_offset = _inner.size * 0.5)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 6)
	_inner.add_child(col)

	scene = CardScene.new()
	scene.custom_minimum_size = Vector2(0.0, SCENE_H)
	scene.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scene.show_puzzle(String(entry.get("id", "")))
	col.add_child(scene)

	var name_label := Label.new()
	name_label.theme_type_variation = "CardName"
	name_label.text = String(entry.get("title", ""))
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(name_label)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	col.add_child(row)
	var blurb := Label.new()
	blurb.theme_type_variation = "CardBlurb"
	blurb.text = String(entry.get("blurb", ""))
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Three lines, whatever the registry says: a row's cards stand level.
	blurb.max_lines_visible = 3
	blurb.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	blurb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	blurb.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	blurb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(blurb)
	var go := IconButton.new("chevron_right")
	go.custom_minimum_size = Vector2(GO, GO)
	go.size_flags_vertical = Control.SIZE_SHRINK_END
	go.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_paint_go(go)
	row.add_child(go)

	# The tap surface lies over the card, drawn by nothing: the card itself
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

## The go button as a round disc in the puzzle's colour with a cream chevron:
## the same paper button, re-dressed.
func _paint_go(go: Button) -> void:
	var r := int(GO * 0.5)
	go.add_theme_stylebox_override("normal", CozyTheme.card(colour, r, colour.darkened(0.28), 5, 8))
	go.add_theme_stylebox_override("hover", CozyTheme.card(colour, r, colour.darkened(0.28), 5, 8))
	go.add_theme_stylebox_override("pressed", CozyTheme.card(colour.darkened(0.12), r, colour.darkened(0.28), 2, 8))
	go.add_theme_stylebox_override("disabled", CozyTheme.card(Color(colour, 0.55), r, Color(colour.darkened(0.28), 0.55), 5, 8))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		go.add_theme_color_override(state, Pal.SURFACE)

## Draws the diorama again: a card that has been off the grid comes back with
## its picture.
func redraw() -> void:
	if scene != null:
		scene.redraw()

func _press() -> void:
	Motion.stop(_press_tw)
	_inner.scale = Vector2.ONE
	_inner.self_modulate = PRESS_TINT
	_press_tw = Motion.squash(_inner, SQUASH, SQUASH_TIME)

func _release() -> void:
	_inner.self_modulate = Color.WHITE
