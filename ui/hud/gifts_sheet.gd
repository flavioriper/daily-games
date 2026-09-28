extends "res://ui/hud/sheet.gd"

## The daily gifts: the week's calendar -- seven days, each showing what it
## holds, today's to claim -- and the hearts gift for three boards solved
## today. Opened from the menu header's gift button, and by the menu itself
## once a day while the calendar's day is still to claim. A claim throws its
## coins into the gold pill at the top.
## Spec docs/superpowers/specs/2026-09-28-gold-gifts-design.md, sections 2 and 4.

const GoldPill = preload("res://ui/menu/gold_pill.gd")
const BoosterIcon = preload("res://arcade/booster_icon.gd")
const Icons = preload("res://ui/icons.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Boosters = preload("res://arcade/boosters.gd")

const TILE_H := 200.0
const ICON := 64.0

var pill: Button
var claim_button: Button
var hearts_button: Button
var _tiles: Array = []
var _week_line: Label
var _hearts_line: Label
var _hearts_row: HBoxContainer
var _hearts_marks: Control
var _fx: Node2D

func puzzle_id() -> String:
	return "wallet"

func _card_style() -> StyleBox:
	return CozyTheme.parchment_card()

func _build_sheet(col: VBoxContainer) -> void:
	_fx = Fx2D.new()
	add_child(_fx)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	col.add_child(head)
	var title := Label.new()
	title.theme_type_variation = "SheetTitle"
	title.text = "GIFT_TITLE"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	pill = GoldPill.new()
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(pill)

	_week_line = Label.new()
	_week_line.theme_type_variation = "SheetBodyDim"
	_week_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_week_line)
	var week := VBoxContainer.new()
	week.add_theme_constant_override("separation", 14)
	col.add_child(week)
	for row_days in [[0, 1, 2, 3], [4, 5, 6]]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		week.add_child(row)
		for d: int in row_days:
			var tile := _tile(d)
			tile.size_flags_stretch_ratio = 2.0 if d == 6 else 1.0
			row.add_child(tile)
			_tiles.append(tile)
	claim_button = IconButton.new("gift", "GIFT_CLAIM", "SunButton")
	claim_button.custom_minimum_size.y = ROW
	claim_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	claim_button.pressed.connect(_claim_day)
	col.add_child(claim_button)

	var rule := ColorRect.new()
	rule.color = Color(Pal.LINE, 0.4)
	rule.custom_minimum_size.y = 3
	col.add_child(rule)

	# the hearts gift: three hearts, what it holds, Claim
	_hearts_row = HBoxContainer.new()
	_hearts_row.add_theme_constant_override("separation", 18)
	col.add_child(_hearts_row)
	_hearts_marks = Control.new()
	_hearts_marks.custom_minimum_size = Vector2(170, 64)
	_hearts_marks.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_hearts_marks.draw.connect(_draw_hearts)
	_hearts_row.add_child(_hearts_marks)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_theme_constant_override("separation", 0)
	_hearts_row.add_child(words)
	var hk := Label.new()
	hk.theme_type_variation = "SheetBody"
	hk.text = "GIFT_HEARTS"
	words.add_child(hk)
	_hearts_line = Label.new()
	_hearts_line.theme_type_variation = "SheetBodyDim"
	words.add_child(_hearts_line)
	hearts_button = IconButton.new("gift", "GIFT_CLAIM", "SunButton")
	hearts_button.custom_minimum_size = Vector2(0, 100)
	hearts_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hearts_button.pressed.connect(_claim_hearts)
	_hearts_row.add_child(hearts_button)

	var close_button := IconButton.new("check", "BTN_CLOSE", "IconButton")
	close_button.custom_minimum_size.y = ROW
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_button.pressed.connect(close)
	col.add_child(close_button)
	Wallet.changed.connect(_refresh)

func _tile(d: int) -> PanelContainer:
	var tile := PanelContainer.new()
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.custom_minimum_size.y = TILE_H
	var inner := VBoxContainer.new()
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.add_theme_constant_override("separation", 4)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(inner)
	var day := Label.new()
	day.name = "Day"
	day.theme_type_variation = "MenuKicker"
	day.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(day)
	var icons := HBoxContainer.new()
	icons.name = "Icons"
	icons.alignment = BoxContainer.ALIGNMENT_CENTER
	icons.add_theme_constant_override("separation", 6)
	icons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(icons)
	var amount := Label.new()
	amount.name = "Amount"
	amount.theme_type_variation = "CardBlurb"
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(amount)
	# the tick over a claimed day
	var tick := Control.new()
	tick.name = "Tick"
	tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tick.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tick.draw.connect(func() -> void:
		var s := minf(tick.size.x, tick.size.y) * 0.5
		var c := tick.size * 0.5
		tick.draw_circle(c, s * 0.5, Color(Pal.GOOD, 0.92), true, -1.0, true)
		Icons.paint(tick, "check", Rect2(c - Vector2(s, s) * 0.36, Vector2(s, s) * 0.72), Pal.SURFACE))
	tile.add_child(tick)
	return tile

