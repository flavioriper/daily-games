extends RefCounted

## Air hockey as pure data: one puck, two mallets and the score, in metres
## and seconds, stepped at a fixed DT. The table stands on end the way the
## screen shows it: x across, y down, player 0's goal on the bottom rail
## (y = L) and player 1's on the top one (y = 0). Nothing here knows about
## pixels, fingers or sound; a step leaves what happened in `events` for the
## screen to play.
##
## A mallet is not pushed, it is led: `aim[p]` is where its player wants it
## and each step it goes there as fast as MALLET_MAX allows, kept inside its
## own half. Its speed over the last SWING of a second is what the puck is
## struck with, so a hand that whips through the puck sends it and one that
## only stands there blocks it. The mallet has no mass to lose: the puck leaves with the
## mallet's speed added to its own bounce.
##
## The steps are short enough that nothing tunnels: at full speed the puck
## and a mallet close 0.06 m a step against 0.12 m of radii.
##
## tests/_probe_hockey.gd plays whole matches, computer against computer; run
## it after touching anything here.
##
## **The power table** (`powers`, the screen's matches; the tutorial and the
## tab's card keep the plain game): every PICK_EVERY seconds a token lies on
## one of four SPOTS, and the puck run through it gives it to whoever struck
## the puck last. TWIN puts a second puck in play (`twin`, stepped by the same
## code with the two swapped), BIG widens your mallet, WIDE opens the other
## goal, SLOW mires the other mallet, GOLD makes the next goal worth two to
## whoever scores it. A goal with a puck still on the table does not stop play.

const DT := 1.0 / 240.0
const W := 1.0
const L := 1.6
const PUCK_R := 0.042
const MALLET_R := 0.078
## Half the goal's mouth, along the rail.
const GOAL_HALF := 0.18
## How far past the rail the puck's middle is when the goal counts.
const GOAL_DEPTH := 0.03
## The cushion of air: what the puck loses a second, as a rate.
const DRAG := 0.22
## Bounce kept off a rail and off a mallet.
const WALL_E := 0.9
const MALLET_E := 0.72
const PUCK_MAX := 4.6
const MALLET_MAX := 7.5
## How many steps a mallet's speed is measured over: a thirtieth of a second.
## A finger's place is read once a frame, so the mallet crosses a whole
## frame's worth of the hand in its first step and stands still for the rest;
## its speed over one step was the hand's four times over at 60 Hz, and a
## nudge sent the puck off at PUCK_MAX. Over two frames it is the hand's own.
const SWING := 8
## The air never lets a puck sit against a rail: one going slower than
## DRIFT_UNDER within EDGE of a rail is eased back toward the table at DRIFT
## (m/s2). A mallet is wider than the puck and kept off the rails by its own
## radius, so a puck at rest in a corner could only ever be pushed further in
## -- by a finger or by the computer -- and the match would stop there.
const EDGE := 0.125
const DRIFT := 0.5
const DRIFT_UNDER := 0.3
## First to this many.
const TARGET := 7

## The power table's tokens, 0 none.
enum { NONE, TWIN, BIG, WIDE, SLOW, GOLD }
const POWERS := [TWIN, BIG, WIDE, SLOW, GOLD]
const PICK_R := 0.085
## Seconds of play to the first token and between tokens, and how long one lies.
const PICK_FIRST := 4.0
const PICK_EVERY := 6.0
const PICK_LIFE := 9.0
const SPOTS := [Vector2(0.27, 0.6), Vector2(0.73, 0.6), Vector2(0.27, 1.0), Vector2(0.73, 1.0)]
## How long each lasts, how much wider the mallet and the goal grow, and how
## fast a mired arm can go.
const BIG_TIME := 8.0
const BIG_K := 1.5
const WIDE_TIME := 7.0
const WIDE_K := 1.55
const SLOW_TIME := 4.5
const SLOW_MAX := 1.3
## The second puck leaves the token toward the other half at this speed.
const TWIN_SPEED := 1.7
## Where a mallet waits and where the puck is served from, measured from its
## player's own rail.
const HOME := 0.26
const SERVE := 0.52

