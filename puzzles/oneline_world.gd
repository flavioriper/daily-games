extends Control

## One Line's world: a garden in the morning's dew, edge to edge under the
## board and the host's rows (CLAUDE.md: a game's world fills the screen). It
## is the menu card's ground (ui/menu/cards/oneline.gd) at the size of the
## screen: pale dew with a low sun behind the wordmark, the lattice's dots
## faint under the figure, a short boardwalk between two posts in the gap of
## the tools row, and in the open foot the garden the snail came out of -- a
## mossy bank, a path of stepping drums with daisies open on them, a stack
## of planks still to lay, a pond with two lily pads, toadstools, tufts, and
## her shine across the bank.
##
## The top is the lightest of it because of what lies over it: the wordmark,
## the motto and the win's "Well done!" are ink with no scrim.
##
## One mesh, built when the rect changes and kept (`_shown`) until the next
## replaces it; the dew's glints are a second, on a child whose alpha
## breathes (still under Motion.reduce). The colours are written here: the
## board preloads this file, so reading them off the board would be a cycle.

const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Face = preload("res://ui/faces/face.gd")
const CardFace = preload("res://ui/menu/cards/card_face.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

## The screen the picture was drawn on; everything scales with the width.
const W := 1080.0
const DEW_TOP := Color("f3f8f1")
const DEW_MID := Color("e3efe6")
const DEW_LOW := Color("cde4dc")
const BANK_FAR := Color("b9d8c4")
const BANK := Color("a3cbae")
const BANK_NEAR := Color("8fbd9a")
const POND := Color("a9d3d6")
const POND_DEEP := Color("8fc2c8")
const PAD_LEAF := Color("7fb574")
const STONE := Color("58606c")
const DRUM := Color("c3b7a4")
const DRUM_DEEP := Color("9c9083")
const CAP_SPENT := Color("dccfb3")
const PLANK := Color("c8a17a")
const PLANK_DEEP := Color("9c7350")
const PETAL := Color("fffdf8")
const TOAD := Color("e2705f")
const TOAD_STEM := Color("f6ead6")
## The low sun behind the wordmark: its middle as shares of the rect, and
## its rings as [radius at W, alpha].
const SUN_AT := Vector2(0.10, 0.02)
const SUN_RINGS := [[760.0, 0.14], [520.0, 0.16], [300.0, 0.20]]
## The lattice showing through: a dot every DOT_STEP at W, from under the
## tools row to the bank, DOT_A strong.
const DOT_STEP := 90.0
const DOT_FROM := 0.275
const DOT_TO := 0.80
const DOT_R := 3.0
const DOT_A := 0.07
## The boardwalk in the gap of the tools row, between the bin and Hint: its
## posts as shares, their radius at W, and how far along it is planked.
const WALK_FROM := Vector2(0.330, 0.232)
const WALK_TO := Vector2(0.780, 0.232)
const WALK_POST := 24.0
const WALK_LAID := 0.62
## The bank: where its three lines stand at the left and right edge, as
## shares of the height.
const BANKS := [[0.842, 0.870, BANK_FAR], [0.888, 0.862, BANK], [0.930, 0.948, BANK_NEAR]]
## The stepping drums across the bank: [x, y as shares, radius at W, spent].
const DRUMS := [
	[0.105, 0.925, 40.0, true], [0.245, 0.957, 44.0, false],
	[0.395, 0.930, 40.0, true], [0.540, 0.962, 44.0, true],
]
## The pond in the right corner and its pads: [x, y, radius at W].
const POND_AT := Vector2(0.860, 0.975)
const POND_R := Vector2(250.0, 96.0)
const PADS := [[0.800, 0.968, 30.0], [0.905, 0.983, 22.0]]
## The stack of planks beside it: its middle as shares, a plank's length and
## width at W.
const STACK_AT := Vector2(0.700, 0.905)
const STACK := Vector2(190.0, 26.0)
## Toadstools: [x, y as shares, radius at W].
const TOADS := [[0.935, 0.888, 26.0], [0.975, 0.905, 17.0], [0.030, 0.872, 18.0]]
## Tufts: [x, y as shares, height at W]; loose daisies the same.
const TUFTS := [
	[0.060, 0.895, 34.0], [0.180, 0.990, 30.0], [0.320, 0.985, 26.0], [0.470, 0.900, 28.0],
	[0.620, 0.990, 30.0], [0.840, 0.880, 30.0], [0.985, 0.955, 28.0],
]
const DAISIES := [[0.170, 0.898, 13.0], [0.455, 0.990, 12.0], [0.605, 0.918, 11.0], [0.640, 0.968, 12.0]]
## Her shine across the bank: a path through these shares.
const SHINE := [Vector2(0.105, 0.925), Vector2(0.170, 0.975), Vector2(0.330, 0.905), Vector2(0.395, 0.930)]
const SHINE_A := 0.34
## The dew that glints: [x, y as shares, radius at W].
const GLINTS := [
	[0.215, 0.878, 13.0], [0.505, 0.935, 11.0], [0.760, 0.955, 12.0],
	[0.560, 0.214, 9.0], [0.880, 0.868, 10.0], [0.345, 0.972, 9.0],
]
const BREATH := 3.4
const BREATH_LOW := 0.3

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

func _build() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var u := size.x / W
	var b := Face.Builder.new()
	# The dew under everything, in two washes: lightest over the rows.
	var half := size.y * 0.45
	var first := b.verts.size()
	b.polygon(PackedVector2Array([Vector2(-8.0, -8.0), Vector2(size.x + 8.0, -8.0),
		Vector2(size.x + 8.0, half), Vector2(-8.0, half)]), Color.WHITE)
	CardFace.shade(b, first, DEW_TOP, DEW_MID, 0.0, half)
	first = b.verts.size()
	b.polygon(PackedVector2Array([Vector2(-8.0, half), Vector2(size.x + 8.0, half),
		Vector2(size.x + 8.0, size.y + 8.0), Vector2(-8.0, size.y + 8.0)]), Color.WHITE)
	CardFace.shade(b, first, DEW_MID, DEW_LOW, half, size.y)
	var sun := SUN_AT * size
	for ring in SUN_RINGS:
		b.disc(sun, ring[0] * u, Color(Pal.SUN_RAY, ring[1]))
	# The lattice the figure is drawn on, showing through.
	var step := DOT_STEP * u
	var y := size.y * DOT_FROM
	while y < size.y * DOT_TO:
		var x := fmod(size.x * 0.5, step)
		while x < size.x:
			b.disc(Vector2(x, y), DOT_R * u, Color(Pal.TEXT, DOT_A))
			x += step
		y += step
	_boardwalk(b, u)
	# The bank, far to near.
	for line in BANKS:
		var from := Vector2(-8.0, size.y * float(line[0]))
		var to := Vector2(size.x + 8.0, size.y * float(line[1]))
		var pts := Face.Builder.bezier3(from, Vector2(size.x * 0.30, from.y - 46.0 * u),
			Vector2(size.x * 0.68, to.y + 40.0 * u), to, 28)
		pts.append(to)
		pts.append(Vector2(size.x + 8.0, size.y + 8.0))
		pts.append(Vector2(-8.0, size.y + 8.0))
		b.polygon(pts, line[2])
	# The pond and its pads.
	var pond := POND_AT * size
	b.ellipse(pond, POND_R.x * u, POND_R.y * u, POND_DEEP)
	b.ellipse(pond + Vector2(0.0, -6.0 * u), POND_R.x * u * 0.94, POND_R.y * u * 0.86, POND)
	b.stroke(Face.Builder.arc_points(pond + Vector2(-40.0 * u, -10.0 * u), 70.0 * u, PI * 1.15, PI * 1.6),
		5.0 * u, Color(1.0, 1.0, 1.0, 0.45), false, false)
	for p in PADS:
		_pad(b, Vector2(p[0], p[1]) * size, p[2] * u)
	# Her shine, then the drums it runs between.
	var shine := Face.Builder.bezier3(SHINE[0] * size, SHINE[1] * size, SHINE[2] * size, SHINE[3] * size, 24)
	shine.append(SHINE[3] * size)
	b.stroke(shine, 15.0 * u, Color(1.0, 1.0, 1.0, SHINE_A * 0.5), false, false)
	b.stroke(shine, 6.0 * u, Color(1.0, 1.0, 1.0, SHINE_A), false, false)
	for d in DRUMS:
		var at := Vector2(d[0], d[1]) * size
		var r: float = d[2] * u
		Scenery.soft_disc(b, at + Vector2(0.05, 0.34) * r, r * 1.1, r * 0.8, Color(Pal.TEXT, 0.2))
		_drum(b, at, r, CAP_SPENT if d[3] else Pal.ACCENT)
		if d[3]:
			_daisy(b, at + Vector2(0.0, -0.04) * r, r * 0.42)
	_stack(b, STACK_AT * size, u)
	for t in TOADS:
		_toad(b, Vector2(t[0], t[1]) * size, t[2] * u)
	for t in TUFTS:
		Scenery.tuft(b, Vector2(t[0], t[1]) * size, t[2] * u)
	for d in DAISIES:
		var at := Vector2(d[0], d[1]) * size
		b.stroke(PackedVector2Array([at, at + Vector2(0.0, 1.9) * d[2] * u]), 3.0 * u, Pal.LEAF_DEEP, false, false)
		_daisy(b, at, d[2] * u)
	_shown = b.mesh()
	queue_redraw()
	var gb := Face.Builder.new()
	for g in GLINTS:
		_glint(gb, Vector2(g[0], g[1]) * size, g[2] * u)
	_glints_shown = gb.mesh()
	_glints.size = size
	_glints.queue_redraw()

## The gap of the tools row: a ford between two posts, planked most of the
## way, the near post spent and in flower.
func _boardwalk(b: Face.Builder, u: float) -> void:
	var from := WALK_FROM * size
	var to := WALK_TO * size
	var r := WALK_POST * u
	b.stroke(PackedVector2Array([from + Vector2(0.0, 5.0 * u), to + Vector2(0.0, 5.0 * u)]), 22.0 * u, Color(Pal.TEXT, 0.09))
	b.stroke(PackedVector2Array([from, to]), 18.0 * u, STONE)
	var end := from.lerp(to, WALK_LAID)
	b.stroke(PackedVector2Array([from, end]), 21.0 * u, PLANK_DEEP)
	var slats := 7
	for k in slats:
		var a := from.lerp(end, (k + 0.06) / slats)
		var z := from.lerp(end, (k + 0.94) / slats)
		b.stroke(PackedVector2Array([a, z]), 16.0 * u, PLANK.lightened(0.06) if k % 2 == 0 else PLANK.darkened(0.04), false, false)
		b.stroke(PackedVector2Array([a + Vector2(0.0, -5.0 * u), z + Vector2(0.0, -5.0 * u)]), 3.5 * u,
			Color(1.0, 1.0, 1.0, 0.28), false, false)
	for post in [[from, true], [to, false]]:
		var at: Vector2 = post[0]
		Scenery.soft_disc(b, at + Vector2(0.05, 0.34) * r, r * 1.1, r * 0.8, Color(Pal.TEXT, 0.2))
		_drum(b, at, r, CAP_SPENT if post[1] else Pal.ACCENT)
		if post[1]:
			_daisy(b, at + Vector2(0.0, -0.04) * r, r * 0.42)

## A post: the drum, lit on its upper rim, and the cap sat in it.
func _drum(b: Face.Builder, at: Vector2, r: float, cap: Color) -> void:
	b.ellipse(at + Vector2(0.0, 0.1) * r, r, r, DRUM_DEEP)
	b.ellipse(at, r, r, DRUM)
	b.stroke(Face.Builder.arc_points(at, 0.86 * r, PI * 1.05, PI * 1.7), 0.07 * r, Color(1.0, 1.0, 1.0, 0.3), false, false)
	var centre := at + Vector2(0.0, -0.04) * r
	b.ellipse(centre + Vector2(0.0, 0.06) * r, 0.6 * r, 0.6 * r, cap.darkened(0.18))
	b.ellipse(centre, 0.6 * r, 0.6 * r, cap)

## A daisy of `r`: seven petals round a sun.
func _daisy(b: Face.Builder, at: Vector2, r: float) -> void:
	for k in 7:
		var dir := Vector2.from_angle(TAU * k / 7.0 - PI * 0.5)
		b.ellipse(at + dir * r * 0.62, r * 0.36, r * 0.36, PETAL)
	b.disc(at, r * 0.34, Pal.SUN)

## A lily pad: a disc with a wedge cut out of it, lit on one side.
func _pad(b: Face.Builder, at: Vector2, r: float) -> void:
	var pts := PackedVector2Array([at])
	var n := 18
	for k in n + 1:
		var a := -0.5 + (TAU - 0.7) * k / n
		pts.append(at + Vector2(cos(a) * r, sin(a) * r * 0.5))
	b.polygon(pts, PAD_LEAF)
	b.stroke(Face.Builder.arc_points(at, r * 0.7, PI * 1.1, PI * 1.5), r * 0.1, Color(1.0, 1.0, 1.0, 0.3), false, false)

## Three planks still to lay, one across two.
func _stack(b: Face.Builder, at: Vector2, u: float) -> void:
	var long := STACK.x * u
	var wide := STACK.y * u
	Scenery.soft_disc(b, at + Vector2(0.0, wide * 1.3), long * 0.6, wide * 0.9, Color(Pal.TEXT, 0.16))
	for plank in [[Vector2(-0.04, 0.55), -0.06, 0.0], [Vector2(0.03, -0.45), 0.04, 0.05], [Vector2(0.0, -1.3), 0.34, -0.03]]:
		var mid: Vector2 = at + (plank[0] as Vector2) * Vector2(long, wide)
		var along := Vector2.from_angle(plank[1]) * long * 0.5
		var tone: float = plank[2]
		b.stroke(PackedVector2Array([mid - along + Vector2(0.0, wide * 0.2), mid + along + Vector2(0.0, wide * 0.2)]), wide, PLANK_DEEP)
		b.stroke(PackedVector2Array([mid - along, mid + along]), wide * 0.84,
			PLANK.lightened(tone) if tone > 0.0 else PLANK.darkened(-tone))
		b.stroke(PackedVector2Array([mid - along * 0.9 + Vector2(0.0, -wide * 0.24), mid + along * 0.9 + Vector2(0.0, -wide * 0.24)]),
			wide * 0.14, Color(1.0, 1.0, 1.0, 0.28), false, false)

## A toadstool: a pale stem under a red cap with two spots.
func _toad(b: Face.Builder, at: Vector2, r: float) -> void:
	b.polygon(Face.Builder.round_rect(at + Vector2(-0.3, -0.2) * r, Vector2(0.6, 1.2) * r, 0.24 * r), TOAD_STEM)
	var cap := PackedVector2Array()
	for p in Face.Builder.arc_points(at + Vector2(0.0, -0.1) * r, r, PI, TAU):
		cap.append(p)
	b.polygon(cap, TOAD)
	b.disc(at + Vector2(-0.4, -0.5) * r, 0.17 * r, PETAL)
	b.disc(at + Vector2(0.3, -0.62) * r, 0.13 * r, PETAL)

## A drop of dew catching the sun: a soft disc and a four-pointed glint.
func _glint(b: Face.Builder, at: Vector2, r: float) -> void:
	b.disc(at, r * 0.55, Color(1.0, 1.0, 1.0, 0.5))
	var pts := PackedVector2Array()
	for i in 8:
		pts.append(at + Vector2.from_angle(-PI * 0.5 + i * PI * 0.25) * (r if i % 2 == 0 else r * 0.28))
	b.polygon(pts, Color(1.0, 1.0, 1.0, 0.9))
