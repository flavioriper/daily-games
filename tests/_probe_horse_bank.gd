extends SceneTree

## Re-proves Horse Pen's bank (content/horse.json) against the rules as they
## stand: every meadow's answer closes the pen within the stock, on bare
## grass only, and scores the `best` the bank says; the horse starts loose;
## and the band's target is under it. Headless:
##
##     godot --headless --script res://tests/_probe_horse_bank.gd
##
## Re-mine (tools/mine_horse.gd) when a rule in puzzles/horse_gen.gd changes.

const Gen = preload("res://puzzles/horse_gen.gd")
const State = preload("res://puzzles/horse_state.gd")

func _initialize() -> void:
	var bad := 0
	for band in Gen.BANDS.size():
		var pool: Array = State.pool(band)
		var spare := 0
		var lo := 1 << 30
		var hi := 0
		for d: Dictionary in pool:
			var m := Gen.unpack(d)
			var none := PackedByteArray()
			none.resize(int(m.w) * int(m.h))
			var walls := none.duplicate()
			var ok: bool = not (Gen.reach(m, none).gaps as PackedInt32Array).is_empty()
			for i: int in m.sol:
				ok = ok and m.bare[i] == 1
				walls[i] = 1
			var r := Gen.reach(m, walls)
			ok = ok and (r.gaps as PackedInt32Array).is_empty() and int(r.score) == int(m.best)
			ok = ok and (m.sol as Array).size() <= int(m.budget)
			ok = ok and int(m.w) == int(Gen.BANDS[band].w) and int(m.h) == int(Gen.BANDS[band].h)
			if not ok:
				bad += 1
				print("band %d: a meadow that does not prove (horse %d)" % [band, m.horse])
			spare += int(m.budget) - (m.sol as Array).size()
			lo = mini(lo, int(m.best))
			hi = maxi(hi, int(m.best))
		print("band %d: %d meadows, best %d..%d, %d with a bale to spare" % [band, pool.size(), lo, hi, spare])
	print("bank ok" if bad == 0 else "bank BAD: %d" % bad)
	quit()
