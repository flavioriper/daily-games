extends Control

## Bagatelle's four cards over the board, one Control a `mode` (the
## reference's tabs, as the user's sheet of 2026-10-18 lays them out):
##
## - "up": the run's five upgrades for coins, a row each (what it does, its
##   level, now and next, the price on a coin pill), and a ×1 / Max chip in
##   the head; a row held at level 10 says the eighth investment opens it;
## - "jar": the jar a tier a tile (its marble, its name, "in the jar /
##   owned", its worth), Merge 10 on a tile with ten in the jar, and Merge
##   all at the foot;
## - "shop": the cash out (the SP it would pay, a bar to the next one, the
##   button, which asks once more before it takes the run), then the shop's
##   five items a row each;
## - "invest": the ten investments as a strip, the next one as a row (asked
##   twice: it spends every SP and starts the shop again), then Ascend: shut
##   until the tenth, then its button and its four stats.
##
## The rules and every figure are arcade/bagatelle_sim.gd's; this draws and
## asks. A row the coins (or the SP) do not cover is dim. The screen
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
const ROW_H := 140.0
const SHOP_ROW_H := 116.0
const ASC_ROW_H := 100.0
const TILE_H := 96.0
const X_SIZE := 84.0
const ICON := 92.0
const REFRESH := 0.15
const SP_TINT := Color("b07fd0")
const ASC_TINT := Color("6fb7e8")

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
var _strip: Control
var _inv: Button
var _inv_asked := false
var _asc: Button
var _asc_asked := false
var _asc_line: Label
var _pts: Label
var _built_at := -1

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
	_build()
	_refresh()
	if not Motion.reduce:
		card.pivot_offset = Vector2(CARD_W * 0.5, 500.0)
		card.scale = Vector2.ONE * 0.92
		card.create_tween().tween_property(card, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		Motion.appear(self, 0.0, 1.0, 0.2)

func _build() -> void:
	match mode:
		"up":
			_build_up()
		"jar":
			_build_jar()
		"invest":
			_build_invest()
		_:
			_build_shop()

## The card again from nothing, as a buy may open a row or close one.
func _rebuild() -> void:
	for c in _col.get_children():
		_col.remove_child(c)
		c.queue_free()
	_rows.clear()
	_build()
	_refresh()

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

## A white pill: a coin, a star (SP) or a crown (ascend points) and a count
## (the Label is "Row/Count"). `what` is "coin", "sp" or "ascend".
static func pill(what: String, tall: float) -> PanelContainer:
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
	icon.draw.connect(_pill_icon.bind(icon, what, tall))
	row.add_child(icon)
	var count := Label.new()
	count.name = "Count"
	count.theme_type_variation = "SheetTitle"
	count.add_theme_font_size_override("font_size", int(tall * 0.92))
	row.add_child(count)
	return p

static func _pill_icon(icon: Control, what: String, tall: float) -> void:
	match what:
		"sp":
			icon.draw_mesh(Art.star(tall * 0.48), null, Transform2D(0.0, icon.size * 0.5))
		"ascend":
			Icons.paint(icon, "crown", Rect2(Vector2.ZERO, icon.size), ASC_TINT)
		_:
			icon.draw_mesh(Art.coin(tall * 0.42), null, Transform2D(0.0, icon.size * 0.5))

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
			"marbles", "tier":
				c.draw_mesh(Art.marble(tier), null, Transform2D(0.0, Vector2.ONE * 2.0, 0.0, m))
			"balls", "double":
				c.draw_mesh(Art.marble(0), null, Transform2D(0.0, Vector2.ONE * 1.5, 0.0, m + Vector2(-13, 0)))
				c.draw_mesh(Art.marble(0), null, Transform2D(0.0, Vector2.ONE * 1.5, 0.0, m + Vector2(13, 0)))
			"mega", "mega_shop":
				c.draw_mesh(Art.marble(1), null, Transform2D(0.0, Vector2.ONE * 1.6, 0.0, m + Vector2(-10, 6)))
				c.draw_mesh(Art.marble(3), null, Transform2D(0.0, Vector2.ONE * 1.6, 0.0, m + Vector2(12, -8)))
			"value", "drop":
				c.draw_mesh(Art.coin(26.0), null, Transform2D(0.0, m))
				if what == "drop":
					Icons.paint(c, "sparkle", Rect2(m + Vector2(4, -36), Vector2(30, 30)), Color("fff4c2"))
			"peg", "times_peg", "mega_peg", "ult_peg":
				c.draw_mesh(Art.bonus_pin(String(Sim.INVEST_PEG[what])), null, Transform2D(0.0, Vector2.ONE * 1.8, 0.0, m))
			"xp", "mega_xp":
				c.draw_mesh(Art.cup(0), null, Transform2D(0.0, Vector2.ONE * 0.5, 0.0, m + Vector2(0, -22)))
				if what == "mega_xp":
					Icons.paint(c, "sparkle", Rect2(m + Vector2(4, -38), Vector2(30, 30)), Color("fff4c2"))
			"bonus", "sp_boost":
				c.draw_mesh(Art.star(30.0), null, Transform2D(0.0, m))
			"mega_up":
				Icons.paint(c, "trend", Rect2(m - Vector2(26, 26), Vector2(52, 52)), Art.CREAM)
			"auto", "auto_cash", "speed":
				Icons.paint(c, "clock", Rect2(m - Vector2(26, 26), Vector2(52, 52)), Art.CREAM)
			"coin":
				c.draw_mesh(Art.coin(26.0), null, Transform2D(0.0, m))
			"prestige":
				c.draw_mesh(Art.star(30.0), null, Transform2D(0.0, m))
			"weight":
				# a marble with a heavy arrow under it
				c.draw_mesh(Art.marble(0), null, Transform2D(0.0, Vector2.ONE * 1.3, 0.0, m + Vector2(0, -14)))
				c.draw_polyline(PackedVector2Array([m + Vector2(-14, 10), m + Vector2(0, 26), m + Vector2(14, 10)]), Art.CREAM, 6.0, true)
			"ascend":
				Icons.paint(c, "crown", Rect2(m - Vector2(28, 28), Vector2(56, 56)), ASC_TINT)
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
	var held := pill("coin", 44.0)
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
		var b := _row(id, _icon(id), "BG_UP_" + id.to_upper(), "BG_UP_" + id.to_upper() + "_LINE", ROW_H, pill("coin", 38.0))
		b.pressed.connect(_buy.bind(id))
		_col.add_child(b)
		_rows[id] = b

func _buy(id: String) -> void:
	if sim.buy(id, 0 if _max else 1) <= 0:
		refused.emit()
		return
	_squash(_rows[id])
	_refresh()

## An upgrade's figure at level `n`, as its row says it.
func _up_now(id: String, n: int) -> String:
	var v := Sim.up_at(id, n)
	match id:
		"auto":
			return tr("BG_SECONDS") % String.num(v * (1.0 - sim.ascend_at("speed")), 3).rstrip("0").trim_suffix(".")
		"weight":
			return "×" + String.num(v, 1).trim_suffix(".0")
		"xp":
			return "+" + Sim.short(v)
	return Sim.short(v)

# --- the jar ---

func _build_jar() -> void:
	_col.add_child(Dialog.head("BG_JAR", "sparkle", _x()))
	var line := Label.new()
	line.theme_type_variation = "SheetBodyDim"
	line.text = "BG_JAR_LINE"
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.custom_minimum_size.x = CARD_W - 80.0
	_col.add_child(line)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	_col.add_child(grid)
	_built_at = mini(Sim.TIERS, maxi(sim.best_tier + 2, 2))
	for k in _built_at:
		var t := _tile(k)
		grid.add_child(t)
		_rows[k] = t
	_merge_all = Dialog.primary("sparkle", tr("BG_MERGE_ALL"))
	_merge_all.name = "MergeAll"
	_merge_all.pressed.connect(func() -> void:
		if sim.merge_all() <= 0:
			refused.emit()
			return
		_squash(_merge_all)
		_jar_again())
	Dialog.buttons(_col, _merge_all)

## A tier's tile: its marble, its name, "jar / owned · ×worth" and Merge 10.
func _tile(k: int) -> PanelContainer:
	var p := PanelContainer.new()
	p.name = "t%d" % k
	p.custom_minimum_size = Vector2((CARD_W - 2.0 * Dialog.INSET - 12.0) * 0.5, TILE_H)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.add_theme_stylebox_override("panel", Dialog.tile(Pal.SURFACE, 10))
	var row := HBoxContainer.new()
	row.name = "In"
	row.add_theme_constant_override("separation", 10)
	p.add_child(row)
	var icon := Control.new()
	icon.custom_minimum_size = Vector2(64, 64)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.draw.connect(func() -> void:
		icon.draw_circle(icon.size * 0.5, 32.0, Art.VELVET_TOP, true, -1.0, true)
		icon.draw_mesh(Art.marble(k), null, Transform2D(0.0, Vector2.ONE * 1.45, 0.0, icon.size * 0.5)))
	row.add_child(icon)
	var words := VBoxContainer.new()
	words.name = "Words"
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_theme_constant_override("separation", 0)
	row.add_child(words)
	var name_l := Label.new()
	name_l.theme_type_variation = "CardName"
	name_l.clip_text = true
	name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_l.add_theme_font_size_override("font_size", 28)
	name_l.text = "BG_TIER_" + String(Sim.TIER_IDS[k]).to_upper()
	words.add_child(name_l)
	var status := Label.new()
	status.name = "Status"
	status.theme_type_variation = "MenuKicker"
	status.clip_text = true
	status.add_theme_font_size_override("font_size", 20)
	words.add_child(status)
	if k < Sim.TIERS - 1:
		# "+ 10": the tile's words need the room "Merge 10" took
		var merge := IconButton.new("plus", str(Sim.MERGE), "IconButton")
		merge.name = "Merge"
		merge.custom_minimum_size = Vector2(104, 72)
		merge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		merge.pressed.connect(_merge.bind(k))
		row.add_child(merge)
	return p

func _merge(k: int) -> void:
	if sim.merge(k) <= 0:
		refused.emit()
		return
	_squash(_rows[k])
	_jar_again()

## The jar card again when a merge opened a new tier's tile.
func _jar_again() -> void:
	if mini(Sim.TIERS, maxi(sim.best_tier + 2, 2)) != _built_at:
		_rebuild()
	else:
		_refresh()

# --- the cash out and the shop ---

func _build_shop() -> void:
	var trailing := HBoxContainer.new()
	trailing.add_theme_constant_override("separation", 14)
	var held := pill("sp", 44.0)
	_held = held.get_node("Row/Count")
	trailing.add_child(held)
	trailing.add_child(_x())
	_col.add_child(Dialog.head("BG_SHOP", "crown", trailing))
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
	shop_l.text = "BG_SHOP_KICKER"
	_col.add_child(shop_l)
	for id: String in Sim.SHOP:
		var b := _row(id, _icon(id), "BG_SHOP_" + id.to_upper(), "BG_SHOP_" + id.to_upper() + "_LINE", SHOP_ROW_H, pill("sp", 34.0))
		b.pressed.connect(_shop.bind(id))
		_col.add_child(b)
		_rows[id] = b

## How far the coins are from this SP to the next.
func _draw_cash_bar() -> void:
	var r := Rect2(Vector2.ZERO, _cash_bar.size)
	_cash_bar.draw_style_box(_bar_box(Color(Pal.TEXT, 0.1)), r)
	var lo: float = sim.this_sp_at()
	var hi: float = sim.next_sp_at()
	var u := clampf((sim.coins - lo) / maxf(1.0, hi - lo), 0.0, 1.0)
	if u > 0.01:
		_cash_bar.draw_style_box(_bar_box(SP_TINT), Rect2(r.position, Vector2(maxf(r.size.y, r.size.x * u), r.size.y)))

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

func _shop_now(id: String, n: int) -> String:
	if id == "balls":
		return "+%d" % (Sim.BALLS_STEP * n)
	if n <= 0:
		return "×1"
	var v := float(Sim.SHOP_LEVELS[id][n - 1])
	return ("+%d" % int(v)) if id == "balls" else "×" + String.num(v, 1).trim_suffix(".0")

# --- investments and ascend ---

func _build_invest() -> void:
	var trailing := HBoxContainer.new()
	trailing.add_theme_constant_override("separation", 14)
	var held := pill("sp", 44.0)
	_held = held.get_node("Row/Count")
	trailing.add_child(held)
	trailing.add_child(_x())
	_col.add_child(Dialog.head("BG_INVEST", "trend", trailing))
	var line := Label.new()
	line.theme_type_variation = "SheetBodyDim"
	line.text = "BG_INVEST_LINE"
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.custom_minimum_size.x = CARD_W - 80.0
	_col.add_child(line)
	_strip = Control.new()
	_strip.name = "Strip"
	_strip.custom_minimum_size = Vector2(CARD_W - 80.0, 64.0)
	_strip.draw.connect(_draw_strip)
	_col.add_child(_strip)
	var id: String = sim.next_invest()
	if id != "":
		_inv = _row("invest", _icon(id), "BG_INV_" + id.to_upper(), "BG_INV_" + id.to_upper() + "_LINE", ROW_H, pill("sp", 38.0))
		_inv.pressed.connect(_on_invest)
		_col.add_child(_inv)
	else:
		var done := Label.new()
		done.theme_type_variation = "CardBlurb"
		done.text = "BG_INVEST_ALL"
		done.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_col.add_child(done)
	# Ascend
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Dialog.tile(Color("eaf4fb"), 22))
	var pc := VBoxContainer.new()
	pc.add_theme_constant_override("separation", 10)
	panel.add_child(pc)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	pc.add_child(top)
	var title := Label.new()
	title.theme_type_variation = "CardName"
	title.add_theme_font_size_override("font_size", 36)
	title.text = "BG_ASCEND"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var pts := pill("ascend", 38.0)
	_pts = pts.get_node("Row/Count")
	top.add_child(pts)
	_asc_line = Label.new()
	_asc_line.theme_type_variation = "CardBlurb"
	_asc_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_asc_line.custom_minimum_size.x = CARD_W - 120.0
	pc.add_child(_asc_line)
	if sim.can_ascend():
		_asc = Dialog.primary("crown", tr("BG_ASCEND_GO"))
		_asc.name = "Ascend"
		_asc.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_asc.pressed.connect(_on_ascend)
		pc.add_child(_asc)
	_col.add_child(panel)
	if sim.ascends > 0 or sim.ascend_pts > 0:
		for a: String in Sim.ASCEND:
			var b := _row("a_" + a, _icon(a), "BG_ASC_" + a.to_upper(), "", ASC_ROW_H, pill("ascend", 32.0))
			b.pressed.connect(_raise.bind(a))
			_col.add_child(b)
			_rows[a] = b

