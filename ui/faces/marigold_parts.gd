extends RefCounted

## Marigold's drawing, shared by the board (puzzles/marigold2d.gd) and its
## menu card (ui/menu/card_art.gd): the buds and their blooms, the seed, the
## pot, the sun that shoots and its spout. Builder shapes only, so the board
## batches a whole field of buds into one mesh.

const Pal = preload("res://core/palette.gd")
const Face = preload("res://ui/faces/face.gd")
const State = preload("res://puzzles/marigold_state.gd")

## A bud's three colours by kind: body, lit edge, shaded edge.
static func colours(kind: int) -> Array:
	match kind:
		State.ORANGE: return [Pal.MG_ORANGE, Pal.MG_ORANGE_HI, Pal.MG_ORANGE_DEEP]
		State.GREEN: return [Pal.MG_GREEN, Pal.MG_GREEN_HI, Pal.MG_GREEN_DEEP]
		State.PURPLE: return [Pal.MG_PURPLE, Pal.MG_PURPLE_HI, Pal.MG_PURPLE_DEEP]
	return [Pal.MG_BLUE, Pal.MG_BLUE_HI, Pal.MG_BLUE_DEEP]

## A closed bud of radius `r` at `at`: its reflection on the pond, a shaded
## rim, the body, a shine, and the mark that tells the kinds apart without
## their colour -- a marigold's creases (and a warm halo, since it is the
## goal), a clover's three lobes, a violet's five, a bluebell's bell seams.
## Bluebells and marigolds sit in a collar of two leaves.
static func bud(b: Face.Builder, at: Vector2, r: float, kind: int, scale := 1.0, alpha := 1.0) -> void:
	var c: Array = colours(kind)
	var rr := r * scale
	if rr <= 0.2:
		return
	b.ellipse(at + Vector2(0.0, rr * 1.45), rr * 0.78, rr * 0.24, Color(c[2], 0.16 * alpha))
	if kind == State.ORANGE:
		b.disc(at, rr * 1.42, Color(Pal.MG_ORANGE_HI, 0.2 * alpha))
	b.ellipse(at + Vector2(0.0, rr * 0.22), rr * 1.02, rr * 0.9, Color(Pal.TEXT, 0.16 * alpha))
	match kind:
		State.GREEN:
			for k in 3:
				var a := -PI * 0.5 + TAU * float(k) / 3.0
				b.disc(at + Vector2.from_angle(a) * rr * 0.42, rr * 0.62, Color(c[2], alpha))
			for k in 3:
				var a := -PI * 0.5 + TAU * float(k) / 3.0
				b.disc(at + Vector2.from_angle(a) * rr * 0.4, rr * 0.54, Color(c[0], alpha))
			for k in 3:
				var a := -PI * 0.5 + TAU * float(k) / 3.0
				b.stroke(PackedVector2Array([at, at + Vector2.from_angle(a) * rr * 0.62]), rr * 0.1, Color(c[2], 0.6 * alpha))
			b.disc(at, rr * 0.18, Color(c[2], alpha))
		State.PURPLE:
			for k in 5:
				var a := -PI * 0.5 + TAU * float(k) / 5.0
				b.disc(at + Vector2.from_angle(a) * rr * 0.45, rr * 0.55, Color(c[2], alpha))
			for k in 5:
				var a := -PI * 0.5 + TAU * float(k) / 5.0
				b.disc(at + Vector2.from_angle(a) * rr * 0.43, rr * 0.48, Color(c[0], alpha))
			b.disc(at, rr * 0.3, Color(Pal.MG_PURPLE_HI, alpha))
		_:
			for side: float in [-1.0, 1.0]:
				leaf(b, at + Vector2(0.0, rr * 0.45), Vector2(side * 0.85, 0.55).normalized(), rr * 1.3, rr * 0.36,
					Color(Pal.MG_GREEN_DEEP, alpha))
			b.disc(at, rr, Color(c[2], alpha))
			b.disc(at + Vector2(-rr * 0.06, -rr * 0.08), rr * 0.84, Color(c[0], alpha))
			if kind == State.ORANGE:
				# the petals' creases, folded shut
				for k in 3:
					var a := -PI * 0.5 + (float(k) - 1.0) * 0.7
					b.stroke(PackedVector2Array([at + Vector2.from_angle(a) * rr * 0.2, at + Vector2.from_angle(a) * rr * 0.72]),
						rr * 0.13, Color(c[2], 0.7 * alpha))
				b.ellipse(at + Vector2(0.0, -rr * 0.86), rr * 0.3, rr * 0.16, Color(Pal.MG_GREEN_DEEP, alpha))
			else:
				# a bell's seams, curving down from its tip
				for side: float in [-1.0, 1.0]:
					b.stroke(Face.Builder.bezier2(at + Vector2(0.0, -rr * 0.8), at + Vector2(side * rr * 0.55, -rr * 0.2),
						at + Vector2(side * rr * 0.4, rr * 0.62), 8), rr * 0.09, Color(c[2], 0.5 * alpha))
				b.disc(at + Vector2(0.0, -rr * 0.84), rr * 0.16, Color(c[1], alpha))
	b.ellipse(at + Vector2(-rr * 0.32, -rr * 0.36), rr * 0.3, rr * 0.2, Color(1.0, 1.0, 1.0, 0.5 * alpha))

