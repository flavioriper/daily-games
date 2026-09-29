extends SceneTree

## Shots and probes of the Untangle ring, played through the board's own input
## path. Windowed, one at a time:
##
##     godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_untangle.gd -- [d=0..3] [mode] [rm] [out=<dir>]
##
## Modes: `rest` (the board as dealt), `hold` (a peg lifted over a glowing
## hole), `taut` (a peg dragged past what its rope reaches), `plan` (the
## dealer's answer played move by move to the win), `wrong` (moves that make
## it worse until the thread runs out, Hard and Insane), `answer` (the same,
## then Show the answer), `hint` (the HUD's hint), `undo`, `reset`.
## Each mode saves numbered frames to <dir>/ut_<mode>_<n>.png and prints the
## board's draw-call count and mean frame time over its last second.

const SHOT_DIR := "/private/tmp/claude-501/-Users-flavioriper-dev-daily/530f0079-d9f8-4c41-a981-a083e45e245d/scratchpad"

var _t := 0.0
var _level := 0
var _mode := "rest"
var _reduce := false
var _dir := SHOT_DIR
var _menu: Node
var _host: Node
var _puzzle: Node
var _opened := false
var _plan: Array = []          # [[at_time, Callable], ...]
var _frames := 0
var _n := 0
var _end := 8.0
var _ms_from := 0.0
var _ms_sum := 0.0
var _ms_n := 0
var _draws_max := 0

func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	load("res://core/progress.gd").path = "user://progress_harness.cfg"
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
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://_shot_ut_progress.cfg"))
	progress.path = "user://_shot_ut_progress.cfg"
	for e in load("res://ui/registry.gd").PUZZLES:
		if _mode == "howto" and e.id == "untangle":
			continue
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
			if e.id == "untangle":
				entry = e
		_menu._open_at(entry, _level)
		_host = _menu.get_child(_menu.get_child_count() - 1)
		_puzzle = _host._puzzle
		if _host.has_node("HowToPlay") and _mode != "howto":
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
		print("frames: draw calls peak %d, mean %.2f ms over %d frames" % [_draws_max, _ms_sum / maxf(_ms_n, 1), _ms_n])
		print("board: %d holes, %d ropes, par %d, budget %d, crossings %d, spent %d" % [_puzzle.state.holes, _puzzle.state.ropes, _puzzle.state.par, _puzzle.state.budget, _puzzle.state.crossings(), _puzzle.state.spent])
		quit()
		return true
	return false

func _at(t: float, what: Callable) -> void:
	_plan.append([t, what])
	_plan.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))

func _shot(tag := "") -> void:
	RenderingServer.force_draw()
	_n += 1
	var path := "%s/ut_%s_d%d_%d%s.png" % [_dir, _mode, _level, _n, tag]
	root.get_texture().get_image().save_png(path)
	print("saved ", path)

# --- the hand ---

func _press(local: Vector2) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = local
	_puzzle._gui_input(ev)

