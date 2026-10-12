extends RefCounted

## Furrow, as pure data: a field of plots, a crop growing on each, and the
## seeds they pay (spec docs/superpowers/specs/2026-10-11-arcade-furrow-design.md).
## The screen (arcade/furrow_screen.gd) and the field it draws
## (arcade/furrow_field.gd) call in and play `events`; nothing here draws,
## sounds or reads a clock but `save` and `load_saved`.
##
## **A kept game.** There is no run: the field is saved (`path`) and grows
## on the wall clock while the game is shut. Nothing is picked, sold or
## banked while away, so time away is worth one full field and no more.
##
## **A crop** takes `grow` seconds and pays `value` seeds. A slower crop
## pays more a second, so the slow ones are for going away and the quick
## ones for staying. **Ripe, it keeps** for `keep_time` (KEEP_TIMES its
## growing, never under KEEP_MIN) and then withers: a dead crop pays
## nothing and is cleared by a touch. **A picked plot is bare** (the user,
## 2026-10-12: "user must select and click to plant on soil after harvest,
## no auto for now"): nothing grows on it until a packet is sown there.
##
## **The animals** (the user, the same day). A coop of hens lays eggs on
## the ground, up to NEST a hen, and a touch gathers one; a cow fills in
## `milk_time` and gives her milk to a touch, never by herself. Both are
## links of the chain. Each has its own upgrades and its own milestones
## (EGG_MILES, MILK_MILES: seeds at once and MILE_UP on what it pays, for
## good). A rooster makes one egg in so many a chick, a hen in CHICK_GROW.
## The fence holds FENCE_HOLDS once mended; with it down a fox comes by
## every FOX_EVERY or so and takes a hen unless it is shooed (`shoo`),
## never the last, and no more than FOX_AWAY while the game is shut.
##
## **The chain.** Each crop picked within WINDOW seconds of the last is a
## link, and a link pays `chain_step()` more than the one before it, up to
## as many links as there are open plots (a chain kept going past that
## stays at its top). So a field left to ripen and picked in one stroke
## pays far more than the same crops picked one by one. The whole field in
## one chain is a clean sweep and pays SWEEP of the chain again.
##
## Seeds are Furrow's own: gold buys none of this. They open plots (one at
## a time, in ORDER), buy the next crop's packet, and three upgrades with no
## top, each level GROWTH times the last.
##
##   step(dt)        grows the field and runs the chain's clock
##   pick(i)         picks a ripe plot and leaves it bare; false when it is not
##   clear(i)        takes a dead crop off its plot
##   dig(i)          takes a growing one off
##   sow(i, crop)    sows a bare plot
##   buy_plot()      opens the next plot, bare
##   buy_crop()      the next crop's packet
##   buy_up(id)      a level of an upgrade
##   gather()        an egg off the ground
##   milk(k)         cow `k`, when she is full
##   buy(what)       the coop, a hen, the rooster, the fence mended, the
##                   pasture, a cow: `price(what)` is -1 when it is not for sale

