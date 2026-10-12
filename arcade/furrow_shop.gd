extends Control

## Furrow's shed: the seeds held and what they buy (arcade/furrow_sim.gd),
## a card laid over the field by the screen. It has three pages, a tab
## each: the field's four upgrades; the coop (a hen, Feed, the Nest box,
## the rooster, the fence mended); the pasture (a cow, Care, the Pail). A
## pen not built yet has one row, the pen itself. A row is one thing: what
## it does, where it stands, and its price on a pill; a row the seeds do
## not cover is dim and cannot be pressed, and one that is not for sale
## (the coop full, the rooster bought, the fence whole) has no price. An
## animal's page opens on its milestones: how many gathered, and how many
## the next one asks. No upgrade has a top; its price is the brake. Spec
## docs/superpowers/specs/2026-10-11-arcade-furrow-design.md.

signal closed

const Sim = preload("res://arcade/furrow_sim.gd")
const Art = preload("res://arcade/furrow_art.gd")
const Animals = preload("res://arcade/furrow_animals.gd")
const Dialog = preload("res://ui/hud/dialog.gd")
const Icons = preload("res://ui/icons.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Face = preload("res://ui/faces/face.gd")
const CozyTheme = preload("res://ui/theme.gd")

const TINT := Color("6fae4a")
const ROW_H := 140.0
const WIDE := 860.0
const PAGES := ["field", "coop", "cow"]
const ICON := {"compost": "leaf", "basket": "plus", "knack": "sparkle", "mulch": "clock", "feed": "leaf", "nest": "plus", "care": "heart", "pail": "plus"}
## A page's badge colour.
const PAGE_TINT := {"field": Color("6fae4a"), "coop": Color("e9a53c"), "cow": Color("6fa8dc")}

var sim: RefCounted
## The page it opens on.
var page := "field"
var _rows := {}
var _bank: Label
var _list: VBoxContainer
var _tabs := {}
var _line: Label
var _mile: Control
var _font: Font

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 8
	_font = CozyTheme.make().get_font("font", "SheetTitle")
	add_child(Dialog.scrim())
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var card := Dialog.card(WIDE)
	center.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	card.add_child(col)
	var pill := seeds_pill(46.0)
	_bank = pill.get_node("Row/Count")
	col.add_child(Dialog.head("FW_SHOP", "trend", pill))
	var tabs := HBoxContainer.new()
	tabs.name = "Tabs"
	tabs.add_theme_constant_override("separation", 12)
	col.add_child(tabs)
	for id: String in PAGES:
		var t := Button.new()
		t.name = id
		t.focus_mode = Control.FOCUS_NONE
		t.text = tr("FW_TAB_" + id.to_upper())
		t.theme_type_variation = "IconButton"
		t.custom_minimum_size.y = 84.0
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.pressed.connect(show_page.bind(id))
		tabs.add_child(t)
		_tabs[id] = t
	_line = Label.new()
	_line.theme_type_variation = "SheetBodyDim"
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line.custom_minimum_size.x = WIDE - 80.0
	col.add_child(_line)
	_mile = Control.new()
	_mile.name = "Mile"
	_mile.custom_minimum_size.y = 64.0
	_mile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mile.draw.connect(_draw_mile)
	col.add_child(_mile)
	_list = VBoxContainer.new()
	_list.name = "Rows"
	_list.add_theme_constant_override("separation", 14)
	col.add_child(_list)
	var done := Dialog.primary("check", tr("FW_SHOP_DONE"))
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

## The rows of a page: an upgrade's id, or what `Sim.buy` takes.
func rows_of(id: String) -> Array:
	match id:
		"coop":
			return ["hen", "feed", "nest", "rooster", "fence"] if sim.coop else ["coop"]
		"cow":
			return ["cow", "care", "pail"] if sim.pasture else ["pasture"]
	return Sim.UPS.duplicate()

func show_page(id: String) -> void:
	page = id
	for t: String in _tabs:
		var b: Button = _tabs[t]
		var on := t == id
		var sb := Dialog.tile(PAGE_TINT[t] if on else Pal.SURFACE, 0)
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
	_line.text = tr("FW_SHOP_LINE" if id == "field" else "FW_COOP_LINE" if id == "coop" else "FW_COW_LINE")
	_mile.visible = (id == "coop" and sim.coop) or (id == "cow" and sim.pasture)
	refresh()

func _draw_icon(icon: Control, id: String) -> void:
	var mid := icon.size * 0.5
	icon.draw_circle(mid + Vector2(0, 5.0), 46.0, Color(Pal.TEXT, 0.16), true, -1.0, true)
	icon.draw_circle(mid, 46.0, PAGE_TINT[page] if id in Sim.ALL_UPS else Color("f3ead6"), true, -1.0, true)
	match id:
		"coop", "hen":
			icon.draw_mesh(Animals.hen(62.0), null, Transform2D(0.0, mid + Vector2(-6, 30)))
		"rooster":
			icon.draw_mesh(Animals.hen(64.0, true), null, Transform2D(0.0, mid + Vector2(-4, 32)))
		"pasture", "cow":
			icon.draw_mesh(Animals.cow(76.0), null, Transform2D(0.0, mid + Vector2(-2, 26)))
		"fence":
			icon.draw_mesh(Animals.fence_icon(62.0), null, Transform2D(0.0, mid + Vector2(0, 2)))
		"nest":
			icon.draw_mesh(Animals.egg(52.0), null, Transform2D(0.0, mid + Vector2(0, 24)))
		"pail":
			icon.draw_mesh(Animals.bottle(62.0), null, Transform2D(0.0, mid + Vector2(0, 4)))
		_:
			Icons.paint(icon, String(ICON[id]), Rect2(mid - Vector2(25, 25), Vector2(50, 50)), Pal.SURFACE)

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
	icon.custom_minimum_size = Vector2(96, 96)
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

## Buys row `id`; the screen plays the sim's event.
func buy(id: String) -> void:
	var was: Array = rows_of(page)
	var ok: bool = sim.buy_up(id) if id in Sim.ALL_UPS else sim.buy(id)
	if not ok:
		return
	if rows_of(page) != was:
		# the pen is built: its page has its own rows now
		show_page(page)
		return
	var b: Button = _rows[id]
	b.pivot_offset = b.size * 0.5
	Motion.squash(b, 0.06, 0.16)
	refresh()

## Where a row that is not an upgrade stands.
func _status(id: String) -> String:
	match id:
		"hen":
			return tr("FW_ROOM") % [int(sim.hens) + (sim.chicks as Array).size(), Sim.HENS_MAX]
		"cow":
			return tr("FW_ROOM") % [(sim.cows as Array).size(), Sim.COWS_MAX]
		"rooster":
			return tr("FW_ROOSTER_HAS") if sim.rooster else tr("FW_ROOSTER_NONE") % int(round(Sim.HATCH * 100.0))
		"fence":
			return tr("FW_FENCE_DOWN") if float(sim.fence_t) <= 0.0 else tr("FW_FENCE_HOLDS") % _span(float(sim.fence_t))
		"coop":
			return tr("FW_COOP_COMES") % Sim.HENS_START
		"pasture":
			return tr("FW_PASTURE_COMES")
	return ""

static func _span(secs: float) -> String:
	return load("res://arcade/furrow_screen.gd").span(secs)

func refresh() -> void:
	_bank.text = Locale.number(sim.seeds)
	for id: String in _rows:
		var b: Button = _rows[id]
		var up := id in Sim.ALL_UPS
		var cost: int = sim.up_price(id) if up else sim.price(id)
		var n := int(sim.lv[id]) if up else 0
		(b.find_child("Status", true, false) as Label).text = tr("FW_UP_STATUS") % [n, sim.up_worth(id, n), sim.up_worth(id, n + 1)] if up else _status(id)
		var pill: Control = b.get_node("In/Price")
		pill.visible = cost >= 0
		(b.get_node("In/Price/Row/Count") as Label).text = Locale.number(maxi(cost, 0))
		var afford: bool = cost >= 0 and sim.seeds >= cost
		b.disabled = not afford
		var sb := Dialog.tile(Pal.SURFACE, 0)
		for s in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			b.add_theme_stylebox_override(s, sb)
		b.modulate.a = 1.0 if afford or cost < 0 else 0.5
	_mile.queue_redraw()

## An animal's milestones: how many gathered of the next one's count, as a
## bar, and what reaching it pays.
func _draw_mile() -> void:
	if not _mile.visible or _mile.size.x <= 0.0:
		return
	var kind := "egg" if page == "coop" else "milk"
	var got: int = sim.eggs_got if kind == "egg" else sim.milk_got
	var next: int = sim.next_mile(kind)
	var all: Array = Sim.EGG_MILES if kind == "egg" else Sim.MILK_MILES
	var prizes: Array = Sim.EGG_PRIZES if kind == "egg" else Sim.MILK_PRIZES
	var n: int = sim.miles(kind)
	var from := 0 if n == 0 else int(all[n - 1])
	var part := 1.0 if next < 0 else clampf(float(got - from) / maxf(1.0, next - from), 0.0, 1.0)
	var w := _mile.size.x
	var b := Face.Builder.new()
	b.fan(Face.Builder.round_rect(Vector2(0, 38.0), Vector2(w, 22.0), 11.0), Color(Pal.TEXT, 0.12))
	if part > 0.01:
		b.fan(Face.Builder.round_rect(Vector2(0, 38.0), Vector2(maxf(22.0, w * part), 22.0), 11.0), PAGE_TINT[page])
	_mile.set_meta("bar", b.mesh())
	_mile.draw_mesh(_mile.get_meta("bar"), null)
	var left := tr("FW_MILE_EGGS" if kind == "egg" else "FW_MILE_MILK") % [Locale.number(got), n]
	_mile.draw_string(_font, Vector2(0, 28.0), left, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Pal.TEXT)
	var right := tr("FW_MILE_DONE") if next < 0 else tr("FW_MILE_NEXT") % [Locale.number(next), Locale.number(int(prizes[n]))]
	_mile.draw_string(_font, Vector2(0, 28.0), right, HORIZONTAL_ALIGNMENT_RIGHT, w, 26, Color(Pal.TEXT, 0.7))
