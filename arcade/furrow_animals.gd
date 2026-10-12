extends RefCounted

## Furrow's animals and their pens, drawn as builder shapes like the rest
## of the field (arcade/furrow_art.gd): the hens, the rooster and the
## chicks of the coop, the eggs they leave on the ground, the cows of the
## pasture and the bottle a full one shows, the fox, and the two round pens
## with their fences. Every animal is drawn looking right with its feet at
## the origin; the field (arcade/furrow_field.gd) turns one by its draw
## transform and never rebuilds it to move it.
##
## A pen is a round of ground seen from the same corner as the lots, so an
## oval `rx` by `ry`: its ground, its far fence and what stands in it are
## one mesh (`pen_back`), drawn before the animals, and its near fence
## another (`pen_front`), drawn over them.

const Art = preload("res://arcade/furrow_art.gd")
const Face = preload("res://ui/faces/face.gd")

const HEN := Color("fff6e6")
const HEN_SHADE := Color("ecdcc0")
const COMB := Color("e2504a")
const BEAK := Color("f2a23a")
const ROOSTER := Color("cf6f3c")
const ROOSTER_SHADE := Color("a8532a")
const TAIL := Color("2f6a5e")
const TAIL_HI := Color("4a8f7c")
const CHICK := Color("ffdf6b")
const CHICK_SHADE := Color("f2c14e")
const COW := Color("fbf6ea")
const COW_SHADE := Color("e6dcc6")
const PATCH := Color("8a5a3c")
const PINK := Color("f4b5b0")
const HOOF := Color("5c4636")
const FOX := Color("e07a3a")
const FOX_DEEP := Color("b9582a")
const SHELL := Color("fff3dc")
const SHELL_SHADE := Color("e9d3ae")
const GLASS := Color("ffffff")
const CAP := Color("6fa8dc")
const STRAW := Color("ecc55a")

static var _cache := {}

static func _made(key: String, build: Callable) -> ArrayMesh:
	if _cache.has(key):
		return _cache[key]
	if _cache.size() > 120:
		_cache.clear()
	var b := Face.Builder.new()
	build.call(b)
	var m := b.mesh()
	_cache[key] = m
	return m

# --- the coop ---

## A hen `s` pixels tall, or the rooster.
static func hen(s: float, rooster := false) -> ArrayMesh:
	return _made("hen%.1f/%s" % [s, rooster], func(b: Face.Builder) -> void: hen_into(b, Vector2.ZERO, s, rooster))

static func hen_into(b: Face.Builder, at: Vector2, s: float, rooster := false) -> void:
	var body := ROOSTER if rooster else HEN
	var shade := ROOSTER_SHADE if rooster else HEN_SHADE
	Art.soft(b, at + Vector2(0, s * 0.02), s * 0.5, s * 0.16, Color(0.2, 0.2, 0.1, 0.34))
	for x in [-0.1, 0.12]:
		b.stroke(PackedVector2Array([at + Vector2(x * s, -s * 0.24), at + Vector2(x * s, -s * 0.02)]), s * 0.05, BEAK)
		b.stroke(PackedVector2Array([at + Vector2(x * s - s * 0.05, 0), at + Vector2(x * s + s * 0.09, 0)]), s * 0.05, BEAK)
	# the tail
	var root := at + Vector2(-s * 0.3, -s * 0.5)
	if rooster:
		for row: Array in [[-0.5, -0.36, TAIL], [-0.42, -0.6, TAIL_HI], [-0.2, -0.7, TAIL]]:
			Art._lens(b, root, root + Vector2(float(row[0]), float(row[1])) * s, s * 0.14, row[2])
	else:
		for row: Array in [[-0.3, -0.2], [-0.24, -0.36]]:
			Art._lens(b, root, root + Vector2(float(row[0]), float(row[1])) * s, s * 0.1, shade)
	b.ellipse(at + Vector2(0, -s * 0.44), s * 0.4, s * 0.31, shade)
	b.ellipse(at + Vector2(0.01 * s, -s * 0.47), s * 0.38, s * 0.28, body)
	# the neck and the head
	b.fan(PackedVector2Array([at + Vector2(s * 0.08, -s * 0.5), at + Vector2(s * 0.36, -s * 0.44), at + Vector2(s * 0.42, -s * 0.8), at + Vector2(s * 0.2, -s * 0.82)]), GOLD_NECK if rooster else body)
	var head := at + Vector2(s * 0.32, -s * 0.84)
	for k in 3:
		b.disc(head + Vector2((k - 1) * s * 0.08 - s * 0.02, -s * (0.16 if k == 1 else 0.13)) * (1.3 if rooster else 1.0), s * (0.075 if rooster else 0.055), COMB)
	b.disc(head, s * 0.17, GOLD_NECK if rooster else body)
	b.fan(PackedVector2Array([head + Vector2(s * 0.13, -s * 0.06), head + Vector2(s * 0.32, s * 0.02), head + Vector2(s * 0.13, s * 0.07)]), BEAK)
	b.ellipse(head + Vector2(s * 0.14, s * 0.14), s * 0.045, s * (0.09 if rooster else 0.06), COMB)
	b.disc(head + Vector2(s * 0.05, -s * 0.03), s * 0.032, Art.INK)
	# the wing
	b.ellipse(at + Vector2(-s * 0.06, -s * 0.44), s * 0.22, s * 0.15, shade)
	b.stroke(Face.Builder.bezier2(at + Vector2(-s * 0.22, -s * 0.4), at + Vector2(-s * 0.06, -s * 0.3), at + Vector2(s * 0.12, -s * 0.42), 6), s * 0.03, Color(Art.INK, 0.2))

