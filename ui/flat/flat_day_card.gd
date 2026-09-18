extends "res://ui/hud/panel.gd"

## The flat screen's day card: a tree, "Day N" over the island's name, on
## cream with the theme's soft bottom edge. The win screen shows a second one
## under the board with the time, moves and hints at its right (set_stats).
## Spec: docs/superpowers/specs/2026-09-18-binairo-flat-design.md, sections 3 and 8.

const Icons = preload("res://ui/icons.gd")

const HEIGHT := 120.0
const ICON := 64.0

var _day: Label
var _island: Label
var _stats: Label

func _init() -> void:
	enter_from = Vector2(-120, 0)

func _build() -> void:
	_inner.add_theme_stylebox_override("panel", CozyTheme.card(Pal.SURFACE, 28, Pal.LINE, 6, 24))
	_inner.custom_minimum_size.y = HEIGHT
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	_inner.add_child(row)
	var icon := Control.new()
	icon.custom_minimum_size = Vector2(ICON, ICON)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.draw.connect(func() -> void: Icons.paint(icon, "tree", Rect2(Vector2.ZERO, icon.size), Pal.LEAF))
	row.add_child(icon)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 0)
	row.add_child(col)
	_day = Label.new()
	_day.theme_type_variation = "CardTitle"
	col.add_child(_day)
	_island = Label.new()
	_island.theme_type_variation = "CardBodyDim"
	col.add_child(_island)
	_stats = Label.new()
	_stats.theme_type_variation = "CardBody"
	_stats.add_theme_font_override("font", CozyTheme.body(700))
	_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_stats.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_stats.visible = false
	row.add_child(_stats)
	set_day(1, "")

func set_day(n: int, island: String) -> void:
	_day.text = "Day %d" % n
	_island.text = island
	_island.visible = island != ""

## The win screen's figures at the card's right; "" hides them.
func set_stats(text: String) -> void:
	_stats.text = text
	_stats.visible = text != ""
