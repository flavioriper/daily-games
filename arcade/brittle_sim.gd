extends RefCounted

## Brittle's game, pure data (arcade/brittle_screen.gd plays it): a tin of
## nut brittle cut in squares, each with a number iced on it, and a stream of
## sugar balls poured up from a scoop at the foot of the tin. A ball that
## strikes a square takes one off its number, and at nothing the square
## breaks. When every ball is back on the floor the squares come down a row
## and a new row is laid at the top; a square past the last row ends the run.
##
## Field units: a cell is 1 x 1, x runs 0..COLS, y runs 0 at the top to FLOOR.
## Row r stands at y r..r+1; row ROWS is the empty lane over the floor, and a
## square in it is the end. Fixed step `DT`; nothing here draws or plays a
## sound: `events` says what happened and the screen drains it.

const COLS := 7
const ROWS := 9
const FLOOR := float(ROWS + 1)
const W := float(COLS)
const DT := 1.0 / 120.0
## A ball: radius and speed, cells a second.
const R := 0.135
const SPEED := 15.0
## A square's half width: the gap between two is what a ball's edge reads.
const HALF := 0.46
## An item is struck within this of its middle.
const ITEM_R := 0.3
## The stream: seconds between two balls, shorter the more there are, so a
## large handful is poured in about the same time.
const POUR := 0.085
const POUR_MIN := 0.028
const POUR_ALL := 2.6
## Aim: never flatter than this share of the speed.
const MIN_RISE := 0.13
## After a bounce a ball keeps at least this share going up or down, so it
## cannot run for ever from wall to wall.
const MIN_FALL := 0.06
## Rolling home along the floor, and flying back when called, cells a second.
const ROLL := 13.0
const BACK := 34.0
## From this far into a volley a little weight pulls every ball down: no
## volley can last for ever between two squares.
const STALL := 26.0
const PULL := 5.0
## What a run holds at the start.
const START_BALLS := 1
const UNDOS := 2
const SIGHTS := 2
## Rows a Second chance takes off the bottom.
const REVIVE_ROWS := 3
## The first step each kind may come, and how likely in a row.
const TRI_FROM := 3
const TRI_ODDS := 0.2
const POP_FROM := 7
const POP_ODDS := 0.07
const LINE_FROM := 5
const LINE_ODDS := 0.28
const FIZZ_FROM := 9
const FIZZ_ODDS := 0.14
## A hard square, worth twice the step, from this step on.
const HARD_FROM := 6
const HARD_ODDS := 0.25
## How many squares a row may hold: FEW at the start, one more every
## MORE_EVERY steps, up to MOST.
const FEW := 2
const MOST := 5
const MORE_EVERY := 9
## A cleared tin is worth this many times the step.
const CLEAR_BONUS := 10
## One tick of sound for every this many seconds of hits.
const HIT_GAP := 0.05

enum Kind { NONE, SQUARE, TL, TR, BR, BL, POP, PLUS, ROW, COL, FIZZ }
enum Phase { AIM, FLY }
enum Ball { WAIT, FLY, ROLL, HOME, BACK }

var rng := RandomNumberGenerator.new()
## One entry a cell, row by row: COLS * (ROWS + 1).
var kind := PackedInt32Array()
var hp := PackedInt32Array()
var full := PackedInt32Array()
## Sim seconds at the cell's last hit, for the board's knock.
var struck := PackedFloat32Array()
## An item already used this volley: it goes at the volley's end.
var spent := PackedByteArray()

var phase: int = Phase.AIM
var step_n := 0
var score := 0
var balls := START_BALLS
var undos := UNDOS
var sights := SIGHTS
var over := false
## The scoop: where the volley leaves from.
var home_x := W * 0.5
## Where the first ball down landed: the next volley's scoop.
var next_x := W * 0.5
var clock := 0.0
## Everything still in flight: positions, velocities, states. `prev` is
## where every ball stood before the last step, so the board can draw a
## frame that falls between two steps where it falls (brittle_board.gd).
var pos := PackedVector2Array()
var prev := PackedVector2Array()
var vel := PackedVector2Array()
var state := PackedByteArray()
var fired := 0
var landed := 0
var events: Array = []
## Run stats.
var broke := 0
var best_crush := 0
var volleys := 0
var crush := 0
var gained := 0
var _pour := 0.0
var _pour_t := 0.0
var _dir := Vector2.UP
var _home_set := false
var _hit_t := -1.0
var _undo: Dictionary = {}
# the ball in hand while it is tested against cells
var _p := Vector2.ZERO
var _v := Vector2.ZERO

