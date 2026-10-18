extends RefCounted

## Bagatelle's board as pure data: no nodes, no clock of its own (spec
## docs/superpowers/specs/2026-10-15-arcade-bagatelle-design.md, and the
## user's progression sheet of 2026-10-18, which every figure below copies).
## A board W wide and H tall in field units: staggered rows of brass pins, a
## dropper gliding along the top, five cups along the foot. Marbles fall
## through the pins one by one (they never touch each other), each a circle
## against the pins' circles at fixed steps of STEP seconds with a seeded
## scatter, so a seed replays.
##
## The jar holds every marble owned, by tier (`owned`, `jar`): a drop takes
## the best one the jar holds, a landing rolls it back. **Every marble
## comes out of the dropper**: it glides over the middle band on its own
## and nothing moves it; a tap, Drop and Auto each let a marble go from
## wherever it stands (`drop`, `drop_here`). Auto lets one marble go every
## `auto_every()` seconds; at most MAX_AIR are in the air at once. Brass
## fins stand between the cups: a marble always lands inside one.
##
## **Four layers, each resetting the ones under it** (2026-10-18, the
## user's sheet: "everything should be redo to match the spec"):
##
## - the run: coins buy the five upgrades, a level at a time off fixed
##   tables (`UP_LEVELS`, `UP_PRICES`); a landing pays coins and gives its
##   cup xp, and a cup's multiplier is its base + CUP_STEP a level;
## - a cash out turns the run's coins into shop points (SP), which buy the
##   shop's five items;
## - an investment spends every SP and takes the run and the shop back to
##   nothing, for something kept (bonus pegs, ×10 xp, twice the marbles ...);
##   one at a time, in order, each opening the next;
## - an ascend, once the tenth investment is made, takes the investments too
##   and gives one ascend point, which buys a level of one of four stats.
##
## Coins, worth and prices are floats: a coin count passes int64 well
## before the top tier. Actions return whether they did anything; `events`
## is for the holder to drain. `step(dt)` takes any `dt`.

const VER := 2
const W := 1000.0
const H := 1150.0
const STEP := 1.0 / 120.0
## The pins: ROWS rows from ROW_Y0, DY apart; even rows ACROSS pins at the
## half steps, odd rows ACROSS - 1 between them.
const ROWS := 13
const ACROSS := 13
const DX := W / ACROSS
const ROW_Y0 := 150.0
const DY := 62.0
const PIN_R := 8.0
const BALL_R := 17.0
## Where a marble is let go, and where it is in a cup.
const DROP_Y := 60.0
## A marble is let go inside the dropper's barrel, above its mouth at
## DROP_Y, and is seen falling out of it.
const SPAWN_Y := DROP_Y - 30.0
const CUP_TOP := 1030.0
const LAND_Y := 1075.0
## Five cups, as the reference's shots have (seven until 2026-10-18).
const CUPS := 5
const CUP_W := W / CUPS
## The fins between the cups: half a fin's width, and where they start.
const FIN_W := 5.0
const FIN_TOP := 982.0
## The most marbles in the air at once; the rest wait in the jar.
const MAX_AIR := 60
## A cup pays its base + CUP_STEP a level: read off the reference's shots,
## where every cup's ×figure is exactly that (LV 118 ×25.1 at an edge,
## LV 217 ×44.2 in the middle).
const CUP_BASE := [1.5, 1.0, 0.8, 1.0, 1.5]
const CUP_STEP := 0.2
## A cup's xp to its next level: NEED_FIRST × NEED_GROWTH^level +
## NEED_STEP a level, so every level asks more than the one before (the
## user, 2026-10-18: "XP for upgrade cup must increase at each level, not
## flat"; the growth alone read 5, 6, 6, 6, 6, 6, 7 ...).
const NEED_FIRST := 5.0
const NEED_GROWTH := 1.035
const NEED_STEP := 2.0
## The physics: gravity, how much of a blow's speed comes back, the scatter
## a pin adds along its face, the fastest a marble falls.
const GRAVITY := 3000.0
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
## The dropper's glide (radians a second of its sway, and how far), and
## the least time between two marbles a finger lets go (Auto has none: its
## fastest levels let one go every 0.04 s and faster).
const GLIDE := 0.55
const GLIDE_SPAN := 0.14
const RELEASE_GAP := 0.07
## The most marbles Auto lets go in one step.
const AUTO_BURST := 4

