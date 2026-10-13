extends "res://ui/menu/cards/card_face.gd"

## Pinwheel's card: the board's frame coming up from the card's foot, right
## of the middle, its lower rows run off the bottom edge. Three paper pieces
## lie on it in the board's cloths, each held through one of its own squares
## by its pinwheel, and between them they leave one hole: an elbow of three
## cells. The piece that fills it is the go button -- an elbow in the card's
## colour, lifted off the frame and caught a part of a turn short of home,
## swung about its own pin as the board swings one, with a short arrow over
## it for the clockwise quarter a tap gives and a chevron on its arm. The
## name stands top left on a primrose paper, a toy pinwheel on its stick in
## the bottom left corner, and the top right corner is left to the seal.
##
## Everything is one mesh and nothing lives on it.

const Board = preload("res://puzzles/pinwheel2d.gd")
const Cloth = preload("res://ui/faces/patch_cloth.gd")
const PinWheel = preload("res://ui/faces/pin_wheel.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

## The row the card was drawn for (puzzle_card_2d.gd's CARD_H).
const H := 246.0
## A cell at H, the frame's columns and rows, and how many rows stand above
## the card's foot.
const CELL := 44.0
const COLS := 5
const ROWS := 3
const ROWS_SHOWN := 2.3
## The frame's ground round the cells, its corner and its rim, in cells, and
## how far its right side stands in from the card's, at H.
const PAD := 0.2
const FRAME_ROUND := 0.3
const RIM := 0.085
const RIGHT := 16.0
## The pieces on the frame: [cloth, pin, cells].
const PIECES := [
	[2, Vector2i(0, 1), [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(0, 2)]],
	[4, Vector2i(1, 1), [Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2)]],
	[1, Vector2i(4, 1), [Vector2i(4, 0), Vector2i(4, 1), Vector2i(4, 2)]],
]
## The go piece: the cells of the hole, the pin it swings about, how far
## short of home it is caught (the board turns clockwise, so it is behind),
## how far it is lifted, in cells, and the arm that carries the chevron.
const GO := [Vector2i(2, 0), Vector2i(3, 0), Vector2i(3, 1)]
const GO_PIN := Vector2i(3, 0)
const GO_TURN := -0.42
const GO_LIFT := Vector2(0.0, -0.5)
const GO_MARK := Vector2i(2, 0)
const GO_SHADOW := Vector2(0.1, 0.34)
const GO_WHEEL := 0.34
## The arrow over the go piece: its radius about the pin, in cells, and the
## arc it runs, clockwise.
const ARROW_R := 1.02
const ARROW_FROM := -2.2
const ARROW_TO := -1.06
const ARROW_W := 0.085
## The words' margin and how far down they start.
const SIDE := 22.0
const WORDS := 266.0
const WORDS_TOP := 14.0
## The toy pinwheel in the corner: where its hub stands from the bottom left
## at H, its radius and its lean.
const TOY_AT := Vector2(56.0, 86.0)
const TOY_R := 27.0
const TOY_TURN := 0.3

## The paper: primrose over butter, the rise along the foot, and the blurb.
const PAPER_TOP := Color("fdf7dc")
const PAPER_LOW := Color("f9e9ab")
const RISE := Color("f4dd92")
const RISE_FAR := Color("f7e4a2")
const BLURB := Color("86753f")
const STICK := Color("c9a56a")

func _k() -> float:
	return size.y / H

func _cell() -> float:
	return CELL * _k()

## The top left corner of the frame's cells.
func _origin() -> Vector2:
	var c := _cell()
	return Vector2(size.x - RIGHT * _k() - (float(COLS) + PAD) * c, size.y - ROWS_SHOWN * c)

static func _span(pin: Vector2i) -> Vector2i:
	return Vector2i(pin.x * 2 + 1, pin.y * 2 + 1)

