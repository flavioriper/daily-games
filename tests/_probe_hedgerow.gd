extends SceneTree

## Plays Hedgerow TD's sim headless with a simple bot and prints how far it
## got: the wave, lives, gold, score and a tally of events, plus a line a
## wave. Run after touching arcade/hedgerow_sim.gd.
##   godot --headless --script tests/_probe_hedgerow.gd -- [seed] [skill] [picks]
## skill 2 plants round the path's bends and fuses duals, 1 the same with
## singles only, both on the best 26 cells; 0 plain towers on the best 14. picks is four
## letters of s h r e l t (sun shade rain ember leaf stone), default "sreh".

const Sim = preload("res://arcade/hedgerow_sim.gd")
const LETTERS := {"s": Sim.El.SUN, "h": Sim.El.SHADE, "r": Sim.El.RAIN, "e": Sim.El.EMBER, "l": Sim.El.LEAF, "t": Sim.El.STONE}

var skill := 2
var picks: Array = []
var walls: Array[Vector2i] = []

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var seed_v := int(args[0]) if args.size() > 0 else 7
	skill = int(args[1]) if args.size() > 1 else 2
	var letters := String(args[2]) if args.size() > 2 else "sreh"
	for ch in letters:
		picks.append(LETTERS[ch])
	_plan()
	var sim = Sim.new(seed_v)
	var tally := {}
	var t0 := Time.get_ticks_usec()
	var last_wave := 0
	var lives_at: int = sim.lives
	var guard := 0
	while not sim.is_over() and guard < 60 * 60 * 90:
		guard += 1
		_bot(sim)
		sim.step()
		for ev: Dictionary in sim.events:
			tally[ev.type] = int(tally.get(ev.type, 0)) + 1
			if ev.type == "clear":
				print("wave %2d cleared  lives %2d (-%d)  gold %5d  towers %2d  score %d" % [ev.wave, sim.lives, lives_at - sim.lives, sim.gold, sim.towers.size(), sim.score])
				lives_at = sim.lives
		sim.events.clear()
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	print("%s at wave %d, lives %d, score %d, kills %d, leaks %d, %.0f game s in %.0f ms" % [
		"WON" if sim.phase == Sim.Phase.WON else "over", sim.wave, sim.lives, sim.score, sim.kills, sim.leaks, sim.t, ms])
	var kinds := {}
	for tw: Dictionary in sim.towers:
		var k := "%s%d" % [tw.key, tw.level + 1]
		kinds[k] = int(kinds.get(k, 0)) + 1
	print("towers: ", kinds)
	print("events: ", tally)
	quit()

## The grass cells, best first: how much of the walk each covers within a
## thorn's reach. skill 0 plants only the best dozen, as a player who never
## looks past the first bends would.
func _plan() -> void:
	var probe = Sim.new(1)
	var line: PackedVector2Array = Sim.walk_line()
	var scored: Array = []
	for y in Sim.ROWS:
		for x in Sim.COLS:
			var c := Vector2i(x, y)
			if probe.build_block(c) != "":
				continue
			var n := 0
			for i in range(0, line.size(), 2):
				if Sim.centre(c).distance_to(line[i]) <= 2.4:
					n += 1
			scored.append([n, c])
	scored.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	var cap := 14 if skill == 0 else 26
	for i in mini(cap, scored.size()):
		walls.append(scored[i][1])

func _bot(sim) -> void:
	if sim.pick_pending:
		for e: int in picks:
			if not sim.picked.has(e):
				sim.pick(e)
				break
	var singles: Array = []
	for e: int in sim.picked:
		singles.append(Sim.EL_KEY[e])
	# fill the walls, element towers once they can be afforded
	for c: Vector2i in walls:
		if sim.at.has(c):
			continue
		var key := "thorn"
		if skill > 0 and not singles.is_empty() and sim.gold >= 100 and sim.wave >= 3:
			key = singles[(c.x + c.y) % singles.size()]
		if sim.gold >= Sim.TOWERS[key].cost[0]:
			sim.build(c, key)
		return
	# then make them better, the cheapest step first
	var best: Dictionary = {}
	var best_cost := 1 << 30
	var best_act := ""
	for tw: Dictionary in sim.towers:
		if tw.key == "thorn" and not singles.is_empty() and skill > 0:
			var cost: int = Sim.TOWERS[singles[tw.id % singles.size()]].cost[0]
			if cost < best_cost:
				best = tw; best_cost = cost; best_act = "swap"
		var up: int = sim.upgrade_cost(tw)
		# a plain tower is only worth upgrading when there is no element yet
		var weight := 3 if Sim.BASIC.has(tw.key) and not singles.is_empty() and skill > 0 else 1
		if up > 0 and up * weight < best_cost:
			best = tw; best_cost = up; best_act = "up"
		if skill >= 2:
			var f: Array = sim.fusions(tw)
			if not f.is_empty():
				var fc: int = Sim.TOWERS[f[0]].cost[0]
				if fc <= best_cost * 1.5:
					best = tw; best_cost = fc; best_act = "fuse"
	if best.is_empty() or sim.gold < best_cost + 40:
		return
	match best_act:
		"up":
			sim.upgrade(best)
		"fuse":
			var f: Array = sim.fusions(best)
			sim.fuse(best, f[best.id % f.size()])
		"swap":
			var c: Vector2i = best.cell
			sim.sell(best)
			sim.build(c, singles[best.id % singles.size()])
