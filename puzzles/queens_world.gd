extends Control

## Queens' world: the palace garden on a pale morning, edge to edge under
## the court and the host's rows (CLAUDE.md: a game's world fills the
## screen). It is the menu card's picture (ui/menu/cards/queens.gd) at the
## size of the screen, made of the court's own things: its pastel tiles,
## the cream blooms a region opens, the crosses a queen casts and her gold.
##
## The top is morning air, cream and all but bare, since the wordmark, the
## motto and the win's "Well done!" are ink with no scrim; a low sun stands
## behind the corner. In the gap of the tools row a garland of the court's
## blooms hangs between two posts. Under the court there is only the lawn's
## pale wash. The foot is the garden: a clipped hedge with two round
## topiaries, a walk of loose court tiles laid across the grass in the
## regions' colours (one of them crossed, one gold where a queen would
## sit), blooms and tufts beside it, and the hive at the right with a
## dashed flight looping out of it.
##
## One mesh, built when the rect changes and kept (`_shown`) until the next
## replaces it; the pollen motes are a second, on a child whose alpha
## breathes (still under Motion.reduce). The colours are written here: the
## board preloads this file, so this one cannot preload the board.

const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Face = preload("res://ui/faces/face.gd")
const CardFace = preload("res://ui/menu/cards/card_face.gd")
const Scenery = preload("res://ui/flat/scenery.gd")
const CrossMark = preload("res://ui/faces/cross_mark.gd")

