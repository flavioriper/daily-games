extends Control

## The Grove's skills, on a card over the land and drawn as a tree (spec
## docs/superpowers/specs/2026-10-07-grove-tree-and-jetty-design.md, section
## 3): the trunk runs up the middle, a node a kind of tree; two boughs leave
## each kind, Soft to its left and Rich to its right; four roots go down
## under a line of soil. Only what the sim says is shown (`Sim.shown`): every
## node with a level and every open one, nothing past them.
##
## The tree stands on a field that pans up and down under a finger. A tap
## chooses a node, and the card along the foot says its name, what it is now
## and what the next level makes it, its level, and its price on the sun
## bar, which is the one Button here and the one that buys.
##
## The rules, the prices and every figure are valley/grove_sim.gd's; this
## only draws and asks. The field is one Control: the paper and the earth
## are one mesh, the trunk, boughs and roots another (rebuilt when a node
## opens or gets its first or second level), each node one mesh for its
## plate and picture, kept by picture and state, and one string for its
## figure.
## Built once by the screen (valley/grove_screen.gd) and shown, like the shop.

signal bought(id: String, paid: int)
signal refused(id: String)

const Sim = preload("res://valley/grove_sim.gd")
const Art = preload("res://valley/grove_art.gd")
const Face = preload("res://ui/faces/face.gd")
const Dialog = preload("res://ui/hud/dialog.gd")
const Icons = preload("res://ui/icons.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Motes = preload("res://ui/motes.gd")

## The card is the shop's: as wide, as thinly lined, the same head.
const CARD_W := 1000.0
const CARD_INSET := 26
## The field is this tall where the screen lets it be, and never under
## FIELD_LEAST; REST is what the card's head and foot and the air over and
## under the card take.
const FIELD_MOST := 1000.0
const FIELD_LEAST := 620.0
const REST := 560.0
const FIELD_R := 30.0
## A cell of the tree's grid and a node's plate in it. Four root columns are
## 3 cells and a plate across: 836 of the field's 948.
const CELL := Vector2(236.0, 216.0)
const PLATE := 128.0
const PLATE_R := 30.0
## The soil lies half a cell under the Sapling; the deepest root is five down.
const SOIL := 108.0
const DEEPEST := 5
## How much of a plate a picture may take, and how far a small one is grown.
const PIC := 88.0
const PIC_GROW := 1.1
## The level's chip on a plate's corner, and the price's tag under a plate
## that has no level yet.
const CHIP := Vector2(54.0, 38.0)
const TAG_H := 44.0
const TAG_ORB := 30.0
const NUM_SIZE := 26
const PRICE_SIZE := 28
## A press that moves less than this is a tap: a finger's own slop, about
## 1.5 mm on a phone. At 12 a tap that drifted chose nothing and panned.
const TAP := 24.0
## A finger let go while moving lets the field run on, at GLIDE_MOST pixels
## a second at the most: its speed falls away at GLIDE_STOP a second, and
## under GLIDE_LEAST it stands.
const GLIDE_STOP := 4.5
const GLIDE_LEAST := 30.0
const GLIDE_MOST := 5000.0
const WHEEL := 96.0
## The foot card: a picture on a disc, the words, and the bar that buys.
const FOOT_H := 244.0
const DISC_R := 52.0
const BAR := Vector2(520.0, 84.0)
const BAR_R := 24

const FILL := Color("fcf7ef")
const RIM := Color("e4d7c0")
const LEAF_RIM := Color("b7d49c")
const SHADOW := Color(0.33, 0.21, 0.1, 0.2)
const HILL := Color("e3eed6")
const HILL_FAR := Color("edf3e2")
## The trunk and its boughs, lit and in shade, and what is not grown yet: a
## link to a node with no level is pale. Roots are a shade deeper, to read
## on the earth.
const TRUNK := Color("a5714a")
const TRUNK_SHADE := Color("865a39")
const BARE := Color("d9c3a3")
const ROOT := Color("7a5236")
const ROOT_BARE := Color("ecd9b6")
## A kind the land no longer grows: how much of its nodes' pictures is left
## on the paper they lie on (`_faded`).
const GONE := 0.45
## The nodes that are nothing before their first level, so their line says
## only what that level brings (`GROVE_FX_<ID>_FIRST`).
const FIRSTS := ["crate", "crit", "luck", "beaver"]

## What a node's two figures are, by id (a bough by its part): how
## `_figure` writes them. `sim.value` answers in these units: a count, the
## seconds, a percent (25.0 is 25%), chops a keen one counts for, a yield. A
## Soft bough's is its kind's points of chop, which no line says: `_effect`
## makes them the whole chops they are with the axe as it is, a count.
const FX := {
	"room": "count", "sprout": "secs",
	"jetty": "count", "tying": "secs", "bundle": "count", "raft": "secs", "load": "count",
	"beaver": "count", "teeth": "percent",
	"crit": "percent", "critsize": "chops", "luck": "percent", "crate": "secs", "cratesize": "count",
	"soft": "count", "rich": "count",
}

const NONE := -1
const MOUSE := -2

static var _plates := {}
static var _fades := {}
static var _ring: ArrayMesh

var sim: RefCounted
var _tree_name: Callable
var _field: Control
var _energy_l: Label
var _foot: PanelContainer
var _help: Label
var _row: Control
var _pic: Control
var _name_l: Label
var _fx_l: Label
var _chip: Control
var _level_l: Label
var _bar: Button
## The bar's running bump or shiver, and where it lay across when that began.
var _bar_tw: Tween
var _bar_x := 0.0
var _cost_l: Label
var _mote: Control
var _tick: Control
var _num: Font
## The nodes laid out: {id, at, mesh, text, text_at, size, colour}, `at` in
## the tree's own pixels (the Sapling's middle is (0, 0), y down).
var _nodes: Array[Dictionary] = []
var _seen := {}
var _back: ArrayMesh
var _back_for := Vector3.ZERO
var _links: ArrayMesh
var _links_for := ""
var _frame: ArrayMesh
var _frame_for := Vector2.ZERO
## The tree's y under the field's middle, and the least and most it may be.
var _pan := 0.0
var _pan_least := 0.0
var _pan_most := 0.0
var _goal := NAN
var _speed := 0.0
var _finger := NONE
var _down_at := Vector2.ZERO
var _down_pan := 0.0
var _moved := false
## The press stopped a tree that was running on: its release chooses nothing.
var _caught := false
var _last_y := 0.0
var _last_ms := 0
var _chosen := ""
var _last := ""
var _fresh := false
## Seconds into a bought node's bump and a new node's pop, and the nodes the
## last refresh found new.
var _bumps := {}
var _born := {}
var _new: Array[String] = []

## `tree_name(tier)` is the screen's: "Birch", "Birch II".
func setup(grove: RefCounted, tree_name: Callable) -> void:
	sim = grove
	_tree_name = tree_name

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_num = CozyTheme.display(700)
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
	var card := Dialog.card(CARD_W, CARD_INSET)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 20)
	card.add_child(col)
	# the shop's head: the badge and the title, the energy held, a round X
	var head := Dialog.energy_head("GROVE_SKILLS", "tree", close)
	_energy_l = head.energy
	_energy_l.text = "0"
	col.add_child(head.head)
	_field = Control.new()
	_field.name = "Field"
	_field.clip_contents = true
	_field.mouse_filter = Control.MOUSE_FILTER_STOP
	_field.custom_minimum_size = Vector2(CARD_W - CARD_INSET * 2.0, FIELD_MOST)
	_field.draw.connect(_draw_field)
	_field.gui_input.connect(_on_field_input)
	_field.resized.connect(_on_field_resized)
	col.add_child(_field)
	col.add_child(_build_foot())
	resized.connect(_fit)
	_fit()
	set_process(false)

