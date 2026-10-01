extends SceneTree

## Shots and probes of Rings, played through the board's own input path (a
## press on a peg, a release). Windowed, one at a time:
##
##     godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_rings.gd -- [d=0..3] [mode] [rm] [out=<dir>]
##
## Modes: `rest`, `press` (a finger held on a peg: the dip), `lift` (a ring
## lifted -- on Insane a two-tone one, its somersault -- then dropped),
## `doom` (Hard or Insane: a drop that would doom the pegs -- the wobble, the
## heart, the hop back), `out` (dooms until the hearts run out: dusk, the
## card, Try again), `right` (drops onto their own colour in a row with each
## gag forced once: combo, bubble, confetti at 4, twirl, love, bee), `solve`
## (the solver's line tap by tap, then the party: hoop, cat, seal), `restore`,
## `perf`. Frames go to <dir>/rg_<mode>_d<level>_<n>.png; every mode prints
## the peak draw calls from 0.5 s on.
##
const SHOT_DIR := "/tmp"
const Gen = preload("res://puzzles/rings_gen.gd")

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
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://_shot_rg_progress.cfg"))
	progress.path = "user://_shot_rg_progress.cfg"
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
			if e.id == "rings":
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
		print("board: band ", st.difficulty, " pegs ", st.pegs.size(), " colours ", st.colours, " tumble ", st.tumble,
			", hearts ", _puzzle.hearts, "/", _puzzle.max_hearts, ", out ", _puzzle.out_of_hearts,
			", done ", _puzzle.is_done(), ", solved ", st.is_solved(), ", hints ", _puzzle.hints_left(),
			", can_undo ", _puzzle.can_undo(), ", flawless ", _puzzle._flawless, ", win_delay ", _puzzle.win_delay(),
			", moves ", st.log.size(), ", scale ", _puzzle._s)
		print("pegs: ", st.pegs)
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

func _at(t: float, what: Callable) -> void:
	_plan.append([t, what])
	_plan.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))

func _shot(tag := "") -> void:
	RenderingServer.force_draw()
	_n += 1
	var path := "%s/rg_%s_d%d_%d%s.png" % [_dir, _mode, _level, _n, tag]
	root.get_texture().get_image().save_png(path)
	print("saved ", path, "  tip: ", _puzzle.tip_line().text)

# --- the hand ---

