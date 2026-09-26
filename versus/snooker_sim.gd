extends RefCounted

## Snooker's table and its physics, in metres and seconds, with no node in
## sight: the screen draws it, the rules read what a shot did, and the
## computer player clones it to try shots before it plays one.
##
## The table is the regulation playing area (3569 x 1778 mm inside the
## cushion faces, WPBSA) standing on end, the black's cushion at the top
## (y = 0) and the baulk cushion at the bottom (y = L), so the player looks
## up the table from behind the D the way the reference layout does. The
## balls and pockets are drawn SCALE times regulation, because a 52.5 mm
## ball on a phone-sized table is a speck; everything else is to size.
##
## The motion is the standard cloth model: a ball either slides or rolls.
## `roll` holds the spin about the horizontal axes as the surface speed it
## gives the ball's contact point, so a ball rolls when `roll == vel`; while
## the two differ the contact point slips, and sliding friction pulls them
## together (the centre at mu*g, the spin at 5/2 mu*g, which is where the
## classic 5/7 of a stun shot's speed comes from). Top and back spin fall out
## of that alone: a stunned cue ball keeps its spin through a collision and
## the cloth turns it into follow or draw. `side` is the spin about the
## vertical axis, again as a surface speed; it bends the angle off a cushion
## and wears away on the cloth. Collisions are resolved at their time of
## impact inside a step, so a thin cut lands where the aim line said.

const W := 1.778
const L := 3.569
const SCALE := 1.3
const R := 0.02625 * SCALE
const G := 9.81
const MU_SLIDE := 0.2
const MU_ROLL := 0.010
## How fast side spin wears off on the cloth, as surface speed per second.
const SIDE_WEAR := 0.7
const E_BALL := 0.94
const E_CUSHION := 0.78
## How much of the side spin's surface speed a cushion turns into sideways
## travel, and how much of the spin survives the contact.
const SIDE_GRIP := 0.22
const SIDE_KEEP := 0.45
## A ball slower than this, and rolling, has stopped.
const REST := 0.004
const DT := 1.0 / 480.0
const MAX_SPEED := 6.5
## Tip offsets, as a fraction of the radius, beyond which a real cue miscues.
const MAX_TIP := 0.6

## Where the cushions stop short of each pocket: along each edge from a
## corner, and either side of a middle pocket's centre line.
const CORNER := 0.09
const MIDDLE := 0.072
const JAW := 0.07
## How far past a pocket's mouth line a ball's centre goes before it drops.
const DROP := R * 0.3

const CUE := 0
const REDS := 15
const YELLOW := 16
const GREEN := 17
const BROWN := 18
const BLUE := 19
const PINK := 20
const BLACK := 21
const COUNT := 22

const BAULK_Y := L - 0.737
const D_R := 0.292
const D_CENTRE := Vector2(W * 0.5, BAULK_Y)

## Each colour's own spot, by ball id.
const SPOTS := {
	YELLOW: Vector2(W * 0.5 + D_R, BAULK_Y),
	GREEN: Vector2(W * 0.5 - D_R, BAULK_Y),
	BROWN: Vector2(W * 0.5, BAULK_Y),
	BLUE: Vector2(W * 0.5, L * 0.5),
	PINK: Vector2(W * 0.5, L * 0.25),
	BLACK: Vector2(W * 0.5, 0.324),
}

var pos := PackedVector2Array()
var vel := PackedVector2Array()
var roll := PackedVector2Array()
var side := PackedFloat32Array()
var on: Array[bool] = []
## The cue ball's orientation, only so its spots can turn with the roll.
var spin_basis := Basis.IDENTITY
## Cushion segments [a, b], cushion faces and pocket jaws alike.
var segments: Array = []
## Pockets: mouth centre, the way out, the mouth's half width.
var pockets: Array = []

# --- what the shot in play has done ---
var first_hit := -1
var potted: Array[int] = []
## Every contact since the last read, for the sound and the puffs:
## {"kind": "ball"|"cushion"|"pot", "speed": float, "at": Vector2, "id": int}.
var events: Array = []
var log_events := true

func _init() -> void:
	pos.resize(COUNT)
	vel.resize(COUNT)
	roll.resize(COUNT)
	side.resize(COUNT)
	on.resize(COUNT)
	_build_table()
	rack()

