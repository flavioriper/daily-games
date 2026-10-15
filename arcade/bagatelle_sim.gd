extends RefCounted

## Bagatelle's board as pure data: no nodes, no clock of its own (spec
## docs/superpowers/specs/2026-10-15-arcade-bagatelle-design.md). A board
## W wide and H tall in field units: staggered rows of brass pins, a
## dropper gliding along the top, seven cups along the foot. Marbles fall
## through the pins one by one (they never touch each other), each a circle
## against the pins' circles at fixed steps of STEP seconds with a seeded
## scatter, so a seed replays.
##
## The jar holds every marble owned, by tier (`owned`, `jar`): a drop takes
## the best one the jar holds, a landing rolls it back. A landing pays
## value × worth(tier) × the cup's multiplier × the marble's pin bonus ×
## polish in coins, and a point to its cup, which goes up a level at
## `need(lv)` points. Coins buy the run's four upgrades; a cash out turns
## the run's coins into stars, kept for ever, which buy the star shop.
##
## Coins, worth and prices are floats: a coin count passes int64 well
## before the twelfth tier. Actions return whether they did anything;
## `events` is for the holder to drain. `step(dt)` takes any `dt`.

const VER := 1
const W := 1000.0
const H := 1000.0
const STEP := 1.0 / 120.0
## The pins: ROWS rows from ROW_Y0, DY apart; even rows ACROSS pins at the
## half steps, odd rows ACROSS - 1 between them.
const ROWS := 12
const ACROSS := 13
const DX := W / ACROSS
const ROW_Y0 := 150.0
const DY := 60.0
const PIN_R := 8.0
const BALL_R := 17.0
## Where a marble is let go, and where it is in a cup.
const DROP_Y := 60.0
const CUP_TOP := 880.0
const LAND_Y := 925.0
const CUPS := 7
const CUP_W := W / CUPS
const CUP_BASE := [5.0, 2.0, 1.0, 0.5, 1.0, 2.0, 5.0]
const CUP_STEP := 0.1
## The physics: gravity, how much of a blow's speed comes back, the scatter
## a pin adds along its face, the fastest a marble falls.
const GRAVITY := 2800.0
const BOUNCE := 0.2
const SLIDE := 0.9
const SCATTER := 45.0
const FASTEST := 1500.0
const SIDEWAYS := 260.0
## A blow's sideways kick, and how often it goes against the side struck.
const KICK_LO := 170.0
const KICK_HI := 250.0
const LEAN_OFF := 0.4
## The walls' push back in, and how long a marble may rest before a nudge.
const WALL_KICK := 120.0
const STILL := 0.25
## A tap's across is kept within the middle band (the spec's call 2: a tap
## at the wall would feed the edge cup all day).
const AIM_LO := 0.36
const AIM_HI := 0.64
## The dropper's glide.
const GLIDE := 0.55
const GLIDE_SPAN := 0.14

## The tiers: ten of one merge into one of the next; tier k is worth WORTH^k.
const TIERS := 12
const MERGE := 10
const WORTH := 20.0
const TIER_IDS := ["clay", "glass", "agate", "swirl", "cats_eye", "opal", "moonstone", "pearl", "ember", "frost", "comet", "star"]

## The run's upgrades: first price, growth, and the most ranks (0: no top).
const UPS := ["marbles", "value", "auto", "weight"]
const UP_FIRST := {"marbles": 6.0, "value": 12.0, "auto": 25.0, "weight": 60.0}
const UP_GROWTH := {"marbles": 1.1, "value": 1.2, "auto": 1.3, "weight": 1.45}
const UP_TOP := {"marbles": 0, "value": 0, "auto": 40, "weight": 25}
const START_MARBLES := 3
const AUTO_FIRST := 2.4
const AUTO_STEP := 0.9
const AUTO_LEAST := 0.1
const WEIGHT_STEP := 0.12

