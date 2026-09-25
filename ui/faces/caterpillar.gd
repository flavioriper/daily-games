extends RefCounted

## The caterpillar, as builder shapes rather than as a Control: Caterpillar's
## walk drawn as the creature that walked it. The body is the one thing the
## player draws on that board and it changes on every square, so it is baked
## into the board's mesh with everything else -- a Control per segment would
## be sixty-four nodes -- and the face on its head is `Face.face_parts`, the
## family's own, baked in beside it.
##
## Three parts, each a fraction of the cell `s`:
##   body()      -- a tube through the segment centres, a round segment on
##                  every square, alternating leaf and light, feet under every
##                  other one; the tail's segment a little smaller.
##   head()      -- a bigger round with the face on it, antennae pointing the
##                  way it is going, each tipped in sun.
##   butterfly() -- what the solve turns it into: two pairs of wings, the fore
##                  in flower and the hind in sun, beating as a scale across.
##
## Ported number for number from the canvas mock
## (docs/brainstorm/concepts.html#caterpillar: `drawBody`, `drawHead`,
## `drawButterfly`). The menu card draws the same three with the same calls.
## Spec: docs/superpowers/specs/2026-09-25-caterpillar-flat-design.md, section 7.

const Pal = preload("res://core/palette.gd")
const Face = preload("res://ui/faces/face.gd")

## The tube under the segments, its deep outline and its fill, in cells.
const TUBE_DEEP := 0.5
const TUBE := 0.4
## A segment's radius, the tail's share of it, the drop of its deep rim, how
## far its face shrinks inside that rim, and its shine.
const SEG_R := 0.3
const TAIL := 0.82
const RIM_DROP := 0.03
const FACE_IN := 0.92
const SHINE_ALPHA := 0.35
const FOOT_R := 0.14
## The head: its radius, its face's radius and how far the face leans the way
## it is going, the antennae's roots, tips and width, and their knobs.
const HEAD_R := 0.36
const HEAD_FACE := 0.95
const FACE_LEAN := 0.12
const ANT_ROOT := Vector2(0.6, 0.35)
const ANT_TIP := Vector2(1.35, 0.75)
const ANT_BEND := Vector2(1.2, 0.2)
const ANT_W := 0.035
const ANT_KNOB := 0.05

## Every segment but the head, along `pts` (tail first). `scales` is each
## segment's pop-in, one Vector2 a point; `breath` its crawl, one float a
## point (1.0 still). The head's own point is in `pts` so the tube reaches it.
static func body(b: Face.Builder, pts: PackedVector2Array, s: float, scales: Array, breath: PackedFloat32Array) -> void:
	var n := pts.size()
	if n == 0:
		return
	if n > 1:
		b.stroke(pts, s * TUBE_DEEP, Pal.LEAF_DEEP)
		b.stroke(pts, s * TUBE, Pal.LEAF)
	for i in n - 1:
		var sc: Vector2 = scales[i]
		if sc.x <= 0.01:
			continue
		var r := s * SEG_R * (TAIL if i == 0 else 1.0) * breath[i]
		var xf := Transform2D(0.0, sc, 0.0, pts[i])
		b.fan(xf * Face.Builder.ring(Vector2(0.0, s * RIM_DROP), r, r), Pal.LEAF_DEEP)
		b.fan(xf * Face.Builder.ring(Vector2.ZERO, r * FACE_IN, r * FACE_IN),
			Pal.LEAF if i % 2 == 1 else Pal.LEAF_LIGHT)
		b.fan(xf * Face.Builder.ring(Vector2(-0.3, -0.35) * r, r * 0.3, r * 0.18),
			Color(1.0, 1.0, 1.0, SHINE_ALPHA))
		if i % 2 == 0:
			b.fan(xf * Face.Builder.ring(Vector2(-0.5, 0.9) * r, r * FOOT_R, r * FOOT_R), Pal.LEAF_DEEP)
			b.fan(xf * Face.Builder.ring(Vector2(0.5, 0.9) * r, r * FOOT_R, r * FOOT_R), Pal.LEAF_DEEP)

## The head at `at`, facing `dir` (a unit vector), `grow` its breath and
## `squash` its munch, with the family's face in `expr` at eye level `eye`.
static func head(b: Face.Builder, at: Vector2, dir: Vector2, s: float, grow: float,
		squash: Vector2, expr: int, eye: float) -> void:
	var r := s * HEAD_R * grow
	var xf := Transform2D(0.0, squash, 0.0, at)
	var root := dir * r * 0.9
	for side: float in [-1.0, 1.0]:
		var nrm := Vector2(-dir.y, dir.x) * side
		var a := root * ANT_ROOT.x + nrm * r * ANT_ROOT.y
		var tip := root * ANT_TIP.x + nrm * r * ANT_TIP.y
		var bend := root * ANT_BEND.x + nrm * r * ANT_BEND.y
		var line := Face.Builder.bezier2(a, bend, tip, 8)
		line.append(tip)
		b.stroke(xf * line, s * ANT_W, Pal.LEAF_DEEP)
		b.fan(xf * Face.Builder.ring(tip, s * ANT_KNOB, s * ANT_KNOB), Pal.SUN)
	b.fan(xf * Face.Builder.ring(Vector2(0.0, s * RIM_DROP), r, r), Pal.LEAF_DEEP)
	b.fan(xf * Face.Builder.ring(Vector2.ZERO, r * 0.93, r * 0.93), Pal.LEAF)
	var face := Face.Builder.new()
	Face.face_parts(face, r * HEAD_FACE, dir * r * FACE_LEAN, Pal.TEXT, eye, expr)
	_append(b, face, xf)

## The butterfly at `at`, `w` its span's half, `beat` 0..1 how open its wings
## are, `lean` its tilt.
static func butterfly(b: Face.Builder, at: Vector2, w: float, beat: float, lean: float, alpha := 1.0) -> void:
	var xf := Transform2D(lean, at)
	for side: float in [-1.0, 1.0]:
		var wing := Transform2D(0.0, Vector2(side * beat, 1.0), 0.0, Vector2.ZERO)
		b.fan(xf * wing * Face.Builder.ring(Vector2(0.55, -0.28) * w, w * 0.55, w * 0.42), Color(Pal.FLOWER, alpha))
		b.fan(xf * wing * Face.Builder.ring(Vector2(0.45, 0.3) * w, w * 0.34, w * 0.28), Color(Pal.SUN, alpha))
		b.fan(xf * wing * Face.Builder.ring(Vector2(0.6, -0.32) * w, w * 0.14, w * 0.14), Color(1.0, 1.0, 1.0, 0.5 * alpha))
		var feeler := Face.Builder.bezier2(Vector2(0.0, -0.38) * w, Vector2(side * 0.1, -0.7) * w, Vector2(side * 0.25, -0.78) * w, 6)
		feeler.append(Vector2(side * 0.25, -0.78) * w)
		b.stroke(xf * feeler, w * 0.05, Color(Pal.TEXT, alpha))
	b.fan(xf * Face.Builder.ring(Vector2.ZERO, w * 0.1, w * 0.42), Color(Pal.TEXT, alpha))

## Copies `src`'s triangles into `b` through `xf`.
static func _append(b: Face.Builder, src: Face.Builder, xf: Transform2D) -> void:
	var base := b.verts.size()
	for i in src.verts.size():
		b.verts.append(xf * src.verts[i])
		b.cols.append(src.cols[i])
	for i in src.idx:
		b.idx.append(base + i)
