extends "res://ui/hud/sheet.gd"

## The settings sheet: the Reduce motion toggle, a New puzzle row (a
## prototype affordance the menu leaves out) and Close. The sheet applies the
## toggle itself, persisting it and stilling the world, so the menu and the
## puzzle host share one behaviour and only refresh their own chrome on
## reduce_changed.
## Spec: docs/superpowers/specs/2026-09-14-binairo-hud-design.md, sections 2 and 5.

const Locale = preload("res://core/locale.gd")

signal reduce_changed(on: bool)
signal new_puzzle

var with_new := true
var toggle: CheckButton
var new_button: Button
var close_button: Button
var _switch: Control

func _init(show_new := true) -> void:
	with_new = show_new

func _build_sheet(col: VBoxContainer) -> void:
	var title := Label.new()
	title.theme_type_variation = "SheetTitle"
	title.text = "Settings"
	col.add_child(title)
	toggle = CheckButton.new()
	toggle.text = "Reduce motion"
	toggle.add_theme_font_override("font", CozyTheme.body(700))
	toggle.add_theme_font_size_override("font_size", 34)
	toggle.custom_minimum_size.y = ROW
	toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_style_toggle()
	toggle.set_pressed_no_signal(Motion.reduce)
	_switch = Control.new()
	_switch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_switch.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	_switch.offset_left = -108.0
	_switch.offset_right = -20.0
	_switch.offset_top = -26.0
	_switch.offset_bottom = 26.0
	_switch.draw.connect(_draw_switch)
	toggle.add_child(_switch)
	toggle.toggled.connect(func(on: bool) -> void:
		_switch.queue_redraw()
		_set_reduce(on))
	col.add_child(toggle)
	var lang_row := HBoxContainer.new()
	lang_row.add_theme_constant_override("separation", 24)
	lang_row.custom_minimum_size.y = ROW
	var lang_label := Label.new()
	lang_label.text = tr("TURN_LANGUAGE")
	lang_label.theme_type_variation = "SheetBody"
	lang_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lang_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lang_row.add_child(lang_label)
	var picker := OptionButton.new()
	picker.custom_minimum_size = Vector2(260.0, ROW)
	picker.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	picker.add_theme_font_override("font", CozyTheme.body(700))
	picker.add_theme_font_size_override("font_size", 32)
	for i in Locale.CODES.size():
		picker.add_item(Locale.NAMES[Locale.CODES[i]], i)
	picker.select(Locale.CODES.find(Locale.current()))
	picker.item_selected.connect(func(i: int) -> void:
		Locale.set_current(Locale.CODES[i])
		close())
	lang_row.add_child(picker)
	col.add_child(lang_row)
	new_button = IconButton.new("reset", "New puzzle (prototype)", "IconButton")
	new_button.custom_minimum_size.y = ROW
	# Buttons keep their own width, centred, rather than the sheet's.
	new_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	new_button.visible = with_new
	new_button.pressed.connect(func() -> void:
		new_puzzle.emit()
		close())
	col.add_child(new_button)
	close_button = IconButton.new("check", "Close", "PrimaryButton")
	close_button.custom_minimum_size.y = ROW
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_button.pressed.connect(close)
	col.add_child(close_button)

func _on_open() -> void:
	toggle.set_pressed_no_signal(Motion.reduce)
	_switch.queue_redraw()

func _style_toggle() -> void:
	var blank_image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	blank_image.fill(Color.TRANSPARENT)
	var blank := ImageTexture.create_from_image(blank_image)
	for state in ["checked", "unchecked", "checked_disabled", "unchecked_disabled"]:
		toggle.add_theme_icon_override(state, blank)
	var normal := CozyTheme.card(Pal.SURFACE_HI, 26, Pal.LINE, 6, 28)
	var pressed := CozyTheme.card(Pal.SURFACE_HI.darkened(0.05), 26, Pal.LINE, 3, 28)
	toggle.add_theme_stylebox_override("normal", normal)
	toggle.add_theme_stylebox_override("hover", normal)
	toggle.add_theme_stylebox_override("pressed", pressed)
	toggle.add_theme_stylebox_override("hover_pressed", pressed)

func _draw_switch() -> void:
	var on := toggle.button_pressed
	var track := StyleBoxFlat.new()
	track.bg_color = Pal.ACCENT if on else Pal.LINE
	track.set_corner_radius_all(26)
	_switch.draw_style_box(track, Rect2(Vector2.ZERO, _switch.size))
	var knob_x := _switch.size.x - 26.0 if on else 26.0
	_switch.draw_circle(Vector2(knob_x, _switch.size.y * 0.5), 19.0, Pal.SURFACE)

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
