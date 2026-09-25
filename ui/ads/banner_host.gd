extends Control

## Invisible Godot-side companion for the native banner. The native provider
## owns the pixels; this node reserves the same bottom band in the game's
## layout and keeps it synchronized when an ad loads or fails. Off a phone,
## under a debug ADS_FAKE_BANNER run, it paints its own grey stand-in so a
## layout can be checked without a device.

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Ads.banner_changed.connect(_on_banner_changed)
	_on_banner_changed(Ads.is_banner_visible(), Ads.bottom_inset())

func _on_banner_changed(_visible: bool, _height: float) -> void:
	queue_redraw()

func _draw() -> void:
	var h := Ads.fake_height()
	if h <= 0.0:
		return
	var r := Rect2(0.0, size.y - h, size.x, h)
	draw_rect(r, Color(0.82, 0.82, 0.82))
	draw_string(get_theme_default_font(), r.position + Vector2(24.0, h * 0.62), "AD", HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color(0.4, 0.4, 0.4))
