extends Control

## Sunbeam's world: the greenhouse itself, edge to edge under the floor and
## the host's rows (CLAUDE.md: a game's world fills the screen). It is the
## glass wall the board used to draw inside its card, at the size of the
## screen: morning light pale across the top, behind the wordmark; the sage
## panes and their white mullions from the wall's top rail down, with slant
## shafts of light falling through them; a small hanging shelf of seedlings
## in the gap of the tools row; and along the foot the potting bench, with a
## trough in flower, a watering can, a trowel and two potted plants.
##
## The top is light because of what lies over it: the wordmark, the motto
## and the win's "Well done!" are ink. Only glass lies under the floor.
##
## One mesh, built when the rect changes and kept (`_shown`) until the next
## replaces it; the motes in the light are a second, on a child whose alpha
## breathes (still under Motion.reduce). The colours are written here: the
## board preloads this file.

const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Face = preload("res://ui/faces/face.gd")
const CardFace = preload("res://ui/menu/cards/card_face.gd")
const Scenery = preload("res://ui/flat/scenery.gd")
const Parts = preload("res://ui/faces/sunbeam_parts.gd")

## The screen the picture was drawn on; everything scales with the width.
## What stands at the top is measured from the top and what stands on the
## bench from the foot, so a taller screen opens more glass between them.
const W := 1080.0
const LIGHT_TOP := Color("fdf8ec")
const GLASS_HIGH := Color("ecf4ec")
const GLASS_LOW := Color("d3e5d8")
const MULLION_INK := Color("fffdf8")
const CAN := Color("a9c4b6")
const CAN_DEEP := Color("7f9f8e")
## Where the light gives way to the glass, and the wall's top rail, from the
## top at W: the rail runs between the tools row and the floor's frame.
const GLASS_FROM := 330.0
const TOP_RAIL := 496.0
const PANES := 5
const MULLION := 10.0
## The sun's glow behind the wordmark: its middle as shares of the rect, and
## its rings as [radius at W, alpha].
const SUN_AT := Vector2(0.10, 0.02)
const SUN_RINGS := [[680.0, 0.10], [460.0, 0.12], [280.0, 0.16]]
## Slant shafts through the glass: [x of the top edge as a share, width as a
## share], alternately bright and soft.
const SHAFTS := [[-0.16, 0.12], [0.10, 0.05], [0.34, 0.15], [0.62, 0.06]]
const SHAFT_DRIFT := 0.36
## The hanging shelf in the gap of the tools row: its plank's ends as shares
## of the width, its top from the top at W, and the seedlings' size at W.
const SHELF := Vector2(0.345, 0.635)
const SHELF_Y := 470.0
const SHELF_POT := 64.0
## The bench along the foot: its top above the bottom edge, at W.
const BENCH := 58.0
## The motes: [x as a share, y from the top (positive) or from the foot
## (negative) at W, radius at W].
const MOTES := [[0.30, 438.0, 5.0], [0.70, 452.0, 4.0], [0.76, 410.0, 3.0],
	[0.62, -150.0, 4.0], [0.24, -176.0, 3.5], [0.90, -200.0, 4.5], [0.47, -128.0, 3.0]]
const BREATH := 3.6
const BREATH_LOW := 0.35

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
	var rail_y := TOP_RAIL * u
	var bench_y := size.y - BENCH * u
	# The morning light across the top, then the glass under it.
	var first := b.verts.size()
	b.polygon(PackedVector2Array([Vector2(-8.0, -8.0), Vector2(size.x + 8.0, -8.0),
		Vector2(size.x + 8.0, rail_y), Vector2(-8.0, rail_y)]), Color.WHITE)
	CardFace.shade(b, first, LIGHT_TOP, GLASS_HIGH, GLASS_FROM * u * 0.4, rail_y)
	first = b.verts.size()
	b.polygon(PackedVector2Array([Vector2(-8.0, rail_y), Vector2(size.x + 8.0, rail_y),
		Vector2(size.x + 8.0, size.y + 8.0), Vector2(-8.0, size.y + 8.0)]), Color.WHITE)
	CardFace.shade(b, first, GLASS_HIGH, GLASS_LOW, rail_y, size.y)
	var sun := SUN_AT * size
	for ring in SUN_RINGS:
		b.disc(sun, ring[0] * u, Color(Pal.BEAM, ring[1]))
	# The shafts, falling slant from the top rail to the bench.
	var drift := (bench_y - rail_y) * SHAFT_DRIFT
	for k in SHAFTS.size():
		var x0: float = size.x * float(SHAFTS[k][0])
		var w: float = size.x * float(SHAFTS[k][1])
		b.polygon(PackedVector2Array([Vector2(x0, rail_y), Vector2(x0 + w, rail_y),
			Vector2(x0 + w + drift, bench_y), Vector2(x0 + drift, bench_y)]),
			Color(Pal.BEAM_CORE, 0.5) if k % 2 == 0 else Color(Pal.BEAM, 0.14))
	# The wall's mullions and its top rail, white paint, and a long glint on
	# two of the panes.
	var pw := size.x / float(PANES)
	for k in range(1, PANES):
		var x := pw * float(k)
		b.fan(Face.Builder.round_rect(Vector2(x - MULLION * u * 0.5, rail_y), Vector2(MULLION * u, bench_y - rail_y),
			MULLION * u * 0.5), Color(MULLION_INK, 0.8))
	b.fan(Face.Builder.round_rect(Vector2(-8.0, rail_y - MULLION * u * 0.5), Vector2(size.x + 16.0, MULLION * u),
		MULLION * u * 0.5), Color(MULLION_INK, 0.85))
	for k: int in [0, 3]:
		var x0 := pw * float(k) + pw * 0.55
		var y0 := bench_y - 250.0 * u
		b.fan(PackedVector2Array([Vector2(x0, y0), Vector2(x0 + pw * 0.16, y0),
			Vector2(x0 - pw * 0.08, bench_y - 90.0 * u), Vector2(x0 - pw * 0.24, bench_y - 90.0 * u)]),
			Color(1.0, 1.0, 1.0, 0.3))
	_shelf(b, u)
	_bench(b, u, bench_y)
	_shown = b.mesh()
	queue_redraw()
	var mb := Face.Builder.new()
	for m in MOTES:
		var y: float = float(m[1]) * u if float(m[1]) >= 0.0 else size.y + float(m[1]) * u
		mb.disc(Vector2(size.x * float(m[0]), y), float(m[2]) * u, Color(Pal.BEAM_CORE, 0.9))
	_motes_shown = mb.mesh()
	_motes.size = size
	_motes.queue_redraw()

