extends SceneTree

## Shots and probes of Toy Cannons (built as Toy Train), played through the board's own input path
## (a touch pressed and let go on an engine). Windowed, one at a time:
##
##     godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_train.gd -- [d=0..3] [mode] [rm] [out=<dir>]
##
## Modes: `rest` (the entrance and the rug); `play` (the state's own hand,
## shot with engines on the loop, a block in the air and one in the siding);
## `refuse` (a buried engine tapped, then the loop filled and one more);
## `hint` (the bulb); `solve` (the deal's own line to the win, the picture
## put back and the seal); `jam` (Insane: the shed emptied carelessly until
## the siding is full, the card, Try again); `reset`; `restore` (a day
## reopened already won); `howto` (the tutorial's pages as they play).
## Frames go to <dir>/tt_<mode>_d<level>_<n>.png; every mode prints the peak
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
var _auto := ""
var _line_i := 0
var _shots_left := 0
var _shot_every := 0.0
var _shot_next := 0.0

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
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://_shot_tt_progress.cfg"))
	progress.path = "user://_shot_tt_progress.cfg"
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
			if e.id == "train":
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
	_drive()
	if _shots_left > 0 and _t >= _shot_next:
		_shots_left -= 1
		_shot_next = _t + _shot_every
		_shot()
	if _t >= _ms_from and _t < _end:
		_ms_sum += delta * 1000.0
		_ms_n += 1
		_draws_max = maxi(_draws_max, int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)))
	if _t >= _end:
		if _ms_n > 0:
			print("frames: draw calls peak %d, mean %.2f ms over %d frames" % [_draws_max, _ms_sum / maxf(_ms_n, 1), _ms_n])
		var st = _puzzle.state
		print("board: band ", st.band, " ", st.w, "x", st.h, " ", st.name_key, " left ", st.left, "/", st.count(), " engines ", st.colour.size(),
			" taps ", st.taps, " par ", st.par, ", parked ", st.parked(), ", jammed ", st.jammed, ", out ", _puzzle.out_of_hearts,
			", done ", _puzzle.is_done(), ", solved ", st.is_solved(), ", hints ", _puzzle.hints_left(), ", pill '", _puzzle.pill_text(), "'")
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
	var path := "%s/tt_%s_d%d_%d%s.png" % [_dir, _mode, _level, _n, tag]
	root.get_texture().get_image().save_png(path)
	var st = _puzzle.state
	print("saved ", path, "  t ", snappedf(_t, 0.01), " toast: ", _puzzle._toast, "  left ", st.left, " taps ", st.taps,
		" loop ", st.loop.size(), " parked ", st.parked(), " draws ", int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)))

func _tap(e: int) -> void:
	if e < 0:
		return
	var at: Vector2 = _puzzle.engine_screen(e)
	for down in [true, false]:
		var ev := InputEventScreenTouch.new()
		ev.index = 0
		ev.pressed = down
		ev.position = at
		_puzzle._gui_input(ev)

## A hand that plays by itself every frame: `hand` sends the state's own
## pick whenever the loop has room for two more, `line` the deal's own line
## an engine at a time, `careless` every front of the shed as fast as it can.
func _drive() -> void:
	var st = _puzzle.state
	if _auto == "" or _puzzle.is_done() or _puzzle.out_of_hearts:
		return
	match _auto:
		"hand":
			if st.loop.size() + st.gate.size() < 3:
				_tap(st.hint())
		"line":
			if st.idle() and _line_i < st.line.size():
				_tap(st.line[_line_i])
				_line_i += 1
		"careless":
			for column: PackedInt32Array in st.sheds:
				if not column.is_empty() and st.judge(column[0]) == 0:
					_tap(column[0])
					break

func _script() -> void:
	var st = _puzzle.state
	match _mode:
		"rest":
			_at(0.3, _shot)
			_at(0.6, _shot)
			_at(2.2, _shot)
			_end = 3.0
		"play":
			_at(1.6, func() -> void: _auto = "hand")
			_at(2.0, func() -> void:
				_shots_left = 7
				_shot_every = 0.9
				_shot_next = _t)
			_end = 9.5
		"refuse":
			_at(1.6, func() -> void:
				var column: PackedInt32Array = st.sheds[0]
				_tap(column[1]))
			_at(1.7, _shot)
			_at(2.2, func() -> void: _auto = "careless")
			_at(3.4, _shot)
			_at(4.4, _shot)
			_end = 5.0
		"hint":
			_at(1.6, func() -> void: _host.action_hint() if _host.has_method("action_hint") else _puzzle.hint())
			_at(1.8, _shot)
			_at(3.0, _shot)
			_end = 4.0
		"solve":
			_ms_from = 2.0
			_at(1.4, func() -> void: _auto = "hand")
			_end = 200.0
			_watch_win()
		"jam":
			_at(1.4, func() -> void: _auto = "careless")
			_end = 200.0
			_watch_jam()
		"reset":
			_at(1.4, func() -> void: _auto = "hand")
			_at(4.0, func() -> void: _auto = "")
			_at(8.5, _shot)
			_at(8.6, func() -> void: _puzzle.reset_board())
			_at(8.9, _shot)
			_at(10.0, _shot)
			_end = 10.5
		"restore":
			_at(1.0, func() -> void:
				_puzzle.completed_record = {"taps": st.par}
				_puzzle.restore_completed())
			_at(1.3, _shot)
			_end = 2.0
		"howto":
			_at(0.6, func() -> void: _host._show_tutorial())
			var t := 1.0
			for k in 4:
				_at(t + 3.0, _shot)
				_at(t + 6.5, _shot)
				_at(t + 6.7, func() -> void:
					var how := _host.get_node_or_null("HowToPlay")
					if how != null:
						how._turn(1))
				t += 7.0
			_end = t + 0.5

var _won_at := -1.0
func _watch_win() -> void:
	_at(_t + 0.1, func() -> void:
		if _puzzle.is_done() and _won_at < 0.0:
			_won_at = _t
			print("won at ", snappedf(_t, 0.01), " taps ", _puzzle.state.taps, " par ", _puzzle.state.par)
			_at(_t + 0.5, _shot)
			_at(_t + 1.2, _shot)
			_at(_t + 2.2, _shot)
			_at(_t + 4.0, _shot)
			_end = _t + 4.5
		elif _won_at < 0.0:
			if int(_t * 10.0) % 60 == 0:
				_shot()
			_watch_win())

func _watch_jam() -> void:
	_at(_t + 0.1, func() -> void:
		if _puzzle.out_of_hearts and _won_at < 0.0:
			_won_at = _t
			print("jammed at ", snappedf(_t, 0.01))
			_at(_t + 0.3, _shot)
			_at(_t + 2.2, _shot)
			_at(_t + 2.6, func() -> void: _puzzle.try_again())
			_at(_t + 3.6, _shot)
			_end = _t + 4.0
		elif _puzzle.is_done():
			print("won, no jam")
			_end = _t + 0.2
		elif _won_at < 0.0:
			_watch_jam())
