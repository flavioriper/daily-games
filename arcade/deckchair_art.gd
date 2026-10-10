extends RefCounted

## Deckchair's cards and cloth (arcade/deckchair_table.gd draws with them).
## Everything is a mesh built once for a card's width and kept: a face is
## the cream card with its suit's two marks, a small one in the corner
## strip that shows when cards overlap and a big one below; its rank is
## lettered over it by the table (one text draw a card). A back is the
## deckchair's own canvas, striped, the house's sprout stamped in its middle.
## The cards are marks, so nothing here has a face.
##
## The cloth is a place: a pool of lamplight over the columns, thread
## stitched round its hem, the sprout embroidered at its foot, and in the
## one empty place of the top row a glass of lemonade on a straw coaster.
##
## A card's mesh has its top left corner at the origin and is `w` wide and
## `w * TALL` high.

const Face = preload("res://ui/faces/face.gd")
const Sim = preload("res://arcade/deckchair_sim.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

const TALL := 1.42
const CARD := Color("fffaf0")
const CARD_EDGE := Color("d6c6ab")
const RED := Color("d9564b")
const BLACK := Color("3d3944")
const STRIPE := Color("4c9a94")
const STRIPE_DEEP := Color("3a7a75")
const STRIPE_PALE := Color("fdf3dc")
const CLOTH := Color("8dba8c")
const CLOTH_DEEP := Color("74a57c")
const CLOTH_LINE := Color("5f9069")
const SHADE := Color(0.13, 0.22, 0.14, 0.2)
const HALO := Color("f5c23a")
## The cloth where the lamp falls on it, and the thread it is sewn with.
const CLOTH_LIT := Color("b4d9a6")
const THREAD := Color("d3ecc0")
## The light of a moment: the lamp's own, a red suit's and a black suit's,
## and the brass a card is framed in.
const LAMP := Color("fff6e0")
const GLOW := Color("ffe08a")
const LIGHT_RED := Color("ffb7a6")
const LIGHT_BLACK := Color("b9c8f6")
const BRASS := Color("d9a441")
## The glass: its coaster's straw, the glass, the lemonade and the lemon.
const STRAW := Color("e6c896")
const STRAW_DEEP := Color("b88f5c")
const GLASS := Color("f3fbf6")
const GLASS_EDGE := Color("c5ddd2")
const LEMONADE := Color("f6dc6e")
const LEMONADE_LIT := Color("fdf0a8")
const LEMON := Color("f2c53b")
## How far down a column can ever reach, in cards' heights: a king over six
## cards face down, built to its ace.
const REACH := 4.96
const RANKS := ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]

static var _cache := {}

static func _made(key: String, build: Callable) -> ArrayMesh:
	if _cache.has(key):
		return _cache[key]
	if _cache.size() > 60:
		_cache.clear()
	var b := Face.Builder.new()
	build.call(b)
	var m := b.mesh()
	_cache[key] = m
	return m

static func ink(card: int) -> Color:
	return RED if Sim.is_red(card) else BLACK

static func size(w: float) -> Vector2:
	return Vector2(w, w * TALL)

## A card's face, less its rank.
static func face(suit: int, w: float) -> ArrayMesh:
	return _made("face%d/%.1f" % [suit, w], func(b: Face.Builder) -> void:
		_body(b, w, CARD)
		var col := RED if suit % 2 == 1 else BLACK
		pip(b, suit, Vector2(0.77, 0.21) * w, 0.115 * w, col)
		pip(b, suit, Vector2(0.5, 0.9) * w, 0.27 * w, col))

static func back(w: float) -> ArrayMesh:
	return _made("back/%.1f" % w, func(b: Face.Builder) -> void:
		_body(b, w, CARD)
		var inset := 0.085 * w
		var at := Vector2(inset, inset)
		var sz := size(w) - at * 2.0
		b.polygon(Face.Builder.round_rect(at, sz, 0.05 * w), STRIPE)
		# the canvas: a broad pale stripe, then a thin one, across the panel
		var n := 4
		var step := sz.x / float(n)
		for k in n:
			var x := at.x + step * (k + 0.5)
			_bar(b, x - step * 0.2, at.y, step * 0.4, sz.y, STRIPE_PALE)
		for k in n - 1:
			var x := at.x + step * (k + 1.0)
			_bar(b, x - step * 0.04, at.y, step * 0.08, sz.y, STRIPE_DEEP)
		# the house's stamp: a sprout on a cream button
		var mid := size(w) * 0.5
		b.disc(mid + Vector2(0, 0.012 * w), 0.235 * w, STRIPE_DEEP)
		b.disc(mid, 0.22 * w, STRIPE_PALE)
		b.stroke(Face.Builder.ring(mid, 0.17 * w, 0.17 * w), maxf(1.0, 0.014 * w), Color(STRIPE, 0.7), true)
		sprout(b, mid + Vector2(0, 0.015 * w), 0.0072 * w, STRIPE_DEEP))

