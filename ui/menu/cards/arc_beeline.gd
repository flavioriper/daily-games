extends "res://ui/menu/cards/card_face.gd"

## Beeline's card: a pale morning, sky over honey, and the flight itself.
## Two of the game's hedges stand on the right: the nearer a whole gate, one
## half hanging from the top and one standing on the foot with the gap
## between, the farther only its lower half, at the card's edge under the
## seal's corner. The bee flies at the first gap, a ribbon hanging in it,
## and the last two flaps of her wake rise and fall behind her, each a
## small arc of dots. Queens seats the same bee on a court; here she flies.
##
## The go button is the tap: a round stone pad low under her in the card's
## colour, lifted over its shadow, its chevron pointing up, since a tap is a
## flap. The name stands top left.
##
## Everything is one mesh. The bee is arcade/beeline_art.gd's own builder,
## turned and set in place vertex by vertex; her wings, the hedges and the
## ribbon are redrawn here from that file's shapes, the hedges because the
## game's are one mesh a screen long. Nothing lives on the card and it
## writes no string.

const Art = preload("res://arcade/beeline_art.gd")
const Sim = preload("res://arcade/beeline_sim.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

## The row the card was drawn for (puzzle_card_2d.gd's CARD_H).
const H := 246.0
## The picture's reach from the right side at H, and where the words end:
## the scale is capped so the picture never starts under them.
const REACH := 262.0
const WORDS_END := 224.0
## Where things stand, as [how far in from the card's right side, how far
## down], at H: the bee, the near gate's middle line, the far hedge's, the
## pad.
const BEE := Vector2(204.0, 124.0)
const NEAR := 122.0
const FAR := 54.0
const PAD := Vector2(214.0, 202.0)
## The near gap's top and bottom, and the far hedge's top, at H.
const GAP_TOP := 76.0
const GAP_FOOT := 168.0
const FAR_TOP := 146.0
## A hedge's field unit at H (the game's gate is Sim.GATE_W of them wide),
## and half the bee's length.
const HEDGE_U := 1.04
const BEE_S := 23.0
## How far the bee leans into her climb, in radians.
const LEAN := -0.14
## The wake: each flap's reach and rise at H, how many dots a flap, and the
## dot's size.
const FLAP := Vector2(26.0, 13.0)
const FLAP_DOTS := 4
const DOT_R := 3.0
## The pad: its half sizes at H, its lip, its lift and its shadow.
const PAD_R := Vector2(30.0, 24.0)
const PAD_LIP := 6.0
const GO_LIFT := 4.0
const GO_SHADOW := 0.24
const PLAIN_R := Vector2(21.0, 16.0)
## The ribbon in the gap: its tier and its size at H.
const RIBBON := 3
const RIBBON_R := 10.0
## The words' margin, their room and how far down they start.
const SIDE := 22.0
const WORDS := 215.0
const WORDS_TOP := 14.0

## The morning: sky over honey, a pale pool behind the flight, one cloud
## and the blurb's ink.
const SKY_TOP := Color("eaf4f8")
const SKY_LOW := Color("fbf3d8")
const POOL := Color("fffaea")
const CLOUD := Color("ffffff")
const BLURB := Color("6c6a5c")

func _k() -> float:
	return minf(size.y / H, (size.x - WORDS_END) / REACH)

## A place given as [in from the right, down] at H, on the card. The
## picture stands on the foot, so a taller card keeps its room over it.
func _at(p: Vector2) -> Vector2:
	var k := _k()
	return Vector2(size.x - p.x * k, size.y - (H - p.y) * k)

func _paint(b: Face.Builder) -> void:
	var k := _k()
	var first := b.verts.size()
	b.polygon(ground(), Color.WHITE)
	shade(b, first, SKY_TOP, SKY_LOW, 0.0, size.y)
	var bee := _at(BEE)
	Scenery.soft_disc(b, bee + Vector2(30.0, 4.0) * k, 120.0 * k, 78.0 * k, Color(POOL, 0.6))
	_cloud(b, _at(Vector2(268.0, 196.0)) if size.x > 700.0 else _at(Vector2(176.0, 30.0)), k)
	var top := EDGE + 1.0
	var foot := size.y - EDGE - 2.0
	# The far hedge first, its lower half only: the seal has the corner.
	_hedge(b, _at(Vector2(FAR, FAR_TOP)), foot, false, k, 11)
	_hedge(b, _at(Vector2(NEAR, GAP_TOP)), top, true, k, 7)
	_hedge(b, _at(Vector2(NEAR, GAP_FOOT)), foot, false, k, 5)
	Art.ribbon_into(b, RIBBON, _at(Vector2(NEAR, (GAP_TOP + GAP_FOOT) * 0.5 - 4.0)), RIBBON_R * k)
	_wake(b, bee, k)
	_bee(b, bee, k)
	_pad(b, _at(PAD), k)

## One soft cloud, three discs on a flat foot.
func _cloud(b: Face.Builder, at: Vector2, k: float) -> void:
	for d: Array in [[Vector2(-16.0, 2.0), 10.0], [Vector2(0.0, -4.0), 14.0], [Vector2(17.0, 2.0), 10.0]]:
		b.disc(at + (d[0] as Vector2) * k, float(d[1]) * k, Color(CLOUD, 0.7))
	b.polygon(Face.Builder.round_rect(at + Vector2(-26.0, 0.0) * k, Vector2(52.0, 12.0) * k, 6.0 * k), Color(CLOUD, 0.7))

## One half of a gate as the game draws it, its rounded end at `end` and
## its column running to the height `to`: the ink, a row of leaf bumps down
## each side, the leaf lit from the left, clumps and a blossom or two.
## `down` hangs it from above.
func _hedge(b: Face.Builder, end: Vector2, to: float, down: bool, k: float, pick: int) -> void:
	var u := HEDGE_U * k
	var dir := -1.0 if down else 1.0
	var hw := Sim.GATE_W * 0.5 * u
	var dome := 13.0 * u
	var length := absf(to - end.y)
	var far := end.y + length * dir
	# No bump past the column's far end: it stands on the paper's edge.
	var n := maxi(int((length - dome - 9.0 * u) / (8.0 * u)) + 1, 0)
	var rng := RandomNumberGenerator.new()
	rng.seed = pick
	_box(b, end.x - hw + 4.0 * u, end.y + dome * dir, end.x + hw - 4.0 * u, far, Art.HEDGE_INK)
	for i in n:
		var y := end.y + (dome / u + 2.0 + i * 8.0) * u * dir
		for side: float in [-1.0, 1.0]:
			b.disc(Vector2(end.x + side * (hw - 4.5 * u), y), 6.4 * u, Art.HEDGE_INK)
	b.ellipse(end + Vector2(0.0, dome * dir), hw + 1.5 * u, dome, Art.HEDGE_INK)
	_box(b, end.x - hw + 4.0 * u, end.y + dome * dir, end.x + hw - 4.0 * u, far, Art.HEDGE)
	for i in n:
		var y := end.y + (dome / u + 2.0 + i * 8.0) * u * dir
		b.disc(Vector2(end.x - (hw - 4.5 * u), y), 4.6 * u, Art.HEDGE_HI if i % 3 == 0 else Art.HEDGE)
		b.disc(Vector2(end.x + hw - 4.5 * u, y), 4.6 * u, Art.HEDGE_DEEP)
	b.ellipse(end + Vector2(0.0, dome * dir), hw - 0.5 * u, dome - 2.0 * u, Art.HEDGE)
	b.ellipse(end + Vector2(-hw * 0.3, (dome - 4.5 * u) * dir), hw * 0.42, 3.2 * u, Color(Art.HEDGE_HI, 0.8))
	var room := length - 12.0 * u
	for i in int(room / (9.0 * u)):
		var y := end.y + (10.0 * u + i * 9.0 * u + rng.randf_range(-2.0, 2.0) * u) * dir
		var x := rng.randf_range(-hw + 9.0 * u, hw - 9.0 * u)
		var lit := x < rng.randf_range(-0.3, 0.5) * hw
		b.ellipse(Vector2(end.x + x, y), rng.randf_range(4.0, 7.0) * u, rng.randf_range(2.6, 4.0) * u,
			Color(Art.HEDGE_HI if lit else Art.HEDGE_DEEP, 0.55 if lit else 0.6))
	if room > 26.0 * u:
		var c := Vector2(end.x + rng.randf_range(-hw + 11.0 * u, hw - 11.0 * u), end.y + (18.0 * u + rng.randf_range(0.0, room - 26.0 * u)) * dir)
		var col: Color = Art.BLOSSOMS[pick % Art.BLOSSOMS.size()]
		for p in 5:
			b.disc(c + Vector2.from_angle(TAU * p / 5.0 + pick) * 2.6 * u, 2.3 * u, col)
		b.disc(c, 1.6 * u, Color("f2c14e") if col != Art.BLOSSOMS[1] else Art.BLOSSOMS[0])

static func _box(b: Face.Builder, x0: float, y0: float, x1: float, y1: float, col: Color) -> void:
	b.fan(PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)]), col)