static func _moved(pts: PackedVector2Array, by: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(pts.size())
	for i in pts.size():
		out[i] = pts[i] + by
	return out

## `pts` in `ink`, as much of it as lies on the paper.
func _on_paper(b: Face.Builder, paper: PackedVector2Array, pts: PackedVector2Array, ink: Color) -> void:
	for part in Geometry2D.intersect_polygons(paper, pts):
		b.polygon(part, ink)

## The closed line `loop` in `ink`, as much of it as lies on the paper.
func _line_on_paper(b: Face.Builder, paper: PackedVector2Array, loop: PackedVector2Array, width: float,
		ink: Color) -> void:
	var line := loop.duplicate()
	line.append(loop[0])
	# Short of the paper's edge by the line's own half width and its cap.
	for within: PackedVector2Array in Geometry2D.offset_polygon(paper, -(width * 0.5 + 2.0)):
		for part in Geometry2D.intersect_polyline_with_polygon(line, within):
			if part.size() >= 2:
				b.stroke(part, width, ink, false, false)

## Every triangle of `from` that lies whole on the paper, into `b`: how the
## small marks (print, stitch, wheel) stop at the card's edge.
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

func _paint(b: Face.Builder) -> void:
	var c := _cell()
	var k := _k()
	var paper := ground()
	var at := _origin()
	var first := b.verts.size()
	b.polygon(paper, Color.WHITE)
	shade(b, first, PAPER_TOP, PAPER_LOW, 0.0, size.y)
	# The rise along the foot, left of the frame, and the toy on its stick.
	var free := at.x - PAD * c
	_on_paper(b, paper, Face.Builder.ring(Vector2(free * 0.66, size.y + 14.0 * k), free * 0.5, 46.0 * k), RISE_FAR)
	_on_paper(b, paper, Face.Builder.ring(Vector2(free * 0.16, size.y + 12.0 * k), minf(free * 0.44, 200.0 * k), 52.0 * k),
		RISE)
	_toy(b, Vector2(TOY_AT.x * k, size.y - TOY_AT.y * k), k)
	_frame(b, paper, at, c)
	var marks := Face.Builder.new()
	for piece in PIECES:
		_piece(b, marks, paper, at, c, int(piece[0]), piece[1], piece[2])
	# Every pinwheel over every piece, as the board lays them.
	var r := c * Board.PIN_R
	for piece in PIECES:
		var hub := at + (Vector2(piece[1]) + Vector2.ONE * 0.5) * c
		PinWheel.shadow(marks, hub, r, Pal.TEXT)
		PinWheel.wheel(marks, hub, r, 0.0, Pal.LINE, Pal.SURFACE, PinWheel.BRASS, Cloth.cloth_deep(int(piece[0])))
	_take(b, marks, paper)
	if not soon:
		_go(b, at + GO_LIFT * c, c)

## The frame as Board._build_frame lays it, run off the card's foot: its
## ground, the rules between its cells, a puff on each, and its rim.
func _frame(b: Face.Builder, paper: PackedVector2Array, at: Vector2, c: float) -> void:
	var pad := PAD * c
	var corner := at - Vector2.ONE * pad
	var box := Vector2(float(COLS) * c + 2.0 * pad, size.y - corner.y + c)
	var panel := Face.Builder.round_rect(corner, box, FRAME_ROUND * c)
	_on_paper(b, paper, _moved(panel, Vector2(0.0, 0.07 * c)), Color(Pal.TEXT, 0.1))
	_on_paper(b, paper, panel, Pal.QUILT_BACK)
	var marks := Face.Builder.new()
	var w := maxf(1.5, c * Board.RULE_W * 1.6)
	var foot := at.y + float(ROWS) * c
	for x in range(1, COLS):
		var px := at.x + float(x) * c
		marks.stroke(PackedVector2Array([Vector2(px, at.y), Vector2(px, foot)]), w, Pal.QUILT_RULE, false, false)
	for y in range(1, ROWS):
		var py := at.y + float(y) * c
		marks.stroke(PackedVector2Array([Vector2(at.x, py), Vector2(at.x + float(COLS) * c, py)]), w, Pal.QUILT_RULE,
			false, false)
	_take(b, marks, paper)
	var puff := Color(Pal.SURFACE, Board.PUFF_ALPHA)
	for cell: Vector2i in GO:
		_on_paper(b, paper, Face.Builder.round_rect(at + (Vector2(cell) + Vector2.ONE * Board.PUFF_INSET) * c,
			Vector2.ONE * (1.0 - 2.0 * Board.PUFF_INSET) * c, Board.PUFF_R * c), puff)
	_line_on_paper(b, paper, panel, RIM * c, Pal.LINE)

## One piece at rest, as Board._put_piece lays one: its lip, its cloth, its
## print, the quilting stitch inside its edge and the solid edge round it.
func _piece(b: Face.Builder, marks: Face.Builder, paper: PackedVector2Array, at: Vector2, c: float, cloth: int,
		pin: Vector2i, cells: Array) -> void:
	var span := _span(pin)
	var loops: Array = Cloth.loops(cells)
	for loop: PackedVector2Array in loops:
		if Cloth._area(loop) <= 0.0:
			continue
		var pts := Cloth.laid(loop, at, c, span)
		_on_paper(b, paper, _moved(pts, Board.REST_SHADOW * c), Color(Pal.TEXT, Cloth.SHADOW_ALPHA * Board.REST_LEVEL))
		_on_paper(b, paper, _moved(pts, Vector2(0.0, Cloth.EDGE * c)), Cloth.cloth_deep(cloth))
		_on_paper(b, paper, pts, Cloth.cloth(cloth))
	var own := Face.Builder.new()
	Cloth.print_cloth(own, cells, cloth, at, c, span)
	for loop: PackedVector2Array in Cloth.inset_loops(cells):
		Cloth.dash_loop(own, Cloth.laid(loop, at, c, span, Vector2.ONE, 0.0, Cloth.RADIUS * 0.6),
			Cloth.QUILT_W * c, Cloth.QUILT_ON * c, Cloth.QUILT_OFF * c, Cloth.cloth_thread(cloth))
	_take(b, own, paper)
	for loop: PackedVector2Array in loops:
		if Cloth._area(loop) > 0.0:
			_line_on_paper(b, paper, Cloth.laid(loop, at, c, span), Board.EDGE_W * c, Cloth.cloth_stitch(cloth))

## The go piece, its cells' corner at `at`: the hole's own shape in the
## card's colour, turned short of home about its pin over its shadow, with
## its pinwheel, the chevron on its arm and the arrow of the turn over it.
func _go(b: Face.Builder, at: Vector2, c: float) -> void:
	var span := _span(GO_PIN)
	var hub := at + (Vector2(GO_PIN) + Vector2.ONE * 0.5) * c
	var deep := colour.darkened(0.26)
	for loop: PackedVector2Array in Cloth.loops(GO):
		if Cloth._area(loop) <= 0.0:
			continue
		var pts := Cloth.laid(loop, at, c, span, Vector2.ONE, GO_TURN)
		b.polygon(_moved(pts, GO_SHADOW * c), Color(Pal.TEXT, 0.18))
		b.polygon(_moved(pts, Vector2(0.0, Cloth.EDGE * c * 1.3)), deep)
		b.polygon(pts, colour)
		b.stroke(pts, Board.EDGE_W * c, colour.lerp(Pal.TEXT, Cloth.STITCH), true)
	for loop: PackedVector2Array in Cloth.inset_loops(GO):
		Cloth.dash_loop(b, Cloth.laid(loop, at, c, span, Vector2.ONE, GO_TURN, Cloth.RADIUS * 0.6),
			Cloth.QUILT_W * c * 1.2, Cloth.QUILT_ON * c, Cloth.QUILT_OFF * c, colour.lerp(Pal.SURFACE, 0.7))
	# The chevron, on the arm, turned with the piece.
	var mid := Cloth.place(Vector2(GO_MARK) + Vector2(0.48, 0.5), at, c, span, Vector2.ONE, GO_TURN)
	var h := c * 0.19
	var mark := PackedVector2Array()
	for v: Vector2 in [Vector2(-h * 0.55, -h), Vector2(h * 0.55, 0.0), Vector2(-h * 0.55, h)]:
		mark.append(mid + v.rotated(GO_TURN))
	b.stroke(mark, c * 0.12, Pal.SURFACE)
	var r := c * GO_WHEEL
	PinWheel.shadow(b, hub, r, Pal.TEXT)
	PinWheel.wheel(b, hub, r, GO_TURN, Pal.LINE, Pal.SURFACE, PinWheel.BRASS, deep)
	# The turn a tap gives: a short arc over the piece, clockwise.
	var arc := Face.Builder.arc_points(hub, ARROW_R * c, ARROW_FROM, ARROW_TO)
	b.stroke(arc, ARROW_W * c, deep)
	var tip := arc[arc.size() - 1]
	var along := Vector2.from_angle(ARROW_TO + PI * 0.5)
	var head := c * 0.17
	b.stroke(PackedVector2Array([tip - along.rotated(0.6) * head, tip + along * head * 0.25,
		tip - along.rotated(-0.6) * head]), ARROW_W * c, deep)

## A toy pinwheel on its stick, standing in the rise.
func _toy(b: Face.Builder, hub: Vector2, k: float) -> void:
	var r := TOY_R * k
	b.stroke(PackedVector2Array([hub, Vector2(hub.x + 5.0 * k, size.y - 16.0 * k)]), 4.5 * k, STICK)
	Scenery.soft_disc(b, hub + Vector2(2.0, 5.0) * k, r, r, Color(Pal.TEXT, 0.08))
	PinWheel.wheel(b, hub, r, TOY_TURN, Pal.LINE, Pal.SURFACE, PinWheel.BRASS, Cloth.cloth(2))

func _lay() -> void:
	var words := _words(String(entry.get("title", "")), SIDE, size.y * 0.5, WORDS, Pal.TEXT, BLURB)
	words.position.y = roundf(WORDS_TOP * _k())
