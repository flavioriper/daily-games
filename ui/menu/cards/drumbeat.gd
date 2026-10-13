extends "res://ui/menu/cards/card_face.gd"

## Drumbeat's card: the board's one road on a warm evening. The road comes in
## from the card's right edge under the seal's corner and ends, round, at the
## ring: three of the board's berries ride it right to left, the red one
## already in the ring, each over its drum's mark on the strip below (dot,
## triangle, square), as the board names a drum twice. Under the road stand
## Hard's three drums along the foot -- the big drum under the ring, the hand
## drum and the tongue drum -- the board's own drawings with their faces.
##
## The go button is the drum the berry in the ring wants: the big drum in
## the card's colour, larger than its siblings, lifted over its shadow, the
## board's glow behind it and a chevron on its belly where the others carry a
## face. The name stands top left.
##
## Everything is one mesh: the berries and the two plain drums are
## ui/faces/drumbeat_parts.gd's cached meshes laid into it, and nothing lives
## on the card.

const Parts = preload("res://ui/faces/drumbeat_parts.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

## The row the card was drawn for (puzzle_card_2d.gd's CARD_H).
const H := 246.0
## The picture's width at H and the room the words keep on its left: the
## scale never lets the first run into the second.
const PICTURE := 240.0
const WORDS_END := 250.0
## The road, at H: how far in from the right its round end stands, its top
## rail, the track's top and floor, and the foot of the strip of marks.
const ROAD_LEFT := 228.0
const RAIL_Y := 72.0
const TRACK_Y := 79.0
const FLOOR_Y := 135.0
const STRIP_Y := 157.0
const ROAD_ROUND := 20.0
## The ring: how far in from the right, and its radius; a berry's radius and
## how far apart they ride; a mark's size.
const RING_IN := 194.0
const RING_R := 26.0
const NOTE_R := 21.0
const NOTE_GAP := 66.0
const MARK := 6.5
## The berries from the ring outward, by drum kind (drumbeat2d.gd's
## DRUM_KINDS on Hard: big 0, hand 1, tongue 3).
const NOTES := [0, 3, 1]
## The drums: [kind, how far in from the right its middle is, its radius].
## The first is the go drum.
const GO_IN := 194.0
const GO_R := 43.0
const GO_LIFT := 4.0
const DRUMS := [[1, 110.0, 30.0], [3, 47.0, 30.0]]
const FOOT := 10.0
## The words' margin, their room and how far down they start.
const SIDE := 22.0
const WORDS := 215.0
const WORDS_TOP := 14.0

## The evening: apricot over a deeper apricot, the road's wood a shade
## lighter than the board's so it does not sit heavy on a light card.
const SKY_TOP := Color("fdf0de")
const SKY_LOW := Color("f8d9b6")
const GLOW := Color("ffd27a")
const WOOD := Color("9a6a45")
const WOOD_HI := Color("b98a61")
const WOOD_DEEP := Color("6f4a31")
const TRACK := Color("5e4230")
const BLURB := Color("86694c")

func _k() -> float:
	return minf(size.y / H, maxf(0.6, (size.x - WORDS_END) / PICTURE))

## A place given as [in from the right, down the card at H]: anchored to the
## card's right side and its foot.
func _at(xr: float, y: float) -> Vector2:
	var k := _k()
	return Vector2(size.x - xr * k, size.y - (H - y) * k)

func _paint(b: Face.Builder) -> void:
	var k := _k()
	var first := b.verts.size()
	b.polygon(ground(), Color.WHITE)
	shade(b, first, SKY_TOP, SKY_LOW, 0.0, size.y)
	# Two lanterns' worth of light and no lantern.
	Scenery.soft_disc(b, _at(150.0, 96.0), 132.0 * k, 74.0 * k, Color(GLOW, 0.3))
	Scenery.soft_disc(b, _at(GO_IN, 194.0), 86.0 * k, 40.0 * k, Color(GLOW, 0.28))
	_road(b, k)
	# The plain drums, then the go drum in front of them.
	for d: Array in DRUMS:
		_plain(b, int(d[0]), float(d[1]), float(d[2]), k)
	if soon:
		_plain(b, 0, GO_IN, GO_R * 0.86, k)
	else:
		_go(b, _at(GO_IN, H - FOOT - GO_LIFT), GO_R * k)
	# The berries last, over the ring.
	for i in NOTES.size():
		var c := _at(RING_IN - i * NOTE_GAP, (TRACK_Y + FLOOR_Y) * 0.5)
		b.append(Parts.berry(int(NOTES[i]), NOTE_R * k, Parts.Mood.JOY if i == 0 else Parts.Mood.HAPPY),
			Transform2D(0.0, c))

## The road from its round end to the paper's right edge: the plank, the
## track, the strip of marks under it, and the ring with its post.
func _road(b: Face.Builder, k: float) -> void:
	var left := _at(ROAD_LEFT, 0.0).x
	var right := size.x - EDGE
	Scenery.soft_disc(b, Vector2((left + right) * 0.5 - 2.0 * k, _at(0.0, STRIP_Y + 3.0).y), (right - left) * 0.5 - 6.0 * k, 9.0 * k,
		Color(Pal.TEXT, 0.16))
	b.polygon(_slab(left, right, _at(0.0, RAIL_Y).y, _at(0.0, STRIP_Y).y, ROAD_ROUND * k), WOOD_DEEP)
	b.polygon(_slab(left + 5.0 * k, right, _at(0.0, TRACK_Y).y, _at(0.0, FLOOR_Y).y, (ROAD_ROUND - 6.0) * k), TRACK)
	# The rail's lit top, clear of the round corner.
	b.stroke(PackedVector2Array([Vector2(left + ROAD_ROUND * k, _at(0.0, RAIL_Y + 3.0).y),
		Vector2(right - 2.0 * k, _at(0.0, RAIL_Y + 3.0).y)]), 3.0 * k, WOOD_HI, false, false)
	b.stroke(PackedVector2Array([Vector2(left + 8.0 * k, _at(0.0, FLOOR_Y + 2.5).y),
		Vector2(right, _at(0.0, FLOOR_Y + 2.5).y)]), 5.0 * k, WOOD, false, false)
	var ring := _at(RING_IN, (TRACK_Y + FLOOR_Y) * 0.5)
	b.stroke(PackedVector2Array([Vector2(ring.x, _at(0.0, FLOOR_Y).y), Vector2(ring.x, _at(0.0, STRIP_Y - 4.0).y)]),
		3.0 * k, Color(Parts.CREAM, 0.5))
	b.disc(ring, RING_R * k, Color(Parts.CREAM, 0.14))
	b.stroke(Face.Builder.ring(ring, RING_R * k, RING_R * k), 4.0 * k, Parts.CREAM, true)
	# Each berry's drum named again under it; the ring's own is its post.
	for i in range(1, NOTES.size()):
		_mark(b, int(NOTES[i]), _at(RING_IN - i * NOTE_GAP, (FLOOR_Y + STRIP_Y) * 0.5 + 2.0), MARK * k,
			Parts.LANE_BODY[int(NOTES[i])])

## A slab from `left` to `right` whose left corners are round and whose
## right side is cut square, where it leaves the paper.
static func _slab(left: float, right: float, top: float, bottom: float, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array([Vector2(right, top)])
	pts.append_array(Face.Builder.arc_points(Vector2(left + r, top + r), r, -PI * 0.5, -PI))
	pts.append_array(Face.Builder.arc_points(Vector2(left + r, bottom - r), r, PI, PI * 0.5))
	pts.append(Vector2(right, bottom))
	return pts

## A drum's mark, as drumbeat2d.gd's `_mark` draws it: a dot for the big
## drum, a triangle for the hand drum, a square for the tongue drum.
static func _mark(b: Face.Builder, kind: int, c: Vector2, s: float, col: Color) -> void:
	match kind:
		0:
			b.disc(c, s * 0.82, col)
		1:
			b.polygon(PackedVector2Array([c + Vector2(0.0, -s), c + Vector2(s * 0.95, s * 0.72),
				c + Vector2(-s * 0.95, s * 0.72)]), col)
		_:
			b.polygon(Face.Builder.round_rect(c - Vector2.ONE * s * 0.76, Vector2.ONE * s * 1.52, s * 0.1), col)

## One of the board's drums, as it stands, its mark on its skin.
func _plain(b: Face.Builder, kind: int, xr: float, r: float, k: float) -> void:
	var foot := _at(xr, H - FOOT)
	b.append(Parts.band_drum(kind, r * k), Transform2D(0.0, foot))
	var skin := foot + Vector2(0.0, Parts.skin_y(kind, r * k) - (r * k * 0.2 if kind == 3 else 0.0))
	var s := r * k * 0.26
	match kind:
		0:
			b.ellipse(skin, s * 0.82, s * 0.26, Color(Parts.LANE_BODY[kind], 0.9))
		1:
			b.polygon(PackedVector2Array([skin + Vector2(0.0, -s * 0.3), skin + Vector2(s * 0.95, s * 0.22),
				skin + Vector2(-s * 0.95, s * 0.22)]), Color(Parts.LANE_BODY[kind], 0.9))

## The go drum, its foot on `foot`: the big drum's barrel, tacks and skin in
## the card's colour, the board's glow behind it and a chevron on its belly.
func _go(b: Face.Builder, foot: Vector2, r: float) -> void:
	var top := Parts.skin_y(0, r)
	var deep := colour.darkened(0.28)
	Scenery.soft_disc(b, foot + Vector2(0.0, top * 0.62), r * 1.3, r * 0.7, Color(Parts.LANE_BODY[0], 0.22))
	Scenery.soft_disc(b, foot + Vector2(0.0, GO_LIFT * _k() + r * 0.02), r * 1.06, r * 0.2, Color(Pal.TEXT, 0.24))
	b.polygon(_moved(Parts._barrel(r * 0.98, r * 0.86, top, -r * 0.06), foot), deep)
	b.polygon(_moved(Parts._barrel(r * 0.9, r * 0.8, top, -r * 0.1), foot), colour)
	b.stroke(PackedVector2Array([foot + Vector2(-r * 0.6, top + r * 0.2), foot + Vector2(-r * 0.7, -r * 0.3)]), r * 0.07,
		Color(colour.lightened(0.35), 0.7))
	for i in 7:
		var x := lerpf(-r * 0.78, r * 0.78, i / 6.0)
		var y := top + r * 0.12 + absf(x) * 0.05
		b.disc(foot + Vector2(x, y), r * 0.045, Parts.BRASS_DEEP)
		b.disc(foot + Vector2(x, y - r * 0.01), r * 0.035, Parts.BRASS)
	var skin := foot + Vector2(0.0, top)
	b.ellipse(skin, r * 0.9 * 1.06, r * 0.26 * 1.18, deep)
	b.ellipse(skin, r * 0.9, r * 0.26, Parts.SKIN_DEEP)
	b.ellipse(skin + Vector2(-r * 0.036, -r * 0.016), r * 0.846, r * 0.229, Parts.SKIN)
	b.ellipse(skin + Vector2(-r * 0.36, -r * 0.078), r * 0.216, r * 0.052, Color(1, 1, 1, 0.4))
	b.ellipse(skin, r * 0.21, r * 0.066, Color(Parts.LANE_BODY[0], 0.9))
	var at := foot + Vector2(0.0, top + r * 0.64)
	var h := r * 0.2
	b.stroke(PackedVector2Array([at + Vector2(-h * 0.55, -h), at + Vector2(h * 0.55, 0.0), at + Vector2(-h * 0.55, h)]),
		r * 0.13, Pal.SURFACE)

static func _moved(pts: PackedVector2Array, by: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(p + by)
	return out

func _lay() -> void:
	var words := _words(String(entry.get("title", "")), SIDE, size.y * 0.5, WORDS, Pal.TEXT, BLURB)
	words.position.y = roundf(WORDS_TOP * size.y / H)
