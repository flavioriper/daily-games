extends RefCounted

## Griddle's stand as pure data: no nodes, no clock of its own (spec
## docs/superpowers/specs/2026-10-12-arcade-griddle-design.md). Four places
## run at once whichever is on the screen:
##
## - the **fields** grow wheat (loaves) and clover (feed) on lots that tire;
## - the **yard**'s cows eat the feed and fill with milk, a cheese each;
## - the **counter** grills a loaf and a cheese into a toastie and sells it
##   to the queue;
## - the **office** holds the signboard's loudness, the town's four moods
##   and the favours that mend them.
##
## Every place works by itself, slowly (a cart, a pail, a cook, a till), and
## a finger does the same thing at once. `step(dt)` takes any `dt`; what
## happened is left in `events` for the screen to play back. Toasties sold
## by hand one soon after another are a **rush**, each link paying more.
##
## Each place has a shortcut that pays now and annoys someone: tonic on a
## lot (the gardeners), scraps in the trough and a crowded barn (the vet),
## the hurry bell (the crew), a loud signboard (the neighbours). A mood that
## reaches the top costs something and settles; nothing ends the game.

const VER := 1
const PLACES := ["fields", "yard", "counter", "office"]

# --- the fields ---
const LOTS := 12
const START_LOTS := 3
const FALLOW := -1
const WHEAT := 0
const CLOVER := 1
## A crop: the seconds it grows and what a lot of it gives on good soil.
const CROPS := [{"id": "wheat", "grow": 18.0, "gives": 3}, {"id": "clover", "grow": 14.0, "gives": 4}]
const SOIL_MAX := 100.0
## What a harvest takes out of a lot's soil, what a resting lot gets back a
## second, and the soil under which a lot is tired.
const WEAR := 1.0
const REST := 0.25
const TIRED := 30.0
## The least a worn lot still gives, as a part of its crop.
const POOR := 0.5
const TONIC_GIVES := 1.5
const TONIC_WEAR := 3.0
## The seconds between two lots the cart takes by itself.
const CART := 8.0
const LARDER := 24
const LARDER_UP := 8

# --- the yard ---
const START_COWS := 1
const START_STALLS := 2
const STALLS_MAX := 6
## How many cows more than its stalls a barn takes, crowded.
const CROWD := 2
## The seconds a cow takes over one feed and over one cheese's milk.
const EAT := 8.0
const SCRAPS_EAT := 12.0
const MILK := 12.0
## The seconds between two cows the pail takes by itself.
const PAIL := 6.0
## The seconds a cow goes unfed before she is poorly, and the seconds she
## lies in once tucked up.
const HUNGRY := 40.0
const TUCK := 25.0
## The chance a cow is poorly as she fills: a floor, more a cow over the
## stalls, more on scraps.
const POORLY := 0.01
const POORLY_CROWD := 0.05
const POORLY_SCRAPS := 0.07

# --- the counter ---
const GRILLS_MAX := 3
const TILLS_MAX := 3
const COOK := 6.0
const SERVE := 9.0
const PASS := 6
const PASS_UP := 2
## The queue's room a till, and the seconds a customer waits.
const QUEUE := 5
const PATIENCE := 40.0
## Seconds between two customers with a quiet signboard and no star.
const FOOTFALL := 9.0
const PRICE := 4.0
## The rush: the seconds a link waits for the next, what a link adds and
## the links past which it adds no more.
const WINDOW := 3.0
const RUSH_STEP := 0.08
const RUSH_CAP := 15
const RUSH_NAMED := [5, 10, 15]
## A queue emptied by one rush of this many or more is a clean counter,
## paid a part of the rush again.
const CLEAN_MIN := 5
const CLEAN_PAYS := 0.25
## The crew's pep: lost a second at work, got back a second at tea, and the
## pep under which they are worn out. Their pace runs from SLOW to 1.
const PEP_MAX := 100.0
const PEP_WORK := 0.25
const PEP_TEA := 6.0
const TEA := 15.0
const WORN := 25.0
const SLOW := 0.5
const BELL := 1.5
const BELL_WEAR := 3.0

