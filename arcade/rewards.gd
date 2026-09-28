extends Control

## The loud rewards Firefly and Molehill share: a layer laid over the whole
## screen that owns the bits flung about (sparks, stars, coins, confetti,
## clods, shards, hearts, motes and rings), the stickers (words lettered a
## hopping letter at a time, over a turning sunburst when they are loud) and
## the rain that falls after a big moment. The kit is the one Stackwood,
## Lucky Thirteen and Posy each carry in their own screen, lifted here once
## so a screen only says *when* to celebrate.
##
## Everything is in this layer's own pixels; `at(c, p)` maps a point of any
## control into them. The screen steps it (`step`) from its own clock, so a
## pause stops it, and it draws itself as one mesh plus the stickers'
## letters. Under reduce motion the bits, rings and rain are never made and
## a sticker is lettered still.

const Motion = preload("res://core/motion.gd")
const Face = preload("res://ui/faces/face.gd")
const CozyTheme = preload("res://ui/theme.gd")

const STICKER_COLS := [Color("ff6f61"), Color("ffb03b"), Color("ffd84d"), Color("7fd66a"), Color("5cb8ff"), Color("b77be6")]
const CONFETTI := [Color("f7dc9c"), Color("ee8d6e"), Color("9391dc"), Color("5fc1ad"), Color("f2b632"), Color("f4a7a0")]
const GOLD := Color("f2c14e")
const GOLD_DEEP := Color("c98f22")
## The most bits alive at once.
const MAX_BITS := 480

## {pos, vel, rot, spin, t, life, kind, col, size, float?, to?}
var bits: Array = []
## {text, at, t, life, size, rainbow, col, rays, tilt, id, rise}
var stickers: Array = []
## Seconds of rain still falling, and what it is made of.
var _rain := 0.0
var _rain_kinds: Array = ["confetti"]
var _rain_cols: Array = CONFETTI
## Where stickers must stay inside, in this layer's pixels; empty = anywhere.
var bounds := Rect2()
var _clock := 0.0
var _mesh: ArrayMesh
var _ray_mesh: ArrayMesh
var _font: Font
## Sunbursts drawn added to what is under them rather than laid over it: on
## a night sky pale gold laid over navy reads as grey haze, added it glows.
var _rays: Control
## The sunburst's glow, outer rays and inner rays.
var _ray_cols := [Color(Color("fff4c2"), 0.35), Color(Color("ffe39a"), 0.34), Color(Color("fffaf0"), 0.24)]

func _init() -> void:
	name = "Rewards"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_font = CozyTheme.display(700)
	_rays = Control.new()
	_rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rays.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rays.show_behind_parent = true
	_rays.draw.connect(_draw_rays)
	add_child(_rays)

## Sunbursts glow (added) rather than lie over what is under them; for a
## dark ground.
func set_additive(on: bool) -> void:
	if on:
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_rays.material = m
		# added light stacks, so it is warm and faint to start with
		_ray_cols = [Color(Color("b87a1e"), 0.3), Color(Color("c98f22"), 0.32), Color(Color("8a6a3a"), 0.28)]
	else:
		_rays.material = null
		_ray_cols = [Color(Color("fff4c2"), 0.35), Color(Color("ffe39a"), 0.34), Color(Color("fffaf0"), 0.24)]

func clear() -> void:
	bits.clear()
	stickers.clear()
	_rain = 0.0
	queue_redraw()

## A point `p` of control `c`, in this layer's pixels.
func at(c: CanvasItem, p: Vector2) -> Vector2:
	return get_global_transform().affine_inverse() * (c.get_global_transform() * p)

func font() -> Font:
	return _font

# --- making ---

## Throws `n` bits of `kind` out of `from` at up to `speed` px/s. A bit may
## be sent home (`to`): it flies out, then is pulled in and dies on arrival.
func spray(from: Vector2, col: Color, n: int, speed: float, kind := "spark", size := 1.0, delay := 0.0, to := Vector2.INF) -> void:
	if Motion.reduce:
		return
	n = mini(n, MAX_BITS - bits.size())
	for i in n:
		var v := Vector2.from_angle(randf() * TAU) * speed * randf_range(0.35, 1.0) + Vector2(0, -speed * 0.4)
		var bit := {"pos": from, "vel": v, "rot": randf() * TAU, "spin": randf_range(-10.0, 10.0), "t": -delay - (0.03 * i if to != Vector2.INF else 0.0),
			"life": randf_range(0.55, 0.95) + (0.6 if kind in ["confetti", "coin", "heart", "note"] else 0.0), "kind": kind,
			"col": col, "size": size * randf_range(0.7, 1.25)}
		if to != Vector2.INF:
			bit.to = to
			bit.life = 1.6
		bits.append(bit)

