extends RefCounted

## One rope of the Untangle ring, drawn as a thick laid cotton cord -- a soft
## shadow, a dark rim, the round body with its shade and its light, and the
## slanted strands of a three-strand rope.
##
## The rope is pulled tight. It runs straight from its peg to each knot it is
## in, through the knot and straight on to the next, and its line is worked
## out from where those are and nothing else (`lay`): no chain of points on
## its way somewhere, so nothing can be drawn half arrived. A knot is two
## ropes twisted round each other in one short tight twist (`lay_knot`): along
## its axis each swings across the other once a crossing, and each leaves its
## end of the twist round a bend of its own width toward where it goes next,
## whatever way that is -- so the knot holds its shape however the pegs are
## moved. What moves is laid on top of that line: a swing on each straight
## stretch when the rope is kicked (two damped springs, `kick` and `step`),
## and, when the knots it is in change, a short glide from the line it had
## to the line it has (`MORPH`).
##
## Drawing takes any stretch of the rope by length (`draw`'s `s0`, `s1`), with
## the strands laid by length from the rope's start, so the board can lay a
## short piece of one rope back over another where it crosses on top and the
## piece meets the rope under it without a seam.
##
## Spec: docs/superpowers/specs/2026-09-29-untangle-knots-design.md, section 2
## and the 2026-10-05 amendment.

const Face = preload("res://ui/faces/face.gd")

## A knot, in rope widths: from one crossing to the next along it, and how far
## each rope swings either side of its axis.
const KNOT_PITCH := 1.4
const KNOT_SIDE := 0.52
## The most crossings a knot is drawn with; a deeper wrap shows its count.
const KNOT_MOST := 6
## Pieces of line from one crossing to the next.
const KNOT_STEPS := 8
## How far a knot runs on past its first and last crossings, as a share of
## the pitch, and the pieces of line that takes. Short of half: a rope comes
## into the knot already heading across the other, so one hooked round
## another dips in and out in a V and need not turn along the knot first.
const KNOT_LEAD := 0.3
const KNOT_LEAD_STEPS := 3
## The bend a rope leaves a knot round, in rope widths, and the angle a piece
## of that bend covers.
const FILLET := 0.8
const FILLET_STEP := 0.18
## A straight stretch is cut into pieces about this long, in rope widths.
const LEG_PIECE := 1.3
const LEG_MOST := 14
## Seconds a rope takes from the line it had to a new one when its knots change.
const MORPH := 0.22
## The swing: px a second a kick of 1 gives, the slowest and fastest it beats
## (a long rope swings slowly), the px of rope a 1 Hz swing would have, and
## how fast it dies.
const KICK := 52.0
const SWING_SLOW := 2.4
const SWING_FAST := 6.5
const SWING_SPAN := 1500.0
const SWING_DAMP := 0.2
## The second way it swings, an S, against the first: how fast and how much.
const SWING_TWO := 2.1
const SWING_TWO_KICK := 0.6
const SIM_DT := 1.0 / 120.0
## The light falls from the top left, onto the cloth.
const LIGHT := Vector2(-0.55, -0.83)

## The rope's own length: the farthest its pegs can be, in px.
var length := 0.0
## Goes up every time the drawn line may have changed: what a caller keeps
## worked out from the line (the board's crossings) is good while it holds.
var ver := 0
## Per knot this rope is in (its key), where its crossings are in the drawn
## line, in the order the rope meets them.
var marks := {}

## The line the rope lies in at rest, and per point the way it swings (a unit
## sideways) and how far each of the two swings carries it (0 where it is held:
## in a knot, on a bend).
var _base := PackedVector2Array()
var _nrm := PackedVector2Array()
var _sh1 := PackedFloat32Array()
var _sh2 := PackedFloat32Array()
## What that line was laid from, and the knots alone (a change of those glides).
var _sig: Array = []
var _shape: Array = []
var _a1 := 0.0
var _v1 := 0.0
var _a2 := 0.0
var _v2 := 0.0
var _hz := SWING_SLOW
var _old := PackedVector2Array()
var _old_cum := PackedFloat32Array()
var _morph := 1.0
var _accum := 0.0
## Its drawn line and the length along it, built on demand.
var _line := PackedVector2Array()
var _cum := PackedFloat32Array()
var _line_ok := false

