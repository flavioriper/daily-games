extends Control

## Brittle's tin: draws the sim, runs it, takes the finger and says what it
## has shown (`beat`). The screen plays that: the sound, the knock and the
## stickers; the tutorial's pages hold this board with nothing round it.
##
## **A piece is a cached mesh set down by transform**, one `draw_mesh` a cell,
## so a knock is a transform and never a rebuild. **The balls are one
## MultiMesh**: a volley of three hundred is one draw call and its positions
## one buffer.
##
## A volley speeds up the longer it lasts (`pace`): nobody waits for the last
## ball rattling at the top of the tin.
##
## **A frame is drawn where it falls between two steps** (2026-11-02, the
## user: "all laggy"). The sim steps at 120 Hz and a frame at 60 is two
## steps, but at pace 1.6 it is 3.2: drawn at the last step a stream moved
## 0.375 cells three frames and 0.5 the fourth, a 33% hop every fourth frame
## that reads as lag at a steady 60 fps (tests/_perf_brittle.gd prints the
## hops). Now every ball is drawn at `prev.lerp(pos, _acc / DT)`, so a frame
## moves exactly what its share of time is worth. And at 15 cells a second
## a ball crosses its own width every frame, more under the pace, so a
## second MultiMesh lays a streak from where each ball was drawn to where it
## is: the stream reads as a stream, not a strobe.

signal beat(what: String, data: Dictionary)

const Sim = preload("res://arcade/brittle_sim.gd")
const Art = preload("res://arcade/brittle_art.gd")
const Face = preload("res://ui/faces/face.gd")
const Motion = preload("res://core/motion.gd")

## Seconds of a row coming down, a piece's knock, and how big the knock is.
const SLIDE := 0.24
const KNOCK := 0.14
const KNOCK_SIZE := 0.09
## A line's flash, seconds.
const BEAM := 0.22
## Aim dots: how far apart, in cells, and how many a long sight reaches.
const DOT_GAP := 0.42
const SIGHT_BOUNCES := 3
## A finger below this far over the floor takes the aim back.
const CANCEL := 0.5
## One tick for every this many radians of aim.
const AIM_TICK := 0.09
## How fast a volley runs by how long it has run: [seconds, pace].
const PACE := [[5.0, 1.0], [9.0, 1.6], [14.0, 2.6], [INF, 4.0]]

var sim: RefCounted
var interactive := true
## The card or the sheet is up: nothing moves.
var paused := false
## The bulb: the next aim sees further.
var long_sight := false
var _cell := 100.0
var _o := Vector2.ZERO
var _tin: ArrayMesh
var _balls: MultiMeshInstance2D
var _buffer := PackedFloat32Array()
var _streaks: MultiMeshInstance2D
var _sbuffer := PackedFloat32Array()
## Where each ball was drawn last frame, in the tin's pixels: a streak runs
## from there.
var _drawn := PackedVector2Array()
var _acc := 0.0
var _slide := 1.0
var _aiming := false
var _aim := Vector2.UP
var _aim_ok := false
var _aim_mesh: ArrayMesh
var _tick_at := 0.0
var _beams: Array = []
var _shake := 0.0
var _clock := 0.0
var _font: Font
var _tight := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_font = Art.font()
	_streaks = MultiMeshInstance2D.new()
	var sm := MultiMesh.new()
	sm.transform_format = MultiMesh.TRANSFORM_2D
	sm.mesh = Art.streak()
	_streaks.multimesh = sm
	add_child(_streaks)
	_balls = MultiMeshInstance2D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.mesh = Art.ball()
	_balls.multimesh = mm
	add_child(_balls)
	resized.connect(layout)
	layout()

func lay(game: RefCounted) -> void:
	sim = game
	_acc = 0.0
	_slide = 1.0
	_aiming = false
	_aim_mesh = null
	_beams.clear()
	_tight = sim.tight()
	_balls.visible = false
	_streaks.visible = false
	_drawn = PackedVector2Array()
	queue_redraw()

