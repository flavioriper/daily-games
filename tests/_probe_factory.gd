extends SceneTree

## Factory's sim, headless: the rules first, then a crude player to say how
## slow the first plate is.
##
##     godot --headless --path . --script res://tests/_probe_factory.gd
##     godot --headless --path . --script res://tests/_probe_factory.gd -- pace [first seed] [lands]
##
## The checks (the spec's section 12): a tap fells a tree after three bites
## and a log lies beside it; a belt carries it; the market sells at its rate
## and no faster; two feeders alternate; a full belt waits and nothing is
## lost; a firebox banked and one under a working kiln last what the ledger's
## formula says; a kiln and a retort on one fire run at a half each; a module
## sold returns its price and its items lie; a save reads back as the same
## land and plays on the same; no time stepped changes nothing; plate prices;
## a stump is a tree again in 240 s.
##
## The ledger's headline times are rounded and the checks are not: a kiln is
## 55 MJ at 60 kW, 2291.7 ticks (229.2 s, the ledger's "3 min 50 s"); a retort
## 1333.3 ticks (133.3 s, its "2 min 15 s"); a log banked 66666.7 ticks
## (1 h 51 min), under a working kiln 13333.3 (22 min). Each is held to the
## formula within a couple of ticks.
##
## `pace` plays new lands with a player who taps every tree that stands, lays
## the shortest belt from any log lying to the market or to a belt already
## going there, and buys a plate the moment the coins reach; it prints the
## play-minute of the second plate. Everything runs on a throwaway file.

const Sim = preload("res://factory/sim.gd")

var _fails := 0
var _checks := 0
var _frames := 0
var _done := false

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 2 or _done:
		return _done
	_done = true
	Sim.path = OS.get_user_data_dir() + "/_probe_factory.cfg"
	DirAccess.remove_absolute(Sim.path)
	var args := OS.get_cmdline_user_args()
	if args.has("pace"):
		_pace(int(args[1]) if args.size() > 1 else 1, int(args[2]) if args.size() > 2 else 5)
	else:
		_check_land()
		_check_chop()
		_check_belts()
		_check_feeders()
		_check_plates_and_rocks()
		_check_fire()
		_check_kiln()
		_check_shared()
		_check_sell()
		_check_kept()
		print("probe_factory: %d checks, %d failed" % [_checks, _fails])
	DirAccess.remove_absolute(Sim.path)
	quit(1 if _fails > 0 else 0)
	return true

func _ok(what: String, yes: bool) -> void:
	_checks += 1
	if not yes:
		_fails += 1
		print("FAIL ", what)

## One tick, and what it said.
func _tick(sim: RefCounted) -> Array:
	sim.events.clear()
	sim.step(Sim.TICK)
	return sim.events.duplicate()

func _run(sim: RefCounted, ticks: int) -> void:
	for i in ticks:
		sim.step(Sim.TICK)
	sim.events.clear()

## Ticks until an event of `type` (returned in `found`), or -1 past `most`.
func _until(sim: RefCounted, type: String, most: int, found: Array = []) -> int:
	for i in most:
		for e: Dictionary in _tick(sim):
			if e.type == type:
				found.append(e)
				return i + 1
	return -1

## Every item the land holds: lying, riding, waiting on the counter, in a
## machine or in a hopper.
func _all(sim: RefCounted) -> int:
	var n: int = sim.market.wait.size()
	for t: Vector2i in sim.items:
		n += sim.items[t].size()
	for id: int in sim.modules:
		var m: Dictionary = sim.modules[id]
		if m.kind == "firebox":
			n += m.hopper.size()
		else:
			n += (1 if m.inp != "" else 0) + (1 if m.out != "" else 0)
	return n

func _lying(sim: RefCounted, tile: Vector2i) -> int:
	return sim.items[tile].size() if sim.items.has(tile) else 0

## A land with a meadow to the +x of the first plate (tiles 8..15 across,
## nothing standing on it) and coins to build with.
func _meadow() -> RefCounted:
	var sim: RefCounted = Sim.new(7)
	sim.coins = 100000
	sim.buy_plate(Vector2i(1, 0), "meadow")
	sim.events.clear()
	return sim

func _belt_row(sim: RefCounted, from: Vector2i, n: int, facing: int) -> void:
	for i in n:
		sim.lay_belt(from + Sim.DIRS[facing] * i, facing)

func _refused(sim: RefCounted, why: String) -> bool:
	var e: Dictionary = sim.events.back() if not sim.events.is_empty() else {}
	return e.get("type", "") == "refused" and e.get("why", "") == why

# --- the checks ---

