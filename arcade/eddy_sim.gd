extends RefCounted

## Eddy as pure data (spec
## docs/superpowers/specs/2026-10-10-arcade-eddy-design.md): a whirlpool
## steered about a pond, drawing in what floats there. The screen
## (arcade/eddy_screen.gd) hands `steer()` the pad's lean, calls `step()` at
## the fixed DT and drains `events`.
##
## The water is a real one. The whirlpool is a vortex with a core: inside the
## core the water turns as one piece, outside it the turning falls off with
## distance, so a thing drawn in goes round faster and faster the nearer it
## gets. Everything afloat is carried by drag alone -- it takes up the
## water's speed over its own `tau`, a leaf in a third of a second, a ball in
## two -- and nothing is ever moved by rule. So a small whirlpool cannot
## grip a thing wider than itself (`grip`), and a thing goes down only once
## it is in the core, going round with the water, and no wider than the
## mouth. The core's water travels with the whirlpool, so a thing the mouth
## comes over is taken as it goes; one it passes a little wide of is tugged
## and left turning.
##
## A run is one of many (the user, 2026-10-11: "a slow incremental where user
## buy upgrades to go further and further, not a one take game", spec
## docs/superpowers/specs/2026-10-11-eddy-incremental-design.md). What it
## scores is banked, the bank buys four upgrades that are kept
## (arcade/eddy_upgrades.gd), and `fit()` hands a fresh run their levels: a
## longer spin, more of the turning run inward, a wider mouth from the first,
## a longer reach and a faster travel. The sim knows nothing of the bank.
##
## The pond is `w` wide and `h` tall, y down. Lengths are pond units, speeds
## units a second. The game's pond is WIDE by TALL whatever the phone, far
## more than is looked at at once (`view_of`); a tutorial page lays a small
## one.

enum Phase { READY, PLAY, DRAIN, OVER }
enum Kind { LEAF, PETAL, ACORN, DUCK, BOAT, BALL, BUCKET, CAN, LILO, RAFT, ROWBOAT }

