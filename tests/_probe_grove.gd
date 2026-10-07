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
## energy; a node costs what the table says and a capped one stops; a grove
## saved and read back is the same grove; time away fills the land and no
## further, and a clock set back grows nothing; the tree's nodes open in
## their order; a felled tree's wood lies, is gathered, tied and rafted and
## is nobody's until the raft lands it; beavers, keen chops, lucky wood and
## crates do what their nodes say; a file kept before the jetty, or with
## nonsense in it, loads. `pace` plays days of short visits with a player who
## always buys the cheapest node it can (the shop's or the tree's; the
## optional last argument is a comma list of ids or parts, `soft,rich`, that
## it never buys), and prints where that player stands, with the wood felled
## beside the wood the raft delivered; `marathon` plays without stopping.
## Everything runs on throwaway files.

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
		_check_jetty(stock)
		_check_skills()
		_check_kept()
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
	_ok("it gives one energy and makes one wood", fell == 1 and sim.energy == 1 and sim.wood_made == 1)
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
	# a grove kept with Sprout bought and Room never: open by its own level alone
	var lone: RefCounted = Sim.new(22)
	lone.lv.sprout = 2
	_ok("a kept Sprout stays open whatever Room is", int(lone.lv.room) == 0 and lone.is_open("sprout") and not lone.is_open("bundle"))
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
	_ok("the Jetty root opens with the Raft, then the Jetty", Sim.ROOTS.jetty == ["raft", "jetty", "bundle", "tying", "load"] and not trunk.buy("jetty") and trunk.buy("raft") and trunk.buy("jetty"))
	trunk.save(3000.0)
	var back: RefCounted = Sim.load_saved(3000.0)
	_ok("the boughs and every node are kept", back.level("soft:1") == 2 and back.level("rich:2") == 1 and back.level("jetty") == 1 and back.level("soft:2") == 0 and is_equal_approx(back.hp(1), 5.0))