## A leaf from `base` along `dir`, `len` long and `wid` across at its widest.
static func leaf(b: Face.Builder, base: Vector2, dir: Vector2, len: float, wid: float, col: Color) -> void:
	var n := Vector2(-dir.y, dir.x)
	var tip := base + dir * len
	var pts := Face.Builder.bezier2(base, base + dir * len * 0.45 + n * wid * 1.3, tip, 7)
	var back := Face.Builder.bezier2(tip, base + dir * len * 0.45 - n * wid * 1.3, base, 7)
	for k in range(1, back.size() - 1):
		pts.append(back[k])
	b.polygon(pts, col)

## An open bloom: `open` 0 is the bud, 1 the flower wide open. A lit bud's
## glow sits under it; `fade` takes the whole flower out as it is picked.
static func bloom(b: Face.Builder, at: Vector2, r: float, kind: int, open: float, scale := 1.0, alpha := 1.0, spin := 0.0) -> void:
	var c: Array = colours(kind)
	var rr := r * scale
	if rr <= 0.2 or alpha <= 0.0:
		return
	var o := clampf(open, 0.0, 1.2)
	b.disc(at, rr * (1.3 + 0.55 * o), Color(c[1], 0.28 * alpha))
	var petals := 5
	var reach := 0.95
	var pr := 0.62
	match kind:
		State.ORANGE:
			petals = 10
			reach = 1.0
			pr = 0.5
		State.GREEN:
			petals = 4
			reach = 0.72
			pr = 0.68
		State.PURPLE:
			petals = 5
			reach = 0.9
			pr = 0.62
	var turn := 0.25 * o + spin
	if kind == State.ORANGE:
		# a marigold is ruffled: a back ring of deeper petals under the front
		for k in petals:
			var a := -PI * 0.5 + TAU * (float(k) + 0.5) / float(petals) + turn
			b.ellipse(at + Vector2.from_angle(a) * rr * reach * (0.5 + 0.7 * o), rr * pr * (0.6 + 0.4 * o), rr * pr * (0.6 + 0.4 * o),
				Color(c[2], alpha))
	for k in petals:
		var a := -PI * 0.5 + TAU * float(k) / float(petals) + turn
		var at_p := at + Vector2.from_angle(a) * rr * reach * (0.4 + 0.6 * o)
		b.disc(at_p, rr * pr * (0.55 + 0.45 * o), Color(c[0] if kind != State.BLUE else c[1], alpha))
		# each petal's lit tip
		b.disc(at + Vector2.from_angle(a) * rr * reach * (0.55 + 0.75 * o), rr * pr * 0.3 * o,
			Color(1.0, 1.0, 1.0, 0.28 * alpha))
	match kind:
		State.GREEN:
			b.disc(at, rr * 0.3, Color(c[2], alpha))
		State.ORANGE:
			b.disc(at, rr * 0.55, Color(Pal.MG_ORANGE_HI, alpha))
			b.disc(at, rr * 0.3, Color(Pal.MG_ORANGE_DEEP, alpha))
			for k in 6:
				b.disc(at + Vector2.from_angle(TAU * float(k) / 6.0 + turn) * rr * 0.2, rr * 0.07, Color(Pal.SUN_RAY, alpha))
		_:
			b.disc(at, rr * 0.5, Color(c[2], 0.5 * alpha))
			b.disc(at, rr * 0.42, Color(Pal.SUN_RAY, alpha))
			b.disc(at + Vector2(-rr * 0.1, -rr * 0.1), rr * 0.18, Color(1.0, 1.0, 1.0, 0.7 * alpha))

