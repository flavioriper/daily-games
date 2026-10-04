extends SceneTree

## Plays Peapod's sim headless with a bot and prints how far each run went.
## Run after touching arcade/peapod_sim.gd.
##   godot --headless --script tests/_probe_peapod.gd -- [seed] [skill 0-2] [games]
## Skill 0 wanders under whatever is lowest, slowly, and lets gifts fall;
## 1 aims at the lowest thing and goes for a gift it can reach; 2 does both
## at a quick finger's pace.

const Sim = preload("res://arcade/peapod_sim.gd")

func _target(sim: RefCounted, skill: int) -> float:
	# a gift on its way down, if there is time to get under it
	if skill >= 1:
		for tk: Dictionary in sim.tokens:
			if float(tk.y) > 150.0:
				return float(tk.x)
	if sim.wave_kind == Sim.Wave.WALL:
		for r in sim.rows.size():
			var best := -1
			var low := 1 << 30
			for c in Sim.COLS:
				var cell = sim.rows[r][c]
				if cell == null:
					continue
				# gifts first, then the weakest of the lowest row
				var w: int = int(cell.hp) - (1000 if int(cell.kind) >= Sim.Kind.PEA and skill >= 1 else 0)
				if w < low:
					low = w
					best = c
			if best >= 0:
				return (best + 0.5) * Sim.CELL_W
		return sim.x
	if sim.segs.is_empty():
		return sim.x
	# the plate furthest along that is on the field
	for sg: Dictionary in sim.segs:
		if float(sg.s) > 20.0:
			return Sim.path_at(float(sg.s) + (10.0 if skill >= 1 else 0.0)).x
	return sim.x

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var seed_v := int(args[0]) if args.size() > 0 else 7
	var skill := int(args[1]) if args.size() > 1 else 1
	var games := int(args[2]) if args.size() > 2 else 5
	var speed: float = [110.0, 240.0, 520.0][clampi(skill, 0, 2)]
	var waves: Array = []
	for g in games:
		var sim = Sim.new(seed_v + g)
		var tally := {}
		var hand: float = sim.x
		var guard := 0
		var log := ""
		while not sim.is_over() and guard < 60 * 60 * 30:
			guard += 1
			hand = move_toward(hand, _target(sim, skill), speed * Sim.DT)
			sim.target_x = hand
			sim.step()
			for ev: Dictionary in sim.events:
				tally[ev.type] = int(tally.get(ev.type, 0)) + 1
				if ev.type == "wave":
					log += " %d@%ds(p%d r%d w%d)" % [ev.wave, int(sim.t), sim.peas, sim.rate_lv, sim.power]
			sim.events.clear()
		waves.append(sim.wave)
		print("seed %d skill %d: wave %d  score %d  %.0f s  peas %d rate %d power %d  kills %d  caught %d/%d  streak %d" % [
			seed_v + g, skill, sim.wave, sim.score, sim.t, sim.peas, sim.rate_lv, sim.power, sim.kills, sim.caught,
			int(tally.get("token", 0)), sim.best_streak])
		if g == 0:
			print(log)
			print(tally)
	waves.sort()
	print("waves: ", waves)
	quit()
