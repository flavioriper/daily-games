extends SceneTree

## The Grove and the shared inventory, headless: the arithmetic first, then
## a bot at the real sim to say how slow the numbers are.
##
##     godot --headless --path . --script res://tests/_probe_grove.gd
##     godot --headless --path . --script res://tests/_probe_grove.gd -- pace [visits a day] [seconds a visit] [days] [ids never bought]
##     godot --headless --path . --script res://tests/_probe_grove.gd -- marathon [hours]
##
## The checks: Stock adds, pays all or nothing and keeps its file; a new
## grove is one sapling that takes Sim.HP chops and gives one wood and one
## energy; a tile costs what the table says and a capped one stops; a grove
## saved and read back is the same grove; time away fills the land and no
## further, and a clock set back grows nothing. `pace` plays days of short
## visits with a player who always buys the cheapest node it can (the shop's
## or the tree's; the optional last argument is a comma list of ids or parts,
## `soft,rich`, that it never buys), and prints where that player stands; `marathon` plays without stopping. Everything
## runs on throwaway files.

const Sim = preload("res://valley/grove_sim.gd")
const DT := 1.0 / 30.0
## The bot lifts its finger this long after a tree comes down.
const TRAVEL := 0.3

var _fails := 0
var _checks := 0

func _initialize() -> void:
	var dir := OS.get_user_data_dir()
	var stock: Node = root.get_node("Stock")
	stock.path = dir + "/_probe_stock.cfg"
	DirAccess.remove_absolute(stock.path)
	stock.reload()
	Sim.path = dir + "/_probe_grove.cfg"
	DirAccess.remove_absolute(Sim.path)
	var args := OS.get_cmdline_user_args()
	if args.has("pace"):
		_pace(int(args[1]) if args.size() > 1 else 8, float(args[2]) if args.size() > 2 else 120.0, int(args[3]) if args.size() > 3 else 30,
			(args[4] as String).split(",") if args.size() > 4 else PackedStringArray())
	elif args.has("marathon"):
		_pace(1, (float(args[1]) if args.size() > 1 else 2.0) * 3600.0, 1, PackedStringArray())
	else:
		_check_stock(stock)
		_check_sim()
		print("probe_grove: %d checks, %d failed" % [_checks, _fails])
	DirAccess.remove_absolute(stock.path)
	DirAccess.remove_absolute(Sim.path)
	quit(1 if _fails > 0 else 0)

func _ok(what: String, yes: bool) -> void:
	_checks += 1
	if not yes:
		_fails += 1
		print("FAIL ", what)

func _check_stock(stock: Node) -> void:
	_ok("an empty stock holds no wood", stock.count("wood") == 0)
	stock.add("wood", 5, "probe")
	stock.add("wood", 0, "probe")
	stock.add("wood", -3, "probe")
	_ok("wood adds, and nothing or less than nothing does not", stock.count("wood") == 5)
	_ok("a cost held can be paid", stock.can_pay({"wood": 5}))
	_ok("a cost not held cannot", not stock.can_pay({"wood": 6}) and not stock.can_pay({"wood": 1, "planks": 1}))
	_ok("a cost that is short takes nothing", not stock.pay({"wood": 2, "planks": 1}) and stock.count("wood") == 5)
	_ok("a cost that is held is taken", stock.pay({"wood": 2}) and stock.count("wood") == 3)
	stock.flush()
	stock.reload()
	_ok("the stock is kept on its file", stock.count("wood") == 3)

