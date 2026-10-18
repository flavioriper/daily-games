extends SceneTree

## Bagatelle's sim checked headless (arcade/bagatelle_sim.gd), and a greedy
## bot that plays it for a while and says how fast it went.
##   godot --headless --script tests/_probe_bagatelle.gd -- [seed] [minutes]
## The bot taps four times a second while the jar holds a marble, buys the
## cheapest run upgrade it can, merges while the jar keeps more than the air
## holds, cashes out when a cash out would pay half of what it has put into
## the shop since its last investment, spends SP cheapest first, makes each
## investment as soon as the SP cover it and ascends as soon as it may.

const Sim = preload("res://arcade/bagatelle_sim.gd")

var _fails := 0

## With "nocash" the bot never cashes out: the raw curve of one run.
var _no_cash := false
## A run's second-half gaps past this many times its first half's is FLAG.
const FLAT_RATIO := 1.3

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
	_no_cash = args.size() > 2 and args[2] == "nocash"
	if args.size() > 4:
		Sim.sp_div = float(args[3])
		Sim.sp_pow = float(args[4])
	if args.size() <= 4:
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
	_check("starts with 1 clay marble", s.in_jar() == 1 and s.owned[0] == 1)
	s.auto_off = true
	s.owned[0] = 3
	s.jar[0] = 3
	s.drop(400.0)
	_check("a tap asks the dropper, nothing falls yet", s.in_jar() == 3 and s.balls.is_empty())
	var x0: float = s.drop_x
	_run(s, 0.5)
	var let_x := -1.0
	for ev: Dictionary in s.events:
		if ev.type == "drop":
			let_x = float(ev.x)
	_check("the dropper lets one go where it is, not at the tap", s.in_jar() == 2 and s.balls.size() == 1 and absf(let_x - x0) < 20.0 and absf(x0 - 400.0) > 60.0)
	s.drop(900.0)
	s.drop(900.0)
	_run(s, 0.5)
	_check("two quick taps let two go, never past the band", s.balls.size() == 3 and float(s.balls[2].p.x) <= Sim.W * Sim.AIM_HI + 1.0 and float(s.balls[2].p.x) >= Sim.W * Sim.AIM_LO - 1.0)
	s.jar[0] += 2
	s.owned[0] += 2
	s.balls.pop_back()
	s.balls.pop_back()
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
	_check("the dropper glides on its own", _glides(s))
	_check("paid coins", s.coins > 0.0)
	var hits: Vector2i = s.take_pins()
	_check("touched pins (%d)" % hits.x, hits.x >= 4)
	# no marble may stick: 200 drops all land within 15 s
	var s2 = Sim.new(seed_v + 1)
	s2.owned[0] = 200
	s2.jar[0] = 200
	for i in 200:
		_let(s2, s2.rng.randf_range(Sim.BALL_R, Sim.W - Sim.BALL_R))
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
	var in_cup := true
	for ev: Dictionary in s2.events:
		if ev.type == "land":
			var x := float(ev.x)
			var xd: float = round(x / Sim.CUP_W) * Sim.CUP_W
			if xd > 1.0 and xd < Sim.W - 1.0 and absf(x - xd) < Sim.BALL_R + Sim.FIN_W - 0.5:
				in_cup = false
	_check("every landing is inside a cup, never on a fin", in_cup)
	# Auto: one marble every 2.5 s at level 1, never more
	var s3 = Sim.new(seed_v + 2)
	s3.owned[0] = 6
	s3.jar[0] = 6
	s3.up.auto = 1
	_run(s3, 20.0)
	_check("auto lets one marble go every 2.5 s (%d drops in 20 s)" % s3.drops, s3.drops >= 7 and s3.drops <= 9 and s3.balls.size() + s3.in_jar() == 6)
	# at 0.04 s (level 14) it lets 25 a second go, past the finger's gap
	var s4 = Sim.new(seed_v + 4)
	s4.owned[0] = 100
	s4.jar[0] = 100
	s4.up.auto = 14
	_run(s4, 1.0)
	_check("auto at 0.04 s lets ~25 go in a second (%d)" % s4.drops, s4.drops >= 22 and s4.drops <= 27)
	# weight: a heavy marble falls faster through the same pins
	var fall := []
	for lv in [0, 14]:
		var s5 = Sim.new(seed_v + 5)
		s5.auto_off = true
		s5.up.weight = lv
		s5.drop_here()
		var tt := 0.0
		var done := false
		while tt < 10.0 and not done:
			s5.step(1.0 / 60.0)
			tt += 1.0 / 60.0
			for ev: Dictionary in s5.events:
				if ev.type == "land":
					done = true
			s5.events.clear()
		fall.append(tt)
	_check("weight 20x falls ~4.5x faster (%.2f s against %.2f s)" % [fall[1], fall[0]], fall[1] < fall[0] / 3.0 and fall[1] > 0.2)

