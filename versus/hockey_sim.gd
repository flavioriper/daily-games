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

static func home(p: int) -> Vector2:
	return Vector2(W * 0.5, L - HOME if p == 0 else HOME)

## The middle of the goal player `p` defends.
static func goal_of(p: int) -> Vector2:
	return Vector2(W * 0.5, L if p == 0 else 0.0)

## A point kept where player `p`'s mallet may be: its own half, clear of the
## rails and of the middle line.
static func clamp_half(p: int, at: Vector2) -> Vector2:
	var x := clampf(at.x, MALLET_R, W - MALLET_R)
	if p == 0:
		return Vector2(x, clampf(at.y, L * 0.5 + MALLET_R, L - MALLET_R))
	return Vector2(x, clampf(at.y, MALLET_R, L * 0.5 - MALLET_R))

## Which half the puck is in: 0 the bottom, 1 the top.
func side() -> int:
	return 0 if puck.y >= L * 0.5 else 1

## The puck at rest in `to`'s half, for that player to play.
func serve(to: int) -> void:
	puck = Vector2(W * 0.5, L - SERVE if to == 0 else SERVE)
	puck_vel = Vector2.ZERO
	puck_on = true
	last_touch = -1

## A fresh match with the score kept or not.
func reset(first := 0) -> void:
	scores = [0, 0]
	over = false
	winner = -1
	clock = 0.0
	events.clear()
	for p in 2:
		mallet[p] = home(p)
		aim[p] = home(p)
		mallet_vel[p] = Vector2.ZERO
		_moves[p].clear()
		_moved[p] = Vector2.ZERO
	serve(first)

func step(dt: float = DT) -> void:
	for p in 2:
		var want := clamp_half(p, aim[p])
		var to := want - mallet[p]
		var reach := MALLET_MAX * dt
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
	if not puck_on or over:
		return
	clock += dt
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
	# A puck squeezed between a mallet and a rail: the mallet is the one that
	# gives, or the two would trade places every step.
	for p in 2:
		var gap := puck - mallet[p]
		var need := PUCK_R + MALLET_R
		if gap.length() < need - 0.0005:
			var n := gap.normalized() if gap.length() > 0.00001 else Vector2(0, -1.0 if p == 0 else 1.0)
			mallet[p] = puck - n * need
	if puck_vel.length() > PUCK_MAX:
		puck_vel = puck_vel.normalized() * PUCK_MAX

func _strike(p: int) -> void:
	var gap := puck - mallet[p]
	var need := PUCK_R + MALLET_R
	var d := gap.length()
	if d >= need:
		return
	var n := gap / d if d > 0.00001 else Vector2(0, -1.0 if p == 0 else 1.0)
	puck = mallet[p] + n * need
	var closing := (puck_vel - mallet_vel[p]).dot(n)
	if closing >= 0.0:
		return
	puck_vel -= (1.0 + MALLET_E) * closing * n
	last_touch = p
	events.append({"kind": "mallet", "who": p, "speed": -closing, "at": puck - n * PUCK_R})

func _rails() -> void:
	# the long rails
	if puck.x < PUCK_R:
		puck.x = PUCK_R
		if puck_vel.x < 0.0:
			_knock("wall", -puck_vel.x, Vector2(0.0, puck.y))
			puck_vel.x = -puck_vel.x * WALL_E
	elif puck.x > W - PUCK_R:
		puck.x = W - PUCK_R
		if puck_vel.x > 0.0:
			_knock("wall", puck_vel.x, Vector2(W, puck.y))
			puck_vel.x = -puck_vel.x * WALL_E
	# the short rails, each with its mouth
	for end in 2:
		var rail := L if end == 0 else 0.0
		var out := 1.0 if end == 0 else -1.0
		var past := (puck.y - rail) * out
		if past < -PUCK_R:
			continue
		var off := absf(puck.x - W * 0.5)
		if off < GOAL_HALF:
			# Over the mouth: through it once the middle is well past the rail.
			if past >= GOAL_DEPTH:
				_goal(1 - end)
				return
			# A post: the mouth's corner, struck as a point.
			var post := Vector2(W * 0.5 + (1.0 if puck.x >= W * 0.5 else -1.0) * GOAL_HALF, rail)
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
	scores[by] += 1
	puck_on = false
	events.append({"kind": "goal", "by": by, "at": puck})
	puck_vel = Vector2.ZERO
	if scores[by] >= TARGET:
		over = true
		winner = by