## The shadow a lifted card throws, laid under it.
static func shadow(w: float) -> ArrayMesh:
	return _made("shadow/%.1f" % w, func(b: Face.Builder) -> void:
		b.polygon(Face.Builder.round_rect(Vector2(-0.02, 0.03) * w, size(w) + Vector2(0.04, 0.04) * w, 0.1 * w), Color(SHADE, 0.3)))

## A ring round a card: where a carried card may be set down, or the hint.
static func halo(w: float) -> ArrayMesh:
	return _made("halo/%.1f" % w, func(b: Face.Builder) -> void:
		var grow := 0.045 * w
		b.stroke(Face.Builder.round_rect(Vector2(-grow, -grow), size(w) + Vector2(grow, grow) * 2.0, 0.12 * w), 0.07 * w, HALO, true))

static func _body(b: Face.Builder, w: float, fill: Color) -> void:
	var sz := size(w)
	var r := 0.09 * w
	b.polygon(Face.Builder.round_rect(Vector2(0, 0.022 * w), sz, r), SHADE)
	b.polygon(Face.Builder.round_rect(Vector2.ZERO, sz, r), CARD_EDGE)
	var line := maxf(1.0, 0.016 * w)
	b.polygon(Face.Builder.round_rect(Vector2(line, line), sz - Vector2(line, line) * 2.0, r - line), fill)

static func _bar(b: Face.Builder, x: float, y: float, bw: float, bh: float, col: Color) -> void:
	b.polygon(PackedVector2Array([Vector2(x, y), Vector2(x + bw, y), Vector2(x + bw, y + bh), Vector2(x, y + bh)]), col)

## A suit's mark, `r` from its middle to its side: spade, heart, club,
## diamond, in the sim's order.
static func pip(b: Face.Builder, suit: int, c: Vector2, r: float, col: Color) -> void:
	match suit:
		1:
			_heart(b, c, r, col, 1.0)
		3:
			b.polygon(PackedVector2Array([c + Vector2(0, -1.12) * r, c + Vector2(0.84, 0) * r, c + Vector2(0, 1.12) * r, c + Vector2(-0.84, 0) * r]), col)
		0:
			_heart(b, c + Vector2(0, -0.12) * r, r, col, -1.0)
			_stem(b, c + Vector2(0, 0.2) * r, r, col)
		2:
			b.disc(c + Vector2(0, -0.5) * r, 0.46 * r, col)
			b.disc(c + Vector2(-0.5, 0.18) * r, 0.46 * r, col)
			b.disc(c + Vector2(0.5, 0.18) * r, 0.46 * r, col)
			b.disc(c + Vector2(0, 0.02) * r, 0.3 * r, col)
			_stem(b, c + Vector2(0, 0.2) * r, r, col)

## Two lobes and a point: a heart, or turned over (`way` -1) a spade's head.
static func _heart(b: Face.Builder, c: Vector2, r: float, col: Color, way: float) -> void:
	b.disc(c + Vector2(-0.46, -0.34 * way) * r, 0.52 * r, col)
	b.disc(c + Vector2(0.46, -0.34 * way) * r, 0.52 * r, col)
	b.polygon(PackedVector2Array([c + Vector2(-0.93, -0.1 * way) * r, c + Vector2(0, -0.5 * way) * r,
		c + Vector2(0.93, -0.1 * way) * r, c + Vector2(0, 1.02 * way) * r]), col)

static func _stem(b: Face.Builder, c: Vector2, r: float, col: Color) -> void:
	b.polygon(PackedVector2Array([c + Vector2(-0.1, 0) * r, c + Vector2(0.1, 0) * r, c + Vector2(0.36, 0.86) * r, c + Vector2(-0.36, 0.86) * r]), col)

