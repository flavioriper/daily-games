extends Control

## Nonogram's world: the table the picture is laid on, edge to edge under
## the board and the host's rows (CLAUDE.md: a game's world fills the
## screen). It is the menu card's picture (ui/menu/cards/nonogram.gd) at the
## size of the screen: the glaze-blue cloth with its weave, palest at the top
## where the wordmark is ink, a pool of light where the floor lies, and the
## things a tiler keeps to hand -- two spare tiles, a pebble and a daisy in
## the gap of the tools row; and in the foot's corners, either side of the
## host's tile tray, a small finished heart on its own little tray, a saucer
## of pebbles and a few daisies. Nothing lies between: an Easy picture is
## tall and its floor comes down to the tray, and the cloth behind the
## tray's chips is plain and light so they read.
##
## One mesh, built when the rect changes and kept (`_shown`) until the next
## replaces it; the four glints on the tiles are a second, on a child whose
## alpha breathes (still under Motion.reduce). The colours are written here:
## the board preloads this file, so this file does not preload the board.

const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Face = preload("res://ui/faces/face.gd")
const CardFace = preload("res://ui/menu/cards/card_face.gd")
const Scenery = preload("res://ui/flat/scenery.gd")
const Mosaic = preload("res://ui/faces/mosaic_tile.gd")

## The screen the picture was drawn on; everything scales with the width.
const W := 1080.0
const TOP_H := 1920.0
const CLOTH_TOP := Color("f4f6fa")
const CLOTH_MID := Color("e6ebf5")
const CLOTH_LOW := Color("d7dfee")
const THREAD := Color("8c9cc4")
const SAUCER := Color("fbf7ee")
const SAUCER_EDGE := Color("d9d2c2")
## The weave: a thread every WEAVE pixels at W, both ways.
const WEAVE := 36.0
const WEAVE_A := 0.05
## The light from the window, behind the wordmark: its middle as shares.
const LIGHT_AT := Vector2(0.10, 0.02)
## The spares in the gap of the tools row: [x, y as shares, size at W, turn].
## Their y is a share of a 9:16 screen (TOP_H at W), not of this one: the
## host's rows sit at fixed pixels from the top, and on a taller phone a share
## of the height dropped them out of the tools row onto the clues (2026-10-28).
const SPARES := [[0.365, 0.229, 62.0, -0.26], [0.455, 0.236, 62.0, 0.34]]
const SPARE_PEBBLE := [0.565, 0.232, 70.0]
const SPARE_DAISY := [0.665, 0.231, 20.0, 0.4]
## The finished heart on its little tray, left of the tile tray: its middle
## as shares, a tile at W, its lean.
const HEART := [".X.X.", "XXXXX", ".XXX.", "..X.."]
const HEART_AT := Vector2(0.105, 0.942)
const HEART_CELL := 26.0
const HEART_TILT := -0.07
## The saucer of pebbles at the other side: middle as shares, radius at W.
const DISH_AT := Vector2(0.910, 0.938)
const DISH_R := 52.0
## Daisies on the cloth: [x, y as shares, radius at W, turn].
const DAISIES := [
	[0.182, 0.914, 11.0, 0.2], [0.040, 0.988, 9.0, 0.9],
	[0.846, 0.978, 11.0, 0.5], [0.972, 0.986, 9.0, 1.1],
]
const DAISY_PETALS := 7
## The glints that breathe: [x, y as shares, radius at W].
const GLINTS := [[0.352, 0.221, 9.0], [0.442, 0.228, 9.0], [0.086, 0.931, 7.0], [0.898, 0.931, 7.0]]
const BREATHE := 3.6
const BREATHE_LOW := 0.3

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
	_breath = Motion.pulse(_glints, "modulate:a", 1.0, BREATHE_LOW, BREATHE)

func _draw() -> void:
	if _shown != null:
		draw_mesh(_shown, null)

