extends RefCounted

## One rope of the Untangle ring: a chain of points pinned at both pegs,
## stepped as a Verlet rope (each point keeps its own velocity, a few passes
## pull neighbours back to their spacing) and drawn as a thick laid cotton
## cord -- a soft shadow, a dark rim, the round body with its shade and its
## light, and the slanted strands of a three-strand rope.
##
## What the physics is for. A rope on its own lies nearly straight between its
## pegs (its rest length follows the gap, plus a hair of slack). Where it is
## wrapped round another rope the board *binds* a run of its points to the
## line of a braid the two share (`bind`), and the rest length grows to the
## way round; the chain does the rest, so a wrap pulls both ropes in towards
## each other, a new one cinches, and one let go springs apart. The coil
## itself -- the shorter rope swinging across the longer, turn by turn, while
## the longer runs straight through -- is laid on
## the drawn line (`wiggles`), not the chain, so it stays round however coarse
## the chain. A peg let go kicks the chain sideways and it whips and settles.
## Nothing here is a tween.
##
## Drawing takes any stretch of the rope by length (`draw`'s `s0`, `s1`), with
## the strands laid by length from the rope's start, so the board can lay a
## short piece of one rope back over another where it crosses on top and the
## piece meets the rope under it without a seam.
##
## Spec: docs/superpowers/specs/2026-09-29-untangle-knots-design.md, section 2.

const Face = preload("res://ui/faces/face.gd")

## Points along the rope, ends included.
const SEGS := 37
const SIM_DT := 1.0 / 120.0
## Fraction of speed a point keeps each step: the cloth it lies on drags it.
const DAMP := 0.968
const ITERS := 8
## Passes after the binds, so the chain stays joined round them.
const ITERS_AFTER := 3
## How hard a point is pulled toward the line through its neighbours.
const BEND := 0.22
## Slack over the way between the pegs, at rest, as a fraction of it.
const SLACK := 0.006
## How fast the rest length follows its target.
const FOLLOW := 0.3
## The light falls from the top left, onto the cloth.
const LIGHT := Vector2(-0.55, -0.83)

var p := PackedVector2Array()
var q := PackedVector2Array()
## The length the chain is asked to keep, in px, and the extra slack a kick
## has added on top of SLACK (a fraction, decaying).
var rest := 0.0
var extra := 0.0
## The rope's own length: the farthest its pegs can be, in px.
var length := 0.0
## The way the rope has to go between its pegs, round the wraps it is in, in
## px; 0 means the straight gap.
var route := 0.0
## Points held to the braids this rope is wrapped in: index, where, how hard.
var bind_i := PackedInt32Array()
var bind_at := PackedVector2Array()
var bind_k := PackedFloat32Array()
## Per point, how firmly it is held (0 free): a held point keeps less speed.
var _held := PackedFloat32Array()
## The braids this rope is twisted in, laid on its drawn line: each
## {"c", "axis", "perp", "len", "n", "side" (+1 or -1), "w", "swing" (px),
## "spin" (radians the twist is turned by while it cinches or lets go)}.
var wiggles: Array = []

## Its drawn line and the length along it, built on demand after each step.
var _line := PackedVector2Array()
var _cum := PackedFloat32Array()
var _line_ok := false
## Goes up every time the drawn line may have changed: what a caller keeps
## worked out from the line (the board's crossings) is good while it holds.
var ver := 0
## Where each chain span starts in the drawn line: a span is one piece where
## the rope runs straight, three where it bends or twists.
var _span_at := PackedInt32Array()
## The box round each span as drawn (twists included): x0, x1, y0, y1 a span.
var _box := PackedFloat32Array()

func setup(a: Vector2, b: Vector2, max_length: float, bow: float) -> void:
	length = max_length
	p.resize(SEGS)
	q.resize(SEGS)
	rest = a.distance_to(b) * (1.0 + SLACK)
	var n := (b - a).orthogonal().normalized()
	for i in SEGS:
		var u := float(i) / (SEGS - 1)
		p[i] = a.lerp(b, u) + n * bow * sin(PI * u)
		q[i] = p[i]
	_line_ok = false
	ver += 1