## The card along the foot: with nothing chosen, one line of help; with a
## node, its picture, its name over what the next level does, its level on a
## chip, and its price on the bar.
func _build_foot() -> Control:
	_foot = PanelContainer.new()
	_foot.name = "Foot"
	_foot.custom_minimum_size.y = FOOT_H
	_foot.add_theme_stylebox_override("panel", CozyTheme.lifted(FILL, 30, 18))
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 14)
	_foot.add_child(col)
	_help = Label.new()
	_help.name = "Help"
	_help.text = "GROVE_SKILLS_HELP"
	_help.theme_type_variation = "CardBlurb"
	_help.add_theme_font_size_override("font_size", 32)
	_help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_help.clip_text = true
	col.add_child(_help)
	_row = HBoxContainer.new()
	_row.visible = false
	_row.add_theme_constant_override("separation", 18)
	col.add_child(_row)
	_pic = Control.new()
	_pic.custom_minimum_size = Vector2(DISC_R * 2.0, DISC_R * 2.0)
	_pic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pic.draw.connect(_draw_pic)
	_row.add_child(_pic)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_theme_constant_override("separation", -2)
	_row.add_child(words)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	words.add_child(top)
	_name_l = Label.new()
	_name_l.name = "Name"
	_name_l.theme_type_variation = "CardTitle"
	_name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_l.clip_text = true
	top.add_child(_name_l)
	_chip = PanelContainer.new()
	_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var teal := StyleBoxFlat.new()
	teal.bg_color = Pal.ACCENT
	teal.set_corner_radius_all(20)
	teal.content_margin_left = 18.0
	teal.content_margin_right = 18.0
	teal.content_margin_top = 1.0
	teal.content_margin_bottom = 3.0
	_chip.add_theme_stylebox_override("panel", teal)
	_level_l = Label.new()
	_level_l.name = "Level"
	_level_l.theme_type_variation = "Badge"
	_level_l.add_theme_font_size_override("font_size", 30)
	_chip.add_child(_level_l)
	top.add_child(_chip)
	_fx_l = Label.new()
	_fx_l.name = "Effect"
	_fx_l.theme_type_variation = "CardBlurb"
	_fx_l.add_theme_font_size_override("font_size", 30)
	_fx_l.clip_text = true
	words.add_child(_fx_l)
	# the bar keeps its own size: no container stretches a button
	_bar = Button.new()
	_bar.name = "Buy"
	_bar.focus_mode = Control.FOCUS_NONE
	_bar.custom_minimum_size = BAR
	_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_bar.pivot_offset = BAR * 0.5
	_bar.visible = false
	_bar.pressed.connect(buy_selected)
	col.add_child(_bar)
	var price := HBoxContainer.new()
	price.alignment = BoxContainer.ALIGNMENT_CENTER
	price.add_theme_constant_override("separation", 10)
	price.mouse_filter = Control.MOUSE_FILTER_IGNORE
	price.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bar.add_child(price)
	_mote = Motes.icon(46.0)
	price.add_child(_mote)
	_tick = Control.new()
	_tick.custom_minimum_size = Vector2(38, 38)
	_tick.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tick.draw.connect(func() -> void:
		Icons.paint(_tick, "check", Rect2(Vector2.ZERO, _tick.size), Pal.LEAF_DEEP))
	price.add_child(_tick)
	_cost_l = Label.new()
	_cost_l.name = "Cost"
	_cost_l.theme_type_variation = "CardTitle"
	_cost_l.add_theme_font_size_override("font_size", 44)
	price.add_child(_cost_l)
	return _foot

## The field takes what the screen's height leaves it.
func _fit() -> void:
	if _field != null:
		_field.custom_minimum_size.y = clampf(size.y - REST, FIELD_LEAST, FIELD_MOST)

# --- what the screen asks ---

func open() -> void:
	if visible or sim == null:
		return
	_let_go()
	visible = true
	_fresh = true
	refresh()
	_seat()
	Motion.appear(self, 0.0, 1.0, 0.2)

func close() -> void:
	_let_go()
	visible = false

func is_open() -> bool:
	return visible

## The energy held, as the screen's own plate counts it (what has landed).
func held(text: String) -> void:
	if _energy_l != null and _energy_l.text != text:
		_energy_l.text = text

