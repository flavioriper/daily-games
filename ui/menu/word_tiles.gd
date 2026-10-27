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
const Face = preload("res://ui/faces/face.gd")
const Mosaic = preload("res://ui/faces/mosaic_tile.gd")
const CozyTheme = preload("res://ui/theme.gd")

## The icon's tile colours, sampled from assets/icon/icon.png (the user,
## 2026-10-27: "make sure the daily puzzle colors follow the icon colors"):
## a warm cream, a sunflower yellow, a leaf green, a sky blue and a coral.
## They are the icon's, not the app palette's muted kin, so the wordmark
## reads as the icon does.
const PAPER := Color("fdecc8")
const BUTTER := Color("fdcf3f")
const LEAF := Color("55b35c")
const SKY := Color("72b5fb")
const CORAL := Color("fb7c6a")

## A piece's corner, bevel and the shades of its edge and rim, as the Hidden
## Word board cuts it (puzzles/hidden_word2d.gd reads them from here): the
## board is a heavy script, and the boot opening, which stands on this one,
## must never load it.
const RADIUS := 0.19
const BEVEL := 0.055
const EDGE_MIX := 0.26
const RIM_LIGHT := 0.3

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

## The letter's colour on tile `i`: ink on the cream tiles, white on every
## coloured one, the yellow included (as the icon has it).
static func ink_at(i: int) -> Color:
	return Pal.TEXT if colour_at(i) == PAPER else Pal.SURFACE

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
	var r := s * RADIUS
	var edge := maxf(LIP_MIN, s * LIP)
	var bev := s * BEVEL
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
		piece(b, Vector2.ONE * (-tile * 0.5), tile, fill, fill.lerp(Pal.TEXT, EDGE_MIX),
			fill.lerp(Pal.SURFACE, RIM_LIGHT))
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
