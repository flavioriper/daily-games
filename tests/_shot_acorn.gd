extends SceneTree

## Shots and probes of Golden Acorn, played through the board's own input
## path (a touch pressed and let go on a plate). Windowed, one at a time:
##
##     godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_acorn.gd -- [d=0..3] [mode] [rm] [out=<dir>] [lang=pt]
##
## Modes: `rest` (the entrance and the first question); `play` (every
## question locked, right and wrong by turns: each reveal, each swap, the
## win); `perfect` (every one right: the seal); `hint` (the bulb, then a
## pick from the two left); `out` (the Climb: wrong until the hearts are
## gone, the card, Try again); `doc` (a daily whose questions are a published
## day's: a document is put in the backend's cache as the server would write
## it, and taken out again); `restore` (a day reopened already played, one
## wrong); `bank` (headless-safe: prints a week of every
## band's questions, no shots).
## Frames go to <dir>/ac_<mode>_d<level>_<n>.png; every mode prints the peak
## draw calls and the mean frame from 0.5 s on.

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
		elif a.begins_with("lang="):
			load("res://core/locale.gd").set_current(a.substr(5))
		else:
			_mode = a
	if _mode == "bank":
		return
	var progress = load("res://core/progress.gd")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://_shot_ac_progress.cfg"))
	progress.path = "user://_shot_ac_progress.cfg"
	for e in load("res://ui/registry.gd").PUZZLES:
		progress.mark_tutorial_seen(String(e.id))
	var main: Node = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	_menu = main.get_node("UI/Menu")

func _process(delta: float) -> bool:
	if _mode == "bank":
		_bank()
		quit()
		return true
	_t += delta
	if not _opened:
		_opened = true
		_t = 0.0
		# A probe plays the bank: the day's own questions stay on the server.
		load("res://core/backend.gd").stop()
		if _mode == "doc":
			_plant_doc()
		var entry: Dictionary = {}
		for e in load("res://ui/registry.gd").PUZZLES:
			if e.id == "acorn":
				entry = e
		if _reduce:
			load("res://core/motion.gd").reduce = true
		_menu._open_at(entry, _level)
		_host = _menu.get_child(_menu.get_child_count() - 1)
		_puzzle = _host._puzzle
		# The real pointer over the window must not play the board.
		_puzzle.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
		print("board: band ", st.band, " source ", st.source, " question ", st.index + 1, "/", st.count(), " locked ", st.results.size(),
			" right ", st.rights(), ", hearts ", _puzzle.hearts, "/", _puzzle.max_hearts,
			", out ", _puzzle.out_of_hearts, ", done ", _puzzle.is_done(), ", solved ", _puzzle.is_solved(),
			", hints ", _puzzle.hints_left(), ", label ", _puzzle.check_label())
		print("share:\n", _puzzle.share_glyphs())
		_cleanup()
		quit()
		return true
	return false

func _cleanup() -> void:
	for n in root.get_children():
		var card := n.find_child("OutOfHearts", true, false)
		if card != null:
			card.queue_free()
	load("res://core/motion.gd").reduce = false

func _at(t: float, what: Callable) -> void:
	_plan.append([t, what])
	_plan.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))

func _shot(tag := "") -> void:
	RenderingServer.force_draw()
	_n += 1
	var path := "%s/ac_%s_d%d_%d%s.png" % [_dir, _mode, _level, _n, tag]
	root.get_texture().get_image().save_png(path)
	var st = _puzzle.state
	print("saved ", path, "  question ", st.index + 1, " ", st.question().get("id", "?"), " right ", st.rights())

## A tap on shown place `place`, as a finger makes it.
func _tap(place: int) -> void:
	for down in [true, false]:
		var ev := InputEventScreenTouch.new()
		ev.index = 0
		ev.pressed = down
		ev.position = _puzzle.plate_point(place)
		_puzzle._gui_input(ev)

## A wrong shown place of the question on the card.
func _wrong() -> int:
	for i in 4:
		if i != _puzzle.state.right_place() and not _puzzle.state.is_cut(i):
			return i
	return 0

## From `t`: every question answered (`right_when` says which ones rightly),
## a shot of each reveal. Returns when the last has been read.
func _answer_all(t: float, right_when: Callable, shots := true) -> float:
	# (The deal follows the open by a frame: the count is the band's.)
	var n: int = load("res://puzzles/acorn_state.gd").ASKS[_level]
	for k in n:
		_at(t, func() -> void:
			if _puzzle.out_of_hearts or _puzzle.is_done():
				return
			_tap(_puzzle.state.right_place() if right_when.call(k) else _wrong()))
		_at(t + 0.35, func() -> void: _host._on_check())
		if shots:
			_at(t + 1.9, _shot)
		_at(t + 2.0, func() -> void: _host._on_check())
		t += 2.9
	return t

func _script() -> void:
	match _mode:
		"rest":
			_at(0.25, _shot)
			_at(1.6, _shot)
			_at(1.7, func() -> void: _tap(1))
			_at(2.2, _shot)
			_end = 2.6
		"play":
			var t := _answer_all(1.6, func(k: int) -> bool: return k % 3 != 1)
			_at(t + 1.2, _shot)
			_end = t + 1.6
		"perfect":
			var t := _answer_all(1.6, func(_k: int) -> bool: return true, false)
			_at(t + 0.6, _shot)
			_at(t + 2.2, _shot)
			_end = t + 2.6
		"hint":
			_at(1.6, func() -> void: _host._on_hint())
			_at(2.2, _shot)
			_at(2.3, func() -> void: _tap(_puzzle.state.right_place()))
			_at(2.8, _shot)
			_end = 3.2
		"out":
			var t := _answer_all(1.6, func(_k: int) -> bool: return false)
			_at(8.0, _shot)
			_at(11.0, _shot)
			_at(11.2, func() -> void: _puzzle.try_again())
			_at(12.6, _shot)
			_end = minf(t, 13.4)
		"doc":
			_at(1.6, _shot)
			_at(1.7, _unplant_doc)
			_end = 2.0
		"restore":
			_at(0.6, func() -> void:
				var n: int = _puzzle.state.count()
				var picks := []
				var rights := []
				for i in n:
					var right := i != 2
					rights.append(right)
					picks.append(_puzzle.state.right_place(i) if right else (_puzzle.state.right_place(i) + 1) % 4)
				_puzzle.completed_record = {"picks": picks, "rights": rights, "set": _puzzle.state.set_id()}
				_puzzle.restore_completed())
			_at(1.2, _shot)
			_end = 1.6
		_:
			_end = 2.0

## Today's document as the server publishes it, built from another day's
## bank so it is plainly not what the bank would deal today.
func _doc_path() -> String:
	return "user://backend_cache/acorn-%d-content.json" % load("res://core/daily.gd").date_key()

func _plant_doc() -> void:
	var S = load("res://puzzles/acorn_state.gd")
	var bands := []
	for band in 4:
		bands.append(S.bank_band(19990101, band))
	DirAccess.make_dir_recursive_absolute("user://backend_cache")
	var f := FileAccess.open(_doc_path(), FileAccess.WRITE)
	f.store_string(JSON.stringify({"v": 1, "source": "model", "bands": bands}))
	f.close()

func _unplant_doc() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_doc_path()))

## A week of every band from the bank, as the server and a phone both deal it.
func _bank() -> void:
	var S = load("res://puzzles/acorn_state.gd")
	for day in range(20261008, 20261015):
		for band in 4:
			var line := "%d band %d:" % [day, band]
			for q: Dictionary in S.bank_band(day, band):
				line += " " + str(q.id)
			print(line)