## Her last two flaps: each a small arc of dots behind her, the nearer one
## brighter, none under the words.
func _wake(b: Face.Builder, bee: Vector2, k: float) -> void:
	var tail := bee + Vector2(-BEE_S * 1.5, 5.0) * k
	for f in 2:
		var from := tail + Vector2(-FLAP.x * f, 3.0 * f) * k
		for d in FLAP_DOTS:
			var t := (d + 0.5) / float(FLAP_DOTS)
			var at := from + Vector2(-FLAP.x * t, -FLAP.y * 4.0 * t * (1.0 - t) + 3.0 * t) * k
			if at.x < WORDS_END - 6.0:
				continue
			var fade := 0.9 - 0.2 * (f * FLAP_DOTS + d) / float(FLAP_DOTS)
			b.disc(at, (DOT_R - 0.25 * (f * FLAP_DOTS + d)) * k, Color(Art.BODY_HI, fade))

## The bee about `at`, leaning into her climb: her wings behind her, then
## the game's own body, both set in place after they are built.
func _bee(b: Face.Builder, at: Vector2, k: float) -> void:
	var s := BEE_S * k
	var xf := Transform2D(LEAN, at)
	var first := b.verts.size()
	var root: Vector2 = Art.WING_AT * (s / Art.BEE)
	for w in 2:
		var mid := root + Vector2((0.26 - 0.5 * w) * s, -0.52 * s)
		var lean := 0.3 - 0.5 * w
		var edge := PackedVector2Array()
		var fill := PackedVector2Array()
		for p: Vector2 in Face.Builder.ring(Vector2.ZERO, 0.4 * s, 0.6 * s):
			edge.append(mid + p.rotated(lean))
		for p: Vector2 in Face.Builder.ring(Vector2.ZERO, 0.33 * s, 0.53 * s):
			fill.append(mid + p.rotated(lean))
		b.fan(edge, Color(Art.WING_EDGE, 0.75))
		b.fan(fill, Color(Art.WING, 0.9))
	Art._bee(b, Art.Look.FLY, s)
	for i in range(first, b.verts.size()):
		b.verts[i] = xf * b.verts[i]

