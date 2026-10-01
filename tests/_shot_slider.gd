extends SceneTree

## Shots and probes of Super Slider, played through the board's own input
## path (a press, a drag through every cell of a block's path, a release).
## Windowed, one at a time:
##
##     godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_slider.gd -- [d=0..3] [mode] [rm] [out=<dir>]
##
## Modes: `rest`; `fret` (Hard: a move that sets the big block back, held:
## the sweat drop); `cost` (Hard: the same move let go: a heart splits and
## the block slides back); `out` (Hard: setbacks until the hearts run out:
## dusk, the card, Try again); `home` (Insane: the big block dragged up --
## the head shake -- then a move that strands it: a heart, the slide back);
## `streak` (nearer moves with gags forced: twirl, love, butterfly, the
## bubble); `solve` (the shortest way dragged out, then the party);
## `restore`. Frames go to <dir>/sl_<mode>_d<level>_<n>.png; every mode
## prints the peak draw calls and the mean frame from 0.5 s on.

const Gen = preload("res://puzzles/slider_gen.gd")
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
var _moves_done := 0
var _won_at := -1.0

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
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://_shot_sl_progress.cfg"))
	progress.path = "user://_shot_sl_progress.cfg"
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
			if e.id == "slider":
				entry = e
		if _reduce:
			load("res://core/motion.gd").reduce = true
		_menu._open_at(entry, _level)
		_host = _menu.get_child(_menu.get_child_count() - 1)
		_puzzle = _host._puzzle
		if _host.has_node("HowToPlay"):
			_host.get_node("HowToPlay").free()
		if _mode != "early":
			_puzzle._state.finish()
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
		print("board: band ", st.difficulty, " homesick ", st.homesick, " par ", st.par, " dist ", st.dist_of(st.key),
			", hearts ", _puzzle.hearts, "/", _puzzle.max_hearts, ", out ", _puzzle.out_of_hearts,
			", done ", _puzzle.is_done(), ", solved ", st.is_solved(), ", moves ", _puzzle.moves, ", hints ", _puzzle.hints_left(),
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
	var path := "%s/sl_%s_d%d_%d%s.png" % [_dir, _mode, _level, _n, tag]
	root.get_texture().get_image().save_png(path)
	print("saved ", path, "  tip: ", _puzzle.tip_line().text, "  hearts ", _puzzle.hearts, " streak ", _puzzle._streak,
		" fret ", _puzzle._fret, " love ", _puzzle._love.size(), " flies ", _puzzle._flies.size(), " moves ", _puzzle.moves)

func _mouse(at: Vector2, down: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = down
	ev.position = at
	_puzzle._gui_input(ev)

func _motion(at: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = at
	_puzzle._gui_input(ev)

## A block's grab point at anchor `c`: the middle of its top-left cell.
func _cell_at(c: int) -> Vector2:
	return _puzzle.cell_to_local(c / Gen.COLS, c % Gen.COLS)

## A drag of block `p` through `path` (anchors), spread over `over` seconds
## from `from`; `hold` keeps the finger down at the end.
func _drag(path: PackedInt32Array, from: float, over := 0.4, hold := false) -> void:
	_at(from, func(): _mouse(_cell_at(path[0]), true))
	for i in range(1, path.size()):
		var c: int = path[i]
		_at(from + over * float(i) / float(path.size()), func(): _motion(_cell_at(c)))
	if not hold:
		_at(from + over + 0.05, func(): _mouse(_cell_at(path[path.size() - 1]), false))

## Every move from here, as {"p", "to", "path", "d"} (the distance after).
func _all_moves() -> Array:
	var st = _puzzle._state
	var out: Array = []
	var here: int = st.key
	for p in st.blocks.size():
		var a: int = st.kind(p)
		var base: int = here - Gen.contrib(a, st.at(p))
		for to in st.reach(p):
			if to == st.at(p):
				continue
			out.append({"p": p, "to": to, "path": st.path(p, to), "d": st.dist_of(base + Gen.contrib(a, to))})
	return out

## The first move that would cost a heart here (Hard: a setback; Homesick: a
## dead end), or {}.
func _costly() -> Dictionary:
	var st = _puzzle._state
	var d0: int = st.dist_of(st.key)
	for m: Dictionary in _all_moves():
		if st.homesick and int(m.d) == -1:
			return m
		if not st.homesick and int(m.d) > d0:
			return m
	return {}

## Drives the next move of a shortest way as soon as the board is still.
func _drive(from: float, until: float, each: Callable) -> void:
	var t := from
	while t < until:
		_at(t, func():
			if _puzzle.is_done():
				if _won_at < 0.0:
					_won_at = _t
					for k in [0.4, 1.4, 2.6, 3.8]:
						_at(_t + k, _shot)
					_end = _t + 4.4
				return
			if _puzzle.busy() or not _puzzle._drag.is_empty() or _t < _next_ok:
				return
			var m: Dictionary = _puzzle._state.hint_move()
			if m.is_empty():
				return
			each.call()
			_next_ok = _t + 0.75
			_drag(m.path, _t, 0.3))
		t += 0.1

var _next_ok := 0.0

func _script() -> void:
	var t0 := 1.6
	match _mode:
		"rest":
			_at(0.45, _shot)
			_at(1.2, _shot)
			_at(3.2, _shot)
		"fret":
			_at(t0, func():
				var m := _costly()
				print("costly: ", m)
				if not m.is_empty():
					_drag(m.path, _t, 0.3, true))
			_at(t0 + 0.7, _shot)
			_end = t0 + 1.2
		"cost":
			_at(t0, func():
				var m := _costly()
				if not m.is_empty():
					_drag(m.path, _t, 0.3))
			_at(t0 + 0.55, _shot)
			_at(t0 + 0.85, _shot)
			_at(t0 + 1.4, _shot)
			_end = t0 + 2.0
		"out":
			for k in 4:
				_at(t0 + float(k) * 2.0, func():
					if _puzzle.out_of_hearts:
						return
					var m := _costly()
					if not m.is_empty():
						_drag(m.path, _t, 0.3))
			_at(t0 + 1.0, _shot)
			_at(t0 + 6.0 + 0.8, _shot)
			_at(t0 + 6.0 + 2.2, _shot)
			_at(t0 + 6.0 + 2.4, func():
				for n in root.get_children():
					var card := n.find_child("OutOfHearts", true, false)
					if card != null:
						card.try_again.emit()
						break)
			_at(t0 + 6.0 + 3.4, _shot)
			_end = t0 + 6.0 + 4.0
		"home":
			# the big block dragged up: it shakes its head
			_at(t0, func():
				var st = _puzzle._state
				var b: int = st.big()
				var at: Vector2 = _cell_at(st.at(b))
				_mouse(at, true)
				_motion(at + Vector2(0.0, -_puzzle._cell() * 0.8)))
			_at(t0 + 0.15, _shot)
			_at(t0 + 0.4, func():
				var st = _puzzle._state
				_mouse(_cell_at(st.at(st.big())), false))
			# then nearer moves until a dead end is one move away, and that move
			var at := t0 + 1.0
			for k in 60:
				_at(at, func():
					if _done_home or _puzzle.busy() or not _puzzle._drag.is_empty() or _puzzle.is_done():
						return
					var m := _costly()
					if not m.is_empty() and _moves_done >= 2:
						_done_home = true
						_drag(m.path, _t, 0.3)
						_at(_t + 0.55, _shot)
						_at(_t + 0.95, _shot)
						_at(_t + 1.6, _shot)
						_end = _t + 2.2
						return
					var h: Dictionary = _puzzle._state.hint_move()
					if not h.is_empty():
						_moves_done += 1
						_drag(h.path, _t, 0.3))
				at += 0.8
			_end = at + 1.0
		"nudge":
			# Insane: a finger a little below the big block leans it toward an
			# open cell and must never move it there
			_at(t0, func():
				var st = _puzzle._state
				# play nearer moves until the cell under the big block is open
				for i in 40:
					var b: int = st.big()
					var below: int = st.at(b) + 2 * Gen.COLS
					if below < Gen.N and st.block_at(below) < 0 and st.block_at(below + 1) < 0:
						break
					var h: Dictionary = st.hint_move()
					if h.is_empty():
						break
					st.play(h.p, h.to)
				for q in st.blocks.size():
					_puzzle._disp[q] = _puzzle._still_at(q)
				var b2: int = st.big()
				var was: int = st.at(b2)
				var at: Vector2 = _cell_at(was)
				_mouse(at, true)
				for k in 5:
					_motion(at + Vector2(0.0, _puzzle._cell() * 0.08 * float(k + 1)))
				print("nudge: big was ", was, " now ", st.at(b2), " want ", _puzzle._drag.want)
				_mouse(at, false))
			_end = t0 + 1.0
		"early":
			# Insane: a move let go before the solver is done waits for it
			_at(0.05, func():
				var st = _puzzle._state
				print("ready at open: ", st.solver_ready())
				for p in st.blocks.size():
					if p == st.big():
						continue
					for to in st.reach(p):
						if to != st.at(p):
							_drag(st.path(p, to), _t, 0.15)
							return)
			_at(0.35, func(): print("pending ", not _puzzle._pending.is_empty(), " busy ", _puzzle.busy(), " ready ", _puzzle._state.solver_ready()))
			_at(0.36, _shot)
			_at(3.5, func(): print("after: pending ", not _puzzle._pending.is_empty(), " busy ", _puzzle.busy(), " moves ", _puzzle.moves, " hearts ", _puzzle.hearts))
			_end = 3.6
		"streak":
			_drive(t0, 30.0, func():
				_puzzle.force_gag = _moves_done % 3
				_moves_done += 1
				_at(_t + 0.65, _shot))
			_end = 9.0
		"solve":
			_drive(t0, 200.0, func(): pass)
			_end = 200.0
		"restore":
			_at(0.6, func():
				_puzzle.completed_record = {"hearts": 1, "flawless": true}
				_puzzle.restore_completed()
				print("restored: solved_at ", _puzzle._solved_at, " now ", _puzzle._now(), " exit ", _puzzle._exit(_puzzle._now()), " big ", _puzzle._state.big(), " at ", _puzzle._state.at(_puzzle._state.big())))
			_at(1.4, func():
				print("later: solved_at ", _puzzle._solved_at, " exit ", _puzzle._exit(_puzzle._now()))
				_shot())
			_end = 2.0

var _done_home := false