## The ten investments: a numbered disc each, gold once made, the next one
## ringed.
func _draw_strip() -> void:
	var n := Sim.INVEST.size()
	var w := _strip.size.x / n
	var font := get_theme_font("font", "SheetTitle")
	for i in n:
		var m := Vector2(w * (i + 0.5), _strip.size.y * 0.5)
		var made: bool = i < sim.invested
		var next: bool = i == sim.invested
		_strip.draw_circle(m + Vector2(0, 3), 26.0, Color(Pal.TEXT, 0.12), true, -1.0, true)
		_strip.draw_circle(m, 26.0, Pal.SUN if made else Pal.SURFACE, true, -1.0, true)
		if next:
			_strip.draw_arc(m, 27.0, 0.0, TAU, 40, SP_TINT, 4.0, true)
		var s := str(i + 1)
		var fs := 26
		var tw := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		_strip.draw_string(font, m + Vector2(-tw * 0.5, fs * 0.36), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Pal.TEXT if made or next else Pal.TEXT_DIM)

func _on_invest() -> void:
	if not sim.can_invest():
		refused.emit()
		return
	if not _inv_asked:
		_inv_asked = true
		_squash(_inv)
		_refresh()
		return
	sim.invest()
	close()

func _on_ascend() -> void:
	if not sim.can_ascend():
		refused.emit()
		return
	if not _asc_asked:
		_asc_asked = true
		_squash(_asc)
		_refresh()
		return
	sim.ascend()
	close()

