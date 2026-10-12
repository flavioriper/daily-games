extends SceneTree

## Proves Griddle's stand headless and plays it with two bots. Run after
## touching arcade/griddle_sim.gd.
##   godot --headless --script tests/_probe_griddle.gd -- [pace]
## The stand's promises: nothing ripens early and a ripe lot waits; a lot
## gives less as its soil wears and gets it back resting; tonic gives more
## and wears three times as fast; a full larder takes no more; a cow gives
## nothing unfed and nothing poorly; a toastie takes a loaf and a cheese;
## only a hand's sale is a link of the rush, each link pays more up to the
## cap, and a queue emptied by a rush is a clean counter paid once; every
## shortcut raises its own mood and nothing else's, a mood at the top costs
## what it says and settles, a favour calms it; coins never go below zero;
## time away fills the larder, sells nothing and moves no mood; and a stand
## saved comes back as it was. With `pace`, two bots play: one that only
## looks on (the stand must still earn), and one that goes round the four
## places serving by hand and buying (the climb to the stars, in hours).

const Sim = preload("res://arcade/griddle_sim.gd")

var _fails := 0

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	Sim.path = "user://_probe_griddle.cfg"
	_fields()
	_yard()
	_counter()
	_office()
	_kept()
	if args.size() > 0 and args[0] == "pace":
		_pace()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Sim.path))
	print("%d failed" % _fails)
	quit(1 if _fails > 0 else 0)