## The star shop: each rank's price in stars, in order.
const SHOP := ["plus", "times", "polish", "jar", "finer", "twins", "warm", "shine"]
const SHOP_PRICES := {
	"plus": [2, 5, 12, 30, 75],
	"times": [10, 40, 150],
	"polish": [5, 10, 20, 40, 80, 160, 320, 640, 1280, 2560],
	"jar": [1, 3, 8, 20, 50],
	"finer": [20, 80, 300, 1000, 3000, 9000],
	"twins": [4, 10, 25, 60, 150],
	"warm": [3, 8, 20, 50, 120],
	"shine": [5, 15, 40, 100, 250],
}
const PLUS := 0.5
const TIMES := 2.0
const POLISH := 1.25
const JAR_STEP := 3
const TWIN_STEP := 0.2
const WARM_STEP := 5
const SHINE_STEP := 0.25
## A cash out: stars = floor((log10(earned) - STAR_FROM)^STAR_POW × shine),
## so a run of 1e5 coins pays one, 1e8 thirty-two, 1e15 four hundred: the
## tiers multiply coins by twenty and the stars must not follow them.
const STAR_FROM := 3.7
const STAR_POW := 2.5
## Every coin is worth 1 + STAR_BONUS × sqrt(stars ever earned): the stars
## always count, and the root keeps cash outs from doubling each other.
const STAR_BONUS := 0.1
## Where bonus pins stand on a new board, in the order they are bought.
const PLUS_AT := [Vector2i(3, 6), Vector2i(5, 6), Vector2i(4, 3), Vector2i(7, 9), Vector2i(8, 4)]
const TIMES_AT := [Vector2i(6, 6), Vector2i(2, 9), Vector2i(10, 9)]

static var path := "user://bagatelle.cfg"

var rng := RandomNumberGenerator.new()
var seed_v := 0
var t := 0.0
var events: Array = []
## The marbles in the air: {p, v, tier, boost, seen (pin ids), id}.
var balls: Array = []
## The jar, a tier an entry: marbles owned and marbles in the jar.
var owned := PackedInt64Array()
var jar := PackedInt64Array()
var coins := 0.0
## This run's coins, and every coin ever.
var earned := 0.0
var lifetime := 0.0
var up := {}
var cup_lv := PackedInt32Array()
var cup_pts := PackedInt32Array()
## When each pin was last touched (t), for its halo.
var glow := PackedFloat32Array()
## Bonus pins: pin id -> "plus" or "times".
var bonus := {}
var stars := 0
var stars_ever := 0
var cashouts := 0
var shop := {}
var best_tier := 0
var drops := 0
var landed := 0
## Pins touched since the holder last read them, and the lowest row one was on.
var pin_hits := 0
var pin_row := 0
var _acc := 0.0
var _auto_t := 0.0
var _next_id := 0
var _could := {}

func _init(rng_seed := 0) -> void:
	seed_v = rng_seed if rng_seed != 0 else int(Time.get_unix_time_from_system()) & 0x7fffffff
	rng.seed = seed_v
	owned.resize(TIERS)
	jar.resize(TIERS)
	cup_lv.resize(CUPS)
	cup_pts.resize(CUPS)
	glow.resize(ROWS * ACROSS)
	glow.fill(-10.0)
	for id: String in UPS:
		up[id] = 0
	for id: String in SHOP:
		shop[id] = 0
	_new_run()

func _new_run() -> void:
	balls.clear()
	coins = 0.0
	earned = 0.0
	for id: String in UPS:
		up[id] = 0
	owned.fill(0)
	jar.fill(0)
	owned[0] = START_MARBLES + JAR_STEP * int(shop.jar)
	jar[0] = owned[0]
	cup_lv.fill(WARM_STEP * int(shop.warm))
	cup_pts.fill(0)
	_auto_t = 0.0
	_place_bonus()
	for id: String in UPS:
		_could[id] = false

func _say(ev: Dictionary) -> void:
	events.append(ev)

# --- the board ---

## The pins in row `r`.
static func row_count(r: int) -> int:
	return ACROSS if r % 2 == 0 else ACROSS - 1

## Whether row `r` has a pin at `i`: the wide rows' two outermost places
## stand closer to the walls than a marble is wide, and are left bare.
static func has_pin(r: int, i: int) -> bool:
	if r < 0 or r >= ROWS or i < 0 or i >= row_count(r):
		return false
	return not (r % 2 == 0 and (i == 0 or i == ACROSS - 1))

