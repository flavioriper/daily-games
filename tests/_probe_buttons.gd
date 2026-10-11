extends SceneTree

## Button Box's rules, headless: every picture of the bank on every band is
## scrambled off a seed and played three ways -- by the state's own hand
## (`hint`), by a careless one (any button, at random) and by a greedy one
## that fills the tin first. What must hold on each: the bare patches are as
## many as the buttons in the tin, the tin holds no colour a bare patch
## wants, a full tin still leaves a tap that sews, and the cloth ends whole.
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
		var homes: Array = []
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
						homes.append(st.homes())
						sizes.append(st.count())
						if st.par <= 0:
							_fail("%s band %d seed %d: no par" % [pic.id, band, s])
					_play(st, how, rng, "%s band %d seed %d how %d" % [pic.id, band, s, how])
		pars.sort()
		homes.sort()
		sizes.sort()
		print("band %d: %d deals, buttons %d-%d, par %d-%d (median %d), sewn at the start %d-%d" % [
			band, pars.size(), sizes[0], sizes[-1], pars[0], pars[-1], pars[pars.size() / 2], homes[0], homes[-1]])
	print("probe_buttons: %d runs, %d failures" % [_runs, _bad])
	quit(1 if _bad > 0 else 0)

func _fail(what: String) -> void:
	_bad += 1
	if _bad < 20:
		print("FAIL ", what)

func _play(st, how: int, rng: RandomNumberGenerator, tag: String) -> void:
	_runs += 1
	var guard := 0
	while not st.is_solved() and guard < 5000:
		guard += 1
		var out: Array = []
		var sews: Array = []
		for i in st.slot.size():
			if st.slot[i] >= 0 and st.cur[i] >= 0 and st.cur[i] != st.slot[i]:
				out.append(i)
				if not st._bare(st.cur[i]).is_empty():
					sews.append(i)
		var bare := 0
		for i in st.slot.size():
			if st.slot[i] >= 0 and st.cur[i] < 0:
				bare += 1
				if st.tin.has(st.slot[i]):
					_fail(tag + ": the tin holds a colour a bare patch wants")
					return
		if bare != st.in_tin():
			_fail(tag + ": %d bare patches, %d in the tin" % [bare, st.in_tin()])
			return
		if st.in_tin() > st.capacity():
			_fail(tag + ": the tin is over its places")
			return
		if st.in_tin() > 0 and sews.is_empty():
			_fail(tag + ": buttons in the tin and no tap sews")
			return
		var i := -1
		match how:
			0: i = st.hint()
			1: i = out[rng.randi_range(0, out.size() - 1)]
			2:
				# fill the tin while it takes anything, then sew
				i = out[rng.randi_range(0, out.size() - 1)] if st.in_tin() < st.capacity() else sews[rng.randi_range(0, sews.size() - 1)]
		var res: Dictionary = st.tap(i)
		if res.why == State.REFUSED_FULL:
			i = sews[rng.randi_range(0, sews.size() - 1)]
			res = st.tap(i)
		if res.why != State.OK:
			_fail(tag + ": a tap that should move was refused (%d)" % res.why)
			return
		st.history = []
	if not st.is_solved():
		_fail(tag + ": not solved in 5000 taps")
