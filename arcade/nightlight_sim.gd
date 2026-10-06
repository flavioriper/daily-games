extends RefCounted

## Nightlight, as pure data: a small star in the middle of a night sky, the
## meteors thrown at it, the bodies that cross the sky on their own, what the
## star is made of and the hydrogen it burns, four tiles for the hand bought
## with light, the powers the star is offered as it grows, and the supernova
## that gives everything back and starts a small star again among its ashes. Kept and without an end (the
## user, 2026-10-06: "the run never ends, but player can rebirth star to buy
## some new perks that make journey faster and faster").
## Spec docs/superpowers/specs/2026-10-06-arcade-nightlight-design.md.
##
## The physics is the point (the user: "real phisic", "objects start to spin
## faster and faster by gravity till being eat", never a hole in the screen).
## Gravity is Newton's, GM / r^2 toward the star, and nothing else pulls. An
## orbit in empty space never decays, so the star wears a haze: inside it a
## body is dragged, most near the star, and what the drag takes from it is
## given off as light. That one thing is the capture, the spiral and the
## income; the speeding up is not animated, it falls out of the law.
##
## The star's pull is also uneven across a body, harder on its near side
## than its far one, and close enough that tide is more than what holds the
## body together: it comes apart, and the pieces draw out along the path by
## themselves (`_tear`).
##
## Nothing here draws or reads the clock. The screen
## (arcade/nightlight_screen.gd) calls `advance`, drains `events` and keeps
## the file; `tests/_probe_nightlight.gd` plays it with a bot. Lengths are
## the screen's own 1080-wide pixels as the game starts, measured from the
## star at (0, 0); the view draws back as the star grows (`zoom`).

enum Kind { METEOR, PEBBLE, ROCK, COMET, PLANET, ASH }

## One body in the sky. `h` is the share of it that is hydrogen; `e` is the
## light the haze has made of it and not yet let go; `heat` how deep in the
## haze it is, 0 outside; `trail` where it has been, oldest first.
class Body:
	var id := 0
	var kind := Kind.METEOR
	var m := 1.0
	var h := 0.0
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var spin := 0.0
	var turn := 0.0
	var e := 0.0
	var heat := 0.0
	var trail := PackedVector2Array()

const STEP := 1.0 / 120.0
## Gravity for a star of one mass, the haze's drag at the star's surface (a
## share of a body's speed a second) and the light a perfect spiral from far
## off pays for each of a body's mass.
##
## Everything moves at half the speed it first had (the user, 2026-10-06:
## "we need to reduce bodies movement speed, it's way too fast"): G is a
## quarter of the first 1.13e6, and SPARE and a body's tumbling half, so
## every path is the shape it was and takes twice as long. DRAG is two
## fifths of the first 0.25, not half: a spiral is slower in seconds than it
## was, and still goes round a few times on the way down.
const G := 2.8e5
const DRAG := 0.1
const LIGHT := 2.1
## A new star's mass and its radius; the radius is the cube root of the mass.
## The star is a little over twice as wide as it first was (46 px) and the
## bodies two thirds (BODY_R was 14), the same day: "let's try to get
## somewhere closer to real sizings ... right now it look way too small
## compared to the bodies around". A planetoid is under a fifth of a new
## star across where it was three fifths, a thrown meteor a twentieth. The
## haze and the Roche radius are about where they were in pixels, so fewer
## of the star's radii (they were 5 and 3).
const START := 10.0
const STAR_R := 100.0
## Past SEEN pixels on the screen the star grows only by the logarithm and
## the view draws back instead.
const SEEN := 130.0
const SEEN_LOG := 36.0
## A body is eaten this far inside the star's edge.
const EAT := 0.92
## The haze is this many of the star's radii wide, before the Haze tile.
const HAZE := 2.6
## A body's radius is the cube root of its mass times this.
const BODY_R := 9.0
## A thrown meteor, before the Meteor tile: a fifth of what it was while the
## pouch held four, since nothing limits a throw now (the user, 2026-10-06:
## "remove the asteroid limit on throw, but make it way smaller").
const METEOR := 0.2
## What a body of each Kind weighs, before the sky is any richer.
const MASS := [METEOR, 0.5, 1.5, 3.0, 8.0, 2.0]
## A passing body is a pebble this often, a rock up to the second figure, a
## comet up to the third, a planetoid for the rest.
const MIX := [0.5, 0.8, 0.95]
## A passer starts this far out and aims to miss the star by up to MISS,
## both in the screen's pixels; it has SPARE px/s over what gravity gives it,
## so gravity alone bends it and lets it go. PROGRADE of them turn the way
## the haze turns. Past FAR and leaving, a body is gone.
const SPAWN := 1350.0
const MISS := 760.0
const SPARE := 115.0
const PROGRADE := 0.75
const FAR := 2400.0
## Seconds between passers, and the wait is that times something in here.
const PASS := 3.2
const GAP_MIN := 0.6
const GAP_MAX := 1.4
## The most bodies in the sky. A throw past it takes the oldest meteor still
## up, so a sky parked full of circles outside the haze cannot grow for ever.
const MOST := 160
## Light is let go in pieces of a quarter of a body's mass, and never less
## than this.
const PIECE := 0.05
## Every TRAIL_EVERY ticks a body leaves a point of its trail, TRAIL at most:
## 1.2 s of where it has been.
const TRAIL_EVERY := 6
const TRAIL := 24
## Two bodies meet when their middles are this share of their radii apart.
const TOUCH := 0.8

