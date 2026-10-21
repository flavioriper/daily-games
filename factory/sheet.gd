extends Control

## Factory's program sheet: a panel that slides up over the lower part of the
## floor when a robot is picked, where its program is read and changed while
## the floor keeps running above it. Spec
## docs/superpowers/specs/2026-10-20-factory-rewired-design.md, section 10;
## its grammar is the prototype's (docs/brainstorm/concepts.html, tab
## "Factory · rewired"): the body at the left with a bolt, the chain laid
## left to right from it, each node a rounded box with its glyph, a bar on
## its input side and a dot on its output side, a `+` past a loose output and
## one on the middle of every wire, the loop-back wire drawn round the top
## with "again", the parts hanging under the body on dashed wires from a
## diamond port, a dotted grid behind.
##
## factory/screen.gd mounts it over its field and hands it the one sim with
## `setup`; `open(i)` shows robot `i`'s program. Every change goes through
## the sim's editing API (`set_next`, `add_node`, `remove_node`, `set_move`,
## `fit`, `unfit`, `tow`), which sends the robot home; the screen forwards
## the sim's events (`event`) so an edit made from elsewhere redraws it too.
##
## The hand. Every finger is a ScreenTouch or a ScreenDrag, the desktop mouse
## read beside them. A tap on a node, the body or a part picks it and stands
## the pill (ui/hud/piece_pill.gd) by it; a tap on a `+` opens the tray at the
## sheet's foot (the node kinds the parts give, or the bin's parts); a press
## on an output dot that moves over DRAG pulls a wire, dropped on a node to
## wire it, and one that does not move arms the dot, the next node tapped
## taking the wire; a drag anywhere else pans the pane sideways; a swipe down
## from the handle closes the sheet.
##
## Drawn as few meshes as it can: the paper and the handle, baked once a
## size; the graph (grid, wires, boxes, ports, glyphs, the Move's arrow and
## count, the `+`s, the parts), one ArrayMesh rebuilt only when it changes
## and drawn under the pan; the running node's glow, a cached ring under a
## transform. Face.Builder has no text, so the names under the nodes are
## lettered over the mesh with TextLines drawn one font size after the other
## (each size is one glyph batch).
##
## `preview` is the tutorial's: the same sheet drawn small into a rect of a
## diagram (`show_preview`), with no input, no slide and no handle to pull,
## on a sim of the page's own (ui/hud/factory_tutorial_diagram.gd).

signal closed

const Sim = preload("res://factory/sim.gd")
const Bots = preload("res://factory/bots.gd")
const Art = preload("res://factory/art.gd")
const Life = preload("res://factory/life.gd")
const Face = preload("res://ui/faces/face.gd")
const Motion = preload("res://core/motion.gd")
const Analytics = preload("res://core/analytics.gd")
const PiecePill = preload("res://ui/hud/piece_pill.gd")

## The sheet's height (of the field's), the body's box, a node's height and
## the widths of a Pick or Release and of a Move, the air between two nodes,
## a port's hit zone, a part's disc, the tray's band, the slide in and the
## pixels a press on an output dot moves before it pulls a wire. The spec
## gives its sizes in an 810-wide space; the canvas is 1080 wide, so they are
## K times the spec's here (the controller, 2026-10-20), and every size below
## is in the canvas's pixels.
const K := 4.0 / 3.0
const HEIGHT := 0.58
const BODY := 150.0
const NODE_H := 128.0
const NODE_W := 128.0
const MOVE_W := 170.0
const GAP := 80.0
const PORT_HIT := 107.0
const PART := 112.0
const TRAY_H := 147.0
const SLIDE := 0.26
const DRAG := 6.0

## The handle's band at the top (a swipe down from it closes the sheet, once
## it has gone CLOSE_PULL), and a press that moves less than TAP is a tap
## (the screen's).
const HANDLE_H := 80.0
const CLOSE_PULL := 146.0
const TAP := 24.0
## The graph in the pane: the loop-back's lane LANE under the content's top,
## the chain's middle DROP under the lane, the body LEFT in from the left; a
## wire back turns up RISE past its output dot and comes down LOOP_IN before
## the box it goes to; corners of CORNER. After a node whose wire does not
## go to the next box the air is WIDE, room for a loose `+` or a wire's rise.
const LANE := 80.0
const DROP := 187.0
const LEFT := 100.0
const RISE := 36.0
const LOOP_IN := 50.0
const CORNER := 21.0
const WIDE := 123.0
## The parts: the dashed bus BUS under the body, the parts BUS under it, a
## part every PART_STEP.
const BUS := 61.0
const PART_STEP := 181.0
## The `+` past a loose output, the round one on a wire, and how near a
## press must come to either; the output dot, the input bar, the grid's
## pitch and a box's corner.
const PLUS := 53.0
const PLUS_MID := 37.0
const PLUS_HIT := 85.0
const DOT_R := 15.0
const BAR := Vector2(13.0, 45.0)
const GRID := 40.0
const ROUND := 24.0
## Lettering, and the tray's chips.
const FS := 32
const FS_SMALL := 24
const CHIP_W := 300.0
## The running node's glow breathes once a GLOW_S seconds.
const GLOW_S := 1.2

const PAPER := Color("fffaf1")
const DOT := Color("d8ccb6")
const LINE := Color("e3d8c6")
const WIRE := Color("8a7f72")
const LIVE := Color("c68a44")
const SEL := Color("3f7fd6")
const RED := Color("d9574a")
const INK := Color("2f2a25")
const MUTED := Color("6f655b")
const DEAD := Color("f4efe6")

## Names the player reads, by node kind and by part.
const NODE_KEY := {"move": "FACTORY_MOVE", "pick": "FACTORY_PICK", "release": "FACTORY_RELEASE"}
const PART_KEY := {"treads": "FACTORY_TREADS", "gripper": "FACTORY_GRIPPER", "battery": "FACTORY_BATTERY",
	"fast": "FACTORY_FAST_TREADS", "plug": "FACTORY_FAST_PLUG"}
## The pill's buttons and their captions; `lift` is Remove on a node and
## Take off on a part (`_pill_names`).
const PILL_CAP := {"turn": "TL_TURN", "minus": "FACTORY_FEWER", "plus": "FACTORY_MORE", "lift": "FACTORY_REMOVE",
	"info": "FACTORY_INFO", "place": "FACTORY_TOW"}
const MOUSE := -2
const NO_FINGER := -99

## Strokes of the Move's count, 1..9, in a box one wide and one tall: each
## an Array of polylines; a polyline Array of [x, y] or ["arc", cx, cy, r,
## from, to] (turns) or ["ring", cx, cy, rx, ry] (closed).
const DIGITS := {
	1: [[[0.22, 0.22], [0.58, 0.0], [0.58, 1.0]]],
	2: [[["arc", 0.5, 0.28, 0.3, 1.05, 2.15], [0.1, 1.0], [0.92, 1.0]]],
	3: [[["arc", 0.48, 0.26, 0.26, 1.1, 2.5]], [["arc", 0.48, 0.74, 0.27, -0.5, 0.9]]],
	4: [[[0.68, 1.0], [0.68, 0.0], [0.06, 0.68], [0.94, 0.68]]],
	5: [[[0.86, 0.0], [0.24, 0.0], [0.18, 0.44], ["arc", 0.5, 0.67, 0.32, -0.8, 0.85]]],
	6: [[["ring", 0.5, 0.68, 0.32, 0.31]], [[0.78, 0.04], ["q", 0.18, 0.16, 0.18, 0.66]]],
	7: [[[0.08, 0.0], [0.92, 0.0], [0.4, 1.0]]],
	8: [[["ring", 0.5, 0.25, 0.25, 0.24]], [["ring", 0.5, 0.73, 0.3, 0.27]]],
	9: [[["ring", 0.5, 0.32, 0.32, 0.31]], [[0.82, 0.34], ["q", 0.82, 0.94, 0.24, 0.98]]],
}

