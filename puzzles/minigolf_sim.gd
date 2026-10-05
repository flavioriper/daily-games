extends RefCounted

## Mini Golf's physics, scene-free: one hole and the ball on it.
##
## The field is W by H units, y down. A hole's green is a set of squares on a
## COLS by ROWS grid (CELL a side, from ORIGIN); its edge is the kerb, and a
## corner named in `cuts` is cut across at 45 degrees, which is what a bank
## shot turns on. On the green stand blocks (kerb-high boxes), posts (round
## bumpers that kick the ball away), sand (the ball drags), water (the ball
## is fished out and put back where it was struck from; the putt stands),
## slopes (a square that pushes the ball one way) and, on Insane, gates: a
## gate is shut on every other putt and swaps when the ball stops.
##
## A putt is an angle and a power in 0..1. Everything it does runs through
## step(), fixed at DT, so the guide, the hint and the miner play a putt on
## a clone() and see exactly where it goes.
##
## A hole is plain data (content/minigolf.json holds mined ones):
##   {"cells": [c + r * COLS, ...], "cuts": [cell * 4 + corner, ...],
##    "tee": [x, y], "cup": [x, y], "blocks": [[x, y, hw, hh, turn], ...],
##    "posts": [[x, y, r], ...], "sand": [[x, y, rx, ry], ...],
##    "water": [[x, y, rx, ry], ...], "slopes": [[cell, dir], ...],
##    "gates": [[x0, y0, x1, y1, phase], ...], "par": n, "proof": [[a, u], ...]}
## corner 0..3 is top-left, top-right, bottom-right, bottom-left; dir 0..3 is
## east, south, west, north; a gate is shut while `parity` equals its phase.

const W := 82.0
const H := 116.0
const COLS := 4
const ROWS := 6
const CELL := 18.0
const ORIGIN := Vector2(5.0, 4.0)
const BALL_R := 1.7
const CUP_R := 3.3
## How far along each kerb a cut corner starts.
const CHAMFER := 7.0
const DT := 1.0 / 120.0
## A putt leaves between V_MIN and V_MAX; the green takes FRICTION off every
## second and DRAG of the speed besides, sand SAND times the first.
const V_MIN := 24.0
const V_MAX := 118.0
const FRICTION := 26.0
const DRAG := 0.45
const SAND := 5.0
const SLOPE := 44.0
## What a kerb and a post give back of the speed along the hit; a post never
## sends the ball off slower than POST_KICK.
const WALL_BOUNCE := 0.62
const POST_BOUNCE := 0.95
const POST_KICK := 40.0
## A ball over the cup under CAPTURE_V drops; faster, it rims out (bent
## toward the middle and slowed). A slow ball inside FUNNEL_R rolls in.
const CAPTURE_V := 56.0
const LIP_KEEP := 0.8
const LIP_PULL := 0.2
const FUNNEL_R := 4.6
const FUNNEL_V := 30.0
const FUNNEL_PULL := 60.0
const STOP_V := 2.2
const STOP_TIME := 0.2
const SHOT_CAP := 12.0
const DIRS := [Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0), Vector2(0, -1)]
## The kerbs are looked up through squares of BUCKET units.
const BUCKET := 6.0
const GW := 14
const GH := 20
## The way to the cup is counted over squares of FIELD units.
const FIELD := 2.0
const FW := 41
const FH := 58
const FAR := 9999.0

# --- the hole, shared by every clone ---
var hole: Dictionary = {}
var cells := PackedByteArray()
var cuts := PackedInt32Array()
var seg_a := PackedVector2Array()
var seg_ab := PackedVector2Array()
var seg_inv := PackedFloat32Array()
## -1 for a kerb, else the gate this stretch belongs to.
var seg_gate := PackedInt32Array()
var gate_phase := PackedInt32Array()
var gate_a := PackedVector2Array()
var gate_b := PackedVector2Array()
var buckets: Array = []
var posts := PackedVector3Array()
var sand := PackedFloat32Array()
var water := PackedFloat32Array()
## Per square: 0 flat, else 1 + the way it pushes.
var slope := PackedByteArray()
var blocks: Array = []
var tee := Vector2.ZERO
var cup := Vector2.ZERO
var par := 0
var proof: Array = []
## Steps to the cup from each FIELD square over the green, -1 off it.
var field := PackedInt32Array()