## The tide (the user, 2026-10-06: "something orbiting sun too close should
## rip apart into smaller pieces"). The star pulls a body's near side harder
## than its far side, by GM x its radius / r^3. A big body is held by its own
## weight, which also goes by its radius, so it is torn at one distance
## whatever its size: ROCHE of the star's radii (a real star as dense as the
## Sun tears a loose rock at 1.9 of its own). A small one is a stone and
## held by that too, the more the smaller it is, so it gets nearer: a body
## HOLD px in radius is as much stone as weight, and torn the cube root of
## two nearer. A denser star (the Core perk) tears from further out.
const ROCHE := 1.8
const HOLD := 9.0
## Nothing is torn lighter than twice this share of a thrown meteor (which
## so comes apart once, in three), a body goes in PIECES at most at a time,
## and nothing is torn while the sky holds FULL bodies.
const CRUMB := 0.3
const PIECES := 4
const FULL := 300
## A piece starts this share of its body's radius from the body's middle.
const APART := 0.55

## What the star is made of (the user, 2026-10-06: "show mass compared to
## the sun ... show also temperature, composition and how much fuel it has to
## burn"). A new star is one Sun: `suns()` is its mass over START. STAR_H of
## it is hydrogen and STAR_HE helium, the rest rock. The share of a body of
## each Kind that is hydrogen: a comet is ice, a planetoid half gas, an ash
## what a star has already burnt.
const STAR_H := 0.7
const STAR_HE := 0.28
const HYDROGEN := [0.3, 0.2, 0.15, 0.9, 0.6, 0.1]
## A star of one Sun burns BURN of its own mass a second, hydrogen into
## helium, and a heavier one more of itself, by its Suns to the power HOT (a
## real star's is 2.5, and a heavy one is gone in no time). A mass burnt is
## SHINE light. With none left it goes dim: its powers sleep, nothing burns
## and nothing is lost, and it lights again once WAKE of its mass is
## hydrogen. DIM seconds from lit to dim and back.
const BURN := 0.0015
const HOT := 0.25
const SHINE := 2.0
const WAKE := 0.03
const DIM := 1.5
## Its temperature, in kelvin, by the logarithm of its mass; a dim star is
## COLD of that.
const TEMP := [[1.0, 3000.0], [2.0, 5800.0], [3.0, 9500.0], [4.5, 28000.0]]
const COLD := 0.55

