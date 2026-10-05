extends SceneTree

## Times Peapod's sim with a full gun: usec a step on a millipede and a wall.
##   godot --headless --script tests/_probe_peapod_perf.gd

const Sim = preload("res://arcade/peapod_sim.gd")

func _run(wave: int, label: String) -> void:
	var sim = Sim.new(5)
	for i in 120:
		sim.step()
	sim.events.clear()
	sim.rate_lv = Sim.MAX_RATE
	sim.crit_lv = Sim.CRIT_MAX
	sim.power = 9
	sim.pod = Sim.Kind.ZAP
	sim.pod_t = 1000.0
	sim.rows.clear()
	sim.segs.clear()
	sim.wave = wave - 1
	sim.gap_t = 0.0
	sim._deal()
	var worst := 0
	var total := 0
	var events := 0
	var n := 600
	for i in n:
		sim.target_x = 150.0 + 120.0 * sin(i * 0.02)
		# nothing dies: the load stays whole
		for row in sim.rows:
			for c in row:
				if c != null:
					c.hp = 1 << 40
		for sg in sim.segs:
			sg.hp = 1 << 40
		var t0 := Time.get_ticks_usec()
		sim.step()
		var d := Time.get_ticks_usec() - t0
		total += d
		worst = maxi(worst, d)
		events += sim.events.size()
		sim.events.clear()
	print("%s: %d usec a step, worst %d, shots %d, events %.0f a second" % [label, total / n, worst, sim.shots.size(), events / (n / 60.0)])

func _initialize() -> void:
	_run(21, "millipede 24 plates")
	_run(20, "wall 9 rows")
	quit()
