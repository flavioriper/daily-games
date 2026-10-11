extends SceneTree

## Proves Furrow's field headless and plays it with two bots. Run after
## touching arcade/furrow_sim.gd.
##   godot --headless --script tests/_probe_furrow.gd -- [pace]
## The field's promises: nothing ripens early, what is ripe waits and is
## never lost, a chain pays more a link up to the open plots and no further,
## the whole field in one chain is a clean sweep paid once, time away grows
## the field in one go and banks nothing, and a field saved comes back as it
## was. With `pace`, two bots climb to the last crop and the whole field: one
## that stays and picks all day (hours of play), one that looks in every 45
## minutes of a 16-hour day (days). The game is meant to take days.

const Sim = preload("res://arcade/furrow_sim.gd")

var _fails := 0

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	Sim.path = "user://_probe_furrow.cfg"
	_rules()
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

func _ripen(s: RefCounted) -> void:
	for p: Dictionary in s.plots:
		if p.open:
			p.t = s.grow_time(p.crop)
			p.ripe = true
			p.gold = false

func _rules() -> void:
	var s = Sim.new(7)
	_check("a new field has %d plots open and one crop" % Sim.START, s.opened() == Sim.START and s.crops == 1)
	var first: int = s.order[0]
	_check("an unripe plot is not picked", not s.pick(first) and s.seeds == 0)
	s.step(Sim.CROPS[0].grow - 0.5)
	_check("nothing ripens early", s.ripe_count() == 0)
	s.step(1.0)
	_check("the open plots ripen together", s.ripe_count() == Sim.START)
	s.step(100000.0)
	_check("what is ripe waits", s.ripe_count() == Sim.START)
	_ripen(s)
	s.events.clear()
	var pays := []
	for i: int in s.order:
		if s.pick(i):
			pays.append(int(s.events[-1].pay))
	_check("four radishes at 5%% a link pay 1, 1, 1, 1 (%s)" % str(pays), pays == [1, 1, 1, 1])
	_check("the chain is four links", s.chain == 4)
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
	_ripen(f)
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
	_check("a crop not held is not sown", not g.sow(a, 2))
	_check("the same crop is not sown again", not g.sow(a, 0))
	_ripen(g)
	_ripen(g)
	g.events.clear()
	_check("the packet of the crop a ripe bed grows picks it and sows nothing", g.sow(a, 0) and g.seeds == 1 and not g.plots[a].ripe and g.events.size() == 1 and g.events[0].type == "pick")
	g.seeds = 0
	g.step(Sim.WINDOW + 0.1)
	_ripen(g)
	g.events.clear()
	_check("sowing a ripe plot picks it first", g.sow(a, 1) and g.seeds == 1 and int(g.plots[a].crop) == 1 and not g.plots[a].ripe)
	# buying
	g.seeds = 0
	_check("a plot is not opened on credit", g.buy_plot() == -1)
	g.seeds = g.plot_price()
	var was: int = g.plot_price()
	var nxt: int = g.next_plot()
	_check("the next plot opens for its price", g.buy_plot(1) == nxt and g.seeds == 0 and g.plots[nxt].open and int(g.plots[nxt].crop) == 1)
	_check("and the one after is dearer", g.plot_price() > was)
	g.seeds = 10
	_check("a packet is not had on credit", not g.buy_crop())
	g.seeds = g.crop_price()
	_check("the next packet is", g.buy_crop() and g.crops == 3 and g.seeds == 0)
	var t0: float = g.grow_time(1)
	var w0: int = g.worth(2)
	var c0: float = g.chain_step()
	g.seeds = 100000
	for id: String in Sim.UPS:
		g.buy_up(id)
	_check("compost grows faster, a basket pays more, the knack links dearer", g.grow_time(1) < t0 and g.worth(2) > w0 and g.chain_step() > c0)
	# gold
	var gold = Sim.new(11)
	var n := 0
	for k in 4000:
		_ripen_one(gold)
		if gold.plots[gold.order[0]].gold:
			n += 1
		gold.pick(gold.order[0])
	_check("about one ripening in twenty-five is golden (%d of 4000)" % n, n > 100 and n < 230)

