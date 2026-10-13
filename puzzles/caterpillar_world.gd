extends Control

## Caterpillar's world: the kitchen garden the bed stands in, edge to edge
## under the board and the host's rows (CLAUDE.md: a game's world fills the
## screen). It is the menu card's mint lawn (ui/menu/cards/caterpillar.gd)
## at the size of the screen: pale and sunlit across the top, where the
## wordmark and the win's words are ink; mown in faint bands under the bed;
## and at the foot, where nothing lies over it while the board is played, a
## low fence, a row of cabbages in their soil (one of them nibbled), a
## flower pot, a watering can, tufts, clovers and daisies, with a bush in
## each corner. Three stepping tiles, a nibbled leaf and a clover lie in the
## gap of the tools row. Nothing here has a face: only the caterpillar does.
##
## One mesh, built when the rect changes and kept (`_shown`) until the next
## replaces it; the dew's glints are a second, on a child whose alpha
## breathes (still under Motion.reduce). The colours are written here: the
## board preloads this file, so reading them from the board would be a cycle.

const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Face = preload("res://ui/faces/face.gd")
const CardFace = preload("res://ui/menu/cards/card_face.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

## The screen the picture was drawn on; everything scales with the width.
const W := 1080.0
const LAWN_TOP := Color("f6f9ea")
const LAWN_MID := Color("e4f3df")
const LAWN_LOW := Color("c6e4c2")
const STRIPE := Color("bfe0bb")
const GRASS_DEEP := Color("9fcf9a")
const TILE := Color("d9efc9")
const TILE_LIP := Color("b4d7a4")
const LEAF := Color("86c46f")
const LEAF_DARK := Color("5fa458")
const LEAF_LIT := Color("b9e19c")
const WOOD := Color("d2a473")
const WOOD_DARK := Color("b08253")
const WOOD_LIT := Color("e8c697")
const SOIL := Color("c9a47a")
const SOIL_DARK := Color("b48c61")
const POT := Color("dd8f68")
const POT_RIM := Color("eaa884")
const POT_SHADE := Color("c27752")
const CAN := Color("9fcfd2")
const CAN_SHADE := Color("7fb5ba")
const CAN_LIT := Color("c8e6e6")
const PETAL := Color("fffdf6")
## Where the lawn stops being the top's pale wash and where the mown bands
## begin, as shares of the height.
const MID_AT := 0.26
const BANDS_FROM := 0.27
const BAND := 96.0
## The sun's middle as shares of the rect and its rings: [radius at W, alpha].
const SUN_AT := Vector2(0.93, 0.025)
const SUN_RINGS := [[640.0, 0.09], [440.0, 0.10], [270.0, 0.14]]
## The gap of the tools row: stepping tiles [x, y as shares, side at W,
## turn], the nibbled leaf and the clover [x, y, size at W].
const GAP_TILES := [[0.345, 0.238, 46.0, -0.10], [0.410, 0.230, 46.0, 0.07], [0.476, 0.239, 46.0, -0.04]]
const GAP_LEAF := [0.585, 0.234, 44.0]
const GAP_CLOVER := [0.690, 0.238, 13.0]
## The foot. The fence's rail as a share of the height and how far across it
## runs; the soil bed's middle line, its ends and half height at W.
const FENCE_Y := 0.868
const FENCE_TO := 0.70
const FENCE_POSTS := 8
const SOIL_Y := 0.925
const SOIL_FROM := 0.035
const SOIL_TO := 0.665
const SOIL_H := 46.0
## The cabbages on the soil: [x as a share, radius at W, nibbled].
const CABBAGES := [[0.105, 50.0, false], [0.225, 54.0, false], [0.350, 50.0, true],
	[0.472, 55.0, false], [0.595, 50.0, false]]
## The flower pot and the watering can: the foot's middle as shares, the
## width at W.
const POT_AT := Vector2(0.775, 0.948)
const POT_W := 96.0
const CAN_AT := Vector2(0.905, 0.952)
const CAN_W := 132.0
## Daisies [x, y, radius at W], tufts [x, y, height at W] and clovers
## [x, y, radius at W] on the grass.
const DAISIES := [
	[0.030, 0.985, 14.0], [0.300, 0.978, 13.0], [0.540, 0.988, 14.0], [0.700, 0.900, 12.0],
	[0.965, 0.880, 13.0], [0.842, 0.985, 12.0], [0.752, 0.862, 11.0],
]
const TUFTS := [
	[0.170, 0.984, 24.0], [0.430, 0.982, 22.0], [0.660, 0.980, 24.0], [0.985, 0.958, 26.0],
	[0.842, 0.894, 22.0], [0.012, 0.905, 22.0], [0.725, 0.972, 20.0],
]
const CLOVERS := [[0.090, 0.972, 11.0], [0.610, 0.975, 10.0], [0.930, 0.872, 11.0], [0.800, 0.858, 9.0]]
## The dew that glints: [x, y, radius at W].
const GLINTS := [
	[0.225, 0.900, 12.0], [0.472, 0.898, 13.0], [0.905, 0.905, 11.0],
	[0.700, 0.866, 9.0], [0.410, 0.222, 9.0], [0.060, 0.948, 10.0],
]
const BREATH := 3.2
const BREATH_LOW := 0.3

var _shown: ArrayMesh
var _dew: Control
var _dew_shown: ArrayMesh
var _breath: Tween

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dew = Control.new()
	_dew.name = "Dew"
	_dew.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dew.draw.connect(func() -> void:
		if _dew_shown != null:
			_dew.draw_mesh(_dew_shown, null))
	add_child(_dew)
	resized.connect(_build)
	_build()
	_breath = Motion.pulse(_dew, "modulate:a", 1.0, BREATH_LOW, BREATH)

func _draw() -> void:
	if _shown != null:
		draw_mesh(_shown, null)

func _build() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var u := size.x / W
	var b := Face.Builder.new()
	# The lawn under everything: the top's pale wash, then the mint.
	var first := b.verts.size()
	b.polygon(_band(-8.0, size.y * MID_AT), Color.WHITE)
	CardFace.shade(b, first, LAWN_TOP, LAWN_MID, 0.0, size.y * MID_AT)
	first = b.verts.size()
	b.polygon(_band(size.y * MID_AT, size.y + 8.0), Color.WHITE)
	CardFace.shade(b, first, LAWN_MID, LAWN_LOW, size.y * MID_AT, size.y)
	# The low sun behind the corner.
	var sun := SUN_AT * size
	for ring in SUN_RINGS:
		b.disc(sun, ring[0] * u, Color(Pal.SUN_RAY, ring[1]))
	# Mown bands, a shade apart, from under the tools row down.
	var y := size.y * BANDS_FROM
	var k := 0
	while y < size.y:
		if k % 2 == 1:
			b.polygon(_band(y, minf(y + BAND * u, size.y + 8.0)), Color(STRIPE, 0.22))
		y += BAND * u
		k += 1
	_gap(b, u)
	_foot(b, u)
	_shown = b.mesh()
	queue_redraw()
	var gb := Face.Builder.new()
	for g in GLINTS:
		_sparkle(gb, Vector2(g[0], g[1]) * size, g[2] * u, Color(PETAL, 0.95))
	_dew_shown = gb.mesh()
	_dew.size = size
	_dew.queue_redraw()

## A strip of the whole width from `y0` to `y1`, past both sides.
func _band(y0: float, y1: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(-8.0, y0), Vector2(size.x + 8.0, y0),
		Vector2(size.x + 8.0, y1), Vector2(-8.0, y1)])

