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
		for day in _days:
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
	Motion.reduce = false
	print("probe_buttons_board: %d days, %d failures" % [runs, _bad])
	quit(1 if _bad > 0 else 0)
	return true

func _play(board: Control, how: int, rng: RandomNumberGenerator) -> int:
	var st = board.state
	var taps := 0
	while not st.is_solved() and taps < 60000:
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
