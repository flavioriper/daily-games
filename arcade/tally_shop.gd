extends Control

## Tally's upgrades as a tree (spec docs/superpowers/specs/2026-10-15-tally-
## builder-and-tree-design.md, section 5), a card over the paper in the
## Grove's skill-tree manner: a head with a round X, a field of squared paper
## that pans up and down under a finger when the screen is short, the
## counting box at the root, a trunk of pencil up the middle and the six
## tracks as boughs in the order they open, alternating sides, and a card
## along the foot that names the chosen track, shows the next rank's asks as
## tokens with have over need, the rank after's as a dim line, and the one
## sun bar that buys.
##
## The rules and every figure are arcade/tally_sim.gd's (`asks`, `can_buy`,
## `buy`); this only draws and asks. The paper, the box and the boughs are
## one mesh in the tree's pixels (arcade/tally_tree_art.gd), rebuilt when a
## track opens; a plate is a small Control under the field holding one mesh
## a state and its two strings, so a bought rank can squash it. The screen
## mounts it (`sim`, `closed`, `bought`) and plays the sound and the sticker.

signal closed
signal bought(id: String)

const Sim = preload("res://arcade/tally_sim.gd")
const Art = preload("res://arcade/tally_art.gd")
const TreeArt = preload("res://arcade/tally_tree_art.gd")
const Dialog = preload("res://ui/hud/dialog.gd")
const IconButton = preload("res://ui/hud/icon_button.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const CozyTheme = preload("res://ui/theme.gd")
const UiSound = preload("res://ui/ui_sound.gd")
const Haptics = preload("res://core/haptics.gd")

const CARD_W := 1000.0
const CARD_INSET := 26
const X_SIZE := 84.0
## The air over and under the card, and what the field is clamped to: at
## most what the tree needs with the tallest cell, at least a cell and a half.
const AIR := 48.0
const FIELD_LEAST := 640.0
const FIELD_MOST := 1190.0
const FIELD_R := 30.0
## The tree's grid: a bough's reach from the trunk, the first row's clearance
## over the box, and a row's height, chosen so the tree fits the field where
## it can (a plate not open wears "Lv n" under it: under CELL_Y_LEAST that
## tag meets the plate over it).
const CELL_X := 250.0
const ROOT_GAP := 160.0
const CELL_Y_LEAST := 190.0
const CELL_Y_MOST := 210.0
## The air over the top plate and under the box.
const TOP_AIR := 24.0
const FOOT_AIR := 20.0
## A plate's Control: the plate, its ring and a little round it.
const SIDE := TreeArt.PLATE + 2.0 * (TreeArt.RING_GAP + TreeArt.RING_W + 6.0)
## A press that moves less than this is a tap; a finger let go while moving
## lets the field run on, its speed falling away at GLIDE_STOP a second.
const TAP := 12.0
const GLIDE_STOP := 4.5
const GLIDE_LEAST := 30.0
const WHEEL := 96.0
## The foot card and its asks row: a token's scale, a column's width, where
## the token, the count and the bar lie.
const FOOT_H := 440.0
const ASKS_H := 132.0
const TOKEN_K := 1.15
const COL := 190.0
const TOKEN_Y := 40.0
const COUNT_Y := 98.0
const BAR_Y := 116.0
const BAR_W := 118.0
const UNIT := {"belt": "TL_PER_S", "dig": "TL_BELTS", "add": "TL_PER_S", "mul": "TL_PER_S", "sub": "TL_PER_S", "pow": "TL_PER_S"}

const NONE := -1
const MOUSE := -2

var sim: RefCounted
var _card: PanelContainer
var _field: Control
var _foot: PanelContainer
var _name_l: Label
var _line_l: Label
var _asks: Control
var _then_l: Label
var _bar: Button
var _font: Font
var _plates := {}
var _back: ArrayMesh
var _back_for := ""
var _frame: ArrayMesh
var _frame_for := Vector2.ZERO
## The tree's measure for the field it has: a row's height, its top and its
## bottom in tree pixels (y up negative, the box's middle (0, 0)).
var _cell_y := CELL_Y_MOST
var _top := 0.0
var _bottom := 0.0
## How far the tree is pulled down to show its top, and the most it may be.
var _pan := 0.0
var _pan_most := 0.0
var _speed := 0.0
var _finger := NONE
var _down_at := Vector2.ZERO
var _down_pan := 0.0
var _moved := false
var _last_y := 0.0
var _last_ms := 0
var _chosen := ""
var _asks_on := false
var _asks_of: Array = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 8
	_font = CozyTheme.display(700)
	var scrim := Dialog.scrim()
	scrim.name = "Scrim"
	scrim.gui_input.connect(func(event: InputEvent) -> void:
		if (event is InputEventScreenTouch or event is InputEventMouseButton) and event.pressed:
			close())
	add_child(scrim)
	var center := CenterContainer.new()
	center.name = "Center"
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_card = Dialog.card(CARD_W, CARD_INSET)
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(_card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	_card.add_child(col)
	col.add_child(_build_head())
	var line := Label.new()
	line.name = "Line"
	line.text = "TL_TREE_LINE"
	line.theme_type_variation = "CardBlurb"
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.custom_minimum_size.x = CARD_W - CARD_INSET * 2.0
	col.add_child(line)
	_field = Control.new()
	_field.name = "Field"
	_field.clip_contents = true
	_field.mouse_filter = Control.MOUSE_FILTER_STOP
	_field.custom_minimum_size = Vector2(CARD_W - CARD_INSET * 2.0, FIELD_LEAST)
	_field.draw.connect(_draw_field)
	_field.gui_input.connect(_on_field_input)
	_field.resized.connect(_lay_out)
	col.add_child(_field)
	for id: String in Sim.TRACKS:
		var p := Plate.new(id, _font)
		_field.add_child(p)
		_plates[id] = p
	# the frame lies over the plates: the field's rounded corners and its shade
	var frame := Control.new()
	frame.name = "Frame"
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.draw.connect(func() -> void:
		var view := _field.size
		if _frame == null or _frame_for != view:
			_frame_for = view
			_frame = TreeArt.frame(view, FIELD_R)
		frame.draw_mesh(_frame, null))
	_field.add_child(frame)
	col.add_child(_build_foot())
	resized.connect(_fit)
	_fit()
	set_process(false)
	_chosen = _first()
	refresh()
	if not Motion.reduce:
		_card.pivot_offset = Vector2(CARD_W * 0.5, 600.0)
		_card.scale = Vector2.ONE * 0.92
		_card.create_tween().tween_property(_card, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		Motion.appear(self, 0.0, 1.0, 0.2)

## The head: the badge and the title, and a round X.
func _build_head() -> Control:
	var x := IconButton.new("cross", "", "IconButton")
	x.name = "Close"
	x.custom_minimum_size = Vector2(X_SIZE, X_SIZE)
	x.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var r := int(X_SIZE * 0.5)
	var up := CozyTheme.soft_button(Pal.SURFACE, r, false, 0)
	var down := CozyTheme.soft_button(Pal.SURFACE, r, true, 0)
	for st in ["normal", "hover", "disabled"]:
		x.add_theme_stylebox_override(st, up)
	x.add_theme_stylebox_override("pressed", down)
	x.pressed.connect(close)
	return Dialog.head("TL_UPGRADES", "trend", x)

## The card along the foot: the chosen track's name and line, the next rank's
## asks as tokens, the rank after in a dim line, and the sun bar.
func _build_foot() -> Control:
	_foot = PanelContainer.new()
	_foot.name = "Foot"
	_foot.custom_minimum_size.y = FOOT_H
	_foot.add_theme_stylebox_override("panel", CozyTheme.lifted(Pal.SURFACE, 30, 18))
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 6)
	_foot.add_child(col)
	_name_l = Label.new()
	_name_l.name = "Name"
	_name_l.theme_type_variation = "CardName"
	_name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_l.clip_text = true
	col.add_child(_name_l)
	_line_l = Label.new()
	_line_l.name = "Status"
	_line_l.theme_type_variation = "CardBlurb"
	_line_l.add_theme_font_size_override("font_size", 28)
	_line_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_line_l.clip_text = true
	col.add_child(_line_l)
	_asks = Control.new()
	_asks.name = "Asks"
	_asks.custom_minimum_size.y = ASKS_H
	_asks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_asks.draw.connect(_draw_asks)
	col.add_child(_asks)
	_then_l = Label.new()
	_then_l.name = "Then"
	_then_l.theme_type_variation = "CardBlurb"
	_then_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_then_l.clip_text = true
	_then_l.modulate.a = 0.7
	col.add_child(_then_l)
	var air := Control.new()
	air.custom_minimum_size.y = 8.0
	col.add_child(air)
	# the bar keeps its own size: no container stretches a button
	_bar = Dialog.primary("trend", tr("TL_BUY"))
	_bar.name = "Buy"
	_bar.custom_minimum_size = Vector2(Dialog.WIDE, 104.0)
	_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_bar.pivot_offset = Vector2(Dialog.WIDE * 0.5, 52.0)
	_bar.pressed.connect(func() -> void:
		_buy(_chosen))
	col.add_child(_bar)
	return _foot

## The field takes what the screen's height leaves it, between its bounds.
func _fit() -> void:
	if _field == null or _card == null:
		return
	var rest := _card.get_combined_minimum_size().y - _field.custom_minimum_size.y
	_field.custom_minimum_size.y = clampf(size.y - AIR * 2.0 - rest, FIELD_LEAST, FIELD_MOST)

# --- what the screen asks ---

## The first track that can be bought, else the belts.
func _first() -> String:
	if sim != null:
		for id: String in Sim.TRACKS:
			if sim.can_buy(id):
				return id
	return "belt"

func close() -> void:
	_let_go()
	closed.emit()
	queue_free()

## After a rank or the tally changed: every plate's state, the boughs if a
## track opened, and the foot card.
func refresh() -> void:
	if sim == null or _field == null:
		return
	var open := {}
	for id: String in Sim.TRACKS:
		open[id] = sim.track_open(id)
		_dress(id)
	var key := "%s|%d|%s" % [str(open), int(_cell_y), str(_field.size)]
	if key != _back_for or _back == null:
		_back_for = key
		_back = TreeArt.back(_field.size.x, Vector2(_top - _field.size.y, _bottom + _field.size.y), CELL_X, ROOT_GAP, _cell_y, open)
	_place()
	_refresh_foot()
	_field.queue_redraw()

## Chooses a track: the foot card says what it is.
func select(id: String) -> void:
	if id == "" or not _plates.has(id) or id == _chosen:
		return
	var was := _chosen
	_chosen = id
	_dress(was)
	_dress(id)
	_refresh_foot()

## Buys a rank of `id` (the bar's, and the harness's): the plate squashes,
## its ring refills and the foot moves on to the next rank.
func _buy(id: String) -> bool:
	if sim == null or not _plates.has(id):
		return false
	if not sim.buy(id):
		if id == _chosen:
			Motion.shiver(_bar, 6.0)
		return false
	select(id)
	Motion.squash(_plates[id], 0.12, 0.22)
	bought.emit(id)
	refresh()
	return true

# --- where things are ---

## Measures the tree for the field it has: the tallest cell that fits, else
## the least and a pan.
func _lay_out() -> void:
	var h := _field.size.y
	var fixed := TreeArt.ROOT_HALF + FOOT_AIR + ROOT_GAP + SIDE * 0.5 + TOP_AIR
	_cell_y = clampf((h - fixed) / 4.0, CELL_Y_LEAST, CELL_Y_MOST)
	_top = TreeArt.row_y(5, ROOT_GAP, _cell_y) - SIDE * 0.5 - TOP_AIR
	_bottom = TreeArt.ROOT_HALF + FOOT_AIR
	_pan_most = maxf(0.0, (_bottom - _top) - h)
	_pan = clampf(_pan, 0.0, _pan_most)
	if sim != null:
		refresh()

## Where the tree's (0, 0), the box's middle, is on the field.
func _origin() -> Vector2:
	return Vector2(_field.size.x * 0.5, _field.size.y - _bottom + _pan)

func _spot(id: String) -> Vector2:
	return TreeArt.spot(id, CELL_X, ROOT_GAP, _cell_y)

## Seats every plate under the pan.
func _place() -> void:
	var o := _origin()
	for id: String in _plates:
		var p: Control = _plates[id]
		p.position = o + _spot(id) - Vector2.ONE * SIDE * 0.5

## A plate's middle on the field, for the screen's effects and the harness.
func plate_center(id: String) -> Vector2:
	return _origin() + _spot(id)

## The plates' rects on the field, the tag under a shut one counted, for the
## harness's check that none meets another.
func plate_rects() -> Dictionary:
	var out := {}
	for id: String in _plates:
		var p: Control = _plates[id]
		var r := p.get_rect()
		if not sim.track_open(id):
			r.end = Vector2(r.end.x, p.position.y + SIDE * 0.5 + TreeArt.TAG_Y + TreeArt.TAG_FS * 0.5)
		out[id] = r
	return out

func _set_pan(to: float) -> void:
	_pan = clampf(to, 0.0, _pan_most)
	_place()
	_field.queue_redraw()

func _plate_at(at: Vector2) -> String:
	for id: String in _plates:
		var p: Control = _plates[id]
		if p.get_rect().grow(4.0).has_point(at):
			return id
	return ""

# --- the hand ---

## A finger is a ScreenTouch and a ScreenDrag (the project has mouse-from-
## touch off); the mouse does the same on a desktop, and its wheel pans.
func _on_field_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed and _finger == NONE:
			_press(t.index, t.position)
		elif not t.pressed and t.index == _finger:
			_release(t.position)
	elif event is InputEventScreenDrag:
		if (event as InputEventScreenDrag).index == _finger:
			_drag((event as InputEventScreenDrag).position)
	elif event is InputEventMouseButton:
		var m := event as InputEventMouseButton
		if m.button_index == MOUSE_BUTTON_LEFT:
			if m.pressed and _finger == NONE:
				_press(MOUSE, m.position)
			elif not m.pressed and _finger == MOUSE:
				_release(m.position)
		elif m.pressed and m.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			_speed = 0.0
			_set_pan(_pan + (WHEEL if m.button_index == MOUSE_BUTTON_WHEEL_UP else -WHEEL))
	elif event is InputEventMouseMotion and _finger == MOUSE:
		_drag((event as InputEventMouseMotion).position)

func _press(finger: int, at: Vector2) -> void:
	_finger = finger
	_speed = 0.0
	_down_at = at
	_down_pan = _pan
	_moved = false
	_last_y = at.y
	_last_ms = Time.get_ticks_msec()

## Under TAP it is still a tap; past it the tree goes with the finger, up
## and down only, when it is taller than the field.
func _drag(at: Vector2) -> void:
	if not _moved and at.distance_to(_down_at) < TAP:
		return
	_moved = true
	if _pan_most <= 0.0:
		return
	var now := Time.get_ticks_msec()
	var dt := maxf(0.001, (now - _last_ms) / 1000.0)
	_speed = lerpf(_speed, (at.y - _last_y) / dt, 0.5)
	_last_y = at.y
	_last_ms = now
	_set_pan(_down_pan + (at.y - _down_at.y))

func _release(at: Vector2) -> void:
	_finger = NONE
	if not _moved:
		_speed = 0.0
		var id := _plate_at(at)
		# a tap that moves the choice is heard and felt, as a button's is
		if id != "" and id != _chosen:
			UiSound.click(self)
			Haptics.play(Haptics.TICK)
		select(id)
	elif Motion.reduce or Time.get_ticks_msec() - _last_ms > 90 or absf(_speed) < GLIDE_LEAST * 4.0:
		_speed = 0.0
	else:
		set_process(true)

func _let_go() -> void:
	_finger = NONE
	_moved = false
	_speed = 0.0

func _process(delta: float) -> void:
	if _finger == NONE and _speed != 0.0:
		_set_pan(_pan + _speed * delta)
		_speed *= exp(-GLIDE_STOP * delta)
		if absf(_speed) < GLIDE_LEAST or _pan <= 0.0 or _pan >= _pan_most:
			_speed = 0.0
	if _speed == 0.0:
		set_process(false)

# --- the words ---

func _speed_text(id: String, l: int) -> String:
	var v := Sim.speed_for(id, l)
	var s := str(int(v)) if absf(v - roundf(v)) < 0.001 else String.num(v, 2).trim_suffix("0")
	return tr(UNIT[id]) % s

func _refresh_foot() -> void:
	if _foot == null or sim == null or _chosen == "":
		return
	var id := _chosen
	var open: bool = sim.track_open(id)
	var top: bool = sim.at_top(id)
	var l := int(sim.lv[id])
	_name_l.text = tr("TL_TRACK_" + id.to_upper())
	_asks_on = open and not top
	_asks_of = sim.asks(id) if _asks_on else []
	_bar.visible = _asks_on
	_then_l.visible = _asks_on
	if not open:
		_line_l.text = tr("TL_OPENS_AT") % (int(Sim.UNLOCK[int(Sim.TRACK_KIND[id])]) + 1)
	elif top:
		_line_l.text = tr("TL_AT_TOP") % [l, _speed_text(id, l)]
	else:
		_line_l.text = tr("TL_TRACK_LINE") % [l, _speed_text(id, l), _speed_text(id, l + 1)]
		if l + 1 >= int(Sim.TRACK_TOP[id]):
			_then_l.text = "%s  %s" % [tr("TL_THEN"), tr("TL_AT_TOP_SHORT")]
		else:
			var parts := PackedStringArray()
			for a: Array in sim.asks_at(id, l + 1):
				parts.append("%s ×%s" % [Sim.short(int(a[0])), Sim.short(int(a[1]))])
			_then_l.text = "%s  %s" % [tr("TL_THEN"), "  ·  ".join(parts)]
		var short_of := ""
		for a: Array in _asks_of:
			var have: int = sim.held(int(a[0]))
			if have < int(a[1]):
				short_of = tr("TL_SHORT_OF") % [Sim.short(int(a[1]) - have), Sim.short(int(a[0]))]
				break
		var can := short_of == ""
		(_bar as IconButton).set_label(tr("TL_BUY") if can else short_of)
		(_bar as IconButton).set_enabled(can)
	_asks.queue_redraw()

## The next rank's asks: a token a number, "have / need" under it (green once
## met) and a thin bar filled to have over need.
func _draw_asks() -> void:
	if not _asks_on or _asks_of.is_empty():
		return
	var n := _asks_of.size()
	var x0 := _asks.size.x * 0.5 - (n - 1) * COL * 0.5
	for i in n:
		var a: Array = _asks_of[i]
		var v := int(a[0])
		var need := int(a[1])
		var have: int = sim.held(v)
		var met := have >= need
		var cx := x0 + i * COL
		var at := Vector2(cx, TOKEN_Y)
		_asks.draw_mesh(Art.token(false), null, Transform2D(0.0, Vector2.ONE * TOKEN_K, 0.0, at))
		var txt := Sim.short(v)
		var fs := 32 if txt.length() <= 2 else (26 if txt.length() == 3 else 21)
		var w := _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		_asks.draw_string(_font, at + Vector2(-w * 0.5, fs * 0.36 - 2.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Art.INK)
		var count := "%s / %s" % [Sim.short(mini(have, need)), Sim.short(need)]
		var cw := _font.get_string_size(count, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		_asks.draw_string(_font, Vector2(cx - cw * 0.5, COUNT_Y), count, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, TreeArt.MET if met else Pal.TEXT_DIM)
		var bar := Rect2(cx - BAR_W * 0.5, BAR_Y, BAR_W, 6.0)
		_asks.draw_rect(bar, TreeArt.UNMET)
		var fill := clampf(float(have) / float(maxi(1, need)), 0.0, 1.0)
		if fill > 0.0:
			_asks.draw_rect(Rect2(bar.position, Vector2(BAR_W * fill, 6.0)), TreeArt.MET if met else Pal.SUN)

# --- the drawing ---

## A plate's mesh and strings for its track's state.
func _dress(id: String) -> void:
	if id == "" or not _plates.has(id):
		return
	var p: Plate = _plates[id]
	var kind := int(Sim.TRACK_KIND[id])
	var open: bool = sim.track_open(id)
	var top: bool = sim.at_top(id)
	var can: bool = sim.can_buy(id)
	var l := int(sim.lv[id])
	var met := []
	var asks: Array = sim.asks(id) if open and not top else []
	for a: Array in asks:
		met.append(sim.held(int(a[0])) >= int(a[1]))
	p.chip = tr("TL_LEVEL_SHORT") % l if open else ""
	p.chip_w = _font.get_string_size(p.chip, HORIZONTAL_ALIGNMENT_LEFT, -1, TreeArt.CHIP_FS).x + 22.0 if open else 0.0
	p.tag = "" if open else tr("TL_LEVEL_SHORT") % (int(Sim.UNLOCK[kind]) + 1)
	p.mesh = TreeArt.plate(kind, open, top, can, asks.size(), met, p.chip_w, id == _chosen)
	p.queue_redraw()

func _draw_field() -> void:
	if sim == null or _back == null:
		return
	_field.draw_mesh(_back, null, Transform2D(0.0, _origin()))

## One track's plate: its mesh about its middle, the rank on its chip, the
## level it opens at under it while shut. The frame over the field is the
## field's own, drawn after the plates by `Frame`.
class Plate extends Control:
	var id := ""
	var mesh: ArrayMesh
	var chip := ""
	var chip_w := 0.0
	var tag := ""
	var _font: Font

	func _init(id_: String, font: Font) -> void:
		id = id_
		_font = font
		name = id_
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = Vector2.ONE * SIDE
		pivot_offset = size * 0.5

	func _draw() -> void:
		var c := size * 0.5
		if mesh != null:
			draw_mesh(mesh, null, Transform2D(0.0, c))
		if chip != "":
			var w := _font.get_string_size(chip, HORIZONTAL_ALIGNMENT_LEFT, -1, TreeArt.CHIP_FS).x
			draw_string(_font, c + TreeArt.CORNER + Vector2(-chip_w * 0.5 + (chip_w - w) * 0.5, TreeArt.CHIP_FS * 0.36), chip, HORIZONTAL_ALIGNMENT_LEFT, -1, TreeArt.CHIP_FS, Art.INK)
		if tag != "":
			var w := _font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, TreeArt.TAG_FS).x
			draw_string(_font, c + Vector2(-w * 0.5, TreeArt.TAG_Y + TreeArt.TAG_FS * 0.36), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, TreeArt.TAG_FS, Art.PENCIL)