# --- the office ---
const MOODS := ["garden", "vet", "crew", "town"]
const MOOD_MAX := 100.0
const MOOD_WARN := 60.0
const MOOD_AFTER := 35.0
## What each mood calms by a minute, and what its grievances add a minute.
const CALM := 2.0
const G_TONIC := 4.0
const G_TIRED := 3.0
const V_SCRAPS := 10.0
const V_CROWD := 5.0
const V_POORLY := 6.0
const C_BELL := 12.0
const C_WORN := 6.0
const VOLUMES := 4
const T_VOLUME := [0.0, 2.0, 8.0, 14.0]
const VOLUME_PULL := 0.35
## What a mood at the top costs: a part of the coins held (the gardeners'
## and the vet's bill), or seconds (the crew's walk, the signboard down).
const BILL := 0.15
const BAN := 120.0
const WALK := 45.0
const HUSH := 120.0
const FAVOUR_CALMS := 50.0
const FAVOUR_WAIT := 60.0
const FAVOUR_UP := 1.25

# --- the stand's name ---
const STARS := [20, 80, 250, 700, 2000, 5000, 12000, 30000, 70000, 150000]
const STAR_NEXT := 2.2
const STAR_PRICE := 0.15
const STAR_PULL := 0.05

## What is bought once or a few times: the first price and what each more
## costs over the last.
const BUYS := {"lot": [25, 1.6], "cow": [40, 1.7], "stall": [60, 1.8], "grill": [250, 10.0], "till": [200, 10.0]}
## What is bought with no top: the first price. Each level is UP dearer.
const UPS := {"seed": 40, "cart": 30, "larder": 50, "churn": 60, "pail": 40, "heat": 60, "tills": 50, "shelf": 45, "recipe": 80, "sign": 70}
const UP := 1.55
const UP_PLACE := {"seed": "fields", "cart": "fields", "larder": "fields", "churn": "yard", "pail": "yard", "heat": "counter", "tills": "counter", "shelf": "counter", "recipe": "office", "sign": "office"}
const SEED_UP := 0.2
const FASTER := 0.9

## The longest time away that is worked out; the larder is full long before.
const AWAY_MAX := 900.0

static var path := "user://griddle.cfg"

var rng := RandomNumberGenerator.new()
var events: Array = []
var clock := 0.0

var coins := 0
var earned := 0
var served := 0
var stars := 0
var lv := {}

## A lot: {open, crop (FALLOW: resting), t (seconds grown), ripe, soil,
## tonic}.
var lots: Array = []
var loaves := 6
var feed := 8
var cheese := 4
var cart_t := 0.0
## Seconds tonic is still refused after the gardeners' complaint.
var ban := 0.0

## A cow: {milk (0 to 1), full, eat (seconds since her last feed), hungry
## (seconds unfed), poorly, rest (seconds still lying in)}.
var cows: Array = []
var stalls := START_STALLS
var scraps := false
var pail_t := 0.0

var grills := 1
var tills := 1
## Each grill's toastie, 0 to 1, and each till's reach for the next.
var cooking: Array = [0.0, 0.0, 0.0]
var serving: Array = [0.0, 0.0, 0.0]
var ready := 0
## Each customer's seconds waited, the front first.
var queue: Array = []
var arrive := 0.0
var pep := PEP_MAX
var tea := 0.0
var bell := false
var walk := 0.0

var volume := 0
var hush := 0.0
var mood := {}
var warned := {}
var favours := {}
var favour_t := {}

var rush := 0
var rush_t := 0.0
var rush_sum := 0
var best_rush := 0
var cleans := 0
var walked := 0
## Today's takings and yesterday's, for the ledger: a day is five minutes.
const DAY := 300.0
var day_t := 0.0
var today := 0
var yesterday := 0

## Nothing sold and no mood moved: the time away.
var shut := false
var away_secs := 0.0
var stamp := 0.0

func _init(rng_seed := 0) -> void:
	if rng_seed != 0:
		rng.seed = rng_seed
	else:
		rng.randomize()
	for id: String in UPS:
		lv[id] = 0
	for m: String in MOODS:
		mood[m] = 0.0
		warned[m] = false
		favours[m] = 0
		favour_t[m] = 0.0
	for i in LOTS:
		lots.append({"open": i < START_LOTS, "crop": [WHEAT, CLOVER, CLOVER][i] if i < START_LOTS else FALLOW, "t": 0.0, "ripe": false, "soil": SOIL_MAX, "tonic": false})
	for k in START_COWS:
		cows.append(_cow())
	stamp = Time.get_unix_time_from_system()

