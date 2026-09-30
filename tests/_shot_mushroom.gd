extends SceneTree

## Shots and probes of Mushroom Patch, played through the board's own input
## path (press and release in board coordinates; the mushroom chip is armed,
## so a tap plants). Windowed, one at a time:
##
##     godot --path . --resolution 810x1440 --always-on-top --rendering-driver opengl3_angle --script res://tests/_shot_mushroom.gd -- [d=0..3] [mode] [rm] [out=<dir>]
##
## Modes: `rest` (the patch as dealt; on Insane the rings growing in, then a
## number held), `right` (the answer's mushrooms in reading order, one every
## 0.8 s: streak, bubble, gags, flowers), `wrong` (Hard and Insane: a wrong
## mushroom until the hearts run out, shots mid-wilt, on the card and after
## Try again), `solve` (every mushroom planted to the win screen, the party
## run out), `restore` (a solved day reopened). Frames go to
## <dir>/mp_<mode>_d<level>_<n>.png. Every mode prints the peak draw calls
## from 0.5 s on (or its own window).

const SHOT_DIR := "/private/tmp/claude-501/-Users-flavioriper-dev-daily/bf1fb280-2fc8-4159-9f7c-20f23809da0e/scratchpad"

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
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://_shot_mp_progress.cfg"))
	progress.path = "user://_shot_mp_progress.cfg"
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
			if e.id == "mushroom":
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
		print("board: %dx%d band %d, rings %d of %d givens, %d mushrooms left of %d, shown %d, hearts %d/%d, out %s, done %s, hints %d, streak %d" % [
			st.n, st.n, st.band, st.rings.size(), st.given.size(), st.left(), st.mushrooms.size(), st.shown.size(),
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
	var path := "%s/mp_%s_d%d_%d%s.png" % [_dir, _mode, _level, _n, tag]
	root.get_texture().get_image().save_png(path)
	print("saved ", path)

# --- the hand ---

func _press(cell: Vector2i, down: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = down
	ev.position = _puzzle.cell_centre(cell)
	_puzzle._gui_input(ev)

func _tap(cell: Vector2i) -> void:
	_press(cell, true)
	_press(cell, false)

func _plant(cell: Vector2i) -> void:
	_tap(cell)
	print("plant ", cell, " -> mark ", int(_puzzle.state.marks.get(cell, 0)), " hearts ", _puzzle.hearts)

func _answer() -> Array:
	var cells: Array = _puzzle.state.mushrooms.keys()
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y or (a.y == b.y and a.x < b.x))
	return cells

## A covered, unmarked cell with no mushroom.
func _wrong_cell() -> Vector2i:
	var st = _puzzle.state
	for y in st.n:
		for x in st.n:
			var c := Vector2i(x, y)
			if not st.mushrooms.has(c) and not st.given.has(c) and not st.marks.has(c):
				return c
	return Vector2i(-1, -1)

## The first ring given, else the first given.
func _a_number() -> Vector2i:
	var st = _puzzle.state
	for g in st.given:
		if st.rings.has(g):
			return g
	for g in st.given:
		if int(st.given[g]) > 0:
			return g
	return Vector2i(-1, -1)

func _script() -> void:
	var cells := _answer()
	match _mode:
		"rest":
			_at(0.35, _shot.bind("_enter"))
			_at(1.3, _shot.bind("_rings"))
			_at(2.4, _shot)
			_at(2.6, func() -> void:
				print("hold ", _a_number(), " ring ", _puzzle.state.rings.has(_a_number()))
				_press(_a_number(), true))
			_at(2.9, _shot.bind("_reach"))
			_at(3.0, func() -> void: _press(_a_number(), false))
			_end = 3.3
		"right":
			for k in mini(cells.size(), 8):
				_at(1.2 + k * 0.8, _plant.bind(cells[k]))
				_at(1.2 + k * 0.8 + 0.6, _shot)
			_end = 1.2 + mini(cells.size(), 8) * 0.8 + 0.8
		"wrong":
			_at(1.0, _plant.bind(cells[0]))
			for k in 3:
				var t0 := 1.8 + k * 2.4
				_at(t0, func() -> void:
					var c := _wrong_cell()
					print("wrong mushroom at ", c, " hearts ", _puzzle.hearts)
					_plant(c))
				_at(t0 + 0.8, _shot.bind("_worry"))
				_at(t0 + 1.45, _shot.bind("_wilt"))
				_at(t0 + 2.1, _shot)
			_at(10.0, _shot.bind("_card"))
			_at(10.2, func() -> void:
				if _puzzle.out_of_hearts:
					_puzzle.try_again()
				print("after try again: hearts %d out %s shown %d hints %d" % [_puzzle.hearts, _puzzle.out_of_hearts, _puzzle.state.shown.size(), _puzzle.hints_left()]))
			_at(11.4, _shot)
			_end = 11.6
		"solve":
			for k in cells.size():
				_at(1.0 + k * 0.4, _plant.bind(cells[k]))
			var done: float = 1.0 + cells.size() * 0.4
			for k in 12:
				_at(done + 0.3 + k * 0.4, _shot)
			_ms_from = done
			_end = done + 5.4
		"restore":
			_at(1.5, func() -> void: _puzzle.restore_completed_board())
			_at(2.0, _shot)
			_end = 2.2
