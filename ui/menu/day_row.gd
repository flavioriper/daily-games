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

## Emitted by the pager's two chevrons. The row itself never changes page;
## ui/menu.gd owns which page is up, the way it owns which day it is.
signal prev
signal next

const HEIGHT := 180.0
const PLATE := 132.0
const TREE := 84.0
const HEART := 46.0
const HEART_GAP := 16.0
const HEARTS := 3
const HEARTS_FULL := 2
const CHEVRON := 110.0
## The pager's dots. Two is what thirteen cards need; the row draws as many
## as it is given, so a fourteenth board costs nothing here.
const DOT := 14.0
const DOT_GAP := 12.0

var _day: Label
var _island: Label
var _prev: Button
var _next: Button
var _dots: Control
var _page := 0
var _pages := 1

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

	# --- the pager ---
	# The thirteenth card does not fit on one page (spec section 9), and this
	# row is the only place a pager fits for free: it is 180 tall, it already
	# ends in a chevron that does nothing, and the cards cannot give up a
	# pixel without the 92 picture giving it up first. Hidden at one page, so
	# nothing changes on a screen that does not need it.
	_prev = IconButton.new("chevron_left")
	_prev.custom_minimum_size = Vector2(CHEVRON, CHEVRON)
	_prev.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_style_chevron(_prev)
	_prev.pressed.connect(func() -> void: prev.emit())
	row.add_child(_prev)

	_dots = Control.new()
	_dots.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dots.draw.connect(_draw_dots.bind(_dots))
	row.add_child(_dots)

	var go := IconButton.new("chevron_right")
	go.custom_minimum_size = Vector2(CHEVRON, CHEVRON)
	go.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_style_chevron(go)
	go.pressed.connect(func() -> void: next.emit())
	row.add_child(go)
	_next = go

	set_pager(0, 1)
	set_day(1, "")

func _style_chevron(b: Button) -> void:
	var r := int(CHEVRON * 0.5)
	b.add_theme_stylebox_override("normal", CozyTheme.card(Pal.SURFACE_HI, r, Pal.LINE, 5, 8))
	b.add_theme_stylebox_override("hover", CozyTheme.card(Pal.SURFACE_HI, r, Pal.LINE, 5, 8))
	b.add_theme_stylebox_override("pressed", CozyTheme.card(Pal.SURFACE_HI.darkened(0.08), r, Pal.LINE, 2, 8))

func _draw_dots(on: Control) -> void:
	for i in _pages:
		var x := i * (DOT + DOT_GAP) + DOT * 0.5
		var c: Color = Pal.TEXT if i == _page else Pal.LINE
		on.draw_circle(Vector2(x, DOT * 0.5), DOT * 0.5, c)

## Which page is up, and how many there are. One page hides the pager's new
## half: the prev chevron and the dots, which did not exist before this,
## simply are not there. The next chevron is not new -- it is the same
## chevron this row always ended in, wired to nothing until now -- so it
## keeps exactly its old look at one page (present, full alpha, enabled) and
## only starts disabling itself once a real second page makes "next" a
## question with a wrong answer. That is also what keeps this row's draw
## calls at the measured 311 with the pager hidden: a chevron that already
## rendered before the pager existed has to go on rendering, or the count
## moves for a screen that was supposed to look untouched.
func set_pager(page: int, pages: int) -> void:
	_page = page
	_pages = pages
	var many := pages > 1
	_prev.visible = many
	_dots.visible = many
	_dots.custom_minimum_size = Vector2(pages * DOT + (pages - 1) * DOT_GAP, DOT) if many else Vector2.ZERO
	_prev.disabled = page <= 0
	_prev.modulate.a = 1.0 if page > 0 else 0.35
	_next.disabled = many and page >= pages - 1
	_next.modulate.a = 1.0 if not many or page < pages - 1 else 0.35
	_dots.queue_redraw()

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
