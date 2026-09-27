extends RefCounted

## Henhouse as pure data (spec
## docs/superpowers/specs/2026-09-27-arcade-henhouse-design.md): an egg farm
## run from one hen to retirement. A pen of hens on top, fed from a feed
## silo on the right and a water tank on the left; a conveyor belt along
## the bottom carrying eggs through a washer, a stamp and a packer to the
## crate, where they sell. The screen (arcade/henhouse_screen.gd) steps this
## at the fixed DT, hands it the finger (grab, hold, release, pet, refill,
## buy) and drains `events`.
##
## After the idle-clicker family of egg farms: buy hens, keep them fed and
## watered or they stop laying and are lost, drag the eggs to market, stroke
## the hens to make them lay faster, then buy the belt, the machines and the
## squirrels that do it all for you, a rooster for chicks (which eat twice as
## much and can be put to sleep), and retire on a million.

enum Phase { READY, PLAY, OVER }
enum Kind { HEN, CHICK }
enum Egg { GROUND, HELD, BELT, CARRIED }

const DT := 1.0 / 30.0
## The field in its own units: the pen on top, the belt along the bottom.
const W := 360.0
const H := 400.0
## Where the hens may walk.
const PEN := Rect2(56.0, 44.0, 248.0, 234.0)
## The fence round the pen, drawn a little outside it.
const FENCE := Rect2(40.0, 24.0, 280.0, 272.0)
## The water tank on the left of the pen and the feed silo on the right;
## a tap on either refills it.
const TANK := Rect2(8.0, 80.0, 28.0, 150.0)
const SILO := Rect2(324.0, 80.0, 28.0, 150.0)
const BELT_Y := 336.0
const BELT_HALF := 13.0
const BELT_X0 := 14.0
const CRATE := Rect2(296.0, 306.0, 58.0, 62.0)
const BELT_SPEED := 60.0
## Where each machine stands over the belt.
const MACHINE_X := {"washer": 104.0, "stamp": 170.0, "packer": 236.0}
const READY_TIME := 1.4
const START_MONEY := 20.0
const MAX_FLOCK := 30
const EGG_CAP := 45
const LAY_TIME := 5.0
const HEN_SPEED := 16.0
const CHICK_SPEED := 22.0
## Feed and water, per bird per second (a chick awake takes twice), and the
## price of a unit. The troughs grow with the flock, so a refill lasts.
const EAT := 0.5
const DRINK := 0.6
const FEED_PRICE := 0.10
const WATER_PRICE := 0.06
const LOW := 0.25
## A trough dry this long loses a hen, and then another every STARVE_EACH.
const STARVE := 20.0
const STARVE_EACH := 8.0
const PET_RADIUS := 26.0
const HAPPY_DECAY := 0.022
const HAPPY_DECAY_RADIO := 0.012
const RADIO_BOOST := 1.25
const BASE_VALUE := 2.0
const FEED_MULT := 2.0
const FEED_PRICE_MULT := 1.35
const WASH_MULT := 1.5
const STAMP_MULT := 2.0
const PACK_MULT := 3.0
const GOLD_MULT := 10.0
const GOLD_CHANCE := 0.03
const FERTILE_CHANCE := 0.3
const HATCH_TIME := 10.0
const GROW_TIME := 40.0
const BASKET_N := 6
const GRAB_RADIUS := 17.0
const BASKET_RADIUS := 30.0
const SQUIRREL_SPEED := 95.0
const SQUIRREL_CARRY := 5
const SQUIRREL_HOME := Vector2(30.0, 380.0)
const RETIRE := 1000000
## What the shop sells: each has a tab, and a price read by price().
const FARM := ["hen", "rooster", "radio", "feed", "auto_feed", "auto_water"]
const FACTORY := ["belt", "basket", "squirrel", "washer", "stamp", "packer"]
const FLAT := {"rooster": 600, "radio": 400, "auto_feed": 250, "auto_water": 250,
	"belt": 30, "basket": 80, "washer": 120, "stamp": 1000, "packer": 8000}