func _init(seed_value := -1) -> void:
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	var n := COLS * (ROWS + 1)
	kind.resize(n)
	hp.resize(n)
	full.resize(n)
	struck.resize(n)
	spent.resize(n)
	struck.fill(-99.0)
	_spawn_step()

static func index(r: int, c: int) -> int:
	return r * COLS + c

static func solid(k: int) -> bool:
	return k >= Kind.SQUARE and k <= Kind.POP

static func centre(i: int) -> Vector2:
	return Vector2(i % COLS + 0.5, i / COLS + 0.5)

func is_over() -> bool:
	return over

func flying() -> bool:
	return phase == Phase.FLY

## Squares in the last row: one more step and the run is over.
func tight() -> bool:
	for c in COLS:
		if solid(kind[index(ROWS - 1, c)]):
			return true
	return false

func bricks_left() -> int:
	var n := 0
	for i in kind.size():
		if solid(kind[i]):
			n += 1
	return n

# --- a volley ---

## A direction a volley may leave in: up, never flatter than MIN_RISE.
static func clamp_aim(d: Vector2) -> Vector2:
	var v := d.normalized()
	if v.y > -MIN_RISE:
		var side := -1.0 if v.x < 0.0 else 1.0
		v = Vector2(side * sqrt(1.0 - MIN_RISE * MIN_RISE), -MIN_RISE)
	return v

func can_fire() -> bool:
	return phase == Phase.AIM and not over

func fire(d: Vector2) -> bool:
	if not can_fire():
		return false
	_keep_undo()
	_dir = clamp_aim(d)
	phase = Phase.FLY
	volleys += 1
	clock = 0.0
	fired = 0
	landed = 0
	crush = 0
	gained = 0
	_home_set = false
	next_x = home_x
	struck.fill(-99.0)
	_hit_t = -1.0
	_pour = clampf(POUR_ALL / float(balls), POUR_MIN, POUR)
	_pour_t = 0.0
	pos.resize(balls)
	vel.resize(balls)
	state.resize(balls)
	for k in balls:
		pos[k] = Vector2(home_x, FLOOR - R)
		vel[k] = Vector2.ZERO
		state[k] = Ball.WAIT
	prev = pos.duplicate()
	events.append({"kind": "fire", "balls": balls})
	return true

## The balls in the air come straight home and the ones not poured stay.
func recall() -> bool:
	if phase != Phase.FLY or fired == 0:
		return false
	for k in state.size():
		if state[k] == Ball.FLY:
			state[k] = Ball.BACK
		elif state[k] == Ball.WAIT:
			state[k] = Ball.ROLL
	fired = balls
	events.append({"kind": "recall"})
	return true

func step() -> void:
	if phase != Phase.FLY:
		return
	clock += DT
	# a packed array assigned is shared, not copied: one copy a step
	prev = pos.duplicate()
	if fired < balls:
		_pour_t -= DT
		while _pour_t <= 0.0 and fired < balls:
			vel[fired] = _dir * SPEED
			state[fired] = Ball.FLY
			fired += 1
			_pour_t += _pour
	var home := 0
	for k in state.size():
		match state[k]:
			Ball.FLY:
				_fly(k)
			Ball.ROLL:
				var p: Vector2 = pos[k]
				p.y = FLOOR - R
				p.x = move_toward(p.x, next_x, ROLL * DT)
				pos[k] = p
				if p.x == next_x:
					state[k] = Ball.HOME
			Ball.BACK:
				var to := Vector2(next_x, FLOOR - R)
				var p2: Vector2 = pos[k].move_toward(to, BACK * DT)
				pos[k] = p2
				if p2 == to:
					state[k] = Ball.HOME
			Ball.HOME:
				home += 1
	if home == state.size():
		_end_volley()

