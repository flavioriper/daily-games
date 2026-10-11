extends SceneTree

## Shots and probes of Pixel Garden, played through the board's own input
## path (a touch pressed on a peg, dragged, let go). Windowed, one at a time:
##
##     [PG_BANK=<bank.json>] godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_pixel_garden.gd -- [d=0..3] [mode] [rm] [out=<dir>]
##
## Modes: `rest` (half of plate 0 seated, the tweezers moved); `plate` (plate
## 0 finished right: the iron crosses it, the word, a gag); `astray` (Hard:
## plate 0 filled with one bead astray: the frown, the bead home);
## `out` (three plates astray, from when Hard had hearts); `peek` (the
## picture held up over the board); `solve` (every peg but the last through
## the state, the last tapped: the win's iron, the party, the cat, the
## seal); `restore`; and `tour` (Hard and Insane, the big pictures: the
## board whole and bare, a third of it seated, the zoom's button, a run
## dragged on the zoomed board with its beads in the air, two fingers
## pushing to the lower left corner, the picture held, the tutorial's ZOOM
## page on a sheet over the screen for a loop, then the win), which reads
## the draw calls of each stretch twice. Frames
## go to <dir>/pg_<mode>_d<level>_<n>.png; every mode prints the peak draw
## calls and the mean frame from 0.5 s on.

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
## `tour`'s readings: [name, from, to, peak draw calls, ms summed, frames].
var _reads: Array = []

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
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://_shot_pg_progress.cfg"))
	progress.path = "user://_shot_pg_progress.cfg"
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
			if e.id == "pixelgarden":
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
	for r: Array in _reads:
		if _t >= float(r[1]) and _t < float(r[2]):
			r[3] = maxi(int(r[3]), int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)))
			r[4] = float(r[4]) + delta * 1000.0
			r[5] = int(r[5]) + 1
	if _t >= _end:
		if _ms_n > 0:
			print("frames: draw calls peak %d, mean %.2f ms over %d frames" % [_draws_max, _ms_sum / maxf(_ms_n, 1), _ms_n])
		var st = _puzzle._state
		for r: Array in _reads:
			print("read %s: draw calls peak %d, mean %.2f ms over %d frames" % [r[0], r[3], float(r[4]) / maxf(1.0, r[5]), r[5]])
		print("board: band ", st.band, " n ", st.n, " colours ", st.names.size(), " cell ", _puzzle._cell,
			", out ", _puzzle.out_of_hearts, ", done ", _puzzle.is_done(), ", ironed ", st.ironed,
			", moves ", _puzzle.moves, " left ", _puzzle.moves_left, "/", _puzzle.max_moves, ", hints ", _puzzle.hints_left(),
			", flawless ", _puzzle._flawless, ", zoom ", _puzzle.zoom.k, ", size ", _puzzle.size, ", caps ", _puzzle.capabilities())
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
	# (no window, no frame: a dry run of the script still prints its state)
	if DisplayServer.get_name() == "headless":
		print("(headless: no shot at ", snappedf(_t, 0.01), ") zoom ", _puzzle.zoom.k, " placed ", _puzzle._state.placed(),
			" air ", _puzzle._incoming.size(), " toast ", _puzzle._toast, " done ", _puzzle.is_done())
		return
	RenderingServer.force_draw()
	_n += 1
	var path := "%s/pg_%s_d%d_%d%s.png" % [_dir, _mode, _level, _n, tag]
	root.get_texture().get_image().save_png(path)
	print("saved ", path, "  hearts ", _puzzle.hearts, " streak ", _puzzle._streak, " words ", _puzzle._words.size(),
		" love ", _puzzle._love.size(), " flies ", _puzzle._flies.size(), " irons ", _puzzle._irons.size(),
		" toast ", _puzzle._toast, " gone ", _puzzle._pegs_gone(_puzzle._now()), " solved_at ", _puzzle._solved_at, " now ", _puzzle._now(), " gen ", _puzzle._gen)

## A finger down or up at `at` (board-local): touch is not mouse here.
func _mouse(at: Vector2, down: bool, finger := 0) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = finger
	ev.pressed = down
	ev.position = at
	_puzzle._gui_input(ev)

func _slide(at: Vector2, finger := 0) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index = finger
	ev.position = at
	_puzzle._gui_input(ev)

func _read(name: String, from: float, to: float) -> void:
	_reads.append([name, from, to, 0, 0.0, 0])