const GOLD_NECK := Color("e9a53c")

## A chick `s` pixels tall.
static func chick(s: float) -> ArrayMesh:
	return _made("chick%.1f" % s, func(b: Face.Builder) -> void:
		Art.soft(b, Vector2(0, s * 0.04), s * 0.5, s * 0.18, Color(0.2, 0.2, 0.1, 0.3))
		for x in [-0.12, 0.12]:
			b.stroke(PackedVector2Array([Vector2(x * s, -s * 0.2), Vector2(x * s, 0)]), s * 0.07, BEAK)
		b.disc(Vector2(0, -s * 0.44), s * 0.36, CHICK_SHADE)
		b.disc(Vector2(0.02 * s, -s * 0.47), s * 0.33, CHICK)
		b.disc(Vector2(s * 0.2, -s * 0.78), s * 0.24, CHICK)
		b.fan(PackedVector2Array([Vector2(s * 0.4, -s * 0.84), Vector2(s * 0.62, -s * 0.76), Vector2(s * 0.4, -s * 0.7)]), BEAK)
		b.disc(Vector2(s * 0.27, -s * 0.83), s * 0.05, Art.INK)
		b.ellipse(Vector2(-s * 0.1, -s * 0.44), s * 0.16, s * 0.11, CHICK_SHADE))

## An egg `s` pixels tall, lying on the ground at the origin.
static func egg(s: float) -> ArrayMesh:
	return _made("egg%.1f" % s, func(b: Face.Builder) -> void: egg_into(b, Vector2.ZERO, s))

static func egg_into(b: Face.Builder, at: Vector2, s: float) -> void:
	Art.soft(b, at + Vector2(s * 0.04, s * 0.06), s * 0.6, s * 0.24, Color(0.2, 0.18, 0.1, 0.36))
	b.ellipse(at + Vector2(0, -s * 0.42), s * 0.39, s * 0.5, SHELL_SHADE)
	b.ellipse(at + Vector2(-s * 0.02, -s * 0.45), s * 0.35, s * 0.46, SHELL)
	b.ellipse(at + Vector2(-s * 0.12, -s * 0.62), s * 0.1, s * 0.15, Color(1, 1, 1, 0.85))

