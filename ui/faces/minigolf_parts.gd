extends RefCounted

## Mini Golf's drawings: builder shapes, not Controls -- the board bakes a
## whole hole into one mesh, and the menu card and the tutorial draw the
## same pieces (ui/faces/patch_cloth.gd's reason). Everything takes the
## field's top-left `o` and the pixels a field unit `s`, and reads the hole
## off a `puzzles/minigolf_sim.gd`.

const Pal = preload("res://core/palette.gd")
const Face = preload("res://ui/faces/face.gd")
const Scenery = preload("res://ui/flat/scenery.gd")
const Sim = preload("res://puzzles/minigolf_sim.gd")

## The kerb's width, the lip it shows toward the foot of the card, and how
## round its outer corners are, in field units.
const KERB := 2.3
const LIP := 0.9
const DROP := 1.1

static func _hash(a: int, b: int) -> float:
	var h := (a * 374761393 + b * 668265263) ^ (a * b * 1274126177)
	h = (h ^ (h >> 13)) * 1274126177
	return float((h ^ (h >> 16)) & 0x7fffffff) / float(0x7fffffff)

## The green's shape grown `grow` units and moved by `shift`, in one
## colour: a rounded square a square of it, and a plain bar across every
## join between two neighbours, so only the shape's own corners are round.
static func _slab(b: Face.Builder, sim, o: Vector2, s: float, grow: float, shift: Vector2, round: float, colour: Color) -> void:
	var count: int = sim.cells.size()
	for i in count:
		if sim.cells[i] == 0:
			continue
		var r := Sim.cell_rect(i).grow(grow)
		b.fan(Face.Builder.round_rect(o + (r.position + shift) * s, r.size * s, round), colour)
		var mid := Sim.cell_mid(i) + shift
		var half := Sim.CELL * 0.5 + grow
		if i % Sim.COLS < Sim.COLS - 1 and sim.cells[i + 1] == 1:
			var a := o + (mid + Vector2(0.0, -half)) * s
			var z := o + (mid + Vector2(Sim.CELL, half)) * s
			b.fan(PackedVector2Array([a, Vector2(z.x, a.y), z, Vector2(a.x, z.y)]), colour)
		if i + Sim.COLS < count and sim.cells[i + Sim.COLS] == 1:
			var a := o + (mid + Vector2(-half, 0.0)) * s
			var z := o + (mid + Vector2(half, Sim.CELL)) * s
			b.fan(PackedVector2Array([a, Vector2(z.x, a.y), z, Vector2(a.x, z.y)]), colour)

## The squares of the green as [top-left, size] in pixels.
static func _squares(sim, o: Vector2, s: float) -> Array:
	var out: Array = []
	var count: int = sim.cells.size()
	for i in count:
		if sim.cells[i] == 0:
			continue
		var r := Sim.cell_rect(i)
		out.append([o + r.position * s, r.size * s])
	return out

