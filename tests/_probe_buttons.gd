extends SceneTree

## Button Box's rules, headless: every picture of the bank on every band is
## scrambled off a seed and played three ways -- by the state's own hand
## (`hint`), by a careless one (any legal move, at random) and by one that
## fills the tin whenever it can. What must hold on each: the bare patches
## are as many as the buttons in the tin, the tin is never over its places,
## while the tin holds anything some move sews, and the cloth ends whole.
##
##   godot --headless --path . --script tests/_probe_buttons.gd [-- seeds=3]

const State = preload("res://puzzles/buttons_state.gd")

var _bad := 0
var _runs := 0

func _initialize() -> void:
	var seeds := 3
	for a in OS.get_cmdline_user_args():
		if a.begins_with("seeds="):
			seeds = int(a.trim_prefix("seeds="))
	var doc: Dictionary = State.bank()
	for band in 4:
		var pars: Array = []
		var sizes: Array = []
		for pic: Dictionary in doc.bands[band]:
			for s in seeds:
				for how in 3:
					var rng := RandomNumberGenerator.new()
					rng.seed = hash([pic.id, s])
					var st = State.new()
					st.band = band
					st.adopt(pic, doc.palette, rng)
					if how == 0:
						pars.append(st.par)
						sizes.append(st.count())
						if st.par <= 0:
							_fail("%s band %d seed %d: no par" % [pic.id, band, s])
					_play(st, how, rng, "%s band %d seed %d how %d" % [pic.id, band, s, how])
		pars.sort()
		sizes.sort()
		print("band %d: %d deals, buttons %d-%d, par %d-%d (median %d)" % [
			band, pars.size(), sizes[0], sizes[-1], pars[0], pars[-1], pars[pars.size() / 2]])
	print("probe_buttons: %d runs, %d failures" % [_runs, _bad])
	quit(1 if _bad > 0 else 0)

func _fail(what: String) -> void:
	_bad += 1
	if _bad < 20:
		print("FAIL ", what)

## Every legal move now: [sews, stows], each a `hint`-shaped move.
func _legal(st) -> Array:
	var sews: Array = []
	var stows: Array = []
	var room: bool = st.in_tin() < st.capacity()
	for c in st.colours.size():
		var held: PackedInt32Array = st.tin_of(c)
		var bare: PackedInt32Array = st.bare_of(c)
		if not held.is_empty() and not bare.is_empty():
			sews.append({"cells": PackedInt32Array(), "places": held, "to": bare[0]})
	var seen := {}
	for i in st.slot.size():
		if st.judge(i) != State.OK or seen.has(i):
			continue
		var run: PackedInt32Array = st.run_of(i)
		for g in run:
			seen[g] = true
		var bare: PackedInt32Array = st.bare_of(st.cur[i])
		if not bare.is_empty():
			sews.append({"cells": run, "places": PackedInt32Array(), "to": bare[bare.size() - 1]})
		if room:
			stows.append({"cells": run, "places": PackedInt32Array(), "to": -1})
	return [sews, stows]

func _play(st, how: int, rng: RandomNumberGenerator, tag: String) -> void:
	_runs += 1
	var guard := 0
	while not st.is_solved() and guard < 8000:
		guard += 1
		var bare := 0
		for i in st.slot.size():
			if st.slot[i] >= 0 and st.cur[i] < 0:
				bare += 1
		if bare != st.in_tin():
			_fail(tag + ": %d bare patches, %d in the tin" % [bare, st.in_tin()])
			return
		if st.in_tin() > st.capacity():
			_fail(tag + ": the tin is over its places")
			return
		var legal := _legal(st)
		var sews: Array = legal[0]
		var stows: Array = legal[1]
		if st.in_tin() > 0 and sews.is_empty():
			_fail(tag + ": buttons in the tin and no move sews")
			return
		if sews.is_empty() and stows.is_empty():
			_fail(tag + ": no move at all")
			return
		var move: Dictionary
		match how:
			0: move = st.hint()
			1:
				var all := sews + stows
				move = all[rng.randi_range(0, all.size() - 1)]
			_:
				var pool := stows if not stows.is_empty() else sews
				move = pool[rng.randi_range(0, pool.size() - 1)]
		if st.play(move).why != State.OK:
			_fail(tag + ": a legal move was refused")
			return
		st.history = []
	if not st.is_solved():
		_fail(tag + ": not solved in 8000 moves")