static func value(id: int) -> int:
	if id >= 1 and id <= REDS:
		return 1
	if id >= YELLOW and id <= BLACK:
		return id - YELLOW + 2
	return 0

static func is_red(id: int) -> bool:
	return id >= 1 and id <= REDS

static func is_colour(id: int) -> bool:
	return id >= YELLOW and id <= BLACK

## Every ball set for the break: the colours on their spots, the reds in
## their triangle with the apex just behind the pink, and the cue ball in
## the D (the player may move it anywhere in the D before the break).
func rack() -> void:
	for i in COUNT:
		vel[i] = Vector2.ZERO
		roll[i] = Vector2.ZERO
		side[i] = 0.0
		on[i] = true
	for id in SPOTS:
		pos[id] = SPOTS[id]
	var gap := 0.0004
	var apex := Vector2(W * 0.5, SPOTS[PINK].y - 2.0 * R - 0.002)
	var row_h := (2.0 * R + gap) * sqrt(3.0) * 0.5
	var id := 1
	for k in 5:
		for j in k + 1:
			pos[id] = apex + Vector2((j - k * 0.5) * (2.0 * R + gap), -k * row_h)
			id += 1
	pos[CUE] = D_CENTRE + Vector2(-D_R * 0.35, D_R * 0.55)
	spin_basis = Basis.IDENTITY
	begin_shot()

func begin_shot() -> void:
	first_hit = -1
	potted.clear()

func reds_left() -> int:
	var n := 0
	for id in range(1, REDS + 1):
		if on[id]:
			n += 1
	return n

func copy() -> RefCounted:
	var c = get_script().new()
	c.pos = pos.duplicate()
	c.vel = vel.duplicate()
	c.roll = roll.duplicate()
	c.side = side.duplicate()
	c.on = on.duplicate()
	c.log_events = false
	return c

## The cue ball struck along `dir` at `speed` m/s, the tip `tip.x` of a
## radius right of centre (side) and `tip.y` above it (top; negative is
## screw). A tip at 0.4 above centre sends the ball off already rolling.
func strike(dir: Vector2, speed: float, tip: Vector2) -> void:
	begin_shot()
	var d := dir.normalized()
	var v := clampf(speed, 0.0, MAX_SPEED)
	var t := tip.limit_length(MAX_TIP)
	vel[CUE] = d * v
	roll[CUE] = d * v * 2.5 * t.y
	# Right-hand side turns the ball so its right flank runs forward; in this
	# frame that is a negative surface speed (see _cushion).
	side[CUE] = -2.5 * v * t.x

func moving() -> bool:
	for i in COUNT:
		if on[i] and _busy(i):
			return true
	return false

func _busy(i: int) -> bool:
	return vel[i].length_squared() > 0.0 or (roll[i] - vel[i]).length_squared() > 1e-8

## Runs until every ball has stopped, or `limit` seconds of play.
## A rehearsal may take a coarser step: collisions are resolved at their
## time of impact, so a step twice as long moves nothing through anything.
func settle(limit := 30.0, dt := DT) -> void:
	var t := 0.0
	while t < limit and moving():
		step(dt)
		t += dt

func step(dt: float) -> void:
	var busy: Array[int] = []
	for i in COUNT:
		if on[i] and _busy(i):
			busy.append(i)
	if busy.is_empty():
		return
	for i in busy:
		_cloth(i, dt)
		pos[i] += vel[i] * dt
		if i == CUE and log_events:
			_turn_basis(dt)
	# Only a moving ball can run into anything: each moving ball against
	# every ball, a pair of moving balls once.
	for i in busy:
		if not on[i] or vel[i].length_squared() == 0.0:
			continue
		for j in COUNT:
			if j == i or not on[j]:
				continue
			if j < i and vel[j].length_squared() > 0.0 and busy.has(j):
				continue
			_collide(i, j, dt)
	for i in busy:
		if on[i] and vel[i].length_squared() > 0.0:
			_cushions(i)
			_pockets(i)

