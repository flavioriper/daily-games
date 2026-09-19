extends Control

## The first screen's header: `Daily` lettered in ink with a golden sun for
## the dot of its i (ui/sun_dot.gd), the sprig growing out of the a beside
## it and the motto under; the sun and the moon sit beside it, with settings
## and calendar above them.
##
## The wordmark is a Label, not the extruded letters the campsite carried
## (legacy/ui/hud/title_view.gd): no SubViewport, no World3D, no TextMesh.
## The two characters are the board's own -- ui/faces/sun_face.gd and
## moon_face.gd, the pair Binairo is played with -- so the first screen and
## the first board are visibly one game. They idle: the rays turn once in
## forty seconds and the moon rocks, and the i's small sun turns with them
## and glints every few seconds (ui/sun_dot.gd), all stilled by
## reduce-motion like everything else.
##
## The entrance is one little sunrise rather than a fade over the finished
## header: the wordmark lifts into place, its sprig grows from the lettering,
## and the sun and moon rise a beat apart. The utility buttons stay quiet and
## simply scale into place. Once the pair has landed, its ordinary idle starts.
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
const SunDot = preload("res://ui/sun_dot.gd")
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
## The sprig over the wordmark grows out of the a -- the letter before the
## sun's i, where the Binairo lockup roots its own sprout (the A of BINAiRO)
## -- by the user's call on 2026-09-19 against rooting it in the sun. It
## stands on that letter's top: Fredoka 700's x-height, measured at 0.507 em,
## with the stem's foot sunk a few pixels into the ink so its flat end never
## leaves a sliver of paper against the bowl's curve. Then how tall the stem
## is and how big the leaves are.
const SPRIG_LETTER := 1
const X_HEIGHT_EM := 0.507
const SPRIG_SINK := 3.0
const SPRIG_RISE := 50.0
const SPRIG_LEAF := 58.0
const TITLE_TOP := 100.0
## The entrance is deliberately short enough that the day row can follow it
## without making the whole menu wait. Values are offsets from enter(delay).
const TITLE_LIFT := 18.0
const FACE_RISE := 34.0
const TITLE_TIME := 0.34
const BUTTON_TIME := 0.28
const SPRIG_TIME := 0.42
const SUN_TIME := 0.52
const MOON_TIME := 0.48
const TITLE_AT := 0.0
const BUTTON_AT := 0.04
const MOTTO_AT := 0.10
const SPRIG_AT_TIME := 0.12
const SUN_AT := 0.08
const MOON_AT := 0.17

var gear: Button
var calendar: Button
var _title: Label
var _motto: Label
var _title_block: VBoxContainer
var _sun_dot: SunDot
var _sprig: Control
var _sun: Control
var _moon: Control
var _sun_seat: Control
var _moon_seat: Control
var _entrance_tw: Tween
var _sprig_progress := 1.0:
	set(value):
		_sprig_progress = value
		if is_instance_valid(_sprig):
			_sprig.queue_redraw()

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
	_title_block = VBoxContainer.new()
	_title_block.name = "Title"
	_title_block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_block.add_theme_constant_override("separation", 0)
	_title_block.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_title_block.offset_top = TITLE_TOP
	add_child(_title_block)
	_title = Label.new()
	_title.theme_type_variation = "MenuWordmark"
	_title.text = TITLE
	_title_block.add_child(_title)
	_sun_dot = SunDot.new(_title)
	_title.add_child(_sun_dot)
	_motto = Label.new()
	_motto.theme_type_variation = "MenuMotto"
	_motto.text = MOTTO
	_title_block.add_child(_motto)
	_sprig = Control.new()
	_sprig.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sprig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sprig.draw.connect(_draw_sprig.bind(_sprig))
	add_child(_sprig)
	_title.resized.connect(_sprig.queue_redraw)

	# --- the two characters ---
	_sun_seat = _face_seat(SUN_SEAT)
	_sun = SunFace.new()
	_sun.size = Vector2(SUN_SEAT, SUN_SEAT)
	_sun_seat.add_child(_sun)
	_moon_seat = _face_seat(MOON_SEAT)
	_moon = MoonFace.new()
	_moon.rocks = true
	_moon.size = Vector2(MOON_SEAT, MOON_SEAT)
	_moon_seat.add_child(_moon)
	resized.connect(_place_pair)
	_place_pair()
	_set_entrance_final()

