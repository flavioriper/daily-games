extends RefCounted

## Posy's drawings (spec docs/superpowers/specs/2026-09-27-arcade-posy-design.md):
## the six garden tiles (a red flower, a leaf, a water drop, a yellow
## mushroom, a plum berry, an acorn), the rainbow posy, a breeze's streaks
## and a seed bomb's glow laid over a tile, the bee who sits on a tile and
## flies off it, the bed's weeds, stones and moss, the four tools' pictures
## and the day's sprout. Each is built once per look and size, its origin at the
## centre, and moved by the draw transform; shared with the Arcade tab's
## banner.

const Face = preload("res://ui/faces/face.gd")
const CozyTheme = preload("res://ui/theme.gd")

const INK := Color("3b3028")
const CREAM := Color("fbf3e2")
const CELL := Color("f4e6c9")
const CELL_DEEP := Color("e6d2ab")
const BOARD := Color("ecd9b4")
const WOOD := Color("c9a172")
const WOOD_DEEP := Color("9c7447")
const LEAF := Color("5dbb4a")
const LEAF_DEEP := Color("3d8f35")
const GOLD := Color("f2b632")
const BADGE := Color("3f95e0")
## Each kind's paint: the body and its shade.
const PAINT := [Color("e8453c"), Color("5dbb4a"), Color("3fa3ea"), Color("f6c53d"), Color("9b52c4"), Color("c98a4a")]
const RAINBOW := [Color("ec5a4f"), Color("f59a3c"), Color("f6cf42"), Color("68c05a"), Color("4aa3e8"), Color("a064d2")]

static var _cache := {}

const STONE := Color("a39d94")
const MOSS := Color("6f9e3c")
const WEED := Color("7cb342")
const SOIL := Color("b89464")

static func paint(k: int) -> Color:
	if k < 0:
		return GOLD
	match k:
		10: return WEED
		11: return STONE
		12: return MOSS
	return PAINT[clampi(k, 0, PAINT.size() - 1)]

static func _cached(key: String, build: Callable) -> ArrayMesh:
	if _cache.has(key):
		return _cache[key]
	if _cache.size() > 400:
		_cache.clear()
	var b := Face.Builder.new()
	build.call(b)
	var m := b.mesh()
	_cache[key] = m
	return m

## A tile of kind `k` (-1 the rainbow posy), `s` pixels across, centred.
static func tile(k: int, s: float) -> ArrayMesh:
	return _cached("t%d_%d" % [k, roundi(s)], func(b: Face.Builder) -> void: _build_tile(b, k, s))

static func _flower(b: Face.Builder, r: float) -> void:
	var body := PAINT[0]
	var deep := body.darkened(0.25)
	for i in 5:
		var d := Vector2.from_angle(TAU * i / 5.0 - PI * 0.5)
		b.disc(d * r * 0.44 + Vector2(r * 0.02, r * 0.05), r * 0.37, deep)
	for i in 5:
		var d := Vector2.from_angle(TAU * i / 5.0 - PI * 0.5)
		b.disc(d * r * 0.43, r * 0.33, body)
		b.ellipse(d * r * 0.5 + Vector2(-r * 0.06, -r * 0.07), r * 0.12, r * 0.07, Color(1, 1, 1, 0.3))
	b.disc(Vector2(r * 0.02, r * 0.03), r * 0.3, Color("e0902a"))
	b.disc(Vector2.ZERO, r * 0.26, Color("f7c948"))
	b.disc(Vector2(-r * 0.08, -r * 0.08), r * 0.08, Color(1, 1, 1, 0.55))

