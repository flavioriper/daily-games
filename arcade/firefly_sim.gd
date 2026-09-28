extends RefCounted

## Firefly's whole game as pure data: the first game on the Arcade tab, a
## formation shooter after the 1981 arcade genre, re-dressed as a night
## garden (spec docs/superpowers/specs/2026-09-27-arcade-firefly-design.md).
## The screen (arcade/firefly_screen.gd) steps it at a fixed DT, hands it the
## player's hands (`target_x`, `axis`, `fire`) and draws what it holds; it
## reads `events` after every step for sounds and bursts.
##
## Field units, not pixels: the field is W by H with y down, and the screen
## scales it to fit. The cast: the firefly (you), gnats (one hit, 50 in the
## swarm and 100 diving), beetles (one hit, 80 and 160) and moths (two
## hits, 150 in the swarm, 400 diving and doubled for each escort shot down
## before them). A moth may dive alone and spin a silk beam: a firefly
## caught in it is carried up and lost, and hangs under the moth in the
## swarm; shoot that moth while it is diving and the firefly comes back and
## flies beside yours, two shots at once. Shoot it in the swarm instead and
## the captive turns rogue. Every fourth stage from the third is a flyby:
## forty bugs pass through without firing, 100 each, and all forty earn a
## 10,000 bonus.

const W := 240.0
const H := 372.0
const DT := 1.0 / 120.0

const PLAYER_Y := H - 24.0
const PLAYER_SPEED := 190.0
const PLAYER_R := 6.0
## The half-gap between the two ships of a pair.
const PAIR := 8.0
const SHOT_SPEED := 420.0
const SHOT_R := 2.0
## Volleys in the air at once; a pair's volley is two shots.
const MAX_VOLLEYS := 2
const FIRE_GAP := 0.14
const ENEMY_R := 7.0
const BULLET_R := 2.0
const BULLET_SPEED := 150.0

const COLS := 10
const SLOT_DX := 20.0
const SLOT_DY := 17.0
const FORM_TOP := 46.0
## How far a captive hangs above its moth.
const CAPTIVE_UP := 13.0

const START_SHIPS := 3
const EXTRA_FIRST := 20000
const EXTRA_EVERY := 70000

enum Kind { GNAT, BEETLE, MOTH, ROGUE }
enum St { WAIT, ENTER, FORM, DIVE, RETURN, BEAM, FLYBY, DEAD }
enum Ship { ALIVE, DEAD, CAPTURED }
enum Phase { INTRO, PLAY, CLEAR, RESULT, OVER }

const POINTS_FORM := {Kind.GNAT: 50, Kind.BEETLE: 80, Kind.MOTH: 150, Kind.ROGUE: 500}
const POINTS_DIVE := {Kind.GNAT: 100, Kind.BEETLE: 160, Kind.MOTH: 400, Kind.ROGUE: 1000}

## Entrance paths, in fractions of the field; each ends where the bug turns
## for its seat and flies home. "mirror" flips them across the middle.
const PATH_TOP := [Vector2(0.56, -0.06), Vector2(0.53, 0.12), Vector2(0.42, 0.33), Vector2(0.24, 0.52),
	Vector2(0.17, 0.66), Vector2(0.26, 0.77), Vector2(0.40, 0.71), Vector2(0.44, 0.57), Vector2(0.38, 0.45)]
const PATH_SIDE := [Vector2(-0.08, 0.90), Vector2(0.12, 0.83), Vector2(0.32, 0.70), Vector2(0.45, 0.53),
	Vector2(0.43, 0.38), Vector2(0.31, 0.31), Vector2(0.20, 0.39), Vector2(0.24, 0.51), Vector2(0.34, 0.49)]
## The flyby's paths, which leave the field instead of taking a seat.
const FLY_A := [Vector2(0.45, -0.06), Vector2(0.46, 0.28), Vector2(0.30, 0.52), Vector2(0.14, 0.50),
	Vector2(0.18, 0.30), Vector2(0.38, 0.34), Vector2(0.62, 0.54), Vector2(0.86, 0.60), Vector2(1.12, 0.50)]
const FLY_B := [Vector2(-0.08, 0.80), Vector2(0.28, 0.66), Vector2(0.50, 0.42), Vector2(0.36, 0.20),
	Vector2(0.20, 0.28), Vector2(0.34, 0.50), Vector2(0.70, 0.52), Vector2(0.90, 0.30), Vector2(1.12, 0.12)]
