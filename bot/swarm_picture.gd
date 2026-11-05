extends RefCounted

## What the swarm's draw tool shows (bot/swarm_face.gd `apply_draw`): a
## picture from any of four places, turned into an Image, then into the
## pixels whose shape the dots crowd into. Only the shape and each pixel's
## brightness are kept: the dots stay the swarm's own, in its tone (the user,
## 2026-11-05: "Drawing should be done using the particles").
##
##   name  "bank:<id>"   one of Pixel Garden's hand-drawn pictures
##                       (content/pixel_garden.json), by id, e.g. bank:strawberry
##         "today[:<side>]"  the night's themed picture (ThemedPictures) of
##                       that band side (10, 12, 24, 32; 24 when left out);
##                       only what the phone already holds, never the network
##   rows [+ palette]    a grid the agent wrote: one string a row, one char a
##                       pixel, "." or " " bare; any other char is a pixel at
##                       full brightness unless the palette maps it to
##                       "#rrggbb" or a bead name (Pal.PG_BEADS), whose
##                       brightness it then takes (only the brightness: the
##                       dots keep the swarm's tone)
##   png                 a small picture, base64 (from the bot server)
##
## Every source ends as one Image, so they all fit, shade and sort the same.

const Pal = preload("res://core/palette.gd")
const ThemedPictures = preload("res://core/themed_pictures.gd")
const Daily = preload("res://core/daily.gd")
const BANK := "res://content/pixel_garden.json"
## A grid the agent writes, or a png it sends, is kept at most this many
## pixels a side before it is fitted to the dots.
const SIDE_MOST := 96
## A pixel darker than EMPTY_LUM is the dark around a picture: left bare.
const EMPTY_LUM := 0.05
## The dimmest pixel of a picture still glows this much of the brightest.
const DIMMEST := 0.2
## A border colour holding this share of a full picture's border is its
## ground (sky, grass, a table), taken away so the thing stands alone.
const GROUND_SHARE := 0.12
const GROUND_NEAR := 0.1
## How many dots a pixel draws, against its brightness: a pixel's weight is
## (FLOOR + its brightness) ^ CURVE, and an outline pixel's EDGE more, so
## bright parts and outlines crowd and dark ones thin (stippling: with one
## tone, the shading is in how many dots there are, not how bright they are).
const WEIGHT_FLOOR := 0.3
const WEIGHT_CURVE := 1.2
const WEIGHT_EDGE := 0.9

static var _bank := {}

## {image: Image, name: String} or {error: String}.
static func image_of(cmd: Dictionary) -> Dictionary:
	if cmd.has("png"):
		var raw := Marshalls.base64_to_raw(String(cmd.png))
		var img := Image.new()
		if raw.is_empty() or img.load_png_from_buffer(raw) != OK:
			return {"error": "png is not a picture"}
		return {"image": _capped(img), "name": "a picture"}
	if cmd.has("rows"):
		return _grid(cmd.rows, cmd.get("palette", {}), "a drawing")
	var name := String(cmd.get("name", "")).strip_edges().to_lower()
	if name.begins_with("bank:"):
		var pic: Dictionary = bank().get(name.substr(5), {})
		if pic.is_empty():
			return {"error": "no picture %s in the bank" % name.substr(5)}
		return _grid(pic.rows, _bank_palette(), name.substr(5).replace("_", " "))
	if name == "today" or name.begins_with("today:"):
		var side := int(name.substr(6)) if name.begins_with("today:") else 24
		var pic := ThemedPictures.picture(Daily.date_key(), side)
		if pic.is_empty():
			return {"error": "today's picture of side %d is not on this phone" % side}
		return _grid(pic.rows, _bank_palette(), String(pic.name))
	return {"error": "pass name (bank:<id> or today), rows with palette, or png"}

## Pixel Garden's pictures by id, every band.
static func bank() -> Dictionary:
	if _bank.is_empty():
		var doc = JSON.parse_string(FileAccess.get_file_as_string(BANK))
		if doc is Dictionary:
			for band in doc.get("bands", []):
				for pic in band:
					_bank[String(pic.id)] = pic
	return _bank

static func _bank_palette() -> Dictionary:
	return ThemedPictures.letters()

static func _grid(rows, palette, shown: String) -> Dictionary:
	if not rows is Array or rows.is_empty():
		return {"error": "rows must be a list of strings"}
	var h: int = rows.size()
	var w := 0
	for r in rows:
		w = maxi(w, String(r).length())
	if w == 0 or w > SIDE_MOST or h > SIDE_MOST:
		return {"error": "a drawing is 1 to %d pixels a side" % SIDE_MOST}
	var cols := {}
	if palette is Dictionary:
		for k in palette:
			var c = _colour(String(palette[k]))
			if c == null:
				return {"error": "palette %s: %s is not a colour" % [k, palette[k]]}
			cols[String(k)] = c
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in h:
		var r := String(rows[y])
		for x in r.length():
			var ch := r[x]
			if ch == "." or ch == " ":
				continue
			img.set_pixel(x, y, cols.get(ch, Color.WHITE))
	return {"image": img, "name": shown}

static func _colour(s: String):
	if Pal.PG_BEADS.has(s):
		return Pal.PG_BEADS[s]
	var hex := s.trim_prefix("#")
	if hex.length() in [6, 8] and hex.is_valid_hex_number():
		return Color.html(hex)
	return null

