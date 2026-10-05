extends Node

## The banner, and the consent that comes before it. The only file that
## touches the AdMob plugin (Poing's godot-admob-plugin): screens read
## bottom_inset() through ui/safe_area.gd and never see an ad object.
##
## start() runs from world/main.gd (and again once the age screen is
## answered), so tests and harnesses never ask for an ad. Order: the player's
## age must be known (an owner of remove_ads goes the same way: only the banner
## and the interstitial are dropped, the opt-in rewarded videos stay), then the
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
const Sound = preload("res://core/sound.gd")
const AdPacing = preload("res://core/ad_pacing.gd")
const Backend = preload("res://core/backend.gd")
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
const TEST_INTERSTITIAL_ANDROID := "ca-app-pub-3940256099942544/1033173712"
const TEST_INTERSTITIAL_IOS := "ca-app-pub-3940256099942544/4411468910"
const TEST_REWARDED_ANDROID := "ca-app-pub-3940256099942544/5224354917"
const TEST_REWARDED_IOS := "ca-app-pub-3940256099942544/1712485313"

## A rewarded video finished loading, was used, or ownership changed: open
## cards refresh their buttons.
signal rewards_changed

var _ad_view: Object
var _banner_visible := false
var _banner_height := 0.0
var _started := false
var _removed := false
var _fake := 0.0
var state_path := "user://ads.cfg"
var pacing := AdPacing.new()
var _interstitial: InterstitialAd
var _rewarded: RewardedAd
var _loading_interstitial := false
var _loading_rewarded := false
var _finished_pending := false
var _fake_full := ""   # "", "1" (always earns) or "skip" (never earns)
var _retry: Timer

func _ready() -> void:
	reload_state()
	if OS.is_debug_build():
		_fake = maxf(0.0, OS.get_environment("ADS_FAKE_BANNER").to_float())
		_fake_full = OS.get_environment("ADS_FAKE_FULL")
	_retry = Timer.new()
	_retry.one_shot = true
	_retry.wait_time = 60.0
	_retry.timeout.connect(func() -> void:
		_load_interstitial()
		_load_rewarded())
	add_child(_retry)
	Store.owned_changed.connect(func(owned: bool) -> void:
		if owned:
			remove()
		rewards_changed.emit())

func reload_state() -> void:
	var cfg := ConfigFile.new()
	cfg.load(state_path)
	for k: String in pacing.state:
		pacing.state[k] = cfg.get_value("pacing", k, pacing.state[k])

func _save_state() -> void:
	var cfg := ConfigFile.new()
	for k: String in pacing.state:
		cfg.set_value("pacing", k, pacing.state[k])
	cfg.save(state_path)

func start() -> void:
	if _started:
		return
	# An owner still starts the SDK: the opt-in videos stay. Only the banner
	# and the interstitial are dropped, by _removed.
	if Store.owns_remove_ads():
		_removed = true
	if _fake > 0.0 and not _removed:
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
	_fetch_remote()
	_configure_requests()
	_consent()

func _fetch_remote() -> void:
	var got: Dictionary = await Backend.config("ads")
	if got.ok:
		pacing.merge(got.data)

## Every request this app makes carries the player's band: a child is
## child-directed at rating G, a teen is under the age of consent, and
## neither is ever sent a personalised ad. A child is capped at G, a teen at
## PG, an adult at T: never MA, and PG for adults too was measured by AdMob
## at a third to two thirds of the revenue (2026-09-29).
func _configure_requests() -> void:
	var b := AgeGate.band()
	var rc := RequestConfiguration.new()
	match b:
		AgeGate.CHILD:
			rc.max_ad_content_rating = RequestConfiguration.MAX_AD_CONTENT_RATING_G
		AgeGate.ADULT:
			rc.max_ad_content_rating = RequestConfiguration.MAX_AD_CONTENT_RATING_T
		_:
			rc.max_ad_content_rating = RequestConfiguration.MAX_AD_CONTENT_RATING_PG
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
	UserMessagingPlatform.consent_information.update(request, _on_consent_updated, _on_consent_failed)

# Everything handed to the plugin from here to _on_ads_ready is a method, never
# a lambda: the plugin keeps these in static variables, which outlive this
# node and this script. A lambda that reads `self` points back at its script
# without holding it, and freeing one after the script is gone aborts: on
# iOS, where closing the app runs the engine's whole cleanup, every close was
# reported as a crash (TestFlight, builds 991 and 1000). A method Callable is
# an object id and a name, and frees to nothing.
func _on_consent_updated() -> void:
	var info := UserMessagingPlatform.consent_information
	if info.get_consent_status() == info.ConsentStatus.REQUIRED and info.get_is_consent_form_available():
		UserMessagingPlatform.load_consent_form(_on_consent_form, _on_consent_done)
	else:
		_init_ads()

