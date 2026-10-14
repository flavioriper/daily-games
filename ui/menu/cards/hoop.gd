extends "res://ui/menu/cards/card_face.gd"

## Yarn Hoop's card: a pale rose linen, and on its right the board's wooden
## embroidery hoop with its screw at the top and its own linen inside. In it
## a small low-poly heart is half knitted, as the board fills a panel: the
## left lobe and the right lobe's top are knit, darker ground and lighter Vs
## in three shades of rose; the three panels low on the right are still bare
## linen, each with its corner dots, its purple pins standing at the corners,
## two of its sides already threaded in terracotta yarn. The heart keeps the
## board's rule: a panel is knit only when all its sides are threaded, and a
## pin with every side threaded is gone (`_true`).
##
## The go button is a ball of yarn in the card's colour, lifted over its
## shadow between the words and the hoop, a chevron on it, and its loose
## end runs to the pin in the heart's middle, the thread in hand (the
## heart's lowest pin has every side threaded, so it is gone). The name stands
## top left.
##
## Everything is one mesh. Nothing lives on the card and it writes no
## string. (The board's colours are puzzles/hoop2d.gd's, copied: preloading
## the board is a cycle.)

const Scenery = preload("res://ui/flat/scenery.gd")

## The row and the width the card was drawn for.
const H := 246.0
const W := 490.0
## The hoop: its middle from the card's right side and foot, its radius and
## its ring's width, at H.
const HOOP_AT := Vector2(132.0, 118.0)
const HOOP_R := 100.0
const RING := 13.0
## The heart's pins, as shares of the hoop's radius about its middle.
const PINS: Array[Vector2] = [
	Vector2(-0.56, -0.26), Vector2(-0.28, -0.52), Vector2(0.0, -0.26), Vector2(0.28, -0.52),
	Vector2(0.56, -0.26), Vector2(-0.34, 0.12), Vector2(0.0, 0.16), Vector2(0.34, 0.12),
	Vector2(0.0, 0.6),
]
## The panels: corners, bead colour, knit or bare.
const PANELS := [
	[[0, 1, 2], "coral", true],
	[[2, 3, 4], "rose", true],
	[[0, 2, 5], "red", true],
	[[2, 6, 5], "rose", true],
	[[5, 6, 8], "red", true],
	[[2, 7, 6], "rose", false],
	[[2, 4, 7], "coral", false],
	[[6, 7, 8], "red", false],
]
## Sides of the bare panels already threaded.
const THREADED := [[2, 7], [7, 8]]
## A stitch's column width and row height, at H.
const KNIT := Vector2(8.0, 6.5)
## The pin's head, at H.
const PIN_R := 4.6
## The go button: its radius, where it stands from the card's right side and
## foot, its lift and its shadow.
const GO_R := 27.0
const GO_AT := Vector2(268.0, 52.0)
const GO_LIFT := 5.0
const GO_SHADOW := 0.24
## The words' margin, their room and how far down they start.
const SIDE := 22.0
const WORDS := 215.0
const WORDS_TOP := 14.0

## The linen, top to foot, and the blurb's ink.
const LINEN_TOP := Color("fcf0ec")
const LINEN_LOW := Color("f2dcd5")
const BLURB := Color("85645c")
## The board's own colours (puzzles/hoop2d.gd).
const LINEN := Color("fbf6ec")
const LINEN_WEAVE := Color("efe6d6")
const RING_WOOD := Color("d4a777")
const RING_DEEP := Color("a87a4f")
const RING_HI := Color("e9c79c")
const SCREW := Color("b58a5e")
const YARN := Color("b8664d")
const YARN_DEEP := Color("8e4634")
const PIN := Color("6b5b8c")
const PIN_DEEP := Color("4d4068")
const PIN_HI := Color("a596c4")
const MARK := Color("b5a48b")

## The card's height sets the scale and its width caps it.
func _k() -> float:
	return minf(size.y / H, size.x / W)

## A place given as [in from the card's right side, up from its foot] at H.
func _at(p: Vector2) -> Vector2:
	var k := _k()
	return Vector2(size.x - p.x * k, size.y - p.y * k)

func _pin(v: int) -> Vector2:
	return _at(HOOP_AT) + PINS[v] * HOOP_R * _k()

func _threaded(a: int, b: int) -> bool:
	for p in PANELS:
		if p[2] and _has_side(p[0], a, b):
			return true
	for t in THREADED:
		if (t[0] == a and t[1] == b) or (t[0] == b and t[1] == a):
			return true
	return false

static func _has_side(corners: Array, a: int, b: int) -> bool:
	for m in corners.size():
		var x: int = corners[m]
		var y: int = corners[(m + 1) % corners.size()]
		if (x == a and y == b) or (x == b and y == a):
			return true
	return false

