extends SceneTree
## How wide a pot is: from random tables, every straight pot AI.pots() lists,
## struck at its pace at aim offsets; prints the share that drop at each offset
## and of those lists' pots how many drop dead on, by the cut.
const Sim = preload("res://versus/snooker_sim.gd")
const AI = preload("res://versus/snooker_ai.gd")
func _initialize() -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = 3
	var offs := [0.0, 0.002, 0.004, 0.008, 0.012, 0.02]
	var hit := {}; var n := 0
	for o in offs: hit[o] = 0
	var state := {"phase": "red"}
	for t in 60:
		var sim = Sim.new(); sim.log_events = false
		for id in range(1, 7):
			sim.pos[id] = Vector2(rng.randf_range(0.1, Sim.W - 0.1), rng.randf_range(0.15, Sim.L - 0.15))
		for id in range(7, 16): sim.on[id] = false
		sim.pos[0] = Vector2(rng.randf_range(0.2, Sim.W - 0.2), rng.randf_range(0.3, Sim.L - 0.3))
		for p in AI.pots(sim, state).slice(0, 4):
			n += 1
			for o in offs:
				var s = sim.copy()
				var d: Vector2 = (p.dir as Vector2).rotated(o * (1 if n % 2 else -1))
				s.strike(d, float(p.speed) * 1.1, Vector2(0, 0.1))
				s.settle(20.0, Sim.DT * 2.0)
				if s.potted.has(int(p.id)): hit[o] += 1
	print("pots=", n, " ", hit)
	quit()
