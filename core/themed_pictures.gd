class_name ThemedPictures
extends RefCounted

## The day's themed bead pictures, as a phone reads them
## (docs/superpowers/specs/2026-10-13-daily-theme-design.md). The night's
## process publishes one picture a band -- a thing from the theme, drawn as
## shaded pixel art on a bare board (server/functions/src/pictures.ts) --
## keyed by the band's side (10, 12, 24, 32, 48 for Button Box's Insane on
## builds before 2026-10-27, and 128 for Jewel Box's Insane since, sewn a
## quarter at a time), and Pixel Garden and Button Box deal it
## in place of their bank's for that band (Button Box's Hard asks for the
## 32).
##
## Since 2026-10-14 a picture is kept at the squares it was drawn at, never
## redrawn to the band's side: its rows are a square of any side within the
## band's range (RULES.side), and the boards lay whatever side they are
## handed (Pixel Garden by rows.size(), the other two by w and h).
##
## Yarn Hoop's low-poly pictures ride in the same document, a band each (`hoops`, since
## 2026-10-16): pins and panels read off a drawing on the night
## (server/functions/src/hoop.ts), laid here as they are.
## How Big?'s things of the day ride there too (`things`).
##
## Only what this phone already holds is read (Backend.cached_day): no board
## waits on the network for a picture. world/main.gd asks for the day behind
## the menu at boot. With no document, an unstarted backend (the suite, every
## harness, tools/export_days.gd), a board dealt from New, or a picture that
## does not keep the rules below, the answer is {} and the bank deals.

const Backend = preload("res://core/backend.gd")
const GAME := "pictures"
const BANK := "res://content/pixel_garden.json"
## tools/beads.js RULES, as the server ran them, by the band's side: the
## side the rows may be, colours, the fill of the picture's own square, the
## largest colour's share of its beads (Button Box's `lead`), and an edge
## left bare. The fill is FILL unless a band names its own (the 128's,
## at least half its square). The two tables change together.
const RULES := {
	10: {"side": [10, 18], "colours": [3, 7]},
	12: {"side": [12, 22], "colours": [4, 7]},
	24: {"side": [24, 34], "colours": [6, 12]},
	32: {"side": [32, 40], "colours": [8, 14]},
	48: {"side": [44, 64], "colours": [10, 16]},
	# 64 to 84 since 2026-11-03 (half the jewels of the 96 to 144 it was): a
	# build before it holds the old range, so it turns the night's smaller
	# picture down and plays the night's 48 in quarters until updated.
	128: {"side": [64, 84], "colours": [12, 16], "fill": [0.5, 0.9]},
}
const FILL := [0.25, 0.80]
const LEAD := 0.6

static var _letters := {}

## The bank's palette letters: a themed picture is written in the same ones.
static func letters() -> Dictionary:
	if _letters.is_empty():
		var doc = JSON.parse_string(FileAccess.get_file_as_string(BANK))
		if doc is Dictionary and doc.get("palette") is Dictionary:
			_letters = doc.palette
	return _letters

## The picture of `size` squares for the daily of `date_key`, in the bank's
## shape ({id, name, rows}; `name` is already in the player's language, and
## tr() hands a string it has no row for straight back), or {}.
static func picture(date_key: int, size: int) -> Dictionary:
	if date_key == 0 or not Backend.started():
		return {}
	var doc: Dictionary = Backend.cached_day(GAME, date_key)
	var sizes = doc.get("sizes")
	if int(doc.get("v", 0)) != 1 or not sizes is Dictionary:
		return {}
	var pic = sizes.get(str(size))
	if not pic is Dictionary or not valid(pic.get("rows"), size):
		return {}
	var id := String(pic.get("id", ""))
	var shown := id.replace("_", " ")
	var names = pic.get("name")
	if names is Dictionary:
		var lang := TranslationServer.get_locale().substr(0, 2)
		shown = String(names.get(lang, names.get("en", shown)))
	shown = shown.strip_edges()
	return {"id": "themed_" + id, "name": shown.left(1).to_upper() + shown.substr(1), "rows": pic.rows}

