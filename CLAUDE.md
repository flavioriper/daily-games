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
  and the question marks `?` `¿` cross themselves at weight 700 and vanish,
  and even at 550 their caps come and go with the font size under TextMesh's
  default curve step; `core/lettering.gd` drops a line that carries a digit
  or a question mark to weight 550 *and* a curve step of three hundredths of
  its font size, the pair measured to extrude them whole at every size tried.
  Upper-case everything that goes on a board.

**The first screen (`ui/menu.gd`) is a campsite, not a list.** `world/camp.gd`
is mounted on the stage in place of a board, staged the way the concept
banner (`docs/art/concept-menu-banner.png`) frames it: the scout
(`mascot_scout`, alive through `world/mascot.gd`) reading his map on the
dock with the river behind him, the day sign lettered live at his left, the
lantern between them on the path, the tent and the tree line behind, and
the "A puzzle a brighter you" board at the dock's corner. The fence diorama
(`camp_sign`) that used to close the frame at the bottom with a motto plank
was dropped on 2026-09-17 at the user's request; the lawn runs to the
bottom and the page buttons stand on it. `tests/preview_tree.tscn` mounts
the same `Camp` under a fixed camera, so the editor shows the real thing.
The menu frames `camp.hero_box()` in the screen above the cards after
every layout change.

- **The menu camera is a shift lens** (`CameraRig.shift_fov_deg`, passed as
  `fit_camera`'s `shift_fov`), posed the way the camp asks (`Camp.VIEW_PITCH`,
  `VIEW_YAW`, `VIEW_FOV`): from a step to the left of the camp, 13.7 degrees
  down, 90 degrees across the hero strip, with the frustum slid so the strip
  lands at the top of the screen. Standing close and off to the left through
  a wide field is what shows the scout's left side and lays the dock and the
  day sign at an angle; the head-on 54-degree view it replaced read flat. The
  ordinary perspective had to aim under the camp through a narrow field to
  hold it up there, which flattened and shrank it. `tests/preview_tree.gd`
  takes the same pose off the camp, so the editor shows the menu's view.
  It is Godot's frustum projection with an offset, and in 4.7
  `project_position` and `project_ray_normal` mis-scale that offset while
  `unproject_position` is right: anything that needs a ray or a pixel size
  on the menu asks the rig (`ray_origin`, `ray_normal`,
  `pixels_per_unit_at`), never `Camera3D` directly.
- **The campsite has its own light, palette and soft focus; boards do
  not.** Its light and colour aim at the painted frame
  `docs/art/concept-menu-painted.png` (2026-09-17), not the banner; the
  section "The first screen's light" in `docs/art/shading-direction.md`
  holds the calibration. `Stage.show_setting(true)` applies `grade_camp` (a
  low golden sun from the right over a dark cool bounce, contrast up and
  saturation left alone, a soft bloom, a deep sky over a warm horizon, the
  shared water in deep teal) and shows `world/soft_focus.gd`, a full-screen
  quad that blurs by view distance past the framed thing by reading the
  screen texture's mip levels, since Compatibility has no depth of field;
  it also blurs and darkens what stands nearer than the framed thing, in
  the top of the frame only (`near_gate`; the lawn under the cards is as
  near and already takes the vignette), and lays a soft vignette over the 3D
  world. `show_setting(false)` restores the boards' measured pair, the
  sun's direction, the sky and the water colours and hides the pass, so a
  piece is lit exactly as calibrated. The camp's own greens are
  `Pal.CAMP_*`; a board's TURF and LEAF never changed. On Compatibility the
  screen and depth textures only exist during the transparent pass, so the
  quad is `blend_mix` with a low `render_priority`; anything that must stay
  in front of the blur has to draw in the opaque pass (the clouds went to
  alpha scissor for this). `SCREEN_UV.y` runs top-down in a spatial shader
  here. Measured on this Mac at phone resolution: the whole menu idles at
  about 13 ms against 10 before the painted pass, the soft focus itself is
  2.8 ms, the grade 1.2 ms and the lawn under the cards 2.3 ms; if a phone
  drops frames on the menu, `Camp.NEAR_GRASS` and the soft focus's
  visibility are the two levers, in that order.
