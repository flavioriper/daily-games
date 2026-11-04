extends RefCounted

## Biscuit Tin's drawings: a broken biscuit piece (a golden shortbread
## fragment, rounded where it was the biscuit's rim and jagged where it
## broke, docked with little holes), a whole biscuit with its crimped rim,
## the plate the pieces are laid on, the open tin they lie in, the lid with
## a dimple for every biscuit, and the kitchen table under it all (a checked
## cloth, a teacup, a sugar bowl). Builder shapes, not Controls: the board,
## the menu card and the tutorial draw the same pieces. Letters are the
## caller's (a draw_string each).

const Pal = preload("res://core/palette.gd")
const Face = preload("res://ui/faces/face.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

## Shortbread: its face, its baked edge, its shadow side, the holes.
const BISCUIT := Color("efc37a")
const BISCUIT_LIT := Color("f8dca0")
const BISCUIT_DEEP := Color("c98e45")
const BISCUIT_DARK := Color("9c6528")
const DOCK := Color("b77b36")
## The letters, iced in chocolate.
const INK := Color("5a3416")
## A word just found: warm gold over the piece; a piece picked: lifted.
const GOLD := Color("f4b73f")
const GOLD_DEEP := Color("c98a1e")
## The tin: deep blue enamel with a gold rim.
const TIN := Color("3f6fa8")
const TIN_LIT := Color("5e8fc8")
const TIN_DEEP := Color("2b4f7e")
const TIN_INSIDE := Color("cfd8e2")
const TIN_INSIDE_DEEP := Color("aebccb")
const RIM := Color("e2b75a")
const RIM_LIT := Color("f6dc93")
const RIM_DEEP := Color("a87a2a")
## Paper cases the pieces sit in.
const CASE := Color("fbf6ea")
const CASE_DEEP := Color("e4d8bf")
## The plate.
const CHINA := Color("fdfbf6")
const CHINA_EDGE := Color("d9d2c4")
const CHINA_BAND := Color("8fb3d9")
## The cloth: cream and a soft blue check.
const CLOTH := Color("f7f1e3")
const CLOTH_CHECK := Color("bfd2e6")
const CLOTH_CROSS := Color("a6bfd9")
const SUGAR := Color("f2efe8")

## A piece's size at a scale of 1, by its letters (2, 3, 4).
const PIECE_H := 112.0
const PIECE_W := [0.0, 0.0, 170.0, 196.0, 222.0]

## A piece's outline about the origin, `sz` across: a rounded slab, one or
## two of its sides broken into jags. `seed_at` picks the breaks (fixed per
## piece, never per biscuit, so the shapes give nothing away).
static func piece_outline(sz: Vector2, seed_at: int) -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_at * 7919 + 13
	var half := sz * 0.5
	var r := sz.y * 0.28
	# which sides broke: 0 top, 1 right, 2 bottom, 3 left
	var broke := [false, false, false, false]
	broke[rng.randi_range(0, 3)] = true
	if rng.randf() < 0.6:
		broke[rng.randi_range(0, 3)] = true
	var corners := [Vector2(-half.x, -half.y), Vector2(half.x, -half.y), Vector2(half.x, half.y), Vector2(-half.x, half.y)]
	var pts := PackedVector2Array()
	for side in 4:
		var a: Vector2 = corners[side]
		var b2: Vector2 = corners[(side + 1) % 4]
		var d := (b2 - a).normalized()
		var n := Vector2(d.y, -d.x)
		var len := a.distance_to(b2)
		# the rounded corner at `a`
		var prev: Vector2 = corners[(side + 3) % 4]
		var din := (a - prev).normalized()
		for k in 5:
			var t := k / 4.0
			var p0 := a - din * r
			var p2 := a + d * r
			pts.append(p0.lerp(a, t).lerp(a.lerp(p2, t), t))
		if broke[side]:
			var steps := 4 + rng.randi_range(0, 2)
			for k in range(1, steps):
				var t := float(k) / float(steps)
				var at := a + d * (r + (len - 2.0 * r) * t)
				at += n * rng.randf_range(-0.1, 0.07) * sz.y
				at += d * rng.randf_range(-0.04, 0.04) * len
				pts.append(at)
		else:
			# a gentle bulge, the biscuit's rim
			for k in range(1, 4):
				var t := k / 4.0
				pts.append(a + d * (r + (len - 2.0 * r) * t) + n * sin(t * PI) * sz.y * 0.025)
		pts.append(b2 - d * r)
	return pts

## A piece about the origin, `sz` across: its shadow, its baked edge, the
## face, its lit top, the docking holes. `lit`: gold (a word just found);
## `ghost`: only a faint outline (the piece is on the plate).
static func piece(b, sz: Vector2, seed_at: int, lit := 0.0, ghost := false) -> void:
	var out := piece_outline(sz, seed_at)
	if ghost:
		b.stroke(out, maxf(2.0, sz.y * 0.035), Color(BISCUIT_DARK, 0.28), true)
		return
	var shadow := PackedVector2Array()
	var edge := PackedVector2Array()
	for p in out:
		shadow.append(p + Vector2(sz.y * 0.03, sz.y * 0.1))
		edge.append(p + Vector2(0.0, sz.y * 0.06))
	b.fan(shadow, Color(0.25, 0.14, 0.05, 0.22))
	b.fan(edge, BISCUIT_DARK.lerp(GOLD_DEEP, lit))
	var tone := RandomNumberGenerator.new()
	tone.seed = seed_at * 31 + 5
	var face := BISCUIT.lerp(BISCUIT_LIT, tone.randf() * 0.45).lerp(GOLD, lit * 0.8)
	var first: int = b.verts.size()
	b.fan(out, Color.WHITE)
	_shade(b, first, face.lightened(0.12), face.darkened(0.06), -sz.y * 0.5, sz.y * 0.5)
	b.stroke(out, maxf(1.5, sz.y * 0.025), Color(BISCUIT_DEEP, 0.55), true)
	# docking holes in the corners, clear of the letters
	for k in 4:
		var at := Vector2((-0.36 if k % 2 == 0 else 0.36) * sz.x, (-0.3 if k < 2 else 0.3) * sz.y)
		if tone.randf() < 0.7:
			b.ellipse(at, sz.y * 0.035, sz.y * 0.03, Color(DOCK, 0.7))

## A whole biscuit about `at`, `r` across: a crimped round with holes
## round its middle. Its word is the caller's.
static func whole(b, at: Vector2, r: float, kind := 0) -> void:
	var face: Color = [BISCUIT, Color("e7b06a"), Color("f0cf8c"), Color("d9a05c"), Color("f2c88a")][kind % 5]
	var rim := PackedVector2Array()
	var n := 48
	for k in n:
		var a := TAU * k / n
		var rr := r * (1.0 + (0.035 if k % 2 == 0 else -0.01))
		rim.append(at + Vector2(cos(a), sin(a)) * rr)
	b.ellipse(at + Vector2(r * 0.05, r * 0.14), r * 1.02, r * 0.98, Color(0.25, 0.14, 0.05, 0.22))
	var under := PackedVector2Array()
	for p in rim:
		under.append(p + Vector2(0.0, r * 0.08))
	b.fan(under, BISCUIT_DARK)
	var first: int = b.verts.size()
	b.fan(rim, Color.WHITE)
	_shade(b, first, face.lightened(0.15), face.darkened(0.08), at.y - r, at.y + r)
	b.stroke(Face.Builder.ring(at, r * 0.86, r * 0.86), maxf(1.5, r * 0.035), Color(BISCUIT_DEEP, 0.5), true)
	for k in 8:
		var a := TAU * k / 8.0 + 0.2
		b.ellipse(at + Vector2(cos(a), sin(a)) * r * 0.7, r * 0.04, r * 0.035, Color(DOCK, 0.7))

## An empty dimple on the lid for a biscuit not made yet, `r` across.
static func dimple(b, at: Vector2, r: float) -> void:
	b.disc(at + Vector2(0.0, r * 0.05), r, TIN_DEEP)
	b.disc(at, r * 0.96, TIN.lerp(TIN_DEEP, 0.35))
	b.stroke(Face.Builder.arc_points(at, r * 0.9, PI * 0.15, PI * 0.85), maxf(1.5, r * 0.06), Color(TIN_LIT, 0.6))

## The plate the pieces are laid on, `rect` its oval's box, seen from a
## little above: china with a blue band, a shadow on the cloth.
static func plate(b, rect: Rect2) -> void:
	var c := rect.get_center()
	var rx := rect.size.x * 0.5
	var ry := rect.size.y * 0.5
	Scenery.soft_disc(b, c + Vector2(0.0, ry * 0.18), rx * 1.04, ry * 1.08, Color(0.2, 0.18, 0.12, 0.26))
	b.ellipse(c + Vector2(0.0, ry * 0.06), rx, ry, CHINA_EDGE)
	b.ellipse(c, rx, ry, CHINA)
	b.stroke(Face.Builder.ring(c, rx * 0.93, ry * 0.88), maxf(2.0, ry * 0.04), Color(CHINA_BAND, 0.85), true)
	b.ellipse(c + Vector2(0.0, ry * 0.04), rx * 0.8, ry * 0.68, Color(CHINA_EDGE, 0.35))
	b.ellipse(c, rx * 0.79, ry * 0.66, CHINA)

## The open tin, `rect` its inside: a gold-rimmed blue enamel wall round a
## pale tin floor with paper cases, seen from above.
static func tin(b, rect: Rect2, wall: float) -> void:
	var outer := rect.grow(wall)
	var r := wall * 2.2
	Scenery.soft_disc(b, outer.get_center() + Vector2(0.0, outer.size.y * 0.04), outer.size.x * 0.56, outer.size.y * 0.56, Color(0.2, 0.18, 0.12, 0.25))
	b.fan(Face.Builder.round_rect(outer.position + Vector2(0.0, wall * 0.35), outer.size, r), TIN_DEEP)
	var first: int = b.verts.size()
	b.fan(Face.Builder.round_rect(outer.position, outer.size, r), Color.WHITE)
	_shade(b, first, TIN_LIT, TIN, outer.position.y, outer.end.y)
	# the gold rim round its mouth
	b.stroke(Face.Builder.round_rect(outer.position + Vector2.ONE * wall * 0.22, outer.size - Vector2.ONE * wall * 0.44, r * 0.9), wall * 0.3, RIM_DEEP, true)
	b.stroke(Face.Builder.round_rect(outer.position + Vector2.ONE * wall * 0.18, outer.size - Vector2.ONE * wall * 0.44, r * 0.9), wall * 0.2, RIM_LIT, true)
	# a pattern of little gold flowers on the blue
	var k := 0
	var x := outer.position.x + wall * 0.5
	while x < outer.end.x - wall * 0.3:
		for y in [outer.position.y + wall * 0.62, outer.end.y - wall * 0.38]:
			_flower(b, Vector2(x, y), wall * 0.16, RIM if k % 2 == 0 else RIM_LIT)
			k += 1
		x += wall * 1.1
	# the floor inside
	b.fan(Face.Builder.round_rect(rect.position, rect.size, r * 0.6), TIN_INSIDE_DEEP)
	b.fan(Face.Builder.round_rect(rect.position + Vector2(0.0, wall * 0.22), rect.size - Vector2(0.0, wall * 0.22), r * 0.6), TIN_INSIDE)

## A paper case under a piece's place in the tin, `sz` across about `at`.
static func case(b, at: Vector2, sz: Vector2) -> void:
	var half := sz * 0.5
	b.fan(Face.Builder.round_rect(at - half, sz, sz.y * 0.3), CASE_DEEP)
	b.fan(Face.Builder.round_rect(at - half + Vector2(sz.y * 0.06, sz.y * 0.06), sz - Vector2.ONE * sz.y * 0.12, sz.y * 0.26), CASE)
	# the case's pleats
	var x := at.x - half.x + sz.y * 0.25
	while x < at.x + half.x - sz.y * 0.2:
		b.polygon(_box(Vector2(x, at.y - half.y + sz.y * 0.08), Vector2(maxf(1.0, sz.y * 0.02), sz.y * 0.84)), Color(CASE_DEEP, 0.5))
		x += sz.y * 0.18

## The lid, `rect`: blue enamel with a gold rim, a dimple per biscuit.
static func lid(b, rect: Rect2) -> void:
	var r := rect.size.y * 0.32
	Scenery.soft_disc(b, rect.get_center() + Vector2(0.0, rect.size.y * 0.12), rect.size.x * 0.54, rect.size.y * 0.62, Color(0.2, 0.18, 0.12, 0.22))
	b.fan(Face.Builder.round_rect(rect.position + Vector2(0.0, rect.size.y * 0.06), rect.size, r), TIN_DEEP)
	var first: int = b.verts.size()
	b.fan(Face.Builder.round_rect(rect.position, rect.size, r), Color.WHITE)
	_shade(b, first, TIN_LIT, TIN, rect.position.y, rect.end.y)
	var w := rect.size.y * 0.07
	b.stroke(Face.Builder.round_rect(rect.position + Vector2.ONE * w, rect.size - Vector2.ONE * w * 2.0, r * 0.85), w, RIM, true)
	b.stroke(Face.Builder.round_rect(rect.position + Vector2.ONE * w * 0.8, rect.size - Vector2.ONE * w * 2.0, r * 0.85), w * 0.4, RIM_LIT, true)

## The kitchen table edge to edge, `sz`: a cream cloth with a soft blue
## check, its weave crossing darker.
static func cloth(b, sz: Vector2, u: float) -> void:
	b.polygon(_box(Vector2.ZERO, sz), CLOTH)
	var band := 90.0 * u
	var x := -band * 0.5
	while x < sz.x:
		b.polygon(_box(Vector2(x, 0.0), Vector2(band, sz.y)), Color(CLOTH_CHECK, 0.45))
		x += band * 2.0
	var y := -band * 0.3
	while y < sz.y:
		b.polygon(_box(Vector2(0.0, y), Vector2(sz.x, band)), Color(CLOTH_CHECK, 0.45))
		y += band * 2.0
	# a fine weave line through the middle of each band
	x = 0.0
	while x < sz.x:
		b.polygon(_box(Vector2(x - 1.0 * u, 0.0), Vector2(2.0 * u, sz.y)), Color(CLOTH_CROSS, 0.25))
		x += band * 2.0
	y = band * 0.2
	while y < sz.y:
		b.polygon(_box(Vector2(0.0, y - 1.0 * u), Vector2(sz.x, 2.0 * u)), Color(CLOTH_CROSS, 0.25))
		y += band * 2.0

## A sugar bowl seen from above at `c`, `r` across: china, sugar cubes.
static func sugar(b, c: Vector2, r: float) -> void:
	b.ellipse(c + Vector2(r * 0.06, r * 0.14), r, r, Color(0.1, 0.06, 0.02, 0.2))
	b.disc(c + Vector2(0.0, r * 0.06), r, CHINA_EDGE)
	b.disc(c, r, CHINA)
	b.stroke(Face.Builder.ring(c, r * 0.86, r * 0.86), maxf(1.5, r * 0.06), Color(CHINA_BAND, 0.8), true)
	b.disc(c, r * 0.72, CHINA_EDGE)
	for k in 5:
		var a := TAU * k / 5.0 + 0.4
		var at := c + Vector2(cos(a), sin(a)) * r * 0.32
		var s := r * 0.2
		b.polygon(PackedVector2Array([at + Vector2(-s, -s * 0.7).rotated(a), at + Vector2(s, -s * 0.7).rotated(a), at + Vector2(s, s * 0.7).rotated(a), at + Vector2(-s, s * 0.7).rotated(a)]), SUGAR if k % 2 == 0 else Color.WHITE)

## Crumbs strewn round `at` (a biscuit broken, a crumb swept), `r` the
## spread.
static func crumbs(b, at: Vector2, r: float, seed_at: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_at
	for k in 7:
		var p := at + Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-0.5, 0.5)) * r
		b.ellipse(p, r * rng.randf_range(0.03, 0.06), r * rng.randf_range(0.02, 0.05), BISCUIT_DEEP.lerp(BISCUIT, rng.randf()))

static func _flower(b, at: Vector2, s: float, col: Color) -> void:
	for k in 5:
		var a := TAU * k / 5.0
		b.disc(at + Vector2(cos(a), sin(a)) * s, s * 0.6, col)
	b.disc(at, s * 0.5, RIM_DEEP)

static func _box(at: Vector2, sz: Vector2) -> PackedVector2Array:
	return PackedVector2Array([at, at + Vector2(sz.x, 0.0), at + sz, at + Vector2(0.0, sz.y)])

static func _shade(b, first: int, top: Color, bottom: Color, y0: float, y1: float) -> void:
	for i in range(first, b.verts.size()):
		var c := top.lerp(bottom, clampf(inverse_lerp(y0, y1, b.verts[i].y), 0.0, 1.0))
		b.cols[i] = Color(c.r, c.g, c.b, b.cols[i].a * c.a)