const FEED_COSTS := [100, 600, 4000, 25000, 120000]
const SQUIRREL_COSTS := [200, 2500, 25000]
const NAMES := ["Zebra", "Pip", "Nugget", "Pearl", "Dot", "Biscuit", "Clover", "Maple", "Olive", "Poppy",
	"Hazel", "Daisy", "Pepper", "Mabel", "Tilly", "Rosie", "Ginger", "Juniper", "Button", "Willow",
	"Peanut", "Fern", "Bramble", "Honey", "Sprout", "Marigold", "Pickle", "Waffle", "Plum", "Bean"]

var rng := RandomNumberGenerator.new()
var phase := Phase.READY
var phase_t := 0.0
## Seconds played.
var t := 0.0
var won := false
var money := START_MONEY
var earned := 0.0
var feed := 0.0
var water := 0.0
var hens: Array = []      # {id, kind, pos, to, rest, happy, lay, grow, asleep, name, face, peck}
var eggs: Array = []      # {id, st, pos, gold, fertile, washed, stamped, boxed, age}
var squirrels: Array = [] # {pos, st, target, carry: Array, face}
var rooster := {}         # {pos, to, rest, face} once bought
var owned := {}           # item -> level (0 or absent: not owned)
var hens_bought := 0
var events: Array = []
var sold := 0
var golds := 0
var hatched := 0
var lost := 0
var petted := 0.0
var best_flock := 1
var starve_t := 0.0
var _next_id := 1
var _low_warned := {"feed": false, "water": false}
var _names_used := 0

func _init(seed_value := -1) -> void:
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	feed = cap()
	water = cap()
	_add_hen(Kind.HEN, PEN.get_center())
	events.clear()
	events.append({"type": "ready"})

func is_over() -> bool:
	return phase == Phase.OVER

func flock() -> int:
	return hens.size()

func adults() -> int:
	var n := 0
	for h: Dictionary in hens:
		if h.kind == Kind.HEN:
			n += 1
	return n

## How much a trough holds: more as the flock grows, so a refill lasts.
func cap() -> float:
	return 100.0 + 15.0 * hens.size()

func level(item: String) -> int:
	return int(owned.get(item, 0))

func has(item: String) -> bool:
	return level(item) > 0

## The price of a unit of feed, dearer with every grade of feed.
func feed_price() -> float:
	return FEED_PRICE * pow(FEED_PRICE_MULT, level("feed"))

func refill_cost(which: String) -> int:
	var lack := cap() - (feed if which == "feed" else water)
	var unit := feed_price() if which == "feed" else WATER_PRICE
	return maxi(1, int(ceilf(lack * unit)))

## What an item costs now, or -1 when it cannot be bought (owned, or at its
## last level, or the pen is full).
func price(item: String) -> int:
	match item:
		"hen":
			if hens.size() >= MAX_FLOCK:
				return -1
			return int(round(10.0 * pow(1.2, hens_bought)))
		"feed":
			var lv := level("feed")
			return FEED_COSTS[lv] if lv < FEED_COSTS.size() else -1
		"squirrel":
			var lv := level("squirrel")
			return SQUIRREL_COSTS[lv] if lv < SQUIRREL_COSTS.size() else -1
		"retire":
			return RETIRE
	if has(item):
		return -1
	return int(FLAT.get(item, -1))

func max_level(item: String) -> int:
	match item:
		"hen":
			return MAX_FLOCK
		"feed":
			return FEED_COSTS.size()
		"squirrel":
			return SQUIRREL_COSTS.size()
	return 1

## Buys an item; false when it cannot be bought or afforded.
func buy(item: String) -> bool:
	if phase != Phase.PLAY:
		return false
	var p := price(item)
	if p < 0 or money < p:
		events.append({"type": "refused", "item": item, "price": p})
		return false
	money -= p
	match item:
		"hen":
			hens_bought += 1
			var at := PEN.position + PEN.size * Vector2(rng.randf_range(0.15, 0.85), rng.randf_range(0.2, 0.8))
			_add_hen(Kind.HEN, at)
		"rooster":
			owned[item] = 1
			rooster = {"pos": Vector2(PEN.get_center().x, PEN.position.y + 10.0), "to": PEN.get_center(), "rest": 0.0, "face": 1.0, "crow": 0.0}
		"squirrel":
			owned[item] = level(item) + 1
			squirrels.append({"pos": SQUIRREL_HOME + Vector2(squirrels.size() * 14.0, 0), "st": "home", "target": -1, "carry": [], "face": 1.0})
		"retire":
			won = true
			phase = Phase.OVER
			phase_t = 0.0
			events.append({"type": "bought", "item": item})
			events.append({"type": "retire"})
			return true
		_:
			owned[item] = level(item) + 1
	events.append({"type": "bought", "item": item, "level": level(item)})
	return true

