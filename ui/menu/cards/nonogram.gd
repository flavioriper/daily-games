extends "res://ui/menu/cards/card_face.gd"

## Nonogram's card: the picture as a thing on a table. A small tray of the
## board's floor, five sockets by four, lies a few degrees off square on a
## glaze-blue cloth at the card's right, its clue tabs along its top and left
## as the board writes them, and the picture in it is a heart with one tile to
## go. Every line that already reads as its numbers say has gone green, tab
## and numbers both, so the two still in ink -- a row of three, a column of
## three -- cross at the one empty socket. The tile that socket wants is the
## go button: a tile in the card's colour, lifted off the tray's corner beside
## it, with a chevron on its crown. Two spare tiles and a pebble lie on the
## cloth over the tray, and the name stands at the left.
##
## Everything is one mesh (the sockets, tiles and pebbles are the board's own,
## ui/faces/mosaic_tile.gd); the clue numbers are draw_strings over it, turned
## with the tray, as the board writes its own. Nothing lives on it.

const Board = preload("res://puzzles/nonogram2d.gd")
const Mosaic = preload("res://ui/faces/mosaic_tile.gd")
const Scenery = preload("res://ui/flat/scenery.gd")
const CozyTheme = preload("res://ui/theme.gd")

## The row the card was drawn for (puzzle_card_2d.gd's CARD_H); the tray
## grows with a taller one.
const H := 246.0
## A socket at H, the card's margins, the tray's lift off the card's foot and
## the room the words are owed beside it.
const CELL := 32.0
const SIDE := 22.0
const FOOT := 16.0
const WORDS := 258.0
const WORDS_GAP := 8.0
## How low the tray's top may come: under the seal (SEAL_IN + SEAL_R) and a
## little air.
const SEAL_CLEAR := 72.0
## The tray's lean, clockwise, so its top right corner dips away from the seal.
const TILT := 0.044
## The picture, row by row, and the tile still to lay. Its clues are counted
## from it (`_runs`), so the numbers shown are true of the picture shown.
const PICTURE := [
	".X.X.",
	"XXXXX",
	".XXX.",
	"..X..",
]
const COLS := 5
const ROWS := 4
const MISSING := Vector2i(3, 2)
## The sockets ruled out with a pebble, each in a line already read right.
const PEBBLES := [Vector2i(0, 0), Vector2i(4, 0), Vector2i(0, 3)]
## The clue bands, in cells: the board's NUM a number, two deep on the left
## and one on top, and the numbers a touch larger than the board's NUM_SIZE
## because a socket here is a third of one there.
const BAND_PAD := 0.06
const ROW_DEEP := 2
const COL_DEEP := 1
const NUM_SIZE := 0.47
## The tray round the floor and its bands, in cells: its margin, its corner
## and its bottom edge.
const TRAY_PAD := 0.17
const TRAY_ROUND := 0.26
const TRAY_LIP := 0.07
## The go tile, in cells: its size, where its middle hangs over the grid and
## its own lean past the tray's.
const GO_SIZE := 1.4
const GO_AT := Vector2(4.62, 3.5)
const GO_TURN := 0.16
## The spares on the cloth over the tray: [x in cells from the tray's left,
## y as a share of the cloth over it, size in cells, turn]; the pebble's the
## same without a turn.
const SPARES := [[1.15, 0.52, 0.82, -0.3], [2.5, 0.42, 0.82, 0.42]]
const SPARE_PEBBLE := [3.55, 0.66, 0.95]
## The daisies in the bottom left corner, the board's own for a line that
## reads right: [x, y from the bottom, radius, turn], at H.
const DAISIES := [[44.0, 30.0, 12.0, 0.2], [72.0, 22.0, 8.5, 0.9]]

const CLOTH_TOP := Color("eef1f7")
const CLOTH_LOW := Color("d7dfee")
const BLURB := Color("6d6877")

## The clue numbers: [middle in the tray's own pixels, text, ink].
var _nums: Array = []

func _k() -> float:
	return size.y / H

## The tray's size in cells, bands and lip and all.
static func _tray_cells() -> Vector2:
	return Vector2(_band(ROW_DEEP) + COLS + TRAY_PAD * 2.0, _band(COL_DEEP) + ROWS + TRAY_PAD * 2.0 + TRAY_LIP)

## A clue band `deep` numbers deep, in cells, the gap to the floor included.
static func _band(deep: int) -> float:
	return Board.NUM * deep + BAND_PAD + Board.TAB_GAP

## The tray's own scale: the card's, unless the words or the seal want room.
func _ks() -> float:
	var cells := _tray_cells()
	var wide := (size.x - SIDE * 2.0 - WORDS - WORDS_GAP) / (cells.x * CELL)
	var tall := (size.y - FOOT * _k() - SEAL_CLEAR) / (cells.y * CELL)
	return minf(_k(), minf(wide, tall))

