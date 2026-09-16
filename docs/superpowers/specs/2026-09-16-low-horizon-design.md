# The game leans into a low-horizon landscape

Every board is played on a leaning tableau standing in a painted lake
landscape whose horizon, hills and clouds are in frame, and whose grass,
clouds and water all move. Set on 2026-09-16.

The landscape comes from the BlenderKit scene "Stylized Anime Lake Landscape
Scene" (asset `6eb333de-54e9-471b-ae66-682595eaa28f`, free, royalty-free),
appended into `art/landscape.blend` as its own scene. The cut-down meadow
already in the game was taken from that same source file, so this is the rest
of a landscape we already own half of, not a new one.

## 0. What is replaced, and what is kept

Replaced:

- The camera's 68-degree pitch and 30-degree field. The board no longer meets
  the camera by lying flat under it; it leans.
- `shaders/water.gdshader`'s drifting bands and sparkle dots, in favour of the
  source lake's painted depth gradient, foam curls and streak highlights.
- The claim in `world/backdrop.gd` that no sky can ever be in frame. It was
  true at 68 degrees. It is the thing this design changes.

Kept, deliberately:

- `assets/models/meadow.glb` exactly as it is -- the sculpted basin, the curved
  shoreline and the `Grass_Blades` UV2 channel the wind shader reads. That work
  is a day old and still correct for the near ground.
- Every piece in `core/placeholders.gd`. Section 2 is arranged so no piece has
  to be re-cut.
- `shaders/backdrop_grass.gdshader`'s mechanism, `Ambient`'s `motion_scale`
  global as the single reduce-motion switch, and the splash ring.
- The board's stone platform, floating as it does today. An easel or a stand
  to explain the lean is deferred: it is new modelling, and the lean reads as
  a deliberate tableau without it. Revisit once the framing is on a phone.

## 1. Framing geometry

|                    | now   | this design | source painting |
| ------------------ | ----- | ----------- | --------------- |
| camera pitch       | 68    | **7**       | 3.24            |
| vertical FOV       | 30    | **40**      | 39.6            |
| horizon in frame   | never | **~32% from top** | ~42%      |
| board face seen at | 68    | **68**      | --              |

The frame spans `pitch - fov/2` to `pitch + fov/2` below the horizontal, so
the horizon sits about `0.5 - pitch/fov` down the frame. The old numbers put
it at -1.77 (far off the top); 7 and 40 put it at 0.325. The source painting's
own 3.24 and 39.6 were measured off its camera; 7 is steeper on purpose,
because a portrait phone frame spends its top and bottom on the HUD and the
extra three degrees buy that room back.

Distance does not enter into it. `CameraRig.fit` only slides the camera along
the view direction, so no amount of fitting can raise a horizon that the pitch
puts out of frame. This is why Pipes, already pitched at 35, still shows
nothing but meadow to every edge.

## 2. The lean, and why no piece changes

`Stage.fit_camera` stops setting the camera's pitch from the board and starts
setting the board's *tilt* from it:

```
rig.pitch_deg = CAMERA_PITCH          # 7.0, every board, always
anchor tilt   = board_face - CAMERA_PITCH
```

`board_pitch()` keeps its name and its numbers but is re-read as **the angle
the board's face is seen at**, which is what it always meant to a board. The
three boards that override it need no edit:

| board   | `board_pitch()` | face seen at | lean |
| ------- | --------------- | ------------ | ---- |
| default | NAN -> 68       | 68           | 61   |
| Horse   | 72              | 72           | 65   |
| Balance | 44              | 44           | 37   |
| Pipes   | 35              | 35           | 28   |

Because the face angle is preserved exactly, every tile top, every stacked
cairn pebble, every lantern glass and every token silhouette projects to the
screen as it does today, and the board's screen footprint stays roughly square
instead of squashing. That is the whole point of tilting the board rather than
dropping the camera onto a flat one.

