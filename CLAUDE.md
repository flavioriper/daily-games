# Agent guidelines

## Art: Blender models

Full rules: `docs/art/blender-contract.md`. The short version every agent must
follow when touching a model:

- **One mesh per layer.** Every visual layer (each colour region or detail:
  body, colour cap, each ear, each eye, muzzle, nose, mouth, tongue, each
  cheek, each foot, tail) is its own mesh object with its own material. Never
  merge layers into one mesh, never put two materials on one mesh. This is
  what makes a layer textureable on its own later. Two lobes of the *same*
  layer (one material) may share a mesh.
- **The `.blend` is the source.** Mascots are modelled in the live Blender
  session and saved to `art/mascot_<name>.blend` (tracked in git). Never write
  a script that rebuilds a mascot from scratch; the Blender MCP is a remote
  control for edits, not a generator.
- **Export through the contract check**, never by hand:
  `Blender -b art/mascot_pom.blend --python tools/blender_export.py -- Mascot_Pom`
  then `godot --headless --path . --import`.
- **Preview on the real stage** with `tests/_shot_model.gd` (toon shader,
  outlines) before calling a model done; Blender's viewport colours are not
  what the game shows.

## Art: the menu's title signs

Each of the twelve menu cards *is* a carved wood sign, and the same board is
the title in every HUD row -- each puzzle's, and the menu's own "Daily". All
thirteen are rendered from one source: `art/sign.blend`. Five layers, one mesh
and one material each, per the contract above: plank, title, motto, leaves,
screws.

- **Never edit the twelve PNGs.** They are output. To change how every sign
  looks, edit `art/sign.blend` in the live Blender session and re-render:
  `Blender -b art/sign.blend --python tools/build_signs.py`,
  then `godot --headless --path . --import`.
- **The words come from `ui/registry.gd`**, not from the .blend. The tool reads
  every entry's `title` and `motto`, so adding a puzzle there and re-running is
  all a new sign takes. The menu's own sign is `daily.png`, read the same way
  from `ui/menu.gd`'s `TITLE` and `MOTTO`. The Text objects in the .blend only
  hold whatever was rendered last.
- **`ui/hud/top_bar.gd` hangs the sign by id** and falls back to the drawn
  plaque (`ui/hud/wordmark.gd`, `CozyTheme.plank`) when there is no PNG for it,
  so a stripped project still shows a title. How tall it stands is
  `sign_height`: a puzzle's row can only afford 180 (four buttons leave it
  about 496px at 1080 wide), and the menu overrides it to 250 because it shares
  its row with one button.
- **Titles shrink to fit; the plank never stretches**, so the column stays
  even. The tool prints a `FIT` line when a title had to come down (Code Break
  90%, Snake Apple 85%). What binds the width is the leaf sprigs at x = +-0.79,
  not the plank's edge.
- Fredoka is a variable font and Blender only loads its Light instance, so the
  lettering's weight comes from the Text objects' `offset` (a faux-bold), not
  from a weight axis. Pushing that offset too far closes the counter of an "A"
  into a sliver.

## Art: shading direction

The look everything aims for is in `docs/art/shading-direction.md`: soft
painted cel, no harsh black outlines, warm muted pastels, diffuse and
painterly surfaces, soft coloured shadows, minimal specular, depth through
colour rather than fog. Read it before touching a shader, palette or light.

## Playing on an Android phone

The game ships as a native APK through Firebase App Distribution (project
`peeplet-daily`, package `com.peeplet.daily`). Run `tools/deploy_android.sh`
to export and distribute; the build lands in the Firebase App Tester app on
the phone. Nothing deploys on push.

The export is the non-gradle (prebuilt template) path, arm64-v8a only,
debug-signed. Machine-local setup it depends on: the Android SDK at
`/opt/homebrew/share/android-commandlinetools` and `~/.android/debug.keystore`,
both wired into Godot's editor settings, plus the 4.7 Android export
templates. `build/` is ignored -- it is output.

## Analytics

Gameplay events go to Firebase (project `peeplet-daily`) over the GA4
Measurement Protocol, in `core/analytics.gd`. No native SDK, so the Android
export stays on the non-gradle path.

- **Nothing sends unless `Analytics.start()` runs**, and only `world/main.gd`
  calls it. Tests and harnesses build the same screens and stay silent; keep
  it that way rather than making this an autoload.
- The API secret lives in `analytics_secret.cfg` beside `project.godot`:
  untracked, packed by the preset's `include_filter`, overridable with
  `GA_API_SECRET`. Missing secret means the game runs untracked, not broken.
- Events: `game_open`, `puzzle_start`, `puzzle_complete`, `puzzle_abandon`,
  `hint_used`, `undo_used`, `check_used`, `board_reset`, `rules_opened`,
  `new_puzzle`, `reduce_motion`, and on a board that can be turned,
  `view_turn` and `peek_used`. Board events carry puzzle_id, difficulty,
  day, seconds, moves, hints, checks; the last two tell us whether Pipes'
  third dimension is a puzzle or a nuisance.
- To debug the wiring: `Analytics.validate = true` posts to GA4's validation
  endpoint and prints the verdict instead of recording; `Analytics.debug_mode`
  puts events in the console's DebugView.
- `tools/analytics_secret.sh <secret>` installs the secret in both places that
  need it (the untracked file and the `ANALYTICS_API_SECRET` repo secret) and
  then sends one DebugView-tagged event, so the wiring is visible rather than
  assumed. GA4's collect endpoint answers 204 to everything, so DebugView is
  the only proof a secret actually works.

## CI

`.github/workflows/android.yml` runs on push to `main` (and on demand from the
Actions tab): tests, then the APK, then Firebase App Distribution. The suite
gates it -- the job stops on a non-zero failure count before anything reaches
a phone. Each run stamps `version/code` with the run number so two builds are
never the same version.

Three repo secrets feed it, and the build says so when one is missing:

- `ANDROID_DEBUG_KEYSTORE` -- base64 of `~/.android/debug.keystore`. It must
  be *that* key: Android will not install a build over one signed differently.
- `ANALYTICS_API_SECRET` -- the GA4 Measurement Protocol secret. Absent, the
  build warns and reports nothing.
- `FIREBASE_SERVICE_ACCOUNT` -- JSON key with App Distribution Admin. Absent,
  the APK is still attached to the run as an artifact.

CI gets its Android SDK path into Godot by appending to the editor settings
file that `--import` generates, rather than writing one by hand; the appended
keys win over the defaults above them.