## After the energy or a level changed: every node's state, the links if a
## node opened, and the foot card.
func refresh() -> void:
	if sim == null or _field == null:
		return
	var ids: Array[String] = sim.shown()
	var key := ""
	var nodes: Array[Dictionary] = []
	var seen := {}
	_new.clear()
	for id in ids:
		var level: int = sim.level(id)
		# a bough is in leaf by its level, one pair then two
		key += "%s%d " % [id, mini(level, 2)]
		seen[id] = true
		if visible and not _seen.is_empty() and not _seen.has(id):
			_new.append(id)
			if not Motion.reduce:
				_born[id] = 0.0
		nodes.append(_lay(id, level))
	_nodes = nodes
	_seen = seen
	if key != _links_for:
		_links_for = key
		_links = _links_mesh(seen)
		var deep := 1
		for root: String in Sim.ROOT_ORDER:
			for k in (Sim.ROOTS[root] as Array).size():
				if seen.has(Sim.ROOTS[root][k]):
					deep = maxi(deep, k + 1)
		_pan_least = -CELL.y * (int(sim.lv.seeds) + 1)
		_pan_most = CELL.y * deep
	var want := Vector3(_field.size.x, _field.size.y, float(sim.lv.seeds))
	if _back == null or want != _back_for:
		_back_for = want
		_back = _back_mesh(_field.size, int(sim.lv.seeds))
	if not is_nan(_goal):
		_goal = clampf(_goal, _pan_least, _pan_most)
	_set_pan(_pan)
	_refresh_foot()
	_field.queue_redraw()
	if not _born.is_empty():
		set_process(true)

## Chooses a node ("" for none): the foot card says what it is.
func select(id: String) -> void:
	if _seen.is_empty():
		refresh()
	_chosen = id if _seen.has(id) else ""
	_refresh_foot()
	_field.queue_redraw()

## The bar: buys the chosen node's next level, or shakes its head. On a node
## of a kind gone from the land it has no price and does nothing.
func buy_selected() -> void:
	if sim == null or _chosen == "" or _gone(_chosen):
		return
	var id := _chosen
	var paid: int = sim.cost(id)
	if sim.buy(id):
		_last = id
		if not Motion.reduce:
			_bumps[id] = 0.0
			set_process(true)
		refresh()
		_settle_bar()
		_bar_tw = Motion.bump(_bar, 0.05, 0.2)
		# what it opened may lie past the field's edge: the tree comes to it
		for other in _new:
			if not _in_view(other):
				pan_to(id)
				break
		bought.emit(id, paid)
	elif not sim.is_done(id):
		_settle_bar()
		_bar_tw = Motion.shiver(_bar, 6.0)
		refused.emit(id)

## The bar back as it lies, before it is bumped or shaken again: both start
## from where they find it, so a second press inside the first's fifth of a
## second would leave it where it was caught (the screen's `_kick`).
func _settle_bar() -> void:
	if Motion.running(_bar_tw):
		_bar_tw.kill()
		_bar.scale = Vector2.ONE
		_bar.position.x = _bar_x
	_bar_x = _bar.position.x

## Brings a node to the middle of the field, as near as the tree's ends let.
func pan_to(id: String) -> void:
	for n: Dictionary in _nodes:
		if n.id == id:
			_speed = 0.0
			var to := clampf((n.at as Vector2).y, _pan_least, _pan_most)
			if Motion.reduce or not visible:
				_goal = NAN
				_set_pan(to)
			else:
				_goal = to
				set_process(true)
			return

# --- where things are ---

## A node's place on the tree's grid, x across and y up: the trunk is column
## 0, the boughs either side of it, the roots four columns under the soil.
static func cell(id: String) -> Vector2:
	var tier := Sim.tier_of(id)
	match Sim.part_of(id):
		"kind":
			return Vector2(0.0, tier)
		"soft":
			return Vector2(-1.0, tier)
		"rich":
			return Vector2(1.0, tier)
	for i in Sim.ROOT_ORDER.size():
		var at: int = (Sim.ROOTS[Sim.ROOT_ORDER[i]] as Array).find(id)
		if at >= 0:
			return Vector2(i - (Sim.ROOT_ORDER.size() - 1) * 0.5, -(at + 1.0))
	return Vector2.ZERO

static func spot(id: String) -> Vector2:
	var c := cell(id)
	return Vector2(c.x * CELL.x, -c.y * CELL.y)

## Where the tree's (0, 0) is on the field.
func _origin() -> Vector2:
	return Vector2(_field.size.x * 0.5, _field.size.y * 0.5 - _pan)

func _set_pan(to: float) -> void:
	_pan = clampf(to, _pan_least, _pan_most)
	if _field != null:
		_field.queue_redraw()

## The pan that opens the card: the soil a third up the field, or the last
## node bought where that leaves it out of sight.
func _seat() -> void:
	_goal = NAN
	_speed = 0.0
	_set_pan(SOIL - _field.size.y / 6.0)
	if _last != "" and _seen.has(_last) and not _in_view(_last):
		_set_pan(spot(_last).y)

func _in_view(id: String) -> bool:
	var y := _origin().y + spot(id).y
	var pan := _pan if is_nan(_goal) else _goal
	y += _pan - pan
	return y > PLATE * 0.6 and y < _field.size.y - PLATE * 0.8

func _on_field_resized() -> void:
	if not visible or sim == null:
		return
	refresh()
	if _fresh:
		_seat()

func _node_at(at: Vector2) -> String:
	var o := _origin()
	var half := PLATE * 0.5 + 12.0
	for n: Dictionary in _nodes:
		var c: Vector2 = o + n.at
		if Rect2(c.x - half, c.y - half, half * 2.0, half * 2.0 + TAG_H * 0.5).has_point(at):
			return n.id
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
			# a touch the system took away is let go and chooses nothing
			_release(t.position, not t.canceled)
	elif event is InputEventScreenDrag:
		if (event as InputEventScreenDrag).index == _finger:
			_drag((event as InputEventScreenDrag).position)
	elif event is InputEventMouseButton:
		var m := event as InputEventMouseButton
		if m.button_index == MOUSE_BUTTON_LEFT:
			if m.pressed and _finger == NONE:
				_press(MOUSE, m.position)
			elif not m.pressed and _finger == MOUSE:
				_release(m.position, true)
		elif m.pressed and m.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			_goal = NAN
			_speed = 0.0
			_set_pan(_pan + (-WHEEL if m.button_index == MOUSE_BUTTON_WHEEL_UP else WHEEL))
	elif event is InputEventMouseMotion and _finger == MOUSE:
		_drag((event as InputEventMouseMotion).position)

