extends RefCounted

## Gumdrop's drawing (arcade/gumdrop_screen.gd): the kitchen table, the
## tray, a mould's floor and walls, the card's picture of it, the pots, the
## dropper and the two buttons, each one cached mesh. The syrup itself is
## not here: it is the sim's grid as a texture (`paint`) under
## shaders/gumdrop_syrup_2d.gdshader.
##
## A mould's meshes are built in pixels, `u` of them a mould unit, with the
## mould's corner at the origin.

const Pal = preload("res://core/palette.gd")
const Face = preload("res://ui/faces/face.gd")
const Mould = preload("res://arcade/gumdrop_mould.gd")
const Sim = preload("res://arcade/gumdrop_sim.gd")

const INK := Color("3b3340")
const TABLE := Color("ecd3ab")
const TABLE_HI := Color("f4e2c2")
const TABLE_LOW := Color("dcbc8d")
const TABLE_LINE := Color("c9a473")
const TRAY := Color("3b3e4c")
const TRAY_HI := Color("585c6e")
const TRAY_LOW := Color("2b2d38")
const FLOOR := Color("30323e")
const CLEAR := Color("c9d6e0")
const WALL_TOP := Color("8a8fa3")
const WALL_HI := Color("b4b9c9")
const WALL_LOW := Color("4d5162")
const PAPER := Color("fcf7ef")
const GLASS := Color("eef4f6")
const GLASS_LINE := Color("9fb2bd")
const CORK := Color("c99a63")
const CORK_LOW := Color("a87a48")
const BULB := Color("d9788a")
const BULB_HI := Color("eda2ae")
const BULB_LOW := Color("b65a6e")
const SERVE := Color("f2b63c")
const SERVE_LOW := Color("d99a22")
## The six flavours, in Mould.Flavour's order: the sim's, since the judge
## compares colours.
const FLAVOURS := Sim.FLAVOURS
## The locale key of each flavour's name.
const NAMES := ["GD_CHERRY", "GD_ORANGE", "GD_LEMON", "GD_LIME", "GD_BLUEBERRY", "GD_GRAPE"]
## The jar a pot is, in pixels, its mesh built once.
const JAR_W := 96.0
const JAR_H := 112.0

static var _cache := {}

static func _made(key: String, build: Callable) -> ArrayMesh:
	if _cache.has(key):
		return _cache[key]
	if _cache.size() > 80:
		_cache.clear()
	var b := Face.Builder.new()
	build.call(b)
	var m := b.mesh()
	_cache[key] = m
	return m

## The sim's squares as bytes for the syrup's texture: each one's colour
## (`Sim.colour`: the hue at its strength, deepened past the card's shade)
## times its strength, the strength in alpha, so the shader's cubic blends
## them right and takes the colour back out.
static func paint(sim: RefCounted, into: PackedByteArray) -> void:
	var n: int = Sim.N * Sim.N
	var red: PackedFloat32Array = sim.red
	var yel: PackedFloat32Array = sim.yel
	var blu: PackedFloat32Array = sim.blu
	for i in n:
		var r := red[i]
		var y := yel[i]
		var b := blu[i]
		var at := i * 4
		if r + y + b <= 0.002:
			into[at] = 0
			into[at + 1] = 0
			into[at + 2] = 0
			into[at + 3] = 0
			continue
		var c := Sim.colour(r, y, b)
		var a := c.a * 255.0
		into[at] = int(c.r * a)
		into[at + 1] = int(c.g * a)
		into[at + 2] = int(c.b * a)
		into[at + 3] = int(a)

## The table, the whole screen: pale boards running down it.
static func table(size: Vector2) -> ArrayMesh:
	var b := Face.Builder.new()
	b.fan(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)]), TABLE)
	var board := 216.0
	var k := 0
	var x := -board * 0.35
	while x < size.x:
		if k % 2 == 0:
			b.fan(PackedVector2Array([Vector2(x, 0), Vector2(x + board, 0), Vector2(x + board, size.y), Vector2(x, size.y)]), Color(TABLE_HI, 0.55))
		b.stroke(PackedVector2Array([Vector2(x, -8), Vector2(x, size.y + 8)]), 3.0, Color(TABLE_LINE, 0.55))
		# the grain: a few long faint lines down each board
		for g in 3:
			var gx := x + board * (0.22 + 0.27 * g) + 9.0 * sin(k * 2.3 + g)
			var from := size.y * (0.08 + 0.21 * ((k + g) % 4))
			b.stroke(PackedVector2Array([Vector2(gx, from), Vector2(gx + 5.0, from + size.y * 0.3)]), 2.0, Color(TABLE_LOW, 0.4))
		x += board
		k += 1
	return b.mesh()

