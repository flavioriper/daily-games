extends RefCounted

## Nightlight, as pure data: a star in the middle of a night sky, the ring of
## gas it is born with and the gas that drifts in from the far sky, the
## bodies that gas condenses into, what passes on its own, the chain of
## elements the star burns through, four tiles for the hand bought with
## light, the powers the star is offered as it grows, and the ways its life
## ends, each of which leaves a small star again with a ring of the gas the
## last one threw off. Kept and without an end (the
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
	## The dust share of the gas a solid came from, 0 to 1: what a dead star
	## made of it will leave behind.
	var metal := 0.0
	## 1 when a press has just braked it, 0 again FLUSH seconds on; drawn, not
	## saved.
	var sink := 0.0
	## The mass of the biggest solid this body is or has been part of; 0 for
	## gas. What it pays for its mass goes by this (`pay`).
	var rank := 0.0
	## The light it has let go so far.
	var paid := 0.0

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
const LIGHT := 13.0
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
const SEEN_LOG := 70.0
## A body is eaten this far inside the star's edge.
const EAT := 0.94
## The disc is this many of the star's radii wide, before the Wide haze.
const HAZE := 3.0
## A solid's radius is the cube root of its mass times this: rock is denser
## than a star.
const BODY_R := 44.0

## The unit of gas and of dust: two thousandths of a Sun (the user: "going
## from 1x -> 2x sun is not so fast like throwing 3 bodies into it"). A ring's
## puff is RING_M / RING, about a PUFF, and carries a plain share of its mass
## as dust (FIRST_DUST at a first birth, ASH_DUST and up after an end). H of a
## puff is hydrogen, DUSTY of it dust, and GAS_HE of the
## rest helium. What the hand is worth feeds the star, and the planets come at
## their own pace.
const PUFF := 0.02
const PUFF_H := 0.7
const DUSTY := 0.01
const GAS_HE := 0.93
## The most puffs in the sky; the trickle adds to the last one past it.
const MOST := 260
## The most solids the gas makes by itself.
const SOLIDS := 40
## Nothing is torn, and nothing more is let in, while the sky holds FULL.
const FULL := 400

## The ring a star is born with: its inner and outer edge in the newborn's
## plain disc, how many puffs, what they weigh together, and how many of
## them are already falling so a new star has something winding in.
const RING_IN := 1.15
const RING_OUT := 1.75
const RING := 180
const RING_M := 3.0
const RING_FALLING := 6
## A ring is never more than this share of the newborn's own mass: a heavier
## one all comes down by itself once the star has eaten a tenth of a Sun of
## it (the runaway). A richer sky shows in what drifts in (`trickle_rate`),
## not in a heavier ring.
const RING_MOST := 0.3
## The ring's outer edge is this far from the star on the screen, of the
## design's 1080 across.
const FRAME := 500.0
## A press: the share of its speed a body under the finger's middle loses,
## the finger's reach in the design's pixels and what a level of Reach adds,
## the seconds between brakes while it is held, and how long what it braked
## is drawn warm.
const BRAKE := 0.2
const PRESS_R := 95.0
const REACH_STEP := 0.25
const FLOW := 0.6
const FLOW_STEP := 0.88
const FLOW_LEAST := 0.15
const FLUSH := 6.0
## Gas from the far sky, fed by need: the ring is made up to what it weighed
## when the star was born (`ring_m`) and no further, so a full ring gets
## nothing and an emptied one all of it, anywhere in the ring. What lands
## inside a grown star's disc is not in the ring, so a big star is fed in
## full with no hand. TRICKLE is the most of it, mass a second at one Sun;
## TRICKLE_UP the power of the star's Suns that most goes by (Bondi's is 2,
## which runs away); RICH_STEP what a level of Rich adds. No more than
## DRIFT_MOST puffs are set down in a tick, and what is owed past that waits:
## none is dropped.
const TRICKLE := 0.028
const TRICKLE_UP := 0.25
const RICH_STEP := 0.5
const DRIFT_MOST := 8

## Condensing. A puff has to be up COOL seconds before its dust falls out.
## Two that are MEET px apart (as the game starts; it widens with the star)
## make a grain of their dust, STICK of the times they are looked at and
## found that near: dust sticks slowly, so a ring's grains gather over its
## first minutes and not in its first second. Past the frost line there is
## ICY as much ice again as dust. A solid takes the dust of a puff that comes
## within its own radius and FEED of it more, and gathers a solid it touches
## or comes that near. From CORE_M up it keeps GULP of the gas too, each time
## they are looked at and never more than GULP_M at once, until it weighs
## GIANT_MOST.
const COOL := 12.0
const MEET := 30.0
const STICK := 0.0006
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

## What a thing's mass pays against gas, by the biggest solid it is or was
## part of (the user: "sending raw gas should give way less than sending real
## bodies to it like meteors, planets"). An iron-rich ring earns several
## times a first one's light by these: that is what the iron is for.
const PAY_GAS := 1.0
const PAY_GRAIN := 4.0
const PAY_ROCK := 10.0
const PAY_WORLD := 25.0

