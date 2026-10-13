extends Control

## Hedgehogs' world: the back garden on a raking day, edge to edge under the
## bed and the host's rows (CLAUDE.md: a game's world fills the screen). It
## is the menu card's fresh lawn (ui/menu/cards/hedgehogs.gd) at the size of
## the screen: pale at the top, where the wordmark is ink, with a low sun in
## the corner; mown in faint leaning bands; a washing line with three small
## things pegged on it in the gap of the tools row; a drift of fallen leaves
## and acorns between the bed and the tray; and in the foot, either side of
## the tray's two chips, a wheelbarrow heaped with leaves and a wicker
## basket with a rake leant on it, over a fringe of grass and toadstools.
##
## Nothing here has a face: only the lawn's own sleepers do. The colours
## are written here; the board preloads this file, so it does not preload
## the board.
##
## One mesh, built when the rect or the bed's foot changes (`set_foot`) and
## kept (`_shown`) until the next replaces it; the motes in the light are a
## second, on a child whose alpha breathes (still under Motion.reduce).

const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Face = preload("res://ui/faces/face.gd")
const CardFace = preload("res://ui/menu/cards/card_face.gd")
const Scenery = preload("res://ui/flat/scenery.gd")
const Lawn = preload("res://ui/faces/leaf_pile.gd")

## The screen the picture was drawn on; everything scales with the width.
const W := 1080.0
const AIR := Color("fbf8e8")
const LAWN_TOP := Color("eaf3d8")
const LAWN_LOW := Color("cfe2b0")
const MOWN := Color("b4d08f")
const SHADE := Color("9dbd78")
## Where the air has become lawn, as a share of the height.
const LAWN_FROM := 0.27
## The sun's middle, as shares of the rect, and its rings: [radius at W,
## alpha].
const SUN_AT := Vector2(0.92, 0.03)
const SUN_RINGS := [[620.0, 0.08], [420.0, 0.09], [250.0, 0.13]]
## The mown bands: their breadth at W and how far they lean across the
## screen.
const BAND := 150.0
const LEAN := 70.0
## The washing line in the gap of the tools row: its ends as shares, its sag
## at W, and what hangs on it: [along the line 0..1, width, height at W,
## colour].
const LINE_FROM := Vector2(0.305, 0.208)
const LINE_TO := Vector2(0.805, 0.208)
const LINE_SAG := 24.0
const LINE_INK := Color("b89a6e")
const WASHING := [
	[0.22, 26.0, 34.0, Color("f3c6b8")],
	[0.50, 34.0, 28.0, Color("f7efd9")],
	[0.76, 24.0, 36.0, Color("bcd6e6")],
]
const PEG := Color("c8a17a")
## The drift between the bed and the tray: [x as a share, y at W from the
## drift's line, length at W, angle, colour index, kind]; -1 is an acorn.
const DRIFT := [
	[0.065, 6.0, 30.0, 0.6, 0, 0], [0.150, -10.0, 26.0, -0.9, 2, 1], [0.255, 8.0, 28.0, 2.1, 1, 2],
	[0.345, -4.0, 12.0, 0.4, -1, 0], [0.445, 10.0, 26.0, 1.3, 4, 0], [0.560, -8.0, 30.0, -0.4, 3, 1],
	[0.660, 6.0, 24.0, 2.6, 0, 2], [0.745, -6.0, 11.0, -0.7, -1, 0], [0.840, 8.0, 28.0, 0.9, 2, 0],
	[0.935, -8.0, 26.0, -1.6, 1, 1],
]
## Where the drift lies when the board has not said where its bed ends, as
## a share of the height, and how far under the bed it lies at W.
const DRIFT_AT := 0.868
const DRIFT_UNDER := 56.0
## The foot's things, from the bottom edge at W: the wheelbarrow's and the
## basket's middles (x as a share).
const BARROW_AT := Vector2(0.098, 118.0)
const BASKET_AT := Vector2(0.905, 104.0)
const WICKER := Color("d6b47e")
const WICKER_DEEP := Color("b08a55")
const TIN := Color("8fa9a3")
const TIN_DEEP := Color("6d8a85")
## The fringe along the bottom edge: [x as a share, height at W].
const FRINGE := [
	[0.035, 22.0], [0.215, 18.0], [0.300, 24.0], [0.405, 17.0], [0.500, 22.0],
	[0.610, 18.0], [0.715, 24.0], [0.790, 17.0], [0.975, 22.0],
]
const STOOLS := [[0.185, 30.0, 13.0], [0.822, 26.0, 11.0], [0.455, 20.0, 9.0]]
## The motes: [x, y as shares, radius at W].
const MOTES := [
	[0.36, 0.238, 5.0], [0.62, 0.226, 4.0], [0.74, 0.244, 4.5],
	[0.20, 0.905, 5.0], [0.50, 0.985, 4.0], [0.80, 0.900, 4.5],
]
const BREATH := 3.4
const BREATH_LOW := 0.3

