extends Control

## Mini Golf's world: the course's park, edge to edge behind the board and
## the host's rows (CLAUDE.md: a game's world fills the screen). The morning
## air is cream across the top, where the wordmark and the win's words are
## ink, and turns into the mown lawn the card had just over the tools row;
## the lawn's stripes run down the whole of it and nothing else lies under
## the hole in play. In the gap of the tools row stand a small flag, a ball
## on its tee and a spare ball. Along the foot, measured up from the bottom
## edge so a taller screen keeps them there: a hedge, the course's toy
## windmill with its door, a bunker of sand, a bucket of balls, a putter
## and its bag, tufts and daisies.
##
## One mesh, built when the rect changes and kept (`_shown`) until the next
## replaces it; the windmill's sails are a second, on a child that sways
## (still under Motion.reduce). The colours are the palette's own GF_ ones
## and the parts ui/faces/minigolf_parts.gd's: the board is never loaded
## from here.

const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Face = preload("res://ui/faces/face.gd")
const CardFace = preload("res://ui/menu/cards/card_face.gd")
const Scenery = preload("res://ui/flat/scenery.gd")
const Parts = preload("res://ui/faces/minigolf_parts.gd")

## The screen the picture was drawn on; everything scales with the width.
const W := 1080.0
const AIR_TOP := Color("fdf8e8")
const AIR_LOW := Color("e6f0cf")
const LAWN_LOW := Color("b5d196")
## Where the air has become lawn, as a share of the height.
const LAWN_FROM := 0.262
const STRIPE := 96.0
const STRIPE_INK := Color(1.0, 1.0, 1.0, 0.07)
## The sun's middle, as shares of the rect, and its rings: [radius at W,
## alpha].
const SUN_AT := Vector2(0.10, 0.02)
const SUN_RINGS := [[640.0, 0.10], [440.0, 0.10], [270.0, 0.14]]
## The gap of the tools row: the flag's foot, the ball on its tee and the
## spare ball, as shares; the flag's height and the balls' radius at W.
const GAP_FLAG := Vector2(0.585, 0.247)
const GAP_FLAG_H := 46.0
const GAP_TEE := Vector2(0.415, 0.243)
const GAP_BALL := Vector2(0.478, 0.245)
const GAP_BALL_R := 10.0
## The windmill: its foot's middle in from the left and up from the bottom,
## its height and its foot's half width, all at W.
const MILL_AT := Vector2(150.0, 62.0)
const MILL_H := 150.0
const MILL_W := 54.0
const SAIL := 78.0
const MILL_WALL := Color("fbf1d8")
const MILL_SHADE := Color("e6d3ac")
const MILL_ROOF := Color("f0705a")
const MILL_ROOF_DEEP := Color("cc5140")
const MILL_DOOR := Color("96683f")
const SAIL_INK := Color("fffdf8")
const SAIL_RIB := Color("c9996a")
const SWAY := 5.6
const SWAY_BY := 0.5
## The hedge's bushes along the bottom edge: [x as a share, radius at W].
const HEDGE := [[0.02, 52.0], [0.30, 40.0], [0.40, 46.0], [0.985, 54.0], [0.60, 38.0]]
const BAG := Color("7fa8d8")
const BAG_DEEP := Color("5d87ba")
const BAG_TRIM := Color("fbf1d8")
const BUCKET := Color("f6b25e")
const BUCKET_DEEP := Color("d08a37")
const STEEL := Color("cfd6dc")
const STEEL_DEEP := Color("9aa6b0")

var _shown: ArrayMesh
var _sails: Control
var _sails_shown: ArrayMesh
var _sway: Tween

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sails = Control.new()
	_sails.name = "Sails"
	_sails.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sails.draw.connect(func() -> void:
		if _sails_shown != null:
			_sails.draw_mesh(_sails_shown, null))
	add_child(_sails)
	resized.connect(_build)
	_build()
	_sails.rotation = -SWAY_BY
	_sway = Motion.pulse(_sails, "rotation", -SWAY_BY, SWAY_BY, SWAY)