## Worlds pull what is near them: the WORLDS heaviest solids from PLANET_M up
## do. A solid feels a world out to PULL_REACH of its Hill radii. Gas feels
## only a world that holds it (`holds`: a core, not a small planet and not a
## full giant), and only inside one Hill radius of it; inside HILL_HOLD of
## that radius it eases toward the world's speed MOON_DRAG a second.
const WORLDS := 8
const PULL_REACH := 6.0
const HILL_HOLD := 0.5
const MOON_DRAG := 0.05

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
## From the helium flash, or with its hydrogen gone, the star is a giant:
## GIANT of its width wider again and GIANT_K at the surface whatever it
## weighs (a red supergiant's 3,600 K), SWELL seconds getting there. Burning
## carbon it swells on to SUPER, a supergiant, and its disc, frost line and
## wind go out with it.
const GIANT := 1.2
const SUPER := 2.0
const GIANT_K := 3600.0
const SWELL := 30.0
## Its surface temperature in kelvin, by its Suns; a dim star is COLD of
## that.
const TEMP := [[1.0, 5800.0], [2.0, 9000.0], [4.0, 14000.0], [8.0, 22000.0], [16.0, 30000.0], [60.0, 42000.0]]
const COLD := 0.5

## The shop is the hand's (the user, 2026-10-06: "the shop should be related
## to what player can do"): a wider press, a quicker one while the finger is
## held, a richer sky and gas with more hydrogen in it.
const TILES := ["reach", "flow", "rich", "pure"]
## A tile's first price in light, what each level multiplies it by, and its
## last level (0: it has none).
const TILE := {
	"reach": [40.0, 2.2, 6],
	"flow": [30.0, 2.0, 0],
	"rich": [12.0, 1.8, 0],
	"pure": [20.0, 1.9, 6],
}
## A level of Pure is PURE_STEP more of a puff in hydrogen.
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
## disc. Tidal furnace: a torn body pays FURNACE_SHARE of its own worth (its
## mass, a perfect spiral's light and what its rank pays) a level, over and
## above that worth. Fusion: the star's own burning pays one SHINE more a
## level. Thrift: it burns THRIFT as much.
const WIND := 0.0003
const WIND_REACH := 3.0
const HAZE_STEP := 1.15
const BEACON_SOON := 0.8
const BEACON_RICH := 1.2
const RADIANCE := 0.3
const FURNACE_SHARE := 0.5
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
## Every supernova so far makes what passes this much heavier, and as much
## more gas drift in, for good.
const RICHER := 0.5
## What a star leaves is a ring of RING_M (never over RING_MOST of the
## newborn). Its puffs are ASH_DUST of dust, and the heavy layers of
## the dead star add METAL times their share to that, never over ASH_MOST: it
## is what a star made, so the next star's planets come quicker. A first
## star's ring is FIRST_DUST of dust. The falling few are each on a closed
## path whose nearest point to the new star is ASH_NEAR to ASH_NEAR +
## ASH_REACH of its radii and whose furthest is inside ASH_FAR of them.
const FIRST_DUST := 0.004
const ASH_DUST := 0.01
const ASH_MOST := 0.03
const ASH_H := 0.5
const ASH_NEAR := 1.7
const ASH_REACH := 1.2
const ASH_FAR := 4.2
## A body tumbles up to this many radians a second, either way.
const TUMBLE := 0.3

## Where the star is kept, and which way of keeping it this is. A harness
## points `path` elsewhere.
static var path := "user://nightlight.cfg"
const KEPT := 4

# --- relics: what a dead star leaves, in the live star's frame ---
enum Relic { WD, NS, BH }
## A white dwarf's mass in Suns, and what each Sun of the dead star adds, up to a limit under Chandrasekhar.
const WD_M := 0.6
const WD_M_PER := 0.05
const WD_MOST := 1.3
## A black hole is this share of the star, and no less than BH_LEAST Suns; from COLLAPSE Suns a supernova leaves one.
const BH_SHARE := 0.2
const BH_LEAST := 3.0
const COLLAPSE := 20.0
## Where a body is lost to a relic, in the sim's pixels: a black hole grows by its Suns.
const WD_R := 8.0
const NS_R := 5.0
const BH_R := 10.0
const BH_R_M := 3.0
## How many relics are kept, and past what distance one pulls nothing.
const RELICS_MOST := 12
const RELIC_REACH := 6000.0
## Neighbour stars, decoration: how many and how far.
const NEIGHBOURS := 5
const FAR_NEAR := 2500.0
const FAR_FAR := 5000.0
## A planetary nebula pays this; the new star's ring sits inside its lobe by LOBE.
const NEBULA_DUST := 2
const LOBE := 2.0
## The dead star's silicon, iron and rock become dust in the gas it leaves, METAL
## of their share of it (a supernova's are a twelfth of the star, so its gas
## is 0.016 dust: a handful of worlds by its tenth minute, where 0.032 made
## twenty); a solid from gas this dusty is iron-dark, fully from twice IRONY.
const METAL := 0.07
const IRONY := 0.008

var mass := START
var light := 0.0
var dust := 0
var novas := 0
var fades := 0
var bought := 0
var lv := {"reach": 0, "flow": 0, "rich": 0, "pure": 0}
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
## The dead stars left in the sky, each {kind, m, pos, layers, age, novas}:
## point masses that pull everything and eat what comes inside their radius.
var relics: Array[Dictionary] = []
## Where the neighbour stars sit, only for the look of the sky.
var far: Array[Vector2] = []
## How far the sky has been carried from where the live star stands.
var drift := Vector2.ZERO
## Where the last end put the dead star, in the new star's frame, and how far
## that is: {from, d}, empty before any end. The screen plays the sky's slide
## from it.
var last_birth := {}
## True for a star that has just been born in its first cloud (`born`), so the
## screen plays it.
var fresh := false
var clock := 0.0
## What happened since the screen last looked, oldest first:
## {kind: "eat", at, m, gas, e} (`e` is all the light that body paid, from its
## first drag to its last), {kind: "shed", at, e}, {kind: "form", at},
## {kind: "merge", at}, {kind: "tear", at, m}, {kind: "shine", e},
## {kind: "ignite", stage}, {kind: "dim"}, {kind: "wake"},
## {kind: "lost", at, m, relic} (a body fell into relic number `relic`).
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