func setup(a: Vector2, b: Vector2, max_length: float, wd := 1.0) -> void:
	length = max_length
	_sig = []
	_shape = []
	_base = PackedVector2Array()
	lay(a, b, [], wd)
	rest()

## Lays the rope from `a` to `b` through `stops`, in order: each [knot (from
## `lay_knot`), 0 when this rope is the knot's first, 1 its second]. Returns
## whether its line changed. A change of the knots themselves is glided to;
## the pegs or a knot moving is followed at once.
func lay(a: Vector2, b: Vector2, stops: Array, wd: float) -> bool:
	var sig: Array = [a, b, wd]
	var shape: Array = []
	for st in stops:
		var kn: Dictionary = st[0]
		sig.append_array([kn.k, kn.c, kn.x, kn.m, kn.side, kn.dir_b, st[1]])
		shape.append_array([kn.k, kn.m, kn.side, kn.dir_b])
	if sig == _sig:
		return false
	if shape != _shape and _base.size() >= 2:
		_old = polyline().duplicate()
		_old_cum = lengths(_old)
		_morph = 0.0
	_sig = sig
	_shape = shape
	_build(a, b, stops, wd)
	_line_ok = false
	ver += 1
	return true

## True when the rope goes through a knot.
func knotted() -> bool:
	return not _shape.is_empty()

## Still, on its line: no swing and no glide left to run.
func rest() -> void:
	_a1 = 0.0
	_v1 = 0.0
	_a2 = 0.0
	_v2 = 0.0
	_morph = 1.0
	_line_ok = false
	ver += 1

## A whip: the rope is sent swinging sideways, `amp` one way or the other.
func kick(amp: float) -> void:
	_v1 += amp * KICK
	_v2 -= amp * KICK * SWING_TWO_KICK

## What is left of the swing, in px: what says the rope has come to rest.
func energy() -> float:
	return absf(_a1) + absf(_a2) + (absf(_v1) + absf(_v2)) * 0.02

## True while the rope is swinging or gliding to a new line.
func moving() -> bool:
	return _morph < 1.0 or energy() > 0.06

## `dt` seconds of the swing and the glide.
func step(dt: float) -> void:
	if not moving():
		if _a1 != 0.0 or _a2 != 0.0:
			rest()
		return
	if _morph < 1.0:
		_morph = minf(1.0, _morph + dt / MORPH)
	_accum += dt
	var w1 := TAU * _hz
	var w2 := w1 * SWING_TWO
	var steps := 0
	while _accum >= SIM_DT and steps < 8:
		_accum -= SIM_DT
		steps += 1
		_v1 += (-w1 * w1 * _a1 - 2.0 * SWING_DAMP * w1 * _v1) * SIM_DT
		_a1 += _v1 * SIM_DT
		_v2 += (-w2 * w2 * _a2 - 2.0 * SWING_DAMP * w2 * _v2) * SIM_DT
		_a2 += _v2 * SIM_DT
	_accum = minf(_accum, SIM_DT * 2.0)
	_line_ok = false
	ver += 1

## Straight-line gap ratio: 1 when the pegs are as far as the rope goes.
func taut(a: Vector2, b: Vector2) -> float:
	return clampf(a.distance_to(b) / maxf(length, 1.0), 0.0, 1.0)

# --- a knot ---

