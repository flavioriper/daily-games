extends SceneTree

## Shots and probes of Nonogram, played through the board's own input path
## (press, motion, release in board coordinates). Windowed, one at a time:
##
##     godot --path . --resolution 810x1440 --always-on-top --rendering-driver opengl3_angle --script res://tests/_shot_nonogram.gd -- [d=0..3] [mode] [rm] [out=<dir>]
##
## Modes: `rest` (the floor as dealt), `right` (right strokes row by row,
## one a second), `wrong` (Hard and Insane: a wrong tile until the hearts run
## out, shots mid-eject, on the card and after Try again), `solve` (every row
## swept to the win screen, the party run out), `perf` (half the rows, then a
## quiet window), `restore` (a solved day reopened). Frames go to
## <dir>/ng_<mode>_d<level>_<n>.png. Every mode prints the peak draw calls from
## 0.5 s on (or its own window).

const SHOT_DIR := "/private/tmp/claude-501/-Users-flavioriper-dev-daily/28ee2984-ddba-4e5a-9218-55d95cbba28d/scratchpad"

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
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://_shot_ng_progress.cfg"))
	progress.path = "user://_shot_ng_progress.cfg"
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
			if e.id == "nonogram":
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
		print("board: %dx%d, %d leaves, %d filled of %d, hearts %d/%d, out %s, done %s, hints %d, streak %d" % [
			_puzzle.state.w, _puzzle.state.h, _puzzle.state.leaf_count(), _puzzle.state.filled_count(), _puzzle.state.target,
			_puzzle.hearts, _puzzle.max_hearts, _puzzle.out_of_hearts, _puzzle.is_done(),
			_puzzle.hints_left(), _puzzle._streak])
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
	var path := "%s/ng_%s_d%d_%d%s.png" % [_dir, _mode, _level, _n, tag]
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

func _c(x: int, y: int) -> Vector2:
	return _puzzle.cell_to_local(y, x)

## Sweeps every run of row y the picture wants, one stroke a run.
func _sweep_row(y: int) -> void:
	var st = _puzzle.state
	var x := 0
	while x < st.w:
		if int(st.bitmap[y][x]) != 1 or st.mark_at(Vector2i(x, y)) == 1:
			x += 1
			continue
		var x1 := x
		while x1 + 1 < st.w and int(st.bitmap[y][x1 + 1]) == 1:
			x1 += 1
		_ev_press(_c(x, y), true)
		for k in range(x, x1 + 1):
			_ev_motion(_c(k, y))
		_ev_press(_c(x1, y), false)
		x = x1 + 1

## A cell the picture leaves empty that nothing covers yet.
func _empty_cell() -> Vector2i:
	var st = _puzzle.state
	for y in st.h:
		for x in st.w:
			if int(st.bitmap[y][x]) == 0 and st.mark_at(Vector2i(x, y)) == 0:
				return Vector2i(x, y)
	return Vector2i(-1, -1)

func _script() -> void:
	var rows: int = _puzzle.state.h
	match _mode:
		"rest":
			_at(0.35, _shot.bind("_enter"))
			_at(2.5, _shot)
			_end = 2.7
		"right":
			for k in mini(rows, 8):
				_at(1.2 + k * 1.0, _sweep_row.bind(k))
				_at(1.2 + k * 1.0 + 0.45, _shot)
			_end = 1.2 + mini(rows, 8) * 1.0 + 0.5
		"wrong":
			_at(1.0, _sweep_row.bind(0))
			for k in 3:
				var t0 := 1.8 + k * 2.2
				_at(t0, func() -> void:
					var c := _empty_cell()
					print("wrong tile at ", c, " hearts ", _puzzle.hearts)
					_ev_press(_c(c.x, c.y), true)
					_ev_press(_c(c.x, c.y), false))
				_at(t0 + 0.4, _shot.bind("_worry"))
				_at(t0 + 1.5, _shot)
			_at(8.6, _shot.bind("_card"))
			_at(8.8, func() -> void:
				if _puzzle.out_of_hearts:
					_puzzle.try_again()
				print("after try again: hearts %d out %s filled %d hints %d" % [_puzzle.hearts, _puzzle.out_of_hearts, _puzzle.state.filled_count(), _puzzle.hints_left()]))
			_at(10.0, _shot)
			_end = 10.2
		"solve":
			for k in rows:
				_at(1.0 + k * 0.4, _sweep_row.bind(k))
			var done: float = 1.0 + rows * 0.4
			for k in 12:
				_at(done + 0.3 + k * 0.4, _shot)
			_ms_from = done
			_end = done + 5.4
		"restore":
			_at(1.5, func() -> void: _puzzle.restore_completed_board())
			_at(2.0, func() -> void:
				var now: float = _puzzle._now()
				print("restore: solved_at %.2f now %.2f gone %.2f frame %.2f" % [_puzzle._solved_at, now, _puzzle._gone(now), _puzzle._frame_at])
				_shot())
			_end = 2.2
		"perf":
			for k in rows / 2:
				_at(1.0 + k * 0.4, _sweep_row.bind(k))
			_ms_from = 1.0 + rows / 2 * 0.4 + 2.5
			_end = _ms_from + 3.0
