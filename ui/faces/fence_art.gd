extends RefCounted

## Garden Fence's drawings: the lawn, the garden bed (dark soil in the
## fence's shape, a few rows of sprouts), the low wooden rail round it, a
## fence post seen from above (its sawn top with the year rings, a cream
## cap that bears the letter), the twine strung post to post with its knot,
## the daisy that opens on a post once twine has touched it, Insane's little
## arched gate, the wooden sign the word being strung is chalked on, and the
## seed tag a tied word hangs on. Builder shapes, not Controls: the board,
## the menu card and the tutorial draw the same pieces. Letters are the
## caller's (a draw_string each).

const Pal = preload("res://core/palette.gd")
const Face = preload("res://ui/faces/face.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

const LAWN := Color("c9e0a2")
const LAWN_STRIPE := Color("bcd791")
const LAWN_DEEP := Color("a7c77c")
const SOIL := Color("8a6a4c")
const SOIL_LIT := Color("9c7b5a")
const SOIL_DEEP := Color("6f5239")
const SPROUT := Color("86b95a")
const SPROUT_DEEP := Color("5f9443")
const RAIL := Color("c69c6d")
const RAIL_LIT := Color("dcb88a")
const RAIL_DEEP := Color("9a7146")
const POST := Color("b98a58")
const POST_LIT := Color("d7ad7c")
const POST_DEEP := Color("8a6038")
const POST_RING := Color("a57a4b")
const CAP := Color("fbf3e1")
const CAP_DEEP := Color("e3d3b2")
const INK := Color("3e3226")
const INK_DIM := Color("b3a58e")
## The twine: jute once tied, a brighter green string while being strung,
## gold while it spells a word the garden knows.
const TWINE := Color("c8a46a")
const TWINE_DEEP := Color("9a7a45")
const STRING := Color("6f9e3c")
const GOLD := Color("e2a92a")
const GOLD_DEEP := Color("b07a12")
const PETAL := Color("fffaf0")
const PETAL_DEEP := Color("efe3c8")
const HEART := Color("f2c13d")
const GATE := Color("7d9c5a")
const GATE_DEEP := Color("57753a")
const SIGN := Color("caa274")
const SIGN_LIT := Color("e0bf92")
const SIGN_DEEP := Color("986f43")
const TAG := Color("f6ecd6")
const TAG_DEEP := Color("d8c6a2")
## The daily theme's word, tied: a rose ribbon (no twine state is rose) with
## a bow; the seed packet with a sun on it that hangs on the sign while the
## word is hidden.
const RIBBON := Color("e0697c")
const RIBBON_DEEP := Color("a9465a")
const RIBBON_LIT := Color("ffb3bd")
const PACKET := Color("f3e3c0")
const PACKET_DEEP := Color("c9ad7c")
const SUN := Color("f6b93b")
const SUN_DEEP := Color("d48a1c")

## The lawn edge to edge, `sz`: soft mowing stripes, a few daisies and
## tufts, kept clear of `keep` (the bed and its fence).
static func lawn(b, sz: Vector2, u: float, keep: Rect2) -> void:
	b.polygon(PackedVector2Array([Vector2.ZERO, Vector2(sz.x, 0), sz, Vector2(0, sz.y)]), LAWN)
	var band := 120.0 * u
	var x := -band * 0.5
	while x < sz.x:
		b.polygon(PackedVector2Array([Vector2(x, 0), Vector2(x + band, 0), Vector2(x + band - sz.y * 0.08, sz.y), Vector2(x - sz.y * 0.08, sz.y)]), Color(LAWN_STRIPE, 0.55))
		x += band * 2.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var grown := keep.grow(40.0 * u)
	for k in 26:
		var p := Vector2(rng.randf() * sz.x, rng.randf_range(0.06, 0.98) * sz.y)
		if grown.has_point(p):
			continue
		if k % 3 == 0:
			daisy(b, p, rng.randf_range(9.0, 13.0) * u, rng.randf() * TAU)
		else:
			Scenery.tuft(b, p, rng.randf_range(16.0, 24.0) * u)

## The bed inside the fence's outline `ring` (its corners), soil with a
## lighter top and a few rows of sprouts; the rail round it.
static func bed(b, ring: PackedVector2Array, u: float) -> void:
	var c := Vector2.ZERO
	for p in ring:
		c += p
	c /= ring.size()
	# the shadow the rail casts on the lawn
	var shade := PackedVector2Array()
	for p in ring:
		shade.append(p + (p - c).normalized() * 10.0 * u + Vector2(0.0, 12.0 * u))
	b.polygon(shade, Color(0.25, 0.32, 0.12, 0.2))
	var first: int = b.verts.size()
	b.polygon(ring, Color.WHITE)
	var top := 1e9
	var bottom := -1e9
	for p in ring:
		top = minf(top, p.y)
		bottom = maxf(bottom, p.y)
	for i in range(first, b.verts.size()):
		var k := clampf((b.verts[i].y - top) / maxf(1.0, bottom - top), 0.0, 1.0)
		b.cols[i] = SOIL_LIT.lerp(SOIL, k)
	# furrows across the bed, cut to its shape, and sprouts along them
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	var rows := 6
	for r in rows:
		var y := lerpf(top, bottom, (r + 0.7) / (rows + 0.4))
		var line := PackedVector2Array([Vector2(c.x - 2000.0, y - 4.0 * u), Vector2(c.x + 2000.0, y - 4.0 * u), Vector2(c.x + 2000.0, y + 4.0 * u), Vector2(c.x - 2000.0, y + 4.0 * u)])
		for part in Geometry2D.intersect_polygons(line, _inset(ring, c, 30.0 * u)):
			b.polygon(part, Color(SOIL_DEEP, 0.45))
			var x0 := 1e9
			var x1 := -1e9
			for p in part:
				x0 = minf(x0, p.x)
				x1 = maxf(x1, p.x)
			var n := int((x1 - x0) / (70.0 * u))
			for k in n:
				var sx := lerpf(x0, x1, (k + 0.5 + rng.randf_range(-0.2, 0.2)) / maxf(1.0, n))
				sprout(b, Vector2(sx, y - 2.0 * u), rng.randf_range(9.0, 13.0) * u, rng.randf() * 0.6 - 0.3)
	# the rail: a plank round the bed, lit on its top edge
	var closed := ring.duplicate()
	b.stroke(_grow(closed, c, 3.0 * u), 26.0 * u, RAIL_DEEP, true)
	b.stroke(closed, 22.0 * u, RAIL, true)
	b.stroke(_inset(closed, c, 5.0 * u), 6.0 * u, Color(RAIL_LIT, 0.8), true)

## A sprout: two round leaves on a short stem.
static func sprout(b, at: Vector2, r: float, lean: float) -> void:
	var tip := at + Vector2(lean * r, -r * 0.9)
	b.stroke(PackedVector2Array([at, tip]), maxf(1.5, r * 0.18), SPROUT_DEEP)
	b.ellipse(tip + Vector2(-r * 0.42, -r * 0.05), r * 0.5, r * 0.3, SPROUT)
	b.ellipse(tip + Vector2(r * 0.42, -r * 0.1), r * 0.5, r * 0.3, SPROUT)

## A post of radius `r` about the origin seen from above: its shadow, the
## sawn top with year rings, the cream cap that bears the letter. `used`
## winds a loop of twine round it.
static func post(b, r: float, seed: int, used := false) -> void:
	Scenery.soft_disc(b, Vector2(r * 0.08, r * 0.3), r * 1.25, r * 1.1, Color(0.2, 0.25, 0.1, 0.3))
	b.disc(Vector2(0.0, r * 0.12), r, POST_DEEP)
	var first: int = b.verts.size()
	b.disc(Vector2.ZERO, r, Color.WHITE)
	for i in range(first, b.verts.size()):
		var k := clampf((b.verts[i].y + r) / (2.0 * r), 0.0, 1.0)
		b.cols[i] = POST_LIT.lerp(POST, k)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 31 + 7
	var off := Vector2(rng.randf_range(-0.1, 0.1), rng.randf_range(-0.1, 0.1)) * r
	b.stroke(Face.Builder.ring(off, r * 0.9, r * 0.88), maxf(1.0, r * 0.035), Color(POST_RING, 0.7), true)
	# the cap
	b.disc(Vector2(0.0, r * 0.06), r * 0.74, CAP_DEEP)
	b.disc(Vector2.ZERO, r * 0.72, CAP)
	if used:
		b.stroke(Face.Builder.ring(Vector2.ZERO, r * 0.98, r * 0.98), maxf(2.0, r * 0.12), TWINE, true)
		b.stroke(Face.Builder.ring(Vector2(0.0, -r * 0.02), r * 0.98, r * 0.98), maxf(1.0, r * 0.04), Color(1, 1, 1, 0.35), true)

## A daisy of radius `r`: white petals about a gold heart, turned `turn`.
static func daisy(b, at: Vector2, r: float, turn := 0.0) -> void:
	for k in 8:
		var a := turn + TAU * k / 8.0
		var d := Vector2(cos(a), sin(a))
		b.ellipse(at + d * r * 0.55 + Vector2(0.0, r * 0.08), r * 0.5, r * 0.26, PETAL_DEEP)
	for k in 8:
		var a := turn + TAU * k / 8.0
		var d := Vector2(cos(a), sin(a))
		var pts := Face.Builder.ring(at + d * r * 0.55, r * 0.48, r * 0.24)
		var rot := PackedVector2Array()
		var cc := at + d * r * 0.55
		for p in pts:
			var q := p - cc
			rot.append(cc + Vector2(q.x * cos(a) - q.y * sin(a), q.x * sin(a) + q.y * cos(a)))
		b.fan(rot, PETAL)
	b.disc(at + Vector2(0.0, r * 0.06), r * 0.3, GOLD_DEEP)
	b.disc(at, r * 0.28, HEART)

## Twine from `a` to `c`, sagging by `sag` (px) at its middle.
static func twine(b, a: Vector2, c: Vector2, width: float, colour: Color, sag := 0.0) -> void:
	var mid := (a + c) * 0.5 + (c - a).orthogonal().normalized() * sag
	var pts := Face.Builder.bezier2(a, mid, c, 10)
	pts.append(c)
	b.stroke(pts, width, colour)
	b.stroke(pts, maxf(1.0, width * 0.3), Color(1, 1, 1, 0.22))

## The knot where twine is tied off.
static func knot(b, at: Vector2, r: float, colour := TWINE) -> void:
	b.disc(at + Vector2(0.0, r * 0.15), r, colour.darkened(0.25))
	b.disc(at, r, colour)
	b.stroke(PackedVector2Array([at + Vector2(-r * 0.2, r * 0.6), at + Vector2(-r * 0.9, r * 1.9)]), maxf(1.5, r * 0.45), colour)
	b.stroke(PackedVector2Array([at + Vector2(r * 0.2, r * 0.6), at + Vector2(r * 0.7, r * 2.0)]), maxf(1.5, r * 0.45), colour)

## A ribbon bow of half-width `r` at `at`, its loops along `dir` (unit):
## two loops, two tails hanging, the knot between.
static func bow(b, at: Vector2, r: float, dir := Vector2.RIGHT) -> void:
	# the tails hang down whichever way the loops lie
	var n := dir.orthogonal()
	if n.y < 0.0:
		n = -n
	for side in [-1.0, 1.0]:
		var tail := PackedVector2Array([at, at + dir * side * r * 0.45 + n * r * 0.95, at + dir * side * r * 0.8 + n * r * 0.8])
		b.stroke(tail, maxf(1.5, r * 0.26), RIBBON_DEEP)
	for side in [-1.0, 1.0]:
		var c: Vector2 = at + dir * side * r * 0.56 - n * r * 0.08
		var loop := Face.Builder.ring(c, r * 0.52, r * 0.34)
		var rot := PackedVector2Array()
		var a := dir.angle()
		for q in loop:
			var d := q - c
			rot.append(c + Vector2(d.x * cos(a) - d.y * sin(a), d.x * sin(a) + d.y * cos(a)))
		b.fan(rot, RIBBON_DEEP)
		var inner := PackedVector2Array()
		for q in rot:
			inner.append(c + (q - c) * 0.72 - n * r * 0.04)
		b.fan(inner, RIBBON)
	b.disc(at + n * r * 0.06, r * 0.26, RIBBON_DEEP)
	b.disc(at, r * 0.22, RIBBON_LIT.lerp(RIBBON, 0.5))

## The seed packet of `w` x 1.3 `w`, its top middle at `top`: a paper
## pouch with a folded lip and a sun on its front, hung by a bit of twine.
static func packet(b, top: Vector2, w: float) -> void:
	var h := w * 1.3
	var tl := top - Vector2(w * 0.5, 0.0)
	b.stroke(PackedVector2Array([top + Vector2(0.0, -w * 0.3), top + Vector2(0.0, w * 0.08)]), maxf(1.5, w * 0.06), TWINE_DEEP)
	b.fan(Face.Builder.round_rect(tl + Vector2(0.0, w * 0.06), Vector2(w, h), w * 0.1), PACKET_DEEP)
	b.fan(Face.Builder.round_rect(tl, Vector2(w, h), w * 0.1), PACKET)
	b.polygon(PackedVector2Array([tl + Vector2(0.0, h * 0.2), tl + Vector2(w, h * 0.2), tl + Vector2(w, h * 0.26), tl + Vector2(0.0, h * 0.26)]), Color(PACKET_DEEP, 0.7))
	var sc := tl + Vector2(w * 0.5, h * 0.6)
	var sr := w * 0.2
	for k in 8:
		var a := TAU * k / 8.0
		var d := Vector2(cos(a), sin(a))
		b.polygon(PackedVector2Array([sc + d * sr * 1.95, sc + d.rotated(0.32) * sr * 1.2, sc + d.rotated(-0.32) * sr * 1.2]), SUN)
	b.disc(sc + Vector2(0.0, sr * 0.1), sr * 1.05, SUN_DEEP)
	b.disc(sc, sr, SUN)

## Insane's gate: a leafy arch over the outer half of the post at `at`
## (radius `r`), facing out along `out` (unit), a gold ring round its cap
## and a gold bud at the arch's crown. It stays within half a post of the
## post, so a gate on a side at the screen's edge is never cut.
static func gate(b, at: Vector2, out: Vector2, r: float) -> void:
	var base := out.angle()
	var arch := PackedVector2Array()
	var rr := r * 1.32
	for k in 17:
		var a := base - PI * 0.62 + PI * 1.24 * k / 16.0
		arch.append(at + Vector2(cos(a), sin(a)) * rr)
	b.stroke(arch, maxf(3.0, r * 0.26), GATE_DEEP)
	b.stroke(arch, maxf(2.0, r * 0.18), GATE)
	# leaves along it
	for k in 7:
		var a := base - PI * 0.55 + PI * 1.1 * k / 6.0
		var p := at + Vector2(cos(a), sin(a)) * rr
		var d := Vector2(cos(a), sin(a))
		b.ellipse(p + d * r * 0.08, r * 0.16, r * 0.1, Color(SPROUT, 0.95))
	# the posts the arch stands on
	for side in [-1.0, 1.0]:
		var a: float = base + side * PI * 0.62
		b.disc(at + Vector2(cos(a), sin(a)) * rr, r * 0.16, GATE_DEEP)
	b.disc(at + out * rr, r * 0.17, GOLD_DEEP)
	b.disc(at + out * rr, r * 0.13, GOLD)
	b.stroke(Face.Builder.ring(at, r * 1.08, r * 1.08), maxf(2.0, r * 0.08), Color(GOLD, 0.85), true)

## The sign the word being strung is chalked on: a plank on two stakes.
static func sign(b, rect: Rect2) -> void:
	var r := rect.size.y * 0.22
	var u := rect.size.y / 100.0
	for x in [rect.position.x + rect.size.x * 0.2, rect.end.x - rect.size.x * 0.2]:
		b.polygon(Face.Builder.round_rect(Vector2(x - 7.0 * u, rect.end.y - 10.0 * u), Vector2(14.0 * u, 26.0 * u), 4.0 * u), SIGN_DEEP)
	Scenery.soft_disc(b, rect.get_center() + Vector2(0.0, rect.size.y * 0.42), rect.size.x * 0.55, rect.size.y * 0.3, Color(0.2, 0.25, 0.1, 0.22))
	b.fan(Face.Builder.round_rect(rect.position + Vector2(0.0, 6.0 * u), rect.size, r), SIGN_DEEP)
	var first: int = b.verts.size()
	b.fan(Face.Builder.round_rect(rect.position, rect.size, r), Color.WHITE)
	for i in range(first, b.verts.size()):
		var k := clampf((b.verts[i].y - rect.position.y) / rect.size.y, 0.0, 1.0)
		b.cols[i] = SIGN_LIT.lerp(SIGN, k)
	# the grain, and a nail at each end
	for k in 3:
		var y := rect.position.y + rect.size.y * (0.28 + k * 0.24)
		b.stroke(PackedVector2Array([Vector2(rect.position.x + r, y), Vector2(rect.end.x - r * 1.6, y + 2.0 * u)]), maxf(1.0, 1.6 * u), Color(SIGN_DEEP, 0.35))
	for x in [rect.position.x + r * 0.7, rect.end.x - r * 0.7]:
		b.disc(Vector2(x, rect.get_center().y), 4.0 * u, SIGN_DEEP)

## A seed tag a tied word hangs on: a little card with a punched hole and
## its string, `bulb` blue-edged.
static func tag(b, rect: Rect2, bulb := false, theme := false) -> void:
	var r := rect.size.y * 0.24
	b.fan(Face.Builder.round_rect(rect.position + Vector2(0.0, rect.size.y * 0.08), rect.size, r), TAG_DEEP)
	b.fan(Face.Builder.round_rect(rect.position, rect.size, r), TAG)
	var hole := Vector2(rect.position.x + rect.size.y * 0.32, rect.get_center().y)
	b.disc(hole, rect.size.y * 0.1, TAG_DEEP)
	if bulb:
		b.stroke(Face.Builder.round_rect(rect.position + Vector2.ONE * 2.0, rect.size - Vector2.ONE * 4.0, r), maxf(1.5, rect.size.y * 0.06), Color("7fb2d9"), true)
	if theme:
		# the day's word: a ribbon bow tied through its hole
		bow(b, hole, rect.size.y * 0.28)

## `ring` pulled in towards `c` by `d`.
static func _inset(ring: PackedVector2Array, c: Vector2, d: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in ring:
		out.append(p + (c - p).normalized() * d)
	return out

static func _grow(ring: PackedVector2Array, c: Vector2, d: float) -> PackedVector2Array:
	return _inset(ring, c, -d)