var sim: RefCounted
## Drawn into a tutorial page: it takes no input and stays where it is put.
var preview := false
## The robot whose program is up.
var robot := 0
## The screen's cues: a touch, a node, a wire, a part fitted, a no.
var _fx: Node2D
var _open := false
var _inset := 0.0
var _shown_y := 0.0
var _hidden_y := 0.0
var _slide: Tween
var _clock := 0.0

## The pane's sideways pan (0 or less) and what is picked: "" for nothing,
## "body", a node's id, or PART_SEL + i for part i. `_tray` is {} closed,
## {"after": id} for a node into the wire out of `id`, {"parts": true} for
## the bin; `_armed` the output dot armed by a tap; `_wire` the wire a finger
## pulls, {from, at}.
var _pan := 0.0
var _sel := ""
## A part's pick, never a node's id (node ids are the sim's and may start
## with any letter).
const PART_SEL := "part:"
var _sel_at := 0.0
var _info := false
var _tray := {}
var _armed := ""
var _wire := {}
var _btn_at := {}

var _finger := NO_FINGER
var _start := Vector2.ZERO
var _moved := false
var _down := {}          # what the press landed on (`_hit`)
var _pan_from := 0.0
var _pull := 0.0         # how far a swipe from the handle has pulled it down
var _grab_y := 0.0       # where that swipe began, in the parent's pixels

var _pill_ui: PiecePill
var _paper: ArrayMesh
var _graph: ArrayMesh
var _labels: Array = []  # [text, at (graph space, centre and baseline), fs, colour]
var _dirty := true
var _glows := {}         # "w|h|r" -> ring mesh
var _wire_mesh: ArrayMesh
var _tray_mesh: ArrayMesh
var _tray_key := ""
var _tray_words: Array = []
var _band: ArrayMesh
var _lines := {}         # [text, fs] -> TextLine

func setup(with_sim: RefCounted, fx: Node2D) -> void:
	sim = with_sim
	_fx = fx
	_dirty = true

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	visible = false
	_pill_ui = PiecePill.new(PILL_CAP.duplicate())

## Fits the sheet to the field it lies over: HEIGHT of it tall, its foot
## `inset` over the screen's (the safe area's) bottom edge.
func fit_to(field_size: Vector2, inset: float) -> void:
	_inset = inset
	size = Vector2(field_size.x, roundf(field_size.y * HEIGHT))
	position.x = 0.0
	_shown_y = field_size.y - size.y
	_hidden_y = field_size.y + 8.0
	if _slide == null or not _slide.is_running():
		position.y = _shown_y + _pull if _open else _hidden_y
	_paper = null
	_band = null
	_tray_key = ""
	_dirty = true
	queue_redraw()

func is_open() -> bool:
	return _open

## Robot `i`'s program drawn into `rect` of the parent (a tutorial page): the
## sheet is `across` pixels wide and scaled down to fit, panned to bring node
## `focus` (when it has one) to the middle. Its hand is off, so a page can
## play it with edits of the sim; `tray` stands the bin's parts up.
func show_preview(i: int, rect: Rect2, across: float, focus := "", tray := false) -> void:
	preview = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	robot = i
	_open = true
	_sel = ""
	_info = false
	_armed = ""
	_tray = {"parts": true} if tray else {}
	_tray_key = ""
	_pan = 0.0
	var k := rect.size.x / across
	size = Vector2(across, rect.size.y / k)
	scale = Vector2(k, k)
	position = rect.position
	_paper = null
	_band = null
	if focus != "":
		var r := node_rect(focus)
		if r.size.x > 0.0:
			_pan = _clamp_pan(across * 0.5 - r.get_center().x)
	_dirty = true
	visible = true
	queue_redraw()

## Robot `i`'s program, sliding up if the sheet was down; on another robot
## the picks, the tray and the pan start over.
func open(i: int) -> void:
	if sim == null or i < 0 or i >= sim.robots.size():
		return
	var was := _open
	robot = i
	let_go()
	_sel = ""
	_info = false
	_tray = {}
	_armed = ""
	_pan = 0.0
	_open = true
	_dirty = true
	visible = true
	if not was:
		Motion.stop(_slide)
		_slide = Motion.slide(self, "position:y", _hidden_y, _shown_y, SLIDE, 0.0, false)
	queue_redraw()

func close() -> void:
	if not _open:
		return
	_open = false
	let_go()
	_sel = ""
	_tray = {}
	_armed = ""
	Motion.stop(_slide)
	_slide = Motion.slide(self, "position:y", position.y, _hidden_y, SLIDE, 0.0, false)
	if _slide == null:
		visible = false
	else:
		_slide.tween_callback(func() -> void:
			if not _open:
				visible = false)
	closed.emit()

## Every finger let go (a card went up, the app lost the focus).
func let_go() -> void:
	_finger = NO_FINGER
	_down = {}
	_wire = {}
	_wire_mesh = null
	if _pull != 0.0:
		_pull = 0.0
		if _open:
			position.y = _shown_y

## A sim event, forwarded by the screen: an edit, a tow or a fault of this
## robot redraws the graph, and a pick that is gone is dropped.
func event(e: Dictionary) -> void:
	if not _open or int(e.get("robot", -1)) != robot:
		return
	match String(e.type):
		"edited", "towed", "stuck", "flat":
			_dirty = true
			_keep_valid()

func _keep_valid() -> void:
	var b := _bot()
	if b.is_empty():
		return
	if _sel.begins_with(PART_SEL):
		if int(_sel.substr(PART_SEL.length())) >= (b.parts as Array).size():
			_sel = ""
	elif _sel != "" and _sel != Sim.BODY and not b.nodes.has(_sel):
		_sel = ""
	if _tray.has("after") and _tray.after != Sim.BODY and not b.nodes.has(_tray.after):
		_tray = {}
	if _armed != "" and _armed != Sim.BODY and not b.nodes.has(_armed):
		_armed = ""

func _bot() -> Dictionary:
	if sim == null or robot < 0 or robot >= sim.robots.size():
		return {}
	return sim.robots[robot]

func _process(delta: float) -> void:
	if not visible:
		return
	_clock += delta
	queue_redraw()

# --- the layout ---

## The pane under the handle and over the tray's band, in the sheet's pixels.
func _pane() -> Rect2:
	return Rect2(0.0, HANDLE_H, size.x, maxf(1.0, size.y - TRAY_H - _inset - HANDLE_H))

