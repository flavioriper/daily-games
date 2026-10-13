extends Control

## Super Slider's world: a carpenter's bench seen from above, edge to edge
## under the tray and the host's rows (CLAUDE.md: a game's world fills the
## screen). The tray is a thing somebody made, so it lies where it was made:
## honey oak boards, pale where the window's light falls across the top
## (the wordmark, the motto and the win's "Well done!" are ink), two curled
## shavings, a brass screw and a spare square in the gap of the tools row,
## and under the tray the gate's green runner going off the foot of the
## bench -- the way home the big block walks -- with a mallet and shavings
## on one side of it and spare blocks, a tin of wax and two dog holes on the
## other. Nothing here has a face: only the tray's blocks do.
##
## The board says where its tray ends and how wide its gate is
## (`set_foot`), since a tray with a pill over it stands lower; the foot's
## things shrink to the band left, and stay away when it is too thin.
##
## One mesh, built when the rect or the foot changes and kept (`_shown`)
## until the next replaces it; the dust in the window's light is a second,
## on a child whose alpha breathes (still under Motion.reduce).

const Motion = preload("res://core/motion.gd")
const Face = preload("res://ui/faces/face.gd")
const CardFace = preload("res://ui/menu/cards/card_face.gd")

## The screen the picture was drawn on; everything scales with the width.
const W := 1080.0
## The bench: cream in the light, honey oak under the tray, deeper at the
## foot. Written here, not read from the board (it preloads this file).
const OAK_LIGHT := Color("fdf5e4")
const OAK_MID := Color("f4e3c2")
const OAK_LOW := Color("e6cb9f")
const SEAM := Color("b98f5a")
const GRAIN := Color("c9a06c")
const LIGHT := Color("fffaf0")
## The tray's own walnut and brass, for the mallet, the screw and the holes.
const WALNUT := Color("a8764f")
const WALNUT_HI := Color("c9976b")
const WALNUT_DEEP := Color("7e5638")
const BRASS := Color("d9ad5b")
const BRASS_HI := Color("f3d99a")
## The gate's mat, run out as a runner.
const MAT := Color("a9cf8e")
const MAT_DEEP := Color("7fae66")
const MAT_HI := Color("d4efb4")
## The spare blocks.
const BAR := Color("6f9fd8")
const BAR_HI := Color("a3c4ec")
const BAR_DEEP := Color("4f7db6")
const SQ := Color("f2c14e")
const SQ_HI := Color("f9dd8f")
const SQ_DEEP := Color("cf9a2c")
const SHAVING := Color("f7e6c4")
const SHAVING_DEEP := Color("d9b888")
const TIN := Color("c7ccd1")
const TIN_HI := Color("eef1f3")
const WAX := Color("f1d79a")
## Where the bench turns from the light to its own oak, as a share of the
## height, and where the boards' seams and grain begin (under the rows).
const TURN := 0.27
## The boards' seams, as shares of the width.
const SEAMS := [0.205, 0.415, 0.61, 0.83]
## Grain: [x, y as shares, length at W].
const GRAINS := [
	[0.06, 0.34, 120.0], [0.27, 0.31, 90.0], [0.47, 0.37, 140.0], [0.70, 0.33, 110.0],
	[0.90, 0.40, 80.0], [0.12, 0.55, 100.0], [0.33, 0.62, 130.0], [0.55, 0.58, 90.0],
	[0.76, 0.66, 120.0], [0.93, 0.72, 70.0], [0.04, 0.80, 90.0], [0.50, 0.83, 110.0],
]
## The window's light behind the wordmark: its middle as shares, its rings
## [radius at W, alpha].
const SUN_AT := Vector2(0.10, 0.02)
const SUN_RINGS := [[680.0, 0.30], [460.0, 0.30], [280.0, 0.35]]
## The gap of the tools row: two shavings, a screw, a spare square.
const GAP_SHAVINGS := [[0.385, 0.236, 22.0, 0.4], [0.455, 0.229, 17.0, 2.6]]
const GAP_SCREW := Vector2(0.585, 0.236)
const GAP_SQUARE := Vector2(0.685, 0.232)
## The foot the things were drawn for, at W, and the least that shows them.
const FOOT_FULL := 230.0
const FOOT_LEAST := 120.0
## The dust in the light: [x, y as shares, radius at W].
const DUST := [[0.20, 0.060, 5.0], [0.34, 0.118, 4.0], [0.46, 0.046, 3.5], [0.14, 0.150, 3.5], [0.58, 0.100, 3.0]]
const BREATH := 3.6
const BREATH_LOW := 0.3

