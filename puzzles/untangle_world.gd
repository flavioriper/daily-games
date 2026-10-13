extends Control

## Untangle's world: a piece of linen on the sewing table, edge to edge
## under the hoop and the host's rows (CLAUDE.md: a game's world fills the
## screen). It is the menu card's picture (ui/menu/cards/untangle.gd) at the
## size of the screen: the cloth pale at the top, where the wordmark, the
## motto and the win's words are ink, with the window's light on its upper
## right; a line of running stitch and one small flower in the gap of the
## tools row; a sprig in each lower corner of the hoop's square; and, in
## the open foot, the things left beside the work -- a ball of the board's
## rope with its loose end run through a needle, two spare pegs, a stitched
## sprig and the hem.
##
## Nothing lies where the hoop does but the weave, which is faint: the ropes
## have to read (and the board lays its own taut linen inside the hoop).
##
## One mesh, built when the rect changes and kept (`_shown`) until the next
## replaces it; the motes of dust in the light are a second, on a child
## whose alpha breathes (still under Motion.reduce).
##
## The colours are the board's (untangle2d.gd), written again here: the
## board preloads this file, so this one cannot preload the board.

const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Face = preload("res://ui/faces/face.gd")
const CardFace = preload("res://ui/menu/cards/card_face.gd")
const Scenery = preload("res://ui/flat/scenery.gd")
const Rewards = preload("res://arcade/rewards.gd")

## The screen the picture was drawn on; everything scales with the width.
const W := 1080.0
const LINEN_TOP := Color("f9f1df")
const LINEN_LOW := Color("eedfc2")
const WEAVE := Color("b99a63")
const LIGHT := Color("fffaf0")
const CLOTH_LEAF := Color("a9b98d")
const CLOTH_LEAF_DEEP := Color("859a6c")
const CLOTH_PETAL := Color("f7eedb")
const CLOTH_PETAL_DEEP := Color("dcc9a4")
const CLOTH_GOLD := Color("e8b84a")
const CLOTH_BERRY := Color("98a6c4")
const CAP := Color("d7a56e")
const CAP_SIDE := Color("b98552")
const CAP_DEEP := Color("8d6034")
const CAP_HI := Color("f2d5a9")
## The ball of rope and the spare pegs' inlays: [fill, deep edge, pale strip].
const YARN := [Color("f08f7a"), Color("bd5b48"), Color("ffc9ba")]
const INLAYS := [
	[Color("86bfe8"), Color("4f8bb8"), Color("c8e6fb")],
	[Color("f7d766"), Color("c99d2c"), Color("fff0a8")],
]
const NEEDLE := Color("c9bda6")
const NEEDLE_HI := Color("f4eee0")