func _fly(k: int) -> void:
	_p = pos[k]
	_v = vel[k]
	if clock > STALL:
		_v.y += PULL * DT
		_v = _v.normalized() * SPEED
	_p += _v * DT
	var bounced := false
	if _p.x < R:
		_p.x = R
		_v.x = absf(_v.x)
		bounced = true
	elif _p.x > W - R:
		_p.x = W - R
		_v.x = -absf(_v.x)
		bounced = true
	if _p.y < R:
		_p.y = R
		_v.y = absf(_v.y)
		bounced = true
	if bounced:
		_keep_moving()
		if k == fired - 1 or k % 7 == 0:
			events.append({"kind": "wall", "at": _p})
	if _p.y >= FLOOR - R and _v.y > 0.0:
		_p.y = FLOOR - R
		pos[k] = _p
		landed += 1
		state[k] = Ball.ROLL
		if not _home_set:
			_home_set = true
			next_x = clampf(_p.x, R, W - R)
			events.append({"kind": "land", "x": next_x})
		return
	var c0 := maxi(int(_p.x - R), 0)
	var c1 := mini(int(_p.x + R), COLS - 1)
	var r0 := maxi(int(_p.y - R), 0)
	var r1 := mini(int(_p.y + R), ROWS)
	for r in range(r0, r1 + 1):
		for c in range(c0, c1 + 1):
			var i := r * COLS + c
			var what := kind[i]
			if what == Kind.NONE:
				continue
			if what >= Kind.PLUS:
				_touch_item(i, what)
			elif _collide(i):
				_hit(i)
	pos[k] = _p
	vel[k] = _v

## Going up or down at least MIN_FALL of the speed, at the same speed.
func _keep_moving() -> void:
	if absf(_v.y) < MIN_FALL * SPEED:
		var up := -1.0 if _v.y < 0.0 else 1.0
		_v.y = up * MIN_FALL * SPEED
		_v = _v.normalized() * SPEED

## Bounces the ball in hand off cell `i`; true when it struck. Used by a real
## ball and by the aim's trace, so the guide is the game's own physics.
func _collide(i: int) -> bool:
	var what := kind[i]
	var m := centre(i)
	var q: Vector2
	if what == Kind.SQUARE or what == Kind.POP:
		q = Vector2(clampf(_p.x, m.x - HALF, m.x + HALF), clampf(_p.y, m.y - HALF, m.y + HALF))
		if q == _p:
			# deep inside: out by the nearest side
			var d := _p - m
			if absf(d.x) > absf(d.y):
				q.x = m.x + signf(d.x) * HALF
			else:
				q.y = m.y + signf(d.y) * HALF
			return _reflect(q, _side(d))
	else:
		var t := triangle(what, m)
		var inside := Geometry2D.point_is_inside_triangle(_p, t[0], t[1], t[2])
		var best := INF
		for e in 3:
			var c := Geometry2D.get_closest_point_to_segment(_p, t[e], t[(e + 1) % 3])
			var dd := c.distance_squared_to(_p)
			if dd < best:
				best = dd
				q = c
		if inside:
			# t[1] and t[2] are the long side: out through it
			var nrm: Vector2 = ((t[1] + t[2]) * 0.5 - t[0]).normalized()
			var foot := Geometry2D.get_closest_point_to_segment(_p, t[1], t[2])
			return _reflect(foot, nrm)
	var off := _p - q
	var dist2 := off.length_squared()
	if dist2 >= R * R or dist2 == 0.0:
		return false
	return _reflect(q, off / sqrt(dist2))

static func _side(d: Vector2) -> Vector2:
	if absf(d.x) > absf(d.y):
		return Vector2(signf(d.x), 0.0)
	return Vector2(0.0, signf(d.y))

func _reflect(q: Vector2, n: Vector2) -> bool:
	_p = q + n * R
	var into := _v.dot(n)
	if into >= 0.0:
		return false
	_v -= 2.0 * into * n
	_keep_moving()
	return true

## A wedge's three corners: the right angle first, the long side after.
static func triangle(what: int, m: Vector2) -> Array:
	var a := m + Vector2(-HALF, -HALF)
	var b := m + Vector2(HALF, -HALF)
	var c := m + Vector2(HALF, HALF)
	var d := m + Vector2(-HALF, HALF)
	match what:
		Kind.TL:
			return [a, b, d]
		Kind.TR:
			return [b, c, a]
		Kind.BR:
			return [c, d, b]
	return [d, a, c]

