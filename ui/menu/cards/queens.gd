extends "res://ui/menu/cards/card_face.gd"

## Queens' card: the court is the paper. Four rows of it run off every side
## of the card in a few large regions, in the board's own pastels under its
## ink seams, and one queen is seated near the right: the bee, on the gold
## her cell keeps, with the cross she casts along her row and her column,
## as far as the court is coloured. The go button is the
## seat of the next queen, a tile in the card's colour two columns off and a
## row down, in another colour: the one cell near her that she does not see.
## The name stands on the calm tan region, top left, which no cross reaches,
## and the top right cell is bare sky for the seal.
##
## The court, the crosses, the blooms and the go tile are one mesh; the bee
## is the board's Control, idling as she does there.

const Board = preload("res://puzzles/queens2d.gd")
const BeeFace = preload("res://ui/faces/bee_face.gd")
const CrossMark = preload("res://ui/faces/cross_mark.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

## The rows a card shows: the cell is the card's height over these, unless
## the words would lose their room.
const ROWS := 4
## The words' margin from the card's left side, and the least room they keep
## left of the queen's reach (es is the longest: "Una reina por fila,").
const SIDE := 24.0
const WORDS_MIN := 256.0
## The seams and the grid, in cells (the board's SEAM and GRID on a cell of
## about 110), and their least widths in pixels.
const SEAM := 0.046
const SEAM_MIN := 2.5
const GRID := 0.02
const GRID_MIN := 1.25

## The regions, as indices into Pal.REGION: the words' tan, the seal's sky,
## the queen's lavender, the go seat's apricot and a mint past it.
const TAN := 0
const LAVENDER := 1
const SKY := 2
const MINT := 3
const APRICOT := 4
## The queen and the go seat, as [columns from the right edge, row].
const QUEEN := Vector2i(1, 2)
const GO := Vector2i(3, 3)
## The go tile: its inset in the cell, its corner and its foot, in cells.
const GO_INSET := 0.09
const GO_ROUND := 0.2
const GO_FOOT := 0.07
## The blooms her own region opens once she is seated (the board's BLOOM_R
## and BLOOM_AT), by cell.
const BLOOMS := [Vector2i(2, 2), Vector2i(0, 3)]
const WORDS_DIM := Color("6a5a48")

func _cell() -> float:
	return minf(size.y / ROWS, (size.x - SIDE - WORDS_MIN) / 3.0)

func _rows() -> int:
	return int(ceilf(size.y / _cell() - 0.01))

func _cols() -> int:
	return int(ceilf(size.x / _cell()))

## The top left corner of the cell `r` columns in from the right edge.
func _at(r: int, row: int) -> Vector2:
	var c := _cell()
	return Vector2(size.x - (r + 1) * c, row * c)

func _mid(r: int, row: int) -> Vector2:
	return _at(r, row) + Vector2.ONE * _cell() * 0.5

## The region a cell is cut into. The court runs on to the left for as wide
## as the card is, and a row past the fourth belongs to the fourth.
static func _region(r: int, row: int) -> int:
	row = mini(row, ROWS - 1)
	if r <= 2 and row <= 1:
		return SKY
	if r == 0 and row == 2:
		return SKY
	if r <= 2:
		return LAVENDER
	if row <= 1:
		return TAN
	if r <= 5:
		return APRICOT
	if r <= 8:
		return MINT
	return TAN

## The cells the words stand on: laid plain, with no lip and no grid.
static func _calm(r: int, row: int) -> bool:
	return row <= 1 and r >= 3

## Whether the card crosses a cell: her row and her column, the two lines
## that read as her reach at this size. The board also crosses the eight
## that touch her and the rest of her region, and the tan is left bare.
static func _seen(r: int, row: int) -> bool:
	if r == QUEEN.x and row == QUEEN.y:
		return false
	if _region(r, row) == TAN:
		return false
	return r == QUEEN.x or row == QUEEN.y

static func _hash(r: int, row: int) -> float:
	return fposmod(sin(r * 12.9898 + row * 78.233) * 43758.5453, 1.0)

## How far the paper's corner cuts into a vertical line `x` from the left.
func _corner(x: float) -> float:
	var R := RADIUS - EDGE
	var d := minf(x - EDGE, size.x - EDGE - x)
	if d >= R:
		return 0.0
	d = maxf(d, 0.0)
	return R - sqrt(maxf(R * R - (R - d) * (R - d), 0.0))

func _clipped(b: Face.Builder, paper: PackedVector2Array, at: Vector2, s: Vector2, col: Color) -> void:
	var rect := PackedVector2Array([at, at + Vector2(s.x, 0.0), at + s, at + Vector2(0.0, s.y)])
	var inside := at.x >= RADIUS and at.x + s.x <= size.x - RADIUS \
		or at.y >= RADIUS and at.y + s.y <= size.y - RADIUS
	if inside and at.x >= EDGE and at.y >= EDGE and at.x + s.x <= size.x - EDGE and at.y + s.y <= size.y - EDGE:
		b.fan(rect, col)
		return
	for part in Geometry2D.intersect_polygons(paper, rect):
		b.polygon(part, col)

func _paint(b: Face.Builder) -> void:
	var c := _cell()
	var paper := ground()
	var rows := _rows()
	var cols := _cols()
	# The cells: each its region's colour, a touch off by its own hash, with
	# the lit top lip and the shaded foot the board gives it.
	var lip := c * Board.BEVEL
	for row in rows:
		for r in cols:
			var col: Color = Pal.REGION[_region(r, row)]
			var at := _at(r, row)
			if _calm(r, row):
				_clipped(b, paper, at, Vector2(c, c), col)
				continue
			var h := _hash(r, row)
			if h > 0.5:
				col = col.lightened(Board.TONE * 2.0 * (h - 0.5))
			else:
				col = col.darkened(Board.TONE * 2.0 * (0.5 - h))
			_clipped(b, paper, at, Vector2(c, c), col)
			_clipped(b, paper, at, Vector2(c, lip), col.lerp(Pal.PAPER, Board.BEVEL_LIT))
			_clipped(b, paper, at + Vector2(0.0, c - lip), Vector2(c, lip), col.lerp(Pal.TEXT, Board.BEVEL_SHADE))
	# The gold her own cell keeps, and her shadow on it.
	_clipped(b, paper, _at(QUEEN.x, QUEEN.y), Vector2(c, c), Color(Pal.QUEEN_WASH, Board.HALO_ALPHA))
	Scenery.soft_disc(b, _mid(QUEEN.x, QUEEN.y) + Board.BEE_SHADOW_AT * c, Board.BEE_SHADOW_RX * c,
		Board.BEE_SHADOW_RY * c, Color(Pal.TEXT, Board.SHADOW_ALPHA))
	# The grid inside a region, faint, and none under the words.
	var grid_w := maxf(c * GRID, GRID_MIN)
	var grid_ink := Color(Pal.TEXT, Board.GRID_ALPHA)
	var seam_w := maxf(c * SEAM, SEAM_MIN)
	var seams: Array = []
	for row in rows:
		for r in cols:
			var at := _at(r, row)
			var g := _region(r, row)
			# The edge to the cell on the left, and the one to the cell below.
			if at.x > EDGE + seam_w:
				var cut := _corner(at.x) + EDGE + seam_w * 0.5
				var line := PackedVector2Array([Vector2(at.x, maxf(at.y, cut)),
					Vector2(at.x, minf(at.y + c, size.y - cut))])
				if line[1].y > line[0].y:
					if _region(r + 1, row) != g:
						seams.append(line)
					elif not (_calm(r, row) and _calm(r + 1, row)):
						b.stroke(line, grid_w, grid_ink, false, false)
			if at.y + c < size.y - EDGE - seam_w:
				var inset := EDGE + seam_w * 0.5
				var line := PackedVector2Array([Vector2(maxf(at.x, inset), at.y + c),
					Vector2(minf(at.x + c, size.x - inset), at.y + c)])
				if line[1].x > line[0].x:
					if _region(r, row + 1) != g:
						seams.append(line)
					elif not (_calm(r, row) and _calm(r, row + 1)):
						b.stroke(line, grid_w, grid_ink, false, false)
	# The seams between two regions, in ink, round-ended so corners meet.
	for line: PackedVector2Array in seams:
		b.stroke(line, seam_w, Pal.TEXT)
	# The blooms: her region has its queen.
	for cell: Vector2i in BLOOMS:
		_bloom(b, _mid(cell.x, cell.y) + Board.BLOOM_AT * c, c * Board.BLOOM_R, _hash(cell.x, cell.y) * TAU)
	# The crosses she casts, as the board lays the ones it derives.
	for row in ROWS:
		for r in cols:
			if not _seen(r, row):
				continue
			var mid := _mid(r, row)
			if mid.x < c * 0.42 or mid.y > size.y - c * 0.3:
				continue
			CrossMark.draw(b, mid, c, Vector2.ONE * Board.AUTO_SCALE, Board.AUTO_ALPHA, 0.0, Pal.TEXT_DIM)
	# The go button: the next queen's seat.
	if not soon:
		_go(b, _at(GO.x, GO.y), c)

## The seat: a tile in the card's colour on a cream rim, its foot darker, a
## chevron on it.
func _go(b: Face.Builder, at: Vector2, c: float) -> void:
	var inset := c * GO_INSET
	var side := c - inset * 2.0
	var foot := c * GO_FOOT
	var round := c * GO_ROUND
	var tile := at + Vector2(inset, inset - foot * 0.3)
	b.polygon(Face.Builder.round_rect(tile + Vector2(0.0, foot * 1.3), Vector2(side, side), round), Color(Pal.TEXT, 0.2))
	b.polygon(Face.Builder.round_rect(tile - Vector2.ONE * 2.0, Vector2(side, side) + Vector2.ONE * 4.0, round + 2.0), Pal.SURFACE)
	b.polygon(Face.Builder.round_rect(tile, Vector2(side, side), round), colour.darkened(0.24))
	b.polygon(Face.Builder.round_rect(tile, Vector2(side, side - foot), round), colour)
	var mid := tile + Vector2(side, side - foot) * 0.5
	var h := c * 0.16
	b.stroke(PackedVector2Array([mid + Vector2(-h * 0.55, -h), mid + Vector2(h * 0.55, 0.0),
		mid + Vector2(-h * 0.55, h)]), c * 0.1, Pal.SURFACE)

## A bloom of `r`: five cream petals, each on its ink, round a gold middle.
func _bloom(b: Face.Builder, at: Vector2, r: float, turn: float) -> void:
	for p in Board.BLOOM_PETALS:
		var a := turn + TAU * p / Board.BLOOM_PETALS
		var dir := Vector2.from_angle(a)
		b.fan(Board._oval(at + dir * r * 0.55, r * 0.52, r * 0.3, a), Color(Pal.TEXT, 0.55))
		b.fan(Board._oval(at + dir * r * 0.55, r * 0.45, r * 0.23, a), Pal.SURFACE)
	b.disc(at, r * 0.32, Pal.SUN)

func _lay() -> void:
	var c := _cell()
	var bee := BeeFace.new()
	var px := c * Board.BEE_SIZE
	bee.size = Vector2(px, px)
	bee.position = _mid(QUEEN.x, QUEEN.y) - bee.size * 0.5
	_keep(bee)
	bee.set_idle(true)
	# The words stand on the tan, left of the column her reach touches.
	var room := size.x - 3.0 * c - SIDE - 6.0
	_words(String(entry.get("title", "")), SIDE, c + 3.0, room, Pal.TEXT, WORDS_DIM)
