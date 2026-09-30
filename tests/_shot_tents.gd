extends SceneTree

## Shots and probes of Tents, played through the board's own input path
## (press, motion, release in board coordinates). Windowed, one at a time:
##
##     godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_shikaku.gd -- [d=0..3] [mode] [rm] [out=<dir>]
##
## Modes: `rest` (the board as dealt), `right` (the answer's tents pitched
## one a second: streak, lamps, gags, butterflies), `wrong` (a fair tent that
## is not the answer, again until the hearts run out: Hard and Insane),
## `sweep` (a row of cairns swept), `solve` (the answer to the win: clearing,
## stamp, party), `perf` (half the answer, then a quiet window).
## Frames go to <dir>/tn_<mode>_d<level>_<n>.png.

const SHOT_DIR := "/private/tmp/claude-501/-Users-flavioriper-dev-daily/95dec8fe-d455-46d8-9499-4a8808ab22dc/scratchpad"

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
var _ms_from := 1e9
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
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://_shot_tn_progress.cfg"))
	progress.path = "user://_shot_tn_progress.cfg"
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
			if e.id == "tents":
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
		print("board: %dx%d, %d trees, %d oaks, %d tents, hearts %d/%d, out %s, done %s, streak %d, flies %d" % [
			_puzzle.w, _puzzle.h, _puzzle.state.tree_list.size(), _puzzle.state.oaks.size(), _puzzle.state.tents().size(),
			_puzzle.hearts, _puzzle.max_hearts, _puzzle.out_of_hearts, _puzzle.is_done(),
			_puzzle._streak, _puzzle._flies.size()])
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
	var path := "%s/tn_%s_d%d_%d%s.png" % [_dir, _mode, _level, _n, tag]
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

func _tap(t: float, cell: Vector2i) -> void:
	_at(t, func() -> void: _ev_press(_puzzle.cell_to_local(cell.y, cell.x), true))
	_at(t + 0.06, func() -> void: _ev_press(_puzzle.cell_to_local(cell.y, cell.x), false))

## A fair square that is not the answer's: beside a tree, touching no tent,
## its lines not full.
func _wrong_cell() -> Vector2i:
	var st = _puzzle.state
	for y in st.h:
		for x in st.w:
			var c := Vector2i(x, y)
			if st.trees.has(c) or st.mark_at(c) != 0 or st.solution.has(c):
				continue
			st.marks[c] = 1
			var fair: bool = st.tent_fair(c)
			st.marks.erase(c)
			if fair:
				return c
	return Vector2i(-1, -1)

func _script() -> void:
	match _mode:
		"rest":
			_at(2.5, _shot)
			_end = 2.7
		"right":
			var tents: Array = _puzzle.state.solution.duplicate()
			var n := mini(tents.size() - 1, 8)
			for k in n:
				_tap(1.5 + k * 0.9, tents[k])
				_at(1.5 + k * 0.9 + 0.55, _shot)
			_at(1.5 + n * 0.9 + 1.5, _shot)
			_at(1.5 + n * 0.9 + 3.0, _shot)
			_end = 1.5 + n * 0.9 + 3.2
		"wrong":
			for k in 3:
				var t0 := 1.5 + k * 1.6
				_at(t0, func() -> void:
					var c := _wrong_cell()
					print("wrong tent ", c)
					if c.x >= 0:
						_ev_press(_puzzle.cell_to_local(c.y, c.x), true)
						_ev_press(_puzzle.cell_to_local(c.y, c.x), false))
				_at(t0 + 0.45, _shot)
				_at(t0 + 1.2, _shot)
			_at(7.0, _shot)
			_at(7.3, func() -> void:
				_puzzle.try_again()
				print("after try again: hearts %d out %s tents %d" % [_puzzle.hearts, _puzzle.out_of_hearts, _puzzle.state.tents().size()]))
			_at(8.3, _shot)
			_end = 8.5
		"sweep":
			_at(1.5, func() -> void: _ev_press(_puzzle.cell_to_local(0, 0), true))
			for k in range(1, _puzzle.w):
				var x := k
				_at(1.5 + k * 0.05, func() -> void: _ev_motion(_puzzle.cell_to_local(0, x)))
			_at(1.5 + _puzzle.w * 0.05 + 0.05, func() -> void: _ev_press(_puzzle.cell_to_local(0, _puzzle.w - 1), false))
			_at(2.0, _shot)
			_at(2.6, _shot)
			_end = 2.8
		"solve":
			var tents: Array = _puzzle.state.solution.duplicate()
			for k in tents.size():
				_tap(1.0 + k * 0.3, tents[k])
			var done := 1.0 + tents.size() * 0.3
			for k in 9:
				_at(done + 0.4 + k * 0.45, _shot)
			_ms_from = done
			_end = done + 4.6
		"perf":
			var tents: Array = _puzzle.state.solution.duplicate()
			for k in tents.size() / 2:
				_tap(1.0 + k * 0.3, tents[k])
			_ms_from = 1.0 + tents.size() * 0.15 + 2.5
			_end = _ms_from + 3.0
