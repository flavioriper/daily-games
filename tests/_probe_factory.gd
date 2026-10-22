extends SceneTree

## Factory's sim, headless: the floor's rules.
##
##     godot --headless --path . --script res://tests/_probe_factory.gd
##
## The checks: a new floor has its stations where STATIONS and BAYS say and
## nothing else; no belt goes on a station; the intake fills one square a
## FEED_TICKS up to QUEUE_MOST; the stack gives an empty box; the table takes
## an empty box, then squares into it up to BOX_FULL, and gives the box back
## only full; the deliver pad pays a full box PAY_FULL, a box its squares, a
## square PAY_SQUARE; open floor holds a stack and a Pick takes its top; a
## belt carries a square into the table's box and waits at a full one; a belt
## does not deliver onto the intake pad, the bay or the stack; the fast belt
## and the bridge carry as they did; a belt sold gives its price back; a save
## reads back as the same floor and plays on the same; a file of another
## version, or none, or nonsense, is refused and the sim is left alone.
## The robots: the three of a new floor and their faults (the Picker walks
## with no gripper, the Boxer's gripper closes a tile short of the stack, the Shipper stops
## at a loose wire), the three fixes and the first full box, no two robots
## ever on one tile nor one on a station, a belt or a thing lying; a loop's cost
## and the pause to charge; an insert after the last node, a cycle that
## never passes the body, a bump, a part taken off mid node, an edit that
## keeps the charge, a tow and a robot with no cell.
## Everything runs on a throwaway file.

const Sim = preload("res://factory/sim.gd")
const Bots = preload("res://factory/bots.gd")
const Art = preload("res://factory/art.gd")

const T := Vector2i(2, 4)     # the pack table
const D := Vector2i(5, 4)     # the deliver pad
const I := Vector2i(1, 5)     # the intake pad
const S := Vector2i(3, 2)     # the box stack
const B := Vector2i(2, 0)     # the charging bay's middle pad, under the charger

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
	_check_floor()
	_check_belts()
	_check_kept()
	_check_robots()
	_check_turns()
	_check_room()
	_check_pace()
	print("probe_factory: %d checks, %d failed" % [_checks, _fails])
	DirAccess.remove_absolute(Sim.path)
	quit(1 if _fails > 0 else 0)
	return true

func _ok(what: String, yes: bool, more := "") -> void:
	_checks += 1
	print("PASS " if yes else "FAIL ", what, "" if more == "" else "  (" + more + ")")
	if not yes:
		_fails += 1

## One tick, and what it said.
func _tick(sim: RefCounted) -> Array:
	sim.events.clear()
	sim.step(Sim.TICK)
	return sim.events.duplicate()

func _run(sim: RefCounted, ticks: int) -> void:
	for i in ticks:
		sim.step(Sim.TICK)
	sim.events.clear()

func _after(sim: RefCounted, ticks: int) -> RefCounted:
	_run(sim, ticks)
	return sim

## Ticks until an event of `type` (returned in `found`), or -1 past `most`.
func _until(sim: RefCounted, type: String, most: int, found: Array = []) -> int:
	for i in most:
		for e: Dictionary in _tick(sim):
			if e.type == type:
				found.append(e)
				return i + 1
	return -1

## Ticks until the table's box holds `n`; false past `most`.
func _until_table_n(sim: RefCounted, n: int, most: int) -> bool:
	for i in most:
		if not sim.table.is_empty() and int(sim.table.n) >= n:
			return true
		sim.step(Sim.TICK)
	return not sim.table.is_empty() and int(sim.table.n) >= n

## A square off the intake, the queue topped up first.
func _square(sim: RefCounted) -> Dictionary:
	if sim.queue <= 0:
		sim.queue = 1
	return sim.take(I)

## `n` squares into the table's box; true when every one went in.
func _fill(sim: RefCounted, n: int) -> bool:
	for i in n:
		if not sim.put(T, _square(sim)):
			return false
	return true

func _lying(sim: RefCounted, tile: Vector2i) -> int:
	return sim.items[tile].size() if sim.items.has(tile) else 0

func _belt_row(sim: RefCounted, from: Vector2i, n: int, facing: int) -> void:
	for i in n:
		sim.lay_belt(from + Sim.DIRS[facing] * i, facing)

## A floor with no robot on it, for the floor's and the belts' own rules.
func _bare(with_seed: int) -> RefCounted:
	var sim: RefCounted = Sim.new(with_seed)
	sim.robots = []
	sim.milestone = 1   # belts are laid on a bare floor
	return sim

## Ticks until an event of `type` (of robot `robot`, -1 any), or -1 past
## `most`; the event is put in `found`.
func _until_event(sim: RefCounted, type: String, most: int, robot := -1, found: Array = []) -> int:
	for i in most:
		for e: Dictionary in _tick(sim):
			if e.type == type and (robot < 0 or int(e.get("robot", -1)) == robot):
				found.append(e)
				return i + 1
	return -1

## Ticks until robot `i` stands at node `id`; false past `most`.
func _until_pc(sim: RefCounted, i: int, id: String, most: int) -> bool:
	for k in most:
		if sim.robots[i].pc == id:
			return true
		sim.step(Sim.TICK)
	return sim.robots[i].pc == id

func _refused(sim: RefCounted, why: String) -> bool:
	var e: Dictionary = sim.events.back() if not sim.events.is_empty() else {}
	return e.get("type", "") == "refused" and e.get("why", "") == why

## The three fixes of the first session on `sim`, in any order: the Picker's
## gripper and its Pick, the Boxer's two vertical Moves, the Shipper's wire.
func _fix_all(sim: RefCounted) -> bool:
	var ok: bool = sim.fit(0, "gripper")
	ok = ok and sim.add_node(0, Bots.walk(sim.robots[0]).ids[0], "out", "pick") != ""
	ok = ok and sim.set_move(1, "a", 2)
	ok = ok and sim.set_next(2, "g", "out", "h")
	return ok

# --- the checks ---