var _shown: ArrayMesh
var _dust: Control
var _dust_shown: ArrayMesh
var _breath: Tween
## Where the tray ends and how wide its gate is, in this rect's pixels; -1
## until the board says.
var _foot := -1.0
var _gate := -1.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dust = Control.new()
	_dust.name = "Dust"
	_dust.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dust.draw.connect(func() -> void:
		if _dust_shown != null:
			_dust.draw_mesh(_dust_shown, null))
	add_child(_dust)
	resized.connect(_build)
	_build()
	_breath = Motion.pulse(_dust, "modulate:a", 1.0, BREATH_LOW, BREATH)

func _draw() -> void:
	if _shown != null:
		draw_mesh(_shown, null)

## The board's word: its tray's frame ends at `y` and its gate is `gate`
## wide. The mesh is built again only when either moved.
func set_foot(y: float, gate: float) -> void:
	if is_equal_approx(y, _foot) and is_equal_approx(gate, _gate):
		return
	_foot = y
	_gate = gate
	_build()

func _build() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var u := size.x / W
	var b := Face.Builder.new()
	var turn := size.y * TURN
	# The bench: the light across the top, the oak under it.
	var first := b.verts.size()
	b.polygon(PackedVector2Array([Vector2(-8.0, -8.0), Vector2(size.x + 8.0, -8.0),
		Vector2(size.x + 8.0, turn), Vector2(-8.0, turn)]), Color.WHITE)
	CardFace.shade(b, first, OAK_LIGHT, OAK_MID, 0.0, turn)
	first = b.verts.size()
	b.polygon(PackedVector2Array([Vector2(-8.0, turn), Vector2(size.x + 8.0, turn),
		Vector2(size.x + 8.0, size.y + 8.0), Vector2(-8.0, size.y + 8.0)]), Color.WHITE)
	CardFace.shade(b, first, OAK_MID, OAK_LOW, turn, size.y)
	var sun := SUN_AT * size
	for ring in SUN_RINGS:
		b.disc(sun, ring[0] * u, Color(LIGHT, ring[1]))
	# The boards' seams and a little grain, from under the rows down.
	for sx in SEAMS:
		var x: float = sx * size.x
		b.stroke(PackedVector2Array([Vector2(x, turn + 10.0 * u), Vector2(x, size.y + 8.0)]), 3.0 * u,
			Color(SEAM, 0.10), false, false)
		b.stroke(PackedVector2Array([Vector2(x + 3.0 * u, turn + 10.0 * u), Vector2(x + 3.0 * u, size.y + 8.0)]), 2.0 * u,
			Color(LIGHT, 0.16), false, false)
	for g in GRAINS:
		var at := Vector2(g[0], g[1]) * size
		var l: float = g[2] * u
		b.stroke(Face.Builder.bezier3(at, at + Vector2(6.0 * u, l * 0.3), at + Vector2(-6.0 * u, l * 0.7),
			at + Vector2(0.0, l), 10), 2.5 * u, Color(GRAIN, 0.10), false, true)
	# The gap of the tools row.
	for s in GAP_SHAVINGS:
		_shaving(b, Vector2(s[0], s[1]) * size, s[2] * u, s[3])
	_screw(b, GAP_SCREW * size, 13.0 * u)
	_piece(b, GAP_SQUARE * size, Vector2(40.0, 40.0) * u, SQ, SQ_HI, SQ_DEEP, 0.12)
	_foot_things(b, u)
	_shown = b.mesh()
	queue_redraw()
	var db := Face.Builder.new()
	for d in DUST:
		db.disc(Vector2(d[0], d[1]) * size, d[2] * u, Color(LIGHT, 0.9))
	_dust_shown = db.mesh()
	_dust.size = size
	_dust.queue_redraw()