## Tops a trough up to the brim; false when the money is short.
func refill(which: String) -> bool:
	if phase != Phase.PLAY:
		return false
	var c := refill_cost(which)
	if (feed if which == "feed" else water) >= cap() - 0.5:
		return false
	if money < c:
		events.append({"type": "refused", "item": which, "price": c})
		return false
	money -= c
	if which == "feed":
		feed = cap()
	else:
		water = cap()
	_low_warned[which] = false
	events.append({"type": "refill", "which": which, "cost": c})
	return true

func _add_hen(kind: int, at: Vector2) -> Dictionary:
	var h := {"id": _next_id, "kind": kind, "pos": _in_pen(at), "to": _in_pen(at), "rest": rng.randf_range(0.2, 1.5),
		"happy": 0.0, "lay": LAY_TIME * rng.randf_range(0.4, 0.9), "grow": 0.0, "asleep": false,
		"name": NAMES[_names_used % NAMES.size()], "face": 1.0 if rng.randf() < 0.5 else -1.0, "peck": 0.0, "hungry": false}
	_names_used += 1
	_next_id += 1
	hens.append(h)
	best_flock = maxi(best_flock, hens.size())
	events.append({"type": "hen", "id": h.id, "kind": kind, "name": h.name})
	return h

static func _in_pen(p: Vector2) -> Vector2:
	return Vector2(clampf(p.x, PEN.position.x, PEN.end.x), clampf(p.y, PEN.position.y, PEN.end.y))

func step() -> void:
	phase_t += DT
	match phase:
		Phase.READY:
			_walk(DT)
			if phase_t >= READY_TIME:
				phase = Phase.PLAY
				phase_t = 0.0
				events.append({"type": "go"})
		Phase.PLAY:
			t += DT
			_troughs(DT)
			_walk(DT)
			_lay(DT)
			_eggs(DT)
			_squirrels(DT)
			_closed()
		Phase.OVER:
			_walk(DT)

func _troughs(dt: float) -> void:
	var mouths := 0.0
	for h: Dictionary in hens:
		if h.kind == Kind.CHICK:
			mouths += 0.0 if h.asleep else 2.0
		else:
			mouths += 1.0
	if not rooster.is_empty():
		mouths += 1.0
	feed = maxf(0.0, feed - mouths * EAT * dt)
	water = maxf(0.0, water - mouths * DRINK * dt)
	for which in ["feed", "water"]:
		var lv: float = feed if which == "feed" else water
		if lv < cap() * LOW:
			if has("auto_" + which) and money >= refill_cost(which):
				refill(which)
			elif not _low_warned[which]:
				_low_warned[which] = true
				events.append({"type": "low", "which": which})
	if feed <= 0.0 or water <= 0.0:
		var was := starve_t
		starve_t += dt
		if was == 0.0:
			events.append({"type": "starving"})
		if starve_t >= STARVE and hens.size() > 0:
			starve_t = STARVE - STARVE_EACH
			# The weakest goes first: a chick, else the least happy hen.
			var pick := 0
			for i in hens.size():
				var a: Dictionary = hens[i]
				var b: Dictionary = hens[pick]
				if (a.kind == Kind.CHICK and b.kind != Kind.CHICK) or (a.kind == b.kind and a.happy < b.happy):
					pick = i
			var gone: Dictionary = hens[pick]
			hens.remove_at(pick)
			lost += 1
			events.append({"type": "lost", "id": gone.id, "pos": gone.pos, "name": gone.name})
	else:
		starve_t = 0.0

func hungry() -> bool:
	return feed <= 0.0 or water <= 0.0

