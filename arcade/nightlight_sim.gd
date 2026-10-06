extends RefCounted

## Nightlight, as pure data: a star in the middle of a night sky, the gas
## poured into the disc round it, the bodies that gas condenses into, what
## passes on its own, the chain of elements the star burns through, four
## tiles for the hand bought with light, the powers the star is offered as it
## grows, and the two ways its life ends, each of which leaves a small star
## again among the gas the last one threw off. Kept and without an end (the
## user, 2026-10-06: "the run never ends, but player can rebirth star to buy
## some new perks that make journey faster and faster").
## Spec docs/superpowers/specs/2026-10-06-arcade-nightlight-design.md.
##
## It follows a real star (the user, 2026-10-06: "I want something that is
## closer to the star lifecycle ... Check on web about how the sun behave and
## bodies around it, that's the whole idea"):
##
## - A young star is fed by a disc of gas. Gas rubs on gas, loses its turn
##   and winds in, and what the fall gives up leaves as light. That is the
##   haze here: inside it everything is dragged, and the drag's work is the
##   income.
## - The disc is nearly all gas and a hundredth dust. The dust of two puffs
##   that meet sticks into a grain, a grain sweeps the dust of every puff it
##   crosses, grains gather into rocks and planets, and a planet heavy enough
##   starts keeping the gas as well. Past the frost line ice joins in.
## - The gas carries what is small with it and cannot move what is big: a
##   grain winds in with the gas, a planet stays for a long time.
## - The star's pull is uneven across a body, and close enough that tide is
##   more than what holds the body together (`_tear`).
## - The star burns the lightest thing it has into the next: hydrogen into
##   helium, and once there is core enough of each, helium into carbon,
##   carbon into neon, neon into oxygen, oxygen into silicon, silicon into
##   iron. Each pays less than the last and goes quicker. Iron pays nothing,
##   and a core of it past 1.4 Suns falls in on itself: the supernova.
##
## Nothing here draws or reads the clock. The screen
## (arcade/nightlight_screen.gd) calls `advance`, drains `events`, plays the
## end when `ending()` says so and keeps the file;
## `tests/_probe_nightlight.gd` plays it with a bot. Lengths are the screen's
## own 1080-wide pixels as the game starts, measured from the star at (0, 0);
## the view draws back as the star grows (`zoom`).

enum Kind { GAS, GRAIN, ROCK, COMET, PLANET, GIANT }

## One thing in the sky. `h` is the share of it that is hydrogen. A puff of
## gas has `dust`, the share of it that is solid and has not fallen out yet,
## and `age`, the seconds it has been up. A solid has `ice`, the share of it
## that is ice, and `grip`, how much of the disc's drag takes hold of it. `e`
## is the light the disc has made of it and not yet let go; `heat` how deep
## in the disc it is, 0 outside.
class Body:
	var id := 0
	var kind := Kind.GAS
	var m := 1.0
	var h := 0.0
	var dust := 0.0
	var ice := 0.0
	var age := 0.0
	var grip := 1.0
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var spin := 0.0
	var turn := 0.0
	var e := 0.0
	var heat := 0.0

const STEP := 1.0 / 60.0
## Gravity for a star of one mass, the disc's drag at the star's surface (a
## share of a puff's speed a second) and the light a perfect spiral from far
## off pays for each of a body's mass.
##
## Everything is slow (the user, 2026-10-06, a second time: "movement of
## bodies should be slower, it should be a slower relaxing game"): a round
## at the Roche radius takes half a minute and one at the disc's edge a
## minute and a half, at 46 and 33 px/s. To change the speed and keep every
## path's shape, move G by the square and SPARE, TUMBLE and DRAG by the
## factor itself.
const G := 4.8e4
const DRAG := 0.011
const LIGHT := 6.0
## The drag at the disc's edge, as a share of the drag at the star: a disc
## flows in all the way out, or what is set down at its rim would hang there.
const THIN := 0.3
## A new star's mass and its radius; a radius is the cube root of a mass.
## The star is wide and the bodies small (the user: "make sun way bigger
## related to the bodies around"): a planet as heavy as a thousandth of the
## star is a sixteenth of it across, a grain a fiftieth.
const START := 10.0
const STAR_R := 150.0
## Past SEEN pixels on the screen the star grows only by the logarithm and
## the view draws back instead.
const SEEN := 150.0
const SEEN_LOG := 40.0
## A body is eaten this far inside the star's edge.
const EAT := 0.94
## The disc is this many of the star's radii wide, before the Wide haze.
const HAZE := 3.0
## Past this many of the star's radii water is ice.
const FROST := 2.2
## A solid's radius is the cube root of its mass times this: rock is denser
## than a star.
const BODY_R := 44.0

## A puff of gas, before the Puff tile: two thousandths of a Sun (the user:
## "going from 1x -> 2x sun is not so fast like throwing 3 bodies into it").
## H of it is hydrogen, DUSTY of it dust, and GAS_HE of the rest helium. A
## heavier puff (the tile, the perk) is more gas and the same dust: what the
## hand is worth feeds the star, and the planets come at their own pace.
const PUFF := 0.02
const PUFF_H := 0.7
const DUSTY := 0.01
const GAS_HE := 0.93
## Gas comes in at the disc's rim, between IN_NEAR and IN_FAR of its radius
## and within IN_WIDE radians of a place that goes round the star once in
## IN_TURN seconds, so it arrives as a stream and meets itself.
const IN_NEAR := 0.7
const IN_FAR := 0.97
const IN_WIDE := 0.5
const IN_TURN := 200.0
## The most puffs in the sky; one more is poured into the last.
const MOST := 150
## The most solids the gas makes by itself.
const SOLIDS := 24
## Nothing is torn, and nothing more is let in, while the sky holds FULL.
const FULL := 300

## Condensing. A puff has to be up COOL seconds before its dust falls out.
## Two that are MEET px apart (as the game starts; it widens with the star)
## make a grain of their dust. Past the frost line there is ICY as much ice
## again as dust. A solid takes the dust of a puff that comes within its own
## radius and FEED of it more, and gathers a solid it touches or comes that
## near. From CORE_M up it keeps GULP of the gas too, each time they are
## looked at and never more than GULP_M at once, until it weighs GIANT_MOST.
const COOL := 12.0
const MEET := 30.0
const ICY := 2.0
const ICE_H := 0.4
const FEED := 0.6
const TOUCH := 0.8
const CORE_M := 0.012
const GULP := 0.06
const GULP_M := 0.0003
const GIANT_MOST := 0.04
## What is looked at for meeting every MEET_EVERY ticks: nothing here moves
## five pixels in that time.
const MEET_EVERY := 6
## A solid lighter than GRAIN_M is a grain, one lighter than PLANET_M a rock;
## with ICE_LOOK of it ice it is a comet until it is a planet, and with
## GASSY of it hydrogen and CORE_M of mass it is a giant.
const GRAIN_M := 0.002
const PLANET_M := 0.008
const ICE_LOOK := 0.3
const GASSY := 0.3
## The disc has all of its hold on a body GRIP_R px in radius and smaller,
## and less on a bigger one by the square: a planet a thousandth of a Sun is
## dragged a tenth as hard as the gas.
const GRIP_R := 3.0

