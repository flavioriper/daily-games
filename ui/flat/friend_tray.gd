extends "res://ui/hud/panel.gd"

## The flat Code Break's palette: one chip per friend, six across the column
## and seven on the hard difficulty. A chip is a **direct action, not a
## brush**: tap it and the friend runs into the first free seat, which is
## what the island board's tray does. Nothing here is ever armed, so nothing
## here is ever lit; the chips only dim together when the row is full or the
## game is over.
##
## The chips are built on the first refresh, not in _build: how many there
## are is the puzzle's difficulty, and the host has no puzzle yet when it
## lays out its rows.
## Spec: docs/superpowers/specs/2026-09-18-codebreak-flat-design.md, section 3.

## The friend the player chose, as an index into ui/faces/friends.gd.
signal pick(i: int)

const Friends = preload("res://ui/faces/friends.gd")

const HEIGHT := 150.0
const CHIP_H := 140.0
const GAP := 20.0
## The friend fills this much of the chip's width, as the mock has it.
const PIECE := 0.86
const SQUASH := 0.1
const SQUASH_TIME := 0.18
const DIM := 0.45

var chips: Array[Button] = []
var _faces: Array[Control] = []

func _init() -> void:
	enter_from = Vector2(0, 100)

func _make_inner() -> Container:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", GAP)
	row.custom_minimum_size.y = HEIGHT
	return row

## One chip per friend, sharing the column between them.
func _make_chips(count: int) -> void:
	for chip in chips:
		chip.queue_free()
	chips = []
	_faces = []
	for i in count:
		var chip := Button.new()
		chip.name = "Chip_%d" % i
		chip.focus_mode = Control.FOCUS_NONE
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		chip.custom_minimum_size.y = CHIP_H
		var fill := Friends.tile(i)
		var rest := CozyTheme.card(fill, 28, Pal.LINE, 6, 0)
		var down := CozyTheme.card(fill.lerp(Pal.LINE, 0.15), 28, Pal.LINE, 2, 0)
		for state in ["normal", "hover", "focus", "disabled"]:
			chip.add_theme_stylebox_override(state, rest)
		chip.add_theme_stylebox_override("pressed", down)
		chip.pressed.connect(_on_pressed.bind(i))
		_inner.add_child(chip)
		chips.append(chip)
		var face := Friends.make(i, CHIP_H, Vector2.ZERO)
		chip.add_child(face)
		_faces.append(face)
		# The chip's width is whatever the column leaves it, so the friend is
		# re-seated whenever that changes.
		chip.resized.connect(_fit.bind(i))
		_fit(i)
		face.set_idle(true)

## Centres friend `i` in its chip, a touch up so the bottom edge does not
## crowd it.
func _fit(i: int) -> void:
	var chip: Button = chips[i]
	var seat: float = minf(chip.size.x * PIECE, CHIP_H)
	Friends.resize(_faces[i], seat, chip.size * 0.5 - Vector2(0.0, 3.0))

func _on_pressed(i: int) -> void:
	Motion.squash(chips[i], SQUASH, SQUASH_TIME)
	pick.emit(i)

## Reads the board's palette: how many chips, and whether they take a tap.
func refresh(puzzle) -> void:
	var entries: Array = puzzle.palette() if puzzle != null else []
	if entries.size() != chips.size():
		_make_chips(entries.size())
	for i in chips.size():
		var live: bool = bool(entries[i].get("enabled", true))
		chips[i].disabled = not live
		chips[i].modulate.a = 1.0 if live else DIM
