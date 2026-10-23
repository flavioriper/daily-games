extends Control

## Tally's parts, a card over the paper from the tray's Parts slot. A part is
## a template saved from a pick on the paper (the user, 2026-10-19: "now
## submodule will be just a building template saved that user can use to
## spawn. User can only place or delete a submodule, no edit"): a row a
## part, its block small, its name and size, with Place (the hand takes the
## template to set down as plain pieces) and a bin. The screen mounts it
## (`sim`) and does what `chose` asks.

signal closed
## "place" or "drop" with a part's id.
signal chose(what: String, id: int)

const Sim = preload("res://arcade/tally_sim.gd")
const Art = preload("res://arcade/tally_art.gd")
const Dialog = preload("res://ui/hud/dialog.gd")
const IconButton = preload("res://ui/hud/icon_button.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const CozyTheme = preload("res://ui/theme.gd")
const TouchScroll = preload("res://ui/touch_scroll.gd")

const WIDE := 900.0
const MINI := 96.0
const LIST_MOST := 620.0
const ROW_H := 84.0

var sim: RefCounted
var _touch: Node

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
	col.add_theme_constant_override("separation", 18)
	card.add_child(col)
	_list_card(col)
	if not Motion.reduce:
		card.pivot_offset = Vector2(WIDE * 0.5, 300)
		card.scale = Vector2.ONE * 0.9
		card.create_tween().tween_property(card, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		Motion.appear(self, 0.0, 1.0, 0.2)

## The parts.
func _list_card(col: VBoxContainer) -> void:
	col.add_child(Dialog.head("TL_PARTS", "puzzle"))
	var ids: Array = sim.defs.keys()
	ids.sort()
	if ids.is_empty():
		var none := Label.new()
		none.text = "TL_PARTS_NONE"
		none.theme_type_variation = "CardBlurb"
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		none.custom_minimum_size.x = WIDE - 120
		col.add_child(none)
	else:
		var scroll := ScrollContainer.new()
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.custom_minimum_size = Vector2(WIDE - 80, minf(LIST_MOST, ids.size() * (MINI + 40.0)))
		col.add_child(scroll)
		_touch = TouchScroll.attach(scroll)
		var list := VBoxContainer.new()
		list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		list.add_theme_constant_override("separation", 12)
		scroll.add_child(list)
		for id: int in ids:
			list.add_child(_row(id))
	var done := Dialog.secondary("check", tr("TL_DONE"))
	done.pressed.connect(_pick.bind("", -1))
	Dialog.buttons(col, done)

## One part's row: its block small, its name and size, Place, the bin.
func _row(id: int) -> Control:
	var d: Dictionary = sim.defs[id]
	var tile := PanelContainer.new()
	tile.add_theme_stylebox_override("panel", Dialog.tile(Pal.SURFACE, 14))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	tile.add_child(row)
	var mini := Control.new()
	mini.custom_minimum_size = Vector2(MINI, MINI)
	mini.draw.connect(_draw_mini.bind(mini, id))
	row.add_child(mini)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(words)
	var name_l := Label.new()
	name_l.text = Sim.part_title(d)
	name_l.theme_type_variation = "CardTitle"
	name_l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_l.custom_minimum_size.x = 120
	words.add_child(name_l)
	var n := (d.pieces as Array).size()
	var line := Label.new()
	line.text = tr("TL_PART_SIZE") % [int(d.w), int(d.h)] + "  ·  " + (tr("TL_PART_PIECES_ONE") if n == 1 else tr("TL_PART_PIECES_N") % n)
	line.theme_type_variation = "CardBlurb"
	words.add_child(line)
	var place := IconButton.new("play", tr("TL_PART_PLACE"), "PrimaryButton")
	place.custom_minimum_size = Vector2(0, ROW_H)
	place.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	place.pressed.connect(_pick.bind("place", id))
	row.add_child(place)
	var bin := IconButton.new("bin", "", "IconButton")
	bin.custom_minimum_size = Vector2(ROW_H, ROW_H)
	bin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bin.pressed.connect(_pick.bind("drop", id))
	row.add_child(bin)
	return tile

func _draw_mini(c: Control, id: int) -> void:
	var d: Dictionary = sim.defs[id]
	var w := int(d.w)
	var h := int(d.h)
	var s := MINI / (maxf(w, h) * Art.U + Art.U * 0.6)
	var off := (Vector2(MINI, MINI) - Vector2(w, h) * Art.U * s) * 0.5
	c.draw_mesh(Art.lid(w, h, []), null, Transform2D(0.0, Vector2.ONE * s, 0.0, off))

func _pick(what: String, id: int) -> void:
	if what != "" and _touch != null and _touch.dragged():
		return
	if what != "":
		chose.emit(what, id)
	closed.emit()
	queue_free()
