# Ads and Remove Ads Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A consented AdMob banner on every screen, and a lifetime `remove_ads` purchase that removes it, reachable from a banner tab, a menu header button and settings.

**Architecture:** Two autoload adapters, `Ads` (`core/ads.gd`, exists) and `Store` (`core/store.gd`, new), are the only code that touches a plugin. Screens read `Ads.bottom_inset()` through `ui/safe_area.gd` (already wired) and talk to `Store` for the purchase. Off a phone both adapters are inert, with debug-only environment switches (`ADS_FAKE_BANNER`, `STORE_FAKE`) so every screen can be driven on this Mac.

**Tech Stack:** Godot 4.7 GDScript, Poing `godot-admob-plugin` v5.1.0, godot-iap 3.5.2, Gradle Android export, Xcode-project iOS export.

**Spec:** `docs/superpowers/specs/2026-09-25-ads-and-remove-ads-design.md` (read the Amendments, which override section 2).

## Global Constraints

- Product ID `remove_ads`, non-consumable, the same on both stores. No price in code; the price shown is the store's `display_price`.
- Test ad IDs only (spec amendment). Android app `ca-app-pub-3940256099942544~3347511713`, banner `ca-app-pub-3940256099942544/9214589741`; iOS app `ca-app-pub-3940256099942544~1458002511`, banner `ca-app-pub-3940256099942544/2435281174`.
- No ad request before UMP consent is settled; none at all while `remove_ads` is owned.
- The banner is never overlaid by Godot UI (AdMob policy): the tab sits above the ad, inside the reserved band.
- iOS minimum 17.0 (godot-iap).
- **No new suite tests** (user's standing rule): verification is throwaway probes under the session scratchpad, plus the existing suite (`godot --headless --script tests/run_tests.gd`) staying at 0 failures.
- Windowed harnesses: `--resolution 810x1440` **before** `--script`, `--always-on-top`, one at a time; commit `project.godot` before any windowed run and revert Godot's re-save afterwards.
- Every user-visible string is a key in `locale/ui.csv` (en, pt-BR, es).
- Screens never reference a plugin class; only `core/ads.gd` and `core/store.gd` do.

## Review Focus

1. **A sheet or overlay anchored to the bottom while a banner shows**: the native ad draws over Godot, so the sheet's Close / Buy button must sit above it. Task 5 sweeps every bottom-anchored node with the fake banner.
2. **Offline launch of an owner**: `Store` must keep `owned` from `user://store.cfg` when the store query fails, and clear it only on a *successful* query that lacks `remove_ads`. Task 2's probe covers both.
3. **Buying twice / tapping Buy during a pending purchase**: `buy()` is ignored while one is in flight, and a pending Play purchase is not owned. Task 2.
4. **Owning mid-session on a board**: the banner, the tab and the inset go at once and the board re-lays out; the header button hides when the menu is back. Task 4 probe.
5. **Consent failure or no network**: UMP `update` failing must still let ads load (non-personalised by SDK default) rather than blocking forever. Task 3.

---

### Task 1: Install both plugins and prove they build on 4.7

This is the spec's spike. **If either plugin will not export on 4.7, stop and report to the user**; do not pick a replacement.

**Files:**
- Create: `addons/admob/**` (Poing v5.1.0), `addons/godot-iap/**` (3.5.2), `tools/export_ios.sh`
- Modify: `project.godot` (`[editor_plugins]`, `[autoload]`, AdMob settings), `export_presets.cfg` (iOS min version, plist, iOS/Android plugin options), `tools/strip_dev_addons.sh`

- [ ] **Step 1: Download and unpack.**
```bash
cd /Users/flavioriper/dev/daily
S=/private/tmp/claude-501/-Users-flavioriper-dev-daily/64aaa3f2-2268-4edf-b450-0c2f01ea5666/scratchpad
curl -L -o $S/admob.zip https://github.com/poingstudios/godot-admob-plugin/releases/download/v5.1.0/poing-godot-admob-v5.1.0.zip
unzip -o $S/admob.zip -d $S/admob && ls $S/admob
# godot-iap: release asset of hyodotdev/openiap tag godot-iap-3.5.2
gh release view godot-iap-3.5.2 -R hyodotdev/openiap --json assets -q '.assets[].name'
gh release download godot-iap-3.5.2 -R hyodotdev/openiap -p 'godot-iap-3.5.2.zip' -D $S
unzip -o $S/godot-iap-3.5.2.zip -d $S/iap && ls -R $S/iap | head -40
```
Copy each so the result is `addons/admob/plugin.cfg` and `addons/godot-iap/plugin.cfg`. If asset names differ, list the release assets and pick the plugin zip, not the source zip.

- [ ] **Step 2: Native libraries for AdMob.** Poing downloads them when the plugin is enabled in the editor. Enable both plugins headless-safely by editing `project.godot`:
```
[editor_plugins]

enabled=PackedStringArray("res://addons/godot_mcp/plugin.cfg", "res://addons/admob/plugin.cfg", "res://addons/godot-iap/plugin.cfg")
```
then run `godot --headless --editor --quit-after 200 --path .` and check `ls addons/admob/android/bin addons/admob/ios/bin`. If the libraries did not arrive, open the editor once (`godot -e --path .`) and use Project → Tools → AdMob Manager → Android / iOS → Download & Install (ask the user to click it if you cannot drive the editor through the godot MCP). The files must be committed: CI never runs the editor. Record their total size (`du -sh addons/admob addons/godot-iap`) for the report.

- [ ] **Step 3: Keep godot-iap's iOS-only GDExtension quiet.**
```bash
mv addons/godot-iap/bin/godot_iap.gdextension addons/godot-iap/bin/godot_iap.gdextension.disabled
```
(Use the actual path: `find addons/godot-iap -name '*.gdextension'`.) Confirm the autoload the plugin registered: `grep -n GodotIapPlugin project.godot`. If the plugin did not add it on the headless run, add under `[autoload]`: `GodotIapPlugin="*res://addons/godot-iap/<path of godot_iap.gd>"`. Record the path of `types.gd` (`find addons/godot-iap -name types.gd`) for Task 2.

- [ ] **Step 4: AdMob project settings.** Read the setting names from the plugin (`grep -rn "admob/" addons/admob --include=*.gd | grep -i "app_id\|enabled" | head`) and set in `project.godot` Android and iOS **Enabled = true** and **App Id** to the test app IDs from Global Constraints. Add our own adapter settings under `[ads]`:
```
[ads]

banner_unit_id.android="ca-app-pub-3940256099942544/9214589741"
banner_unit_id.ios="ca-app-pub-3940256099942544/2435281174"
```
Delete the stale `ads/provider_singleton` and `ads/app_id` if present (`grep -n "^ads/\|^\[ads\]" project.godot`).

- [ ] **Step 5: iOS preset.** In `export_presets.cfg` under the iOS preset's `[preset.1.options]`: `application/min_ios_version="17.0"`, and add to `application/additional_plist_content` (check the key name with `grep -n plist export_presets.cfg`; Godot 4.7's iOS exporter calls it `application/additional_plist_content`):
```
<key>NSUserTrackingUsageDescription</key><string>This lets us show you ads that are more relevant. The game works the same either way.</string>
```