static func _capped(img: Image) -> Image:
	img.convert(Image.FORMAT_RGBA8)
	var big := maxi(img.get_width(), img.get_height())
	if big > SIDE_MOST:
		var f := float(SIDE_MOST) / big
		# A photo shrinks smoothly; pixel art would blur, so it keeps its squares.
		img.resize(maxi(1, int(img.get_width() * f)), maxi(1, int(img.get_height() * f)), Image.INTERPOLATE_BILINEAR)
	return img

## The pixels of a picture, at most `most`: shrunk (keeping its squares)
## until it fits, then listed with their place in pixels from the picture's
## centre and their brightness, spread from DIMMEST for its darkest to 1 for
## its brightest, so its outlines and features show in one tone.
static func pixels(picture: Image, most: int) -> Dictionary:
	var source := _without_ground(picture)
	var img := source
	var pts := _opaque(img)
	var tries := 0
	while pts.size() > most and tries < 12:
		var f := sqrt(float(most) / pts.size()) * 0.97
		img = source.duplicate()
		img.resize(maxi(1, int(source.get_width() * f * pow(0.95, tries))), maxi(1, int(source.get_height() * f * pow(0.95, tries))), Image.INTERPOLATE_NEAREST)
		pts = _opaque(img)
		tries += 1
	if pts.size() > most:
		pts.resize(most)
	var w := img.get_width()
	var h := img.get_height()
	var lo := 1.0
	var hi := 0.0
	for p in pts:
		lo = minf(lo, p[2])
		hi = maxf(hi, p[2])
	# Built in locals: a packed array read out of a dictionary is a copy.
	var xs := PackedFloat32Array()
	var ys := PackedFloat32Array()
	var ls := PackedFloat32Array()
	var ws := PackedFloat32Array()
	for p in pts:
		var x: int = p[0]
		var y: int = p[1]
		xs.append(x + 0.5 - w * 0.5)
		ys.append(y + 0.5 - h * 0.5)
		var t: float = 1.0 if hi - lo < 0.05 else (float(p[2]) - lo) / (hi - lo)
		ls.append(DIMMEST + (1.0 - DIMMEST) * t)
		var edge := false
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q: Vector2i = Vector2i(x, y) + d
			if q.x < 0 or q.y < 0 or q.x >= w or q.y >= h or not _lit(img.get_pixel(q.x, q.y)):
				edge = true
				break
		ws.append(pow(WEIGHT_FLOOR + t, WEIGHT_CURVE) + (WEIGHT_EDGE if edge else 0.0))
	return {"w": w, "h": h, "n": pts.size(), "x": xs, "y": ys, "l": ls, "wt": ws}

static func _lit(c: Color) -> bool:
	return c.a >= 0.5 and c.get_luminance() >= EMPTY_LUM

## A full picture (no bare pixel: a scene, a photo) loses its ground: each
## colour that holds GROUND_SHARE of the border is flooded away from the
## border inward, so only the thing in it is left. A picture with bare
## pixels is a thing already and is kept whole (a drawing that touches its
## own edges must not lose them).
static func _without_ground(picture: Image) -> Image:
	var img := picture.duplicate() as Image
	var w := img.get_width()
	var h := img.get_height()
	for y in h:
		for x in w:
			if not _lit(img.get_pixel(x, y)):
				return img
	var border: Array[Vector2i] = []
	for x in w:
		border.append(Vector2i(x, 0))
		border.append(Vector2i(x, h - 1))
	for y in range(1, h - 1):
		border.append(Vector2i(0, y))
		border.append(Vector2i(w - 1, y))
	var grounds: Array[Color] = []
	for b in border:
		var c := img.get_pixel(b.x, b.y)
		var known := false
		for g in grounds:
			if _near(g, c):
				known = true
		if known:
			continue
		var count := 0
		for o in border:
			if _near(img.get_pixel(o.x, o.y), c):
				count += 1
		if count >= GROUND_SHARE * border.size():
			grounds.append(c)
	var bare := Color(0, 0, 0, 0)
	for g in grounds:
		var todo: Array[Vector2i] = []
		for b in border:
			if _near(img.get_pixel(b.x, b.y), g):
				todo.append(b)
		while not todo.is_empty():
			var p: Vector2i = todo.pop_back()
			var c := img.get_pixel(p.x, p.y)
			if c.a < 0.5 or not _near(c, g):
				continue
			img.set_pixelv(p, bare)
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q: Vector2i = p + d
				if q.x >= 0 and q.y >= 0 and q.x < w and q.y < h:
					todo.append(q)
	return img

static func _near(a: Color, b: Color) -> bool:
	return a.a >= 0.5 and b.a >= 0.5 and absf(a.r - b.r) <= GROUND_NEAR and absf(a.g - b.g) <= GROUND_NEAR and absf(a.b - b.b) <= GROUND_NEAR

## A list already sorted top to bottom, cut into bands of about sqrt(n) and
## each band sorted left to right by `key`.
static func band_sorted(items: Array, key: Callable) -> Array:
	var n := items.size()
	if n == 0:
		return items
	var per := maxi(1, int(ceil(float(n) / maxf(1.0, round(sqrt(n))))))
	var out := []
	var at := 0
	while at < n:
		var band := items.slice(at, mini(n, at + per))
		band.sort_custom(func(a, b): return key.call(a) < key.call(b))
		out.append_array(band)
		at += per
	return out

static func _opaque(img: Image) -> Array:
	var pts := []
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a < 0.5:
				continue
			if not _lit(c):
				continue
			pts.append([x, y, c.get_luminance()])
	return pts
