class_name ThemedPictures
extends RefCounted

## The day's themed bead pictures, as a phone reads them
## (docs/superpowers/specs/2026-10-13-daily-theme-design.md). The night's
## process publishes one picture a band -- a thing from the theme, drawn as
## shaded pixel art on a bare board (server/functions/src/pictures.ts) --
## keyed by the band's side (10, 12, 24, 32, 48 for Button Box's Insane on
## builds before 2026-10-27, and 96 for Jewel Box's Insane since, sewn a
## quarter at a time), and Pixel Garden, Button Box and Toy Cannons deal it
## in place of their bank's for that band (Button Box's Hard asks for the
## 32).
##
## Since 2026-10-14 a picture is kept at the squares it was drawn at, never
## redrawn to the band's side: its rows are a square of any side within the
## band's range (RULES.side), and the boards lay whatever side they are
## handed (Pixel Garden by rows.size(), the other two by w and h).
##
## Gumdrop's jellies ride in the same document, a mould each (`jellies`),
## and Yarn Hoop's low-poly pictures, a band each (`hoops`, since
## 2026-10-16): pins and panels read off a drawing on the night
## (server/functions/src/hoop.ts), laid here as they are.
##
## Only what this phone already holds is read (Backend.cached_day): no board
## waits on the network for a picture. world/main.gd asks for the day behind
## the menu at boot. With no document, an unstarted backend (the suite, every
## harness, tools/export_days.gd), a board dealt from New, or a picture that
## does not keep the rules below, the answer is {} and the bank deals.

const Backend = preload("res://core/backend.gd")
const Mould = preload("res://puzzles/gumdrop_mould.gd")
const GAME := "pictures"
const BANK := "res://content/pixel_garden.json"
## tools/beads.js RULES, as the server ran them, by the band's side: the
## side the rows may be, colours, the fill of the picture's own square, the
## largest colour's share of its beads (Button Box's `lead`), and an edge
## left bare. The two tables change together.
const RULES := {
	10: {"side": [10, 18], "colours": [3, 7]},
	12: {"side": [12, 22], "colours": [4, 7]},
	24: {"side": [24, 34], "colours": [6, 12]},
	32: {"side": [32, 40], "colours": [8, 14]},
	48: {"side": [44, 64], "colours": [10, 16]},
	96: {"side": [80, 112], "colours": [12, 16]},
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

## Gumdrop's themed jellies for `band` of the daily of `date_key`, built
## and not yet dressed (puzzles/gumdrop_mould.gd `build_parts`), a mould
## each in the theme's order, or []: the night writes a list a band under
## `jellies` (server/functions/src/jelly.ts), and one that does not keep
## its band's row of Mould.THEMED is dropped, its place the board's own.
static func jellies(date_key: int, band: int) -> Array:
	var out: Array = []
	if date_key == 0 or not Backend.started():
		return out
	var doc: Dictionary = Backend.cached_day(GAME, date_key)
	var all = doc.get("jellies")
	if int(doc.get("v", 0)) != 1 or not all is Dictionary or not all.get(str(band)) is Array:
		return out
	for got in all[str(band)]:
		if not got is Dictionary:
			continue
		var parts := Mould.from_doc(got.get("parts"))
		if parts.is_empty():
			continue
		var m := Mould.build_parts("themed_" + String(got.get("id", "")), parts)
		if Mould.unfit(m, band) == "" and not out.any(func(x: Dictionary) -> bool: return x.id == m.id):
			out.append(m)
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
	if share < float(FILL[0]) or share > float(FILL[1]):
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
