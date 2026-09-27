extends SceneTree

## Plays Firefly's sim headless with a simple bot for a few minutes of game
## time and prints what happened: stages reached, score, and a tally of
## events. Run after touching arcade/firefly_sim.gd.
##   godot --headless --script tests/_probe_firefly.gd -- [seed] [minutes]

const Sim = preload("res://arcade/firefly_sim.gd")

## 1 plays well; lower fires less and dodges less.
var skill := 1.0
var _rng := RandomNumberGenerator.new()

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var seed_v := int(args[0]) if args.size() > 0 else 7
	var minutes := float(args[1]) if args.size() > 1 else 4.0
	skill = float(args[2]) if args.size() > 2 else 1.0
	var sim: RefCounted = Sim.new(seed_v)
	var tally := {}
	var steps := int(minutes * 60.0 / Sim.DT)
	var t0 := Time.get_ticks_usec()
	var stages := []
	for i in steps:
		_bot(sim)
		sim.step()
		for ev: Dictionary in sim.events:
			tally[ev.type] = int(tally.get(ev.type, 0)) + 1
			if ev.type == "stage_start" or ev.type == "challenge_start":
				stages.append(ev.stage)
			if ev.type == "challenge_result":
				print("flyby: %d/%d bonus %d" % [ev.hits, ev.total, ev.bonus])
		sim.events.clear()
		if sim.is_over():
			print("game over at %.1f s" % sim.t)
			break
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	print("stage %d score %d ships %d fired %d hits %d kills %d" % [sim.stage, sim.score, sim.ships, sim.fired, sim.hits, sim.kills])
	print("stages: ", stages)
	print("events: ", tally)
	print("sim ms per game second: %.2f" % (ms / sim.t))
	quit()

## Sits under the lowest bug, sidesteps bullets coming down on it, fires.
func _bot(sim: RefCounted) -> void:
	sim.fire = _rng.randf() < skill
	var aim: float = sim.px
	var best := -1.0
	for e: Dictionary in sim.enemies:
		if e.st == Sim.St.WAIT:
			continue
		if e.pos.y > best and e.pos.y < Sim.PLAYER_Y - 30.0:
			best = e.pos.y
			aim = e.pos.x
	for b: Dictionary in sim.bullets:
		if b.pos.y > Sim.PLAYER_Y - 90.0 and absf(b.pos.x - sim.px) < 14.0 and _rng.randf() < skill:
			aim = sim.px + (30.0 if b.pos.x < sim.px else -30.0)
	sim.target_x = aim
