extends VBoxContainer

## The Valley tab: slow places that feed each other through one shared
## inventory (core/stock.gd), with no last level and no finish. Only the
## first is here, the Grove (valley/grove_screen.gd); the others are still
## to be planned, so the tab holds one card and the wood, and the card says
## beside its name what the place makes and how much a minute. Its body takes the
## day row's and the grid's room, as Versus, Arcade, Stats and Streak do.
## Spec docs/superpowers/specs/2026-10-05-valley-grove-design.md, section 1.
##
## The card's picture is the land as it stands: the grove is read from its
## file when the tab is shown and goes on growing in front of you, so the
## tab alone says whether a visit is worth it. Pressing Play writes it back
## first, and the screen opens on the very trees the card was showing.

signal play(place: String)

const Pal = preload("res://core/palette.gd")
const CozyTheme = preload("res://ui/theme.gd")
const IconButton = preload("res://ui/hud/icon_button.gd")
const Sim = preload("res://valley/grove_sim.gd")
const Art = preload("res://valley/grove_art.gd")
const Life = preload("res://valley/grove_life.gd")

const GAP := 20
const PAD := 24
const RADIUS := 36
const PILL_H := 84.0
const ART_H_MIN := 260.0
const BAR_H := 22.0
const CHIP_H := 52.0
const FILL := Color("fcf7ef")
## The land keeps this much water round it on the card.
const SHORE := 22.0
const SHORE_FOOT := 50.0
## And over its back edge, for the crowns that stand there.
const SHORE_TOP := 96.0

var _sim: RefCounted
var _wood_l: Label
var _rate: Label
var _art: Control
## The trees and their shadows, as the screen shows them
## (valley/grove_life.gd), on two layers over the picture's ground.
var _life: RefCounted = Life.new()
var _shade: Control
var _stand: Control
var _ground: ArrayMesh
var _light: ArrayMesh
var _grass: Array[MultiMesh] = []
var _u := 1.0
var _origin := Vector2.ZERO
var _line: Label
var _count: Label
var _bar: Control

func _init() -> void:
	add_theme_constant_override("separation", GAP)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var strip := HBoxContainer.new()
	strip.name = "StockStrip"
	strip.add_child(_wood_pill())
	add_child(strip)
	# the card takes the tab: the land is taller than it is wide since
	# 2026-10-06, and its picture wants the height
	add_child(_grove_card())
	set_process(false)

func _ready() -> void:
	Stock.changed.connect(_write_wood)
	visibility_changed.connect(func() -> void: set_process(is_visible_in_tree()))
	_write_wood()

## The wood held for the whole valley, as the Arcade tab shows the gold.
func _wood_pill() -> Control:
	var pill := PanelContainer.new()
	pill.name = "Wood"
	pill.custom_minimum_size = Vector2(240, PILL_H)
	pill.add_theme_stylebox_override("panel", CozyTheme.lifted(Pal.SURFACE, int(PILL_H * 0.5), 8))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	pill.add_child(row)
	var icon := Control.new()
	icon.custom_minimum_size = Vector2(76, 60)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.draw.connect(func() -> void:
		icon.draw_mesh(Art.icon("wood"), null, Transform2D(-0.3, Vector2(0.8, 0.8), 0.0, icon.size * 0.5 + Vector2(6.0, 0.0))))
	row.add_child(icon)
	_wood_l = Label.new()
	_wood_l.theme_type_variation = "SheetTitle"
	_wood_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_wood_l)
	var kicker := Label.new()
	kicker.text = "GROVE_WOOD"
	kicker.theme_type_variation = "MenuKicker"
	kicker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(kicker)
	var tail := Control.new()
	tail.custom_minimum_size.x = 14
	row.add_child(tail)
	return pill