func _cow() -> Dictionary:
	return {"milk": 0.0, "full": false, "eat": 0.0, "hungry": 0.0, "poorly": false, "rest": 0.0}

func _emit(type: String, more := {}) -> void:
	if shut:
		return
	var ev := {"type": type}
	ev.merge(more)
	events.append(ev)

# --- what things are worth ---

func larder() -> int:
	return LARDER + LARDER_UP * int(lv.larder)

func pass_room() -> int:
	return PASS + PASS_UP * int(lv.shelf)

func queue_room() -> int:
	return QUEUE * tills

func opened() -> int:
	var n := 0
	for l: Dictionary in lots:
		if l.open:
			n += 1
	return n

func grow_time(crop: int) -> float:
	return float(CROPS[crop].grow)

## What lot `i` gives when it is cut: its crop, less on worn soil, more
## with better seed and with tonic.
func gives(i: int) -> int:
	var l: Dictionary = lots[i]
	if int(l.crop) == FALLOW:
		return 0
	var n := float(CROPS[l.crop].gives) * lerpf(POOR, 1.0, clampf(float(l.soil) / SOIL_MAX, 0.0, 1.0)) * (1.0 + SEED_UP * int(lv.seed))
	if l.tonic:
		n *= TONIC_GIVES
	return maxi(1, int(round(n)))

func cart_time() -> float:
	return CART * pow(FASTER, int(lv.cart))

func milk_time() -> float:
	return MILK * pow(FASTER, int(lv.churn))

func pail_time() -> float:
	return PAIL * pow(FASTER, int(lv.pail))

func cook_time() -> float:
	return COOK * pow(FASTER, int(lv.heat))

func serve_time() -> float:
	return SERVE * pow(FASTER, int(lv.tills))

func crowded() -> int:
	return maxi(0, cows.size() - stalls)

func cow_room() -> int:
	return stalls + CROWD

## The crew's pace: slower as they wear out, faster under the bell, nothing
## at tea or on a walk.
func pace() -> float:
	if tea > 0.0 or walk > 0.0:
		return 0.0
	return lerpf(SLOW, 1.0, pep / PEP_MAX) * (BELL if bell else 1.0)

func price() -> float:
	return PRICE * (1.0 + 0.1 * int(lv.recipe)) * (1.0 + STAR_PRICE * stars)

## What the next toastie sold by hand would pay.
func link_pay(n: int) -> int:
	return maxi(1, int(round(price() * (1.0 + RUSH_STEP * mini(n - 1, RUSH_CAP)))))

## Customers a second.
func footfall() -> float:
	var f := (1.0 + 0.12 * int(lv.sign)) * (1.0 + VOLUME_PULL * volume) * (1.0 + STAR_PULL * stars) / FOOTFALL
	return f * 0.5 if hush > 0.0 else f

func star_at(n: int) -> int:
	if n < STARS.size():
		return STARS[n]
	return int(round(STARS[-1] * pow(STAR_NEXT, n - STARS.size() + 1)))

func next_star() -> int:
	return star_at(stars)

# --- prices and buying ---

## How many of `what` have been bought past the start.
func _bought(what: String) -> int:
	match what:
		"lot":
			return opened() - START_LOTS
		"cow":
			return cows.size() - START_COWS
		"stall":
			return stalls - START_STALLS
		"grill":
			return grills - 1
		"till":
			return tills - 1
	return 0

## The price of the next `what`, or -1 when no more are to be had.
func buy_price(what: String) -> int:
	match what:
		"lot":
			if opened() >= LOTS:
				return -1
		"cow":
			if cows.size() >= cow_room():
				return -1
		"stall":
			if stalls >= STALLS_MAX:
				return -1
		"grill":
			if grills >= GRILLS_MAX:
				return -1
		"till":
			if tills >= TILLS_MAX:
				return -1
	var row: Array = BUYS[what]
	return int(round(float(row[0]) * pow(float(row[1]), _bought(what))))

