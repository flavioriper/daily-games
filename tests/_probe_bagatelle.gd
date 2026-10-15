extends SceneTree

## Bagatelle's sim checked headless (arcade/bagatelle_sim.gd), and a greedy
## bot that plays it for a while and says how fast it went.
##   godot --headless --script tests/_probe_bagatelle.gd -- [seed] [minutes]
## The bot taps four times a second while the jar holds a marble, buys the
## cheapest run upgrade it can (Marbles only while the jar runs dry), merges
## while ten would leave it twice the marbles in the air, cashes out when the
## stars would at least double what it has, and spends stars cheapest first.

const Sim = preload("res://arcade/bagatelle_sim.gd")

var _fails := 0

func _check(what: String, ok: bool) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		_fails += 1

func _initialize() -> void:
	Sim.path = "user://_probe_bagatelle.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Sim.path))
	var args := OS.get_cmdline_user_args()
	var seed_v := int(args[0]) if args.size() > 0 else 7
	var minutes := float(args[1]) if args.size() > 1 else 0.0
	_physics(seed_v)
	_spread(seed_v)
	_rules(seed_v)
	_kept(seed_v)
	if minutes > 0.0:
		_pace(seed_v, minutes)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Sim.path))
	print("%d failed" % _fails)
	quit(1 if _fails > 0 else 0)

func _physics(seed_v: int) -> void:
	var s = Sim.new(seed_v)
	_check("starts with 3 clay marbles", s.in_jar() == 3 and s.owned[0] == 3)
	s.drop(500.0)
	_check("a drop takes one from the jar", s.in_jar() == 2 and s.balls.size() == 1)
	var landed := false
	var secs := 0.0
	while secs < 12.0:
		s.step(1.0 / 60.0)
		secs += 1.0 / 60.0
		for ev: Dictionary in s.events:
			if ev.type == "land":
				landed = true
		s.events.clear()
		if landed:
			break
	_check("the marble lands (%.2f s)" % secs, landed and secs > 0.6 and secs < 8.0)
	_check("and rolls back to the jar", s.in_jar() == 3)
	_check("paid coins", s.coins > 0.0)
	var hits: Vector2i = s.take_pins()
	_check("touched pins (%d)" % hits.x, hits.x >= 4)
	# no marble may stick: 200 drops all land within 15 s
	var s2 = Sim.new(seed_v + 1)
	s2.owned[0] = 200
	s2.jar[0] = 200
	for i in 200:
		s2.drop(s2.rng.randf_range(0.0, Sim.W), false)
	var t := 0.0
	while s2.balls.size() > 0 and t < 15.0:
		s2.step(1.0 / 30.0)
		t += 1.0 / 30.0
	_check("200 marbles all land (%.1f s)" % t, s2.balls.is_empty())
	var inside := true
	for ev: Dictionary in s2.events:
		if ev.type == "land" and (float(ev.x) < 0.0 or float(ev.x) > Sim.W):
			inside = false
	_check("every landing is on the board", inside)

func _spread(seed_v: int) -> void:
	for at: Array in [["middle", 500.0, true], ["aimed left", 0.0, true], ["wall", 0.0, false]]:
		var s = Sim.new(seed_v + 3)
		s.owned[0] = 1000
		s.jar[0] = 1000
		var tally := PackedInt32Array()
		tally.resize(Sim.CUPS)
		for i in 1000:
			s.drop(float(at[1]), bool(at[2]))
		var t := 0.0
		while not s.balls.is_empty() and t < 30.0:
			s.step(1.0 / 30.0)
			t += 1.0 / 30.0
		var paid := 0.0
		for ev: Dictionary in s.events:
			if ev.type == "land":
				tally[int(ev.cup)] += 1
				paid += float(ev.pay)
		print("  %s: cups %s, mean pay %.2f" % [at[0], str(tally), paid / 1000.0])
		if at[0] == "aimed left":
			_check("an aimed tap at the wall feeds the edge cup less than half (%d)" % tally[0], tally[0] < 500)

