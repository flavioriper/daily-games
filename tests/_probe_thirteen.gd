extends SceneTree

## Plays Lucky Thirteen's sim headless with a bot and prints how far it got.
## Run after touching arcade/thirteen_sim.gd.
##   godot --headless --script tests/_probe_thirteen.gd -- [seed] [skill 0-2] [tools 0/1] [games]
## Skill 0 merges a random group, 1 the smallest number's biggest group, 2
## tries every group and end on a copy and keeps the tray with the most
## moves left in it. With `games` over 1 it plays that many seeds and
## prints how often each number was reached.

const Sim = preload("res://arcade/thirteen_sim.gd")

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var seed_v := int(args[0]) if args.size() > 0 else 7
	var skill := int(args[1]) if args.size() > 1 else 2
	var use_tools := (int(args[2]) if args.size() > 2 else 1) == 1
	var games := int(args[3]) if args.size() > 3 else 1
	var reached := {}
	var total_moves := 0
	var total_score := 0
	var t0 := Time.get_ticks_msec()
	for g in games:
		var sim = _play(seed_v + g, skill, use_tools, games == 1)
		for v in range(1, sim.max_v + 1):
			reached[v] = int(reached.get(v, 0)) + 1
		total_moves += sim.moves
		total_score += sim.score
	if games > 1:
		var line := ""
		for v in range(4, 16):
			if reached.has(v):
				line += "%d:%.0f%% " % [v, 100.0 * reached[v] / games]
		print("skill %d tools %s over %d games: mean moves %.0f, mean score %d, reached %s (%.1f s)" % [
			skill, use_tools, games, float(total_moves) / games, total_score / games, line, (Time.get_ticks_msec() - t0) / 1000.0])
	quit()

func _play(seed_v: int, skill: int, use_tools: bool, verbose: bool):
	var sim = Sim.new(seed_v)
	var pick := RandomNumberGenerator.new()
	pick.seed = seed_v + 1
	var tally := {}
	var guard := 0
	while not sim.is_over() and guard < 5000:
		guard += 1
		if sim.phase == Sim.Phase.STUCK:
			if not (use_tools and _rescue(sim, pick)):
				sim.give_up()
		else:
			var chain := _choose(sim, skill, pick)
			sim.begin(chain[0])
			for k in range(1, chain.size()):
				sim.extend(chain[k])
			sim.commit()
		for ev: Dictionary in sim.events:
			tally[ev.type] = int(tally.get(ev.type, 0)) + 1
		sim.events.clear()
	if verbose:
		print("seed %d skill %d tools %s: score %d, biggest %d, moves %d, best chain %d, clovers left %d, tools used %d" % [
			seed_v, skill, use_tools, sim.score, sim.max_v, sim.moves, sim.best_chain, sim.clovers, sim.tools_used])
		print(tally)
	return sim

static func _choose(sim, skill: int, pick: RandomNumberGenerator) -> Array:
	var groups: Array = sim.groups_of(Sim.MIN_CHAIN)
	if skill == 0:
		var g: Array = groups[pick.randi_range(0, groups.size() - 1)]
		var ends := g.duplicate()
		ends.shuffle()
		return _first_long(g, ends)
	if skill == 1:
		groups.sort_custom(func(a: Array, b: Array) -> bool:
			var va: int = sim.value(a[0])
			var vb: int = sim.value(b[0])
			return va < vb if va != vb else a.size() > b.size())
		var g: Array = groups[0]
		# end on the lowest cell, so the new pebble sits under the fresh ones
		var ends := g.duplicate()
		ends.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y > b.y)
		return _first_long(g, ends)
	var best: Array = []
	var best_s := -INF
	for g: Array in groups:
		for end: Vector2i in g:
			var chain := Sim.chain_through(g, end, 300)
			if chain.size() < Sim.MIN_CHAIN:
				continue
			var s := _rate(sim, chain) + pick.randf() * 0.01
			if s > best_s:
				best_s = s
				best = chain
	return best

static func _first_long(g: Array, ends: Array) -> Array:
	for end: Vector2i in ends:
		var chain := Sim.chain_through(g, end, 400)
		if chain.size() >= Sim.MIN_CHAIN:
			return chain
	return []

## A move's worth: what the tray looks like after it on a copy -- moves
## left, the new pebble beside its own number, big numbers kept low.
static func _rate(sim, chain: Array) -> float:
	var s = sim.clone()
	s.begin(chain[0])
	for k in range(1, chain.size()):
		s.extend(chain[k])
	s.commit()
	var into: Vector2i = chain[-1]
	var nv: int = s.value(into)
	var score := 0.0
	var groups: Array = s.groups_of(2)
	for g: Array in groups:
		var v: int = s.value(g[0])
		score += (g.size() - 1) * (1.0 + v * 0.35) * (2.0 if g.size() >= 3 else 1.0)
	if not s.has_move():
		score -= 60.0
	for d: Vector2i in Sim.NEIGHBOURS:
		if s.value(into + d) == nv:
			score += 2.0 + nv * 0.5
	# merge the small numbers first, and let the chain run long
	score -= sim.value(into) * 0.6
	score += chain.size() * 0.4
	return score

static func _rescue(sim, pick: RandomNumberGenerator) -> bool:
	for tool in [Sim.Tool.SHUFFLE, Sim.Tool.PLUCK, Sim.Tool.SWAP, Sim.Tool.LIFT, Sim.Tool.UNDO]:
		if not sim.can_use(tool):
			continue
		if tool in Sim.TARGETED:
			for tries in 40:
				var a := Vector2i(pick.randi_range(0, Sim.COLS - 1), pick.randi_range(0, Sim.ROWS - 1))
				var b := Vector2i(pick.randi_range(0, Sim.COLS - 1), pick.randi_range(0, Sim.ROWS - 1))
				if sim.can_target(tool, a, b):
					return sim.use(tool, a, b)
			continue
		return sim.use(tool)
	return false
