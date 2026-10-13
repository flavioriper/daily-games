extends "res://ui/menu/cards/card_face.gd"

## Molehill's card: a light lawn and three of the game's own hills in a
## triangle, two behind and one in front. The far left one holds a mole just
## bonked, dizzy under three stars; the far right one, under the seal's
## corner, is an empty hole; and out of the near one a mole is up and looking
## about, which is the one to hit. No rabbit: the hill it would peek from
## stands under the seal.
##
## The go button is the mallet over that mole: the game's barrel head redrawn
## in the card's colour, large, lifted over a shadow, its striking end turned
## down at the mole and a chevron along the blow; its handle runs up to the
## right, under the seal. The name stands top left, with the best score.
##
## Everything is one mesh: the hills and the moles are
## arcade/molehill_art.gd's own builders and meshes, and nothing lives on it.

const MoleArt = preload("res://arcade/molehill_art.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

## The row the card was drawn for (puzzle_card_2d.gd's CARD_H).
const H := 246.0
## The game's unit at H: a mound is 92 of them wide.
const UNIT := 0.85
## The hills' mouths as [in from the right, down] at H: the dizzy mole's,
## the empty one, and the one the mole is up in.
const BONKED := Vector2(205.0, 150.0)
const EMPTY := Vector2(56.0, 152.0)
const UP := Vector2(128.0, 212.0)
## The picture's left reach at H, and where the words end: the scale is
## capped so the one never passes the other.
const REACH := 248.0
const WORDS_END := 240.0
## The mallet: its head's middle as [in from the right, down] at H, the way
## the blow goes, the head's size across and along it, the handle's length
## and width, how far it is lifted and its shadow.
const HEAD_AT := Vector2(140.0, 108.0)
const BLOW := Vector2(0.26, 0.97)
const HEAD := Vector2(40.0, 62.0)
const HEAD_ROUND := 10.0
const HANDLE := 90.0
const HANDLE_W := 9.0
const GO_LIFT := 5.0
const GO_SHADOW := 0.2
## The stars over the dizzy mole, in units from its hole: [x, y, radius].
const STARS := [[-17.0, -66.0, 5.0], [1.0, -75.0, 6.5], [18.0, -65.0, 4.5]]
const STAR := Color("ffd65c")
## Tufts on the lawn, as [x in the card's width, down at H, size, lean].
const TUFTS := [[0.08, 214.0, 1.0, -1.0], [0.3, 226.0, 0.8, 1.0], [0.62, 96.0, 0.7, 1.0]]
## The words' margin, their room and how far down they start.
const SIDE := 22.0
const WORDS := 215.0
const WORDS_TOP := 14.0

## The lawn, a pale pool behind the hills, and the blurb's ink.
const LAWN_TOP := Color("e6f3d6")
const LAWN_LOW := Color("cfe6b4")
const POOL := Color("f1f9e2")
const BLURB := Color("5f6e4a")

## The picture's scale: the card's height sets it, its width caps it.
func _k() -> float:
	return minf(size.y / H, (size.x - WORDS_END) / REACH)

## A place given as [in from the right, down at H], on the card: anchored to
## the right side and the foot.
func _at(p: Vector2) -> Vector2:
	var k := _k()
	return Vector2(size.x - p.x * k, size.y - (H - p.y) * k)

func _paint(b: Face.Builder) -> void:
	var k := _k()
	var u := UNIT * k
	var first := b.verts.size()
	b.polygon(ground(), Color.WHITE)
	shade(b, first, LAWN_TOP, LAWN_LOW, 0.0, size.y)
	Scenery.soft_disc(b, _at(Vector2(128.0, 172.0)), 150.0 * k, 70.0 * k, Color(POOL, 0.6))
	for t: Array in TUFTS:
		var at := Vector2(size.x * float(t[0]), size.y - (H - float(t[1])) * k)
		if at.x < WORDS_END and at.y < 176.0 * size.y / H:
			continue
		MoleArt.tuft(b, at, k * float(t[2]), float(t[3]))
	# The far hills whole, then the near one over them, as the game rows them.
	var bonked := _at(BONKED)
	var empty := _at(EMPTY)
	var up := _at(UP)
	MoleArt.mound_back(b, bonked, u)
	MoleArt.mound_back(b, empty, u)
	b.append(MoleArt.mesh(MoleArt.Look.MOLE_DIZZY, u), Transform2D(0.0, bonked))
	MoleArt.mound_front(b, bonked, u)
	MoleArt.mound_front(b, empty, u)
	for s: Array in STARS:
		_star(b, bonked + Vector2(float(s[0]), float(s[1])) * u, float(s[2]) * u)
	MoleArt.mound_back(b, up, u)
	b.append(MoleArt.mesh(MoleArt.Look.MOLE, u, 1), Transform2D(0.0, up))
	MoleArt.mound_front(b, up, u)
	_mallet(b, k)

## A four-pointed star, flat.
func _star(b: Face.Builder, c: Vector2, r: float) -> void:
	b.fan(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.28, -r * 0.28), c + Vector2(r, 0),
		c + Vector2(r * 0.28, r * 0.28), c + Vector2(0, r), c + Vector2(-r * 0.28, r * 0.28), c + Vector2(-r, 0),
		c + Vector2(-r * 0.28, -r * 0.28)]), STAR)