## Under the tray: the runner off the foot of the bench, and beside it the
## bench's own things, sized to the band the tray leaves.
func _foot_things(b: Face.Builder, u: float) -> void:
	var top := _foot if _foot >= 0.0 else size.y * 0.885
	var gate := _gate if _gate > 0.0 else 400.0 * u
	var open := size.y - top
	if open <= 8.0 * u:
		return
	var mid := size.x * 0.5
	# The runner: the gate's mat run out, hemmed and stitched, with the
	# mat's own mark pointing the way.
	var half := gate * 0.5
	var y0 := top - 4.0 * u
	b.polygon(PackedVector2Array([Vector2(mid - half - 6.0 * u, y0), Vector2(mid + half + 6.0 * u, y0),
		Vector2(mid + half + 6.0 * u, size.y + 8.0), Vector2(mid - half - 6.0 * u, size.y + 8.0)]), Color(MAT_DEEP, 0.55))
	b.polygon(PackedVector2Array([Vector2(mid - half, y0), Vector2(mid + half, y0),
		Vector2(mid + half, size.y + 8.0), Vector2(mid - half, size.y + 8.0)]), MAT)
	for side: float in [-1.0, 1.0]:
		var x := mid + side * (half - 16.0 * u)
		var y := top + 14.0 * u
		while y < size.y:
			b.stroke(PackedVector2Array([Vector2(x, y), Vector2(x, y + 16.0 * u)]), 4.0 * u, Color(MAT_HI, 0.9), false, true)
			y += 34.0 * u
	var cy := top + 54.0 * u
	while cy < size.y - 10.0 * u:
		var w := gate * 0.16
		b.stroke(PackedVector2Array([Vector2(mid - w, cy - w * 0.5), Vector2(mid, cy + w * 0.5), Vector2(mid + w, cy - w * 0.5)]),
			9.0 * u, Color(MAT_DEEP, 0.75), false, true)
		cy += 78.0 * u
	if open < FOOT_LEAST * u:
		return
	var k := clampf(open / (FOOT_FULL * u), 0.5, 1.0) * u
	var base := top + open * 0.55
	var left := (mid - half) * 0.5
	var right := mid + half + (size.x - mid - half) * 0.5
	# Left of the runner: a mallet, and what the plane left.
	_mallet(b, Vector2(left - 10.0 * k, base), k)
	_shaving(b, Vector2(left + 110.0 * k, base + 62.0 * k), 24.0 * k, 1.1)
	_shaving(b, Vector2(left - 118.0 * k, base - 58.0 * k), 18.0 * k, 3.4)
	# Right of it: spare blocks, a tin of wax, two dog holes.
	_piece(b, Vector2(right - 46.0 * k, base + 22.0 * k), Vector2(150.0, 72.0) * k, BAR, BAR_HI, BAR_DEEP, -0.10)
	_piece(b, Vector2(right - 74.0 * k, base - 50.0 * k), Vector2(70.0, 70.0) * k, SQ, SQ_HI, SQ_DEEP, 0.16)
	_tin(b, Vector2(right + 88.0 * k, base - 20.0 * k), 44.0 * k)
	for hx: float in [right + 20.0 * k, right + 110.0 * k]:
		var hole := Vector2(hx, base + 78.0 * k)
		b.disc(hole, 13.0 * k, Color(BRASS, 0.9))
		b.disc(hole, 9.0 * k, WALNUT_DEEP)
		b.disc(hole + Vector2(0.0, 2.5 * k), 6.5 * k, Color(0.0, 0.0, 0.0, 0.18))

## A block off the tray with no face: its shaded lip, its top and a lit
## band, `box` in size about `at`, turned `turn`.
func _piece(b: Face.Builder, at: Vector2, box: Vector2, ink: Color, hi: Color, deep: Color, turn: float) -> void:
	var p := Face.Builder.new()
	var r := minf(box.x, box.y) * 0.2
	p.fan(Face.Builder.round_rect(-box * 0.5 + Vector2(0.0, box.y * 0.10), box, r), Color(0.0, 0.0, 0.0, 0.10))
	p.fan(Face.Builder.round_rect(-box * 0.5 + Vector2(0.0, box.y * 0.06), box, r), deep)
	p.fan(Face.Builder.round_rect(-box * 0.5, box, r), ink)
	p.fan(Face.Builder.round_rect(-box * 0.5 + Vector2(box.x * 0.12, box.y * 0.12), Vector2(box.x * 0.76, box.y * 0.14),
		box.y * 0.07), Color(hi, 0.8))
	b.append(p.mesh(), Transform2D(turn, at))

