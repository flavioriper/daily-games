extends SceneTree

## Plays Molehill's sim headless with a bot of a given reaction time and
## prints the score, the whacks, the escapes and a tally of events. Run
## after touching arcade/molehill_sim.gd.
##   godot --headless --script tests/_probe_molehill.gd -- [seed] [react ms] [slips 0..1]
## The bot sees a mole `react` ms after it starts rising, whacks moles one at
## a time (one tap per `react` / 2 at most, a finger's pace), and whacks a
## rabbit by mistake `slips` of the time.

const Sim = preload("res://arcade/molehill_sim.gd")

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var seed_v := int(args[0]) if args.size() > 0 else 7
	var react := float(args[1]) / 1000.0 if args.size() > 1 else 0.35
	var slips := float(args[2]) if args.size() > 2 else 0.05
	var sim = Sim.new(seed_v)
	var pick := RandomNumberGenerator.new()
	pick.seed = seed_v + 1
	var tally := {}
	var busy := 0.0
	var seen := {}   # hill -> seconds since it came up, for the bot's eyes
	var guard := 0
	var max_up := 0
	while not sim.is_over() and guard < 60 * 120:
		guard += 1
		busy -= Sim.DT
		var up := 0
		for i in Sim.HILLS:
			var h: Dictionary = sim.hills[i]
			if h.st == Sim.St.RISE or h.st == Sim.St.UP:
				up += 1
				seen[i] = float(seen.get(i, 0.0)) + Sim.DT
			else:
				seen.erase(i)
		max_up = maxi(max_up, up)
		if busy <= 0.0:
			# the oldest mole it has seen, never a rabbit unless it slips
			var target := -1
			var oldest := 0.0
			for i: int in seen:
				var h: Dictionary = sim.hills[i]
				if h.done or seen[i] < react:
					continue
				if h.kind == Sim.Kind.BUNNY and pick.randf() > slips * Sim.DT * 20.0:
					continue
				if seen[i] > oldest:
					oldest = seen[i]
					target = i
			if target >= 0:
				sim.whack(target)
				busy = react * 0.5
		sim.step()
		for ev: Dictionary in sim.events:
			tally[ev.type] = int(tally.get(ev.type, 0)) + 1
		sim.events.clear()
	print("seed %d react %d ms: score %d  whacked %d  escaped %d  missed %d  bunnies %d  golds %d  best streak %d  most up %d" % [
		seed_v, int(react * 1000), sim.score, sim.whacked, sim.escaped, sim.missed, sim.bunnies, sim.golds, sim.best_streak, max_up])
	print(tally)
	quit()