## The shop is the hand's (the user, 2026-10-06: "the shop should be related
## to what player can do, for example bigger or faster bodies manual send"):
## a heavier meteor, one more of them a throw, meteors that keep leaving
## while the finger is down, and icier ones that bring more hydrogen.
const TILES := ["meteor", "volley", "stream", "ice"]
## A tile's first price in light, what each level multiplies it by, and its
## last level (0: it has none).
const TILE := {
	"meteor": [10.0, 1.5, 0],
	"volley": [60.0, 2.6, 0],
	"stream": [30.0, 1.8, 0],
	"ice": [20.0, 1.7, 6],
}
## Stream's first level lets a meteor go every STREAM seconds while the
## finger is down, each level after STREAM_STEP of that, never under
## STREAM_LEAST. A level of Ice is ICE_STEP more of a meteor in hydrogen.
const STREAM := 0.6
const STREAM_STEP := 0.85
const STREAM_LEAST := 0.08
const ICE_STEP := 0.1

## The star's powers (the user, 2026-10-06: "the sun powerup come as it grow,
## giving user powerup decisions to pick ... a powerup to use more fuel to
## create a solar wind that interfer in surrounding bodies orbit to make them
## start fall, or a another powerup that goes into a different direction").
## At each of MILES Suns, and every doubling after the last, two are offered
## that go different ways (WAY: 0 catches more, 1 makes more light, 2 saves
## hydrogen) and one is picked. A power is always on while the star is lit,
## burns COST of the star's plain burning more for each level, and goes with
## the star at a supernova.
const POWERS := ["wind", "haze", "beacon", "radiance", "furnace", "fusion", "thrift"]
const WAY := {"wind": 0, "haze": 0, "beacon": 0, "radiance": 1, "furnace": 1, "fusion": 1, "thrift": 2}
const COST := {"wind": 0.4, "haze": 0.25, "beacon": 0.3, "radiance": 0.3, "furnace": 0.25, "fusion": 0.2, "thrift": 0.0}
const MILES := [2.0, 4.0, 8.0, 15.0, 30.0, 60.0]
## Solar wind: a drag of WIND a level on what is outside the haze, out to
## WIND_REACH of the haze's radius, so a circle parked there comes down. It
## makes no light. Wide haze: HAZE_STEP wider a level. Beacon: bodies pass
## BEACON_SOON sooner and BEACON_RICH heavier. Radiance: RADIANCE more light
## from the haze. Tidal furnace: a torn body pays FURNACE light a mass.
## Fusion: the star's own burning pays one SHINE more a level. Thrift: it
## burns THRIFT as much.
const WIND := 0.012
const WIND_REACH := 3.0
const HAZE_STEP := 1.15
const BEACON_SOON := 0.8
const BEACON_RICH := 1.2
const RADIANCE := 0.3
const FURNACE := 0.15
const THRIFT := 0.7

## The star can go supernova from this mass on, for DUST stardust; a heavier
## star pays more, by the square root. The mark does not rise: each life is
## quicker to it than the last, and what a perk costs is the reason to go on
## past it (the first pass's mark rose four times a life and each life came
## out longer, the opposite of what was asked).
const NOVA := 1000.0
const DUST := 3.0
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
## The ashes a supernova leaves: ASHES and ASHES_LOG more for every tenfold
## of the star's mass over a hundred, ASHES_MOST at most, each on a closed
## path whose nearest point to the star is ASH_NEAR to ASH_NEAR + ASH_REACH
## of the new star's radii (the nearest a little outside its Roche radius)
## and whose furthest is inside ASH_FAR of them. In its radii and not in
## pixels: a new star the Ember perk has made heavier is wider too, and
## would have its nearest ashes inside it.
const ASHES := 14.0
const ASHES_LOG := 10.0
const ASHES_MOST := 48
const ASH_NEAR := 1.9
const ASH_REACH := 4.1
const ASH_FAR := 9.8
## A body tumbles up to this many radians a second, either way.
const TUMBLE := 0.75

## Where the star is kept. A harness points this elsewhere.
static var path := "user://nightlight.cfg"