const FLY_C := [Vector2(0.22, -0.06), Vector2(0.30, 0.24), Vector2(0.50, 0.44), Vector2(0.70, 0.26),
	Vector2(0.60, 0.10), Vector2(0.48, 0.24), Vector2(0.50, 0.60), Vector2(0.40, 0.86), Vector2(0.30, 1.12)]

var rng := RandomNumberGenerator.new()
var t := 0.0
var stage := 0
var phase := Phase.INTRO
var phase_t := 0.0
var score := 0
var ships := START_SHIPS
var next_extra := EXTRA_FIRST

# --- the player ---
var px := W * 0.5
var ship := Ship.ALIVE
var pair := false
var respawn_t := 0.0
## Where a caught ship is while it is carried up, and how far it has turned.
var caught_pos := Vector2.ZERO
var caught_spin := 0.0
var caught_by := -1
## A freed ship flying down to join yours: {pos, spin}, or empty.
var freed := {}

# --- the hands, set by the screen before each step ---
## The x the firefly heads for (NAN for none) and a keyboard's -1..1.
var target_x := NAN
var axis := 0.0
var fire := false
var _fire_cd := 0.0

var shots: Array = []     # {pos: Vector2}
var bullets: Array = []   # {pos: Vector2, vel: Vector2}
var enemies: Array = []   # see _spawn
var events: Array = []    # {type, pos, ...}; cleared by the screen

# --- the swarm ---
var sway := 0.0
var spread := 1.0
var _sway_amp := 10.0
var _breathe := 0.0
var _dive_t := 3.0
var _challenge := false
var flyby_hits := 0
var flyby_total := 0
# --- tallies for the end ---
var fired := 0
var hits := 0
var kills := 0

func _init(the_seed := 0) -> void:
	if the_seed == 0:
		rng.randomize()
	else:
		rng.seed = the_seed
	_start_stage()

# --- stages ---

static func is_challenge(n: int) -> bool:
	return n >= 3 and (n - 3) % 4 == 0

## How hard the swarm plays at a stage, counting only the ordinary ones.
func level() -> int:
	return stage - int((stage + 1) / 4.0)

func _start_stage() -> void:
	stage += 1
	_challenge = is_challenge(stage)
	phase = Phase.INTRO
	phase_t = 0.0
	enemies.clear()
	bullets.clear()
	_sway_amp = 10.0
	_breathe = 0.0
	_dive_t = 2.5
	flyby_hits = 0
	flyby_total = 0
	events.append({"type": "challenge_start" if _challenge else "stage_start", "stage": stage})
	if _challenge:
		_plan_flyby()
	else:
		_plan_stage()

func _plan_stage() -> void:
	var waves := [
		{"path": PATH_TOP, "streams": [
			{"mirror": false, "slots": [[Kind.BEETLE, 4, 1], [Kind.BEETLE, 5, 1], [Kind.BEETLE, 4, 2], [Kind.BEETLE, 5, 2]]},
			{"mirror": true, "slots": [[Kind.GNAT, 4, 3], [Kind.GNAT, 5, 3], [Kind.GNAT, 4, 4], [Kind.GNAT, 5, 4]]}]},
		{"path": PATH_SIDE, "streams": [
			{"mirror": false, "slots": [[Kind.MOTH, 3, 0], [Kind.BEETLE, 3, 1], [Kind.MOTH, 4, 0], [Kind.BEETLE, 6, 1],
				[Kind.MOTH, 5, 0], [Kind.BEETLE, 3, 2], [Kind.MOTH, 6, 0], [Kind.BEETLE, 6, 2]]}]},
		{"path": PATH_SIDE, "streams": [
			{"mirror": true, "slots": [[Kind.BEETLE, 7, 1], [Kind.BEETLE, 8, 1], [Kind.BEETLE, 7, 2], [Kind.BEETLE, 8, 2],
				[Kind.BEETLE, 1, 1], [Kind.BEETLE, 2, 1], [Kind.BEETLE, 1, 2], [Kind.BEETLE, 2, 2]]}]},
		{"path": PATH_TOP, "streams": [
			{"mirror": true, "slots": [[Kind.GNAT, 6, 3], [Kind.GNAT, 7, 3], [Kind.GNAT, 6, 4], [Kind.GNAT, 7, 4],
				[Kind.GNAT, 8, 3], [Kind.GNAT, 9, 3], [Kind.GNAT, 8, 4], [Kind.GNAT, 9, 4]]}]},
		{"path": PATH_TOP, "streams": [
			{"mirror": false, "slots": [[Kind.GNAT, 3, 3], [Kind.GNAT, 2, 3], [Kind.GNAT, 3, 4], [Kind.GNAT, 2, 4],
				[Kind.GNAT, 1, 3], [Kind.GNAT, 0, 3], [Kind.GNAT, 1, 4], [Kind.GNAT, 0, 4]]}]},
	]
	var gap := maxf(2.2, 2.9 - 0.06 * level())
	var shoot := 0.0 if level() <= 1 else minf(0.5, 0.12 + 0.05 * level())
	for w in waves.size():
		var wave: Dictionary = waves[w]
		for stream: Dictionary in wave.streams:
			var path := _path(wave.path, stream.mirror)
			var slots: Array = stream.slots
			for i in slots.size():
				var s: Array = slots[i]
				var e := _spawn(s[0], Vector2i(s[1], s[2]), path, St.ENTER)
				e.delay = 1.6 + w * gap + i * 0.12
				e.fire_left = 1 if rng.randf() < shoot else 0
				enemies.append(e)

