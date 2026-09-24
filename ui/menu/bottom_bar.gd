extends "res://ui/hud/panel.gd"

## The first screen's bottom bar: Home, Stats, Streak.
##
## More left with the 3D game on 2026-09-24 (settings has its own button in
## the header). Home is the screen you are on. **All three tabs are real
## since 2026-09-24** (docs/superpowers/specs/2026-09-24-stats-streak-design.md):
## Stats and Streak each open a body over the day row and the grid.
## Spec: docs/superpowers/specs/2026-09-18-flat-menu-design.md, section 1.

signal picked(tab: String)

const Icons = preload("res://ui/icons.gd")

const HEIGHT := 120.0
const ICON := 56.0
const TABS := [
	{"key": "home", "label": "BAR_HOME", "icon": "home", "live": true},
	{"key": "stats", "label": "BAR_STATS", "icon": "trophy", "live": true},
	{"key": "streak", "label": "BAR_STREAK", "icon": "bars", "live": true},
]

var current := "home"
var _tabs: Dictionary = {}

func _init() -> void:
	enter_from = Vector2(0, 40)

func _build() -> void:
	_inner.add_theme_stylebox_override("panel", CozyTheme.lifted(Pal.SURFACE, int(HEIGHT * 0.5), 12))
	_inner.custom_minimum_size.y = HEIGHT
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	_inner.add_child(row)
	for tab in TABS:
		row.add_child(_make_tab(tab))
	_repaint()

func _make_tab(tab: Dictionary) -> Control:
	var holder := Control.new()
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.custom_minimum_size.y = HEIGHT - 24.0

	var pill := Panel.new()
	pill.name = "Pill"
	pill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pill.offset_left = 14.0
	pill.offset_right = -14.0
	pill.add_theme_stylebox_override("panel", CozyTheme.card(Pal.SUN_TILE, int((HEIGHT - 24.0) * 0.5), Pal.SUN_TILE, 0, 0))
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.visible = false
	holder.add_child(pill)

	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 8)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(col)
	var icon := Control.new()
	icon.name = "Icon"
	icon.custom_minimum_size = Vector2(ICON, ICON)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.draw.connect(func() -> void:
		var on: bool = current == tab.key
		Icons.paint(icon, String(tab.icon), Rect2(Vector2.ZERO, icon.size),
			Pal.ACCENT_2 if on else Pal.TEXT))
	col.add_child(icon)
	var label := Label.new()
	label.name = "Label"
	label.text = String(tab.label)
	label.theme_type_variation = "NavLabel"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(label)

	var tap := Button.new()
	tap.flat = true
	tap.focus_mode = Control.FOCUS_NONE
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		tap.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	tap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tap.pressed.connect(_on_tab.bind(tab))
	holder.add_child(tap)

	_tabs[tab.key] = {"pill": pill, "icon": icon, "label": label}
	return holder

func _on_tab(tab: Dictionary) -> void:
	picked.emit(String(tab.key))

## Which tab reads as the one you are on.
func show_tab(key: String) -> void:
	current = key
	_repaint()

func _repaint() -> void:
	for key in _tabs:
		var parts: Dictionary = _tabs[key]
		var on: bool = key == current
		parts.pill.visible = on
		parts.icon.queue_redraw()
		parts.label.theme_type_variation = "NavLabelOn" if on else "NavLabel"
