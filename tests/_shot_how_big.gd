extends SceneTree

## Shots and probes of How Big?, played through the board's own input path
## (a touch pressed on the grip, dragged and let go). Windowed, one at a time:
##
##     godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_how_big.gd -- [d=0..3] [mode] [rm] [out=<dir>] [seed=<n>]
##
## Modes: `rest` (the entrance and the first pair); `drag` (the answer pulled
## to its least, its most and the truth); `lock` (a round locked 30% over:
## the reveal and the result card); `rounds` (every round locked a little
## off, each reveal and each swap, the win); `spot` (every round exact: the
## seal); `hint`; `reset`; `out` (Insane: every rung three times too big
## until the hearts are gone, the card, Try again); `restore` (a day reopened
## already played); `pairs` (headless-safe: prints a week of every band's
## rounds and their frames, no shots).
## Frames go to <dir>/hb_<mode>_d<level>_<n>.png; every mode prints the peak
## draw calls and the mean frame from 0.5 s on.

const SHOT_DIR := "/tmp"

var _t := 0.0
var _level := 0
var _mode := "rest"
var _reduce := false
var _dir := SHOT_DIR
var _seed := -1
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
		elif a.begins_with("seed="):
			_seed = int(a.substr(5))
		else:
			_mode = a
	if _mode == "pairs":
		return
	var progress = load("res://core/progress.gd")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://_shot_hb_progress.cfg"))
	progress.path = "user://_shot_hb_progress.cfg"
	for e in load("res://ui/registry.gd").PUZZLES:
		progress.mark_tutorial_seen(String(e.id))
	var main: Node = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	_menu = main.get_node("UI/Menu")

func _process(delta: float) -> bool:
	if _mode == "pairs":
		_pairs()
		quit()
		return true
	_t += delta
	if not _opened:
		_opened = true
		_t = 0.0
		var entry: Dictionary = {}
		for e in load("res://ui/registry.gd").PUZZLES:
			if e.id == "how_big":
				entry = e
		if _reduce:
			load("res://core/motion.gd").reduce = true
		_menu._open_at(entry, _level)
		_host = _menu.get_child(_menu.get_child_count() - 1)
		_puzzle = _host._puzzle
		if _seed >= 0:
			var rng := RandomNumberGenerator.new()
			rng.seed = _seed
			_puzzle.start(rng, _level)
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
		print("board: band ", st.band, " round ", st.index + 1, "/", st.round_count(), " locked ", st.results.size(),
			" total ", st.total(), "/", st.best_total(), ", hearts ", _puzzle.hearts, "/", _puzzle.max_hearts,
			", out ", _puzzle.out_of_hearts, ", done ", _puzzle.is_done(), ", solved ", _puzzle.is_solved(),
			", hints ", _puzzle.hints_left(), ", label ", _puzzle.check_label(), ", win_delay ", _puzzle.win_delay())
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
	var path := "%s/hb_%s_d%d_%d%s.png" % [_dir, _mode, _level, _n, tag]
	root.get_texture().get_image().save_png(path)
	var st = _puzzle.state
	print("saved ", path, "  round ", st.index + 1, " ", st.ref().id, " -> ", st.tgt().id,
		"  guess ", snappedf(_puzzle._guess(), 0.0001), " truth ", st.truth(), " total ", st.total())

