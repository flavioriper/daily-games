extends "res://ui/menu/cards/card_face.gd"

## Mushroom Patch's card: a corner of the patch on an autumn wood's floor.
## The board's parchment comes in from the card's bottom right corner and
## runs off both edges, so only its top left is seen: three numbers turned
## over along the patch's own edge, one mushroom planted between them, a
## pebble on the cell the first number rules out, and the rest still under
## its turf. The numbers are counted in code from where the mushrooms are,
## and washed as the board washes them: the 1 already holds its one and is
## green, the two 2s are still in ink. The 2 on the top row has one cell
## left to count -- the sod beside it, which is the go button, in the card's
## colour with a chevron. The name stands top left over fallen leaves, and
## the top right corner is left to the seal.
##
## The ground, the patch, the pebble and the go sod are one mesh; the three
## numerals are drawn over it, as the board writes them; the mushroom is the
## board's Control, idling.

const Board = preload("res://puzzles/mushroom2d.gd")
const MushroomFace = preload("res://ui/faces/mushroom_face.gd")
const Mosaic = preload("res://ui/faces/mosaic_tile.gd")
const Scenery = preload("res://ui/flat/scenery.gd")
const CozyTheme = preload("res://ui/theme.gd")

## The row the card was drawn for (puzzle_card_2d.gd's CARD_H).
const H := 246.0
## A cell at H, and how much of the patch shows: three columns and the edge
## of a fourth, two rows and most of a third.
const CELL := 62.0
const COLS_SHOWN := 3.3
const ROWS_SHOWN := 2.7
const COLS := 4
const ROWS := 3
## The words' margin from the card's sides, the room they are owed left of
## the patch and how far down they start.
const SIDE := 22.0
const WORDS := 266.0
const WORDS_GAP := 10.0
const WORDS_TOP := 14.0
## How far under the seal the patch's parchment may start.
const SEAL_CLEAR := SEAL_IN + SEAL_R + 4.0
## The parchment round the cells, and its corner, in cells.
const PLATE_PAD := 0.16
const PLATE_ROUND := 0.34
## The go sod, in cells, and how far it is lifted.
const GO_SIZE := 1.06
const GO_LIFT := 0.05

## Where the mushrooms are, which of them is planted, and what the player
## has turned over or ruled out. Everything past the fourth column and the
## third row is off the card and holds none.
const MUSHROOMS := [Vector2i(1, 1), Vector2i(2, 0)]
const PLANTED := [Vector2i(1, 1)]
const GIVEN := [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 1)]
const PEBBLED := [Vector2i(0, 1)]
const GO := Vector2i(2, 0)

## The wood's floor: warm light over amber, the litter heaped along the foot,
## and the fallen leaves as [x in the free width, y from the foot at H,
## length at H, angle, ink].
const FLOOR_TOP := Color("f9ecd3")
const FLOOR_LOW := Color("f0cd9f")
const LITTER := Color("e9bb85")
const LITTER_FAR := Color("eec593")
const BLURB := Color("7d6648")
const LEAVES := [
	[0.10, 34.0, 22.0, -0.5, Color("c8683f")],
	[0.34, 58.0, 17.0, 0.7, Color("dfa23c")],
	[0.58, 26.0, 20.0, -2.5, Color("b9573a")],
	[0.80, 70.0, 15.0, 2.2, Color("d98a3d")],
]

## The numerals, [centre, text, ink], written over the mesh.
var _nums: Array = []

func _k() -> float:
	return size.y / H

## The patch's own scale: the card's, unless the words or the seal want room.
func _ks() -> float:
	var wide := (size.x - SIDE - WORDS - WORDS_GAP) / (COLS_SHOWN * CELL)
	var tall := (size.y - SEAL_CLEAR - PLATE_PAD * CELL) / (ROWS_SHOWN * CELL)
	return minf(_k(), minf(wide, tall))

func _cell() -> float:
	return CELL * _ks()

## The patch's top left corner.
func _origin() -> Vector2:
	var c := _cell()
	return Vector2(size.x - COLS_SHOWN * c, size.y - ROWS_SHOWN * c)

func _mid(cell: Vector2i) -> Vector2:
	return _origin() + (Vector2(cell) + Vector2.ONE * 0.5) * _cell()

## How many mushrooms stand in the eight cells touching `cell`, of `among`.
static func _count(cell: Vector2i, among: Array) -> int:
	var total := 0
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			if (dx != 0 or dy != 0) and among.has(cell + Vector2i(dx, dy)):
				total += 1
	return total

