extends RefCounted

## Firefly's cast, drawn as builder shapes and shared by the game
## (arcade/firefly_screen.gd) and its card on the Arcade tab. Every sprite
## is built at the origin facing up (-y), in pixels for a field unit of `u`
## pixels, so a bug is turned to its heading by the draw transform and never
## rebuilt to move. Two wing frames a bug; the screen flips between them.
##
## The cast is the garden's night shift: you are a firefly, and the swarm is
## gnats (small, striped), ladybird beetles and the big lilac moths, who
## are the ones with the silk beam. A captive is your firefly wrapped in
## silk; a rogue is one the swarm kept, turned rose.

const Pal = preload("res://core/palette.gd")
const Face = preload("res://ui/faces/face.gd")
const Motes = preload("res://ui/motes.gd")

enum Look { FIREFLY, GNAT, BEETLE, MOTH, MOTH_HURT, ROGUE, CAPTIVE }

const INK := Color("3b3028")
const GLOW := Color("ffe27a")
const GLOW_HOT := Color("fff6c9")
const FIREFLY_BODY := Color("56618a")
const FIREFLY_SHIELD := Color("ef8a62")
const WING := Color(0.92, 0.95, 1.0, 0.55)
const GNAT_BODY := Color("f4c94f")
const GNAT_STRIPE := Color("7a5a3a")
const BEETLE_SHELL := Color("e2645c")
const BEETLE_DEEP := Color("bf4a44")
const MOTH_WING := Color("9aa6e6")
const MOTH_WING_DEEP := Color("7d8fd9")
const MOTH_HURT := Color("e58fb5")
const MOTH_HURT_DEEP := Color("c26b93")
const MOTH_FUR := Color("f6ecd9")
const ROGUE_BODY := Color("b8577a")
const SILK := Color(1.0, 1.0, 1.0, 0.75)

## The shop's cards, by arcade/firefly_sim.gd's Card: Peapod's colours, so a
## card is the same colour in both shops.
const CARD := [Color("f5a44a"), Color("f08fb0"), Color("7fc8ee"), Color("45558f"), Color("a98be0")]
const PAPER := Color("fcf7ef")

static var _cache := {}

## One sprite's mesh, cached per look, frame and scale.
static func mesh(look: int, frame: int, u: float) -> ArrayMesh:
	var key := "%d/%d/%.2f" % [look, frame, u]
	if _cache.has(key):
		return _cache[key]
	if _cache.size() > 200:
		_cache.clear()
	var b := Face.Builder.new()
	match look:
		Look.FIREFLY:
			firefly(b, u, frame, FIREFLY_BODY, FIREFLY_SHIELD, true)
		Look.ROGUE:
			firefly(b, u, frame, ROGUE_BODY, Color("f4a7a0"), true, true)
		Look.CAPTIVE:
			firefly(b, u, 0, FIREFLY_BODY.lerp(Color.WHITE, 0.35), FIREFLY_SHIELD.lerp(Color.WHITE, 0.35), false)
			silk(b, u)
		Look.GNAT:
			gnat(b, u, frame)
		Look.BEETLE:
			beetle(b, u, frame)
		Look.MOTH:
			moth(b, u, frame, false)
		Look.MOTH_HURT:
			moth(b, u, frame, true)
	var m := b.mesh()
	_cache[key] = m
	return m

static func _eyes(b: Face.Builder, at: Vector2, gap: float, r: float, cross := false) -> void:
	for s in [-1.0, 1.0]:
		var c := at + Vector2(s * gap, 0)
		b.ellipse(c, r, r * 1.2, INK)
		if cross:
			b.disc(c + Vector2(-s * r * 0.25, -r * 0.1), r * 0.4, Color("f4a7a0"))
		else:
			b.disc(c + Vector2(-r * 0.3, -r * 0.4), r * 0.38, Color.WHITE)

static func _cheeks(b: Face.Builder, at: Vector2, gap: float, r: float) -> void:
	for s in [-1.0, 1.0]:
		b.ellipse(at + Vector2(s * gap, 0), r, r * 0.6, Color(Pal.CHEEK, 0.8))

