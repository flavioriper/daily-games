extends "res://ui/hud/panel.gd"

## The first screen's bottom bar: Puzzles, Versus, Arcade, Valley, Stats,
## Streak.
##
## The first tab was Home until 2026-09-26, when the daily grid became
## Puzzles and Versus joined beside it for the games played against someone
## (snooker first, against the computer; versus/snooker_screen.gd). The key
## stays "home": it is still the screen the app opens on. Arcade joined on
## 2026-09-27 for games played alone for a score (Firefly first;
## arcade/firefly_screen.gd). Valley joined on 2026-10-05 for the slow places
## that share one inventory (the Grove first; valley/grove_screen.gd).
##
## More left with the 3D game on 2026-09-24 (settings has its own button in
## the header). Home is the screen you are on. **All three tabs are real
## since 2026-09-24** (docs/superpowers/specs/2026-09-24-stats-streak-design.md):
## Stats and Streak each open a body over the day row and the grid.
## Spec: docs/superpowers/specs/2026-09-18-flat-menu-design.md, section 1.
##
## Redrawn to the user's mock on 2026-09-28: a paper bar with a hairline rim
## and a leaf sprig growing out of each end, filled icons in a warm dark ink
## (crossed swords for Versus, a game pad for Arcade), and the tab you are
## on standing in a raised gold pill, lettered in ink, with a small sprig on
## its corner and a coral dot under it.

signal picked(tab: String)

const Icons = preload("res://ui/icons.gd")
const SheetParts = preload("res://ui/hud/sheet_parts.gd")
const Face = preload("res://ui/faces/face.gd")

const HEIGHT := 120.0
const ICON := 48.0
## The tab you are on: a gold pill, its rim, and its glow.
const PILL := Color("ffe6bd")
const PILL_RIM := Color("f4c98a")
const PILL_GLOW := Color(0.96, 0.62, 0.2, 0.26)
## Room under the pill for the dot, and the dot itself.
const PILL_FOOT := 14.0
const DOT_R := 4.5
## An idle icon's ink: darker than the label's dim, as the mock draws it.
const IDLE_INK := Color("6e6057")
## Opaque, so leaves crossing in the one mesh do not darken where they meet.
const SPRIG_A := Color(0.55, 0.68, 0.35)
const SPRIG_B := Color(0.71, 0.78, 0.5)
const TABS := [
	{"key": "home", "label": "BAR_HOME", "icon": "puzzle", "live": true},
	{"key": "versus", "label": "BAR_VERSUS", "icon": "swords", "live": true},
	{"key": "arcade", "label": "BAR_ARCADE", "icon": "gamepad", "live": true},
	{"key": "valley", "label": "BAR_VALLEY", "icon": "tree", "live": true},
	{"key": "stats", "label": "BAR_STATS", "icon": "bars", "live": true},
	{"key": "streak", "label": "BAR_STREAK", "icon": "flame", "live": true},
]

var current := "home"
var _tabs: Dictionary = {}
var _sprigs: Control
var _sprig_mesh: ArrayMesh
var _pill_mesh: ArrayMesh

func _init() -> void:
	enter_from = Vector2(0, 40)

func _build() -> void:
	var bar := CozyTheme.lifted(Pal.SURFACE, int(HEIGHT * 0.5), 12)
	# Thin top and bottom margins: the pill, the icon over the word and the
	# dot under them need the height more than the rim needs the air.
	bar.content_margin_top = 8.0
	bar.content_margin_bottom = 8.0
	bar.set_border_width_all(2)
	bar.border_color = Color(Pal.LINE, 0.28)
	_inner.add_theme_stylebox_override("panel", bar)
	_inner.custom_minimum_size.y = HEIGHT
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	_inner.add_child(row)
	for tab in TABS:
		row.add_child(_make_tab(tab))
	# The end sprigs ride over the bar's rim, so they come after the row;
	# they reach past the panel's content rect, which nothing clips.
	_sprigs = Control.new()
	_sprigs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sprigs.resized.connect(func() -> void:
		_sprig_mesh = null
		_sprigs.queue_redraw())
	_sprigs.draw.connect(_draw_sprigs)
	_inner.add_child(_sprigs)
	_repaint()