## The tiers: ten of one merge into one of the next, worth ten times as much
## (the reference's Unify: Base, Tier I ×10, Tier II ×100 ... Tier XV).
const TIERS := 16
const MERGE := 10
const WORTH := 10.0
const TIER_IDS := ["clay", "glass", "agate", "swirl", "cats_eye", "opal", "moonstone", "pearl", "ember", "frost", "comet", "star", "aurora", "nova", "eclipse", "sun"]

## The run's five upgrades. Level n of each is UP_LEVELS[id][n], bought for
## UP_PRICES[id][n] coins (level 0 is where a run starts). Levels past
## BASE_TOP open with the eighth investment (the sheet says "5 more upgrade
## tier" and lists four: the four are what is built).
const UPS := ["marbles", "value", "auto", "weight", "xp"]
const UP_LEVELS := {
	"marbles": [1, 2, 3, 5, 8, 12, 20, 40, 80, 150, 300, 450, 1200, 1800, 2800],
	"value": [1, 2, 5, 10, 20, 50, 100, 200, 500, 1000, 3000, 1e4, 7.5e4, 2e5, 5e5],
	"auto": [3.5, 2.5, 1.8, 1.3, 0.9, 0.6, 0.3, 0.25, 0.2, 0.15, 0.12, 0.1, 0.06, 0.05, 0.04],
	"weight": [1.0, 1.3, 1.6, 2.0, 2.5, 3.0, 4.0, 5.0, 6.5, 8.0, 9.0, 10.0, 14.0, 16.0, 20.0],
	"xp": [1, 2, 4, 7, 12, 20, 35, 75, 150, 350, 600, 1000, 4000, 8000, 16000],
}
const UP_PRICES := {
	"marbles": [0, 10, 30, 180, 800, 3500, 1.6e4, 2.5e5, 1.5e6, 9e6, 5.5e7, 4e8, 1.5e10, 9e10, 5.5e11],
	"value": [0, 2, 15, 150, 1500, 6000, 2.2e4, 3.5e5, 2e6, 1.2e7, 8e7, 6e8, 2.5e10, 1.5e11, 9e11],
	"auto": [0, 30, 80, 500, 1900, 7000, 2.8e4, 4e5, 2.5e6, 1.5e7, 1e8, 7.5e8, 2.8e10, 1.7e11, 1e12],
	"weight": [0, 10, 35, 200, 1000, 3700, 1.5e4, 2.3e5, 1.4e6, 8.5e6, 5.5e7, 4e8, 1.4e10, 8.5e10, 5e11],
	"xp": [0, 25, 70, 500, 1900, 7000, 2.4e4, 3.6e5, 2.2e6, 1.3e7, 7.5e7, 5.5e8, 2.2e10, 1.3e11, 8e11],
}
const BASE_TOP := 10
const MEGA_TOP := 14

## The shop, bought with SP: level n of each is SHOP_LEVELS[id][n - 1], for
## SHOP_PRICES[id][n - 1]. "mega" (the merged marbles' worth) opens with
## the seventh investment. More balls is off the tables: BALLS_STEP marble
## a level for BALLS_PRICE SP each, as many as are bought (the user,
## 2026-10-18: "the more balls upgrade has a flat 1 star cost and is
## uncaped, player can buy as many he wants"; the sheet's was 5 levels).
const SHOP := ["xp", "balls", "drop", "bonus", "mega"]
const BALLS_STEP := 1
const BALLS_PRICE := 1.0
const SHOP_LEVELS := {
	"xp": [2.0, 3.0, 5.0, 8.0, 10.0],
	"drop": [2.0, 4.0, 6.0, 8.0, 10.0],
	"bonus": [1.5, 2.0, 3.0, 4.0, 5.0],
	"mega": [2.0, 4.0, 6.0, 8.0, 10.0],
}
const SHOP_PRICES := {
	"xp": [1, 3, 8, 20, 45],
	"drop": [2, 5, 12, 28, 65],
	"bonus": [2, 5, 12, 30, 80],
	"mega": [500, 1500, 4000, 10000, 25000],
}
## A cash out: SP = floor(sqrt(coins / SP_DIV)) × the SP multipliers, from
## the coins held (the reference's card reads "CURRENT COINS": a coin spent
## on an upgrade is a coin not cashed). The reference's card works out to
## SP_DIV 2e4 (4.87B coins, +2.5K SP under the ×5 investment, 19.74M to the
## next); with it the probe's bot made all ten investments in 78 minutes,
## so it is 1e7 here: a first cash out at about ten minutes, the first
## investment at 35, the fifth at 2.7 hours and the tenth at 3.8.
const SP_DIV := 1e7
const SP_POW := 0.5
## The probe's knobs for a sweep (tests/_probe_bagatelle.gd -- seed
## minutes x div pow); the game never sets them.
static var sp_div := SP_DIV
static var sp_pow := SP_POW

