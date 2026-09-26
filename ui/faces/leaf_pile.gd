extends RefCounted

## Hedgehogs' lawn as builder shapes rather than Controls: a cell's ground,
## a leaf pile and a flag, the drawings the board (puzzles/hedgehogs2d.gd),
## the tray's flag chip (ui/flat/tile_tray.gd) and the menu card
## (ui/menu/card_art.gd) all make, so none of them can drift apart. A hard
## lawn carries a hundred piles, so they are batched into one mesh the way
## `ui/faces/patch_cloth.gd`'s patches and `paper_plane.gd`'s darts are.
##
## A pile is a mound and five almond leaves in the autumn colours, each
## leaf's place, turn and colour hashed from the cell so the same pile is
## drawn every frame. `blow` carries the leaves off: 0 is a pile at rest,
## 0..1 is the gust taking them (they fly along `dir`, spin and fade, and the
## mound is gone), 1 is nothing.
## Ported from the concept page's mock (docs/brainstorm/concepts.html#hedgehogs:
## pile, almond, flagMark, and drawCell's ground).
## Spec: docs/superpowers/specs/2026-09-26-hedgehogs-flat-design.md, section 7.

const Pal = preload("res://core/palette.gd")
const Face = preload("res://ui/faces/face.gd")

const LEAVES := 5
## A leaf's length, and how far its hashed seat strays from the cell's
## middle, as fractions of the cell.
const LEAF_LEN := 0.34
const SPREAD := Vector2(0.5, 0.4)
## The mound under the leaves: its half-size and its lip, in cells.
const MOUND := Vector2(0.37, 0.26)
const MOUND_LIP := 0.05
## How far a blown leaf travels, in cells, and how high it lifts on the way.
const FLY := 0.9
const LOFT := 0.3
## A cell's ground: the gap round it, its corner, and the rim under it, in
## cells.
const INSET := 0.04
const RADIUS := 0.18
const RIM := 0.05
const RAKED_RIM := 0.03
## A woken hedgehog's cell: how far the raked grass washes toward BAD.
const WOKE_WASH := 0.38

## A small stable hash of two ints into [0, 1), the mock's `hash`.
static func h01(a: int, b: int) -> float:
	var x := (a * 374761393 + b * 668265263) ^ (a * b * 1274126177)
	x = ((x ^ (x >> 13)) * 1274126177) & 0xffffffff
	return float((x ^ (x >> 16)) & 0xffffffff) / 4294967296.0

## One almond leaf, `length` long, centred on `at` and turned `angle`, with a
## faint vein down its middle.
static func almond(b: Face.Builder, at: Vector2, length: float, angle: float, colour: Color) -> void:
	var xf := Transform2D(angle, at)
	var half := length * 0.5
	var pts := Face.Builder.bezier2(Vector2(-half, 0.0), Vector2(0.0, -length * 0.36), Vector2(half, 0.0), 8)
	pts.append_array(Face.Builder.bezier2(Vector2(half, 0.0), Vector2(0.0, length * 0.36), Vector2(-half, 0.0), 8))
	b.fan(xf * pts, colour)
	var vein := Color(0.35, 0.2, 0.08, 0.35 * colour.a)
	b.stroke(xf * PackedVector2Array([Vector2(-length * 0.42, 0.0), Vector2(length * 0.4, 0.0)]),
		maxf(1.5, length * 0.05), vein)

## A cell's ground, the cell `s` wide centred on `centre`: the lawn's turf
## with its tufts while covered, the raked grass once raked -- washed toward
## BAD when a woken hedgehog lies on it. `alpha` fades it.
static func ground(b: Face.Builder, centre: Vector2, s: float, cell_id: int, raked: bool, woke: bool, alpha := 1.0) -> void:
	var inset := s * INSET
	var at := centre - Vector2.ONE * (s * 0.5 - inset)
	var box := Vector2.ONE * (s - 2.0 * inset)
	var r := s * RADIUS
	if raked:
		var fill: Color = Pal.RAKED.lerp(Pal.BAD, WOKE_WASH) if woke else Pal.RAKED
		b.fan(Face.Builder.round_rect(at, box, r), Color(Pal.RAKED_EDGE, alpha))
		b.fan(Face.Builder.round_rect(at, box - Vector2(0.0, s * RAKED_RIM), r), Color(fill, alpha))
		return
	b.fan(Face.Builder.round_rect(at, box, r), Color(Pal.LAWN_DEEP, alpha))
	b.fan(Face.Builder.round_rect(at, box - Vector2(0.0, s * RIM), r), Color(Pal.LAWN, alpha))
	var tuft := Color(Pal.LAWN_DEEP, 0.5 * alpha)
	for i in 3:
		var tx := centre.x + (h01(cell_id, i + 70) - 0.5) * s * 0.7
		var ty := centre.y + s * 0.3
		b.stroke(PackedVector2Array([Vector2(tx, ty), Vector2(tx - s * 0.03, ty - s * 0.08)]), s * 0.025, tuft)
		b.stroke(PackedVector2Array([Vector2(tx, ty), Vector2(tx + s * 0.03, ty - s * 0.09)]), s * 0.025, tuft)