## Straight and still between two points, no physics: a board that has just
## been laid out, a rope restored. Binds still apply, so a wrap is drawn.
func snap(a: Vector2, b: Vector2) -> void:
	rest = maxf(a.distance_to(b), route) * (1.0 + SLACK)
	for i in SEGS:
		p[i] = a.lerp(b, float(i) / (SEGS - 1))
	for k in bind_i.size():
		p[bind_i[k]] = bind_at[k]
	for i in SEGS:
		q[i] = p[i]
	extra = 0.0
	_line_ok = false
	ver += 1

func clear_binds() -> void:
	bind_i.resize(0)
	bind_at.resize(0)
	bind_k.resize(0)
	_held.resize(SEGS)
	_held.fill(0.0)
	wiggles = []
	_line_ok = false
	ver += 1

## Every bind, the braids' twists and the route at once, from a caller that
## lays them all out again whenever anything moves: a rope whose binds come
## out the same keeps its line (and `ver`), so what was worked out from it
## still holds.
func set_binds(bi: PackedInt32Array, bat: PackedVector2Array, bk: PackedFloat32Array, wg: Array, way: float) -> void:
	if bi == bind_i and bat == bind_at and bk == bind_k and way == route and wg == wiggles:
		return
	clear_binds()
	route = way
	for n in bi.size():
		bind(bi[n], bat[n], bk[n])
	wiggles = wg

func bind(i: int, at: Vector2, k: float) -> void:
	bind_i.append(i)
	bind_at.append(at)
	bind_k.append(k)
	if _held.size() == SEGS:
		_held[i] = maxf(_held[i], k)

## One fixed step with the pegs at `a` and `b`.
func step(a: Vector2, b: Vector2) -> void:
	var gap := a.distance_to(b)
	var target := maxf(gap, route) * (1.0 + SLACK + extra)
	rest = lerpf(rest, target, FOLLOW)
	var seg := rest / (SEGS - 1)
	var held := _held.size() == SEGS
	for i in range(1, SEGS - 1):
		var v := (p[i] - q[i]) * DAMP
		if held:
			# A rope held to a braid lies in a groove: it keeps less speed,
			# and a point held firmly almost none.
			v *= 0.88 * (1.0 - minf(0.9, _held[i] * 2.5))
		q[i] = p[i]
		p[i] += v
	p[0] = a
	p[SEGS - 1] = b
	q[0] = a
	q[SEGS - 1] = b
	_relax(seg, ITERS)
	if not bind_i.is_empty():
		for k in bind_i.size():
			var i := bind_i[k]
			p[i] = p[i].lerp(bind_at[k], bind_k[k])
		_relax(seg, ITERS_AFTER)
	for pass_i in 2:
		for i in range(1, SEGS - 1):
			p[i] += ((p[i - 1] + p[i + 1]) * 0.5 - p[i]) * BEND
	_line_ok = false
	ver += 1

func _relax(seg: float, passes: int) -> void:
	for it in passes:
		for i in SEGS - 1:
			var d := p[i + 1] - p[i]
			var len := d.length()
			if len < 0.0001:
				continue
			var diff := (len - seg) / len
			if i == 0:
				p[i + 1] -= d * diff
			elif i == SEGS - 2:
				p[i] += d * diff
			else:
				p[i] += d * diff * 0.5
				p[i + 1] -= d * diff * 0.5

## A whip: the middle of the rope is sent sideways by `amp` px per step
## (positive one way, negative the other) and the rope is given `slack` more
## to swing with.
func kick(amp: float, slack := 0.0) -> void:
	var n := (p[SEGS - 1] - p[0]).orthogonal().normalized()
	for i in range(1, SEGS - 1):
		q[i] -= n * amp * sin(PI * float(i) / (SEGS - 1))
	extra = maxf(extra, slack)

## Sum of the points' speeds, per step: what says the rope has come to rest.
func energy() -> float:
	var e := 0.0
	for i in range(1, SEGS - 1):
		e += (p[i] - q[i]).length()
	return e

## Straight-line gap ratio: 1 when the pegs are as far as the rope goes.
func taut(a: Vector2, b: Vector2) -> float:
	return clampf(a.distance_to(b) / maxf(length, 1.0), 0.0, 1.0)