## The investments, in order: id and SP price. Each spends every SP.
const INVEST := ["peg", "times_peg", "mega_xp", "double", "sp_boost", "mega_peg", "mega_shop", "mega_up", "auto_cash", "ult_peg"]
const INVEST_PRICES := [30, 60, 130, 280, 600, 1300, 2800, 6000, 13000, 30000]
## What they give: a peg's kind (each one peg on the board), ×10 xp, ×2
## marbles, ×5 SP, and the auto cash out's share of a cash out a second
## (the sheet: "+10% cashout passive sec").
const INVEST_PEG := {"peg": "plus", "times_peg": "times", "mega_peg": "mega", "ult_peg": "ult"}
const MEGA_XP := 10.0
const DOUBLE := 2
const SP_BOOST := 5.0
const AUTO_CASH := 0.1
## The bonus pegs: what one adds to a marble's value, or multiplies it by,
## the first time it is touched. The adds count before the multipliers.
const PEG_ADD := {"plus": 10.0, "mega": 100.0}
const PEG_MUL := {"times": 2.0, "ult": 5.0}
const PEG_KINDS := ["plus", "times", "mega", "ult"]
## Where each peg stands on a new board.
const PEG_AT := {"plus": Vector2i(6, 4), "times": Vector2i(5, 7), "mega": Vector2i(7, 7), "ult": Vector2i(6, 10)}

## Ascend: four stats of five levels, a point a level.
const ASCEND := ["coin", "balls", "prestige", "speed"]
const ASCEND_LEVELS := {
	"coin": [10.0, 50.0, 150.0, 320.0, 500.0],
	"balls": [2000, 3000, 3800, 4500, 5000],
	"prestige": [16.0, 96.0, 320.0, 700.0, 1000.0],
	"speed": [0.92, 0.97, 0.988, 0.993, 0.995],
}
const ASCEND_TOP := 5

static var path := "user://bagatelle.cfg"

var rng := RandomNumberGenerator.new()
var seed_v := 0
var t := 0.0
var events: Array = []
## The marbles in the air: {p, v, tier, add, mul, peg (the last peg that
## touched it), seen (pin ids), id, run (its own steps owed)}.
var balls: Array = []
## The jar, a tier an entry: marbles owned and marbles in the jar.
var owned := PackedInt64Array()
var jar := PackedInt64Array()
## Base marbles the run has been given (what the count figures say it
## should hold, merged or not).
var given := 0
var coins := 0.0
## This run's coins, and every coin ever.
var earned := 0.0
var lifetime := 0.0
var up := {}
var cup_lv := PackedInt32Array()
var cup_xp := PackedFloat64Array()
## When each pin was last touched (t), for its halo.
var glow := PackedFloat32Array()
## Bonus pegs: pin id -> kind.
var bonus := {}
var sp := 0.0
var sp_ever := 0.0
var cashouts := 0
var shop := {}
## Investments made (0 to 10, in order) and ascend points and stats.
var invested := 0
var ascends := 0
var ascend_pts := 0
var asc := {}
var best_tier := 0
var drops := 0
var landed := 0
## Pins touched since the holder last read them, and the lowest row one was on.
var pin_hits := 0
var pin_row := 0
## The dropper: where it is, marbles asked for and not yet let go, its
## glide's phase, and when it last let one go.
var drop_x := W * 0.5
var _want := 0
var _ph := 0.0
var _let_at := -10.0
var _auto_t := 0.0
## Auto held (for a probe: the sheet's Auto never stops, 3.5 s at level 0).
var auto_off := false
var _acc := 0.0
var _cash_acc := 0.0
var _next_id := 0
var _could := {}

