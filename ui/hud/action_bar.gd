extends "res://ui/hud/panel.gd"

## The bottom rows: the colour tray above (palette puzzles only), then the
## working-line card, Reset in slate and Check in sun. Whatever the puzzle
## does not support is hidden and the rest takes its space.
## Spec: docs/superpowers/specs/2026-09-14-binairo-hud-design.md, sections 2 and 5;
## docs/superpowers/specs/2026-09-14-codebreak-3d-design.md, section 3.

signal reset
signal check
signal pick(index: int)

const IconButton = preload("res://ui/hud/icon_button.gd")
const LineCard = preload("res://ui/hud/line_card.gd")
const StatusCard = preload("res://ui/hud/status_card.gd")
const PaletteTray = preload("res://ui/hud/palette_tray.gd")

const BUTTON := Vector2(260, 130)
const ALL_GOOD_TIME := 1.2

var tray: PanelContainer
var line_card: PanelContainer
var status_card: PanelContainer
var reset_button: Button
var check_button: Button
var _row: HBoxContainer
var _all_good: Tween

func _init() -> void:
	enter_from = Vector2(0, 100)

func _make_inner() -> Container:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 20)
	return col

func _build() -> void:
	tray = PaletteTray.new()
	tray.name = "Tray"
	tray.visible = false
	tray.pick.connect(func(i: int) -> void: pick.emit(i))
	_inner.add_child(tray)
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 20)
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_inner.add_child(_row)
	line_card = LineCard.new()
	_row.add_child(line_card)
	status_card = StatusCard.new()
	status_card.visible = false
	_row.add_child(status_card)
	reset_button = IconButton.new("reset", "Reset", "DarkButton")
	reset_button.custom_minimum_size = BUTTON
	reset_button.pressed.connect(func() -> void: reset.emit())
	_row.add_child(reset_button)
	check_button = IconButton.new("check", "Check", "PrimaryButton")
	check_button.custom_minimum_size = BUTTON
	check_button.pressed.connect(func() -> void: check.emit())
	_row.add_child(check_button)

func refresh(puzzle) -> void:
	var caps: Array = puzzle.capabilities() if puzzle != null else []
	var done: bool = puzzle != null and puzzle.is_done()
	tray.visible = caps.has("palette")
	tray.refresh(puzzle if tray.visible else null)
	line_card.visible = caps.has("lines")
	status_card.visible = caps.has("status")
	status_card.refresh(puzzle if status_card.visible else null)
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
