extends SceneTree

## Factory's sim, headless: the rules first, then a crude player to say how
## slow the first forest level and the first plate are.
##
##     godot --headless --path . --script res://tests/_probe_factory.gd
##     godot --headless --path . --script res://tests/_probe_factory.gd -- pace [first seed] [lands]
##
## The checks: a new land is neutral ground with the market and a forest
## behind it; a forest is closed (no belt, no machine, no bare tile), a tap
## anywhere on it is one log into its stock, twelve at most, and the stock
## leaves by its gates, the sides by turns, onto bare ground past a gate (two
## a tile) or into a belt; a belt from the gate to the market sells; a
## forest's four levels, their prices and the logs a second each makes by
## itself; a belt carries; the market sells at its rate and no faster; two
## feeders alternate; a full belt waits and nothing is lost; plate prices,
## and the fire and the retort in the drawer from the first plate bought
## (the kiln never: nothing gives stone); a firebox banked and one under a
## working retort last what the ledger's formula says; two retorts on one
## fire run at a half each; a module sold returns its price and its items
## lie; a save reads back as the same land and plays on the same; a land of
## the first version is refused; no time stepped changes nothing.
##
## The ledger's headline times are rounded and the checks are not: a retort
## is 32 MJ at 60 kW, 1333.3 ticks (133.3 s, the ledger's "2 min 15 s"); a
## log banked 66666.7 ticks (1 h 51 min), under a working retort 13333.3
## (22 min). Each is held to the formula within a couple of ticks.
##
## `pace` plays new lands with a player who taps the forest once a second,
## lays the nine belts from the gate to the market as soon as the coins
## reach, buys the forest's first level the moment it can and then the first
## plate; it prints the play-minute of each, and the mean, least and most
## over the lands. The lands agree to the tick: a seed only stands the trees
## and says which of them a log comes off, and nothing of the pace reads
## that. Everything runs on a throwaway file.

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
		_pace(int(args[1]) if args.size() > 1 else 1, int(args[2]) if args.size() > 2 else 10)
	else:
		_check_land()
		_check_forest()
		_check_gates()
		_check_levels()
		_check_belts()
		_check_feeders()
		_check_plates()
		_check_fire()
		_check_retort()
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

## Every item the land holds: lying, riding, lying on the hatch, in a
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

## A land with a second plate of neutral ground to the +x of the first
## (tiles 8..15 across, nothing on it), which is the plate that puts the fire
## and the retort in the drawer, and coins to build with.
func _open() -> RefCounted:
	var sim: RefCounted = Sim.new(7)
	sim.coins = 100000
	sim.buy_plate(Vector2i(1, 0), "neutral")
	sim.events.clear()
	return sim

## The forest a new land has, a tile well inside it, and the one gate of its
## four that leads on to land: out of (3, -1) into (3, 0).
const F := Vector2i(0, -1)
const IN := Vector2i(4, -4)
const PAST := Vector2i(3, 0)

func _stock(sim: RefCounted, p: Vector2i = F) -> int:
	return int(sim.forests[p].stock)

## The nine belts from the gate to the market: down the column past the gate
## and along to the market.
func _way(sim: RefCounted) -> void:
	_belt_row(sim, PAST, 6, 1)
	_belt_row(sim, Vector2i(3, 6), 3, 0)

func _belt_row(sim: RefCounted, from: Vector2i, n: int, facing: int) -> void:
	for i in n:
		sim.lay_belt(from + Sim.DIRS[facing] * i, facing)

func _refused(sim: RefCounted, why: String) -> bool:
	var e: Dictionary = sim.events.back() if not sim.events.is_empty() else {}
	return e.get("type", "") == "refused" and e.get("why", "") == why

# --- the checks ---

func _check_land() -> void:
	var sim: RefCounted = Sim.new(7)
	_ok("a new land has twenty coins, the market's plate and a forest behind it", sim.coins == 20 and sim.earned == 0
		and sim.plates == {Vector2i.ZERO: "neutral", Sim.FOREST_AT: "forest"} and Sim.FOREST_AT == F)
	_ok("fourteen trees", sim.trees.size() == Sim.TREES and Sim.TREES == 14)
	var inside := true
	var on := {}
	for id: int in sim.trees:
		var tr: Dictionary = sim.trees[id]
		var t: Vector2i = tr.tile - F * Sim.PLATE
		on[tr.tile] = true
		inside = inside and t.x >= 1 and t.x <= 6 and t.y >= 1 and t.y <= 6 and int(tr.look) >= 0 and int(tr.look) <= 3 \
			and tr.keys().size() == 3 and int(tr.id) == id
	_ok("each on the forest inside its rim, on a tile of its own, a look and nothing else to it", inside and on.size() == Sim.TREES)
	var edges: Array = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(1, -1), Vector2i(-1, -1), Vector2i(0, -2)]
	edges.sort()
	_ok("six free edges round the two", sim.free_edges() == edges)
	_ok("a tile across the back seam is on the plate behind", Sim.plate_of(Vector2i(-1, 0)) == Vector2i(-1, 0) and Sim.plate_of(Vector2i(7, -8)) == Vector2i(0, -1)
		and Sim.plate_of(Vector2i(3, -1)) == F and sim.on_land(Vector2i(3, -1)) and not sim.on_land(Vector2i(3, -9)))
	_ok("the belt is in the drawer; the fire, the retort and the kiln are not", sim.unlocked("belt") and not sim.unlocked("firebox") and not sim.unlocked("retort")
		and not sim.unlocked("kiln") and not sim.can_place("firebox", Vector2i(0, 0), 0))
	_ok("the market is its one tile and cannot be sold or built on", sim.is_market(Vector2i(6, 6)) and not sim.is_market(Vector2i(7, 7)) and not sim.is_market(Vector2i(5, 6))
		and not sim.sell(Vector2i(6, 6)) and not sim.can_lay(Vector2i(6, 6)) and sim.can_lay(Vector2i(6, 7)) and not sim.can_lay(Vector2i(8, 0)))
	_ok("its plate is open ground: every other tile of it is bare and takes a belt", _bare(sim, Vector2i.ZERO) == 63)
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
	var before := var_to_str(first.pack().trees)
	var said := 0
	for i in 3000:
		said += _tick(first).size()
	_ok("left alone five minutes a new land does nothing: no tree comes or goes, nothing lies, nothing is said",
		var_to_str(first.pack().trees) == before and first.items.is_empty() and said == 0 and first.coins == 20 and _stock(first) == 0)