## A ring swelling out of `from` to `radius` and thinning away.
func ring(from: Vector2, radius: float, col: Color, delay := 0.0, life := 0.45) -> void:
	if Motion.reduce:
		return
	bits.append({"pos": from, "vel": Vector2.ZERO, "rot": 0.0, "spin": 0.0, "t": -delay, "life": life, "kind": "ring",
		"col": col, "size": radius})

## Rain over the whole layer for `seconds`: `kinds` picked at random, in
## `cols`.
func rain(seconds: float, kinds: Array = ["confetti", "star"], cols: Array = CONFETTI) -> void:
	_rain = maxf(_rain, seconds)
	_rain_kinds = kinds
	_rain_cols = cols

## A word lettered at `where`, each letter hopping in on its own, fitted to
## `bounds`. `rainbow` letters it in the sticker colours, else in `col`;
## `rays` turns a sunburst behind it. A sticker with an `id` replaces the one
## before it with the same id; `rise` lifts it a little as it lives. Any
## other live sticker it would cover pushes it down, unless it is `keep`.
func sticker(text: String, where: Vector2, fs: int, life: float, rainbow := true, col := Color.WHITE, rays := false, id := "", rise := 0.0, keep := false) -> Dictionary:
	if id != "":
		stickers = stickers.filter(func(st: Dictionary) -> bool: return String(st.id) != id)
	var room := (bounds.size.x if bounds.has_area() else self.size.x) - 40.0
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	if w > room and w > 0.0:
		fs = int(fs * room / w)
		w = room
	if bounds.has_area():
		where.x = clampf(where.x, bounds.position.x + w * 0.5 + 20.0, bounds.end.x - w * 0.5 - 20.0)
		where.y = clampf(where.y, bounds.position.y + fs * 0.8, bounds.end.y - fs * 0.4)
	# make room: a sticker lands under any live one it would cover
	var h := fs * 1.05
	for pass_ in (0 if keep else 4):
		var moved := false
		for o: Dictionary in stickers:
			if float(o.t) > float(o.life) - 0.3:
				continue
			var ow := _font.get_string_size(o.text, HORIZONTAL_ALIGNMENT_LEFT, -1, o.size).x
			var oa: Vector2 = o.at
			var oh := float(o.size) * 1.05
			if absf(oa.x - where.x) < (ow + w) * 0.5 and absf(oa.y - where.y) < (oh + h) * 0.5:
				where.y = oa.y + (oh + h) * 0.5 + 6.0
				moved = true
		if not moved:
			break
	var st := {"text": text, "at": where, "t": 0.0, "life": life, "size": fs, "rainbow": rainbow, "col": col,
		"rays": rays and not Motion.reduce, "tilt": 0.0 if Motion.reduce else randf_range(-0.08, 0.08), "id": id,
		"rise": 0.0 if Motion.reduce else rise}
	stickers.append(st)
	return st

func has_sticker(id: String) -> bool:
	for st: Dictionary in stickers:
		if String(st.id) == id:
			return true
	return false

# --- the clock ---

func step(delta: float) -> void:
	_clock += delta
	if not bits.is_empty():
		var drag := exp(-delta * 2.2)
		for b: Dictionary in bits:
			b.t += delta
			if b.t < 0.0 or String(b.kind) == "ring":
				continue
			var v: Vector2 = b.vel
			if b.has("to"):
				# out along the throw, then pulled home ever harder
				var pull := clampf((b.t - 0.18) / 0.5, 0.0, 1.0)
				var home: Vector2 = b.to
				v = v * drag + (home - (b.pos as Vector2)) * 30.0 * pull * delta
				v = v.lerp((home - (b.pos as Vector2)) * 6.0, pull * pull * 0.5)
				b.pos += v * delta
				if pull > 0.3 and (b.pos as Vector2).distance_to(home) < 18.0:
					b.t = b.life
			elif b.get("float", false):
				v.y = minf(v.y + 120.0 * delta, 300.0)
				b.pos += Vector2(v.x + sin(b.t * 3.0 + b.rot) * 70.0, v.y) * delta
			else:
				v *= drag
				var fall := 1700.0
				match String(b.kind):
					"confetti", "heart":
						fall = 700.0
					"mote":
						fall = -120.0
					"note":
						fall = -420.0
						v.x += sin(b.t * 6.0 + b.rot) * 260.0 * delta
				v.y += fall * delta
				b.pos += v * delta
			b.vel = v
			b.rot += float(b.spin) * delta
		bits = bits.filter(func(b: Dictionary) -> bool: return b.t < b.life)
	for st: Dictionary in stickers:
		st.t += delta
	stickers = stickers.filter(func(st: Dictionary) -> bool: return st.t < st.life)
	if _rain > 0.0:
		_rain -= delta
		if not Motion.reduce and randf() < delta * 34.0 and bits.size() < MAX_BITS:
			bits.append({"pos": Vector2(randf_range(0.0, size.x), -40.0), "vel": Vector2(randf_range(-60.0, 60.0), randf_range(160.0, 300.0)),
				"rot": randf() * TAU, "spin": randf_range(-4.0, 4.0), "t": 0.0, "life": 4.2,
				"kind": _rain_kinds[randi() % _rain_kinds.size()], "col": _rain_cols[randi() % _rain_cols.size()],
				"size": randf_range(1.0, 1.5), "float": true})
	queue_redraw()

