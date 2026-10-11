extends SceneTree
const Sim = preload("res://factory/sim.gd")
var n := 0
func ok(c: bool, what: String) -> void:
	n += 1
	if not c:
		print("FAIL ", what)
func _process(_d: float) -> bool:
	Sim.path = "user://_tmp_factory.cfg"
	var s := Sim.new(7)
	ok(s.plates.size() == 2 and s.plates[Vector2i.ZERO] == "neutral" and s.plates[Vector2i(0, -1)] == "forest", "two plates")
	ok(s.trees.size() == Sim.TREES, "trees")
	ok(not s.can_lay(Vector2i(3, -1)) and not s.can_lay(Vector2i(4, -4)) and s.can_lay(Vector2i(3, 0)), "forest closed")
	ok(not s.unlocked("firebox") and s.plate_price() == 50, "locked, price 50")
	ok(s.tap(Vector2i(4, -4)), "tap")
	s.step(0.1)
	ok(s.items.has(Vector2i(3, 0)) and s.forests[Vector2i(0, -1)].stock == 0, "log lies past the gate")
	for i in 20:
		s.tap(Vector2i(4, -4))
		s.step(0.1)
	ok(s.forests[Vector2i(0, -1)].stock == Sim.FOREST_ROOM and (s.items[Vector2i(3, 0)] as Array).size() == 2, "fills: %s" % [s.forests])
	ok(not s.tap(Vector2i(4, -4)), "full refused")
	for y in 7:
		ok(s.lay_belt(Vector2i(3, y), 1), "belt %d" % y)
	for x in [3, 4, 5]:
		s.lay_belt(Vector2i(x, 6), 0)
	ok(s.belts.size() == 9 and s.coins == 11, "9 belts, coins %d" % s.coins)
	for i in 1200:
		s.step(0.1)
	ok(s.coins == 11 + 14 and s.forests[Vector2i(0, -1)].stock == 0, "14 sold: coins %d %s" % [s.coins, s.forests])
	s.coins = 60
	ok(s.upgrade_price(Vector2i(2, -3)) == 60 and s.upgrade(Vector2i(2, -3)) and s.forest_rate(Vector2i(0, -1)) == 1.0, "auto bought")
	var before: int = s.earned
	for i in 600:
		s.step(0.1)
	ok(s.earned - before == 15, "a minute of auto through a 4 s market: %d" % (s.earned - before))
	s.coins = 50
	ok(s.buy_plate(Vector2i(1, 0), "neutral") and s.unlocked("retort") and s.unlocked("firebox") and not s.unlocked("kiln") and s.plate_price() == 150, "plate bought")
	s.coins = 150
	ok(s.buy_plate(Vector2i(1, -1), "forest") and s.forests.size() == 2 and s.plate_price() == 450, "second forest")
	s.save()
	var packed: Dictionary = s.pack()
	var r := Sim.new(1)
	ok(r.load_saved() and r.pack() == packed, "save round trip")
	for i in 50:
		s.step(0.1)
		r.step(0.1)
	ok(r.pack() == s.pack(), "plays on the same")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://_tmp_factory.cfg"))
	print("checks %d done" % n)
	quit()
	return true