- [ ] **Step 6: `tools/strip_dev_addons.sh` must survive a multi-plugin list.** Replace the `enabled=` deletion with removal of just the godot_mcp entry:
```bash
perl -ni -e 'print unless /^MCPGameBridge=/' project.godot
perl -pi -e 's{"res://addons/godot_mcp/plugin\.cfg",\s*}{}; s{,\s*"res://addons/godot_mcp/plugin\.cfg"}{}; s{^enabled=PackedStringArray\("res://addons/godot_mcp/plugin\.cfg"\)\n}{}' project.godot
```
Keep the existing `exclude_filter` edit and the final grep check. Verify on a scratch copy: `cp project.godot $S/p.godot && tools/strip_dev_addons.sh && grep -n editor_plugins -A2 project.godot; git checkout project.godot export_presets.cfg`. Expected: admob and godot-iap entries remain, godot_mcp gone, script prints "stripped".

- [ ] **Step 7: `tools/export_ios.sh`.**
```bash
#!/usr/bin/env bash
# Exports the iOS Xcode project with godot-iap's GDExtension switched on (it
# is iOS-only and stays .disabled everywhere else), then embeds its frameworks.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
ext=$(find addons/godot-iap -name 'godot_iap.gdextension.disabled' | head -1)
on="${ext%.disabled}"
out=build/ios
mkdir -p "$out"
mv "$ext" "$on"
trap 'mv "$on" "$ext"' EXIT
godot --headless --path . --export-debug iOS "$out/peeplet-daily.ipa"
IOS_EXPORT_DIR="$(pwd)/$out" "$(dirname "$on")/../scripts/fix_ios_embed.sh"
```
(Adjust the `fix_ios_embed.sh` path to where it actually is: `find addons/godot-iap -name fix_ios_embed.sh`.) `chmod +x`. It will stop on the empty Team ID: that is the user's, and a stop there with "team" in the error still counts as reaching the exporter. If Godot refuses earlier because of either plugin, that is a Task 1 failure to report.

- [ ] **Step 8: Build the Android APK.**
```bash
cp project.godot $S/project.godot.bak; cp export_presets.cfg $S/presets.bak
tools/strip_dev_addons.sh
godot --headless --path . --install-android-build-template --export-debug Android $S/test.apk 2>&1 | tail -40
cp $S/project.godot.bak project.godot; cp $S/presets.bak export_presets.cfg
unzip -l $S/test.apk | grep -i "gms\|ads\|openiap\|GodotIap" | head
$ANDROID_HOME/build-tools/*/aapt2 dump xmltree $S/test.apk --file AndroidManifest.xml | grep -A1 APPLICATION_ID
```
Expected: export succeeds; the manifest carries `com.google.android.gms.ads.APPLICATION_ID` with the test app ID. (If `ANDROID_HOME` is unset, the SDK is at `/opt/homebrew/share/android-commandlinetools`.)