## The graph laid out, unpanned (the sheet's pixels at `_pan` 0): `rects` id
## -> Rect2 ("body" and every node), `ids` the nodes left to right (the chain
## as it runs from the body, then the rest in the order they were made),
## `plus` id -> {rect, disc} (the `+` on the wire out of id, or past it when
## loose), `parts` Rect2 a part, `parts_plus`, and the lines: `cy` the
## chain's middle, `lane` the loop-back's, `bus` the parts' wire; `width` the
## whole.
func _layout() -> Dictionary:
	var b := _bot()
	var lay := {"rects": {}, "ids": [], "plus": {}, "parts": [], "parts_plus": Rect2(), "cy": 0.0, "lane": 0.0, "bus": 0.0, "width": size.x}
	if b.is_empty():
		return lay
	var pane := _pane()
	var tall := LANE + DROP + BODY * 0.5 + BUS * 2.0 + PART + 85.0
	var top := pane.position.y + maxf(0.0, (pane.size.y - tall) * 0.12)
	var lane := top + LANE
	var cy := lane + DROP
	lay.lane = lane
	lay.cy = cy
	var w: Dictionary = Bots.walk(b)
	var ids: Array = (w.ids as Array).duplicate()
	for id: String in b.order:
		if not ids.has(id) and b.nodes.has(id):
			ids.append(id)
	lay.ids = ids
	var rects: Dictionary = lay.rects
	rects[Sim.BODY] = Rect2(LEFT, cy - BODY * 0.5, BODY, BODY)
	var x := LEFT + BODY
	var prev: String = Sim.BODY
	for id: String in ids:
		x += GAP if String(b.next.get(prev, {}).get("out", "")) == id else WIDE
		var wd := MOVE_W if String(b.nodes[id].kind) == "move" else NODE_W
		rects[id] = Rect2(x, cy - NODE_H * 0.5, wd, NODE_H)
		x += wd
		prev = id
	# the `+` of every wire, or past every loose output
	var order := [Sim.BODY] + ids
	for k in order.size():
		var id: String = order[k]
		var r: Rect2 = rects[id]
		var x1 := r.end.x
		var out := String(b.next.get(id, {}).get("out", ""))
		var c := Vector2.ZERO
		var disc := true
		if out == "" or (out != Sim.BODY and not rects.has(out)):
			c = Vector2(x1 + 21.0 + PLUS * 0.5, cy)
			disc = false
		elif out == Sim.BODY or (rects[out] as Rect2).position.x <= x1:
			c = Vector2(x1 + RISE, (lane + cy) * 0.5)
		else:
			var x2: float = (rects[out] as Rect2).position.x
			if k + 1 < order.size() and order[k + 1] == out:
				c = Vector2((x1 + x2) * 0.5, cy)
			else:
				c = _arch_at(Vector2(x1, cy), Vector2(x2, cy), lane, 0.5)
		var d := PLUS_MID if disc else PLUS
		lay.plus[id] = {"rect": Rect2(c - Vector2(d, d) * 0.5, Vector2(d, d)), "disc": disc}
	# the parts, under the body
	var bus := cy + BODY * 0.5 + BUS
	lay.bus = bus
	var bcx := LEFT + BODY * 0.5
	var parts: Array = []
	for i in (b.parts as Array).size():
		parts.append(Rect2(bcx + i * PART_STEP - PART * 0.5, bus + BUS, PART, PART))
	lay.parts = parts
	var n := parts.size()
	lay.parts_plus = Rect2(Vector2(bcx + n * PART_STEP, bus + BUS + PART * 0.5) - Vector2(PLUS, PLUS) * 0.5, Vector2(PLUS, PLUS))
	lay.width = maxf(x, bcx + n * PART_STEP + PLUS) + 140.0
	return lay

## A wire forward past other boxes arches over them: its point at `t`.
static func _arch_at(a: Vector2, z: Vector2, lane: float, t: float) -> Vector2:
	var c0 := Vector2(a.x + 120.0, lane + 32.0)
	var c1 := Vector2(z.x - 120.0, lane + 32.0)
	var u := 1.0 - t
	return a * (u * u * u) + c0 * (3.0 * u * u * t) + c1 * (3.0 * u * t * t) + z * (t * t * t)

func _off() -> Vector2:
	return Vector2(_pan, 0.0)

## Node `id`'s box ("body" too), in the sheet's pixels; Rect2() for none.
func node_rect(id: String) -> Rect2:
	var r: Variant = _layout().rects.get(id)
	return Rect2() if r == null else Rect2((r as Rect2).position + _off(), (r as Rect2).size)

## The middle of node `id`'s output dot.
func out_port(id: String) -> Vector2:
	var r := node_rect(id)
	return Vector2(r.end.x, r.get_center().y)

## The middle of node `id`'s input bar.
func in_port(id: String) -> Vector2:
	var r := node_rect(id)
	return Vector2(r.position.x, r.get_center().y)

## The `+` on the wire out of `after`, or past it when that wire is loose.
func plus_rect(after: String) -> Rect2:
	var p: Variant = _layout().plus.get(after)
	return Rect2() if p == null else Rect2((p.rect as Rect2).position + _off(), (p.rect as Rect2).size)

func parts_plus_rect() -> Rect2:
	var r: Rect2 = _layout().parts_plus
	return Rect2(r.position + _off(), r.size)

## Part `index`'s disc's box.
func part_rect(index: int) -> Rect2:
	var parts: Array = _layout().parts
	if index < 0 or index >= parts.size():
		return Rect2()
	return Rect2((parts[index] as Rect2).position + _off(), (parts[index] as Rect2).size)

# --- the tray ---

## The band at the sheet's foot the tray and the body's battery line use.
func _band_rect() -> Rect2:
	return Rect2(0.0, size.y - TRAY_H - _inset, size.x, TRAY_H + _inset)

## What the tray offers: [kind or part, locked, sub line] rows.
func _tray_rows() -> Array:
	var b := _bot()
	var rows: Array = []
	if _tray.is_empty() or b.is_empty():
		return rows
	if _tray.has("after"):
		for kind: String in Sim.NODES:
			var ok: bool = Bots.can(b, kind)
			var part := String(Sim.NODES[kind].part)
			rows.append([kind, not ok, "" if ok else tr("FACTORY_NEEDS") % tr(String(PART_KEY.get(part, part)))])
		return rows
	for row: Dictionary in sim.bin_rows():
		var part := String(row.part)
		var fitted: bool = (b.parts as Array).has(part)
		match String(row.state):
			"spare":
				rows.append([part, fitted, tr("FACTORY_IN_BIN")])
			"price":
				rows.append([part, fitted or int(sim.coins) < int(row.price), "$%d" % int(row.price)])
			"later":
				rows.append([part, true, tr("FACTORY_LATER")])
			_:
				rows.append([part, true, ""])
	return rows

## Chip `kind`'s box in the tray (a node kind, or a part with the bin up);
## Rect2() when the tray is closed or has no such chip.
func tray_rect(kind: String) -> Rect2:
	var rows := _tray_rows()
	for k in rows.size():
		if String(rows[k][0]) == kind:
			return _chip_at(k, rows.size())
	return Rect2()

func tray_locked(kind: String) -> bool:
	for row: Array in _tray_rows():
		if String(row[0]) == kind:
			return bool(row[1])
	return false

func _chip_at(k: int, n: int) -> Rect2:
	var band := _band_rect()
	var w := minf(CHIP_W, (size.x - 48.0 - (n - 1) * 16.0) / maxf(1.0, n))
	var whole := n * w + (n - 1) * 16.0
	var x0 := (size.x - whole) * 0.5
	return Rect2(x0 + k * (w + 16.0), band.position.y + 45.0, w, TRAY_H - 59.0)

# --- the pill ---

func _pill_names() -> Array:
	var b := _bot()
	if _sel == "" or b.is_empty():
		return []
	if _sel == Sim.BODY:
		return ["info", "place"] if String(b.stuck) == "flat" else ["info"]
	if _sel.begins_with(PART_SEL):
		return ["lift"]
	if not b.nodes.has(_sel):
		return []
	return ["turn", "minus", "plus", "lift"] if String(b.nodes[_sel].kind) == "move" else ["lift"]

