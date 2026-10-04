extends "res://ui/hud/sheet.gd"

## The settings sheet: the Reduce motion, Sound and Vibration switches, the language,
## How to play and a New puzzle row (both only on a board; the menu leaves
## them out), Remove ads (the purchase sheet's door; "Ads removed" and
## disabled once owned -- Restore lives on that sheet, one tap away, which
## is Apple's rule), Privacy choices (only when UMP says the region needs
## the door), Credits and Close. How to play is the rules sheet's only door since the tip card went
## (1a04e0a, 2026-09-21). The sheet applies the
## toggle itself, persisting it and stilling the world, so the menu and the
## puzzle host share one behaviour and only refresh their own chrome on
## reduce_changed.
## Spec: docs/superpowers/specs/2026-09-14-binairo-hud-design.md, sections 2 and 5.

const Locale = preload("res://core/locale.gd")
const Icons = preload("res://ui/icons.gd")
const Sound = preload("res://core/sound.gd")
const Haptics = preload("res://core/haptics.gd")
const CreditsSheet = preload("res://ui/hud/credits_sheet.gd")
const Analytics = preload("res://core/analytics.gd")

## The language dropdown's rows, and the chevron and check drawn on them.
const CHOICE_H := 108.0
const MARK := 40.0
## A setting's row, the plaque on it, and the secondary buttons' height.
const ROW_H := 136.0
const PLAQUE := 80.0
const SMALL_H := 104.0
## The plaques' tints (the HUD mock, 2026-09-28): apricot, sage, lavender;
## Vibration's peach came with its switch (2026-10-03).
const MOTION_TINT := Color("f8c877")
const SOUND_TINT := Color("a8cf9a")
const HAPTICS_TINT := Color("f4b8a4")
const LANGUAGE_TINT := Color("aab4e8")
## Remove ads on taupe paper, Credits on rose with a maroon heart.
const ADS_TINT := Color("ece2d6")
const CREDITS_TINT := Color("f7dedb")
const HEART_INK := Color("8e2f3c")
## A switch that is on.
const SWITCH_ON := Color("6aa477")

signal reduce_changed(on: bool)
signal new_puzzle
signal rules
signal remove_ads

var with_new := true
## How to play without New puzzle: a Versus or Arcade screen, which has a
## tutorial and no day to deal again (ui/hud/screen_tutor.gd sets it).
var with_rules := false:
	set(on):
		with_rules = on
		if _buttons != null:
			_pack_buttons()
var toggle: CheckButton
var sound_toggle: CheckButton
var haptics_toggle: CheckButton
var credits_button: Button
var ads_button: Button
var privacy_button: Button
## Opens over this sheet, so closing it lands back here.
var credits_sheet: Control
var rules_button: Button
var new_button: Button
var close_button: Button
var _buttons: VBoxContainer
## Whether Privacy choices is showing, re-read at every open.
var _privacy := false
## The language dropdown: the row that shows the current language, the
## chevron on it, and the list it opens inside the sheet.
var lang_button: Button
var _lang_name: Label
var _lang_chevron: Control
var _lang_list: VBoxContainer

func _init(show_new := true) -> void:
	with_new = show_new

func _build_sheet(col: VBoxContainer) -> void:
	_title_row(col, "SETTINGS_TITLE", "gear")
	toggle = _switch_row("run", MOTION_TINT, "SETTINGS_REDUCE_MOTION", "SETTINGS_REDUCE_MOTION_SUB",
		Motion.reduce, _set_reduce)
	col.add_child(toggle)
	sound_toggle = _switch_row("music", SOUND_TINT, "SETTINGS_SOUND", "SETTINGS_SOUND_SUB", Sound.on,
		func(on: bool) -> void:
			Sound.set_on(on)
			Analytics.track("sound_toggled", {"on": on}))
	col.add_child(sound_toggle)
	haptics_toggle = _switch_row("buzz", HAPTICS_TINT, "SETTINGS_HAPTICS", "SETTINGS_HAPTICS_SUB", Haptics.on,
		func(on: bool) -> void:
			Haptics.set_on(on)
			Analytics.track("haptics_toggled", {"on": on}))
	col.add_child(haptics_toggle)
	col.add_child(_build_language())
	col.add_child(SheetParts.Divider.new())
	rules_button = _small_button("help", "RULES_TITLE", Pal.SURFACE)
	rules_button.pressed.connect(func() -> void:
		close_then(rules.emit))
	new_button = _small_button("reset", "SETTINGS_NEW_PUZZLE", Pal.SURFACE)
	new_button.pressed.connect(func() -> void:
		close_then(new_puzzle.emit))
	ads_button = _small_button("no_ads", "ADS_TAB", ADS_TINT)
	ads_button.pressed.connect(func() -> void: close_then(remove_ads.emit))
	privacy_button = _small_button("eye", "SETTINGS_PRIVACY", Pal.SURFACE)
	privacy_button.pressed.connect(func() -> void: close_then(Ads.show_privacy_options))
	credits_button = _small_button("heart", "SETTINGS_CREDITS", CREDITS_TINT)
	credits_button.glyph_colour = HEART_INK
	credits_button.pressed.connect(func() -> void: credits_sheet.open())
	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 18)
	col.add_child(_buttons)
	_pack_buttons()
	close_button = _wide_primary("check", "BTN_CLOSE")
	close_button.pressed.connect(close)
	col.add_child(close_button)