## The cloth: slide until the contact point stops slipping, then roll.
func _cloth(i: int, dt: float) -> void:
	var v := vel[i]
	var w := roll[i]
	var u := v - w
	var slip := u.length()
	var grip := MU_SLIDE * G * dt
	if slip > grip * 3.5:
		var dir := u / slip
		v -= dir * grip
		w += dir * grip * 2.5
	else:
		# Rolling: the spin follows the travel, and the cloth's drag slows both.
		var s := v.length()
		var ns := s - MU_ROLL * G * dt
		if ns <= REST or s == 0.0:
			v = Vector2.ZERO
		else:
			v = v * (ns / s)
		w = v
	var sd := side[i]
	if sd != 0.0:
		var wear := SIDE_WEAR * dt
		side[i] = 0.0 if absf(sd) <= wear else sd - signf(sd) * wear
	if v == Vector2.ZERO and w == Vector2.ZERO:
		side[i] = 0.0
	vel[i] = v
	roll[i] = w

func _turn_basis(dt: float) -> void:
	var w := roll[CUE]
	var omega := Vector3(-w.y, w.x, side[CUE]) / R
	var a := omega.length() * dt
	if a > 0.0:
		spin_basis = (Basis(omega.normalized(), a) * spin_basis).orthonormalized()

func _collide(i: int, j: int, dt: float) -> void:
	var d := pos[j] - pos[i]
	var dist2 := d.length_squared()
	var reach := 2.0 * R
	if dist2 >= reach * reach:
		return
	var rv := vel[j] - vel[i]
	# Back both balls up to the moment they touched, so the contact normal is
	# the true one and not wherever the step happened to leave them.
	var back := 0.0
	var a := rv.length_squared()
	if a > 0.0:
		var b := 2.0 * d.dot(rv)
		var c := dist2 - reach * reach
		var disc := b * b - 4.0 * a * c
		if disc >= 0.0:
			back = clampf((b + sqrt(disc)) / (2.0 * a), 0.0, dt)
	pos[i] -= vel[i] * back
	pos[j] -= vel[j] * back
	d = pos[j] - pos[i]
	var dist := d.length()
	if dist == 0.0:
		d = Vector2(1.0, 0.0)
		dist = 1.0
	var n := d / dist
	var approach := (vel[i] - vel[j]).dot(n)
	if approach > 0.0:
		var jn := approach * (1.0 + E_BALL) * 0.5
		vel[i] -= n * jn
		vel[j] += n * jn
		if log_events:
			events.append({"kind": "ball", "speed": approach, "at": pos[i] + n * R, "id": j})
		if first_hit == -1:
			if i == CUE:
				first_hit = j
			elif j == CUE:
				first_hit = i
	pos[i] += vel[i] * back
	pos[j] += vel[j] * back
	# Whatever overlap is left (a cluster pressed together) is pushed apart.
	d = pos[j] - pos[i]
	dist = d.length()
	if dist < reach and dist > 0.0:
		var push := (reach - dist) * 0.5
		pos[i] -= d / dist * push
		pos[j] += d / dist * push

func _cushions(i: int) -> void:
	var p := pos[i]
	for seg in segments:
		var a: Vector2 = seg[0]
		var b: Vector2 = seg[1]
		var ab := b - a
		var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		var q := a + ab * t
		var off := p - q
		var dist2 := off.length_squared()
		if dist2 >= R * R or dist2 == 0.0:
			continue
		var n := off / sqrt(dist2)
		var vn := vel[i].dot(n)
		p = q + n * R
		if vn >= 0.0:
			continue
		_cushion(i, n, vn)
	pos[i] = p

## A cushion's rebound: the normal speed comes back at E_CUSHION, the roll
## is turned the same way (so a rolling ball leaves nearly rolling), and side
## grips the rubber: its surface speed at the contact runs along the
## cushion, the cushion drags against it, and the ball is pushed the other
## way along the rail -- running side widens the angle, check side narrows it.
func _cushion(i: int, n: Vector2, vn: float) -> void:
	var v := vel[i] - n * vn * (1.0 + E_CUSHION)
	var w := roll[i]
	var wn := w.dot(n)
	if wn < 0.0:
		w -= n * wn * (1.0 + E_CUSHION)
	var along := Vector2(-n.y, n.x)
	v += along * side[i] * SIDE_GRIP
	side[i] *= SIDE_KEEP
	vel[i] = v
	roll[i] = w
	if log_events:
		events.append({"kind": "cushion", "speed": -vn, "at": pos[i] - n * R, "id": i})

