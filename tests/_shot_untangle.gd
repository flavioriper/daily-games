extends SceneTree

## Shots and probes of the Untangle ring, played through the board's own input
## path. Windowed, one at a time:
##
##     godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_untangle.gd -- [d=0..3] [day=N] [mode] [rm] [out=<dir>]
##
## Modes: `rest` (the board as dealt), `carry` (a peg carried over ropes in
## steps, a frame each, then `_folds` -- any rope line turning back on
## itself), `hold` (a peg lifted over a glowing
## hole), `taut` (a peg dragged past what its rope reaches), `plan` (the
## dealer's answer played move by move to the win), `wrong` (moves that make
## it worse until the thread runs out, Hard and Insane), `answer` (the same,
## then Show the answer), `hint` (the HUD's hint), `undo`, `reset`, `lifts`
## (every peg in turn, or `peg=N` alone, lifted a little toward the middle,
## held, shot at 0.2 s and 0.6 s and let go: the knots under a hand).
## Each mode saves numbered frames to <dir>/ut_<mode>_<n>.png and prints the
## board's draw-call count and mean frame time over its last second.

const SHOT_DIR := "/private/tmp/claude-501/-Users-flavioriper-dev-daily/530f0079-d9f8-4c41-a981-a083e45e245d/scratchpad"

var _t := 0.0
var _level := 0
var _day := 0
var _peg := -1
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
		elif a.begins_with("day="):
			_day = int(a.substr(4))
		elif a.begins_with("peg="):
			_peg = int(a.substr(4))
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
		if _day > 0:
			# A later day's deal: the host is told that many are done.
			var host: Control = load("res://ui/flat/flat_host.gd").new()
			host.setup(entry, _level, _day - 1)
			_menu._mount_host(host)
		else:
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