## How many tiles of plate `p` are bare and take a belt.
func _bare(sim: RefCounted, p: Vector2i) -> int:
	var n := 0
	for y in Sim.PLATE:
		for x in Sim.PLATE:
			var t := p * Sim.PLATE + Vector2i(x, y)
			n += 1 if sim.tile_free(t) and sim.can_lay(t) else 0
	return n

func _check_forest() -> void:
	var sim: RefCounted = Sim.new(7)
	_ok("a tap on bare ground does nothing", not sim.tap(Vector2i(0, 0)) and _refused(sim, "nothing"))
	# closed: nothing goes on any of its sixty-four tiles
	var closed := true
	for y in Sim.PLATE:
		for x in Sim.PLATE:
			var t := F * Sim.PLATE + Vector2i(x, y)
			closed = closed and sim.is_forest(t) and not sim.can_lay(t) and not sim.tile_free(t) and not sim.put(t, "log")
	_ok("a forest is closed: no tile of it is bare, takes a belt or is put on", closed and _bare(sim, F) == 0 and not sim.is_forest(PAST))
	_ok("a belt laid on a forest is refused as forest and costs nothing", not sim.lay_belt(IN, 1) and _refused(sim, "forest")
		and not sim.lay_belt(Sim.gate(F, 1), 1) and _refused(sim, "forest") and sim.coins == 20 and sim.belts.is_empty())
	var built: RefCounted = _open()
	_ok("so is a machine, and one whose front would stand in it", not built.can_place("firebox", IN, 0) and not built.place("firebox", IN, 0) and _refused(built, "forest")
		and not built.can_place("retort", PAST, 3) and not built.place("retort", PAST, 3) and _refused(built, "forest")
		and built.can_place("retort", PAST, 1) and built.modules.is_empty() and built.coins == 100000 - 50)
	_ok("the gates are a tile in each side", Sim.gate(F, 0) == Vector2i(7, -4) and Sim.gate(F, 1) == Vector2i(3, -1)
		and Sim.gate(F, 2) == Vector2i(0, -5) and Sim.gate(F, 3) == Vector2i(4, -8))
	# a tap is a log
	sim.events.clear()
	_ok("a tap on a forest is one log into its stock", sim.tap(IN) and _stock(sim) == 1 and sim.items.is_empty() and sim.dirty)
	var e: Dictionary = sim.events[0] if sim.events.size() == 1 else {}
	var by: Dictionary = sim.trees.get(int(e.get("id", 0)), {})
	_ok("it says chop: the plate, the hand's own, and the tree it came off", e.get("type", "") == "chop" and e.get("plate", null) == F and e.get("auto", true) == false
		and not by.is_empty() and by.tile == e.tile and (e.tile - IN).length_squared() <= 2)
	_ok("a tap on its rim and one on a gate are a log each", sim.tap(Vector2i(0, -1)) and sim.tap(Sim.gate(F, 1)) and _stock(sim) == 3)
	# out of the one gate that leads on to land, a tick each, two to the tile
	var said := _tick(sim)
	_ok("a tick later one lies past the gate", _stock(sim) == 2 and _lying(sim, PAST) == 1 and sim.items[PAST][0].kind == "log" and sim.items.size() == 1)
	_ok("and it says log: the tile, the gate it left by", said.size() == 1 and said[0].type == "log" and said[0].tile == PAST and said[0].from == Sim.gate(F, 1) and said[0].kind == "log")
	_tick(sim)
	_ok("the next tick a second lies there", _stock(sim) == 1 and _lying(sim, PAST) == 2)
	said = []
	for i in 50:
		said.append_array(_tick(sim))
	_ok("two a tile and no more: the third waits in the forest", _stock(sim) == 1 and _lying(sim, PAST) == 2 and sim.items.size() == 1 and said.is_empty())
	# twelve held and no more
	var took := 0
	for i in 20:
		took += 1 if sim.tap(IN) else 0
	_ok("it holds twelve", took == 11 and _stock(sim) == Sim.FOREST_ROOM and Sim.FOREST_ROOM == 12)
	sim.events.clear()
	_ok("a tap on a full forest is refused as full, at a tree of it", not sim.tap(IN) and _refused(sim, "full") and _stock(sim) == 12
		and sim.is_forest(sim.events[0].tile) and sim.events.size() == 1)
	_run(sim, 100)
	_ok("fourteen logs in all, none lost and none sold", _stock(sim) + _all(sim) == 14 and sim.coins == 20 and sim.earned == 0)
	# the belt from the gate to the market
	_way(sim)
	_ok("nine belts from the gate to the market are nine coins", sim.belts.size() == 9 and sim.coins == 11 and sim.belts[PAST] == 1 and sim.belts[Vector2i(5, 6)] == 0)
	_ok("the two that lay past the gate are on the belt laid under them", _lying(sim, PAST) == 2 and sim.items[PAST][0].at == 0.5 and sim.items[PAST][1].at == 0.0)
	var lost := false
	var sales: Array[int] = []
	for i in 1200:
		for ev: Dictionary in _tick(sim):
			if ev.type == "sale":
				sales.append(i)
		lost = lost or _stock(sim) + _all(sim) + sales.size() != 14
	var nearest := 100000
	for i in range(1, sales.size()):
		nearest = mini(nearest, sales[i] - sales[i - 1])
	_ok("the belt empties the forest and the market sells all fourteen, a coin each", sales.size() == 14 and sim.coins == 25 and sim.earned == 14 and _stock(sim) == 0 and _all(sim) == 0)
	_ok("none lost on the way, and never two sales in under four seconds", not lost and nearest >= 40)
	# one log, timed: out of the gate onto the belt, nine tiles, four seconds on the hatch
	sim = Sim.new(7)
	_way(sim)
	sim.tap(IN)
	var found: Array = []
	var at := _until(sim, "sale", 400, found)
	_ok("a log tapped rides nine tiles of belt to the market in 18 s and lies on its hatch four (%d ticks)" % at, at >= 219 and at <= 223 and sim.coins == 12)
	# what else takes a log past a gate: a hopper, a retort's back
	sim = _open()
	sim.place("firebox", PAST, 0)
	_run(sim, 200)
	for i in 6:
		sim.tap(IN)
	var fed := 0
	for i in 20:
		for ev: Dictionary in _tick(sim):
			fed += 1 if ev.type == "fed" else 0
	var fire: Dictionary = sim.module_at(PAST)
	_ok("a fire box past a gate takes five into its hopper and the sixth waits in the forest", fire.built and fire.hopper == ["log", "log", "log", "log", "log"] and fed == 5
		and _stock(sim) == 1 and sim.items.is_empty())
	sim = _open()
	sim.place("retort", PAST, 1)
	_run(sim, 400)
	sim.tap(IN)
	sim.tap(IN)
	_run(sim, 20)
	_ok("a retort's back past a gate takes one and the next waits", sim.module_at(PAST).built and sim.module_at(PAST).inp == "log" and _stock(sim) == 1 and sim.items.is_empty())