func _touch(at: Vector2, down: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = 0
	ev.pressed = down
	ev.position = at
	_puzzle._gui_input(ev)

func _move(at: Vector2) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index = 0
	ev.position = at
	_puzzle._gui_input(ev)

## Drags the grip until the answer reads `times` the truth, through the
## board's input: press on the grip, eight steps, release.
func _size(times: float) -> void:
	var from: Vector2 = _puzzle.grip_point()
	var to: Vector2 = _puzzle.grip_for(_puzzle.state.truth() * times)
	_touch(from, true)
	for k in 8:
		_move(from.lerp(to, float(k + 1) / 8.0))
	_touch(to, false)

func _script() -> void:
	var st = _puzzle.state
	match _mode:
		"rest":
			_at(0.25, _shot)
			_at(0.45, _shot)
			_at(0.7, _shot)
			_at(2.0, _shot)
			_end = 3.0
		"drag":
			_at(1.4, func() -> void: _size(0.01))
			_at(1.6, _shot)
			_at(2.0, func() -> void: _size(100.0))
			_at(2.2, _shot)
			_at(2.6, func() -> void: _size(1.0))
			_at(2.8, _shot)
			_at(3.2, func() -> void:
				_touch(_puzzle.grip_point(), true)
				_move(_puzzle.grip_point() + Vector2(-12.0, -12.0)))
			_at(3.35, _shot)
			_at(3.5, func() -> void: _touch(_puzzle.grip_point(), false))
			_end = 4.2
		"lock":
			_at(1.4, func() -> void: _size(1.3))
			_at(1.8, func() -> void: _host._on_check())
			for dt in [0.15, 0.4, 0.75, 1.3, 2.2]:
				_at(1.8 + dt, _shot)
			_end = 4.6
		"rounds", "spot":
			var t := 1.4
			var offs := [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0] if _mode == "spot" else [1.1, 0.85, 1.6, 0.55, 1.02, 1.25, 0.9]
			for k in st.round_count():
				_at(t, _size.bind(float(offs[k % offs.size()])))
				_at(t + 0.25, _shot)
				_at(t + 0.4, func() -> void: _host._on_check())
				_at(t + 1.9, _shot)
				if k < st.round_count() - 1:
					_at(t + 2.1, func() -> void: _host._on_check())
					_at(t + 2.3, _shot)
				t += 3.0
			for dt in [0.4, 1.2, 2.4]:
				_at(t + dt, _shot)
			_end = t + 3.2
		"hint":
			_at(1.4, func() -> void: _host._on_hint())
			_at(1.6, _shot)
			_at(2.2, func() -> void: _size(1.02))
			_at(2.4, func() -> void: _host._on_hint())
			_at(2.6, _shot)
			_end = 3.6
		"reset":
			_at(1.4, func() -> void: _size(1.5))
			_at(1.7, _shot)
			_at(1.9, func() -> void: _host._on_reset())
			_at(2.1, _shot)
			_end = 3.0
		"out":
			var t := 1.4
			for k in 3:
				_at(t, _size.bind(3.0))
				_at(t + 0.3, func() -> void: _host._on_check())
				_at(t + 1.6, _shot)
				_at(t + 1.9, func() -> void: _host._on_check())
				t += 2.9
			_at(t + 1.2, _shot)
			_at(t + 1.6, func() -> void: _puzzle.try_again())
			_at(t + 2.4, _shot)
			_end = t + 3.0
		"restore":
			_at(0.2, func() -> void:
				var scores := []
				var guesses := []
				for r in st.rounds:
					scores.append(90)
					guesses.append(float(r.tgt.size_m) * 1.12)
				_puzzle.completed_record = {"scores": scores, "guesses": guesses}
				_puzzle.restore_completed())
			_at(0.5, _shot)
			_end = 1.5

## A week of every band, as text: the pairs, how far apart they are and how
## each stands on a stage the size the phone gives it.
func _pairs() -> void:
	var State = load("res://puzzles/how_big_state.gd")
	var stage := Vector2(928.0, 1000.0)
	print("items ", State.items().size())
	for band in 4:
		for day in 7:
			var st = State.new()
			var rng := RandomNumberGenerator.new()
			rng.seed = (_seed if _seed >= 0 else 20261008) + day * 977 + band
			st.setup(rng, band)
			var line := "band %d day %d:" % [band, day]
			for k in st.round_count():
				st.index = k
				st.ref_m = float(st.ref().size_m)
				var f: Dictionary = st.frame(stage)
				var true_px: float = maxf(State.box_m(st.tgt(), st.truth()).x, State.box_m(st.tgt(), st.truth()).y) * float(f.ppm)
				line += "  %s>%s x%.2f [ref %d true %d max %d start %d]" % [st.ref().id, st.tgt().id,
					State.bigness(st.tgt()) / State.bigness(st.ref()), int(maxf(f.ref.x, f.ref.y)), int(true_px),
					int(f.max), int(f.start)]
			print(line)
