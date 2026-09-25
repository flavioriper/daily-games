extends "res://ui/hud/sheet.gd"

## The settings sheet: the Reduce motion and Sound switches, the language,
## How to play and a New puzzle row (both only on a board; the menu leaves
## them out), Credits and Close. How to play is the rules sheet's only door since the tip card went
## (1a04e0a, 2026-09-21). The sheet applies the
## toggle itself, persisting it and stilling the world, so the menu and the
## puzzle host share one behaviour and only refresh their own chrome on
## reduce_changed.
## Spec: docs/superpowers/specs/2026-09-14-binairo-hud-design.md, sections 2 and 5.

const Locale = preload("res://core/locale.gd")
const Icons = preload("res://ui/icons.gd")
const Sound = preload("res://core/sound.gd")
const CreditsSheet = preload("res://ui/hud/credits_sheet.gd")
const Analytics = preload("res://core/analytics.gd")

## The language dropdown's rows, and the chevron and check drawn on them.
const CHOICE_H := 108.0
const MARK := 40.0

signal reduce_changed(on: bool)
signal new_puzzle
signal rules

var with_new := true
var toggle: CheckButton
var sound_toggle: CheckButton
var credits_button: Button
## Opens over this sheet, so closing it lands back here.
var credits_sheet: Control
var rules_button: Button
var new_button: Button
var close_button: Button
## The language dropdown: the row that shows the current language, the
## chevron on it, and the list it opens inside the sheet.
var lang_button: Button
var _lang_name: Label
var _lang_chevron: Control
var _lang_list: VBoxContainer

func _init(show_new := true) -> void:
	with_new = show_new

func _build_sheet(col: VBoxContainer) -> void:
	var title := Label.new()
	title.theme_type_variation = "SheetTitle"
	title.text = "SETTINGS_TITLE"
	col.add_child(title)
	toggle = _switch_row("SETTINGS_REDUCE_MOTION", Motion.reduce, _set_reduce)
	col.add_child(toggle)
	sound_toggle = _switch_row("SETTINGS_SOUND", Sound.on, func(on: bool) -> void:
		Sound.set_on(on)
		Analytics.track("sound_toggled", {"on": on}))
	col.add_child(sound_toggle)
	col.add_child(_build_language())
	rules_button = IconButton.new("help", "RULES_TITLE", "IconButton")
	rules_button.custom_minimum_size.y = ROW
	rules_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rules_button.visible = with_new
	rules_button.pressed.connect(func() -> void:
		close_then(rules.emit))
	col.add_child(rules_button)
	new_button = IconButton.new("reset", "SETTINGS_NEW_PUZZLE", "IconButton")
	new_button.custom_minimum_size.y = ROW
	# Buttons keep their own width, centred, rather than the sheet's.
	new_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	new_button.visible = with_new
	new_button.pressed.connect(func() -> void:
		close_then(new_puzzle.emit))
	col.add_child(new_button)
	credits_button = IconButton.new("heart", "SETTINGS_CREDITS", "IconButton")
	credits_button.custom_minimum_size.y = ROW
	credits_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	credits_button.pressed.connect(func() -> void: credits_sheet.open())
	col.add_child(credits_button)
	close_button = IconButton.new("check", "BTN_CLOSE", "PrimaryButton")
	close_button.custom_minimum_size.y = ROW
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_button.pressed.connect(close)
	col.add_child(close_button)

func _ready() -> void:
	super()
	credits_sheet = CreditsSheet.new()
	credits_sheet.name = "CreditsSheet"
	add_child(credits_sheet)