func _draw() -> void:
	if _shown != null:
		draw_mesh(_shown, null)

func _build() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var u := size.x / W
	var b := Face.Builder.new()
	var split := size.y * LAWN_FROM
	# The air, cream at the top and the lawn's own green by the tools row.
	var first := b.verts.size()
	b.polygon(PackedVector2Array([Vector2(-8.0, -8.0), Vector2(size.x + 8.0, -8.0),
		Vector2(size.x + 8.0, split), Vector2(-8.0, split)]), Color.WHITE)
	CardFace.shade(b, first, AIR_TOP, AIR_LOW, 0.0, size.y * 0.17)
	first = b.verts.size()
	b.polygon(PackedVector2Array([Vector2(-8.0, size.y * 0.17), Vector2(size.x + 8.0, size.y * 0.17),
		Vector2(size.x + 8.0, split), Vector2(-8.0, split)]), Color.WHITE)
	CardFace.shade(b, first, AIR_LOW, Pal.GF_LAWN, size.y * 0.17, split)
	first = b.verts.size()
	b.polygon(PackedVector2Array([Vector2(-8.0, split), Vector2(size.x + 8.0, split),
		Vector2(size.x + 8.0, size.y + 8.0), Vector2(-8.0, size.y + 8.0)]), Color.WHITE)
	CardFace.shade(b, first, Pal.GF_LAWN, LAWN_LOW, split, size.y)
	var sun := SUN_AT * size
	for ring in SUN_RINGS:
		b.disc(sun, ring[0] * u, Color(Pal.SUN_RAY, ring[1]))
	# The mown stripes, down the whole lawn.
	var x0 := 0.0
	var k := 0
	while x0 < size.x:
		if k % 2 == 0:
			var x1 := minf(x0 + STRIPE * u, size.x)
			b.fan(PackedVector2Array([Vector2(x0, split), Vector2(x1, split),
				Vector2(x1, size.y), Vector2(x0, size.y)]), STRIPE_INK)
		x0 += STRIPE * u
		k += 1
	# The gap of the tools row: a flag, a ball on its tee, a spare ball.
	var r := GAP_BALL_R * u
	var tee := GAP_TEE * size
	b.fan(PackedVector2Array([tee + Vector2(-r * 0.5, -r * 0.5), tee + Vector2(r * 0.5, -r * 0.5),
		tee + Vector2(r * 0.14, r * 1.1), tee + Vector2(-r * 0.14, r * 1.1)]), Pal.GF_FLAG)
	Parts.ball(b, tee + Vector2(0.0, -r * 1.2), r)
	Parts.ball(b, GAP_BALL * size, r * 0.9)
	Parts.flag(b, GAP_FLAG * size, GAP_FLAG_H * u, 0.6)
	_foot(b, u)
	_shown = b.mesh()
	queue_redraw()
	# The sails, about the hub.
	var sb := Face.Builder.new()
	var len := SAIL * u
	for i in 4:
		var dir := Vector2.from_angle(float(i) * PI * 0.5)
		var side := dir.orthogonal()
		sb.stroke(PackedVector2Array([Vector2.ZERO, dir * len]), 5.0 * u, SAIL_RIB)
		sb.fan(PackedVector2Array([dir * len * 0.26 + side * 2.0 * u, dir * len + side * 2.0 * u,
			dir * len + side * len * 0.34, dir * len * 0.26 + side * len * 0.30]), SAIL_INK)
		for j in 3:
			var at := lerpf(0.42, 0.86, float(j) / 2.0)
			sb.stroke(PackedVector2Array([dir * len * at + side * 2.0 * u, dir * len * at + side * len * 0.31]),
				2.0 * u, Color(SAIL_RIB, 0.55), false, false)
	sb.disc(Vector2.ZERO, 9.0 * u, MILL_ROOF_DEEP)
	sb.disc(Vector2.ZERO, 5.0 * u, Pal.GF_POST_HI)
	_sails_shown = sb.mesh()
	_sails.position = _hub(u)
	_sails.queue_redraw()

