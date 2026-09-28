extends SceneTree

## How the day's proofs fare with a convoy: for each band, how many proofs
## still get every cart over.
##     godot --headless --script res://tests/_probe_trestle_convoy.gd -- [carts] [gap]

const Sim = preload("res://puzzles/trestle_sim.gd")
const Gen = preload("res://puzzles/trestle_gen.gd")

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var carts := int(args[0]) if args.size() > 0 else 3
	var doc = JSON.parse_string(FileAccess.get_file_as_string(Gen.BANK))
	for b in doc.bands.size():
		var ok := 0
		var worst := 0.0
		for lv: Dictionary in doc.bands[b]:
			var proof: Array = []
			for r in lv.proof:
				proof.append({"a": Vector2i(int(r[0]), int(r[1])), "b": Vector2i(int(r[2]), int(r[3])), "m": int(r[4])})
			var sim := Sim.new()
			sim.setup(lv, proof, carts)
			while not sim.done():
				sim.step()
			if sim.crossed():
				ok += 1
			worst = maxf(worst, sim.worst())
		print("band %d: %d carts, %d of %d proofs carry the convoy (worst %.2f)" % [b, carts, ok, doc.bands[b].size(), worst])
	quit()
