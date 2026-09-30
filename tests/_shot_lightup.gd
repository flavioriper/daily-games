extends SceneTree

## Shots and probes of Light Up, played through the board's own input path
## (press, motion, release in board coordinates). Windowed, one at a time:
##
##     godot --path . --resolution 810x1440 --always-on-top --rendering-driver opengl3_angle --script res://tests/_shot_lightup.gd -- [d=0..3] [mode] [rm] [out=<dir>]
##
## Modes: `rest` (the court as dealt), `right` (the answer's lamps set down
## one a second), `wrong` (a fair lamp that is not the answer, again until
## the hearts run out: Hard and Insane; shots mid-gutter, after the eject,
## on the out-of-hearts card, then after Try again), `sweep` (a row of chips
## swept), `wake` (Insane: a lamp in a napping cat's line wakes her, then a
## tap on her cushion is refused), `solve` (the answer to the win, the party
## run out: hats, garland, sky lanterns, seal), `perf` (half the answer, then a
## quiet window). `right` sets down first one lamp of each gag (glasses,
## smoke heart, snail) by the board's own hash; `sweep` sets two lamps down
## first and shoots mid-sweep for the glance. Frames go to <dir>/lu_<mode>_d<level>_<n>.png. Every mode
## prints the peak draw calls from 0.5 s on (or its own window).

const SHOT_DIR := "/private/tmp/claude-501/-Users-flavioriper-dev-daily/f721c072-aa1c-4e1e-a76c-14c94a593176/scratchpad"

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
var _end := 6.0
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
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://_shot_lu_progress.cfg"))
	progress.path = "user://_shot_lu_progress.cfg"
	for e in load("res://ui/registry.gd").PUZZLES:
		progress.mark_tutorial_seen(String(e.id))
	if _reduce:
		load("res://core/motion.gd").reduce = true
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
			if e.id == "lightup":
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
		print("board: %dx%d, %d cats %s, %d lamps, hearts %d/%d, out %s, done %s, hints %d" % [
			_puzzle.w, _puzzle.h, _puzzle.state.cats.size(), _puzzle.state.cat_seen, _puzzle.state.lamps().size(),
			_puzzle.hearts, _puzzle.max_hearts, _puzzle.out_of_hearts, _puzzle.is_done(), _puzzle.hints_left()])
		print("share: ", _puzzle.share_glyphs())
		var loaded: Array = []
		for k in _puzzle.fx._streams:
			if _puzzle.fx._streams[k] != null:
				loaded.append(k)
		print("cues loaded: ", loaded)
		quit()
		return true
	return false

func _at(t: float, what: Callable) -> void:
	_plan.append([t, what])
	_plan.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))

func _shot(tag := "") -> void:
	RenderingServer.force_draw()
	_n += 1
	var path := "%s/lu_%s_d%d_%d%s.png" % [_dir, _mode, _level, _n, tag]
	root.get_texture().get_image().save_png(path)
	print("saved ", path)

# --- the hand ---

