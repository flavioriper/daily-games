extends RefCounted

## Furrow's field, drawn as builder shapes and shared by the game
## (arcade/furrow_field.gd), its tray, its tutorial pages and its card on
## the Arcade tab. Everything is built in pixels and cached per look and
## size; the field moves, sways and squashes a plant by its draw transform
## and never rebuilds one to do it.
##
## The field is seen from a corner (the last section of this file): lots of
## turned earth with roads between them, a house, a barn and a mill behind.
## A plant stands with the soil line at the origin and grows up from it
## (`plant`, in the sim's four stages: a mound, a sprout, the young plant,
## ripe). What is picked is `produce`: the crop alone, its middle at the
## origin, the same drawing the tray's packets wear.

const Pal = preload("res://core/palette.gd")
const Face = preload("res://ui/faces/face.gd")
const Rewards = preload("res://arcade/rewards.gd")
const Sim = preload("res://arcade/furrow_sim.gd")

const INK := Color("4a3a2a")
const GRASS := Color("9ccb6f")
const GRASS_HI := Color("b4da84")
const GRASS_DEEP := Color("7fb257")
const SOIL := Color("a8754a")
const SOIL_HI := Color("c08e5e")
const SOIL_DEEP := Color("8a5c38")
const SOIL_DARK := Color("74492b")
const WOOD := Color("c79a66")
const WOOD_HI := Color("e0b988")
const WOOD_DEEP := Color("9c7248")
const LEAF := Color("6fae4a")
const LEAF_HI := Color("93c95f")
const LEAF_DEEP := Color("4f8a38")
const STEM := Color("7fb257")
const CREAM := Color("fffaf0")
const GOLD := Color("f2c14e")
const SEED := Color("e8c98a")
const SEED_DEEP := Color("b98d4f")
## Each crop's own colour, its light and its deep.
const TONE := [Color("e2557a"), Color("f08a34"), Color("a5d86a"), Color("e5503f"), Color("f4cf4a"), Color("ee8a2e"), Color("f6c63a"), Color("5fa858")]
const TONE_HI := [Color("f28aa4"), Color("f8ad62"), Color("c9ec96"), Color("f3806f"), Color("fbe58c"), Color("f7ab5b"), Color("fbdf7e"), Color("86c97c")]
const TONE_DEEP := [Color("b83a5c"), Color("cf6a1c"), Color("7fba4a"), Color("bb382b"), Color("d9aa24"), Color("c96a18"), Color("d99f1c"), Color("3f8040")]

static var _cache := {}

static func _made(key: String, build: Callable) -> ArrayMesh:
	if _cache.has(key):
		return _cache[key]
	if _cache.size() > 240:
		_cache.clear()
	var b := Face.Builder.new()
	build.call(b)
	var m := b.mesh()
	_cache[key] = m
	return m

# --- the ground ---

static func _tuft(b: Face.Builder, at: Vector2, s: float, col: Color) -> void:
	for d in [-0.5, 0.0, 0.5]:
		b.stroke(PackedVector2Array([at, at + Vector2(d * s, -s * (1.0 - absf(d) * 0.4))]), maxf(2.0, s * 0.2), col)

static func _daisy(b: Face.Builder, at: Vector2, r: float, col: Color) -> void:
	for i in 5:
		b.disc(at + Vector2.from_angle(TAU * i / 5.0) * r * 0.7, r * 0.55, col)
	b.disc(at, r * 0.45, GOLD)

## A bed of turned earth `size` pixels, its middle at the origin: a lip, the
## earth, and three furrows across it.
static func bed(size: Vector2) -> ArrayMesh:
	return _made("bed%.0f/%.0f" % [size.x, size.y], func(b: Face.Builder) -> void:
		var r := minf(size.x, size.y) * 0.2
		var at := -size * 0.5
		b.fan(Face.Builder.round_rect(at + Vector2(0, 7.0), size, r), Color(SOIL_DARK, 0.55))
		b.fan(Face.Builder.round_rect(at, size, r), SOIL_DEEP)
		b.fan(Face.Builder.round_rect(at + Vector2(5, 4), size - Vector2(10, 12), r * 0.86), SOIL)
		for i in 3:
			var y := at.y + size.y * (0.26 + 0.24 * i)
			b.stroke(PackedVector2Array([Vector2(at.x + size.x * 0.14, y), Vector2(at.x + size.x * 0.86, y)]), size.y * 0.075, SOIL_DEEP)
			b.stroke(PackedVector2Array([Vector2(at.x + size.x * 0.16, y - size.y * 0.045), Vector2(at.x + size.x * 0.84, y - size.y * 0.045)]), size.y * 0.03, Color(SOIL_HI, 0.8)))

