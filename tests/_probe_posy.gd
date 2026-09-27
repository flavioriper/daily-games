extends SceneTree

## Plays Posy's sim headless with a bot and prints how far it got. Run after
## touching arcade/posy_sim.gd.
##   godot --headless --script tests/_probe_posy.gd -- [seed] [skill 0-2] [tools 0/1] [games]
## Skill 0 plays a random move, 1 the hint (the longest line), 2 tries every
## move on a copy and keeps the one that does most for the day's goals. With
## `games` over 1 it plays that many seeds and prints how far they got.

const Sim = preload("res://arcade/posy_sim.gd")

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var seed_v := int(args[0]) if args.size() > 0 else 7
	var skill := int(args[1]) if args.size() > 1 else 2
	var use_tools := (int(args[2]) if args.size() > 2 else 1) == 1
	var games := int(args[3]) if args.size() > 3 else 1
	var days := {}
	var total := 0
	var t0 := Time.get_ticks_msec()
	for g in games:
		var sim = _play(seed_v + g, skill, use_tools, games == 1)
		days[sim.day] = int(days.get(sim.day, 0)) + 1
		total += sim.score
	if games > 1:
		var keys := days.keys()
		keys.sort()
		var line := ""
		for d in keys:
			line += "%d:%d " % [d, days[d]]
		print("skill %d tools %s over %d games: mean score %d, ended on day (day:games) %s (%.1f s)" % [
			skill, use_tools, games, total / games, line, (Time.get_ticks_msec() - t0) / 1000.0])
	quit()

func _play(seed_v: int, skill: int, use_tools: bool, verbose: bool):
	var sim = Sim.new(seed_v)
	var pick := RandomNumberGenerator.new()
	pick.seed = seed_v + 1
	var tally := {}
	var guard := 0
	while not sim.is_over() and guard < 3000:
		guard += 1
		# a tool when a day is about to be lost
		if use_tools and sim.moves_left <= 2 and not sim.goals_met():
			var used := false
			for tool in [Sim.Tool.BOMB, Sim.Tool.TROWEL]:
				if sim.can_use(tool):
					sim.use(tool, Vector2i(pick.randi_range(1, 6), pick.randi_range(1, 6)))
					used = true
					break
			if used:
				_tally(sim, tally)
				continue
		var moves: Array = sim.all_moves()
		if moves.is_empty():
			print("no move on seed %d day %d" % [seed_v, sim.day])
			break
		var m: Array
		match skill:
			0:
				m = moves[pick.randi() % moves.size()]
			1:
				m = sim.hint()
			_:
				m = _best(sim, moves)
		var ok: bool = sim.swap(m[0], m[1])
		if not ok:
			print("refused move ", m)
			break
		_tally(sim, tally)
	if verbose:
		print("seed %d skill %d: day %d, score %d, moves %d, made %d, best cascade %d, tools used %d" % [
			seed_v, skill, sim.day, sim.score, sim.moves, sim.made, sim.best_cascade, sim.tools_used])
		print(tally)
	return sim

func _tally(sim, tally: Dictionary) -> void:
	for ev: Dictionary in sim.events:
		tally[ev.type] = int(tally.get(ev.type, 0)) + 1
	sim.events.clear()

func _best(sim, moves: Array) -> Array:
	var best: Array = moves[0]
	var best_v := -1.0
	for m: Array in moves:
		var s = sim.clone()
		s.swap(m[0], m[1])
		var v := 0.0
		for g: Dictionary in s.goals:
			v += mini(int(g.got), int(g.need))
		if s.day > sim.day:
			v += 1000.0
		v += s.score * 0.0001
		if v > best_v:
			best_v = v
			best = m
	return best
