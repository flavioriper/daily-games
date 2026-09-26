extends RefCounted

## Sunbeam's drawing: the greenhouse's pieces as builder shapes, shared by the
## board (puzzles/sunbeam2d.gd) and its menu card (ui/menu/card_art.gd), so
## the two cannot drift apart. A drawing and not a character: nothing here has
## a face, which is the rule for a board whose pieces are marks (CLAUDE.md,
## "The flat cast is a shared drawing").
##
## Everything is in pixels, sized off `s`, the cell. Ported from the concept
## page's mock (docs/brainstorm/concepts.html#sunbeam).

const Pal = preload("res://core/palette.gd")
const Face = preload("res://ui/faces/face.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

## A cup's bend reaches this far past its two cells' centres, in cells: a
## little under half, so a cup backed against the floor's edge keeps its
## copper inside the frame. The beam's arc round it uses the same figure.
const CUP_BULGE := 0.36
## A cup's arms run this far toward its mouth past the two centres.
const CUP_ARM := 0.3
## The beam's three passes: glow, halo and core, as widths in cells and alphas.
const BEAM_GLOW := Vector2(0.42, 0.22)
const BEAM_HALO := Vector2(0.2, 0.5)
const BEAM_CORE := Vector2(0.07, 1.0)

## A brass mirror standing at `at`: its shadow, the round mount (gold when a
## hint pinned it), the glass on its diagonal and two rivets. `lift` 0 to 1
## raises it off the floor while a finger holds it.
static func mirror(b: Face.Builder, at: Vector2, s: float, slash: bool, lift := 0.0, pinned := false, scale := 1.0) -> void:
	var r := s * 0.33 * scale * (1.0 + lift * 0.06)
	var up := Vector2(0.0, -lift * 6.0)
	Scenery.soft_disc(b, at + Vector2(0.0, s * 0.06 + lift * 10.0), r * 1.15, r * 0.95, Color(Pal.TEXT, 0.2 + lift * 0.08))
	var c := at + up
	b.disc(c + Vector2(0.0, 4.0), r, Pal.BRASS_DEEP)
	b.disc(c, r, Pal.SUN if pinned else Pal.BRASS)
	var arc := Face.Builder.arc_points(c, r, PI * 1.1, PI * 1.5)
	arc.append(c)
	b.fan(arc, Color(Pal.BRASS_HI, 0.35))
	b.disc(c, r * 0.73, Pal.BRASS.lerp(Pal.FLOOR_TILE, 0.25))
	var xf := Transform2D(-PI * 0.25 if slash else PI * 0.25, c)
	var ln := s * 0.4 * scale
	var th := s * 0.075 * scale
	b.fan(xf * Face.Builder.round_rect(Vector2(-ln, -th + 3.0), Vector2(ln * 2.0, th * 2.0), th * 0.8), Pal.MIRROR_EDGE)
	b.fan(xf * Face.Builder.round_rect(Vector2(-ln, -th), Vector2(ln * 2.0, th * 2.0), th * 0.8), Pal.MIRROR_GLASS)
	b.fan(xf * Face.Builder.round_rect(Vector2(-ln * 0.75, -th * 0.6), Vector2(ln * 0.85, th * 0.4), th * 0.2), Color(1.0, 1.0, 1.0, 0.95))
	b.disc(xf * Vector2(-ln, 0.0), s * 0.05 * scale, Pal.BRASS_DEEP)
	b.disc(xf * Vector2(ln, 0.0), s * 0.05 * scale, Pal.BRASS_DEEP)

## A cup's centreline in pixels: an arm from the first cell toward the mouth,
## the bend round the back, and the arm out of the second cell. `a` and `z`
## are the two cells' centres and `f` the direction the mouth faces.
static func cup_path(a: Vector2, z: Vector2, s: float, f: Vector2) -> PackedVector2Array:
	var mid := (a + z) * 0.5
	var u := a - mid
	var v := -f * s * CUP_BULGE
	var pts := PackedVector2Array([a + f * s * CUP_ARM])
	for k in 17:
		var q := PI * float(k) / 16.0
		pts.append(mid + u * cos(q) + v * sin(q))
	pts.append(z + f * s * CUP_ARM)
	return pts

## A copper cup along `pts` (cup_path's): its shadow, the copper and its lit
## rim, the channel the light runs in, and a brass cog on the bend.
static func cup(b: Face.Builder, pts: PackedVector2Array, s: float, f: Vector2, lift := 0.0, pinned := false) -> void:
	var up := Vector2(0.0, -lift * 6.0)
	b.stroke(_shift(pts, Vector2(0.0, 10.0 + lift * 10.0)), s * 0.34, Color(Pal.TEXT, 0.16))
	b.stroke(_shift(pts, up + Vector2(0.0, 5.0)), s * 0.3, Pal.COPPER_DEEP)
	b.stroke(_shift(pts, up), s * 0.3, Pal.SUN if pinned else Pal.COPPER)
	b.stroke(_shift(pts, up + Vector2(0.0, -s * 0.07)), s * 0.07, Pal.COPPER_HI)
	b.stroke(_shift(pts, up), s * 0.1, Pal.COPPER_DEEP.lerp(Pal.FLOOR_TILE, 0.3))
	var cog := pts[9] + up
	for i in 8:
		var d := Vector2.from_angle(float(i) * PI * 0.25)
		b.stroke(PackedVector2Array([cog + d * s * 0.06, cog + d * s * 0.11]), s * 0.05, Pal.BRASS_DEEP, false, false)
	b.disc(cog, s * 0.075, Pal.BRASS)
	b.disc(cog, s * 0.028, Pal.BRASS_DEEP)

static func _shift(pts: PackedVector2Array, by: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(pts.size())
	for i in pts.size():
		out[i] = pts[i] + by
	return out

## The beam along `pts` (pixels), in three passes. A run is cut at every
## sharp turn and stroked on its own, because a stroke's joint pinches at a
## right angle; the caps meet under the mirror that turned it.
static func beam(b: Face.Builder, pts: PackedVector2Array, s: float, alpha := 1.0) -> void:
	if pts.size() < 2:
		return
	var runs: Array = []
	var run := PackedVector2Array([pts[0]])
	for i in range(1, pts.size()):
		run.append(pts[i])
		if i < pts.size() - 1:
			var d0 := (pts[i] - pts[i - 1]).normalized()
			var d1 := (pts[i + 1] - pts[i]).normalized()
			if d0.dot(d1) < 0.7:
				runs.append(run)
				run = PackedVector2Array([pts[i]])
	runs.append(run)
	for pass_i: Vector2 in [BEAM_GLOW, BEAM_HALO, BEAM_CORE]:
		var col := Pal.BEAM_CORE if pass_i == BEAM_CORE else Pal.BEAM
		for r: PackedVector2Array in runs:
			if r.size() >= 2 and r[0].distance_to(r[r.size() - 1]) > 0.5:
				b.stroke(r, s * pass_i.x, Color(col, pass_i.y * alpha))

## A dewdrop at `at`: a glow once lit, the drop itself (pale blue while dry,
## gold once the light has reached it) and its shine.
static func drop(b: Face.Builder, at: Vector2, s: float, lit: bool, scale := Vector2.ONE) -> void:
	var r := s * 0.17
	if lit:
		Scenery.soft_disc(b, at, s * 0.5, s * 0.5, Color(Pal.BEAM, 0.55))
	var c := at + Vector2(0.0, r * 0.2)
	var shape := _drop_shape(r)
	var xf := Transform2D(0.0, scale, 0.0, c)
	b.polygon(xf * _grow(shape, 3.0), Pal.DEW_LIT_EDGE if lit else Pal.DEW_EDGE)
	b.polygon(xf * shape, Pal.DEW_LIT if lit else Pal.DEW)
	b.ellipse(xf * Vector2(-r * 0.35, -r * 0.05), r * 0.16 * scale.x, r * 0.26 * scale.y, Color(1.0, 1.0, 1.0, 0.9))

## A drop's outline about its belly's centre, pointed up.
static func _drop_shape(r: float) -> PackedVector2Array:
	var top := Vector2(0.0, -r * 1.55)
	var pts := Face.Builder.bezier3(top, Vector2(r * 0.5, -r * 0.8), Vector2(r, -r * 0.2), Vector2(r, r * 0.25), 8)
	pts.append_array(Face.Builder.arc_points(Vector2(0.0, r * 0.25), r, 0.0, PI).slice(0, -1))
	pts.append_array(Face.Builder.bezier3(Vector2(-r, r * 0.25), Vector2(-r, -r * 0.2), Vector2(-r * 0.5, -r * 0.8), top, 8))
	return pts

## An outline pushed out by `by` along each vertex's direction from its centre.
static func _grow(pts: PackedVector2Array, by: float) -> PackedVector2Array:
	var c := Vector2.ZERO
	for p in pts:
		c += p
	c /= float(pts.size())
	var out := PackedVector2Array()
	for p in pts:
		out.append(p + (p - c).normalized() * by)
	return out

## A leaf from `root`, `ln` long, pointing along `ang`.
static func leaf(b: Face.Builder, root: Vector2, ln: float, ang: float, col: Color) -> void:
	var dir := Vector2.from_angle(ang)
	var side := dir.orthogonal() * ln * 0.42
	var tip := root + dir * ln
	var pts := Face.Builder.bezier2(root, root + dir * ln * 0.55 + side, tip, 8)
	pts.append_array(Face.Builder.bezier2(tip, root + dir * ln * 0.55 - side, root, 8))
	b.polygon(pts, col)

## A terracotta pot with three leaves in it: it stops the light.
static func pot(b: Face.Builder, at: Vector2, s: float) -> void:
	Scenery.soft_disc(b, at + Vector2(0.0, s * 0.3), s * 0.34, s * 0.09, Color(Pal.TEXT, 0.16))
	var root := at + Vector2(0.0, -s * 0.14)
	leaf(b, root, s * 0.34, -2.2, Pal.LEAF_DEEP)
	leaf(b, root, s * 0.36, -0.9, Pal.LEAF)
	leaf(b, root, s * 0.3, -1.6, Pal.LEAF_LIGHT)
	b.fan(PackedVector2Array([at + Vector2(-s * 0.26, -s * 0.1), at + Vector2(s * 0.26, -s * 0.1),
		at + Vector2(s * 0.19, s * 0.3), at + Vector2(-s * 0.19, s * 0.3)]), Pal.POT_CLAY)
	b.fan(Face.Builder.round_rect(at + Vector2(-s * 0.3, -s * 0.16), Vector2(s * 0.6, s * 0.12), s * 0.04), Pal.POT_RIM)
	b.fan(Face.Builder.round_rect(at + Vector2(-s * 0.16, -s * 0.02), Vector2(s * 0.06, s * 0.24), s * 0.03), Color(1.0, 1.0, 1.0, 0.2))

## The bud on its mound: shut and pink while it waits, glowing when the light
## reaches it with a drop still dry, and opening into five petals on the solve
## (`open` 0 to 1, overshoot allowed).
static func bud(b: Face.Builder, at: Vector2, s: float, open := 0.0, glow := false, spin := 0.0) -> void:
	var base := at + Vector2(0.0, s * 0.14)
	Scenery.soft_disc(b, base + Vector2(0.0, s * 0.2), s * 0.3, s * 0.08, Color(Pal.TEXT, 0.14))
	b.ellipse(base + Vector2(0.0, s * 0.18), s * 0.26, s * 0.1, Pal.BARK)
	b.stroke(Face.Builder.bezier2(base + Vector2(0.0, s * 0.16), base + Vector2(s * 0.04, 0.0), base + Vector2(0.0, -s * 0.12), 6),
		s * 0.05, Pal.LEAF_DEEP)
	leaf(b, base + Vector2(0.0, s * 0.08), s * 0.26, -0.4, Pal.LEAF)
	leaf(b, base + Vector2(0.0, s * 0.1), s * 0.24, -2.7, Pal.LEAF_DEEP)
	var head := base + Vector2(0.0, -s * 0.2)
	if glow:
		Scenery.soft_disc(b, head, s * 0.42, s * 0.42, Color(Pal.BEAM, 0.6))
	if open > 0.0:
		for i in 5:
			var a := float(i) * TAU / 5.0 + spin
			var petal := Face.Builder.ring(Vector2(0.0, -s * 0.16 * open), s * 0.11 * open, s * 0.17 * open)
			var col := Pal.FLOWER if i % 2 == 1 else Pal.FLOWER.lerp(Color.WHITE, 0.2)
			b.fan(Transform2D(a, head) * petal, col)
		b.disc(head, s * 0.09 * open, Pal.BEAM)
		b.disc(head, s * 0.05 * open, Pal.SUN)
	else:
		b.ellipse(head, s * 0.12, s * 0.17, Pal.FLOWER_DEEP)
		b.ellipse(head + Vector2(-s * 0.03, -s * 0.01), s * 0.08, s * 0.15, Pal.FLOWER)
		leaf(b, head + Vector2(0.0, s * 0.1), s * 0.14, -1.1, Pal.LEAF)
		leaf(b, head + Vector2(0.0, s * 0.1), s * 0.14, -2.05, Pal.LEAF)

## The gap in the glass the sun comes in by: a pale pane with an iron edge.
static func window(b: Face.Builder, at: Vector2, s: float) -> void:
	var box := Face.Builder.round_rect(at - Vector2.ONE * s * 0.42, Vector2.ONE * s * 0.84, s * 0.2)
	b.fan(_shift(box, Vector2(0.0, 4.0)), Pal.GLASS_FRAME_DEEP)
	b.fan(box, Pal.GLASS_FRAME_DEEP)
	b.fan(Face.Builder.round_rect(at - Vector2.ONE * s * 0.38, Vector2.ONE * s * 0.76, s * 0.17),
		Pal.GLASSHOUSE.lerp(Pal.BEAM, 0.35))

## The morning sun sitting in the window, its ten rays turned by `rot`.
static func sun(b: Face.Builder, at: Vector2, s: float, rot := 0.0) -> void:
	for i in 10:
		var d := Vector2.from_angle(rot + float(i) * PI / 5.0)
		var n := d.orthogonal()
		b.fan(PackedVector2Array([at + d * s * 0.22 + n * s * 0.045, at + d * s * 0.36, at + d * s * 0.22 - n * s * 0.045]), Pal.BEAM)
	b.disc(at, s * 0.2, Pal.SUN)
	b.disc(at + Vector2(-s * 0.05, -s * 0.05), s * 0.1, Pal.BEAM)

## A wooden rail from `a` to `z` (pixels) with a peg at each of `pegs`.
static func rail(b: Face.Builder, a: Vector2, z: Vector2, s: float, pegs: PackedVector2Array) -> void:
	var wd := s * 0.3
	b.stroke(PackedVector2Array([a + Vector2(0.0, 4.0), z + Vector2(0.0, 4.0)]), wd + 8.0, Pal.RAIL_DEEP)
	b.stroke(PackedVector2Array([a, z]), wd, Pal.RAIL)
	b.stroke(PackedVector2Array([a - Vector2(0.0, wd * 0.18), z - Vector2(0.0, wd * 0.18)]), wd * 0.18, Color(Pal.BEAM_CORE, 0.35))
	for p in pegs:
		b.disc(p, s * 0.055, Pal.RAIL_PEG)
