extends "res://ui/hud/panel.gd"

## The first screen's categories: Puzzles, Versus, Arcade, in a row under the
## header and over the list they pick. Each is a chip of the one paper bar,
## its icon beside its word, and the one whose cards are up stands in a
## raised gold pill.
##
## **This was the bottom bar until 2026-10-13** (ui/menu/bottom_bar.gd; the
## user: "Remove the bottom nav, instead add the categories before the game
## list"). The bar had six tabs. Factory is a card of the Arcade list now,
## Streak opens from the header's calendar and the day row's chevron as it
## always did, and Stats from a button on Streak. The row stays up over
## those two pages with nothing lit, and a tap on a category leaves them.
## The first key stays "home": it is still the screen the app opens on.
##
## It keeps the bar's surface -- `picked`, `show_tab`, `_tabs` -- and the
## bar's 2026-09-28 look less what a row at the top has no room for: the
## icon stands beside the word rather than over it (88 tall where the bar
## was 120; the 32 went to the pager's seam at the foot of the screen, see
## PAGER_SEAM in ui/menu.gd), and the end sprigs and the dot under the pill
## are gone.

signal picked(tab: String)

const Icons = preload("res://ui/icons.gd")
const SheetParts = preload("res://ui/hud/sheet_parts.gd")
const Face = preload("res://ui/faces/face.gd")

const HEIGHT := 88.0
const ICON := 40.0
## The word beside the icon, and the room between them.
const WORD := 30
const WORD_GAP := 12
## The tab you are on: a gold pill, its rim, and its glow.
const PILL := Color("ffe6bd")
const PILL_RIM := Color("f4c98a")
const PILL_GLOW := Color(0.96, 0.62, 0.2, 0.26)
## An idle icon's ink: darker than the label's dim, as the mock draws it.
const IDLE_INK := Color("6e6057")
const SPRIG_A := Color(0.55, 0.68, 0.35)
const TABS := [
	{"key": "home", "label": "BAR_HOME", "icon": "puzzle", "live": true},
	{"key": "versus", "label": "BAR_VERSUS", "icon": "swords", "live": true},
	{"key": "arcade", "label": "BAR_ARCADE", "icon": "gamepad", "live": true},
]

var current := "home"
var _tabs: Dictionary = {}
var _pill_mesh: ArrayMesh

func _init() -> void:
	enter_from = Vector2(0, -24)

func _build() -> void:
	var bar := CozyTheme.lifted(Pal.SURFACE, int(HEIGHT * 0.5), 12)
	# Thin top and bottom margins: the pill needs the height more than the
	# rim needs the air.
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
	_repaint()

func _make_tab(tab: Dictionary) -> Control:
	var holder := Control.new()
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.custom_minimum_size.y = HEIGHT - 16.0

	var pill := Panel.new()
	pill.name = "Pill"
	pill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pill.offset_left = 10.0
	pill.offset_right = -10.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = PILL
	sb.set_corner_radius_all(int((HEIGHT - 16.0) * 0.5))
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

	var col := HBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", WORD_GAP)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(col)
	var icon := Control.new()
	icon.name = "Icon"
	icon.custom_minimum_size = Vector2(ICON, ICON)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.resized.connect(func() -> void: icon.pivot_offset = icon.size * 0.5)
	# The idle ink is a shade darker than the label, as the mock draws it. A
	# hole (the pad's buttons) is paper at rest and the pill showing through on.
	icon.draw.connect(func() -> void:
		var on: bool = current == tab.key
		var hole: Color = PILL if on else Pal.SURFACE
		Icons.paint(icon, String(tab.icon), Rect2(Vector2.ZERO, icon.size),
			Pal.ACCENT_2 if on else IDLE_INK, hole))
	col.add_child(icon)
	var label := Label.new()
	label.name = "Label"
	label.text = String(tab.label)
	label.theme_type_variation = "NavLabel"
	label.add_theme_font_size_override("font_size", WORD)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
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

## Which category reads as the one you are on; any other key (Streak,
## Stats) lights none.
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
		parts.icon.queue_redraw()
		parts.label.theme_type_variation = "NavLabelOn" if on else "NavLabel"
