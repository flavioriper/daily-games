extends RefCounted

## Trestle's physics, pure data: a bridge of joints and members, and a cart
## that drives over it. Stepped at a fixed `DT` by whoever owns it -- the
## board on its clock, the miner and the probes as fast as they can -- so the
## same design gives the same crossing everywhere.
##
## Units are grid units (one lattice step) and seconds, y up. The left bank's
## road ends at (0, 0), the right bank's at (w, dy).
##
## **Members are XPBD distance constraints** (small steps: `SUB` substeps a
## step, one pass each), so each one measures its own force: the multiplier a
## substep needs is the force times h squared. Tension is positive. A member
## whose force, smoothed over `SMOOTH` seconds, passes its material's limit
## snaps: it is replaced by two stubs dangling from its ends, which carry
## nothing and never break. A rope pulls and never pushes.
##
## **The cart is a moving mass, not a wheeled body.** On a road member it
## lends its mass to the member's two joints in proportion to where it
## stands, so its weight goes into the bridge exactly as a load would, and it
## is drawn where the deflected deck puts it. At a member's end it takes the
## road member that carries straight on; with none, or when its member snaps,
## it flies and falls until it lands on a road or in the river.
##
## **A convoy** (after the solve) is more carts behind the first, each the
## same moving mass. The lead cart is the scalar fields below, exactly as a
## lone cart always was, so a one-cart run is the run the bank was proved
## on; the others live in `trail` and are driven by swapping each into those
## fields for its step (`_swap`). The test is over when every cart is over,
## or any is in the river.
## **Tea** (Insane's Tea Party, `level.tea`): the lead cart carries cups of
## tea filled to the brim. The tea's surface leans in its cup as a damped
## spring chasing the level, so a deck that tilts under the cart leans it
## and a sudden kink (a joint where the deck bends) sloshes it past even
## that. Past `TEA_RIM` it spills, and a spilled run never counts as over:
## the bridge must be stiff and level, not only strong.
## Spec: docs/superpowers/specs/2026-09-28-trestle-flat-design.md;
## docs/superpowers/specs/2026-10-01-trestle-polish-design.md for the tea.

const DT := 1.0 / 120.0
const SUB := 10
const G := 10.0
const DAMP := 0.6
## How long a member's force is smoothed over before it is judged: a jolt
## shorter than this does not snap a member, a load does.
const SMOOTH := 0.05
## Gravity (the structure's and the cart's) comes on over this long when the
## test starts, so a bridge is loaded, not dropped.
const RAMP := 0.6
const JOINT_MASS := 0.04
const CART_V := 1.6
const CART_START := -1.4
const CART_EXIT := 1.6
const WATER := -4.6
const BED := -6.0
const TIME_OUT := 30.0
## A convoy's carts set off this far apart (grid units), one behind another.
const CONVOY_GAP := 2.0

## The tea: how far its surface may lean against the cup's rim (radians),
## how fast it sloshes and how soon it settles.
const TEA_RIM := 0.03
const TEA_HZ := 1.4
const TEA_ZETA := 0.22

enum { ROAD, WOOD, ROPE }
## cost a unit of length, mass a unit, stiffness (EA), tension and
## compression limits. A rope's compression limit is never read.
const MATS := [
	{"cost": 200, "mass": 0.15, "ea": 2400.0, "t": 30.0, "c": 30.0},
	{"cost": 150, "mass": 0.08, "ea": 3200.0, "t": 44.0, "c": 36.0},
	{"cost": 120, "mass": 0.03, "ea": 2000.0, "t": 60.0, "c": 0.0},
]

enum { CART_BANK_L, CART_ROAD, CART_AIR, CART_BANK_R, CART_WATER, CART_OVER }

var w := 4
var dy := 0
var cart_mass := 1.0

# joints
var jp := PackedVector2Array()
var jv := PackedVector2Array()
var jm := PackedFloat32Array()
var jfix := PackedByteArray()
var home := PackedVector2Array()
var _prev := PackedVector2Array()
var _w := PackedFloat32Array()
var _key := {}

