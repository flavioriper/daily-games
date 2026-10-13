extends "res://ui/menu/cards/card_face.gd"

## Toy Cannons' card: a corner of the playroom on a pale mint floor. A small
## mat of the board's toy blocks stands low on the right, four by four, and
## the track runs under it along the card's foot and turns up its right side,
## as the board's loop does. Two of the board's cannons are on it, each
## pointing across the mat as a cannon on the loop does: a rose one at the
## foot that has popped two blocks of its column and has a cork in the air
## toward the third, which is rose and the nearest left in its line, and a
## yellow one up the side whose nearest block is yellow. The board's rule is
## kept: a cannon takes only the nearest block of the line it is passing, and
## only if it is its own colour (`_true`).
##
## The go button is the next cannon to send: in the card's colour, large,
## lifted out of the wooden tray at the foot where the board keeps the ones
## waiting, a chevron on its carriage up the way it fires. The mat's two
## nearest blocks at the foot's left are the same blue, so they are the first
## it will pop. The name stands top left.
##
## Everything is one mesh, the blocks, track, cannons and cork
## ui/faces/train_art.gd's own builders. Nothing lives on the card and it
## writes no string. (The board's id is `train`: docs/agents/boards/train.md.)

const Art = preload("res://ui/faces/train_art.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

## The row and the width the card was drawn for.
const H := 246.0
const W := 490.0
## A block's square at H, and the mat's room from the card's right side and
## foot.
const CELL := 30.0
const RIGHT := 44.0
const FOOT := 46.0
## The mat, top row first: R rose, Y yellow, G green, B the card's colour,
## a space a block popped, * the one popped a moment ago.
const MAT: Array[String] = [
	"GYRY",
	"GRRY",
	"BR*G",
	"BB G",
]
## The track: its gauge, how far its middle runs from the card's right side
## and foot, how far left the foot run starts, how high the side run ends
## (both from the card's right side and foot), and the bend's radius.
const GAUGE := 15.0
const TRACK_IN := 23.0
const TRACK_LEFT := 190.0
const TRACK_TOP := 160.0
const BEND := 15.0
## A cannon on the loop: its length, the column the foot one stands under,
## the row the side one stands by, and how far the cork has flown, as a
## share of the way from the muzzle to its block.
const UNIT := 36.0
const FOOT_COL := 2
const SIDE_ROW := 1
const CORK_AT := 0.5
## The tray: its right end and its foot from the card's right side and foot,
## its size, and where the small waiting cannon stands in it.
const TRAY_IN := 200.0
const TRAY_UP := 13.0
const TRAY := Vector2(112.0, 50.0)
const WAIT_IN := 284.0
const WAIT := 32.0
## The go cannon: its length, its place, how far it is lifted, its shadow.
const GO := 60.0
const GO_AT := Vector2(234.0, 44.0)
const GO_LIFT := 5.0
const GO_SHADOW := 0.22
## The words' margin, their room and how far down they start.
const SIDE := 22.0
const WORDS := 215.0
const WORDS_TOP := 14.0

## The floor: mint over a deeper mint, a pale pool behind the mat, the mat's
## cloth and its edge, and the blurb's ink.
const FLOOR_TOP := Color("e9f6ee")
const FLOOR_LOW := Color("d3ecdf")
const POOL := Color("f6fcf6")
const CLOTH := Color("f7faf1")
const CLOTH_EDGE := Color("b4d3c2")
const BLURB := Color("5c7468")

## The picture's scale: the card's height sets it, its width caps it.
func _k() -> float:
	return minf(size.y / H, size.x / W)

## A place given as [in from the card's right side, up from its foot] at H.
func _at(p: Vector2) -> Vector2:
	var k := _k()
	return Vector2(size.x - p.x * k, size.y - p.y * k)

## The middle of the mat's square in column `c`, row `r` (top row 0).
func _cell(c: int, r: int) -> Vector2:
	var cols := MAT[0].length()
	var rows := MAT.size()
	return _at(Vector2(RIGHT + (cols - c - 0.5) * CELL, FOOT + (rows - r - 0.5) * CELL))

func _ink(mark: String) -> Color:
	match mark:
		"R": return Art.colour("rose")
		"Y": return Art.colour("yellow")
		"G": return Art.colour("green")
	return colour

static func _is_block(mark: String) -> bool:
	return mark != " " and mark != "*"

## The nearest block up column `c` from the foot, as its row, or -1.
func _from_foot(c: int) -> int:
	for r in range(MAT.size() - 1, -1, -1):
		if _is_block(MAT[r][c]):
			return r
	return -1

## The nearest block along row `r` from the right, as its column, or -1.
func _from_side(r: int) -> int:
	for c in range(MAT[r].length() - 1, -1, -1):
		if _is_block(MAT[r][c]):
			return c
	return -1

## The picture keeps the board's rule: each cannon's nearest block is its
## own colour, and the go cannon's colour is the nearest in a foot line.
func _true() -> bool:
	var foot := _from_foot(FOOT_COL)
	var side := _from_side(SIDE_ROW)
	return foot >= 0 and MAT[foot][FOOT_COL] == "R" and side >= 0 and MAT[SIDE_ROW][side] == "Y" \
		and _from_foot(0) >= 0 and MAT[_from_foot(0)][0] == "B"

## Draws what `draw` builds about the origin under `xf`.
func _put(b: Face.Builder, xf: Transform2D, draw: Callable) -> void:
	var part := Face.Builder.new()
	draw.call(part)
	b.append(part.mesh(), xf)

func _paint(b: Face.Builder) -> void:
	var k := _k()
	var s := CELL * k
	var first := b.verts.size()
	b.polygon(ground(), Color.WHITE)
	shade(b, first, FLOOR_TOP, FLOOR_LOW, 0.0, size.y)
	var cols := MAT[0].length()
	var rows := MAT.size()
	var mid := (_cell(0, 0) + _cell(cols - 1, rows - 1)) * 0.5
	Scenery.soft_disc(b, mid + Vector2(-s * 0.6, s * 0.3), s * 4.4, s * 3.1, Color(POOL, 0.6))
	_track(b, k)
	# The mat the blocks stand on.
	var corner := _cell(0, 0) - Vector2.ONE * s * 0.5
	var cloth := Rect2(corner, Vector2(cols, rows) * s).grow(s * 0.13)
	b.polygon(Face.Builder.round_rect(cloth.position + Vector2(0.0, s * 0.09), cloth.size, s * 0.3), CLOTH_EDGE)
	b.polygon(Face.Builder.round_rect(cloth.position, cloth.size, s * 0.3), CLOTH)
	for r in rows:
		for c in cols:
			var mark := MAT[r][c]
			if _is_block(mark):
				Art.block(b, _cell(c, r), s, _ink(mark))
			elif mark == "*":
				_puff(b, _cell(c, r), s, Art.colour("rose"))
	_tray(b, k)
	var shot := _true()
	# The yellow cannon up the side, pointing left across the mat.
	var side := Vector2(_at(Vector2(TRACK_IN, 0.0)).x, _cell(0, SIDE_ROW).y)
	_put(b, Transform2D(-PI * 0.5, side), func(p: Face.Builder) -> void: Art.engine(p, UNIT * k, Art.colour("yellow")))
	# The rose one at the foot, pointing up its column, and its cork.
	var foot := Vector2(_cell(FOOT_COL, 0).x, _at(Vector2(0.0, TRACK_IN)).y)
	_put(b, Transform2D(0.0, foot), func(p: Face.Builder) -> void: Art.engine(p, UNIT * k, Art.colour("rose")))
	if shot:
		var muzzle := foot - Vector2(0.0, UNIT * k * 0.5)
		var block := _cell(FOOT_COL, _from_foot(FOOT_COL)) + Vector2(0.0, s * 0.5)
		_put(b, Transform2D(0.0, muzzle.lerp(block, CORK_AT)), func(p: Face.Builder) -> void: Art.cork(p, UNIT * k * 1.25))
	# The one waiting in the tray, and the go cannon.
	var wait := _at(Vector2(WAIT_IN, TRAY_UP + TRAY.y * 0.5 + 2.0))
	_put(b, Transform2D(0.0, wait), func(p: Face.Builder) -> void: Art.engine(p, WAIT * k, Art.colour("green")))
	if soon:
		var plain := _at(Vector2(GO_AT.x, TRAY_UP + TRAY.y * 0.5 + 2.0))
		_put(b, Transform2D(0.0, plain), func(p: Face.Builder) -> void: Art.engine(p, WAIT * k, colour))
	else:
		_go(b, _at(GO_AT) - Vector2(0.0, GO_LIFT * k), GO * k)

## The track: along the foot from the left, round the bend and up the right
## side, open at both ends.
func _track(b: Face.Builder, k: float) -> void:
	var pts := PackedVector2Array()
	var y := _at(Vector2(0.0, TRACK_IN)).y
	var x := _at(Vector2(TRACK_IN, 0.0)).x
	var r := BEND * k
	var step := GAUGE * k * 0.5
	var from := _at(Vector2(TRACK_LEFT, 0.0)).x
	var n := maxi(2, int((x - r - from) / step))
	for i in n:
		pts.append(Vector2(lerpf(from, x - r, float(i) / n), y))
	var centre := Vector2(x - r, y - r)
	for i in 6:
		var a := PI * 0.5 - PI * 0.5 * float(i) / 5.0
		pts.append(centre + Vector2(cos(a), sin(a)) * r)
	var top := _at(Vector2(0.0, TRACK_TOP)).y
	n = maxi(2, int((y - r - top) / step))
	for i in range(1, n + 1):
		pts.append(Vector2(x, lerpf(y - r, top, float(i) / n)))
	Art.track(b, pts, GAUGE * k, false)

## The wooden tray at the foot, two hollows in it.
func _tray(b: Face.Builder, k: float) -> void:
	var at := _at(Vector2(TRAY_IN + TRAY.x, TRAY_UP + TRAY.y))
	var sz := TRAY * k
	var r := sz.y * 0.3
	b.polygon(Face.Builder.round_rect(at + Vector2(0.0, 4.0 * k), sz, r), Art.TRAY_DEEP)
	b.polygon(Face.Builder.round_rect(at, sz, r), Art.TRAY)
	for x: float in [WAIT_IN, GO_AT.x]:
		var hole := Vector2(sz.x * 0.4, sz.y * 0.76)
		var c := Vector2(_at(Vector2(x, 0.0)).x, at.y + sz.y * 0.5)
		b.polygon(Face.Builder.round_rect(c - hole * 0.5, hole, hole.x * 0.3), Art.TRAY_PLACE)

## A block just popped: a soft breath of its colour and a ring of crumbs.
func _puff(b: Face.Builder, at: Vector2, s: float, ink: Color) -> void:
	Scenery.soft_disc(b, at, s * 0.5, s * 0.5, Color(ink.lightened(0.5), 0.5))
	for i in 5:
		var a := TAU * float(i) / 5.0 - 0.4
		b.disc(at + Vector2(cos(a), sin(a)) * s * 0.33, s * (0.07 if i % 2 == 0 else 0.05), Color(ink.lightened(0.25), 0.8))

## The go cannon about `at`, `s` long: the board's cannon in the card's
## colour over its own shadow, a chevron on its carriage up the way it fires.
func _go(b: Face.Builder, at: Vector2, s: float) -> void:
	var k := _k()
	Scenery.soft_disc(b, at + Vector2(0.0, s * 0.2 + GO_LIFT * k), s * 0.5, s * 0.42, Color(Pal.TEXT, GO_SHADOW))
	_put(b, Transform2D(0.0, at), func(p: Face.Builder) -> void: Art.engine(p, s, colour))
	var c := at + Vector2(0.0, s * 0.25)
	var h := s * 0.11
	b.stroke(PackedVector2Array([c + Vector2(-h, h * 0.55), c + Vector2(0.0, -h * 0.55), c + Vector2(h, h * 0.55)]),
		s * 0.075, Pal.SURFACE)

func _lay() -> void:
	var words := _words(String(entry.get("title", "")), SIDE, size.y * 0.5, WORDS, Pal.TEXT, BLURB)
	words.position.y = roundf(WORDS_TOP * size.y / H)