## Whether the dropper, left alone, moves on its glide.
func _glides(s) -> bool:
	var x0: float = s.drop_x
	_run(s, 0.5)
	return absf(s.drop_x - x0) > 5.0

## Lets a clay marble go at `x` straight from the jar.
static func _let(s, x: float) -> void:
	s.drop_x = x
	s._release(false)

## Runs the sim `secs` on, a frame at a time (a step clamps at 0.25 s).
static func _run(s, secs: float) -> void:
	var t := 0.0
	while t < secs:
		s.step(1.0 / 60.0)
		t += 1.0 / 60.0

func _spread(seed_v: int) -> void:
	for at: Array in [["middle", 500.0, true], ["aimed left", 0.0, true], ["wall", 0.0, false]]:
		var s = Sim.new(seed_v + 3)
		s.owned[0] = 1000
		s.jar[0] = 1000
		var tally := PackedInt32Array()
		tally.resize(Sim.CUPS)
		var x := clampf(float(at[1]), Sim.W * Sim.AIM_LO, Sim.W * Sim.AIM_HI) if bool(at[2]) else clampf(float(at[1]), Sim.BALL_R, Sim.W - Sim.BALL_R)
		for i in 1000:
			_let(s, x)
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
	_check("value level 1 costs 2", is_equal_approx(s.price("value"), 2.0))
	_check("buy value", s.buy("value") == 1 and is_equal_approx(s.coins, 98.0) and is_equal_approx(s.value(), 2.0))
	_check("ball count level 1 costs 10, gives 2", is_equal_approx(s.price("marbles"), 10.0) and s.buy("marbles") == 1 and s.owned[0] == 2 and s.jar[0] == 2)
	s.coins = 1e13
	s.buy("auto", 0)
	_check("max buy stops at level 10 before the eighth investment (%d)" % int(s.up.auto), int(s.up.auto) == Sim.BASE_TOP and s.up_waits("auto"))
	_check("auto at level 10 is 0.12 s", is_equal_approx(s.auto_every(), 0.12))
	s.buy("marbles", 0)
	_check("ball count 300 at level 10", s.owned_all() == 300)
	s.auto_off = true
	s.jar[0] = 25
	s.owned[0] = 25
	_check("merge all makes two glass", s.merge_all() == 2 and s.owned[1] == 2 and s.jar[0] == 5)
	_check("best tier noted", s.best_tier == 1)
	s.drop(500.0)
	_run(s, 0.5)
	_check("drop takes the best first", s.balls.size() == 1 and int(s.balls[0].tier) == 1)
	_check("a glass marble is worth ten", is_equal_approx(s.tier_worth(1), 10.0))
	# cups: base + 0.2 a level, xp from Ball xp
	s.cup_lv[0] = 118
	s.cup_lv[2] = 217
	_check("cup multipliers read as the reference's (25.1, 44.2)", is_equal_approx(s.cup_mult(0), 25.1) and is_equal_approx(s.cup_mult(2), 44.2))
	# SP: sqrt(earned / 2e4)
	s.coins = 4.9e9
	_check("4.9B coins is 22 SP (sqrt of 490)", s.sp_for() == 22)
	_check("the next SP at 23² × 1e7", is_equal_approx(s.next_sp_at(), 23.0 * 23.0 * Sim.SP_DIV))
	s.coins = 4.9e12
	_check("cash out pays 700", s.cash_out() == 700 and is_equal_approx(s.sp, 700.0))
	_check("a cash out resets the run", s.coins == 0.0 and int(s.up.value) == 0 and s.owned_all() == 1 and s.balls.is_empty() and s.cup_lv[0] == 0)
	_check("the shop: more balls 5 for 1 SP", s.shop_buy("balls") and s.owned_all() == 6 and is_equal_approx(s.sp, 699.0))
	for k in 7:
		s.shop_buy("balls")
	_check("more balls has no top and stays 1 SP: eight bought, +40", int(s.shop.balls) == 8 and s.owned_all() == 41 and is_equal_approx(s.sp, 692.0) and s.can_shop("balls"))
	var rises := true
	for lv in 300:
		rises = rises and Sim.need(lv + 1) > Sim.need(lv)
	_check("a cup's xp to its next level rises every level", rises and Sim.need(0) == 5.0)
	_check("mega balls value shut until investment 7", not s.can_shop("mega"))
	s.shop_buy("bonus")
	_check("shop bonus 1.5x on SP", is_equal_approx(s.sp_mult(), 1.5))
	# investments
	s.sp = 29.0
	_check("investment 1 needs 30", not s.invest())
	s.sp = 45.0
	_check("investment 1: the gold peg, the SP and shop spent", s.invest() and s.invested == 1 and s.sp == 0.0 and int(s.shop.balls) == 0 and s.owned_all() == 1 and s.bonus.values() == ["plus"])
	var from: int = s.bonus.keys()[0]
	var to := Sim.pin_id(8, 6)
	_check("a peg moves", s.move_bonus(from, to) and s.bonus.has(to) and not s.bonus.has(from))
	_check("onto itself it does not", not s.move_bonus(to, to))
	s.sp = 60.0
	_check("investment 2: the rose peg too", s.invest() and s.bonus.size() == 2 and s.bonus.has(to))
	var b := {"tier": 0, "add": 10.0, "mul": 2.0}
	_check("a marble through both pegs pays (1 + 10) x 2", is_equal_approx(s.ball_worth(b), 22.0))
	for i in 8:
		s.sp = 1e6
		s.invest()
	_check("ten investments made, four pegs", s.invested == 10 and s.bonus.size() == 4 and s.has_invest("mega_up"))
	s.coins = 1e13
	s.buy("value", 0)
	s.buy("marbles", 0)
	_check("the eighth opens levels to 14 (value 500K)", int(s.up.value) == 14 and is_equal_approx(s.value(), 5e5))
	s.sp = 0.0
	s.coins = Sim.SP_DIV * 100.0 * 100.0
	var before: float = s.sp
	_run(s, 1.0)
	_check("auto cash out: a tenth of a cash out a second (%.0f)" % (s.sp - before), s.sp - before >= 0.09 * s.sp_for() and s.sp - before <= 0.11 * s.sp_for() + 1.0)
	_check("the fourth investment doubles the marbles (level 14: 5600)", s.count_target() == 5600 and s.owned_all() == 5600)
	# ascend
	_check("ascend", s.ascend() and s.ascend_pts == 1 and s.invested == 0 and s.bonus.is_empty() and s.sp == 0.0)
	_check("raise coin value x10", s.raise("coin") and is_equal_approx(s.coin_mult(), 10.0) and not s.raise("coin"))
	s.ascend_pts = 4
	s.raise("speed")
	_check("drop speed -92%", is_equal_approx(s.auto_every(), 3.5 * 0.08))
	s.raise("balls")
	_check("ascend balls +2000", s.owned_all() == 2001)
	s.raise("prestige")
	_check("prestige x16 SP", is_equal_approx(s.sp_mult(), 16.0))
	_check("short 999", Sim.short(999.0) == "999")
	_check("short 12.4K", Sim.short(12400.0) == "12.4K")
	_check("short 3.1M", Sim.short(3100000.0) == "3.1M")
	_check("short 250B", Sim.short(2.5e11) == "250B")
	_check("short 1.2e40", Sim.short(1.2e40) == "1.2e40")
	_check("short 1Qa", Sim.short(1e15) == "1Qa")