## The signboard on the next plot to open, `w` pixels wide, its foot at the
## origin: the price is lettered on it by the field.
static func signboard(w: float) -> ArrayMesh:
	return _made("sign%.0f" % w, func(b: Face.Builder) -> void:
		var h := w * 0.5
		b.fan(Face.Builder.round_rect(Vector2(-w * 0.05, -h * 0.4), Vector2(w * 0.1, h * 0.5), w * 0.03), WOOD_DEEP)
		b.fan(Face.Builder.round_rect(Vector2(-w * 0.5, -h * 1.3 + 5.0), Vector2(w, h), h * 0.24), Color(SOIL_DARK, 0.4))
		b.fan(Face.Builder.round_rect(Vector2(-w * 0.5, -h * 1.3), Vector2(w, h), h * 0.24), WOOD_DEEP)
		b.fan(Face.Builder.round_rect(Vector2(-w * 0.5 + 4.0, -h * 1.3 + 4.0), Vector2(w - 8.0, h - 10.0), h * 0.2), CREAM))

## A seed, the game's own coin, `tall` pixels, its middle at the origin.
static func seed_icon(tall: float) -> ArrayMesh:
	return _made("seed%.1f" % tall, func(b: Face.Builder) -> void: seed_into(b, Vector2.ZERO, tall))

static func seed_into(b: Face.Builder, c: Vector2, tall: float, turn := 0.3) -> void:
	var h := tall * 0.5
	var up := Vector2.UP.rotated(turn)
	var side := up.orthogonal()
	_lens(b, c - up * h + Vector2(0, tall * 0.06), c + up * h + Vector2(0, tall * 0.06), h * 0.7, Color(SEED_DEEP, 0.9))
	_lens(b, c - up * h, c + up * h, h * 0.66, SEED)
	b.stroke(PackedVector2Array([c - up * h * 0.5, c + up * h * 0.5]), maxf(1.5, tall * 0.07), SEED_DEEP)
	b.ellipse(c + side * h * 0.28 + up * h * 0.2, h * 0.12, h * 0.24, Color(CREAM, 0.7))

# --- shapes ---

## A leaf from `from` to `to`, `w` wide at its middle.
static func _lens(b: Face.Builder, from: Vector2, to: Vector2, w: float, col: Color) -> void:
	var mid := (from + to) * 0.5
	var n := (to - from).orthogonal().normalized() * w
	var pts := Face.Builder.bezier2(from, mid + n, to, 8)
	pts.append_array(Face.Builder.bezier2(to, mid - n, from, 8))
	b.fan(pts, col)

static func _leaf(b: Face.Builder, from: Vector2, to: Vector2, w: float, col := LEAF, vein := LEAF_DEEP) -> void:
	_lens(b, from, to, w, col)
	b.stroke(PackedVector2Array([from, from.lerp(to, 0.8)]), maxf(1.2, w * 0.14), Color(vein, 0.7))

static func _ball(b: Face.Builder, c: Vector2, r: float, crop: int) -> void:
	b.disc(c + Vector2(0, r * 0.08), r, TONE_DEEP[crop])
	b.disc(c, r * 0.94, TONE[crop])
	b.ellipse(c + Vector2(-r * 0.3, -r * 0.34), r * 0.3, r * 0.2, Color(TONE_HI[crop], 0.9))

## The earth heaped where a plant stands.
static func _mound(b: Face.Builder, s: float, wide := 0.4) -> void:
	b.ellipse(Vector2(0, s * 0.06), s * wide, s * 0.13, SOIL_DEEP)
	b.ellipse(Vector2(0, s * 0.03), s * wide * 0.86, s * 0.09, SOIL_HI)

# --- the plants ---

## Crop `crop` at `stage` (0 a mound, 1 a sprout, 2 young, 3 ripe), `s`
## pixels half a bed wide, the soil line at the origin.
static func plant(crop: int, stage: int, s: float) -> ArrayMesh:
	return _made("plant%d/%d/%.1f" % [crop, stage, s], func(b: Face.Builder) -> void:
		b.ellipse(Vector2(0, s * 0.1), s * (0.3 + 0.12 * stage), s * 0.12, Color(SOIL_DARK, 0.35))
		if stage == 0:
			_mound(b, s, 0.3)
			seed_into(b, Vector2(0, -s * 0.04), s * 0.2, 1.2)
		elif stage == 1:
			b.stroke(Face.Builder.bezier2(Vector2.ZERO, Vector2(s * 0.04, -s * 0.18), Vector2(0, -s * 0.34), 6), s * 0.06, STEM)
			_leaf(b, Vector2(0, -s * 0.3), Vector2(-s * 0.26, -s * 0.5), s * 0.11, LEAF_HI)
			_leaf(b, Vector2(0, -s * 0.3), Vector2(s * 0.26, -s * 0.52), s * 0.11, LEAF_HI)
			_mound(b, s, 0.24)
		else:
			_grown(b, crop, s, stage >= 3))

