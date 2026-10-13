extends "res://ui/menu/cards/card_face.gd"

## Snooker's card: the baize is the paper, a light fresh green from edge to
## edge, and the card's bottom right corner is the table's: its wooden rail
## along the whole foot and up the right side as far as a middle pocket, the
## cushions inside them, and the corner pocket in brass and leather where
## they meet. A red lies a ball's width from that pocket, the blue, the pink
## and the black stand beyond it, and the cue comes in low from the left,
## under the words, to the cue ball: a thin cut that sends the red down the
## line to the pocket, worked out in code from where the two balls lie.
##
## The go button is the cue's shot: a broad sleeve in the card's colour round
## the cue behind its tip, lifted over a shadow, its chevron pointing at the
## cue ball. The name stands top left.
##
## Everything is one mesh in versus/snooker_table.gd's own colours; nothing
## lives on the card and it writes no string.

const Table = preload("res://versus/snooker_table.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

## The row the card was drawn for (puzzle_card_2d.gd's CARD_H) and the width
## its picture was laid at: a narrower card draws it smaller.
const H := 246.0
const W := 490.0
## How far the rails stand in from the card's edge (true pixels: the paper's
## corner does not scale), the wood's width and the cushion's, at H.
const IN := 7.0
const RAIL := 18.0
const CUSHION := 8.0
## How far short of a pocket a cushion is cut, and how far its nose is cut
## back along the jaw.
const JAW := 17.0
const JAW_CUT := 7.0
## The corner pocket: how far in from the rails' outer corner its drop sits,
## its radius and its brass cap's.
const POCKET_IN := 23.0
const POCKET_R := 15.0
const CAP_R := 19.0
## Where the side rail stops, down from the top at H, and the middle pocket
## that ends it.
const SIDE_TOP := 90.0
const MIDDLE_R := 12.0
const MIDDLE_CAP := 15.0
## A ball's radius, and the balls as [in from the right, down] at H: the cue
## ball, the red by the pocket, then the blue, the pink and the black.
const BALL := 15.0
const CUE_BALL := Vector2(172.0, 178.0)
const RED_AT := Vector2(86.0, 190.0)
const COLOURS := [[19, Vector2(146.0, 116.0)], [20, Vector2(94.0, 134.0)], [21, Vector2(60.0, 100.0)]]
## The cue: its length, its half widths at the tip and the butt, the gap to
## the ball, and how far it is lifted over its shadow.
const CUE_LEN := 250.0
const CUE_TIP := 3.4
const CUE_BUTT := 6.6
const CUE_GAP := 5.0
const CUE_LIFT := Vector2(4.0, 7.0)
## The go sleeve: its length and thickness, how far behind the tip it starts,
## and its shadow.
const GO_LEN := 54.0
const GO_THICK := 25.0
const GO_BACK := 9.0
const GO_SHADOW := 0.26
## The words' margin, their room and how far down they start.
const SIDE := 22.0
const WORDS := 215.0
const WORDS_TOP := 14.0

## The baize, light enough for ink; the lamp's pool on it; the cushions, a
## step lighter than the table's so they sit on a pale cloth; the blurb.
const BAIZE_TOP := Color("e6f3dd")
const BAIZE_LOW := Color("cbe6bf")
const POOL := Color("f3fae9")
const RUBBER := Color("5aa868")
const RUBBER_NOSE := Color("8fcc93")
const RUBBER_BACK := Color("3f8a50")
const SHADE := Color(0.08, 0.2, 0.12, 0.3)
const BLURB := Color("5a704f")

## The picture's scale: the card's height sets it, its width caps it.
func _k() -> float:
	return minf(size.y / H, size.x / W)

## A place given as [in from the right, down] at H: the picture hangs from
## the right side and stands on the foot.
func _at(p: Vector2) -> Vector2:
	var k := _k()
	return Vector2(size.x - p.x * k, size.y - (H - p.y) * k)

## The rails' outer line: the paper, IN inside its edge.
func _outer() -> PackedVector2Array:
	return Face.Builder.round_rect(Vector2(IN, IN), size - Vector2(IN, IN) * 2.0, RADIUS - IN)

## The corner pocket's drop.
func _pocket() -> Vector2:
	return size - Vector2.ONE * (IN + POCKET_IN * _k())

## The middle pocket's, where the side rail stops.
func _middle() -> Vector2:
	var k := _k()
	return Vector2(size.x - IN - (RAIL - 3.0) * k, _at(Vector2(0.0, SIDE_TOP)).y)

## Where the cue ball's middle is as it meets the red, for the red to leave
## along the line to the pocket: a ball's width back from it on that line.
func _ghost() -> Vector2:
	var red := _at(RED_AT)
	return red - (_pocket() - red).normalized() * BALL * 2.0 * _k()

func _paint(b: Face.Builder) -> void:
	var k := _k()
	var first := b.verts.size()
	b.polygon(ground(), Color.WHITE)
	shade(b, first, BAIZE_TOP, BAIZE_LOW, 0.0, size.y)
	Scenery.soft_disc(b, _at(Vector2(130.0, 150.0)), 150.0 * k, 92.0 * k, Color(POOL, 0.6))
	_rails(b, k)
	var cue := _at(CUE_BALL)
	var aim := (_ghost() - cue).normalized()
	# The shadows under every ball, then the balls.
	var places: Array = [[0, cue], [1, _at(RED_AT)]]
	for c: Array in COLOURS:
		places.append([c[0], _at(c[1])])
	for p: Array in places:
		Scenery.soft_disc(b, (p[1] as Vector2) + Vector2(3.0, 6.0) * k, BALL * k * 1.05, BALL * k * 0.8, SHADE)
	for p: Array in places:
		var id := int(p[0])
		_ball(b, Table.RED if id == 1 else Table.BALL[id], p[1], BALL * k, id == 21)
	_cue(b, cue, aim, k)

## The table's corner: the wood along the foot and up the right side, a lit
## line where it meets the cushions, the brass under the pockets, the
## cushions cut back at their jaws, and the pockets over them.
func _rails(b: Face.Builder, k: float) -> void:
	var outer := _outer()
	var t := RAIL * k
	var mid := _middle()
	var foot := Rect2(0.0, size.y - IN - t, size.x, IN + t)
	var side := Rect2(size.x - IN - t, mid.y, IN + t, size.y - mid.y)
	for band: Rect2 in [foot, side]:
		for piece: PackedVector2Array in Geometry2D.intersect_polygons(outer, _box(band)):
			b.polygon(piece, Table.WOOD)
	# The lit top of the wood, a hair inside its outer edge.
	var lit := Face.Builder.round_rect(Vector2.ONE * (IN + 3.0 * k), size - Vector2.ONE * (IN + 3.0 * k) * 2.0,
		RADIUS - IN - 3.0 * k)
	var foot_lit := Rect2(0.0, size.y - IN - t + 3.0 * k, size.x, t)
	var side_lit := Rect2(size.x - IN - t + 3.0 * k, mid.y, t, size.y - mid.y)
	for band: Rect2 in [foot_lit, side_lit]:
		for piece: PackedVector2Array in Geometry2D.intersect_polygons(lit, _box(band)):
			b.polygon(piece, Table.WOOD_LIT)
	# The table's inlaid diamonds along the foot rail.
	var inner := Vector2(size.x - IN - t, size.y - IN - t)
	var n := maxi(2, int((inner.x - 120.0 * k) / (150.0 * k)))
	for i in n:
		var x := lerpf(70.0 * k, inner.x - 90.0 * k, (i + 0.5) / n)
		var c := Vector2(x, size.y - IN - t * 0.5 + 1.0 * k)
		var d := 4.2 * k
		b.fan(PackedVector2Array([c + Vector2(0.0, -d), c + Vector2(d * 1.5, 0.0), c + Vector2(0.0, d), c + Vector2(-d * 1.5, 0.0)]),
			Color(Table.INLAY, 0.9))
	var hole := _pocket()
	b.disc(hole, CAP_R * k, Table.BRASS_DEEP)
	b.disc(hole + Vector2(-1.0, -1.4) * k, (CAP_R - 1.5) * k, Table.BRASS)
	b.disc(mid, MIDDLE_CAP * k, Table.BRASS_DEEP)
	b.disc(mid + Vector2(-1.0, -1.2) * k, (MIDDLE_CAP - 1.5) * k, Table.BRASS)
	# The cushions: the foot's runs in from the card's left edge, the side's
	# from the middle pocket, both cut back at the corner's jaws.
	var c := CUSHION * k
	var jaw := JAW * k
	var cut := JAW_CUT * k
	var foot_cushion := PackedVector2Array([Vector2(0.0, inner.y - c), Vector2(inner.x - c - jaw - cut, inner.y - c),
		Vector2(inner.x - c - jaw, inner.y), Vector2(0.0, inner.y)])
	for piece: PackedVector2Array in Geometry2D.intersect_polygons(ground(), foot_cushion):
		b.polygon(piece, RUBBER)
	b.stroke(PackedVector2Array([Vector2(IN + 6.0, inner.y - c), Vector2(inner.x - c - jaw - cut, inner.y - c)]),
		maxf(2.0, 2.4 * k), RUBBER_NOSE, false, false)
	b.stroke(PackedVector2Array([Vector2(IN + 6.0, inner.y), Vector2(inner.x - c - jaw, inner.y)]),
		maxf(1.5, 2.0 * k), RUBBER_BACK, false, false)
	var top := mid.y + (MIDDLE_R + 4.0) * k
	b.polygon(PackedVector2Array([Vector2(inner.x - c, top + cut), Vector2(inner.x, top),
		Vector2(inner.x, inner.y - c - jaw), Vector2(inner.x - c, inner.y - c - jaw - cut)]), RUBBER)
	b.stroke(PackedVector2Array([Vector2(inner.x - c, top + cut), Vector2(inner.x - c, inner.y - c - jaw - cut)]),
		maxf(2.0, 2.4 * k), RUBBER_NOSE, false, false)
	b.stroke(PackedVector2Array([Vector2(inner.x, top), Vector2(inner.x, inner.y - c - jaw)]),
		maxf(1.5, 2.0 * k), RUBBER_BACK, false, false)
	_drop(b, hole, POCKET_R * k, Vector2(1.0, 1.0).normalized())
	_drop(b, mid, MIDDLE_R * k, Vector2.RIGHT)

## A pocket's leather and its dark drop, deepening toward `out`.
func _drop(b: Face.Builder, at: Vector2, r: float, out: Vector2) -> void:
	b.disc(at, r + 1.6 * _k(), Table.LEATHER)
	b.disc(at, r, Table.HOLE)
	b.disc(at + out * r * 0.14, r * 0.78, Color("1a100a"))
	b.disc(at + out * r * 0.26, r * 0.52, Color("0f0905"))

static func _box(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])