const COLS := 4
const ROWS := 5
## The plots open on a new field.
const START := 4
## id, seconds to grow, seeds a crop, the packet's price.
const CROPS := [
	{"id": "radish", "grow": 10.0, "value": 1, "price": 0},
	{"id": "carrot", "grow": 30.0, "value": 4, "price": 60},
	{"id": "lettuce", "grow": 90.0, "value": 14, "price": 600},
	{"id": "tomato", "grow": 240.0, "value": 45, "price": 6000},
	{"id": "corn", "grow": 600.0, "value": 130, "price": 50000},
	{"id": "pumpkin", "grow": 1800.0, "value": 450, "price": 400000},
	{"id": "sunflower", "grow": 7200.0, "value": 2100, "price": 3000000},
	{"id": "melon", "grow": 28800.0, "value": 10000, "price": 25000000},
]
## The fifth plot's price, and how much dearer each one after it is.
const PLOT_FIRST := 15
const PLOT_GROWTH := 1.62
const UPS := ["compost", "basket", "knack", "mulch"]
const COOP_UPS := ["feed", "nest"]
const COW_UPS := ["care", "pail"]
const ALL_UPS := ["compost", "basket", "knack", "mulch", "feed", "nest", "care", "pail"]
const FIRST := {"compost": 50, "basket": 80, "knack": 120, "mulch": 90, "feed": 150, "nest": 200, "care": 900, "pail": 1200}
const GROWTH := 1.45
## A level of Compost grows everything this much faster, of Basket pays
## this much more, of Knack adds this to what each link pays.
const COMPOST_UP := 0.04
const BASKET_UP := 0.08
const KNACK_UP := 0.005
## A ripe crop keeps KEEP_TIMES as long as it took to grow, never less than
## KEEP_MIN seconds, and a level of Mulch this much longer.
const KEEP_TIMES := 3.0
const KEEP_MIN := 90.0
const MULCH_UP := 0.1
## What a link pays more than the one before it, and the seconds a chain
## waits for its next link.
const CHAIN_STEP := 0.05
const WINDOW := 1.6
## The links that are a moment, and every EVERY after the last of them.
const BUNCHES := [5, 10, 15, 20]
const EVERY := 10
## The whole field in one chain: this much of the chain again, from MIN_SWEEP
## open plots.
const SWEEP := 0.25
const MIN_SWEEP := 6
## One ripening in so many is golden and pays GOLD_TIMES.
const GOLD_CHANCE := 0.04
const GOLD_TIMES := 5
## The stages a plant is drawn in: a mound, a sprout, a young plant, ripe;
## then DEAD, and BARE for a plot with nothing sown.
const STAGES := 4
const DEAD := 4
const BARE := -1

## The coop: its price, the hens it comes with and has room for, a hen's
## price and how much dearer each is.
const COOP_PRICE := 300
const HENS_START := 2
const HENS_MAX := 8
const HEN_FIRST := 150
const HEN_GROWTH := 1.5
## A hen lays every LAY seconds, an egg pays EGG, and NEST eggs a hen lie
## on the ground before the hens stop.
const LAY := 40.0
const EGG := 5
const NEST := 3
const FEED_UP := 0.05
const NEST_UP := 0.1
## With a rooster one egg in so many is a chick, a hen in CHICK_GROW seconds.
const ROOSTER_PRICE := 2500
const HATCH := 0.08
const CHICK_GROW := 300.0
## The fence: mended it holds this long. Down, a fox comes every FOX_EVERY
## seconds or so, is FOX_TIME on its way (a touch shoos it) and takes a
## hen; never the last, and FOX_AWAY at most while the game is shut.
const FENCE_HOLDS := 86400.0
const FENCE_FIRST := 60
const FENCE_A_HEN := 40
const FOX_EVERY := 900.0
const FOX_TIME := 6.0
const FOX_AWAY := 2
## The pasture: its price, the cows it has room for, a cow's price.
const PASTURE_PRICE := 4000
const COWS_MAX := 5
const COW_FIRST := 2500
const COW_GROWTH := 1.7
## A cow fills in MILK_TIME seconds and her milk pays MILK.
const MILK_TIME := 150.0
const MILK := 60
const CARE_UP := 0.05
const PAIL_UP := 0.1
## Each animal's milestones: so many gathered, the seeds each pays at once,
## and what every one reached adds to what an egg or a bottle pays.
const EGG_MILES := [10, 50, 200, 1000, 5000, 20000]
const EGG_PRIZES := [60, 400, 2000, 12000, 70000, 300000]
const MILK_MILES := [5, 25, 100, 500, 2500, 10000]
const MILK_PRIZES := [300, 2000, 10000, 60000, 350000, 1500000]
const MILE_UP := 0.1
const SPROUT := 0.12
const YOUNG := 0.5

static var path := "user://furrow.cfg"

