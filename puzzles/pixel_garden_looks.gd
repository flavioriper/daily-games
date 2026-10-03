extends RefCounted

## Pixel Garden's copies (the board checkup, 2026-10-03). Every bead on the
## board, every bare peg and every bead in the box was drawn in script on
## every frame it moved -- and the win wave moves all of them at once (256
## beads, 27-38 ms a frame for two seconds on Insane), a plate's iron moves a
## quarter of them, and the box's heaps (14k vertices) were made again on
## every bead seated.
##
## A `Kit` is one drawing in many looks that all share one topology: the same
## vertex count and the same indices, whatever the look (a bead's hole
## closing as it fuses, its shine, its fade). So a layer of any number of
## copies is their looks' vertices transformed and appended natively, their
## colours appended, and one copy's indices tiled n times -- made once and
## sliced (`tiled`), the way Marigold's bits are. Nothing is offset in
## script after the tiling.

const Face = preload("res://ui/faces/face.gd")
const Pal = preload("res://core/palette.gd")
const Scenery = preload("res://ui/flat/scenery.gd")
const Bead = preload("res://ui/faces/bead.gd")

## The steps a bead's fuse, shine, fade and shade are cut into.
const FUSE_STEPS := 16
const SHINE_STEPS := 8
const ALPHA_STEPS := 8
const SHADE_STEPS := 8

class Kit:
	## look id -> [verts, colours]; verts split at `split` (a bead's shade,
	## which stays on the board while the bead lifts, comes first).
	var _looks := {}
	var _make: Callable
	var count := 0
	var split := 0
	var idx := PackedInt32Array()
	var _tiled := PackedInt32Array()
	var _tiled_n := 0

	## `make(id)` draws look `id` about its origin into a Face.Builder and
	## returns [builder, split].
	func _init(make: Callable) -> void:
		_make = make

	func has(id: int) -> bool:
		return _looks.has(id)

	## Look `id` as [verts, colours, shade verts, body verts].
	func look(id: int) -> Array:
		var hit = _looks.get(id)
		if hit != null:
			return hit
		var made: Array = _make.call(id)
		var b: Face.Builder = made[0]
		if count == 0:
			count = b.verts.size()
			split = int(made[1])
			idx = b.idx
		assert(b.verts.size() == count and b.idx.size() == idx.size(), "a look broke the kit's topology")
		var out := [b.verts, b.cols, b.verts.slice(0, split), b.verts.slice(split)]
		_looks[id] = out
		return out

	## One copy's indices tiled `n` times, made once and grown as asked.
	func tiled(n: int) -> PackedInt32Array:
		if n > _tiled_n:
			grow(n - _tiled_n)
		return _tiled.slice(0, n * idx.size())

	## Tiles `more` copies further (a board primes a few a frame).
	func grow(more: int) -> void:
		if count == 0 or more <= 0:
			return
		var per := idx.size()
		var ix := PackedInt32Array()
		ix.resize(more * per)
		for m in more:
			var base := (_tiled_n + m) * count
			var w := m * per
			for k in per:
				ix[w + k] = idx[k] + base
		_tiled.append_array(ix)
		_tiled_n += more

	func tiled_count() -> int:
		return _tiled_n

## Copies of a kit's looks, put together into one mesh.
class Copies:
	var v := PackedVector2Array()
	var c := PackedColorArray()
	var n := 0

	## Look `id` under `xf`.
	func add(kit: Kit, id: int, xf: Transform2D) -> void:
		var l := kit.look(id)
		v.append_array(xf * (l[0] as PackedVector2Array))
		c.append_array(l[1])
		n += 1

	## Look `id` with its shade under `shade` and the rest under `body`.
	func add2(kit: Kit, id: int, shade: Transform2D, body: Transform2D) -> void:
		var l := kit.look(id)
		v.append_array(shade * (l[2] as PackedVector2Array))
		v.append_array(body * (l[3] as PackedVector2Array))
		c.append_array(l[1])
		n += 1

	## `copies` copies already laid out (a cached run of them).
	func add_run(verts: PackedVector2Array, cols: PackedColorArray, copies: int) -> void:
		v.append_array(verts)
		c.append_array(cols)
		n += copies

	func mesh(kit: Kit) -> ArrayMesh:
		if n == 0:
			return null
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = v
		arrays[Mesh.ARRAY_COLOR] = c
		arrays[Mesh.ARRAY_INDEX] = kit.tiled(n)
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return m

## A bead look's id: colour `k`, and its fuse, shine, fade and shade steps,
## and whether the peg shows down its hole.
static func bead_id(k: int, fused: float, shine: float, alpha: float, shade: float, peg_in: bool) -> int:
	var f := roundi(clampf(fused, 0.0, 1.0) * FUSE_STEPS)
	var sh := roundi(clampf(shine, 0.0, 1.0) * SHINE_STEPS)
	var a := roundi(clampf(alpha, 0.0, 1.0) * ALPHA_STEPS)
	var sd := roundi(clampf(shade, 0.0, 1.0) * SHADE_STEPS)
	return ((((k * (FUSE_STEPS + 1) + f) * (SHINE_STEPS + 1) + sh) * (ALPHA_STEPS + 1) + a) * (SHADE_STEPS + 1) + sd) * 2 \
		+ (1 if peg_in else 0)

## A bead kit for a cell `s` wide, its colours `colours`: Bead.bead's drawing
## (ui/faces/bead.gd) with every part always drawn and every ellipse a fixed
## number of points, so all its looks share one topology.
static func bead_kit(s: float, colours: Array) -> Kit:
	var pal := colours.duplicate()
	return Kit.new(func(id: int) -> Array: return _bead_look(id, s, pal))

