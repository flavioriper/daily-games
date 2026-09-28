extends RefCounted

## Trestle's drawings, shared by the board (puzzles/trestle2d.gd) and its
## menu card (ui/menu/card_art.gd): the three members, a joint's bolt, an
## anchor's pin, and the cart. All builder shapes, never Controls -- a bridge
## is baked into one mesh a frame -- and all sized off `u`, the length of one
## grid step in pixels.
## Spec: docs/superpowers/specs/2026-09-28-trestle-flat-design.md.

const Face = preload("res://ui/faces/face.gd")
const Pal = preload("res://core/palette.gd")

const ROAD := Color("b5825a")
const ROAD_TOP := Color("d8a878")
const ROAD_DEEP := Color("7d5334")
const WOOD := Color("d9b27c")
const WOOD_DEEP := Color("a07346")
const ROPE := Color("c9b48a")
const ROPE_DEEP := Color("8a7450")
const BOLT := Color("c9a24a")
const BOLT_DEEP := Color("7a5a24")
const PIN := Color("c2553f")
const PIN_DEEP := Color("7e2f22")
const STONE := Color("a39a8a")
const STONE_DEEP := Color("7a7264")
const CART := Color("e26a55")
const CART_DEEP := Color("a84534")
const CART_TRIM := Color("f6d49a")
const WHEEL := Color("6e4a2f")
const OK := Color("7cb06b")
const WARN := Color("f2b632")
const BAD := Color("d9605a")

## A member between `p` and `q` in pixels: 0 road, 1 wood, 2 rope. `tint`
## blends toward a stress colour; `alpha` fades a ghost.
static func member(b: Face.Builder, p: Vector2, q: Vector2, mat: int, u: float, tint := Color(0, 0, 0, 0), alpha := 1.0) -> void:
	var d := q - p
	var l := d.length()
	if l < 0.5:
		return
	var n := d / l
	var side := n.orthogonal()
	if side.y > 0.0:
		side = -side
	match mat:
		0:
			var w := u * 0.2
			b.stroke(PackedVector2Array([p, q]), w + u * 0.05, _mix(ROAD_DEEP, tint, alpha))
			b.stroke(PackedVector2Array([p, q]), w, _mix(ROAD, tint, alpha))
			b.stroke(PackedVector2Array([p + side * w * 0.3, q + side * w * 0.3]), w * 0.28, _mix(ROAD_TOP, tint, alpha))
			# plank seams across it, one every third of a step
			var seams := int(l / (u * 0.34))
			for k in range(1, seams):
				var c := p + d * (float(k) / seams)
				b.stroke(PackedVector2Array([c - side * w * 0.42, c + side * w * 0.42]), u * 0.025, _mix(ROAD_DEEP, tint, alpha * 0.6), false, false)
		1:
			var w := u * 0.13
			b.stroke(PackedVector2Array([p, q]), w + u * 0.045, _mix(WOOD_DEEP, tint, alpha))
			b.stroke(PackedVector2Array([p, q]), w, _mix(WOOD, tint, alpha))
			b.stroke(PackedVector2Array([p + side * w * 0.22, q + side * w * 0.22]), w * 0.22, _mix(Color("f0d3a4"), tint, alpha * 0.8))
		_:
			var w := u * 0.055
			b.stroke(PackedVector2Array([p, q]), w + u * 0.03, _mix(ROPE_DEEP, tint, alpha))
			b.stroke(PackedVector2Array([p, q]), w, _mix(ROPE, tint, alpha))
			# the twist: short dark ticks slanting across it
			var ticks := int(l / (u * 0.12))
			for k in range(1, ticks):
				var c := p + d * (float(k) / ticks)
				b.stroke(PackedVector2Array([c - n * w * 0.5 - side * w * 0.5, c + n * w * 0.5 + side * w * 0.5]), u * 0.018, _mix(ROPE_DEEP, tint, alpha * 0.7), false, false)

static func _mix(c: Color, tint: Color, alpha: float) -> Color:
	var out := c.lerp(Color(tint, 1.0), tint.a)
	out.a *= alpha
	return out

## The stress colour for a member at `r` of its limit: none under a third,
## then green to amber to red.
static func stress(r: float) -> Color:
	if r < 0.3:
		return Color(0, 0, 0, 0)
	var k := clampf((r - 0.3) / 0.7, 0.0, 1.0)
	var c := OK.lerp(WARN, clampf(k * 2.0, 0.0, 1.0)) if k < 0.5 else WARN.lerp(BAD, clampf(k * 2.0 - 1.0, 0.0, 1.0))
	return Color(c, clampf(0.35 + k * 0.6, 0.0, 0.95))