## The weave: a thread every this many pixels at W, each way.
const WEAVE_STEP := 30.0
const WEAVE_ALPHA := 0.035
## The window's light on the upper right: its middle as shares of the rect,
## and its rings as [radius at W, alpha].
const LIGHT_AT := Vector2(0.94, 0.03)
const LIGHT_RINGS := [[760.0, 0.16], [520.0, 0.18], [300.0, 0.22]]
## The running stitch in the gap of the tools row, between the bin and
## Hint: from, the pull of its sag, to, as shares; and the flower on it.
const SEAM_FROM := Vector2(0.300, 0.226)
const SEAM_SAG := Vector2(0.560, 0.250)
const SEAM_TO := Vector2(0.820, 0.226)
const SEAM_FLOWER := [0.560, 0.236, 20.0]
## The sprigs: [x, y as shares, radius at W, tilt, side]. Two in the lower
## corners of the hoop's square, one large in the foot.
const SPRIGS := [
	[0.068, 0.806, 26.0, 0.5, 1.0],
	[0.932, 0.806, 26.0, PI - 0.5, -1.0],
	[0.090, 0.944, 44.0, 0.2, 1.0],
]
## The ball of rope in the foot: its middle as shares, its radius at W.
const BALL_AT := Vector2(0.850, 0.938)
const BALL_R := 56.0
## Its loose end: two bends as shares, to the needle's eye.
const TAIL_C0 := Vector2(0.720, 0.990)
const TAIL_C1 := Vector2(0.640, 0.905)
## The needle: its eye and its point as shares.
const NEEDLE_EYE := Vector2(0.560, 0.952)
const NEEDLE_TIP := Vector2(0.445, 0.928)
## The spare pegs: [x, y as shares, radius at W].
const PEGS := [[0.285, 0.950, 30.0], [0.352, 0.932, 30.0]]
## The hem: how far over the foot it runs, at W.
const HEM_UP := 30.0
## The dust in the light: [x, y as shares, radius at W, alpha].
const MOTES := [
	[0.700, 0.900, 9.0, 0.55], [0.930, 0.870, 7.0, 0.45], [0.500, 0.975, 6.0, 0.4],
	[0.210, 0.890, 7.0, 0.45], [0.640, 0.238, 6.0, 0.4], [0.400, 0.212, 5.0, 0.35],
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
	# The linen under everything.
	var first := b.verts.size()
	b.polygon(PackedVector2Array([Vector2(-8.0, -8.0), Vector2(size.x + 8.0, -8.0),
		Vector2(size.x + 8.0, size.y + 8.0), Vector2(-8.0, size.y + 8.0)]), Color.WHITE)
	CardFace.shade(b, first, LINEN_TOP, LINEN_LOW, 0.0, size.y)
	# The window's light, then the weave over it.
	var light := LIGHT_AT * size
	for ring in LIGHT_RINGS:
		b.disc(light, ring[0] * u, Color(LIGHT, ring[1]))
	var step := WEAVE_STEP * u
	var y := step * 0.5
	while y < size.y:
		b.stroke(PackedVector2Array([Vector2(0.0, y), Vector2(size.x, y)]), 2.0 * u, Color(WEAVE, WEAVE_ALPHA), false, false)
		y += step
	var x := step * 0.5
	while x < size.x:
		b.stroke(PackedVector2Array([Vector2(x, 0.0), Vector2(x, size.y)]), 2.0 * u, Color(WEAVE, WEAVE_ALPHA), false, false)
		x += step
	# The running stitch in the gap of the tools row, and its flower.
	var seam := Face.Builder.bezier2(SEAM_FROM * size, SEAM_SAG * size, SEAM_TO * size, 30)
	seam.append(SEAM_TO * size)
	_running(b, seam, 5.0 * u, Color(CLOTH_GOLD, 0.55))
	_flower(b, Vector2(SEAM_FLOWER[0], SEAM_FLOWER[1]) * size, SEAM_FLOWER[2] * u, 0.3)
	for s in SPRIGS:
		_sprig(b, Vector2(s[0], s[1]) * size, s[2] * u, s[3], s[4], u)
	# The hem along the foot.
	var hem_y := size.y - HEM_UP * u
	_running(b, PackedVector2Array([Vector2(40.0 * u, hem_y), Vector2(size.x - 40.0 * u, hem_y)]), 5.0 * u, Color(CLOTH_GOLD, 0.5))
	for i in PEGS.size():
		_peg(b, Vector2(PEGS[i][0], PEGS[i][1]) * size, PEGS[i][2] * u, INLAYS[i % INLAYS.size()])
	_needle_and_ball(b, u)
	_shown = b.mesh()
	queue_redraw()
	var mb := Face.Builder.new()
	for m in MOTES:
		var r: float = m[2] * u
		Scenery.soft_disc(mb, Vector2(m[0], m[1]) * size, r, r, Color(LIGHT, m[3]))
	_motes_shown = mb.mesh()
	_motes.size = size
	_motes.queue_redraw()

## A running stitch along `line`: a dash of 22 and a gap of 16 at W.
func _running(b: Face.Builder, line: PackedVector2Array, width: float, ink: Color) -> void:
	var u := size.x / W
	var dash := 22.0 * u
	var gap := 16.0 * u
	var run := PackedVector2Array()
	var left := dash
	var drawing := true
	for i in range(1, line.size()):
		var a := line[i - 1]
		var seg := line[i] - a
		var length := seg.length()
		if length <= 0.0:
			continue
		var dir := seg / length
		var at := 0.0
		if drawing and run.is_empty():
			run.append(a)
		while length - at > left:
			at += left
			if drawing:
				run.append(a + dir * at)
				b.stroke(run, width, ink, false, true)
				run = PackedVector2Array()
				left = gap
			else:
				run = PackedVector2Array([a + dir * at])
				left = dash
			drawing = not drawing
		left -= length - at
		if drawing:
			run.append(line[i])
	if drawing and run.size() >= 2:
		b.stroke(run, width, ink, false, true)

## A stitched flower of six petals at `at`.
func _flower(b: Face.Builder, at: Vector2, r: float, tilt: float) -> void:
	for k in 6:
		var a := TAU * k / 6.0 + tilt
		Rewards.petal(b, at + Vector2.from_angle(a) * r * 0.5, r * 0.5, r * 0.28, a, CLOTH_PETAL_DEEP)
	for k in 6:
		var a := TAU * k / 6.0 + tilt
		Rewards.petal(b, at + Vector2.from_angle(a) * r * 0.48 + Vector2(-0.03, -0.04) * r, r * 0.46, r * 0.24, a, CLOTH_PETAL)
	b.disc(at, r * 0.28, CLOTH_GOLD)
	b.disc(at + Vector2(-r * 0.06, -r * 0.08), r * 0.1, Color("f9dc8a"))

## A flower with two leaves and three berries, as the board stitched them
## in its cloth's corners.
func _sprig(b: Face.Builder, at: Vector2, r: float, tilt: float, side: float, u: float) -> void:
	for k in 2:
		var a := tilt + side * (0.55 + 0.9 * k)
		Rewards.petal(b, at + Vector2.from_angle(a) * r * 1.35, r * 0.78, r * 0.3, a, CLOTH_LEAF)
		b.stroke(PackedVector2Array([at + Vector2.from_angle(a) * r * 0.7, at + Vector2.from_angle(a) * r * 1.9]),
			2.4 * u, CLOTH_LEAF_DEEP, false, false)
	_flower(b, at, r, tilt)
	for k in 3:
		var d := at + Vector2(side * (r * 1.6 + k * r * 0.34), -r * 0.9 - k * r * 0.14)
		b.disc(d, r * 0.17, CLOTH_BERRY)
		b.disc(d + Vector2(-0.05, -0.05) * r, r * 0.05, Color(1, 1, 1, 0.7))

## A peg lying on the cloth, as the board draws one at rest: its soft
## shadow, the cap, and an inlay.
func _peg(b: Face.Builder, at: Vector2, r: float, col: Array) -> void:
	Scenery.soft_disc(b, at + Vector2(0.1, 0.26) * r, r * 1.02, r * 0.66, Color(Pal.TEXT, 0.22))
	b.ellipse(at + Vector2(0.0, r * 0.1), r, r, CAP_DEEP)
	b.ellipse(at, r * 0.97, r * 0.97, CAP_SIDE)
	b.ellipse(at + Vector2(0.0, -r * 0.06), r * 0.8, r * 0.78, CAP)
	b.ellipse(at + Vector2(-0.27, -0.32) * r, r * 0.27, r * 0.19, Color(CAP_HI, 0.85))
	b.disc(at + Vector2(0.0, -r * 0.06), r * 0.4, col[1])
	b.disc(at + Vector2(0.0, -r * 0.08), r * 0.32, col[0])
	b.disc(at + Vector2(-0.1, -0.16) * r, r * 0.1, Color(col[2], 0.9))

## The ball of rope, its loose end wandering over the cloth and through the
## eye of the needle left beside it.
func _needle_and_ball(b: Face.Builder, u: float) -> void:
	var at := BALL_AT * size
	var r := BALL_R * u
	var eye := NEEDLE_EYE * size
	var tip := NEEDLE_TIP * size
	var along := (tip - eye).normalized()
	# The needle: its shadow, the steel, the light along it, the eye.
	var shaft := PackedVector2Array([eye - along * 14.0 * u, tip])
	b.stroke(PackedVector2Array([shaft[0] + Vector2(2.0, 5.0) * u, tip + Vector2(2.0, 5.0) * u]), 8.0 * u, Color(Pal.TEXT, 0.10), false, true)
	b.stroke(shaft, 7.0 * u, NEEDLE, false, true)
	b.stroke(PackedVector2Array([eye + along * 10.0 * u - Vector2(0.0, 1.5 * u), tip - along * 12.0 * u - Vector2(0.0, 1.5 * u)]),
		2.2 * u, Color(NEEDLE_HI, 0.9), false, true)
	b.stroke(PackedVector2Array([eye - along * 6.0 * u, eye + along * 5.0 * u]), 2.6 * u, LINEN_LOW, false, true)
	# The loose end, from the ball to the eye and a little way past it.
	var tail := Face.Builder.bezier3(at + Vector2(-0.70, 0.55) * r, TAIL_C0 * size, TAIL_C1 * size, eye, 26)
	tail.append(eye)
	tail.append(eye + Vector2(-26.0, 30.0) * u)
	b.stroke(tail, 9.0 * u, Color(Pal.TEXT, 0.06), false, true)
	b.stroke(tail, 7.0 * u, YARN[1], false, true)
	b.stroke(tail, 4.2 * u, YARN[0], false, true)
	# The ball: its shadow, the wound rope, three turns of it, the light.
	Scenery.soft_disc(b, at + Vector2(r * 0.12, r * 0.9), r * 1.15, r * 0.36, Color(Pal.TEXT, 0.18))
	b.disc(at, r, YARN[1])
	b.disc(at + Vector2(-0.03, -0.05) * r, r * 0.93, YARN[0])
	for k in 3:
		var a0 := 0.5 + k * 1.05
		b.stroke(Face.Builder.arc_points(at + Vector2.from_angle(a0 + 2.2) * r * 0.5, r * 0.85, a0, a0 + 1.4), 3.4 * u, Color(YARN[1], 0.75), false, false)
	b.disc(at + Vector2(-0.34, -0.38) * r, r * 0.2, Color(YARN[2], 0.8))