## The cloth under the cards: paler at the top, a pool of lamplight over
## the columns, thread stitched round the hem, and, where a column never
## reaches (`row` the columns' top, `w` a card's width), the sprout
## embroidered in a stitched ring. `glass_at` is where the glass stands
## (`glass` its coaster's radius, 0 for none).
static func cloth(sz: Vector2, w := 0.0, row := 0.0, glass_at := Vector2.ZERO, glass_r := 0.0) -> ArrayMesh:
	var b := Face.Builder.new()
	var a := b.vertex(Vector2.ZERO, CLOTH)
	var c := b.vertex(Vector2(sz.x, 0), CLOTH)
	var d := b.vertex(sz, CLOTH_DEEP)
	var e := b.vertex(Vector2(0, sz.y), CLOTH_DEEP)
	b.tri(a, c, d)
	b.tri(a, d, e)
	if w <= 0.0:
		return b.mesh()
	var h := w * TALL
	Scenery.soft_disc(b, Vector2(sz.x * 0.5, row + h * 1.9), sz.x * 0.62, h * 3.3, Color(CLOTH_LIT, 0.62))
	var inset := 0.045 * w
	stitch(b, Face.Builder.round_rect(Vector2(inset, inset), sz - Vector2(inset, inset) * 2.0, 0.2 * w), 0.13 * w, 0.085 * w, maxf(1.5, 0.024 * w), Color(THREAD, 0.8))
	var foot := row + h * REACH
	if sz.y - foot > 1.7 * w:
		var mid := Vector2(sz.x * 0.5, (foot + sz.y) * 0.5)
		var r := minf(0.62 * w, (sz.y - foot) * 0.36)
		Scenery.soft_disc(b, mid, r * 1.5, r * 1.5, Color(CLOTH_LIT, 0.3))
		stitch(b, Face.Builder.ring(mid, r, r), 0.11 * w, 0.075 * w, maxf(1.5, 0.022 * w), Color(THREAD, 0.7))
		sprout(b, mid + Vector2(0, 0.04 * r), r * 0.021, Color(THREAD, 0.85))
		# a leaf of thread either side, leaning away
		for way: float in [-1.0, 1.0]:
			var at := mid + Vector2(way * r * 1.75, r * 0.3)
			leaf(b, at, at + Vector2(way * 0.55, -0.55) * r, 0.17 * r, Color(THREAD, 0.6))
			leaf(b, at + Vector2(way * 0.1, 0.12) * r, at + Vector2(way * 0.75, 0.1) * r, 0.14 * r, Color(THREAD, 0.5))
	if glass_r > 0.0:
		_glass(b, glass_at, glass_r)
	return b.mesh()

## A glass of lemonade seen from above, on a woven straw coaster `r` across
## its half: two cubes of ice, a slice of lemon and a striped paper straw.
static func _glass(b: Face.Builder, c: Vector2, r: float) -> void:
	b.disc(c + Vector2(0.04, 0.14) * r, r, Color(SHADE, 0.3))
	b.disc(c + Vector2(0, 0.06) * r, r, STRAW_DEEP)
	b.disc(c, r, STRAW)
	for k in 3:
		b.stroke(Face.Builder.ring(c, r * (0.9 - 0.2 * k), r * (0.9 - 0.2 * k)), maxf(1.0, 0.045 * r), Color(STRAW_DEEP, 0.55), true)
	var g := 0.7 * r
	b.disc(c + Vector2(0.03, 0.1) * r, g, Color(SHADE, 0.3))
	b.disc(c, g, GLASS_EDGE)
	b.disc(c, g * 0.92, GLASS)
	b.disc(c, g * 0.8, LEMONADE)
	b.disc(c + Vector2(-0.1, -0.1) * g, g * 0.5, Color(LEMONADE_LIT, 0.55))
	for at: Vector2 in [Vector2(-0.3, 0.2), Vector2(0.12, 0.36)]:
		var q := c + at * g
		var s := 0.3 * g
		b.polygon(Face.Builder.round_rect(q - Vector2(s, s) * 0.5, Vector2(s, s), s * 0.25), Color(1, 1, 1, 0.5))
	# the slice, at the rim
	var l := c + Vector2(0.3, -0.26) * g
	b.disc(l, 0.4 * g, LEMON)
	b.disc(l, 0.31 * g, LEMONADE_LIT)
	for k in 3:
		var dir := Vector2.from_angle(PI * k / 3.0 + 0.3) * 0.3 * g
		b.stroke(PackedVector2Array([l - dir, l + dir]), maxf(1.0, 0.045 * g), Color(LEMON, 0.9))
	# the straw, leaning out up and to the left, banded
	var from := c + Vector2(-0.08, 0.1) * g
	var to := c + Vector2(-0.95, -1.15) * g
	b.stroke(PackedVector2Array([from, to]), 0.2 * g, STRIPE_PALE)
	for k in 4:
		var u := 0.2 + 0.21 * k
		b.stroke(PackedVector2Array([from.lerp(to, u), from.lerp(to, u + 0.09)]), 0.2 * g, STRIPE, false, false)