var mass := START
var light := 0.0
var dust := 0
var novas := 0
var bought := 0
var lv := {"meteor": 0, "volley": 0, "stream": 0, "ice": 0}
var perk := {"core": 0, "disc": 0, "hand": 0, "crowd": 0, "ember": 0}
## The hydrogen left to burn and the helium it has made, both in mass; the
## rest of the star is rock.
var fuel := START * STAR_H
var spent := START * STAR_HE
## False while the star is out of hydrogen; `lit` follows it, 0 to 1.
var awake := true
var lit := 1.0
var power := {"wind": 0, "haze": 0, "beacon": 0, "radiance": 0, "furnace": 0, "fusion": 0, "thrift": 0}
## The powers picked this life, and the two on offer (empty when none is).
var picks := 0
var offer: Array = []
var bodies: Array[Body] = []
var clock := 0.0
## What happened since the screen last looked, oldest first:
## {kind: "eat", at, m}, {kind: "shed", at, e}, {kind: "merge", at},
## {kind: "tear", at, m}, {kind: "shine", e}.
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
var _pass_gap := 2.0
var _shine := 0.0

func _init(rng_seed := 0) -> void:
	if rng_seed != 0:
		_rng.seed = rng_seed
	else:
		_rng.randomize()

# --- what the star and the tiles are worth ---

## The star as the world has it.
func star_r() -> float:
	return STAR_R * pow(mass / START, 1.0 / 3.0)

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

func rock() -> float:
	return maxf(0.0, mass - fuel - spent)

## The levels of a power that are doing something: none while the star is dim.
func on(which: String) -> int:
	return int(power[which]) if awake else 0

## The hydrogen the star burns a second while it is lit: its plain burning,
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

## The star's temperature, in kelvin: hotter the heavier, and cold while dim.
func temp() -> float:
	var l := log(maxf(1.0, mass)) / log(10.0)
	var k: float = TEMP[TEMP.size() - 1][1]
	if l <= float(TEMP[0][0]):
		k = TEMP[0][1]
	else:
		for i in range(1, TEMP.size()):
			if l <= float(TEMP[i][0]):
				var from: float = TEMP[i - 1][0]
				k = lerpf(TEMP[i - 1][1], TEMP[i][1], (l - from) / (float(TEMP[i][0]) - from))
				break
	return k * lerpf(COLD, 1.0, lit)

## The haze's width, in the star's own radii.
func haze_wide() -> float:
	return HAZE * pow(HAZE_STEP, on("haze"))

## How far the solar wind reaches; 0 with none.
func wind_r() -> float:
	return haze_r() * WIND_REACH if on("wind") > 0 else 0.0

func haze_r() -> float:
	return star_r() * haze_wide()

func gm() -> float:
	return G * (1.0 + CORE * int(perk.core)) * mass

func glow() -> float:
	return (1.0 + RADIANCE * on("radiance")) * (1.0 + DISC * int(perk.disc))

func meteor_mass() -> float:
	return METEOR * (1.0 + int(lv.meteor)) * (1.0 + HAND * int(perk.hand))

## The share of a thrown meteor that is hydrogen.
func meteor_h() -> float:
	return minf(0.9, float(HYDROGEN[Kind.METEOR]) + ICE_STEP * int(lv.ice))

## How many meteors a throw lets go.
func volley() -> int:
	return 1 + int(lv.volley)

## Seconds between meteors while the finger is held down; 0 with no Stream.
func stream_gap() -> float:
	if int(lv.stream) <= 0:
		return 0.0
	return maxf(STREAM_LEAST, STREAM * pow(STREAM_STEP, int(lv.stream) - 1))

func pass_time() -> float:
	return PASS * pow(BEACON_SOON, on("beacon")) * pow(CROWD, int(perk.crowd))

## How heavy what passes is, against a first sky's.
func rich() -> float:
	return pow(BEACON_RICH, on("beacon")) * (1.0 + RICHER * novas)

static func body_r(m: float) -> float:
	return BODY_R * pow(m, 1.0 / 3.0)

