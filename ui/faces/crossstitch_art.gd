extends RefCounted

## Cross Stitch's drawings: the letter patches (a square of floss on the
## linen, its face the thread's colour, a running stitch round its edge),
## the sampler's linen with its weave of holes, the wooden stretcher frame,
## the little cross-stitched flowers in the four holes, the needle that
## sews a word's border, and the spools and the pincushion on the table.
## Builder shapes, not Controls: the board, the menu card and the tutorial
## draw the same pieces. Letters are the caller's (a draw_string each).

const Pal = preload("res://core/palette.gd")
const Face = preload("res://ui/faces/face.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

## A patch's face by its mark (crossstitch_state.gd's Mark): stitched,
## on the right thread, a stray. The first two are Hidden Word's green and
## amber, so the Words row reads as one family; a stray is plain linen.
const FACE := [Pal.GOOD, Pal.WORD_NEAR, Color("f7efdc")]
const DEEP := [Color("5c8d4d"), Color("c4973a"), Color("d9cbad")]
const STITCH := [Color("e9f5e2"), Color("fff3d4"), Color("b9a988")]
const LETTER := [Pal.SURFACE, Pal.SURFACE, Color("4a3828")]
const INK := Color("4a3828")
const LINEN := Color("f3ead6")
const LINEN_LOW := Color("ebdfc5")
const WEAVE := Color("d8c9a8")
const FRAME := Color("c79a68")
const FRAME_DEEP := Color("9c7148")
const FRAME_LIT := Color("dcb788")
const ROSE := Color("e58fa6")
const ROSE_DEEP := Color("c86c86")
const LEAF := Color("8cb46a")
const GOLD := Color("e2a93b")
const GOLD_LIT := Color("f6cf73")
const STEEL := Color("c9ced6")
const STEEL_DEEP := Color("8e96a3")

## A patch's corner, its rim under the face, the running stitch's inset,
## as shares of its side.
const ROUND := 0.17
const RIM := 0.055
const INSET := 0.12

## A letter patch about `at`, `s` a side: the deep rim a little low, the
## face, and a running stitch round it in a light thread. `lift` raises the
## face off its rim (a patch picked up).
static func patch(b, at: Vector2, s: float, mark: int, lift := 0.0) -> void:
	var m := clampi(mark, 0, 2)
	var half := Vector2.ONE * s * 0.5
	var r := s * ROUND
	var up := Vector2(0.0, -s * RIM * lift)
	b.fan(Face.Builder.round_rect(at - half + Vector2(0.0, s * RIM), Vector2.ONE * s, r), DEEP[m])
	b.fan(Face.Builder.round_rect(at - half + up, Vector2.ONE * s, r), FACE[m])
	running_square(b, at + up, s * (1.0 - INSET * 2.0), s * 0.035, Color(STITCH[m], 0.85 if m < 2 else 0.9))

## A running stitch round a square of side `s` about `at`: four dashes a side.
static func running_square(b, at: Vector2, s: float, w: float, colour: Color, per_side := 4) -> void:
	var h := s * 0.5
	var corners := [at + Vector2(-h, -h), at + Vector2(h, -h), at + Vector2(h, h), at + Vector2(-h, h)]
	for k in 4:
		var p0: Vector2 = corners[k]
		var p1: Vector2 = corners[(k + 1) % 4]
		for d in per_side:
			var t0 := (d + 0.2) / float(per_side)
			var t1 := (d + 0.75) / float(per_side)
			b.stroke(PackedVector2Array([p0.lerp(p1, t0), p0.lerp(p1, t1)]), w, colour)

## The linen inside the frame, `rect`, with its weave: a soft dot every
## `pitch` pixels.
static func linen(b, rect: Rect2, pitch: float) -> void:
	var first: int = b.verts.size()
	b.polygon(_box(rect.position, rect.size), Color.WHITE)
	_shade(b, first, LINEN, LINEN_LOW, rect.position.y, rect.end.y)
	var dot := maxf(1.2, pitch * 0.14)
	var y := rect.position.y + pitch * 0.5
	while y < rect.end.y:
		var x := rect.position.x + pitch * 0.5
		while x < rect.end.x:
			b.polygon(_box(Vector2(x - dot, y - dot), Vector2(dot, dot) * 2.0), Color(WEAVE, 0.55))
			x += pitch
		y += pitch

## The wooden stretcher frame round the linen `inner`, `w` wide: four bars,
## mitred at the corners, lit on top and deep below, with a peg at each
## corner.
static func frame(b, inner: Rect2, w: float) -> void:
	var o := inner.grow(w)
	Scenery.soft_disc(b, o.get_center() + Vector2(0.0, w * 0.6), o.size.x * 0.56, o.size.y * 0.56, Color(0.25, 0.15, 0.08, 0.18))
	b.fan(Face.Builder.round_rect(o.position + Vector2(0.0, w * 0.18), o.size, w * 0.5), FRAME_DEEP)
	b.fan(Face.Builder.round_rect(o.position, o.size, w * 0.5), FRAME)
	# the lit top bar and the shaded inner lip
	b.polygon(_box(o.position + Vector2(w * 0.5, w * 0.12), Vector2(o.size.x - w, w * 0.22)), Color(FRAME_LIT, 0.8))
	b.polygon(_box(inner.position - Vector2.ONE * w * 0.14, inner.size + Vector2.ONE * w * 0.28), FRAME_DEEP)
	# mitres
	for c in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
		var a: Vector2 = o.position + o.size * c
		var i: Vector2 = inner.position + inner.size * c
		b.stroke(PackedVector2Array([a.lerp(i, 0.12), a.lerp(i, 0.88)]), maxf(1.5, w * 0.06), Color(FRAME_DEEP, 0.7))
		b.disc(a.lerp(i, 0.5), w * 0.13, FRAME_DEEP)
		b.disc(a.lerp(i, 0.5) - Vector2(0.0, w * 0.03), w * 0.1, FRAME_LIT)

## A little cross-stitched flower about `at`, `s` across: petals of X
## stitches in rose round a gold eye, two leaves under it.
static func flower(b, at: Vector2, s: float) -> void:
	var u := s / 7.0
	var w := maxf(1.4, u * 0.38)
	for p in [Vector2(0, -2), Vector2(-2, 0), Vector2(2, 0), Vector2(0, 2), Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		_x(b, at + p * u, u * 0.42, w, ROSE if absf(p.x) + absf(p.y) < 2.5 else ROSE_DEEP)
	_x(b, at, u * 0.42, w, GOLD)
	for p in [Vector2(-2, 2.6), Vector2(2, 2.6)]:
		_x(b, at + p * u, u * 0.38, w, LEAF)

## One cross stitch: two strokes, an X `r` from its middle to a corner.
static func _x(b, at: Vector2, r: float, w: float, colour: Color) -> void:
	b.stroke(PackedVector2Array([at + Vector2(-r, -r), at + Vector2(r, r)]), w, colour)
	b.stroke(PackedVector2Array([at + Vector2(r, -r), at + Vector2(-r, r)]), w, colour)

## A word's gold border, a running stitch along `pts` (a closed ring),
## sewn as far as `upto` (0..1 of its length). `colour`, `from_k` and
## `len_k` (shares of a dash) lay a second thread in the first's gaps: the
## day's theme word is sewn round in gold and rose.
static func border(b, pts: PackedVector2Array, w: float, upto := 1.0, dash := 16.0, colour := GOLD, from_k := 0.0, len_k := 0.6) -> Vector2:
	var total := 0.0
	var n := pts.size()
	for k in n:
		total += pts[k].distance_to(pts[(k + 1) % n])
	var reach := total * clampf(upto, 0.0, 1.0)
	var run := 0.0
	var tip := pts[0]
	for k in n:
		var p0 := pts[k]
		var p1 := pts[(k + 1) % n]
		var seg := p0.distance_to(p1)
		var d := 0.0
		while d < seg and run + d < reach:
			var d0 := d + dash * from_k
			var e := minf(seg, d0 + dash * len_k)
			e = minf(e, reach - run)
			if e > d0:
				b.stroke(PackedVector2Array([p0.lerp(p1, d0 / seg), p0.lerp(p1, e / seg)]), w, colour)
			tip = p0.lerp(p1, minf(1.0, (d + dash) / seg))
			d += dash
		run += seg
		if run >= reach:
			tip = p0.lerp(p1, clampf((reach - (run - seg)) / seg, 0.0, 1.0))
			break
	return tip

## The day's theme word's sun, a little round of linen pinned at the word's
## start with a sun cross-stitched on it, `r` its linen's half width.
## `bloom` 0 is the knot that only says which line is the day's (a gold
## French knot with a thread's tail, no rays); 1 the whole sun, eight rays
## of X stitches round a gold eye, sewn once the word is stitched.
static func sun(b, at: Vector2, r: float, bloom: float) -> void:
	var k := clampf(bloom, 0.0, 1.0)
	if k <= 0.0:
		var kr := r * 0.3
		b.stroke(PackedVector2Array([at + Vector2(kr * 0.6, kr * 0.4), at + Vector2(kr * 1.6, kr * 1.5), at + Vector2(kr * 2.3, kr * 1.3)]), maxf(1.2, kr * 0.28), GOLD)
		b.disc(at + Vector2(0.0, kr * 0.18), kr * 1.05, Color(FRAME_DEEP, 0.8))
		b.disc(at, kr, GOLD)
		b.disc(at - Vector2(kr, kr) * 0.3, kr * 0.38, GOLD_LIT)
		return
	var rr := r * lerpf(0.45, 1.0, k)
	b.disc(at + Vector2(0.0, rr * 0.12), rr * 1.06, Color(FRAME_DEEP, 0.85))
	b.disc(at, rr, LINEN)
	b.stroke(Face.Builder.ring(at, rr * 0.86, rr * 0.86), maxf(1.0, rr * 0.05), Color(WEAVE, 0.9), true)
	var w := maxf(1.2, rr * 0.11)
	for n in 8:
		var a := n * TAU / 8.0 - PI * 0.5
		var len := rr * (0.62 if n % 2 == 0 else 0.52) * k
		_x(b, at + Vector2(cos(a), sin(a)) * len, rr * 0.11, w, Pal.SUN if n % 2 == 0 else ROSE)
	b.disc(at, rr * 0.34, GOLD)
	for p in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1), Vector2.ZERO]:
		_x(b, at + p * rr * 0.13, rr * 0.07, maxf(1.0, rr * 0.06), GOLD_LIT)