## What passes on its own, by Kind, before the sky is any richer: nothing
## for gas, then a pebble, a rock, a comet, a planetoid.
const MASS := [0.0, 0.0008, 0.003, 0.0015, 0.01, 0.0]
const PASS_ICE := [0.0, 0.0, 0.1, 0.8, 0.3, 0.0]
## A passing body is a pebble this often, a rock up to the second figure, a
## comet up to the third, a planetoid for the rest.
const MIX := [0.45, 0.7, 0.93]
## A passer starts this far out and aims to miss the star by up to MISS,
## both in the screen's pixels; it has SPARE px/s over what gravity gives it,
## so gravity alone bends it and lets it go. PROGRADE of them turn the way
## the disc turns. Past FAR and leaving, a body is gone.
const SPAWN := 1350.0
const MISS := 700.0
const SPARE := 32.0
const PROGRADE := 0.8
const FAR := 2400.0
## Seconds between passers round a star of one Sun, and the wait is that
## times something in here. A heavier star draws them sooner, by its Suns to
## the power DRAWN (the user: "as the star grow it start to pull more objects
## around because of gravity"); its pull also bends more of them in.
const PASS := 7.0
const GAP_MIN := 0.6
const GAP_MAX := 1.4
const DRAWN := 0.3
## Light is let go in pieces, never less than this.
const PIECE := 0.05

## The tide (the user, 2026-10-06: "something orbiting sun too close should
## rip apart into smaller pieces"). The star pulls a body's near side harder
## than its far side, by GM x its radius / r^3. A big body is held by its own
## weight, which also goes by its radius, so it is torn at one distance
## whatever its size: ROCHE of the star's radii. A small one is a stone and
## held by that too, the more the smaller it is, so it gets nearer: a body
## HOLD px in radius is as much stone as weight, and torn the cube root of
## two nearer. A denser star (the Core perk) tears from further out. Gas is
## not torn: there is nothing of it to tear.
const ROCHE := 1.5
const HOLD := 5.0
## Nothing is torn lighter than twice CRUMB, and a body goes in PIECES at
## most at a time.
const CRUMB := 0.002
const PIECES := 3
## A piece starts this share of its body's radius from the body's middle.
const APART := 0.55

## What the star is made of and what it burns (the user, 2026-10-06: "add
## the sun fusion physic on it ... light elements fusion into heavy
## elements"). A new star is one Sun: STAR_H of it hydrogen and STAR_HE
## helium, the rest rock. It burns in STAGES steps, each turning one element
## into the next of CHAIN: hydrogen into helium from the start; helium once
## the helium it has MADE is a core of FLASH Suns (the helium flash, at a
## hundred million kelvin); carbon once there is a core of CARBON Suns of it
## and the star weighs HEAVY Suns (a lighter star's core never gets hot
## enough); and each of the last three once there is NEXT Suns of what it
## burns. An iron core of IRON Suns cannot hold itself up.
const CHAIN := ["h", "he", "c", "ne", "o", "si", "fe"]
const STAGES := 6
const STAR_H := 0.7
const STAR_HE := 0.28
const FLASH := 0.45
const CARBON := 1.06
const HEAVY := 8.0
const NEXT := 0.25
const IRON := 1.4
## The core's temperature while each stage is the last one lit, in millions
## of kelvin.
const CORE_TEMP := [15.0, 100.0, 600.0, 1200.0, 1500.0, 2700.0]
## A star of one Sun burns BURN of its own mass in hydrogen a second, and a
## heavier one more of itself, by its Suns to the power HOT (a real star's is
## 2.5, and a heavy one is gone in no time). Each later stage burns RATE as
## fast as that and pays SHINE light a mass: less every time, and quicker (a
## real star of twenty-five Suns has seven million years of hydrogen and one
## day of silicon).
const BURN := 0.00007
const HOT := 0.3
const RATE := [1.0, 1.5, 3.0, 5.0, 5.0, 8.0]
const SHINE := [30.0, 10.0, 5.0, 3.5, 3.5, 2.0]
## Out of hydrogen that stage sleeps until WAKE of the star is hydrogen
## again. With nothing burning at all the star is dim: its powers sleep, and
## after GRACE seconds of that it lets its layers go. DIM seconds from lit to
## dim and back.
const WAKE := 0.02
const GRACE := 60.0
const DIM := 1.5
## Burning carbon, or anything at all with its hydrogen gone, the star is a
## giant: GIANT wider and GIANT_K at the surface whatever it weighs (a red
## supergiant's 3,600 K), SWELL seconds getting there.
const GIANT := 0.28
const GIANT_K := 3600.0
const SWELL := 30.0
## Its surface temperature in kelvin, by its Suns; a dim star is COLD of
## that.
const TEMP := [[1.0, 5800.0], [2.0, 9000.0], [4.0, 14000.0], [8.0, 22000.0], [16.0, 30000.0], [60.0, 42000.0]]
const COLD := 0.5

## The shop is the hand's (the user, 2026-10-06: "the shop should be related
## to what player can do"): a heavier puff, one more of them at a time, a
## quicker flow while the button is held, and gas with more hydrogen in it.
const TILES := ["puff", "volley", "stream", "pure"]
## A tile's first price in light, what each level multiplies it by, and its
## last level (0: it has none).
const TILE := {
	"puff": [12.0, 1.8, 0],
	"volley": [150.0, 3.5, 0],
	"stream": [30.0, 2.0, 0],
	"pure": [20.0, 1.9, 6],
}
## A level of the Puff tile is PUFF_STEP of a first puff more. Held, the
## button lets a puff go every STREAM seconds, each level of the tile
## STREAM_STEP of that, never under STREAM_LEAST. A level of Pure is
## PURE_STEP more of a puff in hydrogen.
const PUFF_STEP := 0.5
const STREAM := 0.6
const STREAM_STEP := 0.88
const STREAM_LEAST := 0.08
const PURE_STEP := 0.04

