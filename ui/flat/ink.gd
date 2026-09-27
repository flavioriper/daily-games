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

const CozyTheme = preload("res://ui/theme.gd")

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
	# Light paper takes a white hairline round its edge, as the mock's does.
	if fill.v > 0.5:
		for sb: StyleBoxFlat in [up, down]:
			sb.set_border_width_all(2)
			sb.border_color = Color(1, 1, 1, 0.75)
	for state in ["normal", "hover", "focus"]:
		b.add_theme_stylebox_override(state, up)
	b.add_theme_stylebox_override("pressed", down)
	b.add_theme_stylebox_override("disabled", off)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(state, text)
	b.add_theme_color_override("font_disabled_color", Color(text, 0.4))
	b.add_theme_font_override("font", CozyTheme.body(700))
	b.add_theme_font_size_override("font_size", 32)
	b.material = plain()
	if "glyph_painter" in b:
		b.glyph_painter = icon

## The ink skin's icons, drawn in line and solid ink to the mock's hand;
## false for a name it does not draw, so the button falls back.
static func icon(ci: CanvasItem, name: String, r: Rect2, ink: Color, fill: Color) -> bool:
	var s := minf(r.size.x, r.size.y)
	var o := r.position + (r.size - Vector2(s, s)) * 0.5
	var at := func(x: float, y: float) -> Vector2: return o + Vector2(x, y) * s
	var w := s * 0.1
	match name:
		"chevron_left":
			_line(ci, [at.call(0.62, 0.18), at.call(0.3, 0.5), at.call(0.62, 0.82)], w * 1.1, ink)
		"chevron_right":
			_line(ci, [at.call(0.38, 0.18), at.call(0.7, 0.5), at.call(0.38, 0.82)], w * 1.1, ink)
		"check":
			_line(ci, [at.call(0.16, 0.52), at.call(0.4, 0.76), at.call(0.86, 0.26)], w * 1.15, ink)
		"reset", "undo":
			# A circle drawn nearly all the way round, clockwise, with the
			# arrowhead at its upper right (mirrored for undo).
			var c: Vector2 = at.call(0.5, 0.54)
			var rad := s * 0.32
			var flip := -1.0 if name == "undo" else 1.0
			var from := -PI * 0.22
			var raw := PackedVector2Array()
			for i in 29:
				var a := from - TAU * 0.8 * i / 28.0
				raw.append(c + Vector2(cos(a) * flip, sin(a)) * rad)
			_line(ci, Array(raw), w, ink)
			var tip := raw[0]
			var tang := (raw[0] - raw[1]).normalized()
			var nrm := Vector2(-tang.y, tang.x)
			var head := s * 0.34
			ci.draw_colored_polygon(PackedVector2Array([tip + tang * head * 0.6,
				tip - tang * head * 0.2 + nrm * head * 0.5, tip - tang * head * 0.2 - nrm * head * 0.5]), ink)
		"bulb":
			var c: Vector2 = at.call(0.5, 0.4)
			ci.draw_circle(c, s * 0.25, ink, true, -1.0, true)
			ci.draw_colored_polygon(PackedVector2Array([at.call(0.33, 0.5), at.call(0.67, 0.5),
				at.call(0.6, 0.7), at.call(0.4, 0.7)]), ink)
			_line(ci, [at.call(0.39, 0.79), at.call(0.61, 0.79)], w * 0.8, ink)
			_line(ci, [at.call(0.43, 0.9), at.call(0.57, 0.9)], w * 0.8, ink)
			# The glint: a short arc of paper inside the glass.
			ci.draw_arc(c, s * 0.14, PI * 1.05, PI * 1.45, 8, fill, w * 0.5, true)
		"gear":
			var c: Vector2 = at.call(0.5, 0.5)
			for i in 8:
				var a := i * PI / 4.0
				var d := Vector2.from_angle(a)
				var t := Vector2(-d.y, d.x)
				ci.draw_colored_polygon(PackedVector2Array([c + d * s * 0.2 - t * s * 0.08,
					c + d * s * 0.44 - t * s * 0.07, c + d * s * 0.44 + t * s * 0.07,
					c + d * s * 0.2 + t * s * 0.08]), ink)
			ci.draw_circle(c, s * 0.31, ink, true, -1.0, true)
			ci.draw_circle(c, s * 0.12, fill, true, -1.0, true)
		_:
			return false
	return true

## A polyline with round caps and joins.
static func _line(ci: CanvasItem, pts: Array, w: float, ink: Color) -> void:
	ci.draw_polyline(PackedVector2Array(pts), ink, w, true)
	var caps: Array = pts if pts.size() <= 3 else [pts[0], pts[pts.size() - 1]]
	for p: Vector2 in caps:
		ci.draw_circle(p, w * 0.5, ink, true, -1.0, true)