## The gap of the tools row: three of the bed's tiles as stepping stones, a
## leaf with a bite out of it and a clover. Small: on the win they lie over
## the words.
func _gap(b: Face.Builder, u: float) -> void:
	for t in GAP_TILES:
		_tile(b, Vector2(t[0], t[1]) * size, t[2] * u, t[3])
	_leaf(b, Vector2(GAP_LEAF[0], GAP_LEAF[1]) * size, GAP_LEAF[2] * u, -0.5, true)
	_clover(b, Vector2(GAP_CLOVER[0], GAP_CLOVER[1]) * size, GAP_CLOVER[2] * u)

## The foot: the far grass, the fence, the soil and its cabbages, the pot
## and the can, then what grows loose on the lawn and a bush in each corner.
func _foot(b: Face.Builder, u: float) -> void:
	var fy := size.y * FENCE_Y
	# A deeper grass rising to the fence's line.
	b.ellipse(Vector2(size.x * 0.34, size.y + 40.0 * u), size.x * 0.80, size.y - fy + 70.0 * u, Color(GRASS_DEEP, 0.30))
	b.ellipse(Vector2(size.x * 0.88, size.y + 60.0 * u), size.x * 0.46, size.y - fy + 40.0 * u, Color(GRASS_DEEP, 0.26))
	# The fence: two rails and their posts, each post's shadow on the grass.
	var to := size.x * FENCE_TO
	var post_h := 74.0 * u
	var post_w := 22.0 * u
	for rail in [-0.30, 0.22]:
		var ry: float = fy + post_h * rail
		b.polygon(Face.Builder.round_rect(Vector2(-8.0, ry - 7.0 * u), Vector2(to + 8.0, 14.0 * u), 5.0 * u), WOOD_DARK)
		b.polygon(Face.Builder.round_rect(Vector2(-8.0, ry - 7.0 * u), Vector2(to + 8.0, 9.0 * u), 4.0 * u), WOOD)
	for i in FENCE_POSTS:
		var px := lerpf(26.0 * u, to - 14.0 * u, float(i) / float(FENCE_POSTS - 1))
		Scenery.soft_disc(b, Vector2(px, fy + post_h * 0.52), post_w * 0.9, 6.0 * u, Color(LEAF_DARK, 0.18))
		var top := Vector2(px - post_w * 0.5, fy - post_h * 0.5)
		b.polygon(Face.Builder.round_rect(top, Vector2(post_w, post_h), post_w * 0.42), WOOD_DARK)
		b.polygon(Face.Builder.round_rect(top, Vector2(post_w * 0.72, post_h - 3.0 * u), post_w * 0.36), WOOD)
		b.polygon(Face.Builder.round_rect(top + Vector2(post_w * 0.16, post_w * 0.3),
			Vector2(post_w * 0.22, post_h * 0.5), post_w * 0.11), Color(WOOD_LIT, 0.8))
	# The soil, a little raised, with furrows.
	var sy := size.y * SOIL_Y
	var s0 := size.x * SOIL_FROM
	var s1 := size.x * SOIL_TO
	var sh := SOIL_H * u
	b.polygon(Face.Builder.round_rect(Vector2(s0, sy - sh + 8.0 * u), Vector2(s1 - s0, sh * 2.0), sh), SOIL_DARK)
	b.polygon(Face.Builder.round_rect(Vector2(s0, sy - sh), Vector2(s1 - s0, sh * 2.0 - 4.0 * u), sh), SOIL)
	for f in 6:
		var fx := lerpf(s0 + sh, s1 - sh * 1.6, float(f) / 5.0) + 34.0 * u
		b.stroke(PackedVector2Array([Vector2(fx, sy + sh * 0.50), Vector2(fx + 46.0 * u, sy + sh * 0.56)]),
			3.0 * u, Color(SOIL_DARK, 0.7))
	for c in CABBAGES:
		_cabbage(b, Vector2(size.x * c[0], sy - 10.0 * u), c[1] * u, c[2])
	_pot(b, POT_AT * size, POT_W * u)
	_can(b, CAN_AT * size, CAN_W * u)
	for c in CLOVERS:
		_clover(b, Vector2(c[0], c[1]) * size, c[2] * u)
	for t in TUFTS:
		Scenery.tuft(b, Vector2(t[0], t[1]) * size, t[2] * u)
	for d in DAISIES:
		_daisy(b, Vector2(d[0], d[1]) * size, d[2] * u)
	_bush(b, Vector2(-10.0 * u, size.y + 14.0 * u), 92.0 * u)
	_bush(b, Vector2(size.x + 6.0 * u, size.y + 18.0 * u), 104.0 * u)

