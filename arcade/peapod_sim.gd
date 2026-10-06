extends RefCounted

## Peapod as pure data (spec
## docs/superpowers/specs/2026-10-04-arcade-peapod-design.md): a pea cannon
## on a cart at the foot of a garden, firing on its own, and numbered crates
## coming down on it. The screen (arcade/peapod_screen.gd) sets `target_x`
## (or `axis`), calls `step()` at the fixed DT and drains `events`.
##
## The rules of the genre, kept: the cannon only slides and never stops
## firing; a crate takes as many peas as its number; gift crates drop a
## token that must be caught (one more pea a volley, a quicker gun, a
## heavier pea, a helper cart for a while); a firecracker crate takes its
## neighbours with it; and whatever reaches the cart's line ends the run.
## (The tokens, the gun's gifts and the helper went with the fourth pass.)
## Two waves of crates in a wall, five across, then one of a millipede
## winding down a path -- every plate a number, the head worth six of them,
## and a plate shot off knocks the whole of it back.
##
## The second pass (2026-10-04): three pods held for a while (a fan of peas,
## a pea that goes through three, a pea that bursts on its neighbours),
## three more gifts (a magnet for the gifts, a frost on whatever is coming,
## a shove back up) and an iron crate that takes one a pea whatever the pea
## weighs. The helper is a short one now, and the millipede quickens as it
## shortens.
##
## The third pass (2026-10-05): the rotten gift is gone (a gift that took
## something back made no sense). A wave holds more gifts and more crates,
## and its gifts are planned together (`_plan_gifts`), not drawn one by one:
## the gun's own come first and are half of them at least, and a magnet
## only comes with gifts right behind it to pull.
##
## The fourth pass (2026-10-05, the user's design): nothing falls and nothing
## is caught. A gift crate's gift is had the moment the crate breaks, so the
## magnet is gone, and with it the gun's three gifts and the helper. The gun
## is one pea a volley and grows in a shop between waves: every crate pays
## energy, and energy buys a heavier pea, a quicker gun, a pea that now and
## then lands three times as hard, or more energy a crate. A price climbs
## with each one bought and with the size of the walls (`price`), so a card
## left for later is never the cheaper for it. Two more pods, held one at a
## time like the rest: lightning that jumps on from what it hit, and a flame
## that leaves it burning. A hit says what it took (`dmg`, `crit`, `how`),
## for the numbers the screen floats off it.
##
## The fifth pass (2026-10-05, the user: "since upgrades don't stack, a wave
## with an electric shot and a burst makes one of them useless", and "instead
## of auto activate the buff, keep the last two on screen so the user can
## activate anytime, and new buffs replace the old one"). A gift is kept, not
## started: it goes to one of two places (`held`), a newer gift taking the
## older one's, and `use(slot)` starts it. And the pods are two kinds that
## run together: how the peas go (`shape`: Fan, Dart, Burst) and what they
## are made of (`element`: lightning, flame), one of each at once, each with
## its own ten seconds. A wave's second pod is of the other kind than its
## first.
##
## The sixth pass (2026-10-05, the user's four asks). The shop sells a pea
## more a volley, dear (`Card.SHOTS`), and a volley's peas leave one after
## another up the same lane (side by side since the eighth). The crit's chance no longer
## grows a level: it is CRIT_CHANCE from the first one bought (none before)
## and a level makes the crit land harder (`crit_mult`), the chance going up
## a little every CRIT_EVERY levels. The crit and the quicker gun cost more.
## And no gift is lost to a newer one: past the two places a gift waits its
## turn (`queue`), first in first out: the two places are the head of one
## line, and a gift started lets everything behind it move up one.
##
## The seventh pass (2026-10-05, the user's four asks). A price climbs only
## with each one bought, no longer with the walls ("the price increase should
## only be applied when the player buys it"). The shapes run all together,
## each with its own time, and only the elements take each other's place
## ("only elemental should not stack"). A pea of an element is the same pea in
## the element's colour (the screen's). And a new gift goes to the head of the
## line, not its end.
##
## The eighth pass (2026-10-05, the user: "instead of buffs being a queue,
## make them available at screen since beginning but as 0", and "change +1
## pea to be parallel instead of sequential"). There is no line of gifts: the
## run counts how many of each it has (`stock`), every one of the seven there
## from the start at none, and `use(kind)` starts one of a kind. A gift
## started while its like is running adds its time to what is left. And a
## volley's peas leave together, side by side.
##
## The ninth pass (2026-10-06, the user: "nearly impossible to beat after
## wave 17, where crates start getting 2k hp"). The numbers climb 1.16 a wave
## after wave 10, not 1.3 (`HP_LATE`).
##
## The tenth pass (2026-10-06, the user: "crate on fire should explode and
## spread fire to near crates, fire damage should increase based on shoot
## damage", "different carts other than this default with different
## upgrades", "5 canons", "3 more elementals", and then "don't add cap" and
## "no pea gun limit as well"). A fire burns as hard as the hit that lit it
## (a crit's, a shell's), and a thing that goes while alight bursts a beat
## later: what is next to it takes a blow and catches the same fire, and so
## on down the wall. Six carts (`Cart`, `cart`, chosen before the run): each
## shoots its own way and sells a card of its own where the pea gun sells a
## pea more (`Card.SHOTS`, `special`). Three more elements: the nettle's
## stings, the hail that leaves a thing brittle, the gust that drives
## whatever is coming back while it is being hit. And nothing the shop sells
## has a most: a price is the only brake.

## SHOP: a wave is cleared and the shop is open; nothing moves until
## `leave_shop()`.
enum Phase { READY, PLAY, OVER, SHOP }
enum Wave { WALL, MILLI }
## What a crate or a plate is. FAN to SHOVE hold a gift (`holds_gift`); FAN
## to FLAME are the pods (`is_pod`): FAN to BURST are how the peas go
## (`is_shape`), ZAP and FLAME what they are made of (`is_element`).
enum Kind { CRATE, GOLD, BOMB, HEAD, FAN, PIERCE, BURST, ZAP, FLAME, NETTLE, HAIL, GUST, FROST, SHOVE, IRON }
## How a shot in flight is shaped; its element (`el`) is its colour. PEA to
## BURST are the pea gun's and what the Dart and the Berry make of any
## cart's; the rest are the other carts' own.
enum Shot { PEA, PIERCE, BURST, CONKER, PUMPKIN, DROP, SEED }
## What the shop sells. SHOTS is the cart's own card: a pea more a volley on
## the pea gun, and on the others what `special` counts.
enum Card { DAMAGE, SPEED, CRIT, ENERGY, SHOTS }
## What a number came off by: the pea itself, a splash or a jump of it, a
## firecracker or a shell's blast, a burn, a nettle's sting.
enum Hit { PEA, SIDE, BOOM, BURN, STING }
## The carts. PEA: a pea straight up, and a pea more a card. CONKER: its shot
## hops on to the nearest crate, a hop more a card. PUMPKIN: slow and heavy,
## and everything round where it lands takes a share; a wider blast a card.
## HOSE: a stream of drops that land harder the longer they stay on one
## thing; a card lets them. DANDELION: a cone of light seeds, two more a
## card. TWINS: a second cart mirrored across the garden, its share a card.
enum Cart { PEA, CONKER, PUMPKIN, HOSE, DANDELION, TWINS }

