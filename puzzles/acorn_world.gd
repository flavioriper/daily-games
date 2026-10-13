extends Control

## Golden Acorn's world: up in the oak in high summer, edge to edge under the
## board and the host's rows (CLAUDE.md: a game's world fills the screen).
## It is the menu card's golden parchment (ui/menu/cards/acorn.gd) taken up
## into the tree: warm air, lightest at the top where the wordmark, the
## motto and the win's "Well done!" are ink; a twig with the prize hanging
## from it in the gap of the tools row; sprays of oak leaves coming in from
## both sides, mostly behind the question while it is played and whole once
## the win has shrunk it; and at the foot the bough the climb stands on,
## with the squirrel's hollow and its hoard at the left. The right of the
## foot is left to the bough alone: Lock stands there.
##
## Nothing in it has a face, and the only gold acorn is the one on the twig:
## the hoard is brown, so it does not read as the score.
##
## One mesh, built when the rect changes and kept (`_shown`) until the next
## replaces it; the glints round the prize and the motes over the bough are
## a second, on a child whose alpha breathes (still under Motion.reduce).
## The colours are written here: the board preloads this file.

const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Face = preload("res://ui/faces/face.gd")
const CardFace = preload("res://ui/menu/cards/card_face.gd")
const Scenery = preload("res://ui/flat/scenery.gd")
const LeafPile = preload("res://ui/faces/leaf_pile.gd")
const Art = preload("res://ui/faces/acorn_art.gd")

## The screen the picture was drawn on; everything scales with the width,
## and the foot's things are measured up from the bottom edge.
const W := 1080.0
const AIR_TOP := Color("fef8e6")
const AIR_MID := Color("f8efc9")
const AIR_LOW := Color("eee6b2")
const GLOW := Color("fff6cf")
const LEAF_LIGHT := Color("a9cb7c")
const LEAF_MID := Color("8dba68")
const LEAF_DEEP := Color("6f9f55")
const SHADE := Color("9cc07a")
const BARK := Color("a57a48")
const BARK_LIT := Color("c39a68")
const BARK_DEEP := Color("86602f")
const HOLLOW := Color("5c3f20")
## The sun's soft rings behind the wordmark: its middle as shares of the
## rect, then [radius at W, alpha].
const SUN_AT := Vector2(0.10, 0.02)
const SUN_RINGS := [[620.0, 0.30], [420.0, 0.30], [250.0, 0.36]]
## The twig in the gap of the tools row, as shares: from, two handles, to;
## its leaves as [share along it, length at W, angle, tint 0..2]; and the
## prize hanging from it: [share along, drop at W, radius at W].
const TWIG := [Vector2(0.395, 0.2255), Vector2(0.46, 0.215), Vector2(0.56, 0.236), Vector2(0.665, 0.2275)]
const TWIG_LEAVES := [[0.10, 50.0, -2.5, 1], [0.34, 58.0, -0.9, 0], [0.80, 54.0, -2.2, 0], [1.0, 60.0, -0.25, 1]]
const PRIZE := [0.58, 22.0, 15.0]
## The sprays coming in from the sides: [side (-1 left, 1 right), y as a
## share, reach at W, rise at W, leaves].
const SPRAYS := [
	[-1.0, 0.405, 150.0, -46.0, 5],
	[1.0, 0.470, 170.0, -30.0, 6],
	[-1.0, 0.640, 176.0, 34.0, 6],
	[1.0, 0.735, 146.0, 40.0, 5],
]
## Leaf shade on the air, behind everything: [x, y as shares, rx, ry at W].
const SHADES := [
	[0.0, 0.42, 250.0, 170.0], [1.0, 0.50, 270.0, 190.0],
	[0.0, 0.66, 280.0, 200.0], [1.0, 0.76, 240.0, 170.0], [0.30, 1.0, 420.0, 170.0],
]
## The bough: its top edge from the left side to where it leaves the foot,
## as [x share, pixels up from the bottom at W]: from, two handles, to.
const BOUGH := [Vector2(-0.02, 152.0), Vector2(0.24, 128.0), Vector2(0.50, 84.0), Vector2(1.02, 30.0)]
## The hollow: [x share, up from the bottom, rx, ry at W], and the hoard in
## it and beside it: [x share, up from the bottom, radius, angle].
const HOLE := [0.135, 62.0, 66.0, 40.0]
const HOARD := [
	[0.108, 50.0, 17.0, -0.35], [0.150, 46.0, 18.0, 0.25], [0.130, 70.0, 15.0, 0.05],
	[0.262, 126.0, 17.0, 0.5], [0.305, 121.0, 14.0, -1.2],
]
## The shoot standing off the bough, left of Lock: its foot's x share and
## height at W, and its leaves as [share up it, length, angle, tint].
const SHOOT := [0.455, 64.0]
const SHOOT_LEAVES := [[0.45, 40.0, -2.75, 0], [0.75, 44.0, -0.4, 1], [1.0, 46.0, -1.3, 0]]
## The glints: [x, y as shares (y < 0: pixels up from the bottom at W over
## the height), radius at W], and how they breathe.
const GLINTS := [[0.612, 0.2395, 9.0], [0.560, 0.2520, 6.0], [0.640, 0.2180, 5.0]]
const MOTES := [[0.070, 196.0, 5.0], [0.215, 182.0, 4.0], [0.375, 176.0, 4.5], [0.540, 150.0, 3.5]]
const BREATH := 3.6
const BREATH_LOW := 0.35