## The hanging shelf in the gap of the tools row: a plank on two cords with
## three seedlings on it, small, since "Well done!" stands under it on the win.
func _shelf(b: Face.Builder, u: float) -> void:
	var x0 := size.x * SHELF.x
	var x1 := size.x * SHELF.y
	var y := SHELF_Y * u
	for x: float in [x0 + 16.0 * u, x1 - 16.0 * u]:
		b.stroke(PackedVector2Array([Vector2(x, y - 86.0 * u), Vector2(x, y)]), 3.0 * u, Color(Pal.RAIL_DEEP, 0.7))
	b.fan(Face.Builder.round_rect(Vector2(x0, y + 4.0 * u), Vector2(x1 - x0, 12.0 * u), 5.0 * u), Pal.RAIL_DEEP)
	b.fan(Face.Builder.round_rect(Vector2(x0, y), Vector2(x1 - x0, 12.0 * u), 5.0 * u), Pal.RAIL)
	b.fan(Face.Builder.round_rect(Vector2(x0 + 8.0 * u, y + 2.0 * u), Vector2(x1 - x0 - 16.0 * u, 3.0 * u), 1.5 * u),
		Color(Pal.BEAM_CORE, 0.4))
	var s := SHELF_POT * u
	for k in 3:
		var at := Vector2(lerpf(x0, x1, 0.2 + 0.3 * float(k)), y - s * 0.3)
		if k == 1:
			# the middle one in flower
			Parts.pot(b, at, s * 0.9)
			for q in 2:
				var fh := at + Vector2((float(q) - 0.5) * s * 0.3, -s * (0.44 + 0.08 * float(q)))
				for i in 5:
					b.disc(fh + Vector2.from_angle(float(i) * TAU / 5.0) * s * 0.06, s * 0.06, Pal.FLOWER)
				b.disc(fh, s * 0.045, Pal.SUN)
		else:
			Parts.pot(b, at, s)

