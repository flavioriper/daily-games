extends Control

## Mushroom Patch's world: an autumn wood's floor seen from above, edge to
## edge under the board and the host's rows (CLAUDE.md: a game's world fills
## the screen). It is the menu card's ground (ui/menu/cards/mushroom.gd) at
## the size of the screen: warm light over amber, soft dapples where the sun
## comes through the leaves, the litter heaped along the foot, and the
## fallen leaves, acorns and twigs a forager walks over.
##
## What lies where is decided by what lies over it. The top is the palest,
## for the wordmark and the win's "Well done!", which are ink. A few small
## leaves and an acorn lie in the gap of the tools row. Under the patch the
## floor is bare. Between the patch and the tray runs a thin drift of leaves,
## and the tray's two chips stand between a mossy log with two buttons on it
## at the left and the forager's basket at the right.
##
## Nothing here has a face: only the patch's own mushrooms do, so nothing in
## the world reads as a piece. The colours are written here, not read from
## the board (the board preloads this file).
##
## One mesh, built when the rect changes and kept (`_shown`) until the next
## replaces it; the dust motes are a second, on a child whose alpha breathes
## (still under Motion.reduce).

const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Face = preload("res://ui/faces/face.gd")
const CardFace = preload("res://ui/menu/cards/card_face.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

## The screen the picture was drawn on; sizes scale with the width, places
## are shares of the rect.
const W := 1080.0
const FLOOR_TOP := Color("fbf1dc")
const FLOOR_MID := Color("f6e0bb")
const FLOOR_LOW := Color("efc99a")
const LITTER := Color("e6b680")
const LITTER_FAR := Color("ebc08d")
const DAPPLE := Color("fff8e6")
const BARK := Color("9a6b47")
const BARK_DEEP := Color("7c5437")
const BARK_LIT := Color("b98a5f")
const HEART_WOOD := Color("e3c08f")
const MOSS := Color("9db86a")
const MOSS_DEEP := Color("7f9e55")
const STEM := Color("f7ead2")
const CAP_RED := Color("d9694a")
const CAP_TAN := Color("c98a52")
const WICKER := Color("c99558")
const WICKER_DEEP := Color("a87440")
const WICKER_LIT := Color("dfb47a")
const NUT := Color("b98148")
const NUT_CAP := Color("8a5f3c")
const TWIG := Color("a67b55")
const RUST := Color("c8683f")
const GOLD := Color("dfa23c")
const BRICK := Color("b9573a")
const AMBER := Color("d98a3d")
const OLIVE := Color("b7ab5a")
## Where the floor's middle tone stands, as a share of the height.
const MID_AT := 0.46
## The light in the wordmark's corner: its middle as shares, its rings as
## [radius at W, alpha].
const LIGHT_AT := Vector2(0.10, 0.02)
const LIGHT_RINGS := [[720.0, 0.10], [480.0, 0.12], [280.0, 0.16]]
## The dapples: [x, y as shares, rx, ry at W, alpha]. None lies under the
## patch's middle.
const DAPPLES := [
	[0.86, 0.065, 230.0, 120.0, 0.50], [0.52, 0.232, 250.0, 60.0, 0.40],
	[0.14, 0.885, 240.0, 90.0, 0.40], [0.80, 0.875, 220.0, 80.0, 0.36],
	[0.50, 0.965, 330.0, 70.0, 0.30],
]
## The leaves in the gap of the tools row, small and pale so the win's words
## read over them: [x, y as shares, length at W, angle, ink, alpha].
const GAP_LEAVES := [
	[0.345, 0.238, 34.0, -0.45, RUST, 0.55], [0.470, 0.226, 28.0, 0.80, GOLD, 0.60],
	[0.640, 0.240, 32.0, -2.60, AMBER, 0.55], [0.745, 0.228, 26.0, 2.30, OLIVE, 0.55],
]
const GAP_ACORN := Vector2(0.560, 0.236)
## The drift between the patch and the tray, and the litter round the tray:
## [x, y as shares, length at W, angle, ink].
const LEAVES := [
	[0.060, 0.884, 40.0, -0.50, RUST], [0.150, 0.893, 30.0, 0.90, GOLD],
	[0.265, 0.882, 34.0, 2.60, BRICK], [0.390, 0.892, 28.0, -1.20, AMBER],
	[0.520, 0.884, 32.0, 0.40, OLIVE], [0.640, 0.893, 30.0, -2.40, RUST],
	[0.760, 0.883, 36.0, 1.90, GOLD], [0.880, 0.892, 30.0, -0.80, BRICK],
	[0.965, 0.884, 34.0, 2.90, AMBER],
	[0.030, 0.990, 44.0, -0.30, GOLD], [0.230, 0.992, 36.0, 0.50, RUST],
	[0.420, 0.994, 40.0, -2.80, AMBER], [0.600, 0.992, 34.0, 0.20, BRICK],
	[0.790, 0.994, 38.0, 2.70, OLIVE], [0.960, 0.990, 42.0, -2.90, RUST],
]
## Acorns and pebbles in the drift: [x, y as shares, size at W].
const ACORNS := [[0.205, 0.887, 15.0], [0.705, 0.888, 14.0], [0.455, 0.990, 15.0]]
const TWIGS := [[0.320, 0.893, 70.0, 0.12], [0.830, 0.886, 60.0, -0.20], [0.700, 0.990, 80.0, 0.08]]
## The log at the tray's left and the basket at its right: their middles as
## shares of the rect.
const LOG_AT := Vector2(0.085, 0.948)
const BASKET_AT := Vector2(0.915, 0.950)
## The motes that breathe: [x, y as shares, radius at W].
const MOTES := [
	[0.300, 0.224, 7.0], [0.690, 0.244, 5.0], [0.110, 0.905, 6.0],
	[0.900, 0.900, 7.0], [0.500, 0.898, 5.0], [0.180, 0.975, 5.0], [0.820, 0.978, 6.0],
]
const BREATH := 3.6
const BREATH_LOW := 0.3

var _shown: ArrayMesh
var _motes: Control
var _motes_shown: ArrayMesh
var _breath: Tween

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_motes = Control.new()
	_motes.name = "Motes"
	_motes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_motes.draw.connect(func() -> void:
		if _motes_shown != null:
			_motes.draw_mesh(_motes_shown, null))
	add_child(_motes)
	resized.connect(_build)
	_build()
	_breath = Motion.pulse(_motes, "modulate:a", 1.0, BREATH_LOW, BREATH)

func _draw() -> void:
	if _shown != null:
		draw_mesh(_shown, null)

func _build() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var u := size.x / W
	var b := Face.Builder.new()
	# The floor, pale at the top and amber at the foot, in two bands so the
	# middle tone stands where the patch does.
	var mid := size.y * MID_AT
	var first := b.verts.size()
	b.polygon(PackedVector2Array([Vector2(-8.0, -8.0), Vector2(size.x + 8.0, -8.0),
		Vector2(size.x + 8.0, mid), Vector2(-8.0, mid)]), Color.WHITE)
	CardFace.shade(b, first, FLOOR_TOP, FLOOR_MID, 0.0, mid)
	first = b.verts.size()
	b.polygon(PackedVector2Array([Vector2(-8.0, mid), Vector2(size.x + 8.0, mid),
		Vector2(size.x + 8.0, size.y + 8.0), Vector2(-8.0, size.y + 8.0)]), Color.WHITE)
	CardFace.shade(b, first, FLOOR_MID, FLOOR_LOW, mid, size.y)
	# The light behind the wordmark, and the sun through the leaves.
	var light := LIGHT_AT * size
	for ring in LIGHT_RINGS:
		b.disc(light, ring[0] * u, Color(Pal.SUN_RAY, ring[1]))
	for d in DAPPLES:
		Scenery.soft_disc(b, Vector2(d[0], d[1]) * size, d[2] * u, d[3] * u, Color(DAPPLE, d[4]))
	# The litter heaped along the foot.
	b.ellipse(Vector2(size.x * 0.70, size.y + 14.0 * u), size.x * 0.52, 62.0 * u, LITTER_FAR)
	b.ellipse(Vector2(size.x * 0.22, size.y + 12.0 * u), size.x * 0.44, 74.0 * u, LITTER)
	b.ellipse(Vector2(size.x * 0.96, size.y + 10.0 * u), size.x * 0.24, 56.0 * u, LITTER)
	# The gap of the tools row.
	for l in GAP_LEAVES:
		_leaf(b, Vector2(l[0], l[1]) * size, l[2] * u, l[3], Color(l[4], l[5]))
	_acorn(b, GAP_ACORN * size, 13.0 * u, 0.4, 0.7)
	# The drift under the patch and round the tray.
	for t in TWIGS:
		_twig(b, Vector2(t[0], t[1]) * size, t[2] * u, t[3])
	for l in LEAVES:
		_leaf(b, Vector2(l[0], l[1]) * size, l[2] * u, l[3], l[4])
	for a in ACORNS:
		_acorn(b, Vector2(a[0], a[1]) * size, a[2] * u, -0.3, 1.0)
	_log(b, LOG_AT * size, u)
	_basket(b, BASKET_AT * size, u)
	_shown = b.mesh()
	queue_redraw()
	var mb := Face.Builder.new()
	for m in MOTES:
		Scenery.soft_disc(mb, Vector2(m[0], m[1]) * size, m[2] * u * 2.0, m[2] * u * 2.0, Color(DAPPLE, 0.9))
	_motes_shown = mb.mesh()
	_motes.size = size
	_motes.queue_redraw()

## A fallen leaf from `at`, `length` long, with its midrib.
func _leaf(b: Face.Builder, at: Vector2, length: float, angle: float, ink: Color) -> void:
	var xf := Transform2D(angle, at)
	var pts := Face.Builder.bezier2(Vector2.ZERO, Vector2(length * 0.55, -length * 0.42), Vector2(length, 0.0))
	pts.append_array(Face.Builder.bezier2(Vector2(length, 0.0), Vector2(length * 0.55, length * 0.42), Vector2.ZERO))
	b.polygon(xf * pts, ink)
	b.stroke(xf * PackedVector2Array([Vector2(-length * 0.14, 0.0), Vector2(length * 0.82, 0.0)]),
		maxf(length * 0.05, 1.0), Color(ink.darkened(0.22), ink.a), false, true)

## An acorn lying on its side, `r` its nut's half length.
func _acorn(b: Face.Builder, at: Vector2, r: float, angle: float, alpha: float) -> void:
	var xf := Transform2D(angle, at)
	Scenery.soft_disc(b, at + Vector2(0.0, r * 0.7), r * 1.3, r * 0.45, Color(Pal.TEXT, 0.12 * alpha))
	b.polygon(xf * Face.Builder.ring(Vector2.ZERO, r, r * 0.74), Color(NUT, alpha))
	b.polygon(xf * Face.Builder.ring(Vector2(-r * 0.2, -r * 0.24), r * 0.34, r * 0.16), Color(Pal.SURFACE, 0.35 * alpha))
	var cap := Geometry2D.intersect_polygons(Face.Builder.ring(Vector2(-r * 0.5, 0.0), r * 0.72, r * 0.86),
		PackedVector2Array([Vector2(-r * 2.0, -r), Vector2(-r * 0.42, -r), Vector2(-r * 0.42, r), Vector2(-r * 2.0, r)]))
	for part in cap:
		b.polygon(xf * part, Color(NUT_CAP, alpha))
	b.stroke(xf * PackedVector2Array([Vector2(-r * 1.2, 0.0), Vector2(-r * 1.5, -r * 0.1)]), r * 0.16,
		Color(NUT_CAP, alpha), false, true)

## A twig with one side shoot.
func _twig(b: Face.Builder, at: Vector2, length: float, angle: float) -> void:
	var xf := Transform2D(angle, at)
	b.stroke(xf * PackedVector2Array([Vector2(-length * 0.5, 0.0), Vector2(0.0, -length * 0.04),
		Vector2(length * 0.5, length * 0.02)]), 5.0 * length / 70.0, TWIG, false, true)
	b.stroke(xf * PackedVector2Array([Vector2(length * 0.1, -length * 0.03), Vector2(length * 0.28, -length * 0.2)]),
		4.0 * length / 70.0, TWIG, false, true)

## A button mushroom with no face, standing on `foot`, `h` tall.
func _button(b: Face.Builder, foot: Vector2, h: float, cap: Color) -> void:
	b.polygon(Face.Builder.round_rect(foot + Vector2(-h * 0.16, -h * 0.62), Vector2(h * 0.32, h * 0.62), h * 0.12), STEM)
	var dome := Geometry2D.intersect_polygons(Face.Builder.ring(foot + Vector2(0.0, -h * 0.56), h * 0.48, h * 0.44),
		PackedVector2Array([foot + Vector2(-h, -h * 1.2), foot + Vector2(h, -h * 1.2),
			foot + Vector2(h, -h * 0.5), foot + Vector2(-h, -h * 0.5)]))
	for part in dome:
		b.polygon(part, cap)
	b.disc(foot + Vector2(-h * 0.18, -h * 0.78), h * 0.07, Color(STEM, 0.9))
	b.disc(foot + Vector2(h * 0.14, -h * 0.70), h * 0.055, Color(STEM, 0.9))
	b.disc(foot + Vector2(h * 0.02, -h * 0.88), h * 0.045, Color(STEM, 0.9))

## The mossy log, lying in from the left edge with its cut end to the right,
## two buttons standing on it.
func _log(b: Face.Builder, at: Vector2, u: float) -> void:
	var half := 46.0 * u
	var end_x := at.x + 96.0 * u
	Scenery.soft_disc(b, Vector2(at.x, at.y + half * 1.05), 190.0 * u, 26.0 * u, Color(Pal.TEXT, 0.14))
	b.polygon(PackedVector2Array([Vector2(-8.0, at.y - half), Vector2(end_x, at.y - half),
		Vector2(end_x, at.y + half), Vector2(-8.0, at.y + half)]), BARK)
	b.polygon(PackedVector2Array([Vector2(-8.0, at.y + half * 0.45), Vector2(end_x, at.y + half * 0.45),
		Vector2(end_x, at.y + half), Vector2(-8.0, at.y + half)]), BARK_DEEP)
	b.stroke(PackedVector2Array([Vector2(-8.0, at.y - half * 0.62), Vector2(end_x - 14.0 * u, at.y - half * 0.62)]),
		6.0 * u, BARK_LIT, false, true)
	for x in [0.012, 0.062]:
		b.stroke(PackedVector2Array([Vector2(size.x * x, at.y - half * 0.1), Vector2(size.x * x + 34.0 * u, at.y - half * 0.06)]),
			4.0 * u, BARK_DEEP, false, true)
	# The cut end and its rings.
	b.ellipse(Vector2(end_x, at.y), 20.0 * u, half, BARK_DEEP)
	b.ellipse(Vector2(end_x, at.y), 15.0 * u, half * 0.84, HEART_WOOD)
	b.polygon(Face.Builder.ring(Vector2(end_x, at.y), 9.0 * u, half * 0.5), HEART_WOOD.darkened(0.08))
	b.polygon(Face.Builder.ring(Vector2(end_x, at.y), 4.0 * u, half * 0.22), HEART_WOOD)
	# Moss over its back, and the buttons on it.
	b.ellipse(Vector2(at.x - 30.0 * u, at.y - half * 0.92), 62.0 * u, 15.0 * u, MOSS_DEEP)
	b.ellipse(Vector2(at.x - 38.0 * u, at.y - half * 1.0), 48.0 * u, 11.0 * u, MOSS)
	b.ellipse(Vector2(at.x + 52.0 * u, at.y - half * 0.94), 26.0 * u, 9.0 * u, MOSS)
	_button(b, Vector2(at.x - 44.0 * u, at.y - half * 1.02), 46.0 * u, CAP_RED)
	_button(b, Vector2(at.x - 4.0 * u, at.y - half * 0.98), 32.0 * u, CAP_TAN)
	Scenery.tuft(b, Vector2(end_x + 30.0 * u, at.y + half * 0.96), 24.0 * u)

## The forager's basket, a few caps and a leaf showing over its rim.
func _basket(b: Face.Builder, at: Vector2, u: float) -> void:
	var w := 150.0 * u
	var h := 84.0 * u
	var top := at.y - h * 0.5
	Scenery.soft_disc(b, Vector2(at.x, at.y + h * 0.56), w * 0.66, 20.0 * u, Color(Pal.TEXT, 0.16))
	# The handle behind, then what it holds, then the weave in front.
	b.stroke(Face.Builder.bezier3(Vector2(at.x - w * 0.42, top + 6.0 * u), Vector2(at.x - w * 0.40, top - h * 0.95),
		Vector2(at.x + w * 0.40, top - h * 0.95), Vector2(at.x + w * 0.42, top + 6.0 * u), 20), 9.0 * u, WICKER_DEEP, false, true)
	_button(b, Vector2(at.x - w * 0.20, top + 22.0 * u), 44.0 * u, CAP_TAN)
	_button(b, Vector2(at.x + w * 0.10, top + 26.0 * u), 54.0 * u, CAP_RED)
	_leaf(b, Vector2(at.x + w * 0.22, top + 4.0 * u), 36.0 * u, -0.5, GOLD)
	var body := PackedVector2Array([Vector2(at.x - w * 0.5, top), Vector2(at.x + w * 0.5, top),
		Vector2(at.x + w * 0.40, top + h - 12.0 * u), Vector2(at.x + w * 0.34, top + h),
		Vector2(at.x - w * 0.34, top + h), Vector2(at.x - w * 0.40, top + h - 12.0 * u)])
	b.polygon(body, WICKER)
	for i in 3:
		var y := top + h * (0.34 + 0.22 * i)
		var inset := w * (0.47 - 0.035 * i)
		b.stroke(PackedVector2Array([Vector2(at.x - inset, y), Vector2(at.x + inset, y)]), 4.0 * u, WICKER_DEEP, false, true)
	b.polygon(Face.Builder.round_rect(Vector2(at.x - w * 0.54, top - 7.0 * u), Vector2(w * 1.08, 18.0 * u), 9.0 * u), WICKER_LIT)
	Scenery.tuft(b, Vector2(at.x - w * 0.66, at.y + h * 0.5), 22.0 * u)
