extends Control

## Trivet's table: the tray of places, the stacks on it, the hand on its
## cloth, the two tools and the fingers on them. It draws
## arcade/trivet_sim.gd and hands it the player's moves; the screen round it
## (arcade/trivet_screen.gd) keeps the score, the sound and the cards, and a
## tutorial page (ui/hud/trivet_tutorial_diagram.gd) is this table alone
## with a hand scripted on it.
##
## **The table is the whole field** (the house's pattern since 2026-10-10):
## the planks run edge to edge and the screen's bar and plates lie over
## them. `top_band` and `foot_band` say how much of the field they cover.
##
## **What is shown runs behind the sim.** A move is settled in the sim at
## once and told as events; the table plays them one after another on its
## own clock (`_queue`), each mat hopping in its turn, and says what it has
## got to with `beat` so a sound is heard when its mat lands. `shown_score`
## and `shown_level` are the score as far as the table has shown it. A stack
## may be set down while the last move is still playing: on a place empty
## both in the sim and on the table.
##
## Drawing: the table and the tray are still meshes built on resize; a stack
## is one mesh held until its mats change (`_mesh`), laid by its transform;
## a mat in the air is its colour's one mesh; lights, rings and motes are
## one live mesh. Nothing is keyed by a size.

## Something the table has just shown or the player has just done: `what`
## and what it was about (the screen plays it).
signal beat(what: String, data: Dictionary)

const Sim = preload("res://arcade/trivet_sim.gd")
const Art = preload("res://arcade/trivet_art.gd")
const Face = preload("res://ui/faces/face.gd")
const Motion = preload("res://core/motion.gd")
const CozyTheme = preload("res://ui/theme.gd")

## A mat's half width at most, in the field's pixels.
const U_MOST := 112.0
## The cloth's band at the field's foot and the room beside it.
const FOOT := 330.0
const SIDE := 40.0
const TOOL_R := 62.0
## A hop from stack to stack: each mat leaves HOP_GAP after the last, is
## HOP_T in the air and rises HOP_UP of a mat's width at the middle.
const HOP_GAP := 0.07
const HOP_T := 0.26
const HOP_UP := 0.9
## A stack put away: it swells for SWELL_T, then its mats go one every
## POP_GAP from the top, each POP_T leaving.
const SWELL_T := 0.2
const SWELL := 0.1
const POP_GAP := 0.045
const POP_T := 0.3
## A stack set down or added to swells by this and settles.
const LAND_BUMP := 0.1
const LAND_T := 0.26
## A stack carried stands this much larger, this far above the finger (in
## mat widths), and leans into the way it is taken.
const CARRY_SWELL := 0.08
const CARRY_UP := 1.25
const LEAN_MOST := 0.12
const EASE := 18.0
## How far a finger moves before a press is a carry and not a tap.
const CARRY_AFTER := 18.0
## A place takes a stack let go within this many mat widths of its middle.
const REACH := 1.0
const DEAL_STEP := 0.07
const LID_T := 0.5
const MOTES := 9

var sim: RefCounted
var interactive := true
## How much of the field the screen's bar and plates cover, and its foot.
var top_band := 0.0
var foot_band := 0.0
## The score and the level as far as the table has shown them.
var shown_score := 0
var shown_level := 1
## Which tool is armed: "" or "sweep".
var armed := ""
## The cloth, the tools and the margins at this much of their size: a
## tutorial page's table is a third of the screen's.
var ui := 1.0

