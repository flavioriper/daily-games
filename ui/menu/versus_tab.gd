extends VBoxContainer

## The Versus tab: games played against someone rather than against the
## day's board. Snooker is the first, and for now the someone is the
## computer (versus/snooker_screen.gd); online play is the plan the tab is
## named for. Its body takes the day row's and the grid's room, the way
## Stats and Streak do, under the same header and over the same bar.
##
## One card a game: a painted banner with the real table lying across it (the
## game's own drawing, still, so it costs one mesh and no frame), the name,
## a line, the three levels, the record at the level picked and Play. A
## quieter card under it says more are coming.

signal play(game: String, level: int)

const Pal = preload("res://core/palette.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Vistas = preload("res://ui/menu/vistas.gd")
const IconButton = preload("res://ui/hud/icon_button.gd")
const Icons = preload("res://ui/icons.gd")
const SunDot = preload("res://ui/sun_dot.gd")
const Record = preload("res://versus/versus_record.gd")
const Sim = preload("res://versus/snooker_sim.gd")
const Table = preload("res://versus/snooker_table.gd")

const GAP := 20
const PAD := 26
const RADIUS := 36
const ART_H := 330.0
const LEVELS := ["DIFF_EASY", "DIFF_MEDIUM", "DIFF_HARD"]
const FILL := Color("fcf7ef")
static var PLAIN := CanvasItemMaterial.new()

var _level := 1
var _chips: Array[Button] = []
var _record: Label
var _art: Control
var _table: Control

func _init() -> void:
	add_theme_constant_override("separation", GAP)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_level = Record.last_level("snooker")
	add_child(_snooker_card())
	add_child(_soon_card())

func _card() -> VBoxContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", CozyTheme.lifted(FILL, RADIUS, PAD))
	card.material = PLAIN
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	card.add_child(col)
	return col

func _snooker_card() -> Control:
	var col := _card()
	# The banner: the treehouse at dusk with the table laid across it.
	_art = Vistas.card_plate("snooker", Pal.ACCENT_2)
	_art.custom_minimum_size.y = ART_H
	# A tall phone's spare height goes to the picture, not to a gap under
	# the cards.
	_art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_art.clip_contents = true
	col.add_child(_art)
	var sim := Sim.new()
	_table = Table.new()
	_table.still = true
	_table.sim = sim
	_table.show_guide = false
	_table.aim_dir = (sim.pos[11] - sim.pos[Sim.CUE]).normalized()
	_table.power = 0.35
	_art.add_child(_table)
	_art.resized.connect(_lay_table)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	col.add_child(head)
	var name_l := Label.new()
	name_l.text = "Snooker"
	name_l.theme_type_variation = "CardName"
	head.add_child(name_l)
	name_l.add_child(SunDot.new(name_l))
	var chip := Label.new()
	chip.text = "VS_AGAINST"
	chip.theme_type_variation = "MenuKicker"
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(chip)
	var blurb := Label.new()
	blurb.text = "VS_SNOOKER_BLURB"
	blurb.theme_type_variation = "CardBlurb"
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(blurb)

	var levels := HBoxContainer.new()
	levels.add_theme_constant_override("separation", 14)
	col.add_child(levels)
	for i in LEVELS.size():
		var b := Button.new()
		b.text = LEVELS[i]
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size.y = 84
		b.add_theme_font_size_override("font_size", 32)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_pick.bind(i))
		levels.add_child(b)
		_chips.append(b)
	_record = Label.new()
	_record.theme_type_variation = "CardBlurb"
	_record.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_record)
	var go := IconButton.new("chevron_right", tr("VS_PLAY"), "SunButton")
	go.custom_minimum_size.y = 120
	go.pressed.connect(func() -> void:
		Record.set_last_level("snooker", _level)
		play.emit("snooker", _level))
	col.add_child(go)
	_paint_chips()
	var card: Control = col.get_parent()
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return card

## The table lies on its side across the banner, turned about its middle.
func _lay_table() -> void:
	var span := Vector2(Sim.W, Sim.L) + Vector2.ONE * 2.0 * (Table.CUSHION + Table.RAIL)
	# Lying down, the table's length runs across the banner: as tall as the
	# banner allows, but never wider than it.
	var h := minf(_art.size.y - 36.0, (_art.size.x - 60.0) * span.x / span.y)
	var w := h * span.y / span.x
	_table.size = Vector2(h, w)
	_table.pivot_offset = _table.size * 0.5
	_table.rotation = -PI * 0.5
	_table.position = _art.size * 0.5 - _table.size * 0.5
	_table.queue_redraw()

func _soon_card() -> Control:
	var col := _card()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	col.add_child(row)
	var icon := Control.new()
	icon.custom_minimum_size = Vector2(72, 72)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.draw.connect(func() -> void:
		Icons.paint(icon, "versus", Rect2(Vector2.ZERO, icon.size), Pal.TEXT_DIM))
	row.add_child(icon)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(words)
	var t := Label.new()
	t.text = "VS_SOON"
	t.theme_type_variation = "CardTitle"
	words.add_child(t)
	var l := Label.new()
	l.text = "VS_SOON_LINE"
	l.theme_type_variation = "CardBlurb"
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.add_child(l)
	return col.get_parent()

func _pick(i: int) -> void:
	_level = i
	Record.set_last_level("snooker", i)
	_paint_chips()

func _paint_chips() -> void:
	for i in _chips.size():
		var on := i == _level
		var b := _chips[i]
		var fill := Pal.SUN_TILE if on else Pal.SURFACE
		var border := Pal.ACCENT_2 if on else Pal.LINE
		for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
			b.add_theme_stylebox_override(state, CozyTheme.chip(fill, 28, border, 4 if on else 2, state == "pressed"))
		b.add_theme_color_override("font_color", Pal.ACCENT_2 if on else Pal.TEXT)
		b.add_theme_color_override("font_hover_color", Pal.ACCENT_2 if on else Pal.TEXT)
		b.add_theme_color_override("font_pressed_color", Pal.ACCENT_2 if on else Pal.TEXT)
	refresh()

func refresh() -> void:
	var rec := Record.get_record("snooker", _level)
	_record.text = tr("VS_RECORD") % [rec.x, rec.y]
