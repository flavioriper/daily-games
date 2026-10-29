extends Control

## Pinwheel's world: a breezy primrose hill, edge to edge under the board and
## the host's rows (CLAUDE.md: a game's world fills the screen). It is the
## menu card's picture (ui/menu/cards/pinwheel.gd) at the size of the screen:
## the primrose paper going to butter, the sun's soft rings behind the
## wordmark, a cloud and a small kite in the gap of the tools row, and along
## the foot the card's two rises with toy pinwheels stood in them on their
## sticks, a few scraps of the pieces' cloth and some grass (a level whose
## frame comes down to the foot keeps the rises and the grass alone). Nothing lies
## under the frame but the paper.
##
## The frame is tall and differs per level, so the board says where its foot
## is (`set_foot`) and the rises and the toys are sized to the band that is
## left under it.
##
## One mesh, built when the rect or the foot changes and kept (`_shown`)
## until the next replaces it; the largest toy's wheel is a second, on a
## child that sways (still under Motion.reduce). Nothing here has a face.
## The colours are written here: the board preloads this file.

const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Face = preload("res://ui/faces/face.gd")
const CardFace = preload("res://ui/menu/cards/card_face.gd")
const Scenery = preload("res://ui/flat/scenery.gd")
const Cloth = preload("res://ui/faces/patch_cloth.gd")
const PinWheel = preload("res://ui/faces/pin_wheel.gd")

## The screen the picture was drawn on; everything scales with the width.
const W := 1080.0
const PAPER_TOP := Color("fdf7dc")
const PAPER_LOW := Color("f9e9ab")
const RISE := Color("f4dd92")
const RISE_FAR := Color("f7e4a2")
const STICK := Color("c9a56a")
const CLOUD := Color("fffbee")
const SUN_AT := Vector2(0.10, 0.02)
const SUN_RINGS := [[640.0, 0.10], [440.0, 0.10], [270.0, 0.14]]
## The gap of the tools row: a cloud [x, y as shares, radius at W] and a
## small kite [x, y, half height at W, lean].
const GAP_CLOUD := [0.455, 0.234, 26.0]
const GAP_KITE := [0.665, 0.229, 24.0, 0.42]
## The band the foot was drawn for, at W; a shallower one shrinks it.
const BAND := 300.0
const BAND_MIN := 0.42
## Under this much open foot (at W) the toys and the scraps are left out:
## they would stand behind the frame with only their sticks' ends showing.
const TOYS_FROM := 150.0
## The toys: [x as a share, how high the hub stands over the bottom edge at
## W, radius at W, cloth, lean]. The first is the one that sways.
const TOYS := [
	[0.840, 212.0, 62.0, 2, 0.30],
	[0.105, 176.0, 50.0, 4, -0.20],
	[0.270, 118.0, 34.0, 1, 0.55],
	[0.615, 126.0, 36.0, 0, 0.10],
	[0.955, 110.0, 30.0, 3, -0.40],
]
## Scraps of cloth in the grass: [x, height over the bottom at W, side at W,
## cloth, turn].
const SCRAPS := [
	[0.405, 52.0, 44.0, 3, 0.22], [0.470, 40.0, 36.0, 0, -0.30], [0.735, 46.0, 40.0, 1, 0.12],
]
## Tufts: [x, height over the bottom at W, blade height at W].
const TUFTS := [
	[0.040, 70.0, 26.0], [0.190, 96.0, 22.0], [0.345, 78.0, 24.0], [0.545, 84.0, 22.0],
	[0.690, 92.0, 24.0], [0.900, 86.0, 26.0],
]
const SWAY := 0.9
const SWAY_TIME := 5.2

var _foot := -1.0
var _shown: ArrayMesh
var _wheel: Control
var _wheel_shown: ArrayMesh
var _sway: Tween

## Whether the tools row's gap holds its cloud and kite: the board's count
## pill stands there since 2026-10-29, and turns them off.
var gap := true

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wheel = Control.new()
	_wheel.name = "Wheel"
	_wheel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wheel.draw.connect(func() -> void:
		if _wheel_shown != null:
			_wheel.draw_mesh(_wheel_shown, null))
	add_child(_wheel)
	resized.connect(_build)
	_build()
	_sway = Motion.pulse(_wheel, "rotation", 0.0, SWAY, SWAY_TIME)

## Where the board's frame ends, in this rect's pixels: the foot's things
## are sized to what is left under it. Built again only when it moves.
func set_foot(y: float) -> void:
	if absf(y - _foot) < 0.5:
		return
	_foot = y
	_build()

func _draw() -> void:
	if _shown != null:
		draw_mesh(_shown, null)

## How big the foot's things are: 1 in the band they were drawn for.
func _band() -> float:
	var u := size.x / W
	if _foot < 0.0:
		return 1.0
	return clampf((size.y - _foot) / (BAND * u), BAND_MIN, 1.0)