var _u := 100.0
var _mid := Vector2.ZERO
var _hand_u := 90.0
var _cloth := Rect2()
var _table: ArrayMesh
var _tray: ArrayMesh
var _live: ArrayMesh
var _clock := 0.0
## The places from the back of the tray to the front, for drawing.
var _order: Array[int] = []
## What lies on each place as shown, its mesh, and when it last took a mat.
var _shown: Array = []
var _mesh: Array = []
var _bump: PackedFloat32Array
var _swell: PackedFloat32Array
var _lidded: Array = []
## The hand as shown, its meshes, and when each stack was dealt.
var _hand: Array = [[], [], []]
var _hand_mesh: Array = [null, null, null]
var _dealt: PackedFloat32Array = [-10.0, -10.0, -10.0]
## The sim's events still to show, and when the next may begin.
var _queue: Array = []
var _next_at := 0.0
## Mats in the air: {col, from, to (cells), at (when it leaves), k, n}.
var _fly: Array = []
## Mats leaving a stack put away: {col, pos (field pixels), at}.
var _pops: Array = []
## Stacks swept off and lids lifted: {mesh, pos, at, kind}.
var _ghosts: Array = []
## Rings and motes: {kind, pos, at, life, col, seed}.
var _bits: Array = []
## The carry: the hand's slot (-1 none), where the finger is, where the
## stack is drawn, and the slot a tap picked up.
var _held := -1
var _finger := Vector2.ZERO
var _held_at := Vector2.ZERO
var _lean := 0.0
var _down := false
var _press_at := Vector2.ZERO
var _moved := false
var _picked := -1
var _sink_at := -10.0
var _moves := 0
## The meshes a `_draw` handed over, held until the next.
var _shade: ArrayMesh
var _top_live: ArrayMesh
var _tight := false
var _font: Font

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP if interactive else Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_font = CozyTheme.display(700)
	resized.connect(layout)
	layout()

# --- the sim ---

## A fresh game: the table shows `game` as it stands.
func lay(game: RefCounted) -> void:
	sim = game
	_queue.clear()
	_fly.clear()
	_pops.clear()
	_ghosts.clear()
	_bits.clear()
	_held = -1
	_picked = -1
	_down = false
	armed = ""
	_sink_at = -10.0
	_tight = false
	var n: int = sim.cells.size()
	_shown.clear()
	_mesh.clear()
	_lidded.clear()
	_bump = PackedFloat32Array()
	_bump.resize(n)
	_bump.fill(-10.0)
	_swell = PackedFloat32Array()
	_swell.resize(n)
	_swell.fill(-10.0)
	for i in n:
		_shown.append((sim.stacks[i] as Array).duplicate())
		_mesh.append(Art.stack(_shown[i], Sim.run_of(_shown[i]) >= 2))
		_lidded.append(bool(sim.closed[i]))
	_order.clear()
	for i in n:
		_order.append(i)
	_order.sort_custom(func(a: int, b: int) -> bool:
		var pa := Art.place_of(sim.cells[a])
		var pb := Art.place_of(sim.cells[b])
		return pa.y < pb.y if not is_equal_approx(pa.y, pb.y) else pa.x < pb.x)
	shown_score = sim.score
	shown_level = sim.level
	for i in Sim.HAND:
		_hand[i] = []
		_hand_mesh[i] = null
	_tray = null
	layout()
	play()

## The sim's new events onto the end of what is still to be shown.
func play() -> void:
	if sim == null:
		return
	for ev: Dictionary in sim.events:
		_queue.append(ev)
	sim.events.clear()

## Whether everything the sim has done has been shown.
func settled() -> bool:
	return _queue.is_empty() and _fly.is_empty() and _pops.is_empty() and _clock >= _next_at

# --- the layout ---

func layout() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var foot := foot_band + FOOT * ui
	var side := SIDE * ui
	var room := Rect2(side, top_band, size.x - side * 2.0, maxf(1.0, size.y - top_band - foot))
	# the screen's tray is 8.3 mat widths across and 7.2 deep, and a tall
	# stack at its back stands another mat width and a half over that
	var reach: int = sim.radius if sim != null else Sim.R
	var across := (3.0 * reach + 2.0) * 1.04 + 0.2
	var deep := sqrt(3.0) * (2.0 * reach + 1.0) * Art.SQ * 1.04 + 2.0
	_u = minf(U_MOST, minf(room.size.x / across, room.size.y / deep))
	_mid = room.get_center() + Vector2(0, _u * 0.6)
	var tools := _tool_r() * 2.0 + 28.0 * ui
	_cloth = Rect2(side + tools, size.y - foot + 22.0 * ui, size.x - side * 2.0 - tools, (FOOT - 44.0) * ui)
	_hand_u = minf(_u, minf(_cloth.size.x / 3.0 * 0.42, _cloth.size.y * 0.36))
	_table = Art.table(size, _mid - Vector2(0, _u), _u * 6.2, _cloth)
	if sim != null and _tray == null:
		_tray = Art.tray(sim.cells)
	queue_redraw()

