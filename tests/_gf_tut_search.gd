extends SceneTree

## Finds the putts ui/hud/minigolf_tutorial_diagram.gd plays on its
## hand-made holes, and prints them as the constants that file holds:
##
##     godot --headless --script res://tests/_gf_tut_search.gd
##
## The physics is pure data at a fixed step, so a putt plays the same every
## time; each one printed is checked steady (it still does its job a little
## off). Re-run it when the physics or the page's holes change.

const Sim = preload("res://puzzles/minigolf_sim.gd")

func _initialize() -> void:
	var D = load("res://ui/hud/minigolf_tutorial_diagram.gd")
	var holes: Dictionary = D.HOLES
	# the putt and the bank: straight along the lane, the middle of the
	# widest run of powers that drop
	for name: String in ["putt", "bank"]:
		var sim := Sim.new()
		sim.setup(holes[name])
		var run_from := -1
		var best := Vector2i(0, -1)
		for ui in range(5, 102):
			var ok := false
			if ui <= 100:
				var c = sim.clone()
				c.putt(0.0, float(ui) * 0.01)
				c.run()
				ok = c.sunk
			if ok and run_from < 0:
				run_from = ui
			elif not ok and run_from >= 0:
				if ui - run_from > best.y - best.x:
					best = Vector2i(run_from, ui)
				run_from = -1
		var u := float(best.x + best.y - 1) * 0.005
		print("%s: [0.0, %.3f] (powers %d to %d drop) steady %d" % [name, u, best.x, best.y - 1, sim.steady(0.0, u)])
	# the card: along the lane to the corner, then the steady putt
	_two(holes["card"], "card", 0, func(c) -> bool: return c.p.x > 46.0 and c.p.x < 54.0 and absf(c.p.y - 49.0) < 3.0 and c.hits == 0)
	# sand: into the sand (off the post if one will have it), then out
	_two(holes["sand"], "sand", 0, func(c) -> bool: return c.in_sand_at(c.p))
	# water: into the pond, then round it
	_two(holes["water"], "water", 1, func(c) -> bool: return c.wet)
	# gates: a tap up to the shut gate, then through
	_two(holes["gates"], "gates", 0, func(c) -> bool: return c.p.x > 30.0 and c.p.x < 38.0 and c.hits == 0)
	quit()

## A first putt along the lane that leaves the ball where `want` says, the
## steadiest of them, then the steady putt from there off `banks` kerbs at
## most.
func _two(hole: Dictionary, name: String, banks: int, want: Callable) -> void:
	var sim := Sim.new()
	sim.setup(hole)
	var best := []
	var top := -1
	for ai in range(-12, 13):
		var a := float(ai) * 0.02
		for ui in range(3, 100):
			var u := float(ui) * 0.01
			var c = sim.clone()
			c.putt(a, u)
			c.run()
			if c.sunk or not want.call(c):
				continue
			var n := 0
			for q: Vector2 in Sim.OFF:
				var d = sim.clone()
				d.putt(a + q.x, u + q.y)
				d.run()
				if not d.sunk and want.call(d):
					n += 1
			# of the steadiest, the straightest
			var score := n * 100 - absi(ai)
			if score > top:
				top = score
				best = [a, u]
	if best.is_empty():
		print("%s: no first putt" % name)
		return
	sim.putt(best[0], best[1])
	sim.run()
	var shot: Dictionary = sim.best_shot(180, 9, banks)
	print("%s: [%.4f, %.3f] (steady %d, rests %s wet %s) then [%.4f, %.3f] sunk %s steady %d" % [name, best[0], best[1],
		top / 100, sim.p, sim.wet, shot.a, shot.u, shot.sunk, sim.steady(shot.a, shot.u)])