The tilt is applied to `Stage.anchor` about the camera's right axis
(`Vector3.UP.cross(rig.view_offset_dir())`), so the board leans toward the
camera at any yaw. A board that turns (Pipes) therefore keeps facing the
player at all four stops, with its own X and Z swapping under it -- which is
what its four stops mean.

### The one thing the lean does break

A piece that reads as *standing in a place* -- Horse Pen's horse, Tents'
conifers, Light Up's lanterns, Untangle's mooring posts -- leans with the
board and looks like it is toppling backwards. Two levers, chosen per board on
a screenshot, never guessed:

1. Counter-rotate the piece by the board's tilt about its own base, so it
   stands world-up out of a leaning field. Correct, but it gaps at the base
   and can occlude the cell behind it.
2. Let the board ask for a shallower face angle, trading grid depth for
   uprightness.

This is the main risk in the design and the bulk of the work. It is per board,
it is judged on a rendered frame, and it is the part the user accepted when
choosing to reframe all twelve.

## 3. Input

Picking currently intersects the camera ray with a *world-horizontal* plane at
`plane_height()`. A leaning board breaks that, and it is the only thing in the
codebase that breaks outright rather than merely looking wrong.

The fix is in `core/puzzle_base_3d.gd` alone, and no board changes:

- `local_to_board` and `local_ray` take the ray into the board's own space
  (`board.global_transform.affine_inverse()`) before intersecting the local
  plane. Boards already treat the hit as board-local -- it was identical to
  world only because the anchor sat untransformed at the origin.
- `board_to_local` applies `board.global_transform` to the point before
  unprojecting. All fifteen callers keep passing board-local points from
  `BoardMath`, unchanged.
- `_refit` hands the rig `board.global_transform * board_aabb()`, so the fit
  frames where the board actually is.

## 4. The landscape at a raking angle

At 7 degrees the ground recedes to the horizon, and `test_1.jpg` -- one painted
top-down meadow, 498 px, vignetted -- smears if it is asked to cover that
distance. The source scene solves it with a silhouette, and so does this:

- **Near ground:** `meadow.glb`, untouched, with its basin and shoreline.
- **Far ring:** `hills.glb`, new -- the outer annulus of the source scene's
  200x200 sculpted terrain, the part that rolls. Placed just outside the
  meadow's footprint so the join falls behind the rise. Painted with the same
  texture, unshaded, and washed toward `Pal.SKY_HORIZON` with distance, per
  `docs/art/shading-direction.md`: depth through colour, not fog.
- **Cloud bank:** one wide card behind the hills, drawn by a new
  `shaders/backdrop_sky.gdshader` ported from the source's `Material.003` --
  two noise fields through hard ramps, white to `#c3dcec` (the source's own
  pale blue, within a hair of `Pal.SKY_TOP`), alpha-cut, drifting. Built as a
  `QuadMesh` in code rather than exported: it is a rectangle.
- **Clouds:** the three `cloud.png` cards from the source scene, at last worth
  their draw calls. `cloud.glb` is already exported and unused. They drift.
- **Foliage and blossom:** kept, re-placed for a camera that now sees the bank
  rather than looking down on it.

The `ProceduralSkyMaterial` already in `Stage` becomes visible for the first
time; its `SKY_TOP` and `SKY_HORIZON` are what the cloud bank sits against.

## 5. The lake

`shaders/water.gdshader` is rewritten as a port of the source lake's
`Material.005` -- 42 nodes, no image textures, so it ports rather than bakes.
Four layers, in order:

1. **Depth gradient.** A quadratic-sphere gradient from the lake centre through
   a four-stop ramp. The source's stops, converted from linear to sRGB, are
   `#00ffdd`, `#00b3ff`, `#008ffb`, `#0061ff` at 0.15 / 0.359 / 0.673 / 1.0.
   Those are far more saturated than this project's direction allows, so they
   are muted toward `Pal.WATER` (`#2f8fd6`) and `Pal.WATER_HI` (`#5fb0e8`)
   and the final hexes are settled on a rendered frame.
