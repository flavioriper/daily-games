extends RefCounted

## The caterpillar, as builder shapes rather than as a Control: Caterpillar's
## walk drawn as the creature that walked it. The body is the one thing the
## player draws on that board and it changes on every square, so it is baked
## into the board's mesh with everything else -- a Control per segment would
## be sixty-four nodes -- and the face on its head is `Face.face_parts`, the
## family's own, baked in beside it.
##
## Four parts, each a fraction of the cell `s`:
##   body()      -- one soft tube along a smoothed walk (round bends, a
##                  pointed tail), shaded away from the light under a lit band,
##                  with a crease between segments, two spots and a shine on
##                  each, a soft shadow and a stubby pair of legs under it.
##   segment()   -- a short piece of that tube, which the board pops out on
##                  its own when the walk is cut back.
##   head()      -- a bigger round with the face on it and antennae pointing
##                  the way it is going, swaying, each tipped in sun.
##   butterfly() -- what the solve turns it into: a forewing in flower and a
##                  hindwing in sun on each side, spotted, beating as a scale
##                  across, on a segmented ink body with curled feelers.
##
## First ported from the canvas mock
## (docs/brainstorm/concepts.html#caterpillar), redrawn in the polish of
## 2026-09-26; the body was a string of round beads on a thin tube until
## 2026-10-02, when it became one smooth creature (players read the beads as
## an old browser game). The menu card draws the same parts with the same calls.
## Spec: docs/superpowers/specs/2026-09-25-caterpillar-flat-design.md, section 7
## and the amendment at its end.