var puck := Vector2(W * 0.5, L * 0.5)
var puck_vel := Vector2.ZERO
## False between a goal and the serve: the puck is off the table.
var puck_on := true
var mallet: Array[Vector2] = [home(0), home(1)]
var mallet_vel: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]
var aim: Array[Vector2] = [home(0), home(1)]
## Each mallet's last SWING moves, a ring, and their sum.
var _moves: Array = [[], []]
var _moved: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]
var _move_at := 0
var scores := [0, 0]
var over := false
var winner := -1
## Who touched the puck last, -1 nobody since the serve.
var last_touch := -1
## What the last steps did, oldest first; the screen plays and clears them.
## {kind: "mallet", who, speed, at} / {kind: "wall", speed, at} /
## {kind: "post", speed, at} / {kind: "goal", by, at}.
var events: Array[Dictionary] = []
## Seconds played with the puck on the table.
var clock := 0.0
## Rails the puck has met since a mallet last struck it.
var banks := 0
## Blows that crossed the table without a goal, since the serve.
var rally := 0

## Tokens lie on the table (see the header).
var powers := false
var rng := RandomNumberGenerator.new()
var pick_kind := NONE
var pick_at := Vector2.ZERO
var pick_t := 0.0
var _pick_due := PICK_FIRST
var _pick_last := NONE
## A mallet's radius, seconds of BIG and of SLOW left, by seat.
var radius: Array[float] = [MALLET_R, MALLET_R]
var big_t := [0.0, 0.0]
var slow_t := [0.0, 0.0]
## Seconds a goal stands open, by the seat that defends it.
var wide_t := [0.0, 0.0]
## The next goal is worth two.
var gold := false
## The second puck.
var twin_on := false
var twin := Vector2.ZERO
var twin_vel := Vector2.ZERO
var _twin_touch := -1
var _twin_banks := 0

static func home(p: int) -> Vector2:
	return Vector2(W * 0.5, L - HOME if p == 0 else HOME)

## The middle of the goal player `p` defends.
static func goal_of(p: int) -> Vector2:
	return Vector2(W * 0.5, L if p == 0 else 0.0)

## A point kept where player `p`'s mallet may be: its own half, clear of the
## rails and of the middle line.
static func clamp_half(p: int, at: Vector2, r := MALLET_R) -> Vector2:
	var x := clampf(at.x, r, W - r)
	if p == 0:
		return Vector2(x, clampf(at.y, L * 0.5 + r, L - r))
	return Vector2(x, clampf(at.y, r, L * 0.5 - r))

## Half the mouth of the goal `p` defends.
func goal_half(p: int) -> float:
	return GOAL_HALF * (WIDE_K if wide_t[p] > 0.0 else 1.0)

## What `me` should mind most, the puck or the twin: [where, how fast, on].
func threat(me: int) -> Array:
	if not twin_on or not puck_on:
		return [twin, twin_vel, true] if twin_on else [puck, puck_vel, puck_on]
	var goal := goal_of(me)
	var home_way := -1.0 if me == 1 else 1.0
	var first := (puck.y - goal.y) * -home_way + (0.0 if puck_vel.y * home_way > 0.1 else 1.0)
	var second := (twin.y - goal.y) * -home_way + (0.0 if twin_vel.y * home_way > 0.1 else 1.0)
	return [twin, twin_vel, true] if second < first else [puck, puck_vel, true]

## Which half the puck is in: 0 the bottom, 1 the top.
func side() -> int:
	return 0 if puck.y >= L * 0.5 else 1

## The puck at rest in `to`'s half, for that player to play.
func serve(to: int) -> void:
	puck = Vector2(W * 0.5, L - SERVE if to == 0 else SERVE)
	puck_vel = Vector2.ZERO
	puck_on = true
	last_touch = -1
	twin_on = false
	banks = 0
	rally = 0

## A fresh match with the score kept or not.
func reset(first := 0) -> void:
	scores = [0, 0]
	over = false
	winner = -1
	clock = 0.0
	events.clear()
	pick_kind = NONE
	_pick_due = PICK_FIRST
	_pick_last = NONE
	gold = false
	for p in 2:
		radius[p] = MALLET_R
		big_t[p] = 0.0
		slow_t[p] = 0.0
		wide_t[p] = 0.0
		mallet[p] = home(p)
		aim[p] = home(p)
		mallet_vel[p] = Vector2.ZERO
		_moves[p].clear()
		_moved[p] = Vector2.ZERO
	serve(first)

