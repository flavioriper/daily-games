extends "res://ui/hud/panel.gd"

## The first screen's day row: a tree on a pale plate, "Day N" over the day's
## name, three hearts and a chevron. It is the flat day card
## (ui/flat/flat_day_card.gd) at the menu's size, with the two decorations
## the mock puts on it.
##
## **The hearts and the chevron are decoration**, by decision with the user
## on 2026-09-18, and this comment is the place that says so plainly: they
## are drawn exactly as the mock draws them -- two of three filled -- and
## they count nothing. There is no three-a-day goal, no streak health and no
## lives. The day whose number and name it shows is real
## (core/progress.gd); everything else on this row is a picture of a feature
## that has not been designed. The chevron squashes and does nothing.
## Spec: docs/superpowers/specs/2026-09-18-flat-menu-design.md, section 4.

const Icons = preload("res://ui/icons.gd")
const IconButton = preload("res://ui/hud/icon_button.gd")

const HEIGHT := 180.0
const PLATE := 132.0
const TREE := 84.0
const HEART := 46.0
const HEART_GAP := 16.0
const HEARTS := 3
const HEARTS_FULL := 2
const CHEVRON := 110.0

var _day: Label
var _island: Label

func _init() -> void:
	enter_from = Vector2(0, 30)

func _build() -> void:
	_inner.add_theme_stylebox_override("panel", CozyTheme.card(Pal.SURFACE, 36, Pal.LINE, 6, 24))
	_inner.custom_minimum_size.y = HEIGHT
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	_inner.add_child(row)

	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel", CozyTheme.card(Pal.SURFACE_HI, 26, Pal.LINE, 4, 0))
	plate.custom_minimum_size = Vector2(PLATE, PLATE)
	plate.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(plate)
	var tree := Control.new()
	tree.custom_minimum_size = Vector2(TREE, TREE)
	tree.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tree.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tree.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tree.draw.connect(func() -> void: Icons.paint(tree, "tree", Rect2(Vector2.ZERO, tree.size), Pal.LEAF))
	plate.add_child(tree)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	var kicker := Label.new()
	kicker.theme_type_variation = "MenuKicker"
	kicker.text = "TODAY"
	kicker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(kicker)
	_day = Label.new()
	_day.theme_type_variation = "DayBig"
	col.add_child(_day)
	_island = Label.new()
	_island.theme_type_variation = "CardBodyDim"
	col.add_child(_island)

	var hearts := Control.new()
	hearts.custom_minimum_size = Vector2(HEARTS * HEART + (HEARTS - 1) * HEART_GAP, HEART)
	hearts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hearts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hearts.draw.connect(_draw_hearts.bind(hearts))
	row.add_child(hearts)

	var go := IconButton.new("chevron_right")
	go.custom_minimum_size = Vector2(CHEVRON, CHEVRON)
	go.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	go.add_theme_stylebox_override("normal", CozyTheme.card(Pal.SURFACE_HI, int(CHEVRON * 0.5), Pal.LINE, 5, 8))
	go.add_theme_stylebox_override("hover", CozyTheme.card(Pal.SURFACE_HI, int(CHEVRON * 0.5), Pal.LINE, 5, 8))
	go.add_theme_stylebox_override("pressed", CozyTheme.card(Pal.SURFACE_HI.darkened(0.08), int(CHEVRON * 0.5), Pal.LINE, 2, 8))
	row.add_child(go)

	set_day(1, "")

func _draw_hearts(on: Control) -> void:
	for i in HEARTS:
		var box := Rect2(Vector2(i * (HEART + HEART_GAP), 0.0), Vector2(HEART, HEART))
		if i < HEARTS_FULL:
			Icons.paint(on, "heart", box, Pal.ACCENT_2)
		else:
			Icons.paint(on, "heart_line", box, Pal.LINE)

func set_day(n: int, island: String) -> void:
	_day.text = "Day %d" % n
	_island.text = island
	_island.visible = island != ""
