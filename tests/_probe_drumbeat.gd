extends SceneTree

## Plays every Drumbeat chart with a bot and prints the result:
##
##     godot --headless --script res://tests/_probe_drumbeat.gd -- [jitter ms] [slips %] [lag ms]
##
## The bot strikes each note on its drum `jitter` ms off at random (0 = dead
## on) and `lag` ms late on average, skips `slips` percent of the notes, keeps
## every hold to its end, rolls at 12 a second and pops every balloon.

const Sim = preload("res://puzzles/drumbeat_state.gd")

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var jitter := float(args[0]) / 1000.0 if args.size() > 0 else 0.0
	var slips := float(args[1]) / 100.0 if args.size() > 1 else 0.0
	var lag := float(args[2]) / 1000.0 if args.size() > 2 else 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for song: Dictionary in Sim.songs():
		for lv in 4:
			var sim := Sim.new(song, lv)
			var acts: Array = []  # [t, lane, press?]
			for n: Dictionary in sim.notes:
				if Sim.is_long(n.type):
					var t := float(n.t) + 0.01
					var k := 0
					while t < float(n.end) - 0.01 and (n.type != Sim.Type.BALLOON or k < int(n.count)):
						acts.append([t, n.lane, true])
						acts.append([t + 0.03, n.lane, false])
						t += 1.0 / 12.0
						k += 1
					continue
				if rng.randf() < slips:
					continue
				var at := float(n.t) + lag + rng.randf_range(-jitter, jitter)
				acts.append([at, n.lane, true])
				acts.append([(float(n.end) + 0.02) if n.type == Sim.Type.HOLD else at + 0.04, n.lane, false])
			acts.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
			var t := -1.0
			var i := 0
			var lost := []
			while not sim.done and not sim.out and t < 400.0:
				t += 1.0 / 120.0
				while i < acts.size() and float(acts[i][0]) <= t:
					if acts[i][2]:
						sim.press(float(acts[i][0]), int(acts[i][1]))
					else:
						sim.lift(float(acts[i][0]), int(acts[i][1]))
					i += 1
				sim.update(t)
				for ev: Dictionary in sim.events:
					if ev.type == "heart":
						lost.append("%.0f" % t)
				sim.events.clear()
			print("%-9s %d  score %7d  good %3d ok %3d bad %3d slip %2d  combo %3d/%3d  gauge %5.1f  holds %2d rolls %3d balloons %d  hearts %d/%d %s  clear %s fc %s  end %.1f/%.1f" % [
				song.id, lv, sim.score, sim.goods, sim.oks, sim.bads, sim.slips, sim.max_combo, sim.regular_count(), sim.gauge,
				sim.holds, sim.rolls, sim.balloons, sim.hearts, sim.max_hearts, ",".join(lost), sim.cleared() and not sim.out, sim.full_combo(), t, sim.length])
	quit()
