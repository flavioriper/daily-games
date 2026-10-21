extends RefCounted

## Gumdrop's drawing (puzzles/gumdrop_table.gd): the kitchen table, the
## tray, a jelly's floor and its skin, the card's picture of it, the pots,
## the needle and the two buttons, each one cached mesh. The syrup itself is
## not here: it is the fluid's dye texture (puzzles/gumdrop_fluid.gd) under
## shaders/gumdrop_syrup_2d.gdshader.
##
## A mould's meshes are built in pixels, `u` of them a mould unit, with the
## mould's corner at the origin.

const Pal = preload("res://core/palette.gd")
const Face = preload("res://ui/faces/face.gd")
const Mould = preload("res://puzzles/gumdrop_mould.gd")
const Sim = preload("res://puzzles/gumdrop_sim.gd")

const INK := Color("3b3340")
const TABLE := Color("ecd3ab")
const TABLE_HI := Color("f4e2c2")
const TABLE_LOW := Color("dcbc8d")
const TABLE_LINE := Color("c9a473")
const TRAY := Color("474b5c")
const TRAY_HI := Color("636879")
const TRAY_LOW := Color("33363f")
## The clear jelly (2026-10-14, after the two screens of the game the first
## spec names, the user: "right now borders make it look weird, i wanted
## something that look more like a jelly"): a dark glossy gel, darker
## than the tray it stands on, its side (`GEL_SIDE`) lit along the upper
## left and no light outline anywhere. The tint lies on `GEL` and is
## drawn the card's colour at the card's shade.
const GEL := Color("1e1f28")
const GEL_SIDE := Color("2f313d")
const GEL_LIT := Color("8c90a4")
const GEL_SHADOW := Color("14151b")
const STEEL := Color("b9c2cc")
## How wide the seam between two chunks is drawn, in mould units: the
## dye's texels are 0.4 of one, and the groove hides where two tints meet.
const SEAM := 1.3
## The grey of the drain button, the one tool that takes tint out: no
## flavour's colour (the pots are coloured by index).
const DRAIN := Color("7b8496")
const DRAIN_HI := Color("a6aec0")
const DRAIN_LOW := Color("5d6577")
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

## A jelly's floor, under the tint: its soft shadow on the tray, its side
## (the clear rim, `Mould.RIM` out from the outline) lit along the upper
## left, and the dark gel itself, a little lighter toward its middle, as a
## dome is.
static func floor_of(m: Dictionary, u: float) -> ArrayMesh:
	var b := Face.Builder.new()
	var rim := _scaled(m.rim, u)
	b.polygon(_moved(rim, Vector2(1.6, 2.6) * u), Color(GEL_SHADOW, 0.28))
	b.polygon(_moved(rim, Vector2(0.7, 1.2) * u), Color(GEL_SHADOW, 0.35))
	b.polygon(rim, GEL_SIDE)
	var body := _scaled(m.outline, u)
	# the side's light: a stroke of the outline moved up and left, which the
	# gel then covers but for a crescent along the upper left
	b.stroke(_moved(body, Vector2(-0.55, -0.75) * u), 0.9 * u, Color(GEL_LIT, 0.55), true)
	b.polygon(body, GEL)
	for k in 3:
		for inner: PackedVector2Array in Geometry2D.offset_polygon(body, -(2.5 + 2.5 * k) * u, Geometry2D.JOIN_ROUND):
			if inner.size() >= 3:
				b.polygon(inner, Color(1, 1, 1, 0.035))
	return b.mesh()