func _check_floor() -> void:
	var sim: RefCounted = Sim.new(7)
	_ok("a new floor is version 9, 30 x 15, nothing on it, no coins, three robots, a gripper in the bin", Sim.VERSION == 9 and Sim.COLS == 30
		and Sim.ROWS == 15 and sim.coins == 0 and sim.earned == 0 and sim.queue == 0 and sim.table.is_empty() and sim.items.is_empty()
		and sim.belts.is_empty() and sim.robots.size() == 3 and sim.bin == {"gripper": 1})
	# the floor's own rules, with no robot walking it
	sim.robots = []
	sim.milestone = 1   # belts are open (the lock is _check_pace's)
	_ok("floor stations", sim.station_at(T) == "table" and sim.station_at(B) == "charger" and sim.station_at(Vector2i(2, 1)) == ""
		and sim.station_at(I) == "intake" and sim.station_at(S) == "stack" and sim.station_at(D) == "deliver" and sim.stations.size() == 7 and Sim.BAY == B
		and Sim.BAYS.all(func(t: Vector2i) -> bool: return sim.station_at(t) == "charger"))
	_ok("the floor's edge", sim.on_floor(Vector2i(0, 0)) and sim.on_floor(Vector2i(29, 14)) and not sim.on_floor(Vector2i(30, 0))
		and not sim.on_floor(Vector2i(0, 15)) and not sim.on_floor(Vector2i(-1, 3)))
	_ok("no belt on a station", not sim.can_lay(T) and not sim.can_lay(Vector2i(1, 0)) and sim.can_lay(Vector2i(4, 1)) and not sim.can_lay(Vector2i(30, 4)))
	_ok("no belt on the drawn intake and deliver belts, and room past them", not sim.can_lay(Vector2i(0, 2)) and not sim.can_lay(Vector2i(0, 5))
		and not sim.can_lay(Vector2i(6, 4)) and not sim.can_lay(Vector2i(6, 0)) and sim.can_lay(Vector2i(0, 6)) and sim.can_lay(Vector2i(6, 5))
		and sim.can_lay(Vector2i(1, 2)) and sim.can_lay(Vector2i(Sim.COLS - 1, 3)))
	sim.coins = 10
	_ok("and one tried there is refused", not sim.lay_belt(T, 0) and _refused(sim, "station") and sim.belts.is_empty() and sim.coins == 10)
	sim.coins = 0
	_ok("intake fills", _after(sim, 10).queue == 1 and _after(sim, 100).queue == 6)
	_ok("stack gives a box", sim.gives(S).kind == "box" and sim.gives(S).n == 0)
	_ok("a Pick at the intake takes a square off the queue", sim.gives(I).kind == "square" and sim.take(I).kind == "square" and sim.queue == 5)
	var box: Dictionary = sim.take(S)
	var sq: Dictionary = _square(sim)
	_ok("the stack is never empty and each box is new", box.kind == "box" and int(box.n) == 0 and sim.take(S).id != box.id)
	_ok("table takes a box then squares", sim.put(T, box) and not sim.takes(T, box) and sim.takes(T, sq) and sim.put(T, sq) and sim.table.n == 1)
	_run(sim, 3)
	sim.alpha = 0.0
	var at0: Vector2 = sim.item_pos(T, sim.table)
	sim.alpha = 1.0
	var at1: Vector2 = sim.item_pos(T, sim.table)
	sim.step(0.0)
	_ok("the table's box rests in the table's middle", at0 == at1 and at0 == Vector2(T) + Vector2(0.5, 0.5), "%s %s" % [at0, at1])
	_ok("table gives only a full box", sim.gives(T).is_empty() and sim.take(T).is_empty() and _fill(sim, 3) and sim.gives(T).kind == "box")
	_ok("and a fifth square is not taken", not sim.takes(T, _square(sim)) and int(sim.table.n) == Sim.BOX_FULL)
	var full_box: Dictionary = sim.take(T)
	_ok("the full box comes off and the table is bare", full_box.kind == "box" and int(full_box.n) == 4 and sim.table.is_empty() and not sim.takes(T, _square(sim)))
	var empty_box: Dictionary = sim.take(S)
	sq = _square(sim)
	sim.events.clear()
	_ok("deliver pays", sim.put(D, full_box) and sim.coins == 6 and sim.put(D, sq) and sim.coins == 7 and sim.put(D, empty_box) and sim.coins == 7)
	_ok("each sale said, the full box's six first", sim.events.size() == 3 and sim.events[0].type == "sale" and sim.events[0].amount == 6
		and sim.events[0].kind == "box" and sim.events[0].tile == D and sim.events[2].amount == 0 and sim.earned == 7)
	var half: Dictionary = sim.take(S)
	half.n = 2
	_ok("a box with two pays two", sim.put(D, half) and sim.coins == 9 and not sim.items.has(D))
	sq = _square(sim)
	var sq2: Dictionary = _square(sim)
	_ok("floor holds a stack", sim.put(Vector2i(2, 1), sq) and sim.put(Vector2i(2, 1), sq2) and sim.gives(Vector2i(2, 1)).id == sq2.id
		and sim.take(Vector2i(2, 1)).id == sq2.id and _lying(sim, Vector2i(2, 1)) == 1)
	_ok("a Pick on bare floor with nothing there takes nothing", sim.gives(Vector2i(6, 2)).is_empty() and sim.take(Vector2i(6, 2)).is_empty())
	# nothing lies on the bay's pads, the stack, the intake pad or a drawn belt
	var lay: Dictionary = _square(sim)
	_ok("a Release on the bay, the intake pad, the stack or a drawn belt is not taken", not sim.takes(B, lay) and not sim.put(Vector2i(1, 0), lay)
		and not sim.takes(I, lay) and not sim.takes(S, lay) and not sim.takes(Vector2i(0, 3), lay) and not sim.takes(Vector2i(6, 1), lay)
		and not sim.items.has(B) and not sim.items.has(Vector2i(1, 0)))

