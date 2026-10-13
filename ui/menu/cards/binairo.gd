extends "res://ui/menu/cards/card_face.gd"

## Binairo's card: a day and a night on one paper, and a corner of the board
## lying across the line between them. The tiles are the board's own (their
## paper, their edge, the sun and the moon that sit on them, an = between
## two of them), and the one tile missing is the go button: two moons stand
## beside it, so the tile it wants is a sun, and the card is the game's rule
## read once. The top right place is left to the night sky, which is where
## the done seal is pinned.
##
## Everything still is one mesh; the seven faces are the board's Controls,
## idling as they do there.

const SunFace = preload("res://ui/faces/sun_face.gd")
const MoonFace = preload("res://ui/faces/moon_face.gd")

## The row the card was drawn for (puzzle_card_2d.gd's CARD_H); the board
## grows with a taller one.
const H := 246.0
## A tile, the gap between two and the tile's bottom edge, at H; the corner
## radius as a share of the tile, and the faces' sizes, as the board has them
## (puzzles/binairo2d.gd: TILE_RADIUS 18 on a tile of about 112, SUN_SIZE,
## MOON_SIZE, SIGN_R, SIGN_GLYPH, SIGN_STROKE).
const TILE := 58.0
const GAP := 7.0
const TILE_EDGE := 4.0
const TILE_ROUND := 0.17
const SUN_SIZE := 0.26 * 2.0 * 1.55
const MOON_SIZE := 0.34 * 2.0
const SIGN_R := 0.15
const SIGN_GLYPH := 0.07
const SIGN_STROKE := 0.034
## The board's margin from the card's right edge and the words' from its left.
const SIDE := 24.0
const TEXT_X := 24.0

## The corner of the board, row by row: 0 a sun, 1 a moon, 2 the go tile,
## -1 the bare place the seal takes.
const CELLS := [
	[0, 0, -1],
	[1, 0, 1],
	[1, 1, 2],
]
## The = between the two suns of the top row.
const SIGN := [Vector2i(0, 0), Vector2i(1, 0)]

const DAY_TOP := Color("ffeccb")
const DAY_LOW := Color("fbd3a0")
const NIGHT_TOP := Color("3d488c")
const NIGHT_LOW := Color("6b7bc8")
## The stars, in tiles from the bare place's middle: [x, y, radius].
const STARS := [[-0.26, -0.20, 0.050], [0.20, 0.24, 0.036], [-0.10, 0.34, 0.026], [0.36, -0.06, 0.028]]

func _tile() -> float:
	return TILE * size.y / H

## The top left corner of tile (col, row).
func _cell(col: int, row: int) -> Vector2:
	var t := _tile()
	var g := GAP * size.y / H
	var side := t * 3.0 + g * 2.0
	var origin := Vector2(size.x - SIDE - side, (size.y - side) * 0.5)
	return origin + Vector2(col, row) * (t + g)

## The line between the day and the night, top to bottom: it leaves the top
## edge over the board's third column and comes down left of the board, so
## the suns stand in the day and the moons in the night.
func _divide() -> PackedVector2Array:
	var t := _tile()
	var top := Vector2(_cell(2, 0).x - t * 0.06, 0.0)
	var low := Vector2(_cell(0, 0).x - t * 0.52, size.y)
	var pts := Face.Builder.bezier3(top, Vector2(top.x, size.y * 0.50), Vector2(low.x, size.y * 0.46), low, 24)
	pts.append(low)
	return pts

