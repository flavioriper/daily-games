extends RefCounted

## The phone's safe-area insets (top, bottom) in viewport units, for the
## screens that lay their chrome out from the edges: the menu and the puzzle
## host. Only phones report one that matters; the desktop's value describes
## the screen, not the window, so it reads as zero there -- except for a
## debug ADS_FAKE_BANNER run, where the desktop bottom inset is the fake
## banner's own design-pixel height, so the layout can be checked off a phone.

static func insets(control: Control) -> Vector2:
	var fake := Ads.fake_height() if Ads != null else 0.0
	if not OS.has_feature("mobile"):
		return Vector2(0.0, fake)
	var win := DisplayServer.window_get_size()
	if win.y <= 0:
		return Vector2.ZERO
	var safe := DisplayServer.get_display_safe_area()
	var k := control.get_viewport_rect().size.y / float(win.y)
	var top := maxf(0.0, float(safe.position.y)) * k
	var bottom := maxf(0.0, float(win.y - safe.end.y)) * k
	if Ads != null:
		bottom += (Ads.bottom_inset() * k) if fake == 0.0 else fake
	return Vector2(top, bottom)
