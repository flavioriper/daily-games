extends "res://ui/hud/sheet.gd"

## What a Versus game's options sheet is made of: rows of chips and switches,
## saved with the game's record (versus/versus_record.gd). The screen reads
## them from there and hears `changed`.

signal changed

const Record = preload("res://versus/versus_record.gd")

const FILL := Color("fcf7ef")

## The game the switches are saved under.
func _game() -> String:
	return ""

## A label and a row of chips, one lit.
func _chips(col: VBoxContainer, key: String, labels: Array, chosen: int, picked: Callable) -> void:
	var kicker := Label.new()
	kicker.text = key
	kicker.theme_type_variation = "MenuKicker"
	col.add_child(kicker)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	col.add_child(row)
	var chips: Array[Button] = []
	for i in labels.size():
		var chip := Button.new()
		chip.text = labels[i]
		chip.focus_mode = Control.FOCUS_NONE
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.custom_minimum_size.y = 84.0
		chip.add_theme_font_size_override("font_size", 32)
		chip.add_theme_color_override("font_color", Pal.TEXT)
		chip.add_theme_color_override("font_hover_color", Pal.TEXT)
		chip.add_theme_color_override("font_pressed_color", Pal.TEXT)
		row.add_child(chip)
		chips.append(chip)
		chip.pressed.connect(func() -> void:
			picked.call(i)
			_light(chips, i)
			changed.emit())
	_light(chips, chosen)

func _light(chips: Array[Button], lit: int) -> void:
	for i in chips.size():
		var box := CozyTheme.lifted(Pal.SURFACE if i == lit else FILL, 24, 12)
		if i == lit:
			box.border_color = Pal.ACCENT_2
			box.set_border_width_all(4)
		for state in ["normal", "hover", "pressed"]:
			chips[i].add_theme_stylebox_override(state, box)

## A line with its reason under it, and a drawn switch at its right, as the
## settings sheet's.
func _switch(col: VBoxContainer, key: String, title: String, sub: String) -> void:
	var row := Button.new()
	row.toggle_mode = true
	row.focus_mode = Control.FOCUS_NONE
	row.custom_minimum_size.y = 96.0
	row.set_pressed_no_signal(bool(Record.option(_game(), key, true)))
	var box := CozyTheme.lifted(FILL, 24, 10)
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		row.add_theme_stylebox_override(state, box)
	var line := HBoxContainer.new()
	line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	line.offset_left = 24.0
	line.offset_right = -20.0
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(line)
	var words := VBoxContainer.new()
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_theme_constant_override("separation", -4)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(words)
	var name_l := Label.new()
	name_l.text = title
	name_l.theme_type_variation = "SheetBody"
	var sub_l := Label.new()
	sub_l.text = sub
	sub_l.theme_type_variation = "CardBlurb"
	sub_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.add_child(name_l)
	words.add_child(sub_l)
	var knob := Control.new()
	knob.custom_minimum_size = Vector2(96.0, 56.0)
	knob.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	knob.draw.connect(func() -> void:
		var lit := row.button_pressed
		var track := StyleBoxFlat.new()
		track.bg_color = Pal.ACCENT_2 if lit else Color(Pal.LINE, 0.55)
		track.set_corner_radius_all(28)
		knob.draw_style_box(track, Rect2(Vector2.ZERO, knob.size))
		var r := knob.size.y * 0.5 - 6.0
		knob.draw_circle(Vector2(knob.size.x - r - 6.0 if lit else r + 6.0, knob.size.y * 0.5), r, Pal.PAPER))
	line.add_child(knob)
	row.toggled.connect(func(value: bool) -> void:
		knob.queue_redraw()
		Record.set_option(_game(), key, value)
		changed.emit())
	col.add_child(row)
