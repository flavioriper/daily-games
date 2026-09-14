extends Control

## A modal bottom sheet: a scrim and a paper card that slides up with the
## Reduce motion toggle, a New puzzle row (a prototype affordance) and Close.
## Hidden until open(); tapping the scrim closes it.
## Spec: docs/superpowers/specs/2026-09-14-binairo-hud-design.md, sections 2 and 5.

signal reduce_changed(on: bool)
signal new_puzzle
signal closed

const Motion = preload("res://core/motion.gd")
const CozyTheme = preload("res://ui/theme.gd")
const IconButton = preload("res://ui/hud/icon_button.gd")
const Pal = preload("res://core/palette.gd")

const SLIDE := 0.3
const FADE := 0.2
const OFFSET := 300.0
const MARGIN := 40.0
const ROW := 110.0

var toggle: CheckButton
var new_button: Button
var close_button: Button
var _scrim: ColorRect
var _card: PanelContainer
var _tw: Tween

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	_scrim = ColorRect.new()
	_scrim.color = Color(Pal.OUTLINE, 0.35)
	_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scrim.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventScreenTouch and ev.pressed:
			close())
	add_child(_scrim)
	_card = PanelContainer.new()
	_card.add_theme_stylebox_override("panel", CozyTheme.paper_card())
	_card.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_card.offset_left = MARGIN
	_card.offset_right = -MARGIN
	_card.offset_bottom = -MARGIN
	add_child(_card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 20)
	_card.add_child(col)
	var title := Label.new()
	title.theme_type_variation = "CardTitle"
	title.text = "Settings"
	col.add_child(title)
	toggle = CheckButton.new()
	toggle.text = "Reduce motion"
	toggle.custom_minimum_size.y = ROW * 0.8
	toggle.set_pressed_no_signal(Motion.reduce)
	toggle.toggled.connect(func(on: bool) -> void: reduce_changed.emit(on))
	col.add_child(toggle)
	new_button = IconButton.new("reset", "New puzzle (prototype)", "IconButton")
	new_button.custom_minimum_size.y = ROW
	new_button.pressed.connect(func() -> void:
		new_puzzle.emit()
		close())
	col.add_child(new_button)
	close_button = IconButton.new("check", "Close", "PrimaryButton")
	close_button.custom_minimum_size.y = ROW
	close_button.pressed.connect(close)
	col.add_child(close_button)

## The card's resting y: anchored to the bottom above the margin.
func _rest_y() -> float:
	return size.y - MARGIN - _card.size.y

func open() -> void:
	visible = true
	toggle.set_pressed_no_signal(Motion.reduce)
	Motion.stop(_tw)
	var rest := _rest_y()
	_tw = Motion.slide(_card, "position:y", rest + OFFSET, rest, SLIDE)
	Motion.appear(_scrim, 0.0, 1.0, FADE)

func close() -> void:
	if not visible:
		return
	Motion.stop(_tw)
	var rest := _rest_y()
	var slide: Tween = Motion.slide(_card, "position:y", rest, rest + OFFSET, SLIDE, 0.0, false)
	Motion.appear(_scrim, 1.0, 0.0, FADE)
	if slide == null:
		visible = false
		closed.emit()
		return
	_tw = slide
	slide.finished.connect(func() -> void:
		visible = false
		closed.emit())
