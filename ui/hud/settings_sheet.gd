extends "res://ui/hud/sheet.gd"

## The settings sheet: the Reduce motion toggle, a New puzzle row (a
## prototype affordance) and Close.
## Spec: docs/superpowers/specs/2026-09-14-binairo-hud-design.md, sections 2 and 5.

signal reduce_changed(on: bool)
signal new_puzzle

var toggle: CheckButton
var new_button: Button
var close_button: Button

func _build_sheet(col: VBoxContainer) -> void:
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

func _on_open() -> void:
	toggle.set_pressed_no_signal(Motion.reduce)
