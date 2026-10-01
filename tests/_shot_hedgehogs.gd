extends SceneTree

## Shots and probes of Hedgehogs, played through the board's own input path
## (a press and a release on a cell). Windowed, one at a time:
##
##     godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_hedgehogs.gd -- [d=0..3] [mode] [rm] [out=<dir>]
##
## Modes: `rest`; `woke` (a rake on a hedgehog: on Hard and Insane a heart
## splits); `out` (wakes until the hearts run out: dusk, the card, Try
## again); `walk` (Insane: rakes logic proves, shot as the bell rings and the
## piles snuffle); `streak` (proved rakes with the gags forced: acorn, love,
## butterfly, the bubble); `solve` (logic plays the lawn out, then the party);
## `restore`. Frames go to <dir>/hh_<mode>_d<level>_<n>.png; every mode
## prints the peak draw calls and the mean frame from 0.5 s on.

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
var _won_at := -1.0
var _walk_shots := 0
var _gag_i := 0

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
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://_shot_hh_progress.cfg"))
	progress.path = "user://_shot_hh_progress.cfg"
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
			if e.id == "hedgehogs":
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
		print("board: band ", st.difficulty, " ", st.cols(), "x", st.rows(), " walkers ", st.walkers(), " walks ", st.walks,
			", hearts ", _puzzle.hearts, "/", _puzzle.max_hearts, ", out ", _puzzle.out_of_hearts,
			", done ", _puzzle.is_done(), ", solved ", st.is_solved(), ", hints ", _puzzle.hints_left(),
			", can_undo ", _puzzle.can_undo(), ", flawless ", _puzzle._flawless, ", woken ", st.woken)
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
	var path := "%s/hh_%s_d%d_%d%s.png" % [_dir, _mode, _level, _n, tag]
	root.get_texture().get_image().save_png(path)
	print("saved ", path, "  tip: ", _puzzle.tip_line().text, "  hearts ", _puzzle.hearts, " streak ", _puzzle._streak,
		" bell ", _puzzle._bell_view, " paws ", _puzzle._paws)

## A tap: a press and a release over cell c, through the board's own input.
func _tap(c: int) -> void:
	var at: Vector2 = _puzzle._centre(c)
	for down in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = down
		ev.position = at
		_puzzle._gui_input(ev)

## A covered hedgehog not flagged, or -1.
func _hog() -> int:
	var st = _puzzle._state
	for c in st.size():
		if st.is_hog(c) and st.open[c] == 0 and st.woke[c] == 0 and st.flag[c] == 0:
			return c
	return -1

## The next rake logic proves (a flag it proves is laid through the flag
## chip, held), or -1 once nothing is left.
func _proved() -> int:
	var st = _puzzle._state
	for guard in 40:
		var step: Dictionary = st.hint_step()
		if step.is_empty():
			return -1
		if step.kind == "rake":
			return int(step.cell)
		st.toggle_flag(int(step.cell))
	return -1

func _ready_for_input() -> bool:
	return not _puzzle.busy() and not _puzzle.is_done() and not _puzzle.out_of_hearts \
		and _puzzle._now() >= _puzzle._busy_until

## Taps proved rakes from `from` to `until`, each when the board is still,
## calling `each` before every tap; once solved, four shots over the party.
func _drive(from: float, until: float, each: Callable) -> void:
	var t := from
	while t < until:
		_at(t, func():
			if _puzzle.is_done():
				if _won_at < 0.0:
					_won_at = _t
					for k in [0.4, 1.4, 2.6, 3.8]:
						_at(_t + k, _shot)
					_end = _t + 4.2
				return
			if not _ready_for_input():
				return
			var c := _proved()
			if c < 0:
				return
			each.call(c)
			_tap(c))
		t += 0.15

func _script() -> void:
	var t0 := 1.8
	match _mode:
		"rest":
			_at(1.2, _shot)
			_at(3.2, _shot)
		"woke":
			_at(t0, func(): _tap(_hog()))
			_at(t0 + 0.45, _shot)
			_at(t0 + 0.9, _shot)
			_at(t0 + 2.0, _shot)
			_end = t0 + 2.6
		"out":
			for k in 4:
				_at(t0 + float(k) * 1.6, func():
					if _ready_for_input():
						_tap(_hog()))
			_at(t0 + 0.9, _shot)
			var last := t0 + 1.6 * 3.0
			_at(last + 1.4, _shot)
			_at(last + 2.4, _shot)
			_at(last + 2.6, func():
				for n in root.get_children():
					var card := n.find_child("OutOfHearts", true, false)
					if card != null:
						card.try_again.emit()
						break)
			_at(last + 3.6, _shot)
			_end = last + 4.2
		"walk":
			_drive(t0, 40.0, func(c: int):
				if _puzzle._state.bell == 2 and _walk_shots < 2:
					_walk_shots += 1
					var at := _t
					_at(at + 0.62, _shot.bind("_ring"))
					_at(at + 0.95, _shot.bind("_snuffle"))
					_at(at + 1.9, _shot.bind("_after")))
			_end = 14.0
		"streak":
			_drive(t0, 40.0, func(c: int):
				_puzzle.force_gag = _gag_i % 3
				_gag_i += 1
				if _gag_i <= 6:
					_at(_t + 0.45, _shot))
			_end = t0 + 6.0
		"solve":
			_drive(t0, 120.0, func(c: int): pass)
			_end = 120.0
		"restore":
			_at(0.6, func():
				_puzzle.completed_record = {"woke": [], "hearts": 1, "flawless": true}
				_puzzle.restore_completed())
			_at(1.4, _shot)
			_at(4.4, _shot)
			_end = 5.0
