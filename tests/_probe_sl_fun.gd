extends SceneTree

## What Super Slider tells a player, headless, DAYS trays a band: how often a
## legal first move brings the big block nearer, leaves it where it stood or
## takes it farther (by the solver's distance), how many moves of a shortest
## way move the big block itself, and a player tapping any legal move at
## random, never undoing, against three times the shortest (Insane counts the
## walks that strand the big block). Then the stars a way would earn
## (State.stars_for), the shortest way and a way with every fifth move wasted.
##     godot --headless --script tests/_probe_sl_fun.gd -- [days=60]
const Gen = preload("res://puzzles/slider_gen.gd")
const State = preload("res://puzzles/slider_state.gd")

var _days := 60

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("days="):
			_days = int(a.substr(5))

func _process(_d: float) -> bool:
	for band in 4:
		var near := 0
		var same := 0
		var far := 0
		var dead := 0
		var red := 0
		var line := 0
		var solved := 0
		var stranded := 0
		var walked := 0
		var pars := 0
		for day in _days:
			var rng := RandomNumberGenerator.new()
			rng.seed = 7919 * band + day
			var st := State.new()
			st.build(rng, band, day)
			st.finish()
			pars += st.par
			var d0 := st.dist_of(st.key)
			for p in st.blocks.size():
				var a := st.kind(p)
				var base := st.key - Gen.contrib(a, st.at(p))
				for to in st.reach(p):
					if to == st.at(p):
						continue
					var d1 := st.dist_of(base + Gen.contrib(a, to))
					if d1 == -1:
						dead += 1
					elif d1 < d0:
						near += 1
					elif d1 == d0:
						same += 1
					else:
						far += 1
			# the shortest way, counting the big block's own moves
			while not st.is_solved():
				var m := st.hint_move()
				if m.is_empty():
					break
				if st.kind(int(m.p)) == Gen.B0:
					red += 1
				line += 1
				st.play(int(m.p), int(m.to))
			# the random player
			st.reset_board()
			var r := RandomNumberGenerator.new()
			r.seed = 31 * day + band
			var n := 0
			while not st.is_solved() and n < 3 * st.par:
				var opts: Array = []
				for p in st.blocks.size():
					for to in st.reach(p):
						if to != st.at(p):
							opts.append([p, to])
				if opts.is_empty():
					break
				var o: Array = opts[r.randi_range(0, opts.size() - 1)]
				st.play(int(o[0]), int(o[1]))
				n += 1
				if st.dist_of(st.key) == -1:
					stranded += 1
					break
			walked += n
			if st.is_solved():
				solved += 1
			st.abandon()
		var all := float(near + same + far + dead)
		print("band %d: par mean %.1f | first moves nearer %d%% same %d%% farther %d%% strand %d%% | big block %d of %d moves on the shortest (%d%%) | random: %d/%d solved in 3x par, %d stranded" % [
			band, float(pars) / _days, roundi(100.0 * near / all), roundi(100.0 * same / all),
			roundi(100.0 * far / all), roundi(100.0 * dead / all), red, line, roundi(100.0 * red / maxi(1, line)),
			solved, _days, stranded])
	if State.new().has_method("stars_for"):
		for par in [10, 27, 45, 72, 98]:
			var st := State.new()
			st.par = par
			print("par %d: shortest %d star(s), +%d wasted %d, +%d wasted %d" % [par,
				st.call("stars_for", par), par / 5, st.call("stars_for", par + par / 5), par / 2, st.call("stars_for", par + par / 2)])
	return true