func _check_land() -> void:
	var sim: RefCounted = Sim.new(7)
	_ok("a new land has twenty coins and one forest plate", sim.coins == 20 and sim.earned == 0 and sim.plates == {Vector2i.ZERO: "forest"})
	_ok("six trees on it", sim.trees.size() == 6)
	var inside := true
	for id: int in sim.trees:
		var t: Vector2i = sim.trees[id].tile
		inside = inside and t.x >= 1 and t.x <= 6 and t.y >= 1 and t.y <= 6 and not sim.is_market(t) \
			and int(sim.trees[id].look) >= 0 and int(sim.trees[id].look) <= 3
	_ok("each inside the edge, off the market, with a look", inside)
	_ok("four free edges", sim.free_edges() == [Vector2i(-1, 0), Vector2i(0, -1), Vector2i(0, 1), Vector2i(1, 0)])
	_ok("a tile across the back seam is on the plate behind", Sim.plate_of(Vector2i(-1, 0)) == Vector2i(-1, 0) and Sim.plate_of(Vector2i(7, -8)) == Vector2i(0, -1))
	_ok("the belt is in the drawer and the fire is not", sim.unlocked("belt") and not sim.unlocked("kiln") and not sim.can_place("firebox", Vector2i(0, 0), 0))
	_ok("the market is its 2x2 and cannot be sold or built on", sim.is_market(Vector2i(6, 6)) and sim.is_market(Vector2i(7, 7)) and not sim.is_market(Vector2i(5, 7))
		and not sim.sell(Vector2i(7, 7)) and not sim.can_lay(Vector2i(6, 7)) and not sim.can_lay(Vector2i(8, 0)))
	var same: RefCounted = Sim.new(7)
	var other: RefCounted = Sim.new(8)
	_ok("a seed is a land", var_to_str(sim.pack()) == var_to_str(same.pack()) and var_to_str(sim.pack()) != var_to_str(other.pack()))
	sim.coins = 100000
	_ok("the market's levels cost 30, 80, 200, 500, 1250", sim.upgrade_price("market") == 30 and sim.upgrade(Vector2i(6, 6)) and sim.upgrade_price("market") == 80
		and sim.upgrade("market") and sim.upgrade_price("market") == 200 and sim.upgrade("market") and sim.upgrade_price("market") == 500
		and sim.upgrade("market") and sim.upgrade_price("market") == 1250 and sim.coins == 100000 - 810)
	sim.upgrade("market")
	sim.upgrade("market")
	_ok("and past a sale a second each halves it", int(sim.market.level) == 7 and is_equal_approx(sim.market_interval(), 0.125))
	var first: RefCounted = Sim.new(7)
	_ok("a new market sells every four seconds", is_equal_approx(first.market_interval(), 4.0))
	var found: Array = []
	var at := _until(first, "grew", 1000, found)
	_ok("a seventh tree comes up at ninety seconds", at == 900 and found[0].sprout and first.trees.size() == 7)
	_run(first, 3 * 900 + 5)
	_ok("and they stop at ten a plate", first.trees.size() == 10)
	_run(first, 2000)
	_ok("for good", first.trees.size() == 10)

func _check_chop() -> void:
	var sim: RefCounted = Sim.new(7)
	var ids: Array = sim.trees.keys()
	var tr: Dictionary = sim.trees[ids[0]]
	var tile: Vector2i = tr.tile
	_ok("a tap on bare ground does nothing", not sim.tap(Vector2i(0, 0)) and _refused(sim, "nothing"))
	_ok("a tap on a tree calls a beaver", sim.tap(tile) and tr.state == "bitten")
	_ok("a second tap does nothing", not sim.tap(tile) and _refused(sim, "busy"))
	var hits := 0
	var fell_at := -1
	var log_at := -1
	var lies := Sim.NONE
	for i in 60:
		for e: Dictionary in _tick(sim):
			if e.type == "hit":
				hits += 1
			elif e.type == "fell":
				fell_at = i + 1
			elif e.type == "log":
				log_at = i + 1
				lies = e.tile
	_ok("two bites, down on the third at 2.4 s", hits == 2 and fell_at == 24)
	_ok("the log on the ground 0.9 s after", log_at == 33)
	var d := lies - tile
	_ok("it lies on a tile beside the stump", absi(d.x) + absi(d.y) == 1 and _lying(sim, lies) == 1 and sim.items[lies][0].kind == "log" and _lying(sim, tile) == 0)
	_ok("a stump is left, and a tap on it does nothing", tr.state == "stump" and not sim.tap(tile))
	_run(sim, 2400 - 36 - 2)
	_ok("still a stump two ticks short of 240 s", tr.state == "stump")
	_run(sim, 3)
	_ok("and a tree again at 240 s", tr.state == "standing")
	_ok("the log lay where it was all that time", _lying(sim, lies) == 1 and sim.coins == 20)

	# three beavers a plate; the fourth tap waits its turn
	sim = Sim.new(7)
	ids = sim.trees.keys()
	for i in 4:
		_ok("tap %d is taken" % (i + 1), sim.tap(sim.trees[ids[i]].tile))
	var biting := 0
	for id: int in sim.trees:
		biting += 1 if sim.trees[id].state == "bitten" else 0
	_ok("three beavers and one tree waiting", biting == 3 and sim.trees[ids[3]].state == "standing" and sim.trees[ids[3]].queued)
	_run(sim, 24)
	_ok("the fourth is bitten as the first comes down", sim.trees[ids[3]].state == "bitten")
	_run(sim, 40)
	_ok("four logs lie", _all(sim) == 4)

	# a belt beside the tree takes the log before bare ground does
	sim = Sim.new(7)
	ids = sim.trees.keys()
	tile = sim.trees[ids[0]].tile
	var beside := Sim.NONE
	for q in 4:
		# the last place bare ground would be tried
		var n: Vector2i = tile + Sim.DIRS[(sim._to_market(tile) + 3 - q) % 4]
		if sim.can_lay(n) and sim.tree_at(n).is_empty():
			beside = n
			break
	sim.lay_belt(beside, 0)
	sim.tap(tile)
	_run(sim, 34)
	_ok("a belt beside the tree takes its log", _lying(sim, beside) == 1 and sim.coins == 19)