const DT := 1.0 / 60.0
const W := 300.0
const H := 460.0
const COLS := 5
const CELL_W := W / COLS
const CELL_H := 40.0
## The grass the cart stands on, the cart's axle and the line nothing may
## reach.
const GROUND := 432.0
const CART_Y := 414.0
const DANGER := 380.0
const CART_HALF := 22.0
const CART_SPEED := 1400.0
const READY_TIME := 1.6
const GAP_TIME := 1.5
const PEA_SPEED := 540.0
## The quicker gun: volleys a second at first, what a level adds, and the
## levels it takes (the shots in the air are what the phone pays for).
## By Cart. Nothing has a most (the user, 2026-10-06): the price is the
## brake, and the gun fires FIRE_MOST volleys a step at most.
const CART_RATE := [5.0, 4.5, 1.4, 12.0, 3.5, 5.0]
const CART_RATE_STEP := [1.0, 0.9, 0.28, 1.5, 0.7, 1.0]
const FIRE_MOST := 3
## By Cart: the share of the pea's weight one shot lands as (what is short
## of a whole number is kept for the next: `_whole`), how fast it flies, how
## big it is drawn, and what the cart's own card costs and climbs by.
const CART_WEIGHT := [1.0, 1.0, 4.2, 0.68, 0.36, 1.0]
const CART_SPEED_UP := [540.0, 540.0, 400.0, 900.0, 540.0, 540.0]
const CART_SIZE := [1.0, 1.15, 1.9, 0.72, 0.8, 1.0]
const CART_PRICE := [80, 40, 40, 36, 44, 36]
const CART_PRICE_STEP := [1.5, 1.0, 1.0, 0.9, 1.0, 0.9]
## The conker: how far a hop reaches, and what of its weight each hop keeps.
const HOP_REACH := 120.0
const HOP_KEEP := 0.7
## The pumpkin: how far its blast reaches and what a card adds, and the
## share of the shell everything in it takes.
const BLAST_R := 46.0
const BLAST_STEP := 14.0
const BLAST_SHARE := 0.6
## The hose: what each drop more on the same thing adds, how much a card
## quickens that, the most it comes to and what a card adds to that.
const JET_STEP := 0.08
const JET_QUICK := 0.25
const JET_CAP := 2.0
const JET_CAP_STEP := 0.5
## The dandelion: its seeds a volley and what a card adds, and how far the
## outermost lean (as vx).
const SEEDS := 5
const SEED_STEP := 2
const SEED_VX := 105.0
## The twin's share of the cart's weight, and what a card adds.
const TWIN := 0.7
const TWIN_STEP := 0.15
## The crit: with none bought no pea is lucky. From the first level a pea
## has CRIT_CHANCE of landing CRIT_MULT times as hard, and every level after
## adds CRIT_MULT_STEP to that; the chance itself only goes up CRIT_CHANCE_STEP
## every CRIT_EVERY levels, to CRIT_CHANCE_MAX.
const CRIT_CHANCE := 0.1
const CRIT_CHANCE_STEP := 0.05
const CRIT_CHANCE_MAX := 0.5
const CRIT_EVERY := 5
const CRIT_MULT := 3
const CRIT_MULT_STEP := 1
## How far apart the peas of a volley leave, side by side, and how wide the
## row is at its most (so a cart on a column's middle lands all of them on it).
const PEA_GAP := 10.0
const PEA_ROW := 54.0
## Energy is counted in orbs, ORBS of them to one energy: a crate drops an
## orb for every quarter of what it is worth, so one worth 1.5 drops six.
## A crate is worth ENERGY_CRATE (a golden one GOLD_WORTH times), and a
## level of the Energy card adds ENERGY_STEP of that.
const ORBS := 4
const ENERGY_CRATE := 1.0
const ENERGY_STEP := 0.1
## A card's price in energy with none bought, and how much of that each one
## bought adds. Nothing else moves a price.
const PRICE := [11, 14, 14, 12, 80]
const PRICE_STEP := [0.7, 0.9, 0.9, 0.6, 1.5]
## The beat between the shop closing and the next wave.
const SHOP_GAP := 0.5
## The gifts there are, FAN to SHOVE: `stock` counts each.
const GIFTS := 10
const POD_TIME := 10.0
## Lightning: the jumps on from what a pea hit, and how far one reaches.
const ZAP_JUMPS := 4
const ZAP_REACH := 90.0
## A flame: how long a thing burns, how often it is bitten, and the share
## of the hit that lit it each bite takes. A thing that goes while alight
## bursts FLARE_FUSE later: whatever is next to it takes FLARE_SHARE of that
## hit and catches the same fire.
const BURN_TIME := 3.0
const BURN_TICK := 0.5
const BURN_BITE := 0.75
const FLARE_FUSE := 0.09
const FLARE_SHARE := 1.5
## The nettle: a shot leaves as many stings as its share of the pea's weight,
## they last STING_TIME from the last one, and every STING_TICK each takes
## STING_RATE a second of what the thing began as. They have no most.
const STING_TIME := 3.0
const STING_TICK := 0.5
const STING_RATE := 0.005
## The hail: how long a thing stays brittle, and what it takes of everything
## while it is.
const BRITTLE_TIME := 3.0
const BRITTLE := 1.5
## The gust: whatever is coming goes back at GUST_BACK of its speed for
## GUST_HOLD after each of its shots lands.
const GUST_HOLD := 0.25
const GUST_BACK := 0.35
const FROST_TIME := 5.0
const FROST := 0.35
const SHOVE_WALL := 60.0
const SHOVE_MILLI := 200.0
## The fan's two side peas lean this far off straight up (as vx).
const FAN_VX := 135.0
const PIERCES := 3
## A wall still high up comes down quickly, so a cleared sky never waits.
const RUSH_Y := 150.0
const RUSH := 5.0
const GOLD_WORTH := 5
## The millipede's path: rows ROW apart between X0 and X1, a half circle at
## each end, entered from off the left edge.
const PATH_FROM := -26.0
const X0 := 40.0
const X1 := W - 40.0
const Y0 := 34.0
const ROW := 46.0
const TURN_R := ROW * 0.5
const PATH_ROWS := 8
const SPACING := 31.0
const SEG_R := 15.0
const HEAD_R := 19.0
const HEAD_WORTH := 6
## A wall's rows on wave 1 (one more every other wave) and at its most, the
## chance a cell is left empty (the lowest row's is its own), and a
## millipede's plates before the wave's number is added.
const WALL_ROWS := 6
const WALL_ROWS_MAX := 12
const WALL_GAP := 0.1
const WALL_GAP_LOW := 0.25
const MILLI_PLATES := 9
const MILLI_PLATES_MAX := 26
const KNOCK := 9.0
## With every plate gone but the head it runs this much quicker.
const MILLI_HURRY := 0.6
const CATCH_UP := 5.0
## A crate's number grows HP_EARLY a wave to wave HP_TURN and HP_LATE after.
## Past the turn the gun is mostly bought (a wave's energy is about one card,
## a tenth more gun), so HP_LATE over that is how steeply a run closes: at
## 1.3 every run ended on the same wave, whatever was done.
const HP_EARLY := 1.32
const HP_LATE := 1.16
const HP_TURN := 10
## Kills this close together are one streak.
const STREAK_GAP := 0.7

var rng := RandomNumberGenerator.new()
var phase := Phase.READY
var phase_t := 0.0
var t := 0.0
var score := 0
var wave := 0
var wave_kind := Wave.WALL
## Seconds until the next wave is dealt (0: one is on).
var gap_t := 0.0
var x := W * 0.5
## Where the finger wants the cart (NAN: where it is), or the keys' axis.
var target_x := NAN
var axis := 0.0
## The gun: a pea's weight, the rate's level and the crit's, the peas a
## volley (one, and one more a SHOTS card) and the level of the Energy card. `bought` is how many of each card the shop has sold
## (a booster's head start is not one of them, so it does not raise a price).
var power := 1
var rate_lv := 0
var crit_lv := 0
var peas := 1
var energy_lv := 0
## The cart (set before the first step), and how many of its own card it has
## (`peas` is one more than this on the pea gun).
var cart := Cart.PEA
var special := 0
var bought := [0, 0, 0, 0, 0]
## Energy held and all the run has made, both in orbs (`ORBS` to one
## energy), and the part of an orb the crates so far have left over.
var energy := 0
var earned := 0
var _orb_part := 0.0
## The gifts had and not yet used: how many of each, by `kind - Kind.FAN`
## (`has`). All seven are there from the start, at none.
var stock: Array = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
## What is running: the seconds left of each shape (FAN, PIERCE, BURST, in
## that order: `has_shape`), all of which run together; one element (0:
## none, else ZAP to GUST) and its seconds; the frost's.
var shape_t: Array = [0.0, 0.0, 0.0]
var element := 0
var element_t := 0.0
var frost_t := 0.0
var _cool := 0.0
var shots: Array = []
## How much sky the screen shows over the field's top, in field units (a
## phone is taller than the field): a pea flies on to the top of it, and
## lands on whatever of a wall it meets up there.
var sky := 0.0
## Seconds until the last thing lit has burnt out, and the last sting gone.
var _burning := 0.0
var _stinging := 0.0
## The bursts on their fuses: {t, pos, off, c, ids, heat} (`off`: how far up
## from the wall's foot; `ids`: the plates either side on a millipede).
var _flares: Array = []
## Seconds the gust still holds whatever is coming.
var _gust_t := 0.0
var _gust_said := -1.0
## What the landings so far were short of a whole number by.
var _part := 0.0
## The hose: what its drops are on, and how many have landed there running.
var _jet_id := -1
var _jet_n := 0
var _shopped := false
var _last_pod := -1
## The crits' own dice, so a wave is dealt the same however the peas land.
var _luck := RandomNumberGenerator.new()
## The wall, lowest row first: each row COLS cells, null or {kind, hp, max,
## id}. `wall_y` is the lowest row's bottom edge.
var rows: Array = []
var wall_y := 0.0
var wall_speed := 8.0
## The millipede, head first: {kind, hp, max, s, id, dying}.
var segs: Array = []
var milli_speed := 24.0
var milli_n := 1
var _push := 0.0
## Where each plate is, worked out once a step and again when one goes: a
## pea asking the path for every plate it passed was most of a step.
var _seg_pos := PackedVector2Array()
var _seg_dirty := true
var _seg_top := 0.0
var _seg_low := 0.0
var events: Array = []
var kills := 0
## Gift crates broken, and gifts used.
var caught := 0
var used := 0
var fired := 0
var streak := 0
var best_streak := 0
var _streak_t := 0.0
var _warned := false
var _next_id := 1