func _check_gates() -> void:
	# a second way out: neutral ground beside the forest, past its +x gate
	var sim: RefCounted = Sim.new(7)
	sim.coins = 100000
	sim.buy_plate(Vector2i(1, -1), "neutral")
	var east := Vector2i(8, -4)
	for i in 4:
		sim.tap(IN)
	var from: Array = []
	var into: Array = []
	for i in 4:
		for e: Dictionary in _tick(sim):
			if e.type == "log":
				from.append(e.from)
				into.append(e.tile)
	_ok("with ground past two gates the logs leave by turns, one a tick (%s)" % [from],
		from == [Vector2i(7, -4), Vector2i(3, -1), Vector2i(7, -4), Vector2i(3, -1)] and into == [east, PAST, east, PAST])
	_ok("two lie past each and the forest is empty", _lying(sim, east) == 2 and _lying(sim, PAST) == 2 and _stock(sim) == 0)
	sim.tap(IN)
	_run(sim, 30)
	_ok("with both full the next waits", _stock(sim) == 1 and _all(sim) == 4)
	# a belt past each: one a gate a tick, then a belt's own gap
	sim = Sim.new(7)
	sim.coins = 100000
	sim.buy_plate(Vector2i(1, -1), "neutral")
	_belt_row(sim, east, 8, 0)
	_way(sim)
	for i in 6:
		sim.tap(IN)
	var said := _tick(sim)
	_ok("belts past two gates take one each in the same tick", said.size() == 2 and said[0].from == Vector2i(7, -4) and said[1].from == Vector2i(3, -1)
		and _stock(sim) == 4 and _lying(sim, east) == 1 and _lying(sim, PAST) == 1 and sim.items[east][0].from == 0 and sim.items[PAST][0].from == 1)
	_run(sim, 9)
	_ok("and no more until the first has gone half a tile", _stock(sim) == 4)
	said = _tick(sim)
	_ok("then one each again", said.size() == 2 and _stock(sim) == 2 and _lying(sim, east) == 2 and _lying(sim, PAST) == 2)
	# a belt at one gate and bare ground at the other: the belt has them
	sim = Sim.new(7)
	sim.coins = 100000
	sim.buy_plate(Vector2i(1, -1), "neutral")
	_way(sim)
	sim.forests[F].next = 0
	sim.tap(IN)
	_tick(sim)
	_ok("a belt at one gate takes the log before bare ground at another does, whichever side's turn it is", _lying(sim, east) == 0 and _lying(sim, PAST) == 1 and _stock(sim) == 0)

func _check_levels() -> void:
	var sim: RefCounted = Sim.new(7)
	_ok("a forest by hand makes nothing by itself, and its first level is 60", sim.forest_rate(F) == 0.0 and sim.upgrade_price(IN) == 60 and sim.upgrade_price(Vector2i(0, -8)) == 60
		and Sim.FOREST_PRICE == [60, 180, 540, 1620] and Sim.FOREST_RATE == [0.0, 1.0, 2.0, 3.0, 4.0])
	_ok("twenty coins do not reach it", not sim.upgrade(IN) and _refused(sim, "coins") and sim.coins == 20 and int(sim.forests[F].level) == 0)
	_ok("bare ground has no level to buy", sim.upgrade_price(PAST) == -1 and not sim.upgrade(PAST) and _refused(sim, "top"))
	sim.coins = 100000
	var spent := 0
	var right := true
	for lv in 4:
		var cost: int = Sim.FOREST_PRICE[lv]
		sim.events.clear()
		right = right and sim.upgrade_price(IN) == cost and sim.upgrade(Vector2i(lv, -1 - lv))
		spent += cost
		var e: Dictionary = sim.events.back()
		right = right and e.type == "level" and e.target == "forest" and e.level == lv + 1 and e.plate == F and e.tile == Vector2i(lv, -1 - lv)
		right = right and int(sim.forests[F].level) == lv + 1 and is_equal_approx(sim.forest_rate(F), lv + 1.0) and sim.coins == 100000 - spent
	_ok("its levels are 60, 180, 540 and 1620, bought from any tile of it, a log a second more each", right and spent == 2400 and int(sim.forests[F].paid) == 2400)
	_ok("and there is no fifth", sim.upgrade_price(IN) == -1 and not sim.upgrade(IN) and _refused(sim, "top") and sim.coins == 100000 - 2400)
	# the logs a second of each level, counted
	for lv in range(0, 5):
		sim = Sim.new(7)
		sim.coins = 100000
		for i in lv:
			sim.upgrade(IN)
		sim.events.clear()
		var chops := 0
		var auto := true
		var first := -1
		for i in 20:
			for e: Dictionary in _tick(sim):
				if e.type == "chop":
					chops += 1
					auto = auto and e.auto and e.plate == F and sim.trees.has(int(e.id)) and sim.trees[int(e.id)].tile == e.tile
					first = i + 1 if first < 0 else first
		_ok("level %d makes %d in two seconds, its own, off a tree of it (%d, the first at tick %d)" % [lv, 2 * lv, chops, first],
			chops == 2 * lv and auto and _stock(sim) + _all(sim) == 2 * lv and (lv == 0 or first == ceili(10.0 / lv)))
	# with nowhere to go but the ground it fills and stops
	sim.events.clear()
	_run(sim, 600)
	_ok("a forest with no belt fills, two past the gate and twelve held, and stops there", _stock(sim) == 12 and _lying(sim, PAST) == 2 and _all(sim) == 2
		and is_equal_approx(float(sim.forests[F].t), 1.0))
	var said := _tick(sim)
	_ok("and says nothing more", said.is_empty())
	sim.put(PAST, "log")
	_ok("a hand's tap is refused there too", not sim.tap(IN) and _refused(sim, "full"))
	# the first level through a belt and a new market: a log a second made,
	# one in four seconds sold, and the forest waits on the belt
	sim = Sim.new(7)
	_way(sim)
	sim.coins = 60
	sim.upgrade(IN)
	var made := 0
	var lost := false
	for i in 1800:
		for e: Dictionary in _tick(sim):
			made += 1 if e.type == "chop" else 0
		lost = lost or made != sim.earned + _all(sim) + _stock(sim)
	var before: int = sim.earned
	var was := made
	for i in 600:
		for e: Dictionary in _tick(sim):
			made += 1 if e.type == "chop" else 0
		lost = lost or made != sim.earned + _all(sim) + _stock(sim)
	_ok("a level-1 forest on a belt sells fifteen a minute through a new market, and makes no more than that once all is full (%d sold, %d made)" % [sim.earned - before, made - was],
		sim.earned - before == 15 and made - was == 15 and _stock(sim) == 12 and sim.market.wait.size() == 1)
	_ok("every log made is sold, riding, waiting or held: none lost", not lost and sim.coins == sim.earned)