- [ ] **Step 9: Suite and editor load stay clean.** `godot --headless --path . --script tests/run_tests.gd 2>&1 | tail -5` → `failed=0`. `godot --headless --path . --quit 2>&1 | grep -i "error" | head` → no new errors from either addon (note any, and whether they are the missing-native warnings that are expected off a phone).

- [ ] **Step 10: Commit.**
```bash
git add addons/admob addons/godot-iap project.godot export_presets.cfg tools/strip_dev_addons.sh tools/export_ios.sh
git commit -m "build: Poing AdMob 5.1.0 and godot-iap 3.5.2, test IDs, iOS 17"
```
Report: sizes, Android export result, iOS export result, and anything the plugins did that the plan did not expect.

---

### Task 2: `core/store.gd`, the purchase adapter

**Files:**
- Create: `core/store.gd`
- Modify: `project.godot` `[autoload]` (add `Store="*res://core/store.gd"` **before** `Ads`)

**Interfaces:**
- Consumes: the `GodotIapPlugin` autoload and `types.gd` path from Task 1.
- Produces (autoload `Store`):
  - `signal owned_changed(owned: bool)`, `signal purchase_failed(reason: String)`, `signal price_ready`, `signal busy_changed(busy: bool)`
  - `const PRODUCT := "remove_ads"`
  - `func owns_remove_ads() -> bool`, `func available() -> bool`, `func price_text() -> String`, `func is_busy() -> bool`, `func buy() -> void`, `func restore() -> void`

- [ ] **Step 1: Write `core/store.gd`.** (Replace `TYPES_PATH` with the path recorded in Task 1.)
```gdscript
extends Node

## The one door to the store: owns `remove_ads` or not, its price, buy and
## restore. Screens use this and never godot-iap, the rule core/ads.gd keeps
## for ads. The owned flag is saved in user://store.cfg so it holds offline,
## and it is checked against the store on every launch, so a refund clears it
## -- but only on a query that succeeded: offline is not a refund.
## Off a phone there is no store: available() is false and buy() fails with
## "unavailable". A debug build run with STORE_FAKE=1 buys and restores at
## once, so the flow can be walked on the desktop.
## Spec: docs/superpowers/specs/2026-09-25-ads-and-remove-ads-design.md, section 3.

signal owned_changed(owned: bool)
signal purchase_failed(reason: String)
signal price_ready
signal busy_changed(busy: bool)

const Analytics = preload("res://core/analytics.gd")
const PRODUCT := "remove_ads"
const TYPES_PATH := "res://addons/godot-iap/types.gd"
static var save_path := "user://store.cfg"

var _iap: Node
var _types: Script
var _owned := false
var _price := ""
var _busy := false
var _fake := false

func _ready() -> void:
	_owned = _load_owned()
	_fake = OS.is_debug_build() and OS.get_environment("STORE_FAKE") == "1"
	if _fake:
		_price = "$1.99"
		return
	if not OS.has_feature("mobile"):
		return
	_iap = get_node_or_null("/root/GodotIapPlugin")
	if _iap == null or not ResourceLoader.exists(TYPES_PATH):
		_iap = null
		return
	_types = load(TYPES_PATH)
	_iap.purchase_updated.connect(_on_purchase_updated)
	_iap.purchase_error.connect(_on_purchase_error)
	_connect.call_deferred()

func owns_remove_ads() -> bool:
	return _owned

func available() -> bool:
	return _fake or _iap != null

func price_text() -> String:
	return _price

func is_busy() -> bool:
	return _busy

func buy() -> void:
	if _busy or _owned:
		return
	Analytics.track("purchase_started", {"product": PRODUCT})
	if _fake:
		_set_owned(true)
		Analytics.track("purchase_complete", {"product": PRODUCT})
		return
	if _iap == null:
		_fail("unavailable")
		return
	_set_busy(true)
	var platforms = _types.RequestPurchasePropsByPlatforms.new()
	platforms.apple = _types.RequestPurchaseIosProps.new()
	platforms.apple.sku = PRODUCT
	platforms.google = _types.RequestPurchaseAndroidProps.new()
	platforms.google.skus = [PRODUCT] as Array[String]
	await _iap.request_purchase(_types.RequestPurchaseProps.in_app(platforms))
	# The outcome arrives on purchase_updated or purchase_error.

func restore() -> void:
	if _busy:
		return
	if _fake:
		_set_owned(true)
		Analytics.track("restore_used", {"found": true})
		return
	if _iap == null:
		_fail("unavailable")
		return
	_set_busy(true)
	if _iap.has_method("restore_purchases"):
		await _iap.restore_purchases()
	var found := await _sync_owned()
	_set_busy(false)
	Analytics.track("restore_used", {"found": found})
	if not found:
		_fail("nothing_to_restore")

func _connect() -> void:
	if not await _iap.init_connection():
		return
	var request = _types.ProductRequest.new()
	request.skus = [PRODUCT] as Array[String]
	request.type = _types.ProductQueryType.IN_APP
	var products: Array = await _iap.fetch_products(request)
	for p in products:
		if String(p.id) == PRODUCT:
			_price = String(p.display_price)
			price_ready.emit()
	await _sync_owned()

## Reads the store's current purchases. Returns whether remove_ads is among
## them; clears the flag only when the query itself succeeded.
func _sync_owned() -> bool:
	var result: Dictionary = await _iap.get_available_purchases_result()
	if not result.get("success", false):
		return _owned
	var found := false
	for p in result.get("purchases", []):
		var d: Dictionary = p if p is Dictionary else p.to_dict()
		if String(d.get("productId", "")) == PRODUCT and String(d.get("purchaseState", "purchased")) == "purchased":
			found = true
			await _iap.finish_transaction_dict(d, false)
	_set_owned(found)
	return found

func _on_purchase_updated(purchase: Dictionary) -> void:
	if String(purchase.get("productId", "")) != PRODUCT:
		return
	match String(purchase.get("purchaseState", "")):
		"purchased":
			# Acknowledge at once: Play refunds anything left unacknowledged
			# for three days, and StoreKit replays an unfinished transaction.
			await _iap.finish_transaction_dict(purchase, false)
			_set_busy(false)
			_set_owned(true)
			Analytics.track("purchase_complete", {"product": PRODUCT})
		"pending":
			# Play's slow payment methods: not owned until it completes.
			_set_busy(false)
			_fail("pending")

func _on_purchase_error(error: Dictionary) -> void:
	_set_busy(false)
	_fail(String(error.get("code", "unknown")))

func _fail(reason: String) -> void:
	Analytics.track("purchase_failed", {"reason": reason})
	purchase_failed.emit(reason)

func _set_busy(value: bool) -> void:
	if _busy != value:
		_busy = value
		busy_changed.emit(value)

func _set_owned(value: bool) -> void:
	if _owned == value:
		return
	_owned = value
	var cfg := ConfigFile.new()
	cfg.set_value("store", PRODUCT, value)
	cfg.save(save_path)
	owned_changed.emit(value)

func _load_owned() -> bool:
	var cfg := ConfigFile.new()
	return cfg.load(save_path) == OK and bool(cfg.get_value("store", PRODUCT, false))
```
Check every godot-iap call name against `godot_iap.gd` before running (`grep -n "^func \|^signal" <path>/godot_iap.gd`); the research read 3.5.2's source, but trust the file in the tree.

