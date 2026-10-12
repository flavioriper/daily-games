extends RefCounted

## Trivet's mats, tray and table (arcade/trivet_board.gd draws with them).
## A mat is a six-sided piece of thick felt seen from a little above: its
## top, three sides that face the player, and a mark pressed into the top,
## one a colour, so a colour is never told by its hue alone. Everything
## here is built once at U pixels to a mat's half width and laid by the
## board's transform: nothing is keyed by a size that changes.

const Face = preload("res://ui/faces/face.gd")
const Sim = preload("res://arcade/trivet_sim.gd")

## A mat's half width in the meshes' own pixels.
const U := 100.0
## How much the tray is seen from above: a mat's depth on the page over
## its width, and its thickness.
const SQ := 0.8
const TH := 0.17
## The felts, by the sim's colour index, and the ink the page letters in.
const FELT := [Color("d9694f"), Color("e6b441"), Color("7fae6a"), Color("4f9fb5"), Color("9a6bb0"), Color("e79aa6")]
const INK := Color("4a3626")
const CREAM := Color("fffaf0")
const TABLE := Color("b98a5e")
const TABLE_HI := Color("c99a6c")
const TABLE_LOW := Color("a3764c")
const TRAY := Color("8a6038")
const TRAY_HI := Color("a2744a")
const TRAY_LOW := Color("6c4826")
const DENT := Color("5e3f22")
const CLOTH := Color("ede0c8")
const CLOTH_LOW := Color("d9c8a8")
const THREAD := Color("c9a56e")
const LAMP := Color("fff0c4")
const HALO := Color("fff4c2")
const AMBER := Color("f2a13a")

static var _mats := {}
static var _one := {}