func _check_belts() -> void:
	var sim: RefCounted = Sim.new(7)
	# the front rim of the first plate: six tiles running into the market
	_ok("a belt can be laid on the rim", sim.can_lay(Vector2i(0, 7)))
	_belt_row(sim, Vector2i(0, 7), 6, 0)
	_ok("six belts are six coins", sim.coins == 14 and sim.belts.size() == 6)
	_ok("the same belt twice is not paid twice", not sim.lay_belt(Vector2i(0, 7), 0) and sim.coins == 14)
	_ok("a tap turns it a quarter, and again", sim.turn(Vector2i(0, 7)) and sim.belts[Vector2i(0, 7)] == 1 and sim.lay_belt(Vector2i(0, 7), 0) and sim.coins == 14)
	sim.put(Vector2i(0, 7), "log")
	var sale := -1
	var before: float = sim.items[Vector2i(0, 7)][0].at
	_tick(sim)
	_ok("an item rides a twentieth of a tile a tick", is_equal_approx(sim.items[Vector2i(0, 7)][0].at - before, 0.05))
	sim.step(0.05)
	var half: Vector2 = sim.item_pos(Vector2i(0, 7), sim.items[Vector2i(0, 7)][0])
	_ok("and is drawn a tick behind, half way between the last two", is_equal_approx(sim.alpha, 0.5) and is_equal_approx(half.x, 0.5 + 0.025) and is_equal_approx(half.y, 7.5))
	sim.step(0.05)
	for i in 200:
		for e: Dictionary in _tick(sim):
			if e.type == "sale":
				sale = i + 3
	# from mid tile to the market's edge is five tiles and a half, 11 s
	_ok("five and a half tiles to the market in 11 s, sold as it lands", sale >= 110 and sale <= 112)
	_ok("a log is a coin", sim.coins == 15 and sim.earned == 1 and _all(sim) == 0)

	# a full belt: twelve logs, a market that takes one every four seconds
	for x in 6:
		_ok("a tile takes two", sim.put(Vector2i(x, 7), "log") and sim.put(Vector2i(x, 7), "log") and not sim.put(Vector2i(x, 7), "log"))
	var sold := 0
	var last := -1000
	var nearest := 1000
	var lost := false
	var close := false
	var stuck := false
	for i in 600:
		for e: Dictionary in _tick(sim):
			if e.type == "sale":
				if sold > 0:
					nearest = mini(nearest, i - last)
				last = i
				sold += 1
		lost = lost or _all(sim) + sold != 12
		for t: Vector2i in sim.items:
			var arr: Array = sim.items[t]
			close = close or (arr.size() == 2 and arr[0].at - arr[1].at < 0.5 - 0.0001) or arr.size() > 2
		if i == 150:
			# the counter is full and the belt behind it waits
			stuck = sim.market.wait.size() == 6 and sim.items[Vector2i(5, 7)][0].at == 1.0
	_ok("the counter fills to six and the belt behind waits", stuck)
	_ok("nothing is lost on a full belt", not lost)
	_ok("no two items nearer than half a tile", not close)
	_ok("never two sales in under four seconds", nearest >= 40)
	_ok("twelve sold in the end, a coin each", sold == 12 and sim.coins == 27 and _all(sim) == 0)
	_ok("which took the market's rate, not the belt's", last >= 11 * 40 - 5)

	# a belt with nothing ahead holds at its end; one into the pond too
	sim = _meadow()
	_belt_row(sim, Vector2i(8, 7), 8, 0)
	sim.put(Vector2i(8, 7), "stone")
	sim.put(Vector2i(8, 7), "log")
	_run(sim, 400)
	_ok("a belt into the pond holds its items at its end", _lying(sim, Vector2i(15, 7)) == 2 and sim.items[Vector2i(15, 7)][0].at == 1.0
		and is_equal_approx(sim.items[Vector2i(15, 7)][1].at, 0.5) and sim.items[Vector2i(15, 7)][0].kind == "stone")
	# a ring of belts goes round and neither hangs nor loses
	sim = _meadow()
	sim.lay_belt(Vector2i(9, 1), 0)
	sim.lay_belt(Vector2i(10, 1), 1)
	sim.lay_belt(Vector2i(10, 2), 2)
	sim.lay_belt(Vector2i(9, 2), 3)
	sim.put(Vector2i(9, 1), "log")
	_run(sim, 80)
	_ok("a ring of belts carries its item round", _all(sim) == 1 and _lying(sim, Vector2i(9, 1)) == 1)
	# an item on bare ground stays; a belt laid under it takes it
	sim = _meadow()
	sim.put(Vector2i(9, 5), "log")
	_run(sim, 100)
	_ok("an item on bare ground does not move", _lying(sim, Vector2i(9, 5)) == 1)
	sim.lay_belt(Vector2i(9, 5), 0)
	sim.lay_belt(Vector2i(10, 5), 0)
	_run(sim, 30)
	_ok("a belt laid under it carries it off", _lying(sim, Vector2i(9, 5)) == 0 and _lying(sim, Vector2i(10, 5)) == 1)

func _check_feeders() -> void:
	var sim := _meadow()
	# a line of six from (10,3) into the pond, fed from behind and from a side
	_belt_row(sim, Vector2i(10, 3), 6, 0)
	_belt_row(sim, Vector2i(8, 3), 2, 0)
	_belt_row(sim, Vector2i(10, 1), 2, 1)
	for t: Vector2i in [Vector2i(9, 3), Vector2i(8, 3)]:
		sim.put(t, "log")
		sim.put(t, "log")
	for t: Vector2i in [Vector2i(10, 2), Vector2i(10, 1)]:
		sim.put(t, "stone")
		sim.put(t, "stone")
	var seen := {}
	var order := ""
	var lost := false
	for i in 500:
		_tick(sim)
		for it: Dictionary in sim.items.get(Vector2i(10, 3), []):
			if not seen.has(it.id):
				seen[it.id] = true
				order += "L" if it.kind == "log" else "S"
		lost = lost or _all(sim) != 8
	_ok("two feeders take turns (%s)" % order, order == "LSLSLSLS" or order == "SLSLSLSL")
	_ok("and all eight are on the line, none lost", not lost and _all(sim) == 8 and _lying(sim, Vector2i(15, 3)) == 2 and _lying(sim, Vector2i(12, 3)) == 2)
	_ok("the feeders are empty", _lying(sim, Vector2i(9, 3)) == 0 and _lying(sim, Vector2i(10, 2)) == 0)