func _rules(seed_v: int) -> void:
	var s = Sim.new(seed_v)
	s.coins = 100.0
	var before := s.price("value")
	_check("buy value", s.buy("value") == 1 and is_equal_approx(s.coins, 100.0 - before))
	_check("value 2 after one rank", is_equal_approx(s.value(), 2.0))
	s.coins = 1e9
	var n: int = s.buy("auto", 0)
	_check("max buy stops at auto's top (%d)" % n, int(s.up.auto) == Sim.UP_TOP.auto)
	_check("auto every at least 0.1 s", s.auto_every() >= Sim.AUTO_LEAST - 0.0001)
	s.buy("marbles", 5)
	_check("marbles adds to the jar", s.owned[0] == 8 and s.jar[0] == 8)
	s.jar[0] = 25
	s.owned[0] = 25
	_check("merge all makes two glass", s.merge_all() == 2 and s.owned[1] == 2 and s.jar[0] == 5)
	_check("best tier noted", s.best_tier == 1)
	_check("drop takes the best first", s.drop(500.0) and int(s.balls[0].tier) == 1)
	s.earned = 1e6
	_check("stars for 1M earned is 8", s.stars_for() == 8)
	_check("next star past 1M", s.next_star_at() > 1e6 and s.stars_for(s.next_star_at() * 1.0001) == 9)
	_check("cash out pays 8", s.cash_out() == 8 and s.stars == 8)
	_check("a cash out resets the run", s.coins == 0.0 and int(s.up.value) == 0 and s.owned_all() == 3 and s.balls.is_empty())
	_check("a plus pin bought stands on the board", s.shop_buy("plus") and s.bonus.size() == 1)
	var from: int = s.bonus.keys()[0]
	var to := Sim.pin_id(8, 6)
	_check("a bonus pin moves", s.move_bonus(from, to) and s.bonus.has(to) and not s.bonus.has(from))
	_check("onto a bonus pin it does not", not s.move_bonus(to, to))
	_check("short 999", Sim.short(999.0) == "999")
	_check("short 12.4K", Sim.short(12400.0) == "12.4K")
	_check("short 3.1M", Sim.short(3100000.0) == "3.1M")
	_check("short 250B", Sim.short(2.5e11) == "250B")
	_check("short 1.2e40", Sim.short(1.2e40) == "1.2e40")
	_check("short 1Qa", Sim.short(1e15) == "1Qa")

func _kept(seed_v: int) -> void:
	var s = Sim.new(seed_v)
	s.coins = 1234.5
	s.up.value = 3
	s.stars = 7
	s.stars_ever = 9
	s.shop.plus = 2
	s._place_bonus()
	s.owned[0] = 4
	s.owned[2] = 1
	s.cup_lv[3] = 12
	s.best_tier = 2
	s.drop(500.0)
	s.save()
	var l = Sim.load_saved()
	_check("kept coins", is_equal_approx(l.coins, 1234.5))
	_check("kept upgrades", int(l.up.value) == 3)
	_check("kept stars and shop", l.stars == 7 and int(l.shop.plus) == 2 and l.bonus.size() == 2)
	_check("marbles in the air come back to the jar", l.jar[2] == 1 and l.jar[0] == 4)
	_check("kept cups", l.cup_lv[3] == 12)
	var k := Sim.kept()
	_check("the card reads it", not k.new and int(k.stars) == 9 and int(k.tier) == 2)

func _pace(seed_v: int, minutes: float) -> void:
	var s = Sim.new(seed_v)
	var t := 0.0
	var tap := 0.0
	var marks := {}
	var next_print := 300.0
	var dt := 1.0 / 30.0
	while t < minutes * 60.0:
		s.step(dt)
		t += dt
		s.events.clear()
		tap += dt
		if tap >= 0.25:
			tap = 0.0
			if s.in_jar() > 0:
				s.drop(s.rng.randf_range(0.0, Sim.W))
			_bot_buy(s)
		if s.best_tier >= 3 and not marks.has("tier3"):
			marks["tier3"] = t
		if s.best_tier >= 5 and not marks.has("tier5"):
			marks["tier5"] = t
		if s.best_tier >= 4 and not marks.has("tier4"):
			marks["tier4"] = t
		if s.stars_ever >= 10 and not marks.has("stars10"):
			marks["stars10"] = t
		if s.cashouts >= 1 and not marks.has("cash1"):
			marks["cash1"] = t
		if t >= next_print:
			next_print += 300.0
			print("  %4.0f min  coins %s/s-ish  earned %s  stars %d (ever %d, outs %d)  up %s  tiers %s  cups %s" % [t / 60.0, Sim.short(s.earned / maxf(1.0, t)), Sim.short(s.earned), s.stars, s.stars_ever, s.cashouts, str(s.up), str(s.owned), str(s.cup_lv)])
	for k: String in marks:
		print("  %s at %.1f min" % [k, float(marks[k]) / 60.0])

func _bot_buy(s) -> void:
	# merge while the jar keeps more than twice what is in the air
	var air: int = s.balls.size()
	for k in Sim.TIERS - 1:
		while s.jar[k] >= Sim.MERGE and s.in_jar() - Sim.MERGE + 1 > air + 5:
			s.merge(k)
	# the cheapest upgrade the coins cover; marbles only when the jar runs dry
	var best := ""
	var bp := INF
	for id: String in Sim.UPS:
		if not s.can_buy(id):
			continue
		if id == "marbles" and s.in_jar() > maxi(3, air):
			continue
		var p: float = s.price(id)
		if p < bp:
			bp = p
			best = id
	if best != "":
		s.buy(best)
	var could: int = s.stars_for()
	if could >= maxi(3, s.stars_ever / 2):
		s.cash_out()
		var bought := true
		while bought:
			bought = false
			var cheap := ""
			var cp := 1 << 30
			for id: String in Sim.SHOP:
				if s.can_shop(id) and s.shop_price(id) < cp:
					cp = s.shop_price(id)
					cheap = id
			if cheap != "":
				s.shop_buy(cheap)
				bought = true
