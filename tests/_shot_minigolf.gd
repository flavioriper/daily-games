extends SceneTree

## Shots and probes of Mini Golf, played through the board's own input path
## (a press, a drag back, a release). Windowed, one at a time:
##
##     godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_minigolf.gd -- [d=0..3] [mode] [rm] [out=<dir>] [hole=<n>]
##
## Modes: `rest`; `aim` (a pull held: the dots and the band); `putt` (the
## steady putt let go, shot as it rolls); `hint` (the bulb: its line, then
## the aim brought near it); `solve` (every hole played by the steady putt
## to the win and the party); `out` (Insane: putts wasted until the strokes
## run out: dusk, the card, Try again); `reset`; `restore`; `holes` (each
## hole of the course at rest). Frames go to <dir>/gf_<mode>_d<level>_<n>.png;
## every mode prints the peak draw calls and the mean frame from 0.5 s on.

const Sim = preload("res://puzzles/minigolf_sim.gd")
const SHOT_DIR := "/tmp"

var _t := 0.0
var _level := 0
var _mode := "rest"
var _reduce := false
var _dir := SHOT_DIR
var _hole := -1
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
var _auto := false
var _wait := 0.0
var _wasted := 0

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
		elif a.begins_with("hole="):
			_hole = int(a.substr(5))
		else:
			_mode = a
	var progress = load("res://core/progress.gd")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://_shot_gf_progress.cfg"))
	progress.path = "user://_shot_gf_progress.cfg"
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
		var entry: Dictionary = load("res://ui/registry.gd").find("minigolf")
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
	if _auto:
		_play(delta)
	if _t >= _ms_from and _t < _end:
		_ms_sum += delta * 1000.0
		_ms_n += 1
		_draws_max = maxi(_draws_max, int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)))
	if _t >= _end:
		if _ms_n > 0:
			print("frames: draw calls peak %d, mean %.2f ms over %d frames" % [_draws_max, _ms_sum / maxf(_ms_n, 1), _ms_n])
		var st = _puzzle._state
		print("board: band ", st.band, " hole ", st.index + 1, "/", st.holes.size(), " card ", st.card, " par ", st.par_total(),
			", moves ", _puzzle.moves_left, "/", _puzzle.max_moves, ", out ", _puzzle.out_of_hearts,
			", done ", _puzzle.is_done(), ", solved ", st.is_solved(), ", hints ", _puzzle.hints_left(),
			", caps ", _puzzle.capabilities(), ", flawless ", _puzzle._flawless, ", win_delay ", _puzzle.win_delay())
		print("tip: ", _puzzle.tip_line().text)
		print("share: ", _puzzle.share_glyphs())
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
	var path := "%s/gf_%s_d%d_%d%s.png" % [_dir, _mode, _level, _n, tag]
	root.get_texture().get_image().save_png(path)
	print("saved ", path, "  phase ", _puzzle._phase, " hole ", _puzzle._state.index + 1, " strokes ", _puzzle._state.sim.strokes,
		" stickers ", _puzzle._stickers.map(func(s): return s.text))

func _mouse(pos: Vector2, down: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = down
	ev.position = pos
	_puzzle._gui_input(ev)

func _drag(pos: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = pos
	_puzzle._gui_input(ev)

## Presses mid-card and pulls back for a putt of `a` and `u`; lets go when
## `go`.
func _pull(a: float, u: float, go: bool) -> void:
	var from: Vector2 = _puzzle.size * Vector2(0.5, 0.6)
	var to: Vector2 = _puzzle.pull_for(from, a, u)
	_mouse(from, true)
	_drag(from.lerp(to, 0.5))
	_drag(to)
	if go:
		_mouse(to, false)

## The steady putt from here, let go.
func _best() -> void:
	var shot: Dictionary = _puzzle._state.sim.best_shot()
	_pull(shot.a, shot.u, true)

## Plays on by itself: a steady putt whenever the ball is at rest.
func _play(delta: float) -> void:
	if _puzzle.is_done() or _puzzle.out_of_hearts:
		return
	if _puzzle._phase != "aim":
		_wait = 0.25
		return
	_wait -= delta
	if _wait > 0.0:
		return
	_wait = 0.25
	if _mode == "out":
		# a tap of a putt: a stroke gone and the ball barely moved
		_pull(_puzzle._state.sim.tee.angle_to_point(_puzzle._state.sim.p) + 1.0 + float(_wasted), 0.02, true)
		_wasted += 1
	else:
		_best()

func _script() -> void:
	if _hole > 0:
		_at(0.05, func():
			var st = _puzzle._state
			while st.index < _hole - 1:
				st.sim.sunk = true
				st.card[st.index] = st.par()
				st.next_hole()
			_puzzle._fresh_hole(_puzzle._now() - 5.0))
	match _mode:
		"rest":
			_at(1.5, _shot)
			_end = 2.0
		"holes":
			var n: int = load("res://puzzles/minigolf_gen.gd").holes_for(_level)
			for k in n:
				_at(1.2 + 1.2 * k, _shot)
				_at(1.3 + 1.2 * k, func():
					var st = _puzzle._state
					if not st.last_hole():
						st.sim.sunk = true
						st.card[st.index] = st.par()
						st.next_hole()
						_puzzle._fresh_hole(_puzzle._now() - 5.0))
			_end = 1.6 + 1.2 * n
		"aim":
			_at(1.2, func():
				var shot: Dictionary = _puzzle._state.sim.best_shot()
				_pull(shot.a, shot.u, false))
			_at(1.5, _shot)
			_end = 2.0
		"putt":
			_at(1.2, _best)
			for k in 6:
				_at(1.45 + 0.35 * k, _shot)
			_end = 5.0
		"hint":
			_at(1.0, func(): _host._on_hint())
			_at(2.2, _shot)
			_at(2.3, func():
				var g: Dictionary = _puzzle._ghost
				if not g.is_empty():
					_pull(float(g.a) + 0.03, float(g.u) - 0.03, false))
			_at(2.6, _shot)
			_end = 3.0
		"solve":
			_at(1.2, func(): _auto = true)
			for k in 30:
				_at(2.0 + 1.5 * k, _shot)
			_end = 48.0
		"out":
			_at(1.2, func(): _auto = true)
			for k in 12:
				_at(4.0 + 3.0 * k, _shot)
			_end = 42.0
		"reset":
			_at(1.2, _best)
			_at(5.0, _shot)
			_at(5.2, func(): _host._on_reset())
			_at(6.2, _shot)
			_end = 6.6
		"restore":
			_at(0.6, func():
				var st = _puzzle._state
				_puzzle.completed_record = {"card": [2, 1, 3, 2, 2], "log": "⚪⭐🟠", "flawless": true}
				_puzzle.restore_completed())
			_at(1.6, _shot)
			_end = 2.0
