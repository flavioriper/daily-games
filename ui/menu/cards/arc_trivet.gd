extends "res://ui/menu/cards/card_face.gd"

## Trivet's card: the tray from above on a pale grey-teal table. A flower
## of seven of the game's own places stands low on the right, cut in its
## wood, and four of them hold stacks of felt mats drawn as the game draws
## a stack: the sides of every mat showing, the mark only on the top one.
## The middle stack's top two mats are the card's colour, and the place up
## and to the left of it is bare and lit: a stack set down there meets a
## neighbour whose top is its own colour, which is the game's one rule.
##
## The go button is that stack in hand: two mats in the card's colour,
## larger, lifted over its shadow above the bare place, a chevron pressed
## into its top where the others wear a mark. The name stands top left with
## the best under it.
##
## Everything is one mesh, built in arcade/trivet_art.gd's own pixels (U to
## a mat's half width) and laid by scale, and nothing lives on the card.

const Art = preload("res://arcade/trivet_art.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

## The row the card was drawn for (puzzle_card_2d.gd's CARD_H), and the
## width it was drawn at.
const H := 246.0
const W := 490.0
## A mat's half width at H, and the tray's middle in from the card's right
## side and up from its foot.
const MAT := 32.0
const TRAY_IN := Vector2(104.0, 88.0)
## The places, in the sim's axial cells: the flower.
const PLACES: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 1),
	Vector2i(-1, 0), Vector2i(0, -1)]
## The stacks, bottom to top, by the art's colour index; ROSE stands for the
## card's own colour.
const ROSE := -1
const STACKS := {
	Vector2i(0, -1): [1, 1, 2],
	Vector2i(1, -1): [4, 4, 4],
	Vector2i(0, 0): [3, 3, ROSE, ROSE],
	Vector2i(1, 0): [5, 5],
	Vector2i(0, 1): [2, 2, 1, 1],
}
## The bare place the go stack is bound for, and the neighbour it meets.
const HOME := Vector2i(-1, 0)
const MEETS := Vector2i(0, 0)
## The go stack: its mats, its size beside a laid one, how far it is lifted
## (in mat half widths) and its shadow.
const GO := [ROSE, ROSE]
const GO_SIZE := 1.28
const GO_LIFT := 0.62
const GO_SHADOW := 0.24
## The words' margin, their room and how far down they start.
const SIDE := 22.0
const WORDS := 215.0
const WORDS_TOP := 14.0

## The table: a pale grey-teal, a soft pool under the tray, the blurb's ink.
const TABLE_TOP := Color("ecf3f2")
const TABLE_LOW := Color("d9e7e5")
const POOL := Color("f7fbfa")
const BLURB := Color("5f7472")

## The picture's scale: the card's height sets it, its width caps it.
func _k() -> float:
	return minf(size.y / H, size.x / W)

## The tray's middle on the card.
func _tray() -> Vector2:
	return size - TRAY_IN * _k()

## A place's middle on the card.
func _mid(cell: Vector2i) -> Vector2:
	return _tray() + Art.place_of(cell) * MAT * _k()

## The go stack meets a stack whose top is its own colour: the game's rule.
static func _meets() -> bool:
	var there: Array = STACKS.get(MEETS, [])
	return not STACKS.has(HOME) and not there.is_empty() and there[-1] == GO[-1] and PLACES.has(HOME)

## Lays every vertex `b` has taken since `first` -- drawn in the art's own
## pixels about the origin -- at `scale` about `at`.
static func _set_down(b: Face.Builder, first: int, at: Vector2, scale: float) -> void:
	for i in range(first, b.verts.size()):
		b.verts[i] = b.verts[i] * scale + at