## The pad about `at`: a flat stone in the card's colour over its shadow,
## its lip under it, a pale patch for the light and the chevron pointing
## up. Not open yet, it is a plain pebble with nothing on it.
func _pad(b: Face.Builder, at: Vector2, k: float) -> void:
	if soon:
		var pr := PLAIN_R * k
		Scenery.soft_disc(b, at + Vector2(0.0, pr.y * 0.7), pr.x * 1.1, pr.y * 0.5, Color(Pal.TEXT, GO_SHADOW * 0.8))
		b.ellipse(at + Vector2(0.0, 3.0 * k), pr.x, pr.y, colour.darkened(0.26))
		b.ellipse(at, pr.x, pr.y, colour)
		return
	var r := PAD_R * k
	var c := at - Vector2(0.0, GO_LIFT * k)
	Scenery.soft_disc(b, at + Vector2(0.0, r.y * 0.78 + GO_LIFT * k), r.x * 1.14, r.y * 0.5, Color(Pal.TEXT, GO_SHADOW))
	b.ellipse(c + Vector2(0.0, PAD_LIP * k), r.x, r.y, colour.darkened(0.3))
	b.ellipse(c, r.x, r.y, colour)
	b.ellipse(c + Vector2(-r.x * 0.3, -r.y * 0.46), r.x * 0.36, r.y * 0.2, Color(Pal.SURFACE, 0.3))
	var h := r.y * 0.42
	b.stroke(PackedVector2Array([c + Vector2(-h, h * 0.5), c + Vector2(0.0, -h * 0.5), c + Vector2(h, h * 0.5)]),
		r.y * 0.26, Pal.SURFACE)

func _lay() -> void:
	var words := _words(String(entry.get("title", "")), SIDE, size.y * 0.5, WORDS, Pal.TEXT, BLURB)
	words.position.y = roundf(WORDS_TOP * size.y / H)