## Two ropes twisted round each other `n` times at `c`, as one tight twist:
## rope A comes from `a_in` and goes on to `a_out`, rope B from `b_in` to
## `b_out` (pegs, or the knots they come from and go to). The twist lies along
## the way the four pull it, and of the ways it can lie there -- which of B's
## legs is at which end, which side of it A comes in on -- it takes the one
## its four legs have to turn least to leave by, so a rope hooked on another
## dips in and out of the knot and does not curl round to reach it. `was` is
## the knot as it was last laid (or {}): it keeps the way it lay unless
## another is clearly better, so a knot does not turn over as a peg is
## carried past.
##
## {"k" (`key`), "c", "x" (the axis, the way A runs through), "y", "m"
## (crossings drawn), "of" (crossings there are), "half" (half its length),
## "side" (+1 when A comes in on the `y` side), "dir_b" (+1 when B runs
## through the same way as A)}.
static func lay_knot(key: Variant, c: Vector2, n: int, wd: float, a_in: Vector2, a_out: Vector2,
		b_in: Vector2, b_out: Vector2, was := {}) -> Dictionary:
	var m := knot_shown(n)
	var ua0 := (a_in - c).normalized()
	var ua1 := (a_out - c).normalized()
	var ub0 := (b_in - c).normalized()
	var ub1 := (b_out - c).normalized()
	var half := knot_half(n, wd)
	var best := {}
	var least := INF
	for dir_b in [1, -1]:
		var bl := ub0 if dir_b > 0 else ub1
		var br := ub1 if dir_b > 0 else ub0
		var pull: Vector2 = (ua1 + br) - (ua0 + bl)
		var x := pull.normalized()
		if pull.length() < 0.001:
			x = (ua1 - ua0).normalized() if (ua1 - ua0).length() > 0.001 else Vector2.RIGHT
		var y := Vector2(-x.y, x.x)
		for side in [1, -1]:
			var kn := {"k": key, "c": c, "x": x, "y": y, "m": m, "of": n, "half": half, "side": side, "dir_b": dir_b}
			# How far each leg turns between the way it comes and the way
			# the knot has it heading, at all four ends.
			var cost := 0.0
			for who in 2:
				var d := 1.0 if who == 0 else float(dir_b)
				var from: Vector2 = a_in if who == 0 else b_in
				var to: Vector2 = a_out if who == 0 else b_out
				var come: Vector2 = c - x * half * d + y * knot_off(kn, who, -half * d, wd)
				var leave: Vector2 = c + x * half * d + y * knot_off(kn, who, half * d, wd)
				var run_in: Vector2 = ((x + y * knot_slope(kn, who, -half * d, wd)) * d).normalized()
				var run_out: Vector2 = ((x + y * knot_slope(kn, who, half * d, wd)) * d).normalized()
				cost += 1.0 - run_in.dot((come - from).normalized())
				cost += 1.0 - run_out.dot((to - leave).normalized())
			if not was.is_empty() and int(was.dir_b) == dir_b and int(was.side) == side:
				cost = cost * 0.8 - 0.15
			if cost < least:
				least = cost
				best = kn
	return best

## How many of a knot's `n` crossings are drawn: all of them up to
## `KNOT_MOST`, and past it the most that are odd or even as `n` is (a rope
## has to leave the knot on the side its crossings put it).
static func knot_shown(n: int) -> int:
	if n <= KNOT_MOST:
		return n
	return KNOT_MOST if n % 2 == KNOT_MOST % 2 else KNOT_MOST - 1

## Half the length of a knot of `n` crossings as drawn.
static func knot_half(n: int, wd: float) -> float:
	return (float(knot_shown(n) - 1) * 0.5 + KNOT_LEAD) * KNOT_PITCH * wd

## The way rope `who` heads at `along` the knot, for a rope running the
## axis's way (px sideways per px along).
static func knot_slope(kn: Dictionary, who: int, along: float, wd: float) -> float:
	var pitch := KNOT_PITCH * wd
	var first := -float(int(kn.m) - 1) * pitch * 0.5
	var slope := -float(kn.side) * KNOT_SIDE * wd * PI / pitch * cos(PI * (first - along) / pitch)
	return slope if who == 0 else -slope