static func _grown(b: Face.Builder, crop: int, s: float, ripe: bool) -> void:
	var g := 1.0 if ripe else 0.68
	match String(Sim.CROPS[crop].id):
		"radish":
			for a in [-0.6, 0.0, 0.6]:
				_leaf(b, Vector2(0, -s * 0.16), Vector2(sin(a) * s * 0.5, -s * (0.25 + 0.6 * cos(a))) * g, s * 0.17 * g)
			if ripe:
				_ball(b, Vector2(0, -s * 0.14), s * 0.3, crop)
			_mound(b, s, 0.42 if ripe else 0.3)
		"carrot":
			for a in [-0.8, -0.4, 0.0, 0.4, 0.8]:
				var tip := Vector2(sin(a) * s * 0.6, -s * (0.2 + 0.72 * cos(a))) * g
				b.stroke(Face.Builder.bezier2(Vector2(0, -s * 0.08), Vector2(tip.x * 0.2, tip.y * 0.7), tip, 7), s * 0.07, LEAF_DEEP)
				for k in [0.45, 0.7, 0.95]:
					var p := Vector2(0, -s * 0.08).lerp(tip, k)
					b.ellipse(p, s * 0.09 * g, s * 0.07 * g, LEAF if absf(a) > 0.2 else LEAF_HI)
			if ripe:
				b.ellipse(Vector2(0, -s * 0.07), s * 0.21, s * 0.16, TONE_DEEP[crop])
				b.ellipse(Vector2(0, -s * 0.1), s * 0.18, s * 0.12, TONE[crop])
			_mound(b, s, 0.38 if ripe else 0.28)
		"lettuce":
			_head(b, crop, Vector2(0, -s * 0.24 * g), s * 0.5 * g)
		"tomato":
			b.stroke(PackedVector2Array([Vector2(s * 0.34, 0), Vector2(s * 0.34, -s * 1.05 * g)]), s * 0.06, WOOD)
			for row: Array in [[-0.24, -0.34, 0.36], [0.22, -0.4, 0.38], [0.0, -0.74, 0.36], [-0.2, -0.98, 0.24], [0.18, -1.0, 0.22]]:
				b.disc(Vector2(row[0], row[1]) * s * g, float(row[2]) * s * g, LEAF_DEEP if float(row[1]) > -0.5 else LEAF)
			b.ellipse(Vector2(-0.1, -0.86) * s * g, s * 0.2 * g, s * 0.12 * g, Color(LEAF_HI, 0.7))
			for row: Array in [[-0.3, -0.36], [0.26, -0.5], [-0.06, -0.72], [0.14, -0.2]]:
				if ripe:
					_ball(b, Vector2(row[0], row[1]) * s, s * 0.15, crop)
				else:
					b.disc(Vector2(row[0], row[1]) * s * g, s * 0.07, LEAF_HI)
			_mound(b, s, 0.3)
		"corn":
			var top := -s * 1.5 * g
			b.stroke(PackedVector2Array([Vector2.ZERO, Vector2(0, top)]), s * 0.09, LEAF_DEEP)
			for row: Array in [[-1.0, 0.25, 0.5], [1.0, 0.4, 0.62], [-1.0, 0.6, 0.86], [1.0, 0.74, 0.96]]:
				var from := Vector2(0, top * float(row[1]))
				_leaf(b, from, from + Vector2(float(row[0]) * s * 0.62 * g, top * (float(row[2]) - float(row[1])) * 0.7 + s * 0.1), s * 0.13 * g)
			for d in [-0.12, 0.0, 0.12]:
				b.stroke(PackedVector2Array([Vector2(0, top), Vector2(d * s, top - s * 0.16 * g)]), s * 0.035, SEED)
			if ripe:
				_cob(b, crop, Vector2(s * 0.14, top * 0.5), s * 0.3, 0.18)
			_mound(b, s, 0.28)
		"pumpkin":
			_leaf(b, Vector2(-s * 0.1, -s * 0.05), Vector2(-s * 0.74, -s * 0.4) * g, s * 0.26 * g)
			_leaf(b, Vector2(s * 0.1, -s * 0.05), Vector2(s * 0.76, -s * 0.34) * g, s * 0.26 * g, LEAF_HI)
			b.stroke(Face.Builder.bezier2(Vector2(s * 0.3, -s * 0.1), Vector2(s * 0.7, -s * 0.7 * g), Vector2(s * 0.5, -s * 0.8 * g), 8), s * 0.04, LEAF_DEEP)
			if ripe:
				_gourd(b, crop, Vector2(0, -s * 0.34), s * 0.52)
			else:
				b.ellipse(Vector2(0, -s * 0.14), s * 0.2, s * 0.16, LEAF_HI)
				b.ellipse(Vector2(0, -s * 0.14), s * 0.08, s * 0.15, LEAF)
		"sunflower":
			var top := -s * 1.3 * g
			b.stroke(Face.Builder.bezier2(Vector2.ZERO, Vector2(s * 0.08, top * 0.5), Vector2(0, top), 8), s * 0.09, LEAF_DEEP)
			_leaf(b, Vector2(0, top * 0.36), Vector2(-s * 0.5 * g, top * 0.56), s * 0.17 * g)
			_leaf(b, Vector2(0, top * 0.52), Vector2(s * 0.5 * g, top * 0.74), s * 0.17 * g, LEAF_HI)
			if ripe:
				_bloom(b, crop, Vector2(0, top), s * 0.46)
			else:
				b.disc(Vector2(0, top), s * 0.16, LEAF)
				b.disc(Vector2(0, top), s * 0.09, TONE[crop])
			_mound(b, s, 0.26)
		_:
			_leaf(b, Vector2(-s * 0.1, -s * 0.05), Vector2(-s * 0.78, -s * 0.3) * g, s * 0.22 * g, LEAF_HI)
			_leaf(b, Vector2(s * 0.1, -s * 0.05), Vector2(s * 0.74, -s * 0.44) * g, s * 0.24 * g)
			b.stroke(Face.Builder.bezier2(Vector2(-s * 0.3, -s * 0.1), Vector2(-s * 0.7, -s * 0.74 * g), Vector2(-s * 0.46, -s * 0.84 * g), 8), s * 0.04, LEAF_DEEP)
			if ripe:
				_melon(b, crop, Vector2(0, -s * 0.34), s * 0.56)
			else:
				b.ellipse(Vector2(0, -s * 0.14), s * 0.22, s * 0.16, TONE_HI[crop])

