extends "res://ui/hud/panel.gd"

## The HUD's top row: back, the puzzle's carved sign (the same board the menu
## cards are cut from, rendered by tools/build_signs.py), then undo, hint with
## its bouncing count badge, and settings. Emits one signal per button; the
## host decides what they do.
##
## With no sign rendered for this id the row falls back to the drawn plaque it
## used to be -- wordmark, motto, leaf and nails -- so a stripped project still
## has a readable title.
## Spec: docs/superpowers/specs/2026-09-14-binairo-hud-design.md, sections 2 and 5.

signal back
signal undo
signal hint
signal settings

const IconButton = preload("res://ui/hud/icon_button.gd")
const Icons = preload("res://ui/icons.gd")
const Wordmark = preload("res://ui/hud/wordmark.gd")

const SIGN_DIR := "res://assets/signs/"
## How tall the sign stands in the row. The board is wide (the frame
## tools/build_signs.py renders is 1024x372), so height is what the row can
## afford to give it; the width follows, and KEEP_ASPECT_CENTERED shrinks the
## whole board rather than squeezing it when the slot is narrower than that.
## 180 is all a puzzle's row can use: four buttons and their separations leave
## about 496px between them at 1080 wide, and 496 / (1024/372) is 180.
const SIGN_HEIGHT := 180.0
const BUTTON := Vector2(110, 110)
const LEAF := 36.0
const NAIL_R := 8.0
const NAIL_INSET := 27.0
const NAIL_GLINT := 0.35
const LEAF_INSET := 10.0
const BADGE_HOP := -6.0
const BADGE_HOP_TIME := 0.3
const BADGE_CYCLE := 2.4

## Which sign to hang: a registry id, or "daily" for the menu's own.
var sign_id := ""
## Overridable before the row enters the tree. The menu gives its own sign more
## than SIGN_HEIGHT because it carries one button rather than four, and the
## app's title should not read smaller than an entry in its list.
var sign_height := SIGN_HEIGHT
var title_text := ""
var motto_text := ""
## False on the menu, which has nowhere to go back to: a blank of the button's
## size stands in so the wordmark stays centred between it and the gear.
var with_back := true
var back_button: Button
var undo_button: Button
var hint_button: Button
var settings_button: Button
var _sign: TextureRect
var _title: Control
var _motto: Label
var _plaque: PanelContainer
var _bounce: Tween

func _init(sign := "", title := "", motto := "", back_shown := true) -> void:
	sign_id = sign
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
	var tex: Texture2D = load(SIGN_DIR + sign_id + ".png") as Texture2D
	if tex != null:
		_sign = TextureRect.new()
		_sign.texture = tex
		_sign.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_sign.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_sign.custom_minimum_size = Vector2(0.0, sign_height)
		_sign.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_sign.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_inner.add_child(_sign)
		_add_buttons()
		return
	_build_plaque()
	_add_buttons()

## The row's buttons, after whatever carries the title.
func _add_buttons() -> void:
	undo_button = _button("undo", undo)
	hint_button = _button("bulb", hint)
	settings_button = _button("gear", settings)

## The drawn plaque: what the row was before the signs were modelled, kept as
## the fallback. The plaque hugs the title and motto and stays centred between
## the buttons: the CenterContainer takes the expanding slot the words used to.
func _build_plaque() -> void:
	var centre := CenterContainer.new()
	centre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inner.add_child(centre)
	_plaque = PanelContainer.new()
	_plaque.name = "Plaque"
	# A hewn sign rather than another rounded card: the grain shader cuts the
	# board's silhouette and rim from the plaque's size.
	CozyTheme.plank(_plaque, 5.0)
	_plaque.draw.connect(_draw_plaque)
	centre.add_child(_plaque)
	# Room down each side for the two leaves, which are painted on the plaque
	# itself rather than laid out in it: without the margin the bottom-left
	# one landed under the first word of a wide motto.
	var room := int(LEAF + 2.0 * LEAF_INSET)
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", room)
	pad.add_theme_constant_override("margin_right", room)
	_plaque.add_child(pad)
	var words := VBoxContainer.new()
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_theme_constant_override("separation", 0)
	pad.add_child(words)
	var title_row := HBoxContainer.new()
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	title_row.add_theme_constant_override("separation", 4)
	words.add_child(title_row)
	_title = Wordmark.new(title_text.to_upper())
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

func _button(icon: String, sig: Signal) -> Button:
	var b := IconButton.new(icon)
	b.custom_minimum_size = BUTTON
	b.pressed.connect(func() -> void: sig.emit())
	_inner.add_child(b)
	return b

## Two nail heads at the plaque's top corners, each with a glint up and to
## the left, and a second leaf at its bottom-left, mirrored (a negative-width
## rect flips the icon). It sits in the side margin _build keeps for it,
## clear of the motto. The first leaf stays at the title's top-right.
func _draw_plaque() -> void:
	var w := _plaque.size.x
	var h := _plaque.size.y
	for x in [NAIL_INSET, w - NAIL_INSET]:
		var c := Vector2(x, NAIL_INSET)
		_plaque.draw_circle(c, NAIL_R, Pal.OUTLINE)
		_plaque.draw_circle(c - Vector2.ONE * NAIL_R * NAIL_GLINT, NAIL_R * NAIL_GLINT, Color(Pal.SURFACE, 0.55))
	Icons.paint(_plaque, "leaf", Rect2(Vector2(LEAF_INSET + LEAF, h - LEAF - LEAF_INSET), Vector2(-LEAF, LEAF)), Pal.MOSS)

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