const DT := 1.0 / 60.0
## The pond the game is played on (the user, 2026-10-10: "a fixed bigger
## water scene with all objects rendered, and camera start to zoom out as
## user get bigger"), and how much water SMALL and BIG are counted for: a
## pond holds as many times those as it has that much water. It was 600 by
## 1000 until the camera came closer (VIEW): it is as many looks wide as it
## was, two and a half, and holds as much, so the water is as full to the
## eye as it was.
const WIDE := 400.0
const TALL := 660.0
const ROOM := 300.0 * 320.0
## How much of the pond's width is looked at round a whirlpool of level 1
## (240 until the user, 2026-10-11: "camera is too far, it should be closer
## to the vortex"), and the power of its core's growth the look widens by. The screen's
## camera reads it, and so does the stocking: a new thing comes onto the
## water out of sight.
const VIEW := 150.0
const VIEW_POW := 0.5
## The whirlpool's fastest travel with nothing bought and how quickly it
## answers the pad. It is slow on purpose (the user, 2026-10-10: "speed is
## too fast, it should be way slower to move", of 150, and 2026-10-11, of
## 60: "movement is too fast yet, it should be way slower"): six seconds
## across what is looked at, seventeen across the pond. Faster is bought
## (`speed`, SPEED_UP; the user, 2026-10-12: "we need a upgrade to increase
## speed of movement").
const SPEED := 24.0
const ANSWER := 0.3
## It grows through these levels.
const LEVELS := 20
## The core's radius at level 1 and what a level adds.
const CORE := 7.0
const CORE_STEP := 2.6
## The water's speed round the core's edge at level 1, and a level's more.
const TURN := 60.0
const TURN_STEP := 8.0
## How much of the turning also runs inward, and how many cores out the
## whirlpool is felt at all.
const INFLOW := 0.45
const REACH := 4.5
## A thing is gripped whole when the core is this many times its own
## radius; under that the grip falls off as the cube.
const GRIP := 1.4
## A thing goes down once it is this far into the core (a part of its
## radius) and goes round with the water there to within SLIP, at level 1;
## the leeway grows as the turning does (`turn_of`). Its going round is
## taken in the whirlpool's own frame, so the whirlpool's travel is no part
## of it: what the mouth comes over on the move goes down as what it waits
## beside does.
const MOUTH := 0.95
const SLIP := 10.0
## What is swallowed to leave level 1, how much more each level asks, and
## how much more again by the square of the levels made (none until
## 2026-10-12: once a whirlpool took what it went over, the big things went
## down as fast as they were crossed and a rowing boat was four runs off,
## not fifty; at 3 a level asks about eight of the newest kind it takes).
const GROW := 6
const GROW_STEP := 6
const GROW_CURVE := 3.0
## The spin: seconds of turning in a run with nothing bought, and what a
## level gives back.
const SPIN := 30.0
const SPIN_BACK := 4.0
## What a level of each of the shop's upgrades is worth: seconds of spin,
## inflow, units of core at level 1, cores of reach, units a second of travel.
const SPIN_UP := 2.0
const PULL_UP := 0.05
const MOUTH_UP := 0.6
const REACH_UP := 0.2
const SPEED_UP := 2.0
## Under this part of the spin the run says so, once.
const LOW := 0.25
## The whirlpool unwinding at the end.
const DRAIN_T := 1.4
## Each kind: its tier, the radius it is weighed at, the seconds it takes
## to take up the water's speed, its points, what it adds to the growing,
## and how long it is in going down.
const KINDS := [
	{"tier": 1, "r": 4.8, "tau": 0.35, "value": 1, "mass": 1, "sink": 0.8},
	{"tier": 1, "r": 4.0, "tau": 0.28, "value": 1, "mass": 1, "sink": 0.7},
	{"tier": 1, "r": 4.4, "tau": 0.5, "value": 2, "mass": 1, "sink": 0.8},
	{"tier": 2, "r": 11.0, "tau": 1.4, "value": 10, "mass": 6, "sink": 1.3},
	{"tier": 2, "r": 13.0, "tau": 1.8, "value": 15, "mass": 8, "sink": 1.4},
	{"tier": 2, "r": 15.0, "tau": 2.2, "value": 20, "mass": 10, "sink": 1.5},
	{"tier": 3, "r": 21.0, "tau": 2.8, "value": 40, "mass": 22, "sink": 1.7},
	{"tier": 3, "r": 24.0, "tau": 3.2, "value": 50, "mass": 28, "sink": 1.8},
	{"tier": 3, "r": 27.0, "tau": 3.6, "value": 60, "mass": 34, "sink": 1.9},
	{"tier": 4, "r": 33.0, "tau": 4.5, "value": 120, "mass": 60, "sink": 2.2},
	{"tier": 4, "r": 38.0, "tau": 5.5, "value": 160, "mass": 80, "sink": 2.4},
]
const TIERS := 4
## How many of each tier the pond keeps afloat, and the most let in a second.
const SMALL := 104
const SMALL_STEP := 5
const BIG := 10
const BIG_STEP := 1.5
## The third and fourth tiers, there from the first run to be grown into.
const GREAT := 2.4
const HUGE := 1.2
const LET_IN := 2.5
## A thing's own slow wander, and the push that brings a new one in from the
## bank for its first seconds where the pond is too small to hide it.
const WANDER := 4.0
const PUSH := 16.0
const FRESH := 3.0
## The whirlpool's middle comes no nearer the bank than this, and nothing
## afloat nearer than this and its own radius.
const BANK := 8.0

var rng := RandomNumberGenerator.new()
var phase := Phase.READY
var phase_t := 0.0
## Seconds of play.
var t := 0.0
var w := WIDE
var h := TALL
var pos := Vector2.ZERO
var vel := Vector2.ZERO
## The pad's lean, a length of 0 to 1.
var lean := Vector2.ZERO
var level := 1
## Swallowed since the last level, of `need()`.
var grown := 0
var spin := SPIN
var spin_full := SPIN
var score := 0
## Things swallowed, of each tier, and the biggest kind among them (-1 none).
var taken := [0, 0, 0, 0, 0]
var biggest := -1
## The shop's upgrades as this run has them (`fit`): the core at level 1,
## the part of the turning that runs inward, the cores it is felt out to and
## its fastest travel.
var core0 := CORE
var inflow := INFLOW
var far := REACH
var speed := SPEED
var events: Array = []
## What floats: {id, kind, look, pos, vel, ang, turn, drift, fresh, age,
## sink (seconds of going down, -1 afloat), rad, a, from}.
var things: Array = []
## The pond keeps itself stocked; a tutorial page lays its own.
var stocks := true
var _next_id := 0
var _let := 0.0
var _low_said := false
var _big_said := -10.0