- [ ] **Step 2: Register the autoload** before `Ads` in `project.godot`:
```
Store="*res://core/store.gd"
Ads="*res://core/ads.gd"
```

- [ ] **Step 3: Probe (throwaway, in the scratchpad).** `$S/probe_store.gd`:
```gdscript
extends SceneTree
var frame := 0
func _process(_d: float) -> bool:
	frame += 1
	if frame < 3:
		return false
	var store = root.get_node("Store")
	print("available=", store.available(), " owned=", store.owns_remove_ads(), " price=", store.price_text())
	var failed := []
	store.purchase_failed.connect(func(r): failed.append(r))
	store.buy()
	print("after buy owned=", store.owns_remove_ads(), " failed=", failed)
	return true
```
Run three times, each from the repo root:
```bash
rm -f ~/Library/Application\ Support/Godot/app_userdata/Peeplet\ Daily/store.cfg
godot --headless --path . --script $S/probe_store.gd            # expect available=false owned=false; failed=["unavailable"]
STORE_FAKE=1 godot --headless --path . --script $S/probe_store.gd  # expect available=true price=$1.99; after buy owned=true
godot --headless --path . --script $S/probe_store.gd            # expect owned=true (persisted, no store = no clearing)
```
Confirm the userdata folder name with `ls ~/Library/Application\ Support/Godot/app_userdata/`. Delete `store.cfg` afterwards so later probes start clean.

- [ ] **Step 4: Suite** → `failed=0`. **Commit:** `git add core/store.gd core/store.gd.uid project.godot && git commit -m "feat(store): remove_ads through godot-iap, saved on the device"`

---

### Task 3: `core/ads.gd` on Poing, with consent and the fake banner

**Files:**
- Modify: `core/ads.gd` (rewrite), `ui/safe_area.gd`, `ui/ads/banner_host.gd`, `world/main.gd:29`

**Interfaces:**
- Consumes: `Store.owns_remove_ads()`, `Store.owned_changed`.
- Produces (autoload `Ads`, existing names kept): `signal banner_changed(visible: bool, height: float)`, `is_banner_visible() -> bool`, `bottom_inset() -> float` (window pixels, as before), plus new `start() -> void`, `remove() -> void`, `privacy_options_required() -> bool`, `show_privacy_options() -> void`, `fake_height() -> float` (design px, 0 unless faked). `show_banner()` is removed; `world/main.gd` calls `Ads.start()`.

