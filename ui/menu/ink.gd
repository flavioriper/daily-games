extends RefCounted

## Text drawn straight onto a canvas for the Stats and Streak tabs, where a
## Label per figure would be a node per number (gl_compatibility pays per
## draw command either way, so the saving is nodes, not calls).

static func text(ci: CanvasItem, font: Font, s: String, pos: Vector2, size: int, col: Color,
		align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	if align == HORIZONTAL_ALIGNMENT_CENTER:
		pos.x -= w * 0.5
	elif align == HORIZONTAL_ALIGNMENT_RIGHT:
		pos.x -= w
	ci.draw_string(font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

## The largest size at or under `size` at which `s` fits `width`, stepping
## down and never under `floor_size` (the top bar's _fit, in small).
static func fit(font: Font, s: String, size: int, width: float, floor_size := 18) -> int:
	while size > floor_size and font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
		size -= 1
	return size