func _check_plates_and_rocks() -> void:
	var sim: RefCounted = Sim.new(7)
	_ok("the second plate is 50 and twenty coins do not reach", sim.plate_price() == 50 and not sim.buy_plate(Vector2i(1, 0), "quarry") and _refused(sim, "coins"))
	sim.coins = 100000
	_ok("a plate off the board's edge is refused, and a kind there is none of", not sim.buy_plate(Vector2i(2, 0), "forest") and not sim.buy_plate(Vector2i(1, 0), "swamp") and not sim.buy_plate(Vector2i(0, 0), "forest"))
	_ok("a quarry is bought for 50", sim.buy_plate(Vector2i(1, 0), "quarry") and sim.coins == 100000 - 50 and sim.plates[Vector2i(1, 0)] == "quarry")
	_ok("the fire is in the drawer from the second plate", sim.unlocked("firebox") and sim.unlocked("kiln") and sim.unlocked("retort"))
	_ok("the third is 150", sim.plate_price() == 150 and sim.buy_plate(Vector2i(-1, 0), "forest") and sim.coins == 100000 - 200)
	_ok("the fourth 450, the fifth 1350", sim.plate_price() == 450 and sim.buy_plate(Vector2i(0, -1), "meadow") and sim.plate_price() == 1350)
	var on := {}
	for id: int in sim.trees:
		var p: Vector2i = Sim.plate_of(sim.trees[id].tile)
		on[p] = int(on.get(p, 0)) + 1
	_ok("a new forest has six trees, behind the first plate", on.get(Vector2i(-1, 0), 0) == 6 and on.get(Vector2i(0, 0), 0) == 6 and on.size() == 2)
	_ok("a quarry three rocks, a meadow nothing", sim.rocks.size() == 3)
	var rock: Vector2i = sim.rocks.keys()[0]
	_ok("the rocks stand on the quarry", Sim.plate_of(rock) == Vector2i(1, 0) and sim.rocks[rock].ready)
	sim.events.clear()
	_ok("a tap chips a stone", sim.tap(rock) and sim.events[0].type == "chip")
	var to: Vector2i = sim.events[0].to
	_ok("which lies beside the rock", absi((to - rock).x) + absi((to - rock).y) == 1 and sim.items[to][0].kind == "stone")
	_ok("a second tap only wobbles", not sim.tap(rock) and _refused(sim, "wait"))
	_run(sim, 1798)
	_ok("not ready two ticks short of three minutes", not sim.rocks[rock].ready and not sim.tap(rock))
	_run(sim, 3)
	_ok("ready at three", sim.rocks[rock].ready and sim.tap(rock) and _all(sim) == 2)
	_ok("a belt is not laid on a rock or a standing tree", not sim.can_lay(rock) and not sim.can_lay(sim.trees[sim.trees.keys()[0]].tile))
	# a belt on a stump clears the tree for good
	var tr: Dictionary = sim.trees[sim.trees.keys()[0]]
	var n: int = sim.trees.size()
	sim.tap(tr.tile)
	_run(sim, 40)
	_ok("a belt laid on a stump takes the tree for good", tr.state == "stump" and sim.lay_belt(tr.tile, 0) and sim.trees.size() == n - 1 and sim.tree_at(tr.tile).is_empty())

func _check_fire() -> void:
	var sim := _meadow()
	var fire_at := Vector2i(10, 3)
	_ok("a firebox is 20", sim.price("firebox") == 20 and sim.place("firebox", fire_at, 0) and sim.coins == 100000 - 50 - 20)
	var fire: Dictionary = sim.module_at(fire_at)
	_ok("it is being built, and a tap waits", not fire.built and not sim.tap(fire_at) and not sim.can_place("firebox", fire_at, 0) and not sim.can_lay(fire_at))
	sim.lay_belt(Vector2i(10, 2), 1)
	sim.put(Vector2i(10, 2), "stone")
	sim.events.clear()
	_ok("built in 20 s", _until(sim, "built", 300) == 200 and fire.built and is_equal_approx(fire.build, 1.0))
	_run(sim, 30)
	_ok("a stone is no fuel and waits at the belt's end", fire.hopper.is_empty() and sim.items[Vector2i(10, 2)][0].at == 1.0)
	sim.sell(Vector2i(10, 2))
	_ok("a belt sold leaves its item lying", _lying(sim, Vector2i(10, 2)) == 1 and not sim.belts.has(Vector2i(10, 2)))
	# seven logs down a belt from the other side: five in the hopper, two wait
	_belt_row(sim, Vector2i(10, 7), 4, 3)
	for t: Vector2i in [Vector2i(10, 7), Vector2i(10, 6), Vector2i(10, 5), Vector2i(10, 4)]:
		sim.put(t, "log")
		if t.y != 4:
			sim.put(t, "log")
	_run(sim, 200)
	_ok("the hopper takes five and the belt holds the rest", fire.hopper.size() == 5 and _lying(sim, Vector2i(10, 4)) == 2 and _all(sim) == 8)
	_ok("an unlit fire draws nothing", not fire.lit and fire.draw == 0.0)
	_ok("a tap lights one", sim.tap(fire_at) and fire.lit and fire.fuel_kind == "log" and is_equal_approx(sim.fuel_left(fire), 1.0))
	_ok("a tap on a lit fire does nothing", not sim.tap(fire_at) and _refused(sim, "lit"))
	_tick(sim)
	_ok("banked it draws 12 kW of its 60", is_equal_approx(fire.draw, 12.0) and is_equal_approx(fire.cap, 60.0))
	# the ledger, section 7: a log is 320 MJ, banked at 12 kW, 0.4 game seconds
	# a tick: 320000 / 4.8 = 66666.7 ticks, 1 h 51 min of play
	var ticks := 1 + _until(sim, "dim", 70000)
	_ok("a log banked lasts 66667 ticks, 1 h 51 min (%d)" % ticks, absi(ticks - 66667) <= 1)
	_ok("then the fire is out and waits for a tap", not fire.lit and fire.hopper.size() == 5 and sim.fuel_left(fire) == 0.0)
	_run(sim, 100)
	_ok("and does not light itself", not fire.lit)
	# charcoal: 150 MJ
	var coal := _meadow()
	coal.place("firebox", fire_at, 0)
	coal.lay_belt(Vector2i(10, 2), 1)
	coal.put(Vector2i(10, 2), "charcoal")
	_run(coal, 240)
	coal.tap(fire_at)
	ticks = _until(coal, "dim", 40000)
	_ok("a charcoal banked lasts 31250 ticks, 52 min (%d)" % ticks, absi(ticks - 31250) <= 1)
	_ok("an empty firebox does not light", not coal.tap(fire_at) and _refused(coal, "empty"))

