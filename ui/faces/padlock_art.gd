extends RefCounted

## Padlock's drawings: the brass lock body with its dial slots, a dial's
## strip of letter cells (ivory, or gold once lit), the glass window across
## the slots, the steel shackle, the found words' brass tags on their key
## ring, and the shed door the lock hangs on, its hasp, ivy and a watering
## can. Builder shapes, not Controls: the board, the menu card and the
## tutorial draw the same pieces. Letters are the caller's (a draw_string
## each).

const Pal = preload("res://core/palette.gd")
const Face = preload("res://ui/faces/face.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

const BRASS := Color("d9a646")
const BRASS_LIT := Color("f2cf7a")
const BRASS_DEEP := Color("a87628")
const BRASS_DARK := Color("7a5219")
const SLOT := Color("4a3420")
const IVORY := Color("fbf3df")
const IVORY_LOW := Color("eadcbc")
const INK := Color("4a3828")
## A lit letter: warm gold, its ink deep brown.
const GOLD := Color("f4b73f")
const GOLD_DEEP := Color("c98a1e")
const GOLD_INK := Color("5a3608")
const STEEL := Color("c9ced6")
const STEEL_LIT := Color("eef1f5")
const STEEL_DEEP := Color("8e96a3")
const RUST := Color("b0582f")
const RUST_DEEP := Color("7e3a1d")
const DOOR := Color("cfdcc0")
const DOOR_LOW := Color("b9cba8")
const DOOR_GAP := Color("93a884")
const IRON := Color("5d5a57")
const IRON_LIT := Color("8b8783")
const LEAF := Color("7fae5c")
const LEAF_DEEP := Color("5f8f45")
const CAN := Color("7d9fd9")
const CAN_DEEP := Color("5a79b3")

## A cell's corner and its rim, as shares of its height.
const ROUND := 0.16
const RIM := 0.06

## The lock's body round `rect`: a rounded brass block, lit along its top,
## deep below, a soft shadow on the door. `rust` (0..1) rusts its lower edge.
static func body(b, rect: Rect2, rust := 0.0) -> void:
	var r := minf(rect.size.x, rect.size.y) * 0.12
	Scenery.soft_disc(b, rect.get_center() + Vector2(0.0, rect.size.y * 0.08), rect.size.x * 0.58, rect.size.y * 0.6, Color(0.15, 0.2, 0.1, 0.22))
	b.fan(Face.Builder.round_rect(rect.position + Vector2(0.0, r * 0.35), rect.size, r), BRASS_DARK)
	var first: int = b.verts.size()
	b.fan(Face.Builder.round_rect(rect.position, rect.size, r), Color.WHITE)
	_shade(b, first, BRASS_LIT, BRASS_DEEP, rect.position.y, rect.end.y)
	# a bevel round the face
	b.stroke(Face.Builder.round_rect(rect.position + Vector2.ONE * r * 0.35, rect.size - Vector2.ONE * r * 0.7, r * 0.7), maxf(1.5, r * 0.08), Color(BRASS_LIT, 0.7), true)
	if rust > 0.0:
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		for k in 14:
			var at := Vector2(rect.position.x + rng.randf() * rect.size.x, rect.end.y - rng.randf() * rect.size.y * 0.25 - r * 0.3)
			b.ellipse(at, r * rng.randf_range(0.12, 0.3), r * rng.randf_range(0.08, 0.2), Color(RUST, 0.55 * rust))

## A dial's slot, `rect`: a dark recess the strip slides in. A rusty slot
## (Rusty Lock) has a rust rim and an arrow pointing down at its head.
static func slot(b, rect: Rect2, rusty := false) -> void:
	var r := rect.size.x * 0.18
	b.fan(Face.Builder.round_rect(rect.position - Vector2.ONE * r * 0.18, rect.size + Vector2.ONE * r * 0.36, r * 1.1), RUST_DEEP if rusty else BRASS_DARK)
	b.fan(Face.Builder.round_rect(rect.position, rect.size, r), SLOT)
	b.polygon(_box(rect.position + Vector2(r * 0.4, r * 0.15), Vector2(rect.size.x - r * 0.8, r * 0.3)), Color(0, 0, 0, 0.25))
	if rusty:
		var rng := RandomNumberGenerator.new()
		rng.seed = 11
		for k in 10:
			var side := -1.0 if k % 2 == 0 else 1.0
			var at := Vector2(rect.get_center().x + side * (rect.size.x * 0.5 + r * 0.05), rect.position.y + rng.randf() * rect.size.y)
			b.ellipse(at, r * rng.randf_range(0.15, 0.32), r * rng.randf_range(0.2, 0.45), Color(RUST, 0.85))

## The rusty dial's arrow, engraved on the brass above its slot.
static func arrow(b, at: Vector2, s: float) -> void:
	b.polygon(PackedVector2Array([at + Vector2(-s, -s * 0.5), at + Vector2(s, -s * 0.5), at + Vector2(0.0, s * 0.6)]), RUST_DEEP)

## One letter cell about `at`, `sz` across: an ivory tumbler face, or gold
## once lit, its rim under it.
static func cell(b, at: Vector2, sz: Vector2, lit: bool) -> void:
	var r := sz.y * ROUND
	var half := sz * 0.5
	b.fan(Face.Builder.round_rect(at - half + Vector2(0.0, sz.y * RIM), sz, r), GOLD_DEEP if lit else IVORY_LOW)
	b.fan(Face.Builder.round_rect(at - half, sz, r), GOLD if lit else IVORY)
	b.polygon(_box(at - half + Vector2(r, sz.y * 0.08), Vector2(sz.x - r * 2.0, sz.y * 0.07)), Color(1, 1, 1, 0.35))

## The glass window across the slots, `rect`: brass bars above and below,
## a soft gloss between.
static func window(b, rect: Rect2) -> void:
	var bar := rect.size.y * 0.11
	b.polygon(_box(rect.position, rect.size), Color(1.0, 0.97, 0.85, 0.12))
	b.polygon(_box(rect.position + Vector2(0.0, rect.size.y * 0.08), Vector2(rect.size.x, rect.size.y * 0.16)), Color(1, 1, 1, 0.22))
	for y in [rect.position.y - bar * 0.5, rect.end.y - bar * 0.5]:
		b.fan(Face.Builder.round_rect(Vector2(rect.position.x - bar, y + bar * 0.3), Vector2(rect.size.x + bar * 2.0, bar), bar * 0.5), BRASS_DARK)
		b.fan(Face.Builder.round_rect(Vector2(rect.position.x - bar, y), Vector2(rect.size.x + bar * 2.0, bar), bar * 0.5), BRASS_LIT)
		for x in [rect.position.x - bar * 0.3, rect.end.x + bar * 0.3]:
			b.disc(Vector2(x, y + bar * 0.5), bar * 0.28, BRASS_DEEP)

## The steel shackle over a body `w` wide whose top is `top`: a U of steel
## `thick` thick, `h` tall, lifted `lift` (0 shut .. 1 open: the right leg
## leaves its hole and the U swings a little).
static func shackle(b, mid_x: float, top: float, w: float, h: float, thick: float, lift := 0.0) -> void:
	var up := h * 0.42 * lift
	var half := w * 0.5 - thick * 0.5
	var pts := PackedVector2Array()
	var foot := top + thick * 0.6
	pts.append(Vector2(mid_x - half, foot - up))
	for k in 25:
		var a := PI + PI * k / 24.0
		pts.append(Vector2(mid_x + cos(a) * half, top - h + half + sin(a) * half - up))
	pts.append(Vector2(mid_x + half, foot - up - (h * 0.18 if lift > 0.0 else 0.0)))
	b.stroke(pts, thick * 1.12, STEEL_DEEP)
	b.stroke(pts, thick, STEEL)
	var gloss := PackedVector2Array()
	for k in range(4, 13):
		var a := PI + PI * k / 24.0
		gloss.append(Vector2(mid_x + cos(a) * (half - thick * 0.18), top - h + half + sin(a) * (half - thick * 0.18) - up))
	b.stroke(gloss, thick * 0.22, Color(STEEL_LIT, 0.8))

## A brass tag `rect` on a short loop of string, its word the caller's.
## `lit`: the word lit a letter (gold); else plain steel.
static func tag(b, rect: Rect2, lit: bool) -> void:
	var r := rect.size.y * 0.3
	b.fan(Face.Builder.round_rect(rect.position + Vector2(0.0, rect.size.y * 0.1), rect.size, r), BRASS_DEEP if lit else STEEL_DEEP)
	b.fan(Face.Builder.round_rect(rect.position, rect.size, r), BRASS_LIT if lit else STEEL_LIT)
	b.disc(rect.position + Vector2(r * 0.9, rect.size.y * 0.5), rect.size.y * 0.13, BRASS_DARK if lit else STEEL_DEEP)

## The daily theme's luggage tag (2026-11-06): a kraft card tied to the
## shackle on a red string, a little sun printed by its hole. The caller
## builds it about the knot (0, 0) and turns it there; the string runs to
## the hole at `hole`, the card `sz` lies to its right. Blank, a pencil line
## waits for the word; `found` (the day's word dialled), a warm halo glows
## behind it (a halo, never a shade of the card). The word is the caller's.
const KRAFT := Color("ecd9ab")
const KRAFT_DEEP := Color("c4a266")
const KRAFT_INK := Color("4f3416")
const PENCIL := Color("8a7556")
const STRING := Color("c4473d")
const STRING_DEEP := Color("8f2f28")

static func luggage(b, hole: Vector2, sz: Vector2, found: bool) -> void:
	var h := sz.y
	var at := hole - Vector2(h * 0.42, h * 0.5)
	var rect := Rect2(at, sz)
	if found:
		Scenery.soft_disc(b, rect.get_center(), sz.x * 0.75, h * 1.25, Color(Pal.SUN_RAY, 0.55))
	# the string from the knot to the hole, a little slack
	var mid := hole * 0.5 + Vector2(-h * 0.08, h * 0.12)
	var line := PackedVector2Array([Vector2.ZERO, mid, hole])
	b.stroke(line, maxf(1.5, h * 0.075), STRING_DEEP)
	b.stroke(line, maxf(1.0, h * 0.045), STRING)
	b.disc(Vector2.ZERO, h * 0.07, STRING_DEEP)
	# the card, its left corners clipped, a shadow under it
	var c := h * 0.28
	var card := PackedVector2Array([
		at + Vector2(c, 0.0), at + Vector2(sz.x - h * 0.12, 0.0), at + Vector2(sz.x, h * 0.12),
		at + Vector2(sz.x, h - h * 0.12), at + Vector2(sz.x - h * 0.12, h), at + Vector2(c, h),
		at + Vector2(0.0, h - c), at + Vector2(0.0, c)])
	var shadow := PackedVector2Array()
	for p in card:
		shadow.append(p + Vector2(h * 0.04, h * 0.1))
	b.polygon(shadow, Color(0.1, 0.12, 0.06, 0.25))
	var rim := PackedVector2Array()
	for p in card:
		rim.append(p + Vector2(0.0, h * 0.06))
	b.polygon(rim, KRAFT_DEEP)
	b.polygon(card, KRAFT)
	b.polygon(_box(at + Vector2(c, h * 0.08), Vector2(sz.x - c - h * 0.2, h * 0.06)), Color(1, 1, 1, 0.35))
	# the hole's eyelet
	b.disc(hole, h * 0.16, KRAFT_DEEP)
	b.disc(hole, h * 0.09, Color(0.25, 0.2, 0.12))
	# the sun by the hole
	sun(b, hole + Vector2(h * 0.52, 0.0), h * 0.22, found)
	if not found:
		# a pencil line where the word will be written
		var x0 := hole.x + h * 0.95
		var x1 := at.x + sz.x - h * 0.3
		var y := at.y + h * 0.7
		var x := x0
		while x < x1:
			b.polygon(_box(Vector2(x, y), Vector2(minf(h * 0.18, x1 - x), maxf(1.0, h * 0.04))), Color(PENCIL, 0.6))
			x += h * 0.28

## A little sun about `at`, `r` its disc: eight rays round it. `bright`
## lengthens the rays.
static func sun(b, at: Vector2, r: float, bright := false) -> void:
	var ray := r * (0.75 if bright else 0.5)
	for k in 8:
		var a := TAU * k / 8.0
		var d := Vector2(cos(a), sin(a))
		var n := Vector2(-d.y, d.x)
		b.polygon(PackedVector2Array([at + d * r * 1.15 + n * r * 0.22, at + d * (r * 1.2 + ray), at + d * r * 1.15 - n * r * 0.22]), Pal.SUN_DEEP)
	b.disc(at, r, Pal.SUN_DEEP)
	b.disc(at - Vector2(0.0, r * 0.06), r * 0.86, Pal.SUN)
	b.disc(at - Vector2(r * 0.25, r * 0.3), r * 0.28, Color(Pal.SUN_RAY, 0.9))

## The shed door edge to edge, `sz`: painted vertical boards with gaps,
## knots and worn paint, a brace across.
static func door(b, sz: Vector2, u: float) -> void:
	var first: int = b.verts.size()
	b.polygon(_box(Vector2.ZERO, sz), Color.WHITE)
	_shade(b, first, DOOR, DOOR_LOW, 0.0, sz.y)
	var board := 150.0 * u
	var x := -40.0 * u
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	while x < sz.x + board:
		b.polygon(_box(Vector2(x - 3.0 * u, 0.0), Vector2(6.0 * u, sz.y)), DOOR_GAP)
		b.polygon(_box(Vector2(x + 3.0 * u, 0.0), Vector2(5.0 * u, sz.y)), Color(1, 1, 1, 0.18))
		for k in 3:
			var y := rng.randf() * sz.y
			b.ellipse(Vector2(x + rng.randf_range(0.25, 0.75) * board, y), 9.0 * u, 15.0 * u, Color(DOOR_GAP, 0.45))
			b.ellipse(Vector2(x + rng.randf_range(0.2, 0.8) * board, rng.randf() * sz.y), rng.randf_range(14.0, 30.0) * u, rng.randf_range(5.0, 9.0) * u, Color(0.85, 0.72, 0.52, 0.3))
		x += board

## The hasp the lock hangs from: an iron strap bolted across the door from
## the left, hinged at its root, its slotted end over the staple at `at`
## (the staple's middle); `w` sets the size.
static func hasp(b, at: Vector2, w: float) -> void:
	var h := w * 0.2
	var x0 := at.x - w * 1.25
	var x1 := at.x + w * 0.22
	Scenery.soft_disc(b, Vector2((x0 + x1) * 0.5, at.y + h * 0.5), (x1 - x0) * 0.55, h * 0.9, Color(0.1, 0.12, 0.08, 0.2))
	b.fan(Face.Builder.round_rect(Vector2(x0, at.y - h * 0.5 + h * 0.12), Vector2(x1 - x0, h), h * 0.35), Color(IRON, 0.8).darkened(0.3))
	b.fan(Face.Builder.round_rect(Vector2(x0, at.y - h * 0.5), Vector2(x1 - x0, h), h * 0.35), IRON)
	b.polygon(_box(Vector2(x0 + h * 0.3, at.y - h * 0.38), Vector2(x1 - x0 - h * 0.6, h * 0.16)), Color(IRON_LIT, 0.6))
	# the hinge's knuckles at the root
	for k in 3:
		var y := at.y - h * 0.9 + k * h * 0.6
		b.fan(Face.Builder.round_rect(Vector2(x0 - h * 0.35, y), Vector2(h * 0.7, h * 0.55), h * 0.2), IRON if k % 2 == 0 else IRON_LIT.darkened(0.2))
	# bolts along the strap
	for x in [x0 + h * 1.2, x0 + (x1 - x0) * 0.45]:
		b.disc(Vector2(x, at.y), h * 0.16, IRON_LIT)
		b.disc(Vector2(x, at.y + h * 0.03), h * 0.09, IRON)

## The staple, an iron loop standing out of the door through the hasp's
## slot, at `at`; the shackle hangs through it.
static func staple(b, at: Vector2, w: float) -> void:
	var r := w * 0.11
	var arc := Face.Builder.arc_points(at + Vector2(0.0, r * 0.3), r, PI, TAU)
	b.stroke(arc, w * 0.055, IRON)
	b.stroke(Face.Builder.arc_points(at + Vector2(0.0, r * 0.3), r, PI * 1.15, PI * 1.6), w * 0.02, IRON_LIT)

## The key ring the tags hang from, a nail in the door at `at`, `r` across.
static func ring(b, at: Vector2, r: float) -> void:
	b.disc(at, r * 0.16, IRON)
	b.disc(at - Vector2(r * 0.04, r * 0.04), r * 0.08, IRON_LIT)
	b.stroke(Face.Builder.ring(at + Vector2(0.0, r * 0.95), r, r * 0.95), r * 0.12, STEEL_DEEP, true)
	b.stroke(Face.Builder.ring(at + Vector2(0.0, r * 0.92), r, r * 0.95), r * 0.06, STEEL_LIT, true)

## Ivy climbing up the door's edge at `x`, from the foot `y1` to `y0`.
static func ivy(b, x: float, y0: float, y1: float, u: float, side := 1.0) -> void:
	var stem := PackedVector2Array()
	var y := y1
	var k := 0
	while y > y0:
		stem.append(Vector2(x + sin(k * 0.7) * 18.0 * u * side, y))
		y -= 30.0 * u
		k += 1
	if stem.size() >= 2:
		b.stroke(stem, 5.0 * u, LEAF_DEEP)
	for i in range(0, stem.size(), 2):
		var p := stem[i]
		var d := (1.0 if i % 4 == 0 else -1.0) * side
		_leaf(b, p + Vector2(d * 22.0 * u, 0.0), 24.0 * u * (0.7 + 0.3 * sin(i * 1.7)), d)

static func _leaf(b, at: Vector2, s: float, d: float) -> void:
	b.polygon(PackedVector2Array([at + Vector2(-s * 0.6 * d, 0.0), at + Vector2(0.0, -s * 0.55), at + Vector2(s * 0.6 * d, -s * 0.1), at + Vector2(s * 0.1 * d, s * 0.5)]), LEAF)
	b.stroke(PackedVector2Array([at + Vector2(-s * 0.5 * d, 0.0), at + Vector2(s * 0.4 * d, -s * 0.05)]), maxf(1.0, s * 0.06), LEAF_DEEP)

## A watering can on the ground at `foot`, `h` tall.
static func can(b, foot: Vector2, h: float) -> void:
	var w := h * 0.9
	Scenery.soft_disc(b, foot + Vector2(0.0, h * 0.02), w * 0.75, h * 0.1, Color(0.1, 0.12, 0.08, 0.28))
	b.stroke(PackedVector2Array([foot + Vector2(w * 0.35, -h * 0.35), foot + Vector2(w * 0.95, -h * 0.85)]), h * 0.1, CAN_DEEP)
	b.fan(Face.Builder.round_rect(foot + Vector2(-w * 0.45, -h * 0.75), Vector2(w * 0.85, h * 0.75), h * 0.12), CAN)
	b.polygon(_box(foot + Vector2(-w * 0.38, -h * 0.68), Vector2(w * 0.14, h * 0.58)), Color(1, 1, 1, 0.25))
	b.stroke(Face.Builder.arc_points(foot + Vector2(-w * 0.02, -h * 0.75), w * 0.32, PI, TAU), h * 0.07, CAN_DEEP)
	b.ellipse(foot + Vector2(w * 1.0, -h * 0.88), h * 0.1, h * 0.06, CAN_DEEP)

static func _box(at: Vector2, sz: Vector2) -> PackedVector2Array:
	return PackedVector2Array([at, at + Vector2(sz.x, 0.0), at + sz, at + Vector2(0.0, sz.y)])

static func _shade(b, first: int, top: Color, bottom: Color, y0: float, y1: float) -> void:
	for i in range(first, b.verts.size()):
		var c := top.lerp(bottom, clampf(inverse_lerp(y0, y1, b.verts[i].y), 0.0, 1.0))
		b.cols[i] = Color(c.r, c.g, c.b, b.cols[i].a * c.a)