func _check(what: String, ok: bool) -> void:
	print("%s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_fails += 1

func _has(s: RefCounted, type: String) -> int:
	var n := 0
	for ev: Dictionary in s.events:
		if String(ev.type) == type:
			n += 1
	return n

## A stand with nobody coming and no crew at work: one place at a time.
func _quiet(seed_ := 7) -> RefCounted:
	var s = Sim.new(seed_)
	s.shut = true
	return s

func _fields() -> void:
	var s = _quiet()
	_check("a new stand has %d lots open, one cow, one grill, one till" % Sim.START_LOTS, s.opened() == Sim.START_LOTS and s.cows.size() == 1 and s.grills == 1 and s.tills == 1)
	s._step_fields(Sim.CROPS[Sim.CLOVER].grow - 0.5)
	_check("nothing ripens early", s.ripe_count() == 0)
	_check("an unripe lot is not cut", not s.harvest(1))
	s.cart_t = -1000.0
	s._step_fields(1.0)
	_check("clover ripens at its time and wheat not yet", s.lots[1].ripe and s.lots[2].ripe and not s.lots[0].ripe)
	s._step_fields(500.0)
	_check("a ripe lot waits", s.lots[1].ripe and s.lots[0].ripe)
	var had: int = s.feed
	var n: int = s.gives(1)
	_check("a lot on good soil gives its crop (%d)" % n, n == Sim.CROPS[Sim.CLOVER].gives)
	_check("a hand cuts a ripe lot", s.harvest(1) and s.feed == had + n and not s.lots[1].ripe)
	_check("a cut wears the soil by %d" % int(Sim.WEAR), is_equal_approx(s.lots[1].soil, Sim.SOIL_MAX - Sim.WEAR))
	s.lots[2].soil = 0.0
	_check("worn soil gives half (%d)" % s.gives(2), s.gives(2) == int(round(Sim.CROPS[Sim.CLOVER].gives * Sim.POOR)))
	s.lots[2].soil = Sim.SOIL_MAX
	s.lots[2].tonic = true
	_check("tonic gives half as much again (%d)" % s.gives(2), s.gives(2) == int(round(Sim.CROPS[Sim.CLOVER].gives * Sim.TONIC_GIVES)))
	s.feed = 0
	s.harvest(2)
	_check("and wears the soil three times as fast", is_equal_approx(s.lots[2].soil, Sim.SOIL_MAX - Sim.WEAR * Sim.TONIC_WEAR))
	s.feed = s.larder()
	s.lots[1].ripe = true
	_check("a full larder takes no more", not s.harvest(1) and s.lots[1].ripe)
	s.lots[1].soil = 40.0
	s.plant(1, Sim.FALLOW)
	s._step_fields(40.0)
	_check("a resting lot gets its soil back", is_equal_approx(s.lots[1].soil, 40.0 + Sim.REST * 40.0))
	_check("and grows nothing", not s.lots[1].ripe and s.gives(1) == 0)
	# the cart
	var c = _quiet()
	c.cart_t = -1000.0
	c._step_fields(Sim.CROPS[Sim.WHEAT].grow + 0.1)
	var ripe: int = c.ripe_count()
	c.cart_t = 0.0
	for k in int((c.cart_time() * 3.0 + 0.5) / 0.25):
		c._step_fields(0.25)
	_check("the cart takes the ripe lots by itself, one at a time (%d)" % ripe, ripe == 3 and c.loaves > 6 and c.feed > 8)
	c.ban = 10.0
	_check("tonic is refused while the gardeners' complaint stands", not c.set_tonic(0, true))

func _yard() -> void:
	var s = _quiet()
	s.feed = 0
	s._step_yard(Sim.EAT + Sim.MILK * 2.0)
	_check("an unfed cow gives nothing", not s.cows[0].full and s.cows[0].milk < 0.7)
	s = _quiet()
	s.pail_t = -1000.0
	s._step_yard(s.milk_time() + 0.5)
	_check("a fed cow fills in her time", s.cows[0].full)
	var had: int = s.cheese
	_check("a hand takes her milk for a cheese", s.milk(0) and s.cheese == had + 1 and not s.cows[0].full)
	_check("and nothing from a cow not full", not s.milk(0))
	_check("she ate as she went (%d feed left)" % s.feed, s.feed < 8)
	s.cows[0].poorly = true
	s.cows[0].full = true
	_check("a poorly cow gives nothing", not s.milk(0))
	_check("she is tucked up once", s.tuck(0) and not s.tuck(0))
	s._step_yard(Sim.TUCK + 0.5)
	_check("and is well after", not s.cows[0].poorly)
	s = _quiet()
	s._step_yard(s.milk_time() + s.pail_time() + 1.0)
	_check("the pail takes a full cow by itself", s.cheese == 5)
	# a hungry herd, with the stand open
	s = Sim.new(3)
	s.feed = 0
	s.lots[1].open = false
	s.lots[2].open = false
	for k in 200:
		s._step_yard(0.25)
	_check("a cow left unfed is poorly", s.cows[0].poorly and _has(s, "poorly") == 1)
	s = Sim.new(3)
	s.coins = 100000
	while s.buy("stall"):
		pass
	while s.buy("cow"):
		pass
	_check("a barn takes %d cows more than its %d stalls" % [Sim.CROWD, Sim.STALLS_MAX], s.cows.size() == Sim.STALLS_MAX + Sim.CROWD and s.crowded() == Sim.CROWD)

func _counter() -> void:
	var s = Sim.new(5)
	s.arrive = -1000.0
	s.step(s.cook_time() / s.pace() + 0.6)
	_check("a toastie takes a loaf and a cheese", s.ready == 1 and s.loaves <= 5 and s.cheese <= 4)
	_check("nobody is served with nobody waiting", not s.serve())
	s.queue = [0.0, 0.0]
	s.ready = 0
	s.cooking = [0.0, 0.0, 0.0]
	_check("nor with nothing on the pass", not s.serve())
	# the rush
	s = Sim.new(5)
	s.arrive = -1000.0
	s.loaves = 0
	s.ready = 30
	for k in 20:
		s.queue.append(0.0)
	s.tills = 3
	var first: int = s.link_pay(1)
	var sum := 0
	var coins: int = s.coins
	for k in 20:
		s.serve()
	for ev: Dictionary in s.events:
		if String(ev.type) == "serve":
			sum += int(ev.pay)
	_check("each link of a rush pays more, to the cap", s.link_pay(2) > first or Sim.PRICE < 9.0)
	_check("the cap holds: the 16th link pays what the 20th does", s.link_pay(Sim.RUSH_CAP + 1) == s.link_pay(20))
	_check("the 5th, 10th and 15th link are named", _has(s, "rush") == 3)
	_check("a queue emptied by a rush is a clean counter, paid once", _has(s, "clean") == 1 and s.cleans == 1)
	_check("the coins are the links' pay and the bonus", s.coins - coins == s.rush_sum and s.rush_sum > sum)
	_check("the rush is twenty links", s.rush == 20 and s.best_rush == 20)
	s.events.clear()
	s.step(Sim.WINDOW + 0.3)
	_check("it ends a window after its last link", s.rush == 0 and _has(s, "rush_end") == 1)
	# a till's own sale is no link
	s = Sim.new(5)
	s.arrive = -1000.0
	s.loaves = 0
	s.ready = 3
	s.queue = [0.0, 0.0, 0.0]
	s.step(s.serve_time() / s.pace() + 0.6)
	_check("the till sells by itself, and that is no link", s.served >= 1 and s.rush == 0)
	# patience
	s = Sim.new(5)
	s.arrive = -1000.0
	s.loaves = 0
	s.cheese = 0
	s.cows.clear()
	s.queue = [0.0]
	s.step(Sim.PATIENCE + 0.5)
	_check("a customer left waiting goes", s.queue.is_empty() and s.walked == 1)
	# pep and tea
	s = Sim.new(5)
	s.arrive = -1000.0
	s.pep = 10.0
	var slow: float = s.pace()
	_check("a worn crew is slower", slow < 0.6)
	_check("tea is taken", s.take_tea() and s.pace() == 0.0)
	s.step(Sim.TEA + 0.5)
	_check("and they are back with their pep", s.tea == 0.0 and s.pep > 90.0 and s.pace() > 0.9)
	s.set_bell(true)
	_check("the bell hurries them", s.pace() > 1.3)
	# the stars
	s = Sim.new(5)
	s.arrive = -1000.0
	s.ready = 1000
	s.loaves = 0
	var was: float = s.price()
	for k in Sim.STARS[0]:
		s.queue.append(0.0)
		s.serve(false)
	_check("the %dth toastie is the first star, and the price goes up" % Sim.STARS[0], s.stars == 1 and s.price() > was)

func _office() -> void:
	for row in [["garden", "tonic"], ["vet", "scraps"], ["crew", "bell"], ["town", "volume"]]:
		var s = Sim.new(9)
		s.arrive = -100000.0
		s.loaves = 0
		s.coins = 1000
		match String(row[1]):
			"tonic":
				s.set_tonic(0, true)
				s.set_tonic(1, true)
				s.set_tonic(2, true)
			"scraps":
				s.set_scraps(true)
				s.feed = 100000
			"bell":
				s.set_bell(true)
			"volume":
				s.set_volume(3)
		s.rng.seed = 1
		var others := true
		var t := 0.0
		while t < 3600.0 and _has(s, "boil") == 0:
			# nothing else is let go wrong: no cow hungry, the cart cuts the lots
			s.feed = maxi(s.feed, 20)
			for c: Dictionary in s.cows:
				if c.poorly and float(c.rest) <= 0.0:
					s.tuck(s.cows.find(c))
			s.step(1.0)
			t += 1.0
		for m: String in Sim.MOODS:
			if m != row[0] and float(s.mood[m]) > 30.0:
				others = false
		_check("%s raises the %s's mood to the top (%d s) and no other's" % [row[1], row[0], int(t)], _has(s, "boil") == 1 and _has(s, "warn") >= 1 and others)
		_check("  it settles at %d, and coins are not below zero (%d)" % [int(Sim.MOOD_AFTER), s.coins], absf(float(s.mood[row[0]]) - Sim.MOOD_AFTER) < 0.5 and s.coins >= 0)
		match String(row[0]):
			"garden":
				_check("  the gardeners' bill is paid and tonic is off and refused", s.coins < 1000 and s.tonic_count() == 0 and s.ban > 0.0)
			"vet":
				_check("  the vet's bill is paid, scraps are off, the herd lies in", s.coins < 1000 and not s.scraps and s.cows[0].poorly)
			"crew":
				_check("  the crew walk out and the bell is off", s.walk > 0.0 and not s.bell and s.pace() == 0.0)
			"town":
				_check("  the signboard is down and quiet for a while", s.volume == 0 and s.hush > 0.0 and not s.set_volume(2))
	var q = Sim.new(9)
	q.arrive = -100000.0
	q.loaves = 0
	for k in 600:
		q.step(1.0)
	var calm := true
	for m: String in Sim.MOODS:
		if float(q.mood[m]) > 0.5:
			calm = false
	_check("a stand with no shortcut taken annoys nobody", calm)
	q.set_volume(1)
	for k in 600:
		q.step(1.0)
	_check("a signboard one notch up is put up with", float(q.mood.town) < 1.0)
	q.mood.town = 80.0
	q.coins = 5
	_check("a favour is not had for nothing", not q.favour("town"))
	q.coins = 100000
	var p: int = q.favour_price("town")
	_check("a favour calms a mood by %d" % int(Sim.FAVOUR_CALMS), q.favour("town") and is_equal_approx(q.mood.town, 80.0 - Sim.FAVOUR_CALMS) and q.coins == 100000 - p)
	_check("the next waits, and costs more", not q.favour("town") and q.favour_price("town") > p)

func _kept() -> void:
	var s = Sim.new(11)
	s.coins = 100000
	s.buy("lot")
	s.plant(3, Sim.WHEAT)
	s.set_tonic(3, true)
	s.buy("cow")
	s.buy("stall")
	s.buy("grill")
	s.buy("till")
	s.buy_up("recipe")
	s.buy_up("larder")
	s.set_volume(2)
	s.set_scraps(true)
	s.mood.vet = 44.0
	s.served = 100
	s.stars = 2
	s.best_rush = 9
	for k in 30:
		s.step(1.0)
	s.ban = 50.0
	s.walk = 20.0
	s.hush = 70.0
	s.yesterday = 123
	s.save()
	var kept: Dictionary = Sim.kept()
	_check("the tab's card reads the stand kept", int(kept.served) == s.served and int(kept.stars) == 2)
	var b = Sim.load_saved(11)
	_check("a stand saved comes back as it was", b.coins == s.coins and b.opened() == 4 and int(b.lots[3].crop) == Sim.WHEAT and b.lots[3].tonic
		and b.cows.size() == 2 and b.stalls == 3 and b.grills == 2 and b.tills == 2 and int(b.lv.recipe) == 1 and int(b.lv.larder) == 1
		and b.volume == 2 and b.scraps and b.stars == 2 and b.best_rush == 9 and b.ban > 40.0 and b.walk > 10.0 and b.hush > 60.0 and b.yesterday == 123 and absf(float(b.mood.vet) - float(s.mood.vet)) < 0.01)
	# away
	var a = Sim.new(13)
	a.coins = 50
	a.mood.town = 30.0
	a.set_volume(3)
	a.set_scraps(true)
	a.events.clear()
	var came: int = a.away(3600.0)
	_check("time away fills the larder (%d came in)" % came, came > 10 and a.loaves == a.larder() and a.feed > 0)
	_check("sells nothing, moves no mood, sickens no cow and says nothing", a.coins == 50 and a.served == 0 and is_equal_approx(a.mood.town, 30.0) and a.poorly_count() == 0 and a.events.is_empty())
	a.feed = 0
	for l: Dictionary in a.lots:
		l.open = false
	a.away(100000.0)
	a.step(0.25)
	_check("a herd left with an empty trough is not found poorly, nor poorly at once", a.poorly_count() == 0 and _has(a, "poorly") == 0)

# --- the bots ---

## Buys the cheapest thing that helps, as a player who reads the plates.
func _shop(s: RefCounted) -> void:
	var best := ""
	var best_p := 1 << 60
	var kind := ""
	for what: String in Sim.BUYS:
		var p: int = s.buy_price(what)
		# no cow over the stalls, no stall with a stall free
		if what == "cow" and s.cows.size() >= s.stalls:
			continue
		if what == "stall" and s.cows.size() < s.stalls:
			continue
		if p >= 0 and p < best_p:
			best = what
			best_p = p
			kind = "buy"
	for id: String in Sim.UPS:
		var p: int = s.up_price(id)
		if p < best_p:
			best = id
			best_p = p
			kind = "up"
	if best != "" and s.coins >= best_p:
		if kind == "buy":
			s.buy(best)
			if best == "lot":
				# a new lot: clover while the herd outeats the fields, else wheat
				var wheat := 0
				var clover := 0
				for l: Dictionary in s.lots:
					if l.open and int(l.crop) == Sim.WHEAT:
						wheat += 1
					elif l.open and int(l.crop) == Sim.CLOVER:
						clover += 1
				for i in Sim.LOTS:
					if s.lots[i].open and int(s.lots[i].crop) == Sim.FALLOW and float(s.lots[i].soil) >= Sim.SOIL_MAX:
						s.plant(i, Sim.CLOVER if clover <= wheat else Sim.WHEAT)
		else:
			s.buy_up(best)

## A lot worn thin is rested and a rested one sown again.
func _tend(s: RefCounted) -> void:
	for i in Sim.LOTS:
		var l: Dictionary = s.lots[i]
		if not l.open:
			continue
		if int(l.crop) != Sim.FALLOW and float(l.soil) < 40.0:
			l["was"] = int(l.crop)
			s.plant(i, Sim.FALLOW)
		elif int(l.crop) == Sim.FALLOW and float(l.soil) >= 95.0 and l.has("was"):
			s.plant(i, int(l.was))
	for k in s.cows.size():
		s.tuck(k)
	if s.pep < 30.0:
		s.take_tea()

func _pace() -> void:
	# the one who only looks on: buys, tends, never serves
	var s = Sim.new(21)
	var t := 0.0
	while t < 3600.0:
		s.step(0.25)
		t += 0.25
		if int(t) % 5 == 0 and is_equal_approx(t, float(int(t))):
			_shop(s)
			_tend(s)
		s.events.clear()
	print("    looking on, one hour: %d served, %d earned, %d stars, %d lots, %d cows, %d walked off; best rush %d" % [s.served, s.earned, s.stars, s.opened(), s.cows.size(), s.walked, s.best_rush])
	_check("a stand only looked on still earns (%d in an hour)" % s.earned, s.earned > 1500)
	var idle: int = s.earned
	# the one who goes round: twenty seconds a place, serving by hand at the counter
	s = Sim.new(21)
	t = 0.0
	var star_at := {}
	var hours := 0.0
	while t < 3600.0 * 8.0:
		s.step(0.25)
		t += 0.25
		var place := int(t / 20.0) % 3
		if place == 0:
			for i in Sim.LOTS:
				s.harvest(i)
		elif place == 1:
			for k in s.cows.size():
				s.milk(k)
		else:
			# a tap every quarter second while there is something to sell
			s.serve()
		if is_equal_approx(t, float(int(t))) and int(t) % 5 == 0:
			_shop(s)
			_tend(s)
		for ev: Dictionary in s.events:
			if String(ev.type) == "star":
				star_at[int(ev.n)] = t
		s.events.clear()
		if is_equal_approx(t, 3600.0):
			print("    going round, one hour: %d served, %d earned, %d stars, %d lots, %d cows, %d walked off; best rush %d, %d clean counters" % [s.served, s.earned, s.stars, s.opened(), s.cows.size(), s.walked, s.best_rush, s.cleans])
			_check("a hand earns more than looking on (%d against %d)" % [s.earned, idle], s.earned > idle * 1.15)
	var line := "    stars at (min):"
	for n: int in star_at:
		line += " %d:%d" % [n, int(float(star_at[n]) / 60.0)]
	print(line)
	print("    going round, eight hours: %d served, %d earned, %d stars, price %.1f, levels %s" % [s.served, s.earned, s.stars, s.price(), str(s.lv)])
	hours = float(star_at.get(1, 0.0)) / 60.0
	_check("the first star comes in 3 to 12 minutes (%.1f)" % hours, hours >= 3.0 and hours <= 12.0)
	_check("the fifth star takes an hour or more (%s min)" % str(int(float(star_at.get(5, 1e9)) / 60.0)), float(star_at.get(5, 1e9)) >= 3600.0)
	_check("coins never went below zero", s.coins >= 0)