func _check_belts() -> void:
	var sim: RefCounted = Sim.new(7)
	# the market's row of the first plate: six tiles running into it
	_ok("a belt can be laid on the rim", sim.can_lay(Vector2i(0, 6)))
	_belt_row(sim, Vector2i(0, 6), 6, 0)
	_ok("six belts are six coins", sim.coins == 14 and sim.belts.size() == 6)
	_ok("the same belt twice is not paid twice", not sim.lay_belt(Vector2i(0, 6), 0) and sim.coins == 14)
	_ok("a tap turns it a quarter, and again", sim.turn(Vector2i(0, 6)) and sim.belts[Vector2i(0, 6)] == 1 and sim.lay_belt(Vector2i(0, 6), 0) and sim.coins == 14)
	sim.put(Vector2i(0, 6), "log")
	var sale := -1
	var before: float = sim.items[Vector2i(0, 6)][0].at
	_tick(sim)
	_ok("an item rides a twentieth of a tile a tick", is_equal_approx(sim.items[Vector2i(0, 6)][0].at - before, 0.05))
	sim.step(0.05)
	var half: Vector2 = sim.item_pos(Vector2i(0, 6), sim.items[Vector2i(0, 6)][0])
	_ok("and is drawn a tick behind, half way between the last two", is_equal_approx(sim.alpha, 0.5) and is_equal_approx(half.x, 0.5 + 0.025) and is_equal_approx(half.y, 6.5))
	sim.step(0.05)
	for i in 200:
		for e: Dictionary in _tick(sim):
			if e.type == "sale":
				sale = i + 3
	# from mid tile to the market's edge is five tiles and a half, 11 s
	_ok("five and a half tiles to the market in 11 s, then four on its hatch (%d)" % sale, sale >= 149 and sale <= 153)
	_ok("a log is a coin", sim.coins == 15 and sim.earned == 1 and _all(sim) == 0)

	# a full belt: twelve logs, a market that takes one every four seconds
	for x in 6:
		_ok("a tile takes two", sim.put(Vector2i(x, 6), "log") and sim.put(Vector2i(x, 6), "log") and not sim.put(Vector2i(x, 6), "log"))
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
			# the hatch has its one and the belt behind it waits
			stuck = sim.market.wait.size() == 1 and sim.items[Vector2i(5, 6)][0].at == 1.0
	_ok("the hatch holds one and the belt behind waits", stuck)
	_ok("nothing is lost on a full belt", not lost)
	_ok("no two items nearer than half a tile", not close)
	_ok("never two sales in under four seconds", nearest >= 40)
	_ok("twelve sold in the end, a coin each", sold == 12 and sim.coins == 27 and _all(sim) == 0)
	_ok("which took the market's rate, not the belt's", last >= 11 * 40 - 5)

	# a belt with nothing ahead holds at its end; one into the pond too
	sim = _open()
	_belt_row(sim, Vector2i(8, 7), 8, 0)
	sim.put(Vector2i(8, 7), "stone")
	sim.put(Vector2i(8, 7), "log")
	_run(sim, 400)
	_ok("a belt into the pond holds its items at its end", _lying(sim, Vector2i(15, 7)) == 2 and sim.items[Vector2i(15, 7)][0].at == 1.0
		and is_equal_approx(sim.items[Vector2i(15, 7)][1].at, 0.5) and sim.items[Vector2i(15, 7)][0].kind == "stone")
	# a belt pointing into a forest gives it nothing: what rides waits at its end
	sim = Sim.new(7)
	_belt_row(sim, Vector2i(5, 2), 3, 3)
	sim.put(Vector2i(5, 2), "log")
	_run(sim, 200)
	_ok("a belt pointing into a forest holds its item at its end", _lying(sim, Vector2i(5, 0)) == 1 and sim.items[Vector2i(5, 0)][0].at == 1.0 and _stock(sim) == 0 and _all(sim) == 1)
	# a ring of belts goes round and neither hangs nor loses
	sim = _open()
	sim.lay_belt(Vector2i(9, 1), 0)
	sim.lay_belt(Vector2i(10, 1), 1)
	sim.lay_belt(Vector2i(10, 2), 2)
	sim.lay_belt(Vector2i(9, 2), 3)
	sim.put(Vector2i(9, 1), "log")
	_run(sim, 80)
	_ok("a ring of belts carries its item round", _all(sim) == 1 and _lying(sim, Vector2i(9, 1)) == 1)
	# an item on bare ground stays; a belt laid under it takes it
	sim = _open()
	sim.put(Vector2i(9, 5), "log")
	_run(sim, 100)
	_ok("an item on bare ground does not move", _lying(sim, Vector2i(9, 5)) == 1)
	sim.lay_belt(Vector2i(9, 5), 0)
	sim.lay_belt(Vector2i(10, 5), 0)
	_run(sim, 30)
	_ok("a belt laid under it carries it off", _lying(sim, Vector2i(9, 5)) == 0 and _lying(sim, Vector2i(10, 5)) == 1)

func _check_feeders() -> void:
	var sim := _open()
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