var cols := COLS
var rows := ROWS
## A plot: {open, crop (BARE: nothing sown), t (seconds grown), ripe, gold,
## age (seconds ripe), dead}.
var plots: Array = []
## The order the plots open in: from the middle out.
var order: Array = []
var seeds := 0
## Every seed ever paid, and every crop ever picked.
var earned := 0
var picked := 0
## How many of CROPS are held: the first `crops` of them.
var crops := 1
var lv := {"compost": 0, "basket": 0, "knack": 0, "mulch": 0, "feed": 0, "nest": 0, "care": 0, "pail": 0}
## The coop: whether it is built, the hens, each chick's seconds grown, the
## eggs on the ground and the egg on its way (a part of one).
var coop := false
var hens := 0
var chicks: Array = []
var rooster := false
var eggs := 0
var lay_acc := 0.0
## The seconds the fence still holds (0: down), the seconds to the next fox
## with it down, and the seconds a fox on its way still needs (0: none).
var fence_t := 0.0
var fox_t := FOX_EVERY
var fox := 0.0
var eggs_got := 0
var hens_lost := 0
## The pasture: whether it is fenced, and each cow's seconds filled.
var pasture := false
var cows: Array = []
var milk_got := 0
## What has been looked at once: a crop's id, "hen", "cow". The screen
## shows a thing's card the first time it is touched.
var seen: Array = []
## The chain: its links, the seconds it still waits, and what it has paid.
var chain := 0
var chain_t := 0.0
var chain_sum := 0
var _swept := false
## The plots picked in this chain: all of them is the sweep.
var _chain_plots := 0
var best_chain := 0
var best_sweep := 0
var sweeps := 0
## What the time away did, for the screen's welcome: the seconds, and the
## plots that ripened in them.
var away_secs := 0.0
var away_ripe := 0
## And the crops that died in them, the eggs laid, the cows that filled and
## the hens a fox took.
var away_dead := 0
var away_eggs := 0
var away_milk := 0
var away_lost := 0
## The wall clock at the last step, to measure a pause by.
var stamp := 0.0
var events: Array = []
var _rng := RandomNumberGenerator.new()

func _init(rng_seed := 0, c := COLS, r := ROWS, start := START) -> void:
	cols = c
	rows = r
	if rng_seed != 0:
		_rng.seed = rng_seed
	else:
		_rng.randomize()
	for i in cols * rows:
		plots.append({"open": false, "crop": BARE, "t": 0.0, "ripe": false, "gold": false, "age": 0.0, "dead": false})
	order = range(cols * rows)
	var mid := Vector2((cols - 1) * 0.5, minf((rows - 1) * 0.5, 1.5))
	order.sort_custom(func(a: int, b: int) -> bool:
		var da := Vector2(a % cols, a / cols).distance_squared_to(mid)
		var db := Vector2(b % cols, b / cols).distance_squared_to(mid)
		return da < db if not is_equal_approx(da, db) else a < b)
	for k in mini(start, order.size()):
		plots[order[k]].open = true
		# a new field is sown with the first crop, so there is something to pick
		plots[order[k]].crop = 0
	stamp = Time.get_unix_time_from_system()

# --- what things are worth ---

func grow_time(crop: int) -> float:
	return float(CROPS[crop].grow) / (1.0 + COMPOST_UP * int(lv.compost))

## The seeds a crop pays before the chain.
func worth(crop: int) -> int:
	return maxi(1, int(round(float(CROPS[crop].value) * (1.0 + BASKET_UP * int(lv.basket)))))

## The seconds crop `crop` keeps once ripe, before it withers.
func keep_time(crop: int) -> float:
	return maxf(KEEP_MIN, float(CROPS[crop].grow) * KEEP_TIMES) * (1.0 + MULCH_UP * int(lv.mulch))

func chain_step() -> float:
	return CHAIN_STEP + KNACK_UP * int(lv.knack)

func opened() -> int:
	var n := 0
	for p: Dictionary in plots:
		if p.open:
			n += 1
	return n

func ripe_count() -> int:
	var n := 0
	for p: Dictionary in plots:
		if p.open and p.ripe and not p.dead:
			n += 1
	return n

func dead_count() -> int:
	var n := 0
	for p: Dictionary in plots:
		if p.open and p.dead:
			n += 1
	return n

func bare_count() -> int:
	var n := 0
	for p: Dictionary in plots:
		if p.open and int(p.crop) == BARE:
			n += 1
	return n

## What link `n` of a chain pays, as a multiple of the crop's worth.
func times(n: int) -> float:
	return 1.0 + chain_step() * (mini(n, opened()) - 1)

