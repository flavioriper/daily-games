extends RefCounted

## One warm theme for every Control: the display and body fonts, the card
## styles and the button variants the HUD uses, built in code so it stays in
## step with the palette. One Theme instance is built and shared.
## Spec: docs/superpowers/specs/2026-09-14-binairo-hud-design.md, section 4.

const Pal = preload("res://core/palette.gd")

const DISPLAY_PATH := "res://assets/fonts/Fredoka-Variable.ttf"
const BODY_PATH := "res://assets/fonts/Nunito-Variable.ttf"
## The OpenType 'wght' axis tag: the four ASCII bytes packed big-endian.
const WGHT := 0x77676874

static var _theme: Theme
static var _fonts: Dictionary = {}

## The shared theme, built once.
static func make() -> Theme:
	if _theme != null:
		return _theme
	var theme := Theme.new()
	# Plain labels and buttons: the body face, today's paper button look.
	theme.set_font("font", "Label", body(500))
	theme.set_color("font_color", "Label", Pal.TEXT)
	theme.set_font("font", "Button", body(700))
	_button(theme, "Button", Pal.SURFACE_HI, Pal.LINE, 6, 28, Pal.TEXT)
	# Label variations.
	_label(theme, "Wordmark", display(700), 72, Pal.SURFACE)
	theme.set_color("font_outline_color", "Wordmark", Pal.OUTLINE)
	theme.set_constant("outline_size", "Wordmark", 8)
	_label(theme, "Motto", body(700), 24, Pal.SURFACE)
	theme.set_color("font_outline_color", "Motto", Pal.OUTLINE)
	theme.set_constant("outline_size", "Motto", 4)
	_label(theme, "CardTitle", display(600), 40, Pal.TEXT)
	_label(theme, "CardBody", body(500), 30, Pal.TEXT)
	_label(theme, "OnSlateTitle", display(600), 40, Pal.MOON)
	_label(theme, "OnSlateBody", body(500), 30, Pal.MOON)
	_label(theme, "Badge", display(700), 26, Pal.SURFACE)
	# Button variations.
	_variant(theme, "IconButton", body(700), 34, Pal.SURFACE_HI, Pal.LINE, 6, 28, Pal.TEXT)
	_variant(theme, "PrimaryButton", display(700), 40, Pal.SUN, Pal.SUN_DEEP, 8, 32, Pal.TEXT)
	_variant(theme, "DarkButton", display(700), 40, Pal.SLATE, Pal.SLATE_GIVEN, 8, 32, Pal.MOON)
	_theme = theme
	return theme

## The rounded display face at a weight (Fredoka).
static func display(weight: int) -> FontVariation:
	return _font(DISPLAY_PATH, weight)

## The body face at a weight (Nunito).
static func body(weight: int) -> FontVariation:
	return _font(BODY_PATH, weight)

## A cached FontVariation over the file at `path` with the wght axis set. A
## missing file (a stripped test project) falls back to the engine font.
static func _font(path: String, weight: int) -> FontVariation:
	var key := "%s|%d" % [path, weight]
	if _fonts.has(key):
		return _fonts[key]
	var fv := FontVariation.new()
	var base: Font = null
	if ResourceLoader.exists(path):
		base = load(path) as Font
	fv.base_font = base if base != null else ThemeDB.fallback_font
	fv.variation_opentype = {WGHT: weight}
	_fonts[key] = fv
	return fv

static func _label(theme: Theme, name: String, font: Font, size: int, colour: Color) -> void:
	theme.set_type_variation(name, "Label")
	theme.set_font("font", name, font)
	theme.set_font_size("font_size", name, size)
	theme.set_color("font_color", name, colour)

static func _variant(theme: Theme, name: String, font: Font, size: int, fill: Color, border: Color, border_w: int, radius: int, text: Color) -> void:
	theme.set_type_variation(name, "Button")
	theme.set_font("font", name, font)
	theme.set_font_size("font_size", name, size)
	_button(theme, name, fill, border, border_w, radius, text)

## The four button states for a type: normal and hover alike (touch has no
## hover), pressed sinks onto a 2 px edge and darkens toward LINE, disabled
## fades to 55 percent.
static func _button(theme: Theme, type: String, fill: Color, border: Color, border_w: int, radius: int, text: Color) -> void:
	theme.set_stylebox("normal", type, card(fill, radius, border, border_w, 24))
	theme.set_stylebox("hover", type, card(fill, radius, border, border_w, 24))
	theme.set_stylebox("pressed", type, card(fill.lerp(Pal.LINE, 0.15), radius, border, 2, 24))
	theme.set_stylebox("disabled", type, card(Color(fill, 0.55), radius, Color(border, 0.55), border_w, 24))
	theme.set_stylebox("focus", type, StyleBoxEmpty.new())
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		theme.set_color(state, type, text)
	theme.set_color("font_disabled_color", type, Color(text, 0.45))

## A rounded card with a thick bottom edge, the HUD's paper.
static func card(fill: Color, radius: int, border: Color, border_w: int, margin: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	sb.border_width_bottom = border_w
	sb.border_color = border
	return sb

static func paper_card() -> StyleBoxFlat:
	return card(Color(Pal.PAPER, 0.94), 28, Pal.LINE, 6, 24)

static func slate_card() -> StyleBoxFlat:
	return card(Color(Pal.SLATE, 0.92), 24, Pal.SLATE_GIVEN, 0, 20)

static func parchment_card() -> StyleBoxFlat:
	var sb := card(Color(Pal.PARCHMENT, 0.96), 12, Pal.LINE, 0, 24)
	sb.set_border_width_all(3)
	return sb

static func wood_card() -> StyleBoxFlat:
	return card(Pal.WOOD, 28, Pal.WOOD_DEEP, 8, 16)

## Dark wood with a thick deeper edge: the plank the wordmark and the day
## card sit on.
static func plank_card() -> StyleBoxFlat:
	return card(Pal.PLAQUE, 18, Pal.PLAQUE_DEEP, 10, 20)

## The trough carved into the colour tray, holding the buttons.
static func wood_channel() -> StyleBoxFlat:
	return card(Pal.WOOD_DEEP, 20, Pal.WOOD_DEEP.darkened(0.25), 4, 10)