static func _head(b: Face.Builder, crop: int, c: Vector2, r: float) -> void:
	for i in 6:
		var a := TAU * i / 6.0 + 0.3
		b.disc(c + Vector2(cos(a), sin(a) * 0.6) * r * 0.56, r * 0.52, TONE_DEEP[crop] if i % 2 == 0 else TONE[crop])
	for i in 4:
		var a := TAU * i / 4.0
		b.disc(c + Vector2(cos(a), sin(a) * 0.6) * r * 0.24 - Vector2(0, r * 0.1), r * 0.4, TONE[crop] if i % 2 == 0 else TONE_HI[crop])
	b.disc(c - Vector2(0, r * 0.14), r * 0.26, TONE_HI[crop])
	b.ellipse(c - Vector2(r * 0.06, r * 0.2), r * 0.1, r * 0.07, Color(CREAM, 0.7))

static func _cob(b: Face.Builder, crop: int, c: Vector2, r: float, turn: float) -> void:
	var up := Vector2.UP.rotated(turn)
	_lens(b, c - up * r * 1.05 + Vector2(0, r * 0.08), c + up * r * 1.1 + Vector2(0, r * 0.08), r * 0.9, TONE_DEEP[crop])
	_lens(b, c - up * r * 1.05, c + up * r * 1.1, r * 0.84, TONE[crop])
	for k in [-0.5, -0.1, 0.3, 0.7]:
		b.ellipse(c + up * r * float(k) + up.orthogonal() * r * 0.1, r * 0.2, r * 0.12, Color(TONE_HI[crop], 0.85))
	_leaf(b, c - up * r * 1.1, c + up * r * 0.5 - up.orthogonal() * r * 0.56, r * 0.4, LEAF_HI)
	_leaf(b, c - up * r * 1.1, c + up * r * 0.3 + up.orthogonal() * r * 0.6, r * 0.4, LEAF)

static func _gourd(b: Face.Builder, crop: int, c: Vector2, r: float) -> void:
	b.ellipse(c + Vector2(0, r * 0.08), r, r * 0.76, TONE_DEEP[crop])
	for d in [-0.56, 0.56]:
		b.ellipse(c + Vector2(d * r, 0), r * 0.44, r * 0.66, TONE_DEEP[crop].lerp(TONE[crop], 0.5))
	b.ellipse(c, r * 0.66, r * 0.72, TONE[crop])
	b.ellipse(c, r * 0.3, r * 0.7, TONE_HI[crop].lerp(TONE[crop], 0.4))
	b.ellipse(c + Vector2(-r * 0.4, -r * 0.36), r * 0.16, r * 0.1, Color(CREAM, 0.6))
	b.stroke(Face.Builder.bezier2(c + Vector2(0, -r * 0.68), c + Vector2(r * 0.04, -r * 0.96), c + Vector2(r * 0.2, -r * 0.98), 6), r * 0.16, LEAF_DEEP)

static func _bloom(b: Face.Builder, crop: int, c: Vector2, r: float) -> void:
	for i in 14:
		var a := TAU * i / 14.0
		Rewards.petal(b, c + Vector2.from_angle(a) * r * 0.66, r * 0.4, r * 0.17, a, TONE_DEEP[crop] if i % 2 == 0 else TONE[crop])
	for i in 14:
		var a := TAU * (i + 0.5) / 14.0
		Rewards.petal(b, c + Vector2.from_angle(a) * r * 0.56, r * 0.32, r * 0.14, a, TONE_HI[crop])
	b.disc(c, r * 0.46, Color("7a4f2a"))
	b.disc(c, r * 0.36, Color("96643a"))
	for i in 7:
		b.disc(c + Vector2.from_angle(TAU * i / 7.0) * r * 0.2, r * 0.05, Color("5c3a1e"))

static func _melon(b: Face.Builder, crop: int, c: Vector2, r: float) -> void:
	b.ellipse(c + Vector2(0, r * 0.08), r, r * 0.74, TONE_DEEP[crop])
	b.ellipse(c, r * 0.96, r * 0.7, TONE[crop])
	for d in [-0.62, -0.22, 0.22, 0.62]:
		var x := c.x + float(d) * r
		var h := r * 0.66 * sqrt(1.0 - float(d) * float(d) * 0.9)
		b.stroke(Face.Builder.bezier2(Vector2(x, c.y - h), Vector2(x + float(d) * r * 0.3, c.y), Vector2(x, c.y + h), 8), r * 0.1, TONE_DEEP[crop])
	b.ellipse(c + Vector2(-r * 0.36, -r * 0.34), r * 0.2, r * 0.1, Color(CREAM, 0.5))

