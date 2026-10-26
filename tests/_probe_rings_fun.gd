extends SceneTree

## How hard a Rings deal is, band by band (the 2026-10-26 made-fun pass).
## Headless:
##
##     godot --headless --path . --script res://tests/_probe_rings_fun.gd -- [n=40] [try=c,cap,spare ...]
##
## For each band (or each `try=` shape, dealt the same way): the deal's time
## mean and worst, the solver's nodes and line, the share of first moves that
## leave the pegs unsortable (`Gen.verdict`, "?" past the budget), and how
## often a player who taps any legal move at random, never undoing, sorts it
## (the lower, the more a deal asks to be thought about).

const Gen = preload("res://puzzles/rings_gen.gd")

var _n := 40

func _initialize() -> void:
	var tries: Array = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("n="):
			_n = int(a.substr(2))
		elif a.begins_with("try="):
			var p := a.substr(4).split(",")
			tries.append({"colours": int(p[0]), "cap": int(p[1]), "spare": int(p[2])})
	if tries.is_empty():
		for b in Gen.BANDS.size():
			_band(str(b), b, Gen.BANDS[b])
	else:
		for t: Dictionary in tries:
			_band("%d,%d,%d" % [t["colours"], t["cap"], t["spare"]], -1, t)
	quit()

func _band(label: String, band: int, shape: Dictionary) -> void:
	var cap: int = shape["cap"]
	var ms_sum := 0.0
	var ms_max := 0.0
	var lines: Array[int] = []
	var nodes_max := 0
	var dead := 0
	var firsts := 0
	var unknown := 0
	var wins := 0
	var plays := 0
	var tangled := 0
	for i in _n:
		var rng := RandomNumberGenerator.new()
		rng.seed = 9000 + i * 7919
		var t0 := Time.get_ticks_usec()
		var pegs: Array
		if band >= 0:
			pegs = Gen.deal(rng, band)
		else:
			pegs = _deal(rng, shape)
		var ms := (Time.get_ticks_usec() - t0) / 1000.0
		ms_sum += ms
		ms_max = maxf(ms_max, ms)
		for peg: Array in pegs:
			for k in peg.size() - 1:
				if peg[k] == peg[k + 1]:
					tangled += 1
		var out: Dictionary = Gen._search(pegs, Gen.NODE_BUDGET, cap)
		lines.append((out["path"] as Array).size())
		nodes_max = maxi(nodes_max, int(out["nodes"]))
		for m: Vector2i in Gen.moves_from(pegs, cap):
			var work := _copy(pegs)
			Gen.apply(work, m.x, m.y, cap)
			var v := Gen.verdict(work, Gen.NODE_BUDGET, cap)
			firsts += 1
			if v == 0:
				dead += 1
			elif v < 0:
				unknown += 1
		for r in 10:
			plays += 1
			if _random_play(pegs, cap, rng):
				wins += 1
	lines.sort()
	print("%s  deal %.1f ms mean %.1f worst | solver nodes worst %d, line %d-%d (median %d) | first moves dead %d/%d (%d ?) | random player sorts %d/%d | rings on own colour %d" % [
		label, ms_sum / _n, ms_max, nodes_max, lines[0], lines[-1], lines[lines.size() / 2],
		dead, firsts, unknown, wins, plays, tangled])

func _deal(rng: RandomNumberGenerator, shape: Dictionary) -> Array:
	var cap: int = shape["cap"]
	var last: Array = []
	for attempt in Gen.ATTEMPTS:
		var pegs := Gen._deal_once(rng, int(shape["colours"]), int(shape["spare"]), cap)
		last = pegs
		if not Gen.solve(pegs, Gen.NODE_BUDGET, cap).is_empty():
			return pegs
	return last

func _copy(pegs: Array) -> Array:
	var out: Array = []
	for s in pegs:
		out.append((s as Array).duplicate())
	return out

## Any legal move at random (the full set, not the solver's pruned one), never
## straight back, until sorted, stuck, or 600 moves.
func _random_play(pegs: Array, cap: int, rng: RandomNumberGenerator) -> bool:
	var work := _copy(pegs)
	var back := Vector2i(-1, -1)
	for step in 600:
		if Gen.solved(work, cap):
			return true
		var moves: Array[Vector2i] = []
		for i in work.size():
			if (work[i] as Array).is_empty() or Gen.locked(work[i], cap):
				continue
			for j in work.size():
				if i != j and Vector2i(i, j) != back and Gen.take(work[i], work[j], cap) > 0:
					moves.append(Vector2i(i, j))
		if moves.is_empty():
			return false
		var m: Vector2i = moves[rng.randi_range(0, moves.size() - 1)]
		Gen.apply(work, m.x, m.y, cap)
		back = Vector2i(m.y, m.x)
	return false