func _press(finger: int, at: Vector2) -> void:
	_finger = finger
	_fresh = false
	# a finger put down on a running tree stops it, and that is all it does
	_caught = _speed != 0.0
	_goal = NAN
	_speed = 0.0
	_down_at = at
	_down_pan = _pan
	_moved = false
	_last_y = at.y
	_last_ms = Time.get_ticks_msec()

## Under TAP it is still a tap; past it the tree goes with the finger, up
## and down only.
func _drag(at: Vector2) -> void:
	if not _moved and at.distance_to(_down_at) < TAP:
		return
	_moved = true
	var now := Time.get_ticks_msec()
	var dt := maxf(0.001, (now - _last_ms) / 1000.0)
	_speed = clampf(lerpf(_speed, -(at.y - _last_y) / dt, 0.5), -GLIDE_MOST, GLIDE_MOST)
	_last_y = at.y
	_last_ms = now
	_set_pan(_down_pan - (at.y - _down_at.y))

## `meant` is false for a touch that was canceled: the finger is let go,
## nothing is chosen and nothing runs on.
func _release(at: Vector2, meant: bool) -> void:
	_finger = NONE
	if not _moved:
		_speed = 0.0
		if meant and not _caught:
			select(_node_at(at))
	elif not meant or Motion.reduce or Time.get_ticks_msec() - _last_ms > 90 or absf(_speed) < GLIDE_LEAST * 4.0:
		_speed = 0.0
	else:
		set_process(true)

func _let_go() -> void:
	_finger = NONE
	_moved = false
	_caught = false
	_speed = 0.0
	_goal = NAN

func _process(delta: float) -> void:
	var busy := false
	if not is_nan(_goal):
		_set_pan(lerpf(_pan, _goal, minf(1.0, delta * 12.0)))
		if absf(_pan - _goal) < 0.6:
			_set_pan(_goal)
			_goal = NAN
		else:
			busy = true
	elif _finger == NONE and _speed != 0.0:
		_set_pan(_pan + _speed * delta)
		_speed *= exp(-GLIDE_STOP * delta)
		if absf(_speed) < GLIDE_LEAST or _pan <= _pan_least or _pan >= _pan_most:
			_speed = 0.0
		else:
			busy = true
	for clocks: Dictionary in [_bumps, _born]:
		for id: String in clocks.keys():
			clocks[id] = float(clocks[id]) + delta
			if float(clocks[id]) >= 0.3:
				clocks.erase(id)
		if not clocks.is_empty():
			busy = true
	_field.queue_redraw()
	if not busy:
		set_process(false)

# --- the words ---

func _name_of(id: String) -> String:
	var tier := Sim.tier_of(id)
	match Sim.part_of(id):
		"kind":
			return _tree_name.call(tier)
		"soft":
			return tr("GROVE_SOFT") % _tree_name.call(tier)
		"rich":
			return tr("GROVE_RICH") % _tree_name.call(tier)
	return tr("GROVE_" + id.to_upper())

## Whether a node is of a kind the land no longer grows (the best opened and
## the two under it come up): the kind's own node and its two boughs. They
## keep their levels, are drawn faded, and nothing more is bought on them.
func _gone(id: String) -> bool:
	return Sim.part_of(id) in ["kind", "soft", "rich"] and not sim.grows(Sim.tier_of(id))

## What the chosen node's next level does, in its own words.
func _effect(id: String) -> String:
	if _gone(id):
		return tr("GROVE_GONE") % _tree_name.call(Sim.tier_of(id))
	if Sim.part_of(id) == "kind":
		return tr("GROVE_FX_SEEDS") % _tree_name.call(Sim.tier_of(id))
	if sim.is_done(id):
		return tr("GROVE_DONE")
	var level: int = sim.level(id)
	var now: float = sim.value(id, level)
	var then: float = sim.value(id, level + 1)
	if Sim.part_of(id) == "soft":
		now = _chops(now)
		then = _chops(then)
	return line(id, now, then)

## The whole chops a tree of `points` takes with the axe as it is now, as
## the tutorial's first page counts a sapling's (valley/grove_screen.gd,
## `_chops_line`). With a strong axe a bough's two figures can be the same
## one: that is the truth about the bough then.
func _chops(points: float) -> float:
	return float(maxi(1, ceili(points / sim.power() - 0.0001)))

## A node's line from its two figures, what it is and what the next level
## makes it: "room for 6 piles, then 8". Every node has its own key
## (`GROVE_FX_<ID>`, a bough's by its part) taking the two as text; `FX`
## says how each is written. A node that is nothing before its first level
## (FIRSTS: Crates, Keen edge, Lucky wood, Beavers) says only what that level
## brings, with its figure where the words have a place for one: "a keen chop
## 5% of the time", not "0% of the time, then 5%".
static func line(id: String, now: float, then: float) -> String:
	var part := Sim.part_of(id)
	var key := "GROVE_FX_" + part.to_upper()
	if part in FIRSTS and now <= 0.0:
		var first := String(TranslationServer.translate(key + "_FIRST"))
		return first % _figure(part, then) if first.contains("%s") else first
	return String(TranslationServer.translate(key)) % [_figure(part, now), _figure(part, then)]

static func _figure(part: String, v: float) -> String:
	match String(FX.get(part, "count")):
		"secs":
			return str(roundi(v)) if v >= 99.95 else Art.decimal("%.1f" % v)
		"percent":
			return "%d%%" % roundi(v)
		"chops":
			return Art.amount(v, Art.comma())
	return Art.short(roundi(v))

