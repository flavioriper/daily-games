extends SceneTree

## Brittle's frame cost, windowed:
##     godot --path . --resolution 810x1440 --always-on-top --script res://tests/_perf_brittle.gd
## Opens the Arcade tab and Brittle through the menu and times real frames
## (ticks, not the smoothed delta) through a few states, split into the
## script's share (to the end of node processing) and the render's share,
## and prints how far a flying ball moved between frames at each pace, as
## drawn: the hops that read as lag at a steady 60 fps. `-- uncapped` lifts
## the frame cap and vsync for the raw cost, `mouse` sends mouse events,
## `power` starts the rest. Puts user://arcade.cfg back on every exit.

const Sim = preload("res://arcade/brittle_sim.gd")
const PATH := "user://arcade.cfg"

## Runs after every other node's _process: marks where the script side ends.
class Tail extends Node:
	var at := 0
	func _init() -> void:
		process_priority = 100000
	func _process(_d: float) -> void:
		at = Time.get_ticks_usec()

var _menu: Node
var _s: Node
var _t := 0.0
var _step := 0
var _at := 0.0
var _had := false
var _backup := PackedByteArray()
var _frames := PackedFloat32Array()
var _script := PackedFloat32Array()
var _draws := 0
var _label := ""
var _tail: Tail
var _last := 0
var _mouse := false
var _prev0 := Vector2.INF
var _track := -1
var _jumps := {}

func _initialize() -> void:
	load("res://ui/hud/screen_tutor.gd").no_first_play = true
	_had = FileAccess.file_exists(PATH)
	if _had:
		_backup = FileAccess.get_file_as_bytes(PATH)
	var wallet: Node = root.get_node("Wallet")
	var wallet_tmp := OS.get_user_data_dir() + "/_perf_wallet.cfg"
	DirAccess.remove_absolute(wallet_tmp)
	wallet.path = wallet_tmp
	wallet.reload()
	if "uncapped" in OS.get_cmdline_user_args():
		Engine.max_fps = 0
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_mouse = "mouse" in OS.get_cmdline_user_args()
	if "power" in OS.get_cmdline_user_args():
		load("res://core/power.gd").start(root, true)
	var main: Node = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	_menu = main.get_node("UI/Menu")
	_tail = Tail.new()
	root.add_child(_tail)

func _win(at: Vector2) -> Vector2:
	var c: Control = _s.board
	return root.get_final_transform() * (c.get_global_transform_with_canvas() * at)

func _touch(at: Vector2, down: bool) -> void:
	if _mouse:
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		mb.pressed = down
		mb.position = _win(at)
		mb.global_position = mb.position
		Input.parse_input_event(mb)
		Input.flush_buffered_events()
		return
	var ev := InputEventScreenTouch.new()
	ev.index = 0
	ev.pressed = down
	ev.position = _win(at)
	Input.parse_input_event(ev)
	Input.flush_buffered_events()

func _drag(at: Vector2) -> void:
	if _mouse:
		var mm := InputEventMouseMotion.new()
		mm.button_mask = MOUSE_BUTTON_MASK_LEFT
		mm.position = _win(at)
		mm.global_position = mm.position
		Input.parse_input_event(mm)
		Input.flush_buffered_events()
		return
	var ev := InputEventScreenDrag.new()
	ev.index = 0
	ev.position = _win(at)
	Input.parse_input_event(ev)
	Input.flush_buffered_events()

func _rig(step_n: int, balls: int) -> void:
	var sim = _s.sim
	sim.step_n = step_n
	sim.balls = balls
	sim.kind.fill(Sim.Kind.NONE)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	for r in 8:
		for c in 7:
			var i: int = Sim.index(r, c)
			var roll := rng.randf()
			if roll < 0.6:
				sim.kind[i] = Sim.Kind.SQUARE
			elif roll < 0.68:
				sim.kind[i] = Sim.Kind.TL + rng.randi_range(0, 3)
			elif roll < 0.72:
				sim.kind[i] = Sim.Kind.POP
			elif roll < 0.82:
				sim.kind[i] = [Sim.Kind.PLUS, Sim.Kind.ROW, Sim.Kind.COL, Sim.Kind.FIZZ][rng.randi_range(0, 3)]
			if Sim.solid(sim.kind[i]):
				sim.hp[i] = rng.randi_range(1, step_n * 2 + 40)
				sim.full[i] = int(sim.hp[i] * rng.randf_range(1.0, 2.5))
	_s.board.lay(sim)

func _begin(label: String) -> void:
	_label = label
	_frames = PackedFloat32Array()
	_script = PackedFloat32Array()
	_draws = 0

func _report() -> void:
	if _frames.size() < 3:
		print("%s: no frames" % _label)
		return
	var sorted := _frames.duplicate()
	sorted.sort()
	var sum := 0.0
	var ssum := 0.0
	for k in _frames.size():
		sum += _frames[k]
		ssum += _script[k]
	var n := _frames.size()
	print("%-44s %4d frames: mean %5.1f ms, p95 %5.1f, max %5.1f | script %4.1f ms | draws %d" % [_label, n, sum / n, sorted[int(n * 0.95)], sorted[n - 1], ssum / n, _draws])