# --- the ball ---
var p := Vector2.ZERO
var v := Vector2.ZERO
## Where the ball lay before the putt: water puts it back there.
var lie := Vector2.ZERO
var strokes := 0
## The gates whose phase this is are shut.
var parity := 0
var rolling := false
var sunk := false
## The last putt ended in the water (or off the green).
var wet := false
var time := 0.0
var slow := 0.0
var in_sand := false
var lipped := false
## The kerbs, blocks, gates and posts this putt has come off.
var hits := 0

# --- the hole ---

static func cell_rect(i: int) -> Rect2:
	return Rect2(ORIGIN + Vector2(i % COLS, i / COLS) * CELL, Vector2(CELL, CELL))

static func cell_mid(i: int) -> Vector2:
	return ORIGIN + (Vector2(i % COLS, i / COLS) + Vector2(0.5, 0.5)) * CELL

## The square under `at`, -1 off the grid.
static func cell_of(at: Vector2) -> int:
	var c := int(floorf((at.x - ORIGIN.x) / CELL))
	var r := int(floorf((at.y - ORIGIN.y) / CELL))
	if c < 0 or r < 0 or c >= COLS or r >= ROWS:
		return -1
	return c + r * COLS

func green(c: int, r: int) -> bool:
	return c >= 0 and r >= 0 and c < COLS and r < ROWS and cells[c + r * COLS] == 1

## A cut corner's two ends: [on the level kerb, on the upright kerb].
static func cut_ends(id: int) -> Array:
	var i := id / 4
	var k := id % 4
	var rect := cell_rect(i)
	var corner := rect.position + Vector2(CELL if k == 1 or k == 2 else 0.0, CELL if k >= 2 else 0.0)
	var dx := -1.0 if k == 1 or k == 2 else 1.0
	var dy := -1.0 if k >= 2 else 1.0
	return [corner + Vector2(dx * CHAMFER, 0.0), corner + Vector2(0.0, dy * CHAMFER), corner]

func setup(h: Dictionary) -> void:
	hole = h
	cells = PackedByteArray()
	cells.resize(COLS * ROWS)
	for i in h.get("cells", []):
		if int(i) >= 0 and int(i) < cells.size():
			cells[int(i)] = 1
	cuts = PackedInt32Array()
	for id in h.get("cuts", []):
		cuts.append(int(id))
	tee = _v2(h.get("tee", [41, 100]))
	cup = _v2(h.get("cup", [41, 30]))
	par = int(h.get("par", 0))
	proof = h.get("proof", [])
	blocks = h.get("blocks", [])
	posts = PackedVector3Array()
	for q in h.get("posts", []):
		posts.append(Vector3(float(q[0]), float(q[1]), float(q[2])))
	sand = _flat4(h.get("sand", []))
	water = _flat4(h.get("water", []))
	slope = PackedByteArray()
	slope.resize(COLS * ROWS)
	for q in h.get("slopes", []):
		slope[int(q[0])] = 1 + int(q[1])
	seg_a = PackedVector2Array()
	seg_ab = PackedVector2Array()
	seg_inv = PackedFloat32Array()
	seg_gate = PackedInt32Array()
	_kerbs()
	for id in cuts:
		var e := cut_ends(id)
		_seg(e[0], e[1], -1)
	for q in blocks:
		var pts := block_points(q)
		for k in 4:
			_seg(pts[k], pts[(k + 1) % 4], -1)
	gate_phase = PackedInt32Array()
	gate_a = PackedVector2Array()
	gate_b = PackedVector2Array()
	for q in h.get("gates", []):
		var a := Vector2(float(q[0]), float(q[1]))
		var b := Vector2(float(q[2]), float(q[3]))
		_seg(a, b, gate_phase.size())
		gate_a.append(a)
		gate_b.append(b)
		gate_phase.append(int(q[4]))
	_bucket()
	_field()
	tee_up()

## The ball back on the tee, the hole unplayed.
func tee_up() -> void:
	p = tee
	v = Vector2.ZERO
	lie = tee
	strokes = 0
	parity = 0
	rolling = false
	sunk = false
	wet = false
	time = 0.0
	slow = 0.0
	in_sand = false
	lipped = false

