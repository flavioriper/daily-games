extends RefCounted

## Hosepipes' drawings: the soil squares of the raised bed (dry, or dark and
## wet under a hose), the bed's wooden frame, a hose as a round tube that
## bends through the middle of each square, the garden tap at one end and
## the flower at the other (a closed bud until its hose reaches it, then
## open), a seed mound for Insane's Seedlings, and the halo of the hose
## under the finger. Builder shapes, not Controls: the board, the menu card
## and the tutorial draw the same pieces.
##
## Hoses are coloured by index (core/palette.gd CAT). No state is ever told
## by a shade of a hose's own colour (CLAUDE.md): the hose in hand wears a
## cream halo at its head, a reached flower opens, a watered square darkens
## its soil.

const Pal = preload("res://core/palette.gd")
const Face = preload("res://ui/faces/face.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

const DRY := Color("e2c99f")
const DRY_DEEP := Color("d3b68a")
const DRY_FLECK := Color("c9a87a")
const WET := Color("9b7350")
const WET_DEEP := Color("86613f")
const WET_SHINE := Color("b48d68")
const FRAME := Color("b98653")
const FRAME_LIT := Color("cf9d68")
const FRAME_DEEP := Color("8d6038")
const FRAME_NAIL := Color("7a5634")
const BRASS := Color("d8b25a")
const BRASS_DEEP := Color("a98236")
const STONE := Color("cfc8ba")
const STONE_DEEP := Color("aaa293")
const CREAM := Color("fdf6e6")
const PETAL_EYE := Color("f6cf5a")
const PETAL_EYE_DEEP := Color("dca83a")
const SEPAL := Color("6f9e55")
const SEPAL_DEEP := Color("557f40")
const MOUND := Color("a17a55")
const MOUND_DEEP := Color("7f5c3c")
const SEED := Color("f1e2c0")
const SPROUT := Color("86b863")

## Shares of a square: the hose's width, its rim, the bend's reach, a
## soil tile's gap and corner.
const HOSE_W := 0.34
const HOSE_RIM := 0.07
const TILE_GAP := 0.06
const TILE_CORNER := 0.14

## The ramp's colours in the order a bed takes them, the most different
## first: teal, terracotta, lavender, mustard, sky, rose, sage, stone. A
## five-hose bed never holds both terracotta and rose.
const ORDER := [0, 1, 3, 6, 5, 4, 2, 7]

## The hose colours, by index.
static func colour(c: int) -> Color:
	return Pal.CAT[ORDER[c % ORDER.size()]]

## The small mark a hose's tap and flower share, so a pair is matched by
## shape as well as colour: a dot, a triangle, a square, a diamond, a plus,
## a ring, a bar, a chevron.
static func mark(b: Face.Builder, at: Vector2, r: float, c: int, ink: Color) -> void:
	match c % 8:
		0:
			b.disc(at, r * 0.55, ink)
		1:
			b.fan(PackedVector2Array([at + Vector2(0.0, -r * 0.7), at + Vector2(r * 0.65, r * 0.5), at + Vector2(-r * 0.65, r * 0.5)]), ink)
		2:
			b.fan(Face.Builder.round_rect(at - Vector2(r, r) * 0.5, Vector2(r, r), r * 0.12), ink)
		3:
			b.fan(PackedVector2Array([at + Vector2(0.0, -r * 0.72), at + Vector2(r * 0.6, 0.0), at + Vector2(0.0, r * 0.72), at + Vector2(-r * 0.6, 0.0)]), ink)
		4:
			b.stroke(PackedVector2Array([at - Vector2(r * 0.6, 0.0), at + Vector2(r * 0.6, 0.0)]), r * 0.32, ink)
			b.stroke(PackedVector2Array([at - Vector2(0.0, r * 0.6), at + Vector2(0.0, r * 0.6)]), r * 0.32, ink)
		5:
			b.stroke(Face.Builder.arc_points(at, r * 0.45, 0.0, TAU), r * 0.26, ink, true)
		6:
			b.stroke(PackedVector2Array([at - Vector2(r * 0.62, 0.0), at + Vector2(r * 0.62, 0.0)]), r * 0.4, ink)
		_:
			b.stroke(PackedVector2Array([at + Vector2(-r * 0.55, r * 0.3), at + Vector2(0.0, -r * 0.3), at + Vector2(r * 0.55, r * 0.3)]), r * 0.3, ink)

## A soil square `s` wide about `at`, dry or wet; `seed` places its specks.
static func soil(b: Face.Builder, at: Vector2, s: float, wet: bool, seed: int) -> void:
	var t := s * (1.0 - TILE_GAP)
	var r := s * TILE_CORNER
	var top := at - Vector2(t, t) * 0.5
	b.fan(Face.Builder.round_rect(top + Vector2(0.0, s * 0.03), Vector2(t, t), r), WET_DEEP if wet else DRY_DEEP)
	b.fan(Face.Builder.round_rect(top, Vector2(t, t * 0.97), r), WET if wet else DRY)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 7919 + 13
	if wet:
		# two soft shines where the water stands
		b.ellipse(at + Vector2(-t * 0.2, -t * 0.22), t * 0.16, t * 0.06, Color(WET_SHINE, 0.75))
		b.ellipse(at + Vector2(t * 0.22, t * 0.18), t * 0.1, t * 0.04, Color(WET_SHINE, 0.55))
	else:
		for k in 4:
			var p := at + Vector2(rng.randf_range(-0.34, 0.34), rng.randf_range(-0.34, 0.34)) * t
			b.disc(p, t * rng.randf_range(0.025, 0.045), DRY_FLECK)

## The bed's wooden frame round `rect` (the soil's outer edge), `w` thick.
static func frame(b: Face.Builder, rect: Rect2, w: float) -> void:
	var o := rect.grow(w)
	Scenery.soft_disc(b, o.get_center() + Vector2(0.0, w * 0.9), o.size.x * 0.56, w * 1.4, Color(FRAME_DEEP, 0.22))
	b.fan(Face.Builder.round_rect(o.position + Vector2(0.0, w * 0.35), o.size, w * 0.6), FRAME_DEEP)
	b.fan(Face.Builder.round_rect(o.position, o.size, w * 0.6), FRAME)
	# the boards' lit top edges and the soil's dark bed under the squares
	b.fan(Face.Builder.round_rect(o.position + Vector2(w * 0.2, w * 0.15), Vector2(o.size.x - w * 0.4, w * 0.3), w * 0.15), FRAME_LIT)
	b.fan(Face.Builder.round_rect(rect.position - Vector2(w, w) * 0.12, rect.size + Vector2(w, w) * 0.24, w * 0.3), WET_DEEP)
	# a nail at each corner
	for p: Vector2 in [o.position, Vector2(o.end.x, o.position.y), o.end, Vector2(o.position.x, o.end.y)]:
		var q := p + (o.get_center() - p).sign() * w * 0.5
		b.disc(q, w * 0.13, FRAME_NAIL)

## The centreline of a hose through `pts` (square middles), each turn a
## round bend from the middle of one step to the middle of the next.
static func hose_line(pts: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	if pts.is_empty():
		return out
	out.append(pts[0])
	for i in range(1, pts.size() - 1):
		var a: Vector2 = pts[i - 1]
		var p: Vector2 = pts[i]
		var c: Vector2 = pts[i + 1]
		if absf((p - a).cross(c - p)) < 0.01:
			out.append(p)
			continue
		var m0 := (a + p) * 0.5
		var m1 := (p + c) * 0.5
		var arc := Face.Builder.bezier2(m0, p, m1, 8)
		for k in arc.size():
			if k == 0 and out.size() > 0 and out[out.size() - 1].distance_to(arc[k]) < 0.5:
				continue
			out.append(arc[k])
	if pts.size() > 1:
		out.append(pts[pts.size() - 1])
	return out

## A hose through `pts` for a square `s` wide, in hose colour `col`: a soft
## shadow, the rim, the tube and a lit stripe along it.
static func hose(b: Face.Builder, pts: Array, s: float, col: Color) -> void:
	if pts.size() < 2:
		return
	var line := hose_line(pts)
	var w := s * HOSE_W
	var shadow := PackedVector2Array()
	for p in line:
		shadow.append(p + Vector2(0.0, w * 0.28))
	b.stroke(shadow, w * 1.1, Color(Pal.TEXT, 0.16))
	b.stroke(line, w + s * HOSE_RIM, col.darkened(0.28))
	b.stroke(line, w, col)
	var lit := PackedVector2Array()
	for p in line:
		lit.append(p + Vector2(-w * 0.12, -w * 0.16))
	b.stroke(lit, w * 0.26, Color(col.lightened(0.45), 0.7))

## The garden tap at `at` for a square `s` wide, hose `c`'s, in its colour
## `col`: a stone plate and a valve wheel in the hose's colour, four spokes
## to a brass hub that carries the pair's mark.
static func tap(b: Face.Builder, at: Vector2, s: float, col: Color, c := -1) -> void:
	var r := s * 0.4
	Scenery.soft_disc(b, at + Vector2(0.0, r * 0.35), r * 1.05, r * 0.3, Color(Pal.TEXT, 0.2))
	b.fan(Face.Builder.round_rect(at - Vector2(r, r) * 0.82, Vector2(r, r) * 1.64, r * 0.32), STONE_DEEP)
	b.fan(Face.Builder.round_rect(at - Vector2(r, r * 1.04) * 0.82, Vector2(r, r * 0.96) * 1.64, r * 0.32), STONE)
	b.disc(at + Vector2(0.0, r * 0.08), r * 0.72, col.darkened(0.3))
	b.disc(at, r * 0.72, col)
	b.disc(at, r * 0.5, Color(col.darkened(0.18), 1.0))
	for k in 4:
		var d := Vector2.RIGHT.rotated(k * PI * 0.5) * r * 0.62
		b.stroke(PackedVector2Array([at, at + d]), r * 0.2, col)
	b.disc(at + Vector2(0.0, r * 0.04), r * 0.3, BRASS_DEEP)
	b.disc(at, r * 0.3, BRASS)
	if c >= 0:
		mark(b, at, r * 0.26, c, Color(Pal.TEXT, 0.8))

## The flower at `at` for a square `s` wide, hose `c`'s, its petals in
## `col`; `open` runs from 0 (a closed bud, its colour still plain) to 1
## (open, the yellow eye carrying the pair's mark).
static func flower(b: Face.Builder, at: Vector2, s: float, col: Color, open: float, c := -1) -> void:
	var r := s * 0.4
	Scenery.soft_disc(b, at + Vector2(0.0, r * 0.4), r * 0.9, r * 0.28, Color(Pal.TEXT, 0.2))
	# two leaves under it
	for k in 2:
		var d := Vector2(1.0 if k == 0 else -1.0, 0.3).normalized()
		b.ellipse(at + d * r * 0.66 + Vector2(0.0, r * 0.3), r * 0.36, r * 0.17, SEPAL_DEEP if k == 0 else SEPAL)
	var spread := lerpf(0.24, 0.62, open)
	var size := lerpf(0.44, 0.42, open)
	for k in 5:
		var a := -PI * 0.5 + k * TAU / 5.0
		var p := at + Vector2.RIGHT.rotated(a) * r * spread
		b.disc(p + Vector2(0.0, r * 0.06), r * size, col.darkened(0.25))
	for k in 5:
		var a := -PI * 0.5 + k * TAU / 5.0
		var p := at + Vector2.RIGHT.rotated(a) * r * spread
		b.disc(p, r * size, col)
		b.disc(p + Vector2.RIGHT.rotated(a) * r * size * 0.3 - Vector2(0, r * 0.06), r * size * 0.35, Color(col.lightened(0.4), 0.35 + open * 0.4))
	var eye := r * lerpf(0.0, 0.3, open)
	if eye > 1.0:
		b.disc(at + Vector2(0.0, r * 0.04), eye, PETAL_EYE_DEEP)
		b.disc(at, eye, PETAL_EYE)
	if c >= 0:
		# the mark: on the closed bud in cream, on the open flower's eye in ink
		var ink := Color(Pal.TEXT, 0.75 * open) if open > 0.5 else Color(CREAM, 0.9 * (1.0 - open * 2.0))
		if ink.a > 0.02:
			mark(b, at, r * 0.26, c, ink)

## A bare seed for a square `s` wide at `at`: a mound of turned soil with a
## pale seed and a curl of a sprout.
static func seed_mound(b: Face.Builder, at: Vector2, s: float) -> void:
	var r := s * 0.38
	Scenery.soft_disc(b, at + Vector2(0.0, r * 0.4), r * 0.95, r * 0.26, Color(Pal.TEXT, 0.18))
	b.ellipse(at + Vector2(0.0, r * 0.18), r * 0.9, r * 0.62, MOUND_DEEP)
	b.ellipse(at + Vector2(0.0, r * 0.08), r * 0.84, r * 0.56, MOUND)
	b.ellipse(at + Vector2(-r * 0.12, r * 0.06), r * 0.26, r * 0.17, SEED)
	var stem := Face.Builder.bezier2(at + Vector2(r * 0.12, 0.0), at + Vector2(r * 0.18, -r * 0.5), at + Vector2(r * 0.42, -r * 0.6), 8)
	b.stroke(stem, r * 0.1, SPROUT)
	b.ellipse(at + Vector2(r * 0.46, -r * 0.62), r * 0.17, r * 0.09, SPROUT)

## The cream halo round the head of the hose under the finger.
static func halo(b: Face.Builder, at: Vector2, s: float) -> void:
	b.disc(at, s * 0.42, Color(CREAM, 0.35))
	var ring := Face.Builder.arc_points(at, s * 0.42, 0.0, TAU)
	b.stroke(ring, s * 0.06, Color(CREAM, 0.95), true)