## The six corners of a mat of half width `r` about `c`, flat sides up and
## down, the first at the right and round by the front.
static func hex(c: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 6:
		var a := TAU * i / 6.0
		pts.append(c + Vector2(cos(a) * r, sin(a) * r * SQ))
	return pts

## A place's middle in mat widths from the tray's: `cell` in the sim's
## axial coordinates.
static func place_of(cell: Vector2i) -> Vector2:
	return Vector2(1.5 * cell.x, sqrt(3.0) * (cell.y + cell.x * 0.5) * SQ) * 1.04

## One mat of `col` into `b`, its foot's middle at `at`.
static func mat_into(b: Face.Builder, col: int, at: Vector2, marked := true) -> void:
	var felt: Color = FELT[col]
	var top := at - Vector2(0, TH * U)
	var up := hex(top, U)
	var down := hex(at, U)
	# the three sides that face the player: right, front, left
	var shade := [0.2, 0.3, 0.38]
	for k in 3:
		b.fan(PackedVector2Array([up[k], up[k + 1], down[k + 1], down[k]]), felt.darkened(shade[k]))
	b.fan(up, felt.darkened(0.06))
	b.fan(hex(top - Vector2(0, 1.5), U * 0.9), felt.lightened(0.07))
	if marked:
		_mark(b, col, top, felt.lightened(0.34))

## The mark pressed into a colour's top.
static func _mark(b: Face.Builder, col: int, c: Vector2, ink: Color) -> void:
	var r := U * 0.3
	var flat := Vector2(1.0, SQ)
	match col:
		0:
			b.ellipse(c, r * 0.8, r * 0.8 * SQ, ink)
		1:
			b.stroke(Face.Builder.ring(c, r * 0.85, r * 0.85 * SQ), r * 0.34, ink, true)
		2:
			b.fan(PackedVector2Array([c + Vector2(0, -r) * flat, c + Vector2(r * 0.95, r * 0.7) * flat, c + Vector2(-r * 0.95, r * 0.7) * flat]), ink)
		3:
			b.fan(PackedVector2Array([c + Vector2(0, -r) * flat, c + Vector2(r, 0) * flat, c + Vector2(0, r) * flat, c + Vector2(-r, 0) * flat]), ink)
		4:
			b.stroke(PackedVector2Array([c - Vector2(r * 0.85, 0), c + Vector2(r * 0.85, 0)]), r * 0.42, ink)
			b.stroke(PackedVector2Array([c - Vector2(0, r * 0.85 * SQ), c + Vector2(0, r * 0.85 * SQ)]), r * 0.42, ink)
		_:
			for k in 3:
				var a := TAU * k / 3.0 - PI * 0.5
				b.ellipse(c + Vector2(cos(a), sin(a) * SQ) * r * 0.55, r * 0.42, r * 0.42 * SQ, ink)

## One mat by itself: what flies from stack to stack.
static func mat(col: int) -> ArrayMesh:
	if not _mats.has(col):
		var b := Face.Builder.new()
		mat_into(b, col, Vector2.ZERO)
		_mats[col] = b.mesh()
	return _mats[col]

## A stack, bottom to top, its foot's middle at the origin. Only the top mat
## wears its mark: the rest show their sides. `tag` leaves a cream button on
## the top's front edge for the count the board letters on it.
static func stack(mats: Array, tag := false) -> ArrayMesh:
	if mats.is_empty():
		return null
	var b := Face.Builder.new()
	b.ellipse(Vector2(0, U * 0.1), U * 1.04, U * SQ * 1.02, Color(0.16, 0.09, 0.03, 0.24))
	for i in mats.size():
		mat_into(b, int(mats[i]), Vector2(0, -i * TH * U), i == mats.size() - 1)
	if tag:
		var at := tag_at(mats.size())
		b.ellipse(at + Vector2(0, 3.0), U * 0.27, U * 0.27, Color(INK, 0.3))
		b.ellipse(at, U * 0.27, U * 0.27, CREAM)
	return b.mesh()

## Where a stack of `n` mats wears its count, from its foot's middle.
static func tag_at(n: int) -> Vector2:
	return Vector2(U * 0.56, -n * TH * U + U * 0.46 * SQ)

## The middle of the top of a stack of `n` mats, from its foot's middle.
static func top_of(n: int) -> Vector2:
	return Vector2(0, -n * TH * U)

## The lid over a place not yet open: a turned wooden cover with a knob.
static func lid() -> ArrayMesh:
	if not _one.has("lid"):
		var b := Face.Builder.new()
		var up := hex(Vector2(0, -U * 0.1), U * 0.94)
		var down := hex(Vector2.ZERO, U * 0.94)
		for k in 3:
			b.fan(PackedVector2Array([up[k], up[k + 1], down[k + 1], down[k]]), TRAY_LOW.darkened(0.1 * k))
		b.fan(up, TRAY_HI)
		b.fan(hex(Vector2(0, -U * 0.115), U * 0.8), TRAY_HI.lightened(0.08))
		b.stroke(hex(Vector2(0, -U * 0.115), U * 0.62), 3.0, Color(TRAY_LOW, 0.5), true)
		b.ellipse(Vector2(0, -U * 0.1), U * 0.2, U * 0.2 * SQ, TRAY_LOW)
		b.ellipse(Vector2(0, -U * 0.17), U * 0.17, U * 0.17 * SQ, THREAD)
		b.ellipse(Vector2(-U * 0.04, -U * 0.2), U * 0.07, U * 0.05, Color(CREAM, 0.6))
		_one["lid"] = b.mesh()
	return _one["lid"]

## The tray under the places, in the meshes' own pixels about the tray's
## middle: a wooden board cut to the places' outline, a dent a place.
static func tray(cells: Array) -> ArrayMesh:
	var b := Face.Builder.new()
	for c: Vector2i in cells:
		b.fan(hex(place_of(c) * U + Vector2(0, U * 0.3), U * 1.2), Color(0.16, 0.09, 0.03, 0.2))
	for c: Vector2i in cells:
		b.fan(hex(place_of(c) * U + Vector2(0, U * 0.13), U * 1.16), TRAY_LOW)
	for c: Vector2i in cells:
		b.fan(hex(place_of(c) * U, U * 1.16), TRAY)
	for c: Vector2i in cells:
		b.fan(hex(place_of(c) * U - Vector2(0, U * 0.02), U * 1.06), TRAY_HI)
	for c: Vector2i in cells:
		var at := place_of(c) * U
		b.fan(hex(at, U * 0.95), DENT)
		b.fan(hex(at + Vector2(0, U * 0.05), U * 0.9), DENT.lightened(0.09))
	return b.mesh()

## The table, the whole field: planks, a pool of lamplight over the tray
## (`lamp`, in the field's pixels) and the cloth the hand lies on (`cloth`).
static func table(size: Vector2, lamp: Vector2, lamp_r: float, cloth: Rect2) -> ArrayMesh:
	var b := Face.Builder.new()
	b.fan(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)]), TABLE)
	var plank := 190.0
	var y := -40.0
	var k := 0
	while y < size.y:
		var tone: Color = [TABLE, TABLE_HI, TABLE_LOW, TABLE][k % 4]
		b.fan(PackedVector2Array([Vector2(0, y + 3.0), Vector2(size.x, y + 3.0), Vector2(size.x, y + plank), Vector2(0, y + plank)]), Color(tone, 0.55))
		b.stroke(PackedVector2Array([Vector2(0, y), Vector2(size.x, y)]), 4.0, Color(TABLE_LOW.darkened(0.25), 0.5), false, false)
		# a board's end, somewhere along it
		var end := fposmod(k * 397.0 + 210.0, size.x)
		b.stroke(PackedVector2Array([Vector2(end, y), Vector2(end, y + plank)]), 3.0, Color(TABLE_LOW.darkened(0.25), 0.35), false, false)
		y += plank
		k += 1
	for i in 5:
		var f := 1.0 - i / 5.0
		b.ellipse(lamp, lamp_r * (0.5 + 0.7 * f), lamp_r * (0.5 + 0.7 * f) * 0.86, Color(LAMP, 0.055))
	# the cloth: linen with a stitched hem
	b.fan(Face.Builder.round_rect(cloth.position + Vector2(0, 10.0), cloth.size, 44.0), Color(0.16, 0.09, 0.03, 0.22))
	b.fan(Face.Builder.round_rect(cloth.position, cloth.size, 44.0), CLOTH)
	b.fan(Face.Builder.round_rect(cloth.position + Vector2(0, cloth.size.y * 0.55), Vector2(cloth.size.x, cloth.size.y * 0.45), 44.0), Color(CLOTH_LOW, 0.35))
	stitch(b, Face.Builder.round_rect(cloth.position + Vector2(16, 16), cloth.size - Vector2(32, 32), 30.0), THREAD)
	return b.mesh()

