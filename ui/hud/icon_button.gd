extends Button

## The HUD's one button: a vector icon from ui/icons.gd, an optional label to
## its right, an optional count badge at the top-right corner, and a squish on
## press. The look comes from the theme variation: IconButton (paper),
## PrimaryButton (sun) or DarkButton (slate).
## Spec: docs/superpowers/specs/2026-09-14-binairo-hud-design.md, sections 2 and 5.

const Icons = preload("res://ui/icons.gd")
const Motion = preload("res://core/motion.gd")
const Pal = preload("res://core/palette.gd")

const GLYPH := 44.0
const BADGE_R := 22.0
const SQUASH := 0.10
const SQUASH_TIME := 0.18

var icon_name := ""
var label_text := ""
## Count shown in the badge; 0 hides it.
var badge: int = 0:
	set(v):
		badge = v
		_refresh_badge()
## Where the badge rests; the top bar's bounce hops from here.
var badge_rest := Vector2.ZERO
var _press_tw: Tween
var _row: HBoxContainer
var _glyph: Control
var _label: Label
var _badge: Control
var _badge_label: Label

func _init(icon := "", label := "", variation := "IconButton") -> void:
	icon_name = icon
	label_text = label
	theme_type_variation = variation
	text = ""
	focus_mode = Control.FOCUS_NONE

func _ready() -> void:
	_row = HBoxContainer.new()
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", 14)
	_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_row)
	_glyph = Control.new()
	_glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glyph.custom_minimum_size = Vector2(GLYPH, GLYPH)
	_glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_glyph.draw.connect(_draw_glyph)
	_row.add_child(_glyph)
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.text = label_text
	_label.visible = label_text != ""
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_row.add_child(_label)
	_badge = Control.new()
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge.size = Vector2(BADGE_R * 2.0, BADGE_R * 2.0)
	_badge.draw.connect(_draw_badge)
	add_child(_badge)
	_badge_label = Label.new()
	_badge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge_label.theme_type_variation = "Badge"
	_badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_badge_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_badge.add_child(_badge_label)
	button_down.connect(squish)
	resized.connect(_layout)
	_apply_look()
	_fit_content()
	_refresh_badge()
	_layout()

func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED and _label != null:
		_apply_look()
		_fit_content()

## A Button measures only its own text, and this one keeps its text empty, so
## widen custom_minimum_size to the glyph-and-label row plus the stylebox
## padding: a labelled button never clips its label. A wider minimum set by
## the host stands. (Button's own C++ measure ignores a script
## _get_minimum_size, hence the custom minimum.)
func _fit_content() -> void:
	if _row == null:
		return
	var style := get_theme_stylebox("normal")
	var pad := style.get_minimum_size().x if style != null else 0.0
	custom_minimum_size.x = maxf(custom_minimum_size.x, _row.get_combined_minimum_size().x + pad)

## Enable or disable, dimming the icon and label with the theme's disabled colour.
func set_enabled(on: bool) -> void:
	disabled = not on
	_apply_look()

func set_label(text_: String) -> void:
	label_text = text_
	if _label != null:
		_label.text = text_
		_label.visible = text_ != ""
		_fit_content()

## The press squish: flatter and wider, then springs back. Restarts cleanly
## when mashed.
func squish() -> void:
	Motion.stop(_press_tw)
	scale = Vector2.ONE
	_press_tw = Motion.squash(self, SQUASH, SQUASH_TIME)

func badge_node() -> Control:
	return _badge

func _apply_look() -> void:
	if _label == null:
		return
	var colour := _ink()
	_label.add_theme_font_override("font", get_theme_font("font"))
	_label.add_theme_font_size_override("font_size", get_theme_font_size("font_size"))
	_label.add_theme_color_override("font_color", colour)
	_glyph.queue_redraw()

func _ink() -> Color:
	return get_theme_color("font_disabled_color") if disabled else get_theme_color("font_color")

func _layout() -> void:
	pivot_offset = size * 0.5
	badge_rest = Vector2(size.x - BADGE_R * 1.4, -BADGE_R * 0.6)
	if _badge != null:
		_badge.position = badge_rest

func _refresh_badge() -> void:
	if _badge == null:
		return
	_badge.visible = badge > 0
	_badge_label.text = str(badge)
	_badge.queue_redraw()

func _draw_glyph() -> void:
	var fill: Color = get_theme_stylebox("normal").bg_color if get_theme_stylebox("normal") is StyleBoxFlat else Color.TRANSPARENT
	Icons.paint(_glyph, icon_name, Rect2(Vector2.ZERO, _glyph.size), _ink(), fill)

func _draw_badge() -> void:
	_badge.draw_circle(Vector2(BADGE_R, BADGE_R), BADGE_R, Pal.WATER)