## One ball as the table paints it: its shaded rim, its body, a lit patch,
## a glint and the cloth's bounce along its foot.
func _ball(b: Face.Builder, base: Color, at: Vector2, r: float, black: bool) -> void:
	var l := Table.LIGHT.normalized()
	b.disc(at, r, base.darkened(0.2 if black else 0.32))
	b.disc(at + l * r * 0.1, r * 0.88, base)
	b.disc(at + l * r * 0.3, r * 0.52, Color(base.lightened(0.12 if black else 0.16), 0.8))
	b.ellipse(at + l * r * 0.5, r * 0.2, r * 0.14, Color(1.0, 1.0, 1.0, 0.85))
	b.stroke(Face.Builder.arc_points(at, r * 0.86, PI * 0.15, PI * 0.75), r * 0.14,
		Color(base.lightened(0.25), 0.35), false, false)

## The cue laid along `aim` behind the cue ball at `ball`: its shadow, the
## chalked tip, the ferrule, the ash shaft and the ebony butt with its brass
## ring, as the table draws it; and the go sleeve round it behind the tip.
func _cue(b: Face.Builder, ball: Vector2, aim: Vector2, k: float) -> void:
	var n := Vector2(-aim.y, aim.x)
	var tip := ball - aim * (BALL + CUE_GAP) * k
	var len := CUE_LEN * k
	b.polygon(_taper(tip + CUE_LIFT * k, aim, n, 0.0, len, CUE_TIP * k, CUE_BUTT * k), Color(SHADE, 0.2))
	var parts := [
		[0.0, 0.016, Color("5f86b0")],
		[0.016, 0.045, Color("f3ead8")],
		[0.045, 0.66, Color("e3c18c")],
		[0.66, 0.69, Table.BRASS],
		[0.69, 1.0, Color("4a3024")],
	]
	for p: Array in parts:
		var a := float(p[0]) * len
		var e := float(p[1]) * len
		b.polygon(_taper(tip, aim, n, a, e, lerpf(CUE_TIP, CUE_BUTT, float(p[0])) * k, lerpf(CUE_TIP, CUE_BUTT, float(p[1])) * k), p[2])
	# A lit line along the shaft's upper side.
	b.stroke(PackedVector2Array([tip - aim * len * 0.06 - n * CUE_TIP * k * 0.45, tip - aim * len * 0.62 - n * CUE_BUTT * k * 0.4]),
		maxf(1.0, 1.3 * k), Color(1.0, 1.0, 1.0, 0.35), false, false)
	if soon:
		return
	# The go sleeve: a pill in the card's colour over its own shadow, a pale
	# band along its top and the chevron pointing down the aim.
	var mid := tip - aim * (GO_BACK + GO_LEN * 0.5) * k - Vector2(0.0, 2.0 * k)
	var half := (GO_LEN - GO_THICK) * 0.5 * k
	var line := PackedVector2Array([mid - aim * half, mid + aim * half])
	Scenery.soft_disc(b, mid + Vector2(2.0, 13.0) * k, GO_LEN * 0.56 * k, GO_THICK * 0.4 * k, Color(Pal.TEXT, GO_SHADOW))
	b.stroke(PackedVector2Array([line[0] + Vector2(0.0, 3.0 * k), line[1] + Vector2(0.0, 3.0 * k)]), GO_THICK * k, colour.darkened(0.28))
	b.stroke(line, GO_THICK * k, colour)
	b.stroke(PackedVector2Array([line[0] - n * GO_THICK * k * 0.2, line[1] - n * GO_THICK * k * 0.2]), GO_THICK * k * 0.3,
		Color(Pal.SURFACE, 0.18))
	var h := GO_THICK * k * 0.24
	b.stroke(PackedVector2Array([mid - aim * h * 0.55 - n * h, mid + aim * h * 0.55, mid - aim * h * 0.55 + n * h]),
		GO_THICK * k * 0.15, Pal.SURFACE)

## A length of the cue from `a` to `e` back from the tip, `wa` and `we` its
## half widths there.
static func _taper(tip: Vector2, aim: Vector2, n: Vector2, a: float, e: float, wa: float, we: float) -> PackedVector2Array:
	return PackedVector2Array([tip - aim * a - n * wa, tip - aim * a + n * wa, tip - aim * e + n * we, tip - aim * e - n * we])

func _lay() -> void:
	var words := _words(String(entry.get("title", "")), SIDE, size.y * 0.5, WORDS, Pal.TEXT, BLURB)
	words.position.y = roundf(WORDS_TOP * size.y / H)