func _init(seed_value := -1, tall := TALL, wide := WIDE) -> void:
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	h = tall
	w = wide
	pos = Vector2(w, h) * 0.5
	_stock_first()
	events.append({"type": "ready"})

func is_over() -> bool:
	return phase == Phase.OVER

## A fresh run's upgrades, each a level of 0 and up: {spin, pull, mouth,
## reach, speed}.
func fit(ups: Dictionary) -> void:
	spin_full = SPIN + SPIN_UP * int(ups.get("spin", 0))
	spin = spin_full
	inflow = INFLOW + PULL_UP * int(ups.get("pull", 0))
	core0 = CORE + MOUTH_UP * int(ups.get("mouth", 0))
	far = REACH + REACH_UP * int(ups.get("reach", 0))
	speed = SPEED + SPEED_UP * int(ups.get("speed", 0))

## The core at level `lv` of a whirlpool whose first is `base`.
static func core_of(lv: int, base := CORE) -> float:
	return base + CORE_STEP * (lv - 1)

## How many units across the pond is looked at round a core of `rc`: never
## more than the pond is wide.
static func view_of(rc: float) -> float:
	return minf(VIEW * pow(rc / CORE, VIEW_POW), WIDE)

static func turn_of(lv: int) -> float:
	return TURN + TURN_STEP * (lv - 1)

## What a whirlpool of level `lv` must swallow to grow.
static func need_of(lv: int) -> int:
	return GROW + GROW_STEP * (lv - 1) + int(GROW_CURVE * (lv - 1) * (lv - 1))

## The first level whose mouth takes `kind`.
static func level_for(kind: int, base := CORE) -> int:
	for lv in range(1, LEVELS + 1):
		if grip_of(kind, lv, base) >= 1.0:
			return lv
	return LEVELS

## How much of the water's pull a thing of `kind` feels at level `lv`, 0 to 1.
static func grip_of(kind: int, lv: int, base := CORE) -> float:
	var k := clampf(core_of(lv, base) / (float(KINDS[kind].r) * GRIP), 0.0, 1.0)
	return k * k * k

func core() -> float:
	return core_of(level, core0)

func reach() -> float:
	return core() * far

## This run's own: how much of its pull `kind` feels now, and the level its
## mouth first takes it.
func grip(kind: int) -> float:
	return grip_of(kind, level, core0)

func opens_at(kind: int) -> int:
	return level_for(kind, core0)

func need() -> int:
	return need_of(level)

## How strongly the whirlpool turns just now: 1 in play, falling to nothing
## as it unwinds.
func strength() -> float:
	if phase == Phase.DRAIN:
		return clampf(1.0 - phase_t / DRAIN_T, 0.0, 1.0)
	return 0.0 if phase == Phase.OVER else 1.0

## The pad's lean. The first one of a run sets the spin running.
func steer(dir: Vector2) -> void:
	lean = dir.limit_length(1.0)
	if phase == Phase.READY and lean.length() > 0.0:
		phase = Phase.PLAY
		phase_t = 0.0
		events.append({"type": "go"})

## The whirlpool's own water at `p`, in its own frame: round and inward.
func swirl(p: Vector2) -> Vector2:
	var d := p - pos
	var r := d.length()
	var out := reach()
	if r >= out or r < 0.001:
		return Vector2.ZERO
	var rc := core()
	var vt := turn_of(level) * (r / rc if r < rc else rc / r) * strength()
	var n := d / r
	var fade := 1.0 - smoothstep(out * 0.55, out, r)
	return (Vector2(-n.y, n.x) * vt - n * vt * inflow) * fade

## How much of the whirlpool's travel the water at `r` from its middle
## shares: all of it in the core, none two cores out. It does at any speed
## (the user, 2026-10-12: "it should absorv items while move not only when
## it's stopped"): until then a whirlpool in a hurry left its core's water
## behind and kept a twelfth of its pull, so it took nothing it crossed.
func carry(r: float) -> float:
	var rc := core()
	return 1.0 - smoothstep(rc, rc * 2.0, r)