func step(dt: float = DT) -> void:
	for p in 2:
		var want := clamp_half(p, aim[p], radius[p])
		var to := want - mallet[p]
		var reach := (SLOW_MAX if slow_t[p] > 0.0 else MALLET_MAX) * dt
		if to.length() > reach:
			to = to.normalized() * reach
		mallet[p] += to
		var ring: Array = _moves[p]
		if ring.size() < SWING:
			ring.resize(SWING)
			ring.fill(Vector2.ZERO)
		_moved[p] += to - ring[_move_at]
		ring[_move_at] = to
		mallet_vel[p] = _moved[p] / (SWING * dt)
	_move_at = (_move_at + 1) % SWING
	if (not puck_on and not twin_on) or over:
		return
	clock += dt
	_tick_powers(dt)
	if puck_on:
		_step_puck(dt)
	if twin_on and not over:
		_swap()
		_step_puck(dt)
		_swap()
	if over:
		return
	if puck_on and twin_on:
		_pucks_meet()
	elif twin_on:
		# The first puck went in: the second is the puck now.
		_swap()

func _swap() -> void:
	var a := [puck, puck_vel, puck_on, last_touch, banks]
	puck = twin
	puck_vel = twin_vel
	puck_on = twin_on
	last_touch = _twin_touch
	banks = _twin_banks
	twin = a[0]
	twin_vel = a[1]
	twin_on = a[2]
	_twin_touch = a[3]
	_twin_banks = a[4]

func _pucks_meet() -> void:
	var gap := twin - puck
	var d := gap.length()
	if d >= PUCK_R * 2.0 or d < 0.00001:
		return
	var n := gap / d
	var push := (PUCK_R * 2.0 - d) * 0.5
	puck -= n * push
	twin += n * push
	var closing := (twin_vel - puck_vel).dot(n)
	if closing < 0.0:
		puck_vel += closing * n
		twin_vel -= closing * n
		_knock("post", -closing, puck + n * PUCK_R)

func _step_puck(dt: float) -> void:
	puck += puck_vel * dt
	puck_vel *= exp(-DRAG * dt)
	if puck_vel.length() < DRIFT_UNDER:
		var off := Vector2.ZERO
		if puck.x < EDGE:
			off.x = 1.0
		elif puck.x > W - EDGE:
			off.x = -1.0
		if puck.y < EDGE:
			off.y = 1.0
		elif puck.y > L - EDGE:
			off.y = -1.0
		if off != Vector2.ZERO:
			puck_vel += off.normalized() * DRIFT * dt
	for p in 2:
		_strike(p)
	_rails()
	if not puck_on:
		return
	# A puck squeezed between a mallet and a rail: the mallet is the one that
	# gives, or the two would trade places every step.
	for p in 2:
		var gap := puck - mallet[p]
		var need := PUCK_R + radius[p]
		if gap.length() < need - 0.0005:
			var n := gap.normalized() if gap.length() > 0.00001 else Vector2(0, -1.0 if p == 0 else 1.0)
			mallet[p] = puck - n * need
	if puck_vel.length() > PUCK_MAX:
		puck_vel = puck_vel.normalized() * PUCK_MAX
	if pick_kind != NONE and last_touch >= 0 and puck.distance_to(pick_at) < PICK_R + PUCK_R:
		_take(last_touch)

func _tick_powers(dt: float) -> void:
	for p in 2:
		big_t[p] = maxf(0.0, big_t[p] - dt)
		slow_t[p] = maxf(0.0, slow_t[p] - dt)
		wide_t[p] = maxf(0.0, wide_t[p] - dt)
		radius[p] = MALLET_R * (BIG_K if big_t[p] > 0.0 else 1.0)
	if not powers:
		return
	if pick_kind != NONE:
		pick_t -= dt
		if pick_t <= 0.0:
			pick_kind = NONE
			_pick_due = PICK_EVERY * 0.5
		return
	_pick_due -= dt
	if _pick_due > 0.0:
		return
	var kinds: Array = POWERS.filter(func(k: int) -> bool:
		return k != _pick_last and not (k == TWIN and twin_on) and not (k == GOLD and gold))
	pick_kind = kinds[rng.randi() % kinds.size()]
	_pick_last = pick_kind
	pick_t = PICK_LIFE
	# The spot furthest from the puck, of two drawn: never under it.
	var a: Vector2 = SPOTS[rng.randi() % SPOTS.size()]
	var b: Vector2 = SPOTS[rng.randi() % SPOTS.size()]
	pick_at = a if a.distance_to(puck) > b.distance_to(puck) else b