## The star's powers (the user, 2026-10-06: "the sun powerup come as it grow,
## giving user powerup decisions to pick ... a powerup to use more fuel to
## create a solar wind that interfer in surrounding bodies orbit to make them
## start fall, or a another powerup that goes into a different direction").
## At each of MILES Suns, and every doubling after the last, two are offered
## that go different ways (WAY: 0 catches more, 1 makes more light, 2 saves
## hydrogen) and one is picked. A power is always on while the star is lit,
## burns COST of the star's plain burning more for each level, and goes with
## the star when it ends.
const POWERS := ["wind", "haze", "beacon", "radiance", "furnace", "fusion", "thrift"]
const WAY := {"wind": 0, "haze": 0, "beacon": 0, "radiance": 1, "furnace": 1, "fusion": 1, "thrift": 2}
const COST := {"wind": 0.4, "haze": 0.25, "beacon": 0.3, "radiance": 0.3, "furnace": 0.25, "fusion": 0.2, "thrift": 0.0}
const MILES := [2.0, 4.0, 8.0, 15.0, 30.0, 60.0]
## Solar wind: a drag of WIND a level on what is outside the disc, out to
## WIND_REACH of its radius, so what is parked there comes down. It makes no
## light. Wide haze: HAZE_STEP wider a level. Beacon: bodies pass BEACON_SOON
## sooner and BEACON_RICH heavier. Radiance: RADIANCE more light from the
## disc. Tidal furnace: a torn body pays FURNACE light a mass. Fusion: the
## star's own burning pays one SHINE more a level. Thrift: it burns THRIFT as
## much.
const WIND := 0.006
const WIND_REACH := 3.0
const HAZE_STEP := 1.15
const BEACON_SOON := 0.8
const BEACON_RICH := 1.2
const RADIANCE := 0.3
const FURNACE := 200.0
const THRIFT := 0.7

## A supernova pays DUST stardust and a heavier star more, by the square root
## of its Suns over HEAVY. A star that only lets go pays FADE_DUST.
const DUST := 3.0
const FADE_DUST := 1
## The first perk costs this much stardust, and each one after a dust more.
const PERK := 2
const PERKS := ["core", "disc", "hand", "crowd", "ember"]
const CORE := 0.15
const DISC := 0.25
const HAND := 0.3
const CROWD := 0.85
const EMBER := 2.0
## Every supernova so far makes what passes this much heavier, for good.
const RICHER := 0.5
## What a star leaves: ASHES puffs of gas and ASHES_LOG more for every
## tenfold of its Suns, ASHES_MOST at most (FADE_ASHES when it only let go),
## each ASH_M puffs heavy and ASH_DUST of it dust, since it is what a star
## made: the next star's planets come quicker. Each is on a closed path
## whose nearest point to the new star is ASH_NEAR to ASH_NEAR + ASH_REACH
## of its radii and whose furthest is inside ASH_FAR of them.
const ASHES := 14.0
const ASHES_LOG := 10.0
const ASHES_MOST := 40
const FADE_ASHES := 8
const ASH_M := 3.0
const ASH_DUST := 0.05
const ASH_H := 0.5
const ASH_NEAR := 1.7
const ASH_REACH := 1.2
const ASH_FAR := 4.2
## A body tumbles up to this many radians a second, either way.
const TUMBLE := 0.3

## Where the star is kept, and which way of keeping it this is. A harness
## points `path` elsewhere.
static var path := "user://nightlight.cfg"
const KEPT := 2

var mass := START
var light := 0.0
var dust := 0
var novas := 0
var fades := 0
var bought := 0
var lv := {"puff": 0, "volley": 0, "stream": 0, "pure": 0}
var perk := {"core": 0, "disc": 0, "hand": 0, "crowd": 0, "ember": 0}
## The hydrogen left to burn, and the helium that came with the gas and lies
## over the core, both in mass.
var fuel := START * STAR_H
var env := START * STAR_HE
## What the star has made and not yet burnt on: helium, carbon, neon, oxygen,
## silicon, iron (CHAIN from its second). The rest of the star is rock.
var made: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
## The stages that have lit; the first always has.
var ignited: Array[bool] = [true, false, false, false, false, false]
## False while the hydrogen is out (it lights again at WAKE).
var h_on := true
## False while nothing burns at all; `lit` follows it, 0 to 1, `cold` counts
## the seconds of it, and `swell` is how much of a giant the star is.
var awake := true
var lit := 1.0
var cold := 0.0
var swell := 0.0
var power := {"wind": 0, "haze": 0, "beacon": 0, "radiance": 0, "furnace": 0, "fusion": 0, "thrift": 0}
## The powers picked this life, and the two on offer (empty when none is).
var picks := 0
var offer: Array = []
var bodies: Array[Body] = []
var clock := 0.0
## What happened since the screen last looked, oldest first:
## {kind: "eat", at, m, gas}, {kind: "shed", at, e}, {kind: "form", at},
## {kind: "merge", at}, {kind: "tear", at, m}, {kind: "shine", e},
## {kind: "ignite", stage}, {kind: "dim"}, {kind: "wake"}.
var events: Array[Dictionary] = []
## Everything this star and the ones before it ate, for the record.
var eaten := 0.0
## False for a sky with nothing crossing it (a tutorial's page), and for a
## star that burns nothing (the same).
var passing := true
var burning := true

var _rng := RandomNumberGenerator.new()
var _next_id := 1
var _tick := 0
var _acc := 0.0
var _pass_wait := 0.0
var _pass_gap := 4.0
var _shine := 0.0
var _inlet := 0.0

func _init(rng_seed := 0) -> void:
	if rng_seed != 0:
		_rng.seed = rng_seed
	else:
		_rng.randomize()
	_inlet = _rng.randf() * TAU

# --- what the star and the tiles are worth ---

## The star as its mass alone makes it: what the disc, the frost line and
## the tide are measured in.
func main_r() -> float:
	return STAR_R * pow(mass / START, 1.0 / 3.0)

## The star as the world has it: a giant is wider.
func star_r() -> float:
	return main_r() * (1.0 + GIANT * swell)

## The star as the screen shows it.
func seen_r() -> float:
	var r := star_r()
	return r if r < SEEN else SEEN + SEEN_LOG * log(r / SEEN)

## Screen pixels to one of the world's.
func zoom() -> float:
	return seen_r() / star_r()

## A new star is one Sun.
func suns() -> float:
	return mass / START

## All of its helium: what came with the gas and what it made.
func helium() -> float:
	return env + made[0]