## The needle, its eye at the back, pointing along `dir`, `l` long, a tail
## of gold thread from its eye.
static func needle(b, tip: Vector2, dir: Vector2, l: float) -> void:
	var d := dir.normalized() if dir.length() > 0.01 else Vector2.RIGHT
	var n := Vector2(-d.y, d.x)
	var back := tip - d * l
	var w := l * 0.07
	b.polygon(PackedVector2Array([tip, back + n * w, back - d * w * 0.6, back - n * w]), STEEL)
	b.stroke(PackedVector2Array([tip - d * l * 0.15, back]), w * 0.45, Color(Pal.SURFACE, 0.7))
	b.stroke(Face.Builder.ring(back - d * w * 0.4, w * 0.9, w * 0.5), w * 0.35, STEEL_DEEP, true)
	b.stroke(PackedVector2Array([back, back - d * l * 0.25 + n * l * 0.12, back - d * l * 0.5 + n * l * 0.02]), w * 0.5, GOLD)

## A spool of thread standing on the table, `h` tall, its thread `colour`.
static func spool(b, foot: Vector2, h: float, colour: Color) -> void:
	var w := h * 0.62
	Scenery.soft_disc(b, foot + Vector2(0.0, h * 0.04), w * 0.7, h * 0.12, Color(0.25, 0.15, 0.08, 0.25))
	b.fan(Face.Builder.round_rect(Vector2(foot.x - w * 0.5, foot.y - h * 0.16), Vector2(w, h * 0.16), h * 0.05), FRAME_DEEP)
	b.fan(Face.Builder.round_rect(Vector2(foot.x - w * 0.38, foot.y - h * 0.86), Vector2(w * 0.76, h * 0.72), h * 0.04), colour)
	for k in 6:
		var y := foot.y - h * (0.2 + k * 0.11)
		b.stroke(PackedVector2Array([Vector2(foot.x - w * 0.36, y), Vector2(foot.x + w * 0.36, y - h * 0.03)]), maxf(1.0, h * 0.012), Color(colour.darkened(0.2), 0.7))
	b.fan(Face.Builder.round_rect(Vector2(foot.x - w * 0.5, foot.y - h), Vector2(w, h * 0.16), h * 0.05), FRAME)
	b.polygon(_box(Vector2(foot.x - w * 0.3, foot.y - h * 0.86), Vector2(w * 0.12, h * 0.72)), Color(1, 1, 1, 0.2))