func _check_plates() -> void:
	var sim: RefCounted = Sim.new(7)
	_ok("the first plate bought is 50 and twenty coins do not reach", sim.plate_price() == 50 and not sim.buy_plate(Vector2i(1, 0), "neutral") and _refused(sim, "coins"))
	sim.coins = 100000
	_ok("a plate off the board's edge is refused, and one where a plate is", not sim.buy_plate(Vector2i(2, 0), "forest") and _refused(sim, "edge")
		and not sim.buy_plate(Vector2i(0, 0), "forest") and not sim.buy_plate(Vector2i(0, -1), "neutral"))
	var none := true
	for kind: String in ["quarry", "meadow", "swamp", ""]:
		none = none and not sim.buy_plate(Vector2i(1, 0), kind) and _refused(sim, "kind")
	_ok("there are two kinds of land and no other is sold", none and Sim.KINDS == ["forest", "neutral"] and sim.plates.size() == 2 and sim.coins == 100000)
	_ok("neutral ground is bought for 50", sim.buy_plate(Vector2i(1, 0), "neutral") and sim.coins == 100000 - 50 and sim.plates[Vector2i(1, 0)] == "neutral"
		and sim.events.back().type == "plate" and sim.events.back().plate == Vector2i(1, 0) and sim.events.back().kind == "neutral")
	_ok("all sixty-four tiles of it are bare, and nothing stands on it", _bare(sim, Vector2i(1, 0)) == 64 and sim.trees.size() == Sim.TREES and sim.forests.size() == 1)
	_ok("the fire and the retort are in the drawer from the first plate bought", sim.unlocked("firebox") and sim.unlocked("retort"))
	_ok("the kiln is not, and is not placed: nothing gives stone", not sim.unlocked("kiln") and Sim.LOCKED == ["kiln"] and not sim.can_place("kiln", Vector2i(9, 4), 0)
		and not sim.place("kiln", Vector2i(9, 4), 0) and _refused(sim, "locked") and sim.modules.is_empty() and sim.coins == 100000 - 50)
	_ok("the second is 150", sim.plate_price() == 150 and sim.buy_plate(Vector2i(-1, 0), "forest") and sim.coins == 100000 - 200)
	_ok("the third 450, the fourth 1350", sim.plate_price() == 450 and sim.buy_plate(Vector2i(0, 1), "neutral") and sim.plate_price() == 1350)
	var on := {}
	var own := {}
	for id: int in sim.trees:
		var p: Vector2i = Sim.plate_of(sim.trees[id].tile)
		on[p] = int(on.get(p, 0)) + 1
		own[sim.trees[id].tile] = true
	_ok("a forest bought has fourteen trees of its own", on.get(Vector2i(-1, 0), 0) == 14 and on.get(F, 0) == 14 and on.size() == 2 and own.size() == 28)
	var west := Vector2i(-1, 0)
	_ok("and is a forest like the first: closed, by hand, its own stock", sim.forests.size() == 2 and _bare(sim, west) == 0 and sim.forest_rate(west) == 0.0
		and sim.upgrade_price(Vector2i(-4, 4)) == 60 and sim.tap(Vector2i(-4, 4)) and _stock(sim, west) == 1 and _stock(sim) == 0)
	# its +x gate leads on to the market's plate
	var said := _tick(sim)
	_ok("its log leaves by the gate toward the market's plate", said.size() == 1 and said[0].type == "log" and said[0].from == Sim.gate(west, 0) and said[0].from == Vector2i(-1, 4)
		and said[0].tile == Vector2i(0, 4) and _lying(sim, Vector2i(0, 4)) == 1 and _stock(sim, west) == 0)
	_ok("a level bought on one forest is that forest's", sim.upgrade(Vector2i(-4, 4)) and sim.forest_rate(west) == 1.0 and sim.forest_rate(F) == 0.0 and sim.upgrade_price(IN) == 60)

func _check_fire() -> void:
	var sim := _open()
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
	var coal := _open()
	coal.place("firebox", fire_at, 0)
	coal.lay_belt(Vector2i(10, 2), 1)
	coal.put(Vector2i(10, 2), "charcoal")
	_run(coal, 240)
	coal.tap(fire_at)
	ticks = _until(coal, "dim", 40000)
	_ok("a charcoal banked lasts 31250 ticks, 52 min (%d)" % ticks, absi(ticks - 31250) <= 1)
	_ok("an empty firebox does not light", not coal.tap(fire_at) and _refused(coal, "empty"))

func _check_retort() -> void:
	var sim := _open()
	var fire_at := Vector2i(10, 3)
	sim.place("firebox", fire_at, 0)
	var coins: int = sim.coins
	_ok("a retort is 40 and stands on two tiles", sim.price("retort") == 40 and sim.place("retort", Vector2i(9, 4), 0) and sim.coins == coins - 40)
	var retort: Dictionary = sim.module_at(Vector2i(10, 4))
	var fire: Dictionary = sim.module_at(fire_at)
	_ok("back at its root, front ahead, output past it", retort.root == Vector2i(9, 4) and sim.front_of(retort) == Vector2i(10, 4) and sim.out_tile(retort) == Vector2i(11, 4)
		and sim.module_at(Vector2i(9, 4)) == retort)
	_ok("nothing is built over it", not sim.can_place("retort", Vector2i(8, 4), 0) and sim.can_place("retort", Vector2i(8, 4), 1) and not sim.can_lay(Vector2i(9, 4)))
	# logs down the plate's back column and into the retort's back
	_belt_row(sim, Vector2i(8, 0), 4, 1)
	sim.lay_belt(Vector2i(8, 4), 0)
	for y in 5:
		sim.put(Vector2i(8, y), "log")
		sim.put(Vector2i(8, y), "log")
	_belt_row(sim, Vector2i(11, 4), 5, 0)
	sim.lay_belt(Vector2i(10, 2), 1)
	sim.put(Vector2i(10, 2), "log")
	sim.put(Vector2i(10, 2), "log")
	_run(sim, 300)
	_ok("nothing went in while it was being built", not retort.built and retort.inp == "" and _all(sim) == 12)
	_run(sim, 150)
	_ok("built in 40 s, and it took a log", retort.built and retort.inp == "log" and fire.hopper.size() == 2)
	_ok("with no fire it does not work and has no cycle", retort.work == 0.0 and sim.cycle_seconds(retort) == -1.0)
	sim.tap(fire_at)
	_tick(sim)
	_ok("a working retort draws the fire's 60 kW and has all it asks", is_equal_approx(fire.draw, 60.0) and is_equal_approx(retort.share, 1.0))
	# 32 MJ at 60 kW: 32000 / 24 = 1333.3 ticks a log, 133.3 s
	_ok("its card says 133 s a log", is_equal_approx(sim.cycle_seconds(retort), 32000.0 / 24.0 * 0.1))
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
	_ok("the first charcoal at 1334 ticks (%d)" % (made[0] if made.size() > 0 else -1), made.size() >= 9 and absi(made[0] - 1334) <= 1)
	var even := made.size() >= 9
	for i in range(1, made.size()):
		even = even and made[i] - made[i - 1] >= 1334 and made[i] - made[i - 1] <= 1337
	_ok("and one every 1334 or so after, the next log taking a tick to come in (%d made)" % made.size(), even)
	# 320 MJ at 60 kW: 13333.3 ticks, 22 min 13 s; a tick idle between two
	# logs burns a fifth, so the log lasts a few ticks more than that
	_ok("a log under a working retort lasts 22 min (%d ticks)" % dim, dim >= 13334 and dim <= 13334 + 12)
	_tick(sim)
	_ok("the retort only pauses when the fire dims", retort.inp == "log" and float(retort.work) > 0.0 and float(retort.work) < 1.0 and retort.share == 0.0)
	var held: float = retort.work
	_run(sim, 100)
	_ok("and keeps what it had done", retort.work == held)
	var coal := 0
	for t: Vector2i in sim.items:
		for it: Dictionary in sim.items[t]:
			coal += 1 if it.kind == "charcoal" else 0
	_ok("the charcoal rode off and no log was lost", _all(sim) == 12 - 1 and coal == made.size() and _lying(sim, Vector2i(15, 4)) == 2)
	_ok("a retort turns from its card if its front has room", sim.turn(Vector2i(9, 4)) and retort.facing == 1 and sim.front_of(retort) == Vector2i(9, 5) and sim.module_at(Vector2i(10, 4)).is_empty())

	# heat does not cross a seam: a fire on the plate bought, a retort on the first
	sim = _open()
	sim.place("firebox", Vector2i(8, 0), 0)
	sim.place("retort", Vector2i(6, 0), 0)
	sim.lay_belt(Vector2i(8, 1), 3)
	sim.lay_belt(Vector2i(5, 0), 0)
	sim.put(Vector2i(8, 1), "log")
	sim.put(Vector2i(5, 0), "log")
	_run(sim, 420)
	sim.tap(Vector2i(8, 0))
	_run(sim, 50)
	retort = sim.module_at(Vector2i(6, 0))
	_ok("heat does not cross to another plate", sim.module_at(Vector2i(8, 0)).lit and retort.inp == "log" and retort.share == 0.0 and retort.work == 0.0 and sim.cycle_seconds(retort) == -1.0)