## What it is made of, as shares of its mass in CHAIN's order with rock last.
func layers() -> Array[float]:
	var out: Array[float] = [fuel / mass, helium() / mass]
	var sum := out[0] + out[1]
	for i in range(1, STAGES):
		out.append(made[i] / mass)
		sum += made[i] / mass
	out.append(maxf(0.0, 1.0 - sum))
	return out

## The levels of a power that are doing something: none while the star is dim.
func on(which: String) -> int:
	return int(power[which]) if awake else 0

## The hydrogen the star burns a second while that is lit: its plain burning,
## and what its powers add.
func burn_rate() -> float:
	return _plain_burn() * (1.0 + _more())

func _plain_burn() -> float:
	return BURN * mass * pow(suns(), HOT) * pow(THRIFT, int(power.thrift))

## What the powers burn, as a share of the plain burning.
func _more() -> float:
	var more := 0.0
	for which: String in POWERS:
		more += float(COST[which]) * int(power[which])
	return more

## Seconds the hydrogen lasts as the star burns now, with nothing more eaten.
func fuel_time() -> float:
	return fuel / burn_rate()

## The heaviest stage that has lit.
func stage() -> int:
	var at := 0
	for i in STAGES:
		if ignited[i]:
			at = i
	return at

## The core's temperature, in millions of kelvin.
func core_temp() -> float:
	return CORE_TEMP[stage()]

## The star's surface temperature, in kelvin: hotter the heavier, cooler as a
## giant, and cold while dim.
func temp() -> float:
	var s := suns()
	var k: float = TEMP[TEMP.size() - 1][1]
	if s <= float(TEMP[0][0]):
		k = TEMP[0][1]
	else:
		for i in range(1, TEMP.size()):
			if s <= float(TEMP[i][0]):
				var from := log(float(TEMP[i - 1][0]))
				k = lerpf(TEMP[i - 1][1], TEMP[i][1], (log(s) - from) / (log(float(TEMP[i][0])) - from))
				break
	return lerpf(k, GIANT_K, swell) * lerpf(COLD, 1.0, lit)

## What the star is on its way to, for the screen's line: {which: "he" / "c"
## / "fe" / "dim", have, need}, in Suns of core, or in seconds for a dim
## star; `heavy` false while a carbon core waits for the star to weigh
## enough.
func goal() -> Dictionary:
	if not awake:
		return {"which": "dim", "have": cold, "need": GRACE, "heavy": true}
	if not ignited[1]:
		return {"which": "he", "have": made[0] / START, "need": FLASH, "heavy": true}
	if not ignited[2]:
		return {"which": "c", "have": made[1] / START, "need": CARBON, "heavy": suns() >= HEAVY}
	return {"which": "fe", "have": made[5] / START, "need": IRON, "heavy": true}

## The disc's width, in the star's own radii.
func haze_wide() -> float:
	return HAZE * pow(HAZE_STEP, on("haze"))

## How far the solar wind reaches; 0 with none.
func wind_r() -> float:
	return haze_r() * WIND_REACH if on("wind") > 0 else 0.0

func haze_r() -> float:
	return main_r() * haze_wide()

## Past this, water is ice.
func frost_r() -> float:
	return main_r() * FROST

func gm() -> float:
	return G * (1.0 + CORE * int(perk.core)) * mass

func glow() -> float:
	return (1.0 + RADIANCE * on("radiance")) * (1.0 + DISC * int(perk.disc))

func puff_mass() -> float:
	return PUFF * (1.0 + PUFF_STEP * int(lv.puff)) * (1.0 + HAND * int(perk.hand))

## The share of a puff that is hydrogen.
func puff_h() -> float:
	return minf(0.95, PUFF_H + PURE_STEP * int(lv.pure))

## How many puffs the button lets go at a time.
func volley() -> int:
	return 1 + int(lv.volley)

## Seconds between puffs while the button is held.
func stream_gap() -> float:
	return maxf(STREAM_LEAST, STREAM * pow(STREAM_STEP, int(lv.stream)))

func pass_time() -> float:
	return PASS * pow(suns(), -DRAWN) * pow(BEACON_SOON, on("beacon")) * pow(CROWD, int(perk.crowd))

## How heavy what passes is, against a first sky's.
func rich() -> float:
	return pow(BEACON_RICH, on("beacon")) * (1.0 + RICHER * novas)

static func body_r(m: float) -> float:
	return BODY_R * pow(m, 1.0 / 3.0)

## How far apart two puffs make a grain.
func gas_r() -> float:
	return MEET * main_r() / STAR_R

## Inside this nothing big holds together, and nothing gathers.
func roche_r() -> float:
	return main_r() * ROCHE * pow(1.0 + CORE * int(perk.core), 1.0 / 3.0)

## How near the star a solid of `m` gets before the tide has it in pieces; 0
## for one too small to be torn.
func tear_r(m: float) -> float:
	if m < CRUMB * 2.0:
		return 0.0
	var h := HOLD / body_r(m)
	return roche_r() / pow(1.0 + h * h, 1.0 / 3.0)

## Seconds a circle at `r` takes to go round.
func turn_time(r: float) -> float:
	return TAU * sqrt(r * r * r / gm())

## The velocity of a circle round the star through `pos`, the way the disc
## turns.
func circle_vel(pos: Vector2) -> Vector2:
	return pos.orthogonal().normalized() * -sqrt(gm() / pos.length())

## The light a perfect spiral from the disc's edge pays for each of a body's
## mass.
func spiral_light() -> float:
	return LIGHT * (1.0 - 1.0 / haze_wide()) * glow()

func last_level(tile: String) -> int:
	return int(TILE[tile][2])

func is_done(tile: String) -> bool:
	return last_level(tile) > 0 and int(lv[tile]) >= last_level(tile)

func cost(tile: String) -> int:
	return int(round(float(TILE[tile][0]) * pow(float(TILE[tile][1]), int(lv[tile]))))

func can_buy(tile: String) -> bool:
	return not is_done(tile) and light >= cost(tile)

func buy(tile: String) -> bool:
	if not can_buy(tile):
		return false
	light -= cost(tile)
	lv[tile] = int(lv[tile]) + 1
	return true

# --- the powers ---

## The Suns the star weighs at its `i`th pick: MILES, then twice the last
## for each one after.
static func mile(i: int) -> float:
	if i < MILES.size():
		return MILES[i]
	return float(MILES[MILES.size() - 1]) * pow(2.0, i - MILES.size() + 1)