func _init(seed_value := -1, cart_value := Cart.PEA) -> void:
	cart = cart_value
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	_luck.seed = rng.randi()
	events.append({"type": "ready"})

func is_over() -> bool:
	return phase == Phase.OVER

## Volleys a second, and what a level of the quicker gun adds.
func rate() -> float:
	return CART_RATE[cart] + rate_step() * rate_lv

func rate_step() -> float:
	return CART_RATE_STEP[cart]

## What the cart's own card has made of it.
func hops() -> int:
	return 1 + special

func blast_r() -> float:
	return BLAST_R + BLAST_STEP * special

func jet_cap() -> float:
	return JET_CAP + JET_CAP_STEP * special

func seeds() -> int:
	return SEEDS + SEED_STEP * special

func twin_share() -> float:
	return TWIN + TWIN_STEP * special

## How hard the hose's drops are landing now, 1 and up.
func jet() -> float:
	return minf(1.0 + JET_STEP * (1.0 + JET_QUICK * special) * _jet_n, jet_cap())

## The chance a pea is lucky, at crit level `lv`: none before the first.
static func crit_chance(lv: int) -> float:
	if lv <= 0:
		return 0.0
	return minf(CRIT_CHANCE + CRIT_CHANCE_STEP * int(lv / float(CRIT_EVERY)), CRIT_CHANCE_MAX)

## How many times as hard a lucky pea lands, at crit level `lv`.
static func crit_mult(lv: int) -> int:
	return CRIT_MULT + CRIT_MULT_STEP * maxi(0, lv - 1)

func crit() -> float:
	return crit_chance(crit_lv)

## A crate's number on wave `w`, before its row and its luck.
static func hp_base(w: int) -> float:
	return 2.4 * pow(HP_EARLY, mini(w, HP_TURN) - 1) * pow(HP_LATE, maxi(0, w - HP_TURN))

static func holds_gift(kind: int) -> bool:
	return kind >= Kind.FAN and kind <= Kind.SHOVE

static func is_pod(kind: int) -> bool:
	return kind >= Kind.FAN and kind <= Kind.GUST

static func is_shape(kind: int) -> bool:
	return kind >= Kind.FAN and kind <= Kind.BURST

## Whether shape `kind` (FAN, PIERCE or BURST) is running.
func has_shape(kind: int) -> bool:
	return float(shape_t[kind - Kind.FAN]) > 0.0

static func is_element(kind: int) -> bool:
	return kind >= Kind.ZAP and kind <= Kind.GUST

## About how many crates wave `w`'s wall holds: what a wave pays is this
## many crates' worth, a millipede's too (its head pays the difference).
static func wave_crates(w: int) -> float:
	return mini(WALL_ROWS + int(w / 2.0), WALL_ROWS_MAX) * COLS * (1.0 - WALL_GAP)

# --- the shop ---

## What `card` costs now, in orbs (a whole number of energy): more for each
## one bought and for nothing else, so a card not bought costs on wave 10
## what it did on wave 1.
func price(card: int) -> int:
	var first: float = CART_PRICE[cart] if card == Card.SHOTS else PRICE[card]
	var step: float = CART_PRICE_STEP[cart] if card == Card.SHOTS else PRICE_STEP[card]
	return maxi(1, roundi(first * (1.0 + step * int(bought[card])))) * ORBS

## No card has a most (the user, 2026-10-06: "don't add cap", "no pea gun
## limit as well"); kept for what asks.
func maxed(_card: int) -> bool:
	return false

func can_buy(card: int) -> bool:
	return not maxed(card) and energy >= price(card)

func buy(card: int) -> bool:
	if not can_buy(card):
		return false
	energy -= price(card)
	bought[card] = int(bought[card]) + 1
	match card:
		Card.DAMAGE:
			power += 1
		Card.SPEED:
			rate_lv += 1
		Card.CRIT:
			crit_lv += 1
		Card.ENERGY:
			energy_lv += 1
		Card.SHOTS:
			special += 1
			if cart == Cart.PEA:
				peas += 1
	events.append({"type": "buy", "card": card})
	return true

## The shop is shut and the next wave is on its way.
func leave_shop() -> void:
	if phase != Phase.SHOP:
		return
	phase = Phase.PLAY
	phase_t = 0.0
	_shopped = true
	gap_t = SHOP_GAP

## An iron crate's number: the peas it takes, whatever they weigh.
static func iron_hp(w: int) -> int:
	return 10 + 4 * w

static func path_len() -> float:
	return (X1 - PATH_FROM) + (PATH_ROWS - 1) * (PI * TURN_R + X1 - X0)

## The path at `s` along it.
static func path_at(s: float) -> Vector2:
	var first := X1 - PATH_FROM
	if s <= first:
		return Vector2(PATH_FROM + s, Y0)
	s -= first
	var straight := X1 - X0
	var leg := PI * TURN_R + straight
	var k := mini(int(s / leg), PATH_ROWS - 2)
	var r := s - k * leg
	var right := k % 2 == 0
	var top := Y0 + k * ROW
	if r < PI * TURN_R:
		var a := r / TURN_R
		var out := sin(a) * TURN_R
		return Vector2(X1 + out if right else X0 - out, top + TURN_R - cos(a) * TURN_R)
	r = minf(r - PI * TURN_R, straight)
	return Vector2(X1 - r if right else X0 + r, top + ROW)

## How near the end is, 0 (far) to 1 (on the line): the screen's warning.
func danger() -> float:
	if phase != Phase.PLAY:
		return 0.0
	if wave_kind == Wave.WALL:
		if rows.is_empty():
			return 0.0
		return clampf((wall_y - (DANGER - 110.0)) / 110.0, 0.0, 1.0)
	if segs.is_empty():
		return 0.0
	var left: float = path_len() - float(segs[0].s)
	return clampf(1.0 - left / 420.0, 0.0, 1.0)

## Where a cell's centre is.
func cell_pos(row: int, col: int) -> Vector2:
	return Vector2((col + 0.5) * CELL_W, wall_y - (row + 0.5) * CELL_H)

func step() -> void:
	phase_t += DT
	match phase:
		Phase.READY:
			_move()
			if phase_t >= READY_TIME:
				phase = Phase.PLAY
				phase_t = 0.0
				events.append({"type": "go"})
				_deal()
		Phase.PLAY:
			t += DT
			_move()
			_tick_gifts()
			_fire()
			_step_shots()
			_step_flares()
			_step_burns()
			if gap_t > 0.0:
				gap_t -= DT
				if gap_t <= 0.0:
					gap_t = 0.0
					_after_gap()
			elif wave_kind == Wave.WALL:
				_step_wall()
			else:
				_step_milli()
			_streak_t -= DT
			if _streak_t <= 0.0:
				streak = 0
			var d := danger()
			if d > 0.35 and not _warned:
				_warned = true
				events.append({"type": "warn"})
			elif d < 0.15:
				_warned = false
		Phase.OVER:
			_step_shots()