## The windmill's hub, where the sails turn.
func _hub(u: float) -> Vector2:
	return Vector2(MILL_AT.x * u, size.y - (MILL_AT.y + MILL_H * 0.80) * u)

## Everything along the foot, measured up from the bottom edge.
func _foot(b: Face.Builder, u: float) -> void:
	var base := size.y
	# A bunker of sand and tufts round it.
	var sand := Vector2(size.x * 0.52, base - 76.0 * u)
	b.ellipse(sand + Vector2(0.0, 5.0 * u), 104.0 * u, 34.0 * u, Pal.GF_SAND_DEEP)
	b.ellipse(sand, 100.0 * u, 30.0 * u, Pal.GF_SAND)
	for g: Vector2 in [Vector2(-52.0, -6.0), Vector2(-14.0, 9.0), Vector2(30.0, -10.0), Vector2(62.0, 6.0)]:
		b.disc(sand + g * u, 2.6 * u, Pal.GF_SAND_DEEP)
	Parts.ball(b, sand + Vector2(18.0, 2.0) * u, 11.0 * u)
	# The hedge along the very edge.
	for i in HEDGE.size():
		Parts.bush(b, Vector2(float(HEDGE[i][0]) * size.x, base - float(HEDGE[i][1]) * 0.35 * u), float(HEDGE[i][1]) * u, i)
	# The windmill: its tower, its door and its cap.
	var foot := Vector2(MILL_AT.x * u, base - MILL_AT.y * u)
	var h := MILL_H * u
	var w := MILL_W * u
	Scenery.soft_disc(b, foot + Vector2(10.0 * u, 2.0 * u), w * 1.5, 12.0 * u, Color(0.08, 0.2, 0.1, 0.22))
	var top := foot - Vector2(0.0, h * 0.72)
	b.polygon(PackedVector2Array([foot + Vector2(-w, 0.0), foot + Vector2(w, 0.0),
		top + Vector2(w * 0.62, 0.0), top + Vector2(-w * 0.62, 0.0)]), MILL_WALL)
	b.polygon(PackedVector2Array([foot + Vector2(w * 0.35, 0.0), foot + Vector2(w, 0.0),
		top + Vector2(w * 0.62, 0.0), top + Vector2(w * 0.22, 0.0)]), MILL_SHADE)
	for band in 2:
		var y := lerpf(0.30, 0.62, float(band))
		var half := lerpf(w, w * 0.62, y)
		b.stroke(PackedVector2Array([foot + Vector2(-half, -h * 0.72 * y), foot + Vector2(half, -h * 0.72 * y)]),
			5.0 * u, Color(MILL_ROOF, 0.55), false, false)
	var door := Face.Builder.round_rect(foot + Vector2(-w * 0.32, -h * 0.30), Vector2(w * 0.64, h * 0.30 + 2.0 * u), w * 0.3)
	b.polygon(door, MILL_DOOR)
	b.disc(foot + Vector2(w * 0.16, -h * 0.13), 2.6 * u, Pal.GF_POST_HI)
	b.polygon(PackedVector2Array([top + Vector2(-w * 0.80, 2.0 * u), top + Vector2(w * 0.80, 2.0 * u),
		top + Vector2(0.0, -h * 0.30)]), MILL_ROOF)
	b.polygon(PackedVector2Array([top + Vector2(w * 0.12, 2.0 * u), top + Vector2(w * 0.80, 2.0 * u),
		top + Vector2(0.0, -h * 0.30)]), MILL_ROOF_DEEP)
	# A bucket of balls.
	var bucket := Vector2(size.x * 0.715, base - 58.0 * u)
	Scenery.soft_disc(b, bucket + Vector2(6.0 * u, 26.0 * u), 40.0 * u, 9.0 * u, Color(0.08, 0.2, 0.1, 0.2))
	for at: Vector2 in [Vector2(-14.0, -30.0), Vector2(8.0, -34.0), Vector2(-2.0, -24.0)]:
		Parts.ball(b, bucket + at * u, 11.0 * u, 0.6)
	b.polygon(PackedVector2Array([bucket + Vector2(-30.0, -24.0) * u, bucket + Vector2(30.0, -24.0) * u,
		bucket + Vector2(22.0, 26.0) * u, bucket + Vector2(-22.0, 26.0) * u]), BUCKET)
	b.polygon(PackedVector2Array([bucket + Vector2(10.0, -24.0) * u, bucket + Vector2(30.0, -24.0) * u,
		bucket + Vector2(22.0, 26.0) * u, bucket + Vector2(8.0, 26.0) * u]), BUCKET_DEEP)
	b.stroke(PackedVector2Array([bucket + Vector2(-31.0, -24.0) * u, bucket + Vector2(31.0, -24.0) * u]), 6.0 * u, Pal.GF_POST_HI)
	Parts.ball(b, bucket + Vector2(52.0, 20.0) * u, 11.0 * u)
	# The bag, leant, and a putter beside it.
	var bag := Vector2(size.x * 0.875, base - 48.0 * u)
	Scenery.soft_disc(b, bag + Vector2(8.0 * u, 20.0 * u), 46.0 * u, 10.0 * u, Color(0.08, 0.2, 0.1, 0.2))
	var lean := Transform2D(0.16, bag)
	for c: Vector2 in [Vector2(-10.0, -128.0), Vector2(8.0, -140.0)]:
		b.stroke(PackedVector2Array([lean * (Vector2(c.x, -70.0) * u), lean * (c * u)]), 4.0 * u, STEEL_DEEP)
		b.ellipse(lean * (c * u), 9.0 * u, 6.0 * u, STEEL)
	b.polygon(_turn(lean, Face.Builder.round_rect(Vector2(-24.0, -96.0) * u, Vector2(48.0, 118.0) * u, 16.0 * u)), BAG_DEEP)
	b.polygon(_turn(lean, Face.Builder.round_rect(Vector2(-24.0, -96.0) * u, Vector2(38.0, 118.0) * u, 16.0 * u)), BAG)
	b.stroke(PackedVector2Array([lean * (Vector2(-23.0, -78.0) * u), lean * (Vector2(23.0, -78.0) * u)]), 7.0 * u, BAG_TRIM, false, false)
	b.polygon(_turn(lean, Face.Builder.round_rect(Vector2(-14.0, -44.0) * u, Vector2(24.0, 34.0) * u, 8.0 * u)), BAG_DEEP)
	var grip := Vector2(size.x * 0.955, base - 150.0 * u)
	var head := Vector2(size.x * 0.935, base - 30.0 * u)
	b.stroke(PackedVector2Array([grip, head]), 4.0 * u, STEEL_DEEP)
	b.stroke(PackedVector2Array([grip, grip.lerp(head, 0.26)]), 7.0 * u, Pal.GF_KERB_DEEP)
	b.stroke(PackedVector2Array([head, head + Vector2(-24.0, 3.0) * u]), 9.0 * u, STEEL)
	# Tufts and daisies between them.
	for t: Vector2 in [Vector2(0.245, 34.0), Vector2(0.355, 96.0), Vector2(0.455, 22.0), Vector2(0.63, 28.0),
			Vector2(0.775, 100.0), Vector2(0.81, 22.0), Vector2(0.09, 26.0)]:
		Parts.tuft(b, Vector2(t.x * size.x, base - t.y * u), 22.0 * u)
	for d: Vector2 in [Vector2(0.225, 70.0), Vector2(0.325, 30.0), Vector2(0.66, 108.0), Vector2(0.79, 54.0)]:
		Parts.daisy(b, Vector2(d.x * size.x, base - d.y * u), 9.0 * u)
	Parts.daisy(b, Vector2(0.575 * size.x, base - 24.0 * u), 8.0 * u, Pal.FLOWER)

func _turn(xf: Transform2D, pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(xf * p)
	return out
