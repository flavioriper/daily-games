extends Control

## Griddle's shop: the coins held and what they buy (arcade/griddle_sim.gd),
## a card laid over the place by the screen. Four pages, a tab a place: what
## is bought there a few times (a lot, a cow and a stall, a grill and a
## till) and that place's upgrades, which have no top. A row is one thing:
## what it does, where it stands and its price on a pill; a row the coins
## do not cover is dim and cannot be pressed, and one with no more to be
## had has no price. Spec
## docs/superpowers/specs/2026-10-12-arcade-griddle-design.md.

signal closed

const Sim = preload("res://arcade/griddle_sim.gd")
const Art = preload("res://arcade/griddle_art.gd")
const Animals = preload("res://arcade/furrow_animals.gd")
const Dialog = preload("res://ui/hud/dialog.gd")
const Icons = preload("res://ui/icons.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")

const ROW_H := 132.0
const WIDE := 880.0
const ICON := {"seed": "leaf", "cart": "run", "larder": "plus", "churn": "clock", "pail": "plus", "heat": "flame", "tills": "clock", "shelf": "plus", "recipe": "sparkle", "sign": "trend",
	"lot": "island", "stall": "home", "grill": "flame", "till": "coin"}
const BUYS_OF := {"fields": ["lot"], "yard": ["cow", "stall"], "counter": ["grill", "till"], "office": []}

