extends Control

## Tents' world: a misty wood, edge to edge under the meadow and the host's
## rows (CLAUDE.md: a game's world fills the screen). It is the menu card's
## picture (ui/menu/cards/tents.gd) at the size of the screen: pale mist
## across the top, behind the wordmark, with a low sun in it; a far line of
## pines standing in the gap of the tools row; quiet mist under the meadow;
## and at the foot the wood's floor, a nearer line of pines, and a camp on
## it -- one tent with its lamp lit, a cairn, a few tufts and flowers --
## where nothing lies over it while the board is played.
##
## The mist keeps the top because of what lies over it: the wordmark, the
## motto and the win's words are ink.
##
## One mesh, built when the rect changes and kept (`_shown`) until the next
## replaces it; the lamp's pool and three fireflies are a second, on a child
## whose alpha breathes (still under Motion.reduce).
##
## The colours are written here, not read from the board: the board preloads
## this file.

const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Face = preload("res://ui/faces/face.gd")
const CardFace = preload("res://ui/menu/cards/card_face.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

## The screen the picture was drawn on; everything scales with the width.
const W := 1080.0
const MIST_TOP := Color("eef6ef")
const MIST_LOW := Color("d6e9d9")
const WOOD_FAR := Color("c9e3cf")
const WOOD := Color("b4d6bd")
const WOOD_LOW := Color("a3caae")
## The far pines' two tones and the near ones' three.
const PINE_FAR := Color("c3dfca")
const PINE_MID := Color("a9cfb4")
const PINE_NEAR := Color("8dbb97")
const PINE_NEAR_DEEP := Color("7aaa86")
const TRUNK := Color("9a8468")
## The low sun in the mist, as shares of the rect, and its rings: [radius at
## W, alpha].
const SUN_AT := Vector2(0.90, 0.035)
const SUN_RINGS := [[620.0, 0.07], [420.0, 0.08], [240.0, 0.12]]
## The far pines in the gap of the tools row, between the bin and the bulb:
## their line as a share of the height, and each as [x share, height, half
## width] at W.
const RIDGE := 0.252
const RIDGE_PINES := [[0.275, 44.0, 18.0], [0.325, 62.0, 24.0], [0.385, 40.0, 17.0],
	[0.455, 70.0, 27.0], [0.515, 48.0, 20.0], [0.585, 58.0, 23.0], [0.640, 38.0, 16.0],
	[0.700, 66.0, 26.0], [0.765, 46.0, 19.0], [0.815, 34.0, 15.0]]
## The wood's floor at the foot: where it begins and where it is whole.
const FLOOR_FROM := 0.800
const FLOOR_LINE := 0.885
## The pines behind the camp, on the floor's line: [x share, height, half
## width] at W.
const BACK_PINES := [[0.04, 150.0, 52.0], [0.13, 104.0, 40.0], [0.23, 132.0, 48.0],
	[0.34, 90.0, 36.0], [0.44, 118.0, 44.0], [0.55, 84.0, 34.0], [0.76, 96.0, 38.0],
	[0.86, 140.0, 50.0], [0.96, 108.0, 42.0]]
## The pines that stand near, at the sides: [x share, foot's y share, height,
## half width] at W.
const NEAR_PINES := [[0.075, 0.975, 250.0, 84.0], [0.185, 0.990, 170.0, 60.0],
	[0.945, 0.985, 230.0, 78.0]]
## The camp: the tent's middle and size at W, the cairn's foot and size.
const TENT_AT := Vector2(0.655, 0.925)
const TENT_R := 170.0
const CAIRN_AT := Vector2(0.415, 0.962)
const CAIRN_R := 44.0
## Tufts as [x, y shares, height at W] and flowers as [x, y shares, radius at
## W, pink or white].
const TUFTS := [[0.300, 0.945, 30.0], [0.500, 0.975, 34.0], [0.560, 0.930, 24.0],
	[0.800, 0.972, 32.0], [0.860, 0.938, 24.0], [0.250, 0.985, 26.0]]
const FLOWERS := [[0.335, 0.968, 9.0, true], [0.470, 0.942, 7.0, false],
	[0.780, 0.948, 8.0, false], [0.840, 0.982, 9.0, true], [0.545, 0.988, 7.0, true]]
## The fireflies by the camp: [x, y shares, radius at W].
const FLIES := [[0.520, 0.868, 6.0], [0.780, 0.852, 5.0], [0.330, 0.900, 5.0]]
const BREATHE := 3.4
const BREATHE_LOW := 0.45

var _shown: ArrayMesh
var _glow: Control
var _glow_shown: ArrayMesh
var _breath: Tween

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow = Control.new()
	_glow.name = "Glow"
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow.draw.connect(func() -> void:
		if _glow_shown != null:
			_glow.draw_mesh(_glow_shown, null))
	add_child(_glow)
	resized.connect(_build)
	_build()
	_breath = Motion.pulse(_glow, "modulate:a", 1.0, BREATHE_LOW, BREATHE)

func _draw() -> void:
	if _shown != null:
		draw_mesh(_shown, null)

func _build() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var u := size.x / W
	var b := Face.Builder.new()
	# The mist under everything.
	var first := b.verts.size()
	b.polygon(PackedVector2Array([Vector2(-8.0, -8.0), Vector2(size.x + 8.0, -8.0),
		Vector2(size.x + 8.0, size.y + 8.0), Vector2(-8.0, size.y + 8.0)]), Color.WHITE)
	CardFace.shade(b, first, MIST_TOP, MIST_LOW, 0.0, size.y * FLOOR_FROM)
	# The low sun, behind the gear.
	var sun := SUN_AT * size
	for ring in SUN_RINGS:
		b.disc(sun, ring[0] * u, Color(Pal.SUN_RAY, ring[1]))
	# The far pines in the tools row's gap, their feet lost in the mist.
	var ridge := size.y * RIDGE
	for p in RIDGE_PINES:
		_pine(b, Vector2(size.x * p[0], ridge), p[1] * u, p[2] * u, PINE_FAR, PINE_FAR, 2)
	first = b.verts.size()
	b.polygon(PackedVector2Array([Vector2(size.x * 0.22, ridge - 16.0 * u), Vector2(size.x * 0.87, ridge - 16.0 * u),
		Vector2(size.x * 0.87, ridge + 6.0 * u), Vector2(size.x * 0.22, ridge + 6.0 * u)]), Color.WHITE)
	CardFace.shade(b, first, Color(MIST_TOP, 0.0), MIST_TOP, ridge - 16.0 * u, ridge + 4.0 * u)
	# The wood's floor coming up out of the mist at the foot.
	var line := size.y * FLOOR_LINE
	first = b.verts.size()
	b.polygon(PackedVector2Array([Vector2(-8.0, size.y * FLOOR_FROM), Vector2(size.x + 8.0, size.y * FLOOR_FROM),
		Vector2(size.x + 8.0, line + 2.0), Vector2(-8.0, line + 2.0)]), Color.WHITE)
	CardFace.shade(b, first, MIST_LOW, WOOD_FAR, size.y * FLOOR_FROM, line)
	for p in BACK_PINES:
		_pine(b, Vector2(size.x * p[0], line + 2.0), p[1] * u, p[2] * u, PINE_MID, PINE_MID, 3)
	first = b.verts.size()
	b.polygon(PackedVector2Array([Vector2(-8.0, line), Vector2(size.x + 8.0, line),
		Vector2(size.x + 8.0, size.y + 8.0), Vector2(-8.0, size.y + 8.0)]), Color.WHITE)
	CardFace.shade(b, first, WOOD, WOOD_LOW, line, size.y)
	# A soft clearing where the camp stands.
	Scenery.soft_disc(b, Vector2(size.x * 0.56, size.y * 0.958), size.x * 0.36, 70.0 * u, Color(Pal.MEADOW, 0.55))
	# The near pines at the sides, their shadows on the floor.
	for p in NEAR_PINES:
		var foot := Vector2(size.x * p[0], size.y * p[1])
		Scenery.soft_disc(b, foot + Vector2(0.0, 4.0 * u), p[3] * u * 0.9, 12.0 * u, Color(Pal.LEAF_DEEP, 0.16))
		b.polygon(Face.Builder.round_rect(foot + Vector2(-9.0, -26.0) * u, Vector2(18.0, 28.0) * u, 4.0 * u), TRUNK)
		_pine(b, foot + Vector2(0.0, -18.0 * u), p[2] * u, p[3] * u, PINE_NEAR, PINE_NEAR_DEEP, 3)
	for t in TUFTS:
		Scenery.tuft(b, Vector2(t[0], t[1]) * size, t[2] * u)
	for f in FLOWERS:
		_flower(b, Vector2(f[0], f[1]) * size, f[2] * u, Pal.FLOWER if f[3] else Pal.SURFACE)
	_cairn(b, CAIRN_AT * size, CAIRN_R * u)
	_tent(b, TENT_AT * size, TENT_R * u)
	_shown = b.mesh()
	queue_redraw()
	# What breathes: the lamp's pool at the doorway and the fireflies.
	var g := Face.Builder.new()
	var at := TENT_AT * size
	var R := TENT_R * u
	Scenery.soft_disc(g, at + Vector2(-0.05, 0.40) * R, 0.46 * R, 0.12 * R, Color(Pal.SUN, 0.42))
	g.disc(at + Vector2(-0.05, 0.16) * R, 0.20 * R, Color(Pal.SUN_RAY, 0.16))
	for f in FLIES:
		var p := Vector2(f[0], f[1]) * size
		g.disc(p, f[2] * u * 2.6, Color(Pal.SUN_RAY, 0.16))
		g.disc(p, f[2] * u, Color(Pal.SUN_RAY, 0.9))
	_glow_shown = g.mesh()
	_glow.size = size
	_glow.queue_redraw()

## A pine standing on `foot`: `tiers` boughs one over another, the lit side
## `colour` and the other `deep`.
func _pine(b: Face.Builder, foot: Vector2, tall: float, wide: float, colour: Color, deep: Color, tiers: int) -> void:
	for i in tiers:
		var t := float(i) / tiers
		var base := foot.y - tall * t * 0.78
		var top := foot.y - tall * minf(1.0, t * 0.78 + 0.58)
		var half := wide * (1.0 - t * 0.55)
		b.polygon(PackedVector2Array([Vector2(foot.x, top), Vector2(foot.x + half, base),
			Vector2(foot.x - half, base)]), deep)
		if deep != colour:
			b.polygon(PackedVector2Array([Vector2(foot.x, top), Vector2(foot.x + half * 0.25, base),
				Vector2(foot.x - half, base)]), colour)

## A tent of `R` at `at`, cut as the board's own (its lines, pegs, poles, two
## slopes, seam and lit edge), with the doorway dark and a lamp in it.
func _tent(b: Face.Builder, at: Vector2, R: float) -> void:
	Scenery.soft_disc(b, at + Vector2(0.0, 0.42) * R, 0.50 * R, 0.10 * R, Color(Pal.TEXT, 0.18))
	for side: float in [-1.0, 1.0]:
		b.stroke(PackedVector2Array([at + Vector2(side * 0.44, 0.4) * R, at + Vector2(side * 0.16, -0.3) * R]),
			0.03 * R, Color(Pal.TENT_DARK, 0.55))
		b.polygon(Face.Builder.round_rect(at + Vector2(side * 0.44 - 0.025, 0.35) * R, Vector2(0.05, 0.09) * R, 0.02 * R),
			Pal.BARK)
		b.stroke(PackedVector2Array([at + Vector2(-side * 0.025, -0.41) * R, at + Vector2(side * 0.05, -0.52) * R]),
			0.035 * R, Pal.BARK)
	b.polygon(PackedVector2Array([at + Vector2(0.0, -0.46) * R, at + Vector2(0.42, 0.4) * R,
		at + Vector2(-0.42, 0.4) * R]), Pal.TENT_DEEP)
	b.polygon(PackedVector2Array([at + Vector2(0.0, -0.46) * R, at + Vector2(0.2, 0.4) * R,
		at + Vector2(-0.42, 0.4) * R]), Pal.TENT_CANVAS)
	b.stroke(PackedVector2Array([at + Vector2(-0.02, -0.42) * R, at + Vector2(-0.39, 0.38) * R]),
		0.022 * R, Color(1.0, 1.0, 1.0, 0.35), false, false)
	# The doorway and the lamp hung in it.
	b.polygon(PackedVector2Array([at + Vector2(-0.05, -0.10) * R, at + Vector2(0.08, 0.4) * R,
		at + Vector2(-0.19, 0.4) * R]), Pal.TENT_DOOR)
	b.disc(at + Vector2(-0.05, 0.20) * R, 0.085 * R, Color(Pal.SUN_RAY, 0.45))
	b.disc(at + Vector2(-0.05, 0.20) * R, 0.045 * R, Pal.SUN_RAY)

## Three stones one on another, standing on `foot`.
func _cairn(b: Face.Builder, foot: Vector2, r: float) -> void:
	Scenery.soft_disc(b, foot + Vector2(0.0, 0.04 * r), r * 1.05, r * 0.2, Color(Pal.TEXT, 0.16))
	var stones := [[0.0, -0.30, 1.0, 0.34, Color("b9b4a6")], [0.06, -0.80, 0.74, 0.27, Color("c8c3b5")],
		[-0.04, -1.20, 0.48, 0.20, Color("d6d2c6")]]
	for s in stones:
		var c: Vector2 = foot + Vector2(s[0], s[1]) * r
		b.ellipse(c, s[2] * r, s[3] * r, s[4])
		b.ellipse(c + Vector2(-0.18, -0.30) * s[2] * r * Vector2(1.0, s[3] / s[2]), s[2] * r * 0.5, s[3] * r * 0.3,
			Color(1.0, 1.0, 1.0, 0.28))

## A meadow flower of `r`: five petals round a sun-yellow middle.
func _flower(b: Face.Builder, at: Vector2, r: float, petal: Color) -> void:
	for i in 5:
		b.disc(at + Vector2.from_angle(-PI * 0.5 + i * TAU / 5.0) * r, r * 0.72, petal)
	b.disc(at, r * 0.6, Pal.SUN)