func buy(what: String) -> bool:
	var p := buy_price(what)
	if p < 0 or coins < p:
		return false
	coins -= p
	var at := -1
	match what:
		"lot":
			for i in LOTS:
				if not lots[i].open:
					lots[i].open = true
					at = i
					break
		"cow":
			cows.append(_cow())
			at = cows.size() - 1
		"stall":
			stalls += 1
		"grill":
			grills += 1
			at = grills - 1
		"till":
			tills += 1
			at = tills - 1
	_emit("bought", {"what": what, "paid": p, "i": at})
	return true

func up_price(id: String) -> int:
	return int(round(float(UPS[id]) * pow(UP, int(lv[id]))))

func buy_up(id: String) -> bool:
	var p := up_price(id)
	if coins < p:
		return false
	coins -= p
	lv[id] = int(lv[id]) + 1
	_emit("up", {"id": id, "level": int(lv[id]), "paid": p})
	return true

func _pay(n: int) -> void:
	coins += n
	earned += n
	today += n

# --- the fields ---

## Sets what lot `i` grows (FALLOW: it rests). What was growing is lost.
func plant(i: int, crop: int) -> bool:
	var l: Dictionary = lots[i]
	if not l.open or int(l.crop) == crop:
		return false
	l.crop = crop
	l.t = 0.0
	l.ripe = false
	if crop == FALLOW:
		l.tonic = false
	_emit("plant", {"i": i, "crop": crop})
	return true

func set_tonic(i: int, on: bool) -> bool:
	var l: Dictionary = lots[i]
	if not l.open or int(l.crop) == FALLOW or bool(l.tonic) == on or (on and ban > 0.0):
		return false
	l.tonic = on
	_emit("toggle", {"what": "tonic", "on": on, "i": i})
	return true

## Whether the larder has room for what lot `i` grows.
func has_room(i: int) -> bool:
	return (loaves if int(lots[i].crop) == WHEAT else feed) < larder()

## Cuts lot `i` if it is ripe and the larder has room for any of it.
func harvest(i: int, hand := true) -> bool:
	var l: Dictionary = lots[i]
	if not l.open or not l.ripe:
		return false
	if not has_room(i):
		if hand:
			_emit("full", {"i": i, "crop": int(l.crop)})
		return false
	var n := gives(i)
	if int(l.crop) == WHEAT:
		n = mini(n, larder() - loaves)
		loaves += n
	else:
		n = mini(n, larder() - feed)
		feed += n
	var was: float = l.soil
	l.soil = maxf(0.0, float(l.soil) - WEAR * (TONIC_WEAR if l.tonic else 1.0))
	l.ripe = false
	l.t = 0.0
	_emit("harvest", {"i": i, "n": n, "crop": int(l.crop), "hand": hand})
	if was >= TIRED and float(l.soil) < TIRED:
		_emit("tired", {"i": i})
	return true

func ripe_count() -> int:
	var n := 0
	for l: Dictionary in lots:
		if l.open and l.ripe:
			n += 1
	return n

func tired_count() -> int:
	var n := 0
	for l: Dictionary in lots:
		if l.open and int(l.crop) != FALLOW and float(l.soil) < TIRED:
			n += 1
	return n

func tonic_count() -> int:
	var n := 0
	for l: Dictionary in lots:
		if l.open and l.tonic:
			n += 1
	return n

func _step_fields(dt: float) -> void:
	ban = maxf(0.0, ban - dt)
	for i in LOTS:
		var l: Dictionary = lots[i]
		if not l.open:
			continue
		if int(l.crop) == FALLOW:
			l.soil = minf(SOIL_MAX, float(l.soil) + REST * dt)
		elif not l.ripe:
			l.t = float(l.t) + dt
			if float(l.t) >= grow_time(l.crop):
				l.ripe = true
				_emit("ripe", {"i": i})
	cart_t += dt
	if cart_t >= cart_time():
		for i in LOTS:
			if lots[i].open and lots[i].ripe and has_room(i):
				cart_t = 0.0
				harvest(i, false)
				break
		cart_t = minf(cart_t, cart_time())

# --- the yard ---

func set_scraps(on: bool) -> bool:
	if scraps == on:
		return false
	scraps = on
	_emit("toggle", {"what": "scraps", "on": on})
	return true

