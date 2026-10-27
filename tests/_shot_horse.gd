extends SceneTree

## Shots and probes of Horse Pen, played through the board's own input path
## (a touch pressed and let go on a cell). Windowed, one at a time:
##
##     godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_horse.gd -- [d=0..3] [mode] [rm] [out=<dir>]
##
## Modes: `rest` (the entrance and the bare field); `play` (the answer's
## bales one at a time: the wheat shrinking, the pen closing, the pills);
## `refuse` (water, a boulder, the horse, then the stock spent); `notyet`
## (Submit on an open pen, then a pen short of the best submitted: its
## stars, the win, the best pen's faint bales); `stroll` (half the
## answer laid and left alone: the horse trots to a way out and peeks; the
## rest laid: it wanders off to graze; a tap mid-walk sends it home); `hint`;
## `solve` (the answer, Submit, the win); `out` (Insane: bales laid and
## lifted until the moves are gone, the card, Try again); `reset`;
## `restore` (a day reopened already played).
## Frames go to <dir>/hp_<mode>_d<level>_<n>.png; every mode prints the peak
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
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://_shot_hp_progress.cfg"))
	progress.path = "user://_shot_hp_progress.cfg"
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
			if e.id == "horse":
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
		print("board: band ", st.band, " ", st.w, "x", st.h, " bales ", st.bales(), "/", st.budget,
			" closed ", st.closed(), " score ", st.score(), " target ", st.target, " best ", st.best,
			", moves ", _puzzle.moves_left, "/", _puzzle.max_moves, ", out ", _puzzle.out_of_hearts,
			", done ", _puzzle.is_done(), ", solved ", st.is_solved(), ", hints ", _puzzle.hints_left(),
			", can_undo ", _puzzle.can_undo(), ", win_delay ", _puzzle.win_delay())
		print("tip: ", _puzzle.tip_line().text)
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
	var path := "%s/hp_%s_d%d_%d%s.png" % [_dir, _mode, _level, _n, tag]
	root.get_texture().get_image().save_png(path)
	print("saved ", path, "  tip: ", _puzzle.tip_line().text, "  score ", _puzzle.state.score(),
		" bales ", _puzzle.state.bales(), " moves ", _puzzle.moves_left)

## A tap: a touch pressed and let go over `cell`, through the board's input.
func _tap(cell: int) -> void:
	var at: Vector2 = _puzzle.cell_centre(cell)
	for down in [true, false]:
		var ev := InputEventScreenTouch.new()
		ev.index = 0
		ev.pressed = down
		ev.position = at
		_puzzle._gui_input(ev)

func _first(test: Callable) -> int:
	for i in _puzzle.state.cells():
		if test.call(i):
			return i
	return -1

