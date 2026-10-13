extends Control

## Trestle's world: the valley's morning sky, edge to edge under the board
## and the host's rows (CLAUDE.md: a game's world fills the screen). The
## board (puzzles/trestle2d.gd) already paints its valley from one edge of
## the screen to the other -- the hills, the banks, the river down to the
## foot -- so what was missing was the air over it: this file is the sky the
## board used to draw inside its card, with the far blue mountains standing
## on the board's horizon (`set_ground`), and the river's bed, which the
## board paints into its own still scene through `paint_bed`.
##
## The top of the screen is a cream morning mist, because the wordmark, the
## motto and the win's "Well done!" are ink; the blue comes in under the
## tools row. A small cloud and three far birds stand in the gap of that
## row.
##
## Two meshes: the sky, built when the rect changes and kept (`_shown`), and
## the mountains with the warm glow behind them, built for a grid step and
## moved with the horizon, so the win's slide rebuilds neither.

const Face = preload("res://ui/faces/face.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

## The screen the picture was drawn on; the sky's things scale with the width.
const W := 1080.0
## The sky's stops: [share of the height, colour].
const SKY := [
	[0.0, Color("fdf7ea")], [0.15, Color("f8f5ea")], [0.29, Color("c2e2f2")],
	[0.50, Color("b3dcf1")], [0.74, Color("e3eedd")], [1.0, Color("f6ecd6")],
]
const GLOW_HIGH := Color("f6ecd6", 0.0)
const GLOW_LOW := Color("fbe3b8", 0.8)
const PEAK := Color("b4cfe0")
const SNOW := Color("f4f8fb")
const CLOUD := Color("fdfdf8")
const BIRD := Color("7f97ad", 0.7)
## The gap of the tools row: one cloud [x, y as shares, radius at W] and the
## birds [x, y, half span at W].
const CLOUDS := [[0.455, 0.232, 26.0]]
const BIRDS := [[0.640, 0.226, 13.0], [0.690, 0.236, 10.0], [0.735, 0.224, 8.0]]
## The mountains, as the board had them: [share of the width, height in
## grid steps].
const PEAKS := [Vector2(0.1, 2.9), Vector2(0.33, 3.6), Vector2(0.55, 2.7), Vector2(0.78, 3.3), Vector2(1.0, 2.6)]

## The river's bed, under the board's water (`paint_bed`).
const BED := Color("9db7a6")
const BED_DEEP := Color("86a596")
const WEED := Color("4f8f6a")
const WEED_PALE := Color("6faa7e")
const STONE := Color("b9c3c0")
const STONE_DEEP := Color("8fa3a6")
const WOOD := Color("9a7850")
const WOOD_DEEP := Color("7b5d3c")

var _shown: ArrayMesh
var _peaks: Control
var _peaks_shown: ArrayMesh
var _peaks_u := 0.0
var _peaks_w := 0.0
var _horizon := -1.0
var _u := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_peaks = Control.new()
	_peaks.name = "Peaks"
	_peaks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_peaks.draw.connect(func() -> void:
		if _peaks_shown != null:
			_peaks.draw_mesh(_peaks_shown, null))
	add_child(_peaks)
	resized.connect(_build)
	_build()

func _draw() -> void:
	if _shown != null:
		draw_mesh(_shown, null)

## Where the board's horizon stands and its grid step: the mountains are
## built for the step and moved to the line.
func set_ground(horizon: float, u: float) -> void:
	_horizon = horizon
	_u = u
	_place_peaks()

func _build() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var s := size.x / W
	var b := Face.Builder.new()
	for i in SKY.size() - 1:
		var y0: float = size.y * float(SKY[i][0]) - (8.0 if i == 0 else 0.0)
		var y1: float = size.y * float(SKY[i + 1][0]) + (8.0 if i == SKY.size() - 2 else 0.0)
		var i0 := b.vertex(Vector2(-8.0, y0), SKY[i][1])
		var i1 := b.vertex(Vector2(size.x + 8.0, y0), SKY[i][1])
		var i2 := b.vertex(Vector2(size.x + 8.0, y1), SKY[i + 1][1])
		var i3 := b.vertex(Vector2(-8.0, y1), SKY[i + 1][1])
		b.tri(i0, i1, i2)
		b.tri(i0, i2, i3)
	for c in CLOUDS:
		Scenery.cloud(b, Vector2(c[0], c[1]) * size, c[2] * s, CLOUD)
	for bird in BIRDS:
		var at := Vector2(bird[0], bird[1]) * size
		var r: float = bird[2] * s
		b.stroke(PackedVector2Array([at + Vector2(-r, -r * 0.2), at + Vector2(-r * 0.45, -r * 0.55), at,
			at + Vector2(r * 0.45, -r * 0.55), at + Vector2(r, -r * 0.2)]), r * 0.22, BIRD)
	_shown = b.mesh()
	queue_redraw()
	_peaks.size = size
	_peaks_w = 0.0
	_place_peaks()

func _place_peaks() -> void:
	if _peaks == null or _u <= 0.0 or size.x <= 0.0:
		return
	if _peaks_u != _u or _peaks_w != size.x:
		# built round a horizon at y = 0
		var b := Face.Builder.new()
		var i0 := b.vertex(Vector2(-8.0, -_u * 3.0), GLOW_HIGH)
		var i1 := b.vertex(Vector2(size.x + 8.0, -_u * 3.0), GLOW_HIGH)
		var i2 := b.vertex(Vector2(size.x + 8.0, 0.0), GLOW_LOW)
		var i3 := b.vertex(Vector2(-8.0, 0.0), GLOW_LOW)
		b.tri(i0, i1, i2)
		b.tri(i0, i2, i3)
		for p: Vector2 in PEAKS:
			var top := Vector2(size.x * p.x, -_u * p.y)
			var half := _u * (2.2 + p.y * 0.5)
			b.polygon(PackedVector2Array([top, top + Vector2(half, _u * p.y + _u * 0.2), top + Vector2(-half, _u * p.y + _u * 0.2)]), PEAK)
			var cap := 0.26
			b.polygon(PackedVector2Array([top, top + Vector2(half * cap, _u * p.y * cap), top + Vector2(half * cap * 0.4, _u * p.y * cap * 0.8),
				top + Vector2(0.0, _u * p.y * cap * 1.1), top + Vector2(-half * cap * 0.5, _u * p.y * cap * 0.8), top + Vector2(-half * cap, _u * p.y * cap)]), SNOW)
		_peaks_shown = b.mesh()
		_peaks_u = _u
		_peaks_w = size.x
		_peaks.queue_redraw()
	_peaks.position = Vector2(0.0, _horizon)

## The river's bed, painted by the board into its own still scene (it lies
## under the board's water and between its banks, where a child of the board
## could not): gravel from `top` down to `bottom` across `width`, and on its
## left, clear of the host's button at the right of the foot, the things a
## river keeps -- stones, waterweed, a plank that went in and a cart wheel
## half in the gravel. `u` is the board's grid step; `left` and `right` are
## where the banks' faces stand.
static func paint_bed(b: Face.Builder, width: float, top: float, bottom: float, u: float, left: float, right: float) -> void:
	if bottom - top < u * 0.3:
		return
	var crest := PackedVector2Array()
	for k in 25:
		var x := width * k / 24.0
		crest.append(Vector2(x, top + u * (0.08 * sin(k * 1.1) + 0.05 * sin(k * 2.7 + 1.0))))
	crest.append(Vector2(width, bottom + 4.0))
	crest.append(Vector2(0.0, bottom + 4.0))
	b.polygon(crest, BED)
	var low := PackedVector2Array()
	for k in 25:
		var x := width * k / 24.0
		low.append(Vector2(x, top + u * (0.75 + 0.1 * sin(k * 0.8 + 2.0))))
	low.append(Vector2(width, bottom + 4.0))
	low.append(Vector2(0.0, bottom + 4.0))
	b.polygon(low, BED_DEEP)
	var room := right - left
	if room < u * 3.0:
		return
	# gravel along the crest, the whole way across
	for k in 11:
		var x := left + room * (0.06 + 0.088 * k)
		var y := top + u * (0.2 + 0.1 * ((k * 3) % 4))
		b.ellipse(Vector2(x, y), u * (0.1 + 0.03 * (k % 3)), u * 0.06, STONE_DEEP if k % 2 else STONE)
	# the left of the bed: three stones, weed, a plank, a wheel
	var at := Vector2(left + room * 0.10, top + u * 0.42)
	b.ellipse(at + Vector2(0.0, u * 0.05), u * 0.36, u * 0.22, STONE_DEEP)
	b.ellipse(at, u * 0.34, u * 0.2, STONE)
	b.ellipse(at + Vector2(u * 0.42, u * 0.12), u * 0.2, u * 0.12, STONE_DEEP)
	b.ellipse(at + Vector2(-u * 0.1, -u * 0.07), u * 0.12, u * 0.05, Color(1, 1, 1, 0.3))
	for k in 5:
		var foot := Vector2(left + room * (0.17 + 0.022 * k), top + u * 0.5)
		var tall := u * (0.55 + 0.22 * ((k * 2) % 3))
		var lean := u * (0.1 * (k - 2))
		b.stroke(PackedVector2Array([foot, foot + Vector2(lean * 0.4, -tall * 0.5), foot + Vector2(lean, -tall)]),
			u * 0.07, WEED if k % 2 else WEED_PALE)
	# a plank that went in, lying on the gravel
	var p0 := Vector2(left + room * 0.30, top + u * 0.62)
	var p1 := p0 + Vector2(u * 1.25, -u * 0.16)
	b.stroke(PackedVector2Array([p0 + Vector2(0.0, u * 0.03), p1 + Vector2(0.0, u * 0.03)]), u * 0.17, WOOD_DEEP, false, false)
	b.stroke(PackedVector2Array([p0, p1]), u * 0.14, WOOD, false, false)
	b.disc(p0.lerp(p1, 0.12), u * 0.03, WOOD_DEEP)
	b.disc(p0.lerp(p1, 0.88), u * 0.03, WOOD_DEEP)
	# a cart wheel, half in the gravel
	var hub := Vector2(left + room * 0.50, top + u * 0.66)
	var r := u * 0.3
	var rim := PackedVector2Array()
	for k in 13:
		rim.append(hub + Vector2.from_angle(PI + PI * k / 12.0) * r)
	b.stroke(rim, u * 0.07, WOOD_DEEP)
	for k in 3:
		b.stroke(PackedVector2Array([hub, hub + Vector2.from_angle(PI + PI * (k + 0.5) / 3.0) * r]), u * 0.035, WOOD_DEEP)
	b.disc(hub, u * 0.06, WOOD)
	for k in 3:
		var foot := Vector2(left + room * (0.56 + 0.02 * k), top + u * 0.55)
		b.stroke(PackedVector2Array([foot, foot + Vector2(u * 0.05 * (k - 1), -u * (0.4 + 0.15 * (k % 2)))]), u * 0.06, WEED_PALE if k % 2 else WEED)
