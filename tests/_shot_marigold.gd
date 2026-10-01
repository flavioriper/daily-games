extends SceneTree

## Shots and probes of Marigold's polish (spec
## docs/superpowers/specs/2026-10-01-marigold-polish-design.md). Windowed,
## one at a time:
##
##     godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_marigold.gd -- [d=0..3] [mode] [rm] [out=<dir>]
##
## Modes: `rest`; `shot` (the hint's best line, shot through the real
## release); `sweet` (Insane: the proof's first shot, then a shot that blooms
## a marigold without its sweetheart: the fold); `out` (Hard: one seed and
## one heart left, shot: the heart splits, dusk, the card, Try again);
## `reset` (Hard: a seed shot, then Reset: a heart); `gags` (the frog, the
## ducks, the sunglasses, the streak); `solve` (every marigold but one
## picked, the last one aimed at: the full bloom, the win, the party);
## `restore`. Frames go to <dir>/mg_<mode>_d<level>_<n>.png; every mode
## prints the peak draw calls and the mean frame from 0.5 s on.

const State = preload("res://puzzles/marigold_state.gd")
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
var _end := 5.0
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
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://_shot_mg_progress.cfg"))
	progress.path = "user://_shot_mg_progress.cfg"
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
			if e.id == "marigold":
				entry = e
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
		print("board: band ", st.band, " sweethearts ", st.sweethearts, " pairs ", _pairs(), " marigolds ", st.oranges_left, "/", st.orange_total,
			", seeds ", st.seeds, ", hearts ", _puzzle.hearts, "/", _puzzle.max_hearts, ", out ", _puzzle.out_of_hearts,
			", done ", _puzzle.is_done(), ", solved ", st.is_solved(), ", tries ", st.tries, ", hints ", _puzzle.hints_left(),
			", caps ", _puzzle.capabilities(), ", flawless ", _puzzle._flawless, ", win_delay ", _puzzle.win_delay())
		print("tip: ", _puzzle.tip_line().text)
		print("share: ", _puzzle.share_glyphs())
		_cleanup()
		quit()
		return true
	return false

func _pairs() -> int:
	var n := 0
	for j in _puzzle._state.pair:
		if j >= 0:
			n += 1
	return n / 2

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
	var path := "%s/mg_%s_d%d_%d%s.png" % [_dir, _mode, _level, _n, tag]
	root.get_texture().get_image().save_png(path)
	print("saved ", path, "  phase ", _puzzle._phase, " hearts ", _puzzle.hearts, " streak ", _puzzle._streak,
		" stickers ", _puzzle._stickers.map(func(s): return s.text), " folds ", _puzzle._fold_until > _puzzle._now())

## Aims at `a` and shoots through the board's own press and release: a press
## and a release on the point of the field down that line.
func _fire(a: float) -> void:
	var to: Vector2 = _puzzle._pt(State.SUN_C + State.aim_dir(a) * 30.0)
	for down in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = down
		ev.position = to
		_puzzle._gui_input(ev)

## An angle whose shot from here blooms a marigold without its sweetheart.
func _lonely() -> float:
	var st = _puzzle._state
	for k in 97:
		var a := lerpf(State.AIM_MIN + 0.02, PI - State.AIM_MIN - 0.02, float(k) / 96.0)
		var order: PackedInt32Array = st.shot_order(a)
		var lit := {}
		for i in order:
			lit[i] = true
		for i in order:
			if st.kind[i] == State.ORANGE and not lit.has(st.pair[i]):
				return a
	return PI * 0.5

## Runs `what` the first frame from `from` on that the board is aiming.
func _when_aim(from: float, what: Callable) -> void:
	_when_phase("aim", from, what)

func _when_phase(phase: String, from: float, what: Callable) -> void:
	_at(from, func():
		if _puzzle._phase == phase:
			what.call()
		else:
			_when_phase(phase, _t + 0.05, what))

func _script() -> void:
	var t0 := 1.6
	match _mode:
		"rest":
			for k in [1.2, 3.0]:
				_at(k, _shot)
			_end = 3.5
		"shot":
			_at(t0, func(): _fire(_puzzle._state.best_angle()))
			for k in [0.5, 1.0, 1.6, 2.4, 3.4, 4.6]:
				_at(t0 + k, _shot)
			_end = t0 + 5.0
		"sweet":
			_at(t0, func(): _fire(float(_puzzle._state.proof[0])))
			for k in [0.6, 1.2, 2.0, 3.0]:
				_at(t0 + k, _shot)
			_when_aim(t0 + 3.0, func():
				_fire(_lonely())
				for k in [0.6, 1.4, 2.6]:
					_at(_t + k, _shot)
				_at(_t + 3.0, func(): _when_aim(_t, func():
					for k in [0.0, 0.15, 0.35, 0.8]:
						_at(_t + k, _shot)
					_end = _t + 1.0)))
			_end = 40.0
		"out":
			_at(t0, func():
				_puzzle.hearts = 1
				_puzzle._hearts_mesh = null
				_puzzle._state.seeds = 1
				_fire(PI * 0.5))
			_at(t0 + 1.0, _shot)
			_when_phase("asleep", t0 + 1.0, func():
				for k in [0.05, 0.4, 0.9, 1.8]:
					_at(_t + k, _shot)
				_at(_t + 2.2, func():
					var card: Node = null
					for n in root.get_children():
						card = n.find_child("OutOfHearts", true, false)
						if card != null:
							break
					print("card: ", card != null, " out ", _puzzle.out_of_hearts)
					_puzzle.try_again()
					for k in [0.3, 1.2]:
						_at(_t + k, _shot)
					_end = _t + 1.5))
			_end = 60.0
		"reset":
			_at(t0, func(): _fire(PI * 0.5))
			_when_aim(t0 + 0.5, func():
				print("can_reset ", _puzzle.can_reset())
				_puzzle.reset_board()
				for k in [0.05, 0.4, 1.4]:
					_at(_t + k, _shot)
				_end = _t + 1.8)
			_end = 60.0
		"gags":
			_at(t0, func():
				_puzzle._shot_word(16)
				_puzzle._shades_on(5.0)
				_puzzle._ducks_at = -100.0
				_puzzle._ducks())
			_at(t0 + 1.2, func(): _puzzle._shot_word(23))
			_at(t0 + 2.0, func():
				_puzzle._streak = 2
				_puzzle._on_streak(true))
			for k in [0.25, 0.5, 0.9, 1.5, 2.8, 4.0]:
				_at(t0 + k, _shot)
			_end = t0 + 5.0
		"solve":
			_at(t0, func():
				var st = _puzzle._state
				var last := -1
				for i in st.pos.size():
					if st.kind[i] == State.ORANGE:
						if last < 0:
							last = i
						else:
							st.st[i] = State.GONE
				st.oranges_left = 1
				_puzzle._buds = []
				_puzzle._hud = null
				# the best line, which now can only score the last marigold
				_fire(st.best_angle()))
			for k in [0.6, 1.2, 2.0, 3.0]:
				_at(t0 + k, _shot)
			_when_phase("won", t0 + 1.0, func():
				for k in [0.3, 1.0, 1.6, 2.2, 3.0]:
					_at(_t + k, _shot)
				_end = _t + 3.2)
			_end = 60.0
		"restore":
			_at(0.2, func():
				_puzzle.completed_record = {"score": 123450, "shots": 7, "log": "🟠🔵🟠🌈", "hearts": 2, "flawless": true}
				_puzzle.restore_completed())
			for k in [1.0, 2.0]:
				_at(k, _shot)
			_end = 2.5