## The hens' house, `u` pixels a unit, its foot at the origin: boards on
## four legs, a round door, a ramp down, a red roof.
static func hutch(b: Face.Builder, at: Vector2, u: float) -> void:
	Art.soft(b, at + Vector2(6.0 * u, 2.0 * u), 50.0 * u, 16.0 * u, Color(0.2, 0.2, 0.1, 0.36))
	for x in [-26.0, 22.0]:
		b.fan(Face.Builder.round_rect(at + Vector2(x * u, -16.0 * u), Vector2(5.0 * u, 17.0 * u), 2.0 * u), Art.WOOD_DEEP)
	b.fan(Face.Builder.round_rect(at + Vector2(-32.0 * u, -52.0 * u), Vector2(64.0 * u, 40.0 * u), 6.0 * u), Art.WOOD_DEEP)
	b.fan(Face.Builder.round_rect(at + Vector2(-30.0 * u, -52.0 * u), Vector2(60.0 * u, 36.0 * u), 5.0 * u), Art.WOOD_HI)
	for k in 3:
		b.stroke(PackedVector2Array([at + Vector2(-28.0 * u, (-44.0 + 9.0 * k) * u), at + Vector2(28.0 * u, (-44.0 + 9.0 * k) * u)]), 1.4 * u, Color(Art.WOOD_DEEP, 0.5), false, false)
	b.fan(Face.Builder.round_rect(at + Vector2(-9.0 * u, -40.0 * u), Vector2(18.0 * u, 24.0 * u), 9.0 * u), Color("5a4332"))
	# the ramp
	b.fan(PackedVector2Array([at + Vector2(-8.0 * u, -16.0 * u), at + Vector2(8.0 * u, -16.0 * u), at + Vector2(22.0 * u, 2.0 * u), at + Vector2(6.0 * u, 2.0 * u)]), Art.WOOD)
	for k in 3:
		b.stroke(PackedVector2Array([at + Vector2((-5.0 + 5.0 * k) * u, (-12.0 + 5.0 * k) * u), at + Vector2((9.0 + 5.0 * k) * u, (-12.0 + 5.0 * k) * u)]), 1.6 * u, Art.WOOD_DEEP, false, false)
	b.fan(PackedVector2Array([at + Vector2(-40.0 * u, -50.0 * u), at + Vector2(40.0 * u, -50.0 * u), at + Vector2(0, -80.0 * u)]), Art.ROOF_DEEP)
	b.fan(PackedVector2Array([at + Vector2(-40.0 * u, -52.0 * u), at + Vector2(36.0 * u, -52.0 * u), at + Vector2(-2.0 * u, -80.0 * u)]), Art.ROOF)
	b.stroke(PackedVector2Array([at + Vector2(-40.0 * u, -51.0 * u), at + Vector2(40.0 * u, -51.0 * u)]), 3.0 * u, Art.ROOF_DEEP.darkened(0.15))

# --- the pasture ---

## A cow `s` pixels long, looking right; `full` shows her udder heavy.
static func cow(s: float, full := false) -> ArrayMesh:
	return _made("cow%.1f/%s" % [s, full], func(b: Face.Builder) -> void: cow_into(b, Vector2.ZERO, s, full))