## A secondary button on its own tint, sized by the row it is packed into.
func _small_button(icon: String, key: String, fill: Color) -> Button:
	var b := IconButton.new(icon, key, "IconButton")
	b.custom_minimum_size.y = SMALL_H
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var up := CozyTheme.soft_button(fill, 28, false, 20)
	var down := CozyTheme.soft_button(fill, 28, true, 20)
	var off := CozyTheme.soft_button(Color(fill, 0.55), 28, false, 20)
	off.shadow_color = Color(off.shadow_color, 0.0)
	for st in ["normal", "hover"]:
		b.add_theme_stylebox_override(st, up)
	b.add_theme_stylebox_override("pressed", down)
	b.add_theme_stylebox_override("disabled", off)
	return b

## The secondary buttons two to a row, whichever are showing (How to play
## and New puzzle only on a board, Privacy only where UMP asks for it); a
## lone last one stands centred at a row's half width.
func _pack_buttons() -> void:
	var shown: Array[Button] = []
	for b: Button in [rules_button, new_button, ads_button, privacy_button, credits_button]:
		var on := b.visible
		if b == rules_button:
			on = with_new or with_rules
		elif b == new_button:
			on = with_new
		elif b == privacy_button:
			on = _privacy
		if b.get_parent() != null:
			b.get_parent().remove_child(b)
		b.visible = on
		if on:
			shown.append(b)
	for row in _buttons.get_children():
		_buttons.remove_child(row)
		row.queue_free()
	var i := 0
	while i < shown.size():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 18)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		_buttons.add_child(row)
		row.add_child(shown[i])
		if i + 1 < shown.size():
			row.add_child(shown[i + 1])
			shown[i].size_flags_horizontal = Control.SIZE_EXPAND_FILL
			shown[i + 1].size_flags_horizontal = Control.SIZE_EXPAND_FILL
		else:
			# Alone: half the row, centred between two quarter spacers.
			shown[i].size_flags_horizontal = Control.SIZE_EXPAND_FILL
			for at in [0, 2]:
				var pad := Control.new()
				pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
				pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				pad.size_flags_stretch_ratio = 0.5
				row.add_child(pad)
				row.move_child(pad, at)
		i += 2

func _ready() -> void:
	super()
	credits_sheet = CreditsSheet.new()
	credits_sheet.name = "CreditsSheet"
	add_child(credits_sheet)

func _on_open() -> void:
	_set_switch(toggle, Motion.reduce)
	_set_switch(sound_toggle, Sound.on)
	_set_switch(haptics_toggle, Haptics.on)
	_show_languages(false)
	# IconButton letters a child Label and keeps Button.text empty.
	var owned := Store.owns_remove_ads()
	ads_button.set_label(tr("STORE_OWNED") if owned else tr("ADS_TAB"))
	ads_button.set_enabled(not owned)
	var privacy := Ads.privacy_options_required()
	if privacy != _privacy:
		_privacy = privacy
		_pack_buttons()