func step() -> void:
	phase_t += DT
	match phase:
		Phase.READY:
			_float_all()
		Phase.PLAY:
			t += DT
			_move()
			_float_all()
			_restock()
			spin -= DT
			if not _low_said and spin <= spin_full * LOW:
				_low_said = true
				events.append({"type": "low"})
			if spin <= 0.0:
				spin = 0.0
				phase = Phase.DRAIN
				phase_t = 0.0
				lean = Vector2.ZERO
				events.append({"type": "drain"})
		Phase.DRAIN:
			vel = vel.lerp(Vector2.ZERO, minf(1.0, DT * 4.0))
			pos += vel * DT
			_float_all()
			if phase_t >= DRAIN_T:
				phase = Phase.OVER
				phase_t = 0.0
				events.append({"type": "over"})
		Phase.OVER:
			_float_all()

func _move() -> void:
	vel = vel.lerp(lean * speed, 1.0 - exp(-DT / ANSWER))
	pos += vel * DT
	var lo := Vector2(BANK, BANK)
	var hi := Vector2(w - BANK, h - BANK)
	if pos.x < lo.x or pos.x > hi.x:
		vel.x = 0.0
	if pos.y < lo.y or pos.y > hi.y:
		vel.y = 0.0
	pos = pos.clamp(lo, hi)

func _float_all() -> void:
	var rc := core()
	var live := strength() > 0.0
	var i := things.size() - 1
	while i >= 0:
		var th: Dictionary = things[i]
		th.age = float(th.age) + DT
		if float(th.sink) >= 0.0:
			if _sink(th, rc):
				things.remove_at(i)
		else:
			_drift(th, rc, live)
		i -= 1

## One thing afloat for one step: carried by the water it sits in.
func _drift(th: Dictionary, rc: float, live: bool) -> void:
	var kind: Dictionary = KINDS[th.kind]
	var p: Vector2 = th.pos
	var v: Vector2 = th.vel
	var own: Vector2 = th.drift
	if float(th.fresh) > 0.0:
		th.fresh = float(th.fresh) - DT
	else:
		own = own.limit_length(WANDER)
		th.drift = own.rotated(DT * 0.15 * (1.0 if int(th.id) % 2 == 0 else -1.0))
	var water := own
	var r := p.distance_to(pos)
	var g := 0.0
	if live and r < rc * far:
		g = grip(th.kind)
		var round := swirl(p)
		var along := vel * carry(r)
		water += (round + along) * g
		# What goes round is pressed toward the middle, as the turning water
		# itself is, or drag alone would fling it out like a stone on a
		# string. The water presses on a thing only as hard as its own going
		# round asks, and no harder than the water there goes round itself:
		# so a leaf lying still as a whirlpool goes by out of reach is pressed
		# by nothing. Its going round is counted on the water it sits in, which
		# near the middle travels with the whirlpool: counted on the pond, a
		# whirlpool on the move pressed a leaf on one side of it too little
		# and flung it out ahead.
		if r > 0.001:
			var n := (p - pos) / r
			var side := Vector2(-n.y, n.x)
			var going := clampf((v - along).dot(side), 0.0, round.dot(side))
			v -= n * (going * going / maxf(r, rc * 0.25)) * DT
	v += (water - v) * (1.0 - exp(-DT / float(kind.tau)))
	p += v * DT
	# the bank turns a thing back
	var lo := BANK + float(kind.r)
	if p.x < lo or p.x > w - lo:
		p.x = clampf(p.x, lo, w - lo)
		v.x = -v.x * 0.3
		th.drift = Vector2(-own.x, own.y)
	if p.y < lo or p.y > h - lo:
		p.y = clampf(p.y, lo, h - lo)
		v.y = -v.y * 0.3
		th.drift = Vector2(th.drift.x, -own.y)
	th.pos = p
	th.vel = v
	# it turns with the water round it
	var want := 0.0
	if g > 0.0 and r > 0.001:
		want = turn_of(level) * (1.0 / rc if r < rc else rc / (r * r)) * g * strength() * (1.0 - smoothstep(rc * far * 0.55, rc * far, r))
	th.turn = lerpf(float(th.turn), want, minf(1.0, DT * 3.0))
	th.ang = float(th.ang) + (float(th.turn) + float(th.idle)) * DT
	if not live or r > rc * MOUTH:
		return
	if g < 1.0:
		# sat on a mouth too small for it
		if t - _big_said > 4.0 and phase == Phase.PLAY:
			_big_said = t
			events.append({"type": "too_big", "kind": th.kind, "at": p, "level": opens_at(th.kind)})
		return
	if phase != Phase.PLAY:
		return
	# down it goes, once it goes round with the water
	var n := (p - pos) / maxf(r, 0.001)
	var side := Vector2(-n.y, n.x)
	var rel := v - vel
	if absf(rel.dot(side) - swirl(p).dot(side)) <= SLIP * turn_of(level) / TURN:
		th.sink = 0.0
		th.rad = r
		th.a = (p - pos).angle()
		th.from = r
		events.append({"type": "catch", "kind": th.kind, "tier": kind.tier, "at": p})

