extends SceneTree

## Mines Trestle's levels: deals a shape per band, proves it with a design
## found by pruning a full truss, and prints the survivors as JSON lines.
##
##     godot --headless --script res://tools/mine_trestle.gd -- <band> <count> [seed]
##
## For each shape it builds the full candidates (a truss one or two rows
## under the road, one over it, both), keeps those that get the cart over
## with every member under MARGIN of its limit, then prunes each: members are
## tried out most expensive first, and a wood member is tried as rope where
## rope is on offer, keeping every change that still proves. The cheapest
## result is the level's proof and its hints; the budget is its cost times
## the band's slack, rounded up to 100. A shape whose road alone gets over
## is thrown away (it never does: a bare deck cannot even hold itself up).
## Then `python3 tools/merge_trestle.py` gathers the bands' lines into
## content/trestle.json.

const Sim = preload("res://puzzles/trestle_sim.gd")
const Gen = preload("res://puzzles/trestle_gen.gd")

const MARGIN := 0.85

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var band := int(args[0])
	var count := int(args[1])
	var rng := RandomNumberGenerator.new()
	rng.seed = int(args[2]) if args.size() > 2 else 1000 + band
	var made := 0
	var tries := 0
	while made < count and tries < count * 6:
		tries += 1
		var level := deal(rng, band)
		var t0 := Time.get_ticks_msec()
		var best := prove(level, band)
		if best.is_empty():
			printerr("band %d try %d: no proof (%d ms)" % [band, tries, Time.get_ticks_msec() - t0])
			continue
		var cost := Sim.cost_of(best)
		var slack: float = Gen.BANDS[band].slack
		level.budget = int(ceil(cost * slack / 100.0)) * 100
		level.proof_cost = cost
		var rows: Array = []
		for d in best:
			rows.append([d.a.x, d.a.y, d.b.x, d.b.y, d.m])
		level.proof = rows
		level.band = band
		print(JSON.stringify(level))
		printerr("band %d #%d: w %d dy %d cost %d budget %d members %d (%d ms)" % [
			band, made, level.w, level.dy, cost, level.budget, best.size(), Time.get_ticks_msec() - t0])
		made += 1
	quit()

static func deal(rng: RandomNumberGenerator, band: int) -> Dictionary:
	var b: Dictionary = Gen.BANDS[band]
	var w: int = b.w[rng.randi() % b.w.size()]
	var dy: int = b.dy[rng.randi() % b.dy.size()]
	var anchors: Array = [[0, 0], [w, dy]]
	# cliff pins: each side gets zero to two, never above the road
	for side in 2:
		var x := 0 if side == 0 else w
		var top := 0 if side == 0 else dy
		var n := rng.randi_range(0 if band >= 2 else 1, 2)
		var rows := [1, 2, 3]
		for i in n:
			var k := rng.randi() % rows.size()
			anchors.append([x, top - int(rows[k])])
			rows.remove_at(k)
	# bank posts, for rope, from Medium
	if band >= 1 and rng.randf() < 0.5:
		var hgt := rng.randi_range(2, 3)
		anchors.append([-1, hgt])
		anchors.append([w + 1, dy + hgt])
	var level := {"w": w, "dy": dy, "cart": b.cart, "anchors": anchors, "mats": b.mats}
	# a rock in the river on the wide gaps, sometimes
	if w >= 10 or (w >= 7 and rng.randf() < 0.55):
		var x := w / 2 + rng.randi_range(-1, 1)
		var top := -rng.randi_range(1, 2)
		level.rock = [x, top]
		anchors.append([x, top])
	return level

static func prove(level: Dictionary, band: int) -> Array:
	if Gen.proves(level, Gen.plain_deck(level)):
		return []
	var rope: bool = level.mats.has(Sim.ROPE)
	var best: Array = []
	var best_cost := 1 << 30
	# every full candidate that holds, cheapest first; the two cheapest are
	# pruned (pruning is the slow part: a run a member, several passes)
	var holds: Array = []
	for shape in [[1, 0], [2, 0], [0, 1], [1, 1], [2, 1]]:
		for diag in 3:
			var cand := Gen.full(level, shape[0], shape[1], diag)
			if Gen.proves(level, cand, MARGIN):
				holds.append(cand)
	holds.sort_custom(func(a: Array, b: Array) -> bool: return Sim.cost_of(a) < Sim.cost_of(b))
	for cand in holds.slice(0, 2):
		var design := prune(level, cand, rope)
		var c := Sim.cost_of(design)
		if c < best_cost:
			best_cost = c
			best = design
	return best

static func prune(level: Dictionary, design: Array, rope: bool) -> Array:
	var d := design.duplicate()
	var changed := true
	while changed:
		changed = false
		var order := range(d.size())
		order.sort_custom(func(i: int, j: int) -> bool:
			return Sim.member_cost(d[i].a, d[i].b, d[i].m) > Sim.member_cost(d[j].a, d[j].b, d[j].m))
		var gone := {}
		for i in order:
			if d[i].m == Sim.ROAD:
				continue
			var trial: Array = []
			for k in d.size():
				if k != i and not gone.has(k):
					trial.append(d[k])
			if Gen.proves(level, trial, MARGIN):
				gone[i] = true
				changed = true
		if not gone.is_empty():
			var kept: Array = []
			for k in d.size():
				if not gone.has(k):
					kept.append(d[k])
			d = kept
	if rope:
		for i in d.size():
			if d[i].m != Sim.WOOD:
				continue
			var was: int = d[i].m
			d[i] = {"a": d[i].a, "b": d[i].b, "m": Sim.ROPE}
			if not Gen.proves(level, d, MARGIN):
				d[i] = {"a": d[i].a, "b": d[i].b, "m": was}
	return d
