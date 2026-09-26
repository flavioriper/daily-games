extends RefCounted

## Hedgehogs' lawn as builder shapes rather than Controls: a cell's ground,
## a leaf pile and a flag, the drawings the board (puzzles/hedgehogs2d.gd),
## the tray's flag chip (ui/flat/tile_tray.gd) and the menu card
## (ui/menu/card_art.gd) all make, so none of them can drift apart. A hard
## lawn carries a hundred piles, so they are batched into one mesh the way
## `ui/faces/patch_cloth.gd`'s patches and `paper_plane.gd`'s darts are.
##
## A pile is a heap: a soft shadow, a lumpy mound with a lit crown, four
## leaves fanned out round its rim in the deeper colours and four lying on
## top in the bright ones -- almonds, maples and oaks, each leaf's shape,
## place, turn and colour hashed from the cell so the same pile is drawn
## every frame. `blow` carries the leaves off: 0 is a pile at rest, 0..1 is
## the gust taking them (they spiral away along `dir`, flipping as they
## tumble, and one in four drops short and settles before it fades), 1 is
## nothing. `rustle` 0..1 is the breeze lifting the top leaves and letting
## them down again.
##
## Every leaf is one of three unit outlines triangulated once (`_unit`), so a
## hundred piles cost vertex appends and never a triangulation apiece.
## Ported from the concept page's mock (docs/brainstorm/concepts.html#hedgehogs:
## pile, almond, flagMark, and drawCell's ground), polished 2026-09-26.
## Spec: docs/superpowers/specs/2026-09-26-hedgehogs-flat-design.md, sections
## 7 and 10.

const Pal = preload("res://core/palette.gd")
const Face = preload("res://ui/faces/face.gd")

enum Kind { ALMOND, MAPLE, OAK }

const LEAVES := 7
## The leaves fanned round the rim (the first BACK of LEAVES), the rest lie
## on top.
const BACK := 4
## A leaf's length, as a fraction of the cell: round the rim, and on top.
const LEAF_BACK := 0.38
const LEAF_TOP := 0.34
## How far the rim leaves sit out from the middle, and how far the top ones
## stray, as fractions of the cell.
const RIM := Vector2(0.27, 0.15)
const SPREAD := Vector2(0.3, 0.16)
## The mound under the leaves: its half-size, how far it sits below the
## middle, its lip, and how lumpy its outline is, in cells.
const MOUND := Vector2(0.38, 0.25)
const MOUND_DROP := 0.07
const MOUND_LIP := 0.04
const LUMP := 0.16
## How far a blown leaf travels, in cells, how high it lifts on the way, and
## how wide its spiral swings.
const FLY := 0.95
const LOFT := 0.34
const SWIRL := 0.22
## One leaf in this many drops short of the rest and settles before it
## fades, and for the last this much of the gust.
const SETTLER := 4
const SETTLE_FADE := 0.28
## The breeze: how high a top leaf lifts and how far it turns.
const RUSTLE_LIFT := 0.07
const RUSTLE_TURN := 0.45
## A flagged pile, pressed down under its twig.
const PRESSED := Vector2(1.06, 0.84)
## A cell's ground: the gap round it, its corner, and the rim under it, in
## cells.
const INSET := 0.04
const RADIUS := 0.18
const GROUND_RIM := 0.05
const RAKED_RIM := 0.03
## The rake's lines across a raked cell.
const TINES := 2
## A woken hedgehog's cell: how far the raked grass washes toward BAD.
const WOKE_WASH := 0.38

static var _units: Array = []

## A small stable hash of two ints into [0, 1), the mock's `hash`.
static func h01(a: int, b: int) -> float:
	var x := (a * 374761393 + b * 668265263) ^ (a * b * 1274126177)
	x = ((x ^ (x >> 13)) * 1274126177) & 0xffffffff
	return float((x ^ (x >> 16)) & 0xffffffff) / 4294967296.0

## The unit outline of a leaf of `kind`, one long along +x and centred on
## the origin with its stem at -x, and its triangles, built once.
static func _unit(kind: int) -> Array:
	if _units.is_empty():
		for k in 3:
			var pts := _outline(k)
			_units.append([pts, Geometry2D.triangulate_polygon(pts)])
	return _units[kind]