func _sel_rect() -> Rect2:
	if _sel.begins_with(PART_SEL):
		return part_rect(int(_sel.substr(PART_SEL.length())))
	return node_rect(_sel)

func _pill_layout() -> Dictionary:
	var names := _pill_names()
	if names.is_empty():
		return {}
	var r := _sel_rect()
	# it stands under the words under the box, not over them
	var words := 0.0 if _sel == Sim.BODY else (75.0 if _sel.begins_with(PART_SEL) else 48.0)
	return PiecePill.layout(names, Vector2(r.get_center().x, r.position.y), Vector2(r.get_center().x, r.end.y + words), _pane())

## Where pill button `button` is, in the sheet's pixels; Rect2() with no pill
## or no such button.
func pill_button_rect(button: String) -> Rect2:
	var lay := _pill_layout()
	return Rect2() if lay.is_empty() else lay.buttons.get(button, Rect2())

func _pill_title() -> String:
	var b := _bot()
	if _sel == Sim.BODY:
		return _robot_name(b)
	if _sel.begins_with(PART_SEL):
		var part := String(b.parts[int(_sel.substr(PART_SEL.length()))])
		return tr(String(PART_KEY.get(part, part)))
	var kind := String(b.nodes[_sel].kind)
	return tr(String(NODE_KEY.get(kind, kind)))

func _robot_name(b: Dictionary) -> String:
	var key := "FACTORY_" + String(b.name).to_upper()
	return tr(key) if tr(key) != key else String(b.name)

func _pick(what: String) -> void:
	_sel = what
	_sel_at = _clock
	_info = false
	_tray = {}
	_armed = ""
	_dirty = true

## A pill button let go on.
func _pill_press(button: String) -> void:
	var b := _bot()
	if b.is_empty():
		return
	_btn_at[button] = _clock
	match button:
		"turn", "minus", "plus":
			var node: Dictionary = b.nodes[_sel]
			var f := int(node.facing)
			var n := int(node.n)
			if button == "turn":
				f = (f + 1) % 4
			else:
				n += 1 if button == "plus" else -1
			if n < 1 or n > 9:
				_no()
				return
			if sim.set_move(robot, _sel, f, n):
				_fx.touch(1.0 + (n - 5) * 0.03 if button != "turn" else 1.06)
		"lift":
			var done: bool = sim.unfit(robot, int(_sel.substr(PART_SEL.length()))) if _sel.begins_with(PART_SEL) else sim.remove_node(robot, _sel)
			if done:
				_fx.touch(0.9)
			_sel = ""
		"info":
			_info = not _info
			_fx.touch(1.0 if _info else 0.9)
		"place":
			if sim.tow(robot):
				_fx.touch()
	_dirty = true

func _no() -> void:
	_cue("no")

## One of the factory set's cues (assets/sfx/factory/), where there is an
## ear: a tutorial's page has none.
func _cue(cue_name: String) -> void:
	if _fx != null:
		_fx.cue(cue_name)

# --- the hand ---

func _gui_input(event: InputEvent) -> void:
	if not _open or preview:
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			_press(t.index, t.position)
		else:
			_release(t.index, t.position)
	elif event is InputEventScreenDrag:
		_drag((event as InputEventScreenDrag).index, (event as InputEventScreenDrag).position)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_press(MOUSE, mb.position)
			else:
				_release(MOUSE, mb.position)
		elif mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			_pan = _clamp_pan(_pan + (60.0 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else -60.0))
	elif event is InputEventMouseMotion and _finger == MOUSE:
		_drag(MOUSE, (event as InputEventMouseMotion).position)
	accept_event()

## What is under `p`: {what, id}. The pill and the tray first (they lie over
## the graph), then the handle, then a box (its own dot only right by the
## dot), then the output dot or `+` nearest `p` within their zones outside
## the boxes, then a box's reach, a part, the pane.
func _hit(p: Vector2) -> Dictionary:
	var pill := _pill_layout()
	if not pill.is_empty():
		var nm := PiecePill.button_at(pill, p)
		if nm != "":
			return {"what": "pill", "id": nm}
		if (pill.rect as Rect2).has_point(p):
			return {"what": "none"}
	if not _tray.is_empty() or (_info and _sel == Sim.BODY):
		if _band_rect().has_point(p):
			var rows := _tray_rows()
			for k in rows.size():
				if _chip_at(k, rows.size()).has_point(p):
					return {"what": "chip", "id": String(rows[k][0])}
			return {"what": "none"}
	if p.y < HANDLE_H:
		return {"what": "handle"}
	var lay := _layout()
	var off := _off()
	# inside a box the box wins, but for its own dot within two of the dot's
	# radii; with a dot armed, anywhere inside another box takes the wire
	for id: String in lay.rects:
		var r: Rect2 = lay.rects[id]
		if not Rect2(r.position + off, r.size).has_point(p):
			continue
		if _armed != "" and id != _armed:
			return {"what": "node", "id": id}
		if p.distance_to(Vector2(r.end.x, r.get_center().y) + off) <= DOT_R * 2.0:
			return {"what": "out", "id": id}
		return {"what": "node", "id": id}
	var best := {}
	var best_d := INF
	for id: String in lay.rects:
		var r: Rect2 = lay.rects[id]
		var d := p.distance_to(Vector2(r.end.x, r.get_center().y) + off)
		if d <= PORT_HIT * 0.5 and d < best_d:
			best = {"what": "out", "id": id}
			best_d = d
	for id: String in lay.plus:
		var d := p.distance_to((lay.plus[id].rect as Rect2).get_center() + off)
		if d <= PLUS_HIT * 0.5 and d < best_d:
			best = {"what": "plus", "id": id}
			best_d = d
	var pp: Rect2 = lay.parts_plus
	var dp := p.distance_to(pp.get_center() + off)
	if dp <= PLUS_HIT * 0.5 and dp < best_d:
		best = {"what": "parts_plus", "id": ""}
	if not best.is_empty():
		return best
	var into := _box_at(lay, p)
	if into != "":
		return {"what": "node", "id": into}
	for i in (lay.parts as Array).size():
		var r: Rect2 = lay.parts[i]
		if Rect2(r.position + off, r.size).grow(13.0).has_point(p):
			return {"what": "part", "id": str(i)}
	return {"what": "pane"}

## The box ("body" or a node) under `p`, or within a port's reach of its
## input bar: what a wire dropped there goes into. "" for none.
func _box_at(lay: Dictionary, p: Vector2) -> String:
	var off := _off()
	for id: String in lay.rects:
		var r: Rect2 = lay.rects[id]
		if Rect2(r.position + off, r.size).grow(11.0).has_point(p):
			return id
	for id: String in lay.rects:
		var r: Rect2 = lay.rects[id]
		if p.distance_to(Vector2(r.position.x, r.get_center().y) + off) <= PORT_HIT * 0.5:
			return id
	return ""

func _press(finger: int, p: Vector2) -> void:
	if _finger != NO_FINGER:
		return
	_finger = finger
	_start = p
	_moved = false
	_pan_from = _pan
	_grab_y = p.y + position.y
	_down = _hit(p)