func _next() -> void:
	_step += 1
	_at = _t

func _fire(dir: Vector2) -> void:
	var f: Rect2 = _s.board.frame_rect()
	_touch(f.get_center(), true)
	_drag(f.get_center() + dir * f.size.y * 0.3)
	_touch(f.get_center(), false)

func _process(delta: float) -> bool:
	_t += delta
	var now := Time.get_ticks_usec()
	if _label != "" and _last > 0:
		_frames.append((now - _last) / 1000.0)
		_script.append((_tail.at - _last) / 1000.0)
		_draws = maxi(_draws, int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)))
	_last = now
	var sim = _s.sim if _s != null else null
	var drawn: PackedVector2Array = _s.board._drawn if _s != null else PackedVector2Array()
	if sim != null and sim.flying() and drawn.size() == sim.pos.size() and sim.pos.size() > 0:
		if _track < 0 or sim.state[_track] != Sim.Ball.FLY:
			_track = -1
			_prev0 = Vector2.INF
			for k in sim.state.size():
				if sim.state[k] == Sim.Ball.FLY:
					_track = k
					break
		if _track >= 0:
			var p: Vector2 = drawn[_track] / _s.board.cell_px()
			if _prev0 != Vector2.INF and p != Vector2.INF:
				var pace: float = _s.board.pace()
				if not _jumps.has(pace):
					_jumps[pace] = PackedFloat32Array()
				_jumps[pace].append(p.distance_to(_prev0))
			_prev0 = p
	else:
		_prev0 = Vector2.INF
		_track = -1
	match _step:
		0:
			if _t > 0.8:
				_menu._show_tab("arcade")
				_begin("menu, arcade tab, idle")
				_next()
		1:
			if _t > _at + 2.0:
				_report()
				_menu._open_arcade("brittle")
				_s = _menu.get_node("Brittle")
				_next()
		2:
			if _t > _at + 0.8:
				var card: Node = _s.get_node_or_null("BoostCard")
				if card != null:
					card._on_play()
				_next()
		3:
			if _t > _at + 1.0:
				_begin("brittle idle, step 1")
				_next()
		4:
			if _t > _at + 2.0:
				_report()
				_fire(Vector2(0.6, -1.0))
				_begin("one ball, step 1")
				_next()
		5:
			if not sim.flying() and _s.board.settled() and _t > _at + 0.5:
				_report()
				_rig(45, 180)
				_begin("full tin idle")
				_next()
		6:
			if _t > _at + 2.0:
				_report()
				_s.board._tight = true
				_begin("full tin, redrawn every frame")
				_next()
		7:
			_step = 9
			_at = _t
		8:
			_step = 9
			_at = _t
		9:
			if _t > _at + 2.0:
				_report()
				_s.board._tight = false
				_s.board.queue_redraw()
				var f: Rect2 = _s.board.frame_rect()
				_touch(f.get_center(), true)
				_begin("aiming, a drag a frame")
				_next()
		10:
			if _t > _at + 2.0:
				_report()
				_touch(_s.board.frame_rect().get_center(), false)
				_next()
			else:
				var f: Rect2 = _s.board.frame_rect()
				_drag(f.position + f.size * Vector2(0.3 + 0.4 * fmod(_t * 0.7, 1.0), 0.4))
		11:
			if _t > _at + 0.3:
				_begin("180 balls flying, first 4 s")
				_next()
		12:
			if _t > _at + 4.0:
				_report()
				_begin("180 balls, rest of the volley")
				_next()
		13:
			if not sim.flying() and _s.board.settled():
				_report()
				for pace in _jumps:
					var j: PackedFloat32Array = _jumps[pace]
					var line := ""
					for k in mini(j.size(), 14):
						line += "%.3f " % j[k]
					print("pace %.1f: a ball moved a frame (cells, as drawn): %s" % [pace, line])
				_rig(45, 60)
				_s.top_bar.hint.emit()
				var f: Rect2 = _s.board.frame_rect()
				_touch(f.get_center(), true)
				_begin("aiming with the bulb, a drag a frame")
				_next()
		14:
			if _t > _at + 2.0:
				_report()
				_touch(_s.board.frame_rect().get_center(), false)
				_finish()
			else:
				var f: Rect2 = _s.board.frame_rect()
				_drag(f.position + f.size * Vector2(0.3 + 0.4 * fmod(_t * 0.7, 1.0), 0.4))
	if _t > 120.0:
		print("timed out at step %d" % _step)
		_finish()
	return false

func _finish() -> void:
	if _had:
		var f := FileAccess.open(PATH, FileAccess.WRITE)
		f.store_buffer(_backup)
		f.close()
	else:
		DirAccess.remove_absolute(PATH)
	quit(0)
