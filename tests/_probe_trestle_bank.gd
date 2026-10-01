extends SceneTree

## Re-proves every level in content/trestle.json against the sim as it
## stands, because a change to the physics (or the cart's start) quietly
## invalidates what the miner proved:
##
##     godot --headless --script res://tests/_probe_trestle_bank.gd -- [write]
##
## A level passes when its proof gets the cart over with every member under
## 0.92 of its limit and a bare road deck does not. With `write`, the levels
## that fail are dropped from the file.

const Sim = preload("res://puzzles/trestle_sim.gd")
const Gen = preload("res://puzzles/trestle_gen.gd")

const MARGIN := 0.92

func _initialize() -> void:
	var write := OS.get_cmdline_user_args().has("write")
	var doc = JSON.parse_string(FileAccess.get_file_as_string(Gen.BANK))
	var bands: Array = doc.bands
	var bad := 0
	for b in bands.size():
		var keep: Array = []
		var worst := 0.0
		for lv: Dictionary in bands[b]:
			var proof: Array = []
			for r in lv.proof:
				proof.append({"a": Vector2i(int(r[0]), int(r[1])), "b": Vector2i(int(r[2]), int(r[3])), "m": int(r[4])})
			var sim := Sim.new()
			sim.setup(lv, proof)
			var over := sim.run()
			var deck := Gen.proves(lv, Gen.plain_deck(lv))
			var ok := over and (not sim.tea or sim.tea_peak <= 0.95) and sim.worst() <= MARGIN and not deck and Sim.cost_of(proof) <= int(lv.budget)
			if ok:
				keep.append(lv)
				worst = maxf(worst, sim.worst())
			else:
				bad += 1
				print("band %d: w %d dy %d FAILS (over %s worst %.2f tea %.2f deck %s)" % [b, lv.w, lv.dy, over, sim.worst(), sim.tea_peak, deck])
		print("band %d: %d of %d hold, worst stress %.2f" % [b, keep.size(), bands[b].size(), worst])
		bands[b] = keep
	if write and bad > 0:
		var f := FileAccess.open(Gen.BANK.replace("res://", "res://"), FileAccess.WRITE)
		f.store_string(JSON.stringify({"bands": bands}) + "\n")
		print("wrote %s without the %d that fail" % [Gen.BANK, bad])
	quit()
