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

## Art: never bake a model down to an image

**A model ships as a model.** Never render a `.blend` to a PNG, an atlas or a
sprite sheet and put that on screen in place of the geometry -- not for HUD
chrome, not for menu cards, not for a title, not for anything. Export the
`.glb` through `tools/blender_export.py` and put the real thing in the scene.

**Why:** a baked image throws away everything the model was modelled for. It
cannot be lit by the scene, cannot take the toon shader or the outline pass,
cannot be recoloured or textured per layer (which is the entire point of the
one-mesh-per-layer rule above), cannot animate or be turned, and goes soft as
soon as it is drawn larger than the resolution it was baked at. It also freezes
the art at one camera and one light, so it stops matching the game the moment
either of those changes -- and it will, this game has already re-pitched its
camera once.

If draw calls are the reason to hesitate, say so out loud and measure it
against the budget in `docs/art/blender-contract.md`. Do not quietly trade the
model away for a picture of it.

## Art: the menu's title signs

Every menu card *is* a carved wood sign, and the same board is the title in
every HUD row -- each puzzle's, and the menu's own "Daily". It is a real model
on screen, not a picture of one: `assets/models/title_sign.glb`, instanced
through `Models.instance("title_sign")` so it takes the toon shader, the grain
on its plank, its own cast shadow and the outline pass.

- **The board is modelled; the words are data.** `art/sign.blend` holds three
  layers (plank, leaf sprigs, screws) exported as the `Title_Sign` collection
  by `tools/build_models.sh`. The title and motto are **not** in the .blend:
  `ui/hud/sign_view.gd` extrudes them with `TextMesh` in the display face, so a
  new puzzle costs a registry line and no export at all. The Text objects still
  in the .blend are there to design against, nothing more.
- **`ui/hud/sign_view.gd` is a SubViewport** with its own `World3D`, camera and
  light. It draws **on demand**, not per frame: thirteen live signs on
  UPDATE_WHEN_VISIBLE cost 18.6 ms of process time on the menu against a ~5 ms
  idle baseline. Call `redraw()` after anything that changes what it shows --
  `set_words()` and the resize refit already do.
- **Light it the way `world/stage.gd` lights the game**: its 0.46 sun over
  0.115 ambient is *measured* against a rendered frame, not derived, because
  gl_compatibility renders brighter than the shader maths predicts. At the
  obvious values the plank blows out to pale pine and the leaves go yellow.
- **The camera is tilted ~9 degrees off dead-on.** Straight down the board's
  normal an orthographic camera sees only front faces, so the lettering's
  extrusion is edge-on and the whole sign reads flat. `TextMesh` has no bevel
  to catch light the way the Blender text did, so the depth has to be shown.
- **Outline shells get their own thin materials here**, at `LINE_WIDTH` 0.005
  rather than Toon's 0.014: a sign is drawn far larger than a stage piece, so
  the world-space shells read several times too thick, and a leaf in the shared
  ink line becomes the harsh black edge `docs/art/shading-direction.md` rules
  out. Build fresh materials -- `Toon.line()` caches per colour and those are
  shared with every piece on the stage.
- **Titles shrink to fit; the plank never stretches**, so the column stays
  even. What binds the width is the leaf sprigs at x = +-0.79, not the plank's
  edge. How tall a sign stands is `top_bar.sign_height`: a puzzle's row can
  only afford 180 (four buttons leave about 496px at 1080 wide), and the menu
  overrides it to 250 since it shares its row with one button.

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
