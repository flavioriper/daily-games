extends SceneTree

## Shots and probes of Quilt, played through the board's own input path (a
## press on a patch, motions, a release). Windowed, one at a time:
##
##     godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_quilt.gd -- [d=0..3] [mode] [rm] [out=<dir>]
##
## Modes: `rest` (the entrance, the ghost finger on Easy and Medium, the
## label), `tap` (a rack patch tapped: the wiggle and the line; then one held
## half a cell off its fit, sticky snap's ghost), `stuck` (Easy and Medium:
## a drop that leaves the quilt unfinishable, the rose pulse), `wrong` (Hard
## and Insane: a wrong patch landing, snipped, peeling and fluttering home,
## then held over its chalked spot and let go there), `out` (wrong patches
## until the hearts run out: the dusk, the card, Try again), `restore` (a
## solved day reopened: the cat asleep, the seal, Scrap Basket's bunting),
## `right` (right patches one after another short of the solve: the streak,
## the bubble, the gags, a finished row's glint) and `solve` (every answer
## patch: the wave, the dance, the cat hopping on and curling up, the
## bunting and the seal). Frames go to <dir>/ql_<mode>_d<level>_<n>.png. Every
## mode prints the peak draw calls from 0.5 s on.

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
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://_shot_ql_progress.cfg"))
	progress.path = "user://_shot_ql_progress.cfg"
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
			if e.id == "quilt":
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
		var st = _puzzle._state
		print("board: %dx%d band %d, %d patches (%d scraps), cell %.1f, rack cell %.1f, shelves %d, hearts %d/%d, out %s, done %s, hints %d, ruled %d, flawless %s" % [
			st.cols, st.rows, st.band, st.shapes.size(), st.scraps().size(), _puzzle._cell(),
			_puzzle._rack_cell(), _puzzle._shelves().size(), _puzzle.hearts, _puzzle.max_hearts,
			_puzzle.out_of_hearts, _puzzle.is_done(), _puzzle.hints_left(), st.ruled.size(),
			_puzzle._flawless])
		print("tip: ", _puzzle.tip_line().text)
		# The rack cell each shelf count would give, from the chosen order.
		var order: Array = []
		for shelf in _puzzle._shelves():
			order.append_array(shelf)
		var by: Array = []
		for count in [2, 3]:
			var per := int(ceil(order.size() / float(count)))
			var split: Array = []
			var k := 0
			while k < order.size():
				split.append(order.slice(k, mini(k + per, order.size())))
				k += per
			by.append("%d shelves %.1f" % [count, _puzzle._cell_for(split)])
		print("rack cell by shelves: ", ", ".join(by), "; board ", _puzzle.size)
		quit()
		return true
	return false

func _at(t: float, what: Callable) -> void:
	_plan.append([t, what])
	_plan.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))

func _shot(tag := "") -> void:
	RenderingServer.force_draw()
	_n += 1
	var path := "%s/ql_%s_d%d_%d%s.png" % [_dir, _mode, _level, _n, tag]
	root.get_texture().get_image().save_png(path)
	print("saved ", path, "  tip: ", _puzzle.tip_line().text)

# --- the hand ---

