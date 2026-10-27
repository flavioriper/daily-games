extends SceneTree
## Throwaway: how Horse Pen plays, 60 meadows a band out of the bank. Three
## players, against the stars and the best pen known:
##   plugger  -- lays each bale where it leaves the fewest ways out (the
##               biggest reach on a tie) and stops when the pen shuts;
##   casual   -- Gen.search with a short look (8 pens grown, 60 steps);
##   keen     -- Gen.search with the phone's own fallback look (40, 400).
## Counted: the pen closed at all, the share of the best, and how many reach
## the old target (what Submit asked until 2026-10-27) and the stars a pen
## earns now (State.need: one closed, two at 70%, three at 90%, and the best).
##
##     godot --headless --script res://tests/_probe_hp_fun.gd
const Gen = preload("res://puzzles/horse_gen.gd")
const State = preload("res://puzzles/horse_state.gd")

const DAYS := 60

func _initialize() -> void:
	for band in Gen.BANDS.size():
		var pool: Array = State.pool(band)
		var rows := {"plugger": _blank(), "casual": _blank(), "keen": _blank()}
		var gaps0 := 0
		for s in mini(DAYS, pool.size()):
			var m := Gen.unpack(pool[(s * 7) % pool.size()])
			var target := Gen.target_for(int(m.best), band)
			var st = State.new()
			st.band = band
			st.adopt(m)
			var rungs := [st.need(1), st.need(2), st.need(3), int(m.best)]
			var none := PackedByteArray()
			none.resize(int(m.w) * int(m.h))
			gaps0 += (Gen.reach(m, none).gaps as PackedInt32Array).size()
			_tally(rows.plugger, _plug(m), m, target, rungs)
			var rng := RandomNumberGenerator.new()
			rng.seed = 99 + s
			_tally(rows.casual, _searched(rng, m, 8, 60), m, target, rungs)
			_tally(rows.keen, _searched(rng, m, 40, 400), m, target, rungs)
		var n := mini(DAYS, pool.size())
		print("band %d: %d meadows, %.1f ways out on a bare field, target %d%% of best" % [
			band, n, float(gaps0) / n, int(Gen.BANDS[band].share * 100)])
		for k: String in rows:
			var r: Dictionary = rows[k]
			print("  %-8s closed %d/%d  mean %.0f%% of best  >=old target %d  stars 1/2/3/best %s" % [
				k, r.closed, n, 100.0 * r.share / maxf(1, r.closed), r.target, str(r.ladder)])
	quit()

func _blank() -> Dictionary:
	return {"closed": 0, "share": 0.0, "target": 0, "ladder": [0, 0, 0, 0]}

func _tally(row: Dictionary, score: int, m: Dictionary, target: int, rungs: Array) -> void:
	if score <= 0:
		return
	row.closed += 1
	var f := float(score) / float(m.best)
	row.share += f
	if score >= target:
		row.target += 1
	for i in rungs.size():
		if score >= int(rungs[i]):
			row.ladder[i] += 1

## The plugger's pen: its score, 0 when it never shut.
func _plug(m: Dictionary) -> int:
	var walls := PackedByteArray()
	walls.resize(int(m.w) * int(m.h))
	for _b in int(m.budget):
		var r := Gen.reach(m, walls)
		if (r.gaps as PackedInt32Array).is_empty():
			break
		var pick := -1
		var key := Vector2i(1 << 30, 0)
		for i: int in r.order:
			if m.bare[i] != 1 or i == int(m.horse):
				continue
			walls[i] = 1
			var t := Gen.reach(m, walls)
			walls[i] = 0
			var k := Vector2i((t.gaps as PackedInt32Array).size(), -(t.order as PackedInt32Array).size())
			if k.x < key.x or (k.x == key.x and k.y < key.y):
				key = k
				pick = i
		if pick < 0:
			break
		walls[pick] = 1
	var end := Gen.reach(m, walls)
	return int(end.score) if (end.gaps as PackedInt32Array).is_empty() else 0

func _searched(rng: RandomNumberGenerator, m: Dictionary, grows: int, steps: int) -> int:
	var found := Gen.search(rng, m, int(m.budget), grows, steps)
	return int(found.get("score", 0)) if not found.is_empty() else 0