func _kept(seed_v: int) -> void:
	var s = Sim.new(seed_v)
	s.sp = 400.0
	s.invest()
	s.coins = 1234.5
	s.up.value = 3
	s.sp = 7.0
	s.sp_ever = 9.0
	s.shop.xp = 2
	s.owned[0] = 4
	s.owned[2] = 1
	s.cup_lv[3] = 12
	s.cup_xp[3] = 3.5
	s.best_tier = 2
	s.ascend_pts = 1
	s.asc.coin = 2
	s.auto_off = true
	s.drop(500.0)
	_run(s, 0.5)
	s.save()
	var l = Sim.load_saved()
	_check("kept coins", is_equal_approx(l.coins, 1234.5))
	_check("kept upgrades", int(l.up.value) == 3)
	_check("kept SP, shop and investment", is_equal_approx(l.sp, 7.0) and int(l.shop.xp) == 2 and l.invested == 1 and l.bonus.size() == 1)
	_check("kept ascend", l.ascend_pts == 1 and int(l.asc.coin) == 2)
	_check("marbles in the air come back to the jar", l.jar[2] == 1 and l.jar[0] == 4)
	_check("kept cups", l.cup_lv[3] == 12 and is_equal_approx(l.cup_xp[3], 3.5))
	var k := Sim.kept()
	_check("the card reads it", not k.new and int(k.sp) == 9 and int(k.tier) == 2)
	# a file from before the sheet starts again
	var cfg := ConfigFile.new()
	cfg.load(Sim.path)
	cfg.set_value("board", "ver", 1)
	cfg.save(Sim.path)
	var old = Sim.load_saved()
	_check("a VER 1 file starts a new board", old.coins == 0.0 and old.invested == 0 and Sim.kept().new)