## How far along plot `i` is, 0 to 1.
func grown(i: int) -> float:
	var p: Dictionary = plots[i]
	if int(p.crop) == BARE:
		return 0.0
	return 1.0 if p.ripe else clampf(float(p.t) / grow_time(p.crop), 0.0, 1.0)

func left(i: int) -> float:
	var p: Dictionary = plots[i]
	return 0.0 if p.ripe or int(p.crop) == BARE else maxf(0.0, grow_time(p.crop) - float(p.t))

## How much of its keeping a ripe plot has left, 1 to 0.
func fresh(i: int) -> float:
	var p: Dictionary = plots[i]
	if not p.ripe or p.dead:
		return 0.0
	return clampf(1.0 - float(p.age) / keep_time(p.crop), 0.0, 1.0)

## The seconds a ripe plot still keeps.
func keeps(i: int) -> float:
	var p: Dictionary = plots[i]
	return maxf(0.0, keep_time(p.crop) - float(p.age)) if p.ripe and not p.dead else 0.0

func stage(i: int) -> int:
	var p: Dictionary = plots[i]
	if int(p.crop) == BARE:
		return BARE
	if p.dead:
		return DEAD
	var k := grown(i)
	return 3 if p.ripe else 2 if k >= YOUNG else 1 if k >= SPROUT else 0

## The plot the next purchase opens, -1 with the field whole.
func next_plot() -> int:
	for i: int in order:
		if not plots[i].open:
			return i
	return -1

static func _fives(v: float) -> int:
	return int(round(v / 5.0)) * 5

func plot_price() -> int:
	return _fives(PLOT_FIRST * pow(PLOT_GROWTH, opened() - START))

## The next packet's price, -1 with every crop held.
func crop_price() -> int:
	return int(CROPS[crops].price) if crops < CROPS.size() else -1

func up_price(id: String) -> int:
	return _fives(float(FIRST[id]) * pow(GROWTH, int(lv[id])))

## What level `n` of an upgrade is worth, as the shop letters it.
func up_worth(id: String, n: int) -> String:
	match id:
		"compost":
			return "+%d%%" % int(round(COMPOST_UP * n * 100.0))
		"basket":
			return "+%d%%" % int(round(BASKET_UP * n * 100.0))
		"mulch":
			return "+%d%%" % int(round(MULCH_UP * n * 100.0))
		"feed":
			return "+%d%%" % int(round(FEED_UP * n * 100.0))
		"nest":
			return "+%d%%" % int(round(NEST_UP * n * 100.0))
		"care":
			return "+%d%%" % int(round(CARE_UP * n * 100.0))
		"pail":
			return "+%d%%" % int(round(PAIL_UP * n * 100.0))
		_:
			return "+%.1f%%" % ((CHAIN_STEP + KNACK_UP * n) * 100.0)

# --- time ---

## Grows plot `p` by `dt`: 1 when it ripened and waits, 2 when it died (ripe
## before or within these seconds), 0 otherwise. `keeps` false lets nothing
## die: a field kept by a build that knew no withering is not lost to it.
func _grow(p: Dictionary, dt: float, keeps := true) -> int:
	if not p.open or p.dead or int(p.crop) == BARE:
		return 0
	var out := 0
	if not p.ripe:
		p.t = float(p.t) + dt
		var g := grow_time(p.crop)
		if float(p.t) < g:
			return 0
		p.ripe = true
		p.gold = _rng.randf() < GOLD_CHANCE
		p.age = float(p.t) - g
		out = 1
	else:
		p.age = float(p.age) + dt
	if not keeps:
		p.age = 0.0
	elif float(p.age) >= keep_time(p.crop):
		p.dead = true
		p.gold = false
		return 2
	return out

func step(dt: float) -> void:
	stamp = Time.get_unix_time_from_system()
	for i in plots.size():
		match _grow(plots[i], dt):
			1:
				events.append({"type": "ripe", "i": i, "gold": plots[i].gold})
			2:
				events.append({"type": "dead", "i": i})
	_animals(dt, true)
	if coop:
		if fence_t > 0.0:
			fence_t = maxf(0.0, fence_t - dt)
			if fence_t == 0.0:
				events.append({"type": "fence_down"})
		elif fox > 0.0:
			fox -= dt
			if fox <= 0.0:
				fox = 0.0
				fox_t = FOX_EVERY * _rng.randf_range(0.7, 1.3)
				if hens > 1:
					hens -= 1
					hens_lost += 1
					events.append({"type": "took"})
		elif hens > 1:
			fox_t -= dt
			if fox_t <= 0.0:
				fox = FOX_TIME
				events.append({"type": "fox"})
	if chain > 0:
		chain_t -= dt
		if chain_t <= 0.0:
			_end_chain()