static func _bead_look(id: int, s: float, colours: Array) -> Array:
	var peg_in := id % 2 == 1
	var v := id / 2
	var sd := float(v % (SHADE_STEPS + 1)) / SHADE_STEPS
	v /= SHADE_STEPS + 1
	var alpha := float(v % (ALPHA_STEPS + 1)) / ALPHA_STEPS
	v /= ALPHA_STEPS + 1
	var shine := float(v % (SHINE_STEPS + 1)) / SHINE_STEPS
	v /= SHINE_STEPS + 1
	var fused := float(v % (FUSE_STEPS + 1)) / FUSE_STEPS
	var k := v / (FUSE_STEPS + 1)
	var colour: Color = colours[k]
	var b := Face.Builder.new()
	var rx := s * Bead.R
	var ry := rx
	var c := colour.lerp(Color.WHITE, shine * 0.28)
	var deep := c.darkened(0.22)
	Scenery.soft_disc(b, Vector2(s * 0.03, s * 0.08), rx * 1.12, ry * 1.02, Color(Pal.TEXT, 0.22 * alpha * sd))
	var split := b.verts.size()
	var top := Vector2.ZERO
	b.ellipse(top + Vector2(0.0, ry * 0.1), rx, ry, Color(deep, alpha))
	b.ellipse(top, rx * 0.97, ry * 0.95, Color(c, alpha))
	var hi := PackedVector2Array()
	var lo := PackedVector2Array()
	for i in 9:
		var a1 := lerpf(PI * 1.05, PI * 1.62, i / 8.0)
		hi.append(top + Vector2(cos(a1) * rx, sin(a1) * ry) * 0.7)
		var a2 := lerpf(PI * 0.05, PI * 0.62, i / 8.0)
		lo.append(top + Vector2(cos(a2) * rx, sin(a2) * ry) * 0.72)
	b.stroke(hi, rx * 0.2, Color(c.lerp(Color.WHITE, 0.55), 0.8 * alpha))
	b.stroke(lo, rx * 0.16, Color(deep, 0.5 * alpha))
	# The hole, with as many points as the open one has, however far it has
	# closed.
	var hole := lerpf(Bead.HOLE, Bead.HOLE_FUSED, clampf(fused, 0.0, 1.0)) / Bead.R
	var hr := Vector2(rx, ry) * hole
	var open_r := Vector2(rx, ry) * (Bead.HOLE / Bead.R)
	var hc := top + Vector2(0.0, ry * 0.02)
	var open := alpha * (1.0 - clampf(fused * 1.5, 0.0, 1.0))
	_ellipse(b, hc, hr * 1.2, Color(deep, alpha), open_r.x * 1.2)
	_ellipse(b, hc, hr, Color(c.darkened(0.45), alpha), open_r.x)
	_ellipse(b, hc + Vector2(0.0, hr.y * 0.28), Vector2(hr.x * 0.8, hr.y * 0.72),
		Color(Pal.PG_BOARD.darkened(0.28).lerp(c.darkened(0.3), 0.25), open), open_r.x * 0.8)
	var po := open if peg_in else 0.0
	var pr := hr * 0.44
	var pc := hc + Vector2(0.0, hr.y * 0.3)
	_ellipse(b, pc + Vector2(0.0, pr.y * 0.3), pr, Color(Pal.PG_PEG_DEEP, po), open_r.x * 0.44)
	_ellipse(b, pc, pr * 0.92, Color(Pal.PG_PEG, po), open_r.x * 0.44 * 0.92)
	_ellipse(b, pc - pr * 0.28, pr * 0.4, Color(Pal.PG_PEG_HI, po), open_r.x * 0.44 * 0.4)
	b.ellipse(top + Vector2(-rx * 0.38, -ry * 0.4), rx * 0.22, ry * 0.14, Color(Color.WHITE, 0.55 * fused * alpha))
	return [b, split]

## An ellipse with as many points as one of radius `as_r` would have.
static func _ellipse(b: Face.Builder, at: Vector2, r: Vector2, colour: Color, as_r: float) -> void:
	var n := Face.Builder.arc_n(as_r, TAU)
	var pts := PackedVector2Array()
	pts.resize(n)
	for i in n:
		var a := TAU * i / n
		pts[i] = at + Vector2(cos(a) * r.x, sin(a) * r.y)
	b.fan(pts, colour)

## A bare peg, a cell `s` wide (one look).
static func peg_kit(s: float) -> Kit:
	return Kit.new(func(_id: int) -> Array:
		var b := Face.Builder.new()
		Bead.peg(b, Vector2.ZERO, s, 1.0)
		return [b, 0])

## A bead lying in the box, of radius `r`, one look a colour: the heap's
## drawing in PixelGarden._heap.
static func heap_kit(r: float, colours: Array) -> Kit:
	var pal := colours.duplicate()
	return Kit.new(func(k: int) -> Array:
		var col: Color = pal[k]
		var b := Face.Builder.new()
		b.ellipse(Vector2(0.0, r * 0.18), r, r * 0.86, col.darkened(0.25))
		b.ellipse(Vector2.ZERO, r * 0.96, r * 0.82, col)
		b.ellipse(Vector2(0.0, r * 0.04), r * 0.4, r * 0.34, col.darkened(0.45))
		if r >= 4.0:
			b.ellipse(-Vector2(r * 0.4, r * 0.32), r * 0.24, r * 0.14, Color(col.lerp(Color.WHITE, 0.6), 0.9))
		return [b, 0])