## The screen the picture was drawn on; everything scales with the width.
const W := 1080.0
const AIR_TOP := Color("fdf6e6")
const AIR_LOW := Color("f3f0d6")
const LAWN_HIGH := Color("e3ecc4")
const LAWN_LOW := Color("bfd89c")
const HEDGE_FAR := Color("a9c98c")
const HEDGE := Color("8fb877")
const HEDGE_LIT := Color("a4c88a")
const HEDGE_DEEP := Color("79a565")
const POST := Color("b98f5e")
const CORD := Color("c7a26c")
const HIVE := Color("e9b65a")
const HIVE_BAND := Color("cf9740")
const HIVE_DOOR := Color("5a3d24")
const CLOUD := Color("fffaf0")
## The sun's middle, as shares of the rect, and its glow's rings: [radius
## at W, alpha].
const SUN_AT := Vector2(0.93, 0.03)
const SUN_RINGS := [[640.0, 0.09], [440.0, 0.10], [270.0, 0.14]]
## Where the air has become lawn, as shares of the height: the lawn's wash
## starts under the tools row and is whole at the hedge.
const LAWN_FROM := 0.26
const HEDGE_Y := 0.842
## The garland in the gap of the tools row: its two ends as shares, its sag
## at W, and how many blooms hang on it.
const GARLAND_FROM := Vector2(0.300, 0.212)
const GARLAND_TO := Vector2(0.815, 0.212)
const GARLAND_SAG := 34.0
const GARLAND_BLOOMS := 5
const GARLAND_R := 17.0
## No cloud: the host's rows cover the air down to the garland. A cloud
## added here is [x, y as shares, radius at W].
const CLOUDS := []
## The walk across the foot: [x, y as shares, side at W, region, turn]. The
## regions index Pal.REGION; the tiles are loose, each a little turned.
const WALK := [
	[0.070, 0.936, 104.0, 3, -0.10], [0.185, 0.957, 100.0, 1, 0.07],
	[0.298, 0.930, 104.0, 4, -0.05], [0.412, 0.955, 100.0, 2, 0.09],
	[0.525, 0.932, 104.0, 0, -0.08], [0.640, 0.957, 100.0, 7, 0.05],
]
## Which of the walk's tiles carries a cross, and which the queen's gold.
const WALK_CROSSED := 1
const WALK_GOLD := 3
## The hive: its foot's middle as shares, its width at W.
const HIVE_AT := Vector2(0.868, 0.962)
const HIVE_W := 150.0
## The topiaries on the hedge: [x as a share, radius at W].
const TOPIARY := [[0.115, 44.0], [0.735, 38.0]]
## Loose blooms on the grass: [x, y, radius at W, turn].
const BLOOMS := [
	[0.035, 0.878, 15.0, 0.3], [0.245, 0.885, 13.0, 1.1], [0.468, 0.880, 14.0, 2.0],
	[0.585, 0.893, 12.0, 0.7], [0.965, 0.900, 14.0, 1.6], [0.752, 0.975, 13.0, 2.6],
	[0.130, 0.988, 12.0, 0.9],
]
## Tufts on the grass: [x, y, height at W].
const TUFTS := [
	[0.350, 0.892, 26.0], [0.695, 0.905, 24.0], [0.020, 0.972, 24.0],
	[0.470, 0.992, 22.0], [0.975, 0.968, 26.0], [0.905, 0.884, 22.0],
]
## The motes that breathe: [x, y, radius at W].
const MOTES := [
	[0.215, 0.862, 7.0], [0.395, 0.848, 5.0], [0.560, 0.866, 6.0],
	[0.790, 0.858, 5.0], [0.930, 0.846, 6.0], [0.655, 0.236, 5.0],
]
const BREATH := 3.4
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
	# The morning air under everything, turning to the lawn's pale wash.
	var first := b.verts.size()
	b.polygon(_band(-8.0, size.y * LAWN_FROM), Color.WHITE)
	CardFace.shade(b, first, AIR_TOP, AIR_LOW, 0.0, size.y * LAWN_FROM)
	first = b.verts.size()
	b.polygon(_band(size.y * LAWN_FROM, size.y * HEDGE_Y), Color.WHITE)
	CardFace.shade(b, first, AIR_LOW, LAWN_HIGH, size.y * LAWN_FROM, size.y * HEDGE_Y)
	# The low sun behind the corner.
	var sun := SUN_AT * size
	for ring in SUN_RINGS:
		b.disc(sun, ring[0] * u, Color(Pal.SUN_RAY, ring[1]))
	for c in CLOUDS:
		Scenery.cloud(b, Vector2(c[0], c[1]) * size, c[2] * u, CLOUD)
	_garland(b, u)
	# The garden at the foot: a far hedge's soft line, the clipped hedge and
	# its topiaries, then the grass.
	var hy := size.y * HEDGE_Y
	b.ellipse(Vector2(size.x * 0.30, hy + 20.0 * u), size.x * 0.46, 64.0 * u, HEDGE_FAR)
	b.ellipse(Vector2(size.x * 0.82, hy + 24.0 * u), size.x * 0.40, 58.0 * u, HEDGE_FAR)
	for t in TOPIARY:
		var at := Vector2(size.x * t[0], hy - 6.0 * u)
		var r: float = t[1] * u
		b.disc(at, r, HEDGE)
		b.disc(at + Vector2(-r * 0.22, -r * 0.26), r * 0.62, HEDGE_LIT)
		b.disc(at + Vector2(0.0, -r * 1.28), r * 0.46, HEDGE)
		b.disc(at + Vector2(-r * 0.10, -r * 1.38), r * 0.26, HEDGE_LIT)
	b.polygon(_hedge(hy, u), HEDGE)
	b.stroke(_hedge_top(hy, u), 5.0 * u, HEDGE_LIT, false, false)
	first = b.verts.size()
	b.polygon(_band(hy + 46.0 * u, size.y + 8.0), Color.WHITE)
	CardFace.shade(b, first, LAWN_HIGH.lerp(LAWN_LOW, 0.45), LAWN_LOW, hy + 46.0 * u, size.y)
	b.stroke(PackedVector2Array([Vector2(-8.0, hy + 46.0 * u), Vector2(size.x + 8.0, hy + 46.0 * u)]),
		7.0 * u, HEDGE_DEEP, false, false)
	# The walk of loose court tiles.
	for i in WALK.size():
		_tile(b, WALK[i], u, i == WALK_CROSSED, i == WALK_GOLD)
	for t in TUFTS:
		Scenery.tuft(b, Vector2(t[0], t[1]) * size, t[2] * u)
	for f in BLOOMS:
		_bloom(b, Vector2(f[0], f[1]) * size, f[2] * u, f[3])
	_hive(b, HIVE_AT * size, HIVE_W * u, u)
	_shown = b.mesh()
	queue_redraw()
	var mb := Face.Builder.new()
	for m in MOTES:
		var at := Vector2(m[0], m[1]) * size
		mb.disc(at, m[2] * u * 2.2, Color(Pal.SUN_RAY, 0.22))
		mb.disc(at, m[2] * u, Color(Pal.SUN, 0.85))
	_motes_shown = mb.mesh()
	_motes.size = size
	_motes.queue_redraw()

