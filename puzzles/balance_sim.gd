extends RefCounted

## The seesaw's physics, as data stepped at a fixed DT on the board's clock:
## the beam as one rotational degree of freedom on a pendulum pivot, and each
## fruit as a body that is held, flying, rolling on the plank, bouncing on
## the grass or sitting in the basket. Marigold's rule: owning the physics
## rather than handing it to Godot's server keeps it deterministic, steppable
## headless by a harness, stoppable at once under reduce motion, and unable to
## wedge a fruit where the rules cannot see it.
##
## Lengths are the board's pixels; `s` along the plank is in cups (cup x sits
## at s = x). The board sets the layout (`pivot`, `cup`, `r`, `ground`,
## `slots`) on every relayout and reads positions back to draw. The rules
## never ask this anything: whether the beam is level is the state's
## integer question. This only makes the answer visible.
## Spec: docs/superpowers/specs/2026-09-27-balance-seesaw-design.md, section 3.

const DT := 1.0 / 120.0
## A frame never runs more than this much physics, so a stall does not come
## back as a burst.
const MAX_STEPS := 12

enum { BASKET, HELD, AIR, PLANK, GROUND, ARC }

# --- the beam ---
## One unit of torque leans the beam by atan(1 / K): a pendulum balance rests
## at tan(angle) = torque / K. TICK is that angle, the spirit level's tick.
const TICK := 0.03
const K := 1.0 / TICK
## Where the ends meet the hay bales: a reading of 5.5 units.
const A_MAX := 0.1635
## The empty beam's own swing, a little under one a second, and how fast it
## dies; a laden beam is heavier to swing (`LOAD_I`).
const OMEGA := 5.4
const ZETA := 0.4
const LOAD_I := 0.004
const STOP_BOUNCE := 0.3
## A landing fruit's kick to the beam, per unit of weight, cup and px/s.
const KICK := 0.00002

# --- the fruit ---
## Gravity, in cups per second squared (scaled by the cup's pixels).
const G := 24.0
## The pull of the cup a fruit is making for, strong enough to hold it
## against the steepest tilt, and the rolling friction under it.
const WELL := 30.0
const WELL_REACH := 0.7
const ROLL_DRAG := 5.0
## The cup's own hollow: a stiff, well-damped core a fifth of a cup wide, so
## a seated fruit sits in the middle of its cup however far the beam leans.
const CORE := 420.0
const CORE_DRAG := 22.0
const CORE_W := 0.12
const BOUNCE := 0.34
const GROUND_BOUNCE := 0.42
const GROUND_SLIDE := 0.7
## How fast a flying fruit may leave the finger, in cups a second.
const THROW_MAX := 6.0
const THROW_KEEP := 0.6
## A held fruit's speed fades while the finger is still.
const HOLD_FADE := 14.0
## A rolling fruit's face rolls with it; a seated one rights itself.
const WEEBLE_K := 60.0
const WEEBLE_C := 9.0
const GRIP := 30.0
## Seated: near its cup, slow, down.
const SEAT_S := 0.03
const SEAT_V := 0.08
## The beam at rest.
const REST_A := 0.0006
const REST_V := 0.01
## A home-going hop's time and height.
const ARC_TIME := 0.5
const ARC_HIGH := 1.4

# --- layout, set by the board ---
var pivot := Vector2.ZERO
var cup := 100.0          # px between cups
var r := 40.0             # a fruit's radius in px
var top := 10.0           # plank's top above its centre line, px
var half := 400.0         # plank's half length, px
var ground := 900.0       # the grass line, px
var left_wall := 0.0
var right_wall := 1000.0
var slots: Array[Vector2] = []   # the basket seat per fruit

# --- state ---
var a := 0.0
var av := 0.0
var bodies: Array[Dictionary] = []
var weights: Array[int] = []
var events: Array = []
var t := 0.0
var _acc := 0.0
var _was_rest := true

## One body per fruit: `w` its weight, `mode`, and per mode its numbers.
func setup(fruit_weights: Array) -> void:
	weights.assign(fruit_weights)
	bodies = []
	for f in weights.size():
		bodies.append({"mode": BASKET, "pos": Vector2.ZERO, "vel": Vector2.ZERO, "s": 0.0, "sv": 0.0,
			"h": 0.0, "hv": 0.0, "spin": 0.0, "spv": 0.0, "cup": 0, "bounces": 0, "seated": false,
			"arc": {}, "landed": false})
	a = 0.0
	av = 0.0
	events = []

