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
- **The campsite has its own light and a soft focus; boards do not.**
  `Stage.show_setting(true)` applies `grade_camp` (a warmer, slightly
  stronger sun over warmer bounce, wider shadow blur, saturation and
  contrast through the Environment's adjustments, a soft bloom, a deeper
  sky overhead) and shows `world/soft_focus.gd`, a full-screen quad that
  blurs by view distance past the framed thing by reading the screen
  texture's mip levels, since Compatibility has no depth of field.
  `show_setting(false)` restores the boards' measured pair and hides the
  pass, so a piece is lit exactly as calibrated. On Compatibility the
  screen and depth textures only exist during the transparent pass, so the
  quad is `blend_mix` with a low `render_priority`; anything that must stay
  in front of the blur has to draw in the opaque pass (the clouds went to
  alpha scissor for this). Measured on this Mac at phone resolution: the
  soft focus is 2.8 ms a frame, the grade 1.2 ms; if a phone drops frames on
  the menu, the soft focus's visibility is the first lever.
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

## Turns and the backend

A **turn** is one committed input a day, an immediate reveal and a graded
result -- never a pass or a fail. Turns sit on the camp grid as cards beside
the boards (`ui/registry.gd` says `"kind": "turn"`), and cost a
`core/turn_base.gd` subclass plus a registry line, the way a puzzle costs a
`PuzzleBase3D`. Both stand on `core/stage_view.gd`, which owns the stage
mounting, the camera fit and the picking maths; `PuzzleBase` extends it too,
because GDScript is single-inheritance.

**The live backend is not provisioned, and that is expected.** Cloud
Firestore is not enabled in `peeplet-daily`, there is no Firebase Web app for
it yet, and `core/backend.gd`'s `API_KEY` is still the placeholder
`PASTE_WEB_API_KEY_HERE`. A build run against the real project will fail to
sign in every time; that is not a bug to chase, it is the project waiting on
the repo owner to provision it. Everything below this point is verified
against the local emulator suite, not the live project.

`core/backend.gd` is the only way out of the game. It is static and woken by
`world/main.gd` alone, exactly like `Analytics` -- **unstarted means offline**,
which is how the suite and the harnesses build these screens without touching
the network, and why neither is an autoload.

- Identity is **Firebase Auth anonymous** over the Identity Toolkit REST API,
  not an install id: a security rule cannot verify an unsigned id, and the
  leaderboard is coming. It upgrades in place to a real account later.
- Reads go straight to **Firestore's REST API**; writes go to one Cloud
  Function. Every document a client reads carries a **single `json` field**,
  which is what keeps Firestore's typed values from becoming a decoder.
- There is **no percentile endpoint**: the tally ships the 101-bucket
  histogram and `Backend.percentile()` does the arithmetic on the device.
  Instant reveal, works offline, and "the number moves if you come back" is
  just a second read.
- A submit is queued to disk before it is sent and flushed on the next
  launch. The server keys on uid, day and game, so a double flush is
  harmless. Nothing waits on the network, and in particular **nothing blocks
  Lock**. `submitTurn` itself only accepts a submit dated today or yesterday
  in UTC -- yesterday stays open so the offline queue can still flush after
  the day rolls over mid-queue.
- Server lives in `server/` (Cloud Functions v2, TypeScript, Node 22).
  `tools/deploy_functions.sh` deploys the functions and the rules; it is not
  in CI yet, and it has not been run against `peeplet-daily` for the reason
  above. `server/.gdignore` keeps Godot out of `node_modules`.
- `tools/_backend_probe.gd` drives the whole path against the emulator suite
  and prints what came back. It is a harness, not a suite entry.

Running the emulator suite locally has three traps worth knowing before you
lose an hour to them. The Firestore emulator needs **JDK 21+**; the `java` on
this Mac's `PATH` is Homebrew's 17, and firebase-tools refuses to start
against it, so every emulator command runs prefixed with
`PATH="/opt/homebrew/opt/openjdk/bin:$PATH"`. The suite itself is started
`--project demo-peeplet` -- the `demo-` prefix is what forces the emulator
into fully offline mode with no real credentials touched -- which is why
`core/backend.gd` reads a `FIREBASE_PROJECT` environment override alongside
`FIREBASE_EMULATOR`, rather than hardcoding the project id it addresses.
And **`firebase functions:shell` cannot invoke a v2 `onSchedule` function** in
CLI 15.14.0: it prints "Successfully invoked function" and does nothing. To
trigger `publishDay` or `rollupTally` by hand, wrap the body in a temporary
`onRequest` function and curl it, or write to Firestore directly over the
emulator's REST API; this has already cost two implementers an afternoon
each.

`core/locale.gd` picks between `en`, `pt` and `es` and does the number
formatting `TranslationServer` does not. Only the turn flow's strings are
keyed (`locale/turn.csv`); the twelve boards are still hardcoded English, and
`GUESS_BLURB` is sitting in the CSV unwired, ready for whenever the registry's
own blurbs get keyed. Upper-case accented capitals turned out to be fine:
`ÁÉÍÓÚ` and `ÃÕÇÑ` both extrude cleanly at weight 700 (18,024 and 21,228
faces, in the same 3,600-5,600-faces-per-glyph range as `GUESS` at 22,356) --
the only glyphs that need the weight dropped to 550 are digits 8 and 9. That
was measured once with a throwaway probe; there is no need to re-run it for
a new accented title.

Roadmap: `docs/brainstorm/single-turn-roadmap.md`. Phase 0's design:
`docs/superpowers/specs/2026-09-17-single-turn-foundation-design.md`.

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
