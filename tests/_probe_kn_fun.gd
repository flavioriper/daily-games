extends SceneTree

## Knight, measured (2026-10-29 made-fun pass). A casual player: never hops
## into a square a rose knight reaches (the rose rings say so), else picks a
## safe hop, preferring one nearer the king half the time. Reports per band
## over `days` deals: how many days the player walks into a lost position
## (no way left to the king), after how many hops, how many hops a won day
## took against the shortest line, and -- the preview's guard -- whether
## State.peek(to) agrees with State.play(to) on every legal square met.
##
##     godot --headless --path . --script res://tests/_probe_kn_fun.gd

const State = preload("res://puzzles/knight_state.gd")
const Gen = preload("res://puzzles/knight_gen.gd")

func _initialize() -> void:
	for band in 4:
		_band(band)
	quit()

func _band(band: int) -> void:
	var rng := RandomNumberGenerator.new()
	var me := RandomNumberGenerator.new()
	me.seed = 7
	var days := 30
	var lost_days := 0
	var lost_at := []
	var won := 0
	var over := []
	var disagree := 0
	var peeks := 0
	for day in days:
		rng.seed = 5000 + day
		var st = State.new()
		st.build(rng, band, day)
		var d: Array = Gen.dist(st.w)
		var hops := 0
		var was_lost := false
		for _i in 60:
			if st.won:
				break
			var safe: Array = []
			for m in st.legal():
				var p: Dictionary = st.peek(m)
				var copy = State.new()
				copy.g = st.g
				copy.w = st.w
				copy.king = st.king
				copy.difficulty = st.difficulty
				copy.you = st.you
				copy.foes = st.foes.duplicate()
				copy.mask = st.mask
				var r: Dictionary = copy.play(m)
				peeks += 1
				if r.is_empty() or int(r.caught) != int(p.caught) or bool(r.won) != bool(p.won) \
						or (int(p.caught) < 0 and (copy.you != int(p.you) or copy.foes != p.foes)):
					disagree += 1
				if int(p.caught) < 0:
					safe.append(m)
			if safe.is_empty():
				break
			var pick: int = safe[me.randi() % safe.size()]
			if me.randf() < 0.5:
				for m in safe:
					if int(d[m][st.king]) < int(d[pick][st.king]):
						pick = m
			st.play(pick)
			hops += 1
			if not st.won and not st.brambles() and not was_lost and st.lost():
				was_lost = true
				lost_days += 1
				lost_at.append(hops)
				break
		if st.won:
			won += 1
			over.append(hops - st.opt())
	lost_at.sort()
	over.sort()
	print("band %d: lost %d/%d (hop p50 %s), won %d, over par p50 %s p90 %s; peek vs play disagree %d of %d" % [
		band, lost_days, days, str(lost_at[lost_at.size() / 2]) if not lost_at.is_empty() else "-",
		won, str(over[over.size() / 2]) if not over.is_empty() else "-",
		str(over[over.size() * 9 / 10]) if not over.is_empty() else "-", disagree, peeks])