func _on_consent_failed(error: FormError) -> void:
	Analytics.track("consent_failed", {"error": error.message if error else ""})
	_init_ads()

func _on_consent_form(form: ConsentForm) -> void:
	form.show(_on_consent_done)

func _on_consent_done(_error: FormError) -> void:
	_init_ads()

func _on_privacy_options_closed(_error: FormError) -> void:
	pass

func _init_ads() -> void:
	var listener := OnInitializationCompleteListener.new()
	listener.on_initialization_complete = _on_ads_ready
	MobileAds.initialize(listener)

func _on_ads_ready(_status: InitializationStatus) -> void:
	_load_banner()
	_load_interstitial()
	_load_rewarded()

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
	# The iOS plugin puts its native view on the window the moment it is
	# created, loaded or not, and an empty banner view still swallows every
	# touch in its band: with no fill the bottom of the screen went dead under
	# buttons laid out for no banner. It stays hidden until an ad is there.
	if ios:
		_ad_view.hide()
	var listener := AdListener.new()
	listener.on_ad_loaded = func() -> void:
		if _removed or _ad_view == null:
			return
		_ad_view.show()
		_set_banner(true, float(_ad_view.get_height_in_pixels()))
		Analytics.track("ad_banner_loaded")
	listener.on_ad_failed_to_load = func(error: LoadAdError) -> void:
		if _ad_view != null:
			_ad_view.hide()
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
	if _interstitial != null:
		_interstitial.destroy()
		_interstitial = null
	rewards_changed.emit()

func privacy_options_required() -> bool:
	if not OS.has_feature("mobile") or not _plugin_present():
		return false
	var info := UserMessagingPlatform.consent_information
	return info.get_privacy_options_requirement_status() == info.PrivacyOptionsRequirementStatus.REQUIRED

func show_privacy_options() -> void:
	if privacy_options_required():
		UserMessagingPlatform.show_privacy_options_form(_on_privacy_options_closed)

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

func _unit(kind: String) -> String:
	var ios := OS.get_name() == "iOS"
	if OS.is_debug_build():
		match kind:
			"interstitial": return TEST_INTERSTITIAL_IOS if ios else TEST_INTERSTITIAL_ANDROID
			"rewarded": return TEST_REWARDED_IOS if ios else TEST_REWARDED_ANDROID
	return str(ProjectSettings.get_setting("ads/%s_unit_id.%s" % [kind, "ios" if ios else "android"], ""))

func _retry_soon() -> void:
	if _retry != null and _retry.is_stopped():
		_retry.start()

func _load_interstitial() -> void:
	if _removed or _interstitial != null or _loading_interstitial or AgeGate.band() == AgeGate.CHILD:
		return
	var unit := _unit("interstitial")
	if unit.is_empty():
		return
	_loading_interstitial = true
	var cb := InterstitialAdLoadCallback.new()
	cb.on_ad_loaded = func(ad: InterstitialAd) -> void:
		_loading_interstitial = false
		_interstitial = ad
	cb.on_ad_failed_to_load = func(error: LoadAdError) -> void:
		_loading_interstitial = false
		Analytics.track("ad_load_failed", {"format": "interstitial", "error": "%d" % error.code})
		_retry_soon()
	InterstitialAdLoader.new().load(unit, ad_request(), cb)

func _load_rewarded() -> void:
	if _rewarded != null or _loading_rewarded:
		return
	var unit := _unit("rewarded")
	if unit.is_empty():
		return
	_loading_rewarded = true
	var cb := RewardedAdLoadCallback.new()
	cb.on_ad_loaded = func(ad: RewardedAd) -> void:
		_loading_rewarded = false
		_rewarded = ad
		rewards_changed.emit()
	cb.on_ad_failed_to_load = func(error: LoadAdError) -> void:
		_loading_rewarded = false
		Analytics.track("ad_load_failed", {"format": "rewarded", "error": "%d" % error.code})
		_retry_soon()
	RewardedAdLoader.new().load(unit, ad_request(), cb)

## A game (board, Arcade run, Versus game) ended.
func note_finished() -> void:
	pacing.note_finished(Daily.date_key())
	_finished_pending = true
	_save_state()

## The player just left a screen for the list: show the interstitial if a
## finished game earned one since the last call and pacing allows.
func leaving_game() -> void:
	if not _finished_pending:
		return
	_finished_pending = false
	if _removed:
		return
	var now := Time.get_unix_time_from_system()
	var today := Daily.date_key()
	var why := pacing.interstitial_verdict(now, today, Progress.hearts(today), AgeGate.band())
	if why.is_empty() and _interstitial == null and _fake_full.is_empty():
		why = "not_loaded"
		_load_interstitial()
	if not why.is_empty():
		Analytics.track("ad_interstitial_skipped", {"reason": why})
		return
	if not _fake_full.is_empty():
		_record_interstitial(now, today)
		_quiet(true)
		_fake_show("interstitial", func(_earned: bool) -> void: _quiet(false))
		return
	var ad := _interstitial
	_interstitial = null
	# Spent only once the ad is really up: a failed show costs nothing.
	ad.full_screen_content_callback.on_ad_showed_full_screen_content = func() -> void:
		_record_interstitial(now, today)
	ad.full_screen_content_callback.on_ad_dismissed_full_screen_content = func() -> void:
		_quiet(false)
		ad.destroy()
		_load_interstitial()
	ad.full_screen_content_callback.on_ad_failed_to_show_full_screen_content = func(_e: AdError) -> void:
		_quiet(false)
		Analytics.track("ad_interstitial_skipped", {"reason": "show_failed"})
		ad.destroy()
		_load_interstitial()
	_quiet(true)
	ad.show()