func _refresh_foot() -> void:
	if _foot == null:
		return
	var on := _chosen != "" and _seen.has(_chosen)
	_help.visible = not on
	_row.visible = on
	_bar.visible = on
	if not on:
		return
	var id := _chosen
	var gone := _gone(id)
	var done: bool = sim.is_done(id)
	var can: bool = sim.can_buy(id)
	var level: int = sim.level(id)
	var last: int = sim.last_level(id)
	_name_l.text = _name_of(id)
	_fx_l.text = _effect(id)
	_level_l.text = "%d / %d" % [level, last] if last > 0 else str(level)
	# a kind gone from the land: the bar is there, as on every node, with no
	# price on it and nothing to press for
	_cost_l.text = "" if gone else (tr("GROVE_MAX") if done else Art.short(sim.cost(id)))
	_mote.visible = not done and not gone
	_tick.visible = done and not gone
	# the shop's bar and its three looks: the sun button's own when the
	# energy reaches, paper when it does not, a leaf when nothing is left
	var up: StyleBoxFlat
	var down: StyleBoxFlat
	if can:
		up = CozyTheme.soft_button(Pal.SUN, BAR_R, false, 0)
		down = CozyTheme.soft_button(Pal.SUN, BAR_R, true, 0)
	else:
		up = StyleBoxFlat.new()
		up.bg_color = Pal.LEAF_TILE if done and not gone else Art.PRICE_OFF
		up.set_corner_radius_all(BAR_R)
		down = up
	for st in ["normal", "hover", "disabled", "focus"]:
		_bar.add_theme_stylebox_override(st, up)
	_bar.add_theme_stylebox_override("pressed", down)
	_cost_l.add_theme_color_override("font_color", Pal.LEAF_DEEP if done else (Pal.TEXT if can else Pal.TEXT_DIM))
	_pic.queue_redraw()

## The chosen node's picture on a disc, as a tile of the shop wears its own.
func _draw_pic() -> void:
	if _chosen == "" or sim == null:
		return
	var c := _pic.size * 0.5
	var gone := _gone(_chosen)
	_pic.draw_circle(c, DISC_R, Pal.LEAF_TILE if sim.is_done(_chosen) and not gone else Pal.PARCHMENT, true, -1.0, true)
	var mesh := _picture(_chosen)
	var box := mesh.get_aabb()
	var fit := minf(1.0, DISC_R * 2.0 * 0.76 / maxf(1.0, maxf(box.size.x, box.size.y)))
	var mid := Vector2(box.get_center().x, box.get_center().y)
	_pic.draw_mesh(_faded(mesh, Pal.PARCHMENT) if gone else mesh, null, Transform2D(0.0, Vector2(fit, fit), 0.0, c - mid * fit))

# --- the drawing ---

static func _picture(id: String) -> ArrayMesh:
	match Sim.part_of(id):
		"kind":
			return Art.tree(Sim.look_of(Sim.tier_of(id)))
		"soft":
			return Art.icon("soft")
		"rich":
			return Art.icon("rich")
	return Art.icon(id)

## One node, laid out: where it is, the mesh its state asks for, and its
## figure: the level on its chip, or its price on the tag under it while it
## has no level. A node with nothing left wears a tick and says nothing. One
## of a kind gone from the land is faded: its level if it has one, in dim
## figures, and no price, since nothing more is bought on it.
func _lay(id: String, level: int) -> Dictionary:
	var done: bool = sim.is_done(id)
	var can: bool = sim.can_buy(id)
	var gone := _gone(id)
	var text := ""
	var text_at := Vector2.ZERO
	var fs := NUM_SIZE
	var colour := Pal.SURFACE
	var wide := 0
	if done:
		pass
	elif level > 0:
		text = str(level)
		text_at = _chip_at() + Vector2(-_num.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x * 0.5, _mid(fs))
		if gone:
			colour = Pal.TEXT_DIM
	elif gone:
		pass
	else:
		text = Art.short(sim.cost(id))
		fs = PRICE_SIZE
		colour = Pal.TEXT if can else Pal.TEXT_DIM
		# the tag is as wide as its figure, to the next six pixels
		wide = ceili(_num.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x / 6.0) * 6
		text_at = Vector2(-_tag_w(wide) * 0.5 + 12.0 + TAG_ORB + 4.0, _tag_y() + _mid(fs))
	var lap: int = Sim.lap_of(Sim.tier_of(id)) if Sim.part_of(id) == "kind" else 0
	return {"id": id, "at": spot(id), "mesh": _plate(id, lap, level > 0, done, can, wide, gone),
		"text": text, "text_at": text_at, "size": fs, "colour": colour}

## How far under a line's middle its baseline lies.
func _mid(fs: int) -> float:
	return (_num.get_ascent(fs) - _num.get_descent(fs)) * 0.5

static func _chip_at() -> Vector2:
	return Vector2(PLATE * 0.5 - 10.0, -PLATE * 0.5 + 8.0)

static func _tag_w(wide: int) -> float:
	return 12.0 + TAG_ORB + 4.0 + wide + 18.0

static func _tag_y() -> float:
	return PLATE * 0.5 + 14.0

