# Roadmap to release

Started 2026-09-24. This tracks what stands between today's `main` and a
build real players can install from Google Play and the App Store. Tick a box
when it is done and verified, and add the date. Items marked **(you)** need a
person: an account, a signature, a payment or a decision. Everything else can
be built.

## Where we are (checked 2026-09-24)

- **19 flat boards on the grid**, every one with Easy, Medium and Hard, plus a
  provisional Insane row (`ui/registry.gd`). Rings is built but not on the
  grid.
- **CI is green**: the last three pushes to `main` ran tests, the APK and App
  Distribution with no failures (`gh run list`).
- **Android testers only.** The build is a debug-signed APK sent through
  Firebase App Distribution (`export_presets.cfg`: `export_format=0`, the
  non-Gradle template, `version/name="0.1.0"`). There is no iOS preset. Xcode
  26.5 is installed on this Mac.
- **Analytics and the backend are live** on `daily-games-420bf`.
- **Ads are stubbed.** `core/ads.gd` is an adapter with no plugin behind it
  and no app ID, so a banner never shows. There is no in-app purchase code.

## Decisions (2026-09-24)

- **Platforms: Android and iOS**, launching together.
- **Name: Peeplet Daily, package `com.peeplet.daily`** (the export preset's
  values). `project.godot`'s `config/name` still says `Daily`, so align it.
  The iOS bundle ID should match.
- **Monetisation: banner ads, plus a one-time purchase that removes ads for
  life.**
- **pt and es ship at 1.0.**
- **The 3D game is removed**: legacy/, More, the campsite and How Big? all go.
- **Rings ships**, as the twentieth card.
- **Stats and Streak ship** as real tabs.

---

## Phase 1: The game is complete

### Remove the 3D game
- [x] (2026-09-24, `feat/remove-3d`) Delete `legacy/` and everything only it uses: the stage, the toon and
      model pipeline, `assets/models/`, the `.blend` sources for the islands
      and the camp, the 3D shaders, `Registry.LEGACY`, and `_raise_stage` in
      `ui/menu.gd`. Live files that still mention `legacy/` include
      `ui/menu.gd`, `ui/puzzle_host.gd`, `ui/registry.gd`,
      `ui/menu/menu_header.gd`, `ui/menu/card_art.gd`, `core/puzzle_base.gd`
      and several `puzzles/*2d.gd`. Check each one before deleting.
- [x] (2026-09-24) The bottom bar loses **More**: it is now Home, Stats,
      Streak. Settings already has its own button in the header.
- [x] (2026-09-24) Legacy boards' `seed_as` goes with them. Check that no flat board seeds
      from an island id.
- [ ] Backend: How Big? was the only turn. Decide whether to disable
      `publishDay`, `rollupTally` and `submitTurn` (Cloud Functions plus
      scheduler costs) or keep them for a future flat turn. Take
      `core/backend.gd` out of the startup path if nothing uses it.
- [x] (2026-09-24) Rewrite CLAUDE.md's legacy/ and turns sections to match.
- [ ] Measure the APK size again. It was 31.7 MB on 2026-09-15 with the 3D in
      it.

### Rings, the twentieth board
- [ ] Put it back in `Registry.PUZZLES`.
- [ ] Give it a difficulty sheet (`pick_difficulty`) and an Insane row, like
      the other nineteen.
- [ ] Record its sound set (`tools/gen_sfx.py rings`).
- [ ] Check its card picture. Page two at 1080x1920 goes from 7 cards to 8,
      so the short last row needs a filler (`8 % 3 = 2`).
- [ ] Re-sweep its title fit and measure its draw calls against the
      controls.

### Stats and Streak
- [ ] Spec first (the concept page, then the spec, as for every screen).
      Stats: solves, best and average times per board and difficulty, and a
      history. Streak: consecutive days with a solve, the best streak, and a
      calendar.
- [ ] Decide what the day-row hearts and the calendar badge mean now. Today
      they are decoration; a real streak probably makes them real.
- [ ] Extend `core/progress.gd` to record what the tabs need. Today it
      stores done marks and `completed_stats` per board per day.
- [ ] Back up progress to the cloud. A player who reinstalls or changes
      phones loses their streak. Anonymous Firebase auth can be upgraded to
      Sign in with Apple and Google, which is also how the remove-ads
      purchase follows them.

### Content and boards
- [ ] Insane banks: mine each board's Insane batch into `content/insane/`
      (`tools/mine_insane.gd`). Today the directory does not exist.
- [ ] Binairo and Sudoku Insane both miss the 194 ms gate and were accepted
      by ruling. Confirm that they ship like that.
