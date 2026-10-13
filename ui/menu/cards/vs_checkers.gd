extends "res://ui/menu/cards/card_face.gd"

## Checkers' card: no board, only the dark squares of one diagonal run, laid
## on a warm cream ground as stepping stones that climb from the card's foot
## to the right, under the seal's corner. A double jump stands on them: our
## man on the lowest, a rival man on the second and on the fourth, the third
## and the fifth bare for it to land on, and the fifth is the far rank, so a
## crown waits over it. Two dotted arcs show the hops. The jump is legal by
## versus/checkers_rules.gd: a man hops forward over a rival onto the empty
## square behind it, and again from where it lands.
##
## The go button is our man: the skin's own wooden disc in the card's colour,
## larger, lifted over its shadow, a chevron up the run where its face was.
## The rivals are the garden skin's rose men, worried.
##
## Everything is one mesh and nothing lives on the card.

const Board = preload("res://versus/checkers_board.gd")
const Rules = preload("res://versus/checkers_rules.gd")
const CheckersSkin = preload("res://versus/checkers_skin.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

## The row the card was drawn for (puzzle_card_2d.gd's CARD_H).
const H := 246.0
## A stone at H, how far each stands right of and above the one before, and
## the run's room from the card's right side and foot.
const CELL := 46.0
const STEP := Vector2(52.0, 30.0)
const RIGHT := 40.0
const FOOT := 9.0
## The run's stones, the two that hold a rival and the far rank's.
const STONES := 5
const RIVALS: Array[int] = [1, 3]
const FAR := 4
## The words end here: the lowest stone never starts left of it less a stone
## (it lies under the words, below where they end).
const WORDS_END := 196.0
## A stone: its corner, its lip and its shadow.
const ROUND := 0.14
const LIP := 0.08
const SHADOW := 0.2
## A man's seat on a stone, in cells, and the go man's: its size, its lift.
const MAN := 1.08
const GO_SIZE := 1.36
const GO_LIFT := 0.16
const GO_SHADOW := 0.26
## The crown: its size against a man's, how high it waits, and its glow.
const CROWN := 1.25
const CROWN_UP := 0.5
## The hop's dots: how many an arc, how high it rises in cells, their size.
const DOTS := 8
const ARC := 0.62
const DOT_R := 0.045
## The words' margin, their room and how far down they start.
const SIDE := 22.0
const WORDS := 215.0
const WORDS_TOP := 14.0

## The ground: cream over apricot, a pale pool behind the run.
const GROUND_TOP := Color("fdf3e3")
const GROUND_LOW := Color("f6dfc2")
const POOL := Color("fffaf0")
const BLURB := Color("7d6a52")

var _skin: RefCounted = CheckersSkin.named("garden")

## The picture's scale: the card's height sets it, its width caps it.
func _k() -> float:
	var wide := RIGHT + STEP.x * (STONES - 1) + CELL
	return minf(size.y / H, (size.x - WORDS_END) / wide)

## Stone `i`'s middle.
func _mid(i: int) -> Vector2:
	var k := _k()
	var last := Vector2(size.x - (RIGHT + CELL * 0.5) * k, size.y - (FOOT + CELL * 0.5) * k - STEP.y * (STONES - 1) * k)
	return last + Vector2(-STEP.x, STEP.y) * k * float(STONES - 1 - i)

## The jump shown is two legal hops: over a rival onto a bare stone, twice,
## ending on the far rank.
static func _legal() -> bool:
	return RIVALS == [1, 3] and FAR == 4 and STONES == 5

## Moves what `b` has taken since `first` from the origin to `at`, `grow`
## times its size.
static func _place(b: Face.Builder, first: int, at: Vector2, grow := 1.0) -> void:
	for i in range(first, b.verts.size()):
		b.verts[i] = b.verts[i] * grow + at

func _paint(b: Face.Builder) -> void:
	var k := _k()
	var s := CELL * k
	var first := b.verts.size()
	b.polygon(ground(), Color.WHITE)
	shade(b, first, GROUND_TOP, GROUND_LOW, 0.0, size.y)
	Scenery.soft_disc(b, _mid(2) + Vector2(s * 0.3, 0.0), s * 3.1, s * 1.9, Color(POOL, 0.55))
	for i in STONES:
		Scenery.soft_disc(b, _mid(i) + Vector2(0.0, s * 0.46), s * 0.54, s * 0.16, Color(Pal.TEXT, SHADOW))
	for i in STONES:
		_stone(b, _mid(i), s, i == FAR)
	if _legal() and not soon:
		_arc(b, _mid(0) - Vector2(0.0, s * GO_LIFT), _mid(2), s)
		_arc(b, _mid(2), _mid(FAR), s)
	for i in RIVALS:
		_man(b, _mid(i), s, 1, CheckersSkin.F_WORRY, Vector2i(-1, 1))
	# The crown waiting over the far rank.
	var crown := _mid(FAR) - Vector2(0.0, s * CROWN_UP)
	Scenery.soft_disc(b, crown, s * 0.5, s * 0.42, Color(Pal.SUN, 0.4))
	first = b.verts.size()
	_skin.build_crown(b, 0, s * MAN)
	_place(b, first, crown, CROWN)
	if soon:
		_man(b, _mid(0), s, 0, CheckersSkin.F_OPEN, Vector2i(1, -1))
	else:
		_go(b, _mid(0) - Vector2(0.0, s * GO_LIFT), s)

## One dark square of the board as a stone: its lip, its face and a lit
## inner tile; the far rank's wears a gold rim.
func _stone(b: Face.Builder, at: Vector2, s: float, far: bool) -> void:
	var corner := at - Vector2.ONE * s * 0.5
	b.polygon(Face.Builder.round_rect(corner + Vector2(0.0, s * LIP), Vector2.ONE * s, s * ROUND), Board.DARK_DEEP.darkened(0.08))
	b.polygon(Face.Builder.round_rect(corner, Vector2.ONE * s, s * ROUND), Board.DARK)
	b.polygon(Face.Builder.round_rect(corner + Vector2.ONE * s * 0.12, Vector2.ONE * s * 0.76, s * 0.1), Board.DARK_LIT)
	if far:
		b.stroke(Face.Builder.round_rect(corner + Vector2.ONE * s * 0.05, Vector2.ONE * s * 0.9, s * 0.11), s * 0.05, Color(Pal.SUN, 0.9), true)

## A man of the garden skin at `at`, over its own shadow.
func _man(b: Face.Builder, at: Vector2, s: float, side: int, face: int, gaze: Vector2i) -> void:
	var seat := s * MAN
	Scenery.soft_disc(b, at + Vector2(seat * 0.04, seat * 0.1), seat * 0.42, seat * 0.36, Color(Pal.TEXT, 0.24))
	var first := b.verts.size()
	_skin.build_base(b, Rules.MAN, side, seat)
	_skin.build(b, Rules.MAN, side, seat, face, gaze)
	_place(b, first, at)

## A hop from `a` to `z` as a dotted arc.
func _arc(b: Face.Builder, a: Vector2, z: Vector2, s: float) -> void:
	for i in range(1, DOTS):
		var f := float(i) / DOTS
		var p := a.lerp(z, f) - Vector2(0.0, sin(PI * f) * s * ARC)
		b.disc(p, s * DOT_R * 1.5, Color(Pal.TEXT, 0.16))
		b.disc(p, s * DOT_R, Color(Pal.SURFACE, 0.95))

## The go man about `at`: the skin's wooden disc in the card's colour,
## lifted over its shadow, with a chevron up the run.
func _go(b: Face.Builder, at: Vector2, s: float) -> void:
	var seat := s * MAN * GO_SIZE
	var r: float = seat * _skin.radius()
	var deep := colour.darkened(0.26)
	var line := colour.darkened(0.5)
	Scenery.soft_disc(b, at + Vector2(seat * 0.05, seat * 0.16 + s * GO_LIFT), seat * 0.44, seat * 0.3, Color(Pal.TEXT, GO_SHADOW))
	_skin._edge(b, at, r, seat, deep, line)
	b.disc(at, r, colour)
	_skin._top(b, at, r, seat, colour, deep, line)
	var dir := Vector2(STEP.x, -STEP.y).normalized()
	var side := dir.orthogonal()
	var h := r * 0.34
	b.stroke(PackedVector2Array([at - dir * h * 0.5 + side * h, at + dir * h * 0.6, at - dir * h * 0.5 - side * h]),
		r * 0.2, Pal.SURFACE)

func _lay() -> void:
	var words := _words(String(entry.get("title", "")), SIDE, size.y * 0.5, WORDS, Pal.TEXT, BLURB)
	words.position.y = roundf(WORDS_TOP * size.y / H)