var _shown: ArrayMesh
var _motes: Control
var _motes_shown: ArrayMesh
var _breath: Tween
## Where the board's bed ends, in this rect's pixels; negative until told.
var _foot := -1.0

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

## The board says where its bed ends, so the drift lies under it; the mesh is
## made again only when that moves.
func set_foot(y: float) -> void:
	if absf(y - _foot) < 0.5:
		return
	_foot = y
	_build()

func _build() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var u := size.x / W
	var w := size.x
	var h := size.y
	var b := Face.Builder.new()
	# The air and the lawn it turns into.
	var first := b.verts.size()
	b.polygon(PackedVector2Array([Vector2(-8.0, -8.0), Vector2(w + 8.0, -8.0),
		Vector2(w + 8.0, h * LAWN_FROM), Vector2(-8.0, h * LAWN_FROM)]), Color.WHITE)
	CardFace.shade(b, first, AIR, LAWN_TOP, 0.0, h * LAWN_FROM)
	first = b.verts.size()
	b.polygon(PackedVector2Array([Vector2(-8.0, h * LAWN_FROM), Vector2(w + 8.0, h * LAWN_FROM),
		Vector2(w + 8.0, h + 8.0), Vector2(-8.0, h + 8.0)]), Color.WHITE)
	CardFace.shade(b, first, LAWN_TOP, LAWN_LOW, h * LAWN_FROM, h)
	var sun := SUN_AT * size
	for ring: Array in SUN_RINGS:
		b.disc(sun, float(ring[0]) * u, Color(Pal.SUN_RAY, float(ring[1])))
	# The mower's bands, leaning, from under the tools row down.
	var band := BAND * u
	var lean := LEAN * u
	var k := 0
	var y := h * LAWN_FROM + band * 0.4
	while y < h:
		if k % 2 == 0:
			b.polygon(PackedVector2Array([Vector2(-8.0, y + lean), Vector2(w + 8.0, y),
				Vector2(w + 8.0, y + band), Vector2(-8.0, y + band + lean)]), Color(MOWN, 0.16))
		y += band
		k += 1
	# The washing line.
	var from := LINE_FROM * size
	var to := LINE_TO * size
	var cord := Face.Builder.bezier2(from, (from + to) * 0.5 + Vector2(0.0, LINE_SAG * 2.0 * u), to, 20)
	cord.append(to)
	b.stroke(cord, 3.0 * u, Color(LINE_INK, 0.8), false, true)
	for wash: Array in WASHING:
		var at := cord[clampi(int(round(float(wash[0]) * float(cord.size() - 1))), 0, cord.size() - 1)]
		var sz := Vector2(float(wash[1]), float(wash[2])) * u
		b.fan(Face.Builder.round_rect(at + Vector2(-sz.x * 0.5, 1.0 * u), sz, 5.0 * u), wash[3])
		b.fan(Face.Builder.round_rect(at + Vector2(-sz.x * 0.5, sz.y * 0.62), Vector2(sz.x, sz.y * 0.16), 0.0),
			Color((wash[3] as Color).darkened(0.12), 0.9))
		for side: float in [-0.3, 0.3]:
			b.fan(Face.Builder.round_rect(at + Vector2(sz.x * side - 2.5 * u, -5.0 * u), Vector2(5.0, 12.0) * u, 2.0 * u), PEG)
	# The drift the wind left under the bed.
	var line := (_foot + DRIFT_UNDER * u) if _foot >= 0.0 else h * DRIFT_AT
	line = minf(line, h - 220.0 * u)
	for d: Array in DRIFT:
		var at := Vector2(float(d[0]) * w, line + float(d[1]) * u)
		if int(d[4]) < 0:
			Lawn.acorn(b, at, float(d[2]) * u, float(d[3]))
			continue
		var colour: Color = Pal.AUTUMN_LEAVES[int(d[4])]
		Lawn.leaf(b, at + Vector2(2.0, 3.0) * u, float(d[2]) * u, float(d[3]), Color(Pal.TEXT, 0.08), int(d[5]))
		Lawn.leaf(b, at, float(d[2]) * u, float(d[3]), colour.lerp(LAWN_LOW, 0.22), int(d[5]))
	_barrow(b, Vector2(BARROW_AT.x * w, h - BARROW_AT.y * u), u)
	_basket(b, Vector2(BASKET_AT.x * w, h - BASKET_AT.y * u), u)
	# The fringe along the very foot.
	for f: Array in FRINGE:
		Scenery.tuft(b, Vector2(float(f[0]) * w, h - 8.0 * u), float(f[1]) * u)
	for s: Array in STOOLS:
		Lawn.toadstool(b, Vector2(float(s[0]) * w, h - float(s[1]) * u), float(s[2]) * u)
	_shown = b.mesh()
	queue_redraw()
	var mb := Face.Builder.new()
	for m: Array in MOTES:
		var at := Vector2(float(m[0]), float(m[1])) * size
		mb.disc(at, float(m[2]) * 2.2 * u, Color(Pal.SUN_RAY, 0.16))
		mb.disc(at, float(m[2]) * u, Color(Pal.SURFACE, 0.8))
	_motes_shown = mb.mesh()
	_motes.size = size
	_motes.queue_redraw()

