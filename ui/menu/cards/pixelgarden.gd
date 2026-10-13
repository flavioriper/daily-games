extends "res://ui/menu/cards/card_face.gd"

## Pixel Garden's card: a pale aqua craft mat and the board whole on it, a
## small square pegboard in its wooden tray standing low on the right. A
## tulip is half made on it in the board's own beads: the rose cup is all
## but done, the leaves are in, and the peg between them -- the top of the
## stem -- is still bare and lit. So the bead it wants is a green one.
##
## The go button is that bead: one of the board's beads in the card's
## colour, drawn large and lifted over its shadow on the mat beside the
## tray, a chevron across its hole, with a dotted hop from it to the lit
## peg. Three loose beads lie on the mat and the board's iron waits bottom
## left. The name stands top left.
##
## Everything is one mesh, the beads and pegs ui/faces/bead.gd's own
## builders and the iron ui/faces/iron.gd's. Nothing lives on the card and
## it writes no string.

const Bead = preload("res://ui/faces/bead.gd")
const Iron = preload("res://ui/faces/iron.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

## The row the card was drawn for (puzzle_card_2d.gd's CARD_H).
const H := 246.0
## A peg's cell at H, the pegs a side, the board's margin round them and the
## tray's rim round that, and the tray's room from the card's right and foot.
const CELL := 20.6
const N := 7
const PAD := 5.0
const RIM := 5.0
const RIGHT := 16.0
const FOOT := 10.0
## The picture, a row a string: R a petal, G a leaf or the stem, `.` a peg
## the picture leaves bare. `o` is a peg it wants and has not got yet.
const PICTURE: Array[String] = [
	".R.R.o.",
	".RRRRR.",
	".RRRRR.",
	"..RRR..",
	".......",
	".G.G.o.",
	"..GGG..",
]
## The peg the go bead is for: the top of the stem.
const HOME := Vector2i(3, 4)
## The go bead: its size in beads, where its middle stands from the tray's
## left side and the card's foot at H, how far it is lifted, its shadow.
const GO_SIZE := 2.5
const GO_AT := Vector2(46.0, 52.0)
const GO_LIFT := 5.0
const GO_SHADOW := 0.24
## The loose beads on the mat, as [in from the tray's left, up from the
## foot, PG_BEADS key], at H.
const LOOSE := [[92.0, 22.0, "rose"], [118.0, 30.0, "yellow"], [16.0, 20.0, "pink"]]
## The iron: where it stands from the card's left and foot at H, its length
## and the way it points.
const IRON_AT := Vector2(92.0, 44.0)
const IRON := 56.0
const IRON_TURN := -0.3
## The words' margin, their room and how far down they start.
const SIDE := 22.0
const WORDS := 215.0
const WORDS_TOP := 14.0

## The mat, top to foot, the faint cutting grid on it, and the blurb's ink.
const MAT_TOP := Color("e6f5f2")
const MAT_LOW := Color("cfe9e5")
const MAT_GRID := Color("b7dcd7")
const BLURB := Color("587371")

func _k() -> float:
	return size.y / H

## The tray's side, rim to rim.
func _side() -> float:
	return (CELL * N + (PAD + RIM) * 2.0) * _k()

## The tray's top left corner.
func _tray() -> Vector2:
	var k := _k()
	return Vector2(size.x - RIGHT * k - _side(), size.y - FOOT * k - _side())

## The middle of the peg at `cell`.
func _peg(cell: Vector2i) -> Vector2:
	var k := _k()
	return _tray() + Vector2.ONE * (RIM + PAD) * k + (Vector2(cell) + Vector2.ONE * 0.5) * CELL * k

func _go_at() -> Vector2:
	var k := _k()
	return Vector2(_tray().x - GO_AT.x * k, size.y - GO_AT.y * k)

func _paint(b: Face.Builder) -> void:
	var k := _k()
	var s := CELL * k
	var first := b.verts.size()
	b.polygon(ground(), Color.WHITE)
	shade(b, first, MAT_TOP, MAT_LOW, 0.0, size.y)
	_grid(b, k)
	var o := _tray()
	var side := _side()
	# The tray: its shade on the mat, the wood, the board's bevel and face.
	Scenery.soft_disc(b, o + Vector2(side * 0.46, side * 0.975), side * 0.5, side * 0.05, Color(Pal.TEXT, 0.2))
	b.fan(Face.Builder.round_rect(o + Vector2(0.0, 3.0 * k), Vector2.ONE * side, 12.0 * k), Pal.PG_TRAY_DEEP)
	b.fan(Face.Builder.round_rect(o, Vector2.ONE * side, 12.0 * k), Pal.PG_TRAY)
	b.fan(Face.Builder.round_rect(o + Vector2.ONE * 1.5 * k, Vector2(side - 3.0 * k, 3.0 * k), 1.5 * k),
		Color(Pal.PG_TRAY_HI, 0.8))
	var inner := o + Vector2.ONE * RIM * k
	var face := side - RIM * 2.0 * k
	b.fan(Face.Builder.round_rect(inner, Vector2.ONE * face, 8.0 * k), Pal.PG_BOARD_DEEP)
	b.fan(Face.Builder.round_rect(inner + Vector2(0.0, 1.5 * k), Vector2(face, face - 1.5 * k), 8.0 * k), Pal.PG_BOARD)
	# The pegs first, then the beads over them, as the board bakes them.
	for y in N:
		for x in N:
			var cell := Vector2i(x, y)
			if PICTURE[y][x] in ".o" or cell == HOME:
				Bead.peg(b, _peg(cell), s)
	var home := _peg(HOME)
	if not soon:
		Scenery.soft_disc(b, home, s * 0.78, s * 0.78, Color(Pal.SUN, 0.5))
		b.stroke(Face.Builder.ring(home, s * 0.5, s * 0.5), s * 0.09, Color(Pal.SUN, 0.95), true)
		Bead.peg(b, home, s, 1.0, 1.0)
	for y in N:
		for x in N:
			var cell := Vector2i(x, y)
			if cell == HOME:
				continue
			match PICTURE[y][x]:
				"R":
					Bead.bead(b, _peg(cell), s, Pal.PG_BEADS["rose"])
				"G":
					Bead.bead(b, _peg(cell), s, Pal.PG_BEADS["green"])
	# What lies on the mat.
	for l: Array in LOOSE:
		var at := Vector2(o.x - float(l[0]) * k, size.y - float(l[1]) * k)
		Bead.bead(b, at, s, Pal.PG_BEADS[String(l[2])], Vector2.ONE, 1.0, 0.0, 0.0, 0.0, MAT_LOW, false)
	Iron.iron(b, Vector2(IRON_AT.x * k, size.y - IRON_AT.y * k), IRON * k, IRON_TURN)
	if not soon:
		_go(b, _go_at(), s, home)

## The mat's cutting grid: a few faint lines under the words' side, kept
## inside the paper.
func _grid(b: Face.Builder, k: float) -> void:
	var step := 41.0 * k
	var x := maxf(step * 0.75, RADIUS + 2.0)
	while x < size.x - RADIUS - 2.0:
		b.stroke(PackedVector2Array([Vector2(x, EDGE + 1.0), Vector2(x, size.y - EDGE - 1.0)]), 1.2,
			Color(MAT_GRID, 0.45), false, false)
		x += step
	var y := RADIUS + 2.0
	while y < size.y - RADIUS - 2.0:
		b.stroke(PackedVector2Array([Vector2(EDGE + 1.0, y), Vector2(size.x - EDGE - 1.0, y)]), 1.2,
			Color(MAT_GRID, 0.45), false, false)
		y += step

## The go bead about `at`: a bead of the board's make in the card's colour,
## large, lifted over its own shadow, a chevron across its hole, and the
## dotted hop to the peg it is for.
func _go(b: Face.Builder, at: Vector2, s: float, home: Vector2) -> void:
	var big := s * GO_SIZE
	var r := big * Bead.R
	var lift := GO_LIFT * _k()
	# The hop: dots from the bead's rim toward the lit peg.
	var way := home - at
	var reach := way.length()
	var dir := way / reach
	var d := r + s * 0.5
	while d < reach - s * 0.75:
		b.disc(at + dir * d - Vector2(0.0, lift * (1.0 - d / reach)), s * 0.11, Color(colour.darkened(0.1), 0.75))
		d += s * 0.5
	Scenery.soft_disc(b, at + Vector2(0.0, r * 0.62 + lift), r * 1.05, r * 0.36, Color(Pal.TEXT, GO_SHADOW))
	Bead.bead(b, at - Vector2(0.0, lift), big, colour, Vector2.ONE, 1.0, 0.0, 0.0, 0.0, MAT_LOW, false)
	var c := at - Vector2(0.0, lift - r * 0.02)
	var h := r * 0.36
	b.stroke(PackedVector2Array([c + Vector2(-h * 0.55, -h), c + Vector2(h * 0.55, 0.0), c + Vector2(-h * 0.55, h)]),
		r * 0.22, Pal.SURFACE)

func _lay() -> void:
	var words := _words(String(entry.get("title", "")), SIDE, size.y * 0.5, WORDS, Pal.TEXT, BLURB)
	words.position.y = roundf(WORDS_TOP * _k())