func _build() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var u := size.x / W
	var k := _band() * u
	var b := Face.Builder.new()
	var first := b.verts.size()
	b.polygon(PackedVector2Array([Vector2(-8.0, -8.0), Vector2(size.x + 8.0, -8.0),
		Vector2(size.x + 8.0, size.y + 8.0), Vector2(-8.0, size.y + 8.0)]), Color.WHITE)
	CardFace.shade(b, first, PAPER_TOP, PAPER_LOW, 0.0, size.y)
	var sun := SUN_AT * size
	for ring in SUN_RINGS:
		b.disc(sun, ring[0] * u, Color(Pal.SUN_RAY, ring[1]))
	# The gap of the tools row: a cloud, and a kite with its tail.
	if gap:
		Scenery.cloud(b, Vector2(GAP_CLOUD[0], GAP_CLOUD[1]) * size, GAP_CLOUD[2] * u, CLOUD)
		_kite(b, Vector2(GAP_KITE[0], GAP_KITE[1]) * size, GAP_KITE[2] * u, GAP_KITE[3])
	# The rises along the foot, the far one first.
	b.ellipse(Vector2(size.x * 0.70, size.y + 40.0 * k), size.x * 0.62, 190.0 * k, RISE_FAR)
	b.ellipse(Vector2(size.x * 0.16, size.y + 46.0 * k), size.x * 0.52, 200.0 * k, RISE)
	b.ellipse(Vector2(size.x * 1.02, size.y + 60.0 * k), size.x * 0.34, 170.0 * k, RISE)
	for t in TUFTS:
		Scenery.tuft(b, Vector2(t[0] * size.x, size.y - t[1] * k), t[2] * k)
	var toys := _foot < 0.0 or size.y - _foot >= TOYS_FROM * u
	for s in (SCRAPS if toys else []):
		_scrap(b, Vector2(s[0] * size.x, size.y - s[1] * k), s[2] * k, int(s[3]), s[4])
	# The toys on their sticks; the first one's wheel is the child's.
	for i in (TOYS.size() if toys else 0):
		var toy: Array = TOYS[i]
		var hub := Vector2(toy[0] * size.x, size.y - toy[1] * k)
		var r: float = toy[2] * k
		b.stroke(PackedVector2Array([hub, Vector2(hub.x + r * 0.16, size.y - toy[1] * k * 0.12)]), maxf(3.0, r * 0.15), STICK)
		Scenery.soft_disc(b, hub + Vector2(0.06, 0.16) * r, r, r, Color(Pal.TEXT, 0.07))
		if i > 0:
			PinWheel.wheel(b, hub, r, toy[4], Pal.LINE, Pal.SURFACE, PinWheel.BRASS, Cloth.cloth(int(toy[3])))
	_shown = b.mesh()
	queue_redraw()
	var lead: Array = TOYS[0]
	var wb := Face.Builder.new()
	PinWheel.wheel(wb, Vector2.ZERO, lead[2] * k, lead[4], Pal.LINE, Pal.SURFACE, PinWheel.BRASS, Cloth.cloth(int(lead[3])))
	_wheel_shown = wb.mesh()
	_wheel.position = Vector2(lead[0] * size.x, size.y - lead[1] * k)
	_wheel.size = Vector2.ZERO
	_wheel.visible = toys
	_wheel.queue_redraw()

## A small paper kite of half height `h`, leaning `lean`, and its tail: a
## thread hanging off its foot with three bows on it.
func _kite(b: Face.Builder, at: Vector2, h: float, lean: float) -> void:
	var up := Vector2.UP.rotated(lean)
	var side := up.orthogonal()
	var top := at + up * h
	var foot := at - up * h * 1.15
	var left := at + side * h * 0.7
	var right := at - side * h * 0.7
	var tail := Face.Builder.bezier3(foot, foot + Vector2(-0.3, 0.9) * h, foot + Vector2(0.9, 1.3) * h,
		foot + Vector2(0.5, 2.3) * h, 14)
	b.stroke(tail, maxf(1.5, h * 0.07), Color(STICK, 0.85), false, false)
	for i in [4, 8, 12]:
		var p := tail[i]
		for s in [-1.0, 1.0]:
			b.polygon(PackedVector2Array([p, p + Vector2(s * 0.30, -0.16) * h, p + Vector2(s * 0.30, 0.16) * h]),
				Cloth.cloth(4 if i == 8 else 1))
	b.polygon(PackedVector2Array([top, left, at]), Cloth.cloth(2))
	b.polygon(PackedVector2Array([top, at, right]), Cloth.cloth_deep(2))
	b.polygon(PackedVector2Array([left, foot, at]), Cloth.cloth_deep(2))
	b.polygon(PackedVector2Array([at, foot, right]), Cloth.cloth(2))
	b.stroke(PackedVector2Array([top, left, foot, right]), maxf(1.5, h * 0.07), Cloth.cloth_stitch(2), true)

## A scrap of a piece's cloth lying in the grass: a rounded square with its
## lip under it and a stitch inside its edge.
func _scrap(b: Face.Builder, at: Vector2, side: float, cloth: int, turn: float) -> void:
	var xf := Transform2D(turn, at)
	var box := Face.Builder.round_rect(-Vector2.ONE * side * 0.5, Vector2.ONE * side, side * 0.2)
	b.polygon(Transform2D(turn, at + Vector2(0.0, side * 0.09)) * box, Cloth.cloth_deep(cloth))
	b.polygon(xf * box, Cloth.cloth(cloth))
	b.stroke(xf * Face.Builder.round_rect(-Vector2.ONE * side * 0.34, Vector2.ONE * side * 0.68, side * 0.12),
		maxf(1.5, side * 0.045), Color(Cloth.cloth_stitch(cloth), 0.55), true)