func _plan_flyby() -> void:
	var looks := [[Kind.GNAT, Kind.BEETLE], [Kind.BEETLE, Kind.MOTH], [Kind.GNAT, Kind.GNAT],
		[Kind.MOTH, Kind.BEETLE], [Kind.BEETLE, Kind.GNAT]]
	var plan := [[FLY_A, [false, true]], [FLY_B, [false]], [FLY_B, [true]], [FLY_C, [false, true]], [FLY_A, [true]]]
	for w in plan.size():
		var mirrors: Array = plan[w][1]
		var per := 8 / mirrors.size()
		for m in mirrors.size():
			var path := _path(plan[w][0], mirrors[m])
			for i in per:
				var kind: int = looks[w][(i + m) % 2]
				var e := _spawn(kind, Vector2i(-1, -1), path, St.FLYBY)
				e.hp = 1
				e.delay = 1.8 + w * 3.4 + i * 0.16
				enemies.append(e)
				flyby_total += 1

func _spawn(kind: int, slot: Vector2i, path: PackedVector2Array, st: int) -> Dictionary:
	return {"kind": kind, "slot": slot, "hp": 2 if kind == Kind.MOTH else 1, "st": St.WAIT, "next": st,
		"pos": path[0], "heading": PI * 0.5, "path": path, "pd": 0.0, "pi": 0, "pbase": 0.0, "delay": 0.0,
		"speed": 120.0 * _pace(), "fire_left": 0, "fire_at": [], "captive": false,
		"leader": -1, "escorts_down": 0, "beam": 0.0, "beam_t": 0.0, "flash": 0.0,
		"id": rng.randi(), "hurt": false, "beam_run": false}

func _pace() -> float:
	return 1.0 + 0.045 * minf(level(), 16)

## A path from fractions of the field, smoothed through Catmull-Rom.
func _path(fracs: Array, mirror: bool) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for f: Vector2 in fracs:
		pts.append(Vector2((1.0 - f.x) if mirror else f.x, f.y) * Vector2(W, H))
	return smooth(pts)

static func smooth(pts: PackedVector2Array, steps := 10) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := pts.size()
	for i in n - 1:
		var p0 := pts[maxi(i - 1, 0)]
		var p1 := pts[i]
		var p2 := pts[i + 1]
		var p3 := pts[mini(i + 2, n - 1)]
		for k in steps:
			var u := float(k) / steps
			var u2 := u * u
			var u3 := u2 * u
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * u + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * u2
				+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * u3))
	out.append(pts[n - 1])
	return out

## Where a seat in the swarm is right now: the swarm sways while it
## gathers and breathes in and out once it has.
func home(slot: Vector2i) -> Vector2:
	var x := W * 0.5 + sway + (slot.x - (COLS - 1) * 0.5) * SLOT_DX * spread
	var y := FORM_TOP + slot.y * SLOT_DY * (1.0 + (spread - 1.0) * 0.6)
	return Vector2(x, y)

# --- the step ---