func _mouse(pos: Vector2, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = pos
	_puzzle._gui_input(ev)

func _peg(i: int) -> Vector2:
	var st: Dictionary = _puzzle._station(i)
	return Vector2(float(st["cx"]), (float(st["top"]) + float(st["ground"])) * 0.5) * _puzzle._s

func _tap(i: int) -> void:
	_mouse(_peg(i), true)
	_mouse(_peg(i), false)

func _move(m: Vector2i) -> void:
	_tap(m.x)
	_tap(m.y)

## A legal move the state would judge doomed (tried in the hand, put back).
func _doom_move() -> Vector2i:
	var st = _puzzle._state
	for m: Vector2i in Gen.moves_from(st.pegs):
		st.lift(m.x)
		var d: bool = st.would_doom(m.y)
		st.put_back()
		if d:
			return m
	return Vector2i(-1, -1)

## Plays good moves on the state (no flights) until a doomed one is on offer.
func _walk_to_doom() -> Vector2i:
	var mv := _doom_move()
	var q := 0
	var st = _puzzle._state
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	while mv.x < 0 and q < 60:
		var ms: Array = Gen.moves_from(st.pegs)
		var safe: Array = []
		for m: Vector2i in ms:
			st.lift(m.x)
			if not st.would_doom(m.y):
				safe.append(m)
			st.put_back()
		if safe.is_empty():
			break
		var g: Vector2i = safe[rng.randi_range(0, safe.size() - 1)]
		st.lift(g.x)
		st.drop(g.y)
		if st.is_solved():
			break
		mv = _doom_move()
		q += 1
	_puzzle._reconcile_locks()
	_puzzle._refresh()
	return mv

## A move onto its own colour that dooms nothing; failing that the solver's.
func _good_onto() -> Vector2i:
	var st = _puzzle._state
	for m: Vector2i in Gen.moves_from(st.pegs):
		if (st.pegs[m.y] as Array).is_empty():
			continue
		st.lift(m.x)
		var d: bool = st.would_doom(m.y) or Gen.verdict(_after_move(st, m.y)) != 1
		st.put_back()
		if not d:
			return m
	var path: Array = Gen.solve(st.pegs)
	return path[0] if not path.is_empty() else Vector2i(-1, -1)

func _after_move(st, j: int) -> Array:
	var copy: Array = []
	for s in st.pegs:
		copy.append((s as Array).duplicate())
	(copy[j] as Array).append(st.held)
	return copy

## A peg whose top ring is two-tone, or -1.
func _two_tone_top() -> int:
	var st = _puzzle._state
	for i in st.pegs.size():
		var p: Array = st.pegs[i]
		if not p.is_empty() and Gen.two_tone(int(p.back())) and not st.locked(i):
			return i
	return -1

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
			_at(1.5, func() -> void: _mouse(_peg(0), true))
			_at(1.62, _shot.bind("_down"))
			_at(1.8, func() -> void: _mouse(_peg(0), false))
			_at(1.86, _shot)
			_at(2.3, _shot)
			_end = 3.0
		"lift":
			var i := [-1]
			_at(1.4, func() -> void:
				i[0] = _two_tone_top()
				if i[0] < 0:
					i[0] = _good_onto().x
				print("lift peg %d top %d" % [i[0], int((_puzzle._state.pegs[i[0]] as Array).back())])
				_tap(i[0]))
			for k in 5:
				_at(1.43 + 0.04 * k, _shot)
			_at(2.0, _shot)
			_at(2.3, func() -> void:
				# Put it back: it turns back over.
				_tap(i[0]))
			for k in 4:
				_at(2.34 + 0.06 * k, _shot)
			_end = 3.0
		"doom":
			var m := [Vector2i(-1, -1)]
			_at(0.9, func() -> void: m[0] = _walk_to_doom())
			_at(1.2, func() -> void:
				print("doom move ", m[0], " hearts ", _puzzle.hearts)
				if m[0].x >= 0:
					_move(m[0]))
			for k in 10:
				_at(1.3 + 0.12 * k, _shot)
			_at(2.8, func() -> void:
				print("after: hearts %d busy %s pegs %s" % [_puzzle.hearts, _puzzle.busy(), str(_puzzle._state.pegs)]))
			_end = 3.2
		"out":
			for k in 4:
				_at(1.0 + 1.8 * k, func() -> void:
					if _puzzle.out_of_hearts or _puzzle.busy():
						return
					var mv := _walk_to_doom()
					print("out %d: doom %s" % [k, str(mv)])
					if mv.x >= 0:
						_move(mv))
			_at(7.7, _shot)
			_at(9.4, _shot)
			_at(9.8, func() -> void:
				print("out: hearts %d, out %s, can_reset %s" % [_puzzle.hearts, _puzzle.out_of_hearts, _puzzle.can_reset()])
				_cleanup()
				_puzzle.try_again())
			_at(10.0, _shot)
			_at(11.0, _shot)
			_end = 11.3
		"right":
			var gags := [-1, -1, 0, 1, 2, -2, -2]
			for k in gags.size():
				var g: int = gags[k]
				_at(1.0 + 1.6 * k, func() -> void:
					var mv := _good_onto()
					if mv.x < 0:
						print("right %d: nothing" % k)
						return
					_puzzle.force_gag = g
					_move(mv)
					_puzzle.force_gag = -2
					print("right %d: %s streak %d combo %d" % [k, str(mv), _puzzle._streak, _puzzle._combo_n]))
				_at(1.5 + 1.6 * k, _shot)
				_at(2.1 + 1.6 * k, _shot)
			_at(12.4, func() -> void: print("undo: ", _puzzle.undo()))
			_at(12.5, _shot)
			_end = 13.0
		"solve":
			var line: Array = []
			_at(0.95, func() -> void:
				line.append_array(Gen.solve(_puzzle._state.pegs))
				print("solve: line of %d" % line.size()))
			for k in 90:
				_at(1.0 + 0.45 * k, func() -> void:
					if _puzzle.is_done() or line.is_empty():
						return
					_move(line.pop_front()))
			_at(0.9, func() -> void:
				_puzzle.solved.connect(func() -> void:
					var base := _t
					for s in [0.3, 0.8, 1.2, 1.6, 2.1, 2.7, 3.4, 4.2]:
						_at(base + s, _shot)
					_end = base + 4.6))
			_end = 50.0
		"restore":
			_at(0.2, func() -> void:
				_puzzle.completed_record = {"hearts": maxi(0, _puzzle.max_hearts - 1), "flawless": true}
				_puzzle.restore_completed_board())
			_at(1.0, _shot)
			_end = 1.5