## The ring's inner and outer edge, fixed when the star is born; the frost
## line, at its middle; and the dust share of the gas this star was born in,
## which what drifts in later shares.
var ring := Vector2.ZERO
var frost := 0.0
var dusty := FIRST_DUST
## What the ring weighed when the star was born: the far sky makes the ring
## up to this and no further. Kept in the file.
var ring_m := RING_M
var _owed_gas := 0.0
## The gas outside the disc as the last tick left it: what the ring holds now.
var _gas_out := 0.0

func _init(rng_seed := 0) -> void:
	if rng_seed != 0:
		_rng.seed = rng_seed
	else:
		_rng.randomize()
	_set_ring()
	for i in NEIGHBOURS:
		far.append(Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(FAR_NEAR, FAR_FAR))

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
	return star_r() * zoom()

## Screen pixels to one of the world's: the star's own log rule, or less
## where the ring would not fit.
func zoom() -> float:
	var r := star_r()
	var plain := 1.0 if r < SEEN else (SEEN + SEEN_LOG * log(r / SEEN)) / r
	return minf(plain, FRAME / ring.y) if ring.y > 0.0 else plain

## A new star is one Sun.
func suns() -> float:
	return mass / START

## A relic's mass as Suns.
func relic_suns(rel: Dictionary) -> float:
	return float(rel.m) / START

## Inside this a body is the relic's: a point for a dwarf or a neutron star, a black hole's horizon by its Suns.
func relic_r(rel: Dictionary) -> float:
	match int(rel.kind):
		Relic.WD: return WD_R
		Relic.NS: return NS_R
	return BH_R + BH_R_M * relic_suns(rel)

## One more relic; past RELICS_MOST the farthest goes. Hands back the one it
## kept, so a caller can watch it grow.
func add_relic(kind: int, m: float, pos: Vector2, layers: Array) -> Dictionary:
	var rel := {"kind": kind, "m": m, "pos": pos, "layers": layers.duplicate(), "age": 0.0, "novas": novas, "fades": fades}
	relics.append(rel)
	while relics.size() > RELICS_MOST:
		var worst := 0
		for i in relics.size():
			if (relics[i].pos as Vector2).length_squared() > (relics[worst].pos as Vector2).length_squared():
				worst = i
		relics.remove_at(worst)
	return rel

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
	return lerpf(k, GIANT_K, giant()) * lerpf(COLD, 1.0, lit)

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

## The disc, as wide as the star is: a giant's reaches past what a plain
## star's did.
func haze_r() -> float:
	return star_r() * haze_wide()

## Past this, water is ice: the ring's middle for the star's whole life, and
## a giant thaws it. A sim with no ring has the old line, 2.2 radii.
func frost_r() -> float:
	return frost * (1.0 + GIANT * swell) if frost > 0.0 else star_r() * 2.2

## How much of a giant the star is for its colour and the sky: a supergiant
## is no redder than a giant.
func giant() -> float:
	return minf(1.0, swell)

func gm() -> float:
	return G * (1.0 + CORE * int(perk.core)) * mass

func glow() -> float:
	return (1.0 + RADIANCE * on("radiance")) * (1.0 + DISC * int(perk.disc))

## The share of a puff that is hydrogen.
func puff_h() -> float:
	return minf(0.95, PUFF_H + PURE_STEP * int(lv.pure))

func pass_time() -> float:
	return PASS * pow(suns(), -DRAWN) * pow(BEACON_SOON, on("beacon")) * pow(CROWD, int(perk.crowd))

## How heavy what passes is, against a first sky's.
func rich() -> float:
	return pow(BEACON_RICH, on("beacon")) * (1.0 + RICHER * novas)

static func body_r(m: float) -> float:
	return BODY_R * pow(m, 1.0 / 3.0)

## What a mass pays against gas, by the biggest solid it is or was part of
## (0 for gas).
static func pay(rank: float) -> float:
	if rank <= 0.0:
		return PAY_GAS
	if rank < GRAIN_M:
		return PAY_GRAIN
	return PAY_ROCK if rank < PLANET_M else PAY_WORLD

## True for a solid that keeps some of the gas it meets: a core, up to a
## giant that is full. `_meet` gulps by this, and a world holds gas by it.
static func holds(b: Body) -> bool:
	return b.m >= CORE_M and b.m < GIANT_MOST

## How far a world's own pull beats the star's tide, where it is now.
func hill_r(b: Body) -> float:
	return b.pos.length() * pow(b.m / (3.0 * mass), 1.0 / 3.0)

## What circles the star, for the screen and the Arcade card: grains are dust
## and are not counted, and neither is anything on an open path.
func system() -> Dictionary:
	var n := {"planets": 0, "giants": 0, "comets": 0, "rocks": 0}
	var free := 2.0 * gm()
	for b in bodies:
		# only what is on a closed path: a planetoid passing through is not the
		# star's
		if b.kind == Kind.GAS or b.vel.length_squared() * b.pos.length() >= free:
			continue
		match b.kind:
			Kind.PLANET: n.planets += 1
			Kind.GIANT: n.giants += 1
			Kind.COMET: n.comets += 1
			Kind.ROCK: n.rocks += 1
	return n

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
## heavy to hold itself up, "nebula" when a star too light for carbon has made
## a carbon core and has nothing more to burn, "fade" after GRACE seconds with
## nothing to burn at all, "" otherwise. Nothing moves once it is; the screen
## plays it and calls `end` (the user, asked how a life ends: "the star
## decides").
func ending() -> String:
	if made[5] >= IRON * START:
		return "nova"
	if ignited[1] and not ignited[2] and suns() < HEAVY and made[1] >= CARBON * START:
		return "nebula"
	if cold >= GRACE:
		return "fade"
	return ""

