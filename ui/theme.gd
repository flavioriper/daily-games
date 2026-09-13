extends RefCounted

## One warm theme for every Control. Buttons are rounded paper cards with dark
## text; labels default to the ink colour. Built in code so it stays in step
## with the palette.

const Pal = preload("res://core/palette.gd")

static func make() -> Theme:
	var theme := Theme.new()
	theme.set_stylebox("normal", "Button", _card(Pal.SURFACE_HI))
	theme.set_stylebox("hover", "Button", _card(Pal.SURFACE))
	theme.set_stylebox("pressed", "Button", _card(Pal.LINE))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	theme.set_color("font_color", "Button", Pal.TEXT)
	theme.set_color("font_hover_color", "Button", Pal.TEXT)
	theme.set_color("font_pressed_color", "Button", Pal.TEXT)
	theme.set_color("font_focus_color", "Button", Pal.TEXT)
	theme.set_color("font_color", "Label", Pal.TEXT)
	return theme

static func _card(fill: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_corner_radius_all(28)
	sb.set_content_margin_all(24)
	sb.border_width_bottom = 6
	sb.border_color = Pal.LINE
	return sb