# members
var ma := PackedInt32Array()
var mb := PackedInt32Array()
var mrest := PackedFloat32Array()
var mmat := PackedInt32Array()
var malive := PackedByteArray()
var mstub := PackedByteArray()
## Smoothed force (tension +) and force over limit, 0..1+, for the stress view.
var mforce := PackedFloat32Array()
var mratio := PackedFloat32Array()
var mpeak := PackedFloat32Array()
## Which member of the design each member was built as (-1 for a stub).
var morigin := PackedInt32Array()
var _fsum := PackedFloat32Array()

# the cart
var cart := CART_BANK_L
var cart_seg := -1
var cart_from := -1
var cart_u := 0.0
var cart_pos := Vector2.ZERO
var cart_vel := Vector2.ZERO
var cart_angle := 0.0

## The carts behind the lead: [{cart, seg, from, u, pos, vel, angle}].
var trail: Array = []

## The tea's surface against its cup (radians, + toward the front), how
## fast it is moving, the most it leaned as a share of the rim, and whether
## it spilled.
var tea := false
var tea_lean := 0.0
var tea_spin := 0.0
var tea_peak := 0.0
var spilled := false

var t := 0.0
var broken: Array[int] = []
## What happened this step, drained by the owner: {"kind": "snap"|"land"|
## "splash"|"cross"|"leave"|"road", ...}.
var events: Array = []

## `design` is [{"a": Vector2i, "b": Vector2i, "m": int}], `anchors` grid
## points that never move.
func setup(level: Dictionary, design: Array, carts := 1) -> void:
	w = int(level.w)
	dy = int(level.get("dy", 0))
	cart_mass = float(level.cart)
	jp = PackedVector2Array()
	jv = PackedVector2Array()
	jm = PackedFloat32Array()
	jfix = PackedByteArray()
	_key = {}
	for a in level.anchors:
		var j := _joint(Vector2i(int(a[0]), int(a[1])))
		jfix[j] = 1
	ma = PackedInt32Array()
	mb = PackedInt32Array()
	mrest = PackedFloat32Array()
	mmat = PackedInt32Array()
	malive = PackedByteArray()
	mstub = PackedByteArray()
	mforce = PackedFloat32Array()
	mratio = PackedFloat32Array()
	mpeak = PackedFloat32Array()
	morigin = PackedInt32Array()
	for i in design.size():
		var d: Dictionary = design[i]
		var a := _joint(d.a)
		var b := _joint(d.b)
		_member(a, b, int(d.m), false, i)
		var half: float = MATS[int(d.m)].mass * mrest[mrest.size() - 1] * 0.5
		jm[a] += half
		jm[b] += half
	home = jp.duplicate()
	_prev = jp.duplicate()
	_w.resize(jp.size())
	_fsum.resize(ma.size())
	t = 0.0
	broken = []
	events = []
	cart = CART_BANK_L
	cart_seg = -1
	cart_from = -1
	cart_u = 0.0
	cart_pos = Vector2(CART_START, 0.0)
	cart_vel = Vector2(CART_V, 0.0)
	cart_angle = 0.0
	tea = bool(level.get("tea", false))
	tea_lean = 0.0
	tea_spin = 0.0
	tea_peak = 0.0
	spilled = false
	trail = []
	_crossed_told = false
	for i in range(1, carts):
		trail.append({"cart": CART_BANK_L, "seg": -1, "from": -1, "u": 0.0,
			"pos": Vector2(CART_START - CONVOY_GAP * i, 0.0), "vel": Vector2(CART_V, 0.0), "angle": 0.0})

## Trades the lead's fields with trail cart `i`'s; a second call trades back.
func _swap(i: int) -> void:
	var c: Dictionary = trail[i]
	var keep := {"cart": cart, "seg": cart_seg, "from": cart_from, "u": cart_u,
		"pos": cart_pos, "vel": cart_vel, "angle": cart_angle}
	cart = int(c.cart)
	cart_seg = int(c.seg)
	cart_from = int(c.from)
	cart_u = float(c.u)
	cart_pos = c.pos
	cart_vel = c.vel
	cart_angle = float(c.angle)
	trail[i] = keep