## Inside this nothing big holds together, and nothing gathers.
func roche_r() -> float:
	return star_r() * ROCHE * pow(1.0 + CORE * int(perk.core), 1.0 / 3.0)

## The lightest piece the tide leaves.
func grain() -> float:
	return meteor_mass() * CRUMB

## How near the star a body of `m` gets before the tide has it in pieces; 0
## for one too small to be torn.
func tear_r(m: float) -> float:
	if m < grain() * 2.0:
		return 0.0
	var h := HOLD / body_r(m)
	return roche_r() / pow(1.0 + h * h, 1.0 / 3.0)

## Seconds a circle at `r` takes to go round.
func turn_time(r: float) -> float:
	return TAU * sqrt(r * r * r / gm())

## The speed of a circle at the bare haze's edge: what a throw is measured in.
func throw_speed() -> float:
	return sqrt(gm() / (HAZE * star_r()))

## The light a perfect spiral from the haze's edge pays for each of a body's
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

# --- the supernova ---

func can_nova() -> bool:
	return mass >= NOVA

## The stardust a supernova would pay now.
func dust_for() -> int:
	return 0 if mass < NOVA else int(floor(DUST * sqrt(mass / NOVA)))

## The mass at which it pays one more.
func next_dust_mass() -> float:
	if mass < NOVA:
		return NOVA
	return NOVA * pow((dust_for() + 1) / DUST, 2.0)

func perk_cost() -> int:
	return PERK + bought

## The star gives back what it ate. Its mass, its light, the tiles and its
## powers go; stardust, the perks and a richer sky stay. The ashes are left on closed
## paths round the new star, all turning the same way, the nearest of them
## already brushing its haze. Returns the stardust paid, 0 if it cannot yet.
func nova() -> int:
	if not can_nova():
		return 0
	var got := dust_for()
	var count := mini(ASHES_MOST, roundi(ASHES + ASHES_LOG * log(mass / 100.0) / log(10.0)))
	dust += got
	novas += 1
	mass = START * pow(EMBER, int(perk.ember))
	light = 0.0
	fuel = mass * STAR_H
	spent = mass * STAR_HE
	awake = true
	lit = 1.0
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
	var rw := star_r()
	for i in count:
		var near := (ASH_NEAR + _rng.randf() * ASH_REACH) * rw
		var far := near + 0.6 * rw + _rng.randf() * ((ASH_FAR - 0.6) * rw - near)
		var way := Vector2.from_angle(_rng.randf() * TAU)
		# let go at its furthest point, where it is slowest
		var v := sqrt(pull * (2.0 / far - 2.0 / (near + far)))
		add(Kind.ASH, MASS[Kind.ASH] * (1.0 + RICHER * novas) * _rng.randf_range(0.6, 1.4), way * far, way.orthogonal() * -v)
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
	b.h = HYDROGEN[kind]
	b.pos = pos
	b.vel = vel
	b.spin = _rng.randf() * TAU
	b.turn = _rng.randf_range(-TUMBLE, TUMBLE)
	bodies.append(b)
	return b

## A throw, let go at `pos` with `vel`: one meteor, or with Volley several
## side by side across the way they go. Nothing limits a throw.
func throw_at(pos: Vector2, vel: Vector2) -> void:
	var n := volley()
	var m := meteor_mass()
	var side := (vel if vel != Vector2.ZERO else pos).orthogonal().normalized() * body_r(m) * 2.4
	for k in n:
		if bodies.size() >= MOST:
			for i in bodies.size():
				if bodies[i].kind == Kind.METEOR:
					bodies.remove_at(i)
					break
		add(Kind.METEOR, m, pos + side * (k - (n - 1) * 0.5), vel).h = meteor_h()