## A place's foot in the field's pixels.
func place_px(cell: int) -> Vector2:
	return _mid + Art.place_of(sim.cells[cell]) * _u

## The top of the stack shown on `cell`.
func top_px(cell: int) -> Vector2:
	return place_px(cell) + Art.top_of((_shown[cell] as Array).size()) * (_u / Art.U)

## Where the hand's stack `slot` rests on the cloth.
func slot_px(slot: int) -> Vector2:
	return Vector2(_cloth.position.x + _cloth.size.x * (slot + 0.5) / Sim.HAND, _cloth.position.y + _cloth.size.y * 0.7)

func tool_px(which: String) -> Vector2:
	var r := _tool_r()
	var x := SIDE * ui + r
	var mid := _cloth.get_center().y
	return Vector2(x, mid - r - 12.0 * ui) if which == "sweep" else Vector2(x, mid + r + 12.0 * ui)

func _tool_r() -> float:
	return TOOL_R * ui

## The place a stack let go at `p` would be set on, or -1.
func place_under(p: Vector2, empty := true) -> int:
	var best := -1
	var best_d := REACH * _u
	for i in sim.cells.size():
		var d := (place_px(i) - p) / Vector2(1.0, Art.SQ)
		if d.length() < best_d:
			best_d = d.length()
			best = i
	if best >= 0 and empty and not (sim.can_place(best) and (_shown[best] as Array).is_empty() and not _lidded[best]):
		return -1
	return best

# --- the fingers ---