## A whole hole at rest: the shade under it, the kerb, the felt and its mown
## squares, the cut corners, slopes, sand, water, the tee's mat, blocks,
## posts and the cup. The ball, the flag and the gates are the board's.
static func hole(b: Face.Builder, sim, o: Vector2, s: float) -> void:
	var round := KERB * s * 0.9
	# the shade the whole course throws on the lawn
	# (opaque: the slab's squares and bars overlap, and a see-through shade
	# would be darker wherever two of them do)
	_slab(b, sim, o, s, KERB, Vector2(0.0, DROP + LIP), round, Pal.GF_LAWN_DEEP.darkened(0.07))
	# the kerb: its shaded side, then its top, then a lit line along it
	_slab(b, sim, o, s, KERB, Vector2(0.0, LIP), round, Pal.GF_KERB_DEEP)
	_slab(b, sim, o, s, KERB, Vector2.ZERO, round, Pal.GF_KERB)
	_slab(b, sim, o, s, KERB - 0.55, Vector2.ZERO, round * 0.7, Pal.GF_KERB_HI)
	_slab(b, sim, o, s, KERB - 1.25, Vector2.ZERO, round * 0.45, Pal.GF_KERB)
	# the felt: the shade under the kerb's inner edge first, then the green
	for q: Array in _squares(sim, o, s):
		b.fan(PackedVector2Array([q[0], q[0] + Vector2(q[1].x, 0.0), q[0] + q[1], q[0] + Vector2(0.0, q[1].y)]), Pal.GF_FELT)
	# mown squares, a quarter of a square each, chequered
	var half := Sim.CELL * 0.5
	var count: int = sim.cells.size()
	for i in count:
		if sim.cells[i] == 0:
			continue
		var r := Sim.cell_rect(i)
		var c := i % Sim.COLS
		var row := i / Sim.COLS
		for k in 4:
			var kx := k % 2
			var ky := k / 2
			if (c * 2 + kx + row * 2 + ky) % 2 == 1:
				continue
			var at := o + (r.position + Vector2(kx, ky) * half) * s
			b.fan(PackedVector2Array([at, at + Vector2(half * s, 0.0), at + Vector2(half, half) * s, at + Vector2(0.0, half * s)]), Pal.GF_FELT_ALT)
	# the kerb's shade on the felt: a dark band along every top and left edge
	var kerbs: int = sim.seg_a.size()
	for k in kerbs:
		if sim.seg_gate[k] >= 0:
			continue
		var a: Vector2 = sim.seg_a[k]
		var ab: Vector2 = sim.seg_ab[k]
		if absf(ab.x) > 0.01 and absf(ab.y) > 0.01:
			continue
		# only the kerbs, not the blocks (their own shade is drawn with them)
		var mid := a + ab * 0.5
		var into := Vector2(0.0, 1.0) if absf(ab.x) > 0.01 else Vector2(1.0, 0.0)
		if not sim.open_at(mid + into * 1.0, 0.0) or sim.open_at(mid - into * 1.0, 0.0):
			continue
		if not _on_grid(a) or not _on_grid(a + ab):
			continue
		var w := 1.1 * s
		var p0 := o + a * s
		var p1 := o + (a + ab) * s
		_quad(b, p0, p1, p1 + into * w, p0 + into * w, Color(Pal.GF_FELT_DEEP, 0.75), Color(Pal.GF_FELT_DEEP, 0.0))
	# slopes: a paler square with arrows the way it runs
	for i in count:
		if sim.slope[i] == 0:
			continue
		var dir: Vector2 = Sim.DIRS[sim.slope[i] - 1]
		var r := Sim.cell_rect(i).grow(-1.2)
		b.fan(Face.Builder.round_rect(o + r.position * s, r.size * s, 1.6 * s), Color(Pal.GF_FELT_HI, 0.22))
		var mid := o + Sim.cell_mid(i) * s
		var side := Vector2(-dir.y, dir.x)
		for row in 3:
			for col in 2:
				var at := mid + dir * (float(row) - 1.0) * 4.6 * s + side * (float(col) - 0.5) * 6.4 * s
				arrow(b, at, dir, 1.9 * s, Color(Pal.GF_FELT_HI, 0.85))
	# sand
	var k := 0
	var sands: int = sim.sand.size()
	var ponds: int = sim.water.size()
	while k < sands:
		var at := o + Vector2(sim.sand[k], sim.sand[k + 1]) * s
		var rx: float = sim.sand[k + 2] * s
		var ry: float = sim.sand[k + 3] * s
		b.fan(_blob(at, rx + 0.5 * s, ry + 0.5 * s, k), Pal.GF_SAND_DEEP)
		b.fan(_blob(at + Vector2(0.0, 0.35 * s), rx, ry, k), Pal.GF_SAND)
		for n in 9:
			var a := _hash(k + n, 5) * TAU
			var d := sqrt(_hash(k + n, 9)) * 0.7
			b.disc(at + Vector2(cos(a) * rx, sin(a) * ry) * d, 0.28 * s, Pal.GF_SAND_DEEP)
		k += 4
	# water
	k = 0
	while k < ponds:
		var at := o + Vector2(sim.water[k], sim.water[k + 1]) * s
		var rx: float = sim.water[k + 2] * s
		var ry: float = sim.water[k + 3] * s
		b.fan(_blob(at, rx + 0.55 * s, ry + 0.55 * s, k + 40), Pal.GF_FELT_DEEP)
		b.fan(_blob(at, rx, ry, k + 40), Pal.GF_WATER_DEEP)
		b.fan(_blob(at + Vector2(0.0, 0.45 * s), rx - 0.3 * s, ry - 0.5 * s, k + 40), Pal.GF_WATER)
		b.stroke(Face.Builder.arc_points(at + Vector2(-rx * 0.1, -ry * 0.05), rx * 0.55, PI * 1.05, PI * 1.5), 0.35 * s, Color(Pal.GF_WATER_HI, 0.9))
		b.stroke(Face.Builder.arc_points(at + Vector2(rx * 0.15, ry * 0.2), rx * 0.3, PI * 0.1, PI * 0.55), 0.3 * s, Color(Pal.GF_WATER_HI, 0.7))
		k += 4
	# the cut corners: a wedge of kerb
	for id: int in sim.cuts:
		var e := Sim.cut_ends(id)
		var p0: Vector2 = o + e[0] * s
		var p1: Vector2 = o + e[1] * s
		var corner: Vector2 = o + e[2] * s
		var lean := Vector2(0.0, LIP * s * 0.8)
		b.fan(PackedVector2Array([p0 + lean, p1 + lean, corner]), Pal.GF_KERB_DEEP)
		b.fan(PackedVector2Array([p0, p1, corner]), Pal.GF_KERB)
		var inner := (corner - (p0 + p1) * 0.5).normalized()
		b.stroke(PackedVector2Array([p0 + inner * 0.55 * s, p1 + inner * 0.55 * s]), 0.45 * s, Pal.GF_KERB_HI, false, false)
	# the tee's mat
	var tee: Vector2 = o + sim.tee * s
	b.fan(Face.Builder.round_rect(tee - Vector2(3.4, 2.6) * s, Vector2(6.8, 5.2) * s, 1.2 * s), Color(Pal.GF_FELT_DEEP, 0.55))
	for sx: float in [-2.4, 2.4]:
		b.disc(tee + Vector2(sx, 0.0) * s, 0.42 * s, Pal.GF_POLE)
	# the blocks
	for q in sim.blocks:
		block(b, o, s, q)
	# the posts
	for q: Vector3 in sim.posts:
		post(b, o + Vector2(q.x, q.y) * s, q.z * s)
	cup(b, o + sim.cup * s, Sim.CUP_R * s)