## How many picks the star has grown past.
func passed() -> int:
	var n := 0
	var now := suns()
	while now >= mile(n):
		n += 1
	return n

## Picks it has earned and not made.
func owed() -> int:
	return passed() - picks

## The Suns at which the next pick comes.
func next_pick() -> float:
	return mile(passed())

## The two powers on offer, or none. Drawn once and kept, so leaving and
## coming back does not draw again. They go different ways, and Thrift is
## not a first pick: there is nothing yet for it to save.
func offering() -> Array:
	if owed() <= 0:
		return []
	if offer.size() != 2:
		var pool: Array = POWERS.filter(func(w: String) -> bool: return picks > 0 or w != "thrift")
		var a: String = pool[_rng.randi() % pool.size()]
		var rest: Array = pool.filter(func(w: String) -> bool: return WAY[w] != WAY[a])
		offer = [a, rest[_rng.randi() % rest.size()]]
	return offer

## Takes the `i`th of the two on offer. Returns it, or "" if none is owed.
func pick(i: int) -> String:
	var two := offering()
	if two.is_empty():
		return ""
	var which: String = two[clampi(i, 0, 1)]
	power[which] = int(power[which]) + 1
	picks += 1
	offer = []
	return which

# --- the end ---

## How the star's life is ending, if it is: "nova" with an iron core too
## heavy to hold itself up, "fade" after GRACE seconds with nothing left to
## burn, "" otherwise. Nothing moves once it is; the screen plays it and
## calls `end` (the user, asked how a life ends: "the star decides").
func ending() -> String:
	if made[5] >= IRON * START:
		return "nova"
	if cold >= GRACE:
		return "fade"
	return ""

## The stardust the end would pay if it came now as a supernova.
func dust_for() -> int:
	return maxi(int(DUST), int(floor(DUST * sqrt(suns() / HEAVY))))

func perk_cost() -> int:
	return PERK + bought

## The star gives back what it is made of. Its mass, its light, the tiles
## and its powers go; stardust, the perks and a richer sky stay. What it
## threw off is left as gas on closed paths round the new star, all turning
## the same way, the nearest of it already in the disc. Returns the stardust
## paid, 0 if no end has come.
func end() -> int:
	var how := ending()
	if how == "":
		return 0
	var nova := how == "nova"
	var got := dust_for() if nova else FADE_DUST
	var count := FADE_ASHES
	if nova:
		count = mini(ASHES_MOST, roundi(ASHES + ASHES_LOG * log(suns()) / log(10.0)))
		novas += 1
	else:
		fades += 1
	dust += got
	mass = START * pow(EMBER, int(perk.ember))
	light = 0.0
	fuel = mass * STAR_H
	env = mass * STAR_HE
	for i in STAGES:
		made[i] = 0.0
		ignited[i] = i == 0
	h_on = true
	awake = true
	lit = 1.0
	cold = 0.0
	swell = 0.0
	_shine = 0.0
	picks = 0
	offer = []
	for tile: String in TILES:
		lv[tile] = 0
	for which: String in POWERS:
		power[which] = 0
	bodies.clear()
	events.clear()
	_pass_wait = 0.0
	var pull := gm()
	var rw := main_r()
	for i in count:
		var near := (ASH_NEAR + _rng.randf() * ASH_REACH) * rw
		var far := near + 0.4 * rw + _rng.randf() * ((ASH_FAR - 0.4) * rw - near)
		var way := Vector2.from_angle(_rng.randf() * TAU)
		# let go at its furthest point, where it is slowest
		var v := sqrt(pull * (2.0 / far - 2.0 / (near + far)))
		var b := add(Kind.GAS, PUFF * ASH_M * (1.0 + RICHER * novas) * _rng.randf_range(0.6, 1.4), way * far, way.orthogonal() * -v)
		b.h = ASH_H
		b.dust = ASH_DUST
		b.age = COOL
	return got

## A perk drawn at random for what the next one costs, or "" if the stardust
## does not reach. A perk drawn twice counts twice.
func buy_perk() -> String:
	var c := perk_cost()
	if dust < c:
		return ""
	dust -= c
	bought += 1
	var which: String = PERKS[_rng.randi() % PERKS.size()]
	perk[which] = int(perk[which]) + 1
	return which

# --- the sky ---

func add(kind: Kind, m: float, pos: Vector2, vel: Vector2) -> Body:
	var b := Body.new()
	b.id = _next_id
	_next_id += 1
	b.kind = kind
	b.m = m
	b.pos = pos
	b.vel = vel
	b.spin = _rng.randf() * TAU
	b.turn = _rng.randf_range(-TUMBLE, TUMBLE)
	bodies.append(b)
	_sort(b)
	return b

## What a solid is called by what it weighs and is made of, and how much of
## the disc's drag takes hold of it.
func _sort(b: Body) -> void:
	if b.kind == Kind.GAS:
		b.grip = 1.0
		return
	if b.h >= GASSY and b.m >= CORE_M:
		b.kind = Kind.GIANT
	elif b.ice >= ICE_LOOK and b.m < PLANET_M:
		b.kind = Kind.COMET
	elif b.m < GRAIN_M:
		b.kind = Kind.GRAIN
	elif b.m < PLANET_M:
		b.kind = Kind.ROCK
	else:
		b.kind = Kind.PLANET
	var g := GRIP_R / body_r(b.m)
	b.grip = minf(1.0, g * g)

func gas_count() -> int:
	var n := 0
	for b in bodies:
		if b.kind == Kind.GAS:
			n += 1
	return n

## The button: a puff of gas set going round the star at the disc's rim,
## where the stream comes in now, or with Volley several. Past the sky's
## most it is poured into the puff before it.
func pour() -> void:
	var m := puff_mass()
	var rh := haze_r()
	var gas := gas_count()
	for k in volley():
		if gas >= MOST or bodies.size() >= FULL:
			for i in range(bodies.size() - 1, -1, -1):
				var last := bodies[i]
				if last.kind == Kind.GAS:
					last.h = (last.h * last.m + puff_h() * m) / (last.m + m)
					last.dust = (last.dust * last.m + DUSTY * PUFF) / (last.m + m)
					last.m += m
					break
			continue
		var pos := Vector2.from_angle(_inlet + _rng.randf_range(-IN_WIDE, IN_WIDE)) * rh * _rng.randf_range(IN_NEAR, IN_FAR)
		var b := add(Kind.GAS, m, pos, circle_vel(pos) * _rng.randf_range(0.97, 1.0))
		b.h = puff_h()
		b.dust = DUSTY * PUFF / m
		gas += 1

