extends SceneTree

## Proves Furrow's field headless and plays it with two bots. Run after
## touching arcade/furrow_sim.gd.
##   godot --headless --script tests/_probe_furrow.gd -- [pace]
## The field's promises: nothing ripens early, what is ripe keeps for its
## time and then dies, a picked plot is bare until it is sown, a chain pays
## more a link up to the open plots and no further, the whole field in one
## chain is a clean sweep paid once, time away grows the field in one go and
## banks nothing, and a field saved comes back as it was. The animals': hens
## lay to the ground's room and no further, a cow gives nothing until she is
## full and nothing by herself, eggs and milk are links, a milestone pays
## once, a rooster's chicks grow into hens, and a fox takes a hen only with
## the fence down, never the last and never one it was shooed from. With `pace`, two bots climb to the last crop and the whole field: one
## that stays and picks all day (hours of play), one that looks in every 45
## minutes of a 16-hour day (days). The game is meant to take days.

const Sim = preload("res://arcade/furrow_sim.gd")

var _fails := 0

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	Sim.path = "user://_probe_furrow.cfg"
	_rules()
	_animals()
	_kept()
	if args.size() > 0 and args[0] == "pace":
		var stay := _stay()
		var look := _look_in()
		_check("the bot that stays needs 6 hours or more of play for the last crop (%.1f)" % stay, stay >= 6.0)
		_check("the bot that looks in takes 5 to 30 days for the last crop (%.1f)" % look, look >= 5.0 and look <= 30.0)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Sim.path))
	print("%d failed" % _fails)
	quit(1 if _fails > 0 else 0)