func _check_belts() -> void:
	var sim: RefCounted = _bare(7)
	sim.coins = 100
	var box: Dictionary = sim.take(S)
	sim.put(T, box)
	# a belt from the table's right into it carries a square into the box
	_belt_row(sim, Vector2i(4, 4), 2, 2)   # (4,4),(3,4) facing -x into the table
	_ok("two belts laid for a coin each", sim.coins == 98 and sim.belt_kind(Vector2i(4, 4)) == "belt" and sim.price("belt") == 1)
	var sq3: Dictionary = _square(sim)
	_ok("belt feeds the table", sim.put(Vector2i(4, 4), sq3) and _until_table_n(sim, 1, 200) and sim.items.is_empty())
	_ok("a Pick on a belt takes its front", sim.put(Vector2i(4, 4), _square(sim)) and sim.front_of_tile(Vector2i(4, 4)).kind == "square"
		and sim.take(Vector2i(4, 4)).kind == "square" and sim.front_of_tile(Vector2i(4, 4)).is_empty())
	for i in 4:
		sim.put(Vector2i(4, 4), _square(sim))
		_run(sim, 25)
	_run(sim, 60)
	var waits: Array = sim.items.get(Vector2i(3, 4), [])
	_ok("belt waits at a full box", int(sim.table.n) == 4 and waits.size() == 1 and is_equal_approx(float(waits[0].at), 1.0) and not sim.items.has(Vector2i(4, 4)),
		"n %d, %s" % [int(sim.table.n), str(sim.items.keys())])
	sim.take(T)
	sim.put(T, sim.take(S))
	_run(sim, 5)
	_ok("and goes on into the next box", int(sim.table.n) == 1 and not sim.items.has(Vector2i(3, 4)))
	# a belt into the deliver pad sells
	_belt_row(sim, Vector2i(5, 2), 2, 1)   # (5,2),(5,3) facing down into the market
	var c: int = sim.coins
	sim.put(Vector2i(5, 2), _square(sim))
	_ok("a belt into the deliver pad sells", _until(sim, "sale", 100) > 0 and sim.coins == c + 1 and sim.items.is_empty())
	# into the intake pad, the bay or the stack nothing goes: the belt waits
	for at: Vector2i in [I, B, S]:
		var w: RefCounted = _bare(1)
		w.coins = 10
		var from: Vector2i = at + Vector2i(0, 1)
		w.lay_belt(from, 3)
		w.put(from, _square(w))
		_run(w, 50)
		_ok("a belt into the %s waits" % w.station_at(at), _lying(w, from) == 1 and is_equal_approx(float(w.items[from][0].at), 1.0) and _lying(w, at) == 0)
	# a belt flipped beside the table runs into it
	var f: RefCounted = _bare(1)
	f.coins = 10
	_belt_row(f, Vector2i(2, 3), 3, 0)
	_ok("a line flipped by the table ends into it", f.flip_line(Vector2i(3, 3)) and int(f.belts[Vector2i(2, 3)]) == 1 and int(f.belts[Vector2i(3, 3)]) == 2)
	# the fast belt and the bridge
	var k: RefCounted = _bare(1)
	k.coins = 1000
	_belt_row(k, Vector2i(12, 7), 3, 0)
	for i in 3:
		k.lay_belt(Vector2i(12 + i, 8), 0, "fast")
	_ok("a fast belt is four coins and carries twice as far", k.coins == 1000 - 3 - 12 and k.belt_seconds(Vector2i(12, 8)) == 1.0 and k.unlocked("fast") and k.unlocked("bridge"))
	k.put(Vector2i(12, 7), _square(k))
	k.put(Vector2i(12, 8), _square(k))
	_run(k, 20)
	_ok("so in two seconds", k.items.has(Vector2i(13, 7)) and k.items.has(Vector2i(14, 8)), str(k.items.keys()))
	k.items.clear()
	var bk: RefCounted = _bare(1)
	bk.coins = 1000
	_belt_row(bk, Vector2i(12, 8), 5, 0)
	_belt_row(bk, Vector2i(15, 6), 2, 1)
	_belt_row(bk, Vector2i(15, 9), 2, 1)
	c = bk.coins
	_ok("a bridge is laid on a belt for the difference", bk.lay_belt(Vector2i(15, 8), 0, "bridge") and bk.belt_kind(Vector2i(15, 8)) == "bridge" and bk.coins == c - 24)
	var across := 0
	var under := 0
	var wrong := 0
	for i in 600:
		if i % 10 == 0 and i < 300:
			bk.put(Vector2i(12, 8), _square(bk))
			bk.put(Vector2i(15, 6), bk.take(S))
		bk.step(Sim.TICK)
		for end: Vector2i in [Vector2i(16, 8), Vector2i(15, 10)]:
			if bk.items.has(end) and float(bk.items[end][0].at) >= 1.0 - 0.001:
				var it: Dictionary = bk.items[end].pop_front()
				if bk.items[end].is_empty():
					bk.items.erase(end)
				if end == Vector2i(16, 8):
					under += 1 if it.kind == "square" else 0
					wrong += 0 if it.kind == "square" else 1
				else:
					across += 1 if it.kind == "box" else 0
					wrong += 0 if it.kind == "box" else 1
	_ok("thirty squares under a bridge and thirty boxes over, none mixed", under == 30 and across == 30 and wrong == 0, "%d %d %d" % [under, across, wrong])
	c = bk.coins
	_ok("a belt sold gives its price back, what rode it lies", bk.put(Vector2i(12, 8), _square(bk)) and bk.sell(Vector2i(12, 8)) and bk.coins == c + 1
		and not bk.belts.has(Vector2i(12, 8)) and _lying(bk, Vector2i(12, 8)) == 1)
	_ok("and a line sold in one go", bk.sell_belts([Vector2i(13, 8), Vector2i(14, 8)]) and bk.coins == c + 3 and bk.events.back().type == "sold_line")
	_ok("a station is nothing to sell or turn", not bk.sell(T) and not bk.turn(T))