## The things of the night's pictures for the daily of `date_key`, smallest
## band first, each once: {en, pt, es} names as the night wrote them, and
## `g` ({pt, es}: "m", "f", "mp" or "fp") when the theme said the pt/es
## names' gender (since 2026-11-06; Who Ate the Pie? puts an article
## before them). The scene's picture is not a thing and is left out.
const GENDERS := ["m", "f", "mp", "fp"]
static func names(date_key: int) -> Array:
	var out: Array = []
	if date_key == 0 or not Backend.started():
		return out
	var doc: Dictionary = Backend.cached_day(GAME, date_key)
	var sizes = doc.get("sizes")
	if int(doc.get("v", 0)) != 1 or not sizes is Dictionary:
		return out
	var keys: Array = (sizes as Dictionary).keys()
	keys.sort_custom(func(a, b) -> bool: return int(a) < int(b))
	var seen := {}
	for k in keys:
		var pic = sizes[k]
		if not pic is Dictionary or not pic.get("name") is Dictionary:
			continue
		var id := String(pic.get("id", ""))
		if id == "" or id == "scene" or seen.has(id):
			continue
		var n: Dictionary = pic.name
		var row := {}
		for lang in ["en", "pt", "es"]:
			var w := String(n.get(lang, "")).strip_edges()
			if w == "" or w.length() > 30:
				row = {}
				break
			row[lang] = w
		if row.is_empty():
			continue
		var g = pic.get("g")
		if g is Dictionary and String(g.get("pt", "")) in GENDERS and String(g.get("es", "")) in GENDERS:
			row["g"] = {"pt": String(g.pt), "es": String(g.es)}
		seen[id] = true
		out.append(row)
	return out

## Yarn Hoop's drawn picture for `band` of the daily of `date_key`:
## {id, name, pins, panels, inks} (pins a PackedVector2Array in a square of
## 100, panels an Array of PackedInt32Array, inks a colour "#rrggbb" a
## panel), or {} when there is none or any of it will not do (a panel of
## under 3 or over HOOP_CORNERS corners, a pin used twice in one, a side
## three panels share).
const HOOP_CORNERS := 7
const HOOP_MOST := 400
static func hoop(date_key: int, band: int) -> Dictionary:
	if date_key == 0 or not Backend.started():
		return {}
	var doc: Dictionary = Backend.cached_day(GAME, date_key)
	var all = doc.get("hoops")
	if int(doc.get("v", 0)) != 1 or not all is Dictionary or not all.get(str(band)) is Dictionary:
		return {}
	return hoop_of(all[str(band)])

## A drawn Yarn Hoop picture as the night writes it, read and checked; {}
## when it will not do.
static func hoop_of(got: Dictionary) -> Dictionary:
	var flat = got.get("pins")
	var list = got.get("panels")
	if not flat is Array or not list is Array or (flat as Array).size() % 2 == 1:
		return {}
	var count: int = (flat as Array).size() / 2
	if count < 4 or count > HOOP_MOST * 2 or (list as Array).size() < 4 or (list as Array).size() > HOOP_MOST:
		return {}
	var pins := PackedVector2Array()
	for i in count:
		var x = flat[2 * i]
		var y = flat[2 * i + 1]
		if not (x is float or x is int) or not (y is float or y is int) or not is_finite(float(x)) or not is_finite(float(y)):
			return {}
		pins.append(Vector2(clampf(float(x), -10.0, 110.0), clampf(float(y), -10.0, 110.0)))
	var panels: Array = []
	var inks: Array = []
	var sides := {}
	for p in list:
		if not p is Dictionary or not p.get("k") is Array or not p.get("c") is String:
			return {}
		var k: Array = p.k
		if k.size() < 3 or k.size() > HOOP_CORNERS or not Color.html_is_valid(p.c):
			return {}
		var corners := PackedInt32Array()
		for v in k:
			if not (v is float or v is int) or int(v) < 0 or int(v) >= count or corners.has(int(v)):
				return {}
			corners.append(int(v))
		for m in corners.size():
			var a := corners[m]
			var b := corners[(m + 1) % corners.size()]
			var key := mini(a, b) * 65536 + maxi(a, b)
			sides[key] = int(sides.get(key, 0)) + 1
			if sides[key] > 2:
				return {}
		panels.append(corners)
		inks.append(String(p.c))
	var id := String(got.get("id", ""))
	var shown := id.replace("_", " ")
	var names = got.get("name")
	if names is Dictionary:
		var lang := TranslationServer.get_locale().substr(0, 2)
		shown = String(names.get(lang, names.get("en", shown)))
	shown = shown.strip_edges()
	return {"id": "themed_" + id, "name": shown.left(1).to_upper() + shown.substr(1), "pins": pins, "panels": panels, "inks": inks}

