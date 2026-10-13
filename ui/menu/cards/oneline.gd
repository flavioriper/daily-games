extends "res://ui/menu/cards/card_face.gd"

## One Line's card: the stroke itself, part walked. It starts at a post under
## the name's first letter and runs along the foot of the card as the name's
## own underline, a boardwalk already laid, into a small figure of two
## triangles standing one on the other; the snail is out on the next line,
## climbing, with her plank and her shine behind her, and the three lines
## after it are still bare stone. The post she is heading for is the go
## button: a cap in the card's colour with a chevron on it. Every post whose
## lines are all walked has opened its daisy, as on the board, and from where
## she is the rest can still be walked in one go -- the rule, read once.
##
## The fords, the planks, the drums and the caps are the board's own, by its
## own measures (puzzles/oneline2d.gd), ported small because its builders
## are tied to the state it draws. Everything still is one mesh; the snail is
## the board's walker (ui/faces/snail_face.gd), idling, and the only thing
## here that lives beside the words.

const Board = preload("res://puzzles/oneline2d.gd")
const SnailFace = preload("res://ui/faces/snail_face.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

## The row the card was drawn for (puzzle_card_2d.gd's CARD_H); the figure
## grows with a taller one.
const H := 246.0
## The lattice at H: one step, square as the board's is, its first column in
## from the card's right edge and its first row up from the bottom.
const STEP := 68.0
const RIGHT := 46.0
const BASE := 40.0
## A post beside the board's (POST_R of a step): a card's seven want to be
## read from the page.
const POST := 1.12
## The posts, as [column from the right, row from the bottom]. The first is
## not on the lattice: it stands at the words' margin, so the line out of it
## is as long as the card is wide.
const POSTS := [Vector2i(-1, 0), Vector2i(2, 0), Vector2i(0, 0), Vector2i(1, 1), Vector2i(2, 1),
	Vector2i(0, 1), Vector2i(1, 2)]
## The lines in the order they are walked, each from the post it is left by.
## The first WALKED are planked, the next is the one she is on, LAID of the
## way along it, and the rest are stone.
const LINES := [[0, 1], [1, 2], [2, 3], [3, 5], [5, 6], [6, 4], [4, 3], [3, 1]]
const WALKED := 4
const LAID := 0.32
## The posts with no line left to walk, and the one she is heading for.
const SPENT := [0, 2, 5]
const GO_POST := 6
## The go cap's radius, and the cap's share of its drum (the board's is 0.6;
## this one carries a chevron).
const GO := 27.0
const GO_CAP := 0.78
## The snail's radius, and how far over the plank she rides, in radii.
const SNAIL := 22.0
const SNAIL_LIFT := 0.7
## The words' margin, the column they are never left with less than, and the
## air between them and the figure.
const TEXT_X := 24.0
const WORDS := 256.0
const AIR := 10.0

const DEW_TOP := Color("ecf4ee")
const DEW_LOW := Color("cde4dc")
const BLURB := Color("5f6f69")

func _k() -> float:
	return size.y / H

## The figure's own scale: the card's, unless that would leave the words
## less than their column.
func _ks() -> float:
	return minf(_k(), (size.x - TEXT_X - AIR - WORDS) / (RIGHT + STEP * 2.0 + STEP * Board.POST_R * POST))

func _step() -> float:
	return STEP * _ks()

## Where post `i` stands: on the lattice, which hangs from the card's right
## edge and stands on the line the stroke comes in along.
func _post(i: int) -> Vector2:
	var p: Vector2i = POSTS[i]
	var y0 := size.y - BASE * _k()
	if p.x < 0:
		return Vector2(TEXT_X + 14.0 * _k(), y0)
	var ks := _ks()
	return Vector2(size.x - (RIGHT + STEP * p.x) * ks, y0 - STEP * p.y * ks)

## Where the snail's plank ends, on the line she is walking.
func _head() -> Vector2:
	var line: Array = LINES[WALKED]
	return _post(line[0]).lerp(_post(line[1]), LAID)

func _paint(b: Face.Builder) -> void:
	var step := _step()
	var R := step * Board.POST_R * POST
	# The ground: a morning's dew, lighter where the figure stands, and the
	# lattice the figure is drawn on showing through as dots.
	var first := b.verts.size()
	b.polygon(ground(), Color.WHITE)
	shade(b, first, DEW_TOP, DEW_LOW, 0.0, size.y)
	var mid := (_post(3) + _post(GO_POST)) * 0.5
	Scenery.soft_disc(b, mid, step * 1.55, step * 1.4, Color(1.0, 1.0, 1.0, 0.4))
	for col in range(-1, 5):
		for row in range(-1, 4):
			var at := Vector2(size.x - (RIGHT + STEP * col) * _ks(), size.y - BASE * _k() - step * row)
			if at.x < RADIUS or at.x > size.x - 14.0 or at.y < 14.0 or at.y > size.y - 14.0:
				continue
			if at.distance_to(seal_centre()) < SEAL_R + 10.0 or at.x < size.x - step * 4.4:
				continue
			b.disc(at, step * 0.026, Color(Pal.TEXT, 0.13))
	# The fords: every line as stone over its shadow, lit along its upper
	# side, whether or not it has been walked.
	for line: Array in LINES:
		var a := _post(line[0])
		var z := _post(line[1])
		var cast: Vector2 = Board.FORD_SHADOW * step
		b.stroke(PackedVector2Array([a + cast, z + cast]), step * Board.LINE_W * 1.2, Color(Pal.TEXT, Board.FORD_SHADOW_A))
	for line: Array in LINES:
		var a := _post(line[0])
		var z := _post(line[1])
		b.stroke(PackedVector2Array([a, z]), step * Board.LINE_W, Pal.FORD_STONE)
		var lift := _up(a, z) * step * (Board.LINE_W * 0.5 - Board.CREST_W * 0.7)
		b.stroke(PackedVector2Array([a + lift, z + lift]), step * Board.CREST_W,
			Color(1.0, 1.0, 1.0, Board.CREST_A), false, false)
	# The boardwalk over them, as far as she has come, and her shine on the
	# last of it.
	for i in WALKED + 1:
		var a := _post(LINES[i][0])
		var z := _post(LINES[i][1])
		_plank(b, a, z, 1.0 if i < WALKED else LAID, i)
	var from := _post(LINES[WALKED][0])
	var head := _head()
	const PARTS := 5
	for k in PARTS:
		b.stroke(PackedVector2Array([from.lerp(head, 0.35 + 0.65 * k / PARTS), from.lerp(head, 0.35 + 0.65 * (k + 1) / PARTS)]),
			step * Board.PLANK_W * 0.28, Color(1.0, 1.0, 1.0, Board.SHEEN_A * float(k + 1) / PARTS), false, false)
	# The posts: a soft shadow, the drum, and the cap that says what is left
	# there -- teal with lines still to walk, pale under a daisy with none.
	for i in POSTS.size():
		var at := _post(i)
		var go := i == GO_POST and not soon
		var r := GO * _ks() if go else R
		Scenery.soft_disc(b, at + Vector2(0.05, 0.3) * r, 0.92 * r * Board.SHADOW_SPREAD, 0.8 * r * Board.SHADOW_SPREAD,
			Color(Pal.TEXT, Board.SHADOW_A))
		if go:
			_go(b, at, r)
			continue
		_drum(b, at, r, Pal.POST_STONE, Pal.POST_DEEP)
		var spent := SPENT.has(i)
		_cap(b, at, r, 0.6, Pal.POST_SPENT if spent else Pal.ACCENT)
		if spent:
			_daisy(b, at + Vector2(0.0, -0.04) * r, r * Board.DAISY_R, i)

## The side of a line that faces up the page, where its light falls.
func _up(a: Vector2, z: Vector2) -> Vector2:
	var along := (z - a).normalized()
	var up := Vector2(along.y, -along.x)
	return -up if up.y > 0.0 else up

## A plank from `from` toward `to`, laid `u` of the way: the deep wood, then
## the slats over it with a seam between each, every slat cut its own tone
## off a hash of its line and place (the board's _plank, at rest).
func _plank(b: Face.Builder, from: Vector2, to: Vector2, u: float, grain: int) -> void:
	var step := _step()
	var span := from.distance_to(to)
	if span <= 0.0 or u <= 0.0:
		return
	var along := (to - from) / span
	b.stroke(PackedVector2Array([from, from + along * span * u]), step * Board.PLANK_DEEP_W, Pal.WOOD_DEEP)
	var count := maxi(1, roundi(span / (step * Board.SLAT)))
	var cut := span / count
	var gap := step * Board.SEAM * 0.5
	var w := step * Board.PLANK_W
	var edge := _up(from, to) * w * 0.32
	for k in count:
		var start := k * cut
		var reach := minf((k + 1) * cut, span * u)
		if reach <= start:
			break
		var tone := _hash(grain * 31 + k) * 2.0 - 1.0
		var slat: Color = Pal.PLANK_LAID.lightened(tone * Board.SLAT_TONE) if tone > 0.0 \
			else Pal.PLANK_LAID.darkened(-tone * Board.SLAT_TONE)
		var a := from + along * (start + gap)
		var z := from + along * maxf(start + gap, reach - gap)
		b.stroke(PackedVector2Array([a, z]), w, slat, false, false)
		b.stroke(PackedVector2Array([a + edge, z + edge]), w * 0.22, Color(1.0, 1.0, 1.0, Board.SLAT_LIGHT_A), false, false)

## A fixed 0..1 hash of `k`, so the boardwalk is cut the same at every size.
func _hash(k: int) -> float:
	var h := (k * 374761393 + 668265263) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	return float(h % 1000) / 999.0

## A post's drum, its cut face lit on the upper rim.
func _drum(b: Face.Builder, at: Vector2, r: float, drum: Color, deep: Color) -> void:
	b.ellipse(at + Vector2(0.0, 0.1) * r, r, r, deep)
	b.ellipse(at, r, r, drum)
	b.stroke(Face.Builder.arc_points(at, 0.86 * r, PI * 1.05, PI * 1.7), 0.07 * r, Color(1.0, 1.0, 1.0, 0.3), false, false)

## The cap sat in it, `share` of the drum across, over its own lip.
func _cap(b: Face.Builder, at: Vector2, r: float, share: float, ink: Color) -> void:
	var centre := at + Vector2(0.0, -0.04) * r
	b.ellipse(centre + Vector2(0.0, 0.07) * r, (share + 0.04) * r, (share + 0.04) * r, ink.darkened(Board.CAP_LIP))
	b.ellipse(centre, share * r, share * r, ink)
	b.ellipse(at + Vector2(-0.2, -0.26) * r * share / 0.6, 0.26 * r * share / 0.6, 0.16 * r * share / 0.6, Color(1.0, 1.0, 1.0, 0.28))

## The go post: a drum and a cap in the card's colour, and the chevron.
func _go(b: Face.Builder, at: Vector2, r: float) -> void:
	_drum(b, at, r, colour.darkened(0.16), colour.darkened(0.34))
	_cap(b, at, r, GO_CAP, colour)
	var mid := at + Vector2(0.03, -0.04) * r
	var c := r * 0.32
	b.stroke(PackedVector2Array([mid + Vector2(-c * 0.55, -c), mid + Vector2(c * 0.55, 0.0),
		mid + Vector2(-c * 0.55, c)]), r * 0.2, Pal.SURFACE)

## A spent post's daisy, open (the board's _daisy at rest).
func _daisy(b: Face.Builder, at: Vector2, r: float, n: int) -> void:
	var turn := _hash(n) * TAU
	for p in Board.DAISY_PETALS:
		var a := turn + TAU * p / Board.DAISY_PETALS
		var dir := Vector2.from_angle(a)
		Board._oval(b, at + dir * r * 0.55, r * 0.36, r * 0.17, a, Pal.PETAL_EDGE)
		Board._oval(b, at + dir * r * 0.55, r * 0.32, r * 0.13, a, Pal.SURFACE)
	b.disc(at, r * 0.3, Pal.SUN_DEEP)
	b.disc(at + Vector2(0.0, -0.04) * r, r * 0.25, Pal.SUN_RAY)

func _lay() -> void:
	var k := _k()
	var ks := _ks()
	# The walker, at the end of her plank: turned the way she is going (the
	# drawing faces right, so a stroke heading left mirrors it) and leaning
	# with the line, as far as the board lets her (TILT_MAX).
	var line: Array = LINES[WALKED]
	var dir := _post(line[1]) - _post(line[0])
	var R := SNAIL * ks
	var snail := SnailFace.new()
	snail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_keep(snail)
	var seat := SnailFace.SEAT * R
	snail.size = Vector2(seat, seat)
	snail.pivot_offset = snail.size * 0.5
	snail.position = _head() - Vector2(0.0, R * SNAIL_LIFT) - snail.size * 0.5
	var facing := -1.0 if dir.x < 0.0 else 1.0
	snail.scale = Vector2(facing, 1.0)
	snail.rotation = clampf(atan2(dir.y, absf(dir.x)), -Board.TILT_MAX, Board.TILT_MAX) * facing
	snail.set_idle(true)
	# The words stand over the line the stroke comes in along.
	var foot := size.y - BASE * k
	var room := size.x - (RIGHT + STEP * 2.0 + STEP * Board.POST_R * POST) * ks - AIR - TEXT_X
	_words(String(entry.get("title", "")), TEXT_X, (foot - 16.0 * k) * 0.5 + 4.0, room, Pal.TEXT, BLURB)
