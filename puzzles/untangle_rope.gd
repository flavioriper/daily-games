extends RefCounted

## One rope of the Untangle ring: a chain of points pinned at both pegs,
## stepped as a Verlet rope (each point keeps its own velocity, a few passes
## pull neighbours back to their spacing) and drawn as a thick twisted cord --
## a shadow, a dark edge, the body, a pale strip down it and the slanted
## grooves of a laid rope, all appended to the board's one mesh.
##
## What the physics is for. The rule is tested on the straight line between
## two holes and the picture must agree with it, so the rope is kept nearly
## taut: its rest length follows the gap between its pegs (plus a hair of
## slack), and never exceeds the rope's own length, which is what stops a peg
## dragged too far. What is left over is the life: a peg let go kicks the
## chain sideways and it whips and settles, a peg lifted takes up the slack,
## a rope pulled tight rings when it is let go. Nothing here is a tween.
##
## Spec: docs/superpowers/specs/2026-09-29-untangle-ring-design.md, section 2.

const Face = preload("res://ui/faces/face.gd")

## Points along the rope, ends included.
const SEGS := 15
const SIM_DT := 1.0 / 120.0
## Fraction of speed a point keeps each step: the cloth it lies on drags it.
const DAMP := 0.972
const ITERS := 9
## How hard a point is pulled toward the line through its neighbours.
const BEND := 0.16
## Slack over the gap between the pegs, at rest, as a fraction of it.
const SLACK := 0.004
## How fast the rest length follows its target.
const FOLLOW := 0.4

var p := PackedVector2Array()
var q := PackedVector2Array()
## The length the chain is asked to keep, in px, and the extra slack a kick
## has added on top of SLACK (a fraction, decaying).
var rest := 0.0
var extra := 0.0
## The rope's own length: the farthest its pegs can be, in px.
var length := 0.0
var _tw := 0.0

func setup(a: Vector2, b: Vector2, max_length: float, bow: float) -> void:
	length = max_length
	p.resize(SEGS)
	q.resize(SEGS)
	rest = minf(length, a.distance_to(b) * (1.0 + SLACK))
	var n := (b - a).orthogonal().normalized()
	for i in SEGS:
		var u := float(i) / (SEGS - 1)
		p[i] = a.lerp(b, u) + n * bow * sin(PI * u)
		q[i] = p[i]

## Straight and still between two points, no physics: reduce-motion, a board
## that has just been laid out, a rope restored.
func snap(a: Vector2, b: Vector2) -> void:
	rest = minf(length, a.distance_to(b) * (1.0 + SLACK))
	for i in SEGS:
		p[i] = a.lerp(b, float(i) / (SEGS - 1))
		q[i] = p[i]
	extra = 0.0

## One fixed step with the pegs at `a` and `b`.
func step(a: Vector2, b: Vector2) -> void:
	var gap := a.distance_to(b)
	var target := minf(length, gap * (1.0 + SLACK + extra))
	rest = lerpf(rest, target, FOLLOW)
	var seg := rest / (SEGS - 1)
	for i in range(1, SEGS - 1):
		var v := (p[i] - q[i]) * DAMP
		q[i] = p[i]
		p[i] += v
	p[0] = a
	p[SEGS - 1] = b
	q[0] = a
	q[SEGS - 1] = b
	for it in ITERS:
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
	for i in range(1, SEGS - 1):
		p[i] += ((p[i - 1] + p[i + 1]) * 0.5 - p[i]) * BEND

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

## The chain smoothed with a Catmull-Rom through its points, two pieces to a
## span, so a whipping rope bends round instead of kinking.
func polyline() -> PackedVector2Array:
	var out := PackedVector2Array()
	out.append(p[0])
	for i in SEGS - 1:
		var p0 := p[maxi(i - 1, 0)]
		var p1 := p[i]
		var p2 := p[i + 1]
		var p3 := p[mini(i + 2, SEGS - 1)]
		out.append(_cr(p0, p1, p2, p3, 0.5))
		out.append(p2)
	return out

static func _cr(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)

static func lengths(line: PackedVector2Array) -> PackedFloat32Array:
	var cum := PackedFloat32Array()
	cum.resize(line.size())
	for i in range(1, line.size()):
		cum[i] = cum[i - 1] + line[i - 1].distance_to(line[i])
	return cum

## The point `s` along a polyline and its unit direction there.
static func at(line: PackedVector2Array, cum: PackedFloat32Array, s: float) -> Array:
	var k := 1
	while k < cum.size() - 1 and cum[k] < s:
		k += 1
	var seg := cum[k] - cum[k - 1]
	var u := (s - cum[k - 1]) / seg if seg > 0.0 else 0.0
	var dir := (line[k] - line[k - 1])
	return [line[k - 1].lerp(line[k], clampf(u, 0.0, 1.0)), dir.normalized() if dir.length_squared() > 0.0 else Vector2.RIGHT]

