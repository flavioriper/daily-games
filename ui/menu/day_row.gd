extends "res://ui/hud/panel.gd"

## The first screen's day row: the day's island painted behind it
## (ui/menu/vistas.gd), "Day N" over the day's name, three hearts and a
## chevron. It is the flat day card (ui/flat/flat_day_card.gd) at the menu's
## size, with the two decorations the mock puts on it.
##
## **The hearts count today's distinct boards solved** (`Progress.hearts`),
## three of which keep the streak, and **the chevron opens Streak**
## (spec `2026-09-24-stats-streak-design.md`, section 4). The day whose
## number and name it shows is real (core/progress.gd), and so now is
## everything else on this row.
## Spec: docs/superpowers/specs/2026-09-18-flat-menu-design.md, section 4.
## Spec: docs/superpowers/specs/2026-09-24-painted-menu-design.md, section 6.

signal open_streak

const Icons = preload("res://ui/icons.gd")
const IconButton = preload("res://ui/hud/icon_button.gd")
const Vistas = preload("res://ui/menu/vistas.gd")

const HEIGHT := 200.0
const HEART := 54.0
const HEART_GAP := 16.0
const HEARTS := 3
const CHEVRON := 110.0

## The pop waits for the row's own entrance to land.
const POP_DELAY := 0.45

var _vista: ColorRect
var _day: Label
var _island: Label
var _hearts_ci: Control
var _hearts := 0
var _known := false
var _popping := -1
var _pop_t := 0.0:
	set(value):
		_pop_t = value
		if is_instance_valid(_hearts_ci):
			_hearts_ci.queue_redraw()

func _init() -> void:
	enter_from = Vector2(0, 30)

func _build() -> void:
	# The day's vista fills the card under a paper scrim from the left; the
	# stylebox under it only shows at the rim and carries the shadow.
	_inner.add_theme_stylebox_override("panel", CozyTheme.lifted(Pal.SURFACE, 40, 0))
	_inner.custom_minimum_size.y = HEIGHT
	_vista = Vistas.day_plate()
	_inner.add_child(_vista)
	var pad := MarginContainer.new()
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		pad.add_theme_constant_override(side, 24)
	pad.add_theme_constant_override("margin_left", 48)
	_inner.add_child(pad)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	pad.add_child(row)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	var kicker := Label.new()
	kicker.theme_type_variation = "MenuKicker"
	kicker.text = "MENU_TODAY"
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
	_hearts_ci = hearts
	row.add_child(hearts)

	var go := IconButton.new("chevron_right")
	go.custom_minimum_size = Vector2(CHEVRON, CHEVRON)
	go.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	go.add_theme_stylebox_override("normal", CozyTheme.lifted(Pal.SURFACE, int(CHEVRON * 0.5), 8))
	go.add_theme_stylebox_override("hover", CozyTheme.lifted(Pal.SURFACE, int(CHEVRON * 0.5), 8))
	go.add_theme_stylebox_override("pressed", CozyTheme.lifted(Pal.SURFACE_HI.darkened(0.06), int(CHEVRON * 0.5), 8))
	go.pressed.connect(func() -> void: open_streak.emit())
	row.add_child(go)

	set_day(1, "")

## Today's count. The first call only sets it; a later rise pops the newest
## heart in, so coming back from the solve that earned it shows it arriving.
func set_hearts(n: int) -> void:
	n = clampi(n, 0, HEARTS)
	var rose := _known and n > _hearts
	_hearts = n
	_known = true
	_popping = n - 1 if rose else -1
	if rose and not Motion.reduce:
		_pop_t = 0.0
		create_tween().tween_property(self, "_pop_t", Motion.POP_IN, Motion.POP_IN).set_delay(POP_DELAY)
	else:
		_pop_t = Motion.POP_IN
	if is_instance_valid(_hearts_ci):
		_hearts_ci.queue_redraw()

func _draw_hearts(on: Control) -> void:
	for i in HEARTS:
		var centre := Vector2(i * (HEART + HEART_GAP) + HEART * 0.5, HEART * 0.5)
		var s := Motion.pop_in_scale(_pop_t) if i == _popping else Vector2.ONE
		on.draw_set_transform(centre, 0.0, s)
		var box := Rect2(Vector2(-HEART, -HEART) * 0.5, Vector2(HEART, HEART))
		if i < _hearts:
			Icons.paint(on, "heart", box, Pal.HEART)
		else:
			Icons.paint(on, "heart", box, Color(Pal.SURFACE, 0.92))
			Icons.paint(on, "heart_line", box, Pal.LINE)
	on.draw_set_transform(Vector2.ZERO)

var _day_n := 1

func set_day(n: int, island: String) -> void:
	_day_n = n
	_day.text = tr("MENU_DAY") % n
	_island.text = island
	_island.visible = island != ""
	Vistas.set_day_vista(_vista, island, Pal.ACCENT)

## "Day %d" is formatted, so it cannot re-translate itself like the kicker.
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _day != null:
		_day.text = tr("MENU_DAY") % _day_n
