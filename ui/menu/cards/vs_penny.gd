extends "res://ui/menu/cards/card_face.gd"

## Penny Drop's card: a piece of the board's own rack standing on a warm
## butter paper, low on the right -- four columns and three rows of the
## painted face on its wooden foot, the dark inside showing through the
## holes. Our pennies are the card's colour and lie three along the bottom
## row; the rival's suns sit on top of them. The fourth place of our row is
## the one empty hole on the floor, ringed, and the go button is the penny
## that takes it: ours, larger, held over that column with its chevron
## pointing down the drop. The name stands top left.
##
## Everything is one mesh, the rack and the pennies redrawn small from
## versus/penny_board.gd's builders (which are instance methods and bake a
## whole seven by six), and nothing lives on the card.

const Board = preload("res://versus/penny_board.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

## The row the card was drawn for (puzzle_card_2d.gd's CARD_H).
const H := 246.0
## A hole's square at H, the piece of the rack shown, and its room from the
## card's right side and foot.
const CELL := 44.0
const COLS := 4
const ROWS := 3
const RIGHT := 14.0
const FOOT := 9.0
## The words end here: the rack's foot never starts left of it.
const WORDS_END := 244.0
## The pennies in the rack, rows from the top, as the board's cells are:
## "o" ours, "x" the rival's, "." empty. Ours fill the floor but for GO.
const RACK: Array[String] = ["..x.", ".xx.", ".ooo"]
const GO := Vector2i(0, 2)
## The go penny: its radius in cells (a penny in the rack is 0.45), how far
## it hangs over the frame, how far it is lifted, and its shadow.
const GO_R := 0.57
const GO_OVER := 0.12
const GO_LIFT := 0.07
const GO_SHADOW := 0.22
## The words' margin, their room and how far down they start.
const SIDE := 22.0
const WORDS := 215.0
const WORDS_TOP := 14.0

## The butter paper, a pale pool behind the rack, and the blurb's ink.
const PAPER_TOP := Color("fdf6df")
const PAPER_LOW := Color("f8e7bb")
const POOL := Color("fffaea")
const BLURB := Color("7d6a45")

## The card's height sets the scale; the words cap it.
func _k() -> float:
	var wide := RIGHT + CELL * (float(COLS) + 2.0 * _out())
	return minf(size.y / H, (size.x - WORDS_END) / wide)

## How far the foot stands out past the holes on each side, in cells.
static func _out() -> float:
	return (Board.FRAME + Board.FOOT_OUT) / Board.U

func _cell() -> float:
	return CELL * _k()

## The top left corner of the holes.
func _origin() -> Vector2:
	var u := _cell()
	var under := (Board.FRAME * 0.5 + Board.FOOT_H + 5.0) / Board.U
	return Vector2(size.x - RIGHT * _k() - u * (float(COLS) + _out()), size.y - FOOT * _k() - u * (float(ROWS) + under))

func _mid(cell: Vector2i) -> Vector2:
	return _origin() + (Vector2(cell) + Vector2.ONE * 0.5) * _cell()

## Where the go penny hangs: over its column, clear of the frame's top.
func _go_at() -> Vector2:
	var u := _cell()
	var top := _origin().y - u * Board.FRAME / Board.U
	return Vector2(_mid(GO).x, top - u * (GO_OVER + GO_R))

## Whether the picture is a true one: every penny rests on the floor or on
## another, and GO is the lowest empty place of its column.
static func _stands() -> bool:
	for x in COLS:
		var seen := false
		for y in ROWS:
			var full := RACK[y][x] != "."
			if seen and not full:
				return false
			seen = seen or full
	var go := GO
	return RACK[go.y][go.x] == "." and (go.y == ROWS - 1 or RACK[go.y + 1][go.x] != ".")

func _paint(b: Face.Builder) -> void:
	var u := _cell()
	var s := u / Board.U
	var o := _origin()
	var grid := Vector2(COLS, ROWS) * u
	var first := b.verts.size()
	b.polygon(ground(), Color.WHITE)
	shade(b, first, PAPER_TOP, PAPER_LOW, 0.0, size.y)
	var pool := o + grid * Vector2(0.5, 0.42)
	Scenery.soft_disc(b, pool, minf(grid.x * 0.74, size.x - pool.x - 4.0), minf(grid.y * 0.8, pool.y - 4.0), Color(POOL, 0.6))
	# The foot and the dark inside, as the board's back.
	var foot_at := o + Vector2(-(Board.FRAME + Board.FOOT_OUT), ROWS * Board.U + Board.FRAME * 0.5) * s
	var foot := Vector2(COLS * Board.U + 2.0 * (Board.FRAME + Board.FOOT_OUT), Board.FOOT_H) * s
	b.fan(Face.Builder.round_rect(foot_at + Vector2(0.0, 5.0 * s), foot, 14.0 * s), Board.WOOD_DEEP)
	b.fan(Face.Builder.round_rect(foot_at, foot - Vector2(0.0, 5.0 * s), 14.0 * s), Board.WOOD)
	b.stroke(PackedVector2Array([foot_at + Vector2(18.0, 8.0) * s, foot_at + Vector2(foot.x - 18.0 * s, 8.0 * s)]), 5.0 * s,
		Color(Board.WOOD_LIT, 0.8))
	b.fan(Face.Builder.round_rect(o - Vector2.ONE * 4.0 * s, grid + Vector2.ONE * 8.0 * s, 10.0 * s), Board.INSIDE)
	# The pennies lie behind the painted face.
	var true_one := _stands()
	for y in ROWS:
		for x in COLS:
			var mark := RACK[y][x]
			if mark == "o":
				_penny(b, _mid(Vector2i(x, y)), u * Board.PENNY_R / Board.U, true)
			elif mark == "x":
				_penny(b, _mid(Vector2i(x, y)), u * Board.PENNY_R / Board.U, false)
	_front(b, o, s)
	if soon:
		# Not open yet: a plain penny of ours waits over the column.
		var r := u * Board.PENNY_R / Board.U
		_penny(b, Vector2(_mid(GO).x, o.y - u * Board.FRAME / Board.U - u * GO_OVER - r), r, true)
		return
	if true_one:
		var home := _mid(GO)
		Scenery.soft_disc(b, home, u * 0.4, u * 0.4, Color(Pal.SUN, 0.3))
		b.stroke(Face.Builder.ring(home, u * 0.3, u * 0.3), u * 0.07, Color(Pal.SUN, 0.95), true)
	_go(b, _go_at(), u)

## The painted face over `COLS` by `ROWS` holes from `o`: a square a hole
## with the hole cut through it, the frame, and each hole's rim and shade.
func _front(b: Face.Builder, o: Vector2, s: float) -> void:
	var n := 28
	var grid := Vector2(COLS, ROWS) * Board.U * s
	for y in ROWS:
		for x in COLS:
			var centre := _mid(Vector2i(x, y))
			for i in n:
				var d0 := Vector2.from_angle(TAU * i / n)
				var d1 := Vector2.from_angle(TAU * (i + 1) / n)
				var v0 := b.vertex(centre + d0 * Board.HOLE_R * s, Board.PAINT)
				var v1 := b.vertex(centre + d1 * Board.HOLE_R * s, Board.PAINT)
				var v2 := b.vertex(centre + d1 * (Board.U * s * 0.5 / maxf(absf(d1.x), absf(d1.y))), Board.PAINT)
				var v3 := b.vertex(centre + d0 * (Board.U * s * 0.5 / maxf(absf(d0.x), absf(d0.y))), Board.PAINT)
				b.tri(v0, v1, v2)
				b.tri(v0, v2, v3)
	var half := Board.FRAME * 0.5 * s
	var wide := (Board.FRAME + 2.0) * s
	b.stroke(Face.Builder.round_rect(o + Vector2(-half, -half + 4.0 * s), grid + Vector2(2.0 * half, 2.0 * half), 26.0 * s), wide,
		Board.PAINT_DEEP, true)
	b.stroke(Face.Builder.round_rect(o + Vector2(-half, -half), grid + Vector2(2.0 * half, 2.0 * half - 4.0 * s), 26.0 * s), wide,
		Board.PAINT_LIT, true)
	b.stroke(PackedVector2Array([o + Vector2(8.0, -Board.FRAME + 9.0) * s, o + Vector2(grid.x - 8.0 * s, (-Board.FRAME + 9.0) * s)]),
		5.0 * s, Color(1, 1, 1, 0.28))
	for y in ROWS:
		for x in COLS:
			var centre := _mid(Vector2i(x, y))
			b.stroke(Face.Builder.ring(centre, (Board.HOLE_R + 1.0) * s, (Board.HOLE_R + 1.0) * s), 5.0 * s, Board.PAINT_DEEP, true)
			b.stroke(Face.Builder.arc_points(centre, (Board.HOLE_R + 4.5) * s, PI * 0.15, PI * 0.85), 3.0 * s, Color(1, 1, 1, 0.22))
			b.stroke(Face.Builder.arc_points(centre, (Board.HOLE_R - 4.0) * s, PI * 1.1, PI * 1.9), 7.0 * s, Color(0.05, 0.12, 0.12, 0.22))

## One penny of radius `r` about `at`, as the board stamps them: the
## rival's a gold sun with its rays, ours a crescent in the card's colour.
func _penny(b: Face.Builder, at: Vector2, r: float, ours: bool, stamped := true) -> void:
	var s := r / Board.PENNY_R
	var rim: Color = colour.darkened(0.3) if ours else Board.RIM[0]
	var coin: Color = colour if ours else Board.COIN[0]
	var shine: Color = colour.lightened(0.45) if ours else Board.SHINE[0]
	var stamp: Color = colour.darkened(0.2) if ours else Board.STAMP[0]
	b.disc(at + Vector2(0.0, 2.0 * s), r, rim.darkened(0.25))
	b.disc(at, r - 1.0 * s, rim)
	b.disc(at + Vector2(0.0, -1.5 * s), r - 6.0 * s, coin)
	b.stroke(Face.Builder.ring(at, r - 12.0 * s, r - 12.0 * s), 2.5 * s, Color(stamp, 0.7), true)
	b.stroke(Face.Builder.arc_points(at, r - 8.5 * s, PI * 1.08, PI * 1.55), 4.0 * s, Color(shine, 0.9))
	if not stamped:
		return
	if ours:
		var pts := Face.Builder.arc_points(at + Vector2(-2.0, 0.0) * s, 19.0 * s, PI * 0.32, PI * 1.68)
		pts.append_array(Face.Builder.arc_points(at + Vector2(7.0, 0.0) * s, 15.5 * s, PI * 1.5, PI * 0.5))
		b.polygon(pts, stamp)
	else:
		b.disc(at, 11.0 * s, stamp)
		for i in 8:
			var d := Vector2.from_angle(TAU * i / 8.0)
			b.stroke(PackedVector2Array([at + d * 16.5 * s, at + d * 23.0 * s]), 5.0 * s, stamp)

## The go penny about `at`: ours, larger, lifted over its shadow, a chevron
## down the drop where the others carry their stamp.
func _go(b: Face.Builder, at: Vector2, u: float) -> void:
	var r := u * GO_R
	Scenery.soft_disc(b, at + Vector2(0.0, r * 0.98), r * 0.8, r * 0.2, Color(Pal.TEXT, GO_SHADOW))
	var up := at - Vector2(0.0, u * GO_LIFT)
	_penny(b, up, r, true, false)
	var h := r * 0.3
	b.stroke(PackedVector2Array([up + Vector2(-h, -h * 0.45), up + Vector2(0.0, h * 0.65), up + Vector2(h, -h * 0.45)]), r * 0.2,
		Pal.SURFACE)

func _lay() -> void:
	var words := _words(String(entry.get("title", "")), SIDE, size.y * 0.5, WORDS, Pal.TEXT, BLURB)
	words.position.y = roundf(WORDS_TOP * size.y / H)
