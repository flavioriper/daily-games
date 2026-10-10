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
## two -- and nothing is ever moved by rule. So a whirlpool hurried past a
## leaf has not the time to take it (the leaf is tugged and left turning),
## a small one cannot grip a thing wider than itself (`grip`), and a thing
## goes down only once it is in the core, moving with the water, and no
## wider than the mouth.
##
## The pond is W wide and `h` tall, y down. Lengths are pond units, speeds
## units a second.

enum Phase { READY, PLAY, DRAIN, OVER }
enum Kind { LEAF, PETAL, ACORN, DUCK, BOAT, BALL }

const DT := 1.0 / 60.0
const W := 300.0
## The whirlpool's fastest travel and how quickly it answers the pad.
const SPEED := 150.0
const ANSWER := 0.16
## It grows through these levels.
const LEVELS := 10
## The core's radius at level 1 and what a level adds.
const CORE := 7.0
const CORE_STEP := 2.6
## The water's speed round the core's edge at level 1, and a level's more.
const TURN := 60.0
const TURN_STEP := 10.0
## How much of the turning also runs inward, and how many cores out the
## whirlpool is felt at all.
const INFLOW := 0.45
const REACH := 4.5
## A thing is gripped whole when the core is this many times its own
## radius; under that the grip falls off as the cube.
const GRIP := 1.4
## A thing in the core goes down when it moves with the water to within
## this.
const SLIP := 25.0
## What is swallowed to leave level 1, and how much more each level asks.
const GROW := 6
const GROW_STEP := 10
## The spin: seconds of turning in a run, and what a level gives back.
const SPIN := 40.0
const SPIN_BACK := 6.0
## Under this part of the spin the run says so, once.
const LOW := 0.25
## The whirlpool unwinding at the end.
const DRAIN_T := 1.4
## Long spin and Head start (arcade/boosters.gd).
const LONG_BY := 15.0
const HEAD_LEVELS := 2
## A Second chance gives this part of the spin back.
const REVIVE := 0.5
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
]
## How many of each tier the pond keeps afloat, and the most let in a second.
const SMALL := 34
const SMALL_STEP := 2
const BIG := 4
const BIG_STEP := 0.6
const LET_IN := 2.5
## A thing's own slow wander, and the push that brings a new one in from the
## bank for its first seconds.
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
var h := 360.0
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
## Things swallowed, of each tier.
var taken := [0, 0, 0]
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

func _init(seed_value := -1, tall := 360.0) -> void:
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	h = tall
	pos = Vector2(W * 0.5, h * 0.5)
	_stock_first()
	events.append({"type": "ready"})

func is_over() -> bool:
	return phase == Phase.OVER

static func core_of(lv: int) -> float:
	return CORE + CORE_STEP * (lv - 1)

static func turn_of(lv: int) -> float:
	return TURN + TURN_STEP * (lv - 1)

## What a whirlpool of level `lv` must swallow to grow.
static func need_of(lv: int) -> int:
	return GROW + GROW_STEP * (lv - 1)

## The first level whose mouth takes `kind`.
static func level_for(kind: int) -> int:
	for lv in range(1, LEVELS + 1):
		if grip_of(kind, lv) >= 1.0:
			return lv
	return LEVELS

## How much of the water's pull a thing of `kind` feels at level `lv`, 0 to 1.
static func grip_of(kind: int, lv: int) -> float:
	var k := clampf(core_of(lv) / (float(KINDS[kind].r) * GRIP), 0.0, 1.0)
	return k * k * k

func core() -> float:
	return core_of(level)

func reach() -> float:
	return core() * REACH

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
	var far := reach()
	if r >= far or r < 0.001:
		return Vector2.ZERO
	var rc := core()
	var vt := turn_of(level) * (r / rc if r < rc else rc / r) * strength()
	var n := d / r
	var fade := 1.0 - smoothstep(far * 0.55, far, r)
	return (Vector2(-n.y, n.x) * vt - n * vt * INFLOW) * fade