## The mallet: the go button in the card's colour, or the game's plain wood
## and smaller when the card is not open yet.
func _mallet(b: Face.Builder, k: float) -> void:
	var s := k * (0.7 if soon else 1.0)
	var blow := BLOW.normalized()
	var along := Vector2(blow.y, -blow.x)
	var c := _at(HEAD_AT) - Vector2(0.0, 0.0 if soon else GO_LIFT * k)
	var face: Color = MoleArt.WOOD if soon else colour
	var deep: Color = MoleArt.WOOD_DEEP if soon else colour.darkened(0.26)
	var band: Color = MoleArt.WOOD_BAND if soon else colour.darkened(0.42)
	Scenery.soft_disc(b, c + Vector2(6.0, 18.0 + GO_LIFT) * s, HEAD.x * 0.95 * s, HEAD.y * 0.4 * s, Color(Pal.TEXT, GO_SHADOW))
	# The handle up to the right, a grip at its end.
	var hand := c + along * HANDLE * s
	b.stroke(PackedVector2Array([c, hand]), HANDLE_W * s, MoleArt.WOOD_DEEP)
	b.stroke(PackedVector2Array([c + Vector2(-1.0, -1.0) * s, hand + Vector2(-1.0, -1.0) * s]), HANDLE_W * 0.6 * s, MoleArt.HANDLE)
	b.stroke(PackedVector2Array([hand - along * 24.0 * s, hand]), HANDLE_W * 1.25 * s, Color("9a4f3a"))
	# The barrel, its long side along the blow.
	var xf := Transform2D(along, blow, c)
	var half := HEAD * 0.5 * s
	b.polygon(xf * Face.Builder.round_rect(-half + Vector2(0.0, 0.0), HEAD * s, HEAD_ROUND * s), deep)
	b.polygon(xf * Face.Builder.round_rect(-half + Vector2(1.5, 1.5) * s, (HEAD - Vector2(3.0, 6.0)) * s, (HEAD_ROUND - 1.0) * s), face)
	b.polygon(xf * Face.Builder.round_rect(-half + Vector2(4.0, 5.0) * s, Vector2(7.0, HEAD.y - 14.0) * s, 3.5 * s),
		Color(Pal.SURFACE, 0.2))
	for side in [-1.0, 1.0]:
		var y: float = side * (HEAD.y * 0.5 - 9.0) * s
		b.polygon(xf * Face.Builder.round_rect(Vector2(-half.x, y - 3.0 * s), Vector2(HEAD.x * s, 6.0 * s), 2.0 * s), band)
	if soon:
		return
	var h := 8.0 * s
	b.stroke(xf * PackedVector2Array([Vector2(-h, -h * 0.55), Vector2(0.0, h * 0.55), Vector2(h, -h * 0.55)]), 5.0 * s, Pal.SURFACE)

func _lay() -> void:
	var words := _words(String(entry.get("title", "")), SIDE, size.y * 0.5, WORDS, Pal.TEXT, BLURB)
	words.position.y = roundf(WORDS_TOP * size.y / H)