func _check_kiln() -> void:
	var sim := _meadow()
	var fire_at := Vector2i(10, 3)
	sim.place("firebox", fire_at, 0)
	var coins: int = sim.coins
	_ok("a kiln is 40 and stands on two tiles", sim.place("kiln", Vector2i(9, 4), 0) and sim.coins == coins - 40)
	var kiln: Dictionary = sim.module_at(Vector2i(10, 4))
	var fire: Dictionary = sim.module_at(fire_at)
	_ok("back at its root, front ahead, output past it", kiln.root == Vector2i(9, 4) and sim.front_of(kiln) == Vector2i(10, 4) and sim.out_tile(kiln) == Vector2i(11, 4)
		and sim.module_at(Vector2i(9, 4)) == kiln)
	_ok("nothing is built over it", not sim.can_place("retort", Vector2i(8, 4), 0) and sim.can_place("retort", Vector2i(8, 4), 1) and not sim.can_lay(Vector2i(9, 4)))
	# stones down the plate's back column and into the kiln's back
	_belt_row(sim, Vector2i(8, 0), 4, 1)
	sim.lay_belt(Vector2i(8, 4), 0)
	for y in 5:
		sim.put(Vector2i(8, y), "stone")
		sim.put(Vector2i(8, y), "stone")
	_belt_row(sim, Vector2i(11, 4), 5, 0)
	sim.lay_belt(Vector2i(10, 2), 1)
	sim.put(Vector2i(10, 2), "log")
	sim.put(Vector2i(10, 2), "log")
	_run(sim, 300)
	_ok("nothing went in while it was being built", not kiln.built and kiln.inp == "" and _all(sim) == 12)
	_run(sim, 150)
	_ok("built in 40 s, and it took a stone", kiln.built and kiln.inp == "stone" and fire.hopper.size() == 2)
	_ok("with no fire it does not work and has no cycle", kiln.work == 0.0 and sim.cycle_seconds(kiln) == -1.0)
	sim.tap(fire_at)
	_tick(sim)
	_ok("a working kiln draws the fire's 60 kW and has all it asks", is_equal_approx(fire.draw, 60.0) and is_equal_approx(kiln.share, 1.0))
	# 55 MJ at 60 kW: 55000 / 24 = 2291.7 ticks a stone, 229.2 s
	_ok("its card says 229 s a stone", is_equal_approx(sim.cycle_seconds(kiln), 55000.0 / 24.0 * 0.1))
	var made: Array[int] = []
	var dim := -1
	for i in 14000:
		for e: Dictionary in _tick(sim):
			if e.type == "made":
				made.append(i + 2)
			elif e.type == "dim":
				dim = i + 2
		if dim > 0:
			break
	_ok("the first lime at 2292 ticks (%d)" % (made[0] if made.size() > 0 else -1), made.size() >= 5 and absi(made[0] - 2292) <= 1)
	var even := made.size() >= 5
	for i in range(1, made.size()):
		even = even and made[i] - made[i - 1] >= 2292 and made[i] - made[i - 1] <= 2295
	_ok("and one every 2292 or so after, the next stone taking a tick to come in", even)
	# 320 MJ at 60 kW: 13333.3 ticks, 22 min 13 s; a tick idle between two
	# stones burns a fifth, so the log lasts a few ticks more than that
	_ok("a log under a working kiln lasts 22 min (%d ticks)" % dim, dim >= 13334 and dim <= 13334 + 10)
	_tick(sim)
	_ok("the kiln only pauses when the fire dims", kiln.inp == "stone" and float(kiln.work) > 0.0 and float(kiln.work) < 1.0 and kiln.share == 0.0)
	var held: float = kiln.work
	_run(sim, 100)
	_ok("and keeps what it had done", kiln.work == held)
	_ok("the limes rode off and no stone was lost", _all(sim) == 12 - 1 and _lying(sim, Vector2i(15, 4)) == 2)
	_ok("a kiln turns from its card if its front has room", sim.turn(Vector2i(9, 4)) and kiln.facing == 1 and sim.front_of(kiln) == Vector2i(9, 5) and sim.module_at(Vector2i(10, 4)).is_empty())

	# heat does not cross a seam: a fire on the meadow, a kiln on the forest
	sim = _meadow()
	sim.place("firebox", Vector2i(8, 0), 0)
	sim.place("kiln", Vector2i(6, 0), 0)
	sim.lay_belt(Vector2i(8, 1), 3)
	sim.lay_belt(Vector2i(5, 0), 0)
	sim.put(Vector2i(8, 1), "log")
	sim.put(Vector2i(5, 0), "stone")
	_run(sim, 420)
	sim.tap(Vector2i(8, 0))
	_run(sim, 50)
	kiln = sim.module_at(Vector2i(6, 0))
	_ok("heat does not cross to another plate", sim.module_at(Vector2i(8, 0)).lit and kiln.inp == "stone" and kiln.share == 0.0 and kiln.work == 0.0 and sim.cycle_seconds(kiln) == -1.0)

