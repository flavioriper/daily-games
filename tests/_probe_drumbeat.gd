extends SceneTree

## Plays every Drumbeat chart with a bot and prints the result:
##
##     godot --headless --script res://tests/_probe_drumbeat.gd -- [jitter ms] [slips %]
##
## The bot strikes each note `jitter` ms off at random (0 = dead on), strikes
## the wrong side on `slips` percent of them, doubles every big note, rolls at
## 12 a second and pops every balloon.

const Sim = preload("res://puzzles/drumbeat_state.gd")

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var jitter := float(args[0]) / 1000.0 if args.size() > 0 else 0.0
	var slips := float(args[1]) / 100.0 if args.size() > 1 else 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for song: Dictionary in Sim.songs():
		for lv in 4:
			var sim := Sim.new(song, lv)
			var taps: Array = []
			for n: Dictionary in sim.notes:
				if Sim.is_long(n.type):
					var t := float(n.t) + 0.01
					var k := 0
					while t < float(n.end) - 0.01 and (n.type != Sim.Type.BALLOON or k < int(n.count)):
						taps.append([t, true])
						t += 1.0 / 12.0
						k += 1
					continue
				var at := float(n.t) + rng.randf_range(-jitter, jitter)
				var face := Sim.is_don(n.type)
				if rng.randf() < slips:
					face = not face
				taps.append([at, face])
				if Sim.is_big(n.type):
					taps.append([at + 0.02, face])
			taps.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
			var t := -1.0
			var i := 0
			while not sim.done and t < 400.0:
				t += 1.0 / 120.0
				while i < taps.size() and float(taps[i][0]) <= t:
					sim.hit(float(taps[i][0]), bool(taps[i][1]))
					i += 1
				sim.update(t)
				sim.events.clear()
			print("%-9s %d  score %7d  good %3d ok %3d bad %3d  combo %3d/%3d  gauge %5.1f  rolls %3d balloons %d bigs %d  clear %s fc %s ag %s  end %.1f/%.1f" % [
				song.id, lv, sim.score, sim.goods, sim.oks, sim.bads, sim.max_combo, sim.regular_count(), sim.gauge,
				sim.rolls, sim.balloons, sim.bigs, sim.cleared(), sim.full_combo(), sim.all_good(), t, sim.length])
	quit()