## How much of the whirlpool's travel the water at `r` from its middle
## shares: all of it in the core, none two cores out.
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
	vel = vel.lerp(lean * SPEED, 1.0 - exp(-DT / ANSWER))
	pos += vel * DT
	var lo := Vector2(BANK, BANK)
	var hi := Vector2(W - BANK, h - BANK)
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
	if live and r < rc * REACH:
		g = grip_of(th.kind, level)
		var round := swirl(p)
		water += (round + vel * carry(r)) * g
		# what floats is pressed toward the middle as the water round it is
		# (the water's own turning, which a thing afloat shares), or drag
		# alone would fling it out like a stone on a string
		# -- and only as far as it already goes the whirlpool's way: one
		# hurried past presses on nothing.
		if r > 0.001:
			var with := 1.0 - smoothstep(0.3, 0.7, (v - vel).length() / maxf(SPEED, turn_of(level) * 1.5))
			v -= (p - pos) / r * (round.length_squared() / maxf(r, rc * 0.25)) * g * with * DT
	v += (water - v) * (1.0 - exp(-DT / float(kind.tau)))
	p += v * DT
	# the bank turns a thing back
	var lo := BANK + float(kind.r)
	if p.x < lo or p.x > W - lo:
		p.x = clampf(p.x, lo, W - lo)
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
		want = turn_of(level) * (1.0 / rc if r < rc else rc / (r * r)) * g * strength() * (1.0 - smoothstep(rc * REACH * 0.55, rc * REACH, r))
	th.turn = lerpf(float(th.turn), want, minf(1.0, DT * 3.0))
	th.ang = float(th.ang) + (float(th.turn) + float(th.idle)) * DT
	if not live or r > rc * 0.8:
		return
	if g < 1.0:
		# sat on a mouth too small for it
		if t - _big_said > 4.0 and phase == Phase.PLAY:
			_big_said = t
			events.append({"type": "too_big", "kind": th.kind, "at": p, "level": level_for(th.kind)})
		return
	if phase != Phase.PLAY:
		return
	if (v - vel - swirl(p)).length() <= SLIP:
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
	events.append({"type": "swallow", "kind": th.kind, "tier": kind.tier, "value": kind.value, "at": pos})
	if level >= LEVELS:
		return
	grown += int(kind.mass)
	while level < LEVELS and grown >= need():
		grown -= need()
		level += 1
		spin = minf(spin_full, spin + SPIN_BACK)
		_low_said = spin <= spin_full * LOW
		events.append({"type": "level", "n": level, "opens": _opened(level)})
	if level >= LEVELS:
		grown = 0

## The kinds whose first level is `lv`.
static func _opened(lv: int) -> Array:
	var out := []
	for kind in KINDS.size():
		if lv > 1 and level_for(kind) == lv:
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

## A big thing: ducks mostly, the larger toys once the whirlpool has grown
## some.
func _big_kind() -> int:
	var roll := rng.randf()
	if level >= 4 and roll < 0.22:
		return Kind.BALL
	if level >= 3 and roll < 0.5:
		return Kind.BOAT
	return Kind.DUCK

func _stock_first() -> void:
	var mid := pos
	for i in SMALL:
		put(_small_kind(), _free_place(mid, 36.0, 0.0))
	for kind: int in [Kind.DUCK, Kind.DUCK, Kind.DUCK, Kind.BOAT]:
		var th := put(kind, _free_place(mid, 80.0, 30.0))
		th.age = 10.0
	for th: Dictionary in things:
		th.age = 10.0

## A place on the water at least `clear` from `from` and `apart` from every
## big thing.
func _free_place(from: Vector2, clear: float, apart: float) -> Vector2:
	var p := Vector2.ZERO
	for attempt in 30:
		p = Vector2(rng.randf_range(BANK + 16.0, W - BANK - 16.0), rng.randf_range(BANK + 16.0, h - BANK - 16.0))
		if p.distance_to(from) < clear:
			continue
		var ok := true
		if apart > 0.0:
			for th: Dictionary in things:
				if int(KINDS[th.kind].tier) == 2 and p.distance_to(th.pos) < apart:
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

## New things float in from the banks as the pond thins.
func _restock() -> void:
	if not stocks:
		return
	_let = minf(_let + LET_IN * DT, 3.0)
	if _let < 1.0:
		return
	var kind := -1
	if count(2) < int(BIG + BIG_STEP * (level - 1)):
		kind = _big_kind()
	elif count(1) < SMALL + SMALL_STEP * (level - 1):
		kind = _small_kind()
	if kind < 0:
		return
	_let -= 1.0
	# from the bank furthest from the whirlpool as often as not
	var at := Vector2.ZERO
	var best := -1.0
	for attempt in 3:
		var side := rng.randi() % 4
		var along := rng.randf()
		var p := Vector2(BANK, lerpf(BANK, h - BANK, along))
		match side:
			1: p = Vector2(W - BANK, lerpf(BANK, h - BANK, along))
			2: p = Vector2(lerpf(BANK, W - BANK, along), BANK)
			3: p = Vector2(lerpf(BANK, W - BANK, along), h - BANK)
		if p.distance_to(pos) > best:
			best = p.distance_to(pos)
			at = p
	var aim := Vector2(rng.randf_range(W * 0.2, W * 0.8), rng.randf_range(h * 0.2, h * 0.8))
	var th := put(kind, at)
	th.drift = (aim - at).normalized() * PUSH
	th.fresh = FRESH

# --- boosters (arcade/boosters.gd) ---

func long_spin() -> void:
	spin_full += LONG_BY
	spin = spin_full

func head_start() -> void:
	level = mini(LEVELS, level + HEAD_LEVELS)

## The Second chance: the whirlpool winds up again where it stopped.
func revive() -> void:
	phase = Phase.READY
	phase_t = 0.0
	spin = spin_full * REVIVE
	_low_said = false
	lean = Vector2.ZERO
	vel = Vector2.ZERO
	events.append({"type": "revive"})