func _check_shared() -> void:
	var sim := _meadow()
	var fire_at := Vector2i(10, 3)
	sim.place("firebox", fire_at, 0)
	sim.place("kiln", Vector2i(9, 4), 0)
	_ok("a retort is 40", sim.price("retort") == 40 and sim.place("retort", Vector2i(9, 2), 0))
	var fire: Dictionary = sim.module_at(fire_at)
	var kiln: Dictionary = sim.module_at(Vector2i(9, 4))
	var retort: Dictionary = sim.module_at(Vector2i(9, 2))
	sim.lay_belt(Vector2i(8, 4), 0)
	sim.lay_belt(Vector2i(8, 2), 0)
	sim.lay_belt(Vector2i(11, 3), 2)
	sim.put(Vector2i(8, 4), "stone")
	sim.put(Vector2i(8, 2), "log")
	sim.put(Vector2i(11, 3), "log")
	_run(sim, 420)
	_ok("each holds its own and neither takes the other's", kiln.inp == "stone" and retort.inp == "log" and fire.hopper == ["log"])
	sim.tap(fire_at)
	_tick(sim)
	# the ledger, section 4: supply over demand. Two sinks of 60 kW on a fire
	# of 60: each runs at a half. (The spec's "60 over 100" is loose wording.)
	_ok("a kiln and a retort on one fire run at a half each", is_equal_approx(kiln.share, 0.5) and is_equal_approx(retort.share, 0.5) and is_equal_approx(fire.draw, 60.0))
	_ok("and their cards say twice as long", is_equal_approx(sim.cycle_seconds(kiln), 2.0 * 229.1666667) and is_equal_approx(sim.cycle_seconds(retort), 2.0 * 133.3333333))
	# a retort is 32 MJ: 1333.3 ticks at full heat, 2666.7 at a half
	var ticks := 1 + _until(sim, "made", 3000)
	_ok("the charcoal comes at 2667 ticks, not 1334 (%d)" % ticks, absi(ticks - 2667) <= 1)
	_ok("it lies past the retort's front", _lying(sim, Vector2i(11, 2)) == 1 and sim.items[Vector2i(11, 2)][0].kind == "charcoal" and retort.out == "")
	_tick(sim)
	# the retort idle asks a fifth: 60 + 12 = 72 over 60
	_ok("the retort idle, the kiln has 60 over 72", is_equal_approx(kiln.share, 60.0 / 72.0) and is_equal_approx(fire.draw, 60.0))
	_ok("the kiln is nearer half done than done", float(kiln.work) > 0.5 and float(kiln.work) < 0.6)
	# levels: 90 and 120 kW for 60 and 180
	sim.put(Vector2i(8, 2), "log")
	_run(sim, 30)
	var coins: int = sim.coins
	_ok("the fire's second level is 60", sim.upgrade_price(fire_at) == 60 and sim.upgrade(fire_at) and sim.coins == coins - 60 and fire.level == 2)
	_tick(sim)
	_ok("at 90 kW each has three quarters", is_equal_approx(kiln.share, 0.75) and is_equal_approx(fire.draw, 90.0))
	_ok("the third is 180", sim.upgrade_price(fire_at) == 180 and sim.upgrade(fire_at) and fire.level == 3)
	_tick(sim)
	_ok("at 120 kW each has all it asks", is_equal_approx(kiln.share, 1.0) and is_equal_approx(retort.share, 1.0) and is_equal_approx(fire.draw, 120.0))
	_ok("and there is no fourth, nor a level on a kiln", sim.upgrade_price(fire_at) == -1 and not sim.upgrade(fire_at) and sim.upgrade_price(Vector2i(9, 4)) == -1)
	coins = sim.coins
	_ok("sold, the fire returns all 260 paid on it", sim.sell_price(fire_at) == 260 and sim.sell(fire_at) and sim.coins == coins + 260 and sim.module_at(fire_at).is_empty())
	_tick(sim)
	_ok("and the machines it fed pause", kiln.share == 0.0 and retort.share == 0.0)

	# a second fire: a sink between two has the sum of the shares, held to one
	sim = _meadow()
	sim.place("firebox", Vector2i(10, 3), 0)
	sim.place("firebox", Vector2i(10, 5), 0)
	sim.place("kiln", Vector2i(9, 4), 0)
	sim.lay_belt(Vector2i(8, 4), 0)
	sim.put(Vector2i(8, 4), "stone")
	sim.lay_belt(Vector2i(10, 2), 1)
	sim.lay_belt(Vector2i(10, 6), 3)
	sim.put(Vector2i(10, 2), "log")
	sim.put(Vector2i(10, 6), "log")
	_run(sim, 420)
	sim.tap(Vector2i(10, 3))
	sim.tap(Vector2i(10, 5))
	_tick(sim)
	_ok("a kiln between two fires runs no faster than its rating", is_equal_approx(sim.module_at(Vector2i(9, 4)).share, 1.0))

	# a machine's output goes into the next machine's back, a hopper or the market
	sim = _meadow()
	sim.place("retort", Vector2i(9, 3), 0)
	sim.place("firebox", Vector2i(11, 3), 0)
	sim.place("firebox", Vector2i(10, 2), 0)
	sim.lay_belt(Vector2i(8, 3), 0)
	sim.put(Vector2i(8, 3), "log")
	sim.lay_belt(Vector2i(10, 1), 1)
	sim.put(Vector2i(10, 1), "log")
	_run(sim, 420)
	sim.tap(Vector2i(10, 2))
	_until(sim, "made", 1500)
	_tick(sim)
	_ok("a retort's charcoal goes into the hopper its front points at", sim.module_at(Vector2i(11, 3)).hopper == ["charcoal"] and _all(sim) == 1)