## A body from far off, on an open path.
func _passer() -> void:
	if bodies.size() >= FULL:
		return
	var z := zoom()
	var out := SPAWN / z
	var way := Vector2.from_angle(_rng.randf() * TAU)
	var pos := way * out
	var u := _rng.randf()
	var kind := Kind.GRAIN if u < MIX[0] else (Kind.ROCK if u < MIX[1] else (Kind.COMET if u < MIX[2] else Kind.PLANET))
	var miss := _rng.randf() * MISS / z * (1.0 if _rng.randf() < PROGRADE else -1.0)
	var aim := (way.orthogonal() * -miss - pos).normalized()
	var spare := SPARE / z
	var b := add(kind, MASS[kind] * rich() * _rng.randf_range(0.8, 1.2), pos, aim * sqrt(spare * spare + 2.0 * gm() / out))
	b.ice = PASS_ICE[kind]
	b.h = b.ice * ICE_H
	_sort(b)

## The tide has the body at `at`: it is gone and its pieces are in its place,
## sharing its mass and its light unevenly, the heaviest first and still the
## body it was (its id). Each keeps the body's own motion and what its
## tumbling gave the place it was cut from, and nothing else: no push. The
## star pulls the nearer pieces harder, and that draws them out into a line
## along the path.
func _tear(at: int) -> void:
	var b := bodies[at]
	var n := clampi(int(b.m / CRUMB), 2, PIECES)
	var shares := PackedFloat32Array()
	var total := 0.0
	for k in n:
		shares.append(_rng.randf_range(0.6, 1.4))
		total += shares[k]
	shares.sort()
	shares.reverse()
	var reach := body_r(b.m) * APART
	var first := _rng.randf() * TAU
	var offs := PackedVector2Array()
	var mid := Vector2.ZERO
	for k in n:
		var off := Vector2.from_angle(first + TAU * (k + _rng.randf_range(-0.25, 0.25)) / n) * reach * _rng.randf_range(0.7, 1.0)
		offs.append(off)
		mid += off * (shares[k] / total)
	bodies.remove_at(at)
	events.append({"kind": "tear", "at": b.pos, "m": b.m})
	if on("furnace") > 0:
		var paid := FURNACE * on("furnace") * b.m
		light += paid
		events.append({"kind": "shed", "at": b.pos, "e": paid})
	for k in n:
		var off := offs[k] - mid
		var share := shares[k] / total
		var piece := add(Kind.GRAIN, b.m * share, b.pos + off, b.vel - off.orthogonal() * b.turn)
		piece.e = b.e * share
		piece.h = b.h
		piece.ice = b.ice
		piece.heat = b.heat
		_sort(piece)
		if k == 0:
			piece.id = b.id
			piece.spin = b.spin

## What is near what, every MEET_EVERY ticks, outside the Roche radius (what
## the tide pulls apart it does not let gather): two puffs make a grain of
## their dust, a solid takes a puff's dust and, heavy enough, some of the
## puff, and two solids become one and keep their momentum. The sky is laid
## on a grid as wide as the longest reach, and a body is tried only against
## what is already in the nine cells round its own.
func _meet() -> void:
	if bodies.size() < 2:
		return
	var most := 0.0
	var solids := 0
	for b in bodies:
		if b.kind != Kind.GAS:
			solids += 1
			most = maxf(most, b.m)
	var rg := gas_r()
	var big := body_r(most)
	var cell := maxf(rg, maxf(rg * 0.5 + big * (1.0 + FEED), big * (2.0 * TOUCH + FEED)))
	var grid := {}
	var gone := false
	var roche := roche_r()
	var inside := roche * roche
	var frost := frost_r()
	var born: Array[Dictionary] = []
	for a in bodies:
		if a.pos.length_squared() < inside:
			continue
		var a_gas := a.kind == Kind.GAS
		var ra := 0.0 if a_gas else body_r(a.m)
		var cx := int(floor(a.pos.x / cell))
		var cy := int(floor(a.pos.y / cell))
		for gx in range(cx - 1, cx + 2):
			for gy in range(cy - 1, cy + 2):
				var there = grid.get(Vector2i(gx, gy))
				if there == null:
					continue
				for b: Body in there:
					if b.m <= 0.0:
						continue
					var b_gas := b.kind == Kind.GAS
					var d := a.pos - b.pos
					if a_gas and b_gas:
						if a.dust <= 0.0 or b.dust <= 0.0 or a.age < COOL or b.age < COOL or solids >= SOLIDS:
							continue
						if absf(d.x) >= rg or absf(d.y) >= rg or d.length_squared() >= rg * rg:
							continue
						born.append(_condense(a, b, frost))
						solids += 1
					elif a_gas != b_gas:
						var s := b if a_gas else a
						var g := a if a_gas else b
						var reach := rg * 0.5 + body_r(s.m) * (1.0 + FEED)
						if absf(d.x) >= reach or absf(d.y) >= reach or d.length_squared() >= reach * reach:
							continue
						if g.dust > 0.0 and g.age >= COOL:
							_sweep(s, g, frost)
						if s.m >= CORE_M and s.m < GIANT_MOST:
							_gulp(s, g)
						if g.m <= 0.0:
							gone = true
					else:
						var rb := body_r(b.m)
						var reach := (ra + rb) * TOUCH + maxf(ra, rb) * FEED
						if absf(d.x) >= reach or absf(d.y) >= reach or d.length_squared() >= reach * reach:
							continue
						# the one already on the grid takes the other in, where it is filed
						var m := a.m + b.m
						if a.m > b.m:
							b.id = a.id
							b.spin = a.spin
							b.turn = a.turn
						b.vel = (a.vel * a.m + b.vel * b.m) / m
						b.pos = (a.pos * a.m + b.pos * b.m) / m
						b.h = (a.h * a.m + b.h * b.m) / m
						b.ice = (a.ice * a.m + b.ice * b.m) / m
						b.e += a.e
						b.m = m
						a.m = 0.0
						_sort(b)
						gone = true
						solids -= 1
						events.append({"kind": "merge", "at": b.pos})
					if a.m <= 0.0:
						break
				if a.m <= 0.0:
					break
			if a.m <= 0.0:
				break
		if a.m > 0.0:
			var key := Vector2i(cx, cy)
			if grid.has(key):
				(grid[key] as Array).append(a)
			else:
				grid[key] = [a]
	if gone:
		var left: Array[Body] = []
		for b in bodies:
			if b.m > 0.0:
				left.append(b)
		bodies = left
	for row in born:
		var grain := add(Kind.GRAIN, float(row.m), row.pos, row.vel)
		grain.ice = float(row.ice)
		grain.h = grain.ice * ICE_H
		_sort(grain)
		events.append({"kind": "form", "at": grain.pos})

