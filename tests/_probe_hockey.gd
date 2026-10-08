extends SceneTree

## Air hockey, computer against computer, as pure data: whole matches at every
## pairing of levels, with what a match is like printed a line a pairing --
## who won how often, how long a match and a rally last, how hard the puck is
## hit -- and three things that must hold whatever is changed in
## versus/hockey_sim.gd or versus/hockey_ai.gd: the puck never leaves the
## table but through a goal, every match ends, and a level beats the one
## below it more often than not. Then the tutorial's scripted scenes
## (ui/hud/hockey_tutorial_diagram.gd), which must still do what their pages
## say: the swing scores, the bank goes in off a rail, the block keeps it out.
## And a puck left at rest in a corner or against a rail, where no mallet can
## get behind it, must come away by itself.
##
##     godot --headless --path . --script res://tests/_probe_hockey.gd -- [matches] [seed]

const Sim = preload("res://versus/hockey_sim.gd")
const AI = preload("res://versus/hockey_ai.gd")

## A match that is not over by now never will be.
const LIMIT := 2400.0

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var n := int(args[0]) if args.size() > 0 else 12
	var seed := int(args[1]) if args.size() > 1 else 7
	var bad := 0
	for a in 3:
		for b in 3:
			var wins := [0, 0]
			var secs := 0.0
			var goals := 0
			var hits := 0
			var top := 0.0
			var own := 0
			var stuck := 0
			for k in n:
				var r := _match(a, b, seed + k * 31 + a * 7 + b * 3)
				if r.is_empty():
					stuck += 1
					continue
				wins[r.winner] += 1
				secs += r.secs
				goals += r.goals
				hits += r.hits
				top = maxf(top, r.top)
				bad += r.out
			var played := maxi(1, n - stuck)
			print("bottom L%d v top L%d: %2d-%2d  %5.1f s a match  %4.1f s a goal  %4.1f hits a goal  top %.1f m/s unfinished %d" % [
				a, b, wins[0], wins[1], secs / played, secs / maxi(1, goals), float(hits) / maxi(1, goals), top, stuck])
			bad += stuck
			if a > b and wins[0] <= wins[1]:
				print("  ! level %d did not beat level %d" % [a, b])
				bad += 1
			if a < b and wins[1] <= wins[0]:
				print("  ! level %d did not beat level %d" % [b, a])
				bad += 1
	bad += _lessons()
	bad += _corners()
	print("OK" if bad == 0 else "FAILED: %d" % bad)
	quit(0 if bad == 0 else 1)

func _match(a: int, b: int, seed: int) -> Dictionary:
	var sim := Sim.new()
	var bots := [AI.new(0, a, seed), AI.new(1, b, seed + 1)]
	var first := seed % 2
	sim.reset(first)
	for bot in bots:
		bot.served()
	var hits := 0
	var top := 0.0
	var own := 0
	var out := 0
	var pause := 0.0
	var t := 0.0
	while not sim.over and t < LIMIT:
		t += Sim.DT
		for bot in bots:
			bot.drive(sim, Sim.DT)
		sim.step()
		for e in sim.events:
			match String(e.kind):
				"mallet":
					hits += 1
				"goal":
					pause = 0.8
		sim.events.clear()
		if sim.puck_on:
			top = maxf(top, sim.puck_vel.length())
			if sim.puck.x < 0.0 or sim.puck.x > Sim.W or sim.puck.y < -0.2 or sim.puck.y > Sim.L + 0.2 or is_nan(sim.puck.x):
				out += 1
		elif not sim.over:
			pause -= Sim.DT
			if pause <= 0.0:
				# to whoever was scored on
				sim.serve(0 if sim.puck.y > Sim.L * 0.5 else 1)
				for bot in bots:
					bot.served()
	if not sim.over:
		return {}
	return {"winner": sim.winner, "secs": sim.clock, "goals": sim.scores[0] + sim.scores[1], "hits": hits, "top": top, "own": own, "out": out}

## The tutorial's scenes, run as the page runs them.
func _lessons() -> int:
	var D = load("res://ui/hud/hockey_tutorial_diagram.gd")
	var bad := 0
	for lesson in [D.Lesson.LEAD, D.Lesson.SCORE, D.Lesson.BLOCK, D.Lesson.BANK]:
		var scene: Dictionary = D.scene_of(lesson)
		var sim: RefCounted = D.lay(scene)
		var t := 0.0
		var hits := [0, 0]
		var walls := 0
		var goal := -1
		var goal_t := 0.0
		while t < float(scene.len):
			t += Sim.DT
			D.advance(scene, sim, t)
			for e in sim.events:
				match String(e.kind):
					"mallet":
						hits[int(e.who)] += 1
					"wall":
						walls += 1
					"goal":
						goal = int(e.by)
						goal_t = t
			sim.events.clear()
		var ok := true
		match lesson:
			D.Lesson.LEAD:
				ok = hits[0] == 0 and goal == -1
			D.Lesson.SCORE:
				ok = goal == 0 and walls == 0
			D.Lesson.BLOCK:
				ok = goal == -1 and hits[0] >= 2 and hits[1] >= 1
			D.Lesson.BANK:
				ok = goal == 0 and walls >= 1 and hits[1] == 0
		print("lesson %d: hits %s walls %d goal %d at %.2f s  %s" % [lesson, str(hits), walls, goal, goal_t, "ok" if ok else "!"])
		if not ok:
			bad += 1
	return bad

## A puck at rest where a mallet can only push it further in: it must drift
## clear of the rails by itself.
func _corners() -> int:
	var bad := 0
	var r := Sim.PUCK_R
	for at in [Vector2(r, r), Vector2(Sim.W - r, r), Vector2(r, Sim.L - r), Vector2(Sim.W - r, Sim.L - r),
			Vector2(0.3, r), Vector2(0.7, Sim.L - r), Vector2(r, 0.6), Vector2(Sim.W - r, 1.1)]:
		var sim := Sim.new()
		sim.reset(0)
		sim.puck = at
		var t := 0.0
		while t < 6.0:
			t += Sim.DT
			sim.step()
		var clear: bool = sim.puck.x > Sim.EDGE and sim.puck.x < Sim.W - Sim.EDGE and sim.puck.y > Sim.EDGE and sim.puck.y < Sim.L - Sim.EDGE
		if not clear or not sim.puck_on:
			print("  ! a puck left at %s is at %s after 6 s" % [str(at), str(sim.puck)])
			bad += 1
	print("corners and rails: %s" % ("clear" if bad == 0 else "STUCK"))
	return bad