## A node's plate and picture, one mesh, kept by picture and state: the sun
## button's rim where the energy reaches, paper where it does not, a leaf
## and a tick where nothing is left; a chip for the level it has, or the
## price's tag (`wide` its figure's width) while it has none. `gone`: of a
## kind the land no longer grows, so faded: the plate flat paper with no rim
## and no lip, its picture GONE of itself on it, its chip or its tick in
## paper tones, and no tag.
static func _plate(id: String, lap: int, levelled: bool, done: bool, can: bool, wide: int, gone := false) -> ArrayMesh:
	var part := Sim.part_of(id)
	var pic := "kind%d.%d" % [Sim.look_of(Sim.tier_of(id)), lap] if part == "kind" else (part if part in ["soft", "rich"] else id)
	var key := "%s|%d%d%d%d|%d" % [pic, int(levelled), int(done), int(can), int(gone), wide]
	if _plates.has(key):
		return _plates[key]
	var b := Face.Builder.new()
	var h := PLATE * 0.5
	var box := func(grow: float, down := 0.0) -> PackedVector2Array:
		return Face.Builder.round_rect(Vector2(-h - grow, -h - grow + down), Vector2.ONE * (PLATE + grow * 2.0), PLATE_R + grow)
	if gone:
		b.polygon(box.call(0.0), Art.PRICE_OFF)
	else:
		b.polygon(box.call(2.0, 9.0), Color(SHADOW, 0.1))
		b.polygon(box.call(0.0, 6.0), Pal.SUN_DEEP if can else SHADOW)
	if gone:
		pass
	elif done:
		b.polygon(box.call(0.0), LEAF_RIM)
		b.polygon(box.call(-4.0), Pal.LEAF_TILE)
	elif can:
		b.polygon(box.call(0.0), Pal.SUN)
		b.polygon(box.call(-7.0), FILL)
	else:
		b.polygon(box.call(0.0), RIM)
		b.polygon(box.call(-3.0), FILL)
	# the picture, fitted to the plate; a kind that has come round again
	# stands over its gold marks
	var mesh := _picture(id)
	var bounds := mesh.get_aabb()
	var room := PIC - (14.0 if lap > 0 else 0.0)
	var fit := minf(PIC_GROW, room / maxf(1.0, maxf(bounds.size.x, bounds.size.y)))
	var mid := Vector2(bounds.get_center().x, bounds.get_center().y)
	_append(b, _faded(mesh, Art.PRICE_OFF) if gone else mesh, Transform2D(0.0, Vector2(fit, fit), 0.0, Vector2(0.0, -8.0 if lap > 0 else 0.0) - mid * fit))
	var marks := mini(lap, 5)
	for i in marks:
		b.disc(Vector2((i - (marks - 1) * 0.5) * 16.0, h - 18.0), 5.5, Art.PRICE_OFF.lerp(Art.MARK, GONE) if gone else Art.MARK)
	var corner := _chip_at()
	if done:
		b.disc(corner, 22.0, Pal.SURFACE)
		b.disc(corner, 18.0, RIM if gone else Pal.LEAF_DEEP)
		b.stroke(PackedVector2Array([corner + Vector2(-8.0, 0.5), corner + Vector2(-2.5, 6.5), corner + Vector2(8.5, -6.0)]), 4.6, Pal.SURFACE)
	elif levelled:
		b.polygon(Face.Builder.round_rect(corner - CHIP * 0.5 - Vector2(3.0, 3.0), CHIP + Vector2(6.0, 6.0), CHIP.y * 0.5 + 3.0), Pal.SURFACE)
		b.polygon(Face.Builder.round_rect(corner - CHIP * 0.5, CHIP, CHIP.y * 0.5), RIM if gone else Pal.ACCENT)
	elif gone:
		pass
	else:
		var w := _tag_w(wide)
		var at := Vector2(-w * 0.5, _tag_y() - TAG_H * 0.5)
		b.polygon(Face.Builder.round_rect(at + Vector2(0.0, 4.0), Vector2(w, TAG_H), TAG_H * 0.5), Pal.SUN_DEEP if can else SHADOW)
		b.polygon(Face.Builder.round_rect(at, Vector2(w, TAG_H), TAG_H * 0.5), Pal.SUN if can else RIM)
		if not can:
			b.polygon(Face.Builder.round_rect(at + Vector2(2.5, 2.5), Vector2(w - 5.0, TAG_H - 5.0), TAG_H * 0.5), Art.PRICE_OFF)
		var sc := Motes.icon_scale(TAG_ORB)
		_append(b, Motes.orb(), Transform2D(0.0, Vector2(sc, sc), 0.0, at + Vector2(12.0 + TAG_ORB * 0.5, TAG_H * 0.5)))
	_plates[key] = b.mesh()
	return _plates[key]

## Another kept mesh into `b` under `xf`. Builder.append walks every vertex
## in script; this moves the points and the colours whole and walks only the
## indices, which a tree's few thousand want.
static func _append(b: Face.Builder, m: ArrayMesh, xf: Transform2D) -> void:
	var a := m.surface_get_arrays(0)
	var base := b.verts.size()
	b.verts.append_array(xf * (a[Mesh.ARRAY_VERTEX] as PackedVector2Array))
	b.cols.append_array(a[Mesh.ARRAY_COLOR] as PackedColorArray)
	var ix: PackedInt32Array = a[Mesh.ARRAY_INDEX]
	var out := PackedInt32Array()
	out.resize(ix.size())
	for i in ix.size():
		out[i] = base + ix[i]
	b.idx.append_array(out)

## A picture faded for a kind gone from the land: GONE of itself on `paper`,
## the tone it lies on. Every colour is mixed toward the paper and none is
## made clearer: a picture is shapes laid over each other (a crown's clumps
## over its trunk), and at 45% alpha each showed through the next. Kept by
## picture and paper.
static func _faded(m: ArrayMesh, paper: Color) -> ArrayMesh:
	var key := "%d|%s" % [m.get_instance_id(), paper.to_html()]
	if not _fades.has(key):
		var a := m.surface_get_arrays(0)
		var cols: PackedColorArray = (a[Mesh.ARRAY_COLOR] as PackedColorArray).duplicate()
		for i in cols.size():
			var c := cols[i]
			cols[i] = Color(paper.lerp(c, GONE), c.a)
		a[Mesh.ARRAY_COLOR] = cols
		var out := ArrayMesh.new()
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
		_fades[key] = out
	return _fades[key]

## The chosen node's ring, in ink on a pale line so it reads on the paper and
## on the earth alike.
static func _ring_mesh() -> ArrayMesh:
	if _ring == null:
		var b := Face.Builder.new()
		var g := 9.0
		var pts := Face.Builder.round_rect(Vector2.ONE * (-PLATE * 0.5 - g), Vector2.ONE * (PLATE + g * 2.0), PLATE_R + g)
		b.stroke(pts, 11.0, Color(Pal.SURFACE, 0.9), true)
		b.stroke(pts, 5.0, Pal.TEXT, true)
		_ring = b.mesh()
	return _ring