## One thing going down: round the middle, nearer and faster, then gone.
## True once it is.
func _sink(th: Dictionary, rc: float) -> bool:
	var kind: Dictionary = KINDS[th.kind]
	th.sink = float(th.sink) + DT
	var k := clampf(float(th.sink) / float(kind.sink), 0.0, 1.0)
	th.rad = float(th.from) * (1.0 - k * k)
	var w := turn_of(level) / rc * (1.0 + 2.4 * k * k)
	th.a = float(th.a) + w * DT
	th.turn = w
	th.ang = float(th.ang) + w * DT
	th.pos = pos + Vector2.from_angle(th.a) * float(th.rad)
	th.vel = vel
	if k < 1.0:
		return false
	_swallow(th)
	return true

func _swallow(th: Dictionary) -> void:
	var kind: Dictionary = KINDS[th.kind]
	score += int(kind.value)
	taken[kind.tier] += 1
	biggest = maxi(biggest, int(th.kind))
	events.append({"type": "swallow", "kind": th.kind, "tier": kind.tier, "value": kind.value, "at": pos})
	if level >= LEVELS:
		return
	grown += int(kind.mass)
	while level < LEVELS and grown >= need():
		grown -= need()
		level += 1
		# a thing still going down as the whirlpool unwinds makes its level,
		# but gives no spin back: the run is over and the bar stays empty
		if phase == Phase.PLAY:
			spin = minf(spin_full, spin + SPIN_BACK)
			_low_said = spin <= spin_full * LOW
		events.append({"type": "level", "n": level, "opens": _opened(level)})
	if level >= LEVELS:
		grown = 0

## The kinds whose first level is `lv`.
func _opened(lv: int) -> Array:
	var out := []
	for kind in KINDS.size():
		if lv > 1 and opens_at(kind) == lv:
			out.append(kind)
	return out

# --- what floats ---

## Lays one thing on the water and gives it back.
func put(kind: int, at: Vector2, push := Vector2.ZERO) -> Dictionary:
	var th := {"id": _next_id, "kind": kind, "look": rng.randi() % 3, "pos": at, "vel": push,
		"ang": rng.randf() * TAU, "turn": 0.0, "idle": rng.randf_range(-0.25, 0.25),
		"drift": Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(1.0, WANDER),
		"fresh": 0.0, "age": 0.0, "sink": -1.0, "rad": 0.0, "a": 0.0, "from": 0.0}
	_next_id += 1
	things.append(th)
	return th

func _small_kind() -> int:
	var roll := rng.randf()
	return Kind.LEAF if roll < 0.55 else (Kind.PETAL if roll < 0.82 else Kind.ACORN)

## A big thing: ducks mostly. A small pond gets the larger toys once the
## whirlpool has grown some; the game's has every kind from the first.
func _big_kind() -> int:
	var roll := rng.randf()
	if (level >= 4 or w > 300.0) and roll < 0.22:
		return Kind.BALL
	if (level >= 3 or w > 300.0) and roll < 0.5:
		return Kind.BOAT
	return Kind.DUCK