static func cow_into(b: Face.Builder, at: Vector2, s: float, full := false) -> void:
	Art.soft(b, at + Vector2(s * 0.03, s * 0.02), s * 0.6, s * 0.15, Color(0.2, 0.2, 0.1, 0.36))
	# the far legs, then the tail, the body and the near legs
	for x in [-0.27, 0.2]:
		b.fan(Face.Builder.round_rect(at + Vector2(x * s, -s * 0.3), Vector2(s * 0.085, s * 0.3), s * 0.03), COW_SHADE.darkened(0.08))
		b.fan(Face.Builder.round_rect(at + Vector2(x * s, -s * 0.06), Vector2(s * 0.085, s * 0.06), s * 0.02), HOOF)
	b.stroke(Face.Builder.bezier2(at + Vector2(-s * 0.4, -s * 0.5), at + Vector2(-s * 0.52, -s * 0.46), at + Vector2(-s * 0.48, -s * 0.2), 8), s * 0.03, COW_SHADE)
	b.disc(at + Vector2(-s * 0.48, -s * 0.18), s * 0.04, PATCH)
	b.ellipse(at + Vector2(-s * 0.2, -s * 0.2), s * (0.1 if full else 0.075), s * (0.085 if full else 0.06), PINK)
	b.fan(Face.Builder.round_rect(at + Vector2(-s * 0.42, -s * 0.58), Vector2(s * 0.76, s * 0.38), s * 0.17), COW_SHADE)
	b.fan(Face.Builder.round_rect(at + Vector2(-s * 0.42, -s * 0.6), Vector2(s * 0.76, s * 0.34), s * 0.16), COW)
	b.ellipse(at + Vector2(-s * 0.16, -s * 0.47), s * 0.14, s * 0.09, PATCH)
	b.ellipse(at + Vector2(-s * 0.06, -s * 0.42), s * 0.08, s * 0.06, PATCH)
	b.ellipse(at + Vector2(0.15 * s, -s * 0.36), s * 0.08, s * 0.05, PATCH)
	b.ellipse(at + Vector2(-s * 0.32, -s * 0.36), s * 0.05, s * 0.05, PATCH)
	for x in [-0.36, 0.11]:
		b.fan(Face.Builder.round_rect(at + Vector2(x * s, -s * 0.32), Vector2(s * 0.095, s * 0.32), s * 0.035), COW)
		b.fan(Face.Builder.round_rect(at + Vector2(x * s, -s * 0.065), Vector2(s * 0.095, s * 0.065), s * 0.02), HOOF)
	# the head: ears and horns behind it, a patch over one eye, a pink muzzle
	var head := at + Vector2(s * 0.36, -s * 0.6)
	Art._lens(b, head + Vector2(-s * 0.1, -s * 0.08), head + Vector2(-s * 0.26, -s * 0.12), s * 0.05, PATCH)
	Art._lens(b, head + Vector2(s * 0.1, -s * 0.08), head + Vector2(s * 0.26, -s * 0.12), s * 0.05, COW_SHADE)
	b.stroke(PackedVector2Array([head + Vector2(-s * 0.07, -s * 0.14), head + Vector2(-s * 0.1, -s * 0.22)]), s * 0.035, Color("e8dcc0"))
	b.stroke(PackedVector2Array([head + Vector2(s * 0.07, -s * 0.14), head + Vector2(s * 0.1, -s * 0.22)]), s * 0.035, Color("e8dcc0"))
	b.fan(Face.Builder.round_rect(head + Vector2(-s * 0.15, -s * 0.17), Vector2(s * 0.3, s * 0.3), s * 0.13), COW)
	b.ellipse(head + Vector2(-s * 0.07, -s * 0.05), s * 0.07, s * 0.09, PATCH)
	b.ellipse(head + Vector2(0, s * 0.09), s * 0.135, s * 0.085, PINK)
	for x in [-0.045, 0.045]:
		b.disc(head + Vector2(x * s, s * 0.085), s * 0.016, Color(Art.INK, 0.6))
	for x in [-0.07, 0.07]:
		b.disc(head + Vector2(x * s, -s * 0.045), s * 0.024, Art.INK)
		b.disc(head + Vector2(x * s + s * 0.008, -s * 0.053), s * 0.008, Color.WHITE)
	# a bell
	b.disc(head + Vector2(-s * 0.02, s * 0.2), s * 0.035, Art.GOLD)

## A bottle of milk `s` pixels tall, its middle at `at`.
static func bottle_into(b: Face.Builder, at: Vector2, s: float) -> void:
	b.fan(Face.Builder.round_rect(at + Vector2(-s * 0.26, -s * 0.2), Vector2(s * 0.52, s * 0.7), s * 0.14), Color("cfdcec"))
	b.fan(Face.Builder.round_rect(at + Vector2(-s * 0.22, -s * 0.18), Vector2(s * 0.44, s * 0.64), s * 0.12), GLASS)
	b.fan(Face.Builder.round_rect(at + Vector2(-s * 0.13, -s * 0.42), Vector2(s * 0.26, s * 0.3), s * 0.06), GLASS)
	b.fan(Face.Builder.round_rect(at + Vector2(-s * 0.16, -s * 0.5), Vector2(s * 0.32, s * 0.13), s * 0.05), CAP)
	b.fan(Face.Builder.round_rect(at + Vector2(-s * 0.14, s * 0.02), Vector2(s * 0.1, s * 0.3), s * 0.04), Color("e3ecf6"))

