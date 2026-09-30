extends SceneTree

## Shots and probes of Queens, played through the board's own input path
## (press and release in board coordinates; a tap on a bare seat crosses it,
## a second tap seats a queen). Windowed, one at a time:
##
##     godot --path . --resolution 810x1440 --always-on-top --rendering-driver opengl3_angle --script res://tests/_shot_queens.gd -- [d=0..3] [mode] [rm] [out=<dir>]
##
## Modes: `rest` (the court as dealt), `right` (the answer's queens row by
## row, one a second), `wrong` (Hard and Insane: a wrong queen until the
## hearts run out, shots mid-eject, on the card and after Try again),
## `solve` (every queen seated to the win screen, the party run out), `perf`
## (half the queens, then a quiet window), `restore` (a solved day reopened).
## Frames go to <dir>/qn_<mode>_d<level>_<n>.png. Every mode prints the peak
## draw calls from 0.5 s on (or its own window).

const SHOT_DIR := "/private/tmp/claude-501/-Users-flavioriper-dev-daily/a65a8a25-4a64-4965-8dde-1757b42a1e71/scratchpad"

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
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://_shot_qn_progress.cfg"))
	progress.path = "user://_shot_qn_progress.cfg"
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
			if e.id == "queens":
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
		print("board: %dx%d band %d, mist %s quota %s, %d queens of %d, shown %d, hearts %d/%d, out %s, done %s, hints %d, streak %d" % [
			st.n, st.n, st.band, st.mist, st.quota, st.queens.size(), st.n, st.shown.size(),
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
	var path := "%s/qn_%s_d%d_%d%s.png" % [_dir, _mode, _level, _n, tag]
	root.get_texture().get_image().save_png(path)
	print("saved ", path)

# --- the hand ---

func _tap(cell: Vector2i) -> void:
	var at: Vector2 = _puzzle.cell_to_local(cell.y, cell.x)
	for down in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = down
		ev.position = at
		_puzzle._gui_input(ev)

## A queen on `cell`: a bare seat takes a cross first, then her.
func _seat(cell: Vector2i) -> void:
	var st = _puzzle.state
	if st.mark_at(cell) == 0:
		_tap(cell)
	_tap(cell)
	print("seat ", cell, " -> mark ", st.mark_at(cell), " hearts ", _puzzle.hearts)

## The answer's queen in row `r`.
func _answer(r: int) -> Vector2i:
	return Vector2i(int(_puzzle.state.solution[r]), r)

## A bare seat the answer leaves empty and no queen sees.
func _wrong_cell() -> Vector2i:
	var st = _puzzle.state
	for y in st.n:
		for x in st.n:
			var c := Vector2i(x, y)
			if int(st.solution[y]) != x and st.mark_at(c) == 0:
				return c
	return Vector2i(-1, -1)

func _script() -> void:
	var n: int = _puzzle.state.n
	match _mode:
		"rest":
			_at(0.35, _shot.bind("_enter"))
			_at(1.2, _shot.bind("_mist"))
			_at(2.5, _shot)
			_end = 2.7
		"right":
			for k in mini(n, 8):
				_at(1.2 + k * 1.0, _seat.bind(_answer(k)))
				_at(1.2 + k * 1.0 + 0.45, _shot)
			_end = 1.2 + mini(n, 8) * 1.0 + 0.5
		"wrong":
			_at(1.0, _seat.bind(_answer(0)))
			for k in 3:
				var t0 := 1.8 + k * 2.2
				_at(t0, func() -> void:
					var c := _wrong_cell()
					print("wrong queen at ", c, " hearts ", _puzzle.hearts)
					_seat(c))
				_at(t0 + 0.6, _shot.bind("_worry"))
				_at(t0 + 1.25, _shot.bind("_fly"))
				_at(t0 + 1.9, _shot)
			_at(8.6, _shot.bind("_card"))
			_at(8.8, func() -> void:
				if _puzzle.out_of_hearts:
					_puzzle.try_again()
				print("after try again: hearts %d out %s queens %d shown %d hints %d" % [_puzzle.hearts, _puzzle.out_of_hearts, _puzzle.state.queens.size(), _puzzle.state.shown.size(), _puzzle.hints_left()]))
			_at(10.0, _shot)
			_end = 10.2
		"solve":
			for k in n:
				_at(1.0 + k * 0.5, _seat.bind(_answer(k)))
			var done: float = 1.0 + n * 0.5
			for k in 12:
				_at(done + 0.3 + k * 0.4, _shot)
			_ms_from = done
			_end = done + 5.4
		"restore":
			_at(1.5, func() -> void: _puzzle.restore_completed_board())
			_at(2.0, _shot)
			_end = 2.2
		"perf":
			for k in n / 2:
				_at(1.0 + k * 0.5, _seat.bind(_answer(k)))
			_ms_from = 1.0 + n / 2 * 0.5 + 2.5
			_end = _ms_from + 3.0