## One of the bed's tiles laid loose on the lawn: a lip, a face, a glint.
func _tile(b: Face.Builder, at: Vector2, side: float, turn: float) -> void:
	var xf := Transform2D(turn, at)
	var half := Vector2(side, side) * 0.5
	b.polygon(xf * Face.Builder.round_rect(-half + Vector2(0.0, side * 0.09), half * 2.0, side * 0.2), TILE_LIP)
	b.polygon(xf * Face.Builder.round_rect(-half, half * 2.0, side * 0.2), TILE)
	b.polygon(xf * Face.Builder.round_rect(-half + Vector2(side * 0.14, side * 0.12),
		Vector2(side * 0.34, side * 0.10), side * 0.05), Color(PETAL, 0.55))

## A leaf of length `lng` about `at`, leaning `turn`, its midrib drawn; with
## `bitten` a round bite is out of its upper edge.
func _leaf(b: Face.Builder, at: Vector2, lng: float, turn: float, bitten := false) -> void:
	var a := Vector2(-lng * 0.5, 0.0)
	var z := Vector2(lng * 0.5, 0.0)
	var wide := lng * 0.30
	var pts := Face.Builder.bezier2(a, Vector2(0.0, -wide * 1.5), z, 12)
	var back := Face.Builder.bezier2(z, Vector2(0.0, wide * 1.5), a, 12)
	pts.append_array(back)
	var parts: Array = [pts]
	if bitten:
		parts = Geometry2D.clip_polygons(pts, Face.Builder.ring(Vector2(lng * 0.12, -wide * 0.72), lng * 0.15, lng * 0.15))
	var xf := Transform2D(turn, at)
	for part in parts:
		b.polygon(xf * (part as PackedVector2Array), LEAF)
	b.stroke(xf * PackedVector2Array([a * 0.78, z * 0.70]), maxf(1.5, lng * 0.045), LEAF_DARK)