## Takes a full cow's milk for a cheese, if the larder has room.
func milk(k: int, hand := true) -> bool:
	var c: Dictionary = cows[k]
	if not c.full or c.poorly:
		return false
	if cheese >= larder():
		if hand:
			_emit("full", {"k": k, "crop": -2})
		return false
	c.full = false
	c.milk = 0.0
	cheese += 1
	_emit("milk", {"k": k, "hand": hand})
	return true

## Tucks a poorly cow up: she lies in, and is well after.
func tuck(k: int) -> bool:
	var c: Dictionary = cows[k]
	if not c.poorly or float(c.rest) > 0.0:
		return false
	c.rest = TUCK
	_emit("tuck", {"k": k})
	return true

func full_count() -> int:
	var n := 0
	for c: Dictionary in cows:
		if c.full and not c.poorly:
			n += 1
	return n

## The cows poorly and not yet tucked up.
func poorly_count() -> int:
	var n := 0
	for c: Dictionary in cows:
		if c.poorly and float(c.rest) <= 0.0:
			n += 1
	return n

func _sicken(k: int) -> void:
	cows[k].poorly = true
	cows[k].full = false
	cows[k].milk = 0.0
	_emit("poorly", {"k": k})

func _step_yard(dt: float) -> void:
	var eat := SCRAPS_EAT if scraps else EAT
	for k in cows.size():
		var c: Dictionary = cows[k]
		if c.poorly:
			if float(c.rest) > 0.0:
				c.rest = float(c.rest) - dt
				if float(c.rest) <= 0.0:
					c.poorly = false
					c.rest = 0.0
					c.hungry = 0.0
					_emit("well", {"k": k})
			continue
		# a cow eats as she goes; with nothing in the trough she waits
		c.eat = float(c.eat) + dt
		var fed := true
		if float(c.eat) >= eat:
			if feed > 0:
				feed -= 1
				c.eat = 0.0
				c.hungry = 0.0
			else:
				c.eat = eat
				fed = false
		if not fed:
			c.hungry = float(c.hungry) + dt
			if not shut and float(c.hungry) >= HUNGRY:
				_sicken(k)
			continue
		if not c.full:
			c.milk = float(c.milk) + dt / milk_time()
			if float(c.milk) >= 1.0:
				c.milk = 1.0
				c.full = true
				var risk := POORLY + POORLY_CROWD * crowded() + (POORLY_SCRAPS if scraps else 0.0)
				if not shut and rng.randf() < risk:
					_sicken(k)
				else:
					_emit("filled", {"k": k})
	pail_t += dt
	if pail_t >= pail_time():
		for k in cows.size():
			if cows[k].full and not cows[k].poorly and cheese < larder():
				pail_t = 0.0
				milk(k, false)
				break
		pail_t = minf(pail_t, pail_time())

# --- the counter ---

func set_bell(on: bool) -> bool:
	if bell == on or walk > 0.0:
		return false
	bell = on
	_emit("toggle", {"what": "bell", "on": on})
	return true

## Sends the crew to tea: they stop, and come back with their pep.
func take_tea() -> bool:
	if tea > 0.0 or walk > 0.0 or pep >= PEP_MAX - 1.0:
		return false
	tea = TEA
	_emit("tea", {"on": true})
	return true

## Sells the toastie at the front of the pass to the front of the queue. By
## hand it is a link of the rush.
func serve(hand := true, till := 0) -> bool:
	if ready <= 0 or queue.is_empty():
		if hand:
			_emit("no_serve", {"why": "pass" if ready <= 0 else "queue"})
		return false
	ready -= 1
	queue.pop_front()
	served += 1
	var pay := link_pay(1)
	var n := 0
	if hand:
		rush += 1
		rush_t = WINDOW
		n = rush
		pay = link_pay(rush)
		rush_sum += pay
		best_rush = maxi(best_rush, rush)
	_pay(pay)
	_emit("serve", {"hand": hand, "n": n, "pay": pay, "till": till})
	if hand:
		if rush in RUSH_NAMED:
			_emit("rush", {"n": rush, "tier": RUSH_NAMED.find(rush)})
		if queue.is_empty() and rush >= CLEAN_MIN:
			var bonus := maxi(1, int(round(rush_sum * CLEAN_PAYS)))
			_pay(bonus)
			rush_sum += bonus
			cleans += 1
			_emit("clean", {"n": rush, "bonus": bonus})
	while served >= next_star():
		stars += 1
		_emit("star", {"n": stars})
	return true