## A body from far off, on an open path.
func _passer() -> void:
	var z := zoom()
	var out := SPAWN / z
	var way := Vector2.from_angle(_rng.randf() * TAU)
	var pos := way * out
	var u := _rng.randf()
	var kind := Kind.PEBBLE if u < MIX[0] else (Kind.ROCK if u < MIX[1] else (Kind.COMET if u < MIX[2] else Kind.PLANET))
	var miss := _rng.randf() * MISS / z * (1.0 if _rng.randf() < PROGRADE else -1.0)
	var aim := (way.orthogonal() * -miss - pos).normalized()
	var spare := SPARE / z
	add(kind, MASS[kind] * rich() * _rng.randf_range(0.8, 1.2), pos, aim * sqrt(spare * spare + 2.0 * gm() / out))

## The tide has the body at `at`: it is gone and its pieces are in its place,
## sharing its mass and its light unevenly, the heaviest first and still the
## body it was (its id, its trail). Each keeps the body's own motion and what
## its tumbling gave the place it was cut from, and nothing else: no push.
## The star pulls the nearer pieces harder, and that draws them out into a
## line along the path.
func _tear(at: int) -> void:
	var b := bodies[at]
	var n := clampi(int(b.m / grain()), 2, PIECES)
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
		var piece := add(b.kind, b.m * share, b.pos + off, b.vel - off.orthogonal() * b.turn)
		piece.e = b.e * share
		piece.h = b.h
		piece.heat = b.heat
		if k == 0:
			piece.id = b.id
			piece.spin = b.spin
			piece.trail = b.trail

## Two bodies that touch become one, and keep their momentum. Inside the
## star's Roche radius nothing does: what the tide pulls apart it does not
## let gather. The sky is
## laid on a grid as wide as the biggest body's reach, and a body is tried
## only against what is already in the nine cells round its own: with every
## pair tried, a sky of 160 was 2 ms a tick.
func _merge() -> void:
	var n := bodies.size()
	if n < 2:
		return
	var most := 0.0
	for b in bodies:
		most = maxf(most, b.m)
	var cell := maxf(1.0, body_r(most) * 2.0 * TOUCH)
	var grid := {}
	var gone := false
	var roche := roche_r()
	var inside := roche * roche
	for a in bodies:
		if a.pos.length_squared() < inside:
			continue
		var ra := body_r(a.m)
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
					var reach := (ra + body_r(b.m)) * TOUCH
					var d := a.pos - b.pos
					if absf(d.x) >= reach or absf(d.y) >= reach or d.length_squared() >= reach * reach:
						continue
					# the one already on the grid takes the other in, where it is filed
					var m := a.m + b.m
					if a.m > b.m:
						b.kind = a.kind
						b.id = a.id
						b.spin = a.spin
						b.turn = a.turn
						b.trail = a.trail
					b.vel = (a.vel * a.m + b.vel * b.m) / m
					b.pos = (a.pos * a.m + b.pos * b.m) / m
					b.h = (a.h * a.m + b.h * b.m) / m
					b.e += a.e
					b.m = m
					a.m = 0.0
					gone = true
					events.append({"kind": "merge", "at": b.pos})
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

## `delta` seconds pass, in whole ticks; what is left over waits. No more
## than `most` ticks a call, so a long frame does not become a longer one.
func advance(delta: float, most := 12) -> void:
	_acc += delta
	var n := mini(most, int(_acc / STEP))
	_acc = minf(_acc - n * STEP, STEP)
	for i in n:
		tick()