static func _on_grid(at: Vector2) -> bool:
	var g := (at - Sim.ORIGIN) / Sim.CELL
	return absf(g.x - roundf(g.x)) < 0.01 and absf(g.y - roundf(g.y)) < 0.01

static func _quad(b: Face.Builder, p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, near: Color, far: Color) -> void:
	var base := b.verts.size()
	b.verts.append_array(PackedVector2Array([p0, p1, p2, p3]))
	b.cols.append_array(PackedColorArray([near, near, far, far]))
	b.idx.append_array(PackedInt32Array([base, base + 1, base + 2, base, base + 2, base + 3]))

## An oval a little out of true, the same every time for the same `k`.
static func _blob(at: Vector2, rx: float, ry: float, k: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n := 28
	var phase := _hash(k, 3) * TAU
	for i in n:
		var a := TAU * float(i) / float(n)
		var wob := 1.0 + 0.05 * sin(a * 3.0 + phase) + 0.03 * sin(a * 5.0 + phase * 2.0)
		pts.append(at + Vector2(cos(a) * rx, sin(a) * ry) * wob)
	return pts

## A chevron at `at` pointing `dir`, `r` to its tips.
static func arrow(b: Face.Builder, at: Vector2, dir: Vector2, r: float, colour: Color) -> void:
	var side := Vector2(-dir.y, dir.x)
	b.stroke(PackedVector2Array([at - dir * r * 0.45 + side * r * 0.8, at + dir * r * 0.45, at - dir * r * 0.45 - side * r * 0.8]),
		r * 0.36, colour)

static func block(b: Face.Builder, o: Vector2, s: float, q) -> void:
	var pts := Sim.block_points(q)
	var lean := Vector2(0.0, LIP * s)
	var shade := PackedVector2Array()
	var side := PackedVector2Array()
	var top := PackedVector2Array()
	for p in pts:
		shade.append(o + p * s + lean * 2.0)
		side.append(o + p * s + lean)
		top.append(o + p * s)
	b.fan(shade, Color(Pal.GF_FELT_DEEP, 0.7))
	b.fan(side, Pal.GF_KERB_DEEP)
	b.fan(top, Pal.GF_KERB)
	var mid := o + Vector2(float(q[0]), float(q[1])) * s
	var inner := PackedVector2Array()
	for p in top:
		inner.append(mid + (p - mid) * 0.62)
	b.stroke(inner, 0.4 * s, Color(Pal.GF_KERB_HI, 0.9), true)

## A bumper post: a round cap with a lip, a ring and a shine.
static func post(b: Face.Builder, at: Vector2, r: float, swell := 1.0) -> void:
	var rr := r * swell
	Scenery.soft_disc(b, at + Vector2(0.0, r * 0.55), rr * 1.25, rr * 0.9, Color(0.1, 0.25, 0.12, 0.28))
	b.disc(at + Vector2(0.0, r * 0.34), rr, Pal.GF_POST_DEEP)
	b.disc(at, rr, Pal.GF_POST)
	b.disc(at, rr * 0.62, Pal.GF_POST_HI)
	b.disc(at, rr * 0.36, Pal.GF_BALL)
	b.ellipse(at + Vector2(-rr * 0.42, -rr * 0.5), rr * 0.2, rr * 0.11, Color(1.0, 1.0, 1.0, 0.7))

static func cup(b: Face.Builder, at: Vector2, r: float) -> void:
	b.disc(at, r * 1.16, Color(Pal.GF_CUP_RIM, 0.55))
	b.disc(at, r, Pal.GF_CUP)
	# the far wall catches the light
	b.fan(Face.Builder.arc_points(at + Vector2(0.0, r * 0.22), r * 0.82, PI * 0.08, PI * 0.92), Color(1.0, 1.0, 1.0, 0.1))

## The ball about `at`: `r` its radius, `sink` 0..1 how far it has dropped
## into the cup.
static func ball(b: Face.Builder, at: Vector2, r: float, sink := 0.0, lift := 0.0) -> void:
	var k := 1.0 - 0.55 * sink
	var rr := r * k
	if sink < 0.5:
		Scenery.soft_disc(b, at + Vector2(r * 0.18, r * 0.5 + lift * 0.6), rr * (1.15 + lift / r * 0.08), rr * 0.8, Color(0.08, 0.2, 0.1, 0.3 * (1.0 - sink * 2.0)))
	var c := at - Vector2(0.0, lift)
	b.disc(c, rr, Pal.GF_BALL_SHADE.darkened(0.25 * sink))
	b.disc(c + Vector2(-rr * 0.07, -rr * 0.1), rr * 0.9, Pal.GF_BALL.darkened(0.3 * sink))
	b.ellipse(c + Vector2(-rr * 0.32, -rr * 0.38), rr * 0.26, rr * 0.17, Color(1.0, 1.0, 1.0, 0.95 * (1.0 - sink)))
	for d: Vector2 in [Vector2(0.3, 0.2), Vector2(0.0, 0.45), Vector2(0.42, -0.2)]:
		b.disc(c + d * rr, rr * 0.09, Color(Pal.GF_BALL_SHADE, 0.8 * (1.0 - sink)))

## The flag in the cup at `at`: `h` the pole's height, `wave` the pennant's
## flutter (radians of phase), `lift` 0..1 how far it has been pulled out.
static func flag(b: Face.Builder, at: Vector2, h: float, wave: float, lift := 0.0, fade := 1.0) -> void:
	if fade <= 0.0:
		return
	var foot := at - Vector2(0.0, lift * h * 0.6)
	var top := foot - Vector2(0.0, h)
	var w := h * 0.045
	Scenery.soft_disc(b, at + Vector2(h * 0.2, h * 0.04), h * 0.26, h * 0.06, Color(0.08, 0.2, 0.1, 0.22 * fade * (1.0 - lift)))
	b.stroke(PackedVector2Array([foot, top]), w * 2.0, Color(Pal.GF_POLE, fade))
	b.disc(top, w * 1.5, Color(Pal.GF_POST, fade))
	# the pennant: a triangle whose free edge ripples
	var a := top + Vector2(w, h * 0.04)
	var z := top + Vector2(w, h * 0.4)
	var tip := top + Vector2(h * 0.5, h * 0.2 + sin(wave) * h * 0.035)
	var belly := Vector2(0.0, sin(wave + 1.3) * h * 0.03)
	var edge := Face.Builder.bezier2(a, (a + tip) * 0.5 + belly + Vector2(0.0, -h * 0.02), tip, 8)
	edge.append(tip)
	var back := Face.Builder.bezier2(tip, (z + tip) * 0.5 + belly + Vector2(0.0, h * 0.02), z, 8)
	edge.append_array(back)
	edge.append(z)
	b.polygon(edge, Color(Pal.GF_FLAG, fade))
	b.stroke(PackedVector2Array([z, (z + tip) * 0.5 + belly + Vector2(0.0, h * 0.02), tip]), w * 0.9, Color(Pal.GF_FLAG_DEEP, fade), false, false)

## A gate between `a` and `z` (pixels): `shut` 1 across the lane, 0 swung
## back along the kerb about `a`.
static func gate(b: Face.Builder, a: Vector2, z: Vector2, shut: float, s: float) -> void:
	var across := z - a
	var length := across.length()
	var dir := across / length
	var open_dir := Vector2(-dir.y, dir.x)
	# swung open it lies along the kerb, drawn in a little so it stays on the felt
	var turn := (1.0 - shut) * PI * 0.5
	var arm := dir.rotated(turn) if open_dir.y <= 0.0 or absf(open_dir.x) > 0.5 else dir.rotated(-turn)
	var hinge := a + dir * 0.9 * s
	var end := hinge + arm * (length - 1.8 * s)
	var lean := Vector2(0.0, LIP * s * 0.7)
	b.stroke(PackedVector2Array([hinge + lean * 1.8, end + lean * 1.8]), 1.5 * s, Color(Pal.GF_FELT_DEEP, 0.6))
	b.stroke(PackedVector2Array([hinge + lean, end + lean]), 1.5 * s, Pal.GF_GATE_DEEP)
	b.stroke(PackedVector2Array([hinge, end]), 1.5 * s, Pal.GF_GATE)
	# pickets
	var n := 5
	for i in n:
		var at := hinge.lerp(end, (float(i) + 0.5) / float(n))
		b.disc(at, 0.34 * s, Pal.GF_GATE_DEEP)
	# the hinge post and the latch post
	for at: Vector2 in [a + dir * 0.9 * s, z - dir * 0.9 * s]:
		b.disc(at + lean, 1.25 * s, Pal.GF_KERB_DEEP)
		b.disc(at, 1.25 * s, Pal.GF_KERB)
		b.disc(at, 0.6 * s, Pal.GF_KERB_HI)

## A round hedge of three lobes in two greens, a few leaves lit on top.
static func bush(b: Face.Builder, at: Vector2, r: float, k: int) -> void:
	var lobes := [Vector2(-0.7, 0.15), Vector2(0.7, 0.2), Vector2(0.0, -0.25)]
	for l: Vector2 in lobes:
		b.disc(at + l * r + Vector2(0.0, r * 0.12), r * 0.75, Pal.GF_BUSH_DEEP)
	for l: Vector2 in lobes:
		b.disc(at + l * r, r * 0.7, Pal.GF_BUSH)
	for i in 4:
		var a := -PI * 0.5 + (_hash(k, i) - 0.5) * 2.4
		b.ellipse(at + Vector2(cos(a), sin(a)) * r * 0.75, r * 0.14, r * 0.08, Pal.GF_BUSH_HI)

static func tuft(b: Face.Builder, at: Vector2, h: float) -> void:
	for k in 3:
		var ang := -PI * 0.5 + (float(k) - 1.0) * 0.45
		var tip := at + Vector2(cos(ang), sin(ang)) * h
		b.fan(PackedVector2Array([at + Vector2(-h * 0.12, 0.0), tip, at + Vector2(h * 0.12, 0.0)]), Pal.GF_LAWN_DEEP)

static func daisy(b: Face.Builder, at: Vector2, r: float, eye: Color = Pal.SUN_RAY) -> void:
	for k in 5:
		var a := TAU * float(k) / 5.0
		b.disc(at + Vector2(cos(a), sin(a)) * r * 0.6, r * 0.42, Pal.PAPER)
	b.disc(at, r * 0.36, eye)

## The card's lawn: the mown stripes, hedges in the corners, tufts and
## daisies, none of it where `keep` (pixel rects) says something stands.
static func lawn(b: Face.Builder, size: Vector2, radius: float, keep: Array) -> void:
	b.fan(Face.Builder.round_rect(Vector2.ONE * 2.0, size - Vector2.ONE * 4.0, radius), Pal.GF_LAWN)
	var stripe := 96.0
	var x0 := 2.0
	var k := 0
	while x0 < size.x - 2.0:
		if k % 2 == 0:
			var x1 := minf(x0 + stripe, size.x - 2.0)
			b.fan(PackedVector2Array([Vector2(x0, 14.0), Vector2(x1, 14.0), Vector2(x1, size.y - 14.0), Vector2(x0, size.y - 14.0)]),
				Color(1.0, 1.0, 1.0, 0.07))
		x0 += stripe
		k += 1
	var unit := size.x / 10.0
	for corner: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
		var at := Vector2(corner.x * size.x, corner.y * size.y) + (Vector2.ONE - corner * 2.0) * unit * 0.42
		bush(b, at, unit * 0.3, int(corner.x + corner.y * 2.0))
	for i in 130:
		var at := Vector2(_hash(i, 3) * size.x, 14.0 + _hash(i, 11) * (size.y - 28.0))
		var hit := false
		for r: Rect2 in keep:
			if r.has_point(at):
				hit = true
		if hit:
			continue
		match i % 4:
			0, 1:
				tuft(b, at, unit * (0.13 + 0.08 * _hash(i, 17)))
			2:
				daisy(b, at, unit * (0.07 + 0.03 * _hash(i, 19)))
			3:
				daisy(b, at, unit * (0.06 + 0.02 * _hash(i, 29)), Pal.FLOWER)
