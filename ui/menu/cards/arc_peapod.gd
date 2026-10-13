extends "res://ui/menu/cards/card_face.gd"

## Peapod's card: a bright mint morning and nothing but open air. Three of
## the game's own numbered crates come down in a staggered row on the right,
## one of them under the seal's corner, and the nearest -- an 8, cracked, the
## last of its number -- has a stream of four peas rising to it from the pea
## cannon at the foot: the game's cart on its two wheels, aiming straight up.
##
## The go button is the cannon: the pod redrawn in the card's colour, larger
## than the game's, lifted over its shadow, a chevron on its belly pointing
## up the stream. The name stands top left, with the best score under it.
##
## Everything still is one mesh: the crates, their cracks, the cart and its
## wheels are arcade/peapod_art.gd's own meshes baked in, the peas its own
## builder. The crates' numbers are three strings over the mesh, as the game
## letters them. Nothing lives on the card.

const PeaArt = preload("res://arcade/peapod_art.gd")
const PeaSim = preload("res://arcade/peapod_sim.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

## The row the card was drawn for (puzzle_card_2d.gd's CARD_H).
const H := 246.0
## The words end here: the picture never starts left of it.
const WORDS_END := 241.0
## How far the picture reaches in from the card's right side, at H.
const REACH := 249.0
## The game's unit for a crate at H (a crate is 57 by 37 of them).
const UNIT := 1.3
## The crates, as [in from the right, down, number, worn stage], at H. The
## middle one is the one being shot.
const CRATES := [[52.0, 112.0, 35, 0], [134.0, 68.0, 8, 2], [212.0, 106.0, 120, 0]]
const TARGET := 1
const CRACK_LOOK := 2
## The cannon: the game's unit for it at H, how far its axle stands over the
## card's foot, how far the go cannon is lifted, and its shadow.
const GUN := 1.75
const AXLE := 30.0
const GO_LIFT := 4.0
const GO_SHADOW := 0.2
## The peas in flight: how many, their radius and how far apart, at H.
const PEAS := 4
const PEA_R := 5.0
const PEA_GAP := 10.0
## The words' margin, their room and how far down they start.
const SIDE := 22.0
const WORDS := 215.0
const WORDS_TOP := 14.0

## The morning: a brighter, greener mint than Toy Cannons' floor, a pale
## pool behind the crates, the grass under the cart, and the blurb's ink.
const AIR_TOP := Color("e6f7df")
const AIR_LOW := Color("cdebc0")
const POOL := Color("f6fcef")
const GRASS := Color("a9dc7f")
const BLURB := Color("567250")

## The numbers `_draw` letters over the mesh: [centre, value, height].
var _nums: Array = []

## The picture's scale: the card's height sets it, its width caps it.
func _k() -> float:
	return minf(size.y / H, maxf(size.x - WORDS_END, 0.0) / REACH)

## The foot the picture stands on: the card's own, whatever its height.
func _foot() -> float:
	return size.y

## A crate's middle on the card.
func _crate_at(i: int) -> Vector2:
	var k := _k()
	return Vector2(size.x - float(CRATES[i][0]) * k, float(CRATES[i][1]) * k)

## The cannon's axle: under the crate it shoots.
func _axle() -> Vector2:
	return Vector2(_crate_at(TARGET).x, _foot() - AXLE * _k())

func _paint(b: Face.Builder) -> void:
	_nums.clear()
	var k := _k()
	var first := b.verts.size()
	b.polygon(ground(), Color.WHITE)
	shade(b, first, AIR_TOP, AIR_LOW, 0.0, size.y)
	if k <= 0.0:
		return
	var u := UNIT * k
	var mid := _crate_at(TARGET)
	Scenery.soft_disc(b, Vector2(size.x - 130.0 * k, 100.0 * k), 120.0 * k, 62.0 * k, Color(POOL, 0.6))
	var axle := _axle()
	Scenery.soft_disc(b, axle + Vector2(0.0, 10.0 * k), 62.0 * k, 8.0 * k, Color(GRASS, 0.55))
	# The crates, the game's own, and the cracks of the one nearly spent.
	var tall := (PeaSim.CELL_H - 3.0) * u
	for i in CRATES.size():
		var at := _crate_at(i)
		var hp := int(CRATES[i][2])
		b.append(PeaArt.crate(PeaSim.Kind.CRATE, PeaArt.tier_of(hp), u), Transform2D(0.0, at))
		if int(CRATES[i][3]) > 0:
			b.append(PeaArt.cracks(false, CRACK_LOOK, int(CRATES[i][3]), u), Transform2D(0.0, at))
		_nums.append([at + Vector2(0.0, -2.2 * u), hp, tall])
	# The stream, from the pod's mouth up to the crate's foot.
	var g := GUN * k
	var lift := 0.0 if soon else GO_LIFT * k
	var mouth := axle.y - lift - 42.0 * g
	var under := mid.y + tall * 0.5
	for i in PEAS:
		var y := mouth - (float(i) + 0.9) * PEA_GAP * k
		if y < under + PEA_R * k:
			break
		PeaArt.pea(b, Vector2(axle.x, y), PEA_R * k)
	# The cannon: its shadow, the pod, the cart over the pod's foot, wheels.
	var foot := axle - Vector2(0.0, lift)
	Scenery.soft_disc(b, axle + Vector2(0.0, 9.0 * g), 26.0 * g, 3.6 * g, Color(Pal.TEXT, GO_SHADOW))
	if soon:
		b.append(PeaArt.barrel(g), Transform2D(0.0, foot + Vector2(0.0, -12.0 * g)))
	else:
		_pod(b, foot + Vector2(0.0, -12.0 * g), g)
	b.append(PeaArt.cart(g), Transform2D(0.0, foot))
	for side: float in [-1.0, 1.0]:
		b.append(PeaArt.wheel(g), Transform2D(0.4, foot + Vector2(side * 13.0 * g, 0.0)))

## The go pod, its foot at `at`, mouth up: the game's pod (peapod_art.gd's
## `barrel`) in the card's colour, a chevron up its belly.
func _pod(b: Face.Builder, at: Vector2, g: float) -> void:
	var deep := colour.darkened(0.26)
	var tall := 30.0 * g
	var body := PackedVector2Array()
	body.append_array(Face.Builder.bezier3(at + Vector2(-6, 0) * g, at + Vector2(-12, -8) * g, at + Vector2(-10, -22) * g,
		at + Vector2(-8, -30) * g, 10))
	body.append_array(Face.Builder.bezier3(at + Vector2(8, -30) * g, at + Vector2(10, -22) * g, at + Vector2(12, -8) * g,
		at + Vector2(6, 0) * g, 10))
	b.polygon(body, deep)
	var inner := PackedVector2Array()
	for p in body:
		var q := p - at
		inner.append(at + Vector2(q.x * 0.84 - 0.8 * g, q.y * 0.97 - 0.4 * g))
	b.polygon(inner, colour)
	b.ellipse(at + Vector2(-5.6 * g, -tall * 0.5), 1.6 * g, tall * 0.28, Color(Pal.SURFACE, 0.4))
	# The lip round the mouth, and the dark of the mouth in it.
	b.ellipse(at + Vector2(0.0, -tall + 0.6 * g), 10.0 * g, 4.2 * g, deep)
	b.ellipse(at + Vector2(0.0, -tall - 0.6 * g), 9.4 * g, 3.4 * g, colour.lightened(0.3))
	b.ellipse(at + Vector2(0.0, -tall - 0.4 * g), 6.4 * g, 2.0 * g, colour.darkened(0.5))
	# The tendril off the foot, as the game's pod has.
	b.stroke(Face.Builder.bezier3(at + Vector2(8, -6) * g, at + Vector2(15, -8) * g, at + Vector2(16, -15) * g,
		at + Vector2(12, -14) * g, 10), maxf(1.0, 1.1 * g), deep)
	var c := at + Vector2(0.0, -tall * 0.5 + 1.0 * g)
	var h := 4.6 * g
	b.stroke(PackedVector2Array([c + Vector2(-h, h * 0.55), c + Vector2(0.0, -h * 0.55), c + Vector2(h, h * 0.55)]),
		2.6 * g, Pal.SURFACE)

func _draw() -> void:
	super()
	var font := PeaArt.font()
	for n: Array in _nums:
		PeaArt.number(self, font, n[0], int(n[1]), float(n[2]))

func _lay() -> void:
	var words := _words(String(entry.get("title", "")), SIDE, size.y * 0.5, WORDS, Pal.TEXT, BLURB)
	words.position.y = roundf(WORDS_TOP * size.y / H)