## A leaf pile on the cell `s` wide centred on `centre`. `blow` 0 is at rest;
## above it the mound is gone and the leaves fly along `dir` (a unit vector),
## spinning and fading, until 1. `scale` squashes the whole pile about its
## centre (an Undo's pop back in); `alpha` fades it (a flagged pile, pressed
## down under its twig).
static func pile(b: Face.Builder, centre: Vector2, s: float, cell_id: int, blow := 0.0,
		dir := Vector2.UP, scale := Vector2.ONE, alpha := 1.0) -> void:
	if blow >= 1.0 or alpha <= 0.0:
		return
	if blow <= 0.0:
		b.ellipse(centre + Vector2(0.0, s * (0.05 + MOUND_LIP)) * scale,
			s * (MOUND.x + 0.03) * scale.x, s * (MOUND.y + 0.04) * scale.y, Color(Pal.PILE_DEEP, alpha))
		b.ellipse(centre + Vector2(0.0, s * 0.05) * scale, s * MOUND.x * scale.x, s * MOUND.y * scale.y,
			Color(Pal.PILE, alpha))
	var u := clampf(blow, 0.0, 1.0)
	for i in LEAVES:
		var off := Vector2((h01(cell_id * 7 + i, 11) - 0.5) * s * SPREAD.x,
			(h01(cell_id * 5 + i, 23) - 0.5) * s * SPREAD.y)
		var angle := h01(cell_id + i * 3, 31) * TAU
		var colour: Color = Pal.AUTUMN_LEAVES[int(h01(cell_id * 3 + i, 47) * Pal.AUTUMN_LEAVES.size()) % Pal.AUTUMN_LEAVES.size()]
		var at := centre + off * scale
		if u > 0.0:
			var fly := u * u * FLY * s
			var drift := (h01(i, cell_id * 2) - 0.5) * u * s * 0.5
			at += dir * fly + Vector2(drift, -sin(PI * u) * s * LOFT)
			angle += u * (h01(i, cell_id) - 0.5) * 6.0
		almond(b, at, s * LEAF_LEN * scale.x, angle, Color(colour, alpha * (1.0 - u)))

## A flag: a bark twig pushed into the pile with a two-tone pennant, `R`
## (about 0.46 of a cell on the lawn) sized about `centre`. `wrong` turns the
## pennant rose (Check's answer); `scale` pops it in and out.
static func flag(b: Face.Builder, centre: Vector2, R: float, wrong := false, scale := Vector2.ONE, alpha := 1.0) -> void:
	if scale.x <= 0.0 or scale.y <= 0.0 or alpha <= 0.0:
		return
	var xf := Transform2D(0.0, scale, 0.0, centre)
	b.ellipse(centre + Vector2(0.0, R * 0.62) * scale, R * 0.34 * scale.x, R * 0.1 * scale.y, Color(Pal.TEXT, 0.16 * alpha))
	b.stroke(xf * PackedVector2Array([Vector2(-0.08, 0.62) * R, Vector2(-0.08, -0.7) * R]), R * 0.12 * scale.x,
		Color(Pal.BARK, alpha))
	var lit: Color = Pal.BAD if wrong else Pal.PENNANT
	var deep: Color = Color("b54a45") if wrong else Pal.PENNANT_DEEP
	b.polygon(xf * PackedVector2Array([Vector2(-0.02, -0.7) * R, Vector2(0.66, -0.44) * R, Vector2(-0.02, -0.16) * R]),
		Color(lit, alpha))
	b.polygon(xf * PackedVector2Array([Vector2(-0.02, -0.44) * R, Vector2(0.66, -0.44) * R, Vector2(-0.02, -0.16) * R]),
		Color(deep, alpha))

## The rake chip's picture: a bark handle leaning right and a five-tined
## head, `s` across, centred on `centre`.
static func rake(b: Face.Builder, centre: Vector2, s: float) -> void:
	var xf := Transform2D(-0.5, centre)
	b.stroke(xf * PackedVector2Array([Vector2(0.0, 0.5) * s, Vector2(0.0, -0.2) * s]), s * 0.1, Pal.BARK)
	b.stroke(xf * PackedVector2Array([Vector2(-0.3, -0.2) * s, Vector2(0.3, -0.2) * s]), s * 0.09, Pal.PILE_DEEP)
	for i in 5:
		var tx := -0.28 + float(i) * 0.14
		b.stroke(xf * PackedVector2Array([Vector2(tx, -0.2) * s, Vector2(tx, -0.42) * s]), s * 0.06, Pal.PILE_DEEP)
