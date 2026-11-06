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
## On a themed day (the daily theme, 2026-11-06) the windmill gives its
## place to the day's thing clipped as a topiary in a wooden planter
## (`set_picture`): a hedge in the thing's outline, which each cup sunk paints
## a band of in the picture's beads from the bottom up (`reveal`), whole
## when the last ball drops. A themed course is themed by its centrepiece,
## as a real one is; nothing under the hole in play changes.
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
const ThemedPictures = preload("res://core/themed_pictures.gd")

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
## The topiary (a themed day's): the picture's cells (Vector2i -> Color),
## its size in squares, its own Control and mesh, and how many rows from
## the bottom wear their beads (a float while a band paints in).
var _pic: Dictionary = {}
var _pic_size := Vector2i.ZERO
var _topiary: Control
var _topiary_shown: ArrayMesh
var _shown_rows := 0.0
var _paint_tw: Tween

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sails = Control.new()
	_sails.name = "Sails"
	_sails.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sails.draw.connect(func() -> void:
		if _sails_shown != null:
			_sails.draw_mesh(_sails_shown, null))
	add_child(_sails)
	_topiary = Control.new()
	_topiary.name = "Topiary"
	_topiary.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_topiary.draw.connect(func() -> void:
		if _topiary_shown != null:
			_topiary.draw_mesh(_topiary_shown, null))
	add_child(_topiary)
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
	_sails.visible = not themed()
	_sails.queue_redraw()
	# The topiary's Control spans the world: a Control is culled by its own
	# rect, and a zero one at the corner left the screen under the bump's
	# and the win slide's scale (the thing blinked out).
	_topiary.size = size
	_build_topiary()

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
	if themed():
		_planter(b, u)
		_foot_rest(b, u)
		return
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
	_foot_rest(b, u)

## The foot right of the windmill's (or the topiary's) place.
func _foot_rest(b: Face.Builder, u: float) -> void:
	var base := size.y
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

# --- the topiary (the daily theme, 2026-11-06) ---

## The topiary's picture box at W (its longer side), and the planter under
## it: its height and how far it stands out past the picture each side.
const TOPIARY := 170.0
const PLANTER_H := 30.0
const PLANTER_LIP := 10.0
## A band paints in over this long (instant under Motion.reduce).
const PAINT_TIME := 0.55
## The hedge's leaves: a disc a square under the squares rounds the outline.
const LEAF := 0.64

func themed() -> bool:
	return not _pic.is_empty()

## The day's picture (`rows` as the night writes them, letters by
## ThemedPictures.letters(); [] for a plain day, the windmill back).
func set_picture(rows: Array) -> void:
	_pic = {}
	_pic_size = Vector2i.ZERO
	var lo := Vector2i(1 << 20, 1 << 20)
	var hi := Vector2i(-1, -1)
	for y in rows.size():
		var row := String(rows[y])
		for x in row.length():
			if row[x] != ".":
				lo = Vector2i(mini(lo.x, x), mini(lo.y, y))
				hi = Vector2i(maxi(hi.x, x), maxi(hi.y, y))
	if hi.x >= 0:
		var letters := ThemedPictures.letters()
		for y in range(lo.y, hi.y + 1):
			var row := String(rows[y])
			for x in range(lo.x, mini(hi.x + 1, row.length())):
				if row[x] == ".":
					continue
				var bead = Pal.PG_BEADS.get(String(letters.get(row[x], row[x])))
				_pic[Vector2i(x, y) - lo] = bead if bead is Color else Pal.GF_BUSH
		_pic_size = hi - lo + Vector2i.ONE
	_shown_rows = 0.0
	Motion.stop(_paint_tw)
	_build()