## The jetty: piles, the circle that gathers them, tying and the raft.
func _check_jetty(stock: Node) -> void:
	var had: int = stock.count("wood")
	var sim: RefCounted = Sim.new(31)
	var at: Vector2 = sim.trees[0].pos
	var fells: Array[Dictionary] = []
	var t := 0.0
	while fells.is_empty() and t < 10.0:
		fells = _of(_hold(sim, at, DT), "fell")
		t += DT
	_ok("a felled sapling leaves one pile of one wood", fells.size() == 1 and sim.logs.size() == 1 and int(sim.logs[0].n) == 1
		and int(sim.logs[0].wood) == 1 and sim.lying() == 1 and sim.jetty_held() == 0)
	_ok("felled by the axe, and by no luck", fells.size() == 1 and fells[0].by == "axe" and not fells[0].lucky and int(fells[0].give) == 1)
	_ok("and Stock is not touched", stock.count("wood") == had and sim.owed == 0 and sim.wood_sent == 0)
	# the swing that takes it is the first after it has lain LIES
	var seen := _hold(sim, at, Sim.LIES + sim.swing_time() + 0.2)
	var gathered := _of(seen, "gather")
	_ok("held on, it is gathered to the jetty once it has lain", sim.logs.is_empty() and sim.lying() == 0 and gathered.size() == 1 and int(gathered[0].n) == 1
		and int(gathered[0].wood) == 1 and sim.jetty_held() == 1 and int(sim.loose.wood) == 1 and stock.count("wood") == had)
	# a stack one pile bigger than the jetty has room for, a lucky pile in it
	var spot := Sim.LAND * 0.5
	var full: RefCounted = Sim.new(32)
	full.trees.clear()
	var room: int = full.jetty_room()
	for i in room + 1:
		full._drop(spot, 0, 2 if i == 0 else 1, i == 0)
	full.logs[0].born = -10.0
	_ok("%d piles on one spot are one stack, holding %d with a lucky one" % [room + 1, room + 2], room == Sim.JETTY and full.logs.size() == 1 and full.lying() == room + 1
		and int(full.logs[0].wood) == room + 2)
	_hold(full, spot, DT)
	_ok("a jetty of %d takes %d of them and the last stays lying" % [room, room], full.jetty_held() == room and full.lying() == 1)
	var on_land: int = int(full.logs[0].wood) if full.logs.size() == 1 else -1
	_ok("nothing is made or lost as the stack is shared (%d and %d)" % [int(full.loose.wood), on_land], on_land >= 1 and int(full.loose.wood) + on_land == room + 2)
	# the very next swing, before anything can be tied and leave
	full._last_chop = -10.0
	seen = _hold(full, spot, DT)
	_ok("a full jetty takes none, and says so", full.lying() == 1 and full.jetty_held() == room and _of(seen, "gather").is_empty() and _of(seen, "full").size() == 1)
	var fair := true
	for n in range(1, 9):
		for wood in range(n, 40):
			for take in range(0, n + 1):
				var got: int = Sim._share(wood, take, n)
				fair = fair and got >= take and wood - got >= n - take and (take < n or got == wood)
	_ok("a share of a stack is whole wood, a wood a pile at least on both sides", fair and Sim._share(3, 1, 2) == 1)
	var pair: RefCounted = Sim.new(34)
	pair.trees.clear()
	for i in 2:
		pair.trees.append({"id": 100 + i, "tier": 0, "pos": spot + Vector2(Sim.MERGE - 30.0, 0.0) * i, "hp": 1.0, "born": -Sim.GROW})
	_hold(pair, spot + Vector2(20.0, 0.0), DT)
	_ok("two fells nearer than MERGE are one stack of two", pair.felled == 2 and pair.logs.size() == 1 and int(pair.logs[0].n) == 2 and int(pair.logs[0].wood) == 2)
	var apart: RefCounted = Sim.new(34)
	apart.trees.clear()
	for i in 2:
		apart.trees.append({"id": 100 + i, "tier": 0, "pos": spot + Vector2(Sim.MERGE + 10.0, 0.0) * i, "hp": 1.0, "born": -Sim.GROW})
	_hold(apart, spot + Vector2(40.0, 0.0), DT)
	_ok("and two further apart are two piles", apart.felled == 2 and apart.logs.size() == 2)
	# the chain, all at once and a frame at a time, on a full jetty
	var once: RefCounted = Sim.new(33)
	var slow: RefCounted = Sim.new(33)
	var wood: int = room + 3
	once.loose = {"n": room, "wood": wood}
	slow.loose = {"n": room, "wood": wood}
	once._send(10000.0)
	var did_once := _chain(once.events)
	once.events.clear()
	var did_slow: Array[String] = []
	for i in 300000:
		slow._send(DT)
		if not slow.events.is_empty():
			did_slow.append_array(_chain(slow.events))
			slow.events.clear()
	_ok("ten thousand seconds empty a full jetty into what is owed", once.owed == wood and once.wood_sent == wood and once.jetty_held() == 0 and not once.raft.away and once.raft_at() == 0.0)
	_ok("and the same a frame at a time", slow.owed == wood and slow.wood_sent == wood and slow.jetty_held() == 0 and not slow.raft.away)
	_ok("bundle for bundle and landing for landing (%s)" % ", ".join(did_once), did_once.size() >= 3 and did_once == did_slow)
	_ok("what is owed is taken once", once.take_owed() == wood and once.owed == 0 and once.take_owed() == 0 and once.wood_sent == wood)
	# the raft: out for half its time, where its wood is counted, and back
	var out: RefCounted = Sim.new(36)
	var size: int = out.bundle_size()
	out.loose = {"n": size, "wood": size}
	out._send(out.tie_time() * 0.5)
	_ok("a bundle is not tied before its time", int(out.loose.n) == size and out.bundles.is_empty() and not out.raft.away)
	out._send(out.tie_time() * 0.5 + out.raft_time() * 0.25)
	_ok("tied, it leaves at once: the raft is half way out a quarter of its time later", is_equal_approx(out.raft_at(), 0.5) and int(out.raft.n) == size and int(out.raft.bundles) == 1
		and out.owed == 0 and out.jetty_held() == 0)
	out._send(out.raft_time() * 0.25)
	_ok("its wood is counted when it gets there, at half its time", out.owed == size and out.wood_sent == size and int(out.raft.n) == 0 and is_equal_approx(out.raft_at(), 1.0) and bool(out.raft.away))
	out._send(out.raft_time() * 0.25)
	_ok("it is on its way back, and landed nothing twice", bool(out.raft.away) and is_equal_approx(out.raft_at(), 0.5) and out.owed == size)
	out._send(out.raft_time() * 0.25)
	_ok("and home at the whole of it", not out.raft.away and out.raft_at() == 0.0 and out.owed == size)
	# whole bundles first; a short one only when the chain would stand still
	var some: RefCounted = Sim.new(35)
	size = some.bundle_size()
	var piles: int = 2 * size + 1
	while some.jetty_room() < piles:
		some.lv.jetty = int(some.lv.jetty) + 1
	some.loose = {"n": piles, "wood": piles}
	var tie: float = some.tie_time()
	var trip: float = some.raft_time()
	# the first leaves as it is tied; the second when it is tied and the
	# raft is back; the pile over is tied from the raft's next return
	var second := maxf(2.0 * tie, tie + trip)
	var want_at := [tie, second, second + trip + tie]
	var left := []
	var short_home := false
	t = 0.0
	while t < want_at[2] + trip + 1.0:
		var home: bool = not some.raft.away and some.bundles.is_empty()
		some._send(DT)
		t += DT
		for e: Dictionary in some.events:
			if e.kind == "sailed":
				left.append([t, int(e.n)])
			elif e.kind == "tied" and int(e.n) < size:
				short_home = home
		some.events.clear()
	_ok("%d piles leave as %d, %d and 1 (%s)" % [piles, size, size, str(left)], size > 1 and left.size() == 3 and left[0][1] == size and left[1][1] == size and left[2][1] == 1
		and some.wood_sent == piles and some.jetty_held() == 0)
	var on_time: bool = left.size() == 3
	for i in mini(left.size(), 3):
		on_time = on_time and absf(float(left[i][0]) - float(want_at[i])) < 0.1
	_ok("the one over only once the raft is home with nothing waiting (%s s)" % str(want_at), short_home and on_time)
	var fresh: RefCounted = Sim.new(37)
	var by_tying: float = 60.0 * fresh.bundle_size() / fresh.tie_time()
	var by_raft: float = 60.0 * fresh.bundle_size() * fresh.raft_load() / fresh.raft_time()
	_ok("a new grove's jetty sends the slower of tying (%.1f) and rafting (%.1f) piles a minute, a wood each (%.2f)" % [by_tying, by_raft, fresh.wood_per_min()], fresh.give(0) == 1
		and is_equal_approx(fresh.wood_per_min(), minf(by_tying, by_raft)))
	fresh.lv.luck = 5
	_ok("and luck's doubles with it", is_equal_approx(fresh.wood_per_min(), minf(by_tying, by_raft) * (1.0 + fresh.luck_chance())) and fresh.luck_chance() > 0.0)