func step() -> void:
	t += DT
	phase_t += DT
	match phase:
		Phase.INTRO:
			if phase_t > 1.2:
				phase = Phase.PLAY
				phase_t = 0.0
		Phase.CLEAR:
			if phase_t > 1.6:
				_start_stage()
		Phase.RESULT:
			if phase_t > 3.2:
				_start_stage()
		Phase.OVER:
			pass
	_swarm()
	_player()
	_shots()
	_enemies()
	_bullets()
	_freed()
	_collide()
	_respawn()
	if phase == Phase.PLAY:
		_attack()
		_check_clear()

func _swarm() -> void:
	var gathering := false
	for e: Dictionary in enemies:
		if e.st == St.WAIT or e.st == St.ENTER:
			if e.next != St.FLYBY:
				gathering = true
				break
	_sway_amp = move_toward(_sway_amp, 10.0 if gathering else 0.0, DT * 6.0)
	_breathe = move_toward(_breathe, 0.0 if gathering else 1.0, DT * 0.8)
	sway = sin(t * 1.15) * _sway_amp
	spread = 1.0 + 0.13 * (0.5 - 0.5 * cos(t * 1.7)) * _breathe

func _player() -> void:
	if ship != Ship.ALIVE or phase == Phase.OVER:
		return
	var lo := PLAYER_R + 4.0 + (PAIR if pair else 0.0)
	var hi := W - lo
	var want := px
	if not is_nan(target_x):
		want = target_x
	if absf(axis) > 0.01:
		want = px + axis * 1000.0
	px = move_toward(px, clampf(want, lo, hi), PLAYER_SPEED * (1.6 if not is_nan(target_x) else 1.0) * DT)
	_fire_cd -= DT
	if fire and _fire_cd <= 0.0 and phase != Phase.INTRO:
		if shots.size() < MAX_VOLLEYS * (2 if pair else 1):
			_fire_cd = FIRE_GAP
			fired += 1
			if pair:
				shots.append({"pos": Vector2(px - PAIR, PLAYER_Y - 8.0)})
				shots.append({"pos": Vector2(px + PAIR, PLAYER_Y - 8.0)})
			else:
				shots.append({"pos": Vector2(px, PLAYER_Y - 8.0)})
			events.append({"type": "shoot", "pos": Vector2(px, PLAYER_Y)})

func _shots() -> void:
	for i in range(shots.size() - 1, -1, -1):
		var s: Dictionary = shots[i]
		s.pos.y -= SHOT_SPEED * DT
		if s.pos.y < -10.0:
			shots.remove_at(i)

func _bullets() -> void:
	for i in range(bullets.size() - 1, -1, -1):
		var b: Dictionary = bullets[i]
		b.pos += b.vel * DT
		if b.pos.y > H + 10.0 or b.pos.x < -10.0 or b.pos.x > W + 10.0:
			bullets.remove_at(i)

## Moves `e` `dist` along its path; true once it has run out.
func _follow(e: Dictionary, dist: float) -> bool:
	var path: PackedVector2Array = e.path
	e.pd += dist
	var d: float = e.pd
	var i: int = e.pi
	var base: float = e.pbase
	while i < path.size() - 1:
		var seg := path[i].distance_to(path[i + 1])
		if d - base <= seg:
			_move(e, path[i].lerp(path[i + 1], (d - base) / maxf(seg, 0.001)))
			e.pi = i
			e.pbase = base
			return false
		base += seg
		i += 1
	_move(e, path[path.size() - 1])
	return true

func _set_path(e: Dictionary, path: PackedVector2Array) -> void:
	e.path = path
	e.pd = 0.0
	e.pi = 0
	e.pbase = 0.0

func _move(e: Dictionary, p: Vector2) -> void:
	var d: Vector2 = p - e.pos
	if d.length_squared() > 1e-6:
		e.heading = lerp_angle(e.heading, d.angle(), 0.35)
	e.pos = p

## Flies `e` toward its seat; true once it is in it.
func _home_in(e: Dictionary, speed: float) -> bool:
	var to := home(e.slot)
	var d: Vector2 = to - e.pos
	var step := speed * DT
	if d.length() <= step:
		e.pos = to
		return true
	_move(e, e.pos + d.normalized() * step)
	return false

