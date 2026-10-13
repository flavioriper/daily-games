extends Control

## Bridges' world: the sea, edge to edge under the board and the host's rows
## (CLAUDE.md: a game's world fills the screen). It is the menu card's
## lagoon (ui/menu/cards/bridges.gd) at the size of the screen, in the
## board's own pale water so the islets stand on it as they stood in their
## pool: a morning mist over the top, where the wordmark and the motto are
## ink; the open water under the lattice, with nothing on it; and the beach
## along the foot, where nothing lies over it while the board is played --
## a jetty of the board's planks run out from the sand with a lantern on its
## far post, a stack of spare planks, a dinghy pulled up, rocks, lily pads
## and dune grass. Two pads and a buoy float in the gap of the tools row.
##
## Lantern Night (`set_night`) lays the board's dusk over all of it but the
## top, which stays light for the ink.
##
## One mesh, built when the rect or the night changes and kept (`_shown`)
## until the next replaces it; the glints on the water and the lantern's
## glow are a second, on a child whose alpha breathes (still under
## Motion.reduce). The colours are written here: the board preloads this
## file, so this file cannot preload the board.

const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Face = preload("res://ui/faces/face.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

## The screen the picture was drawn on; everything scales with the width.
const W := 1080.0
## The air and the water, top to foot, as [share of the height, colour]. The
## two blues are the board's own (WATER_HI let down into PAPER).
const MIST_TOP := Color("fdf7ea")
const SEA_PALE := Color("92c5e6")
const SEA := Color("6eb6e8")
const SEA_LOW := Color("5fa9df")
const STOPS := [
	[0.0, MIST_TOP], [0.09, Color("f1f4ea")], [0.17, Color("c9e2ec")],
	[0.235, SEA_PALE], [0.285, SEA], [0.80, SEA], [1.0, SEA_LOW],
]
const SUN_AT := Vector2(0.10, 0.02)
const SUN_RINGS := [[620.0, 0.30], [400.0, 0.35], [230.0, 0.45]]
const SUN := Color("fff1c9")
## The beach: the waterline as heights over the foot at W (left end, two
## handles, right end), and its sands.
const SHORE := [215.0, 310.0, 140.0, 250.0]
const SAND := Color("f0dfba")
const SAND_WET := Color("dcc391")
const SAND_LOW := Color("e7d2a6")
const FOAM := Color("fffdf8")
const WOOD := Color("c99a63")
const WOOD_LIT := Color("dcb37f")
const WOOD_DEEP := Color("9a7042")
const POST := Color("7d5a36")
const ROCK := Color("9ba5ad")
const ROCK_LIT := Color("bcc5cb")
const SHADE := Color("336e99")
const PAD := Color("7fb86a")
const PAD_DEEP := Color("5f9a52")
const HULL := Color("f6ead2")
const HULL_IN := Color("d9bb8b")
const LANTERN := Color("f7c66b")
const BUOY := Color("ea7c63")
## The night's veil (the board's NIGHT_ALPHA of MOON_DEEP) and where it
## starts and is whole, as shares of the height.
const NIGHT := Color("6273c0")
const NIGHT_ALPHA := 0.42
const NIGHT_FROM := 0.17
const NIGHT_FULL := 0.285
## The glints that breathe on the foot's water: [x share, height over the
## foot at W, radius at W].
const GLINTS := [[0.36, 372.0, 13.0], [0.57, 292.0, 15.0], [0.88, 362.0, 12.0],
	[0.09, 342.0, 11.0], [0.70, 398.0, 10.0]]
const BREATH := 3.4
const BREATH_LOW := 0.3

var _night := false
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

## Lantern Night's dusk over the water, or the day back.
func set_night(on: bool) -> void:
	if on == _night:
		return
	_night = on
	_build()

func _build() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var u := size.x / W
	var foot := size.y
	var b := Face.Builder.new()
	_bands(b, STOPS, 1.0)
	var sun := SUN_AT * size
	for ring in SUN_RINGS:
		Scenery.soft_disc(b, sun, ring[0] * u, ring[0] * u, Color(SUN, ring[1]))
	# The gap of the tools row: two pads, a buoy and a ripple or two.
	_pad(b, Vector2(0.395 * size.x, 0.236 * size.y), 20.0 * u, 0.6, true)
	_pad(b, Vector2(0.445 * size.x, 0.226 * size.y), 13.0 * u, 2.4, false)
	_buoy(b, Vector2(0.625 * size.x, 0.232 * size.y), 13.0 * u)
	_ripple(b, Vector2(0.52 * size.x, 0.244 * size.y), 44.0 * u, u)
	_ripple(b, Vector2(0.72 * size.x, 0.224 * size.y), 34.0 * u, u)
	# The foot's open water.
	for r in [[0.30, 408.0, 54.0], [0.47, 352.0, 46.0], [0.66, 330.0, 58.0],
			[0.83, 418.0, 44.0], [0.05, 420.0, 40.0], [0.93, 300.0, 36.0]]:
		_ripple(b, Vector2(r[0] * size.x, foot - r[1] * u), r[2] * u, u)
	_rocks(b, Vector2(0.065 * size.x, foot - 292.0 * u), 30.0 * u)
	_rocks(b, Vector2(0.945 * size.x, foot - 318.0 * u), 26.0 * u)
	_pad(b, Vector2(0.44 * size.x, foot - 296.0 * u), 24.0 * u, 1.1, true)
	_pad(b, Vector2(0.49 * size.x, foot - 276.0 * u), 15.0 * u, 3.0, false)
	_pad(b, Vector2(0.745 * size.x, foot - 300.0 * u), 19.0 * u, 4.2, false)
	# The beach: shallows, foam, the wet sand and the dry.
	var shore := _shore(u)
	b.stroke(shore, 150.0 * u, Color(SEA_PALE, 0.35), false, false)
	b.stroke(shore, 70.0 * u, Color(SEA_PALE, 0.5), false, false)
	b.stroke(shore, 26.0 * u, Color(FOAM, 0.6), false, false)
	_land(b, shore, 0.0, SAND_WET, SAND_WET)
	_land(b, shore, 30.0 * u, SAND, SAND_LOW)
	_rocks(b, Vector2(0.615 * size.x, foot - 196.0 * u), 24.0 * u)
	# The jetty, run out from the sand, and its shadow on the water.
	var pier_x := 0.215 * size.x
	var pier_w := 92.0 * u
	var pier_top := foot - 322.0 * u
	var pier_low := foot - 150.0 * u
	b.fan(Face.Builder.round_rect(Vector2(pier_x - pier_w * 0.5 + 8.0 * u, pier_top + 12.0 * u),
		Vector2(pier_w, pier_low - pier_top), 8.0 * u), Color(SHADE, 0.22))
	var slat := 24.0 * u
	var y := pier_top
	var k := 0
	while y < pier_low - 1.0:
		var h := minf(slat, pier_low - y) - 4.0 * u
		var jog := (float(k % 3) - 1.0) * 3.0 * u
		_plank(b, Vector2(pier_x - pier_w * 0.5 + jog, y), Vector2(pier_w, h), u)
		y += slat
		k += 1
	for side in [-1.0, 1.0]:
		for py in [pier_top + 10.0 * u, (pier_top + pier_low) * 0.5]:
			b.disc(Vector2(pier_x + side * (pier_w * 0.5 + 2.0 * u), py + 3.0 * u), 10.0 * u, WOOD_DEEP)
			b.disc(Vector2(pier_x + side * (pier_w * 0.5 + 2.0 * u), py), 10.0 * u, POST)
			b.disc(Vector2(pier_x + side * (pier_w * 0.5 + 2.0 * u) - 2.0 * u, py - 2.0 * u), 4.5 * u, WOOD)
	# A stack of spare planks on the sand.
	var stack := Vector2(0.50 * size.x, foot - 92.0 * u)
	for i in 3:
		var turn := [-0.10, 0.07, -0.03][i] as float
		var at := stack + Vector2((i - 1) * 10.0 * u, -i * 15.0 * u)
		_turned(b, at, turn, Vector2(190.0 * u, 26.0 * u), u)
	# The dinghy pulled up, and its oar.
	_dinghy(b, Vector2(0.80 * size.x, foot - 112.0 * u), -0.42, u)
	# Dune grass, a starfish and pebbles.
	for t in [[0.045, 150.0, 34.0], [0.095, 118.0, 26.0], [0.345, 58.0, 30.0],
			[0.395, 84.0, 22.0], [0.665, 54.0, 30.0], [0.955, 150.0, 30.0], [0.915, 44.0, 24.0]]:
		Scenery.tuft(b, Vector2(t[0] * size.x, foot - t[1] * u), t[2] * u)
	_star(b, Vector2(0.305 * size.x, foot - 118.0 * u), 15.0 * u)
	for p in [[0.13, 62.0, 7.0], [0.16, 50.0, 5.0], [0.58, 132.0, 6.0], [0.62, 48.0, 5.0], [0.265, 40.0, 6.0]]:
		b.ellipse(Vector2(p[0] * size.x, foot - p[1] * u), p[2] * u * 1.3, p[2] * u, ROCK_LIT)
	if _night:
		_bands(b, [[NIGHT_FROM, Color(NIGHT, 0.0)], [NIGHT_FULL, Color(NIGHT, NIGHT_ALPHA)],
			[1.0, Color(NIGHT, NIGHT_ALPHA)]], 0.0)
		for s in [[0.33, 400.0, 6.0], [0.55, 345.0, 5.0], [0.78, 388.0, 6.0], [0.12, 380.0, 5.0], [0.90, 262.0, 5.0]]:
			b.polygon(_star_pts(Vector2(s[0] * size.x, foot - s[1] * u), s[2] * u * 1.6, 0.45), Color(Pal.SUN_RAY, 0.55))
	# The lantern on the jetty's far post, lit over the dusk.
	var post := Vector2(pier_x + pier_w * 0.5 + 2.0 * u, pier_top + 10.0 * u)
	b.stroke(PackedVector2Array([post, post + Vector2(0.0, -58.0 * u)]), 7.0 * u, POST)
	var lamp := post + Vector2(0.0, -76.0 * u)
	b.fan(Face.Builder.round_rect(lamp - Vector2(15.0, 20.0) * u, Vector2(30.0, 40.0) * u, 10.0 * u), LANTERN)
	b.fan(Face.Builder.round_rect(lamp - Vector2(9.0, 12.0) * u, Vector2(18.0, 24.0) * u, 7.0 * u), Color(FOAM, 0.55))
	b.fan(Face.Builder.round_rect(lamp - Vector2(11.0, 25.0) * u, Vector2(22.0, 7.0) * u, 3.0 * u), POST)
	b.fan(Face.Builder.round_rect(lamp + Vector2(-11.0, 18.0) * u, Vector2(22.0, 6.0) * u, 3.0 * u), POST)
	_shown = b.mesh()
	queue_redraw()
	var gb := Face.Builder.new()
	Scenery.soft_disc(gb, lamp, 70.0 * u, 70.0 * u, Color(LANTERN, 0.38 if _night else 0.22))
	for g in GLINTS:
		gb.polygon(_star_pts(Vector2(g[0] * size.x, foot - g[1] * u), g[2] * u, 0.30), Color(FOAM, 0.9))
	_glints_shown = gb.mesh()
	_glints.size = size
	_glints.queue_redraw()

## Bands across the whole rect between `stops` ([share of the height,
## colour]), each shaded from its own colour to the next; `over` is how far
## the first and last run past the rect's top and foot, in rects.
func _bands(b: Face.Builder, stops: Array, over: float) -> void:
	var x0 := -8.0
	var x1 := size.x + 8.0
	for i in stops.size() - 1:
		var y0: float = float(stops[i][0]) * size.y
		var y1: float = float(stops[i + 1][0]) * size.y
		if i == 0:
			y0 -= over * size.y
		if i == stops.size() - 2:
			y1 += over * size.y + 8.0
		var c0: Color = stops[i][1]
		var c1: Color = stops[i + 1][1]
		var first := b.vertex(Vector2(x0, y0), c0)
		b.vertex(Vector2(x1, y0), c0)
		b.vertex(Vector2(x1, y1), c1)
		b.vertex(Vector2(x0, y1), c1)
		b.tri(first, first + 1, first + 2)
		b.tri(first, first + 2, first + 3)

## The waterline, left to right.
func _shore(u: float) -> PackedVector2Array:
	var foot := size.y
	var from := Vector2(-8.0, foot - SHORE[0] * u)
	var to := Vector2(size.x + 8.0, foot - SHORE[3] * u)
	var pts := Face.Builder.bezier3(from, Vector2(size.x * 0.30, foot - SHORE[1] * u),
		Vector2(size.x * 0.62, foot - SHORE[2] * u), to, 40)
	pts.append(to)
	return pts

## The land under the line `shore` dropped by `drop`, shaded `top` at the
## line to `low` at the foot. It runs well past the foot: the world slides
## under the board on the win.
func _land(b: Face.Builder, shore: PackedVector2Array, drop: float, top: Color, low: Color) -> void:
	var end := size.y * 2.0
	for i in shore.size() - 1:
		var a := shore[i] + Vector2(0.0, drop)
		var c := shore[i + 1] + Vector2(0.0, drop)
		var first := b.vertex(a, top)
		b.vertex(c, top)
		b.vertex(Vector2(c.x, size.y), low)
		b.vertex(Vector2(a.x, size.y), low)
		b.vertex(Vector2(c.x, end), low)
		b.vertex(Vector2(a.x, end), low)
		b.tri(first, first + 1, first + 2)
		b.tri(first, first + 2, first + 3)
		b.tri(first + 3, first + 2, first + 4)
		b.tri(first + 3, first + 4, first + 5)

## One plank lying flat: its edge under it, its face and a lit strip.
func _plank(b: Face.Builder, at: Vector2, box: Vector2, u: float) -> void:
	var r := minf(6.0 * u, box.y * 0.4)
	b.fan(Face.Builder.round_rect(at + Vector2(0.0, 4.0 * u), box, r), WOOD_DEEP)
	b.fan(Face.Builder.round_rect(at, box, r), WOOD)
	b.fan(Face.Builder.round_rect(at + Vector2(box.x * 0.06, box.y * 0.16),
		Vector2(box.x * 0.88, box.y * 0.26), r * 0.5), Color(WOOD_LIT, 0.8))

## A plank of `box` about `at`, turned.
func _turned(b: Face.Builder, at: Vector2, turn: float, box: Vector2, u: float) -> void:
	var xf := Transform2D(turn, at)
	var r := 7.0 * u
	b.fan(xf * Face.Builder.round_rect(-box * 0.5 + Vector2(0.0, 6.0 * u), box, r), WOOD_DEEP)
	b.fan(xf * Face.Builder.round_rect(-box * 0.5, box, r), WOOD)
	b.fan(xf * Face.Builder.round_rect(-box * 0.5 + Vector2(box.x * 0.05, box.y * 0.16),
		Vector2(box.x * 0.9, box.y * 0.26), r * 0.5), Color(WOOD_LIT, 0.8))
	for k in [-0.3, 0.05, 0.34]:
		b.stroke(xf * PackedVector2Array([Vector2(box.x * k, -box.y * 0.5 + 3.0 * u),
			Vector2(box.x * k, box.y * 0.5 - 3.0 * u)]), 2.0 * u, Color(WOOD_DEEP, 0.4))

## The dinghy from above, its bow up the beach, with two thwarts and an oar
## laid beside it.
func _dinghy(b: Face.Builder, at: Vector2, turn: float, u: float) -> void:
	var xf := Transform2D(turn, at)
	var l := 112.0 * u
	var w := 46.0 * u
	Scenery.soft_disc(b, at + Vector2(10.0, 16.0) * u, l * 1.15, w * 1.5, Color(WOOD_DEEP, 0.28))
	var hull := _hull(l, w)
	b.polygon(xf * _hull(l + 5.0 * u, w + 5.0 * u), WOOD_DEEP)
	b.polygon(xf * hull, HULL)
	b.polygon(xf * _hull(l - 12.0 * u, w - 11.0 * u), HULL_IN)
	for k in [-0.28, 0.30]:
		var half := (w - 9.0 * u) * (0.96 if k < 0.0 else 0.84)
		b.stroke(xf * PackedVector2Array([Vector2(l * k, -half), Vector2(l * k, half)]), 13.0 * u, HULL, false, false)
	var oar := Transform2D(turn + 0.16, at + Vector2(-26.0, 78.0) * u)
	b.stroke(oar * PackedVector2Array([Vector2(-96.0 * u, 0.0), Vector2(70.0 * u, 0.0)]), 6.0 * u, WOOD)
	b.fan(oar * Face.Builder.round_rect(Vector2(64.0, -11.0) * u, Vector2(54.0, 22.0) * u, 9.0 * u), WOOD_LIT)

## A boat's outline `l` half long and `w` half wide: a pointed bow at +x, a
## flat stern at -x.
func _hull(l: float, w: float) -> PackedVector2Array:
	var pts := PackedVector2Array([Vector2(-l, -w * 0.78)])
	pts.append_array(Face.Builder.bezier3(Vector2(-l * 0.9, -w), Vector2(-l * 0.1, -w * 1.08),
		Vector2(l * 0.62, -w * 0.82), Vector2(l, 0.0), 14))
	pts.append_array(Face.Builder.bezier3(Vector2(l, 0.0), Vector2(l * 0.62, w * 0.82),
		Vector2(-l * 0.1, w * 1.08), Vector2(-l * 0.9, w), 14))
	pts.append(Vector2(-l * 0.9, w))
	pts.append(Vector2(-l, w * 0.78))
	return pts

## Two rocks, the big one and a smaller beside it, with their shadow on the
## water.
func _rocks(b: Face.Builder, at: Vector2, r: float) -> void:
	Scenery.soft_disc(b, at + Vector2(r * 0.3, r * 0.5), r * 2.0, r * 0.9, Color(SHADE, 0.28))
	for part in [[Vector2.ZERO, 1.0], [Vector2(1.15, 0.28), 0.56]]:
		var c: Vector2 = at + (part[0] as Vector2) * r
		var rs: float = r * float(part[1])
		b.ellipse(c + Vector2(0.0, rs * 0.14), rs * 1.1, rs * 0.86, ROCK.darkened(0.14))
		b.ellipse(c, rs * 1.1, rs * 0.8, ROCK)
		b.ellipse(c + Vector2(-rs * 0.25, -rs * 0.28), rs * 0.6, rs * 0.34, ROCK_LIT)

## A lily pad with its notch at `turn`, and a white bloom on it or not.
func _pad(b: Face.Builder, at: Vector2, r: float, turn: float, bloom: bool) -> void:
	Scenery.soft_disc(b, at + Vector2(0.0, r * 0.35), r * 1.3, r * 0.8, Color(SHADE, 0.22))
	var pts := PackedVector2Array([at])
	for i in 23:
		var a := turn + 0.3 + (TAU - 0.6) * float(i) / 22.0
		pts.append(at + Vector2(cos(a) * r, sin(a) * r * 0.86))
	b.polygon(pts, PAD_DEEP)
	var top := PackedVector2Array([at + Vector2(0.0, -r * 0.08)])
	for i in 23:
		var a := turn + 0.3 + (TAU - 0.6) * float(i) / 22.0
		top.append(at + Vector2(0.0, -r * 0.08) + Vector2(cos(a) * r * 0.92, sin(a) * r * 0.78))
	b.polygon(top, PAD)
	if bloom:
		var c := at + Vector2(r * 0.2, -r * 0.2)
		for i in 5:
			b.ellipse(c + Vector2.from_angle(TAU * i / 5.0) * r * 0.26, r * 0.22, r * 0.2, FOAM)
		b.disc(c, r * 0.15, Pal.SUN_RAY)

## A float on the water: its ring of foam, its red body and white band.
func _buoy(b: Face.Builder, at: Vector2, r: float) -> void:
	b.stroke(Face.Builder.ring(at + Vector2(0.0, r * 0.5), r * 1.9, r * 1.1), r * 0.16, Color(FOAM, 0.6), true)
	b.disc(at + Vector2(0.0, r * 0.14), r, BUOY.darkened(0.18))
	b.disc(at, r, BUOY)
	b.disc(at, r * 0.55, FOAM)
	b.disc(at, r * 0.26, BUOY)

## A ripple: a short white dash with a bow in it and a shorter twin under.
func _ripple(b: Face.Builder, at: Vector2, span: float, u: float) -> void:
	b.stroke(Face.Builder.bezier2(at, at + Vector2(span * 0.5, -8.0 * u), at + Vector2(span, 0.0)),
		5.0 * u, Color(FOAM, 0.7))
	var twin := at + Vector2(span * 0.3, 16.0 * u)
	b.stroke(Face.Builder.bezier2(twin, twin + Vector2(span * 0.3, -5.0 * u), twin + Vector2(span * 0.6, 0.0)),
		4.0 * u, Color(FOAM, 0.5))

## A starfish on the sand.
func _star(b: Face.Builder, at: Vector2, r: float) -> void:
	b.polygon(_star_pts(at + Vector2(0.0, r * 0.12), r, 0.45), BUOY.darkened(0.2))
	b.polygon(_star_pts(at, r, 0.45), BUOY.lightened(0.15))

## A star's outline: five points for a `waist` of 0.45, four pinched ones
## for less.
func _star_pts(at: Vector2, r: float, waist: float) -> PackedVector2Array:
	var n := 10 if waist >= 0.4 else 8
	var pts := PackedVector2Array()
	for i in n:
		pts.append(at + Vector2.from_angle(-PI * 0.5 + i * TAU / n) * (r if i % 2 == 0 else r * waist))
	return pts