## How far off the knot's axis rope `who` (0 the first, 1 the second) lies at
## `along` it (px from its middle, the axis's way).
static func knot_off(kn: Dictionary, who: int, along: float, wd: float) -> float:
	var pitch := KNOT_PITCH * wd
	var first := -float(int(kn.m) - 1) * pitch * 0.5
	var off := float(kn.side) * KNOT_SIDE * wd * sin(PI * (first - along) / pitch)
	return off if who == 0 else -off

## The bend a rope takes from `e`, heading `t`, to run on straight at `w`: an
## arc `rho` round, tangent to both, as points after `e` up to where it
## straightens. Empty when it runs straight on, or `w` is too near to bend to.
static func _fillet(e: Vector2, t: Vector2, w: Vector2, rho: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var to := w - e
	var cr := t.cross(to)
	if absf(cr) < 0.5 and t.dot(to) > 0.0:
		return out
	var s := 1.0 if cr >= 0.0 else -1.0
	var o := e + Vector2(-t.y, t.x) * s * rho
	var d := o.distance_to(w)
	if d <= rho * 1.02:
		return out
	var from := (e - o).angle()
	var sweep := fposmod(s * ((w - o).angle() - s * acos(rho / d) - from), TAU)
	if sweep < 0.02 or sweep > PI * 1.7:
		return out
	var steps := int(ceil(sweep / FILLET_STEP))
	for j in range(1, steps + 1):
		out.append(o + Vector2.from_angle(from + s * sweep * float(j) / float(steps)) * rho)
	return out

func _build(a: Vector2, b: Vector2, stops: Array, wd: float) -> void:
	var n := stops.size()
	# Where the rope comes into each knot and leaves it, and the way it runs
	# through.
	var come := PackedVector2Array()
	var leave := PackedVector2Array()
	var run_in := PackedVector2Array()
	var run_out := PackedVector2Array()
	for st in stops:
		var kn: Dictionary = st[0]
		var who: int = st[1]
		var d := 1.0 if who == 0 else float(kn.dir_b)
		var x: Vector2 = kn.x
		var y: Vector2 = kn.y
		var half: float = kn.half
		come.append((kn.c as Vector2) - x * half * d + y * knot_off(kn, who, -half * d, wd))
		leave.append((kn.c as Vector2) + x * half * d + y * knot_off(kn, who, half * d, wd))
		# The rope's heading at each end: along the axis its way, and across
		# as the swing has it there.
		run_in.append(((x + y * knot_slope(kn, who, -half * d, wd)) * d).normalized())
		run_out.append(((x + y * knot_slope(kn, who, half * d, wd)) * d).normalized())
	var pts := PackedVector2Array([a])
	var nrm := PackedVector2Array([Vector2.ZERO])
	var sh1 := PackedFloat32Array([0.0])
	var sh2 := PackedFloat32Array([0.0])
	marks = {}
	var way := 0.0
	for i in n + 1:
		var from: Vector2 = a if i == 0 else leave[i - 1]
		var to: Vector2 = b if i == n else come[i]
		# The bend out of the last knot and the bend into this one, each
		# aimed at where the other straightens (three rounds settle it).
		# Bend, straight, bend is only right when the straight runs on from
		# the one bend and into the other; with too little room for that the
		# bends are tried tighter.
		var out_of := PackedVector2Array()
		var into := PackedVector2Array()
		var p0 := from
		var p1 := to
		var gap := 0.0
		var along := Vector2.ZERO
		var fits := false
		for tighter in [1.0, 0.55, 0.3]:
			var rho: float = FILLET * wd * tighter
			out_of = PackedVector2Array()
			into = PackedVector2Array()
			p0 = from
			p1 = to
			for it in 3:
				if i > 0:
					out_of = _fillet(from, run_out[i - 1], p1, rho)
					p0 = out_of[out_of.size() - 1] if not out_of.is_empty() else from
				if i < n:
					into = _fillet(to, -run_in[i], p0, rho)
					p1 = into[into.size() - 1] if not into.is_empty() else to
				if i == 0 or i == n:
					break
			gap = p0.distance_to(p1)
			along = (p1 - p0) / gap if gap > 0.01 else Vector2.ZERO
			fits = gap > 0.01
			if fits and i > 0:
				var before: Vector2 = out_of[out_of.size() - 2] if out_of.size() >= 2 else from
				var heading: Vector2 = (p0 - before).normalized() if not out_of.is_empty() else run_out[i - 1]
				fits = heading.dot(along) > 0.93
			if fits and i < n:
				var after: Vector2 = into[into.size() - 2] if into.size() >= 2 else to
				var heading: Vector2 = (after - p1).normalized() if not into.is_empty() else run_in[i]
				fits = heading.dot(along) > 0.93
			if fits:
				break
		# With no room even so (two knots almost touching, a knot at its peg)
		# the rope takes one smooth curve from the heading it leaves with to
		# the heading it arrives with: a corner there would be drawn as a
		# spike.
		if not fits and (i > 0 or i < n):
			var span := from.distance_to(to)
			var reach := clampf(span * 0.42, 0.2 * wd, 2.6 * wd)
			var c0: Vector2 = from + (run_out[i - 1] * reach if i > 0 else (to - from) * 0.3)
			var c1: Vector2 = to - (run_in[i] * reach if i < n else (to - from) * 0.3)
			var cuts := clampi(int(ceil(span / (0.22 * wd))), 8, 24)
			for j in range(1, cuts + 1):
				var u := float(j) / float(cuts)
				var v := 1.0 - u
				pts.append(from * v * v * v + c0 * 3.0 * v * v * u + c1 * 3.0 * v * u * u + to * u * u * u)
				nrm.append(Vector2.ZERO)
				sh1.append(0.0)
				sh2.append(0.0)
		else:
			for v in out_of:
				pts.append(v)
				nrm.append(Vector2.ZERO)
				sh1.append(0.0)
				sh2.append(0.0)
			# The straight stretch, which is what swings.
			var pieces := clampi(int(ceil(gap / (LEG_PIECE * wd))), 1, LEG_MOST)
			var side := Vector2(-along.y, along.x)
			var much := clampf(gap / (7.0 * wd), 0.0, 1.0)
			for j in range(1, pieces):
				var u := float(j) / float(pieces)
				pts.append(p0.lerp(p1, u))
				nrm.append(side)
				sh1.append(sin(PI * u) * much)
				sh2.append(sin(TAU * u) * much)
			for j in range(into.size() - 1, -1, -1):
				pts.append(into[j])
				nrm.append(Vector2.ZERO)
				sh1.append(0.0)
				sh2.append(0.0)
			pts.append(to)
			nrm.append(Vector2.ZERO)
			sh1.append(0.0)
			sh2.append(0.0)
		way += gap
		if i == n:
			break
		# Through the knot: the lead in, across the axis and back from
		# crossing to crossing, and the lead out.
		var kn: Dictionary = stops[i][0]
		var who: int = stops[i][1]
		var d := 1.0 if who == 0 else float(kn.dir_b)
		var half: float = kn.half
		var pitch := KNOT_PITCH * wd
		var lead := KNOT_LEAD * pitch
		var m: int = kn.m
		var offs := PackedFloat32Array()
		for j in range(1, KNOT_LEAD_STEPS):
			offs.append(-half + lead * float(j) / float(KNOT_LEAD_STEPS))
		var at := PackedInt32Array()
		for q in m:
			at.append(pts.size() + offs.size())
			var cross := -half + lead + float(q) * pitch
			offs.append(cross)
			if q < m - 1:
				for j in range(1, KNOT_STEPS):
					offs.append(cross + pitch * float(j) / float(KNOT_STEPS))
		for j in range(1, KNOT_LEAD_STEPS + 1):
			offs.append(half - lead + lead * float(j) / float(KNOT_LEAD_STEPS))
		for v in offs:
			pts.append((kn.c as Vector2) + (kn.x as Vector2) * v * d + (kn.y as Vector2) * knot_off(kn, who, v * d, wd))
			nrm.append(Vector2.ZERO)
			sh1.append(0.0)
			sh2.append(0.0)
		marks[kn.k] = at
		way += 2.0 * half
	_base = pts
	_nrm = nrm
	_sh1 = sh1
	_sh2 = sh2
	_hz = clampf(SWING_SPAN / maxf(way, 1.0), SWING_SLOW, SWING_FAST)

## The line as drawn: where the rope lies, the swing laid on its straight
## stretches, and while its knots have just changed, the way from the line it
## had (point for point by how far along each lies).
func polyline() -> PackedVector2Array:
	if not _line_ok:
		_line = _base.duplicate()
		if _a1 != 0.0 or _a2 != 0.0:
			for i in _line.size():
				var by := _a1 * _sh1[i] + _a2 * _sh2[i]
				if by != 0.0:
					_line[i] += _nrm[i] * by
		if _morph < 1.0 and _old.size() >= 2 and _line.size() >= 2:
			# Eased with a little spring, so a knot cinches in.
			var u := _morph - 1.0
			var e := 1.0 + 1.9 * u * u * u + 0.9 * u * u
			var here := lengths(_line)
			var total: float = here[here.size() - 1]
			var old_total: float = _old_cum[_old_cum.size() - 1]
			var k := 1
			for i in _line.size():
				var s := here[i] / maxf(total, 1.0) * old_total
				while k < _old_cum.size() - 1 and _old_cum[k] < s:
					k += 1
				var seg := _old_cum[k] - _old_cum[k - 1]
				var f := clampf((s - _old_cum[k - 1]) / seg, 0.0, 1.0) if seg > 0.0 else 0.0
				_line[i] = _old[k - 1].lerp(_old[k], f).lerp(_line[i], e)
			# Half way between two lines is neither: whatever corners the
			# blend has are rounded off while it lasts.
			var soft := sin(PI * _morph) * 0.5
			for it in 2:
				var last := _line[0]
				for i in range(1, _line.size() - 1):
					var was := _line[i]
					_line[i] = was.lerp((last + _line[i + 1]) * 0.5, soft)
					last = was
		_cum = lengths(_line)
		_line_ok = true
	return _line

func cum() -> PackedFloat32Array:
	polyline()
	return _cum

func total() -> float:
	var c := cum()
	return c[c.size() - 1]

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
func hits(other, near: Vector2, radius: float) -> Array:
	var la := polyline()
	var ca := cum()
	var lb: PackedVector2Array = other.polyline()
	var cb: PackedFloat32Array = other.cum()
	var out: Array = []
	var r2 := radius * radius
	var ib := PackedInt32Array()
	for v in lb.size() - 1:
		if Geometry2D.get_closest_point_to_segment(near, lb[v], lb[v + 1]).distance_squared_to(near) <= r2:
			ib.append(v)
	if ib.is_empty():
		return out
	for u in la.size() - 1:
		if Geometry2D.get_closest_point_to_segment(near, la[u], la[u + 1]).distance_squared_to(near) > r2:
			continue
		for v in ib:
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
		# Where the line turns tighter than the band is wide, the band's inner
		# side stops at the point the line turns about: drawn its full width
		# there it would cross itself and show as a torn fold.
		var most := INF
		var inner := 0.0
		if i > 0 and i < n - 1:
			var d1 := line[i] - line[i - 1]
			var d2 := line[i + 1] - line[i]
			var cr := d1.cross(d2)
			var dot := d1.dot(d2)
			if absf(cr) > 0.05 * absf(dot) or dot < 0.0:
				most = 0.46 * (d1.length() + d2.length()) / absf(atan2(cr, dot))
				inner = signf(cr) * signf(nm.dot(Vector2(-t.y, t.x)))
		# 0: nm points away from the light (the stops as given), 1: toward it.
		var flip := smoothstep(-0.35, 0.35, nm.dot(LIGHT))
		var at := line[i] + off
		for j in m:
			var out := wide[j]
			if out * inner > most:
				out = most * inner
			vs[w] = at + nm * out
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