func _check_sell() -> void:
	var sim := _meadow()
	var fire_at := Vector2i(10, 3)
	sim.place("firebox", fire_at, 0)
	sim.place("kiln", Vector2i(9, 4), 0)
	_belt_row(sim, Vector2i(10, 0), 3, 1)
	for y in 3:
		sim.put(Vector2i(10, y), "log")
		sim.put(Vector2i(10, y), "log")
	sim.lay_belt(Vector2i(8, 4), 0)
	sim.put(Vector2i(8, 4), "stone")
	sim.put(Vector2i(8, 4), "stone")
	_run(sim, 500)
	var fire: Dictionary = sim.module_at(fire_at)
	var kiln: Dictionary = sim.module_at(Vector2i(9, 4))
	_ok("a hopper of five, a kiln with a stone", fire.hopper.size() == 5 and kiln.inp == "stone" and _all(sim) == 8)
	var coins: int = sim.coins
	sim.events.clear()
	_ok("a kiln sold returns its 40", sim.sell(Vector2i(10, 4)) and sim.coins == coins + 40 and sim.modules.size() == 1)
	_ok("and says so", sim.events[0].type == "sold_back" and sim.events[0].amount == 40 and sim.events[0].items == 1)
	_ok("its stone lies on its tile", _lying(sim, Vector2i(9, 4)) == 1 and sim.items[Vector2i(9, 4)][0].kind == "stone" and _all(sim) == 8)
	_ok("a firebox sold returns its 20", sim.sell(fire_at) and sim.coins == coins + 60 and sim.modules.is_empty())
	_ok("two of its five logs lie on its tile and the rest on the nearest bare ground", _lying(sim, fire_at) == 2 and _all(sim) == 8)
	var near := true
	var loose := 0
	for t: Vector2i in sim.items:
		if sim.belts.has(t):
			continue
		loose += sim.items[t].size()
		near = near and (t - fire_at).length_squared() <= 2 and sim.items[t].size() <= 2
	_ok("none further than a tile off, none over two a tile", near and loose == 6)
	coins = sim.coins
	_ok("a belt sold returns its coin and its items lie", sim.sell(Vector2i(10, 2)) and sim.coins == coins + 1 and _lying(sim, Vector2i(10, 2)) == 1 and _all(sim) == 8)
	_ok("there is nothing to sell on bare ground", not sim.sell(Vector2i(12, 6)) and _refused(sim, "nothing"))
	# a module placed where things lie moves them aside, and a short purse buys nothing
	_ok("a firebox goes where the logs lie", sim.place("firebox", fire_at, 0) and _lying(sim, fire_at) == 0 and _all(sim) == 8)
	sim.coins = 39
	_ok("39 coins do not buy a kiln", not sim.place("kiln", Vector2i(12, 6), 0) and _refused(sim, "coins") and sim.coins == 39)
	_ok("nor does a kiln fit half in the pond", not sim.can_place("kiln", Vector2i(15, 6), 0) and sim.can_place("kiln", Vector2i(15, 6), 2))

