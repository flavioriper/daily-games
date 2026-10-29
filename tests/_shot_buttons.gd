extends SceneTree

## Shots and probes of Button Box, played through the board's own input path (a
## touch pressed, dragged and let go). Windowed, one at a time:
##
##     godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_buttons.gd -- [d=0..3] [mode] [rm] [out=<dir>]
##
## Modes: `rest` (the entrance and the cloth); `merge` (a run landing and
## merging together); `play` (four moves of the
## state's own hand, shot picked and in the air); `refuse` (a sewn button
## tapped; the tin filled and tapped once more; a patch of another colour); `hint` (the bulb, then Undo);
## `solve` (the hand's taps to the win); `out` (Insane: the taps spent
## carelessly, the card, Try again); `reset`; `restore` (a day reopened
## already sewn); `howto` (the tutorial's pages as they play, five on Hard and
## Insane); `big` (Hard and Insane: the picture whole at rest, then close by
## the button with a run picked, the run in the air to the tin, a pan by one
## finger and a pinch back to whole, the draw calls of each read apart).
## `howzoom` is the tutorial's ZOOM page alone (Hard and Insane).
## `PG_BANK=<file>` points the board at another bank of pictures.
## Frames go to <dir>/bb_<mode>_d<level>_<n>.png; every mode prints the peak
## draw calls and the mean frame from 0.5 s on.

const SHOT_DIR := "/tmp"
const GAP := 0.55

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
var _move := {}
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
		elif a == "trace":
			pass
		elif a.begins_with("out="):
			_dir = a.substr(4)
		else:
			_mode = a
	var progress = load("res://core/progress.gd")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://_shot_bb_progress.cfg"))
	progress.path = "user://_shot_bb_progress.cfg"
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
			if e.id == "buttons":
				entry = e
		if _reduce:
			load("res://core/motion.gd").reduce = true
		_menu._open_at(entry, _level)
		_host = _menu.get_child(_menu.get_child_count() - 1)
		_puzzle = _host._puzzle
		# The real pointer over the window must not play the board.
		_puzzle.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
		_mark_peak = maxi(_mark_peak, int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)))
	if _t >= _end:
		if _ms_n > 0:
			print("frames: draw calls peak %d, mean %.2f ms over %d frames" % [_draws_max, _ms_sum / maxf(_ms_n, 1), _ms_n])
		var st = _puzzle.state
		print("board: band ", st.band, " ", st.w, "x", st.h, " ", st.name_key, " sewn ", st.homes(), "/", st.count(), " taps ", st.taps,
			" par ", st.par, ", tin ", st.in_tin(), "/", st.capacity(), ", left ", _puzzle.moves_left, "/", _puzzle.max_moves,
			", out ", _puzzle.out_of_hearts, ", done ", _puzzle.is_done(), ", solved ", st.is_solved(), ", hints ", _puzzle.hints_left(),
			", can_undo ", _puzzle.can_undo(), ", pill '", _puzzle.pill_text(), "'")
		print("share:\n", _puzzle.share_glyphs())
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

## The draw calls since the last mark, by name: the peak of each stretch.
var _mark_peak := 0
func _mark(what: String) -> void:
	print("draws: %s, peak %d (now %d)" % [what, _mark_peak, int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))])
	_mark_peak = 0

func _at(t: float, what: Callable) -> void:
	_plan.append([t, what])
	_plan.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))

func _shot(tag := "") -> void:
	RenderingServer.force_draw()
	_n += 1
	var path := "%s/bb_%s_d%d_%d%s.png" % [_dir, _mode, _level, _n, tag]
	root.get_texture().get_image().save_png(path)
	print("saved ", path, "  toast: ", _puzzle._toast, "  sewn ", _puzzle.state.homes(), " taps ", _puzzle.state.taps,
		" tin ", _puzzle.state.in_tin(), "/", _puzzle.state.capacity(), " left ", _puzzle.moves_left)

## A tap: a touch pressed and let go over `cell`, through the board's input.
func _tap(cell: int) -> void:
	var at: Vector2 = _puzzle.cell_screen(cell)
	for down in [true, false]:
		var ev := InputEventScreenTouch.new()
		ev.index = 0
		ev.pressed = down
		ev.position = at
		_puzzle._gui_input(ev)