## The language is a dropdown drawn inside the sheet, not an OptionButton.
## An OptionButton opens a PopupMenu, and a PopupMenu picks and dismisses on
## mouse events only: this project does not emulate the mouse from touch, so
## on the phone the popup opened, ignored every tap, and ate the input of
## everything under it -- the game looked frozen. Rows in the sheet's own
## column are plain Buttons, which take a touch like every other button here.
func _build_language() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	lang_button = Button.new()
	lang_button.focus_mode = Control.FOCUS_NONE
	_dress_row(lang_button)
	lang_button.pressed.connect(func() -> void: _show_languages(not _lang_list.visible))
	# The current language and the chevron on their own small pill at the
	# row's right, where the rows above keep their switch.
	var pill := PanelContainer.new()
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var face := CozyTheme.soft_button(Pal.SURFACE, 22, false, 0)
	face.content_margin_left = 26
	face.content_margin_right = 18
	face.content_margin_top = 12
	face.content_margin_bottom = 12
	pill.add_theme_stylebox_override("panel", face)
	var inner := HBoxContainer.new()
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_theme_constant_override("separation", 14)
	pill.add_child(inner)
	_lang_name = Label.new()
	_lang_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lang_name.add_theme_font_override("font", CozyTheme.body(600))
	_lang_name.add_theme_font_size_override("font_size", 32)
	_lang_name.add_theme_color_override("font_color", Pal.TEXT)
	_lang_name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	inner.add_child(_lang_name)
	_lang_chevron = Control.new()
	_lang_chevron.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lang_chevron.custom_minimum_size = Vector2(MARK, MARK)
	_lang_chevron.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_lang_chevron.draw.connect(func() -> void:
		# chevron_right turned a quarter: down while shut, up while open.
		var c := _lang_chevron.size * 0.5
		var turn := -PI * 0.5 if _lang_list.visible else PI * 0.5
		_lang_chevron.draw_set_transform(c, turn)
		Icons.paint(_lang_chevron, "chevron_right", Rect2(-c, _lang_chevron.size), Pal.TEXT_DIM)
		_lang_chevron.draw_set_transform(Vector2.ZERO))
	inner.add_child(_lang_chevron)
	_row_content(lang_button, "globe", LANGUAGE_TINT, "TURN_LANGUAGE", "SETTINGS_LANGUAGE_SUB", pill)
	box.add_child(lang_button)
	_lang_list = VBoxContainer.new()
	_lang_list.add_theme_constant_override("separation", 10)
	_lang_list.visible = false
	for i in Locale.CODES.size():
		_lang_list.add_child(_language_row(Locale.CODES[i], i))
	box.add_child(_lang_list)
	_show_languages(false)
	return box

## A setting's row face: lifted paper, as tall as ROW_H, its text drawn by
## the children _row_content lays on it rather than by the button.
func _dress_row(row: Button) -> void:
	row.text = ""
	row.custom_minimum_size.y = ROW_H
	var normal := CozyTheme.soft_button(Pal.SURFACE, 26, false, 0)
	var pressed := CozyTheme.soft_button(Pal.SURFACE, 26, true, 0)
	row.add_theme_stylebox_override("normal", normal)
	row.add_theme_stylebox_override("hover", normal)
	row.add_theme_stylebox_override("pressed", pressed)
	row.add_theme_stylebox_override("hover_pressed", pressed)

## What a setting's row shows: the plaque, the label over its sub-line, and
## `trailing` (a switch or the language pill) at the right. Nothing on it
## takes the mouse, so a tap anywhere on the row is the row's.
func _row_content(row: Button, icon: String, tint: Color, key: String, sub_key: String, trailing: Control) -> void:
	var line := HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	line.offset_left = 24.0
	line.offset_right = -24.0
	line.add_theme_constant_override("separation", 26)
	row.add_child(line)
	line.add_child(SheetParts.Plaque.new(icon, tint, PLAQUE))
	var words := VBoxContainer.new()
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_theme_constant_override("separation", 0)
	line.add_child(words)
	var label := Label.new()
	label.text = key
	label.add_theme_font_override("font", CozyTheme.body(800))
	label.add_theme_font_size_override("font_size", 36)
	label.add_theme_color_override("font_color", Pal.TEXT)
	words.add_child(label)
	var sub := Label.new()
	sub.text = sub_key
	sub.add_theme_font_override("font", CozyTheme.body(600))
	sub.add_theme_font_size_override("font_size", 27)
	sub.add_theme_color_override("font_color", Pal.TEXT_DIM)
	sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	sub.clip_text = true
	words.add_child(sub)
	for c in [label, sub]:
		(c as Label).mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(trailing)

