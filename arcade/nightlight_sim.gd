extends RefCounted

## Nightlight, as pure data: a small star in the middle of a night sky, the
## meteors thrown at it, the bodies that cross the sky on their own, four
## tiles bought with light, and the supernova that gives everything back and
## starts a small star again among its ashes. Kept and without an end (the
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
## Nothing here draws or reads the clock. The screen
## (arcade/nightlight_screen.gd) calls `advance`, drains `events` and keeps
## the file; `tests/_probe_nightlight.gd` plays it with a bot. Lengths are
## the screen's own 1080-wide pixels as the game starts, measured from the
## star at (0, 0); the view draws back as the star grows (`zoom`).

enum Kind { METEOR, PEBBLE, ROCK, COMET, PLANET, ASH }

## One body in the sky. `e` is the light the haze has made of it and not yet
## let go; `heat` how deep in the haze it is, 0 outside; `trail` where it
## has been, oldest first.
class Body:
	var id := 0
	var kind := Kind.METEOR
	var m := 1.0
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
const G := 1.13e6
const DRAG := 0.25
const LIGHT := 1.5
## A new star's mass and its radius; the radius is the cube root of the mass.
const START := 10.0
const STAR_R := 46.0
## Past SEEN pixels on the screen the star grows only by the logarithm and
## the view draws back instead.
const SEEN := 80.0
const SEEN_LOG := 24.0
## A body is eaten this far inside the star's edge.
const EAT := 0.92
## The haze is this many of the star's radii wide, before the Haze tile.
const HAZE := 5.0
const HAZE_STEP := 1.08
## A body's radius is the cube root of its mass times this.
const BODY_R := 14.0
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
const SPARE := 230.0
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
## Every TRAIL_EVERY ticks a body leaves a point of its trail, TRAIL at most.
const TRAIL_EVERY := 3
const TRAIL := 24
## Two bodies meet when their middles are this share of their radii apart.
const TOUCH := 0.8

const TILES := ["meteor", "haze", "glow", "sky"]
## A tile's first price in light, what each level multiplies it by, and its
## last level (0: it has none).
const TILE := {
	"meteor": [10.0, 1.5, 0],
	"haze": [25.0, 1.7, 10],
	"glow": [20.0, 1.6, 0],
	"sky": [30.0, 1.65, 0],
}
## What a level of each tile does.
const GLOW_STEP := 0.2
const SKY_SOON := 0.92
const SKY_RICH := 1.2

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
## path whose nearest point to the star is within these bounds and whose
## furthest is inside ASH_FAR.
const ASHES := 14.0
const ASHES_LOG := 10.0
const ASHES_MOST := 48
const ASH_NEAR := 170.0
const ASH_REACH := 430.0
const ASH_FAR := 980.0

## Where the star is kept. A harness points this elsewhere.
static var path := "user://nightlight.cfg"

var mass := START
var light := 0.0
var dust := 0
var novas := 0
var bought := 0
var lv := {"meteor": 0, "haze": 0, "glow": 0, "sky": 0}
var perk := {"core": 0, "disc": 0, "hand": 0, "crowd": 0, "ember": 0}
var bodies: Array[Body] = []
var clock := 0.0
## What happened since the screen last looked, oldest first:
## {kind: "eat", at, m}, {kind: "shed", at, e}, {kind: "merge", at}.
var events: Array[Dictionary] = []
## Everything this star and the ones before it ate, for the record.
var eaten := 0.0
## False for a sky with nothing crossing it (a tutorial's page).
var passing := true

var _rng := RandomNumberGenerator.new()
var _next_id := 1
var _tick := 0
var _acc := 0.0
var _pass_wait := 0.0
var _pass_gap := 2.0

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

## The haze's width, in the star's own radii.
func haze_wide() -> float:
	return HAZE * pow(HAZE_STEP, int(lv.haze))

func haze_r() -> float:
	return star_r() * haze_wide()

func gm() -> float:
	return G * (1.0 + CORE * int(perk.core)) * mass

