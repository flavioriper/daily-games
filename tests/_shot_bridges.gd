extends SceneTree

## Shots and probes of Bridges, played through the board's own input path (a
## press on an islet, a drag to the one facing it, a release; a tap on the
## water). Windowed, one at a time:
##
##     godot --path . --resolution 810x1440 --always-on-top --rendering-driver opengl3_angle --script res://tests/_shot_bridges.gd -- [d=0..3] [mode] [rm] [out=<dir>]
##
## Modes: `rest` (the sea as dealt, the ghost finger on Easy and Medium, an
## islet tapped and read out), `right` (the answer's planks one every 0.7 s:
## streak, bubble, slots filling, flips, pennants, gags), `wrong` (Hard and
## Insane: a wrong plank until the hearts run out, shots mid-sink, on the
## card and after Try again), `tap` (a tap on a lane's water, twice), `solve`
## (every plank to the win
## screen, the party run out), `restore` (a solved day reopened). Frames go to
## <dir>/br_<mode>_d<level>_<n>.png. Every mode prints the peak draw calls
## from 0.5 s on (or its own window).

const SHOT_DIR := "/private/tmp/claude-501/-Users-flavioriper-dev-daily/e34fab47-08f2-4a51-8e47-4a951880fbbf/scratchpad"

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
var _end := 6.0
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
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://_shot_br_progress.cfg"))
	progress.path = "user://_shot_br_progress.cfg"
	for e in load("res://ui/registry.gd").PUZZLES:
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
			if e.id == "bridges":
				entry = e
		# Settings load after _initialize, so reduce motion is set here, right
		# before the board opens.
		if _reduce:
			load("res://core/motion.gd").reduce = true
		_menu._open_at(entry, _level)
		_host = _menu.get_child(_menu.get_child_count() - 1)
		_puzzle = _host._puzzle
		if _host.has_node("HowToPlay"):
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
		var st = _puzzle.state
		print("board: %dx%d band %d, %d islets, %d lanterns, %d runs, ruled %d, groups %d, hearts %d/%d, out %s, done %s, hints %d, streak %d, cell %.1f" % [
			st.n, st.n, st.band, st.islets.size(), st.lanterns.size(), st.runs.size(), st.ruled.size(),
			st.groups().size(), _puzzle.hearts, _puzzle.max_hearts, _puzzle.out_of_hearts, _puzzle.is_done(),
			_puzzle.hints_left(), _puzzle._streak, _puzzle._cell()])
		print("tip: ", _puzzle.tip_line().text)
		print("share: ", _puzzle.share_glyphs())
		var loaded: Array = []
		for k in _puzzle.fx._streams:
			if _puzzle.fx._streams[k] != null:
				loaded.append(k)
		print("cues loaded: ", loaded)
		quit()
		return true
	return false

func _at(t: float, what: Callable) -> void:
	_plan.append([t, what])
	_plan.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))

func _shot(tag := "") -> void:
	RenderingServer.force_draw()
	_n += 1
	var path := "%s/br_%s_d%d_%d%s.png" % [_dir, _mode, _level, _n, tag]
	root.get_texture().get_image().save_png(path)
	print("saved ", path)

# --- the hand ---

func _mouse(pos: Vector2, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = pos
	_puzzle._gui_input(ev)

func _motion(pos: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = pos
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT
	_puzzle._gui_input(ev)

## A drag from `a` to the islet facing it, `b`: press, two motions, release.
func _drag(a: Vector2i, b: Vector2i) -> void:
	var p: Vector2 = _puzzle._at(a)
	var q: Vector2 = _puzzle._at(b)
	_mouse(p, true)
	_motion(p.lerp(q, 0.5))
	_motion(q)
	_mouse(q, false)

func _lay(key: String) -> void:
	var lane: Dictionary = _puzzle.state.lanes[key]
	_drag(lane.a, lane.b)
	print("lay %s -> %d planks, hearts %d" % [key, _puzzle.state.planks(key), _puzzle.hearts])

func _tap(at: Vector2) -> void:
	_mouse(at, true)
	_mouse(at, false)

## The answer's planks, one entry per plank, lanes in sorted order.
func _plan_answer() -> Array:
	var st = _puzzle.state
	var keys: Array = st.answer.keys()
	keys.sort()
	var out: Array = []
	for k in keys:
		for i in int(st.answer[k]):
			out.append(String(k))
	return out

## A lane the answer lays fewer planks on than it could take, never crossed.
func _wrong_lane() -> String:
	var st = _puzzle.state
	for key in st.lanes:
		if st.blocked_by(String(key)) != "":
			continue
		var cap := int(st.ruled.get(key, 99))
		var now: int = st.planks(String(key))
		if now >= 2 or now >= cap:
			continue
		if now + 1 > int(st.answer.get(key, 0)):
			return String(key)
	return ""

func _script() -> void:
	var st = _puzzle.state
	var plan := _plan_answer()
	match _mode:
		"rest":
			_at(0.35, _shot.bind("_enter"))
			_at(1.4, _shot)
			_at(2.6, _shot.bind("_coach"))
			_at(3.0, _shot.bind("_coach2"))
			_at(3.3, func() -> void: _tap(_puzzle._at(st.islets[0])))
			_at(3.6, _shot.bind("_read"))
			_at(3.7, func() -> void: print("tip: ", _puzzle.tip_line().text))
			_end = 3.9
		"right":
			var n := mini(plan.size(), 12)
			for k in n:
				_at(1.2 + k * 0.7, _lay.bind(plan[k]))
				_at(1.2 + k * 0.7 + 0.45, _shot)
			_end = 1.2 + n * 0.7 + 0.8
		"tap":
			# Tap the middle of the water of the first answer lane with water.
			for key in plan:
				var cells: Array = st.lanes[key].cells
				if cells.is_empty():
					continue
				var c: Vector2i = cells[cells.size() / 2]
				_at(1.2, func() -> void:
					_tap(_puzzle.cell_to_local(c.y, c.x))
					print("tap %s -> %d planks" % [key, st.planks(key)]))
				_at(1.7, _shot)
				_at(1.9, func() -> void:
					_tap(_puzzle.cell_to_local(c.y, c.x))
					print("tap again %s -> %d planks" % [key, st.planks(key)]))
				_at(2.4, _shot)
				break
			_end = 2.6
		"wrong":
			_at(1.0, _lay.bind(plan[0]))
			for k in 3:
				var t0 := 1.8 + k * 2.4
				_at(t0, func() -> void:
					var w := _wrong_lane()
					if w != "":
						_lay(w))
				_at(t0 + 0.4, _shot.bind("_land"))
				_at(t0 + 0.95, _shot.bind("_sink"))
				_at(t0 + 1.9, _shot)
			_at(9.6, _shot.bind("_card"))
			_at(9.8, func() -> void:
				if _puzzle.out_of_hearts:
					_puzzle.try_again()
				print("after try again: hearts %d out %s ruled %d hints %d runs %d" % [_puzzle.hearts, _puzzle.out_of_hearts, st.ruled.size(), _puzzle.hints_left(), st.runs.size()]))
			_at(11.0, _shot)
			_end = 11.2
		"solve":
			for k in plan.size():
				_at(1.0 + k * 0.12, _lay.bind(plan[k]))
			var done: float = 1.0 + plan.size() * 0.12
			for k in 14:
				_at(done + 0.3 + k * 0.4, _shot)
			_ms_from = done
			_end = done + 6.2
		"restore":
			_at(1.5, func() -> void: _puzzle.restore_completed_board())
			_at(2.0, _shot)
			_end = 2.2