## One mesh for both ends, built once a size: a long sprig rising out of each
## bottom corner and leaning off the bar, a short one lower and further out.
func _draw_sprigs() -> void:
	var h := _sprigs.size.y
	var w := _sprigs.size.x
	if w <= 0.0:
		return
	if _sprig_mesh == null:
		var b := Face.Builder.new()
		var Draw = SheetParts.Draw
		# Rooted inside the bar's round ends so the leaves stay inside the
		# screen's 40 px margin.
		Draw.sprig(b, Vector2(0.0, h + 8.0), -PI * 0.84, 38.0, 0.3, SPRIG_B, 2)
		Draw.sprig(b, Vector2(w, h + 8.0), -PI * 0.16, 38.0, -0.3, SPRIG_B, 2)
		Draw.sprig(b, Vector2(10.0, h + 6.0), -PI * 0.68, 76.0, 0.45, SPRIG_A)
		Draw.sprig(b, Vector2(w - 10.0, h + 6.0), -PI * 0.32, 76.0, -0.45, SPRIG_A)
		_sprig_mesh = b.mesh()
	_sprigs.draw_mesh(_sprig_mesh, null)

func _make_tab(tab: Dictionary) -> Control:
	var holder := Control.new()
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.custom_minimum_size.y = HEIGHT - 16.0

	# The dot under the pill is the holder's own drawing, under its children.
	holder.draw.connect(func() -> void:
		if current == tab.key:
			holder.draw_circle(Vector2(holder.size.x * 0.5, holder.size.y - DOT_R),
				DOT_R, Pal.ACCENT_2, true, -1.0, true))

	var pill := Panel.new()
	pill.name = "Pill"
	pill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pill.offset_left = 10.0
	pill.offset_right = -10.0
	pill.offset_bottom = -PILL_FOOT
	var sb := StyleBoxFlat.new()
	sb.bg_color = PILL
	sb.set_corner_radius_all(int((HEIGHT - 16.0 - PILL_FOOT) * 0.5))
	sb.set_border_width_all(2)
	sb.border_color = PILL_RIM
	sb.shadow_color = PILL_GLOW
	sb.shadow_size = 12
	sb.shadow_offset = Vector2(0.0, 4.0)
	sb.anti_aliasing_size = 1.2
	pill.add_theme_stylebox_override("panel", sb)
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.visible = false
	# A small sprig on the pill's bottom right corner, as the mock has it.
	pill.draw.connect(func() -> void:
		if _pill_mesh == null:
			var b := Face.Builder.new()
			SheetParts.Draw.sprig(b, Vector2.ZERO, -PI * 0.22, 26.0, -0.3, SPRIG_A, 2)
			_pill_mesh = b.mesh()
		pill.draw_set_transform(Vector2(pill.size.x - 10.0, pill.size.y - 2.0))
		pill.draw_mesh(_pill_mesh, null)
		pill.draw_set_transform(Vector2.ZERO))
	holder.add_child(pill)

	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_bottom = -PILL_FOOT
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(col)
	var icon := Control.new()
	icon.name = "Icon"
	icon.custom_minimum_size = Vector2(ICON, ICON)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.resized.connect(func() -> void: icon.pivot_offset = icon.size * 0.5)
	# The idle ink is a shade darker than the label, as the mock draws it. A
	# hole (the flame's core, the pad's buttons) is paper at rest; on, the
	# flame's core is sun and the pad's buttons are the pill showing through.
	icon.draw.connect(func() -> void:
		var on: bool = current == tab.key
		var hole: Color = (Pal.SUN if tab.icon == "flame" else PILL) if on else Pal.SURFACE
		Icons.paint(icon, String(tab.icon), Rect2(Vector2.ZERO, icon.size),
			Pal.ACCENT_2 if on else IDLE_INK, hole))
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

	_tabs[tab.key] = {"pill": pill, "icon": icon, "label": label, "holder": holder}
	return holder

func _on_tab(tab: Dictionary) -> void:
	picked.emit(String(tab.key))

## Which tab reads as the one you are on.
func show_tab(key: String) -> void:
	if key != current and _tabs.has(key):
		Motion.bump(_tabs[key].icon, 0.18)
	current = key
	_repaint()

func _repaint() -> void:
	for key in _tabs:
		var parts: Dictionary = _tabs[key]
		var on: bool = key == current
		parts.pill.visible = on
		parts.holder.queue_redraw()
		parts.icon.queue_redraw()
		parts.label.theme_type_variation = "NavLabelOn" if on else "NavLabel"