## The solids `g` gives up where it is: its dust, and past the frost line
## ICY as much ice again, taken out of the puff.
func _solids(g: Body, frost: float) -> Vector2:
	var rock := g.m * g.dust
	var ice := minf(rock * ICY, g.m * 0.5) if g.pos.length() > frost else 0.0
	g.m -= rock + ice
	g.dust = 0.0
	return Vector2(rock, ice)

## The dust of two puffs sticks: the grain it makes, to be set between them.
func _condense(a: Body, b: Body, frost: float) -> Dictionary:
	var from_a := _solids(a, frost)
	var from_b := _solids(b, frost)
	var ma := from_a.x + from_a.y
	var mb := from_b.x + from_b.y
	var m := ma + mb
	return {"m": m, "ice": (from_a.y + from_b.y) / m, "pos": (a.pos * ma + b.pos * mb) / m, "vel": (a.vel * ma + b.vel * mb) / m}

## A solid sweeps up a puff's dust.
func _sweep(s: Body, g: Body, frost: float) -> void:
	var got := _solids(g, frost)
	var m := s.m + got.x + got.y
	s.vel = (s.vel * s.m + g.vel * (got.x + got.y)) / m
	s.ice = (s.ice * s.m + got.y) / m
	s.h = (s.h * s.m + got.y * ICE_H) / m
	s.m = m
	_sort(s)

## A solid heavy enough keeps some of the gas: all of a puff that is nearly
## gone.
func _gulp(s: Body, g: Body) -> void:
	var take := g.m if g.m < PUFF * 0.25 else minf(g.m * GULP, GULP_M)
	var m := s.m + take
	s.vel = (s.vel * s.m + g.vel * take) / m
	s.h = (s.h * s.m + g.h * take) / m
	s.ice = s.ice * s.m / m
	s.e += g.e * take / g.m
	g.e -= g.e * take / g.m
	s.m = m
	g.m -= take
	_sort(s)

## `delta` seconds pass, in whole ticks; what is left over waits. No more
## than `most` ticks a call, so a long frame does not become a longer one.
func advance(delta: float, most := 6) -> void:
	_acc += delta
	var n := mini(most, int(_acc / STEP))
	_acc = minf(_acc - n * STEP, STEP)
	for i in n:
		tick()

func tick() -> void:
	if ending() != "":
		return
	clock += STEP
	_tick += 1
	_inlet = fposmod(_inlet + TAU * STEP / IN_TURN, TAU)
	if passing:
		_pass_wait += STEP
		if _pass_wait >= _pass_gap:
			_pass_wait = 0.0
			_pass_gap = pass_time() * _rng.randf_range(GAP_MIN, GAP_MAX)
			_passer()
	var pull := gm()
	var rh := haze_r()
	var rwind := wind_r()
	var blow := WIND * on("wind")
	var eat := star_r() * EAT
	var far := FAR / zoom()
	var bind := pull / (2.0 * main_r())
	var gl := glow()
	var roche := roche_r()
	var roche3 := roche * roche * roche
	var torn := CRUMB * 2.0
	var i := bodies.size() - 1
	while i >= 0:
		var b := bodies[i]
		var p := b.pos
		var r2 := p.length_squared()
		var r := sqrt(r2)
		var gas := b.kind == Kind.GAS
		if r < eat:
			mass += b.m
			eaten += b.m
			fuel += b.m * b.h
			if gas:
				env += b.m * (1.0 - b.h - b.dust) * GAS_HE
			light += b.e
			events.append({"kind": "eat", "at": p, "m": b.m, "gas": gas})
			bodies.remove_at(i)
			i -= 1
			continue
		if r > far and p.dot(b.vel) > 0.0:
			bodies.remove_at(i)
			i -= 1
			continue
		if not gas and r < roche and b.m >= torn and bodies.size() < FULL:
			# tear_r, without its cube root
			var h := HOLD / body_r(b.m)
			if r2 * r * (1.0 + h * h) < roche3:
				_tear(i)
				i -= 1
				continue
		var acc := p * (-pull / (r2 * r))
		b.heat = 0.0
		if r < rh:
			# The drag, and the light it makes: the work done on the body, as
			# a share of what a perfect spiral from far off down to the
			# star's surface gives up. A body dropped straight in does
			# almost none.
			var d := 1.0 - r / rh
			var k := DRAG * (THIN + (1.0 - THIN) * d) * b.grip
			acc -= b.vel * k
			b.heat = d
			b.e += k * b.vel.length_squared() * STEP / bind * b.m * LIGHT * gl
			var q := maxf(PIECE, b.m * LIGHT * 0.2)
			if b.e >= q:
				b.e -= q
				light += q
				events.append({"kind": "shed", "at": p, "e": q})
		elif r < rwind:
			acc -= b.vel * blow * b.grip
		b.vel += acc * STEP
		b.pos = p + b.vel * STEP
		b.spin += b.turn * STEP
		b.age += STEP
		i -= 1
	if _tick % MEET_EVERY == 0:
		_meet()
	if burning:
		_burn()

## A tick of the star's own burning. Every stage that has lit turns what it
## burns into the next thing, the heaviest first, so nothing is burnt twice
## in a tick; its light is let go a mote at a time. The powers' share of the
## hydrogen makes no light. Then what has core enough lights, and the star is
## awake if anything burnt.
func _burn() -> void:
	var rate := _plain_burn()
	var any := false
	if not h_on and fuel >= WAKE * mass:
		h_on = true
	for i in range(STAGES - 1, -1, -1):
		if not ignited[i]:
			continue
		if i == 0:
			if not h_on:
				continue
			var plain := rate * STEP
			var use := plain * (1.0 + _more())
			if use >= fuel:
				plain *= fuel / use
				use = fuel
				h_on = false
			fuel -= use
			made[0] += use
			_shine += plain * float(SHINE[0]) * (1.0 + int(power.fusion))
			any = true
		elif made[i - 1] > 0.0:
			var use := minf(made[i - 1], rate * float(RATE[i]) * STEP)
			made[i - 1] -= use
			made[i] += use
			_shine += use * float(SHINE[i]) * (1.0 + int(power.fusion))
			any = true
	var q := maxf(0.25, rate * float(SHINE[0]) * 0.6)
	if _shine >= q:
		_shine -= q
		light += q
		events.append({"kind": "shine", "e": q})
	if not ignited[1] and made[0] >= FLASH * START:
		_ignite(1)
	if not ignited[2] and made[1] >= CARBON * START and suns() >= HEAVY:
		_ignite(2)
	for i in range(3, STAGES):
		if not ignited[i] and ignited[i - 1] and made[i - 1] >= NEXT * START:
			_ignite(i)
	if any != awake:
		awake = any
		events.append({"kind": "wake" if any else "dim"})
	cold = 0.0 if awake else cold + STEP
	lit = move_toward(lit, 1.0 if awake else 0.0, STEP / DIM)
	swell = move_toward(swell, 1.0 if awake and (ignited[2] or not h_on) else 0.0, STEP / SWELL)