## The beat after a cleared wave is over: the shop, when there is energy for
## anything in it, and then the next wave.
func _after_gap() -> void:
	if not _shopped:
		for card in Card.size():
			if can_buy(card):
				phase = Phase.SHOP
				phase_t = 0.0
				events.append({"type": "shop"})
				return
	_shopped = false
	_deal()

func _move() -> void:
	var want := x
	if not is_nan(target_x):
		want = target_x
	elif axis != 0.0:
		want = x + axis * 260.0 * DT
	x = move_toward(x, clampf(want, CART_HALF, W - CART_HALF), CART_SPEED * DT)

## The shape, the element and the frost run down.
func _tick_gifts() -> void:
	for i in shape_t.size():
		if float(shape_t[i]) > 0.0:
			shape_t[i] = float(shape_t[i]) - DT
			if float(shape_t[i]) <= 0.0:
				shape_t[i] = 0.0
				events.append({"type": "pod_off", "kind": Kind.FAN + i})
	if element_t > 0.0:
		element_t -= DT
		if element_t <= 0.0:
			element_t = 0.0
			events.append({"type": "pod_off", "kind": element})
			element = 0
	if frost_t > 0.0:
		frost_t -= DT
		if frost_t <= 0.0:
			frost_t = 0.0
			events.append({"type": "frost_off"})
	_gust_t = maxf(0.0, _gust_t - DT)

## What the frost leaves of a speed.
func _slow() -> float:
	return FROST if frost_t > 0.0 else 1.0

## A volley leaves all at once, from wherever the cart is; the twin's leaves
## with it from across the garden.
func _fire() -> void:
	_cool -= DT
	var n := 0
	while _cool <= 0.0 and n < FIRE_MOST:
		n += 1
		_cool += 1.0 / rate()
		_volley(x, 1.0, true)
		if cart == Cart.TWINS:
			_volley(W - x, twin_share(), false)
		events.append({"type": "shot", "x": x})
		fired += 1
	if _cool < 0.0:
		_cool = 0.0

## How far off the cart's middle pea `i` of a volley of `n` leaves: side by
## side, PEA_GAP apart (closer once the row would be wider than PEA_ROW), the
## volley's middle over the cart's.
static func pea_off(i: int, n: int) -> float:
	return (i - (n - 1) * 0.5) * minf(PEA_GAP, PEA_ROW / maxf(1.0, n - 1.0))

## A volley from `from` as the cart, the shapes and the element running make
## it, each shot `share` of the cart's weight (the twin's is less); `main`
## is the cart's own, which the hose counts. The pea gun's peas leave side by
## side, the dandelion's seeds as a cone, the rest one shot. The Fan's two
## are plain shots of the same cart and element, flung out from either side.
func _volley(from: float, share: float, main: bool) -> void:
	var burst := has_shape(Kind.BURST)
	var pierce := has_shape(Kind.PIERCE)
	var own: int = [Shot.PEA, Shot.CONKER, Shot.PUMPKIN, Shot.DROP, Shot.SEED, Shot.PEA][cart]
	var look: int = Shot.BURST if burst else (Shot.PIERCE if pierce else own)
	var w: float = CART_WEIGHT[cart] * share
	var out := 6.0
	if cart == Cart.DANDELION:
		var n := seeds()
		for i in n:
			_shoot(from, SEED_VX * (2.0 * i / (n - 1.0) - 1.0), look, w, pierce, burst, main)
	else:
		var n := peas if cart == Cart.PEA else 1
		for i in n:
			_shoot(from + pea_off(i, n), 0.0, look, w, pierce, burst, main)
		out += pea_off(n - 1, n)
	if has_shape(Kind.FAN):
		for side in [-1.0, 1.0]:
			_shoot(from + side * out, side * FAN_VX, own, w, false, false, false)

## One shot into the air. It carries how it lands: `w` (its share of the
## pea's weight), `left` (the things a Dart still goes through), `burst`,
## `el` (its element), `hops` (a conker's, and `to`: the id it is hopping
## to, `seen`: what it has landed on), `blast` (a shell's reach); `k` is its
## look (Shot) and `sz` how big it is drawn.
func _shoot(from: float, vx: float, look: int, w: float, pierce: bool, burst: bool, main: bool) -> void:
	shots.append({"x": clampf(from, 3.0, W - 3.0), "y": CART_Y - 34.0, "vx": vx, "vy": -float(CART_SPEED_UP[cart]), "k": look,
		"left": PIERCES - 1 if pierce else 0, "last": -1, "burst": burst, "el": element, "w": w, "sz": CART_SIZE[cart], "main": main,
		"hops": hops() if cart == Cart.CONKER else 0, "to": -1, "seen": [],
		"blast": blast_r() if cart == Cart.PUMPKIN else 0.0})

func _step_shots() -> void:
	var keep: Array = []
	_seg_dirty = true
	var live := phase == Phase.PLAY and gap_t <= 0.0
	for p: Dictionary in shots:
		if int(p.to) >= 0:
			# a conker on its hop: nothing to hop to once the wave is over
			if live and _home(p):
				keep.append(p)
			continue
		p.y += float(p.vy) * DT
		if p.y < -sky - 8.0:
			continue
		if p.vx != 0.0:
			p.x += float(p.vx) * DT
			# a pea flung sideways comes back off the garden's side
			if p.x < 3.0 or p.x > W - 3.0:
				p.x = clampf(p.x, 3.0, W - 3.0)
				p.vx = -float(p.vx)
		if live and _strike(p):
			continue
		keep.append(p)
	shots = keep

## Where every plate is, and the band of the field they are in.
func _place_segs() -> void:
	_seg_dirty = false
	var n := segs.size()
	_seg_pos.resize(n)
	_seg_top = INF
	_seg_low = -INF
	for i in n:
		var at := path_at(segs[i].s)
		_seg_pos[i] = at
		_seg_top = minf(_seg_top, at.y)
		_seg_low = maxf(_seg_low, at.y)

## A pea against whatever is over it. True when it is spent.
func _strike(p: Dictionary) -> bool:
	var px: float = p.x
	var py: float = p.y
	if wave_kind == Wave.WALL:
		if py > wall_y or rows.is_empty() or px < 0.0 or px >= W:
			return false
		var r := int((wall_y - py) / CELL_H)
		var c := clampi(int(px / CELL_W), 0, COLS - 1)
		if r >= rows.size() or rows[r][c] == null:
			return false
		var id: int = rows[r][c].id
		if id == int(p.last):
			return false
		_land_cell(p, r, c, Vector2(px, wall_y - r * CELL_H))
		return _spent(p, id)
	if _seg_dirty:
		_place_segs()
	if py < _seg_top - HEAD_R - 2.0 or py > _seg_low + HEAD_R + 2.0:
		return false
	for i in segs.size():
		var sg: Dictionary = segs[i]
		if sg.dying >= 0.0 or float(sg.s) < 0.0:
			continue
		var at := _seg_pos[i]
		var rad := (HEAD_R if sg.kind == Kind.HEAD else SEG_R) + 2.0
		if absf(at.x - px) < rad and absf(at.y - py) < rad:
			var id: int = sg.id
			if id == int(p.last):
				continue
			_land_seg(p, i, Vector2(px, at.y + rad * 0.7))
			return _spent(p, id)
	return false

## A shot that has landed on `id`: a piercing one with targets left goes on,
## a conker with hops left turns for the nearest thing it has not landed on
## (HOP_KEEP of its weight each hop). True when it is spent.
func _spent(p: Dictionary, id: int) -> bool:
	(p.seen as Array).append(id)
	if int(p.to) < 0 and int(p.left) > 0:
		p.left = int(p.left) - 1
		p.last = id
		return false
	if int(p.hops) <= 0:
		return true
	p.hops = int(p.hops) - 1
	p.w = float(p.w) * HOP_KEEP
	p.to = _nearest(Vector2(p.x, p.y), p.seen)
	return int(p.to) < 0

