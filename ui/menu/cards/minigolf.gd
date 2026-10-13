extends "res://ui/menu/cards/card_face.gd"

## Mini Golf's card: the green is the paper, a light felt from edge to edge,
## and the picture is one putt. The cup and its flag stand on the right under
## the seal's corner; a bumper post sits on the straight line to it, so the
## board's dotted aim leaves the ball down to the wooden kerb along the foot
## and banks off it into the cup -- a true mirror about the kerb, worked out
## in code from where the ball and the cup are. The kerb is one bent wall,
## along the foot and up the right side, not a frame; a sand patch lies in
## its elbow.
##
## The go button is the ball: in the card's colour, large, lifted over its
## shadow, a chevron on it along the aim and the board's pull-back mark
## behind it. The name stands top left.
##
## Everything is one mesh, the cup, flag, post and sand
## ui/faces/minigolf_parts.gd's own builders. Nothing lives on the card and
## it writes no string.

const Parts = preload("res://ui/faces/minigolf_parts.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

## The row the card was drawn for (puzzle_card_2d.gd's CARD_H).
const H := 246.0
## Where things stand, as [how far in from the card's right side, how far
## down], at H: the ball, the cup, the post and the sand.
const BALL := Vector2(212.0, 166.0)
const CUP := Vector2(80.0, 138.0)
const POST := Vector2(146.0, 150.0)
const SAND := Vector2(64.0, 193.0)
## The go ball's radius, the plain ball's, the cup's, the post's, the flag's
## height and the sand's half sizes, all at H.
const GO_R := 26.0
const PLAIN_R := 15.0
const CUP_R := 17.0
const POST_R := 11.0
const FLAG := 54.0
const SAND_R := Vector2(21.0, 11.0)
## The kerb: its top face's upper edge along the foot, how thick it is, how
## deep its lip, where it starts and ends in from the right, and how high
## its arm climbs the right side.
const KERB_Y := 216.0
const KERB_W := 12.0
const KERB_LIP := 5.0
const KERB_FROM := 236.0
const KERB_TO := 24.0
const ARM_TOP := 156.0
## The line the ball's middle turns on: the kerb's edge less the board's
## ball.
const BANK_Y := 206.0
## The aim's dots: how far apart, how big at the ball and at the cup.
const DOT_GAP := 11.0
const DOT_R := 3.3
const DOT_END := 2.0
## The go ball's lift and shadow, and how far the pull-back mark reaches.
const GO_LIFT := 4.0
const GO_SHADOW := 0.24
const PULL := 15.0
## The picture's reach from the right side at H: the scale is capped so it
## never starts under the words.
const REACH := 250.0
const WORDS_END := 238.0
## The words' margin, their room and how far down they start.
const SIDE := 22.0
const WORDS := 215.0
const WORDS_TOP := 14.0

## The felt, a mown band's lighter tone, the shade things throw on it, and
## the blurb's ink.
const FELT_TOP := Color("e4f3d5")
const FELT_LOW := Color("cbe7b6")
const MOWN := Color("eef8e2")
const SHADE := Color("5d9a5a")
const BLURB := Color("5c7350")

func _k() -> float:
	return minf(size.y / H, maxf(size.x - WORDS_END, 1.0) / REACH)

## A place given as [in from the right, down] at H, on the card: the picture
## hangs from the right side and stands on the foot.
func _at(p: Vector2) -> Vector2:
	var k := _k()
	return Vector2(size.x - p.x * k, size.y - (H - p.y) * k)

## Where the aim turns on the kerb: the cup mirrored about the bank line.
func _bank() -> Vector2:
	var ball := _at(BALL)
	var cup := _at(CUP)
	var y := _at(Vector2(0.0, BANK_Y)).y
	var mirror := Vector2(cup.x, 2.0 * y - cup.y)
	var t := (y - ball.y) / (mirror.y - ball.y)
	return Vector2(lerpf(ball.x, mirror.x, t), y)

func _paint(b: Face.Builder) -> void:
	var k := _k()
	var first := b.verts.size()
	b.polygon(ground(), Color.WHITE)
	shade(b, first, FELT_TOP, FELT_LOW, 0.0, size.y)
	var ball := _at(BALL)
	var cup := _at(CUP)
	var bank := _bank()
	# The mown light round the cup and round the ball.
	Scenery.soft_disc(b, cup + Vector2(-10.0, 6.0) * k, 92.0 * k, 62.0 * k, Color(MOWN, 0.6))
	Scenery.soft_disc(b, ball, 60.0 * k, 44.0 * k, Color(MOWN, 0.45))
	_sand(b, _at(SAND), k)
	_kerb(b, k)
	Parts.cup(b, cup, CUP_R * k)
	Parts.post(b, _at(POST), POST_R * k)
	_dots(b, ball, bank, cup, k)
	Parts.flag(b, cup, FLAG * k, 0.6)
	if soon:
		Parts.ball(b, ball, PLAIN_R * k)
	else:
		_go(b, ball, (bank - ball).normalized(), k)

## The kerb: one wall along the foot that turns up the right side, a shade
## on the felt, its deep lip and its lit top.
func _kerb(b: Face.Builder, k: float) -> void:
	var a := _at(Vector2(KERB_FROM, KERB_Y))
	var z := _at(Vector2(KERB_TO, KERB_Y + KERB_W))
	var arm := _at(Vector2(KERB_TO + KERB_W, ARM_TOP))
	var r := 4.0 * k
	var run := Rect2(a, z - a)
	var up := Rect2(arm, z - arm)
	for lay: Array in [[Vector2(0.0, KERB_LIP * 1.9 * k), Color(SHADE, 0.3)], [Vector2(0.0, KERB_LIP * k), Pal.GF_KERB_DEEP],
			[Vector2.ZERO, Pal.GF_KERB]]:
		b.polygon(Face.Builder.round_rect(run.position + lay[0], run.size, r), lay[1])
		b.polygon(Face.Builder.round_rect(up.position + lay[0], up.size, r), lay[1])
	var mid := KERB_W * 0.5 * k
	b.stroke(PackedVector2Array([a + Vector2(mid, mid), Vector2(z.x - mid, a.y + mid), Vector2(z.x - mid, arm.y + mid)]),
		2.0 * k, Color(Pal.GF_KERB_HI, 0.9))

## The sand in the kerb's elbow, as the board lays it: a rim, the patch and
## a few grains.
func _sand(b: Face.Builder, at: Vector2, k: float) -> void:
	b.fan(Parts._blob(at, (SAND_R.x + 1.6) * k, (SAND_R.y + 1.6) * k, 3), Pal.GF_SAND_DEEP)
	b.fan(Parts._blob(at, SAND_R.x * k, SAND_R.y * k, 3), Pal.GF_SAND)
	for g: Vector2 in [Vector2(-0.4, 0.1), Vector2(0.2, -0.3), Vector2(0.45, 0.3), Vector2(-0.1, 0.45)]:
		b.disc(at + g * SAND_R * k, 1.2 * k, Pal.GF_SAND_DEEP)

## The board's dotted aim from the ball to the kerb and on to the cup, each
## dot on a faint rim so it reads on the pale felt. None under the go ball,
## none in the cup.
func _dots(b: Face.Builder, ball: Vector2, bank: Vector2, cup: Vector2, k: float) -> void:
	var legs := [ball.distance_to(bank), bank.distance_to(cup)]
	var whole: float = legs[0] + legs[1]
	var d := (GO_R + 9.0) * k
	while d < whole - (CUP_R + 4.0) * k:
		var at := ball.lerp(bank, d / legs[0]) if d <= legs[0] else bank.lerp(cup, (d - legs[0]) / legs[1])
		var u := d / whole
		var r := lerpf(DOT_R, DOT_END, u) * k
		b.disc(at, r + 1.1 * k, Color(SHADE, 0.34))
		b.disc(at, r, Color(Pal.GF_GUIDE, 0.98))
		d += DOT_GAP * k
	# Where it turns, the kerb is touched.
	b.disc(bank + Vector2(0.0, (KERB_Y - BANK_Y) * k), 2.2 * k, Color(Pal.GF_KERB_HI, 0.95))

## The go ball about `at`, aimed along `dir`: the board's pull-back mark
## behind it, its shadow, the ball in the card's colour and a chevron.
func _go(b: Face.Builder, at: Vector2, dir: Vector2, k: float) -> void:
	var r := GO_R * k
	var back := -dir
	var side := Vector2(-back.y, back.x)
	var c := at - Vector2(0.0, GO_LIFT * k)
	var root := c + back * r * 0.9
	var grip := c + back * (r + PULL * k)
	b.fan(PackedVector2Array([root + side * 3.0 * k, grip + side * 5.0 * k, grip - side * 5.0 * k, root - side * 3.0 * k]),
		Color(Pal.SUN, 0.85))
	b.disc(grip, 6.4 * k, Color(Pal.SURFACE, 0.95))
	b.disc(grip, 4.4 * k, Pal.SUN)
	Scenery.soft_disc(b, at + Vector2(r * 0.16, r * 0.62 + GO_LIFT * k), r * 1.12, r * 0.5, Color(SHADE.darkened(0.4), GO_SHADOW))
	b.disc(c + Vector2(0.0, r * 0.1), r, colour.darkened(0.26))
	b.disc(c, r, colour)
	b.ellipse(c + Vector2(-r * 0.34, -r * 0.42), r * 0.28, r * 0.17, Color(Pal.SURFACE, 0.5))
	Parts.arrow(b, c + dir * r * 0.06, dir, r * 0.42, Pal.SURFACE)

func _lay() -> void:
	var words := _words(String(entry.get("title", "")), SIDE, size.y * 0.5, WORDS, Pal.TEXT, BLURB)
	words.position.y = roundf(WORDS_TOP * size.y / H)
