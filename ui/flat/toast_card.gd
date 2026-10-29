extends RefCounted

## A board's toast: a paper card with one wrapped line, popping in, standing
## a while and fading. Shikaku, Untangle, Hosepipes and Binairo each carry
## their own copy of the same look; Paper Box (2026-10-29) is the first to
## use this one, Lattice (off its own dark pill) and Light Up the same day,
## and the others can move onto it when next touched.
##
## The board owns the clock (`now`) and where the card stands; the card
## keeps its mesh in a var until the next draw replaces it. One draw_mesh
## and the words.

const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Face = preload("res://ui/faces/face.gd")
const CozyTheme = preload("res://ui/theme.gd")

## How long a line stands, and a reading (the bulb's, kept until a move puts
## it out); the fade in and out.
const TIME := 3.6
const READ := 7.0
const FADE := 0.25

var text := ""
var hold := false
var _at := -INF
var _shown: ArrayMesh

## Says `text` at `now`. The same line said again while it shows only
## stays longer.
func say(what: String, now: float, held := false) -> void:
	if what == text and level(now) > 0.0:
		_at = now - FADE
	else:
		text = what
		_at = now
	hold = held

## Puts the card out at once.
func clear() -> void:
	text = ""
	hold = false

## How much of the card shows at `now`: 0 gone, 1 full.
func level(now: float) -> float:
	if text == "":
		return 0.0
	var stay := READ if hold else TIME
	return 1.0 - clampf((now - _at - stay) / FADE, 0.0, 1.0)

## Whether the card is coming in or going out at `now` (the board keeps
## drawing), or showing at all.
func showing(now: float) -> bool:
	return level(now) > 0.0

## The card's height for `width` at font size `fs` and padding `pad`.
func tall(width: float, fs: int, pad: Vector2) -> float:
	var font: Font = CozyTheme.body(700)
	return font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, width - 2.0 * pad.x, fs).y + 2.0 * pad.y

## Draws the card on `ci`, its middle at `centre`, `width` wide.
func draw(ci: CanvasItem, centre: Vector2, width: float, now: float, fs: int, pad: Vector2) -> void:
	var a := level(now)
	if a <= 0.0:
		return
	var font: Font = CozyTheme.body(700)
	var inner := width - 2.0 * pad.x
	var card := Vector2(width, tall(width, fs, pad))
	var k := 1.0 if Motion.reduce else Motion.pop_in_scale(now - _at, FADE).x
	var r := minf(24.0, card.y * 0.3)
	var b := Face.Builder.new()
	b.polygon(Face.Builder.round_rect(-card * 0.5 - Vector2.ONE * 3.0, card + Vector2.ONE * 6.0, r + 3.0), Pal.LINE)
	b.polygon(Face.Builder.round_rect(-card * 0.5, card, r), Pal.SURFACE)
	_shown = b.mesh()
	ci.draw_set_transform(centre, 0.0, Vector2(k, k))
	ci.draw_mesh(_shown, null, Transform2D.IDENTITY, Color(1.0, 1.0, 1.0, a))
	ci.draw_multiline_string(font, Vector2(-inner * 0.5, -card.y * 0.5 + pad.y + font.get_ascent(fs)),
		text, HORIZONTAL_ALIGNMENT_CENTER, inner, fs, -1, Color(Pal.TEXT, a))
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
