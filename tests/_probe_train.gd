extends SceneTree

## Toy Cannons' rules (the board built as Toy Train, its names kept), headless: every picture of every band is dealt off a
## few seeds and played four ways -- the deal's own line, an engine at a
## time; the state's own hand (`hint`), an engine at a time; the same hand
## sending as fast as the loop lets it; and a careless one, any engine a tap
## can send at any tick. What must hold: a colour's engines have room for
## exactly its blocks at every tick, the loop and the siding are never over
## their places, the line wins in its par without holding more than
## REF_PARKED in the siding, and on Easy to Hard every way ends with the rug
## clear. Insane can be lost: how often each hand does is printed.
##
##   godot --headless --path . --script tests/_probe_train.gd [-- seeds=3 band=2]

const State = preload("res://puzzles/train_state.gd")

const GUARD := 200000

var _bad := 0
var _runs := 0

func _initialize() -> void:
	var seeds := 3
	var only := -1
	for a in OS.get_cmdline_user_args():
		if a.begins_with("seeds="):
			seeds = int(a.trim_prefix("seeds="))
		if a.begins_with("band="):
			only = int(a.trim_prefix("band="))
	var doc: Dictionary = State.bank()
	for band in 4:
		if only >= 0 and band != only:
			continue
		var t0 := Time.get_ticks_msec()
		var pics: Array = State.pictures(band)
		var engines: Array = []
		var loads: Array = []
		var pars: Array = []
		var line_ticks: Array = []
		var fast_ticks: Array = []
		var lost := [0, 0, 0, 0]
		var deals := 0
		var deal_ms := 0
		for pic: Dictionary in pics:
			for s in seeds:
				deals += 1
				for how in 4:
					var rng := RandomNumberGenerator.new()
					rng.seed = hash([pic.id, s, band])
					var st = State.new()
					st.band = band
					var d0 := Time.get_ticks_msec()
					st.adopt(pic, doc.palette, rng)
					deal_ms = maxi(deal_ms, Time.get_ticks_msec() - d0)
					var tag := "%s band %d seed %d how %d" % [pic.id, band, s, how]
					if how == 0:
						engines.append(st.colour.size())
						pars.append(st.par)
						for n in st.load_:
							loads.append(n)
						_check_deal(st, tag)
					var won := _play(st, how, rng, tag)
					if not won:
						lost[how] += 1
						if band < State.INSANE or how == 0:
							_fail("%s: not won (left %d, jammed %s, ticks %d)" % [tag, st.left, st.jammed, st.ticks])
					elif how == 0:
						line_ticks.append(st.ticks)
						if st.taps != st.par:
							_fail("%s: line took %d taps, par %d" % [tag, st.taps, st.par])
					elif how == 2:
						fast_ticks.append(st.ticks)
		engines.sort()
		loads.sort()
		pars.sort()
		line_ticks.sort()
		fast_ticks.sort()
		print("band %d: %d deals, engines %d-%d (median %d), loads %d-%d (median %d), par %d-%d (median %d), line ticks median %d max %d, fast ticks median %d, lost line/hand/fast/careless %s, slowest deal %d ms, %d ms" % [
			band, deals, engines[0], engines[-1], engines[engines.size() / 2], loads[0], loads[-1], loads[loads.size() / 2],
			pars[0], pars[-1], pars[pars.size() / 2], line_ticks[line_ticks.size() / 2], line_ticks[-1],
			fast_ticks[fast_ticks.size() / 2] if not fast_ticks.is_empty() else 0, str(lost), deal_ms, Time.get_ticks_msec() - t0])
	print("probe_train: %d runs, %d failures" % [_runs, _bad])
	quit(1 if _bad > 0 else 0)

func _fail(what: String) -> void:
	_bad += 1
	if _bad < 20:
		print("FAIL ", what)

func _check_deal(st, tag: String) -> void:
	var by := PackedInt32Array()
	by.resize(st.colours.size())
	for e in st.colour.size():
		by[st.colour[e]] += st.load_[e]
		if st.load_[e] <= 0:
			_fail("%s: an engine with no load" % tag)
	for c in st.colours.size():
		if by[c] != st.left_by[c]:
			_fail("%s: colour %d has %d blocks and loads of %d" % [tag, c, st.left_by[c], by[c]])
	var stood := 0
	for column: PackedInt32Array in st.sheds:
		stood += column.size()
	if stood != st.colour.size():
		_fail("%s: %d engines, %d in the shed" % [tag, st.colour.size(), stood])

func _check(st, tag: String) -> bool:
	var by := PackedInt32Array()
	by.resize(st.colours.size())
	for e in st.colour.size():
		if st.where[e] != State.GONE:
			by[st.colour[e]] += st.room[e]
		elif st.room[e] != 0:
			_fail("%s: an engine gone with room" % tag)
			return false
	for c in st.colours.size():
		if by[c] != st.left_by[c]:
			_fail("%s: tick %d colour %d has %d blocks and room for %d" % [tag, st.ticks, c, st.left_by[c], by[c]])
			return false
	if st.loop.size() + st.gate.size() > State.ON_LOOP or st.parked() > State.SIDING:
		_fail("%s: over its places" % tag)
		return false
	return true

func _settle(st, tag: String) -> bool:
	while not st.idle() and not st.jammed and st.ticks < GUARD:
		st.tick()
		if not _check(st, tag):
			return false
	return true

func _play(st, how: int, rng: RandomNumberGenerator, tag: String) -> bool:
	_runs += 1
	match how:
		0:
			var most := 0
			for e in st.line:
				if st.send(e) != State.OK:
					_fail("%s: the line's engine %d was refused (%d)" % [tag, e, st.judge(e)])
					return false
				if not _settle(st, tag):
					return false
				most = maxi(most, st.parked())
			if most > State.REF_PARKED[st.band]:
				_fail("%s: the line held %d in the siding" % [tag, most])
		1:
			while not st.is_solved() and not st.jammed and st.ticks < GUARD:
				var e: int = st.hint()
				if e < 0 or st.send(e) != State.OK:
					_fail("%s: the hand had no engine to send (%d)" % [tag, e])
					return false
				if not _settle(st, tag):
					return false
		2:
			while not st.is_solved() and not st.jammed and st.ticks < GUARD:
				var e: int = st.hint()
				if e >= 0 and st.judge(e) == State.OK and rng.randf() < 0.5:
					st.send(e)
				st.tick()
				if not _check(st, tag):
					return false
		3:
			while not st.is_solved() and not st.jammed and st.ticks < GUARD:
				if rng.randf() < 0.4:
					var ready: PackedInt32Array = st.ready_engines()
					# as a hand in a hurry does: half the time a new one out of
					# the shed
					if rng.randf() < 0.5:
						ready = PackedInt32Array()
						for column: PackedInt32Array in st.sheds:
							if not column.is_empty():
								ready.append(column[0])
					if not ready.is_empty():
						st.send(ready[rng.randi_range(0, ready.size() - 1)])
				st.tick()
				if not _check(st, tag):
					return false
	return st.is_solved()
