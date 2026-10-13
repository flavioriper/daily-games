extends "res://ui/menu/cards/card_face.gd"

## Shikaku's card: a corner of the garden on a meadow. A field three cells
## by four stands down the card's left side, as tall as the phone's own, with
## three beds already dug and fenced round their signs -- a four in a two by
## two, a three in a one by three, a two in a one by two -- so the rule is
## read once: a sign's number is its bed's cells. The last row is the plot
## nobody has drawn yet, and it is the go button: a bed in the card's colour,
## three cells for the sign of three that waits in it, with a chevron where
## the furrows would be. The name stands in the grass beside the field.
##
## The ground, the tilled beds, the fence and the settled signs are one mesh
## (the signs baked as the board bakes its own, puzzles/shikaku2d.gd's
## _bake_signs); the waiting sign is the board's Control, idling as it does
## there.

const Board = preload("res://puzzles/shikaku2d.gd")
const MarkerFace = preload("res://ui/faces/marker_face.gd")
const CozyTheme = preload("res://ui/theme.gd")

## The row the card was drawn for (puzzle_card_2d.gd's CARD_H); the field
## grows with a taller one.
const H := 246.0
## A cell at H, the field in cells, its margin from the card's left edge and
## the room the words are owed beside it.
const CELL := 50.0
const COLS := 3
const ROWS := 4
const SIDE := 22.0
const WORDS := 250.0
const WORDS_GAP := 20.0
## The field's corner and bottom edge and a bed's corner, in cells (the
## board's GROUND_RADIUS, GROUND_EDGE and BED_RADIUS on a cell of about 130).
const GROUND_ROUND := 0.2
const GROUND_LIP := 0.09
const BED_ROUND := 0.11
## The dug beds, in cells, each with its sign's cell: the sign's number is
## the bed's area.
const BEDS := [
	[Rect2i(0, 0, 1, 3), Vector2i(0, 1)],
	[Rect2i(1, 0, 2, 2), Vector2i(1, 0)],
	[Rect2i(1, 2, 2, 1), Vector2i(2, 2)],
]
## The plot still to draw, and the cell its sign waits in.
const GO := Rect2i(0, 3, 3, 1)
const GO_SIGN := Vector2i(0, 3)

const MEADOW_TOP := Color("eef3dc")
const MEADOW_LOW := Color("d5e2ae")
## The flowers in the grass under the words: [x from the right edge, y from
## the bottom, height, the board's BLOOMS index], at H.
const FLOWERS := [[112.0, 14.0, 26.0, 0], [78.0, 10.0, 34.0, 2], [44.0, 16.0, 24.0, 3]]

## The settled signs' numerals, as MarkerFace.numeral() gives them, written
## over the mesh.
var _nums: Array = []

## The field's own scale: the card's, unless that would take the words' room.
func _k() -> float:
	return minf(size.y / H, (size.x - SIDE * 2.0 - WORDS_GAP - WORDS) / (CELL * COLS))

func _cell() -> float:
	return CELL * _k()

func _origin() -> Vector2:
	var c := _cell()
	return Vector2(SIDE, (size.y - c * ROWS - c * GROUND_LIP) * 0.5)

func _rect(r: Rect2i) -> Rect2:
	var c := _cell()
	return Rect2(_origin() + Vector2(r.position) * c, Vector2(r.size) * c)

## A sign's top left corner and its seat, standing in `cell` as the board
## stands one (MARKER, MARKER_LIFT).
func _seat(cell: Vector2i) -> Rect2:
	var c := _cell()
	var s := c * Board.MARKER
	var mid := _origin() + (Vector2(cell) + Vector2(0.5, 0.5 - Board.MARKER_LIFT)) * c
	return Rect2(mid - Vector2(s, s) * 0.5, Vector2(s, s))

