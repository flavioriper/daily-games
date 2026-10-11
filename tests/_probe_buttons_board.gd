extends SceneTree

## Button Box played through the board's own taps, headless and with no
## window: `tap(cell)` and `tap_tin(place)` as a finger makes them, by
## hands that know no better -- one that taps a button and then anything at
## all (a bare patch of any colour, any place of the tin, its wood, another
## button), and one that always tries the tin first and never lets a pick
## go on purpose. Every day must end sewn: a state the taps cannot get out
## of is the bug this was written for (2026-10-11, a pick that outlived its
## move kept the tin's own buttons out of reach).
##
##
## Hard and Insane are 24 and 32 square (2026-10-11), and a hand that taps
## anything takes twenty thousand taps to sew one: they are played one day
## each, whatever `days` says. Then the zoom, on an Insane day, through
## `_gui_input` with the touches a phone sends: it goes close and comes back
## and stays inside its limits, a tap on a picture seen close lands on the
## square under the finger, and a finger that pans or pinches taps nothing.
##
##   godot --headless --path . --script tests/_probe_buttons_board.gd [-- days=6]

const Board = preload("res://puzzles/buttons2d.gd")
const Motion = preload("res://core/motion.gd")

var _days := 6
var _started := false
var _bad := 0

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("days="):
			_days = int(a.trim_prefix("days="))

func _process(_delta: float) -> bool:
	if _started:
		return false
	_started = true
	Motion.reduce = true
	var runs := 0
	for band in 4:
		var worst := 0
		for day in (_days if band < 2 else 1):
			for how in 2:
				var board: Control = Board.new()
				board.size = Vector2(1080, 1920)
				root.add_child(board)
				var rng := RandomNumberGenerator.new()
				rng.seed = hash([band, day, 7])
				board.start(rng, band)
				# Insane's count is not what is on trial here
				board.max_moves = 0
				var taps := _play(board, how, rng)
				runs += 1
				worst = maxi(worst, taps)
				if not board.state.is_solved():
					_bad += 1
					print("FAIL band %d day %d how %d: %d of %d sewn after %d taps, tin %d of %d, held %d" % [
						band, day, how, board.state.homes(), board.state.count(), taps,
						board.state.in_tin(), board.state.capacity(), board._held_c])
				board.free()
		print("band %d: the longest day took %d taps" % [band, worst])
	_zoom()
	Motion.reduce = false
	print("probe_buttons_board: %d days, %d failures" % [runs, _bad])
	quit(1 if _bad > 0 else 0)
	return true

func _play(board: Control, how: int, rng: RandomNumberGenerator) -> int:
	var st = board.state
	var taps := 0
	while not st.is_solved() and taps < 200000:
		taps += 1
		var loose: Array = []
		var bare: Array = []
		for i in st.slot.size():
			if st.slot[i] < 0:
				continue
			if st.cur[i] < 0:
				bare.append(i)
			elif not st.is_home(i):
				loose.append(i)
		if how == 0:
			# anything at all
			match rng.randi_range(0, 5):
				0, 1:
					if not loose.is_empty():
						board.tap(loose[rng.randi_range(0, loose.size() - 1)])
				2, 3:
					if not bare.is_empty():
						board.tap(bare[rng.randi_range(0, bare.size() - 1)])
				4:
					board.tap_tin(rng.randi_range(-1, 11))
				5:
					board.tap(rng.randi_range(0, st.slot.size() - 1))
		else:
			# the tin first, always: pick a run and tap the tin; when that is
			# refused, tap a button in the tin and then a bare patch
			if not loose.is_empty() and st.in_tin() < st.capacity() and rng.randf() < 0.6:
				board.tap(loose[rng.randi_range(0, loose.size() - 1)])
				board.tap_tin(rng.randi_range(-1, 11))
			elif st.in_tin() > 0 and rng.randf() < 0.5:
				var places: Array = []
				for p in st.tin.size():
					if st.tin[p] >= 0:
						places.append(p)
				# with a run still picked off the cloth, as a player would have
				if not loose.is_empty():
					board.tap(loose[rng.randi_range(0, loose.size() - 1)])
				board.tap_tin(places[rng.randi_range(0, places.size() - 1)])
				if not bare.is_empty():
					board.tap(bare[rng.randi_range(0, bare.size() - 1)])
			elif not loose.is_empty():
				board.tap(loose[rng.randi_range(0, loose.size() - 1)])
				if not bare.is_empty():
					board.tap(bare[rng.randi_range(0, bare.size() - 1)])
	return taps