## The hens lay, the chicks grow and the cows fill, by `dt`. `live` says so
## in `events`; time away does not. Returns [eggs laid, cows filled].
func _animals(dt: float, live: bool) -> Array:
	var laid := 0
	var filled := 0
	if coop:
		var k := 0
		while k < chicks.size():
			chicks[k] = float(chicks[k]) + dt
			if float(chicks[k]) >= CHICK_GROW:
				chicks.remove_at(k)
				hens += 1
				if live:
					events.append({"type": "grown"})
			else:
				k += 1
		lay_acc += dt * hens / lay_time()
		while lay_acc >= 1.0:
			if rooster and hens + chicks.size() < HENS_MAX and _rng.randf() < HATCH:
				chicks.append(0.0)
				if live:
					events.append({"type": "chick"})
			elif eggs < nest_room():
				eggs += 1
				laid += 1
				if live:
					events.append({"type": "egg"})
			else:
				# the ground is full: the next egg waits
				lay_acc = 1.0
				break
			lay_acc -= 1.0
	if pasture:
		var full := milk_time()
		for c in cows.size():
			if float(cows[c]) < full:
				cows[c] = minf(full, float(cows[c]) + dt)
				if float(cows[c]) >= full:
					filled += 1
					if live:
						events.append({"type": "full", "k": c})
	return [laid, filled]

## Time gone by with the game shut or asleep: the field grows, in one go
## however long it was, what was ripe too long dies, the hens lay to the
## ground's room, the cows fill, and a fox takes a hen or two with the fence
## down. Returns the plots that ripened and wait; the rest is in `away_*`.
func away(seconds: float, keeps := true) -> int:
	var n := 0
	away_dead = 0
	away_eggs = 0
	away_milk = 0
	away_lost = 0
	if seconds <= 0.0:
		return 0
	for p: Dictionary in plots:
		match _grow(p, seconds, keeps):
			1:
				n += 1
			2:
				away_dead += 1
	var got := _animals(seconds, false)
	away_eggs = got[0]
	away_milk = got[1]
	if coop:
		var down := maxf(0.0, seconds - fence_t)
		fence_t = maxf(0.0, fence_t - seconds)
		fox = 0.0
		var visits := mini(FOX_AWAY, int(down / FOX_EVERY))
		away_lost = clampi(visits, 0, maxi(0, hens - 1))
		hens -= away_lost
		hens_lost += away_lost
		eggs = mini(eggs, nest_room())
		if visits > 0:
			fox_t = FOX_EVERY * _rng.randf_range(0.7, 1.3)
		else:
			fox_t = maxf(30.0, fox_t - down)
	if chain > 0:
		_end_chain()
		events.clear()
	return n

func _end_chain() -> void:
	events.append({"type": "chain_end", "n": chain, "sum": chain_sum, "swept": _swept})
	best_chain = maxi(best_chain, chain)
	best_sweep = maxi(best_sweep, chain_sum)
	chain = 0
	chain_sum = 0
	chain_t = 0.0
	_swept = false
	_chain_plots = 0

# --- the hand ---

## A link of the chain worth `base` before it: the seeds it pays.
func _link(base: float) -> int:
	chain += 1
	chain_t = WINDOW
	var pay := maxi(1, int(round(base * times(chain))))
	seeds += pay
	earned += pay
	chain_sum += pay
	return pay

func _bunch() -> void:
	if chain in BUNCHES or (chain > BUNCHES[-1] and (chain - BUNCHES[-1]) % EVERY == 0):
		events.append({"type": "bunch", "n": chain, "tier": mini(BUNCHES.size(), (chain + 4) / 5) - 1})

