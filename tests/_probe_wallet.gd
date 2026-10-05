extends SceneTree

## Gold, gifts and boosters (spec 2026-09-28-gold-gifts-design.md), headless:
## every new script instantiates, the wallet's arithmetic holds (welcome,
## calendar with its grace, hearts gift, board and run pay, buy and use), and
## every booster and Second chance lands on a real sim. Writes only to a
## throwaway wallet file.
##   godot --headless --script tests/_probe_wallet.gd

const Boosters = preload("res://arcade/boosters.gd")

var _fails := 0
var _frames := 0

func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
		print("FAIL ", what)
	else:
		print("ok   ", what)

func _process(_d: float) -> bool:
	_frames += 1
	if _frames < 2:
		return false
	var wallet: Node = root.get_node("Wallet")
	var tmp := OS.get_user_data_dir() + "/_probe_wallet.cfg"
	DirAccess.remove_absolute(tmp)
	wallet.path = tmp
	wallet.reload()

	for p in ["res://core/wallet.gd", "res://arcade/boosters.gd", "res://arcade/booster_icon.gd", "res://arcade/boost_card.gd",
			"res://arcade/second_chance.gd", "res://ui/menu/gold_pill.gd", "res://ui/hud/gifts_sheet.gd", "res://ui/hud/shop_sheet.gd",
			"res://ui/menu/arcade_tab.gd", "res://ui/menu/menu_header.gd", "res://ui/menu.gd", "res://ui/flat/flat_host.gd",
			"res://arcade/firefly_screen.gd", "res://arcade/molehill_screen.gd", "res://arcade/stackwood_screen.gd",
			"res://arcade/thirteen_screen.gd", "res://arcade/posy_screen.gd", "res://arcade/peapod_screen.gd"]:
		var s: GDScript = load(p)
		_check(s != null and s.can_instantiate(), "compiles " + p)

	# welcome
	_check(wallet.gold() == 150, "welcome gold 150 (got %d)" % wallet.gold())
	_check(wallet.count("ff_spare") == 1 and wallet.count("second_chance") == 1, "one of each booster")

	# calendar: day 1, same day again refused, next day is day 2, one missed
	# day forgiven, two missed start over, day 7 wraps
	var d0 := 20260901
	_check(wallet.calendar_step(d0) == 0 and wallet.calendar_open(d0), "calendar opens on day 1")
	var g: Dictionary = wallet.claim_calendar(d0)
	_check(int(g.gold) == 50 and wallet.gold() == 200, "day 1 pays 50")
	_check(wallet.claim_calendar(d0).is_empty(), "day 1 twice refused")
	_check(wallet.calendar_step(20260902) == 1, "next day is day 2")
	wallet.claim_calendar(20260902)
	_check(wallet.calendar_step(20260904) == 2, "one missed day forgiven")
	_check(wallet.calendar_step(20260905) == 0, "two missed days start over")
	var key := 20260904
	for i in 5:
		wallet.claim_calendar(key)
		key = Streak.next_day(key)
	_check(wallet.calendar_step(key) == 0, "after day 7 the week wraps (step %d)" % wallet.calendar_step(key))
	var seventh: Dictionary = wallet.calendar_gift(6, key)
	_check(int(seventh.gold) == 250 and seventh.items.size() == 2, "day 7 is 250 + two kinds of item")

	# earning
	var before: int = wallet.gold()
	_check(wallet.pay_board("binairo", 20260910) == 20 and wallet.pay_board("binairo", 20260910) == 0, "a board pays once a day")
	_check(wallet.pay_board("binairo", 20260911) == 20, "and again the next day")
	var runs := 0
	for i in 20:
		runs += wallet.pay_run(i == 0, 20260910)
	_check(runs == 60, "arcade capped at 60 a day (got %d)" % runs)
	_check(wallet.gold() == before + 40 + 60, "gold adds up")

	# buy and use
	wallet.add_gold(1000, "probe")
	var g0: int = wallet.gold()
	var n0: int = wallet.count("mh_time")
	_check(wallet.buy("mh_time") and wallet.count("mh_time") == n0 + 1 and wallet.gold() == g0 - 120, "buy one")
	_check(wallet.use("mh_time", "molehill") and wallet.count("mh_time") == n0, "use one")
	while wallet.count("sw_low") > 0:
		wallet.use("sw_low", "stackwood")
	_check(wallet.count("sw_low") == 0 and wallet.use("sw_low", "stackwood", true) and wallet.count("sw_low") == 0, "use with none held buys it")
	_check(Boosters.featured(20260910) != Boosters.featured(20260911), "featured rotates by day")

	# every booster on its sim, and every Second chance
	var ff = load("res://arcade/firefly_sim.gd").new(3)
	Boosters.apply("firefly", ff, ["ff_spare", "ff_twin"])
	_check(ff.ships == 4 and ff.pair, "firefly: four ships, a pair")
	ff.ships = 1
	ff.ship = 1
	ff._lose_ship()
	_check(ff.is_over(), "firefly over")
	Boosters.revive("firefly", ff)
	_check(not ff.is_over() and ff.ships == 1, "firefly revived")
	for i in 900:
		ff.step()
	_check(ff.ship == 0 or ff.is_over(), "firefly respawns after the revive (ship %d)" % ff.ship)

	var mh = load("res://arcade/molehill_sim.gd").new(3)
	Boosters.apply("molehill", mh, ["mh_time", "mh_steady"])
	_check(is_equal_approx(mh.time_left(), 70.0) and mh.forgive == 2, "molehill: 70 s, two forgiven")
	mh.streak = 3
	mh._break("miss", 0)
	_check(mh.streak == 3 and mh.forgive == 1, "a slip forgiven")
	for i in 60 * 75:
		mh.step()
	_check(mh.is_over(), "molehill over at 70 s")
	Boosters.revive("molehill", mh)
	_check(not mh.is_over() and mh.time_left() > 14.0, "molehill revived with %.1f s" % mh.time_left())

	var sw = load("res://arcade/stackwood_sim.gd").new(3)
	Boosters.apply("stackwood", sw, ["sw_acorns", "sw_low"])
	_check(sw.acorns == 200 and int(sw.queue[0]) <= 4 and int(sw.queue[1]) <= 4, "stackwood: acorns, small queue")
	# topple it by hand, then revive
	for c in 5:
		for i in 8:
			(sw.cols[c] as Array).append({"id": 1000 + c * 10 + i, "v": 1 << (1 + (i + c) % 6)})
	sw.phase = sw.Phase.OVER
	Boosters.revive("stackwood", sw)
	var tall := 0
	for c in 5:
		tall = maxi(tall, sw.height(c))
	_check(not sw.is_over() and tall <= 5, "stackwood revived, shelf at %d" % tall)

	var lt = load("res://arcade/thirteen_sim.gd").new(3)
	var v0: int = lt.value(Vector2i(0, 0))
	Boosters.apply("thirteen", lt, ["lt_clovers", "lt_head"])
	_check(lt.clovers == 60 and lt.value(Vector2i(0, 0)) == v0 + 1, "thirteen: clovers, head start")
	lt.give_up()
	Boosters.revive("thirteen", lt)
	_check(not lt.is_over() and lt.has_move(), "thirteen revived with a move")

	var po = load("res://arcade/posy_sim.gd").new(3)
	Boosters.apply("posy", po, ["po_kit", "po_bloom"])
	var sp := 0
	for c in 8:
		for r in 8:
			if po.special(Vector2i(c, r)) != 0:
				sp += 1
	var deal_sp := 0
	for ev: Dictionary in po.events:
		if String(ev.type) == "deal":
			for t: Dictionary in ev.tiles:
				if int(t.sp) != 0:
					deal_sp += 1
	_check(int(po.tools[0]) == 4 and sp == 2 and deal_sp == 2, "posy: tools, two specials in bed and deal")
	po.give_up()
	var m0: int = po.moves_left
	Boosters.revive("posy", po)
	_check(not po.is_over() and po.moves_left == m0 + 5, "posy revived with five moves")

	var pp = load("res://arcade/peapod_sim.gd").new(3)
	Boosters.apply("peapod", pp, ["pp_pea", "pp_quick"])
	_check(pp.power == 2 and pp.rate_lv == 1, "peapod: a heavier pea, a quicker gun")
	for i in 60 * 3:
		pp.step()
	pp.wall_y = 1000.0
	pp.step()
	_check(pp.is_over(), "peapod over at the line")
	Boosters.revive("peapod", pp)
	pp.step()
	_check(not pp.is_over() and pp.wall_y < pp.DANGER - 100.0, "peapod revived, the wall back at %.0f" % pp.wall_y)

	DirAccess.remove_absolute(tmp)
	print("FAILS: %d" % _fails)
	quit(1 if _fails > 0 else 0)
	return true
