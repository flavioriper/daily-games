extends "res://ui/menu/cards/card_face.gd"

## Quilt's card: the paper is the plate, a pale grey with a low stud on
## every cell, and the bricks are pressed onto its right side and run off
## the top, the bottom and the right edge. Their left edge is the frontier
## the bricks' own shapes make, stepping left under the words. Five bricks
## lie on one grid with no gap between them: a plain yellow square in the
## top right corner, which is the seal's (no studs, so the seal sits flat), a
## blue, a red, a green and a teal running off the foot. One notch is left
## in the frontier, three cells in an elbow, and the piece that fits it is
## the go button: a brick in the card's colour lifted off the notch over its
## own shadow, studded, a chevron on its elbow. A loose brick lies on the
## bare plate bottom left. (Until 2026-10-17 the card was linen, patches of
## printed cloth and a needle; ui/faces/brick_piece.gd says why.)
##
## Everything is one mesh; nothing lives on this card.

const Cloth = preload("res://ui/faces/brick_piece.gd")

## The row the card was drawn for (puzzle_card_2d.gd's CARD_H).
const H := 246.0
## A cell at H. The grid is five columns by six rows: four rows show, the
## first and the last only when the card is taller than the quilt's scale
## fills. A little under three columns stand right of the words.
const CELL := 64.0
const COLS_RIGHT := 2.9
const FIRST_COL := 2
const ROWS := 6
## The words' margin, the room they are owed left of the quilt, and how far
## down they start.
const SIDE := 22.0
const WORDS := 266.0
const WORDS_GAP := 8.0
const WORDS_TOP := 14.0

## The bricks as [colour, studded, cells]. Rows 0 and 5 lie off the card at
## H. The first is the seal's: plain, no studs.
const PATCHES := [
	[0, false, [Vector2i(3, 0), Vector2i(4, 0), Vector2i(3, 1), Vector2i(4, 1)]],
	[1, true, [Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 2), Vector2i(3, 2)]],
	[2, true, [Vector2i(4, 2), Vector2i(4, 3), Vector2i(3, 3)]],
	[3, true, [Vector2i(3, 4), Vector2i(4, 4), Vector2i(3, 5), Vector2i(4, 5)]],
	[6, true, [Vector2i(1, 5), Vector2i(2, 5)]],
]
## The notch, and the cell of it that carries the chevron.
const GO := [Vector2i(2, 3), Vector2i(1, 4), Vector2i(2, 4)]
const GO_MARK := Vector2i(2, 4)
## How far the go patch is lifted off its notch, and its shadow, in cells.
const GO_LIFT := Vector2(-0.2, -0.14)
const GO_SHADOW := Vector2(0.07, 0.17)

## The plate: a pale grey, lighter at the top, and its studs.
const LINEN_TOP := Color("e9ecf0")
const LINEN_LOW := Color("d8dde4")
const BLURB := Color("66707e")
## The loose brick on the bare plate: its top-left from the card's bottom
## left corner at H, its turn, its colour and its cells.
const LOOSE_AT := Vector2(70.0, 74.0)
const LOOSE_TURN := -0.28
const LOOSE := 4
const LOOSE_CELLS := [Vector2i(0, 0), Vector2i(1, 0)]

func _k() -> float:
	return size.y / H

## The quilt's own scale: the card's, unless the words want the room.
func _ks() -> float:
	return minf(_k(), (size.x - SIDE - WORDS - WORDS_GAP) / (COLS_RIGHT * CELL))

func _cell() -> float:
	return CELL * _ks()

## The grid's top left corner: column FIRST_COL stands COLS_RIGHT cells from
## the right edge and the six rows are centred on the card.
func _origin() -> Vector2:
	var c := _cell()
	return Vector2(size.x - (COLS_RIGHT + FIRST_COL) * c, (size.y - ROWS * c) * 0.5)

## `pts` in `ink`, as much of it as lies on the paper.
func _on_paper(b: Face.Builder, paper: PackedVector2Array, pts: PackedVector2Array, ink: Color) -> void:
	for part in Geometry2D.intersect_polygons(paper, pts):
		b.polygon(part, ink)

## Every triangle of `from` that lies whole on the paper, into `b`: how the
## small marks (print, stitch, chalk) stop at the card's edge.
static func _take(b: Face.Builder, from: Face.Builder, paper: PackedVector2Array) -> void:
	var n := from.verts.size()
	var inside := PackedByteArray()
	inside.resize(n)
	for i in n:
		inside[i] = 1 if Geometry2D.is_point_in_polygon(from.verts[i], paper) else 0
	var moved := PackedInt32Array()
	moved.resize(n)
	moved.fill(-1)
	for t in range(0, from.idx.size() - 2, 3):
		var tri := [from.idx[t], from.idx[t + 1], from.idx[t + 2]]
		if inside[tri[0]] == 0 or inside[tri[1]] == 0 or inside[tri[2]] == 0:
			continue
		for j in 3:
			var v: int = tri[j]
			if moved[v] < 0:
				moved[v] = b.vertex(from.verts[v], from.cols[v])
		b.tri(moved[tri[0]], moved[tri[1]], moved[tri[2]])

