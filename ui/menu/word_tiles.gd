class_name WordTiles
extends Control

## The app icon's two words, DAILY over PUZZLES, as letter tiles drawn in code:
## the first screen's header wears them and the opening lays them one at a
## time (`shown`). Each tile is a piece as Hidden Word's board cuts it (a
## lip, a lit rim, a crown), set a few degrees off square; the pieces are one
## mesh built once and the twelve letters are draw commands over it, as on
## the Hidden Word card. `piece` is that card's cut, moved here so the card,
## the header and the opening all use the one drawing.

const Pal = preload("res://core/palette.gd")
const Board = preload("res://puzzles/hidden_word2d.gd")
const Face = preload("res://ui/faces/face.gd")
const Mosaic = preload("res://ui/faces/mosaic_tile.gd")
const CozyTheme = preload("res://ui/theme.gd")

## The icon's tile colours. SKY and CORAL are the opening's BLUE and CORAL
## (the opening reads them from here).
const PAPER := Pal.PAPER
const BUTTER := Pal.SUN_TILE
const LEAF := Pal.LEAF
const SKY := Color("95c6e8")
const CORAL := Color("fb8f7a")

const ROWS := ["DAILY", "PUZZLES"]
const COLOURS := {
	"DAILY": [PAPER, BUTTER, PAPER, LEAF, PAPER],
	"PUZZLES": [SKY, PAPER, BUTTER, CORAL, SKY, PAPER, LEAF],
}
## Degrees, one a tile in reading order.
const TILT := [-3.0, 2.0, -1.0, 3.0, -2.0, 2.0, -2.0, 1.0, -3.0, 2.0, -1.0, 3.0]
## A piece's bottom edge, in tiles, and the least it may be: the board's EDGE
## has a floor of 5 on a cell of 130, which is a slab on one of 44.
const LIP := 0.07
const LIP_MIN := 3.0

## A tile's side at the 1080 design width, the gap between two (of a tile)
## and the second row's shift to the right (in tiles).
@export var tile := 60.0:
	set(v):
		tile = v
		_dirty = true
		_sized()
		queue_redraw()
@export var gap := 0.12:
	set(v):
		gap = v
		_dirty = true
		_sized()
		queue_redraw()
@export var indent := 0.45:
	set(v):
		indent = v
		_dirty = true
		_sized()
		queue_redraw()
## Tiles drawn, in reading order; 12 draws them all.
var shown := 12:
	set(v):
		v = clampi(v, 0, count())
		if v != shown:
			shown = v
			queue_redraw()

## Every tile's mesh about its own middle, and all of them under their tilts
## as one. `shown` below the whole picks from the first; the whole is the one
## draw_mesh of the resting header.
var _tiles: Array[ArrayMesh] = []
var _all: ArrayMesh
var _dirty := true

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sized()

static func count() -> int:
	var n := 0
	for row in ROWS:
		n += (row as String).length()
	return n

## The row and column of tile `i`.
static func cell(i: int) -> Vector2i:
	for r in ROWS.size():
		var n: int = (ROWS[r] as String).length()
		if i < n:
			return Vector2i(i, r)
		i -= n
	return Vector2i(-1, -1)

static func letter_at(i: int) -> String:
	var c := cell(i)
	return (ROWS[c.y] as String)[c.x]

static func colour_at(i: int) -> Color:
	var c := cell(i)
	return COLOURS[ROWS[c.y]][c.x]

## The letter's colour on tile `i`: ink on the pale tiles, surface on the rest.
static func ink_at(i: int) -> Color:
	var fill := colour_at(i)
	return Pal.TEXT if fill == PAPER or fill == BUTTER else Pal.SURFACE

## The local rect of tile `i`, before its tilt.
func tile_rect(i: int) -> Rect2:
	var c := cell(i)
	var x := c.x * tile * (1.0 + gap) + (indent * tile if c.y > 0 else 0.0)
	return Rect2(Vector2(x, c.y * tile * (1.0 + gap)), Vector2(tile, tile))

func total_size() -> Vector2:
	var wide := 0.0
	for r in ROWS.size():
		var n: int = (ROWS[r] as String).length()
		wide = maxf(wide, n * (1.0 + gap) - gap + (indent if r > 0 else 0.0))
	return Vector2(tile * wide, tile * (ROWS.size() * (1.0 + gap) - gap))

func _sized() -> void:
	custom_minimum_size = total_size()

## One piece at `at`, `s` wide, as the board's `_tile_face` cuts it: the
## bottom edge in `deep`, the face in `rim`, and the crown in `fill` a bevel
## down and in from it.
static func piece(b: Face.Builder, at: Vector2, s: float, fill: Color, deep: Color, rim: Color) -> void:
	var r := s * Board.RADIUS
	var edge := maxf(LIP_MIN, s * LIP)
	var bev := s * Board.BEVEL
	b.polygon(Face.Builder.round_rect(at, Vector2(s, s), r), deep)
	b.polygon(Face.Builder.round_rect(at, Vector2(s, s - edge), r), rim)
	b.polygon(Face.Builder.round_rect(at + Vector2(bev * 0.7, bev), Vector2(s - bev * 1.4, s - edge - bev),
		maxf(r - bev * 0.5, 0.0)), fill)

## The tilt of tile `i` in radians.
static func angle_at(i: int) -> float:
	return deg_to_rad(float(TILT[i]))

func _build() -> void:
	_dirty = false
	_tiles.clear()
	var whole := Face.Builder.new()
	for i in count():
		var fill := colour_at(i)
		var b := Face.Builder.new()
		piece(b, Vector2.ONE * (-tile * 0.5), tile, fill, fill.lerp(Pal.TEXT, Board.EDGE_MIX),
			fill.lerp(Pal.SURFACE, Board.RIM_LIGHT))
		var m := b.mesh()
		_tiles.append(m)
		whole.append(m, _place(i))
	_all = whole.mesh()

## Tile `i` from its own middle to where it stands, tilted about it.
func _place(i: int) -> Transform2D:
	return Transform2D(angle_at(i), tile_rect(i).get_center())

func _draw() -> void:
	if _dirty or _all == null:
		_build()
	if shown >= count():
		draw_mesh(_all, null)
	else:
		for i in shown:
			draw_mesh(_tiles[i], null, _place(i))
	var font: Font = CozyTheme.display(700)
	var lift := Vector2(0.0, -maxf(LIP_MIN, tile * LIP) * 0.5)
	for i in shown:
		var xf := _place(i)
		Mosaic.letter(self, xf * lift, tile, letter_at(i), Vector2.ONE, ink_at(i), font, 1.0, angle_at(i))