- **The camp has weather, and boards do not.** `wind_gust` is the second
  global shader parameter beside `motion_scale` (`world/ambient.gd`,
  `shaders/wind.gdshaderinc`): 0 everywhere, and 1 only while the campsite
  is on the stage, so a board's rim grass keeps exactly the flutter it was
  calibrated with. `Stage.show_setting` sets it with the pollen and the
  grade, and reduce-motion stills it along with everything else (measured:
  two frames 1.5 s apart come out pixel-identical). Over the old flutter it
  lays a gust -- a band travelling across the world along `wind_dir`, one
  crest every 13 units, cubed so the lull is long and the crest arrives
  quickly. `toon_wind`, `outline` and `card_wind` all `#include` the same
  file, because a gust each shader reads differently is a shimmer rather
  than a wind; the gust's direction is taken back through the model's own
  basis so every prop leans the same way in the world however it is turned,
  which the flutter never had to bother with.
  What blows: the grass, the blossom and foliage cards, the bushes and every
  tree crown. A layer's lean is shaped by four `sway_*` parameters
  (`Toon.SWAY_BLADE`, `SWAY_CROWN`, `SWAY_BUSH`, `SWAY_CARD`), read in the
  model's own units so the prop's scale carries them, and `Toon.line_for`
  copies them onto the outline shell -- a line left on the shader's defaults
  peels off the layer it rings. Aim `wind_dir` much further toward the camera
  and the field leans down the view, which reads as growing, not bending.
- **The lawn is sown to what the camera actually sees, which is far less
  than it looks.** The near lawn under the cards is the wedge from
  (x -2.9..3.4, z 7.9) to (x -0.9..0.9, z 10.5) in the camp's space -- about
  eleven square units -- because at the bottom of the screen the shift lens
  is looking almost straight down from (0, 2.7, 10.8). Cast the rig's rays
  at the screen's own pixels before sowing anything: a MultiMesh is culled as
  one thing and never per instance, so a tuft off screen costs its vertices
  every frame and shows nothing. Two grasses carry the ground:
  `grass_patch` (480 triangles) where the camera is close and `grass_clump`
  (98) for the wide fill. Three new fields cost three draw calls (326 to 329
  on the menu, against the 855 budget) -- the bill is triangles and fill,
  never calls.