func _enemies() -> void:
	for e: Dictionary in enemies:
		e.flash = maxf(0.0, e.flash - DT)
		match e.st:
			St.WAIT:
				if phase == Phase.PLAY or phase == Phase.INTRO:
					e.delay -= DT
					if e.delay <= 0.0:
						e.st = e.next
						e.pos = (e.path as PackedVector2Array)[0]
						if e.st == St.ENTER and e.fire_left > 0:
							e.fire_at = [H * rng.randf_range(0.25, 0.45)]
			St.ENTER:
				if _follow(e, e.speed * DT):
					e.st = St.RETURN
				_maybe_fire(e)
			St.FLYBY:
				if _follow(e, e.speed * 1.15 * DT):
					e.st = St.DEAD
					e["escaped"] = true
			St.RETURN:
				if _home_in(e, e.speed * 1.1):
					e.st = St.FORM
					e.leader = -1
			St.FORM:
				e.pos = home(e.slot)
				e.heading = lerp_angle(e.heading, PI * 0.5, 0.12)
			St.DIVE:
				var done := _follow(e, e.speed * 1.15 * DT)
				_maybe_fire(e)
				if e.beam_run and (done or e.pd >= float(e.get("beam_at", 1e9))):
					e.st = St.BEAM
					e.beam_t = 0.0
					events.append({"type": "beam", "pos": e.pos})
				elif done:
					# Off the bottom: back in at the top over its seat.
					e.pos = Vector2(home(e.slot).x, -14.0)
					e.st = St.RETURN
					e.beam_run = false
			St.BEAM:
				_beam(e)
	for i in range(enemies.size() - 1, -1, -1):
		if enemies[i].st == St.DEAD:
			enemies.remove_at(i)

func _beam(e: Dictionary) -> void:
	e.heading = lerp_angle(e.heading, PI * 0.5, 0.2)
	if caught_by == e.id:
		e.beam = 1.0
		return
	e.beam_t += DT
	var bt: float = e.beam_t
	if bt < 0.8:
		e.beam = bt / 0.8
	elif bt < 3.4:
		e.beam = 1.0
	elif bt < 4.1:
		e.beam = 1.0 - (bt - 3.4) / 0.7
	else:
		e.beam = 0.0
		_leave_down(e)
		return
	if ship == Ship.ALIVE and not pair and e.beam > 0.6 and phase == Phase.PLAY:
		if absf(px - e.pos.x) < 13.0 * e.beam and not _captive_exists():
			ship = Ship.CAPTURED
			caught_by = e.id
			caught_pos = Vector2(px, PLAYER_Y)
			caught_spin = 0.0
			shots.clear()
			events.append({"type": "captured", "pos": caught_pos})

## Down and out after a beam, then back in over its seat.
func _leave_down(e: Dictionary) -> void:
	e.st = St.DIVE
	e.beam_run = false
	e.beam = 0.0
	_set_path(e, PackedVector2Array([e.pos, Vector2(e.pos.x, H + 30.0)]))

func _captive_exists() -> bool:
	for e: Dictionary in enemies:
		if e.captive or e.kind == Kind.ROGUE:
			return true
	return ship == Ship.CAPTURED

func _maybe_fire(e: Dictionary) -> void:
	var at: Array = e.fire_at
	if at.is_empty() or ship != Ship.ALIVE:
		return
	if e.pos.y >= float(at[0]):
		at.pop_front()
		if e.pos.y < PLAYER_Y - 60.0:
			var speed := BULLET_SPEED * (1.0 + 0.03 * minf(level(), 12))
			var time: float = (PLAYER_Y - e.pos.y) / speed
			var vx := clampf((px - e.pos.x) / time, -55.0, 55.0)
			bullets.append({"pos": e.pos + Vector2(0, 6), "vel": Vector2(vx, speed)})

# --- attacks ---

func _divers() -> int:
	var n := 0
	for e: Dictionary in enemies:
		if e.st == St.DIVE or e.st == St.BEAM:
			n += 1
	return n

func _attack() -> void:
	if _challenge or ship != Ship.ALIVE:
		return
	var formed: Array = []
	for e: Dictionary in enemies:
		if e.st == St.FORM:
			formed.append(e)
		elif e.st == St.WAIT or e.st == St.ENTER:
			return
	if formed.is_empty():
		return
	_dive_t -= DT
	if _dive_t > 0.0:
		return
	var lv := level()
	var few := formed.size() <= 6
	_dive_t = rng.randf_range(0.7, 1.3) * maxf(0.45, (1.6 - 0.1 * lv) * (0.6 if few else 1.0))
	if _divers() >= mini(2 + int(lv / 2.0), 7) + (2 if few else 0):
		return
	var roll := rng.randf()
	var pick: Dictionary = {}
	if roll < 0.24:
		pick = _pick_kind(formed, Kind.MOTH)
	if pick.is_empty() and roll < 0.32:
		pick = _pick_kind(formed, Kind.ROGUE)
	if pick.is_empty() and roll < 0.62:
		pick = _pick_kind(formed, Kind.BEETLE)
	if pick.is_empty():
		pick = _pick_kind(formed, Kind.GNAT)
	if pick.is_empty():
		pick = formed[rng.randi() % formed.size()]
	if pick.kind == Kind.MOTH:
		if not pick.captive and not pair and not _captive_exists() and rng.randf() < 0.55:
			_dive_beam(pick)
		else:
			_dive_escorted(pick, formed)
	else:
		_dive(pick, {})

