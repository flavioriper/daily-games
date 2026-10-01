extends SceneTree

## Shots and probes of Pinwheel, played through the board's own input path (a
## press on a pin, a release). Windowed, one at a time:
##
##     godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_pinwheel.gd -- [d=0..3] [mode] [rm] [out=<dir>]
##
## Modes: `rest` (the entrance, then the board at rest; on d=3 the ribbons),
## `press` (a finger held on a pin, then let go: the dip, the turn), `snag`
## (Hard or Insane: a piece turned home, then tapped again -- the catch, the
## heart splitting, the button sewn on), `out` (snags until the hearts run
## out: the dusk, the card, then Try again), `ribbon` (Insane: the pin with
## the most tied below it tapped -- the tug down the ribbons), `right` (tidying
## taps in a row with each gag forced once: combo, the bubble, confetti at 4,
## whirl, love, butterfly, then an undo on Easy), `solve` (every piece turned
## home top-down through the pins, then the party: kite, confetti, the cat,
## the seal, on Ribbons the ribbons slipping loose), `restore` (a solved day
## reopened flawless: the cat asleep, the seal), `perf` (rest, no shots).
## Frames go to <dir>/pw_<mode>_d<level>_<n>.png. Every mode prints the peak
## draw calls from 0.5 s on.

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
		else:
			_mode = a
	var progress = load("res://core/progress.gd")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://_shot_pw_progress.cfg"))
	progress.path = "user://_shot_pw_progress.cfg"
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
			if e.id == "pinwheel":
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
		var st = _puzzle._state
		print("board: ", st.cols, "x", st.rows, " band ", st.difficulty, ", cell ", _puzzle._cell(),
			", pieces ", st.shapes.size(), ", ribbons ", st.ribbons.size(), ", hearts ", _puzzle.hearts,
			"/", _puzzle.max_hearts, ", out ", _puzzle.out_of_hearts, ", done ", _puzzle.is_done(),
			", solved ", st.is_solved(), ", hints ", _puzzle.hints_left(), ", can_undo ", _puzzle.can_undo(),
			", sewn ", _sewn(), ", flawless ", _puzzle._flawless, ", win_delay ", _puzzle.win_delay())
		print("tip: ", _puzzle.tip_line().text)
		print("share: ", _puzzle.share_glyphs().replace("\n", " / "))
		_cleanup()
		quit()
		return true
	return false

func _cleanup() -> void:
	for n in root.get_children():
		var card := n.find_child("OutOfHearts", true, false)
		if card != null:
			card.queue_free()

func _sewn() -> int:
	var n := 0
	for p in _puzzle._state.shapes.size():
		if _puzzle._state.is_tacked(p):
			n += 1
	return n

func _at(t: float, what: Callable) -> void:
	_plan.append([t, what])
	_plan.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))

func _shot(tag := "") -> void:
	RenderingServer.force_draw()
	_n += 1
	var path := "%s/pw_%s_d%d_%d%s.png" % [_dir, _mode, _level, _n, tag]
	root.get_texture().get_image().save_png(path)
	print("saved ", path, "  tip: ", _puzzle.tip_line().text)

# --- the hand ---

