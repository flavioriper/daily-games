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

## Art: the title signs and the first screen

Every puzzle's HUD row carries a carved wood sign as its title. It is a real
model on screen, not a picture of one: `assets/models/title_sign.glb`,
instanced through `Models.instance("title_sign")` so it takes the toon shader,
the grain on its plank, its own cast shadow and the outline pass.

- **The board is modelled; the words are data.** `art/sign.blend` holds three
  layers (plank, leaf sprigs, screws) exported as the `Title_Sign` collection
  by `tools/build_models.sh`. The title and motto are **not** in the .blend:
  `ui/hud/sign_view.gd` extrudes them with `TextMesh` through
  `core/lettering.gd`, so a new puzzle costs a registry line and no export.
- **Every model in the HUD stands in a `ui/hud/model_view.gd`**: a SubViewport
  with its own `World3D`, the stage's calibrated light (0.46 sun over 0.115
  ambient, *measured* against a rendered frame because gl_compatibility
  renders brighter than the shader maths predicts) and an orthographic camera
  framed on a box. It draws **on demand**, not per frame: over a dozen live at
  once on the menu, and on UPDATE_WHEN_VISIBLE they cost 18.6 ms against a
  ~5 ms idle baseline. Call `redraw()` after anything that changes what one
  shows. The sign, the menu's title letters (`title_view.gd`) and the cards'
  dioramas (`card_scene.gd`) are its three users.
- **Outline shells get their own thin materials here** (`Lettering.outline`,
  0.005 rather than Toon's 0.014): a sign is drawn far larger than a stage
  piece, so the world-space shells read several times too thick. Never set a
  width on `Toon.line()`'s materials; those are shared with the stage.
- **TextMesh cannot extrude every glyph.** The display face's digits 8 and 9
  cross themselves at weight 700 and vanish; `core/lettering.gd` drops a line
  that carries a digit to weight 550, the heaviest that extrudes all ten.
  Upper-case everything that goes on a board.

**The first screen (`ui/menu.gd`) is a campsite, not a list.** `world/camp.gd`
is mounted on the stage in place of a board, staged the way the concept
banner (`docs/art/concept-menu-banner.png`) frames it: the scout
(`mascot_scout`, alive through `world/mascot.gd`) reading his map on the
dock with the river behind him, the day sign lettered live at his left, the
lantern between them on the path, the tent and the tree line behind, the
"A puzzle a brighter you" board at the dock's corner, and the fence diorama
(`camp_sign`) that closes the frame at the bottom with the footer motto on a
plank. `tests/preview_tree.tscn` mounts the same `Camp` under a fixed
camera, so the editor shows the real thing. The menu frames
`camp.hero_box()` in the screen above the cards and stands the fence where
the footer slot's rays meet the ground, after every layout change.

- **The menu camera is a shift lens** (`CameraRig.shift_fov_deg`, passed as
  `fit_camera`'s `shift_fov`): aimed straight at the camp at 12 degrees, 54
  degrees across the hero strip, with the frustum slid so the strip lands at
  the top of the screen. The ordinary perspective had to aim under the camp
  through a narrow field to hold it up there, which flattened and shrank it.
  It is Godot's frustum projection with an offset, and in 4.7
  `project_position` and `project_ray_normal` mis-scale that offset while
  `unproject_position` is right: anything that needs a ray or a pixel size
  on the menu asks the rig (`ray_origin`, `ray_normal`,
  `pixels_per_unit_at`), never `Camera3D` directly.
- **Instance shader parameters are scarce.** Any mesh given a
  `set_instance_shader_parameter` reserves a 16-item block of the global
  shader buffer, whether or not its material declares such a uniform, and on
  gl_compatibility that buffer is a uniform buffer the GPU caps: 64 KB on
  this Mac, so 256 meshes in the whole game at once, and GLES3 only promises
  16 KB. `Scenery.seed_grain` therefore seeds only wood; do not hand
  per-instance parameters to leaves, stones or anything else in bulk.
- **The camp stands at y 2** (`Camp.LIFT`): the backdrop's hills ring is a flat
  plateau at about y 1.4, and the menu camera stands out over that ring where
  a board's never does. At y 0 the camp's feet and its fence are buried in it.
- **Cards come in pages of nine**, turned with the buttons under the grid, not
  a scroll. Each card's picture is a live diorama of that puzzle's own pieces
  (`ui/hud/card_scene.gd`), never an image; a new puzzle costs one builder.

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
