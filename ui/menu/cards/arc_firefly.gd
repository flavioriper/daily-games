extends "res://ui/menu/cards/card_face.gd"

## Firefly's card: a summer night over the whole paper and the game's own
## cast on it. Two short ranks of the swarm hang top right, left of the
## seal's corner -- three ladybirds over four gnats, facing down as they do
## in the game -- and one moth has broken rank and dives under the corner in
## a soft glow. Low on the right the firefly looks up its column at a gnat,
## one shot of its lantern's light on the way.
##
## The go button is the firefly: the game's own, its body in the card's
## colour, larger, lifted on its glow, a chevron pointing up the column it
## fires along. The name stands top left in cream; the Arcade tab says the
## best score under it.
##
## Everything is one mesh, the bugs arcade/firefly_art.gd's own builders
## laid where they stand. Nothing lives on the card and it writes no string.

const Art = preload("res://arcade/firefly_art.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

## The row the card was drawn for (puzzle_card_2d.gd's CARD_H).
const H := 246.0
## How wide the picture is at H, and where the words end: the picture never
## starts under them.
const REACH := 250.0
const WORDS_END := 238.0
## The ranks, as [how far in from the card's right side, how far down] at H,
## and the bugs' unit (a bug is about 13 units across).
const BEETLES: Array[Vector2] = [Vector2(202.0, 50.0), Vector2(156.0, 50.0), Vector2(110.0, 50.0)]
const GNATS: Array[Vector2] = [Vector2(226.0, 96.0), Vector2(180.0, 96.0), Vector2(134.0, 96.0), Vector2(88.0, 96.0)]
const BUG := 2.5
## The moth that dives, how far it leans, and its glow.
const MOTH := Vector2(50.0, 134.0)
const MOTH_LEAN := 0.32
const MOTH_GLOW := 38.0
## The firefly: where it flies (under the third gnat), its unit as the go
## button and plain, how far it is lifted, and the shot above it.
const FLY := Vector2(134.0, 192.0)
const GO := 3.5
const PLAIN := 2.6
const GO_LIFT := 4.0
const SHOT := Vector2(134.0, 140.0)
const SHOT_R := 4.2
## The grass along the foot: how tall, and how far its top swells.
const GRASS := 22.0
const SWELL := 5.0
## The stars: how many, and their seed.
const STARS := 22
const STAR_SEED := 11
## The words' margin, their room and how far down they start.
const SIDE := 22.0
const WORDS := 215.0
const WORDS_TOP := 14.0

## The night, the grass under it, and the words' inks.
const NIGHT_TOP := Color("1f2f4a")
const NIGHT_LOW := Color("2f4a5c")
const GRASS_TOP := Color("2c5152")
const GRASS_LOW := Color("244546")
const INK := Color("fbf3df")
const DIM := Color("c3cbd6")

func _k() -> float:
	return minf(size.y / H, maxf(size.x - WORDS_END, 1.0) / REACH)

## A place given as [in from the right, down] at H, on the card: the picture
## hangs from the right side and stands on the foot.
func _at(p: Vector2) -> Vector2:
	var k := _k()
	return Vector2(size.x - p.x * k, size.y - (H - p.y) * k)

func _paint(b: Face.Builder) -> void:
	var k := _k()
	var first := b.verts.size()
	b.polygon(ground(), Color.WHITE)
	shade(b, first, NIGHT_TOP, NIGHT_LOW, 0.0, size.y)
	_stars(b, k)
	_grass(b, k)
	# The moth's glow under the swarm, then the ranks facing down.
	var moth := _at(MOTH)
	Scenery.soft_disc(b, moth, MOTH_GLOW * k, MOTH_GLOW * k, Color(Art.MOTH_WING, 0.26))
	for i in BEETLES.size():
		_lay_bug(b, Art.beetle.bind(BUG * k, i % 2), Transform2D(PI, _at(BEETLES[i])))
	for i in GNATS.size():
		_lay_bug(b, Art.gnat.bind(BUG * k, (i + 1) % 2), Transform2D(PI, _at(GNATS[i])))
	_lay_bug(b, Art.moth.bind(BUG * k, 1, false), Transform2D(PI + MOTH_LEAN, moth))
	var fly := _at(FLY)
	if soon:
		_lay_bug(b, Art.firefly.bind(PLAIN * k, 0, Art.FIREFLY_BODY, Art.FIREFLY_SHIELD, true), Transform2D(0.0, fly))
		return
	Art._shot(b, _at(SHOT), SHOT_R * k)
	_go(b, fly - Vector2(0.0, GO_LIFT * k), k)

## One of the game's bugs, built about the origin as its builder draws it and
## then laid by `xf`.
func _lay_bug(b: Face.Builder, build: Callable, xf: Transform2D) -> void:
	var first := b.verts.size()
	build.call(b)
	for i in range(first, b.verts.size()):
		b.verts[i] = xf * b.verts[i]

## The go firefly about `at`: a soft dark under it, the game's firefly with
## its body in the card's colour, and a chevron up its back.
func _go(b: Face.Builder, at: Vector2, k: float) -> void:
	var u := GO * k
	Scenery.soft_disc(b, at + Vector2(0.0, (9.0 * GO + GO_LIFT) * k * 0.82), 9.0 * u, 2.2 * u, Color(NIGHT_TOP.darkened(0.4), 0.5))
	_lay_bug(b, Art.firefly.bind(u, 0, colour, Art.FIREFLY_SHIELD, true), Transform2D(0.0, at))
	var mid := at + Vector2(0.0, 0.2 * u)
	var h := 1.5 * u
	b.stroke(PackedVector2Array([mid + Vector2(-h, h * 0.55), mid + Vector2(0.0, -h * 0.55), mid + Vector2(h, h * 0.55)]),
		0.85 * u, INK)

## A few stars, none under the words.
func _stars(b: Face.Builder, k: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = STAR_SEED
	for i in STARS:
		var at := Vector2(rng.randf_range(16.0, size.x - 16.0), rng.randf_range(14.0, size.y - (GRASS + 14.0) * k))
		var r := rng.randf_range(0.9, 2.1) * k
		var a := rng.randf_range(0.3, 0.75)
		if at.x < WORDS_END + 12.0 and at.y < 176.0 * k:
			continue
		b.disc(at, r, Color(1.0, 0.96, 0.8, a))

## The grass along the foot, its top a slow swell, cut to the paper.
func _grass(b: Face.Builder, k: float) -> void:
	var top := size.y - GRASS * k
	var band := PackedVector2Array()
	var n := 24
	for i in n + 1:
		var t := float(i) / n
		band.append(Vector2(t * size.x, top - sin(t * PI * 1.6 + 0.5) * SWELL * k))
	band.append(Vector2(size.x, size.y))
	band.append(Vector2(0.0, size.y))
	for part: PackedVector2Array in Geometry2D.intersect_polygons(band, ground()):
		var first := b.verts.size()
		b.polygon(part, Color.WHITE)
		shade(b, first, GRASS_TOP, GRASS_LOW, top - SWELL * k, size.y)

func _lay() -> void:
	var words := _words(String(entry.get("title", "")), SIDE, size.y * 0.5, WORDS, INK, DIM)
	words.position.y = roundf(WORDS_TOP * _k())