func _check_kept() -> void:
	var sim: RefCounted = Sim.new(7)
	sim.coins = 100
	sim.milestone = 1   # it lays belts and a bridge
	_run(sim, 70)
	sim.put(T, sim.take(S))
	_fill(sim, 2)
	_belt_row(sim, Vector2i(8, 8), 2, 0)
	sim.lay_belt(Vector2i(10, 2), 0, "bridge")
	sim.put(Vector2i(8, 8), sim.take(I))
	sim.put(Vector2i(12, 1), sim.take(S))
	sim.put(Vector2i(12, 1), sim.take(I))
	sim.picked = "belt"
	_run(sim, 7)
	sim.step(0.04)
	sim.save()
	_ok("a save clears dirty", not sim.dirty)
	var a := FileAccess.get_file_as_string(Sim.path)
	var back: RefCounted = Sim.new(1)
	_ok("round trip", back.load_saved() and var_to_str(back.pack()) == var_to_str(sim.pack()) and back.picked == "belt" and back.queue == sim.queue
		and int(back.table.n) == 2 and back.station_at(T) == "table")
	var kept: Dictionary = back.pack()
	_ok("the save is version 9 and holds the floor, nothing of the land", kept.version == 9 and kept.has_all(["queue", "table", "robots", "bin", "tick_n"])
		and not kept.has("plates") and not kept.has("modules") and not kept.has("sources") and not kept.has("sold"))
	back.save()
	_ok("which saves as the same file", FileAccess.get_file_as_string(Sim.path) == a)
	sim.events.clear()
	sim.step(0.0)
	sim.step(-1.0)
	_ok("stepping no time changes nothing", var_to_str(sim.pack()) == var_to_str(back.pack()) and sim.events.is_empty())
	var same := true
	for i in 3000:
		sim.step(Sim.TICK)
		back.step(Sim.TICK)
		if i % 300 == 0:
			for s: RefCounted in [sim, back]:
				s.put(Vector2i(8, 8), s.take(I))
			same = same and var_to_str(sim.pack()) == var_to_str(back.pack())
	_ok("and the floor read back plays on as the floor saved does", same and var_to_str(sim.pack()) == var_to_str(back.pack()))
	var hitch: RefCounted = Sim.new(1)
	hitch.step(3600.0)
	_ok("a long frame is a quarter of a second at most", hitch.tick_n == 2 and is_equal_approx(hitch.alpha, 0.5))
	# another version, no file, nonsense
	var fresh: RefCounted = Sim.new(3)
	var was := var_to_str(fresh.pack())
	var old: Dictionary = sim.pack()
	old.version = 4
	_write(old, 4)
	_ok("old save wiped", not fresh.load_saved() and var_to_str(fresh.pack()) == was)
	old.version = Sim.VERSION
	_write(old, Sim.VERSION)
	var again: RefCounted = Sim.new(3)
	_ok("the same floor marked 5 is read: the version alone refused it", again.load_saved() and var_to_str(again.pack()) == var_to_str(sim.pack()))
	var shaped: Dictionary = sim.pack()
	shaped.items[Vector2i(12, 1)][0].kind = "log"
	_write(shaped, Sim.VERSION)
	_ok("a floor with a thing there is none of is refused", not fresh.load_saved() and var_to_str(fresh.pack()) == was)
	shaped = sim.pack()
	shaped.table = {"id": 1, "kind": "square", "at": 0.5, "from": -1, "was": Vector2.ZERO}
	_write(shaped, Sim.VERSION)
	_ok("so is one with a square on the table", not fresh.load_saved() and var_to_str(fresh.pack()) == was)
	DirAccess.remove_absolute(Sim.path)
	_ok("no file is no floor, and the sim is left alone", not fresh.load_saved() and var_to_str(fresh.pack()) == was)
	var f := FileAccess.open(Sim.path, FileAccess.WRITE)
	f.store_string("[factory]\nversion=5\nstate=\"%s\"\n" % Marshalls.variant_to_base64({"version": 5, "coins": "many"}))
	f.close()
	_ok("a file that is not a floor is refused", not fresh.load_saved() and var_to_str(fresh.pack()) == was)
	f = FileAccess.open(Sim.path, FileAccess.WRITE)
	f.store_string("[factory]\nstate=\"bm90IGEgbGFuZA==\"\n")
	f.close()
	_ok("so are bytes that are no floor", not fresh.load_saved() and var_to_str(fresh.pack()) == was)
	f = FileAccess.open(Sim.path, FileAccess.WRITE)
	f.store_string("not a config at all {{{")
	f.close()
	_ok("and so is nonsense", not fresh.load_saved() and var_to_str(fresh.pack()) == was)

## The Turn node: a unit and ACT_TICKS, a quarter right or left, Moves walk
## the way the robot faces, and the facing is kept loop to loop.
func _check_turns() -> void:
	var sim: RefCounted = Sim.new(3)
	var bot: Dictionary = Bots.new_robot("Turner", Vector2i(5, 3), ["treads", "battery"], [["turn", Sim.RIGHT], ["move", 1]])
	sim.robots = [bot]
	_ok("a new robot faces down", bot.facing == Sim.HOME_FACING and Sim.HOME_FACING == 1)
	_until_pc(sim, 0, "a", 10)
	var c0: int = bot.charge
	var ticks := 0
	var pivots: Array = []
	var mid := -1.0
	while bot.pc == "a" and ticks < 20:
		for e: Dictionary in _tick(sim):
			if e.type == "pivot":
				pivots.append(e)
		ticks += 1
		if ticks == 2:
			mid = Bots.heading(bot, 0.5)
	_ok("a Turn takes ACT_TICKS and a unit", ticks == Sim.ACT_TICKS and c0 - bot.charge == 1, "%d ticks, %d units" % [ticks, c0 - bot.charge])
	_ok("and turns a quarter right: down to left", bot.facing == 2 and pivots.size() == 1 and pivots[0].facing == 2)
	_ok("swinging there in between", mid > 1.0 and mid < 2.0, str(mid))
	_until_pc(sim, 0, Sim.BODY, 20)
	_ok("a Move walks the way it faces", bot.tile == Vector2i(4, 3))
	_until_pc(sim, 0, "a", 10)
	_until_pc(sim, 0, Sim.BODY, 40)
	_ok("and the facing is kept into the next loop", bot.facing == 3 and bot.tile == Vector2i(4, 2), "%d %s" % [bot.facing, bot.tile])
	_ok("a ring that does not face home is told", not Bots.faces_home(bot) and Bots.ways(bot).end == 2)
	var nid: String = sim.add_node(0, "b", "out", "turn")
	_ok("a Turn added is a right one and the robot goes home facing down", nid != "" and bot.nodes[nid].facing == Sim.RIGHT
		and bot.facing == Sim.HOME_FACING and bot.tile == bot.dock and Bots.ways(bot).end == 3)
	_ok("a left turn", sim.set_turn(0, nid, Sim.LEFT) and Bots.ways(bot).end == 1 and Bots.faces_home(bot))
	var no_treads: RefCounted = Sim.new(3)
	_ok("Turn is the treads'", Bots.can(no_treads.robots[0], "turn") and Sim.NODES.turn.part == "treads")
	var bad: Dictionary = sim.pack()
	bad.robots[0].nodes[nid].facing = 2
	_write(bad, Sim.VERSION)
	var fresh: RefCounted = Sim.new(3)
	var was := var_to_str(fresh.pack())
	_ok("a Turn of two quarters is refused on load", not fresh.load_saved() and var_to_str(fresh.pack()) == was)
	bad = sim.pack()
	bad.robots[0].erase("facing")
	_write(bad, Sim.VERSION)
	_ok("so is a robot with no facing (a version 6 floor)", not fresh.load_saved() and var_to_str(fresh.pack()) == was)
	DirAccess.remove_absolute(Sim.path)