func _paint(b: Face.Builder) -> void:
	var t := _tile()
	var paper := ground()
	# The night under everything, then the day cut out of the same paper.
	var first := b.verts.size()
	b.polygon(paper, Color.WHITE)
	shade(b, first, NIGHT_TOP, NIGHT_LOW, 0.0, size.y)
	var divide := _divide()
	var day := PackedVector2Array([Vector2(-8.0, -8.0)])
	day.append(Vector2(divide[0].x, -8.0))
	day.append_array(divide)
	day.append(Vector2(divide[divide.size() - 1].x, size.y + 8.0))
	day.append(Vector2(-8.0, size.y + 8.0))
	for part in Geometry2D.intersect_polygons(paper, day):
		first = b.verts.size()
		b.polygon(part, Color.WHITE)
		shade(b, first, DAY_TOP, DAY_LOW, 0.0, size.y)
	# The day's edge, lit; kept off the paper's own line at both ends.
	var lit := divide.slice(1, divide.size() - 1)
	b.stroke(lit, t * 0.20, Color(Pal.SUN_RAY, 0.20), false, false)
	b.stroke(lit, t * 0.05, Color(Pal.SURFACE, 0.85), false, false)
	# A sun coming up in the day's low corner, behind nothing.
	var rise := Vector2(t * 0.95, size.y + t * 0.30)
	for ring in [[1.55, 0.13], [1.15, 0.20], [0.78, 0.34]]:
		for part in Geometry2D.intersect_polygons(paper, Face.Builder.ring(rise, t * ring[0], t * ring[0])):
			b.polygon(part, Color(Pal.SUN_RAY, ring[1]))
	# The night's own corner: a few stars and one that twinkles.
	var sky := _cell(2, 0) + Vector2(t, t) * 0.5
	for s in STARS:
		b.disc(sky + Vector2(s[0], s[1]) * t, s[2] * t, Color(Pal.MOON, 0.85))
	_sparkle(b, sky + Vector2(0.08, -0.12) * t, t * 0.20, Color(Pal.SUN_TILE, 0.95))
	for s in [[0.60, 2.62, 0.030], [3.30, 1.40, 0.026], [1.70, 3.26, 0.024], [3.28, 2.70, 0.020]]:
		b.disc(_cell(0, 0) + Vector2(s[0], s[1]) * t, s[2] * t, Color(Pal.MOON, 0.55))
	# The tiles: a shadow on the ground, the edge, the paper.
	var round := t * TILE_ROUND
	var edge := TILE_EDGE * size.y / H
	for row in CELLS.size():
		for col in CELLS[row].size():
			var v: int = CELLS[row][col]
			if v < 0:
				continue
			var at := _cell(col, row)
			var fill: Color = [Pal.SUN_TILE, Pal.MOON_TILE, colour][v]
			var deep: Color = [Color("e6c58f"), Color("b9c1ea"), colour.darkened(0.22)][v]
			b.polygon(Face.Builder.round_rect(at + Vector2(0.0, edge * 1.4), Vector2(t, t), round), Color(0.16, 0.13, 0.30, 0.20))
			b.polygon(Face.Builder.round_rect(at, Vector2(t, t), round), deep)
			b.polygon(Face.Builder.round_rect(at, Vector2(t, t - edge), round), fill)
			if v == 2 and not soon:
				var mid := at + Vector2(t, t - edge) * 0.5
				var k := t * 0.17
				b.stroke(PackedVector2Array([mid + Vector2(-k * 0.55, -k), mid + Vector2(k * 0.55, 0.0),
					mid + Vector2(-k * 0.55, k)]), t * 0.11, Pal.SURFACE)
	# The sign, on the gap between its two tiles.
	var a := _cell(SIGN[0].x, SIGN[0].y)
	var o := _cell(SIGN[1].x, SIGN[1].y)
	var mid_s := (a + o) * 0.5 + Vector2(t, t - edge) * 0.5
	b.disc(mid_s, t * SIGN_R + 2.0, Pal.LINE)
	b.disc(mid_s, t * SIGN_R, Pal.SURFACE)
	for dy in [-0.45, 0.45]:
		b.stroke(PackedVector2Array([mid_s + Vector2(-1.0, dy) * t * SIGN_GLYPH,
			mid_s + Vector2(1.0, dy) * t * SIGN_GLYPH]), t * SIGN_STROKE, Pal.ACORN_DEEP)

## A four-pointed star of `r`, its waist pinched.
func _sparkle(b: Face.Builder, at: Vector2, r: float, ink: Color) -> void:
	var pts := PackedVector2Array()
	for i in 8:
		pts.append(at + Vector2.from_angle(-PI * 0.5 + i * PI * 0.25) * (r if i % 2 == 0 else r * 0.30))
	b.polygon(pts, ink)

func _lay() -> void:
	var t := _tile()
	var edge := TILE_EDGE * size.y / H
	for row in CELLS.size():
		for col in CELLS[row].size():
			var v: int = CELLS[row][col]
			if v != 0 and v != 1:
				continue
			var face: Control
			if v == 0:
				face = SunFace.new()
			else:
				face = MoonFace.new()
				face.rocks = (row + col) % 2 == 1
			var s := t * (SUN_SIZE if v == 0 else MOON_SIZE)
			face.size = Vector2(s, s)
			face.position = _cell(col, row) + (Vector2(t, t - edge) - face.size) * 0.5
			_keep(face)
			face.set_idle(true)
	var room := _cell(0, 0).x - TEXT_X - 6.0
	_words("BINAiRO", TEXT_X, size.y * 0.5 - 8.0, room, Pal.TEXT, Color("7a6753"))