func glow() -> float:
	return (1.0 + GLOW_STEP * int(lv.glow)) * (1.0 + DISC * int(perk.disc))

func meteor_mass() -> float:
	return METEOR * (1.0 + int(lv.meteor)) * (1.0 + HAND * int(perk.hand))

func pass_time() -> float:
	return PASS * pow(SKY_SOON, int(lv.sky)) * pow(CROWD, int(perk.crowd))

## How heavy what passes is, against a first sky's.
func rich() -> float:
	return pow(SKY_RICH, int(lv.sky)) * (1.0 + RICHER * novas)

static func body_r(m: float) -> float:
	return BODY_R * pow(m, 1.0 / 3.0)

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

## The star gives back what it ate. Its mass, its light and the tiles go;
## stardust, the perks and a richer sky stay. The ashes are left on closed
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
	for tile: String in TILES:
		lv[tile] = 0
	bodies.clear()
	events.clear()
	_pass_wait = 0.0
	var pull := gm()
	for i in count:
		var near := ASH_NEAR + _rng.randf() * ASH_REACH
		var far := near + 60.0 + _rng.randf() * (ASH_FAR - 60.0 - near)
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
	b.pos = pos
	b.vel = vel
	b.spin = _rng.randf() * TAU
	b.turn = _rng.randf_range(-1.5, 1.5)
	bodies.append(b)
	return b

## A meteor, let go at `pos` with `vel`. Nothing limits a throw.
func throw_at(pos: Vector2, vel: Vector2) -> void:
	if bodies.size() >= MOST:
		for i in bodies.size():
			if bodies[i].kind == Kind.METEOR:
				bodies.remove_at(i)
				break
	add(Kind.METEOR, meteor_mass(), pos, vel)

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

## Two bodies that touch become one, and keep their momentum. The sky is
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
	for a in bodies:
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
	var eat := rw * EAT
	var far := FAR / zoom()
	var bind := pull / (2.0 * rw)
	var gl := glow()
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
			light += b.e
			events.append({"kind": "eat", "at": p, "m": b.m})
			bodies.remove_at(i)
			i -= 1
			continue
		if r > far and p.dot(b.vel) > 0.0:
			bodies.remove_at(i)
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

## Where a throw from `pos` with `vel` would go: a point every `every` ticks
## for `ticks` of them, stopping at the star. `hit` is whether it got there.
func predict(pos: Vector2, vel: Vector2, ticks := 420, every := 7) -> Dictionary:
	var pts := PackedVector2Array()
	var pull := gm()
	var eat := star_r() * EAT
	var rh := haze_r()
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
	cfg.set_value("star", "mass", mass)
	cfg.set_value("star", "light", light)
	cfg.set_value("star", "dust", dust)
	cfg.set_value("star", "novas", novas)
	cfg.set_value("star", "bought", bought)
	cfg.set_value("star", "eaten", eaten)
	var kept := []
	for b in bodies:
		kept.append([int(b.kind), b.m, b.pos.x, b.pos.y, b.vel.x, b.vel.y])
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
	for row in cfg.get_value("star", "bodies", []):
		if not (row is Array) or (row as Array).size() < 6 or sim.bodies.size() >= 200:
			continue
		var m := float(row[1])
		var pos := Vector2(float(row[2]), float(row[3]))
		if m <= 0.0 or not pos.is_finite() or pos.length() < 1.0:
			continue
		sim.add(clampi(int(row[0]), 0, Kind.size() - 1) as Kind, m, pos, Vector2(float(row[4]), float(row[5])))
	return sim

## What the Arcade tab says of the kept star without building it: its mass
## and its supernovas, both 0 if there is none yet.
static func kept() -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK or not cfg.has_section_key("star", "mass"):
		return {"mass": 0.0, "novas": 0}
	return {"mass": float(cfg.get_value("star", "mass", 0.0)), "novas": int(cfg.get_value("star", "novas", 0))}