- [ ] Sudoku on a real phone: the worst seed takes 193-201 ms on this Mac,
      which is plausibly 400-600 ms on a phone. Past the 300 ms budget the
      grid silently comes out easier (`graded: false`). Time it on an older
      iPhone and a mid-range Android.
- [ ] Every board opens its rules sheet. Hidden Word especially.

### Localisation: pt and es
- [ ] Key all 20 boards' rules, tips, trays, card blurbs and difficulty
      lines. Today only the shared chrome and the two word boards are keyed
      in `locale/ui.csv`.
- [ ] Key the new Stats, Streak, purchase and consent strings.
- [ ] pt is pt-BR (`ui.csv`). `locale/turn.csv` is pt-PT, but it goes with
      How Big?.
- [ ] Have a native speaker review each language: a machine-fluent rule
      that reads wrong is worse than English.

### Settings
- [ ] Add a sound on/off toggle. The sheet has Reduce motion and Language
      today.
- [ ] Decide whether 1.0 has music. None exists.
- [ ] Add **Remove ads** and **Restore purchases** rows. Apple rejects apps
      with a non-consumable purchase and no Restore.
- [ ] Add rows for the privacy policy, the privacy / consent choices, and
      credits.
- [ ] Credits: Fredoka, the wordfreq word lists (CC-BY-SA 4.0, attribution
      required), ElevenLabs sound, and Godot's licence.

## Phase 2: Builds, ads and the purchase

### Android
- [ ] **Move the export to the Gradle build.** Play only accepts AAB for new
      apps, and AAB, the AdMob plugin and Play Billing all need Gradle. CI
      changes with it.
- [ ] Release signing: generate an upload keystore, store it as a CI secret,
      and turn on Play App Signing. **(you)** keep an offline backup of the
      upload key. Keep the debug lane to App Distribution for testers.
- [ ] Target SDK: `gradle_build/target_sdk` is blank. Check Godot 4.7's
      default against Play's current minimum target API level.
- [ ] Launcher icons: the three `launcher_icons/*` slots are empty.

### iOS
- [ ] **(you)** Apple Developer Program membership ($99 a year), and the
      bundle ID `com.peeplet.daily` registered.
- [ ] Install Godot 4.7's iOS export templates (none are in the export
      templates directory today), and add an iOS preset: icons, launch
      screen, portrait only, and the team ID.
- [ ] Export to Xcode, and build and run on a real iPhone.
- [ ] CI for iOS: a macOS runner that exports, signs with App Store Connect
      API keys, and uploads to TestFlight. Alternatively, build locally on
      this Mac for 1.0 and automate later.
- [ ] Check the safe areas on iPhone: the notch or Dynamic Island, and the
      home indicator (`ui/safe_area.gd`).
- [ ] Check the gl_compatibility renderer on iOS. Godot runs it on ANGLE over
      Metal there, so recheck the draw-call budget and the look on a
      device.

### Both
- [ ] Set `version/name` to 1.0.0. Android's `version/code` is the CI run
      number; iOS needs its own build number.
- [ ] Splash: `boot_splash/show_image=false`. Decide the cold-start frame.
- [ ] Release hygiene: the `MCPGameBridge` autoload must not ship, and no
      probe, harness or test may either. `tools/` is already excluded.
- [ ] Crash reporting: there is none. Firebase Crashlytics on both platforms
      needs native plugins.

### Ads
- [ ] **(you)** AdMob account, with one app per platform and a banner unit
      for each.
- [ ] Add Godot AdMob plugins for Android and iOS, and fill in
      `ads/provider_singleton`, `ads/app_id` and `ads/banner_unit_id` for
      each platform.
- [ ] Consent: Google's UMP form for the EEA, the UK and Brazil (LGPD), shown
      before the first ad request.
- [ ] iOS App Tracking Transparency: show the prompt and write its usage
      string, or serve non-personalised ads only and skip tracking.
- [ ] Publish `app-ads.txt` on the developer site.
- [ ] Place the banner so it never covers a board, a tray or the bottom bar,
      on either platform (`ui/safe_area.gd` already reads `Ads.bottom_inset()`).
- [ ] Decide where it shows: the menu only, or on boards too. A banner over a
      board being solved is the likeliest one-star review.

### Remove ads (lifetime, non-consumable)
- [ ] **(you)** Create the product in Play Console and App Store Connect with
      the same product ID, and set the price.
- [ ] Add Godot billing plugins: Play Billing on Android and StoreKit 2 on
      iOS.
- [ ] Add a `core/store.gd` adapter in the shape of `core/ads.gd`, so screens
      never depend on a plugin.
