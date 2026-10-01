extends SceneTree

## Shots and probes of Sunbeam, played through the board's own input path (a
## press on a piece, motion events, a release). Windowed, one at a time:
##
##     godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_sunbeam.gd -- [d=0..3] [mode] [rm] [out=<dir>]
##
## Modes: `rest`; `hold` (a piece held where its light falls on a sleeper:
## the snail worries, a shy drop blushes); `wrong` (a move let go there: the
## snail wakes or the drop dries, a heart splits, the piece slides back);
## `out` (wrong moves until the hearts run out: dusk, the card, Try again);
## `right` (pieces home one at a time, gags forced: streak, rainbow, love,
## butterfly); `solve` (a dark way home, then the party); `restore`.
## Frames go to <dir>/sb_<mode>_d<level>_<n>.png; every mode prints the peak
## draw calls and the mean frame from 0.5 s on.

const Gen = preload("res://puzzles/sunbeam_gen.gd")
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
var _feed: Array = []

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
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://_shot_sb_progress.cfg"))
	progress.path = "user://_shot_sb_progress.cfg"
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
			if e.id == "sunbeam":
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
	if not _feed.is_empty():
		var p: Vector2 = _feed.pop_front()
		if p.x < -9000.0:
			_mouse(_last, false)
		else:
			_motion(p)
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
		print("board: band ", st.difficulty, " ", st.cols, "x", st.rows, " pieces ", st.pieces().size(), " drops ", st.drops().size(),
			" snails ", st.snails().size(), " shy ", st.shy(), ", hearts ", _puzzle.hearts, "/", _puzzle.max_hearts,
			", out ", _puzzle.out_of_hearts, ", done ", _puzzle.is_done(), ", solved ", st.is_solved(),
			", hints ", _puzzle.hints_left(), ", can_undo ", _puzzle.can_undo(), ", flawless ", _puzzle._flawless,
			", win_delay ", _puzzle.win_delay())
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

func _at(t: float, what: Callable) -> void:
	_plan.append([t, what])
	_plan.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))

func _shot(tag := "") -> void:
	RenderingServer.force_draw()
	_n += 1
	var path := "%s/sb_%s_d%d_%d%s.png" % [_dir, _mode, _level, _n, tag]
	root.get_texture().get_image().save_png(path)
	print("saved ", path, "  tip: ", _puzzle.tip_line().text, "  hearts ", _puzzle.hearts, " love ", _puzzle._love.size(),
		" bows ", _puzzle._bows.size(), " flies ", _puzzle._flies.size(), " streak ", _puzzle._streak)

# --- the hand ---

var _last := Vector2.ZERO

func _mouse(pos: Vector2, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = pos
	_last = pos
	_puzzle._gui_input(ev)

func _motion(pos: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = pos
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT
	_last = pos
	_puzzle._gui_input(ev)

func _peg(p: int, q: float) -> Vector2:
	return _puzzle._pt(_puzzle._piece_mid(p, q))

## Presses piece `p` and queues a drag to peg `q` in a few steps; let go at
## the end unless `hold`.
func _slide(p: int, q: int, hold := false) -> void:
	var from := float(_puzzle._state.pos[p])
	_mouse(_peg(p, from), true)
	for k in range(1, 7):
		_feed.append(_peg(p, lerpf(from, float(q), float(k) / 6.0)))
	if not hold:
		_feed.append(Vector2(-9999.0, 0.0))

## A move from here that the judge prices: [piece, peg] or [].
func _priced() -> Array:
	var st = _puzzle._state
	for p in st.pieces().size():
		var was: int = st.pos[p]
		for q in st.g.pieces[p].rail.size():
			if q == was or st.taken(p, q) or st.pinned.has(p):
				continue
			st.pos[p] = q
			st.retrace()
			var k: String = st.judge()
			st.pos[p] = was
			st.retrace()
			if k != "":
				return [p, q]
	return []

## A dark way home from here: [[piece, peg], ...], breadth first.
func _dark_moves() -> Array:
	var st = _puzzle._state
	var g: Dictionary = st.g
	var f = Gen.Fast.new(g, st.sleepers())
	var start: PackedInt32Array = st.pos.duplicate()
	var home: PackedInt32Array = st.home_pos()
	var seen := {str(start): null}
	var queue: Array = [start]
	while not queue.is_empty():
		var s: PackedInt32Array = queue.pop_front()
		for p in f.np:
			for q in f.rails[p]:
				if q == s[p] or not f.fits(s, p, q):
					continue
				var t := s.duplicate()
				t[p] = q
				var key := str(t)
				if seen.has(key):
					continue
				seen[key] = [str(s), p, q]
				if t == home:
					var out: Array = []
					var k := key
					while seen[k] != null:
						out.push_front([seen[k][1], seen[k][2]])
						k = seen[k][0]
					return out
				var r: Vector2i = f.probe(t)
				if r.x == 0:
					queue.append(t)
	return []

func _script() -> void:
	var st = _puzzle._state
	match _mode:
		"rest":
			_at(1.5, _shot)
		"hold":
			_end = 3.0
			_at(1.0, func() -> void:
				var m := _priced()
				print("priced ", m)
				if not m.is_empty():
					_slide(m[0], m[1], true))
			_at(1.6, _shot)
			_at(2.4, _shot)
		"wrong":
			_end = 3.6
			_at(1.0, func() -> void:
				var m := _priced()
				print("priced ", m)
				if not m.is_empty():
					_slide(m[0], m[1]))
			_at(1.35, _shot)
			_at(1.7, _shot)
			_at(2.6, _shot)
		"out":
			_end = 8.0
			for k in 3:
				_at(1.0 + k * 1.6, func() -> void:
					var m := _priced()
					if not m.is_empty():
						_slide(m[0], m[1]))
			_at(5.9, _shot)
			_at(6.6, func() -> void:
				_shot()
				_cleanup()
				_puzzle.try_again())
			_at(7.6, _shot)
		"right":
			_end = 12.0
			var moves := _dark_moves()
			var t := 1.0
			var k := 0
			for mv in moves.slice(0, maxi(0, moves.size() - 1)):
				var gag := k % 3
				_at(t, func() -> void:
					_puzzle.force_gag = gag
					_slide(mv[0], mv[1]))
				_at(t + 0.75, _shot.bind("_g%d" % gag))
				t += 1.5
				k += 1
		"solve":
			_end = 10.0
			var moves := _dark_moves()
			print("dark way: ", moves.size(), " moves")
			var t := 1.0
			for mv in moves:
				_at(t, func() -> void: _slide(mv[0], mv[1]))
				t += 0.45
			for k in 8:
				_at(t + 0.4 + k * 0.7, _shot)
			_end = t + 0.4 + 8 * 0.7
		"restore":
			_end = 2.5
			_at(0.6, func() -> void:
				_puzzle.completed_record = {"hearts": _puzzle.max_hearts, "flawless": true}
				_puzzle.restore_completed())
			_at(1.5, _shot)