func _hit(i: int) -> void:
	struck[i] = clock
	if clock - _hit_t >= HIT_GAP:
		_hit_t = clock
		events.append({"kind": "hit", "i": i, "at": _p, "left": hp[i]})
	_take(i, 1)

## Takes `n` off a square, breaking it at nothing. Popping candy breaks into
## its eight neighbours, each losing a step's worth: a chain can run.
func _take(i: int, n: int) -> void:
	if not solid(kind[i]):
		return
	var took := mini(n, hp[i])
	hp[i] -= took
	score += took
	if hp[i] > 0:
		return
	var was := kind[i]
	var size := full[i]
	kind[i] = Kind.NONE
	broke += 1
	crush += 1
	best_crush = maxi(best_crush, crush)
	events.append({"kind": "break", "i": i, "at": centre(i), "was": was, "full": size, "crush": crush})
	if was == Kind.POP:
		events.append({"kind": "pop", "at": centre(i)})
		var r := i / COLS
		var c := i % COLS
		var blast := maxi(step_n, 3)
		for dr in range(-1, 2):
			for dc in range(-1, 2):
				var r2 := r + dr
				var c2 := c + dc
				if (dr != 0 or dc != 0) and r2 >= 0 and r2 <= ROWS and c2 >= 0 and c2 < COLS:
					var j := index(r2, c2)
					struck[j] = clock
					_take(j, blast)

func _touch_item(i: int, what: int) -> void:
	if _p.distance_squared_to(centre(i)) > (ITEM_R + R) * (ITEM_R + R):
		return
	match what:
		Kind.PLUS:
			kind[i] = Kind.NONE
			gained += 1
			events.append({"kind": "plus", "at": centre(i)})
		Kind.ROW, Kind.COL:
			# Each ball through it runs the line once; `struck` here is a
			# short wait, or a ball inside it would fire it every step.
			if clock - struck[i] < 0.12:
				return
			struck[i] = clock
			spent[i] = 1
			var r := i / COLS
			var c := i % COLS
			events.append({"kind": "line", "i": i, "at": centre(i), "row": what == Kind.ROW})
			if what == Kind.ROW:
				for x in COLS:
					_line_hit(index(r, x))
			else:
				for y in ROWS + 1:
					_line_hit(index(y, c))
		Kind.FIZZ:
			if clock - struck[i] < 0.12:
				return
			struck[i] = clock
			spent[i] = 1
			var turn := rng.randf_range(-PI * 0.42, PI * 0.42)
			_v = Vector2.UP.rotated(turn) * SPEED
			events.append({"kind": "fizz", "at": centre(i)})

func _line_hit(i: int) -> void:
	if solid(kind[i]):
		struck[i] = clock
		_take(i, 1)

func _end_volley() -> void:
	phase = Phase.AIM
	home_x = next_x
	for i in kind.size():
		if spent[i] != 0:
			spent[i] = 0
			kind[i] = Kind.NONE
	balls += gained
	if bricks_left() == 0:
		var bonus := CLEAR_BONUS * step_n
		score += bonus
		events.append({"kind": "clear", "pts": bonus})
	events.append({"kind": "volley", "crush": crush, "gained": gained})
	_descend()

func _descend() -> void:
	for r in range(ROWS, 0, -1):
		for c in COLS:
			var i := index(r, c)
			var j := index(r - 1, c)
			kind[i] = kind[j]
			hp[i] = hp[j]
			full[i] = full[j]
			struck[i] = struck[j]
	for c in COLS:
		kind[index(0, c)] = Kind.NONE
	# what comes down onto the lane over the floor is done with: a square
	# there ends the run, a plum is picked up, anything else is gone
	var ended := false
	for c in COLS:
		var i := index(ROWS, c)
		var what := kind[i]
		if solid(what):
			ended = true
		elif what == Kind.PLUS:
			kind[i] = Kind.NONE
			balls += 1
			events.append({"kind": "plus", "at": centre(i)})
		else:
			kind[i] = Kind.NONE
	if ended:
		over = true
		events.append({"kind": "descend", "step": step_n})
		events.append({"kind": "over"})
		return
	_spawn_step()
	events.append({"kind": "descend", "step": step_n})
	if tight():
		events.append({"kind": "tight"})