func _ev_press(local: Vector2, down: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = down
	ev.position = local
	_puzzle._gui_input(ev)

func _ev_motion(local: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = local
	_puzzle._gui_input(ev)

func _tap(t: float, cell: Vector2i) -> void:
	_at(t, func() -> void: _ev_press(_puzzle.cell_to_local(cell.y, cell.x), true))
	_at(t + 0.06, func() -> void: _ev_press(_puzzle.cell_to_local(cell.y, cell.x), false))

## `lamps` with one lamp of each gag roll first (0 glasses, 1 smoke, 2 snail),
## by the board's own hash, the rest after in their order.
func _gag_first(lamps: Array) -> Array:
	var first: Array = []
	for roll in 3:
		for c: Vector2i in lamps:
			if not first.has(c) and posmod(hash(c * 13 + Vector2i(7, 3)), 5) == roll:
				first.append(c)
				break
	for c in lamps:
		if not first.has(c):
			first.append(c)
	return first

## A stone where a lamp would be fair but is not the answer's.
func _wrong_cell() -> Vector2i:
	var st = _puzzle.state
	for y in st.h:
		for x in st.w:
			var c := Vector2i(x, y)
			if not st.is_white(c) or st.mark_at(c) != 0 or st.solution.has(c):
				continue
			st.marks[c] = 1
			st.recompute()
			var fair: bool = st.lamp_fair(c)
			st.marks.erase(c)
			st.recompute()
			if fair:
				return c
	return Vector2i(-1, -1)

func _script() -> void:
	match _mode:
		"rest":
			_at(2.5, _shot)
			_end = 2.7
		"right":
			# The answer's lamps, the first three picked so each gag plays once
			# (glasses, smoke heart, snail: the board's own hash), one a second.
			var lamps: Array = _gag_first(_puzzle.state.solution.duplicate())
			var n := mini(lamps.size() - 1, 8)
			for k in n:
				_tap(1.5 + k * 0.9, lamps[k])
				_at(1.5 + k * 0.9 + 0.55, _shot)
			_at(1.5 + n * 0.9 + 1.5, _shot)
			_end = 1.5 + n * 0.9 + 1.7
		"wrong":
			# A right lamp first, so there is light on the court to draw back.
			var first: Vector2i = _puzzle.state.solution[0]
			_tap(1.0, first)
			for k in 3:
				var t0 := 1.8 + k * 1.6
				_at(t0, func() -> void:
					var c := _wrong_cell()
					print("wrong lamp ", c, " hearts ", _puzzle.hearts)
					if c.x >= 0:
						_ev_press(_puzzle.cell_to_local(c.y, c.x), true)
						_ev_press(_puzzle.cell_to_local(c.y, c.x), false))
				_at(t0 + 0.4, _shot.bind("_gutter"))
				_at(t0 + 1.2, _shot)
			_at(7.4, _shot.bind("_card"))
			_at(7.6, func() -> void:
				_puzzle.try_again()
				print("after try again: hearts %d out %s lamps %d hints %d" % [_puzzle.hearts, _puzzle.out_of_hearts, _puzzle.state.lamps().size(), _puzzle.hints_left()]))
			_at(8.8, _shot)
			_end = 9.0
		"wake":
			_at(1.5, func() -> void:
				var st = _puzzle.state
				for cat: Vector2i in st.cats:
					if st.cat_need(cat) != 0:
						continue
					for d: Vector2i in st.DIRS:
						var p: Vector2i = cat + d
						while st.lets_light(p) and not st.is_white(p):
							p += d
						if st.is_white(p):
							print("waking ", cat, " from ", p)
							_ev_press(_puzzle.cell_to_local(p.y, p.x), true)
							_ev_press(_puzzle.cell_to_local(p.y, p.x), false)
							return)
			_at(1.9, _shot)
			_at(2.4, func() -> void:
				var cat: Vector2i = _puzzle.state.cats[0]
				_ev_press(_puzzle.cell_to_local(cat.y, cat.x), true)
				_ev_press(_puzzle.cell_to_local(cat.y, cat.x), false)
				print("tip: ", _puzzle.tip_line().text))
			_at(2.6, _shot)
			_end = 2.8
		"sweep":
			# Two of the answer's lamps first, so the glance has faces to turn;
			# a shot mid-sweep catches them looking at the finger.
			var lamps: Array = _puzzle.state.solution.duplicate()
			_tap(0.9, lamps[0])
			_tap(1.1, lamps[1])
			_at(1.52 + _puzzle.w * 0.025, _shot.bind("_mid"))
			_at(1.5, func() -> void: _ev_press(_puzzle.cell_to_local(0, 0), true))
			for k in range(1, _puzzle.w):
				var x := k
				_at(1.5 + k * 0.05, func() -> void: _ev_motion(_puzzle.cell_to_local(0, x)))
			_at(1.5 + _puzzle.w * 0.05 + 0.05, func() -> void: _ev_press(_puzzle.cell_to_local(0, _puzzle.w - 1), false))
			_at(2.0, _shot)
			_at(2.6, _shot)
			_end = 2.8
		"solve":
			var lamps: Array = _puzzle.state.solution.duplicate()
			for k in lamps.size():
				_tap(1.0 + k * 0.3, lamps[k])
			var done := 1.0 + lamps.size() * 0.3
			for k in 9:
				_at(done + 0.4 + k * 0.45, _shot)
			_ms_from = done
			_end = done + 4.4
		"perf":
			var lamps: Array = _puzzle.state.solution.duplicate()
			for k in lamps.size() / 2:
				_tap(1.0 + k * 0.3, lamps[k])
			_ms_from = 1.0 + lamps.size() * 0.15 + 2.5
			_end = _ms_from + 3.0