func _paint(b: Face.Builder) -> void:
	var c := _cell()
	var k := _k()
	var paper := ground()
	var first := b.verts.size()
	b.polygon(paper, Color.WHITE)
	shade(b, first, MEADOW_TOP, MEADOW_LOW, 0.0, size.y)
	# A rise of deeper grass along the bottom, and the flowers on it.
	var hk := size.y / H
	for hill in [[0.74, 0.60, 0.26, 0.30], [0.36, 0.42, 0.16, 0.22]]:
		var mid := Vector2(size.x * hill[0], size.y + size.y * 0.06)
		for part in Geometry2D.intersect_polygons(paper, Face.Builder.ring(mid, size.x * hill[1], size.y * hill[2])):
			b.polygon(part, Color(Pal.MEADOW_LINE, hill[3]))
	for f in FLOWERS:
		_flower(b, Vector2(size.x - f[0] * hk, size.y - f[1] * hk), f[2] * hk, f[3])
	# The field: its bottom edge, the bare ground and the grid.
	var at := _origin()
	var field := Vector2(COLS, ROWS) * c
	b.polygon(Face.Builder.round_rect(at + Vector2(0.0, c * 0.16), field + Vector2(0.0, c * GROUND_LIP), c * GROUND_ROUND),
		Color(Pal.LEAF_DEEP, 0.14))
	b.polygon(Face.Builder.round_rect(at, field + Vector2(0.0, c * GROUND_LIP), c * GROUND_ROUND), Pal.LINE)
	b.polygon(Face.Builder.round_rect(at, field, c * GROUND_ROUND), Pal.BED_GROUND)
	var line := Color(Pal.BED_LINE, Board.GRID_ALPHA)
	for x in range(1, COLS):
		b.stroke(PackedVector2Array([at + Vector2(x * c, 0.0), at + Vector2(x * c, field.y)]), 1.5 * k, line, false, false)
	for y in range(1, ROWS):
		b.stroke(PackedVector2Array([at + Vector2(0.0, y * c), at + Vector2(field.x, y * c)]), 1.5 * k, line, false, false)
	# The beds, tilled, with a shoot in every cell but the sign's.
	for bed in BEDS:
		_bed(b, bed[0], Pal.BED_SOIL, Pal.BED_FURROW, true)
		var r: Rect2i = bed[0]
		for x in r.size.x:
			for y in r.size.y:
				if r.position + Vector2i(x, y) != bed[1]:
					_shoot(b, at + (Vector2(r.position) + Vector2(x, y) + Board.SEED_AT) * c, c * Board.SEED_SIZE * 0.62, (x + y * 2) % 3)
	# The plot to draw: the go button.
	if not soon:
		_bed(b, GO, colour, colour.darkened(0.22), false)
		var g := _rect(GO)
		b.polygon(Face.Builder.round_rect(g.position + Vector2(g.size.x * 0.40, c * 0.13), Vector2(g.size.x * 0.44, c * 0.07), c * 0.035),
			Color(1.0, 1.0, 1.0, 0.26))
		var mid := g.position + Vector2(g.size.x * 0.64, g.size.y * 0.5 - c * 0.03)
		var h := c * 0.2
		b.stroke(PackedVector2Array([mid + Vector2(-h * 0.55, -h), mid + Vector2(h * 0.55, 0.0),
			mid + Vector2(-h * 0.55, h)]), c * 0.13, Pal.SURFACE)
	_fence(b)
	# The signs' shadows on the ground (the board's SHADOW_AT, SHADOW_RX,
	# SHADOW_RY), then the settled signs themselves, grinning.
	var cells: Array = [GO_SIGN]
	for bed in BEDS:
		cells.append(bed[1])
	for cell: Vector2i in cells:
		var seat := _seat(cell)
		b.ellipse(seat.get_center() + Board.SHADOW_AT * seat.size.x, seat.size.x * Board.SHADOW_RX,
			seat.size.x * Board.SHADOW_RY, Color(0.20, 0.12, 0.05, Board.SHADOW_ALPHA))
	_nums = []
	for bed in BEDS:
		var seat := _seat(bed[1])
		var m := _sign(seat, (bed[0] as Rect2i).get_area())
		m.expression = Face.Expr.JOY
		var xf := Transform2D(0.0, seat.position)
		m.bake_into(b, xf, Color.WHITE, true)
		var n := m.numeral()
		if not n.is_empty():
			n[0] = xf * n[0]
			_nums.append(n)
		m.free()

func _draw() -> void:
	super()
	for n in _nums:
		draw_string(CozyTheme.display(700), n[0], n[1], HORIZONTAL_ALIGNMENT_LEFT, -1.0, n[2], n[3])