## The seed: a pale pearly bead with a shine and a soft shadow under it.
static func bead(b: Face.Builder, at: Vector2, r: float) -> void:
	b.disc(at + Vector2(0.0, r * 0.25), r * 1.1, Color(Pal.TEXT, 0.22))
	b.disc(at, r * 1.08, Pal.MG_SEED_RIM)
	b.disc(at, r, Pal.MG_SEED_DEEP)
	b.disc(at + Vector2(-r * 0.08, -r * 0.1), r * 0.85, Pal.MG_SEED)
	b.ellipse(at + Vector2(-r * 0.3, -r * 0.34), r * 0.3, r * 0.2, Color(1.0, 1.0, 1.0, 0.9))

## The seed as it flies: a striped kernel pointing along `angle`, with a
## soft shadow round it. The board builds it once at angle 0 and turns it.
static func kernel(b: Face.Builder, at: Vector2, r: float, angle := 0.0) -> void:
	var d := Vector2.from_angle(angle)
	var n := Vector2(-d.y, d.x)
	var shape := func(grow: float) -> PackedVector2Array:
		var pts := PackedVector2Array()
		for k in 18:
			var u := TAU * float(k) / 18.0
			# round at the tail, drawn to a point at the head
			var x := cos(u)
			var y := sin(u) * (0.86 - 0.3 * maxf(0.0, x)) * (1.0 - 0.25 * maxf(0.0, x) * maxf(0.0, x))
			var along := (x * (1.25 if x > 0.0 else 1.05)) * r * grow
			pts.append(at + d * along + n * y * r * grow)
		return pts
	b.disc(at, r * 1.3, Color(Pal.TEXT, 0.14))
	b.polygon(shape.call(1.12), Pal.MG_SEED_RIM)
	b.polygon(shape.call(1.0), Pal.MG_SEED_DEEP)
	b.polygon(shape.call(0.8), Pal.MG_SEED)
	for side: float in [-1.0, 1.0]:
		b.stroke(PackedVector2Array([at - d * r * 0.7 + n * side * r * 0.36, at + d * r * 0.85 + n * side * r * 0.14]),
			r * 0.14, Color(Pal.MG_SEED_RIM, 0.55))
	b.ellipse(at - d * r * 0.2 - n * r * 0.3, r * 0.34, r * 0.22, Color(1.0, 1.0, 1.0, 0.85))