func _paint(b: Face.Builder) -> void:
	var k := _k()
	var s := MAT * k / Art.U
	var first := b.verts.size()
	b.polygon(ground(), Color.WHITE)
	shade(b, first, TABLE_TOP, TABLE_LOW, 0.0, size.y)
	var tray := _tray()
	Scenery.soft_disc(b, tray + Vector2(0.0, 6.0 * k), MAT * k * 3.0, MAT * k * 2.2, Color(POOL, 0.6))
	# The tray, as the art cuts it: a board to the places' outline, a dent a
	# place.
	first = b.verts.size()
	var u := Art.U
	for c: Vector2i in PLACES:
		b.fan(Art.hex(Art.place_of(c) * u + Vector2(0.0, u * 0.3), u * 1.2), Color(0.16, 0.09, 0.03, 0.16))
	for c: Vector2i in PLACES:
		b.fan(Art.hex(Art.place_of(c) * u + Vector2(0.0, u * 0.13), u * 1.16), Art.TRAY_LOW)
	for c: Vector2i in PLACES:
		b.fan(Art.hex(Art.place_of(c) * u, u * 1.16), Art.TRAY)
	for c: Vector2i in PLACES:
		b.fan(Art.hex(Art.place_of(c) * u - Vector2(0.0, u * 0.02), u * 1.06), Art.TRAY_HI)
	for c: Vector2i in PLACES:
		var at := Art.place_of(c) * u
		b.fan(Art.hex(at, u * 0.95), Art.DENT)
		b.fan(Art.hex(at + Vector2(0.0, u * 0.05), u * 0.9), Art.DENT.lightened(0.09))
	if not soon and _meets():
		# The bare place lit: where the stack in hand goes.
		var home := Art.place_of(HOME) * u
		b.fan(Art.hex(home + Vector2(0.0, u * 0.05), u * 0.9), Color(Art.HALO, 0.5))
		b.stroke(Art.hex(home + Vector2(0.0, u * 0.05), u * 0.78), u * 0.09, Color(Art.HALO, 0.95), true)
	_set_down(b, first, tray, s)
	# The stacks, the far ones first.
	var cells: Array = STACKS.keys()
	cells.sort_custom(func(a: Vector2i, z: Vector2i) -> bool: return Art.place_of(a).y < Art.place_of(z).y)
	for c: Vector2i in cells:
		first = b.verts.size()
		_stack(b, STACKS[c], true)
		_set_down(b, first, _mid(c), s)
	# The stack in hand.
	var over := _mid(HOME)
	if soon:
		first = b.verts.size()
		_stack(b, GO, true)
		_set_down(b, first, over, s)
		return
	Scenery.soft_disc(b, over + Vector2(0.0, MAT * k * 0.16), MAT * k * 1.0, MAT * k * 0.62, Color(Pal.TEXT, GO_SHADOW))
	first = b.verts.size()
	_stack(b, GO, false)
	_chevron(b, Art.top_of(GO.size()))
	_set_down(b, first, over - Vector2(0.0, MAT * k * GO_LIFT), s * GO_SIZE)

## A stack about the origin in the art's pixels, bottom to top, its shadow
## under it; only the top mat wears its mark, and not even it when `marked`
## is off (the go stack wears the chevron there).
func _stack(b: Face.Builder, mats: Array, marked: bool) -> void:
	var u := Art.U
	b.ellipse(Vector2(0.0, u * 0.1), u * 1.04, u * Art.SQ * 1.02, Color(0.16, 0.09, 0.03, 0.24))
	for i in mats.size():
		var at := Vector2(0.0, -i * Art.TH * u)
		var top := i == mats.size() - 1
		if int(mats[i]) == ROSE:
			_mat(b, at, top and marked)
		else:
			Art.mat_into(b, int(mats[i]), at, top and marked)

## One mat in the card's colour, as the art lays a mat: three sides that
## face the player, the top, and the first felt's mark pressed into it.
func _mat(b: Face.Builder, at: Vector2, marked: bool) -> void:
	var u := Art.U
	var felt := colour if not soon else (Art.FELT[0] as Color)
	var top := at - Vector2(0.0, Art.TH * u)
	var up := Art.hex(top, u)
	var down := Art.hex(at, u)
	var shades := [0.2, 0.3, 0.38]
	for n in 3:
		b.fan(PackedVector2Array([up[n], up[n + 1], down[n + 1], down[n]]), felt.darkened(shades[n]))
	b.fan(up, felt.darkened(0.06))
	b.fan(Art.hex(top - Vector2(0.0, 1.5), u * 0.9), felt.lightened(0.07))
	if marked:
		b.ellipse(top, u * 0.24, u * 0.24 * Art.SQ, felt.lightened(0.34))

## The chevron on the go stack's top, about `c` in the art's pixels,
## pointing down at the place it is bound for.
func _chevron(b: Face.Builder, c: Vector2) -> void:
	var u := Art.U
	var h := u * 0.3
	b.stroke(PackedVector2Array([c + Vector2(-h, -h * 0.5 * Art.SQ), c + Vector2(0.0, h * 0.6 * Art.SQ),
		c + Vector2(h, -h * 0.5 * Art.SQ)]), u * 0.17, Pal.SURFACE)

func _lay() -> void:
	var words := _words(String(entry.get("title", "")), SIDE, size.y * 0.5, WORDS, Pal.TEXT, BLURB)
	words.position.y = roundf(WORDS_TOP * _k() if size.y / H <= size.x / W else WORDS_TOP * size.y / H)