## A jelly's skin, drawn over the tint: the groove where one chunk meets
## the next (no wall: the chunks touch, and the groove hides where two
## tints meet), the crisp edge where the tint ends at the gel's side, and
## the light lying on the gel.
static func gloss_of(m: Dictionary, u: float) -> ArrayMesh:
	var b := Face.Builder.new()
	var body := _scaled(m.outline, u)
	for line: PackedVector2Array in m.seams:
		if line.size() >= 2:
			b.stroke(_scaled(line, u), SEAM * u, Color(GEL, 0.9))
	for line: PackedVector2Array in m.seams:
		if line.size() >= 2:
			b.stroke(_moved(_scaled(line, u), Vector2(-0.35, -0.45) * u), SEAM * 0.3 * u, Color(GEL_LIT, 0.28))
	b.stroke(body, 0.8 * u, Color(GEL_SIDE, 0.95), true)
	# the light: a soft sheen along the upper left and a small glint by it
	var box := Rect2(body[0], Vector2.ZERO)
	for q in body:
		box = box.expand(q)
	for k in 9:
		var at := box.position + box.size * Vector2(0.24 + 0.07 * (k % 3), 0.2 + 0.09 * (k / 3))
		var r := clampf(minf(box.size.x, box.size.y) * 0.1, 3.0 * u, 8.0 * u)
		var fits := true
		for d: Vector2 in [Vector2(-1.6, 0), Vector2(1.6, 0), Vector2(0, -0.8), Vector2(0, 0.8)]:
			fits = fits and Geometry2D.is_point_in_polygon(at + d * r, body)
		if fits:
			b.ellipse(at, r * 1.7, r * 0.7, Color(1, 1, 1, 0.12))
			b.ellipse(at + Vector2(-r * 0.4, -r * 0.1), r * 0.6, r * 0.28, Color(1, 1, 1, 0.3))
			b.ellipse(at + Vector2(r * 1.5, r * 0.55), r * 0.22, r * 0.13, Color(1, 1, 1, 0.22))
			break
	return b.mesh()

## The card's picture: the jelly as it is wanted, every part its flavour,
## the one underneath first, with the gummy finish the day viewer gives it
## (2026-10-21, the user: "i loved the gumdrop with the gummy finish look,
## would love if we could add the same view to the ingame"): a soft shadow
## under it, a darker rim inside its outline, a sheen along the upper left
## and a glint by it, lit from the upper left as the tray is. Only the
## picture has it: the tint and the gel keep their own light. Still, and
## all in the one mesh.
static func picture(m: Dictionary, u: float) -> ArrayMesh:
	var b := Face.Builder.new()
	var body := _scaled(m.outline, u)
	b.polygon(_moved(body, Vector2(1.5, 2.5) * u), Color(0.35, 0.23, 0.16, 0.25))
	b.polygon(_scaled(m.rim, u), Color("fffdf8"))
	var want: Array = m.want
	for c in m.cells.size():
		b.polygon(_scaled(m.cells[c], u), FLAVOURS[int(want[c])])
	# the dark rim: the band between the outline and its inner offset, twice,
	# as a closed stroke down the band's middle as wide as the band
	for d: Array in [[1.2, 0.18], [2.4, 0.1]]:
		for mid: PackedVector2Array in Geometry2D.offset_polygon(body, -float(d[0]) * 0.5 * u, Geometry2D.JOIN_ROUND):
			if mid.size() >= 3:
				b.stroke(mid, float(d[0]) * u, Color(0.23, 0.1, 0.19, float(d[1])), true)
	# the sheen: a stroke of the outline moved down and right, kept where it
	# lies inside the jelly, which is along the upper left (a move up and
	# left, as the gel's side light has, would keep the lower right here,
	# the band being clipped to the inside rather than covered)
	var lit := _moved(body, Vector2(0.9, 1.2) * u)
	var half := 0.7 * u
	var n := lit.size()
	var edge := PackedVector2Array()
	edge.resize(n * 2)
	for i in n:
		var t := (lit[(i + 1) % n] - lit[(i - 1 + n) % n]).normalized()
		var nrm := Vector2(-t.y, t.x)
		edge[i * 2] = lit[i] - nrm * half
		edge[i * 2 + 1] = lit[i] + nrm * half
	var soft := b.feather
	b.feather = 0.0
	for i in n:
		var j := (i + 1) % n
		var quad := PackedVector2Array([edge[i * 2], edge[j * 2], edge[j * 2 + 1], edge[i * 2 + 1]])
		for piece: PackedVector2Array in Geometry2D.intersect_polygons(quad, body):
			if piece.size() >= 3:
				b.polygon(piece, Color(1, 1, 1, 0.28))
	b.feather = soft
	# the glint, placed as the gel's is (gloss_of)
	var box := Rect2(body[0], Vector2.ZERO)
	for q in body:
		box = box.expand(q)
	for k in 9:
		var at := box.position + box.size * Vector2(0.24 + 0.07 * (k % 3), 0.2 + 0.09 * (k / 3))
		var r := clampf(minf(box.size.x, box.size.y) * 0.1, 3.0 * u, 8.0 * u)
		var fits := true
		for dir: Vector2 in [Vector2(-1.6, 0), Vector2(1.6, 0), Vector2(0, -0.8), Vector2(0, 0.8)]:
			fits = fits and Geometry2D.is_point_in_polygon(at + dir * r, body)
		if fits:
			b.ellipse(at + Vector2(-r * 0.4, -r * 0.1), r * 0.6, r * 0.28, Color(1, 1, 1, 0.35))
			b.ellipse(at + Vector2(r * 1.5, r * 0.55), r * 0.22, r * 0.13, Color(1, 1, 1, 0.55))
			break
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

