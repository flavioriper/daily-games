extends RefCounted

## Bagatelle's drawings (arcade/bagatelle_board.gd lays them). A board of
## plum velvet; brass pins; matte marbles, a colour a tier and from the
## fourth tier bands of cream round them (so a tier is never only a hue);
## turned wooden cups along the foot; a brass dropper. Everything is built
## once in the sim's field units and laid by the board's transform, so
## nothing is keyed by a size that changes.

const Face = preload("res://ui/faces/face.gd")
const Sim = preload("res://arcade/bagatelle_sim.gd")

const VELVET_TOP := Color("4a3a5e")
const VELVET_LOW := Color("2c2238")
const VELVET_NAP := Color(1.0, 0.95, 1.0, 0.035)
const BRASS := Color("e3b65c")
const BRASS_DEEP := Color("a9803a")
const BRASS_HI := Color("fbe3a6")
const WOOD := Color("c8a17a")
const WOOD_DEEP := Color("8f6a48")
const WOOD_HI := Color("e3c39b")
const FELT := Color("3b5b4a")
const CREAM := Color("fffaf0")
const INK := Color("3b3028")
const SHADE := Color(0.08, 0.04, 0.1, 0.35)
const PLUS := Color("f5c542")
const TIMES := Color("f08aa0")
const HALO := Color("ffe7a8")
## The tiers' colours, Clay to Star.
const TIER := [
	Color("eadbc4"), Color("8fd0e6"), Color("e8a07a"), Color("97c785"),
	Color("f2cd5c"), Color("c6b0e6"), Color("dfe7f0"), Color("f6e1e6"),
	Color("e2645c"), Color("9fdcd2"), Color("7f93d6"), Color("f5a623"),
]

static var _cache := {}

static func _keep(key, b: Face.Builder) -> ArrayMesh:
	var m := b.mesh()
	_cache[key] = m
	return m

static func tier_colour(k: int) -> Color:
	return TIER[clampi(k, 0, TIER.size() - 1)]

## A marble of tier `k`, radius `r`, about (0, 0).
static func marble(k: int, r := Sim.BALL_R) -> ArrayMesh:
	var key := ["marble", k, r]
	if _cache.has(key):
		return _cache[key]
	var b := Face.Builder.new()
	b.detail = maxf(1.0, r / 15.0)
	var c := tier_colour(k)
	b.disc(Vector2(0, r * 0.18), r * 1.02, SHADE)
	b.disc(Vector2.ZERO, r, c)
	# the lower side in shade: a crescent of the darker colour
	b.ellipse(Vector2(0, r * 0.32), r * 0.86, r * 0.62, c.darkened(0.16))
	b.disc(Vector2(0, -r * 0.08), r * 0.8, c)
	# bands from the fourth tier: one, then two from the seventh, then three
	var bands := 0 if k < 3 else (1 if k < 6 else (2 if k < 9 else 3))
	for i in bands:
		var a := -0.5 + 1.1 * i
		var pts := PackedVector2Array()
		for j in 9:
			var u := lerpf(-1.0, 1.0, j / 8.0)
			pts.append(Vector2(u * r * 0.82, sin(u * 2.2 + a) * r * 0.3 + (i - (bands - 1) * 0.5) * r * 0.42))
		b.stroke(pts, maxf(2.0, r * 0.16), Color(CREAM, 0.85))
	# a matte sheen, soft and low
	b.ellipse(Vector2(-r * 0.32, -r * 0.4), r * 0.34, r * 0.22, Color(1, 1, 1, 0.38))
	return _keep(key, b)

## The ring a marble wears once a bonus pin has touched it.
static func boost_ring(kind: String, r := Sim.BALL_R) -> ArrayMesh:
	var key := ["ring", kind, r]
	if _cache.has(key):
		return _cache[key]
	var b := Face.Builder.new()
	b.stroke(Face.Builder.ring(Vector2.ZERO, r + 4.0, r + 4.0), 3.5, PLUS if kind == "plus" else TIMES, true)
	return _keep(key, b)

## One brass pin.
static func pin(r := Sim.PIN_R) -> ArrayMesh:
	var key := ["pin", r]
	if _cache.has(key):
		return _cache[key]
	var b := Face.Builder.new()
	_pin_into(b, Vector2.ZERO, r, BRASS)
	return _keep(key, b)