## A share (0 to 1) of the topiary's rows wearing their beads, from the
## bottom; `paint`: the new rows come on one by one over PAINT_TIME.
func reveal(share: float, paint := false) -> void:
	if not themed():
		return
	var to := clampf(share, 0.0, 1.0) * float(_pic_size.y)
	Motion.stop(_paint_tw)
	if not paint or Motion.reduce or to <= _shown_rows or not is_inside_tree():
		_shown_rows = to
		_build_topiary()
		return
	_paint_tw = create_tween()
	_paint_tw.tween_method(func(v: float) -> void:
		_shown_rows = v
		_build_topiary(), _shown_rows, to, PAINT_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# The thing finished: a bump about its middle as the last row lands.
	if to >= float(_pic_size.y):
		_paint_tw.tween_callback(func() -> void:
			_topiary.pivot_offset = topiary_mid()
			Motion.bump(_topiary, 0.12, 0.4))

## Where the topiary stands: the middle of its foot, in this Control's
## pixels (the board's, unslid), for a sparkle.
func topiary_mid() -> Vector2:
	var u := size.x / W
	return Vector2(MILL_AT.x * u, size.y - (PLANTER_H + 16.0 + TOPIARY * 0.5) * u)

func _box(u: float) -> Rect2:
	var k := TOPIARY * u / float(maxi(_pic_size.x, _pic_size.y))
	var wh := Vector2(_pic_size) * k
	var foot := Vector2(MILL_AT.x * u, size.y - (PLANTER_H + 16.0) * u)
	return Rect2(foot - Vector2(wh.x * 0.5, wh.y), wh)

## The planter, in the world's still mesh: a wooden box in the kerb's
## colours, its shadow on the lawn.
func _planter(b: Face.Builder, u: float) -> void:
	var box := _box(u)
	var w := box.size.x * 0.5 + PLANTER_LIP * u
	var x := box.get_center().x
	var top := box.end.y - 4.0 * u
	var h := PLANTER_H * u
	Scenery.soft_disc(b, Vector2(x + 10.0 * u, top + h + 4.0 * u), w * 1.15, 12.0 * u, Color(0.08, 0.2, 0.1, 0.22))
	b.polygon(PackedVector2Array([Vector2(x - w, top), Vector2(x + w, top),
		Vector2(x + w * 0.86, top + h), Vector2(x - w * 0.86, top + h)]), Pal.GF_KERB)
	b.polygon(PackedVector2Array([Vector2(x + w * 0.4, top), Vector2(x + w, top),
		Vector2(x + w * 0.86, top + h), Vector2(x + w * 0.34, top + h)]), Pal.GF_KERB_DEEP)
	b.stroke(PackedVector2Array([Vector2(x - w - 2.0 * u, top), Vector2(x + w + 2.0 * u, top)]), 7.0 * u, Pal.GF_POST_HI)

## The topiary's own mesh: the hedge (a leaf disc under each square still
## green, so the outline is soft) and the squares, green or their bead.
func _build_topiary() -> void:
	if _topiary == null:
		return
	_topiary_shown = null
	if themed() and size.x > 0.0:
		var u := size.x / W
		var box := _box(u)
		var k := box.size.x / float(_pic_size.x)
		var tb := Face.Builder.new()
		var from := float(_pic_size.y) - _shown_rows
		for c: Vector2i in _pic:
			if float(c.y) + 0.5 < from:
				tb.disc(box.position + (Vector2(c) + Vector2(0.5, 0.62)) * k, k * LEAF, Pal.GF_BUSH_DEEP)
		for c: Vector2i in _pic:
			var at := box.position + Vector2(c) * k
			if float(c.y) + 0.5 < from:
				var hi := (c.x * 7 + c.y * 13) % 5 == 0
				tb.fan(PackedVector2Array([at, at + Vector2(k, 0.0), at + Vector2(k, k), at + Vector2(0.0, k)]),
					Pal.GF_BUSH_HI if hi else Pal.GF_BUSH)
			else:
				var col: Color = _pic[c]
				tb.fan(PackedVector2Array([at, at + Vector2(k, 0.0), at + Vector2(k, k), at + Vector2(0.0, k)]), col)
				tb.fan(PackedVector2Array([at + Vector2(0.0, k * 0.78), at + Vector2(k, k * 0.78), at + Vector2(k, k),
					at + Vector2(0.0, k)]), col.darkened(0.14))
		_topiary_shown = tb.mesh()
	_topiary.queue_redraw()