## A line of thread along a closed outline: a stitch, a gap, a stitch.
static func stitch(b: Face.Builder, outline: PackedVector2Array, col: Color) -> void:
	var run := 0.0
	var from := outline[0]
	var on := true
	var last := outline[0]
	for i in range(1, outline.size() + 1):
		var p := outline[i % outline.size()]
		run += last.distance_to(p)
		last = p
		if run >= (16.0 if on else 11.0):
			if on:
				b.stroke(PackedVector2Array([from, p]), 4.0, col)
			from = p
			on = not on
			run = 0.0

## A round wooden button for a tool, `r` across its half, lit when armed.
static func button(r: float, lit: bool, dim: bool) -> ArrayMesh:
	var b := Face.Builder.new()
	b.disc(Vector2(0, 8.0), r, Color(0.16, 0.09, 0.03, 0.3))
	b.disc(Vector2(0, 5.0), r, TRAY_LOW)
	b.disc(Vector2.ZERO, r, HALO if lit else (CLOTH_LOW if dim else CLOTH))
	b.stroke(Face.Builder.ring(Vector2.ZERO, r - 9.0, r - 9.0), 3.0, Color(THREAD, 0.9 if not dim else 0.4), true)
	return b.mesh()

## The brush: a wooden back and its bristles.
static func brush(r: float, dim: bool) -> ArrayMesh:
	var b := Face.Builder.new()
	var a := 0.45 if dim else 1.0
	var back := PackedVector2Array()
	for p: Vector2 in Face.Builder.round_rect(Vector2(-r * 0.62, -r * 0.5), Vector2(r * 1.24, r * 0.42), r * 0.18):
		back.append(p.rotated(-0.35))
	for k in 6:
		var x := lerpf(-r * 0.5, r * 0.5, k / 5.0)
		var from := Vector2(x, -r * 0.1).rotated(-0.35)
		var to := Vector2(x + r * 0.04 * (k - 2.5), r * 0.52).rotated(-0.35)
		b.stroke(PackedVector2Array([from, to]), r * 0.15, Color(FELT[1].darkened(0.1), a))
	b.fan(back, Color(TRAY, a))
	return b.mesh()

## The fresh hand: three small mats fanned.
static func fresh(r: float, dim: bool) -> ArrayMesh:
	var b := Face.Builder.new()
	var a := 0.45 if dim else 1.0
	var s := r * 0.36 / U
	for k in 3:
		var one := Face.Builder.new()
		mat_into(one, [3, 0, 1][k], Vector2.ZERO, false)
		b.append(one.mesh(), Transform2D(0.0, Vector2(s, s), 0.0, Vector2((k - 1) * r * 0.42, r * 0.2 - absf(k - 1.0) * r * -0.12)), Color(1, 1, 1, a))
	return b.mesh()