static func _leaf_outline(r: float, turn: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n := 18
	var L := r * 0.92
	var w := r * 0.52
	for i in n + 1:
		var t := float(i) / n
		pts.append(Vector2(lerpf(-L, L, t), -w * pow(sin(PI * t), 0.75)).rotated(turn))
	for i in range(n - 1, 0, -1):
		var t := float(i) / n
		pts.append(Vector2(lerpf(-L, L, t), w * pow(sin(PI * t), 0.75)).rotated(turn))
	return pts

static func _leaf(b: Face.Builder, r: float) -> void:
	var turn := -PI * 0.25
	var under := _leaf_outline(r, turn)
	for i in under.size():
		under[i] += Vector2(r * 0.03, r * 0.06)
	b.polygon(under, LEAF_DEEP)
	b.polygon(_leaf_outline(r * 0.95, turn), LEAF)
	# the lit half, up and to the left of the rib
	var lit := PackedVector2Array()
	for i in 19:
		var t := i / 18.0
		lit.append(Vector2(lerpf(-r * 0.85, r * 0.85, t), -r * 0.46 * pow(sin(PI * t), 0.75)).rotated(turn))
	b.polygon(lit, LEAF.lightened(0.12))
	var a := Vector2(-r * 0.95, 0).rotated(turn)
	var z := Vector2(r * 0.8, 0).rotated(turn)
	b.stroke(PackedVector2Array([a, z]), maxf(1.5, r * 0.07), LEAF_DEEP.lightened(0.05))
	for i in 3:
		var t := 0.3 + 0.2 * i
		var on := a.lerp(z, t)
		for side in [-1.0, 1.0]:
			b.stroke(PackedVector2Array([on, on + Vector2(r * 0.22, side * r * 0.24).rotated(turn)]), maxf(1.0, r * 0.045), Color(LEAF_DEEP, 0.7))
	# the stalk
	b.stroke(PackedVector2Array([a, a + Vector2(-r * 0.12, r * 0.08).rotated(turn)]), maxf(1.5, r * 0.08), LEAF_DEEP)

static func _drop_outline(r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var c := Vector2(0, r * 0.22)
	var rr := r * 0.64
	pts.append(Vector2(0, -r * 0.92))
	for i in 25:
		var a := lerpf(-PI * 0.18, PI * 1.18, i / 24.0)
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	return pts

static func _drop(b: Face.Builder, r: float) -> void:
	var body := PAINT[2]
	var under := _drop_outline(r)
	for i in under.size():
		under[i] += Vector2(r * 0.03, r * 0.05)
	b.polygon(under, body.darkened(0.28))
	b.polygon(_drop_outline(r * 0.95), body)
	b.ellipse(Vector2(r * 0.08, r * 0.38), r * 0.38, r * 0.2, Color(body.darkened(0.12), 0.6))
	b.ellipse(Vector2(-r * 0.22, r * 0.02), r * 0.14, r * 0.26, Color(1, 1, 1, 0.45))
	b.disc(Vector2(-r * 0.1, -r * 0.34), r * 0.07, Color(1, 1, 1, 0.6))

static func _mushroom(b: Face.Builder, r: float) -> void:
	var cap := PAINT[3]
	var stem := Color("fbeed2")
	# the stem
	var sp := Face.Builder.round_rect(Vector2(-r * 0.26, -r * 0.05), Vector2(r * 0.52, r * 0.82), r * 0.2)
	b.polygon(sp, stem.darkened(0.12))
	var sp2 := Face.Builder.round_rect(Vector2(-r * 0.24, -r * 0.05), Vector2(r * 0.42, r * 0.78), r * 0.18)
	b.polygon(sp2, stem)
	# the cap: a dome over a flat, paler rim
	var dome := PackedVector2Array()
	for i in 25:
		var a := lerpf(PI, TAU, i / 24.0)
		dome.append(Vector2(cos(a) * r * 0.9, sin(a) * r * 0.78 + r * 0.08))
	for i in 9:
		var t := i / 8.0
		dome.append(Vector2(lerpf(r * 0.9, -r * 0.9, t), r * 0.08 + sin(t * PI) * r * 0.16))
	var under := PackedVector2Array()
	for p in dome:
		under.append(p + Vector2(r * 0.03, r * 0.06))
	b.polygon(under, cap.darkened(0.28))
	b.polygon(dome, cap)
	b.ellipse(Vector2(-r * 0.25, -r * 0.35), r * 0.3, r * 0.16, Color(1, 1, 1, 0.35))
	b.disc(Vector2(r * 0.4, -r * 0.3), r * 0.1, Color(1, 1, 1, 0.3))
	b.disc(Vector2(r * 0.05, -r * 0.5), r * 0.07, Color(1, 1, 1, 0.3))

static func _berry(b: Face.Builder, r: float) -> void:
	var body := PAINT[4]
	var c := Vector2(0, r * 0.12)
	b.disc(c + Vector2(r * 0.03, r * 0.05), r * 0.76, body.darkened(0.3))
	b.disc(c, r * 0.72, body)
	b.ellipse(c + Vector2(-r * 0.12, -r * 0.14), r * 0.5, r * 0.44, body.lightened(0.08))
	b.stroke(Face.Builder.arc_points(c + Vector2(r * 0.12, 0), r * 0.46, -PI * 0.35, PI * 0.35), maxf(1.0, r * 0.05), Color(body.darkened(0.25), 0.6))
	b.ellipse(c + Vector2(-r * 0.32, -r * 0.3), r * 0.16, r * 0.1, Color(1, 1, 1, 0.5))
	# the stalk and two little leaves
	var top := c + Vector2(0, -r * 0.66)
	b.stroke(PackedVector2Array([top, top + Vector2(r * 0.05, -r * 0.2)]), maxf(1.5, r * 0.07), Color("6b4a2a"))
	for side in [-1.0, 1.0]:
		var at := top + Vector2(side * r * 0.2, -r * 0.08)
		var shade := _leaf_outline(r * 0.26, side * 0.35)
		var small := _leaf_outline(r * 0.24, side * 0.35)
		for i in shade.size():
			shade[i] += at + Vector2(r * 0.02, r * 0.03)
		for i in small.size():
			small[i] += at
		b.polygon(shade, LEAF_DEEP)
		b.polygon(small, LEAF)

static func _acorn(b: Face.Builder, r: float) -> void:
	var nut := PAINT[5]
	var cap := Color("7a5230")
	var body := PackedVector2Array()
	for i in 25:
		var a := lerpf(0.0, PI, i / 24.0)
		body.append(Vector2(cos(a) * r * 0.58, sin(a) * r * 0.74 + r * 0.05))
	body.append(Vector2(-r * 0.58, -r * 0.1))
	body.append(Vector2(r * 0.58, -r * 0.1))
	var under := PackedVector2Array()
	for p in body:
		under.append(p + Vector2(r * 0.03, r * 0.05))
	b.polygon(under, nut.darkened(0.3))
	b.polygon(body, nut)
	b.ellipse(Vector2(-r * 0.22, r * 0.25), r * 0.12, r * 0.24, Color(1, 1, 1, 0.3))
	b.disc(Vector2(0, r * 0.78), r * 0.05, nut.darkened(0.35))
	# the cap, scaled, with its stalk
	b.ellipse(Vector2(r * 0.03, -r * 0.2), r * 0.76, r * 0.36, cap.darkened(0.25))
	b.ellipse(Vector2(0, -r * 0.24), r * 0.74, r * 0.33, cap)
	for i in 5:
		for j in 2:
			b.disc(Vector2((i - 2) * r * 0.26 + j * r * 0.13, -r * 0.34 + j * r * 0.15), r * 0.06, Color(cap.lightened(0.2), 0.8))
	b.stroke(PackedVector2Array([Vector2(0, -r * 0.52), Vector2(r * 0.1, -r * 0.78)]), maxf(1.5, r * 0.1), cap.darkened(0.2))

static func _rainbow(b: Face.Builder, r: float) -> void:
	for i in 6:
		var d := Vector2.from_angle(TAU * i / 6.0 - PI * 0.5)
		b.disc(d * r * 0.46 + Vector2(r * 0.02, r * 0.05), r * 0.36, RAINBOW[i].darkened(0.25))
	for i in 6:
		var d := Vector2.from_angle(TAU * i / 6.0 - PI * 0.5)
		b.disc(d * r * 0.45, r * 0.32, RAINBOW[i])
		b.ellipse(d * r * 0.52 + Vector2(-r * 0.05, -r * 0.06), r * 0.11, r * 0.06, Color(1, 1, 1, 0.35))
	b.disc(Vector2(r * 0.02, r * 0.03), r * 0.3, Color("e8d9b8"))
	b.disc(Vector2.ZERO, r * 0.27, CREAM)
	_star(b, Vector2.ZERO, r * 0.2, Color(GOLD, 0.95))

static func _star(b: Face.Builder, c: Vector2, r: float, col: Color, turn := 0.0) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := TAU * i / 10.0 - PI * 0.5 + turn
		pts.append(c + Vector2.from_angle(a) * (r if i % 2 == 0 else r * 0.45))
	b.polygon(pts, col)

## A fat five-pointed star laid into a builder, with a darker rim under it
## and a shine on its upper left: the rewards' star.
static func star(b: Face.Builder, c: Vector2, r: float, col: Color, turn := 0.0) -> void:
	_star(b, c + Vector2(r * 0.04, r * 0.1), r * 1.08, Color(col.darkened(0.35), col.a), turn)
	var pts := PackedVector2Array()
	for i in 10:
		var a := TAU * i / 10.0 - PI * 0.5 + turn
		pts.append(c + Vector2.from_angle(a) * (r if i % 2 == 0 else r * 0.52))
	b.polygon(pts, col)
	b.ellipse(c + Vector2(-r * 0.18, -r * 0.2), r * 0.18, r * 0.11, Color(1, 1, 1, 0.5 * col.a))

## A sunburst: `n` rays between `r0` and `r1`, turned by `turn`.
static func rays(b: Face.Builder, c: Vector2, r0: float, r1: float, n: int, turn: float, col: Color) -> void:
	var half := PI / n * 0.5
	for i in n:
		var a := TAU * i / n + turn
		b.polygon(PackedVector2Array([c + Vector2.from_angle(a - half * 0.4) * r0, c + Vector2.from_angle(a - half) * r1,
			c + Vector2.from_angle(a + half) * r1, c + Vector2.from_angle(a + half * 0.4) * r0]), col)

## A petal (or, long and green, a leaf; flat, a scrap of confetti): an
## ellipse turned by `rot`.
static func petal(b: Face.Builder, c: Vector2, rx: float, ry: float, rot: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := TAU * i / 10.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot))
	b.fan(pts, col)

## A breeze laid over a tile, streaking across it (turn it a quarter for a
## column): white streaks and an arrowhead at each end.
static func breeze(s: float) -> ArrayMesh:
	return _cached("b%d" % roundi(s), func(b: Face.Builder) -> void: _build_breeze(b, s))

## A seed bomb's glow under its tile: a golden halo and a ring of seeds.
static func bomb_glow(s: float, hot := false) -> ArrayMesh:
	return _cached("g%d_%s" % [roundi(s), hot], func(b: Face.Builder) -> void: _build_bomb_glow(b, s, hot))

## A four-pointed twinkle laid into a builder.
static func glint(b: Face.Builder, c: Vector2, r: float, turn: float, col := Color(1, 1, 0.95, 0.95)) -> void:
	b.disc(c, r * 0.45, Color(col, col.a * 0.25))
	for k in 4:
		var d := Vector2.from_angle(TAU * k / 4.0 + turn)
		var side := d.orthogonal() * r * 0.13
		b.polygon(PackedVector2Array([c + side, c + d * r * (1.0 if k % 2 == 0 else 0.7), c - side]), col)
	b.disc(c, r * 0.14, Color(1, 1, 1, col.a))

## A tool's picture, `s` across, centred: the trowel, the two turning
## arrows, the bomb with its fuse lit, the rainbow posy.
static func tool_icon(tool: String, s: float) -> ArrayMesh:
	return _cached("i%s_%d" % [tool, roundi(s)], func(b: Face.Builder) -> void: _build_tool_icon(b, tool, s))

## The day's sprout: two leaves on a stalk.
static func sprout(s: float) -> ArrayMesh:
	return _cached("s%d" % roundi(s), func(b: Face.Builder) -> void: _build_sprout(b, s))

## The display face every number is lettered in.
static func font() -> Font:
	return CozyTheme.display(700)

static func _build_tile(b: Face.Builder, k: int, s: float) -> void:
	var r := s * 0.5
	# a soft shadow on the cell, down and to the right
	b.ellipse(Vector2(r * 0.06, r * 0.62), r * 0.62, r * 0.16, Color(0.35, 0.22, 0.08, 0.16))
	match k:
		0: _flower(b, r)
		1: _leaf(b, r)
		2: _drop(b, r)
		3: _mushroom(b, r)
		4: _berry(b, r)
		5: _acorn(b, r)
		10: _weed_icon(b, r)
		11: _stone(b, r, 2)
		12: _moss(b, r)
		_: _rainbow(b, r)

static func _build_breeze(b: Face.Builder, s: float) -> void:
	var r := s * 0.5
	for i in 3:
		var y := (i - 1) * r * 0.32
		var pts := PackedVector2Array()
		for q in 9:
			var t := q / 8.0
			pts.append(Vector2(lerpf(-r * 0.78, r * 0.78, t), y + sin(t * TAU + i) * r * 0.05))
		b.stroke(pts, maxf(2.0, r * 0.1), Color(1, 1, 1, 0.5 if i != 1 else 0.85))
	for side in [-1.0, 1.0]:
		var tip := Vector2(side * r * 1.02, 0)
		var back := Vector2(side * r * 0.7, 0)
		b.polygon(PackedVector2Array([tip, back + Vector2(0, -r * 0.24), back + Vector2(0, r * 0.24)]), Color(1, 1, 1, 0.95))
		b.stroke(PackedVector2Array([back + Vector2(0, -r * 0.24), tip, back + Vector2(0, r * 0.24)]), maxf(1.5, r * 0.05), Color(INK, 0.35))

static func _build_bomb_glow(b: Face.Builder, s: float, hot := false) -> void:
	var r := s * 0.5
	var c := Color("f07a3a") if hot else GOLD
	b.disc(Vector2.ZERO, r * 1.0, Color(c, 0.22))
	b.disc(Vector2.ZERO, r * 0.86, Color(c, 0.25))
	b.stroke(Face.Builder.ring(Vector2.ZERO, r * 0.9, r * 0.9), maxf(2.0, r * 0.08), Color(c.lightened(0.2), 0.9), true)
	for i in 8:
		var d := Vector2.from_angle(TAU * i / 8.0 + PI / 8.0)
		b.ellipse(d * r * 0.9, r * 0.08, r * 0.08, Color("7a5230"))
		b.disc(d * r * 0.9 + Vector2(-r * 0.02, -r * 0.02), r * 0.035, Color(1, 1, 1, 0.5))

static func _build_tool_icon(b: Face.Builder, tool: String, s: float) -> void:
	var r := s * 0.5
	match tool:
		"trowel":
			var turn := PI * 0.25
			# the handle, wood, down to the lower left
			var h := Face.Builder.round_rect(Vector2(-r * 0.12, r * 0.05), Vector2(r * 0.24, r * 0.62), r * 0.1)
			for i in h.size():
				h[i] = h[i].rotated(turn)
			b.polygon(h, Color("8e5a2c"))
			b.stroke(PackedVector2Array([Vector2(-r * 0.04, r * 0.12).rotated(turn), Vector2(-r * 0.04, r * 0.6).rotated(turn)]), maxf(1.0, r * 0.05), Color(1, 1, 1, 0.3))
			b.stroke(PackedVector2Array([Vector2(0, -r * 0.05).rotated(turn), Vector2(0, r * 0.08).rotated(turn)]), r * 0.14, Color("8a8f98"))
			# the blade, pointing up and to the right
			var blade := PackedVector2Array()
			for i in 13:
				var t := i / 12.0
				blade.append(Vector2(-r * 0.34 * sin(PI * (0.5 + t * 0.5)) - r * 0.02, lerpf(-r * 0.08, -r * 0.92, t)))
			for i in range(12, -1, -1):
				var t := i / 12.0
				blade.append(Vector2(r * 0.34 * sin(PI * (0.5 + t * 0.5)) + r * 0.02, lerpf(-r * 0.08, -r * 0.92, t)))
			for i in blade.size():
				blade[i] = blade[i].rotated(turn)
			b.polygon(blade, Color("a9b0ba"))
			var lit := PackedVector2Array()
			for i in blade.size() / 2:
				lit.append(blade[i])
			lit.append(Vector2(0, -r * 0.92).rotated(turn))
			b.polygon(lit, Color("cfd5dc"))
			b.stroke(PackedVector2Array([Vector2(0, -r * 0.14).rotated(turn), Vector2(0, -r * 0.8).rotated(turn)]), maxf(1.0, r * 0.05), Color("7d848e"))
		"swap":
			var c1 := Color("e8453c")
			var c2 := Color("5dbb4a")
			var arc1 := Face.Builder.arc_points(Vector2(0, r * 0.05), r * 0.56, PI * 1.08, PI * 1.9)
			b.stroke(arc1, r * 0.24, c1.darkened(0.2))
			b.stroke(arc1, r * 0.17, c1)
			var t1: Vector2 = arc1[arc1.size() - 1]
			b.polygon(PackedVector2Array([t1 + Vector2(-r * 0.2, -r * 0.2), t1 + Vector2(r * 0.3, r * 0.02), t1 + Vector2(-r * 0.12, r * 0.28)]), c1.darkened(0.1))
			var arc2 := Face.Builder.arc_points(Vector2(0, -r * 0.05), r * 0.56, PI * 0.08, PI * 0.9)
			b.stroke(arc2, r * 0.24, c2.darkened(0.2))
			b.stroke(arc2, r * 0.17, c2)
			var t2: Vector2 = arc2[arc2.size() - 1]
			b.polygon(PackedVector2Array([t2 + Vector2(r * 0.2, r * 0.2), t2 + Vector2(-r * 0.3, -r * 0.02), t2 + Vector2(r * 0.12, -r * 0.28)]), c2.darkened(0.1))
		"bomb":
			var c := Vector2(-r * 0.08, r * 0.14)
			b.disc(c + Vector2(r * 0.04, r * 0.06), r * 0.62, Color("1c1a22"))
			b.disc(c, r * 0.6, Color("34313c"))
			b.ellipse(c + Vector2(-r * 0.22, -r * 0.24), r * 0.18, r * 0.11, Color(1, 1, 1, 0.35))
			var neck := c + Vector2.from_angle(-PI * 0.3) * r * 0.55
			b.polygon(Face.Builder.round_rect(neck + Vector2(-r * 0.14, -r * 0.12), Vector2(r * 0.28, r * 0.22), r * 0.05), Color("5a5664"))
			var fuse := Face.Builder.bezier2(neck + Vector2(0, -r * 0.1), neck + Vector2(r * 0.25, -r * 0.4), neck + Vector2(r * 0.42, -r * 0.3), 8)
			b.stroke(fuse, maxf(1.5, r * 0.07), Color("b58a55"))
			var spark: Vector2 = fuse[fuse.size() - 1]
			_star(b, spark, r * 0.26, Color("f59a3c"))
			_star(b, spark, r * 0.15, Color("f7d44a"))
		"rainbow":
			_rainbow(b, r * 0.95)

static func _build_sprout(b: Face.Builder, s: float) -> void:
	var r := s * 0.5
	b.stroke(Face.Builder.bezier2(Vector2(0, r * 0.9), Vector2(r * 0.05, r * 0.2), Vector2(0, -r * 0.1), 8), maxf(2.0, r * 0.12), LEAF_DEEP)
	for side in [-1.0, 1.0]:
		var leaf := _leaf_outline(r * 0.55, side * -0.45 + (PI if side < 0 else 0.0))
		for i in leaf.size():
			leaf[i] += Vector2(side * r * 0.45, -r * 0.3)
		b.polygon(leaf, LEAF)
	b.ellipse(Vector2(0, r * 0.92), r * 0.5, r * 0.12, Color("8e6a3c"))

# --- the bee and the bed's ground ---

## A bee sitting on a tile (drawn over it, up in its corner), or on its own,
## flying: `s` is the tile's size. Its wings are a second mesh, so they beat
## by the transform.
static func bee(s: float) -> ArrayMesh:
	return _cached("bee%d" % roundi(s), func(b: Face.Builder) -> void: _build_bee(b, s * 0.5 * 0.5))

static func bee_wings(s: float) -> ArrayMesh:
	return _cached("bw%d" % roundi(s), func(b: Face.Builder) -> void: _build_wings(b, s * 0.5 * 0.5))

static func _build_bee(b: Face.Builder, r: float) -> void:
	var body := Color("f6c53d")
	var ink := Color("3b3028")
	b.ellipse(Vector2(r * 0.05, r * 0.12), r * 0.95, r * 0.72, Color(ink, 0.9))
	b.ellipse(Vector2.ZERO, r * 0.9, r * 0.68, body)
	# stripes, clipped to the body by keeping them short
	for x in [-0.12, 0.3]:
		var h := r * 0.66 * sqrt(maxf(0.0, 1.0 - pow(x / 0.9, 2.0)))
		b.stroke(PackedVector2Array([Vector2(r * x, -h), Vector2(r * x, h)]), r * 0.2, ink)
	# the sting and the head
	b.polygon(PackedVector2Array([Vector2(r * 0.84, -r * 0.1), Vector2(r * 1.18, 0), Vector2(r * 0.84, r * 0.1)]), ink)
	b.disc(Vector2(-r * 0.78, -r * 0.05), r * 0.46, ink)
	b.disc(Vector2(-r * 0.9, -r * 0.14), r * 0.14, Color("fffaf0"))
	b.disc(Vector2(-r * 0.93, -r * 0.14), r * 0.07, ink)
	b.ellipse(Vector2(-r * 0.2, -r * 0.4), r * 0.3, r * 0.12, Color(1, 1, 1, 0.45))
	# feelers
	for side in [-1.0, 1.0]:
		var base := Vector2(-r * 0.95, -r * 0.35)
		var tip := base + Vector2(-r * 0.3 + side * r * 0.12, -r * 0.45)
		b.stroke(PackedVector2Array([base, tip]), maxf(1.0, r * 0.07), ink)
		b.disc(tip, r * 0.09, ink)

static func _build_wings(b: Face.Builder, r: float) -> void:
	for side in [-1.0, 1.0]:
		var c := Vector2(side * r * 0.25 + r * 0.05, -r * 0.72)
		b.ellipse(c, r * 0.36, r * 0.52, Color(1, 1, 1, 0.8))
		b.stroke(Face.Builder.ring(c, r * 0.36, r * 0.52), maxf(1.0, r * 0.06), Color("9fc6e8"), true)

## Weeds under a tile: tufts poking out round its edges, over a patch of
## turned soil; two layers are thicker and darker.
static func weeds(s: float, layers: int) -> ArrayMesh:
	return _cached("w%d_%d" % [roundi(s), layers], func(b: Face.Builder) -> void: _build_weeds(b, s, layers))

static func _build_weeds(b: Face.Builder, s: float, layers: int) -> void:
	var r := s * 0.5
	var soil := SOIL.lightened(0.25) if layers < 2 else SOIL
	b.polygon(Face.Builder.round_rect(Vector2(-r, -r), Vector2(s, s), r * 0.36), Color(soil, 0.5 if layers < 2 else 0.7))
	var rng := RandomNumberGenerator.new()
	rng.seed = 11 + layers
	var green := WEED if layers < 2 else WEED.darkened(0.2)
	var n := 12 if layers < 2 else 20
	for i in n:
		var a := TAU * i / n + rng.randf_range(-0.2, 0.2)
		var at := Vector2(cos(a), sin(a)) * r * rng.randf_range(0.8, 0.98)
		var up := Vector2(rng.randf_range(-0.25, 0.25), -1.0).normalized()
		var tall := r * rng.randf_range(0.28, 0.42) * (1.2 if layers >= 2 else 1.0)
		for k in 3:
			var lean := up.rotated((k - 1) * 0.45)
			b.polygon(PackedVector2Array([at + lean.orthogonal() * r * 0.05, at + lean * tall, at - lean.orthogonal() * r * 0.05]),
				green.darkened(0.08 * k))

static func _weed_icon(b: Face.Builder, r: float) -> void:
	b.ellipse(Vector2(0, r * 0.55), r * 0.8, r * 0.26, SOIL)
	for i in 7:
		var x := lerpf(-0.6, 0.6, i / 6.0) * r
		var tip := Vector2(x * 1.3, -r * (0.55 + 0.3 * sin(i * 1.7) * 0.5))
		b.polygon(PackedVector2Array([Vector2(x - r * 0.1, r * 0.55), tip, Vector2(x + r * 0.1, r * 0.55)]), WEED.darkened(0.1 * (i % 2)))

## A stone standing in a cell: `hp` 2 whole, 1 cracked.
static func stone(s: float, hp: int) -> ArrayMesh:
	return _cached("st%d_%d" % [roundi(s), hp], func(b: Face.Builder) -> void: _stone(b, s * 0.5, hp))

static func _stone_outline(r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 14:
		var a := TAU * i / 14.0
		var wob := 1.0 + 0.07 * sin(a * 3.0 + 1.0) + 0.04 * cos(a * 5.0)
		pts.append(Vector2(cos(a) * r * 0.86, sin(a) * r * 0.74 + r * 0.06) * wob)
	return pts

static func _stone(b: Face.Builder, r: float, hp: int) -> void:
	b.ellipse(Vector2(r * 0.05, r * 0.68), r * 0.72, r * 0.16, Color(0.3, 0.22, 0.12, 0.2))
	var under := _stone_outline(r)
	for i in under.size():
		under[i] += Vector2(r * 0.03, r * 0.08)
	b.polygon(under, STONE.darkened(0.35))
	b.polygon(_stone_outline(r), STONE)
	b.ellipse(Vector2(-r * 0.2, -r * 0.24), r * 0.42, r * 0.24, STONE.lightened(0.18))
	b.ellipse(Vector2(-r * 0.32, -r * 0.34), r * 0.14, r * 0.08, Color(1, 1, 1, 0.45))
	b.disc(Vector2(r * 0.4, r * 0.2), r * 0.08, STONE.darkened(0.2))
	b.disc(Vector2(-r * 0.1, r * 0.34), r * 0.06, STONE.darkened(0.2))
	if hp <= 1:
		var ink := STONE.darkened(0.5)
		b.stroke(PackedVector2Array([Vector2(-r * 0.1, -r * 0.62), Vector2(r * 0.05, -r * 0.2), Vector2(-r * 0.12, r * 0.1), Vector2(r * 0.1, r * 0.5)]), maxf(1.5, r * 0.07), ink)
		b.stroke(PackedVector2Array([Vector2(r * 0.05, -r * 0.2), Vector2(r * 0.42, -r * 0.3)]), maxf(1.0, r * 0.05), ink)
	else:
		# a whole stone wears a little tuft of grass at its foot
		for i in 3:
			var at := Vector2(r * (0.35 + 0.12 * i), r * 0.62)
			b.polygon(PackedVector2Array([at + Vector2(-r * 0.05, 0), at + Vector2(r * 0.02 * (i - 1), -r * 0.24), at + Vector2(r * 0.05, 0)]), LEAF_DEEP)

## Moss filling a cell: a soft green cushion with paler knots.
static func moss(s: float) -> ArrayMesh:
	return _cached("m%d" % roundi(s), func(b: Face.Builder) -> void: _moss(b, s * 0.5))

static func _moss(b: Face.Builder, r: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	b.polygon(Face.Builder.round_rect(Vector2(-r * 0.92, -r * 0.8), Vector2(r * 1.84, r * 1.72), r * 0.6), MOSS.darkened(0.3))
	for i in 9:
		var at := Vector2(rng.randf_range(-0.55, 0.55), rng.randf_range(-0.45, 0.5)) * r
		b.disc(at, r * rng.randf_range(0.3, 0.44), MOSS.darkened(0.08 * (i % 3)))
	for i in 14:
		var at := Vector2(rng.randf_range(-0.7, 0.7), rng.randf_range(-0.6, 0.6)) * r
		b.disc(at, r * 0.07, MOSS.lightened(0.3))
	b.ellipse(Vector2(-r * 0.3, -r * 0.4), r * 0.3, r * 0.12, Color(1, 1, 1, 0.22))
