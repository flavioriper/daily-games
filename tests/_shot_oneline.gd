extends SceneTree

## Shots and probes of One Line, played through the board's own input path
## (press, motion, release in board coordinates). Windowed, one at a time:
##
##     godot --path . --resolution 810x1440 --always-on-top --rendering-driver opengl3_angle --script res://tests/_shot_oneline.gd -- [d=0..3] [mode] [rm] [out=<dir>]
##
## Modes: `rest` (the figure as dealt), `right` (a finishing walk, one step a
## second, the first steps picked so each gag plays once), `wrong` (Hard and
## Insane: a step that leaves the figure unwalkable, again until the hearts
## run out, with shots mid-eject, on the card and after Try again), `sun`
## (Insane: a sunny line, then a second sunny one refused), `solve` (a
## finishing walk to the win screen, the party run out), `perf` (half a walk,
## then a quiet window), `restore` (a solved day reopened). Frames go to <dir>/ol_<mode>_d<level>_<n>.png. Every
## mode prints the peak draw calls from 0.5 s on (or its own window).

const SHOT_DIR := "/private/tmp/claude-501/-Users-flavioriper-dev-daily/f721c072-aa1c-4e1e-a76c-14c94a593176/scratchpad"

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
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://_shot_ol_progress.cfg"))
	progress.path = "user://_shot_ol_progress.cfg"
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
			if e.id == "oneline":
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
		print("board: %dx%d, %d lines, %d sunny, %d walked, hearts %d/%d, out %s, done %s, hints %d, riders %d" % [
			_puzzle.state.cols, _puzzle.state.rows, _puzzle.state.edges.size(), _puzzle.state.sunny.count(true),
			_puzzle.state.walked.size(), _puzzle.hearts, _puzzle.max_hearts, _puzzle.out_of_hearts, _puzzle.is_done(),
			_puzzle.hints_left(), _puzzle.snail.riders])
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
	var path := "%s/ol_%s_d%d_%d%s.png" % [_dir, _mode, _level, _n, tag]
	root.get_texture().get_image().save_png(path)
	print("saved ", path)

# --- the hand ---

func _ev_press(local: Vector2, down: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = down
	ev.position = local
	_puzzle._gui_input(ev)

func _ev_motion(local: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = local
	_puzzle._gui_input(ev)

func _tap_post(n: int) -> void:
	_ev_press(_puzzle.node_to_local(n), true)
	_ev_press(_puzzle.node_to_local(n), false)

func _tap(t: float, n: int) -> void:
	_at(t, func() -> void: _ev_press(_puzzle.node_to_local(n), true))
	_at(t + 0.06, func() -> void: _ev_press(_puzzle.node_to_local(n), false))

## One step of a finishing walk from where the snail stands: the start post
## first, then a safe step.
func _safe_next() -> int:
	var st = _puzzle.state
	if st.current < 0:
		return st.start_post()
	return st.safe_step()

## A step that may be taken but leaves no finish, or -1.
func _wrong_next() -> int:
	var st = _puzzle.state
	for q in st.adj.get(st.current, []):
		var n := int(q.to)
		if st.may_step(n) and not st.step_leaves_finish(n):
			return n
	return -1

func _script() -> void:
	match _mode:
		"rest":
			_at(2.5, _shot)
			_end = 2.7
		"right":
			for k in 9:
				_at(1.5 + k * 0.9, func() -> void: _tap_post(_safe_next()))
				_at(1.5 + k * 0.9 + 0.55, _shot)
			_end = 1.5 + 9 * 0.9 + 0.5
		"wrong":
			_at(1.0, func() -> void: _tap_post(_safe_next()))
			for k in 3:
				var t0 := 1.6 + k * 2.0
				_at(t0, func() -> void:
					# Walk safely until a wrong step is on offer, then take it.
					for _i in 60:
						var w := _wrong_next()
						if w >= 0:
							print("wrong step to ", w, " hearts ", _puzzle.hearts)
							_tap_post(w)
							return
						var s := _safe_next()
						if s < 0:
							return
						_puzzle.state.step(s)
					)
				_at(t0 + 0.5, _shot.bind("_worry"))
				_at(t0 + 1.3, _shot)
			_at(8.2, _shot.bind("_card"))
			_at(8.4, func() -> void:
				_puzzle.try_again()
				print("after try again: hearts %d out %s walked %d hints %d" % [_puzzle.hearts, _puzzle.out_of_hearts, _puzzle.state.walked.size(), _puzzle.hints_left()]))
			_at(9.6, _shot)
			_end = 9.8
		"sun":
			_at(1.0, func() -> void: _tap_post(_safe_next()))
			_at(1.4, func() -> void:
				# Walk safely until a sunny line is taken and a second is on offer.
				var st = _puzzle.state
				for _i in 60:
					if st.dry():
						for q in st.adj.get(st.current, []):
							if st.is_sunny(int(q.i)) and not st.walked.has(int(q.i)):
								print("refused sunny to ", q.to)
								_tap_post(int(q.to))
								print("tip: ", _puzzle.tip_line().text)
								return
					var s := _safe_next()
					if s < 0:
						return
					_tap_post(s)
					_puzzle._stroke = {})
			_at(1.6, _shot)
			_at(2.4, _shot)
			_end = 2.6
		"solve":
			var steps: int = _puzzle.state.edges.size() + 1
			for k in steps:
				_at(1.0 + k * 0.3, func() -> void: _tap_post(_safe_next()))
			var done: float = 1.0 + steps * 0.3
			for k in 12:
				_at(done + 0.4 + k * 0.5, _shot)
			_ms_from = done
			_end = done + 6.6
		"restore":
			_at(1.5, func() -> void: _puzzle.restore_completed_board())
			_at(2.0, _shot)
			_end = 2.2
		"perf":
			var steps: int = (_puzzle.state.edges.size() + 1) / 2
			for k in steps:
				_at(1.0 + k * 0.3, func() -> void: _tap_post(_safe_next()))
			_ms_from = 1.0 + steps * 0.3 + 2.5
			_end = _ms_from + 3.0