func _check_sim() -> void:
	var sim: RefCounted = Sim.new(7)
	_ok("a new grove is one sapling", sim.trees.size() == 1 and int(sim.trees[0].tier) == 0)
	_ok("a sapling starts at four", Sim.hp_of(0) == 4 and int(sim.trees[0].hp) == 4)
	_ok("room for three, a tree back in six seconds, half a second a chop", sim.room() == 3 and is_equal_approx(sim.spawn_time(), 6.0) and is_equal_approx(sim.swing_time(), 0.5))
	var at: Vector2 = sim.trees[0].pos + Vector2(0.0, -Sim.RADIUS[0])
	var swings := 0
	var fell := 0
	var t := 0.0
	while fell == 0 and t < 10.0:
		sim.step(DT, true, at)
		t += DT
		for e: Dictionary in sim.events:
			if e.kind == "swing" and int(e.hits) > 0:
				swings += 1
			elif e.kind == "fell":
				fell += int(e.give)
		sim.events.clear()
	_ok("four chops fell the first tree (%d)" % swings, swings == 4)
	_ok("it gives one wood and one energy", fell == 1 and sim.energy == 1 and sim.wood_made == 1)
	_ok("a chop off the land hits nothing", _swing_hits(sim, Vector2(-500, -500)) == 0)
	for tile: String in Sim.NODE:
		var row: Array = Sim.NODE[tile]
		_ok("%s starts at its first price" % tile, sim.cost(tile) == int(round(float(row[0]))))
	_ok("a tile is not bought on credit", not sim.buy("axe") and int(sim.lv.axe) == 0)
	sim.energy = 10
	_ok("ten energy buys the first axe", sim.buy("axe") and sim.energy == 0 and is_equal_approx(sim.power(), 1.5))
	_ok("and the next costs more", sim.cost("axe") == int(round(10.0 * 1.38)))
	sim.energy = 1 << 60
	while sim.buy("room"):
		pass
	_ok("room stops at its last level", sim.is_done("room") and sim.room() == Sim.ROOM + 27 and not sim.can_buy("room"))
	for i in 40:
		sim.buy("axe")
		sim.buy("seeds")
	_ok("axe and seeds never stop", not sim.is_done("axe") and not sim.is_done("seeds") and int(sim.lv.seeds) > 6)
	_ok("a richer tree asks more than it pays", float(Sim.hp_of(6)) / Sim.hp_of(5) > float(Sim.give_of(6)) / Sim.give_of(5))
	_ok("the looks come round after the fifth", Sim.look_of(4) == 4 and Sim.look_of(5) == 1 and Sim.look_of(8) == 4 and Sim.look_of(9) == 1 and Sim.lap_of(4) == 0 and Sim.lap_of(5) == 1 and Sim.lap_of(9) == 2)
	# kept, and read back
	var a: RefCounted = Sim.new(3)
	a.energy = 77
	a.lv.axe = 4
	a.lv.room = 6
	a.lv.seeds = 2
	for i in 400:
		a.step(0.25)
	var stood: int = a.trees.size()
	a.save(1000.0)
	var b: RefCounted = Sim.load_saved(1000.0)
	_ok("a grove read back is the grove kept", b.energy == 77 and int(b.lv.axe) == 4 and b.trees.size() == stood and b.room() == a.room())
	var same := true
	for i in stood:
		same = same and (b.trees[i].pos as Vector2).is_equal_approx(a.trees[i].pos) and int(b.trees[i].tier) == int(a.trees[i].tier) and is_equal_approx(float(b.trees[i].hp), float(a.trees[i].hp))
	_ok("tree for tree", same)
	# away
	var c: RefCounted = Sim.new(5)
	c.lv.room = 9
	c.trees.clear()
	c.save(5000.0)
	var back: RefCounted = Sim.load_saved(5000.0 - 600.0)
	_ok("a clock set back grows nothing", back.trees.size() == 0)
	var soon: RefCounted = Sim.load_saved(5000.0 + 5.0)
	_ok("five seconds away is no tree yet", soon.trees.size() == 0)
	var filled: RefCounted = Sim.load_saved(5000.0 + 7.0)
	_ok("seven is all twelve: every place counted its own six seconds (%d)" % filled.trees.size(), filled.trees.size() == 12)
	var later: RefCounted = Sim.load_saved(5000.0 + 86400.0 * 30.0)
	_ok("a month away fills the land and no further", later.trees.size() == later.room() and later.room() == 12)
	var gone: RefCounted = Sim.load_saved(1.0)
	DirAccess.remove_absolute(Sim.path)
	var fresh: RefCounted = Sim.load_saved(1.0)
	_ok("no file is a new grove", fresh.trees.size() == 1 and fresh.energy == 0 and gone != null)
	# every felled tree's place counts from the moment it came down
	var d: RefCounted = Sim.new(11)
	d.lv.room = 2
	d.catch_up(100.0)
	for tree: Dictionary in d.trees:
		tree.pos = Sim.LAND * 0.5
		tree.hp = 1.0
	var down := 0
	d.step(DT, true, Sim.LAND * 0.5)
	for e: Dictionary in d.events:
		if e.kind == "fell":
			down += 1
	d.events.clear()
	_ok("five trees stood and one chop felled them all (%d)" % down, down == 5 and d.trees.is_empty())
	var waited := 0.0
	while waited < d.spawn_time() - 0.2:
		d.step(DT)
		waited += DT
	_ok("none is back before the six seconds are up", d.trees.is_empty())
	for i in 12:
		d.step(DT)
	_ok("all five are back six seconds on, not thirty (%d)" % d.trees.size(), d.trees.size() == 5)
	# and one felled later comes back later: its own six seconds
	var e2: RefCounted = Sim.new(12)
	e2.catch_up(100.0)
	e2.trees[0].hp = 1.0
	e2.step(DT, true, e2.trees[0].pos)
	for i in int(3.0 / DT):
		e2.step(DT)
	e2.trees[0].hp = 1.0
	e2.step(DT, true, e2.trees[0].pos)
	for i in int(3.2 / DT):
		e2.step(DT)
	_ok("a tree felled three seconds after another is three behind it (%d)" % e2.trees.size(), e2.trees.size() == 2)
	for i in int(3.0 / DT):
		e2.step(DT)
	_ok("and back three seconds after it", e2.trees.size() == 3)
	e2.energy = 1 << 40
	e2.trees.clear()
	e2.step(DT)
	e2.buy("sprout")
	var longest := 0.0
	for left: float in e2._due:
		longest = maxf(longest, left)
	_ok("a quicker Sprout shortens the places already counting", longest <= e2.spawn_time() + 0.001)
	var spots := {}
	for i in 30:
		var s: RefCounted = Sim.new()
		spots["%d,%d" % [int(s.trees[0].pos.x), int(s.trees[0].pos.y)]] = true
	_ok("trees come up at random spots (%d of 30)" % spots.size(), spots.size() > 20)
	_check_tree()

