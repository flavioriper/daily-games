extends SceneTree

## How hard the Tea Party is, headless:
##
##     godot --headless --script res://tests/_probe_trestle_tea.gd
##
## For every Insane level in content/trestle.json: whether its proof keeps
## the tea in (and how far it leans), and how many of the obvious full
## trusses (one or two rows under the road, one over it, both, each
## diagonal pattern) both fit the budget and get the tea over. A level where
## an obvious truss does is too easy; the proof is the only way we know.
## Spec: docs/superpowers/specs/2026-10-01-trestle-polish-design.md, section 2.

const Sim = preload("res://puzzles/trestle_sim.gd")
const Gen = preload("res://puzzles/trestle_gen.gd")

func _initialize() -> void:
	var bands: Array = JSON.parse_string(FileAccess.get_file_as_string(Gen.BANK)).bands
	var easy := 0
	var bad := 0
	var strong := 0
	var n := 0
	for lv: Dictionary in bands[3]:
		n += 1
		var proof: Array = []
		for r in lv.proof:
			proof.append({"a": Vector2i(int(r[0]), int(r[1])), "b": Vector2i(int(r[2]), int(r[3])), "m": int(r[4])})
		var sim := Sim.new()
		sim.setup(lv, proof)
		var over := sim.run()
		if not over or not lv.get("tea", false):
			bad += 1
		var fit := 0
		var held := 0
		for shape in [[1, 0], [2, 0], [0, 1], [1, 1], [2, 1], [1, 2]]:
			for diag in 3:
				var cand := Gen.full(lv, shape[0], shape[1], diag)
				var s2 := Sim.new()
				s2.setup(lv, cand)
				var ok := s2.run()
				var spilt := s2.spilled
				if not ok and spilt and s2.broken.is_empty():
					held += 1
				if ok and Sim.cost_of(cand) <= int(lv.budget):
					fit += 1
		if fit > 0:
			easy += 1
		if held > 0:
			strong += 1
		print("w %d budget %d proof %d: tea %s lean %.2f | obvious trusses in budget that cross %d, strong but spilling %d" % [
			lv.w, lv.budget, lv.proof_cost, over, sim.tea_peak, fit, held])
	print("insane: %d levels, %d proofs fail, %d with an obvious truss in budget, %d where a strong truss spills" % [n, bad, easy, strong])
	quit()
