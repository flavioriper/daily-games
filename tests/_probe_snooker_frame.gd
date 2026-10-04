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
	var trips_bad := 0
	var wire_max := 0
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
		# What a game online sends after every shot: the table and the referee's
		# whole state must come back through JSON exactly, flipped and not.
		var wire: Dictionary = JSON.parse_string(JSON.stringify({"table": sim.snapshot(), "rules": rules.to_dict()}))
		var t: Dictionary = Sim.read(wire.table)
		var sim2 = Sim.new()
		var rules2 = Rules.new(sim2, 1)
		var flipped = Rules.new(sim2, 0)
		if not t.is_empty():
			sim2.restore(t)
		if t.is_empty() or sim2.pos != sim.pos or sim2.on != sim.on or not rules2.from_dict(wire.rules) \
				or JSON.stringify(rules2.to_dict()) != JSON.stringify(rules.to_dict()) \
				or not flipped.from_dict(wire.rules, true) or JSON.stringify(flipped.to_dict(true)) != JSON.stringify(rules.to_dict()) \
				or flipped.turn != 1 - rules.turn or flipped.scores[0] != rules.scores[1]:
			trips_bad += 1
		wire_max = maxi(wire_max, JSON.stringify(wire).length())
		if OS.get_environment("VERBOSE") != "":
			print("#%d p%d %s %s scored=%d foul=%s pen=%d %s -> %s  score %s reds=%d plan=%dms" % [shots, r.player, plan.kind, state.phase, r.scored, r.foul, r.penalty, r.reason, rules.phase, str(rules.scores), sim.reds_left(), ms])
	print("OVER=", rules.over, " winner=", rules.winner, " scores=", rules.scores, " high=", rules.high_break, " shots=", shots, " worst plan ms=", worst, " mean=", total / max(1, shots))
	print("online round trip: ", shots - trips_bad, "/", shots, " exact, the longest message ", wire_max, " characters")
	quit()
