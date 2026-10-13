extends Control

## Shikaku's world: the meadow the garden is dug in, edge to edge under the
## board and the host's rows (CLAUDE.md: a game's world fills the screen).
## It is the menu card's picture (ui/menu/cards/shikaku.gd) at the size of
## the screen: pale grass under the wordmark with the morning in its corner,
## mown bands running faintly down the lawn, a run of the garden's own fence
## with three flowers at it in the gap of the tools row, and at the foot two
## rises of deeper grass and the flowers and tufts that grow in whatever
## the field leaves open under it. The fields are tall and not all the same
## height, so the board says where its field ends (`set_foot`) and the foot's
## flowers are laid in the band under that, never half behind the ground.
##
## The top is the palest of it because of what lies over it: the wordmark,
## the motto and the win's "Well done!" are ink. Under the field itself
## there is only grass.
##
## One mesh, built when the rect changes and kept (`_shown`) until the next
## replaces it; the pollen is a second, on a child whose alpha breathes
## (still under Motion.reduce). The colours are the palette's and the
## board's BLOOMS written again: the board preloads this file.

const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Face = preload("res://ui/faces/face.gd")
const CardFace = preload("res://ui/menu/cards/card_face.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

## The screen the picture was drawn on; everything scales with the width.
const W := 1080.0
const MEADOW_TOP := Color("eef3dc")
const MEADOW_LOW := Color("d5e2ae")
## The morning in the wordmark's corner: its middle as shares of the rect
## and its rings, [radius at W, alpha].
const SUN_AT := Vector2(0.08, 0.02)
const SUN_RINGS := [[720.0, 0.07], [500.0, 0.08], [300.0, 0.10]]
## The mown bands: their width and lean at W, and how faint.
const BAND := 150.0
const BAND_LEAN := 0.22
const BAND_ALPHA := 0.10
## The rises at the foot: [x, width and height as shares, alpha].
const RISES := [[0.76, 0.62, 0.115, 0.34], [0.22, 0.58, 0.085, 0.26]]
## The fence in the gap of the tools row, as shares of the rect: where it
## stands and its posts along it; its rail's width at W.
const FENCE_Y := 0.2490
const FENCE_FROM := 0.300
const FENCE_TO := 0.610
const FENCE_POSTS := 4
const FENCE_W := 11.0
## Petal and heart, one pair a flower (the board's BLOOMS).
const BLOOMS := [
	[Pal.FLOWER, Pal.SUN_RAY],
	[Pal.SUN_RAY, Pal.ACORN_DEEP],
	[Pal.SURFACE, Pal.SUN],
	[Pal.SHADOW_TINT, Pal.SUN_RAY],
	[Pal.CLOUD, Pal.SUN_TILE],
]
## The flowers at the fence: [x, y of the foot as shares, height at W,
## BLOOMS index].
const FLOWERS := [[0.345, 0.2500, 50.0, 2], [0.455, 0.2505, 64.0, 0], [0.565, 0.2500, 46.0, 3]]
## The tufts at the fence: [x, y of the root as shares, height at W].
const TUFTS := [[0.318, 0.2505, 18.0], [0.402, 0.2510, 16.0], [0.512, 0.2510, 18.0], [0.596, 0.2505, 15.0]]
## The flowers of the foot: [x as a share, how far down the open band its
## foot stands (0 to 1), height at W (less in a shallow band), BLOOMS index].
const FOOT_FLOWERS := [
	[0.060, 0.92, 84.0, 0], [0.135, 0.99, 62.0, 2], [0.215, 0.90, 72.0, 4],
	[0.305, 0.98, 56.0, 1], [0.455, 0.94, 68.0, 3], [0.560, 0.99, 54.0, 2],
	[0.690, 0.92, 76.0, 0], [0.800, 0.99, 58.0, 1], [0.910, 0.93, 70.0, 4],
]
## The tufts of the foot: [x as a share, how far down the band, height at W].
const FOOT_TUFTS := [
	[0.030, 1.0, 30.0], [0.180, 0.96, 26.0], [0.260, 1.0, 24.0], [0.385, 0.97, 28.0],
	[0.620, 0.96, 26.0], [0.745, 1.0, 24.0], [0.965, 0.98, 30.0], [0.505, 1.0, 22.0],
]
## The room a foot flower keeps under the field's edge, at W.
const FOOT_AIR := 10.0
## The pollen that breathes: [x, y as shares, radius at W]. In the gap of
## the tools row and along the very foot, where the meadow always shows.
const POLLEN := [
	[0.262, 0.2200, 4.0], [0.640, 0.2130, 5.0], [0.668, 0.2400, 3.5],
	[0.110, 0.9880, 4.0], [0.420, 0.9820, 4.5], [0.640, 0.9900, 3.5], [0.870, 0.9840, 4.5],
]
const BREATH := 3.6
const BREATH_LOW := 0.30

var _shown: ArrayMesh
var _pollen: Control
var _pollen_shown: ArrayMesh
var _breath: Tween
## Where the board's field ends, in this rect's pixels; the foot's flowers
## stand in the band from there to the bottom edge.
var _foot := -1.0

## The board says where its field ends; the picture is drawn again only
## when that moves.
func set_foot(y: float) -> void:
	if is_equal_approx(y, _foot):
		return
	_foot = y
	_build()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pollen = Control.new()
	_pollen.name = "Pollen"
	_pollen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pollen.draw.connect(func() -> void:
		if _pollen_shown != null:
			_pollen.draw_mesh(_pollen_shown, null))
	add_child(_pollen)
	resized.connect(_build)
	_build()
	_breath = Motion.pulse(_pollen, "modulate:a", 1.0, BREATH_LOW, BREATH)

func _draw() -> void:
	if _shown != null:
		draw_mesh(_shown, null)

func _build() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var u := size.x / W
	var b := Face.Builder.new()
	# The meadow under everything.
	var page := PackedVector2Array([Vector2(-8.0, -8.0), Vector2(size.x + 8.0, -8.0),
		Vector2(size.x + 8.0, size.y + 8.0), Vector2(-8.0, size.y + 8.0)])
	var first := b.verts.size()
	b.polygon(page, Color.WHITE)
	CardFace.shade(b, first, MEADOW_TOP, MEADOW_LOW, 0.0, size.y)
	# The mown bands, every other one a shade deeper, leaning.
	var lean := size.y * BAND_LEAN
	var step := BAND * u
	var x := -lean
	var odd := false
	while x < size.x + step:
		if odd:
			first = b.verts.size()
			b.polygon(PackedVector2Array([Vector2(x + lean, 0.0), Vector2(x + lean + step, 0.0),
				Vector2(x + step, size.y), Vector2(x, size.y)]), Color.WHITE)
			# Nothing under the wordmark, more toward the foot.
			CardFace.shade(b, first, Color(Pal.MEADOW_LINE, 0.0), Color(Pal.MEADOW_LINE, BAND_ALPHA * 2.0),
				size.y * 0.12, size.y)
		odd = not odd
		x += step
	# The morning in the corner, behind the wordmark.
	var sun := SUN_AT * size
	for ring in SUN_RINGS:
		b.disc(sun, ring[0] * u, Color(Pal.SURFACE, ring[1]))
	# Two rises of deeper grass at the foot.
	for rise in RISES:
		b.ellipse(Vector2(size.x * rise[0], size.y + size.y * 0.015), size.x * rise[1], size.y * rise[2],
			Color(Pal.MEADOW_LINE, rise[3]))
	_fence(b, u)
	for t in TUFTS:
		Scenery.tuft(b, Vector2(t[0], t[1]) * size, t[2] * u)
	for f in FLOWERS:
		_flower(b, Vector2(f[0], f[1]) * size, f[2] * u, f[3])
	# The foot: whatever the field leaves open under it.
	var from := (_foot if _foot > 0.0 else size.y * 0.90) + FOOT_AIR * u
	var band := size.y - 6.0 * u - from
	if band > 24.0 * u:
		for t in FOOT_TUFTS:
			var root := Vector2(size.x * t[0], from + band * t[1])
			Scenery.tuft(b, root, minf(t[2] * u, (root.y - from) * 0.9))
		for f in FOOT_FLOWERS:
			var foot := Vector2(size.x * f[0], from + band * f[1])
			_flower(b, foot, minf(f[2] * u, (foot.y - from) / 1.3), f[3])
	_shown = b.mesh()
	queue_redraw()
	var pb := Face.Builder.new()
	for p in POLLEN:
		var at := Vector2(p[0], p[1]) * size
		pb.disc(at, p[2] * u * 2.4, Color(Pal.SURFACE, 0.22))
		pb.disc(at, p[2] * u, Color(Pal.SURFACE, 0.85))
	_pollen_shown = pb.mesh()
	_pollen.size = size
	_pollen.queue_redraw()

## A run of the garden's fence in the gap of the tools row: two rails over their shade,
## lit along the top, and a capped post where they are nailed (the board's
## _fence_mesh, stood up).
func _fence(b: Face.Builder, u: float) -> void:
	var fw := FENCE_W * u
	var y := size.y * FENCE_Y
	var x0 := size.x * FENCE_FROM
	var x1 := size.x * FENCE_TO
	var lit: Color = Pal.FENCE_RAIL.lerp(Pal.SURFACE, 0.55)
	var tall := fw * 4.6
	# Its shade on the grass.
	b.ellipse(Vector2((x0 + x1) * 0.5, y + fw * 0.5), (x1 - x0) * 0.5, fw * 0.9, Color(Pal.LEAF_DEEP, 0.12))
	for rail: float in [0.34, 0.72]:
		var ry := y - tall * rail
		b.stroke(PackedVector2Array([Vector2(x0, ry + fw * 0.3), Vector2(x1, ry + fw * 0.3)]), fw * 0.72, Pal.FENCE_DARK)
		b.stroke(PackedVector2Array([Vector2(x0, ry), Vector2(x1, ry)]), fw * 0.72, Pal.FENCE_RAIL)
		b.stroke(PackedVector2Array([Vector2(x0, ry - fw * 0.16), Vector2(x1, ry - fw * 0.16)]), fw * 0.2, lit)
	for i in FENCE_POSTS:
		var px := lerpf(x0 + fw * 1.4, x1 - fw * 1.4, float(i) / float(FENCE_POSTS - 1))
		var post := Vector2(fw * 1.25, tall)
		var at := Vector2(px - post.x * 0.5, y - tall)
		b.polygon(Face.Builder.round_rect(at + Vector2(fw * 0.22, 0.0), post, post.x * 0.42), Pal.FENCE_DARK)
		b.polygon(Face.Builder.round_rect(at, post, post.x * 0.42), Pal.FENCE_POST)
		b.polygon(Face.Builder.round_rect(at + Vector2(post.x * 0.18, post.x * 0.2), Vector2(post.x * 0.24, tall * 0.5), post.x * 0.12),
			Color(lit, 0.55))
		for rail: float in [0.34, 0.72]:
			b.disc(Vector2(px, y - tall * rail), fw * 0.16, Pal.FENCE_DARK)

## One of the win's flowers, `s` tall from its foot at `at`, in the BLOOMS
## pair `bloom` (the menu card's).
func _flower(b: Face.Builder, at: Vector2, s: float, bloom: int) -> void:
	var lean := (bloom % 3 - 1) * 0.16
	var tip := at + Vector2(s * lean * 0.5, -s)
	var bend := at + Vector2(s * lean * -0.25, -s * 0.55)
	b.stroke(Face.Builder.bezier2(at, bend, tip, 8), maxf(1.6, s * 0.09), Pal.LEAF)
	_leaf(b, at.lerp(bend, 0.7), s * 0.42, -0.35 - lean, Pal.LEAF_LIGHT)
	_leaf(b, at.lerp(bend, 0.7) + Vector2(0.0, s * 0.06), s * 0.38, -2.8 - lean, Pal.LEAF)
	var r := s * 0.30
	var n := 5 + bloom % 2
	for i in n:
		var dir := Vector2.from_angle(lean + TAU * i / n - PI * 0.5)
		b.ellipse(tip + dir * r * 0.62, r * 0.46, r * 0.46, BLOOMS[bloom][0])
	b.disc(tip, r * 0.38, BLOOMS[bloom][1])
	b.disc(tip + Vector2(-r, -r) * 0.1, r * 0.13, Color(Pal.SURFACE, 0.55))

## One leaf: a lens of length `ln` from `at`, turned by `ang`.
func _leaf(b: Face.Builder, at: Vector2, ln: float, ang: float, tint: Color) -> void:
	var turn := Transform2D(ang, at)
	var pts := Face.Builder.bezier2(Vector2.ZERO, Vector2(ln * 0.55, -ln * 0.42), Vector2(ln, 0.0))
	pts.append_array(Face.Builder.bezier2(Vector2(ln, 0.0), Vector2(ln * 0.55, ln * 0.42), Vector2.ZERO))
	var out := PackedVector2Array()
	for p in pts:
		out.append(turn * p)
	b.polygon(out, tint)