# --- placing things ---

func to_basket_now(f: int) -> void:
	var b := bodies[f]
	b.mode = BASKET
	b.pos = slots[f] if f < slots.size() else Vector2.ZERO
	b.spin = 0.0
	b.spv = 0.0

func to_cup_now(f: int, x: int) -> void:
	var b := bodies[f]
	b.mode = PLANK
	b.cup = x
	b.s = float(x)
	b.sv = 0.0
	b.h = 0.0
	b.hv = 0.0
	b.spin = 0.0
	b.spv = 0.0
	b.seated = true
	b.landed = true

func hold(f: int, at: Vector2) -> void:
	var b := bodies[f]
	b.mode = HELD
	b.pos = at
	b.vel = Vector2.ZERO
	b.seated = false

func drag_to(f: int, at: Vector2, delta: float) -> void:
	var b := bodies[f]
	var was: Vector2 = b.pos
	b.pos = at
	var v := (at - was) / maxf(delta, 1e-3)
	b.vel = Vector2(b.vel).lerp(v, 0.5)

## Lets a held fruit go. `x` is the cup it is making for (0: none -- it will
## miss the plank and come home), and it flies from where it is with the
## finger's velocity, trimmed.
func release(f: int, x: int) -> void:
	var b := bodies[f]
	b.mode = AIR
	b.cup = x
	b.bounces = 0
	b.landed = false
	# a fling keeps most of its sideways speed; an upward one is mostly the
	# finger lifting the fruit out of the basket, not a throw
	var v: Vector2 = Vector2(b.vel) * THROW_KEEP
	if v.y < 0.0:
		v.y *= 0.35
	b.vel = v.limit_length(THROW_MAX * cup)

## A scripted hop from wherever the fruit is to cup `x` (0: the basket),
## `delay` seconds from now. Undo, reset and a hint travel this way; a
## springy bale's bounce (Insane) goes `high` times higher, `flips` whole
## turns head over heels, and takes `long` times as long.
func hop(f: int, x: int, delay := 0.0, high := 1.0, flips := 0.0, long := 1.0) -> void:
	var b := bodies[f]
	var from := position(f)
	b.mode = ARC
	b.cup = x
	b.seated = false
	b.landed = false
	b.arc = {"from": from, "spin": wrapf(float(b.spin), -PI, PI) + TAU * flips, "at": t + delay, "dur": ARC_TIME * long,
		"high": ARC_HIGH * cup * (0.7 if x == 0 else 1.0) * high}

# --- reading ---

func plank_point(s: float, lift: float) -> Vector2:
	var d := Vector2(cos(a), sin(a))
	var n := Vector2(sin(a), -cos(a))
	return pivot + d * s * cup + n * lift

## Where fruit `f`'s centre is drawn.
func position(f: int) -> Vector2:
	var b := bodies[f]
	match int(b.mode):
		PLANK:
			return plank_point(float(b.s), top + r - _dip(float(b.s)) + float(b.h))
		_:
			return b.pos

## How the fruit is turned: its roll, plus the plank's lean on the plank.
func angle(f: int) -> float:
	var b := bodies[f]
	return float(b.spin) + (a * 0.6 if int(b.mode) == PLANK else 0.0)

## The torque the beam feels now, in units, from everything touching it.
func live_torque() -> float:
	var tq := 0.0
	for f in bodies.size():
		var b := bodies[f]
		if int(b.mode) == PLANK:
			tq += weights[f] * float(b.s)
	return tq

## What the spirit level shows: the torque the angle stands for.
func reading() -> float:
	return tan(a) * K

func beam_at_rest() -> bool:
	return absf(av) < REST_V and absf(tan(a) * K - live_torque()) < 0.15 or (absf(a) >= A_MAX - 1e-4 and absf(av) < REST_V)

## Nothing is moving: every fruit is home or seated and the beam has stopped.
func calm() -> bool:
	for b in bodies:
		var m := int(b.mode)
		if m == HELD or m == AIR or m == GROUND or m == ARC:
			return false
		if m == PLANK and not bool(b.seated):
			return false
	return beam_at_rest()