- **Instance shader parameters are unusable here; nothing may reintroduce
  one.** Any canvas item or mesh whose material's shader *declares* an
  `instance uniform` reserves a 16-item block of the global shader buffer,
  set or not, and the gl_compatibility shaders declare that buffer as 256
  items -- **sixteen instances in the whole frame**. Past that, index is out
  of the array's range: a desktop driver reads on into the real 4096-item
  buffer and looks perfectly right, which is why this Mac never showed it,
  and a mobile driver hands back garbage. Measured on Android 2026-09-17:
  twenty-five wood meshes stood on the How Big? screen (the deck, the day
  card, and the menu's card dioramas still in the tree behind the host); the
  deck's grain came back as chopped dashes, because a garbage `grain_seed`
  throws the figure's noise coordinates where `floor`/`fract` lose precision,
  and the day card's carved edge chewed the card into a lattice of blocks,
  because a garbage `plank_size` turns the silhouette's alpha cut into a
  staircase. `--rendering-driver opengl3_angle` reproduces the class on this
  Mac (it reads zero rather than garbage, so the cut simply vanishes) and is
  the cheapest way to check anything suspected of being mobile-only.
  The two that used it now use plain uniforms: the wood's log seed with one
  material cached per log (`core/toon.gd`, `GRAIN_LOGS`), and the day card's
  `plank_size` on the panel's own material (`CozyTheme.plank`). Neither costs
  a draw call (338 on the menu either way); the wood cache went 6 to 22.
- **The camp stands at y 2** (`Camp.LIFT`): the backdrop's hills ring is a flat
  plateau at about y 1.4, and the menu camera stands out over that ring where
  a board's never does. At y 0 the camp's feet are buried in it.
- **Cards come in pages of nine**, turned with the buttons under the grid, not
  a scroll. Each card's picture is a live diorama of that puzzle's own pieces
  (`ui/hud/card_scene.gd`), never an image; a new puzzle costs one builder. A
  full page of nine measures 318 draw calls against the 855 budget, on this
  Mac at phone resolution -- the cards are what a page costs, so a page, not
  the whole registry, is the unit to measure against the budget.

## The flat screens, on trial beside the island

Since 2026-09-18 eight cards open a flat 2D board under flat chrome, and each
keeps its stage version reachable as a second card seeded from the same day
(`seed_as`), so both can be played and judged on the phone: **Binairo**
(`puzzles/binairo2d.gd`, beside `binairo_island`), **Code Break**
(`puzzles/codebreak2d.gd`, beside `mastermind_island`), **Balance**
(`puzzles/balance2d.gd`, beside `balance_island`), **Shikaku**
(`puzzles/shikaku2d.gd`, beside `shikaku_island`), **Untangle**
(`puzzles/untangle2d.gd`, beside `untangle_island`), **Tents**
(`puzzles/tents2d.gd`, beside `tents_island`), **Light Up**
(`puzzles/lightup2d.gd`, beside `lightup_island`) and **One Line**
(`puzzles/oneline2d.gd`, beside `oneline_island`). That is every screen the
concept page mocks; nothing is left on paper. The user is deciding whether the
game goes 2D, and nothing else has moved.
Specs:
`docs/superpowers/specs/2026-09-18-binairo-flat-design.md` and its
`...-codebreak-`, `...-balance-`, `...-shikaku-`, `...-untangle-`,
`...-tents-`, `...-lightup-` and `...-oneline-flat-design.md` siblings; mocks:
`docs/brainstorm/concepts.html#binairo`, `#codebreak`, `#balance`, `#shikaku`,
`#untangle`, `#tents`, `#lightup` and `#oneline`.

- **The flat screen breaks the sign rule on purpose.** Its title is a `Label`
  in ink (`Wordmark2D`) with the leaf drawn over it, not the carved sign, and
  it has no How to play card, working-line card or motto footer: a tip card
  with a sprout names the rule a tap just broke and opens the rules sheet.
  Nothing else may drop the sign; this screen is the experiment.
- **The rules live in a scene-free state class** the flat board draws
  (`puzzles/binairo_state.gd`, `puzzles/codebreak_state.gd`), and they are
  the island's move for move, so what is on trial is the screen and not the
  game. The island script still carries its own copy until the verdict;
  whichever board survives, the state is the one truth to keep.
- **Faces are code, not images** (`ui/faces/`): one Control per character,
  drawn from a few tweened properties (`expression`, `eye_open`, `spin`,
  `rock`) as one cached `ArrayMesh` per layer, because gl_compatibility pays
  per draw command. `radius_ratio` fixes R as a fraction of the rect and
  `plain` drops the face for a silhouette; `ui/faces/friends.gd` is the one
  list of Code Break's seven. Filled polygons get an antialiased feather in
  their own colour; MSAA for the 2D canvas stays off.
- **Code Break's score is a count and never a map.** Nothing on that screen
  may suggest which seat a pip came from -- not the pips' arrangement, not
  their colour, not a face, not the order things animate in. That is why the
  pouch is a loose pile with no socket for a miss, and why a checked row
  wears one expression rather than one per seat.
- **The flat host hides the stage** (`Stage.visible = false` and
  `show_setting(false)`) while it is up, under an opaque paper page, and
  shows it again on exit. The menu's `_show_list` restores the setting.
- **The registry picks the shell**: `Registry.shell(entry)` is "island"
  unless the entry says `"shell": "flat"`; `ui/menu.gd` builds the host
  accordingly, and `ui/puzzle_host.gd` builds its rows in `_build_chrome`,
  the one method the flat host overrides. It picks the tray too
  (`"tray": "friends"`, `"weights"`), because the host lays out its rows
  before it has a puzzle to ask how many chips it wants -- and it can drop
  the actions row with `"actions": false`, which Balance does: that board is
  its own continuous check, so it has no Check to put in the row and Reset
  rides up into the top bar instead. The flat host therefore measures its
  bottom slot from the rows it actually built, not from a constant; the
  eight screens want 460, 460, 390, 290, 140, 290, 290 and 290 -- Untangle
  drops the tray *and* the actions row, so its slot is the tip card alone.
- **What the flat chrome asks a board for is optional and defaulted**:
  `palette()`, `weights()` (the weight cards' rows), `tip_line()` (the
  sprout's own line, in place of Binairo's cycle of rules), `flat_win()` (the
  characters of the answer, laid across the win screen in place of the sun
  and the moon, optionally each with a label under it), `win_delay()` and
  `card_height(available)` (a board that wants less of the slot than it was
  given: Balance caps its scale bands, and the leftover becomes air *above*
  the weight cards, because a gap under the day card reads as a mistake and a
  gap above the cards reads as room) and `card_centred()` (where that
  leftover goes: Tents, Light Up and One Line halve it, because their grid is
  square -- or, on One Line, wider than it is tall -- while their space is
  tall, so the cell is capped by the width and there is slack however the card
  is cut; One Line's medium lattice is 4x3 and leaves 432 of a 1190 slot, the
  widest air of the eight and a call its spec's section 10 records rather than
  hides). A board that offers none gets Binairo's behaviour.
- **The flat cast is a shared drawing, and two screens already share one.**
  `ui/faces/friends.gd` is Code Break's seven and `ui/faces/fruit.gd` is
  Balance's five, and the apple in the second *is* the berry in the first --
  one class, one mesh cache, named differently by each screen because the
  mocks drew the same round red fruit twice. Light Up's lamp
  (`ui/faces/court_lantern.gd`) is the third: it is Untangle's paper lantern
  subclassed, with the cord and tassel off it and an iron foot under it, so it
  shares the parent's seat, halo and mesh cache. Check `ui/faces/` before
  drawing a new character -- in eight screens only One Line's walker
  (`ui/faces/snail_face.gd`) has earned a new species, and it earned it
  because nothing else in the cast walks anywhere and its trail *is* the
  mechanic.
- **A canvas command holds a mesh by RID, not by reference.** A board that
  rebuilds a cached `ArrayMesh` every frame and drops the previous one leaves
  the renderer drawing a freed RID -- "Parameter mesh is null", and an empty
  card -- on any frame rendered without its queued redraw flushed first, which
  is exactly what `RenderingServer.force_draw()` does in a harness.
  `lightup2d.gd` and `oneline2d.gd` keep the mesh their last `_draw` handed
  over (`_shown`) until the next one replaces it; `tents2d.gd` and
  `untangle2d.gd` do not, and should if they are ever shot the same way.
- **A board that rebuilds only while it is moving has to ask about every
  wave.** `oneline2d.gd`'s `_animating()` first asked only its posts'
  entrance, and on a figure of twenty lines the lines' own wave outlasts it:
  the last few froze at four fifths of their fade, two pale lines that never
  arrived. It showed on a rendered frame and in no test.

## Art: shading direction

The look everything aims for is in `docs/art/shading-direction.md`: soft
painted cel, no harsh black outlines, warm muted pastels, diffuse and
painterly surfaces, soft coloured shadows, minimal specular, depth through
colour rather than fog. Read it before touching a shader, palette or light.

Every lit material is on it (2026-09-17), through `core/toon.gd`: the eased
ramp, the eased sky rim and the painterly wash come with `Toon.material()`
and its variants, and a shell wears the layer's own colour's line. Two rules
keep it that way: set a mesh's material *before* `Toon.add_outline`, which
reads the colour off it, and call `Toon.reline` after any recolour that
does not go through `Models.tint` or `tint_named`. Nothing may hand a layer
the shared ink `Toon.outline()` or a hard ramp again.

The HUD's paper takes the same wash through `CozyTheme.dress()`, installed
once by `world/main.gd` before any screen builds: every Button, Panel and
PanelContainer that enters the tree without a material gets the one shared
paper material (`shaders/paper_2d.gdshader`, measured in screen space), so
a new widget needs nothing. A widget that wants another surface sets its
own material and keeps it, the way the wood trays do. Harnesses that build
a screen without `main.tscn` show the faces flat; that is the harness, not
a regression.

## Playing on an Android phone

The game ships as a native APK through Firebase App Distribution (project
`daily-games-420bf`, package `com.peeplet.daily`). Run `tools/deploy_android.sh`
to export and distribute; the build lands in the Firebase App Tester app on
the phone. Nothing deploys on push.

The export is the non-gradle (prebuilt template) path, arm64-v8a only,
debug-signed. Machine-local setup it depends on: the Android SDK at
`/opt/homebrew/share/android-commandlinetools` and `~/.android/debug.keystore`,
both wired into Godot's editor settings, plus the 4.7 Android export
templates. `build/` is ignored -- it is output.

## Analytics

Gameplay events go to Firebase (project `daily-games-420bf`) over the GA4
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
  `view_turn` and `peek_used`. A daily turn adds `turn_lock`, `turn_reveal`,
  `turn_share` and `crowd_reveal_opened`. Board events carry puzzle_id,
  difficulty, day, seconds, moves, hints, checks; the last two tell us
  whether Pipes' third dimension is a puzzle or a nuisance.
- **`locale` rides on every event**, stamped by `Analytics.track()` beside
  `session_id` and `engagement_time_msec` on whatever it is handed, so any
  event can be split by language without a caller remembering to pass it.
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

**The live project is `daily-games-420bf`** (provisioned 2026-09-17; it
replaced `peeplet-daily`, which now holds nothing this game uses). Firestore
is a `nam5` multi-region database with the rules from `server/` released,
anonymous sign-in is on, and `core/backend.gd`'s `API_KEY` is the project's
Web app key. The project is on Blaze and the three functions are deployed in
`us-central1` (`tools/deploy_functions.sh`), with their schedules enabled and
a one-day cleanup policy on their container images. Everything below was
verified against the local emulator suite first, then against the live
project.

**The project lives in a Google Cloud organisation with the "secure by
default" policies on**, and three of them bite anything that provisions it:
no service-account keys (`iam.disableServiceAccountKeyCreation`), no members
from other domains (`iam.allowedPolicyMemberDomains`, so a navlio account
cannot own the project and billing is attached from the hypertradeworx side),
and no automatic roles for default service accounts
(`iam.automaticIamGrantsForDefaultServiceAccounts`, so a fresh project's
functions cannot even build). Two one-time scripts hold the answers and are
safe to re-run: `tools/ci_identity.sh` (keyless CI sign-in for App
Distribution) and `tools/functions_identity.sh` (build and Firestore roles
for the functions' identity) and `tools/public_invoker.sh` (the domain
restriction also rejects `allUsers`, so `firebase deploy` leaves `submitTurn`
with no invoker and every call answers 403 from Cloud Run; this overrides the
constraint on this project alone and grants the invoker). All three grant
roles or change policy, so a person runs them, not an agent session. Billing
is the navlio account `013342-E2B1D4-0E3351`.

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
each. Against the live project, `tools/seed_turn_day.sh <game> <day> <json>`
writes one day's document the way `publishDay` would (create-only), for the
day a game ships on, which the 03:00 scheduler never reaches. How Big?'s
first two days (2026-09-17 and -18) were seeded this way.

**How Big?** (`turns/how_big.gd`, phase 1) is the first real turn, and it
replaced the Guess stub outright. The scout stands on a dock at a stated
height and the day's thing from the model set stands beside him as a black
silhouette (`Models.silhouette`, flat `Toon.ink`, no outline), so the player
sizes a shape and the reveal has the painted model to show; the finger
holds the thing's top (the turn overrides `_gui_input` and meets the touch
ray with the thing's frontal plane, because StageView drops any ray that
misses the ground plane and at 7 degrees the top half of the screen is sky).
The camera never moves: every item in the table fits four scout heights, so
the roadmap's pull-back was dropped along with the oak. `content/how_big.json`
is the one table -- the server's `npm run build` copies it into
`server/functions/src/`, gitignored there, so the two sides cannot drift --
and both pick the day's item by `fnv1a("how_big|<day>") % items`. A
published day names `item` and `metres`, and the published height wins, which
is how a day gets hand-picked. `TurnBase.result_text()` is the one line the
host's reveal panel shows under the score. The grade is symmetric in the log
ratio: within 6 percent is 100, a factor of five is 0.

`core/locale.gd` picks between `en`, `pt` and `es` and does the number
formatting `TranslationServer` does not. Only the turn flow's strings are
keyed (`locale/turn.csv`); the twelve boards are still hardcoded English, and
`HOWBIG_BLURB` is sitting in the CSV unwired, ready for whenever the registry's
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

Two repo secrets feed it, and the build says so when one is missing:

- `ANDROID_DEBUG_KEYSTORE` -- base64 of `~/.android/debug.keystore`. It must
  be *that* key: Android will not install a build over one signed differently.
- `ANALYTICS_API_SECRET` -- the GA4 Measurement Protocol secret. Absent, the
  build warns and reports nothing.

App Distribution itself needs no secret. The organisation the Firebase project
sits in forbids service-account keys, so the run signs in to Google keylessly
(Workload Identity Federation): the job's `id-token` is exchanged for the
`app-distribution` service account through the `github` identity pool, and
only runs from this repository are allowed to. `tools/ci_identity.sh` is the
one-time setup on the Google side; a failed sign-in fails the job rather than
warning, because there is no longer a missing secret to excuse it.

CI gets its Android SDK path into Godot by appending to the editor settings
file that `--import` generates, rather than writing one by hand; the appended
keys win over the defaults above them.