func tick() -> void:
	clock += STEP
	_tick += 1
	if passing:
		_pass_wait += STEP
		if _pass_wait >= _pass_gap:
			_pass_wait = 0.0
			_pass_gap = pass_time() * _rng.randf_range(GAP_MIN, GAP_MAX)
			_passer()
	var pull := gm()
	var rw := star_r()
	var rh := haze_r()
	var rwind := wind_r()
	var blow := WIND * on("wind")
	var eat := rw * EAT
	var far := FAR / zoom()
	var bind := pull / (2.0 * rw)
	var gl := glow()
	var roche := roche_r()
	var roche3 := roche * roche * roche
	var torn := grain() * 2.0
	var mark := _tick % TRAIL_EVERY == 0
	var i := bodies.size() - 1
	while i >= 0:
		var b := bodies[i]
		var p := b.pos
		var r2 := p.length_squared()
		var r := sqrt(r2)
		if r < eat:
			mass += b.m
			eaten += b.m
			fuel += b.m * b.h
			light += b.e
			events.append({"kind": "eat", "at": p, "m": b.m})
			bodies.remove_at(i)
			i -= 1
			continue
		if r > far and p.dot(b.vel) > 0.0:
			bodies.remove_at(i)
			i -= 1
			continue
		if r < roche and b.m >= torn and bodies.size() < FULL:
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
			var k := DRAG * d * d
			acc -= b.vel * k
			b.heat = d
			b.e += k * b.vel.length_squared() * STEP / bind * b.m * LIGHT * gl
			var q := maxf(PIECE, b.m * 0.25)
			if b.e >= q:
				b.e -= q
				light += q
				events.append({"kind": "shed", "at": p, "e": q})
		elif r < rwind:
			acc -= b.vel * blow
		b.vel += acc * STEP
		b.pos = p + b.vel * STEP
		b.spin += b.turn * STEP
		if mark:
			b.trail.append(b.pos)
			if b.trail.size() > TRAIL:
				b.trail.remove_at(0)
		i -= 1
	if _tick % 2 == 0:
		_merge()
	if burning:
		_burn()

## A tick of the star's own burning: hydrogen into helium, its plain share
## of that into light, let go a mote at a time. Out of hydrogen it sleeps,
## and wakes with WAKE of its mass in hydrogen again.
func _burn() -> void:
	if awake:
		var rate := _plain_burn()
		var plain := rate * STEP
		var use := plain * (1.0 + _more())
		if use >= fuel:
			plain *= fuel / use
			use = fuel
			awake = false
		fuel -= use
		spent += use
		_shine += plain * SHINE * (1.0 + int(power.fusion))
		var q := maxf(0.25, rate * SHINE * 0.6)
		if _shine >= q:
			_shine -= q
			light += q
			events.append({"kind": "shine", "e": q})
	elif fuel >= WAKE * mass:
		awake = true
	lit = move_toward(lit, 1.0 if awake else 0.0, STEP / DIM)

## Where a throw from `pos` with `vel` would go: a point every `every` ticks
## for `ticks` of them (seven seconds), stopping at the star. `hit` is
## whether it got there.
func predict(pos: Vector2, vel: Vector2, ticks := 840, every := 14) -> Dictionary:
	var pts := PackedVector2Array()
	var pull := gm()
	var eat := star_r() * EAT
	var rh := haze_r()
	var rwind := wind_r()
	var blow := WIND * on("wind")
	var hit := false
	for i in ticks:
		var r2 := pos.length_squared()
		var r := sqrt(r2)
		if r < eat:
			hit = true
			break
		var acc := pos * (-pull / (r2 * r))
		if r < rh:
			var d := 1.0 - r / rh
			acc -= vel * (DRAG * d * d)
		elif r < rwind:
			acc -= vel * blow
		vel += acc * STEP
		pos += vel * STEP
		if i % every == every - 1:
			pts.append(pos)
	return {"pts": pts, "hit": hit}

## A steady hand, for the probe and the tutorial's page: a meteor into the
## outer haze, a little under the speed of a circle there.
func bot_throw() -> void:
	var r := haze_r() * _rng.randf_range(0.55, 0.9)
	var way := Vector2.from_angle(_rng.randf() * TAU)
	throw_at(way * r, way.orthogonal() * -sqrt(gm() / r) * _rng.randf_range(0.8, 1.05))

# --- keeping ---