func _joint(p: Vector2i) -> int:
	if _key.has(p):
		return _key[p]
	var j := jp.size()
	_key[p] = j
	jp.append(Vector2(p))
	jv.append(Vector2.ZERO)
	jm.append(JOINT_MASS)
	jfix.append(0)
	return j

func _member(a: int, b: int, m: int, stub: bool, origin: int) -> void:
	ma.append(a)
	mb.append(b)
	mrest.append(jp[a].distance_to(jp[b]))
	mmat.append(m)
	malive.append(1)
	mstub.append(1 if stub else 0)
	mforce.append(0.0)
	mratio.append(0.0)
	mpeak.append(0.0)
	morigin.append(origin)

func joint_at(p: Vector2i) -> int:
	return _key.get(p, -1)

func done() -> bool:
	if t >= TIME_OUT or cart == CART_WATER or spilled:
		return true
	for c in trail:
		if int(c.cart) == CART_WATER:
			return true
	return crossed()

func crossed() -> bool:
	if cart != CART_OVER or spilled:
		return false
	for c in trail:
		if int(c.cart) != CART_OVER:
			return false
	return true

## How many carts are in the river.
func in_water() -> int:
	var n := 1 if cart == CART_WATER else 0
	for c in trail:
		if int(c.cart) == CART_WATER:
			n += 1
	return n

## One fixed step.
func step() -> void:
	t += DT
	var ramp := clampf(t / RAMP, 0.0, 1.0)
	var g := Vector2(0.0, -G * ramp)
	var h := DT / SUB
	var n := jp.size()
	# every cart's mass rides on its member's two joints
	var lent := {}
	_lend(lent, cart, cart_seg, cart_from, cart_u, ramp)
	for c in trail:
		_lend(lent, int(c.cart), int(c.seg), int(c.from), float(c.u), ramp)
	for j in n:
		if jfix[j] == 1:
			_w[j] = 0.0
		else:
			_w[j] = 1.0 / (jm[j] + float(lent.get(j, 0.0)))
	var nm := ma.size()
	for k in nm:
		_fsum[k] = 0.0
	var fade := exp(-DAMP * h)
	var h2 := h * h
	for _s in SUB:
		for j in n:
			if jfix[j] == 1:
				continue
			jv[j] += g * h
			_prev[j] = jp[j]
			jp[j] += jv[j] * h
		for k in nm:
			if malive[k] == 0:
				continue
			var a := ma[k]
			var b := mb[k]
			var wa := _w[a]
			var wb := _w[b]
			var ws := wa + wb
			if ws == 0.0:
				continue
			var d := jp[b] - jp[a]
			var l := d.length()
			if l < 1e-6:
				continue
			var c := l - mrest[k]
			var mat := mmat[k]
			if mat == ROPE and c < 0.0:
				continue
			var alpha: float = mrest[k] / MATS[mat].ea / h2
			var lam := -c / (ws + alpha)
			var nrm := d / l
			jp[a] -= nrm * (lam * wa)
			jp[b] += nrm * (lam * wb)
			_fsum[k] -= lam / h2
		for j in n:
			if jfix[j] == 1:
				continue
			var v := (jp[j] - _prev[j]) / h * fade
			if jp[j].y < BED:
				jp[j].y = BED
				v = Vector2(v.x * 0.5, maxf(v.y, 0.0))
			jv[j] = v
	var keep := 1.0 - exp(-DT / SMOOTH)
	for k in nm:
		if malive[k] == 0 or mstub[k] == 1:
			continue
		var f := _fsum[k] / SUB
		mforce[k] += (f - mforce[k]) * keep
		var mat: Dictionary = MATS[mmat[k]]
		var lim: float = mat.t if mforce[k] >= 0.0 else mat.c
		var r := absf(mforce[k]) / lim if lim > 0.0 else 0.0
		mratio[k] = r
		if r > mpeak[k]:
			mpeak[k] = r
		if r > 1.0:
			_snap(k)
	_drive()
	_slosh()