func _script() -> void:
	var st = _puzzle.state
	var sol: Array = st.m.sol
	match _mode:
		"rest":
			_at(0.3, _shot)
			_at(0.6, _shot)
			_at(0.9, _shot)
			_at(2.0, _shot)
			_end = 3.0
		"play":
			var t := 1.6
			for k in sol.size():
				_at(t, _tap.bind(int(sol[k])))
				if k == 0 or k >= sol.size() - 2:
					_at(t + 0.12, _shot)
					_at(t + 0.5, _shot)
				t += GAP
			_end = t + 1.0
		"refuse":
			_at(1.6, func() -> void: _tap(_first(st.is_water)))
			_at(1.8, _shot)
			_at(2.4, func() -> void: _tap(_first(st.is_stone)))
			_at(2.6, _shot)
			_at(3.2, func() -> void: _tap(st.horse))
			_at(3.35, _shot)
			var t := 4.0
			var spare: Array = []
			for i in st.cells():
				if st.bare(i) and not sol.has(i) and spare.size() <= st.budget:
					spare.append(i)
			for i in spare:
				_at(t, _tap.bind(i))
				t += 0.2
			_at(t + 0.15, _shot)
			_end = t + 1.2
		"notyet":
			_at(1.6, func() -> void: _puzzle.check())
			_at(1.75, _shot)
			_at(1.95, _shot)
			_at(2.6, func() -> void:
				# A pen short of the best: what a short search finds (seeds
				# tried until one is), laid through the input.
				var Gen = load("res://puzzles/horse_gen.gd")
				for seed in 40:
					var rng := RandomNumberGenerator.new()
					rng.seed = seed
					var found: Dictionary = Gen.search(rng, st.m, st.budget, 4, 20)
					if not found.is_empty() and int(found.score) < st.best:
						print("notyet: a pen of ", found.score, " against ", st.best)
						for k: int in found.walls:
							_tap(k)
						return)
			_at(3.4, func() -> void: _host._on_check())
			_at(3.6, _shot)
			_at(5.4, _shot)
			_at(5.6, _shot)
			_at(6.4, _shot)
			_end = 7.0
		"stroll":
			var half: int = maxi(1, sol.size() / 2)
			var t := 1.4
			for k in half:
				_at(t, _tap.bind(int(sol[k])))
				t += 0.18
			# Left alone: IDLE_ESCAPE after the last bale, then the walk out.
			var off: float = t + _puzzle.IDLE_ESCAPE
			var out_n: int = (_puzzle.state.path_out() as Array).size()
			_at(off + 0.1, func() -> void:
				print("stroll: kind ", _puzzle._walk_kind, " path ", _puzzle._walk.size() - 1, " closed ", st.closed()))
			_at(off + 0.3, _shot)
			_at(off + 0.1 + out_n * _puzzle.WALK_STEP + 0.4, _shot)
			_at(off + 0.1 + out_n * _puzzle.WALK_STEP + 0.6, func() -> void:
				print("stroll: peeked ", _puzzle._walk_peeked, " toast ", _puzzle._toast))
			t = off + out_n * (_puzzle.WALK_STEP + _puzzle.WALK_BACK) + _puzzle.PEEK_TIME + 0.8
			for k in range(half, sol.size()):
				_at(t, _tap.bind(int(sol[k])))
				t += 0.18
			var graze: float = t + _puzzle.IDLE_GRAZE + 0.1
			_at(graze + 0.2, func() -> void:
				print("stroll: kind ", _puzzle._walk_kind, " path ", _puzzle._walk.size() - 1, " closed ", st.closed(), " stars ", st.stars()))
			_at(graze + 0.6, _shot)
			# A tap mid-walk: the horse goes home and the bale still drops.
			_at(graze + 0.7, func() -> void:
				_tap(int(sol[0]))
				print("stroll: tapped mid-walk, kind ", _puzzle._walk_kind, " bales ", st.bales()))
			_at(graze + 0.78, _shot)
			_at(graze + 1.2, _shot)
			_end = graze + 1.8
		"hint":
			_at(1.6, func() -> void: _host._on_hint())
			_at(1.75, _shot)
			_at(2.3, _shot)
			_at(2.6, func() -> void: _tap(int(st.laid[0]) if not st.laid.is_empty() else 0))
			_at(2.8, _shot)
			_end = 3.8
		"solve":
			var t := 1.4
			for i in sol:
				_at(t, _tap.bind(int(i)))
				t += 0.18
			_at(t + 0.6, _shot)
			_at(t + 0.8, func() -> void: _host._on_check())
			for dt in [1.1, 1.5, 2.0, 2.8, 4.2]:
				_at(t + dt, _shot)
			_end = t + 5.0
		"out":
			var cell := _first(func(i: int) -> bool: return st.bare(i) and not sol.has(i))
			var t := 1.6
			for k in _puzzle.max_moves:
				_at(t, _tap.bind(cell))
				t += 0.16
			_at(1.9, _shot)
			_at(t + 0.5, _shot)
			_at(t + 2.2, _shot)
			_at(t + 2.6, func() -> void: _puzzle.try_again())
			_at(t + 3.4, _shot)
			_end = t + 4.0
		"reset":
			var t := 1.4
			for i in sol:
				_at(t, _tap.bind(int(i)))
				t += 0.12
			_at(t + 0.6, func() -> void: _host._on_reset())
			_at(t + 0.75, _shot)
			_at(t + 1.4, _shot)
			_end = t + 2.0
		"restore":
			_at(0.2, func() -> void:
				_puzzle.completed_record = {"walls": sol, "score": st.best}
				_puzzle.restore_completed())
			_at(0.5, _shot)
			_end = 1.5