## A clover: three round leaves and a short stem.
func _clover(b: Face.Builder, at: Vector2, r: float) -> void:
	b.stroke(PackedVector2Array([at, at + Vector2(r * 0.3, r * 1.5)]), maxf(1.5, r * 0.22), LEAF_DARK)
	for i in 3:
		b.disc(at + Vector2.from_angle(-PI * 0.5 + i * TAU / 3.0) * r * 0.62, r * 0.62, LEAF)
	b.disc(at, r * 0.2, LEAF_DARK)

## A daisy: eight petals round a yellow heart.
func _daisy(b: Face.Builder, at: Vector2, r: float) -> void:
	for i in 8:
		var d := Vector2.from_angle(i * TAU / 8.0)
		b.ellipse(at + d * r * 0.62, r * 0.42, r * 0.42, PETAL)
	b.disc(at, r * 0.40, Pal.SUN)

## A cabbage seen from the path: a round of outer leaves, an inner round and
## a pale heart, in its own shadow. A nibbled one has two bites out of its
## rim.
func _cabbage(b: Face.Builder, at: Vector2, r: float, nibbled: bool) -> void:
	Scenery.soft_disc(b, at + Vector2(0.0, r * 0.62), r * 1.05, r * 0.30, Color(SOIL_DARK, 0.55))
	var rim: Array = []
	for i in 6:
		var d := Vector2.from_angle(-PI * 0.5 + (i + 0.5) * TAU / 6.0)
		rim.append(Face.Builder.ring(at + d * r * 0.46, r * 0.62, r * 0.56))
	for petal in rim:
		var parts: Array = [petal]
		if nibbled:
			var out: Array = []
			for part in parts:
				for cut in Geometry2D.clip_polygons(part, Face.Builder.ring(at + Vector2(r * 0.82, -r * 0.52), r * 0.30, r * 0.30)):
					out.append_array(Geometry2D.clip_polygons(cut, Face.Builder.ring(at + Vector2(r * 1.04, -r * 0.06), r * 0.22, r * 0.22)))
			parts = out
		for part in parts:
			b.polygon(part as PackedVector2Array, LEAF_DARK)
	for i in 5:
		var d := Vector2.from_angle(-PI * 0.5 + i * TAU / 5.0)
		b.ellipse(at + d * r * 0.30, r * 0.48, r * 0.44, LEAF)
	for i in 5:
		var d := Vector2.from_angle(-PI * 0.5 + i * TAU / 5.0)
		b.stroke(PackedVector2Array([at + d * r * 0.16, at + d * r * 0.64]), maxf(1.5, r * 0.035), Color(LEAF_DARK, 0.55))
	b.disc(at, r * 0.36, LEAF_LIT)
	b.disc(at + Vector2(-r * 0.07, -r * 0.08), r * 0.17, Color(PETAL, 0.55))