## A seat on the swarm's edge is picked before one in its middle.
func _pick_kind(formed: Array, kind: int) -> Dictionary:
	var best: Dictionary = {}
	var best_w := -1.0
	for e: Dictionary in formed:
		if e.kind != kind:
			continue
		var w := absf(e.slot.x - (COLS - 1) * 0.5) + rng.randf() * 4.0
		if w > best_w:
			best_w = w
			best = e
	return best

func _dive_line(from: Vector2, side: float, aim: float) -> PackedVector2Array:
	var pts := PackedVector2Array([from, from + Vector2(side * 8.0, -10.0), from + Vector2(side * 20.0, -9.0),
		from + Vector2(side * 26.0, 3.0), from + Vector2(side * 21.0, 18.0)])
	var sway_x := rng.randf_range(24.0, 44.0)
	pts.append(Vector2(lerpf(from.x, aim, 0.4) + side * sway_x, from.y + 80.0))
	pts.append(Vector2(aim - side * sway_x * 0.7, H * 0.62))
	pts.append(Vector2(aim + side * sway_x * 0.6, H * 0.86))
	pts.append(Vector2(aim + side * sway_x * 1.6, H + 30.0))
	for i in range(5, pts.size() - 1):
		pts[i].x = clampf(pts[i].x, 8.0, W - 8.0)
	return smooth(pts, 12)

func _dive(e: Dictionary, lead: Dictionary) -> void:
	var side := -1.0 if e.pos.x < W * 0.5 else 1.0
	if not lead.is_empty():
		var offset: Vector2 = e.pos - lead.pos
		var line := PackedVector2Array()
		for p in (lead.path as PackedVector2Array):
			line.append(p + offset)
		_set_path(e, line)
		e.leader = lead.id
	else:
		_set_path(e, _dive_line(e.pos, side, clampf(px + rng.randf_range(-30.0, 30.0), 20.0, W - 20.0)))
		e.leader = -1
	e.st = St.DIVE
	e.speed = 100.0 * _pace()
	var lv := level()
	var n := rng.randi_range(0, mini(1 + int(lv / 3.0), 3))
	var at: Array = []
	for k in n:
		at.append(H * (0.3 + 0.1 * k) + rng.randf_range(0.0, 20.0))
	e.fire_at = at
	events.append({"type": "dive", "pos": e.pos, "kind": e.kind})

func _dive_escorted(moth: Dictionary, formed: Array) -> void:
	moth.escorts_down = 0
	_dive(moth, {})
	var taken := 0
	for e: Dictionary in formed:
		if taken >= 2:
			break
		if e.kind == Kind.BEETLE and e.slot.y == 1 and absi(e.slot.x - moth.slot.x) <= 1:
			_dive(e, moth)
			taken += 1

## A moth's beam run: out of its seat, down to the middle of the field above
## the firefly, and the beam opens there.
func _dive_beam(e: Dictionary) -> void:
	var side := -1.0 if e.pos.x < W * 0.5 else 1.0
	var from: Vector2 = e.pos
	var aim := clampf(px, 30.0, W - 30.0)
	var stop := Vector2(aim, H * 0.54)
	var pts := PackedVector2Array([from, from + Vector2(side * 8.0, -10.0), from + Vector2(side * 20.0, -9.0),
		from + Vector2(side * 26.0, 3.0), from + Vector2(side * 21.0, 18.0),
		Vector2(lerpf(from.x, aim, 0.6), H * 0.36), stop, stop + Vector2(0, 1)])
	_set_path(e, smooth(pts, 12))
	var len := 0.0
	var path: PackedVector2Array = e.path
	for i in path.size() - 2:
		len += path[i].distance_to(path[i + 1])
	e["beam_at"] = len
	e.beam_run = true
	e.st = St.DIVE
	e.speed = 90.0 * _pace()
	e.fire_at = []
	events.append({"type": "dive", "pos": e.pos, "kind": e.kind})

