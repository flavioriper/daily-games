extends SceneTree
## How snooker plays for a thumb, not an arm: the hint's own plan delivered
## with the aim error a phone's drag leaves (NOISE, radians, one sd) against the
## computer at LEVEL, FRAMES frames. Prints shots, table seconds, the hand's pot
## rate, fouls, its high break and who won.
##
##     LEVEL=0 NOISE=0.01 FRAMES=4 REDS=15 godot --headless --path . --script res://tests/_probe_sn_fun.gd
const Sim = preload("res://versus/snooker_sim.gd")
const Rules = preload("res://versus/snooker_rules.gd")
const AI = preload("res://versus/snooker_ai.gd")

func _env(k: String, d: float) -> float:
	return float(OS.get_environment(k)) if OS.get_environment(k) != "" else d

func _initialize() -> void:
	var lv := int(_env("LEVEL", 0))
	var noise := _env("NOISE", 0.01)
	var frames := int(_env("FRAMES", 4))
	var lock := _env("LOCK", 0.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(_env("SEED", 7))
	var won := 0
	var tail := 0.0
	var tot := {"shots": 0, "secs": 0.0, "tries": 0, "pots": 0, "fouls": 0, "high": 0, "yours": 0, "wait": 0.0}
	for f in frames:
		var sim = Sim.new()
		sim.log_events = false
		sim.keep_reds(int(_env("REDS", 6)))
		var rules = Rules.new(sim, f % 2)
		var first := true
		var shots := 0
		while not rules.over and shots < 400:
			var state := {"phase": rules.phase, "free_ball": rules.free_ball, "in_hand": rules.in_hand, "break_off": first}
			var me: bool = rules.turn == 0
			var plan: Dictionary = AI.plan(sim, state, 2 if me else lv)
			var shot: Dictionary
			if me:
				shot = plan.duplicate()
				# A thumb within the lock's window lands dead on the line.
				var err := rng.randfn(0.0, noise)
				shot.dir = (plan.dir as Vector2).rotated(0.0 if absf(err) < lock else err)
				shot.speed = clampf(float(plan.speed) * (1.0 + rng.randfn(0.0, _env("PACE", 0.1))), 0.3, Sim.MAX_SPEED)
			else:
				shot = AI.deliver(plan, lv, rng)
			if rules.in_hand or first:
				sim.pos[0] = plan.get("cue_at", sim.pos[0])
			sim.strike(shot.dir, shot.speed, shot.tip)
			var t := 0.0
			var slow_at := -1.0
			while sim.moving() and t < 30.0:
				sim.step(Sim.DT)
				t += Sim.DT
				var top := 0.0
				for i in Sim.COUNT:
					if sim.on[i]:
						top = maxf(top, sim.vel[i].length())
				if top < 0.25 and slow_at < 0.0:
					slow_at = t
				elif top >= 0.25:
					slow_at = -1.0
			tail += t - slow_at if slow_at >= 0.0 else 0.0
			sim.events.clear()
			var r: Dictionary = rules.judge()
			first = false
			shots += 1
			tot.secs += t
			if me:
				tot.tries += 1 if plan.kind == "pot" else 0
				tot.pots += 1 if int(r.scored) > 0 else 0
				tot.fouls += 1 if bool(r.foul) else 0
				tot.yours += 1
			else:
				tot.wait += t + 1.9
		tot.shots += shots
		tot.high = maxi(tot.high, rules.high_break[0])
		won += 1 if rules.winner == 0 else 0
	print("LEVEL=%d noise=%.4f frames=%d won=%d shots/frame=%.0f your shots=%.0f roll s/frame=%.0f bot wait s/frame=%.0f pots/tries=%d/%d fouls=%d high=%d tail s/frame=%.0f" % [lv, noise, frames, won, float(tot.shots) / frames, float(tot.yours) / frames, tot.secs / frames, tot.wait / frames, tot.pots, tot.tries, tot.fouls, tot.high, tail / frames])
	quit()