func _drag(finger: int, p: Vector2) -> void:
	if finger != _finger:
		return
	var what := String(_down.get("what", ""))
	var far := p.distance_to(_start)
	if what == "out" and (far > DRAG or not _wire.is_empty()):
		_moved = true
		_wire = {"from": String(_down.id), "at": p}
		return
	if not _moved and far >= TAP:
		_moved = true
	if not _moved:
		return
	if what == "handle":
		# the sheet moves with the finger, so the finger is read in the
		# parent's pixels
		Motion.stop(_slide)
		_pull = maxf(0.0, p.y + position.y - _grab_y)
		position.y = _shown_y + _pull
		return
	if what in ["pill", "chip", "none"]:
		return
	_pan = _clamp_pan(_pan_from + p.x - _start.x)

func _clamp_pan(v: float) -> float:
	var w: float = _layout().width
	return clampf(v, minf(0.0, size.x - w), 0.0)

func _release(finger: int, p: Vector2) -> void:
	if finger != _finger:
		return
	_finger = NO_FINGER
	var down := _down
	_down = {}
	var what := String(down.get("what", ""))
	if not _wire.is_empty():
		var from := String(_wire.from)
		_wire = {}
		_wire_mesh = null
		var to := _box_at(_layout(), p)
		if to != "" and to != from:
			_wire_to(from, to)
		return
	if what == "handle":
		var pulled := _pull
		_pull = 0.0
		if pulled >= CLOSE_PULL:
			close()
		elif _open:
			Motion.stop(_slide)
			_slide = Motion.slide(self, "position:y", position.y, _shown_y, SLIDE * 0.6, 0.0, false)
		return
	if _moved:
		return
	_tap(down, p)

func _tap(down: Dictionary, p: Vector2) -> void:
	var b := _bot()
	if b.is_empty():
		return
	var what := String(down.get("what", ""))
	var id := String(down.get("id", ""))
	# a press and its release must land on the same thing
	var now := _hit(p)
	if String(now.get("what", "")) != what or String(now.get("id", "")) != id:
		return
	match what:
		"pill":
			_pill_press(id)
		"chip":
			_chip_press(id)
		"out":
			_armed = "" if _armed == id else id
			_sel = ""
			_tray = {}
			_dirty = true
			_fx.touch(1.1 if _armed != "" else 0.9)
		"plus", "parts_plus":
			var want := {"parts": true} if what == "parts_plus" else {"after": id}
			_tray = {} if _tray == want else want
			_sel = ""
			_armed = ""
			_dirty = true
			_fx.touch(1.0 if not _tray.is_empty() else 0.9)
		"node":
			if _armed != "":
				var from := _armed
				_armed = ""
				_dirty = true
				if from != id:
					_wire_to(from, id)
				return
			_pick(id)
			_fx.touch()
		"part":
			_pick(PART_SEL + id)
			_fx.touch()
		"pane", "handle":
			if _sel != "" or not _tray.is_empty() or _armed != "":
				_sel = ""
				_tray = {}
				_armed = ""
				_dirty = true
				_fx.touch(0.84)

## The wire out of `from` into `to` (a node, or the body: the loop).
func _wire_to(from: String, to: String) -> void:
	_armed = ""
	_dirty = true
	if sim.set_next(robot, from, "out", to):
		_cue("wire")

## A tray chip let go on: a node into the wire the `+` was on, or a part
## fitted from the bin. A locked chip is a no.
func _chip_press(kind: String) -> void:
	if tray_locked(kind) and not _tray.has("parts"):
		_no()
		return
	if _tray.has("after"):
		var id: String = sim.add_node(robot, String(_tray.after), "out", kind)
		_tray = {}
		if id != "":
			_pick(id)
			_cue("node")
	else:
		# the sim says no to a part it will not fit (coins, later, fitted)
		if sim.fit(robot, kind):
			_tray = {}
			_cue("fit")
			Analytics.track("factory_part", {"part": kind})
	_dirty = true

# --- drawing ---

func _draw() -> void:
	var b := _bot()
	if b.is_empty():
		return
	if _paper == null:
		_paper = _bake_paper()
	draw_mesh(_paper, null)
	var lay := _layout()
	_pan = _clamp_pan(_pan)
	if _dirty or _graph == null:
		_dirty = false
		_labels = []
		_graph = _bake(b, lay)
	var off := _off()
	draw_mesh(_graph, null, Transform2D(0.0, off))
	# the running node breathes
	if String(b.stuck) == "" and lay.rects.has(String(b.pc)):
		var r: Rect2 = lay.rects[String(b.pc)]
		var a := 0.7 if Motion.reduce else 0.5 + 0.35 * sin(_clock * TAU / GLOW_S)
		draw_mesh(_glow(r.size, 40.0 if b.pc == Sim.BODY else ROUND), null, Transform2D(0.0, r.position + off), Color(1.0, 1.0, 1.0, a))
	_letter(_labels, off)
	if not _wire.is_empty() and lay.rects.has(String(_wire.from)):
		var r: Rect2 = lay.rects[String(_wire.from)]
		var a := Vector2(r.end.x, r.get_center().y) + off
		var z: Vector2 = _wire.at
		var wb := Face.Builder.new()
		var mx := (a.x + z.x) * 0.5
		var pts := Face.Builder.bezier3(a, Vector2(mx, a.y), Vector2(mx, z.y), z)
		pts.append(z)
		_dashed(wb, pts, 6.0, SEL, 16.0, 12.0)
		wb.disc(z, 12.0, SEL)
		_wire_mesh = wb.mesh()
		draw_mesh(_wire_mesh, null)
	if not _tray.is_empty():
		_draw_tray()
	elif _info and _sel == Sim.BODY:
		_draw_info(b)
	var pill := _pill_layout()
	if not pill.is_empty():
		_pill_ui.caps["lift"] = "FACTORY_TAKE_OFF" if _sel.begins_with(PART_SEL) else "FACTORY_REMOVE"
		_pill_ui.draw(self, pill, _pill_names(), _pill_title(), _font(), _clock, _sel_at, _btn_at, false)

func _font() -> Font:
	return get_theme_font("font", "SheetTitle")

## Words of `rows` ([text, at, fs, colour, align]) over everything, the
## large first and then the small, each size one glyph batch.
func _letter(rows: Array, off: Vector2) -> void:
	for fs: int in [FS, FS_SMALL]:
		for row: Array in rows:
			if int(row[2]) != fs:
				continue
			var line := _line(String(row[0]), fs)
			var at: Vector2 = (row[1] as Vector2) + off
			var w := line.get_line_width()
			var x := at.x - w * 0.5 if row.size() < 5 or int(row[4]) == 0 else at.x
			line.draw(get_canvas_item(), Vector2(x, at.y - line.get_line_ascent()), row[3])

func _line(text: String, fs: int) -> TextLine:
	var key := [text, fs]
	var line: TextLine = _lines.get(key)
	if line == null:
		if _lines.size() > 200:
			_lines = {}
		line = TextLine.new()
		line.add_string(text, _font(), fs)
		_lines[key] = line
	return line

## The paper, its lip and the handle, once a size.
func _bake_paper() -> ArrayMesh:
	var pb := Face.Builder.new()
	var w := size.x
	var h := size.y + 40.0
	pb.polygon(Face.Builder.round_rect(Vector2(0.0, -2.0), Vector2(w, h), 36.0), Color(INK, 0.12))
	pb.polygon(Face.Builder.round_rect(Vector2(0.0, 0.0), Vector2(w, h), 36.0), PAPER)
	pb.polygon(Face.Builder.round_rect(Vector2(w * 0.5 - 56.0, 24.0), Vector2(112.0, 12.0), 6.0), Color(INK, 0.18))
	pb.stroke(PackedVector2Array([Vector2(28.0, HANDLE_H - 1.0), Vector2(w - 28.0, HANDLE_H - 1.0)]), 2.0, Color(LINE, 0.7))
	return pb.mesh()

