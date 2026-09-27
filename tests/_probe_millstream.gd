extends SceneTree

## Plays Millstream's slice 1 through the sim alone, as a player would, and
## prints what happened: dig ore by hand at `taps` a second, pick what lies
## on the grass every few seconds, build a kiln as soon as one is
## affordable (then a second), feed each kiln from the bag, and hand the
## milestone in the moment it can be. Also checks the refusals, that
## nothing lands on water or a building, and a save round trip.
##
##     godot --headless --script res://tests/_probe_millstream.gd -- [taps a second]

const Sim = preload("res://arcade/millstream_sim.gd")

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var taps := float(args[0]) if args.size() > 0 else 3.0
	var s: Sim = Sim.new()
	var iron := Vector2i(7, 11)
	var spots := [Vector2i(10, 12), Vector2i(10, 9)]
	var tap_acc := 0.0
	var tend_acc := 0.0
	var bad_spots := 0
	var kinds := {}
	# refusals first
	print("dig copper: ", s.dig(Vector2i(12, 3)), " dig grass: ", s.dig(Vector2i(10, 10)))
	print("kiln unaffordable: ", s.place_refusal("kiln", spots[0]))
	print("kiln on water: ", s.place_refusal("kiln", Vector2i(0, 5)), " on mill: ", s.place_refusal("kiln", Vector2i(4, 13)), " edge: ", s.place_refusal("kiln", Vector2i(19, 27)))
	s.events.clear()
	while not s.finished() and s.t < 900.0:
		s.step()
		tap_acc += Sim.DT
		tend_acc += Sim.DT
		if tap_acc >= 1.0 / taps:
			tap_acc = 0.0
			s.dig(iron)
		if s.buildings.size() < spots.size() and s.affordable("kiln"):
			s.place("kiln", spots[s.buildings.size()])
		if tend_acc >= 4.0:
			tend_acc = 0.0
			s.pick(s.loose.map(func(it: Dictionary) -> int: return it.id))
			for b: Dictionary in s.buildings:
				s.feed(b.id, "iron_ore", 99)
		if s.can_hand_in():
			s.hand_in()
		for ev: Dictionary in s.events:
			kinds[ev.type] = int(kinds.get(ev.type, 0)) + 1
			if ev.has("loose"):
				var it: Array = s.loose.filter(func(x: Dictionary) -> bool: return x.id == ev.loose)
				var c := Vector2i((it[0].p as Vector2).floor())
				if not Sim.in_bounds(c) or Sim.is_water(c) or s.owner_at(c) != "":
					bad_spots += 1
			if ev.type in ["placed", "milestone"]:
				print("%6.1fs %s %s" % [s.t, ev.type, ev])
		s.events.clear()
	print("finished=%s done_t=%.1f mined=%d smelted=%d stock=%s" % [s.finished(), s.done_t, s.mined, s.smelted, s.stock])
	print("events: ", kinds, " loose left: ", s.loose.size(), " bad spots: ", bad_spots)
	print("feed ingot: ", s.feed(s.buildings[0].id, "iron_ingot", 5), " feed empty bag: ", s.feed(s.buildings[0].id, "iron_ore", 5) if int(s.stock.iron_ore) == 0 else -1, " events: ", s.events.map(func(e: Dictionary) -> String: return e.why))
	s.events.clear()
	var back = Sim.from_dict(s.to_dict())
	print("save round trip: ", JSON.stringify(back.to_dict()) == JSON.stringify(s.to_dict()), " kiln at (10,12): ", not back.building_at(Vector2i(11, 13)).is_empty(), " loose kept: ", back.loose.size())
	var v1 := {"v": 1, "t": 5.0, "stock": {"iron_ore": 3, "iron_ingot": 1}, "buildings": [{"id": 1, "kind": "kiln", "x": 10, "y": 12, "hopper": 2, "shelf": 4, "prog": 0.5}], "milestone": 0, "next_id": 2}
	var old = Sim.from_dict(v1)
	print("v1 save: ingots in bag ", old.stock.iron_ingot, " (want 5), kilns ", old.buildings.size())
	var id: int = s.buildings[0].id
	var ore_before := int(s.stock.iron_ore)
	s.remove(id)
	print("removed refunds ore: ", int(s.stock.iron_ore) - ore_before, " cell free: ", s.owner_at(Vector2i(10, 12)) == "")
	quit()
