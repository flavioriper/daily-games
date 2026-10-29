extends SceneTree

## Pinwheel, measured (2026-10-29 made-fun pass). Per band over `days`
## deals: the fewest taps (`par`), how far the reading carries -- a square
## only one piece can still reach in one way forces that piece's turn, and a
## forced turn rules out every other pose that would lie on it
## (State.reading_chain) -- and a casual tapper: taps the pin whose next turn
## leaves the fewest bare and doubled squares, a random one a third of the
## time, until the frame is covered (cap 400 taps).
##
##     godot --headless --path . --script res://tests/_probe_pw_fun.gd

const State = preload("res://puzzles/pinwheel_state.gd")

func _initialize() -> void:
	for band in 4:
		_band(band)
	quit()

func _trouble(s) -> int:
	var n := 0
	for v: int in s.cover:
		if v != 1:
			n += 1
	return n

func _band(band: int) -> void:
	var rng := RandomNumberGenerator.new()
	var me := RandomNumberGenerator.new()
	me.seed = 11
	var days := 30
	var pars := []
	var over := []
	var read_full := 0
	var read_first := 0
	var unsolved := 0
	var worst_ms := 0
	var steps_checked := 0
	var wrong := 0
	for day in days:
		rng.seed = 9100 + day * 31 + band
		var s = State.new()
		s.setup(rng, band)
		pars.append(s.par)
		var t0 := Time.get_ticks_msec()
		var chain: Array = s.reading_chain()
		worst_ms = maxi(worst_ms, Time.get_ticks_msec() - t0)
		var forced := {}
		for st: Dictionary in chain:
			forced[int(st["piece"])] = true
			steps_checked += 1
			if int(st["turn"]) != int(s.answer[int(st["piece"])]):
				wrong += 1
		var movable := 0
		for p in s.shapes.size():
			if not s.fixed(p):
				movable += 1
		if _all_forced(s, forced):
			read_full += 1
		if not chain.is_empty():
			read_first += 1
		# the casual tapper
		var taps := 0
		while not s.is_solved() and taps < 400:
			var pick := -1
			if me.randf() < 0.33:
				pick = me.randi_range(0, s.shapes.size() - 1)
			else:
				var best := 1 << 30
				for p in s.shapes.size():
					if s.fixed(p):
						continue
					s.turn(p)
					var tr := _trouble(s)
					s.undo()
					if tr < best:
						best = tr
						pick = p
			if pick < 0 or s.fixed(pick):
				continue
			s.turn(pick)
			taps += 1
		if not s.is_solved():
			unsolved += 1
		else:
			over.append(taps - int(pars.back()))
	pars.sort()
	over.sort()
	print("band %d: reading steps %d, against the answer %d wrong" % [band, steps_checked, wrong])
	print("band %d: par p10/p50/p90 %s/%s/%s | reading has a first step %d/%d, carries the whole frame %d/%d (worst %d ms) | tapper over par p50 %s p90 %s, unsolved %d" % [
		band, pars[days / 10], pars[days / 2], pars[days * 9 / 10],
		read_first, days, read_full, days, worst_ms,
		over[over.size() / 2] if not over.is_empty() else "-",
		over[over.size() * 9 / 10] if not over.is_empty() else "-", unsolved])

func _all_forced(s, forced: Dictionary) -> bool:
	for p in s.shapes.size():
		if not s.fixed(p) and not forced.has(p):
			return false
	return true
