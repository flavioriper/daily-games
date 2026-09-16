extends "res://ui/hud/panel.gd"

## The wooden day card: an island icon, "Day N" and the island's name. The host
## sets both from core/progress.gd on every spawn.
## Spec: docs/superpowers/specs/2026-09-14-binairo-hud-design.md, section 2.

const Icons = preload("res://ui/icons.gd")

const MIN_WIDTH := 420.0
const ICON := 64.0

var _day: Label
var _island: Label

func _init() -> void:
	enter_from = Vector2(-120, 0)
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN

func _build() -> void:
	(_inner as PanelContainer).add_theme_stylebox_override("panel", CozyTheme.plank_card())
	_inner.material = CozyTheme.wood_grain(6.0)
	_inner.custom_minimum_size.x = MIN_WIDTH
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	_inner.add_child(row)
	var icon := Control.new()
	icon.custom_minimum_size = Vector2(ICON, ICON)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.draw.connect(func() -> void: Icons.paint(icon, "island", Rect2(Vector2.ZERO, icon.size), Pal.MOSS))
	row.add_child(icon)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 0)
	row.add_child(col)
	_day = Label.new()
	_day.theme_type_variation = "OnSlateTitle"
	col.add_child(_day)
	_island = Label.new()
	_island.theme_type_variation = "OnSlateBody"
	col.add_child(_island)
	set_day(1, "")

func set_day(n: int, island: String) -> void:
	_day.text = "Day %d" % n
	_island.text = island
	_island.visible = island != ""