var _shown: ArrayMesh
var _glints: Control
var _glints_shown: ArrayMesh
var _breath: Tween

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glints = Control.new()
	_glints.name = "Glints"
	_glints.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glints.draw.connect(func() -> void:
		if _glints_shown != null:
			_glints.draw_mesh(_glints_shown, null))
	add_child(_glints)
	resized.connect(_build)
	_build()
	_breath = Motion.pulse(_glints, "modulate:a", 1.0, BREATH_LOW, BREATH)

func _draw() -> void:
	if _shown != null:
		draw_mesh(_shown, null)

func _tint(i: int) -> Color:
	return [LEAF_LIGHT, LEAF_MID, LEAF_DEEP][clampi(i, 0, 2)]

func _build() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var u := size.x / W
	var b := Face.Builder.new()
	# The air, lightest at the top.
	var first := b.verts.size()
	b.polygon(PackedVector2Array([Vector2(-8.0, -8.0), Vector2(size.x + 8.0, -8.0),
		Vector2(size.x + 8.0, size.y * 0.5), Vector2(-8.0, size.y * 0.5)]), Color.WHITE)
	CardFace.shade(b, first, AIR_TOP, AIR_MID, 0.0, size.y * 0.5)
	first = b.verts.size()
	b.polygon(PackedVector2Array([Vector2(-8.0, size.y * 0.5), Vector2(size.x + 8.0, size.y * 0.5),
		Vector2(size.x + 8.0, size.y + 8.0), Vector2(-8.0, size.y + 8.0)]), Color.WHITE)
	CardFace.shade(b, first, AIR_MID, AIR_LOW, size.y * 0.5, size.y)
	var sun := SUN_AT * size
	for ring: Array in SUN_RINGS:
		b.disc(sun, float(ring[0]) * u, Color(GLOW, float(ring[1])))
	# The crown's shade, soft, at the sides and over the bough.
	for s: Array in SHADES:
		Scenery.soft_disc(b, Vector2(float(s[0]) * size.x, float(s[1]) * size.y), float(s[2]) * u, float(s[3]) * u,
			Color(SHADE, 0.16))
	for s: Array in SPRAYS:
		_spray(b, float(s[0]), float(s[1]) * size.y, float(s[2]) * u, float(s[3]) * u, int(s[4]), u)
	_twig(b, u)
	_bough(b, u)
	_shown = b.mesh()
	queue_redraw()
	var gb := Face.Builder.new()
	for g: Array in GLINTS:
		_sparkle(gb, Vector2(float(g[0]), float(g[1])) * size, float(g[2]) * u, Color(Pal.SURFACE, 0.95))
	for m: Array in MOTES:
		gb.disc(Vector2(float(m[0]) * size.x, size.y - float(m[1]) * u), float(m[2]) * u, Color(GLOW, 0.9))
	_glints_shown = gb.mesh()
	_glints.size = size
	_glints.queue_redraw()

## The twig in the gap of the tools row, with its leaves and the prize.
func _twig(b: Face.Builder, u: float) -> void:
	var pts := Face.Builder.bezier3(TWIG[0] * size, TWIG[1] * size, TWIG[2] * size, TWIG[3] * size, 16)
	pts.append(TWIG[3] * size)
	b.stroke(pts, 7.0 * u, BARK)
	for l: Array in TWIG_LEAVES:
		var at := _along(pts, float(l[0]))
		var angle := float(l[2])
		var length := float(l[1]) * u
		LeafPile.leaf(b, at + Vector2.from_angle(angle) * length * 0.46, length, angle, _tint(int(l[3])),
			LeafPile.Kind.OAK)
	var from := _along(pts, float(PRIZE[0]))
	var r := float(PRIZE[2]) * u
	var nut := from + Vector2(0.0, float(PRIZE[1]) * u + r)
	b.stroke(PackedVector2Array([from, nut - Vector2(0.0, r)]), 3.0 * u, BARK)
	Scenery.soft_disc(b, nut, r * 2.6, r * 2.6, Color(GLOW, 0.75))
	Art.acorn(b, nut, r, true)