func _init(rng_seed := 0) -> void:
	seed_v = rng_seed if rng_seed != 0 else int(Time.get_unix_time_from_system()) & 0x7fffffff
	rng.seed = seed_v
	owned.resize(TIERS)
	jar.resize(TIERS)
	cup_lv.resize(CUPS)
	cup_xp.resize(CUPS)
	glow.resize(ROWS * ACROSS)
	glow.fill(-10.0)
	for id: String in SHOP:
		shop[id] = 0
	for id: String in ASCEND:
		asc[id] = 0
	_new_run()

## A fresh run: coins, upgrades, cups and the jar from nothing (the bonus
## pegs stay where they stand).
func _new_run() -> void:
	balls.clear()
	coins = 0.0
	earned = 0.0
	for id: String in UPS:
		up[id] = 0
	owned.fill(0)
	jar.fill(0)
	given = 0
	cup_lv.fill(0)
	cup_xp.fill(0.0)
	_auto_t = 0.0
	_want = 0
	_cash_acc = 0.0
	_fill_jar()
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

## Where the dropper's glide stands at phase `ph`.
static func glide_x(ph: float) -> float:
	return W * (0.5 + GLIDE_SPAN * sin(ph))

# --- figures ---

static func worth(tier: int) -> float:
	return pow(WORTH, tier)

static func need(lv: int) -> float:
	return ceil(NEED_FIRST * pow(NEED_GROWTH, lv) + NEED_STEP * lv)

## An upgrade's figure at level `n`.
static func up_at(id: String, n: int) -> float:
	var a: Array = UP_LEVELS[id]
	return float(a[clampi(n, 0, a.size() - 1)])

func cup_mult(c: int) -> float:
	return float(CUP_BASE[c]) + CUP_STEP * cup_lv[c]

## The shop's figure for `id` (its level's, or what nothing gives).
func shop_at(id: String) -> float:
	var n := int(shop[id])
	if id == "balls":
		return float(BALLS_STEP * n)
	if n <= 0:
		return 1.0
	return float(SHOP_LEVELS[id][n - 1])

func ascend_at(id: String) -> float:
	var n := int(asc[id])
	if n <= 0:
		return 0.0 if id == "balls" or id == "speed" else 1.0
	return float(ASCEND_LEVELS[id][n - 1])

func has_invest(id: String) -> bool:
	return INVEST.find(id) < invested

## The marbles a run should hold, base marbles counted: the Ball count
## level, the shop's more balls, twice that with the fourth investment, and
## Ascend's.
func count_target() -> int:
	var n := int(up_at("marbles", int(up.marbles))) + int(shop_at("balls"))
	if has_invest("double"):
		n *= DOUBLE
	return n + int(ascend_at("balls"))

## Tops the jar up with clay to what the figures say.
func _fill_jar() -> void:
	var want := count_target()
	if want > given:
		owned[0] += want - given
		jar[0] += want - given
		given = want

func value() -> float:
	return up_at("value", int(up.value))

## Every coin a landing pays is also times these: the shop's drop
## multiplier and Ascend's coin value.
func coin_mult() -> float:
	return shop_at("drop") * ascend_at("coin")

## The merged marbles' worth is times the shop's mega balls value.
func tier_worth(tier: int) -> float:
	return worth(tier) * (shop_at("mega") if tier > 0 else 1.0)

## What a marble in the air pays before its cup: its value with what its
## pegs added, times its pegs' multipliers, its tier and the coin multipliers.
func ball_worth(b: Dictionary) -> float:
	return (value() + float(b.get("add", 0.0))) * float(b.get("mul", 1.0)) * tier_worth(int(b.tier)) * coin_mult()

## A clay marble's pay before its cup, for what counts as a big landing.
func unit() -> float:
	return value() * coin_mult()