## The chain smoothed with a Catmull-Rom through its points -- three pieces
## to a span where it bends or where a braid twists it, one where it runs
## straight -- so a whipping rope bends round instead of kinking; then each
## braid's twist laid on it: along the braid the rope swings `swing` px to its
## side and back, crossing its partner `n` times, easing in and out at the ends.
func polyline() -> PackedVector2Array:
	if not _line_ok:
		_line = PackedVector2Array()
		_span_at.resize(SEGS)
		_line.append(p[0])
		for i in SEGS - 1:
			_span_at[i] = _line.size() - 1
			var p0 := p[maxi(i - 1, 0)]
			var p1 := p[i]
			var p2 := p[i + 1]
			var p3 := p[mini(i + 2, SEGS - 1)]
			if _fine(i, p0, p1, p2, p3):
				_line.append(_cr(p0, p1, p2, p3, 1.0 / 3.0))
				_line.append(_cr(p0, p1, p2, p3, 2.0 / 3.0))
			_line.append(p2)
		_span_at[SEGS - 1] = _line.size() - 1
		for wg in wiggles:
			_twist(wg)
		_cum = lengths(_line)
		# The box round each span's drawn pieces, for `hits`.
		_box.resize((SEGS - 1) * 4)
		for i in SEGS - 1:
			var x0 := INF
			var x1 := -INF
			var y0 := INF
			var y1 := -INF
			for j in range(_span_at[i], _span_at[i + 1] + 1):
				var v := _line[j]
				x0 = minf(x0, v.x)
				x1 = maxf(x1, v.x)
				y0 = minf(y0, v.y)
				y1 = maxf(y1, v.y)
			_box[i * 4] = x0
			_box[i * 4 + 1] = x1
			_box[i * 4 + 2] = y0
			_box[i * 4 + 3] = y1
		_line_ok = true
	return _line

## Whether span `i` needs smoothing: it bends (the chain turns at either end
## by more than a few degrees) or lies in reach of a braid.
func _fine(i: int, p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2) -> bool:
	var d1 := p2 - p1
	if (p1 - p0).length_squared() > 0.0 and d1.length_squared() > 0.0:
		if (p1 - p0).normalized().dot(d1.normalized()) < 0.996:
			return true
	if (p3 - p2).length_squared() > 0.0 and d1.length_squared() > 0.0:
		if d1.normalized().dot((p3 - p2).normalized()) < 0.996:
			return true
	for wg in wiggles:
		var L: float = wg.len
		var reach := L * 0.8 + absf(float(wg.swing)) * 3.0
		var c: Vector2 = wg.c
		if p1.distance_squared_to(c) < reach * reach or p2.distance_squared_to(c) < reach * reach:
			return true
	return false

func _twist(wg: Dictionary) -> void:
	var c: Vector2 = wg.c
	var axis: Vector2 = wg.axis
	var perp: Vector2 = wg.perp
	var L: float = wg.len
	var n: float = wg.n
	var swing: float = float(wg.swing) * float(wg.side)
	# The core of a coil runs straight through it.
	if swing == 0.0:
		return
	var w: float = wg.w
	# A braid cinching in or letting go turns as it does: its crossings run
	# along it, so an unwind reads as a spin and not a fade.
	var spin: float = float(wg.get("spin", 0.0))
	var near: float = absf(float(wg.swing)) * 3.0 + 4.0
	# The chain already runs from its side at one end to its side at the
	# other (straight between): what is laid on is the swing across and back
	# less that straight run, so nothing moves at the ends.
	# The swing runs from phase `p0` to `p1` along the braid (a full swing
	# across and back every two pi).
	var p0: float = float(wg.get("p0", 0.0))
	var p1: float = float(wg.get("p1", PI * n))
	var from_side := cos(p0)
	var end_side := cos(p1)
	if wg.has("i0"):
		# The stretch of chain held to the braid, by length along the line.
		var j0 := _span_at[clampi(int(floor(float(wg.i0))), 0, SEGS - 1)]
		var j1 := _span_at[clampi(int(ceil(float(wg.i1))), 0, SEGS - 1)]
		if j1 - j0 < 2:
			return
		var along := PackedFloat32Array()
		along.resize(j1 - j0 + 1)
		for j in range(j0 + 1, j1 + 1):
			along[j - j0] = along[j - j0 - 1] + _line[j - 1].distance_to(_line[j])
		var span := along[along.size() - 1]
		if span <= 0.0:
			return
		for j in range(j0 + 1, j1):
			var u := along[j - j0] / span
			var shape := cos(lerpf(p0, p1, u) + spin * sin(PI * u)) - lerpf(from_side, end_side, u)
			_line[j] += perp * swing * shape * w
		return
	for i in range(1, _line.size() - 1):
		var d := _line[i] - c
		var u := d.dot(axis) / L + 0.5
		if u <= 0.0 or u >= 1.0 or absf(d.dot(perp)) > near:
			continue
		var shape := cos(lerpf(p0, p1, u) + spin * sin(PI * u)) - lerpf(from_side, end_side, u)
		_line[i] += perp * swing * shape * w

