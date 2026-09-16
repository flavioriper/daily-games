extends "res://ui/hud/panel.gd"

## The HUD's top row: back, the puzzle's carved sign (the same modelled board
## the menu cards carry, ui/hud/sign_view.gd), then undo, hint with its
## bouncing count badge, and settings. Emits one signal per button; the host
## decides what they do.
## Spec: docs/superpowers/specs/2026-09-14-binairo-hud-design.md, sections 2 and 5.

signal back
signal undo
signal hint
signal settings

const IconButton = preload("res://ui/hud/icon_button.gd")
const SignView = preload("res://ui/hud/sign_view.gd")

## How tall the sign stands in the row. The board is wide (2.274 by 0.827 in
## title_sign.glb), so height is what the row can afford to give it and the
## width follows; SignView widens its own camera rather than cropping when the
## slot it gets is squarer than the board. 180 is all a puzzle's row can use:
## four buttons and their separations leave about 496px between them at 1080
## wide, and 496 / (2.274 / 0.827) is 180.
const SIGN_HEIGHT := 180.0
const BUTTON := Vector2(110, 110)
const BADGE_HOP := -6.0
const BADGE_HOP_TIME := 0.3
const BADGE_CYCLE := 2.4

## Overridable before the row enters the tree. The menu gives its own sign more
## than SIGN_HEIGHT because it carries one button rather than four, and the
## app's title should not read smaller than an entry in its list.
var sign_height := SIGN_HEIGHT
var title_text := ""
var motto_text := ""
## False on the menu, which has nowhere to go back to: a blank of the button's
## size stands in so the sign stays centred between it and the gear.
var with_back := true
var back_button: Button
var undo_button: Button
var hint_button: Button
var settings_button: Button
var _sign: Control
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
	_sign = SignView.new()
	_sign.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sign.custom_minimum_size = Vector2(0.0, sign_height)
	_sign.set_words(title_text, motto_text)
	_inner.add_child(_sign)
	_add_buttons()

## The row's buttons, after the sign that carries the title.
func _add_buttons() -> void:
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
