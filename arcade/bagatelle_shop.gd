extends Control

## Bagatelle's three cards over the board, one Control a `mode`:
##
## - "up": the run's four upgrades for coins, a row each (what it does, its
##   rank, now and next, the price on a coin pill), and a ×1 / Max chip in
##   the head;
## - "jar": the jar a tier a row (its marble, its name, "in the jar /
##   owned", its worth), Merge 10 on a row with ten in the jar, and Merge
##   all at the foot;
## - "stars": the cash out (the stars it would pay, a bar to the next one,
##   the button, which asks once more before it takes the run), then the
##   star shop a row each.
##
## The rules and every figure are arcade/bagatelle_sim.gd's; this draws and
## asks. A row the coins (or the stars) do not cover is dim. The screen
## mounts it (`sim`, `mode`, `closed`) and hears the sim's events.

signal closed
signal refused

const Sim = preload("res://arcade/bagatelle_sim.gd")
const Art = preload("res://arcade/bagatelle_art.gd")
const Dialog = preload("res://ui/hud/dialog.gd")
const IconButton = preload("res://ui/hud/icon_button.gd")
const Icons = preload("res://ui/icons.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const CozyTheme = preload("res://ui/theme.gd")
const UiSound = preload("res://ui/ui_sound.gd")

const CARD_W := 940.0
const ROW_H := 150.0
const SHOP_ROW_H := 122.0
const X_SIZE := 84.0
const ICON := 92.0
const REFRESH := 0.15

var sim: RefCounted
var mode := "up"
var _rows := {}
var _col: VBoxContainer
## One or Max, kept for the session: the sheet is built afresh each time.
static var _max := false
var _max_b: Button
var _held: Label
var _clock := 0.0
var _seen := -1.0
var _cash: Button
var _cash_asked := false
var _cash_line: Label
var _cash_bar: Control
var _merge_all: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 8
	var scrim := Dialog.scrim()
	scrim.gui_input.connect(func(event: InputEvent) -> void:
		if (event is InputEventScreenTouch or event is InputEventMouseButton) and event.pressed:
			close())
	add_child(scrim)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var card := Dialog.card(CARD_W)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(card)
	_col = VBoxContainer.new()
	_col.add_theme_constant_override("separation", 14)
	card.add_child(_col)
	match mode:
		"up":
			_build_up()
		"jar":
			_build_jar()
		_:
			_build_stars()
	_refresh()
	if not Motion.reduce:
		card.pivot_offset = Vector2(CARD_W * 0.5, 500.0)
		card.scale = Vector2.ONE * 0.92
		card.create_tween().tween_property(card, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		Motion.appear(self, 0.0, 1.0, 0.2)

func close() -> void:
	if is_queued_for_deletion():
		return
	closed.emit()
	queue_free()

func _process(delta: float) -> void:
	_clock += delta
	if _clock - _seen >= REFRESH:
		_refresh()

# --- parts ---

func _x() -> Button:
	var x := IconButton.new("cross", "", "IconButton")
	x.name = "Close"
	x.custom_minimum_size = Vector2(X_SIZE, X_SIZE)
	x.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var r := int(X_SIZE * 0.5)
	var up := CozyTheme.soft_button(Pal.SURFACE, r, false, 0)
	var down := CozyTheme.soft_button(Pal.SURFACE, r, true, 0)
	for st in ["normal", "hover", "disabled"]:
		x.add_theme_stylebox_override(st, up)
	x.add_theme_stylebox_override("pressed", down)
	x.pressed.connect(close)
	return x

## A white pill: a coin or a star and a count (the Label is "Row/Count").
static func pill(star: bool, tall: float) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.add_theme_stylebox_override("panel", Dialog.tile(Pal.SURFACE, 12))
	var row := HBoxContainer.new()
	row.name = "Row"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	p.add_child(row)
	var icon := Control.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.custom_minimum_size = Vector2(tall, tall)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.draw.connect(func() -> void:
		icon.draw_mesh(Art.star(tall * 0.48) if star else Art.coin(tall * 0.42), null, Transform2D(0.0, icon.size * 0.5)))
	row.add_child(icon)
	var count := Label.new()
	count.name = "Count"
	count.theme_type_variation = "SheetTitle"
	count.add_theme_font_size_override("font_size", int(tall * 0.92))
	row.add_child(count)
	return p

## A round tile with a drawing on it, `what` an upgrade's, a shop item's or
## a tier's id.
func _icon(what: String, tier := 0) -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.custom_minimum_size = Vector2(ICON, ICON)
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	c.draw.connect(func() -> void:
		var m := c.size * 0.5
		c.draw_circle(m + Vector2(0, 5.0), ICON * 0.5, Color(Pal.TEXT, 0.14), true, -1.0, true)
		c.draw_circle(m, ICON * 0.5, Art.VELVET_TOP, true, -1.0, true)
		match what:
			"marbles", "jar", "tier":
				c.draw_mesh(Art.marble(tier), null, Transform2D(0.0, Vector2.ONE * 2.0, 0.0, m))
			"finer":
				c.draw_mesh(Art.marble(1), null, Transform2D(0.0, Vector2.ONE * 1.6, 0.0, m + Vector2(-10, 6)))
				c.draw_mesh(Art.marble(2), null, Transform2D(0.0, Vector2.ONE * 1.6, 0.0, m + Vector2(12, -8)))
			"twins":
				c.draw_mesh(Art.marble(0), null, Transform2D(0.0, Vector2.ONE * 1.5, 0.0, m + Vector2(-13, 0)))
				c.draw_mesh(Art.marble(0), null, Transform2D(0.0, Vector2.ONE * 1.5, 0.0, m + Vector2(13, 0)))
			"value", "polish":
				c.draw_mesh(Art.coin(26.0), null, Transform2D(0.0, m))
				if what == "polish":
					Icons.paint(c, "sparkle", Rect2(m + Vector2(4, -36), Vector2(30, 30)), Color("fff4c2"))
			"plus", "times":
				c.draw_mesh(Art.bonus_pin(what), null, Transform2D(0.0, Vector2.ONE * 1.8, 0.0, m))
			"warm":
				c.draw_mesh(Art.cup(0), null, Transform2D(0.0, Vector2.ONE * 0.42, 0.0, m + Vector2(0, -20)))
			"shine":
				c.draw_mesh(Art.star(30.0), null, Transform2D(0.0, m))
			"auto":
				Icons.paint(c, "clock", Rect2(m - Vector2(26, 26), Vector2(52, 52)), Art.CREAM)
			"weight":
				# a marble with a heavy arrow under it
				c.draw_mesh(Art.marble(0), null, Transform2D(0.0, Vector2.ONE * 1.3, 0.0, m + Vector2(0, -14)))
				c.draw_polyline(PackedVector2Array([m + Vector2(-14, 10), m + Vector2(0, 26), m + Vector2(14, 10)]), Art.CREAM, 6.0, true)
	)
	return c

## A row: a Button holding the icon, the words and a trailing control.
func _row(id: String, icon: Control, title: String, line: String, tall: float, trailing: Control) -> Button:
	var b := Button.new()
	b.name = id
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size.y = tall
	var sb := Dialog.tile(Pal.SURFACE, 0)
	for s in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(s, sb)
	var row := HBoxContainer.new()
	row.name = "In"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 18
	row.offset_right = -18
	row.add_theme_constant_override("separation", 18)
	b.add_child(row)
	row.add_child(icon)
	var words := VBoxContainer.new()
	words.name = "Words"
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_theme_constant_override("separation", 0)
	row.add_child(words)
	var name_l := Label.new()
	name_l.name = "Name"
	name_l.theme_type_variation = "CardName"
	name_l.add_theme_font_size_override("font_size", 36)
	name_l.text = title
	words.add_child(name_l)
	if line != "":
		var what := Label.new()
		what.name = "Line"
		what.theme_type_variation = "CardBlurb"
		what.add_theme_font_size_override("font_size", 24)
		what.text = line
		what.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		what.custom_minimum_size.x = 540
		words.add_child(what)
	var status := Label.new()
	status.name = "Status"
	status.theme_type_variation = "MenuKicker"
	words.add_child(status)
	if trailing != null:
		row.add_child(trailing)
	return b

func _status(b: Button) -> Label:
	return b.get_node("In/Words/Status") as Label

func _count(b: Button) -> Label:
	return b.find_child("Count", true, false) as Label

func _dim(b: Button, on: bool) -> void:
	b.modulate.a = 1.0 if on else 0.55

func _squash(b: Control) -> void:
	b.pivot_offset = b.size * 0.5
	Motion.squash(b, 0.06, 0.16)

# --- the upgrades ---

func _build_up() -> void:
	var trailing := HBoxContainer.new()
	trailing.add_theme_constant_override("separation", 14)
	var held := pill(false, 44.0)
	_held = held.get_node("Row/Count")
	trailing.add_child(held)
	_max_b = IconButton.new("", "BG_BUY_MAX" if _max else "BG_BUY_ONE", "IconButton")
	_max_b.name = "Max"
	_max_b.custom_minimum_size = Vector2(150, X_SIZE)
	_max_b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_max_b.pressed.connect(func() -> void:
		_max = not _max
		_max_b.set_label(tr("BG_BUY_MAX") if _max else tr("BG_BUY_ONE"))
		_squash(_max_b))
	trailing.add_child(_max_b)
	trailing.add_child(_x())
	_col.add_child(Dialog.head("BG_UPGRADES", "trend", trailing))
	for id: String in Sim.UPS:
		var b := _row(id, _icon(id), "BG_UP_" + id.to_upper(), "BG_UP_" + id.to_upper() + "_LINE", ROW_H, pill(false, 38.0))
		b.pressed.connect(_buy.bind(id))
		_col.add_child(b)
		_rows[id] = b

func _buy(id: String) -> void:
	if sim.buy(id, 0 if _max else 1) <= 0:
		refused.emit()
		return
	_squash(_rows[id])
	_refresh()

func _up_now(id: String, n: int) -> String:
	match id:
		"marbles":
			return str(Sim.marbles_at(n))
		"value":
			return Sim.short(float(1 + n))
		"auto":
			if n <= 0:
				return tr("BG_OFF")
			return tr("BG_SECONDS") % String.num(maxf(Sim.AUTO_LEAST, Sim.AUTO_FIRST * pow(Sim.AUTO_STEP, n - 1)), 2)
		"weight":
			return "×" + String.num(1.0 + Sim.WEIGHT_STEP * n, 2)
	return ""

# --- the jar ---

func _build_jar() -> void:
	_col.add_child(Dialog.head("BG_JAR", "sparkle", _x()))
	var line := Label.new()
	line.theme_type_variation = "SheetBodyDim"
	line.text = "BG_JAR_LINE"
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.custom_minimum_size.x = CARD_W - 80.0
	_col.add_child(line)
	var shown := mini(Sim.TIERS, maxi(sim.best_tier + 2, 2))
	for k in shown:
		var merge := IconButton.new("plus", "BG_MERGE", "IconButton")
		merge.name = "Merge"
		merge.custom_minimum_size = Vector2(190, 84)
		merge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		merge.pressed.connect(_merge.bind(k))
		var b := _row("t%d" % k, _icon("tier", k), "BG_TIER_" + String(Sim.TIER_IDS[k]).to_upper(), "", 112.0, merge if k < Sim.TIERS - 1 else null)
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_col.add_child(b)
		_rows[k] = b
	_merge_all = Dialog.primary("sparkle", tr("BG_MERGE_ALL"))
	_merge_all.name = "MergeAll"
	_merge_all.pressed.connect(func() -> void:
		if sim.merge_all() <= 0:
			refused.emit()
			return
		_squash(_merge_all)
		_rebuild())
	Dialog.buttons(_col, _merge_all)

func _merge(k: int) -> void:
	if sim.merge(k) <= 0:
		refused.emit()
		return
	_squash(_rows[k])
	_rebuild()

## The jar card again, as a merge may open a new tier's row.
func _rebuild() -> void:
	var shown := mini(Sim.TIERS, maxi(sim.best_tier + 2, 2))
	if not _rows.has(shown - 1):
		for c in _col.get_children():
			_col.remove_child(c)
			c.queue_free()
		_rows.clear()
		_build_jar()
	_refresh()

# --- the stars ---

func _build_stars() -> void:
	var trailing := HBoxContainer.new()
	trailing.add_theme_constant_override("separation", 14)
	var held := pill(true, 44.0)
	_held = held.get_node("Row/Count")
	trailing.add_child(held)
	trailing.add_child(_x())
	_col.add_child(Dialog.head("BG_STARS", "crown", trailing))
	# the cash out
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Dialog.tile(Color("f6ecfa"), 22))
	var pc := VBoxContainer.new()
	pc.add_theme_constant_override("separation", 10)
	panel.add_child(pc)
	_cash_line = Label.new()
	_cash_line.name = "CashLine"
	_cash_line.theme_type_variation = "CardBlurb"
	_cash_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_cash_line.custom_minimum_size.x = CARD_W - 120.0
	pc.add_child(_cash_line)
	_cash_bar = Control.new()
	_cash_bar.custom_minimum_size = Vector2(CARD_W - 120.0, 22.0)
	_cash_bar.draw.connect(_draw_cash_bar)
	pc.add_child(_cash_bar)
	_cash = Dialog.primary("crown", tr("BG_CASH_OUT_NONE"))
	_cash.name = "CashOut"
	_cash.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_cash.pressed.connect(_on_cash)
	pc.add_child(_cash)
	_col.add_child(panel)
	var shop_l := Label.new()
	shop_l.theme_type_variation = "MenuKicker"
	shop_l.text = "BG_STAR_SHOP"
	_col.add_child(shop_l)
	for id: String in Sim.SHOP:
		var b := _row(id, _icon(id), "BG_SHOP_" + id.to_upper(), "BG_SHOP_" + id.to_upper() + "_LINE", SHOP_ROW_H, pill(true, 34.0))
		b.pressed.connect(_shop.bind(id))
		_col.add_child(b)
		_rows[id] = b

func _draw_cash_bar() -> void:
	var r := Rect2(Vector2.ZERO, _cash_bar.size)
	_cash_bar.draw_style_box(_bar_box(Color(Pal.TEXT, 0.1)), r)
	var have: float = sim.stars_for()
	var lo := 0.0 if have <= 0 else _at_stars(int(have))
	var hi: float = sim.next_star_at()
	var u := clampf((log(maxf(sim.earned, 1.0)) - log(maxf(lo, 1.0))) / maxf(0.0001, log(hi) - log(maxf(lo, 1.0))), 0.0, 1.0)
	if u > 0.01:
		_cash_bar.draw_style_box(_bar_box(Color("b07fd0")), Rect2(r.position, Vector2(maxf(r.size.y, r.size.x * u), r.size.y)))

func _at_stars(s: int) -> float:
	var k := 1.0 + Sim.SHINE_STEP * int(sim.shop.shine)
	return pow(10.0, Sim.STAR_FROM + pow(float(s) / k, 1.0 / Sim.STAR_POW))

static func _bar_box(c: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(11)
	sb.anti_aliasing = true
	return sb

func _on_cash() -> void:
	if not sim.can_cash_out():
		refused.emit()
		return
	if not _cash_asked:
		_cash_asked = true
		_squash(_cash)
		_refresh()
		return
	sim.cash_out()
	close()

func _shop(id: String) -> void:
	if not sim.shop_buy(id):
		refused.emit()
		return
	_squash(_rows[id])
	_refresh()

# --- every row's words ---

func _refresh() -> void:
	_seen = _clock
	match mode:
		"up":
			_held.text = Sim.short(sim.coins)
			for id: String in Sim.UPS:
				var b: Button = _rows[id]
				var n := int(sim.up[id])
				var top: bool = sim.up_top(id)
				if top:
					_status(b).text = tr("BG_TOP") % _up_now(id, n)
					_count(b).text = "—"
					_dim(b, false)
					continue
				var buy := Vector2(1, sim.price(id))
				if _max:
					buy = sim.max_buy(id)
					if buy.x < 1:
						buy = Vector2(1, sim.price(id))
				_status(b).text = tr("BG_RANK") % [n, _up_now(id, n), _up_now(id, n + int(buy.x))]
				_count(b).text = Sim.short(buy.y) if buy.x <= 1 else "%s ×%d" % [Sim.short(buy.y), int(buy.x)]
				_dim(b, sim.can_buy(id))
		"jar":
			var any := false
			for k: int in _rows:
				var b: Button = _rows[k]
				_status(b).text = tr("BG_JAR_ROW") % [Sim.short(float(sim.jar[k])), Sim.short(float(sim.owned[k])), Sim.short(Sim.worth(k))]
				var m := b.find_child("Merge", true, false) as Button
				if m != null:
					var can: bool = sim.jar[k] >= Sim.MERGE
					m.disabled = not can
					m.modulate.a = 1.0 if can else 0.45
					any = any or can
			_merge_all.disabled = not any
			_merge_all.modulate.a = 1.0 if any else 0.5
		_:
			_held.text = Sim.short(float(sim.stars))
			var s: int = sim.stars_for()
			if s >= 1:
				_cash_line.text = tr("BG_CASH_LINE") % [Sim.short(sim.earned), s]
			else:
				_cash_line.text = tr("BG_CASH_NOT_YET") % Sim.short(sim.next_star_at())
			var says: String = (tr("BG_CASH_SURE") % s) if _cash_asked else (tr("BG_CASH_OUT") % s if s >= 1 else tr("BG_CASH_OUT_NONE"))
			if _cash.label_text != says:
				_cash.set_label(says)
			_cash.modulate.a = 1.0 if s >= 1 else 0.55
			_cash_bar.queue_redraw()
			for id: String in Sim.SHOP:
				var b: Button = _rows[id]
				var n := int(sim.shop[id])
				var most := (Sim.SHOP_PRICES[id] as Array).size()
				_status(b).text = tr("BG_SHOP_RANK") % [n, most]
				_count(b).text = "—" if sim.shop_top(id) else str(sim.shop_price(id))
				_dim(b, sim.can_shop(id))