## One of the board's signs for `seat`, casting nothing of its own.
func _sign(seat: Rect2, number: int) -> MarkerFace:
	var m := MarkerFace.new()
	m.casts = false
	m.number = number
	m.size = seat.size
	m.position = seat.position
	return m

## A bed over `r`: its lip, its earth and, tilled, the two mounds along
## every row, broken at every seam so the cells can still be counted (the
## board's _build_bed).
func _bed(b: Face.Builder, r: Rect2i, soil: Color, deep: Color, tilled: bool) -> void:
	var c := _cell()
	var px := _rect(r)
	var inset := maxf(1.0, c * 0.03)
	var lip := maxf(2.0, c * 0.06)
	var at := px.position + Vector2.ONE * inset
	var inner := px.size - Vector2.ONE * inset * 2.0
	b.polygon(Face.Builder.round_rect(at, inner, c * BED_ROUND), deep)
	b.polygon(Face.Builder.round_rect(at, inner - Vector2(0.0, lip), c * BED_ROUND), soil)
	if not tilled:
		return
	var rw := c * Board.RIDGE_WIDTH
	var mound := soil.lerp(Pal.SURFACE, Board.RIDGE_LIGHT)
	var crest := soil.lerp(Pal.SURFACE, Board.CREST_LIGHT)
	for row in r.size.y:
		for col in r.size.x:
			var x0 := px.position.x + (col + Board.RIDGE_MARGIN + 0.04) * c
			var x1 := px.position.x + (col + 1.0 - Board.RIDGE_MARGIN - 0.04) * c
			for ridge: float in Board.RIDGES:
				var y := px.position.y + (row + ridge) * c - lip * 0.5
				b.stroke(PackedVector2Array([Vector2(x0, y + rw * 0.35), Vector2(x1, y + rw * 0.35)]), rw,
					Color(deep, Board.GROOVE_ALPHA))
				b.stroke(PackedVector2Array([Vector2(x0, y), Vector2(x1, y)]), rw, mound)
				b.stroke(PackedVector2Array([Vector2(x0 + rw * 0.5, y - rw * 0.2), Vector2(x1 - rw * 0.5, y - rw * 0.2)]),
					rw * Board.CREST_SHARE, crest)

## The fence along every seam between two plots: the rail over its shade,
## lit along the top where it lies, a capped post where runs meet and a
## small one mid-run (the board's _fence_mesh).
func _fence(b: Face.Builder) -> void:
	var c := _cell()
	var at := _origin()
	var fw := maxf(3.0, c * Board.FENCE_WIDTH * 1.25)
	# Unit seams, keyed by their two lattice points, and the lattice points
	# that are some plot's corner.
	var seams := {}
	var corners := {}
	var plots: Array = [GO]
	for bed in BEDS:
		plots.append(bed[0])
	for r: Rect2i in plots:
		for p in [r.position, r.position + Vector2i(r.size.x, 0), r.end, r.position + Vector2i(0, r.size.y)]:
			corners[p] = true
		if r == GO:
			continue
		for x in r.size.x:
			for y in [r.position.y, r.end.y]:
				if y > 0 and y < ROWS:
					seams[[Vector2i(r.position.x + x, y), Vector2i(r.position.x + x + 1, y)]] = true
		for y in r.size.y:
			for x in [r.position.x, r.end.x]:
				if x > 0 and x < COLS:
					seams[[Vector2i(x, r.position.y + y), Vector2i(x, r.position.y + y + 1)]] = true
	var shade_by := Vector2(0.0, fw * 0.5)
	var lit: Color = Pal.FENCE_RAIL.lerp(Pal.SURFACE, 0.55)
	var posts := {}
	for s: Array in seams:
		posts[s[0]] = true
		posts[s[1]] = true
		b.stroke(PackedVector2Array([at + Vector2(s[0]) * c + shade_by, at + Vector2(s[1]) * c + shade_by]), fw, Pal.FENCE_DARK)
	for s: Array in seams:
		var p0 := at + Vector2(s[0]) * c
		var p1 := at + Vector2(s[1]) * c
		b.stroke(PackedVector2Array([p0, p1]), fw * Board.RAIL_SHARE, Pal.FENCE_RAIL)
		if s[0].y == s[1].y:
			var up := Vector2(0.0, -fw * Board.RAIL_SHARE * 0.22)
			b.stroke(PackedVector2Array([p0 + up, p1 + up]), fw * Board.RAIL_SHARE * Board.RAIL_LIT, lit)
	for p: Vector2i in posts:
		# A post on the field's own edge would hang over its rounded ground.
		if p.x <= 0 or p.x >= COLS or p.y <= 0 or p.y >= ROWS:
			continue
		var big := corners.has(p)
		var r := fw * (Board.POST_SHARE if big else Board.MID_POST_SHARE)
		var mid := at + Vector2(p) * c
		b.disc(mid + Vector2(0.0, r * 0.35), r, Pal.FENCE_DARK)
		b.disc(mid, r, Pal.FENCE_POST if big else Pal.FENCE_RAIL.lerp(Pal.FENCE_POST, 0.5))
		if big:
			b.disc(mid + Vector2(-r, -r) * 0.25, r * Board.POST_CAP, lit)