## The tray, `side` pixels square with its corner at the origin.
static func tray(side: float) -> ArrayMesh:
	return _made("tray/%.0f" % side, func(b: Face.Builder) -> void:
		var r := side * 0.07
		var lip := side * 0.022
		b.fan(Face.Builder.round_rect(Vector2(-lip, lip * 1.2), Vector2(side + lip * 2.0, side + lip * 1.4), r + lip), Color(0.25, 0.14, 0.06, 0.22))
		b.fan(Face.Builder.round_rect(Vector2(-lip, -lip), Vector2(side + lip * 2.0, side + lip * 2.0), r + lip), TRAY_LOW)
		b.fan(Face.Builder.round_rect(Vector2(-lip, -lip * 1.5), Vector2(side + lip * 2.0, side + lip * 1.6), r + lip), TRAY_HI)
		b.fan(Face.Builder.round_rect(Vector2.ZERO, Vector2(side, side), r), TRAY)
		b.fan(Face.Builder.round_rect(Vector2(side * 0.05, side * 0.03), Vector2(side * 0.5, side * 0.012), side * 0.006), Color(1, 1, 1, 0.07)))

## A mould's floor: its rim's shadow on the tray, the wall's own colour
## under everything, and each cell's clear jelly.
static func floor_of(m: Dictionary, u: float) -> ArrayMesh:
	var b := Face.Builder.new()
	var rim := _scaled(m.rim, u)
	b.polygon(_moved(rim, Vector2(0.9, 1.5) * u), Color(0, 0, 0, 0.3))
	b.polygon(rim, WALL_LOW)
	for cell: PackedVector2Array in m.inner:
		var p := _scaled(cell, u)
		b.polygon(p, FLOOR)
		b.polygon(p, Color(CLEAR, 0.34))
	return b.mesh()

## A mould's walls and rim, drawn over the syrup, and the light lying on
## each cell's jelly.
static func walls_of(m: Dictionary, u: float) -> ArrayMesh:
	var b := Face.Builder.new()
	var w: float = Mould.WALL * u
	var cells: Array = m.cells
	for cell: PackedVector2Array in cells:
		b.stroke(_moved(_scaled(cell, u), Vector2(0.5, 0.8) * u), w, WALL_LOW, true)
	b.stroke(_moved(_scaled(m.outline, u), Vector2(0.5, 0.8) * u), w + Mould.RIM * u, WALL_LOW, true)
	for cell: PackedVector2Array in cells:
		b.stroke(_scaled(cell, u), w * 0.8, WALL_TOP, true)
	b.stroke(_scaled(m.outline, u), w * 0.8 + Mould.RIM * u * 0.6, WALL_TOP, true)
	for cell: PackedVector2Array in cells:
		b.stroke(_moved(_scaled(cell, u), Vector2(-0.35, -0.5) * u), w * 0.22, Color(WALL_HI, 0.8), true)
	for cell: PackedVector2Array in m.inner:
		_shine(b, _scaled(cell, u), u)
	return b.mesh()

## The light on a cell of jelly: a soft glint toward its upper left.
static func _shine(b: Face.Builder, p: PackedVector2Array, u: float) -> void:
	var box := Rect2(p[0], Vector2.ZERO)
	var mid := Vector2.ZERO
	for q in p:
		box = box.expand(q)
		mid += q
	mid /= p.size()
	var at := mid.lerp(box.position, 0.36)
	if not Geometry2D.is_point_in_polygon(at, p):
		at = mid
	var r := clampf(minf(box.size.x, box.size.y) * 0.1, 2.0 * u, 5.0 * u)
	b.ellipse(at, r * 1.5, r * 0.7, Color(1, 1, 1, 0.2))
	b.ellipse(at + Vector2(-r * 0.4, -r * 0.1), r * 0.5, r * 0.28, Color(1, 1, 1, 0.3))

## The card's picture: the mould as it is wanted, every cell its flavour.
static func picture(m: Dictionary, u: float) -> ArrayMesh:
	var b := Face.Builder.new()
	b.polygon(_moved(_scaled(m.rim, u), Vector2(0.6, 1.0) * u), Color(INK, 0.16))
	b.polygon(_scaled(m.rim, u), Color("fffdf8"))
	var want: Array = m.want
	for c in m.inner.size():
		var p := _scaled(m.inner[c], u)
		var col: Color = FLAVOURS[int(want[c])]
		b.polygon(p, col.darkened(0.12))
		var grown: Array = Geometry2D.offset_polygon(m.inner[c], -0.9)
		if not grown.is_empty():
			b.polygon(_moved(_scaled(grown[0], u), Vector2(-0.3, -0.4) * u), col)
	return b.mesh()