func _walk(dt: float) -> void:
	for h: Dictionary in hens:
		h.peck = maxf(0.0, h.peck - dt)
		h.happy = maxf(0.0, h.happy - (HAPPY_DECAY_RADIO if has("radio") else HAPPY_DECAY) * dt)
		if h.kind == Kind.CHICK:
			if h.asleep:
				continue
			if phase == Phase.PLAY and not hungry():
				h.grow += dt / GROW_TIME
				if h.grow >= 1.0:
					h.kind = Kind.HEN
					h.grow = 1.0
					h.lay = LAY_TIME * rng.randf_range(0.5, 1.0)
					events.append({"type": "grown", "id": h.id, "pos": h.pos, "name": h.name})
		_wander(h, dt, CHICK_SPEED if h.kind == Kind.CHICK else HEN_SPEED)
	if not rooster.is_empty():
		_wander(rooster, dt, HEN_SPEED * 1.1)
		rooster.crow = maxf(0.0, rooster.crow - dt)

## A bird walks to its spot, stands a moment (pecking now and then) and
## picks another.
func _wander(h: Dictionary, dt: float, speed: float) -> void:
	var d: Vector2 = h.to - h.pos
	if d.length() < 1.5:
		h.rest -= dt
		if h.rest <= 0.0:
			var reach := 70.0
			h.to = _in_pen(h.pos + Vector2(rng.randf_range(-reach, reach), rng.randf_range(-reach * 0.7, reach * 0.7)))
			h.rest = rng.randf_range(0.6, 2.6)
			if h.has("peck") and rng.randf() < 0.5:
				h.peck = 0.5
		return
	var go := d.normalized() * minf(d.length(), speed * dt * (0.6 if hungry() else 1.0))
	h.pos += go
	if absf(go.x) > 0.05:
		h.face = signf(go.x)

func lay_rate(h: Dictionary) -> float:
	return (1.0 + h.happy) * (RADIO_BOOST if has("radio") else 1.0)

func _lay(dt: float) -> void:
	if hungry():
		return
	var on_ground := 0
	for e: Dictionary in eggs:
		if e.st == Egg.GROUND:
			on_ground += 1
	for h: Dictionary in hens:
		if h.kind != Kind.HEN:
			continue
		h.lay -= dt * lay_rate(h)
		if h.lay > 0.0:
			continue
		h.lay = LAY_TIME * rng.randf_range(0.8, 1.2)
		if on_ground >= EGG_CAP:
			continue
		on_ground += 1
		var gold := rng.randf() < GOLD_CHANCE
		var fertile := not gold and has("rooster") and rng.randf() < FERTILE_CHANCE
		var e := {"id": _next_id, "st": Egg.GROUND, "pos": _in_pen(h.pos + Vector2(-h.face * 6.0, 4.0)), "gold": gold, "fertile": fertile,
			"washed": false, "stamped": false, "boxed": false, "age": 0.0}
		_next_id += 1
		eggs.append(e)
		events.append({"type": "lay", "id": e.id, "hen": h.id, "pos": e.pos, "gold": gold, "fertile": fertile})

func _eggs(dt: float) -> void:
	var keep: Array = []
	for e: Dictionary in eggs:
		e.age += dt
		match int(e.st):
			Egg.GROUND:
				# A fertile egg left lying hatches, while the pen has room.
				if e.fertile and e.age >= HATCH_TIME and hens.size() < MAX_FLOCK:
					hatched += 1
					var chick := _add_hen(Kind.CHICK, e.pos)
					events.append({"type": "hatch", "id": chick.id, "pos": e.pos})
					continue
			Egg.BELT:
				var x0: float = e.pos.x
				e.pos.x += BELT_SPEED * dt
				for m: String in MACHINE_X:
					var mx: float = MACHINE_X[m]
					if has(m) and x0 < mx and e.pos.x >= mx:
						match m:
							"washer":
								e.washed = true
							"stamp":
								e.stamped = true
							"packer":
								e.boxed = true
						events.append({"type": m, "id": e.id, "pos": Vector2(mx, BELT_Y)})
				if e.pos.x >= CRATE.position.x + 10.0:
					_sell(e, e.pos)
					continue
		keep.append(e)
	eggs = keep