func _build() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var u := size.x / W
	var b := Face.Builder.new()
	# The cloth, palest at the top; it runs past the rect, since the board
	# slides and shrinks on the win and the world is held against it.
	var over := size.y * 0.5
	var first := b.verts.size()
	b.polygon(PackedVector2Array([Vector2(-8.0, -over), Vector2(size.x + 8.0, -over),
		Vector2(size.x + 8.0, size.y * 0.5), Vector2(-8.0, size.y * 0.5)]), Color.WHITE)
	CardFace.shade(b, first, CLOTH_TOP, CLOTH_MID, 0.0, size.y * 0.5)
	first = b.verts.size()
	b.polygon(PackedVector2Array([Vector2(-8.0, size.y * 0.5), Vector2(size.x + 8.0, size.y * 0.5),
		Vector2(size.x + 8.0, size.y + over), Vector2(-8.0, size.y + over)]), Color.WHITE)
	CardFace.shade(b, first, CLOTH_MID, CLOTH_LOW, size.y * 0.5, size.y)
	# The window's light behind the wordmark, and the pool the floor lies in.
	Scenery.soft_disc(b, LIGHT_AT * size, 640.0 * u, 560.0 * u, Color(Pal.SURFACE, 0.55))
	Scenery.soft_disc(b, Vector2(0.5, 0.53) * size, size.x * 0.78, size.y * 0.36, Color(Pal.SURFACE, 0.42))
	# The weave, two quads a thread.
	var step := WEAVE * u
	var thread := Color(THREAD, WEAVE_A)
	var x := step * 0.5
	while x < size.x:
		b.polygon(PackedVector2Array([Vector2(x, 0.0), Vector2(x + 2.0 * u, 0.0),
			Vector2(x + 2.0 * u, size.y), Vector2(x, size.y)]), thread)
		x += step
	var y := step * 0.5
	while y < size.y:
		b.polygon(PackedVector2Array([Vector2(0.0, y), Vector2(size.x, y),
			Vector2(size.x, y + 2.0 * u), Vector2(0.0, y + 2.0 * u)]), thread)
		y += step
	# The cloth's hem: two stitched threads down each side, clear of the rows.
	for side in [0.0, 1.0]:
		var hx := lerpf(14.0 * u, size.x - 14.0 * u, side)
		var hy := size.y * 0.80
		while hy < size.y - 10.0 * u:
			b.polygon(PackedVector2Array([Vector2(hx - 1.5 * u, hy), Vector2(hx + 1.5 * u, hy),
				Vector2(hx + 1.5 * u, hy + 16.0 * u), Vector2(hx - 1.5 * u, hy + 16.0 * u)]), Color(THREAD, 0.30))
			hy += 30.0 * u
	# The spares in the gap of the tools row, lying where they were put down.
	var top := Vector2(size.x, TOP_H * u)
	for s in SPARES:
		var at := Vector2(s[0], s[1]) * top
		var px: float = s[2] * u
		Scenery.soft_disc(b, at + Vector2(0.0, px * 0.16), px * 0.56, px * 0.46, Color(Pal.TEXT, 0.14))
		Mosaic.tile(b, at, px, Vector2.ONE, false, 0.0, 1.0, s[3])
	Mosaic.pebble(b, Vector2(SPARE_PEBBLE[0], SPARE_PEBBLE[1]) * top, SPARE_PEBBLE[2] * u, Vector2.ONE, 1.0)
	_daisy(b, Vector2(SPARE_DAISY[0], SPARE_DAISY[1]) * top, SPARE_DAISY[2] * u, SPARE_DAISY[3])
	_heart(b, u)
	_dish(b, u)
	for d in DAISIES:
		_daisy(b, Vector2(d[0], d[1]) * size, d[2] * u, d[3])
	_shown = b.mesh()
	queue_redraw()
	var gb := Face.Builder.new()
	var top_g := Vector2(size.x, TOP_H * size.x / W)
	for g in GLINTS:
		# The first two glints are the spares'; the others sit by the foot.
		var at := Vector2(g[0], g[1]) * (top_g if g[1] < 0.5 else size)
		_sparkle(gb, at, g[2] * u, Color(Pal.SURFACE, 0.95))
	_glints_shown = gb.mesh()
	_glints.size = size
	_glints.queue_redraw()

