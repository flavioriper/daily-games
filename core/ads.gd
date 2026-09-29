extends Node

## The banner, and the consent that comes before it. The only file that
## touches the AdMob plugin (Poing's godot-admob-plugin): screens read
## bottom_inset() through ui/safe_area.gd and never see an ad object.
##
## start() runs from world/main.gd (and again once the age screen is
## answered), so tests and harnesses never ask for an ad. Order: nothing at
## all if remove_ads is owned; else the player's age must be known, then the
## request configuration it sets, then UMP consent (update, then the form when it is required), then MobileAds.initialize,
## then an anchored adaptive banner at the bottom. A consent update that fails
## still goes on to the ads: the SDK serves non-personalised ads without
## consent, and a stuck form must not mean a blank band for ever. On iOS the
## tracking prompt is UMP's IDFA message (set up in the AdMob console), shown
## by the same form; Info.plist carries its usage string.
##
## A debug run with ADS_FAKE_BANNER=<design px> reports a banner of that
## height on any platform, so layouts can be checked on the desktop;
## BannerHost paints a stand-in there.
## Spec: docs/superpowers/specs/2026-09-25-ads-and-remove-ads-design.md, section 3.

signal banner_changed(visible: bool, height: float)

const Analytics = preload("res://core/analytics.gd")
const AgeGate = preload("res://core/age_gate.gd")
## The "Remove ads" tab BannerHost stands on the banner's top edge, in design
## pixels whatever the banner's own unit: ui/safe_area.gd adds it to the
## bottom inset, unscaled, whenever a banner is up.
const TAB_H := 56.0
## Google's published test banners. A debug build (App Distribution, a
## harness) always asks for these, so only the release builds the stores
## carry ever request the real units in project.godot's ads/ keys: a click on
## a real ad from a debug build would count as invalid traffic.
const TEST_BANNER_ANDROID := "ca-app-pub-3940256099942544/9214589741"
const TEST_BANNER_IOS := "ca-app-pub-3940256099942544/2435281174"

var _ad_view: Object
var _banner_visible := false
var _banner_height := 0.0
var _started := false
var _removed := false
var _fake := 0.0

func _ready() -> void:
	if OS.is_debug_build():
		_fake = maxf(0.0, OS.get_environment("ADS_FAKE_BANNER").to_float())
	Store.owned_changed.connect(func(owned: bool) -> void:
		if owned:
			remove())

func start() -> void:
	if _started:
		return
	if Store.owns_remove_ads():
		_started = true
		_removed = true
		return
	if _fake > 0.0:
		_started = true
		_set_banner(true, _fake)
		return
	if not OS.has_feature("mobile") or not _plugin_present():
		return
	# Nothing is asked of the ad SDK before the player's age is known: the
	# age screen calls start() again once it is answered.
	if not AgeGate.known():
		return
	_started = true
	_configure_requests()
	_consent()

## Every request this app makes carries the player's band: a child is
## child-directed at rating G, a teen is under the age of consent, and
## neither is ever sent a personalised ad; everyone is capped at PG.
func _configure_requests() -> void:
	var b := AgeGate.band()
	var rc := RequestConfiguration.new()
	rc.max_ad_content_rating = RequestConfiguration.MAX_AD_CONTENT_RATING_G if b == AgeGate.CHILD \
		else RequestConfiguration.MAX_AD_CONTENT_RATING_PG
	rc.tag_for_child_directed_treatment = RequestConfiguration.TagForChildDirectedTreatment.TRUE \
		if b == AgeGate.CHILD else RequestConfiguration.TagForChildDirectedTreatment.UNSPECIFIED
	rc.tag_for_under_age_of_consent = RequestConfiguration.TagForUnderAgeOfConsent.TRUE \
		if b != AgeGate.ADULT else RequestConfiguration.TagForUnderAgeOfConsent.UNSPECIFIED
	MobileAds.set_request_configuration(rc)

## The one way an ad request is built here: non-personalised below 18.
func ad_request() -> AdRequest:
	var r := AdRequest.new()
	if AgeGate.band() != AgeGate.ADULT:
		r.extras = {"npa": "1"}
	return r

