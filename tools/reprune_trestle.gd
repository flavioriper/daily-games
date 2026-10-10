extends SceneTree

## Prunes every banked proof again under the sim as it stands and prices it
## again, for a change to the materials that leaves the levels' shapes alone:
##
##     godot --headless --script res://tools/reprune_trestle.gd -- <band>
##
## Prints the band's levels as JSON lines, like tools/mine_trestle.gd; a
## level whose proof no longer holds, or whose bare deck now crosses, is left
## out. Then `python3 tools/merge_trestle.py`.

const Sim = preload("res://puzzles/trestle_sim.gd")
const Gen = preload("res://puzzles/trestle_gen.gd")
const Mine = preload("res://tools/mine_trestle.gd")

func _initialize() -> void:
	var band := int(OS.get_cmdline_user_args()[0])
	var bands: Array = JSON.parse_string(FileAccess.get_file_as_string(Gen.BANK)).bands
	for lv: Dictionary in bands[band]:
		var proof: Array = []
		for r in lv.proof:
			proof.append({"a": Vector2i(int(r[0]), int(r[1])), "b": Vector2i(int(r[2]), int(r[3])), "m": int(r[4])})
		if Gen.proves(lv, Gen.plain_deck(lv)) or not Gen.proves(lv, proof, Mine.MARGIN):
			printerr("band %d: dropped w %d (was %d)" % [band, int(lv.w), int(lv.proof_cost)])
			continue
		var best: Array = Mine.prune(lv, proof, false)
		var cost := Sim.cost_of(best)
		printerr("band %d: w %d cost %d -> %d, members %d -> %d" % [band, int(lv.w), int(lv.proof_cost), cost, proof.size(), best.size()])
		lv.budget = int(ceil(cost * float(Gen.BANDS[band].slack) / 100.0)) * 100
		lv.proof_cost = cost
		var rows: Array = []
		for d in best:
			rows.append([d.a.x, d.a.y, d.b.x, d.b.y, d.m])
		lv.proof = rows
		print(JSON.stringify(lv))
	quit()
