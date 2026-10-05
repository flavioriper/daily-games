extends SceneTree

## Re-proves every hole in content/minigolf.json against the sim as it
## stands: its proof must still put the ball down, in no more putts than its
## par. Run it after touching puzzles/minigolf_sim.gd; a hole that fails
## wants the bank mined again (tools/mine_minigolf.gd).
##
##     godot --headless --script res://tests/_probe_minigolf_bank.gd

const Sim = preload("res://puzzles/minigolf_sim.gd")
const Gen = preload("res://puzzles/minigolf_gen.gd")

func _initialize() -> void:
	var bands: Array = Gen.bank()
	var bad := 0
	for b in bands.size():
		var pool: Array = bands[b]
		var pars := {}
		var missed := 0
		var long := 0
		for hole: Dictionary in pool:
			pars[int(hole.par)] = int(pars.get(int(hole.par), 0)) + 1
			if not Gen.proves(hole):
				missed += 1
			if (hole.proof as Array).size() > int(hole.par):
				long += 1
		bad += missed + long
		var want: int = Gen.holes_for(b)
		print("band %d: %d holes (a course takes %d), pars %s, %d proofs miss, %d proofs over par" % [
			b, pool.size(), want, pars, missed, long])
		if pool.size() < want:
			bad += 1
			print("  too few holes for a course")
	print("bank ok" if bad == 0 else "bank BAD: %d" % bad)
	quit(1 if bad > 0 else 0)