## The part of a polyline from `s0` to `s1` along it.
static func slice(line: PackedVector2Array, cum: PackedFloat32Array, s0: float, s1: float) -> PackedVector2Array:
	var out := PackedVector2Array([at(line, cum, s0)[0]])
	for i in line.size():
		if cum[i] > s0 and cum[i] < s1:
			out.append(line[i])
	out.append(at(line, cum, s1)[0])
	return out

## The rope into `b`: `w` wide, in the colours of one of the board's ropes.
## `lift` (0 to 1) is how far it is off the cloth -- the shadow parts from
## it -- and `alpha` fades it in. `glow` lays a warm light over the body for
## the solve's wave, `from`..`to` the stretch of it (fractions of its length)
## the light covers.
func draw(b: Face.Builder, w: float, fill: Color, deep: Color, light: Color, lift := 0.0, alpha := 1.0,
		glow: Color = Color(0, 0, 0, 0), from := 0.0, to := 0.0, tight := 0.0) -> void:
	var line := polyline()
	var cum := lengths(line)
	var total: float = cum[cum.size() - 1]
	if total <= 1.0 or alpha <= 0.0:
		return
	var thick := w * (1.0 - 0.12 * tight)
	# The shadow falls down and to the right, the further the higher the rope
	# is lifted; a lifted rope's is also fainter and wider.
	var off := Vector2(0.10, 0.20) * w * (1.0 + 2.6 * lift)
	var dark := PackedVector2Array()
	for pt in line:
		dark.append(pt + off)
	b.stroke(dark, thick * (1.0 + 0.3 * lift), Color(0.23, 0.19, 0.16, (0.17 - 0.05 * lift) * alpha), false, false)
	b.stroke(line, thick, Color(deep, alpha))
	b.stroke(line, thick * 0.8, Color(fill, alpha), false, false)
	# The pale strip down the rope, the light on its round back.
	var hi := PackedVector2Array()
	for pt in line:
		hi.append(pt)
	b.stroke(hi, thick * 0.2, Color(light, 0.55 * alpha), false, false)
	_grooves(b, line, cum, thick, deep, light, alpha)
	if glow.a > 0.0 and to > from:
		var seg := slice(line, cum, total * from, total * to)
		if seg.size() >= 2:
			b.stroke(seg, thick * 0.8, Color(glow, glow.a * alpha), false, false)

## The laid rope's grooves: a slanted stroke across the body every
## `w * 0.62` along it, dark, with a pale one beside it.
func _grooves(b: Face.Builder, line: PackedVector2Array, cum: PackedFloat32Array, w: float, deep: Color, light: Color, alpha: float) -> void:
	var total: float = cum[cum.size() - 1]
	var step := w * 0.66
	var half := w * 0.4
	var dark := Color(deep, 0.6 * alpha)
	var pale := Color(light, 0.55 * alpha)
	var s := step * 0.5
	var k := 1
	while s < total:
		while k < cum.size() - 1 and cum[k] < s:
			k += 1
		var seg := cum[k] - cum[k - 1]
		var pt := line[k - 1].lerp(line[k], (s - cum[k - 1]) / seg if seg > 0.0 else 0.0)
		var tn := (line[k] - line[k - 1]).normalized()
		var d := (tn * 0.95 + tn.orthogonal()) * half
		_quad(b, pt - d, pt + d, w * 0.15, dark)
		var shift := tn * (w * 0.17)
		_quad(b, pt - d + shift, pt + d + shift, w * 0.09, pale)
		s += step

## A short straight stroke as one quad with a feathered rim, the same shape
## as Builder.stroke's segment, written out: a rope has hundreds of these.
static func _quad(b: Face.Builder, a: Vector2, c: Vector2, width: float, colour: Color) -> void:
	var t := (c - a).normalized()
	var nrm := Vector2(-t.y, t.x)
	var w := nrm * (width * 0.5)
	var f := nrm * (width * 0.5 + Face.FEATHER)
	var clear := Color(colour, 0.0)
	var base := b.verts.size()
	for end in [a, c]:
		b.verts.append(end - f); b.cols.append(clear)
		b.verts.append(end - w); b.cols.append(colour)
		b.verts.append(end + w); b.cols.append(colour)
		b.verts.append(end + f); b.cols.append(clear)
	for k in 3:
		b.idx.append_array([base + k, base + 4 + k, base + 5 + k, base + k, base + 5 + k, base + k + 1])