- [ ] **Step 1: Rewrite `core/ads.gd`.**
```gdscript
extends Node

## The banner, and the consent that comes before it. The only file that
## touches the AdMob plugin (Poing's godot-admob-plugin): screens read
## bottom_inset() through ui/safe_area.gd and never see an ad object.
##
## start() runs once from world/main.gd, so tests and harnesses never ask for
## an ad. Order: nothing at all if remove_ads is owned; else UMP consent
## (update, then the form when it is required), then MobileAds.initialize,
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
	_started = true
	if Store.owns_remove_ads():
		_removed = true
		return
	if _fake > 0.0:
		_set_banner(true, _fake)
		return
	if not OS.has_feature("mobile") or not ClassDB.class_exists("MobileAds") and not _plugin_present():
		return
	_consent()

func _plugin_present() -> bool:
	return ResourceLoader.exists("res://addons/admob/plugin.cfg")

func _consent() -> void:
	var request := ConsentRequestParameters.new()
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
	var key := "ads/banner_unit_id.ios" if OS.get_name() == "iOS" else "ads/banner_unit_id.android"
	var unit := str(ProjectSettings.get_setting(key, ""))
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
	_ad_view.load_ad(AdRequest.new())

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
```
Fix the `start()` guard to one clear condition once you know whether Poing's classes are GDScript `class_name`s (they are: `addons/admob/gdscript/src/**`), which makes them resolvable on every platform: then the guard is simply `if not OS.has_feature("mobile") or not _plugin_present(): return`. Delete `ClassDB.class_exists` from it.

- [ ] **Step 2: `ui/safe_area.gd`** adds the fake banner off a phone (design px, unscaled) and the real one on a phone:
```gdscript
static func insets(control: Control) -> Vector2:
	var fake := Ads.fake_height() if Ads != null else 0.0
	if not OS.has_feature("mobile"):
		return Vector2(0.0, fake)
	...existing body...
	if Ads != null:
		bottom += (Ads.bottom_inset() * k) if fake == 0.0 else fake
	return Vector2(top, bottom)
```

- [ ] **Step 3: `ui/ads/banner_host.gd`** paints the stand-in when faked (a flat grey band with "AD" so shots read true):
```gdscript
func _draw() -> void:
	var h := Ads.fake_height()
	if h <= 0.0:
		return
	var r := Rect2(0.0, size.y - h, size.x, h)
	draw_rect(r, Color(0.82, 0.82, 0.82))
	draw_string(get_theme_default_font(), r.position + Vector2(24.0, h * 0.62), "AD", HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color(0.4, 0.4, 0.4))
```

- [ ] **Step 4: `world/main.gd`** line 29: `Ads.show_banner()` → `Ads.start()`.

- [ ] **Step 5: Probe.** Headless: `godot --headless --path . --quit` has no errors from `core/ads.gd`. Windowed, one run: `ADS_FAKE_BANNER=150 godot --resolution 810x1440 --always-on-top --path . world/main.tscn` then screenshot via a `_shot_menu.gd` run with the same env (`ADS_FAKE_BANNER=150 godot --resolution 810x1440 --always-on-top --path . --script tests/_shot_menu.gd`); crop `/tmp/shot_menu_1.png` bottom with PIL. Expected: grey band at the bottom, the bottom bar sitting above it, pager above the bar. Then `STORE_FAKE=1` plus a pre-seeded owned `store.cfg` → no band.

- [ ] **Step 6: Suite** → `failed=0`. Revert Godot's `project.godot` re-save if any. **Commit:** `git commit -am "feat(ads): Poing banner behind UMP consent, gone once remove_ads is owned"`

---

### Task 4: The three doors and the purchase sheet

**Files:**
- Create: `ui/hud/remove_ads_sheet.gd`
- Modify: `ui/icons.gd` (new `no_ads` icon), `ui/menu/menu_header.gd` (third button + `remove_ads` signal), `ui/menu.gd` (own the sheet, wire header + banner tab), `ui/puzzle_host.gd` (own the sheet, wire banner tab), `ui/hud/settings_sheet.gd` (three rows), `ui/ads/banner_host.gd` (tab), `core/ads.gd` (`TAB_H` in the inset), `locale/ui.csv`

**Interfaces:**
- Consumes: `Store.*`, `Ads.banner_changed`, `Ads.privacy_options_required()`, `Ads.show_privacy_options()`.
- Produces: `RemoveAdsSheet` (`extends "res://ui/hud/sheet.gd"`, `func open_from(door: String) -> void`); `MenuHeader.signal remove_ads`; `SettingsSheet.signal remove_ads`; `BannerHost.signal tapped`; `const Ads.TAB_H := 56.0` (design px).