## A ring round a box of `box` with corners of `r`, for the glow.
func _glow(box: Vector2, r: float) -> ArrayMesh:
	var key := "%d|%d|%d" % [box.x, box.y, r]
	if not _glows.has(key):
		var gb := Face.Builder.new()
		gb.stroke(Face.Builder.round_rect(Vector2(-9.0, -9.0), box + Vector2(18.0, 18.0), r + 9.0), 12.0, Color(LIVE, 0.55), true)
		gb.stroke(Face.Builder.round_rect(Vector2(-3.0, -3.0), box + Vector2(6.0, 6.0), r + 3.0), 5.0, LIVE, true)
		_glows[key] = gb.mesh()
	return _glows[key]

## The graph of robot `b` laid out as `lay`, unpanned, as one mesh; its words
## go into `_labels`.
func _bake(b: Dictionary, lay: Dictionary) -> ArrayMesh:
	var gb := Face.Builder.new()
	var cy: float = lay.cy
	var lane: float = lay.lane
	var rects: Dictionary = lay.rects
	var ids: Array = lay.ids
	var order := [Sim.BODY] + ids
	_grid(gb, Rect2(0.0, HANDLE_H, maxf(float(lay.width), size.x), _pane().size.y + TRAY_H + _inset))
	# the parts' dashed wires first, under the body
	var bcx := LEFT + BODY * 0.5
	var bus: float = lay.bus
	var foot := cy + BODY * 0.5
	var drops: Array = (lay.parts as Array).duplicate()
	drops.append(lay.parts_plus)
	for r: Rect2 in drops:
		var px := r.get_center().x
		var pts := PackedVector2Array([Vector2(bcx, foot)])
		if absf(px - bcx) < 1.0:
			pts.append(Vector2(bcx, r.position.y))
		else:
			pts.append(Vector2(bcx, bus - CORNER))
			pts.append_array(Face.Builder.arc_points(Vector2(bcx + CORNER, bus - CORNER), CORNER, PI, PI * 0.5))
			pts.append_array(Face.Builder.arc_points(Vector2(px - CORNER, bus + CORNER), CORNER, -PI * 0.5, 0.0))
			pts.append(Vector2(px, r.position.y))
		_dashed(gb, pts, 4.5, WIRE, 12.0, 10.0)
	_labels.append([tr("FACTORY_PARTS"), Vector2(bcx + 19.0, foot + BUS * 0.62), FS_SMALL, MUTED, 1])
	# the wires
	for k in order.size():
		var id: String = order[k]
		var out := String(b.next.get(id, {}).get("out", ""))
		if out == "" or not rects.has(out):
			continue
		var r: Rect2 = rects[id]
		var a := Vector2(r.end.x, cy)
		var to: Rect2 = rects[out]
		var z := Vector2(to.position.x, cy)
		var pts := PackedVector2Array()
		if out == Sim.BODY or to.position.x <= a.x:
			var up := a.x + RISE
			var down := to.position.x - LOOP_IN
			pts.append(a)
			pts.append_array(Face.Builder.arc_points(Vector2(up - CORNER, cy - CORNER), CORNER, PI * 0.5, 0.0))
			pts.append_array(Face.Builder.arc_points(Vector2(up - CORNER, lane + CORNER), CORNER, 0.0, -PI * 0.5))
			pts.append_array(Face.Builder.arc_points(Vector2(down + CORNER, lane + CORNER), CORNER, -PI * 0.5, -PI))
			pts.append_array(Face.Builder.arc_points(Vector2(down + CORNER, cy - CORNER), CORNER, PI, PI * 0.5))
			pts.append(z - Vector2(8.0, 0.0))
			if out == Sim.BODY:
				_labels.append([tr("FACTORY_AGAIN"), Vector2((up + down) * 0.5, lane - 16.0), FS_SMALL, MUTED])
		elif k + 1 < order.size() and order[k + 1] == out:
			pts = PackedVector2Array([a, z - Vector2(8.0, 0.0)])
		else:
			for s in 25:
				pts.append(_arch_at(a, z, lane, s / 24.0))
		gb.stroke(pts, 5.0, WIRE)
		var tip: Vector2 = pts[pts.size() - 1]
		gb.polygon(PackedVector2Array([tip + Vector2(-13.0, -11.0), tip + Vector2(5.0, 0.0), tip + Vector2(-13.0, 11.0)]), WIRE)
	# the boxes
	_body(gb, b, rects[Sim.BODY])
	for id: String in ids:
		_node(gb, b, id, rects[id])
	# the ports
	for id: String in order:
		var r: Rect2 = rects[id]
		gb.polygon(Face.Builder.round_rect(Vector2(r.position.x - BAR.x * 0.5, cy - BAR.y * 0.5), BAR, 4.0), WIRE)
		var out := String(b.next.get(id, {}).get("out", ""))
		var at := Vector2(r.end.x, cy)
		var c := WIRE
		if id == _armed:
			c = SEL
		elif out == "" or not rects.has(out):
			c = RED
		if c != WIRE:
			gb.disc(at, DOT_R + 9.0, Color(c, 0.3))
		gb.disc(at, DOT_R, c)
	# the `+`s
	for id: String in lay.plus:
		var p: Dictionary = lay.plus[id]
		_plus(gb, p.rect, bool(p.disc), _tray.get("after", "") == id)
	_plus(gb, lay.parts_plus, false, _tray.has("parts"))
	# the parts
	for i in (lay.parts as Array).size():
		_part(gb, String(b.parts[i]), lay.parts[i], _sel == PART_SEL + str(i))
	return gb.mesh()

## Dots a GRID apart over `area`, as plain quads (no feather: a feathered
## dot is nine vertices, and there are hundreds).
func _grid(gb: Face.Builder, area: Rect2) -> void:
	var half := 2.5
	var x0 := area.position.x + GRID * 0.5
	var y0 := area.position.y + GRID * 0.5
	var cols := int(area.size.x / GRID)
	var rows := int(area.size.y / GRID)
	var vs := PackedVector2Array()
	var ix := PackedInt32Array()
	vs.resize(cols * rows * 4)
	ix.resize(cols * rows * 6)
	var base := gb.verts.size()
	var w := 0
	for i in cols:
		for j in rows:
			var c := Vector2(x0 + i * GRID, y0 + j * GRID)
			var v := w * 4
			vs[v] = c + Vector2(-half, -half)
			vs[v + 1] = c + Vector2(half, -half)
			vs[v + 2] = c + Vector2(half, half)
			vs[v + 3] = c + Vector2(-half, half)
			var t := w * 6
			ix[t] = base + v
			ix[t + 1] = base + v + 1
			ix[t + 2] = base + v + 2
			ix[t + 3] = base + v
			ix[t + 4] = base + v + 2
			ix[t + 5] = base + v + 3
			w += 1
	var cs := PackedColorArray()
	cs.resize(vs.size())
	cs.fill(DOT)
	gb.verts.append_array(vs)
	gb.cols.append_array(cs)
	gb.idx.append_array(ix)

