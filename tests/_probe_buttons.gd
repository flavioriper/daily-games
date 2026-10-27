extends SceneTree

## Button Box's rules, headless: every picture of the bank on every band is
## scrambled off a seed (three seeds on Easy and Medium, one on the big
## pictures of Hard and Insane) and played three ways -- by the state's own hand
## (`hint`), by a careless one (any legal move, at random) and by one that
## fills the tin whenever it can. What must hold on each: the bare patches
## are as many as the buttons in the tin, the tin is never over its places,
## while the tin holds anything some move sews, the cloth ends whole, and the
## state's own hand ends on the par.
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
		var t0 := Time.get_ticks_msec()
		# Hard and Insane both deal the bank's biggest band (BANK_BAND)
		var pics: Array = doc.bands[State.BANK_BAND[band]]
		for pic: Dictionary in pics:
			# a big picture is a hundred times the moves: one seed of it
			for s in (seeds if band < State.BIG_FROM else 1):
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
		print("band %d: %d deals, buttons %d-%d, par %d-%d (median %d), %d ms" % [
			band, pars.size(), sizes[0], sizes[-1], pars[0], pars[-1], pars[pars.size() / 2], Time.get_ticks_msec() - t0])
	print("probe_buttons: %d runs, %d failures" % [_runs, _bad])
	quit(1 if _bad > 0 else 0)

func _fail(what: String) -> void:
	_bad += 1
	if _bad < 20:
		print("FAIL ", what)

## What a hand may do now, {tin, sew, stow}: the colours the tin holds that
## have a bare patch, the loose buttons whose colour has one, and the loose
## buttons the tin has room for. One pass of the cloth: listing every run
## against every bare patch was a second a move on a 32-square cloth.
func _legal(st) -> Dictionary:
	var bare := {}
	var loose: Array = []
	for i in st.slot.size():
		if st.slot[i] < 0:
			continue
		if st.cur[i] < 0:
			if not bare.has(st.slot[i]):
				bare[st.slot[i]] = []
			(bare[st.slot[i]] as Array).append(i)
		elif st.cur[i] != st.slot[i]:
			loose.append(i)
	var from_tin: Array = []
	for c: int in bare:
		if not st.tin_of(c).is_empty():
			from_tin.append(c)
	var sew: Array = []
	for i: int in loose:
		if bare.has(st.cur[i]):
			sew.append(i)
	return {"bare": bare, "tin": from_tin, "sew": sew, "stow": loose if st.in_tin() < st.capacity() else []}

func _random(st, legal: Dictionary, kind: String, rng: RandomNumberGenerator) -> Dictionary:
	var pool: Array = legal[kind]
	var one: int = pool[rng.randi_range(0, pool.size() - 1)]
	if kind == "tin":
		var to: Array = legal.bare[one]
		return {"cells": PackedInt32Array(), "places": st.tin_of(one), "to": to[rng.randi_range(0, to.size() - 1)]}
	if kind == "stow":
		return {"cells": st.run_of(one), "places": PackedInt32Array(), "to": -1}
	var to: Array = legal.bare[st.cur[one]]
	return {"cells": st.run_of(one), "places": PackedInt32Array(), "to": to[rng.randi_range(0, to.size() - 1)]}

func _play(st, how: int, rng: RandomNumberGenerator, tag: String) -> void:
	_runs += 1
	var guard := 0
	while not st.is_solved() and guard < 20000:
		guard += 1
		if st.part_done():
			st.next_part()
		var legal := _legal(st)
		var bare := 0
		for c: int in legal.bare:
			bare += (legal.bare[c] as Array).size()
		if bare != st.in_tin():
			_fail(tag + ": %d bare patches, %d in the tin" % [bare, st.in_tin()])
			return
		if st.in_tin() > st.capacity():
			_fail(tag + ": the tin is over its places")
			return
		var sews: bool = not (legal.tin as Array).is_empty() or not (legal.sew as Array).is_empty()
		if st.in_tin() > 0 and not sews:
			_fail(tag + ": buttons in the tin and no move sews")
			return
		if not sews and (legal.stow as Array).is_empty():
			_fail(tag + ": no move at all")
			return
		var move: Dictionary
		var kinds: Array = []
		for kind: String in ["tin", "sew", "stow"]:
			if not (legal[kind] as Array).is_empty():
				kinds.append(kind)
		match how:
			0: move = st.hint()
			1: move = _random(st, legal, kinds[rng.randi_range(0, kinds.size() - 1)], rng)
			_: move = _random(st, legal, "stow" if kinds.has("stow") else kinds[rng.randi_range(0, kinds.size() - 1)], rng)
		if st.play(move).why != State.OK:
			_fail(tag + ": a legal move was refused")
			return
		st.history = []
	if not st.is_solved():
		_fail(tag + ": not solved in 20000 moves")
	elif how == 0 and st.taps != st.par:
		_fail(tag + ": the hand took %d moves and the par says %d" % [st.taps, st.par])