const Pal = preload("res://core/palette.gd")
const Face = preload("res://ui/faces/face.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

## The body, one soft tube rather than a string of beads: its half-width and
## the deep outline beyond it, in cells; the lit band along its back (its
## half-width against the body's) and how far it leans toward the light, and
## each segment's own short shine on that band, likewise.
const BODY_HW := 0.31
const OUTLINE := 0.045
const BAND := 0.56
const BAND_LEAN := 0.1
const SHINE := 0.12
const SHINE_LONG := 0.3
const SHINE_LEAN := 0.17
const SHINE_AHEAD := 0.2
const SHINE_ALPHA := 0.38
## Under the band the tube is shaded on the side away from the light: the
## sunlit body over a deeper base, its half-width against the body's and its
## lean, in cells.
const LIT := 0.84
const LIT_LEAN := 0.05
const SHADE := 0.4
## Where the light comes from, top left, as the way a band leans.
const LIGHT := Vector2(-0.68, -0.73)
## The creases between segments, against the body's half-width: how far
## across they reach and how far they bow toward the tail; their width in
## cells and their ink.
const CREASE := 0.78
const CREASE_BOW := 0.22
const CREASE_W := 0.03
const CREASE_ALPHA := 0.42
## Points along each segment's stretch of the centreline.
const STEPS := 6
## How much of a segment's width its pop-in carries: a fresh segment swells
## the tube a little instead of pinching it.
const POP_W := 0.25
## A segment's radius (the shadow, the legs and a cut segment's pop are
## sized by it), the tail's three tapers, and how sharp its tip is.
const SEG_R := 0.33
const TAIL := [0.52, 0.76, 0.92]
const TIP := 0.75
## The two spots on a segment's back: their offset across it and radius,
## both against the body's half-width.
const SPOT_OUT := 0.46
const SPOT_R := 0.12
const SPOT_BACK := 0.22
## A leg: where it leaves the segment and how far it reaches, against the
## segment's radius, its width and its foot, in cells.
const LEG_ROOT := 0.7
const LEG_REACH := 1.12
const LEG_W := 0.085
const FOOT_R := 0.05
## The walk: how far a leg swings along the body and how far it tucks in on
## its lift, against the segment's radius.
const LEG_STRIDE := 0.42
const LEG_TUCK := 0.22
## The shadow under a segment: its drop and alpha; the head's outline drop.
const SHADOW_DROP := 0.07
const SHADOW_ALPHA := 0.14
const RIM_DROP := 0.035
## The head: its radius, its face's radius and how far the face leans the way
## it is going, the antennae's roots, tips and width, and their knobs.
const HEAD_R := 0.39
const HEAD_FACE := 0.95
const FACE_LEAN := 0.12
const ANT_ROOT := Vector2(0.6, 0.35)
const ANT_TIP := Vector2(1.38, 0.8)
const ANT_BEND := Vector2(1.25, 0.2)
const ANT_W := 0.035
const ANT_KNOB := 0.055
## The leaf scrap in its mouth while it chews, its length in cells.
const SNACK := 0.36

## Every segment but the head, along `pts` (tail first). `scales` is each
## segment's pop-in, one Vector2 a point; `breath` its crawl, one float a
## point (1.0 still), which swells the tube there. The head's own point is in
## `pts` so the body reaches it. `glow` 0..1 a point, if given, warms a
## segment toward the paper's white (the solve's wave). `gait`, if given, is
## each segment's walk: x how far its left leg has swung forward (the right
## swings the other way), y how far through its lift the step is, both -1..1
## already scaled by how hard it is walking.
##
## The body is one tube along a smoothed centreline: each segment owns the
## stretch from the middle of the step before it to the middle of the step
## after, a curve through its square's centre (`_spine`), so a turn is a
## round bend instead of a corner, and its width runs smoothly from segment
## to segment down to a pointed tail. Over the tube: a lit band leaning to
## the light, a crease between segments, two spots and a short shine on each.
##
## `from` and `to` draw only segments [from, to) -- `to` -1 runs on through
## the head's point -- and `layer` picks the passes: 1 the shadows and legs,
## 2 the tube and what lies on it, 3 both. The board bakes the settled tail
## once and rebuilds only the stretch near the head each frame; the two meet
## flat-ended in the middle of a step, so tail-lo, head-lo, tail-hi, head-hi
## layer exactly as one call would. `marks` false leaves the creases, spots
## and shine off the tube: the board copies those from cached looks instead.
static func body(b: Face.Builder, pts: PackedVector2Array, s: float, scales: Array,
		breath: PackedFloat32Array, glow := PackedFloat32Array(), gait := PackedVector2Array(),
		from := 0, to := -1, layer := 3, marks := true) -> void:
	var n := pts.size()
	if n == 0 or from >= n:
		return
	var shadow_to := n if to < 0 else mini(to, n)
	var seg_to := n - 1 if to < 0 else mini(to, n - 1)
	if layer & 1:
		for i in range(from, shadow_to):
			var sc: Vector2 = scales[i] if i < n - 1 else Vector2.ONE
			var r := s * SEG_R * _taper(i) * (1.0 - POP_W + POP_W * sc.x)
			Scenery.soft_disc(b, seat(pts, i)[0] + Vector2(0.0, s * SHADOW_DROP), r * 1.25, r * 1.1,
				Color(Pal.TEXT, SHADOW_ALPHA))
		for i in range(from, seg_to):
			var sc: Vector2 = scales[i]
			if sc.x <= 0.01:
				continue
			var r := s * SEG_R * _taper(i) * sc.x
			var st := seat(pts, i)
			var at: Vector2 = st[0]
			var dir: Vector2 = st[1]
			var nrm := dir.orthogonal()
			var step := gait[i] if i < gait.size() else Vector2.ZERO
			for side: float in [-1.0, 1.0]:
				# A leg swinging forward is lifted: it tucks in toward the body and
				# its foot pales a little, then plants and pushes back.
				var fwd := step.x * side
				var lift := maxf(0.0, step.y * side)
				var root := at + nrm * side * r * LEG_ROOT
				var tip := at + nrm * side * r * (LEG_REACH - LEG_TUCK * lift) + dir * r * (0.12 + LEG_STRIDE * fwd)
				var bend := root.lerp(tip, 0.5) + dir * r * LEG_STRIDE * fwd * 0.3
				b.stroke(PackedVector2Array([root, bend, tip]), s * LEG_W * sc.x, Pal.LEAF_DEEP)
				b.disc(tip, s * FOOT_R * sc.x * (1.0 - 0.15 * lift), Pal.LEAF_DEEP.lerp(Pal.TEXT, 0.25).lerp(Pal.LEAF, 0.5 * lift))
	if not (layer & 2) or n < 2:
		return
	var upto := n if to < 0 else mini(to, n)
	var hw := PackedFloat32Array()
	hw.resize(n)
	for i in n:
		var sc: Vector2 = scales[i] if i < n - 1 and i < scales.size() else Vector2.ONE
		var br := breath[i] if i < breath.size() else 1.0
		hw[i] = s * BODY_HW * _taper(i) * br * (1.0 - POP_W + POP_W * clampf(sc.x, 0.0, 1.3))
	var sp := _spine(pts, hw, from, upto)
	var P: PackedVector2Array = sp[0]
	var W: PackedFloat32Array = sp[1]
	var owner: PackedInt32Array = sp[2]
	if P.size() < 2:
		return
	var N: PackedVector2Array = sp[3]
	var fill := PackedColorArray()
	var band := PackedColorArray()
	var base := PackedColorArray()
	base.resize(P.size())
	fill.resize(P.size())
	band.resize(P.size())
	for k in P.size():
		var g := glow[owner[k]] if owner[k] < glow.size() else 0.0
		fill[k] = Pal.LEAF.lerp(Pal.SURFACE, g * 0.5)
		base[k] = Pal.LEAF.lerp(Pal.LEAF_DEEP, SHADE).lerp(Pal.SURFACE, g * 0.5)
		band[k] = Pal.LEAF_LIGHT.lerp(Pal.SURFACE, g * 0.5)
	var full := s * BODY_HW
	var cap0 := from == 0
	var cap1 := to < 0
	_ribbon(b, P, N, W, _flat(Pal.LEAF_DEEP, P.size()), 1.0, s * OUTLINE, 0.0, full, cap0, cap1, 0, P.size())
	_ribbon(b, P, N, W, base, 1.0, 0.0, 0.0, full, cap0, cap1, 0, P.size())
	_ribbon(b, P, N, W, fill, LIT, 0.0, s * LIT_LEAN, full, cap0, cap1, 0, P.size())
	_ribbon(b, P, N, W, band, BAND, 0.0, s * BAND_LEAN, full, cap0, cap1, 0, P.size())
	if not marks:
		return
	# What lies on each segment: the crease where it meets the one before,
	# its two spots and its shine.
	for i in range(from, upto):
		var sc: Vector2 = scales[i] if i < n - 1 and i < scales.size() else Vector2.ONE
		if sc.x <= 0.01:
			continue
		var w := hw[i] * minf(sc.x, 1.0)
		var g := glow[i] if i < glow.size() else 0.0
		if i > 0 and pts[i].distance_to(pts[i - 1]) > 0.5 and g < 0.5:
			crease(b, pts[i - 1], pts[i], w, s)
		if i < n - 1:
			var st := seat(pts, i)
			decal(b, st[0], st[1], w, s)

## The crease where the segment from `a` to `z` begins: a short line across
## the step's middle, bowed toward the tail, `w` the body's half-width there.
static func crease(b: Face.Builder, a: Vector2, z: Vector2, w: float, s: float) -> void:
	var at := (a + z) * 0.5
	var t := (z - a).normalized()
	var line := PackedVector2Array()
	for q in 7:
		var v := -1.0 + 2.0 * float(q) / 6.0
		line.append(at + t.orthogonal() * v * CREASE * w - t * CREASE_BOW * w * (1.0 - v * v))
	b.stroke(line, s * CREASE_W * w / (s * BODY_HW), Color(Pal.LEAF_DEEP, CREASE_ALPHA), false, false)

## A segment's two spots and its shine, on its seat `at` facing `dir`, `w`
## the body's half-width there; both lean toward the light like the band.
static func decal(b: Face.Builder, at: Vector2, dir: Vector2, w: float, s: float) -> void:
	var nrm := dir.orthogonal()
	var lean := nrm * nrm.dot(LIGHT) * s * BAND_LEAN * w / (s * BODY_HW)
	for side: float in [-1.0, 1.0]:
		b.disc(at + lean * 0.4 + nrm * side * SPOT_OUT * w - dir * SPOT_BACK * w, SPOT_R * w, Pal.SUN)
	var glint := Face.Builder.ring(Vector2.ZERO, SHINE_LONG * w, SHINE * w)
	b.fan(Transform2D(dir.angle(), at + lean * SHINE_LEAN / BAND_LEAN + dir * SHINE_AHEAD * w) * glint,
		Color(1.0, 1.0, 1.0, SHINE_ALPHA))

## One cut segment popping out where it stood: a short piece of the tube,
## outlined, banded and spotted, at `at` facing `dir`, `r` its radius (the
## board's SEG_R), scaled by `sc`.
static func segment(b: Face.Builder, at: Vector2, dir: Vector2, r: float, sc: Vector2, fill: Color, alpha := 1.0) -> void:
	var xf := Transform2D(dir.angle(), sc, 0.0, at)
	var w := r * BODY_HW / SEG_R
	var line := PackedVector2Array([xf * Vector2(-w * 0.55, 0.0), xf * Vector2(w * 0.55, 0.0)])
	var k := sc.y
	b.stroke(line, 2.0 * (w + r * OUTLINE / SEG_R) * k, Color(Pal.LEAF_DEEP, alpha))
	b.stroke(line, 2.0 * w * k, Color(fill, alpha))
	var nrm := Vector2.from_angle(dir.angle()).orthogonal()
	var lean := nrm * nrm.dot(LIGHT) * w * BAND_LEAN / BODY_HW * k
	b.stroke(PackedVector2Array([line[0] + lean, line[1] + lean]), 2.0 * w * BAND * k, Color(Pal.LEAF_LIGHT, alpha))
	for side: float in [-1.0, 1.0]:
		b.disc(at + lean * 0.4 + nrm * side * SPOT_OUT * w * k, SPOT_R * w * k, Color(Pal.SUN, alpha))

## Segment `i`'s seat on the smoothed centreline and the way it faces there:
## where its legs, spots and shadow sit (a turn's seat is inside the corner).
static func seat(pts: PackedVector2Array, i: int) -> Array:
	var n := pts.size()
	if i <= 0 or i >= n - 1:
		return [pts[clampi(i, 0, n - 1)], _dir(pts, i)]
	var a := (pts[i - 1] + pts[i]) * 0.5
	var e := (pts[i] + pts[i + 1]) * 0.5
	var at := a * 0.25 + pts[i] * 0.5 + e * 0.25
	return [at, (e - a).normalized() if a.distance_to(e) > 0.01 else _dir(pts, i)]

## The centreline of segments [from, upto) of `pts`, `hw` each one's
## half-width: points, the half-width at each, which segment each belongs to
## and the normal there. A segment runs from the middle of the step before it
## (its tail's tip, for the first) to the middle of the step after it (the
## head's centre, for the last), a quadratic through its own centre; its
## width eases from the average with its neighbour at each end to its own in
## the middle.
static func _spine(pts: PackedVector2Array, hw: PackedFloat32Array, from: int, upto: int) -> Array:
	var n := pts.size()
	var P := PackedVector2Array()
	var W := PackedFloat32Array()
	var owner := PackedInt32Array()
	var N := PackedVector2Array()
	var last_n := Vector2(0.0, 1.0)
	for i in range(from, upto):
		var a := pts[0] if i == 0 else (pts[i - 1] + pts[i]) * 0.5
		var e := pts[i] if i == n - 1 else (pts[i] + pts[i + 1]) * 0.5
		var c := pts[i] if i > 0 and i < n - 1 else a.lerp(e, 0.5)
		var wa := hw[0] * TIP if i == 0 else (hw[i - 1] + hw[i]) * 0.5
		var we := hw[i] if i == n - 1 else (hw[i] + hw[i + 1]) * 0.5
		var last := i == upto - 1
		# A straight segment of even width needs only its ends and middle.
		var steps := STEPS
		if absf((c - a).cross(e - c)) < 0.01 and absf(wa - hw[i]) < 0.05 and absf(we - hw[i]) < 0.05:
			steps = 2
		for k in steps + (1 if last else 0):
			var u := float(k) / steps
			var v := 1.0 - u
			var p := a * (v * v) + c * (2.0 * u * v) + e * (u * u)
			if not P.is_empty() and P[P.size() - 1].distance_squared_to(p) < 0.04 and not (last and k == steps):
				continue
			var x := u * 2.0 if u < 0.5 else u * 2.0 - 1.0
			x = x * x * (3.0 - 2.0 * x)
			# The normal from the curve's own slope, so two stretches built apart
			# meet on the same edge.
			var d := (c - a) * v + (e - c) * u
			if d.length_squared() > 1e-6:
				last_n = d.normalized().orthogonal()
			N.append(last_n)
			P.append(p)
			W.append(lerpf(wa, hw[i], x) if u < 0.5 else lerpf(hw[i], we, x))
			owner.append(i)
	return [P, W, owner, N]

static func _flat(c: Color, n: int) -> PackedColorArray:
	var out := PackedColorArray()
	out.resize(n)
	out.fill(c)
	return out

## A strip along points [a, z) of `P`: `k` times the half-width `W` plus
## `add` either side, coloured per point, leaning `lean` toward the light
## (scaled by how wide the body is there against `full`), feathered along
## both sides like the Builder's stroke, its ends round when `cap0`/`cap1`
## and flat otherwise (where the tail's mesh meets the live stretch's).
static func _ribbon(b: Face.Builder, P: PackedVector2Array, N: PackedVector2Array, W: PackedFloat32Array,
		cols: PackedColorArray, k: float, add: float, lean: float, full: float, cap0: bool, cap1: bool,
		a: int, z: int) -> void:
	var m := z - a
	if m < 2:
		return
	var base := b.verts.size()
	var vs := PackedVector2Array()
	var cs := PackedColorArray()
	vs.resize(m * 4)
	cs.resize(m * 4)
	var centres := PackedVector2Array()
	centres.resize(m)
	var halves := PackedFloat32Array()
	halves.resize(m)
	for j in m:
		var i := a + j
		var nrm := N[i]
		var c := P[i] + nrm * nrm.dot(LIGHT) * lean * W[i] / full
		var half := W[i] * k + add
		centres[j] = c
		halves[j] = half
		var w := j * 4
		var col := cols[i]
		vs[w] = c - nrm * (half + Face.FEATHER)
		vs[w + 1] = c - nrm * half
		vs[w + 2] = c + nrm * half
		vs[w + 3] = c + nrm * (half + Face.FEATHER)
		cs[w] = Color(col, 0.0)
		cs[w + 1] = col
		cs[w + 2] = col
		cs[w + 3] = Color(col, 0.0)
	b.verts.append_array(vs)
	b.cols.append_array(cs)
	var ix := PackedInt32Array()
	ix.resize((m - 1) * 18)
	var w := 0
	for j in m - 1:
		var p := base + j * 4
		var q := p + 4
		for e in 3:
			ix[w] = p + e
			ix[w + 1] = q + e
			ix[w + 2] = q + e + 1
			ix[w + 3] = p + e
			ix[w + 4] = q + e + 1
			ix[w + 5] = p + e + 1
			w += 6
	b.idx.append_array(ix)
	if cap0:
		_cap(b, centres[0], halves[0], -(P[a + 1] - P[a]).normalized(), cols[a])
	if cap1:
		_cap(b, centres[m - 1], halves[m - 1], (P[z - 1] - P[z - 2]).normalized(), cols[z - 1])

## A round end: the half disc beyond `at` facing `out`, feathered.
static func _cap(b: Face.Builder, at: Vector2, r: float, out: Vector2, col: Color) -> void:
	var ang := out.angle()
	var arc := Face.Builder.arc_points(at, r, ang - PI * 0.5, ang + PI * 0.5)
	arc.append(at)
	b.fan(arc, col)

## The tail's segments taper to its tip.
static func _taper(i: int) -> float:
	return TAIL[i] if i < TAIL.size() else 1.0

## Which way segment `i` of `pts` faces: from the one before to the one after.
static func _dir(pts: PackedVector2Array, i: int) -> Vector2:
	var a := pts[maxi(i - 1, 0)]
	var z := pts[mini(i + 1, pts.size() - 1)]
	return (z - a).normalized() if a.distance_to(z) > 0.01 else Vector2(1.0, 0.0)

## The head at `at`, facing `dir` (a unit vector), `grow` its breath and
## `squash` its munch, with the family's face in `expr` at eye level `eye`.
## `sway` swings the antennae, in radians, and `snack` 0..1 is how much of a
## leaf scrap it still has in its mouth while it chews.
static func head(b: Face.Builder, at: Vector2, dir: Vector2, s: float, grow: float,
		squash: Vector2, expr: int, eye: float, sway := 0.0, snack := 0.0) -> void:
	var r := s * HEAD_R * grow
	var xf := Transform2D(0.0, squash, 0.0, at)
	Scenery.soft_disc(b, at + Vector2(0.0, s * SHADOW_DROP * 1.3), r * 1.2, r * 1.0, Color(Pal.TEXT, SHADOW_ALPHA))
	var root := dir * r * 0.9
	for side: float in [-1.0, 1.0]:
		var nrm := Vector2(-dir.y, dir.x) * side
		var a := root * ANT_ROOT.x + nrm * r * ANT_ROOT.y
		var tip := (root * ANT_TIP.x + nrm * r * ANT_TIP.y - a).rotated(sway * side) + a
		var bend := (root * ANT_BEND.x + nrm * r * ANT_BEND.y - a).rotated(sway * side * 0.5) + a
		var line := Face.Builder.bezier2(a, bend, tip, 8)
		line.append(tip)
		b.stroke(xf * line, s * ANT_W, Pal.LEAF_DEEP)
		b.fan(xf * Face.Builder.ring(tip, s * ANT_KNOB, s * ANT_KNOB), Pal.SUN)
		b.fan(xf * Face.Builder.ring(tip - Vector2(1.0, 1.0) * s * ANT_KNOB * 0.3, s * ANT_KNOB * 0.35,
			s * ANT_KNOB * 0.35), Pal.SUN_TILE)
	b.fan(xf * Face.Builder.ring(Vector2(0.0, s * RIM_DROP), r, r), Pal.LEAF_DEEP)
	b.fan(xf * Face.Builder.ring(Vector2.ZERO, r * 0.93, r * 0.93), Pal.LEAF)
	b.fan(xf * Face.Builder.ring(Vector2(0.0, r * 0.12), r * 0.78, r * 0.7), Pal.LEAF.lerp(Pal.LEAF_LIGHT, 0.45))
	b.fan(xf * Face.Builder.ring(Vector2(-0.34, -0.5) * r, r * 0.26, r * 0.14), Color(1.0, 1.0, 1.0, SHINE_ALPHA))
	var face := Face.Builder.new()
	Face.face_parts(face, r * HEAD_FACE, dir * r * FACE_LEAN, Pal.TEXT, eye, expr)
	_append(b, face, xf)
	if snack > 0.01:
		var mouth := dir * r * FACE_LEAN + Vector2(r * 0.12, r * 0.36)
		scrap(b, xf * mouth, s * SNACK * sqrt(snack), -0.5 + 0.4 * snack)

## A torn scrap of leaf, `ln` long, at `at` turned by `ang`: what the head
## holds while it chews.
static func scrap(b: Face.Builder, at: Vector2, ln: float, ang: float) -> void:
	var xf := Transform2D(ang, at)
	var w := ln * 0.62
	var pts := Face.Builder.bezier2(Vector2(-ln * 0.5, 0.0), Vector2(-ln * 0.1, -w), Vector2(ln * 0.5, -w * 0.1), 8)
	pts.append(Vector2(ln * 0.32, w * 0.15))
	pts.append(Vector2(ln * 0.42, w * 0.32))
	pts.append(Vector2(ln * 0.18, w * 0.36))
	pts.append_array(Face.Builder.bezier2(Vector2(ln * 0.05, w * 0.5), Vector2(-ln * 0.3, w * 0.55), Vector2(-ln * 0.5, 0.0), 6))
	var under := PackedVector2Array()
	for p in pts:
		under.append(p * 1.14)
	b.polygon(xf * under, Pal.LEAF_DEEP)
	b.polygon(xf * pts, Pal.LEAF_LIGHT)
	b.stroke(xf * PackedVector2Array([Vector2(-ln * 0.42, 0.0), Vector2(ln * 0.3, -w * 0.12)]), maxf(ln * 0.07, 1.0), Pal.LEAF)

## The butterfly at `at`, `w` its span's half, `beat` 0..1 how open its wings
## are, `lean` its tilt.
static func butterfly(b: Face.Builder, at: Vector2, w: float, beat: float, lean: float, alpha := 1.0) -> void:
	var xf := Transform2D(lean, at)
	for side: float in [-1.0, 1.0]:
		var wing := xf * Transform2D(0.0, Vector2(side * beat, 1.0), 0.0, Vector2.ZERO)
		# The forewing, a teardrop reaching up and out; the hindwing rounder,
		# down and out. Each is a deep rim under a lighter face.
		var fore := _wing(Vector2(0.05, -0.05), Vector2(1.0, -0.95), Vector2(1.1, -0.2), 0.85)
		var hind := _wing(Vector2(0.05, 0.05), Vector2(0.75, 0.75), Vector2(0.35, 0.95), 0.5)
		b.polygon(wing * _scaled(hind, w * 1.06), Color(Pal.SUN_DEEP, alpha))
		b.polygon(wing * _scaled(hind, w * 0.92), Color(Pal.SUN_RAY, alpha))
		b.polygon(wing * _scaled(fore, w * 1.05), Color(Pal.FLOWER_DEEP, alpha))
		b.polygon(wing * _scaled(fore, w * 0.9), Color(Pal.FLOWER, alpha))
		b.fan(wing * Face.Builder.ring(Vector2(0.62, -0.5) * w, w * 0.14, w * 0.14), Color(Pal.SURFACE, 0.9 * alpha))
		b.fan(wing * Face.Builder.ring(Vector2(0.4, -0.25) * w, w * 0.07, w * 0.07), Color(Pal.SURFACE, 0.8 * alpha))
		b.fan(wing * Face.Builder.ring(Vector2(0.42, 0.45) * w, w * 0.1, w * 0.1), Color(Pal.SUN_DEEP, alpha))
		var feeler := Face.Builder.bezier2(Vector2(side * 0.03, -0.3) * w, Vector2(side * 0.12, -0.75) * w, Vector2(side * 0.32, -0.82) * w, 6)
		feeler.append(Vector2(side * 0.32, -0.82) * w)
		b.stroke(xf * feeler, w * 0.045, Color(Pal.TEXT, alpha))
		b.fan(xf * Face.Builder.ring(Vector2(side * 0.33, -0.83) * w, w * 0.06, w * 0.06), Color(Pal.TEXT, alpha))
	for k in 3:
		var y := (-0.22 + 0.2 * float(k)) * w
		b.fan(xf * Face.Builder.ring(Vector2(0.0, y), w * (0.11 - 0.015 * k), w * 0.13), Color(Pal.TEXT, alpha))

## A wing outline from `root` round `far` to `back`, `bulge` its fullness.
static func _wing(root: Vector2, far: Vector2, back: Vector2, bulge: float) -> PackedVector2Array:
	var out := far.orthogonal().normalized() * bulge
	var pts := Face.Builder.bezier3(root, root.lerp(far, 0.4) + out * 0.6, far + out * 0.35, far, 10)
	pts.append_array(Face.Builder.bezier3(far, far + (back - far) * 0.2 - out * 0.4, back + (far - back) * 0.3, back, 8))
	pts.append_array(Face.Builder.bezier2(back, back.lerp(root, 0.5) + (back - far).normalized() * 0.08, root, 6))
	return pts

static func _scaled(pts: PackedVector2Array, k: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(p * k)
	return out

## Copies `src`'s triangles into `b` through `xf`.
static func _append(b: Face.Builder, src: Face.Builder, xf: Transform2D) -> void:
	var base := b.verts.size()
	for i in src.verts.size():
		b.verts.append(xf * src.verts[i])
		b.cols.append(src.cols[i])
	for i in src.idx:
		b.idx.append(base + i)