func cum() -> PackedFloat32Array:
	polyline()
	return _cum

func total() -> float:
	var c := cum()
	return c[c.size() - 1]

static func _cr(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)

static func lengths(line: PackedVector2Array) -> PackedFloat32Array:
	var c := PackedFloat32Array()
	c.resize(line.size())
	for i in range(1, line.size()):
		c[i] = c[i - 1] + line[i - 1].distance_to(line[i])
	return c

## The point `s` along a polyline and its unit direction there.
static func at(line: PackedVector2Array, c: PackedFloat32Array, s: float) -> Array:
	var k := 1
	while k < c.size() - 1 and c[k] < s:
		k += 1
	var seg := c[k] - c[k - 1]
	var u := (s - c[k - 1]) / seg if seg > 0.0 else 0.0
	var dir := (line[k] - line[k - 1])
	return [line[k - 1].lerp(line[k], clampf(u, 0.0, 1.0)), dir.normalized() if dir.length_squared() > 0.0 else Vector2.RIGHT]

## The part of a polyline from `s0` to `s1` along it.
static func slice(line: PackedVector2Array, c: PackedFloat32Array, s0: float, s1: float) -> PackedVector2Array:
	var out := PackedVector2Array([at(line, c, s0)[0]])
	for i in line.size():
		if c[i] > s0 and c[i] < s1:
			out.append(line[i])
	out.append(at(line, c, s1)[0])
	return out

## Every place this rope's drawn line crosses `other`'s within `radius` of
## `near`, as [s along this, s along other, point], in order along this one.
## Two stages: the chains' spans near `near` (within `radius` plus `margin`,
## the most a twist moves the drawn line off its chain) whose drawn boxes
## overlap, and then only the drawn pieces of those spans, exactly.
func hits(other, near: Vector2, radius: float, margin := 0.0) -> Array:
	var la := polyline()
	var ca := cum()
	var lb: PackedVector2Array = other.polyline()
	var cb: PackedFloat32Array = other.cum()
	var pb: PackedVector2Array = other.p
	var out: Array = []
	var r2 := (radius + margin) * (radius + margin)
	var ia := PackedInt32Array()
	for i in SEGS - 1:
		if p[i].distance_squared_to(near) <= r2 or p[i + 1].distance_squared_to(near) <= r2:
			ia.append(i)
	if ia.is_empty():
		return out
	var ib := PackedInt32Array()
	for j in SEGS - 1:
		if pb[j].distance_squared_to(near) <= r2 or pb[j + 1].distance_squared_to(near) <= r2:
			ib.append(j)
	if ib.is_empty():
		return out
	var bb: PackedFloat32Array = other._box
	for i in ia:
		var x0 := _box[i * 4] - 1.0
		var x1 := _box[i * 4 + 1] + 1.0
		var y0 := _box[i * 4 + 2] - 1.0
		var y1 := _box[i * 4 + 3] + 1.0
		for j in ib:
			if bb[j * 4 + 1] < x0 or bb[j * 4] > x1 or bb[j * 4 + 3] < y0 or bb[j * 4 + 2] > y1:
				continue
			var sb: PackedInt32Array = other._span_at
			for u in range(_span_at[i], _span_at[i + 1]):
				for v in range(sb[j], sb[j + 1]):
					var hit = Geometry2D.segment_intersects_segment(la[u], la[u + 1], lb[v], lb[v + 1])
					if hit == null:
						continue
					var pt: Vector2 = hit
					out.append([ca[u] + la[u].distance_to(pt), cb[v] + lb[v].distance_to(pt), pt])
	out.sort_custom(func(x: Array, y: Array) -> bool: return x[0] < y[0])
	return out