## The lead cart's tea, one step: its surface chases the level (against the
## cup, minus the cart's tilt) on an underdamped spring.
func _slosh() -> void:
	if not tea or spilled or cart == CART_OVER or cart == CART_WATER:
		return
	var w0 := TAU * TEA_HZ
	var target := -cart_angle
	tea_spin += (w0 * w0 * (target - tea_lean) - 2.0 * TEA_ZETA * w0 * tea_spin) * DT
	tea_lean += tea_spin * DT
	tea_peak = maxf(tea_peak, absf(tea_lean) / TEA_RIM)
	if absf(tea_lean) > TEA_RIM:
		spilled = true
		events.append({"kind": "spill", "at": cart_pos, "side": signf(tea_lean)})

func _lend(lent: Dictionary, state: int, seg: int, from: int, u: float, ramp: float) -> void:
	if state != CART_ROAD:
		return
	var other := ma[seg] if mb[seg] == from else mb[seg]
	lent[from] = float(lent.get(from, 0.0)) + cart_mass * (1.0 - u) * ramp
	lent[other] = float(lent.get(other, 0.0)) + cart_mass * u * ramp

## A member past its limit: two stubs from its ends, meeting where it broke.
func _snap(k: int) -> void:
	malive[k] = 0
	broken.append(morigin[k])
	var a := ma[k]
	var b := mb[k]
	var mid := (jp[a] + jp[b]) * 0.5
	var mass: float = MATS[mmat[k]].mass * mrest[k] * 0.5
	for e in [a, b]:
		var j := jp.size()
		jp.append(mid + (jp[e] - mid) * 0.04)
		jv.append((jv[a] + jv[b]) * 0.5)
		jm.append(mass * 0.5 + JOINT_MASS)
		jfix.append(0)
		_prev.append(jp[j])
		_w.append(0.0)
		home.append(mid)
		_member(e, j, mmat[k], true, -1)
		mrest[mrest.size() - 1] = mrest[k] * 0.48
		_fsum.append(0.0)
	events.append({"kind": "snap", "m": morigin[k], "at": mid, "mat": mmat[k]})
	if cart == CART_ROAD and cart_seg == k:
		_leave()
	for i in trail.size():
		if int(trail[i].cart) == CART_ROAD and int(trail[i].seg) == k:
			_swap(i)
			_leave()
			_swap(i)

func _leave() -> void:
	var d := _seg_dir()
	cart_vel = d * CART_V
	cart = CART_AIR
	cart_seg = -1
	events.append({"kind": "leave", "at": cart_pos})

func _other(k: int, j: int) -> int:
	return mb[k] if ma[k] == j else ma[k]

func _seg_dir() -> Vector2:
	if cart != CART_ROAD:
		return cart_vel.normalized() if cart_vel.length() > 0.01 else Vector2.RIGHT
	var b := _other(cart_seg, cart_from)
	return (jp[b] - jp[cart_from]).normalized()

## The road member leaving joint `j` that carries straight on along `dir`.
func _next_road(j: int, dir: Vector2, not_k: int) -> int:
	var best := -1
	var best_dot := 0.2
	for k in ma.size():
		if k == not_k or malive[k] == 0 or mstub[k] == 1 or mmat[k] != ROAD:
			continue
		if ma[k] != j and mb[k] != j:
			continue
		var o := _other(k, j)
		var d := (jp[o] - jp[j]).normalized()
		if d.x <= 0.05:
			continue
		var dot := d.dot(dir)
		if dot > best_dot:
			best_dot = dot
			best = k
	return best

func _drive() -> void:
	_drive_one()
	for i in trail.size():
		_swap(i)
		_drive_one()
		_swap(i)
	# the last cart over is the crossing
	if crossed() and not _crossed_told:
		_crossed_told = true
		events.append({"kind": "cross"})

var _crossed_told := false