static func _outline(kind: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	match kind:
		Kind.ALMOND:
			pts = Face.Builder.bezier2(Vector2(-0.5, 0.0), Vector2(0.0, -0.48), Vector2(0.5, 0.0), 9)
			pts.append_array(Face.Builder.bezier2(Vector2(0.5, 0.0), Vector2(0.0, 0.48), Vector2(-0.5, 0.0), 9))
		Kind.MAPLE:
			# Tips and valleys round a point a little behind the middle:
			# five lobes, the middle one longest, a notch for the stem.
			var marks := [[180.0, 0.08], [-150.0, 0.2], [-124.0, 0.36], [-108.0, 0.34], [-94.0, 0.27],
				[-66.0, 0.47], [-52.0, 0.45], [-30.0, 0.31], [-6.0, 0.54], [6.0, 0.54], [30.0, 0.31],
				[52.0, 0.45], [66.0, 0.47], [94.0, 0.27], [108.0, 0.34], [124.0, 0.36], [150.0, 0.2]]
			for m: Array in marks:
				pts.append(Vector2(-0.06, 0.0) + Vector2.from_angle(deg_to_rad(m[0])) * float(m[1]))
		Kind.OAK:
			# Rounded lobes down both sides, tapering to both ends.
			var n := 14
			for i in n + 1:
				var x := 0.5 - float(i) / float(n)
				pts.append(Vector2(x, -_oak_w(x)))
			for i in range(1, n):
				var x := -0.5 + float(i) / float(n)
				pts.append(Vector2(x, _oak_w(x)))
	return pts

static func _oak_w(x: float) -> float:
	var taper := pow(maxf(0.0, sin(PI * (x + 0.5))), 0.7)
	return 0.22 * taper * (0.62 + 0.38 * absf(cos(x * PI * 3.2)))

## One leaf of `kind`, `length` long, centred on `at` and turned `angle`,
## with its midrib and a stub of stem. `flip` squashes it across its length,
## a leaf tumbling edge-on.
static func leaf(b: Face.Builder, at: Vector2, length: float, angle: float, colour: Color,
		kind := Kind.ALMOND, flip := 1.0) -> void:
	var u := _unit(kind)
	var xf := Transform2D(angle, Vector2(length, length * maxf(flip, 0.08)), 0.0, at)
	var pts: PackedVector2Array = xf * (u[0] as PackedVector2Array)
	var first := b.verts.size()
	for p in pts:
		b.vertex(p, colour)
	for t: int in u[1]:
		b.idx.append(first + t)
	b._feather(pts, first, colour)
	if length < 14.0 or colour.a < 0.05:
		return
	var vein := Color(colour.lightened(0.3), 0.55 * colour.a)
	b.stroke(xf * PackedVector2Array([Vector2(-0.4, 0.0), Vector2(0.3, 0.0)]),
		maxf(1.0, length * 0.035), vein, false, false)

## The old single leaf, kept for callers that want the plain almond.
static func almond(b: Face.Builder, at: Vector2, length: float, angle: float, colour: Color) -> void:
	leaf(b, at, length, angle, colour, Kind.ALMOND)

## A cell's ground, the cell `s` wide centred on `centre`: the lawn's turf
## with a tuft at its foot while covered, the raked grass with the rake's
## lines across it once raked -- washed toward BAD when a woken hedgehog lies
## on it. `alpha` fades it.
static func ground(b: Face.Builder, centre: Vector2, s: float, cell_id: int, raked: bool, woke: bool, alpha := 1.0) -> void:
	var inset := s * INSET
	var at := centre - Vector2.ONE * (s * 0.5 - inset)
	var box := Vector2.ONE * (s - 2.0 * inset)
	var r := s * RADIUS
	if raked:
		var fill: Color = Pal.RAKED.lerp(Pal.BAD, WOKE_WASH) if woke else Pal.RAKED
		b.fan(Face.Builder.round_rect(at, box, r), Color(Pal.RAKED_EDGE, alpha))
		b.fan(Face.Builder.round_rect(at, box - Vector2(0.0, s * RAKED_RIM), r), Color(fill, alpha))
		if woke or s < 30.0:
			return
		# The rake's lines: faint, curved the same way, tilted a little per cell.
		var tilt := (h01(cell_id, 91) - 0.5) * 0.3
		var line := Color(Pal.RAKED_EDGE, 0.55 * alpha)
		for k in TINES:
			var y := (float(k) - 0.5) * 0.2 * s
			var dx := (h01(cell_id, 92 + k) - 0.5) * 0.12 * s
			var xf := Transform2D(tilt, centre + Vector2(dx, y - s * 0.04))
			b.stroke(xf * Face.Builder.bezier2(Vector2(-0.2 * s, 0.0), Vector2(0.0, 0.08 * s), Vector2(0.2 * s, 0.0), 7),
				s * 0.028, line, false, false)
		return
	b.fan(Face.Builder.round_rect(at, box, r), Color(Pal.LAWN_DEEP, alpha))
	b.fan(Face.Builder.round_rect(at, box - Vector2(0.0, s * GROUND_RIM), r), Color(Pal.LAWN, alpha))
	var tuft := Color(Pal.LAWN_DEEP, 0.7 * alpha)
	for i in 2:
		var tx := centre.x + (0.3 if i == 0 else -0.32) * s + (h01(cell_id, i + 70) - 0.5) * s * 0.08
		var ty := centre.y + s * 0.36
		b.stroke(PackedVector2Array([Vector2(tx, ty), Vector2(tx - s * 0.035, ty - s * 0.09)]), s * 0.028, tuft, false, false)
		b.stroke(PackedVector2Array([Vector2(tx, ty), Vector2(tx + s * 0.03, ty - s * 0.1)]), s * 0.028, tuft, false, false)

## A leaf's look in the pile: [offset from the middle (unscaled), angle,
## colour, kind, length], all hashed from the cell.
static func _leaf_at(s: float, cell_id: int, i: int) -> Array:
	var kind := int(h01(cell_id * 13 + i, 5) * 3.0) % 3
	var colour: Color = Pal.AUTUMN_LEAVES[int(h01(cell_id * 3 + i, 47) * Pal.AUTUMN_LEAVES.size()) % Pal.AUTUMN_LEAVES.size()]
	if i < BACK:
		var a := TAU * (float(i) + 0.5) / float(BACK) + (h01(cell_id + i, 17) - 0.5) * 0.9
		var off := Vector2(cos(a) * RIM.x, sin(a) * RIM.y + MOUND_DROP) * s
		return [off, a + (h01(cell_id + i, 19) - 0.5) * 0.7, colour.lerp(Pal.PILE_DEEP, 0.32), kind,
			s * LEAF_BACK * (0.9 + 0.2 * h01(cell_id, i + 3))]
	var off := Vector2((h01(cell_id * 7 + i, 11) - 0.5) * SPREAD.x, (h01(cell_id * 5 + i, 23) - 0.5) * SPREAD.y + 0.01) * s
	return [off, h01(cell_id + i * 3, 31) * TAU, colour, kind, s * LEAF_TOP * (0.85 + 0.3 * h01(cell_id, i + 9))]

## A leaf pile on the cell `s` wide centred on `centre`. `blow` 0 is at rest;
## above it the mound is gone and the leaves spiral off along `dir` (a unit
## vector) until 1. `scale` squashes the whole pile about its centre (an
## Undo's pop back in, a flag's press); `alpha` fades it; `rustle` 0..1 is
## the breeze through its top leaves.
static func pile(b: Face.Builder, centre: Vector2, s: float, cell_id: int, blow := 0.0,
		dir := Vector2.UP, scale := Vector2.ONE, alpha := 1.0, rustle := 0.0) -> void:
	if blow >= 1.0 or alpha <= 0.0:
		return
	if blow <= 0.0:
		_mound(b, centre, s, cell_id, scale, alpha)
	var u := clampf(blow, 0.0, 1.0)
	var lift := sin(PI * clampf(rustle, 0.0, 1.0))
	var side := Vector2(-dir.y, dir.x)
	for i in LEAVES:
		var look := _leaf_at(s, cell_id, i)
		var at: Vector2 = centre + (look[0] as Vector2) * scale
		var angle: float = look[1]
		var colour: Color = look[2]
		var flip := 1.0
		var a := alpha
		if u > 0.0:
			var hv := h01(i, cell_id * 2)
			if i % SETTLER == 0:
				# Drops short, lands, lies there a moment and fades.
				var k := minf(1.0, u / (1.0 - SETTLE_FADE))
				var travel := (1.0 - (1.0 - k) * (1.0 - k)) * FLY * 0.7 * s
				at += dir * travel + side * (hv - 0.5) * s * 0.5 + Vector2(0.0, -sin(PI * k) * s * LOFT * 0.8)
				angle += k * (hv - 0.5) * 5.0
				flip = 0.35 + 0.65 * absf(cos(k * 6.0 + float(i)))
				a *= 1.0 if u < 1.0 - SETTLE_FADE else (1.0 - u) / SETTLE_FADE
			else:
				var fly := u * u * FLY * s
				var swirl := sin(u * PI * 1.6 + hv * TAU) * SWIRL * s * u
				at += dir * fly + side * swirl + Vector2(0.0, -sin(PI * u) * s * LOFT)
				angle += u * (hv - 0.5) * 8.0
				flip = 0.3 + 0.7 * absf(cos(u * 7.0 + float(i)))
				a *= 1.0 - u
		elif lift > 0.0 and i >= BACK:
			var hv := h01(i, cell_id + 7)
			at.y -= s * RUSTLE_LIFT * lift * (0.5 + hv)
			angle += RUSTLE_TURN * lift * (hv - 0.5) * 2.0
			flip = 1.0 - 0.3 * lift * hv
		leaf(b, at, float(look[4]) * scale.x, angle, Color(colour, a), look[3], flip)

## The mound under the leaves: a soft shadow, the deep lip, a lumpy body and
## a lit crown.
static func _mound(b: Face.Builder, centre: Vector2, s: float, cell_id: int, scale: Vector2, alpha: float) -> void:
	var mid := centre + Vector2(0.0, s * MOUND_DROP) * scale
	b.ellipse(centre + Vector2(0.0, s * 0.24) * scale, s * 0.42 * scale.x, s * 0.1 * scale.y, Color(Pal.TEXT, 0.12 * alpha))
	var body := PackedVector2Array()
	var lip := PackedVector2Array()
	var n := 20
	for k in n:
		var a := TAU * float(k) / float(n)
		# Scalloped, the edge of a heap of leaves, and lumpy.
		var r := 1.0 + (h01(cell_id, k + 90) - 0.5) * LUMP + (0.05 if k % 2 == 0 else -0.03)
		var p := Vector2(cos(a) * MOUND.x * r, sin(a) * MOUND.y * r) * s * scale
		body.append(mid + p)
		lip.append(mid + p + Vector2(0.0, s * MOUND_LIP * scale.y))
	b.polygon(lip, Color(Pal.PILE_DEEP, alpha))
	b.polygon(body, Color(Pal.PILE.lerp(Pal.AUTUMN_LEAVES[0], 0.28), alpha))
	b.ellipse(mid + Vector2(-0.08, -0.08) * s * scale, s * 0.2 * scale.x, s * 0.08 * scale.y,
		Color(Pal.PILE.lightened(0.22), 0.7 * alpha))

## A flag: a bark twig pushed into the pile with a knot at its head and a
## two-tone pennant, `R` (about 0.46 of a cell on the lawn) sized about
## `centre`. `wrong` turns the pennant rose (Check's answer); `scale` pops it
## in and out; `wave` -1..1 flutters the pennant's tip.
static func flag(b: Face.Builder, centre: Vector2, R: float, wrong := false, scale := Vector2.ONE, alpha := 1.0,
		wave := 0.0) -> void:
	if scale.x <= 0.0 or scale.y <= 0.0 or alpha <= 0.0:
		return
	var xf := Transform2D(0.0, scale, 0.0, centre)
	b.ellipse(centre + Vector2(0.0, R * 0.62) * scale, R * 0.34 * scale.x, R * 0.1 * scale.y, Color(Pal.TEXT, 0.16 * alpha))
	b.stroke(xf * PackedVector2Array([Vector2(-0.08, 0.62) * R, Vector2(-0.08, -0.7) * R]), R * 0.12 * scale.x,
		Color(Pal.BARK, alpha))
	b.stroke(xf * PackedVector2Array([Vector2(-0.08, 0.1) * R, Vector2(-0.24, -0.08) * R]), R * 0.07 * scale.x,
		Color(Pal.BARK, alpha))
	b.disc(xf * (Vector2(-0.08, -0.72) * R), R * 0.08 * scale.x, Color(Pal.BARK.darkened(0.2), alpha))
	var lit: Color = Pal.BAD if wrong else Pal.PENNANT
	var deep: Color = Color("b54a45") if wrong else Pal.PENNANT_DEEP
	var tip := Vector2(0.68, -0.44 + wave * 0.1) * R
	var top := Face.Builder.bezier2(Vector2(-0.02, -0.7) * R, Vector2(0.3, -0.64 + wave * 0.12) * R, tip, 6)
	var foot := Face.Builder.bezier2(tip, Vector2(0.3, -0.24 - wave * 0.08) * R, Vector2(-0.02, -0.16) * R, 6)
	var whole := PackedVector2Array(top)
	whole.append_array(foot)
	whole.append(Vector2(-0.02, -0.16) * R)
	b.polygon(xf * whole, Color(lit, alpha))
	var fold := PackedVector2Array([Vector2(-0.02, -0.43) * R])
	fold.append_array(foot)
	fold.append(Vector2(-0.02, -0.16) * R)
	b.polygon(xf * fold, Color(deep, alpha))

## The rake: a bark handle and a five-tined head, `s` across, centred on
## `centre`, leaning `angle` (the chip's picture leans right).
static func rake(b: Face.Builder, centre: Vector2, s: float, angle := -0.5, alpha := 1.0) -> void:
	var xf := Transform2D(angle, centre)
	b.stroke(xf * PackedVector2Array([Vector2(0.0, 0.5) * s, Vector2(0.0, -0.2) * s]), s * 0.1, Color(Pal.BARK, alpha))
	b.stroke(xf * PackedVector2Array([Vector2(-0.3, -0.2) * s, Vector2(0.3, -0.2) * s]), s * 0.09, Color(Pal.PILE_DEEP, alpha))
	for i in 5:
		var tx := -0.28 + float(i) * 0.14
		b.stroke(xf * PackedVector2Array([Vector2(tx, -0.2) * s, Vector2(tx, -0.42) * s]), s * 0.06, Color(Pal.PILE_DEEP, alpha))

## An acorn lying on the grass, `r` its cap's half-width, turned `angle`.
static func acorn(b: Face.Builder, at: Vector2, r: float, angle: float) -> void:
	var xf := Transform2D(angle, at)
	b.ellipse(at + Vector2(r * 0.2, r * 1.2), r * 1.0, r * 0.3, Color(Pal.TEXT, 0.12))
	b.fan(xf * Face.Builder.ring(Vector2(0.0, r * 0.5), r * 0.78, r * 0.95), Pal.ACORN)
	b.ellipse(xf * Vector2(-r * 0.25, r * 0.35), r * 0.18, r * 0.35, Color(Pal.ACORN.lightened(0.25), 0.8))
	b.fan(xf * Face.Builder.ring(Vector2(0.0, -r * 0.2), r, r * 0.5), Pal.BARK)
	b.stroke(xf * PackedVector2Array([Vector2(0.0, -r * 0.6), Vector2(r * 0.15, -r * 1.0)]), r * 0.2, Pal.BARK.darkened(0.2))

## A toadstool in the grass, `r` its cap's half-width.
static func toadstool(b: Face.Builder, at: Vector2, r: float) -> void:
	b.ellipse(at + Vector2(0.0, r * 0.1), r * 0.9, r * 0.25, Color(Pal.TEXT, 0.12))
	b.fan(Face.Builder.round_rect(at + Vector2(-r * 0.28, -r * 0.9), Vector2(r * 0.56, r * 1.0), r * 0.2), Pal.MUSHROOM_STEM)
	var cap := Face.Builder.arc_points(at + Vector2(0.0, -r * 0.8), r, PI, TAU)
	b.polygon(cap, Pal.MUSHROOM)
	b.disc(at + Vector2(-r * 0.4, -r * 1.2), r * 0.14, Pal.MUSHROOM_STEM)
	b.disc(at + Vector2(r * 0.3, -r * 1.45), r * 0.11, Pal.MUSHROOM_STEM)
	b.disc(at + Vector2(r * 0.55, -r * 1.05), r * 0.09, Pal.MUSHROOM_STEM)