func _pace(seed_v: int, minutes: float) -> void:
	var s = Sim.new(seed_v)
	var t := 0.0
	var tap := 0.0
	var next_print := 300.0
	var dt := 1.0 / 30.0
	var buys := {}
	_bank = 0.0
	while t < minutes * 60.0:
		s.step(dt)
		t += dt
		for ev: Dictionary in s.events:
			match String(ev.type):
				"upgrade":
					var id := String(ev.id)
					if not buys.has(id):
						buys[id] = []
					for _n in int(ev.n):
						(buys[id] as Array).append(t)
				"cashout":
					if not buys.has("cashout"):
						buys["cashout"] = []
					(buys["cashout"] as Array).append(t)
				"invest":
					print("  INVEST #%d %s at %.1f min (cups %s, outs %d)" % [int(ev.n), String(ev.id), t / 60.0, str(s.cup_lv), s.cashouts])
				"ascend":
					print("  ASCEND %d at %.1f min" % [int(ev.n), t / 60.0])
		s.events.clear()
		tap += dt
		if tap >= 0.25:
			tap = 0.0
			if s.in_jar() > 0:
				s.drop(0.0)
			_bot_buy(s)
		if t >= next_print:
			next_print += 300.0
			print("  %4.0f min  earned %s  SP %s (ever %s, outs %d, inv %d, asc %d)  up %s  jar %s  cups %s  best %d" % [t / 60.0, Sim.short(s.earned), Sim.short(s.sp), Sim.short(s.sp_ever), s.cashouts, s.invested, s.ascends, str(s.up.values()), Sim.short(float(s.owned_all())), str(s.cup_lv), s.best_tier])
	_gaps(buys)

