extends SceneTree

## Shots and probes of Sudoku, played through the board's own input path (a
## tap on a cell selects it, `pick` is the pad's chip). Windowed, one at a
## time:
##
##     godot --path . --resolution 810x1440 --always-on-top --rendering-driver opengl3_angle --script res://tests/_shot_sudoku.gd -- [d=0..3] [mode] [rm] [out=<dir>]
##
## Modes: `rest` (the grid as dealt; on Insane the hills rising, then a hill
## selected), `right` (the answer's numbers in reading order, one every
## 0.7 s: streak, bubble, gags, stickers), `wrong` (Hard and Insane: a wrong
## number until the hearts run out, shots mid-tumble, on the card and after
## Try again), `solve` (every number placed to the win screen, the party run
## out), `restore` (a solved day reopened). Frames go to
## <dir>/sd_<mode>_d<level>_<n>.png. Every mode prints the peak draw calls
## from 0.5 s on (or its own window).

const SHOT_DIR := "/private/tmp/claude-501/-Users-flavioriper-dev-daily/2133b696-2f0c-4ef8-a61d-a185c6d59407/scratchpad"

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
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://_shot_sd_progress.cfg"))
	progress.path = "user://_shot_sd_progress.cfg"
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
			if e.id == "sudoku":
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
		var Gen = load("res://puzzles/sudoku_gen.gd")
		print("board: %dx%d band %d, %d givens, %d hills, %d empty, ruled %d, hearts %d/%d, out %s, done %s, hints %d, streak %d, cell %.1f" % [
			Gen.N, Gen.N, st.band, Array(st.given).filter(func(v): return v > 0).size(), Gen.hill_total(st.hills),
			Array(st.grid).count(0), st.ruled.size(),
			_puzzle.hearts, _puzzle.max_hearts, _puzzle.out_of_hearts, _puzzle.is_done(),
			_puzzle.hints_left(), _puzzle._streak, _puzzle._cell])
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
	var path := "%s/sd_%s_d%d_%d%s.png" % [_dir, _mode, _level, _n, tag]
	root.get_texture().get_image().save_png(path)
	print("saved ", path)

# --- the hand ---

func _select(i: int) -> void:
	var Gen = load("res://puzzles/sudoku_gen.gd")
	if _puzzle._sel == i:
		return
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = _puzzle.cell_to_local(i / Gen.N, i % Gen.N)
	_puzzle._gui_input(ev)
	ev = ev.duplicate()
	ev.pressed = false
	_puzzle._gui_input(ev)

func _put(i: int, d: int) -> void:
	_select(i)
	_puzzle.pick(d - 1)
	print("put %d at %d -> grid %d hearts %d" % [d, i, _puzzle.state.grid[i], _puzzle.hearts])

## The open cells in reading order.
func _open() -> Array:
	var out: Array = []
	for i in _puzzle.state.grid.size():
		if _puzzle.state.grid[i] == 0:
			out.append(i)
	return out

func _first_hill() -> int:
	var st = _puzzle.state
	for i in st.hills.size():
		if st.hills[i] >= 0:
			return i
	return 0

func _script() -> void:
	var cells := _open()
	var st = _puzzle.state
	match _mode:
		"rest":
			_at(0.35, _shot.bind("_enter"))
			_at(1.2, _shot.bind("_hills"))
			_at(2.2, _shot)
			_at(2.4, func() -> void: _select(_first_hill()))
			_at(2.7, _shot.bind("_reach"))
			_end = 3.0
		"right":
			var n := mini(cells.size(), 12)
			for k in n:
				var i: int = cells[k]
				_at(1.2 + k * 0.7, _put.bind(i, int(st.sol[i])))
				_at(1.2 + k * 0.7 + 0.45, _shot)
			_end = 1.2 + n * 0.7 + 0.8
		"wrong":
			_at(1.0, _put.bind(cells[0], int(st.sol[cells[0]])))
			for k in 3:
				var t0 := 1.8 + k * 2.2
				_at(t0, func() -> void:
					var i: int = _open()[0]
					var bad := (int(st.sol[i]) % 9) + 1
					while st.is_ruled(i, bad):
						bad = (bad % 9) + 1
					_put(i, bad))
				_at(t0 + 0.6, _shot.bind("_worry"))
				_at(t0 + 1.25, _shot.bind("_tumble"))
				_at(t0 + 1.9, _shot)
			_at(9.0, _shot.bind("_card"))
			_at(9.2, func() -> void:
				if _puzzle.out_of_hearts:
					_puzzle.try_again()
				print("after try again: hearts %d out %s ruled %d hints %d" % [_puzzle.hearts, _puzzle.out_of_hearts, st.ruled.size(), _puzzle.hints_left()]))
			_at(10.4, _shot)
			_end = 10.6
		"solve":
			for k in cells.size():
				var i: int = cells[k]
				_at(1.0 + k * 0.12, _put.bind(i, int(st.sol[i])))
			var done: float = 1.0 + cells.size() * 0.12
			for k in 12:
				_at(done + 0.3 + k * 0.4, _shot)
			_ms_from = done
			_end = done + 5.4
		"restore":
			_at(1.5, func() -> void: _puzzle.restore_completed_board())
			_at(2.0, _shot)
			_end = 2.2
