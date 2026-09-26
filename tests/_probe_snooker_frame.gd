extends SceneTree
const Sim = preload("res://versus/snooker_sim.gd")
const Rules = preload("res://versus/snooker_rules.gd")
const AI = preload("res://versus/snooker_ai.gd")
func _initialize() -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = int(OS.get_environment("SEED")) if OS.get_environment("SEED") != "" else 7
	var sim = Sim.new(); sim.log_events = false
	var rules = Rules.new(sim, 0)
	var shots := 0; var worst := 0; var total := 0
	var first := true
	while not rules.over and shots < 400:
		var state := {"phase": rules.phase, "free_ball": rules.free_ball, "in_hand": rules.in_hand, "break_off": first}
		var t0 := Time.get_ticks_msec()
		var lv := int(OS.get_environment("LEVEL")) if OS.get_environment("LEVEL") != "" else 2
		var plan: Dictionary = AI.plan(sim, state, lv)
		var ms := Time.get_ticks_msec() - t0
		worst = maxi(worst, ms); total += ms
		var shot := AI.deliver(plan, lv, rng)
		if rules.in_hand: sim.pos[0] = plan.cue_at
		sim.strike(shot.dir, shot.speed, shot.tip)
		sim.settle(30.0)
		var r: Dictionary = rules.judge()
		first = false
		shots += 1
		if OS.get_environment("VERBOSE") != "":
			print("#%d p%d %s %s scored=%d foul=%s pen=%d %s -> %s  score %s reds=%d plan=%dms" % [shots, r.player, plan.kind, state.phase, r.scored, r.foul, r.penalty, r.reason, rules.phase, str(rules.scores), sim.reds_left(), ms])
	print("OVER=", rules.over, " winner=", rules.winner, " scores=", rules.scores, " high=", rules.high_break, " shots=", shots, " worst plan ms=", worst, " mean=", total / max(1, shots))
	quit()
