extends Control

## Tally's upgrades: six tracks paid in delivered numbers
## (arcade/tally_sim.gd `asks`, `buy`), a card laid over the paper by the
## screen. A row is one track: its piece, its level and what the next does,
## the numbers it asks for, each a token with what the box holds of it over
## what is asked (green once met), and a button that buys it when all are
## met. A track not opened yet is dim with the level it opens at; one at its
## top says so. Spec docs/superpowers/specs/2026-10-15-arcade-tally-design.md.

signal closed
signal bought(id: String)

const Sim = preload("res://arcade/tally_sim.gd")
const Art = preload("res://arcade/tally_art.gd")
const Dialog = preload("res://ui/hud/dialog.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const CozyTheme = preload("res://ui/theme.gd")

const ROW_H := 176.0
const WIDE := 920.0
const UNIT := {"belt": "TL_PER_S", "dig": "TL_BELTS", "add": "TL_PER_S", "mul": "TL_PER_S", "sub": "TL_PER_S", "pow": "TL_PER_S"}

var sim: RefCounted
var _rows := {}
var _font: Font

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 8
	_font = CozyTheme.display(700)
	add_child(Dialog.scrim())
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var card := Dialog.card(WIDE)
	center.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	card.add_child(col)
	col.add_child(Dialog.head("TL_UPGRADES", "trend"))
	var line := Label.new()
	line.text = "TL_UPGRADES_LINE"
	line.theme_type_variation = "CardBlurb"
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.custom_minimum_size.x = WIDE - 120
	col.add_child(line)
	for id: String in Sim.TRACKS:
		var row := _row(id)
		col.add_child(row)
		_rows[id] = row
	var done := Dialog.primary("check", tr("TL_DONE"))
	done.name = "Done"
	done.pressed.connect(func() -> void:
		closed.emit()
		queue_free())
	Dialog.buttons(col, done)
	refresh()
	if not Motion.reduce:
		card.pivot_offset = Vector2(WIDE * 0.5, 400)
		card.scale = Vector2.ONE * 0.9
		card.create_tween().tween_property(card, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		Motion.appear(self, 0.0, 1.0, 0.2)

func _row(id: String) -> PanelContainer:
	var p := PanelContainer.new()
	p.name = id
	p.custom_minimum_size.y = ROW_H
	p.add_theme_stylebox_override("panel", Dialog.tile(Pal.SURFACE, 14))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	p.add_child(row)
	var icon := Control.new()
	icon.custom_minimum_size = Vector2(96, 96)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.draw.connect(func() -> void:
		var kd := int(Sim.TRACK_KIND[id])
		icon.draw_mesh(Art.icon(kd), null, Transform2D(0.0, Vector2.ONE * 0.9, 0.0, icon.size * 0.5)))
	row.add_child(icon)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_theme_constant_override("separation", 2)
	row.add_child(words)
	var name_l := Label.new()
	name_l.name = "Name"
	name_l.theme_type_variation = "CardName"
	words.add_child(name_l)
	var status := Label.new()
	status.name = "Status"
	status.theme_type_variation = "MenuKicker"
	words.add_child(status)
	var asks := Control.new()
	asks.name = "Asks"
	asks.custom_minimum_size = Vector2(0, 70)
	asks.draw.connect(_draw_asks.bind(asks, id))
	words.add_child(asks)
	var buy := Button.new()
	buy.name = "Buy"
	buy.focus_mode = Control.FOCUS_NONE
	buy.theme_type_variation = "PrimaryButton"
	buy.custom_minimum_size = Vector2(150, 84)
	buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	buy.text = tr("TL_BUY")
	buy.pressed.connect(_buy.bind(id))
	row.add_child(buy)
	return p

## What a rank asks: a token a number with held over asked under it.
func _draw_asks(c: Control, id: String) -> void:
	if not sim.track_open(id) or sim.at_top(id):
		return
	var x := 34.0
	for a: Array in sim.asks(id):
		var v := int(a[0])
		var need := int(a[1])
		var have: int = sim.held(v)
		var at := Vector2(x, c.size.y * 0.5)
		c.draw_mesh(Art.token(false), null, Transform2D(0.0, Vector2.ONE * 0.95, 0.0, at))
		var txt := Sim.short(v)
		var fs := 30 if txt.length() <= 2 else (25 if txt.length() == 3 else 20)
		var w := _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		c.draw_string(_font, at + Vector2(-w * 0.5, fs * 0.36 - 2.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Art.INK)
		var count := "%s/%s" % [Sim.short(mini(have, need)), Sim.short(need)]
		var col := Color("4f8f45") if have >= need else Pal.TEXT_DIM
		c.draw_string(_font, at + Vector2(40, 10), count, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, col)
		x += 44.0 + _font.get_string_size(count, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x + 40.0

func _speed_text(id: String, l: int) -> String:
	var v := Sim.speed_for(id, l)
	var s := str(int(v)) if absf(v - roundf(v)) < 0.001 else String.num(v, 2).trim_suffix("0")
	return tr(UNIT[id]) % s

func _buy(id: String) -> void:
	if not sim.buy(id):
		return
	var p: Control = _rows[id]
	p.pivot_offset = p.size * 0.5
	Motion.squash(p, 0.06, 0.16)
	bought.emit(id)
	refresh()

func refresh() -> void:
	for id: String in _rows:
		var p: PanelContainer = _rows[id]
		var open: bool = sim.track_open(id)
		var top: bool = sim.at_top(id)
		var l := int(sim.lv[id])
		(p.find_child("Name", true, false) as Label).text = tr("TL_TRACK_" + id.to_upper())
		var st := p.find_child("Status", true, false) as Label
		if not open:
			st.text = tr("TL_OPENS_AT") % (int(Sim.UNLOCK[int(Sim.TRACK_KIND[id])]) + 1)
		elif top:
			st.text = tr("TL_AT_TOP") % [l, _speed_text(id, l)]
		else:
			st.text = tr("TL_TRACK_LINE") % [l, _speed_text(id, l), _speed_text(id, l + 1)]
		var buy := p.find_child("Buy", true, false) as Button
		buy.visible = open and not top
		buy.disabled = not sim.can_buy(id)
		p.modulate.a = 1.0 if open else 0.5
		(p.find_child("Asks", true, false) as Control).queue_redraw()