## A centred tin, whatever room there is, with its rim inside the rect.
func layout() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var rim := 18.0
	_cell = floorf(minf((size.x - rim * 2.0) / Sim.W, (size.y - rim * 2.0) / Sim.FLOOR))
	_o = ((size - Vector2(Sim.W, Sim.FLOOR) * _cell) * 0.5).round()
	var b := Face.Builder.new()
	Art.tin(b, _o, _cell)
	_tin = b.mesh()
	_balls.position = _o
	_streaks.position = _o
	_buffer = PackedFloat32Array()
	_sbuffer = PackedFloat32Array()
	_drawn = PackedVector2Array()
	queue_redraw()

func px(p: Vector2) -> Vector2:
	return _o + p * _cell

func cell_px() -> float:
	return _cell

func frame_rect() -> Rect2:
	return Rect2(_o, Vector2(Sim.W, Sim.FLOOR) * _cell)

func settled() -> bool:
	return sim == null or (not sim.flying() and _slide >= 1.0 and _beams.is_empty())

func pace() -> float:
	for p: Array in PACE:
		if sim.clock < float(p[0]):
			return float(p[1])
	return 1.0

# --- running ---

func _process(delta: float) -> void:
	if sim == null:
		return
	_clock += delta
	if paused:
		return
	var moved := false
	if sim.flying():
		_acc += minf(delta, 0.05) * pace()
		while _acc >= Sim.DT and sim.flying():
			_acc -= Sim.DT
			sim.step()
		moved = true
	_play()
	if sim.flying() or not _balls_home():
		_set_balls()
	if _slide < 1.0:
		_slide = 1.0 if Motion.reduce else minf(_slide + delta / SLIDE, 1.0)
		moved = true
	if not _beams.is_empty():
		for k in range(_beams.size() - 1, -1, -1):
			_beams[k].t += delta
			if _beams[k].t >= BEAM:
				_beams.remove_at(k)
		moved = true
	if _shake > 0.0:
		_shake = maxf(_shake - delta * 40.0, 0.0)
		moved = true
	if moved or _tight:
		queue_redraw()

func _balls_home() -> bool:
	return not _balls.visible

## Every ball where this frame falls between the last two steps, and under
## each one that crossed more than its own radius since the last frame, a
## streak from there to here.
func _set_balls() -> void:
	if not sim.flying():
		_balls.visible = false
		_streaks.visible = false
		return
	var n: int = sim.pos.size()
	var mm := _balls.multimesh
	var sm := _streaks.multimesh
	var s := Sim.R * _cell / Art.BALL
	if mm.instance_count < n or _buffer.size() != mm.instance_count * 8:
		mm.instance_count = maxi(n + 32, mm.instance_count)
		_buffer.resize(mm.instance_count * 8)
		_buffer.fill(0.0)
		for k in mm.instance_count:
			_buffer[k * 8] = s
			_buffer[k * 8 + 5] = s
		sm.instance_count = mm.instance_count
		_sbuffer.resize(mm.instance_count * 8)
		_sbuffer.fill(0.0)
	if _drawn.size() != n:
		_drawn.resize(n)
		_drawn.fill(Vector2.INF)
	mm.visible_instance_count = n
	sm.visible_instance_count = n
	var a := clampf(_acc / Sim.DT, 0.0, 1.0)
	var r := Sim.R * _cell
	var streaks := not Motion.reduce
	var prev: PackedVector2Array = sim.prev
	var pos: PackedVector2Array = sim.pos
	for k in n:
		var p: Vector2 = prev[k].lerp(pos[k], a) * _cell
		_buffer[k * 8 + 3] = p.x
		_buffer[k * 8 + 7] = p.y
		var was: Vector2 = _drawn[k]
		_drawn[k] = p
		var j := k * 8
		var d := p - was
		if streaks and was != Vector2.INF and sim.state[k] == Sim.Ball.FLY and d.length_squared() > r * r:
			# turned along d, half as long as the way, a ball wide: the
			# transform's rows laid straight into the buffer
			var len := d.length()
			var cx := d.x / len
			var sy := d.y / len
			var sx := len * 0.5 / Art.BALL
			_sbuffer[j] = cx * sx
			_sbuffer[j + 1] = -sy * s
			_sbuffer[j + 3] = (p.x + was.x) * 0.5
			_sbuffer[j + 4] = sy * sx
			_sbuffer[j + 5] = cx * s
			_sbuffer[j + 7] = (p.y + was.y) * 0.5
		else:
			_sbuffer[j] = 0.0
			_sbuffer[j + 1] = 0.0
			_sbuffer[j + 4] = 0.0
			_sbuffer[j + 5] = 0.0
	mm.buffer = _buffer
	sm.buffer = _sbuffer
	_balls.visible = true
	_streaks.visible = streaks

