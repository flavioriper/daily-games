extends Control

## Before a run: the game's two boosters (arcade/boosters.gd) as toggles,
## each with how many are held or, with none held, its price -- a toggled one
## with none held is bought on Play -- the gold pill, and Play. Nothing starts
## picked. Laid over an Arcade screen by the screen itself, and gone once
## Play is pressed.
## Spec docs/superpowers/specs/2026-09-28-gold-gifts-design.md, section 4.

signal play(ids: Array)

const Boosters = preload("res://arcade/boosters.gd")
const BoosterIcon = preload("res://arcade/booster_icon.gd")
const GoldPill = preload("res://ui/menu/gold_pill.gd")
const CozyTheme = preload("res://ui/theme.gd")
const IconButton = preload("res://ui/hud/icon_button.gd")
const Icons = preload("res://ui/icons.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")

var game := ""
var _picked := {}
var _toggles := {}
var _go: Button
var _pill: Button

## Whether a run of `game` should stop at the card: a booster held, or the
## gold for one.
static func wanted(g: String) -> bool:
	for id: String in Boosters.of(g):
		if Wallet.can_have(id):
			return true
	return false

func _init(g: String) -> void:
	game = g

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 8
	var scrim := ColorRect.new()
	scrim.color = Color(Pal.OUTLINE, 0.4)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scrim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var card := PanelContainer.new()
	card.name = "Card"
	card.add_theme_stylebox_override("panel", CozyTheme.lifted(Pal.SURFACE, 44, 36))
	card.custom_minimum_size.x = 860
	center.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 22)
	card.add_child(col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	col.add_child(head)
	var title := Label.new()
	title.theme_type_variation = "SheetTitle"
	title.text = "BOOST_TITLE"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_pill = GoldPill.new()
	_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(_pill)
	var line := Label.new()
	line.theme_type_variation = "SheetBodyDim"
	line.text = "BOOST_LINE"
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.custom_minimum_size.x = 780
	col.add_child(line)
	for id: String in Boosters.of(game):
		var t := _toggle(id)
		col.add_child(t)
		_toggles[id] = t
	_go = IconButton.new("play", tr("VS_PLAY"), "SunButton")
	_go.name = "Play"
	_go.custom_minimum_size.y = 120
	_go.pressed.connect(_on_play)
	col.add_child(_go)
	_refresh()
	if not Motion.reduce:
		card.pivot_offset = Vector2(430, 300)
		card.scale = Vector2.ONE * 0.9
		card.create_tween().tween_property(card, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		Motion.appear(self, 0.0, 1.0, 0.2)

func _toggle(id: String) -> Button:
	var b := Button.new()
	b.name = id
	b.focus_mode = Control.FOCUS_NONE
	b.toggle_mode = true
	b.custom_minimum_size.y = 150
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 20
	row.offset_right = -24
	row.add_theme_constant_override("separation", 20)
	b.add_child(row)
	var icon := BoosterIcon.new(id, 108)
	icon.name = "Icon"
	row.add_child(icon)
	var words := VBoxContainer.new()
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_theme_constant_override("separation", 0)
	row.add_child(words)
	var name_l := Label.new()
	name_l.theme_type_variation = "CardName"
	name_l.text = Boosters.name_key(id)
	words.add_child(name_l)
	var what := Label.new()
	what.theme_type_variation = "CardBlurb"
	what.text = Boosters.line_key(id)
	words.add_child(what)
	var status := Label.new()
	status.name = "Status"
	status.theme_type_variation = "CardBlurb"
	status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(status)
	# the tick on a picked one
	var tick := Control.new()
	tick.name = "Tick"
	tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tick.custom_minimum_size = Vector2(56, 56)
	tick.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tick.draw.connect(func() -> void:
		var on := bool(_picked.get(id, false))
		tick.draw_circle(tick.size * 0.5, 26.0, Pal.GOOD if on else Color(Pal.LINE, 0.35), true, -1.0, true)
		if on:
			Icons.paint(tick, "check", Rect2(tick.size * 0.5 - Vector2(18, 18), Vector2(36, 36)), Pal.SURFACE))
	row.add_child(tick)
	b.toggled.connect(func(on: bool) -> void:
		_picked[id] = on
		Motion.squash(b, 0.06, 0.16)
		_refresh())
	return b

func _refresh() -> void:
	# what the picked ones still to buy would cost
	var owed := 0
	for id: String in _toggles:
		if bool(_picked.get(id, false)) and Wallet.count(id) <= 0:
			owed += Boosters.price(id)
	for id: String in _toggles:
		var b: Button = _toggles[id]
		var n := Wallet.count(id)
		var on := bool(_picked.get(id, false))
		(b.find_child("Icon", true, false) as Control).count = n
		var status: Label = b.find_child("Status", true, false)
		status.text = tr("BOOST_HELD") % n if n > 0 else "%s %s" % [Locale.number(Boosters.price(id)), tr("GOLD_WORD")]
		# with none held and not picked, it can be picked only if the gold
		# covers it on top of what is already owed
		var afford := n > 0 or on or Wallet.gold() >= owed + Boosters.price(id)
		b.disabled = not afford
		var fill := Pal.SUN_TILE if on else Pal.SURFACE
		var sb := CozyTheme.chip(fill, 30, Pal.SUN if on else Color(Pal.LINE, 0.6), 5 if on else 3)
		for s in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			b.add_theme_stylebox_override(s, sb)
		b.modulate.a = 1.0 if afford else 0.5
		(b.find_child("Tick", true, false) as Control).queue_redraw()

func _on_play() -> void:
	var ids: Array = []
	for id: String in _toggles:
		if bool(_picked.get(id, false)) and Wallet.use(id, game, true):
			ids.append(id)
	play.emit(ids)
	queue_free()