## What is picked: crop `crop` alone, about `r` pixels from its middle at
## the origin.
static func produce(crop: int, r: float) -> ArrayMesh:
	return _made("produce%d/%.1f" % [crop, r], func(b: Face.Builder) -> void: produce_into(b, crop, Vector2.ZERO, r))

static func produce_into(b: Face.Builder, crop: int, c: Vector2, r: float) -> void:
	match String(Sim.CROPS[crop].id):
		"radish":
			for a in [-0.5, 0.0, 0.5]:
				_leaf(b, c + Vector2(0, -r * 0.2), c + Vector2(sin(a) * r * 0.6, -r * (0.3 + 0.7 * cos(a))), r * 0.2)
			b.stroke(Face.Builder.bezier2(c + Vector2(0, r * 0.6), c + Vector2(r * 0.06, r * 0.86), c + Vector2(-r * 0.08, r * 1.0), 6), r * 0.07, TONE_DEEP[crop])
			_ball(b, c + Vector2(0, r * 0.22), r * 0.56, crop)
		"carrot":
			for a in [-0.5, 0.0, 0.5]:
				_leaf(b, c + Vector2(0, -r * 0.4), c + Vector2(sin(a) * r * 0.56, -r * (0.4 + 0.6 * cos(a))), r * 0.16, LEAF if a != 0.0 else LEAF_HI)
			var body := PackedVector2Array([c + Vector2(-r * 0.4, -r * 0.4), c + Vector2(r * 0.4, -r * 0.4), c + Vector2(r * 0.12, r * 0.86), c + Vector2(0, r * 1.0), c + Vector2(-r * 0.12, r * 0.86)])
			b.fan(body, TONE_DEEP[crop])
			b.fan(PackedVector2Array([c + Vector2(-r * 0.34, -r * 0.42), c + Vector2(r * 0.26, -r * 0.42), c + Vector2(r * 0.04, r * 0.8), c + Vector2(-r * 0.1, r * 0.8)]), TONE[crop])
			b.ellipse(c + Vector2(0, -r * 0.4), r * 0.4, r * 0.12, TONE[crop])
			for k in [-0.1, 0.2, 0.5]:
				b.stroke(PackedVector2Array([c + Vector2(-r * 0.2, r * float(k)), c + Vector2(-r * 0.02, r * (float(k) + 0.03))]), r * 0.05, TONE_DEEP[crop])
		"lettuce":
			_head(b, crop, c + Vector2(0, r * 0.1), r * 0.96)
		"tomato":
			_ball(b, c + Vector2(0, r * 0.06), r * 0.86, crop)
			for i in 5:
				var a := TAU * i / 5.0 - PI * 0.5
				_lens(b, c + Vector2(0, -r * 0.66), c + Vector2(0, -r * 0.66) + Vector2(cos(a), sin(a) * 0.6) * r * 0.42, r * 0.1, LEAF_DEEP)
		"corn":
			_cob(b, crop, c + Vector2(0, r * 0.06), r * 0.78, 0.3)
		"pumpkin":
			_gourd(b, crop, c + Vector2(0, r * 0.14), r * 0.94)
		"sunflower":
			_bloom(b, crop, c, r * 0.96)
		_:
			_melon(b, crop, c, r * 0.98)

## A packet of crop `crop` for the tray, `side` pixels square with its
## middle at the origin: paper, the crop on it, a fold at its top.
static func packet(crop: int, side: float) -> ArrayMesh:
	return _made("packet%d/%.0f" % [crop, side], func(b: Face.Builder) -> void:
		var at := Vector2(-side * 0.5, -side * 0.5)
		b.fan(Face.Builder.round_rect(at + Vector2(0, 5.0), Vector2(side, side), side * 0.2), Color(INK, 0.22))
		b.fan(Face.Builder.round_rect(at, Vector2(side, side), side * 0.2), CREAM)
		b.fan(Face.Builder.round_rect(at + Vector2(5, 5), Vector2(side - 10.0, side - 10.0), side * 0.16), TONE_HI[crop].lerp(CREAM, 0.55))
		produce_into(b, crop, Vector2(0, side * 0.03), side * 0.33))

# --- the land, seen from a corner ---
#
# Since the user's picture of 2026-10-11 ("this is what i was thinking": a
# farm seen from a corner, whole fields of one crop with dirt roads between
# them, a house, a barn and a mill) the field is isometric. A plot is a
# lot: a diamond of turned earth `a` pixels from its middle to its side
# corner and `a * RATIO` to its near one, planted with ROWS by ROWS of its
# crop. The lots lie three and two a row, each row half a lot nearer, so
# the earth left between them reads as roads.