## What the chain did, in order: "tied 4 5", "sailed 4 5", "landed 0 5".
func _chain(events: Array[Dictionary]) -> Array[String]:
	var out: Array[String] = []
	for e: Dictionary in events:
		if e.kind in ["tied", "sailed", "landed"]:
			out.append("%s %d %d" % [e.kind, int(e.get("n", 0)), int(e.wood)])
	return out

## Beavers, keen chops, lucky wood, crates, and kinds gone from the land.
func _check_skills() -> void:
	var b: RefCounted = Sim.new(41)
	b.lv.beaver = 1
	var want: float = b.hp(0) / (b.power() * b.bite())
	var seen: Array[Dictionary] = []
	var fells: Array[Dictionary] = []
	var t := 0.0
	while fells.is_empty() and t < 30.0:
		seen = _hold(b, Vector2.ZERO, DT, false)
		fells = _of(seen, "fell")
		t += DT
	_ok("one beaver and nobody holding: a sapling is down in hp / (power * bite) seconds (%.2f of %.1f)" % [t, want], absf(t - want) < 0.1 and fells.size() == 1 and fells[0].by == "beaver")
	var bites := _of(seen, "hit")
	_ok("its bite is its share of a chop and never keen", bites.size() == 1 and bites[0].by == "beaver" and not bites[0].keen and is_equal_approx(b.bite(), Sim.BITE)
		and is_equal_approx(float(bites[0].amount), b.power() * Sim.BITE))
	_ok("its pile lies: a beaver gathers nothing", b.lying() == 1 and b.jetty_held() == 0 and b.energy == 1)
	for i in 49:
		b._drop(b.logs[0].pos, 0, 1, false)
	var before: int = b.felled
	_hold(b, Vector2.ZERO, b.spawn_time() + want + 2.0, false)
	_ok("a beaver goes on biting with fifty piles lying (%d)" % b.lying(), b.felled > before and b.lying() > 50)
	var both: RefCounted = Sim.new(42)
	both.lv.beaver = 1
	_hold(both, Vector2.ZERO, 0.5, false)
	var mine: int = both.trees[0].id
	_ok("a beaver is at the oldest tree", int(both.gnawing[0].tree) == mine)
	both.trees[0].hp = 1.0
	fells = _of(_hold(both, both.trees[0].pos, DT), "fell")
	_ok("and rests when the axe fells it", fells.size() == 1 and fells[0].by == "axe" and int(both.gnawing[0].tree) == 0)
	var two: RefCounted = Sim.new(43)
	two.catch_up(100.0)
	two.lv.beaver = 2
	_hold(two, Vector2.ZERO, 0.2, false)
	_ok("two beavers are at the two oldest trees, a tree each", two.trees.size() == 3 and int(two.gnawing[0].tree) == int(two.trees[0].id) and int(two.gnawing[1].tree) == int(two.trees[1].id))
	# with nobody there (the Valley tab's card)
	var tab: RefCounted = Sim.new(52)
	tab.lv.beaver = 2
	tab.loose = {"n": tab.bundle_size(), "wood": tab.bundle_size()}
	var whole: float = tab.trees[0].hp
	var bitten := 0
	t = 0.0
	while t < maxf(3.0 * want, tab.tie_time() + tab.raft_time()) + tab.spawn_time():
		tab.step(DT, false, Vector2.ZERO, false)
		t += DT
		bitten += _of(tab.events, "hit").size()
		tab.events.clear()
	_ok("with nobody there the beavers do not bite", bitten == 0 and tab.felled == 0 and tab.energy == 0 and is_equal_approx(float(tab.trees[0].hp), whole) and tab.gnawing.is_empty())
	_ok("trees come up and the raft lands all the same", tab.trees.size() == tab.room() and tab.owed == tab.bundle_size() and not tab.raft.away)
	seen = _hold(tab, Vector2.ZERO, want + 0.5, false)
	_ok("and they bite again with somebody back", tab.felled > 0 and not _of(seen, "hit").is_empty())
	# away
	var team: int = Sim.NODE.beaver[2]
	var away: RefCounted = Sim.new(44)
	away.lv.beaver = team
	away.lv.room = 9
	away.catch_up(3.0 * 86400.0)
	var share: int = team * away.room()
	_ok("three days away with %d beavers fells exactly %d * room() trees (%d)" % [team, team, away.felled], away.beavers() == team and away.felled == share and away.lying() == share
		and away.energy == share and away.trees.size() == away.room())
	_ok("nothing of it is on the jetty, and its events are gone", away.jetty_held() == 0 and away.owed == 0 and away.events.is_empty())
	# time away is worked out, not run: a thousand days cost what a day does.
	# No clock is tight here: the longer may take a few times the shorter
	# and 50 ms more before this says anything.
	var day_ms := _away_ms(86400.0)
	var long_ms := _away_ms(86400.0 * 1000.0)
	_ok("a thousand days away cost no more than one (%.2f ms against %.2f)" % [long_ms, day_ms], long_ms <= 4.0 * day_ms + 50.0)
	var brief: RefCounted = Sim.new(45)
	brief.lv.beaver = 1
	var each: float = brief.hp(0) / (brief.power() * brief.bite() / Sim.BITE_EVERY)
	brief.catch_up(2.5 * each)
	_ok("time away for two saplings and a half is two saplings for one beaver (%d)" % brief.felled, brief.room() >= 2 and brief.felled == 2 and brief.lying() == 2)
	var late: RefCounted = Sim.new(46)
	late.lv.beaver = team
	late.lv.room = Sim.NODE.room[2]
	late.lv.seeds = 6
	late.lv.axe = 60
	late.lv.jetty = Sim.NODE.jetty[2]
	var held_wood: int = late.jetty_room() * 100
	late.loose = {"n": late.jetty_room(), "wood": held_wood}
	late.save(1000.0)
	var back: RefCounted = Sim.load_saved(1000.0 + 3.0 * 86400.0)
	_ok("a late grove three days away: the land once over a beaver felled (%d), the full jetty landed" % back.felled, back.felled == team * back.room() and back.lying() == back.felled
		and back.owed == held_wood and back.jetty_held() == 0 and not back.raft.away)
	day_ms = _load_ms(1000.0 + 86400.0)
	long_ms = _load_ms(1000.0 + 86400.0 * 1000.0)
	_ok("read from its file a thousand days on it costs no more than a day on (%.2f ms against %.2f)" % [long_ms, day_ms], long_ms <= 4.0 * day_ms + 50.0)
	# kinds gone from the land
	var gone: RefCounted = Sim.new(47)
	gone.energy = 1 << 40
	gone.buy("soft:0")
	gone.lv.seeds = 3
	_ok("the land grows the best kind and the two under it", not gone.grows(0) and gone.grows(1) and gone.grows(3))
	_ok("soft:0 cannot be bought once the Sapling is gone, and is kept and shown", not gone.can_buy("soft:0") and not gone.buy("soft:0") and not gone.buy("rich:0")
		and gone.level("soft:0") == 1 and gone.shown().has("soft:0") and gone.can_buy("soft:1"))
	# fortune
	var keen: RefCounted = Sim.new(48)
	keen.lv.crit = ceili(1.0 / Sim.CRIT_STEP)   # past its last level: every chop is keen
	var chops: int = ceili(keen.hp(0) / (keen.power() * keen.crit_size()))
	var hits := _of(_hold(keen, keen.trees[0].pos, (chops - 1) * keen.swing_time() + 0.1), "hit")
	_ok("a keen chop counts for crit_size() chops: a sapling is down in %d" % chops, chops < ceili(keen.hp(0) / keen.power()) and hits.size() == chops and hits[0].keen and hits[0].by == "axe"
		and is_equal_approx(float(hits[0].amount), keen.power() * Sim.CRIT_SIZE) and keen.felled == 1)
	var lucky: RefCounted = Sim.new(49)
	lucky.lv.luck = ceili(1.0 / Sim.LUCK_STEP)   # past its last level: every pile is lucky
	lucky.trees[0].hp = 1.0
	fells = _of(_hold(lucky, lucky.trees[0].pos, DT), "fell")
	_ok("a lucky pile is worth double and the energy is not", fells.size() == 1 and fells[0].lucky and lucky.energy == 1 and int(lucky.logs[0].n) == 1
		and int(lucky.logs[0].wood) == 2 and bool(lucky.logs[0].lucky) and lucky.wood_made == 2)
	var c: RefCounted = Sim.new(50)
	_hold(c, Vector2.ZERO, Sim.CRATE + 20.0, false)
	_ok("no crate without the node", c.crate.is_empty() and c.crate_time() == 0.0)
	c.lv.crate = 1
	seen = _hold(c, Vector2.ZERO, c.crate_time() + 0.2, false)
	_ok("with it, one washes up when crate_time() is up", is_equal_approx(c.crate_time(), Sim.CRATE) and not c.crate.is_empty() and _of(seen, "crate").size() == 1)
	var p: Vector2 = c.crate.get("pos", Sim.LAND * 0.5)
	var d := p - Sim.LAND * 0.5
	_ok("on the land, within SHORE of a front edge (%s)" % str(p), Sim.stands(p) and d.y > 0.0 and (Sim.HALF - absf(d.x) - d.y) / sqrt(2.0) <= Sim.SHORE + 0.01)
	seen = _hold(c, Vector2.ZERO, 2.2 * c.crate_time(), false)
	_ok("one at a time", _of(seen, "crate").is_empty() and not c.crate.is_empty())
	var held: int = c.energy
	var opened := _of(_hold(c, p, DT), "opened")
	var holds: int = Sim.CRATE_GIVE * Sim.give_of(0)
	_ok("a swing over it opens it for CRATE_GIVE saplings' energy (%d)" % holds, c.crate.is_empty() and c.crate_give() == holds and c.energy == held + holds and opened.size() == 1
		and int(opened[0].give) == holds)
	c.catch_up(10.0 * 86400.0)
	_ok("away the time goes on counting and one is waiting", not c.crate.is_empty())
	# what the Skills card writes its lines from
	var v: RefCounted = Sim.new(51)
	_ok("the Jetty root's figures", v.value("jetty", 0) == float(Sim.JETTY) and v.value("jetty", 1) == float(Sim.JETTY + Sim.JETTY_STEP) and is_equal_approx(v.value("tying", 0), Sim.TIE)
		and is_equal_approx(v.value("tying", 1), Sim.TIE * Sim.TIE_STEP) and v.value("tying", 2) < v.value("tying", 1) and v.value("bundle", 0) == float(Sim.BUNDLE)
		and v.value("bundle", 3) == float(Sim.BUNDLE + 3 * Sim.BUNDLE_STEP) and is_equal_approx(v.value("raft", 0), Sim.RAFT) and is_equal_approx(v.value("raft", 1), Sim.RAFT * Sim.RAFT_STEP)
		and v.value("load", 0) == 1.0 and v.value("load", 2) == 3.0)
	_ok("the Beavers root's: a count and a percent", v.value("beaver", 0) == 0.0 and v.value("beaver", 2) == 2.0 and is_equal_approx(v.value("teeth", 0), 100.0 * Sim.BITE)
		and is_equal_approx(v.value("teeth", 2), 100.0 * (Sim.BITE + 2.0 * Sim.BITE_STEP)) and v.value("teeth", 0) > 1.0)
	_ok("the Fortune root's: percents, chops, seconds and energy", v.value("crit", 0) == 0.0 and is_equal_approx(v.value("crit", 3), 300.0 * Sim.CRIT_STEP) and v.value("crit", 3) > 1.0
		and is_equal_approx(v.value("critsize", 0), Sim.CRIT_SIZE) and is_equal_approx(v.value("critsize", 2), Sim.CRIT_SIZE + 2.0 * Sim.CRIT_SIZE_STEP)
		and is_equal_approx(v.value("luck", 5), 500.0 * Sim.LUCK_STEP) and v.value("crate", 0) == 0.0 and is_equal_approx(v.value("crate", 1), Sim.CRATE)
		and is_equal_approx(v.value("crate", 2), Sim.CRATE * Sim.CRATE_STEP) and is_equal_approx(v.value("cratesize", 0), float(Sim.CRATE_GIVE))
		and is_equal_approx(v.value("cratesize", 1), Sim.CRATE_GIVE * (1.0 + Sim.CRATE_GIVE_STEP)))
	_ok("and the land reads the same figures", v.jetty_room() == Sim.JETTY and v.bundle_size() == Sim.BUNDLE and v.raft_load() == 1 and is_equal_approx(v.tie_time(), Sim.TIE)
		and is_equal_approx(v.raft_time(), Sim.RAFT) and is_equal_approx(v.bite(), Sim.BITE) and v.crit_chance() == 0.0 and is_equal_approx(v.crit_size(), Sim.CRIT_SIZE)
		and v.luck_chance() == 0.0 and v.beavers() == 0 and v.value("room") == float(Sim.ROOM) and is_equal_approx(v.value("sprout"), Sim.SPROUT))
	v.lv.jetty = 2
	v.lv.tying = 3
	v.lv.bundle = 1
	v.lv.raft = 4
	v.lv.load = 1
	v.lv.teeth = 2
	v.lv.crit = 4
	_ok("at any level too", float(v.jetty_room()) == v.value("jetty") and is_equal_approx(v.tie_time(), v.value("tying")) and float(v.bundle_size()) == v.value("bundle")
		and is_equal_approx(v.raft_time(), v.value("raft")) and float(v.raft_load()) == v.value("load") and is_equal_approx(v.bite() * 100.0, v.value("teeth"))
		and is_equal_approx(v.crit_chance() * 100.0, v.value("crit")) and v.jetty_room() > Sim.JETTY and v.tie_time() < Sim.TIE)