func _check_robots() -> void:
	var sim: RefCounted = Sim.new(3)
	_ok("three on the bay, each on its own pad", sim.robots.size() == 3 and range(3).all(func(i: int) -> bool:
		return sim.robots[i].tile == Sim.BAYS[i] and sim.robots[i].dock == Sim.BAYS[i] and sim.robots[i].charge == Sim.CELL))
	_ok("picker lacks pick", not Bots.can(sim.robots[0], "pick") and Bots.walk(sim.robots[0]).closed and Bots.can(sim.robots[1], "pick"))
	_ok("shipper loose", not Bots.walk(sim.robots[2]).closed and Bots.walk(sim.robots[2]).ids.size() == 7)
	# with no gripper the Picker's Release is skipped beside the table, facing it
	var found: Array = []
	_ok("picker walks empty", _until_event(sim, "skip", 400, 0, found) > 0 and found[0].id == "c" and sim.robots[0].held.is_empty()
		and sim.robots[0].tile == Vector2i(1, 4) and Bots.ahead(sim.robots[0]) == T and sim.robots[0].bubble == "!")
	found = []
	_ok("the second robot's gripper closes on nothing a tile short of the stack", _until_event(sim, "pick", 400, 1, found) > 0
		and found[0].tile == S + Vector2i(0, -1) and String(found[0].kind) == "" and sim.robots[1].held.is_empty())
	_run(sim, 200)
	_ok("shipper stops ? beside the table", sim.robots[2].stuck == "?" and sim.robots[2].bubble == "?" and sim.robots[2].tile == T + Vector2i(1, 0))
	# the fixes
	_ok("gripper from the bin", sim.fit(0, "gripper") and sim.bin.gripper == 0 and sim.robots[0].tile == Sim.BAYS[0] and sim.robots[0].pc == Sim.BODY)
	_ok("and none left to fit twice", not sim.fit(1, "treads") and not sim.fit(2, "gripper"))
	var pick_id: String = sim.add_node(0, Bots.walk(sim.robots[0]).ids[0], "out", "pick")
	_ok("pick inserted after move down", pick_id.begins_with("n") and Bots.walk(sim.robots[0]).ids[1] == pick_id and Bots.walk(sim.robots[0]).closed)
	_ok("picker holds a square and waits", _until_event(sim, "wait", 600, 0) > 0 and sim.robots[0].held.get("kind", "") == "square"
		and sim.robots[0].tile == Vector2i(1, 4) and sim.robots[0].bubble == "wait")
	_ok("boxer fixed", sim.set_move(1, "a", 2) and Bots.net(sim.robots[1]) == Vector2i.ZERO and not sim.set_move(1, "a", 2))
	_ok("shipper wired", not sim.set_next(2, "g", "out", "g") and sim.set_next(2, "g", "out", "h") and Bots.walk(sim.robots[2]).closed
		and sim.robots[2].stuck == "")
	var took := _until_event(sim, "sale", 3000)
	_ok("first full box pays 6", took > 0 and sim.coins == 6, "%d ticks" % took)
	# costs and charging
	_ok("loops cost 14, 14 and 22, a Turn a unit", Bots.cost(sim.robots[0]) == 14 and Bots.cost(sim.robots[1]) == 14 and Bots.cost(sim.robots[2]) == 22,
		"%d %d %d" % [Bots.cost(sim.robots[0]), Bots.cost(sim.robots[1]), Bots.cost(sim.robots[2])])
	_ok("every first-session loop comes home facing down", sim.robots.all(func(b: Dictionary) -> bool: return Bots.faces_home(b) and Bots.net(b) == Vector2i.ZERO))
	_ok("charges on its pad", _until_event(sim, "charging", 400, 0) > 0 and sim.robots[0].tile == Sim.BAYS[0] and sim.robots[0].charging
		and _until_event(sim, "charged", 40, 0) > 0 and sim.robots[0].charge == Sim.CELL and not sim.robots[0].charging)
	var sales := 0
	var shared := 0
	var standing := 0
	var waited := 0
	for i in 3000:
		for e: Dictionary in _tick(sim):
			sales += 1 if e.type == "sale" and e.amount == Sim.PAY_FULL else 0
		var taken := {}
		for r in sim.robots.size():
			var b: Dictionary = sim.robots[r]
			for t: Vector2i in [b.tile, b.was]:
				shared += 1 if taken.get(t, r) != r else 0
				taken[t] = r
			standing += 1 if sim.blocked(b.tile, b) and b.tile != b.dock else 0
			waited += 1 if b.bubble == "wait" and b.pc != Sim.BODY and b.nodes[b.pc].kind == "move" else 0
	_ok("and full boxes keep coming", sales >= 3, "%d in 3000 ticks" % sales)
	_ok("no two robots ever share a tile, none stands where it may not, none waits on a step", shared == 0 and standing == 0 and waited == 0,
		"%d %d %d" % [shared, standing, waited])
	# robots round trip mid loop, and a robot that is no robot is refused
	sim.save()
	var back: RefCounted = Sim.new(1)
	var same: bool = back.load_saved() and var_to_str(back.pack()) == var_to_str(sim.pack())
	for i in 500:
		sim.step(Sim.TICK)
		back.step(Sim.TICK)
	_ok("robots round trip mid loop", same and var_to_str(back.pack()) == var_to_str(sim.pack()))
	var bad: Dictionary = sim.pack()
	bad.robots[0].nodes["a"].kind = "fly"
	_write(bad, Sim.VERSION)
	var fresh: RefCounted = Sim.new(3)
	var was := var_to_str(fresh.pack())
	_ok("a robot with a node there is none of is refused", not fresh.load_saved() and var_to_str(fresh.pack()) == was)
	bad = sim.pack()
	bad.robots[1].pc = "zz"
	_write(bad, Sim.VERSION)
	_ok("so is one running a node it has not", not fresh.load_saved() and var_to_str(fresh.pack()) == was)
	DirAccess.remove_absolute(Sim.path)
	# an insert after the last node, and a node taken out
	var s2: RefCounted = Sim.new(3)
	var last: String = Bots.walk(s2.robots[0]).ids.back()
	_ok("no node the parts do not give", s2.add_node(0, last, "out", "pick") == "")
	s2.fit(0, "gripper")
	var nid: String = s2.add_node(0, last, "out", "release")
	_ok("insert after last keeps loop", nid != "" and s2.robots[0].next[nid].out == Sim.BODY and s2.robots[0].next[last].out == nid
		and Bots.walk(s2.robots[0]).closed)
	_ok("a node taken out is wired round", s2.remove_node(0, nid) and s2.robots[0].next[last].out == Sim.BODY and not s2.robots[0].nodes.has(nid)
		and Bots.walk(s2.robots[0]).closed and not s2.robots[0].order.has(nid))
	var s8: RefCounted = Sim.new(3)
	s8.set_next(0, "b", "out", "a")
	_ok("a node taken out of a ring of two leaves a loose wire, not a node wired to itself", s8.remove_node(0, "b") and s8.robots[0].next.a.out == "")
	# a cycle that never passes the body runs the cell flat
	var s3: RefCounted = Sim.new(3)
	var ids: Array = Bots.walk(s3.robots[0]).ids
	s3.set_next(0, ids.back(), "out", ids[0])
	var w: Dictionary = Bots.walk(s3.robots[0])
	var flat := _until_event(s3, "flat", 1200, 0)
	_ok("cycle off the body goes flat", not w.closed and w.ids.size() == 7 and flat > 0 and s3.robots[0].stuck == "flat" and s3.robots[0].charge == 0,
		"flat at %d" % flat)
	_run(s3, 20)
	_ok("and stays where it stopped", s3.robots[0].stuck == "flat" and s3.robots[0].charge == 0)
	_ok("tow arrives empty", not s3.tow(1) and s3.tow(0) and s3.robots[0].tile == Sim.BAYS[0] and s3.robots[0].charge == 0
		and s3.robots[0].pc == Sim.BODY and _until_event(s3, "charging", 3, 0) > 0)
	# a bump drops the rest of a Move
	var s4: RefCounted = Sim.new(3)
	var bot: Dictionary = Bots.new_robot("Bumper", Vector2i(2, 10), ["treads", "battery"], [["turn", Sim.RIGHT], ["move", 4], ["turn", Sim.LEFT], ["move", 1]])
	s4.robots = [bot]
	_until_pc(s4, 0, "b", 10)
	var before: int = bot.charge
	var bumps := 0
	for i in 40:
		for e: Dictionary in _tick(s4):
			bumps += 1 if e.type == "bump" else 0
		if bot.pc != "b":
			break
	_ok("bump mid move", bot.tile == Vector2i(0, 10) and before - bot.charge == 3 and bumps == 1 and bot.pc == "c",
		"%s %d %d %s" % [bot.tile, before - bot.charge, bumps, bot.pc])
	# a part taken off while its node runs
	var s5: RefCounted = Sim.new(3)
	_until_pc(s5, 1, "c", 100)
	var gi: int = s5.robots[1].parts.find("gripper")
	_ok("unfit sends home", s5.unfit(1, gi) and s5.robots[1].tile == Sim.BAY and s5.robots[1].pc == Sim.BODY and s5.bin.gripper == 2
		and not s5.robots[1].parts.has("gripper"))
	_until_pc(s5, 1, "c", 200)
	var cb: int = s5.robots[1].charge
	var skipped := false
	for i in 20:
		for e: Dictionary in _tick(s5):
			skipped = skipped or (e.type == "skip" and e.robot == 1 and e.id == "c")
		if s5.robots[1].pc != "c":
			break
	_ok("unfit mid node", skipped and cb - s5.robots[1].charge == 1 and s5.robots[1].held.is_empty())
	# an edit keeps the charge
	var s6: RefCounted = Sim.new(3)
	_run(s6, 20)
	var c6: int = s6.robots[0].charge
	_ok("edit keeps charge", c6 < Sim.CELL and s6.set_move(0, "a", 3) and s6.robots[0].charge == c6 and s6.robots[0].tile == Sim.BAYS[0]
		and s6.events.back().type == "edited")
	_ok("a count is kept to 1..9", s6.set_move(0, "a", 40) and s6.robots[0].nodes.a.n == 9 and s6.set_move(0, "a", 0) and s6.robots[0].nodes.a.n == 1)
	_ok("set_move is a Move's, set_turn a Turn's, and a Turn only right or left", not s6.set_move(0, "b", 2) and not s6.set_turn(0, "a", Sim.RIGHT)
		and not s6.set_turn(0, "b", 2) and not s6.set_turn(0, "b", Sim.LEFT) and s6.set_turn(0, "b", Sim.RIGHT) and s6.robots[0].nodes.b.facing == Sim.RIGHT
		and not Bots.faces_home(s6.robots[0]))
	# no cell
	var s7: RefCounted = Sim.new(3)
	_tick(s7)
	_ok("no cell", s7.unfit(0, s7.robots[0].parts.find("battery")) and s7.bin.battery == 1 and _tick(s7).any(func(e: Dictionary) -> bool: return e.type == "stuck")
		and s7.robots[0].stuck == "nocell" and _after(s7, 30).robots[0].tile == Sim.BAYS[0])
	_ok("and runs with it back", s7.fit(0, "battery") and s7.bin.battery == 0 and _after(s7, 30).robots[0].stuck == "" and s7.robots[0].tile != Sim.BAYS[0])
	_ok("a priced part waits for its milestone", not s7.fit(0, "fast") and _refused(s7, "later"))