## One choice in the open dropdown: the language in its own name, and a check
## on the one being spoken. The difficulty sheet's rows, a size smaller.
func _language_row(code: String, index: int) -> Button:
	var row := Button.new()
	row.focus_mode = Control.FOCUS_NONE
	row.custom_minimum_size.y = CHOICE_H
	row.text = String(Locale.NAMES[code])
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.add_theme_font_override("font", CozyTheme.body(700))
	row.add_theme_font_size_override("font_size", 34)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		row.add_theme_color_override(state, Pal.TEXT)
	var fill: Color = Pal.SURFACE_HI if index % 2 == 0 else Pal.SURFACE
	row.add_theme_stylebox_override("normal", CozyTheme.card(fill, 18, fill, 0, 32))
	row.add_theme_stylebox_override("hover", CozyTheme.card(fill, 18, fill, 0, 32))
	row.add_theme_stylebox_override("pressed", CozyTheme.card(fill.darkened(0.06), 18, fill, 0, 32))
	row.pressed.connect(func() -> void:
		if code != Locale.current():
			Locale.set_current(code)
		_show_languages(false))
	var mark := Control.new()
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	mark.offset_left = -MARK - 28.0
	mark.offset_right = -28.0
	mark.offset_top = -MARK * 0.5
	mark.offset_bottom = MARK * 0.5
	mark.draw.connect(func() -> void:
		if code == Locale.current():
			Icons.paint(mark, "check", Rect2(Vector2.ZERO, mark.size), Pal.LEAF_DEEP))
	row.add_child(mark)
	return row

## Opens or shuts the dropdown and brings the row and its checks up to date.
func _show_languages(open_: bool) -> void:
	_lang_list.visible = open_
	_lang_name.text = String(Locale.NAMES[Locale.current()])
	_lang_chevron.queue_redraw()
	for row in _lang_list.get_children():
		(row.get_child(0) as Control).queue_redraw()

## A setting's row with a drawn switch at its right; `changed` gets the new
## state. The CheckButton's own box is blanked, because the switch is drawn.
func _switch_row(icon: String, tint: Color, key: String, sub_key: String, on: bool, changed: Callable) -> CheckButton:
	var row := CheckButton.new()
	row.focus_mode = Control.FOCUS_NONE
	var blank_image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	blank_image.fill(Color.TRANSPARENT)
	var blank := ImageTexture.create_from_image(blank_image)
	for state in ["checked", "unchecked", "checked_disabled", "unchecked_disabled"]:
		row.add_theme_icon_override(state, blank)
	_dress_row(row)
	# Pressed is "on" for a CheckButton, not a finger on it: the row keeps
	# its face either way and the switch says which.
	var face := row.get_theme_stylebox("normal")
	row.add_theme_stylebox_override("pressed", face)
	row.add_theme_stylebox_override("hover_pressed", face)
	row.set_pressed_no_signal(on)
	var knob := Control.new()
	knob.name = "Switch"
	knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	knob.custom_minimum_size = Vector2(96.0, 56.0)
	knob.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	knob.draw.connect(_draw_switch.bind(row, knob))
	_row_content(row, icon, tint, key, sub_key, knob)
	row.toggled.connect(func(value: bool) -> void:
		knob.queue_redraw()
		changed.call(value))
	return row

func _set_switch(row: CheckButton, on: bool) -> void:
	row.set_pressed_no_signal(on)
	row.find_child("Switch", true, false).queue_redraw()

func _draw_switch(row: CheckButton, knob: Control) -> void:
	var on := row.button_pressed
	var track := StyleBoxFlat.new()
	track.bg_color = SWITCH_ON if on else Color(Pal.LINE, 0.55)
	track.set_corner_radius_all(int(knob.size.y * 0.5))
	track.anti_aliasing_size = 1.0
	knob.draw_style_box(track, Rect2(Vector2.ZERO, knob.size))
	var r := knob.size.y * 0.5
	var knob_x := knob.size.x - r if on else r
	knob.draw_circle(Vector2(knob_x, r + 1.5), r - 5.0, Color(0.3, 0.2, 0.1, 0.14), true, -1.0, true)
	knob.draw_circle(Vector2(knob_x, r), r - 6.0, Pal.SURFACE, true, -1.0, true)

## Persist the toggle and still (or wake) the world, then tell the screen.
func _set_reduce(on: bool) -> void:
	Motion.reduce = on
	Motion.save_settings()
	var stage: Node = get_tree().get_first_node_in_group("stage")
	if stage != null and stage.get("ambient") != null:
		stage.ambient.refresh()
	if stage != null and stage.get("backdrop") != null:
		stage.backdrop.refresh()
	reduce_changed.emit(on)
