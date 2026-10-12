extends Control

## Furrow's card about one thing: a crop, a hen or a cow (the user,
## 2026-10-12: "when user click on the plant for the first time it should
## display a dialog about how much it cost to sell and takes to be ready,
## if user want to see again, must hold touch on it for a while"). The
## screen (arcade/furrow_screen.gd) fills it in and lays it over the field:
## the thing's picture, its name, a row for each fact (what it sells for,
## how long it takes, how long it keeps), a line under them, and Got it.
## A crop still growing has a second button that digs it up.

signal closed
## The second button, when `dig` is set.
signal dug

const Art = preload("res://arcade/furrow_art.gd")
const Dialog = preload("res://ui/hud/dialog.gd")
const Shop = preload("res://arcade/furrow_shop.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")

const WIDE := 700.0
const PICTURE := 230.0

var title := ""
## Draws the thing on the picture's Control, its middle given.
var picture: Callable
var tint := Color("f3ead6")
## The facts: [label, value, whether the value is seeds].
var facts: Array = []
var note := ""
## The second button's words; none when empty.
var dig := ""

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
	col.add_theme_constant_override("separation", 16)
	card.add_child(col)
	var pic := Control.new()
	pic.name = "Picture"
	pic.custom_minimum_size = Vector2(PICTURE, PICTURE)
	pic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic.draw.connect(func() -> void:
		var mid := pic.size * 0.5
		pic.draw_circle(mid + Vector2(0, 6.0), PICTURE * 0.5, Color(Pal.TEXT, 0.12), true, -1.0, true)
		pic.draw_circle(mid, PICTURE * 0.5, Pal.SURFACE, true, -1.0, true)
		pic.draw_circle(mid, PICTURE * 0.5 - 10.0, tint, true, -1.0, true)
		if picture.is_valid():
			picture.call(pic, mid))
	col.add_child(pic)
	var name_l := Label.new()
	name_l.name = "Title"
	name_l.theme_type_variation = "SheetTitle"
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.text = title
	col.add_child(name_l)
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
		if bool(fact[2]):
			row.add_child(Shop.seed_icon(40.0))
		var value := Label.new()
		value.theme_type_variation = "SheetTitle"
		value.text = String(fact[1])
		row.add_child(value)
		col.add_child(tile)
	if note != "":
		var line := Label.new()
		line.theme_type_variation = "SheetBodyDim"
		line.text = note
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.custom_minimum_size.x = WIDE - 100.0
		col.add_child(line)
	var done := Dialog.primary("check", tr("FW_ABOUT_DONE"))
	done.name = "Done"
	done.pressed.connect(func() -> void:
		closed.emit()
		queue_free())
	var second: Button = null
	if dig != "":
		second = Dialog.secondary("reset", dig)
		second.name = "Dig"
		second.pressed.connect(func() -> void:
			dug.emit()
			closed.emit()
			queue_free())
	Dialog.buttons(col, done, second)
	if not Motion.reduce:
		card.pivot_offset = Vector2(WIDE * 0.5, 320)
		card.scale = Vector2.ONE * 0.9
		card.create_tween().tween_property(card, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		Motion.appear(self, 0.0, 1.0, 0.2)
		pic.pivot_offset = Vector2(PICTURE, PICTURE) * 0.5
		pic.scale = Vector2.ONE * 0.6
		pic.create_tween().tween_property(pic, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.08)
