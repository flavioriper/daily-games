extends SceneTree

## Shots and probes of Paper Planes, played through the board's own input
## path (a press on a plane, a release). Windowed, one at a time:
##
##     godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_planes.gd -- [d=0..3] [mode] [rm] [out=<dir>]
##
## Modes: `rest` (the entrance, then the board at rest; on d=3 the clouds,
## their ghosts and the wind sock), `press` (a finger held on a free plane,
## then let go: the dip and the launch; on d=3 the clouds glide), `crash`
## (Hard or Insane: a plane blocked by a plane tapped -- the rush, the bonk,
## the heart splitting, the flutter home), `cloud` (Insane: a plane blocked
## by a cloud tapped), `refuse` (Easy or Medium: the free refusal), `out`
## (crashes until the hearts run out: the droop, the dusk, the card, then Try
## again), `stuck` (Insane: greedy launches until the clouds close in -- the
## tip, the pill breathing), `gust` (stuck, then a cloud tapped: the heart,
## the glide), `solve` (Insane: the stored order played tap by tap to the
## win, then the party: flock, confetti, the cat batting the straggler and
## curling up, the seal, Windy Day's gold clouds; on any band), `right` (the
## rewards: launches in a row with the longest lanes -- combo, the bubble,
## confetti at 5 -- with each gag forced once, loop, bird, roll and love, then
## an undo), `howto` (the first-play sheet's diagram), `restore` (a solved
## day reopened flawless with a heart gone: the cat asleep, the seal). Frames
## go to <dir>/pp_<mode>_d<level>_<n>.png.
## Every mode prints the peak draw calls from 0.5 s on.

const SHOT_DIR := "/tmp"

var _t := 0.0
var _level := 0
var _mode := "rest"
var _reduce := false
var _dir := SHOT_DIR
var _menu: Node
var _host: Node
var _puzzle: Node
var _opened := false
var _plan: Array = []
var _n := 0
var _end := 4.0
var _ms_from := 0.5
var _ms_sum := 0.0
var _ms_n := 0
var _draws_max := 0

func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("d="):
			_level = int(a.substr(2))
		elif a == "rm":
			_reduce = true
		elif a.begins_with("out="):
			_dir = a.substr(4)
		else:
			_mode = a
	var progress = load("res://core/progress.gd")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://_shot_pp_progress.cfg"))
	progress.path = "user://_shot_pp_progress.cfg"
	for e in load("res://ui/registry.gd").PUZZLES:
		if _mode == "howto" and e.id == "planes":
			continue
		progress.mark_tutorial_seen(String(e.id))
	if _reduce:
		load("res://core/motion.gd").reduce = true
	var main: Node = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	_menu = main.get_node("UI/Menu")

func _process(delta: float) -> bool:
	_t += delta
	if not _opened:
		_opened = true
		_t = 0.0
		var entry: Dictionary = {}
		for e in load("res://ui/registry.gd").PUZZLES:
			if e.id == "planes":
				entry = e
		# Settings load after _initialize, so reduce motion is set here, right
		# before the board opens.
		if _reduce:
			load("res://core/motion.gd").reduce = true
		_menu._open_at(entry, _level)
		_host = _menu.get_child(_menu.get_child_count() - 1)
		_puzzle = _host._puzzle
		if _host.has_node("HowToPlay") and _mode != "howto":
			_host.get_node("HowToPlay").free()
		_script()
		return false
	while not _plan.is_empty() and float(_plan[0][0]) <= _t:
		var step: Array = _plan.pop_front()
		(step[1] as Callable).call()
	if _t >= _ms_from and _t < _end:
		_ms_sum += delta * 1000.0
		_ms_n += 1
		_draws_max = maxi(_draws_max, int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)))
	if _t >= _end:
		if _ms_n > 0:
			print("frames: draw calls peak %d, mean %.2f ms over %d frames" % [_draws_max, _ms_sum / maxf(_ms_n, 1), _ms_n])
		var st = _puzzle._state
		print("board: %dx%d band %d, cell %.1f, size %s, planes %d left %d, windy %s banked %s count %d gusts %d stuck %s, hearts %d/%d, out %s, done %s, hints %d, can_undo %s" % [
			st.cols, st.rows, st.difficulty, _puzzle._cell, _puzzle.size, st.planes.size(), st.left(),
			st.windy(), st.banked, st.count(), st.gusts, st.stuck(), _puzzle.hearts, _puzzle.max_hearts,
			_puzzle.out_of_hearts, _puzzle.is_done(), _puzzle.hints_left(), _puzzle.can_undo()])
		print("tip: ", _puzzle.tip_line().text)
		_cleanup()
		quit()
		return true
	return false