func _mouse(pos: Vector2, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = pos
	_puzzle._gui_input(ev)

func _pin(p: int) -> Vector2:
	return _puzzle._pin_point(p)

func _tap(p: int) -> void:
	_mouse(_pin(p), true)
	_mouse(_pin(p), false)

## Whether piece `p` hangs from a ribbon whose top is not home yet.
func _waits(p: int) -> bool:
	var st = _puzzle._state
	for r in st.ribbons:
		if int(r.to) == p:
			var a := int(r.from)
			return st.steps_home(a) != 0 and not st.is_tacked(a) or _waits(a)
	return false

## The next tap on the way home, top-down: a piece off home, not sewn, with
## everything above it home. -1 when none is left.
func _next_home() -> int:
	var st = _puzzle._state
	for p in st.shapes.size():
		if st.fixed(p) or st.is_tacked(p) or st.steps_home(p) == 0:
			continue
		if _waits(p):
			continue
		return p
	return -1

## A piece that is home and could be tapped (snags on Hard and Insane).
func _home_piece() -> int:
	var st = _puzzle._state
	for p in st.shapes.size():
		if st.would_snag(p):
			return p
	return -1

## The tap that tidies the frame the most right now (tried on the state and
## taken back), never a home piece. -1 when none tidies.
func _tidiest() -> int:
	var st = _puzzle._state
	var best := -1
	var gain := 0
	var now: int = _puzzle._trouble()
	for p in st.shapes.size():
		if st.fixed(p) or st.is_tacked(p) or st.steps_home(p) == 0:
			continue
		if not st.turn(p):
			continue
		var after: int = _puzzle._trouble()
		st.undo()
		if now - after > gain:
			gain = now - after
			best = p
	return best

## The pin with the most pieces tied below it.
func _most_tied() -> int:
	var st = _puzzle._state
	var best := -1
	var most := 0
	for p in st.shapes.size():
		var n: int = st.tugged(p).size()
		if n > most and not st.fixed(p):
			most = n
			best = p
	return best

# --- the scripts ---

func _script() -> void:
	match _mode:
		"rest":
			for k in 4:
				_at(0.15 + 0.25 * k, _shot)
			_at(2.5, _shot)
			_end = 3.5
		"perf":
			_end = 4.0
		"press":
			var p := [-1]
			_at(1.5, func() -> void:
				p[0] = _next_home()
				_mouse(_pin(p[0]), true))
			_at(1.62, _shot.bind("_down"))
			_at(1.8, func() -> void: _mouse(_pin(p[0]), false))
			_at(1.86, _shot)
			_at(1.98, _shot)
			_at(2.3, _shot)
			_end = 3.0
		"snag":
			var p := [-1]
			_at(1.2, func() -> void:
				p[0] = _next_home()
				# Turn it home first, one tap at a time.
				while _puzzle._state.steps_home(p[0]) > 0:
					_puzzle._state.turn(p[0])
				_puzzle._state.recompute()
				_puzzle._refresh())
			_at(1.6, func() -> void:
				print("snag on piece %d, hearts %d" % [p[0], _puzzle.hearts])
				_tap(p[0]))
			for k in 6:
				_at(1.66 + 0.1 * k, _shot)
			_at(2.6, _shot)
			_at(2.7, func() -> void:
				print("after: hearts %d, sewn %s, busy %s, can_undo %s" % [_puzzle.hearts,
					_puzzle._state.is_tacked(p[0]), _puzzle.busy(), _puzzle.can_undo()])
				_tap(p[0]))
			_at(2.8, _shot)
			_end = 3.4
		"out":
			for k in 4:
				_at(1.0 + 0.9 * k, func() -> void:
					var st = _puzzle._state
					var p := _home_piece()
					if p < 0:
						p = _next_home()
						while st.steps_home(p) > 0:
							st.turn(p)
						st.recompute()
						_puzzle._refresh()
					_tap(p))
			_at(4.4, _shot)
			_at(5.4, _shot)
			_at(5.8, _shot)
			_at(6.0, func() -> void:
				print("out: hearts %d, out %s, can_reset %s, sewn %d" % [_puzzle.hearts, _puzzle.out_of_hearts, _puzzle.can_reset(), _sewn()])
				_cleanup()
				_puzzle.try_again())
			_at(6.2, _shot)
			_at(7.2, _shot)
			_end = 7.5
		"ribbon":
			var p := [-1]
			_at(1.2, func() -> void:
				p[0] = _most_tied()
				print("ribbon: pin %d tugs %s" % [p[0], str(_puzzle._state.tugged(p[0]))])
				_tap(p[0]))
			for k in 6:
				_at(1.24 + 0.07 * k, _shot)
			_at(2.2, _shot)
			_end = 2.8
		"right":
			var gags := [0, 1, 2, -2, -2, -2]
			for k in gags.size():
				var g: int = gags[k]
				_at(1.0 + 1.9 * k, func() -> void:
					var p := _tidiest()
					if p < 0:
						print("right %d: nothing tidies" % k)
						return
					_puzzle.force_gag = g
					_tap(p)
					_puzzle.force_gag = -2
					print("right %d: piece %d, streak %d, combo %d, trouble %d" % [k, p,
						_puzzle._streak, _puzzle._combo_n, _puzzle._trouble()]))
				_at(1.6 + 1.9 * k, _shot)
				_at(2.3 + 1.9 * k, _shot)
			_at(12.6, func() -> void:
				print("undo: ", _puzzle.undo()))
			_at(12.7, _shot)
			_end = 13.2
		"solve":
			for k in 60:
				_at(1.0 + 0.32 * k, func() -> void:
					if _puzzle.is_done():
						return
					var p := _next_home()
					if p >= 0:
						_tap(p))
			# The party is shot off the solve itself, whenever it lands.
			_at(0.9, func() -> void:
				_puzzle.solved.connect(func() -> void:
					var base := _t
					for s in [0.3, 0.7, 1.1, 1.5, 2.0, 2.6, 3.3]:
						_at(base + s, _shot)
					_end = base + 3.8))
			_end = 25.0
		"restore":
			_at(0.2, func() -> void:
				_puzzle.completed_record = {"hearts": maxi(0, _puzzle.max_hearts - 1), "flawless": true}
				_puzzle.restore_completed_board())
			_at(1.0, _shot)
			_end = 1.5
