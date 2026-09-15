extends "res://ui/hud/panel.gd"

## The How to play button that stands where the inline rules card used to,
## at the right of the cards row. It only asks; the host opens the rules
## sheet.
## Spec: docs/superpowers/specs/2026-09-14-binairo-hud-design.md, section 2
## (amendment 2026-09-15).

signal open

const IconButton = preload("res://ui/hud/icon_button.gd")

const HEIGHT := 110.0

var button: Button

func _init() -> void:
	enter_from = Vector2(120, 0)

func _make_inner() -> Container:
	return HBoxContainer.new()

func _build() -> void:
	button = IconButton.new("help", "How to play")
	button.custom_minimum_size.y = HEIGHT
	button.pressed.connect(func() -> void: open.emit())
	_inner.add_child(button)