func value(e: Dictionary) -> float:
	var v := BASE_VALUE * pow(FEED_MULT, level("feed"))
	if e.washed:
		v *= WASH_MULT
	if e.stamped:
		v *= STAMP_MULT
	if e.boxed:
		v *= PACK_MULT
	if e.gold:
		v *= GOLD_MULT
	return v

func _sell(e: Dictionary, at: Vector2) -> void:
	var v := value(e)
	money += v
	earned += v
	sold += 1
	if e.gold:
		golds += 1
	events.append({"type": "sell", "id": e.id, "pos": at, "value": v, "gold": e.gold, "boxed": e.boxed})

# --- the finger ---

## Picks up the egg under a finger (with the basket, every egg near it, up
## to BASKET_N). Returns the ids taken.
func grab(at: Vector2) -> Array:
	if phase != Phase.PLAY:
		return []
	var r := BASKET_RADIUS if has("basket") else GRAB_RADIUS
	var near: Array = []
	for e: Dictionary in eggs:
		if e.st == Egg.GROUND or e.st == Egg.BELT:
			var d: float = (e.pos - at).length()
			if d <= r:
				near.append([d, e])
	near.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var n := BASKET_N if has("basket") else 1
	var ids: Array = []
	for k in mini(n, near.size()):
		var e: Dictionary = near[k][1]
		e.st = Egg.HELD
		ids.append(e.id)
	if not ids.is_empty():
		events.append({"type": "pick", "n": ids.size()})
	return ids

## The held eggs follow the finger, in a little heap.
func hold_at(ids: Array, at: Vector2) -> void:
	var k := 0
	for e: Dictionary in eggs:
		if e.st == Egg.HELD and ids.has(e.id):
			e.pos = at + _heap(k)
			k += 1

static func _heap(k: int) -> Vector2:
	if k == 0:
		return Vector2.ZERO
	var a := k * 2.4
	return Vector2(cos(a), sin(a) * 0.7) * (5.0 + k * 1.5)

func over_crate(at: Vector2) -> bool:
	return CRATE.grow(10.0).has_point(at)

func over_belt(at: Vector2) -> bool:
	return has("belt") and at.y > BELT_Y - BELT_HALF - 12.0 and at.y < BELT_Y + BELT_HALF + 12.0 and at.x < CRATE.position.x + 4.0 and at.x > BELT_X0 - 6.0

## Lets go of the held eggs: sold at the crate, laid on the belt (it
## carries them on), or set back down in the pen.
func release(ids: Array, at: Vector2) -> String:
	var where := "pen"
	if over_crate(at):
		where = "crate"
	elif over_belt(at):
		where = "belt"
	var keep: Array = []
	var k := 0
	for e: Dictionary in eggs:
		if e.st != Egg.HELD or not ids.has(e.id):
			keep.append(e)
			continue
		match where:
			"crate":
				_sell(e, at)
				continue
			"belt":
				e.st = Egg.BELT
				e.pos = Vector2(clampf(at.x - k * 9.0, BELT_X0, CRATE.position.x - 4.0), BELT_Y + (k % 3 - 1) * 4.0)
			_:
				e.st = Egg.GROUND
				e.pos = _in_pen(e.pos)
		k += 1
		keep.append(e)
	eggs = keep
	if where != "crate":
		events.append({"type": "drop", "where": where})
	return where

## A finger stroking the pen: every hen it passes over grows happier, the
## more the further it moved. Returns the ids of the hens it touched.
func pet(at: Vector2, moved: float) -> Array:
	if phase != Phase.PLAY:
		return []
	var touched: Array = []
	for h: Dictionary in hens:
		if h.kind == Kind.HEN and (h.pos + Vector2(0, -12.0) - at).length() <= PET_RADIUS:
			var was: float = h.happy
			h.happy = minf(1.0, h.happy + moved * 0.012)
			petted += h.happy - was
			touched.append(h.id)
	return touched