## A settled bed's shoot: a stem leaning the way `variant` does and its two
## leaves, short of any bud.
func _shoot(b: Face.Builder, at: Vector2, s: float, variant: int) -> void:
	var lean := (variant - 1) * 0.16
	var tip := at + Vector2(s * lean * 0.5, -s)
	var bend := at + Vector2(s * lean * -0.25, -s * 0.55)
	b.ellipse(at + Vector2(0.0, s * 0.03), s * 0.30, s * 0.10, Color(Pal.BED_FURROW, 0.75))
	b.stroke(Face.Builder.bezier2(at, bend, tip, 8), maxf(1.6, s * 0.13), Pal.LEAF)
	_leaf(b, at.lerp(bend, 0.8), s * 0.62, -0.45 - lean, Pal.LEAF_LIGHT)
	_leaf(b, at.lerp(bend, 0.8) + Vector2(0.0, s * 0.08), s * 0.56, -2.7 - lean, Pal.LEAF)

## One of the win's flowers, `s` tall from its foot at `at`, in the board's
## BLOOMS pair `bloom`.
func _flower(b: Face.Builder, at: Vector2, s: float, bloom: int) -> void:
	var lean := (bloom % 3 - 1) * 0.16
	var tip := at + Vector2(s * lean * 0.5, -s)
	var bend := at + Vector2(s * lean * -0.25, -s * 0.55)
	b.stroke(Face.Builder.bezier2(at, bend, tip, 8), maxf(1.6, s * 0.09), Pal.LEAF)
	_leaf(b, at.lerp(bend, 0.7), s * 0.42, -0.35 - lean, Pal.LEAF_LIGHT)
	_leaf(b, at.lerp(bend, 0.7) + Vector2(0.0, s * 0.06), s * 0.38, -2.8 - lean, Pal.LEAF)
	var r := s * 0.30
	var n := 5 + bloom % 2
	for i in n:
		var dir := Vector2.from_angle(lean + TAU * i / n - PI * 0.5)
		b.ellipse(tip + dir * r * 0.62, r * 0.46, r * 0.46, Board.BLOOMS[bloom][0])
	b.disc(tip, r * 0.38, Board.BLOOMS[bloom][1])
	b.disc(tip + Vector2(-r, -r) * 0.1, r * 0.13, Color(Pal.SURFACE, 0.55))

## One leaf: a lens of length `ln` from `at`, turned by `ang` (the board's).
func _leaf(b: Face.Builder, at: Vector2, ln: float, ang: float, tint: Color) -> void:
	var turn := Transform2D(ang, at)
	var pts := Face.Builder.bezier2(Vector2.ZERO, Vector2(ln * 0.55, -ln * 0.42), Vector2(ln, 0.0))
	pts.append_array(Face.Builder.bezier2(Vector2(ln, 0.0), Vector2(ln * 0.55, ln * 0.42), Vector2.ZERO))
	var out := PackedVector2Array()
	for p in pts:
		out.append(turn * p)
	b.polygon(out, tint)

func _lay() -> void:
	# The sign still waiting for its plot, awake.
	var seat := _seat(GO_SIGN)
	var waiting := _sign(seat, GO.get_area())
	_keep(waiting)
	waiting.set_idle(true)
	var x := SIDE + _cell() * COLS + WORDS_GAP
	_words(String(entry.get("title", "")), x, size.y * 0.5 - 4.0, size.x - x - SIDE + 6.0, Pal.TEXT, Color("6f6a4c"))