## A box's paper: a soft shadow, the white, the rim (blue picked, dashed and
## grey when its part is not fitted).
func _box(gb: Face.Builder, r: Rect2, rad: float, picked: bool, dead: bool) -> void:
	gb.polygon(Face.Builder.round_rect(r.position + Vector2(0.0, 6.0), r.size, rad), Color(INK, 0.1))
	var shape := Face.Builder.round_rect(r.position, r.size, rad)
	if picked:
		gb.stroke(Face.Builder.round_rect(r.position - Vector2(8.0, 8.0), r.size + Vector2(16.0, 16.0), rad + 8.0), 10.0, Color(SEL, 0.25), true)
	gb.polygon(shape, DEAD if dead else Color.WHITE)
	if dead:
		var ring := shape.duplicate()
		ring.append(shape[0])
		_dashed(gb, ring, 4.0, MUTED, 13.0, 10.0)
	else:
		gb.stroke(shape, 5.0 if picked else 4.0, SEL if picked else LINE, true)

func _body(gb: Face.Builder, b: Dictionary, r: Rect2) -> void:
	_box(gb, r, 40.0, _sel == Sim.BODY, false)
	var c := r.get_center()
	var tint: Color = Life.TINTS[robot % Life.TINTS.size()]
	var xf := Transform2D(0.0, Vector2(0.86, 0.86) * K, 0.0, c + Vector2(0.0, 8.0))
	gb.append(Art.robot(), xf, tint)
	gb.append(Art.face(String(b.stuck)), xf)
	# the bolt: the bay is where a loop charges
	var bolt := r.position + Vector2(5.0, 5.0)
	gb.disc(bolt + Vector2(0.0, 3.0), 25.0, Color(INK, 0.12))
	gb.disc(bolt, 25.0, LIVE)
	Art._bolt(gb, bolt, 0.95 * K, Color.WHITE)
	# the parts' diamond port
	_diamond(gb, Vector2(c.x, r.end.y), 12.0, SEL)
	_labels.append([_robot_name(b), Vector2(c.x, r.position.y - 19.0), FS, INK])

func _node(gb: Face.Builder, b: Dictionary, id: String, r: Rect2) -> void:
	var node: Dictionary = b.nodes[id]
	var kind := String(node.kind)
	var dead: bool = not Bots.can(b, kind)
	_box(gb, r, ROUND, _sel == id, dead)
	var ink := MUTED if dead else INK
	var c := r.get_center()
	if kind == "move":
		var d := Vector2(Sim.DIRS[int(node.facing)])
		var ac := c + Vector2(-29.0, 0.0)
		var tail := ac - d * 29.0
		var head := ac + d * 29.0
		var side := Vector2(-d.y, d.x)
		gb.stroke(PackedVector2Array([tail, head - d * 5.0]), 10.0, ink)
		gb.stroke(PackedVector2Array([head - d * 20.0 + side * 20.0, head, head - d * 20.0 - side * 20.0]), 10.0, ink)
		_digit(gb, int(node.n), Rect2(c + Vector2(27.0, -29.0), Vector2(35.0, 59.0)), 9.0, ink)
	else:
		_hand(gb, kind == "pick", c, 2.5 * K, ink)
	_labels.append([tr(String(NODE_KEY.get(kind, kind))), Vector2(c.x, r.end.y + 40.0), FS, ink])
	if dead:
		var part := String(Sim.NODES[kind].part)
		_labels.append([tr("FACTORY_NEEDS") % tr(String(PART_KEY.get(part, part))), Vector2(c.x, r.end.y + 72.0), FS_SMALL, RED])

## The prototype's claw over a box: closing (Pick) or open (Release), from a
## 22-unit drawing scaled `s` about `c`.
static func _hand(gb: Face.Builder, pick: bool, c: Vector2, s: float, ink: Color) -> void:
	var o := c - Vector2(11.0, 12.0) * s
	var w := 2.2 * s
	var knee := Vector2(11.0, 9.0 if pick else 8.0)
	gb.stroke(PackedVector2Array([o + Vector2(11.0, 3.0) * s, o + knee * s]), w, ink)
	var l := Vector2(6.0, 14.0) if pick else Vector2(5.0, 11.0)
	var rr := Vector2(16.0, 14.0) if pick else Vector2(17.0, 11.0)
	gb.stroke(PackedVector2Array([o + l * s, o + knee * s, o + rr * s]), w, ink)
	gb.polygon(Face.Builder.round_rect(o + Vector2(7.0, 16.0) * s, Vector2(8.0, 5.0) * s, 1.5 * s), ink)

## Count `n` (1..9) stroked into `rect`.
static func _digit(gb: Face.Builder, n: int, rect: Rect2, w: float, ink: Color) -> void:
	var to := func(x: float, y: float) -> Vector2: return rect.position + Vector2(x, y) * rect.size
	for line: Array in DIGITS.get(clampi(n, 1, 9), []):
		var pts := PackedVector2Array()
		var closed := false
		for bit: Array in line:
			if bit[0] is String:
				match String(bit[0]):
					"arc":
						for p in Face.Builder.arc_points(Vector2(bit[1], bit[2]), 1.0, float(bit[4]) * PI, float(bit[5]) * PI):
							pts.append(to.call(bit[1] + (p.x - bit[1]) * bit[3], bit[2] + (p.y - bit[2]) * bit[3]))
					"ring":
						for p in Face.Builder.ring(Vector2(bit[1], bit[2]), bit[3], bit[4], 40.0):
							pts.append(to.call(p.x, p.y))
						closed = true
					"q":
						var last: Vector2 = pts[pts.size() - 1]
						for p in Face.Builder.bezier2(last, to.call(bit[1], bit[2]), to.call(bit[3], bit[4])):
							pts.append(p)
						pts.append(to.call(bit[3], bit[4]))
			else:
				pts.append(to.call(float(bit[0]), float(bit[1])))
		gb.stroke(pts, w, ink, closed)

static func _diamond(gb: Face.Builder, c: Vector2, r: float, col: Color) -> void:
	gb.polygon(PackedVector2Array([c + Vector2(0.0, -r), c + Vector2(r, 0.0), c + Vector2(0.0, r), c + Vector2(-r, 0.0)]), col)

## A `+`: a rounded box (past a loose output, the parts') or a disc (on a
## wire), blue while its tray is up.
static func _plus(gb: Face.Builder, r: Rect2, disc: bool, hot: bool) -> void:
	var c := r.get_center()
	var ink := SEL if hot else WIRE
	var arm := r.size.x * 0.24
	if disc:
		gb.disc(c, r.size.x * 0.5 + 3.0, ink)
		gb.disc(c, r.size.x * 0.5 - 1.0, PAPER)
	else:
		var shape := Face.Builder.round_rect(r.position, r.size, 12.0)
		gb.polygon(shape, PAPER)
		gb.stroke(shape, 4.0, ink, true)
	gb.stroke(PackedVector2Array([c - Vector2(arm, 0.0), c + Vector2(arm, 0.0)]), 4.5, ink)
	gb.stroke(PackedVector2Array([c - Vector2(0.0, arm), c + Vector2(0.0, arm)]), 4.5, ink)

## Part `part` in its disc, with its name and what it gives under.
func _part(gb: Face.Builder, part: String, r: Rect2, picked: bool) -> void:
	var c := r.get_center()
	_box(gb, r, PART * 0.5, picked, false)
	_diamond(gb, Vector2(c.x, r.position.y), 11.0, SEL)
	# drawn at the spec's size and grown K, as one piece
	var pg := Face.Builder.new()
	_part_glyph(pg, part, Vector2.ZERO, INK)
	gb.append(pg.mesh(), Transform2D(0.0, Vector2(K, K), 0.0, c))
	_labels.append([tr(String(PART_KEY.get(part, part))), Vector2(c.x, r.end.y + 37.0), FS_SMALL, INK])
	var gives: Array = []
	for kind: String in Sim.PARTS.get(part, {}).get("gives", []):
		gives.append(tr(String(NODE_KEY.get(kind, kind))))
	if not gives.is_empty():
		_labels.append([", ".join(gives), Vector2(c.x, r.end.y + 67.0), FS_SMALL, MUTED])