## A pin stands while it has a side not threaded.
func _standing(v: int) -> bool:
	for p in PANELS:
		var c: Array = p[0]
		for m in c.size():
			var a: int = c[m]
			var b: int = c[(m + 1) % c.size()]
			if (a == v or b == v) and not _threaded(a, b):
				return true
	return false

## The picture keeps the board's rule: every knit panel's sides are all
## threaded, and every bare one has a side open.
func _true() -> bool:
	for p in PANELS:
		var c: Array = p[0]
		var all := true
		for m in c.size():
			if not _threaded(c[m], c[(m + 1) % c.size()]):
				all = false
		if all != bool(p[2]):
			return false
	return true

func _paint(b: Face.Builder) -> void:
	var k := _k()
	var first := b.verts.size()
	b.polygon(ground(), Color.WHITE)
	shade(b, first, LINEN_TOP, LINEN_LOW, 0.0, size.y)
	_hoop(b, k)
	var ok := _true()
	for p in PANELS:
		if p[2] and ok:
			_knit(b, p[0], Pal.PG_BEADS.get(p[1], Pal.LINE), k)
	for p in PANELS:
		if not p[2] or not ok:
			_marks(b, p[0], k)
	# The threads: every side of a bare panel already laid.
	for t in THREADED:
		_yarn(b, _pin(t[0]), _pin(t[1]), k)
	for v in PINS.size():
		if _standing(v):
			_pin_head(b, _pin(v), PIN_R * k)
	_clamp(b, k)
	if soon:
		var at := _at(GO_AT)
		Scenery.soft_disc(b, at + Vector2(0.0, GO_R * 0.75 * k), GO_R * k, GO_R * 0.3 * k, Color(Pal.TEXT, 0.2))
		_ball(b, at, GO_R * 0.8 * k, colour)
		return
	_go(b, _at(GO_AT) - Vector2(0.0, GO_LIFT * k), GO_R * k)

## The ring, its shadow on the cloth, and its linen with the weave.
func _hoop(b: Face.Builder, k: float) -> void:
	var c := _at(HOOP_AT)
	var r := HOOP_R * k
	Scenery.soft_disc(b, c + Vector2(0.0, 6.0 * k), r * 1.06, r * 1.02, Color(Pal.OUTLINE, 0.1))
	b.disc(c, r, RING_DEEP)
	b.disc(c + Vector2(0.0, -1.0 * k), r - 1.5 * k, RING_WOOD)
	b.stroke(Face.Builder.arc_points(c, r - RING * k * 0.35, PI * 1.1, PI * 1.75), 2.2 * k, Color(RING_HI, 0.85))
	var inner := r - RING * k
	b.disc(c, inner + 1.5 * k, RING_DEEP)
	b.disc(c, inner, LINEN)
	var gap := 9.0 * k
	var y := c.y - inner + gap
	while y < c.y + inner:
		var half := sqrt(maxf(0.0, inner * inner - (y - c.y) * (y - c.y))) - 1.0
		if half > 2.0:
			b.fan(PackedVector2Array([Vector2(c.x - half, y), Vector2(c.x + half, y), Vector2(c.x + half, y + 0.9 * k), Vector2(c.x - half, y + 0.9 * k)]), LINEN_WEAVE)
		y += gap

## The screw at the ring's top.
func _clamp(b: Face.Builder, k: float) -> void:
	var top := _at(HOOP_AT) - Vector2(0.0, HOOP_R * k)
	b.polygon(Face.Builder.round_rect(top + Vector2(-13.0, -7.0) * k, Vector2(26.0, RING + 5.0) * k, 4.0 * k), RING_DEEP)
	b.polygon(Face.Builder.round_rect(top + Vector2(-11.5, -6.0) * k, Vector2(23.0, RING + 2.0) * k, 3.5 * k), RING_WOOD)
	b.polygon(Face.Builder.round_rect(top + Vector2(-4.5, -18.0) * k, Vector2(9.0, 13.0) * k, 2.5 * k), SCREW)
	b.disc(top + Vector2(0.0, -20.0) * k, 7.5 * k, RING_DEEP)
	b.disc(top + Vector2(0.0, -21.0) * k, 6.5 * k, SCREW)

