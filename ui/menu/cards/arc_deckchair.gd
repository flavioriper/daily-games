extends "res://ui/menu/cards/card_face.gd"

## Deckchair's card: a pale warm sand with two broad deckchair stripes
## leaning across it, and three short columns of the game's own cards
## against the right, each fanned down as the table fans them: a card face
## down, then the ones face up. One home pile stands over them, left of the
## seal's corner, with its ace laid. The picture is one legal move: the red
## six at the foot of the first column goes onto the black seven that ends
## the second (one rank under, the other colour: `Sim.fits`), and the seven
## wears the table's own ring for where a carried card may be set down.
##
## The go button is that six: the game's face, its rank and suit showing,
## in a border of the card's colour, larger, lifted off its column over a
## shadow and leaning, a tab on its side with the chevron toward the seven.
##
## Everything still is one mesh, the cards arcade/deckchair_art.gd's own
## meshes laid into it; each rank is a `draw_string` over it, as the table
## letters them.

const Art = preload("res://arcade/deckchair_art.gd")
const Sim = preload("res://arcade/deckchair_sim.gd")
const Scenery = preload("res://ui/flat/scenery.gd")
const CozyTheme = preload("res://ui/theme.gd")

## The row the card was drawn for (puzzle_card_2d.gd's CARD_H).
const H := 246.0
## How far the picture reaches in from the right at H, and where the words
## end: the scale is capped so the columns never start under them.
const REACH := 236.0
const WORDS_END := 244.0
## A card's width at H, the columns' pitch, their room from the right side
## and how far down their heads stand.
const CARD := 50.0
const PITCH := 58.0
const RIGHT := 14.0
const HEAD := 94.0
## The table's fan: how far down a card face down shows, and one face up,
## in cards' heights.
const FAN_DOWN := 0.12
const FAN_UP := 0.27
## The columns, left to right: how many lie face down, then the cards face
## up as [suit, rank] (suits in the sim's order: spade, heart, club,
## diamond; a rank counts from the ace at 0). The first column's last card
## is the one that moves, onto the end of column DST.
const COLUMNS := [
	[1, [[1, 5]]],
	[1, [[3, 7], [2, 6]]],
	[1, [[0, 12], [3, 11]]],
]
const SRC := 0
const DST := 1
## The home pile: its card, its width at H and its place as [in from the
## right, down] at H.
const HOME := [1, 0]
const HOME_W := 44.0
const HOME_AT := Vector2(124.0, 13.0)
## The go card: its width at H, its middle as [in from the right, down] at
## H, its lean, how thick its border is and how big its tab, in its widths.
const GO_W := 60.0
const GO_AT := Vector2(194.0, 181.0)
const GO_LEAN := -0.1
const GO_EDGE := 0.075
const GO_TAB := 0.23
const GO_SHADOW := 0.26
## The stripes: each [where it crosses the foot, in the card's width; how
## wide it is at H], and how far they lean.
const STRIPES := [[0.5, 46.0], [0.86, 26.0]]
const LEAN := 0.42
## The words' margin, their room and how far down they start.
const SIDE := 22.0
const WORDS := 215.0
const WORDS_TOP := 14.0

## The sand, the stripe on it, the light under the cards and the blurb's ink.
const SAND_TOP := Color("fcf5e6")
const SAND_LOW := Color("f4e4c8")
const STRIPE := Color("f7ecd5")
const POOL := Color("fffaf0")
const BLURB := Color("7d6c52")

func _k() -> float:
	return minf(size.y / H, maxf(size.x - WORDS_END, 1.0) / REACH)

## A place given as [in from the right, down] at H, on the card: the picture
## hangs from the right side and stands on the foot.
func _at(p: Vector2) -> Vector2:
	var k := _k()
	return Vector2(size.x - p.x * k, size.y - (H - p.y) * k)

static func _card(c: Array) -> int:
	return int(c[0]) * Sim.RANKS + int(c[1])

## The card that moves, and whether the game would take it where it goes.
func _mover() -> Array:
	var up: Array = COLUMNS[SRC][1]
	return up[up.size() - 1]

func _legal() -> bool:
	var pile: Array = []
	for c: Array in COLUMNS[DST][1]:
		pile.append(_card(c))
	return Sim.fits(_card(_mover()), pile)

func _lifted() -> bool:
	return not soon and _legal()

## A column's left side.
func _col_x(c: int) -> float:
	var k := _k()
	return size.x - (RIGHT + CARD + float(COLUMNS.size() - 1 - c) * PITCH) * k

## Every card that lies in a column, in the order they are laid, as
## [top left corner, face up, [suit, rank]]; the mover is left out while it
## is lifted.
func _laid() -> Array:
	var k := _k()
	var tall := CARD * Art.TALL * k
	var out := []
	for c in COLUMNS.size():
		var y := _at(Vector2(0.0, HEAD)).y
		for i in int(COLUMNS[c][0]):
			out.append([Vector2(_col_x(c), y), false, []])
			y += FAN_DOWN * tall
		var up: Array = COLUMNS[c][1]
		for i in up.size():
			if c == SRC and i == up.size() - 1 and _lifted():
				break
			out.append([Vector2(_col_x(c), y), true, up[i]])
			y += FAN_UP * tall
	return out