## How tall a lot is to how wide: a little steeper than two to one, so the
## land fills a phone held upright.
const RATIO := 0.56
const ROWS := 3
const EARTH := Color("dcb884")
const EARTH_DEEP := Color("c39d69")
const WALL := Color("f6ead2")
const WALL_SHADE := Color("dccdb0")
const ROOF := Color("d9634f")
const ROOF_DEEP := Color("b34a3a")
const BARN := Color("c8553f")
const BARN_DEEP := Color("a23f30")
const HAY := Color("ecc55a")
const HAY_DEEP := Color("cfa23c")

static func diamond(c: Vector2, a: float, k := 1.0) -> PackedVector2Array:
	return PackedVector2Array([c + Vector2(0, -a * RATIO * k), c + Vector2(a * k, 0), c + Vector2(0, a * RATIO * k), c + Vector2(-a * k, 0)])

## A point of a lot: `u` along its right-hand edge and `v` along its left,
## both 0 to 1 from the far corner.
static func on_lot(a: float, u: float, v: float) -> Vector2:
	return Vector2(0, -a * RATIO) + Vector2(a, a * RATIO) * u + Vector2(-a, a * RATIO) * v

static func _earth(b: Face.Builder, a: float) -> void:
	var t := a * 0.1
	var d := diamond(Vector2.ZERO, a)
	# the bed stands a hand above the road: its two near sides
	b.fan(PackedVector2Array([d[3], d[2], d[2] + Vector2(0, t), d[3] + Vector2(0, t)]), SOIL_DARK)
	b.fan(PackedVector2Array([d[2], d[1], d[1] + Vector2(0, t), d[2] + Vector2(0, t)]), SOIL_DEEP.darkened(0.12))
	b.fan(d, SOIL_DEEP)
	b.fan(diamond(Vector2(0, -a * 0.012), a, 0.94), SOIL)
	for i in ROWS + 1:
		var v := float(i) / ROWS
		b.stroke(PackedVector2Array([on_lot(a, 0.06, lerpf(0.06, 0.94, v)), on_lot(a, 0.94, lerpf(0.06, 0.94, v))]), a * 0.03, Color(SOIL_DEEP, 0.8))

## A lot's turned earth, its middle at the origin.
static func earth(a: float) -> ArrayMesh:
	return _made("earth%.0f" % a, func(b: Face.Builder) -> void: _earth(b, a))

## Where plant `i`, `j` of a lot stands from the lot's middle.
static func row_at(a: float, i: int, j: int) -> Vector2:
	return on_lot(a, (i + 0.5) / ROWS, (j + 0.5) / ROWS) + Vector2(0, a * 0.02)

## A lot's ROWS by ROWS plants of crop `crop` at `stage`, the far ones
## first, the lot's middle at the origin.
static func rows(crop: int, stage: int, a: float) -> ArrayMesh:
	return _made("rows%d/%d/%.0f" % [crop, stage, a], func(b: Face.Builder) -> void:
		for sum in ROWS * 2 - 1:
			for i in ROWS:
				var j := sum - i
				if j >= 0 and j < ROWS:
					b.append(plant(crop, stage, a * 0.25), Transform2D(0.0, row_at(a, i, j))))

## A lot not opened yet: longer grass pegged out with string.
static func lot_empty(a: float) -> ArrayMesh:
	return _made("lot_empty%.0f" % a, func(b: Face.Builder) -> void:
		b.fan(diamond(Vector2.ZERO, a, 0.96), Color(GRASS_HI, 0.75))
		var d := diamond(Vector2.ZERO, a, 0.86)
		for e in 4:
			for k in 6:
				b.stroke(PackedVector2Array([d[e].lerp(d[(e + 1) % 4], (k + 0.15) / 6.0), d[e].lerp(d[(e + 1) % 4], (k + 0.6) / 6.0)]), maxf(2.0, a * 0.022), Color(CREAM, 0.8))
		for at: Vector2 in [Vector2(-0.3, 0.05), Vector2(0.24, -0.1), Vector2(0.02, 0.22), Vector2(-0.05, -0.2)]:
			_tuft(b, at * a, a * 0.08, GRASS_DEEP))