## The tree itself, in its own pixels: the roots from the foot out to their
## columns and down each chain, the trunk from the soil to the last kind
## owned and a bare stretch on to the next, a bough either side of every
## kind, in leaf once it has a level. Only between nodes that are shown.
func _links_mesh(seen: Dictionary) -> ArrayMesh:
	var b := Face.Builder.new()
	var seeds := int(sim.lv.seeds)
	for i in Sim.ROOT_ORDER.size():
		var ids: Array = Sim.ROOTS[Sim.ROOT_ORDER[i]]
		var x := spot(ids[0]).x
		var from := Vector2(signf(x) * 10.0, SOIL - 8.0)
		var to := Vector2(x, CELL.y)
		var path := Face.Builder.bezier3(from, Vector2(x * 0.42, SOIL + 40.0), Vector2(x, SOIL + 2.0), to, 18)
		path.append(to)
		b.stroke(path, 15.0, ROOT if sim.level(ids[0]) > 0 else ROOT_BARE)
		for k in range(1, ids.size()):
			if not seen.has(ids[k]):
				break
			b.stroke(PackedVector2Array([Vector2(x, CELL.y * k), Vector2(x, CELL.y * (k + 1))]), 12.0,
				ROOT if sim.level(ids[k]) > 0 else ROOT_BARE)
	var top := -CELL.y * seeds
	# on to the next kind, and a bud over it: the trunk has no top
	var next := top - CELL.y
	b.stroke(PackedVector2Array([Vector2(0.0, top), Vector2(0.0, next - PLATE * 0.5 - 26.0)]), 13.0, BARE)
	for side: float in [-1.0, 1.0]:
		b.fan(Transform2D(side * 0.7, Vector2(side * 13.0, next - PLATE * 0.5 - 34.0)) * Face.Builder.ring(Vector2.ZERO, 16.0, 8.0),
			Art.LEAF[Sim.look_of(seeds + 1)].lerp(BARE, 0.35))
	for tier in seeds + 1:
		var y := -CELL.y * tier
		var look: int = Sim.look_of(tier)
		for side: float in [-1.0, 1.0]:
			var level: int = sim.level(("soft:%d" if side < 0.0 else "rich:%d") % tier)
			var from := Vector2(side * 6.0, y + 46.0)
			var to := Vector2(side * CELL.x, y)
			var bend := Vector2(side * CELL.x * 0.56, y + 44.0)
			var path := Face.Builder.bezier2(from, bend, to, 16)
			path.append(to)
			b.stroke(path, 13.0, TRUNK if level > 0 else BARE)
			if level > 0:
				b.stroke(Face.Builder.bezier2(from + Vector2(0.0, 3.5), bend + Vector2(0.0, 3.5), to + Vector2(0.0, 3.5), 16), 4.0, TRUNK_SHADE)
			# its leaves: a pair once it has a level, two pairs with both
			for pair in level:
				var at := from.lerp(bend, 0.72 + 0.2 * pair) + Vector2(0.0, -5.0 - 5.0 * pair)
				for up: float in [-1.0, 1.0]:
					var leaf := Transform2D(side * (0.3 + 0.7 * up) * -1.0, at + Vector2(side * 6.0, up * 11.0))
					b.fan(leaf * Face.Builder.ring(Vector2.ZERO, 15.0, 7.5), Art.LEAF[look].darkened(0.08 if up > 0.0 else 0.0))
	# the trunk, flared where it meets the soil, darker down its right
	var half := 15.0
	var foot := SOIL + 3.0
	var left := Face.Builder.bezier2(Vector2(-half * 3.4, foot), Vector2(-half * 1.2, SOIL - 8.0), Vector2(-half, SOIL - 44.0), 10)
	var right := Face.Builder.bezier2(Vector2(half, SOIL - 44.0), Vector2(half * 1.2, SOIL - 8.0), Vector2(half * 3.4, foot), 10)
	var pts := left.duplicate()
	pts.append_array([Vector2(-half, SOIL - 44.0), Vector2(-half * 0.86, top), Vector2(half * 0.86, top)])
	pts.append_array(right)
	pts.append(Vector2(half * 3.4, foot))
	b.polygon(pts, TRUNK)
	var shade := PackedVector2Array([Vector2(half * 0.2, top), Vector2(half * 0.86, top)])
	shade.append_array(right)
	shade.append_array([Vector2(half * 3.4, foot), Vector2(half * 1.3, foot), Vector2(half * 0.36, SOIL - 44.0)])
	b.polygon(shade, TRUNK_SHADE)
	return b.mesh()

