class_name ThemedPictures
extends RefCounted

## The day's themed bead pictures, as a phone reads them
## (docs/superpowers/specs/2026-10-13-daily-theme-design.md). The night's
## process publishes one picture a band -- a thing from the theme, drawn as
## shaded pixel art on a bare board (server/functions/src/pictures.ts) --
## keyed by the band's side (10, 12, 24, 32, and 48 for Button Box's Insane
## alone), and Pixel Garden, Button Box and Toy Cannons deal it in place of
## their bank's for that band (Button Box's Hard asks for the 32).
##
## Since 2026-10-14 a picture is kept at the squares it was drawn at, never
## redrawn to the band's side: its rows are a square of any side within the
## band's range (RULES.side), and the boards lay whatever side they are
## handed (Pixel Garden by rows.size(), the other two by w and h).
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
## left bare. The two tables change together.
const RULES := {
	10: {"side": [10, 18], "colours": [3, 7]},
	12: {"side": [12, 22], "colours": [4, 7]},
	24: {"side": [24, 34], "colours": [6, 12]},
	32: {"side": [32, 40], "colours": [8, 14]},
	48: {"side": [40, 64], "colours": [10, 16]},
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
