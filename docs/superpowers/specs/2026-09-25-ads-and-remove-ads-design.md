# Ads and the remove-ads purchase

Date: 2026-09-25. Branch: `feat/ads-store`. Roadmap: Phase 2, "Ads" and
"Remove ads (lifetime, non-consumable)".

## 1. What the user decided

- **The banner shows everywhere**: menu, Stats, Streak and every board.
- **Personalised ads with consent**: Google's UMP form where the law asks
  for it (EEA, UK, Brazil), then Apple's App Tracking Transparency prompt on
  iOS. A player who declines either gets non-personalised ads.
- **Three doors to the purchase**: a small "Remove ads" tab on the banner's
  top edge, a third icon button in the menu header, and Remove ads /
  Restore purchases rows in settings.
- **One product, `remove_ads`**, non-consumable, the same ID on Play and the
  App Store. Price is set in the store consoles, never in code.

## 2. Plugins

- Ads: `godot-sdk-integrations/godot-admob` (Poing Studios; UMP and ATT
  built in; Android and iOS).
- Purchase: `godot-iap` (StoreKit 2 on iOS 15+, Play Billing v8 on Android).
- Neither claims Godot 4.7. **Task 1 is a spike**: install both, export the
  Gradle APK and the iOS Xcode project, and confirm the singletons load on a
  device or at least link. A plugin that will not build on 4.7 stops the
  work and goes back to the user before any replacement is chosen.
- Test IDs until the user's AdMob account exists: Google's published test
  app IDs and banner units per platform, in `project.godot` under `ads/`
  (per-platform keys via feature overrides, e.g. `ads/app_id.android`).

## 3. Adapters

Screens depend on these two and never on a plugin, the rule `core/ads.gd`
already states.

### `core/store.gd` (new autoload `Store`)

- `owns_remove_ads() -> bool`, `price_text() -> String` (the store's own
  localised price, empty until fetched), `available() -> bool`,
  `buy()`, `restore()`.
- Signals: `owned_changed(owned: bool)`, `purchase_failed(reason: String)`,
  `price_ready`.
- The owned flag is saved in `user://store.cfg`, so it holds offline and
  across restarts, and it is re-checked against the store's current
  purchases on every launch: a refunded purchase clears it.
- Android: every `remove_ads` purchase is acknowledged
  (`finish_transaction`, non-consumable) as soon as it is seen, including
  ones found at launch, so Play never auto-refunds after three days.
  A pending purchase (Play's slow payment methods) is not owned until it
  completes.
- No plugin (editor, desktop, CI, harnesses): `available()` is false and
  `buy()` emits `purchase_failed("unavailable")`. In a debug build the
  environment variable `STORE_FAKE=1` makes `buy()` and `restore()`
  succeed, so the whole flow can be driven on this Mac.

### `core/ads.gd` (existing autoload, extended)

- Start order: if `Store.owns_remove_ads()`, stop; else UMP consent update
  and form if required, then ATT on iOS, then initialise the SDK, then load
  the banner. No ad request before consent is settled.
- `Store.owned_changed(true)` calls `remove()`: hide and destroy the banner,
  emit `banner_changed(false, 0)`, never load again this run.
- The banner is anchored bottom-centre, adaptive width. `bottom_inset()`
  keeps feeding `ui/safe_area.gd`, which already lifts the menu and the
  puzzle host above it.
- `privacy_options_required()` and `show_privacy_options()` are exposed for
  the settings sheet (UMP requires a way back into the form); the row shows
  only when required.

## 4. Screens

- **Banner on boards.** Nothing new to wire: both screens read the inset.
  The work is fitting: shoot all twenty boards at `--resolution 810x1440`
  with a forced 100 design-px inset and fix any whose bottom slot or card
  overflows. Each fix is named in this spec's amendments.
- **Banner tab.** A small paper tab, "Remove ads", drawn by `BannerHost`
  just above the banner (inside the reserved band, never over the ad: AdMob
  forbids overlaying the creative). The inset grows by the tab's height.
  Hidden once owned, with the banner.
- **Header button.** A third `IconButton` in `ui/menu/menu_header.gd`
  beside the calendar and the gear, with a "no ads" icon in `ui/icons.gd`.
  Hidden once owned.
- **Purchase sheet** (`ui/hud/remove_ads_sheet.gd`), the one screen all three
  doors open: what it buys ("No more ads, for good"), the store's price on a
  Buy button, a small Restore link, and a thank-you state after a purchase.
  Failures are a toast line on the sheet, never a silence. Unavailable store:
  the button reads "Not available" and is disabled.
- **Settings sheet.** Rows for Remove ads (price, or "Owned") and Restore
  purchases; a Privacy choices row when UMP requires it.

## 5. Strings and analytics

- New keys in `locale/ui.csv`, en / pt-BR / es.
- Events: `store_opened` (with `door`: banner, header, settings),
  `purchase_started`, `purchase_complete`, `purchase_failed` (with
  `reason`), `restore_used` (with `found`). Existing `ad_banner_*` events
  stay.

## 6. Verification

Per the user's standing rule, no new suite tests: throwaway self-driven
probes that show each piece working.

- Desktop with `STORE_FAKE=1`: buy from each door hides the banner tab and
  header button; restart keeps it owned; deleting `user://store.cfg` and
  restoring brings it back.
- The twenty-board inset sweep above.
- On Android through App Distribution: test banner appears on the menu and
  a board, consent form appears under a forced EEA debug geography, the
  header button opens the sheet. The real purchase needs `remove_ads` to
  exist in Play Console and a license tester; iOS needs the Team ID. Both
  are the user's, and are reported as not verified until they exist.

## 7. Not in this work

`app-ads.txt`, the privacy policy, store privacy labels, the AdMob and store
accounts, and cloud backup of the purchase across devices.