func _end_rush() -> void:
	if rush > 0:
		_emit("rush_end", {"n": rush, "sum": rush_sum})
	rush = 0
	rush_sum = 0
	rush_t = 0.0

func _step_counter(dt: float) -> void:
	if rush > 0:
		rush_t -= dt
		if rush_t <= 0.0:
			_end_rush()
	if shut:
		return
	hush = maxf(0.0, hush - dt)
	# the town comes by
	arrive += dt * footfall()
	while arrive >= 1.0:
		arrive -= 1.0
		if queue.size() < queue_room():
			queue.append(0.0)
			_emit("arrive", {"n": queue.size()})
		else:
			walked += 1
			_emit("turned", {})
	var k := 0
	while k < queue.size():
		queue[k] = float(queue[k]) + dt
		if float(queue[k]) >= PATIENCE:
			queue.remove_at(k)
			walked += 1
			_emit("left", {"k": k})
		else:
			k += 1
	# the crew
	if walk > 0.0:
		walk -= dt
		if walk <= 0.0:
			walk = 0.0
			pep = PEP_MAX
			_emit("crew_back", {})
		return
	if tea > 0.0:
		tea -= dt
		pep = minf(PEP_MAX, pep + PEP_TEA * dt)
		if tea <= 0.0:
			tea = 0.0
			_emit("tea", {"on": false})
		return
	var p := pace()
	var worked := false
	for g in grills:
		if float(cooking[g]) <= 0.0:
			# a new one is laid on only with a loaf, a cheese and room for it
			if loaves <= 0 or cheese <= 0 or ready + _on_grills(g) >= pass_room():
				continue
			loaves -= 1
			cheese -= 1
			cooking[g] = 0.0001
		worked = true
		cooking[g] = float(cooking[g]) + dt * p / cook_time()
		if float(cooking[g]) >= 1.0:
			cooking[g] = 0.0
			ready += 1
			_emit("cook", {"g": g})
	for t in tills:
		if ready <= 0 or queue.is_empty():
			serving[t] = 0.0
			continue
		worked = true
		serving[t] = float(serving[t]) + dt * p / serve_time()
		if float(serving[t]) >= 1.0:
			serving[t] = 0.0
			serve(false, t)
	if worked:
		pep = maxf(0.0, pep - PEP_WORK * (BELL_WEAR if bell else 1.0) * dt)

## The toasties on the grills before grill `g`: with those on the pass they
## may not pass its room.
func _on_grills(g: int) -> int:
	var n := 0
	for j in grills:
		if j != g and float(cooking[j]) > 0.0:
			n += 1
	return n

# --- the office ---

func set_volume(v: int) -> bool:
	v = clampi(v, 0, VOLUMES - 1)
	if v == volume or (hush > 0.0 and v > 0):
		return false
	volume = v
	_emit("toggle", {"what": "volume", "on": v > 0, "v": v})
	return true

func favour_price(m: String) -> int:
	return maxi(20, int(round(price() * 10.0 * pow(FAVOUR_UP, int(favours[m])))))

## A favour done for mood `m`: paid for, and the mood calms.
func favour(m: String) -> bool:
	var p := favour_price(m)
	if coins < p or float(favour_t[m]) > 0.0 or float(mood[m]) < 1.0:
		return false
	coins -= p
	favours[m] = int(favours[m]) + 1
	favour_t[m] = FAVOUR_WAIT
	mood[m] = maxf(0.0, float(mood[m]) - FAVOUR_CALMS)
	if float(mood[m]) < MOOD_WARN:
		warned[m] = false
	_emit("favour", {"m": m, "paid": p})
	return true

## What mood `m` rises by a minute as things stand, before it calms.
func grief(m: String) -> float:
	match m:
		"garden":
			return G_TONIC * tonic_count() + G_TIRED * tired_count()
		"vet":
			return (V_SCRAPS if scraps else 0.0) + V_CROWD * crowded() + V_POORLY * poorly_count()
		"crew":
			return (C_BELL if bell else 0.0) + (C_WORN if pep < WORN and tea <= 0.0 and walk <= 0.0 else 0.0)
		"town":
			return float(T_VOLUME[volume])
	return 0.0

