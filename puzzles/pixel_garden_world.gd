extends Control

## Pixel Garden's world: the craft mat edge to edge under the board and the
## host's rows (CLAUDE.md: a game's world fills the screen). It is the menu
## card's pale aqua cutting mat (ui/menu/cards/pixelgarden.gd) at the size of
## the screen: cream in the window's light across the top, where the
## wordmark is ink; the mat's faint cutting grid from under the tools row
## down; a few loose beads in the gap of the tools row; and along the foot,
## under the tray, what a bead table has lying about -- a jar of beads on
## its side with a spill running out of it, a pair of tweezers, a sheet of
## ironing paper with a small bead flower done on it, and a ruler printed
## along the mat's bottom edge.
##
## The boards differ in height (a two-row bead box is taller), so the board
## says where its tray ends (`set_foot`) and the foot's things fit the band
## left, or stay out of a band too thin for them.
##
## Nothing here has a face: the iron is the board's. One mesh, built when
## the rect or the foot changes and kept (`_shown`) until the next replaces
## it; six glints are a second, on a child whose alpha breathes (still under
## Motion.reduce). The colours are written here: the board preloads this
## file.

const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Face = preload("res://ui/faces/face.gd")
const Bead = preload("res://ui/faces/bead.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

## The screen the picture was drawn on; everything scales with the width.
const W := 1080.0
const LIGHT := Color("fdf8ea")
const MAT_TOP := Color("e6f5f2")
const MAT_LOW := Color("cbe6e1")
const MAT_GRID := Color("a9d3cd")
const INK := Color("7fb3ac")
const PAPER := Color("fbf6e8")
const PAPER_DEEP := Color("e3d9c0")
const GLASS := Color("eef8f7")
const GLASS_DEEP := Color("9cc6c1")
const LID := Color("c89a6c")
const LID_DEEP := Color("9a6f48")
const STEEL := Color("b9c4c8")
const STEEL_DEEP := Color("8796a0")
## Where the window's light gives way to the mat, as shares of the height.
const LIGHT_TO := 0.16
const MAT_FROM := 0.275
## The grid's step at W, and every which line is the heavier one.
const GRID := 90.0
const GRID_BOLD := 4
## The loose beads in the gap of the tools row: [x, y as shares, PG_BEADS
## key]. Small, since they lie over "Well done!" on the win.
const GAP_BEADS := [[0.372, 0.2365, "rose"], [0.418, 0.2285, "yellow"], [0.548, 0.2380, "teal"],
	[0.652, 0.2290, "lilac"], [0.700, 0.2372, "green"]]
const GAP_BEAD := 30.0
## The least open foot (at W) the foot's things are drawn in, and the foot
## they are drawn whole in.
const FOOT_LEAST := 96.0
const FOOT_WHOLE := 170.0
## The spill out of the jar: [x as a share, up from the bottom at W, key].
const SPILL := [[0.228, 44.0, "rose"], [0.262, 66.0, "sky"], [0.292, 38.0, "yellow"],
	[0.327, 58.0, "green"], [0.356, 34.0, "orange"], [0.395, 50.0, "lilac"], [0.452, 40.0, "pink"]]
## The flower on the ironing paper, a row a string: R a petal, Y its eye,
## G the stem and leaves.
const FLOWER: Array[String] = [".R.R.", "RRYRR", ".RRR.", "G.G..", ".GG.."]
const FLOWER_KEYS := {"R": "rose", "Y": "yellow", "G": "green"}
## The glints: [x as a share, y as a share (negative: up from the bottom at
## W), radius at W].
const GLINTS := [[0.395, 0.2300, 9.0], [0.610, 0.2360, 8.0], [0.125, -70.0, 11.0],
	[0.340, -62.0, 8.0], [0.660, -58.0, 9.0], [0.900, -84.0, 10.0]]
const TWINKLE := 3.4
const TWINKLE_LOW := 0.3

var _shown: ArrayMesh
var _glints: Control
var _glints_shown: ArrayMesh
var _twinkle: Tween
## Where the board's tray ends, in this rect's pixels; 0 before it is told.
var _foot := 0.0

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
	_twinkle = Motion.pulse(_glints, "modulate:a", 1.0, TWINKLE_LOW, TWINKLE)

func _draw() -> void:
	if _shown != null:
		draw_mesh(_shown, null)

## The board's tray ends at `y`: the foot's things are fitted to what is
## left under it. Built again only when it moves.
func set_foot(y: float) -> void:
	if is_equal_approx(y, _foot):
		return
	_foot = y
	_build()

func _build() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var u := size.x / W
	var b := Face.Builder.new()
	# The window's light, then the mat coming up out of it. Run past the
	# edges: the board shrinks on the win and this is held against it.
	_band(b, -size.y * 0.5, size.y * LIGHT_TO, LIGHT, LIGHT)
	_band(b, size.y * LIGHT_TO, size.y * MAT_FROM, LIGHT, MAT_TOP)
	_band(b, size.y * MAT_FROM, size.y, MAT_TOP, MAT_LOW)
	_band(b, size.y, size.y * 1.5, MAT_LOW, MAT_LOW)
	var sun := Vector2(0.10, 0.02) * size
	for ring: Array in [[620.0, 0.22], [420.0, 0.26], [250.0, 0.32]]:
		Scenery.soft_disc(b, sun, float(ring[0]) * u, float(ring[0]) * u, Color(Color.WHITE, float(ring[1])))
	_grid(b, u)
	for g: Array in GAP_BEADS:
		Bead.bead(b, Vector2(float(g[0]), float(g[1])) * size, GAP_BEAD * u, Pal.PG_BEADS[String(g[2])],
			Vector2.ONE, 1.0, 0.0, 0.0, 0.0, MAT_TOP, false)
	_ruler(b, u)
	var open := (size.y - _foot) / u if _foot > 0.0 else FOOT_WHOLE
	if open >= FOOT_LEAST:
		_foot_things(b, u, clampf(open / FOOT_WHOLE, 0.56, 1.0))
	_shown = b.mesh()
	queue_redraw()
	var gb := Face.Builder.new()
	for g: Array in GLINTS:
		var y: float = float(g[1]) * size.y if float(g[1]) >= 0.0 else size.y + float(g[1]) * u
		if float(g[1]) < 0.0 and open < FOOT_LEAST:
			continue
		_sparkle(gb, Vector2(float(g[0]) * size.x, y), float(g[2]) * u, Color(Color.WHITE, 0.9))
	_glints_shown = gb.mesh()
	_glints.size = size
	_glints.queue_redraw()

## A band of the ground from `y0` to `y1`, shaded `top` to `low`, a little
## wider than the rect.
func _band(b: Face.Builder, y0: float, y1: float, top: Color, low: Color) -> void:
	var x0 := -size.x * 0.5
	var x1 := size.x * 1.5
	var a := b.vertex(Vector2(x0, y0), top)
	var c := b.vertex(Vector2(x1, y0), top)
	var d := b.vertex(Vector2(x1, y1), low)
	var e := b.vertex(Vector2(x0, y1), low)
	b.tri(a, c, d)
	b.tri(a, d, e)

## The mat's cutting grid, faint, from where the mat is whole down: nothing
## is ruled across the light the wordmark stands in.
func _grid(b: Face.Builder, u: float) -> void:
	var step := GRID * u
	var top := size.y * MAT_FROM
	var i := 0
	var x := size.x * 0.5 - step * floorf(size.x * 0.5 / step) - step * 0.5
	while x < size.x:
		var bold := i % GRID_BOLD == 0
		b.stroke(PackedVector2Array([Vector2(x, top), Vector2(x, size.y)]), (2.4 if bold else 1.6) * u,
			Color(MAT_GRID, 0.34 if bold else 0.2), false, false)
		x += step
		i += 1
	i = 0
	var y := top + step * 0.5
	while y < size.y:
		var bold := i % GRID_BOLD == 0
		b.stroke(PackedVector2Array([Vector2(0.0, y), Vector2(size.x, y)]), (2.4 if bold else 1.6) * u,
			Color(MAT_GRID, 0.34 if bold else 0.2), false, false)
		y += step
		i += 1

## The ruler printed along the mat's bottom edge.
func _ruler(b: Face.Builder, u: float) -> void:
	var y := size.y - 10.0 * u
	b.stroke(PackedVector2Array([Vector2(0.0, y), Vector2(size.x, y)]), 2.4 * u, Color(INK, 0.5), false, false)
	var step := 22.5 * u
	var i := 0
	var x := step
	while x < size.x:
		var tall := (16.0 if i % 4 == 3 else 8.0) * u
		b.stroke(PackedVector2Array([Vector2(x, y), Vector2(x, y - tall)]), 2.0 * u, Color(INK, 0.45), false, false)
		x += step
		i += 1

## What lies on the mat under the tray, `k` of its size, stood on the
## bottom edge: the jar on its side and its spill at the left, the tweezers
## in the middle, the ironing paper with its flower at the right.
func _foot_things(b: Face.Builder, u: float, k: float) -> void:
	var s := u * k
	var base := size.y - 26.0 * u
	# The jar, lying with its mouth to the right.
	var jar := Vector2(size.x * 0.105, base - 46.0 * s)
	var jw := 150.0 * s
	var jh := 84.0 * s
	Scenery.soft_disc(b, jar + Vector2(6.0 * s, jh * 0.56), jw * 0.62, 12.0 * s, Color(Pal.TEXT, 0.16))
	b.fan(Face.Builder.round_rect(jar - Vector2(jw, jh) * 0.5 + Vector2(0.0, 4.0 * s), Vector2(jw, jh), 22.0 * s), GLASS_DEEP)
	b.fan(Face.Builder.round_rect(jar - Vector2(jw, jh) * 0.5, Vector2(jw, jh), 22.0 * s), GLASS)
	# The beads still in it, seen through the glass.
	var keys := ["sky", "rose", "yellow", "green", "lilac", "orange", "teal", "pink"]
	for i in 8:
		var at := jar + Vector2((-0.34 + 0.2 * float(i % 4) + (0.07 if i >= 4 else 0.0)) * jw,
			(0.2 if i < 4 else -0.06) * jh)
		Bead.bead(b, at, 30.0 * s, Pal.PG_BEADS[keys[i]], Vector2.ONE, 0.9, 0.0, 0.0, 0.0, GLASS, false)
	b.fan(Face.Builder.round_rect(jar - Vector2(jw, jh) * 0.5 + Vector2(10.0, 8.0) * s, Vector2(jw - 30.0 * s, 9.0 * s), 4.5 * s),
		Color(Color.WHITE, 0.7))
	# Its wooden lid, off and leant beside the mouth.
	var lid := Vector2(jar.x + jw * 0.5 + 16.0 * s, base - 30.0 * s)
	b.fan(Face.Builder.round_rect(lid - Vector2(11.0, 38.0) * s + Vector2(0.0, 4.0 * s), Vector2(22.0, 76.0) * s, 8.0 * s), LID_DEEP)
	b.fan(Face.Builder.round_rect(lid - Vector2(11.0, 38.0) * s, Vector2(22.0, 76.0) * s, 8.0 * s), LID)
	for l: Array in SPILL:
		Bead.bead(b, Vector2(float(l[0]) * size.x, size.y - (float(l[1]) * k + 4.0) * u), 34.0 * s,
			Pal.PG_BEADS[String(l[2])], Vector2.ONE, 1.0, 0.0, 0.0, 0.0, MAT_LOW, false)
	# The tweezers: two steel arms from one heel, tips nearly together.
	var heel := Vector2(size.x * 0.668, base - 22.0 * s)
	var tip := Vector2(size.x * 0.512, base - 64.0 * s)
	var side := (tip - heel).orthogonal().normalized()
	Scenery.soft_disc(b, heel.lerp(tip, 0.5) + Vector2(0.0, 16.0 * s), 96.0 * s, 9.0 * s, Color(Pal.TEXT, 0.12))
	for way: float in [-1.0, 1.0]:
		var arm := PackedVector2Array([heel, heel.lerp(tip, 0.55) + side * way * 13.0 * s, tip + side * way * 3.0 * s])
		b.stroke(arm, 10.0 * s, STEEL_DEEP)
		b.stroke(arm, 6.0 * s, STEEL)
	b.disc(heel, 9.0 * s, STEEL_DEEP)
	b.disc(heel, 5.5 * s, STEEL)
	# The sheet of ironing paper, a corner curled, and the flower done on it.
	var sheet := Vector2(190.0, 150.0) * s
	var at := Vector2(size.x * 0.955 - sheet.x, base - sheet.y + 8.0 * s)
	Scenery.soft_disc(b, at + Vector2(sheet.x * 0.5, sheet.y), sheet.x * 0.52, 10.0 * s, Color(Pal.TEXT, 0.14))
	var quad := PackedVector2Array([at + Vector2(0.0, 10.0 * s), at + Vector2(sheet.x, 0.0),
		at + sheet + Vector2(4.0 * s, -6.0 * s), at + Vector2(6.0 * s, sheet.y)])
	b.fan(quad, PAPER)
	b.fan(PackedVector2Array([quad[1], quad[1] + Vector2(-30.0, 2.0) * s, quad[1] + Vector2(-4.0, 30.0) * s]), PAPER_DEEP)
	var cell := 24.0 * s
	var from := at + Vector2(sheet.x * 0.5 - cell * 2.0, sheet.y * 0.5 - cell * 2.0 + 4.0 * s)
	for r in FLOWER.size():
		for c in FLOWER[r].length():
			var ch := FLOWER[r][c]
			if FLOWER_KEYS.has(ch):
				Bead.bead(b, from + Vector2(c, r) * cell, cell, Pal.PG_BEADS[String(FLOWER_KEYS[ch])],
					Vector2.ONE, 1.0, 0.0, 1.0, 0.0, PAPER, false)

## A four-pointed glint of `r`, its waist pinched.
func _sparkle(b: Face.Builder, at: Vector2, r: float, ink: Color) -> void:
	var pts := PackedVector2Array()
	for i in 8:
		pts.append(at + Vector2.from_angle(-PI * 0.5 + i * PI * 0.25) * (r if i % 2 == 0 else r * 0.30))
	b.polygon(pts, ink)