func _cell() -> float:
	return CELL * _ks()

## The tray's rect before its lean, in the card's pixels: against the right
## margin, midway between the seal and the foot.
func _tray() -> Rect2:
	var px := _tray_cells() * _cell()
	var mid_y := (SEAL_CLEAR + size.y - FOOT * _k()) * 0.5
	return Rect2(Vector2(size.x - SIDE - px.x, mid_y - px.y * 0.5), px)

## From the grid's own pixels (its top left socket's corner at the origin) to
## the card's, the tray leaning about its middle.
func _xf() -> Transform2D:
	var c := _cell()
	var tray := _tray()
	var grid := tray.position + Vector2(_band(ROW_DEEP) + TRAY_PAD, _band(COL_DEEP) + TRAY_PAD) * c
	var mid := tray.get_center()
	return Transform2D(TILT, mid) * Transform2D(0.0, grid - mid)

func _laid(cell: Vector2i) -> bool:
	return String(PICTURE[cell.y])[cell.x] == "X" and cell != MISSING

## The runs of a line of the whole picture, and whether what is laid already
## reads so.
func _runs(row: bool, index: int, laid_only: bool) -> Array:
	var out: Array = []
	var run := 0
	for i in (COLS if row else ROWS):
		var cell := Vector2i(i, index) if row else Vector2i(index, i)
		var on := _laid(cell) if laid_only else String(PICTURE[cell.y])[cell.x] == "X"
		if on:
			run += 1
		elif run > 0:
			out.append(run)
			run = 0
	if run > 0:
		out.append(run)
	return out

func _paint(b: Face.Builder) -> void:
	var c := _cell()
	var k := _k()
	var paper := ground()
	var tray := _tray()
	var xf := _xf()
	var first := b.verts.size()
	b.polygon(paper, Color.WHITE)
	shade(b, first, CLOTH_TOP, CLOTH_LOW, 0.0, size.y)
	# A pool of light on the cloth where the tray lies, and the daisies.
	Scenery.soft_disc(b, tray.get_center() + Vector2(0.0, c * 0.2), tray.size.x * 0.72, tray.size.y * 0.7,
		Color(Pal.SURFACE, 0.5))
	for d in DAISIES:
		_daisy(b, Vector2(d[0] * k, size.y - d[1] * k), d[2] * k, d[3])
	# The spares, lying where they were put down.
	var over := tray.position.y
	for s in SPARES:
		var at := Vector2(tray.position.x + s[0] * c, over * s[1])
		var px: float = s[2] * c
		Scenery.soft_disc(b, at + Vector2(0.0, px * 0.16), px * 0.56, px * 0.46, Color(Pal.TEXT, 0.14))
		Mosaic.tile(b, at, px, Vector2.ONE, false, 0.0, 1.0, s[3])
	Mosaic.pebble(b, Vector2(tray.position.x + SPARE_PEBBLE[0] * c, over * SPARE_PEBBLE[1]), c * SPARE_PEBBLE[2],
		Vector2.ONE, 1.0)
	# The tray: its shadow, its bottom edge and its parchment.
	var lean := Transform2D(TILT, tray.get_center()) * Transform2D(0.0, -tray.get_center())
	var lip := c * TRAY_LIP
	var top := tray.size - Vector2(0.0, lip)
	b.polygon(lean * Face.Builder.round_rect(tray.position + Vector2(0.0, c * 0.2), tray.size, c * TRAY_ROUND),
		Color(Pal.MOSAIC_DEEP, 0.16))
	b.polygon(lean * Face.Builder.round_rect(tray.position, tray.size, c * TRAY_ROUND), Pal.LINE)
	b.polygon(lean * Face.Builder.round_rect(tray.position, top, c * TRAY_ROUND), Pal.PARCHMENT)
	# The tabs and their numbers: green where the line already reads right.
	_nums = []
	var inset := c * Board.TAB_INSET
	var gap := c * Board.TAB_GAP
	var ok_tab: Color = Pal.SURFACE.lerp(Pal.GOOD, Board.TAB_OK)
	for y in ROWS:
		var clue := _runs(true, y, false)
		var ok := clue == _runs(true, y, true)
		var w := _band(ROW_DEEP) * c - gap
		b.fan(xf * Face.Builder.round_rect(Vector2(-gap - w, y * c + inset), Vector2(w, c - inset * 2.0),
			c * Board.TAB_RADIUS), Color(ok_tab if ok else Pal.SURFACE, Board.TAB_A))
		for i in clue.size():
			var slot := clue.size() - 1 - i
			_nums.append([Vector2(-gap - c * BAND_PAD * 0.5 - c * Board.NUM * (slot + 0.5), (y + 0.5) * c),
				str(clue[i]), Pal.CLUE_OK if ok else Pal.TEXT])
	for x in COLS:
		var clue := _runs(false, x, false)
		var ok := clue == _runs(false, x, true)
		var h := _band(COL_DEEP) * c - gap
		b.fan(xf * Face.Builder.round_rect(Vector2(x * c + inset, -gap - h), Vector2(c - inset * 2.0, h),
			c * Board.TAB_RADIUS), Color(ok_tab if ok else Pal.SURFACE, Board.TAB_A))
		for i in clue.size():
			var slot := clue.size() - 1 - i
			_nums.append([Vector2((x + 0.5) * c, -gap - c * BAND_PAD * 0.5 - c * Board.NUM * (slot + 0.5)),
				str(clue[i]), Pal.CLUE_OK if ok else Pal.TEXT])
	# The floor: every socket, then what lies in it.
	var socket := Mosaic.socket_outline(c)
	for y in ROWS:
		for x in COLS:
			var cell := Vector2i(x, y)
			var mid := Vector2(x + 0.5, y + 0.5) * c
			b.fan(xf * Transform2D(0.0, mid) * socket, Mosaic.socket_colour(PEBBLES.has(cell), 1.0))
	for y in ROWS:
		for x in COLS:
			var cell := Vector2i(x, y)
			var mid := xf * (Vector2(x + 0.5, y + 0.5) * c)
			if _laid(cell):
				Mosaic.tile(b, mid, c, Vector2.ONE, false, 0.0, 1.0, TILT, 0.0, Board._tone(cell))
			elif PEBBLES.has(cell):
				Mosaic.pebble(b, mid, c, Vector2.ONE, 1.0, TILT)
	if not soon:
		_go_tile(b, xf * (GO_AT * c), c * GO_SIZE, TILT + GO_TURN)