func xp_each() -> float:
	return up_at("xp", int(up.xp)) * shop_at("xp") * (MEGA_XP if has_invest("mega_xp") else 1.0)

func auto_every() -> float:
	return up_at("auto", int(up.auto)) * (1.0 - ascend_at("speed"))

func weight() -> float:
	return up_at("weight", int(up.weight))

## Weight makes a marble fall faster, the board's time running sqrt(weight)
## times as fast for it: the same path through the pins, the same cups.
func fall_speed() -> float:
	return sqrt(weight())

# --- the run's upgrades ---

func up_top_level() -> int:
	return MEGA_TOP if has_invest("mega_up") else BASE_TOP

## The next level's price.
func price(id: String, n := -1) -> float:
	var k: int = int(up[id]) if n < 0 else n
	var a: Array = UP_PRICES[id]
	return float(a[mini(k + 1, a.size() - 1)])

func up_top(id: String) -> bool:
	return int(up[id]) >= up_top_level()

## Whether `id` is held at BASE_TOP until the eighth investment.
func up_waits(id: String) -> bool:
	return int(up[id]) >= BASE_TOP and not has_invest("mega_up")

func can_buy(id: String) -> bool:
	return not up_top(id) and coins >= price(id)

func any_ready() -> bool:
	for id: String in UPS:
		if can_buy(id):
			return true
	return false

## How many levels of `id` the coins buy at once, and what they cost.
func max_buy(id: String) -> Vector2:
	var n := 0
	var cost := 0.0
	var k := int(up[id])
	while k + n < up_top_level():
		var p := price(id, k + n)
		if cost + p > coins:
			break
		cost += p
		n += 1
	return Vector2(n, cost)

## Buys `times` levels of `id` (0: as many as the coins cover). The levels bought.
func buy(id: String, times := 1) -> int:
	var n := 0
	while (times <= 0 or n < times) and can_buy(id):
		coins -= price(id)
		up[id] = int(up[id]) + 1
		n += 1
	if n > 0:
		if id == "marbles":
			_fill_jar()
		_say({"type": "upgrade", "id": id, "level": int(up[id]), "n": n})
		_could[id] = can_buy(id)
	return n

# --- the cash out and the shop ---

## SP's multipliers: the shop's bonus, the fifth investment, Ascend's prestige.
func sp_mult() -> float:
	return shop_at("bonus") * (SP_BOOST if has_invest("sp_boost") else 1.0) * ascend_at("prestige")

## The base SP `c` coins make (before the multipliers).
static func sp_base(c: float) -> int:
	return int(floor(pow(maxf(c, 0.0) / sp_div, sp_pow)))

func sp_for(c := -1.0) -> int:
	return int(floor(float(sp_base(coins if c < 0.0 else c)) * sp_mult()))

## Coins where the next base SP comes, and where this one came.
func next_sp_at() -> float:
	var b := sp_base(coins) + 1
	return pow(float(b), 1.0 / sp_pow) * sp_div

func this_sp_at() -> float:
	var b := sp_base(coins)
	return pow(float(b), 1.0 / sp_pow) * sp_div

func can_cash_out() -> bool:
	return sp_for() >= 1

func cash_out() -> int:
	var s := sp_for()
	if s < 1:
		return 0
	sp += s
	sp_ever += s
	cashouts += 1
	_say({"type": "cashout", "sp": s})
	_new_run()
	return s

func shop_open(id: String) -> bool:
	return id != "mega" or has_invest("mega_shop")

func shop_top(id: String) -> bool:
	return id != "balls" and int(shop[id]) >= (SHOP_PRICES[id] as Array).size()

func shop_price(id: String) -> float:
	if id == "balls":
		return BALLS_PRICE
	if shop_top(id):
		return 0.0
	return float(SHOP_PRICES[id][int(shop[id])])

func can_shop(id: String) -> bool:
	return shop_open(id) and not shop_top(id) and sp >= shop_price(id)

func shop_buy(id: String) -> bool:
	if not can_shop(id):
		return false
	sp -= shop_price(id)
	shop[id] = int(shop[id]) + 1
	if id == "balls":
		_fill_jar()
	_say({"type": "shop", "id": id, "level": int(shop[id])})
	return true

# --- investments ---