## `pts` in `colour`, as much of it as lies on the paper.
func _on_paper(b: Face.Builder, paper: PackedVector2Array, pts: PackedVector2Array, colour: Color) -> void:
	for part in Geometry2D.intersect_polygons(paper, pts):
		b.polygon(part, colour)

func _paint(b: Face.Builder) -> void:
	var c := _cell()
	var k := _k()
	var paper := ground()
	var at := _origin()
	var first := b.verts.size()
	b.polygon(paper, Color.WHITE)
	shade(b, first, FLOOR_TOP, FLOOR_LOW, 0.0, size.y)
	# The litter heaped along the foot, left of the patch, and the leaves.
	var free := at.x
	_on_paper(b, paper, Face.Builder.ring(Vector2(free * 0.62, size.y + 12.0 * k), free * 0.5, 44.0 * k), LITTER_FAR)
	_on_paper(b, paper, Face.Builder.ring(Vector2(free * 0.2, size.y + 10.0 * k), minf(free * 0.42, 210.0 * k), 56.0 * k),
		LITTER)
	for leaf in LEAVES:
		MushroomFace._leaf(b, Vector2(SIDE + (free - SIDE * 2.0) * float(leaf[0]), size.y - float(leaf[1]) * k),
			float(leaf[2]) * k, float(leaf[3]), leaf[4])
	# The board's parchment, in from the corner: its shadow, its edge, itself.
	var pad := c * PLATE_PAD
	var plate_at := at - Vector2.ONE * pad
	var plate_size := size - plate_at + Vector2.ONE * c
	var round := c * PLATE_ROUND
	_on_paper(b, paper, Face.Builder.round_rect(plate_at - Vector2(5.0, 4.0) * k, plate_size, round),
		Color(Pal.BARK, 0.14))
	_on_paper(b, paper, Face.Builder.round_rect(plate_at - Vector2(1.5, 1.5) * k, plate_size, round),
		Pal.PARCHMENT.lerp(Pal.BARK, 0.22))
	_on_paper(b, paper, Face.Builder.round_rect(plate_at, plate_size, round), Pal.PARCHMENT)
	# The cells, as the board lays its floor: a bed under whatever is turned
	# over or marked, a sod over the rest.
	_nums.clear()
	var side := c * (1.0 - 2.0 * Board.CELL_INSET)
	var radius := c * Board.CELL_RADIUS
	for y in ROWS:
		for x in COLS:
			var cell := Vector2i(x, y)
			var mid := _mid(cell)
			if cell == GO and not soon:
				continue
			if GIVEN.has(cell):
				var value := _count(cell, MUSHROOMS)
				var settled := value > 0 and _count(cell, PLANTED) == value
				var wash: Dictionary = Board._wash_target(Board.State.SETTLED if settled else Board.State.SHORT, value)
				var floor_col: Color = Pal.SURFACE.lerp(wash.colour, float(wash.level))
				_bed(b, paper, mid, side, radius, c, floor_col)
				if value > 0:
					_nums.append([mid + Vector2(0.0, c * Board.BED_LIP * 0.5), str(value), wash.ink])
			elif PLANTED.has(cell):
				_bed(b, paper, mid, side, radius, c, Pal.MUSHROOM_TILE)
				Scenery.soft_disc(b, mid + Board.SHADOW_AT * c, Board.SHADOW_RX * c, Board.SHADOW_RY * c,
					Color(Pal.TEXT, Board.SHADOW_ALPHA))
			elif PEBBLED.has(cell):
				_bed(b, paper, mid, side, radius, c, Pal.SOCKET_OUT)
				Mosaic.pebble(b, mid, c * Board.PEBBLE * Board.PEBBLE_BODY / Mosaic.PEBBLE_R, Vector2.ONE, 1.0)
			else:
				var tone := Board._hash(cell) * 2.0 - 1.0
				var face: Color = Pal.TURF_REACH.lightened(tone * Board.TONE) if tone > 0.0 \
					else Pal.TURF_REACH.darkened(-tone * Board.TONE)
				_sod(b, paper, mid, side, radius, c, face.lerp(Pal.TURF, Board.TURF_FOOT),
					face.lerp(Pal.SURFACE, Board.TURF_LIT), face)
				# A tuft only on a sod the card shows whole.
				if x < COLS - 1 and y < ROWS - 1 and Board._hash(cell, 1) < 0.7:
					var root := Vector2((Board._hash(cell, 2) - 0.5) * 0.5, 0.2 + 0.12 * Board._hash(cell, 3)) * side
					Board._tuft(b, Transform2D(0.0, mid), root, c * Board.TUFT_H, Color(Pal.TURF, Board.TUFT_ALPHA))
	# The go button: the sod the top row's 2 has left to count.
	if not soon:
		_go(b, paper, _mid(GO) - Vector2(0.0, c * GO_LIFT), c)