## A conker on its hop flies at what it is hopping to, wherever that is by
## now, and lands on it; what it was after gone, it turns for the next
## nearest. False when it is spent.
func _home(p: Dictionary) -> bool:
	var id: int = p.to
	var at := _where(id)
	if at.x == INF:
		p.to = _nearest(Vector2(p.x, p.y), p.seen)
		return int(p.to) >= 0
	var from := Vector2(p.x, p.y)
	var speed: float = CART_SPEED_UP[cart]
	var d := from.distance_to(at)
	if d > speed * DT:
		var v := (at - from) / d * speed
		p.vx = v.x
		p.vy = v.y
		p.x = from.x + v.x * DT
		p.y = from.y + v.y * DT
		return true
	p.x = at.x
	p.y = at.y
	if wave_kind == Wave.WALL:
		var rc := _find(id)
		_land_cell(p, rc.x, rc.y, at)
	else:
		_land_seg(p, _seg_index(id), at)
	return not _spent(p, id)

## Where the crate with `id` is in the wall, as (row, column): (-1, -1) gone.
func _find(id: int) -> Vector2i:
	for r in rows.size():
		for c in COLS:
			if rows[r][c] != null and int(rows[r][c].id) == id:
				return Vector2i(r, c)
	return Vector2i(-1, -1)

## Where the thing with `id` is on the field: x INF when it is gone.
func _where(id: int) -> Vector2:
	if wave_kind == Wave.WALL:
		var rc := _find(id)
		return cell_pos(rc.x, rc.y) if rc.x >= 0 else Vector2(INF, INF)
	var i := _seg_index(id)
	if i < 0 or float(segs[i].dying) >= 0.0 or float(segs[i].s) < 0.0:
		return Vector2(INF, INF)
	return path_at(segs[i].s)

## The id of the nearest thing to `from` within a hop that is not in `seen`,
## -1 for none.
func _nearest(from: Vector2, seen: Array) -> int:
	var best := -1
	var near := HOP_REACH * HOP_REACH
	if wave_kind == Wave.WALL:
		for r in rows.size():
			# nothing still up over the top of the sky is reached
			if wall_y - (r + 0.5) * CELL_H < -sky:
				break
			for c in COLS:
				var cell = rows[r][c]
				if cell == null or seen.has(int(cell.id)):
					continue
				var d := cell_pos(r, c).distance_squared_to(from)
				if d < near:
					near = d
					best = cell.id
		return best
	if segs.is_empty() or segs[0].kind != Kind.HEAD:
		return -1
	for sg: Dictionary in segs:
		if float(sg.dying) >= 0.0 or float(sg.s) < 0.0 or seen.has(int(sg.id)):
			continue
		var d := path_at(sg.s).distance_squared_to(from)
		if d < near:
			near = d
			best = sg.id
	return best

func _lucky() -> bool:
	return crit_lv > 0 and _luck.randf() < crit()

## What shot `p` lands as on the thing `id`, before the luck: the pea's
## weight times its share, and on the hose times how long its drops have
## stayed on the one thing (`jet`); the cart's own first landing is what
## counts that.
func _exact(p: Dictionary, id: int) -> float:
	if cart != Cart.HOSE:
		return power * float(p.w)
	if bool(p.main) and int(p.last) < 0 and int(p.to) < 0:
		if id == _jet_id:
			_jet_n += 1
		else:
			_jet_id = id
			_jet_n = 0
	return power * float(p.w) * (jet() if id == _jet_id else 1.0)

## `x` as a whole number: what is short of one is kept for the next landing,
## so a stream of light shots takes off what it should, a few of them nothing.
func _whole(x: float) -> int:
	_part += x
	var n := int(_part + 0.0001)
	_part -= n
	return n

## What a shot's element leaves on the thing it lands on, before the blow:
## the flame lights it (as hot as this landing, `heat`), the hail leaves it
## brittle, the nettle stings it, and the gust holds whatever is coming.
func _mark(cell: Dictionary, p: Dictionary, heat: float, at: Vector2) -> void:
	match int(p.el):
		Kind.FLAME:
			_light(cell, heat)
		Kind.HAIL:
			cell.brittle = t + BRITTLE_TIME
		Kind.NETTLE:
			if float(cell.sting_t) <= 0.0:
				cell.sting_c = STING_TICK
			cell.sting = float(cell.sting) + float(p.w)
			cell.sting_t = STING_TIME
			_stinging = STING_TIME
		Kind.GUST:
			_gust_t = GUST_HOLD
			if t - _gust_said >= 0.12:
				_gust_said = t
				events.append({"type": "gust", "pos": at})

## Shot `p` lands on the crate at (`r`, `c`); `at` is where its number goes.
func _land_cell(p: Dictionary, r: int, c: int, at: Vector2) -> void:
	var cell: Dictionary = rows[r][c]
	var id: int = cell.id
	var lucky := _lucky()
	var exact := _exact(p, id) * (crit_mult(crit_lv) if lucky else 1)
	var dmg := _whole(exact)
	var half := maxi(1, int(dmg / 2.0)) if dmg > 0 else 0
	var shell := float(p.blast) > 0.0
	_mark(cell, p, exact, at)
	_hurt_cell(r, c, dmg, at, Hit.PEA, lucky, shell)
	if shell:
		_blast_wall(r, c, float(p.blast), _whole(exact * BLAST_SHARE))
	if bool(p.burst) and half > 0:
		for d: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(1, 0)]:
			var rr: int = r + d.x
			var cc: int = c + d.y
			if rr < rows.size() and cc >= 0 and cc < COLS and rows[rr][cc] != null:
				_hurt_cell(rr, cc, half, cell_pos(rr, cc), Hit.SIDE)
	if int(p.el) == Kind.ZAP and half > 0:
		_zap_wall(r, c, half)

## The same on the millipede's plate `i`.
func _land_seg(p: Dictionary, i: int, at: Vector2) -> void:
	var sg: Dictionary = segs[i]
	var id: int = sg.id
	var where := path_at(sg.s)
	var lucky := _lucky()
	var exact := _exact(p, id) * (crit_mult(crit_lv) if lucky else 1)
	var dmg := _whole(exact)
	var half := maxi(1, int(dmg / 2.0)) if dmg > 0 else 0
	var shell := float(p.blast) > 0.0
	var beside: Array = []
	if bool(p.burst) and half > 0:
		for j in [i - 1, i + 1]:
			if j >= 0 and j < segs.size():
				beside.append(segs[j].id)
	_mark(sg, p, exact, at)
	_hurt_seg(i, dmg, at, Hit.PEA, lucky, shell)
	if shell:
		_blast_milli(where, id, float(p.blast), _whole(exact * BLAST_SHARE))
	for other: int in beside:
		var j := _seg_index(other)
		if j >= 0 and float(segs[j].dying) < 0.0 and float(segs[j].s) >= 0.0:
			_hurt_seg(j, half, path_at(segs[j].s), Hit.SIDE)
	if int(p.el) == Kind.ZAP and half > 0:
		_zap_milli(id, where, half)

## A shell has landed on the crate at (`r`, `c`): every other crate within
## `reach` of it takes `dmg`, iron its whole.
func _blast_wall(r: int, c: int, reach: float, dmg: int) -> void:
	var mid := cell_pos(r, c)
	events.append({"type": "blast", "pos": mid, "r": reach})
	if dmg <= 0:
		return
	var up := int(ceilf(reach / CELL_H))
	for rr in range(maxi(0, r - up), mini(rows.size(), r + up + 1)):
		for cc in COLS:
			if (rr == r and cc == c) or rows[rr][cc] == null:
				continue
			var at := cell_pos(rr, cc)
			if at.distance_squared_to(mid) <= reach * reach:
				_hurt_cell(rr, cc, dmg, at, Hit.BOOM)