## Every wanted bead of `pegs` through the state, as a hint-free hand would
## have left them.
func _seat(pegs: Array) -> void:
	var st = _puzzle._state
	var put := 0
	st.begin_stroke()
	for c: int in pegs:
		if int(st.want[c]) != -1 and int(st.beads[c]) == -1 and st.put(c, int(st.want[c])) == "put":
			put += 1
	st.end_stroke()
	# (the counter reads as if a hand had seated them)
	if _puzzle.max_moves > 0:
		_puzzle.moves_left = maxi(1, _puzzle.moves_left - put)
	_puzzle._bands = []
	_puzzle._refresh()

func _tap(c: int) -> void:
	var n: int = _puzzle._state.n
	var at: Vector2 = _puzzle.cell_to_local(c / n, c % n)
	_mouse(at, true)
	_mouse(at, false)

## Seats every wanted bead of plate q, but `skip` (and its bead goes onto
## `stray`, a bare peg of the plate, when one is given).
func _fill(q: int, skip := -1, stray := -1) -> void:
	var st = _puzzle._state
	for c in st.plate_pegs(q):
		if c != skip and int(st.want[c]) != -1 and int(st.beads[c]) != int(st.want[c]):
			_puzzle.set_brush(int(st.want[c]))
			_tap(c)
	if stray >= 0:
		_puzzle.set_brush(int(st.want[skip]))
		_tap(stray)

## A wanted peg and a bare one of plate q, for a bead astray.
func _astray_pair(q: int) -> Vector2i:
	var st = _puzzle._state
	var bare := -1
	var skip := -1
	for c in st.plate_pegs(q):
		if int(st.want[c]) == -1 and bare < 0:
			bare = c
		elif int(st.want[c]) != -1 and skip < 0:
			skip = c
	return Vector2i(skip, bare)