## The next investment's id, or "" when all ten are made.
func next_invest() -> String:
	return INVEST[invested] if invested < INVEST.size() else ""

func invest_price() -> float:
	return float(INVEST_PRICES[invested]) if invested < INVEST.size() else 0.0

func can_invest() -> bool:
	return invested < INVEST.size() and sp >= invest_price()

## Makes the next investment: every SP is spent, the shop and the run start
## again, the investments made stay.
func invest() -> bool:
	if not can_invest():
		return false
	var id := next_invest()
	invested += 1
	sp = 0.0
	for s: String in SHOP:
		shop[s] = 0
	_new_run()
	_say({"type": "invest", "id": id, "n": invested})
	return true

# --- ascend ---

func can_ascend() -> bool:
	return invested >= INVEST.size()

## Ascends: a point to spend, and everything but Ascend starts again.
func ascend() -> bool:
	if not can_ascend():
		return false
	ascends += 1
	ascend_pts += 1
	invested = 0
	sp = 0.0
	for s: String in SHOP:
		shop[s] = 0
	bonus.clear()
	_new_run()
	_say({"type": "ascend", "n": ascends})
	return true

func ascend_top(id: String) -> bool:
	return int(asc[id]) >= ASCEND_TOP

func can_raise(id: String) -> bool:
	return ascend_pts >= 1 and not ascend_top(id)

## A point on one of Ascend's four stats.
func raise(id: String) -> bool:
	if not can_raise(id):
		return false
	ascend_pts -= 1
	asc[id] = int(asc[id]) + 1
	if id == "balls":
		_fill_jar()
	_say({"type": "raise", "id": id, "level": int(asc[id])})
	return true

# --- the pegs ---

## The pegs the investments have given and not yet stood somewhere: on
## their place in PEG_AT (or the first free pin); pegs no longer given go.
func _place_bonus() -> void:
	var want := {}
	for id: String in INVEST_PEG:
		if has_invest(id):
			want[INVEST_PEG[id]] = true
	for pin: int in bonus.keys():
		if not want.has(bonus[pin]):
			bonus.erase(pin)
	for kind: String in PEG_KINDS:
		if not want.has(kind) or bonus.values().has(kind):
			continue
		var rc: Vector2i = PEG_AT[kind]
		var id := pin_id(rc.y, rc.x)
		if not is_pin(id) or bonus.has(id):
			id = -1
			for c in ROWS * ACROSS:
				if is_pin(c) and not bonus.has(c):
					id = c
					break
		if id >= 0:
			bonus[id] = kind

## Carries a bonus peg to another pin. False when either is not right.
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

## A tap: a marble let go from wherever the dropper stands (the tap's
## across is not used: the dropper is never steered). False when the jar
## is empty.
func drop(_x := 0.0, _aimed := true) -> bool:
	return drop_here()

## Drop: a marble let go from wherever the dropper stands.
func drop_here() -> bool:
	if in_jar() - _want <= 0:
		_say({"type": "empty"})
		return false
	_want += 1
	return true

## Lets the best marble in the jar go from the dropper.
func _release(aimed: bool) -> bool:
	var k := best_in_jar()
	if k < 0:
		return false
	_let_at = t
	jar[k] -= 1
	_next_id += 1
	balls.append({"p": Vector2(drop_x, SPAWN_Y), "v": Vector2(rng.randf_range(-20.0, 20.0), 0.0), "tier": k, "add": 0.0, "mul": 1.0, "peg": "", "seen": [], "id": _next_id, "run": 0.0})
	drops += 1
	_say({"type": "drop", "x": drop_x, "tier": k, "aimed": aimed})
	return true

# --- the frame ---

func step(dt: float) -> void:
	_acc += minf(dt, 0.25)
	while _acc >= STEP:
		_acc -= STEP
		_tick()

