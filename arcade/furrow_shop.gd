extends Control

## Furrow's shed: the seeds held and the three upgrades they buy
## (arcade/furrow_sim.gd), a card laid over the field by the screen. A row
## is one upgrade: what it does, its level, what the level is worth now and
## what the next would be, and its price on a pill. A row the seeds do not
## cover is dim and cannot be pressed. No upgrade has a top; its price is
## the brake. Spec docs/superpowers/specs/2026-10-11-arcade-furrow-design.md.

signal closed

const Sim = preload("res://arcade/furrow_sim.gd")
const Art = preload("res://arcade/furrow_art.gd")
const Dialog = preload("res://ui/hud/dialog.gd")
const Icons = preload("res://ui/icons.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")

const TINT := Color("6fae4a")
const ROW_H := 176.0
const ICON := {"compost": "leaf", "basket": "plus", "knack": "sparkle"}

var sim: RefCounted
var _rows := {}
var _bank: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 8
	add_child(Dialog.scrim())
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var card := Dialog.card(860)
	center.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	card.add_child(col)
	var pill := seeds_pill(46.0)
	_bank = pill.get_node("Row/Count")
	col.add_child(Dialog.head("FW_SHOP", "trend", pill))
	var line := Label.new()
	line.theme_type_variation = "SheetBodyDim"
	line.text = "FW_SHOP_LINE"
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.custom_minimum_size.x = 780
	col.add_child(line)
	for id: String in Sim.UPS:
		var row := _row(id)
		col.add_child(row)
		_rows[id] = row
	var done := Dialog.primary("check", tr("FW_SHOP_DONE"))
	done.name = "Done"
	done.pressed.connect(func() -> void:
		closed.emit()
		queue_free())
	Dialog.buttons(col, done)
	refresh()
	if not Motion.reduce:
		card.pivot_offset = Vector2(430, 300)
		card.scale = Vector2.ONE * 0.9
		card.create_tween().tween_property(card, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		Motion.appear(self, 0.0, 1.0, 0.2)

## A white pill with a seed and a count (the Label is "Row/Count").
static func seeds_pill(tall: float) -> PanelContainer:
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
	row.add_child(seed_icon(tall))
	var count := Label.new()
	count.name = "Count"
	count.theme_type_variation = "SheetTitle"
	row.add_child(count)
	return pill

## A seed, `tall` pixels.
static func seed_icon(tall: float) -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.custom_minimum_size = Vector2(tall * 0.8, tall)
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	c.draw.connect(func() -> void: c.draw_mesh(Art.seed_icon(tall), null, Transform2D(0.0, c.size * 0.5)))
	return c

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
	icon.custom_minimum_size = Vector2(100, 100)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.draw.connect(func() -> void:
		icon.draw_circle(icon.size * 0.5 + Vector2(0, 5.0), 50.0, Color(Pal.TEXT, 0.16), true, -1.0, true)
		icon.draw_circle(icon.size * 0.5, 50.0, TINT, true, -1.0, true)
		Icons.paint(icon, String(ICON[id]), Rect2(icon.size * 0.5 - Vector2(27, 27), Vector2(54, 54)), Pal.SURFACE))
	row.add_child(icon)
	var words := VBoxContainer.new()
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_theme_constant_override("separation", 0)
	row.add_child(words)
	var name_l := Label.new()
	name_l.theme_type_variation = "CardName"
	name_l.text = "FW_UP_" + id.to_upper()
	words.add_child(name_l)
	var what := Label.new()
	what.theme_type_variation = "CardBlurb"
	what.text = "FW_UP_" + id.to_upper() + "_LINE"
	what.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	what.custom_minimum_size.x = 400
	words.add_child(what)
	var status := Label.new()
	status.name = "Status"
	status.theme_type_variation = "MenuKicker"
	words.add_child(status)
	var price := seeds_pill(38.0)
	price.name = "Price"
	row.add_child(price)
	b.pressed.connect(buy.bind(id))
	return b

## Buys a level of `id`; the screen plays the sim's event.
func buy(id: String) -> void:
	if not sim.buy_up(id):
		return
	var b: Button = _rows[id]
	b.pivot_offset = b.size * 0.5
	Motion.squash(b, 0.06, 0.16)
	refresh()

func refresh() -> void:
	_bank.text = Locale.number(sim.seeds)
	for id: String in _rows:
		var b: Button = _rows[id]
		var n := int(sim.lv[id])
		var cost: int = sim.up_price(id)
		(b.find_child("Status", true, false) as Label).text = tr("FW_UP_STATUS") % [n, sim.up_worth(id, n), sim.up_worth(id, n + 1)]
		(b.get_node("In/Price/Row/Count") as Label).text = Locale.number(cost)
		var afford: bool = sim.seeds >= cost
		b.disabled = not afford
		var sb := Dialog.tile(Pal.SURFACE, 0)
		for s in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			b.add_theme_stylebox_override(s, sb)
		b.modulate.a = 1.0 if afford else 0.5
