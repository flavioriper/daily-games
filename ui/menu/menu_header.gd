extends Control

## The first screen's header: `Daily` lettered in ink with a sprig growing
## out of it and the motto under, the sun and the moon beside it, and the
## settings and calendar buttons above them.
##
## The wordmark is a Label, not the extruded letters the campsite carried
## (legacy/ui/hud/title_view.gd): no SubViewport, no World3D, no TextMesh.
## The two characters are the board's own -- ui/faces/sun_face.gd and
## moon_face.gd, the pair Binairo is played with -- so the first screen and
## the first board are visibly one game. They idle: the rays turn once in
## forty seconds and the moon rocks, both stilled by reduce-motion like
## everything else.
##
## **The calendar button and its badge are decoration**, by decision with the
## user on 2026-09-18. There is no calendar behind it and the `1` counts
## nothing; it squashes and does nothing else.
## Spec: docs/superpowers/specs/2026-09-18-flat-menu-design.md, sections 1
## and 4.

signal settings

const Pal = preload("res://core/palette.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Motion = preload("res://core/motion.gd")
const Icons = preload("res://ui/icons.gd")
const IconButton = preload("res://ui/hud/icon_button.gd")
const SunFace = preload("res://ui/faces/sun_face.gd")
const MoonFace = preload("res://ui/faces/moon_face.gd")

const TITLE := "Daily"
const MOTTO := "Small puzzles\nbrighter days"
## Measured against the vertical budget rather than chosen: at 1080 by 1920
## the screen owes 80 to margins, 180 to the day row, 150 to the bar and 60
## to the three gaps, and four rows of cards want the rest. 380 is what is
## left, and the lettering below is sized to fit inside it: 100 of air, a
## 140 wordmark on a ~182 line, and two 38 motto lines.
const HEIGHT := 380.0
const BUTTON := Vector2(110.0, 110.0)
const BUTTON_GAP := 20.0
const BADGE := 48.0
## The sun's and the moon's seats, and where the pair sits: right-aligned,
## under the buttons.
const SUN_SEAT := 190.0
const MOON_SEAT := 166.0
const PAIR_TOP := 128.0
const PAIR_RIGHT := 8.0
## The sprig over the wordmark: how far right of its left edge the stem
## stands, as a fraction of the lettering's width, and the leaves' size.
const SPRIG_AT := 0.52
const SPRIG_LEAF := 58.0

var gear: Button
var calendar: Button
var _title: Label
var _sun: Control
var _moon: Control

## Built in _init rather than _ready, so the menu can wire `gear` and
## `calendar` the moment it makes one.
func _init() -> void:
	custom_minimum_size.y = HEIGHT
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()

func _build() -> void:
	# --- the two buttons, top right ---
	calendar = _button("calendar")
	calendar.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	calendar.offset_left = -BUTTON.x
	calendar.offset_bottom = BUTTON.y
	var badge := Control.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	badge.offset_left = -BADGE - BUTTON.x * 0.06
	badge.offset_right = -BUTTON.x * 0.06
	badge.offset_top = -BADGE * 0.3
	badge.offset_bottom = BADGE * 0.7
	badge.draw.connect(_draw_badge.bind(badge))
	calendar.add_child(badge)

	gear = _button("gear")
	gear.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	gear.offset_left = -BUTTON.x * 2.0 - BUTTON_GAP
	gear.offset_right = -BUTTON.x - BUTTON_GAP
	gear.offset_bottom = BUTTON.y
	gear.pressed.connect(func() -> void: settings.emit())

	# --- the lettering ---
	var block := VBoxContainer.new()
	block.name = "Title"
	block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	block.add_theme_constant_override("separation", 0)
	block.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	block.offset_top = 100.0
	add_child(block)
	_title = Label.new()
	_title.theme_type_variation = "MenuWordmark"
	_title.text = TITLE
	block.add_child(_title)
	var motto := Label.new()
	motto.theme_type_variation = "MenuMotto"
	motto.text = MOTTO
	block.add_child(motto)
	var sprig := Control.new()
	sprig.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sprig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sprig.draw.connect(_draw_sprig.bind(sprig))
	add_child(sprig)
	_title.resized.connect(sprig.queue_redraw)

	# --- the two characters ---
	_sun = SunFace.new()
	_sun.size = Vector2(SUN_SEAT, SUN_SEAT)
	add_child(_sun)
	_moon = MoonFace.new()
	_moon.rocks = true
	_moon.size = Vector2(MOON_SEAT, MOON_SEAT)
	add_child(_moon)
	resized.connect(_place_pair)
	_place_pair()

func _button(icon: String) -> Button:
	var b := IconButton.new(icon)
	b.custom_minimum_size = BUTTON
	b.size = BUTTON
	add_child(b)
	return b

## The pair hangs off the right edge, so a wider screen moves them out
## rather than stretching them.
func _place_pair() -> void:
	if _sun == null:
		return
	var right := size.x - PAIR_RIGHT
	_moon.position = Vector2(right - MOON_SEAT, PAIR_TOP + (SUN_SEAT - MOON_SEAT) * 0.5 + 8.0)
	_sun.position = Vector2(_moon.position.x - SUN_SEAT * 0.62, PAIR_TOP)

## A stem out of the lettering with two leaves on it, over the middle of the
## word. Drawn from the title's own rect, so it follows the type.
func _draw_sprig(ci: Control) -> void:
	if _title == null or _title.size.x <= 0.0:
		return
	var text_w: float = _title.get_minimum_size().x
	var base := _title.get_global_transform().origin - ci.get_global_transform().origin
	var root := base + Vector2(text_w * SPRIG_AT, _title.size.y * 0.24)
	var tip := root + Vector2(4.0, -46.0)
	ci.draw_polyline(PackedVector2Array([root, root + Vector2(6.0, -24.0), tip]), Pal.LEAF, 10.0, true)
	Icons.paint(ci, "leaf", Rect2(tip + Vector2(-SPRIG_LEAF, -SPRIG_LEAF * 0.9), Vector2(SPRIG_LEAF, SPRIG_LEAF)), Pal.LEAF)
	Icons.paint(ci, "leaf", Rect2(tip + Vector2(SPRIG_LEAF * 0.9, -SPRIG_LEAF * 0.7), Vector2(-SPRIG_LEAF * 0.85, SPRIG_LEAF * 0.85)), Pal.LEAF_DEEP)

## The calendar's badge: a disc with a 1 on it, and it means nothing.
func _draw_badge(ci: Control) -> void:
	var r := BADGE * 0.5
	ci.draw_circle(Vector2(r, r), r, Pal.ACCENT_2)
	var font := CozyTheme.display(700)
	var sz := int(BADGE * 0.56)
	var w := font.get_string_size("1", HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
	ci.draw_string(font, Vector2(r - w * 0.5, r + sz * 0.36), "1",
		HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Pal.SURFACE)

## The entrance, and the idle the two characters keep afterwards.
func enter(delay: float, fade: float) -> void:
	Motion.appear(self, 0.0, 1.0, fade, delay)
	_sun.set_idle(true)
	_moon.set_idle(true)