## A wheelbarrow seen from the side, heaped with leaves: its handles to the
## left, its wheel to the right. `at` is the middle of its tub.
func _barrow(b: Face.Builder, at: Vector2, u: float) -> void:
	Scenery.soft_disc(b, at + Vector2(6.0, 74.0) * u, 96.0 * u, 16.0 * u, Color(SHADE, 0.5))
	# The heap, behind the tub's rim.
	Lawn.pile(b, at + Vector2(0.0, -34.0) * u, 132.0 * u, 11)
	# The legs and the handles.
	b.stroke(PackedVector2Array([at + Vector2(-46.0, 30.0) * u, at + Vector2(-58.0, 70.0) * u]), 8.0 * u, Pal.PLAQUE_DEEP)
	b.stroke(PackedVector2Array([at + Vector2(-98.0, -22.0) * u, at + Vector2(-58.0, 6.0) * u,
		at + Vector2(52.0, 46.0) * u]), 9.0 * u, Pal.PLAQUE)
	# The wheel.
	var hub := at + Vector2(60.0, 52.0) * u
	b.disc(hub, 24.0 * u, Pal.PLAQUE_DEEP)
	b.disc(hub, 15.0 * u, Pal.WOOD)
	b.disc(hub, 5.0 * u, Pal.PLAQUE_DEEP)
	# The tub.
	var tub := PackedVector2Array([at + Vector2(-78.0, -22.0) * u, at + Vector2(84.0, -22.0) * u,
		at + Vector2(58.0, 34.0) * u, at + Vector2(-52.0, 34.0) * u])
	b.polygon(tub, TIN)
	b.polygon(PackedVector2Array([at + Vector2(-62.0, 14.0) * u, at + Vector2(67.0, 14.0) * u,
		at + Vector2(58.0, 34.0) * u, at + Vector2(-52.0, 34.0) * u]), TIN_DEEP)
	b.stroke(PackedVector2Array([at + Vector2(-80.0, -22.0) * u, at + Vector2(86.0, -22.0) * u]), 7.0 * u, TIN_DEEP.lightened(0.35))
	# Two leaves that slid over the rim.
	Lawn.leaf(b, at + Vector2(-40.0, -20.0) * u, 30.0 * u, 2.2, Pal.AUTUMN_LEAVES[2], 0)
	Lawn.leaf(b, at + Vector2(34.0, -18.0) * u, 28.0 * u, 0.9, Pal.AUTUMN_LEAVES[1], 1)

## A wicker basket of leaves with the rake leant on it. `at` is the middle
## of the basket.
func _basket(b: Face.Builder, at: Vector2, u: float) -> void:
	Scenery.soft_disc(b, at + Vector2(0.0, 58.0) * u, 88.0 * u, 15.0 * u, Color(SHADE, 0.5))
	# The rake, behind, its head up.
	Lawn.rake(b, at + Vector2(52.0, -52.0) * u, 210.0 * u, 0.22)
	Lawn.pile(b, at + Vector2(-6.0, -40.0) * u, 118.0 * u, 5)
	var body := PackedVector2Array([at + Vector2(-70.0, -24.0) * u, at + Vector2(62.0, -24.0) * u,
		at + Vector2(48.0, 54.0) * u, at + Vector2(-56.0, 54.0) * u])
	b.polygon(body, WICKER)
	for i in 4:
		var yy := -8.0 + float(i) * 16.0
		var inset := 3.0 + float(i) * 3.4
		b.stroke(PackedVector2Array([at + Vector2(-68.0 + inset, yy) * u, at + Vector2(60.0 - inset, yy) * u]),
			3.0 * u, Color(WICKER_DEEP, 0.55), false, false)
	for i in 6:
		var xx := -52.0 + float(i) * 20.0
		b.stroke(PackedVector2Array([at + Vector2(xx * 1.12, -22.0) * u, at + Vector2(xx * 0.92, 52.0) * u]),
			2.5 * u, Color(WICKER_DEEP, 0.4), false, false)
	b.stroke(PackedVector2Array([at + Vector2(-74.0, -24.0) * u, at + Vector2(66.0, -24.0) * u]), 9.0 * u, WICKER_DEEP)
	Lawn.leaf(b, at + Vector2(-30.0, -22.0) * u, 28.0 * u, 2.4, Pal.AUTUMN_LEAVES[0], 2)
	Lawn.leaf(b, at + Vector2(-82.0, 50.0) * u, 26.0 * u, 0.5, Pal.AUTUMN_LEAVES[3].lerp(LAWN_LOW, 0.2), 0)