func _script() -> void:
	var st = _puzzle._state
	# The harness feeds _gui_input itself: the Mac's own pointer stays out.
	_puzzle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	match _mode:
		"tour":
			var n: int = st.n
			var z = _puzzle.zoom
			_at(0.8, _shot)
			_at(0.9, func() -> void: _seat(range(0, n * n / 3)))
			_at(1.5, _shot)
			_read("whole 1", 1.6, 2.1)
			_read("whole 2", 2.1, 2.6)
			# The button, on the middle of the board.
			_at(2.7, func() -> void:
				_puzzle._zoom_b.pressed.emit()
				_puzzle._zoom_b.pressed.emit())
			_at(3.2, _shot)
			# A run of the row's own colour dragged on the zoomed board.
			var run := func(row: int, hold: bool) -> void:
				var first := -1
				for x in n:
					var c := row * n + x
					if z.view.grow(-30.0).has_point(_puzzle.cell_to_local(row, x)) and int(st.beads[c]) == -1 and int(st.want[c]) != -1:
						first = c
						break
				if first < 0:
					print("no bare peg in sight on row ", row)
					return
				_puzzle.set_brush(int(st.want[first]))
				var from: Vector2 = _puzzle.cell_to_local(row, first % n)
				_mouse(from, true)
				for i in range(1, 9):
					_slide(from + Vector2(i * _puzzle._cell * z.k, 3.0))
				if not hold:
					_mouse(from, false)
			_at(3.3, func() -> void: run.call(n / 2 - 2, true))
			_at(3.42, _shot)
			_at(3.5, func() -> void: _mouse(Vector2.ZERO, false))
			_read("close 1", 3.3, 3.9)
			_at(3.9, func() -> void: run.call(n / 2 - 1, false))
			_read("close 2", 3.9, 4.6)
			_at(4.3, _shot)
			# Two fingers push the board up and to the right: its lower left.
			_at(4.7, func() -> void:
				var mid: Vector2 = z.view.get_center()
				_mouse(mid, true, 0)
				_mouse(mid + Vector2(140, 0), true, 1)
				for i in range(1, 60):
					_slide(mid + Vector2(i * 20, -i * 20), 0)
					_slide(mid + Vector2(140 + i * 20, -i * 20), 1)
				_mouse(mid, false, 0)
				_mouse(mid, false, 1))
			_at(4.9, _shot)
			_at(5.0, func() -> void: _mouse(_puzzle._thumb.get_center(), true))
			_at(5.5, _shot)
			_at(5.6, func() -> void: _mouse(_puzzle._thumb.get_center(), false))
			# The tutorial's ZOOM page, the diagram alone on a sheet of paper
			# over the screen, for a loop -- before the win, whose card would
			# lie over it.
			var sheet := ColorRect.new()
			_at(6.0, func() -> void:
				var Diagram = load("res://ui/hud/pixel_garden_tutorial_diagram.gd")
				sheet.color = Color("f6efe0")
				sheet.position = Vector2(60, 380)
				sheet.size = Vector2(960, 580)
				sheet.z_index = 50
				_host.add_child(sheet)
				var page: Control = Diagram.new()
				page.lesson = Diagram.Lesson.ZOOM
				page.band = st.band
				page.position = Vector2(10, 10)
				page.size = Vector2(940, 560)
				sheet.add_child(page))
			for t in [8.6, 11.2, 13.2, 14.9, 16.0]:
				_at(t, _shot)
			_at(17.0, func() -> void: sheet.queue_free())
			# The rest through the state, the last bead by a touch: the win.
			_at(17.3, func() -> void:
				var last := -1
				for c in st.size():
					if int(st.want[c]) != -1:
						last = c
				z.reset()
				var rest: Array = range(st.size())
				rest.erase(last)
				for c in st.size():
					if int(st.beads[c]) != -1 and int(st.beads[c]) != int(st.want[c]):
						st._seat(c, -1)
				_seat(rest)
				_puzzle.set_brush(int(st.want[last]))
				_tap(last))
			_read("win", 17.35, 19.9)
			for t in [17.7, 18.3, 18.9, 19.7, 21.9]:
				_at(t, _shot)
			_end = 22.3
		"rest":
			_at(0.6, func() -> void:
				var pegs: PackedInt32Array = st.plate_pegs(0)
				var k := 0
				for c in pegs:
					if int(st.want[c]) != -1 and k < pegs.size() / 4:
						_puzzle.set_brush(int(st.want[c]))
						_tap(c)
						k += 1
				_puzzle.set_brush((_puzzle.brush + 1) % st.names.size()))
			for t in [0.4, 0.64, 0.7, 0.78, 1.0, 1.6]:
				_at(t, _shot)
			_end = 3.0
		"plate":
			_at(0.6, func() -> void: _fill(0))
			for t in [0.7, 0.9, 1.1, 1.3, 1.5, 1.8, 2.2, 3.0]:
				_at(t, _shot)
			_end = 4.0
		"astray":
			_at(0.6, func() -> void:
				var p := _astray_pair(0)
				_fill(0, p.x, p.y))
			for t in [0.7, 1.1, 1.5, 1.75, 1.95, 2.3, 3.0]:
				_at(t, _shot)
			_end = 4.0
		"out":
			_at(0.6, func() -> void:
				var p := _astray_pair(0)
				_fill(0, p.x, p.y))
			_at(2.4, func() -> void:
				var p := _astray_pair(1)
				_fill(1, p.x, p.y))
			_at(4.2, func() -> void:
				var p := _astray_pair(2)
				_fill(2, p.x, p.y))
			for t in [3.0, 5.6, 6.6, 7.6]:
				_at(t, _shot)
			_at(8.0, func() -> void: _puzzle.try_again())
			_at(8.4, _shot)
			_at(9.6, _shot)
			_end = 10.0
		"peek":
			_at(0.8, _shot)
			_at(1.0, func() -> void: _mouse(_puzzle._thumb.get_center(), true))
			_at(1.5, _shot)
			_at(1.7, func() -> void: _mouse(_puzzle._thumb.get_center(), false))
			_at(3.2, _shot)
			_end = 3.5
		"solve":
			_at(0.6, func() -> void:
				var last := -1
				for c in st.size():
					if int(st.want[c]) != -1:
						last = c
				st.begin_stroke()
				for c in st.size():
					if c != last and int(st.want[c]) != -1:
						st.put(c, int(st.want[c]))
				st.end_stroke()
				_puzzle._bands = []
				_puzzle.set_brush(int(st.want[last]))
				_tap(last))
			for t in [0.9, 1.3, 1.7, 2.3, 3.0, 3.6, 4.3, 5.2]:
				_at(t, _shot)
			_end = 5.6
		"restore":
			_at(0.5, func() -> void:
				_puzzle.completed_record = {"hearts": 2, "flawless": true}
				_puzzle.restore_completed())
			_at(1.2, _shot)
			_end = 1.6