## The token goes to `who`.
func _take(who: int) -> void:
	var kind := pick_kind
	pick_kind = NONE
	_pick_due = PICK_EVERY
	var other := 1 - who
	match kind:
		TWIN:
			twin_on = true
			twin = pick_at
			twin_vel = Vector2(rng.randf_range(-0.7, 0.7), TWIN_SPEED * (-1.0 if who == 0 else 1.0))
			_twin_touch = who
			_twin_banks = 0
		BIG:
			big_t[who] = BIG_TIME
			radius[who] = MALLET_R * BIG_K
		WIDE:
			wide_t[other] = WIDE_TIME
		SLOW:
			slow_t[other] = SLOW_TIME
		GOLD:
			gold = true
	events.append({"kind": "power", "who": who, "power": kind, "at": pick_at})

func _strike(p: int) -> void:
	var gap := puck - mallet[p]
	var need := PUCK_R + radius[p]
	var d := gap.length()
	if d >= need:
		return
	var n := gap / d if d > 0.00001 else Vector2(0, -1.0 if p == 0 else 1.0)
	puck = mallet[p] + n * need
	var closing := (puck_vel - mallet_vel[p]).dot(n)
	if closing >= 0.0:
		return
	puck_vel -= (1.0 + MALLET_E) * closing * n
	if last_touch == 1 - p:
		rally += 1
	last_touch = p
	banks = 0
	events.append({"kind": "mallet", "who": p, "speed": -closing, "at": puck - n * PUCK_R, "rally": rally})

func _rails() -> void:
	# the long rails
	if puck.x < PUCK_R:
		puck.x = PUCK_R
		if puck_vel.x < 0.0:
			_knock("wall", -puck_vel.x, Vector2(0.0, puck.y))
			banks += 1
			puck_vel.x = -puck_vel.x * WALL_E
	elif puck.x > W - PUCK_R:
		puck.x = W - PUCK_R
		if puck_vel.x > 0.0:
			_knock("wall", puck_vel.x, Vector2(W, puck.y))
			banks += 1
			puck_vel.x = -puck_vel.x * WALL_E
	# the short rails, each with its mouth
	for end in 2:
		var rail := L if end == 0 else 0.0
		var out := 1.0 if end == 0 else -1.0
		var past := (puck.y - rail) * out
		if past < -PUCK_R:
			continue
		var off := absf(puck.x - W * 0.5)
		var half := goal_half(end)
		if off < half:
			# Over the mouth: through it once the middle is well past the rail.
			if past >= GOAL_DEPTH:
				_goal(1 - end)
				return
			# A post: the mouth's corner, struck as a point.
			var post := Vector2(W * 0.5 + (1.0 if puck.x >= W * 0.5 else -1.0) * half, rail)
			var gap := puck - post
			var d := gap.length()
			if d < PUCK_R and d > 0.00001:
				var n := gap / d
				puck = post + n * PUCK_R
				var v := puck_vel.dot(n)
				if v < 0.0:
					_knock("post", -v, post)
					puck_vel -= (1.0 + WALL_E) * v * n
			continue
		# The rail itself.
		puck.y = rail - out * PUCK_R
		if puck_vel.y * out > 0.0:
			_knock("wall", absf(puck_vel.y), Vector2(puck.x, rail))
			puck_vel.y = -puck_vel.y * WALL_E

func _knock(kind: String, speed: float, at: Vector2) -> void:
	events.append({"kind": kind, "speed": speed, "at": at})

func _goal(by: int) -> void:
	var worth := 2 if gold else 1
	gold = false
	scores[by] += worth
	events.append({"kind": "goal", "by": by, "at": puck, "worth": worth, "banks": banks, "speed": puck_vel.length(),
		"own": last_touch == 1 - by, "more": twin_on})
	puck_on = false
	puck_vel = Vector2.ZERO
	if scores[by] >= TARGET:
		over = true
		winner = by
		twin_on = false