func _gui_input(event: InputEvent) -> void:
	if not interactive or sim == null:
		return
	if event is InputEventScreenTouch:
		if event.index != 0:
			return
		accept_event()
		if event.pressed:
			press(event.position)
		else:
			release(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		if event.pressed:
			press(event.position)
		else:
			release(event.position)
	elif event is InputEventScreenDrag:
		if event.index == 0 and _down:
			accept_event()
			drag(event.position)
	elif event is InputEventMouseMotion:
		if _down and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			accept_event()
			drag(event.position)

func _slot_at(p: Vector2) -> int:
	for i in Sim.HAND:
		if (_hand[i] as Array).is_empty() or (sim.hand[i] as Array).is_empty():
			continue
		var top := slot_px(i) + Art.top_of((_hand[i] as Array).size()) * (_hand_u / Art.U)
		var box := Rect2(slot_px(i).x - _hand_u * 1.15, top.y - _hand_u, _hand_u * 2.3, slot_px(i).y - top.y + _hand_u * 2.0)
		if box.has_point(p):
			return i
	return -1

func press(at: Vector2) -> void:
	if sim == null or sim.is_over():
		return
	_down = true
	_press_at = at
	_moved = false
	_finger = at
	for which: String in ["sweep", "deal"]:
		if at.distance_to(tool_px(which)) <= _tool_r() + 10.0:
			_down = false
			_tool(which)
			return
	if armed == "sweep":
		_down = false
		var cell := place_under(at + Vector2(0, _u * 0.3), false)
		# a tall stack is pressed on its top as often as on its foot
		if cell < 0 or (_shown[cell] as Array).is_empty():
			for i in sim.cells.size():
				if not (_shown[i] as Array).is_empty() and at.x > place_px(i).x - _u and at.x < place_px(i).x + _u \
						and at.y < place_px(i).y + _u * Art.SQ and at.y > top_px(i).y - _u * Art.SQ:
					cell = i
		armed = ""
		if cell >= 0 and settled() and sim.sweep(cell):
			play()
		else:
			beat.emit("disarm", {})
		return
	var slot := _slot_at(at)
	if slot >= 0:
		_held = slot
		_picked = -1
		_held_at = slot_px(slot)
		beat.emit("lift", {"slot": slot})
		return
	if _picked >= 0:
		var cell := place_under(at)
		_down = false
		if cell >= 0:
			_set_down(_picked, cell)
		else:
			beat.emit("back", {"slot": _picked})
		_picked = -1

func drag(at: Vector2) -> void:
	_finger = at
	if at.distance_to(_press_at) > CARRY_AFTER:
		_moved = true

func release(at: Vector2) -> void:
	if not _down:
		return
	_down = false
	_finger = at
	if _held < 0:
		return
	var slot := _held
	_held = -1
	if not _moved:
		# a tap picks the stack up: the next tap on a place sets it down
		_picked = slot
		return
	var cell := place_under(_carry_foot())
	if cell >= 0:
		_set_down(slot, cell)
	else:
		_dealt[slot] = _clock - 1.0
		beat.emit("back", {"slot": slot})

## The foot of the stack in the fingers.
func _carry_foot() -> Vector2:
	return _finger - Vector2(0, CARRY_UP * _u)

func _set_down(slot: int, cell: int) -> void:
	var stack: Array = (sim.hand[slot] as Array).duplicate()
	if not sim.place(slot, cell):
		beat.emit("back", {"slot": slot})
		return
	# on the table at once, whatever is still playing: the place is empty
	# both there and here
	_hand[slot] = []
	_hand_mesh[slot] = null
	_shown[cell] = stack
	_remesh(cell)
	_bump[cell] = _clock
	for ev: Dictionary in sim.events:
		if ev.type == "place":
			ev["seen"] = true
	_ring(place_px(cell), _u * 1.3, 0.4, Art.HALO)
	beat.emit("place", {"cell": cell, "n": stack.size()})
	play()

func _tool(which: String) -> void:
	_picked = -1
	if which == "sweep":
		if sim.sweeps <= 0:
			beat.emit("nope", {"tool": which})
		elif armed == "sweep":
			armed = ""
			beat.emit("disarm", {})
		else:
			armed = "sweep"
			beat.emit("arm", {})
		return
	armed = ""
	if sim.deals <= 0 or not settled():
		beat.emit("nope", {"tool": which})
	elif sim.redeal():
		beat.emit("redeal", {})
		play()

# --- the clock ---

func _process(delta: float) -> void:
	if sim == null:
		return
	_clock += delta
	if _held >= 0:
		var want := _carry_foot() if _moved else slot_px(_held) - Vector2(0, _u * 0.25)
		var was := _held_at
		_held_at = want if Motion.reduce else _held_at.lerp(want, minf(1.0, delta * EASE))
		_lean = lerpf(_lean, clampf((_held_at.x - was.x) / maxf(delta, 0.001) / 1800.0, -LEAN_MOST, LEAN_MOST), minf(1.0, delta * 10.0))
	else:
		_lean = 0.0
	_step_fly()
	_step_pops()
	while not _queue.is_empty() and _clock >= _next_at:
		_begin(_queue.pop_front())
	_ghosts = _ghosts.filter(func(g: Dictionary) -> bool: return _clock - float(g.at) < LID_T)
	_bits = _bits.filter(func(b: Dictionary) -> bool: return _clock - float(b.at) < float(b.life))
	queue_redraw()

## A stack's mesh again, after its mats changed. Two or more of a colour
## on top wear the count's button; one mat alone needs no telling.
func _remesh(cell: int) -> void:
	_mesh[cell] = Art.stack(_shown[cell], Sim.run_of(_shown[cell]) >= 2)

func _begin(ev: Dictionary) -> void:
	var quick := Motion.reduce
	match String(ev.type):
		"place":
			if not ev.has("seen"):
				_shown[int(ev.cell)] = (ev.stack as Array).duplicate()
				_remesh(int(ev.cell))
				_bump[int(ev.cell)] = _clock
				_hand[int(ev.slot)] = []
				_hand_mesh[int(ev.slot)] = null
				beat.emit("place", {"cell": int(ev.cell), "n": (ev.stack as Array).size()})
			_next_at = _clock + (0.0 if quick else 0.16)
		"move":
			var n := int(ev.n)
			_moves += 1
			for k in n:
				_fly.append({"col": int(ev.col), "from": int(ev.from), "to": int(ev.to), "at": _clock + (0.0 if quick else k * HOP_GAP), "k": k, "n": n, "id": _moves, "off": false})
			_next_at = _clock + (0.0 if quick else (n - 1) * HOP_GAP + HOP_T + 0.05)
			_step_fly()
		"clear":
			var cell := int(ev.cell)
			var n := int(ev.n)
			_swell[cell] = _clock
			var lead := 0.0 if quick else SWELL_T
			for k in n:
				_pops.append({"cell": cell, "col": int(ev.col), "at": _clock + lead + (0.0 if quick else k * POP_GAP), "k": k, "n": n, "ev": ev, "off": false})
			_next_at = _clock + (0.05 if quick else lead + n * POP_GAP + 0.22)
			beat.emit("gather", {"cell": cell, "col": int(ev.col), "n": n, "chain": int(ev.chain)})
			_step_pops()
		"level":
			shown_level = int(ev.n)
			var open := int(ev.open)
			if open >= 0:
				_lidded[open] = false
				_ghosts.append({"mesh": Art.lid(), "pos": place_px(open), "at": _clock, "kind": "lid"})
				_ring(place_px(open), _u * 1.5, 0.6, Art.HALO)
			beat.emit("level", ev)
			_next_at = _clock + (0.0 if quick else 0.3)
		"deal":
			for i in Sim.HAND:
				_hand[i] = (ev.hand[i] as Array).duplicate()
				_hand_mesh[i] = Art.stack(_hand[i])
				_dealt[i] = _clock + i * DEAL_STEP
			beat.emit("deal", {"fresh": bool(ev.fresh)})
		"sweep":
			var cell := int(ev.cell)
			_ghosts.append({"mesh": _mesh[cell], "pos": place_px(cell), "at": _clock, "kind": "sweep"})
			for k in 8:
				_mote(top_px(cell), Art.CLOTH, 0.6)
			_shown[cell] = []
			_remesh(cell)
			beat.emit("sweep", {"cell": cell})
		"revive":
			for cell: int in ev.cells:
				_ghosts.append({"mesh": _mesh[cell], "pos": place_px(cell), "at": _clock, "kind": "sweep"})
				_ring(place_px(cell), _u * 1.4, 0.5, Art.HALO)
				_shown[cell] = []
				_remesh(cell)
			_sink_at = -10.0
			beat.emit("revive", {})
		"tight":
			beat.emit("tight", {})
		"full":
			beat.emit("full", {})
		"over":
			_sink_at = _clock
			beat.emit("over", {})
		"ready":
			beat.emit("ready", {})

func _step_fly() -> void:
	var keep: Array = []
	for f: Dictionary in _fly:
		var from := int(f.from)
		var to := int(f.to)
		if not f.off and _clock >= float(f.at):
			f.off = true
			# its foot, where it lay: a mat's thickness under the stack's top
			f["a"] = top_px(from) + Vector2(0, Art.TH * _u)
			var s: Array = _shown[from]
			if not s.is_empty():
				s.pop_back()
			_remesh(from)
		if f.off and (Motion.reduce or _clock >= float(f.at) + HOP_T):
			(_shown[to] as Array).append(int(f.col))
			_remesh(to)
			_bump[to] = _clock
			beat.emit("hop", {"cell": to, "col": int(f.col), "k": int(f.k), "n": int(f.n)})
		else:
			keep.append(f)
	_fly = keep

func _step_pops() -> void:
	var keep: Array = []
	for p: Dictionary in _pops:
		var cell := int(p.cell)
		if not p.off and _clock >= float(p.at):
			p.off = true
			p["pos"] = top_px(cell)
			var s: Array = _shown[cell]
			if not s.is_empty():
				s.pop_back()
			_remesh(cell)
			_mote(p.pos, Art.FELT[int(p.col)], 0.55)
			beat.emit("pop", {"cell": cell, "col": int(p.col), "k": int(p.k), "n": int(p.n), "at": p.pos})
			if int(p.k) == int(p.n) - 1:
				var ev: Dictionary = p.ev
				shown_score += int(ev.pts)
				_ring(place_px(cell), _u * 1.7, 0.55, Art.FELT[int(p.col)].lightened(0.3))
				for k in 10:
					_mote(place_px(cell) - Vector2(0, _u * 0.3), Art.FELT[int(p.col)].lightened(0.2), 0.8)
				beat.emit("clear", {"cell": cell, "col": int(ev.col), "n": int(ev.n), "chain": int(ev.chain), "pts": int(ev.pts), "at": place_px(cell)})
		if p.off and _clock >= float(p.at) + POP_T:
			continue
		keep.append(p)
	_pops = keep

func _ring(pos: Vector2, r: float, life: float, col: Color) -> void:
	if not Motion.reduce:
		_bits.append({"kind": "ring", "pos": pos, "at": _clock, "life": life, "col": col, "r": r, "seed": 0.0})

func _mote(pos: Vector2, col: Color, life: float) -> void:
	if not Motion.reduce:
		_bits.append({"kind": "mote", "pos": pos, "at": _clock, "life": life * randf_range(0.8, 1.2), "col": col, "r": randf_range(4.0, 9.0), "seed": randf() * TAU})

# --- drawing ---

func _stack_xf(pos: Vector2, u: float, sx := 1.0, sy := 1.0, turn := 0.0) -> Transform2D:
	var s := u / Art.U
	return Transform2D(turn, Vector2(s * sx, s * sy), 0.0, pos)

func _draw() -> void:
	if _table == null:
		layout()
	if _table == null or sim == null:
		return
	draw_mesh(_table, null)
	if _tray != null:
		draw_mesh(_tray, null, _stack_xf(_mid, _u))
	var b := Face.Builder.new()
	_lights_into(b)
	_live = b.mesh()
	if _live != null and b.verts.size() > 0:
		draw_mesh(_live, null)
	var s := _u / Art.U
	var sinking := _clock - _sink_at
	for i: int in _order:
		var at := place_px(i)
		if _lidded[i]:
			draw_mesh(Art.lid(), null, _stack_xf(at, _u))
			continue
		var m: ArrayMesh = _mesh[i]
		if m == null:
			continue
		var grow := Motion.bump_scale(_clock - _bump[i], LAND_BUMP, LAND_T)
		var sw := _clock - _swell[i]
		if sw >= 0.0 and sw < SWELL_T and not Motion.reduce:
			grow += SWELL * sin(sw / SWELL_T * PI * 0.5)
		var sy := grow
		var sx := 2.0 - grow if grow > 1.0 else 1.0
		if sinking >= 0.0 and sinking < 0.9 and not Motion.reduce:
			# the run over: the stacks sink one after another and stay a little low
			var k := clampf((sinking - 0.02 * _order.find(i)) / 0.5, 0.0, 1.0)
			sy *= 1.0 - 0.07 * sin(k * PI)
		var turn := 0.0
		if armed == "sweep" and not Motion.reduce:
			turn = 0.025 * sin(_clock * 9.0 + i)
		draw_mesh(m, null, _stack_xf(at, _u, lerpf(1.0, sx, 0.5), sy, turn))
		var n: int = (_shown[i] as Array).size()
		var run := Sim.run_of(_shown[i])
		if run >= 2:
			_count(at + Art.tag_at(n) * s * Vector2(1.0, sy), run, s)
	# ghosts: a lid lifted, a stack swept off
	for g: Dictionary in _ghosts:
		var k := clampf((_clock - float(g.at)) / LID_T, 0.0, 1.0)
		var pos: Vector2 = g.pos
		if g.kind == "lid":
			draw_mesh(g.mesh, null, _stack_xf(pos - Vector2(0, _u * 1.4 * Motion.back_out(k)), _u, 1.0 + 0.2 * k, 1.0 + 0.2 * k, 0.5 * k), Color(1, 1, 1, 1.0 - k * k))
		else:
			draw_mesh(g.mesh, null, _stack_xf(pos + Vector2(_u * 2.2 * k * k, -_u * 0.3 * k), _u, 1.0, 1.0, 0.3 * k), Color(1, 1, 1, 1.0 - k))
	# mats leaving a stack put away: up, smaller, gone
	for p: Dictionary in _pops:
		if not p.off:
			continue
		var k := clampf((_clock - float(p.at)) / POP_T, 0.0, 1.0)
		var sc := (1.0 + 0.25 * sin(k * PI)) * (1.0 - k * k)
		draw_mesh(Art.mat(int(p.col)), null, _stack_xf(p.pos + Vector2(0, Art.TH * _u - _u * 1.1 * k), _u, sc, sc, 0.0), Color(1, 1, 1, 1.0 - k * k * k))
	# mats in the air, over everything that lies
	for f: Dictionary in _fly:
		if not f.off:
			continue
		var k := clampf((_clock - float(f.at)) / HOP_T, 0.0, 1.0)
		var e := k * k * (3.0 - 2.0 * k)
		var from: Vector2 = f.a
		var to := top_px(int(f.to)) - Vector2(0, Art.TH * _u * _landing(int(f.to), f))
		var pos := from.lerp(to, e) - Vector2(0, sin(k * PI) * HOP_UP * _u)
		# it turns over on its way: flat at the middle of the hop
		var flip := absf(cos(k * PI))
		draw_mesh(Art.mat(int(f.col)), null, _stack_xf(pos, _u, 1.0 + 0.06 * sin(k * PI), lerpf(0.25, 1.0, flip), 0.0))
	_draw_hand()
	_draw_tools()
	var top := Face.Builder.new()
	_bits_into(top)
	if top.verts.size() > 0:
		_top_live = top.mesh()
		draw_mesh(_top_live, null)

## How many mats of the same hop are still to land on `cell` before `f`.
func _landing(cell: int, f: Dictionary) -> int:
	var n := 0
	for o: Dictionary in _fly:
		if o.off and int(o.to) == cell and int(o.id) == int(f.id) and int(o.k) < int(f.k):
			n += 1
	return n

func _count(at: Vector2, n: int, s: float) -> void:
	var fs := int(maxf(12.0, 36.0 * s))
	var text := str(n)
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(_font, at + Vector2(-w * 0.5, fs * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Art.INK)

## Under the stacks: the place a carried stack would take, the places left
## when the tray is tight, the stacks a brush may take.
func _lights_into(b: Face.Builder) -> void:
	if Motion.reduce == false:
		for k in MOTES:
			# dust in the lamp's light, slow and soft
			var t := _clock * 0.05 + k * 0.37
			var p := _mid + Vector2(sin(t * 2.3 + k) * _u * 3.6, cos(t * 1.7 + k * 2.0) * _u * 2.6 - _u)
			b.disc(p, 5.0 + 3.0 * sin(k * 1.3), Color(Art.LAMP, 0.1 + 0.06 * sin(_clock * 0.7 + k)))
	var aim := -1
	if _held >= 0 and _moved:
		aim = place_under(_carry_foot())
	var left: int = sim.empties()
	for i in sim.cells.size():
		if _lidded[i]:
			continue
		var at := place_px(i)
		if i == aim:
			b.fan(Art.hex(at, _u * 1.02), Color(Art.HALO, 0.75))
			b.fan(Art.hex(at, _u * 0.82), Color(Art.DENT.lightened(0.2), 0.9))
		elif (_shown[i] as Array).is_empty() and (_picked >= 0 or (_held >= 0 and not _moved)):
			b.stroke(Art.hex(at, _u * 0.8), 5.0, Color(Art.HALO, 0.5), true)
		elif (_shown[i] as Array).is_empty() and left <= Sim.TIGHT and not sim.is_over():
			var beat_k := 0.6 if Motion.reduce else 0.45 + 0.3 * sin(_clock * 4.0)
			b.stroke(Art.hex(at, _u * 0.82), 6.0, Color(Art.AMBER, beat_k), true)
		if armed == "sweep" and not (_shown[i] as Array).is_empty():
			b.stroke(Art.hex(at, _u * 1.06), 6.0, Color(Art.HALO, 0.85), true)

func _draw_hand() -> void:
	for i in Sim.HAND:
		var m: ArrayMesh = _hand_mesh[i]
		if m == null or i == _held:
			continue
		var sc := Motion.pop_in_scale(_clock - _dealt[i], 0.26)
		if sc == Vector2.ZERO:
			continue
		var at := slot_px(i)
		if i == _picked:
			at.y -= _hand_u * 0.25 + (0.0 if Motion.reduce else 4.0 * sin(_clock * 5.0))
		draw_mesh(m, null, _stack_xf(at, _hand_u, sc.x, sc.y))
	if _held >= 0 and _hand_mesh[_held] != null:
		var grow := 1.0 + CARRY_SWELL
		var u := lerpf(_hand_u, _u, 1.0 if _moved else 0.0)
		# its shadow stays on the table under it
		var sb := Face.Builder.new()
		sb.ellipse(_held_at + Vector2(0, _u * 0.5), u * 1.0, u * 0.7, Color(0.16, 0.09, 0.03, 0.2))
		_shade = sb.mesh()
		draw_mesh(_shade, null)
		draw_mesh(_hand_mesh[_held], null, _stack_xf(_held_at, u, grow, grow, _lean))

func _draw_tools() -> void:
	for which: String in ["sweep", "deal"]:
		var left: int = sim.sweeps if which == "sweep" else sim.deals
		var at := tool_px(which)
		var dim := left <= 0
		var xf := Transform2D(0.0, Vector2(ui, ui), 0.0, at)
		draw_mesh(_button(armed == which, dim), null, xf)
		draw_mesh(_glyph(which, dim), null, xf)
		var text := str(left)
		var fs := int(30 * ui)
		var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var tag := at + Vector2(TOOL_R * 0.72, -TOOL_R * 0.72) * ui
		draw_mesh(_badge(), null, Transform2D(0.0, Vector2(ui, ui), 0.0, tag))
		draw_string(_font, tag + Vector2(-w * 0.5, fs * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Art.CREAM)

static var _parts := {}

static func _button(lit: bool, dim: bool) -> ArrayMesh:
	var key := "b%d%d" % [int(lit), int(dim)]
	if not _parts.has(key):
		_parts[key] = Art.button(TOOL_R, lit, dim)
	return _parts[key]

static func _glyph(which: String, dim: bool) -> ArrayMesh:
	var key := "%s%d" % [which, int(dim)]
	if not _parts.has(key):
		_parts[key] = Art.brush(TOOL_R, dim) if which == "sweep" else Art.fresh(TOOL_R, dim)
	return _parts[key]

static func _badge() -> ArrayMesh:
	if not _parts.has("badge"):
		var b := Face.Builder.new()
		b.disc(Vector2(0, 3.0), 24.0, Color(Art.INK, 0.35))
		b.disc(Vector2.ZERO, 24.0, Art.TRAY)
		_parts["badge"] = b.mesh()
	return _parts["badge"]

func _bits_into(b: Face.Builder) -> void:
	for bit: Dictionary in _bits:
		var k := clampf((_clock - float(bit.at)) / float(bit.life), 0.0, 1.0)
		var col: Color = bit.col
		var pos: Vector2 = bit.pos
		if bit.kind == "ring":
			var r: float = float(bit.r) * (0.5 + 0.5 * Motion.back_out(k))
			b.stroke(Art.hex(pos, r), 7.0 * (1.0 - k), Color(col, 0.8 * (1.0 - k)), true)
		else:
			var dir := Vector2.from_angle(float(bit.seed))
			var p := pos + dir * _u * (0.5 + 0.9 * k) * Vector2(1.0, 0.7) - Vector2(0, _u * 0.5 * k)
			b.disc(p, float(bit.r) * (1.0 - 0.5 * k), Color(col, 0.85 * (1.0 - k * k)))
