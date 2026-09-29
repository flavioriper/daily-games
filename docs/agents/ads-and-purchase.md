<!-- Moved verbatim from CLAUDE.md on 2026-09-29. -->

## Ads and the purchase

A banner (Poing's `godot-admob-plugin` v5.1.0) and a lifetime remove-ads
purchase (`godot-iap` 3.5.2, `hyodotdev/openiap`), built 2026-09-25
(`docs/superpowers/specs/2026-09-25-ads-and-remove-ads-design.md`) on branch
`feat/ads-store`. **Two adapters, and a screen never touches a plugin**:
`core/ads.gd` (autoload `Ads`) owns the banner and consent, `core/store.gd`
(autoload `Store`) owns the purchase, both to the rule `core/ads.gd` already
stated before the 3D game left.

- **`Ads.start()` runs once, from `world/main.gd`**, so tests never ask for
  an ad -- `Analytics.start()`'s own discipline. Order: if
  `Store.owns_remove_ads()`, stop for good; else Google's UMP consent
  update, its form when required, `MobileAds.initialize`, then an anchored
  adaptive bottom banner. A failed consent update still proceeds to ads
  (non-personalised) rather than a blank band forever. iOS has no ATT call
  of its own: the tracking prompt is UMP's IDFA message, set up in the
  AdMob console, showing Apple's system dialog; Info.plist still carries
  `NSUserTrackingUsageDescription`. `Store.owned_changed(true)` calls
  `Ads.remove()`, which destroys the banner and never reloads it this run.
- **`ADS_FAKE_BANNER=<design px>` and `STORE_FAKE=1`**, debug-build-only env
  overrides, walk the whole flow on this Mac with no device or plugin:
  the first reports a banner of that height everywhere (`ui/ads/banner_host.gd`
  paints a grey "AD" stand-in), the second makes `Store.buy()` /
  `Store.restore()` succeed at once, at a fake `$1.99`.
- **The owned flag lives in `user://store.cfg`**, holding offline and across
  restarts, but re-checked against the store's real purchases on every
  launch -- except a *failed* query (offline, store unreachable) never
  clears it; only a query that succeeded and found `remove_ads` missing is a
  refund. Android acknowledges every purchase the moment it is seen,
  launch-found ones included, because Play auto-refunds an unacknowledged
  one after three days.
- **`godot-iap`'s GDExtension is iOS-only and stays `.disabled` elsewhere**
  (editor, CI, this Mac). `tools/export_ios.sh` renames it on, runs the
  plugin's `fix_ios_embed.sh` to embed its frameworks, and renames it back
  (clearing `.godot/extension_list.cfg`, which the editor would otherwise
  error on next run) whichever way the export goes. It raises the **iOS
  minimum to 17.0**, dropping iPhones stuck on iOS 16 (8 and X).
- **Real AdMob IDs since 2026-09-28** (account pub-1208368368327333 on
  flavio@hypertradeworx.xyz, one app per platform, "Bottom banner" on each):
  the app IDs are `project.godot`'s `admob/general/{android,ios}/app_id`,
  the units its `ads/banner_unit_id.*`. **A debug build always asks for
  Google's test banner** (`core/ads.gd`'s `TEST_BANNER_*`), so App
  Distribution and harnesses never request a real ad; only the release
  builds the stores carry do. The apps are added as not yet on a store and
  stay "requires review" (limited serving) until each is linked to its
  store listing in AdMob once public. Published in AdMob's Privacy & messaging:
  the GDPR message (both apps, a Do not consent button in every country,
  en plus pt-PT/es/de/fr/it), the US-states message (en, es) and the iOS
  IDFA explainer (en, pt-BR, es-419). The privacy policy and `app-ads.txt`
  are `server/site/`, served by Firebase Hosting
  (`cd server && firebase deploy --only hosting`) at
  https://daily-games-420bf.web.app/peeplet/privacy and
  /app-ads.txt; the app-ads.txt only counts once Play's developer website
  is that domain.
- **The Android template needs AGP 8.9.1, not Godot 4.7's stock 8.6.1**:
  `godot-iap`'s `openiap-google` 3.5.2 pulls `androidx.core:core:1.18.0`,
  which refuses an older AGP. Godot only honours
  `--install-android-build-template` inside a full export, which would run
  Gradle on the unpatched template first -- so `tools/patch_android_template.sh`
  installs the template itself (Godot's own way, when
  `android/.build_version` is missing) and bumps the pinned AGP line; CI and
  `tools/deploy_android.sh` call it **instead of**
  `--install-android-build-template`, before a plain `--export-debug`. Safe
  to run twice; fails loudly if neither AGP line is found.
- **Both plugins' native libraries are committed**: `addons/admob` 17M,
  `addons/godot-iap` 27M (mostly `SwiftGodotRuntime.framework`, 21M). Each
  installer's own `bin/.gitignore` was deleted on purpose so the binaries
  ship, the same call already made for Poing's other `/bin` folders.
- **`tools/strip_dev_addons.sh` now edits a multi-plugin list**: `admob` and
  `godot-iap` stay enabled through export (their exporters run during it)
  while only `godot_mcp`'s entry and its `MCPGameBridge` autoload strip out.