## A tap on a chick puts it to sleep, or wakes it. Returns the chick's id
## or -1.
func tap_chick(at: Vector2) -> int:
	for h: Dictionary in hens:
		if h.kind == Kind.CHICK and (h.pos + Vector2(0, -7.0) - at).length() <= 16.0:
			h.asleep = not h.asleep
			events.append({"type": "sleep" if h.asleep else "wake", "id": h.id, "pos": h.pos})
			return h.id
	return -1

func hen_by_id(id: int) -> Dictionary:
	for h: Dictionary in hens:
		if h.id == id:
			return h
	return {}

# --- squirrels ---

func _squirrels(dt: float) -> void:
	var taken := {}
	for s: Dictionary in squirrels:
		if s.target >= 0:
			taken[s.target] = true
	for s: Dictionary in squirrels:
		match String(s.st):
			"home", "fetch":
				if s.st == "home" and not _move(s, SQUIRREL_HOME, dt):
					pass
				var e := _egg_for(s, taken)
				if e.is_empty():
					if s.carry.is_empty():
						s.st = "home"
						s.target = -1
					else:
						s.st = "drop"
					continue
				s.st = "fetch"
				s.target = e.id
				taken[e.id] = true
				if _move(s, e.pos, dt):
					e.st = Egg.CARRIED
					s.carry.append(e.id)
					s.target = -1
					taken.erase(e.id)
					if s.carry.size() >= SQUIRREL_CARRY:
						s.st = "drop"
			"drop":
				var spot := Vector2(clampf(s.pos.x, BELT_X0 + 10.0, 84.0), BELT_Y - 2.0)
				if _move(s, spot, dt):
					var k := 0
					for e: Dictionary in eggs:
						if e.st == Egg.CARRIED and s.carry.has(e.id):
							if has("belt"):
								e.st = Egg.BELT
								e.pos = Vector2(spot.x - k * 9.0 + 12.0, BELT_Y + (k % 3 - 1) * 4.0)
							else:
								e.st = Egg.GROUND
								e.pos = _in_pen(spot)
							k += 1
					s.carry.clear()
					s.st = "home"
					events.append({"type": "squirrel_drop", "pos": spot})
		# carried eggs ride on the squirrel's back
		var k2 := 0
		for e: Dictionary in eggs:
			if e.st == Egg.CARRIED and s.carry.has(e.id):
				# a little heap on its back, two across
				e.pos = s.pos + Vector2(-s.face * 3.0 + (k2 % 2) * 5.0 - 2.5, -11.0 - int(k2 / 2) * 4.5)
				k2 += 1

## The nearest egg on the ground no other squirrel is after; a squirrel
## leaves a fertile egg to hatch while the pen has room, and never fetches
## without the belt to put it on.
func _egg_for(s: Dictionary, taken: Dictionary) -> Dictionary:
	if not has("belt") or s.carry.size() >= SQUIRREL_CARRY:
		return {}
	if s.target >= 0:
		for e: Dictionary in eggs:
			if e.id == s.target and e.st == Egg.GROUND:
				return e
	var best := {}
	var best_d := INF
	for e: Dictionary in eggs:
		if e.st != Egg.GROUND or taken.has(e.id):
			continue
		if e.fertile and hens.size() < MAX_FLOCK:
			continue
		var d: float = (e.pos - s.pos).length_squared()
		if d < best_d:
			best_d = d
			best = e
	# once carrying, only a near egg is worth the detour
	if not s.carry.is_empty() and best_d > 60.0 * 60.0:
		return {}
	return best

## Steps a squirrel toward a point; true once there.
func _move(s: Dictionary, to: Vector2, dt: float) -> bool:
	var d: Vector2 = to - s.pos
	var reach := SQUIRREL_SPEED * dt
	if d.length() <= reach:
		s.pos = to
		return true
	s.pos += d.normalized() * reach
	if absf(d.x) > 0.5:
		s.face = signf(d.x)
	return false

## The farm closes when the last hen is gone and nothing left could buy
## another.
func _closed() -> void:
	if not hens.is_empty():
		return
	var worth := money
	for e: Dictionary in eggs:
		worth += value(e)
	if worth < price("hen"):
		phase = Phase.OVER
		phase_t = 0.0
		events.append({"type": "closed"})
