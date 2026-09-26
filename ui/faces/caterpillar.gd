extends RefCounted

## The caterpillar, as builder shapes rather than as a Control: Caterpillar's
## walk drawn as the creature that walked it. The body is the one thing the
## player draws on that board and it changes on every square, so it is baked
## into the board's mesh with everything else -- a Control per segment would
## be sixty-four nodes -- and the face on its head is `Face.face_parts`, the
## family's own, baked in beside it.
##
## Four parts, each a fraction of the cell `s`:
##   body()      -- a soft shadow, a stubby pair of legs out to either side of
##                  every segment, a tube through the segment centres and a
##                  round segment on every square, alternating leaf and light,
##                  each with two sun spots along its back; the last two taper.
##   segment()   -- one of those rounds, which the board also pops out on its
##                  own when the walk is cut back.
##   head()      -- a bigger round with the face on it and antennae pointing
##                  the way it is going, swaying, each tipped in sun.
##   butterfly() -- what the solve turns it into: a forewing in flower and a
##                  hindwing in sun on each side, spotted, beating as a scale
##                  across, on a segmented ink body with curled feelers.
##
## First ported from the canvas mock
## (docs/brainstorm/concepts.html#caterpillar), redrawn in the polish of
## 2026-09-26. The menu card draws the same parts with the same calls.
## Spec: docs/superpowers/specs/2026-09-25-caterpillar-flat-design.md, section 7
## and the amendment at its end.

const Pal = preload("res://core/palette.gd")
const Face = preload("res://ui/faces/face.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

## The tube under the segments, its deep outline and its fill, in cells.
const TUBE_DEEP := 0.56
const TUBE := 0.47
## A segment's radius, the tail's two tapers, the drop of its deep rim, how
## far its face shrinks inside that rim, and its shine.
const SEG_R := 0.33
const TAIL := [0.7, 0.86]
const RIM_DROP := 0.035
const FACE_IN := 0.9
const SHINE_ALPHA := 0.4
## The two spots along a segment's back: their offset across it and radius,
## both against the segment's radius.
const SPOT_OUT := 0.42
const SPOT_R := 0.13
## A leg: where it leaves the segment and how far it reaches, against the
## segment's radius, its width and its foot, in cells.
const LEG_ROOT := 0.7
const LEG_REACH := 1.12
const LEG_W := 0.09
const FOOT_R := 0.05
## The walk: how far a leg swings along the body and how far it tucks in on
## its lift, against the segment's radius.
const LEG_STRIDE := 0.42
const LEG_TUCK := 0.22
## The shadow under a segment: its drop and alpha.
const SHADOW_DROP := 0.07
const SHADOW_ALPHA := 0.14
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
## point (1.0 still), which swells the segment. The head's own point is in
## `pts` so the tube reaches it. `glow` 0..1 a point, if given, warms a
## segment toward the paper's white (the solve's wave). `gait`, if given, is
## each segment's walk: x how far its left leg has swung forward (the right
## swings the other way), y how far through its lift the step is, both -1..1
## already scaled by how hard it is walking.
static func body(b: Face.Builder, pts: PackedVector2Array, s: float, scales: Array,
		breath: PackedFloat32Array, glow := PackedFloat32Array(), gait := PackedVector2Array()) -> void:
	var n := pts.size()
	if n == 0:
		return
	for i in n:
		var sc: Vector2 = scales[i] if i < n - 1 else Vector2.ONE
		if sc.x <= 0.01:
			continue
		var r := s * SEG_R * _taper(i) * sc.x
		Scenery.soft_disc(b, pts[i] + Vector2(0.0, s * SHADOW_DROP), r * 1.25, r * 1.1,
			Color(Pal.TEXT, SHADOW_ALPHA))
	for i in n - 1:
		var sc: Vector2 = scales[i]
		if sc.x <= 0.01:
			continue
		var r := s * SEG_R * _taper(i) * sc.x
		var dir := _dir(pts, i)
		var nrm := dir.orthogonal()
		var step := gait[i] if i < gait.size() else Vector2.ZERO
		for side: float in [-1.0, 1.0]:
			# A leg swinging forward is lifted: it tucks in toward the body and
			# its foot pales a little, then plants and pushes back.
			var fwd := step.x * side
			var lift := maxf(0.0, step.y * side)
			var root := pts[i] + nrm * side * r * LEG_ROOT
			var tip := pts[i] + nrm * side * r * (LEG_REACH - LEG_TUCK * lift) + dir * r * (0.12 + LEG_STRIDE * fwd)
			var bend := root.lerp(tip, 0.5) + dir * r * LEG_STRIDE * fwd * 0.3
			b.stroke(PackedVector2Array([root, bend, tip]), s * LEG_W * sc.x, Pal.LEAF_DEEP)
			b.disc(tip, s * FOOT_R * sc.x * (1.0 - 0.15 * lift), Pal.LEAF_DEEP.lerp(Pal.TEXT, 0.25).lerp(Pal.LEAF, 0.5 * lift))
	if n > 1:
		b.stroke(pts, s * TUBE_DEEP, Pal.LEAF_DEEP)
		b.stroke(pts, s * TUBE, Pal.LEAF)
	for i in n - 1:
		var sc: Vector2 = scales[i]
		if sc.x <= 0.01:
			continue
		var fill := Pal.LEAF if i % 2 == 1 else Pal.LEAF_LIGHT
		var g := glow[i] if i < glow.size() else 0.0
		segment(b, pts[i], _dir(pts, i), s * SEG_R * _taper(i) * breath[i], sc,
			fill.lerp(Pal.SURFACE, g * 0.5))

## One round: its deep rim, its face, the two sun spots across its back and
## the shine, at `at` facing `dir`, radius `r`, scaled by `sc`.
static func segment(b: Face.Builder, at: Vector2, dir: Vector2, r: float, sc: Vector2, fill: Color, alpha := 1.0) -> void:
	var xf := Transform2D(0.0, sc, 0.0, at)
	b.fan(xf * Face.Builder.ring(Vector2(0.0, r * RIM_DROP / SEG_R), r, r), Color(Pal.LEAF_DEEP, alpha))
	b.fan(xf * Face.Builder.ring(Vector2.ZERO, r * FACE_IN, r * FACE_IN), Color(fill, alpha))
	var nrm := dir.orthogonal()
	for side: float in [-1.0, 1.0]:
		var p := nrm * side * r * SPOT_OUT - Vector2(0.0, r * 0.08)
		b.fan(xf * Face.Builder.ring(p, r * SPOT_R, r * SPOT_R), Color(Pal.SUN, alpha))
	b.fan(xf * Face.Builder.ring(Vector2(-0.3, -0.38) * r, r * 0.3, r * 0.17),
		Color(1.0, 1.0, 1.0, SHINE_ALPHA * alpha))

## The last two segments taper to the tail.
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