func busy() -> bool:
	return not bits.is_empty() or not stickers.is_empty() or _rain > 0.0

# --- drawing ---

func _draw() -> void:
	_rays.queue_redraw()
	var b := Face.Builder.new()
	_draw_bits(b)
	if not b.verts.is_empty():
		_mesh = b.mesh()
		draw_mesh(_mesh, null)
	_draw_stickers()

func _draw_rays() -> void:
	var b := Face.Builder.new()
	for st: Dictionary in stickers:
		if not st.rays:
			continue
		var grow := Motion.back_out(clampf(st.t / 0.35, 0.0, 1.0))
		var a := 1.0 - clampf((st.t - (st.life - 0.35)) / 0.35, 0.0, 1.0)
		var w := _font.get_string_size(st.text, HORIZONTAL_ALIGNMENT_LEFT, -1, st.size).x
		var r := maxf(w * 0.62, float(st.size) * 1.5) * grow
		var c := _sticker_at(st)
		var c0: Color = _ray_cols[0]
		var c1: Color = _ray_cols[1]
		var c2: Color = _ray_cols[2]
		b.disc(c, r * 0.6, Color(c0, c0.a * a))
		sunrays(b, c, r * 0.2, r, 16, _clock * 0.8, Color(c1, c1.a * a))
		sunrays(b, c, r * 0.2, r * 0.8, 16, -_clock * 0.5 + 0.1, Color(c2, c2.a * a))
	if not b.verts.is_empty():
		_ray_mesh = b.mesh()
		_rays.draw_mesh(_ray_mesh, null)

func _sticker_at(st: Dictionary) -> Vector2:
	return (st.at as Vector2) + Vector2(0, -float(st.rise) * minf(1.0, st.t / maxf(0.01, st.life)))

func _draw_bits(b: Face.Builder) -> void:
	for bit: Dictionary in bits:
		if bit.t < 0.0:
			continue
		var life: float = bit.life
		var a := clampf((life - bit.t) / (life * 0.35), 0.0, 1.0)
		if bit.has("to"):
			a = 1.0
		var col: Color = bit.col
		col.a *= a
		var p: Vector2 = bit.pos
		var sz: float = bit.size
		var rot: float = bit.rot
		match String(bit.kind):
			"confetti":
				petal(b, p, 11.0 * sz, 6.0 * sz * absf(cos(bit.t * 5.0 + rot)) + 1.0, rot, col)
			"star":
				star(b, p, 14.0 * sz * (0.6 + 0.4 * a), col, rot)
			"spark":
				glint(b, p, 22.0 * sz * a, rot, col)
			"coin":
				coin(b, p, 13.0 * sz, bit.t * 9.0 + rot, a)
			"heart":
				heart(b, p, 13.0 * sz, sin(rot) * 0.4, col)
			"clod":
				b.ellipse(p, 7.0 * sz, 5.5 * sz, col)
				b.ellipse(p + Vector2(-1.5, -1.8) * sz, 3.0 * sz, 2.0 * sz, Color(col.lightened(0.3), col.a))
			"shard":
				var d := Vector2.from_angle(rot)
				var n := d.orthogonal()
				b.polygon(PackedVector2Array([p - d * 10.0 * sz, p + n * 5.0 * sz, p + d * 9.0 * sz, p - n * 4.0 * sz]), col)
				b.stroke(PackedVector2Array([p - d * 10.0 * sz, p + n * 5.0 * sz]), 2.0 * sz, Color(col.lightened(0.3), col.a), false, false)
			"note":
				music_note(b, p, 16.0 * sz, sin(bit.t * 5.0 + rot) * 0.3, col)
			"mote":
				b.disc(p, 9.0 * sz * a, Color(col, col.a * 0.25))
				b.disc(p, 3.4 * sz, col)
			"ring":
				var k := clampf(bit.t / life, 0.0, 1.0)
				var r := sz * (0.3 + 0.7 * (1.0 - pow(1.0 - k, 3.0)))
				b.stroke(Face.Builder.ring(p, r, r), maxf(2.0, 14.0 * (1.0 - k)), Color(bit.col, (bit.col as Color).a * (1.0 - k)), true)