2. **Mottle.** Noise at scale 3.3, distortion 7.4, through a greater-than at
   0.3 and a white-to-black ramp.
3. **Foam curls.** A magic field (depth 2, scale 4.4, distortion 0.5) mixed
   0.133 with a spherical gradient, through constant ramps at 0.095 and 0.314.
   This is the white curl that makes the lake read as painted rather than
   shaded, and it is the single most valuable thing in the port.
4. **Streaks.** A wave field (scale 9, distortion -1.2) mixed half and half
   with noise (scale 1.1, distortion -0.5), through a constant ramp with a
   narrow 0.532-to-0.63 window -- the long white dashes across the surface.

Every field's coordinates drift on `TIME * motion_scale`, at different rates,
so the lake moves without any one layer reading as a scrolling texture. The
existing `splash_age` ring and the two-band `light()` survive unchanged; the
ring is why the pond must stay one shared material.

The pond also has to grow: at 7 degrees it runs to the shoreline of a
landscape rather than sitting in a basin under the board.

## 6. Wind

Three moving things, one switch:

- **Grass.** `backdrop_grass.gdshader` keeps its UV2 mechanism; `sway_amount`
  and `gust_scale` are re-tuned, because a field seen edge-on shows sway that a
  field seen from above hid.
- **Clouds.** A slow horizontal drift, in shader rather than in script, so the
  `motion_scale` global stills them along with everything else.
- **Water.** Section 5.

`Motion.reduce` -> `motion_scale = 0` must still still *all* of it. Nothing may
move from `_process` where a shader can do it.

## 7. Light

`Stage`'s sun energy 0.46 and ambient 0.115 were measured against a lit stone
tile face at 68 degrees, on a pipeline the comment says is brighter than the
shader maths predicts. A face leaning 61 degrees toward a camera 7 degrees off
the horizontal takes the sun differently, so both are re-measured the same way
-- off a rendered frame, not derived -- and the comment updated with the new
numbers and date. The sun's own direction is re-aimed so shadows still fall
toward the player and to the left across a leaning board.

## 8. Budget and verification

- Draw calls at rest at most **855** (the ceiling Code Break's screen set).
  This design adds roughly seven: the hills ring, the cloud bank, three cloud
  cards, and headroom.
- Idle mean frame time at most **8 ms** at 1080x1920.
- The full suite passes with no new failures. No new tests: this is MVP-stage
  work and the checks are throwaway harness runs.
- `tests/_shot.gd` renders all twelve boards, and each is judged for piece
  readability and for whether anything looks like it is toppling. This is the
  gate, not the test count.
- `tests/_win.gd` stays 10/10 winnable, run windowed -- it silently reports
  0/0 headless.
- A live look on a phone through `tools/deploy_android.sh`, because a horizon
  and a lean are exactly the things a 6-inch screen judges differently.

## 9. Build order

1. Cut the appended scene in `art/landscape.blend` to the contract and export
   `hills.glb`; confirm `cloud.glb` still imports.
2. Framing: `CAMERA_PITCH`, FOV, the anchor tilt, the AABB transform.
3. Input: the three functions in `core/puzzle_base_3d.gd`.
4. First screenshot of all twelve boards. Nothing else proceeds until the
   framing is judged.
5. The lake shader port.
6. The hills ring, cloud bank and clouds, with their drift.
7. Light re-measurement.
8. Per-board readability pass: the upright/shallower decision, board by board.
9. Budget, suite, win harness, phone.

Steps 2 through 4 are the pivot. If the lean reads as wrong at step 4, the
cheapest retreat is the island-in-the-sky framing (keep 68 degrees, end the
meadow inside the frame, stand the hills and clouds beyond its edge), which
needs sections 4 through 7 and none of 2, 3 or 8.