## The needle with a flavour in it: its point at the origin, standing
## straight up from there, `length` pixels long. A steel needle, a hub, a
## glass barrel with the tint in it and the barrel's two wings; the
## plunger is its own mesh (`plunger`).
static func needle(flavour: int, length: float) -> ArrayMesh:
	return _made("needle/%d/%.0f" % [flavour, length], func(b: Face.Builder) -> void:
		var w := length * 0.15
		var pin := length * 0.26
		var top := length * 0.74
		var col: Color = FLAVOURS[flavour]
		var barrel := Face.Builder.round_rect(Vector2(-w * 0.5, -top), Vector2(w, top - pin - 8.0), 7.0)
		b.polygon(_moved(barrel, Vector2(5.0, 6.0)), Color(0, 0, 0, 0.16))
		# the steel, to a point
		b.polygon(PackedVector2Array([Vector2(0, 0), Vector2(2.6, -10.0), Vector2(2.6, -pin - 2.0), Vector2(-2.6, -pin - 2.0), Vector2(-2.6, -10.0)]), STEEL)
		b.stroke(PackedVector2Array([Vector2(-0.8, -8.0), Vector2(-0.8, -pin)]), 1.6, Color(1, 1, 1, 0.7))
		b.fan(Face.Builder.round_rect(Vector2(-w * 0.2, -pin - 10.0), Vector2(w * 0.4, 12.0), 3.0), GLASS_LINE)
		b.polygon(barrel, Color(GLASS, 0.9))
		# the tint in it
		b.fan(Face.Builder.round_rect(Vector2(-w * 0.36, -top * 0.9), Vector2(w * 0.72, top * 0.9 - pin - 12.0), 5.0), col)
		b.stroke(barrel, 3.0, GLASS_LINE, true)
		for k in 3:
			var y := -pin - 22.0 - (top - pin - 44.0) * k / 3.0
			b.stroke(PackedVector2Array([Vector2(w * 0.5, y), Vector2(w * 0.18, y)]), 2.0, Color(GLASS_LINE, 0.9))
		b.stroke(PackedVector2Array([Vector2(-w * 0.26, -pin - 18.0), Vector2(-w * 0.26, -top * 0.94)]), w * 0.11, Color(1, 1, 1, 0.6))
		b.fan(Face.Builder.round_rect(Vector2(-w * 1.05, -top - 5.0), Vector2(w * 2.1, 11.0), 5.0), GLASS_LINE))

## The needle's plunger, the barrel's top at the origin: a rod and the
## pad a thumb presses. The transform sinks it as it is squeezed.
static func plunger(length: float) -> ArrayMesh:
	return _made("plunger/%.0f" % length, func(b: Face.Builder) -> void:
		var w := length * 0.15
		var rod := length * 0.2
		b.fan(Face.Builder.round_rect(Vector2(-w * 0.16 + 5.0, -rod + 6.0), Vector2(w * 0.32, rod + 4.0), 3.0), Color(0, 0, 0, 0.14))
		b.fan(Face.Builder.round_rect(Vector2(-w * 0.16, -rod), Vector2(w * 0.32, rod + 4.0), 3.0), BULB_LOW)
		b.fan(Face.Builder.round_rect(Vector2(-w * 0.8, -rod - 12.0), Vector2(w * 1.6, 16.0), 8.0), BULB_LOW)
		b.fan(Face.Builder.round_rect(Vector2(-w * 0.8, -rod - 14.0), Vector2(w * 1.6, 13.0), 6.5), BULB)
		b.fan(Face.Builder.round_rect(Vector2(-w * 0.6, -rod - 12.0), Vector2(w * 0.7, 4.0), 2.0), Color(BULB_HI, 0.9)))