- [ ] **Step 1: Strings** appended to `locale/ui.csv` (keep the file's CSV quoting):
```
ADS_TAB,Remove ads,Remover anúncios,Quitar anuncios
STORE_TITLE,No more ads,Sem anúncios,Sin anuncios
STORE_BODY,"One purchase, for good. Every puzzle stays free, and the banner never comes back.","Uma compra, para sempre. Todos os puzzles continuam grátis e o banner nunca mais volta.","Una compra, para siempre. Todos los puzles siguen gratis y el banner no vuelve nunca."
STORE_BUY,Remove ads · %s,Remover anúncios · %s,Quitar anuncios · %s
STORE_BUY_NO_PRICE,Remove ads,Remover anúncios,Quitar anuncios
STORE_UNAVAILABLE,Not available here,Indisponível aqui,No disponible aquí
STORE_RESTORE,Restore purchases,Restaurar compras,Restaurar compras
STORE_THANKS,Thank you! The ads are gone.,Obrigado! Os anúncios sumiram.,¡Gracias! Los anuncios se han ido.
STORE_OWNED,Ads removed,Anúncios removidos,Anuncios quitados
STORE_FAIL,The purchase didn't go through.,A compra não foi concluída.,La compra no se completó.
STORE_PENDING,Waiting for the payment to clear.,Aguardando o pagamento ser confirmado.,Esperando a que se confirme el pago.
STORE_NOTHING,No purchase to restore on this account.,Nenhuma compra para restaurar nesta conta.,No hay compras que restaurar en esta cuenta.
SETTINGS_PRIVACY,Privacy choices,Opções de privacidade,Opciones de privacidad
```
A cancelled purchase (`user-cancelled`) shows nothing.

- [ ] **Step 2: `ui/icons.gd`**: add `"no_ads"` to `NAMES` and a branch returning a rounded rectangle outline (the ad) crossed by one diagonal line:
```gdscript
		"no_ads":
			return {"polys": [], "lines": [
				PackedVector2Array([Vector2(0.18, 0.3), Vector2(0.82, 0.3), Vector2(0.82, 0.7), Vector2(0.18, 0.7), Vector2(0.18, 0.3)]),
				PackedVector2Array([Vector2(0.22, 0.82), Vector2(0.78, 0.18)])]}
```

- [ ] **Step 3: `ui/hud/remove_ads_sheet.gd`.**
```gdscript
extends "res://ui/hud/sheet.gd"

## The purchase sheet: what remove_ads buys, the store's own price on Buy,
## Restore, and a thank-you once it is owned. The banner tab, the menu
## header and settings all open this one sheet (open_from names which, for
## analytics). A failure is a line on the sheet, never a silence; a
## cancelled purchase says nothing.
## Spec: docs/superpowers/specs/2026-09-25-ads-and-remove-ads-design.md, section 4.

const Analytics = preload("res://core/analytics.gd")

var buy_button: Button
var restore_button: Button
var close_button: Button
var _body: Label
var _note: Label

func _card_style() -> StyleBox:
	return CozyTheme.parchment_card()

func _build_sheet(col: VBoxContainer) -> void:
	var title := Label.new()
	title.theme_type_variation = "SheetTitle"
	title.text = "STORE_TITLE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	_body = Label.new()
	_body.theme_type_variation = "SheetBody"
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_body)
	_note = Label.new()
	_note.theme_type_variation = "SheetBodyDim"
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_note)
	buy_button = IconButton.new("no_ads", "STORE_BUY_NO_PRICE", "PrimaryButton")
	buy_button.custom_minimum_size.y = ROW
	buy_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	buy_button.pressed.connect(func() -> void: Store.buy())
	col.add_child(buy_button)
	restore_button = IconButton.new("reset", "STORE_RESTORE", "IconButton")
	restore_button.custom_minimum_size.y = ROW
	restore_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	restore_button.pressed.connect(func() -> void: Store.restore())
	col.add_child(restore_button)
	close_button = IconButton.new("check", "BTN_CLOSE", "IconButton")
	close_button.custom_minimum_size.y = ROW
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_button.pressed.connect(close)
	col.add_child(close_button)
	Store.owned_changed.connect(func(_o: bool) -> void: _refresh())
	Store.price_ready.connect(_refresh)
	Store.busy_changed.connect(func(_b: bool) -> void: _refresh())
	Store.purchase_failed.connect(_on_failed)

func open_from(door: String) -> void:
	Analytics.track("store_opened", {"door": door})
	open()

func _on_open() -> void:
	_note.text = ""
	_refresh()

func _refresh() -> void:
	if _body == null:
		return
	var owned := Store.owns_remove_ads()
	_body.text = tr("STORE_THANKS") if owned else tr("STORE_BODY")
	buy_button.visible = not owned
	restore_button.visible = not owned
	var price := Store.price_text()
	if not Store.available():
		buy_button.text = tr("STORE_UNAVAILABLE")
	elif price.is_empty():
		buy_button.text = tr("STORE_BUY_NO_PRICE")
	else:
		buy_button.text = tr("STORE_BUY") % price
	buy_button.disabled = not Store.available() or Store.is_busy()
	restore_button.disabled = not Store.available() or Store.is_busy()

func _on_failed(reason: String) -> void:
	match reason:
		"user-cancelled":
			_note.text = ""
		"pending":
			_note.text = tr("STORE_PENDING")
		"nothing_to_restore":
			_note.text = tr("STORE_NOTHING")
		"unavailable":
			_note.text = tr("STORE_UNAVAILABLE")
		_:
			_note.text = tr("STORE_FAIL")
	_refresh()
```
Check that `IconButton` sets `text` from its key argument the same way the property assignment does here (`grep -n "func _init" -A15 ui/hud/icon_button.gd`); if it renders its label through a child Label, set that instead.

- [ ] **Step 4: Header button.** In `ui/menu/menu_header.gd`: `signal remove_ads`, `var no_ads: Button`; in `_build()` after `gear`:
```gdscript
	no_ads = _button("no_ads")
	no_ads.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	no_ads.offset_left = -BUTTON.x * 3.0 - BUTTON_GAP * 2.0
	no_ads.offset_right = -BUTTON.x * 2.0 - BUTTON_GAP * 2.0
	no_ads.offset_bottom = BUTTON.y
	no_ads.pressed.connect(func() -> void: remove_ads.emit())
	no_ads.visible = not Store.owns_remove_ads()
	Store.owned_changed.connect(func(owned: bool) -> void: no_ads.visible = not owned)
```
Update the header's doc comment ("the two buttons" → three). If the header runs its button entrance on named buttons (`grep -n "gear\b" ui/menu/menu_header.gd`), give `no_ads` the same entrance.

- [ ] **Step 5: Banner tab.** `core/ads.gd`: `const TAB_H := 56.0`; every `_set_banner(true, h)` stays in window px, and `ui/safe_area.gd` adds `Ads.TAB_H` (design px, unscaled) to `bottom` whenever `Ads.is_banner_visible()`. `ui/ads/banner_host.gd` builds a child `Button` (`theme_type_variation = "IconButton"`, text `ADS_TAB`, `custom_minimum_size = Vector2(0, Ads.TAB_H)`, shrink-centred) anchored bottom-centre, whose `offset_bottom` is `-(banner height in design px)` — `Ads.fake_height()` when faked, else `Ads.bottom_inset() * get_viewport_rect().size.y / DisplayServer.window_get_size().y` — shown only while the banner is visible, and `signal tapped` on press. Set `mouse_filter` on the host itself to IGNORE (already) so only the tab takes input.

- [ ] **Step 6: Wire the sheet.** In `ui/menu.gd` next to `settings_sheet` (line ~230): create `remove_ads_sheet = RemoveAdsSheet.new()`, name it, add it; connect `header.remove_ads` → `remove_ads_sheet.open_from("header")`; `settings_sheet.remove_ads` → `remove_ads_sheet.open_from("settings")`. In `ui/puzzle_host.gd` `_ready()` the same, for settings. For the banner tab: the `BannerHost` is `get_node("/root/Main/UI/BannerHost")` only in the real game; connect it in `world/main.gd` instead: `$UI/BannerHost.tapped.connect(_open_store)` where `_open_store()` finds the open screen's sheet — the host if a board is open (`get_tree().get_first_node_in_group("puzzle_host")`, add that group in `puzzle_host.gd`'s `_ready`), else `$UI/Menu`'s — and calls `open_from("banner")`. Add the Android back handling: wherever `ui/menu.gd` and `ui/puzzle_host.gd` close an open sheet on back (`grep -n "is_open()" ui/menu.gd ui/puzzle_host.gd`), include `remove_ads_sheet`.