static func _scaled(p: PackedVector2Array, u: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(p.size())
	for i in p.size():
		out[i] = p[i] * u
	return out

static func _moved(p: PackedVector2Array, by: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(p.size())
	for i in p.size():
		out[i] = p[i] + by
	return out

## A pot's syrup: what a jar holds when it is `part` full, built with the
## jar's foot at the origin. Twelve fills a flavour are kept. The game's
## pots never run dry (since 2026-10-11) and stand full; the banner's are
## drawn part full.
static func syrup(flavour: int, part: float) -> ArrayMesh:
	var step := int(round(clampf(part, 0.0, 1.0) * 12.0))
	if step <= 0:
		return null
	return _made("syrup/%d/%d" % [flavour, step], func(b: Face.Builder) -> void:
		var w := JAR_W * 0.8
		var h := (JAR_H * 0.72) * step / 12.0
		var col: Color = FLAVOURS[flavour]
		b.fan(Face.Builder.round_rect(Vector2(-w * 0.5, -6.0 - h), Vector2(w, h), 10.0), col.darkened(0.14))
		b.fan(Face.Builder.round_rect(Vector2(-w * 0.5, -6.0 - h), Vector2(w * 0.8, h), 10.0), col)
		b.fan(Face.Builder.round_rect(Vector2(-w * 0.5 + 4.0, -6.0 - h), Vector2(w - 8.0, minf(h, 7.0)), 3.5), col.lightened(0.3)))

## A pot: a small glass jar seen from the side, its foot at the origin,
## drawn over its syrup.
static func jar() -> ArrayMesh:
	return _made("jar", func(b: Face.Builder) -> void:
		var w := JAR_W
		var h := JAR_H
		var body := Face.Builder.round_rect(Vector2(-w * 0.5, -h * 0.84), Vector2(w, h * 0.84), 18.0)
		b.fan(body, Color(GLASS, 0.24))
		b.stroke(body, 5.0, GLASS_LINE, true)
		b.fan(Face.Builder.round_rect(Vector2(-w * 0.56, -h * 0.92), Vector2(w * 1.12, h * 0.13), 7.0), GLASS_LINE)
		b.fan(Face.Builder.round_rect(Vector2(-w * 0.56, -h * 0.92), Vector2(w * 1.12, h * 0.07), 5.0), GLASS)
		b.fan(Face.Builder.round_rect(Vector2(-w * 0.36, -h * 0.72), Vector2(w * 0.1, h * 0.5), 4.0), Color(1, 1, 1, 0.5)))

## A pot's shadow on the table, under everything of it.
static func jar_shadow() -> ArrayMesh:
	return _made("jar_shadow", func(b: Face.Builder) -> void:
		b.ellipse(Vector2(4.0, 2.0), JAR_W * 0.6, 13.0, Color(0.25, 0.14, 0.06, 0.2)))

## The ring a picked pot stands in.
static func jar_ring() -> ArrayMesh:
	return _made("jar_ring", func(b: Face.Builder) -> void:
		b.fan(Face.Builder.round_rect(Vector2(-JAR_W * 0.5 - 15.0, -JAR_H - 6.0), Vector2(JAR_W + 30.0, JAR_H + 24.0), 30.0), Color(1, 1, 1, 0.5))
		b.stroke(Face.Builder.round_rect(Vector2(-JAR_W * 0.5 - 15.0, -JAR_H - 6.0), Vector2(JAR_W + 30.0, JAR_H + 24.0), 30.0), 6.0, Color("fffdf8"), true))

## The dropper's glass with a flavour in it: its tip at the origin, the
## glass standing straight up from there, `len` pixels long.
static func dropper(flavour: int, length: float) -> ArrayMesh:
	return _made("dropper/%d/%.0f" % [flavour, length], func(b: Face.Builder) -> void:
		var w := length * 0.15
		var neck := length * 0.3
		var col: Color = FLAVOURS[flavour]
		var glass := PackedVector2Array([Vector2(-1.5, 0), Vector2(1.5, 0), Vector2(w * 0.2, -neck * 0.8), Vector2(w * 0.5, -neck),
			Vector2(w * 0.5, -length), Vector2(-w * 0.5, -length), Vector2(-w * 0.5, -neck), Vector2(-w * 0.2, -neck * 0.8)])
		b.polygon(_moved(glass, Vector2(5.0, 6.0)), Color(0, 0, 0, 0.16))
		b.polygon(glass, Color(GLASS, 0.9))
		# the syrup drawn up into it
		b.polygon(PackedVector2Array([Vector2(-1.0, -2.0), Vector2(1.0, -2.0), Vector2(w * 0.14, -neck * 0.8), Vector2(w * 0.34, -neck),
			Vector2(w * 0.34, -length * 0.74), Vector2(-w * 0.34, -length * 0.74), Vector2(-w * 0.34, -neck), Vector2(-w * 0.14, -neck * 0.8)]), col)
		b.stroke(glass, 3.0, GLASS_LINE, true)
		b.stroke(PackedVector2Array([Vector2(-w * 0.2, -neck * 1.1), Vector2(-w * 0.2, -length * 0.9)]), w * 0.12, Color(1, 1, 1, 0.6))
		b.fan(Face.Builder.round_rect(Vector2(-w * 0.72, -length - 5.0), Vector2(w * 1.44, 12.0), 5.0), GLASS_LINE))

## The dropper's rubber bulb, its foot at the origin: squashed by the
## transform as it is squeezed.
static func bulb(length: float) -> ArrayMesh:
	return _made("bulb/%.0f" % length, func(b: Face.Builder) -> void:
		var w := length * 0.2
		var h := length * 0.42
		b.ellipse(Vector2(5.0, -h * 0.5 + 6.0), w, h * 0.52, Color(0, 0, 0, 0.16))
		b.ellipse(Vector2(0, -h * 0.5), w, h * 0.52, BULB_LOW)
		b.ellipse(Vector2(-w * 0.08, -h * 0.53), w * 0.86, h * 0.46, BULB)
		b.ellipse(Vector2(-w * 0.36, -h * 0.66), w * 0.2, h * 0.16, Color(BULB_HI, 0.9)))

## The squeeze button: the bulb seen from above, a drop on it.
static func squeeze_button(r: float) -> ArrayMesh:
	return _made("squeeze/%.0f" % r, func(b: Face.Builder) -> void:
		b.disc(Vector2(0, 0.09 * r), r, Color(0.25, 0.14, 0.06, 0.25))
		b.disc(Vector2.ZERO, r, Color("fffdf8"))
		b.disc(Vector2.ZERO, 0.9 * r, BULB_LOW)
		b.disc(Vector2(0, -0.05 * r), 0.84 * r, BULB)
		b.ellipse(Vector2(-0.3, -0.48) * r, 0.34 * r, 0.14 * r, Color(BULB_HI, 0.8))
		_drop(b, Vector2(0, 0.04 * r), 0.36 * r, Color("fffdf8")))

static func _drop(b: Face.Builder, c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array([c + Vector2(0, -r * 1.25)])
	pts.append_array(Face.Builder.arc_points(c + Vector2(0, r * 0.2), r * 0.78, -PI * 0.2, PI * 1.2))
	b.polygon(pts, col)

## The serve button: a round of gold with a tick on it.
static func serve_button(r: float) -> ArrayMesh:
	return _made("serve/%.0f" % r, func(b: Face.Builder) -> void:
		b.disc(Vector2(0, 0.1 * r), r, Color(0.25, 0.14, 0.06, 0.25))
		b.disc(Vector2.ZERO, r, Color("fffdf8"))
		b.disc(Vector2.ZERO, 0.9 * r, SERVE_LOW)
		b.disc(Vector2(0, -0.05 * r), 0.84 * r, SERVE)
		b.stroke(PackedVector2Array([Vector2(-0.36, 0.02) * r, Vector2(-0.1, 0.28) * r, Vector2(0.4, -0.26) * r]), 0.17 * r, Color("fffdf8")))

## The card the picture lies on, `size` pixels with its corner at the
## origin, a strip of tape across its top.
static func card(size: Vector2) -> ArrayMesh:
	return _made("card/%.0f/%.0f" % [size.x, size.y], func(b: Face.Builder) -> void:
		b.fan(Face.Builder.round_rect(Vector2(3.0, 7.0), size, 22.0), Color(0.25, 0.14, 0.06, 0.2))
		b.fan(Face.Builder.round_rect(Vector2.ZERO, size, 22.0), PAPER)
		b.fan(Face.Builder.round_rect(Vector2(size.x * 0.5 - 46.0, -12.0), Vector2(92.0, 26.0), 4.0), Color("f2d98a", 0.85)))