func _check(ok: bool, what: String) -> void:
	if not ok:
		_bad += 1
		print("FAIL zoom: ", what)

func _touch(board: Control, index: int, at: Vector2, down: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = index
	ev.pressed = down
	ev.position = at
	board._gui_input(ev)

func _drag(board: Control, index: int, from: Vector2, to: Vector2, steps := 6) -> void:
	for k in steps:
		var ev := InputEventScreenDrag.new()
		ev.index = index
		ev.position = from.lerp(to, float(k + 1) / steps)
		ev.relative = (to - from) / steps
		board._gui_input(ev)

## A button out of place that the screen shows now, well inside the room.
func _loose_in_sight(board: Control, skip := -1) -> int:
	var st = board.state
	var room: Rect2 = board._view.grow(-80.0)
	for i in st.slot.size():
		if i != skip and st.slot[i] >= 0 and st.cur[i] >= 0 and not st.is_home(i) and room.has_point(board.cell_screen(i)):
			return i
	return -1

func _zoom() -> void:
	var was := _bad
	for band in [1, 2, 3]:
		var board: Control = Board.new()
		board.size = Vector2(1080, 1920)
		root.add_child(board)
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([band, 3, 7])
		board.start(rng, band)
		board.max_moves = 0
		var z = board.zoom
		var st = board.state
		if band < 2:
			_check(not z.enabled, "Medium has a zoom")
			board.zoom_button()
			_check(is_equal_approx(z.k, 1.0), "Medium zoomed")
			board.free()
			continue
		_check(z.enabled and z.k_near > 1.2 and z.k_max >= z.k_near, "band %d: no zoom (near %.2f, most %.2f)" % [band, z.k_near, z.k_max])
		print("zoom band %d: a square %.1f px whole, %.1f at the button, %.1f at the most" % [
			band, board._cell, board._cell * z.k_near, board._cell * z.k_max])
		# the button: close, and whole again
		board.zoom_button()
		_check(is_equal_approx(z.k, z.k_near), "the button did not go close")
		var p := Vector2(333.0, 777.0)
		_check(z.to_layout(z.to_screen(p)).distance_to(p) < 0.01, "to_layout does not undo to_screen")
		board.zoom_button()
		_check(is_equal_approx(z.k, 1.0) and z.xf() == Transform2D.IDENTITY, "the button did not come back whole")
		# a tap on the whole picture lands on its square
		var i := _loose_in_sight(board)
		_touch(board, 0, board.cell_screen(i), true)
		_touch(board, 0, board.cell_screen(i), false)
		_check(board._held_cells.has(i), "whole: the tap did not pick the square under it")
		board._drop()
		# close: a tap lands on the square under the finger
		board.zoom_button()
		for round in 3:
			i = _loose_in_sight(board, i)
			var at: Vector2 = board.cell_screen(i)
			_check(board._cell_under(at) == i, "close: the square under the finger is another")
			_check(board._cell_under(at + Vector2.ONE * board._cell * z.k * 0.4) == i, "close: the square's corner is another's")
			_touch(board, 0, at, true)
			_touch(board, 0, at, false)
			_check(board._held_cells.has(i) and board._held_cells[0] == i, "close: the tap did not pick the square under it")
			board._drop()
		# a finger that shakes less than the slop still taps
		i = _loose_in_sight(board)
		var here: Vector2 = board.cell_screen(i)
		_touch(board, 0, here, true)
		_drag(board, 0, here, here + Vector2(5.0, 4.0), 2)
		_touch(board, 0, here + Vector2(5.0, 4.0), false)
		_check(board._held_cells.has(i), "a finger that barely moved did not tap")
		board._drop()
		# one finger dragged pans, and letting go taps nothing
		var taps: int = st.taps
		var xf: Transform2D = z.xf()
		here = board.cell_screen(i)
		_touch(board, 0, here, true)
		_drag(board, 0, here, here + Vector2(-140.0, -90.0))
		_check(z.busy(), "a drag is not a pan")
		_touch(board, 0, here + Vector2(-140.0, -90.0), false)
		_check(z.xf() != xf, "the pan moved nothing")
		_check(not board.holding() and st.taps == taps, "a pan tapped")
		_check(not z.busy(), "the pan never ended")
		# and the tap after it lands where the picture is now
		i = _loose_in_sight(board)
		_touch(board, 0, board.cell_screen(i), true)
		_touch(board, 0, board.cell_screen(i), false)
		_check(board._held_cells.has(i), "after a pan: the tap did not pick the square under it")
		# a pan with a pick in hand keeps the pick
		here = board._view.get_center()
		_touch(board, 0, here, true)
		_drag(board, 0, here, here + Vector2(120.0, 60.0))
		_touch(board, 0, here + Vector2(120.0, 60.0), false)
		_check(board._held_cells.has(i), "a pan dropped the pick")
		board._drop()
		# two fingers: apart as far as it goes, and no tap
		var a: Vector2 = board._view.get_center() + Vector2(-40.0, 0.0)
		var b: Vector2 = board._view.get_center() + Vector2(40.0, 0.0)
		_touch(board, 0, a, true)
		_touch(board, 1, b, true)
		_drag(board, 1, b, b + Vector2(900.0, 0.0), 12)
		_check(is_equal_approx(z.k, z.k_max), "a pinch went past the most, or not to it (%.3f of %.3f)" % [z.k, z.k_max])
		_touch(board, 1, b + Vector2(900.0, 0.0), false)
		_touch(board, 0, a, false)
		_check(not board.holding() and st.taps == taps, "a pinch tapped")
		# the picture always covers its room
		for corner in [Vector2(-5000.0, -5000.0), Vector2(5000.0, 5000.0)]:
			here = board._view.get_center()
			_touch(board, 0, here, true)
			_drag(board, 0, here, here + corner, 4)
			_touch(board, 0, here + corner, false)
			var shown: Rect2 = z.xf() * board._view
			_check(shown.grow(0.5).encloses(board._view), "a pan left the room uncovered")
		# together again: whole, and not past it
		a = board._view.get_center() + Vector2(-400.0, 0.0)
		b = board._view.get_center() + Vector2(400.0, 0.0)
		_touch(board, 0, a, true)
		_touch(board, 1, b, true)
		_drag(board, 1, b, a + Vector2(8.0, 0.0), 12)
		_touch(board, 1, a + Vector2(8.0, 0.0), false)
		_touch(board, 0, a, false)
		_check(is_equal_approx(z.k, 1.0) and z.xf().origin.length() < 0.01, "a pinch together did not end whole")
		# the tin is never zoomed: a run goes in from a picture seen close
		board.zoom_button()
		i = _loose_in_sight(board)
		_touch(board, 0, board.cell_screen(i), true)
		_touch(board, 0, board.cell_screen(i), false)
		var in_tin: int = st.in_tin()
		_touch(board, 0, board.tin_centre(0), true)
		_touch(board, 0, board.tin_centre(0), false)
		_check(st.in_tin() > in_tin, "close: a tap on the tin put nothing in")
		# Reset is the whole picture again
		board.reset_board()
		_check(is_equal_approx(z.k, 1.0), "Reset left the picture close")
		board.free()
	print("probe_buttons_board: the zoom, %d failures" % (_bad - was))
