extends "res://ui/menu/cards/card_face.gd"

## Reversi's card: one capture on a pale mint felt, and no board. A single
## row of the board's own blue cells lies free across the lower right, round
## at its ends: our sun disc at the left, three of the rival's moons in a
## run -- the middle one caught on its edge, half turned -- and the empty
## cell at the right ringed in the board's hint gold. A shorter row stands
## over it, half a cell off, with a moon and a sun for depth.
##
## The go button is the disc that closes the run: ours, so it wears the sun
## disc's cream rim, but its face is the card's colour and its stamp the
## chevron, pointing down at the ringed cell it hovers over.
##
## Everything is one mesh; the discs are versus/reversi_board.gd's own
## (`_build_disc`), redrawn at the card's size since that builder is an
## instance method of the board. Nothing lives on the card.

const Board = preload("res://versus/reversi_board.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

## The row the card was drawn for (puzzle_card_2d.gd's CARD_H).
const H := 246.0
## A cell at H, the strip's room from the card's right side and foot, and
## where the words end: the strip never starts left of it.
const CELL := 46.0
const RIGHT := 14.0
const FOOT := 16.0
const WORDS_END := 244.0
## The row: 0 ours, 1 the rival's, 2 the rival's disc mid-flip, -1 empty.
const ROW := [0, 1, 2, 1, -1]
## The shorter row above: its first cell's place in cells from the strip's
## left, how far it stands over the strip, and its discs.
const UPPER_AT := 0.5
const UPPER_GAP := 5.0
const UPPER := [1, 0]
## A disc's radius in cells (the board's is 0.4), the strip's frame and
## corner, and a cell's inset.
const DISC := 0.4
const FRAME := 0.07
const ROUND := 0.2
const INSET := 0.035
## The go disc: its radius at H, how far over the ringed cell it hovers,
## and its shadow.
const GO_R := 28.0
const GO_LIFT := 0.78
const GO_SHADOW := 0.22
## The words' margin, their room and how far down they start.
const SIDE := 22.0
const WORDS := 215.0
const WORDS_TOP := 14.0

## The felt, a pale pool under the strip, and the blurb's ink.
const FELT_TOP := Color("e6f4f0")
const FELT_LOW := Color("cfe8e1")
const POOL := Color("f3faf7")
const BLURB := Color("58736c")

func _k() -> float:
	return size.y / H

## One cell: the card's height sets it, the words cap it.
func _cell() -> float:
	return minf(CELL * _k(), (size.x - RIGHT * _k() - WORDS_END) / float(ROW.size()))

## The strip's top left corner.
func _origin() -> Vector2:
	var s := _cell()
	return Vector2(size.x - RIGHT * _k() - ROW.size() * s, size.y - FOOT * _k() - s)

func _mid(i: int) -> Vector2:
	return _origin() + Vector2(i + 0.5, 0.5) * _cell()

func _paint(b: Face.Builder) -> void:
	var s := _cell()
	var o := _origin()
	var first := b.verts.size()
	b.polygon(ground(), Color.WHITE)
	shade(b, first, FELT_TOP, FELT_LOW, 0.0, size.y)
	Scenery.soft_disc(b, o + Vector2(ROW.size() * 0.5 - 0.2, -0.25) * s, s * 2.3, s * 0.95, Color(POOL, 0.6))
	var up := o + Vector2(UPPER_AT * s, -s - UPPER_GAP * _k())
	_strip(b, up, UPPER.size(), s)
	_strip(b, o, ROW.size(), s)
	for i in UPPER.size():
		_disc(b, up + Vector2(i + 0.5, 0.5) * s, s * DISC, int(UPPER[i]))
	var home := -1
	for i in ROW.size():
		match int(ROW[i]):
			-1:
				home = i
			2:
				_flipping(b, _mid(i), s * DISC)
			_:
				_disc(b, _mid(i), s * DISC, int(ROW[i]))
	if home < 0:
		return
	var at := _mid(home)
	if soon:
		# Not open yet: the cell only wears the board's dot for a square
		# that may be played.
		b.disc(at, s * 0.09, Color(Board.HINT, 0.9))
		return
	b.stroke(Face.Builder.ring(at, s * DISC, s * DISC), s * 0.07, Color(Board.HINT, 0.95), true)
	_go(b, at - Vector2(0.0, s * GO_LIFT), at, minf(GO_R * _k(), s * 0.62))

## `n` of the board's cells in a row from `o`: the dark line as its frame,
## round at the ends, and each cell lit as the board's lighter squares are.
func _strip(b: Face.Builder, o: Vector2, n: int, s: float) -> void:
	var f := s * FRAME
	b.fan(Face.Builder.round_rect(o - Vector2(f, f) + Vector2(0.0, s * 0.06), Vector2(n * s + 2.0 * f, s + 2.0 * f), s * (ROUND + FRAME)),
		Board.LINE.darkened(0.18))
	b.fan(Face.Builder.round_rect(o - Vector2(f, f), Vector2(n * s + 2.0 * f, s + 2.0 * f), s * (ROUND + FRAME)), Board.LINE)
	for i in n:
		var lit := i % 2 == 0
		b.fan(Face.Builder.round_rect(o + Vector2(i + INSET, INSET) * s, Vector2.ONE * s * (1.0 - 2.0 * INSET), s * ROUND * 0.8),
			Board.FIELD_LIT if lit else Board.FIELD)

## One of the board's discs about `at`: its shadow, the edge showing the
## face underneath, the face, a raised ring, and the side's stamp -- a sun
## with its rays, or a crescent.
func _disc(b: Face.Builder, at: Vector2, r: float, look: int) -> void:
	var u := r / Board.DISC_R
	b.disc(at + Vector2(0.0, 8.0) * u, r + u, Color(0.05, 0.1, 0.2, 0.28))
	b.disc(at + Vector2(0.0, 4.5) * u, r, (Board.DISC[1 - look] as Color).darkened(0.12))
	b.disc(at, r, Board.RING[look])
	b.disc(at + Vector2(0.0, -1.0) * u, r - 4.0 * u, Board.DISC[look])
	b.stroke(Face.Builder.ring(at, r - 10.0 * u, r - 10.0 * u), 2.5 * u, Color(Board.RING[look], 0.9), true)
	if look == 0:
		b.disc(at, 9.5 * u, Board.STAMP[look])
		for k in 8:
			var d := Vector2.from_angle(TAU * k / 8.0)
			b.stroke(PackedVector2Array([at + d * 14.5 * u, at + d * 20.5 * u]), 4.5 * u, Board.STAMP[look])
	else:
		var pts := Face.Builder.arc_points(at + Vector2(-2.0, 0.0) * u, 17.0 * u, PI * 0.32, PI * 1.68)
		pts.append_array(Face.Builder.arc_points(at + Vector2(6.0, 0.0) * u, 14.0 * u, PI * 1.5, PI * 0.5))
		b.polygon(pts, Board.STAMP[look])

## The rival's disc half turned: seen on its edge, a narrow ellipse still
## the moon's navy on one side and already the sun's cream on the other,
## lifted a little off its cell.
func _flipping(b: Face.Builder, at: Vector2, r: float) -> void:
	var u := r / Board.DISC_R
	var c := at - Vector2(0.0, 7.0 * u)
	b.polygon(Face.Builder.ring(at + Vector2(0.0, 12.0 * u), r * 0.62, r * 0.3), Color(0.05, 0.1, 0.2, 0.22))
	var rx := r * 0.3
	b.polygon(Face.Builder.ring(c + Vector2(-3.5 * u, 0.0), rx, r), Board.DISC[1])
	b.polygon(Face.Builder.ring(c + Vector2(3.5 * u, 0.0), rx, r), Board.RING[0])
	b.polygon(Face.Builder.ring(c + Vector2(5.0 * u, 0.0), rx * 0.82, r - 4.0 * u), Board.DISC[0])

## The go disc about `at`, over the cell at `home`: ours, so the sun disc's
## cream rim, with the card's colour for its face and a chevron for its
## stamp, pointing down at the cell.
func _go(b: Face.Builder, at: Vector2, home: Vector2, r: float) -> void:
	Scenery.soft_disc(b, home + Vector2(0.0, r * 0.2), r * 0.95, r * 0.42, Color(Pal.TEXT, GO_SHADOW))
	b.disc(at + Vector2(0.0, r * 0.14), r, colour.darkened(0.3))
	b.disc(at, r, Board.RING[0])
	b.disc(at - Vector2(0.0, r * 0.03), r * 0.86, colour)
	b.stroke(Face.Builder.arc_points(at, r * 0.72, PI * 1.08, PI * 1.5), r * 0.08, Color(Pal.SURFACE, 0.3))
	var h := r * 0.34
	b.stroke(PackedVector2Array([at + Vector2(-h, -h * 0.5), at + Vector2(0.0, h * 0.55), at + Vector2(h, -h * 0.5)]),
		r * 0.2, Pal.SURFACE)

func _lay() -> void:
	var words := _words(String(entry.get("title", "")), SIDE, size.y * 0.5, WORDS, Pal.TEXT, BLURB)
	words.position.y = roundf(WORDS_TOP * _k())