## The pot at the origin, its rim's middle at (0, 0) and `w` across the rim;
## `glow` lights its mouth as a seed drops in.
static func pot(b: Face.Builder, w: float, glow := 0.0) -> void:
	var h := w * 0.62
	var lip := w * 0.16
	var foot := w * 0.36
	b.ellipse(Vector2(0.0, h + lip * 0.4), w * 0.46, lip * 0.45, Color(Pal.TEXT, 0.2))
	b.fan(PackedVector2Array([Vector2(-w * 0.44, lip * 0.5), Vector2(w * 0.44, lip * 0.5),
		Vector2(foot, h), Vector2(-foot, h)]), Pal.MG_POT)
	b.fan(PackedVector2Array([Vector2(w * 0.1, lip * 0.5), Vector2(w * 0.44, lip * 0.5),
		Vector2(foot, h), Vector2(foot * 0.25, h)]), Pal.MG_POT_DEEP)
	b.fan(PackedVector2Array([Vector2(-w * 0.34, lip * 0.9), Vector2(-w * 0.24, lip * 0.9),
		Vector2(-foot * 0.62, h * 0.9), Vector2(-foot * 0.8, h * 0.9)]), Color(Pal.MG_POT_HI, 0.8))
	# a painted band and a marigold on its belly
	b.fan(PackedVector2Array([Vector2(-w * 0.425, lip * 1.1), Vector2(w * 0.425, lip * 1.1),
		Vector2(w * 0.412, lip * 1.55), Vector2(-w * 0.412, lip * 1.55)]), Color(Pal.MG_POT_DEEP, 0.7))
	var mid := Vector2(-w * 0.02, h * 0.62)
	for k in 8:
		b.disc(mid + Vector2.from_angle(TAU * float(k) / 8.0) * w * 0.07, w * 0.045, Pal.MG_ORANGE)
	b.disc(mid, w * 0.05, Pal.MG_ORANGE_DEEP)
	for side: float in [-1.0, 1.0]:
		leaf(b, mid + Vector2(side * w * 0.1, w * 0.05), Vector2(side, 0.25).normalized(), w * 0.11, w * 0.035, Pal.MG_GREEN_DEEP)
	# the rim, and the soil showing in its mouth
	b.fan(Face.Builder.round_rect(Vector2(-w * 0.5, -lip * 0.5), Vector2(w, lip), lip * 0.45), Pal.MG_POT_HI)
	b.fan(Face.Builder.round_rect(Vector2(-w * 0.5, lip * 0.05), Vector2(w, lip * 0.45), lip * 0.2), Color(Pal.MG_POT, 0.8))
	b.ellipse(Vector2(0.0, -lip * 0.12), w * 0.42, lip * 0.26, Pal.MG_SOIL)
	if glow > 0.0:
		b.ellipse(Vector2(0.0, -lip * 0.12), w * (0.42 + 0.2 * glow), lip * (0.3 + 0.5 * glow), Color(Pal.SUN_RAY, 0.55 * glow))
	# a sprout in the pot, for company
	b.stroke(PackedVector2Array([Vector2(0.0, -lip * 0.1), Vector2(0.0, -lip * 1.4)]), w * 0.035, Pal.MG_GREEN_DEEP)
	b.ellipse(Vector2(-w * 0.08, -lip * 1.45), w * 0.09, w * 0.045, Pal.MG_GREEN)
	b.ellipse(Vector2(w * 0.08, -lip * 1.65), w * 0.09, w * 0.045, Pal.MG_GREEN)

## The sun's rays about the origin, radius `R` to the body's edge.
static func sun_rays(b: Face.Builder, R: float) -> void:
	for i in 8:
		var dir := Vector2.from_angle(-PI * 0.5 + i * PI * 0.25)
		b.stroke(PackedVector2Array([dir * 1.18 * R, dir * 1.42 * R]), 0.26 * R, Pal.SUN_RAY)

## The sun's body and face about the origin -- the family's sun.
static func sun_body(b: Face.Builder, R: float, eye: float, expr: int, look := Vector2.ZERO) -> void:
	b.ellipse(Vector2(0.0, 0.18 * R), 1.08 * R, 1.02 * R, Color(Pal.TEXT, 0.12))
	b.disc(Vector2.ZERO, R, Pal.SUN)
	b.stroke(Face.Builder.arc_points(Vector2.ZERO, 0.74 * R, PI * 1.02, PI * 1.6), 0.24 * R, Color(1.0, 1.0, 1.0, 0.22), false, false)
	Face.face_parts(b, R, Vector2(0.0, 0.08 * R) + look * R, Pal.TEXT, eye, expr)

## The spout the seed leaves from, pointing along +x from the sun's middle:
## a curled leaf funnel, and the seed waiting in its mouth when `loaded`.
static func spout(b: Face.Builder, R: float, loaded: bool, reach := 1.4) -> void:
	var len := R * reach
	b.fan(PackedVector2Array([Vector2(R * 0.55, -R * 0.3), Vector2(len, -R * 0.36),
		Vector2(len, R * 0.36), Vector2(R * 0.55, R * 0.3)]), Pal.MG_GREEN_DEEP)
	b.fan(PackedVector2Array([Vector2(R * 0.58, -R * 0.22), Vector2(len - R * 0.04, -R * 0.26),
		Vector2(len - R * 0.04, R * 0.06), Vector2(R * 0.58, R * 0.04)]), Pal.MG_GREEN)
	b.ellipse(Vector2(len, 0.0), R * 0.14, R * 0.38, Pal.MG_GREEN_DEEP)
	if loaded:
		kernel(b, Vector2(len - R * 0.02, 0.0), R * 0.26)
