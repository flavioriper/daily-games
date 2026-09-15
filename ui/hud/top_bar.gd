extends "res://ui/hud/panel.gd"

## The HUD's top row: back, the wordmark (title in the display face with a
## leaf, the motto beneath), then undo, hint with its bouncing count badge,
## and settings. Emits one signal per button; the host decides what they do.
## Spec: docs/superpowers/specs/2026-09-14-binairo-hud-design.md, sections 2 and 5.

signal back
signal undo
signal hint
signal settings

const IconButton = preload("res://ui/hud/icon_button.gd")
const Icons = preload("res://ui/icons.gd")

const BUTTON := Vector2(110, 110)
const LEAF := 36.0
const BADGE_HOP := -6.0
const BADGE_HOP_TIME := 0.3
const BADGE_CYCLE := 2.4

var title_text := ""
var motto_text := ""
## False on the menu, which has nowhere to go back to: a blank of the button's
## size stands in so the wordmark stays centred between it and the gear.
var with_back := true
var back_button: Button
var undo_button: Button
var hint_button: Button
var settings_button: Button
var _title: Label
var _motto: Label
var _bounce: Tween

func _init(title := "", motto := "", back_shown := true) -> void:
	title_text = title
	motto_text = motto
	with_back = back_shown
	enter_from = Vector2(0, -80)

func _make_inner() -> Container:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	return row

func _build() -> void:
	if with_back:
		back_button = _button("chevron_left", back)
	else:
		var blank := Control.new()
		blank.custom_minimum_size = BUTTON
		_inner.add_child(blank)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_theme_constant_override("separation", 0)
	_inner.add_child(words)
	var title_row := HBoxContainer.new()
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	title_row.add_theme_constant_override("separation", 4)
	words.add_child(title_row)
	_title = Label.new()
	_title.theme_type_variation = "Wordmark"
	_title.text = title_text.to_upper()
	title_row.add_child(_title)
	var leaf := Control.new()
	leaf.custom_minimum_size = Vector2(LEAF, LEAF)
	leaf.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	leaf.draw.connect(func() -> void: Icons.paint(leaf, "leaf", Rect2(Vector2.ZERO, leaf.size), Pal.MOSS))
	title_row.add_child(leaf)
	_motto = Label.new()
	_motto.theme_type_variation = "Motto"
	_motto.text = motto_text.to_upper()
	_motto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_motto.visible = motto_text != ""
	words.add_child(_motto)
	undo_button = _button("undo", undo)
	hint_button = _button("bulb", hint)
	settings_button = _button("gear", settings)

func _button(icon: String, sig: Signal) -> Button:
	var b := IconButton.new(icon)
	b.custom_minimum_size = BUTTON
	b.pressed.connect(func() -> void: sig.emit())
	_inner.add_child(b)
	return b

func refresh(puzzle) -> void:
	var caps: Array = puzzle.capabilities() if puzzle != null else []
	var done: bool = puzzle != null and puzzle.is_done()
	undo_button.visible = caps.has("undo")
	hint_button.visible = caps.has("hint")
	undo_button.set_enabled(puzzle != null and puzzle.can_undo() and not done)
	var left: int = puzzle.hints_left() if puzzle != null else 0
	hint_button.set_enabled(left > 0 and not done)
	hint_button.badge = left
	_set_bounce(hint_button.visible and left > 0 and not done)

## The badge hops every BADGE_CYCLE seconds while hints remain. Under
## reduce-motion hop returns null and the badge stays still.
func _set_bounce(on: bool) -> void:
	if not on:
		Motion.stop(_bounce)
		_bounce = null
		return
	if Motion.running(_bounce):
		return
	var badge: Control = hint_button.badge_node()
	_bounce = hint_button.create_tween().set_loops()
	_bounce.tween_callback(func() -> void: Motion.hop(badge, BADGE_HOP, BADGE_HOP_TIME, 0.0, hint_button.badge_rest.y))
	_bounce.tween_interval(BADGE_CYCLE)