static func bottle(s: float) -> ArrayMesh:
	return _made("bottle%.1f" % s, func(b: Face.Builder) -> void: bottle_into(b, Vector2.ZERO, s))

## The word a full cow has for it: a white bubble with a bottle in it, its
## tail's tip at the origin.
static func bubble(s: float) -> ArrayMesh:
	return _made("bubble%.1f" % s, func(b: Face.Builder) -> void:
		var c := Vector2(0, -s * 0.86)
		b.disc(c + Vector2(0, s * 0.05), s * 0.56, Color(Art.INK, 0.2))
		b.fan(PackedVector2Array([Vector2(-s * 0.16, -s * 0.4), Vector2(s * 0.16, -s * 0.4), Vector2.ZERO]), Color.WHITE)
		b.disc(c, s * 0.54, Color.WHITE)
		bottle_into(b, c + Vector2(0, s * 0.04), s * 0.62))

## A water trough, its foot at `at`.
static func trough(b: Face.Builder, at: Vector2, u: float) -> void:
	Art.soft(b, at + Vector2(3.0 * u, 3.0 * u), 36.0 * u, 11.0 * u, Color(0.2, 0.2, 0.1, 0.32))
	b.fan(Face.Builder.round_rect(at + Vector2(-28.0 * u, -18.0 * u), Vector2(56.0 * u, 20.0 * u), 5.0 * u), Art.WOOD_DEEP)
	b.fan(Face.Builder.round_rect(at + Vector2(-26.0 * u, -18.0 * u), Vector2(52.0 * u, 15.0 * u), 4.0 * u), Art.WOOD)
	b.ellipse(at + Vector2(0, -18.0 * u), 24.0 * u, 5.0 * u, Color("8fc7e8"))
	b.ellipse(at + Vector2(-6.0 * u, -19.0 * u), 9.0 * u, 1.6 * u, Color(1, 1, 1, 0.7))

# --- the fox ---

## A fox `s` pixels long, looking right, low on its feet.
static func fox(s: float) -> ArrayMesh:
	return _made("fox%.1f" % s, func(b: Face.Builder) -> void:
		Art.soft(b, Vector2(0, s * 0.02), s * 0.6, s * 0.13, Color(0.2, 0.2, 0.1, 0.34))
		for x in [-0.26, -0.16, 0.14, 0.24]:
			b.fan(Face.Builder.round_rect(Vector2(x * s, -s * 0.2), Vector2(s * 0.06, s * 0.2), s * 0.025), Color("5a3a28"))
		Art._lens(b, Vector2(-s * 0.3, -s * 0.3), Vector2(-s * 0.74, -s * 0.46), s * 0.15, FOX)
		Art._lens(b, Vector2(-s * 0.58, -s * 0.4), Vector2(-s * 0.76, -s * 0.47), s * 0.09, Art.CREAM)
		b.ellipse(Vector2(-s * 0.02, -s * 0.3), s * 0.36, s * 0.15, FOX_DEEP)
		b.ellipse(Vector2(-s * 0.02, -s * 0.32), s * 0.35, s * 0.13, FOX)
		b.ellipse(Vector2(0.04 * s, -s * 0.25), s * 0.22, s * 0.06, Art.CREAM)
		var head := Vector2(s * 0.36, -s * 0.44)
		for x in [-0.08, 0.07]:
			b.fan(PackedVector2Array([head + Vector2(x * s - s * 0.06, -s * 0.06), head + Vector2(x * s + s * 0.06, -s * 0.06), head + Vector2(x * s, -s * 0.24)]), FOX_DEEP)
		b.disc(head, s * 0.15, FOX)
		b.fan(PackedVector2Array([head + Vector2(s * 0.06, -s * 0.09), head + Vector2(s * 0.34, s * 0.06), head + Vector2(s * 0.04, s * 0.13)]), FOX)
		b.fan(PackedVector2Array([head + Vector2(-s * 0.02, s * 0.04), head + Vector2(s * 0.3, s * 0.07), head + Vector2(s * 0.02, s * 0.14)]), Art.CREAM)
		b.disc(head + Vector2(s * 0.33, s * 0.06), s * 0.03, Art.INK)
		b.disc(head + Vector2(s * 0.07, -s * 0.03), s * 0.028, Art.INK))

