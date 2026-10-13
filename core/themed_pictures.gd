class_name ThemedPictures
extends RefCounted

## The day's themed bead pictures, as a phone reads them
## (docs/superpowers/specs/2026-10-13-daily-theme-design.md). The night's
## process publishes one picture a size -- three things from the theme's
## scene at 10, 12 and 16 squares, the scene at 24 and 32
## (server/functions/src/pictures.ts) -- and Pixel Garden, Button Box and Toy
## Cannons deal it in place of their bank's for that size.
##
## Only what this phone already holds is read (Backend.cached_day): no board
## waits on the network for a picture. world/main.gd asks for the day behind
## the menu at boot. With no document, an unstarted backend (the suite, every
## harness, tools/export_days.gd), a board dealt from New, or a picture that
## does not keep the rules below, the answer is {} and the bank deals.

const Backend = preload("res://core/backend.gd")
const GAME := "pictures"
const BANK := "res://content/pixel_garden.json"
## tools/check_pixel_garden.py's check(), as tools/beads.js holds it and the
## server ran it: colours and fill by size; a small picture leaves an edge
## bare; a big one is a scene or a cut-out and no colour is `MOST` of it.
const RULES := {
	10: {"colours": [3, 4], "fill": [0.30, 0.70], "small": true},
	12: {"colours": [4, 5], "fill": [0.30, 0.70], "small": true},
	16: {"colours": [6, 7], "fill": [0.34, 0.66]},
	24: {"colours": [7, 10], "fill": [0.85, 1.0], "cut": 5},
	32: {"colours": [8, 12], "fill": [0.85, 1.0], "cut": 6},
}
const CUT_FILL := [0.30, 0.70]
const MOST := 0.45

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

static func valid(rows, size: int) -> bool:
	if not RULES.has(size) or not rows is Array or (rows as Array).size() != size:
		return false
	var known := letters()
	var count := {}
	var filled := 0
	for row in rows:
		if not row is String or (row as String).length() != size:
			return false
		for ch: String in row:
			if ch == ".":
				continue
			if not known.has(ch):
				return false
			count[ch] = int(count.get(ch, 0)) + 1
			filled += 1
	var rule: Dictionary = RULES[size]
	var share := float(filled) / float(size * size)
	var cut: bool = rule.has("cut") and share >= CUT_FILL[0] and share <= CUT_FILL[1]
	var least: int = rule.cut if cut else rule.colours[0]
	if count.size() < least or count.size() > int(rule.colours[1]):
		return false
	if not cut and (share < float(rule.fill[0]) or share > float(rule.fill[1])):
		return false
	if rule.has("cut"):
		for ch in count:
			if int(count[ch]) >= MOST * size * size:
				return false
	if rule.get("small", false):
		var top := false; var bottom := false; var left := false; var right := false
		for i in size:
			top = top or String(rows[0])[i] != "."
			bottom = bottom or String(rows[size - 1])[i] != "."
			left = left or String(rows[i])[0] != "."
			right = right or String(rows[i])[size - 1] != "."
		if top and bottom and left and right:
			return false
	return true
