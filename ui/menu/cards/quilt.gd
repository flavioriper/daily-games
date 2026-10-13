extends "res://ui/menu/cards/card_face.gd"

## Quilt's card: the paper is the backing cloth, a heather linen with a faint
## chalked grid, and the quilt is sewn onto its right side and runs off the
## top, the bottom and the right edge. Its left edge is the frontier the
## patches' own shapes make, stepping left under the words. Five patches of
## the board's cloth lie on one grid with no gap between them: a plain butter
## square in the top right corner, which is the seal's, a sky gingham, a coral
## sprig, a sage pinstripe and a teal running off the foot. One notch is left
## in the frontier, three cells in an elbow, and the piece that fits it is the
## go button: a patch in the card's colour lifted off the notch over its own
## shadow, hemmed in pale thread, a chevron on its elbow. A needle lies on the
## bare backing bottom left with its thread behind it.
##
## Everything is one mesh; nothing lives on this card.

const Cloth = preload("res://ui/faces/patch_cloth.gd")

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

## The sewn patches as [cloth, printed, cells]. Rows 0 and 5 lie off the
## card at H. The first is the seal's: plain, no print, no stitch.
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

## The backing: heather linen, lighter at the top, and the chalk of its grid.
const LINEN_TOP := Color("ebe6f2")
const LINEN_LOW := Color("dad2e7")
const CHALK := Color("f6f2fa")
const CHALK_ALPHA := 0.7
const BLURB := Color("6d6680")
## The needle, from the card's bottom left corner at H, and its heading.
const NEEDLE_AT := Vector2(96.0, 46.0)
const NEEDLE_DIR := Vector2(0.94, -0.34)

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
	var marks := Face.Builder.new()
	# The chalked grid over the bare backing, as far left as the card goes.
	var chalk := Color(CHALK, CHALK_ALPHA)
	var width := maxf(1.5, c * 0.026)
	var col := FIRST_COL
	while at.x + col * c > 0.0:
		col -= 1
	for x in range(col + 1, FIRST_COL + 1):
		Cloth.stitch(marks, Vector2(at.x + x * c, 0.0), Vector2(at.x + x * c, size.y), width, c * 0.1, c * 0.1, chalk)
	for y in range(1, ROWS):
		Cloth.stitch(marks, Vector2(0.0, at.y + y * c), Vector2(at.x + FIRST_COL * c, at.y + y * c), width,
			c * 0.1, c * 0.1, chalk)
	_take(b, marks, paper)
	# The quilt's weight on the backing, then each patch: lip, cloth, print
	# and the quilting stitch just inside its edge.
	for p in PATCHES:
		for loop: PackedVector2Array in Cloth.loops(p[2]):
			_on_paper(b, paper, _moved(Cloth.laid(loop, at, c, _span(p[2])), Vector2(-3.0, 4.0) * k),
				Color(Pal.TEXT, 0.1))
	marks = Face.Builder.new()
	for p in PATCHES:
		var cloth: int = p[0]
		var cells: Array = p[2]
		var span := _span(cells)
		for loop: PackedVector2Array in Cloth.loops(cells):
			var pts := Cloth.laid(loop, at, c, span)
			_on_paper(b, paper, _moved(pts, Vector2(0.0, Cloth.EDGE * c)), Cloth.cloth_deep(cloth))
			_on_paper(b, paper, pts, Cloth.cloth(cloth))
		if not p[1]:
			continue
		Cloth.print_cloth(marks, cells, cloth, at, c, span)
		for loop: PackedVector2Array in Cloth.inset_loops(cells):
			Cloth.dash_loop(marks, Cloth.laid(loop, at, c, span, Vector2.ONE, 0.0, Cloth.RADIUS - Cloth.QUILT_INSET),
				c * Cloth.QUILT_W, c * Cloth.QUILT_ON, c * Cloth.QUILT_OFF, Cloth.cloth_thread(cloth))
	_take(b, marks, paper)
	# The needle on the bare backing, its thread lying behind it.
	var eye := Vector2(NEEDLE_AT.x * k, size.y - NEEDLE_AT.y * k)
	var dir := NEEDLE_DIR.normalized()
	var thread := Color("f8f4fb")
	var tail := eye - dir * 0.24 * c
	b.stroke(Face.Builder.bezier3(tail, tail - dir * 0.5 * c + Vector2(0.0, 0.3 * c),
		tail - dir * 0.9 * c + Vector2(0.0, -0.22 * c), tail - dir * 1.25 * c + Vector2(0.0, 0.16 * c)),
		0.03 * c, thread)
	Cloth.needle(b, eye, dir, c * 1.3, thread)
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
		_on_paper(b, paper, _moved(pts, Vector2(0.0, Cloth.EDGE * c * 1.4)), deep)
		_on_paper(b, paper, pts, colour.lerp(Pal.SURFACE, 0.06))
	var marks := Face.Builder.new()
	for loop: PackedVector2Array in Cloth.inset_loops(GO):
		Cloth.dash_loop(marks, Cloth.laid(loop, at, c, span, Vector2.ONE, 0.0, Cloth.RADIUS - Cloth.QUILT_INSET),
			c * 0.04, c * Cloth.QUILT_ON, c * Cloth.QUILT_OFF, colour.lerp(Pal.SURFACE, 0.72))
	var mid := at + (Vector2(GO_MARK) + Vector2(0.52, 0.5)) * c
	var h := c * 0.17
	marks.stroke(PackedVector2Array([mid + Vector2(-h * 0.55, -h), mid + Vector2(h * 0.55, 0.0),
		mid + Vector2(-h * 0.55, h)]), c * 0.11, Pal.SURFACE)
	_take(b, marks, paper)

func _lay() -> void:
	var words := _words(String(entry.get("title", "")), SIDE, size.y * 0.5, WORDS, Pal.TEXT, BLURB)
	words.position.y = roundf(WORDS_TOP * _k())