## A mallet lying on the bench: a walnut head on an oak handle.
func _mallet(b: Face.Builder, at: Vector2, k: float) -> void:
	var p := Face.Builder.new()
	var handle := Vector2(190.0, 22.0) * k
	var head := Vector2(80.0, 124.0) * k
	p.fan(Face.Builder.round_rect(Vector2(-handle.x * 0.5, -handle.y * 0.5 + 6.0 * k), handle, handle.y * 0.5), Color(0.0, 0.0, 0.0, 0.10))
	p.fan(Face.Builder.round_rect(-handle * 0.5, handle, handle.y * 0.5), SHAVING_DEEP)
	p.fan(Face.Builder.round_rect(Vector2(-handle.x * 0.5 + 8.0 * k, -handle.y * 0.5 + 3.0 * k),
		Vector2(handle.x - 16.0 * k, handle.y * 0.25), handle.y * 0.12), Color(LIGHT, 0.5))
	var hx := handle.x * 0.5 - head.x * 0.35
	p.fan(Face.Builder.round_rect(Vector2(hx - head.x * 0.5, -head.y * 0.5 + 8.0 * k), head, 16.0 * k), Color(0.0, 0.0, 0.0, 0.12))
	p.fan(Face.Builder.round_rect(Vector2(hx - head.x * 0.5, -head.y * 0.5 + 5.0 * k), head, 16.0 * k), WALNUT_DEEP)
	p.fan(Face.Builder.round_rect(Vector2(hx - head.x * 0.5, -head.y * 0.5), head, 16.0 * k), WALNUT)
	p.fan(Face.Builder.round_rect(Vector2(hx - head.x * 0.5 + 10.0 * k, -head.y * 0.5 + 10.0 * k),
		Vector2(head.x * 0.22, head.y - 20.0 * k), 7.0 * k), Color(WALNUT_HI, 0.7))
	b.append(p.mesh(), Transform2D(-0.42, at))

## A curl off the plane: a pale ribbon wound once and a half, `r` across,
## started at `turn`.
func _shaving(b: Face.Builder, at: Vector2, r: float, turn: float) -> void:
	var pts := PackedVector2Array()
	for i in 22:
		var f := float(i) / 21.0
		var a := turn + f * TAU * 1.4
		pts.append(at + Vector2(cos(a), sin(a) * 0.8) * r * lerpf(1.0, 0.32, f))
	b.stroke(pts, r * 0.36, Color(SHAVING_DEEP, 0.55), false, true)
	b.stroke(pts, r * 0.24, SHAVING, false, true)

## A brass screw's head, slotted.
func _screw(b: Face.Builder, at: Vector2, r: float) -> void:
	b.disc(at + Vector2(0.0, r * 0.18), r, Color(0.0, 0.0, 0.0, 0.12))
	b.disc(at, r, BRASS)
	b.disc(at + Vector2(-r * 0.2, -r * 0.25), r * 0.5, Color(BRASS_HI, 0.8))
	b.stroke(PackedVector2Array([at + Vector2(-r * 0.6, r * 0.25), at + Vector2(r * 0.6, -r * 0.25)]), r * 0.24,
		Color(WALNUT_DEEP, 0.8), false, true)

## An open tin of wax, seen from above.
func _tin(b: Face.Builder, at: Vector2, r: float) -> void:
	b.disc(at + Vector2(0.0, r * 0.14), r, Color(0.0, 0.0, 0.0, 0.12))
	b.disc(at, r, TIN)
	b.disc(at, r * 0.86, TIN_HI)
	b.disc(at, r * 0.76, WAX)
	b.ellipse(at + Vector2(-r * 0.2, -r * 0.24), r * 0.34, r * 0.18, Color(LIGHT, 0.55))