func _ripen_one(s: RefCounted) -> void:
	var p: Dictionary = s.plots[s.order[0]]
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
	s.step(4.0)
	s.save()
	var b = Sim.load_saved(5)
	_check("a saved field comes back", b.seeds == 321 and b.crops == 3 and int(b.lv.compost) == 2 and int(b.plots[b.order[0]].crop) == 2 and b.opened() == Sim.START)
	_check("no time away, nothing ripened", b.away_ripe == 0 and b.away_secs < 2.0)
	var n: int = b.away(3600.0 * 24.0)
	_check("a day away ripens every open plot and banks nothing", n == Sim.START and b.seeds == 321 and b.ripe_count() == Sim.START)
	_check("a second day adds nothing", b.away(3600.0 * 24.0) == 0)
	_check("the card reads the kept field", int(Sim.kept().plots) == Sim.START and int(Sim.kept().crops) == 3)

# --- the pace ---

## Spends as a player would: the next packet, then the next plot, then the
## cheapest upgrade while it is under a third of what is held.
func _spend(s: RefCounted) -> void:
	var more := true
	while more:
		more = false
		if s.crop_price() >= 0 and s.seeds >= s.crop_price():
			more = s.buy_crop()
		elif s.next_plot() >= 0 and s.seeds >= s.plot_price() and (s.crop_price() < 0 or s.plot_price() < s.crop_price() * 0.5):
			more = s.buy_plot() >= 0
		else:
			var best := ""
			for id: String in Sim.UPS:
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

func _pick_all(s: RefCounted) -> void:
	for i in s.plots.size():
		s.pick(i)
	s.step(Sim.WINDOW + 0.1)
	s.events.clear()

func _done(s: RefCounted) -> bool:
	return s.crops >= Sim.CROPS.size() and s.next_plot() < 0

## Stays and plays: every plot on the best crop that ripens in two minutes,
## the field picked in one stroke whenever it is all ripe. Hours of play.
func _stay() -> float:
	var s = Sim.new(3)
	var t := 0.0
	var said := 1
	while not _done(s) and t < 3600.0 * 400.0:
		s.step(1.0)
		t += 1.0
		if s.ripe_count() == s.opened():
			_pick_all(s)
			_spend(s)
			var c := _crop_for(s, 120.0)
			for i in s.plots.size():
				s.sow(i, c)
			s.events.clear()
		if s.crops > said:
			said = s.crops
			print("  stays: %-9s at %6.1f h, %2d plots, levels %s" % [Sim.CROPS[said - 1].id, t / 3600.0, s.opened(), str(s.lv)])
	print("stays: the last crop and the whole field after %.1f hours of play" % (t / 3600.0))
	return t / 3600.0

## Looks in every 45 minutes of a 16-hour day and sleeps eight: picks the
## field in one stroke, spends, and sows what will be ripe by the next look.
func _look_in() -> float:
	var s = Sim.new(3)
	var t := 0.0
	var said := 1
	var look := 0
	while not _done(s) and t < 86400.0 * 200.0:
		var gap := 2700.0 if look % 22 != 21 else 8.0 * 3600.0
		# five minutes at the field each time, on quick crops
		var c := _crop_for(s, 60.0)
		for i in s.plots.size():
			s.sow(i, c)
		var here := 0.0
		while here < 300.0:
			s.step(1.0)
			here += 1.0
			if s.ripe_count() == s.opened():
				_pick_all(s)
				_spend(s)
				for i in s.plots.size():
					s.sow(i, _crop_for(s, 60.0))
		c = _crop_for(s, gap)
		for i in s.plots.size():
			s.sow(i, c)
		s.events.clear()
		s.away(gap)
		_pick_all(s)
		_spend(s)
		t += gap + 300.0
		look += 1
		if s.crops > said:
			said = s.crops
			print("  looks in: %-9s on day %5.1f, %2d plots, levels %s" % [Sim.CROPS[said - 1].id, t / 86400.0, s.opened(), str(s.lv)])
	print("looks in: the last crop and the whole field after %.1f days" % (t / 86400.0))
	return t / 86400.0
