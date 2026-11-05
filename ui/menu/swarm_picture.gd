extends RefCounted

## What the swarm's draw tool shows (ui/menu/swarm_tab.gd `apply_draw`): a
## picture from any of four places, turned into an Image, then into the
## pixels the dots fly to.
##
##   name  "bank:<id>"   one of Pixel Garden's hand-drawn pictures
##                       (content/pixel_garden.json), by id, e.g. bank:strawberry
##         "today[:<side>]"  the night's themed picture (ThemedPictures) of
##                       that band side (10, 12, 24, 32; 24 when left out);
##                       only what the phone already holds, never the network
##   rows + palette      a grid the agent wrote: one string a row, one char a
##                       pixel, "." or " " bare; palette maps each other char
##                       to "#rrggbb" or a bead name (Pal.PG_BEADS)
##   png                 a small picture, base64 (from the bot server)
##
## Every source ends as one Image, so they all fit, colour and sort the same.

const Pal = preload("res://core/palette.gd")
const ThemedPictures = preload("res://core/themed_pictures.gd")
const Daily = preload("res://core/daily.gd")
const BANK := "res://content/pixel_garden.json"
## A grid the agent writes, or a png it sends, is kept at most this many
## pixels a side before it is fitted to the dots.
const SIDE_MOST := 96
## Additive dots on a dark room cannot show black: a pixel darker than
## EMPTY_LUM is left bare, and any other is lifted to at least LUM_FLOOR.
const EMPTY_LUM := 0.05
const LUM_FLOOR := 0.3

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
			if not cols.has(ch):
				return {"error": "%s is in the rows but not in the palette" % ch}
			img.set_pixel(x, y, cols[ch])
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

## The pixels a picture shows with at most `most` dots: shrunk (keeping its
## squares) until it fits, then listed with their place in pixels from the
## picture's centre and their colour, lifted to show on the dark. Sorted so
## the nearest dot of a sorted swarm flies to it: rows in bands of about
## sqrt(n), left to right in each (the swarm sorts its dots the same way).
static func pixels(source: Image, most: int) -> Dictionary:
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
	pts.sort_custom(func(a, b): return a[1] < b[1] or (a[1] == b[1] and a[0] < b[0]))
	pts = band_sorted(pts, func(p): return p[0])
	# Built in locals: a packed array read out of a dictionary is a copy.
	var xs := PackedFloat32Array()
	var ys := PackedFloat32Array()
	var cs := PackedColorArray()
	for p in pts:
		xs.append(p[0] + 0.5 - w * 0.5)
		ys.append(p[1] + 0.5 - h * 0.5)
		cs.append(p[2])
	return {"w": w, "h": h, "n": pts.size(), "x": xs, "y": ys, "c": cs}

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
			var lum := c.get_luminance()
			if lum < EMPTY_LUM:
				continue
			if lum < LUM_FLOOR:
				var lift := LUM_FLOOR / lum
				c = Color(minf(1.0, c.r * lift), minf(1.0, c.g * lift), minf(1.0, c.b * lift))
			pts.append([x, y, Color(c, 1.0)])
	return pts