## The stardust the end would pay if it came now as a supernova.
func dust_for() -> int:
	return maxi(int(DUST), int(floor(DUST * sqrt(suns() / HEAVY))))

## What the end now due leaves: a black hole from COLLAPSE Suns, a neutron
## star for any other supernova, a white dwarf otherwise.
func remnant() -> int:
	if ending() == "nova":
		return Relic.BH if suns() >= COLLAPSE else Relic.NS
	return Relic.WD

## Its mass: a dwarf grows with the star it came from, up to a limit under
## Chandrasekhar; a neutron star is the iron core; a hole is a share of it.
func remnant_mass() -> float:
	match remnant():
		Relic.NS: return IRON * START
		Relic.BH: return maxf(BH_LEAST, BH_SHARE * suns()) * START
	return minf(WD_MOST, WD_M + WD_M_PER * (suns() - 1.0)) * START

func perk_cost() -> int:
	return PERK + bought

## The star gives back what it is made of. Its mass, its light, the tiles
## and its powers go; stardust, the perks and a richer sky stay. What it
## threw off is the new star's ring, on closed paths all turning the same
## way, a few puffs of it already falling. The dead star stays as
## a relic, and the new one is born away from the relics there are (see
## `last_birth`). Returns the stardust paid, 0 if no end has come.
func end() -> int:
	var how := ending()
	if how == "":
		return 0
	var nova := how == "nova"
	var got := dust_for() if nova else (NEBULA_DUST if how == "nebula" else FADE_DUST)
	if nova:
		novas += 1
	else:
		fades += 1
	dust += got
	# what the dead star was, before anything is reset
	var was_layers := layers()
	var kind := remnant()
	var rm := remnant_mass()
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
	_set_ring()
	bodies.clear()
	events.clear()
	_pass_wait = 0.0
	# its silicon, iron and rock go out as dust in its gas
	var ash_dust := minf(ASH_MOST, ASH_DUST + METAL * (was_layers[5] + was_layers[6] + was_layers[7]))
	ring_m = _lay_ring(RING, minf(RING_M, RING_MOST * mass), ASH_H, ash_dust)
	# where the next star is born: away from the relics there are, far enough that its ring is its own
	var mean := Vector2.ZERO
	for rel in relics:
		mean += rel.pos as Vector2
	var away := Vector2.from_angle(_rng.randf() * TAU) if relics.is_empty() else (-mean).normalized().rotated(_rng.randf_range(-0.7, 0.7))
	if not away.is_finite() or away.length() < 0.5:
		away = Vector2.from_angle(_rng.randf() * TAU)
	# the new star's ring, not the old one's: it is the one that must not touch the relic
	var d := LOBE * ring.y * (1.0 + sqrt(rm / mass))
	for rel in relics:
		rel.pos = (rel.pos as Vector2) - away * d
	for i in far.size():
		far[i] -= away * d
	drift += away * d
	add_relic(kind, rm, -away * d, was_layers)
	last_birth = {"from": -away * d, "d": d}
	return got

## A first star comes up in a ring of its own: gas on circles, a few puffs
## already falling in, no relic.
func born() -> void:
	_set_ring()
	ring_m = _lay_ring(RING, minf(RING_M, RING_MOST * mass), STAR_H, FIRST_DUST)
	fresh = true

## The ring and the frost line a newborn of `m` has. Powers are none on a
## newborn, so its disc is the plain one.
func _set_ring(m := mass) -> void:
	var disc := STAR_R * pow(m / START, 1.0 / 3.0) * HAZE
	ring = Vector2(RING_IN, RING_OUT) * disc
	frost = (ring.x + ring.y) * 0.5
	ring_m = minf(RING_M, RING_MOST * m)

## `count` puffs weighing `total` between the ring's edges, on circles, all
## turning the disc's way; the first few on the old falling paths. Returns
## what it laid, which is `total` give or take a few puffs.
func _lay_ring(count: int, total: float, h: float, dust_share: float) -> float:
	dusty = dust_share
	if count <= 0:
		return 0.0
	var each := total / count
	var falling := mini(RING_FALLING, count)
	var before := bodies.size()
	_lay_gas(falling, each, h, dust_share)
	for i in count - falling:
		var pos := _ring_spot()
		var b := add(Kind.GAS, each * _rng.randf_range(0.6, 1.4), pos, circle_vel(pos) * _rng.randf_range(0.98, 1.02))
		b.h = h
		b.dust = dust_share
		b.age = COOL
	var laid := 0.0
	for i in range(before, bodies.size()):
		laid += bodies[i].m
	_gas_out = gas_outside()
	return laid

## Somewhere in the ring, evenly by area.
func _ring_spot() -> Vector2:
	return Vector2.from_angle(_rng.randf() * TAU) * sqrt(lerpf(ring.x * ring.x, ring.y * ring.y, _rng.randf()))