## The tree: nodes, the trunk and the boughs, and what is kept.
func _check_tree() -> void:
	# a grove kept with Sprout, Room and Seeds keeps them, and its trunk
	var old: RefCounted = Sim.new(21)
	old.lv.sprout = 9
	old.lv.room = 12
	old.lv.seeds = 3
	old.save(2000.0)
	var kept: RefCounted = Sim.load_saved(2000.0)
	_ok("a kept sprout 9, room 12 and seeds 3 come back", int(kept.lv.sprout) == 9 and int(kept.lv.room) == 12 and int(kept.lv.seeds) == 3)
	var wanted := ["kind:0", "kind:1", "kind:2", "kind:3", "kind:4"]
	var drawn: Array[String] = kept.shown()
	var all := true
	for id in wanted:
		all = all and drawn.has(id)
	_ok("and its trunk is drawn from kind:0 to kind:4, no further", all and not drawn.has("kind:5") and not drawn.has("axe"))
	var fresh: RefCounted = Sim.new(22)
	_ok("Sprout is not open on a new grove", not fresh.is_open("sprout") and fresh.is_open("room"))
	fresh.energy = 100
	fresh.buy("room")
	_ok("and is once Room has a level", fresh.is_open("sprout"))
	_ok("a kept Sprout stays open whatever Room is", kept.is_open("sprout"))
	# the boughs
	var soft: RefCounted = Sim.new(23)
	soft.energy = 10
	_ok("the Sapling's Soft bough costs half its price", soft.cost("soft:0") == 10 and soft.buy("soft:0"))
	_ok("and a sapling is three chops of one", is_equal_approx(soft.hp(0), 3.0) and is_equal_approx(float(soft.trees[0].hp), 3.0))
	var rich: RefCounted = Sim.new(24)
	rich.lv.seeds = 1
	rich.energy = 1000
	_ok("a birch gives 2, 3, then 4 with its Rich bough", rich.give(1) == 2 and rich.buy("rich:1") and rich.give(1) == 3 and rich.buy("rich:1") and rich.give(1) == 4 and not rich.can_buy("rich:1"))
	var chosen: RefCounted = Sim.new(25)
	chosen.energy = 1000
	_ok("the Sapling's Rich bough is one level and doubles it", chosen.buy("rich:0") and chosen.give(0) == 2 and chosen.is_done("rich:0"))
	var dear: RefCounted = Sim.new(26)
	_ok("an Oak's Soft bough costs half of 840", dear.cost("soft:2") == int(round(0.5 * 840.0)))
	# the trunk is bought in order
	var trunk: RefCounted = Sim.new(27)
	trunk.energy = 1 << 40
	_ok("kind:2 cannot be bought before kind:1", not trunk.buy("kind:2") and trunk.buy("kind:1") and int(trunk.lv.seeds) == 1 and trunk.is_done("kind:1") and trunk.is_done("kind:0"))
	_ok("and `seeds` is the next kind", trunk.cost("seeds") == 840 and trunk.buy("seeds") and int(trunk.lv.seeds) == 2)
	_ok("a Soft bough is open once its kind is", not trunk.is_open("soft:3") and trunk.is_open("soft:2") and trunk.is_open("soft:0"))
	# the boughs are kept
	trunk.buy("soft:1")
	trunk.buy("soft:1")
	trunk.buy("rich:2")
	trunk.buy("jetty")
	trunk.save(3000.0)
	var back: RefCounted = Sim.load_saved(3000.0)
	_ok("the boughs and every node are kept", back.level("soft:1") == 2 and back.level("rich:2") == 1 and back.level("jetty") == 1 and back.level("soft:2") == 0 and is_equal_approx(back.hp(1), 5.0))