## Hands what the sim did to whoever listens, and keeps the table's part.
func _play() -> void:
	if sim.events.is_empty():
		return
	var list: Array = sim.events
	sim.events = []
	for e: Dictionary in list:
		match String(e.kind):
			"descend":
				_slide = 0.0
				_tight = sim.tight()
				_aim_mesh = null
			"line":
				_beams.append({"at": e.at, "row": e.row, "t": 0.0})
			"pop":
				_shake = 8.0
			"revive":
				_tight = sim.tight()
		beat.emit(String(e.kind), e)

# --- drawing ---

func _draw() -> void:
	if _tin == null:
		return
	var off := Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake)) if _shake > 0.0 and not Motion.reduce else Vector2.ZERO
	draw_mesh(_tin, null)
	if sim == null:
		return
	var k := _cell / Art.CELL
	var drop := Vector2.ZERO
	if _slide < 1.0:
		drop = Vector2(0.0, -(1.0 - Motion.back_out(_slide)) * _cell)
	var flying: bool = sim.flying()
	var hold: bool = flying or _aiming
	for i in sim.kind.size():
		var what: int = sim.kind[i]
		if what == Sim.Kind.NONE:
			continue
		var at := px(Sim.centre(i)) + drop + off
		if Sim.solid(what):
			var left: int = sim.hp[i]
			var scale := k
			var since: float = sim.clock - sim.struck[i]
			if flying and since >= 0.0 and since < KNOCK:
				scale *= 1.0 + KNOCK_SIZE * (1.0 - since / KNOCK)
			var mesh := Art.piece(what, Art.band(left, sim.step_n), Art.crack(left, sim.full[i]), (i * 7 + sim.full[i]) % 5)
			draw_mesh(mesh, null, Transform2D(0.0, Vector2(scale, scale), 0.0, at))
			_number(at, left, what)
		else:
			var bob := 1.0 + (0.05 * sin(_clock * 4.0 + i) if hold and not Motion.reduce else 0.0)
			var fade := 0.45 if sim.spent[i] != 0 else 1.0
			draw_mesh(Art.item(what), null, Transform2D(0.0, Vector2(k * bob, k * bob), 0.0, at), Color(1, 1, 1, fade))
	for b: Dictionary in _beams:
		var a := 1.0 - float(b.t) / BEAM
		var c := px(b.at)
		var col := Color(Art.LACE.lightened(0.5), a)
		if bool(b.row):
			draw_rect(Rect2(_o.x, c.y - _cell * 0.1 * a, Sim.W * _cell, _cell * 0.2 * a), col)
		else:
			draw_rect(Rect2(c.x - _cell * 0.1 * a, _o.y, _cell * 0.2 * a, Sim.FLOOR * _cell), col)
	if _tight:
		var glow := 0.14 + (0.1 * sin(_clock * 5.0) if not Motion.reduce else 0.0)
		draw_rect(Rect2(_o.x, _o.y + (Sim.ROWS - 1) * _cell, Sim.W * _cell, _cell), Color(Art.DANGER, glow))
	if _aim_mesh != null and _aiming and _aim_ok:
		draw_mesh(_aim_mesh, null)
	_draw_scoop(k)

## The number iced on a square, smaller as it grows. A wedge's stands at the
## wedge's own middle, into the right angle: at the cell's it would run off.
func _number(at: Vector2, value: int, what: int) -> void:
	var text := str(value)
	var n := text.length()
	var fs := int(_cell * (0.4 if n <= 2 else (0.32 if n == 3 else 0.25)))
	var c := at
	if what >= Sim.Kind.TL and what <= Sim.Kind.BL:
		fs = int(fs * 0.84)
		var t: Array = Sim.triangle(what, Vector2.ZERO)
		c += ((t[0] + t[1] + t[2]) / 3.0) * _cell
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var base := c + Vector2(-w * 0.5, (_font.get_ascent(fs) - _font.get_descent(fs)) * 0.5)
	draw_string(_font, base + Vector2(0.0, 3.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Art.INK, 0.6))
	draw_string(_font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Art.CREAM)

