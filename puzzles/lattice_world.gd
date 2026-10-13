extends Control

## Lattice's world: a garden wall on a pale morning, edge to edge under the
## board and the host's rows (CLAUDE.md: a game's world fills the screen).
## It is the menu card's slate paper (ui/menu/cards/lattice.gd) at the size
## of the screen, made of the board's own things: the paper is palest at the
## top, where the wordmark and the win's words are ink; a sprig of the
## climber, a loose blank tile and a knot lie in the gap of the tools row;
## nothing but a pale pool lies under the lattice; and along the foot
## stands a low garden trellis of the board's slats between two capped
## posts, a climber wound across it in leaf and cream bloom, a terracotta
## pot at its left, two blank tiles and a knot dropped in the grass, and
## the lawn's rise along the bottom edge.
##
## Nothing here has a number or a face, so only the board's tiles read as
## tiles to move. The colours are written here: the board preloads this
## file, and loading the board back would be a cycle.
##
## One mesh, built when the rect or the board's foot changes and kept
## (`_shown`) until the next replaces it; the pollen is a second, on a child
## whose alpha breathes (still under Motion.reduce).

const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Face = preload("res://ui/faces/face.gd")
const CardFace = preload("res://ui/menu/cards/card_face.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

## The screen the picture was drawn on; everything scales with the width.
const W := 1080.0
const SLATE_TOP := Color("f6f8fc")
const SLATE_MID := Color("e9eef6")
const SLATE_LOW := Color("dbe4f0")
const POOL := Color("f8fafd")
const LAWN := Color("c5dcb4")
const LAWN_DEEP := Color("aecb9c")
const WOOD := Color("c8a17a")
const WOOD_DEEP := Color("9c7350")
const VINE := Color("6f9a4c")
const LEAF := Color("86b85c")
const LEAF_DEEP := Color("5f9440")
const BLOOM := Color("fff6e2")
const BLOOM_EYE := Color("f3b84a")
const POT := Color("d98a63")
const POT_DEEP := Color("b96c49")
const TILE := Color("fffdf8")
const TILE_EDGE := Color("d9cfc0")
const KNOT := Color("4a4038")
## The light in the wordmark's corner, as shares of the rect, and its rings:
## [radius at W, alpha].
const SUN_AT := Vector2(0.10, 0.02)
const SUN_RINGS := [[720.0, 0.10], [480.0, 0.10], [300.0, 0.14]]
## The gap of the tools row, between the bin and Hint: a sprig's root and
## reach, a blank tile and a knot, as shares, sizes at W.
const SPRIG_AT := Vector2(0.455, 0.243)
const SPRIG_TO := Vector2(0.640, 0.224)
const GAP_TILE := [0.365, 0.234, 40.0, -0.20]
const GAP_KNOT := [0.705, 0.236, 13.0]
## The trellis, in pixels at W up from the bottom edge: its foot, its
## height, its sides as shares of the width, and the slats' pitch.
const TRELLIS_FOOT := 92.0
const TRELLIS_H := 176.0
const TRELLIS_X := Vector2(0.075, 0.925)
const TRELLIS_PITCH := 62.0
const SLAT_W := 11.0
const POST_W := 26.0
## The foot is drawn for this much open band under the board (at W); a
## shallower band shrinks it, and under FOOT_MIN only the lawn is drawn.
const FOOT_ROOM := 300.0
const FOOT_MIN := 120.0
## The pollen: [x, y as shares, radius at W]. y over 1 is measured up from
## the bottom edge in pixels at W.
const MOTES := [[0.335, 0.226, 5.0], [0.585, 0.247, 4.0], [0.775, 0.230, 4.5],
	[0.20, 320.0, 5.0], [0.52, 300.0, 4.0], [0.84, 330.0, 5.0]]
const BREATH := 3.4
const BREATH_LOW := 0.3

var _shown: ArrayMesh
var _motes: Control
var _motes_shown: ArrayMesh
var _breath: Tween
## Where the board's lattice ends, in this rect's pixels (set_foot); under 0
## the foot is drawn whole.
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

## The board says where its lattice ends, so the trellis fits the band left.
func set_foot(y: float) -> void:
	if is_equal_approx(y, _foot):
		return
	_foot = y
	_build()

func _draw() -> void:
	if _shown != null:
		draw_mesh(_shown, null)

func _build() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var u := size.x / W
	var b := Face.Builder.new()
	# The slate paper, palest at the top.
	var first := b.verts.size()
	b.polygon(PackedVector2Array([Vector2(-8.0, -8.0), Vector2(size.x + 8.0, -8.0),
		Vector2(size.x + 8.0, size.y * 0.5), Vector2(-8.0, size.y * 0.5)]), Color.WHITE)
	CardFace.shade(b, first, SLATE_TOP, SLATE_MID, 0.0, size.y * 0.5)
	first = b.verts.size()
	b.polygon(PackedVector2Array([Vector2(-8.0, size.y * 0.5), Vector2(size.x + 8.0, size.y * 0.5),
		Vector2(size.x + 8.0, size.y + 8.0), Vector2(-8.0, size.y + 8.0)]), Color.WHITE)
	CardFace.shade(b, first, SLATE_MID, SLATE_LOW, size.y * 0.5, size.y)
	var sun := SUN_AT * size
	for ring in SUN_RINGS:
		b.disc(sun, ring[0] * u, Color(POOL, ring[1] * 4.0))
	# The card's pale pool, behind where the lattice stands.
	Scenery.soft_disc(b, Vector2(size.x * 0.5, size.y * 0.55), size.x * 0.62, size.x * 0.56, Color(POOL, 0.55))
	# The gap of the tools row.
	_sprig(b, SPRIG_AT * size, SPRIG_TO * size, u)
	_blank(b, Vector2(GAP_TILE[0], GAP_TILE[1]) * size, GAP_TILE[2] * u, GAP_TILE[3])
	b.disc(Vector2(GAP_KNOT[0], GAP_KNOT[1]) * size, GAP_KNOT[2] * u, Color(KNOT, 0.8))
	# The foot.
	var room := FOOT_ROOM * u if _foot < 0.0 else size.y - _foot
	var k := clampf(room / (FOOT_ROOM * u), 0.45, 1.0)
	if room >= FOOT_MIN * u:
		_trellis(b, u, k)
	_lawn(b, u, room >= FOOT_MIN * u, k)
	_shown = b.mesh()
	queue_redraw()
	var mb := Face.Builder.new()
	for m in MOTES:
		var y: float = m[1] * size.y if m[1] <= 1.0 else size.y - m[1] * u * k
		if m[1] > 1.0 and room < FOOT_MIN * u:
			continue
		var at := Vector2(m[0] * size.x, y)
		mb.disc(at, m[2] * u * 2.2, Color(BLOOM_EYE, 0.12))
		mb.disc(at, m[2] * u, Color(BLOOM, 0.9))
	_motes_shown = mb.mesh()
	_motes.size = size
	_motes.queue_redraw()

## The trellis: a diamond lattice of slats between two capped posts under a
## top rail, the climber wound across it, a pot at its left foot.
func _trellis(b: Face.Builder, u: float, k: float) -> void:
	var s := u * k
	var foot := size.y - TRELLIS_FOOT * s
	var top := foot - TRELLIS_H * s
	var left := TRELLIS_X.x * size.x
	var right := TRELLIS_X.y * size.x
	var box := Rect2(left, top, right - left, foot - top)
	# The slats, leaning one way and then the other, cut to the box.
	var pitch := TRELLIS_PITCH * s
	var tall := box.size.y
	for lean: float in [1.0, -1.0]:
		var x := box.position.x - tall
		while x < box.end.x + tall:
			var from := Vector2(x, foot)
			var to := Vector2(x + lean * tall, top)
			var cut := _cut(from, to, box)
			if cut.size() == 2:
				b.stroke(cut, SLAT_W * s, WOOD_DEEP if lean > 0.0 else WOOD, false, false)
			x += pitch
	# The rails and the posts over the slats' ends.
	for y: float in [top, foot]:
		b.fan(Face.Builder.round_rect(Vector2(left - 6.0 * s, y - 9.0 * s), Vector2(box.size.x + 12.0 * s, 18.0 * s), 6.0 * s), WOOD_DEEP)
		b.fan(Face.Builder.round_rect(Vector2(left - 6.0 * s, y - 9.0 * s), Vector2(box.size.x + 12.0 * s, 13.0 * s), 6.0 * s), WOOD)
	for x: float in [left, right]:
		var post := Vector2(x - POST_W * s * 0.5, top - 30.0 * s)
		var post_size := Vector2(POST_W * s, tall + 30.0 * s + 34.0 * s)
		b.fan(Face.Builder.round_rect(post, post_size, 7.0 * s), WOOD_DEEP)
		b.fan(Face.Builder.round_rect(post, post_size - Vector2(7.0 * s, 0.0), 7.0 * s), WOOD)
		b.disc(Vector2(x, top - 34.0 * s), 17.0 * s, WOOD_DEEP)
		b.disc(Vector2(x - 2.0 * s, top - 37.0 * s), 14.0 * s, WOOD)
	# The climber: up out of the pot and along the trellis in three swags.
	var pot := Vector2(left + 86.0 * s, foot + 26.0 * s)
	var way := PackedVector2Array()
	way.append_array(Face.Builder.bezier3(pot + Vector2(0.0, -40.0 * s), pot + Vector2(-30.0 * s, -120.0 * s),
		Vector2(left + 150.0 * s, top + 10.0 * s), Vector2(left + 250.0 * s, top + 40.0 * s), 14))
	var spans := 3
	var from_x := left + 250.0 * s
	var step := (right - 40.0 * s - from_x) / float(spans)
	for i in spans:
		var a := Vector2(from_x + step * i, top + 40.0 * s)
		var z := Vector2(from_x + step * (i + 1), top + (40.0 if i < spans - 1 else 16.0) * s)
		var dip := (88.0 if i % 2 == 0 else 64.0) * s
		way.append_array(Face.Builder.bezier3(a, a + Vector2(step * 0.3, dip), z - Vector2(step * 0.3, -dip + 20.0 * s), z, 14))
	b.stroke(way, 7.0 * s, VINE, false, true)
	# Leaves either side of the stem, and a bloom every few.
	var n := way.size()
	var j := 4
	var count := 0
	while j < n - 2:
		var at := way[j]
		var dir := (way[j + 1] - way[j - 1]).normalized()
		var side := Vector2(-dir.y, dir.x) * (1.0 if count % 2 == 0 else -1.0)
		_leaf(b, at, (dir * 0.45 + side).normalized(), (30.0 if count % 3 != 1 else 24.0) * s,
			LEAF if count % 2 == 0 else LEAF_DEEP)
		if count % 4 == 2:
			_bloom(b, at - side * 20.0 * s, 13.0 * s)
		count += 1
		j += 4
	# The pot, over the stem's foot.
	_pot(b, pot, 46.0 * s)

## The lawn's rise along the bottom edge, its tufts, and what was dropped in
## the grass (left out when there is no room for the trellis).
func _lawn(b: Face.Builder, u: float, things: bool, k: float) -> void:
	var s := u * k
	b.ellipse(Vector2(size.x * 0.24, size.y + 70.0 * s), size.x * 0.62, 150.0 * s, LAWN)
	b.ellipse(Vector2(size.x * 0.80, size.y + 86.0 * s), size.x * 0.58, 160.0 * s, LAWN_DEEP)
	b.ellipse(Vector2(size.x * 0.46, size.y + 96.0 * s), size.x * 0.50, 132.0 * s, LAWN)
	for x: float in [0.05, 0.19, 0.335, 0.61, 0.765, 0.955]:
		Scenery.tuft(b, Vector2(x * size.x, size.y - 14.0 * s), 30.0 * s)
	if not things:
		return
	_blank(b, Vector2(size.x * 0.455, size.y - 46.0 * s), 54.0 * s, 0.16)
	_blank(b, Vector2(size.x * 0.535, size.y - 34.0 * s), 54.0 * s, -0.30)
	b.disc(Vector2(size.x * 0.655, size.y - 38.0 * s), 17.0 * s, KNOT)
	b.disc(Vector2(size.x * 0.652, size.y - 43.0 * s), 6.0 * s, Color(TILE, 0.18))
	_bloom(b, Vector2(size.x * 0.865, size.y - 40.0 * s), 14.0 * s)
	_bloom(b, Vector2(size.x * 0.285, size.y - 30.0 * s), 12.0 * s)

## A sprig of the climber from `from` to `to`: a stem, five leaves, a bloom.
func _sprig(b: Face.Builder, from: Vector2, to: Vector2, u: float) -> void:
	var mid := (from + to) * 0.5 + Vector2(0.0, -26.0 * u)
	var way := Face.Builder.bezier2(from, mid, to, 12)
	way.append(to)
	b.stroke(way, 5.0 * u, Color(VINE, 0.85), false, true)
	for i in 5:
		var at := way[2 + i * 2]
		var dir := (way[3 + i * 2] - way[1 + i * 2]).normalized()
		var side := Vector2(-dir.y, dir.x) * (1.0 if i % 2 == 0 else -1.0)
		_leaf(b, at, (dir * 0.5 + side).normalized(), 20.0 * u, Color(LEAF if i % 2 == 0 else LEAF_DEEP, 0.9))
	_bloom(b, to + Vector2(6.0 * u, -4.0 * u), 10.0 * u)

## A leaf rooted at `at`, pointing along `dir`, `len` long.
func _leaf(b: Face.Builder, at: Vector2, dir: Vector2, len: float, ink: Color) -> void:
	var side := Vector2(-dir.y, dir.x)
	var tip := at + dir * len
	var pts := PackedVector2Array()
	pts.append_array(Face.Builder.bezier2(at, at + dir * len * 0.5 + side * len * 0.42, tip, 6))
	pts.append_array(Face.Builder.bezier2(tip, at + dir * len * 0.5 - side * len * 0.42, at, 6))
	b.polygon(pts, ink)

## A five-petalled cream bloom of radius `r`.
func _bloom(b: Face.Builder, at: Vector2, r: float) -> void:
	for i in 5:
		b.disc(at + Vector2.from_angle(-PI * 0.5 + i * TAU / 5.0) * r * 0.62, r * 0.52, BLOOM)
	b.disc(at, r * 0.36, BLOOM_EYE)

## A blank paper tile of side `s`, turned `tilt`: no number, so it is not a
## piece.
func _blank(b: Face.Builder, at: Vector2, s: float, tilt: float) -> void:
	var xf := Transform2D(tilt, at)
	Scenery.soft_disc(b, at + Vector2(0.0, s * 0.46), s * 0.5, s * 0.14, Color(KNOT, 0.14))
	b.fan(xf * Face.Builder.round_rect(-Vector2.ONE * s * 0.5, Vector2.ONE * s, s * 0.2), TILE_EDGE)
	b.fan(xf * Face.Builder.round_rect(-Vector2.ONE * s * 0.5, Vector2(s, s * 0.9), s * 0.2), TILE)

## A terracotta pot standing on `at` (its foot's middle), `w` across the rim.
func _pot(b: Face.Builder, at: Vector2, w: float) -> void:
	Scenery.soft_disc(b, at + Vector2(0.0, 2.0), w * 0.6, w * 0.14, Color(KNOT, 0.16))
	var h := w * 0.82
	b.polygon(PackedVector2Array([at + Vector2(-w * 0.34, 0.0), at + Vector2(w * 0.34, 0.0),
		at + Vector2(w * 0.46, -h), at + Vector2(-w * 0.46, -h)]), POT_DEEP)
	b.polygon(PackedVector2Array([at + Vector2(-w * 0.34, 0.0), at + Vector2(w * 0.16, 0.0),
		at + Vector2(w * 0.26, -h), at + Vector2(-w * 0.46, -h)]), POT)
	b.fan(Face.Builder.round_rect(at + Vector2(-w * 0.54, -h - w * 0.2), Vector2(w * 1.08, w * 0.24), w * 0.07), POT_DEEP)
	b.fan(Face.Builder.round_rect(at + Vector2(-w * 0.54, -h - w * 0.2), Vector2(w * 1.08, w * 0.17), w * 0.07), POT)

## The part of the segment `a` to `z` inside `box` (two points), or nothing.
func _cut(a: Vector2, z: Vector2, box: Rect2) -> PackedVector2Array:
	var t0 := 0.0
	var t1 := 1.0
	var d := z - a
	for axis in 2:
		var lo: float = box.position[axis]
		var hi: float = box.end[axis]
		if is_zero_approx(d[axis]):
			if a[axis] < lo or a[axis] > hi:
				return PackedVector2Array()
			continue
		var ta: float = (lo - a[axis]) / d[axis]
		var tb: float = (hi - a[axis]) / d[axis]
		t0 = maxf(t0, minf(ta, tb))
		t1 = minf(t1, maxf(ta, tb))
	if t1 - t0 <= 0.001:
		return PackedVector2Array()
	return PackedVector2Array([a + d * t0, a + d * t1])
