extends RefCounted

## Stepping Stones' drawings: a flat river stone (its wet rim and the ripple
## round it in the water), a bank's slab of flagstone, the moss under a
## letter that already matches the far bank, the waiting stone's ring of
## ripples, the brook itself between its two grassy banks with reeds and
## pebbles, and the current's streaks. Builder shapes, not Controls: the
## board, the menu card and the tutorial draw the same pieces. Letters are
## the caller's (a draw_string each).

const Pal = preload("res://core/palette.gd")
const Face = preload("res://ui/faces/face.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

const STONE := Color("d3cdbf")
const STONE_LIT := Color("ece8dd")
const STONE_DEEP := Color("a69f90")
const STONE_WET := Color("6f8a8a")
const SLAB := Color("e3d6bb")
const SLAB_LIT := Color("f3ead6")
const SLAB_DEEP := Color("b9a785")
const INK := Color("3e3a33")
const INK_DIM := Color("8c8473")
## The letter a stone changed: warm gold-brown.
const CHANGED := Color("a2620f")
const MOSS := Color("8fbb5a")
const MOSS_DEEP := Color("6c9a3c")
const MOSS_INK := Color("2f4a17")
const WATER := Color("8fcbe0")
const WATER_DEEP := Color("6fb2cf")
const WATER_EDGE := Color("b9e0ec")
const WATER_HI := Color("e4f5fa")
const GRASS := Color("cfe2b0")
const GRASS_LOW := Color("b8d396")
const GRASS_EDGE := Color("9fc07a")
const MUD := Color("b59a72")
const REED := Color("7a9a4c")
const REED_HEAD := Color("8a5a35")
const PEBBLE := Color("c6bba6")

## A river stone of `size` about `at`: a flat irregular round, lit on top,
## a darker wet rim below and the water's ring round it. `seed` shapes it,
## `moss` (0..1) greens its rim (Easy's given stone).
static func stone(b, at: Vector2, size: Vector2, seed: int, moss := 0.0) -> void:
	var pts := _blob(at, size * 0.5, seed)
	# the ripple round it, the wet underside
	b.fan(_blob(at + Vector2(0.0, size.y * 0.12), size * Vector2(0.58, 0.62), seed), Color(WATER_HI, 0.55))
	b.fan(_blob(at + Vector2(0.0, size.y * 0.1), size * 0.5, seed), STONE_WET)
	var first: int = b.verts.size()
	b.fan(pts, Color.WHITE)
	shade(b, first, STONE_LIT, STONE_DEEP, at.y - size.y * 0.5, at.y + size.y * 0.5)
	# a soft sheen across the top
	b.ellipse(at + Vector2(-size.x * 0.12, -size.y * 0.24), size.x * 0.28, size.y * 0.09, Color(1, 1, 1, 0.28))
	if moss > 0.0:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed * 7 + 3
		for k in 9:
			var a := rng.randf_range(PI * 0.15, PI * 0.85) + (PI if k % 2 == 0 else 0.0)
			var p := at + Vector2(cos(a) * size.x * 0.44, sin(a) * size.y * 0.4)
			b.ellipse(p, size.y * rng.randf_range(0.1, 0.18), size.y * rng.randf_range(0.06, 0.11), Color(MOSS, 0.85 * moss))

## A bank's slab: a wide flagstone lying on the grass, squarer than a stone.
static func slab(b, at: Vector2, size: Vector2) -> void:
	var r := size.y * 0.28
	Scenery.soft_disc(b, at + Vector2(0.0, size.y * 0.18), size.x * 0.56, size.y * 0.62, Color(0.2, 0.3, 0.1, 0.22))
	b.fan(Face.Builder.round_rect(at - size * 0.5 + Vector2(0.0, size.y * 0.1), size, r), SLAB_DEEP)
	var first: int = b.verts.size()
	b.fan(Face.Builder.round_rect(at - size * 0.5, size, r), Color.WHITE)
	shade(b, first, SLAB_LIT, SLAB, at.y - size.y * 0.5, at.y + size.y * 0.5)
	# two cracks, the stone's grain
	b.stroke(PackedVector2Array([at + Vector2(-size.x * 0.42, -size.y * 0.1), at + Vector2(-size.x * 0.36, size.y * 0.06), at + Vector2(-size.x * 0.4, size.y * 0.3)]), maxf(1.0, size.y * 0.025), Color(SLAB_DEEP, 0.6))
	b.stroke(PackedVector2Array([at + Vector2(size.x * 0.38, -size.y * 0.32), at + Vector2(size.x * 0.43, -size.y * 0.05)]), maxf(1.0, size.y * 0.025), Color(SLAB_DEEP, 0.6))

## The moss under a letter that already matches the far bank.
static func moss(b, at: Vector2, r: float) -> void:
	b.ellipse(at + Vector2(0.0, r * 0.12), r * 1.02, r * 0.86, MOSS_DEEP)
	b.ellipse(at, r, r * 0.82, MOSS)
	b.ellipse(at + Vector2(-r * 0.3, -r * 0.32), r * 0.34, r * 0.18, Color(1, 1, 1, 0.22))

## Where the next stone will go: two rings of ripples on the water.
static func ripples(b, at: Vector2, size: Vector2) -> void:
	b.stroke(Face.Builder.ring(at, size.x * 0.5, size.y * 0.5), maxf(2.0, size.y * 0.05), Color(WATER_HI, 0.85), true)
	b.stroke(Face.Builder.ring(at, size.x * 0.4, size.y * 0.36), maxf(1.5, size.y * 0.03), Color(WATER_HI, 0.5), true)

## The day's word (the daily theme, 2026-11-06): a little sun medallion
## pinned to a stone's or a slab's corner, its rays out and a dark rim, so
## it reads as a thing on the stone and never as a shade of it.
static func sun_mark(b, at: Vector2, r: float) -> void:
	for k in 8:
		var a := TAU * k / 8.0 - PI * 0.5
		var d := Vector2(cos(a), sin(a))
		var s := Vector2(-d.y, d.x)
		b.polygon(PackedVector2Array([at + d * r * 1.55, at + d * r * 0.8 + s * r * 0.3, at + d * r * 0.8 - s * r * 0.3]), Pal.SUN_DEEP)
	b.disc(at + Vector2(0.0, r * 0.1), r * 1.04, Color(INK, 0.35))
	b.disc(at, r * 1.0, Pal.SUN_DEEP)
	b.disc(at, r * 0.82, Pal.SUN)
	b.ellipse(at + Vector2(-r * 0.25, -r * 0.3), r * 0.32, r * 0.2, Color(1, 1, 1, 0.45))

## The brook edge to edge, `sz`: the near bank's grass down to `near`, the
## water to `far`, the far bank's grass under it; reeds and pebbles along
## both edges.
static func brook(b, sz: Vector2, near: float, far: float, u: float) -> void:
	var w := sz.x
	# the water first, deepening to its middle
	var first: int = b.verts.size()
	b.polygon(PackedVector2Array([Vector2(0, near - 30.0 * u), Vector2(w, near - 30.0 * u), Vector2(w, far + 30.0 * u), Vector2(0, far + 30.0 * u)]), Color.WHITE)
	var mid := (near + far) * 0.5
	for i in range(first, b.verts.size()):
		var y: float = b.verts[i].y
		var k := 1.0 - absf(y - mid) / maxf(1.0, (far - near) * 0.5 + 30.0 * u)
		b.cols[i] = WATER.lerp(WATER_DEEP, clampf(k, 0.0, 1.0) * 0.6)
	# the near bank: grass with a soft wavy lip of mud and pale water
	_bank(b, w, near, -1.0, u, 3)
	_bank(b, w, far, 1.0, u, 9)
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	# reeds at the water's edges, left and right
	for side in [0, 1]:
		for k in 3:
			var x: float = (22.0 + k * 26.0) * u if side == 0 else w - (22.0 + k * 26.0) * u
			var y := near + (6.0 + rng.randf() * 10.0) * u if k != 1 else far - (6.0 + rng.randf() * 10.0) * u
			reed(b, Vector2(x, y), (70.0 + rng.randf() * 40.0) * u, u)
	# lily pads drifting by the sides, clear of the way down the middle
	var span := far - near
	if span > 360.0 * u:
		lily(b, Vector2(w * 0.1, near + span * 0.3), 34.0 * u, 0.3)
		lily(b, Vector2(w * 0.07, near + span * 0.72), 26.0 * u, 2.1)
		lily(b, Vector2(w * 0.92, near + span * 0.2), 28.0 * u, 4.0)
		lily(b, Vector2(w * 0.9, near + span * 0.86), 32.0 * u, 1.2, true)
	# pebbles in the shallows
	for k in 14:
		var top := k % 2 == 0
		var x := rng.randf() * w
		var y := near + rng.randf_range(4.0, 26.0) * u if top else far - rng.randf_range(4.0, 26.0) * u
		var r := rng.randf_range(5.0, 11.0) * u
		b.ellipse(Vector2(x, y), r * 1.3, r * 0.8, Color(PEBBLE, 0.7))

## One bank's grass along `edge`, `dir` -1 above it (the near bank), 1 below
## (the far).
static func _bank(b, w: float, edge: float, dir: float, u: float, seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var lip := PackedVector2Array()
	var steps := 18
	for i in steps + 1:
		var x := w * float(i) / steps
		lip.append(Vector2(x, edge + sin(float(i) * 1.3 + seed) * 7.0 * u))
	var far_y := edge + dir * 4000.0
	# pale water at the edge, then mud, then the grass
	var band := lip.duplicate()
	band.append(Vector2(w, far_y))
	band.append(Vector2(0, far_y))
	var under := PackedVector2Array()
	for p in lip:
		under.append(p - Vector2(0.0, dir * 16.0 * u))
	under.append(Vector2(w, far_y))
	under.append(Vector2(0, far_y))
	b.polygon(under, Color(WATER_EDGE, 0.8))
	var mud := PackedVector2Array()
	for p in lip:
		mud.append(p - Vector2(0.0, dir * 6.0 * u))
	mud.append(Vector2(w, far_y))
	mud.append(Vector2(0, far_y))
	b.polygon(mud, MUD)
	b.polygon(band, GRASS_EDGE)
	var top := PackedVector2Array()
	for p in lip:
		top.append(p + Vector2(0.0, dir * 8.0 * u))
	top.append(Vector2(w, far_y))
	top.append(Vector2(0, far_y))
	var first: int = b.verts.size()
	b.polygon(top, Color.WHITE)
	for i in range(first, b.verts.size()):
		var y: float = b.verts[i].y
		var k := clampf(absf(y - edge) / (260.0 * u), 0.0, 1.0)
		b.cols[i] = GRASS_LOW.lerp(GRASS, k)
	# a few tufts along the lip
	for k in 7:
		var x := rng.randf_range(0.04, 0.96) * w
		Scenery.tuft(b, Vector2(x, edge + dir * rng.randf_range(16.0, 60.0) * u), rng.randf_range(16.0, 26.0) * u)

## A lily pad, notched, turned `turn`; `flower` sets a pink bloom on it.
static func lily(b, at: Vector2, r: float, turn: float, flower := false) -> void:
	b.ellipse(at + Vector2(0.0, r * 0.12), r * 1.04, r * 0.72, Color(WATER_DEEP, 0.7))
	var pts := PackedVector2Array()
	var steps := 24
	for i in steps + 1:
		var a := turn + 0.35 + (TAU - 0.7) * float(i) / steps
		pts.append(at + Vector2(cos(a) * r, sin(a) * r * 0.66))
	pts.append(at)
	b.polygon(pts, Color("7fb45a"))
	b.stroke(PackedVector2Array([at, at + Vector2(cos(turn + PI) * r * 0.8, sin(turn + PI) * r * 0.5)]), maxf(1.0, r * 0.05), Color("5f9443"))
	if flower:
		for k in 6:
			var a := TAU * k / 6.0
			b.ellipse(at + Vector2(cos(a), sin(a) * 0.6) * r * 0.32 + Vector2(0.0, -r * 0.18), r * 0.26, r * 0.15, Color("f2b8c6"))
		b.disc(at + Vector2(0.0, -r * 0.18), r * 0.14, Color("f6d36b"))

## A reed: a tall bent stem with a brown head and a blade.
static func reed(b, root: Vector2, h: float, u: float) -> void:
	var tip := root + Vector2(h * 0.08, -h)
	b.stroke(Face.Builder.bezier2(root, root + Vector2(-h * 0.06, -h * 0.5), tip, 8), maxf(2.0, 4.0 * u), REED)
	b.ellipse(tip + Vector2(0.0, h * 0.14), 5.0 * u, h * 0.13, REED_HEAD)
	b.stroke(Face.Builder.bezier2(root, root + Vector2(h * 0.2, -h * 0.4), root + Vector2(h * 0.34, -h * 0.55), 6), maxf(2.0, 3.0 * u), Color(REED, 0.85))

## The current's streaks: thin pale dashes across the water between `near`
## and `far`, `w` wide (drawn twice by the board, drifting).
static func current(b, w: float, near: float, far: float, u: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	var rows := maxi(3, int((far - near) / (60.0 * u)))
	for i in rows:
		var y := lerpf(near + 30.0 * u, far - 30.0 * u, (float(i) + 0.5) / rows)
		var x := rng.randf() * w
		var len := rng.randf_range(60.0, 140.0) * u
		var pts := PackedVector2Array()
		for k in 7:
			var t := float(k) / 6.0
			pts.append(Vector2(x + t * len, y + sin(t * TAU) * 3.0 * u))
		b.stroke(pts, maxf(1.5, 3.0 * u), Color(WATER_HI, 0.55))

## A slow vertical gradient over the vertices from `first` on.
static func shade(b, first: int, top: Color, bottom: Color, y0: float, y1: float) -> void:
	for i in range(first, b.verts.size()):
		var k := clampf((b.verts[i].y - y0) / maxf(1.0, y1 - y0), 0.0, 1.0)
		b.cols[i] = top.lerp(bottom, k)

## An irregular flat round about `at`, half-size `r`.
static func _blob(at: Vector2, r: Vector2, seed: int) -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var bumps := [rng.randf_range(-0.06, 0.06), rng.randf_range(-0.05, 0.05), rng.randf_range(-0.04, 0.04)]
	var phase := rng.randf() * TAU
	var pts := PackedVector2Array()
	var steps := 36
	for i in steps:
		var a := TAU * float(i) / steps
		var k: float = 1.0 + bumps[0] * sin(a * 2.0 + phase) + bumps[1] * sin(a * 3.0 + phase * 1.7) + bumps[2] * cos(a * 5.0)
		# squarer than an ellipse: a superellipse, flattened top and bottom
		var c := cos(a)
		var s := sin(a)
		var x := signf(c) * pow(absf(c), 0.7)
		var y := signf(s) * pow(absf(s), 0.8)
		pts.append(at + Vector2(x * r.x, y * r.y) * k)
	return pts