func _check_shared() -> void:
	var sim := _open()
	var fire_at := Vector2i(10, 3)
	sim.place("firebox", fire_at, 0)
	sim.place("retort", Vector2i(9, 4), 0)
	_ok("a second retort on the fire's other side", sim.place("retort", Vector2i(9, 2), 0))
	var fire: Dictionary = sim.module_at(fire_at)
	var low: Dictionary = sim.module_at(Vector2i(9, 4))
	var high: Dictionary = sim.module_at(Vector2i(9, 2))
	sim.lay_belt(Vector2i(8, 4), 0)
	sim.lay_belt(Vector2i(8, 2), 0)
	sim.lay_belt(Vector2i(11, 3), 2)
	sim.put(Vector2i(8, 4), "log")
	sim.put(Vector2i(8, 4), "log")
	sim.put(Vector2i(8, 2), "log")
	sim.put(Vector2i(11, 3), "log")
	_run(sim, 420)
	_ok("each holds a log, one more waits behind the first, and the fire has its own", low.inp == "log" and high.inp == "log" and fire.hopper == ["log"] and _lying(sim, Vector2i(8, 4)) == 1)
	sim.tap(fire_at)
	_tick(sim)
	# the ledger, section 4: supply over demand. Two sinks of 60 kW on a fire
	# of 60: each runs at a half.
	_ok("two retorts on one fire run at a half each", is_equal_approx(low.share, 0.5) and is_equal_approx(high.share, 0.5) and is_equal_approx(fire.draw, 60.0))
	_ok("and their cards say twice as long", is_equal_approx(sim.cycle_seconds(low), 2.0 * 133.3333333) and is_equal_approx(sim.cycle_seconds(high), 2.0 * 133.3333333))
	# a retort is 32 MJ: 1333.3 ticks at full heat, 2666.7 at a half
	var ticks := 1 + _until(sim, "made", 3000)
	_ok("the charcoal comes at 2667 ticks, not 1334 (%d)" % ticks, absi(ticks - 2667) <= 1)
	_ok("it lies past each retort's front", _lying(sim, Vector2i(11, 2)) == 1 and sim.items[Vector2i(11, 2)][0].kind == "charcoal" and high.out == ""
		and _lying(sim, Vector2i(11, 4)) == 1 and sim.items[Vector2i(11, 4)][0].kind == "charcoal" and low.out == "")
	_tick(sim)
	# the one with nothing left asks a fifth: 60 + 12 = 72 over 60
	_ok("one idle, the other has 60 over 72", low.inp == "log" and high.inp == "" and is_equal_approx(low.share, 60.0 / 72.0) and is_equal_approx(fire.draw, 60.0))
	# levels: 90 and 120 kW for 60 and 180
	sim.put(Vector2i(8, 2), "log")
	_run(sim, 30)
	var coins: int = sim.coins
	_ok("the fire's second level is 60", sim.upgrade_price(fire_at) == 60 and sim.upgrade(fire_at) and sim.coins == coins - 60 and fire.level == 2)
	_tick(sim)
	_ok("at 90 kW each has three quarters", is_equal_approx(low.share, 0.75) and is_equal_approx(high.share, 0.75) and is_equal_approx(fire.draw, 90.0))
	_ok("the third is 180", sim.upgrade_price(fire_at) == 180 and sim.upgrade(fire_at) and fire.level == 3)
	_tick(sim)
	_ok("at 120 kW each has all it asks", is_equal_approx(low.share, 1.0) and is_equal_approx(high.share, 1.0) and is_equal_approx(fire.draw, 120.0))
	_ok("and there is no fourth, nor a level on a retort", sim.upgrade_price(fire_at) == -1 and not sim.upgrade(fire_at) and sim.upgrade_price(Vector2i(9, 4)) == -1)
	coins = sim.coins
	_ok("sold, the fire returns all 260 paid on it", sim.sell_price(fire_at) == 260 and sim.sell(fire_at) and sim.coins == coins + 260 and sim.module_at(fire_at).is_empty())
	_tick(sim)
	_ok("and the machines it fed pause", low.share == 0.0 and high.share == 0.0)

	# a second fire: a sink between two has the sum of the shares, held to one
	sim = _open()
	sim.place("firebox", Vector2i(10, 3), 0)
	sim.place("firebox", Vector2i(10, 5), 0)
	sim.place("retort", Vector2i(9, 4), 0)
	sim.lay_belt(Vector2i(8, 4), 0)
	sim.put(Vector2i(8, 4), "log")
	sim.lay_belt(Vector2i(10, 2), 1)
	sim.lay_belt(Vector2i(10, 6), 3)
	sim.put(Vector2i(10, 2), "log")
	sim.put(Vector2i(10, 6), "log")
	_run(sim, 420)
	sim.tap(Vector2i(10, 3))
	sim.tap(Vector2i(10, 5))
	_tick(sim)
	_ok("a retort between two fires runs no faster than its rating", sim.module_at(Vector2i(10, 3)).lit and sim.module_at(Vector2i(10, 5)).lit
		and sim.working(sim.module_at(Vector2i(9, 4))) and is_equal_approx(sim.module_at(Vector2i(9, 4)).share, 1.0))

	# a machine's output goes into the next machine's back, a hopper or the market
	sim = _open()
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
	var sim := _open()
	var fire_at := Vector2i(10, 3)
	sim.place("firebox", fire_at, 0)
	sim.place("retort", Vector2i(9, 4), 0)
	_belt_row(sim, Vector2i(10, 0), 3, 1)
	for y in 3:
		sim.put(Vector2i(10, y), "log")
		sim.put(Vector2i(10, y), "log")
	sim.lay_belt(Vector2i(8, 4), 0)
	sim.put(Vector2i(8, 4), "log")
	sim.put(Vector2i(8, 4), "log")
	_run(sim, 500)
	var fire: Dictionary = sim.module_at(fire_at)
	var retort: Dictionary = sim.module_at(Vector2i(9, 4))
	_ok("a hopper of five, a retort with a log", fire.hopper.size() == 5 and retort.inp == "log" and _all(sim) == 8)
	var coins: int = sim.coins
	sim.events.clear()
	_ok("a retort sold returns its 40", sim.sell(Vector2i(10, 4)) and sim.coins == coins + 40 and sim.modules.size() == 1)
	_ok("and says so", sim.events[0].type == "sold_back" and sim.events[0].amount == 40 and sim.events[0].items == 1)
	_ok("its log lies on its tile", _lying(sim, Vector2i(9, 4)) == 1 and sim.items[Vector2i(9, 4)][0].kind == "log" and _all(sim) == 8)
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
	_ok("there is nothing to sell on bare ground, nor on a forest", not sim.sell(Vector2i(12, 6)) and _refused(sim, "nothing") and not sim.sell(IN) and _refused(sim, "nothing")
		and sim.sell_price(IN) == 0)
	# a module placed where things lie moves them aside, and a short purse buys nothing
	_ok("a firebox goes where the logs lie", sim.place("firebox", fire_at, 0) and _lying(sim, fire_at) == 0 and _all(sim) == 8)
	sim.coins = 39
	_ok("39 coins do not buy a retort", not sim.place("retort", Vector2i(12, 6), 0) and _refused(sim, "coins") and sim.coins == 39)
	_ok("nor does a retort fit half in the pond", not sim.can_place("retort", Vector2i(15, 6), 0) and sim.can_place("retort", Vector2i(15, 6), 2))
	# what a machine by a forest held is never spilled into the forest
	sim = _open()
	sim.place("firebox", PAST, 0)
	_run(sim, 200)
	for i in 5:
		sim.tap(IN)
	_run(sim, 10)
	sim.sell(PAST)
	var out := true
	for t: Vector2i in sim.items:
		out = out and not sim.is_forest(t) and sim.items[t].size() <= 2
	_ok("a hopper sold beside a forest spills on open ground, never into the forest", out and _all(sim) == 5 and _stock(sim) == 0)

