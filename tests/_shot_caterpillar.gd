extends SceneTree

## Shots and probes of Caterpillar, played through the board's own input
## path (a press on a square, motion events, a release). Windowed, one at a
## time:
##
##     godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_caterpillar.gd -- [d=0..3] [mode] [rm] [out=<dir>]
##
## Modes: `rest`; `drag` (a flick along the answer two squares an event, the
## body must keep up square for square; prints the frame cost); `wrong` (Hard
## or Insane: half the answer, then a step the judge prices -- blush, heart,
## scoot back); `out` (wrong steps until the hearts run out: dusk, the card,
## Try again); `right` (the answer leaf by leaf, every gag forced once:
## combo, bubble, confetti, burp, love, ladybug); `hungry` (Insane: walk off
## the answer's leaves until the tummy is empty and try a bare square);
## `solve` (the whole answer, then the party: flutter, cat, seal);
## `restore`. Frames go to <dir>/cp_<mode>_d<level>_<n>.png; every mode
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
var _feed: Array = []   # queued motion points, one a frame

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
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://_shot_cp_progress.cfg"))
	progress.path = "user://_shot_cp_progress.cfg"
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
			if e.id == "caterpillar":
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
		print("board: band ", st.difficulty, " ", st.cols, "x", st.rows, " leaves ", st.last_leaf(), " fences ", st.hedges.size(),
			" hunger ", st.hunger, ", body ", st.body.size(), "/", st.size(), ", hearts ", _puzzle.hearts, "/", _puzzle.max_hearts,
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
	var path := "%s/cp_%s_d%d_%d%s.png" % [_dir, _mode, _level, _n, tag]
	root.get_texture().get_image().save_png(path)
	print("saved ", path, "  tip: ", _puzzle.tip_line().text, "  love ", _puzzle._love.size(), " bubbles ", _puzzle._bubbles.size(), " bugs ", _puzzle._bugs.size(), " gag_until ", _puzzle._gag_until - _puzzle._now())

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

func _at_cell(c: int) -> Vector2:
	return _puzzle._centre(c)

## Presses the head (or leaf 1) and queues a drag through `cells` the way a
## finger flicks: points along the walk `every` squares apart (fractions
## land between two squares' centres), released at the end.
func _drag(cells: PackedInt32Array, every := 1.0) -> void:
	var st = _puzzle._state
	var from: int = st.head() if not st.body.is_empty() else st.path[0]
	_mouse(_at_cell(from), true)
	var u := every
	var last := float(cells.size() - 1)
	while u < last:
		var i := int(floor(u))
		_feed.append(_at_cell(cells[i]).lerp(_at_cell(cells[mini(i + 1, cells.size() - 1)]), u - float(i)))
		u += every
	_feed.append(_at_cell(cells[cells.size() - 1]))
	_feed.append(Vector2(-9999.0, 0.0))

## The answer from the body's head on, `count` squares (the head included).
func _answer(count: int) -> PackedInt32Array:
	var st = _puzzle._state
	var at: int = maxi(0, st.body.size() - 1)
	return st.path.slice(at, mini(at + count, st.size()))

## A square next to the head that the board allows and the judge prices.
func _priced() -> int:
	var st = _puzzle._state
	var h: int = st.head()
	for d in [1, -1, st.cols, -st.cols]:
		var m: int = h + d
		if m < 0 or m >= st.size() or not st.adjacent(h, m) or st.body.has(m):
			continue
		if st.why(m) == "" and st.judge(m) != "":
			return m
	return -1

## Lays the answer up to `count` squares straight on the state (no input),
## then redraws.
func _lay(count: int) -> void:
	var st = _puzzle._state
	st.body = st.path.slice(0, count)
	_puzzle._seg_at.clear()
	for i in count:
		_puzzle._seg_at.append(-100.0)
	_puzzle._dirty()

func _script() -> void:
	var st = _puzzle._state
	match _mode:
		"rest":
			_at(1.5, _shot)
		"drag":
			_end = 3.0
			_at(0.8, func() -> void:
				_drag(_answer(st.size() - 1), 1.5))
			_at(1.1, _shot)
			_at(1.6, _shot)
			_at(2.6, func() -> void:
				print("drag: body ", st.body.size(), " of ", st.size() - 1, " asked, agrees ", st.agreed())
				_shot())
		"wrong":
			_end = 3.5
			_at(0.6, func() -> void: _lay(st.size() / 2))
			_at(0.9, func() -> void:
				var m := _priced()
				print("priced square ", m, " judge ", st.judge(m), " stranded ", st.stranded(m))
				_mouse(_at_cell(st.head()), true)
				_motion(_at_cell(m)))
			_at(1.25, _shot)
			_at(1.6, _shot)
			_at(2.2, func() -> void:
				_mouse(_last, false)
				_shot())
		"out":
			_end = 7.0
			_at(0.6, func() -> void: _lay(st.size() / 2))
			for k in 3:
				_at(0.9 + k * 1.2, func() -> void:
					var m := _priced()
					_mouse(_at_cell(st.head()), true)
					_motion(_at_cell(m))
					_mouse(_last, false))
			_at(4.4, _shot)
			_at(5.9, _shot)
			_at(6.1, func() -> void:
				_cleanup()
				_puzzle.try_again())
			_at(6.8, _shot)
		"right":
			_end = 13.5
			_ms_from = 0.5
			var kinds := [0, 1, 2, 0, 1, 2, 0, 1, 2, 0, 1, 2]
			var leaves: PackedInt32Array = st.leaves
			var t := 0.7
			for k in mini(leaves.size() - 2, 6):
				var gag: int = kinds[k]
				var upto: int = st.path.find(leaves[k + 1]) + 1
				_at(t, func() -> void:
					_puzzle.force_gag = gag
					_drag(_answer(upto - maxi(0, st.body.size() - 1))))
				_at(t + 1.05, _shot.bind("_g%d" % gag))
				t += 2.0
		"hungry":
			_end = 3.0
			_at(0.6, func() -> void:
				# Walk bare squares until the tummy is empty, then try one more.
				st.start(st.path[0])
				_puzzle._seg_at.append(-100.0)
				var safety := 0
				while st.tummy() > 0 and safety < 200:
					safety += 1
					var moved := false
					for d in [1, -1, st.cols, -st.cols]:
						var m: int = st.head() + d
						if m >= 0 and m < st.size() and st.adjacent(st.head(), m) and not st.body.has(m) \
								and st.clue[m] == 0 and st.why(m) == "":
							st.grow(m)
							_puzzle._seg_at.append(-100.0)
							moved = true
							break
					if not moved:
						break
				_puzzle._dirty()
				print("tummy ", st.tummy()))
			_at(1.0, func() -> void:
				for d in [1, -1, st.cols, -st.cols]:
					var m: int = st.head() + d
					if m >= 0 and m < st.size() and st.adjacent(st.head(), m) and not st.body.has(m) and st.clue[m] == 0:
						print("hungry try ", m, " why ", st.why(m))
						_mouse(_at_cell(st.head()), true)
						_motion(_at_cell(m))
						_mouse(_last, false)
						return)
			_at(1.12, _shot)
			_at(1.8, _shot)
		"solve":
			_end = 8.0
			_at(0.7, func() -> void: _drag(_answer(st.size())))
			for k in 7:
				_at(0.7 + float(st.size()) / 60.0 + 0.6 + k * 0.7, _shot)
		"restore":
			_end = 2.5
			_at(0.6, func() -> void:
				_puzzle.completed_record = {"hearts": _puzzle.max_hearts, "flawless": true}
				_puzzle.restore_completed())
			_at(1.5, _shot)
