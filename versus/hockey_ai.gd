extends RefCounted

## The computer's hand at air hockey. It plays the way a person does and with
## a person's limits: it sees the puck a little late (`react`), its arm has a
## top speed (`speed`, well under what a finger manages), and where it means
## to send the puck is off by a little (`wobble`). The three levels are those
## numbers and whether it reads a bounce off the long rails before it happens.
##
## One of these a mallet: `drive(sim, dt)` once a sim step sets `sim.aim[me]`.
## It keeps what it saw in a short queue, so two of them can play each other
## (tests/_probe_hockey.gd) and neither sees the present.
##
## What it does, in order: a puck coming at its goal is met on a line in front
## of the goal; a puck in its own half is got behind and driven at the other
## goal (straight, or off a rail when it feels like it); otherwise it waits in
## front of its goal, shading toward the puck's side.

const Sim = preload("res://versus/hockey_sim.gd")

## Per level: the arm's top speed (m/s), how late it sees (s), how far off
## its aim is (m at the far goal), how far off it stands to block (m),
## whether it reads the rails, how often it goes for a bank (0..1), and how
## hard it follows through (0..1).
const LEVELS := [
	{"speed": 1.5, "react": 0.30, "wobble": 0.34, "slip": 0.12, "rails": false, "bank": 0.0, "drive": 0.55},
	{"speed": 2.4, "react": 0.19, "wobble": 0.2, "slip": 0.075, "rails": true, "bank": 0.2, "drive": 0.8},
	{"speed": 3.5, "react": 0.11, "wobble": 0.1, "slip": 0.045, "rails": true, "bank": 0.35, "drive": 1.0},
]
## How far in front of its goal it stands to defend, and to wait.
const GUARD := 0.2
## How far behind the puck it lines up before it swings.
const BACK := 0.07

var me := 1
var level := 1
var rng := RandomNumberGenerator.new()
## What it has seen, oldest first: [seconds, puck, puck_vel, on].
var _seen: Array = []
var _t := 0.0
## The point it is driving the puck at, picked once a possession.
var _mark := Vector2.ZERO
var _has_mark := false
## A breath after a serve or a goal before it moves on the puck.
var _rest := 0.0
## How long the puck has dawdled in its half without being sent back. Past
## STALL it stops lining anything up and goes straight at the puck.
var _dawdle := 0.0
const STALL := 2.5
## How far off this block is, picked once a shot coming in.
var _slip := 0.0
var _blocking := false

func _init(seat := 1, the_level := 1, seed := 0) -> void:
	me = seat
	level = clampi(the_level, 0, LEVELS.size() - 1)
	if seed == 0:
		rng.randomize()
	else:
		rng.seed = seed

## The puck was served: it takes a moment to go for it.
func served() -> void:
	_rest = lerpf(0.9, 0.45, level / 2.0)
	_has_mark = false
	_seen.clear()