static func _v2(a) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))

static func _flat4(rows: Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for q in rows:
		for k in 4:
			out.append(float(q[k]))
	return out

## A block's four corners.
static func block_points(q: Array) -> PackedVector2Array:
	var mid := Vector2(float(q[0]), float(q[1]))
	var hw := float(q[2])
	var hh := float(q[3])
	var turn := float(q[4])
	var out := PackedVector2Array()
	for c: Vector2 in [Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, hh), Vector2(-hw, hh)]:
		out.append(mid + c.rotated(turn))
	return out

func _seg(a: Vector2, b: Vector2, gate: int) -> void:
	var ab := b - a
	var l2 := ab.length_squared()
	if l2 < 1e-6:
		return
	seg_a.append(a)
	seg_ab.append(ab)
	seg_inv.append(1.0 / l2)
	seg_gate.append(gate)

## The green's edge: every side of a square with no green beyond it, the
## runs along one line joined.
func _kerbs() -> void:
	for r in ROWS + 1:
		for side in 2:
			# side 0: the green is under the line; 1: over it
			var from := -1
			for c in COLS + 1:
				var on := green(c, r) and not green(c, r - 1) if side == 0 else green(c, r - 1) and not green(c, r)
				if on and from < 0:
					from = c
				elif not on and from >= 0:
					_seg(ORIGIN + Vector2(from, r) * CELL, ORIGIN + Vector2(c, r) * CELL, -1)
					from = -1
	for c in COLS + 1:
		for side in 2:
			var from := -1
			for r in ROWS + 1:
				var on := green(c, r) and not green(c - 1, r) if side == 0 else green(c - 1, r) and not green(c, r)
				if on and from < 0:
					from = r
				elif not on and from >= 0:
					_seg(ORIGIN + Vector2(c, from) * CELL, ORIGIN + Vector2(c, r) * CELL, -1)
					from = -1

func _bucket() -> void:
	buckets = []
	buckets.resize(GW * GH)
	for i in buckets.size():
		buckets[i] = PackedInt32Array()
	var pad := BALL_R + 1.2
	for i in seg_a.size():
		var a := seg_a[i]
		var b := a + seg_ab[i]
		var x0 := clampi(int(floorf((minf(a.x, b.x) - pad) / BUCKET)), 0, GW - 1)
		var x1 := clampi(int(floorf((maxf(a.x, b.x) + pad) / BUCKET)), 0, GW - 1)
		var y0 := clampi(int(floorf((minf(a.y, b.y) - pad) / BUCKET)), 0, GH - 1)
		var y1 := clampi(int(floorf((maxf(a.y, b.y) + pad) / BUCKET)), 0, GH - 1)
		for y in range(y0, y1 + 1):
			for x in range(x0, x1 + 1):
				var list: PackedInt32Array = buckets[x + y * GW]
				list.append(i)
				buckets[x + y * GW] = list

## Whether a ball's middle may lie at `at`: on the green, off the water, out
## of every block and post, clear of the cut corners.
func open_at(at: Vector2, pad := BALL_R) -> bool:
	var i := cell_of(at)
	if i < 0 or cells[i] == 0:
		return false
	if in_water(at):
		return false
	for q in blocks:
		var d := (at - Vector2(float(q[0]), float(q[1]))).rotated(-float(q[4]))
		if absf(d.x) < float(q[2]) + pad and absf(d.y) < float(q[3]) + pad:
			return false
	for q in posts:
		if at.distance_squared_to(Vector2(q.x, q.y)) < (q.z + pad) * (q.z + pad):
			return false
	for id in cuts:
		if id / 4 != i:
			continue
		var e := cut_ends(id)
		var corner: Vector2 = e[2]
		var d := (at - corner).abs()
		if d.x + d.y < CHAMFER + pad * 1.42:
			return false
	return true

func in_water(at: Vector2) -> bool:
	var k := 0
	while k < water.size():
		var dx := (at.x - water[k]) / water[k + 2]
		var dy := (at.y - water[k + 1]) / water[k + 3]
		if dx * dx + dy * dy < 1.0:
			return true
		k += 4
	return false