static func pin_id(r: int, i: int) -> int:
	return r * ACROSS + i

static func pin_rc(id: int) -> Vector2i:
	@warning_ignore("integer_division")
	return Vector2i(id % ACROSS, id / ACROSS)

static func pin_at(r: int, i: int) -> Vector2:
	var x := (float(i) + 0.5) * DX if r % 2 == 0 else (float(i) + 1.0) * DX
	return Vector2(x, ROW_Y0 + DY * r)

static func pin_pos(id: int) -> Vector2:
	var rc := pin_rc(id)
	return pin_at(rc.y, rc.x)

static func is_pin(id: int) -> bool:
	var rc := pin_rc(id)
	return id >= 0 and has_pin(rc.y, rc.x)

## The pin nearest `p` within `reach`, or -1.
static func pin_near(p: Vector2, reach := DX * 0.5) -> int:
	var best := -1
	var bd := reach
	var r0 := clampi(int(round((p.y - ROW_Y0) / DY)) - 1, 0, ROWS - 1)
	for r in range(r0, mini(r0 + 3, ROWS)):
		for i in row_count(r):
			if not has_pin(r, i):
				continue
			var d := pin_at(r, i).distance_to(p)
			if d < bd:
				bd = d
				best = pin_id(r, i)
	return best

static func cup_of(x: float) -> int:
	return clampi(int(x / CUP_W), 0, CUPS - 1)

## Where the dropper is at time `at`.
static func dropper_x(at: float) -> float:
	return W * (0.5 + GLIDE_SPAN * sin(at * GLIDE))

# --- figures ---

static func worth(tier: int) -> float:
	return pow(WORTH, tier)

static func need(lv: int) -> int:
	return int(ceil(6.0 * pow(1.08, lv)))

func cup_mult(c: int) -> float:
	return float(CUP_BASE[c]) * (1.0 + CUP_STEP * cup_lv[c])

func value() -> float:
	return float(1 + int(up.value))

func polish() -> float:
	return pow(POLISH, int(shop.polish)) * star_bonus()

func star_bonus() -> float:
	return 1.0 + STAR_BONUS * sqrt(float(stars_ever))

func auto_every() -> float:
	var n := int(up.auto)
	if n <= 0:
		return 0.0
	return maxf(AUTO_LEAST, AUTO_FIRST * pow(AUTO_STEP, n - 1))

func gravity() -> float:
	return GRAVITY * (1.0 + WEIGHT_STEP * int(up.weight))

func twin_chance() -> float:
	return TWIN_STEP * int(shop.twins)

func price(id: String, n := -1) -> float:
	var k: int = int(up[id]) if n < 0 else n
	return floor(float(UP_FIRST[id]) * pow(float(UP_GROWTH[id]), k))

func up_top(id: String) -> bool:
	return int(UP_TOP[id]) > 0 and int(up[id]) >= int(UP_TOP[id])

func can_buy(id: String) -> bool:
	return not up_top(id) and coins >= price(id)

func any_ready() -> bool:
	for id: String in UPS:
		if can_buy(id):
			return true
	return false

## How many ranks of `id` the coins buy at once, and what they cost.
func max_buy(id: String) -> Vector2:
	var n := 0
	var cost := 0.0
	var k := int(up[id])
	while true:
		if int(UP_TOP[id]) > 0 and k + n >= int(UP_TOP[id]):
			break
		var p := price(id, k + n)
		if cost + p > coins:
			break
		cost += p
		n += 1
		if n >= 1000:
			break
	return Vector2(n, cost)

## Buys `times` ranks of `id` (0: as many as the coins cover). The ranks bought.
func buy(id: String, times := 1) -> int:
	var n := 0
	while (times <= 0 or n < times) and can_buy(id):
		coins -= price(id)
		up[id] = int(up[id]) + 1
		if id == "marbles":
			var k := int(shop.finer)
			owned[k] += 1
			jar[k] += 1
			_note_tier(k)
		n += 1
		if n >= 1000:
			break
	if n > 0:
		_say({"type": "upgrade", "id": id, "level": int(up[id]), "n": n})
		_could[id] = can_buy(id)
	return n