var sim: RefCounted
## The page it opens on.
var page := "counter"
var _rows := {}
var _bank: Label
var _list: VBoxContainer
var _tabs := {}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 8
	add_child(Dialog.scrim())
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var card := Dialog.card(WIDE)
	center.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	card.add_child(col)
	var pill := coins_pill(46.0)
	_bank = pill.get_node("Row/Count")
	col.add_child(Dialog.head("GR_SHOP", "trend", pill))
	var tabs := HBoxContainer.new()
	tabs.name = "Tabs"
	tabs.add_theme_constant_override("separation", 10)
	col.add_child(tabs)
	for id: String in Sim.PLACES:
		var t := Button.new()
		t.name = id
		t.focus_mode = Control.FOCUS_NONE
		t.text = tr("GR_PLACE_" + id.to_upper())
		t.theme_type_variation = "IconButton"
		t.custom_minimum_size.y = 84.0
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.pressed.connect(show_page.bind(id))
		tabs.add_child(t)
		_tabs[id] = t
	_list = VBoxContainer.new()
	_list.name = "Rows"
	_list.add_theme_constant_override("separation", 12)
	col.add_child(_list)
	var done := Dialog.primary("check", tr("GR_DONE"))
	done.name = "Done"
	done.pressed.connect(func() -> void:
		closed.emit()
		queue_free())
	Dialog.buttons(col, done)
	show_page(page)
	if not Motion.reduce:
		card.pivot_offset = Vector2(WIDE * 0.5, 300)
		card.scale = Vector2.ONE * 0.9
		card.create_tween().tween_property(card, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		Motion.appear(self, 0.0, 1.0, 0.2)

## A white pill with a coin and a count (the Label is "Row/Count").
static func coins_pill(tall: float) -> PanelContainer:
	var pill := PanelContainer.new()
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pill.add_theme_stylebox_override("panel", Dialog.tile(Pal.SURFACE, 14))
	var row := HBoxContainer.new()
	row.name = "Row"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	pill.add_child(row)
	row.add_child(coin_icon(tall))
	var count := Label.new()
	count.name = "Count"
	count.theme_type_variation = "SheetTitle"
	row.add_child(count)
	return pill

## A coin, `tall` pixels.
static func coin_icon(tall: float) -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.custom_minimum_size = Vector2(tall, tall)
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	c.draw.connect(func() -> void: c.draw_mesh(Art.coin(tall * 0.9), null, Transform2D(0.0, c.size * 0.5)))
	return c

## The rows of a page: what `Sim.buy` takes, then the place's upgrades.
func rows_of(id: String) -> Array:
	var rows: Array = BUYS_OF[id].duplicate()
	for up: String in Sim.UPS:
		if Sim.UP_PLACE[up] == id:
			rows.append(up)
	return rows

func show_page(id: String) -> void:
	page = id
	for t: String in _tabs:
		var b: Button = _tabs[t]
		var on := t == id
		var sb := Dialog.tile(Art.PLACE_TINT[t] if on else Pal.SURFACE, 0)
		for s in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			b.add_theme_stylebox_override(s, sb)
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(c, Pal.SURFACE if on else Pal.TEXT)
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	_rows.clear()
	for row_id: String in rows_of(id):
		var row := _row(row_id)
		_list.add_child(row)
		_rows[row_id] = row
	refresh()

func _draw_icon(icon: Control, id: String) -> void:
	var mid := icon.size * 0.5
	icon.draw_circle(mid + Vector2(0, 5.0), 44.0, Color(Pal.TEXT, 0.16), true, -1.0, true)
	icon.draw_circle(mid, 44.0, Art.PLACE_TINT[page] if id in Sim.UPS else Color("f3ead6"), true, -1.0, true)
	if id == "cow":
		icon.draw_mesh(Animals.cow(72.0), null, Transform2D(0.0, mid + Vector2(-2, 24)))
	else:
		Icons.paint(icon, String(ICON[id]), Rect2(mid - Vector2(24, 24), Vector2(48, 48)), Pal.SURFACE if id in Sim.UPS else Art.INK)

func _row(id: String) -> Button:
	var b := Button.new()
	b.name = id
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size.y = ROW_H
	var row := HBoxContainer.new()
	row.name = "In"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 20
	row.offset_right = -20
	row.add_theme_constant_override("separation", 20)
	b.add_child(row)
	var icon := Control.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.custom_minimum_size = Vector2(92, 92)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.draw.connect(_draw_icon.bind(icon, id))
	row.add_child(icon)
	var words := VBoxContainer.new()
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_theme_constant_override("separation", -2)
	row.add_child(words)
	var name_l := Label.new()
	name_l.theme_type_variation = "CardName"
	name_l.text = "GR_UP_" + id.to_upper()
	words.add_child(name_l)
	var what := Label.new()
	what.theme_type_variation = "CardBlurb"
	what.text = "GR_UP_" + id.to_upper() + "_LINE"
	what.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	what.custom_minimum_size.x = 420
	words.add_child(what)
	var status := Label.new()
	status.name = "Status"
	status.theme_type_variation = "MenuKicker"
	words.add_child(status)
	var price := coins_pill(38.0)
	price.name = "Price"
	row.add_child(price)
	b.pressed.connect(buy.bind(id))
	return b

## Buys row `id`; the screen plays the sim's event.
func buy(id: String) -> void:
	var ok: bool = sim.buy_up(id) if id in Sim.UPS else sim.buy(id)
	if not ok:
		return
	var b: Button = _rows[id]
	b.pivot_offset = b.size * 0.5
	Motion.squash(b, 0.06, 0.16)
	refresh()

## Where a row that is bought a few times stands.
func _status(id: String) -> String:
	match id:
		"lot":
			return tr("GR_HAS") % [sim.opened(), Sim.LOTS]
		"cow":
			return tr("GR_HAS") % [sim.cows.size(), sim.cow_room()]
		"stall":
			return tr("GR_HAS") % [sim.stalls, Sim.STALLS_MAX]
		"grill":
			return tr("GR_HAS") % [sim.grills, Sim.GRILLS_MAX]
		"till":
			return tr("GR_HAS") % [sim.tills, Sim.TILLS_MAX]
	return ""

func refresh() -> void:
	_bank.text = Locale.number(sim.coins)
	for id: String in _rows:
		var b: Button = _rows[id]
		var up := id in Sim.UPS
		var cost: int = sim.up_price(id) if up else sim.buy_price(id)
		(b.find_child("Status", true, false) as Label).text = tr("GR_LEVEL") % int(sim.lv[id]) if up else _status(id)
		var pill: Control = b.get_node("In/Price")
		pill.visible = cost >= 0
		(b.get_node("In/Price/Row/Count") as Label).text = Locale.number(maxi(cost, 0))
		var afford: bool = cost >= 0 and sim.coins >= cost
		b.disabled = not afford
		var sb := Dialog.tile(Pal.SURFACE, 0)
		for s in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			b.add_theme_stylebox_override(s, sb)
		b.modulate.a = 1.0 if afford or cost < 0 else 0.5
