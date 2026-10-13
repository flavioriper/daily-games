extends Control

## Paper Planes' world: the air over the clouds, edge to edge under the
## board and the host's rows (CLAUDE.md: a game's world fills the screen).
## It is the menu card's picture (ui/menu/cards/planes.gd) at the size of
## the screen: a pale morning sky, bluest at the top and warming to cream,
## the card's lanes running across it as a faint lattice of dots, flat
## clouds lying at its sides, and a sea of cloud along the foot with two of
## the board's folded planes out over it on their dotted ways.
##
## The top stays pale because of what lies over it: the wordmark, the motto
## and the win's "Well done!" are ink. Nothing but the dots lies where the
## field stands. The side clouds are half behind the field while it is
## played and whole once the win has shrunk it.
##
## One mesh, built when the rect changes and kept (`_shown`) until the next
## replaces it; five glints are a second, on a child whose alpha breathes
## (still under Motion.reduce). The colours are written here: the board
## preloads this file.

const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Face = preload("res://ui/faces/face.gd")
const CardFace = preload("res://ui/menu/cards/card_face.gd")
const PaperPlane = preload("res://ui/faces/paper_plane.gd")

## The screen the picture was drawn on; everything scales with the width.
const W := 1080.0
const SKY_TOP := Color("d6eaf4")
const SKY_MID := Color("f3f3ea")
const SKY_LOW := Color("fdf3e0")
## Where the blue has turned to cream, as a share of the height.
const MID_AT := 0.46
## The morning light behind the wordmark: its middle as shares, its rings as
## [radius at W, alpha].
const LIGHT_AT := Vector2(0.10, 0.02)
const LIGHT_RINGS := [[620.0, 0.22], [420.0, 0.22], [250.0, 0.28]]
## The lanes' dots: their pitch and radius at W, how far down they start (a
## share: none under the wordmark and the levels) and how strong they are.
const DOT_PITCH := 90.0
const DOT_R := 3.6
const DOT_FROM := 0.268
const DOT_ALPHA := 0.16
## Opaque: a cloud is shapes one over another, and a veil would show every
## overlap.
const CLOUD := Color("ffffff")
const CLOUD_SHADE := Color("e4ecf3")
## The flat clouds at the sides: [x, y as shares, half width at W].
const CLOUDS := [
	[0.035, 0.405, 84.0], [0.985, 0.515, 96.0], [0.060, 0.655, 70.0],
	[0.955, 0.760, 78.0], [0.020, 0.845, 60.0],
]
## One small cloud in the gap of the tools row.
const GAP_CLOUD := [0.445, 0.229, 30.0]
## The plane in the gap of the tools row: its head as shares, its cell at W,
## its paper, and the way it came (shares, tail first).
const GAP_PLANE := Vector2(0.690, 0.2265)
const GAP_CELL := 40.0
const GAP_PAPER := 1
const GAP_WAY := [Vector2(0.545, 0.243), Vector2(0.600, 0.247), Vector2(0.652, 0.236)]
## The sea of cloud along the foot, back to front: [how far its crests stand
## over the bottom edge at W, a crest's radius at W, the pitch between
## crests as a share of the radius, the colour, the shift along x].
const SEA := [
	[92.0, 46.0, 1.55, Color("e9eff5"), 0.0],
	[58.0, 40.0, 1.5, Color("f4f6f8"), 31.0],
	[26.0, 34.0, 1.45, Color("ffffff"), 12.0],
]
## The two planes out over the sea: [head x as a share, how far over the
## bottom edge at W, heading, cell at W, paper, the way's length at W].
const SEA_PLANES := [
	[0.250, 52.0, -0.20, 38.0, 0, 150.0],
	[0.790, 58.0, PI + 0.16, 34.0, 2, 120.0],
]
## The glints that breathe: [x, y as shares, radius at W].
const GLINTS := [
	[0.370, 0.221, 9.0], [0.775, 0.243, 7.0], [0.045, 0.560, 8.0],
	[0.962, 0.640, 8.0], [0.520, 0.972, 7.0],
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
	# The sky, in two falls: blue to cream, cream to the foot's warmth. It
	# runs past every edge, since the board's win turns this rect about.
	var over := size.y * 0.5
	var mid := size.y * MID_AT
	var first := b.verts.size()
	b.polygon(PackedVector2Array([Vector2(-over, -over), Vector2(size.x + over, -over),
		Vector2(size.x + over, mid), Vector2(-over, mid)]), Color.WHITE)
	CardFace.shade(b, first, SKY_TOP, SKY_MID, 0.0, mid)
	first = b.verts.size()
	b.polygon(PackedVector2Array([Vector2(-over, mid), Vector2(size.x + over, mid),
		Vector2(size.x + over, size.y + over), Vector2(-over, size.y + over)]), Color.WHITE)
	CardFace.shade(b, first, SKY_MID, SKY_LOW, mid, size.y)
	var light := LIGHT_AT * size
	for ring in LIGHT_RINGS:
		b.disc(light, ring[0] * u, Color(Pal.SURFACE, ring[1]))
	# The lanes: a lattice of dots, centred, from under the levels down to
	# the sea.
	var pitch := DOT_PITCH * u
	var cols := int(floor(size.x / pitch))
	var x0 := (size.x - float(cols) * pitch) * 0.5 + pitch * 0.5
	var y := size.y * DOT_FROM
	var sea_top := size.y - float(SEA[0][0]) * u - float(SEA[0][1]) * u
	while y < sea_top:
		for c in cols:
			b.disc(Vector2(x0 + float(c) * pitch, y), DOT_R * u, Color(Pal.LINE, DOT_ALPHA))
		y += pitch
	# The clouds at the sides, and the small one by the tools.
	for c in CLOUDS:
		_cloud(b, Vector2(c[0], c[1]) * size, c[2] * u)
	_cloud(b, Vector2(GAP_CLOUD[0], GAP_CLOUD[1]) * size, GAP_CLOUD[2] * u)
	# The plane in the gap, on the way it came.
	var way := PackedVector2Array()
	for p: Vector2 in GAP_WAY:
		way.append(p * size)
	var head := GAP_PLANE * size
	way.append(head)
	_way(b, way, u, GAP_PAPER)
	PaperPlane.dart(b, head, (head - way[way.size() - 2]).angle(), GAP_CELL * u, GAP_PAPER)
	# The sea of cloud, back to front.
	for k in SEA.size():
		var band: Array = SEA[k]
		var r := float(band[1]) * u
		var top := size.y - float(band[0]) * u
		var step := r * float(band[2])
		var x := -r + fposmod(float(band[4]) * u, step) - step
		var i := 0
		while x < size.x + r:
			# Every other crest stands a little lower, so the line rolls.
			b.disc(Vector2(x, top + (r * 0.22 if i % 2 == 1 else 0.0)), r, band[3])
			x += step
			i += 1
		b.polygon(PackedVector2Array([Vector2(-over, top), Vector2(size.x + over, top),
			Vector2(size.x + over, size.y + over), Vector2(-over, size.y + over)]), band[3])
	# The two planes out over it, each on the way it came.
	for p in SEA_PLANES:
		var at := Vector2(float(p[0]) * size.x, size.y - float(p[1]) * u)
		var dir := Vector2.from_angle(float(p[2]))
		var tail := at - dir * float(p[5]) * u
		_way(b, PackedVector2Array([tail, tail.lerp(at, 0.5) + dir.orthogonal() * 9.0 * u, at]),
			u, int(p[4]))
		PaperPlane.dart(b, at, float(p[2]), float(p[3]) * u, int(p[4]))
	_shown = b.mesh()
	queue_redraw()
	var gb := Face.Builder.new()
	for g in GLINTS:
		_glint(gb, Vector2(g[0], g[1]) * size, g[2] * u)
	_glints_shown = gb.mesh()
	_glints.size = size
	_glints.queue_redraw()

## A flat cloud about `at`, `w` to either side: the card's, with a shade
## under it.
func _cloud(b: Face.Builder, at: Vector2, w: float) -> void:
	var h := w * 0.3
	b.polygon(Face.Builder.round_rect(at - Vector2(w, -h * 0.16), Vector2(w * 2.0, h), h * 0.5), CLOUD_SHADE)
	b.polygon(Face.Builder.round_rect(at - Vector2(w, 0.0), Vector2(w * 2.0, h), h * 0.5), CLOUD)
	b.disc(at + Vector2(-w * 0.3, 0.0), h * 0.9, CLOUD)
	b.disc(at + Vector2(w * 0.25, -h * 0.1), h * 1.15, CLOUD)

## The dotted way a plane came along, in its own thread.
func _way(b: Face.Builder, path: PackedVector2Array, u: float, paper: int) -> void:
	PaperPlane.dashes(b, path, 4.0 * u, 9.0 * u, 11.0 * u, 0.0, Color(PaperPlane.thread(paper), 0.55), 14.0 * u)

## A four-pointed glint of `r`, its waist pinched (the menu cards').
func _glint(b: Face.Builder, at: Vector2, r: float) -> void:
	var pts := PackedVector2Array()
	for i in 8:
		pts.append(at + Vector2.from_angle(-PI * 0.5 + i * PI * 0.25) * (r if i % 2 == 0 else r * 0.30))
	b.polygon(pts, Color(Pal.SUN_RAY, 0.85))
