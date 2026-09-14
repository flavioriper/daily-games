extends "res://ui/hud/panel.gd"

## The bottom row: the working-line card, Reset in slate and Check in sun.
## Whatever the puzzle does not support is hidden and the rest takes its space.
## Spec: docs/superpowers/specs/2026-09-14-binairo-hud-design.md, sections 2 and 5.

signal reset
signal check

const IconButton = preload("res://ui/hud/icon_button.gd")
const LineCard = preload("res://ui/hud/line_card.gd")

const BUTTON := Vector2(260, 130)
const ALL_GOOD_TIME := 1.2

var line_card: PanelContainer
var reset_button: Button
var check_button: Button
var _all_good: Tween

func _init() -> void:
	enter_from = Vector2(0, 100)

func _make_inner() -> Container:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	return row

func _build() -> void:
	line_card = LineCard.new()
	_inner.add_child(line_card)
	reset_button = IconButton.new("reset", "Reset", "DarkButton")
	reset_button.custom_minimum_size = BUTTON
	reset_button.pressed.connect(func() -> void: reset.emit())
	_inner.add_child(reset_button)
	check_button = IconButton.new("check", "Check", "PrimaryButton")
	check_button.custom_minimum_size = BUTTON
	check_button.pressed.connect(func() -> void: check.emit())
	_inner.add_child(check_button)

func refresh(puzzle) -> void:
	var caps: Array = puzzle.capabilities() if puzzle != null else []
	var done: bool = puzzle != null and puzzle.is_done()
	line_card.visible = caps.has("lines")
	check_button.visible = caps.has("check")
	check_button.set_enabled(not done)
	line_card.refresh(puzzle)

## A clean check: the button says so for a moment and squashes.
func all_good() -> void:
	Motion.stop(_all_good)
	check_button.set_label("All good")
	check_button.squish()
	_all_good = check_button.create_tween()
	_all_good.tween_interval(ALL_GOOD_TIME)
	_all_good.tween_callback(func() -> void: check_button.set_label("Check"))