func in_sand_at(at: Vector2) -> bool:
	var k := 0
	while k < sand.size():
		var dx := (at.x - sand[k]) / sand[k + 2]
		var dy := (at.y - sand[k + 1]) / sand[k + 3]
		if dx * dx + dy * dy < 1.0:
			return true
		k += 4
	return false

## The way to the cup, counted out from it over the open squares (the gates
## taken as open).
func _field() -> void:
	field = PackedInt32Array()
	field.resize(FW * FH)
	field.fill(-1)
	var open := PackedByteArray()
	open.resize(FW * FH)
	for y in FH:
		for x in FW:
			if open_at(Vector2(x + 0.5, y + 0.5) * FIELD, BALL_R * 0.6):
				open[x + y * FW] = 1
	var start := clampi(int(cup.x / FIELD), 0, FW - 1) + clampi(int(cup.y / FIELD), 0, FH - 1) * FW
	open[start] = 1
	field[start] = 0
	var queue := PackedInt32Array([start])
	var head := 0
	while head < queue.size():
		var at := queue[head]
		head += 1
		var x := at % FW
		var y := at / FW
		var d := field[at] + 1
		if x > 0 and open[at - 1] == 1 and field[at - 1] < 0:
			field[at - 1] = d
			queue.append(at - 1)
		if x < FW - 1 and open[at + 1] == 1 and field[at + 1] < 0:
			field[at + 1] = d
			queue.append(at + 1)
		if y > 0 and open[at - FW] == 1 and field[at - FW] < 0:
			field[at - FW] = d
			queue.append(at - FW)
		if y < FH - 1 and open[at + FW] == 1 and field[at + FW] < 0:
			field[at + FW] = d
			queue.append(at + FW)

## How far `at` is from the cup going round the kerbs, in field units; FAR
## where there is no way.
func way(at: Vector2) -> float:
	var x := clampi(int(at.x / FIELD), 0, FW - 1)
	var y := clampi(int(at.y / FIELD), 0, FH - 1)
	var best := -1
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var xx := x + dx
			var yy := y + dy
			if xx < 0 or yy < 0 or xx >= FW or yy >= FH:
				continue
			var d := field[xx + yy * FW]
			if d >= 0 and (best < 0 or d < best):
				best = d
	if best < 0:
		return FAR
	return float(best) * FIELD + minf(at.distance_to(cup), FIELD * 2.0) * 0.25

func gate_shut(g: int) -> bool:
	return gate_phase[g] == parity

# --- the ball ---

static func speed_of(power: float) -> float:
	return lerpf(V_MIN, V_MAX, clampf(power, 0.0, 1.0))

## Strikes the ball. False while it rolls or once it is in the cup.
func putt(angle: float, power: float) -> bool:
	if rolling or sunk:
		return false
	lie = p
	v = Vector2.from_angle(angle) * speed_of(power)
	strokes += 1
	rolling = true
	wet = false
	time = 0.0
	slow = 0.0
	lipped = false
	hits = 0
	return true

