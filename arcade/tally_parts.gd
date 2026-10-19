extends Control

## Tally's parts, a card over the paper from the tray's Parts slot (the
## user, 2026-10-19: "create a submodule with operations inside it ... so I
## can just spawn it somewhere else"): a row a part, its lid small, its name,
## its size and how many copies stand on the paper, with Place (the hand
## takes copies of it), Edit (the bench opens on it) and a bin (the part and
## every copy go); under them the size of a new part, across and down, and
## New. The screen mounts it (`sim`) and does what `chose` asks.
##
## With `bench` set (the part on the bench, the user, 2026-10-19: "i should
## be able to rename it and change grid") it is that part's card instead: a
## field for its name and its grid's size, across and down, from `bench_size`;
## Done says them through `edited`.

signal closed
## "place", "edit" or "drop" with a part's id; "new" with its size.
signal chose(what: String, id: int, size: Vector2i)
## The bench's part named and sized.
signal edited(name: String, size: Vector2i)

const Sim = preload("res://arcade/tally_sim.gd")
const Art = preload("res://arcade/tally_art.gd")
const Dialog = preload("res://ui/hud/dialog.gd")
const IconButton = preload("res://ui/hud/icon_button.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const CozyTheme = preload("res://ui/theme.gd")

const WIDE := 900.0
const MINI := 96.0
const LIST_MOST := 620.0
const ROW_H := 84.0
## A new part's size as first offered.
const START := Vector2i(4, 4)
const NAME_MOST := 18
const FIELD_H := 96.0

static var _size := START

var sim: RefCounted
## The part on the bench, or -1, and its grid's size there.
var bench := -1
var bench_size := START
var _wide_l: Label
var _tall_l: Label
var _field: LineEdit
## The size the steppers hold.
var _sz := START

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
	if bench >= 0:
		_bench_card(col)
	else:
		_list_card(col)
	if not Motion.reduce:
		card.pivot_offset = Vector2(WIDE * 0.5, 300)
		card.scale = Vector2.ONE * 0.9
		card.create_tween().tween_property(card, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		Motion.appear(self, 0.0, 1.0, 0.2)

## The bench's part: its name and its grid's size.
func _bench_card(col: VBoxContainer) -> void:
	_sz = bench_size
	col.add_child(Dialog.head("TL_PART_EDIT", "pencil"))
	_field = LineEdit.new()
	_field.name = "Name"
	_field.custom_minimum_size.y = FIELD_H
	_field.max_length = NAME_MOST
	_field.text = Sim.part_title(sim.defs[bench])
	_field.select_all_on_focus = true
	_field.context_menu_enabled = false
	_field.add_theme_font_override("font", CozyTheme.display(700))
	_field.add_theme_font_size_override("font_size", 44)
	_field.add_theme_color_override("font_color", Pal.TEXT)
	_field.add_theme_color_override("caret_color", Pal.ACCENT_2)
	_field.add_theme_stylebox_override("normal", CozyTheme.card(Pal.SURFACE, 28, Pal.LINE, 3, 20))
	_field.add_theme_stylebox_override("focus", CozyTheme.card(Pal.SURFACE, 28, Pal.SUN, 4, 20))
	_field.text_submitted.connect(func(_t: String) -> void: _field.release_focus())
	# a touch is not a click here: only a click gives a LineEdit the keyboard
	_field.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventScreenTouch and ev.pressed:
			_field.edit())
	col.add_child(_field)
	var tile := PanelContainer.new()
	tile.add_theme_stylebox_override("panel", Dialog.tile(Pal.SURFACE, 14))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	tile.add_child(row)
	_wide_l = _stepper(row, "TL_PART_WIDE", 0)
	_tall_l = _stepper(row, "TL_PART_TALL", 1)
	col.add_child(tile)
	_show_size()
	var many: int = sim.copies_of(bench)
	if many > 0:
		var note := Label.new()
		note.text = tr("TL_PART_RESIZE_NOTE_ONE") if many == 1 else tr("TL_PART_RESIZE_NOTE_N") % many
		note.theme_type_variation = "CardBlurb"
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.custom_minimum_size.x = WIDE - 120
		col.add_child(note)
	var done := Dialog.primary("check", tr("TL_DONE"))
	done.pressed.connect(func() -> void:
		var nm := _field.text.strip_edges()
		edited.emit(nm, _sz)
		closed.emit()
		queue_free())
	Dialog.buttons(col, done)

## The parts, and New.
func _list_card(col: VBoxContainer) -> void:
	_sz = _size
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
		var list := VBoxContainer.new()
		list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		list.add_theme_constant_override("separation", 12)
		scroll.add_child(list)
		for id: int in ids:
			list.add_child(_row(id))
	col.add_child(_maker())
	var done := Dialog.secondary("check", tr("TL_DONE"))
	done.pressed.connect(_pick.bind("", -1))
	Dialog.buttons(col, done)

## One part's row: its lid small, its name and size, Place, Edit, the bin.
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
	var many: int = sim.copies_of(id)
	var line := Label.new()
	line.text = tr("TL_PART_SIZE") % [int(d.w), int(d.h)] + "  ·  " + (tr("TL_PART_COPIES_ONE") if many == 1 else tr("TL_PART_COPIES_N") % many)
	line.theme_type_variation = "CardBlurb"
	words.add_child(line)
	var place := IconButton.new("play", tr("TL_PART_PLACE"), "PrimaryButton")
	place.custom_minimum_size = Vector2(0, ROW_H)
	place.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	place.pressed.connect(_pick.bind("place", id))
	row.add_child(place)
	var edit := IconButton.new("pencil", "", "IconButton")
	edit.custom_minimum_size = Vector2(ROW_H, ROW_H)
	edit.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	edit.pressed.connect(_pick.bind("edit", id))
	row.add_child(edit)
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
	c.draw_mesh(Art.lid(w, h, sim.part_ports(id, 0)), null, Transform2D(0.0, Vector2.ONE * s, 0.0, off))

## The new part's size, across and down, and New.
func _maker() -> Control:
	var tile := PanelContainer.new()
	tile.add_theme_stylebox_override("panel", Dialog.tile(Pal.SURFACE, 14))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	tile.add_child(row)
	_wide_l = _stepper(row, "TL_PART_WIDE", 0)
	_tall_l = _stepper(row, "TL_PART_TALL", 1)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(gap)
	var make := IconButton.new("plus", tr("TL_PART_NEW"), "PrimaryButton")
	make.custom_minimum_size = Vector2(0, ROW_H)
	make.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	make.pressed.connect(func() -> void:
		chose.emit("new", -1, _sz)
		closed.emit()
		queue_free())
	row.add_child(make)
	_show_size()
	return tile

## A caption over a minus, the count and a plus; `axis` 0 across, 1 down.
func _stepper(row: HBoxContainer, key: String, axis: int) -> Label:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	row.add_child(box)
	var cap := Label.new()
	cap.text = key
	cap.theme_type_variation = "CardBlurb"
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(cap)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 6)
	box.add_child(line)
	var less := IconButton.new("minus", "", "IconButton")
	less.custom_minimum_size = Vector2(64, 64)
	less.pressed.connect(_step.bind(axis, -1))
	line.add_child(less)
	var n := Label.new()
	n.theme_type_variation = "CardTitle"
	n.custom_minimum_size.x = 48
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	line.add_child(n)
	var more := IconButton.new("plus", "", "IconButton")
	more.custom_minimum_size = Vector2(64, 64)
	more.pressed.connect(_step.bind(axis, 1))
	line.add_child(more)
	return n

func _step(axis: int, by: int) -> void:
	if axis == 0:
		_sz.x = clampi(_sz.x + by, Sim.PART_LEAST, Sim.PART_MOST)
	else:
		_sz.y = clampi(_sz.y + by, Sim.PART_LEAST, Sim.PART_MOST)
	if bench < 0:
		_size = _sz
	_show_size()

func _show_size() -> void:
	_wide_l.text = str(_sz.x)
	_tall_l.text = str(_sz.y)

func _pick(what: String, id: int) -> void:
	if what != "":
		chose.emit(what, id, Vector2i.ZERO)
	closed.emit()
	queue_free()