## The gas outside the disc now: what the ring holds.
func gas_outside() -> float:
	var rh := haze_r()
	var out := 0.0
	for b in bodies:
		if b.kind == Kind.GAS and b.pos.length_squared() >= rh * rh:
			out += b.m
	return out

## `count` puffs of gas of `m_each` (give or take) on closed paths round the
## star, nearest of them already in the disc: each is let go at its furthest
## point, where it is slowest, and they all turn the same way.
func _lay_gas(count: int, m_each: float, h: float, dust_share: float) -> void:
	var pull := gm()
	var rw := main_r()
	for i in count:
		var near := (ASH_NEAR + _rng.randf() * ASH_REACH) * rw
		var apo := near + 0.4 * rw + _rng.randf() * ((ASH_FAR - 0.4) * rw - near)
		var way := Vector2.from_angle(_rng.randf() * TAU)
		var v := sqrt(pull * (2.0 / apo - 2.0 / (near + apo)))
		var b := add(Kind.GAS, m_each * _rng.randf_range(0.6, 1.4), way * apo, way.orthogonal() * -v)
		b.h = h
		b.dust = dust_share
		b.age = COOL

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
	b.rank = maxf(b.rank, b.m)
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

## The finger: everything within `r` of `at` loses a share of its speed,
## most under the middle, none at the edge. What follows is the orbit's own.
## Returns how many it braked.
func brake(at: Vector2, r: float) -> int:
	var n := 0
	if r <= 0.0:
		return n
	for b in bodies:
		var d := b.pos.distance_to(at)
		if d >= r:
			continue
		b.vel *= 1.0 - BRAKE * (1.0 - d / r)
		b.sink = 1.0
		n += 1
	if n > 0:
		events.append({"kind": "brake", "at": at, "n": n})
	return n

## How far the finger reaches, in the sim's pixels: the same on the screen
## whatever the star weighs.
func press_r() -> float:
	return PRESS_R * (1.0 + REACH_STEP * int(lv.reach)) / zoom()

## Seconds between brakes while a finger is held.
func flow_gap() -> float:
	return maxf(FLOW_LEAST, FLOW * pow(FLOW_STEP, int(lv.flow)))

## The most mass a second that drifts in from the far sky: more the heavier
## the star, and RICHER more for every supernova so far, as what passes is
## heavier.
func trickle_rate() -> float:
	return TRICKLE * pow(suns(), TRICKLE_UP) * (1.0 + RICHER * novas) * (1.0 + RICH_STEP * int(lv.rich)) * (1.0 + HAND * int(perk.hand))

## How much of that comes now, 0 to 1: the share of the ring that is empty.
func need() -> float:
	return clampf(1.0 - _gas_out / ring_m, 0.0, 1.0) if ring_m > 0.0 else 0.0

## What has drifted in is set down a puff at a time anywhere in the ring, on
## a circle; with the sky full it goes into the last puff there is. As many
## puffs as are owed, DRIFT_MOST a tick at most, and the rest waits.
func _trickle() -> void:
	if ring.y <= 0.0:
		return
	var each := RING_M / RING
	_owed_gas += trickle_rate() * need() * STEP
	var rh := haze_r()
	for k in DRIFT_MOST:
		if _owed_gas < each:
			return
		if gas_count() >= MOST or bodies.size() >= FULL:
			var into: Body = null
			for i in range(bodies.size() - 1, -1, -1):
				if bodies[i].kind == Kind.GAS:
					into = bodies[i]
					break
			if into == null:
				return
			into.h = (into.h * into.m + puff_h() * each) / (into.m + each)
			into.dust = (into.dust * into.m + dusty * each) / (into.m + each)
			into.m += each
			_owed_gas -= each
			if into.pos.length() >= rh:
				_gas_out += each
			continue
		_owed_gas -= each
		var pos := _ring_spot()
		var b := add(Kind.GAS, each, pos, circle_vel(pos))
		b.h = puff_h()
		b.dust = dusty
		if pos.length() >= rh:
			_gas_out += each

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
		# a share of what the body is worth, over and above it: not in `paid`
		var paid := FURNACE_SHARE * on("furnace") * b.m * spiral_light() * pay(b.rank)
		light += paid
		events.append({"kind": "shed", "at": b.pos, "e": paid})
	for k in n:
		var off := offs[k] - mid
		var share := shares[k] / total
		var piece := add(Kind.GRAIN, b.m * share, b.pos + off, b.vel - off.orthogonal() * b.turn)
		piece.e = b.e * share
		piece.h = b.h
		piece.ice = b.ice
		piece.metal = b.metal
		piece.heat = b.heat
		piece.rank = b.rank
		piece.paid = b.paid * share
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
						# the die is thrown last, so a pair that could not stick draws nothing
						if _rng.randf() >= STICK:
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
						if holds(s):
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
						b.metal = (a.metal * a.m + b.metal * b.m) / m
						b.e += a.e
						b.rank = maxf(a.rank, b.rank)
						b.paid += a.paid
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
		grain.metal = float(row.metal)
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
	var metal := _metal((a.dust * a.m + b.dust * b.m) / (a.m + b.m))
	var from_a := _solids(a, frost)
	var from_b := _solids(b, frost)
	var ma := from_a.x + from_a.y
	var mb := from_b.x + from_b.y
	var m := ma + mb
	return {"m": m, "ice": (from_a.y + from_b.y) / m, "metal": metal, "pos": (a.pos * ma + b.pos * mb) / m, "vel": (a.vel * ma + b.vel * mb) / m}