func _check_kept() -> void:
	# a land with a bit of everything on it, mid motion
	var sim := _open()
	var west := Vector2i(-1, 0)
	sim.buy_plate(Vector2i(0, 1), "neutral")
	sim.buy_plate(west, "forest")
	sim.place("firebox", Vector2i(10, 3), 0)
	sim.place("retort", Vector2i(9, 4), 0)
	sim.place("retort", Vector2i(9, 2), 0)
	sim.lay_belt(Vector2i(8, 4), 0)
	sim.lay_belt(Vector2i(8, 2), 0)
	sim.lay_belt(Vector2i(11, 3), 2)
	sim.put(Vector2i(8, 4), "log")
	sim.put(Vector2i(8, 2), "log")
	sim.put(Vector2i(11, 3), "log")
	sim.put(Vector2i(11, 3), "log")
	_way(sim)
	_belt_row(sim, Vector2i(0, 7), 6, 0)
	_belt_row(sim, Vector2i(11, 4), 4, 0)
	for x in 6:
		sim.put(Vector2i(x, 7), "stone")
	_run(sim, 420)
	sim.tap(Vector2i(10, 3))
	for i in 5:
		sim.tap(IN)
	sim.tap(Vector2i(-4, 4))
	sim.upgrade("market")
	# the first forest makes its own from here: the land's dice are in the save
	sim.upgrade(IN)
	sim.picked = "belt"
	_run(sim, 777)
	for i in 3:
		sim.tap(Vector2i(-4, 4))
	_run(sim, 13)
	sim.step(0.04)
	sim.save()
	_ok("a save clears dirty", not sim.dirty)
	_ok("the land saved has a forest at work, one by hand, logs lying and riding, a fire lit", int(sim.forests[F].level) == 1 and _stock(sim) > 0 and int(sim.forests[west].level) == 0
		and _lying(sim, Vector2i(0, 4)) == 2 and _lying(sim, PAST) > 0 and sim.module_at(Vector2i(10, 3)).lit and sim.earned > 0)
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
	var kept: Dictionary = back.pack()
	_ok("the save is version 2 and holds the forests, and nothing of the land that was", kept.version == 2 and Sim.VERSION == 2 and kept.has("forests") and kept.forests.size() == 2
		and not kept.has("rocks") and not kept.has("queue") and not kept.has("sprout") and not kept.has("falls"))
	back.save()
	var b := FileAccess.get_file_as_string(Sim.path)
	_ok("which saves as the same file", a == b)
	sim.events.clear()
	sim.step(0.0)
	sim.step(-1.0)
	_ok("stepping no time changes nothing", var_to_str(sim.pack()) == var_to_str(back.pack()) and sim.events.is_empty())
	sim.save()
	_ok("nor does saving again", FileAccess.get_file_as_string(Sim.path) == a)
	# the two play on alike: ten minutes of a forest making its own, taps and sales
	var same := true
	for i in 6000:
		sim.step(Sim.TICK)
		back.step(Sim.TICK)
		if i % 600 == 0:
			for t: Vector2i in [IN, Vector2i(-4, 4), Vector2i(-2, 6)]:
				sim.tap(t)
				back.tap(t)
			same = same and var_to_str(sim.pack()) == var_to_str(back.pack())
	_ok("and the land read back plays on as the land saved does", same and var_to_str(sim.pack()) == var_to_str(back.pack()) and sim.coins == back.coins and _all(sim) == _all(back))
	_ok("a long frame is a quarter of a second at most", _long_frame())
	# a land of the first version: the very land above, marked 1
	var fresh: RefCounted = Sim.new(3)
	var was := var_to_str(fresh.pack())
	var old: Dictionary = sim.pack()
	old.version = 1
	_write(old, 1)
	_ok("a land of the first version is refused, and the sim is left alone", not fresh.load_saved() and var_to_str(fresh.pack()) == was)
	old.version = Sim.VERSION
	_write(old, Sim.VERSION)
	var again: RefCounted = Sim.new(3)
	_ok("the same land marked 2 is read: the version alone refused it", again.load_saved() and var_to_str(again.pack()) == var_to_str(sim.pack()))
	# what a first-version land was: a forest under the market, nothing behind it
	var shaped: Dictionary = sim.pack()
	shaped.plates[Vector2i.ZERO] = "forest"
	_write(shaped, Sim.VERSION)
	_ok("a land whose first plate is a forest is refused whatever it is marked", not fresh.load_saved() and var_to_str(fresh.pack()) == was)
	shaped = sim.pack()
	shaped.plates[Vector2i(1, 0)] = "quarry"
	_write(shaped, Sim.VERSION)
	_ok("so is one with a kind of land there is none of", not fresh.load_saved() and var_to_str(fresh.pack()) == was)
	shaped = sim.pack()
	shaped.forests.erase(west)
	_write(shaped, Sim.VERSION)
	_ok("and one with a forest that keeps no stock", not fresh.load_saved() and var_to_str(fresh.pack()) == was)
	# no file, and a file that is not a land
	DirAccess.remove_absolute(Sim.path)
	_ok("no file is no land, and the sim is left alone", not fresh.load_saved() and var_to_str(fresh.pack()) == was)
	var f := FileAccess.open(Sim.path, FileAccess.WRITE)
	f.store_string("[factory]\nversion=2\nstate=\"%s\"\n" % Marshalls.variant_to_base64({"version": 2, "coins": "many"}))
	f.close()
	_ok("a file that is not a land is refused", not fresh.load_saved() and var_to_str(fresh.pack()) == was)
	f = FileAccess.open(Sim.path, FileAccess.WRITE)
	f.store_string("[factory]\nstate=\"bm90IGEgbGFuZA==\"\n")
	f.close()
	_ok("so are bytes that are no land", not fresh.load_saved() and var_to_str(fresh.pack()) == was)
	f = FileAccess.open(Sim.path, FileAccess.WRITE)
	f.store_string("not a config at all {{{")
	f.close()
	_ok("and so is nonsense", not fresh.load_saved() and var_to_str(fresh.pack()) == was)

