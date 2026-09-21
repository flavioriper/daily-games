extends Control

## Invisible Godot-side companion for the native banner. The native provider
## owns the pixels; this node reserves the same bottom band in the game's
## layout and keeps it synchronized when an ad loads or fails.

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Ads.banner_changed.connect(_on_banner_changed)
	_on_banner_changed(Ads.is_banner_visible(), Ads.bottom_inset())

func _on_banner_changed(_visible: bool, _height: float) -> void:
	queue_redraw()
