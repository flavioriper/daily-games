extends SceneTree

## Plays Brittle's sim with a bot: `godot --headless --script
## res://tests/_probe_brittle.gd -- [runs] [skill]`. Skill is how many angles
## it tries a volley (more is better). Prints where runs end, how long a
## volley takes in game time, and any ball that stays out.

const Sim = preload("res://arcade/brittle_sim.gd")

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var runs := int(args[0]) if args.size() > 0 else 20
	var skill := int(args[1]) if args.size() > 1 else 9
	var steps := []
	var scores := []
	var longest := 0.0
	var total_flight := 0.0
	var vols := 0
	var capped := 0
	var t0 := Time.get_ticks_msec()
	for run in runs:
		var sim := Sim.new(run + 1)
		var picker := RandomNumberGenerator.new()
		picker.seed = run * 31 + 7
		while not sim.is_over() and sim.step_n < 150:
			var d := _choose(sim, picker, skill)
			sim.fire(d)
			var ticks := 0
			while sim.flying() and ticks < 120 * 120:
				sim.step()
				ticks += 1
			if sim.flying():
				capped += 1
				sim.recall()
				while sim.flying():
					sim.step()
			sim.events.clear()
			longest = maxf(longest, sim.clock)
			total_flight += sim.clock
			vols += 1
			# every number stays a number
			for i in sim.kind.size():
				assert(not Sim.solid(sim.kind[i]) or sim.hp[i] > 0)
		print("run %d: step %d, balls %d, score %d, %d ms" % [run, sim.step_n, sim.balls, sim.score, Time.get_ticks_msec() - t0])
		steps.append(sim.step_n)
		scores.append(sim.score)
	steps.sort()
	print("runs %d skill %d: step min %d med %d max %d, score med %d, volley mean %.1fs longest %.1fs, capped %d, %d ms" % [runs, skill,
		steps[0], steps[steps.size() / 2], steps[-1], scores[scores.size() / 2], total_flight / maxf(vols, 1.0), longest, capped, Time.get_ticks_msec() - t0])
	# undo gives the same row back
	var a := Sim.new(5)
	a.fire(Vector2(0.3, -1.0))
	while a.flying():
		a.step()
	var row := a.kind.slice(0, Sim.COLS)
	var hit := a.score
	a.undo()
	a.fire(Vector2(0.3, -1.0))
	while a.flying():
		a.step()
	print("undo same row: ", row == a.kind.slice(0, Sim.COLS), " same score: ", hit == a.score)
	# a recalled volley ends at once
	var b := Sim.new(6)
	for _k in 30:
		b.balls = 60
		b.fire(Vector2(-0.4, -1.0))
		for _s in 60:
			b.step()
		b.recall()
		var n := 0
		while b.flying() and n < 2000:
			b.step()
			n += 1
		if b.flying() or b.over:
			break
	print("recall ok: ", not b.flying())
	var c := Sim.new(7)
	for r in Sim.ROWS + 1:
		c.kind[Sim.index(r, 3)] = Sim.Kind.SQUARE
		c.hp[Sim.index(r, 3)] = 5
	c.over = true
	c.revive()
	print("revive ok: ", not c.over, " lowest row empty: ", c.kind[Sim.index(Sim.ROWS - 1, 3)] == Sim.Kind.NONE, " upper stays: ", c.kind[Sim.index(2, 3)] == Sim.Kind.SQUARE)
	quit()

## The angle that does best when really played out on a copy of the tin.
func _choose(sim, picker: RandomNumberGenerator, skill: int) -> Vector2:
	var best := Vector2.UP
	var top := -INF
	for _k in skill:
		var d := Vector2.UP.rotated(picker.randf_range(-1.42, 1.42))
		var c = _copy(sim)
		c.fire(d)
		var ticks := 0
		while c.flying() and ticks < 3000:
			c.step()
			ticks += 1
		var worth: float = float(c.score - sim.score) / float(maxi(sim.step_n, 1)) + 4.0 * float(c.balls - sim.balls)
		for k in c.kind.size():
			if Sim.solid(c.kind[k]):
				worth -= pow(float(k / Sim.COLS), 2.0) * 0.08
		if c.is_over():
			worth -= 1000.0
		if worth > top:
			top = worth
			best = d
	return best

func _copy(sim) -> RefCounted:
	var c := Sim.new(1)
	c.kind = sim.kind.duplicate()
	c.hp = sim.hp.duplicate()
	c.full = sim.full.duplicate()
	c.step_n = sim.step_n
	c.score = sim.score
	c.balls = sim.balls
	c.home_x = sim.home_x
	c.next_x = sim.home_x
	c.rng.state = sim.rng.state
	return c
