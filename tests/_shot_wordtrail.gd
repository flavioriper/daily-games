extends SceneTree

## Shots and probes of Word Trail, played through the board's own input (a
## press, drags from tile to tile, a release -- the mouse events land on
## _gui_input in the board's local coordinates). Windowed, one at a time:
##
##     godot --path . --resolution 810x1440 --always-on-top --rendering-driver opengl3_angle --script res://tests/_shot_wordtrail.gd -- [d=0..3] [mode] [rm] [out=<dir>]
##
## Modes: `rest` (the field as dealt, a trail under the finger), `words`
## (a word every 1.6 s with shots as each lands -- the rewards and gags),
## `miss` (three wrong trails on a band that counts them, the dandelion),
## `out` (every wish spent: the droop, the card, one more wish, spent again,
## then Show the words), `solve` (every word, shots through the party),
## `night` (Insane: a finger held and dragged in the dark, then let go),
## `restore` (a solved day reopened). Frames go to
## <dir>/wt_<mode>_d<level>_<n>.png. Every mode prints the peak draw calls.

## Pass out=<dir> for a session scratchpad; this is only the fallback.
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
var _end := 6.0
var _ms_from := 0.5
var _ms_sum := 0.0
var _ms_n := 0
var _draws_max := 0
var _rng := RandomNumberGenerator.new()

func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_rng.seed = 7
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
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://_shot_wt_progress.cfg"))
	progress.path = "user://_shot_wt_progress.cfg"
	for e in load("res://ui/registry.gd").PUZZLES:
		progress.mark_tutorial_seen(String(e.id))
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
			if e.id == "wordtrail":
				entry = e
		load("res://core/motion.gd").reduce = _reduce
		_menu._open_at(entry, _level)
		_host = _menu.get_child(_menu.get_child_count() - 1)
		_puzzle = _host._puzzle
		if _host.has_node("HowToPlay"):
			_host.get_node("HowToPlay").free()
		var st = _puzzle._state
		var ws: Array = []
		for w in st.words:
			ws.append(w["word"])
		print("words: ", ws, " n ", st.n, " wishes ", st.wishes, " night ", st.night(), " hints ", _puzzle.hints_left())
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
		print("board: found %d/%d, misses %d, wishes left %d, out %s, done %s, solved %s, hints %d, shown %s" % [
			st.found_count(), st.words.size(), st.misses, st.wishes_left(), _puzzle.out_of_hearts,
			_puzzle.is_done(), _puzzle.is_solved(), _puzzle.hints_left(), st.shown.keys()])
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
	var path := "%s/wt_%s_d%d_%d%s.png" % [_dir, _mode, _level, _n, tag]
	root.get_texture().get_image().save_png(path)
	print("saved ", path)

# --- the hand ---

func _local(cell: Vector2i) -> Vector2:
	return _puzzle.cell_to_local(cell.y, cell.x)