## The next step's row. Row 0 is empty when this runs.
func _spawn_step() -> void:
	step_n += 1
	var cols := []
	for c in COLS:
		cols.append(c)
	_shuffle(cols)
	var want := mini(FEW + step_n / MORE_EVERY, MOST)
	var n := FEW + rng.randi_range(0, want - FEW + 1) if step_n > 1 else 2
	n = mini(n, COLS - 2)
	for k in n:
		_lay_square(index(0, cols[k]))
	# a plum in every row, or the run could never grow
	kind[index(0, cols[n])] = Kind.PLUS
	var free := n + 1
	if step_n >= LINE_FROM and rng.randf() < LINE_ODDS and free < COLS:
		kind[index(0, cols[free])] = Kind.ROW if rng.randf() < 0.5 else Kind.COL
		free += 1
	if step_n >= FIZZ_FROM and rng.randf() < FIZZ_ODDS and free < COLS:
		kind[index(0, cols[free])] = Kind.FIZZ

func _lay_square(i: int) -> void:
	var value := step_n
	if step_n >= HARD_FROM and rng.randf() < HARD_ODDS:
		value *= 2
	var what: int = Kind.SQUARE
	if step_n >= POP_FROM and rng.randf() < POP_ODDS:
		what = Kind.POP
	elif step_n >= TRI_FROM and rng.randf() < TRI_ODDS:
		what = Kind.TL + rng.randi_range(0, 3)
	kind[i] = what
	hp[i] = value
	full[i] = value
	struck[i] = -99.0

func _shuffle(a: Array) -> void:
	for k in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, k)
		var t = a[k]
		a[k] = a[j]
		a[j] = t

# --- what the aim sees ---

## Where a ball sent `d` from the scoop goes: the point it starts at, one for
## each bounce up to `bounces`, and the last point it reached. No square is
## touched and no number changes.
func trace(d: Vector2, bounces: int) -> PackedVector2Array:
	var out := PackedVector2Array([Vector2(home_x, FLOOR - R)])
	_p = out[0]
	_v = clamp_aim(d) * SPEED
	var seen := 0
	for _s in 1400:
		var was := _v
		_p += _v * DT
		if _p.x < R:
			_p.x = R
			_v.x = absf(_v.x)
		elif _p.x > W - R:
			_p.x = W - R
			_v.x = -absf(_v.x)
		if _p.y < R:
			_p.y = R
			_v.y = absf(_v.y)
		if _p.y >= FLOOR - R and _v.y > 0.0:
			out.append(_p)
			return out
		for r in range(maxi(int(_p.y - R), 0), mini(int(_p.y + R), ROWS) + 1):
			for c in range(maxi(int(_p.x - R), 0), mini(int(_p.x + R), COLS - 1) + 1):
				var i := r * COLS + c
				if solid(kind[i]):
					_collide(i)
		if _v != was:
			out.append(_p)
			seen += 1
			if seen > bounces:
				return out
	out.append(_p)
	return out

# --- tools ---

func _keep_undo() -> void:
	_undo = {"kind": kind.duplicate(), "hp": hp.duplicate(), "full": full.duplicate(), "step": step_n,
		"score": score, "balls": balls, "home": home_x, "rng": rng.state, "broke": broke, "volleys": volleys}

func can_undo() -> bool:
	return phase == Phase.AIM and not over and undos > 0 and not _undo.is_empty()

## The last volley never happened: the row it brought down, its score and the
## balls it won go back, and the same row will come again.
func undo() -> bool:
	if not can_undo():
		return false
	undos -= 1
	kind = _undo.kind
	hp = _undo.hp
	full = _undo.full
	step_n = _undo.step
	score = _undo.score
	balls = _undo.balls
	home_x = _undo.home
	next_x = home_x
	rng.state = _undo.rng
	broke = _undo.broke
	volleys = _undo.volleys
	struck.fill(-99.0)
	spent.fill(0)
	_undo = {}
	return true

## The Second chance: the three lowest rows and the lane are swept off.
func revive() -> void:
	for r in range(ROWS - REVIVE_ROWS + 1, ROWS + 1):
		for c in COLS:
			kind[index(r, c)] = Kind.NONE
	over = false
	phase = Phase.AIM
	_undo = {}
	if bricks_left() == 0:
		_spawn_step()
	events.append({"kind": "revive"})