## The whole screen's ground, `size` pixels: mown grass, the earth the lots
## at `centres` stand on, `a` from one to the next (a lot is drawn narrower,
## so what shows between them is road), a house, a
## barn and a mill's tower on the line `back` behind them, each `u` pixels
## a unit, trees and hay where the rows leave room. `mill` is where the
## mill stands: the field turns its sails there (`sails`).
static func land(size: Vector2, centres: Array, a: float, back: float, u: float, mill: Vector2) -> ArrayMesh:
	var b := Face.Builder.new()
	b.fan(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)]), GRASS)
	var band := size.y / 14.0
	for i in 14:
		if i % 2 == 0:
			b.fan(PackedVector2Array([Vector2(0, i * band), Vector2(size.x, i * band), Vector2(size.x, (i + 1) * band), Vector2(0, (i + 1) * band)]), Color(GRASS_HI, 0.28))
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for c: Vector2 in centres:
		lo = lo.min(c - Vector2(a, a * RATIO))
		hi = hi.max(c + Vector2(a, a * RATIO))
	var keep := Rect2(lo, hi - lo).grow(a * 0.2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4177
	for i in 120:
		var at := Vector2(rng.randf() * size.x, rng.randf() * size.y)
		if keep.has_point(at) or (at.y < back and at.y > back - 170.0 * u):
			continue
		var k := rng.randf()
		if k < 0.75:
			_tuft(b, at, 9.0 + rng.randf() * 8.0, GRASS_DEEP if rng.randf() < 0.6 else GRASS_HI)
		else:
			_daisy(b, at, 6.0 + rng.randf() * 3.0, CREAM if rng.randf() < 0.6 else Color("f6c7d3"))
	# the yard behind the lots and the road down to them
	if u > 0.0:
		b.ellipse(Vector2(size.x * 0.5, back - 12.0 * u), size.x * 0.46, 46.0 * u, EARTH_DEEP)
		b.ellipse(Vector2(size.x * 0.5, back - 16.0 * u), size.x * 0.45, 42.0 * u, EARTH)
	for c: Vector2 in centres:
		b.fan(diamond(c + Vector2(0, a * 0.07), a, 1.08), EARTH_DEEP)
	for c: Vector2 in centres:
		b.fan(diamond(c + Vector2(0, a * 0.02), a, 1.06), EARTH)
	if u > 0.0:
		_tree(b, Vector2(size.x * 0.045, back - 30.0 * u), u * 1.1)
		_house(b, Vector2(size.x * 0.22, back - 22.0 * u), u, WALL, WALL_SHADE, ROOF, ROOF_DEEP, false)
		_tree(b, Vector2(size.x * 0.4, back - 44.0 * u), u * 0.9)
		_house(b, Vector2(size.x * 0.56, back - 24.0 * u), u * 1.08, BARN, BARN_DEEP, Color("8f7a66"), Color("75624f"), true)
		_hay(b, Vector2(size.x * 0.7, back - 2.0 * u), u)
		_mill(b, mill, u)
		_tree(b, Vector2(size.x * 0.955, back - 26.0 * u), u)
	# where a row of two leaves the land's side free
	for c: Vector2 in centres:
		for side in [-1.0, 1.0]:
			var at: Vector2 = c + Vector2(side * a * 2.0, 0)
			var free := at.x > a * 0.2 and at.x < size.x - a * 0.2
			for o: Vector2 in centres:
				if o.distance_to(at) < a * 0.5:
					free = false
			if free and absf(at.x - size.x * 0.5) > a * 2.0:
				var tu := a / 170.0
				if int(c.y) % 2 == 0:
					_tree(b, at + Vector2(side * a * 0.1, a * 0.1), tu)
				else:
					_hay(b, at + Vector2(-side * a * 0.2, a * 0.1), tu)
					_tree(b, at + Vector2(side * a * 0.36, -a * 0.1), tu * 0.8)
	return b.mesh()

static func _tree(b: Face.Builder, at: Vector2, u: float) -> void:
	b.ellipse(at + Vector2(0, 4.0 * u), 34.0 * u, 12.0 * u, Color(SOIL_DARK, 0.25))
	b.fan(Face.Builder.round_rect(at + Vector2(-7.0 * u, -40.0 * u), Vector2(14.0 * u, 44.0 * u), 6.0 * u), WOOD_DEEP)
	b.disc(at + Vector2(0, -62.0 * u), 36.0 * u, LEAF_DEEP)
	b.disc(at + Vector2(-20.0 * u, -48.0 * u), 24.0 * u, LEAF_DEEP)
	b.disc(at + Vector2(20.0 * u, -50.0 * u), 24.0 * u, LEAF_DEEP)
	b.disc(at + Vector2(-4.0 * u, -68.0 * u), 30.0 * u, LEAF)
	b.disc(at + Vector2(-12.0 * u, -76.0 * u), 15.0 * u, LEAF_HI)

static func _hay(b: Face.Builder, at: Vector2, u: float) -> void:
	b.ellipse(at + Vector2(0, 4.0 * u), 30.0 * u, 10.0 * u, Color(SOIL_DARK, 0.25))
	b.fan(Face.Builder.round_rect(at + Vector2(-26.0 * u, -34.0 * u), Vector2(52.0 * u, 38.0 * u), 16.0 * u), HAY_DEEP)
	b.fan(Face.Builder.round_rect(at + Vector2(-24.0 * u, -36.0 * u), Vector2(46.0 * u, 34.0 * u), 15.0 * u), HAY)
	for k in 3:
		b.stroke(PackedVector2Array([at + Vector2(-14.0 * u + 12.0 * u * k, -30.0 * u), at + Vector2(-16.0 * u + 12.0 * u * k, -8.0 * u)]), 2.5 * u, Color(HAY_DEEP, 0.8))

## A house seen from its corner, its near corner's foot at `at`: two walls
## and a hipped roof; a barn has a wide door with a cross on it.
static func _house(b: Face.Builder, at: Vector2, u: float, wall: Color, shade: Color, roof: Color, roof_deep: Color, barn: bool) -> void:
	var w := 62.0 * u
	var h := 58.0 * u
	var up := Vector2(0, -h)
	var left := at + Vector2(-w, -w * RATIO)
	var right := at + Vector2(w, -w * RATIO)
	b.ellipse(at + Vector2(0, -w * RATIO * 0.6), w * 1.2, w * 0.5, Color(SOIL_DARK, 0.22))
	b.fan(PackedVector2Array([left, at, at + up, left + up]), wall)
	b.fan(PackedVector2Array([at, right, right + up, at + up]), shade)
	var top := at + up + Vector2(0, -w * RATIO - 46.0 * u)
	var eave := Vector2(0, 6.0 * u)
	b.fan(PackedVector2Array([left + up + eave + Vector2(-8.0 * u, 0), at + up + eave + Vector2(0, 6.0 * u), top]), roof)
	b.fan(PackedVector2Array([at + up + eave + Vector2(0, 6.0 * u), right + up + eave + Vector2(8.0 * u, 0), top]), roof_deep)
	# on the lit wall a door, on the other a window: each leans as its wall does
	var along := (left - at) / w
	var door_w := 26.0 * u if barn else 15.0 * u
	var door_h := 40.0 * u if barn else 32.0 * u
	var d0 := at + along * (w * 0.5 - door_w * 0.5)
	var d1 := at + along * (w * 0.5 + door_w * 0.5)
	b.fan(PackedVector2Array([d1, d0, d0 + Vector2(0, -door_h), d1 + Vector2(0, -door_h)]), CREAM if barn else WOOD_DEEP)
	if barn:
		b.stroke(PackedVector2Array([d1, d0 + Vector2(0, -door_h)]), 3.0 * u, BARN_DEEP)
		b.stroke(PackedVector2Array([d0, d1 + Vector2(0, -door_h)]), 3.0 * u, BARN_DEEP)
	var side := (right - at) / w
	var w0 := at + side * w * 0.34 + Vector2(0, -h * 0.4)
	var w1 := at + side * w * 0.66 + Vector2(0, -h * 0.4)
	b.fan(PackedVector2Array([w0, w1, w1 + Vector2(0, -18.0 * u), w0 + Vector2(0, -18.0 * u)]), Color("fbe7a8") if not barn else CREAM)

## The mill's tower and cap, its foot at `at`; the sails turn on the hub
## `mill_hub` above it.
static func _mill(b: Face.Builder, at: Vector2, u: float) -> void:
	b.ellipse(at + Vector2(0, 2.0 * u), 46.0 * u, 16.0 * u, Color(SOIL_DARK, 0.25))
	b.fan(PackedVector2Array([at + Vector2(-36.0 * u, 0), at + Vector2(0, 8.0 * u), at + Vector2(0, -128.0 * u), at + Vector2(-22.0 * u, -124.0 * u)]), WALL)
	b.fan(PackedVector2Array([at + Vector2(0, 8.0 * u), at + Vector2(36.0 * u, 0), at + Vector2(22.0 * u, -124.0 * u), at + Vector2(0, -128.0 * u)]), WALL_SHADE)
	b.fan(PackedVector2Array([at + Vector2(-28.0 * u, -122.0 * u), at + Vector2(0, -116.0 * u), at + Vector2(0, -164.0 * u)]), ROOF)
	b.fan(PackedVector2Array([at + Vector2(0, -116.0 * u), at + Vector2(28.0 * u, -122.0 * u), at + Vector2(0, -164.0 * u)]), ROOF_DEEP)
	b.fan(Face.Builder.round_rect(at + Vector2(-24.0 * u, -34.0 * u), Vector2(16.0 * u, 36.0 * u), 7.0 * u), WOOD_DEEP)
	b.fan(Face.Builder.round_rect(at + Vector2(-18.0 * u, -84.0 * u), Vector2(12.0 * u, 16.0 * u), 5.0 * u), Color("fbe7a8"))

static func mill_hub(at: Vector2, u: float) -> Vector2:
	return at + Vector2(0, -112.0 * u)

## The mill's four sails about the origin.
static func sails(u: float) -> ArrayMesh:
	return _made("sails%.2f" % u, func(b: Face.Builder) -> void:
		for k in 4:
			var d := Vector2.from_angle(TAU * k / 4.0)
			var n := d.orthogonal()
			b.stroke(PackedVector2Array([Vector2.ZERO, d * 84.0 * u]), 5.0 * u, WOOD_DEEP)
			b.fan(PackedVector2Array([d * 26.0 * u, d * 84.0 * u, d * 84.0 * u + n * 20.0 * u, d * 26.0 * u + n * 20.0 * u]), Color(CREAM, 0.95))
			for j in 4:
				var q := d * (34.0 + 14.0 * j) * u
				b.stroke(PackedVector2Array([q, q + n * 20.0 * u]), 2.0 * u, WOOD)
			b.stroke(PackedVector2Array([d * 26.0 * u + n * 20.0 * u, d * 84.0 * u + n * 20.0 * u]), 2.5 * u, WOOD)
		b.disc(Vector2.ZERO, 9.0 * u, WOOD_DEEP)
		b.disc(Vector2.ZERO, 5.0 * u, WOOD_HI))