func _check(what: String, ok: bool) -> void:
	print("%s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_fails += 1

## Every open plot ripe this moment, sown with `crop` where it was bare.
func _ripen(s: RefCounted, crop := 0) -> void:
	for p: Dictionary in s.plots:
		if p.open:
			if int(p.crop) == Sim.BARE:
				p.crop = crop
			p.t = s.grow_time(p.crop)
			p.ripe = true
			p.gold = false
			p.age = 0.0
			p.dead = false

func _rules() -> void:
	var s = Sim.new(7)
	_check("a new field has %d plots open and one crop" % Sim.START, s.opened() == Sim.START and s.crops == 1)
	var first: int = s.order[0]
	_check("an unripe plot is not picked", not s.pick(first) and s.seeds == 0)
	s.step(Sim.CROPS[0].grow - 0.5)
	_check("nothing ripens early", s.ripe_count() == 0)
	s.step(1.0)
	_check("the open plots ripen together", s.ripe_count() == Sim.START)
	s.step(s.keep_time(0) - 2.0)
	_check("what is ripe keeps for its time", s.ripe_count() == Sim.START and s.fresh(first) < 0.05)
	s.events.clear()
	s.step(3.0)
	_check("and then it dies", s.ripe_count() == 0 and s.dead_count() == Sim.START and s.events.filter(func(ev: Dictionary) -> bool: return ev.type == "dead").size() == Sim.START)
	_check("a dead crop is not picked and pays nothing", not s.pick(first) and s.seeds == 0)
	_check("it is cleared, and the plot is bare", s.clear(first) and s.stage(first) == Sim.BARE and s.seeds == 0 and s.chain == 0)
	s.step(100000.0)
	_check("nothing grows on a bare plot", s.stage(first) == Sim.BARE and s.bare_count() == 1)
	_check("a slow crop keeps %d times its growing, a quick one %d s" % [int(Sim.KEEP_TIMES), int(Sim.KEEP_MIN)], is_equal_approx(s.keep_time(7), 28800.0 * Sim.KEEP_TIMES) and is_equal_approx(s.keep_time(0), Sim.KEEP_MIN))
	_ripen(s)
	s.events.clear()
	var pays := []
	for i: int in s.order:
		if s.pick(i):
			pays.append(int(s.events[-1].pay))
	_check("four radishes at 5%% a link pay 1, 1, 1, 1 (%s)" % str(pays), pays == [1, 1, 1, 1])
	_check("the chain is four links", s.chain == 4)
	_check("a picked plot is bare", s.bare_count() == Sim.START and s.stage(first) == Sim.BARE)
	s.step(Sim.WINDOW + 0.1)
	_check("the chain ends when its window does, and is the best", s.chain == 0 and s.best_chain == 4)
	# a whole field of tomatoes in one stroke
	var f = Sim.new(7)
	for p: Dictionary in f.plots:
		p.open = true
		p.crop = 3
	f.crops = 4
	_ripen(f)
	f.events.clear()
	var total := 0
	for i in f.plots.size():
		f.pick(i)
	for ev: Dictionary in f.events:
		if ev.type == "pick":
			total += int(ev.pay)
	var flat: int = f.worth(3) * f.plots.size()
	_check("twenty in a chain pay more than twenty alone (%d > %d)" % [total, flat], total > flat * 1.4)
	var bunches: Array = f.events.filter(func(ev: Dictionary) -> bool: return ev.type == "bunch")
	_check("a chain of twenty has four bunches", bunches.size() == 4 and int(bunches[3].tier) == 3)
	var sweeps: Array = f.events.filter(func(ev: Dictionary) -> bool: return ev.type == "sweep")
	_check("the whole field in one chain is one clean sweep", sweeps.size() == 1 and int(sweeps[0].bonus) == int(round(total * Sim.SWEEP)))
	_check("the seeds are the picks and the sweep", f.seeds == total + int(sweeps[0].bonus))
	# a chain kept going past the field stays at its top and sweeps once
	_ripen(f, 3)
	f.events.clear()
	f.pick(0)
	_check("past the field a link pays the field's top", int(f.events[0].pay) == int(round(f.worth(3) * f.times(20))) and f.times(21) == f.times(20))
	for i in range(1, f.plots.size()):
		f.pick(i)
	_check("and the sweep is not paid twice", f.events.filter(func(ev: Dictionary) -> bool: return ev.type == "sweep").is_empty())
	# sowing
	var g = Sim.new(7)
	g.crops = 2
	var a: int = g.order[0]
	_check("nothing is sown over what grows", not g.sow(a, 1) and int(g.plots[a].crop) == 0)
	_ripen(g)
	_check("nor over what is ripe", not g.sow(a, 1) and g.plots[a].ripe)
	g.pick(a)
	_check("a crop not held is not sown", not g.sow(a, 2))
	g.events.clear()
	_check("a bare plot is sown with the packet in hand", g.sow(a, 1) and int(g.plots[a].crop) == 1 and g.events.size() == 1 and g.events[0].type == "sow")
	_check("a growing crop is dug up, and the plot is bare", g.dig(a) and g.stage(a) == Sim.BARE and not g.dig(a))
	g.step(Sim.WINDOW + 0.1)
	g.seeds = 0
	# buying
	g.seeds = 0
	_check("a plot is not opened on credit", g.buy_plot() == -1)
	g.seeds = g.plot_price()
	var was: int = g.plot_price()
	var nxt: int = g.next_plot()
	_check("the next plot opens bare for its price", g.buy_plot() == nxt and g.seeds == 0 and g.plots[nxt].open and g.stage(nxt) == Sim.BARE)
	_check("and the one after is dearer", g.plot_price() > was)
	g.seeds = 10
	_check("a packet is not had on credit", not g.buy_crop())
	g.seeds = g.crop_price()
	_check("the next packet is", g.buy_crop() and g.crops == 3 and g.seeds == 0)
	var t0: float = g.grow_time(1)
	var w0: int = g.worth(2)
	var c0: float = g.chain_step()
	var k0: float = g.keep_time(4)
	g.seeds = 100000
	for id: String in Sim.UPS:
		g.buy_up(id)
	_check("compost grows faster, a basket pays more, the knack links dearer, mulch keeps longer", g.grow_time(1) < t0 and g.worth(2) > w0 and g.chain_step() > c0 and g.keep_time(4) > k0)
	# gold
	var gold = Sim.new(11)
	var n := 0
	for k in 4000:
		_ripen_one(gold)
		if gold.plots[gold.order[0]].gold:
			n += 1
		gold.pick(gold.order[0])
	_check("about one ripening in twenty-five is golden (%d of 4000)" % n, n > 100 and n < 230)

func _count(s: RefCounted, type: String) -> int:
	return s.events.filter(func(ev: Dictionary) -> bool: return ev.type == type).size()

func _animals() -> void:
	var s = Sim.new(9)
	_check("no coop, no eggs", not s.gather() and s.price("hen") == -1 and s.price("fence") == -1 and s.price("rooster") == -1)
	_check("the coop is not built on credit", not s.buy("coop"))
	s.seeds = Sim.COOP_PRICE
	_check("the coop comes with %d hens and a fence down" % Sim.HENS_START, s.buy("coop") and s.seeds == 0 and s.hens == Sim.HENS_START and s.fence_t == 0.0 and s.price("coop") == -1)
	s.events.clear()
	s.step(Sim.LAY / Sim.HENS_START - 1.0)
	_check("no egg early", s.eggs == 0)
	s.step(1.5)
	_check("two hens lay an egg every %d s" % int(Sim.LAY / 2.0), s.eggs == 1 and _count(s, "egg") == 1)
	for k in 200:
		s.step(5.0)
		if s.fox > 0.0:
			s.shoo()
	_check("eggs lie to the ground's room and no further (%d)" % s.eggs, s.eggs == s.nest_room() and s.eggs == Sim.HENS_START * Sim.NEST)
	s.events.clear()
	var held: int = s.seeds
	_check("an egg gathered is a link and pays", s.gather() and s.eggs == Sim.HENS_START * Sim.NEST - 1 and s.seeds == held + s.egg_worth() and s.chain == 1)
	while s.gather():
		pass
	_check("the ground is bare and the chain %d links" % s.chain, s.eggs == 0 and s.chain == Sim.HENS_START * Sim.NEST)
	s.step(Sim.WINDOW + 0.1)
	# milestones
	var w0: int = s.egg_worth()
	s.eggs_got = Sim.EGG_MILES[0] - 1
	s.eggs = 2
	s.seeds = 0
	s.events.clear()
	s.gather()
	var mile: Array = s.events.filter(func(ev: Dictionary) -> bool: return ev.type == "mile")
	_check("the %dth egg is a milestone: %d seeds at once" % [Sim.EGG_MILES[0], Sim.EGG_PRIZES[0]], mile.size() == 1 and int(mile[0].prize) == Sim.EGG_PRIZES[0] and s.seeds >= Sim.EGG_PRIZES[0] and s.miles("egg") == 1)
	s.events.clear()
	s.gather()
	_check("paid once", _count(s, "mile") == 0)
	s.eggs_got = Sim.EGG_MILES[2]
	_check("every milestone reached makes an egg worth more (%d > %d)" % [s.egg_worth(), w0], s.egg_worth() > w0 and s.next_mile("egg") == Sim.EGG_MILES[3])
	s.step(Sim.WINDOW + 0.1)
	# the fox
	var f = Sim.new(9)
	f.seeds = 100000
	f.buy("coop")
	f.buy("hen")
	f.events.clear()
	var took := 0
	var came := 0
	for k in 2000:
		f.step(5.0)
		came += _count(f, "fox")
		took += _count(f, "took")
		f.events.clear()
	_check("with the fence down a fox comes and takes hens, never the last (%d came, %d taken, %d left)" % [came, took, f.hens], came >= 2 and took == 2 and f.hens == 1 and f.hens_lost == 2)
	f.hens = 4
	f.fox_t = 1.0
	f.step(2.0)
	_check("a fox on its way", f.fox > 0.0)
	_check("shooed, it takes nothing", f.shoo() and f.fox == 0.0 and not f.shoo())
	f.step(Sim.FOX_TIME + 1.0)
	_check("and the hens are all there", f.hens == 4)
	_check("the fence is mended for its price", f.price("fence") == Sim.FENCE_FIRST + Sim.FENCE_A_HEN * 4 and f.buy("fence") and f.price("fence") == -1)
	f.events.clear()
	for k in 1000:
		f.step(60.0)
	_check("mended, no fox comes while it holds", f.hens == 4 and _count(f, "fox") == 0 and f.fence_t > 0.0)
	f.step(Sim.FENCE_HOLDS)
	_check("it comes down in the end", f.fence_t == 0.0 and _count(f, "fence_down") == 1 and f.price("fence") > 0)
	var a = Sim.new(9)
	a.seeds = 100000
	a.buy("coop")
	for k in 4:
		a.buy("hen")
	a.away(86400.0 * 3.0)
	_check("days away with the fence down cost %d hens at most" % Sim.FOX_AWAY, a.hens == 6 - Sim.FOX_AWAY and a.away_lost == Sim.FOX_AWAY and a.eggs == a.nest_room())
	a.hens = 1
	a.away(86400.0)
	_check("and never the last", a.hens == 1 and a.away_lost == 0)
	# the rooster
	var r = Sim.new(9)
	r.seeds = 1000000
	r.buy("coop")
	r.buy("fence")
	_check("hens are bought to the coop's room, each dearer", r.price("hen") == Sim.HEN_FIRST and r.buy("hen") and r.price("hen") > Sim.HEN_FIRST)
	r.buy("rooster")
	r.events.clear()
	var chicks := 0
	var grown := 0
	for k in 3000:
		r.step(10.0)
		while r.gather():
			pass
		chicks += _count(r, "chick")
		grown += _count(r, "grown")
		r.events.clear()
	_check("a rooster's eggs hatch now and then, and the chicks grow into hens to the coop's room (%d chicks, %d hens)" % [chicks, r.hens],
		chicks == Sim.HENS_MAX - 3 and grown == chicks and r.hens == Sim.HENS_MAX and r.chicks.is_empty() and r.price("hen") == -1)
	# the cows
	var c = Sim.new(9)
	_check("no pasture, no cow", c.price("cow") == -1 and not c.milk(0))
	c.seeds = Sim.PASTURE_PRICE
	_check("the pasture comes with a cow", c.buy("pasture") and c.cows.size() == 1 and c.seeds == 0)
	c.step(Sim.MILK_TIME - 1.0)
	_check("a cow gives nothing until she is full", not c.cow_full(0) and not c.milk(0) and c.seeds == 0)
	c.events.clear()
	c.step(2.0)
	_check("full, she says so", c.cow_full(0) and _count(c, "full") == 1)
	c.step(100000.0)
	_check("and waits: nothing is milked by itself", c.seeds == 0 and c.milk_got == 0 and c.cow_full(0))
	_check("milked, she pays %d and fills again" % c.milk_worth(), c.milk(0) and c.seeds == Sim.MILK and c.chain == 1 and not c.cow_full(0) and c.milk_got == 1)
	c.seeds = 10000000
	var t0: float = c.milk_time()
	var w1: int = c.milk_worth()
	var l0: float = r.lay_time()
	r.eggs_got = 0
	var e0: int = r.egg_worth()
	for id: String in Sim.COW_UPS:
		c.buy_up(id)
	for id: String in Sim.COOP_UPS:
		r.buy_up(id)
	_check("care fills faster, a pail pays more, feed lays faster, a nest box pays more", c.milk_time() < t0 and c.milk_worth() > w1 and r.lay_time() < l0 and r.egg_worth() > e0)
	while c.buy("cow"):
		pass
	_check("cows are bought to the pasture's room", c.cows.size() == Sim.COWS_MAX and c.price("cow") == -1)
	# eggs and crops in one chain
	var m = Sim.new(9)
	for p: Dictionary in m.plots:
		p.open = true
	m.crops = 4
	_ripen(m, 3)
	m.coop = true
	m.hens = 2
	m.eggs = 6
	m.events.clear()
	while m.gather():
		pass
	for i in m.plots.size():
		m.pick(i)
	_check("eggs first, then the field: one chain of 26, and still a clean sweep", m.chain == 26 and _count(m, "sweep") == 1)
	_check("something is looked at once", m.see("hen") and not m.see("hen"))

func _ripen_one(s: RefCounted) -> void:
	var p: Dictionary = s.plots[s.order[0]]
	p.crop = 0
	p.t = 0.0
	p.ripe = false
	s.step(s.grow_time(p.crop) + 0.01)
	if s.chain > 0:
		s.step(Sim.WINDOW + 0.1)
	s.events.clear()

func _kept() -> void:
	var s = Sim.new(5)
	s.crops = 3
	s.seeds = 321
	s.lv.compost = 2
	s.plots[s.order[0]].crop = 2
	s.plots[s.order[1]].crop = Sim.BARE
	s.seeds = 100000
	s.buy("coop")
	s.buy("hen")
	s.buy("rooster")
	s.buy("fence")
	s.buy("pasture")
	s.buy("cow")
	s.buy_up("feed")
	s.seeds = 321
	s.eggs = 4
	s.eggs_got = 12
	s.milk_got = 3
	s.chicks = [20.0]
	s.cows = [10.0, 30.0]
	s.see("radish")
	s.step(4.0)
	s.events.clear()
	s.save()
	var b = Sim.load_saved(5)
	_check("a saved field comes back", b.seeds == 321 and b.crops == 3 and int(b.lv.compost) == 2 and int(b.plots[b.order[0]].crop) == 2 and b.opened() == Sim.START
		and b.stage(b.order[1]) == Sim.BARE)
	_check("and its animals", b.coop and b.hens == 3 and b.rooster and b.eggs == 4 and b.eggs_got == 12 and b.chicks.size() == 1 and b.fence_t > Sim.FENCE_HOLDS - 60.0
		and b.pasture and b.cows.size() == 2 and b.milk_got == 3 and int(b.lv.feed) == 1 and b.seen == ["radish"])
	_check("no time away, nothing ripened", b.away_ripe == 0 and b.away_secs < 2.0)
	# an hour away: the lettuce (90 s, keeps 270) and the radishes are dead, the bare plot is bare
	var n: int = b.away(3600.0)
	_check("an hour away kills what was ripe too long and banks nothing", n == 0 and b.away_dead == Sim.START - 1 and b.seeds == 321 and b.stage(b.order[1]) == Sim.BARE)
	_check("the hens laid to the ground's room, the cows filled, the fence held", b.eggs == b.nest_room() and b.away_milk == 2 and b.full_count() == 2 and b.away_lost == 0 and b.hens >= 3)
	# a melon sown before bed is ripe and waiting in the morning
	var m = Sim.new(5)
	m.crops = 8
	for p: Dictionary in m.plots:
		if p.open:
			p.crop = 7
			p.t = 0.0
	_check("eight hours away ripens a field of melons", m.away(8.0 * 3600.0) == Sim.START and m.away_dead == 0)
	_check("most of a day more and they still wait", m.away(23.0 * 3600.0) == 0 and m.ripe_count() == Sim.START)
	_check("two hours on and they are gone", m.away(2.0 * 3600.0) == 0 and m.dead_count() == Sim.START and m.away_dead == Sim.START)
	# a field kept by the build before withering
	var cfg := ConfigFile.new()
	cfg.set_value("field", "plots", [[true, 0, 10.0, true, false], [true, 1, 3.0, false, false]])
	cfg.set_value("field", "seeds", 9)
	cfg.set_value("field", "lv", {"compost": 1, "basket": 0, "knack": 0})
	cfg.set_value("field", "stamp", Time.get_unix_time_from_system() - 86400.0)
	cfg.save(Sim.path)
	var old = Sim.load_saved(5)
	_check("an older field loses nothing to its first return", old.seeds == 9 and old.plots[0].ripe and old.plots[1].ripe and old.dead_count() == 0 and int(old.lv.compost) == 1 and not old.coop)
	s.save()
	_check("the card reads the kept field", int(Sim.kept().plots) == Sim.START and int(Sim.kept().crops) == 3)

# --- the pace ---

## Spends as a player would: the fence when it is down, the next packet,
## then the next plot, a pen or an animal while it is a small part of the
## next packet, then the cheapest upgrade while it is under a tenth of it.
func _spend(s: RefCounted) -> void:
	var more := true
	while more:
		more = false
		var goal: float = s.crop_price() if s.crop_price() >= 0 else s.seeds * 2.0
		if s.price("fence") >= 0 and s.seeds >= s.price("fence"):
			more = s.buy("fence")
		elif s.crop_price() >= 0 and s.seeds >= s.crop_price():
			more = s.buy_crop()
		elif s.next_plot() >= 0 and s.seeds >= s.plot_price() and (s.crop_price() < 0 or s.plot_price() < s.crop_price() * 0.5):
			more = s.buy_plot() >= 0
		else:
			for what: String in ["coop", "pasture", "hen", "cow", "rooster"]:
				if not more and s.price(what) >= 0 and s.seeds >= s.price(what) and s.price(what) <= goal * 0.25:
					more = s.buy(what)
			if not more:
				var ups: Array = Sim.UPS.duplicate()
				if s.coop:
					ups.append_array(Sim.COOP_UPS)
				if s.pasture:
					ups.append_array(Sim.COW_UPS)
				var best := ""
				for id: String in ups:
					if best == "" or s.up_price(id) < s.up_price(best):
						best = id
				var cap: float = (s.crop_price() * 0.1) if s.crop_price() >= 0 else s.seeds * 0.5
				if s.seeds >= s.up_price(best) and s.up_price(best) <= cap:
					more = s.buy_up(best)
	s.events.clear()

## The best crop held that is ripe within `secs`.
func _crop_for(s: RefCounted, secs: float) -> int:
	var best := 0
	for c in s.crops:
		if s.grow_time(c) <= secs:
			best = c
	return best

## The best crop held that is ripe after `secs` away and has not died by
## then; -1 when none is, and the plots are better left bare.
func _crop_away(s: RefCounted, secs: float) -> int:
	var best := -1
	for c in s.crops:
		if s.grow_time(c) <= secs and secs < s.grow_time(c) + s.keep_time(c):
			best = c
	return best

func _sow_all(s: RefCounted, crop: int) -> void:
	if crop < 0:
		return
	for i in s.plots.size():
		s.sow(i, crop)

## One stroke: the eggs, the full cows, everything ripe; what died is cleared.
func _pick_all(s: RefCounted) -> void:
	while s.gather():
		pass
	for k in s.cows.size():
		s.milk(k)
	for i in s.plots.size():
		s.pick(i)
		s.clear(i)
	s.step(Sim.WINDOW + 0.1)
	s.events.clear()

func _done(s: RefCounted) -> bool:
	return s.crops >= Sim.CROPS.size() and s.next_plot() < 0

## Stays and plays: every plot on the best crop that ripens in two minutes,
## the field picked in one stroke whenever it is all ripe and sown again by
## hand, the fox shooed. Hours of play.
func _stay() -> float:
	var s = Sim.new(3)
	var t := 0.0
	var said := 1
	while not _done(s) and t < 3600.0 * 400.0:
		s.step(1.0)
		t += 1.0
		if s.fox > 0.0:
			s.shoo()
		if s.ripe_count() + s.bare_count() == s.opened():
			_pick_all(s)
			_spend(s)
			_sow_all(s, _crop_for(s, 120.0))
			s.events.clear()
		if s.crops > said:
			said = s.crops
			print("  stays: %-9s at %6.1f h, %2d plots, %d hens, %d cows, levels %s" % [Sim.CROPS[said - 1].id, t / 3600.0, s.opened(), s.hens, s.cows.size(), str(s.lv)])
	print("stays: the last crop and the whole field after %.1f hours of play (%d eggs, %d bottles, %d hens lost)" % [t / 3600.0, s.eggs_got, s.milk_got, s.hens_lost])
	return t / 3600.0

## Looks in every 45 minutes of a 16-hour day and sleeps eight: picks the
## field in one stroke, spends, and sows what will be ripe and not yet dead
## by the next look.
func _look_in() -> float:
	var s = Sim.new(3)
	var t := 0.0
	var said := 1
	var look := 0
	var died := 0
	while not _done(s) and t < 86400.0 * 200.0:
		var gap := 2700.0 if look % 22 != 21 else 8.0 * 3600.0
		# five minutes at the field each time, on quick crops
		_pick_all(s)
		_sow_all(s, _crop_for(s, 60.0))
		var here := 0.0
		while here < 300.0:
			s.step(1.0)
			here += 1.0
			if s.fox > 0.0:
				s.shoo()
			if s.ripe_count() + s.bare_count() == s.opened():
				_pick_all(s)
				_spend(s)
				_sow_all(s, _crop_for(s, 60.0))
		# what is in the ground now would be dead by the next look: dug up
		var c := _crop_away(s, gap)
		for i in s.plots.size():
			if c >= 0 and int(s.plots[i].crop) != c:
				s.dig(i)
		_sow_all(s, c)
		s.events.clear()
		s.away(gap)
		died += s.away_dead
		_pick_all(s)
		_spend(s)
		t += gap + 300.0
		look += 1
		if s.crops > said:
			said = s.crops
			print("  looks in: %-9s on day %5.1f, %2d plots, %d hens, %d cows, levels %s" % [Sim.CROPS[said - 1].id, t / 86400.0, s.opened(), s.hens, s.cows.size(), str(s.lv)])
	print("looks in: the last crop and the whole field after %.1f days (%d eggs, %d bottles, %d hens lost, %d crops dead)" % [t / 86400.0, s.eggs_got, s.milk_got, s.hens_lost, died])
	return t / 86400.0