func _tick() -> void:
	t += STEP
	_move_dropper()
	# the marbles asked for by a finger, one at a time
	if _want > 0 and t - _let_at >= RELEASE_GAP and balls.size() < MAX_AIR + 20:
		_want -= 1
		if not _release(true):
			_want = 0
	# Auto: a marble every `every`, from wherever the dropper stands, when
	# the jar has one and the air has room (several a step at its fastest)
	var every := auto_every()
	if every > 0.0 and not auto_off:
		_auto_t = minf(_auto_t + STEP, maxf(every, STEP) * AUTO_BURST)
		var n := 0
		while _auto_t >= every and n < AUTO_BURST and in_jar() - _want > 0 and balls.size() < MAX_AIR:
			_auto_t -= every
			n += 1
			_release(false)
		if n == 0 and _auto_t >= every:
			_auto_t = every
	# the ninth investment: a share of a cash out every second, the run kept
	if has_invest("auto_cash"):
		_cash_acc += AUTO_CASH * sp_for() * STEP
		if _cash_acc >= 1.0:
			var whole := floorf(_cash_acc)
			_cash_acc -= whole
			sp += whole
			sp_ever += whole
	# a heavier marble's time runs faster: more steps of its own a tick
	var speed := fall_speed()
	var i := 0
	while i < balls.size():
		var b: Dictionary = balls[i]
		b.run = float(b.run) + speed
		var in_cup := false
		while float(b.run) >= 1.0 and not in_cup:
			b.run = float(b.run) - 1.0
			in_cup = _move(b, GRAVITY)
		if in_cup:
			_land(b)
			balls.remove_at(i)
		else:
			i += 1
	for id: String in UPS:
		var now := can_buy(id)
		if now and not bool(_could.get(id, false)):
			_say({"type": "ready", "id": id})
		_could[id] = now

## The dropper glides, and nothing else moves it.
func _move_dropper() -> void:
	_ph += GLIDE * STEP
	drop_x = glide_x(_ph)

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
					var kind: String = bonus[id]
					b.peg = kind
					if PEG_ADD.has(kind):
						b.add = float(b.add) + float(PEG_ADD[kind])
					else:
						b.mul = float(b.mul) * float(PEG_MUL[kind])
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
	# the fins between the cups: a marble on one is sent to a side
	if p.y > FIN_TOP - BALL_R:
		var xd: float = round(p.x / CUP_W) * CUP_W
		if xd > 1.0 and xd < W - 1.0:
			var dx: float = p.x - xd
			var keep := BALL_R + FIN_W
			if absf(dx) < keep:
				var side := signf(dx) if absf(dx) > 0.5 else (1.0 if rng.randf() < 0.5 else -1.0)
				p.x = xd + side * keep
				v.x = side * maxf(absf(v.x) * 0.5, 80.0)
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
	var pay := ball_worth(b) * cup_mult(c)
	coins += pay
	earned += pay
	lifetime += pay
	landed += 1
	cup_xp[c] += xp_each()
	_say({"type": "land", "cup": c, "pay": pay, "tier": k, "x": (b.p as Vector2).x, "boost": float(b.mul) + float(b.add), "vx": (b.v as Vector2).x})
	var was := cup_lv[c]
	while cup_xp[c] >= need(cup_lv[c]):
		cup_xp[c] -= need(cup_lv[c])
		cup_lv[c] += 1
	if cup_lv[c] > was:
		_say({"type": "cup", "cup": c, "level": cup_lv[c], "n": cup_lv[c] - was})

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
	cfg.set_value("board", "owned", owned.duplicate())
	cfg.set_value("board", "given", given)
	cfg.set_value("board", "cup_lv", cup_lv)
	cfg.set_value("board", "cup_xp", cup_xp)
	var bkeys := PackedInt32Array()
	var bkinds := PackedStringArray()
	for id: int in bonus:
		bkeys.append(id)
		bkinds.append(String(bonus[id]))
	cfg.set_value("board", "bonus_at", bkeys)
	cfg.set_value("board", "bonus_kind", bkinds)
	cfg.set_value("sp", "sp", sp)
	cfg.set_value("sp", "ever", sp_ever)
	cfg.set_value("sp", "cashouts", cashouts)
	cfg.set_value("sp", "shop", shop)
	cfg.set_value("sp", "invested", invested)
	cfg.set_value("sp", "ascends", ascends)
	cfg.set_value("sp", "ascend_pts", ascend_pts)
	cfg.set_value("sp", "asc", asc)
	cfg.set_value("sp", "best_tier", best_tier)
	cfg.set_value("sp", "drops", drops)
	cfg.save(path)

