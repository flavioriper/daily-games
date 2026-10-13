extends "res://ui/menu/cards/card_face.gd"

## Marigold's card: the board's dusk over its pond, kept light. A pale lilac
## sky falls to a peach horizon behind one soft range, the pond runs from
## there to a low green bank along the foot, and the picture is one shot.
## The family's sun stands in the sky left of the seal's corner, its spout
## turned down the aim; the board's dotted guide leaves the spout, glances
## off a violet and then a bluebell -- both stand open, since a bud a seed
## touches blooms -- and comes down into the pot on the bank, where a seed
## caught comes back. Two marigolds, the ones the garden asks for, are still
## shut at either end of the pond. Every bounce is a true mirror about the
## bud's own edge, worked out in code from the aim, and the pot stands where
## that path lands.
##
## The go button is the pot: the board's pot redrawn in the card's colour,
## larger, lifted over its shadow, a chevron on its belly and the seed just
## over its mouth. The name stands top left over the sky.
##
## Everything is one mesh, the flowers, the sun and the seed
## ui/faces/marigold_parts.gd's own builders. Nothing lives on the card and
## it writes no string.

const Parts = preload("res://ui/faces/marigold_parts.gd")
const State = preload("res://puzzles/marigold_state.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

## The row the card was drawn for (puzzle_card_2d.gd's CARD_H).
const H := 246.0
## Where things stand, as [how far in from the card's right side, how far
## down], at H: the sun, the two buds the seed glances off, the two
## marigolds still shut.
const SUN := Vector2(118.0, 40.0)
const FIRST := Vector2(160.0, 145.0)
const SECOND := Vector2(47.5, 140.0)
const SHUT: Array[Vector2] = [Vector2(300.0, 170.0), Vector2(220.0, 180.0)]
## The sun's radius, a shut bud's, an open bloom's (its petals reach about
## 1.6 of it), and the circle a seed bounces off, all at H.
const SUN_R := 19.0
const BUD := 22.0
const BLOOM := 17.0
const BOUNCE := 26.0
## The aim, in degrees clockwise from the card's right: the one angle whose
## two bounces come down between the bluebell and the first bloom. Half a
## degree either way misses the second bud; `_path` falls back to a plain
## drop if it ever does.
const AIM := 102.5
## The pot: its rim's height on the card and its width at H, how far the go
## pot is lifted, and the plain pot's width when the card is not open yet.
const POT_Y := 194.0
const POT_W := 66.0
const POT_LIFT := 4.0
const POT_PLAIN := 54.0
## The guide's dots: how far apart, how big, and the room left clear round
## the words.
const DOT_GAP := 11.0
const DOT_R := 2.7
const WORDS_CLEAR := Vector2(250.0, 112.0)
## The horizon and the bank's top, at H.
const HORIZON := 112.0
const BANK_Y := 216.0
## The words' margin, their room and how far down they start.
const SIDE := 22.0
const WORDS := 215.0
const WORDS_TOP := 14.0

## The dusk, lightened from the board's: sky, horizon, the far range, the
## pond from its far shore to the foot, and the blurb's ink.
const SKY_TOP := Color("e6e2f7")
const SKY_LOW := Color("fbe8dc")
const RANGE := Color("dcd2ec")
const POND_TOP := Color("d3e3f5")
const POND_LOW := Color("b6cfec")
const BLURB := Color("6a6788")
## The pond's glints, as [x in the card's width, y at H, length at H].
const GLINTS := [
	[0.07, 150.0, 26.0],
	[0.22, 196.0, 20.0],
	[0.47, 134.0, 18.0],
	[0.93, 190.0, 20.0],
]

func _k() -> float:
	return size.y / H

## A place given as [in from the right, down] at H, on the card.
func _at(p: Vector2) -> Vector2:
	return Vector2(size.x - p.x * _k(), p.y * _k())

## The shot: where the seed leaves the spout, where it meets each bud and
## where it crosses the pot's rim, with the direction it comes down in.
## A bounce mirrors the flight about the line from the bud's middle to the
## point touched, as the board's seed does.
func _path() -> Dictionary:
	var k := _k()
	var d := Vector2.from_angle(deg_to_rad(AIM))
	var from := _at(SUN) + d * SUN_R * k * (State.MUZZLE / 3.4)
	var pts := PackedVector2Array([from])
	var p := _at(SUN)
	for bud: Vector2 in [FIRST, SECOND]:
		var c := _at(bud)
		var t := _meet(p, d, c, BOUNCE * k)
		if t < 0.0:
			break
		p += d * t
		pts.append(p)
		d = d.bounce((p - c).normalized())
	var rim := (POT_Y - POT_LIFT) * k
	if d.y < 0.2:
		d = Vector2(0.0, 1.0)
	var land := p + d * ((rim - p.y) / d.y)
	land.x = clampf(land.x, POT_W * k, size.x - POT_W * k)
	pts.append(land)
	return {"pts": pts, "dir": (land - p).normalized(), "aim": Vector2.from_angle(deg_to_rad(AIM))}

## How far along `d` from `p` the circle about `c` is met, or -1.
static func _meet(p: Vector2, d: Vector2, c: Vector2, r: float) -> float:
	var o := p - c
	var half := o.dot(d)
	var disc := half * half - (o.length_squared() - r * r)
	if disc < 0.0:
		return -1.0
	var t := -half - sqrt(disc)
	return t if t > 0.001 else -1.0

func _paint(b: Face.Builder) -> void:
	var k := _k()
	var paper := ground()
	# The pond under everything, then the sky over its top, the range on the
	# horizon and the bank along the foot, each cut to the paper.
	var first := b.verts.size()
	b.polygon(paper, Color.WHITE)
	shade(b, first, POND_TOP, POND_LOW, HORIZON * k, BANK_Y * k)
	first = b.verts.size()
	_cut(b, paper, PackedVector2Array([Vector2(0.0, 0.0), Vector2(size.x, 0.0), Vector2(size.x, HORIZON * k),
		Vector2(0.0, HORIZON * k)]), Color.WHITE)
	shade(b, first, SKY_TOP, SKY_LOW, 0.0, HORIZON * k)
	_cut(b, paper, _range(k), RANGE)
	# The far shore's own reflection: a pale band where the pond begins.
	b.fan(PackedVector2Array([Vector2(EDGE, HORIZON * k), Vector2(size.x - EDGE, HORIZON * k),
		Vector2(size.x - EDGE, (HORIZON + 5.0) * k), Vector2(EDGE, (HORIZON + 5.0) * k)]), Color(Pal.MG_SHINE, 0.6))
	for glint in GLINTS:
		_glint(b, Vector2(size.x * float(glint[0]), float(glint[1]) * k), float(glint[2]) * k, k)
	_cut(b, paper, _bank(k, -3.0), Pal.MG_BANK_DEEP.lerp(Pal.MG_BANK, 0.35))
	_cut(b, paper, _bank(k, 0.0), Pal.MG_BANK.lerp(Pal.SURFACE, 0.22))

	var shot := _path()
	var pts: PackedVector2Array = shot.pts
	# The flowers: the two the seed has touched open, the marigolds shut.
	for at: Vector2 in SHUT:
		Parts.bud(b, _at(at), BUD * k, State.ORANGE)
	Parts.bloom(b, _at(FIRST), BLOOM * k, State.PURPLE, 1.0)
	Parts.bloom(b, _at(SECOND), BLOOM * k, State.BLUE, 1.0)
	_dots(b, pts, k)
	_sun(b, shot.aim, k)
	var land := pts[pts.size() - 1]
	if soon:
		var plain := Face.Builder.new()
		Parts.pot(plain, POT_PLAIN * k)
		b.append(plain.mesh(), Transform2D(0.0, Vector2(land.x, POT_Y * k)))
		return
	_go(b, land, k)
	var dir: Vector2 = shot.dir
	Parts.kernel(b, land - dir * 15.0 * k, 5.2 * k, dir.angle())

## `shape` where it lies on the paper, in `colour`.
func _cut(b: Face.Builder, paper: PackedVector2Array, shape: PackedVector2Array, colour: Color) -> void:
	for piece: PackedVector2Array in Geometry2D.intersect_polygons(paper, shape):
		b.polygon(piece, colour)

## The far range: low humps standing on the horizon, highest behind the
## picture and sunk where the words are.
func _range(k: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var steps := 36
	for i in steps + 1:
		var x := size.x * float(i) / float(steps)
		var from_right := (size.x - x) / k
		var rise := 9.0 + 15.0 * exp(-pow((from_right - 150.0) / 120.0, 2.0)) + 10.0 * exp(-pow((from_right - 330.0) / 70.0, 2.0))
		rise += 3.0 * sin(from_right * 0.045)
		pts.append(Vector2(x, (HORIZON - rise) * k))
	pts.append(Vector2(size.x, HORIZON * k))
	pts.append(Vector2(0.0, HORIZON * k))
	return pts

## The bank along the foot, its top a slow swell, `lift` higher or lower.
func _bank(k: float, lift: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var steps := 28
	for i in steps + 1:
		var x := size.x * float(i) / float(steps)
		pts.append(Vector2(x, (BANK_Y + lift + 3.0 * sin((size.x - x) / k * 0.021 + 0.6)) * k))
	pts.append(Vector2(size.x, size.y))
	pts.append(Vector2(0.0, size.y))
	return pts

## A glint on the pond: a pale dash and a shorter one under it.
func _glint(b: Face.Builder, at: Vector2, length: float, k: float) -> void:
	b.stroke(PackedVector2Array([at, at + Vector2(length, 0.0)]), 2.6 * k, Color(Pal.MG_SHINE, 0.8))
	b.stroke(PackedVector2Array([at + Vector2(length * 0.35, 7.0 * k), at + Vector2(length * 0.9, 7.0 * k)]), 2.2 * k,
		Color(Pal.MG_SHINE, 0.55))

## The guide: the board's dots along the shot, each on a faint rim so it
## reads on the pale pond, none under the words and none in the pot.
func _dots(b: Face.Builder, pts: PackedVector2Array, k: float) -> void:
	var gap := DOT_GAP * k
	var total := 0.0
	for i in range(1, pts.size()):
		total += pts[i].distance_to(pts[i - 1])
	var stop := total - 24.0 * k
	var walked := 0.0
	var next := gap * 0.5
	for i in range(1, pts.size()):
		var a := pts[i - 1]
		var z := pts[i]
		var seg := a.distance_to(z)
		while next <= walked + seg and next <= stop:
			var at := a.lerp(z, (next - walked) / maxf(seg, 0.001))
			next += gap
			if at.x < WORDS_CLEAR.x and at.y < WORDS_CLEAR.y * k:
				continue
			b.disc(at, (DOT_R + 1.1) * k, Color(Pal.MG_BLUE_DEEP, 0.3))
			b.disc(at, DOT_R * k, Pal.GF_GUIDE)
		walked += seg

## The sun as the board stands it: rays, the spout turned down the aim with
## nothing in it (the seed has flown), the body looking the same way.
func _sun(b: Face.Builder, aim: Vector2, k: float) -> void:
	var at := _at(SUN)
	var R := SUN_R * k
	Scenery.soft_disc(b, at, R * 2.0, R * 2.0, Color(Pal.SUN_RAY, 0.32))
	var part := Face.Builder.new()
	Parts.sun_rays(part, R)
	b.append(part.mesh(), Transform2D(0.0, at))
	part = Face.Builder.new()
	Parts.spout(part, R, false, State.MUZZLE / 3.4)
	b.append(part.mesh(), Transform2D(aim.angle(), at))
	part = Face.Builder.new()
	Parts.sun_body(part, R, 1.0, Face.Expr.HAPPY, aim * 0.07)
	b.append(part.mesh(), Transform2D(0.0, at))

## The go pot, its rim's middle at `rim`: Parts.pot's shape in the card's
## colour, lifted over its shadow on the bank, with a chevron on its belly.
func _go(b: Face.Builder, rim: Vector2, k: float) -> void:
	var w := POT_W * k
	var h := w * 0.62
	var lip := w * 0.17
	var foot := w * 0.36
	var deep := colour.darkened(0.26)
	var lit := colour.lerp(Pal.SURFACE, 0.34)
	Scenery.soft_disc(b, rim + Vector2(0.0, h + POT_LIFT * k), w * 0.56, lip * 0.5, Color(Pal.TEXT, 0.3))
	b.fan(PackedVector2Array([rim + Vector2(-w * 0.44, lip * 0.5), rim + Vector2(w * 0.44, lip * 0.5),
		rim + Vector2(foot, h), rim + Vector2(-foot, h)]), colour)
	b.fan(PackedVector2Array([rim + Vector2(w * 0.2, lip * 0.5), rim + Vector2(w * 0.44, lip * 0.5),
		rim + Vector2(foot, h), rim + Vector2(foot * 0.5, h)]), Color(deep, 0.75))
	b.fan(PackedVector2Array([rim + Vector2(-w * 0.35, lip * 0.9), rim + Vector2(-w * 0.26, lip * 0.9),
		rim + Vector2(-foot * 0.68, h * 0.9), rim + Vector2(-foot * 0.84, h * 0.9)]), Color(lit, 0.7))
	# The rim and the soil in its mouth.
	b.fan(Face.Builder.round_rect(rim + Vector2(-w * 0.5, -lip * 0.5), Vector2(w, lip), lip * 0.45), lit)
	b.fan(Face.Builder.round_rect(rim + Vector2(-w * 0.5, lip * 0.08), Vector2(w, lip * 0.42), lip * 0.2), Color(colour, 0.85))
	b.ellipse(rim + Vector2(0.0, -lip * 0.12), w * 0.42, lip * 0.26, Pal.MG_SOIL)
	b.ellipse(rim + Vector2(0.0, -lip * 0.12), w * 0.5, lip * 0.5, Color(Pal.SUN_RAY, 0.3))
	var mid := rim + Vector2(0.0, lip * 0.5 + (h - lip * 0.5) * 0.52)
	var c := w * 0.13
	b.stroke(PackedVector2Array([mid + Vector2(-c * 0.55, -c), mid + Vector2(c * 0.55, 0.0), mid + Vector2(-c * 0.55, c)]),
		w * 0.085, Pal.SURFACE)

func _lay() -> void:
	var words := _words(String(entry.get("title", "")), SIDE, size.y * 0.5, WORDS, Pal.TEXT, BLURB)
	words.position.y = roundf(WORDS_TOP * _k())