## The word boards' themed words for the daily of `date_key`, in the
## language the boards' lists follow (Locale.current()), the best first, or
## empty: `hiddenword` is an Array of answers, `wordtrail` a Dictionary of
## them by length ("3" to "8"). The
## night picks them out of the boards' own lists (server/functions/src/
## words.ts); the board keeps only what its list holds as it spells it
## (HiddenWordState.setup, WordTrailState._write), so a word it would not
## deal is never dealt.
static func words(date_key: int, board: String):
	var empty = {} if board == "wordtrail" else []
	if date_key == 0 or not Backend.started():
		return empty
	var doc: Dictionary = Backend.cached_day(GAME, date_key)
	var all = doc.get("words")
	if int(doc.get("v", 0)) != 1 or not all is Dictionary or not all.get(board) is Dictionary:
		return empty
	var got = all[board].get(Locale.current())
	return got if typeof(got) == typeof(empty) else empty

## How Big?'s things from the night for the daily of `date_key`, or []:
## the day's new ones and a few of the pool's (server/functions/src/
## things.ts), each a row of content/how_big.json's kind with its shape in
## it (`shape`: content/how_big_shapes.json's kind) and its words in three
## languages (`name`, `fact`). One that does not keep what the board reads
## is dropped, and the thirty fill its place.
static func things(date_key: int) -> Array:
	var out: Array = []
	if date_key == 0 or not Backend.started():
		return out
	var doc: Dictionary = Backend.cached_day(GAME, date_key)
	var all = doc.get("things")
	if int(doc.get("v", 0)) != 1 or not all is Array:
		return out
	var id_ok := RegEx.create_from_string("^d_[a-z0-9_]+$")
	for got in all:
		if not got is Dictionary or id_ok.search(str(got.get("id", ""))) == null:
			continue
		var size := float(got.get("size_m", 0.0))
		if size <= 0.0 or size > 40.0 or not str(got.get("measure", "")) in ["long", "tall"]:
			continue
		if not (got.get("name") is Dictionary and str(got.name.get("en", "")) != ""):
			continue
		if not (got.get("fact") is Dictionary and _shape_ok(got.get("shape"))):
			continue
		if out.any(func(x: Dictionary) -> bool: return x.id == got.id):
			continue
		got["from"] = 0.0
		got["to"] = 1.0
		out.append(got)
	return out

## A shape as the board draws it: a box whose longer side is 1000, rings of
## at least three points and whole triangles, every number inside the box.
static func _shape_ok(s) -> bool:
	if not s is Dictionary:
		return false
	var w := float(s.get("w", 0.0))
	var h := float(s.get("h", 0.0))
	if w <= 0.0 or h <= 0.0 or absf(maxf(w, h) - 1000.0) > 0.5:
		return false
	var tris = s.get("tris")
	var loops = s.get("loops")
	if not tris is Array or (tris as Array).is_empty() or (tris as Array).size() % 6 != 0:
		return false
	if not loops is Array or (loops as Array).is_empty():
		return false
	for ring in loops:
		if not ring is Array or (ring as Array).size() < 6 or (ring as Array).size() % 2 != 0:
			return false
	for list in [tris] + loops:
		for k in (list as Array).size():
			var v = list[k]
			if not (v is float or v is int) or float(v) < -0.5 or float(v) > (w if k % 2 == 0 else h) + 0.5:
				return false
	return true

## Whether `rows` is a picture the band of side `size` may deal: a square
## of a side within the band's range, in the bank's letters, keeping the
## rules above.
static func valid(rows, size: int) -> bool:
	if not RULES.has(size) or not rows is Array or (rows as Array).is_empty():
		return false
	var rule: Dictionary = RULES[size]
	var side: int = (rows as Array).size()
	if side < int(rule.side[0]) or side > int(rule.side[1]):
		return false
	var known := letters()
	var count := {}
	var filled := 0
	for row in rows:
		if not row is String or (row as String).length() != side:
			return false
		for ch: String in row:
			if ch == ".":
				continue
			if not known.has(ch):
				return false
			count[ch] = int(count.get(ch, 0)) + 1
			filled += 1
	if count.size() < int(rule.colours[0]) or count.size() > int(rule.colours[1]):
		return false
	var share := float(filled) / float(side * side)
	var fill: Array = rule.get("fill", FILL)
	if share < float(fill[0]) or share > float(fill[1]):
		return false
	for ch in count:
		if float(count[ch]) >= LEAD * filled:
			return false
	var top := false; var bottom := false; var left := false; var right := false
	for i in side:
		top = top or String(rows[0])[i] != "."
		bottom = bottom or String(rows[side - 1])[i] != "."
		left = left or String(rows[i])[0] != "."
		right = right or String(rows[i])[side - 1] != "."
	return not (top and bottom and left and right)