func _draw() -> void:
	super()
	if _nums.is_empty():
		return
	var font: Font = CozyTheme.display(700)
	var px := int(roundf(_cell() * NUM_SIZE))
	if px <= 0:
		return
	var rise := font.get_ascent(px) * 0.5
	var xf := _xf()
	for n in _nums:
		var wide := font.get_string_size(n[1], HORIZONTAL_ALIGNMENT_LEFT, -1.0, px).x
		draw_set_transform_matrix(xf * Transform2D(0.0, n[0]))
		draw_string(font, Vector2(-wide * 0.5, rise - px * 0.06), n[1], HORIZONTAL_ALIGNMENT_LEFT, -1.0, px, n[2])
	draw_set_transform(Vector2.ZERO)

## The tile the last socket wants, `s` across and turned `angle` about `at`:
## cut as Mosaic cuts one (deep edge, lit rim, crown) in the card's colour,
## lifted over its own shadow, with a chevron on the crown.
func _go_tile(b: Face.Builder, at: Vector2, s: float, angle: float) -> void:
	Scenery.soft_disc(b, at + Vector2(0.0, s * 0.2), s * 0.6, s * 0.5, Color(Pal.MOSAIC_DEEP, 0.26))
	var xf := Transform2D(angle, at)
	var inks := [colour.darkened(0.26), colour.lerp(Pal.SURFACE, 0.36), colour]
	var outlines := Mosaic.tile_outlines(s, 0.0)
	for i in outlines.size():
		b.fan(xf * (outlines[i] as PackedVector2Array), inks[i])
	var mid := Vector2(s * 0.02, -s * 0.03)
	var h := s * 0.19
	b.stroke(xf * PackedVector2Array([mid + Vector2(-h * 0.55, -h), mid + Vector2(h * 0.55, 0.0),
		mid + Vector2(-h * 0.55, h)]), s * 0.12, Pal.SURFACE)

## One of the board's daisies of `r` at `at` (its _daisy and DAISY_INKS).
func _daisy(b: Face.Builder, at: Vector2, r: float, turn: float) -> void:
	for p in Board.DAISY_PETALS:
		var a := turn + TAU * p / Board.DAISY_PETALS
		var dir := Vector2.from_angle(a)
		b.fan(Board._oval(at + dir * r * 0.55, r * 0.5, r * 0.26, a), Board.DAISY_INKS[0])
		b.fan(Board._oval(at + dir * r * 0.55, r * 0.44, r * 0.2, a), Board.DAISY_INKS[1])
	b.fan(Face.Builder.ring(at, r * 0.3, r * 0.3), Board.DAISY_INKS[2])

func _lay() -> void:
	var room := _tray().position.x - SIDE - WORDS_GAP
	_words(String(entry.get("title", "")), SIDE, size.y * 0.5 - 4.0, room, Pal.TEXT, BLURB)
