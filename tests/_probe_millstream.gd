extends SceneTree

## Plays Millstream's slice 1 through the sim alone, as a player would, and
## prints what happened: dig ore by hand at a tap a second, build a kiln as
## soon as one is affordable (then a second), tend each kiln every few
## seconds, and hand the milestone in the moment it can be. Also checks the
## refusals and a save round trip.
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
			for b: Dictionary in s.buildings:
				s.tend(b.id)
		if s.can_hand_in():
			s.hand_in()
		for ev: Dictionary in s.events:
			kinds[ev.type] = int(kinds.get(ev.type, 0)) + 1
			if ev.type in ["placed", "milestone"]:
				print("%6.1fs %s %s" % [s.t, ev.type, ev])
		s.events.clear()
	print("finished=%s done_t=%.1f mined=%d smelted=%d stock=%s" % [s.finished(), s.done_t, s.mined, s.smelted, s.stock])
	print("events: ", kinds)
	var back = Sim.from_dict(s.to_dict())
	print("save round trip: ", JSON.stringify(back.to_dict()) == JSON.stringify(s.to_dict()), " kiln at (10,12): ", not back.building_at(Vector2i(11, 13)).is_empty())
	var id: int = s.buildings[0].id
	var ore_before := int(s.stock.iron_ore)
	s.remove(id)
	print("removed refunds ore: ", int(s.stock.iron_ore) - ore_before, " cell free: ", s.owner_at(Vector2i(10, 12)) == "")
	quit()