## A bed about `at`, as Board._bed sinks one, kept on the paper.
func _bed(b: Face.Builder, paper: PackedVector2Array, at: Vector2, side: float, radius: float, c: float,
		floor_col: Color) -> void:
	var corner := at - Vector2.ONE * (side * 0.5)
	var lip := c * Board.BED_LIP
	_on_paper(b, paper, Face.Builder.round_rect(corner, Vector2.ONE * side, radius),
		floor_col.lerp(Pal.TEXT, Board.BED_WALL))
	_on_paper(b, paper, Face.Builder.round_rect(corner + Vector2(0.0, lip), Vector2(side, side - lip), radius),
		floor_col)

## A sod about `at`, as Board._turf cuts one (foot, lit rim, crown), kept on
## the paper.
func _sod(b: Face.Builder, paper: PackedVector2Array, at: Vector2, side: float, radius: float, c: float,
		foot: Color, rim: Color, face: Color) -> void:
	var corner := at - Vector2.ONE * (side * 0.5)
	var edge := side * (Board.FACE_SHORT + Board.FACE_DROP)
	var bev := c * Board.BEVEL
	_on_paper(b, paper, Face.Builder.round_rect(corner, Vector2.ONE * side, radius), foot)
	_on_paper(b, paper, Face.Builder.round_rect(corner, Vector2(side, side - edge), radius), rim)
	_on_paper(b, paper, Face.Builder.round_rect(corner + Vector2(bev * 0.7, bev),
		Vector2(side - bev * 1.4, side - edge - bev), maxf(radius - bev * 0.5, 0.0)), face)

## The go sod about `at`: a sod in the card's colour, lifted over its own
## shadow, with a chevron on the crown.
func _go(b: Face.Builder, paper: PackedVector2Array, at: Vector2, c: float) -> void:
	var s := c * GO_SIZE
	var side := s * (1.0 - 2.0 * Board.CELL_INSET)
	Scenery.soft_disc(b, at + Vector2(0.0, s * 0.36), s * 0.5, s * 0.2, Color(Pal.TEXT, 0.2))
	_sod(b, paper, at, side, s * Board.CELL_RADIUS, s, colour.darkened(0.26), colour.lerp(Pal.SURFACE, 0.36), colour)
	var mid := at + Vector2(s * 0.02, -s * 0.04)
	var h := s * 0.17
	b.stroke(PackedVector2Array([mid + Vector2(-h * 0.55, -h), mid + Vector2(h * 0.55, 0.0),
		mid + Vector2(-h * 0.55, h)]), s * 0.11, Pal.SURFACE)

func _draw() -> void:
	super()
	var font: Font = CozyTheme.display(700)
	var px := int(roundf(_cell() * Board.NUM_SIZE))
	if px <= 0:
		return
	var rise := font.get_ascent(px) * 0.5
	for n in _nums:
		var wide := font.get_string_size(n[1], HORIZONTAL_ALIGNMENT_LEFT, -1.0, px).x
		draw_string(font, n[0] + Vector2(-wide * 0.5, rise), n[1], HORIZONTAL_ALIGNMENT_LEFT, -1.0, px, n[2])

func _lay() -> void:
	var c := _cell()
	var seat := c * Board.MUSHROOM / MushroomFace.RATIO
	for cell: Vector2i in PLANTED:
		var cap := MushroomFace.new()
		cap.size = Vector2(seat, seat)
		cap.position = _mid(cell) - cap.size * 0.5
		_keep(cap)
		cap.set_idle(true)
	# The name runs over the patch's top edge, clear of the seal; the blurb
	# breaks short of the patch.
	var room := size.x - SIDE - (SEAL_IN + SEAL_R + 10.0)
	var words := _words(String(entry.get("title", "")), SIDE, size.y * 0.5, room, Pal.TEXT, BLURB)
	words.position.y = roundf(WORDS_TOP * _k())