static func _pin_into(b: Face.Builder, p: Vector2, r: float, col: Color) -> void:
	b.disc(p + Vector2(1.5, 3.0), r, SHADE)
	b.disc(p, r, col.darkened(0.25))
	b.disc(p + Vector2(-0.6, -0.8), r * 0.78, col)
	b.disc(p + Vector2(-r * 0.3, -r * 0.35), r * 0.3, Color(BRASS_HI, 0.9))

## Every pin of the board, one mesh.
static func pins() -> ArrayMesh:
	if _cache.has("pins"):
		return _cache["pins"]
	var b := Face.Builder.new()
	for r in Sim.ROWS:
		for i in Sim.row_count(r):
			if Sim.has_pin(r, i):
				_pin_into(b, Sim.pin_at(r, i), Sim.PIN_R, BRASS)
	return _keep("pins", b)

## A bonus pin: a larger pin of its colour with a soft halo and its mark.
static func bonus_pin(kind: String) -> ArrayMesh:
	var key := ["bonus", kind]
	if _cache.has(key):
		return _cache[key]
	var b := Face.Builder.new()
	var col := PLUS if kind == "plus" else TIMES
	b.disc(Vector2.ZERO, Sim.PIN_R * 2.6, Color(col, 0.16))
	b.disc(Vector2.ZERO, Sim.PIN_R * 1.9, Color(col, 0.22))
	_pin_into(b, Vector2.ZERO, Sim.PIN_R * 1.35, col)
	var s := Sim.PIN_R * 0.55
	if kind == "plus":
		b.stroke(PackedVector2Array([Vector2(-s, 0), Vector2(s, 0)]), 2.6, INK)
		b.stroke(PackedVector2Array([Vector2(0, -s), Vector2(0, s)]), 2.6, INK)
	else:
		b.stroke(PackedVector2Array([Vector2(-s, -s), Vector2(s, s)]), 2.6, INK)
		b.stroke(PackedVector2Array([Vector2(-s, s), Vector2(s, -s)]), 2.6, INK)
	return _keep(key, b)

## A pin's glow as it is touched: a soft disc, never rays.
static func halo() -> ArrayMesh:
	if _cache.has("halo"):
		return _cache["halo"]
	var b := Face.Builder.new()
	b.disc(Vector2.ZERO, Sim.PIN_R * 2.8, Color(HALO, 0.18))
	b.disc(Vector2.ZERO, Sim.PIN_R * 1.9, Color(HALO, 0.3))
	b.disc(Vector2.ZERO, Sim.PIN_R * 1.15, Color(HALO, 0.75))
	return _keep("halo", b)

## One cup, its top at y 0 and its middle across at x 0, CUP_W wide.
static func cup(c: int) -> ArrayMesh:
	var key := ["cup", c]
	if _cache.has(key):
		return _cache[key]
	var b := Face.Builder.new()
	var w := Sim.CUP_W - 10.0
	var h := Sim.H - Sim.CUP_TOP + 6.0
	var x0 := -w * 0.5
	b.polygon(Face.Builder.round_rect(Vector2(x0 + 2.0, 6.0), Vector2(w, h), 18.0), SHADE)
	b.polygon(Face.Builder.round_rect(Vector2(x0, 0.0), Vector2(w, h), 18.0), WOOD_DEEP)
	b.polygon(Face.Builder.round_rect(Vector2(x0 + 6.0, 4.0), Vector2(w - 12.0, h - 14.0), 14.0), WOOD)
	# the felt inside, and the turned rim
	b.polygon(Face.Builder.round_rect(Vector2(x0 + 14.0, 16.0), Vector2(w - 28.0, h - 40.0), 12.0), FELT.lerp(WOOD_DEEP, 0.15 * absf(c - 3)))
	b.polygon(Face.Builder.round_rect(Vector2(x0 + 2.0, -6.0), Vector2(w - 4.0, 14.0), 7.0), WOOD_HI)
	return _keep(key, b)