func _ignite(i: int) -> void:
	ignited[i] = true
	events.append({"kind": "ignite", "stage": i})

# --- keeping ---

## Writes the star and its sky to `path`.
func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("star", "kept", KEPT)
	for tile: String in TILES:
		cfg.set_value("lv", tile, int(lv[tile]))
	for which: String in PERKS:
		cfg.set_value("perk", which, int(perk[which]))
	for which: String in POWERS:
		cfg.set_value("power", which, int(power[which]))
	cfg.set_value("star", "fuel", fuel)
	cfg.set_value("star", "env", env)
	cfg.set_value("star", "made", Array(made))
	cfg.set_value("star", "ignited", Array(ignited))
	cfg.set_value("star", "swell", swell)
	cfg.set_value("star", "cold", cold)
	cfg.set_value("star", "picks", picks)
	cfg.set_value("star", "offer", offer)
	cfg.set_value("star", "mass", mass)
	cfg.set_value("star", "light", light)
	cfg.set_value("star", "dust", dust)
	cfg.set_value("star", "novas", novas)
	cfg.set_value("star", "fades", fades)
	cfg.set_value("star", "bought", bought)
	cfg.set_value("star", "eaten", eaten)
	var kept := []
	for b in bodies:
		kept.append([int(b.kind), b.m, b.pos.x, b.pos.y, b.vel.x, b.vel.y, b.h, b.dust, b.ice])
	cfg.set_value("star", "bodies", kept)
	cfg.save(path)

## The star as it was left, with its sky. A first visit, or a file that
## cannot be read, is a new star of START mass in an empty sky. A star kept
## before the gas (no `kept` in its file) comes back with its mass, its
## stardust, its perks and its powers, and an empty sky: its bodies were a
## thousand times too heavy for this one. Nothing happens while the game is
## closed.
static func load_saved(rng_seed := 0) -> RefCounted:
	var sim: RefCounted = (load("res://arcade/nightlight_sim.gd") as GDScript).new(rng_seed)
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK or not cfg.has_section_key("star", "mass"):
		return sim
	var old := int(cfg.get_value("star", "kept", 1)) < KEPT
	for tile: String in TILES:
		var was := "meteor" if tile == "puff" else ("ice" if tile == "pure" else tile)
		var level := maxi(0, int(cfg.get_value("lv", was if old else tile, 0)))
		sim.lv[tile] = level if sim.last_level(tile) == 0 else mini(level, sim.last_level(tile))
	for which: String in PERKS:
		sim.perk[which] = maxi(0, int(cfg.get_value("perk", which, 0)))
	sim.mass = maxf(START, float(cfg.get_value("star", "mass", START)))
	sim.light = maxf(0.0, float(cfg.get_value("star", "light", 0.0)))
	sim.dust = maxi(0, int(cfg.get_value("star", "dust", 0)))
	sim.novas = maxi(0, int(cfg.get_value("star", "novas", 0)))
	sim.fades = maxi(0, int(cfg.get_value("star", "fades", 0)))
	sim.bought = maxi(0, int(cfg.get_value("star", "bought", 0)))
	sim.eaten = maxf(0.0, float(cfg.get_value("star", "eaten", 0.0)))
	sim.fuel = clampf(float(cfg.get_value("star", "fuel", sim.mass * STAR_H)), 0.0, sim.mass)
	sim.env = clampf(float(cfg.get_value("star", "env", sim.mass * STAR_HE)), 0.0, sim.mass - sim.fuel)
	var room: float = sim.mass - sim.fuel - sim.env
	var was_made = cfg.get_value("star", "made", [])
	var was_lit = cfg.get_value("star", "ignited", [])
	if not old and was_made is Array and was_lit is Array and (was_made as Array).size() == STAGES and (was_lit as Array).size() == STAGES:
		for i in STAGES:
			sim.made[i] = clampf(float(was_made[i]), 0.0, room)
			room -= sim.made[i]
			sim.ignited[i] = i == 0 or bool(was_lit[i])
		sim.swell = clampf(float(cfg.get_value("star", "swell", 0.0)), 0.0, 1.0)
		sim.cold = clampf(float(cfg.get_value("star", "cold", 0.0)), 0.0, GRACE * 0.5)
	sim.h_on = sim.fuel > 0.0
	for which: String in POWERS:
		sim.power[which] = maxi(0, int(cfg.get_value("power", which, 0)))
	# a star kept before there were powers has every pick it grew past to make
	sim.picks = clampi(int(cfg.get_value("star", "picks", 0)), 0, sim.passed())
	var two = cfg.get_value("star", "offer", [])
	if two is Array and (two as Array).size() == 2 and POWERS.has(two[0]) and POWERS.has(two[1]):
		sim.offer = [String(two[0]), String(two[1])]
	if old:
		return sim
	for row in cfg.get_value("star", "bodies", []):
		if not (row is Array) or (row as Array).size() < 9 or sim.bodies.size() >= FULL:
			continue
		var m := float(row[1])
		var pos := Vector2(float(row[2]), float(row[3]))
		if m <= 0.0 or not pos.is_finite() or pos.length() < 1.0:
			continue
		var b: Body = sim.add(clampi(int(row[0]), 0, Kind.size() - 1) as Kind, m, pos, Vector2(float(row[4]), float(row[5])))
		b.h = clampf(float(row[6]), 0.0, 1.0)
		b.dust = clampf(float(row[7]), 0.0, 1.0)
		b.ice = clampf(float(row[8]), 0.0, 1.0)
		b.age = COOL
		sim._sort(b)
	return sim

## What the Arcade tab says of the kept star without building it: its mass
## and its supernovas, both 0 if there is none yet.
static func kept() -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK or not cfg.has_section_key("star", "mass"):
		return {"mass": 0.0, "novas": 0}
	return {"mass": float(cfg.get_value("star", "mass", 0.0)), "novas": int(cfg.get_value("star", "novas", 0))}