## How iron-dark the solid a puff's dust makes is, 0 to 1, full from twice
## IRONY: a quarter from a first star's FIRST_DUST, 0.6 from the ASH_DUST of
## a nebula or a fade, and 1 from a supernova's gas (0.016 and up, to
## ASH_MOST).
func _metal(dust_share: float) -> float:
	return clampf(dust_share / (2.0 * IRONY), 0.0, 1.0)

## A solid sweeps up a puff's dust.
func _sweep(s: Body, g: Body, frost: float) -> void:
	var metal := _metal(g.dust)
	var got := _solids(g, frost)
	var m := s.m + got.x + got.y
	s.vel = (s.vel * s.m + g.vel * (got.x + got.y)) / m
	s.ice = (s.ice * s.m + got.y) / m
	s.metal = (s.metal * s.m + metal * (got.x + got.y)) / m
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
	s.paid += g.paid * take / g.m
	g.paid -= g.paid * take / g.m
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
	if passing:
		_trickle()
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
	var gone := FAR / zoom()
	# a spiral's work down to the star's real surface, a giant's wider one
	# included: the light a body pays is the share of it the drag has done,
	# so a puff poured at a giant's wider rim pays what a plain star's does
	var bind := pull / (2.0 * star_r())
	var gl := glow()
	var roche := roche_r()
	var roche3 := roche * roche * roche
	var torn := CRUMB * 2.0
	# the relics near enough to pull: position, GM and the radius squared inside which they eat
	var pull_at := PackedVector2Array()
	var pull_gm := PackedFloat64Array()
	var pull_in := PackedFloat64Array()
	var pull_of := PackedInt32Array()
	var tide := Vector2.ZERO
	for k in relics.size():
		var rel := relics[k]
		if (rel.pos as Vector2).length() <= RELIC_REACH:
			var rr := relic_r(rel)
			pull_at.append(rel.pos)
			pull_gm.append(G * float(rel.m))
			pull_in.append(rr * rr)
			pull_of.append(k)
			# the star is never moved, so a relic's pull at the star is taken off every
			# body: what a body feels of a relic is its tide in the star's frame
			var rp: Vector2 = rel.pos
			var rp2 := rp.length_squared()
			if rp2 > 1.0:
				tide += rp * (G * float(rel.m) / (rp2 * sqrt(rp2)))
	# the WORLDS heaviest solids from PLANET_M up, as they are now: copied
	# values only, so one eaten, torn or merged later in the tick is not read
	# again. Held in order, heaviest first, by one pass and no sort.
	var w_m := PackedFloat64Array()
	var w_at := PackedVector2Array()
	var w_vel := PackedVector2Array()
	var w_gm := PackedFloat64Array()
	var w_soft := PackedFloat64Array()
	var w_reach := PackedFloat64Array()
	var w_hold := PackedFloat64Array()
	var w_gas := PackedFloat64Array()
	var w_id := PackedInt32Array()
	for b in bodies:
		if b.kind == Kind.GAS or b.m < PLANET_M or (w_m.size() >= WORLDS and b.m <= w_m[WORLDS - 1]):
			continue
		var slot := w_m.size()
		while slot > 0 and w_m[slot - 1] < b.m:
			slot -= 1
		var hill := hill_r(b)
		var sr := body_r(b.m)
		w_m.insert(slot, b.m)
		w_at.insert(slot, b.pos)
		w_vel.insert(slot, b.vel)
		w_gm.insert(slot, G * b.m)
		w_soft.insert(slot, sr * sr)
		w_reach.insert(slot, pow(PULL_REACH * hill, 2.0))
		w_hold.insert(slot, pow(HILL_HOLD * hill, 2.0) if holds(b) else -1.0)
		w_gas.insert(slot, hill * hill if holds(b) else -1.0)
		w_id.insert(slot, b.id)
		if w_m.size() > WORLDS:
			w_m.resize(WORLDS)
			w_at.resize(WORLDS)
			w_vel.resize(WORLDS)
			w_gm.resize(WORLDS)
			w_soft.resize(WORLDS)
			w_reach.resize(WORLDS)
			w_hold.resize(WORLDS)
			w_gas.resize(WORLDS)
			w_id.resize(WORLDS)
	var w_holder := false
	for k in w_gas.size():
		w_holder = w_holder or w_gas[k] > 0.0
	# the gas outside the disc, summed as the bodies are gone through: what the
	# ring holds, which the far sky makes up to `ring_m`
	var out := 0.0
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
			var in_all := b.paid + b.e
			if not gas:
				# a solid pays in full, whatever its path: what a perfect spiral
				# would have, by its rank, less what it has let go already
				var rest := b.m * spiral_light() * pay(b.rank) - b.paid - b.e
				if rest > 0.0:
					light += rest
					in_all += rest
					events.append({"kind": "shed", "at": p, "e": rest})
			events.append({"kind": "eat", "at": p, "m": b.m, "gas": gas, "e": in_all})
			bodies.remove_at(i)
			i -= 1
			continue
		if r > gone and p.dot(b.vel) > 0.0:
			bodies.remove_at(i)
			i -= 1
			continue
		# a relic takes what falls inside it (a body right on one is eaten, not
		# divided by) and pulls what does not; a black hole weighs what it ate
		var acc_rel := Vector2.ZERO
		var lost := false
		for k in pull_at.size():
			var to := pull_at[k] - p
			var d2 := to.length_squared()
			if d2 <= pull_in[k]:
				var which := pull_of[k]
				if int(relics[which].kind) == Relic.BH:
					relics[which].m = float(relics[which].m) + b.m
				events.append({"kind": "lost", "at": p, "m": b.m, "relic": which})
				bodies.remove_at(i)
				lost = true
				break
			acc_rel += to * (pull_gm[k] / (d2 * sqrt(d2)))
		if lost:
			i -= 1
			continue
		if not gas and r < roche and b.m >= torn and bodies.size() < FULL:
			# tear_r, without its cube root
			var h := HOLD / body_r(b.m)
			if r2 * r * (1.0 + h * h) < roche3:
				_tear(i)
				i -= 1
				continue
		# the worlds pull the solids within their reach, one another included,
		# never themselves; gas feels only a world that holds it, inside its
		# Hill radius, and is eased toward that world's speed inside half of it
		if not gas or w_holder:
			for k in w_at.size():
				var to := w_at[k] - p
				var d2 := to.length_squared()
				if d2 >= (w_gas[k] if gas else w_reach[k]) or w_id[k] == b.id:
					continue
				var soft := d2 + w_soft[k]
				acc_rel += to * (w_gm[k] / (soft * sqrt(soft)))
				if gas and d2 < w_hold[k]:
					b.vel += (w_vel[k] - b.vel) * (MOON_DRAG * STEP)
		var acc := p * (-pull / (r2 * r))
		acc += acc_rel - tide
		b.heat = 0.0
		if b.sink > 0.0:
			b.sink = maxf(0.0, b.sink - STEP / FLUSH)
		if r < rh:
			# The drag, and the light it makes: the work done on the body, as
			# a share of what a perfect spiral from far off down to the
			# star's surface gives up. A body dropped straight in does
			# almost none.
			var d := 1.0 - r / rh
			var k := DRAG * (THIN + (1.0 - THIN) * d) * b.grip
			acc -= b.vel * k
			b.heat = d
			b.e += k * b.vel.length_squared() * STEP / bind * b.m * LIGHT * gl * pay(b.rank)
			var q := maxf(PIECE, b.m * LIGHT * 0.2)
			if b.e >= q:
				b.e -= q
				b.paid += q
				light += q
				events.append({"kind": "shed", "at": p, "e": q})
		else:
			if gas:
				out += b.m
			if r < rwind:
				acc -= b.vel * blow * b.grip
		b.vel += acc * STEP
		b.pos = p + b.vel * STEP
		b.spin += b.turn * STEP
		b.age += STEP
		i -= 1
	_gas_out = out
	if _tick % MEET_EVERY == 0:
		_meet()
	if burning:
		_burn()
	for rel in relics:
		rel.age = float(rel.age) + STEP

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
	var want := 0.0
	if awake and (ignited[1] or not h_on):
		want = SUPER if ignited[2] else 1.0
	swell = move_toward(swell, want, STEP / SWELL)

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
		kept.append([int(b.kind), b.m, b.pos.x, b.pos.y, b.vel.x, b.vel.y, b.h, b.dust, b.ice, b.metal, b.rank, b.paid])
	cfg.set_value("star", "bodies", kept)
	cfg.set_value("star", "relics", relics.map(func(r): return [int(r.kind), float(r.m), (r.pos as Vector2).x, (r.pos as Vector2).y, float(r.age), int(r.novas), Array(r.layers), int(r.fades)]))
	cfg.set_value("star", "far", far.map(func(p): return [p.x, p.y]))
	cfg.set_value("star", "drift", [drift.x, drift.y])
	cfg.set_value("star", "ring", [ring.x, ring.y])
	cfg.set_value("star", "ring_m", ring_m)
	cfg.set_value("star", "frost", frost)
	cfg.set_value("star", "dusty", dusty)
	var n := system()
	cfg.set_value("star", "worlds", int(n.planets) + int(n.giants))
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
	if cfg.load(path) != OK:
		sim.born()
		return sim
	if not cfg.has_section_key("star", "mass"):
		return sim
	var ver := int(cfg.get_value("star", "kept", 1))
	var pre_gas := ver < 2
	# a star kept before the ring (KEPT 3 and older) has the old tiles' keys:
	# the volley is the press's reach, the stream its flow, the puff the sky's
	# richness
	var was_tile := {"reach": "volley", "flow": "stream", "rich": "puff", "pure": "pure"}
	for tile: String in TILES:
		var key: String = tile
		if ver < 4:
			key = was_tile[tile]
			if pre_gas:
				key = "meteor" if key == "puff" else ("ice" if key == "pure" else key)
		var level := maxi(0, int(cfg.get_value("lv", key, 0)))
		sim.lv[tile] = level if sim.last_level(tile) == 0 else mini(level, sim.last_level(tile))
	for which: String in PERKS:
		sim.perk[which] = maxi(0, int(cfg.get_value("perk", which, 0)))
	sim._set_ring(START * pow(EMBER, int(sim.perk.ember)))
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
	if not pre_gas and was_made is Array and was_lit is Array and (was_made as Array).size() == STAGES and (was_lit as Array).size() == STAGES:
		for i in STAGES:
			sim.made[i] = clampf(float(was_made[i]), 0.0, room)
			room -= sim.made[i]
			sim.ignited[i] = i == 0 or bool(was_lit[i])
		sim.swell = clampf(float(cfg.get_value("star", "swell", 0.0)), 0.0, SUPER)
		sim.cold = clampf(float(cfg.get_value("star", "cold", 0.0)), 0.0, GRACE * 0.5)
		# A star kept before the nebula end (KEPT 2, on testers' phones since
		# 2026-10-06) could already hold the carbon core that now sheds it on
		# load, before its player has seen the goal line warn of it: its core
		# comes back just under the line, the rest of it as helium, so the
		# mass still sums and the player gets to read the line first.
		var line := CARBON * START
		if ver < 3 and sim.ignited[1] and not sim.ignited[2] and sim.suns() < HEAVY and sim.made[1] >= line:
			sim.made[0] += sim.made[1] - line * 0.98
			sim.made[1] = line * 0.98
	sim.h_on = sim.fuel > 0.0
	for which: String in POWERS:
		sim.power[which] = maxi(0, int(cfg.get_value("power", which, 0)))
	# a star kept before there were powers has every pick it grew past to make
	sim.picks = clampi(int(cfg.get_value("star", "picks", 0)), 0, sim.passed())
	var two = cfg.get_value("star", "offer", [])
	if two is Array and (two as Array).size() == 2 and POWERS.has(two[0]) and POWERS.has(two[1]):
		sim.offer = [String(two[0]), String(two[1])]
	if pre_gas:
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
		b.metal = clampf(float(row[9]), 0.0, 1.0) if row.size() >= 10 else 0.0
		# twelve columns carry the rank and what was paid; an older row's rank is
		# its mass, which `_sort` gives a solid, and gas has none
		var had := (row as Array).size() >= 12 and is_finite(float(row[10])) and is_finite(float(row[11]))
		b.rank = maxf(0.0, float(row[10])) if had and b.kind != Kind.GAS else 0.0
		b.paid = maxf(0.0, float(row[11])) if had else 0.0
		b.age = COOL
		sim._sort(b)
	if ver >= 3:
		sim._load_sky(cfg)
	if ver >= 4:
		var edges = cfg.get_value("star", "ring", [])
		if edges is Array and (edges as Array).size() == 2 and (edges[0] is float or edges[0] is int) and (edges[1] is float or edges[1] is int) and is_finite(float(edges[0])) and is_finite(float(edges[1])) and float(edges[0]) > 0.0 and float(edges[1]) > float(edges[0]):
			sim.ring = Vector2(float(edges[0]), float(edges[1]))
			sim.frost = clampf(float(cfg.get_value("star", "frost", sim.frost)), sim.ring.x, sim.ring.y)
		sim.dusty = clampf(float(cfg.get_value("star", "dusty", FIRST_DUST)), 0.0, ASH_MOST)
		# what the ring weighed at birth; a file without it, or with something
		# that is not a mass, keeps the newborn's own (`_set_ring`)
		var born_m = cfg.get_value("star", "ring_m", sim.ring_m)
		if (born_m is float or born_m is int) and is_finite(float(born_m)) and float(born_m) > 0.0:
			sim.ring_m = minf(float(born_m), sim.ring_m * 1.5)
	else:
		# a star kept before the ring is given one: inside a heavy star's disc it simply falls;
		# a sky already full is given only what it has room for
		var room_left := mini(RING, FULL - sim.bodies.size())
		sim._lay_ring(room_left, RING_M * room_left / RING, ASH_H, ASH_DUST)
	sim._gas_out = sim.gas_outside()
	return sim