## The firefly: a slate body, a coral shield over the head, glassy wings
## and a lantern tail that glows.
static func firefly(b: Face.Builder, u: float, frame: int, body: Color, shield: Color, glow: bool, rogue := false) -> void:
	var s := u
	if glow:
		for k in 3:
			b.disc(Vector2(0, 5.2 * s), (7.5 - k * 2.0) * s, Color(GLOW, 0.10 + k * 0.08))
	var spread := 0.45 if frame == 0 else 0.15
	for side in [-1.0, 1.0]:
		var wc := Vector2(side * 4.6 * s, 0.4 * s)
		var wing := Face.Builder.ring(Vector2.ZERO, 3.2 * s, 6.2 * s)
		var xf := Transform2D(side * spread, wc)
		b.fan(xf * wing, WING)
		b.stroke(xf * Face.Builder.ring(Vector2.ZERO, 3.2 * s, 6.2 * s), 0.35 * s, Color(1, 1, 1, 0.5), true)
	# the tail's lantern
	b.ellipse(Vector2(0, 4.6 * s), 3.4 * s, 4.0 * s, GLOW if glow else GLOW.lerp(Color.WHITE, 0.5))
	b.ellipse(Vector2(0, 5.2 * s), 2.0 * s, 2.4 * s, GLOW_HOT)
	# body
	b.ellipse(Vector2(0, -0.2 * s), 3.3 * s, 4.4 * s, body)
	for k in 2:
		b.stroke(PackedVector2Array([Vector2(-2.9 * s, (1.2 + k * 1.3) * s), Vector2(2.9 * s, (1.2 + k * 1.3) * s)]), 0.45 * s, body.darkened(0.25))
	# head and shield
	b.ellipse(Vector2(0, -4.6 * s), 3.1 * s, 2.6 * s, shield)
	b.ellipse(Vector2(-0.9 * s, -5.4 * s), 1.1 * s, 0.6 * s, Color(1, 1, 1, 0.35))
	for side in [-1.0, 1.0]:
		var ant := Face.Builder.bezier2(Vector2(side * 1.0 * s, -6.6 * s), Vector2(side * 1.4 * s, -9.0 * s), Vector2(side * 3.2 * s, -9.6 * s), 8)
		b.stroke(ant, 0.5 * s, body.darkened(0.2))
		b.disc(Vector2(side * 3.2 * s, -9.6 * s), 0.8 * s, GLOW if not rogue else Color("f4a7a0"))
	_eyes(b, Vector2(0, -4.4 * s), 1.25 * s, 0.62 * s, rogue)

## Silk wound round a captive.
static func silk(b: Face.Builder, u: float) -> void:
	var s := u
	for k in 5:
		var y := (-5.0 + k * 2.4) * s
		var pts := Face.Builder.bezier2(Vector2(-5.0 * s, y - 1.0 * s), Vector2(0, y + 1.6 * s), Vector2(5.0 * s, y - 0.6 * s), 10)
		b.stroke(pts, 0.55 * s, SILK)

## A gnat: a small butter-yellow bug with brown stripes and buzzy wings.
static func gnat(b: Face.Builder, u: float, frame: int) -> void:
	var s := u
	var spread := 0.7 if frame == 0 else 0.25
	for side in [-1.0, 1.0]:
		var xf := Transform2D(side * spread, Vector2(side * 3.6 * s, -0.8 * s))
		b.fan(xf * Face.Builder.ring(Vector2.ZERO, 2.6 * s, 4.2 * s), WING)
	b.ellipse(Vector2(0, 1.0 * s), 3.9 * s, 4.6 * s, GNAT_BODY)
	for k in 2:
		var y := (1.2 + k * 2.0) * s
		b.stroke(PackedVector2Array([Vector2(-3.5 * s, y), Vector2(3.5 * s, y)]), 0.9 * s, GNAT_STRIPE)
	b.stroke(PackedVector2Array([Vector2(0, 5.4 * s), Vector2(0, 6.8 * s)]), 0.7 * s, GNAT_STRIPE)
	b.ellipse(Vector2(0, -3.6 * s), 3.0 * s, 2.6 * s, GNAT_BODY.lerp(Color.WHITE, 0.2))
	for side in [-1.0, 1.0]:
		b.stroke(PackedVector2Array([Vector2(side * 0.9 * s, -5.8 * s), Vector2(side * 2.2 * s, -7.6 * s)]), 0.45 * s, GNAT_STRIPE)
		b.disc(Vector2(side * 2.2 * s, -7.6 * s), 0.6 * s, GNAT_STRIPE)
	_eyes(b, Vector2(0, -3.6 * s), 1.2 * s, 0.6 * s)
	_cheeks(b, Vector2(0, -2.5 * s), 2.1 * s, 0.6 * s)