func stars_for(e := -1.0) -> int:
	var v := earned if e < 0.0 else e
	if v < 10.0:
		return 0
	var d := log(v) / log(10.0) - STAR_FROM
	if d <= 0.0:
		return 0
	return int(floor(pow(d, STAR_POW) * (1.0 + SHINE_STEP * int(shop.shine))))

## Coins this run still short of the next star.
func next_star_at() -> float:
	var s := stars_for() + 1
	var k := 1.0 + SHINE_STEP * int(shop.shine)
	return pow(10.0, STAR_FROM + pow(float(s) / k, 1.0 / STAR_POW))

func can_cash_out() -> bool:
	return stars_for() >= 1

func cash_out() -> int:
	var s := stars_for()
	if s < 1:
		return 0
	stars += s
	stars_ever += s
	cashouts += 1
	_say({"type": "cashout", "stars": s})
	_new_run()
	return s

func shop_top(id: String) -> bool:
	return int(shop[id]) >= (SHOP_PRICES[id] as Array).size()

func shop_price(id: String) -> int:
	if shop_top(id):
		return 0
	return int(SHOP_PRICES[id][int(shop[id])])

func can_shop(id: String) -> bool:
	return not shop_top(id) and stars >= shop_price(id)

func shop_buy(id: String) -> bool:
	if not can_shop(id):
		return false
	stars -= shop_price(id)
	shop[id] = int(shop[id]) + 1
	match id:
		"jar":
			owned[0] += JAR_STEP
			jar[0] += JAR_STEP
		"plus", "times":
			_place_bonus()
		"warm":
			for c in CUPS:
				cup_lv[c] = maxi(cup_lv[c], WARM_STEP * int(shop.warm))
	_say({"type": "shop", "id": id, "level": int(shop[id])})
	return true

## Bonus pins the shop has given and not yet stood somewhere: put on the
## first free places in PLUS_AT / TIMES_AT (or any free pin).
func _place_bonus() -> void:
	for kind: String in ["plus", "times"]:
		var have := 0
		for id: int in bonus:
			if bonus[id] == kind:
				have += 1
		var want := int(shop[kind])
		var spots: Array = PLUS_AT if kind == "plus" else TIMES_AT
		var j := 0
		while have < want:
			var id := -1
			while j < spots.size() and id < 0:
				var rc: Vector2i = spots[j]
				j += 1
				var c := pin_id(rc.y, rc.x)
				if is_pin(c) and not bonus.has(c):
					id = c
			if id < 0:
				for c in ROWS * ACROSS:
					if is_pin(c) and not bonus.has(c):
						id = c
						break
			if id < 0:
				break
			bonus[id] = kind
			have += 1

## Carries a bonus pin to another pin. False when either is not right.
func move_bonus(from: int, to: int) -> bool:
	if not bonus.has(from) or not is_pin(to) or from == to or bonus.has(to):
		return false
	bonus[to] = bonus[from]
	bonus.erase(from)
	_say({"type": "moved", "from": from, "to": to})
	return true

# --- the jar ---

func in_jar() -> int:
	var n := 0
	for k in TIERS:
		n += jar[k]
	return n

func owned_all() -> int:
	var n := 0
	for k in TIERS:
		n += owned[k]
	return n

## Merges ten of tier `k` in the jar into one of the next, `times` times
## (0: as many as the jar holds). The merges made.
func merge(k: int, times := 1) -> int:
	if k < 0 or k >= TIERS - 1:
		return 0
	var n := 0
	while (times <= 0 or n < times) and jar[k] >= MERGE:
		jar[k] -= MERGE
		owned[k] -= MERGE
		jar[k + 1] += 1
		owned[k + 1] += 1
		n += 1
	if n > 0:
		_say({"type": "merge", "tier": k + 1, "n": n})
		_note_tier(k + 1)
	return n

## Every tier merged up as far as the jar allows, lowest first.
func merge_all() -> int:
	var n := 0
	for k in TIERS - 1:
		n += merge(k, 0)
	return n

