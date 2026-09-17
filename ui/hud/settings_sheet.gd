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

func _init(show_new := true) -> void:
	with_new = show_new

func _build_sheet(col: VBoxContainer) -> void:
	var title := Label.new()
	title.theme_type_variation = "CardTitle"
	title.text = "Settings"
	col.add_child(title)
	toggle = CheckButton.new()
	toggle.text = "Reduce motion"
	toggle.add_theme_font_size_override("font_size", 30)
	toggle.custom_minimum_size.y = ROW * 0.8
	toggle.set_pressed_no_signal(Motion.reduce)
	toggle.toggled.connect(_set_reduce)
	col.add_child(toggle)
	var lang_row := HBoxContainer.new()
	lang_row.add_theme_constant_override("separation", 10)
	var lang_label := Label.new()
	lang_label.text = tr("TURN_LANGUAGE")
	lang_label.add_theme_font_size_override("font_size", 30)
	lang_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lang_row.add_child(lang_label)
	var picker := OptionButton.new()
	picker.custom_minimum_size.y = ROW * 0.8
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
	new_button.visible = with_new
	new_button.pressed.connect(func() -> void:
		new_puzzle.emit()
		close())
	col.add_child(new_button)
	close_button = IconButton.new("check", "Close", "PrimaryButton")
	close_button.custom_minimum_size.y = ROW
	close_button.pressed.connect(close)
	col.add_child(close_button)

func _on_open() -> void:
	toggle.set_pressed_no_signal(Motion.reduce)

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
