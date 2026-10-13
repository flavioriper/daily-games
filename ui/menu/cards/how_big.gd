extends "res://ui/menu/cards/card_face.gd"

## How Big?'s card: one round of the board, mid-guess, on a pale periwinkle
## paper. A person stands in ink on the ground line with the board's bracket
## up their outer side -- the thing whose size is known -- and to their
## right the elephant stands as the board draws an answer still being sized:
## white, in an ink outline, its foot on the line's right end. It is too
## small. A faint line round it shows the size it has to reach, to scale
## with the person (1.65 m beside 3.2 m at the shoulder, the table's own
## figures), so the picture says which way to pull.
##
## The go button is the board's grip, on the answer's top left corner where
## the finger sizes it: a disc in the card's colour, larger than the
## board's, lifted over a shadow, its chevron pointing up and away from the
## foot, the way that grows it, and two dots leading on to the corner it is
## pulled toward. The board's Lock is a worded button in the actions row and
## is not drawn. The name stands top left.
##
## Everything is one mesh, the silhouettes ui/faces/how_big_art.gd's own
## data and builders. Nothing lives on the card and it writes no string.

const Art = preload("res://ui/faces/how_big_art.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

## The card the picture was drawn for (puzzle_card_2d.gd's CARD_H, and the
## narrowest card the grid lays).
const H := 246.0
const W := 490.0
## The two things, and their sizes in metres as content/how_big.json has
## them (both heights, both over the whole of the drawing).
const KNOWN := "person"
const ANSWER := "elephant"
const KNOWN_M := 1.65
const ANSWER_M := 3.2
## The answer's true height on the card at H, and the share of it the guess
## stands at.
const TRUE_TALL := 124.0
const GUESS := 0.76
## The ground line over the card's foot, the picture's room from the right
## side, the gap between the two things, and how far the line runs on past
## the person and the answer.
const GROUND := 34.0
const RIGHT := 22.0
const GAP := 30.0
const RUN := Vector2(30.0, 10.0)
## The line's and the outlines' widths at H, and how strong the true size's
## line is.
const LINE_W := 3.0
const OUTLINE_W := 3.0
const TRUE_W := 2.0
const TRUE_ALPHA := 0.2
## The bracket: how far off the person it stands, its width and its feet.
const BRACKET_OFF := 10.0
const BRACKET_W := 2.6
const BRACKET_FOOT := 5.0
## The go grip: its radius at H, how far it is lifted, its shadow, and the
## dots leading on from it (how many, how big).
const GRIP := 25.0
const GRIP_LIFT := 4.0
const GRIP_SHADOW := 0.22
const DOTS := 2
const DOT_R := 2.6
## The plain grip of a card not open yet.
const GRIP_PLAIN := 13.0
## The words' margin, their room and how far down they start.
const SIDE := 22.0
const WORDS := 215.0
const WORDS_TOP := 14.0

## The paper, a pale pool behind the picture, and the blurb's ink.
const PAPER_TOP := Color("efeefa")
const PAPER_LOW := Color("dedcf2")
const POOL := Color("f8f7fd")
const BLURB := Color("6b6886")

## The picture's scale: the card's height sets it, its width caps it.
func _k() -> float:
	return minf(size.y / H, size.x / W)

func _ground_y() -> float:
	return size.y - GROUND * _k()

## The answer's box at `share` of its true size, its bottom right corner on
## the line's right end.
func _answer_box(share: float) -> Rect2:
	var k := _k()
	var tall := TRUE_TALL * k * share
	var wide := tall * Art.aspect(ANSWER)
	var foot := Vector2(size.x - RIGHT * k, _ground_y())
	return Rect2(foot - Vector2(wide, tall), Vector2(wide, tall))

## The person's box, to scale with the answer's true size, left of it.
func _known_box() -> Rect2:
	var k := _k()
	var tall := TRUE_TALL * k * KNOWN_M / ANSWER_M
	var wide := tall * Art.aspect(KNOWN)
	var x := _answer_box(1.0).position.x - GAP * k - wide
	return Rect2(Vector2(x, _ground_y() - tall), Vector2(wide, tall))

## The shape standing in `box`.
static func _in(id: String, box: Rect2) -> Transform2D:
	return Art.stand(id, Vector2(box.position.x, box.end.y), maxf(box.size.x, box.size.y))

func _paint(b: Face.Builder) -> void:
	var k := _k()
	var first := b.verts.size()
	b.polygon(ground(), Color.WHITE)
	shade(b, first, PAPER_TOP, PAPER_LOW, 0.0, size.y)
	var full := _answer_box(1.0)
	var guess := _answer_box(GUESS)
	var known := _known_box()
	var y := _ground_y()
	Scenery.soft_disc(b, Vector2(lerpf(known.position.x, full.end.x, 0.55), y - full.size.y * 0.42),
		(full.end.x - known.position.x) * 0.48, full.size.y * 0.6, Color(POOL, 0.6))
	# The ground line under both.
	b.stroke(PackedVector2Array([Vector2(known.position.x - RUN.x * k, y), Vector2(full.end.x + RUN.y * k, y)]),
		LINE_W * k, Color(Pal.TEXT, 0.5))
	# The known thing, in ink, and its bracket up the outer side.
	Art.fill(b, KNOWN, _in(KNOWN, known), Pal.TEXT)
	var bx := known.position.x - BRACKET_OFF * k
	Art.bracket(b, Vector2(bx, known.end.y - LINE_W * k), Vector2(bx, known.position.y), Vector2.RIGHT,
		Color(Pal.TEXT, 0.6), BRACKET_W * k, BRACKET_FOOT * k)
	# The size the answer has to reach, then the answer as it stands.
	Art.outline(b, ANSWER, _in(ANSWER, full), TRUE_W * k, Color(Pal.TEXT, TRUE_ALPHA))
	var xf := _in(ANSWER, guess)
	Art.fill(b, ANSWER, xf, Pal.SURFACE)
	Art.outline(b, ANSWER, xf, OUTLINE_W * k, Pal.TEXT)
	if soon:
		Art.grip(b, guess.position, GRIP_PLAIN * k, Vector2(-1.0, -1.0), Pal.SURFACE, Pal.TEXT)
		return
	_go(b, guess.position, full.position, k)

## The go grip on the answer's corner `at`, pulled toward `to`.
func _go(b: Face.Builder, at: Vector2, to: Vector2, k: float) -> void:
	var r := GRIP * k
	var pull := (to - at).normalized()
	var reach := at.distance_to(to)
	for i in DOTS:
		var d := r + (reach - r) * (float(i) + 0.75) / float(DOTS)
		b.disc(at + pull * d, DOT_R * k, Color(Pal.TEXT, 0.45))
	Scenery.soft_disc(b, at + Vector2(0.0, r * 0.82 + GRIP_LIFT * k), r * 0.95, r * 0.34, Color(Pal.TEXT, GRIP_SHADOW))
	var c := at - Vector2(0.0, GRIP_LIFT * k)
	b.disc(c + Vector2(0.0, r * 0.14), r, colour.darkened(0.28))
	b.disc(c, r, colour)
	b.disc(c - Vector2(0.0, r * 0.3), r * 0.62, Color(Pal.SURFACE, 0.14))
	# The chevron, along the pull.
	var side := Vector2(-pull.y, pull.x)
	var h := r * 0.36
	var tip := c + pull * h * 0.55
	b.stroke(PackedVector2Array([tip - pull * h * 1.1 + side * h, tip, tip - pull * h * 1.1 - side * h]),
		r * 0.22, Pal.SURFACE)

func _lay() -> void:
	var words := _words(String(entry.get("title", "")), SIDE, size.y * 0.5, WORDS, Pal.TEXT, BLURB)
	words.position.y = roundf(WORDS_TOP * size.y / H)