## A part's mark, about 48 across: treads, a claw, a cell, the fast treads'
## lines, a plug.
static func _part_glyph(gb: Face.Builder, part: String, c: Vector2, ink: Color) -> void:
	match part:
		"treads", "fast":
			var track := Face.Builder.round_rect(c + Vector2(-24.0, -10.0), Vector2(48.0, 22.0), 11.0)
			gb.stroke(track, 4.5, ink, true)
			for k in 3:
				gb.disc(c + Vector2(-12.0 + 12.0 * k, 1.0), 4.0, ink)
			if part == "fast":
				for k in 2:
					var x := -8.0 + 12.0 * k
					gb.stroke(PackedVector2Array([c + Vector2(x, -26.0), c + Vector2(x + 7.0, -19.0), c + Vector2(x, -12.0)]), 3.5, LIVE)
		"gripper":
			_hand(gb, true, c, 1.9, ink)
		"battery":
			gb.stroke(Face.Builder.round_rect(c + Vector2(-22.0, -12.0), Vector2(40.0, 24.0), 5.0), 4.0, ink, true)
			gb.polygon(Face.Builder.round_rect(c + Vector2(19.0, -5.0), Vector2(6.0, 10.0), 2.0), ink)
			Art._bolt(gb, c + Vector2(-2.0, 0.0), 0.75, LIVE)
		"plug":
			gb.polygon(Face.Builder.round_rect(c + Vector2(-13.0, -8.0), Vector2(26.0, 20.0), 6.0), ink)
			gb.stroke(PackedVector2Array([c + Vector2(-6.0, -8.0), c + Vector2(-6.0, -20.0)]), 4.5, ink)
			gb.stroke(PackedVector2Array([c + Vector2(6.0, -8.0), c + Vector2(6.0, -20.0)]), 4.5, ink)
			gb.stroke(PackedVector2Array([c + Vector2(0.0, 12.0), c + Vector2(0.0, 22.0)]), 4.0, ink)
			Art._bolt(gb, c + Vector2(0.0, 2.0), 0.45, LIVE)
		_:
			gb.disc(c, 10.0, ink)

## A dashed line along `pts`: dashes of `dash`, gaps of `gap`.
static func _dashed(gb: Face.Builder, pts: PackedVector2Array, w: float, col: Color, dash: float, gap: float) -> void:
	if pts.size() < 2:
		return
	var on := true
	var left := dash
	var cur := PackedVector2Array([pts[0]])
	for i in range(1, pts.size()):
		var a := pts[i - 1]
		var z := pts[i]
		var seg := a.distance_to(z)
		var t := 0.0
		while seg - t > left:
			t += left
			var q := a.lerp(z, t / seg)
			if on:
				cur.append(q)
				gb.stroke(cur, w, col, false, false)
			else:
				cur = PackedVector2Array([q])
			on = not on
			left = dash if on else gap
		left -= seg - t
		if on:
			cur.append(z)
	if on and cur.size() >= 2:
		gb.stroke(cur, w, col, false, false)

## The band at the foot: the paper lifted over the pane, once a size.
func _band_mesh() -> ArrayMesh:
	if _band == null:
		var bb := Face.Builder.new()
		var r := _band_rect()
		bb.polygon(Face.Builder.round_rect(r.position + Vector2(0.0, -6.0), r.size + Vector2(0.0, 40.0), 26.0), Color(INK, 0.1))
		bb.polygon(Face.Builder.round_rect(r.position, r.size + Vector2(0.0, 40.0), 26.0), PAPER)
		bb.stroke(PackedVector2Array([Vector2(24.0, r.position.y), Vector2(size.x - 24.0, r.position.y)]), 2.0, LINE)
		_band = bb.mesh()
	return _band

## The tray: its title and a chip a node kind or a part, the locked dim with
## what they need, the bin's with "in the bin", a price or "later". Baked
## again only when what it shows changes.
func _draw_tray() -> void:
	var rows := _tray_rows()
	var key := str(rows) + str(_tray)
	if key != _tray_key or _tray_mesh == null:
		_tray_key = key
		var tb := Face.Builder.new()
		_tray_words = []
		var band := _band_rect()
		_tray_words.append([tr("FACTORY_ADD_NODE" if _tray.has("after") else "FACTORY_FIT_PART"), Vector2(37.0, band.position.y + 33.0), FS_SMALL, MUTED, 1])
		for k in rows.size():
			var row: Array = rows[k]
			var r := _chip_at(k, rows.size())
			var locked := bool(row[1])
			var shape := Face.Builder.round_rect(r.position, r.size, 21.0)
			tb.polygon(Face.Builder.round_rect(r.position + Vector2(0.0, 5.0), r.size, 21.0), Color(INK, 0.1 if not locked else 0.04))
			tb.polygon(shape, Color("f1ebdf") if locked else Color.WHITE)
			tb.stroke(shape, 4.0, LINE, true)
			var what := String(row[0])
			var title := tr(String(NODE_KEY.get(what, PART_KEY.get(what, what))))
			var sub := String(row[2])
			var col := Color(INK, 0.45) if locked else INK
			var c := r.get_center()
			var y := c.y + (-5.0 if sub != "" else 11.0)
			_tray_words.append([title, Vector2(c.x, y), FS, col])
			if sub.begins_with("$"):
				var price := sub.substr(1)
				var tw := _line(price, FS_SMALL).get_line_width()
				Art._coin_into(tb, Vector2(c.x - tw * 0.5 - 8.0, c.y + 23.0), 12.0)
				_tray_words.append([price, Vector2(c.x + 13.0, c.y + 31.0), FS_SMALL, Color(MUTED, 0.6 if locked else 1.0)])
			elif sub != "":
				_tray_words.append([sub, Vector2(c.x, c.y + 31.0), FS_SMALL, RED if _tray.has("after") and locked else Color(MUTED, 0.8)])
		_tray_mesh = tb.mesh()
	draw_mesh(_band_mesh(), null)
	draw_mesh(_tray_mesh, null)
	_letter(_tray_words, Vector2.ZERO)

## The body's battery line in the band: the charge, the loop's cost and the
## pause it buys on the bay; flat away from the bay, said so.
func _draw_info(b: Dictionary) -> void:
	draw_mesh(_band_mesh(), null)
	var band := _band_rect()
	var cost: int = Bots.cost(b)
	# the pause in tenths, with the decimal comma where the language writes one
	var pause := Art.amount(snappedf(cost * Sim.TICK / maxf(1.0, Bots.rate(b)), 0.1), Art.comma())
	var line := tr("FACTORY_BATTERY_LINE") % [int(b.charge), Bots.cell(b), cost, pause]
	var rows: Array = [[line, Vector2(size.x * 0.5, band.position.y + 67.0), FS, INK]]
	if String(b.stuck) == "flat":
		rows.append([tr("FACTORY_FLAT"), Vector2(size.x * 0.5, band.position.y + 109.0), FS_SMALL, RED])
	_letter(rows, Vector2.ZERO)
