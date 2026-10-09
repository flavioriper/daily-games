extends SceneTree

## A finger leading the bottom mallet up into a puck at rest, its place read
## `hz` times a second as a phone reads it: how fast does the puck leave for
## how fast the finger went? godot --headless --path . --script tests/_probe_hockey_touch.gd

const Sim := preload("res://versus/hockey_sim.gd")

func _initialize() -> void:
	for hz in [60, 120]:
		print("finger read at %d Hz" % hz)
		for v in [0.1, 0.2, 0.3, 0.5, 0.8, 1.2, 2.0, 3.0, 5.0]:
			var lo := INF
			var hi := 0.0
			# the read's phase against the sim's step changes which step strikes
			for phase in 8:
				var out := _push(v, hz, phase / 8.0)
				lo = minf(lo, out)
				hi = maxf(hi, out)
			print("  finger %.1f m/s -> puck %.2f to %.2f m/s (x%.1f)" % [v, lo, hi, hi / v])
	quit()

func _push(v: float, hz: int, phase: float) -> float:
	var sim := Sim.new()
	sim.reset(0)
	var start := Vector2(0.5, 1.45)
	sim.mallet[0] = start
	sim.aim[0] = start
	var t := 0.0
	var next := phase / hz
	var best := 0.0
	while t < 3.0:
		if t >= next:
			next += 1.0 / hz
			sim.aim[0] = start + Vector2(0.0, -v * t)
		sim.step()
		t += Sim.DT
		best = maxf(best, sim.puck_vel.length())
		if sim.puck.y < 0.9:
			break
	return best