- [ ] **Step 7: Settings rows.** In `ui/hud/settings_sheet.gd`: `signal remove_ads`; before `credits_button`:
```gdscript
	ads_button = IconButton.new("no_ads", "ADS_TAB", "IconButton")
	ads_button.custom_minimum_size.y = ROW
	ads_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ads_button.pressed.connect(func() -> void: close_then(remove_ads.emit))
	col.add_child(ads_button)
	privacy_button = IconButton.new("eye", "SETTINGS_PRIVACY", "IconButton")
	privacy_button.custom_minimum_size.y = ROW
	privacy_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	privacy_button.pressed.connect(func() -> void: close_then(Ads.show_privacy_options))
	col.add_child(privacy_button)
```
and in `_on_open()`: `ads_button.text = tr("STORE_OWNED") if Store.owns_remove_ads() else tr("ADS_TAB")`, `ads_button.disabled = Store.owns_remove_ads()`, `privacy_button.visible = Ads.privacy_options_required()`. Restore lives on the purchase sheet, one tap from here, which satisfies Apple's rule. Update the file's doc comment.

- [ ] **Step 8: Probe the flow (windowed, one run at a time).** A throwaway `$S/probe_store_flow.gd` modelled on `tests/_shot_menu.gd` (read it first) that, with `ADS_FAKE_BANNER=150 STORE_FAKE=1` and a clean `store.cfg`: shoots the menu (tab and header button visible), opens the sheet from the header and shoots it, presses `buy_button`, waits two frames and shoots (thank-you, header button gone, grey band and tab gone, bottom bar back down). Crop and look at each PNG. Then a second run with the store unset (`ADS_FAKE_BANNER=150` only): sheet shows "Not available here", Buy disabled.