- **iOS needs an app icon, not only the Team ID.** A dummy Team ID alone
  gets past the (expected) Team ID stop and fails next on "Invalid icon" --
  the project has no icon, and none of the three `launcher_icons/*` Android
  slots either.
- **Every bottom-anchored node clears the inset**, not only the two
  screens' own margins: every `ui/hud/sheet.gd` subclass re-offsets its card
  from `SafeArea.insets()` on open and on `Ads.banner_changed`, and the
  first-play card (`ui/hud/how_to_play.gd`) centres in the room above the
  inset rather than the whole screen -- Pinwheel's card (1636 tall in
  pt-BR) clears a 180 banner by 24 px and would not fit a 1080x1920 phone
  with a 180 banner plus a top inset over ~48. Height-bound boards lose
  cell size in proportion to the slot at a 180 banner (Hidden Word 1140 to
  904, Sudoku 1114 to 878, Code Break 1180 to 944) -- still playable in
  every shot, but tap size wants a phone to judge it. iOS banner height
  (points vs. pixels) is unverified on a device. See "The first screen"
  above for the grid's own page-count change.
- **The purchase sheet was redrawn on 2026-09-28** (`ui/hud/remove_ads_sheet.gd`):
  a meadow picture (`Vistas.STORE`, `Vistas.picture()`) with the sprout on
  its rock, three perk rows on tinted plaques (`STORE_PERK_*`) in place of
  the paragraph, one wide sun button with the price, Restore as a quiet
  text button, and no Close while there is something to buy (the X is
  enough); with no store it keeps the button dimmed and says so in a line
  under it (`STORE_UNAVAILABLE_NOTE`); owned, the thanks and a wide Close.
- **Fair ads since 2026-09-29** (branch `feat/fair-ads`, plan
  `docs/superpowers/plans/2026-09-29-fair-ads.md`, research
  `reports/Fair ad monetization for puzzles.md`). **The age gate**
  (`core/age_gate.gd`, `ui/hud/age_screen.gd`): a birth year asked once at
  first launch on a phone, kept in `user://age.cfg`, never sent -- only the
  band leaves the device (child under 13, teen 13-17, adult; the younger
  reading of the year wins). `Ads._configure_requests()` caps everyone at
  PG and a child at G with the child-directed tag, tags anyone under 18
  under-age-of-consent, and every request below 18 goes out `npa=1`. A
  desktop debug run shows the screen with `AGE_SCREEN=1`. **Pacing**
  (`core/ad_pacing.gd`, pure, saved by `Ads`): the interstitial waits out a
  3-day grace, three hearts that day, six finished games, two games and 4
  minutes since the last one and 4 after a video, at most 4 a day, and
  never for a child; the defaults are the report's and `config/ads`
  (`Backend.config`, written by `tools/set_ads_config.sh`) overrides any of
  them by name and type, a bad document ignored. **An interstitial is only
  ever asked for through `Ads.leaving_game()` after a finished game --
  never before one**: not on `play_level`, not on Play again, not at
  launch. **Rewarded videos are opt-in and asked, never pushed**: `hint` (one
  more hint a video once a board's own are spent, as many as the player
  will watch, `add_hint()`; since 2026-09-29 hint videos neither count
  toward nor stop at the ten-a-day cap, `Ads._capped()`, which binds only
  the other two), `double` (an Arcade run's gold doubled on the end card --
  gold only, never score, and inside `Wallet.ARCADE_CAP`) and `continue`
  (a run kept going beside the gold Second chance, once a run, no timer, its
  best marked boosted). **Remove ads removes the banner and the
  interstitials and nothing else**: the videos stay for buyers too, by the
  user's decision, so there is no free-reward path (`STORE_BODY` says so).
  An ad mutes Master and puts the player's Sound setting back after.
  `ADS_FAKE_FULL=1` (always earns) or `skip` (never does), debug builds
  only, stands a grey card in for either ad. Probes: `tests/_probe_age_gate`,
  `_probe_ad_pacing`, `_probe_ads_slots`, `_probe_ads_flow`,
  `_probe_extra_hint`, `_probe_hint_offer`, `_probe_chance` (with
  `ADS_FAKE_FULL`) and `_shot_doubler`. **Outside steps a person owns**:
  the four interstitial/rewarded unit ids in `project.godot`
  (`ads/interstitial_unit_id.*`, `ads/rewarded_unit_id.*`, still unset),
  AdMob's maximum content rating set to PG, the Play target-audience and
  App Store age-rating answers, and a Brazilian lawyer's word on whether a
  self-declared year meets ECA Digital's "reliable" standard.
- **The purchase sheet has three doors**: a paper "Remove ads" tab
  (`Ads.TAB_H` 56) `ui/ads/banner_host.gd` stands on the banner's top edge,
  a third header icon button, and a Remove ads row in settings (Restore
  purchases lives on the sheet itself, one tap away). The tab and the header
  icon go for good once owned; the settings row is the one door that stays,
  disabled, reading "Ads removed". `price_text()` is empty until the store
  answers, so nothing shows a price until a real product exists in Play
  Console or App Store Connect.