## The relics, the neighbour stars and the drift out of a file of KEPT 3 or
## later; a row that is not what it should be is left out.
func _load_sky(cfg: ConfigFile) -> void:
	for row in cfg.get_value("star", "relics", []):
		# seven columns, or eight with the fades the sky seeds its nebula with
		if not (row is Array) or (row as Array).size() < 7 or (row as Array).size() > 8 or relics.size() >= RELICS_MOST or not (row[6] is Array):
			continue
		var pos := Vector2(float(row[2]), float(row[3]))
		var m := float(row[1])
		if m <= 0.0 or not is_finite(m) or not pos.is_finite() or not is_finite(float(row[4])):
			continue
		# as many shares as `layers()` gives (hydrogen, helium, the stages, rock),
		# no more and no fewer: the sky colours them by Art.MADE's index
		var layers := []
		for share in row[6]:
			if layers.size() >= STAGES + 2:
				break
			layers.append(float(share) if is_finite(float(share)) else 0.0)
		while layers.size() < STAGES + 2:
			layers.append(0.0)
		var rel := add_relic(clampi(int(row[0]), 0, Relic.size() - 1), m, pos, layers)
		rel.age = maxf(0.0, float(row[4]))
		rel.novas = maxi(0, int(row[5]))
		rel.fades = maxi(0, int(row[7])) if row.size() == 8 else 0
	var seen: Array[Vector2] = []
	for row in cfg.get_value("star", "far", []):
		if row is Array and (row as Array).size() == 2 and seen.size() < NEIGHBOURS:
			var at := Vector2(float(row[0]), float(row[1]))
			if at.is_finite():
				seen.append(at)
	if not seen.is_empty():
		far = seen
	var way = cfg.get_value("star", "drift", [])
	if way is Array and (way as Array).size() == 2:
		var to := Vector2(float(way[0]), float(way[1]))
		if to.is_finite():
			drift = to

## What the Arcade tab says of the kept star without building it: its mass
## its supernovas and the dead stars it keeps, all 0 if there is none yet.
static func kept() -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK or not cfg.has_section_key("star", "mass"):
		return {"mass": 0.0, "novas": 0, "relics": 0, "worlds": 0}
	var dead = cfg.get_value("star", "relics", [])
	return {"mass": float(cfg.get_value("star", "mass", 0.0)), "novas": int(cfg.get_value("star", "novas", 0)), "relics": (dead as Array).size() if dead is Array else 0, "worlds": maxi(0, int(cfg.get_value("star", "worlds", 0)))}