- [ ] **Step 9: Suite** → `failed=0`; the locale check in the suite (if any) passes with the new keys. **Commit:** `git commit -am "feat(store): the purchase sheet, a header button, a banner tab and settings rows"` (add the new file first).

---

### Task 5: Everything clears the banner

**Files:** whatever the sweep finds. Known candidates: `ui/hud/sheet.gd` (card `offset_bottom = -MARGIN`), the win overlay in `ui/puzzle_host.gd` (`_build_overlay`), `ui/hud/how_to_play.gd`, the menu toast/pager (already inset-aware), `ui/menu/difficulty_sheet.gd`.

- [ ] **Step 1: Find every bottom-anchored node.**
```bash
grep -rn "PRESET_BOTTOM\|PRESET_FULL_RECT\|offset_bottom\|anchor_bottom" ui --include=*.gd | grep -v "^ui/faces" > $S/bottom.txt; wc -l $S/bottom.txt
```
Read each hit; list those whose bottom edge can reach the screen's bottom while a banner shows.

- [ ] **Step 2: Sheets.** In `ui/hud/sheet.gd`, the card's `offset_bottom` becomes `-MARGIN - SafeArea.insets(self).y`, set in `open()` (so it tracks a banner that arrived or left) — preload `SafeArea` there. This covers every sheet at once.

- [ ] **Step 3: Other overlays** from Step 1: give each the same `SafeArea.insets(self).y` on its bottom edge, re-applied on `Ads.banner_changed` where the node outlives a change.

- [ ] **Step 4: Twenty-board sweep.** With `ADS_FAKE_BANNER=150` (≈ a 50 dp adaptive banner at the phone's density in design px — also try 180), shoot every registry board in a single windowed run using `tests/_shot_anim.gd`'s board-opening code as the model (read it; a throwaway `$S/sweep_boards.gd` that walks `Registry.PUZZLES`, opens each at difficulty 1, waits for the entrance, shoots `$S/board_<id>.png`). For each PNG check with PIL that the lowest non-background row of the board UI ends above the grey band (the band's colour is exactly `(209,209,209)` at 0.82). List every board that overlaps and, for each, the fix (usually its `card_height(available)` or a tray's fixed height; a board card that cannot shrink is reported with its numbers, not squeezed silently).

- [ ] **Step 5:** Re-run the sweep after the fixes; every board clears. Suite → `failed=0`. **Commit:** `git commit -am "fix(ads): sheets, overlays and boards all sit above the banner"`. Record each fix in the spec's Amendments.

---

### Task 6: Docs, and the device check

**Files:** `CLAUDE.md` (new "Ads and the purchase" section), `docs/roadmap-to-release.md` (tick what is done, mark what waits on the user), spec Amendments.

- [ ] **Step 1: CLAUDE.md**: a section after "Analytics" stating: the two adapters and the rule that screens never touch a plugin; the start order; `ADS_FAKE_BANNER` and `STORE_FAKE`; `store.cfg` and the refund rule; the godot-iap `.disabled` GDExtension and `tools/export_ios.sh`; test IDs until the AdMob account exists; iOS 17 minimum; the strip script now edits a multi-plugin list; every bottom-anchored node clears the inset. Add the new analytics events to the Events list there.

- [ ] **Step 2: Roadmap**: tick "Add Godot AdMob plugins", "Consent", "iOS ATT" (usage string done; the IDFA message is set up in the AdMob console by the user), "Place the banner", "Decide where it shows" (everywhere), "Add billing plugins", "core/store.gd", "Owning it hides the banner", Settings' "Remove ads and Restore purchases rows". Leave unticked with **(you)**: AdMob account and real IDs, the IDFA message and the EEA consent form in the AdMob console, `app-ads.txt`, the store products, license testers / sandbox, "Restore works on a fresh install" and "acknowledge within three days" (code done, unverified on a device).

- [ ] **Step 3: Commit** `git commit -am "docs: ads and the remove-ads purchase"`.

- [ ] **Step 4: Device check — ask the user first.** `tools/deploy_android.sh` sends a build to testers through App Distribution. Ask the user before running it. On the phone: the test banner shows on the menu and on a board, nothing is covered, the tab and header button open the sheet, and the sheet reads "Remove ads" with no price (the product does not exist yet) — which is expected until the Play product exists.
