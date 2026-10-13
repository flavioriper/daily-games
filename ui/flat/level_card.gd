extends "res://ui/hud/panel.gd"

## The flat screen's level card: the board's levels side by side in the day
## card's place and at its height, the one being played ringed, the ones done today checked, and a tap on
## another opens that level without a stop at the menu (the user,
## 2026-10-13: "add a difficulty card ingame screen so user can easily
## switch between them without needing to left game"). A registry entry asks
## for it with `"level_card": true`.
##
## It is the difficulty sheet's row (ui/menu/difficulty_sheet.gd) cut to a
## cell: that sheet's tints, its plaque with the level's sign and its names.

## Another level was tapped.
signal pick(difficulty: int)

const Sheet = preload("res://ui/menu/difficulty_sheet.gd")
const Registry = preload("res://ui/registry.gd")
const Progress = preload("res://core/progress.gd")
const Icons = preload("res://ui/icons.gd")

## The day card's, so the host's top slot is the height it was.
const HEIGHT := 120.0
const RADIUS := 32
const PAD := 12
const GAP := 10
const CELL_RADIUS := 22
const PLAQUE := 56.0
const RING := 4
const DONE := 30.0
const NAME_SIZE := 28

var _entry: Dictionary = {}
var _current := 0
var _cells: Dictionary = {}

func _init(entry: Dictionary = {}, current := 0) -> void:
	_entry = entry
	_current = current
	enter_from = Vector2(0, 100)

func _build() -> void:
	var paper := CozyTheme.lifted(Pal.SURFACE, RADIUS, PAD)
	_inner.add_theme_stylebox_override("panel", paper)
	_inner.custom_minimum_size.y = HEIGHT
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GAP)
	_inner.add_child(row)
	var levels: Array = _entry.get("levels", [])
	for i in levels.size():
		var level: Dictionary = levels[i]
		var d := int(level.get("difficulty", i))
		var cell := _cell(level, d)
		_cells[d] = cell
		row.add_child(cell)
	_ring()

## Another level is the one played now (the host changed boards in place).
func set_current(d: int) -> void:
	_current = d
	_ring()

func _ring() -> void:
	for d: int in _cells:
		var t := clampi(d, 0, 3)
		var tint: Array = Sheet.TINTS[t]
		var here := d == _current
		var ring: Color = (Sheet.NIGHT_RIM if t == 3 else tint[2]) if here else Color.TRANSPARENT
		var cell: Button = _cells[d]
		var up := CozyTheme.chip(tint[0], CELL_RADIUS, ring, RING if here else 0)
		for st in ["normal", "hover", "focus", "disabled"]:
			cell.add_theme_stylebox_override(st, up)
		cell.add_theme_stylebox_override("pressed", CozyTheme.chip(tint[0], CELL_RADIUS, ring, RING if here else 0, true))

func _cell(level: Dictionary, d: int) -> Button:
	var t := clampi(d, 0, 3)
	var tint: Array = Sheet.TINTS[t]
	var night := t == 3
	var cell := Button.new()
	cell.name = "Level%d" % d
	cell.focus_mode = Control.FOCUS_NONE
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cell.pivot_offset = Vector2(0.0, 0.0)
	cell.resized.connect(func() -> void: cell.pivot_offset = cell.size * 0.5)
	cell.pressed.connect(func() -> void:
		Motion.squash(cell, 0.08, 0.18)
		if d != _current:
			pick.emit(d))
	var col := HBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 10)
	cell.add_child(col)
	var plaque := Sheet.LevelPlaque.new(t, tint[1], tint[2])
	plaque.custom_minimum_size = Vector2(PLAQUE, PLAQUE)
	col.add_child(plaque)
	var name_label := Label.new()
	var key := String(level.get("name", ""))
	name_label.text = Sheet.LEVEL_KEYS.get(key, key)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_override("font", CozyTheme.display(700))
	name_label.add_theme_font_size_override("font_size", NAME_SIZE)
	name_label.add_theme_color_override("font_color", Pal.PAPER if night else Pal.TEXT)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(name_label)
	if Progress.completed(Registry.progress_id(_entry, d)):
		var done := Control.new()
		done.mouse_filter = Control.MOUSE_FILTER_IGNORE
		done.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		done.offset_left = -DONE - 4.0
		done.offset_right = -4.0
		done.offset_top = 4.0
		done.offset_bottom = 4.0 + DONE
		done.draw.connect(func() -> void:
			done.draw_circle(done.size * 0.5, done.size.x * 0.5, Pal.SUN if night else Pal.LEAF_DEEP, true, -1.0, true)
			Icons.paint(done, "check", Rect2(done.size * 0.22, done.size * 0.56), Pal.TEXT if night else Pal.SURFACE))
		cell.add_child(done)
	return cell