## A tomato pincushion, `r` across half, a few pins in it.
static func cushion(b, at: Vector2, r: float) -> void:
	Scenery.soft_disc(b, at + Vector2(0.0, r * 0.75), r * 1.1, r * 0.3, Color(0.25, 0.15, 0.08, 0.25))
	b.ellipse(at, r, r * 0.8, Color("d9605a"))
	for k in 5:
		var x := at.x + (k - 2) * r * 0.36
		b.stroke(PackedVector2Array([Vector2(x, at.y - r * 0.72 + absf(k - 2) * r * 0.1), Vector2(x, at.y + r * 0.7 - absf(k - 2) * r * 0.1)]), maxf(1.0, r * 0.05), Color("b9483f"))
	b.ellipse(at + Vector2(-r * 0.3, -r * 0.35), r * 0.3, r * 0.16, Color(1, 1, 1, 0.25))
	for k in 4:
		var a := -PI * 0.5 + (k - 1.5) * 0.5
		b.disc(at + Vector2(cos(a), sin(a)) * r * 0.9 + Vector2(0.0, -r * 0.12), r * 0.2, LEAF if k % 2 == 0 else Color("6f9a4f"))
	for p in [[Vector2(-0.4, -0.5), Color("7d8fd9")], [Vector2(0.3, -0.6), Color("f5a623")], [Vector2(0.55, -0.2), Color("e58fb5")]]:
		var base: Vector2 = at + (p[0] as Vector2) * r
		var top := base + Vector2((p[0] as Vector2).x, -1.0).normalized() * r * 0.7
		b.stroke(PackedVector2Array([base, top]), maxf(1.0, r * 0.05), STEEL_DEEP)
		b.disc(top, r * 0.13, p[1])

static func _box(at: Vector2, sz: Vector2) -> PackedVector2Array:
	return PackedVector2Array([at, at + Vector2(sz.x, 0.0), at + sz, at + Vector2(0.0, sz.y)])

static func _shade(b, first: int, top: Color, bottom: Color, y0: float, y1: float) -> void:
	for i in range(first, b.verts.size()):
		var c := top.lerp(bottom, clampf(inverse_lerp(y0, y1, b.verts[i].y), 0.0, 1.0))
		b.cols[i] = Color(c.r, c.g, c.b, b.cols[i].a * c.a)