## The card's heart, finished, on a little parchment tray of its own.
func _heart(b: Face.Builder, u: float) -> void:
	var c := HEART_CELL * u
	var cols: int = String(HEART[0]).length()
	var rows := HEART.size()
	var mid := HEART_AT * size
	var pad := c * 0.34
	var sz := Vector2(cols * c + pad * 2.0, rows * c + pad * 2.0)
	var xf := Transform2D(HEART_TILT, mid)
	var corner := -sz * 0.5
	b.polygon(xf * Face.Builder.round_rect(corner + Vector2(0.0, c * 0.32), sz, c * 0.36), Color(Pal.TEXT, 0.10))
	b.polygon(xf * Face.Builder.round_rect(corner + Vector2(0.0, c * 0.12), sz, c * 0.36), Pal.LINE)
	b.polygon(xf * Face.Builder.round_rect(corner, sz, c * 0.36), Pal.PARCHMENT)
	var socket := Mosaic.socket_outline(c)
	for r in rows:
		for k in cols:
			var at := Vector2((k + 0.5 - cols * 0.5) * c, (r + 0.5 - rows * 0.5) * c)
			b.fan(xf * Transform2D(0.0, at) * socket, Mosaic.socket_colour(false, 1.0))
	for r in rows:
		for k in cols:
			if String(HEART[r])[k] == "X":
				var at := Vector2((k + 0.5 - cols * 0.5) * c, (r + 0.5 - rows * 0.5) * c)
				Mosaic.tile(b, xf * at, c, Vector2.ONE, false, 0.0, 1.0, HEART_TILT)

## A saucer with the pebbles a tiler rules cells out with.
func _dish(b: Face.Builder, u: float) -> void:
	var c := DISH_AT * size
	var r := DISH_R * u
	Scenery.soft_disc(b, c + Vector2(0.0, r * 0.22), r * 1.2, r * 1.05, Color(Pal.TEXT, 0.13))
	b.disc(c + Vector2(0.0, r * 0.07), r, SAUCER_EDGE)
	b.disc(c, r, SAUCER)
	b.stroke(Face.Builder.ring(c, r * 0.78, r * 0.78), 2.0 * u, Color(SAUCER_EDGE, 0.8), true)
	for p in [Vector2(-0.30, -0.16), Vector2(0.26, -0.22), Vector2(-0.04, 0.24), Vector2(0.36, 0.20)]:
		Mosaic.pebble(b, c + p * r, r * 0.62, Vector2.ONE, 1.0, p.x * 3.0)
	# One that rolled off it.
	Mosaic.pebble(b, c + Vector2(-r * 1.3, r * 0.75), r * 0.62, Vector2.ONE, 1.0, 0.8)

## The board's daisy for a line that reads right.
func _daisy(b: Face.Builder, at: Vector2, r: float, turn: float) -> void:
	for p in DAISY_PETALS:
		var a := turn + TAU * p / DAISY_PETALS
		var dir := Vector2.from_angle(a)
		b.fan(_oval(at + dir * r * 0.55, r * 0.5, r * 0.26, a), Pal.PETAL_EDGE)
		b.fan(_oval(at + dir * r * 0.55, r * 0.44, r * 0.2, a), Pal.SURFACE)
	b.fan(Face.Builder.ring(at, r * 0.3, r * 0.3), Pal.SUN)

static func _oval(at: Vector2, rx: float, ry: float, angle: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in 12:
		var a := TAU * k / 12.0
		pts.append(at + Vector2(cos(a) * rx, sin(a) * ry).rotated(angle))
	return pts

## A four-pointed glint of `r`, its waist pinched.
func _sparkle(b: Face.Builder, at: Vector2, r: float, ink: Color) -> void:
	var pts := PackedVector2Array()
	for i in 8:
		pts.append(at + Vector2.from_angle(-PI * 0.5 + i * PI * 0.25) * (r if i % 2 == 0 else r * 0.30))
	b.polygon(pts, ink)