## One DT of the roll. True while the ball still moves. `events` (or null)
## takes what happened: ["wall", at, speed], ["post", at, index], ["sand",
## at], ["lip", at], ["sunk", at], ["splash", at], ["stop", at].
func step(events = null) -> bool:
	if not rolling:
		return false
	time += DT
	var ci := cell_of(p)
	if ci < 0 or cells[ci] == 0:
		_drown(events)
		return false
	var pushed := false
	var sd := slope[ci]
	if sd > 0:
		v += DIRS[sd - 1] * (SLOPE * DT)
		pushed = true
	var mult := 1.0
	if sand.size() > 0:
		var now := in_sand_at(p)
		if now:
			mult = SAND
			if not in_sand and events != null:
				events.append(["sand", p])
		in_sand = now
	var speed := v.length()
	var drop := (FRICTION * mult + DRAG * speed) * DT
	if speed <= drop:
		v = Vector2.ZERO
		speed = 0.0
	else:
		v *= (speed - drop) / speed
		speed -= drop
	# the cup
	var to := cup - p
	var d2 := to.length_squared()
	if d2 < CUP_R * CUP_R:
		if speed < CAPTURE_V:
			p = cup
			v = Vector2.ZERO
			rolling = false
			sunk = true
			if events != null:
				events.append(["sunk", cup])
			return false
		if not lipped:
			lipped = true
			v = v * LIP_KEEP + to.normalized() * (speed * LIP_PULL)
			if events != null:
				events.append(["lip", p])
	else:
		if d2 > (CUP_R + 0.6) * (CUP_R + 0.6):
			lipped = false
		if d2 < FUNNEL_R * FUNNEL_R and speed < FUNNEL_V:
			v += to * (FUNNEL_PULL * DT / sqrt(d2))
			pushed = true
	p += v * DT
	# the kerbs, the blocks and the shut gates
	var bx := clampi(int(p.x / BUCKET), 0, GW - 1)
	var by := clampi(int(p.y / BUCKET), 0, GH - 1)
	var near: PackedInt32Array = buckets[bx + by * GW]
	for i in near:
		var g := seg_gate[i]
		if g >= 0 and gate_phase[g] != parity:
			continue
		var a := seg_a[i]
		var ab := seg_ab[i]
		var q := a + ab * clampf((p - a).dot(ab) * seg_inv[i], 0.0, 1.0)
		var d := p - q
		var l2 := d.length_squared()
		if l2 >= BALL_R * BALL_R:
			continue
		var n := d / sqrt(l2) if l2 > 1e-9 else Vector2(-ab.y, ab.x).normalized()
		p = q + n * BALL_R
		var vn := v.dot(n)
		if vn < 0.0:
			v -= n * ((1.0 + WALL_BOUNCE) * vn)
			if vn < -6.0:
				hits += 1
				if events != null:
					events.append(["gate" if g >= 0 else "wall", q, -vn])
	for k in posts.size():
		var post := posts[k]
		var c := Vector2(post.x, post.y)
		var d := p - c
		var reach := post.z + BALL_R
		var l2 := d.length_squared()
		if l2 >= reach * reach:
			continue
		var n := d / sqrt(l2) if l2 > 1e-9 else Vector2(0.0, 1.0)
		p = c + n * reach
		var vn := v.dot(n)
		if vn < 0.0:
			v -= n * ((1.0 + POST_BOUNCE) * vn)
			var out := v.dot(n)
			if out < POST_KICK:
				v += n * (POST_KICK - out)
			hits += 1
			if events != null:
				events.append(["post", c, k])
	if water.size() > 0 and in_water(p):
		_drown(events)
		return false
	speed = v.length()
	if speed < STOP_V:
		slow += DT
		if not pushed or slow >= STOP_TIME:
			_rest(events)
			return false
	else:
		slow = 0.0
	if time > SHOT_CAP:
		_rest(events)
		return false
	return true

func _rest(events) -> void:
	v = Vector2.ZERO
	rolling = false
	parity = strokes % 2
	_clear_gates()
	if events != null:
		events.append(["stop", p])

## Out of the water and back to the lie; the putt stands.
func _drown(events) -> void:
	if events != null:
		events.append(["splash", p])
	p = lie
	v = Vector2.ZERO
	rolling = false
	wet = true
	parity = strokes % 2
	_clear_gates()

## A gate that shuts on the ball nudges it to the side it is on.
func _clear_gates() -> void:
	for g in gate_phase.size():
		if gate_phase[g] != parity:
			continue
		var a := gate_a[g]
		var ab := gate_b[g] - a
		var q := a + ab * clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		var d := p - q
		var l := d.length()
		if l < BALL_R:
			var n := d / l if l > 1e-6 else Vector2(-ab.y, ab.x).normalized()
			p = q + n * (BALL_R + 0.05)

## The roll played out to its end.
func run() -> void:
	while step():
		pass