func _record_interstitial(now: float, today: int) -> void:
	pacing.note_interstitial(now, today)
	_save_state()
	Analytics.track("ad_interstitial_shown")

## Game sound off under a full-screen ad, back to the player's own Sound
## setting when it goes (never simply on).
func _quiet(on: bool) -> void:
	if on:
		AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)
	else:
		Sound.apply()

## Placements: "hint", "double", "continue", "heart" (Binairo), "hour" (Balance), "spool" (Untangle), "wish" (Word Trail) and "row" (Code
## Break). Opt-in, so owners keep them.
## Hints are unlimited: they neither count against nor stop at the daily cap,
## which is there for the videos that pay gold or keep a run alive.
func can_reward(placement: String) -> bool:
	if _capped(placement) and pacing.rewarded_left(Daily.date_key()) <= 0:
		return false
	if not _fake_full.is_empty():
		return true
	return _rewarded != null

## Analytics only: call once when a rewarded button is shown.
func offered(placement: String) -> void:
	Analytics.track("ad_rewarded_offered", {"placement": placement})

## done.call(earned) exactly once, after the ad is dismissed (or at once on a
## failure). The reward is recorded on the earned callback and handed to the
## game on dismissal, so the game never changes under the ad.
func show_rewarded(placement: String, done: Callable) -> void:
	var today := Daily.date_key()
	if _capped(placement) and pacing.rewarded_left(today) <= 0:
		_not_ready()
		done.call(false)
		return
	Analytics.track("ad_rewarded_started", {"placement": placement})
	var finish := func(earned: bool, shown: bool = true) -> void:
		_quiet(false)
		if earned:
			# A hint still spaces the next interstitial but is never counted.
			if _capped(placement):
				pacing.note_rewarded(Time.get_unix_time_from_system(), Daily.date_key())
			else:
				pacing.note_rewarded_seen(Time.get_unix_time_from_system())
			_save_state()
			Analytics.track("ad_rewarded_completed", {"placement": placement})
		elif shown:
			pacing.note_rewarded_seen(Time.get_unix_time_from_system())
			_save_state()
		else:
			_not_ready()
		_load_rewarded()
		rewards_changed.emit()
		done.call(earned)
	_quiet(true)
	if not _fake_full.is_empty():
		_fake_show("rewarded", finish)
		return
	if _rewarded == null:
		finish.call(false, false)
		return
	var ad := _rewarded
	_rewarded = null
	var earned := [false]
	ad.full_screen_content_callback.on_ad_dismissed_full_screen_content = func() -> void:
		ad.destroy()
		finish.call(earned[0])
	ad.full_screen_content_callback.on_ad_failed_to_show_full_screen_content = func(_e: AdError) -> void:
		ad.destroy()
		finish.call(false, false)
	var listener := OnUserEarnedRewardListener.new()
	listener.on_user_earned_reward = func(_item: RewardedItem) -> void: earned[0] = true
	ad.show(listener)

func _capped(placement: String) -> bool:
	return placement != "hint"

## No video was shown (none loaded, or today's are spent): say so for a
## moment, over whatever asked, so a tap is never met with silence.
func _not_ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	var label := Label.new()
	label.text = tr("AD_NOT_READY")
	label.add_theme_font_size_override("font_size", 34)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color(0.15, 0.13, 0.12))
	label.add_theme_constant_override("outline_size", 12)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(900, 0)
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 260)
	layer.add_child(label)
	add_child(layer)
	get_tree().create_timer(2.5).timeout.connect(layer.queue_free)

## ADS_FAKE_FULL (debug builds): a grey card saying which ad would be up,
## gone after 1.5 s. "skip" never earns, to check a video closed early.
func _fake_show(kind: String, then: Callable) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	var rect := ColorRect.new()
	rect.color = Color(0.3, 0.3, 0.3, 0.96)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var label := Label.new()
	label.text = "AD (%s)" % kind
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	rect.add_child(label)
	layer.add_child(rect)
	add_child(layer)
	get_tree().create_timer(1.5).timeout.connect(func() -> void:
		layer.queue_free()
		then.call(_fake_full != "skip"))
