extends SceneTree

## Mini Golf, measured for the made-fun pass (2026-10-29): a casual hand
## (the steady putt struck well off) over each band's bank. How often a putt
## stops near the cup without dropping, how often a ball drops off a kerb,
## and the strokes against par.
##
##     godot --headless --script res://tests/_probe_gf_fun.gd -- [n=<holes a band>] [aim=<rad>] [pow=<share>]

const Sim = preload("res://puzzles/minigolf_sim.gd")
const Gen = preload("res://puzzles/minigolf_gen.gd")

func _initialize() -> void:
	var n := 40
	var aim := 0.06
	var pw := 0.14
	for a in OS.get_cmdline_user_args():
		if a.begins_with("n="): n = int(a.substr(2))
		elif a.begins_with("aim="): aim = float(a.substr(4))
		elif a.begins_with("pow="): pw = float(a.substr(4))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var bands: Array = Gen.bank()
	for band in bands.size():
		var pool: Array = bands[band]
		var putts := 0
		var near := [0, 0, 0]
		var sunk_bank := 0
		var sunk := 0
		var aces := 0
		var over := {}
		var holes := 0
		var slows: Array = []
		for h in mini(n, pool.size()):
			var base := Sim.new()
			base.setup(pool[h])
			for round in 3:
				var sim = base.clone()
				var k := 0
				while not sim.sunk and k < 9:
					var shot: Dictionary = sim.best_shot(48, 5, 1)
					sim.putt(float(shot.a) + rng.randfn(0.0, aim), clampf(float(shot.u) * (1.0 + rng.randfn(0.0, pw)), 0.03, 1.0))
					var slow_t := 0.0
					while sim.step():
						if not sim.sunk and not sim.wet and sim.p.distance_to(sim.cup) < 11.5 and sim.v.length() < 72.0:
							slow_t += Sim.DT
					var extra := slow_t * (1.0 / 0.4 - 1.0)
					if extra > 0.0:
						slows.append(extra)
					k += 1
					putts += 1
					if sim.sunk:
						sunk += 1
						if sim.hits > 0:
							sunk_bank += 1
					else:
						var dd: float = sim.p.distance_to(sim.cup)
						if dd < 6.0: near[0] += 1
						if dd < 9.0: near[1] += 1
						if dd < 12.0: near[2] += 1
				if k == 1:
					aces += 1
				var d: int = k - int(pool[h].get("par", 2))
				over[d] = int(over.get(d, 0)) + 1
				holes += 1
		print("band %d: %d holes played, %d putts; missed putts stopping <6/<9/<12 of the cup: %d/%d/%d (%.0f%%/%.0f%%/%.0f%% of misses); sunk %d, off a kerb %d (%.0f%%); aces %d; vs par %s; slowed putts %d, extra wall seconds median %.2f max %.2f" % [
			band, holes, putts, near[0], near[1], near[2], 100.0 * near[0] / maxf(1, putts - sunk), 100.0 * near[1] / maxf(1, putts - sunk),
			100.0 * near[2] / maxf(1, putts - sunk), sunk, sunk_bank, 100.0 * sunk_bank / maxf(1, sunk), aces, str(over), slows.size(), _median(slows), _max(slows)])
	quit()

static func _median(a: Array) -> float:
	if a.is_empty():
		return 0.0
	var b := a.duplicate()
	b.sort()
	return float(b[b.size() / 2])

static func _max(a: Array) -> float:
	var m := 0.0
	for x in a:
		m = maxf(m, float(x))
	return m