## Milliseconds `catch_up(seconds)` takes on a land of twelve with every
## beaver, the quickest of three goes.
func _away_ms(seconds: float) -> float:
	var best := INF
	for go in 3:
		var sim: RefCounted = Sim.new(44)
		sim.lv.beaver = Sim.NODE.beaver[2]
		sim.lv.room = 9
		sim.loose = {"n": sim.jetty_room(), "wood": sim.jetty_room()}
		var began := Time.get_ticks_usec()
		sim.catch_up(seconds)
		best = minf(best, (Time.get_ticks_usec() - began) / 1000.0)
	return best

## Milliseconds the grove on the file takes to be read at `now`, the
## quickest of three goes.
func _load_ms(now: float) -> float:
	var best := INF
	for go in 3:
		var began := Time.get_ticks_usec()
		Sim.load_saved(now)
		best = minf(best, (Time.get_ticks_usec() - began) / 1000.0)
	return best

## The jetty is kept; a file from before it, or with nonsense in it, loads.
func _check_kept() -> void:
	var a: RefCounted = Sim.new(61)
	a.lv.crate = 1
	a._drop(Vector2(520.0, 400.0), 0, 2, true)
	a._drop(Vector2(520.0, 600.0), 0, 1, false)
	a.loose = {"n": 1, "wood": 3}
	a.bundles.append({"n": 1, "wood": 4})
	var out_for: float = a.raft_time() * 0.25
	a.raft = {"n": 1, "wood": 5, "bundles": 1, "t": out_for, "away": true}
	a.owed = 7
	a.wood_sent = 70
	a.crate = {"pos": Vector2(520.0, 880.0)}
	a.save(4000.0)
	var b: RefCounted = Sim.load_saved(4000.0)
	_ok("the piles lying are kept", b.logs.size() == 2 and b.lying() == 2 and int(b.logs[0].wood) == 2 and bool(b.logs[0].lucky) and (b.logs[0].pos as Vector2).is_equal_approx(Vector2(520.0, 400.0))
		and int(b.logs[1].wood) == 1 and not b.logs[1].lucky)
	_ok("and the jetty, the raft, what is owed and the crate", int(b.loose.n) == 1 and int(b.loose.wood) == 3 and b.bundles.size() == 1 and int(b.bundles[0].wood) == 4
		and bool(b.raft.away) and int(b.raft.n) == 1 and int(b.raft.wood) == 5 and is_equal_approx(float(b.raft.t), out_for) and b.owed == 7 and b.wood_sent == 70
		and (b.crate.get("pos", Vector2.ZERO) as Vector2).is_equal_approx(Vector2(520.0, 880.0)))
	var c: RefCounted = Sim.load_saved(4000.0 + 86400.0)
	_ok("a day on the jetty has landed, the piles still lie and no wood was made (%d owed)" % c.owed, c.owed == 7 + 5 + 4 + 3 and c.wood_sent == 70 + 12 and c.jetty_held() == 0
		and not c.raft.away and c.lying() == 2)
	# a grove kept before the jetty
	var old := ConfigFile.new()
	old.set_value("lv", "axe", 3)
	old.set_value("lv", "room", 2)
	old.set_value("grove", "energy", 40)
	old.set_value("grove", "wood_made", 99)
	old.set_value("grove", "felled", 50)
	old.set_value("grove", "seen", 100.0)
	old.set_value("grove", "due", [1.0])
	old.set_value("grove", "land", Sim.KEPT_ON)
	old.set_value("grove", "trees", [[0, 520.0, 520.0, 4.0]])
	old.save(Sim.path)
	var kept: RefCounted = Sim.load_saved(100.0 + 3600.0)
	_ok("a grove kept before the jetty loads with an empty one", kept.energy == 40 and kept.wood_made == 99 and int(kept.lv.axe) == 3 and kept.trees.size() == kept.room()
		and kept.lying() == 0 and kept.jetty_held() == 0 and kept.owed == 0 and kept.wood_sent == 0 and not kept.raft.away and kept.crate.is_empty())
	# nonsense in every new key
	old.set_value("lv", "crate", 1)
	old.set_value("jetty", "logs", [[520.0, 520.0, -4, 50, 0, false], "pile", [1, 2], [520.0, 520.0, 3, 2, 0, false], 7, [NAN, 5.0, 1, 1, 0, false], ["x", "y", 2, 2, "oak", 1], null])
	old.set_value("jetty", "loose", [-3, 500])
	old.set_value("jetty", "bundles", "many")
	old.set_value("jetty", "raft", ["5", -1, "one", "soon", true])
	old.set_value("jetty", "tie", "now")
	old.set_value("jetty", "owed", "lots")
	old.set_value("jetty", "sent", -20)
	old.set_value("jetty", "crate", "here")
	old.set_value("jetty", "crate_t", [1])
	old.save(Sim.path)
	var odd: RefCounted = Sim.load_saved(100.0)
	_ok("a file with nonsense in the jetty's keys loads, and makes no wood", odd != null and odd.energy == 40 and odd.lying() == 0 and odd.jetty_held() == 0 and odd.owed == 0
		and odd.wood_sent == 0 and int(odd.raft.n) == 0 and int(odd.raft.wood) == 0 and odd.tie_t == 0.0 and odd.crate.is_empty())
	var odd_later: RefCounted = Sim.load_saved(100.0 + 86400.0)
	_ok("nor a day later", odd_later.lying() == 0 and odd_later.jetty_held() == 0 and odd_later.owed == 0 and odd_later.wood_sent == 0 and not odd_later.raft.away)
	old.set_value("jetty", "logs", 12)
	old.set_value("jetty", "loose", "none")
	old.set_value("jetty", "bundles", [[2, 1], [-1, -1], "b", [0, 9]])
	old.set_value("jetty", "raft", {"n": 4})
	old.set_value("jetty", "owed", -5)
	old.set_value("jetty", "crate", [INF, 2.0])
	old.save(Sim.path)
	var odder: RefCounted = Sim.load_saved(100.0 + 600.0)
	_ok("nor another", odder.lying() == 0 and odder.jetty_held() == 0 and odder.owed == 0 and odder.wood_sent == 0 and int(odder.raft.wood) == 0)
	# more on the jetty than it has room for: held to its room, the rest
	# back on the land by the jetty's end of it, no wood made or lost
	old.set_value("jetty", "logs", [])
	old.set_value("jetty", "raft", [0, 0, 0, 0.0, false])
	old.set_value("jetty", "owed", 0)
	old.set_value("jetty", "sent", 0)
	old.set_value("jetty", "crate", [])
	old.set_value("jetty", "loose", [20, 50])
	old.set_value("jetty", "bundles", [[4, 9]])
	old.save(Sim.path)
	var over: RefCounted = Sim.load_saved(100.0)
	var room: int = over.jetty_room()
	var on_jetty: int = int(over.loose.wood) + (int(over.bundles[0].wood) if over.bundles.size() == 1 else -1000)
	var on_land: int = int(over.logs[0].wood) if over.logs.size() == 1 else -1000
	_ok("a jetty kept fuller than its room is held to it (%d of %d), the rest lying by it (%d)" % [over.jetty_held(), room, over.lying()], room < 24 and over.jetty_held() == room
		and over.lying() == 24 - room and on_jetty + on_land == 59 and over.logs.size() == 1 and (over.logs[0].pos as Vector2).is_equal_approx(Sim.by_jetty())
		and Sim.stands(Sim.by_jetty()))
	# figures no grove could hold
	var many := [[1.0e300, 1.0e300]]
	for i in 5000:
		many.append([1, 1])
	old.set_value("jetty", "logs", [[520.0, 520.0, 1.0e300, 1.0e300, 0, false], [520.0, 300.0, 2, 3, 0, false], [300.0, 520.0, 1 << 60, 1 << 61, 0, false]])
	old.set_value("jetty", "loose", [1000000, 2000000])
	old.set_value("jetty", "bundles", many)
	old.set_value("jetty", "owed", 1.0e300)
	old.set_value("jetty", "sent", 1 << 60)
	old.save(Sim.path)
	var huge: RefCounted = Sim.load_saved(100.0)
	var read: int = Sim.ROWS - 1   # the bundles read: the first row is no count
	_ok("a count past what a grove could hold reads as none", huge.owed == 0 and huge.wood_sent == 0)
	_ok("five thousand bundles and a million loose piles are a jetty of %d (%d held, %d bundles)" % [room, huge.jetty_held(), huge.bundles.size()], huge.jetty_held() == room
		and huge.bundles.size() == room and int(huge.loose.n) == 0)
	_ok("and the rest of what was read lies on the land, counted right (%d piles)" % huge.lying(), huge.lying() == 2 + (read - room) + 1000000)
	var huge_later: RefCounted = Sim.load_saved(100.0 + 86400.0)
	_ok("a day on its jetty has landed and nothing has turned over", huge_later.owed == room and huge_later.wood_sent == room and huge_later.jetty_held() == 0 and not huge_later.raft.away
		and huge_later.lying() == huge.lying())
	# a tree a beaver had bitten keeps what it had left
	old.set_value("grove", "trees", [[0, 520.0, 520.0, 0.4], [0, 520.0, 300.0, 0.0]])
	old.save(Sim.path)
	var bitten: RefCounted = Sim.load_saved(100.0)
	_ok("a tree kept with 0.4 left has 0.4 left, and one with nothing stands on its last crumb", bitten.trees.size() >= 2 and is_equal_approx(float(bitten.trees[0].hp), 0.4)
		and is_equal_approx(float(bitten.trees[1].hp), Sim.DOWN) and bitten.felled == 50 and bitten.energy == 40)
	DirAccess.remove_absolute(Sim.path)