## A strip of the whole width from `y0` to `y1`, a little past the sides.
func _band(y0: float, y1: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(-8.0, y0), Vector2(size.x + 8.0, y0),
		Vector2(size.x + 8.0, y1), Vector2(-8.0, y1)])

## The clipped hedge's top: a low line of soft bumps across the screen.
func _hedge_top(hy: float, u: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var steps := 54
	for i in steps + 1:
		var x := lerpf(-8.0, size.x + 8.0, float(i) / steps)
		pts.append(Vector2(x, hy - (8.0 + 7.0 * sin(x / (46.0 * u)) + 4.0 * sin(x / (17.0 * u) + 1.3)) * u))
	return pts

func _hedge(hy: float, u: float) -> PackedVector2Array:
	var pts := _hedge_top(hy, u)
	pts.append(Vector2(size.x + 8.0, hy + 50.0 * u))
	pts.append(Vector2(-8.0, hy + 50.0 * u))
	return pts

## The garland: two short posts, a sagging cord between them and the court's
## blooms hung along it.
func _garland(b: Face.Builder, u: float) -> void:
	var from := GARLAND_FROM * size
	var to := GARLAND_TO * size
	var cord := Face.Builder.bezier2(from, (from + to) * 0.5 + Vector2(0.0, GARLAND_SAG * 2.0 * u), to, 28)
	cord.append(to)
	b.stroke(cord, 4.0 * u, CORD)
	for end: Vector2 in [from, to]:
		b.disc(end, 8.0 * u, POST)
		b.disc(end + Vector2(-2.0, -2.0) * u, 3.5 * u, POST.lightened(0.3))
	for k in GARLAND_BLOOMS:
		var at: Vector2 = cord[int(round((k + 0.5) / GARLAND_BLOOMS * (cord.size() - 1)))]
		var r := GARLAND_R * u * (1.0 if k % 2 == 0 else 0.82)
		_bloom(b, at + Vector2(0.0, r * 0.5), r, k * 1.3)
	# Two leaves a side of the middle bloom.
	var mid: Vector2 = cord[cord.size() / 2]
	for s: float in [-1.0, 1.0]:
		b.fan(_oval(mid + Vector2(s * 46.0, -4.0) * u, 15.0 * u, 6.5 * u, s * 0.35), Pal.LEAF)

## A loose court tile: its region's colour with the lit lip and the shaded
## foot the court's cells have, on an ink rim, a soft shadow under it.
func _tile(b: Face.Builder, t: Array, u: float, crossed: bool, gold: bool) -> void:
	var at := Vector2(t[0], t[1]) * size
	var s: float = t[2] * u
	var col: Color = Pal.REGION[int(t[3]) % Pal.REGION.size()]
	var xf := Transform2D(float(t[4]), at)
	Scenery.soft_disc(b, at + Vector2(0.0, s * 0.46), s * 0.6, s * 0.14, Color(Pal.TEXT, 0.16))
	var rim := 4.0 * u
	b.polygon(xf * Face.Builder.round_rect(-Vector2.ONE * (s * 0.5 + rim), Vector2.ONE * (s + 2.0 * rim), s * 0.16 + rim), Pal.TEXT)
	b.polygon(xf * Face.Builder.round_rect(-Vector2.ONE * s * 0.5, Vector2.ONE * s, s * 0.16), col.lerp(Pal.TEXT, 0.1))
	b.polygon(xf * Face.Builder.round_rect(-Vector2.ONE * s * 0.5, Vector2(s, s * 0.93), s * 0.16), col)
	b.polygon(xf * Face.Builder.round_rect(Vector2(-s * 0.38, -s * 0.44), Vector2(s * 0.76, s * 0.07), s * 0.035), col.lerp(Pal.PAPER, 0.4))
	if gold:
		b.polygon(xf * Face.Builder.round_rect(-Vector2.ONE * s * 0.5, Vector2(s, s * 0.93), s * 0.16), Color(Pal.QUEEN_WASH, 0.42))
		_crown(b, at + Vector2(0.0, -s * 0.02), s * 0.3, float(t[4]))
	if crossed:
		CrossMark.draw(b, at + Vector2(0.0, -s * 0.03), s, Vector2.ONE * 0.8, 0.7, float(t[4]), Pal.TEXT_DIM)

## A small crown lying on the gold tile: three points on a band.
func _crown(b: Face.Builder, at: Vector2, r: float, turn: float) -> void:
	var xf := Transform2D(turn, at)
	var pts := PackedVector2Array([
		Vector2(-r, r * 0.55), Vector2(-r, -r * 0.45), Vector2(-r * 0.5, r * 0.02),
		Vector2(0.0, -r * 0.75), Vector2(r * 0.5, r * 0.02), Vector2(r, -r * 0.45),
		Vector2(r, r * 0.55),
	])
	b.polygon(xf * pts, Pal.SUN_DEEP)
	b.polygon(xf * Face.Builder.round_rect(Vector2(-r, r * 0.3), Vector2(r * 2.0, r * 0.3), r * 0.1), Pal.SUN)
	for p: Vector2 in [Vector2(-r, -r * 0.45), Vector2(0.0, -r * 0.75), Vector2(r, -r * 0.45)]:
		b.disc(xf * p, r * 0.14, Pal.SURFACE)

## The hive: a straw skep of four bands with a dark door, on its shadow,
## and the dashed flight a bee left looping out of it.
func _hive(b: Face.Builder, foot: Vector2, w: float, u: float) -> void:
	Scenery.soft_disc(b, foot + Vector2(0.0, 2.0 * u), w * 0.62, w * 0.1, Color(Pal.TEXT, 0.18))
	var bands := [[1.0, 0.0], [0.92, 0.25], [0.74, 0.5], [0.48, 0.74]]
	var h := w * 0.92
	for band in bands:
		var bw: float = w * band[0]
		var y: float = foot.y - h * band[1]
		var at := Vector2(foot.x - bw * 0.5, y - h * 0.27)
		b.polygon(Face.Builder.round_rect(at - Vector2(0.0, 0.0), Vector2(bw, h * 0.3), h * 0.14), HIVE_BAND)
		b.polygon(Face.Builder.round_rect(at, Vector2(bw, h * 0.24), h * 0.12), HIVE)
		b.polygon(Face.Builder.round_rect(at + Vector2(bw * 0.12, h * 0.04), Vector2(bw * 0.4, h * 0.045), h * 0.02),
			HIVE.lightened(0.3))
	b.disc(foot + Vector2(0.0, -h * 1.0), w * 0.09, HIVE_BAND)
	var door := foot + Vector2(0.0, -h * 0.13)
	b.polygon(Face.Builder.round_rect(door - Vector2(w * 0.11, h * 0.1), Vector2(w * 0.22, h * 0.22), w * 0.1), HIVE_DOOR)
	# The flight: a dashed loop up and away to the left.
	var path := Face.Builder.bezier3(door + Vector2(-w * 0.2, -h * 0.1), foot + Vector2(-w * 1.5, -h * 0.5),
		foot + Vector2(-w * 0.2, -h * 2.0), foot + Vector2(-w * 1.35, -h * 1.55), 26)
	for i in range(0, path.size() - 1, 2):
		b.stroke(PackedVector2Array([path[i], path[i + 1]]), 3.0 * u, Color(Pal.TEXT, 0.3))

## A bloom of `r`: five cream petals, each on its ink, round a gold middle
## (the court's own, puzzles/queens2d.gd).
func _bloom(b: Face.Builder, at: Vector2, r: float, turn: float) -> void:
	for p in 5:
		var a := turn + TAU * p / 5.0
		var dir := Vector2.from_angle(a)
		b.fan(_oval(at + dir * r * 0.55, r * 0.52, r * 0.3, a), Color(Pal.TEXT, 0.55))
		b.fan(_oval(at + dir * r * 0.55, r * 0.45, r * 0.23, a), Pal.SURFACE)
	b.disc(at, r * 0.32, Pal.SUN)

static func _oval(at: Vector2, rx: float, ry: float, angle: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in 12:
		var a := TAU * k / 12.0
		pts.append(at + Vector2(cos(a) * rx, sin(a) * ry).rotated(angle))
	return pts