func _pockets(i: int) -> void:
	var p := pos[i]
	for k in pockets.size():
		var pk: Dictionary = pockets[k]
		var rel: Vector2 = p - pk.at
		var out: Vector2 = pk.out
		if rel.dot(out) > DROP and absf(rel.dot(Vector2(-out.y, out.x))) < float(pk.half) + R:
			_pot(i, k)
			return
	# Nothing leaves the table any other way; a ball that somehow got past
	# the rails is in whichever pocket is nearest.
	if p.x < -0.25 or p.x > W + 0.25 or p.y < -0.25 or p.y > L + 0.25:
		var best := 0
		for k in pockets.size():
			if p.distance_to(pockets[k].at) < p.distance_to(pockets[best].at):
				best = k
		_pot(i, best)

func _pot(i: int, k: int) -> void:
	on[i] = false
	if log_events:
		events.append({"kind": "pot", "speed": vel[i].length(), "at": pockets[k].at, "from": pos[i], "id": i, "pocket": k})
	vel[i] = Vector2.ZERO
	roll[i] = Vector2.ZERO
	side[i] = 0.0
	potted.append(i)

## The cushion faces between the pockets and the jaws that run back into
## them; corners cut on the diagonal, the middles straight out.
func _build_table() -> void:
	var c := CORNER
	var m := MIDDLE
	var h := L * 0.5
	var diag := Vector2(1.0, 1.0).normalized() * JAW
	segments = [
		[Vector2(c, 0.0), Vector2(W - c, 0.0)],
		[Vector2(c, L), Vector2(W - c, L)],
		[Vector2(0.0, c), Vector2(0.0, h - m)],
		[Vector2(0.0, h + m), Vector2(0.0, L - c)],
		[Vector2(W, c), Vector2(W, h - m)],
		[Vector2(W, h + m), Vector2(W, L - c)],
		# corner jaws
		[Vector2(c, 0.0), Vector2(c, 0.0) + Vector2(-diag.x, -diag.y)],
		[Vector2(0.0, c), Vector2(0.0, c) + Vector2(-diag.x, -diag.y)],
		[Vector2(W - c, 0.0), Vector2(W - c, 0.0) + Vector2(diag.x, -diag.y)],
		[Vector2(W, c), Vector2(W, c) + Vector2(diag.x, -diag.y)],
		[Vector2(c, L), Vector2(c, L) + Vector2(-diag.x, diag.y)],
		[Vector2(0.0, L - c), Vector2(0.0, L - c) + Vector2(-diag.x, diag.y)],
		[Vector2(W - c, L), Vector2(W - c, L) + Vector2(diag.x, diag.y)],
		[Vector2(W, L - c), Vector2(W, L - c) + Vector2(diag.x, diag.y)],
		# middle jaws, opening a touch as they go back
		[Vector2(0.0, h - m), Vector2(-JAW, h - m - 0.006)],
		[Vector2(0.0, h + m), Vector2(-JAW, h + m + 0.006)],
		[Vector2(W, h - m), Vector2(W + JAW, h - m - 0.006)],
		[Vector2(W, h + m), Vector2(W + JAW, h + m + 0.006)],
	]
	var half_c := c * sqrt(2.0) * 0.5
	var s2 := sqrt(0.5)
	pockets = [
		{"at": Vector2(c * 0.5, c * 0.5), "out": Vector2(-s2, -s2), "half": half_c},
		{"at": Vector2(W - c * 0.5, c * 0.5), "out": Vector2(s2, -s2), "half": half_c},
		{"at": Vector2(0.0, h), "out": Vector2(-1.0, 0.0), "half": m},
		{"at": Vector2(W, h), "out": Vector2(1.0, 0.0), "half": m},
		{"at": Vector2(c * 0.5, L - c * 0.5), "out": Vector2(-s2, s2), "half": half_c},
		{"at": Vector2(W - c * 0.5, L - c * 0.5), "out": Vector2(s2, s2), "half": half_c},
	]

# --- placing balls ---

## Whether a ball could stand at `p` without touching another (ignoring `skip`).
func free_at(p: Vector2, skip := -1) -> bool:
	for i in COUNT:
		if i == skip or not on[i]:
			continue
		if pos[i].distance_squared_to(p) < 4.0 * R * R * 1.0004:
			return false
	return true