# --- hits ---

func _collide() -> void:
	# Shots against bugs, and against a captive hanging under its moth.
	for i in range(shots.size() - 1, -1, -1):
		var s: Dictionary = shots[i]
		var hit := false
		for e: Dictionary in enemies:
			if e.st == St.WAIT or e.st == St.DEAD:
				continue
			if e.captive and e.st != St.FORM and (s.pos as Vector2).distance_to(e.pos + _captive_offset(e)) < ENEMY_R:
				e.captive = false
				events.append({"type": "captive_lost", "pos": e.pos + _captive_offset(e)})
				hit = true
				break
			if (s.pos as Vector2).distance_to(e.pos) < ENEMY_R + SHOT_R:
				_hurt(e)
				hit = true
				break
		if hit:
			hits += 1
			shots.remove_at(i)
	for i in range(enemies.size() - 1, -1, -1):
		if enemies[i].st == St.DEAD:
			enemies.remove_at(i)
	if ship != Ship.ALIVE:
		return
	var bodies := _ship_xs()
	for i in range(bullets.size() - 1, -1, -1):
		var b: Dictionary = bullets[i]
		for k in bodies.size():
			if (b.pos as Vector2).distance_to(Vector2(bodies[k], PLAYER_Y)) < PLAYER_R + BULLET_R:
				bullets.remove_at(i)
				_ship_hit(k)
				return
	for e: Dictionary in enemies:
		if e.st == St.DIVE or e.st == St.RETURN or e.st == St.ENTER or e.st == St.FLYBY:
			for k in bodies.size():
				if (e.pos as Vector2).distance_to(Vector2(bodies[k], PLAYER_Y)) < PLAYER_R + ENEMY_R - 1.0:
					_kill(e, true)
					_ship_hit(k)
					return

## A captive hangs behind its moth, whichever way the moth is flying.
static func captive_offset(e: Dictionary) -> Vector2:
	return -Vector2.from_angle(e.heading) * CAPTIVE_UP

func _captive_offset(e: Dictionary) -> Vector2:
	return captive_offset(e)

func ship_xs() -> Array:
	return _ship_xs()

func _ship_xs() -> Array:
	return [px - PAIR, px + PAIR] if pair else [px]

func _hurt(e: Dictionary) -> void:
	e.hp -= 1
	e.flash = 0.12
	if e.hp > 0:
		e.hurt = true
		events.append({"type": "hurt", "pos": e.pos, "kind": e.kind})
		return
	_kill(e, false)

func _kill(e: Dictionary, rammed: bool) -> void:
	var diving: bool = e.st != St.FORM
	var hang: Vector2 = e.pos + _captive_offset(e)
	e.st = St.DEAD
	kills += 1
	var pts := 0
	if _challenge:
		pts = 100
		flyby_hits += 1
	elif e.kind == Kind.MOTH and diving:
		pts = POINTS_DIVE[Kind.MOTH] * int(pow(2.0, mini(e.escorts_down, 2)))
	else:
		pts = POINTS_DIVE[e.kind] if diving else POINTS_FORM[e.kind]
	# An escort shot down before its moth doubles the moth.
	if e.leader != -1:
		for m: Dictionary in enemies:
			if m.id == e.leader and m.st != St.DEAD:
				m.escorts_down += 1
	_add(pts)
	events.append({"type": "pop", "pos": e.pos, "kind": e.kind, "points": pts, "rammed": rammed})
	if e.captive:
		if diving:
			freed = {"pos": hang, "spin": 0.0}
			events.append({"type": "rescue", "pos": freed.pos})
		else:
			var rogue := _spawn(Kind.ROGUE, Vector2i(e.slot.x, -1), PackedVector2Array([hang]), St.RETURN)
			rogue.st = St.RETURN
			enemies.append(rogue)
			events.append({"type": "rogue", "pos": rogue.pos})
		e.captive = false
	if caught_by == e.id and ship == Ship.CAPTURED:
		# Shot while it was hauling the firefly up: the firefly drops free.
		ship = Ship.ALIVE
		caught_by = -1
		px = caught_pos.x
		events.append({"type": "rescue", "pos": caught_pos})