func _swing_hits(sim: RefCounted, at: Vector2) -> int:
	var hits := -1
	var t := 0.0
	while hits < 0 and t < 2.0:
		sim.step(DT, true, at)
		t += DT
		for e: Dictionary in sim.events:
			if e.kind == "swing":
				hits = int(e.hits)
		sim.events.clear()
	return hits

## Days of `visits` short visits, `secs` each, evenly through sixteen waking
## hours, by a player who holds the circle on the oldest tree and buys the
## cheapest node it can afford, in the shop or the tree, except any whose id
## or part (`soft` of `soft:2`) is in `never`.
func _pace(visits: int, secs: float, days: int, never: PackedStringArray) -> void:
	var sim: RefCounted = Sim.new(1)
	var gap := 16.0 * 3600.0 / visits
	var played := 0.0
	var seeds_at := []
	print("pace: %d visits a day of %d s, %d days%s" % [visits, int(secs), days, ", never " + ",".join(never) if never.size() > 0 else ""])
	for day in days:
		for v in visits:
			sim.catch_up(gap if v > 0 else 8.0 * 3600.0)
			var t := 0.0
			var rest := 0.0
			while t < secs:
				var hold: bool = rest <= 0.0 and not sim.trees.is_empty()
				var at := Vector2.ZERO
				if hold:
					at = sim.trees[0].pos + Vector2(0.0, -Sim.radius_of(sim.trees[0].tier))
				sim.step(DT, hold, at)
				rest -= DT
				t += DT
				for e: Dictionary in sim.events:
					if e.kind == "fell":
						rest = TRAVEL
				sim.events.clear()
				while true:
					var best := ""
					var ids: Array[String] = sim.shown()
					ids.append_array(Sim.SHOP)
					for id: String in ids:
						if never.has(id) or never.has(Sim.part_of(id)):
							continue
						if sim.can_buy(id) and (best == "" or sim.cost(id) < sim.cost(best)):
							best = id
					if best == "":
						break
					sim.buy(best)
					if Sim.part_of(best) == "kind":
						seeds_at.append("seeds %d on day %d (%.1f h played)" % [int(sim.lv.seeds), day + 1, (played + t) / 3600.0])
			played += secs
		if (day + 1) in [1, 2, 3, 5, 7, 10, 14, 21, 30, 45, 60, 90] or day == days - 1:
			var boughs := 0
			for tier in sim.soft.size():
				boughs += sim.soft[tier]
			var rich := 0
			for tier in sim.rich.size():
				rich += sim.rich[tier]
			var rest_of := ""
			for root: String in Sim.ROOT_ORDER:
				for id: String in Sim.ROOTS[root]:
					if id != "room" and id != "sprout" and sim.level(id) > 0:
						rest_of += " %s %d" % [id, sim.level(id)]
			print("day %d: axe %d reach %d swing %d sprout %d room %d seeds %d | soft %d rich %d |%s | wood %d energy %d | %.1f h played" % [day + 1,
				int(sim.lv.axe), int(sim.lv.reach), int(sim.lv.swing), int(sim.lv.sprout), int(sim.lv.room), int(sim.lv.seeds),
				boughs, rich, rest_of if rest_of != "" else " -", sim.wood_made, sim.energy, played / 3600.0])
	for line: String in seeds_at:
		print(line)