- [ ] Owning it hides the banner at once, stops ad requests and survives a
      restart. Keep the flag on the device and restore it from the store.
- [ ] Restore purchases works on a fresh install on both platforms.
- [ ] Android: acknowledge the purchase within three days, or Play refunds
      it.
- [ ] Test with Play license testers and the StoreKit sandbox, including a
      purchase refunded after the fact.

## Phase 3: Store and legal

- [ ] **(you)** Google Play developer account. A new personal account must
      run a **closed test with at least 12 testers for 14 days** before it
      can publish to production. This is the longest wait on the list, so
      start it early.
- [ ] Privacy policy at a public URL, in en, pt and es. It covers anonymous
      Firebase auth, GA4 analytics, AdMob, the purchase, and cloud backup if
      it ships.
- [ ] Play Data Safety form and Apple's App Privacy labels, both matching the
      policy.
- [ ] Content ratings: IARC on Play and Apple's age rating.
- [ ] Target audience: 13+ (not for children). Families rules would forbid
      most of the ads setup.
- [ ] Store listings in en, pt-BR and es: title, subtitle or short
      description, long description, screenshots for each required device
      size (including iPhone 6.9" and iPad if iPad is supported), and Play's
      1024x500 feature graphic.
- [ ] **Never use** Wordle, Hashiwokakero, the LinkedIn or Puzzmo names, or
      any other game's trademark in a listing, a keyword field or a
      screenshot. The in-game renames only protect us if the stores follow
      them too.
- [ ] A developer website hosting the privacy policy, `app-ads.txt` and a
      support email or URL (Apple requires one).
- [ ] Trademark check on "Peeplet Daily".
- [ ] Decide on iPad: supported, or iPhone only. Supporting it adds
      screenshots and a 3:4 layout pass. The menu already fits 4x4 at 3:4.

## Phase 4: Quality gate

- [ ] Full playthrough on an Android phone and an iPhone: all 20 boards at
      all four difficulties open, solve, show their win screen and mark the
      day done. Do it in all three languages.
- [ ] Day rollover while the app is open and while it is backgrounded: the
      seed, the done marks, Day N and the streak all follow.
- [ ] Offline: a cold start with no network plays everything, the banner
      fails quietly, and ownership of the purchase is still honoured.
- [ ] `--rendering-driver opengl3_angle` on every board. No `instance
      uniform` may creep back.
- [ ] Performance on a low-end Android phone and the oldest iPhone we
      support.
- [ ] Screens: 9:16, 9:20, iPhone with a notch or Dynamic Island, and iPad if
      it is supported.
- [ ] Android back: it closes a sheet, then a board, then the app. Pausing
      and resuming on both platforms keeps the board's state.
- [ ] Upgrade from a 0.x tester build: saves load, and the loss of the 3D
      boards breaks nothing that was saved.

## Found on the way

- [ ] `tests/_win.gd` is stale: it now removes the first-play tutorial and no
      longer loops on a board whose host goes away, but Binairo, Code Break
      and Queens still fail in it. The same three also fail on `main`
      before the 3D removal (main scored 7/19 in that run; the branch
      scored 16/19), so it is the harness and its timing, not the boards.
      Fix it before the quality gate leans on it.
- [ ] `ui/flat/tip_card.gd` and `ui/hud/binairo_tutorial.gd` are loaded by
      nothing live. Check whether the first-play tutorial replaced them, and
      delete them if so.

## Phase 5: Launch

- [ ] Android: internal track, then the closed test (12 testers for 14
      days), then production with a staged rollout starting around 10%.
- [ ] iOS: TestFlight, then App Review, then a phased release.
- [ ] Launch dashboard: GA4 `game_open`, `puzzle_complete` (with `solved`),
      `puzzle_abandon` and retention, plus ad revenue and remove-ads
      conversion.
- [ ] Add analytics events for the purchase funnel (`remove_ads_viewed`,
      `remove_ads_purchased`, `purchases_restored`) and the consent outcome.

---

## Critical path

1. **Now:** start **(you)** the Play developer account, the Apple Developer
   membership and AdMob. Approval and verification take days.
2. **Remove the 3D game.** It shrinks everything that follows.
3. **Gradle export and the iOS export**, the two builds everything else sits
   on.
4. In parallel: **Stats and Streak** (the biggest feature), **Rings**,
   **pt/es keying**, and **ads plus the purchase**.
5. As soon as there is a signed Android build worth testing, **start the
   14-day closed test**. Everything else can keep landing during it.
6. Store listings, privacy, then the quality gate, then launch on both
   stores.
