extends SceneTree

## Knight's generator, timed and checked: forty seeds a level, the mean and
## worst wall time in GDScript, the shortest line's range, and every board's
## line replayed through `step` to a win that is never caught, with the naive
## line proved to fail. A harness, not a suite entry.
##     godot --headless --path . --script tests/_probe_knight_gen.gd
const G := preload("res://puzzles/knight_gen.gd")
const S := preload("res://puzzles/knight_state.gd")

func _initialize() -> void:
	for d in 4:
		var worst := 0.0
		var sum := 0.0
		var lo := 99
		var hi := 0
		var bad := 0
		var short := 0
		var att_max := 0
		var node_max := 0
		var node_sum := 0
		var cnt := 40
		for s in cnt:
			var rng := RandomNumberGenerator.new()
			rng.seed = s * 7919 + d
			var t0 := Time.get_ticks_usec()
			var g := G.generate(rng, d)
			var ms := (Time.get_ticks_usec() - t0) / 1000.0
			worst = maxf(worst, ms)
			sum += ms
			att_max = maxi(att_max, int(g.attempts))
			var nodes: int = g.nodes
			node_max = maxi(node_max, nodes)
			node_sum += nodes
			var opt: int = g.opt
			lo = mini(lo, opt)
			hi = maxi(hi, opt)
			if opt < int(G.band(d).min):
				short += 1
			var you: int = g.you
			var foes: PackedInt32Array = g.foes
			var ok := true
			for i in g.line.size():
				var r: Dictionary = G.step(g, you, foes, g.line[i])
				if r.caught >= 0 or (r.won != (i == g.line.size() - 1)):
					ok = false
					break
				you = r.you
				foes = r.foes
			if not ok or G.naive_wins(g):
				bad += 1
				print("  BAD d=%d s=%d" % [d, s])
		print("level %d: mean %.1f ms worst %.1f ms, shortest %d-%d, below min %d, attempts max %d, bad %d" % [
			d, sum / cnt, worst, lo, hi, short, att_max, bad])
		print("  nodes: max %d mean %.1f" % [node_max, float(node_sum) / cnt])
	_check_state()
	quit()

## The state, driven the way the board drives it: a caught move keeps
## nothing, the day's line wins, Undo and Reset put everything back, a taken
## rose knight returns on Undo, and Insane's budget refuses the move past it.
func _check_state() -> void:
	var fails := 0
	var caught_checks := 0
	var budget_checks := 0
	for d in 4:
		for s in 10:
			var rng := RandomNumberGenerator.new()
			rng.seed = s * 7919 + d
			var st = S.new()
			st.build(rng, d)
			# a caught move is not kept
			var reach: Dictionary = st.reach()
			for m in st.legal():
				if reach.has(m) and m != st.king:
					caught_checks += 1
					var you0: int = st.you
					var r: Dictionary = st.play(m)
					if int(r.caught) < 0 or st.you != you0 or not st.history.is_empty():
						fails += 1
						print("  caught move kept d=%d s=%d" % [d, s])
					break
			# the line wins
			for m in st.g.line:
				st.play(m)
			if not st.is_solved():
				fails += 1
				print("  line did not win d=%d s=%d" % [d, s])
			# reset puts back the opening, including taken rose knights
			st.reset_board()
			if st.you != int(st.g.you) or st.foes != st.g.foes or st.is_solved() or st.can_undo():
				fails += 1
				print("  reset wrong d=%d s=%d" % [d, s])
			# undo after every step of the line walks it back
			for m in st.g.line.slice(0, st.g.line.size() - 1):
				st.play(m)
			while st.can_undo():
				st.undo()
			if st.you != int(st.g.you) or st.foes != st.g.foes:
				fails += 1
				print("  undo walk wrong d=%d s=%d" % [d, s])
			# hints alone solve it
			for i in 64:
				var h: int = st.hint_move()
				if h < 0:
					break
				st.play(h)
			if not st.is_solved():
				fails += 1
				print("  hints did not solve d=%d s=%d" % [d, s])
			# a forced budget always binds, on every level: the shortest line's
			# first two hops are never caught, so this runs the same way on
			# every seed rather than depending on the greedy walk finding an
			# uncaught square before the real budget runs out
			st.reset_board()
			var orig_budget = st.g.get("budget", 0)
			st.g["budget"] = 2
			st.play(st.g.line[0])
			st.play(st.g.line[1])
			budget_checks += 1
			if st.moves_left() != 0:
				fails += 1
				print("  budget not spent d=%d s=%d" % [d, s])
			if not st.play(st.legal()[0]).is_empty():
				fails += 1
				print("  budget not enforced d=%d s=%d" % [d, s])
			if st.hint_move() != -1:
				fails += 1
				print("  hint ignored budget d=%d s=%d" % [d, s])
			st.undo()
			if st.moves_left() != 1:
				fails += 1
				print("  undo did not give a move back d=%d s=%d" % [d, s])
			st.g["budget"] = orig_budget
	print("state: %d failures, %d budget checks, %d caught checks" % [fails, budget_checks, caught_checks])