## Each letter hops in on its own, rocks for a moment, and the word swells
## away at the end; a pale rim and a dark one under the colour, so it reads
## over anything.
func _draw_stickers() -> void:
	for st: Dictionary in stickers:
		var text: String = st.text
		var fs: int = st.size
		var total := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var x := -total * 0.5
		var out_a := 1.0 - clampf((st.t - (st.life - 0.3)) / 0.3, 0.0, 1.0)
		var swell := 1.0 + 0.2 * (1.0 - out_a)
		var tilt: float = st.tilt
		var base := _sticker_at(st)
		for i in text.length():
			var ch := text[i]
			var adv := _font.get_char_size(ch.unicode_at(0), fs).x
			var k := clampf((st.t - i * 0.035) / 0.28, 0.0, 1.0)
			if k <= 0.0 and not Motion.reduce:
				x += adv
				continue
			var sc := 1.0 if Motion.reduce else Motion.back_out(k)
			var hop := 0.0 if Motion.reduce else -sin(st.t * 8.0 - i * 0.55) * fs * 0.09 * exp(-st.t * 1.4)
			var centre: Vector2 = base + (Vector2(x + adv * 0.5, hop) * swell).rotated(tilt)
			var rock := 0.0 if Motion.reduce else sin(st.t * 7.0 + i) * 0.08 * exp(-st.t * 1.2)
			draw_set_transform(centre, tilt + rock, Vector2(sc, sc) * swell)
			var o := Vector2(-adv * 0.5, fs * 0.36)
			var col: Color = STICKER_COLS[i % STICKER_COLS.size()] if st.rainbow else st.col
			draw_char_outline(_font, o + Vector2(0, fs * 0.09), ch, fs, int(fs * 0.34), Color(0.25, 0.15, 0.05, 0.35 * out_a))
			draw_char_outline(_font, o, ch, fs, int(fs * 0.3), Color(Color("fffaf0"), out_a))
			draw_char_outline(_font, o, ch, fs, int(fs * 0.13), Color(col.darkened(0.5), out_a))
			draw_char(_font, o, ch, fs, Color(col, out_a))
			x += adv
	draw_set_transform(Vector2.ZERO)

# --- shapes, laid into a builder ---

## A four-pointed glint: a spark.
static func glint(b: Face.Builder, c: Vector2, r: float, turn: float, col := Color(1, 1, 0.95, 0.95)) -> void:
	if r <= 0.5:
		return
	b.disc(c, r * 0.45, Color(col, col.a * 0.26))
	for k in 4:
		var d := Vector2.from_angle(TAU * k / 4.0 + turn)
		var side := d.orthogonal() * r * 0.13
		b.polygon(PackedVector2Array([c + side, c + d * r * (1.0 if k % 2 == 0 else 0.7), c - side]), col)
	b.disc(c, r * 0.14, Color(1, 1, 1, col.a))

## A five-pointed star with a darker drop and a shine.
static func star(b: Face.Builder, c: Vector2, r: float, col: Color, turn := 0.0) -> void:
	for pass_ in 2:
		var pts := PackedVector2Array()
		var from := c + (Vector2(r * 0.04, r * 0.1) if pass_ == 0 else Vector2.ZERO)
		var rr := r * (1.08 if pass_ == 0 else 1.0)
		for i in 10:
			var a := TAU * i / 10.0 - PI * 0.5 + turn
			pts.append(from + Vector2.from_angle(a) * (rr if i % 2 == 0 else rr * 0.52))
		b.polygon(pts, Color(col.darkened(0.35), col.a) if pass_ == 0 else col)
	b.ellipse(c + Vector2(-r * 0.18, -r * 0.2), r * 0.18, r * 0.11, Color(1, 1, 1, 0.5 * col.a))

