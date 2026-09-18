extends Control

## The win screen's top: the sun and the moon at illustration size, both
## beaming, the moon in front and a little lower, leaves at the sides, three
## stars, then "Well done!" and "Perfect balance!". Laid out in the column's
## space (1000 wide, 640 tall) under the host's top margin, at the spec's
## positions. It slides down into the space the top bar and day card leave.
## Spec: docs/superpowers/specs/2026-09-18-binairo-flat-design.md, section 8
## (as amended).

const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Icons = preload("res://ui/icons.gd")
const Face = preload("res://ui/faces/face.gd")
const SunFace = preload("res://ui/faces/sun_face.gd")
const MoonFace = preload("res://ui/faces/moon_face.gd")

const HEIGHT := 640.0
## Centres in the column's space (the spec's x less the 40 margin, y less
## the 40 top margin).
const SUN_AT := Vector2(430.0, 230.0)
const SUN_SIZE := 130.0 * 2.0 * 1.55
const MOON_AT := Vector2(570.0, 290.0)
const MOON_SIZE := 105.0 * 2.0
const LEAF_L := Vector2(210.0, 260.0)
const LEAF_R := Vector2(790.0, 260.0)
const LEAF := 110.0
const STARS := [[360.0, 100.0, 22.0], [690.0, 100.0, 16.0], [760.0, 200.0, 26.0]]
const TITLE_Y := 508.0
const SUB_Y := 582.0
const SLIDE := 0.4
const FADE := 0.2

var sun: Control
var moon: Control
var _title: Label
var _sub: Label
var _spin: Tween
var _rock: Tween

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size.y = HEIGHT
	var art := Control.new()
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.draw.connect(_draw_art.bind(art))
	add_child(art)
	sun = SunFace.new()
	sun.size = Vector2(SUN_SIZE, SUN_SIZE)
	sun.position = SUN_AT - sun.size * 0.5
	sun.expression = Face.Expr.JOY
	add_child(sun)
	moon = MoonFace.new()
	moon.size = Vector2(MOON_SIZE, MOON_SIZE)
	moon.position = MOON_AT - moon.size * 0.5
	moon.expression = Face.Expr.JOY
	moon.rocks = true
	add_child(moon)
	_title = Label.new()
	_title.theme_type_variation = "WellDone"
	_title.text = "Well done!"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_title.offset_top = TITLE_Y - 60.0
	_title.offset_bottom = TITLE_Y + 60.0
	add_child(_title)
	_sub = Label.new()
	_sub.theme_type_variation = "CardBodyDim"
	_sub.add_theme_font_size_override("font_size", 34)
	_sub.text = "Perfect balance!"
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_sub.offset_top = SUB_Y - 24.0
	_sub.offset_bottom = SUB_Y + 24.0
	add_child(_sub)
	visible = false

## Two leaves turned outward and three four-point stars in sun.
func _draw_art(ci: Control) -> void:
	ci.draw_set_transform(LEAF_L, -0.9, Vector2.ONE)
	Icons.paint(ci, "leaf", Rect2(Vector2(-LEAF * 0.5, -LEAF * 0.5), Vector2(LEAF, LEAF)), Pal.LEAF)
	ci.draw_set_transform(LEAF_R, -2.2, Vector2.ONE)
	Icons.paint(ci, "leaf", Rect2(Vector2(-LEAF * 0.5, -LEAF * 0.5), Vector2(LEAF, LEAF)), Pal.LEAF)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for s in STARS:
		var pts := PackedVector2Array()
		for i in 8:
			var a := i * PI / 4.0
			var r: float = s[2] if i % 2 == 0 else s[2] * 0.38
			pts.append(Vector2(s[0], s[1]) + Vector2(cos(a), sin(a)) * r)
		ci.draw_colored_polygon(pts, Pal.SUN)
		ci.draw_polyline(pts + PackedVector2Array([pts[0]]), Pal.SUN, 1.5, true)

## Slides in from 200 above while fading up, after `delay`. Both faces start
## their idle life (the sun turns its rays, the moon rocks).
func enter(delay := 0.0) -> void:
	visible = true
	Motion.slide(self, "position:y", position.y - 200.0, position.y, SLIDE, delay)
	Motion.appear(self, 0.0, 1.0, FADE, delay)
	sun.set_idle(true)
	moon.set_idle(true)