## A potted colour back on the table: its own spot, else the highest spot
## that is free (black first), else as near its own spot as it will go on
## the line from there to the top cushion, else below it.
func respot(id: int) -> void:
	var own: Vector2 = SPOTS[id]
	var at := own
	if not free_at(own, id):
		at = Vector2.INF
		for other in [BLACK, PINK, BLUE, BROWN, GREEN, YELLOW]:
			if free_at(SPOTS[other], id):
				at = SPOTS[other]
				break
		if at == Vector2.INF:
			var y := own.y
			while y > R and at == Vector2.INF:
				y -= 0.002
				if free_at(Vector2(own.x, y), id):
					at = Vector2(own.x, y)
			y = own.y
			while y < L - R and at == Vector2.INF:
				y += 0.002
				if free_at(Vector2(own.x, y), id):
					at = Vector2(own.x, y)
	pos[id] = at
	vel[id] = Vector2.ZERO
	roll[id] = Vector2.ZERO
	side[id] = 0.0
	on[id] = true

## Whether `p` is a legal place for the cue ball in hand: on or inside the D.
static func in_d(p: Vector2) -> bool:
	return p.y >= BAULK_Y and p.distance_to(D_CENTRE) <= D_R

## Clamps `p` into the D.
static func clamp_d(p: Vector2) -> Vector2:
	var q := Vector2(p.x, maxf(p.y, BAULK_Y))
	var off := q - D_CENTRE
	if off.length() > D_R:
		q = D_CENTRE + off.normalized() * D_R
	return q

# --- geometry the aim line and the computer both need ---

## The first thing a ball travelling from `from` along `dir` would touch:
## {"t": distance, "id": ball id or -1 for a cushion, "at": centre at
## contact, "normal": contact normal}. Ignores `skip`.
func cast(from: Vector2, dir: Vector2, skip := CUE) -> Dictionary:
	var best := {"t": INF, "id": -1, "at": from, "normal": Vector2.ZERO}
	for i in COUNT:
		if i == skip or not on[i]:
			continue
		var t := _ray_circle(from, dir, pos[i], 2.0 * R)
		if t < best.t:
			var at := from + dir * t
			best = {"t": t, "id": i, "at": at, "normal": (pos[i] - at).normalized()}
	for seg in segments:
		var hit := _ray_capsule(from, dir, seg[0], seg[1], R)
		if hit.t < best.t:
			best = {"t": hit.t, "id": -1, "at": from + dir * hit.t, "normal": hit.normal}
	return best

static func _ray_circle(o: Vector2, d: Vector2, c: Vector2, r: float) -> float:
	var oc := o - c
	var b := oc.dot(d)
	var cc := oc.length_squared() - r * r
	var disc := b * b - cc
	if disc < 0.0:
		return INF
	var t := -b - sqrt(disc)
	return t if t >= 0.0 else INF

static func _ray_capsule(o: Vector2, d: Vector2, a: Vector2, b: Vector2, r: float) -> Dictionary:
	var best := {"t": INF, "normal": Vector2.ZERO}
	var ab := b - a
	var n := Vector2(-ab.y, ab.x).normalized()
	for side_n in [n, -n]:
		var denom: float = d.dot(side_n)
		if denom >= 0.0:
			continue
		var t: float = (r - (o - a).dot(side_n)) / denom
		if t < 0.0:
			continue
		var p := o + d * t
		var u := (p - a).dot(ab) / ab.length_squared()
		if u >= 0.0 and u <= 1.0 and t < best.t:
			best = {"t": t, "normal": side_n}
	for e in [a, b]:
		var t := _ray_circle(o, d, e, r)
		if t < best.t:
			best = {"t": t, "normal": (o + d * t - e).normalized()}
	return best

## Whether a ball could travel straight from `a` to `b` without touching any
## ball but those in `skip`.
func lane_clear(a: Vector2, b: Vector2, skip: Array) -> bool:
	var ab := b - a
	var len2 := ab.length_squared()
	if len2 == 0.0:
		return true
	for i in COUNT:
		if not on[i] or skip.has(i):
			continue
		var t := clampf((pos[i] - a).dot(ab) / len2, 0.0, 1.0)
		if (a + ab * t).distance_squared_to(pos[i]) < 4.0 * R * R * 0.999:
			return false
	return true