## A sunburst: `n` rays between `r0` and `r1`.
static func sunrays(b: Face.Builder, c: Vector2, r0: float, r1: float, n: int, turn: float, col: Color) -> void:
	var half := PI / n * 0.5
	for i in n:
		var a := TAU * i / n + turn
		b.polygon(PackedVector2Array([c + Vector2.from_angle(a - half * 0.4) * r0, c + Vector2.from_angle(a - half) * r1,
			c + Vector2.from_angle(a + half) * r1, c + Vector2.from_angle(a + half * 0.4) * r0]), col)

## An ellipse turned by `rot`: a scrap of confetti.
static func petal(b: Face.Builder, c: Vector2, rx: float, ry: float, rot: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := TAU * i / 10.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot))
	b.fan(pts, col)

## A gold coin spinning about its upright axis (`spin`), its face narrowing
## to its rim and back.
static func coin(b: Face.Builder, c: Vector2, r: float, spin: float, a := 1.0) -> void:
	var w := absf(cos(spin))
	b.ellipse(c, maxf(r * 0.18, r * w), r, Color(GOLD_DEEP, a))
	b.ellipse(c + Vector2(-r * 0.06 * w, 0), maxf(r * 0.1, r * 0.82 * w), r * 0.82, Color(GOLD, a))
	if w > 0.4:
		b.ellipse(c + Vector2(-r * 0.3 * w, -r * 0.3), r * 0.16 * w, r * 0.26, Color(1, 1, 0.9, 0.7 * a))

## An eighth note, its head at `c`, tipped by `rot`: a music bit.
static func music_note(b: Face.Builder, c: Vector2, r: float, rot: float, col: Color) -> void:
	var t := Transform2D(rot, c)
	var dark := Color(col.darkened(0.45), col.a)
	var head := PackedVector2Array()
	for i in 12:
		var a := TAU * i / 12.0
		head.append(t * Vector2(cos(a) * r * 0.62, sin(a) * r * 0.46).rotated(-0.4))
	b.polygon(head, col)
	var top := Vector2(r * 0.5, -r * 1.9)
	b.stroke(PackedVector2Array([t * Vector2(r * 0.5, -r * 0.1), t * top]), r * 0.2, dark)
	b.polygon(PackedVector2Array([t * top, t * (top + Vector2(r * 0.75, r * 0.55)), t * (top + Vector2(r * 0.6, r * 0.8)), t * (top + Vector2(0, r * 0.45))]), dark)
	b.ellipse(t * Vector2(-r * 0.2, -r * 0.14), r * 0.18, r * 0.1, Color(1, 1, 1, 0.55 * col.a))

## A heart tipped by `rot`.
static func heart(b: Face.Builder, c: Vector2, r: float, rot: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 24:
		var t := TAU * i / 24.0
		var x := 16.0 * pow(sin(t), 3.0)
		var y := -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
		pts.append(c + (Vector2(x, y) * r / 16.0).rotated(rot))
	b.polygon(pts, col)
	b.ellipse(c + Vector2(-r * 0.4, -r * 0.35).rotated(rot), r * 0.2, r * 0.13, Color(1, 1, 1, 0.45 * col.a))

## A warm glow breathing in from the edges of `rect`, `amount` 0..1 strong.
static func edge_glow(b: Face.Builder, rect: Rect2, tint: Color, amount: float, beat: float) -> void:
	var s := rect.size
	var o := rect.position
	var edge := Color(tint, (0.25 + 0.2 * beat) * amount)
	var none := Color(tint, 0.0)
	var w := (70.0 + 40.0 * beat) * (0.6 + 0.4 * amount)
	_quad(b, [o, o + Vector2(s.x, 0), o + Vector2(s.x - w, w), o + Vector2(w, w)], [edge, edge, none, none])
	_quad(b, [o + Vector2(0, s.y), o + Vector2(w, s.y - w), o + Vector2(s.x - w, s.y - w), o + s], [edge, none, none, edge])
	_quad(b, [o, o + Vector2(w, w), o + Vector2(w, s.y - w), o + Vector2(0, s.y)], [edge, none, none, edge])
	_quad(b, [o + Vector2(s.x, 0), o + s, o + Vector2(s.x - w, s.y - w), o + Vector2(s.x - w, w)], [edge, edge, none, none])

static func _quad(b: Face.Builder, p: Array, c: Array) -> void:
	var i0 := b.vertex(p[0], c[0])
	var i1 := b.vertex(p[1], c[1])
	var i2 := b.vertex(p[2], c[2])
	var i3 := b.vertex(p[3], c[3])
	b.tri(i0, i1, i2)
	b.tri(i0, i2, i3)
