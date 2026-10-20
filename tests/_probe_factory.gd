extends SceneTree

## Factory's sim, headless: the floor's rules.
##
##     godot --headless --path . --script res://tests/_probe_factory.gd
##
## The checks: a new floor has its five stations where STATIONS says and
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
## Everything runs on a throwaway file.

const Sim = preload("res://factory/sim.gd")

const T := Vector2i(4, 5)     # the pack table
const D := Vector2i(8, 5)     # the deliver pad
const I := Vector2i(1, 5)     # the intake pad
const S := Vector2i(4, 1)     # the box stack
const B := Vector2i(1, 1)     # the charging bay

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

func _refused(sim: RefCounted, why: String) -> bool:
	var e: Dictionary = sim.events.back() if not sim.events.is_empty() else {}
	return e.get("type", "") == "refused" and e.get("why", "") == why

# --- the checks ---

func _check_floor() -> void:
	var sim: RefCounted = Sim.new(7)
	_ok("a new floor is version 5, 10 x 8, nothing on it, no coins, a gripper in the bin", Sim.VERSION == 5 and Sim.COLS == 10 and Sim.ROWS == 8
		and sim.coins == 0 and sim.earned == 0 and sim.queue == 0 and sim.table.is_empty() and sim.items.is_empty() and sim.belts.is_empty()
		and sim.robots.is_empty() and sim.bin == {"gripper": 1})
	_ok("floor stations", sim.station_at(T) == "table" and sim.station_at(B) == "charger" and sim.station_at(Vector2i(2, 2)) == ""
		and sim.station_at(I) == "intake" and sim.station_at(S) == "stack" and sim.station_at(D) == "deliver" and sim.stations.size() == 5 and Sim.BAY == B)
	_ok("the floor's edge", sim.on_floor(Vector2i(0, 0)) and sim.on_floor(Vector2i(9, 7)) and not sim.on_floor(Vector2i(10, 0))
		and not sim.on_floor(Vector2i(0, 8)) and not sim.on_floor(Vector2i(-1, 3)))
	_ok("no belt on a station", not sim.can_lay(T) and sim.can_lay(Vector2i(2, 5)) and not sim.can_lay(Vector2i(10, 5)))
	_ok("no belt on the drawn intake and deliver columns", not sim.can_lay(Vector2i(0, 3)) and not sim.can_lay(Vector2i(Sim.COLS - 1, 3))
		and sim.can_lay(Vector2i(1, 3)) and sim.can_lay(Vector2i(Sim.COLS - 2, 3)))
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
	_ok("floor holds a stack", sim.put(Vector2i(2, 2), sq) and sim.put(Vector2i(2, 2), sq2) and sim.gives(Vector2i(2, 2)).id == sq2.id
		and sim.take(Vector2i(2, 2)).id == sq2.id and _lying(sim, Vector2i(2, 2)) == 1)
	_ok("a Pick on bare floor with nothing there takes nothing", sim.gives(Vector2i(6, 6)).is_empty() and sim.take(Vector2i(6, 6)).is_empty())
	# the bay, the stack and the intake pad take a Release as floor does
	var lay: Dictionary = _square(sim)
	_ok("a Release on the bay lies there", sim.put(B, lay) and _lying(sim, B) == 1 and sim.take(B).id == lay.id)
	sim.queue = 0
	lay = sim.take(S)
	_ok("and on the intake pad, which then gives it back with the queue empty", sim.put(I, lay) and _lying(sim, I) == 1 and sim.gives(I).id == lay.id)
	sim.queue = 1
	_ok("but with a square queued the queue goes first", sim.take(I).kind == "square" and _lying(sim, I) == 1 and sim.take(I).id == lay.id)