func drive(sim: RefCounted, dt: float) -> void:
	var cfg: Dictionary = LEVELS[level]
	_t += dt
	_rest = maxf(0.0, _rest - dt)
	_seen.append([_t, sim.puck, sim.puck_vel, sim.puck_on])
	while _seen.size() > 1 and _t - float(_seen[1][0]) >= float(cfg.react):
		_seen.pop_front()
	var saw: Array = _seen[0]
	var puck: Vector2 = saw[1]
	var vel: Vector2 = saw[2]
	var at: Vector2 = sim.mallet[me]
	# Everything below is worked out for a mallet at the top (seat 1) and
	# turned over for the one at the bottom.
	var flip := me == 0
	if flip:
		puck = _turn(puck)
		vel = Vector2(-vel.x, -vel.y)
		at = _turn(at)
	var want := Vector2(Sim.W * 0.5, GUARD)
	var pace: float = cfg.speed
	if not bool(saw[3]) or sim.over:
		_has_mark = false
	elif puck.y < Sim.L * 0.5 + Sim.PUCK_R and (vel.y > -0.6 or puck.y < 0.5) and _rest <= 0.0:
		# In its half and not flying at the goal: get behind it and drive.
		if not _has_mark:
			_has_mark = true
			_mark = _pick_mark(cfg, puck)
		var line := (_mark - puck).normalized()
		var behind := puck - line * (Sim.PUCK_R + Sim.MALLET_R + BACK)
		behind.y = maxf(behind.y, Sim.MALLET_R)
		var lined := (at - behind).length() < 0.05 or (puck - at).normalized().dot(line) > 0.92
		_dawdle = _dawdle + dt if vel.length() < 0.4 else 0.0
		if _dawdle > STALL:
			want = puck
		elif at.y > puck.y - 0.02 and not lined:
			# On the wrong side of it: round the side it has more room on.
			var round_x := puck.x + (-1.0 if at.x < puck.x else 1.0) * (Sim.PUCK_R + Sim.MALLET_R + 0.05)
			want = Vector2(round_x, maxf(puck.y - 0.12, Sim.MALLET_R))
		elif lined:
			want = puck + line * 0.3
			pace = float(cfg.speed) * float(cfg.drive)
		else:
			want = behind
	elif vel.y < -0.15:
		# Coming at the goal: meet it on the guard line.
		_has_mark = false
		if not _blocking:
			_blocking = true
			_slip = rng.randfn(0.0, float(cfg.slip))
		var hit: Vector2 = _reach(puck, vel, GUARD + Sim.PUCK_R, bool(cfg.rails))
		if hit.y >= 0.0:
			want = Vector2(clampf(hit.x + _slip, Sim.W * 0.5 - Sim.GOAL_HALF - 0.08, Sim.W * 0.5 + Sim.GOAL_HALF + 0.08), GUARD)
	else:
		_has_mark = false
		want = Vector2(lerpf(Sim.W * 0.5, puck.x, 0.35), GUARD)
	if flip:
		want = _turn(want)
		at = _turn(at)
	want = Sim.clamp_half(me, want)
	if not _has_mark:
		_dawdle = 0.0
	if vel.y >= -0.15:
		_blocking = false
	var to: Vector2 = want - at
	var step: float = pace * dt
	sim.aim[me] = at + (to if to.length() <= step else to.normalized() * step)

## Where the drive is meant to go: into the far goal, straight or off a long
## rail, and off by this level's wobble.
func _pick_mark(cfg: Dictionary, puck: Vector2) -> Vector2:
	var goal := Vector2(Sim.W * 0.5, Sim.L)
	var off := rng.randfn(0.0, float(cfg.wobble))
	var mark := goal + Vector2(off, 0.0)
	if rng.randf() < float(cfg.bank):
		# Off a rail: aim at the goal's reflection in it.
		var rail := 0.0 if rng.randf() < 0.5 else Sim.W
		var mirrored := Vector2(2.0 * rail - mark.x, mark.y)
		var t := (rail - puck.x) / (mirrored.x - puck.x) if absf(mirrored.x - puck.x) > 0.001 else 0.5
		mark = puck + (mirrored - puck) * clampf(t, 0.05, 1.0)
	return mark

static func _turn(p: Vector2) -> Vector2:
	return Vector2(Sim.W - p.x, Sim.L - p.y)

## Sim.reach_line on what was seen rather than what is.
static func _reach(puck: Vector2, vel: Vector2, line: float, rails: bool) -> Vector2:
	if absf(vel.y) < 0.02 or signf(line - puck.y) != signf(vel.y):
		return Vector2(puck.x, -1.0)
	var t := (line - puck.y) / vel.y
	var x := puck.x + vel.x * t
	if not rails:
		return Vector2(clampf(x, Sim.PUCK_R, Sim.W - Sim.PUCK_R), t)
	var lo := Sim.PUCK_R
	var span := Sim.W - 2.0 * Sim.PUCK_R
	var u := fposmod(x - lo, span * 2.0)
	if u > span:
		u = span * 2.0 - u
	return Vector2(lo + u, t)