func _button(icon: String) -> Button:
	var b := IconButton.new(icon)
	b.custom_minimum_size = BUTTON
	b.size = BUTTON
	add_child(b)
	return b

func _face_seat(side: float) -> Control:
	var seat := Control.new()
	seat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	seat.size = Vector2(side, side)
	add_child(seat)
	return seat

## The pair hangs off the right edge, so a wider screen moves them out
## rather than stretching them.
func _place_pair() -> void:
	if _sun == null:
		return
	var right := size.x - PAIR_RIGHT
	_moon_seat.position = Vector2(right - MOON_SEAT, PAIR_TOP + (SUN_SEAT - MOON_SEAT) * 0.5 + 8.0)
	_sun_seat.position = Vector2(_moon_seat.position.x - SUN_SEAT * 0.62, PAIR_TOP)

## A stem out of the a with two leaves on it. Rooted on the letter's own
## bounds, so it follows the type wherever the label puts it.
func _draw_sprig(ci: Control) -> void:
	if _title == null or _title.size.x <= 0.0:
		return
	var box := _title.get_character_bounds(SPRIG_LETTER)
	if box.size.x <= 0.0:
		return
	var font := _title.get_theme_font("font")
	var font_size := _title.get_theme_font_size("font_size")
	var baseline := box.position.y + font.get_ascent(font_size)
	var base := _title.get_global_transform().origin - ci.get_global_transform().origin
	var root := base + Vector2(box.get_center().x, baseline - X_HEIGHT_EM * font_size + SPRIG_SINK)
	var tip := root + Vector2(4.0, -(SPRIG_RISE + SPRIG_SINK))
	var bend := root.lerp(tip, 0.45) + Vector2(2.0, 0.0)
	var stem_t := clampf(_sprig_progress / 0.58, 0.0, 1.0)
	var stem := PackedVector2Array([root])
	if stem_t <= 0.5:
		stem.append(root.lerp(bend, stem_t * 2.0))
	else:
		stem.append(bend)
		stem.append(bend.lerp(tip, (stem_t - 0.5) * 2.0))
	if stem.size() > 1:
		ci.draw_polyline(stem, Pal.LEAF, 10.0, true)
	# The leaf icon's base is at (0.15, 0.85) of its rect and its tip at the
	# opposite corner; a mirrored rect points it the other way. Each rect is
	# placed so that base lands on the stem's tip and the leaf grows up and
	# outward, as on the flat top bar (ui/flat/flat_top_bar.gd) and the sprout.
	var right := SPRIG_LEAF
	var left := SPRIG_LEAF * 0.85
	var right_t := _smoothstep(0.48, 0.86, _sprig_progress)
	var left_t := _smoothstep(0.62, 1.0, _sprig_progress)
	var anchor := tip + Vector2(0.0, 3.0)
	var right_size := right * right_t
	var left_size := left * left_t
	if right_size > 0.0:
		Icons.paint(ci, "leaf", Rect2(anchor + Vector2(-0.15 * right_size, -0.85 * right_size), Vector2(right_size, right_size)), Pal.LEAF)
	if left_size > 0.0:
		Icons.paint(ci, "leaf", Rect2(anchor + Vector2(0.15 * left_size, -0.85 * left_size), Vector2(-left_size, left_size)), Pal.LEAF_DEEP)