func _ship_hit(k: int) -> void:
	var xs := _ship_xs()
	events.append({"type": "ship_pop", "pos": Vector2(xs[k], PLAYER_Y)})
	if pair:
		pair = false
		px = xs[1 - k]
		return
	ship = Ship.DEAD
	shots.clear()
	respawn_t = 2.2
	_lose_ship()

func _lose_ship() -> void:
	if ships <= 1:
		ships = 0
		phase = Phase.OVER
		phase_t = 0.0
		events.append({"type": "game_over"})
	else:
		ships -= 1

func _add(pts: int) -> void:
	score += pts
	while score >= next_extra:
		ships += 1
		next_extra = EXTRA_FIRST + EXTRA_EVERY if next_extra == EXTRA_FIRST else next_extra + EXTRA_EVERY
		events.append({"type": "extra_ship"})

# --- the caught and the freed ---

func _freed() -> void:
	if ship == Ship.CAPTURED:
		var moth: Dictionary = {}
		for e: Dictionary in enemies:
			if e.id == caught_by:
				moth = e
		if moth.is_empty():
			ship = Ship.ALIVE
			caught_by = -1
			return
		var to: Vector2 = moth.pos + Vector2(0, -CAPTIVE_UP + 2.0)
		# Pulled up the beam, turning.
		caught_spin += DT * 9.0
		caught_pos = caught_pos.move_toward(Vector2(moth.pos.x, to.y), 60.0 * DT)
		if caught_pos.distance_to(Vector2(moth.pos.x, to.y)) < 1.0:
			moth.captive = true
			moth.beam_t = maxf(moth.beam_t, 3.4)
			caught_by = -1
			ship = Ship.DEAD
			respawn_t = 1.6
			events.append({"type": "carried", "pos": caught_pos})
			_lose_ship()
			# The moth takes its prize home rather than on down the field.
			moth.st = St.RETURN
			moth.beam = 0.0
			moth.beam_run = false
		return
	if freed.is_empty():
		return
	freed.spin += DT * 8.0
	var dock := Vector2((px + PAIR * 2.0) if ship == Ship.ALIVE else W * 0.5, PLAYER_Y)
	dock.x = minf(dock.x, W - PLAYER_R - 4.0)
	freed.pos = (freed.pos as Vector2).move_toward(dock, 110.0 * DT)
	if (freed.pos as Vector2).distance_to(dock) < 1.0:
		if ship == Ship.ALIVE:
			pair = true
			px = clampf(dock.x - PAIR, PLAYER_R + 4.0 + PAIR, W - PLAYER_R - 4.0 - PAIR)
		else:
			ship = Ship.ALIVE
			px = dock.x
			ships += 1
			if phase == Phase.OVER:
				phase = Phase.PLAY
		events.append({"type": "docked", "pos": dock})
		freed = {}

func _respawn() -> void:
	if ship != Ship.DEAD or phase == Phase.OVER:
		return
	respawn_t -= DT
	if respawn_t > 0.0 or not freed.is_empty():
		return
	for e: Dictionary in enemies:
		if e.st == St.DIVE or e.st == St.BEAM or (e.st == St.RETURN and not _challenge):
			return
	if not bullets.is_empty():
		return
	ship = Ship.ALIVE
	pair = false
	px = W * 0.5
	_dive_t = 2.0
	events.append({"type": "ready"})

func _check_clear() -> void:
	if not enemies.is_empty() or ship == Ship.CAPTURED or not freed.is_empty():
		return
	phase_t = 0.0
	bullets.clear()
	if _challenge:
		var bonus := 10000 if flyby_hits == flyby_total else flyby_hits * 100
		_add(bonus)
		phase = Phase.RESULT
		events.append({"type": "challenge_result", "hits": flyby_hits, "total": flyby_total, "bonus": bonus})
	else:
		phase = Phase.CLEAR
		events.append({"type": "stage_clear", "stage": stage})

func is_over() -> bool:
	return phase == Phase.OVER

## The Second chance (arcade/boosters.gd): one firefly back, on the stage
## the game ended on, rising in once the dives have gone home.
func revive() -> void:
	if phase != Phase.OVER:
		return
	ships = 1
	ship = Ship.DEAD
	respawn_t = 1.0
	bullets.clear()
	phase = Phase.PLAY
	phase_t = 0.0
	events.append({"type": "revive"})

func challenge() -> bool:
	return _challenge