## Where a rope's drawn line turns back on itself (a turn over 100 degrees
## between neighbouring pieces): what tears the ribbon into shards.
func _folds() -> void:
	for r in _puzzle._ropes.size():
		var line: PackedVector2Array = _puzzle._ropes[r].polyline()
		var n := 0
		var worst := 0.0
		for i in range(1, line.size() - 1):
			var d0 := line[i] - line[i - 1]
			var d1 := line[i + 1] - line[i]
			if d0.length() < 0.01 or d1.length() < 0.01:
				continue
			var ang := rad_to_deg(absf(d0.angle_to(d1)))
			worst = maxf(worst, ang)
			if ang > 100.0:
				n += 1
		var cn := 0
		var ch: PackedVector2Array = _puzzle._ropes[r].p
		for i in range(1, ch.size() - 1):
			var e0 := ch[i] - ch[i - 1]
			var e1 := ch[i + 1] - ch[i]
			if e0.length() > 0.01 and e1.length() > 0.01 and absf(e0.angle_to(e1)) > deg_to_rad(100.0):
				cn += 1
		print("rope ", r, " chain folds ", cn, " pts ", line.size(), " folds ", n, " worst turn ", snappedf(worst, 1.0), " wiggles ", _puzzle._ropes[r].wiggles.size())

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
		"lifts":
			# Every peg in turn lifted a little off its hole, held, shot and
			# put back: the tangle under a hand that has not gone anywhere.
			var n: int = _puzzle.state.at.size()
			_end = 1.5 + 0.9 * n
			for p in n:
				if _peg >= 0 and p != _peg:
					continue
				var t0 := 1.0 + 0.9 * (p if _peg < 0 else 0)
				if _peg >= 0:
					_end = 3.0
				var home: Vector2 = _puzzle.peg_to_local(p)
				var inward: Vector2 = (_puzzle.size * 0.5 - home).normalized()
				for k in 6:
					_at(t0 + 0.05 + 0.05 * k, func() -> void: _motion(home + inward * 12.0 * (k + 1) + Vector2(-20.0, 0.0)))
				_at(t0 + 0.2, _shot)
				_at(t0 + 0.6, _shot)
				_at(t0 + 0.7, func() -> void: _release(_puzzle.peg_to_local(p)))
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
		"carry":
			# A peg carried slowly over ropes, a frame at each step: the ropes
			# wrap and slide off under the hand, before the drop. Picks the
			# move that wraps most, else the one that passes over most.
			_end = 6.4
			var st = _puzzle.state
			var best: Array = []
			var score := -1
			for p in st.at.size():
				for h in st.holes:
					if st.drop_check(p, h) != 0:
						continue
					var pv: Array = st.preview(p, h)
					var sc: int = int(pv[1]) * 100 + absi(int(pv[0]))
					if sc > score:
						score = sc
						best = [p, h]
			var pg: int = best[0]
			var hl: int = best[1]
			print("carry peg ", pg, " -> hole ", hl, " preview ", st.preview(pg, hl))
			_at(1.0, func() -> void: _press(_puzzle.peg_to_local(pg)))
			for i in 8:
				var u := float(i + 1) / 8.0
				_at(1.2 + i * 0.5, func() -> void: _motion(_puzzle.peg_to_local(pg).lerp(_puzzle.hole_to_local(hl), u)))
				_at(1.55 + i * 0.5, _shot)
			_at(5.4, func() -> void: _release(_puzzle.hole_to_local(hl)))
			_at(6.2, _shot)
			_at(6.25, _folds)
			_at(0.9, _folds)
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
		"soak":
			# Random play through the real input path, then a check that the
			# board is not stuck: 70 operations, one every 0.55 s.
			_end = 48.0
			_ms_from = 99.0
			var rng := RandomNumberGenerator.new()
			rng.seed = 42 + _level
			for k in 70:
				_at(1.0 + k * 0.55, func() -> void:
					var pz = _puzzle
					var st = pz.state
					var op := rng.randi() % 12
					if op < 6:
						var mv: Array = load("res://puzzles/untangle_gen.gd").legal_moves(st.at, st.holes, st.reach)
						if not mv.is_empty():
							var m: Array = mv[rng.randi() % mv.size()]
							_press(pz.peg_to_local(m[0]))
							_motion(pz.hole_to_local(m[1]))
							_release(pz.hole_to_local(m[1]))
					elif op == 6:
						_press(pz.peg_to_local(rng.randi() % st.at.size()))
						_motion(pz._c + Vector2(rng.randf_range(-600, 600), rng.randf_range(-600, 600)))
						_release(pz._c)
					elif op == 7:
						_host.top_bar.hint_button.pressed.emit()
					elif op == 8:
						_host.top_bar.undo_button.pressed.emit()
					elif op == 9 and rng.randi() % 3 == 0:
						_host.top_bar.reset_button.pressed.emit()
					elif op == 10:
						_press(pz._c + Vector2(rng.randf_range(-300, 300), rng.randf_range(-300, 300)))
						_release(pz._c)
					else:
						var chain: PackedVector2Array = pz._ropes[rng.randi() % st.ropes].p
						_press(chain[chain.size() / 2])
						_release(chain[chain.size() / 2]))
			_at(44.0, func() -> void:
				var pz = _puzzle
				print("soak: done=", pz.is_done(), " solved=", pz.state.is_solved(), " held=", pz._held, " sel=", pz._sel, " settled=", pz._settled(pz._now()), " out=", pz.out_of_hearts, " crossings=", pz.state.crossings(), " spent=", pz.state.spent, "/", pz.state.budget))
		"swat":
			# Insane: on the move before her swipe, move the very peg she is
			# eyeing. Its drop flight must not be skipped by her swat.
			_end = 8.0
			_ms_from = 99.0
			var plan: Array = _puzzle.state.plan
			for k in 2:
				var step := k
				_drag(1.0 + k * 2.9, plan[step][0], plan[step][2], 0.3)
			_at(7.0 - 0.9, func() -> void:
				var pz = _puzzle
				var p: int = pz.state.cat_next().peg
				var hole := -1
				for h in pz.state.holes:
					if pz.state.drop_check(p, h) == 0:
						hole = h
				print("swat: peg ", p, " to hole ", hole, " in ", pz.state.cat_next()["in"])
				if hole >= 0:
					# Tap the peg, then tap the hole: a long flight from home.
					_press(pz.peg_to_local(p))
					_release(pz.peg_to_local(p))
					_at(_t + 0.3, func() -> void:
						print("swat: selected=", pz._sel, " moves_here=", pz.state.moves_here, " busy_left=", pz._busy_until - pz._now())
						_press(pz.hole_to_local(hole))
						_release(pz.hole_to_local(hole))
						print("swat: after tap moves_here=", pz.state.moves_here))
					for dt in [0.03, 0.06, 0.1, 0.2, 0.3, 0.45]:
						_at(_t + 0.3 + dt, func() -> void:
							print("swat: t+", dt, " peg_px=", pz._peg_px[p], " mv=", pz._mv[p], " lift=", pz._lift[p]))
					_at(_t + 0.3 + 0.10, func() -> void:
						print("swat: 0.10s after the drop the peg is ", pz.peg_to_local(p).distance_to(pz.hole_to_local(hole)), " px from its hole (flight length ", pz.peg_to_local(p).distance_to(pz.hole_to_local(hole)), ")")))
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
				print("HUD after a settled move: undo disabled=", _host.top_bar.undo_button.disabled, " reset disabled=", _host.top_bar.reset_button.disabled)
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
			var c: int = int(st.preview(p, h)[0])
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
					var c: int = int(st.preview(p, h)[0])
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