func _smoothstep(edge_a: float, edge_b: float, value: float) -> float:
	var t := clampf((value - edge_a) / (edge_b - edge_a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

## The calendar's badge: a disc with a 1 on it, and it means nothing.
func _draw_badge(ci: Control) -> void:
	var r := BADGE * 0.5
	ci.draw_circle(Vector2(r, r), r, Pal.ACCENT_2)
	var font := CozyTheme.display(700)
	var sz := int(BADGE * 0.56)
	var w := font.get_string_size("1", HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
	ci.draw_string(font, Vector2(r - w * 0.5, r + sz * 0.36), "1",
		HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Pal.SURFACE)

## The entrance, and the idle the two characters keep afterwards. The faces
## move inside fixed seats so a resize can still place the pair while the
## entrance is running without snapping either drawing out of its tween.
func enter(delay: float, fade: float) -> void:
	Motion.stop(_entrance_tw)
	_sun.set_idle(false)
	_moon.set_idle(false)
	_sun_dot.set_idle(false)
	modulate.a = 1.0
	if Motion.reduce:
		_set_entrance_final()
		return

	_title_block.position.y = TITLE_TOP + TITLE_LIFT
	_title.modulate.a = 0.0
	_motto.modulate.a = 0.0
	_sprig_progress = 0.0
	_prepare_button(gear)
	_prepare_button(calendar)
	_sun.position = Vector2(0.0, FACE_RISE)
	_sun.scale = Vector2.ONE * 0.76
	_sun.modulate.a = 0.0
	_sun.spin = -PI * 0.12
	_moon.position = Vector2(18.0, FACE_RISE)
	_moon.scale = Vector2.ONE * 0.82
	_moon.modulate.a = 0.0
	_moon.rock = -PI * 0.055

	# One parallel score keeps the individual beats related. `fade` still
	# controls the text's fade time as it did in the original entrance.
	var text_fade := maxf(fade, 0.18)
	_entrance_tw = create_tween().set_parallel(true)
	_entrance_tw.tween_property(_title_block, "position:y", TITLE_TOP, TITLE_TIME).set_delay(delay + TITLE_AT) \
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_entrance_tw.tween_property(_title, "modulate:a", 1.0, text_fade).set_delay(delay + TITLE_AT)
	_entrance_tw.tween_property(_motto, "modulate:a", 1.0, text_fade).set_delay(delay + MOTTO_AT)
	_scale_in(gear, delay + BUTTON_AT, BUTTON_TIME)
	_scale_in(calendar, delay + BUTTON_AT + 0.06, BUTTON_TIME)
	_entrance_tw.tween_property(self, "_sprig_progress", 1.0, SPRIG_TIME).set_delay(delay + SPRIG_AT_TIME) \
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_rise_face(_sun, Vector2.ZERO, delay + SUN_AT, SUN_TIME)
	_entrance_tw.tween_property(_sun, "spin", 0.0, SUN_TIME).set_delay(delay + SUN_AT) \
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_rise_face(_moon, Vector2.ZERO, delay + MOON_AT, MOON_TIME)
	_entrance_tw.tween_property(_moon, "rock", 0.0, MOON_TIME).set_delay(delay + MOON_AT) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_entrance_tw.chain().tween_callback(_start_idle)

func _prepare_button(button: Control) -> void:
	button.pivot_offset = button.size * 0.5
	button.scale = Vector2.ONE * 0.90
	button.modulate.a = 0.0

func _scale_in(node: Control, at: float, time: float) -> void:
	_entrance_tw.tween_property(node, "scale", Vector2.ONE, time).set_delay(at) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_entrance_tw.tween_property(node, "modulate:a", 1.0, time * 0.55).set_delay(at)

func _rise_face(face: Control, rest: Vector2, at: float, time: float) -> void:
	_entrance_tw.tween_property(face, "position", rest, time).set_delay(at) \
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_entrance_tw.tween_property(face, "scale", Vector2.ONE, time * 0.82).set_delay(at) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_entrance_tw.tween_property(face, "modulate:a", 1.0, time * 0.38).set_delay(at)

func _set_entrance_final() -> void:
	_title_block.position.y = TITLE_TOP
	_title.modulate.a = 1.0
	_motto.modulate.a = 1.0
	_sprig_progress = 1.0
	for button in [gear, calendar]:
		button.scale = Vector2.ONE
		button.modulate.a = 1.0
	_sun.position = Vector2.ZERO
	_sun.scale = Vector2.ONE
	_sun.modulate.a = 1.0
	_sun.spin = 0.0
	_moon.position = Vector2.ZERO
	_moon.scale = Vector2.ONE
	_moon.modulate.a = 1.0
	_moon.rock = 0.0

## Settings can change while the menu stays on screen. Still a running
## entrance and both idle loops immediately, or wake only the finished pair.
func refresh_motion(reduced: bool) -> void:
	Motion.stop(_entrance_tw)
	_sun.set_idle(false)
	_moon.set_idle(false)
	_sun_dot.set_idle(false)
	if reduced:
		_set_entrance_final()
	else:
		_start_idle()

func _start_idle() -> void:
	_sun.set_idle(true)
	_moon.set_idle(true)
	_sun_dot.set_idle(true)
