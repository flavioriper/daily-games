extends Control

## Griddle's card about one lot (arcade/griddle_screen.gd lays it over the
## fields): what it grows, what a cut gives, how long it takes and how its
## soil stands, and under them what it may be set to: wheat, clover or
## rest, and tonic on or off. A choice is made on the sim by the screen
## (`chose`), and the card closes.

signal closed
## "wheat", "clover", "rest" or "tonic".
signal chose(id: String)

const Sim = preload("res://arcade/griddle_sim.gd")
const Art = preload("res://arcade/griddle_art.gd")
const Dialog = preload("res://ui/hud/dialog.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")

const WIDE := 760.0
const PICTURE := 210.0

var sim: RefCounted
var lot := 0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 8
	add_child(Dialog.scrim())
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var card := Dialog.card(WIDE)
	center.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	card.add_child(col)
	var l: Dictionary = sim.lots[lot]
	var crop := int(l.crop)
	var pic := Control.new()
	pic.name = "Picture"
	pic.custom_minimum_size = Vector2(PICTURE, PICTURE)
	pic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic.draw.connect(func() -> void:
		var mid := pic.size * 0.5
		pic.draw_circle(mid + Vector2(0, 6.0), PICTURE * 0.5, Color(Pal.TEXT, 0.12), true, -1.0, true)
		pic.draw_circle(mid, PICTURE * 0.5, Pal.SURFACE, true, -1.0, true)
		pic.draw_circle(mid, PICTURE * 0.5 - 10.0, Color("e9dcc0"), true, -1.0, true)
		var box := Vector2(150, 120)
		pic.draw_mesh(Art.lot(box, 1 if crop == Sim.FALLOW else 0), null, Transform2D(0.0, mid))
		if crop != Sim.FALLOW:
			pic.draw_mesh(Art.crop(crop, 3, box), null, Transform2D(0.0, mid)))
	col.add_child(pic)
	var name_l := Label.new()
	name_l.name = "Title"
	name_l.theme_type_variation = "SheetTitle"
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.text = tr("GR_LOT_REST") if crop == Sim.FALLOW else tr("GR_LOT_" + String(Sim.CROPS[crop].id).to_upper())
	col.add_child(name_l)
	var facts := []
	if crop != Sim.FALLOW:
		var n: int = sim.gives(lot)
		facts.append([tr("GR_LOT_GIVES"), (tr("GR_GIVES_LOAF_ONE") if n == 1 else tr("GR_GIVES_LOAF_N") % n) if crop == Sim.WHEAT else tr("GR_GIVES_FEED") % n])
		facts.append([tr("GR_LOT_EVERY"), "%d s" % int(round(sim.grow_time(crop)))])
	facts.append([tr("GR_LOT_SOIL"), "%d%%" % int(round(float(l.soil)))])
	for fact: Array in facts:
		var tile := PanelContainer.new()
		tile.add_theme_stylebox_override("panel", Dialog.tile(Pal.SURFACE, 18))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		tile.add_child(row)
		var what := Label.new()
		what.theme_type_variation = "SheetBody"
		what.text = String(fact[0])
		what.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(what)
		var value := Label.new()
		value.theme_type_variation = "SheetTitle"
		value.text = String(fact[1])
		row.add_child(value)
		col.add_child(tile)
	var line := Label.new()
	line.theme_type_variation = "SheetBodyDim"
	line.text = tr("GR_LOT_TIRED") if float(l.soil) < Sim.TIRED and crop != Sim.FALLOW else tr("GR_LOT_NOTE")
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.custom_minimum_size.x = WIDE - 100.0
	col.add_child(line)
	var grows := HBoxContainer.new()
	grows.name = "Grows"
	grows.add_theme_constant_override("separation", 12)
	col.add_child(grows)
	for row in [["wheat", "GR_SET_WHEAT", crop == Sim.WHEAT], ["clover", "GR_SET_CLOVER", crop == Sim.CLOVER], ["rest", "GR_SET_REST", crop == Sim.FALLOW]]:
		grows.add_child(_choice(row[0], tr(row[1]), row[2], Art.PLACE_TINT.fields))
	if crop != Sim.FALLOW:
		var banned: bool = sim.ban > 0.0 and not l.tonic
		var t := _choice("tonic", tr("GR_TONIC_OFF") if l.tonic else (tr("GR_TONIC_BAN") if banned else tr("GR_TONIC_ON")), false, Art.AMBER if l.tonic else Pal.SURFACE)
		t.disabled = banned
		col.add_child(t)
	var done := Dialog.primary("check", tr("GR_DONE"))
	done.name = "Done"
	done.pressed.connect(_close)
	Dialog.buttons(col, done)
	if not Motion.reduce:
		card.pivot_offset = Vector2(WIDE * 0.5, 320)
		card.scale = Vector2.ONE * 0.9
		card.create_tween().tween_property(card, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		Motion.appear(self, 0.0, 1.0, 0.2)

func _close() -> void:
	closed.emit()
	queue_free()

## One of the card's choices: the one that already holds is tinted and
## cannot be pressed.
func _choice(id: String, text: String, on: bool, tint: Color) -> Button:
	var b := Button.new()
	b.name = id
	b.focus_mode = Control.FOCUS_NONE
	b.text = text
	b.theme_type_variation = "IconButton"
	b.custom_minimum_size.y = 96.0
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.disabled = on
	var lit := on or (id == "tonic" and tint != Pal.SURFACE)
	var sb := Dialog.tile(tint if lit else Pal.SURFACE, 0)
	for s in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		b.add_theme_stylebox_override(s, sb)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		b.add_theme_color_override(c, Pal.SURFACE if lit else Pal.TEXT)
	b.pressed.connect(func() -> void:
		chose.emit(id)
		queue_free())
	return b
