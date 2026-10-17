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

## The vista of `time` for today, or null.
static func texture(time: String) -> Texture2D:
	var today := Daily.date_key()
	if today != _day:
		_day = today
		_tex = _decoded(Backend.cached_day(GAME, today)) if Backend.started() else {}
	return _tex.get(time)

## The day's four from a document in hand, for a probe that runs offline.
static func adopt(doc: Dictionary) -> void:
	_day = Daily.date_key()
	_tex = _decoded(doc)

## Forgets what was decoded, for the document that just arrived.
static func reload() -> void:
	_day = 0

static func _decoded(doc: Dictionary) -> Dictionary:
	var times = doc.get("times")
	if int(doc.get("v", 0)) != 1 or not times is Dictionary:
		return {}
	var out := {}
	for time in TIMES:
		var img := Image.new()
		if img.load_jpg_from_buffer(Marshalls.base64_to_raw(str(times.get(time, "")))) != OK:
			return {}
		out[time] = ImageTexture.create_from_image(img)
	return out