## The rope from `s0` to `s1` along it (all of it when `s1` < 0) into `b`: `w`
## wide, in the colours of one of the board's ropes. `lift` (0 to 1) is how
## far it is off the cloth -- the shadow parts from it -- and `alpha` fades it
## in. `glow` lays a warm light over the body for the solve's wave, `from`..`to`
## the stretch of it (fractions of its length) the light covers. `tight` thins
## a rope pulled to its limit. `shadow` 0 leaves the shadow out (a piece laid
## back over a crossing brings its own, smaller one).
func draw(b: Face.Builder, w: float, fill: Color, deep: Color, light: Color, lift := 0.0, alpha := 1.0,
		glow: Color = Color(0, 0, 0, 0), from := 0.0, to := 0.0, tight := 0.0, s0 := 0.0, s1 := -1.0, shadow := 1.0) -> void:
	var full := polyline()
	var c := cum()
	var length_now: float = c[c.size() - 1]
	if length_now <= 1.0 or alpha <= 0.0:
		return
	var whole := s1 < 0.0
	if whole:
		s1 = length_now
	s0 = clampf(s0, 0.0, length_now)
	s1 = clampf(s1, 0.0, length_now)
	if s1 - s0 < 1.0:
		return
	var line := full if whole else slice(full, c, s0, s1)
	var thick := w * (1.0 - 0.12 * tight)
	if shadow > 0.0:
		# The shadow falls down and to the right, the further the higher the
		# rope is lifted; a lifted rope's is also fainter and wider. A piece
		# laid over a crossing casts a shorter one, onto the rope beneath.
		var off := Vector2(0.10, 0.22) * w * (1.0 + 2.6 * lift) * (1.0 if whole else 0.6)
		var under := line
		if not whole:
			var trim := (s1 - s0) * 0.2
			under = slice(full, c, s0 + trim, s1 - trim)
		var a_sh := (0.22 - 0.07 * lift) * alpha * shadow
		var ink := Color(0.23, 0.18, 0.14, a_sh)
		var clear := Color(ink, 0.0)
		_ribbon(b, under, off, thick * (1.2 + 0.35 * lift) * 0.5,
			PackedFloat32Array([-1.0, -0.45, 0.45, 1.0]), [clear, ink, ink, clear])
	# The round body, one ribbon: its colour runs across the rope from the
	# dark rim on the side the light comes from, through the light on its
	# back, to the shade on the far side and the far rim.
	var half := thick * 0.5
	var f := Face.FEATHER / half
	var rim := Color(deep, alpha)
	_ribbon(b, line, Vector2.ZERO, half,
		PackedFloat32Array([-1.0 - f, -1.0, -0.78, -0.42, -0.1, 0.36, 0.72, 1.0, 1.0 + f]),
		[Color(rim, 0.0), rim, Color(fill, alpha), Color(fill.lerp(light, 0.75), alpha), Color(fill, alpha),
			Color(fill, alpha), Color(fill.lerp(deep, 0.5), alpha), rim, Color(rim, 0.0)])
	_strands(b, full, c, s0, s1, thick, fill, deep, light, alpha)
	if glow.a > 0.0 and to > from:
		var g0 := maxf(s0, length_now * from)
		var g1 := minf(s1, length_now * to)
		if g1 > g0 + 1.0:
			var seg := slice(full, c, g0, g1)
			if seg.size() >= 2:
				b.stroke(seg, thick * 0.8, Color(glow, glow.a * alpha), false, false)

## The dark this rope leaves on a rope it lies over at `s` along it: a soft
## band down either side of it, `half` each way along it, darkest beside the
## rope at `s` and gone at the ends and a rope's half-width out. It lies
## outside this rope's own body, so it can go on over everything.
func shade(b: Face.Builder, w: float, s: float, half: float, ink: Color) -> void:
	var full := polyline()
	var c := cum()
	var s0 := maxf(s - half, 0.0)
	var s1 := minf(s + half, c[c.size() - 1])
	if s1 - s0 < 2.0 or ink.a <= 0.0:
		return
	var n := 9
	var near := w * 0.44
	var far := w * 0.74
	var base := b.verts.size()
	for i in n:
		var u := float(i) / float(n - 1)
		var got := at(full, c, lerpf(s0, s1, u))
		var pt: Vector2 = got[0]
		var nm: Vector2 = (got[1] as Vector2).orthogonal()
		var a := sin(PI * u)
		var dark := Color(ink, ink.a * a * a)
		var clear := Color(ink, 0.0)
		b.verts.append(pt - nm * far)
		b.cols.append(clear)
		b.verts.append(pt - nm * near)
		b.cols.append(dark)
		b.verts.append(pt + nm * near)
		b.cols.append(dark)
		b.verts.append(pt + nm * far)
		b.cols.append(clear)
	for i in n - 1:
		for j in [0, 2]:
			var v: int = base + i * 4 + j
			b.idx.append_array(PackedInt32Array([v, v + 4, v + 5, v, v + 5, v + 1]))

