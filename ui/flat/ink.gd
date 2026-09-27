extends RefCounted

## The ink skin: a monochrome look for a flat screen, warm stone paper with
## everything drawn in one soft charcoal ink -- no painted vista, no colour
## but a muted rose for a broken rule. A trial on `feat/binairo-mono`, worn by
## the one registry entry that says `"skin": "ink"` (Binairo), from the
## user's mock of 2026-09-27.

const PAGE := Color("ebe6dd")
const PAGE_DEEP := Color("ddd6ca")
const CARD := Color("f5f1ea")
const TILE := Color("f8f5ef")
const TILE_EDGE := Color("dcd5ca")
## A placed symbol's tile, and a given's, a step deeper.
const TILE_SET := Color("e4ded4")
const TILE_GIVEN := Color("d6cfc3")
const INK := Color("3a3531")
const INK_DIM := Color("857e76")
const HAZE := Color("c9c1b5")
## A broken rule: the only colour on the screen.
const BAD := Color("b0574c")
const BAD_TILE := Color("ecd2cb")
const SHADOW := Color(0.22, 0.18, 0.13, 0.12)

static var _plain: CanvasItemMaterial

## A material that is nothing, so CozyTheme.dress() leaves a widget clean:
## the paper wash it hands every Panel and Button reads as a stain here.
static func plain() -> CanvasItemMaterial:
	if _plain == null:
		_plain = CanvasItemMaterial.new()
	return _plain

## Cream paper lifted off the page on a soft shadow.
static func paper(fill := CARD, radius := 28, margin := 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	sb.shadow_color = SHADOW
	sb.shadow_size = 14
	sb.shadow_offset = Vector2(0.0, 6.0)
	sb.anti_aliasing_size = 1.2
	return sb

## A button in `fill` on the ink skin's shadow; pressed sinks, disabled fades.
static func button(b: Button, fill: Color, text: Color, radius: int) -> void:
	var up := paper(fill, radius, 8)
	var down := paper(fill.darkened(0.06), radius, 8)
	down.shadow_size = 4
	down.shadow_offset = Vector2(0.0, 2.0)
	var off := paper(Color(fill, 0.6), radius, 8)
	off.shadow_color = Color(SHADOW, 0.04)
	for state in ["normal", "hover", "focus"]:
		b.add_theme_stylebox_override(state, up)
	b.add_theme_stylebox_override("pressed", down)
	b.add_theme_stylebox_override("disabled", off)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(state, text)
	b.add_theme_color_override("font_disabled_color", Color(text, 0.4))
	b.material = plain()
