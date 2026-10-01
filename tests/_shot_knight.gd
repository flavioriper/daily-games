extends SceneTree

## Shots and probes of Knight, played through the board's own input path (a
## press and a release on a square). Windowed, one at a time:
##
##     godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_knight.gd -- [d=0..3] [mode] [rm] [out=<dir>]
##
## Modes: `rest`; `caught` (a hop into a rose knight's reach: on Hard and
## Insane a heart splits); `out` (catches until the hearts run out: dusk, the
## card, Try again); `lost` (safe hops until the position has no way to the
## king: the toast and the Start over button, then pressing it); `boxed`
## (Insane: safe hops until no hop is left that is not a catch: a heart, the
## brambles wither back); `nap` (Insane: the day's line on a banked board
## that needs a nap, shot as the knight dozes off); `streak` (the day's line
## with gags forced: somersault, love, butterfly, the bubble); `solve` (the
## day's line, then the crown and the party); `restore`.
## Frames go to <dir>/kn_<mode>_d<level>_<n>.png; every mode prints the peak
## draw calls and the mean frame from 0.5 s on.

const Gen = preload("res://puzzles/knight_gen.gd")
const InsaneBank = preload("res://core/insane_bank.gd")
const SHOT_DIR := "/tmp"
## The step between scripted hops: a hop and the answer take ~0.6 s.
const GAP := 0.9

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
var _walk := RandomNumberGenerator.new()
var _napped_shot := false

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
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://_shot_kn_progress.cfg"))
	progress.path = "user://_shot_kn_progress.cfg"
	for e in load("res://ui/registry.gd").PUZZLES:
		progress.mark_tutorial_seen(String(e.id))
	var main: Node = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	_menu = main.get_node("UI/Menu")
	_walk.seed = 7

func _process(delta: float) -> bool:
	_t += delta
	if not _opened:
		_opened = true
		_t = 0.0
		var entry: Dictionary = {}
		for e in load("res://ui/registry.gd").PUZZLES:
			if e.id == "knight":
				entry = e
		if _reduce:
			load("res://core/motion.gd").reduce = true
		if _mode == "nap":
			_pick_nap_board()
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
		print("board: band ", st.difficulty, " ", st.w, "x", st.w, " foes ", st.foes, " brambles ", st.brambles(),
			", hearts ", _puzzle.hearts, "/", _puzzle.max_hearts, ", out ", _puzzle.out_of_hearts, ", lost ", _puzzle._lost,
			", done ", _puzzle.is_done(), ", solved ", st.is_solved(), ", hints ", _puzzle.hints_left(),
			", can_undo ", _puzzle.can_undo(), ", flawless ", _puzzle._flawless, ", win_delay ", _puzzle.win_delay())
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
	var path := "%s/kn_%s_d%d_%d%s.png" % [_dir, _mode, _level, _n, tag]
	root.get_texture().get_image().save_png(path)
	print("saved ", path, "  tip: ", _puzzle.tip_line().text, "  hearts ", _puzzle.hearts, " streak ", _puzzle._streak,
		" lost ", _puzzle._lost, " love ", _puzzle._love.size(), " flies ", _puzzle._flies.size())

## A tap: a press and a release over square c, through the board's own input.
func _tap(c: int) -> void:
	var at: Vector2 = _puzzle._centre(c)
	for down in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = down
		ev.position = at
		_puzzle._gui_input(ev)

## A safe hop chosen off the walk's seed, or -1 when there is none.
func _safe() -> int:
	var st = _puzzle._state
	var ok := PackedInt32Array()
	for m in st.legal():
		if int(st.peek(m).caught) < 0 and m != st.king:
			ok.append(m)
	return -1 if ok.is_empty() else ok[_walk.randi_range(0, ok.size() - 1)]

## A hop into a rose knight's reach, or -1.
func _unsafe() -> int:
	var st = _puzzle._state
	for m in st.legal():
		if int(st.peek(m).caught) >= 0:
			return m
	return -1