func _note_tier(k: int) -> void:
	if k > best_tier:
		best_tier = k
		_say({"type": "tier", "tier": k})

## The best tier the jar holds, or -1.
func best_in_jar() -> int:
	for k in range(TIERS - 1, -1, -1):
		if jar[k] > 0:
			return k
	return -1

# --- dropping ---

## A marble let go at `x` (kept in the middle band when `aimed`). False when
## the jar is empty.
func drop(x: float, aimed := true) -> bool:
	var k := best_in_jar()
	if k < 0:
		_say({"type": "empty"})
		return false
	var at := clampf(x, W * AIM_LO, W * AIM_HI) if aimed else clampf(x, BALL_R, W - BALL_R)
	_let(k, at, aimed)
	if twin_chance() > 0.0 and rng.randf() < twin_chance():
		var k2 := best_in_jar()
		if k2 >= 0:
			_let(k2, clampf(at + rng.randf_range(-24.0, 24.0), BALL_R, W - BALL_R), aimed)
	return true

func _let(k: int, x: float, aimed := true) -> void:
	jar[k] -= 1
	_next_id += 1
	balls.append({"p": Vector2(x, DROP_Y), "v": Vector2(rng.randf_range(-20.0, 20.0), 0.0), "tier": k, "boost": 1.0, "seen": [], "id": _next_id})
	drops += 1
	_say({"type": "drop", "x": x, "tier": k, "aimed": aimed})

# --- the frame ---

func step(dt: float) -> void:
	_acc += minf(dt, 0.25)
	while _acc >= STEP:
		_acc -= STEP
		_tick()

func _tick() -> void:
	t += STEP
	var every := auto_every()
	if every > 0.0:
		_auto_t += STEP
		if _auto_t >= every:
			_auto_t -= every
			if in_jar() > 0:
				drop(dropper_x(t), false)
	var g := gravity()
	var i := 0
	while i < balls.size():
		var b: Dictionary = balls[i]
		if _move(b, g):
			_land(b)
			balls.remove_at(i)
		else:
			i += 1
	for id: String in UPS:
		var now := can_buy(id)
		if now and not bool(_could.get(id, false)):
			_say({"type": "ready", "id": id})
		_could[id] = now

## Moves one marble a step. True when it is in a cup.
func _move(b: Dictionary, g: float) -> bool:
	var v: Vector2 = b.v
	var p: Vector2 = b.p
	v.y += g * STEP
	if v.length() > FASTEST:
		v = v.normalized() * FASTEST
	p += v * STEP
	var reach := PIN_R + BALL_R
	var r := int(round((p.y - ROW_Y0) / DY))
	if r >= 0 and r < ROWS and absf(p.y - (ROW_Y0 + DY * r)) < reach:
		var n := row_count(r)
		var off := 0.5 if r % 2 == 0 else 1.0
		var ci := int(round(p.x / DX - off))
		for i in range(ci - 1, ci + 2):
			if i < 0 or i >= n or not has_pin(r, i):
				continue
			var c := pin_at(r, i)
			var d := p - c
			var dl := d.length()
			if dl >= reach or dl < 0.001:
				continue
			var nrm := d / dl
			p = c + nrm * reach
			var vn := v.dot(nrm)
			if vn < 0.0:
				var tan := Vector2(-nrm.y, nrm.x)
				# the scatter is a blow's, not a roll's: rolling round a pin
				# it adds nothing, or it walks the marble off to the walls
				var vt := v.dot(tan) * SLIDE + (rng.randf_range(-SCATTER, SCATTER) if vn < -90.0 else 0.0)
				# a marble resting on a pin's crown is tipped off it
				if absf(vt) < 25.0:
					vt = 25.0 if rng.randf() < 0.5 else -25.0
				v = tan * vt - nrm * vn * BOUNCE
				# a blow sends the marble left or right afresh, a little more
				# often the way it struck: no drift is carried from row to
				# row, so the cups fall out as a pin board's do (the middle
				# busiest), and a marble never rides a diagonal to the wall
				if vn < -90.0:
					var side := signf(d.x) if absf(d.x) > 1.0 else (1.0 if rng.randf() < 0.5 else -1.0)
					if rng.randf() < LEAN_OFF:
						side = -side
					v.x = side * rng.randf_range(KICK_LO, KICK_HI)
				var id := pin_id(r, i)
				glow[id] = t
				pin_hits += 1
				pin_row = maxi(pin_row, r)
				if bonus.has(id) and not (b.seen as Array).has(id):
					(b.seen as Array).append(id)
					if bonus[id] == "plus":
						b.boost = float(b.boost) + PLUS
					else:
						b.boost = float(b.boost) * TIMES
					_say({"type": "bonus", "pin": id, "kind": bonus[id], "id": b.id})
	# a marble drifts across only so fast: the pins send it left or right a
	# little, never flying (what keeps the middle cups the busy ones)
	v.x = clampf(v.x, -SIDEWAYS, SIDEWAYS)
	# the walls send a marble back in (an edge pin stands closer to the wall
	# than a marble is wide, so it must go over the pin, not beside it)
	if p.x < BALL_R:
		p.x = BALL_R
		v.x = maxf(absf(v.x) * BOUNCE, WALL_KICK)
	elif p.x > W - BALL_R:
		p.x = W - BALL_R
		v.x = -maxf(absf(v.x) * BOUNCE, WALL_KICK)
	# a marble come to rest on the pins is tipped toward the middle
	if v.length_squared() < 40.0 * 40.0:
		b.still = float(b.get("still", 0.0)) + STEP
		if float(b.still) > STILL:
			v = Vector2(signf(W * 0.5 - p.x) * KICK_HI, -60.0)
			b.still = 0.0
	else:
		b.still = 0.0
	b.p = p
	b.v = v
	return p.y >= LAND_Y