## SP the bot has put into the shop since its last investment, and holds.
var _bank := 0.0
## The bot's sense of its coins a second.
var _rate := 0.0
var _last_earned := 0.0
## The pace of the buys: when each rank of each upgrade was bought, and the
## gaps between them. A gap that keeps growing is the price curve outrunning
## the income: the game stalls.
func _gaps(buys: Dictionary) -> void:
	var outs: Array = buys.get("cashout", [])
	for id: String in buys:
		var ts: Array = buys[id]
		if id == "cashout":
			var line := "  cashouts x%d:" % ts.size()
			for v in ts:
				line += " %.0f" % float(v)
			print(line)
			continue
		# the first run only: a cash out starts the prices over, and the
		# burst of cheap ranks after it would hide the curve
		var end := float(outs[0]) if not outs.is_empty() else INF
		var line := "  %s x%d (first run):" % [id, ts.size()]
		var prev := 0.0
		var gaps := PackedFloat32Array()
		for i in ts.size():
			if float(ts[i]) > end:
				break
			var g := float(ts[i]) - prev
			gaps.append(g)
			prev = float(ts[i])
			if i < 24:
				line += " %.0f" % float(ts[i])
		print(line + (" ..." if gaps.size() > 24 else ""))
		# the verdict skips the first three ranks (cheap, bought in seconds)
		# and reads the rest: a second half slower than FLAT_RATIO times
		# the first is a price curve outrunning the income. Value is +1 a
		# rank against x1.6 a price and meant to fall behind: noted, not
		# flagged.
		var late := gaps.slice(mini(3, gaps.size()))
		if late.size() >= 4:
			var head := _mean(late.slice(0, late.size() / 2))
			var tail := _mean(late.slice(late.size() / 2))
			var worst := 0.0
			for g in late:
				worst = maxf(worst, g)
			var ratio := tail / maxf(head, 0.01)
			var verdict := "ok  " if ratio <= FLAT_RATIO else ("note" if id == "value" else "FLAG")
			print("    %s gaps from the 4th buy: first half %.0fs  second half %.0fs  longest %.0fs  (ratio %.2f)" % [verdict, head, tail, worst, ratio])
		elif gaps.size() >= 2:
			var all_head := _mean(gaps.slice(0, gaps.size() / 2))
			var all_tail := _mean(gaps.slice(gaps.size() / 2))
			print("    gaps: first half %.0fs  second half %.0fs  (too few past the 3rd buy to judge)" % [all_head, all_tail])

static func _mean(a: PackedFloat32Array) -> float:
	if a.is_empty():
		return 0.0
	var s := 0.0
	for v in a:
		s += v
	return s / a.size()

func _bot_buy(s) -> void:
	# merge while the jar keeps more than the air holds
	for k in Sim.TIERS - 1:
		while s.jar[k] >= Sim.MERGE and s.in_jar() - Sim.MERGE + 1 > Sim.MAX_AIR:
			s.merge(k)
	# the cheapest upgrade the coins cover, while it is no more than a
	# minute's coins: past that the bot saves for the cash out
	var best := ""
	var bp := INF
	for id: String in Sim.UPS:
		if not s.can_buy(id):
			continue
		var p: float = s.price(id)
		if p < bp:
			bp = p
			best = id
	_rate = lerpf(_rate, maxf(0.0, s.earned - _last_earned) * 4.0, 0.05)
	_last_earned = s.earned
	if best != "" and bp <= maxf(_rate * 60.0, 50.0):
		s.buy(best)
	if s.can_ascend():
		s.ascend()
		_bank = 0.0
		for id: String in Sim.ASCEND:
			if s.can_raise(id):
				s.raise(id)
				break
		return
	if s.can_invest():
		s.invest()
		_bank = 0.0
		return
	var could: int = s.sp_for()
	if not _no_cash and could >= maxi(3, int(_bank * 0.5)):
		s.cash_out()
		_bank += could
		var bought := true
		while bought:
			bought = false
			var cheap := ""
			var cp := INF
			for id: String in Sim.SHOP:
				if s.can_shop(id) and s.shop_price(id) < cp:
					cp = s.shop_price(id)
					cheap = id
			# hold back for the next investment when it is near
			if cheap != "" and s.sp - cp >= 0.0 and (s.invest_price() <= 0.0 or s.sp < s.invest_price() * 0.5):
				s.shop_buy(cheap)
				bought = true