## FileAccess, not ResourceLoader: no resource loader recognises .cfg, so
## ResourceLoader.exists() answers false for it everywhere, and every launch
## stopped here before consent or a banner was ever asked for.
func _plugin_present() -> bool:
	return FileAccess.file_exists("res://addons/admob/plugin.cfg")

func _consent() -> void:
	var request := ConsentRequestParameters.new()
	request.tag_for_under_age_of_consent = AgeGate.band() != AgeGate.ADULT
	UserMessagingPlatform.consent_information.update(request, _on_consent_updated, func(error: FormError) -> void:
		Analytics.track("consent_failed", {"error": error.message if error else ""})
		_init_ads())

func _on_consent_updated() -> void:
	var info := UserMessagingPlatform.consent_information
	if info.get_consent_status() == info.ConsentStatus.REQUIRED and info.get_is_consent_form_available():
		UserMessagingPlatform.load_consent_form(func(form: ConsentForm) -> void:
			form.show(func(_error: FormError) -> void: _init_ads()),
			func(_error: FormError) -> void: _init_ads())
	else:
		_init_ads()

func _init_ads() -> void:
	if _removed:
		return
	var listener := OnInitializationCompleteListener.new()
	listener.on_initialization_complete = func(_status: InitializationStatus) -> void: _load_banner()
	MobileAds.initialize(listener)

func _load_banner() -> void:
	if _removed:
		return
	var ios := OS.get_name() == "iOS"
	var unit := str(ProjectSettings.get_setting("ads/banner_unit_id.ios" if ios else "ads/banner_unit_id.android", ""))
	if OS.is_debug_build():
		unit = TEST_BANNER_IOS if ios else TEST_BANNER_ANDROID
	if unit.is_empty():
		push_warning("Ads: no banner unit for this platform")
		return
	var size := AdSize.get_current_orientation_anchored_adaptive_banner_ad_size(AdSize.FULL_WIDTH)
	_ad_view = AdView.new(unit, size, AdPosition.BOTTOM)
	var listener := AdListener.new()
	listener.on_ad_loaded = func() -> void:
		if _removed:
			return
		_set_banner(true, float(_ad_view.get_height_in_pixels()))
		Analytics.track("ad_banner_loaded")
	listener.on_ad_failed_to_load = func(error: LoadAdError) -> void:
		_set_banner(false, 0.0)
		Analytics.track("ad_banner_failed", {"error": "%d %s" % [error.code, error.message]})
	listener.on_ad_impression = func() -> void: Analytics.track("ad_banner_impression")
	_ad_view.ad_listener = listener
	_ad_view.load_ad(ad_request())

## remove_ads was bought: the banner goes now and is never asked for again.
func remove() -> void:
	_removed = true
	if _ad_view != null:
		_ad_view.destroy()
		_ad_view = null
	_set_banner(false, 0.0)

func privacy_options_required() -> bool:
	if not OS.has_feature("mobile") or not _plugin_present():
		return false
	var info := UserMessagingPlatform.consent_information
	return info.get_privacy_options_requirement_status() == info.PrivacyOptionsRequirementStatus.REQUIRED

func show_privacy_options() -> void:
	if privacy_options_required():
		UserMessagingPlatform.show_privacy_options_form(func(_error: FormError) -> void: pass)

func is_banner_visible() -> bool:
	return _banner_visible

## Window pixels, the unit ui/safe_area.gd scales from. A fake banner is given
## in design pixels, so fake_height() is what the stand-in paints.
func bottom_inset() -> float:
	return _banner_height if _banner_visible else 0.0

func fake_height() -> float:
	return _fake if _banner_visible and _fake > 0.0 else 0.0

func _set_banner(visible: bool, height: float) -> void:
	var changed := _banner_visible != visible or not is_equal_approx(_banner_height, height)
	_banner_visible = visible
	_banner_height = height if visible else 0.0
	if changed:
		banner_changed.emit(_banner_visible, _banner_height)
