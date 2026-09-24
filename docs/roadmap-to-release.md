# Roadmap to release

Started 2026-09-24. This tracks what stands between today's `main` and a
build real players can install from Google Play and the App Store. Tick a box
when it is done and verified, and add the date. Items marked **(you)** need a
person: an account, a signature, a payment or a decision. Everything else can
be built.

## Where we are (checked 2026-09-24)

- **19 flat boards on the grid**, every one with Easy, Medium and Hard, plus a
  provisional Insane row (`ui/registry.gd`). Rings is back on the grid as
  the twentieth (2026-09-24), Insane included.
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
- [x] (2026-09-24) Backend: **kept**. A new, flat How Big? is coming, so the
      functions, `core/backend.gd` and `content/how_big.json` stay.
- [x] (2026-09-24) Rewrite CLAUDE.md's legacy/ and turns sections to match.
- [x] (2026-09-24) Measure the APK size again. **32.3 MB**, against 50.2 MB
      for CI's last build with the 3D in it (run 35982761844: 11.1 MB of
      `.glb`, 5.7 MB of textures). The 31.7 MB of 2026-09-15 predates most of
      the models, so it is not the comparison. The engine
      (`libgodot_android.so`) is 25.5 MB of the 32.3 and is the floor; the
      game itself is about 4 MB, half of it sound. A local build was also
      packing `build/sfx_raw`'s 176 ElevenLabs mp3s (+2.6 MB, never loaded),
      because git ignored `build/` and Godot did not; `build/.gdignore` is now
      tracked. CI never had them.

### Rings, the twentieth board
- [x] (2026-09-24) Put it back in `Registry.PUZZLES`. It had been on the grid
      and was dropped by Pinwheel's merge (`57c8539`); registry entry, card
      picture, `rings` suite and `_win.gd` solver restored from that merge's
      second parent. Suite 122,581/0; `_win.gd` solves it (22 moves).
- [x] (2026-09-24) Give it a difficulty sheet (`pick_difficulty`): Easy,
      Medium, Hard.
- [x] (2026-09-24) Its Insane row: **a move budget**, not a harder deal (the
      screen caps it at 8 pegs and 6 colours, and less slack only deals dead
      boards). Hard's deal, sorted within the shortest solve + 2, no hints,
      Undo gives a move back. The shortest solve costs 90-600 ms here, so it
      is mined: `content/insane/rings.json`, 300 deals of 755 kept from 900,
      optima 22-26 against Hard's 16-24 (`tools/insane/rings_ladder.gd`).
      Without the bank it deals live with the game solver's line as a far
      looser budget (76 on one deal whose optimum is 23).
- [x] (2026-09-24) Record its sound set: lift, drop, lock, refused, undo,
      hint, reset, solved, enter, wired and generated (one take each). **(you)**
      listen and name any to redo.
- [x] (2026-09-24) Check its card picture. Page two holds 8, the filler runs,
      and the card is the same width as its neighbours.
- [x] (2026-09-24) Title fit and draw calls. Motto 363 against the
      five-button 370 (15948e3); nothing is fitted, confirmed on a frame. Board
      **58**, page two **181** twice, page one 330. Word Trail, the control,
      read 47 against its recorded 65, which predates the tip card's removal,
      so the old records are no longer controls.

### Stats and Streak
- [x] (2026-09-24) Spec first: `docs/superpowers/specs/2026-09-24-stats-streak-design.md`,
      off the concept page (`docs/brainstorm/concepts.html#progress`). Stats
      is solves, best and average times per board and difficulty, plus a
      history; Streak is consecutive kept days, the best streak, earned rest
      days and a calendar.
- [x] (2026-09-24) The day-row hearts and the calendar badge are real: a
      heart is one distinct board solved today, three keep the streak, and
      the badge is the current streak. Both open Streak.
- [x] (2026-09-24) `core/progress.gd` carries a solve log (`log_solve`,
      `solve_log`, `hearts`), one record per board and difficulty per day;
      `core/streak.gd` and `core/player_stats.gd` derive Streak and Stats
      from it, nothing stored.
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
- [x] (2026-09-24, `feat/gradle-export`) **Move the export to the Gradle
      build.** Play only accepts AAB for new apps, and AAB, the AdMob plugin
      and Play Billing all need Gradle. The preset has
      `use_gradle_build=true`, and CI and `tools/deploy_android.sh` pass
      `--install-android-build-template` (`android/` stays out of git and is
      unpacked from the engine's own `android_source.zip`); CI caches Gradle.
      The tester APK is **84.2 MB** against 32.3 MB before, and that is
      packaging, not content: Gradle stores `libgodot_android.so`
      uncompressed (76.2 MB, page-aligned, Android's modern default) where the
      prebuilt template compressed it. A debug **AAB** exported from the same
      preset (`export_format=1`) is **32.3 MB**, and Play compresses per
      device, so players never see the 84. Not yet run on a phone: the first
      CI build after this merges is the on-device check.
- [ ] Release signing: generate an upload keystore, store it as a CI secret,
      and turn on Play App Signing. **(you)** keep an offline backup of the
      upload key. Keep the debug lane to App Distribution for testers.
- [ ] Target SDK: now set explicitly to **36** (min 24), Godot 4.7's own
      template defaults and the newest platform installed; the APK's manifest
      reads `targetSdkVersion 36`. Still to do: confirm Play's current
      minimum target level when the Play account exists.
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
      Fix it before the quality gate leans on it. On 2026-09-24 it scored
      **8/20**: most failures now read `hud=false`, likely the tip card's
      removal, and four boards free their host before the check.
- [ ] Pinwheel's merge (`57c8539`) dropped `ui/menu.gd`'s
      `Ads.banner_changed` → `_apply_insets` hook, so the menu does not move
      its margins when a banner appears. Restore it with the ads work.
- [x] (2026-09-24) `ui/flat/tip_card.gd` and `ui/hud/binairo_tutorial.gd`
      were loaded by nothing live; deleted.

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
