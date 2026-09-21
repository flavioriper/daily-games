extends Node

## Centralized banner-ad integration.
##
## The native bridge is intentionally optional. The project currently uses
## Godot's non-Gradle Android export and has no ads plugin installed, so the
## game must remain fully playable in the editor, desktop builds and CI. Once
## a compatible Google Mobile Ads Godot plugin is added, this adapter expects
## its singleton to expose initialize(), load_banner(), show_banner() and
## hide_banner(). Keeping that API here prevents screens from depending on a
## particular plugin.

signal banner_changed(visible: bool, height: float)

const Analytics = preload("res://core/analytics.gd")
const TEST_BANNER_UNIT := "ca-app-pub-3940256099942544/6300978111"
const DEFAULT_HEIGHT := 100.0

var _provider: Object
var _banner_visible := false
var _banner_height := 0.0
var _started := false

func _ready() -> void:
	_start()

func _start() -> void:
	if _started:
		return
	_started = true
	if not OS.has_feature("mobile"):
		return
	var singleton_name := str(ProjectSettings.get_setting("ads/provider_singleton", ""))
	if singleton_name.is_empty() or not Engine.has_singleton(singleton_name):
		return
	_provider = Engine.get_singleton(singleton_name)
	if _provider == null:
		return
	var app_id := str(ProjectSettings.get_setting("ads/app_id", ""))
	var unit_id := str(ProjectSettings.get_setting("ads/banner_unit_id", ""))
	if OS.is_debug_build() and unit_id.is_empty():
		unit_id = TEST_BANNER_UNIT
	if app_id.is_empty() or unit_id.is_empty():
		push_warning("Ads: native provider found, but app ID or banner unit ID is missing")
		return
	if _provider.has_signal("banner_loaded"):
		_provider.banner_loaded.connect(_on_banner_loaded)
	if _provider.has_signal("banner_failed"):
		_provider.banner_failed.connect(_on_banner_failed)
	if _provider.has_method("initialize"):
		_provider.initialize(app_id)
	if _provider.has_method("load_banner"):
		_provider.load_banner(unit_id)

func show_banner() -> void:
	if _provider == null or not _provider.has_method("show_banner"):
		return
	_provider.show_banner()
	_set_banner(true, _provider_banner_height())

func hide_banner() -> void:
	if _provider != null and _provider.has_method("hide_banner"):
		_provider.hide_banner()
	_set_banner(false, 0.0)

func is_banner_visible() -> bool:
	return _banner_visible

func bottom_inset() -> float:
	return _banner_height if _banner_visible else 0.0

func _on_banner_loaded(..._args: Array) -> void:
	show_banner()
	Analytics.track("ad_banner_loaded")

func _on_banner_failed(...args: Array) -> void:
	_set_banner(false, 0.0)
	Analytics.track("ad_banner_failed", {"error": str(args[0]) if not args.is_empty() else ""})

func _set_banner(visible: bool, height: float) -> void:
	var changed := _banner_visible != visible or not is_equal_approx(_banner_height, height)
	_banner_visible = visible
	_banner_height = height if visible else 0.0
	if changed:
		banner_changed.emit(_banner_visible, _banner_height)
		if visible:
			Analytics.track("ad_banner_impression")

func _provider_banner_height() -> float:
	if _provider != null and _provider.has_method("get_banner_height"):
		return maxf(0.0, float(_provider.get_banner_height()))
	return DEFAULT_HEIGHT