func _drive_one() -> void:
	var step_len := CART_V * DT
	match cart:
		CART_BANK_L:
			cart_pos.x += step_len
			cart_pos.y = 0.0
			cart_angle = 0.0
			if cart_pos.x >= 0.0:
				var j := joint_at(Vector2i(0, 0))
				var k := _next_road(j, Vector2.RIGHT, -1) if j >= 0 else -1
				if k < 0:
					cart_vel = Vector2(CART_V, 0.0)
					cart = CART_AIR
					events.append({"kind": "leave", "at": cart_pos})
				else:
					_enter(k, j, 0.0)
		CART_ROAD:
			var b := _other(cart_seg, cart_from)
			var len := jp[b].distance_to(jp[cart_from])
			cart_u += step_len / maxf(len, 0.05)
			while cart_u >= 1.0 and cart == CART_ROAD:
				var over := (cart_u - 1.0) * len
				var dir := (jp[b] - jp[cart_from]).normalized()
				if jfix[b] == 1 and home[b] == Vector2(w, dy):
					cart = CART_BANK_R
					cart_pos = Vector2(w + over, dy)
					cart_angle = 0.0
					events.append({"kind": "bank"})
					return
				var k := _next_road(b, dir, cart_seg)
				if k < 0:
					cart_pos = jp[b]
					_leave()
					return
				var nlen := jp[_other(k, b)].distance_to(jp[b])
				_enter(k, b, over / maxf(nlen, 0.05))
				b = _other(cart_seg, cart_from)
				len = nlen
			if cart == CART_ROAD:
				var from := jp[cart_from]
				var to := jp[b]
				cart_pos = from.lerp(to, cart_u)
				cart_angle = (to - from).angle()
		CART_AIR:
			var was := cart_pos
			cart_vel.y -= G * DT
			cart_pos += cart_vel * DT
			cart_angle = lerp_angle(cart_angle, cart_vel.angle() * 0.5, 0.05)
			_land(was)
		CART_BANK_R:
			cart_pos.x += step_len
			cart_pos.y = dy
			if cart_pos.x >= w + CART_EXIT:
				cart = CART_OVER
				events.append({"kind": "over"})
		CART_OVER:
			# rolls on out of sight while the rest come over
			cart_pos.x += step_len

func _enter(k: int, from: int, u: float) -> void:
	cart = CART_ROAD
	cart_seg = k
	cart_from = from
	cart_u = u
	events.append({"kind": "road", "m": morigin[k]})

## A falling cart lands on the first road it crosses from above, a bank, or
## the river.
func _land(was: Vector2) -> void:
	var now := cart_pos
	if now.x <= 0.0 and was.y >= 0.0 and now.y < 0.0:
		cart = CART_BANK_L
		cart_pos.y = 0.0
		events.append({"kind": "land", "at": cart_pos})
		return
	if now.x >= w and was.y >= dy and now.y < dy:
		cart = CART_BANK_R
		cart_pos.y = dy
		events.append({"kind": "land", "at": cart_pos})
		return
	for k in ma.size():
		if malive[k] == 0 or mstub[k] == 1 or mmat[k] != ROAD:
			continue
		var p := jp[ma[k]]
		var q := jp[mb[k]]
		var hit = Geometry2D.segment_intersects_segment(was, now, p, q)
		if hit == null:
			continue
		var n := (q - p).orthogonal()
		if n.y < 0.0:
			n = -n
		if (now - was).dot(n) >= 0.0:
			continue
		var from := ma[k] if p.x <= q.x else mb[k]
		var to := _other(k, from)
		var len := jp[from].distance_to(jp[to])
		_enter(k, from, jp[from].distance_to(hit) / maxf(len, 0.05))
		events.append({"kind": "land", "at": hit})
		return
	if now.y < WATER:
		cart = CART_WATER
		events.append({"kind": "splash", "at": Vector2(now.x, WATER)})

## Runs a whole test headless: true when the cart gets over. `worst` gets
## the highest stress any design member reached, for the miner's margin.
func run(max_time := TIME_OUT) -> bool:
	while not done() and t < max_time:
		step()
		if not broken.is_empty() or spilled:
			return false
	return crossed()

func worst() -> float:
	var r := 0.0
	for k in ma.size():
		if mstub[k] == 0:
			r = maxf(r, mpeak[k])
	return r

static func cost_of(design: Array) -> int:
	var c := 0
	for d in design:
		c += member_cost(d.a, d.b, int(d.m))
	return c

static func member_cost(a: Vector2i, b: Vector2i, m: int) -> int:
	return int(round(MATS[m].cost * Vector2(a).distance_to(Vector2(b)) / 10.0)) * 10