## A band along `line` (moved by `off`), `half` wide either side, whose colour
## runs across it: `across` are the places across it (-1 the side the light
## comes from, 1 the far side, in halves) and `cols` the colour at each. One
## run of vertices per point, written straight into the builder.
##
## The side normal is carried along the line (never flipped point to point:
## a flip folds the strip into shards wherever the rope turns across the
## light), and which side is lit is blended in per point instead, so a rope
## running along the light is lit evenly and the shading turns with the rope.
static func _ribbon(b: Face.Builder, line: PackedVector2Array, off: Vector2, half: float,
		across: PackedFloat32Array, cols: Array) -> void:
	var n := line.size()
	if n < 2:
		return
	var m := across.size()
	# Each stop's colour as given and as seen from the other side, for the
	# blend; and the stops' offsets across, in px.
	var given := PackedColorArray()
	var mirror := PackedColorArray()
	var wide := PackedFloat32Array()
	given.resize(m)
	mirror.resize(m)
	wide.resize(m)
	for j in m:
		given[j] = cols[j]
		mirror[j] = _sample(across, cols, -across[j])
		wide[j] = across[j] * half
	# Written into local arrays sized once and handed over whole: a rope is a
	# thousand vertices, and an append a vertex through the builder was most
	# of what a moving rope cost.
	var base := b.verts.size()
	var vs := PackedVector2Array()
	var cs := PackedColorArray()
	vs.resize(n * m)
	cs.resize(n * m)
	var prev := Vector2.ZERO
	var w := 0
	for i in n:
		var t := line[mini(i + 1, n - 1)] - line[maxi(i - 1, 0)]
		var nm := t.orthogonal().normalized() if t.length_squared() > 0.0 else prev
		if nm == Vector2.ZERO:
			nm = Vector2.UP
		if prev != Vector2.ZERO and nm.dot(prev) < 0.0:
			nm = -nm
		prev = nm
		# 0: nm points away from the light (the stops as given), 1: toward it.
		var flip := smoothstep(-0.35, 0.35, nm.dot(LIGHT))
		var at := line[i] + off
		for j in m:
			vs[w] = at + nm * wide[j]
			cs[w] = given[j].lerp(mirror[j], flip)
			w += 1
	b.verts.append_array(vs)
	b.cols.append_array(cs)
	b.idx.append_array(_grid(n, m, base))

## The triangles of a band `n` points long and `m` stops across whose first
## vertex is `base`, kept: a moving rope asks for the same few again and
## again, frame after frame.
static var _grids := {}
static func _grid(n: int, m: int, base: int) -> PackedInt32Array:
	var key := Vector3i(n, m, base)
	var got = _grids.get(key)
	if got != null:
		return got
	if _grids.size() > 512:
		_grids.clear()
	var out := PackedInt32Array()
	out.resize((n - 1) * (m - 1) * 6)
	var w := 0
	for i in n - 1:
		var r0 := base + i * m
		var r1 := r0 + m
		for j in m - 1:
			out[w] = r0 + j
			out[w + 1] = r1 + j
			out[w + 2] = r1 + j + 1
			out[w + 3] = r0 + j
			out[w + 4] = r1 + j + 1
			out[w + 5] = r0 + j + 1
			w += 6
	_grids[key] = out
	return out

## The colour of a band `across` / `cols` at the place `a` across it.
static func _sample(across: PackedFloat32Array, cols: Array, a: float) -> Color:
	var m := across.size()
	if a <= across[0]:
		return cols[0]
	for j in range(1, m):
		if a <= across[j]:
			var span := across[j] - across[j - 1]
			var u := (a - across[j - 1]) / span if span > 0.0 else 0.0
			return (cols[j - 1] as Color).lerp(cols[j], u)
	return cols[m - 1]

## `line` moved sideways by `d`: away from the light when `away`, toward it
## otherwise.
static func _offset(line: PackedVector2Array, d: float, away: bool) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(line.size())
	for i in line.size():
		var t := (line[mini(i + 1, line.size() - 1)] - line[maxi(i - 1, 0)])
		var n := t.orthogonal().normalized() if t.length_squared() > 0.0 else Vector2.UP
		if n.dot(LIGHT) > 0.0:
			n = -n
		out[i] = line[i] + (n if away else -n) * d
	return out