## A knit panel: a darker ground in its colour, lighter V stitches over it,
## a hair of linen left round it as the board's seam.
func _knit(b: Face.Builder, corners: Array, base: Color, k: float) -> void:
	var outline := PackedVector2Array()
	for v: int in corners:
		outline.append(_pin(v))
	var inset: Array = Geometry2D.offset_polygon(outline, -0.9 * k)
	var ground: PackedVector2Array = inset[0] if not inset.is_empty() else outline
	b.polygon(ground, base.darkened(0.16))
	var light := base.lightened(0.07)
	var lo := ground[0]
	var hi := ground[0]
	for p in ground:
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
	var cw := KNIT.x * k
	var rh := KNIT.y * k
	var y := floorf(lo.y / rh) * rh
	while y <= hi.y:
		var x := floorf(lo.x / cw) * cw
		while x <= hi.x:
			var c := Vector2(x + cw * 0.5, y + rh * 0.5)
			for side: float in [-1.0, 1.0]:
				var leaf := PackedVector2Array()
				var lc := c + Vector2(side * cw * 0.21, 0.0)
				for m in 6:
					var a := TAU * m / 6.0
					leaf.append(lc + Vector2(cos(a) * cw * 0.17, sin(a) * rh * 0.6).rotated(-side * 0.5))
				var inside := true
				for q in leaf:
					if not Geometry2D.is_point_in_polygon(q, ground):
						inside = false
						break
				if inside:
					b.fan(leaf, light)
			x += cw
		y += rh

## A bare panel's mark: a dot a corner, its shape in small.
func _marks(b: Face.Builder, corners: Array, k: float) -> void:
	var c := Vector2.ZERO
	for v: int in corners:
		c += _pin(v)
	c /= corners.size()
	var far := 0.01
	for v: int in corners:
		far = maxf(far, _pin(v).distance_to(c))
	for v: int in corners:
		b.disc(c + (_pin(v) - c) / far * minf(6.0 * k, far * 0.3), 1.5 * k, MARK)

## A thread between two pins, with its twist.
func _yarn(b: Face.Builder, a: Vector2, c: Vector2, k: float) -> void:
	b.stroke(PackedVector2Array([a, c]), 3.2 * k, YARN)
	var d := c - a
	var n := d.length()
	if n <= 0.0:
		return
	var u := d / n
	var v := Vector2(-u.y, u.x)
	var t := 2.5 * k
	while t < n - 2.0 * k:
		var p := a + u * t
		b.stroke(PackedVector2Array([p - v * 1.3 * k - u * k, p + v * 1.3 * k + u * k]), 0.9 * k, YARN_DEEP, false, false)
		t += 5.0 * k

func _pin_head(b: Face.Builder, at: Vector2, r: float) -> void:
	b.disc(at + Vector2(0.6, 1.0) * r * 0.25, r, Color(Pal.OUTLINE, 0.18))
	b.disc(at, r, PIN_DEEP)
	b.disc(at + Vector2(-0.2, -0.3) * r * 0.1, r * 0.82, PIN)
	b.disc(at + Vector2(-r * 0.3, -r * 0.32), r * 0.3, PIN_HI)

## A ball of yarn about `at`: a disc of `col` and its wraps.
func _ball(b: Face.Builder, at: Vector2, r: float, col: Color) -> void:
	b.disc(at, r, col.darkened(0.12))
	b.disc(at + Vector2(0.0, -r * 0.04), r * 0.96, col)
	for m in 5:
		var a := -0.9 + m * 0.42
		var pts := Face.Builder.arc_points(at + Vector2.from_angle(a + PI) * r * 0.55, r * 1.05, a - 0.75, a + 0.75)
		var inside := PackedVector2Array()
		for p in pts:
			if p.distance_to(at) < r * 0.94:
				inside.append(p)
		if inside.size() > 1:
			b.stroke(inside, r * 0.08, col.darkened(0.18))

## The go button: a ball of yarn in the card's colour over its shadow, a
## chevron on it, its loose end running to the pin in the heart's middle.
func _go(b: Face.Builder, at: Vector2, r: float) -> void:
	var k := _k()
	var pin := _pin(6)
	var from := at + Vector2(r * 0.7, r * 0.45)
	var tail := Face.Builder.bezier2(from, (from + pin) * 0.5 + Vector2(0.0, 26.0 * k), pin, 16)
	b.stroke(tail, 3.2 * k, colour.darkened(0.08))
	Scenery.soft_disc(b, at + Vector2(0.0, r * 0.85 + GO_LIFT * k), r * 1.0, r * 0.3, Color(Pal.TEXT, GO_SHADOW))
	_ball(b, at, r, colour)
	var h := r * 0.3
	b.stroke(PackedVector2Array([at + Vector2(-h * 0.55, -h), at + Vector2(h * 0.55, 0.0), at + Vector2(-h * 0.55, h)]),
		r * 0.17, Pal.SURFACE)

func _lay() -> void:
	var words := _words(String(entry.get("title", "")), SIDE, size.y * 0.5, WORDS, Pal.TEXT, BLURB)
	words.position.y = roundf(WORDS_TOP * size.y / H)