func _grove_card() -> Control:
	var card := PanelContainer.new()
	card.name = "Grove"
	card.add_theme_stylebox_override("panel", CozyTheme.lifted(FILL, RADIUS, PAD))
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	card.add_child(col)
	_art = Control.new()
	_art.name = "Art"
	_art.custom_minimum_size.y = ART_H_MIN
	_art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.resized.connect(_layout_art)
	_art.draw.connect(_draw_art)
	_art.clip_contents = true
	# the land's own wind: only what stands on a foot of its own leans
	_art.material = Art.wind()
	col.add_child(_art)
	_shade = _art_layer(func() -> void:
		if _sim != null:
			_life.draw_shade(_shade, _sim))
	_shade.material = _life.shade
	_stand = _art_layer(_draw_stand)
	_stand.material = Art.wind()
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", GAP)
	col.add_child(head)
	var name_l := Label.new()
	name_l.text = "Grove"
	name_l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	name_l.theme_type_variation = "CardName"
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_l)
	head.add_child(_makes_chip())
	_line = Label.new()
	_line.text = "VALLEY_GROVE_BLURB"
	_line.theme_type_variation = "CardBlurb"
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_line)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GAP)
	col.add_child(row)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	left.add_theme_constant_override("separation", 6)
	row.add_child(left)
	_bar = Control.new()
	_bar.custom_minimum_size.y = BAR_H
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.draw.connect(_draw_bar)
	left.add_child(_bar)
	_count = Label.new()
	_count.theme_type_variation = "CardBlurb"
	left.add_child(_count)
	var go := IconButton.new("play", "VS_PLAY", "SunButton")
	go.name = "Play"
	go.custom_minimum_size = Vector2(260, 96)
	go.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	go.pressed.connect(_on_play)
	row.add_child(go)
	return card

## What the place makes, beside its name: the log of the pill above, the
## word, and how much of it a minute comes in by itself (the user,
## 2026-10-06: "show what the grove game has as outcome ... so user can
## understand it's meant to farm wood. Show a wood/min rate"). The rate is
## the most the grove's jetty can send in a minute at its levels
## (`Sim.wood_per_min`, written by `_write_rate`).
func _makes_chip() -> Control:
	var chip := PanelContainer.new()
	chip.name = "Makes"
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sb := StyleBoxFlat.new()
	sb.bg_color = Pal.SURFACE_HI
	sb.set_corner_radius_all(int(CHIP_H * 0.5))
	sb.content_margin_left = 10
	sb.content_margin_right = 22
	chip.add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	chip.add_child(row)
	var icon := Control.new()
	icon.custom_minimum_size = Vector2(56, CHIP_H)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.draw.connect(func() -> void:
		icon.draw_mesh(Art.icon("wood"), null, Transform2D(-0.3, Vector2(0.6, 0.6), 0.0, icon.size * 0.5 + Vector2(4.0, 0.0))))
	row.add_child(icon)
	var what := Label.new()
	what.text = "GROVE_WOOD"
	what.theme_type_variation = "MenuKicker"
	what.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(what)
	var gap := Control.new()
	gap.custom_minimum_size.x = 6
	row.add_child(gap)
	_rate = Label.new()
	_rate.name = "Rate"
	_rate.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_rate.theme_type_variation = "Badge"
	_rate.add_theme_font_size_override("font_size", 30)
	_rate.add_theme_color_override("font_color", Pal.TEXT)
	_rate.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_rate)
	var per := Label.new()
	per.text = "VALLEY_PER_MIN"
	per.theme_type_variation = "CardBlurb"
	per.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(per)
	_write_rate()
	return chip

func _art_layer(draws: Callable) -> Control:
	var layer := Control.new()
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.draw.connect(draws)
	_art.add_child(layer)
	return layer

## Called as the tab is shown: the grove as it stands now.
func refresh() -> void:
	_sim = Sim.load_saved(Time.get_unix_time_from_system())
	_write_wood()
	_write_count()
	_write_rate()
	_redraw_art()

func _redraw_art() -> void:
	_art.queue_redraw()
	_shade.queue_redraw()
	_stand.queue_redraw()