## `secs` of the grove a frame at a time, the circle held at `at` or nobody
## holding. Returns what happened.
func _hold(sim: RefCounted, at: Vector2, secs: float, holding := true) -> Array[Dictionary]:
	var seen: Array[Dictionary] = []
	var t := 0.0
	while t < secs - 0.001:
		sim.step(DT, holding, at)
		t += DT
		seen.append_array(sim.events)
		sim.events.clear()
	return seen

func _of(seen: Array[Dictionary], kind: String) -> Array[Dictionary]:
	return seen.filter(func(e: Dictionary) -> bool: return e.kind == kind)

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
## hours, by a player who buys the cheapest node it can afford, in the shop
## or the tree, except any whose id or part (`soft` of `soft:2`) is in
## `never`. It holds the circle on a crate when one lies, else on the oldest
## tree, and with no tree standing on the biggest pile: it never leaves a
## tree for a pile, so what it gathers is what lies under its chopping and
## what it goes to when the land is bare. What the raft lands it takes, as
## the screen does for Stock. A day's line: the levels; the wood felled, the
## wood delivered, the piles lying and held on the jetty at the day's end,
## and the share of the played frames since the last line the jetty was full;
## the trees felled and how many of them by beavers.
func _pace(visits: int, secs: float, days: int, never: PackedStringArray) -> void:
	var sim: RefCounted = Sim.new(1)
	var gap := 16.0 * 3600.0 / visits
	var played := 0.0
	var seeds_at := []
	var delivered := 0
	var by_axe := 0
	var looked := -1   # the energy it last went shopping with
	var frames := 0
	var full := 0
	print("pace: %d visits a day of %d s, %d days%s" % [visits, int(secs), days, ", never " + ",".join(never) if never.size() > 0 else ""])
	for day in days:
		for v in visits:
			sim.catch_up(gap if v > 0 else 8.0 * 3600.0)
			delivered += sim.take_owed()
			var t := 0.0
			var rest := 0.0
			while t < secs:
				var hold := false
				var at := Vector2.ZERO
				if rest <= 0.0:
					if not sim.crate.is_empty():
						hold = true
						at = sim.crate.pos
					elif not sim.trees.is_empty():
						hold = true
						at = sim.trees[0].pos + Vector2(0.0, -Sim.radius_of(sim.trees[0].tier))
					elif not sim.logs.is_empty():
						hold = true
						var most := 0
						for pile: Dictionary in sim.logs:
							if int(pile.n) > most:
								most = int(pile.n)
								at = pile.pos
				sim.step(DT, hold, at)
				delivered += sim.take_owed()
				rest -= DT
				t += DT
				frames += 1
				if sim.jetty_held() >= sim.jetty_room():
					full += 1
				for e: Dictionary in sim.events:
					if e.kind == "fell" and e.by == "axe":
						rest = TRAVEL
						by_axe += 1
				sim.events.clear()
				# nothing new can be bought until the energy has changed
				if sim.energy == looked:
					continue
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
				looked = sim.energy
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
			print("day %d: axe %d reach %d swing %d sprout %d room %d seeds %d | soft %d rich %d |%s | wood %d felled, %d delivered, %d piles lying, %d of %d on the jetty, full %d%% | trees %d, %d by beavers | energy %d | %.1f h played" % [day + 1,
				int(sim.lv.axe), int(sim.lv.reach), int(sim.lv.swing), int(sim.lv.sprout), int(sim.lv.room), int(sim.lv.seeds),
				boughs, rich, rest_of if rest_of != "" else " -", sim.wood_made, delivered, sim.lying(), sim.jetty_held(), sim.jetty_room(),
				roundi(100.0 * full / maxi(1, frames)), sim.felled, sim.felled - by_axe, sim.energy, played / 3600.0])
			frames = 0
			full = 0
	for line: String in seeds_at:
		print(line)
