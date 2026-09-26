extends "res://ui/hud/panel.gd"

## The flat screen's day card: the first screen's day row
## (ui/menu/day_row.gd) at the board's height -- the day's island painted
## behind a paper scrim, "Day N" over the island's name, and today's three
## hearts at its right. The win screen shows a second one under the board
## with the time, moves and hints at its right in place of the hearts
## (set_stats).
## Spec: docs/superpowers/specs/2026-09-18-binairo-flat-design.md, sections 3 and 8;
## restyled after the painted menu on 2026-09-26.

const Icons = preload("res://ui/icons.gd")
const Vistas = preload("res://ui/menu/vistas.gd")

const HEIGHT := 120.0
const RADIUS := 32
const HEART := 40.0
const HEART_GAP := 10.0
const HEARTS := 3
## The paper pill the hearts sit on, so an empty one still reads over a
## bright sea.
const PILL_PAD := Vector2(14, 10)

var _vista: ColorRect
var _day: Label
var _island: Label
var _stats: Label
var _hearts_ci: Control
var _hearts := 0

func _init() -> void:
	enter_from = Vector2(-120, 0)

func _build() -> void:
	_inner.add_theme_stylebox_override("panel", CozyTheme.lifted(Pal.SURFACE, RADIUS, 0))
	_inner.custom_minimum_size.y = HEIGHT
	_vista = Vistas.day_plate()
	(_vista.material as ShaderMaterial).set_shader_parameter("radius", float(RADIUS))
	_inner.add_child(_vista)
	var pad := MarginContainer.new()
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["margin_top", "margin_bottom"]:
		pad.add_theme_constant_override(side, 14)
	pad.add_theme_constant_override("margin_left", 40)
	pad.add_theme_constant_override("margin_right", 28)
	_inner.add_child(pad)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	pad.add_child(row)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", -4)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	_day = Label.new()
	_day.theme_type_variation = "CardTitle"
	_day.add_theme_font_override("font", CozyTheme.display(700))
	col.add_child(_day)
	_island = Label.new()
	_island.theme_type_variation = "CardBodyDim"
	col.add_child(_island)
	_hearts_ci = Control.new()
	_hearts_ci.custom_minimum_size = Vector2(HEARTS * HEART + (HEARTS - 1) * HEART_GAP, HEART) + PILL_PAD * 2.0
	_hearts_ci.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_hearts_ci.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hearts_ci.draw.connect(_draw_hearts)
	row.add_child(_hearts_ci)
	_stats = Label.new()
	_stats.theme_type_variation = "CardBody"
	_stats.add_theme_font_override("font", CozyTheme.body(700))
	_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	# On the hearts' paper pill, for the same reason.
	var pill := CozyTheme.card(Color(Pal.SURFACE, 0.9), 30, Pal.LINE, 0, 0)
	pill.content_margin_left = 20
	pill.content_margin_right = 20
	pill.content_margin_top = 8
	pill.content_margin_bottom = 8
	_stats.add_theme_stylebox_override("normal", pill)
	_stats.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_stats.visible = false
	row.add_child(_stats)
	set_day(1, "")

func set_day(n: int, island: String) -> void:
	_day.text = tr("MENU_DAY") % n
	_island.text = island
	_island.visible = island != ""
	Vistas.set_day_vista(_vista, island, Pal.ACCENT)

## Today's boards solved, of the three that keep the streak.
func set_hearts(n: int) -> void:
	_hearts = clampi(n, 0, HEARTS)
	_hearts_ci.queue_redraw()

## The win screen's figures at the card's right, in place of the hearts;
## "" hides them and brings the hearts back.
func set_stats(text: String) -> void:
	_stats.text = text
	_stats.visible = text != ""
	_hearts_ci.visible = text == ""

func _draw_hearts() -> void:
	var pill := Rect2(Vector2.ZERO, _hearts_ci.size)
	var sb := CozyTheme.card(Color(Pal.SURFACE, 0.9), int(pill.size.y * 0.5), Pal.LINE, 0, 0)
	_hearts_ci.draw_style_box(sb, pill)
	for i in HEARTS:
		var box := Rect2(PILL_PAD + Vector2(i * (HEART + HEART_GAP), 0.0), Vector2(HEART, HEART))
		if i < _hearts:
			Icons.paint(_hearts_ci, "heart", box, Pal.HEART)
		else:
			Icons.paint(_hearts_ci, "heart", box, Color(Pal.SURFACE, 0.92))
			Icons.paint(_hearts_ci, "heart_line", box, Pal.LINE)