func _step_office(dt: float) -> void:
	if shut:
		return
	for m: String in MOODS:
		favour_t[m] = maxf(0.0, float(favour_t[m]) - dt)
		mood[m] = clampf(float(mood[m]) + (grief(m) - CALM) * dt / 60.0, 0.0, MOOD_MAX)
		if float(mood[m]) >= MOOD_MAX:
			_boil(m)
		elif float(mood[m]) >= MOOD_WARN and not warned[m]:
			warned[m] = true
			_emit("warn", {"m": m})
		elif float(mood[m]) < MOOD_WARN - 10.0:
			warned[m] = false
	day_t += dt
	if day_t >= DAY:
		day_t -= DAY
		yesterday = today
		today = 0
		_emit("day", {"took": yesterday})

## A mood at the top: its price, and it settles.
func _boil(m: String) -> void:
	mood[m] = MOOD_AFTER
	warned[m] = false
	var bill := 0
	match m:
		"garden":
			bill = int(round(coins * BILL))
			ban = BAN
			for l: Dictionary in lots:
				l.tonic = false
		"vet":
			bill = int(round(coins * BILL))
			scraps = false
			for c: Dictionary in cows:
				if not c.poorly:
					c.poorly = true
					c.full = false
					c.milk = 0.0
				c.rest = TUCK
		"crew":
			walk = WALK
			bell = false
			tea = 0.0
		"town":
			volume = 0
			hush = HUSH
	coins -= bill
	_emit("boil", {"m": m, "bill": bill})

# --- what needs a hand ---

## How much place `p` wants looking at: 0 nothing, 1 something waits, 2 it
## is going wrong.
func alarm(p: String) -> int:
	match p:
		"fields":
			if loaves <= 0 or feed <= 0 or tired_count() > 0:
				return 2
			return 1 if ripe_count() >= 2 else 0
		"yard":
			if poorly_count() > 0 or (feed <= 0 and not cows.is_empty()):
				return 2
			return 1 if full_count() >= 2 else 0
		"counter":
			if walk > 0.0 or (pep < WORN and tea <= 0.0) or queue.size() >= queue_room():
				return 2
			return 1 if ready >= 3 and queue.size() >= 3 else 0
		"office":
			for m: String in MOODS:
				if float(mood[m]) >= MOOD_WARN:
					return 2
	return 0

# --- time ---

func step(dt: float) -> void:
	clock += dt
	stamp = Time.get_unix_time_from_system()
	# a long frame is taken in pieces, so nothing skips its turn
	var left := dt
	while left > 0.0:
		var d := minf(left, 0.25)
		left -= d
		_step_fields(d)
		_step_yard(d)
		_step_counter(d)
		_step_office(d)

## The time the game was shut: the fields and the yard went on into the
## larder, the stand was closed and nobody minded anything. Returns what
## came into the larder.
func away(seconds: float) -> int:
	var before := loaves + feed + cheese
	shut = true
	var left := minf(seconds, AWAY_MAX)
	while left > 0.0:
		var d := minf(left, 1.0)
		left -= d
		_step_fields(d)
		_step_yard(d)
	shut = false
	stamp = Time.get_unix_time_from_system()
	return loaves + feed + cheese - before

# --- kept ---

## Writes the stand to `path`; a harness that must leave no file sets it to "".
func save() -> void:
	if path == "":
		return
	var cfg := ConfigFile.new()
	var rows := []
	for l: Dictionary in lots:
		rows.append([l.open, int(l.crop), float(l.t), l.ripe, float(l.soil), l.tonic])
	var herd := []
	for c: Dictionary in cows:
		herd.append([float(c.milk), c.full, c.poorly, float(c.rest)])
	cfg.set_value("stand", "ver", VER)
	cfg.set_value("stand", "coins", coins)
	cfg.set_value("stand", "earned", earned)
	cfg.set_value("stand", "served", served)
	cfg.set_value("stand", "stars", stars)
	cfg.set_value("stand", "lv", lv)
	cfg.set_value("stand", "best_rush", best_rush)
	cfg.set_value("stand", "cleans", cleans)
	cfg.set_value("stand", "stamp", Time.get_unix_time_from_system())
	cfg.set_value("fields", "lots", rows)
	cfg.set_value("fields", "larder", [loaves, feed, cheese])
	cfg.set_value("yard", "cows", herd)
	cfg.set_value("yard", "stalls", stalls)
	cfg.set_value("yard", "scraps", scraps)
	cfg.set_value("counter", "grills", grills)
	cfg.set_value("counter", "tills", tills)
	cfg.set_value("counter", "ready", ready)
	cfg.set_value("counter", "pep", pep)
	cfg.set_value("counter", "bell", bell)
	cfg.set_value("office", "volume", volume)
	cfg.set_value("office", "mood", mood)
	cfg.set_value("office", "favours", favours)
	cfg.save(path)