## The laid rope's strands: every `w * 0.62` along it a slanted groove, dark,
## bowed like the edge of a round strand, with the strand's lit ridge beside
## it. Laid by length from the rope's start, so any piece of it matches.
func _strands(b: Face.Builder, line: PackedVector2Array, c: PackedFloat32Array, s0: float, s1: float, w: float,
		fill: Color, deep: Color, light: Color, alpha: float) -> void:
	var step := w * 0.62
	var half := w * 0.42
	var dark := Color(deep, 0.42 * alpha)
	var pale := Color(light, 0.45 * alpha)
	var s := ceilf((s0 - step * 0.5) / step) * step + step * 0.5
	if s >= s1:
		return
	var count := int(ceilf((s1 - s) / step))
	# Two quads a strand, eight vertices a quad, written into local arrays
	# sized once (see _ribbon).
	var vs := PackedVector2Array()
	var cs := PackedColorArray()
	vs.resize(count * 16)
	cs.resize(count * 16)
	var base := b.verts.size()
	var at := 0
	var k := 1
	while s < s1 and at < count * 16:
		while k < c.size() - 1 and c[k] < s:
			k += 1
		var seg := c[k] - c[k - 1]
		var pt := line[k - 1].lerp(line[k], (s - c[k - 1]) / seg if seg > 0.0 else 0.0)
		var tn := (line[k] - line[k - 1]).normalized()
		var nm := tn.orthogonal()
		# From one rim to the other, leaning along the rope: the seam between
		# two strands, and beside it the lit back of the next strand, brighter
		# on the side the light comes from.
		var e0 := pt - nm * half - tn * half * 0.7
		var e1 := pt + nm * half + tn * half * 0.7
		_quad_at(vs, cs, at, e0, e1, w * 0.12, dark)
		var ridge := tn * (w * 0.19)
		var lit := nm if nm.dot(LIGHT) > 0.0 else -nm
		var r0 := pt + ridge + lit * half * 0.85 + tn * half * 0.6 * (1.0 if lit == nm else -1.0)
		_quad_at(vs, cs, at + 8, pt + ridge, r0, w * 0.11, pale)
		at += 16
		s += step
	if at < vs.size():
		vs.resize(at)
		cs.resize(at)
	b.verts.append_array(vs)
	b.cols.append_array(cs)
	b.idx.append_array(_quads(at / 8, base))

## A short straight stroke as one quad with a feathered rim, the same shape
## as Builder.stroke's segment, written out at `w` in `vs`/`cs`: eight
## vertices, a rim either side.
static func _quad_at(vs: PackedVector2Array, cs: PackedColorArray, w: int, a: Vector2, c: Vector2, width: float, colour: Color) -> void:
	var t := (c - a).normalized()
	var nrm := Vector2(-t.y, t.x)
	var hw := nrm * (width * 0.5)
	var f := nrm * (width * 0.5 + Face.FEATHER)
	var clear := Color(colour, 0.0)
	vs[w] = a - f; cs[w] = clear
	vs[w + 1] = a - hw; cs[w + 1] = colour
	vs[w + 2] = a + hw; cs[w + 2] = colour
	vs[w + 3] = a + f; cs[w + 3] = clear
	vs[w + 4] = c - f; cs[w + 4] = clear
	vs[w + 5] = c - hw; cs[w + 5] = colour
	vs[w + 6] = c + hw; cs[w + 6] = colour
	vs[w + 7] = c + f; cs[w + 7] = clear

## The triangles of `n` quads from `_quad_at`, the first vertex at `base`.
static var _quad_grids := {}
static func _quads(n: int, base: int) -> PackedInt32Array:
	var key := Vector2i(n, base)
	var got = _quad_grids.get(key)
	if got != null:
		return got
	if _quad_grids.size() > 512:
		_quad_grids.clear()
	var out := PackedInt32Array()
	out.resize(n * 18)
	var w := 0
	for q in n:
		var o := base + q * 8
		for k in 3:
			out[w] = o + k
			out[w + 1] = o + 4 + k
			out[w + 2] = o + 5 + k
			out[w + 3] = o + k
			out[w + 4] = o + 5 + k
			out[w + 5] = o + k + 1
			w += 6
	_quad_grids[key] = out
	return out