func _mouse(pos: Vector2, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = pos
	_puzzle._gui_input(ev)

func _motion(pos: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = pos
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT
	_puzzle._gui_input(ev)

## The point a patch is taken hold of on the rack: its first cell's middle.
func _bay_point(p: int) -> Vector2:
	var first: Vector2i = (_puzzle._state.shapes[p] as Array)[0]
	return _puzzle._bay_home(p) + (Vector2(first) + Vector2(0.5, 0.5)) * _puzzle._rack_cell()

## Where the finger has to be for patch `p`'s origin to sit on `origin`
## (held HOLD_LIFT above the finger), nudged by `off` cells.
func _drop_point(p: int, origin: int, off := Vector2.ZERO) -> Vector2:
	var st = _puzzle._state
	var first: Vector2i = (st.shapes[p] as Array)[0]
	var cell: float = _puzzle._cell()
	var corner: Vector2 = _puzzle._origin() + Vector2(float(origin % st.cols), float(origin / st.cols)) * cell
	return corner + (Vector2(first) + Vector2(0.5, 0.5 + _puzzle.HOLD_LIFT) + off) * cell

## A drag spread over a few frames from `t`: press, two motions, release at
## `t + 0.4` (or held, if `hold`).
func _drag(t: float, p: int, origin: int, off := Vector2.ZERO, hold := false) -> void:
	_at(t, func() -> void: _mouse(_bay_point(p), true))
	_at(t + 0.12, func() -> void: _motion(_bay_point(p).lerp(_drop_point(p, origin, off), 0.5)))
	_at(t + 0.26, func() -> void: _motion(_drop_point(p, origin, off)))
	if not hold:
		_at(t + 0.4, func() -> void:
			_mouse(_drop_point(p, origin, off), false)
			print("drop %d at %d -> at %d, hearts %d" % [p, origin, int(_puzzle._state.at[p]), _puzzle.hearts]))

## A patch and a spot that fits but is wrong: a scrap first on Scrap Basket.
func _wrong_pick() -> Array:
	var st = _puzzle._state
	var order: Array = []
	for p in st.scraps():
		order.append(p)
	for p in st.shapes.size():
		if not order.has(p):
			order.append(p)
	for p in order:
		if int(st.at[p]) >= 0:
			continue
		for origin in st.cols * st.rows:
			if st.fits(p, origin) == 0 and not st.is_right(p, origin) and not st.is_ruled(p, origin):
				return [p, origin]
	return []

## The quilt's own patches (never a scrap) in an order that leaves the
## quilt finishable after each: the answer's, top row first.
func _answer_order() -> Array:
	var st = _puzzle._state
	var order: Array = []
	for p in st.shapes.size():
		if int(st.answer[p]) >= 0:
			order.append(p)
	order.sort_custom(func(a: int, b: int) -> bool: return int(st.answer[a]) < int(st.answer[b]))
	return order

## A drop on Easy or Medium that leaves the quilt unfinishable, with cells to
## pulse if there is one.
func _stuck_pick() -> Array:
	var st = _puzzle._state
	var fallback: Array = []
	for p in st.shapes.size():
		if int(st.at[p]) >= 0:
			continue
		for origin in st.cols * st.rows:
			if st.fits(p, origin) != 0:
				continue
			st.at[p] = origin
			st.recompute()
			var dead: bool = not st.finishable()
			var cells: int = st.dead_cells().size()
			st.at[p] = -1
			st.recompute()
			if dead and cells > 0:
				return [p, origin]
			if dead and fallback.is_empty():
				fallback = [p, origin]
	return fallback

func _script() -> void:
	var st = _puzzle._state
	match _mode:
		"rest":
			_at(0.3, _shot.bind("_enter"))
			_at(1.2, _shot)
			_at(3.2, _shot.bind("_coach"))
			_at(3.6, _shot.bind("_coach2"))
			_at(4.1, _shot.bind("_coach3"))
			_end = 4.3
		"tap":
			var p := 0
			for q in st.shapes.size():
				if int(st.answer[q]) >= 0:
					p = q
					break
			_at(1.2, func() -> void:
				_mouse(_bay_point(p), true))
			_at(1.3, func() -> void:
				_mouse(_bay_point(p), false))
			_at(1.45, _shot.bind("_wiggle"))
			# Held 0.4 of a cell off its answer: sticky snap's ghost.
			_drag(2.2, p, int(st.answer[p]), Vector2(0.42, 0.3), true)
			_at(2.75, _shot.bind("_sticky"))
			_at(2.8, func() -> void:
				_mouse(_drop_point(p, int(st.answer[p]), Vector2(0.42, 0.3)), false)
				print("sticky drop -> at %d (answer %d)" % [int(st.at[p]), int(st.answer[p])]))
			_at(3.5, _shot.bind("_sewn"))
			_end = 3.7
		"stuck":
			var pick := _stuck_pick()
			if pick.is_empty():
				print("no dead end found")
				_end = 1.0
				return
			_drag(1.0, pick[0], pick[1])
			_at(1.75, _shot.bind("_pulse"))
			_at(2.05, _shot.bind("_pulse2"))
			_at(3.2, _shot)
			_end = 3.4
		"wrong":
			_at(0.9, func() -> void:
				var pick := _wrong_pick()
				print("wrong pick: ", pick, " scrap ", st.scraps().has(pick[0]))
				_drag(1.0, pick[0], pick[1])
				_at(1.55, _shot.bind("_land"))
				_at(1.95, _shot.bind("_snip"))
				_at(2.25, _shot.bind("_peel"))
				_at(2.6, _shot.bind("_flutter"))
				_at(3.3, _shot.bind("_home"))
				# The same patch held over its chalked spot, then let go there.
				_drag(3.6, pick[0], pick[1], Vector2.ZERO, true)
				_at(4.1, _shot.bind("_cross"))
				_at(4.2, func() -> void:
					_mouse(_drop_point(pick[0], pick[1]), false)
					print("ruled drop -> hearts %d" % _puzzle.hearts))
				_at(4.5, _shot.bind("_ruled")))
			_end = 4.8
		"out":
			for k in 3:
				var t0 := 1.0 + k * 2.2
				_at(t0 - 0.05, func() -> void:
					if _puzzle.out_of_hearts:
						return
					var pick := _wrong_pick()
					if not pick.is_empty():
						_drag(_t + 0.05, pick[0], pick[1]))
			_at(8.0, _shot.bind("_dusk"))
			_at(9.1, _shot.bind("_card"))
			_at(9.3, func() -> void:
				if _puzzle.out_of_hearts:
					_puzzle.try_again()
				print("after try again: hearts %d out %s ruled %d moves %d" % [
					_puzzle.hearts, _puzzle.out_of_hearts, st.ruled.size(), _puzzle.moves]))
			_at(9.45, _shot.bind("_wave"))
			_at(10.5, _shot)
			_end = 10.7
		"right":
			var order := _answer_order()
			var n := order.size() - 1
			for k in n:
				var p: int = order[k]
				var t0 := 1.0 + k * 1.3
				_drag(t0, p, int(st.answer[p]))
				_at(t0 + 0.41, func() -> void:
					print("patch %d gag roll %d, streak %d, rows %d" % [p,
						_puzzle._gag_roll(p), _puzzle._streak, _puzzle._rows.size()]))
				_at(t0 + 0.62, _shot.bind("_p%d_a" % k))
				_at(t0 + 0.95, _shot.bind("_p%d_b" % k))
			_end = 1.0 + n * 1.3 + 0.4
		"solve":
			var order := _answer_order()
			for k in order.size():
				var p: int = order[k]
				_drag(1.0 + k * 0.7, p, int(st.answer[p]))
			var t1 := 1.0 + (order.size() - 1) * 0.7 + 0.4
			_at(t1 + 0.05, func() -> void:
				print("solved %s, flawless %s, win_delay %.2f, share: %s" % [_puzzle.is_done(),
					_puzzle._flawless, _puzzle.win_delay(), _puzzle.share_glyphs()]))
			for dt in [0.6, 1.5, 1.8, 2.1, 2.4, 2.75, 3.1, 3.6]:
				_at(t1 + dt, _shot.bind("_%02d" % int(dt * 10)))
			_at(t1 + 3.65, func() -> void:
				print("cat curled %s, tip: %s" % [_puzzle._cat_curled, _puzzle.tip_line().text]))
			_end = t1 + 3.8
		"restore":
			_at(1.5, func() -> void:
				_puzzle.completed_record = {"flawless": true, "hearts": 1}
				_puzzle.restore_completed_board())
			_at(2.0, _shot)
			_end = 2.2