func _land(b: Dictionary) -> void:
	var c := cup_of((b.p as Vector2).x)
	var k := int(b.tier)
	jar[k] += 1
	var pay := value() * worth(k) * cup_mult(c) * float(b.boost) * polish()
	coins += pay
	earned += pay
	lifetime += pay
	landed += 1
	cup_pts[c] += 1
	_say({"type": "land", "cup": c, "pay": pay, "tier": k, "x": (b.p as Vector2).x, "boost": float(b.boost)})
	if cup_pts[c] >= need(cup_lv[c]):
		cup_pts[c] -= need(cup_lv[c])
		cup_lv[c] += 1
		_say({"type": "cup", "cup": c, "level": cup_lv[c]})

## Takes the pins touched since the last read: [count, lowest row].
func take_pins() -> Vector2i:
	var out := Vector2i(pin_hits, pin_row)
	pin_hits = 0
	pin_row = 0
	return out

## A number as the plates say it: whole to 999, then 12.4K, 3.1M ... and
## past the names, 1.2e36.
static func short(v: float) -> String:
	var a := absf(v)
	var neg := "-" if v < 0.0 else ""
	if a < 10.0 and not is_equal_approx(a, floor(a)):
		return neg + String.num(floorf(a * 10.0) / 10.0, 1).trim_suffix(".0")
	if a < 1000.0:
		return neg + str(int(floor(a)))
	var names := ["K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc"]
	var e := int(floor(log(a) / log(1000.0)))
	if e > names.size():
		var p := int(floor(log(a) / log(10.0)))
		return neg + String.num(a / pow(10.0, p), 1) + "e" + str(p)
	var x := a / pow(1000.0, e)
	if x >= 999.95:
		x = 999.0
	var s := str(int(x)) if x >= 100.0 else String.num(floorf(x * 10.0) / 10.0, 1).trim_suffix(".0")
	return neg + s + String(names[e - 1])

# --- kept ---