## A gift's icons and its words: the coin with its gold, each item with how
## many.
func _fill(tile: PanelContainer, gift: Dictionary) -> void:
	var icons: HBoxContainer = tile.get_child(0).get_node("Icons")
	for c in icons.get_children():
		c.queue_free()
	var words: Array = []
	if int(gift.gold) > 0:
		icons.add_child(BoosterIcon.new("gold", ICON))
		words.append(Locale.number(int(gift.gold)))
	for id: String in gift.items:
		icons.add_child(BoosterIcon.new(id, ICON))
		words.append("x%d" % int(gift.items[id]))
	(tile.get_child(0).get_node("Amount") as Label).text = "  ".join(words)

func _on_open() -> void:
	var w := maxf(content_width(), 1.0)
	_week_line.custom_minimum_size.x = w
	_refresh()

func _refresh() -> void:
	if _tiles.is_empty():
		return
	var today := Daily.date_key()
	var shown := Wallet.calendar_shown_step(today)
	var open := Wallet.calendar_open(today)
	for d in _tiles.size():
		var tile: PanelContainer = _tiles[d]
		(tile.get_child(0).get_node("Day") as Label).text = tr("GIFT_DAY") % (d + 1)
		_fill(tile, Wallet.calendar_gift(d, today))
		var claimed := d < shown or (d == shown and not open)
		var is_today := d == shown and open
		var fill := Pal.SUN_TILE if is_today else (Pal.SURFACE_HI if claimed else Pal.SURFACE)
		var box := CozyTheme.lifted(fill, 28, 12)
		if is_today:
			box.border_color = Pal.SUN
			box.set_border_width_all(6)
		tile.add_theme_stylebox_override("panel", box)
		tile.modulate.a = 0.6 if claimed else 1.0
		(tile.get_node("Tick") as Control).visible = claimed
	_week_line.text = tr("GIFT_WEEK")
	claim_button.set_enabled(open)
	claim_button.set_label(tr("GIFT_CLAIM") if open else tr("GIFT_TOMORROW"))
	var hearts := Progress.hearts(today)
	var claimed_h := Wallet.hearts_claimed(today)
	var gift := Wallet.hearts_gift(today)
	var parts: Array = [tr("GIFT_GOLD") % Locale.number(int(gift.gold))]
	for id: String in gift.items:
		parts.append(tr(Boosters.name_key(id)))
	_hearts_line.text = " + ".join(parts)
	hearts_button.set_enabled(Wallet.hearts_ready(today))
	hearts_button.set_label(tr("GIFT_CLAIMED") if claimed_h else (tr("GIFT_CLAIM") if hearts >= 3 else "%d/3" % hearts))
	_hearts_marks.set_meta("n", hearts)
	_hearts_marks.queue_redraw()

func _draw_hearts() -> void:
	var n := int(_hearts_marks.get_meta("n", 0))
	for i in 3:
		var r := Rect2(Vector2(i * 56.0, 4.0), Vector2(54, 54))
		Icons.paint(_hearts_marks, "heart" if i < n else "heart_line", r, Pal.HEART if i < n else Pal.LINE)

func _claim_day() -> void:
	var step := Wallet.calendar_step()
	var gift := Wallet.claim_calendar()
	if gift.is_empty():
		return
	var tile: Control = _tiles[step]
	_celebrate(tile, gift)

func _claim_hearts() -> void:
	var gift := Wallet.claim_hearts()
	if gift.is_empty():
		return
	_celebrate(hearts_button, gift)

func _celebrate(from: Control, gift: Dictionary) -> void:
	var at := from.get_global_rect().get_center()
	pill.fly_from(at, int(gift.gold))
	_fx.cue("claim")
	Motion.bump(from, 0.12, 0.3)
	var local := at - _fx.get_global_transform().origin
	_fx.puff(local, Pal.SUN, 12)
	_fx.puff(local, Color("fffaf0"), 8)