func _mouse(pos: Vector2, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.position = pos
	e.pressed = pressed
	_puzzle._gui_input(e)

func _move(pos: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = pos
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	_puzzle._gui_input(e)

## A whole trail at once: press on the first cell, drag through the rest,
## let go on the last (or off the field when `cancel`).
func _trace(path: Array, cancel := false) -> void:
	if path.is_empty():
		return
	_mouse(_local(path[0]), true)
	for k in range(1, path.size()):
		_move(_local(path[k]))
	if cancel:
		_mouse(Vector2(-200, -200), false)
	else:
		_mouse(_local(path[-1]), false)
	print("traced %d tiles -> found %d, misses %d, left %d" % [path.size(), _puzzle._state.found_count(),
		_puzzle._state.misses, _puzzle._state.wishes_left()])

## A trail that is not a word but could have been one, never tried: a
## random walk over free tiles as long as some hiding word.
func _wrong() -> Array:
	var st = _puzzle._state
	for tries in 4000:
		var want := -1
		for w in st.words:
			if not w["found"]:
				want = (w["path"] as Array).size()
				break
		if want < 0:
			return []
		var free: Array = []
		for c in st.letters:
			if st.can_trace(c):
				free.append(c)
		var path: Array = [free[_rng.randi_range(0, free.size() - 1)]]
		while path.size() < want:
			var opts: Array = []
			for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var k: Vector2i = path[-1] + d
				if st.can_trace(k) and not path.has(k):
					opts.append(k)
			if opts.is_empty():
				break
			path.append(opts[_rng.randi_range(0, opts.size() - 1)])
		if path.size() != want or st.tried.has(st._key(path)):
			continue
		var is_word := false
		for w in st.words:
			if w["path"] == path:
				is_word = true
		if not is_word:
			return path
	return []

func _next_word() -> Array:
	for w in _puzzle._state.words:
		if not w["found"]:
			return w["path"]
	return []

func _script() -> void:
	match _mode:
		"rest":
			_at(0.1, _shot.bind("_enter"))
			_at(1.2, func() -> void:
				var p: Array = _next_word()
				_mouse(_local(p[0]), true)
				for k in range(1, p.size() - 1):
					_move(_local(p[k])))
			_at(1.5, _shot.bind("_trail"))
			_at(1.6, func() -> void: _mouse(Vector2(-200, -200), false))
			_at(2.4, _shot)
			_end = 2.6
		"words":
			var count: int = _puzzle._state.words.size() - 1
			for k in count:
				var t0 := 1.0 + k * 1.6
				_at(t0, func() -> void: _trace(_next_word()))
				_at(t0 + 0.45, _shot.bind("_lock"))
				_at(t0 + 0.9, _shot.bind("_gag"))
			_end = 1.0 + count * 1.6 + 0.3
		"miss":
			for k in 3:
				var t0 := 1.0 + k * 1.2
				_at(t0, func() -> void: _trace(_wrong()))
				_at(t0 + 0.2, _shot.bind("_shake"))
				_at(t0 + 0.8, _shot.bind("_seed"))
			_at(4.8, func() -> void: _trace(_wrong(), true))
			_end = 5.2
		"out":
			var wishes: int = _puzzle._state.wishes
			for k in wishes:
				_at(1.0 + k * 0.5, func() -> void: _trace(_wrong()))
			var t_out := 1.0 + wishes * 0.5
			_at(t_out + 0.6, _shot.bind("_droop"))
			_at(t_out + 2.2, _shot.bind("_card"))
			_at(t_out + 2.4, func() -> void:
				print("out %s, card %s" % [_puzzle.out_of_hearts, is_instance_valid(_puzzle._card)])
				_puzzle.wish_back())
			_at(t_out + 2.7, _shot.bind("_back"))
			for k in 3:
				_at(t_out + 3.4 + k * 0.5, func() -> void: _trace(_wrong()))
			_at(t_out + 7.0, _shot.bind("_card2"))
			_at(t_out + 7.2, func() -> void: _puzzle.show_words())
			_at(t_out + 8.6, _shot.bind("_showing"))
			_at(t_out + 11.0, _shot.bind("_shown"))
			_end = t_out + 11.2
		"solve":
			var count: int = _puzzle._state.words.size()
			for k in count:
				_at(1.0 + k * 0.5, func() -> void: _trace(_next_word()))
			var t_win := 1.0 + count * 0.5
			for k in 14:
				_at(t_win + k * 0.45, _shot)
			_ms_from = t_win
			_end = t_win + 14 * 0.45 + 0.2
		"night":
			_at(0.8, _shot.bind("_dark"))
			_at(1.0, func() -> void:
				var p: Array = _next_word()
				_mouse(_local(p[0]), true))
			_at(1.3, _shot.bind("_lamp"))
			_at(1.4, func() -> void:
				var p: Array = _next_word()
				for k in range(1, 4):
					_move(_local(p[k])))
			_at(1.7, _shot.bind("_walk"))
			_at(1.8, func() -> void: _mouse(Vector2(-200, -200), false))
			_at(2.4, _shot.bind("_after"))
			_at(3.6, _shot.bind("_faded"))
			_at(3.8, func() -> void: _trace(_next_word()))
			_at(4.8, _shot.bind("_word"))
			_end = 5.0
		"restore":
			_at(1.0, func() -> void:
				_puzzle.completed_record = {"misses": 2, "more": false}
				_puzzle.restore_completed())
			_at(1.8, _shot)
			_end = 2.0