func pick(i: int) -> bool:
	var p: Dictionary = plots[i]
	if not p.open or not p.ripe or p.dead:
		return false
	var crop := int(p.crop)
	var gold: bool = p.gold
	var pay := _link(worth(crop) * (GOLD_TIMES if gold else 1))
	picked += 1
	_chain_plots += 1
	events.append({"type": "pick", "i": i, "crop": crop, "gold": gold, "n": chain, "pay": pay})
	_bare(p)
	_bunch()
	var open := opened()
	if not _swept and _chain_plots == open and open >= MIN_SWEEP:
		_swept = true
		sweeps += 1
		var bonus := maxi(1, int(round(chain_sum * SWEEP)))
		seeds += bonus
		earned += bonus
		chain_sum += bonus
		events.append({"type": "sweep", "n": chain, "bonus": bonus})
	return true

func _bare(p: Dictionary) -> void:
	p.crop = BARE
	p.t = 0.0
	p.age = 0.0
	p.ripe = false
	p.gold = false
	p.dead = false

## Takes a dead crop off its plot: nothing paid, and no link.
func clear(i: int) -> bool:
	var p: Dictionary = plots[i]
	if not p.open or not p.dead:
		return false
	events.append({"type": "clear", "i": i, "crop": int(p.crop)})
	_bare(p)
	return true

## Takes a crop still growing off its plot, for another to be sown there.
func dig(i: int) -> bool:
	var p: Dictionary = plots[i]
	if not p.open or int(p.crop) == BARE or p.ripe or p.dead:
		return false
	events.append({"type": "dig", "i": i, "crop": int(p.crop)})
	_bare(p)
	return true

## Sows a bare plot. Nothing is sown over what grows, waits or lies dead.
func sow(i: int, crop: int) -> bool:
	var p: Dictionary = plots[i]
	if not p.open or crop < 0 or crop >= crops or int(p.crop) != BARE:
		return false
	p.crop = crop
	p.t = 0.0
	events.append({"type": "sow", "i": i, "crop": crop})
	return true

func buy_plot() -> int:
	var i := next_plot()
	var cost := plot_price()
	if i < 0 or seeds < cost:
		return -1
	seeds -= cost
	var p: Dictionary = plots[i]
	p.open = true
	_bare(p)
	events.append({"type": "plot", "i": i, "paid": cost})
	return i

func buy_crop() -> bool:
	var cost := crop_price()
	if cost < 0 or seeds < cost:
		return false
	seeds -= cost
	crops += 1
	events.append({"type": "crop", "crop": crops - 1, "paid": cost})
	return true

func buy_up(id: String) -> bool:
	var cost := up_price(id)
	if seeds < cost:
		return false
	seeds -= cost
	lv[id] = int(lv[id]) + 1
	events.append({"type": "up", "id": id, "level": int(lv[id]), "paid": cost})
	return true

# --- the animals ---

func lay_time() -> float:
	return LAY / (1.0 + FEED_UP * int(lv.feed))

## The eggs the ground has room for.
func nest_room() -> int:
	return hens * NEST

func milk_time() -> float:
	return MILK_TIME / (1.0 + CARE_UP * int(lv.care))

## How many of an animal's milestones are reached ("egg" or "milk").
func miles(kind: String) -> int:
	var got := eggs_got if kind == "egg" else milk_got
	var n := 0
	for m: int in (EGG_MILES if kind == "egg" else MILK_MILES):
		if got >= m:
			n += 1
	return n

## The next milestone's count, -1 with every one reached.
func next_mile(kind: String) -> int:
	var all: Array = EGG_MILES if kind == "egg" else MILK_MILES
	var n := miles(kind)
	return int(all[n]) if n < all.size() else -1

func egg_worth() -> int:
	return maxi(1, int(round(EGG * (1.0 + NEST_UP * int(lv.nest)) * (1.0 + MILE_UP * miles("egg")))))

func milk_worth() -> int:
	return maxi(1, int(round(MILK * (1.0 + PAIL_UP * int(lv.pail)) * (1.0 + MILE_UP * miles("milk")))))

func cow_full(k: int) -> bool:
	return k >= 0 and k < cows.size() and float(cows[k]) >= milk_time()

