extends SceneTree

## Plays Stackwood's sim headless with a greedy bot and prints the score, the
## biggest block, the merges, the chains and the tools it could afford. Run
## after touching arcade/stackwood_sim.gd.
##   godot --headless --script tests/_probe_stackwood.gd -- [seed] [skill 0-2] [tools 0/1]
## Skill 0 drops at random, 1 takes the column with the most touching
## matches, 2 also keeps stacks low and a big block off the small ones.

const Sim = preload("res://arcade/stackwood_sim.gd")

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var seed_v := int(args[0]) if args.size() > 0 else 7
	var skill := int(args[1]) if args.size() > 1 else 2
	var use_tools := (int(args[2]) if args.size() > 2 else 1) == 1
	var sim = Sim.new(seed_v)
	var pick := RandomNumberGenerator.new()
	pick.seed = seed_v + 1
	var tally := {}
	var guard := 0
	var decided := -1
	while not sim.is_over() and guard < 60 * 60 * 60:
		guard += 1
		if sim.phase == Sim.Phase.FALL and not sim.piece.is_empty() and not sim.piece.dropping and int(sim.piece.id) != decided:
			decided = int(sim.piece.id)
			if use_tools:
				var tallest := 0
				for c in Sim.COLS:
					tallest = maxi(tallest, sim.height(c))
				if tallest >= Sim.ROWS - 1 and sim.can_use(Sim.Tool.ZAP):
					sim.use(Sim.Tool.ZAP)
				elif tallest >= Sim.ROWS and sim.can_use(Sim.Tool.BOMB):
					sim.use(Sim.Tool.BOMB)
				elif tallest >= Sim.ROWS - 2 and sim.can_use(Sim.Tool.WILD):
					sim.use(Sim.Tool.WILD)
			var best_c := pick.randi_range(0, Sim.COLS - 1)
			if skill > 0 and not sim.piece.is_empty():
				var best_s := -INF
				for c in Sim.COLS:
					var s := _rate(sim, c, skill) + pick.randf() * 0.1
					if s > best_s:
						best_s = s
						best_c = c
			sim.aim(best_c)
			sim.drop()
		sim.step()
		for ev: Dictionary in sim.events:
			tally[ev.type] = int(tally.get(ev.type, 0)) + 1
		sim.events.clear()
	print("seed %d skill %d tools %s: score %d, biggest %d, drops %d, merges %d, best chain %d, acorns left %d, tools used %d, %.1f min" % [
		seed_v, skill, use_tools, sim.score, sim.max_v, sim.drops, sim.merges, sim.best_chain, sim.acorns, sim.tools_used, guard * Sim.DT / 60.0])
	print(tally)
	quit()

static func _rate(sim, c: int, skill: int) -> float:
	var h: int = sim.height(c)
	if h > Sim.ROWS:
		return -1000.0
	var v: int = sim.piece.v
	if int(sim.piece.kind) != Sim.Piece.BLOCK:
		# a rainbow or bomb goes where the most blocks are
		return float(h) + (5.0 if h > 0 else 0.0)
	var s := 0.0
	var below: Dictionary = sim._at(Vector2i(c, h - 1))
	for n in [Vector2i(c - 1, h), Vector2i(c + 1, h), Vector2i(c, h - 1)]:
		var b: Dictionary = sim._at(n)
		if not b.is_empty() and int(b.v) == v:
			s += 10.0
	if h == Sim.ROWS and s == 0.0:
		return -500.0
	if skill >= 2:
		s -= h * 1.2
		if not below.is_empty() and int(below.v) < v:
			s -= 3.0
		if not below.is_empty() and int(below.v) == v * 2:
			s += 2.0
	return s