## What the tree stands in, one mesh in the tree's own pixels for a field of
## `view`: paper above with two pale hills far off, a line of turf, and the
## Grove's earth below, clay under it, with its seams and stones. Tall
## enough for the trunk as it is and the deepest root.
func _back_mesh(view: Vector2, seeds: int) -> ArrayMesh:
	var b := Face.Builder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261007
	var w := view.x * 0.5 + 4.0
	var top := -CELL.y * (seeds + 1) - view.y * 0.5 - 8.0
	var foot := CELL.y * DEEPEST + view.y * 0.5 + 8.0
	b.polygon(PackedVector2Array([Vector2(-w, top), Vector2(w, top), Vector2(w, SOIL), Vector2(-w, SOIL)]), FILL)
	for hill: Array in [[-0.5, 1.15, 132.0, HILL_FAR], [0.62, 0.95, 104.0, HILL_FAR], [-0.05, 1.3, 66.0, HILL]]:
		var pts := PackedVector2Array([Vector2(w * (float(hill[0]) - float(hill[1])), SOIL)])
		pts.append_array(Face.Builder.bezier2(Vector2(w * (float(hill[0]) - float(hill[1])), SOIL),
			Vector2(w * float(hill[0]), SOIL - float(hill[2]) * 2.0), Vector2(w * (float(hill[0]) + float(hill[1])), SOIL), 24))
		pts.append(Vector2(w * (float(hill[0]) + float(hill[1])), SOIL))
		b.polygon(pts, hill[3])
	# the earth, lighter under the turf and deeper as it goes down
	var rows := [[SOIL, Art.EARTH[0]], [SOIL + 150.0, Art.EARTH[1]], [SOIL + CELL.y * 2.2, Art.CLAY[0]], [foot, Art.CLAY[1]]]
	for i in rows.size() - 1:
		var v0 := b.vertex(Vector2(-w, rows[i][0]), rows[i][1])
		var v1 := b.vertex(Vector2(w, rows[i][0]), rows[i][1])
		var v2 := b.vertex(Vector2(w, rows[i + 1][0]), rows[i + 1][1])
		var v3 := b.vertex(Vector2(-w, rows[i + 1][0]), rows[i + 1][1])
		b.tri(v0, v1, v2)
		b.tri(v0, v2, v3)
	var deep := foot - SOIL
	for i in 46:
		var at := Vector2(rng.randf_range(-w + 20.0, w - 70.0), SOIL + 40.0 + deep * rng.randf())
		var long := rng.randf_range(22.0, 58.0)
		b.stroke(PackedVector2Array([at, at + Vector2(long, rng.randf_range(-3.0, 3.0))]), 3.0, Color(Art.SEAM, 0.16))
	for i in 30:
		var at := Vector2(rng.randf_range(-w + 26.0, w - 26.0), SOIL + 50.0 + deep * rng.randf())
		var s := rng.randf_range(0.7, 1.35)
		b.ellipse(at, 12.0 * s, 8.0 * s, Art.STONE_SHADE.lerp(Art.STONE, 0.45))
		b.ellipse(at + Vector2(-3.0, -2.4) * s, 6.0 * s, 3.4 * s, Art.STONE)
	# the turf: a dark lip hanging over the earth in scallops, grass on it
	var x := -w
	while x < w:
		var r := rng.randf_range(8.0, 13.0)
		b.disc(Vector2(x, SOIL + 9.0), r, Art.LIP)
		x += r * 1.25
	b.polygon(PackedVector2Array([Vector2(-w, SOIL - 9.0), Vector2(w, SOIL - 9.0), Vector2(w, SOIL + 10.0), Vector2(-w, SOIL + 10.0)]), Art.LIP_LIT)
	b.polygon(PackedVector2Array([Vector2(-w, SOIL - 12.0), Vector2(w, SOIL - 12.0), Vector2(w, SOIL + 1.0), Vector2(-w, SOIL + 1.0)]), Art.GRASS)
	b.stroke(PackedVector2Array([Vector2(-w, SOIL - 11.0), Vector2(w, SOIL - 11.0)]), 3.0, Art.GRASS_LIT, false, false)
	for i in 34:
		var at := Vector2(rng.randf_range(-w + 10.0, w - 10.0), SOIL - 10.0)
		if absf(at.x) < 60.0:
			continue
		var s := rng.randf_range(1.1, 1.7)
		b.append(Art.tuft(), Transform2D(0.0, Vector2(s, s), 0.0, at), Art.TUFTS[rng.randi() % Art.TUFTS.size()])
	return b.mesh()

## What lies over the tree, in the field's pixels: the card's paper on the
## field's four corners, so it is rounded as the card is, a hairline round
## it, and a little shade under its top and over its foot, where the tree
## goes on out of sight.
static func _frame_mesh(view: Vector2) -> ArrayMesh:
	var b := Face.Builder.new()
	var ink := Color(0.3, 0.2, 0.1)
	for edge: Array in [[0.0, 26.0], [view.y, -26.0]]:
		var v0 := b.vertex(Vector2(0.0, edge[0]), Color(ink, 0.1))
		var v1 := b.vertex(Vector2(view.x, edge[0]), Color(ink, 0.1))
		var v2 := b.vertex(Vector2(view.x, float(edge[0]) + float(edge[1])), Color(ink, 0.0))
		var v3 := b.vertex(Vector2(0.0, float(edge[0]) + float(edge[1])), Color(ink, 0.0))
		b.tri(v0, v1, v2)
		b.tri(v0, v2, v3)
	var r := FIELD_R
	for corner: Array in [[Vector2.ZERO, Vector2(r, r), PI], [Vector2(view.x, 0.0), Vector2(view.x - r, r), PI * 1.5],
			[view, view - Vector2(r, r), 0.0], [Vector2(0.0, view.y), Vector2(r, view.y - r), PI * 0.5]]:
		var pts := PackedVector2Array([corner[0]])
		pts.append_array(Face.Builder.arc_points(corner[1], r, corner[2], float(corner[2]) + PI * 0.5))
		b.polygon(pts, Pal.PAPER)
	b.stroke(Face.Builder.round_rect(Vector2(1.0, 1.0), view - Vector2(2.0, 2.0), r - 1.0), 2.0, Color(Pal.LINE, 0.55), true)
	return b.mesh()

func _draw_field() -> void:
	if sim == null or _back == null or _links == null:
		return
	var view := _field.size
	if _frame == null or _frame_for != view:
		_frame_for = view
		_frame = _frame_mesh(view)
	var o := _origin()
	var move := Transform2D(0.0, o)
	_field.draw_mesh(_back, null, move)
	_field.draw_mesh(_links, null, move)
	for n: Dictionary in _nodes:
		var at: Vector2 = o + n.at
		if at.y < -PLATE or at.y > view.y + PLATE:
			continue
		var k := Vector2.ONE
		if _born.has(n.id):
			k = Motion.pop_in_scale(float(_born[n.id]))
		elif _bumps.has(n.id):
			k *= Motion.bump_scale(float(_bumps[n.id]), 0.12)
		_field.draw_set_transform(at, 0.0, k)
		# the ring under the plate, so the chip and the tag lie over it
		if n.id == _chosen:
			_field.draw_mesh(_ring_mesh(), null)
		_field.draw_mesh(n.mesh, null)
		if n.text != "":
			_field.draw_string(_num, n.text_at, n.text, HORIZONTAL_ALIGNMENT_LEFT, -1, n.size, n.colour)
	_field.draw_set_transform(Vector2.ZERO)
	_field.draw_mesh(_frame, null)