func _check_belts() -> void:
	var sim: RefCounted = Sim.new(7)
	sim.coins = 100
	var box: Dictionary = sim.take(S)
	sim.put(T, box)
	# a belt from the intake pad's side to the table carries a square into the box
	_belt_row(sim, Vector2i(2, 5), 2, 0)   # (2,5),(3,5) facing +x into the table
	_ok("two belts laid for a coin each", sim.coins == 98 and sim.belt_kind(Vector2i(2, 5)) == "belt" and sim.price("belt") == 1)
	var sq3: Dictionary = _square(sim)
	_ok("belt feeds the table", sim.put(Vector2i(2, 5), sq3) and _until_table_n(sim, 1, 200) and sim.items.is_empty())
	_ok("a Pick on a belt takes its front", sim.put(Vector2i(2, 5), _square(sim)) and sim.front_of_tile(Vector2i(2, 5)).kind == "square"
		and sim.take(Vector2i(2, 5)).kind == "square" and sim.front_of_tile(Vector2i(2, 5)).is_empty())
	for i in 4:
		sim.put(Vector2i(2, 5), _square(sim))
		_run(sim, 25)
	_run(sim, 60)
	var waits: Array = sim.items.get(Vector2i(3, 5), [])
	_ok("belt waits at a full box", int(sim.table.n) == 4 and waits.size() == 1 and is_equal_approx(float(waits[0].at), 1.0) and not sim.items.has(Vector2i(2, 5)),
		"n %d, %s" % [int(sim.table.n), str(sim.items.keys())])
	sim.take(T)
	sim.put(T, sim.take(S))
	_run(sim, 5)
	_ok("and goes on into the next box", int(sim.table.n) == 1 and not sim.items.has(Vector2i(3, 5)))
	# a belt into the deliver pad sells
	_belt_row(sim, Vector2i(6, 5), 2, 0)
	var c: int = sim.coins
	sim.put(Vector2i(6, 5), _square(sim))
	_ok("a belt into the deliver pad sells", _until(sim, "sale", 100) > 0 and sim.coins == c + 1 and sim.items.is_empty())
	# into the intake pad, the bay or the stack nothing goes: the belt waits
	for at: Vector2i in [I, B, S]:
		var w: RefCounted = Sim.new(1)
		w.coins = 10
		var from: Vector2i = at + Vector2i(1, 0)
		w.lay_belt(from, 2)
		w.put(from, _square(w))
		_run(w, 50)
		_ok("a belt into the %s waits" % w.station_at(at), _lying(w, from) == 1 and is_equal_approx(float(w.items[from][0].at), 1.0) and _lying(w, at) == 0)
	# a belt flipped beside the table runs into it
	var f: RefCounted = Sim.new(1)
	f.coins = 10
	_belt_row(f, Vector2i(4, 6), 3, 0)
	_ok("a line flipped by the table ends into it", f.flip_line(Vector2i(5, 6)) and int(f.belts[Vector2i(4, 6)]) == 3 and int(f.belts[Vector2i(5, 6)]) == 2)
	# the fast belt and the bridge
	var k: RefCounted = Sim.new(1)
	k.coins = 1000
	_belt_row(k, Vector2i(2, 2), 3, 0)
	for i in 3:
		k.lay_belt(Vector2i(2 + i, 3), 0, "fast")
	_ok("a fast belt is four coins and carries twice as far", k.coins == 1000 - 3 - 12 and k.belt_seconds(Vector2i(2, 3)) == 1.0 and k.unlocked("fast") and k.unlocked("bridge"))
	k.put(Vector2i(2, 2), _square(k))
	k.put(Vector2i(2, 3), _square(k))
	_run(k, 20)
	_ok("so in two seconds", k.items.has(Vector2i(3, 2)) and k.items.has(Vector2i(4, 3)), str(k.items.keys()))
	k.items.clear()
	var bk: RefCounted = Sim.new(1)
	bk.coins = 1000
	_belt_row(bk, Vector2i(2, 3), 5, 0)
	_belt_row(bk, Vector2i(5, 1), 2, 1)
	_belt_row(bk, Vector2i(5, 4), 2, 1)
	c = bk.coins
	_ok("a bridge is laid on a belt for the difference", bk.lay_belt(Vector2i(5, 3), 0, "bridge") and bk.belt_kind(Vector2i(5, 3)) == "bridge" and bk.coins == c - 24)
	var across := 0
	var under := 0
	var wrong := 0
	for i in 600:
		if i % 10 == 0 and i < 300:
			bk.put(Vector2i(2, 3), _square(bk))
			bk.put(Vector2i(5, 1), bk.take(S))
		bk.step(Sim.TICK)
		for end: Vector2i in [Vector2i(6, 3), Vector2i(5, 5)]:
			if bk.items.has(end) and float(bk.items[end][0].at) >= 1.0 - 0.001:
				var it: Dictionary = bk.items[end].pop_front()
				if bk.items[end].is_empty():
					bk.items.erase(end)
				if end == Vector2i(6, 3):
					under += 1 if it.kind == "square" else 0
					wrong += 0 if it.kind == "square" else 1
				else:
					across += 1 if it.kind == "box" else 0
					wrong += 0 if it.kind == "box" else 1
	_ok("thirty squares under a bridge and thirty boxes over, none mixed", under == 30 and across == 30 and wrong == 0, "%d %d %d" % [under, across, wrong])
	c = bk.coins
	_ok("a belt sold gives its price back, what rode it lies", bk.put(Vector2i(2, 3), _square(bk)) and bk.sell(Vector2i(2, 3)) and bk.coins == c + 1
		and not bk.belts.has(Vector2i(2, 3)) and _lying(bk, Vector2i(2, 3)) == 1)
	_ok("and a line sold in one go", bk.sell_belts([Vector2i(3, 3), Vector2i(4, 3)]) and bk.coins == c + 3 and bk.events.back().type == "sold_line")
	_ok("a station is nothing to sell or turn", not bk.sell(T) and not bk.turn(T))

func _check_kept() -> void:
	var sim: RefCounted = Sim.new(7)
	sim.coins = 100
	_run(sim, 70)
	sim.put(T, sim.take(S))
	_fill(sim, 2)
	_belt_row(sim, Vector2i(2, 5), 2, 0)
	sim.lay_belt(Vector2i(6, 6), 0, "bridge")
	sim.put(Vector2i(2, 5), sim.take(I))
	sim.put(Vector2i(7, 2), sim.take(S))
	sim.put(Vector2i(7, 2), sim.take(I))
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
	_ok("the save is version 5 and holds the floor, nothing of the land", kept.version == 5 and kept.has_all(["queue", "table", "robots", "bin", "tick_n"])
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
				s.put(Vector2i(2, 5), s.take(I))
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
	shaped.items[Vector2i(7, 2)][0].kind = "log"
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

## A floor's Dictionary into the throwaway file, as `save()` writes one.
func _write(d: Dictionary, version: int) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("factory", "version", version)
	cfg.set_value("factory", "state", Marshalls.variant_to_base64(d))
	cfg.save(Sim.path)