func cow_left(k: int) -> float:
	return maxf(0.0, milk_time() - float(cows[k]))

func full_count() -> int:
	var n := 0
	for k in cows.size():
		if cow_full(k):
			n += 1
	return n

func _mile(kind: String, before: int) -> void:
	var now := miles(kind)
	for n in range(before, now):
		var prize := int((EGG_PRIZES if kind == "egg" else MILK_PRIZES)[n])
		seeds += prize
		earned += prize
		events.append({"type": "mile", "kind": kind, "n": n + 1, "prize": prize, "count": int((EGG_MILES if kind == "egg" else MILK_MILES)[n])})

## An egg off the ground: a link of the chain.
func gather() -> bool:
	if not coop or eggs <= 0:
		return false
	var before := miles("egg")
	eggs -= 1
	eggs_got += 1
	var pay := _link(egg_worth())
	events.append({"type": "gather", "n": chain, "pay": pay})
	_bunch()
	_mile("egg", before)
	return true

## Cow `k` milked, when she is full: a link of the chain.
func milk(k: int) -> bool:
	if not pasture or not cow_full(k):
		return false
	var before := miles("milk")
	cows[k] = 0.0
	milk_got += 1
	var pay := _link(milk_worth())
	events.append({"type": "milk", "k": k, "n": chain, "pay": pay})
	_bunch()
	_mile("milk", before)
	return true

## The fox sent off before it reached the hens.
func shoo() -> bool:
	if fox <= 0.0:
		return false
	fox = 0.0
	fox_t = FOX_EVERY * _rng.randf_range(0.7, 1.3)
	events.append({"type": "shoo"})
	return true

## What `what` costs now: "coop", "hen", "rooster", "fence", "pasture" or
## "cow". -1 when it is not for sale (held, full, or its pen not built).
func price(what: String) -> int:
	match what:
		"coop":
			return -1 if coop else COOP_PRICE
		"hen":
			return _fives(HEN_FIRST * pow(HEN_GROWTH, maxi(0, hens + chicks.size() - HENS_START))) if coop and hens + chicks.size() < HENS_MAX else -1
		"rooster":
			return ROOSTER_PRICE if coop and not rooster else -1
		"fence":
			return FENCE_FIRST + FENCE_A_HEN * hens if coop and fence_t <= 0.0 else -1
		"pasture":
			return -1 if pasture else PASTURE_PRICE
		"cow":
			return _fives(COW_FIRST * pow(COW_GROWTH, cows.size() - 1)) if pasture and cows.size() < COWS_MAX else -1
	return -1

func buy(what: String) -> bool:
	var cost := price(what)
	if cost < 0 or seeds < cost:
		return false
	seeds -= cost
	match what:
		"coop":
			coop = true
			hens = HENS_START
			fence_t = 0.0
			fox_t = FOX_EVERY
		"hen":
			hens += 1
		"rooster":
			rooster = true
		"fence":
			fence_t = FENCE_HOLDS
			if fox > 0.0:
				shoo()
		"pasture":
			pasture = true
			cows = [0.0]
		"cow":
			cows.append(0.0)
	events.append({"type": "bought", "what": what, "paid": cost})
	return true

## Marks `id` as looked at: true the first time.
func see(id: String) -> bool:
	if id in seen:
		return false
	seen.append(id)
	return true

# --- kept ---

