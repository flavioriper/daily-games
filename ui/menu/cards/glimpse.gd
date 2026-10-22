extends "res://ui/menu/cards/pixelgarden.gd"

## Glimpse's card: Pixel Garden's card (the mat, the tray, the go bead and
## its hop) with Glimpse's things on it. The board holds a little mirrored
## bug half beaded from memory, its last peg lit; where Pixel Garden's iron
## lies, the pattern card lies face down under its cover -- the eye and the
## pips of the looks (puzzles/glimpse2d.gd's own cover) -- tilted on the
## mat. The mat is a cool blue, the memory skill's.

const Glimpse = preload("res://puzzles/glimpse2d.gd")

## The bug, a row a string: B its back, Y its spots, `.` a bare peg, `o` a
## peg it wants and has not got yet.
const BUG: Array[String] = [
	".B...B.",
	"..B.B..",
	".BBBBB.",
	"BBYBYBB",
	".BBBBB.",
	".BYoYB.",
	"B..B..B",
]
const BUG_HOME := Vector2i(3, 5)
## The covered card: its middle from the card's left and foot at H, its
## side and its tilt.
const COVER_AT := Vector2(84.0, 56.0)
const COVER := 70.0
const COVER_TURN := -0.18

const GL_MAT_TOP := Color("e8f2fa")
const GL_MAT_LOW := Color("d2e6f3")

func _paint(b: Face.Builder) -> void:
	var k := _k()
	var s := CELL * k
	var first := b.verts.size()
	b.polygon(ground(), Color.WHITE)
	shade(b, first, GL_MAT_TOP, GL_MAT_LOW, 0.0, size.y)
	_grid(b, k)
	var o := _tray()
	var side := _side()
	Scenery.soft_disc(b, o + Vector2(side * 0.46, side * 0.975), side * 0.5, side * 0.05, Color(Pal.TEXT, 0.2))
	b.fan(Face.Builder.round_rect(o + Vector2(0.0, 3.0 * k), Vector2.ONE * side, 12.0 * k), Pal.PG_TRAY_DEEP)
	b.fan(Face.Builder.round_rect(o, Vector2.ONE * side, 12.0 * k), Pal.PG_TRAY)
	b.fan(Face.Builder.round_rect(o + Vector2.ONE * 1.5 * k, Vector2(side - 3.0 * k, 3.0 * k), 1.5 * k),
		Color(Pal.PG_TRAY_HI, 0.8))
	var inner := o + Vector2.ONE * RIM * k
	var face := side - RIM * 2.0 * k
	b.fan(Face.Builder.round_rect(inner, Vector2.ONE * face, 8.0 * k), Pal.PG_BOARD_DEEP)
	b.fan(Face.Builder.round_rect(inner + Vector2(0.0, 1.5 * k), Vector2(face, face - 1.5 * k), 8.0 * k), Pal.PG_BOARD)
	for y in N:
		for x in N:
			var cell := Vector2i(x, y)
			if BUG[y][x] in ".o" or cell == BUG_HOME:
				Bead.peg(b, _peg(cell), s)
	var home := _peg(BUG_HOME)
	if not soon:
		Scenery.soft_disc(b, home, s * 0.78, s * 0.78, Color(Pal.SUN, 0.5))
		b.stroke(Face.Builder.ring(home, s * 0.5, s * 0.5), s * 0.09, Color(Pal.SUN, 0.95), true)
		Bead.peg(b, home, s, 1.0, 1.0)
	for y in N:
		for x in N:
			var cell := Vector2i(x, y)
			if cell == BUG_HOME:
				continue
			match BUG[y][x]:
				"B":
					Bead.bead(b, _peg(cell), s, Pal.PG_BEADS["blue"])
				"Y":
					Bead.bead(b, _peg(cell), s, Pal.PG_BEADS["yellow"])
	# The pattern card face down on the mat, its cover drawn about its own
	# corner and turned into place.
	var c := Vector2(COVER_AT.x * k, size.y - COVER_AT.y * k)
	var side_c := COVER * k
	Scenery.soft_disc(b, c + Vector2(0.0, side_c * 0.5), side_c * 0.55, side_c * 0.1, Color(Pal.TEXT, 0.18))
	var card := Face.Builder.new()
	var r := Rect2(Vector2.ONE * -side_c * 0.5, Vector2.ONE * side_c)
	card.fan(Face.Builder.round_rect(r.position + Vector2(0.0, 3.0 * k), r.size, 10.0 * k), Pal.PG_TRAY_DEEP)
	card.fan(Face.Builder.round_rect(r.position, r.size, 10.0 * k), Pal.PG_TRAY)
	Glimpse.cover(card, r, 2, 3)
	b.append(card.mesh(), Transform2D(COVER_TURN, c))
	if not soon:
		_go(b, _go_at(), s, home)