## A ladybird: a red shell in two halves with ink spots; on the second
## frame the halves lift and the wings under them show.
static func beetle(b: Face.Builder, u: float, frame: int) -> void:
	var s := u
	var lift := 0.0 if frame == 0 else 0.22
	if frame == 1:
		for side in [-1.0, 1.0]:
			var xf := Transform2D(side * 0.55, Vector2(side * 4.4 * s, 1.0 * s))
			b.fan(xf * Face.Builder.ring(Vector2.ZERO, 2.6 * s, 5.0 * s), WING)
	b.ellipse(Vector2(0, 0.8 * s), 5.0 * s, 5.4 * s, INK.lerp(BEETLE_DEEP, 0.2))
	for side in [-1.0, 1.0]:
		var half := PackedVector2Array()
		for p in Face.Builder.arc_points(Vector2.ZERO, 5.0 * s, -PI * 0.5, PI * 0.5):
			half.append(Vector2(p.x * side, p.y * 1.08))
		var xf := Transform2D(side * lift, Vector2(side * 0.25 * s, 1.0 * s))
		b.fan(xf * half, BEETLE_SHELL)
		b.disc(xf * Vector2(side * 2.4 * s, -1.2 * s), 1.1 * s, INK)
		b.disc(xf * Vector2(side * 2.8 * s, 2.2 * s), 0.9 * s, INK)
		b.disc(xf * Vector2(side * 1.2 * s, 4.0 * s), 0.7 * s, INK)
		b.ellipse(xf * Vector2(side * 1.6 * s, -2.8 * s), 1.2 * s, 0.6 * s, Color(1, 1, 1, 0.35))
	b.ellipse(Vector2(0, -4.6 * s), 3.2 * s, 2.4 * s, INK.lerp(Color("5b4a5e"), 0.5))
	for side in [-1.0, 1.0]:
		b.stroke(PackedVector2Array([Vector2(side * 1.2 * s, -6.4 * s), Vector2(side * 2.4 * s, -8.2 * s)]), 0.45 * s, INK)
		b.disc(Vector2(side * 2.4 * s, -8.2 * s), 0.6 * s, INK)
	for side in [-1.0, 1.0]:
		var c := Vector2(side * 1.3 * s, -4.8 * s)
		b.disc(c, 0.85 * s, Color.WHITE)
		b.disc(c + Vector2(0, 0.15 * s), 0.45 * s, INK)

## A moth: broad lilac wings with an eye spot each, a furry cream body and
## feathery feelers; once hurt its wings go rose.
static func moth(b: Face.Builder, u: float, frame: int, hurt: bool) -> void:
	var s := u * 1.05
	var wing := MOTH_HURT if hurt else MOTH_WING
	var deep := MOTH_HURT_DEEP if hurt else MOTH_WING_DEEP
	var fold := 0.0 if frame == 0 else 0.28
	for side in [-1.0, 1.0]:
		# forewing and hindwing
		var fx := Transform2D(side * (0.35 - fold), Vector2(side * 4.6 * s, -1.4 * s))
		var fore := Face.Builder.ring(Vector2.ZERO, 5.4 * s * (1.0 - fold * 0.5), 3.8 * s)
		b.fan(fx * fore, deep)
		b.fan(fx * Face.Builder.ring(Vector2(0, -0.3 * s), 4.8 * s * (1.0 - fold * 0.5), 3.2 * s), wing)
		b.disc(fx * Vector2(side * 1.6 * s * (1.0 - fold * 0.5), -0.2 * s), 1.3 * s, MOTH_FUR)
		b.disc(fx * Vector2(side * 1.6 * s * (1.0 - fold * 0.5), -0.2 * s), 0.7 * s, deep.darkened(0.3))
		var hx := Transform2D(side * (-0.5 + fold), Vector2(side * 3.4 * s, 3.2 * s))
		b.fan(hx * Face.Builder.ring(Vector2.ZERO, 3.8 * s * (1.0 - fold * 0.4), 2.8 * s), deep)
		b.fan(hx * Face.Builder.ring(Vector2(0, -0.2 * s), 3.3 * s * (1.0 - fold * 0.4), 2.3 * s), wing.lerp(Color.WHITE, 0.15))
	b.ellipse(Vector2(0, 1.4 * s), 2.3 * s, 5.0 * s, MOTH_FUR.darkened(0.08))
	for k in 3:
		b.stroke(PackedVector2Array([Vector2(-2.0 * s, (1.8 + k * 1.3) * s), Vector2(2.0 * s, (1.8 + k * 1.3) * s)]), 0.4 * s, MOTH_FUR.darkened(0.2))
	b.ellipse(Vector2(0, -3.4 * s), 2.9 * s, 2.5 * s, MOTH_FUR)
	for side in [-1.0, 1.0]:
		var stem := Face.Builder.bezier2(Vector2(side * 0.9 * s, -5.2 * s), Vector2(side * 1.6 * s, -7.8 * s), Vector2(side * 3.8 * s, -8.6 * s), 8)
		b.stroke(stem, 0.4 * s, deep.darkened(0.2))
		for k in range(1, 7):
			var p := stem[k]
			b.stroke(PackedVector2Array([p, p + Vector2(side * 0.5 * s, -0.9 * s)]), 0.3 * s, deep.darkened(0.2))
	_eyes(b, Vector2(0, -3.6 * s), 1.2 * s, 0.62 * s)
	_cheeks(b, Vector2(0, -2.5 * s), 2.0 * s, 0.55 * s)