## Writes the field to `path`; a harness that must leave no file sets it to "".
func save() -> void:
	if path == "":
		return
	var cfg := ConfigFile.new()
	var rows_out := []
	for p: Dictionary in plots:
		rows_out.append([p.open, int(p.crop), float(p.t), p.ripe, p.gold, float(p.age), p.dead])
	cfg.set_value("field", "ver", 2)
	cfg.set_value("field", "plots", rows_out)
	cfg.set_value("field", "seen", seen)
	cfg.set_value("coop", "built", coop)
	cfg.set_value("coop", "hens", hens)
	cfg.set_value("coop", "chicks", chicks)
	cfg.set_value("coop", "rooster", rooster)
	cfg.set_value("coop", "eggs", eggs)
	cfg.set_value("coop", "lay", lay_acc)
	cfg.set_value("coop", "fence", fence_t)
	cfg.set_value("coop", "fox", fox_t)
	cfg.set_value("coop", "got", eggs_got)
	cfg.set_value("coop", "lost", hens_lost)
	cfg.set_value("cows", "built", pasture)
	cfg.set_value("cows", "cows", cows)
	cfg.set_value("cows", "got", milk_got)
	cfg.set_value("field", "seeds", seeds)
	cfg.set_value("field", "earned", earned)
	cfg.set_value("field", "picked", picked)
	cfg.set_value("field", "crops", crops)
	cfg.set_value("field", "lv", lv)
	cfg.set_value("field", "best_chain", best_chain)
	cfg.set_value("field", "best_sweep", best_sweep)
	cfg.set_value("field", "sweeps", sweeps)
	cfg.set_value("field", "stamp", Time.get_unix_time_from_system())
	cfg.save(path)

## The kept field, grown by the time away; a new one with nothing kept.
static func load_saved(rng_seed := 0) -> RefCounted:
	var s = new(rng_seed)
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return s
	var kept: Array = cfg.get_value("field", "plots", [])
	for i in mini(kept.size(), s.plots.size()):
		var row: Array = kept[i]
		s.plots[i] = {"open": bool(row[0]), "crop": clampi(int(row[1]), BARE, CROPS.size() - 1), "t": float(row[2]), "ripe": bool(row[3]), "gold": bool(row[4]),
			"age": float(row[5]) if row.size() > 5 else 0.0, "dead": bool(row[6]) if row.size() > 6 else false}
	s.seeds = int(cfg.get_value("field", "seeds", 0))
	s.earned = int(cfg.get_value("field", "earned", 0))
	s.picked = int(cfg.get_value("field", "picked", 0))
	s.crops = clampi(int(cfg.get_value("field", "crops", 1)), 1, CROPS.size())
	var levels: Dictionary = cfg.get_value("field", "lv", {})
	for id: String in ALL_UPS:
		s.lv[id] = int(levels.get(id, 0))
	s.seen = Array(cfg.get_value("field", "seen", []))
	s.coop = bool(cfg.get_value("coop", "built", false))
	s.hens = clampi(int(cfg.get_value("coop", "hens", 0)), 0, HENS_MAX)
	s.chicks = Array(cfg.get_value("coop", "chicks", []))
	s.rooster = bool(cfg.get_value("coop", "rooster", false))
	s.eggs = int(cfg.get_value("coop", "eggs", 0))
	s.lay_acc = float(cfg.get_value("coop", "lay", 0.0))
	s.fence_t = float(cfg.get_value("coop", "fence", 0.0))
	s.fox_t = float(cfg.get_value("coop", "fox", FOX_EVERY))
	s.eggs_got = int(cfg.get_value("coop", "got", 0))
	s.hens_lost = int(cfg.get_value("coop", "lost", 0))
	s.pasture = bool(cfg.get_value("cows", "built", false))
	s.cows = Array(cfg.get_value("cows", "cows", []))
	s.milk_got = int(cfg.get_value("cows", "got", 0))
	s.best_chain = int(cfg.get_value("field", "best_chain", 0))
	s.best_sweep = int(cfg.get_value("field", "best_sweep", 0))
	s.sweeps = int(cfg.get_value("field", "sweeps", 0))
	# a clock set back gives no time, and never takes any
	s.away_secs = maxf(0.0, Time.get_unix_time_from_system() - float(cfg.get_value("field", "stamp", Time.get_unix_time_from_system())))
	# a field kept before crops could wither loses nothing to its first return
	s.away_ripe = s.away(s.away_secs, int(cfg.get_value("field", "ver", 1)) >= 2)
	return s

## The field as the Arcade tab's card reads it, without growing anything.
static func kept() -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return {"earned": 0, "seeds": 0, "plots": 0, "crops": 0}
	var n := 0
	for row: Array in cfg.get_value("field", "plots", []):
		if bool(row[0]):
			n += 1
	return {"earned": int(cfg.get_value("field", "earned", 0)), "seeds": int(cfg.get_value("field", "seeds", 0)), "plots": n,
		"crops": int(cfg.get_value("field", "crops", 1))}