func _raise(id: String) -> void:
	if not sim.raise(id):
		refused.emit()
		return
	_squash(_rows[id])
	_refresh()

func _asc_now(id: String, n: int) -> String:
	if n <= 0:
		return "—"
	var v := float(Sim.ASCEND_LEVELS[id][n - 1])
	match id:
		"balls":
			return "+" + Sim.short(v)
		"speed":
			return "-" + String.num(v * 100.0, 1).trim_suffix(".0") + "%"
	return "×" + Sim.short(v)

# --- every row's words ---

func _refresh() -> void:
	_seen = _clock
	match mode:
		"up":
			_held.text = Sim.short(sim.coins)
			for id: String in Sim.UPS:
				var b: Button = _rows[id]
				var n := int(sim.up[id])
				if sim.up_waits(id):
					_status(b).text = tr("BG_UP_WAITS") % _up_now(id, n)
					_count(b).text = "—"
					_dim(b, false)
					continue
				if sim.up_top(id):
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
				var t: PanelContainer = _rows[k]
				(t.find_child("Status", true, false) as Label).text = tr("BG_JAR_TILE") % [Sim.short(float(sim.jar[k])), Sim.short(float(sim.owned[k])), Sim.short(sim.tier_worth(k))]
				var m := t.find_child("Merge", true, false) as Button
				if m != null:
					var can: bool = sim.jar[k] >= Sim.MERGE
					m.disabled = not can
					m.modulate.a = 1.0 if can else 0.45
					any = any or can
			_merge_all.disabled = not any
			_merge_all.modulate.a = 1.0 if any else 0.5
		"invest":
			_held.text = Sim.short(sim.sp)
			_pts.text = str(sim.ascend_pts)
			_strip.queue_redraw()
			if _inv != null:
				var price: float = sim.invest_price()
				_count(_inv).text = Sim.short(price)
				_status(_inv).text = (tr("BG_INVEST_SURE") if _inv_asked else tr("BG_INVEST_NTH")) % (sim.invested + 1)
				_dim(_inv, sim.can_invest())
			if _asc != null:
				var says: String = tr("BG_ASCEND_SURE") if _asc_asked else tr("BG_ASCEND_GO")
				if _asc.label_text != says:
					_asc.set_label(says)
				_asc_line.text = tr("BG_ASCEND_READY")
			else:
				_asc_line.text = tr("BG_ASCEND_SHUT") % (Sim.INVEST.size() - sim.invested)
			for a: String in Sim.ASCEND:
				if not _rows.has(a):
					continue
				var b: Button = _rows[a]
				var n := int(sim.asc[a])
				if sim.ascend_top(a):
					_status(b).text = tr("BG_TOP") % _asc_now(a, n)
					_count(b).text = "—"
				else:
					_status(b).text = tr("BG_RANK") % [n, _asc_now(a, n), _asc_now(a, n + 1)]
					_count(b).text = "1"
				_dim(b, sim.can_raise(a))
		_:
			_held.text = Sim.short(sim.sp)
			var s: int = sim.sp_for()
			if s >= 1:
				_cash_line.text = tr("BG_CASH_LINE") % [Sim.short(sim.coins), Sim.short(float(s))]
			else:
				_cash_line.text = tr("BG_CASH_NOT_YET") % Sim.short(sim.next_sp_at())
			var says: String = (tr("BG_CASH_SURE") % Sim.short(float(s))) if _cash_asked else (tr("BG_CASH_OUT") % Sim.short(float(s)) if s >= 1 else tr("BG_CASH_OUT_NONE"))
			if _cash.label_text != says:
				_cash.set_label(says)
			_cash.modulate.a = 1.0 if s >= 1 else 0.55
			_cash_bar.queue_redraw()
			for id: String in Sim.SHOP:
				var b: Button = _rows[id]
				var n := int(sim.shop[id])
				if not sim.shop_open(id):
					_status(b).text = tr("BG_SHOP_SHUT")
					_count(b).text = "—"
					_dim(b, false)
					continue
				if id == "balls":
					# no top: a level for the same SP, as many as are bought
					_status(b).text = tr("BG_RANK") % [n, _shop_now(id, n), _shop_now(id, n + 1)]
					_count(b).text = Sim.short(sim.shop_price(id))
					_dim(b, sim.can_shop(id))
					continue
				var most := (Sim.SHOP_PRICES[id] as Array).size()
				if sim.shop_top(id):
					_status(b).text = tr("BG_TOP") % _shop_now(id, n)
					_count(b).text = "—"
				else:
					_status(b).text = tr("BG_SHOP_RANK") % [n, most, _shop_now(id, n), _shop_now(id, n + 1)]
					_count(b).text = Sim.short(sim.shop_price(id))
				_dim(b, sim.can_shop(id))
