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
const Face = preload("res://ui/faces/face.gd")
const Icons = preload("res://ui/icons.gd")
const Ink = preload("res://ui/flat/ink.gd")
const InkSun = preload("res://ui/faces/ink_sun.gd")
const InkMoon = preload("res://ui/faces/ink_moon.gd")

const CHIP := 140.0
const GAP := 24.0
const LIFT := 8.0
## The row's height: a chip plus the room its lift needs above it. The host
## measures its bottom slot from this.
const HEIGHT := CHIP + LIFT
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
## The ink skin (ui/flat/ink.gd): cream chips with ink symbols, and the clear
## chip an empty dashed outline.
var ink := false
var _dash_mesh: ArrayMesh

func _init(inked := false) -> void:
	ink = inked
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
				face = InkSun.new() if ink else SunFace.new()
				face.size = Vector2(SUN_SIZE, SUN_SIZE)
			1:
				face = InkMoon.new() if ink else MoonFace.new()
				face.size = Vector2(MOON_SIZE, MOON_SIZE) * (0.9 if ink else 1.0)
			_:
				face = Control.new()
				face.size = Vector2(CROSS, CROSS) * (0.7 if ink else 1.0)
				face.mouse_filter = Control.MOUSE_FILTER_IGNORE
				var cross_ink: Color = Ink.INK if ink else Pal.TEXT_DIM
				face.draw.connect(func() -> void: Icons.paint(face, "cross", Rect2(Vector2.ZERO, face.size), cross_ink))
				if ink:
					var dash := Control.new()
					dash.mouse_filter = Control.MOUSE_FILTER_IGNORE
					dash.size = chip.size
					dash.draw.connect(_draw_dashes.bind(dash))
					chip.add_child(dash)
		# Centred, and a touch up so the chip's bottom edge does not crowd it.
		face.position = (chip.size - face.size) * 0.5 + Vector2(0.0, -3.0)
		chip.add_child(face)
		if face.has_method("set_idle"):
			face.set_idle(true)

## The chip's look, resting or armed: its own fill lifted off the page, and
## when armed a border all round in its symbol's colour.
func _style(chip: Button, i: int, armed: bool) -> void:
	if ink:
		var sb: StyleBoxFlat
		if i == 2:
			sb = StyleBoxFlat.new()
			sb.bg_color = Color(Ink.CARD, 0.35)
			sb.set_corner_radius_all(24)
		else:
			sb = Ink.paper(Ink.CARD, 24)
		if armed:
			sb.set_border_width_all(4)
			sb.border_color = Ink.INK
		var down := sb.duplicate() as StyleBoxFlat
		down.bg_color = sb.bg_color.darkened(0.06)
		down.shadow_size = mini(sb.shadow_size, 4)
		for state in ["normal", "hover", "focus", "disabled"]:
			chip.add_theme_stylebox_override(state, sb)
		chip.add_theme_stylebox_override("pressed", down)
		chip.material = Ink.plain()
		return
	var fill: Color = [Pal.SUN_TILE, Pal.MOON_TILE, Pal.SURFACE_HI][i]
	var edge: Color = [Pal.SUN, Pal.MOON_INK, Pal.LINE][i]
	var sb := CozyTheme.chip(fill, 28, edge, 5 if armed else 0)
	var pressed := CozyTheme.chip(fill, 28, edge, 5 if armed else 0, true)
	for state in ["normal", "hover", "focus"]:
		chip.add_theme_stylebox_override(state, sb)
	chip.add_theme_stylebox_override("pressed", pressed)
	chip.add_theme_stylebox_override("disabled", sb)

## The clear chip's dashed outline, round its rounded rectangle, built once
## into one mesh (a canvas command a dash would be two dozen draw calls).
func _draw_dashes(ci: Control) -> void:
	if _armed == 2:
		return
	if _dash_mesh == null:
		var inset := 3.0
		var pts := Face.Builder.round_rect(Vector2(inset, inset), ci.size - Vector2(inset, inset) * 2.0, 22.0)
		pts.append(pts[0])
		var mb := Face.Builder.new()
		var dash := 12.0
		var gap := 9.0
		var on := true
		var left := dash
		var seg := PackedVector2Array([pts[0]])
		for k in range(1, pts.size()):
			var a := pts[k - 1]
			var z := pts[k]
			var d := a.distance_to(z)
			var t := 0.0
			while d - t > left:
				t += left
				var p := a.lerp(z, t / d)
				if on:
					seg.append(p)
					mb.stroke(seg, 2.5, Color(Ink.INK_DIM, 0.8))
				seg = PackedVector2Array([p])
				on = not on
				left = dash if on else gap
			left -= d - t
			if on:
				seg.append(z)
			else:
				seg = PackedVector2Array([z])
		_dash_mesh = mb.mesh()
	ci.draw_mesh(_dash_mesh, null)

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
		for child in chip.get_children():
			child.queue_redraw()
		Motion.stop(_lifts[i])
		_lifts[i] = Motion.slide(chip, "position:y", chip.position.y, 0.0 if up else LIFT, LIFT_TIME)
