extends SceneTree

## Shots and probes of Button Box, played through the board's own input path (a
## touch pressed, dragged and let go). Windowed, one at a time:
##
##     godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_buttons.gd -- [d=0..3] [mode] [rm] [out=<dir>]
##
## Modes: `rest` (the entrance and the cloth); `play` (four taps of the
## state's own hand, shot in the air and landed); `refuse` (a sewn button
## tapped; the tin filled and one tap more); `hint` (the bulb, then Undo);
## `solve` (the hand's taps to the win); `out` (Insane: the taps spent
## carelessly, the card, Try again); `reset`; `restore` (a day reopened
## already sewn); `howto` (the tutorial's four pages as they play).
## Frames go to <dir>/bb_<mode>_d<level>_<n>.png; every mode prints the peak
## draw calls and the mean frame from 0.5 s on.

const SHOT_DIR := "/tmp"
const GAP := 0.55

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
		else:
			_mode = a
	var progress = load("res://core/progress.gd")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://_shot_bb_progress.cfg"))
	progress.path = "user://_shot_bb_progress.cfg"
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
			if e.id == "buttons":
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
		print("board: band ", st.band, " ", st.w, "x", st.h, " ", st.name_key, " sewn ", st.homes(), "/", st.count(), " taps ", st.taps,
			" par ", st.par, ", tin ", st.in_tin(), "/", st.capacity(), ", left ", _puzzle.moves_left, "/", _puzzle.max_moves,
			", out ", _puzzle.out_of_hearts, ", done ", _puzzle.is_done(), ", solved ", st.is_solved(), ", hints ", _puzzle.hints_left(),
			", can_undo ", _puzzle.can_undo(), ", pill '", _puzzle.pill_text(), "'")
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
	var path := "%s/bb_%s_d%d_%d%s.png" % [_dir, _mode, _level, _n, tag]
	root.get_texture().get_image().save_png(path)
	print("saved ", path, "  toast: ", _puzzle._toast, "  sewn ", _puzzle.state.homes(), " taps ", _puzzle.state.taps,
		" tin ", _puzzle.state.in_tin(), "/", _puzzle.state.capacity(), " left ", _puzzle.moves_left)

## A tap: a touch pressed and let go over `cell`, through the board's input.
func _tap(cell: int) -> void:
	var at: Vector2 = _puzzle.cell_centre(cell)
	for down in [true, false]:
		var ev := InputEventScreenTouch.new()
		ev.index = 0
		ev.pressed = down
		ev.position = at
		_puzzle._gui_input(ev)

func _touch(at: Vector2, down: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = 0
	ev.pressed = down
	ev.position = at
	_puzzle._gui_input(ev)

## The next tap of the state's own hand.
func _next() -> void:
	var i: int = _puzzle.state.hint()
	if i >= 0:
		_tap(i)

func _first(test: Callable) -> int:
	for i in _puzzle.state.slot.size():
		if _puzzle.state.slot[i] >= 0 and test.call(i):
			return i
	return -1

## A button out of place that no bare patch waits for: it can only go into
## the tin.
func _loose() -> int:
	var st = _puzzle.state
	return _first(func(i: int) -> bool: return st.cur[i] >= 0 and not st.is_home(i) and st._bare(st.cur[i]).is_empty())

func _script() -> void:
	var st = _puzzle.state
	match _mode:
		"rest":
			_at(0.3, _shot)
			_at(0.5, _shot)
			_at(2.0, _shot)
			_end = 3.0
		"play":
			_at(1.6, _next)
			_at(1.8, _shot)
			_at(2.4, _shot)
			_at(2.6, _next)
			_at(2.8, _shot)
			_at(3.4, _next)
			_at(4.0, _next)
			_at(4.25, _shot)
			_at(5.2, _shot)
			_end = 6.0
		"refuse":
			_at(1.6, func() -> void: _tap(_first(st.is_home) if _first(st.is_home) >= 0 else 0))
			_at(1.75, _shot)
			var t := 2.4
			for k in 8:
				_at(t, func() -> void:
					var i := _loose()
					if i >= 0:
						_tap(i))
				t += 0.5
			_at(t + 0.2, _shot)
			_end = t + 2.0
		"hint":
			_at(1.6, func() -> void: _host._on_hint())
			_at(1.75, _shot)
			_at(2.5, _shot)
			_at(2.8, func() -> void: _host._on_undo())
			_at(3.3, _shot)
			_end = 4.0
		"solve":
			var t := 1.4
			for k in st.par + 2:
				_at(t, _next)
				t += 0.45
			for dt in [-3.0, 0.0, 0.5, 1.0, 1.6, 2.6, 4.2]:
				_at(t + dt, _shot)
			_end = t + 5.2
		"out":
			var t := 1.6
			for k in _puzzle.max_moves * 3:
				_at(t, func() -> void:
					if _puzzle.moves_left <= 0:
						return
					var i := _loose()
					_tap(i if i >= 0 and st.in_tin() < st.capacity() else st.hint()))
				t += 0.12
			_at(2.4, _shot)
			_at(t + 0.6, _shot)
			_at(t + 2.4, _shot)
			_at(t + 2.8, func() -> void: _puzzle.try_again())
			_at(t + 3.6, _shot)
			_end = t + 4.2
		"reset":
			var t := 1.4
			for k in 4:
				_at(t, _next)
				t += 0.4
			_at(t + 0.4, func() -> void: _host._on_reset())
			_at(t + 0.5, _shot)
			_at(t + 1.4, _shot)
			_end = t + 2.0
		"howto":
			# the tutorial card as the ? opens it, each page shot twice as it plays
			_at(0.6, func() -> void: _host._show_tutorial())
			var t := 1.0
			for page in 4:
				_at(t + 4.2, _shot)
				_at(t + 7.5, _shot)
				_at(t + 7.7, func() -> void:
					if is_instance_valid(_host._tutorial):
						_host._tutorial._turn(1))
				t += 7.8
			_at(t + 0.2, func() -> void:
				if is_instance_valid(_host._tutorial):
					_host._tutorial.free())
			_end = t + 0.6
		"restore":
			_at(0.2, func() -> void:
				_puzzle.completed_record = {"taps": st.par + 2, "left": 0}
				_puzzle.restore_completed())
			_at(0.5, _shot)
			_end = 1.5