## The kept board, or a new one. A file from before the sheet's economy
## (VER 1, stars) is not read: the board starts again.
static func load_saved(rng_seed := 0) -> RefCounted:
	var cfg := ConfigFile.new()
	if path == "" or cfg.load(path) != OK or int(cfg.get_value("board", "ver", 0)) != VER:
		return new(rng_seed)
	var s = new(int(cfg.get_value("board", "seed", rng_seed)))
	var sh: Dictionary = cfg.get_value("sp", "shop", {})
	for id: String in SHOP:
		s.shop[id] = maxi(0, int(sh.get(id, 0))) if id == "balls" else clampi(int(sh.get(id, 0)), 0, (SHOP_PRICES[id] as Array).size())
	var a: Dictionary = cfg.get_value("sp", "asc", {})
	for id: String in ASCEND:
		s.asc[id] = clampi(int(a.get(id, 0)), 0, ASCEND_TOP)
	s.sp = maxf(0.0, float(cfg.get_value("sp", "sp", 0.0)))
	s.sp_ever = maxf(s.sp, float(cfg.get_value("sp", "ever", 0.0)))
	s.cashouts = maxi(0, int(cfg.get_value("sp", "cashouts", 0)))
	s.invested = clampi(int(cfg.get_value("sp", "invested", 0)), 0, INVEST.size())
	s.ascends = maxi(0, int(cfg.get_value("sp", "ascends", 0)))
	s.ascend_pts = maxi(0, int(cfg.get_value("sp", "ascend_pts", 0)))
	s.best_tier = clampi(int(cfg.get_value("sp", "best_tier", 0)), 0, TIERS - 1)
	s.drops = maxi(0, int(cfg.get_value("sp", "drops", 0)))
	s.coins = maxf(0.0, float(cfg.get_value("board", "coins", 0.0)))
	s.earned = maxf(0.0, float(cfg.get_value("board", "earned", 0.0)))
	s.lifetime = maxf(s.earned, float(cfg.get_value("board", "lifetime", 0.0)))
	var u: Dictionary = cfg.get_value("board", "up", {})
	for id: String in UPS:
		s.up[id] = clampi(int(u.get(id, 0)), 0, s.up_top_level())
	var o: PackedInt64Array = cfg.get_value("board", "owned", PackedInt64Array())
	if o.size() == TIERS:
		for k in TIERS:
			s.owned[k] = maxi(0, o[k])
			s.jar[k] = s.owned[k]
		s.given = maxi(0, int(cfg.get_value("board", "given", 0)))
	else:
		s.owned.fill(0)
		s.jar.fill(0)
		s.given = 0
	s._fill_jar()
	var lv: PackedInt32Array = cfg.get_value("board", "cup_lv", PackedInt32Array())
	var xp: PackedFloat64Array = cfg.get_value("board", "cup_xp", PackedFloat64Array())
	for c in CUPS:
		if c < lv.size():
			s.cup_lv[c] = maxi(0, lv[c])
		if c < xp.size():
			s.cup_xp[c] = maxf(0.0, xp[c])
	s.bonus = {}
	var bk: PackedInt32Array = cfg.get_value("board", "bonus_at", PackedInt32Array())
	var bn: PackedStringArray = cfg.get_value("board", "bonus_kind", PackedStringArray())
	for j in mini(bk.size(), bn.size()):
		if is_pin(bk[j]) and PEG_KINDS.has(bn[j]) and not s.bonus.has(bk[j]) and not s.bonus.values().has(bn[j]):
			s.bonus[bk[j]] = bn[j]
	s._place_bonus()
	for id: String in UPS:
		s._could[id] = s.can_buy(id)
	return s

## The board as the Arcade tab's card reads it, without running anything.
static func kept() -> Dictionary:
	var cfg := ConfigFile.new()
	if path == "" or cfg.load(path) != OK or int(cfg.get_value("board", "ver", 0)) != VER:
		return {"new": true, "sp": 0.0, "tier": 0}
	return {"new": false, "sp": float(cfg.get_value("sp", "ever", 0.0)), "tier": int(cfg.get_value("sp", "best_tier", 0))}