func clone():
	var c = get_script().new()
	c.hole = hole
	c.cells = cells
	c.cuts = cuts
	c.seg_a = seg_a
	c.seg_ab = seg_ab
	c.seg_inv = seg_inv
	c.seg_gate = seg_gate
	c.gate_phase = gate_phase
	c.gate_a = gate_a
	c.gate_b = gate_b
	c.buckets = buckets
	c.posts = posts
	c.sand = sand
	c.water = water
	c.slope = slope
	c.blocks = blocks
	c.tee = tee
	c.cup = cup
	c.par = par
	c.proof = proof
	c.field = field
	c.p = p
	c.v = v
	c.lie = lie
	c.strokes = strokes
	c.parity = parity
	c.rolling = rolling
	c.sunk = sunk
	c.wet = wet
	c.time = time
	c.slow = slow
	c.in_sand = in_sand
	c.lipped = lipped
	c.hits = hits
	return c

# --- looking ahead ---

## Where a putt would roll: a point every `gap` units for `length` units of
## the way (the whole way when `length` is 0), on a copy.
func guide(angle: float, power: float, length: float, gap: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var c = clone()
	if not c.putt(angle, power):
		return out
	var gone := 0.0
	var next := gap
	var last: Vector2 = c.p
	while c.step():
		gone += last.distance_to(c.p)
		last = c.p
		if gone >= next:
			out.append(last)
			next += gap
		if length > 0.0 and gone >= length:
			break
	if c.sunk:
		out.append(c.cup)
	return out

## What a putt from here comes to: [worth, sunk]. In the cup is worth
## SUNK_WORTH; else whatever leaves the ball nearest by the way round, and
## the water is worth less than staying put.
const SUNK_WORTH := 30.0
const BANK_COST := 1.5

func try_putt(angle: float, power: float, banks := -1) -> Array:
	var c = clone()
	c.putt(angle, power)
	c.run()
	if banks >= 0 and c.hits > banks:
		return [-FAR, false]
	# of two putts that do the same, the one off fewer kerbs
	var fuss := float(c.hits) * BANK_COST
	if c.sunk:
		return [SUNK_WORTH - fuss, true]
	if c.wet:
		return [-way(p) - 40.0, false]
	return [-c.way(c.p) - fuss, false]

const OFF := [Vector2(0.035, 0.0), Vector2(-0.035, 0.0), Vector2(0.0, 0.06), Vector2(0.0, -0.06)]

## How many of the four putts just off (angle, power) also drop.
func steady(angle: float, power: float) -> int:
	var n := 0
	for q: Vector2 in OFF:
		if try_putt(angle + q.x, power + q.y)[1]:
			n += 1
	return n

## The putt to take from here: {"a", "u", "sunk"}. Every `angles`-th of a
## turn at `powers` strengths, the best few looked at more closely, and of
## the best dozen the one worth most with a hand that is a little off: a
## steady good putt over a lucky great one. With `banks` 0 or more, a putt
## that comes off more kerbs than that is not looked at (the miner's decent
## hand plans one bank at most).
func best_shot(angles := 72, powers := 7, banks := -1) -> Dictionary:
	var found: Array = []
	for ai in angles:
		var a := TAU * float(ai) / float(angles)
		for ui in powers:
			var u := 0.16 + 0.84 * float(ui) / float(powers - 1)
			var got := try_putt(a, u, banks)
			found.append([float(got[0]), a, u, bool(got[1])])
	found.sort_custom(func(x, y): return x[0] > y[0])
	var step_a := TAU / float(angles)
	var step_u := 0.84 / float(powers - 1)
	var close: Array = []
	for k in mini(5, found.size()):
		var from: Array = found[k]
		for da in [-0.5, -0.25, 0.25, 0.5]:
			for du in [-0.4, 0.0, 0.4]:
				var a: float = from[1] + da * step_a
				var u := clampf(from[2] + du * step_u, 0.05, 1.0)
				var got := try_putt(a, u, banks)
				close.append([float(got[0]), a, u, bool(got[1])])
	found = found.slice(0, 12) + close
	found.sort_custom(func(x, y): return x[0] > y[0])
	var best: Array = found[0]
	var top := -INF
	for row: Array in found.slice(0, 12):
		var worth: float = row[0]
		for q: Vector2 in OFF:
			worth += maxf(-200.0, float(try_putt(row[1] + q.x, clampf(row[2] + q.y, 0.03, 1.0))[0]))
		if worth > top:
			top = worth
			best = row
	return {"a": wrapf(best[1], -PI, PI), "u": best[2], "sunk": best[3]}
