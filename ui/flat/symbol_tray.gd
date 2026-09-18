extends "res://ui/hud/panel.gd"

## The flat screen's palette: a sun chip, a moon chip and a clear chip under
## the board. Tapping one arms it as the board's brush: it lifts and takes a
## border in its colour, the others rest. The tray only asks; the puzzle owns
## the brush (`brush`, -2 none, -1 clear, 0 sun, 1 moon) and refresh() reads
## it back, so a reset or a solve that drops the brush is shown here too.
## Spec: docs/superpowers/specs/2026-09-18-binairo-flat-design.md, section 5.

## The symbol the player chose: 0 sun, 1 moon, -1 clear.
signal pick(v: int)

const SunFace = preload("res://ui/faces/sun_face.gd")
const MoonFace = preload("res://ui/faces/moon_face.gd")
const Icons = preload("res://ui/icons.gd")

const CHIP := 140.0
const GAP := 24.0
const LIFT := 8.0
const LIFT_TIME := 0.18
const SQUASH := 0.1
const SQUASH_TIME := 0.18
## Faces at the radii the spec names: the sun's rays reach 1.55 R, the moon's
## disc is its own radius.
const SUN_SIZE := 34.0 * 2.0 * 1.55
const MOON_SIZE := 45.0 * 2.0
const CROSS := 60.0
## Chip index -> brush value.
const VALUES := [0, 1, -1]

var chips: Array[Button] = []
var _slots: Array[Control] = []
var _armed := -1
var _lifts: Array = [null, null, null]

func _init() -> void:
	enter_from = Vector2(0, 100)

func _make_inner() -> Container:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", GAP)
	return row

func _build() -> void:
	for i in 3:
		# A plain Control holds each chip so the lift can move the chip
		# freely; a container would put it straight back.
		var slot := Control.new()
		slot.custom_minimum_size = Vector2(CHIP, CHIP + LIFT)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_inner.add_child(slot)
		_slots.append(slot)
		var chip := Button.new()
		chip.name = ["SunChip", "MoonChip", "ClearChip"][i]
		chip.focus_mode = Control.FOCUS_NONE
		chip.size = Vector2(CHIP, CHIP)
		chip.position = Vector2(0.0, LIFT)
		chip.pivot_offset = chip.size * 0.5
		_style(chip, i, false)
		chip.pressed.connect(_on_pressed.bind(i))
		slot.add_child(chip)
		chips.append(chip)
		var face: Control
		match i:
			0:
				face = SunFace.new()
				face.size = Vector2(SUN_SIZE, SUN_SIZE)
			1:
				face = MoonFace.new()
				face.size = Vector2(MOON_SIZE, MOON_SIZE)
			_:
				face = Control.new()
				face.size = Vector2(CROSS, CROSS)
				face.mouse_filter = Control.MOUSE_FILTER_IGNORE
				face.draw.connect(func() -> void: Icons.paint(face, "cross", Rect2(Vector2.ZERO, face.size), Pal.TEXT_DIM))
		# Centred, and a touch up so the chip's bottom edge does not crowd it.
		face.position = (chip.size - face.size) * 0.5 + Vector2(0.0, -3.0)
		chip.add_child(face)
		if face.has_method("set_idle"):
			face.set_idle(true)

## The chip's look, resting or armed: its own fill, the theme's bottom edge,
## and when armed a border all round in its symbol's colour.
func _style(chip: Button, i: int, armed: bool) -> void:
	var fill: Color = [Pal.SUN_TILE, Pal.MOON_TILE, Pal.SURFACE_HI][i]
	var edge: Color = [Pal.SUN, Pal.MOON_INK, Pal.LINE][i]
	var sb := CozyTheme.card(fill, 28, Pal.LINE, 6, 0)
	if armed:
		sb.set_border_width_all(4)
		sb.border_width_bottom = 8
		sb.border_color = edge
	var pressed := CozyTheme.card(fill.lerp(Pal.LINE, 0.15), 28, Pal.LINE, 2, 0)
	for state in ["normal", "hover", "focus"]:
		chip.add_theme_stylebox_override(state, sb)
	chip.add_theme_stylebox_override("pressed", pressed)
	chip.add_theme_stylebox_override("disabled", sb)

func _on_pressed(i: int) -> void:
	Motion.squash(chips[i], SQUASH, SQUASH_TIME)
	pick.emit(VALUES[i])

## Reads the puzzle's brush and shows it: the armed chip lifts with the back
## ease and takes its border, the rest settle back.
func refresh(puzzle) -> void:
	var brush: int = puzzle.get("brush") if puzzle != null and puzzle.get("brush") != null else -2
	var armed := VALUES.find(brush)
	var done: bool = puzzle != null and puzzle.is_done()
	for i in 3:
		chips[i].disabled = done
	if armed == _armed:
		return
	_armed = armed
	for i in 3:
		var chip := chips[i]
		var up := i == armed
		_style(chip, i, up)
		Motion.stop(_lifts[i])
		_lifts[i] = Motion.slide(chip, "position:y", chip.position.y, 0.0 if up else LIFT, LIFT_TIME)