func _on_play() -> void:
	# the screen reads the grove from its file: hand it the one on the card
	if _sim != null:
		_sim.save(Time.get_unix_time_from_system())
	play.emit("grove")

func _process(delta: float) -> void:
	if _sim == null:
		return
	var before: int = _sim.trees.size()
	# nobody is in the grove while it is looked at from here: its beavers
	# do not bite, and get these seconds as time away when it is next read
	_sim.step(delta, false, Vector2.ZERO, false)
	_sim.events.clear()
	# what the raft has landed is wood in the valley now. The grove is kept
	# at once: the tab reads it from its file each time it is shown, and one
	# kept from before the landing would land the same wood again.
	var landed: int = _sim.take_owed()
	if landed > 0:
		Stock.add("wood", landed, "grove")
		_sim.save(Time.get_unix_time_from_system())
		Stock.flush()
	if _sim.trees.size() != before:
		_write_count()
	Art.blow()
	# the tab slides and the list scrolls: the shadows are kept to where the
	# land is now
	_life.place(_origin, _u, _art.get_global_transform())
	_shade.queue_redraw()
	_stand.queue_redraw()

func _write_wood() -> void:
	if _wood_l != null:
		_wood_l.text = Art.short(Stock.count("wood"))

## A rate of none is "--", not 0 (the jetty always sends something, so it is
## what a tab with no grove read yet shows). Under ten a minute it keeps one
## decimal.
func _write_rate() -> void:
	var rate: float = 0.0 if _sim == null else _sim.wood_per_min()
	if rate <= 0.0:
		_rate.text = "--"
	elif rate < 10.0:
		_rate.text = ("%.1f" % rate).trim_suffix(".0")
	else:
		_rate.text = Art.short(roundi(rate))

func _write_count() -> void:
	if _sim == null:
		return
	var full: bool = _sim.trees.size() >= _sim.room()
	_count.text = tr("VALLEY_FULL") if full else tr("GROVE_TREES") % [_sim.trees.size(), _sim.room()]
	_bar.queue_redraw()

func _draw_bar() -> void:
	var s := _bar.size
	var back := StyleBoxFlat.new()
	back.bg_color = Pal.SURFACE_HI
	back.set_corner_radius_all(int(s.y * 0.5))
	_bar.draw_style_box(back, Rect2(Vector2.ZERO, s))
	if _sim == null or _sim.trees.is_empty():
		return
	var part: float = clampf(float(_sim.trees.size()) / _sim.room(), 0.0, 1.0)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Pal.SUN if part >= 1.0 else Pal.GOOD
	fill.set_corner_radius_all(int(s.y * 0.5))
	_bar.draw_style_box(fill, Rect2(Vector2.ZERO, Vector2(maxf(s.y, s.x * part), s.y)))

## The whole land, as big as the picture's room lets it be, water all round.
func _layout_art() -> void:
	var s := _art.size
	if s.x <= 0.0 or s.y <= 0.0:
		return
	var view: Rect2 = Art.VIEW
	_u = minf((s.x - SHORE * 2.0) / view.size.x, (s.y - SHORE_TOP - SHORE_FOOT) / view.size.y)
	_origin = Vector2((s.x - view.size.x * _u) * 0.5, SHORE_TOP + (s.y - SHORE_TOP - SHORE_FOOT - view.size.y * _u) * 0.5) - view.position * _u
	_ground = Art.ground(s, _origin, _u)
	_grass = Art.grass(_origin, _u)
	_light = Art.light(s)
	_life.place(_origin, _u, _art.get_global_transform())
	_redraw_art()

func _draw_art() -> void:
	if _ground == null:
		return
	_art.draw_mesh(_ground, null)
	for mm: MultiMesh in _grass:
		_art.draw_multimesh(mm, null)

func _draw_stand() -> void:
	if _ground == null:
		return
	if _sim != null:
		_life.draw(_stand, _sim)
	# drawn where it lies, so the wind the trees wear leaves it alone
	_stand.draw_mesh(_light, null)
