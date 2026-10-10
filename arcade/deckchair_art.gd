extends RefCounted

## Deckchair's cards and cloth (arcade/deckchair_table.gd draws with them).
## Everything is a mesh built once for a card's width and kept: a face is
## the cream card with its suit's two marks, a small one in the corner
## strip that shows when cards overlap and a big one below; its rank is
## lettered over it by the table (one text draw a card). A back is the
## deckchair's own canvas, striped. The cards are marks, so nothing here has
## a face.
##
## A card's mesh has its top left corner at the origin and is `w` wide and
## `w * TALL` high.

const Face = preload("res://ui/faces/face.gd")
const Sim = preload("res://arcade/deckchair_sim.gd")

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
			_bar(b, x - step * 0.04, at.y, step * 0.08, sz.y, STRIPE_DEEP))

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

## The cloth under the cards: paler at the top, with a stitched line round it.
static func cloth(sz: Vector2) -> ArrayMesh:
	var b := Face.Builder.new()
	var a := b.vertex(Vector2.ZERO, CLOTH)
	var c := b.vertex(Vector2(sz.x, 0), CLOTH)
	var d := b.vertex(sz, CLOTH_DEEP)
	var e := b.vertex(Vector2(0, sz.y), CLOTH_DEEP)
	b.tri(a, c, d)
	b.tri(a, d, e)
	return b.mesh()

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