static func joint(b: Face.Builder, p: Vector2, u: float, alpha := 1.0) -> void:
	b.disc(p, u * 0.095, Color(BOLT_DEEP, alpha))
	b.disc(p, u * 0.068, Color(BOLT, alpha))
	b.disc(p + Vector2(-0.02, -0.02) * u, u * 0.025, Color(1, 0.95, 0.8, 0.8 * alpha))

## An anchor: a red pin in a stone plate, fixed to the bank.
static func anchor(b: Face.Builder, p: Vector2, u: float, glow := 0.0) -> void:
	if glow > 0.0:
		b.disc(p, u * (0.22 + 0.06 * glow), Color(Pal.SUN, 0.35 * glow))
	b.fan(Face.Builder.round_rect(p - Vector2.ONE * u * 0.15, Vector2.ONE * u * 0.3, u * 0.07), STONE_DEEP)
	b.fan(Face.Builder.round_rect(p - Vector2.ONE * u * 0.13, Vector2.ONE * u * 0.26, u * 0.06), STONE)
	b.disc(p, u * 0.1, PIN_DEEP)
	b.disc(p, u * 0.075, PIN)
	b.disc(p + Vector2(-0.025, -0.025) * u, u * 0.028, Color(1, 0.85, 0.8, 0.8))

## The cart's body, its origin on the road's top at the middle of its axle
## line, facing +x. `n` passengers widen it. Wheels are drawn apart.
static func cart_body(b: Face.Builder, u: float, n: int) -> void:
	var w := cart_width(u, n)
	var h := u * 0.34
	var base := -wheel_r(u) * 1.15
	var body := Rect2(Vector2(-w * 0.5, base - h), Vector2(w, h))
	b.fan(Face.Builder.round_rect(body.position + Vector2(0, u * 0.04), body.size, u * 0.08), CART_DEEP)
	b.fan(Face.Builder.round_rect(body.position, body.size, u * 0.08), CART)
	b.fan(Face.Builder.round_rect(body.position + Vector2(u * 0.04, u * 0.04), Vector2(w - u * 0.08, h * 0.26), u * 0.05), CART_TRIM)
	# the boards of its side
	for k in range(1, 4):
		var x := body.position.x + w * k / 4.0
		b.stroke(PackedVector2Array([Vector2(x, base - h * 0.62), Vector2(x, base - u * 0.03)]), u * 0.02, Color(CART_DEEP, 0.7), false, false)
	# the tow bar at the front
	b.stroke(PackedVector2Array([Vector2(w * 0.5, base - h * 0.35), Vector2(w * 0.5 + u * 0.22, base - h * 0.2)]), u * 0.05, WHEEL)
	b.disc(Vector2(w * 0.5 + u * 0.22, base - h * 0.2), u * 0.04, WHEEL)

static func cart_width(u: float, n: int) -> float:
	return u * (0.62 + 0.3 * n)

static func wheel_r(u: float) -> float:
	return u * 0.15

## One wheel, centred on its hub; turned by the draw transform.
static func wheel(b: Face.Builder, u: float) -> void:
	var r := wheel_r(u)
	b.disc(Vector2.ZERO, r, WHEEL)
	b.disc(Vector2.ZERO, r * 0.72, Color("a3794f"))
	for k in 4:
		var a := k * PI / 4.0
		var s := Vector2(cos(a), sin(a)) * r * 0.7
		b.stroke(PackedVector2Array([-s, s]), u * 0.025, WHEEL, false, false)
	b.disc(Vector2.ZERO, r * 0.22, BOLT)

## Where the wheels sit on the cart, relative to its origin.
static func wheel_at(u: float, n: int) -> Array[Vector2]:
	var w := cart_width(u, n)
	var y := -wheel_r(u)
	return [Vector2(-w * 0.32, y), Vector2(w * 0.32, y)]

## Where passenger `i` of `n` sits, relative to the cart's origin.
static func seat(u: float, n: int, i: int) -> Vector2:
	var w := cart_width(u, n)
	var x := 0.0 if n == 1 else lerpf(-w * 0.5 + u * 0.3, w * 0.5 - u * 0.3, float(i) / (n - 1))
	return Vector2(x, -wheel_r(u) * 1.15 - u * 0.42)