## Everything straight to rest: every flight lands where it was going and
## the beam stands where its load puts it. Reduce motion, a restore, a
## harness.
func snap() -> void:
	for f in bodies.size():
		var b := bodies[f]
		match int(b.mode):
			HELD:
				pass
			AIR, ARC, GROUND:
				if int(b.cup) != 0:
					to_cup_now(f, int(b.cup))
				else:
					to_basket_now(f)
			PLANK:
				to_cup_now(f, int(b.cup))
			BASKET:
				to_basket_now(f)
	a = clampf(atan(live_torque() / K), -A_MAX, A_MAX)
	av = 0.0
	_was_rest = true

# --- stepping ---

func advance(delta: float) -> void:
	_acc = minf(_acc + delta, DT * MAX_STEPS)
	while _acc >= DT:
		_acc -= DT
		_step(DT)

func _step(dt: float) -> void:
	t += dt
	var g := G * cup
	for f in bodies.size():
		var b := bodies[f]
		match int(b.mode):
			HELD: b.vel = Vector2(b.vel) * exp(-HOLD_FADE * dt)
			AIR: _fly(f, b, dt, g)
			PLANK: _roll(f, b, dt, g)
			GROUND: _bounce(f, b, dt, g)
			ARC: _arc(f, b)
	_swing(dt)

func _swing(dt: float) -> void:
	var load_i := 1.0
	for f in bodies.size():
		var b := bodies[f]
		if int(b.mode) == PLANK:
			load_i += LOAD_I * weights[f] * float(b.s) * float(b.s)
	var w := OMEGA / sqrt(load_i)
	var acc := w * w * (live_torque() * cos(a) / K - sin(a)) - 2.0 * ZETA * w * av
	# already lying on a bale: a heavy load presses it there, and one step's
	# push is not a knock (with the pinned load of an Insane day, ~100 units,
	# it was -- every step thudded and jolted the fruit up off the plank)
	var lying := absf(a) >= A_MAX - 1e-6
	av += acc * dt
	a += av * dt
	if absf(a) > A_MAX:
		var hit := 0.0 if lying else absf(av)
		a = signf(a) * A_MAX
		if av * signf(a) > 0.0:
			# a real knock bounces; anything less is the plank lying on the bale
			av = -av * STOP_BOUNCE if hit > 0.12 else 0.0
			if hit > 0.12:
				events.append({"e": "thud", "speed": hit, "side": signf(a)})
				for b in bodies:
					if int(b.mode) == PLANK:
						b.hv = maxf(float(b.hv), hit * cup * 4.0)
	var rest := beam_at_rest()
	if rest and not _was_rest:
		events.append({"e": "rest"})
	_was_rest = rest

## Height of the plank's cup profile under `s`: a dip at every cup, a crown
## between them, so nothing rests anywhere but in a cup.
func _dip(s: float) -> float:
	var u := s - roundf(s)
	return r * 0.18 * (0.5 + 0.5 * cos(u * TAU))

func _fly(f: int, b: Dictionary, dt: float, g: float) -> void:
	var v: Vector2 = b.vel
	v.y += g * dt
	var p: Vector2 = Vector2(b.pos) + v * dt
	# walls
	if p.x < left_wall + r:
		p.x = left_wall + r
		v.x = absf(v.x) * 0.5
	elif p.x > right_wall - r:
		p.x = right_wall - r
		v.x = -absf(v.x) * 0.5
	b.pos = p
	b.vel = v
	b.spin = float(b.spin) + v.x / r * dt * 0.5
	# the plank, seen from its own frame
	var local := (p - pivot).rotated(-a)
	var s := local.x / cup
	var surface := -(top + r - _dip(s))
	if absf(local.x) <= half and local.y >= surface and local.y < surface + r * 1.5:
		var lv := v.rotated(-a)
		if int(b.cup) == 0:
			# not meant for the plank: glance off it and fall on past its end
			lv = Vector2(lv.x + signf(local.x + 0.01) * 3.0 * cup, -absf(lv.y) * 0.4)
			b.vel = lv.rotated(a)
			b.pos = pivot + Vector2(local.x, surface).rotated(a)
			return
		b.mode = PLANK
		b.s = s
		b.sv = lv.x / cup * 0.5
		b.h = 0.0
		b.hv = maxf(0.0, lv.y * BOUNCE)
		b.seated = false
		av += KICK * weights[f] * s * lv.y
		events.append({"e": "land", "f": f, "speed": lv.y})
		return
	if p.y >= ground - r:
		b.pos = Vector2(p.x, ground - r)
		b.mode = GROUND
		b.vel = Vector2(v.x * GROUND_SLIDE, -absf(v.y) * GROUND_BOUNCE)
		b.bounces = 1
		events.append({"e": "grass", "f": f, "speed": v.y})

