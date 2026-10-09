extends "res://ui/hud/sheet.gd"

## The shop: the gold pill, a chip for each Arcade game, and that game's two
## boosters and the Second chance, each with how many are held and Buy at its
## price in gold. Gold is the only price; nothing here costs money. Opened
## from the Arcade tab's strip and from a gold pill.
## Spec docs/superpowers/specs/2026-09-28-gold-gifts-design.md, sections 3 and 4.

const GoldPill = preload("res://ui/menu/gold_pill.gd")
const BoosterIcon = preload("res://arcade/booster_icon.gd")
const Boosters = preload("res://arcade/boosters.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Analytics = preload("res://core/analytics.gd")

const NAMES := {"firefly": "Firefly", "molehill": "Molehill", "stackwood": "Stackwood", "thirteen": "Lucky Thirteen", "posy": "Posy", "peapod": "Peapod", "beeline": "Beeline"}

var pill: Button
var _game := "firefly"
var _chips := {}
var _rows: VBoxContainer
var _line: Label
var _note: Label
var _fx: Node2D

func puzzle_id() -> String:
	return "wallet"

func _card_style() -> StyleBox:
	return CozyTheme.parchment_card()

func _build_sheet(col: VBoxContainer) -> void:
	_fx = Fx2D.new()
	add_child(_fx)
	var head := _title_row(col, "SHOP_TITLE", "coin")
	pill = GoldPill.new()
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(pill)
	head.move_child(pill, x_button.get_index())
	_line = Label.new()
	_line.theme_type_variation = "SheetBodyDim"
	_line.text = "SHOP_LINE"
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_line)
	# one chip a game, wrapping onto a second row on a narrow card
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 12)
	chips.add_theme_constant_override("v_separation", 12)
	col.add_child(chips)
	for g: String in Boosters.GAMES:
		var chip := Button.new()
		chip.text = NAMES[g]
		chip.focus_mode = Control.FOCUS_NONE
		chip.custom_minimum_size = Vector2(150, 76)
		chip.add_theme_font_override("font", CozyTheme.display(700))
		chip.add_theme_font_size_override("font_size", 30)
		chip.pressed.connect(func() -> void: _pick(g))
		chips.add_child(chip)
		_chips[g] = chip
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 16)
	col.add_child(_rows)
	_note = Label.new()
	_note.theme_type_variation = "SheetBodyDim"
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.visible = false
	col.add_child(_note)
	var close_button := IconButton.new("check", "BTN_CLOSE", "IconButton")
	close_button.custom_minimum_size.y = ROW
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_button.pressed.connect(close)
	col.add_child(close_button)
	Wallet.changed.connect(_refresh_rows)

## Opens on `game`'s boosters (the one the player came from).
func open_for(game: String, door: String) -> void:
	if is_open():
		return
	if Boosters.GAMES.has(game):
		_game = game
	Analytics.track("shop_opened", {"door": door, "game": _game})
	open()

func _on_open() -> void:
	_line.custom_minimum_size.x = maxf(content_width(), 1.0)
	_note.visible = false
	_pick(_game)

func _pick(game: String) -> void:
	_game = game
	for g: String in _chips:
		var b: Button = _chips[g]
		var on := g == game
		var sb := CozyTheme.chip(Boosters.TINT[g] if on else Pal.SURFACE, 200, Color(Pal.LINE, 0.35), 0 if on else 2)
		for s in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(s, sb)
		b.add_theme_color_override("font_color", Pal.SURFACE if on else Pal.TEXT)
		b.add_theme_color_override("font_hover_color", Pal.SURFACE if on else Pal.TEXT)
		b.add_theme_color_override("font_pressed_color", Pal.SURFACE if on else Pal.TEXT)
	for c in _rows.get_children():
		_rows.remove_child(c)
		c.queue_free()
	var ids: Array = Boosters.of(game)
	ids.append(Boosters.CHANCE)
	for id: String in ids:
		_rows.add_child(_row(id))
	_refresh_rows()

func _row(id: String) -> Control:
	var panel := PanelContainer.new()
	panel.name = id
	var box := CozyTheme.lifted(Pal.SURFACE, 30, 18)
	box.set_border_width_all(2)
	box.border_color = Color(Pal.LINE, 0.25)
	panel.add_theme_stylebox_override("panel", box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	panel.add_child(row)
	var icon := BoosterIcon.new(id, 104)
	icon.name = "Icon"
	row.add_child(icon)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_theme_constant_override("separation", 0)
	row.add_child(words)
	var name_l := Label.new()
	name_l.theme_type_variation = "CardName"
	name_l.text = Boosters.name_key(id)
	words.add_child(name_l)
	var line := Label.new()
	line.theme_type_variation = "CardBlurb"
	line.text = Boosters.chance_key(_game) if id == Boosters.CHANCE else Boosters.line_key(id)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.custom_minimum_size.x = 300
	words.add_child(line)
	var buy := IconButton.new("coin", Locale.number(Boosters.price(id)), "SunButton")
	buy.name = "Buy"
	buy.custom_minimum_size = Vector2(190, 96)
	buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	buy.pressed.connect(_buy.bind(id, buy))
	row.add_child(buy)
	return panel

func _refresh_rows() -> void:
	if _rows == null:
		return
	for panel in _rows.get_children():
		if panel.is_queued_for_deletion():
			continue
		var id := String(panel.name)
		var icon = panel.find_child("Icon", true, false)
		if icon != null:
			icon.count = Wallet.count(id)
		var buy = panel.find_child("Buy", true, false)
		if buy != null:
			buy.set_enabled(Wallet.gold() >= Boosters.price(id))

func _buy(id: String, button: Control) -> void:
	if not Wallet.buy(id):
		Motion.shiver(button)
		_note.text = tr("SHOP_SHORT")
		_note.visible = true
		_fx.cue("refused")
		return
	_note.visible = false
	_fx.cue("buy")
	var local := button.get_global_rect().get_center() - _fx.get_global_transform().origin
	_fx.puff(local, Pal.SUN, 10)
	var icon: Control = button.get_parent().get_node("Icon")
	icon.pivot_offset = icon.size * 0.5
	Motion.bump(icon, 0.2, 0.3)