## `from` onto the paper: its triangles whole on the paper as they are, and
## the ones the card's edge cuts clipped to it, so a brick running off the
## card is cut at the edge rather than losing a sliver.
static func _clip(b: Face.Builder, from: Face.Builder, paper: PackedVector2Array) -> void:
	for t in range(0, from.idx.size() - 2, 3):
		var tri := PackedVector2Array([from.verts[from.idx[t]], from.verts[from.idx[t + 1]],
			from.verts[from.idx[t + 2]]])
		var col: Color = from.cols[from.idx[t]]
		var inside := true
		for v in tri:
			if not Geometry2D.is_point_in_polygon(v, paper):
				inside = false
		if inside:
			var a := b.vertex(tri[0], col)
			b.tri(a, b.vertex(tri[1], from.cols[from.idx[t + 1]]), b.vertex(tri[2], from.cols[from.idx[t + 2]]))
			continue
		for part in Geometry2D.intersect_polygons(paper, tri):
			b.polygon(part, col)

static func _span(cells: Array) -> Vector2i:
	var hi := Vector2i.ZERO
	for c: Vector2i in cells:
		hi = Vector2i(maxi(hi.x, c.x + 1), maxi(hi.y, c.y + 1))
	return hi

static func _moved(pts: PackedVector2Array, by: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(pts.size())
	for i in pts.size():
		out[i] = pts[i] + by
	return out

func _paint(b: Face.Builder) -> void:
	var c := _cell()
	var k := _k()
	var paper := ground()
	var at := _origin()
	var first := b.verts.size()
	b.polygon(paper, Color.WHITE)
	shade(b, first, LINEN_TOP, LINEN_LOW, 0.0, size.y)
	# The plate's low studs on every cell clear of the words.
	var marks := Face.Builder.new()
	var col := FIRST_COL
	while at.x + col * c > -c:
		col -= 1
	var r := Cloth.PLATE_STUD_R * c
	for y in ROWS:
		for x in range(col, FIRST_COL + 3):
			var mid := at + (Vector2(x, y) + Vector2(0.5, 0.5)) * c
			if mid.x - r < SIDE + WORDS:
				continue
			marks.disc(mid + Vector2(0.0, Cloth.PLATE_STUD * c), r, Color(Cloth.PLATE_DEEP, 0.8))
			marks.disc(mid, r, LINEN_TOP.lerp(Color.WHITE, 0.4))
			marks.disc(mid + Vector2(0.02, 0.03) * c, r * 0.8, LINEN_TOP.lerp(LINEN_LOW, (mid.y / size.y)))
	_take(b, marks, paper)
	# The bricks' weight on the plate, then each brick: side, face, bevel
	# and studs.
	for p in PATCHES:
		for loop: PackedVector2Array in Cloth.loops(p[2]):
			_on_paper(b, paper, _moved(Cloth.laid(loop, at, c, _span(p[2])), Vector2(-3.0, 5.0) * k),
				Color(Pal.TEXT, 0.12))
	for p in PATCHES:
		var ci: int = p[0]
		var cells: Array = p[2]
		var span := _span(cells)
		marks = Face.Builder.new()
		Cloth.patch(marks, Cloth.loops(cells), at, c, span, Cloth.cloth(ci), Cloth.cloth_deep(ci))
		if p[1]:
			Cloth.print_cloth(marks, cells, ci, at, c, span)
		_clip(b, marks, paper)
	# The loose brick on the bare plate.
	var loose := Face.Builder.new()
	var lat := Vector2(LOOSE_AT.x * k, size.y - LOOSE_AT.y * k)
	var lc := c * 0.62
	var lspan := _span(LOOSE_CELLS)
	var lshape := Cloth.loops(LOOSE_CELLS)
	Cloth.shadow(loose, lshape, lat, lc, lspan, Vector2(0.1, 0.22) * lc, 0.6, Vector2.ONE, LOOSE_TURN)
	Cloth.patch(loose, lshape, lat, lc, lspan, Cloth.cloth(LOOSE), Cloth.cloth_deep(LOOSE), Vector2.ONE, 1.0, LOOSE_TURN)
	Cloth.print_cloth(loose, LOOSE_CELLS, LOOSE, lat, lc, lspan, Vector2.ONE, 1.0, LOOSE_TURN)
	_clip(b, loose, paper)
	if not soon:
		_go(b, paper, at + GO_LIFT * c, c)

## The go button: the patch the notch wants, in the card's colour, lifted
## over its shadow, hemmed in pale thread, a chevron on its elbow.
func _go(b: Face.Builder, paper: PackedVector2Array, at: Vector2, c: float) -> void:
	var span := _span(GO)
	var deep := colour.darkened(0.3)
	for loop: PackedVector2Array in Cloth.loops(GO):
		var pts := Cloth.laid(loop, at, c, span)
		_on_paper(b, paper, _moved(pts, GO_SHADOW * c), Color(Pal.TEXT, 0.2))
		_on_paper(b, paper, _moved(pts, Vector2(0.0, Cloth.EDGE * c)), deep)
		_on_paper(b, paper, pts, colour.lerp(Pal.SURFACE, 0.06))
	var marks := Face.Builder.new()
	for cell: Vector2i in GO:
		if cell != GO_MARK:
			Cloth.stud(marks, at + (Vector2(cell) + Vector2(0.5, 0.5)) * c, c, colour.lerp(Pal.SURFACE, 0.06))
	var mid := at + (Vector2(GO_MARK) + Vector2(0.52, 0.5)) * c
	var h := c * 0.17
	marks.stroke(PackedVector2Array([mid + Vector2(-h * 0.55, -h), mid + Vector2(h * 0.55, 0.0),
		mid + Vector2(-h * 0.55, h)]), c * 0.11, Pal.SURFACE)
	_take(b, marks, paper)

func _lay() -> void:
	var words := _words(String(entry.get("title", "")), SIDE, size.y * 0.5, WORDS, Pal.TEXT, BLURB)
	words.position.y = roundf(WORDS_TOP * _k())