## Pins the bank's pick to the first board whose line needs a nap.
func _pick_nap_board() -> void:
	var rows: Array = InsaneBank.boards("knight")
	for i in rows.size():
		if bool(rows[i].grade.get("nap", false)):
			var keep: Dictionary = rows[i]
			InsaneBank._cache[InsaneBank.path_for("knight")] = [keep]
			return

var _line_i := 0
var _won_at := -1.0

## Taps the day's line a hop at a time, each as soon as the board is still,
## calling `each` after every tap; once solved, four shots over the party
## and the end.
func _drive_line(from: float, until: float, each: Callable) -> void:
	var t := from
	while t < until:
		_at(t, func():
			if _puzzle.is_done():
				if _won_at < 0.0:
					_won_at = _t
					for k in [0.3, 1.1, 2.3, 3.6]:
						_at(_t + k, _shot)
					_end = _t + 4.0
				return
			if _puzzle.busy() or _puzzle._now() < _puzzle._busy_until:
				return
			var line: PackedInt32Array = _puzzle._state.g.line
			if _line_i >= line.size():
				return
			each.call()
			_tap(line[_line_i])
			_line_i += 1)
		t += 0.1

func _line_from(i: int) -> void:
	var line: PackedInt32Array = _puzzle._state.g.line
	if i < line.size():
		_tap(line[i])

func _script() -> void:
	var t0 := 1.6
	match _mode:
		"rest":
			_at(1.2, _shot)
			_at(3.2, _shot)
		"caught":
			_at(t0, func(): _tap(_unsafe()))
			_at(t0 + 0.65, _shot)
			_at(t0 + 1.1, _shot)
			_at(t0 + 2.0, _shot)
			_end = t0 + 2.6
		"out":
			for k in 4:
				_at(t0 + float(k) * 2.0, func(): _tap(_unsafe()))
			_at(t0 + 1.0, _shot)
			_at(t0 + 3.0 * 2.0 + 1.0, _shot)
			_at(t0 + 3.0 * 2.0 + 2.2, _shot)
			_at(t0 + 3.0 * 2.0 + 2.4, func():
				for n in root.get_children():
					var card := n.find_child("OutOfHearts", true, false)
					if card != null:
						card.try_again.emit()
						break)
			_at(t0 + 3.0 * 2.0 + 3.4, _shot)
			_end = t0 + 3.0 * 2.0 + 4.0
		"lost":
			# safe hops until the board calls it lost, then the button
			var at := t0
			for k in 20:
				_at(at, func():
					if not _puzzle._lost and not _puzzle.is_done():
						var m := _safe()
						if m >= 0:
							_tap(m))
				at += GAP
			_at(at, _shot)
			_at(at + 0.2, func():
				if _puzzle._stuck_btn.visible:
					_puzzle._stuck_btn.pressed.emit())
			_at(at + 1.0, _shot)
			_end = at + 1.4
		"boxed":
			var at := t0
			for k in 40:
				_at(at, func():
					if not _puzzle.busy() and not _puzzle.is_done() and not _puzzle.out_of_hearts:
						var m := _safe()
						if m >= 0:
							_tap(m))
				at += GAP
				if k == 6:
					_at(at - 0.1, _shot)
			_end = at + 1.0
			_at(_end - 0.4, _shot)
		"nap":
			_drive_line(t0, 40.0, func():
				if not _puzzle._nap_at.is_empty() and not _napped_shot:
					_napped_shot = true
					_at(_t + 0.9, _shot.bind("_nap")))
			_end = 30.0
		"streak":
			_drive_line(t0, 30.0, func():
				_puzzle.force_gag = _line_i % 3
				_at(_t + 0.5, _shot))
			_end = 12.0
		"solve":
			_drive_line(t0, 60.0, func(): pass)
			_end = 60.0
		"restore":
			_at(0.6, func():
				_puzzle.completed_record = {"hearts": 1, "flawless": false}
				_puzzle.restore_completed())
			_at(1.4, _shot)
			_end = 2.0
