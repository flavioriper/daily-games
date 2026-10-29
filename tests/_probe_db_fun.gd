extends SceneTree

## Throwaway: a thumb on glass playing every Drumbeat chart. Each stroke is
## off by a normal error of `sd` ms around `lag` ms late, `wrong` percent go
## to a neighbouring drum, `skip` percent are not played. Ten seeds a song;
## prints the share cleared per band and the median gauge.
##     godot --headless --script res://tests/_probe_db_fun.gd -- sd lag wrong skip

const Sim = preload("res://puzzles/drumbeat_state.gd")

func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var sd := float(a[0]) / 1000.0
	var lag := float(a[1]) / 1000.0
	var wrong := float(a[2]) / 100.0
	var skip := float(a[3]) / 100.0
	var line := ""
	for lv in 4:
		var clears := 0
		var runs := 0
		var gauges := []
		for song: Dictionary in Sim.songs():
			for seed in 10:
				var rng := RandomNumberGenerator.new()
				rng.seed = 1000 * seed + lv
				var sim := Sim.new(song, lv)
				var acts: Array = []
				for n: Dictionary in sim.notes:
					if Sim.is_long(n.type):
						var t := float(n.t) + 0.02
						var k := 0
						while t < float(n.end) - 0.01 and (n.type != Sim.Type.BALLOON or k < int(n.count)):
							acts.append([t, n.lane, true]); acts.append([t + 0.03, n.lane, false])
							t += 1.0 / 9.0; k += 1
						continue
					if rng.randf() < skip:
						continue
					var lane := int(n.lane)
					if sim.lanes > 1 and rng.randf() < wrong:
						lane = (lane + 1 + rng.randi_range(0, sim.lanes - 2)) % sim.lanes
					var at := float(n.t) + lag + rng.randfn(0.0, sd)
					acts.append([at, lane, true])
					acts.append([(float(n.end) + 0.02) if n.type == Sim.Type.HOLD else at + 0.05, lane, false])
				acts.sort_custom(func(x: Array, y: Array) -> bool: return x[0] < y[0])
				var t := -1.0
				var i := 0
				while not sim.done and not sim.out and t < 400.0:
					t += 1.0 / 120.0
					while i < acts.size() and float(acts[i][0]) <= t:
						if acts[i][2]: sim.press(float(acts[i][0]), int(acts[i][1]))
						else: sim.lift(float(acts[i][0]), int(acts[i][1]))
						i += 1
					sim.update(t)
					sim.events.clear()
				runs += 1
				if sim.cleared() and not sim.out: clears += 1
				gauges.append(sim.gauge)
		gauges.sort()
		line += "  band %d clear %2d/%d gauge %3.0f" % [lv, clears, runs, gauges[gauges.size() / 2]]
	print("sd %d lag %d wrong %d skip %d:%s" % [int(sd * 1000), int(lag * 1000), int(wrong * 100), int(skip * 100), line])
	quit()