## The kept stand, with the time away worked in; a new one with nothing kept.
static func load_saved(rng_seed := 0) -> RefCounted:
	var s = new(rng_seed)
	var cfg := ConfigFile.new()
	if path == "" or cfg.load(path) != OK:
		return s
	s.coins = int(cfg.get_value("stand", "coins", 0))
	s.earned = int(cfg.get_value("stand", "earned", 0))
	s.served = int(cfg.get_value("stand", "served", 0))
	s.stars = int(cfg.get_value("stand", "stars", 0))
	s.best_rush = int(cfg.get_value("stand", "best_rush", 0))
	s.cleans = int(cfg.get_value("stand", "cleans", 0))
	var levels: Dictionary = cfg.get_value("stand", "lv", {})
	for id: String in UPS:
		s.lv[id] = maxi(0, int(levels.get(id, 0)))
	var rows: Array = cfg.get_value("fields", "lots", [])
	for i in mini(rows.size(), LOTS):
		var r: Array = rows[i]
		s.lots[i] = {"open": bool(r[0]), "crop": clampi(int(r[1]), FALLOW, CROPS.size() - 1), "t": float(r[2]), "ripe": bool(r[3]), "soil": clampf(float(r[4]), 0.0, SOIL_MAX), "tonic": bool(r[5])}
	var held: Array = cfg.get_value("fields", "larder", [6, 8, 4])
	s.loaves = int(held[0])
	s.feed = int(held[1])
	s.cheese = int(held[2])
	s.stalls = clampi(int(cfg.get_value("yard", "stalls", START_STALLS)), START_STALLS, STALLS_MAX)
	var herd: Array = cfg.get_value("yard", "cows", [])
	if not herd.is_empty():
		s.cows.clear()
		for r: Array in herd:
			var c: Dictionary = s._cow()
			c.milk = float(r[0])
			c.full = bool(r[1])
			c.poorly = bool(r[2])
			c.rest = float(r[3])
			s.cows.append(c)
	s.scraps = bool(cfg.get_value("yard", "scraps", false))
	s.grills = clampi(int(cfg.get_value("counter", "grills", 1)), 1, GRILLS_MAX)
	s.tills = clampi(int(cfg.get_value("counter", "tills", 1)), 1, TILLS_MAX)
	s.ready = int(cfg.get_value("counter", "ready", 0))
	s.pep = clampf(float(cfg.get_value("counter", "pep", PEP_MAX)), 0.0, PEP_MAX)
	s.bell = bool(cfg.get_value("counter", "bell", false))
	s.volume = clampi(int(cfg.get_value("office", "volume", 0)), 0, VOLUMES - 1)
	var moods: Dictionary = cfg.get_value("office", "mood", {})
	var done: Dictionary = cfg.get_value("office", "favours", {})
	for m: String in MOODS:
		s.mood[m] = clampf(float(moods.get(m, 0.0)), 0.0, MOOD_MAX - 1.0)
		s.favours[m] = int(done.get(m, 0))
	s.away_secs = maxf(0.0, Time.get_unix_time_from_system() - float(cfg.get_value("stand", "stamp", Time.get_unix_time_from_system())))
	s.away(s.away_secs)
	return s

## The stand as the Arcade tab's card reads it, without running anything.
static func kept() -> Dictionary:
	var cfg := ConfigFile.new()
	if path == "" or cfg.load(path) != OK:
		return {"served": 0, "stars": 0, "coins": 0}
	return {"served": int(cfg.get_value("stand", "served", 0)), "stars": int(cfg.get_value("stand", "stars", 0)), "coins": int(cfg.get_value("stand", "coins", 0))}
