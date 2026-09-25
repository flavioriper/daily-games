extends Control

## Invisible Godot-side companion for the native banner. The native provider
## owns the pixels; this node reserves the same bottom band in the game's
## layout and keeps it synchronized when an ad loads or fails. Off a phone,
## under a debug ADS_FAKE_BANNER run, it paints its own grey stand-in so a
## layout can be checked without a device.
##
## While a banner is up, a small paper "Remove ads" tab stands on its top
## edge (Ads.TAB_H tall, design px; ui/safe_area.gd reserves it with the
## banner), and a tap on it emits `tapped`: world/main.gd opens the purchase
## sheet from there. The host itself ignores input, so only the tab takes it.
## Spec: docs/superpowers/specs/2026-09-25-ads-and-remove-ads-design.md, section 4.

signal tapped

const CozyTheme = preload("res://ui/theme.gd")
const Pal = preload("res://core/palette.gd")

## The tab's lettering and padding, sized to stand inside TAB_H: the theme's
## IconButton (34 on a 24 margin) would be ~100 tall.
const TAB_FONT := 26
const TAB_PAD_X := 28
const TAB_RADIUS := 22

var tab: Button

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# A sibling of the screens, not their child, so it takes the theme itself.
	theme = CozyTheme.make()
	_build_tab()
	Ads.banner_changed.connect(_on_banner_changed)
	resized.connect(_place_tab)
	_on_banner_changed(Ads.is_banner_visible(), Ads.bottom_inset())

func _build_tab() -> void:
	tab = Button.new()
	tab.name = "Tab"
	tab.theme_type_variation = "IconButton"
	tab.text = "ADS_TAB"
	tab.focus_mode = Control.FOCUS_NONE
	tab.custom_minimum_size = Vector2(0.0, Ads.TAB_H)
	tab.add_theme_font_size_override("font_size", TAB_FONT)
	# A tab rather than a button: rounded on top, flat where it meets the band.
	for state in ["normal", "hover", "pressed", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Pal.SURFACE_HI if state != "pressed" else Pal.SURFACE_HI.lerp(Pal.LINE, 0.15)
		sb.corner_radius_top_left = TAB_RADIUS
		sb.corner_radius_top_right = TAB_RADIUS
		sb.content_margin_left = TAB_PAD_X
		sb.content_margin_right = TAB_PAD_X
		sb.content_margin_top = 0
		sb.content_margin_bottom = 0
		sb.border_width_top = 3
		sb.border_width_left = 3
		sb.border_width_right = 3
		sb.border_color = Pal.LINE
		sb.anti_aliasing = true
		tab.add_theme_stylebox_override(state, sb)
	tab.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	tab.grow_horizontal = Control.GROW_DIRECTION_BOTH
	tab.grow_vertical = Control.GROW_DIRECTION_BEGIN
	tab.pressed.connect(func() -> void: tapped.emit())
	tab.visible = false
	add_child(tab)
	# A language change re-letters the tab and changes its width.
	tab.minimum_size_changed.connect(_place_tab)

func _on_banner_changed(visible_: bool, _height: float) -> void:
	tab.visible = visible_
	_place_tab()
	queue_redraw()

## The tab's foot on the banner's top edge. The banner's height is design px
## when faked and window px when real, so a real one is scaled to the canvas.
func _place_tab() -> void:
	if tab == null:
		return
	var band := Ads.fake_height()
	if band <= 0.0:
		var win := DisplayServer.window_get_size()
		band = Ads.bottom_inset() * get_viewport_rect().size.y / float(win.y) if win.y > 0 else 0.0
	var w := tab.get_combined_minimum_size().x
	tab.offset_left = -w * 0.5
	tab.offset_right = w * 0.5
	tab.offset_bottom = -band
	tab.offset_top = -band - Ads.TAB_H

func _draw() -> void:
	var h := Ads.fake_height()
	if h <= 0.0:
		return
	var r := Rect2(0.0, size.y - h, size.x, h)
	draw_rect(r, Color(0.82, 0.82, 0.82))
	draw_string(get_theme_default_font(), r.position + Vector2(24.0, h * 0.62), "AD", HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color(0.4, 0.4, 0.4))