func _touch(at: Vector2, down: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = 0
	ev.pressed = down
	ev.position = at
	_puzzle._gui_input(ev)

## A tap on the tin: place `p`, or its first free place.
func _tap_tin(p := -1) -> void:
	var st = _puzzle.state
	var at: Vector2 = _puzzle.tin_centre(p if p >= 0 else mini(st.in_tin(), st.capacity() - 1))
	for down in [true, false]:
		var ev := InputEventScreenTouch.new()
		ev.index = 0
		ev.pressed = down
		ev.position = at
		_puzzle._gui_input(ev)

## The pick of the state's own next move.
func _pick() -> void:
	var move: Dictionary = _puzzle.state.hint()
	if move.is_empty():
		return
	_move = move
	# a pick stays picked after its move: put it down before the next
	if _puzzle.holding():
		_puzzle._drop()
	if OS.get_cmdline_user_args().has("trace"):
		print("pick ", move, " held_c ", _puzzle._held_c, " tin ", _puzzle.state.tin, " taps ", _puzzle.state.taps)
	if (move.cells as PackedInt32Array).is_empty():
		_tap_tin(move.places[0])
	else:
		_tap(move.cells[0])

## And where it goes.
func _place() -> void:
	if _move.is_empty():
		return
	if int(_move.to) >= 0:
		_tap(int(_move.to))
	else:
		_tap_tin()
	if OS.get_cmdline_user_args().has("trace"):
		print("  placed: taps ", _puzzle.state.taps, " held_c ", _puzzle._held_c, " cells ", _puzzle._held_cells, " places ", _puzzle._held_places, " toast ", _puzzle._toast)
	_move = {}

func _next() -> void:
	_pick()
	_place()

func _first(test: Callable) -> int:
	for i in _puzzle.state.slot.size():
		if _puzzle.state.slot[i] >= 0 and test.call(i):
			return i
	return -1

## A button out of place.
func _loose() -> int:
	var st = _puzzle.state
	return _first(func(i: int) -> bool: return st.cur[i] >= 0 and not st.is_home(i))

func _script() -> void:
	var st = _puzzle.state
	match _mode:
		"rest":
			_at(0.3, _shot)
			_at(0.5, _shot)
			_at(2.0, _shot)
			_end = 3.0
		"play":
			_at(1.6, _pick)
			_at(2.3, _shot)
			_at(2.4, _place)
			_at(2.55, _shot)
			# the first of the run settling into its socket, the rest in the air
			_at(2.85, _shot)
			_at(3.2, _pick)
			_at(3.7, _shot)
			_at(3.8, _place)
			_at(3.95, _shot)
			_at(4.6, _next)
			_at(5.2, _next)
			_at(6.0, _shot)
			_end = 6.6
		"merge":
			# a run on its way: in the air, standing on its slots, swelling,
			# going in as a wave, merged
			# the hand's own moves played quietly up to its first onto the
			# picture, so the one shot sews
			_at(1.4, func() -> void:
				var st_ = _puzzle.state
				var guard := 0
				while guard < 200:
					guard += 1
					var m: Dictionary = st_.hint()
					if m.is_empty() or (int(m.to) >= 0 and (m.cells as PackedInt32Array).size() >= 4):
						break
					st_.play(m)
				_puzzle._deal()
				_puzzle._layout()
				_puzzle._request())
			_at(1.6, _pick)
			_at(2.0, _place)
			for dt in [0.7, 1.4, 1.5, 1.6, 1.7, 1.8, 1.95, 2.4]:
				_at(2.0 + dt, _shot)
			_end = 4.8
		"refuse":
			_at(1.6, func() -> void: _tap(_first(st.is_home) if _first(st.is_home) >= 0 else 0))
			_at(1.75, _shot)
			var t := 2.4
			for k in 10:
				_at(t, func() -> void:
					if st.in_tin() < st.capacity() and _loose() >= 0:
						_tap(_loose())
						_tap_tin())
				t += 0.5
			# the tin is full: a run picked and the tin tapped once more
			_at(t, func() -> void: _tap(_loose()))
			_at(t + 0.3, func() -> void: _tap_tin())
			_at(t + 0.5, _shot)
			# a pick and a bare patch of another colour
			_at(t + 1.0, func() -> void:
				var wrong := _first(func(i: int) -> bool: return st.cur[i] < 0 and st.slot[i] != _puzzle._held_c)
				if wrong >= 0:
					_tap(wrong))
			_at(t + 1.2, _shot)
			_end = t + 2.4
		"hint":
			_at(1.6, func() -> void: _host._on_hint())
			_at(1.75, _shot)
			_at(2.5, _shot)
			_at(2.8, func() -> void: _host._on_undo())
			_at(3.3, _shot)
			_end = 4.0
		"solve":
			var t := 1.4
			for k in st.par + 2:
				_at(t, _pick)
				_at(t + 0.2, _place)
				t += 0.6
			for dt in [-3.0, 0.0, 0.5, 1.0, 1.6, 2.6, 4.2]:
				_at(t + dt, _shot)
			_end = t + 5.2
		"parts":
			# Insane in parts: the first part at rest, sewn by the state's own
			# hand to its last move, that move through the board, the hop,
			# the slide half way and the next part in its place
			_at(1.4, _shot)
			_at(1.6, func() -> void:
				var st_ = _puzzle.state
				var guard := 0
				while guard < 4000:
					guard += 1
					var m: Dictionary = st_.hint()
					if m.is_empty():
						break
					var cur_: PackedInt32Array = st_.cur.duplicate()
					var tin_: PackedInt32Array = st_.tin.duplicate()
					var taps_: int = st_.taps
					st_.play(m)
					if st_.part_done():
						st_.cur = cur_
						st_.tin = tin_
						st_.taps = taps_
						st_._recount()
						break
				_puzzle._deal()
				_puzzle._layout()
				_puzzle._request())
			_at(2.0, _shot)
			_at(2.4, _pick)
			_at(2.6, _place)
			for dt in [1.35, 1.45, 1.55, 1.65, 3.0]:
				_at(2.6 + dt, _shot)
			_end = 6.4
		"out":
			var t := 1.6
			for k in _puzzle.max_moves * 2:
				_at(t, func() -> void:
					if _puzzle.moves_left <= 0:
						return
					# a careless hand: one button at a time into the tin, then the hand's own
					if st.in_tin() < st.capacity() and k % 3 != 0 and _loose() >= 0:
						_tap(_loose())
						_tap_tin()
					else:
						_next())
				t += 0.4
			_at(2.4, _shot)
			_at(t + 0.6, _shot)
			_at(t + 2.4, _shot)
			_at(t + 2.8, func() -> void: _puzzle.try_again())
			_at(t + 3.6, _shot)
			_end = t + 4.2
		"reset":
			var t := 1.4
			for k in 4:
				_at(t, _next)
				t += 0.4
			_at(t + 0.4, func() -> void: _host._on_reset())
			_at(t + 0.5, _shot)
			_at(t + 1.4, _shot)
			_end = t + 2.0
		"howto":
			# the tutorial card as the ? opens it, each page shot twice as it plays
			_at(0.6, func() -> void: _host._show_tutorial())
			var t := 1.0
			for page in (5 if _level >= 2 else 4):
				_at(t + 4.2, _shot)
				_at(t + 7.5, _shot)
				_at(t + 7.7, func() -> void:
					if is_instance_valid(_host._tutorial):
						_host._tutorial._turn(1))
				t += 7.8
			_at(t + 0.2, func() -> void:
				if is_instance_valid(_host._tutorial):
					_host._tutorial.free())
			_end = t + 0.6
		"big":
			# a dozen of the hand's moves first, so some are sewn; then whole,
			# at rest
			_at(0.9, func() -> void:
				for k in 12:
					_next()
				if _puzzle.holding():
					_puzzle._drop())
			_at(1.6, _shot)
			_at(1.7, _mark.bind("whole at rest"))
			# close, by the button, on the picture's middle
			_at(2.4, func() -> void:
				_puzzle.zoom_button()
				_puzzle.zoom_button())
			_at(3.0, _mark.bind("going close"))
			# a run picked: the biggest in sight
			_at(3.1, func() -> void:
				var best := -1
				var most := 0
				for i in st.slot.size():
					if st.slot[i] >= 0 and st.cur[i] >= 0 and not st.is_home(i) \
							and _puzzle._view.grow(-120.0).has_point(_puzzle.cell_screen(i)):
						var n: int = st.run_of(i).size()
						if n > most:
							most = n
							best = i
				print("pick: a run of ", most, " at ", best)
				_tap(best))
			_at(3.8, _shot)
			_at(3.9, _mark.bind("close, a run picked"))
			# into the tin, shot in the air
			_at(4.0, func() -> void: _tap_tin())
			_at(4.16, _shot)
			_at(4.3, _shot)
			_at(4.9, _shot)
			_at(5.0, _mark.bind("the run to the tin"))
			# one finger pans
			_at(5.2, func() -> void:
				var from: Vector2 = _puzzle._view.get_center()
				_touch(from, true)
				for k in 8:
					var ev := InputEventScreenDrag.new()
					ev.index = 0
					ev.position = from + Vector2(-30.0, -22.0) * (k + 1)
					_puzzle._gui_input(ev)
				_touch(from + Vector2(-240.0, -176.0), false))
			_at(5.5, _shot)
			# the bulb's place brings the picture to it (Hard has a bulb)
			_at(5.7, func() -> void:
				if _puzzle.hints_left() > 0:
					_host._on_hint())
			_at(6.6, _shot)
			_at(6.7, _mark.bind("panned, hinted"))
			# whole again
			_at(6.9, func() -> void:
				_puzzle.zoom_button()
				_puzzle.zoom_button())
			_at(7.6, _shot)
			_at(7.7, _mark.bind("whole again"))
			_end = 8.2
		"howzoom":
			# the tutorial's ZOOM page (Hard and Insane), shot as it plays
			_at(0.6, func() -> void: _host._show_tutorial())
			_at(1.0, func() -> void:
				for k in 3:
					if is_instance_valid(_host._tutorial):
						_host._tutorial._turn(1))
			for t in [2.6, 4.3, 5.4, 6.6, 7.6, 9.0, 10.2]:
				_at(t, _shot)
			_at(10.6, func() -> void:
				if is_instance_valid(_host._tutorial):
					_host._tutorial.free())
			_end = 11.0
		"restore":
			_at(0.2, func() -> void:
				_puzzle.completed_record = {"taps": st.par + 2, "left": 0}
				_puzzle.restore_completed())
			_at(0.5, _shot)
			# the host lays a won day out for the win screen: whole, for a
			# picture in parts
			_at(0.7, func() -> void: _puzzle.set_clear(_puzzle._clear.x, _puzzle._clear.y, true))
			_at(1.1, _shot)
			_end = 1.5