## The scoop, its ball while nothing flies, and how many are left to pour.
func _draw_scoop(k: float) -> void:
	var x: float = sim.next_x if sim.flying() and sim.landed > 0 else sim.home_x
	var at := px(Vector2(x, Sim.FLOOR))
	draw_mesh(Art.scoop(), null, Transform2D(0.0, Vector2(k, k * 0.5), 0.0, at + Vector2(0.0, -5.0)))
	var left: int = sim.balls
	if sim.flying():
		left = sim.balls - sim.fired
	else:
		var r := Sim.R * _cell / Art.BALL
		draw_mesh(Art.ball(), null, Transform2D(0.0, Vector2(r, r), 0.0, px(Vector2(x, Sim.FLOOR - Sim.R))))
	if left <= 0:
		return
	var fs := int(_cell * 0.3)
	var text := "x%d" % left
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var side := 1.0 if at.x + _cell * 0.5 + w < _o.x + Sim.W * _cell else -1.0
	var tx := at.x + side * _cell * 0.42 - (w if side < 0.0 else 0.0)
	draw_string(_font, Vector2(tx, at.y - _cell * 0.1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Art.SUGAR)

## The dotted way a ball will go: to its first bounce and a little past, or
## further under the bulb. It is the sim's own physics (`trace`).
func _build_aim() -> void:
	var path: PackedVector2Array = sim.trace(_aim, SIGHT_BOUNCES if long_sight else 1)
	var b := Face.Builder.new()
	var r := Sim.R * _cell * 0.42
	var gap := DOT_GAP
	var run := 0.0
	for s in range(path.size() - 1):
		var a := path[s]
		var d := path[s + 1] - a
		var len := d.length()
		if len <= 0.0:
			continue
		var at := fmod(gap - fmod(run, gap), gap)
		while at < len:
			var fade := 1.0
			if s > 0 and not long_sight:
				fade = clampf(1.0 - (run + at - _first_leg(path)) / 3.0, 0.0, 1.0)
			if fade > 0.0:
				b.disc(px(a + d * (at / len)), r, Color(Art.SUGAR, 0.85 * fade))
			at += gap
		run += len
		if s == 0:
			# where the ball first meets something
			b.stroke(Face.Builder.ring(px(path[1]), Sim.R * _cell, Sim.R * _cell), 3.0, Color(Art.SUGAR, 0.9), true)
		if not long_sight and s >= 1:
			break
	_aim_mesh = b.mesh()

func _first_leg(path: PackedVector2Array) -> float:
	return path[0].distance_to(path[1])

# --- the finger ---

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
		if event.index == 0 and _aiming:
			accept_event()
			drag(event.position)
	elif event is InputEventMouseMotion:
		if _aiming and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			accept_event()
			drag(event.position)

func can_aim() -> bool:
	return sim != null and sim.can_fire() and _slide >= 1.0 and not paused

func press(at: Vector2) -> void:
	if not can_aim():
		beat.emit("tap", {})
		return
	_aiming = true
	beat.emit("press", {})
	drag(at)

func drag(at: Vector2) -> void:
	if not _aiming:
		return
	var from := px(Vector2(sim.home_x, Sim.FLOOR - Sim.R))
	var d := at - from
	_aim_ok = at.y < from.y - _cell * CANCEL
	if _aim_ok:
		_aim = Sim.clamp_aim(d)
		var turn := _aim.angle()
		if absf(angle_difference(turn, _tick_at)) >= AIM_TICK:
			_tick_at = turn
			beat.emit("aim", {})
		_build_aim()
	queue_redraw()

func release(_at: Vector2) -> void:
	if not _aiming:
		return
	_aiming = false
	queue_redraw()
	if not _aim_ok:
		beat.emit("cancel", {})
		return
	if sim.fire(_aim):
		_balls.visible = false
		_drawn = PackedVector2Array()
		_acc = Sim.DT
		_set_balls()
		beat.emit("fired", {"balls": sim.balls})

## The finger goes (a card came up): the aim is dropped, nothing fires.
func let_go() -> void:
	_aiming = false
	queue_redraw()