## The same round `mid` on the millipede, the plate `id` its own.
func _blast_milli(mid: Vector2, id: int, reach: float, dmg: int) -> void:
	events.append({"type": "blast", "pos": mid, "r": reach})
	if dmg <= 0:
		return
	var ids: Array = []
	for sg: Dictionary in segs:
		if int(sg.id) != id and float(sg.dying) < 0.0 and float(sg.s) >= 0.0 and path_at(sg.s).distance_squared_to(mid) <= reach * reach:
			ids.append(sg.id)
	for other: int in ids:
		if segs.is_empty() or segs[0].kind != Kind.HEAD:
			return
		var j := _seg_index(other)
		if j >= 0:
			_hurt_seg(j, dmg, path_at(segs[j].s), Hit.BOOM)

## Lightning off the crate at (`r`, `c`): on to the nearest crate in reach,
## and from that to the next, ZAP_JUMPS times, none of them twice.
func _zap_wall(r: int, c: int, dmg: int) -> void:
	var at := cell_pos(r, c)
	var pts := [at]
	var done := {Vector2i(r, c): true}
	for jump in ZAP_JUMPS:
		var best := Vector2i(-1, -1)
		var near := ZAP_REACH * ZAP_REACH
		for rr in rows.size():
			# nothing still up over the top of the sky is reached
			if wall_y - (rr + 0.5) * CELL_H < -sky:
				break
			for cc in COLS:
				if rows[rr][cc] == null or done.has(Vector2i(rr, cc)):
					continue
				var d := cell_pos(rr, cc).distance_squared_to(at)
				if d < near:
					near = d
					best = Vector2i(rr, cc)
		if best.x < 0:
			break
		done[best] = true
		at = cell_pos(best.x, best.y)
		pts.append(at)
		_hurt_cell(best.x, best.y, dmg, at, Hit.SIDE)
	if pts.size() > 1:
		events.append({"type": "zap", "pts": pts})

## The same along the millipede, off the plate `id` at `at`.
func _zap_milli(id: int, at: Vector2, dmg: int) -> void:
	var pts := [at]
	var done := {id: true}
	for jump in ZAP_JUMPS:
		if segs.is_empty() or segs[0].kind != Kind.HEAD:
			break
		var best := -1
		var near := ZAP_REACH * ZAP_REACH
		var where := at
		for j in segs.size():
			var sg: Dictionary = segs[j]
			if done.has(int(sg.id)) or float(sg.dying) >= 0.0 or float(sg.s) < 0.0:
				continue
			var q := path_at(sg.s)
			var d := q.distance_squared_to(at)
			if d < near:
				near = d
				best = j
				where = q
		if best < 0:
			break
		done[int(segs[best].id)] = true
		at = where
		pts.append(at)
		_hurt_seg(best, dmg, at, Hit.SIDE)
	if pts.size() > 1:
		events.append({"type": "zap", "pts": pts})

## `cell` is lit, as hot as `heat` (the landing that lit it): it burns from
## now, and one already alight burns as hot as the hottest that has lit it.
func _light(cell, heat: float) -> void:
	if cell == null or int(cell.hp) <= 0:
		return
	if float(cell.burn_t) <= 0.0:
		cell.burn_c = BURN_TICK
		cell.burn = heat
	else:
		cell.burn = maxf(float(cell.burn), heat)
	cell.burn_t = BURN_TIME
	_burning = BURN_TIME

## The bursts whose fuses have run out: what is next to where a thing went
## while alight catches its fire and takes FLARE_SHARE of the hit that lit
## it. One of those going bursts in its turn, a fuse later.
func _step_flares() -> void:
	if _flares.is_empty():
		return
	if gap_t > 0.0:
		_flares.clear()
		return
	var due: Array = []
	var keep: Array = []
	for f: Dictionary in _flares:
		f.t = float(f.t) - DT
		if float(f.t) <= 0.0:
			due.append(f)
		else:
			keep.append(f)
	_flares = keep
	for f: Dictionary in due:
		var heat: float = f.heat
		var dmg := maxi(1, roundi(heat * FLARE_SHARE))
		if wave_kind == Wave.WALL and f.has("off"):
			var r := floori(float(f.off) / CELL_H)
			var c: int = f.c
			events.append({"type": "flare", "pos": cell_pos(r, c)})
			for dr in [-1, 0, 1]:
				for dc in [-1, 0, 1]:
					var rr: int = r + dr
					var cc: int = c + dc
					if (dr == 0 and dc == 0) or rr < 0 or rr >= rows.size() or cc < 0 or cc >= COLS or rows[rr][cc] == null:
						continue
					_light(rows[rr][cc], heat)
					_hurt_cell(rr, cc, dmg, cell_pos(rr, cc), Hit.BURN)
		elif wave_kind == Wave.MILLI and f.has("ids"):
			events.append({"type": "flare", "pos": f.pos})
			for id: int in f.ids:
				if segs.is_empty() or segs[0].kind != Kind.HEAD:
					break
				var j := _seg_index(id)
				if j >= 0 and float(segs[j].dying) < 0.0 and float(segs[j].s) >= 0.0:
					_light(segs[j], heat)
					_hurt_seg(j, dmg, path_at(segs[j].s), Hit.BURN)

## What is alight is bitten every BURN_TICK until it burns out, and what is
## stung every STING_TICK until its stings are gone.
func _step_burns() -> void:
	if (_burning <= 0.0 and _stinging <= 0.0) or gap_t > 0.0:
		return
	_burning -= DT
	_stinging -= DT
	if wave_kind == Wave.WALL:
		for r in rows.size():
			for c in COLS:
				if rows[r][c] == null:
					continue
				var cell: Dictionary = rows[r][c]
				var bite := _burn(cell)
				if bite > 0:
					_hurt_cell(r, c, bite, cell_pos(r, c), Hit.BURN)
				var sting := _stung(cell)
				if sting > 0 and int(cell.hp) > 0:
					_hurt_cell(r, c, sting, cell_pos(r, c), Hit.STING)
		return
	var ids: Array = []
	for sg: Dictionary in segs:
		if (float(sg.burn_t) > 0.0 or float(sg.sting_t) > 0.0) and float(sg.dying) < 0.0 and float(sg.s) >= 0.0:
			ids.append(sg.id)
	for id: int in ids:
		if segs.is_empty() or segs[0].kind != Kind.HEAD:
			return
		var i := _seg_index(id)
		if i < 0:
			continue
		var sg: Dictionary = segs[i]
		var bite := _burn(sg)
		if bite > 0:
			_hurt_seg(i, bite, path_at(sg.s), Hit.BURN)
		var sting := _stung(sg)
		if sting > 0 and int(sg.hp) > 0 and not segs.is_empty() and segs[0].kind == Kind.HEAD:
			i = _seg_index(id)
			if i >= 0:
				_hurt_seg(i, sting, path_at(sg.s), Hit.STING)

## What the fire takes off `cell` this step: BURN_BITE of the hit that lit
## it, every BURN_TICK (what is short of a whole number kept for the next).
func _burn(cell: Dictionary) -> int:
	if float(cell.burn_t) <= 0.0:
		return 0
	cell.burn_t = float(cell.burn_t) - DT
	cell.burn_c = float(cell.burn_c) - DT
	if float(cell.burn_c) > 0.0:
		return 0
	cell.burn_c = float(cell.burn_c) + BURN_TICK
	cell.burn_part = float(cell.burn_part) + float(cell.burn) * BURN_BITE
	var n := int(float(cell.burn_part) + 0.0001)
	cell.burn_part = float(cell.burn_part) - n
	return n

## What its stings take off `cell` this step: each STING_RATE a second of
## what it began as. They all go STING_TIME after the last.
func _stung(cell: Dictionary) -> int:
	if float(cell.sting_t) <= 0.0:
		return 0
	cell.sting_t = float(cell.sting_t) - DT
	if float(cell.sting_t) <= 0.0:
		cell.sting = 0.0
		return 0
	cell.sting_c = float(cell.sting_c) - DT
	if float(cell.sting_c) > 0.0:
		return 0
	cell.sting_c = float(cell.sting_c) + STING_TICK
	cell.sting_part = float(cell.sting_part) + int(cell.max) * STING_RATE * float(cell.sting) * STING_TICK
	var n := int(float(cell.sting_part) + 0.0001)
	cell.sting_part = float(cell.sting_part) - n
	return n