## How many times the water SMALL and BIG are counted for this pond has.
func room() -> float:
	return w * h / ROOM

func _stock_first() -> void:
	var mid := pos
	for i in int(SMALL * room()):
		put(_small_kind(), _free_place(mid, 36.0, 0.0))
	# every kind is there from the first, the big ones to be grown into
	var toys := [Kind.DUCK, Kind.DUCK, Kind.DUCK, Kind.BOAT, Kind.DUCK, Kind.BALL, Kind.BOAT, Kind.DUCK]
	for i in int(BIG * room()):
		put(toys[i % toys.size()], _free_place(mid, 80.0, 30.0))
	var great := [Kind.BUCKET, Kind.CAN, Kind.LILO]
	for i in int(GREAT * room()):
		put(great[i % great.size()], _free_place(mid, 140.0, 70.0))
	var huge := [Kind.RAFT, Kind.ROWBOAT]
	for i in int(HUGE * room()):
		put(huge[i % huge.size()], _free_place(mid, 200.0, 110.0))
	for th: Dictionary in things:
		th.age = 10.0

## A place on the water at least `clear` from `from` and `apart` from every
## big thing.
func _free_place(from: Vector2, clear: float, apart: float) -> Vector2:
	var p := Vector2.ZERO
	for attempt in 30:
		p = Vector2(rng.randf_range(BANK + 16.0, w - BANK - 16.0), rng.randf_range(BANK + 16.0, h - BANK - 16.0))
		if p.distance_to(from) < clear:
			continue
		var ok := true
		if apart > 0.0:
			for th: Dictionary in things:
				if int(KINDS[th.kind].tier) >= 2 and p.distance_to(th.pos) < apart + float(KINDS[th.kind].r):
					ok = false
					break
		if ok:
			break
	return p

func count(tier: int) -> int:
	var n := 0
	for th: Dictionary in things:
		if int(KINDS[th.kind].tier) == tier:
			n += 1
	return n

## New things come onto the water as the pond thins: out of sight where the
## pond is bigger than what is looked at, else floating in from the banks.
func _restock() -> void:
	if not stocks:
		return
	_let = minf(_let + LET_IN * DT, 3.0)
	if _let < 1.0:
		return
	var have := [0, 0, 0, 0, 0]
	for th: Dictionary in things:
		have[int(KINDS[th.kind].tier)] += 1
	var kind := -1
	if have[4] < int(HUGE * room()):
		kind = Kind.RAFT if rng.randf() < 0.55 else Kind.ROWBOAT
	elif have[3] < int(GREAT * room()):
		kind = [Kind.BUCKET, Kind.CAN, Kind.LILO][rng.randi() % 3]
	elif have[2] < int((BIG + BIG_STEP * (level - 1)) * room()):
		kind = _big_kind()
	elif have[1] < int((SMALL + SMALL_STEP * (level - 1)) * room()):
		kind = _small_kind()
	if kind < 0:
		# a full pond is looked at again in a while, not sixty times a second
		_let = 0.0
		return
	_let -= 1.0
	var sight := view_of(core())
	if w > sight * 1.5:
		for attempt in 12:
			var p := Vector2(rng.randf_range(BANK + 16.0, w - BANK - 16.0), rng.randf_range(BANK + 16.0, h - BANK - 16.0))
			if p.distance_to(pos) >= sight:
				put(kind, p)
				return
	# from the bank furthest from the whirlpool as often as not
	var at := Vector2.ZERO
	var best := -1.0
	for attempt in 3:
		var side := rng.randi() % 4
		var along := rng.randf()
		var y0 := BANK
		var y1 := h - BANK
		var p := Vector2(BANK, lerpf(y0, y1, along))
		match side:
			1: p = Vector2(w - BANK, lerpf(y0, y1, along))
			2: p = Vector2(lerpf(BANK, w - BANK, along), y0)
			3: p = Vector2(lerpf(BANK, w - BANK, along), y1)
		if p.distance_to(pos) > best:
			best = p.distance_to(pos)
			at = p
	var aim := Vector2(rng.randf_range(w * 0.2, w * 0.8), h * rng.randf_range(0.2, 0.8))
	var th := put(kind, at)
	th.drift = (aim - at).normalized() * PUSH
	th.fresh = FRESH