## A leaf from its foot to its tip, `bulge` wide at the middle.
static func leaf(b: Face.Builder, foot: Vector2, tip: Vector2, bulge: float, col: Color) -> void:
	var mid := (foot + tip) * 0.5
	var n := (tip - foot).orthogonal().normalized() * bulge
	var pts := Face.Builder.bezier2(foot, mid + n, tip, 8)
	pts.append_array(Face.Builder.bezier2(tip, mid - n, foot, 8))
	b.fan(pts, col)

## The house's sprout about `c`: a stem and its two leaves, `k` times 30 tall.
static func sprout(b: Face.Builder, c: Vector2, k: float, col: Color) -> void:
	b.stroke(Face.Builder.bezier2(c + Vector2(1.0, 16.0) * k, c + Vector2(-3.0, 6.0) * k, c + Vector2(0.0, -4.0) * k, 6), 3.4 * k, col)
	leaf(b, c + Vector2(0.0, -3.0) * k, c + Vector2(-17.0, -17.0) * k, 9.0 * k, col)
	leaf(b, c + Vector2(0.0, -1.0) * k, c + Vector2(14.0, -12.0) * k, 7.0 * k, col)

## Dashes of thread along a closed outline.
static func stitch(b: Face.Builder, pts: PackedVector2Array, dash: float, gap: float, width: float, col: Color) -> void:
	var run := PackedVector2Array()
	var left := dash
	var on := true
	for i in pts.size():
		var a := pts[i]
		var to := pts[(i + 1) % pts.size()]
		var seg := a.distance_to(to)
		var done := 0.0
		if on and run.is_empty():
			run.append(a)
		while seg - done > left:
			done += left
			var p := a.lerp(to, done / seg)
			if on:
				run.append(p)
				b.stroke(run, width, col)
				run = PackedVector2Array()
			else:
				run = PackedVector2Array([p])
			on = not on
			left = dash if on else gap
		left -= seg - done
		if on:
			run.append(to)
	if on and run.size() > 1:
		b.stroke(run, width, col)

## A frame round a card whose top left corner is `at`, `grow` out from it.
static func frame_into(b: Face.Builder, at: Vector2, w: float, grow: float, width: float, col: Color) -> void:
	b.stroke(Face.Builder.round_rect(at - Vector2(grow, grow), size(w) + Vector2(grow, grow) * 2.0, 0.09 * w + grow), width, col, true)

## An empty place: a card's outline pressed into the cloth. `suit` at or
## over 0 marks a home with its suit; `loop` marks the stock's, a turning
## arrow for the waste going back.
static func slot_into(b: Face.Builder, at: Vector2, w: float, suit := -1, loop := false) -> void:
	var sz := size(w)
	b.polygon(Face.Builder.round_rect(at, sz, 0.09 * w), Color(CLOTH_LINE, 0.28))
	b.stroke(Face.Builder.round_rect(at, sz, 0.09 * w), maxf(2.0, 0.025 * w), Color(CLOTH_LINE, 0.75), true)
	var c := at + sz * 0.5
	if suit >= 0:
		pip(b, suit, c, 0.24 * w, Color(CLOTH_LINE, 0.7))
	if loop:
		var r := 0.2 * w
		b.stroke(Face.Builder.arc_points(c, r, -PI * 0.35, PI * 1.25), 0.055 * w, Color(CLOTH_LINE, 0.85))
		var tip := c + Vector2.from_angle(-PI * 0.35) * r
		b.polygon(PackedVector2Array([tip + Vector2(0.11, -0.02) * w, tip + Vector2(-0.07, -0.09) * w, tip + Vector2(-0.03, 0.1) * w]), Color(CLOTH_LINE, 0.85))