func save() -> void:
	if path == "":
		return
	var cfg := ConfigFile.new()
	cfg.set_value("board", "ver", VER)
	cfg.set_value("board", "seed", seed_v)
	cfg.set_value("board", "coins", coins)
	cfg.set_value("board", "earned", earned)
	cfg.set_value("board", "lifetime", lifetime)
	cfg.set_value("board", "up", up)
	# marbles in the air go back to the jar
	var o := owned.duplicate()
	cfg.set_value("board", "owned", o)
	cfg.set_value("board", "cup_lv", cup_lv)
	cfg.set_value("board", "cup_pts", cup_pts)
	var bkeys := PackedInt32Array()
	var bkinds := PackedStringArray()
	for id: int in bonus:
		bkeys.append(id)
		bkinds.append(String(bonus[id]))
	cfg.set_value("board", "bonus_at", bkeys)
	cfg.set_value("board", "bonus_kind", bkinds)
	cfg.set_value("stars", "stars", stars)
	cfg.set_value("stars", "ever", stars_ever)
	cfg.set_value("stars", "cashouts", cashouts)
	cfg.set_value("stars", "shop", shop)
	cfg.set_value("stars", "best_tier", best_tier)
	cfg.set_value("stars", "drops", drops)
	cfg.save(path)

static func load_saved(rng_seed := 0) -> RefCounted:
	var cfg := ConfigFile.new()
	if path == "" or cfg.load(path) != OK:
		return new(rng_seed)
	var s = new(int(cfg.get_value("board", "seed", rng_seed)))
	var sh: Dictionary = cfg.get_value("stars", "shop", {})
	for id: String in SHOP:
		s.shop[id] = clampi(int(sh.get(id, 0)), 0, (SHOP_PRICES[id] as Array).size())
	s.stars = maxi(0, int(cfg.get_value("stars", "stars", 0)))
	s.stars_ever = maxi(s.stars, int(cfg.get_value("stars", "ever", 0)))
	s.cashouts = maxi(0, int(cfg.get_value("stars", "cashouts", 0)))
	s.best_tier = clampi(int(cfg.get_value("stars", "best_tier", 0)), 0, TIERS - 1)
	s.drops = maxi(0, int(cfg.get_value("stars", "drops", 0)))
	s.coins = maxf(0.0, float(cfg.get_value("board", "coins", 0.0)))
	s.earned = maxf(0.0, float(cfg.get_value("board", "earned", 0.0)))
	s.lifetime = maxf(s.earned, float(cfg.get_value("board", "lifetime", 0.0)))
	var u: Dictionary = cfg.get_value("board", "up", {})
	for id: String in UPS:
		var top := int(UP_TOP[id])
		s.up[id] = maxi(0, int(u.get(id, 0))) if top <= 0 else clampi(int(u.get(id, 0)), 0, top)
	var o: PackedInt64Array = cfg.get_value("board", "owned", PackedInt64Array())
	if o.size() == TIERS:
		for k in TIERS:
			s.owned[k] = maxi(0, o[k])
			s.jar[k] = s.owned[k]
	if s.owned_all() <= 0:
		s.owned[0] = START_MARBLES
		s.jar[0] = START_MARBLES
	var lv: PackedInt32Array = cfg.get_value("board", "cup_lv", PackedInt32Array())
	var pts: PackedInt32Array = cfg.get_value("board", "cup_pts", PackedInt32Array())
	for c in CUPS:
		if c < lv.size():
			s.cup_lv[c] = maxi(0, lv[c])
		if c < pts.size():
			s.cup_pts[c] = maxi(0, pts[c])
	s.bonus = {}
	var bk: PackedInt32Array = cfg.get_value("board", "bonus_at", PackedInt32Array())
	var bn: PackedStringArray = cfg.get_value("board", "bonus_kind", PackedStringArray())
	var counts := {"plus": 0, "times": 0}
	for j in mini(bk.size(), bn.size()):
		var kind := bn[j]
		if is_pin(bk[j]) and counts.has(kind) and int(counts[kind]) < int(s.shop[kind]) and not s.bonus.has(bk[j]):
			s.bonus[bk[j]] = kind
			counts[kind] = int(counts[kind]) + 1
	s._place_bonus()
	for id: String in UPS:
		s._could[id] = s.can_buy(id)
	return s

## The board as the Arcade tab's card reads it, without running anything.
static func kept() -> Dictionary:
	var cfg := ConfigFile.new()
	if path == "" or cfg.load(path) != OK:
		return {"new": true, "stars": 0, "tier": 0}
	return {"new": false, "stars": int(cfg.get_value("stars", "ever", 0)), "tier": int(cfg.get_value("stars", "best_tier", 0))}