# --- the pens ---

## A point of a pen's rim at angle `ang` (0 its right, a quarter turn on its near side).
static func rim(rx: float, ry: float, ang: float) -> Vector2:
	return Vector2(cos(ang) * rx, sin(ang) * ry)

## A length of fence along a pen's rim from angle `from` to `to`: posts and
## two rails. `gap` leaves the posts between those two angles out and lays
## their rails on the ground: where the fence is down.
static func _fence(b: Face.Builder, rx: float, ry: float, from: float, to: float, posts: int, tall: float, gap := Vector2(1, -1)) -> void:
	var pts: Array = []
	for k in posts + 1:
		pts.append(lerpf(from, to, float(k) / posts))
	for k in posts:
		var a0: float = pts[k]
		var a1: float = pts[k + 1]
		var down := a0 >= gap.x - 0.001 and a1 <= gap.y + 0.001
		var p0 := rim(rx, ry, a0)
		var p1 := rim(rx, ry, a1)
		if down:
			# the rails lie where they fell
			b.stroke(PackedVector2Array([p0 + Vector2(2, 3), p0.lerp(p1, 0.8) + Vector2(4, 8)]), tall * 0.14, Art.WOOD_DEEP)
			b.stroke(PackedVector2Array([p0.lerp(p1, 0.3) + Vector2(-3, 9), p1 + Vector2(-2, 2)]), tall * 0.14, Art.WOOD)
			continue
		for h in [0.36, 0.74]:
			b.stroke(PackedVector2Array([p0 - Vector2(0, tall * h) + Vector2(0, 1.5), p1 - Vector2(0, tall * h) + Vector2(0, 1.5)]), tall * 0.14, Art.WOOD_DEEP)
			b.stroke(PackedVector2Array([p0 - Vector2(0, tall * h), p1 - Vector2(0, tall * h)]), tall * 0.12, Art.WOOD_HI)
	for k in posts + 1:
		var a: float = pts[k]
		if a > gap.x + 0.001 and a < gap.y - 0.001:
			continue
		var p := rim(rx, ry, a)
		b.ellipse(p + Vector2(1.0, 1.0), tall * 0.2, tall * 0.08, Color(0.2, 0.2, 0.1, 0.25))
		b.fan(Face.Builder.round_rect(p + Vector2(-tall * 0.1, -tall), Vector2(tall * 0.2, tall * 1.02), tall * 0.08), Art.WOOD_DEEP)
		b.fan(Face.Builder.round_rect(p + Vector2(-tall * 0.1, -tall), Vector2(tall * 0.13, tall * 1.0), tall * 0.06), Art.WOOD)

## Where the fence comes down, on a pen's near side.
const GAP := Vector2(PI * 5.0 / 9.0, PI * 7.0 / 9.0)

