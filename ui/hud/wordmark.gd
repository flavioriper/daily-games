extends Control

## The title as cut-out lettering: a cream face standing on a tan extrusion
## that grades darker toward the plank, a lighter top edge where the light
## catches, and a soft shadow past the foot. No outline; the depth does the
## separating. Every pass is the same display face, so the 2D batcher folds
## them into one draw call.
## Spec: docs/superpowers/specs/2026-09-14-binairo-hud-design.md, section 4
## (amendment of 2026-09-16).

const CozyTheme = preload("res://ui/theme.gd")
const Pal = preload("res://core/palette.gd")

const SIZE := 76
## Pixels the letters stand off the plank.
const DEPTH := 7
## The extrusion's tint just under the face and down at the plank, as a mix
## from the light wood toward the plank's deep edge.
const EXTRUDE_TOP := 0.05
const EXTRUDE_BOTTOM := 0.8
## Where the shadow lands, past the extrusion's foot.
const SHADOW := Vector2(2, 3)
const SHADOW_ALPHA := 0.22
const SHADOW_SPREAD := 4

var text := "":
	set(v):
		text = v
		update_minimum_size()
		queue_redraw()
var _font: Font

func _init(t := "") -> void:
	_font = CozyTheme.display(700)
	mouse_filter = MOUSE_FILTER_IGNORE
	text = t

func _get_minimum_size() -> Vector2:
	var s := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, SIZE)
	return Vector2(s.x + SHADOW.x, _font.get_height(SIZE) + DEPTH + SHADOW.y)

func _draw() -> void:
	var origin := Vector2(0, _font.get_ascent(SIZE))
	# The shadow: a fat faint outline under a fainter solid, so its edge
	# falls off instead of stopping.
	var shadow_at := origin + Vector2(0, DEPTH) + SHADOW
	_pass(shadow_at, Color(Pal.OUTLINE, SHADOW_ALPHA * 0.5), SHADOW_SPREAD)
	_pass(shadow_at, Color(Pal.OUTLINE, SHADOW_ALPHA))
	# The extrusion, one pixel at a time from the plank up to the face.
	for i in range(DEPTH, 0, -1):
		var t := lerpf(EXTRUDE_TOP, EXTRUDE_BOTTOM, float(i - 1) / maxf(DEPTH - 1, 1))
		_pass(origin + Vector2(0, i), Pal.WOOD.lerp(Pal.PLAQUE_DEEP, t))
	# The face, over a lighter pass one pixel up: only the top edges show it.
	_pass(origin + Vector2(0, -1), Pal.SURFACE)
	_pass(origin, Pal.SURFACE_HI)

func _pass(at: Vector2, colour: Color, outline := 0) -> void:
	if outline > 0:
		draw_string_outline(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, SIZE, outline, colour)
	else:
		draw_string(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, SIZE, colour)