## A terracotta pot with a sprig of three leaves, its foot's middle at `at`.
func _pot(b: Face.Builder, at: Vector2, w: float) -> void:
	var h := w * 0.86
	Scenery.soft_disc(b, at + Vector2(0.0, 2.0), w * 0.62, w * 0.12, Color(LEAF_DARK, 0.22))
	var top := at + Vector2(0.0, -h)
	b.stroke(PackedVector2Array([top, top + Vector2(0.0, -w * 0.5)]), maxf(2.0, w * 0.05), LEAF_DARK)
	_leaf(b, top + Vector2(-w * 0.26, -w * 0.42), w * 0.56, 0.5)
	_leaf(b, top + Vector2(w * 0.28, -w * 0.52), w * 0.60, -0.55)
	_leaf(b, top + Vector2(w * 0.02, -w * 0.82), w * 0.50, -1.45)
	b.polygon(PackedVector2Array([top + Vector2(-w * 0.44, 0.0), top + Vector2(w * 0.44, 0.0),
		at + Vector2(w * 0.30, 0.0), at + Vector2(-w * 0.30, 0.0)]), POT)
	b.polygon(PackedVector2Array([top + Vector2(w * 0.16, 0.0), top + Vector2(w * 0.44, 0.0),
		at + Vector2(w * 0.30, 0.0), at + Vector2(w * 0.12, 0.0)]), POT_SHADE)
	b.polygon(Face.Builder.round_rect(top + Vector2(-w * 0.5, -w * 0.08), Vector2(w, w * 0.22), w * 0.08), POT_RIM)

## A watering can on its side of the path: the body, its spout to the left
## with a rose on it, and the handle's hoop.
func _can(b: Face.Builder, at: Vector2, w: float) -> void:
	var h := w * 0.62
	Scenery.soft_disc(b, at + Vector2(0.0, 2.0), w * 0.56, w * 0.10, Color(LEAF_DARK, 0.22))
	var body := Vector2(w * 0.56, h)
	var corner := at + Vector2(-body.x * 0.5 + w * 0.08, -h)
	# The hoop behind the body.
	b.stroke(Face.Builder.arc_points(corner + Vector2(body.x * 0.5, 0.0), body.x * 0.40, PI, TAU),
		w * 0.06, CAN_SHADE, false, true)
	# The spout and its rose.
	var from := corner + Vector2(2.0, h * 0.62)
	var tip := corner + Vector2(-w * 0.36, h * 0.08)
	b.stroke(PackedVector2Array([from, tip]), w * 0.08, CAN_SHADE)
	b.polygon(Transform2D((tip - from).angle(), tip) * Face.Builder.round_rect(
		Vector2(-w * 0.03, -w * 0.09), Vector2(w * 0.07, w * 0.18), w * 0.03), CAN)
	b.polygon(Face.Builder.round_rect(corner, body, w * 0.08), CAN_SHADE)
	b.polygon(Face.Builder.round_rect(corner, Vector2(body.x * 0.78, h), w * 0.08), CAN)
	b.polygon(Face.Builder.round_rect(corner + Vector2(body.x * 0.12, h * 0.14),
		Vector2(body.x * 0.12, h * 0.52), body.x * 0.06), Color(CAN_LIT, 0.8))
	b.polygon(Face.Builder.round_rect(corner + Vector2(-w * 0.02, -w * 0.03), Vector2(body.x + w * 0.04, w * 0.08), w * 0.03), CAN_LIT)

## A round bush of `r` about `at`, lit from the left.
func _bush(b: Face.Builder, at: Vector2, r: float) -> void:
	for p in [[-0.55, -0.20, 0.62], [0.50, -0.26, 0.66], [0.0, -0.62, 0.74]]:
		b.disc(at + Vector2(p[0], p[1]) * r, r * p[2], LEAF_DARK)
	for p in [[-0.62, -0.34, 0.40], [0.38, -0.44, 0.42], [-0.08, -0.84, 0.46]]:
		b.disc(at + Vector2(p[0], p[1]) * r, r * p[2], LEAF)

## A four-pointed glint of `r`, its waist pinched (the menu cards').
func _sparkle(b: Face.Builder, at: Vector2, r: float, ink: Color) -> void:
	var pts := PackedVector2Array()
	for i in 8:
		pts.append(at + Vector2.from_angle(-PI * 0.5 + i * PI * 0.25) * (r if i % 2 == 0 else r * 0.30))
	b.polygon(pts, ink)