## Where the last card of column `c` lies.
func _end(c: int) -> Vector2:
	var k := _k()
	var tall := CARD * Art.TALL * k
	var up: Array = COLUMNS[c][1]
	return Vector2(_col_x(c), _at(Vector2(0.0, HEAD)).y + (float(COLUMNS[c][0]) * FAN_DOWN + float(up.size() - 1) * FAN_UP) * tall)

## The go card's own frame: its top left corner at the origin, leaning.
func _go_xf() -> Transform2D:
	var w := GO_W * _k()
	var turn := Transform2D(GO_LEAN, Vector2.ZERO)
	return Transform2D(GO_LEAN, _at(GO_AT) - turn * (Art.size(w) * 0.5))

func _paint(b: Face.Builder) -> void:
	var k := _k()
	var first := b.verts.size()
	b.polygon(ground(), Color.WHITE)
	shade(b, first, SAND_TOP, SAND_LOW, 0.0, size.y)
	_stripes(b, k)
	var w := CARD * k
	var mid := Vector2(_col_x(1) + w * 0.5, _at(Vector2(0.0, HEAD + 60.0)).y)
	Scenery.soft_disc(b, mid, 130.0 * k, 92.0 * k, Color(POOL, 0.55))
	# The home pile, its ace laid.
	b.append(Art.face(int(HOME[0]), HOME_W * k), Transform2D(0.0, _at(HOME_AT)))
	for c: Array in _laid():
		var at: Vector2 = c[0]
		b.append(Art.face(int(c[2][0]), w) if c[1] else Art.back(w), Transform2D(0.0, at))
	if not _lifted():
		return
	b.append(Art.halo(w), Transform2D(0.0, _end(DST)))
	_go(b, k)

## Two broad stripes of the chair's canvas leaning across the sand, kept
## inside the paper.
func _stripes(b: Face.Builder, k: float) -> void:
	for s: Array in STRIPES:
		var x := size.x * float(s[0])
		var half := float(s[1]) * k * 0.5
		var run := size.y * LEAN
		var band := PackedVector2Array([Vector2(x - half + run, 0.0), Vector2(x + half + run, 0.0),
			Vector2(x + half, size.y), Vector2(x - half, size.y)])
		for part: PackedVector2Array in Geometry2D.intersect_polygons(band, ground()):
			b.polygon(part, Color(STRIPE, 0.75))

## The go card: the mover's own face in a border of the card's colour,
## lifted over its shadow, with the chevron on a tab at its side.
func _go(b: Face.Builder, k: float) -> void:
	var w := GO_W * k
	var xf := _go_xf()
	var sz := Art.size(w)
	var edge := GO_EDGE * w
	Scenery.soft_disc(b, xf * (sz * 0.5) + Vector2(0.0, sz.y * 0.5 + 4.0 * k), sz.x * 0.62, sz.y * 0.16, Color(Pal.TEXT, GO_SHADOW))
	var rim := Face.Builder.round_rect(-Vector2.ONE * edge, sz + Vector2.ONE * edge * 2.0, 0.09 * w + edge)
	b.polygon(xf * Face.Builder.round_rect(Vector2(-edge, -edge + 0.05 * w), sz + Vector2.ONE * edge * 2.0, 0.09 * w + edge), colour.darkened(0.26))
	b.polygon(xf * rim, colour)
	b.append(Art.face(int(_mover()[0]), w), xf)
	# The tab, on the side the card goes to.
	var at := xf * Vector2(sz.x + edge * 0.4, sz.y * 0.6)
	var r := GO_TAB * w
	b.disc(at + Vector2(0.0, 0.035 * w), r, colour.darkened(0.26))
	b.disc(at, r, colour)
	var h := r * 0.5
	var right := xf.basis_xform(Vector2.RIGHT)
	var down := xf.basis_xform(Vector2.DOWN)
	b.stroke(PackedVector2Array([at - right * h * 0.55 - down * h, at + right * h * 0.55, at - right * h * 0.55 + down * h]),
		r * 0.32, Pal.SURFACE)

## A rank lettered on a card `w` wide whose frame is `xf`, where the table
## letters it.
func _rank(font: Font, xf: Transform2D, w: float, c: Array) -> void:
	var px := int(w * 0.31)
	if px <= 0:
		return
	draw_set_transform_matrix(xf)
	draw_string(font, Vector2(0.11, 0.325) * w, Art.RANKS[int(c[1])], HORIZONTAL_ALIGNMENT_LEFT, -1.0, px, Art.ink(_card(c)))

func _draw() -> void:
	super()
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var k := _k()
	var font: Font = CozyTheme.display(700)
	_rank(font, Transform2D(0.0, _at(HOME_AT)), HOME_W * k, HOME)
	for c: Array in _laid():
		if c[1]:
			_rank(font, Transform2D(0.0, c[0]), CARD * k, c[2])
	if _lifted():
		_rank(font, _go_xf(), GO_W * k, _mover())
	draw_set_transform_matrix(Transform2D.IDENTITY)

func _lay() -> void:
	var words := _words(String(entry.get("title", "")), SIDE, size.y * 0.5, WORDS, Pal.TEXT, BLURB)
	words.position.y = roundf(WORDS_TOP * _k())
