extends "res://ui/hud/panel.gd"

## The bottom rows: the trays above (a colour tray on palette puzzles, a piece
## tray on puzzles that hand out pieces), then the working-line card, the view
## buttons, Reset in slate and Check in sun. Whatever the puzzle does not
## support is hidden and the rest takes its space.
## Spec: docs/superpowers/specs/2026-09-14-binairo-hud-design.md, sections 2 and 5;
## docs/superpowers/specs/2026-09-14-codebreak-3d-design.md, section 3;
## docs/superpowers/specs/2026-09-15-pipes-iso-design.md, section 5.

signal reset
signal check
signal pick(index: int)
signal piece_pick(index: int)
signal turn_view
## True on the press, false on the release: peek lasts as long as the hold.
signal peek(on: bool)

const IconButton = preload("res://ui/hud/icon_button.gd")
const LineCard = preload("res://legacy/ui/hud/line_card.gd")
const StatusCard = preload("res://legacy/ui/hud/status_card.gd")
const PaletteTray = preload("res://legacy/ui/hud/palette_tray.gd")
const PieceTray = preload("res://legacy/ui/hud/piece_tray.gd")

const BUTTON := Vector2(260, 130)
## The view buttons carry no label, so they need only the glyph's width.
const VIEW_BUTTON := Vector2(150, 130)
const ALL_GOOD_TIME := 1.2

var tray: PanelContainer
var piece_tray: PanelContainer
var line_card: PanelContainer
var status_card: PanelContainer
var turn_button: Button
var peek_button: Button
var reset_button: Button
var check_button: Button
var _row: HBoxContainer
var _all_good: Tween
var _check_label := "Check"

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
	piece_tray = PieceTray.new()
	piece_tray.name = "PieceTray"
	piece_tray.visible = false
	piece_tray.pick.connect(func(i: int) -> void: piece_pick.emit(i))
	_inner.add_child(piece_tray)
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 20)
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_inner.add_child(_row)
	line_card = LineCard.new()
	_row.add_child(line_card)
	status_card = StatusCard.new()
	status_card.visible = false
	_row.add_child(status_card)
	turn_button = IconButton.new("turn", "", "DarkButton")
	turn_button.custom_minimum_size = VIEW_BUTTON
	turn_button.pressed.connect(func() -> void: turn_view.emit())
	_row.add_child(turn_button)
	peek_button = IconButton.new("eye", "", "DarkButton")
	peek_button.custom_minimum_size = VIEW_BUTTON
	# Peek is a hold, not a press: it lasts exactly as long as the finger.
	peek_button.button_down.connect(func() -> void: peek.emit(true))
	peek_button.button_up.connect(func() -> void: peek.emit(false))
	_row.add_child(peek_button)
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
	piece_tray.visible = caps.has("pieces")
	piece_tray.refresh(puzzle if piece_tray.visible else null)
	var view: bool = caps.has("view")
	turn_button.visible = view
	peek_button.visible = view
	line_card.visible = caps.has("lines")
	status_card.visible = caps.has("status")
	status_card.refresh(puzzle if status_card.visible else null)
	check_button.visible = caps.has("check")
	check_button.set_enabled(not done)
	_check_label = puzzle.check_label() if puzzle != null else "Check"
	if not Motion.running(_all_good):
		check_button.set_label(_check_label)
	line_card.refresh(puzzle)

## A clean check: the button says so for a moment and squashes.
func all_good() -> void:
	Motion.stop(_all_good)
	check_button.set_label("All good")
	check_button.squish()
	_all_good = check_button.create_tween()
	_all_good.tween_interval(ALL_GOOD_TIME)
	_all_good.tween_callback(func() -> void: check_button.set_label(_check_label))