## A land's Dictionary into the throwaway file, as `save()` writes one.
func _write(land: Dictionary, version: int) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("factory", "version", version)
	cfg.set_value("factory", "state", Marshalls.variant_to_base64(land))
	cfg.save(Sim.path)

func _long_frame() -> bool:
	var sim: RefCounted = Sim.new(7)
	sim.tap(IN)
	sim.events.clear()
	sim.step(3600.0)
	# an hour's hitch is two ticks and a half: the one log is out of its gate
	# and nothing else has happened
	return sim.events.size() == 1 and sim.events[0].type == "log" and is_equal_approx(sim.alpha, 0.5) and _stock(sim) == 0 and _lying(sim, PAST) == 1

# --- the pace bot ---

## A new land played by a player who does one thing a second: a tap on the
## forest, the nine belts from the gate to the market once the coins reach
## (they do at once: a new land has twenty), the forest's first level the
## moment it can be bought, then the first plate, neutral ground beside the
## market's. It never raises the market, so every coin is one log sold at a
## new market's rate.
func _pace(first_seed: int, lands: int) -> void:
	var levels: Array[float] = []
	var bought: Array[float] = []
	for k in lands:
		var sim: RefCounted = Sim.new(first_seed + k)
		var ticks := 0
		var taps := 0
		var laid := false
		var level := -1
		var plate := -1
		while plate < 0 and ticks < 3 * 36000:
			sim.step(Sim.TICK)
			ticks += 1
			if ticks % 10 != 0:
				continue
			if sim.tap(Sim.FOREST_AT * Sim.PLATE + Vector2i(4, 4)):
				taps += 1
			if not laid and sim.coins >= 9 * sim.price("belt"):
				_way(sim)
				laid = sim.belts.size() == 9
			if level < 0:
				if laid and sim.coins >= sim.upgrade_price(IN) and sim.upgrade(IN):
					level = ticks
			elif sim.coins >= sim.plate_price() and sim.buy_plate(Vector2i(1, 0), "neutral"):
				plate = ticks
			sim.events.clear()
		if level < 0 or plate < 0:
			print("pace seed %d: not done in three hours (level at tick %d, plate at tick %d, %d coins)" % [first_seed + k, level, plate, sim.coins])
			_fails += 1
			continue
		levels.append(level / 600.0)
		bought.append(plate / 600.0)
		print("pace seed %d: the forest's first level at play-minute %.1f, the first plate at %.1f (%d taps taken, %d logs sold)" % [first_seed + k, level / 600.0, plate / 600.0, taps, sim.earned])
	if levels.is_empty():
		return
	print("pace: the forest's first level at play-minute %.1f, the mean of %d lands (least %.1f, most %.1f)" % [_mean(levels), levels.size(), levels.min(), levels.max()])
	print("pace: the first plate bought at play-minute %.1f, the mean of %d lands (least %.1f, most %.1f)" % [_mean(bought), bought.size(), bought.min(), bought.max()])

func _mean(of: Array[float]) -> float:
	var sum := 0.0
	for v: float in of:
		sum += v
	return sum / of.size()