func _seg_index(id: int) -> int:
	for i in segs.size():
		if int(segs[i].id) == id:
			return i
	return -1

## `how` is what it came off by (Hit): iron takes one of anything but a
## firecracker's or a shell's (`whole`), which it takes whole; a splash, a
## jump, a burn or a sting lands `quiet`, without a sound of its own.
## `lucky` is a crit. A brittle thing takes BRITTLE of whatever it is.
func _hurt_cell(r: int, c: int, dmg: int, at: Vector2, how := Hit.PEA, lucky := false, whole := false) -> void:
	var cell: Dictionary = rows[r][c]
	if float(cell.brittle) > t:
		dmg = roundi(dmg * BRITTLE)
	if cell.kind == Kind.IRON and how != Hit.BOOM and not whole:
		dmg = 1
	cell.hp = int(cell.hp) - dmg
	var quiet := how != Hit.PEA and how != Hit.BOOM
	events.append({"type": "hit", "pos": at, "id": cell.id, "kind": cell.kind, "hp": maxi(0, cell.hp), "max": cell.max, "quiet": quiet,
		"dmg": dmg, "crit": lucky, "how": how})
	if cell.hp > 0:
		return
	var pos := cell_pos(r, c)
	rows[r][c] = null
	if float(cell.burn_t) > 0.0:
		_flares.append({"t": FLARE_FUSE, "pos": pos, "off": wall_y - pos.y, "c": c, "heat": float(cell.burn)})
	_killed(cell, pos)
	if cell.kind == Kind.BOMB:
		events.append({"type": "boom", "pos": pos})
		var blast := maxi(2, int(ceilf(hp_base(wave) * 3.0)))
		for dr in [-1, 0, 1]:
			for dc in [-1, 0, 1]:
				var rr: int = r + dr
				var cc: int = c + dc
				if rr >= 0 and rr < rows.size() and cc >= 0 and cc < COLS and rows[rr][cc] != null:
					_hurt_cell(rr, cc, blast, cell_pos(rr, cc), Hit.BOOM)

func _hurt_seg(i: int, dmg: int, at: Vector2, how := Hit.PEA, lucky := false, whole := false) -> void:
	var sg: Dictionary = segs[i]
	if float(sg.brittle) > t:
		dmg = roundi(dmg * BRITTLE)
	if sg.kind == Kind.IRON and how != Hit.BOOM and not whole:
		dmg = 1
	sg.hp = int(sg.hp) - dmg
	var quiet := how != Hit.PEA and how != Hit.BOOM
	events.append({"type": "hit", "pos": at, "id": sg.id, "kind": sg.kind, "hp": maxi(0, sg.hp), "max": sg.max, "quiet": quiet,
		"dmg": dmg, "crit": lucky, "how": how})
	if sg.hp > 0:
		return
	_seg_dirty = true
	var pos := path_at(sg.s)
	if sg.kind == Kind.HEAD:
		# the head gone, the rest goes off plate by plate
		segs.remove_at(i)
		_killed(sg, pos)
		for k in segs.size():
			segs[k].dying = 0.12 + 0.07 * k
		return
	if float(sg.burn_t) > 0.0:
		var ids: Array = []
		for j in [i - 1, i + 1]:
			if j >= 0 and j < segs.size():
				ids.append(segs[j].id)
		_flares.append({"t": FLARE_FUSE, "pos": pos, "ids": ids, "heat": float(sg.burn)})
	segs.remove_at(i)
	_killed(sg, pos)
	_push += KNOCK
	events.append({"type": "knock"})

## A crate or a plate gone: the score, the streak, its energy, and one more
## of a gift crate's gift, kept for when it is wanted.
func _killed(cell: Dictionary, pos: Vector2, popped := false) -> void:
	var kind: int = cell.kind
	var worth: int = int(cell.max)
	var pay := ENERGY_CRATE
	if kind == Kind.GOLD:
		worth *= GOLD_WORTH
		pay *= GOLD_WORTH
	elif kind == Kind.HEAD:
		# a millipede is fewer plates than a wall is crates: its head makes
		# the wave up to a wall's worth
		pay *= maxf(1.0, wave_crates(wave) - milli_n)
	# in orbs; what is short of one is kept for the next crate
	_orb_part += pay * (1.0 + ENERGY_STEP * energy_lv) * ORBS
	var got := int(_orb_part)
	_orb_part -= got
	energy += got
	earned += got
	score += worth
	kills += 1
	streak += 1
	best_streak = maxi(best_streak, streak)
	_streak_t = STREAK_GAP
	events.append({"type": "kill", "pos": pos, "kind": kind, "points": worth, "max": cell.max, "id": cell.id,
		"streak": streak, "popped": popped, "energy": got})
	if holds_gift(kind):
		_take(kind, pos)

## A gift crate broken: one more of its gift is had (`count`: how many
## now). Nothing starts until `use()`.
func _take(kind: int, at: Vector2) -> void:
	caught += 1
	stock[kind - Kind.FAN] = int(stock[kind - Kind.FAN]) + 1
	events.append({"type": "gift", "pos": at, "kind": kind, "count": has(kind)})

## How many of gift `kind` are had and not used.
func has(kind: int) -> int:
	return int(stock[kind - Kind.FAN]) if holds_gift(kind) else 0

## Whether a gift of `kind` can be started now: there is one, and a wave is
## on to use it against.
func can_use(kind: int) -> bool:
	return phase == Phase.PLAY and gap_t <= 0.0 and has(kind) > 0

## Starts one gift of `kind` (`left`: how many are still had). A shape runs
## with whatever else is running; an element takes the place of the other
## element. One started while its like is running adds its time to what is
## left, so none is ever spent for nothing.
func use(kind: int) -> bool:
	if not can_use(kind):
		return false
	stock[kind - Kind.FAN] = int(stock[kind - Kind.FAN]) - 1
	used += 1
	if kind == Kind.FROST:
		frost_t += FROST_TIME
	elif kind == Kind.SHOVE:
		_shove()
	elif is_element(kind):
		element_t = element_t + POD_TIME if element == kind else POD_TIME
		element = kind
	else:
		shape_t[kind - Kind.FAN] = float(shape_t[kind - Kind.FAN]) + POD_TIME
	events.append({"type": "use", "kind": kind, "left": has(kind)})
	return true

## Everything coming goes back a way: the wall up, the millipede along
## its path.
func _shove() -> void:
	if wave_kind == Wave.WALL:
		wall_y = maxf(wall_y - SHOVE_WALL, minf(wall_y, RUSH_Y))
	elif not segs.is_empty() and segs[0].kind == Kind.HEAD:
		var s: float = segs[0].s
		segs[0].s = maxf(s - SHOVE_MILLI, minf(s, 260.0))
		for i in range(1, segs.size()):
			segs[i].s = minf(float(segs[i].s), float(segs[i - 1].s) - SPACING)

# --- the waves ---

func _deal() -> void:
	wave += 1
	_flares.clear()
	_jet_id = -1
	_jet_n = 0
	wave_kind = Wave.MILLI if wave % 3 == 0 else Wave.WALL
	if wave_kind == Wave.WALL:
		_deal_wall()
	else:
		_deal_milli()
	events.append({"type": "wave", "wave": wave, "kind": wave_kind})

## How many gift crates (or plates) wave `w` holds.
static func gift_count(w: int) -> int:
	return mini(1 + int(w / 3.0), 4)

func _shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var held = a[i]
		a[i] = a[j]
		a[j] = held

## A pod that is not `last`.
func _a_pod(last: int) -> int:
	var pods: Array = range(Kind.FAN, Kind.GUST + 1)
	pods.erase(last)
	return pods[rng.randi_range(0, pods.size() - 1)]

## A pod that runs together with `pod`: an element for a shape, a shape for
## an element.
func _a_match(pod: int) -> int:
	var pods: Array = range(Kind.ZAP, Kind.GUST + 1) if is_shape(pod) else [Kind.FAN, Kind.PIERCE, Kind.BURST]
	return pods[rng.randi_range(0, pods.size() - 1)]