## The squeeze button: the plunger's pad seen from above, a drop on it.
static func squeeze_button(r: float) -> ArrayMesh:
	return _made("squeeze/%.0f" % r, func(b: Face.Builder) -> void:
		b.disc(Vector2(0, 0.09 * r), r, Color(0.25, 0.14, 0.06, 0.25))
		b.disc(Vector2.ZERO, r, Color("fffdf8"))
		b.disc(Vector2.ZERO, 0.9 * r, BULB_LOW)
		b.disc(Vector2(0, -0.05 * r), 0.84 * r, BULB)
		b.ellipse(Vector2(-0.3, -0.48) * r, 0.34 * r, 0.14 * r, Color(BULB_HI, 0.8))
		_drop(b, Vector2(0, 0.04 * r), 0.36 * r, Color("fffdf8")))

static func _drop(b: Face.Builder, c: Vector2, r: float, col: Color) -> void:
	b.polygon(_drop_points(c, r), col)

static func _drop_points(c: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array([c + Vector2(0, -r * 1.25)])
	pts.append_array(Face.Builder.arc_points(c + Vector2(0, r * 0.2), r * 0.78, -PI * 0.2, PI * 1.2))
	return pts

## The drain button: a round of grey with a hollow drop on it, the one
## tool that takes tint out (2026-10-14).
static func drain_button(r: float) -> ArrayMesh:
	return _made("drain/%.0f" % r, func(b: Face.Builder) -> void:
		b.disc(Vector2(0, 0.1 * r), r, Color(0.25, 0.14, 0.06, 0.25))
		b.disc(Vector2.ZERO, r, Color("fffdf8"))
		b.disc(Vector2.ZERO, 0.9 * r, DRAIN_LOW)
		b.disc(Vector2(0, -0.05 * r), 0.84 * r, DRAIN)
		b.ellipse(Vector2(-0.3, -0.48) * r, 0.34 * r, 0.14 * r, Color(DRAIN_HI, 0.8))
		b.stroke(_drop_points(Vector2(0, 0.04 * r), 0.36 * r), 0.09 * r, Color("fffdf8"), true)
		# the arrow out of it
		b.stroke(PackedVector2Array([Vector2(0, 0.22 * r), Vector2(0, -0.2 * r)]), 0.08 * r, Color("fffdf8"))
		b.stroke(PackedVector2Array([Vector2(-0.13 * r, -0.07 * r), Vector2(0, -0.22 * r), Vector2(0.13 * r, -0.07 * r)]), 0.08 * r, Color("fffdf8")))

## The meter's slack: a reading up to this far over full is still the
## card's shade to the eye (the strength's curve flattens there) and the
## number stays white.
const METER_SLACK := 0.08
## The meter on the squeeze button (puzzles/gumdrop_table.gd): the chunk's
## syrup as shares of the card's shade, laid clockwise from the top along
## the button's white rim, a segment a flavour poured in (`segments`,
## [flavour, share] in the order they went in, summing to `total`); past
## full a dark ring climbs outside the rim. Built each frame it is shown.
static func meter(r: float, segments: Array, total: float) -> ArrayMesh:
	var b := Face.Builder.new()
	var from := -PI * 0.5
	var shown := minf(total, 1.0)
	var rim := 0.95 * r
	var w := 0.1 * r
	for seg: Array in segments:
		var part: float = float(seg[1]) / maxf(total, 0.0001) * shown
		if part > 0.002:
			var to := from + TAU * part
			b.stroke(Face.Builder.arc_points(Vector2.ZERO, rim, from, to), w, FLAVOURS[int(seg[0])], false, false)
			from = to
	# the marks a quarter apart, over the segments
	for q in 4:
		var a := -PI * 0.5 + TAU * 0.25 * q
		var d := Vector2.from_angle(a)
		b.stroke(PackedVector2Array([d * (rim - w * 0.5), d * (rim + w * 0.5)]), 0.03 * r, Color(INK, 0.35 if q > 0 else 0.6))
	if total > 1.0 + METER_SLACK:
		var over := clampf((total - 1.0) / 0.6, 0.0, 1.0)
		b.stroke(Face.Builder.arc_points(Vector2.ZERO, r + 0.05 * r, -PI * 0.5, -PI * 0.5 + TAU * over), 0.08 * r, Color(INK, 0.7), false, true)
	return b.mesh()

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