# --- the shop ---

## A shot of the lantern's light, `r` wide, flying up.
static func _shot(b: Face.Builder, c: Vector2, r: float) -> void:
	b.ellipse(c + Vector2(0, r * 0.2), r * 1.25, r * 2.3, Color(INK, 0.18))
	b.ellipse(c, r, r * 2.1, GLOW)
	b.ellipse(c + Vector2(0, -r * 0.3), r * 0.5, r * 1.2, Color.WHITE)

static func _twinkle(b: Face.Builder, c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in 8:
		pts.append(c + Vector2.from_angle(-PI * 0.5 + TAU * k / 8.0) * (r if k % 2 == 0 else r * 0.32))
	b.polygon(pts, col)

## A shop card's medallion, centred, `side` pixels across: its colour on a
## paper-ringed disc and its picture on that. A heavier shot is one in a
## burst, a quicker gun two chevrons, the lucky shot a bull's eye with a
## glint, more energy three motes, one more shot three side by side.
static func card_token(card: int, side: float) -> ArrayMesh:
	var key := "ct/%d/%.1f" % [card, side]
	if _cache.has(key):
		return _cache[key]
	var b := Face.Builder.new()
	var r := side * 0.46
	var c := Vector2.ZERO
	var base: Color = CARD[card]
	b.disc(c + Vector2(0, r * 0.2), r, Color(0.3, 0.2, 0.08, 0.12))
	b.disc(c + Vector2(0, r * 0.12), r, base.darkened(0.22))
	b.disc(c, r, PAPER)
	b.disc(c, r * 0.85, base)
	b.stroke(Face.Builder.arc_points(c, r * 0.68, -PI * 0.85, -PI * 0.5), maxf(1.0, r * 0.09), Color(1, 1, 1, 0.5))
	var s := r * 1.25
	# Sim.Card: DAMAGE, SPEED, CRIT, ENERGY, SHOTS
	match card:
		0:
			var pts := PackedVector2Array()
			for k in 16:
				pts.append(c + Vector2.from_angle(TAU * k / 16.0) * s * (0.5 if k % 2 == 0 else 0.34))
			b.polygon(pts, GLOW_HOT)
			_shot(b, c, s * 0.15)
		1:
			for k in 2:
				var y := c.y + s * (0.2 - 0.34 * k)
				for pass_ in 2:
					var o := Vector2(0, s * 0.05) if pass_ == 0 else Vector2.ZERO
					b.stroke(PackedVector2Array([Vector2(c.x - s * 0.3, y + s * 0.14) + o, Vector2(c.x, y - s * 0.14) + o,
						Vector2(c.x + s * 0.3, y + s * 0.14) + o]), s * 0.15, Color(INK, 0.25) if pass_ == 0 else PAPER)
		2:
			b.disc(c + Vector2(0, s * 0.04), s * 0.44, Color(INK, 0.2))
			b.disc(c, s * 0.44, PAPER)
			b.disc(c, s * 0.3, Color("f08a80"))
			b.disc(c, s * 0.15, PAPER)
			_twinkle(b, c + Vector2(s * 0.3, -s * 0.3), s * 0.24, GLOW)
		3:
			for m: Array in [[Vector2(0.27, -0.27), 0.26], [Vector2(-0.3, 0.27), 0.2], [Vector2(-0.03, -0.02), 0.56]]:
				var at: Vector2 = c + m[0] * s
				Motes.glow(b, at, s * float(m[1]), Color(Motes.ORB, 1.0), 1.1)
				Motes.glow(b, at, s * float(m[1]) * 0.7, Color(Motes.ORB_HI, 1.0), 1.0)
				Motes.glow(b, at, s * float(m[1]) * 0.42, Color.WHITE, 0.7)
		4:
			for k in [-1.0, 1.0, 0.0]:
				_shot(b, c + Vector2(s * 0.3 * k, s * (0.1 if k != 0.0 else -0.06)), s * (0.11 if k != 0.0 else 0.13))
	var m := b.mesh()
	_cache[key] = m
	return m