## What a wave's `count` gifts are, in the order they are met: a pod first,
## never the one the wave before began with, and after it the frost (from
## wave 3), the shove (from wave 4) and one more pod, in any order. The
## second pod is one that runs together with the first, so no wave holds two
## pods of which one is wasted.
func _plan_gifts(count: int) -> Array:
	var first := _a_pod(_last_pod)
	_last_pod = first
	var extras: Array = [_a_match(first)]
	if wave >= 3:
		extras.append(Kind.FROST)
	if wave >= 4:
		extras.append(Kind.SHOVE)
	_shuffle(extras)
	extras.resize(clampi(count - 1, 0, extras.size()))
	extras.push_front(first)
	return extras

## Where a wave's gifts go among `n` places (a wall's rows over the lowest,
## a millipede's plates), in the order they are met: spread along them, each
## on a place of its own.
func _gift_places(plan: Array, n: int) -> Array:
	var count := plan.size()
	var places: Array = []
	for i in count:
		var at := int((i + rng.randf()) * n / count)
		var low: int = 0 if i == 0 else int(places[i - 1]) + 1
		places.append(clampi(at, low, n - count + i))
	return places

## How many iron crates wave `w` holds.
static func iron_count(w: int) -> int:
	return 0 if w < 5 else mini(1 + int((w - 5) / 4.0), 4)

func _cell(kind: int, hp: int) -> Dictionary:
	_next_id += 1
	return {"kind": kind, "hp": maxi(1, hp), "max": maxi(1, hp), "id": _next_id - 1, "burn_t": 0.0, "burn_c": 0.0, "burn": 0.0, "burn_part": 0.0,
		"sting": 0.0, "sting_t": 0.0, "sting_c": 0.0, "sting_part": 0.0, "brittle": 0.0}

## A wall: rows of crates, the higher the heavier, with gaps, one to four
## gifts up it, a firecracker from wave four and a golden crate now and then.
func _deal_wall() -> void:
	rows.clear()
	var n := mini(WALL_ROWS + int(wave / 2.0), WALL_ROWS_MAX)
	var base := hp_base(wave)
	for r in n:
		var row: Array = []
		for c in COLS:
			var gap := WALL_GAP if r > 0 else WALL_GAP_LOW
			if rng.randf() < gap:
				row.append(null)
				continue
			var hp := base * (1.0 + 0.3 * r) * rng.randf_range(0.7, 1.3)
			if rng.randf() < 0.08:
				hp *= 2.0
			row.append(_cell(Kind.CRATE, roundi(hp)))
		rows.append(row)
	var plan := _plan_gifts(gift_count(wave))
	var at := _gift_places(plan, n - 1)
	for i in plan.size():
		var r: int = int(at[i]) + 1
		rows[r][rng.randi_range(0, COLS - 1)] = _cell(plan[i], roundi(base * (0.5 + 0.12 * r)))
	if wave >= 4:
		_scatter(1 + int(wave >= 9), n, func(r: int) -> Dictionary: return _cell(Kind.BOMB, roundi(base * (0.8 + 0.2 * r))))
	if wave >= 2 and rng.randf() < 0.6:
		_scatter(1, n, func(r: int) -> Dictionary: return _cell(Kind.GOLD, roundi(base * (1.6 + 0.3 * r))))
	_scatter(iron_count(wave), n, func(_r: int) -> Dictionary: return _cell(Kind.IRON, iron_hp(wave)))
	wall_y = 0.0
	wall_speed = 6.5 + 0.45 * mini(wave, 20)

## Puts `count` cells made by `make` on rows of their own, clear of the
## lowest and of each other.
func _scatter(count: int, n: int, make: Callable) -> void:
	for i in count:
		for tries in 12:
			var r := rng.randi_range(1 if n > 1 else 0, n - 1)
			var c := rng.randi_range(0, COLS - 1)
			var here = rows[r][c]
			if here == null or int(here.kind) == Kind.CRATE:
				rows[r][c] = make.call(r)
				break

func _step_wall() -> void:
	while not rows.is_empty() and _row_empty(rows[0]):
		rows.pop_front()
		wall_y -= CELL_H
		for f: Dictionary in _flares:
			if f.has("off"):
				f.off = float(f.off) - CELL_H
	if rows.is_empty():
		_cleared()
		return
	if _gust_t > 0.0 and wall_y >= RUSH_Y:
		# the gust drives it back up, as far as where it stops hurrying down
		wall_y = maxf(RUSH_Y, wall_y - wall_speed * GUST_BACK * DT)
	else:
		wall_y += wall_speed * (RUSH if wall_y < RUSH_Y else _slow()) * DT
	if wall_y >= DANGER:
		_end("wall")

static func _row_empty(row: Array) -> bool:
	for c in row:
		if c != null:
			return false
	return true

## The millipede: a head and so many plates behind it, its gifts spread
## down its length.
func _deal_milli() -> void:
	segs.clear()
	_push = 0.0
	var n := mini(MILLI_PLATES + wave, MILLI_PLATES_MAX)
	var plan := _plan_gifts(gift_count(wave))
	var at := _gift_places(plan, n)
	var base := hp_base(wave) * 1.5
	var head := _cell(Kind.HEAD, roundi(base * HEAD_WORTH))
	head.s = 0.0
	head.dying = -1.0
	segs.append(head)
	for i in n:
		var kind := Kind.CRATE
		if at.has(i):
			kind = plan[at.find(i)]
		elif i % 7 == 5:
			kind = Kind.GOLD
		elif i % 5 == 3 and wave >= 9:
			kind = Kind.IRON
		var hp := base * rng.randf_range(0.7, 1.3) * (0.5 if holds_gift(kind) else (1.6 if kind == Kind.GOLD else 1.0))
		if kind == Kind.IRON:
			hp = iron_hp(wave) * 0.5
		var sg := _cell(kind, roundi(hp))
		sg.s = -(i + 1) * SPACING
		sg.dying = -1.0
		segs.append(sg)
	milli_n = n
	milli_speed = 20.0 + 0.7 * mini(wave, 24)

func _step_milli() -> void:
	if segs.is_empty():
		_cleared()
		return
	# the tail going off after the head
	if segs[0].kind != Kind.HEAD:
		var i := 0
		while i < segs.size():
			var sg: Dictionary = segs[i]
			sg.dying = float(sg.dying) - DT
			if sg.dying <= 0.0:
				segs.remove_at(i)
				_killed(sg, path_at(sg.s), true)
			else:
				i += 1
		return
	var head: Dictionary = segs[0]
	# the shorter it is, the quicker it runs
	var hurry := 1.0 + MILLI_HURRY * (1.0 - float(segs.size() - 1) / maxf(1.0, milli_n))
	var speed := milli_speed * (RUSH if float(head.s) < 260.0 else hurry * _slow())
	var back := minf(_push, 150.0 * DT)
	_push -= back
	if _gust_t > 0.0 and float(head.s) >= 260.0:
		head.s = maxf(260.0, float(head.s) - milli_speed * GUST_BACK * DT - back)
	else:
		head.s = maxf(0.0, float(head.s) + speed * DT - back)
	for i in range(1, segs.size()):
		var sg: Dictionary = segs[i]
		var want: float = float(segs[i - 1].s) - SPACING
		if float(sg.s) > want:
			sg.s = want
		else:
			sg.s = minf(want, float(sg.s) + speed * CATCH_UP * DT)
	if float(head.s) >= path_len():
		_end("milli")

func _cleared() -> void:
	var bonus := 50 * wave
	score += bonus
	events.append({"type": "clear", "wave": wave, "bonus": bonus, "kind": wave_kind})
	gap_t = GAP_TIME

func _end(why: String) -> void:
	phase = Phase.OVER
	phase_t = 0.0
	events.append({"type": "over", "why": why})

## The Second chance (arcade/boosters.gd): the wall is shoved back up four
## rows, the millipede a long way back along its path.
func revive() -> void:
	if phase != Phase.OVER:
		return
	phase = Phase.PLAY
	phase_t = 0.0
	_warned = false
	if wave_kind == Wave.WALL:
		wall_y = minf(wall_y, DANGER) - CELL_H * 4.5
	elif not segs.is_empty():
		segs[0].s = maxf(float(segs[0].s) - 700.0, 260.0)
	events.append({"type": "revive"})