## The dropper: a little brass funnel on a rail.
static func dropper() -> ArrayMesh:
	if _cache.has("dropper"):
		return _cache["dropper"]
	var b := Face.Builder.new()
	b.polygon(PackedVector2Array([Vector2(-26, -30), Vector2(26, -30), Vector2(9, 0), Vector2(-9, 0)]), BRASS_DEEP)
	b.polygon(PackedVector2Array([Vector2(-22, -28), Vector2(22, -28), Vector2(7, -3), Vector2(-7, -3)]), BRASS)
	b.polygon(Face.Builder.round_rect(Vector2(-30, -38), Vector2(60, 12), 6.0), BRASS_HI)
	return _keep("dropper", b)

## The rail the dropper glides on, across the top.
static func rail() -> ArrayMesh:
	if _cache.has("rail"):
		return _cache["rail"]
	var b := Face.Builder.new()
	var y := Sim.DROP_Y - 38.0
	b.polygon(Face.Builder.round_rect(Vector2(20, y - 3), Vector2(Sim.W - 40, 8), 4.0), Color(BRASS_DEEP, 0.7))
	b.disc(Vector2(20, y + 1), 7.0, BRASS)
	b.disc(Vector2(Sim.W - 20, y + 1), 7.0, BRASS)
	return _keep("rail", b)

## The velvet, `size` pixels: a soft fall from top to foot, a faint nap of
## stripes, and a dimmer edge.
static func velvet(size: Vector2) -> ArrayMesh:
	var key := ["velvet", size]
	if _cache.has(key):
		return _cache[key]
	var b := Face.Builder.new()
	var steps := 24
	for i in steps:
		var y0 := size.y * i / steps
		var y1 := size.y * (i + 1) / steps + 1.0
		var c := VELVET_TOP.lerp(VELVET_LOW, pow(float(i) / (steps - 1), 1.3))
		var a := b.vertex(Vector2(0, y0), c)
		var bb := b.vertex(Vector2(size.x, y0), c)
		var cc := b.vertex(Vector2(size.x, y1), c)
		var d := b.vertex(Vector2(0, y1), c)
		b.tri(a, bb, cc)
		b.tri(a, cc, d)
	var x := 0.0
	while x < size.x:
		b.polygon(PackedVector2Array([Vector2(x, 0), Vector2(x + 18, 0), Vector2(x + 18, size.y), Vector2(x, size.y)]), VELVET_NAP)
		x += 64.0
	# the edges a little darker, as a board's velvet sinks at its frame
	for side in 2:
		for j in 6:
			var w := 10.0 * (j + 1)
			var xx := 0.0 if side == 0 else size.x - w
			b.polygon(PackedVector2Array([Vector2(xx, 0), Vector2(xx + w, 0), Vector2(xx + w, size.y), Vector2(xx, size.y)]), Color(0, 0, 0, 0.025))
	return _keep(key, b)

## A star (the second currency), radius `r`.
static func star(r: float) -> ArrayMesh:
	var key := ["star", r]
	if _cache.has(key):
		return _cache[key]
	var b := Face.Builder.new()
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI * 0.5 + TAU * i / 10.0
		pts.append(Vector2.from_angle(a) * (r if i % 2 == 0 else r * 0.48))
	var sh := PackedVector2Array()
	for p in pts:
		sh.append(p + Vector2(0, r * 0.12))
	b.polygon(sh, Color(0.3, 0.2, 0.1, 0.25))
	b.polygon(pts, Color("f5b83d"))
	var inner := PackedVector2Array()
	for p in pts:
		inner.append(p * 0.62 + Vector2(-r * 0.05, -r * 0.06))
	b.polygon(inner, Color("fbd06a"))
	return _keep(key, b)

## A coin, radius `r`.
static func coin(r: float) -> ArrayMesh:
	var key := ["coin", r]
	if _cache.has(key):
		return _cache[key]
	var b := Face.Builder.new()
	b.disc(Vector2(0, r * 0.12), r, Color(0.3, 0.2, 0.1, 0.25))
	b.disc(Vector2.ZERO, r, Color("d99a2b"))
	b.disc(Vector2(0, -r * 0.05), r * 0.8, Color("f5c04a"))
	b.stroke(Face.Builder.ring(Vector2(0, -r * 0.05), r * 0.56, r * 0.56), maxf(1.5, r * 0.1), Color("d99a2b"), true)
	return _keep(key, b)