## The potting bench along the foot: its plank edge to edge, a trough of
## leaves and flowers, a watering can, a trowel and two potted plants.
func _bench(b: Face.Builder, u: float, y: float) -> void:
	# What stands on it first, so the plank's lip covers their feet.
	var h := 54.0 * u
	var x0 := size.x * 0.07
	var x1 := size.x * 0.50
	var ty := y - h
	var n := maxi(int((x1 - x0) / (h * 0.7)), 2)
	for row in 2:
		for i in n:
			var x := lerpf(x0 + h * 0.4, x1 - h * 0.4, (float(i) + 0.5 * float(row)) / float(n))
			var v := _hash(i + 3, 91 + row)
			var r := h * (0.42 + 0.14 * v) * (1.0 if row == 0 else 0.85)
			var c := Vector2(x, ty - r * 0.3 + float(row) * h * 0.12)
			b.disc(c, r, Pal.LEAF_DEEP if row == 0 else Pal.LEAF)
			b.disc(c + Vector2(-r * 0.25, -r * 0.3), r * 0.45, Color(Pal.LEAF_LIGHT, 0.55 if row == 1 else 0.3))
	for i in n / 2:
		var x := lerpf(x0 + h, x1 - h, (float(i) + 0.3) / float(maxi(n / 2, 1)))
		var v := _hash(i + 5, 57)
		Parts.leaf(b, Vector2(x, ty - h * 0.25), h * (0.55 + 0.3 * v), -PI * 0.5 + (v - 0.5) * 1.2,
			Pal.LEAF_LIGHT if i % 2 == 0 else Pal.LEAF)
	for i in 4:
		var fh := Vector2(lerpf(x0 + 40.0 * u, x1 - 40.0 * u, float(i) / 3.0) + (_hash(i, 7) - 0.5) * 24.0 * u,
			ty - h * (0.45 + 0.3 * _hash(i, 13)))
		for q in 5:
			b.disc(fh + Vector2.from_angle(float(q) * TAU / 5.0) * h * 0.12, h * 0.12, Pal.FLOWER if i % 2 == 0 else Pal.SURFACE)
		b.disc(fh, h * 0.09, Pal.SUN)
	b.fan(PackedVector2Array([Vector2(x0, ty), Vector2(x1, ty), Vector2(x1 - 12.0 * u, y + 4.0 * u),
		Vector2(x0 + 12.0 * u, y + 4.0 * u)]), Pal.POT_CLAY)
	b.fan(Face.Builder.round_rect(Vector2(x0 - 8.0 * u, ty - 6.0 * u), Vector2(x1 - x0 + 16.0 * u, 15.0 * u), 6.0 * u), Pal.POT_RIM)
	b.fan(Face.Builder.round_rect(Vector2(x0 + 26.0 * u, ty + 18.0 * u), Vector2((x1 - x0) * 0.3, 5.0 * u), 2.5 * u),
		Color(1.0, 1.0, 1.0, 0.18))
	# The watering can: its spout out to the left, its handle behind.
	var can := Vector2(size.x * 0.635, y - 46.0 * u)
	var cw := 62.0 * u
	var ch := 46.0 * u
	b.stroke(Face.Builder.arc_points(can + Vector2(cw * 0.62, -ch * 0.1), ch * 0.62, -PI * 0.5, PI * 0.5),
		9.0 * u, CAN_DEEP)
	b.stroke(PackedVector2Array([can + Vector2(-cw * 0.5, ch * 0.5), can + Vector2(-cw * 1.25, -ch * 0.75)]), 12.0 * u, CAN_DEEP)
	b.ellipse(can + Vector2(-cw * 1.3, -ch * 0.82), 15.0 * u, 9.0 * u, CAN)
	b.fan(Face.Builder.round_rect(can - Vector2(cw, ch) * 0.5 + Vector2(0.0, 4.0 * u), Vector2(cw, ch * 1.0), 10.0 * u), CAN_DEEP)
	b.fan(Face.Builder.round_rect(can - Vector2(cw, ch) * 0.5, Vector2(cw, ch * 0.96), 10.0 * u), CAN)
	b.fan(Face.Builder.round_rect(can - Vector2(cw, ch) * 0.5 + Vector2(8.0 * u, 8.0 * u), Vector2(8.0 * u, ch * 0.6), 4.0 * u),
		Color(1.0, 1.0, 1.0, 0.4))
	# A trowel leant against the can.
	var tr0 := Vector2(size.x * 0.735, y - 2.0 * u)
	var tr1 := tr0 + Vector2(26.0 * u, -70.0 * u)
	b.stroke(PackedVector2Array([tr0, tr0.lerp(tr1, 0.5)]), 16.0 * u, CAN_DEEP)
	b.stroke(PackedVector2Array([tr0.lerp(tr1, 0.5), tr1]), 9.0 * u, Pal.RAIL)
	b.disc(tr1, 6.0 * u, Pal.RAIL_DEEP)
	# Two potted plants at the right end.
	Parts.pot(b, Vector2(size.x * 0.855, y - 104.0 * u * 0.3), 104.0 * u)
	Parts.pot(b, Vector2(size.x * 0.945, y - 82.0 * u * 0.3), 82.0 * u, 0.3)
	# The plank itself, its lit top edge and the shade under its lip.
	b.fan(PackedVector2Array([Vector2(-8.0, y), Vector2(size.x + 8.0, y), Vector2(size.x + 8.0, size.y + 8.0),
		Vector2(-8.0, size.y + 8.0)]), Pal.RAIL_DEEP)
	b.fan(PackedVector2Array([Vector2(-8.0, y), Vector2(size.x + 8.0, y), Vector2(size.x + 8.0, y + 30.0 * u),
		Vector2(-8.0, y + 30.0 * u)]), Pal.RAIL)
	b.fan(PackedVector2Array([Vector2(-8.0, y), Vector2(size.x + 8.0, y), Vector2(size.x + 8.0, y + 5.0 * u),
		Vector2(-8.0, y + 5.0 * u)]), Color(Pal.BEAM_CORE, 0.45))
	for k in 3:
		var gx := size.x * (0.18 + 0.31 * float(k))
		b.fan(Face.Builder.round_rect(Vector2(gx, y + 14.0 * u), Vector2(size.x * 0.12, 3.0 * u), 1.5 * u),
			Color(Pal.RAIL_DEEP, 0.5))

## A stable hash of two ints, 0 to 1 (the board's own).
static func _hash(a: int, c: int) -> float:
	var h := (a * 374761393 + c * 668265263) ^ (a * c * 1274126177)
	h = (h ^ (h >> 13)) * 1274126177
	return float((h ^ (h >> 16)) & 0x7fffffff) / float(0x7fffffff)
