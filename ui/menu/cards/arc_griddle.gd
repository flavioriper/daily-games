extends "res://ui/menu/cards/card_face.gd"

## Griddle's card: the toastie stand seen from the front on a warm cream
## evening. A small stall stands low on the right: the game's teal and cream
## awning in scallops under the seal's corner, two posts, the pale wall
## behind, and the counter with its wooden top and teal front along the
## foot. On the counter the iron grill has a toastie still pale on it, two
## soft puffs of steam over it; one of the town waits in front.
##
## The go button is the serve, which is what the player presses at the
## stand: a tray in the card's colour on the pass with the golden toastie
## ready on it, lifted over its shadow, a chevron beside the toastie. The
## name stands top left with the stand's line under it.
##
## Everything is one mesh, the toasties and the customer arcade/griddle_art.gd's
## own builders; nothing lives on the card and it writes no string.

const Art = preload("res://arcade/griddle_art.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

## The row the card was drawn for (puzzle_card_2d.gd's CARD_H) and the width
## the picture's places are written at.
const H := 246.0
const W := 490.0
## The words end here: the picture's scale is capped so the stall never
## starts left of it.
const WORDS_END := 250.0
## The stall, at H on a W-wide card: its left and right, the awning's top,
## its band and its scallops' drop, the counter's top and the front's foot.
const LEFT := 262.0
const RIGHT := 476.0
const AWNING_Y := 76.0
const AWNING_BAND := 16.0
const STRIPES := 6
const TOP_Y := 168.0
const FRONT_Y := 182.0
const FOOT_Y := 234.0
## The grill on the counter: its middle, its width and height.
const GRILL := Vector2(326.0, 154.0)
const GRILL_W := 92.0
const GRILL_H := 28.0
## The toasties' widths, and how brown the one on the grill is.
const PALE := 46.0
const PALE_DONE := 0.25
const READY := 42.0
## The go tray: its middle, its size, how far it is lifted and its shadow.
const GO := Vector2(422.0, 150.0)
const GO_SIZE := Vector2(92.0, 52.0)
const GO_LIFT := 5.0
const GO_SHADOW := 0.24
## The plain plate when the card is not open yet.
const PLAIN_R := 24.0
## The customer: where the feet stand, how tall, coat and skin.
const FOLK := Vector2(286.0, 240.0)
const FOLK_TALL := 66.0
const FOLK_COAT := 0
const FOLK_SKIN := 1
## The steam's puffs, as [x, y, radius] at H.
const STEAM := [[318.0, 118.0, 11.0], [334.0, 104.0, 8.0]]
## The words' margin, their room and how far down they start.
const SIDE := 22.0
const WORDS := 215.0
const WORDS_TOP := 14.0

## The evening: cream over a deeper cream, a warm pool behind the stall, and
## the blurb's ink.
const SKY_TOP := Color("fdf3e6")
const SKY_LOW := Color("f7dfc6")
const POOL := Color("fff8e8")
const BLURB := Color("7d6a52")
## The awning's two cloths, softened from the game's teal and cream.
const CLOTH_A := Color("7fc4ba")
const CLOTH_B := Color("fffaf0")

func _k() -> float:
	return minf(size.y / H, (size.x - WORDS_END) / (W - WORDS_END))

## A place written at H on a W-wide card, on this card: the picture hangs
## from the right side and stands on the foot.
func _at(p: Vector2) -> Vector2:
	var k := _k()
	return Vector2(size.x - (W - p.x) * k, size.y - (H - p.y) * k)

func _rr(b: Face.Builder, at: Vector2, sz: Vector2, r: float, col: Color) -> void:
	var k := _k()
	b.fan(Face.Builder.round_rect(_at(at), sz * k, r * k), col)

func _paint(b: Face.Builder) -> void:
	var k := _k()
	var first := b.verts.size()
	b.polygon(ground(), Color.WHITE)
	shade(b, first, SKY_TOP, SKY_LOW, 0.0, size.y)
	Scenery.soft_disc(b, _at(Vector2((LEFT + RIGHT) * 0.5, 150.0)), 150.0 * k, 96.0 * k, Color(POOL, 0.6))
	# The stall's shadow on the ground, the wall behind and the two posts.
	Scenery.soft_disc(b, _at(Vector2((LEFT + RIGHT) * 0.5, FOOT_Y + 2.0)), (RIGHT - LEFT) * 0.56 * k, 9.0 * k, Color(Art.INK, 0.2))
	_rr(b, Vector2(LEFT + 6.0, AWNING_Y + 6.0), Vector2(RIGHT - LEFT - 12.0, TOP_Y - AWNING_Y), 6.0, Art.WALL)
	_rr(b, Vector2(LEFT + 6.0, AWNING_Y + 6.0), Vector2(RIGHT - LEFT - 12.0, 34.0), 6.0, Art.WALL_SHADE)
	for x: float in [LEFT + 4.0, RIGHT - 12.0]:
		_rr(b, Vector2(x, AWNING_Y + 6.0), Vector2(8.0, TOP_Y - AWNING_Y), 3.0, Art.WOOD_DEEP)
	# The grill, the toastie on it and its steam.
	_rr(b, Vector2(GRILL.x - GRILL_W * 0.5, GRILL.y - GRILL_H * 0.5 + 3.0), Vector2(GRILL_W, GRILL_H), 7.0, Color("3c3f46"))
	_rr(b, Vector2(GRILL.x - GRILL_W * 0.5, GRILL.y - GRILL_H * 0.5), Vector2(GRILL_W, GRILL_H * 0.5), 7.0, Art.IRON)
	for i in 4:
		var x := GRILL.x - GRILL_W * 0.3 + GRILL_W * 0.2 * i
		_rr(b, Vector2(x - 2.0, GRILL.y + 3.0), Vector2(4.0, GRILL_H * 0.34), 2.0, Art.IRON_HI)
	Art.toastie_into(b, _at(Vector2(GRILL.x, GRILL.y - GRILL_H * 0.5 - PALE * 0.2)), PALE * k, PALE_DONE)
	for p: Array in STEAM:
		Scenery.soft_disc(b, _at(Vector2(p[0], p[1])), p[2] * k, p[2] * 0.8 * k, Color(Art.CREAM, 0.85))
	# The counter: its front, the panels on it, and the wooden top.
	_rr(b, Vector2(LEFT, FRONT_Y - 8.0), Vector2(RIGHT - LEFT, FOOT_Y - FRONT_Y + 8.0), 9.0, Art.TEAL_DEEP)
	var panels := 4
	var pw := (RIGHT - LEFT - 20.0) / panels
	for i in panels:
		_rr(b, Vector2(LEFT + 10.0 + pw * i + 5.0, FRONT_Y + 12.0), Vector2(pw - 10.0, FOOT_Y - FRONT_Y - 24.0), 6.0, Art.TEAL)
	_rr(b, Vector2(LEFT - 5.0, TOP_Y + 4.0), Vector2(RIGHT - LEFT + 10.0, FRONT_Y - TOP_Y), 6.0, Art.WOOD_DEEP)
	_rr(b, Vector2(LEFT - 5.0, TOP_Y), Vector2(RIGHT - LEFT + 10.0, FRONT_Y - TOP_Y), 6.0, Art.WOOD_HI)
	# The awning over it all: a band and a scallop a stripe.
	var sw := (RIGHT - LEFT + 16.0) / STRIPES
	var ax := LEFT - 8.0
	Scenery.soft_disc(b, _at(Vector2((LEFT + RIGHT) * 0.5, AWNING_Y + AWNING_BAND + sw * 0.5 + 6.0)), (RIGHT - LEFT) * 0.52 * k, 9.0 * k, Color(Art.INK, 0.14))
	for i in STRIPES:
		var cloth := CLOTH_A if i % 2 == 0 else CLOTH_B
		var at := _at(Vector2(ax + sw * i, AWNING_Y))
		b.fan(PackedVector2Array([at, at + Vector2(sw * k + 0.5, 0.0), at + Vector2(sw * k + 0.5, AWNING_BAND * k), at + Vector2(0.0, AWNING_BAND * k)]), cloth)
		b.fan(Face.Builder.arc_points(at + Vector2(sw * 0.5, AWNING_BAND) * k, sw * 0.5 * k, 0.0, PI), cloth)
	_rr(b, Vector2(ax, AWNING_Y - 4.0), Vector2(sw * STRIPES, 7.0), 3.5, Art.WOOD_DEEP)
	# One of the town, waiting in front.
	_folk(b, _at(FOLK), FOLK_TALL * k)
	if soon:
		# Not open yet: a plain plate on the pass with the toastie on it.
		var c := _at(GO)
		b.disc(c + Vector2(0.0, 3.0 * k), PLAIN_R * k, Color(Art.INK, 0.2))
		b.disc(c, PLAIN_R * k, Art.CREAM)
		Art.toastie_into(b, c - Vector2(0.0, 3.0 * k), READY * 0.8 * k, 1.0)
		return
	_go(b, _at(GO) - Vector2(0.0, GO_LIFT * k), k)

## The game's own person with the feet at `foot`: its builder draws about
## the origin, so what it lays is moved after.
func _folk(b: Face.Builder, foot: Vector2, tall: float) -> void:
	var first := b.verts.size()
	Art._person(b, tall, Art.COATS[FOLK_COAT], Art.SKINS[FOLK_SKIN], false, Color.TRANSPARENT)
	for i in range(first, b.verts.size()):
		b.verts[i] += foot

## The go tray about `at`: the card's colour, lifted over its own shadow,
## the ready toastie on its left and a chevron on its right.
func _go(b: Face.Builder, at: Vector2, k: float) -> void:
	var sz := GO_SIZE * k
	var corner := at - sz * 0.5
	Scenery.soft_disc(b, at + Vector2(0.0, sz.y * 0.5 + (GO_LIFT + 4.0) * k), sz.x * 0.54, 8.0 * k, Color(Art.INK, GO_SHADOW))
	b.fan(Face.Builder.round_rect(corner + Vector2(0.0, 5.0 * k), sz, 15.0 * k), colour.darkened(0.26))
	b.fan(Face.Builder.round_rect(corner, sz, 15.0 * k), colour)
	b.fan(Face.Builder.round_rect(corner + Vector2(5.0, 5.0) * k, Vector2(sz.x - 10.0 * k, sz.y * 0.36), 10.0 * k), Color(Pal.SURFACE, 0.16))
	Art.toastie_into(b, at + Vector2(-sz.x * 0.2, -3.0 * k), READY * k, 1.0)
	var c := at + Vector2(sz.x * 0.31, 0.0)
	var h := 9.0 * k
	b.stroke(PackedVector2Array([c + Vector2(-h * 0.55, -h), c + Vector2(h * 0.55, 0.0), c + Vector2(-h * 0.55, h)]),
		6.0 * k, Pal.SURFACE)

func _lay() -> void:
	var words := _words(String(entry.get("title", "")), SIDE, size.y * 0.5, WORDS, Pal.TEXT, BLURB)
	words.position.y = roundf(WORDS_TOP * _k())
