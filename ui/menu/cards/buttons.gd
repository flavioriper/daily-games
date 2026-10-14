extends "res://ui/menu/cards/card_face.gd"

## Button Box's card: a warm linen with one hem of running stitch, and a
## small cloth picture low on the right inside its stitched border: a
## toadstool, its cap in the card's colour, nearly all sewn -- a sewn button
## is its whole square in the colour, as the board draws it. Three things
## are not done, and they hang together as the board's rules have them: a
## tan button sits loose on the cap's yellow spot, so the stem's foot, the
## patch it belongs on, lies bare; the yellow button that spot wants waits
## in the tin; and one patch of the cap is bare and lit.
##
## The go button is the button that patch wants: one of the board's buttons
## in the card's colour, drawn large and lifted over its shadow between the
## words and the tin, a chevron where its holes would be, with a dotted hop
## to the lit patch. The tin is the board's wooden tray, three places worn
## smooth, along the foot. The name stands top left.
##
## Everything is one mesh, the patches, buttons and tin
## ui/faces/button_art.gd's own builders. Nothing lives on the card and it
## writes no string.

const Art = preload("res://ui/faces/button_art.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

## The row and the width the card was drawn for.
const H := 246.0
const W := 490.0
## A square of the picture at H, and the picture's room from the card's
## right side and foot.
const CELL := 31.0
const RIGHT := 18.0
const FOOT := 12.0
## The picture, a row a string: C the cap, S the stem, Y the cap's spot,
## `.` bare linen.
const PICTURE: Array[String] = [
	".CCC.",
	"CCYCC",
	"CCCCC",
	".SSS.",
	"..S..",
]
## The bare patch the go button is for, the bare patch the loose button
## left, and where that loose button sits instead.
const HOME := Vector2i(1, 2)
const BARE := Vector2i(2, 4)
const LOOSE := Vector2i(2, 1)
const STEM := "tan"
const SPOT := "yellow"
## The border's room round the picture and its stitch, at H.
const BORDER := 5.0
const STITCH := 13.0
## The tin: its places, a place's step, its rim, the gap to the picture and
## how far it stands off the foot, at H.
const TIN_PLACES := 3
const TIN_STEP := 35.0
const TIN_RIM := 7.0
const TIN_GAP := 16.0
const TIN_FOOT := 12.0
## The go button: how wide it is across at H, where its middle stands from
## the picture's left side and the card's foot, its lift and its shadow.
const GO_ACROSS := 54.0
const GO_AT := Vector2(46.0, 92.0)
const GO_LIFT := 5.0
const GO_SHADOW := 0.24
## The hem: how far off the foot it runs, and a dash's step, at H.
const HEM := 22.0
const HEM_STEP := 15.0
## The words' margin, their room and how far down they start.
const SIDE := 22.0
const WORDS := 215.0
const WORDS_TOP := 14.0

## The linen, top to foot, its stitches' thread, and the blurb's ink.
const LINEN_TOP := Color("fbf4e7")
const LINEN_LOW := Color("f1e3cd")
const HEM_INK := Color("d2bb97")
const BLURB := Color("7b6a54")

## The card's height sets the scale and its width caps it.
func _k() -> float:
	return minf(size.y / H, size.x / W)

func _cols() -> int:
	return PICTURE[0].length()

## The picture's top left corner.
func _origin() -> Vector2:
	var k := _k()
	return Vector2(size.x - (RIGHT + _cols() * CELL) * k, size.y - (FOOT + PICTURE.size() * CELL) * k)

func _mid(cell: Vector2i) -> Vector2:
	return _origin() + (Vector2(cell) + Vector2.ONE * 0.5) * CELL * _k()

func _colour_at(cell: Vector2i) -> Color:
	match PICTURE[cell.y][cell.x]:
		"S":
			return Art.colour(STEM)
		"Y":
			return Art.colour(SPOT)
	return colour

func _tin_rect() -> Rect2:
	var k := _k()
	var sz := Vector2(TIN_PLACES * TIN_STEP + TIN_RIM * 2.0, TIN_STEP + TIN_RIM * 2.0) * k
	return Rect2(Vector2(_origin().x - TIN_GAP * k - sz.x, size.y - TIN_FOOT * k - sz.y), sz)

func _go_at() -> Vector2:
	var k := _k()
	return Vector2(_origin().x - GO_AT.x * k, size.y - GO_AT.y * k)

func _paint(b: Face.Builder) -> void:
	var k := _k()
	var s := CELL * k
	var first := b.verts.size()
	b.polygon(ground(), Color.WHITE)
	shade(b, first, LINEN_TOP, LINEN_LOW, 0.0, size.y)
	var o := _origin()
	var tin := _tin_rect()
	_hem(b, k, tin.position.x - 14.0 * k)
	# The picture's stitched border, as the board lays it round its field.
	var field := Rect2(o - Vector2.ONE * BORDER * k, Vector2(_cols(), PICTURE.size()) * s + Vector2.ONE * BORDER * 2.0 * k)
	Art.stitches(b, field, STITCH * k, Color(Pal.PLAQUE, 0.6))
	# Patches under what is not sewn, then the sewn squares.
	for y in PICTURE.size():
		for x in _cols():
			var cell := Vector2i(x, y)
			if PICTURE[y][x] == ".":
				continue
			# Seen close, as the board shows a small picture: the patch and
			# the whole button on it, thread through its holes.
			Art.patch(b, _mid(cell), s, _colour_at(cell))
			if not (cell == HOME or cell == BARE or cell == LOOSE):
				Art.button(b, _mid(cell), s, _colour_at(cell), true)
	# The loose button on a patch that is not its own, over its shadow.
	var loose := _mid(LOOSE)
	Scenery.soft_disc(b, loose + Vector2(0.0, s * 0.1), s * 0.37, s * 0.12, Color(Pal.TEXT, 0.22))
	Art.button(b, loose, s, Art.colour(STEM), false)
	# The tin and the button waiting in it.
	Scenery.soft_disc(b, Vector2(tin.get_center().x, tin.end.y + 3.0 * k), tin.size.x * 0.5, 6.0 * k, Color(Pal.TEXT, 0.14))
	Art.tin(b, tin, TIN_PLACES, TIN_PLACES, TIN_PLACES, TIN_STEP * k)
	Art.button(b, Art.tin_place(tin, 0, TIN_PLACES, TIN_STEP * k, TIN_PLACES), TIN_STEP * k * 0.92, Art.colour(SPOT), false)
	var home := _mid(HOME)
	if soon:
		# Not open yet: the button lies plain on the linen, at the board's size.
		var at := _go_at()
		Scenery.soft_disc(b, at + Vector2(0.0, s * 0.1), s * 0.37, s * 0.12, Color(Pal.TEXT, 0.22))
		Art.button(b, at, s, colour, false)
		return
	Scenery.soft_disc(b, home, s * 0.62, s * 0.62, Color(Pal.SUN, 0.55))
	b.stroke(Face.Builder.ring(home, s * 0.4, s * 0.4), s * 0.08, Color(Pal.SUN, 0.95), true)
	_go(b, _go_at(), k, home, s)

## One line of running stitch along the foot, from the words' margin to
## short of the tin.
func _hem(b: Face.Builder, k: float, until: float) -> void:
	var y := size.y - HEM * k
	var x := SIDE + 4.0
	var step := HEM_STEP * k
	while x + step * 0.6 < until:
		b.stroke(PackedVector2Array([Vector2(x, y), Vector2(x + step * 0.6, y)]), maxf(2.0, 2.4 * k), Color(HEM_INK, 0.8))
		x += step

## The go button about `at`: a button of the board's make in the card's
## colour, large, lifted over its own shadow, a chevron in its dish, and the
## dotted hop to the patch it is for.
func _go(b: Face.Builder, at: Vector2, k: float, home: Vector2, s: float) -> void:
	var cell := GO_ACROSS * k / (Art.RIM * 2.0)
	var r := cell * Art.RIM
	var lift := GO_LIFT * k
	var way := home - at
	var reach := way.length()
	var dir := way / reach
	var d := r + s * 0.3
	while d < reach - s * 0.5:
		b.disc(at + dir * d - Vector2(0.0, lift * (1.0 - d / reach)), s * 0.075, Color(colour.darkened(0.12), 0.8))
		d += s * 0.3
	Scenery.soft_disc(b, at + Vector2(0.0, r * 0.7 + lift), r * 1.05, r * 0.34, Color(Pal.TEXT, GO_SHADOW))
	var up := at - Vector2(0.0, lift)
	Art.button(b, up, cell, colour, false)
	# The centre face again over the holes, and the chevron in it.
	var c := up - Vector2(0.0, cell * Art.RISE)
	b.polygon(Art.tile(c, cell * Art.FACE, cell * Art.TIP * 0.35), colour)
	var h := r * 0.34
	b.stroke(PackedVector2Array([c + Vector2(-h * 0.55, -h), c + Vector2(h * 0.55, 0.0), c + Vector2(-h * 0.55, h)]),
		r * 0.2, Pal.SURFACE)

func _lay() -> void:
	var words := _words(String(entry.get("title", "")), SIDE, size.y * 0.5, WORDS, Pal.TEXT, BLURB)
	words.position.y = roundf(WORDS_TOP * _k())
