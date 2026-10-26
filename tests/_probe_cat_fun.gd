extends SceneTree

## Caterpillar's days as a player meets them: per band, the leaves and fences
## dealt, the share of the answer's steps where a careful player (one who sees
## a square the step would strand) has more than one way on, and the wasted
## steps of a careful player who guesses at random and backs off a dead end
## (squares crawled that the answer does not keep), over 8 guessers a garden.
##     godot --headless --script tests/_probe_cat_fun.gd -- [days=30]
const State := preload("res://puzzles/caterpillar_state.gd")

func _initialize() -> void:
	var days := 30
	for a in OS.get_cmdline_user_args():
		if a.begins_with("days="):
			days = int(a.substr(5))
	for band in 4:
		var ks := 0.0
		var hs := 0.0
		var choice := 0.0
		var waste := 0.0
		var worst := 0
		var steps := 0.0
		var gen_worst := 0.0
		for d in days:
			var st = State.new()
			var rng := RandomNumberGenerator.new()
			rng.seed = 1000 + d * 31 + band
			var t0 := Time.get_ticks_usec()
			st.build(rng, band, d)
			var ms := (Time.get_ticks_usec() - t0) / 1000.0
			gen_worst = maxf(gen_worst, ms)
			ks += st.leaves.size()
			hs += st.hedges.size()
			steps += st.size()
			# choice points along the answer
			st.start(st.path[0])
			var ch := 0
			for i in range(1, st.size()):
				if _ways(st).size() > 1:
					ch += 1
				st.grow(st.path[i])
			choice += float(ch) / (st.size() - 1)
			var w := 0
			for g in 8:
				var r := RandomNumberGenerator.new()
				r.seed = g * 7 + d
				st.body = PackedInt32Array([st.path[0]])
				var n := [0]
				_dfs(st, r, n)
				w += n[0]
			w /= 8
			waste += w
			worst = maxi(worst, w)
		print("band %d: cells %d leaves %.1f fences %.1f choice %.0f%% wasted %.1f (worst %d) gen worst %.0f ms" % [band, steps / days, ks / days, hs / days, 100.0 * choice / days, waste / days, worst, gen_worst])
	quit()

func _ways(st) -> Array:
	var out := []
	var h: int = st.head()
	for nb in [h - 1, h + 1, h - st.cols, h + st.cols]:
		if nb < 0 or nb >= st.size() or not st.adjacent(h, nb) or st.body.has(nb):
			continue
		if st.why(nb) != "":
			continue
		if not st.stranded(nb).is_empty() or st._starved(nb):
			continue
		out.append(nb)
	return out

func _dfs(st, r: RandomNumberGenerator, n: Array) -> bool:
	if st.is_solved():
		return true
	if n[0] > 20000:
		return true
	var ways := _ways(st)
	for i in range(ways.size() - 1, 0, -1):
		var j := r.randi_range(0, i)
		var t = ways[i]; ways[i] = ways[j]; ways[j] = t
	for nb in ways:
		st.body.append(nb)
		if _dfs(st, r, n):
			return true
		st.body.resize(st.body.size() - 1)
		n[0] += 1
	return false