## No two things on one tile: a robot waits, for no charge, behind a robot,
## a station, a belt or a thing lying, and goes when it is clear; no belt is
## laid under a robot and nothing is let go onto one.
func _check_room() -> void:
	var sim: RefCounted = Sim.new(3)
	var lead: Dictionary = Bots.new_robot("Lead", Vector2i(10, 8), ["treads", "battery"], [["move", 3], ["turn", Sim.RIGHT], ["turn", Sim.RIGHT],
		["move", 3], ["turn", Sim.RIGHT], ["turn", Sim.RIGHT]])
	var tail: Dictionary = Bots.new_robot("Tail", Vector2i(10, 7), ["treads", "gripper", "battery"], [["move", 2]])
	lead.dock = Vector2i(10, 8)
	sim.robots = [tail, lead]
	sim.milestone = 1
	sim.coins = 10
	_ok("no belt under a robot", not sim.can_lay(Vector2i(10, 8)) and not sim.lay_belt(Vector2i(10, 8), 0) and _refused(sim, "robot"))
	_ok("nothing let go onto one", not sim.takes(Vector2i(10, 8), {"id": 99, "kind": "square", "at": 0.5, "from": -1, "was": Vector2.ZERO}))
	# the tail's first step is onto the lead, who has not set off: it waits
	var c: int = tail.charge
	var waits := 0
	var both := 0
	_until_pc(sim, 0, "a", 10)
	for i in 60:
		for e: Dictionary in _tick(sim):
			waits += 1 if e.type == "wait" and e.robot == 0 else 0
		both += 1 if tail.tile == lead.tile or tail.tile == lead.was or tail.was == lead.tile else 0
		if tail.pc != "a":
			break
	_ok("a robot waits behind another and goes on once it is clear", waits == 1 and both == 0 and tail.tile == Vector2i(10, 9), "%d %d %s" % [waits, both, tail.tile])
	_ok("a wait costs no charge", c - tail.charge == 2, str(c - tail.charge))
	# a thing lying, a belt and a station are walls to it
	var w: RefCounted = Sim.new(3)
	w.milestone = 1
	w.coins = 10
	var walker: Dictionary = Bots.new_robot("Walker", Vector2i(12, 2), ["treads", "battery"], [["move", 1]])
	w.robots = [walker]
	w.put(Vector2i(12, 3), {"id": 98, "kind": "square", "at": 0.5, "from": -1, "was": Vector2.ZERO})
	_run(w, 30)
	_ok("a thing lying stops it", walker.tile == Vector2i(12, 2) and walker.bubble == "wait")
	w.take(Vector2i(12, 3))
	w.lay_belt(Vector2i(12, 3), 0)
	_run(w, 30)
	_ok("and so does a belt", walker.tile == Vector2i(12, 2) and walker.bubble == "wait")
	w.sell(Vector2i(12, 3))
	_run(w, 8)
	_ok("and once it is gone it walks on", walker.tile.y > 2 and walker.bubble == "")
	var near: Dictionary = Bots.new_robot("Near", Sim.STATIONS.table + Vector2i(0, -1), ["treads", "battery"], [["move", 1]])
	w.robots = [near]
	_run(w, 30)
	_ok("nor does it step onto a station", near.tile == Sim.STATIONS.table + Vector2i(0, -1) and near.bubble == "wait")