## A pen's ground, its far fence and what stands in it, its middle at the
## origin. `kind` "coop" (trodden earth, straw, the hens' house) or "cow"
## (grass, a trough); not `built`, a round of longer grass pegged out.
static func pen_back(kind: String, rx: float, ry: float, built: bool) -> ArrayMesh:
	return _made("penb%s/%.0f/%.0f/%s" % [kind, rx, ry, built], func(b: Face.Builder) -> void:
		var tall := ry * 0.34
		if not built:
			b.ellipse(Vector2.ZERO, rx * 0.94, ry * 0.94, Color(Art.GRASS_HI, 0.5))
			for k in 10:
				var p := rim(rx * 0.9, ry * 0.9, TAU * k / 10.0)
				b.fan(Face.Builder.round_rect(p + Vector2(-2.5, -tall * 0.5), Vector2(5.0, tall * 0.52), 2.0), Art.WOOD_DEEP)
				b.stroke(PackedVector2Array([p - Vector2(0, tall * 0.4), rim(rx * 0.9, ry * 0.9, TAU * (k + 1) / 10.0) - Vector2(0, tall * 0.4)]), 1.6, Color(Art.CREAM, 0.85))
			for at: Vector2 in [Vector2(-0.4, 0.2), Vector2(0.3, -0.3), Vector2(0.5, 0.3), Vector2(-0.1, -0.4)]:
				Art._tuft(b, at * Vector2(rx, ry), 9.0, Art.GRASS_DEEP)
			return
		Art.soft(b, Vector2(0, ry * 0.1), rx * 1.2, ry * 1.25, Color(0.16, 0.26, 0.1, 0.34), 0.7)
		var rng := RandomNumberGenerator.new()
		rng.seed = 77 if kind == "coop" else 78
		if kind == "coop":
			b.ellipse(Vector2(0, 3.0), rx, ry, Art.EARTH_DEEP)
			b.ellipse(Vector2.ZERO, rx, ry, Art.EARTH)
			Art.soft(b, Vector2(-rx * 0.2, -ry * 0.2), rx * 0.7, ry * 0.6, Color(1, 0.97, 0.86, 0.3), 0.3)
			for k in 26:
				var at := Vector2(rng.randf_range(-0.8, 0.8), rng.randf_range(-0.8, 0.8))
				if at.length() > 0.84:
					continue
				var d := Vector2.from_angle(rng.randf() * PI) * 7.0
				b.stroke(PackedVector2Array([at * Vector2(rx, ry) - d, at * Vector2(rx, ry) + d]), 2.0, Color(STRAW, 0.8) if k % 3 != 0 else Color(Art.EARTH_DEEP, 0.7))
		else:
			b.ellipse(Vector2(0, 3.0), rx, ry, Art.GRASS_DEEP)
			b.ellipse(Vector2.ZERO, rx, ry, Art.GRASS_HI)
			Art.soft(b, Vector2(rx * 0.2, ry * 0.3), rx * 0.6, ry * 0.5, Color(Art.GRASS_DEEP, 0.3), 0.3)
			for k in 22:
				var at := Vector2(rng.randf_range(-0.8, 0.8), rng.randf_range(-0.8, 0.8))
				if at.length() > 0.84:
					continue
				if k % 4 == 0:
					Art._daisy(b, at * Vector2(rx, ry), 5.0, Art.CREAM if k % 8 == 0 else Color("fbe58c"))
				else:
					Art._tuft(b, at * Vector2(rx, ry), 9.0, Art.GRASS_DEEP)
		_fence(b, rx, ry, PI, TAU, 9, tall)
		if kind == "coop":
			hutch(b, Vector2(-rx * 0.5, -ry * 0.3), ry / 110.0)
		else:
			trough(b, Vector2(rx * 0.48, -ry * 0.36), ry / 80.0))

## A pen's near fence, drawn over its animals; `whole` false leaves the
## coop's gap.
static func pen_front(rx: float, ry: float, whole: bool) -> ArrayMesh:
	return _made("penf%.0f/%.0f/%s" % [rx, ry, whole], func(b: Face.Builder) -> void:
		_fence(b, rx, ry, 0.0, PI, 9, ry * 0.34, Vector2(1, -1) if whole else GAP))

## A length of straight fence `w` pixels wide for a button, its middle at the origin.
static func fence_icon(w: float) -> ArrayMesh:
	return _made("fencei%.0f" % w, func(b: Face.Builder) -> void:
		var tall := w * 0.62
		for h in [0.3, 0.68]:
			b.stroke(PackedVector2Array([Vector2(-w * 0.5, tall * (0.5 - h) + 1.5), Vector2(w * 0.5, tall * (0.5 - h) + 1.5)]), tall * 0.14, Art.WOOD_DEEP)
			b.stroke(PackedVector2Array([Vector2(-w * 0.5, tall * (0.5 - h)), Vector2(w * 0.5, tall * (0.5 - h))]), tall * 0.12, Art.WOOD_HI)
		for x in [-0.34, 0.0, 0.34]:
			b.fan(Face.Builder.round_rect(Vector2(x * w - w * 0.07, -tall * 0.5), Vector2(w * 0.14, tall), w * 0.05), Art.WOOD_DEEP)
			b.fan(Face.Builder.round_rect(Vector2(x * w - w * 0.07, -tall * 0.5), Vector2(w * 0.09, tall * 0.98), w * 0.04), Art.WOOD))