func _cleanup() -> void:
	for n in root.get_children():
		var card := n.find_child("OutOfHearts", true, false)
		if card != null:
			card.queue_free()

func _at(t: float, what: Callable) -> void:
	_plan.append([t, what])
	_plan.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))

func _shot(tag := "") -> void:
	RenderingServer.force_draw()
	_n += 1
	var path := "%s/pp_%s_d%d_%d%s.png" % [_dir, _mode, _level, _n, tag]
	root.get_texture().get_image().save_png(path)
	print("saved ", path, "  tip: ", _puzzle.tip_line().text)

# --- the hand ---

func _mouse(pos: Vector2, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = pos
	_puzzle._gui_input(ev)

func _head(i: int) -> Vector2:
	var cells: Array = _puzzle._state.planes[i]["cells"]
	var h: Vector2i = cells[cells.size() - 1]
	return _puzzle.cell_to_local(h.y, h.x)

func _tap(i: int) -> void:
	_mouse(_head(i), true)
	_mouse(_head(i), false)

## The free plane with the longest lane (the gags show best on it).
func _longest_free() -> int:
	var st = _puzzle._state
	var best := -1
	var reach := -1
	for i in st.free_planes():
		var n: int = st.lane(i).size()
		if n > reach:
			reach = n
			best = i
	return best

## A launch through the board's input with `gag` forced (-1 for none).
func _launch(gag: int, label: String) -> void:
	_puzzle.force_gag = gag
	var i := _longest_free()
	_tap(i)
	_puzzle.force_gag = -2
	print("%s: plane %d lane %d, streak %d, combo %d, gag_until %.2f" % [label, i,
		_puzzle._state.lane(i).size(), _puzzle._streak, _puzzle._combo_n, _puzzle._gag_until - _puzzle._now()])

## A plane blocked by another plane (or, with `cloud`, by a cloud), the
## longest way to its blocker first so the rush shows.
func _blocked(cloud := false) -> int:
	var st = _puzzle._state
	var best := -1
	var reach := -1
	for i in st.planes.size():
		if st.planes[i]["gone"]:
			continue
		var who: int = st.blocker(i)
		if who == -1 or (who == -2) != cloud:
			continue
		var stop: Vector2i = st.blocker_cell(i)
		var n := 0
		for c in st.lane(i):
			n += 1
			if c == stop:
				break
		if n > reach:
			reach = n
			best = i
	return best

## Random legal launches (seeded) (straight on the board's tap path, no
## input) until the clouds close in. Returns the launches made.
func _launch_until_stuck() -> int:
	var st = _puzzle._state
	var made := 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	while not st.stuck() and not st.solved() and made < 200:
		var free: Array = st.free_planes()
		if free.is_empty():
			break
		_puzzle._tap(int(free[rng.randi_range(0, free.size() - 1)]))
		made += 1
	return made

func _script() -> void:
	var st = _puzzle._state
	match _mode:
		"rest":
			_at(0.3, _shot.bind("_enter"))
			_at(2.0, _shot)
			_at(3.3, _shot.bind("_later"))
			_end = 3.5
		"press":
			var free: Array = st.free_planes()
			var i: int = free[0]
			_at(1.5, func() -> void: _mouse(_head(i), true))
			_at(1.65, _shot.bind("_down"))
			_at(1.7, func() -> void: _mouse(_head(i), false))
			_at(1.82, _shot.bind("_go"))
			_at(1.95, _shot.bind("_glide"))
			_at(2.6, _shot.bind("_after"))
			_end = 2.8
		"crash", "cloud":
			var i := _blocked(_mode == "cloud")
			print("blocked plane %d, blocker %d, hearts %d" % [i, st.blocker(i) if i >= 0 else -9, _puzzle.hearts])
			if i < 0:
				_end = 1.0
				return
			_at(1.5, _tap.bind(i))
			for dt in [0.06, 0.14, 0.22, 0.3, 0.4, 0.55, 0.75, 1.2]:
				_at(1.5 + dt, _shot.bind("_%03d" % int(dt * 100)))
			_at(1.53, func() -> void:
				print("busy %s can_undo %s can_reset %s hearts %d" % [_puzzle.busy(), _puzzle.can_undo(), _puzzle.can_reset(), _puzzle.hearts]))
			_at(2.0, func() -> void:
				# A tap during the crash is ignored.
				var free: Array = st.free_planes()
				if not free.is_empty():
					_tap(int(free[0]))
				print("tap during crash: left %d" % st.left()))
			_end = 2.9
		"refuse":
			var i := _blocked(false)
			_at(1.5, _tap.bind(i))
			_at(1.6, _shot.bind("_band"))
			_at(2.2, _shot)
			_end = 2.4
		"out":
			var n: int = _puzzle.hearts
			for k in n:
				_at(1.5 + k * 1.3, func() -> void:
					var i := _blocked(false)
					if i < 0:
						i = _blocked(true)
					print("crash %d on %d" % [k, i])
					_tap(i))
			var t_out := 1.5 + (n - 1) * 1.3 + 1.0
			_at(t_out + 0.2, _shot.bind("_droop"))
			_at(t_out + 1.5, _shot.bind("_card"))
			_at(t_out + 1.7, func() -> void:
				if _puzzle.out_of_hearts:
					_puzzle.try_again()
				print("after try again: hearts %d out %s left %d count %d" % [
					_puzzle.hearts, _puzzle.out_of_hearts, st.left(), st.count()]))
			_at(t_out + 1.9, _shot.bind("_wave"))
			_at(t_out + 3.0, _shot)
			_end = t_out + 3.2
		"stuck", "gust":
			_at(1.2, func() -> void:
				print("launched %d, stuck %s count %d" % [_launch_until_stuck(), st.stuck(), st.count()]))
			_at(2.4, _shot.bind("_stuck"))
			if _mode == "gust":
				_at(2.6, func() -> void:
					var c: Vector2i = st.cloud_cells()[0]
					var at: Vector2 = _puzzle.cell_to_local(c.y, c.x)
					_mouse(at, true)
					_mouse(at, false)
					print("gust: hearts %d gusts %d count %d stuck %s" % [_puzzle.hearts, st.gusts, st.count(), st.stuck()]))
				_at(2.72, _shot.bind("_blow"))
				_at(3.4, _shot.bind("_after"))
				_end = 3.6
			else:
				_end = 2.6
		"solve":
			var order: Array = st.solve_order()
			for k in order.size():
				_at(1.0 + k * 0.12, _tap.bind(int(order[k])))
			var last := 1.0 + (order.size() - 1) * 0.12
			_at(last - 1.0, _shot.bind("_late"))
			_at(last + 0.05, func() -> void:
				print("win_delay %.2f" % _puzzle.win_delay()))
			for dt in [0.5, 0.9, 1.3, 1.8, 2.3, 2.8, 3.3]:
				_at(last + dt, _shot.bind("_p%02d" % int(dt * 10)))
			_at(last + 0.6, func() -> void:
				print("solved %s done %s record %s" % [_puzzle.is_solved(), _puzzle.is_done(), _puzzle.completion_record()])
				print("share: ", _puzzle.share_glyphs()))
			_end = last + 3.5
		"right":
			var NONE := -1
			_at(1.2, _launch.bind(NONE, "one"))
			_at(1.6, _launch.bind(0, "two, loop"))
			for dt in [0.2, 0.4, 0.6, 0.8, 1.0]:
				_at(1.6 + dt, _shot.bind("_loop%02d" % int(dt * 10)))
			_at(3.0, _launch.bind(2, "three, roll"))
			for dt in [0.06, 0.14, 0.22, 0.32]:
				_at(3.0 + dt, _shot.bind("_roll%02d" % int(dt * 100)))
			_at(3.8, _launch.bind(1, "four, bird"))
			for dt in [0.15, 0.4, 0.7, 1.0, 1.4]:
				_at(3.8 + dt, _shot.bind("_bird%02d" % int(dt * 10)))
			_at(6.0, _launch.bind(3, "five, love"))
			for dt in [0.08, 0.3, 0.6]:
				_at(6.0 + dt, _shot.bind("_love%02d" % int(dt * 100)))
			_at(7.0, _launch.bind(NONE, "six"))
			_at(7.5, func() -> void:
				print("undo: %s, streak %d" % [_puzzle.undo(), _puzzle._streak]))
			_at(7.56, _shot.bind("_undo"))
			_at(8.0, _shot.bind("_after"))
			_end = 8.2
		"howto":
			_ms_from = 9.0
			for k in 12:
				_at(2.0 + k * 0.3, _shot)
			_end = 6.0
		"restore":
			_at(1.5, func() -> void:
				_puzzle.completed_record = {"hearts": maxi(0, _puzzle.max_hearts - 1), "flawless": true}
				_puzzle.restore_completed()
				print("share: ", _puzzle.share_glyphs()))
			_at(2.0, _shot)
			_end = 2.2