func _bounce(f: int, b: Dictionary, dt: float, g: float) -> void:
	var v: Vector2 = b.vel
	v.y += g * dt
	var p: Vector2 = Vector2(b.pos) + v * dt
	if p.x < left_wall + r or p.x > right_wall - r:
		v.x = -v.x * 0.5
		p.x = clampf(p.x, left_wall + r, right_wall - r)
	b.spin = float(b.spin) + v.x / r * dt
	if p.y >= ground - r:
		p.y = ground - r
		b.bounces = int(b.bounces) + 1
		v = Vector2(v.x * GROUND_SLIDE, -absf(v.y) * GROUND_BOUNCE)
		if absf(v.y) < 0.9 * cup or int(b.bounces) > 3:
			b.pos = p
			b.vel = Vector2.ZERO
			hop(f, 0, 0.05)
			return
	b.pos = p
	b.vel = v

func _roll(f: int, b: Dictionary, dt: float, g: float) -> void:
	var s: float = b.s
	var sv: float = b.sv
	var x: float = float(b.cup)
	var off := clampf(s - x, -WELL_REACH, WELL_REACH)
	var core := exp(-(off * off) / (CORE_W * CORE_W))
	var acc := g / cup * sin(a) - (WELL + CORE * core) * off - (ROLL_DRAG + CORE_DRAG * core) * sv
	# the pull toward its cup outweighs the slope; the drag is what settles it
	sv += acc * dt
	s += sv * dt
	# over another fruit: ride up on it
	var floor_h := 0.0
	for o in bodies.size():
		if o == f:
			continue
		var ob := bodies[o]
		if int(ob.mode) != PLANK:
			continue
		var d := absf(float(ob.s) - s) * cup
		if d < 2.0 * r:
			floor_h = maxf(floor_h, sqrt(4.0 * r * r - d * d))
	var h: float = b.h
	var hv: float = b.hv
	hv -= g * cos(a) * dt
	h += hv * dt
	if h <= floor_h:
		if hv < -1.2 * cup:
			events.append({"e": "bump", "f": f, "speed": -hv})
		h = floor_h
		hv = -hv * BOUNCE if hv < -0.8 * cup else 0.0
		b.landed = true
	b.s = s
	b.sv = sv
	b.h = h
	b.hv = hv
	# the face: rolls with the fruit while it rolls, rights itself as it stops
	var roll_rate := sv * cup / r
	var spv: float = b.spv
	var touching := h - floor_h < 1.0
	if touching:
		spv += (roll_rate - spv) * minf(1.0, GRIP * dt)
	spv += (-WEEBLE_K * wrapf(float(b.spin), -PI, PI) - WEEBLE_C * spv) * dt * (0.25 if absf(sv) > 0.6 else 1.0)
	b.spv = spv
	b.spin = float(b.spin) + spv * dt
	var seated := absf(s - x) < SEAT_S and absf(sv) < SEAT_V and h - floor_h < 0.5 and absf(hv) < 0.5 * cup
	if seated and not bool(b.seated):
		events.append({"e": "seat", "f": f})
	b.seated = seated

func _arc(f: int, b: Dictionary) -> void:
	var arc: Dictionary = b.arc
	var u := (t - float(arc.at)) / float(arc.dur)
	if u < 0.0:
		return
	u = minf(u, 1.0)
	var x: int = b.cup
	var to: Vector2 = plank_point(float(x), top + r - _dip(float(x))) if x != 0 else slots[f]
	var e := u * u * (3.0 - 2.0 * u)
	var from: Vector2 = arc.from
	b.pos = from.lerp(to, e) + Vector2(0.0, -float(arc.high) * 4.0 * u * (1.0 - u))
	b.spin = float(arc.spin) * (1.0 - e)
	if u >= 1.0:
		if x != 0:
			b.mode = PLANK
			b.s = float(x)
			b.sv = 0.0
			b.h = 0.0
			b.hv = 0.0
			b.seated = false
			b.landed = true
			av += KICK * weights[f] * float(x) * cup * 3.0
			events.append({"e": "land", "f": f, "speed": cup * 3.0})
		else:
			to_basket_now(f)
			events.append({"e": "home", "f": f})