## A spray of oak leaves on a twig coming in from one side.
func _spray(b: Face.Builder, side: float, y: float, reach: float, rise: float, n: int, u: float) -> void:
	var edge := -12.0 * u if side < 0.0 else size.x + 12.0 * u
	var from := Vector2(edge, y)
	var to := Vector2(edge - side * reach, y + rise)
	var pts := Face.Builder.bezier3(from, from + Vector2(-side * reach * 0.4, -rise * 0.2),
		to + Vector2(side * reach * 0.3, -rise * 0.5), to, 12)
	pts.append(to)
	b.stroke(pts, 8.0 * u, BARK)
	var heading := (to - from).angle()
	for i in n:
		var t := float(i + 1) / float(n)
		var at := _along(pts, t)
		var out := 1.0 if i % 2 == 0 else -1.0
		var angle := heading + out * (0.95 - 0.5 * t) if i < n - 1 else heading
		var length := (62.0 + 12.0 * LeafPile.h01(i, n * 7 + int(y))) * u
		LeafPile.leaf(b, at + Vector2.from_angle(angle) * length * 0.46, length, angle, _tint((i + int(y)) % 3),
			LeafPile.Kind.OAK)
	# One brown acorn under the spray's middle.
	var hang := _along(pts, 0.55)
	var r := 13.0 * u
	b.stroke(PackedVector2Array([hang, hang + Vector2(0.0, 16.0 * u)]), 3.0 * u, BARK)
	Art.acorn(b, hang + Vector2(0.0, 16.0 * u + r), r)

## The bough at the foot, its hollow and hoard, and the shoot standing off it.
func _bough(b: Face.Builder, u: float) -> void:
	var p: Array[Vector2] = []
	for v: Vector2 in BOUGH:
		p.append(Vector2(v.x * size.x, size.y - v.y * u))
	var top := Face.Builder.bezier3(p[0], p[1], p[2], p[3], 28)
	top.append(p[3])
	# The shoot first, so its foot is in the wood.
	var foot := _at_x(top, float(SHOOT[0]) * size.x)
	var tip := foot + Vector2(18.0 * u, -float(SHOOT[1]) * u)
	var shoot := Face.Builder.bezier3(foot + Vector2(0.0, 10.0 * u), foot + Vector2(-10.0 * u, -24.0 * u),
		tip + Vector2(-16.0 * u, 18.0 * u), tip, 12)
	shoot.append(tip)
	b.stroke(shoot, 8.0 * u, BARK)
	for l: Array in SHOOT_LEAVES:
		var at := _along(shoot, float(l[0]))
		var angle := float(l[2])
		var length := float(l[1]) * u
		LeafPile.leaf(b, at + Vector2.from_angle(angle) * length * 0.46, length, angle, _tint(int(l[3])),
			LeafPile.Kind.OAK)
	var body := top.duplicate()
	body.append(Vector2(size.x + 20.0, size.y + 12.0))
	body.append(Vector2(-20.0, size.y + 12.0))
	var first := b.verts.size()
	b.polygon(body, Color.WHITE)
	CardFace.shade(b, first, BARK, BARK_DEEP, size.y - 150.0 * u, size.y)
	# Its lit back, and the bark's grain under it.
	b.stroke(top, 9.0 * u, BARK_LIT, false, false)
	for k in 3:
		var drop := (30.0 + 30.0 * k) * u
		var grain := PackedVector2Array()
		for i in range(2 + k * 3, top.size() - 8 - k * 4):
			var at := top[i] + Vector2(0.0, drop)
			if at.y < size.y - 6.0 * u:
				grain.append(at)
		if grain.size() >= 2:
			b.stroke(grain, 3.0 * u, Color(BARK_DEEP, 0.45), false, false)
	# The hollow, and the hoard in it.
	var hole := Vector2(float(HOLE[0]) * size.x, size.y - float(HOLE[1]) * u)
	var rx := float(HOLE[2]) * u
	var ry := float(HOLE[3]) * u
	b.ellipse(hole, rx + 7.0 * u, ry + 7.0 * u, BARK_LIT)
	b.ellipse(hole + Vector2(0.0, 3.0 * u), rx, ry, HOLLOW)
	for h: Array in HOARD:
		var at := Vector2(float(h[0]) * size.x, size.y - float(h[1]) * u)
		LeafPile.acorn(b, at, float(h[2]) * u, float(h[3]))

## The point `t` of the way along a polyline, by its points.
func _along(pts: PackedVector2Array, t: float) -> Vector2:
	var f := clampf(t, 0.0, 1.0) * float(pts.size() - 1)
	var i := mini(int(f), pts.size() - 2)
	return pts[i].lerp(pts[i + 1], f - float(i))

## The point of a left-to-right polyline over `x`.
func _at_x(pts: PackedVector2Array, x: float) -> Vector2:
	for i in pts.size() - 1:
		if pts[i + 1].x >= x:
			var span := maxf(pts[i + 1].x - pts[i].x, 0.001)
			return pts[i].lerp(pts[i + 1], clampf((x - pts[i].x) / span, 0.0, 1.0))
	return pts[pts.size() - 1]

## A four-pointed star of `r`, its waist pinched (the menu card's).
func _sparkle(b: Face.Builder, at: Vector2, r: float, ink: Color) -> void:
	var pts := PackedVector2Array()
	for i in 8:
		pts.append(at + Vector2.from_angle(-PI * 0.5 + i * PI * 0.25) * (r if i % 2 == 0 else r * 0.30))
	b.polygon(pts, ink)
