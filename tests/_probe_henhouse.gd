extends SceneTree

## Plays Henhouse's sim headless with a bot and prints how long it took to
## retire, what it bought when, and a tally of events. Run after touching
## arcade/henhouse_sim.gd.
##   godot --headless --script tests/_probe_henhouse.gd -- [seed] [skill 0..2]
## The bot has one finger: it drags eggs (to the crate, or to the belt once
## it has one) or strokes the least happy hen, at a human's pace; `skill` 0
## drags slowly and never strokes, 2 is quick and strokes whenever idle. It
## refills a trough when it runs low, buys greedily down a list, lets chicks
## sleep while the troughs are dear, and retires the moment it can.

const Sim = preload("res://arcade/henhouse_sim.gd")
const PLAN := ["belt", "hen", "washer", "basket", "auto_water", "auto_feed", "squirrel", "radio",
	"feed", "stamp", "rooster", "packer"]

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var seed_v := int(args[0]) if args.size() > 0 else 7
	var skill := int(args[1]) if args.size() > 1 else 1
	var sim = Sim.new(seed_v)
	var tally := {}
	var busy := 0.0
	var drag_time: float = [1.3, 0.9, 0.6][skill]
	var bought: Array = []
	var guard := 0
	var marks := {}
	while not sim.is_over() and guard < 30 * 60 * 40:
		guard += 1
		busy -= Sim.DT
		if sim.phase == Sim.Phase.PLAY:
			# troughs and shopping take no finger time worth counting
			for which in ["feed", "water"]:
				var lv: float = sim.feed if which == "feed" else sim.water
				if lv < sim.cap() * 0.3 and not sim.has("auto_" + which):
					sim.refill(which)
			if sim.money >= Sim.RETIRE:
				sim.buy("retire")
			for item: String in PLAN:
				var p: int = sim.price(item)
				if p < 0:
					continue
				# keep a float for the troughs
				if sim.money >= p + 20 and (item != "hen" or p < sim.money * 0.6):
					if sim.buy(item):
						bought.append("%s@%d" % [item, int(sim.t)])
					break
			if busy <= 0.0:
				var ground: Array = sim.eggs.filter(func(e: Dictionary) -> bool: return e.st == Sim.Egg.GROUND and not (e.fertile and sim.flock() < Sim.MAX_FLOCK))
				var need_drag: bool = ground.size() > (2 if not sim.has("squirrel") else 10)
				if need_drag:
					var e: Dictionary = ground[0]
					var ids: Array = sim.grab(e.pos)
					var to: Vector2 = Vector2(40, Sim.BELT_Y) if sim.has("belt") else sim.CRATE.get_center()
					sim.release(ids, to)
					busy = drag_time
				elif skill > 0:
					var low := {}
					for h: Dictionary in sim.hens:
						if h.kind == Sim.Kind.HEN and (low.is_empty() or h.happy < low.happy):
							low = h
					if not low.is_empty():
						sim.pet(low.pos + Vector2(0, -8), 12.0 if skill == 2 else 7.0)
		sim.step()
		for m in [100, 1000, 10000, 100000]:
			if sim.earned >= m and not marks.has(m):
				marks[m] = int(sim.t)
		for ev: Dictionary in sim.events:
			tally[ev.type] = int(tally.get(ev.type, 0)) + 1
		sim.events.clear()
	print("seed %d skill %d: %s at %d:%02d  earned %d  money %d  flock %d (best %d)  sold %d  golds %d  hatched %d  lost %d" % [
		seed_v, skill, "RETIRED" if sim.won else "stopped", int(sim.t) / 60, int(sim.t) % 60, int(sim.earned), int(sim.money),
		sim.flock(), sim.best_flock, sim.sold, sim.golds, sim.hatched, sim.lost])
	print("earned marks (s): ", marks)
	print(" ".join(bought))
	print(tally)
	quit()
