class_name ThemedVistas
extends RefCounted

## The day's painted vistas, as a phone reads them
## (docs/superpowers/specs/2026-10-17-themed-vistas-design.md): the theme's
## place painted at morning, afternoon, dusk and night by the night's
## process (server/functions/src/vistas.ts), a JPEG each, published as
## `days/<day>/turns/vistas` only when all four passed. The difficulty
## sheet's four rows take them in that order and the day card the
## afternoon (ui/menu/vistas.gd).
##
## Only what this phone already holds is read (Backend.cached_day), as
## ThemedPictures does: with no document, an unstarted backend (the suite,
## every harness) or a picture that will not decode, the answer is null and
## the bundled vistas are drawn as ever.

const Backend = preload("res://core/backend.gd")
const GAME := "vistas"
const TIMES := ["morning", "afternoon", "dusk", "night"]
## The group told when the day's document arrives behind a built screen.
const GROUP := "themed_vistas"

static var _day := 0
static var _tex := {}
static var _name := {}
static var _cast := []

## The vista of `time` for today, or null.
static func texture(time: String) -> Texture2D:
	_refresh()
	return _tex.get(time)

## The day's pair of Peeplets as the night published it (two persona
## indices, core/cast.gd clamps them), [] with none. Kept even when the
## document's pictures did not decode.
static func cast() -> Array:
	_refresh()
	return _cast

static func _refresh() -> void:
	var today := Daily.date_key()
	if today != _day:
		_day = today
		_take(Backend.cached_day(GAME, today) if Backend.started() else {})

## The day's theme by name in the player's language, "" with no vistas: the
## day card shows it in place of the island's.
static func title() -> String:
	if texture(TIMES[0]) == null:
		return ""
	var lang := TranslationServer.get_locale().substr(0, 2)
	return str(_name.get(lang, _name.get("en", ""))).strip_edges()

## The day's four from a document in hand, for a probe that runs offline.
static func adopt(doc: Dictionary) -> void:
	_day = Daily.date_key()
	_take(doc)

static func _take(doc: Dictionary) -> void:
	_tex = _decoded(doc)
	var names = doc.get("name")
	_name = names if names is Dictionary and not _tex.is_empty() else {}
	_cast = _cast_of(doc)

## Forgets what was decoded, for the document that just arrived.
static func reload() -> void:
	_day = 0
	_cast = []

static func _cast_of(doc: Dictionary) -> Array:
	var c = doc.get("cast")
	if not c is Array or c.size() != 2:
		return []
	for v in c:
		if not (v is int or v is float):
			return []
	return [int(c[0]), int(c[1])]

static func _decoded(doc: Dictionary) -> Dictionary:
	var times = doc.get("times")
	if int(doc.get("v", 0)) != 1 or not times is Dictionary:
		return {}
	var out := {}
	for time in TIMES:
		var img := Image.new()
		var raw := Marshalls.base64_to_raw(str(times.get(time, "")))
		if raw.is_empty() or img.load_jpg_from_buffer(raw) != OK:
			return {}
		out[time] = ImageTexture.create_from_image(img)
	return out