func _check_kept() -> void:
	# a land with a bit of everything on it, mid motion
	var sim := _meadow()
	sim.buy_plate(Vector2i(0, 1), "quarry")
	sim.place("firebox", Vector2i(10, 3), 0)
	sim.place("kiln", Vector2i(9, 4), 0)
	sim.place("retort", Vector2i(9, 2), 0)
	sim.lay_belt(Vector2i(8, 4), 0)
	sim.lay_belt(Vector2i(8, 2), 0)
	sim.lay_belt(Vector2i(11, 3), 2)
	sim.put(Vector2i(8, 4), "stone")
	sim.put(Vector2i(8, 2), "log")
	sim.put(Vector2i(11, 3), "log")
	sim.put(Vector2i(11, 3), "log")
	_belt_row(sim, Vector2i(0, 7), 6, 0)
	_belt_row(sim, Vector2i(11, 4), 4, 0)
	for x in 6:
		sim.put(Vector2i(x, 7), "log")
	_run(sim, 420)
	sim.tap(Vector2i(10, 3))
	sim.tap(sim.rocks.keys()[0])
	sim.upgrade("market")
	sim.picked = "belt"
	_run(sim, 777)
	for id: int in sim.trees:
		sim.tap(sim.trees[id].tile)
	_run(sim, 13)
	sim.step(0.04)
	sim.save()
	_ok("a save clears dirty", not sim.dirty)
	var a := FileAccess.get_file_as_string(Sim.path)
	var back: RefCounted = Sim.new(999)
	_ok("the file loads", a.length() > 100 and back.load_saved())
	if var_to_str(back.pack()) != var_to_str(sim.pack()):
		var x := var_to_str(sim.pack()).split("\n")
		var y := var_to_str(back.pack()).split("\n")
		for i in mini(x.size(), y.size()):
			if x[i] != y[i]:
				print(i, " A ", x[i], "\n  B ", y[i])
	_ok("into the same land", var_to_str(back.pack()) == var_to_str(sim.pack()) and back.coins == sim.coins and back.picked == "belt")
	back.save()
	var b := FileAccess.get_file_as_string(Sim.path)
	_ok("which saves as the same file", a == b)
	sim.events.clear()
	sim.step(0.0)
	sim.step(-1.0)
	_ok("stepping no time changes nothing", var_to_str(sim.pack()) == var_to_str(back.pack()) and sim.events.is_empty())
	sim.save()
	_ok("nor does saving again", FileAccess.get_file_as_string(Sim.path) == a)
	# the two play on alike: ten minutes with new trees coming up, chops and sales
	var same := true
	for i in 6000:
		sim.step(Sim.TICK)
		back.step(Sim.TICK)
		if i % 600 == 0:
			for id: int in sim.trees:
				sim.tap(sim.trees[id].tile)
			for id: int in back.trees:
				back.tap(back.trees[id].tile)
			same = same and var_to_str(sim.pack()) == var_to_str(back.pack())
	_ok("and the land read back plays on as the land saved does", same and var_to_str(sim.pack()) == var_to_str(back.pack()) and sim.coins == back.coins and _all(sim) == _all(back))
	_ok("a long frame is a quarter of a second at most", _long_frame())
	# no file, and a file that is not a land
	DirAccess.remove_absolute(Sim.path)
	var fresh: RefCounted = Sim.new(3)
	var was := var_to_str(fresh.pack())
	_ok("no file is no land, and the sim is left alone", not fresh.load_saved() and var_to_str(fresh.pack()) == was)
	var f := FileAccess.open(Sim.path, FileAccess.WRITE)
	f.store_string("[factory]\nversion=1\nstate=\"%s\"\n" % Marshalls.variant_to_base64({"version": 1, "coins": "many"}))
	f.close()
	_ok("a file that is not a land is refused", not fresh.load_saved() and var_to_str(fresh.pack()) == was)
	f = FileAccess.open(Sim.path, FileAccess.WRITE)
	f.store_string("not a config at all {{{")
	f.close()
	_ok("and so is nonsense", not fresh.load_saved() and var_to_str(fresh.pack()) == was)

func _long_frame() -> bool:
	var sim: RefCounted = Sim.new(7)
	sim.tap(sim.trees[sim.trees.keys()[0]].tile)
	sim.events.clear()
	sim.step(3600.0)
	# an hour's hitch is two ticks and a half: the first bite is at 0.8 s
	return sim.events.is_empty() and is_equal_approx(sim.alpha, 0.5)

# --- the pace bot ---

## The shortest run of new belts from `from` to a tile beside the market or
## beside a belt already laid (every belt this player lays leads there): the
## tiles and the facing of each. Empty: there is no way.
func _route(sim: RefCounted, from: Vector2i) -> Array:
	var came := {from: Sim.NONE}
	var open: Array[Vector2i] = [from]
	while not open.is_empty():
		var t: Vector2i = open.pop_front()
		for f in 4:
			var n: Vector2i = t + Sim.DIRS[f]
			if sim.is_market(n) or sim.belts.has(n):
				var out: Array = [[t, f]]
				while came[t] != Sim.NONE:
					var prev: Vector2i = came[t]
					out.push_front([prev, Sim.DIRS.find(t - prev)])
					t = prev
				return out
		for f in 4:
			var n: Vector2i = t + Sim.DIRS[f]
			if came.has(n) or not sim.can_lay(n) or not sim.tree_at(n).is_empty():
				continue
			came[n] = t
			open.append(n)
	return []

func _pace(first_seed: int, lands: int) -> void:
	var sum := 0.0
	for k in lands:
		var sim: RefCounted = Sim.new(first_seed + k)
		var ticks := 0
		var laid := 0
		var bought := -1
		while bought < 0 and ticks < 3 * 36000:
			sim.step(Sim.TICK)
			ticks += 1
			if ticks % 10 != 0:
				continue
			# once a second: tap what stands, belt what lies, buy when the coins reach
			for id: int in sim.trees:
				if sim.trees[id].state == "standing" and not sim.trees[id].queued:
					sim.tap(sim.trees[id].tile)
			for t: Vector2i in sim.items.keys():
				if sim.belts.has(t) or not sim.tree_at(t).is_empty():
					continue
				var way := _route(sim, t)
				if way.is_empty() or way.size() > sim.coins:
					continue
				for hop: Array in way:
					sim.lay_belt(hop[0], hop[1])
					laid += 1
			if sim.coins >= sim.plate_price():
				sim.buy_plate(sim.free_edges()[0], "forest")
				bought = ticks
			sim.events.clear()
		var minute := ticks / 600.0
		sum += minute
		print("pace seed %d: second plate at play-minute %.1f (%d belts laid, %d coins earned, %d trees)" % [first_seed + k, minute, laid, sim.earned, sim.trees.size()])
	print("pace: second plate at play-minute %.1f, the mean of %d lands" % [sum / lands, lands])