func _on_open() -> void:
	_set_switch(toggle, Motion.reduce)
	_set_switch(sound_toggle, Sound.on)
	_show_languages(false)

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
	lang_button.custom_minimum_size.y = ROW
	lang_button.text = "TURN_LANGUAGE"
	lang_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	lang_button.add_theme_font_override("font", CozyTheme.body(700))
	lang_button.add_theme_font_size_override("font_size", 34)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		lang_button.add_theme_color_override(state, Pal.TEXT)
	var normal := CozyTheme.card(Pal.SURFACE_HI, 26, Pal.LINE, 6, 28)
	var pressed := CozyTheme.card(Pal.SURFACE_HI.darkened(0.05), 26, Pal.LINE, 3, 28)
	lang_button.add_theme_stylebox_override("normal", normal)
	lang_button.add_theme_stylebox_override("hover", normal)
	lang_button.add_theme_stylebox_override("pressed", pressed)
	lang_button.add_theme_stylebox_override("hover_pressed", pressed)
	lang_button.pressed.connect(func() -> void: _show_languages(not _lang_list.visible))
	# The current language and the chevron sit at the right, where the toggle
	# above keeps its switch.
	var right := HBoxContainer.new()
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	right.offset_left = -360.0
	right.offset_right = -24.0
	right.alignment = BoxContainer.ALIGNMENT_END
	right.add_theme_constant_override("separation", 12)
	lang_button.add_child(right)
	_lang_name = Label.new()
	_lang_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lang_name.add_theme_font_override("font", CozyTheme.body(600))
	_lang_name.add_theme_font_size_override("font_size", 32)
	_lang_name.add_theme_color_override("font_color", Pal.TEXT_DIM)
	_lang_name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	right.add_child(_lang_name)
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
	right.add_child(_lang_chevron)
	box.add_child(lang_button)
	_lang_list = VBoxContainer.new()
	_lang_list.add_theme_constant_override("separation", 10)
	_lang_list.visible = false
	for i in Locale.CODES.size():
		_lang_list.add_child(_language_row(Locale.CODES[i], i))
	box.add_child(_lang_list)
	_show_languages(false)
	return box

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

## A row with a label on the left and a drawn switch on the right; `changed`
## gets the new state. The CheckButton's own box is blanked, because the
## switch is drawn.
func _switch_row(key: String, on: bool, changed: Callable) -> CheckButton:
	var row := CheckButton.new()
	row.text = key
	row.add_theme_font_override("font", CozyTheme.body(700))
	row.add_theme_font_size_override("font_size", 34)
	row.custom_minimum_size.y = ROW
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var blank_image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	blank_image.fill(Color.TRANSPARENT)
	var blank := ImageTexture.create_from_image(blank_image)
	for state in ["checked", "unchecked", "checked_disabled", "unchecked_disabled"]:
		row.add_theme_icon_override(state, blank)
	var normal := CozyTheme.card(Pal.SURFACE_HI, 26, Pal.LINE, 6, 28)
	var pressed := CozyTheme.card(Pal.SURFACE_HI.darkened(0.05), 26, Pal.LINE, 3, 28)
	row.add_theme_stylebox_override("normal", normal)
	row.add_theme_stylebox_override("hover", normal)
	row.add_theme_stylebox_override("pressed", pressed)
	row.add_theme_stylebox_override("hover_pressed", pressed)
	row.set_pressed_no_signal(on)
	var knob := Control.new()
	knob.name = "Switch"
	knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	knob.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	knob.offset_left = -108.0
	knob.offset_right = -20.0
	knob.offset_top = -26.0
	knob.offset_bottom = 26.0
	knob.draw.connect(_draw_switch.bind(row, knob))
	row.add_child(knob)
	row.toggled.connect(func(value: bool) -> void:
		knob.queue_redraw()
		changed.call(value))
	return row

func _set_switch(row: CheckButton, on: bool) -> void:
	row.set_pressed_no_signal(on)
	row.get_node("Switch").queue_redraw()

func _draw_switch(row: CheckButton, knob: Control) -> void:
	var on := row.button_pressed
	var track := StyleBoxFlat.new()
	track.bg_color = Pal.ACCENT if on else Pal.LINE
	track.set_corner_radius_all(26)
	knob.draw_style_box(track, Rect2(Vector2.ZERO, knob.size))
	var knob_x := knob.size.x - 26.0 if on else 26.0
	knob.draw_circle(Vector2(knob_x, knob.size.y * 0.5), 19.0, Pal.SURFACE)

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