## Writes the star and its sky to `path`.
func save() -> void:
	var cfg := ConfigFile.new()
	for tile: String in TILES:
		cfg.set_value("lv", tile, int(lv[tile]))
	for which: String in PERKS:
		cfg.set_value("perk", which, int(perk[which]))
	for which: String in POWERS:
		cfg.set_value("power", which, int(power[which]))
	cfg.set_value("star", "fuel", fuel)
	cfg.set_value("star", "spent", spent)
	cfg.set_value("star", "picks", picks)
	cfg.set_value("star", "offer", offer)
	cfg.set_value("star", "mass", mass)
	cfg.set_value("star", "light", light)
	cfg.set_value("star", "dust", dust)
	cfg.set_value("star", "novas", novas)
	cfg.set_value("star", "bought", bought)
	cfg.set_value("star", "eaten", eaten)
	var kept := []
	for b in bodies:
		kept.append([int(b.kind), b.m, b.pos.x, b.pos.y, b.vel.x, b.vel.y, b.h])
	cfg.set_value("star", "bodies", kept)
	cfg.save(path)

## The star as it was left, with its sky. A first visit, or a file that
## cannot be read, is a new star of START mass in an empty sky. Nothing
## happens while the game is closed.
static func load_saved(rng_seed := 0) -> RefCounted:
	var sim: RefCounted = (load("res://arcade/nightlight_sim.gd") as GDScript).new(rng_seed)
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK or not cfg.has_section_key("star", "mass"):
		return sim
	for tile: String in TILES:
		var level := maxi(0, int(cfg.get_value("lv", tile, 0)))
		sim.lv[tile] = level if sim.last_level(tile) == 0 else mini(level, sim.last_level(tile))
	for which: String in PERKS:
		sim.perk[which] = maxi(0, int(cfg.get_value("perk", which, 0)))
	sim.mass = maxf(START, float(cfg.get_value("star", "mass", START)))
	sim.light = maxf(0.0, float(cfg.get_value("star", "light", 0.0)))
	sim.dust = maxi(0, int(cfg.get_value("star", "dust", 0)))
	sim.novas = maxi(0, int(cfg.get_value("star", "novas", 0)))
	sim.bought = maxi(0, int(cfg.get_value("star", "bought", 0)))
	sim.eaten = maxf(0.0, float(cfg.get_value("star", "eaten", 0.0)))
	# a star kept before it burnt anything: as much hydrogen as what it ate
	# would have left it
	sim.fuel = clampf(float(cfg.get_value("star", "fuel", sim.mass * 0.3)), 0.0, sim.mass)
	sim.spent = clampf(float(cfg.get_value("star", "spent", sim.mass * 0.3)), 0.0, sim.mass - sim.fuel)
	sim.awake = sim.fuel > 0.0
	sim.lit = 1.0 if sim.awake else 0.0
	for which: String in POWERS:
		sim.power[which] = maxi(0, int(cfg.get_value("power", which, 0)))
	# a star kept before there were powers has every pick it grew past to make
	sim.picks = clampi(int(cfg.get_value("star", "picks", 0)), 0, sim.passed())
	var two = cfg.get_value("star", "offer", [])
	if two is Array and (two as Array).size() == 2 and POWERS.has(two[0]) and POWERS.has(two[1]):
		sim.offer = [String(two[0]), String(two[1])]
	for row in cfg.get_value("star", "bodies", []):
		if not (row is Array) or (row as Array).size() < 6 or sim.bodies.size() >= FULL:
			continue
		var m := float(row[1])
		var pos := Vector2(float(row[2]), float(row[3]))
		if m <= 0.0 or not pos.is_finite() or pos.length() < 1.0:
			continue
		var b: Body = sim.add(clampi(int(row[0]), 0, Kind.size() - 1) as Kind, m, pos, Vector2(float(row[4]), float(row[5])))
		if (row as Array).size() > 6:
			b.h = clampf(float(row[6]), 0.0, 1.0)
	return sim

## What the Arcade tab says of the kept star without building it: its mass
## and its supernovas, both 0 if there is none yet.
static func kept() -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK or not cfg.has_section_key("star", "mass"):
		return {"mass": 0.0, "novas": 0}
	return {"mass": float(cfg.get_value("star", "mass", 0.0)), "novas": int(cfg.get_value("star", "novas", 0))}