func _motion(local: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = local
	_puzzle._gui_input(ev)

func _release(local: Vector2) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = false
	ev.position = local
	_puzzle._gui_input(ev)

## Drags peg `p` to hole `h` over `dur` seconds from `t0`, through the real
## input path: press, a run of motions, release.
func _drag(t0: float, p: int, h: int, dur := 0.5) -> void:
	_at(t0, func() -> void:
		_press(_puzzle.peg_to_local(p)))
	var steps := 8
	for k in range(1, steps + 1):
		var u := float(k) / steps
		_at(t0 + 0.05 + dur * u, func() -> void:
			_motion(_puzzle.peg_to_local(p).lerp(_puzzle.hole_to_local(h), u)))
	_at(t0 + 0.1 + dur, func() -> void:
		_release(_puzzle.hole_to_local(h)))

func _free_move() -> Array:
	var st = _puzzle.state
	for p in st.at.size():
		for h in st.holes:
			if st.drop_check(p, h) == 0:
				return [p, h]
	return []

# --- the scripts ---

func _script() -> void:
	_ms_from = 1.5
	match _mode:
		"rest":
			_end = 3.0
			_at(2.4, _shot)
		"hold":
			_end = 4.0
			var m := _free_move()
			_at(1.0, func() -> void: _press(_puzzle.peg_to_local(m[0])))
			_at(1.2, func() -> void: _motion(_puzzle.peg_to_local(m[0]).lerp(_puzzle.hole_to_local(m[1]), 0.5)))
			_at(1.9, func() -> void: _motion(_puzzle.hole_to_local(m[1])))
			_at(2.4, _shot)
			_at(3.0, func() -> void: _release(_puzzle.hole_to_local(m[1])))
			_at(3.25, _shot)
			_at(3.8, _shot)
		"taut":
			# The peg on the shortest rope that can move, dragged well past
			# what the rope reaches, toward the ring's middle.
			_end = 3.6
			var st = _puzzle.state
			var pick := -1
			for p in st.at.size():
				if st.can_go(p) and (pick < 0 or st.reach[p >> 1] < st.reach[pick >> 1]):
					pick = p
			var other: Vector2 = _puzzle.peg_to_local(pick ^ 1)
			var far: Vector2 = other + (_puzzle._c - other).normalized() * (_puzzle._ropes[pick >> 1].length * 1.5)
			_at(1.0, func() -> void: _press(_puzzle.peg_to_local(pick)))
			_at(1.1, func() -> void: _motion(_puzzle.peg_to_local(pick).lerp(far, 0.5)))
			_at(1.5, func() -> void: _motion(far))
			_at(2.0, _shot)
			_at(2.4, func() -> void: _release(far))
			_at(2.6, _shot)
		"plan":
			_plan_script(1.2, 2.7 if _level == 3 else 1.1)
		"wrong":
			_wrong_script(false)
		"answer":
			_wrong_script(true)
		"perf":
			# A peg carried round the ring's middle for four seconds, no shots.
			_end = 6.0
			_ms_from = 2.0
			var m := _free_move()
			_at(1.0, func() -> void: _press(_puzzle.peg_to_local(m[0])))
			for k in 90:
				var a := float(k) * 0.14
				_at(1.1 + k * 0.045, func() -> void:
					_motion(_puzzle._c + Vector2.from_angle(a) * _puzzle._ro * 0.45))
			_at(5.3, func() -> void: _release(_puzzle._c))
		"restore":
			# A daily solved earlier, reopened: the answer laid down, hats, seal.
			_end = 3.0
			_ms_from = 9.0
			_at(0.5, func() -> void:
				_puzzle.completed_record = {"stamp": "UT_STAMP_2"}
				_puzzle.restore_completed())
			_at(1.5, _shot)
		"toys":
			# Pet the kitten, then pluck a rope.
			_end = 4.0
			_ms_from = 9.0
			_at(1.0, func() -> void:
				_press(_puzzle._kitten_at)
				_release(_puzzle._kitten_at))
			_at(1.25, _shot)
			_at(1.8, func() -> void:
				var chain: PackedVector2Array = _puzzle._ropes[0].p
				var mid: Vector2 = chain[chain.size() / 2]
				_press(mid)
				_release(mid))
			_at(2.0, _shot)
		"howto":
			# The first-play sheet, kept: two frames of its diagram.
			_end = 4.0
			_ms_from = 9.0
			_at(1.2, _shot)
			_at(2.0, _shot)
		"enter":
			_end = 2.0
			_ms_from = 9.0
			for k in [0.2, 0.32, 0.45, 0.6, 0.9]:
				_at(k, _shot)
		"idle":
			# One move, then two quiet seconds: what a settled board costs.
			_end = 8.0
			_ms_from = 5.0
			var m := _free_move()
			_drag(1.0, m[0], m[1], 0.4)
			_at(4.9, func() -> void:
				var pz = _puzzle
				print("animating=", pz._animating(pz._now()), " calm=", pz._calm, " held=", pz._held, " sel=", pz._sel, " dirty=", pz._dirty, " busy_left=", pz._busy_until - pz._now()))
		"out":
			# The thread poked down to one stitch, then one bad move.
			_end = 7.0
			_at(1.0, func() -> void: _puzzle.state.spent = _puzzle.state.budget - 1)
			_at(1.1, _shot)
			_at(1.4, func() -> void: _one_bad_move())
			_at(2.4, _shot)
			_at(3.4, _shot)
			_at(4.6, _shot)
		"hint":
			_end = 5.0
			# Insane has no hints of its own; a video's is added first.
			_at(1.2, func() -> void:
				if _puzzle.hints_left() <= 0:
					_puzzle.add_hint())
			_at(1.5, func() -> void: _host.top_bar.hint_button.pressed.emit())
			_at(1.7, _shot)
			_at(2.4, _shot)
			_at(3.6, _shot)
		"undo":
			_end = 6.0
			var m := _free_move()
			_drag(1.0, m[0], m[1], 0.4)
			_at(2.3, _shot)
			_at(2.5, func() -> void: _host.top_bar.undo_button.pressed.emit())
			_at(2.7, _shot)
			_at(3.6, _shot)
		"reset":
			_end = 7.0
			_plan_script(1.0, 0.9, 2)
			_at(5.2, func() -> void: _host.top_bar.reset_button.pressed.emit())
			_at(5.5, _shot)
			_at(6.4, _shot)

## One move that makes the board worse, through the input path.
func _one_bad_move() -> void:
	var st = _puzzle.state
	var best: Array = []
	var worst := -1
	for p in st.at.size():
		for h in st.holes:
			if st.drop_check(p, h) != 0:
				continue
			var t: PackedInt32Array = st.at.duplicate()
			t[p] = h
			var c: int = load("res://puzzles/untangle_gen.gd").crossing_count(t, st.ropes)
			if c > worst:
				worst = c
				best = [p, h]
	if best.is_empty():
		return
	_press(_puzzle.peg_to_local(best[0]))
	_motion(_puzzle.peg_to_local(best[0]).lerp(_puzzle.hole_to_local(best[1]), 0.5))
	_motion(_puzzle.hole_to_local(best[1]))
	_at(_t + 0.25, func() -> void: _release(_puzzle.hole_to_local(best[1])))

## The dealer's own answer, move by move, `gap` seconds apart.
func _plan_script(t0: float, gap: float, only := -1) -> void:
	var plan: Array = _puzzle.state.plan
	var count: int = plan.size() if only < 0 else mini(only, plan.size())
	_end = t0 + gap * count + 5.5
	_at(t0 - 0.2, _shot)
	var cat: bool = _puzzle.state.cat
	for k in count:
		var step := k
		_at(t0 + gap * k, func() -> void:
			var m: Array = _puzzle.state.plan[step]
			_press(_puzzle.peg_to_local(m[0]))
			_motion(_puzzle.peg_to_local(m[0]).lerp(_puzzle.hole_to_local(m[2]), 0.5))
			_motion(_puzzle.hole_to_local(m[2])))
		_at(t0 + gap * k + 0.35, func() -> void:
			_release(_puzzle.hole_to_local(int(_puzzle.state.plan[step][2]))))
		_at(t0 + gap * k + 0.6, _shot)
		if cat and (step + 1) % 3 == 0:
			_at(t0 + gap * k + 1.0, _shot)
	if only < 0:
		for k in 5:
			_at(t0 + gap * count + 0.6 + k * 1.0, _shot)

## Moves that only make the board worse, until the thread is gone.
func _wrong_script(show_answer: bool) -> void:
	_end = 24.0
	_at(0.9, _shot)
	var k := 0
	while k < 24:
		var when := 1.2 + k * 0.85
		_at(when, func() -> void:
			var st = _puzzle.state
			if st.out_of_thread() or _puzzle.is_done():
				return
			var best: Array = []
			var worst := -1
			for p in st.at.size():
				for h in st.holes:
					if st.drop_check(p, h) != 0:
						continue
					var t: PackedInt32Array = st.at.duplicate()
					t[p] = h
					var c: int = load("res://puzzles/untangle_gen.gd").crossing_count(t, st.ropes)
					if c > worst:
						worst = c
						best = [p, h]
			if best.is_empty():
				return
			_press(_puzzle.peg_to_local(best[0]))
			_motion(_puzzle.peg_to_local(best[0]).lerp(_puzzle.hole_to_local(best[1]), 0.5))
			_motion(_puzzle.hole_to_local(best[1])))
		_at(when + 0.3, func() -> void:
			_release(_puzzle.get("_finger") if _puzzle.get("_finger") != null else Vector2.ZERO))
		_at(when + 0.55, func() -> void:
			if _puzzle.state.thread_left() >= 0 and _puzzle.state.thread_left() <= 3:
				_shot())
		k += 1
	_at(15.0, _shot)
	_at(16.5, _shot)
	if show_answer:
		_at(17.0, func() -> void:
			var card = null
			for c in _host.get_children():
				if c.name == "OutOfRows":
					card = c
			if card == null:
				card = root.get_node_or_null("OutOfRows")
			if card != null:
				card._answer(1))
		_at(17.6, _shot)
		_at(19.0, _shot)
