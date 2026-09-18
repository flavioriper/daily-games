extends "res://ui/hud/panel.gd"

## The flat screen's action row: Reset in paper at the column's left edge,
## Check in sun with a white label at its right. The same two signals and the
## same `check_button` field as ui/hud/action_bar.gd, so the host's handlers
## and the win harness read it unchanged; a clean Check still says All good.
## Spec: docs/superpowers/specs/2026-09-18-binairo-flat-design.md, section 3.

signal reset
signal check

const IconButton = preload("res://ui/hud/icon_button.gd")

const BUTTON := Vector2(260, 130)
const ALL_GOOD_TIME := 1.2

var reset_button: Button
var check_button: Button
var _all_good: Tween
var _check_label := "Check"

func _init() -> void:
	enter_from = Vector2(0, 100)

func _make_inner() -> Container:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	return row

func _build() -> void:
	reset_button = IconButton.new("reset", "Reset", "IconButton")
	reset_button.custom_minimum_size = BUTTON
	reset_button.pressed.connect(func() -> void: reset.emit())
	_inner.add_child(reset_button)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inner.add_child(spacer)
	check_button = IconButton.new("check", "Check", "SunButton")
	check_button.custom_minimum_size = BUTTON
	check_button.pressed.connect(func() -> void: check.emit())
	_inner.add_child(check_button)

func refresh(puzzle) -> void:
	var caps: Array = puzzle.capabilities() if puzzle != null else []
	var done: bool = puzzle != null and puzzle.is_done()
	check_button.visible = caps.has("check")
	check_button.set_enabled(not done)
	_check_label = puzzle.check_label() if puzzle != null else "Check"
	if not Motion.running(_all_good):
		check_button.set_label(_check_label)

## A clean check: the button says so for a moment and squashes.
func all_good() -> void:
	Motion.stop(_all_good)
	check_button.set_label("All good")
	check_button.squish()
	_all_good = check_button.create_tween()
	_all_good.tween_interval(ALL_GOOD_TIME)
	_all_good.tween_callback(func() -> void: check_button.set_label(_check_label))