## A floor's Dictionary into the throwaway file, as `save()` writes one.
func _write(d: Dictionary, version: int) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("factory", "version", version)
	cfg.set_value("factory", "state", Marshalls.variant_to_base64(d))
	cfg.save(Sim.path)

## A full box on the deliver pad (a throwaway floor's).
func _sell_full(sim: RefCounted) -> void:
	sim.put(T, sim.take(S))
	_fill(sim, Sim.BOX_FULL)
	sim.put(D, sim.take(T))

func _check_pace() -> void:
	var sim: RefCounted = Sim.new(3)
	_ok("pace blank under two", sim.pace_ticks() == 0 and sim.pace_s() == 0.0 and sim.sold_at.is_empty() and sim.milestone == 0 and sim.held_for == 0)
	_ok("milestone 0 is the start", Sim.MILESTONES[0].id == "line" and sim.milestone_open(0) and not sim.milestone_open(1))
	# a total never opens it: one full box sold, then nothing
	var one: RefCounted = Sim.new(5)
	one.robots = []
	_sell_full(one)
	_run(one, 2000)
	_ok("a total never opens it", one.sold_at.size() == 1 and one.pace_ticks() == 0 and one.milestone == 0 and one.held_for == 0)
	_ok("one box sold reads one, not none", Art.pace_text(one) == TranslationServer.translate("FACTORY_PACE_ONE")
		and Art.pace_text(sim) == TranslationServer.translate("FACTORY_PACE_NONE") and Art.pace_text(one) != Art.pace_text(sim), Art.pace_text(one))
	_ok("the next milestone's ask", Art.next_text(sim) == TranslationServer.translate("FACTORY_PACE_NEXT") % "34"
		and Art.milestone_name("belts") == TranslationServer.translate("FACTORY_MILESTONE_BELTS"), Art.next_text(sim))
	var two: RefCounted = Sim.new(5)
	two.robots = []
	_sell_full(two)
	_run(two, 5)
	_sell_full(two)
	_ok("two sold close together read a gap of the five ticks between", two.sold_at.size() == 2 and two.pace_ticks() == 5)
	_run(two, 3000)
	_ok("and a pace not kept up opens nothing", two.milestone == 0 and two.held_for == 0 and two.sold_at.size() == 2)
	# the fresh floor: belts locked
	_ok("belts locked before 1", not sim.unlocked("belt") and not sim.unlocked("fast") and not sim.unlocked("bridge")
		and not sim.lay_belt(Vector2i(8, 8), 0) and _refused(sim, "locked") and sim.belts.is_empty())
	var rows: Array = sim.bin_rows()
	var by: Dictionary = {}
	for r: Dictionary in rows:
		by[r.part] = r
	_ok("the bin before 1: the gripper spare, fast and plug later, the rest none",
		rows.size() == Sim.PARTS.size() and by.gripper.state == "spare" and by.gripper.n == 1 and by.fast.state == "later" and by.plug.state == "later"
		and by.treads.state == "none" and by.battery.state == "none" and by.fast.price == 30 and by.plug.price == 40)
	# the pace bot: the three fixes on a fresh floor, then run
	_ok("the three fixes apply", _fix_all(sim))
	var opened := _until_event(sim, "milestone", 60000)
	var reading: int = sim.pace_ticks()
	print("pace: %d ticks a box after the three fixes (%.1f s)" % [sim.pace_ticks(), sim.pace_s()])
	_ok("milestone 1 opens from the three fixes alone", opened > 0 and sim.milestone == 1 and sim.milestone_open(1) and not sim.milestone_open(2),
		"%d ticks" % opened)
	# which is seen again on a long run: how the gaps lie
	var gaps: Array = []
	var last: int = sim.sold_at.back() if not sim.sold_at.is_empty() else 0
	for i in 6000:
		for e: Dictionary in _tick(sim):
			if e.type == "sale" and e.amount == Sim.PAY_FULL:
				gaps.append(sim.tick_n - last)
				last = sim.tick_n
	print("pace: gaps over 6000 more ticks ", gaps)
	_ok("belts open at 1", sim.unlocked("belt") and sim.unlocked("fast") and sim.unlocked("bridge") and sim.coins >= 1 and sim.lay_belt(Vector2i(8, 8), 0))
	_ok("and the bin shows fast and plug at their price", sim.bin_rows().filter(func(r: Dictionary) -> bool: return r.state == "price").size() == 2)
	# a stall: held_for climbs, then a starved floor takes it back to 0
	var st: RefCounted = Sim.new(3)
	_fix_all(st)
	var climbed := 0
	for i in 6000:
		st.step(Sim.TICK)
		if st.held_for > 0:
			break
	# the floor is emptied where it stands: nothing more is sold
	st.feed_on = false
	st.queue = 0
	st.table = {}
	st.items = {}
	for b: Dictionary in st.robots:
		b.held = {}
	for i in 700:
		st.step(Sim.TICK)
		climbed = maxi(climbed, st.held_for)
	_ok("hold resets on a stall", climbed >= 300 and st.held_for == 0 and st.milestone == 0, "peak %d, now %d" % [climbed, st.held_for])
	# the rates are what the bot read
	var lax: int = Sim.MILESTONES[1].every
	_ok("rate 1 sits 20% over the bot's reading (to 10 ticks), rate 2 is half of it", lax == roundi(reading * 1.2 / 10.0) * 10 and Sim.MILESTONES[2].every * 2 == lax,
		"reading %d, rates %d and %d" % [reading, lax, Sim.MILESTONES[2].every])
	# Fast plug halves the pause, Fast treads halve the walk
	sim.coins = 200
	var span1 := _charge_span(sim, 0)
	_ok("a charge pause is units long", span1 > 0, "%d ticks" % span1)
	var coins: int = sim.coins
	_ok("fast plug is bought", sim.fit(0, "plug") and sim.coins == coins - 40 and sim.robots[0].parts.has("plug") and sim.bin_rows().any(
		func(r: Dictionary) -> bool: return r.part == "plug" and r.state == "price"))
	var span2 := _charge_span(sim, 0)
	_ok("fast plug halves the pause", span2 > 0 and absi(span2 * 2 - span1) <= 2, "%d -> %d ticks" % [span1, span2])
	_ok("fast treads halve the walk", Bots.step_ticks(sim.robots[0]) == 4 and sim.fit(0, "fast") and Bots.step_ticks(sim.robots[0]) == 2)
	var twice: bool = not sim.fit(0, "fast") and _refused(sim, "fitted")
	sim.coins = 0
	_ok("a part is not bought twice, nor without coins", twice and not sim.fit(1, "fast") and _refused(sim, "coins"))
	# milestone 2 has nothing behind it in this build: a floor that keeps its
	# rate never opens it
	sim.coins = 500
	for i in [1, 2]:
		sim.fit(i, "fast")
		sim.fit(i, "plug")
	var opened2 := 0
	for i in 3000:
		for e: Dictionary in _tick(sim):
			if e.type == "milestone":
				opened2 += 1
	print("pace: %d ticks a box with fast treads and plug on all three" % sim.pace_ticks())
	_ok("nothing asked past BUILT", Art.next_text(sim) == "", Art.next_text(sim))
	# (since the 30 by 15 room the all fast floor, 193, is slower than
	# milestone 2's 170, so this no longer shows BUILT holding a rate met)
	_ok("the pace stops at BUILT", Sim.BUILT == 1 and opened2 == 0 and sim.milestone == Sim.BUILT and sim.held_for == 0
		and sim.pace_ticks() > 0, "pace %d, milestone %d" % [sim.pace_ticks(), sim.milestone])
	# a floor saved mid hold plays on as the original does
	var rt: RefCounted = Sim.new(3)
	_fix_all(rt)
	for i in 6000:
		rt.step(Sim.TICK)
		if rt.held_for > 0:
			break
	_run(rt, 137)
	var held_at: int = rt.held_for
	rt.save()
	var back: RefCounted = Sim.new(1)
	var same: bool = back.load_saved() and var_to_str(back.pack()) == var_to_str(rt.pack())
	_ok("the pace is kept: stamps, hold and milestone", same and held_at > 0 and back.held_for == held_at and back.sold_at == rt.sold_at and back.sold_at.size() >= 2
		and back.pack().has_all(["sold_at", "held_for", "milestone"]))
	for i in 500:
		rt.step(Sim.TICK)
		back.step(Sim.TICK)
	_ok("round trip mid loop", var_to_str(back.pack()) == var_to_str(rt.pack()), "held %d, milestone %d" % [rt.held_for, rt.milestone])
	# the load guard
	var fresh: RefCounted = Sim.new(3)
	var was := var_to_str(fresh.pack())
	for bad_key: Array in [["milestone", 7], ["milestone", -1], ["held_for", -3], ["held_for", Sim.HOLD + 1], ["sold_at", ["x"]]]:
		var bad: Dictionary = rt.pack()
		bad[bad_key[0]] = bad_key[1]
		_write(bad, Sim.VERSION)
		_ok("a floor with %s %s is refused" % [bad_key[0], bad_key[1]], not fresh.load_saved() and var_to_str(fresh.pack()) == was)
	var gone: Dictionary = rt.pack()
	gone.erase("sold_at")
	_write(gone, Sim.VERSION)
	_ok("so is one that kept no stamps", not fresh.load_saved())
	DirAccess.remove_absolute(Sim.path)

## The ticks of robot `i`'s next pause to charge: from its `charging` event to
## its `charged` one, -1 past 2000 ticks.
func _charge_span(sim: RefCounted, i: int) -> int:
	if _until_event(sim, "charging", 2000, i) < 0:
		return -1
	var n := _until_event(sim, "charged", 2000, i)
	return n
